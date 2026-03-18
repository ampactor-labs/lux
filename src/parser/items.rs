/// Top-level item parsing: fn, type, effect, trait, impl declarations.
use crate::ast::*;
use crate::error::LuxError;
use crate::token::{Span, TokenKind};

use super::Parser;

// ── Program & top-level items ────────────────────────────────────

impl Parser {
    pub(crate) fn parse_program(&mut self) -> Result<Vec<Item>, LuxError> {
        let mut items = Vec::new();
        self.skip_semis();
        while !self.at_exact(&TokenKind::Eof) {
            items.push(self.parse_item()?);
            self.skip_semis();
        }
        Ok(items)
    }

    pub(crate) fn parse_item(&mut self) -> Result<Item, LuxError> {
        match self.peek() {
            TokenKind::Fn => Ok(Item::FnDecl(self.parse_fn_decl()?)),
            TokenKind::Let => Ok(Item::LetDecl(self.parse_let_decl()?)),
            TokenKind::Type => Ok(Item::TypeDecl(self.parse_type_decl()?)),
            TokenKind::Effect => Ok(Item::EffectDecl(self.parse_effect_decl()?)),
            TokenKind::Trait => Ok(Item::TraitDecl(self.parse_trait_decl()?)),
            TokenKind::Impl => Ok(Item::ImplBlock(self.parse_impl_block()?)),
            TokenKind::Import => Ok(Item::Import(self.parse_import_decl()?)),
            _ => {
                let expr = self.parse_expr()?;
                Ok(Item::Expr(expr))
            }
        }
    }

    // ── import path/to/module [as alias]
    fn parse_import_decl(&mut self) -> Result<ImportDecl, LuxError> {
        let start_span = self.peek_span();
        self.expect(&TokenKind::Import)?;

        // Parse path segments separated by `/`.
        // Leading `./` means relative (`.` is Dot token, `/` is Slash).
        let mut path = Vec::new();

        // Handle leading `./` for relative imports
        if self.at_exact(&TokenKind::Dot) {
            path.push(".".to_string());
            self.advance(); // consume `.`
            self.expect(&TokenKind::Slash)?; // consume `/`
        }

        // First segment
        let (seg, _) = self.expect_ident()?;
        path.push(seg);

        // Additional `/segment` parts
        while self.at_exact(&TokenKind::Slash) {
            self.advance(); // consume `/`
            let (seg, _) = self.expect_ident()?;
            path.push(seg);
        }

        // Optional `as alias`
        let alias = if self.at_exact(&TokenKind::Ident("as".to_string())) {
            self.advance(); // consume `as`
            let (name, _) = self.expect_ident()?;
            Some(name)
        } else {
            None
        };

        let end = self
            .tokens
            .get(self.pos.saturating_sub(1))
            .map(|t| t.span.end)
            .unwrap_or(start_span.end);
        let span = Span::new(start_span.start, end, start_span.line, start_span.column);

        Ok(ImportDecl { path, alias, span })
    }

    // ── fn name(params) -> RetType with Effects { body }
    // ── fn name(params) -> RetType = expr
    pub(crate) fn parse_fn_decl(&mut self) -> Result<FnDecl, LuxError> {
        let start_span = self.peek_span();
        self.expect(&TokenKind::Fn)?;
        let (name, _) = self.expect_ident()?;

        // Parse optional type parameters <T, U, ...>
        let type_params = if self.at_exact(&TokenKind::Lt) {
            self.advance(); // consume <
            let mut params = Vec::new();
            if !self.at_exact(&TokenKind::Gt) {
                let (tp_name, _) = self.expect_ident()?;
                params.push(tp_name);
                while self.at_exact(&TokenKind::Comma) {
                    self.advance();
                    if self.at_exact(&TokenKind::Gt) {
                        break; // trailing comma
                    }
                    let (tp_name, _) = self.expect_ident()?;
                    params.push(tp_name);
                }
            }
            self.expect(&TokenKind::Gt)?;
            params
        } else {
            Vec::new()
        };

        self.expect(&TokenKind::LParen)?;
        let params = self.parse_params()?;
        self.expect(&TokenKind::RParen)?;

        let return_type = if self.at_exact(&TokenKind::Arrow) {
            self.advance();
            Some(self.parse_type_expr()?)
        } else {
            None
        };

        let effects = if self.at_exact(&TokenKind::With) {
            self.advance();
            self.parse_effect_refs()?
        } else {
            Vec::new()
        };

        let body = if self.at_exact(&TokenKind::Eq) {
            self.advance();
            self.parse_expr()?
        } else {
            self.parse_block_expr()?
        };

        let span = Span::new(
            start_span.start,
            body.span().end,
            start_span.line,
            start_span.column,
        );
        Ok(FnDecl {
            name,
            type_params,
            params,
            return_type,
            effects,
            body,
            span,
        })
    }

    pub(crate) fn parse_params(&mut self) -> Result<Vec<Param>, LuxError> {
        let mut params = Vec::new();
        if self.at_exact(&TokenKind::RParen) {
            return Ok(params);
        }
        params.push(self.parse_param()?);
        while self.at_exact(&TokenKind::Comma) {
            self.advance();
            if self.at_exact(&TokenKind::RParen) {
                break; // trailing comma
            }
            params.push(self.parse_param()?);
        }
        Ok(params)
    }

    pub(crate) fn parse_param(&mut self) -> Result<Param, LuxError> {
        let (name, span) = self.expect_ident()?;
        let type_ann = if self.at_exact(&TokenKind::Colon) {
            self.advance();
            Some(self.parse_type_expr()?)
        } else {
            None
        };
        Ok(Param {
            name,
            type_ann,
            span,
        })
    }

    pub(crate) fn parse_let_decl(&mut self) -> Result<LetDecl, LuxError> {
        let start_span = self.peek_span();
        self.expect(&TokenKind::Let)?;
        let (name, _) = self.expect_ident()?;
        let type_ann = if self.at_exact(&TokenKind::Colon) {
            self.advance();
            Some(self.parse_type_expr()?)
        } else {
            None
        };
        self.expect(&TokenKind::Eq)?;
        let value = self.parse_expr()?;
        let span = Span::new(
            start_span.start,
            value.span().end,
            start_span.line,
            start_span.column,
        );
        Ok(LetDecl {
            name,
            type_ann,
            value,
            span,
        })
    }

    // ── type Name<T> = Variant1(A) | Variant2(B)
    fn parse_type_decl(&mut self) -> Result<TypeDecl, LuxError> {
        let start_span = self.peek_span();
        self.expect(&TokenKind::Type)?;
        let (name, _) = self.expect_ident()?;

        let type_params = if self.at_exact(&TokenKind::Lt) {
            self.advance();
            let mut params = Vec::new();
            if !self.at_exact(&TokenKind::Gt) {
                let (p, _) = self.expect_ident()?;
                params.push(p);
                while self.at_exact(&TokenKind::Comma) {
                    self.advance();
                    let (p, _) = self.expect_ident()?;
                    params.push(p);
                }
            }
            self.expect(&TokenKind::Gt)?;
            params
        } else {
            Vec::new()
        };

        self.expect(&TokenKind::Eq)?;
        let mut variants = vec![self.parse_variant()?];
        while self.at_exact(&TokenKind::Pipe) {
            self.advance();
            variants.push(self.parse_variant()?);
        }

        let end = variants
            .last()
            .map(|v| v.span.end)
            .unwrap_or(start_span.end);
        let span = Span::new(start_span.start, end, start_span.line, start_span.column);
        Ok(TypeDecl {
            name,
            type_params,
            variants,
            span,
        })
    }

    fn parse_variant(&mut self) -> Result<Variant, LuxError> {
        let (name, span) = self.expect_ident()?;
        let mut fields = Vec::new();
        if self.at_exact(&TokenKind::LParen) {
            // Positional fields: Variant(Type, Type, ...)
            self.advance();
            if !self.at_exact(&TokenKind::RParen) {
                fields.push(VariantField {
                    name: None,
                    ty: self.parse_type_expr()?,
                });
                while self.at_exact(&TokenKind::Comma) {
                    self.advance();
                    if self.at_exact(&TokenKind::RParen) {
                        break;
                    }
                    fields.push(VariantField {
                        name: None,
                        ty: self.parse_type_expr()?,
                    });
                }
            }
            let end_tok = self.expect(&TokenKind::RParen)?;
            let end_span = Span::new(span.start, end_tok.span.end, span.line, span.column);
            Ok(Variant {
                name,
                fields,
                span: end_span,
            })
        } else if self.at_exact(&TokenKind::LBrace) {
            // Named fields: Variant { name: Type, name: Type, ... }
            self.advance();
            if !self.at_exact(&TokenKind::RBrace) {
                let (field_name, _) = self.expect_ident()?;
                self.expect(&TokenKind::Colon)?;
                let ty = self.parse_type_expr()?;
                fields.push(VariantField {
                    name: Some(field_name),
                    ty,
                });
                while self.at_exact(&TokenKind::Comma) {
                    self.advance();
                    if self.at_exact(&TokenKind::RBrace) {
                        break;
                    }
                    let (field_name, _) = self.expect_ident()?;
                    self.expect(&TokenKind::Colon)?;
                    let ty = self.parse_type_expr()?;
                    fields.push(VariantField {
                        name: Some(field_name),
                        ty,
                    });
                }
            }
            let end_tok = self.expect(&TokenKind::RBrace)?;
            let end_span = Span::new(span.start, end_tok.span.end, span.line, span.column);
            Ok(Variant {
                name,
                fields,
                span: end_span,
            })
        } else {
            Ok(Variant { name, fields, span })
        }
    }

    // ── effect Name<T> { op1(params) -> RetType \n op2(params) -> RetType }
    fn parse_effect_decl(&mut self) -> Result<EffectDecl, LuxError> {
        let start_span = self.peek_span();
        self.expect(&TokenKind::Effect)?;
        let (name, _) = self.expect_ident()?;

        let type_params = if self.at_exact(&TokenKind::Lt) {
            self.advance();
            let mut params = Vec::new();
            if !self.at_exact(&TokenKind::Gt) {
                let (p, _) = self.expect_ident()?;
                params.push(p);
                while self.at_exact(&TokenKind::Comma) {
                    self.advance();
                    let (p, _) = self.expect_ident()?;
                    params.push(p);
                }
            }
            self.expect(&TokenKind::Gt)?;
            params
        } else {
            Vec::new()
        };

        self.expect(&TokenKind::LBrace)?;
        self.skip_semis();

        let mut operations = Vec::new();
        while !self.at_exact(&TokenKind::RBrace) && !self.at_exact(&TokenKind::Eof) {
            operations.push(self.parse_effect_op()?);
            self.skip_semis();
        }

        let end_tok = self.expect(&TokenKind::RBrace)?;
        let span = Span::new(
            start_span.start,
            end_tok.span.end,
            start_span.line,
            start_span.column,
        );
        Ok(EffectDecl {
            name,
            type_params,
            operations,
            span,
        })
    }

    fn parse_effect_op(&mut self) -> Result<EffectOp, LuxError> {
        let (name, span) = self.expect_ident()?;
        self.expect(&TokenKind::LParen)?;
        let params = self.parse_params()?;
        self.expect(&TokenKind::RParen)?;
        self.expect(&TokenKind::Arrow)?;
        let return_type = self.parse_type_expr()?;
        let end = return_type.span().end;
        let op_span = Span::new(span.start, end, span.line, span.column);
        Ok(EffectOp {
            name,
            params,
            return_type,
            span: op_span,
        })
    }

    fn parse_trait_decl(&mut self) -> Result<TraitDecl, LuxError> {
        let start_span = self.peek_span();
        self.expect(&TokenKind::Trait)?;
        let (name, _) = self.expect_ident()?;
        self.expect(&TokenKind::LBrace)?;
        self.skip_semis();
        let mut methods = Vec::new();
        while !self.at_exact(&TokenKind::RBrace) && !self.at_exact(&TokenKind::Eof) {
            let method_start = self.peek_span();
            self.expect(&TokenKind::Fn)?;
            let (method_name, _) = self.expect_ident()?;
            self.expect(&TokenKind::LParen)?;
            let params = self.parse_params()?;
            self.expect(&TokenKind::RParen)?;
            let return_type = if self.at_exact(&TokenKind::Arrow) {
                self.advance();
                Some(self.parse_type_expr()?)
            } else {
                None
            };
            let method_end = return_type
                .as_ref()
                .map(|t| t.span().end)
                .unwrap_or(method_start.end);
            let method_span = Span::new(
                method_start.start,
                method_end,
                method_start.line,
                method_start.column,
            );
            methods.push(TraitMethod {
                name: method_name,
                params,
                return_type,
                span: method_span,
            });
            self.skip_semis();
        }
        let end_tok = self.expect(&TokenKind::RBrace)?;
        let span = Span::new(
            start_span.start,
            end_tok.span.end,
            start_span.line,
            start_span.column,
        );
        Ok(TraitDecl {
            name,
            methods,
            span,
        })
    }

    fn parse_impl_block(&mut self) -> Result<ImplBlock, LuxError> {
        let start_span = self.peek_span();
        self.expect(&TokenKind::Impl)?;
        let (trait_name, _) = self.expect_ident()?;
        self.expect(&TokenKind::For)?;
        let target_type = self.parse_type_expr()?;
        self.expect(&TokenKind::LBrace)?;
        self.skip_semis();
        let mut methods = Vec::new();
        while !self.at_exact(&TokenKind::RBrace) && !self.at_exact(&TokenKind::Eof) {
            methods.push(self.parse_fn_decl()?);
            self.skip_semis();
        }
        let end_tok = self.expect(&TokenKind::RBrace)?;
        let span = Span::new(
            start_span.start,
            end_tok.span.end,
            start_span.line,
            start_span.column,
        );
        Ok(ImplBlock {
            trait_name,
            target_type,
            methods,
            span,
        })
    }
}
