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

/// Signature for VM builtin functions.
pub type BuiltinFn = fn(&[VmValue]) -> Result<VmValue, String>;

/// The Lux bytecode virtual machine.
pub struct Vm {
    /// Call frame stack.
    frames: Vec<CallFrame>,
    /// Value stack.
    stack: Vec<VmValue>,
    /// Effect handler stack.
    handler_stack: Vec<VmHandlerFrame>,
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
        };
        vm.register_builtins();
        vm
    }

    /// Run a compiled function prototype.
    pub fn run(&mut self, proto: Arc<FnProto>) -> Result<Option<VmValue>, VmError> {
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
        });

        let result = self.execute()?;

        // Clean up
        self.frames.pop();
        self.stack.truncate(stack_base);

        Ok(result)
    }

    /// Main execution loop.
    fn execute(&mut self) -> Result<Option<VmValue>, VmError> {
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
                    let frame = &self.frames[frame_idx];
                    let base = frame.stack_base;
                    self.stack.truncate(base);
                    self.frames.pop();
                    self.stack.push(result);
                }
                OpCode::CallBuiltin => {
                    let id = self.frames[frame_idx].read_u16();
                    let argc = self.frames[frame_idx].read_byte() as usize;
                    self.call_builtin(BuiltinId(id), argc)?;
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
                            // Field access by index on variants
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
                    let name = self.frames[frame_idx]
                        .proto
                        .chunk
                        .names
                        .get(name_idx as usize)
                        .cloned()
                        .unwrap_or_default();
                    let obj = self.stack.pop().unwrap_or(VmValue::Unit);
                    match &obj {
                        VmValue::Tuple(elems) => {
                            // Numeric field access: .0, .1, etc.
                            if let Ok(idx) = name.parse::<usize>() {
                                if idx < elems.len() {
                                    self.stack.push(elems[idx].clone());
                                } else {
                                    self.stack.push(VmValue::Unit);
                                }
                            } else {
                                self.stack.push(VmValue::Unit);
                            }
                        }
                        VmValue::Variant { fields, .. } => {
                            // Named field access — for now push Unit
                            // TODO: proper field name resolution
                            let _ = fields;
                            self.stack.push(VmValue::Unit);
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

                // ── Effects (placeholder) ─────────────────────────
                OpCode::Perform
                | OpCode::PushHandler
                | OpCode::PopHandler
                | OpCode::Resume
                | OpCode::MakeContinuation => {
                    // Placeholder — will be implemented in Phase 6C-5
                    let line = self.frames[frame_idx].current_line();
                    return Err(VmError::new("effects not yet implemented in VM", line));
                }

                // ── Loops ─────────────────────────────────────────
                OpCode::BreakLoop | OpCode::ContinueLoop => {
                    // These are handled by Jump instructions during compilation.
                    // If we get here, it's a compiler error.
                    let line = self.frames[frame_idx].current_line();
                    return Err(VmError::new("unexpected loop control opcode", line));
                }
            }
        }
    }

    // ── Helpers ───────────────────────────────────────────────

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
                // String comparison by lexicographic order
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

                // Set up new frame
                let stack_base = func_idx + 1; // args start after the function
                // Extend stack for local slots beyond parameters
                let extra_locals = closure.proto.local_count as usize - argc;
                for _ in 0..extra_locals {
                    self.stack.push(VmValue::Unit);
                }

                self.frames.push(CallFrame {
                    proto: closure.proto.clone(),
                    upvalues: closure.upvalues.clone(),
                    ip: 0,
                    stack_base,
                });
                // Remove the function value from below args
                // Actually the function is at func_idx, args are at func_idx+1..
                // The stack_base points at the first arg. We need to remove the
                // function slot. For simplicity, swap it out.
                self.stack[func_idx] = VmValue::Unit;

                Ok(())
            }
            VmValue::Builtin(id) => {
                // Collect args
                let start = self.stack.len() - argc;
                let args: Vec<VmValue> = self.stack.drain(start..).collect();
                self.stack.pop(); // remove function value
                self.call_builtin(id, argc)?;
                // call_builtin already pushed args back... actually let's fix this.
                // We already drained args, so re-push them and call.
                for arg in &args {
                    self.stack.push(arg.clone());
                }
                self.call_builtin_with_args(id, &args)?;
                // Remove the pushed args
                self.stack.truncate(self.stack.len() - args.len());
                Ok(())
            }
            VmValue::Variant { name, fields } if fields.is_empty() => {
                // Constructor call — create variant with args as fields
                let start = self.stack.len() - argc;
                let args: Vec<VmValue> = self.stack.drain(start..).collect();
                self.stack.pop(); // remove function value
                self.stack.push(VmValue::Variant {
                    name,
                    fields: Arc::new(args),
                });
                Ok(())
            }
            _ => {
                let line = self.frames.last().map(|f| f.current_line()).unwrap_or(0);
                Err(VmError::new(format!("cannot call value: {func}"), line))
            }
        }
    }

    fn call_builtin(&mut self, _id: BuiltinId, _argc: usize) -> Result<(), VmError> {
        // Stub — actual builtin dispatch handled by call_builtin_with_args
        Ok(())
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
    }

    fn register_builtin(&mut self, name: &str, func: BuiltinFn) {
        let id = BuiltinId(self.builtins.len() as u16);
        self.builtins.push((name.to_string(), func));
        self.builtin_map.insert(name.to_string(), id);
    }
}
