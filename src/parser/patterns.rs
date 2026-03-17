/// Pattern matching parsing: wildcards, literals, variants, records, lists, or-patterns.
use crate::ast::*;
use crate::error::{LuxError, ParseError, ParseErrorKind};
use crate::token::{Span, TokenKind};

use super::Parser;

// ── Pattern span helper ──────────────────────────────────────────

impl Pattern {
    pub(crate) fn span(&self) -> &Span {
        match self {
            Pattern::Wildcard(s)
            | Pattern::Binding(_, s)
            | Pattern::Literal(_, s)
            | Pattern::Tuple(_, s)
            | Pattern::Or(_, s) => s,
            Pattern::Variant { span, .. }
            | Pattern::Record { span, .. }
            | Pattern::List { span, .. } => span,
        }
    }
}

// ── Pattern parsing ──────────────────────────────────────────────

impl Parser {
    pub(crate) fn parse_pattern(&mut self) -> Result<Pattern, LuxError> {
        let pat = self.parse_single_pattern()?;
        // Check for or-pattern: `A | B | C`
        if self.at_exact(&TokenKind::Pipe) {
            let start_span = pat.span().clone();
            let mut alternatives = vec![pat];
            while self.at_exact(&TokenKind::Pipe) {
                self.advance();
                alternatives.push(self.parse_single_pattern()?);
            }
            let end = alternatives.last().unwrap().span().end;
            let span = Span::new(start_span.start, end, start_span.line, start_span.column);
            Ok(Pattern::Or(alternatives, span))
        } else {
            Ok(pat)
        }
    }

    fn parse_single_pattern(&mut self) -> Result<Pattern, LuxError> {
        match self.peek().clone() {
            TokenKind::Underscore => {
                let tok = self.advance();
                Ok(Pattern::Wildcard(tok.span))
            }
            TokenKind::IntLit(_) => {
                let tok = self.advance();
                let val = match tok.kind {
                    TokenKind::IntLit(v) => v,
                    _ => unreachable!(),
                };
                Ok(Pattern::Literal(LitPattern::Int(val), tok.span))
            }
            TokenKind::FloatLit(_) => {
                let tok = self.advance();
                let val = match tok.kind {
                    TokenKind::FloatLit(v) => v,
                    _ => unreachable!(),
                };
                Ok(Pattern::Literal(LitPattern::Float(val), tok.span))
            }
            TokenKind::StringLit(_) => {
                let tok = self.advance();
                let val = match tok.kind {
                    TokenKind::StringLit(v) => v,
                    _ => unreachable!(),
                };
                Ok(Pattern::Literal(LitPattern::String(val), tok.span))
            }
            TokenKind::BoolLit(_) => {
                let tok = self.advance();
                let val = match tok.kind {
                    TokenKind::BoolLit(v) => v,
                    _ => unreachable!(),
                };
                Ok(Pattern::Literal(LitPattern::Bool(val), tok.span))
            }
            TokenKind::LParen => {
                let start_span = self.peek_span();
                self.advance();
                let mut pats = Vec::new();
                if !self.at_exact(&TokenKind::RParen) {
                    pats.push(self.parse_pattern()?);
                    while self.at_exact(&TokenKind::Comma) {
                        self.advance();
                        if self.at_exact(&TokenKind::RParen) {
                            break;
                        }
                        pats.push(self.parse_pattern()?);
                    }
                }
                let end_tok = self.expect(&TokenKind::RParen)?;
                let span = Span::new(
                    start_span.start,
                    end_tok.span.end,
                    start_span.line,
                    start_span.column,
                );
                Ok(Pattern::Tuple(pats, span))
            }
            // List pattern: [a, b, ...rest]
            TokenKind::LBracket => {
                let start_span = self.peek_span();
                self.advance();
                let mut elements = Vec::new();
                let mut rest = None;
                if !self.at_exact(&TokenKind::RBracket) {
                    // Check for `...name` spread
                    if self.at_exact(&TokenKind::DotDot) {
                        // We use `..` + ident for spread (parser sees DotDot then Dot then Ident, or we handle `...`)
                        // Actually `...` is not a single token. Let's check: DotDot (..) and Dot (.). So `...name` = DotDot + Dot? No.
                        // Let me handle this: `...` is DotDot + the next char. Actually the lexer
                        // would lex `...x` as DotDot, then `.x` or Dot + Ident.
                        // Simpler approach: use `...` as DotDot followed immediately by Dot.
                        self.advance(); // consume DotDot
                        if self.at_exact(&TokenKind::Dot) {
                            self.advance(); // consume Dot — now we have `...`
                        }
                        rest = Some(Box::new(self.parse_single_pattern()?));
                    } else {
                        elements.push(self.parse_pattern()?);
                        while self.at_exact(&TokenKind::Comma) {
                            self.advance();
                            if self.at_exact(&TokenKind::RBracket) {
                                break;
                            }
                            // Check for `...name` spread
                            if self.at_exact(&TokenKind::DotDot) {
                                self.advance();
                                if self.at_exact(&TokenKind::Dot) {
                                    self.advance();
                                }
                                rest = Some(Box::new(self.parse_single_pattern()?));
                                break;
                            }
                            elements.push(self.parse_pattern()?);
                        }
                    }
                }
                let end_tok = self.expect(&TokenKind::RBracket)?;
                let span = Span::new(
                    start_span.start,
                    end_tok.span.end,
                    start_span.line,
                    start_span.column,
                );
                Ok(Pattern::List {
                    elements,
                    rest,
                    span,
                })
            }
            TokenKind::Ident(_) => {
                let tok = self.advance();
                let name = match tok.kind {
                    TokenKind::Ident(n) => n,
                    _ => unreachable!(),
                };

                // Check if it's a variant pattern with positional fields: Name(fields)
                if self.at_exact(&TokenKind::LParen) {
                    self.advance();
                    let mut fields = Vec::new();
                    if !self.at_exact(&TokenKind::RParen) {
                        fields.push(self.parse_pattern()?);
                        while self.at_exact(&TokenKind::Comma) {
                            self.advance();
                            if self.at_exact(&TokenKind::RParen) {
                                break;
                            }
                            fields.push(self.parse_pattern()?);
                        }
                    }
                    let end_tok = self.expect(&TokenKind::RParen)?;
                    let span = Span::new(
                        tok.span.start,
                        end_tok.span.end,
                        tok.span.line,
                        tok.span.column,
                    );
                    Ok(Pattern::Variant { name, fields, span })
                } else if self.at_exact(&TokenKind::LBrace) {
                    // Record pattern: Name { field_name, field_name: pat, ... }
                    self.advance();
                    let mut fields = Vec::new();
                    if !self.at_exact(&TokenKind::RBrace) {
                        loop {
                            let (field_name, field_span) = self.expect_ident()?;
                            let pat = if self.at_exact(&TokenKind::Colon) {
                                self.advance();
                                self.parse_pattern()?
                            } else {
                                // Shorthand: `{ name }` is sugar for `{ name: name }`
                                Pattern::Binding(field_name.clone(), field_span)
                            };
                            fields.push((field_name, pat));
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
                    Ok(Pattern::Record { name, fields, span })
                } else {
                    // Simple binding — but uppercase names are likely variants with no fields
                    if name.chars().next().is_some_and(|c| c.is_uppercase()) {
                        Ok(Pattern::Variant {
                            name,
                            fields: Vec::new(),
                            span: tok.span,
                        })
                    } else {
                        Ok(Pattern::Binding(name, tok.span))
                    }
                }
            }
            // Negative number pattern
            TokenKind::Minus => {
                let start_tok = self.advance();
                match self.peek().clone() {
                    TokenKind::IntLit(_) => {
                        let tok = self.advance();
                        let val = match tok.kind {
                            TokenKind::IntLit(v) => v,
                            _ => unreachable!(),
                        };
                        let span = Span::new(
                            start_tok.span.start,
                            tok.span.end,
                            start_tok.span.line,
                            start_tok.span.column,
                        );
                        Ok(Pattern::Literal(LitPattern::Int(-val), span))
                    }
                    TokenKind::FloatLit(_) => {
                        let tok = self.advance();
                        let val = match tok.kind {
                            TokenKind::FloatLit(v) => v,
                            _ => unreachable!(),
                        };
                        let span = Span::new(
                            start_tok.span.start,
                            tok.span.end,
                            start_tok.span.line,
                            start_tok.span.column,
                        );
                        Ok(Pattern::Literal(LitPattern::Float(-val), span))
                    }
                    _ => Err(ParseError {
                        kind: ParseErrorKind::InvalidPattern,
                        span: self.peek_span(),
                    }
                    .into()),
                }
            }
            _ => Err(ParseError {
                kind: ParseErrorKind::InvalidPattern,
                span: self.peek_span(),
            }
            .into()),
        }
    }
}
