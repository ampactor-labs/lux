//! Runtime values for the Lux VM.
//!
//! `VmValue` is the stack type — Arc-wrapped heap values for O(1) clone
//! during stack operations. This is the VM's equivalent of the interpreter's
//! `Value` enum but optimized for stack-based execution.

use std::fmt;
use std::sync::Arc;

use super::chunk::FnProto;

/// Runtime value on the VM stack.
///
/// All heap-allocated variants use `Arc` for O(1) clone when values are
/// duplicated on the stack (DUP, local loads, etc.).
#[derive(Debug, Clone)]
pub enum VmValue {
    Int(i64),
    Float(f64),
    String(Arc<String>),
    Bool(bool),
    Unit,
    List(Arc<Vec<VmValue>>),
    Tuple(Arc<Vec<VmValue>>),
    Closure(Arc<Closure>),
    Builtin(BuiltinId),
    /// ADT variant: name index into the chunk's name table + fields.
    Variant {
        name: Arc<String>,
        fields: Arc<Vec<VmValue>>,
    },
    /// Captured continuation for multi-shot effects.
    Continuation(Arc<VmContinuation>),
    /// Generator (coroutine-based, WASM-compatible).
    Generator(Arc<VmGenerator>),
}

impl PartialEq for VmValue {
    fn eq(&self, other: &Self) -> bool {
        match (self, other) {
            (VmValue::Int(a), VmValue::Int(b)) => a == b,
            (VmValue::Float(a), VmValue::Float(b)) => a == b,
            (VmValue::String(a), VmValue::String(b)) => a == b,
            (VmValue::Bool(a), VmValue::Bool(b)) => a == b,
            (VmValue::Unit, VmValue::Unit) => true,
            (VmValue::List(a), VmValue::List(b)) => a == b,
            (VmValue::Tuple(a), VmValue::Tuple(b)) => a == b,
            (
                VmValue::Variant {
                    name: n1,
                    fields: f1,
                },
                VmValue::Variant {
                    name: n2,
                    fields: f2,
                },
            ) => n1 == n2 && f1 == f2,
            _ => false,
        }
    }
}

/// A compiled closure: function prototype + captured upvalues.
#[derive(Debug)]
pub struct Closure {
    pub proto: Arc<FnProto>,
    pub upvalues: Vec<VmValue>,
}

/// Identifier for a built-in function.
#[derive(Debug, Clone, Copy, PartialEq, Eq, Hash)]
pub struct BuiltinId(pub u16);

/// Captured continuation for replay-based multi-shot effects.
///
/// Contains the full state needed to resume execution from a perform site.
#[derive(Debug)]
pub struct VmContinuation {
    /// Replay log: sequence of values returned by previous resumes.
    pub replay_log: Vec<VmValue>,
    /// The handler frame index this continuation belongs to.
    pub handler_idx: usize,
    /// Snapshot of stack at the point of capture.
    pub stack_snapshot: Vec<VmValue>,
    /// Snapshot of call frames at the point of capture.
    pub frame_count: usize,
}

/// Generator state for coroutine-based yield.
#[derive(Debug)]
pub struct VmGenerator {
    /// The continuation to resume on `next()`.
    pub continuation: Option<VmContinuation>,
    /// Whether the generator has completed.
    pub done: bool,
}

impl fmt::Display for VmValue {
    fn fmt(&self, f: &mut fmt::Formatter<'_>) -> fmt::Result {
        match self {
            VmValue::Int(n) => write!(f, "{n}"),
            VmValue::Float(n) => write!(f, "{n}"),
            VmValue::String(s) => write!(f, "{s}"),
            VmValue::Bool(b) => write!(f, "{b}"),
            VmValue::Unit => write!(f, "()"),
            VmValue::List(elems) => {
                write!(f, "[")?;
                for (i, e) in elems.iter().enumerate() {
                    if i > 0 {
                        write!(f, ", ")?;
                    }
                    write!(f, "{e}")?;
                }
                write!(f, "]")
            }
            VmValue::Tuple(elems) => {
                write!(f, "(")?;
                for (i, e) in elems.iter().enumerate() {
                    if i > 0 {
                        write!(f, ", ")?;
                    }
                    write!(f, "{e}")?;
                }
                write!(f, ")")
            }
            VmValue::Closure(c) => {
                let name = c.proto.name.as_deref().unwrap_or("<lambda>");
                write!(f, "<fn {name}>")
            }
            VmValue::Builtin(id) => write!(f, "<builtin #{}>", id.0),
            VmValue::Variant { name, fields } => {
                write!(f, "{name}")?;
                if !fields.is_empty() {
                    write!(f, "(")?;
                    for (i, field) in fields.iter().enumerate() {
                        if i > 0 {
                            write!(f, ", ")?;
                        }
                        write!(f, "{field}")?;
                    }
                    write!(f, ")")?;
                }
                Ok(())
            }
            VmValue::Continuation(_) => write!(f, "<continuation>"),
            VmValue::Generator(_) => write!(f, "<generator>"),
        }
    }
}
