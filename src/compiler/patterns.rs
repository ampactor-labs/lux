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
                } else {
                    self.emit_op(OpCode::MatchListCons, line);
                    self.emit_u16(elements.len() as u16, line);
                }
            }
            Pattern::Record { name, .. } => {
                let name_idx = self.chunk.intern_name(name);
                self.emit_op(OpCode::MatchVariant, line);
                self.emit_u16(name_idx, line);
            }
            Pattern::Or(alternatives, _) => {
                // Compile first alternative; if true, done.
                // Otherwise try next, etc.
                if let Some(first) = alternatives.first() {
                    self.compile_pattern_test(first, line)?;
                    // For a full implementation, chain alternatives with JumpIfTrue.
                    // Simplified for now — just test first.
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
                // Dup the scrutinee and bind it
                self.emit_op(OpCode::Dup, line);
                self.scope.declare_local(name);
            }
            Pattern::Variant { fields, .. } => {
                for (i, field_pat) in fields.iter().enumerate() {
                    // For each field: dup scrutinee, extract field i, bind
                    self.emit_op(OpCode::Dup, line);
                    self.emit_op(OpCode::LoadInt, line);
                    self.emit_u8(i as u8, line);
                    self.emit_op(OpCode::ListIndex, line); // reuse for field extraction
                    self.compile_pattern_bind(field_pat, line)?;
                    if !matches!(field_pat, Pattern::Binding(_, _)) {
                        self.emit_op(OpCode::Pop, line);
                    }
                }
            }
            Pattern::Tuple(pats, _) => {
                for (i, pat) in pats.iter().enumerate() {
                    self.emit_op(OpCode::Dup, line);
                    self.emit_op(OpCode::LoadInt, line);
                    self.emit_u8(i as u8, line);
                    self.emit_op(OpCode::ListIndex, line);
                    self.compile_pattern_bind(pat, line)?;
                    if !matches!(pat, Pattern::Binding(_, _)) {
                        self.emit_op(OpCode::Pop, line);
                    }
                }
            }
            Pattern::Wildcard(_) | Pattern::Literal(_, _) => {
                // No bindings needed
            }
            Pattern::Record { fields, .. } => {
                for (field_name, field_pat) in fields {
                    self.emit_op(OpCode::Dup, line);
                    let name_idx = self.chunk.intern_name(field_name);
                    self.emit_op(OpCode::FieldAccess, line);
                    self.emit_u16(name_idx, line);
                    self.compile_pattern_bind(field_pat, line)?;
                    if !matches!(field_pat, Pattern::Binding(_, _)) {
                        self.emit_op(OpCode::Pop, line);
                    }
                }
            }
            Pattern::List { elements, rest, .. } => {
                for (i, elem_pat) in elements.iter().enumerate() {
                    self.emit_op(OpCode::Dup, line);
                    self.emit_op(OpCode::LoadInt, line);
                    self.emit_u8(i as u8, line);
                    self.emit_op(OpCode::ListIndex, line);
                    self.compile_pattern_bind(elem_pat, line)?;
                    if !matches!(elem_pat, Pattern::Binding(_, _)) {
                        self.emit_op(OpCode::Pop, line);
                    }
                }
                if let Some(rest_pat) = rest {
                    // Bind rest as list slice — simplified
                    self.compile_pattern_bind(rest_pat, line)?;
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
}
