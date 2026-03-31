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
pub fn compile(
    program: &Program,
    effect_routing: HashMap<crate::token::Span, Vec<String>>,
) -> Result<FnProto, LuxError> {
    let mut compiler = Compiler::new("<main>", effect_routing);
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
    /// Counter for unique pattern scratch variable names.
    pub(super) pat_scratch_id: u32,
    /// Named handler declarations for handler composition (expanded at compile time).
    pub(super) handler_decls: HashMap<
        String,
        (
            Vec<crate::ast::HandlerClause>,
            Vec<crate::ast::StateBinding>,
        ),
    >,
    /// Maps effect op names to evidence local slot index for the current scope.
    /// When a Perform encounters an op in this map, it emits PerformEvidence instead.
    pub(super) evidence_slots: HashMap<String, u16>,
    /// State slot base and count for the current evidence scope.
    pub(super) evidence_state: Option<(u16, u8)>,
    /// Side table mapping expression/declaration spans to required evidence arguments.
    pub(super) effect_routing: HashMap<crate::token::Span, Vec<String>>,
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

// ── Compile-time constant folding ────────────────────────────
// The compiler evaluates constant expressions at compile time.
// This exploits knowledge that C doesn't have: Lux knows when
// an expression is guaranteed pure, so it can safely evaluate it.

/// Result of compile-time constant evaluation.
enum FoldedConst {
    Int(i64),
    Float(f64),
    Bool(bool),
    Str(String),
}

impl Compiler {
    /// Try to evaluate an expression at compile time.
    /// Returns Some(result) if the expression is a constant or a pure
    /// operation on constants. Handles nested constant expressions
    /// recursively: `(1 + 2) * 3` → `9`.
    fn try_eval_const(expr: &Expr) -> Option<FoldedConst> {
        match expr {
            Expr::IntLit(n, _) => Some(FoldedConst::Int(*n)),
            Expr::FloatLit(f, _) => Some(FoldedConst::Float(*f)),
            Expr::BoolLit(b, _) => Some(FoldedConst::Bool(*b)),
            Expr::StringLit(s, _) => Some(FoldedConst::Str(s.clone())),
            Expr::BinOp {
                op, left, right, ..
            } => Self::try_const_fold(op, left, right),
            Expr::UnaryOp { op, operand, .. } => {
                let val = Self::try_eval_const(operand)?;
                match (op, val) {
                    (UnaryOp::Neg, FoldedConst::Int(n)) => Some(FoldedConst::Int(-n)),
                    (UnaryOp::Neg, FoldedConst::Float(f)) => Some(FoldedConst::Float(-f)),
                    (UnaryOp::Not, FoldedConst::Bool(b)) => Some(FoldedConst::Bool(!b)),
                    _ => None,
                }
            }
            _ => None,
        }
    }

    /// Try to fold a binary operation on two sub-expressions.
    fn try_const_fold(op: &BinOp, left: &Expr, right: &Expr) -> Option<FoldedConst> {
        let lhs = Self::try_eval_const(left)?;
        let rhs = Self::try_eval_const(right)?;
        match (op, lhs, rhs) {
            // Int arithmetic
            (BinOp::Add, FoldedConst::Int(a), FoldedConst::Int(b)) => {
                Some(FoldedConst::Int(a.wrapping_add(b)))
            }
            (BinOp::Sub, FoldedConst::Int(a), FoldedConst::Int(b)) => {
                Some(FoldedConst::Int(a.wrapping_sub(b)))
            }
            (BinOp::Mul, FoldedConst::Int(a), FoldedConst::Int(b)) => {
                Some(FoldedConst::Int(a.wrapping_mul(b)))
            }
            (BinOp::Div, FoldedConst::Int(a), FoldedConst::Int(b)) if b != 0 => {
                Some(FoldedConst::Int(a / b))
            }
            (BinOp::Mod, FoldedConst::Int(a), FoldedConst::Int(b)) if b != 0 => {
                Some(FoldedConst::Int(a % b))
            }
            // Float arithmetic
            (BinOp::Add, FoldedConst::Float(a), FoldedConst::Float(b)) => {
                Some(FoldedConst::Float(a + b))
            }
            (BinOp::Sub, FoldedConst::Float(a), FoldedConst::Float(b)) => {
                Some(FoldedConst::Float(a - b))
            }
            (BinOp::Mul, FoldedConst::Float(a), FoldedConst::Float(b)) => {
                Some(FoldedConst::Float(a * b))
            }
            (BinOp::Div, FoldedConst::Float(a), FoldedConst::Float(b)) if b != 0.0 => {
                Some(FoldedConst::Float(a / b))
            }
            // Int comparisons
            (BinOp::Eq, FoldedConst::Int(a), FoldedConst::Int(b)) => {
                Some(FoldedConst::Bool(a == b))
            }
            (BinOp::Neq, FoldedConst::Int(a), FoldedConst::Int(b)) => {
                Some(FoldedConst::Bool(a != b))
            }
            (BinOp::Lt, FoldedConst::Int(a), FoldedConst::Int(b)) => Some(FoldedConst::Bool(a < b)),
            (BinOp::LtEq, FoldedConst::Int(a), FoldedConst::Int(b)) => {
                Some(FoldedConst::Bool(a <= b))
            }
            (BinOp::Gt, FoldedConst::Int(a), FoldedConst::Int(b)) => Some(FoldedConst::Bool(a > b)),
            (BinOp::GtEq, FoldedConst::Int(a), FoldedConst::Int(b)) => {
                Some(FoldedConst::Bool(a >= b))
            }
            // Bool comparisons
            (BinOp::Eq, FoldedConst::Bool(a), FoldedConst::Bool(b)) => {
                Some(FoldedConst::Bool(a == b))
            }
            (BinOp::Neq, FoldedConst::Bool(a), FoldedConst::Bool(b)) => {
                Some(FoldedConst::Bool(a != b))
            }
            // String concat
            (BinOp::Concat, FoldedConst::Str(a), FoldedConst::Str(b)) => {
                Some(FoldedConst::Str(a + &b))
            }
            _ => None,
        }
    }

    pub(super) fn new(
        name: &str,
        effect_routing: HashMap<crate::token::Span, Vec<String>>,
    ) -> Self {
        Self {
            chunk: Chunk::new(name),
            scope: Scope::new(),
            in_tail: false,
            loop_stack: Vec::new(),
            handler_ctx: None,
            effect_ops: HashMap::new(),
            field_registry: HashMap::new(),
            pat_scratch_id: 0,
            handler_decls: HashMap::new(),
            evidence_slots: HashMap::new(),
            evidence_state: None,
            effect_routing,
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
            Item::TypeAlias(_) => {
                // Type aliases are resolved at check time. No codegen needed —
                // refinement predicates are erased at runtime (zero cost).
                Ok(())
            }
            Item::HandlerDecl(decl) => {
                let mut clauses = Vec::new();
                // If base handler exists, start with its clauses
                if let Some(base_name) = &decl.base {
                    if let Some((base_clauses, _)) = self.handler_decls.get(base_name) {
                        clauses = base_clauses.clone();
                    }
                }
                // Overlay: new clauses with same op_name replace base clauses
                for clause in &decl.clauses {
                    if let HandlerOp::OpHandler { op_name, .. } = &clause.operation {
                        clauses.retain(|c| match &c.operation {
                            HandlerOp::OpHandler { op_name: n, .. } => n != op_name,
                            _ => true,
                        });
                    }
                    clauses.push(clause.clone());
                }
                self.handler_decls
                    .insert(decl.name.clone(), (clauses, decl.state_bindings.clone()));
                Ok(())
            }
            // Trait/impl declarations don't generate code.
            // Imports are resolved before compilation.
            Item::TraitDecl(_) | Item::ImplBlock(_) | Item::Import(_) => Ok(()),
        }
    }

    fn compile_fn_decl(&mut self, fd: &FnDecl) -> Result<(), LuxError> {
        let line = Self::current_line(&fd.span);

        // Save enclosing scope so the inner compiler can capture upvalues
        let outer_scope = std::mem::replace(&mut self.scope, Scope::new());

        // Compile function body in a nested compiler
        let mut fn_compiler = Compiler::new(&fd.name, self.effect_routing.clone());
        fn_compiler.effect_ops = self.effect_ops.clone();
        fn_compiler.field_registry = self.field_registry.clone();
        fn_compiler.handler_decls = self.handler_decls.clone();
        fn_compiler.scope.enclosing = Some(Box::new(outer_scope));
        fn_compiler.scope.begin_scope();

        // Declare parameters as locals
        // First pass: declare all param locals (including destructured tuple slots)
        let mut destruct_params: Vec<(u16, String)> = Vec::new();
        for param in &fd.params {
            if param.name.starts_with('(') {
                let slot = fn_compiler.scope.declare_local(&param.name);
                destruct_params.push((slot, param.name.clone()));
            } else {
                fn_compiler.scope.declare_local(&param.name);
            }
        }
        // Second pass: emit destructuring bytecode (runs after VM pre-fills extra locals)
        for (slot, name) in &destruct_params {
            fn_compiler.emit_destructured_param(*slot, name, line);
        }

        // Compile body
        fn_compiler.in_tail = true;
        fn_compiler.compile_expr(&fd.body)?;
        fn_compiler.emit_op(OpCode::Return, line);

        // Extract upvalue descriptors before finishing
        let upvalues: Vec<_> = fn_compiler.scope.upvalues.clone();
        // Restore enclosing scope
        let enclosing = fn_compiler.scope.enclosing.take().unwrap();
        self.scope = *enclosing;

        let mut proto = fn_compiler.finish();
        proto.arity = fd.params.len() as u16;

        // Create closure and emit upvalue descriptors
        let proto_idx = self.chunk.add_constant(Constant::FnProto(Arc::new(proto)));
        self.emit_op(OpCode::MakeClosure, line);
        self.emit_u16(proto_idx, line);
        for uv in &upvalues {
            self.emit_u8(u8::from(uv.is_local), line);
            self.emit_u16(uv.index, line);
        }

        // Always store as global — enables recursive calls by name lookup
        let name_idx = self.chunk.intern_name(&fd.name);
        self.emit_op(OpCode::StoreGlobal, line);
        self.emit_u16(name_idx, line);

        Ok(())
    }

    fn compile_let_decl(&mut self, ld: &LetDecl) -> Result<(), LuxError> {
        let line = Self::current_line(&ld.span);
        self.compile_expr(&ld.value)?;

        match &ld.pattern {
            Pattern::Binding(name, _) => {
                if self.scope.scope_depth > 0 {
                    self.scope.declare_local(name);
                } else {
                    let name_idx = self.chunk.intern_name(name);
                    self.emit_op(OpCode::StoreGlobal, line);
                    self.emit_u16(name_idx, line);
                }
            }
            _ => {
                if self.scope.scope_depth > 0 {
                    self.compile_pattern_bind(&ld.pattern, line)?;
                } else {
                    self.compile_let_pattern_global(&ld.pattern, line)?;
                }
            }
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

                // ── Constant folding ─────────────────────────────
                // If both operands are compile-time constants, evaluate
                // now and emit a single load instruction. The compiler
                // KNOWS this is safe because it has proven purity.
                if let Some(folded) = Self::try_const_fold(op, left, right) {
                    match folded {
                        FoldedConst::Int(n) => {
                            if (-128..=127).contains(&n) {
                                self.emit_op(OpCode::LoadInt, line);
                                self.emit_u8(n as i8 as u8, line);
                            } else {
                                self.emit_constant(Constant::Int(n), line);
                            }
                        }
                        FoldedConst::Float(f) => {
                            self.emit_constant(Constant::Float(f), line);
                        }
                        FoldedConst::Bool(b) => {
                            self.emit_op(OpCode::LoadBool, line);
                            self.emit_u8(u8::from(b), line);
                        }
                        FoldedConst::Str(s) => {
                            self.emit_constant(Constant::String(Arc::new(s)), line);
                        }
                    }
                    return Ok(());
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
                // Constant fold unary ops too
                if let Some(val) = Self::try_eval_const(operand) {
                    let folded = match (op, val) {
                        (UnaryOp::Neg, FoldedConst::Int(n)) => Some(FoldedConst::Int(-n)),
                        (UnaryOp::Neg, FoldedConst::Float(f)) => Some(FoldedConst::Float(-f)),
                        (UnaryOp::Not, FoldedConst::Bool(b)) => Some(FoldedConst::Bool(!b)),
                        _ => None,
                    };
                    if let Some(result) = folded {
                        match result {
                            FoldedConst::Int(n) if (-128..=127).contains(&n) => {
                                self.emit_op(OpCode::LoadInt, line);
                                self.emit_u8(n as i8 as u8, line);
                            }
                            FoldedConst::Int(n) => {
                                self.emit_constant(Constant::Int(n), line);
                            }
                            FoldedConst::Float(f) => {
                                self.emit_constant(Constant::Float(f), line);
                            }
                            FoldedConst::Bool(b) => {
                                self.emit_op(OpCode::LoadBool, line);
                                self.emit_u8(u8::from(b), line);
                            }
                            _ => {}
                        }
                        return Ok(());
                    }
                }
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

                // ── Dead branch elimination ──────────────────────
                // If the condition is a compile-time constant, emit
                // only the taken branch. No jumps, no dead code.
                if let Some(FoldedConst::Bool(cond_val)) = Self::try_eval_const(condition) {
                    if cond_val {
                        self.compile_expr(then_branch)?;
                    } else if let Some(else_br) = else_branch {
                        self.compile_expr(else_br)?;
                    } else {
                        self.emit_op(OpCode::LoadUnit, line);
                    }
                    return Ok(());
                }

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
                // Use a unique temp name per block to prevent nested blocks
                // from clobbering each other's results.
                if pops > 0 {
                    let tmp_id = self.pat_scratch_id;
                    self.pat_scratch_id += 1;
                    let temp_name = format!("__blk_tmp_{tmp_id}__");
                    let temp_idx = self.chunk.intern_name(&temp_name);
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
                pattern,
                value,
                span,
                ..
            } => {
                let line = Self::current_line(span);
                self.compile_expr(value)?;
                match pattern {
                    Pattern::Binding(name, _) => {
                        self.scope.declare_local(name);
                    }
                    _ => {
                        self.compile_pattern_bind(pattern, line)?;
                    }
                }
                // Let expression evaluates to Unit
                self.emit_op(OpCode::LoadUnit, line);
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

                // Load len(list) — called each iteration for correctness
                // (caching in a local shifts slot indices and breaks evidence-passing)
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

            Expr::FanOut { left, right, span } => {
                let line = Self::current_line(span);
                // a <| (f, g, h) compiles to (f(a), g(a), h(a))
                // For now: desugar single function case a <| f → f(a)
                if let Expr::Tuple(elements, _) = right.as_ref() {
                    // Fan-out: apply left to each function, collect into tuple
                    for func in elements {
                        self.compile_expr(func)?;
                        self.compile_expr(left)?;
                        self.emit_op(OpCode::Call, line);
                        self.emit_u8(1, line);
                    }
                    self.emit_op(OpCode::MakeTuple, line);
                    self.emit_u8(elements.len() as u8, line);
                } else {
                    // Single function: a <| f → f(a)
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
                let mut fn_compiler = Compiler::new("<lambda>", self.effect_routing.clone());
                fn_compiler.effect_ops = self.effect_ops.clone();
                fn_compiler.field_registry = self.field_registry.clone();
                fn_compiler.handler_decls = self.handler_decls.clone();
                fn_compiler.scope.enclosing = Some(Box::new(outer_scope));
                fn_compiler.scope.begin_scope();

                let mut destruct_params: Vec<(u16, String)> = Vec::new();
                for param in params {
                    if param.name.starts_with('(') {
                        let slot = fn_compiler.scope.declare_local(&param.name);
                        destruct_params.push((slot, param.name.clone()));
                    } else {
                        fn_compiler.scope.declare_local(&param.name);
                    }
                }
                for (slot, name) in &destruct_params {
                    fn_compiler.emit_destructured_param(*slot, name, line);
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
                    self.emit_op(OpCode::Pop, line); // pop test result (true)
                    self.emit_op(OpCode::Pop, line); // pop test scrutinee copy

                    // Load fresh scrutinee for pattern binding and track it
                    self.emit_op(OpCode::LoadLocal, line);
                    self.emit_u16(scrutinee_slot, line);

                    // Bind pattern variables — pattern_bind consumes the
                    // bind copy from TOS and pushes bound locals.
                    self.scope.begin_scope();
                    self.compile_pattern_bind(&arm.pattern, line)?;

                    // Compile guard if present
                    if let Some(guard) = &arm.guard {
                        self.compile_expr(guard)?;
                        let guard_fail = self.emit_jump(OpCode::JumpIfFalse, line);
                        self.emit_op(OpCode::Pop, line); // pop guard result

                        // Compile arm body
                        self.compile_expr(&arm.body)?;
                        // end_scope once — save pops count for both paths
                        let pops = self.scope.end_scope();
                        if pops > 0 {
                            let temp_idx = self.chunk.intern_name("__arm_tmp__");
                            self.emit_op(OpCode::StoreGlobal, line);
                            self.emit_u16(temp_idx, line);
                            for _ in 0..pops {
                                self.emit_op(OpCode::Pop, line);
                            }
                            self.emit_op(OpCode::LoadGlobal, line);
                            self.emit_u16(temp_idx, line);
                        }
                        let end = self.emit_jump(OpCode::Jump, line);
                        end_patches.push(end);

                        // Guard fail: pop guard result + same bindings count
                        self.patch_jump(guard_fail);
                        self.emit_op(OpCode::Pop, line); // pop guard false
                        for _ in 0..pops {
                            self.emit_op(OpCode::Pop, line);
                        }
                        continue;
                    }

                    // Compile arm body
                    self.compile_expr(&arm.body)?;
                    let pops = self.scope.end_scope();
                    if pops > 0 {
                        let temp_idx = self.chunk.intern_name("__arm_tmp__");
                        self.emit_op(OpCode::StoreGlobal, line);
                        self.emit_u16(temp_idx, line);
                        for _ in 0..pops {
                            self.emit_op(OpCode::Pop, line);
                        }
                        self.emit_op(OpCode::LoadGlobal, line);
                        self.emit_u16(temp_idx, line);
                    }
                    let end = self.emit_jump(OpCode::Jump, line);
                    end_patches.push(end);

                    self.patch_jump(skip);
                    self.emit_op(OpCode::Pop, line); // pop test result (false)
                    self.emit_op(OpCode::Pop, line); // pop test scrutinee copy
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

            Expr::RecordLit { fields, span } => {
                let line = Self::current_line(span);
                // Sort by field name — same canonical order as the type checker.
                // { y: 4, x: 3 } and { x: 3, y: 4 } have identical layout.
                let mut sorted: Vec<(&String, &Expr)> =
                    fields.iter().map(|(n, e)| (n, e)).collect();
                sorted.sort_by_key(|(n, _)| n.as_str());

                for (_, value) in &sorted {
                    self.compile_expr(value)?;
                }

                // Use a unique schema tag derived from sorted field names so that
                // records with different schemas don't collide in the field registry.
                // { x, y } → "#record:x,y"  |  { age, name } → "#record:age,name"
                let field_names: Vec<String> = sorted.iter().map(|(n, _)| (*n).clone()).collect();
                let schema_tag = format!("#record:{}", field_names.join(","));
                self.field_registry.insert(schema_tag.clone(), field_names);

                let tag_idx = self.chunk.intern_name(&schema_tag);
                self.emit_op(OpCode::MakeVariant, line);
                self.emit_u16(tag_idx, line);
                self.emit_u16(sorted.len() as u16, line);
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
        // If this is a known effect operation, emit a wrapper closure.
        // Effect ops are compiled as Perform when called directly (e.g. resolve(ty)),
        // but when used as a bare value (e.g. map(resolve, xs)), they need to be
        // wrapped in a closure so they're first-class: |x| resolve(x)
        if self.scope.scope_depth > 0 {
            if let Some(_effect_name) = self.effect_ops.get(name).cloned() {
                // Build a wrapper closure: fn(arg) { Perform op_name 1; Return }
                let outer_scope = std::mem::replace(&mut self.scope, super::scope::Scope::new());
                let mut wrapper =
                    Compiler::new(&format!("<effect:{name}>"), self.effect_routing.clone());
                wrapper.effect_ops = self.effect_ops.clone();
                wrapper.scope.enclosing = Some(Box::new(outer_scope));
                wrapper.scope.begin_scope();
                wrapper.scope.declare_local("__arg__");

                // Check if this op should use evidence dispatch
                if let Some(&ev_local) = self.evidence_slots.get(name) {
                    // Evidence path
                    wrapper.emit_op(OpCode::LoadLocal, line);
                    wrapper.emit_u16(0, line); // __arg__
                    wrapper.emit_op(OpCode::PerformEvidence, line);
                    wrapper.emit_u16(ev_local, line);
                    let op_name_idx = wrapper.chunk.intern_name(name);
                    wrapper.emit_u16(op_name_idx, line);
                    wrapper.emit_u8(1, line);
                } else {
                    // Normal Perform path
                    wrapper.emit_op(OpCode::LoadLocal, line);
                    wrapper.emit_u16(0, line); // __arg__
                    let op_name_idx = wrapper.chunk.intern_name(name);
                    wrapper.emit_op(OpCode::Perform, line);
                    wrapper.emit_u16(op_name_idx, line);
                    wrapper.emit_u8(1, line); // 1 argument
                }

                wrapper.emit_op(OpCode::Return, line);

                let upvalues: Vec<_> = wrapper.scope.upvalues.clone();
                let enclosing = wrapper.scope.enclosing.take().unwrap();
                self.scope = *enclosing;

                let mut proto = wrapper.finish();
                proto.arity = 1;

                let proto_idx = self.chunk.add_constant(Constant::FnProto(Arc::new(proto)));
                self.emit_op(OpCode::MakeClosure, line);
                self.emit_u16(proto_idx, line);
                for uv in &upvalues {
                    self.emit_u8(u8::from(uv.is_local), line);
                    self.emit_u16(uv.index, line);
                }
                return;
            }
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

    /// Emit destructuring bytecode for a tuple parameter.
    ///
    /// The raw tuple lives at `tuple_slot`. This method:
    /// 1. Parses "(n, _)" into element names
    /// 2. Emits LoadLocal + LoadInt(i) + ListIndex for each named element
    /// 3. Stores the extracted value into a new local via StoreLocal
    ///
    /// Element locals are declared here (they become extra locals that the
    /// VM pre-fills with Unit — our bytecode overwrites them immediately).
    fn emit_destructured_param(&mut self, tuple_slot: u16, name: &str, line: u32) {
        let inner = name.trim_start_matches('(').trim_end_matches(')');
        let elements: Vec<&str> = inner.split(", ").collect();

        for (i, elem_name) in elements.iter().enumerate() {
            let elem_name = elem_name.trim();
            if elem_name == "_" {
                continue; // Skip wildcards — no local needed
            }
            // Declare a local for this element (gets a pre-filled Unit slot)
            let elem_slot = self.scope.declare_local(elem_name);
            // Emit bytecode to extract tuple[i] and store into the local
            self.emit_op(OpCode::LoadLocal, line);
            self.emit_u16(tuple_slot, line);
            if i <= 127 {
                self.emit_op(OpCode::LoadInt, line);
                self.emit_u8(i as u8, line);
            } else {
                self.emit_constant(Constant::Int(i as i64), line);
            }
            self.emit_op(OpCode::ListIndex, line);
            self.emit_op(OpCode::StoreLocal, line);
            self.emit_u16(elem_slot, line);
            self.emit_op(OpCode::Pop, line); // StoreLocal leaves value on stack
        }
    }
}
