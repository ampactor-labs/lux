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
    BundledClosure {
        closure: Arc<Closure>,
        evidence: Arc<Vec<VmValue>>,
    },
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
    /// Evidence for direct effect dispatch — handler operation table.
    Evidence(Arc<VmEvidence>),
}

// Compile-time assertion: VmValue must be Send for parallel prism.
#[allow(dead_code)]
const _: () = {
    fn assert_send<T: Send>() {}
    fn check() {
        assert_send::<VmValue>();
    }
};

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
/// When called with `resume(val)`, replays the handle body from the start
/// with the extended replay log. Previous performs consume from the log;
/// the next perform past the log dispatches normally.
#[derive(Debug)]
pub struct VmContinuation {
    /// Replay log: values returned by previous performs during replay.
    pub replay_log: Vec<VmValue>,
    /// The function proto containing the handle expression.
    pub proto: Arc<FnProto>,
    /// IP of the body start (right after PushHandler operands).
    pub body_start_ip: usize,
    /// Resolved handler entries for the handle block.
    pub handler_entries: Vec<super::frame::VmHandlerEntry>,
    /// Initial state values for the handler.
    pub initial_state: Vec<VmValue>,
    /// Stack snapshot: locals from the enclosing frame at the time PushHandler ran.
    pub stack_snapshot: Vec<VmValue>,
    /// Upvalues from the enclosing frame.
    pub upvalues: Vec<VmValue>,
    /// Handler stack snapshot (outer handlers, excluding the current one).
    pub outer_handler_stack: Vec<super::frame::VmHandlerFrame>,
    /// Number of frames (outer) when the handler was installed.
    pub outer_frame_count: usize,
}

/// Evidence for direct effect dispatch — compiled handler operations as callable protos.
///
/// In the hybrid approach, the handler is still on the handler stack (for
/// indirect effects via function calls). Evidence provides a fast path for
/// direct effect operations: `PerformEvidence` calls handler bodies directly
/// through the evidence value — no handler stack search, no continuation capture.
#[derive(Debug)]
pub struct VmEvidence {
    pub entries: Vec<VmEvidenceEntry>,
    /// Index into `Vm.handler_stack` for the associated handler frame.
    /// State is read/written from this handler frame, keeping state in sync
    /// between evidence dispatch and normal handler stack dispatch.
    pub handler_stack_idx: usize,
}

/// A single operation entry in an evidence value.
#[derive(Debug)]
pub struct VmEvidenceEntry {
    pub op_name: String,
    pub proto: Arc<FnProto>,
    pub param_count: u8,
    /// Captured upvalues from the enclosing scope at PushHandler time.
    pub upvalues: Vec<VmValue>,
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
            VmValue::String(s) => write!(f, "\"{s}\""),
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
            VmValue::BundledClosure { closure, .. } => {
                let name = closure.proto.name.as_deref().unwrap_or("<lambda>");
                write!(f, "<bundled fn {name}>")
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
            VmValue::Evidence(_) => write!(f, "<evidence>"),
        }
    }
}

impl VmValue {
    /// Display for `print`/`println` — strings without quotes.
    pub fn display_print(&self) -> String {
        match self {
            VmValue::String(s) => (**s).clone(),
            other => format!("{other}"),
        }
    }
}
