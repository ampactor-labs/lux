//! Bytecode compiler: translates AST to chunk bytecode.
//!
//! Single-pass compilation with forward jump patching.
//! Tail position tracking for TCO.

use std::collections::HashMap;
use std::sync::Arc;

use crate::ast::*;
use crate::error::LuxError;
use crate::vm::chunk::{Chunk, Constant, FnProto};
use crate::vm::opcode::OpCode;

use super::effects::HandlerCtx;
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
    /// Handler context for Resume state-update name resolution.
    pub(super) handler_ctx: Option<HandlerCtx>,
    /// Known effect operations: op_name → effect_name.
    /// Used to compile `Call(op_name, args)` as `Perform` when the callee
    /// is a registered effect operation.
    pub(super) effect_ops: HashMap<String, String>,
    /// Variant name → ordered field names, for FieldAccess index resolution.
    pub(super) field_registry: HashMap<String, Vec<String>>,
}

/// Loop compilation context.
struct LoopCtx {
    /// Code offset of the loop header (for continue in while/loop).
    start: usize,
    /// Whether continue should use forward-patching (true for for-loops
    /// where the increment section comes after the body).
    continue_forward: bool,
    /// Offsets of jump placeholders that need patching for continue (for-loops).
    continue_patches: Vec<usize>,
    /// Offsets of jump placeholders that need patching on break.
    break_patches: Vec<usize>,
}

impl Compiler {
    pub(super) fn new(name: &str) -> Self {
        Self {
            chunk: Chunk::new(name),
            scope: Scope::new(),
            in_tail: false,
            loop_stack: Vec::new(),
            handler_ctx: None,
            effect_ops: HashMap::new(),
            field_registry: HashMap::new(),
        }
    }

    /// Finish compilation, returning the FnProto.
    pub(super) fn finish(self) -> FnProto {
        let local_count = self.scope.local_count();
        let upval_count = self.scope.upvalues.len() as u16;
        FnProto {
            name: Some(self.chunk.name.clone()),
            arity: 0,
            local_count,
            upval_count,
            chunk: self.chunk,
            field_registry: self.field_registry,
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
    pub(super) fn emit_jump(&mut self, op: OpCode, line: u32) -> usize {
        self.emit_op(op, line);
        let patch_offset = self.chunk.current_offset();
        self.emit_u16(0, line); // placeholder
        patch_offset
    }

    /// Patch a previously emitted jump placeholder to jump to the current offset.
    pub(super) fn patch_jump(&mut self, patch_offset: usize) {
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

    pub(super) fn current_line(span: &crate::token::Span) -> u32 {
        span.line as u32
    }

    // ── Item compilation ──────────────────────────────────────

    fn compile_item(&mut self, item: &Item) -> Result<(), LuxError> {
        match item {
            Item::FnDecl(fd) => self.compile_fn_decl(fd),
            Item::LetDecl(ld) => self.compile_let_decl(ld),
            Item::Expr(e) => {
                self.compile_expr(e)?;
                // Pop the result — top-level expressions are side-effect-only
                // (e.g. print calls). Without this, stale values accumulate
                // on the stack and corrupt handler stack_height tracking.
                self.emit_op(OpCode::Pop, 0);
                Ok(())
            }
            // Register effect operations for Perform dispatch.
            Item::EffectDecl(decl) => {
                for op in &decl.operations {
                    self.effect_ops.insert(op.name.clone(), decl.name.clone());
                }
                Ok(())
            }
            Item::TypeDecl(decl) => {
                self.compile_type_decl(decl)?;
                Ok(())
            }
            // Trait/impl declarations don't generate code.
            // Imports are resolved before compilation.
            Item::TraitDecl(_) | Item::ImplBlock(_) | Item::Import(_) => Ok(()),
        }
    }

    fn compile_fn_decl(&mut self, fd: &FnDecl) -> Result<(), LuxError> {
        let line = Self::current_line(&fd.span);

        // Compile function body in a nested compiler
        let mut fn_compiler = Compiler::new(&fd.name);
        fn_compiler.effect_ops = self.effect_ops.clone();
        fn_compiler.field_registry = self.field_registry.clone();
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
            // In a block: value is on TOS; declare_local claims that position
            self.scope.declare_local(&ld.name);
        } else {
            // Top-level: store as global
            let name_idx = self.chunk.intern_name(&ld.name);
            self.emit_op(OpCode::StoreGlobal, line);
            self.emit_u16(name_idx, line);
        }

        Ok(())
    }

    // ── Expression compilation ────────────────────────────────

    pub(super) fn compile_expr(&mut self, expr: &Expr) -> Result<(), LuxError> {
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
                // Pop locals but keep the result on top.
                // Strategy: save result to a temp global, pop locals, reload.
                if pops > 0 {
                    let temp_idx = self.chunk.intern_name("__blk_tmp__");
                    self.emit_op(OpCode::StoreGlobal, line);
                    self.emit_u16(temp_idx, line);
                    for _ in 0..pops {
                        self.emit_op(OpCode::Pop, line);
                    }
                    self.emit_op(OpCode::LoadGlobal, line);
                    self.emit_u16(temp_idx, line);
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
                    continue_forward: false,
                    continue_patches: Vec::new(),
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
                    continue_forward: false,
                    continue_patches: Vec::new(),
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
                    if ctx.continue_forward {
                        // For-loop: forward jump to increment (patched later)
                        let patch = self.emit_jump(OpCode::Jump, line);
                        // Re-borrow mutably to push the patch
                        self.loop_stack
                            .last_mut()
                            .unwrap()
                            .continue_patches
                            .push(patch);
                    } else {
                        let start = ctx.start;
                        self.emit_loop(start, line);
                    }
                }
            }

            Expr::For {
                binding,
                iterable,
                body,
                span,
            } => {
                let line = Self::current_line(span);

                // Open scope for internal locals (list, idx, binding).
                self.scope.begin_scope();

                // Compile iterable → stack has [list] (claimed as local)
                self.compile_expr(iterable)?;
                let list_slot = self.scope.declare_local("__for_list__");

                // Initialize index = 0 (claimed as local)
                self.emit_op(OpCode::LoadInt, line);
                self.emit_u8(0, line);
                let idx_slot = self.scope.declare_local("__for_idx__");

                // Initialize binding placeholder (claimed as local)
                self.emit_op(OpCode::LoadUnit, line);
                let binding_slot = self.scope.declare_local(binding);

                // loop_start: check idx < len(list)
                let loop_start = self.chunk.current_offset();
                self.loop_stack.push(LoopCtx {
                    start: loop_start,
                    continue_forward: true,
                    continue_patches: Vec::new(),
                    break_patches: Vec::new(),
                });

                // Load len(list)
                self.compile_var_load("len", line);
                self.emit_op(OpCode::LoadLocal, line);
                self.emit_u16(list_slot, line);
                self.emit_op(OpCode::Call, line);
                self.emit_u8(1, line);

                // Load idx
                self.emit_op(OpCode::LoadLocal, line);
                self.emit_u16(idx_slot, line);

                // len > idx? (i.e. idx < len)
                self.emit_op(OpCode::Gt, line);
                let exit_jump = self.emit_jump(OpCode::JumpIfFalse, line);
                self.emit_op(OpCode::Pop, line); // pop condition

                // binding = list[idx]
                self.emit_op(OpCode::LoadLocal, line);
                self.emit_u16(list_slot, line);
                self.emit_op(OpCode::LoadLocal, line);
                self.emit_u16(idx_slot, line);
                self.emit_op(OpCode::ListIndex, line);
                self.emit_op(OpCode::StoreLocal, line);
                self.emit_u16(binding_slot, line);
                self.emit_op(OpCode::Pop, line); // pop the store result

                // Compile body
                self.compile_expr(body)?;
                self.emit_op(OpCode::Pop, line); // discard body value

                // Patch continue jumps to land here (the increment section).
                if let Some(ctx) = self.loop_stack.last_mut() {
                    let patches: Vec<usize> = ctx.continue_patches.drain(..).collect();
                    for patch in patches {
                        self.patch_jump(patch);
                    }
                }

                // idx = idx + 1
                self.emit_op(OpCode::LoadLocal, line);
                self.emit_u16(idx_slot, line);
                self.emit_op(OpCode::LoadInt, line);
                self.emit_u8(1, line);
                self.emit_op(OpCode::Add, line);
                self.emit_op(OpCode::StoreLocal, line);
                self.emit_u16(idx_slot, line);
                self.emit_op(OpCode::Pop, line); // pop store result

                // Jump back to loop_start
                self.emit_loop(loop_start, line);

                // exit:
                self.patch_jump(exit_jump);
                self.emit_op(OpCode::Pop, line); // pop false condition

                let ctx = self.loop_stack.pop().unwrap();
                for patch in ctx.break_patches {
                    self.patch_jump(patch);
                }

                let pops = self.scope.end_scope();
                for _ in 0..pops {
                    self.emit_op(OpCode::Pop, line);
                }
                self.emit_op(OpCode::LoadUnit, line);
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
                // a |> f(b, c) compiles to f(a, b, c) — pipe value inserted as first arg
                if let Expr::Call { func, args, .. } = right.as_ref() {
                    self.compile_expr(func)?;
                    self.compile_expr(left)?;
                    for arg in args {
                        self.compile_expr(arg)?;
                    }
                    self.emit_op(OpCode::Call, line);
                    self.emit_u8((1 + args.len()) as u8, line);
                } else {
                    // a |> f compiles to f(a)
                    self.compile_expr(right)?;
                    self.compile_expr(left)?;
                    self.emit_op(OpCode::Call, line);
                    self.emit_u8(1, line);
                }
            }

            Expr::Return { value, span } => {
                let line = Self::current_line(span);
                self.compile_expr(value)?;
                self.emit_op(OpCode::Return, line);
            }

            Expr::Assert {
                condition,
                message,
                span,
            } => {
                let line = Self::current_line(span);
                // Compile: if condition is true, result is Unit.
                // If false, call __assert_fail(message) which errors.
                self.compile_expr(condition)?;
                let skip_fail = self.emit_jump(OpCode::JumpIfTrue, line);
                self.emit_op(OpCode::Pop, line); // pop false
                self.compile_var_load("__assert_fail", line);
                self.compile_expr(message)?;
                self.emit_op(OpCode::Call, line);
                self.emit_u8(1, line);
                let skip_unit = self.emit_jump(OpCode::Jump, line);
                self.patch_jump(skip_fail);
                self.emit_op(OpCode::Pop, line); // pop true
                self.emit_op(OpCode::LoadUnit, line);
                self.patch_jump(skip_unit);
            }

            // ── Expressions that need closures/calls/effects (Phase 6C-4+) ──
            Expr::Call { func, args, span } => {
                // Check if calling a known effect operation → emit Perform.
                if let Expr::Var(name, _) = func.as_ref() {
                    if let Some(effect_name) = self.effect_ops.get(name).cloned() {
                        self.compile_perform(&effect_name, name, args, span)?;
                        return Ok(());
                    }
                }

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
                fn_compiler.effect_ops = self.effect_ops.clone();
                fn_compiler.field_registry = self.field_registry.clone();
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

                // Save scrutinee in a dedicated local so pattern bindings
                // can't overwrite it (needed when guard fails and we retry arms).
                self.scope.begin_scope();
                self.compile_expr(scrutinee)?;
                let scrutinee_slot = self.scope.declare_local("__match_scrutinee__");

                let mut end_patches = Vec::new();
                for arm in arms {
                    // Load scrutinee for pattern test
                    self.emit_op(OpCode::LoadLocal, line);
                    self.emit_u16(scrutinee_slot, line);
                    self.compile_pattern_test(&arm.pattern, line)?;
                    let skip = self.emit_jump(OpCode::JumpIfFalse, line);
                    self.emit_op(OpCode::Pop, line); // pop test result

                    // Load scrutinee for pattern binding
                    self.emit_op(OpCode::LoadLocal, line);
                    self.emit_u16(scrutinee_slot, line);

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
                        let end = self.emit_jump(OpCode::Jump, line);
                        end_patches.push(end);

                        self.patch_jump(guard_fail);
                        self.emit_op(OpCode::Pop, line); // pop guard false
                        let _pops2 = self.scope.end_scope();
                        // Pop the loaded scrutinee for this arm
                        self.emit_op(OpCode::Pop, line);
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

                // If no arm matched, push Unit as default
                self.emit_op(OpCode::LoadUnit, line);
                for patch in end_patches {
                    self.patch_jump(patch);
                }

                // End the scrutinee scope
                let match_pops = self.scope.end_scope();
                if match_pops > 0 {
                    // Save result, pop scrutinee local, reload result
                    let temp_idx = self.chunk.intern_name("__match_tmp__");
                    self.emit_op(OpCode::StoreGlobal, line);
                    self.emit_u16(temp_idx, line);
                    for _ in 0..match_pops {
                        self.emit_op(OpCode::Pop, line);
                    }
                    self.emit_op(OpCode::LoadGlobal, line);
                    self.emit_u16(temp_idx, line);
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

            // ── Effects ───────────────────────────────────────────
            Expr::Handle {
                expr,
                handlers,
                state_bindings,
                span,
            } => {
                self.compile_handle(expr, handlers, state_bindings, span)?;
            }

            Expr::Perform {
                effect,
                operation,
                args,
                span,
            } => {
                self.compile_perform(effect, operation, args, span)?;
            }

            Expr::Resume {
                value,
                state_updates,
                span,
            } => {
                self.compile_resume(value, state_updates, span)?;
            }
        }
        Ok(())
    }

    // ── Variable resolution ───────────────────────────────────

    pub(super) fn compile_var_load(&mut self, name: &str, line: u32) {
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

    // ── TypeDecl compilation ─────────────────────────────────

    fn compile_type_decl(&mut self, decl: &TypeDecl) -> Result<(), LuxError> {
        for variant in &decl.variants {
            let _arity = variant.fields.len();
            let line = Self::current_line(&variant.span);

            // Register named fields for FieldAccess resolution.
            let field_names: Vec<String> = variant
                .fields
                .iter()
                .enumerate()
                .map(|(idx, f)| f.name.clone().unwrap_or_else(|| format!("_{idx}")))
                .collect();
            if variant.fields.iter().any(|f| f.name.is_some()) {
                self.field_registry
                    .insert(variant.name.clone(), field_names);
            }

            // Emit a zero-field variant as a global. For zero-arity variants
            // this IS the value; for N-arity variants the VM's call_value
            // treats Variant{fields:[]} + Call(N) as a constructor call.
            let name_idx = self.chunk.intern_name(&variant.name);
            self.emit_op(OpCode::MakeVariant, line);
            self.emit_u16(name_idx, line);
            self.emit_u16(0, line);
            let store_idx = self.chunk.intern_name(&variant.name);
            self.emit_op(OpCode::StoreGlobal, line);
            self.emit_u16(store_idx, line);
        }
        Ok(())
    }
}
