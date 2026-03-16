/// Recursive descent parser for Lux.
///
/// Converts a token stream into an AST. Uses Pratt-style precedence
/// climbing for binary expressions.
use crate::ast::*;
use crate::error::{LuxError, ParseError, ParseErrorKind};
use crate::token::{Span, StringInterpPart, Token, TokenKind};

/// Parse a token stream into a Lux program.
pub fn parse(tokens: Vec<Token>) -> Result<Program, LuxError> {
    let mut parser = Parser::new(tokens);
    let items = parser.parse_program()?;
    Ok(Program { items })
}

struct Parser {
    tokens: Vec<Token>,
    pos: usize,
}

// ── Precedence levels (low → high) ──────────────────────────────

#[derive(Debug, Clone, Copy, PartialEq, PartialOrd)]
enum Prec {
    None = 0,
    Pipe = 1,     // |>
    Or = 2,       // ||
    And = 3,      // &&
    Equality = 4, // == !=
    Compare = 5,  // < <= > >=
    Concat = 6,   // ++
    Add = 7,      // + -
    Mul = 8,      // * / %
}

fn infix_precedence(kind: &TokenKind) -> Option<Prec> {
    match kind {
        TokenKind::PipeGt => Some(Prec::Pipe),
        TokenKind::Or => Some(Prec::Or),
        TokenKind::And => Some(Prec::And),
        TokenKind::EqEq | TokenKind::BangEq => Some(Prec::Equality),
        TokenKind::Lt | TokenKind::LtEq | TokenKind::Gt | TokenKind::GtEq => Some(Prec::Compare),
        TokenKind::PlusPlus => Some(Prec::Concat),
        TokenKind::Plus | TokenKind::Minus => Some(Prec::Add),
        TokenKind::Star | TokenKind::Slash | TokenKind::Percent => Some(Prec::Mul),
        _ => None,
    }
}

fn token_to_binop(kind: &TokenKind) -> Option<BinOp> {
    match kind {
        TokenKind::Plus => Some(BinOp::Add),
        TokenKind::Minus => Some(BinOp::Sub),
        TokenKind::Star => Some(BinOp::Mul),
        TokenKind::Slash => Some(BinOp::Div),
        TokenKind::Percent => Some(BinOp::Mod),
        TokenKind::EqEq => Some(BinOp::Eq),
        TokenKind::BangEq => Some(BinOp::Neq),
        TokenKind::Lt => Some(BinOp::Lt),
        TokenKind::LtEq => Some(BinOp::LtEq),
        TokenKind::Gt => Some(BinOp::Gt),
        TokenKind::GtEq => Some(BinOp::GtEq),
        TokenKind::And => Some(BinOp::And),
        TokenKind::Or => Some(BinOp::Or),
        TokenKind::PlusPlus => Some(BinOp::Concat),
        _ => None,
    }
}

// ── Core helpers ─────────────────────────────────────────────────

impl Parser {
    fn new(tokens: Vec<Token>) -> Self {
        Self { tokens, pos: 0 }
    }

    fn from_tokens(mut tokens: Vec<Token>) -> Self {
        if tokens.last().map(|t| &t.kind) != Some(&TokenKind::Eof) {
            tokens.push(Token::new(TokenKind::Eof, Span::dummy()));
        }
        Self { tokens, pos: 0 }
    }

    fn peek(&self) -> &TokenKind {
        self.tokens
            .get(self.pos)
            .map(|t| &t.kind)
            .unwrap_or(&TokenKind::Eof)
    }

    fn peek_span(&self) -> Span {
        self.tokens
            .get(self.pos)
            .map(|t| t.span.clone())
            .unwrap_or_else(Span::dummy)
    }

    fn at(&self, kind: &TokenKind) -> bool {
        std::mem::discriminant(self.peek()) == std::mem::discriminant(kind)
    }

    fn at_exact(&self, kind: &TokenKind) -> bool {
        self.peek() == kind
    }

    fn advance(&mut self) -> Token {
        let tok = self
            .tokens
            .get(self.pos)
            .cloned()
            .unwrap_or_else(|| Token::new(TokenKind::Eof, Span::dummy()));
        if tok.kind != TokenKind::Eof {
            self.pos += 1;
        }
        tok
    }

    fn expect(&mut self, kind: &TokenKind) -> Result<Token, LuxError> {
        if self.at(kind) {
            Ok(self.advance())
        } else {
            Err(ParseError {
                kind: ParseErrorKind::UnexpectedToken {
                    expected: format!("{kind:?}"),
                    found: format!("{:?}", self.peek()),
                },
                span: self.peek_span(),
            }
            .into())
        }
    }

    fn expect_ident(&mut self) -> Result<(String, Span), LuxError> {
        match self.peek().clone() {
            TokenKind::Ident(_) => {
                let tok = self.advance();
                let name = match tok.kind {
                    TokenKind::Ident(n) => n,
                    _ => unreachable!(),
                };
                Ok((name, tok.span))
            }
            _ => Err(ParseError {
                kind: ParseErrorKind::UnexpectedToken {
                    expected: "identifier".to_string(),
                    found: format!("{:?}", self.peek()),
                },
                span: self.peek_span(),
            }
            .into()),
        }
    }

    /// Skip optional semicolons/newlines (semicolons are optional separators).
    fn skip_semis(&mut self) {
        while self.at_exact(&TokenKind::Semicolon) {
            self.advance();
        }
    }
}

// ── Program & top-level items ────────────────────────────────────

impl Parser {
    fn parse_program(&mut self) -> Result<Vec<Item>, LuxError> {
        let mut items = Vec::new();
        self.skip_semis();
        while !self.at_exact(&TokenKind::Eof) {
            items.push(self.parse_item()?);
            self.skip_semis();
        }
        Ok(items)
    }

    fn parse_item(&mut self) -> Result<Item, LuxError> {
        match self.peek() {
            TokenKind::Fn => Ok(Item::FnDecl(self.parse_fn_decl()?)),
            TokenKind::Let => Ok(Item::LetDecl(self.parse_let_decl()?)),
            TokenKind::Type => Ok(Item::TypeDecl(self.parse_type_decl()?)),
            TokenKind::Effect => Ok(Item::EffectDecl(self.parse_effect_decl()?)),
            TokenKind::Trait => Ok(Item::TraitDecl(self.parse_trait_decl()?)),
            TokenKind::Impl => Ok(Item::ImplBlock(self.parse_impl_block()?)),
            _ => {
                let expr = self.parse_expr()?;
                Ok(Item::Expr(expr))
            }
        }
    }

    // ── fn name(params) -> RetType with Effects { body }
    // ── fn name(params) -> RetType = expr
    fn parse_fn_decl(&mut self) -> Result<FnDecl, LuxError> {
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

    fn parse_params(&mut self) -> Result<Vec<Param>, LuxError> {
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

    fn parse_param(&mut self) -> Result<Param, LuxError> {
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

    fn parse_let_decl(&mut self) -> Result<LetDecl, LuxError> {
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
            self.advance();
            if !self.at_exact(&TokenKind::RParen) {
                fields.push(self.parse_type_expr()?);
                while self.at_exact(&TokenKind::Comma) {
                    self.advance();
                    if self.at_exact(&TokenKind::RParen) {
                        break;
                    }
                    fields.push(self.parse_type_expr()?);
                }
            }
            let end_tok = self.expect(&TokenKind::RParen)?;
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

// ── Type expressions ─────────────────────────────────────────────

impl Parser {
    fn parse_type_expr(&mut self) -> Result<TypeExpr, LuxError> {
        // Check for tuple/function type starting with `(`
        if self.at_exact(&TokenKind::LParen) {
            return self.parse_paren_type();
        }

        // Named type
        let (name, span) = self.expect_ident()?;
        let mut args = Vec::new();
        if self.at_exact(&TokenKind::Lt) {
            self.advance();
            if !self.at_exact(&TokenKind::Gt) {
                args.push(self.parse_type_expr()?);
                while self.at_exact(&TokenKind::Comma) {
                    self.advance();
                    args.push(self.parse_type_expr()?);
                }
            }
            self.expect(&TokenKind::Gt)?;
        }
        Ok(TypeExpr::Named { name, args, span })
    }

    /// Parse `(A, B) -> C` (function type) or `(A, B)` (tuple type) or `(A)` (grouped).
    fn parse_paren_type(&mut self) -> Result<TypeExpr, LuxError> {
        let start_span = self.peek_span();
        self.expect(&TokenKind::LParen)?;
        let mut types = Vec::new();
        if !self.at_exact(&TokenKind::RParen) {
            types.push(self.parse_type_expr()?);
            while self.at_exact(&TokenKind::Comma) {
                self.advance();
                if self.at_exact(&TokenKind::RParen) {
                    break;
                }
                types.push(self.parse_type_expr()?);
            }
        }
        let rparen = self.expect(&TokenKind::RParen)?;

        // If followed by `->`, it's a function type
        if self.at_exact(&TokenKind::Arrow) {
            self.advance();
            let return_type = self.parse_type_expr()?;
            let effects = if self.at_exact(&TokenKind::With) {
                self.advance();
                self.parse_effect_refs()?
            } else {
                Vec::new()
            };
            let end = return_type.span().end;
            let span = Span::new(start_span.start, end, start_span.line, start_span.column);
            Ok(TypeExpr::Function {
                params: types,
                return_type: Box::new(return_type),
                effects,
                span,
            })
        } else if types.len() == 1 {
            // Single type in parens — just unwrap
            Ok(types.into_iter().next().unwrap())
        } else {
            let span = Span::new(
                start_span.start,
                rparen.span.end,
                start_span.line,
                start_span.column,
            );
            Ok(TypeExpr::Tuple(types, span))
        }
    }

    fn parse_effect_refs(&mut self) -> Result<Vec<EffectRef>, LuxError> {
        let mut refs = Vec::new();
        refs.push(self.parse_effect_ref()?);
        while self.at_exact(&TokenKind::Comma) {
            // Peek ahead: if after the comma there's an identifier (potential effect name),
            // keep parsing. But stop if we see `{` (body start) or other non-effect tokens.
            // Since effect refs are `Name<T>`, we check for Ident after comma.
            let saved = self.pos;
            self.advance(); // consume comma
            if matches!(self.peek(), TokenKind::Ident(_)) {
                refs.push(self.parse_effect_ref()?);
            } else {
                // Not an effect ref — backtrack
                self.pos = saved;
                break;
            }
        }
        Ok(refs)
    }

    fn parse_effect_ref(&mut self) -> Result<EffectRef, LuxError> {
        let (name, span) = self.expect_ident()?;
        let mut type_args = Vec::new();
        if self.at_exact(&TokenKind::Lt) {
            self.advance();
            if !self.at_exact(&TokenKind::Gt) {
                type_args.push(self.parse_type_expr()?);
                while self.at_exact(&TokenKind::Comma) {
                    self.advance();
                    type_args.push(self.parse_type_expr()?);
                }
            }
            self.expect(&TokenKind::Gt)?;
        }
        Ok(EffectRef {
            name,
            type_args,
            span,
        })
    }
}

// ── TypeExpr span helper ─────────────────────────────────────────

impl TypeExpr {
    fn span(&self) -> &Span {
        match self {
            TypeExpr::Named { span, .. }
            | TypeExpr::Function { span, .. }
            | TypeExpr::Tuple(_, span)
            | TypeExpr::List(_, span)
            | TypeExpr::Inferred(span) => span,
        }
    }
}

// ── Expression parsing (Pratt precedence climbing) ───────────────

impl Parser {
    fn parse_expr(&mut self) -> Result<Expr, LuxError> {
        self.parse_pratt(Prec::None)
    }

    fn parse_pratt(&mut self, min_prec: Prec) -> Result<Expr, LuxError> {
        let mut left = self.parse_unary()?;

        loop {
            // Check for pipe operator separately — it produces Expr::Pipe, not BinOp
            if self.at_exact(&TokenKind::PipeGt) && Prec::Pipe > min_prec {
                self.advance();
                let right = self.parse_pratt(Prec::Pipe)?;
                let span = Span::new(
                    left.span().start,
                    right.span().end,
                    left.span().line,
                    left.span().column,
                );
                left = Expr::Pipe {
                    left: Box::new(left),
                    right: Box::new(right),
                    span,
                };
                continue;
            }

            let Some(prec) = infix_precedence(self.peek()) else {
                break;
            };
            if prec <= min_prec {
                break;
            }

            let op_tok = self.advance();
            let op = token_to_binop(&op_tok.kind).unwrap();
            let right = self.parse_pratt(prec)?;
            let span = Span::new(
                left.span().start,
                right.span().end,
                left.span().line,
                left.span().column,
            );
            left = Expr::BinOp {
                op,
                left: Box::new(left),
                right: Box::new(right),
                span,
            };
        }

        Ok(left)
    }

    fn parse_unary(&mut self) -> Result<Expr, LuxError> {
        match self.peek() {
            TokenKind::Bang => {
                let tok = self.advance();
                let operand = self.parse_unary()?;
                let span = Span::new(
                    tok.span.start,
                    operand.span().end,
                    tok.span.line,
                    tok.span.column,
                );
                Ok(Expr::UnaryOp {
                    op: UnaryOp::Not,
                    operand: Box::new(operand),
                    span,
                })
            }
            TokenKind::Minus => {
                let tok = self.advance();
                let operand = self.parse_unary()?;
                let span = Span::new(
                    tok.span.start,
                    operand.span().end,
                    tok.span.line,
                    tok.span.column,
                );
                Ok(Expr::UnaryOp {
                    op: UnaryOp::Neg,
                    operand: Box::new(operand),
                    span,
                })
            }
            _ => self.parse_postfix(),
        }
    }

    fn parse_postfix(&mut self) -> Result<Expr, LuxError> {
        let mut expr = self.parse_primary()?;

        loop {
            match self.peek() {
                TokenKind::LParen => {
                    // Function call
                    self.advance();
                    let args = self.parse_call_args()?;
                    let end_tok = self.expect(&TokenKind::RParen)?;
                    let span = Span::new(
                        expr.span().start,
                        end_tok.span.end,
                        expr.span().line,
                        expr.span().column,
                    );
                    expr = Expr::Call {
                        func: Box::new(expr),
                        args,
                        span,
                    };
                }
                TokenKind::LBracket => {
                    // Index
                    self.advance();
                    let index = self.parse_expr()?;
                    let end_tok = self.expect(&TokenKind::RBracket)?;
                    let span = Span::new(
                        expr.span().start,
                        end_tok.span.end,
                        expr.span().line,
                        expr.span().column,
                    );
                    expr = Expr::Index {
                        object: Box::new(expr),
                        index: Box::new(index),
                        span,
                    };
                }
                TokenKind::Dot => {
                    // Field access
                    self.advance();
                    let (field, field_span) = self.expect_ident()?;
                    let span = Span::new(
                        expr.span().start,
                        field_span.end,
                        expr.span().line,
                        expr.span().column,
                    );
                    expr = Expr::FieldAccess {
                        object: Box::new(expr),
                        field,
                        span,
                    };
                }
                _ => break,
            }
        }
        Ok(expr)
    }

    fn parse_call_args(&mut self) -> Result<Vec<Expr>, LuxError> {
        let mut args = Vec::new();
        if self.at_exact(&TokenKind::RParen) {
            return Ok(args);
        }
        args.push(self.parse_expr()?);
        while self.at_exact(&TokenKind::Comma) {
            self.advance();
            if self.at_exact(&TokenKind::RParen) {
                break; // trailing comma
            }
            args.push(self.parse_expr()?);
        }
        Ok(args)
    }

    fn parse_primary(&mut self) -> Result<Expr, LuxError> {
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

            // Resume expression
            TokenKind::Resume => {
                let tok = self.advance();
                self.expect(&TokenKind::LParen)?;
                let value = self.parse_expr()?;
                let end_tok = self.expect(&TokenKind::RParen)?;
                let span = Span::new(
                    tok.span.start,
                    end_tok.span.end,
                    tok.span.line,
                    tok.span.column,
                );
                Ok(Expr::Resume {
                    value: Box::new(value),
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

    fn parse_block_expr(&mut self) -> Result<Expr, LuxError> {
        let start_span = self.peek_span();
        self.expect(&TokenKind::LBrace)?;
        self.skip_semis();

        let mut stmts: Vec<Stmt> = Vec::new();
        let mut final_expr: Option<Box<Expr>> = None;

        while !self.at_exact(&TokenKind::RBrace) && !self.at_exact(&TokenKind::Eof) {
            match self.peek() {
                TokenKind::Let => {
                    let decl = self.parse_let_decl()?;
                    stmts.push(Stmt::Let(decl));
                }
                TokenKind::Fn => {
                    let decl = self.parse_fn_decl()?;
                    stmts.push(Stmt::FnDecl(decl));
                }
                _ => {
                    let expr = self.parse_expr()?;
                    // If next is `}`, this expression is the final value
                    if self.at_exact(&TokenKind::RBrace) {
                        final_expr = Some(Box::new(expr));
                        break;
                    }
                    stmts.push(Stmt::Expr(expr));
                }
            }
            self.skip_semis();
        }

        let end_tok = self.expect(&TokenKind::RBrace)?;
        let span = Span::new(
            start_span.start,
            end_tok.span.end,
            start_span.line,
            start_span.column,
        );
        Ok(Expr::Block {
            stmts,
            expr: final_expr,
            span,
        })
    }

    fn parse_if_expr(&mut self) -> Result<Expr, LuxError> {
        let start_span = self.peek_span();
        self.expect(&TokenKind::If)?;
        let condition = self.parse_expr()?;
        let then_branch = self.parse_block_expr()?;

        let else_branch = if self.at_exact(&TokenKind::Else) {
            self.advance();
            if self.at_exact(&TokenKind::If) {
                // else if ...
                Some(Box::new(self.parse_if_expr()?))
            } else {
                Some(Box::new(self.parse_block_expr()?))
            }
        } else {
            None
        };

        let end = else_branch
            .as_ref()
            .map(|e| e.span().end)
            .unwrap_or(then_branch.span().end);
        let span = Span::new(start_span.start, end, start_span.line, start_span.column);
        Ok(Expr::If {
            condition: Box::new(condition),
            then_branch: Box::new(then_branch),
            else_branch,
            span,
        })
    }

    fn parse_match_expr(&mut self) -> Result<Expr, LuxError> {
        let start_span = self.peek_span();
        self.expect(&TokenKind::Match)?;
        let scrutinee = self.parse_expr()?;
        self.expect(&TokenKind::LBrace)?;
        self.skip_semis();

        let mut arms = Vec::new();
        while !self.at_exact(&TokenKind::RBrace) && !self.at_exact(&TokenKind::Eof) {
            arms.push(self.parse_match_arm()?);
            // Allow comma or semicolon as arm separator
            if self.at_exact(&TokenKind::Comma) {
                self.advance();
            }
            self.skip_semis();
        }

        let end_tok = self.expect(&TokenKind::RBrace)?;
        let span = Span::new(
            start_span.start,
            end_tok.span.end,
            start_span.line,
            start_span.column,
        );
        Ok(Expr::Match {
            scrutinee: Box::new(scrutinee),
            arms,
            span,
        })
    }

    fn parse_match_arm(&mut self) -> Result<MatchArm, LuxError> {
        let pattern = self.parse_pattern()?;
        let guard = if self.at_exact(&TokenKind::If) {
            self.advance();
            Some(self.parse_expr()?)
        } else {
            None
        };
        self.expect(&TokenKind::FatArrow)?;
        let body = self.parse_expr()?;
        let span = Span::new(
            pattern.span().start,
            body.span().end,
            pattern.span().line,
            pattern.span().column,
        );
        Ok(MatchArm {
            pattern,
            guard,
            body,
            span,
        })
    }

    fn parse_lambda(&mut self) -> Result<Expr, LuxError> {
        let start_span = self.peek_span();
        self.expect(&TokenKind::Pipe)?;

        let mut params = Vec::new();
        if !self.at_exact(&TokenKind::Pipe) {
            params.push(self.parse_param()?);
            while self.at_exact(&TokenKind::Comma) {
                self.advance();
                if self.at_exact(&TokenKind::Pipe) {
                    break;
                }
                params.push(self.parse_param()?);
            }
        }
        self.expect(&TokenKind::Pipe)?;

        let body = self.parse_expr()?;
        let span = Span::new(
            start_span.start,
            body.span().end,
            start_span.line,
            start_span.column,
        );
        Ok(Expr::Lambda {
            params,
            body: Box::new(body),
            span,
        })
    }

    fn parse_handle_expr(&mut self) -> Result<Expr, LuxError> {
        let start_span = self.peek_span();
        self.expect(&TokenKind::Handle)?;
        let expr = self.parse_expr()?;
        self.expect(&TokenKind::LBrace)?;
        self.skip_semis();

        let mut handlers = Vec::new();
        while !self.at_exact(&TokenKind::RBrace) && !self.at_exact(&TokenKind::Eof) {
            handlers.push(self.parse_handler_clause()?);
            if self.at_exact(&TokenKind::Comma) {
                self.advance();
            }
            self.skip_semis();
        }

        let end_tok = self.expect(&TokenKind::RBrace)?;
        let span = Span::new(
            start_span.start,
            end_tok.span.end,
            start_span.line,
            start_span.column,
        );
        Ok(Expr::Handle {
            expr: Box::new(expr),
            handlers,
            span,
        })
    }

    fn parse_handler_clause(&mut self) -> Result<HandlerClause, LuxError> {
        let start_span = self.peek_span();

        // `use HandlerName`
        if self.at_exact(&TokenKind::Use) {
            self.advance();
            let (name, end_span) = self.expect_ident()?;
            let span = Span::new(
                start_span.start,
                end_span.end,
                start_span.line,
                start_span.column,
            );
            return Ok(HandlerClause {
                operation: HandlerOp::UseHandler { name },
                span,
            });
        }

        // `op(params) => body` or `Effect.op(params) => body`
        let (first_name, _) = self.expect_ident()?;

        // Check for Effect.op syntax
        let (effect_name, op_name) = if self.at_exact(&TokenKind::Dot) {
            self.advance();
            let (op, _) = self.expect_ident()?;
            (Some(first_name), op)
        } else {
            (None, first_name)
        };

        self.expect(&TokenKind::LParen)?;
        let mut params = Vec::new();
        if !self.at_exact(&TokenKind::RParen) {
            let (p, _) = self.expect_ident()?;
            params.push(p);
            while self.at_exact(&TokenKind::Comma) {
                self.advance();
                if self.at_exact(&TokenKind::RParen) {
                    break;
                }
                let (p, _) = self.expect_ident()?;
                params.push(p);
            }
        }
        self.expect(&TokenKind::RParen)?;
        self.expect(&TokenKind::FatArrow)?;
        let body = self.parse_expr()?;

        let span = Span::new(
            start_span.start,
            body.span().end,
            start_span.line,
            start_span.column,
        );
        Ok(HandlerClause {
            operation: HandlerOp::OpHandler {
                effect_name,
                op_name,
                params,
                body,
            },
            span,
        })
    }
}

// ── Pattern parsing ──────────────────────────────────────────────

impl Pattern {
    fn span(&self) -> &Span {
        match self {
            Pattern::Wildcard(s)
            | Pattern::Binding(_, s)
            | Pattern::Literal(_, s)
            | Pattern::Tuple(_, s) => s,
            Pattern::Variant { span, .. } => span,
        }
    }
}

impl Parser {
    fn parse_pattern(&mut self) -> Result<Pattern, LuxError> {
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
            TokenKind::Ident(_) => {
                let tok = self.advance();
                let name = match tok.kind {
                    TokenKind::Ident(n) => n,
                    _ => unreachable!(),
                };

                // Check if it's a variant pattern: Name(fields)
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
