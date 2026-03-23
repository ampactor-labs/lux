/// Recursive descent parser for Lux.
///
/// Converts a token stream into an AST. Uses Pratt-style precedence
/// climbing for binary expressions.
///
/// Split into submodules:
/// - `expr` — Pratt precedence climbing, control flow, handle expressions
/// - `primary` — primary expression parsing (literals, records, lambdas)
/// - `items` — top-level item parsing (fn, type, effect, trait, impl)
/// - `patterns` — pattern matching parsing
mod expr;
mod items;
mod patterns;
mod primary;

use crate::ast::*;
use crate::error::{LuxError, ParseError, ParseErrorKind};
use crate::token::{Span, Token, TokenKind};

/// Parse a token stream into a Lux program.
pub fn parse(tokens: Vec<Token>) -> Result<Program, LuxError> {
    let mut parser = Parser::new(tokens);
    let items = parser.parse_program()?;
    Ok(Program { items })
}

pub(crate) struct Parser {
    pub(crate) tokens: Vec<Token>,
    pub(crate) pos: usize,
}

// ── Precedence levels (low → high) ──────────────────────────────

#[derive(Debug, Clone, Copy, PartialEq, PartialOrd)]
pub(crate) enum Prec {
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

pub(crate) fn infix_precedence(kind: &TokenKind) -> Option<Prec> {
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

pub(crate) fn token_to_binop(kind: &TokenKind) -> Option<BinOp> {
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
    pub(crate) fn new(tokens: Vec<Token>) -> Self {
        Self { tokens, pos: 0 }
    }

    pub(crate) fn from_tokens(mut tokens: Vec<Token>) -> Self {
        if tokens.last().map(|t| &t.kind) != Some(&TokenKind::Eof) {
            tokens.push(Token::new(TokenKind::Eof, Span::dummy()));
        }
        Self { tokens, pos: 0 }
    }

    pub(crate) fn peek(&self) -> &TokenKind {
        self.tokens
            .get(self.pos)
            .map(|t| &t.kind)
            .unwrap_or(&TokenKind::Eof)
    }

    pub(crate) fn peek_span(&self) -> Span {
        self.tokens
            .get(self.pos)
            .map(|t| t.span.clone())
            .unwrap_or_else(Span::dummy)
    }

    /// Peek at the token after the current one (1 token lookahead).
    pub(crate) fn peek_next(&self) -> &TokenKind {
        self.tokens
            .get(self.pos + 1)
            .map(|t| &t.kind)
            .unwrap_or(&TokenKind::Eof)
    }

    pub(crate) fn at(&self, kind: &TokenKind) -> bool {
        std::mem::discriminant(self.peek()) == std::mem::discriminant(kind)
    }

    pub(crate) fn at_exact(&self, kind: &TokenKind) -> bool {
        self.peek() == kind
    }

    pub(crate) fn advance(&mut self) -> Token {
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

    pub(crate) fn expect(&mut self, kind: &TokenKind) -> Result<Token, LuxError> {
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

    pub(crate) fn expect_ident(&mut self) -> Result<(String, Span), LuxError> {
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
    pub(crate) fn skip_semis(&mut self) {
        while self.at_exact(&TokenKind::Semicolon) {
            self.advance();
        }
    }

    /// Lookahead: is the current `{` the start of a record construction?
    ///
    /// Returns true if the tokens after `{` match a record literal pattern:
    ///   `{ ident : ...`  — explicit field  (always record)
    ///   `{ ident ,`      — shorthand field followed by more fields
    ///   `{ ident }`      — single shorthand field
    ///   `{ }`            — empty record
    /// This disambiguates record literals from block expressions.
    pub(crate) fn is_record_construction_ahead(&self) -> bool {
        // Current token is `{`. Check pos+1 and pos+2.
        let tok1 = self.tokens.get(self.pos + 1).map(|t| &t.kind);
        let tok2 = self.tokens.get(self.pos + 2).map(|t| &t.kind);
        match (tok1, tok2) {
            // `{ field: expr }` — explicit field value
            (Some(TokenKind::Ident(_)), Some(TokenKind::Colon)) => true,
            // `{ field, ...}` — shorthand with more fields following
            (Some(TokenKind::Ident(_)), Some(TokenKind::Comma)) => true,
            // `{ field }` — single shorthand field
            (Some(TokenKind::Ident(_)), Some(TokenKind::RBrace)) => true,
            // `{}` — empty record
            (Some(TokenKind::RBrace), _) => true,
            _ => false,
        }
    }
}

// ── Type expressions ─────────────────────────────────────────────

impl Parser {
    pub(crate) fn parse_type_expr(&mut self) -> Result<TypeExpr, LuxError> {
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

    pub(crate) fn parse_effect_refs(&mut self) -> Result<Vec<EffectRef>, LuxError> {
        let mut refs = Vec::new();
        refs.push(self.parse_effect_ref()?);
        loop {
            if self.at_exact(&TokenKind::Comma) {
                // Peek ahead: if after the comma there's an identifier or `!` (negated effect),
                // keep parsing. But stop if we see `{` (body start) or other non-effect tokens.
                let saved = self.pos;
                self.advance(); // consume comma
                if matches!(self.peek(), TokenKind::Ident(_) | TokenKind::Bang) {
                    refs.push(self.parse_effect_ref()?);
                } else {
                    // Not an effect ref — backtrack
                    self.pos = saved;
                    break;
                }
            } else if self.at_exact(&TokenKind::Minus) {
                // Effect subtraction: `E - F` desugars to negation constraint on F
                self.advance(); // consume `-`
                let (name, span) = self.expect_ident()?;
                refs.push(EffectRef {
                    name,
                    type_args: Vec::new(),
                    negated: true,
                    span,
                });
            } else {
                break;
            }
        }
        Ok(refs)
    }

    fn parse_effect_ref(&mut self) -> Result<EffectRef, LuxError> {
        // Check for negation: `!EffectName`
        let negated = if self.at_exact(&TokenKind::Bang) {
            self.advance(); // consume `!`
            true
        } else {
            false
        };
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
            negated,
            span,
        })
    }
}

// ── TypeExpr span helper ─────────────────────────────────────────

impl TypeExpr {
    pub(crate) fn span(&self) -> &Span {
        match self {
            TypeExpr::Named { span, .. }
            | TypeExpr::Function { span, .. }
            | TypeExpr::Tuple(_, span)
            | TypeExpr::List(_, span)
            | TypeExpr::Inferred(span) => span,
        }
    }
}
