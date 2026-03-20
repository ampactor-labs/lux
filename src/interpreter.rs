#![allow(clippy::result_large_err, clippy::large_enum_variant)]
//! Tree-walking interpreter for the Lux language.
//!
//! Evaluates AST nodes produced by the parser. The key feature is algebraic
//! effect handling: `perform` signals an effect, `handle` installs handlers,
//! and `resume` continues the suspended computation.
//!
//! # Generators
//!
//! Generators are implemented via OS threads and channels. `generate(func)`
//! spawns a thread that runs `func` with a special `yield` interceptor. The
//! interceptor sends values through a channel and blocks until `next()` is
//! called. `next(gen)` signals the thread to continue and receives the next
//! yielded value as `Some(val)`, or `None` when the generator is exhausted.

use std::collections::HashMap;
use std::fmt;
use std::sync::{Arc, Mutex};

use crate::ast::{
    self, BinOp, Expr, HandlerOp, ImplBlock, Item, MatchArm, Pattern, Program, Stmt, StringPart,
    UnaryOp,
};
use crate::env::Environment;
use crate::error::{LuxError, RuntimeError, RuntimeErrorKind};
use crate::token::Span;

// ── Replay (multi-shot continuations) ────────────────────────────

/// One replay entry: what resume returned + state updates at that point.
#[derive(Debug, Clone)]
pub struct ReplayEntry {
    pub(crate) resume_value: Value,
    pub(crate) state_updates: Vec<(String, Value)>,
}

// ── Value ────────────────────────────────────────────────────────

/// A runtime value in the Lux interpreter.
#[derive(Debug, Clone)]
pub enum Value {
    Int(i64),
    Float(f64),
    String(String),
    Bool(bool),
    Unit,
    List(Vec<Value>),
    Tuple(Vec<Value>),
    /// A closure: captured env + param names + body.
    ///
    /// Body and closure are `Arc`-shared so that cloning a `Value::Function` is
    /// O(1) (just refcount bumps) instead of deep-copying the AST and env.
    Function {
        name: Option<String>,
        params: Vec<String>,
        body: Arc<Expr>,
        closure_env: Arc<Environment>,
    },
    /// A built-in function.
    BuiltinFn {
        name: String,
        func: fn(Vec<Value>) -> Result<Value, RuntimeError>,
    },
    /// An ADT variant value: `Some(42)` becomes `AdtVariant { name: "Some", fields: [Int(42)] }`.
    AdtVariant {
        name: String,
        fields: Vec<Value>,
    },
    /// A lazy generator backed by a thread.
    ///
    /// `receiver` delivers yielded values one at a time. The channel is a
    /// rendezvous (capacity 0), so the generator thread blocks after each
    /// `yield` until `next()` consumes the value — providing natural
    /// backpressure. `None` signals exhaustion.
    Generator {
        receiver: Arc<Mutex<std::sync::mpsc::Receiver<Option<Value>>>>,
    },
    /// A captured continuation: calling `resume(val)` replays the handle body
    /// with the extended effect log and returns the body's completion value.
    Continuation {
        body: Arc<Expr>,
        handler_clauses: Arc<Vec<ast::HandlerClause>>,
        state_bindings: Arc<Vec<ast::StateBinding>>,
        initial_state: HashMap<String, Value>,
        replay_log: Vec<ReplayEntry>,
        env: Arc<Environment>,
        handler_stack_snapshot: Vec<HandlerFrame>,
    },
}

impl fmt::Display for Value {
    fn fmt(&self, f: &mut fmt::Formatter<'_>) -> fmt::Result {
        match self {
            Value::Int(n) => write!(f, "{n}"),
            Value::Float(v) => write!(f, "{v}"),
            Value::String(s) => write!(f, "\"{s}\""),
            Value::Bool(b) => write!(f, "{b}"),
            Value::Unit => write!(f, "()"),
            Value::List(vs) => {
                write!(f, "[")?;
                for (i, v) in vs.iter().enumerate() {
                    if i > 0 {
                        write!(f, ", ")?;
                    }
                    write!(f, "{v}")?;
                }
                write!(f, "]")
            }
            Value::Tuple(vs) => {
                write!(f, "(")?;
                for (i, v) in vs.iter().enumerate() {
                    if i > 0 {
                        write!(f, ", ")?;
                    }
                    write!(f, "{v}")?;
                }
                if vs.len() == 1 {
                    write!(f, ",")?;
                }
                write!(f, ")")
            }
            Value::Function { .. } => write!(f, "<function>"),
            Value::BuiltinFn { name, .. } => write!(f, "<builtin:{name}>"),
            Value::Generator { .. } => write!(f, "<generator>"),
            Value::Continuation { .. } => write!(f, "<continuation>"),
            Value::AdtVariant { name, fields } if fields.is_empty() => write!(f, "{name}"),
            Value::AdtVariant { name, fields } => {
                write!(f, "{name}(")?;
                for (i, v) in fields.iter().enumerate() {
                    if i > 0 {
                        write!(f, ", ")?;
                    }
                    write!(f, "{v}")?;
                }
                write!(f, ")")
            }
        }
    }
}

impl Value {
    /// Display a value for `print`/`println` — strings without quotes.
    pub fn display_print(&self) -> String {
        match self {
            Value::String(s) => s.clone(),
            other => format!("{other}"),
        }
    }
}

impl PartialEq for Value {
    fn eq(&self, other: &Self) -> bool {
        match (self, other) {
            (Value::Int(a), Value::Int(b)) => a == b,
            (Value::Float(a), Value::Float(b)) => a == b,
            (Value::String(a), Value::String(b)) => a == b,
            (Value::Bool(a), Value::Bool(b)) => a == b,
            (Value::Unit, Value::Unit) => true,
            (Value::List(a), Value::List(b)) => a == b,
            (Value::Tuple(a), Value::Tuple(b)) => a == b,
            (
                Value::AdtVariant {
                    name: n1,
                    fields: f1,
                },
                Value::AdtVariant {
                    name: n2,
                    fields: f2,
                },
            ) => n1 == n2 && f1 == f2,
            (Value::Generator { .. }, Value::Generator { .. }) => false,
            (Value::Continuation { .. }, Value::Continuation { .. }) => false,
            _ => false,
        }
    }
}

// ── Helpers ───────────────────────────────────────────────────────

/// Returns a canonical type name string for a runtime value.
fn value_type_name(val: &Value) -> &'static str {
    match val {
        Value::Int(_) => "Int",
        Value::Float(_) => "Float",
        Value::String(_) => "String",
        Value::Bool(_) => "Bool",
        Value::Unit => "Unit",
        Value::List(_) => "List",
        Value::Tuple(_) => "Tuple",
        Value::Function { .. } | Value::BuiltinFn { .. } => "Function",
        Value::AdtVariant { .. } => "Adt",
        Value::Generator { .. } => "Generator",
        Value::Continuation { .. } => "Continuation",
    }
}

/// Convert a TypeExpr in an impl block to its canonical type name.
fn impl_type_name(te: &crate::ast::TypeExpr) -> String {
    use crate::ast::TypeExpr;
    match te {
        TypeExpr::Named { name, .. } => name.clone(),
        TypeExpr::List(_, _) => "List".to_string(),
        TypeExpr::Tuple(_, _) => "Tuple".to_string(),
        TypeExpr::Function { .. } => "Function".to_string(),
        TypeExpr::Inferred(_) => "_".to_string(),
    }
}

// ── Signal — internal control flow ───────────────────────────────

/// Signals that interrupt normal evaluation.
#[derive(Debug)]
enum Signal {
    /// `return expr` — unwind to function boundary.
    Return(Value),
    /// An effect was performed and no handler was found.
    #[allow(dead_code)]
    Perform {
        effect: String,
        operation: String,
        args: Vec<Value>,
        span: Span,
    },
    /// `resume(val)` inside a handler body, with optional state updates.
    Resume {
        value: Value,
        state_updates: Vec<(String, Value)>,
    },
    /// A handler completed without calling resume — short-circuit back to handle expr.
    HandleDone(Value),
    /// `break` or `break value` — unwind to loop boundary.
    Break(Value),
    /// `continue` — skip to next loop iteration.
    Continue,
    /// Tail call optimization: self-recursive call in tail position detected.
    ///
    /// Caught by the trampoline loop in `call_value` to reuse the current
    /// stack frame instead of growing the call stack.
    TailCall { func: Value, args: Vec<Value> },
}

type EvalResult = Result<Value, Signal>;

impl From<RuntimeError> for Signal {
    fn from(e: RuntimeError) -> Self {
        Signal::Perform {
            effect: "Fail".to_string(),
            operation: "fail".to_string(),
            args: vec![Value::String(format!("{e}"))],
            span: e.span,
        }
    }
}

// ── Handler frames ───────────────────────────────────────────────

#[derive(Debug, Clone)]
pub struct EffectHandler {
    pub(crate) params: Vec<String>,
    pub(crate) body: Expr,
    pub(crate) env: Environment,
}

#[derive(Debug, Clone)]
pub struct HandlerFrame {
    pub(crate) handlers: HashMap<String, EffectHandler>,
    pub(crate) state: HashMap<String, Value>,
}

// ── Continuation context ─────────────────────────────────────────

/// Context captured for building continuations during effect dispatch.
#[derive(Clone)]
struct ContinuationContext {
    body: Arc<Expr>,
    handler_clauses: Arc<Vec<ast::HandlerClause>>,
    state_bindings: Arc<Vec<ast::StateBinding>>,
    initial_state: HashMap<String, Value>,
    env: Arc<Environment>,
}

// ── Interpreter ──────────────────────────────────────────────────

/// The Lux interpreter. Holds runtime state across evaluations.
pub struct Interpreter {
    env: Environment,
    handler_stack: Vec<HandlerFrame>,
    /// Known variant constructor names (0-field variants act as constants).
    variant_constructors: HashMap<String, usize>,
    /// Known effect operation names → (effect_name, param_count).
    effect_ops: HashMap<String, (String, usize)>,
    /// Named field order for record variants: variant_name → [field_name, ...]
    variant_field_names: HashMap<String, Vec<String>>,
    call_depth: usize,
    /// Name of the function currently executing, used for tail call detection.
    current_fn_name: Option<String>,
    /// Whether the current evaluation position is in tail position of the
    /// enclosing function. Set to `true` before evaluating a function body
    /// and selectively propagated through blocks, if, and match branches.
    in_tail_position: bool,
    /// Named handler declarations for handler composition.
    named_handlers: HashMap<
        String,
        (
            Vec<crate::ast::HandlerClause>,
            Vec<crate::ast::StateBinding>,
        ),
    >,
    /// When running inside a generator thread, holds the sender used to
    /// deliver yielded values to `next()` callers.
    ///
    /// The channel is a rendezvous (capacity 0): `send` blocks until the
    /// receiver calls `recv`, naturally pausing the generator between yields.
    generator_sender: Option<std::sync::mpsc::SyncSender<Option<Value>>>,
    /// Method dispatch table: (type_name, method_name) -> function value
    impl_methods: HashMap<(String, String), Value>,
    /// Replay log for multi-shot continuation re-evaluation. `None` = normal mode.
    replay_log: Option<Vec<ReplayEntry>>,
    /// Current position in the replay log.
    replay_pos: usize,
    /// Context for building continuations during handle body evaluation.
    continuation_context: Option<ContinuationContext>,
}

const MAX_CALL_DEPTH: usize = 512;

impl Interpreter {
    /// Create a new interpreter with built-in functions registered.
    pub fn new() -> Self {
        let mut interp = Self {
            env: Environment::new(),
            handler_stack: Vec::new(),
            variant_constructors: HashMap::new(),
            effect_ops: HashMap::new(),
            variant_field_names: HashMap::new(),
            call_depth: 0,
            current_fn_name: None,
            in_tail_position: false,
            named_handlers: HashMap::new(),
            generator_sender: None,
            impl_methods: HashMap::new(),
            replay_log: None,
            replay_pos: 0,
            continuation_context: None,
        };
        interp.register_builtins();
        interp.register_builtin_variants();
        interp.register_builtin_effects();
        interp
    }

    fn register_builtins(&mut self) {
        let mut register = |name: &str, func: fn(Vec<Value>) -> Result<Value, RuntimeError>| {
            self.register_builtin(name, func);
        };
        crate::builtins::register_builtins(&mut register);
    }

    fn register_builtin(
        &mut self,
        name: &str,
        func: fn(Vec<Value>) -> Result<Value, RuntimeError>,
    ) {
        self.env.set(
            name,
            Value::BuiltinFn {
                name: name.to_string(),
                func,
            },
        );
    }

    fn register_builtin_effects(&mut self) {
        // Register `yield` as a known effect operation so that `eval_call`
        // routes `yield(val)` through `dispatch_effect`. Inside a generator
        // thread, `dispatch_effect` intercepts it natively via
        // `generator_channels`. Outside a generator, a user-installed handler
        // (or an unhandled-effect error) applies as normal.
        self.effect_ops
            .insert("yield".to_string(), ("Yield".to_string(), 1));
    }

    fn register_impl_block(&mut self, decl: &ImplBlock) {
        let type_name = impl_type_name(&decl.target_type);
        for method in &decl.methods {
            let params: Vec<String> = method.params.iter().map(|p| p.name.clone()).collect();
            let val = Value::Function {
                name: Some(method.name.clone()),
                params,
                body: Arc::new(method.body.clone()),
                closure_env: self.env.capture(),
            };
            self.impl_methods
                .insert((type_name.clone(), method.name.clone()), val);
        }
    }

    fn register_builtin_variants(&mut self) {
        // Option variants
        self.variant_constructors.insert("None".to_string(), 0);
        self.variant_constructors.insert("Some".to_string(), 1);
        // Result variants
        self.variant_constructors.insert("Ok".to_string(), 1);
        self.variant_constructors.insert("Err".to_string(), 1);

        // Register 0-field variants as values in the environment.
        self.env.set(
            "None",
            Value::AdtVariant {
                name: "None".to_string(),
                fields: vec![],
            },
        );
    }

    // ── Public API ───────────────────────────────────────────────

    /// Evaluate a single expression string (for the REPL).
    pub fn eval_line(&mut self, program: &Program) -> Result<Option<Value>, LuxError> {
        let mut last = None;
        for item in &program.items {
            last = self
                .exec_item(item)
                .map_err(|sig| self.signal_to_error(sig))?;
        }
        Ok(last)
    }

    fn signal_to_error(&self, sig: Signal) -> LuxError {
        match sig {
            Signal::Return(v) => LuxError::Runtime(RuntimeError {
                kind: RuntimeErrorKind::Internal(format!("unexpected return: {v}")),
                span: Span::dummy(),
            }),
            Signal::Perform {
                effect,
                operation,
                span,
                ..
            } => LuxError::Runtime(RuntimeError {
                kind: RuntimeErrorKind::UnhandledEffect { effect, operation },
                span,
            }),
            Signal::Resume { value, .. } => LuxError::Runtime(RuntimeError {
                kind: RuntimeErrorKind::Internal(format!("resume outside handler: {value}")),
                span: Span::dummy(),
            }),
            Signal::HandleDone(v) => LuxError::Runtime(RuntimeError {
                kind: RuntimeErrorKind::Internal(format!("handle done outside handle: {v}")),
                span: Span::dummy(),
            }),
            Signal::Break(_) => LuxError::Runtime(RuntimeError {
                kind: RuntimeErrorKind::Internal("break outside of loop".to_string()),
                span: Span::dummy(),
            }),
            Signal::Continue => LuxError::Runtime(RuntimeError {
                kind: RuntimeErrorKind::Internal("continue outside of loop".to_string()),
                span: Span::dummy(),
            }),
            Signal::TailCall { .. } => LuxError::Runtime(RuntimeError {
                kind: RuntimeErrorKind::Internal("TailCall signal escaped trampoline".to_string()),
                span: Span::dummy(),
            }),
        }
    }

    // ── Items ────────────────────────────────────────────────────

    fn exec_item(&mut self, item: &Item) -> Result<Option<Value>, Signal> {
        match item {
            Item::FnDecl(decl) => {
                let params: Vec<String> = decl.params.iter().map(|p| p.name.clone()).collect();
                let val = Value::Function {
                    name: Some(decl.name.clone()),
                    params,
                    body: Arc::new(decl.body.clone()),
                    closure_env: self.env.capture(),
                };
                self.env.set(&decl.name, val);
                Ok(None)
            }
            Item::LetDecl(decl) => {
                let val = self.eval_expr(&decl.value)?;
                self.bind_pattern_val(&decl.pattern, val);
                Ok(None)
            }
            Item::TypeDecl(decl) => {
                for variant in &decl.variants {
                    let arity = variant.fields.len();
                    self.variant_constructors
                        .insert(variant.name.clone(), arity);
                    // Register field names for named-field variants
                    let field_names: Vec<String> = variant
                        .fields
                        .iter()
                        .enumerate()
                        .map(|(idx, f)| f.name.clone().unwrap_or_else(|| format!("_{idx}")))
                        .collect();
                    if variant.fields.iter().any(|f| f.name.is_some()) {
                        self.variant_field_names
                            .insert(variant.name.clone(), field_names);
                    }
                    if arity == 0 {
                        self.env.set(
                            &variant.name,
                            Value::AdtVariant {
                                name: variant.name.clone(),
                                fields: vec![],
                            },
                        );
                    }
                }
                Ok(None)
            }
            Item::EffectDecl(decl) => {
                for op in &decl.operations {
                    self.effect_ops
                        .insert(op.name.clone(), (decl.name.clone(), op.params.len()));
                }
                Ok(None)
            }
            Item::TraitDecl(_decl) => {
                // Trait declarations have no runtime representation.
                Ok(None)
            }
            Item::ImplBlock(decl) => {
                self.register_impl_block(decl);
                Ok(None)
            }
            Item::Import(_) => {
                // Imports are resolved before interpretation.
                Ok(None)
            }
            Item::HandlerDecl(decl) => {
                let mut clauses = Vec::new();
                // If base handler exists, start with its clauses
                if let Some(base_name) = &decl.base {
                    if let Some((base_clauses, _)) = self.named_handlers.get(base_name) {
                        clauses = base_clauses.clone();
                    }
                }
                // Overlay: new clauses with same op_name replace base clauses
                for clause in &decl.clauses {
                    if let HandlerOp::OpHandler { op_name, .. } = &clause.operation {
                        clauses.retain(|c| match &c.operation {
                            HandlerOp::OpHandler { op_name: n, .. } => n != op_name,
                            _ => true,
                        });
                    }
                    clauses.push(clause.clone());
                }
                self.named_handlers
                    .insert(decl.name.clone(), (clauses, decl.state_bindings.clone()));
                Ok(None)
            }
            Item::Expr(expr) => {
                let val = self.eval_expr(expr)?;
                match &val {
                    Value::Unit => Ok(None),
                    _ => Ok(Some(val)),
                }
            }
        }
    }

    // ── Expression evaluation ────────────────────────────────────

    fn eval_expr(&mut self, expr: &Expr) -> EvalResult {
        match expr {
            Expr::IntLit(n, _) => Ok(Value::Int(*n)),
            Expr::FloatLit(f, _) => Ok(Value::Float(*f)),
            Expr::StringLit(s, _) => Ok(Value::String(s.clone())),
            Expr::BoolLit(b, _) => Ok(Value::Bool(*b)),

            Expr::Var(name, span) => self.eval_var(name, span),
            Expr::List(elems, _) => {
                // Elements of a list literal are never in tail position.
                self.in_tail_position = false;
                let vals: Vec<Value> = elems
                    .iter()
                    .map(|e| self.eval_expr(e))
                    .collect::<Result<_, _>>()?;
                Ok(Value::List(vals))
            }

            Expr::BinOp {
                op,
                left,
                right,
                span,
            } => self.eval_binop(*op, left, right, span),

            Expr::UnaryOp { op, operand, span } => self.eval_unaryop(*op, operand, span),

            Expr::Call { func, args, span } => self.eval_call(func, args, span),

            Expr::FieldAccess {
                object,
                field,
                span,
            } => self.eval_field_access(object, field, span),

            Expr::Index {
                object,
                index,
                span,
            } => self.eval_index(object, index, span),

            Expr::Lambda { params, body, .. } => {
                let param_names: Vec<String> = params.iter().map(|p| p.name.clone()).collect();
                Ok(Value::Function {
                    name: None,
                    params: param_names,
                    body: Arc::new(*body.clone()),
                    closure_env: self.env.capture(),
                })
            }

            Expr::Block { stmts, expr, .. } => self.eval_block(stmts, expr.as_deref()),

            Expr::If {
                condition,
                then_branch,
                else_branch,
                span,
            } => self.eval_if(condition, then_branch, else_branch.as_deref(), span),

            Expr::Match {
                scrutinee,
                arms,
                span,
            } => self.eval_match(scrutinee, arms, span),

            Expr::Let { pattern, value, .. } => {
                // Value of a let binding is never in tail position.
                self.in_tail_position = false;
                let val = self.eval_expr(value)?;
                self.bind_pattern_val(pattern, val);
                Ok(Value::Unit)
            }

            Expr::Pipe { left, right, span } => {
                // Sub-expressions of a pipe are not in tail position.
                self.in_tail_position = false;
                // a |> f(b, c) compiles to f(a, b, c) — pipe value inserted as first arg
                if let Expr::Call { func, args, .. } = right.as_ref() {
                    let pipe_val = self.eval_expr(left)?;
                    let func_val = self.eval_expr(func)?;
                    let mut all_args = vec![pipe_val];
                    for arg in args {
                        all_args.push(self.eval_expr(arg)?);
                    }
                    self.call_value(func_val, all_args, span)
                } else {
                    let arg = self.eval_expr(left)?;
                    let func = self.eval_expr(right)?;
                    self.call_value(func, vec![arg], span)
                }
            }

            Expr::StringInterp { parts, .. } => {
                let mut result = String::new();
                for part in parts {
                    match part {
                        StringPart::Literal(s) => result.push_str(s),
                        StringPart::Expr(e) => {
                            let val = self.eval_expr(e)?;
                            result.push_str(&val.display_print());
                        }
                    }
                }
                Ok(Value::String(result))
            }

            Expr::Handle {
                expr,
                handlers,
                state_bindings,
                span,
            } => self.eval_handle(expr, handlers, state_bindings, span),

            Expr::Resume {
                value,
                state_updates,
                span,
            } => {
                let val = self.eval_expr(value)?;

                // If `resume` is bound to a Continuation (multi-shot handler),
                // call it as a function so the body is re-evaluated via replay.
                // This enables `resume(a) ++ resume(b)` and `map(|x| resume(x), xs)`.
                if state_updates.is_empty() {
                    if let Some(cont @ Value::Continuation { .. }) = self.env.get("resume") {
                        return self.call_value(cont.clone(), vec![val], span);
                    }
                }

                let updates = state_updates
                    .iter()
                    .map(|su| Ok((su.name.clone(), self.eval_expr(&su.value)?)))
                    .collect::<Result<Vec<_>, Signal>>()?;

                // Signal-based resume for stateful handlers (resume(val) with state = x).
                Err(Signal::Resume {
                    value: val,
                    state_updates: updates,
                })
            }

            Expr::Perform {
                effect,
                operation,
                args,
                span,
            } => {
                let evaluated_args: Vec<Value> = args
                    .iter()
                    .map(|a| self.eval_expr(a))
                    .collect::<Result<_, _>>()?;
                Err(Signal::Perform {
                    effect: effect.clone(),
                    operation: operation.clone(),
                    args: evaluated_args,
                    span: span.clone(),
                })
            }

            Expr::Return { value, .. } => {
                let val = self.eval_expr(value)?;
                Err(Signal::Return(val))
            }

            Expr::Assert {
                condition,
                message,
                span,
            } => {
                let cond = self.eval_expr(condition)?;
                match cond {
                    Value::Bool(true) => Ok(Value::Unit),
                    Value::Bool(false) => {
                        let msg = self.eval_expr(message)?;
                        let msg_str = match msg {
                            Value::String(s) => s,
                            other => format!("{other}"),
                        };
                        // Dispatch through the Fail effect so handlers can catch it.
                        self.dispatch_effect(
                            "fail",
                            &[Value::String(format!("assertion failed: {msg_str}"))],
                            span,
                        )
                    }
                    _ => Err(self.type_err("assert condition must be Bool", span)),
                }
            }

            Expr::Tuple(elements, _span) => {
                // Tuple elements are never in tail position.
                self.in_tail_position = false;
                let mut vals = Vec::with_capacity(elements.len());
                for elem in elements {
                    vals.push(self.eval_expr(elem)?);
                }
                Ok(Value::Tuple(vals))
            }

            Expr::While {
                condition, body, ..
            } => {
                loop {
                    let cond = self.eval_expr(condition)?;
                    match cond {
                        Value::Bool(false) => break,
                        Value::Bool(true) => {}
                        _ => {
                            return Err(self
                                .type_err("while condition must be a boolean", condition.span()));
                        }
                    }
                    match self.eval_expr(body) {
                        Ok(_) => {}
                        Err(Signal::Break(v)) => return Ok(v),
                        Err(Signal::Continue) => continue,
                        Err(e) => return Err(e),
                    }
                }
                Ok(Value::Unit)
            }

            Expr::Loop { body, .. } => loop {
                match self.eval_expr(body) {
                    Ok(_) => {}
                    Err(Signal::Break(v)) => return Ok(v),
                    Err(Signal::Continue) => continue,
                    Err(e) => return Err(e),
                }
            },

            Expr::For {
                binding,
                iterable,
                body,
                ..
            } => {
                let iter_val = self.eval_expr(iterable)?;
                match iter_val {
                    Value::List(items) => {
                        for item in items {
                            let saved = self.env.clone();
                            self.env.set(binding, item);
                            let result = self.eval_expr(body);
                            self.env = saved;
                            match result {
                                Ok(_) => {}
                                Err(Signal::Break(v)) => return Ok(v),
                                Err(Signal::Continue) => continue,
                                Err(e) => return Err(e),
                            }
                        }
                        Ok(Value::Unit)
                    }
                    Value::Generator { receiver } => {
                        loop {
                            let val = match receiver.lock().unwrap().recv() {
                                Ok(Some(v)) => v,
                                _ => break,
                            };
                            let saved = self.env.clone();
                            self.env.set(binding, val);
                            let result = self.eval_expr(body);
                            self.env = saved;
                            match result {
                                Ok(_) => {}
                                Err(Signal::Break(v)) => return Ok(v),
                                Err(Signal::Continue) => continue,
                                Err(e) => return Err(e),
                            }
                        }
                        Ok(Value::Unit)
                    }
                    _ => {
                        Err(self.type_err("for loop requires a list or generator", iterable.span()))
                    }
                }
            }

            Expr::Break { value, .. } => {
                let val = match value {
                    Some(expr) => self.eval_expr(expr)?,
                    None => Value::Unit,
                };
                Err(Signal::Break(val))
            }

            Expr::Continue { .. } => Err(Signal::Continue),

            Expr::RecordConstruct {
                name,
                fields: named_fields,
                span,
            } => self.eval_record_construct(name, named_fields, span),
        }
    }

    fn eval_var(&self, name: &str, span: &Span) -> EvalResult {
        // Check environment first
        if let Some(val) = self.env.get(name) {
            return Ok(val.clone());
        }
        // Check if it's a variant constructor with fields (used as a function)
        if let Some(&arity) = self.variant_constructors.get(name) {
            if arity == 0 {
                return Ok(Value::AdtVariant {
                    name: name.to_string(),
                    fields: vec![],
                });
            }
            // Multi-field constructors are handled in Call.
            // Return a placeholder that Call will recognize.
            return Ok(Value::AdtVariant {
                name: name.to_string(),
                fields: vec![],
            });
        }
        Err(Signal::from(RuntimeError {
            kind: RuntimeErrorKind::TypeError(format!("unbound variable '{name}'")),
            span: span.clone(),
        }))
    }

    fn eval_binop(&mut self, op: BinOp, left: &Expr, right: &Expr, span: &Span) -> EvalResult {
        // Short-circuit for boolean operators.
        if op == BinOp::And {
            let l = self.eval_expr(left)?;
            return match l {
                Value::Bool(false) => Ok(Value::Bool(false)),
                Value::Bool(true) => self.eval_expr(right),
                _ => Err(self.type_err("&& requires Bool operands", span)),
            };
        }
        if op == BinOp::Or {
            let l = self.eval_expr(left)?;
            return match l {
                Value::Bool(true) => Ok(Value::Bool(true)),
                Value::Bool(false) => self.eval_expr(right),
                _ => Err(self.type_err("|| requires Bool operands", span)),
            };
        }

        // Operands of binary expressions are never in tail position.
        self.in_tail_position = false;
        let l = self.eval_expr(left)?;
        let r = self.eval_expr(right)?;

        match op {
            BinOp::Add => self.numeric_op(&l, &r, |a, b| a + b, |a, b| a + b, span),
            BinOp::Sub => self.numeric_op(&l, &r, |a, b| a - b, |a, b| a - b, span),
            BinOp::Mul => self.numeric_op(&l, &r, |a, b| a * b, |a, b| a * b, span),
            BinOp::Div => {
                // Check division by zero.
                match (&l, &r) {
                    (Value::Int(_), Value::Int(0)) => {
                        return Err(Signal::from(RuntimeError {
                            kind: RuntimeErrorKind::DivisionByZero,
                            span: span.clone(),
                        }));
                    }
                    (Value::Float(_), Value::Float(d)) if *d == 0.0 => {
                        return Err(Signal::from(RuntimeError {
                            kind: RuntimeErrorKind::DivisionByZero,
                            span: span.clone(),
                        }));
                    }
                    _ => {}
                }
                self.numeric_op(&l, &r, |a, b| a / b, |a, b| a / b, span)
            }
            BinOp::Mod => {
                if let (Value::Int(_), Value::Int(0)) = (&l, &r) {
                    return Err(Signal::from(RuntimeError {
                        kind: RuntimeErrorKind::DivisionByZero,
                        span: span.clone(),
                    }));
                }
                self.numeric_op(&l, &r, |a, b| a % b, |a, b| a % b, span)
            }

            BinOp::Eq => Ok(Value::Bool(l == r)),
            BinOp::Neq => Ok(Value::Bool(l != r)),

            BinOp::Lt => self.compare_op(&l, &r, |ord| ord.is_lt(), span),
            BinOp::LtEq => self.compare_op(&l, &r, |ord| ord.is_le(), span),
            BinOp::Gt => self.compare_op(&l, &r, |ord| ord.is_gt(), span),
            BinOp::GtEq => self.compare_op(&l, &r, |ord| ord.is_ge(), span),

            BinOp::Concat => match (l, r) {
                (Value::String(a), Value::String(b)) => Ok(Value::String(a + &b)),
                (Value::List(mut a), Value::List(b)) => {
                    a.extend(b);
                    Ok(Value::List(a))
                }
                _ => Err(self.type_err("++ requires String or List operands", span)),
            },

            BinOp::And | BinOp::Or => unreachable!("handled above"),
        }
    }

    fn numeric_op(
        &self,
        l: &Value,
        r: &Value,
        int_op: impl FnOnce(i64, i64) -> i64,
        float_op: impl FnOnce(f64, f64) -> f64,
        span: &Span,
    ) -> EvalResult {
        match (l, r) {
            (Value::Int(a), Value::Int(b)) => Ok(Value::Int(int_op(*a, *b))),
            (Value::Float(a), Value::Float(b)) => Ok(Value::Float(float_op(*a, *b))),
            (Value::Int(a), Value::Float(b)) => Ok(Value::Float(float_op(*a as f64, *b))),
            (Value::Float(a), Value::Int(b)) => Ok(Value::Float(float_op(*a, *b as f64))),
            _ => Err(self.type_err("arithmetic requires numeric operands", span)),
        }
    }

    fn compare_op(
        &self,
        l: &Value,
        r: &Value,
        pred: impl FnOnce(std::cmp::Ordering) -> bool,
        span: &Span,
    ) -> EvalResult {
        let ord = match (l, r) {
            (Value::Int(a), Value::Int(b)) => a.cmp(b),
            (Value::Float(a), Value::Float(b)) => {
                a.partial_cmp(b).unwrap_or(std::cmp::Ordering::Equal)
            }
            (Value::String(a), Value::String(b)) => a.cmp(b),
            _ => return Err(self.type_err("comparison requires same-type operands", span)),
        };
        Ok(Value::Bool(pred(ord)))
    }

    fn eval_unaryop(&mut self, op: UnaryOp, operand: &Expr, span: &Span) -> EvalResult {
        // Operand of a unary expression is never in tail position.
        self.in_tail_position = false;
        let val = self.eval_expr(operand)?;
        match (op, &val) {
            (UnaryOp::Neg, Value::Int(n)) => Ok(Value::Int(-n)),
            (UnaryOp::Neg, Value::Float(f)) => Ok(Value::Float(-f)),
            (UnaryOp::Not, Value::Bool(b)) => Ok(Value::Bool(!b)),
            _ => Err(self.type_err("invalid unary operand type", span)),
        }
    }

    fn eval_call(&mut self, func_expr: &Expr, args: &[Expr], span: &Span) -> EvalResult {
        // Check if calling an effect operation by name.
        if let Expr::Var(name, _) = func_expr {
            if let Some((_effect_name, _)) = self.effect_ops.get(name).cloned() {
                let evaluated_args: Vec<Value> = args
                    .iter()
                    .map(|a| self.eval_expr(a))
                    .collect::<Result<_, _>>()?;
                return self.dispatch_effect(name, &evaluated_args, span);
            }
            // Check variant constructors with arity > 0 that aren't in env.
            if self.env.get(name).is_none()
                && self.variant_constructors.get(name).is_some_and(|&a| a > 0)
            {
                let evaluated_args: Vec<Value> = args
                    .iter()
                    .map(|a| self.eval_expr(a))
                    .collect::<Result<_, _>>()?;
                return Ok(Value::AdtVariant {
                    name: name.clone(),
                    fields: evaluated_args,
                });
            }
        }

        // Method call: `obj.method(args)` dispatched via impl table
        if let Expr::FieldAccess { object, field, .. } = func_expr {
            let obj_val = self.eval_expr(object)?;
            let type_name = value_type_name(&obj_val).to_string();
            if let Some(method_fn) = self.impl_methods.get(&(type_name, field.clone())).cloned() {
                let mut evaluated_args: Vec<Value> = args
                    .iter()
                    .map(|a| self.eval_expr(a))
                    .collect::<Result<_, _>>()?;
                // Prepend self as first argument
                evaluated_args.insert(0, obj_val);
                return self.call_value(method_fn, evaluated_args, span);
            }
            // Fall through to normal field access eval if not in impl table
            // (e.g. list.len, string.is_empty)
        }

        // Arguments are not in tail position — clear tail flag during their evaluation.
        let was_tail = std::mem::replace(&mut self.in_tail_position, false);
        let func = self.eval_expr(func_expr)?;
        let evaluated_args: Vec<Value> = args
            .iter()
            .map(|a| self.eval_expr(a))
            .collect::<Result<_, _>>()?;
        self.in_tail_position = was_tail;

        // Tail call optimization: if we're in tail position and calling the
        // same named function that's currently executing, emit TailCall so
        // the trampoline in call_value can reuse the frame.
        if self.in_tail_position {
            if let Value::Function {
                name: Some(ref fn_name),
                ..
            } = func
            {
                if self.current_fn_name.as_ref() == Some(fn_name) {
                    return Err(Signal::TailCall {
                        func,
                        args: evaluated_args,
                    });
                }
            }
        }

        self.call_value(func, evaluated_args, span)
    }

    fn call_value(&mut self, mut func: Value, mut args: Vec<Value>, span: &Span) -> EvalResult {
        // Intercept `next` and `generate` before normal dispatch: these builtins
        // need access to interpreter state (channels / cloning) that plain fn
        // pointers cannot carry.
        if let Value::BuiltinFn { ref name, .. } = func {
            if name == "next" {
                return self.builtin_next(args, span);
            }
            if name == "generate" {
                return self.builtin_generate(args, span);
            }
            if name == "find" {
                return self.builtin_find(args, span);
            }
            if name == "resume" {
                // Stateful handler resume — emit Signal::Resume
                let val = args.into_iter().next().unwrap_or(Value::Unit);
                return Err(Signal::Resume {
                    value: val,
                    state_updates: vec![],
                });
            }
        }

        self.call_depth += 1;
        if self.call_depth > MAX_CALL_DEPTH {
            self.call_depth -= 1;
            return Err(Signal::from(RuntimeError {
                kind: RuntimeErrorKind::StackOverflow,
                span: span.clone(),
            }));
        }

        // Save caller's TCO state so we can restore on return.
        let saved_fn_name = self.current_fn_name.take();
        let saved_tail = self.in_tail_position;

        let result = 'trampoline: loop {
            match func {
                Value::Function {
                    name: ref fn_name,
                    ref params,
                    ref body,
                    ref closure_env,
                } => {
                    let mut call_env = Environment::with_arc_parent(closure_env.clone());
                    // Self-bind for recursion: named functions can call themselves
                    if let Some(name) = fn_name {
                        call_env.set(
                            name,
                            Value::Function {
                                name: fn_name.clone(),
                                params: params.clone(),
                                body: body.clone(),
                                closure_env: Arc::new(call_env.clone()),
                            },
                        );
                    }
                    for (param, arg) in params.iter().zip(args.iter()) {
                        call_env.set(param, arg.clone());
                    }

                    // Set up tail call detection state.
                    self.current_fn_name = fn_name.clone();
                    self.in_tail_position = true;

                    let saved_env = std::mem::replace(&mut self.env, call_env);
                    let mut result = self.eval_expr(body);

                    // Inner trampoline: for self-recursive tail calls, rebind params
                    // in the existing call_env instead of allocating a new one.
                    // This avoids repeated environment cloning for deep recursion.
                    while let Err(Signal::TailCall {
                        func: next_func,
                        args: next_args,
                    }) = result
                    {
                        // Only reuse env for same-function self-recursion.
                        if let Value::Function {
                            name: ref nf_name,
                            params: ref nf_params,
                            body: ref nf_body,
                            ..
                        } = next_func
                        {
                            if nf_name == fn_name {
                                // Rebind params in place — no new env allocation.
                                for (param, arg) in nf_params.iter().zip(next_args.iter()) {
                                    self.env.set(param, arg.clone());
                                }
                                self.in_tail_position = true;
                                result = self.eval_expr(nf_body);
                                continue;
                            }
                        }
                        // Different function: exit inner loop and let outer loop handle it.
                        func = next_func;
                        args = next_args;
                        self.env = saved_env;
                        self.in_tail_position = true;
                        continue 'trampoline;
                    }

                    self.env = saved_env;

                    // Catch Return signals at function boundary.
                    match result {
                        Err(Signal::Return(v)) => break 'trampoline Ok(v),
                        other => break 'trampoline other,
                    }
                }
                Value::BuiltinFn { func: f, .. } => {
                    break 'trampoline f(args).map_err(Signal::from);
                }
                Value::AdtVariant { name, fields } if fields.is_empty() => {
                    // Variant constructor being called with args.
                    break 'trampoline Ok(Value::AdtVariant { name, fields: args });
                }
                Value::Continuation {
                    body,
                    handler_clauses,
                    state_bindings,
                    initial_state,
                    replay_log: mut log,
                    env: cont_env,
                    handler_stack_snapshot,
                } => {
                    // Calling a continuation: extend replay log and re-evaluate body.
                    let resume_value = args.into_iter().next().unwrap_or(Value::Unit);
                    // Collect state updates from the Resume signal if present
                    // (for `resume(val) with state = x` syntax)
                    let state_updates = Vec::new();
                    log.push(ReplayEntry {
                        resume_value,
                        state_updates,
                    });

                    // Save and restore interpreter state around re-evaluation
                    let saved_handler_stack =
                        std::mem::replace(&mut self.handler_stack, handler_stack_snapshot);
                    let saved_env =
                        std::mem::replace(&mut self.env, Environment::with_arc_parent(cont_env));

                    let result = self.eval_handle_body(
                        &body,
                        &handler_clauses,
                        &state_bindings,
                        &initial_state,
                        &log,
                    );

                    self.handler_stack = saved_handler_stack;
                    self.env = saved_env;

                    break 'trampoline result;
                }
                _ => {
                    break 'trampoline Err(
                        self.type_err(&format!("cannot call value: {func}"), span)
                    );
                }
            }
        };

        // Restore caller's TCO state.
        self.current_fn_name = saved_fn_name;
        self.in_tail_position = saved_tail;

        self.call_depth -= 1;
        result
    }

    fn eval_field_access(&mut self, object: &Expr, field: &str, span: &Span) -> EvalResult {
        let obj = self.eval_expr(object)?;
        match (&obj, field) {
            (Value::List(vs), "len") => Ok(Value::Int(vs.len() as i64)),
            (Value::List(vs), "is_empty") => Ok(Value::Bool(vs.is_empty())),
            (Value::String(s), "len") => Ok(Value::Int(s.len() as i64)),
            (Value::String(s), "is_empty") => Ok(Value::Bool(s.is_empty())),
            (Value::AdtVariant { name, fields }, _) => {
                // Look up variant definition to resolve field name → index
                if let Some(field_names) = self.variant_field_names.get(name) {
                    if let Some(idx) = field_names.iter().position(|n| n == field) {
                        if idx < fields.len() {
                            return Ok(fields[idx].clone());
                        }
                    }
                }
                Err(self.type_err(&format!("no field '{field}' on {name}"), span))
            }
            _ => Err(self.type_err(&format!("no field '{field}' on {obj}"), span)),
        }
    }

    /// Evaluate `Name { field: expr, ... }` — record construction.
    fn eval_record_construct(
        &mut self,
        variant_name: &str,
        named_fields: &[(String, Expr)],
        span: &Span,
    ) -> EvalResult {
        // Evaluate all field values
        let mut field_map: Vec<(String, Value)> = Vec::new();
        for (name, expr) in named_fields {
            let val = self.eval_expr(expr)?;
            field_map.push((name.clone(), val));
        }

        // Look up the variant's field order from the declaration
        if let Some(field_names) = self.variant_field_names.get(variant_name) {
            // Reorder values to match declaration order
            let mut positional = Vec::with_capacity(field_names.len());
            for decl_name in field_names {
                let val = field_map
                    .iter()
                    .find(|(n, _)| n == decl_name)
                    .map(|(_, v)| v.clone())
                    .ok_or_else(|| {
                        self.type_err(
                            &format!("missing field '{decl_name}' in {variant_name} {{ ... }}"),
                            span,
                        )
                    })?;
                positional.push(val);
            }
            Ok(Value::AdtVariant {
                name: variant_name.to_string(),
                fields: positional,
            })
        } else {
            // No field names registered — treat values in source order
            let fields: Vec<Value> = field_map.into_iter().map(|(_, v)| v).collect();
            Ok(Value::AdtVariant {
                name: variant_name.to_string(),
                fields,
            })
        }
    }

    fn eval_index(&mut self, object: &Expr, index: &Expr, span: &Span) -> EvalResult {
        // Index expressions are never in tail position.
        self.in_tail_position = false;
        let obj = self.eval_expr(object)?;
        let idx = self.eval_expr(index)?;
        match (&obj, &idx) {
            (Value::List(vs), Value::Int(i)) => {
                let i = *i;
                if i < 0 || i as usize >= vs.len() {
                    Err(Signal::from(RuntimeError {
                        kind: RuntimeErrorKind::IndexOutOfBounds {
                            index: i,
                            length: vs.len(),
                        },
                        span: span.clone(),
                    }))
                } else {
                    Ok(vs[i as usize].clone())
                }
            }
            _ => Err(self.type_err("indexing requires a list and integer", span)),
        }
    }

    // ── Generator builtins ───────────────────────────────────────

    /// `next(gen)` — advance the generator and return the next value.
    ///
    /// Returns `Some(val)` for each yielded value, or `None` when exhausted.
    /// Blocks until the generator yields or finishes. The rendezvous channel
    /// (capacity 0) means the generator is paused between yields, so this
    /// never busy-waits.
    fn builtin_next(&mut self, args: Vec<Value>, span: &Span) -> EvalResult {
        match args.into_iter().next() {
            Some(Value::Generator { receiver }) => match receiver.lock().unwrap().recv() {
                Ok(Some(val)) => Ok(Value::AdtVariant {
                    name: "Some".into(),
                    fields: vec![val],
                }),
                Ok(None) | Err(_) => Ok(Value::AdtVariant {
                    name: "None".into(),
                    fields: vec![],
                }),
            },
            _ => Err(self.type_err("next: argument must be a generator", span)),
        }
    }

    /// `generate(func)` — create a generator from a zero-argument function.
    ///
    /// Spawns a thread that runs `func()`. Inside `func`, `yield(val)` sends
    /// values to the caller one at a time. The rendezvous channel (capacity 0)
    /// means the generator thread pauses after each yield until `next()`
    /// receives the value, providing natural backpressure.
    fn builtin_generate(&mut self, args: Vec<Value>, span: &Span) -> EvalResult {
        let func = match args.into_iter().next() {
            Some(f @ Value::Function { .. }) => f,
            _ => return Err(self.type_err("generate: argument must be a function", span)),
        };

        // Rendezvous channel (capacity 0): generator blocks after each send
        // until `next()` receives, naturally pausing between yields.
        let (value_tx, value_rx) = std::sync::mpsc::sync_channel::<Option<Value>>(0);

        // Build a minimal interpreter for the generator thread.
        let mut gen_interp = Interpreter {
            env: self.env.clone_flat(),
            handler_stack: self.handler_stack.clone(),
            variant_constructors: self.variant_constructors.clone(),
            effect_ops: self.effect_ops.clone(),
            variant_field_names: self.variant_field_names.clone(),
            call_depth: 0,
            current_fn_name: None,
            in_tail_position: false,
            named_handlers: self.named_handlers.clone(),
            generator_sender: Some(value_tx.clone()),
            impl_methods: self.impl_methods.clone(),
            replay_log: None,
            replay_pos: 0,
            continuation_context: None,
        };

        std::thread::spawn(move || {
            let _ = gen_interp.call_value(func, vec![], &Span::dummy());
            // Signal exhaustion after the function returns.
            let _ = value_tx.send(None);
        });

        Ok(Value::Generator {
            receiver: Arc::new(Mutex::new(value_rx)),
        })
    }

    /// `find(list, fn)` — return first element where fn returns true, or None.
    fn builtin_find(&mut self, args: Vec<Value>, span: &Span) -> EvalResult {
        let mut args_iter = args.into_iter();
        let list = args_iter
            .next()
            .ok_or_else(|| self.type_err("find expects 2 arguments", span))?;
        let func = args_iter
            .next()
            .ok_or_else(|| self.type_err("find expects 2 arguments", span))?;
        match list {
            Value::List(items) => {
                for item in items {
                    let result = self.call_value(func.clone(), vec![item.clone()], span)?;
                    if result == Value::Bool(true) {
                        return Ok(Value::AdtVariant {
                            name: "Some".into(),
                            fields: vec![item],
                        });
                    }
                }
                Ok(Value::AdtVariant {
                    name: "None".into(),
                    fields: vec![],
                })
            }
            _ => Err(self.type_err("find expects a list as first argument", span)),
        }
    }

    fn eval_block(&mut self, stmts: &[Stmt], tail: Option<&Expr>) -> EvalResult {
        let saved_env = self.env.clone();
        let result = self.eval_block_inner(stmts, tail);
        self.env = saved_env;
        result
    }

    fn eval_block_inner(&mut self, stmts: &[Stmt], tail: Option<&Expr>) -> EvalResult {
        // Statements are not in tail position — only the final expression is.
        let was_tail = std::mem::replace(&mut self.in_tail_position, false);
        for stmt in stmts {
            match stmt {
                Stmt::Let(decl) => {
                    let val = self.eval_expr(&decl.value)?;
                    self.bind_pattern_val(&decl.pattern, val);
                }
                Stmt::Expr(expr) => {
                    self.eval_expr(expr)?;
                }
                Stmt::FnDecl(decl) => {
                    let params: Vec<String> = decl.params.iter().map(|p| p.name.clone()).collect();
                    let val = Value::Function {
                        name: Some(decl.name.clone()),
                        params,
                        body: Arc::new(decl.body.clone()),
                        closure_env: self.env.capture(),
                    };
                    self.env.set(&decl.name, val);
                }
            }
        }
        // Restore tail position for the final expression.
        self.in_tail_position = was_tail;
        match tail {
            Some(expr) => self.eval_expr(expr),
            None => Ok(Value::Unit),
        }
    }

    fn eval_if(
        &mut self,
        condition: &Expr,
        then_branch: &Expr,
        else_branch: Option<&Expr>,
        span: &Span,
    ) -> EvalResult {
        // Condition is not in tail position; branches inherit the outer tail position.
        let was_tail = std::mem::replace(&mut self.in_tail_position, false);
        let cond = self.eval_expr(condition)?;
        self.in_tail_position = was_tail;
        match cond {
            Value::Bool(true) => self.eval_expr(then_branch),
            Value::Bool(false) => match else_branch {
                Some(e) => self.eval_expr(e),
                None => Ok(Value::Unit),
            },
            _ => Err(self.type_err("if condition must be Bool", span)),
        }
    }

    // ── Pattern matching ─────────────────────────────────────────

    fn eval_match(&mut self, scrutinee: &Expr, arms: &[MatchArm], span: &Span) -> EvalResult {
        // Scrutinee is not in tail position; arm bodies inherit the outer tail position.
        let was_tail = std::mem::replace(&mut self.in_tail_position, false);
        let val = self.eval_expr(scrutinee)?;

        for arm in arms {
            let mut bindings = HashMap::new();
            if self.match_pattern(&arm.pattern, &val, &mut bindings) {
                // Check guard if present — guards are not in tail position.
                if let Some(guard) = &arm.guard {
                    let saved = self.env.clone();
                    for (k, v) in &bindings {
                        self.env.set(k, v.clone());
                    }
                    let guard_result = self.eval_expr(guard);
                    self.env = saved;
                    match guard_result? {
                        Value::Bool(true) => {}
                        Value::Bool(false) => continue,
                        _ => return Err(self.type_err("match guard must be Bool", span)),
                    }
                }
                // Bind pattern variables and evaluate body in tail position.
                self.in_tail_position = was_tail;
                let saved = self.env.clone();
                for (k, v) in bindings {
                    self.env.set(&k, v);
                }
                let result = self.eval_expr(&arm.body);
                self.env = saved;
                return result;
            }
        }
        Err(Signal::from(RuntimeError {
            kind: RuntimeErrorKind::MatchFailed,
            span: span.clone(),
        }))
    }

    fn match_pattern(
        &self,
        pattern: &Pattern,
        value: &Value,
        bindings: &mut HashMap<String, Value>,
    ) -> bool {
        crate::patterns::match_pattern(pattern, value, bindings)
    }

    /// Bind variables from a pattern to values in the current environment.
    fn bind_pattern_val(&mut self, pattern: &Pattern, value: Value) {
        let mut bindings = HashMap::new();
        crate::patterns::match_pattern(pattern, &value, &mut bindings);
        for (k, v) in bindings {
            self.env.set(&k, v);
        }
    }

    // ── Effect handling ──────────────────────────────────────────

    fn eval_handle(
        &mut self,
        body: &Expr,
        handler_clauses: &[ast::HandlerClause],
        state_bindings: &[ast::StateBinding],
        _span: &Span,
    ) -> EvalResult {
        // Evaluate state binding init expressions
        let mut initial_state = HashMap::new();
        for binding in state_bindings {
            let val = self.eval_expr(&binding.init)?;
            initial_state.insert(binding.name.clone(), val);
        }

        // Merge state from named handlers (UseHandler references)
        for clause in handler_clauses {
            if let HandlerOp::UseHandler { name } = &clause.operation {
                if let Some((_, named_state_bindings)) = self.named_handlers.get(name).cloned() {
                    for binding in &named_state_bindings {
                        if !initial_state.contains_key(&binding.name) {
                            let val = self.eval_expr(&binding.init)?;
                            initial_state.insert(binding.name.clone(), val);
                        }
                    }
                }
            }
        }

        self.eval_handle_body(body, handler_clauses, state_bindings, &initial_state, &[])
    }

    /// Evaluate a handle body with replay support for multi-shot continuations.
    ///
    /// When `replay_log` is non-empty, effect operations consume from the log
    /// instead of dispatching to handlers. When the log is exhausted, the next
    /// effect dispatches normally and builds a new Continuation.
    fn eval_handle_body(
        &mut self,
        body: &Expr,
        handler_clauses: &[ast::HandlerClause],
        state_bindings: &[ast::StateBinding],
        initial_state: &HashMap<String, Value>,
        replay_log: &[ReplayEntry],
    ) -> EvalResult {
        // Build handler frame from clauses — two-pass for handler composition.
        let mut handlers = HashMap::new();

        // First pass: expand UseHandler references (base clauses)
        for clause in handler_clauses {
            if let HandlerOp::UseHandler { name } = &clause.operation {
                if let Some((named_clauses, _)) = self.named_handlers.get(name).cloned() {
                    for nc in &named_clauses {
                        if let HandlerOp::OpHandler {
                            op_name,
                            params,
                            body,
                            ..
                        } = &nc.operation
                        {
                            handlers.insert(
                                op_name.clone(),
                                EffectHandler {
                                    params: params.clone(),
                                    body: body.clone(),
                                    env: self.env.clone_flat(),
                                },
                            );
                        }
                    }
                }
            }
        }
        // Second pass: inline OpHandler clauses override base
        for clause in handler_clauses {
            if let HandlerOp::OpHandler {
                op_name,
                params,
                body,
                ..
            } = &clause.operation
            {
                handlers.insert(
                    op_name.clone(),
                    EffectHandler {
                        params: params.clone(),
                        body: body.clone(),
                        env: self.env.clone_flat(),
                    },
                );
            }
        }

        let frame = HandlerFrame {
            handlers,
            state: initial_state.clone(),
        };
        self.handler_stack.push(frame);

        // Set up replay state
        let saved_replay = self.replay_log.take();
        let saved_replay_pos = self.replay_pos;
        self.replay_log = if !replay_log.is_empty() {
            Some(replay_log.to_vec())
        } else {
            None
        };
        self.replay_pos = 0;

        // Store context needed by dispatch_effect to build continuations
        let saved_ctx = self.continuation_context.take();
        self.continuation_context = Some(ContinuationContext {
            body: Arc::new(body.clone()),
            handler_clauses: Arc::new(handler_clauses.to_vec()),
            state_bindings: Arc::new(state_bindings.to_vec()),
            initial_state: initial_state.clone(),
            env: self.env.capture(),
        });

        let result = self.eval_expr(body);

        // Capture final handler state before popping (declaration order)
        let final_state: Vec<Value> = if !state_bindings.is_empty() {
            state_bindings
                .iter()
                .map(|b| {
                    self.handler_stack
                        .last()
                        .and_then(|f| f.state.get(&b.name).cloned())
                        .unwrap_or(Value::Unit)
                })
                .collect()
        } else {
            vec![]
        };

        // Restore state
        self.replay_log = saved_replay;
        self.replay_pos = saved_replay_pos;
        self.continuation_context = saved_ctx;
        self.handler_stack.pop();

        match result {
            Ok(val) | Err(Signal::HandleDone(val)) => {
                if final_state.is_empty() {
                    Ok(val)
                } else {
                    let mut elts = vec![val];
                    elts.extend(final_state);
                    Ok(Value::Tuple(elts))
                }
            }
            Err(other) => Err(other),
        }
    }

    /// Dispatch an effect operation to the nearest handler.
    ///
    /// In replay mode, returns the logged value. Otherwise, builds a
    /// `Value::Continuation` and binds it as `resume` in the handler body.
    fn dispatch_effect(&mut self, op_name: &str, args: &[Value], span: &Span) -> EvalResult {
        // Native yield interception for generator threads.
        if op_name == "yield" {
            if let Some(ref value_tx) = self.generator_sender {
                let val = args.first().cloned().unwrap_or(Value::Unit);
                match value_tx.send(Some(val)) {
                    Ok(()) => return Ok(Value::Unit),
                    Err(_) => return Err(Signal::Break(Value::Unit)),
                }
            }
        }

        // Replay mode: consume from log if available
        if let Some(ref log) = self.replay_log {
            if self.replay_pos < log.len() {
                let entry = log[self.replay_pos].clone();
                self.replay_pos += 1;
                // Apply state updates to the current handler frame
                if let Some(frame) = self.handler_stack.last_mut() {
                    for (name, val) in &entry.state_updates {
                        frame.state.insert(name.clone(), val.clone());
                    }
                }
                return Ok(entry.resume_value);
            }
        }

        // Normal dispatch: search handler stack for a matching handler.
        let found = self
            .handler_stack
            .iter()
            .enumerate()
            .rev()
            .find_map(|(idx, frame)| frame.handlers.get(op_name).map(|h| (idx, h.clone())));

        if let Some((frame_idx, handler)) = found {
            // Build a Continuation value from the replay log so far
            let replay_log_so_far: Vec<ReplayEntry> = self
                .replay_log
                .as_ref()
                .map(|log| log[..self.replay_pos].to_vec())
                .unwrap_or_default();

            let continuation = if let Some(ref ctx) = self.continuation_context {
                Value::Continuation {
                    body: ctx.body.clone(),
                    handler_clauses: ctx.handler_clauses.clone(),
                    state_bindings: ctx.state_bindings.clone(),
                    initial_state: ctx.initial_state.clone(),
                    replay_log: replay_log_so_far,
                    env: ctx.env.clone(),
                    handler_stack_snapshot: self.handler_stack
                        [..self.handler_stack.len().saturating_sub(1)]
                        .to_vec(),
                }
            } else {
                // No continuation context — use old signal-based resume (generators, etc.)
                let mut handler_env = Environment::with_parent(handler.env.clone());
                for (param, arg) in handler.params.iter().zip(args.iter()) {
                    handler_env.set(param, arg.clone());
                }
                for (name, val) in &self.handler_stack[frame_idx].state {
                    handler_env.set(name, val.clone());
                }

                let saved_env = std::mem::replace(&mut self.env, handler_env);
                let result = self.eval_expr(&handler.body);
                self.env = saved_env;

                return match result {
                    Err(Signal::Resume {
                        value,
                        state_updates,
                    }) => {
                        for (name, val) in state_updates {
                            self.handler_stack[frame_idx].state.insert(name, val);
                        }
                        Ok(value)
                    }
                    Ok(val) => Err(Signal::HandleDone(val)),
                    Err(other) => Err(other),
                };
            };

            // Set up handler environment with params + state + resume as continuation
            let mut handler_env = Environment::with_parent(handler.env.clone());
            for (param, arg) in handler.params.iter().zip(args.iter()) {
                handler_env.set(param, arg.clone());
            }
            for (name, val) in &self.handler_stack[frame_idx].state {
                handler_env.set(name, val.clone());
            }
            // For stateless handlers: bind resume as a Continuation (multi-shot capable).
            // For stateful handlers: bind resume as a simple function that emits
            // Signal::Resume (state evolves and can't be replayed correctly).
            // Note: tail-resumptive optimization is VM-only. The interpreter's
            // continuation-based replay log accumulates through continuation chaining,
            // so skipping continuations would break replay for later handlers.
            if self.handler_stack[frame_idx].state.is_empty() {
                handler_env.set("resume", continuation);
            } else {
                // Stateful/tail-resumptive handlers: bind resume as a builtin placeholder.
                // The actual Signal::Resume is emitted in call_value's "resume" intercept.
                handler_env.set(
                    "resume",
                    Value::BuiltinFn {
                        name: "resume".to_string(),
                        func: |_| Ok(Value::Unit), // placeholder; intercepted in call_value
                    },
                );
            }

            let saved_env = std::mem::replace(&mut self.env, handler_env);
            // Save and clear continuation context during handler body eval
            let saved_ctx = self.continuation_context.take();
            let saved_replay = self.replay_log.take();
            let saved_replay_pos = self.replay_pos;

            let result = self.eval_expr(&handler.body);

            self.continuation_context = saved_ctx;
            self.replay_log = saved_replay;
            self.replay_pos = saved_replay_pos;
            self.env = saved_env;

            match result {
                // Old signal-based resume (backward compat for `resume(val) with state = x`)
                Err(Signal::Resume {
                    value,
                    state_updates,
                }) => {
                    for (name, val) in state_updates {
                        self.handler_stack[frame_idx].state.insert(name, val);
                    }
                    Ok(value)
                }
                // Handler returned a value — this becomes the handle expr's result
                Ok(val) => Err(Signal::HandleDone(val)),
                Err(other) => Err(other),
            }
        } else {
            Err(Signal::from(RuntimeError {
                kind: RuntimeErrorKind::UnhandledEffect {
                    effect: String::new(),
                    operation: op_name.to_string(),
                },
                span: span.clone(),
            }))
        }
    }

    // ── Helpers ──────────────────────────────────────────────────

    fn type_err(&self, msg: &str, span: &Span) -> Signal {
        Signal::from(RuntimeError {
            kind: RuntimeErrorKind::TypeError(msg.to_string()),
            span: span.clone(),
        })
    }
}

impl Default for Interpreter {
    fn default() -> Self {
        Self::new()
    }
}

// ── Public execute function ──────────────────────────────────────

/// Execute a parsed program and return the last expression's value.
pub fn execute(program: &Program) -> Result<Option<Value>, LuxError> {
    let mut interp = Interpreter::new();
    interp.eval_line(program)
}
