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
    self, BinOp, Expr, HandlerOp, ImplBlock, Item, LitPattern, MatchArm, Pattern, Program, Stmt,
    StringPart, UnaryOp,
};
use crate::env::Environment;
use crate::error::{LuxError, RuntimeError, RuntimeErrorKind};
use crate::token::Span;

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
    /// `resume(val)` inside a handler body.
    Resume(Value),
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
struct EffectHandler {
    params: Vec<String>,
    body: Expr,
    env: Environment,
}

#[derive(Debug, Clone)]
struct HandlerFrame {
    handlers: HashMap<String, EffectHandler>,
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
    call_depth: usize,
    /// Name of the function currently executing, used for tail call detection.
    current_fn_name: Option<String>,
    /// Whether the current evaluation position is in tail position of the
    /// enclosing function. Set to `true` before evaluating a function body
    /// and selectively propagated through blocks, if, and match branches.
    in_tail_position: bool,
    /// When running inside a generator thread, holds the sender used to
    /// deliver yielded values to `next()` callers.
    ///
    /// The channel is a rendezvous (capacity 0): `send` blocks until the
    /// receiver calls `recv`, naturally pausing the generator between yields.
    generator_sender: Option<std::sync::mpsc::SyncSender<Option<Value>>>,
    /// Method dispatch table: (type_name, method_name) -> function value
    impl_methods: HashMap<(String, String), Value>,
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
            call_depth: 0,
            current_fn_name: None,
            in_tail_position: false,
            generator_sender: None,
            impl_methods: HashMap::new(),
        };
        interp.register_builtins();
        interp.register_builtin_variants();
        interp.register_builtin_effects();
        interp
    }

    fn register_builtins(&mut self) {
        self.register_builtin("print", |args| {
            if let Some(v) = args.first() {
                print!("{}", v.display_print());
            }
            Ok(Value::Unit)
        });
        self.register_builtin("println", |args| {
            if let Some(v) = args.first() {
                println!("{}", v.display_print());
            } else {
                println!();
            }
            Ok(Value::Unit)
        });
        self.register_builtin("len", |args| match args.first() {
            Some(Value::List(vs)) => Ok(Value::Int(vs.len() as i64)),
            Some(Value::String(s)) => Ok(Value::Int(s.len() as i64)),
            _ => Err(RuntimeError {
                kind: RuntimeErrorKind::TypeError("len expects a list or string".into()),
                span: Span::dummy(),
            }),
        });
        self.register_builtin("is_empty", |args| match args.first() {
            Some(Value::List(vs)) => Ok(Value::Bool(vs.is_empty())),
            Some(Value::String(s)) => Ok(Value::Bool(s.is_empty())),
            _ => Err(RuntimeError {
                kind: RuntimeErrorKind::TypeError("is_empty expects a list or string".into()),
                span: Span::dummy(),
            }),
        });
        self.register_builtin("push", |args| {
            if args.len() != 2 {
                return Err(RuntimeError {
                    kind: RuntimeErrorKind::TypeError("push expects 2 arguments".into()),
                    span: Span::dummy(),
                });
            }
            let mut args = args;
            let val = args.remove(1);
            match args.into_iter().next() {
                Some(Value::List(mut vs)) => {
                    vs.push(val);
                    Ok(Value::List(vs))
                }
                _ => Err(RuntimeError {
                    kind: RuntimeErrorKind::TypeError(
                        "push expects a list as first argument".into(),
                    ),
                    span: Span::dummy(),
                }),
            }
        });
        self.register_builtin("to_string", |args| match args.first() {
            Some(v) => Ok(Value::String(v.display_print())),
            None => Ok(Value::String(String::new())),
        });
        self.register_builtin("parse_int", |args| match args.first() {
            Some(Value::String(s)) => match s.parse::<i64>() {
                Ok(n) => Ok(Value::Int(n)),
                Err(_) => Err(RuntimeError {
                    kind: RuntimeErrorKind::TypeError(format!("cannot parse '{s}' as Int")),
                    span: Span::dummy(),
                }),
            },
            _ => Err(RuntimeError {
                kind: RuntimeErrorKind::TypeError("parse_int expects a string".into()),
                span: Span::dummy(),
            }),
        });
        self.register_builtin("range", |args| match (args.first(), args.get(1)) {
            (Some(Value::Int(start)), Some(Value::Int(end))) => {
                let start = *start;
                let end = *end;
                let items = (start..end).map(Value::Int).collect();
                Ok(Value::List(items))
            }
            _ => Err(RuntimeError {
                kind: RuntimeErrorKind::TypeError(
                    "range expects two Int arguments: range(start, end)".into(),
                ),
                span: Span::dummy(),
            }),
        });
        // String builtins
        self.register_builtin("split", |args| match (args.first(), args.get(1)) {
            (Some(Value::String(s)), Some(Value::String(sep))) => {
                let parts: Vec<Value> = s
                    .split(sep.as_str())
                    .map(|p| Value::String(p.to_string()))
                    .collect();
                Ok(Value::List(parts))
            }
            _ => Err(RuntimeError {
                kind: RuntimeErrorKind::TypeError("split expects two strings".into()),
                span: Span::dummy(),
            }),
        });
        self.register_builtin("trim", |args| match args.first() {
            Some(Value::String(s)) => Ok(Value::String(s.trim().to_string())),
            _ => Err(RuntimeError {
                kind: RuntimeErrorKind::TypeError("trim expects a string".into()),
                span: Span::dummy(),
            }),
        });
        self.register_builtin("contains", |args| match (args.first(), args.get(1)) {
            (Some(Value::String(s)), Some(Value::String(sub))) => {
                Ok(Value::Bool(s.contains(sub.as_str())))
            }
            _ => Err(RuntimeError {
                kind: RuntimeErrorKind::TypeError("contains expects two strings".into()),
                span: Span::dummy(),
            }),
        });
        self.register_builtin("starts_with", |args| match (args.first(), args.get(1)) {
            (Some(Value::String(s)), Some(Value::String(prefix))) => {
                Ok(Value::Bool(s.starts_with(prefix.as_str())))
            }
            _ => Err(RuntimeError {
                kind: RuntimeErrorKind::TypeError("starts_with expects two strings".into()),
                span: Span::dummy(),
            }),
        });
        self.register_builtin("replace", |args| {
            match (args.first(), args.get(1), args.get(2)) {
                (Some(Value::String(s)), Some(Value::String(from)), Some(Value::String(to))) => {
                    Ok(Value::String(s.replace(from.as_str(), to.as_str())))
                }
                _ => Err(RuntimeError {
                    kind: RuntimeErrorKind::TypeError("replace expects three strings".into()),
                    span: Span::dummy(),
                }),
            }
        });
        self.register_builtin("chars", |args| match args.first() {
            Some(Value::String(s)) => {
                let chars: Vec<Value> = s.chars().map(|c| Value::String(c.to_string())).collect();
                Ok(Value::List(chars))
            }
            _ => Err(RuntimeError {
                kind: RuntimeErrorKind::TypeError("chars expects a string".into()),
                span: Span::dummy(),
            }),
        });
        self.register_builtin("join", |args| match (args.first(), args.get(1)) {
            (Some(Value::List(items)), Some(Value::String(sep))) => {
                let strings: Vec<String> = items
                    .iter()
                    .map(|v| match v {
                        Value::String(s) => s.clone(),
                        other => other.display_print(),
                    })
                    .collect();
                Ok(Value::String(strings.join(sep.as_str())))
            }
            _ => Err(RuntimeError {
                kind: RuntimeErrorKind::TypeError("join expects a list and string".into()),
                span: Span::dummy(),
            }),
        });
        self.register_builtin("slice", |args| {
            match (args.first(), args.get(1), args.get(2)) {
                (Some(Value::List(items)), Some(Value::Int(start)), Some(Value::Int(end))) => {
                    let len = items.len() as i64;
                    let s = (*start).max(0).min(len) as usize;
                    let e = (*end).max(0).min(len) as usize;
                    let slice = items[s..e].to_vec();
                    Ok(Value::List(slice))
                }
                _ => Err(RuntimeError {
                    kind: RuntimeErrorKind::TypeError("slice expects (List, Int, Int)".into()),
                    span: Span::dummy(),
                }),
            }
        });

        // Numeric builtins
        self.register_builtin("abs", |args| match args.first() {
            Some(Value::Int(n)) => Ok(Value::Int(n.abs())),
            Some(Value::Float(f)) => Ok(Value::Float(f.abs())),
            _ => Err(RuntimeError {
                kind: RuntimeErrorKind::TypeError("abs expects a number".into()),
                span: Span::dummy(),
            }),
        });
        self.register_builtin("min", |args| match (args.first(), args.get(1)) {
            (Some(Value::Int(a)), Some(Value::Int(b))) => Ok(Value::Int(*a.min(b))),
            _ => Err(RuntimeError {
                kind: RuntimeErrorKind::TypeError("min expects two integers".into()),
                span: Span::dummy(),
            }),
        });
        self.register_builtin("max", |args| match (args.first(), args.get(1)) {
            (Some(Value::Int(a)), Some(Value::Int(b))) => Ok(Value::Int(*a.max(b))),
            _ => Err(RuntimeError {
                kind: RuntimeErrorKind::TypeError("max expects two integers".into()),
                span: Span::dummy(),
            }),
        });
        self.register_builtin("floor", |args| match args.first() {
            Some(Value::Float(f)) => Ok(Value::Int(f.floor() as i64)),
            Some(Value::Int(n)) => Ok(Value::Int(*n)),
            _ => Err(RuntimeError {
                kind: RuntimeErrorKind::TypeError("floor expects a number".into()),
                span: Span::dummy(),
            }),
        });
        self.register_builtin("ceil", |args| match args.first() {
            Some(Value::Float(f)) => Ok(Value::Int(f.ceil() as i64)),
            Some(Value::Int(n)) => Ok(Value::Int(*n)),
            _ => Err(RuntimeError {
                kind: RuntimeErrorKind::TypeError("ceil expects a number".into()),
                span: Span::dummy(),
            }),
        });

        // `next` is registered as a placeholder; the real logic lives in
        // `call_value` which can pattern-match on Value::Generator.
        self.register_builtin("next", |_args| {
            Err(RuntimeError {
                kind: RuntimeErrorKind::TypeError("next: argument is not a generator".into()),
                span: Span::dummy(),
            })
        });
        // `generate` is registered as a placeholder; the real logic lives in
        // `call_value` which can clone the interpreter and spawn a thread.
        self.register_builtin("generate", |_args| {
            Err(RuntimeError {
                kind: RuntimeErrorKind::TypeError("generate: argument must be a function".into()),
                span: Span::dummy(),
            })
        });
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
            Signal::Resume(v) => LuxError::Runtime(RuntimeError {
                kind: RuntimeErrorKind::Internal(format!("resume outside handler: {v}")),
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
                self.env.set(&decl.name, val);
                Ok(None)
            }
            Item::TypeDecl(decl) => {
                for variant in &decl.variants {
                    let arity = variant.fields.len();
                    self.variant_constructors
                        .insert(variant.name.clone(), arity);
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

            Expr::Let { name, value, .. } => {
                // Value of a let binding is never in tail position.
                self.in_tail_position = false;
                let val = self.eval_expr(value)?;
                self.env.set(name, val);
                Ok(Value::Unit)
            }

            Expr::Pipe { left, right, span } => {
                // Sub-expressions of a pipe are not in tail position.
                self.in_tail_position = false;
                let arg = self.eval_expr(left)?;
                let func = self.eval_expr(right)?;
                self.call_value(func, vec![arg], span)
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
                span,
            } => self.eval_handle(expr, handlers, span),

            Expr::Resume { value, .. } => {
                let val = self.eval_expr(value)?;
                Err(Signal::Resume(val))
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
            _ => Err(self.type_err(&format!("no field '{field}' on {obj}"), span)),
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
            call_depth: 0,
            current_fn_name: None,
            in_tail_position: false,
            generator_sender: Some(value_tx.clone()),
            impl_methods: self.impl_methods.clone(),
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
                    self.env.set(&decl.name, val);
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
        match pattern {
            Pattern::Wildcard(_) => true,
            Pattern::Binding(name, _) => {
                bindings.insert(name.clone(), value.clone());
                true
            }
            Pattern::Literal(lit, _) => match (lit, value) {
                (LitPattern::Int(a), Value::Int(b)) => a == b,
                (LitPattern::Float(a), Value::Float(b)) => a == b,
                (LitPattern::String(a), Value::String(b)) => a == b,
                (LitPattern::Bool(a), Value::Bool(b)) => a == b,
                _ => false,
            },
            Pattern::Variant {
                name, fields: pats, ..
            } => match value {
                Value::AdtVariant {
                    name: vname,
                    fields,
                } => {
                    if name != vname || pats.len() != fields.len() {
                        return false;
                    }
                    pats.iter()
                        .zip(fields.iter())
                        .all(|(p, v)| self.match_pattern(p, v, bindings))
                }
                // A 0-field variant pattern matching a Binding-like scenario:
                // e.g., pattern `None` vs value `None`.
                _ if pats.is_empty() => {
                    // Check if the value is a variant with the same name.
                    matches!(value, Value::AdtVariant { name: vn, fields } if vn == name && fields.is_empty())
                }
                _ => false,
            },
            Pattern::Tuple(pats, _) => {
                let vs = match value {
                    Value::Tuple(vs) | Value::List(vs) => vs,
                    _ => return false,
                };
                if pats.len() != vs.len() {
                    return false;
                }
                pats.iter()
                    .zip(vs.iter())
                    .all(|(p, v)| self.match_pattern(p, v, bindings))
            }
        }
    }

    // ── Effect handling ──────────────────────────────────────────

    fn eval_handle(
        &mut self,
        body: &Expr,
        handler_clauses: &[ast::HandlerClause],
        _span: &Span,
    ) -> EvalResult {
        // Build handler frame from clauses.
        let mut handlers = HashMap::new();
        for clause in handler_clauses {
            match &clause.operation {
                HandlerOp::OpHandler {
                    op_name,
                    params,
                    body,
                    ..
                } => {
                    handlers.insert(
                        op_name.clone(),
                        EffectHandler {
                            params: params.clone(),
                            body: body.clone(),
                            env: self.env.clone_flat(),
                        },
                    );
                }
                HandlerOp::UseHandler { .. } => {
                    // Skip for MVP.
                }
            }
        }

        let frame = HandlerFrame { handlers };
        self.handler_stack.push(frame);

        let result = self.eval_expr(body);
        self.handler_stack.pop();

        match result {
            Ok(val) => Ok(val),
            // A handler completed without resume — its value replaces the handle expr
            Err(Signal::HandleDone(val)) => Ok(val),
            Err(other) => Err(other),
        }
    }

    /// Dispatch an effect operation call directly to the nearest handler.
    /// If the handler calls resume(val), val is returned and execution continues.
    /// If the handler doesn't resume, Signal::HandleDone propagates up.
    ///
    /// When running inside a generator thread (i.e. `generator_channels` is
    /// `Some`), a `yield` operation is handled natively: the yielded value is
    /// sent through the value channel and the thread blocks until the next
    /// signal arrives, then resumes with `()`.
    fn dispatch_effect(&mut self, op_name: &str, args: &[Value], span: &Span) -> EvalResult {
        // Native yield interception for generator threads.
        if op_name == "yield" {
            if let Some(ref value_tx) = self.generator_sender {
                let val = args.first().cloned().unwrap_or(Value::Unit);
                // Send the yielded value. The rendezvous channel (capacity 0)
                // blocks here until `next()` receives, providing the pause
                // between yields. If the caller dropped the generator, stop.
                match value_tx.send(Some(val)) {
                    Ok(()) => return Ok(Value::Unit),
                    Err(_) => return Err(Signal::Break(Value::Unit)),
                }
            }
        }

        // Search handler stack from top to bottom for a matching handler
        let handler = self
            .handler_stack
            .iter()
            .rev()
            .find_map(|frame| frame.handlers.get(op_name))
            .cloned();

        if let Some(handler) = handler {
            let mut handler_env = Environment::with_parent(handler.env.clone());
            for (param, arg) in handler.params.iter().zip(args.iter()) {
                handler_env.set(param, arg.clone());
            }
            let saved_env = std::mem::replace(&mut self.env, handler_env);
            let result = self.eval_expr(&handler.body);
            self.env = saved_env;

            match result {
                // Handler called resume(val) — return val, continue execution
                Err(Signal::Resume(val)) => Ok(val),
                // Handler returned without resume (like fail) — short-circuit
                Ok(val) => Err(Signal::HandleDone(val)),
                // Propagate other signals
                Err(other) => Err(other),
            }
        } else {
            // No handler found — unhandled effect
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
