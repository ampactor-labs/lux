//! Effect compilation: Handle, Perform, Resume → bytecode.
//!
//! Handler bodies are compiled as separate `FnProto`s (their own call frames),
//! which naturally handles cross-frame effect dispatch. State variables are
//! passed as extra parameters after the effect operation's parameters.

use std::collections::HashMap;
use std::sync::Arc;

use crate::ast::{Expr, HandlerOp, StateBinding, StateUpdate, Stmt};
use crate::error::LuxError;
use crate::vm::chunk::{Constant, HandlerEntry, HandlerTable};
use crate::vm::opcode::OpCode;

use super::compiler::Compiler;

/// Context for compiling `resume` expressions inside handler bodies.
/// Maps state variable names to their indices in the handler's state array.
pub(super) struct HandlerCtx {
    pub state_names: Vec<String>,
    /// True if every handler clause in this handler is tail-resumptive.
    pub tail_resumptive: bool,
    /// True if compiling in evidence mode (resume → Return, not Resume opcode).
    pub evidence_mode: bool,
}

/// Returns true if `expr` contains an `Expr::Perform` or a `Call` to a known effect op.
///
/// Conservative: returns `true` when uncertain (e.g., opaque sub-expressions).
fn contains_effect_call(expr: &Expr, effect_ops: &HashMap<String, String>) -> bool {
    match expr {
        Expr::Perform { .. } => true,
        Expr::Call { func, args, .. } => {
            // A call whose function is a bare name that is a known effect op.
            let callee_is_op =
                matches!(func.as_ref(), Expr::Var(name, _) if effect_ops.contains_key(name));
            if callee_is_op {
                return true;
            }
            contains_effect_call(func, effect_ops)
                || args.iter().any(|a| contains_effect_call(a, effect_ops))
        }
        Expr::Block { stmts, expr, .. } => {
            stmts
                .iter()
                .any(|s| stmt_contains_effect_call(s, effect_ops))
                || expr
                    .as_ref()
                    .is_some_and(|e| contains_effect_call(e, effect_ops))
        }
        Expr::Resume {
            value,
            state_updates,
            ..
        } => {
            contains_effect_call(value, effect_ops)
                || state_updates
                    .iter()
                    .any(|u| contains_effect_call(&u.value, effect_ops))
        }
        Expr::If {
            condition,
            then_branch,
            else_branch,
            ..
        } => {
            contains_effect_call(condition, effect_ops)
                || contains_effect_call(then_branch, effect_ops)
                || else_branch
                    .as_ref()
                    .is_some_and(|e| contains_effect_call(e, effect_ops))
        }
        Expr::Match {
            scrutinee, arms, ..
        } => {
            contains_effect_call(scrutinee, effect_ops)
                || arms
                    .iter()
                    .any(|a| contains_effect_call(&a.body, effect_ops))
        }
        Expr::BinOp { left, right, .. } => {
            contains_effect_call(left, effect_ops) || contains_effect_call(right, effect_ops)
        }
        Expr::UnaryOp { operand, .. } => contains_effect_call(operand, effect_ops),
        Expr::Pipe { left, right, .. } => {
            contains_effect_call(left, effect_ops) || contains_effect_call(right, effect_ops)
        }
        Expr::Return { value, .. } => contains_effect_call(value, effect_ops),
        Expr::Lambda { .. } => {
            // Lambda bodies are a separate scope; conservatively say no effect call
            // at this level (the lambda is not immediately invoked).
            false
        }
        // Literals, Var, FieldAccess, Index, StringInterp, Handle, Assert — conservatively false.
        _ => false,
    }
}

fn stmt_contains_effect_call(stmt: &Stmt, effect_ops: &HashMap<String, String>) -> bool {
    match stmt {
        Stmt::Expr(e) => contains_effect_call(e, effect_ops),
        Stmt::Let(decl) => contains_effect_call(&decl.value, effect_ops),
        Stmt::FnDecl(_) => false,
    }
}

/// Returns true if the handler body is tail-resumptive.
///
/// A handler is tail-resumptive when it always `resume`s with a plain value —
/// no state updates, and the resumed value itself contains no effect calls.
/// This means the continuation is never needed.
fn is_tail_resumptive(body: &Expr, effect_ops: &HashMap<String, String>) -> bool {
    match body {
        Expr::Resume {
            state_updates,
            value,
            ..
        } => state_updates.is_empty() && !contains_effect_call(value, effect_ops),
        Expr::Block { stmts, expr, .. } => {
            // Statements must not contain effect calls.
            if stmts
                .iter()
                .any(|s| stmt_contains_effect_call(s, effect_ops))
            {
                return false;
            }
            // Final expression must itself be tail-resumptive.
            match expr {
                Some(e) => is_tail_resumptive(e, effect_ops),
                None => false,
            }
        }
        _ => false,
    }
}

/// Evidence-eligible: resume in tail position (with or without state updates),
/// resumed value contains no effect calls. The handler never needs a continuation.
///
/// Key difference from `is_tail_resumptive`: state updates ARE allowed.
/// Evidence-eligible handlers return state as part of their return value
/// rather than writing it to the handler frame via the Resume opcode.
fn is_evidence_eligible(body: &Expr, effect_ops: &HashMap<String, String>) -> bool {
    match body {
        Expr::Resume { value, .. } => !contains_effect_call(value, effect_ops),
        Expr::Block { stmts, expr, .. } => {
            stmts
                .iter()
                .all(|s| !stmt_contains_effect_call(s, effect_ops))
                && expr
                    .as_ref()
                    .is_some_and(|e| is_evidence_eligible(e, effect_ops))
        }
        Expr::If {
            then_branch,
            else_branch,
            ..
        } => {
            is_evidence_eligible(then_branch, effect_ops)
                && else_branch
                    .as_ref()
                    .is_some_and(|e| is_evidence_eligible(e, effect_ops))
        }
        _ => false,
    }
}

impl Compiler {
    /// Compile a `handle { body } [with state = init, ...] { handlers }` expression.
    ///
    /// Each handler body becomes a separate `FnProto` stored in the chunk's
    /// constants. The `HandlerTable` maps operation names to these protos.
    pub(super) fn compile_handle(
        &mut self,
        body: &Expr,
        handlers: &[crate::ast::HandlerClause],
        state_bindings: &[StateBinding],
        span: &crate::token::Span,
    ) -> Result<(), LuxError> {
        let line = Self::current_line(span);

        // Collect all state bindings: named handler state first, then explicit overrides.
        // Explicit state bindings take priority — their names shadow base handler state.
        let mut all_state_bindings: Vec<StateBinding> = Vec::new();
        let mut seen_names = std::collections::HashSet::new();

        // Record names from explicit state bindings (they take priority)
        for binding in state_bindings {
            seen_names.insert(binding.name.clone());
        }

        // Add state bindings from UseHandler references (only if not overridden)
        for clause in handlers {
            if let HandlerOp::UseHandler { name } = &clause.operation {
                if let Some((_, base_state)) = self.handler_decls.get(name).cloned() {
                    for binding in base_state {
                        if !seen_names.contains(&binding.name) {
                            seen_names.insert(binding.name.clone());
                            all_state_bindings.push(binding);
                        }
                    }
                }
            }
        }

        // Then add explicit state bindings
        for binding in state_bindings {
            all_state_bindings.push(binding.clone());
        }

        // Compile state init expressions. Values are left on the stack
        // and consumed by PushHandler (stored in VmHandlerFrame.state).
        // State variables are NOT declared as locals — the handle body
        // only accesses state through effect operations, and handler bodies
        // receive state as FnProto parameters.
        for binding in &all_state_bindings {
            self.compile_expr(&binding.init)?;
        }
        let state_count = all_state_bindings.len();

        // Collect state variable names for handler body compilation.
        let state_names: Vec<String> = all_state_bindings
            .iter()
            .map(|sb| sb.name.clone())
            .collect();

        // Expand UseHandler references — two-pass for handler composition.
        let mut expanded: Vec<crate::ast::HandlerClause> = Vec::new();

        // First pass: collect base clauses from UseHandler references
        for clause in handlers {
            if let HandlerOp::UseHandler { name } = &clause.operation {
                if let Some((base_clauses, _)) = self.handler_decls.get(name).cloned() {
                    expanded.extend(base_clauses);
                }
            }
        }

        // Second pass: overlay inline OpHandler clauses (these win over base)
        for clause in handlers {
            if let HandlerOp::OpHandler { op_name, .. } = &clause.operation {
                expanded.retain(|c| match &c.operation {
                    HandlerOp::OpHandler { op_name: n, .. } => n != op_name,
                    _ => true,
                });
                expanded.push(clause.clone());
            }
        }

        // Check if ALL handler ops are evidence-eligible for optimized dispatch.
        let all_evidence_eligible = !expanded.is_empty()
            && expanded.iter().all(|clause| {
                matches!(&clause.operation, HandlerOp::OpHandler { body: hb, .. }
                    if is_evidence_eligible(hb, &self.effect_ops))
            });

        if all_evidence_eligible {
            self.compile_handle_evidence(body, &expanded, state_count, &state_names, line)
        } else {
            self.compile_handle_fallback(body, &expanded, state_count, &state_names, line)
        }
    }

    /// Fallback handle compilation: PushHandler/Perform/Resume/PopHandler path.
    fn compile_handle_fallback(
        &mut self,
        body: &Expr,
        expanded: &[crate::ast::HandlerClause],
        state_count: usize,
        state_names: &[String],
        line: u32,
    ) -> Result<(), LuxError> {
        // Compile each handler body as a separate FnProto.
        let mut table = HandlerTable {
            entries: Vec::new(),
        };
        for clause in expanded {
            if let HandlerOp::OpHandler {
                op_name,
                params,
                body: handler_body,
                ..
            } = &clause.operation
            {
                let proto =
                    self.compile_handler_body(op_name, params, handler_body, state_names, line)?;

                let proto_idx = self.chunk.add_constant(Constant::FnProto(Arc::new(proto)));
                let op_name_idx = self.chunk.intern_name(op_name);
                let tail_res = is_tail_resumptive(handler_body, &self.effect_ops);
                let ev_eligible = is_evidence_eligible(handler_body, &self.effect_ops);
                table.entries.push(HandlerEntry {
                    op_name_idx,
                    proto_idx,
                    param_count: params.len() as u8,
                    tail_resumptive: tail_res,
                    evidence_eligible: ev_eligible,
                });
            }
        }

        // Add handler table to chunk.
        let table_idx = self.chunk.handler_tables.len() as u16;
        self.chunk.handler_tables.push(table);

        // Emit PushHandler: table_idx, state_count.
        self.emit_op(OpCode::PushHandler, line);
        self.emit_u16(table_idx, line);
        self.emit_u16(0, line); // state_slot_base unused
        self.emit_u8(state_count as u8, line);

        // Compile handle body.
        self.compile_expr(body)?;

        // PopHandler (body completed normally, result is on TOS).
        self.emit_op(OpCode::PopHandler, line);

        Ok(())
    }

    /// Evidence-optimized handle compilation.
    ///
    /// Handler is still pushed onto the handler stack (for indirect effects via
    /// function calls), but direct effect operations in the body use
    /// `PerformEvidence` — a synchronous call through the evidence local that
    /// skips handler stack search and continuation capture.
    fn compile_handle_evidence(
        &mut self,
        body: &Expr,
        expanded: &[crate::ast::HandlerClause],
        state_count: usize,
        state_names: &[String],
        line: u32,
    ) -> Result<(), LuxError> {
        // 1. Compile normal handler bodies → handler table for PushHandler.
        let mut normal_table = HandlerTable {
            entries: Vec::new(),
        };
        for clause in expanded {
            if let HandlerOp::OpHandler {
                op_name,
                params,
                body: handler_body,
                ..
            } = &clause.operation
            {
                let proto =
                    self.compile_handler_body(op_name, params, handler_body, state_names, line)?;
                let proto_idx = self.chunk.add_constant(Constant::FnProto(Arc::new(proto)));
                let op_name_idx = self.chunk.intern_name(op_name);
                let tail_res = is_tail_resumptive(handler_body, &self.effect_ops);
                normal_table.entries.push(HandlerEntry {
                    op_name_idx,
                    proto_idx,
                    param_count: params.len() as u8,
                    tail_resumptive: tail_res,
                    evidence_eligible: true,
                });
            }
        }
        let normal_table_idx = self.chunk.handler_tables.len() as u16;
        self.chunk.handler_tables.push(normal_table);

        // 2. Compile evidence-mode handler bodies → handler table for PushEvidence.
        let mut ev_table = HandlerTable {
            entries: Vec::new(),
        };
        for clause in expanded {
            if let HandlerOp::OpHandler {
                op_name,
                params,
                body: handler_body,
                ..
            } = &clause.operation
            {
                let proto = self.compile_handler_body_evidence(
                    op_name,
                    params,
                    handler_body,
                    state_names,
                    line,
                )?;
                let proto_idx = self.chunk.add_constant(Constant::FnProto(Arc::new(proto)));
                let op_name_idx = self.chunk.intern_name(op_name);
                ev_table.entries.push(HandlerEntry {
                    op_name_idx,
                    proto_idx,
                    param_count: params.len() as u8,
                    tail_resumptive: true,
                    evidence_eligible: true,
                });
            }
        }
        let ev_table_idx = self.chunk.handler_tables.len() as u16;
        self.chunk.handler_tables.push(ev_table);

        // 3. Emit PushHandler (state inits consumed from stack, handler on stack).
        self.emit_op(OpCode::PushHandler, line);
        self.emit_u16(normal_table_idx, line);
        self.emit_u16(0, line);
        self.emit_u8(state_count as u8, line);

        // 4. Allocate evidence local.
        self.scope.begin_scope();
        self.emit_op(OpCode::LoadUnit, line);
        let ev_local = self.scope.declare_local("__evidence__");

        // 5. Emit PushEvidence (VM constructs VmEvidence, stores in ev_local).
        self.emit_op(OpCode::PushEvidence, line);
        self.emit_u16(ev_table_idx, line);
        self.emit_u16(ev_local, line);

        // 6. Set evidence_slots for body compilation.
        let saved_slots = std::mem::take(&mut self.evidence_slots);
        let saved_state = self.evidence_state.take();
        for clause in expanded {
            if let HandlerOp::OpHandler { op_name, .. } = &clause.operation {
                self.evidence_slots.insert(op_name.clone(), ev_local);
            }
        }

        // 7. Compile handle body (direct Performs → PerformEvidence).
        self.compile_expr(body)?;

        // 8. Restore evidence state.
        self.evidence_slots = saved_slots;
        self.evidence_state = saved_state;

        // 9. PopHandler (wraps result with state, pops handler from stack).
        self.emit_op(OpCode::PopHandler, line);

        // 10. Clean up evidence scope.
        let pops = self.scope.end_scope();
        if pops > 0 {
            let temp_idx = self.chunk.intern_name("__ev_tmp__");
            self.emit_op(OpCode::StoreGlobal, line);
            self.emit_u16(temp_idx, line);
            for _ in 0..pops {
                self.emit_op(OpCode::Pop, line);
            }
            self.emit_op(OpCode::LoadGlobal, line);
            self.emit_u16(temp_idx, line);
        }

        Ok(())
    }

    /// Compile a handler body as a standalone `FnProto`.
    ///
    /// Parameters: `[effect_params..., state_vars...]`
    /// The VM passes effect args and current state when dispatching.
    fn compile_handler_body(
        &mut self,
        op_name: &str,
        params: &[String],
        body: &Expr,
        state_names: &[String],
        line: u32,
    ) -> Result<crate::vm::chunk::FnProto, LuxError> {
        let mut sub = Compiler::new(&format!("handler:{op_name}"));
        sub.effect_ops = self.effect_ops.clone();
        sub.handler_decls = self.handler_decls.clone();
        sub.scope.begin_scope();

        // Declare effect params as locals.
        for param in params {
            sub.scope.declare_local(param);
        }

        // Declare state vars as locals (passed by VM as extra args).
        for name in state_names {
            sub.scope.declare_local(name);
        }

        // Declare `resume` as a local. For stateless handlers, the VM will
        // pass a VmContinuation as this parameter. For stateful handlers,
        // it stays Unit and the Resume opcode is used instead.
        sub.scope.declare_local("resume");

        // Set handler context so Resume can resolve state update names.
        let tail_res = is_tail_resumptive(body, &sub.effect_ops);
        sub.handler_ctx = Some(HandlerCtx {
            state_names: state_names.to_vec(),
            tail_resumptive: tail_res,
            evidence_mode: false,
        });

        // Compile handler body expression.
        sub.compile_expr(body)?;

        // Emit Return for the fall-through case (HandleDone — handler
        // returned without calling resume).
        sub.emit_op(OpCode::Return, line);

        let mut proto = sub.finish();
        // +1 for the `resume` parameter
        proto.arity = (params.len() + state_names.len() + 1) as u16;
        Ok(proto)
    }

    /// Compile a handler body in evidence mode — `resume` becomes `Return`.
    ///
    /// Parameters: `[effect_params..., state_vars...]` (no resume parameter).
    /// The handler body returns the resume value directly (stateless) or a
    /// tuple `(resume_value, new_state_0, ...)` (stateful).
    fn compile_handler_body_evidence(
        &mut self,
        op_name: &str,
        params: &[String],
        body: &Expr,
        state_names: &[String],
        line: u32,
    ) -> Result<crate::vm::chunk::FnProto, LuxError> {
        let mut sub = Compiler::new(&format!("handler:ev:{op_name}"));
        sub.effect_ops = self.effect_ops.clone();
        sub.handler_decls = self.handler_decls.clone();
        sub.scope.begin_scope();

        // Declare effect params as locals.
        for param in params {
            sub.scope.declare_local(param);
        }

        // Declare state vars as locals (passed by VM as extra args).
        for name in state_names {
            sub.scope.declare_local(name);
        }

        // NO resume parameter — evidence mode uses Return instead.

        sub.handler_ctx = Some(HandlerCtx {
            state_names: state_names.to_vec(),
            tail_resumptive: true,
            evidence_mode: true,
        });

        sub.compile_expr(body)?;
        sub.emit_op(OpCode::Return, line);

        let mut proto = sub.finish();
        proto.arity = (params.len() + state_names.len()) as u16;
        Ok(proto)
    }

    /// Compile a `perform Effect.op(args)` expression.
    ///
    /// Emits: `[args...] Perform op_name_idx argc`
    /// The VM dispatches to the nearest handler on the handler stack.
    pub(super) fn compile_perform(
        &mut self,
        _effect: &str,
        operation: &str,
        args: &[Expr],
        span: &crate::token::Span,
    ) -> Result<(), LuxError> {
        let line = Self::current_line(span);

        // Evidence path: direct call through evidence local (no handler stack search).
        if let Some(&ev_local) = self.evidence_slots.get(operation) {
            for arg in args {
                self.compile_expr(arg)?;
            }
            self.emit_op(OpCode::PerformEvidence, line);
            self.emit_u16(ev_local, line);
            let op_name_idx = self.chunk.intern_name(operation);
            self.emit_u16(op_name_idx, line);
            self.emit_u8(args.len() as u8, line);
            return Ok(());
        }

        // Normal path: handler stack search.
        for arg in args {
            self.compile_expr(arg)?;
        }
        let op_name_idx = self.chunk.intern_name(operation);
        self.emit_op(OpCode::Perform, line);
        self.emit_u16(op_name_idx, line);
        self.emit_u8(args.len() as u8, line);

        Ok(())
    }

    /// Compile a `resume(value) [with name = expr, ...]` expression.
    ///
    /// For stateless handlers (no state updates): compiles as a call to the
    /// `resume` local (which holds a VmContinuation at runtime).
    /// For stateful handlers: uses the Resume opcode for direct stack unwinding.
    pub(super) fn compile_resume(
        &mut self,
        value: &Expr,
        state_updates: &[StateUpdate],
        span: &crate::token::Span,
    ) -> Result<(), LuxError> {
        let line = Self::current_line(span);

        // Evidence mode: resume compiles to Return (value or state-return tuple).
        if self
            .handler_ctx
            .as_ref()
            .is_some_and(|ctx| ctx.evidence_mode)
        {
            let state_names = self.handler_ctx.as_ref().unwrap().state_names.clone();
            if state_updates.is_empty() && state_names.is_empty() {
                // Stateless: just return the resume value.
                self.compile_expr(value)?;
                self.emit_op(OpCode::Return, line);
            } else {
                // Stateful: return (resume_value, new_state_0, ...).
                self.compile_expr(value)?;
                for name in &state_names {
                    if let Some(update) = state_updates.iter().find(|u| u.name == *name) {
                        self.compile_expr(&update.value)?;
                    } else {
                        // State unchanged — load current value from local.
                        let slot = self.scope.resolve_local(name).unwrap();
                        self.emit_op(OpCode::LoadLocal, line);
                        self.emit_u16(slot, line);
                    }
                }
                self.emit_op(OpCode::MakeTuple, line);
                self.emit_u16((1 + state_names.len()) as u16, line);
                self.emit_op(OpCode::Return, line);
            }
            return Ok(());
        }

        // Multi-shot path: call the `resume` local/upvalue as a continuation.
        // Only when there are no state updates AND we know the handler is stateless.
        //
        // Three cases:
        // 1. handler_ctx with empty state_names → stateless handler body, use local
        // 2. handler_ctx with non-empty state_names → stateful handler, use Resume opcode
        // 3. handler_ctx is None → inside a lambda; if resume is an upvalue, it was
        //    captured from a handler body and IS a continuation, so use the call path
        let handler_is_stateful = self
            .handler_ctx
            .as_ref()
            .is_some_and(|ctx| !ctx.state_names.is_empty());

        let handler_is_tail_resumptive = self
            .handler_ctx
            .as_ref()
            .is_some_and(|ctx| ctx.tail_resumptive);

        if state_updates.is_empty() && !handler_is_stateful && !handler_is_tail_resumptive {
            if let Some(slot) = self.scope.resolve_local("resume") {
                self.emit_op(OpCode::LoadLocal, line);
                self.emit_u16(slot, line);
                self.compile_expr(value)?;
                self.emit_op(OpCode::Call, line);
                self.emit_u8(1, line);
                return Ok(());
            }
            // Also handle the case where resume is captured as an upvalue
            // (e.g., inside a lambda: `map(|x| resume(x), xs)`).
            if let Some(idx) = self.scope.resolve_upvalue("resume") {
                self.emit_op(OpCode::LoadUpval, line);
                self.emit_u16(idx, line);
                self.compile_expr(value)?;
                self.emit_op(OpCode::Call, line);
                self.emit_u8(1, line);
                return Ok(());
            }
        }

        // Stateful resume: use the Resume opcode for direct stack unwinding.
        self.compile_expr(value)?;
        for update in state_updates {
            self.compile_expr(&update.value)?;
        }
        self.emit_op(OpCode::Resume, line);
        self.emit_u8(state_updates.len() as u8, line);
        for update in state_updates {
            let offset = self
                .handler_ctx
                .as_ref()
                .and_then(|ctx| ctx.state_names.iter().position(|n| n == &update.name))
                .unwrap_or(0);
            self.emit_u16(offset as u16, line);
        }

        Ok(())
    }
}
