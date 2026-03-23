/// AST node types for Lux.
///
/// The AST is the shared interface between the parser (produces it),
/// the type checker (annotates it), and the interpreter (evaluates it).
use crate::token::Span;

/// A complete Lux program.
#[derive(Debug, Clone)]
pub struct Program {
    pub items: Vec<Item>,
}

/// Top-level items.
#[derive(Debug, Clone)]
pub enum Item {
    /// `fn name(params) -> RetType with Effects { body }`
    FnDecl(FnDecl),
    /// `let name = expr` at top level
    LetDecl(LetDecl),
    /// `type Name = Variant1(T) | Variant2(T)`
    TypeDecl(TypeDecl),
    /// `effect Name { op1(...) -> T, op2(...) -> T }`
    EffectDecl(EffectDecl),
    /// `trait Name { fn_decls }`
    TraitDecl(TraitDecl),
    /// `impl Trait for Type { fn_decls }`
    ImplBlock(ImplBlock),
    /// `import path/to/module` or `import path/to/module as alias`
    Import(ImportDecl),
    /// `handler name [: base] [with state = init] { clauses }`
    HandlerDecl(HandlerDecl),
    /// A bare expression (for REPL / scripts)
    Expr(Expr),
}

// ── Trait declarations ────────────────────────────────────────

#[derive(Debug, Clone)]
pub struct TraitDecl {
    pub name: String,
    pub methods: Vec<TraitMethod>,
    pub span: Span,
}

#[derive(Debug, Clone)]
pub struct TraitMethod {
    pub name: String,
    pub params: Vec<Param>,
    pub return_type: Option<TypeExpr>,
    pub span: Span,
}

#[derive(Debug, Clone)]
pub struct ImplBlock {
    pub trait_name: String,
    pub target_type: TypeExpr,
    pub methods: Vec<FnDecl>,
    pub span: Span,
}

// ── Imports ───────────────────────────────────────────────────

/// `import std/list` or `import ./my_module as m`
#[derive(Debug, Clone)]
pub struct ImportDecl {
    /// Path segments: `["std", "list"]` for `import std/list`.
    pub path: Vec<String>,
    /// Optional alias: `import std/list as l`.
    pub alias: Option<String>,
    pub span: Span,
}

// ── Declarations ──────────────────────────────────────────────

#[derive(Debug, Clone)]
pub struct FnDecl {
    pub name: String,
    pub type_params: Vec<String>,
    pub params: Vec<Param>,
    pub return_type: Option<TypeExpr>,
    pub effects: Vec<EffectRef>,
    pub body: Expr,
    pub span: Span,
}

/// Ownership annotation on the annotation gradient.
/// `Inferred` = no annotation (the default — compiler infers).
/// `Own` = caller transfers ownership (move semantics).
/// `Ref` = caller lends a reference (borrow semantics).
#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub enum Ownership {
    /// No annotation — ownership inferred from usage.
    Inferred,
    /// `own` — takes ownership (value is moved).
    Own,
    /// `ref` — borrows a reference (value is not consumed).
    Ref,
}

#[derive(Debug, Clone)]
pub struct Param {
    pub name: String,
    pub ownership: Ownership,
    pub type_ann: Option<TypeExpr>,
    pub span: Span,
}

#[derive(Debug, Clone)]
pub struct LetDecl {
    pub pattern: Pattern,
    pub type_ann: Option<TypeExpr>,
    pub value: Expr,
    pub span: Span,
}

#[derive(Debug, Clone)]
pub struct TypeDecl {
    pub name: String,
    pub type_params: Vec<String>,
    pub variants: Vec<Variant>,
    pub span: Span,
}

/// A field in an ADT variant — either positional (name is None) or named.
#[derive(Debug, Clone)]
pub struct VariantField {
    pub name: Option<String>,
    pub ty: TypeExpr,
}

#[derive(Debug, Clone)]
pub struct Variant {
    pub name: String,
    pub fields: Vec<VariantField>,
    pub span: Span,
}

#[derive(Debug, Clone)]
pub struct EffectDecl {
    pub name: String,
    pub type_params: Vec<String>,
    pub operations: Vec<EffectOp>,
    pub span: Span,
}

#[derive(Debug, Clone)]
pub struct EffectOp {
    pub name: String,
    pub params: Vec<Param>,
    pub return_type: TypeExpr,
    pub span: Span,
}

/// A named, reusable handler declaration.
#[derive(Debug, Clone)]
pub struct HandlerDecl {
    pub name: String,
    /// Optional base handler to inherit clauses from: `handler child: parent { ... }`
    pub base: Option<String>,
    pub clauses: Vec<HandlerClause>,
    pub state_bindings: Vec<StateBinding>,
    pub span: Span,
}

// ── Expressions ───────────────────────────────────────────────

#[derive(Debug, Clone)]
pub enum Expr {
    /// Integer literal
    IntLit(i64, Span),
    /// Float literal
    FloatLit(f64, Span),
    /// String literal (with interpolation already resolved)
    StringLit(String, Span),
    /// Bool literal
    BoolLit(bool, Span),
    /// Variable reference
    Var(String, Span),
    /// List literal `[a, b, c]`
    List(Vec<Expr>, Span),

    /// Binary operation `a + b`
    BinOp {
        op: BinOp,
        left: Box<Expr>,
        right: Box<Expr>,
        span: Span,
    },
    /// Unary operation `!a`, `-a`
    UnaryOp {
        op: UnaryOp,
        operand: Box<Expr>,
        span: Span,
    },

    /// Function call `f(a, b)`
    Call {
        func: Box<Expr>,
        args: Vec<Expr>,
        span: Span,
    },
    /// Field access `a.b`
    FieldAccess {
        object: Box<Expr>,
        field: String,
        span: Span,
    },
    /// Index `a[b]`
    Index {
        object: Box<Expr>,
        index: Box<Expr>,
        span: Span,
    },

    /// Lambda `|params| body`
    Lambda {
        params: Vec<Param>,
        body: Box<Expr>,
        span: Span,
    },

    /// Block `{ stmt1; stmt2; expr }`
    Block {
        stmts: Vec<Stmt>,
        expr: Option<Box<Expr>>,
        span: Span,
    },

    /// `if cond { then } else { otherwise }`
    If {
        condition: Box<Expr>,
        then_branch: Box<Expr>,
        else_branch: Option<Box<Expr>>,
        span: Span,
    },

    /// `match scrutinee { pat => expr, ... }`
    Match {
        scrutinee: Box<Expr>,
        arms: Vec<MatchArm>,
        span: Span,
    },

    /// `let pattern = value` as expression (in blocks)
    Let {
        pattern: Pattern,
        type_ann: Option<TypeExpr>,
        value: Box<Expr>,
        span: Span,
    },

    /// Pipe `expr |> func`
    Pipe {
        left: Box<Expr>,
        right: Box<Expr>,
        span: Span,
    },

    /// String interpolation `"Hello, {name}!"`
    StringInterp { parts: Vec<StringPart>, span: Span },

    /// `handle expr [with state = init, ...] { handler_clauses }`
    Handle {
        expr: Box<Expr>,
        handlers: Vec<HandlerClause>,
        state_bindings: Vec<StateBinding>,
        span: Span,
    },

    /// `resume(value) [with name = expr, ...]` — resume a suspended effect computation
    Resume {
        value: Box<Expr>,
        state_updates: Vec<StateUpdate>,
        span: Span,
    },

    /// Perform an effect operation (implicitly: just call it like a function)
    /// The checker resolves plain `Call` nodes that reference effect ops into this.
    Perform {
        effect: String,
        operation: String,
        args: Vec<Expr>,
        span: Span,
    },

    /// `return expr`
    Return { value: Box<Expr>, span: Span },

    /// `assert condition, message`
    Assert {
        condition: Box<Expr>,
        message: Box<Expr>,
        span: Span,
    },

    /// Tuple literal `(a, b, c)`
    Tuple(Vec<Expr>, Span),

    /// `while condition { body }`
    While {
        condition: Box<Expr>,
        body: Box<Expr>,
        span: Span,
    },
    /// `loop { body }`
    Loop { body: Box<Expr>, span: Span },
    /// `for binding in iterable { body }`
    For {
        binding: String,
        iterable: Box<Expr>,
        body: Box<Expr>,
        span: Span,
    },
    /// `break` or `break value`
    Break {
        value: Option<Box<Expr>>,
        span: Span,
    },
    /// `continue`
    Continue { span: Span },

    /// Record construction: `Name { field: expr, ... }`
    RecordConstruct {
        name: String,
        fields: Vec<(String, Expr)>,
        span: Span,
    },

    /// Anonymous record literal: `{ x: 3, y: 4 }`
    /// Distinct from `RecordConstruct` (which wraps a named ADT variant).
    RecordLit {
        fields: Vec<(String, Expr)>,
        span: Span,
    },
}

impl Expr {
    pub fn span(&self) -> &Span {
        match self {
            Expr::IntLit(_, s)
            | Expr::FloatLit(_, s)
            | Expr::StringLit(_, s)
            | Expr::BoolLit(_, s)
            | Expr::Var(_, s)
            | Expr::List(_, s) => s,
            Expr::BinOp { span, .. }
            | Expr::UnaryOp { span, .. }
            | Expr::Call { span, .. }
            | Expr::FieldAccess { span, .. }
            | Expr::Index { span, .. }
            | Expr::Lambda { span, .. }
            | Expr::Block { span, .. }
            | Expr::If { span, .. }
            | Expr::Match { span, .. }
            | Expr::Let { span, .. }
            | Expr::Pipe { span, .. }
            | Expr::StringInterp { span, .. }
            | Expr::Handle { span, .. }
            | Expr::Resume { span, .. }
            | Expr::Perform { span, .. }
            | Expr::Return { span, .. }
            | Expr::Assert { span, .. }
            | Expr::While { span, .. }
            | Expr::Loop { span, .. }
            | Expr::For { span, .. }
            | Expr::Break { span, .. }
            | Expr::Continue { span, .. }
            | Expr::RecordConstruct { span, .. }
            | Expr::RecordLit { span, .. } => span,
            Expr::Tuple(_, s) => s,
        }
    }
}

#[derive(Debug, Clone)]
pub enum Stmt {
    Let(LetDecl),
    Expr(Expr),
    FnDecl(FnDecl),
}

// ── Operators ─────────────────────────────────────────────────

#[derive(Debug, Clone, Copy, PartialEq)]
pub enum BinOp {
    Add,
    Sub,
    Mul,
    Div,
    Mod,
    Eq,
    Neq,
    Lt,
    LtEq,
    Gt,
    GtEq,
    And,
    Or,
    Concat, // ++
}

#[derive(Debug, Clone, Copy, PartialEq)]
pub enum UnaryOp {
    Neg,
    Not,
}

// ── Patterns ──────────────────────────────────────────────────

#[derive(Debug, Clone)]
pub struct MatchArm {
    pub pattern: Pattern,
    pub guard: Option<Expr>,
    pub body: Expr,
    pub span: Span,
}

#[derive(Debug, Clone)]
pub enum Pattern {
    /// `_` — matches anything
    Wildcard(Span),
    /// `name` — binds to a variable
    Binding(String, Span),
    /// `42`, `"hello"`, `true`
    Literal(LitPattern, Span),
    /// `Some(x)` or `Cons(head, tail)` — positional variant pattern
    Variant {
        name: String,
        fields: Vec<Pattern>,
        span: Span,
    },
    /// `Person { name, age }` — named field variant pattern
    Record {
        name: String,
        fields: Vec<(String, Pattern)>,
        span: Span,
    },
    /// `(a, b, c)`
    Tuple(Vec<Pattern>, Span),
    /// `[a, b, c]` or `[head, ...tail]` — list destructuring
    List {
        elements: Vec<Pattern>,
        rest: Option<Box<Pattern>>,
        span: Span,
    },
    /// `A | B | C` — or-pattern (all alternatives must bind same variables)
    Or(Vec<Pattern>, Span),
}

#[derive(Debug, Clone)]
pub enum LitPattern {
    Int(i64),
    Float(f64),
    String(String),
    Bool(bool),
}

// ── Types ─────────────────────────────────────────────────────

/// Type expressions as written in source code (before inference).
#[derive(Debug, Clone)]
pub enum TypeExpr {
    /// Named type: `Int`, `String`, `Option<T>`
    Named {
        name: String,
        args: Vec<TypeExpr>,
        span: Span,
    },
    /// Function type: `(A, B) -> C with E1, E2`
    Function {
        params: Vec<TypeExpr>,
        return_type: Box<TypeExpr>,
        effects: Vec<EffectRef>,
        span: Span,
    },
    /// Tuple type: `(A, B, C)`
    Tuple(Vec<TypeExpr>, Span),
    /// List type: `List<T>` or `[T]`
    List(Box<TypeExpr>, Span),
    /// Inferred (no annotation provided)
    Inferred(Span),
}

/// Reference to an effect in type annotations.
///
/// When `negated` is true, this represents a negation constraint (`!IO`):
/// the function must NOT perform this effect. `Pure` (name="Pure", negated=false)
/// means the function must have no effects at all.
#[derive(Debug, Clone)]
pub struct EffectRef {
    pub name: String,
    pub type_args: Vec<TypeExpr>,
    /// True for `!IO`, `!Alloc` — negation constraints.
    pub negated: bool,
    pub span: Span,
}

// ── String interpolation ──────────────────────────────────────

#[derive(Debug, Clone)]
#[allow(clippy::large_enum_variant)]
pub enum StringPart {
    Literal(String),
    Expr(Expr),
}

// ── Effect handling ───────────────────────────────────────────

/// A state binding in a `handle ... with name = expr { ... }` expression.
#[derive(Debug, Clone)]
pub struct StateBinding {
    pub name: String,
    pub init: Expr,
    pub span: Span,
}

/// A state update in `resume(val) with name = expr`.
#[derive(Debug, Clone)]
pub struct StateUpdate {
    pub name: String,
    pub value: Expr,
    pub span: Span,
}

/// A clause in a `handle` expression.
#[derive(Debug, Clone)]
pub struct HandlerClause {
    /// The operation being handled (e.g., "print", "fail").
    /// `None` means a `use SomeHandler` clause.
    pub operation: HandlerOp,
    pub span: Span,
}

#[derive(Debug, Clone)]
#[allow(clippy::large_enum_variant)]
pub enum HandlerOp {
    /// Handle a specific effect operation: `op(params) => body`
    OpHandler {
        effect_name: Option<String>,
        op_name: String,
        params: Vec<String>,
        body: Expr,
        /// True if the handler body is tail-resumptive (resume is the last action,
        /// no state updates). Set by compiler/interpreter, not parser.
        tail_resumptive: bool,
    },
    /// `use HandlerName` — delegate to a named handler
    UseHandler { name: String },
}
