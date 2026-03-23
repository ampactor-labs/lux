/// Error types, pretty-printing, and progressive hints for Lux.
use crate::token::Span;
use crate::types::Type;
use std::fmt;

// ── Compiler Hints (progressive teaching) ─────────────────────

/// A compiler hint — progressive teaching, not error reporting.
///
/// Hints are always collected during type checking. The CLI decides
/// whether to display them (`--teach` flag). Each hint surfaces what
/// the compiler inferred and suggests annotations that would unlock
/// new guarantees.
#[derive(Debug, Clone)]
pub struct CompilerHint {
    pub kind: HintKind,
    pub fn_name: String,
    pub span: Span,
    /// Human-readable inferred signature
    pub inferred: String,
    /// Suggested annotations and what they unlock
    pub suggestions: Vec<HintSuggestion>,
}

#[derive(Debug, Clone)]
pub struct HintSuggestion {
    /// The annotation to add (e.g., "with Pure")
    pub annotation: String,
    /// What declaring this enables
    pub unlocks: String,
}

#[derive(Debug, Clone)]
pub enum HintKind {
    /// Function is provably pure but doesn't declare it
    PurityOpportunity,
    /// Function performs effects but doesn't declare them
    EffectsUndeclared,
    /// Nested function calls that would read better as pipe chains
    PipeSuggestion { nested: String, piped: String },
    /// A let binding whose value is never used
    UnusedBinding,
    /// Handler is tail-resumptive — zero-cost at runtime
    TailResumptiveHandler,
    /// Summary: effect budget for the module
    EffectBudget { pure_count: usize, effectful_count: usize },
}

/// Format a compiler hint for terminal display.
pub fn format_hint(hint: &CompilerHint, filename: Option<&str>) -> String {
    let filename = filename.unwrap_or("<input>");
    let mut out = String::new();

    match &hint.kind {
        HintKind::PurityOpportunity | HintKind::EffectsUndeclared => {
            let label = match hint.kind {
                HintKind::PurityOpportunity => "is pure",
                HintKind::EffectsUndeclared => "has effects",
                _ => unreachable!(),
            };
            out.push_str(&format!(
                "  fn {} {} (line {})\n",
                hint.fn_name, label, hint.span.line
            ));
            out.push_str(&format!(
                "    --> {}:{}:{}\n",
                filename, hint.span.line, hint.span.column
            ));
            out.push_str(&format!("    inferred: {}\n", hint.inferred));
            for suggestion in &hint.suggestions {
                out.push_str(&format!("    -> add `{}`\n", suggestion.annotation));
                out.push_str(&format!("       {}\n", suggestion.unlocks));
            }
        }
        HintKind::PipeSuggestion { nested, piped } => {
            out.push_str(&format!(
                "  pipe opportunity (line {})\n",
                hint.span.line
            ));
            out.push_str(&format!(
                "    --> {}:{}:{}\n",
                filename, hint.span.line, hint.span.column
            ));
            out.push_str(&format!("    found:  {}\n", nested));
            out.push_str(&format!("    prefer: {}\n", piped));
            out.push_str("    -> pipes read left-to-right, like data flows\n");
        }
        HintKind::UnusedBinding => {
            out.push_str(&format!(
                "  unused binding `{}` (line {})\n",
                hint.fn_name, hint.span.line
            ));
            out.push_str(&format!(
                "    --> {}:{}:{}\n",
                filename, hint.span.line, hint.span.column
            ));
            out.push_str("    -> prefix with `_` to indicate intentionally unused\n");
        }
        HintKind::TailResumptiveHandler => {
            out.push_str(&format!(
                "  handler `{}` is tail-resumptive (line {})\n",
                hint.fn_name, hint.span.line
            ));
            out.push_str(&format!(
                "    --> {}:{}:{}\n",
                filename, hint.span.line, hint.span.column
            ));
            out.push_str("    = compiled via evidence passing — zero overhead\n");
            out.push_str("    = no continuation captured, no heap allocation\n");
        }
        HintKind::EffectBudget { pure_count, effectful_count } => {
            let total = pure_count + effectful_count;
            if total > 0 {
                let pct = (*pure_count as f64 / total as f64 * 100.0) as usize;
                let bar_len = 20;
                let filled = bar_len * pct / 100;
                let bar: String = "█".repeat(filled) + &"░".repeat(bar_len - filled);
                out.push_str(&format!(
                    "  effect budget: {} pure  {}\n",
                    bar, pct
                ));
                out.push_str(&format!(
                    "    {} of {} functions are pure — candidates for memoization and parallelization\n",
                    pure_count, total
                ));
            }
        }
    }

    out
}

/// Format a summary of all hints for terminal display.
pub fn format_hint_summary(hints: &[CompilerHint]) -> String {
    let pure_count = hints
        .iter()
        .filter(|h| matches!(h.kind, HintKind::PurityOpportunity))
        .count();
    let effect_count = hints
        .iter()
        .filter(|h| matches!(h.kind, HintKind::EffectsUndeclared))
        .count();
    let pipe_count = hints
        .iter()
        .filter(|h| matches!(h.kind, HintKind::PipeSuggestion { .. }))
        .count();
    let unused_count = hints
        .iter()
        .filter(|h| matches!(h.kind, HintKind::UnusedBinding))
        .count();

    let mut parts = Vec::new();
    if pure_count > 0 {
        parts.push(format!("{pure_count} pure"));
    }
    if effect_count > 0 {
        parts.push(format!("{effect_count} effectful"));
    }
    if pipe_count > 0 {
        parts.push(format!("{pipe_count} pipe opportunities"));
    }
    if unused_count > 0 {
        parts.push(format!("{unused_count} unused bindings"));
    }

    let fn_count = hints.iter().filter(|h| matches!(h.kind, HintKind::PurityOpportunity | HintKind::EffectsUndeclared)).count();
    format!("  {} functions checked: {}", fn_count, parts.join(", "))
}

/// All errors that can occur in Lux compilation / interpretation.
#[derive(Debug, Clone)]
pub enum LuxError {
    Lexer(LexError),
    Parser(ParseError),
    Type(TypeError),
    Runtime(RuntimeError),
}

// ── Lexer errors ──────────────────────────────────────────────

#[derive(Debug, Clone)]
pub struct LexError {
    pub kind: LexErrorKind,
    pub span: Span,
}

#[derive(Debug, Clone)]
pub enum LexErrorKind {
    UnexpectedChar(char),
    UnterminatedString,
    InvalidNumber(String),
    InvalidEscape(char),
}

// ── Parser errors ─────────────────────────────────────────────

#[derive(Debug, Clone)]
pub struct ParseError {
    pub kind: ParseErrorKind,
    pub span: Span,
}

#[derive(Debug, Clone)]
pub enum ParseErrorKind {
    UnexpectedToken { expected: String, found: String },
    UnexpectedEof,
    InvalidPattern,
    InvalidTypeExpr,
    InvalidExpression,
}

// ── Type errors ───────────────────────────────────────────────

#[derive(Debug, Clone)]
pub struct TypeError {
    pub kind: TypeErrorKind,
    pub span: Span,
}

#[derive(Debug, Clone)]
pub enum TypeErrorKind {
    Mismatch {
        expected: Type,
        found: Type,
    },
    UnboundVariable(String),
    UnboundType(String),
    UnboundEffect(String),
    UnboundEffectOp(String),
    NotAFunction(Type),
    WrongArity {
        expected: usize,
        found: usize,
    },
    UnhandledEffect(String),
    /// Effect negation/Pure constraint violated: function performs `effect` but declares `constraint`.
    EffectConstraintViolation {
        effect: String,
        constraint: String,
    },
    InfiniteType,
    NonExhaustiveMatch { missing: Vec<String> },
    DuplicateDefinition(String),
    UnboundStateVar(String),
}

// ── Runtime errors ────────────────────────────────────────────

#[derive(Debug, Clone)]
pub struct RuntimeError {
    pub kind: RuntimeErrorKind,
    pub span: Span,
}

#[derive(Debug, Clone)]
pub enum RuntimeErrorKind {
    DivisionByZero,
    IndexOutOfBounds {
        index: i64,
        length: usize,
    },
    TypeError(String),
    UnhandledEffect {
        effect: String,
        operation: String,
    },
    MatchFailed,
    StackOverflow,
    /// User-triggered failure via the Fail effect
    UserFail(String),
    /// Assertion failure via `assert condition, message`
    AssertionFailed(String),
    /// Internal: should not happen
    Internal(String),
}

// ── Display implementations ───────────────────────────────────

impl fmt::Display for LuxError {
    fn fmt(&self, f: &mut fmt::Formatter<'_>) -> fmt::Result {
        match self {
            LuxError::Lexer(e) => write!(f, "{e}"),
            LuxError::Parser(e) => write!(f, "{e}"),
            LuxError::Type(e) => write!(f, "{e}"),
            LuxError::Runtime(e) => write!(f, "{e}"),
        }
    }
}

impl fmt::Display for LexError {
    fn fmt(&self, f: &mut fmt::Formatter<'_>) -> fmt::Result {
        match &self.kind {
            LexErrorKind::UnexpectedChar(c) => {
                write!(f, "unexpected character '{c}' at line {}", self.span.line)
            }
            LexErrorKind::UnterminatedString => {
                write!(f, "unterminated string at line {}", self.span.line)
            }
            LexErrorKind::InvalidNumber(s) => {
                write!(f, "invalid number '{s}' at line {}", self.span.line)
            }
            LexErrorKind::InvalidEscape(c) => {
                write!(f, "invalid escape '\\{c}' at line {}", self.span.line)
            }
        }
    }
}

impl fmt::Display for ParseError {
    fn fmt(&self, f: &mut fmt::Formatter<'_>) -> fmt::Result {
        match &self.kind {
            ParseErrorKind::UnexpectedToken { expected, found } => {
                write!(
                    f,
                    "expected {expected}, found {found} at line {}",
                    self.span.line
                )
            }
            ParseErrorKind::UnexpectedEof => write!(f, "unexpected end of file"),
            ParseErrorKind::InvalidPattern => {
                write!(f, "invalid pattern at line {}", self.span.line)
            }
            ParseErrorKind::InvalidTypeExpr => {
                write!(f, "invalid type expression at line {}", self.span.line)
            }
            ParseErrorKind::InvalidExpression => {
                write!(f, "invalid expression at line {}", self.span.line)
            }
        }
    }
}

impl fmt::Display for TypeError {
    fn fmt(&self, f: &mut fmt::Formatter<'_>) -> fmt::Result {
        match &self.kind {
            TypeErrorKind::Mismatch { expected, found } => {
                write!(
                    f,
                    "type mismatch: expected {expected}, found {found} at line {}",
                    self.span.line
                )
            }
            TypeErrorKind::UnboundVariable(name) => {
                write!(f, "unbound variable '{name}' at line {}", self.span.line)
            }
            TypeErrorKind::UnboundType(name) => {
                write!(f, "unknown type '{name}' at line {}", self.span.line)
            }
            TypeErrorKind::UnboundEffect(name) => {
                write!(f, "unknown effect '{name}' at line {}", self.span.line)
            }
            TypeErrorKind::UnboundEffectOp(name) => {
                write!(
                    f,
                    "unknown effect operation '{name}' at line {}",
                    self.span.line
                )
            }
            TypeErrorKind::NotAFunction(ty) => {
                write!(
                    f,
                    "expected a function, found {ty} at line {}",
                    self.span.line
                )
            }
            TypeErrorKind::WrongArity { expected, found } => {
                write!(
                    f,
                    "wrong number of arguments: expected {expected}, found {found} at line {}",
                    self.span.line
                )
            }
            TypeErrorKind::UnhandledEffect(name) => {
                write!(f, "unhandled effect '{name}' at line {}", self.span.line)
            }
            TypeErrorKind::EffectConstraintViolation { effect, constraint } => {
                write!(
                    f,
                    "performs effect '{effect}' but declares '{constraint}' at line {}",
                    self.span.line
                )
            }
            TypeErrorKind::InfiniteType => {
                write!(f, "infinite type at line {}", self.span.line)
            }
            TypeErrorKind::NonExhaustiveMatch { missing } => {
                let names = missing.join(", ");
                write!(f, "non-exhaustive match at line {} — missing: {names}", self.span.line)
            }
            TypeErrorKind::DuplicateDefinition(name) => {
                write!(
                    f,
                    "duplicate definition '{name}' at line {}",
                    self.span.line
                )
            }
            TypeErrorKind::UnboundStateVar(name) => {
                write!(
                    f,
                    "unknown handler state variable '{name}' at line {}",
                    self.span.line
                )
            }
        }
    }
}

impl fmt::Display for RuntimeError {
    fn fmt(&self, f: &mut fmt::Formatter<'_>) -> fmt::Result {
        match &self.kind {
            RuntimeErrorKind::DivisionByZero => write!(f, "division by zero"),
            RuntimeErrorKind::IndexOutOfBounds { index, length } => {
                write!(f, "index {index} out of bounds (length {length})")
            }
            RuntimeErrorKind::TypeError(msg) => write!(f, "runtime type error: {msg}"),
            RuntimeErrorKind::UnhandledEffect { effect, operation } => {
                write!(f, "unhandled effect: {effect}.{operation}")
            }
            RuntimeErrorKind::MatchFailed => write!(f, "match failed: no pattern matched"),
            RuntimeErrorKind::StackOverflow => write!(f, "stack overflow"),
            RuntimeErrorKind::UserFail(msg) => write!(f, "fail: {msg}"),
            RuntimeErrorKind::AssertionFailed(msg) => write!(f, "assertion failed: {msg}"),
            RuntimeErrorKind::Internal(msg) => write!(f, "internal error: {msg}"),
        }
    }
}

impl LuxError {
    /// Returns the span associated with this error.
    pub fn span(&self) -> &Span {
        match self {
            LuxError::Lexer(e) => &e.span,
            LuxError::Parser(e) => &e.span,
            LuxError::Type(e) => &e.span,
            LuxError::Runtime(e) => &e.span,
        }
    }

    /// Short description suitable for the caret line of a diagnostic.
    pub fn short_message(&self) -> String {
        match self {
            LuxError::Lexer(e) => match &e.kind {
                LexErrorKind::UnexpectedChar(c) => format!("unexpected character '{c}'"),
                LexErrorKind::UnterminatedString => "unterminated string".to_string(),
                LexErrorKind::InvalidNumber(s) => format!("invalid number '{s}'"),
                LexErrorKind::InvalidEscape(c) => format!("invalid escape '\\{c}'"),
            },
            LuxError::Parser(e) => match &e.kind {
                ParseErrorKind::UnexpectedToken { expected, found } => {
                    format!("expected {expected}, found {found}")
                }
                ParseErrorKind::UnexpectedEof => "unexpected end of file".to_string(),
                ParseErrorKind::InvalidPattern => "invalid pattern".to_string(),
                ParseErrorKind::InvalidTypeExpr => "invalid type expression".to_string(),
                ParseErrorKind::InvalidExpression => "invalid expression".to_string(),
            },
            LuxError::Type(e) => match &e.kind {
                TypeErrorKind::Mismatch { expected, found } => {
                    format!("expected {expected}, found {found}")
                }
                TypeErrorKind::UnboundVariable(name) => format!("unbound variable '{name}'"),
                TypeErrorKind::UnboundType(name) => format!("unknown type '{name}'"),
                TypeErrorKind::UnboundEffect(name) => format!("unknown effect '{name}'"),
                TypeErrorKind::UnboundEffectOp(name) => {
                    format!("unknown effect operation '{name}'")
                }
                TypeErrorKind::NotAFunction(ty) => format!("expected function, found {ty}"),
                TypeErrorKind::WrongArity { expected, found } => {
                    format!("expected {expected} args, found {found}")
                }
                TypeErrorKind::UnhandledEffect(name) => format!("unhandled effect '{name}'"),
                TypeErrorKind::EffectConstraintViolation { effect, constraint } => {
                    format!("performs effect '{effect}' but declares '{constraint}'")
                }
                TypeErrorKind::InfiniteType => "infinite type".to_string(),
                TypeErrorKind::NonExhaustiveMatch { missing } => {
                    let names = missing.join(", ");
                    format!("non-exhaustive match — missing: {names}")
                }
                TypeErrorKind::DuplicateDefinition(name) => {
                    format!("duplicate definition '{name}'")
                }
                TypeErrorKind::UnboundStateVar(name) => {
                    format!("unknown handler state variable '{name}'")
                }
            },
            LuxError::Runtime(e) => match &e.kind {
                RuntimeErrorKind::DivisionByZero => "division by zero".to_string(),
                RuntimeErrorKind::IndexOutOfBounds { index, length } => {
                    format!("index {index} out of bounds (length {length})")
                }
                RuntimeErrorKind::TypeError(msg) => msg.clone(),
                RuntimeErrorKind::UnhandledEffect { effect, operation } => {
                    format!("unhandled effect: {effect}.{operation}")
                }
                RuntimeErrorKind::MatchFailed => "no pattern matched".to_string(),
                RuntimeErrorKind::StackOverflow => "stack overflow".to_string(),
                RuntimeErrorKind::UserFail(msg) => format!("fail: {msg}"),
                RuntimeErrorKind::AssertionFailed(msg) => format!("assertion failed: {msg}"),
                RuntimeErrorKind::Internal(msg) => format!("internal: {msg}"),
            },
        }
    }
}

/// Format an error with source context: header, file/line/col pointer, source
/// line, and a caret underline. Falls back to a plain `"error: <message>"` if
/// the span references a line that does not exist in `source`.
pub fn format_error_with_source(error: &LuxError, source: &str, filename: Option<&str>) -> String {
    let span = error.span();
    let short_msg = error.short_message();
    let filename = filename.unwrap_or("<input>");

    // span.line and span.column are 1-based (from lexer)
    let display_line = span.line;
    let display_col = span.column;

    if display_line == 0 || source.is_empty() {
        return format!("error: {short_msg}");
    }

    let lines: Vec<&str> = source.lines().collect();
    let Some(source_line) = lines.get(display_line - 1) else {
        return format!("error: {short_msg}");
    };

    let line_num_width = display_line.to_string().len();
    let padding = " ".repeat(line_num_width);
    let caret_padding = " ".repeat(display_col.saturating_sub(1));

    let span_len = span.end.saturating_sub(span.start).max(1);
    let col_offset = display_col.saturating_sub(1);
    let available = source_line.len().saturating_sub(col_offset);
    let underline_len = span_len.min(available).max(1);
    let underline = "^".repeat(underline_len);

    format!(
        "error: {short_msg}\n  --> {filename}:{display_line}:{display_col}\n{padding} |\n{display_line} | {source_line}\n{padding} | {caret_padding}{underline}"
    )
}

impl std::error::Error for LuxError {}

// ── Conversions ───────────────────────────────────────────────

impl From<LexError> for LuxError {
    fn from(e: LexError) -> Self {
        LuxError::Lexer(e)
    }
}

impl From<ParseError> for LuxError {
    fn from(e: ParseError) -> Self {
        LuxError::Parser(e)
    }
}

impl From<TypeError> for LuxError {
    fn from(e: TypeError) -> Self {
        LuxError::Type(e)
    }
}

impl From<RuntimeError> for LuxError {
    fn from(e: RuntimeError) -> Self {
        LuxError::Runtime(e)
    }
}
