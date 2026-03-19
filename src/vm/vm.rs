//! Stack-based VM execution loop for Lux.
//!
//! The core is a flat `match` on opcodes — no recursion. This is the
//! fundamental speed advantage over the tree-walking interpreter.

use std::collections::HashMap;
use std::sync::Arc;

use super::chunk::{Constant, FnProto};
use super::error::VmError;
use super::frame::{CallFrame, VmHandlerFrame};
use super::opcode::OpCode;
use super::value::{BuiltinId, Closure, VmValue};

/// Variant name → ordered field names (for FieldAccess index resolution).
type FieldRegistry = HashMap<String, Vec<String>>;

/// Signature for VM builtin functions.
pub type BuiltinFn = fn(&[VmValue]) -> Result<VmValue, String>;

/// The Lux bytecode virtual machine.
pub struct Vm {
    /// Call frame stack.
    pub(super) frames: Vec<CallFrame>,
    /// Value stack.
    pub(super) stack: Vec<VmValue>,
    /// Effect handler stack.
    pub(super) handler_stack: Vec<VmHandlerFrame>,
    /// Global variables (by name index).
    globals: HashMap<u16, VmValue>,
    /// Global name → name_idx mapping (for cross-chunk resolution).
    global_names: HashMap<String, u16>,
    /// Registered builtin functions.
    builtins: Vec<(String, BuiltinFn)>,
    /// Builtin name → id mapping.
    builtin_map: HashMap<String, BuiltinId>,
    /// Output buffer (for WASM compatibility — captures print output).
    pub output: String,
    /// Active handler dispatch stack: `(handler_stack_idx, body_frame_idx)`.
    /// Pushed by Perform, popped by Resume. A stack (not scalar) so nested
    /// effects don't clobber outer dispatch state.
    pub(super) handler_dispatch_stack: Vec<(usize, usize)>,
    /// Variant name → ordered field names (for named field access).
    field_registry: FieldRegistry,
    /// Replay log for multi-shot continuation re-evaluation. `None` = normal mode.
    pub(super) replay_log: Option<Vec<VmValue>>,
    /// Current position in the replay log.
    pub(super) replay_pos: usize,
    /// When true, `PopHandler` at nesting depth 0 stops execution and returns TOS.
    /// Used during continuation replay to stop after the handle body completes.
    pub(super) stop_at_pop_handler: bool,
}

impl Default for Vm {
    fn default() -> Self {
        Self::new()
    }
}

impl Vm {
    pub fn new() -> Self {
        let mut vm = Self {
            frames: Vec::with_capacity(64),
            stack: Vec::with_capacity(256),
            handler_stack: Vec::new(),
            globals: HashMap::new(),
            global_names: HashMap::new(),
            builtins: Vec::new(),
            builtin_map: HashMap::new(),
            output: String::new(),
            handler_dispatch_stack: Vec::new(),
            field_registry: HashMap::new(),
            replay_log: None,
            replay_pos: 0,
            stop_at_pop_handler: false,
        };
        vm.register_builtins();
        vm
    }

    /// Run a compiled function prototype.
    pub fn run(&mut self, proto: Arc<FnProto>) -> Result<Option<VmValue>, VmError> {
        // Load field registry from the top-level proto.
        self.field_registry = proto.field_registry.clone();

        // Allocate locals on the stack
        let stack_base = self.stack.len();
        for _ in 0..proto.local_count {
            self.stack.push(VmValue::Unit);
        }

        self.frames.push(CallFrame {
            proto: proto.clone(),
            upvalues: Vec::new(),
            ip: 0,
            stack_base,
            has_func_slot: false, // top-level frame
        });

        let result = self.execute()?;

        // Clean up
        self.frames.pop();
        self.stack.truncate(stack_base);

        Ok(result)
    }

    /// Main execution loop.
    pub(super) fn execute(&mut self) -> Result<Option<VmValue>, VmError> {
        loop {
            let frame_idx = self.frames.len() - 1;
            let frame = &mut self.frames[frame_idx];

            if frame.ip >= frame.proto.chunk.code.len() {
                // End of code — return whatever's on the stack
                return Ok(self.stack.pop());
            }

            let byte = frame.read_byte();
            let Some(op) = OpCode::from_byte(byte) else {
                let line = frame.current_line();
                return Err(VmError::new(format!("unknown opcode: {byte:#04x}"), line));
            };

            match op {
                // ── Literals ──────────────────────────────────────
                OpCode::LoadConst => {
                    let idx = self.frames[frame_idx].read_u16();
                    let val = self.load_constant(frame_idx, idx)?;
                    self.stack.push(val);
                }
                OpCode::LoadInt => {
                    let val = self.frames[frame_idx].read_byte() as i8;
                    self.stack.push(VmValue::Int(val as i64));
                }
                OpCode::LoadBool => {
                    let val = self.frames[frame_idx].read_byte();
                    self.stack.push(VmValue::Bool(val != 0));
                }
                OpCode::LoadUnit => {
                    self.stack.push(VmValue::Unit);
                }

                // ── Locals ────────────────────────────────────────
                OpCode::LoadLocal => {
                    let slot = self.frames[frame_idx].read_u16() as usize;
                    let base = self.frames[frame_idx].stack_base;
                    let val = self.stack[base + slot].clone();
                    self.stack.push(val);
                }
                OpCode::StoreLocal => {
                    let slot = self.frames[frame_idx].read_u16() as usize;
                    let base = self.frames[frame_idx].stack_base;
                    let val = self.stack.last().cloned().unwrap_or(VmValue::Unit);
                    self.stack[base + slot] = val;
                }
                OpCode::LoadUpval => {
                    let idx = self.frames[frame_idx].read_u16() as usize;
                    let val = self.frames[frame_idx]
                        .upvalues
                        .get(idx)
                        .cloned()
                        .unwrap_or(VmValue::Unit);
                    self.stack.push(val);
                }

                // ── Globals ───────────────────────────────────────
                OpCode::LoadGlobal => {
                    let name_idx = self.frames[frame_idx].read_u16();
                    let name = self.frames[frame_idx]
                        .proto
                        .chunk
                        .names
                        .get(name_idx as usize)
                        .cloned()
                        .unwrap_or_default();

                    // Check builtins first
                    if let Some(id) = self.builtin_map.get(&name) {
                        self.stack.push(VmValue::Builtin(*id));
                    } else if let Some(global_idx) = self.global_names.get(&name) {
                        if let Some(val) = self.globals.get(global_idx) {
                            self.stack.push(val.clone());
                        } else {
                            self.stack.push(VmValue::Unit);
                        }
                    } else {
                        // Unknown global — push Unit (will error at call site)
                        self.stack.push(VmValue::Unit);
                    }
                }
                OpCode::StoreGlobal => {
                    let name_idx = self.frames[frame_idx].read_u16();
                    let name = self.frames[frame_idx]
                        .proto
                        .chunk
                        .names
                        .get(name_idx as usize)
                        .cloned()
                        .unwrap_or_default();
                    let val = self.stack.pop().unwrap_or(VmValue::Unit);
                    let idx = if let Some(idx) = self.global_names.get(&name) {
                        *idx
                    } else {
                        let idx = self.global_names.len() as u16;
                        self.global_names.insert(name, idx);
                        idx
                    };
                    self.globals.insert(idx, val);
                }

                // ── Arithmetic ────────────────────────────────────
                OpCode::Add => self.binary_op(|a, b| match (a, b) {
                    (VmValue::Int(a), VmValue::Int(b)) => Ok(VmValue::Int(a + b)),
                    (VmValue::Float(a), VmValue::Float(b)) => Ok(VmValue::Float(a + b)),
                    (VmValue::Int(a), VmValue::Float(b)) => Ok(VmValue::Float(a as f64 + b)),
                    (VmValue::Float(a), VmValue::Int(b)) => Ok(VmValue::Float(a + b as f64)),
                    _ => Err("type error: cannot add".into()),
                })?,
                OpCode::Sub => self.binary_op(|a, b| match (a, b) {
                    (VmValue::Int(a), VmValue::Int(b)) => Ok(VmValue::Int(a - b)),
                    (VmValue::Float(a), VmValue::Float(b)) => Ok(VmValue::Float(a - b)),
                    _ => Err("type error: cannot subtract".into()),
                })?,
                OpCode::Mul => self.binary_op(|a, b| match (a, b) {
                    (VmValue::Int(a), VmValue::Int(b)) => Ok(VmValue::Int(a * b)),
                    (VmValue::Float(a), VmValue::Float(b)) => Ok(VmValue::Float(a * b)),
                    _ => Err("type error: cannot multiply".into()),
                })?,
                OpCode::Div => self.binary_op(|a, b| match (a, b) {
                    (VmValue::Int(a), VmValue::Int(b)) => {
                        if b == 0 {
                            Err("division by zero".into())
                        } else {
                            Ok(VmValue::Int(a / b))
                        }
                    }
                    (VmValue::Float(a), VmValue::Float(b)) => Ok(VmValue::Float(a / b)),
                    _ => Err("type error: cannot divide".into()),
                })?,
                OpCode::Mod => self.binary_op(|a, b| match (a, b) {
                    (VmValue::Int(a), VmValue::Int(b)) => {
                        if b == 0 {
                            Err("modulo by zero".into())
                        } else {
                            Ok(VmValue::Int(a % b))
                        }
                    }
                    _ => Err("type error: cannot modulo".into()),
                })?,
                OpCode::Neg => {
                    let val = self.stack.pop().unwrap_or(VmValue::Unit);
                    match val {
                        VmValue::Int(n) => self.stack.push(VmValue::Int(-n)),
                        VmValue::Float(n) => self.stack.push(VmValue::Float(-n)),
                        _ => {
                            let line = self.frames[frame_idx].current_line();
                            return Err(VmError::new("type error: cannot negate", line));
                        }
                    }
                }
                OpCode::Not => {
                    let val = self.stack.pop().unwrap_or(VmValue::Unit);
                    match val {
                        VmValue::Bool(b) => self.stack.push(VmValue::Bool(!b)),
                        _ => {
                            let line = self.frames[frame_idx].current_line();
                            return Err(VmError::new("type error: cannot negate bool", line));
                        }
                    }
                }

                // ── Comparison ────────────────────────────────────
                OpCode::Eq => self.binary_op(|a, b| Ok(VmValue::Bool(a == b)))?,
                OpCode::Neq => self.binary_op(|a, b| Ok(VmValue::Bool(a != b)))?,
                OpCode::Lt => self.comparison_op(|a, b| a < b)?,
                OpCode::LtEq => self.comparison_op(|a, b| a <= b)?,
                OpCode::Gt => self.comparison_op(|a, b| a > b)?,
                OpCode::GtEq => self.comparison_op(|a, b| a >= b)?,

                // ── String/List ───────────────────────────────────
                OpCode::Concat => {
                    let b = self.stack.pop().unwrap_or(VmValue::Unit);
                    let a = self.stack.pop().unwrap_or(VmValue::Unit);
                    match (a, b) {
                        (VmValue::String(a), VmValue::String(b)) => {
                            let mut s = (*a).clone();
                            s.push_str(&b);
                            self.stack.push(VmValue::String(Arc::new(s)));
                        }
                        (VmValue::List(a), VmValue::List(b)) => {
                            let mut v = (*a).clone();
                            v.extend((*b).iter().cloned());
                            self.stack.push(VmValue::List(Arc::new(v)));
                        }
                        _ => {
                            let line = self.frames[frame_idx].current_line();
                            return Err(VmError::new("type error: cannot concat", line));
                        }
                    }
                }

                // ── Control flow ──────────────────────────────────
                OpCode::Jump => {
                    let offset = self.frames[frame_idx].read_i16();
                    let ip = self.frames[frame_idx].ip;
                    self.frames[frame_idx].ip = (ip as i32 + offset as i32) as usize;
                }
                OpCode::JumpIfFalse => {
                    let offset = self.frames[frame_idx].read_i16();
                    if let Some(VmValue::Bool(false)) = self.stack.last() {
                        let ip = self.frames[frame_idx].ip;
                        self.frames[frame_idx].ip = (ip as i32 + offset as i32) as usize;
                    }
                }
                OpCode::JumpIfTrue => {
                    let offset = self.frames[frame_idx].read_i16();
                    if let Some(VmValue::Bool(true)) = self.stack.last() {
                        let ip = self.frames[frame_idx].ip;
                        self.frames[frame_idx].ip = (ip as i32 + offset as i32) as usize;
                    }
                }
                OpCode::Pop => {
                    self.stack.pop();
                }
                OpCode::Dup => {
                    if let Some(val) = self.stack.last().cloned() {
                        self.stack.push(val);
                    }
                }

                // ── Functions ─────────────────────────────────────
                OpCode::MakeClosure => {
                    let proto_idx = self.frames[frame_idx].read_u16();
                    let proto = self.load_fn_proto(frame_idx, proto_idx)?;
                    let upval_count = proto.upval_count;
                    let mut upvalues = Vec::with_capacity(upval_count as usize);
                    for _ in 0..upval_count {
                        let is_local = self.frames[frame_idx].read_byte() != 0;
                        let idx = self.frames[frame_idx].read_u16() as usize;
                        let val = if is_local {
                            let base = self.frames[frame_idx].stack_base;
                            self.stack.get(base + idx).cloned().unwrap_or(VmValue::Unit)
                        } else {
                            self.frames[frame_idx]
                                .upvalues
                                .get(idx)
                                .cloned()
                                .unwrap_or(VmValue::Unit)
                        };
                        upvalues.push(val);
                    }
                    self.stack
                        .push(VmValue::Closure(Arc::new(Closure { proto, upvalues })));
                }
                OpCode::Call => {
                    let argc = self.frames[frame_idx].read_byte() as usize;
                    self.call_value(argc, false)?;
                }
                OpCode::TailCall => {
                    let argc = self.frames[frame_idx].read_byte() as usize;
                    self.call_value(argc, true)?;
                }
                OpCode::Return => {
                    let result = self.stack.pop().unwrap_or(VmValue::Unit);
                    if self.frames.len() <= 1 {
                        // Top-level return
                        self.stack.push(result);
                        return Ok(self.stack.pop());
                    }

                    // Check if this is a handler body returning without Resume
                    // (HandleDone). The handler's return value becomes the handle
                    // expression's result.
                    if let Some(&(h_idx, body_idx)) = self.handler_dispatch_stack.last() {
                        if frame_idx == body_idx {
                            self.handler_dispatch_stack.pop();
                            let handler_frame = self.handler_stack[h_idx].frame_idx;
                            let stack_height = self.handler_stack[h_idx].stack_height;

                            // Pop handler body frame.
                            let base = self.frames[frame_idx].stack_base;
                            self.stack.truncate(base);
                            self.frames.pop();

                            // Unwind: pop all frames between handler body and
                            // handle frame (e.g., function calls that performed
                            // the effect from inside the handle body).
                            while self.frames.len() > handler_frame + 1 {
                                let b = self.frames.last().unwrap().stack_base;
                                self.stack.truncate(b);
                                self.frames.pop();
                            }

                            // Unwind stack to handler's installation point.
                            self.stack.truncate(stack_height);

                            // Pop the handler frame.
                            self.handler_stack.remove(h_idx);

                            // Push result as handle expression's value.
                            self.stack.push(result.clone());

                            // Skip past PopHandler in the handle frame.
                            self.skip_past_pop_handler(handler_frame);

                            // In continuation replay, stop after handle body completes.
                            if self.stop_at_pop_handler {
                                return Ok(Some(result));
                            }

                            continue;
                        }
                    }

                    let frame = &self.frames[frame_idx];
                    let base = frame.stack_base;
                    let has_func_slot = frame.has_func_slot;
                    let truncate_to = if has_func_slot {
                        base.saturating_sub(1)
                    } else {
                        base
                    };
                    self.stack.truncate(truncate_to);
                    self.frames.pop();
                    self.stack.push(result);
                }
                OpCode::CallBuiltin => {
                    let id = self.frames[frame_idx].read_u16();
                    let argc = self.frames[frame_idx].read_byte() as usize;
                    let start = self.stack.len() - argc;
                    let args: Vec<VmValue> = self.stack.drain(start..).collect();
                    self.call_builtin_with_args(BuiltinId(id), &args)?;
                }

                // ── Collections ───────────────────────────────────
                OpCode::MakeList => {
                    let count = self.frames[frame_idx].read_u16() as usize;
                    let start = self.stack.len() - count;
                    let elements: Vec<VmValue> = self.stack.drain(start..).collect();
                    self.stack.push(VmValue::List(Arc::new(elements)));
                }
                OpCode::MakeTuple => {
                    let count = self.frames[frame_idx].read_u16() as usize;
                    let start = self.stack.len() - count;
                    let elements: Vec<VmValue> = self.stack.drain(start..).collect();
                    self.stack.push(VmValue::Tuple(Arc::new(elements)));
                }
                OpCode::ListIndex => {
                    let index = self.stack.pop().unwrap_or(VmValue::Unit);
                    let list = self.stack.pop().unwrap_or(VmValue::Unit);
                    match (&list, &index) {
                        (VmValue::List(elems), VmValue::Int(i)) => {
                            let idx = *i as usize;
                            if idx < elems.len() {
                                self.stack.push(elems[idx].clone());
                            } else {
                                let line = self.frames[frame_idx].current_line();
                                return Err(VmError::new("index out of bounds", line));
                            }
                        }
                        (VmValue::Variant { fields, .. }, VmValue::Int(i)) => {
                            let idx = *i as usize;
                            if idx < fields.len() {
                                self.stack.push(fields[idx].clone());
                            } else {
                                self.stack.push(VmValue::Unit);
                            }
                        }
                        (VmValue::Tuple(elems), VmValue::Int(i)) => {
                            let idx = *i as usize;
                            if idx < elems.len() {
                                self.stack.push(elems[idx].clone());
                            } else {
                                let line = self.frames[frame_idx].current_line();
                                return Err(VmError::new("tuple index out of bounds", line));
                            }
                        }
                        _ => {
                            let line = self.frames[frame_idx].current_line();
                            return Err(VmError::new("type error: cannot index", line));
                        }
                    }
                }
                OpCode::FieldAccess => {
                    let name_idx = self.frames[frame_idx].read_u16();
                    let field_name = self.frames[frame_idx]
                        .proto
                        .chunk
                        .names
                        .get(name_idx as usize)
                        .cloned()
                        .unwrap_or_default();
                    let obj = self.stack.pop().unwrap_or(VmValue::Unit);
                    match &obj {
                        VmValue::Tuple(elems) => {
                            if let Ok(idx) = field_name.parse::<usize>() {
                                if idx < elems.len() {
                                    self.stack.push(elems[idx].clone());
                                } else {
                                    self.stack.push(VmValue::Unit);
                                }
                            } else {
                                self.stack.push(VmValue::Unit);
                            }
                        }
                        VmValue::Variant {
                            name: variant_name,
                            fields,
                        } => {
                            // Look up field index from the field registry.
                            let resolved = self
                                .field_registry
                                .get(variant_name.as_str())
                                .and_then(|names| names.iter().position(|n| n == &field_name))
                                .and_then(|idx| fields.get(idx).cloned());
                            self.stack.push(resolved.unwrap_or(VmValue::Unit));
                        }
                        _ => self.stack.push(VmValue::Unit),
                    }
                }
                OpCode::MakeVariant => {
                    let name_idx = self.frames[frame_idx].read_u16();
                    let field_count = self.frames[frame_idx].read_u16() as usize;
                    let name = self.frames[frame_idx]
                        .proto
                        .chunk
                        .names
                        .get(name_idx as usize)
                        .cloned()
                        .unwrap_or_default();
                    let start = self.stack.len() - field_count;
                    let fields: Vec<VmValue> = self.stack.drain(start..).collect();
                    self.stack.push(VmValue::Variant {
                        name: Arc::new(name),
                        fields: Arc::new(fields),
                    });
                }

                // ── Patterns ──────────────────────────────────────
                OpCode::MatchWildcard => {
                    self.stack.push(VmValue::Bool(true));
                }
                OpCode::MatchInt => {
                    let const_idx = self.frames[frame_idx].read_u16();
                    let expected = match self.frames[frame_idx]
                        .proto
                        .chunk
                        .constants
                        .get(const_idx as usize)
                    {
                        Some(Constant::Int(n)) => VmValue::Int(*n),
                        Some(Constant::Float(n)) => VmValue::Float(*n),
                        _ => VmValue::Unit,
                    };
                    let actual = self.stack.last().cloned().unwrap_or(VmValue::Unit);
                    self.stack.push(VmValue::Bool(actual == expected));
                }
                OpCode::MatchBool => {
                    let expected = self.frames[frame_idx].read_byte() != 0;
                    let actual = self.stack.last().cloned().unwrap_or(VmValue::Unit);
                    let matches = matches!(actual, VmValue::Bool(b) if b == expected);
                    self.stack.push(VmValue::Bool(matches));
                }
                OpCode::MatchString => {
                    let const_idx = self.frames[frame_idx].read_u16();
                    let expected = match self.frames[frame_idx]
                        .proto
                        .chunk
                        .constants
                        .get(const_idx as usize)
                    {
                        Some(Constant::String(s)) => VmValue::String(s.clone()),
                        _ => VmValue::Unit,
                    };
                    let actual = self.stack.last().cloned().unwrap_or(VmValue::Unit);
                    self.stack.push(VmValue::Bool(actual == expected));
                }
                OpCode::MatchVariant => {
                    let name_idx = self.frames[frame_idx].read_u16();
                    let expected_name = self.frames[frame_idx]
                        .proto
                        .chunk
                        .names
                        .get(name_idx as usize)
                        .cloned()
                        .unwrap_or_default();
                    let actual = self.stack.last().cloned().unwrap_or(VmValue::Unit);
                    let matches =
                        matches!(&actual, VmValue::Variant { name, .. } if **name == expected_name);
                    self.stack.push(VmValue::Bool(matches));
                }
                OpCode::MatchTuple => {
                    let count = self.frames[frame_idx].read_u16() as usize;
                    let actual = self.stack.last().cloned().unwrap_or(VmValue::Unit);
                    let matches = matches!(&actual, VmValue::Tuple(elems) if elems.len() == count);
                    self.stack.push(VmValue::Bool(matches));
                }
                OpCode::MatchListCons => {
                    let min_elems = self.frames[frame_idx].read_u16() as usize;
                    let actual = self.stack.last().cloned().unwrap_or(VmValue::Unit);
                    let matches =
                        matches!(&actual, VmValue::List(elems) if elems.len() >= min_elems);
                    self.stack.push(VmValue::Bool(matches));
                }
                OpCode::MatchListEmpty => {
                    let actual = self.stack.last().cloned().unwrap_or(VmValue::Unit);
                    let matches = matches!(&actual, VmValue::List(elems) if elems.is_empty());
                    self.stack.push(VmValue::Bool(matches));
                }
                OpCode::MatchListExact => {
                    let count = self.frames[frame_idx].read_u16() as usize;
                    let actual = self.stack.last().cloned().unwrap_or(VmValue::Unit);
                    let matches = matches!(&actual, VmValue::List(elems) if elems.len() == count);
                    self.stack.push(VmValue::Bool(matches));
                }
                OpCode::BindLocal => {
                    let slot = self.frames[frame_idx].read_u16() as usize;
                    let val = self.stack.last().cloned().unwrap_or(VmValue::Unit);
                    let base = self.frames[frame_idx].stack_base;
                    if base + slot < self.stack.len() {
                        self.stack[base + slot] = val;
                    }
                }

                // ── String interpolation ──────────────────────────
                OpCode::StringInterp => {
                    let count = self.frames[frame_idx].read_u16() as usize;
                    let start = self.stack.len() - count;
                    let parts: Vec<VmValue> = self.stack.drain(start..).collect();
                    let mut result = String::new();
                    for part in &parts {
                        result.push_str(&format!("{part}"));
                    }
                    self.stack.push(VmValue::String(Arc::new(result)));
                }

                // ── Effects ─────────────────────────────────────
                OpCode::PushHandler => {
                    self.op_push_handler(frame_idx)?;
                }
                OpCode::PopHandler => {
                    self.op_pop_handler();
                    // In continuation replay mode, stop after the handle body completes.
                    if self.stop_at_pop_handler {
                        return Ok(self.stack.pop());
                    }
                }
                OpCode::Perform => {
                    self.op_perform(frame_idx)?;
                }
                OpCode::Resume => {
                    self.op_resume(frame_idx)?;
                }
                OpCode::MakeContinuation => {
                    // Phase 6C-6: multi-shot continuations
                    let line = self.frames[frame_idx].current_line();
                    return Err(VmError::new(
                        "multi-shot continuations not yet implemented in VM",
                        line,
                    ));
                }

                // ── Loops ─────────────────────────────────────────
                OpCode::BreakLoop | OpCode::ContinueLoop => {
                    let line = self.frames[frame_idx].current_line();
                    return Err(VmError::new("unexpected loop control opcode", line));
                }
            }
        }
    }

    // ── Helpers ───────────────────────────────────────────────

    /// Advance IP past the next PopHandler opcode, properly decoding
    /// instructions (not byte-scanning) and tracking nesting depth.
    fn skip_past_pop_handler(&mut self, handle_frame_idx: usize) {
        let frame = &mut self.frames[handle_frame_idx];
        let code = &frame.proto.chunk.code;
        let mut depth: i32 = 0;
        while frame.ip < code.len() {
            let byte = code[frame.ip];
            frame.ip += 1;
            let Some(op) = OpCode::from_byte(byte) else {
                continue;
            };
            // Track nesting: PushHandler increases depth, PopHandler decreases.
            if op == OpCode::PushHandler {
                depth += 1;
            } else if op == OpCode::PopHandler {
                if depth == 0 {
                    return; // Found the matching PopHandler
                }
                depth -= 1;
            }
            // Skip operands for this instruction.
            frame.ip += Self::operand_size(op);
        }
    }

    /// Return the total operand byte count for an opcode.
    fn operand_size(op: OpCode) -> usize {
        match op {
            // No operands
            OpCode::Add
            | OpCode::Sub
            | OpCode::Mul
            | OpCode::Div
            | OpCode::Mod
            | OpCode::Neg
            | OpCode::Not
            | OpCode::Eq
            | OpCode::Neq
            | OpCode::Lt
            | OpCode::LtEq
            | OpCode::Gt
            | OpCode::GtEq
            | OpCode::Concat
            | OpCode::Pop
            | OpCode::Dup
            | OpCode::Return
            | OpCode::LoadUnit
            | OpCode::ListIndex
            | OpCode::MatchListEmpty
            | OpCode::MatchWildcard
            | OpCode::PopHandler
            | OpCode::MakeContinuation
            | OpCode::BreakLoop
            | OpCode::ContinueLoop => 0,
            // u8
            OpCode::LoadBool | OpCode::LoadInt | OpCode::MatchBool => 1,
            // u8 (argc)
            OpCode::Call | OpCode::TailCall => 1,
            // u16
            OpCode::LoadConst
            | OpCode::LoadLocal
            | OpCode::StoreLocal
            | OpCode::LoadUpval
            | OpCode::LoadGlobal
            | OpCode::StoreGlobal
            | OpCode::MakeList
            | OpCode::MakeTuple
            | OpCode::FieldAccess
            | OpCode::MatchString
            | OpCode::MatchVariant
            | OpCode::MatchTuple
            | OpCode::MatchListCons
            | OpCode::MatchListExact
            | OpCode::BindLocal
            | OpCode::StringInterp
            | OpCode::MatchInt => 2,
            // i16 (jump offset)
            OpCode::Jump | OpCode::JumpIfFalse | OpCode::JumpIfTrue => 2,
            // u16 + u8
            OpCode::CallBuiltin | OpCode::Perform => 3,
            // u16 + u16
            OpCode::MakeVariant => 4,
            // u16 + u16 + u8
            OpCode::PushHandler => 5,
            // MakeClosure: u16 proto idx (upvalues handled dynamically)
            OpCode::MakeClosure => 2, // base; upval descriptors skipped separately
            // Resume: u8 count + count * u16
            OpCode::Resume => 1, // base; state offsets handled by caller
        }
    }

    fn load_constant(&self, frame_idx: usize, idx: u16) -> Result<VmValue, VmError> {
        let constant = self.frames[frame_idx]
            .proto
            .chunk
            .constants
            .get(idx as usize)
            .ok_or_else(|| {
                VmError::new(
                    format!("invalid constant index: {idx}"),
                    self.frames[frame_idx].current_line(),
                )
            })?;
        Ok(match constant {
            Constant::Int(n) => VmValue::Int(*n),
            Constant::Float(n) => VmValue::Float(*n),
            Constant::String(s) => VmValue::String(s.clone()),
            Constant::FnProto(_) => VmValue::Unit, // FnProto loaded via MakeClosure
        })
    }

    fn load_fn_proto(&self, frame_idx: usize, idx: u16) -> Result<Arc<FnProto>, VmError> {
        match self.frames[frame_idx]
            .proto
            .chunk
            .constants
            .get(idx as usize)
        {
            Some(Constant::FnProto(p)) => Ok(p.clone()),
            _ => Err(VmError::new(
                "expected function prototype",
                self.frames[frame_idx].current_line(),
            )),
        }
    }

    fn binary_op(
        &mut self,
        f: impl FnOnce(VmValue, VmValue) -> Result<VmValue, String>,
    ) -> Result<(), VmError> {
        let b = self.stack.pop().unwrap_or(VmValue::Unit);
        let a = self.stack.pop().unwrap_or(VmValue::Unit);
        match f(a, b) {
            Ok(val) => {
                self.stack.push(val);
                Ok(())
            }
            Err(msg) => {
                let line = self.frames.last().map(|f| f.current_line()).unwrap_or(0);
                Err(VmError::new(msg, line))
            }
        }
    }

    fn comparison_op(&mut self, f: impl FnOnce(f64, f64) -> bool) -> Result<(), VmError> {
        let b = self.stack.pop().unwrap_or(VmValue::Unit);
        let a = self.stack.pop().unwrap_or(VmValue::Unit);
        let result = match (&a, &b) {
            (VmValue::Int(a), VmValue::Int(b)) => f(*a as f64, *b as f64),
            (VmValue::Float(a), VmValue::Float(b)) => f(*a, *b),
            (VmValue::Int(a), VmValue::Float(b)) => f(*a as f64, *b),
            (VmValue::Float(a), VmValue::Int(b)) => f(*a, *b as f64),
            (VmValue::String(a), VmValue::String(b)) => {
                let ord = a.cmp(b);
                f(ord as i32 as f64, 0.0)
            }
            _ => false,
        };
        self.stack.push(VmValue::Bool(result));
        Ok(())
    }

    /// Call a value on top of the stack with the given number of arguments.
    fn call_value(&mut self, argc: usize, _is_tail: bool) -> Result<(), VmError> {
        let func_idx = self.stack.len() - 1 - argc;
        let func = self.stack[func_idx].clone();

        match func {
            VmValue::Closure(closure) => {
                if closure.proto.arity as usize != argc {
                    let line = self.frames.last().map(|f| f.current_line()).unwrap_or(0);
                    return Err(VmError::new(
                        format!("expected {} arguments, got {}", closure.proto.arity, argc),
                        line,
                    ));
                }

                let stack_base = func_idx + 1;
                let extra_locals = (closure.proto.local_count as usize).saturating_sub(argc);
                for _ in 0..extra_locals {
                    self.stack.push(VmValue::Unit);
                }

                self.frames.push(CallFrame {
                    proto: closure.proto.clone(),
                    upvalues: closure.upvalues.clone(),
                    ip: 0,
                    stack_base,
                    has_func_slot: true, // function value at stack_base - 1
                });
                self.stack[func_idx] = VmValue::Unit;

                Ok(())
            }
            VmValue::Builtin(id) => {
                let start = self.stack.len() - argc;
                let args: Vec<VmValue> = self.stack.drain(start..).collect();
                self.stack.pop(); // remove function value
                self.call_builtin_with_args(id, &args)?;
                Ok(())
            }
            VmValue::Variant { name, fields } if fields.is_empty() => {
                let start = self.stack.len() - argc;
                let args: Vec<VmValue> = self.stack.drain(start..).collect();
                self.stack.pop(); // remove function value
                self.stack.push(VmValue::Variant {
                    name,
                    fields: Arc::new(args),
                });
                Ok(())
            }
            VmValue::Continuation(cont) => {
                let start = self.stack.len() - argc;
                let args: Vec<VmValue> = self.stack.drain(start..).collect();
                self.stack.pop(); // remove function value
                let resume_value = args.into_iter().next().unwrap_or(VmValue::Unit);
                let result = self.call_continuation(&cont, resume_value)?;
                self.stack.push(result);
                Ok(())
            }
            _ => {
                let line = self.frames.last().map(|f| f.current_line()).unwrap_or(0);
                Err(VmError::new(format!("cannot call value: {func}"), line))
            }
        }
    }

    fn call_builtin_with_args(&mut self, id: BuiltinId, args: &[VmValue]) -> Result<(), VmError> {
        let func = self.builtins.get(id.0 as usize).map(|(_, f)| *f);
        if let Some(f) = func {
            match f(args) {
                Ok(val) => {
                    self.stack.push(val);
                    Ok(())
                }
                Err(msg) => {
                    let line = self.frames.last().map(|f| f.current_line()).unwrap_or(0);
                    Err(VmError::new(msg, line))
                }
            }
        } else {
            let line = self.frames.last().map(|f| f.current_line()).unwrap_or(0);
            Err(VmError::new(format!("unknown builtin: {}", id.0), line))
        }
    }

    // ── Builtin registration ──────────────────────────────────

    fn register_builtins(&mut self) {
        self.register_builtin("print", |args| {
            if let Some(val) = args.first() {
                print!("{val}");
            }
            Ok(VmValue::Unit)
        });
        self.register_builtin("println", |args| {
            if let Some(val) = args.first() {
                println!("{val}");
            } else {
                println!();
            }
            Ok(VmValue::Unit)
        });
        self.register_builtin("to_string", |args| {
            let val = args.first().cloned().unwrap_or(VmValue::Unit);
            Ok(VmValue::String(Arc::new(format!("{val}"))))
        });
        self.register_builtin("len", |args| match args.first() {
            Some(VmValue::List(l)) => Ok(VmValue::Int(l.len() as i64)),
            Some(VmValue::String(s)) => Ok(VmValue::Int(s.len() as i64)),
            _ => Ok(VmValue::Int(0)),
        });
        self.register_builtin("is_empty", |args| match args.first() {
            Some(VmValue::List(l)) => Ok(VmValue::Bool(l.is_empty())),
            _ => Ok(VmValue::Bool(true)),
        });
        self.register_builtin("push", |args| {
            if let (Some(VmValue::List(list)), Some(elem)) = (args.first(), args.get(1)) {
                let mut v = (**list).clone();
                v.push(elem.clone());
                Ok(VmValue::List(Arc::new(v)))
            } else {
                Ok(VmValue::Unit)
            }
        });
        self.register_builtin("range", |args| {
            if let (Some(VmValue::Int(start)), Some(VmValue::Int(end))) =
                (args.first(), args.get(1))
            {
                let list: Vec<VmValue> = (*start..*end).map(VmValue::Int).collect();
                Ok(VmValue::List(Arc::new(list)))
            } else {
                Ok(VmValue::List(Arc::new(Vec::new())))
            }
        });
        self.register_builtin("abs", |args| match args.first() {
            Some(VmValue::Int(n)) => Ok(VmValue::Int(n.abs())),
            Some(VmValue::Float(n)) => Ok(VmValue::Float(n.abs())),
            _ => Ok(VmValue::Int(0)),
        });
        self.register_builtin("min", |args| {
            if let (Some(VmValue::Int(a)), Some(VmValue::Int(b))) = (args.first(), args.get(1)) {
                Ok(VmValue::Int(*a.min(b)))
            } else {
                Ok(VmValue::Int(0))
            }
        });
        self.register_builtin("max", |args| {
            if let (Some(VmValue::Int(a)), Some(VmValue::Int(b))) = (args.first(), args.get(1)) {
                Ok(VmValue::Int(*a.max(b)))
            } else {
                Ok(VmValue::Int(0))
            }
        });
        self.register_builtin("parse_int", |args| match args.first() {
            Some(VmValue::String(s)) => match s.parse::<i64>() {
                Ok(n) => Ok(VmValue::Int(n)),
                Err(_) => Ok(VmValue::Int(0)),
            },
            _ => Ok(VmValue::Int(0)),
        });
        self.register_builtin("string_length", |args| match args.first() {
            Some(VmValue::String(s)) => Ok(VmValue::Int(s.len() as i64)),
            _ => Ok(VmValue::Int(0)),
        });
        self.register_builtin("slice", |args| {
            match (args.first(), args.get(1), args.get(2)) {
                (
                    Some(VmValue::List(items)),
                    Some(VmValue::Int(start)),
                    Some(VmValue::Int(end)),
                ) => {
                    let len = items.len() as i64;
                    let s = (*start).max(0).min(len) as usize;
                    let e = (*end).max(0).min(len) as usize;
                    let slice = items[s..e].to_vec();
                    Ok(VmValue::List(Arc::new(slice)))
                }
                _ => Err("slice expects (List, Int, Int)".into()),
            }
        });
        self.register_builtin("sort", |args| match args.first() {
            Some(VmValue::List(items)) => {
                let mut sorted = (**items).clone();
                sorted.sort_by(|a, b| match (a, b) {
                    (VmValue::Int(x), VmValue::Int(y)) => x.cmp(y),
                    (VmValue::Float(x), VmValue::Float(y)) => {
                        x.partial_cmp(y).unwrap_or(std::cmp::Ordering::Equal)
                    }
                    (VmValue::String(x), VmValue::String(y)) => x.cmp(y),
                    _ => std::cmp::Ordering::Equal,
                });
                Ok(VmValue::List(Arc::new(sorted)))
            }
            _ => Err("sort expects a list".into()),
        });
        self.register_builtin("zip", |args| match (args.first(), args.get(1)) {
            (Some(VmValue::List(a)), Some(VmValue::List(b))) => {
                let pairs: Vec<VmValue> = a
                    .iter()
                    .zip(b.iter())
                    .map(|(x, y)| VmValue::Tuple(Arc::new(vec![x.clone(), y.clone()])))
                    .collect();
                Ok(VmValue::List(Arc::new(pairs)))
            }
            _ => Err("zip expects two lists".into()),
        });
        self.register_builtin("enumerate", |args| match args.first() {
            Some(VmValue::List(items)) => {
                let pairs: Vec<VmValue> = items
                    .iter()
                    .enumerate()
                    .map(|(i, v)| VmValue::Tuple(Arc::new(vec![VmValue::Int(i as i64), v.clone()])))
                    .collect();
                Ok(VmValue::List(Arc::new(pairs)))
            }
            _ => Err("enumerate expects a list".into()),
        });
        self.register_builtin("split", |args| match (args.first(), args.get(1)) {
            (Some(VmValue::String(s)), Some(VmValue::String(sep))) => {
                let parts: Vec<VmValue> = s
                    .split(sep.as_str())
                    .map(|p| VmValue::String(Arc::new(p.to_string())))
                    .collect();
                Ok(VmValue::List(Arc::new(parts)))
            }
            _ => Err("split expects two strings".into()),
        });
        self.register_builtin("trim", |args| match args.first() {
            Some(VmValue::String(s)) => Ok(VmValue::String(Arc::new(s.trim().to_string()))),
            _ => Err("trim expects a string".into()),
        });
        self.register_builtin("contains", |args| match (args.first(), args.get(1)) {
            (Some(VmValue::String(s)), Some(VmValue::String(sub))) => {
                Ok(VmValue::Bool(s.contains(sub.as_str())))
            }
            (Some(VmValue::List(items)), Some(val)) => Ok(VmValue::Bool(items.contains(val))),
            _ => Err("contains expects (String, String) or (List, value)".into()),
        });
        self.register_builtin("starts_with", |args| match (args.first(), args.get(1)) {
            (Some(VmValue::String(s)), Some(VmValue::String(prefix))) => {
                Ok(VmValue::Bool(s.starts_with(prefix.as_str())))
            }
            _ => Err("starts_with expects two strings".into()),
        });
        self.register_builtin("replace", |args| {
            match (args.first(), args.get(1), args.get(2)) {
                (
                    Some(VmValue::String(s)),
                    Some(VmValue::String(from)),
                    Some(VmValue::String(to)),
                ) => Ok(VmValue::String(Arc::new(
                    s.replace(from.as_str(), to.as_str()),
                ))),
                _ => Err("replace expects three strings".into()),
            }
        });
        self.register_builtin("chars", |args| match args.first() {
            Some(VmValue::String(s)) => {
                let chars: Vec<VmValue> = s
                    .chars()
                    .map(|c| VmValue::String(Arc::new(c.to_string())))
                    .collect();
                Ok(VmValue::List(Arc::new(chars)))
            }
            _ => Err("chars expects a string".into()),
        });
        self.register_builtin("join", |args| match (args.first(), args.get(1)) {
            (Some(VmValue::List(items)), Some(VmValue::String(sep))) => {
                let strings: Vec<String> = items
                    .iter()
                    .map(|v| match v {
                        VmValue::String(s) => (**s).clone(),
                        other => format!("{other}"),
                    })
                    .collect();
                Ok(VmValue::String(Arc::new(strings.join(sep.as_str()))))
            }
            _ => Err("join expects a list and string".into()),
        });
        self.register_builtin("floor", |args| match args.first() {
            Some(VmValue::Float(f)) => Ok(VmValue::Int(f.floor() as i64)),
            Some(VmValue::Int(n)) => Ok(VmValue::Int(*n)),
            _ => Err("floor expects a number".into()),
        });
        self.register_builtin("ceil", |args| match args.first() {
            Some(VmValue::Float(f)) => Ok(VmValue::Int(f.ceil() as i64)),
            Some(VmValue::Int(n)) => Ok(VmValue::Int(*n)),
            _ => Err("ceil expects a number".into()),
        });
        self.register_builtin("__assert_fail", |args| {
            let msg = match args.first() {
                Some(VmValue::String(s)) => (**s).clone(),
                Some(v) => format!("{v}"),
                None => "assertion failed".to_string(),
            };
            Err(format!("assertion failed: {msg}"))
        });
    }

    fn register_builtin(&mut self, name: &str, func: BuiltinFn) {
        let id = BuiltinId(self.builtins.len() as u16);
        self.builtins.push((name.to_string(), func));
        self.builtin_map.insert(name.to_string(), id);
    }
}
