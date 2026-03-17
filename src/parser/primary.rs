/// Primary expression parsing: literals, identifiers, records, collections, loops.
use crate::ast::*;
use crate::error::{LuxError, ParseError, ParseErrorKind};
use crate::token::{Span, StringInterpPart, TokenKind};

use super::Parser;

impl Parser {
    pub(crate) fn parse_primary(&mut self) -> Result<Expr, LuxError> {
        match self.peek().clone() {
            TokenKind::IntLit(_) => {
                let tok = self.advance();
                let val = match tok.kind {
                    TokenKind::IntLit(v) => v,
                    _ => unreachable!(),
                };
                Ok(Expr::IntLit(val, tok.span))
            }
            TokenKind::FloatLit(_) => {
                let tok = self.advance();
                let val = match tok.kind {
                    TokenKind::FloatLit(v) => v,
                    _ => unreachable!(),
                };
                Ok(Expr::FloatLit(val, tok.span))
            }
            TokenKind::StringLit(_) => {
                let tok = self.advance();
                let val = match tok.kind {
                    TokenKind::StringLit(v) => v,
                    _ => unreachable!(),
                };
                Ok(Expr::StringLit(val, tok.span))
            }
            TokenKind::StringInterp(_) => {
                let tok = self.advance();
                let raw_parts = match tok.kind {
                    TokenKind::StringInterp(p) => p,
                    _ => unreachable!(),
                };
                let mut string_parts = Vec::new();
                for part in raw_parts {
                    match part {
                        StringInterpPart::Literal(s) => {
                            string_parts.push(StringPart::Literal(s));
                        }
                        StringInterpPart::Tokens(tokens) => {
                            let mut sub_parser = Parser::from_tokens(tokens);
                            let expr = sub_parser.parse_expr()?;
                            string_parts.push(StringPart::Expr(expr));
                        }
                    }
                }
                Ok(Expr::StringInterp {
                    parts: string_parts,
                    span: tok.span,
                })
            }
            TokenKind::BoolLit(_) => {
                let tok = self.advance();
                let val = match tok.kind {
                    TokenKind::BoolLit(v) => v,
                    _ => unreachable!(),
                };
                Ok(Expr::BoolLit(val, tok.span))
            }
            TokenKind::Ident(_) => {
                let tok = self.advance();
                let name = match tok.kind {
                    TokenKind::Ident(n) => n,
                    _ => unreachable!(),
                };

                // `resume(val) with state = expr` — stateful resume
                // Plain `resume(val)` is a normal call (handled by postfix parsing).
                if name == "resume" && self.at_exact(&TokenKind::LParen) {
                    // Peek ahead: does `)` follow by `with`?
                    // Save pos, try parsing, backtrack if no `with`.
                    let saved = self.pos;
                    self.advance(); // consume `(`
                    let value = self.parse_expr()?;
                    self.expect(&TokenKind::RParen)?;
                    if self.at_exact(&TokenKind::With) {
                        // Stateful resume: parse state updates
                        self.advance();
                        let mut state_updates = Vec::new();
                        let mut end;
                        loop {
                            let update_span = self.peek_span();
                            let (uname, _) = self.expect_ident()?;
                            self.expect(&TokenKind::Eq)?;
                            let val_expr = self.parse_expr()?;
                            end = val_expr.span().end;
                            state_updates.push(StateUpdate {
                                name: uname,
                                value: val_expr,
                                span: Span::new(
                                    update_span.start,
                                    end,
                                    update_span.line,
                                    update_span.column,
                                ),
                            });
                            if !self.at_exact(&TokenKind::Comma) {
                                break;
                            }
                            let next = self
                                .tokens
                                .get(self.pos + 1)
                                .map(|t| &t.kind)
                                .unwrap_or(&TokenKind::Eof);
                            let next2 = self
                                .tokens
                                .get(self.pos + 2)
                                .map(|t| &t.kind)
                                .unwrap_or(&TokenKind::Eof);
                            if matches!(next, TokenKind::Ident(_)) && next2 == &TokenKind::Eq {
                                self.advance();
                            } else {
                                break;
                            }
                        }
                        let span = Span::new(tok.span.start, end, tok.span.line, tok.span.column);
                        return Ok(Expr::Resume {
                            value: Box::new(value),
                            state_updates,
                            span,
                        });
                    }
                    // No `with` — backtrack and let it be a normal call
                    self.pos = saved;
                }

                // Record construction: `Name { field: expr, ... }`
                // Only for uppercase names, and only when lookahead confirms
                // `{ ident : ...}` pattern (to avoid ambiguity with `Name { block }`)
                if name.chars().next().is_some_and(|c| c.is_uppercase())
                    && self.at_exact(&TokenKind::LBrace)
                    && self.is_record_construction_ahead()
                {
                    self.advance(); // consume `{`
                    let mut fields = Vec::new();
                    if !self.at_exact(&TokenKind::RBrace) {
                        loop {
                            let (field_name, _) = self.expect_ident()?;
                            let value = if self.at_exact(&TokenKind::Colon) {
                                self.advance();
                                self.parse_expr()?
                            } else {
                                // Shorthand: `{ name }` = `{ name: name }`
                                Expr::Var(field_name.clone(), self.peek_span())
                            };
                            fields.push((field_name, value));
                            if !self.at_exact(&TokenKind::Comma) {
                                break;
                            }
                            self.advance();
                            if self.at_exact(&TokenKind::RBrace) {
                                break;
                            }
                        }
                    }
                    let end_tok = self.expect(&TokenKind::RBrace)?;
                    let span = Span::new(
                        tok.span.start,
                        end_tok.span.end,
                        tok.span.line,
                        tok.span.column,
                    );
                    return Ok(Expr::RecordConstruct { name, fields, span });
                }
                Ok(Expr::Var(name, tok.span))
            }

            // Block expression
            TokenKind::LBrace => self.parse_block_expr(),

            // Parenthesized expression, unit `()`, or tuple `(a, b, ...)`
            TokenKind::LParen => {
                let start_span = self.peek_span();
                self.advance();
                if self.at_exact(&TokenKind::RParen) {
                    // Unit literal () — empty block evaluates to Unit
                    let end_tok = self.advance();
                    let span = Span::new(
                        start_span.start,
                        end_tok.span.end,
                        start_span.line,
                        start_span.column,
                    );
                    Ok(Expr::Block {
                        stmts: vec![],
                        expr: None,
                        span,
                    })
                } else {
                    let first = self.parse_expr()?;
                    if self.at_exact(&TokenKind::Comma) {
                        // Tuple literal
                        let mut elements = vec![first];
                        while self.at_exact(&TokenKind::Comma) {
                            self.advance();
                            if self.at_exact(&TokenKind::RParen) {
                                break; // trailing comma
                            }
                            elements.push(self.parse_expr()?);
                        }
                        let end_tok = self.expect(&TokenKind::RParen)?;
                        let span = Span::new(
                            start_span.start,
                            end_tok.span.end,
                            start_span.line,
                            start_span.column,
                        );
                        Ok(Expr::Tuple(elements, span))
                    } else {
                        self.expect(&TokenKind::RParen)?;
                        Ok(first)
                    }
                }
            }

            // List literal
            TokenKind::LBracket => {
                let start_span = self.peek_span();
                self.advance();
                let mut elements = Vec::new();
                if !self.at_exact(&TokenKind::RBracket) {
                    elements.push(self.parse_expr()?);
                    while self.at_exact(&TokenKind::Comma) {
                        self.advance();
                        if self.at_exact(&TokenKind::RBracket) {
                            break;
                        }
                        elements.push(self.parse_expr()?);
                    }
                }
                let end_tok = self.expect(&TokenKind::RBracket)?;
                let span = Span::new(
                    start_span.start,
                    end_tok.span.end,
                    start_span.line,
                    start_span.column,
                );
                Ok(Expr::List(elements, span))
            }

            // If expression
            TokenKind::If => self.parse_if_expr(),

            // Match expression
            TokenKind::Match => self.parse_match_expr(),

            // Let expression (in blocks)
            TokenKind::Let => {
                let decl = self.parse_let_decl()?;
                let span = decl.span.clone();
                Ok(Expr::Let {
                    name: decl.name,
                    type_ann: decl.type_ann,
                    value: Box::new(decl.value),
                    span,
                })
            }

            // Lambda: |params| body
            TokenKind::Pipe => self.parse_lambda(),

            // Handle expression
            TokenKind::Handle => self.parse_handle_expr(),

            // Resume expression: resume(val) with name = expr, ...
            // Only parsed when `with` state updates follow. Plain `resume(val)` is
            // a normal function call (resume is an Ident, goes through call_value).
            TokenKind::Resume => {
                // Legacy: if TokenKind::Resume still appears, handle it
                let tok = self.advance();
                self.expect(&TokenKind::LParen)?;
                let value = self.parse_expr()?;
                let rparen_tok = self.expect(&TokenKind::RParen)?;

                let mut state_updates = Vec::new();
                let mut end = rparen_tok.span.end;
                if self.at_exact(&TokenKind::With) {
                    self.advance();
                    loop {
                        let update_span = self.peek_span();
                        let (name, _) = self.expect_ident()?;
                        self.expect(&TokenKind::Eq)?;
                        let val_expr = self.parse_expr()?;
                        end = val_expr.span().end;
                        state_updates.push(StateUpdate {
                            name,
                            value: val_expr,
                            span: Span::new(
                                update_span.start,
                                end,
                                update_span.line,
                                update_span.column,
                            ),
                        });
                        // Comma is ambiguous: `resume(()) with a = 1, b = 2`
                        // vs handler clause separator `resume(()) with a = 1, next_op(...)`
                        // Disambiguate: comma followed by ident then `=` is another update.
                        if !self.at_exact(&TokenKind::Comma) {
                            break;
                        }
                        let next = self
                            .tokens
                            .get(self.pos + 1)
                            .map(|t| &t.kind)
                            .unwrap_or(&TokenKind::Eof);
                        let next2 = self
                            .tokens
                            .get(self.pos + 2)
                            .map(|t| &t.kind)
                            .unwrap_or(&TokenKind::Eof);
                        if matches!(next, TokenKind::Ident(_)) && next2 == &TokenKind::Eq {
                            self.advance(); // consume the comma
                        } else {
                            break; // comma belongs to handler clause separator
                        }
                    }
                }

                let span = Span::new(tok.span.start, end, tok.span.line, tok.span.column);
                Ok(Expr::Resume {
                    value: Box::new(value),
                    state_updates,
                    span,
                })
            }

            // Return expression
            TokenKind::Return => {
                let tok = self.advance();
                let value = self.parse_expr()?;
                let span = Span::new(
                    tok.span.start,
                    value.span().end,
                    tok.span.line,
                    tok.span.column,
                );
                Ok(Expr::Return {
                    value: Box::new(value),
                    span,
                })
            }

            // While loop
            TokenKind::While => {
                let tok = self.advance();
                let condition = self.parse_expr()?;
                let body = self.parse_block_expr()?;
                let span = Span::new(
                    tok.span.start,
                    body.span().end,
                    tok.span.line,
                    tok.span.column,
                );
                Ok(Expr::While {
                    condition: Box::new(condition),
                    body: Box::new(body),
                    span,
                })
            }

            // Infinite loop
            TokenKind::Loop => {
                let tok = self.advance();
                let body = self.parse_block_expr()?;
                let span = Span::new(
                    tok.span.start,
                    body.span().end,
                    tok.span.line,
                    tok.span.column,
                );
                Ok(Expr::Loop {
                    body: Box::new(body),
                    span,
                })
            }

            // For loop
            TokenKind::For => {
                let tok = self.advance();
                let binding_tok = self.advance();
                let binding = match binding_tok.kind {
                    TokenKind::Ident(name) => name,
                    other => {
                        return Err(ParseError {
                            kind: ParseErrorKind::UnexpectedToken {
                                expected: "identifier".to_string(),
                                found: format!("{other:?}"),
                            },
                            span: self.peek_span(),
                        }
                        .into());
                    }
                };
                self.expect(&TokenKind::In)?;
                let iterable = self.parse_expr()?;
                let body = self.parse_block_expr()?;
                let span = Span::new(
                    tok.span.start,
                    body.span().end,
                    tok.span.line,
                    tok.span.column,
                );
                Ok(Expr::For {
                    binding,
                    iterable: Box::new(iterable),
                    body: Box::new(body),
                    span,
                })
            }

            // Break
            TokenKind::Break => {
                let tok = self.advance();
                let value = if !self.at_exact(&TokenKind::RBrace)
                    && !self.at_exact(&TokenKind::Semicolon)
                    && !self.at_exact(&TokenKind::Eof)
                {
                    Some(Box::new(self.parse_expr()?))
                } else {
                    None
                };
                let end = value.as_ref().map(|v| v.span().end).unwrap_or(tok.span.end);
                let span = Span::new(tok.span.start, end, tok.span.line, tok.span.column);
                Ok(Expr::Break { value, span })
            }

            // Continue
            TokenKind::Continue => {
                let tok = self.advance();
                Ok(Expr::Continue { span: tok.span })
            }

            // Lambda with `||` (empty params — Or token is two pipes)
            TokenKind::Or => {
                let tok = self.advance();
                // `||` means empty param list for a lambda
                let body = self.parse_expr()?;
                let span = Span::new(
                    tok.span.start,
                    body.span().end,
                    tok.span.line,
                    tok.span.column,
                );
                Ok(Expr::Lambda {
                    params: Vec::new(),
                    body: Box::new(body),
                    span,
                })
            }

            TokenKind::Eof => Err(ParseError {
                kind: ParseErrorKind::UnexpectedEof,
                span: self.peek_span(),
            }
            .into()),

            _ => Err(ParseError {
                kind: ParseErrorKind::InvalidExpression,
                span: self.peek_span(),
            }
            .into()),
        }
    }
}
