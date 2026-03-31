//! Pattern compilation: match tests and variable binding extraction.

use std::sync::Arc;

use crate::ast::*;
use crate::error::LuxError;
use crate::vm::chunk::Constant;
use crate::vm::opcode::OpCode;

use super::compiler::Compiler;

impl Compiler {
    /// Compile a pattern test — pushes bool onto stack.
    pub(super) fn compile_pattern_test(
        &mut self,
        pattern: &Pattern,
        line: u32,
    ) -> Result<(), LuxError> {
        match pattern {
            Pattern::Wildcard(_) | Pattern::Binding(_, _) => {
                self.emit_op(OpCode::MatchWildcard, line);
            }
            Pattern::Literal(lit, _) => match lit {
                LitPattern::Int(n) => {
                    let idx = self.chunk.add_constant(Constant::Int(*n));
                    self.emit_op(OpCode::MatchInt, line);
                    self.emit_u16(idx, line);
                }
                LitPattern::Float(n) => {
                    let idx = self.chunk.add_constant(Constant::Float(*n));
                    self.emit_op(OpCode::MatchInt, line); // reuse for float
                    self.emit_u16(idx, line);
                }
                LitPattern::String(s) => {
                    let idx = self
                        .chunk
                        .add_constant(Constant::String(Arc::new(s.clone())));
                    self.emit_op(OpCode::MatchString, line);
                    self.emit_u16(idx, line);
                }
                LitPattern::Bool(b) => {
                    self.emit_op(OpCode::MatchBool, line);
                    self.emit_u8(u8::from(*b), line);
                }
            },
            Pattern::Variant { name, fields, .. } => {
                let name_idx = self.chunk.intern_name(name);
                self.emit_op(OpCode::MatchVariant, line);
                self.emit_u16(name_idx, line);
                // For nested patterns, we'd need additional tests.
                // Simplified: assume variant match is sufficient for now.
                let _ = fields;
            }
            Pattern::Tuple(pats, _) => {
                self.emit_op(OpCode::MatchTuple, line);
                self.emit_u16(pats.len() as u16, line);
            }
            Pattern::List { elements, rest, .. } => {
                if elements.is_empty() && rest.is_none() {
                    self.emit_op(OpCode::MatchListEmpty, line);
                } else if rest.is_some() {
                    // Has rest pattern: match lists with >= N elements
                    self.emit_op(OpCode::MatchListCons, line);
                    self.emit_u16(elements.len() as u16, line);
                } else {
                    // No rest pattern: match lists with exactly N elements
                    self.emit_op(OpCode::MatchListExact, line);
                    self.emit_u16(elements.len() as u16, line);
                }
            }
            Pattern::Record { name, .. } => {
                let name_idx = self.chunk.intern_name(name);
                self.emit_op(OpCode::MatchVariant, line);
                self.emit_u16(name_idx, line);
            }
            Pattern::Or(alternatives, _) => {
                // Chain alternatives: test each, short-circuit on first match.
                let mut end_patches = Vec::new();
                for (i, alt) in alternatives.iter().enumerate() {
                    if i > 0 {
                        // Previous alternative was false — pop it and try next
                        self.emit_op(OpCode::Pop, line);
                    }
                    self.compile_pattern_test(alt, line)?;
                    if i < alternatives.len() - 1 {
                        // If true, skip remaining alternatives
                        let jump = self.emit_jump(OpCode::JumpIfTrue, line);
                        end_patches.push(jump);
                    }
                }
                // All end_patches jump here (with true on stack)
                for patch in end_patches {
                    self.patch_jump(patch);
                }
            }
        }
        Ok(())
    }

    /// Compile pattern bindings — extracts values and binds to local slots.
    pub(super) fn compile_pattern_bind(
        &mut self,
        pattern: &Pattern,
        line: u32,
    ) -> Result<(), LuxError> {
        match pattern {
            Pattern::Binding(name, _) => {
                // Bind copy on TOS becomes the local (no Dup needed).
                self.scope.declare_local(name);
            }
            Pattern::Variant { fields, .. } => {
                // Save scrutinee to global scratch so LoadGlobal can reload
                // it for each field (Dup from TOS gets clobbered by locals).
                self.pat_scratch_id += 1;
                let scratch_idx = self
                    .chunk
                    .intern_name(&format!("__pat_{}__", self.pat_scratch_id));
                self.emit_op(OpCode::StoreGlobal, line);
                self.emit_u16(scratch_idx, line);
                for (i, field_pat) in fields.iter().enumerate() {
                    self.emit_op(OpCode::LoadGlobal, line);
                    self.emit_u16(scratch_idx, line);
                    self.emit_op(OpCode::LoadInt, line);
                    self.emit_u8(i as u8, line);
                    self.emit_op(OpCode::ListIndex, line);
                    if let Pattern::Binding(name, _) = field_pat {
                        self.scope.declare_local(name);
                    } else {
                        self.compile_pattern_bind(field_pat, line)?;
                    }
                }
            }
            Pattern::Tuple(pats, _) => {
                // Save tuple to global scratch so LoadGlobal can reload it
                // for each element (Dup from TOS gets clobbered by locals
                // sharing the same stack positions).
                self.pat_scratch_id += 1;
                let scratch_idx = self
                    .chunk
                    .intern_name(&format!("__pat_{}__", self.pat_scratch_id));
                self.emit_op(OpCode::StoreGlobal, line);
                self.emit_u16(scratch_idx, line);
                for (i, pat) in pats.iter().enumerate() {
                    self.emit_op(OpCode::LoadGlobal, line);
                    self.emit_u16(scratch_idx, line);
                    self.emit_op(OpCode::LoadInt, line);
                    self.emit_u8(i as u8, line);
                    self.emit_op(OpCode::ListIndex, line);
                    if let Pattern::Binding(name, _) = pat {
                        self.scope.declare_local(name);
                    } else if matches!(pat, Pattern::Wildcard(_)) {
                        self.emit_op(OpCode::Pop, line);
                    } else {
                        self.compile_pattern_bind(pat, line)?;
                    }
                }
            }
            Pattern::Wildcard(_) | Pattern::Literal(_, _) => {
                // Consume bind copy — no binding needed
                self.emit_op(OpCode::Pop, line);
            }
            Pattern::Record { fields, .. } => {
                self.pat_scratch_id += 1;
                let scratch_idx = self
                    .chunk
                    .intern_name(&format!("__pat_{}__", self.pat_scratch_id));
                self.emit_op(OpCode::StoreGlobal, line);
                self.emit_u16(scratch_idx, line);
                for (field_name, field_pat) in fields {
                    self.emit_op(OpCode::LoadGlobal, line);
                    self.emit_u16(scratch_idx, line);
                    let name_idx = self.chunk.intern_name(field_name);
                    self.emit_op(OpCode::FieldAccess, line);
                    self.emit_u16(name_idx, line);
                    if let Pattern::Binding(name, _) = field_pat {
                        self.scope.declare_local(name);
                    } else {
                        self.compile_pattern_bind(field_pat, line)?;
                    }
                }
            }
            Pattern::List { elements, rest, .. } => {
                self.pat_scratch_id += 1;
                let scratch_idx = self
                    .chunk
                    .intern_name(&format!("__pat_{}__", self.pat_scratch_id));
                self.emit_op(OpCode::StoreGlobal, line);
                self.emit_u16(scratch_idx, line);
                for (i, elem_pat) in elements.iter().enumerate() {
                    self.emit_op(OpCode::LoadGlobal, line);
                    self.emit_u16(scratch_idx, line);
                    self.emit_op(OpCode::LoadInt, line);
                    self.emit_u8(i as u8, line);
                    self.emit_op(OpCode::ListIndex, line);
                    if let Pattern::Binding(name, _) = elem_pat {
                        self.scope.declare_local(name);
                    } else {
                        self.compile_pattern_bind(elem_pat, line)?;
                    }
                }
                if let Some(rest_pat) = rest {
                    if let Pattern::Binding(name, _) = rest_pat.as_ref() {
                        // Bind rest = slice(list, N, len(list))
                        self.compile_var_load("slice", line);
                        self.emit_op(OpCode::LoadGlobal, line);
                        self.emit_u16(scratch_idx, line);
                        let n = elements.len();
                        if n <= 127 {
                            self.emit_op(OpCode::LoadInt, line);
                            self.emit_u8(n as u8, line);
                        } else {
                            let idx = self.chunk.add_constant(Constant::Int(n as i64));
                            self.emit_op(OpCode::LoadConst, line);
                            self.emit_u16(idx, line);
                        }
                        self.compile_var_load("len", line);
                        self.emit_op(OpCode::LoadGlobal, line);
                        self.emit_u16(scratch_idx, line);
                        self.emit_op(OpCode::Call, line);
                        self.emit_u8(1, line);
                        self.emit_op(OpCode::Call, line);
                        self.emit_u8(3, line);
                        // rest_slice is on TOS — declare as local
                        self.scope.declare_local(name);
                    } else {
                        self.compile_pattern_bind(rest_pat, line)?;
                    }
                }
            }
            Pattern::Or(alternatives, _) => {
                // Bind from the first matching alternative
                if let Some(first) = alternatives.first() {
                    self.compile_pattern_bind(first, line)?;
                }
            }
        }
        Ok(())
    }

    /// Compile a let-destructuring pattern at global scope.
    /// Value is on TOS; saves to scratch global, then extracts each binding.
    pub(super) fn compile_let_pattern_global(
        &mut self,
        pat: &Pattern,
        line: u32,
    ) -> Result<(), LuxError> {
        self.pat_scratch_id += 1;
        let scratch = self
            .chunk
            .intern_name(&format!("__let_{}__", self.pat_scratch_id));
        self.emit_op(OpCode::StoreGlobal, line);
        self.emit_u16(scratch, line);

        match pat {
            Pattern::Binding(name, _) => {
                self.emit_op(OpCode::LoadGlobal, line);
                self.emit_u16(scratch, line);
                let idx = self.chunk.intern_name(name);
                self.emit_op(OpCode::StoreGlobal, line);
                self.emit_u16(idx, line);
            }
            Pattern::Tuple(pats, _) => {
                for (i, p) in pats.iter().enumerate() {
                    self.emit_op(OpCode::LoadGlobal, line);
                    self.emit_u16(scratch, line);
                    self.emit_op(OpCode::LoadInt, line);
                    self.emit_u8(i as u8, line);
                    self.emit_op(OpCode::ListIndex, line);
                    self.compile_let_pattern_global(p, line)?;
                }
            }
            Pattern::Variant {
                name: _,
                fields,
                span: _,
            } => {
                for (i, p) in fields.iter().enumerate() {
                    self.emit_op(OpCode::LoadGlobal, line);
                    self.emit_u16(scratch, line);
                    self.emit_op(OpCode::LoadInt, line);
                    self.emit_u8(i as u8, line);
                    self.emit_op(OpCode::ListIndex, line);
                    self.compile_let_pattern_global(p, line)?;
                }
            }
            Pattern::Wildcard(_) => {}
            _ => {}
        }
        Ok(())
    }
}
