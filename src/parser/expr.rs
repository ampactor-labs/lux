/// Expression parsing: Pratt precedence climbing, control flow, handle expressions.
use crate::ast::*;
use crate::error::LuxError;
use crate::token::{Span, TokenKind};

use super::{Parser, Prec, infix_precedence, token_to_binop};

// ── Expression parsing (Pratt precedence climbing) ───────────────

impl Parser {
    pub(crate) fn parse_expr(&mut self) -> Result<Expr, LuxError> {
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

    pub(crate) fn parse_unary(&mut self) -> Result<Expr, LuxError> {
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

    pub(crate) fn parse_postfix(&mut self) -> Result<Expr, LuxError> {
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

    pub(crate) fn parse_call_args(&mut self) -> Result<Vec<Expr>, LuxError> {
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

    // ── Control flow expressions ──────────────────────────────────

    pub(crate) fn parse_block_expr(&mut self) -> Result<Expr, LuxError> {
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

    pub(crate) fn parse_if_expr(&mut self) -> Result<Expr, LuxError> {
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

    pub(crate) fn parse_match_expr(&mut self) -> Result<Expr, LuxError> {
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

    pub(crate) fn parse_lambda(&mut self) -> Result<Expr, LuxError> {
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

    // ── Handle expressions ────────────────────────────────────────

    pub(crate) fn parse_handle_expr(&mut self) -> Result<Expr, LuxError> {
        let start_span = self.peek_span();
        self.expect(&TokenKind::Handle)?;
        let expr = self.parse_expr()?;

        // Parse optional state bindings: `with name = expr, ...`
        let mut state_bindings = Vec::new();
        if self.at_exact(&TokenKind::With) {
            self.advance();
            loop {
                let binding_span = self.peek_span();
                let (name, _) = self.expect_ident()?;
                self.expect(&TokenKind::Eq)?;
                let init = self.parse_expr()?;
                let end = init.span().end;
                state_bindings.push(StateBinding {
                    name,
                    init,
                    span: Span::new(
                        binding_span.start,
                        end,
                        binding_span.line,
                        binding_span.column,
                    ),
                });
                if !self.at_exact(&TokenKind::Comma) {
                    break;
                }
                self.advance();
            }
        }

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
            state_bindings,
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
