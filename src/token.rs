//! Token types for the Lux lexer.

/// Source location for error reporting.
#[derive(Debug, Clone, PartialEq)]
pub struct Span {
    pub start: usize,
    pub end: usize,
    pub line: usize,
    pub column: usize,
}

impl Span {
    pub fn new(start: usize, end: usize, line: usize, column: usize) -> Self {
        Self {
            start,
            end,
            line,
            column,
        }
    }

    pub fn dummy() -> Self {
        Self {
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
