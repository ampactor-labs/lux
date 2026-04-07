/// Lexer for the Lux language.
///
/// Converts source text into a stream of tokens. Handles all `TokenKind`
/// variants including multi-character operators, keywords, string literals
/// with escape sequences, and line/block comments.
use crate::error::{LexError, LexErrorKind, LuxError};
use crate::token::{Span, StringInterpPart, Token, TokenKind};

/// Tokenize Lux source code into a vector of tokens.
///
/// Appends an `Eof` token at the end. Returns `LuxError::Lexer` on
/// unexpected characters, unterminated strings, or invalid escapes.
pub fn lex(source: &str) -> Result<Vec<Token>, LuxError> {
    let mut lexer = Lexer::new(source);
    lexer.lex_all()?;
    Ok(lexer.tokens)
}

struct Lexer<'src> {
    source: &'src [u8],
    tokens: Vec<Token>,
    pos: usize,
    line: usize,
    col: usize,
}

impl<'src> Lexer<'src> {
    fn new(source: &'src str) -> Self {
        Self {
            source: source.as_bytes(),
            tokens: Vec::new(),
            pos: 0,
            line: 1,
            col: 1,
        }
    }

    fn peek(&self) -> Option<u8> {
        self.source.get(self.pos).copied()
    }

    fn peek2(&self) -> Option<u8> {
        self.source.get(self.pos + 1).copied()
    }

    fn advance(&mut self) -> Option<u8> {
        let ch = self.source.get(self.pos).copied()?;
        self.pos += 1;
        if ch == b'\n' {
            self.line += 1;
            self.col = 1;
        } else {
            self.col += 1;
        }
        Some(ch)
    }

    fn span_from(&self, start: usize, start_line: usize, start_col: usize) -> Span {
        Span::new(start, self.pos, start_line, start_col)
    }

    fn lex_all(&mut self) -> Result<(), LuxError> {
        while self.pos < self.source.len() {
            self.skip_whitespace_and_comments()?;
            if self.pos >= self.source.len() {
                break;
            }
            self.lex_token()?;
        }
        let span = Span::new(self.pos, self.pos, self.line, self.col);
        self.tokens.push(Token::new(TokenKind::Eof, span));
        Ok(())
    }

    fn skip_whitespace_and_comments(&mut self) -> Result<(), LuxError> {
        loop {
            // Skip whitespace
            while let Some(ch) = self.peek() {
                if ch == b' ' || ch == b'\t' || ch == b'\n' || ch == b'\r' {
                    self.advance();
                } else {
                    break;
                }
            }

            // Check for comments
            if self.peek() == Some(b'/') {
                if self.peek2() == Some(b'/') {
                    // Line comment — skip to end of line
                    self.advance();
                    self.advance();
                    while let Some(ch) = self.peek() {
                        if ch == b'\n' {
                            break;
                        }
                        self.advance();
                    }
                    continue;
                } else if self.peek2() == Some(b'*') {
                    // Block comment — skip to */
                    let start = self.pos;
                    let start_line = self.line;
                    let start_col = self.col;
                    self.advance(); // /
                    self.advance(); // *
                    let mut depth = 1;
                    while depth > 0 {
                        match self.peek() {
                            None => {
                                return Err(LexError {
                                    kind: LexErrorKind::UnexpectedChar('/'),
                                    span: self.span_from(start, start_line, start_col),
                                }
                                .into());
                            }
                            Some(b'/') if self.peek2() == Some(b'*') => {
                                self.advance();
                                self.advance();
                                depth += 1;
                            }
                            Some(b'*') if self.peek2() == Some(b'/') => {
                                self.advance();
                                self.advance();
                                depth -= 1;
                            }
                            _ => {
                                self.advance();
                            }
                        }
                    }
                    continue;
                }
            }
            break;
        }
        Ok(())
    }

    fn lex_token(&mut self) -> Result<(), LuxError> {
        let start = self.pos;
        let start_line = self.line;
        let start_col = self.col;
        let ch = self.advance().unwrap();

        let kind = match ch {
            // Delimiters
            b'(' => TokenKind::LParen,
            b')' => TokenKind::RParen,
            b'{' => TokenKind::LBrace,
            b'}' => TokenKind::RBrace,
            b'[' => TokenKind::LBracket,
            b']' => TokenKind::RBracket,

            // Punctuation
            b',' => TokenKind::Comma,
            b';' => TokenKind::Semicolon,
            b'@' => TokenKind::At,
            b'#' => TokenKind::Hash,

            // Two-char lookahead operators
            b'+' => {
                if self.peek() == Some(b'+') {
                    self.advance();
                    TokenKind::PlusPlus
                } else {
                    TokenKind::Plus
                }
            }
            b'-' => {
                if self.peek() == Some(b'>') {
                    self.advance();
                    TokenKind::Arrow
                } else {
                    TokenKind::Minus
                }
            }
            b'*' => TokenKind::Star,
            b'/' => TokenKind::Slash,
            b'%' => TokenKind::Percent,
            b'=' => {
                if self.peek() == Some(b'=') {
                    self.advance();
                    TokenKind::EqEq
                } else if self.peek() == Some(b'>') {
                    self.advance();
                    TokenKind::FatArrow
                } else {
                    TokenKind::Eq
                }
            }
            b'!' => {
                if self.peek() == Some(b'=') {
                    self.advance();
                    TokenKind::BangEq
                } else {
                    TokenKind::Bang
                }
            }
            b'<' => {
                if self.peek() == Some(b'=') {
                    self.advance();
                    TokenKind::LtEq
                } else if self.peek() == Some(b'|') {
                    self.advance();
                    TokenKind::Prism
                } else {
                    TokenKind::Lt
                }
            }
            b'>' => {
                if self.peek() == Some(b'=') {
                    self.advance();
                    TokenKind::GtEq
                } else if self.peek() == Some(b'<') {
                    self.advance();
                    TokenKind::Compose
                } else {
                    TokenKind::Gt
                }
            }
            b'&' => {
                if self.peek() == Some(b'&') {
                    self.advance();
                    TokenKind::And
                } else {
                    return Err(LexError {
                        kind: LexErrorKind::UnexpectedChar('&'),
                        span: self.span_from(start, start_line, start_col),
                    }
                    .into());
                }
            }
            b'|' => {
                if self.peek() == Some(b'|') {
                    self.advance();
                    TokenKind::Or
                } else if self.peek() == Some(b'>') {
                    self.advance();
                    TokenKind::PipeGt
                } else {
                    TokenKind::Pipe
                }
            }
            b'.' => {
                if self.peek() == Some(b'.') {
                    self.advance();
                    TokenKind::DotDot
                } else {
                    TokenKind::Dot
                }
            }
            b':' => {
                if self.peek() == Some(b':') {
                    self.advance();
                    TokenKind::ColonColon
                } else {
                    TokenKind::Colon
                }
            }

            // String literals
            b'"' => return self.lex_string(start, start_line, start_col),

            // Raw string literals (no interpolation)
            b'\'' => return self.lex_raw_string(start, start_line, start_col),

            // Number literals
            b'0'..=b'9' => return self.lex_number(start, start_line, start_col),

            // Identifiers and keywords
            b'a'..=b'z' | b'A'..=b'Z' => {
                return self.lex_ident(start, start_line, start_col);
            }
            b'_' => {
                // Could be underscore token or start of an identifier like _foo
                if matches!(
                    self.peek(),
                    Some(b'a'..=b'z' | b'A'..=b'Z' | b'0'..=b'9' | b'_')
                ) {
                    return self.lex_ident(start, start_line, start_col);
                } else {
                    TokenKind::Underscore
                }
            }

            _ => {
                return Err(LexError {
                    kind: LexErrorKind::UnexpectedChar(ch as char),
                    span: self.span_from(start, start_line, start_col),
                }
                .into());
            }
        };

        let span = self.span_from(start, start_line, start_col);
        self.tokens.push(Token::new(kind, span));
        Ok(())
    }

    fn lex_string(
        &mut self,
        start: usize,
        start_line: usize,
        start_col: usize,
    ) -> Result<(), LuxError> {
        let mut value = String::new();
        let mut parts: Vec<StringInterpPart> = Vec::new();
        loop {
            match self.peek() {
                None => {
                    return Err(LexError {
                        kind: LexErrorKind::UnterminatedString,
                        span: self.span_from(start, start_line, start_col),
                    }
                    .into());
                }
                Some(b'"') => {
                    self.advance();
                    break;
                }
                Some(b'\\') => {
                    self.advance();
                    match self.peek() {
                        Some(b'n') => {
                            self.advance();
                            value.push('\n');
                        }
                        Some(b't') => {
                            self.advance();
                            value.push('\t');
                        }
                        Some(b'\\') => {
                            self.advance();
                            value.push('\\');
                        }
                        Some(b'"') => {
                            self.advance();
                            value.push('"');
                        }
                        Some(b'{') => {
                            self.advance();
                            value.push('{');
                        }
                        Some(b'}') => {
                            self.advance();
                            value.push('}');
                        }
                        Some(ch) => {
                            return Err(LexError {
                                kind: LexErrorKind::InvalidEscape(ch as char),
                                span: self.span_from(self.pos - 1, self.line, self.col - 1),
                            }
                            .into());
                        }
                        None => {
                            return Err(LexError {
                                kind: LexErrorKind::UnterminatedString,
                                span: self.span_from(start, start_line, start_col),
                            }
                            .into());
                        }
                    }
                }
                Some(b'{') => {
                    // Start of an interpolated expression
                    if !value.is_empty() {
                        parts.push(StringInterpPart::Literal(std::mem::take(&mut value)));
                    }
                    self.advance(); // consume `{`
                    let tokens_start = self.tokens.len();
                    let mut depth: usize = 1;
                    while depth > 0 {
                        // Skip whitespace/comments before lexing each token inside `{}`
                        self.skip_whitespace_and_comments()?;
                        match self.peek() {
                            None => {
                                return Err(LexError {
                                    kind: LexErrorKind::UnterminatedString,
                                    span: self.span_from(start, start_line, start_col),
                                }
                                .into());
                            }
                            Some(b'{') => {
                                depth += 1;
                                self.lex_token()?;
                            }
                            Some(b'}') => {
                                depth -= 1;
                                if depth > 0 {
                                    self.lex_token()?;
                                } else {
                                    self.advance(); // consume closing `}`
                                }
                            }
                            _ => {
                                self.lex_token()?;
                            }
                        }
                    }
                    let inner_tokens: Vec<Token> = self.tokens.drain(tokens_start..).collect();
                    parts.push(StringInterpPart::Tokens(inner_tokens));
                }
                Some(ch) => {
                    self.advance();
                    value.push(ch as char);
                }
            }
        }
        let span = self.span_from(start, start_line, start_col);
        if parts.is_empty() {
            self.tokens
                .push(Token::new(TokenKind::StringLit(value), span));
        } else {
            if !value.is_empty() {
                parts.push(StringInterpPart::Literal(value));
            }
            self.tokens
                .push(Token::new(TokenKind::StringInterp(parts), span));
        }
        Ok(())
    }

    fn lex_number(
        &mut self,
        start: usize,
        start_line: usize,
        start_col: usize,
    ) -> Result<(), LuxError> {
        // Collect integer part (first digit already consumed)
        while let Some(b'0'..=b'9') = self.peek() {
            self.advance();
        }

        // Check for float: dot followed by a digit (not `..` range operator)
        let is_float =
            self.peek() == Some(b'.') && self.peek2().is_some_and(|c| c.is_ascii_digit());

        if is_float {
            self.advance(); // consume the dot
            while let Some(b'0'..=b'9') = self.peek() {
                self.advance();
            }
            let text = std::str::from_utf8(&self.source[start..self.pos]).unwrap();
            let val: f64 = text.parse().map_err(|_| LexError {
                kind: LexErrorKind::InvalidNumber(text.to_string()),
                span: self.span_from(start, start_line, start_col),
            })?;
            let span = self.span_from(start, start_line, start_col);
            self.tokens.push(Token::new(TokenKind::FloatLit(val), span));
        } else {
            let text = std::str::from_utf8(&self.source[start..self.pos]).unwrap();
            let val: i64 = text.parse().map_err(|_| LexError {
                kind: LexErrorKind::InvalidNumber(text.to_string()),
                span: self.span_from(start, start_line, start_col),
            })?;
            let span = self.span_from(start, start_line, start_col);
            self.tokens.push(Token::new(TokenKind::IntLit(val), span));
        }
        Ok(())
    }

    fn lex_ident(
        &mut self,
        start: usize,
        start_line: usize,
        start_col: usize,
    ) -> Result<(), LuxError> {
        // First character already consumed
        while let Some(b'a'..=b'z' | b'A'..=b'Z' | b'0'..=b'9' | b'_') = self.peek() {
            self.advance();
        }

        let text = std::str::from_utf8(&self.source[start..self.pos]).unwrap();
        let kind = match text {
            "let" => TokenKind::Let,
            "fn" => TokenKind::Fn,
            "if" => TokenKind::If,
            "else" => TokenKind::Else,
            "match" => TokenKind::Match,
            "type" => TokenKind::Type,
            "effect" => TokenKind::Effect,
            "handle" => TokenKind::Handle,
            "handler" => TokenKind::Handler,
            "with" => TokenKind::With,
            // "resume" is NOT a keyword — it's a regular identifier bound as a
            // Continuation value in handler bodies. This allows multi-shot:
            // `resume(true) ++ resume(false)` goes through call_value.
            "pub" => TokenKind::Pub,
            // own, ref, gc: context-sensitive in parse_param(), not keywords.
            // This lets the self-hosted compiler use 'own' as an identifier.
            "use" => TokenKind::Use,
            "mod" => TokenKind::Mod,
            "trait" => TokenKind::Trait,
            "impl" => TokenKind::Impl,
            "struct" => TokenKind::Struct,
            "enum" => TokenKind::Enum,
            "return" => TokenKind::Return,
            "loop" => TokenKind::Loop,
            "while" => TokenKind::While,
            "for" => TokenKind::For,
            "in" => TokenKind::In,
            "break" => TokenKind::Break,
            "continue" => TokenKind::Continue,
            "import" => TokenKind::Import,
            "assert" => TokenKind::Assert,
            "where" => TokenKind::Where,
            "true" => TokenKind::BoolLit(true),
            "false" => TokenKind::BoolLit(false),
            _ => TokenKind::Ident(text.to_string()),
        };

        let span = self.span_from(start, start_line, start_col);
        self.tokens.push(Token::new(kind, span));
        Ok(())
    }

    fn lex_raw_string(
        &mut self,
        start: usize,
        start_line: usize,
        start_col: usize,
    ) -> Result<(), LuxError> {
        let mut value = String::new();
        loop {
            match self.peek() {
                None => {
                    return Err(LexError {
                        kind: LexErrorKind::UnterminatedString,
                        span: self.span_from(start, start_line, start_col),
                    }
                    .into());
                }
                Some(b'\'') => {
                    self.advance();
                    break;
                }
                Some(b'\\') => {
                    self.advance();
                    match self.peek() {
                        Some(b'\'') => {
                            self.advance();
                            value.push('\'');
                        }
                        Some(b'\\') => {
                            self.advance();
                            value.push('\\');
                        }
                        Some(b'n') => {
                            self.advance();
                            value.push('\n');
                        }
                        Some(b't') => {
                            self.advance();
                            value.push('\t');
                        }
                        _ => {
                            // In raw strings, unknown escapes are kept literally
                            value.push('\\');
                        }
                    }
                }
                Some(ch) => {
                    self.advance();
                    value.push(ch as char);
                }
            }
        }
        let span = self.span_from(start, start_line, start_col);
        self.tokens
            .push(Token::new(TokenKind::StringLit(value), span));
        Ok(())
    }
}
