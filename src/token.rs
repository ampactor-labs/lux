//! Token types for the Lux lexer.

use std::cell::Cell;
use std::sync::atomic::{AtomicUsize, Ordering};

static FILE_ID_COUNTER: AtomicUsize = AtomicUsize::new(1);

pub fn next_file_id() -> usize {
    FILE_ID_COUNTER.fetch_add(1, Ordering::SeqCst)
}

thread_local! {
    pub static CURRENT_FILE_ID: Cell<usize> = const { Cell::new(0) };
}

/// Source location for error reporting.
#[derive(Debug, Clone, PartialEq, Eq, Hash)]
pub struct Span {
    pub file_id: usize,
    pub start: usize,
    pub end: usize,
    pub line: usize,
    pub column: usize,
}

impl Span {
    pub fn new(start: usize, end: usize, line: usize, column: usize) -> Self {
        Self {
            file_id: CURRENT_FILE_ID.with(|id| id.get()),
            start,
            end,
            line,
            column,
        }
    }

    pub fn dummy() -> Self {
        Self {
            file_id: 0,
            start: 0,
            end: 0,
            line: 0,
            column: 0,
        }
    }
}

#[derive(Debug, Clone, PartialEq)]
pub struct Token {
    pub kind: TokenKind,
    pub span: Span,
}

impl Token {
    pub fn new(kind: TokenKind, span: Span) -> Self {
        Self { kind, span }
    }
}

#[derive(Debug, Clone, PartialEq)]
pub enum TokenKind {
    // Literals
    IntLit(i64),
    FloatLit(f64),
    StringLit(String),
    BoolLit(bool),

    // Identifier
    Ident(String),

    // Keywords
    Let,
    Fn,
    If,
    Else,
    Match,
    Type,
    Effect,
    Handle,
    Handler,
    With,
    Resume,
    Pub,
    Own,
    Ref,
    Gc,
    Use,
    Mod,
    Trait,
    Impl,
    Struct,
    Enum,
    Return,
    Loop,
    While,
    For,
    In,
    Break,
    Continue,
    Import,
    Assert,
    Where,

    // Operators
    Plus,
    Minus,
    Star,
    Slash,
    Percent,
    Eq,
    EqEq,
    BangEq,
    Lt,
    LtEq,
    Gt,
    GtEq,
    And,
    Or,
    Bang,
    Pipe,
    PipeGt,   // |>
    FanOut,   // <|
    Arrow,    // ->
    FatArrow, // =>
    DotDot,   // ..
    Dot,
    ColonColon, // ::
    PlusPlus,   // ++

    // Delimiters
    LParen,
    RParen,
    LBrace,
    RBrace,
    LBracket,
    RBracket,

    // Punctuation
    Comma,
    Colon,
    Semicolon,
    At,
    Hash,
    Underscore,

    // String interpolation: `"hello {expr} world"`
    StringInterp(Vec<StringInterpPart>),

    // Special
    Eof,
}

/// A part of an interpolated string.
#[derive(Debug, Clone, PartialEq)]
pub enum StringInterpPart {
    /// A literal string segment.
    Literal(String),
    /// Tokens from an embedded `{expr}` that the parser will sub-parse.
    Tokens(Vec<Token>),
}
