//! Bytecode compiler: translates AST to chunk bytecode.
//!
//! Single-pass compilation with forward jump patching.
//! Tail position tracking for TCO.

use std::sync::Arc;

use crate::ast::*;
use crate::error::LuxError;
use crate::vm::chunk::{Chunk, Constant, FnProto};
use crate::vm::opcode::OpCode;

use super::scope::Scope;

/// Compile a Lux program to a top-level bytecode chunk.
pub fn compile(program: &Program) -> Result<FnProto, LuxError> {
    let mut compiler = Compiler::new("<main>");
    for item in &program.items {
        compiler.compile_item(item)?;
    }
    compiler.emit_op(OpCode::Return, 0);
    Ok(compiler.finish())
}

/// Bytecode compiler state.
pub(super) struct Compiler {
    pub(super) chunk: Chunk,
    pub(super) scope: Scope,
    /// Whether the current expression is in tail position.
    pub(super) in_tail: bool,
    /// Loop context for break/continue: (loop_start, break_patches).
    loop_stack: Vec<LoopCtx>,
}

/// Loop compilation context.
struct LoopCtx {
    /// Code offset of the loop header (for continue).
    start: usize,
    /// Offsets of jump placeholders that need patching on break.
    break_patches: Vec<usize>,
}

impl Compiler {
    fn new(name: &str) -> Self {
        Self {
            chunk: Chunk::new(name),
            scope: Scope::new(),
            in_tail: false,
            loop_stack: Vec::new(),
        }
    }

    /// Finish compilation, returning the FnProto.
    fn finish(self) -> FnProto {
        let local_count = self.scope.local_count();
        let upval_count = self.scope.upvalues.len() as u16;
        FnProto {
            name: Some(self.chunk.name.clone()),
            arity: 0,
            local_count,
            upval_count,
            chunk: self.chunk,
        }
    }

    // ── Emit helpers ──────────────────────────────────────────

    pub(super) fn emit_op(&mut self, op: OpCode, line: u32) {
        self.chunk.emit_op(op, line);
    }

    pub(super) fn emit_u8(&mut self, val: u8, line: u32) {
        self.chunk.emit(val, line);
    }

    pub(super) fn emit_u16(&mut self, val: u16, line: u32) {
        self.chunk.emit_u16(val, line);
    }

    fn emit_constant(&mut self, constant: Constant, line: u32) -> u16 {
        let idx = self.chunk.add_constant(constant);
        self.emit_op(OpCode::LoadConst, line);
        self.emit_u16(idx, line);
        idx
    }

    /// Emit a jump instruction with a placeholder offset. Returns the offset
    /// of the placeholder for later patching.
    fn emit_jump(&mut self, op: OpCode, line: u32) -> usize {
        self.emit_op(op, line);
        let patch_offset = self.chunk.current_offset();
        self.emit_u16(0, line); // placeholder
        patch_offset
    }

    /// Patch a previously emitted jump placeholder to jump to the current offset.
    fn patch_jump(&mut self, patch_offset: usize) {
        let current = self.chunk.current_offset();
        let delta = (current as i32) - (patch_offset as i32) - 2; // -2 for the i16 operand itself
        self.chunk.patch_i16(patch_offset, delta as i16);
    }

    /// Emit a backward jump to the given target offset.
    fn emit_loop(&mut self, target: usize, line: u32) {
        self.emit_op(OpCode::Jump, line);
        let current = self.chunk.current_offset() + 2; // after the i16 operand
        let delta = (target as i32) - (current as i32);
        self.chunk.emit_i16(delta as i16, line);
    }

    fn current_line(span: &crate::token::Span) -> u32 {
        span.line as u32
    }

    // ── Item compilation ──────────────────────────────────────

    fn compile_item(&mut self, item: &Item) -> Result<(), LuxError> {
        match item {
            Item::FnDecl(fd) => self.compile_fn_decl(fd),
            Item::LetDecl(ld) => self.compile_let_decl(ld),
            Item::Expr(e) => {
                self.compile_expr(e)?;
                // Top-level expressions: keep value on stack (last becomes result)
                Ok(())
            }
            // Type/effect/trait/impl declarations don't generate code
            Item::TypeDecl(_) | Item::EffectDecl(_) | Item::TraitDecl(_) | Item::ImplBlock(_) => {
                Ok(())
            }
        }
    }

    fn compile_fn_decl(&mut self, fd: &FnDecl) -> Result<(), LuxError> {
        let line = Self::current_line(&fd.span);

        // Compile function body in a nested compiler
        let mut fn_compiler = Compiler::new(&fd.name);
        fn_compiler.scope.begin_scope();

        // Declare parameters as locals
        for param in &fd.params {
            fn_compiler.scope.declare_local(&param.name);
        }

        // Compile body
        fn_compiler.in_tail = true;
        fn_compiler.compile_expr(&fd.body)?;
        fn_compiler.emit_op(OpCode::Return, line);

        let mut proto = fn_compiler.finish();
        proto.arity = fd.params.len() as u16;

        // In the outer scope: create closure and bind to name
        let proto_idx = self.chunk.add_constant(Constant::FnProto(Arc::new(proto)));
        self.emit_op(OpCode::MakeClosure, line);
        self.emit_u16(proto_idx, line);
        // No upvalues for top-level functions (for now)

        // Store as global
        let name_idx = self.chunk.intern_name(&fd.name);
        self.emit_op(OpCode::StoreGlobal, line);
        self.emit_u16(name_idx, line);

        Ok(())
    }

    fn compile_let_decl(&mut self, ld: &LetDecl) -> Result<(), LuxError> {
        let line = Self::current_line(&ld.span);
        self.compile_expr(&ld.value)?;

        if self.scope.scope_depth > 0 {
            // In a block: store as local
            self.scope.declare_local(&ld.name);
            // Value already on stack in the right slot
        } else {
            // Top-level: store as global
            let name_idx = self.chunk.intern_name(&ld.name);
            self.emit_op(OpCode::StoreGlobal, line);
            self.emit_u16(name_idx, line);
        }

        Ok(())
    }

    // ── Expression compilation ────────────────────────────────

    fn compile_expr(&mut self, expr: &Expr) -> Result<(), LuxError> {
        match expr {
            Expr::IntLit(n, span) => {
                let line = Self::current_line(span);
                if *n >= -128 && *n <= 127 {
                    self.emit_op(OpCode::LoadInt, line);
                    self.emit_u8(*n as i8 as u8, line);
                } else {
                    self.emit_constant(Constant::Int(*n), line);
                }
            }
            Expr::FloatLit(n, span) => {
                let line = Self::current_line(span);
                self.emit_constant(Constant::Float(*n), line);
            }
            Expr::StringLit(s, span) => {
                let line = Self::current_line(span);
                self.emit_constant(Constant::String(Arc::new(s.clone())), line);
            }
            Expr::BoolLit(b, span) => {
                let line = Self::current_line(span);
                self.emit_op(OpCode::LoadBool, line);
                self.emit_u8(u8::from(*b), line);
            }

            Expr::Var(name, span) => {
                let line = Self::current_line(span);
                self.compile_var_load(name, line);
            }

            Expr::BinOp {
                op,
                left,
                right,
                span,
            } => {
                let line = Self::current_line(span);
                // Short-circuit for And/Or
                match op {
                    BinOp::And => {
                        self.compile_expr(left)?;
                        let skip = self.emit_jump(OpCode::JumpIfFalse, line);
                        self.emit_op(OpCode::Pop, line);
                        self.compile_expr(right)?;
                        self.patch_jump(skip);
                        return Ok(());
                    }
                    BinOp::Or => {
                        self.compile_expr(left)?;
                        let skip = self.emit_jump(OpCode::JumpIfTrue, line);
                        self.emit_op(OpCode::Pop, line);
                        self.compile_expr(right)?;
                        self.patch_jump(skip);
                        return Ok(());
                    }
                    _ => {}
                }
                self.compile_expr(left)?;
                self.compile_expr(right)?;
                match op {
                    BinOp::Add => self.emit_op(OpCode::Add, line),
                    BinOp::Sub => self.emit_op(OpCode::Sub, line),
                    BinOp::Mul => self.emit_op(OpCode::Mul, line),
                    BinOp::Div => self.emit_op(OpCode::Div, line),
                    BinOp::Mod => self.emit_op(OpCode::Mod, line),
                    BinOp::Eq => self.emit_op(OpCode::Eq, line),
                    BinOp::Neq => self.emit_op(OpCode::Neq, line),
                    BinOp::Lt => self.emit_op(OpCode::Lt, line),
                    BinOp::LtEq => self.emit_op(OpCode::LtEq, line),
                    BinOp::Gt => self.emit_op(OpCode::Gt, line),
                    BinOp::GtEq => self.emit_op(OpCode::GtEq, line),
                    BinOp::Concat => self.emit_op(OpCode::Concat, line),
                    BinOp::And | BinOp::Or => unreachable!("handled above"),
                }
            }

            Expr::UnaryOp { op, operand, span } => {
                let line = Self::current_line(span);
                self.compile_expr(operand)?;
                match op {
                    UnaryOp::Neg => self.emit_op(OpCode::Neg, line),
                    UnaryOp::Not => self.emit_op(OpCode::Not, line),
                }
            }

            Expr::If {
                condition,
                then_branch,
                else_branch,
                span,
            } => {
                let line = Self::current_line(span);
                self.compile_expr(condition)?;
                let else_jump = self.emit_jump(OpCode::JumpIfFalse, line);
                self.emit_op(OpCode::Pop, line); // pop condition
                self.compile_expr(then_branch)?;

                if let Some(else_br) = else_branch {
                    let end_jump = self.emit_jump(OpCode::Jump, line);
                    self.patch_jump(else_jump);
                    self.emit_op(OpCode::Pop, line); // pop condition
                    self.compile_expr(else_br)?;
                    self.patch_jump(end_jump);
                } else {
                    self.patch_jump(else_jump);
                    self.emit_op(OpCode::Pop, line); // pop condition
                    self.emit_op(OpCode::LoadUnit, line);
                }
            }

            Expr::Block { stmts, expr, span } => {
                let line = Self::current_line(span);
                self.scope.begin_scope();

                for stmt in stmts {
                    match stmt {
                        Stmt::Let(ld) => self.compile_let_decl(ld)?,
                        Stmt::Expr(e) => {
                            self.compile_expr(e)?;
                            self.emit_op(OpCode::Pop, line);
                        }
                        Stmt::FnDecl(fd) => self.compile_fn_decl(fd)?,
                    }
                }

                if let Some(final_expr) = expr {
                    self.compile_expr(final_expr)?;
                } else {
                    self.emit_op(OpCode::LoadUnit, line);
                }

                let pops = self.scope.end_scope();
                // Pop locals but keep the result on top
                if pops > 0 {
                    // The result is on top, locals are below it.
                    // We need to swap result past locals then pop.
                    // Simple approach: use StoreLocal to temp slot, pop locals, restore.
                    // For now, just pop each local individually under the result.
                    // This is O(n) but correct. Optimize later with a SwapN opcode.
                    for _ in 0..pops {
                        // Result is TOS, local is TOS-1. We need to drop TOS-1.
                        // No direct "drop below top" opcode yet, so we accept the
                        // stack layout as-is. The result is already on top and the
                        // local slots are abandoned. They'll be reclaimed when the
                        // call frame exits.
                    }
                }
            }

            Expr::Let {
                name,
                value,
                span: _,
                ..
            } => {
                self.compile_expr(value)?;
                self.scope.declare_local(name);
                // Value stays on stack as the local's slot
                // Let expression evaluates to Unit
                self.emit_op(
                    OpCode::LoadUnit,
                    self.chunk.lines.last().copied().unwrap_or(0),
                );
            }

            Expr::While {
                condition,
                body,
                span,
            } => {
                let line = Self::current_line(span);
                let loop_start = self.chunk.current_offset();
                self.loop_stack.push(LoopCtx {
                    start: loop_start,
                    break_patches: Vec::new(),
                });

                self.compile_expr(condition)?;
                let exit_jump = self.emit_jump(OpCode::JumpIfFalse, line);
                self.emit_op(OpCode::Pop, line); // pop condition

                self.compile_expr(body)?;
                self.emit_op(OpCode::Pop, line); // discard body value

                self.emit_loop(loop_start, line);
                self.patch_jump(exit_jump);
                self.emit_op(OpCode::Pop, line); // pop false condition

                let ctx = self.loop_stack.pop().unwrap();
                for patch in ctx.break_patches {
                    self.patch_jump(patch);
                }
                self.emit_op(OpCode::LoadUnit, line);
            }

            Expr::Loop { body, span } => {
                let line = Self::current_line(span);
                let loop_start = self.chunk.current_offset();
                self.loop_stack.push(LoopCtx {
                    start: loop_start,
                    break_patches: Vec::new(),
                });

                self.compile_expr(body)?;
                self.emit_op(OpCode::Pop, line); // discard body value
                self.emit_loop(loop_start, line);

                let ctx = self.loop_stack.pop().unwrap();
                for patch in ctx.break_patches {
                    self.patch_jump(patch);
                }
                self.emit_op(OpCode::LoadUnit, line);
            }

            Expr::Break { value, span } => {
                let line = Self::current_line(span);
                if let Some(val) = value {
                    self.compile_expr(val)?;
                } else {
                    self.emit_op(OpCode::LoadUnit, line);
                }
                // Jump to after the loop — placeholder patched when loop ends
                let patch = self.emit_jump(OpCode::Jump, line);
                if let Some(ctx) = self.loop_stack.last_mut() {
                    ctx.break_patches.push(patch);
                }
            }

            Expr::Continue { span } => {
                let line = Self::current_line(span);
                if let Some(ctx) = self.loop_stack.last() {
                    let start = ctx.start;
                    self.emit_loop(start, line);
                }
            }

            Expr::For {
                binding,
                iterable,
                body,
                span,
            } => {
                let line = Self::current_line(span);
                // Compile iterable
                self.compile_expr(iterable)?;

                // Push iterator index (0)
                self.emit_op(OpCode::LoadInt, line);
                self.emit_u8(0, line);

                // Create scope for the loop variable
                self.scope.begin_scope();
                let binding_slot = self.scope.declare_local(binding);
                self.emit_op(OpCode::LoadUnit, line); // placeholder for binding

                let loop_start = self.chunk.current_offset();
                self.loop_stack.push(LoopCtx {
                    start: loop_start,
                    break_patches: Vec::new(),
                });

                // Check: index < len(list)
                // Stack: [list, idx, binding_val]
                // We need to dup list and idx to compare
                // For now, use a simpler approach: compile to a range/list iteration
                // using LoadLocal for the list and index slots.
                // This is a simplification — will be refined in the VM execution phase.

                // For the initial implementation, emit a placeholder that the VM
                // will handle specially. The full for-loop compilation requires
                // the VM to be running to test against.
                // TODO: Implement proper for-loop bytecode once VM dispatch is ready.

                self.compile_expr(body)?;
                self.emit_op(OpCode::Pop, line);
                self.emit_loop(loop_start, line);

                let ctx = self.loop_stack.pop().unwrap();
                for patch in ctx.break_patches {
                    self.patch_jump(patch);
                }

                let _pops = self.scope.end_scope();
                // Pop list and index
                self.emit_op(OpCode::Pop, line);
                self.emit_op(OpCode::Pop, line);
                self.emit_op(OpCode::LoadUnit, line);

                let _ = binding_slot; // used above in declare_local
            }

            Expr::Tuple(elements, span) => {
                let line = Self::current_line(span);
                for elem in elements {
                    self.compile_expr(elem)?;
                }
                self.emit_op(OpCode::MakeTuple, line);
                self.emit_u16(elements.len() as u16, line);
            }

            Expr::List(elements, span) => {
                let line = Self::current_line(span);
                for elem in elements {
                    self.compile_expr(elem)?;
                }
                self.emit_op(OpCode::MakeList, line);
                self.emit_u16(elements.len() as u16, line);
            }

            Expr::StringInterp { parts, span } => {
                let line = Self::current_line(span);
                for part in parts {
                    match part {
                        StringPart::Literal(s) => {
                            self.emit_constant(Constant::String(Arc::new(s.clone())), line);
                        }
                        StringPart::Expr(e) => {
                            self.compile_expr(e)?;
                        }
                    }
                }
                self.emit_op(OpCode::StringInterp, line);
                self.emit_u16(parts.len() as u16, line);
            }

            Expr::Pipe { left, right, span } => {
                let line = Self::current_line(span);
                // a |> f compiles to f(a)
                self.compile_expr(right)?; // function first
                self.compile_expr(left)?; // then argument
                self.emit_op(OpCode::Call, line);
                self.emit_u8(1, line); // 1 argument
            }

            Expr::Return { value, span } => {
                let line = Self::current_line(span);
                self.compile_expr(value)?;
                self.emit_op(OpCode::Return, line);
            }

            // ── Expressions that need closures/calls/effects (Phase 6C-4+) ──
            Expr::Call { func, args, span } => {
                let line = Self::current_line(span);
                self.compile_expr(func)?;
                for arg in args {
                    self.compile_expr(arg)?;
                }
                if self.in_tail {
                    self.emit_op(OpCode::TailCall, line);
                } else {
                    self.emit_op(OpCode::Call, line);
                }
                self.emit_u8(args.len() as u8, line);
            }

            Expr::Lambda {
                params, body, span, ..
            } => {
                let line = Self::current_line(span);

                // Save enclosing scope, give it to the lambda compiler
                let outer_scope = std::mem::replace(&mut self.scope, Scope::new());
                let mut fn_compiler = Compiler::new("<lambda>");
                fn_compiler.scope.enclosing = Some(Box::new(outer_scope));
                fn_compiler.scope.begin_scope();

                for param in params {
                    fn_compiler.scope.declare_local(&param.name);
                }

                fn_compiler.in_tail = true;
                fn_compiler.compile_expr(body)?;
                fn_compiler.emit_op(OpCode::Return, line);

                // Extract upvalue descriptors before finishing
                let upvalues: Vec<_> = fn_compiler.scope.upvalues.clone();
                // Restore enclosing scope
                let enclosing = fn_compiler.scope.enclosing.take().unwrap();
                self.scope = *enclosing;

                let mut proto = fn_compiler.finish();
                proto.arity = params.len() as u16;

                let proto_idx = self.chunk.add_constant(Constant::FnProto(Arc::new(proto)));
                self.emit_op(OpCode::MakeClosure, line);
                self.emit_u16(proto_idx, line);
                // Emit upvalue descriptors
                for uv in &upvalues {
                    self.emit_u8(u8::from(uv.is_local), line);
                    self.emit_u16(uv.index, line);
                }
            }

            Expr::Match {
                scrutinee,
                arms,
                span,
            } => {
                let line = Self::current_line(span);
                self.compile_expr(scrutinee)?;

                let mut end_patches = Vec::new();
                for arm in arms {
                    // Dup scrutinee for pattern test
                    self.emit_op(OpCode::Dup, line);
                    self.compile_pattern_test(&arm.pattern, line)?;
                    let skip = self.emit_jump(OpCode::JumpIfFalse, line);
                    self.emit_op(OpCode::Pop, line); // pop test result

                    // Bind pattern variables
                    self.scope.begin_scope();
                    self.compile_pattern_bind(&arm.pattern, line)?;

                    // Compile guard if present
                    if let Some(guard) = &arm.guard {
                        self.compile_expr(guard)?;
                        let guard_fail = self.emit_jump(OpCode::JumpIfFalse, line);
                        self.emit_op(OpCode::Pop, line); // pop guard result

                        // Compile arm body
                        self.compile_expr(&arm.body)?;
                        let _pops = self.scope.end_scope();
                        // Pop scrutinee (below result) — result is TOS, scrutinee TOS-1
                        // For correctness we need swap+pop. Simplified: we leave scrutinee.
                        let end = self.emit_jump(OpCode::Jump, line);
                        end_patches.push(end);

                        self.patch_jump(guard_fail);
                        self.emit_op(OpCode::Pop, line); // pop guard false
                        let _pops2 = self.scope.end_scope();
                        continue;
                    }

                    // Compile arm body
                    self.compile_expr(&arm.body)?;
                    let _pops = self.scope.end_scope();
                    let end = self.emit_jump(OpCode::Jump, line);
                    end_patches.push(end);

                    self.patch_jump(skip);
                    self.emit_op(OpCode::Pop, line); // pop test result
                }

                // If no arm matched, result is the scrutinee (error case, but safe)
                for patch in end_patches {
                    self.patch_jump(patch);
                }
            }

            Expr::Index {
                object,
                index,
                span,
            } => {
                let line = Self::current_line(span);
                self.compile_expr(object)?;
                self.compile_expr(index)?;
                self.emit_op(OpCode::ListIndex, line);
            }

            Expr::FieldAccess {
                object,
                field,
                span,
            } => {
                let line = Self::current_line(span);
                self.compile_expr(object)?;
                let name_idx = self.chunk.intern_name(field);
                self.emit_op(OpCode::FieldAccess, line);
                self.emit_u16(name_idx, line);
            }

            Expr::RecordConstruct { name, fields, span } => {
                let line = Self::current_line(span);
                for (_, value) in fields {
                    self.compile_expr(value)?;
                }
                let name_idx = self.chunk.intern_name(name);
                self.emit_op(OpCode::MakeVariant, line);
                self.emit_u16(name_idx, line);
                self.emit_u16(fields.len() as u16, line);
            }

            // ── Effects (Phase 6C-5+) ─────────────────────────────
            Expr::Handle { span, .. } => {
                let line = Self::current_line(span);
                // Placeholder: will be implemented in Phase 6C-5
                self.emit_op(OpCode::LoadUnit, line);
            }

            Expr::Perform { span, .. } => {
                let line = Self::current_line(span);
                self.emit_op(OpCode::LoadUnit, line);
            }

            Expr::Resume { span, .. } => {
                let line = Self::current_line(span);
                self.emit_op(OpCode::LoadUnit, line);
            }
        }
        Ok(())
    }

    // ── Variable resolution ───────────────────────────────────

    fn compile_var_load(&mut self, name: &str, line: u32) {
        // Try local first
        if let Some(slot) = self.scope.resolve_local(name) {
            self.emit_op(OpCode::LoadLocal, line);
            self.emit_u16(slot, line);
            return;
        }
        // Try upvalue
        if let Some(idx) = self.scope.resolve_upvalue(name) {
            self.emit_op(OpCode::LoadUpval, line);
            self.emit_u16(idx, line);
            return;
        }
        // Fall back to global
        let name_idx = self.chunk.intern_name(name);
        self.emit_op(OpCode::LoadGlobal, line);
        self.emit_u16(name_idx, line);
    }
}
