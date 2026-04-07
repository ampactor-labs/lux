//! Bytecode chunks — compiled units of Lux code.
//!
//! A `Chunk` holds the instruction stream, constant pool, interned names,
//! and handler tables for a single compilation unit (function body or
//! top-level script).

use std::collections::HashMap;
use std::sync::Arc;

use super::opcode::OpCode;

/// A constant value in the constant pool.
#[derive(Debug, Clone)]
pub enum Constant {
    Int(i64),
    Float(f64),
    String(Arc<String>),
    /// A compiled function prototype (not yet a closure).
    FnProto(Arc<FnProto>),
}

/// A compiled function — bytecode + metadata, not yet a closure.
///
/// Becomes a `Closure` when combined with captured upvalues at runtime
/// via the `MakeClosure` instruction.
#[derive(Debug)]
pub struct FnProto {
    pub chunk: Chunk,
    pub arity: u16,
    pub local_count: u16,
    pub upval_count: u16,
    pub name: Option<String>,
    /// Variant name → ordered field names, for FieldAccess resolution at runtime.
    pub field_registry: HashMap<String, Vec<String>>,
}

/// Handler table entry — maps effect operations to handler body FnProtos.
#[derive(Debug, Clone)]
pub struct HandlerEntry {
    /// Name index of the effect operation (in the chunk's name table).
    pub op_name_idx: u16,
    /// Index into the chunk's constant pool (a `FnProto` for the handler body).
    pub proto_idx: u16,
    /// Number of effect operation parameters (not including state vars).
    pub param_count: u8,
    /// True if handler body is tail-resumptive (skip continuation capture).
    pub tail_resumptive: bool,
    /// True if handler body is evidence-eligible (can use direct call dispatch).
    pub evidence_eligible: bool,
    /// Upvalue descriptors for capturing enclosing locals into handler body.
    /// Each entry is `(is_local, index)` — same semantics as closure upvalues.
    pub upvalue_descs: Vec<(bool, u16)>,
}

/// Handler table — all handler clauses for one `handle { ... }` expression.
#[derive(Debug, Clone)]
pub struct HandlerTable {
    pub entries: Vec<HandlerEntry>,
}

/// A unit of compiled bytecode.
///
/// The instruction stream, constant pool, and name table form the complete
/// compiled representation of a function or top-level script.
#[derive(Debug)]
pub struct Chunk {
    /// Instruction stream (opcodes + inline operands).
    pub code: Vec<u8>,
    /// Source line numbers, parallel to `code` (one per byte for simplicity).
    pub lines: Vec<u32>,
    /// Constant pool (literals, function prototypes).
    pub constants: Vec<Constant>,
    /// Interned string table (variable names, effect op names, variant names).
    pub names: Vec<String>,
    /// Handler tables for `handle { ... }` expressions in this chunk.
    pub handler_tables: Vec<HandlerTable>,
    /// Debug name for this chunk ("main", function name, etc.).
    pub name: String,
}

impl Chunk {
    /// Create a new empty chunk with the given debug name.
    pub fn new(name: impl Into<String>) -> Self {
        Self {
            code: Vec::new(),
            lines: Vec::new(),
            constants: Vec::new(),
            names: Vec::new(),
            handler_tables: Vec::new(),
            name: name.into(),
        }
    }

    /// Emit a single byte (opcode or operand).
    pub fn emit(&mut self, byte: u8, line: u32) {
        self.code.push(byte);
        self.lines.push(line);
    }

    /// Emit an opcode.
    pub fn emit_op(&mut self, op: OpCode, line: u32) {
        self.emit(op.as_byte(), line);
    }

    /// Emit a u16 operand in big-endian.
    pub fn emit_u16(&mut self, val: u16, line: u32) {
        self.emit((val >> 8) as u8, line);
        self.emit((val & 0xFF) as u8, line);
    }

    /// Emit an i16 operand in big-endian.
    pub fn emit_i16(&mut self, val: i16, line: u32) {
        self.emit_u16(val as u16, line);
    }

    /// Current code offset (for jump patching).
    pub fn current_offset(&self) -> usize {
        self.code.len()
    }

    /// Patch a previously emitted i16 at the given offset.
    pub fn patch_i16(&mut self, offset: usize, val: i16) {
        let bytes = (val as u16).to_be_bytes();
        self.code[offset] = bytes[0];
        self.code[offset + 1] = bytes[1];
    }

    /// Read a u16 from code at the given offset.
    pub fn read_u16(&self, offset: usize) -> u16 {
        ((self.code[offset] as u16) << 8) | (self.code[offset + 1] as u16)
    }

    /// Read an i16 from code at the given offset.
    pub fn read_i16(&self, offset: usize) -> i16 {
        self.read_u16(offset) as i16
    }

    /// Add a constant to the pool, returning its index.
    pub fn add_constant(&mut self, constant: Constant) -> u16 {
        let idx = self.constants.len();
        self.constants.push(constant);
        idx as u16
    }

    /// Intern a name string, returning its index. Deduplicates.
    pub fn intern_name(&mut self, name: &str) -> u16 {
        if let Some(idx) = self.names.iter().position(|n| n == name) {
            return idx as u16;
        }
        let idx = self.names.len();
        self.names.push(name.to_string());
        idx as u16
    }

    /// Disassemble the chunk to a human-readable string.
    pub fn disassemble(&self) -> String {
        let mut out = format!("=== {} ===\n", self.name);
        let mut offset = 0;
        while offset < self.code.len() {
            let line = self.lines.get(offset).copied().unwrap_or(0);
            let start = offset;
            let byte = self.code[offset];
            offset += 1;

            let Some(op) = OpCode::from_byte(byte) else {
                out.push_str(&format!("{start:04}  {line:4} | UNKNOWN({byte:#04x})\n"));
                continue;
            };

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
                | OpCode::PopEvidence
                | OpCode::BreakLoop
                | OpCode::ContinueLoop => {
                    out.push_str(&format!("{start:04}  {line:4} | {op:?}\n"));
                }
                // u8 operand
                OpCode::LoadBool => {
                    let val = self.code[offset];
                    offset += 1;
                    out.push_str(&format!("{start:04}  {line:4} | {op:?} {val}\n"));
                }
                OpCode::LoadInt => {
                    let val = self.code[offset] as i8;
                    offset += 1;
                    out.push_str(&format!("{start:04}  {line:4} | {op:?} {val}\n"));
                }
                OpCode::Call | OpCode::TailCall => {
                    let argc = self.code[offset];
                    offset += 1;
                    out.push_str(&format!("{start:04}  {line:4} | {op:?} argc={argc}\n"));
                }
                OpCode::BundleEvidence => {
                    let argc = self.code[offset];
                    offset += 1;
                    out.push_str(&format!("{start:04}  {line:4} | {op:?} argc={argc}\n"));
                }
                OpCode::Resume => {
                    let count = self.code[offset];
                    offset += 1;
                    let mut offsets = Vec::new();
                    for _ in 0..count {
                        let off = self.read_u16(offset);
                        offset += 2;
                        offsets.push(off);
                    }
                    out.push_str(&format!(
                        "{start:04}  {line:4} | {op:?} state_updates={count} offsets={offsets:?}\n"
                    ));
                }
                // u16 operand
                OpCode::LoadConst
                | OpCode::LoadLocal
                | OpCode::StoreLocal
                | OpCode::LoadUpval
                | OpCode::LoadGlobal
                | OpCode::StoreGlobal
                | OpCode::MakeList
                | OpCode::MakeTuple
                | OpCode::Prism
                | OpCode::FieldAccess
                | OpCode::MatchString
                | OpCode::MatchVariant
                | OpCode::MatchTuple
                | OpCode::MatchListCons
                | OpCode::MatchListExact
                | OpCode::BindLocal
                | OpCode::StringInterp => {
                    let idx = self.read_u16(offset);
                    offset += 2;
                    let extra = self.describe_operand(op, idx);
                    out.push_str(&format!("{start:04}  {line:4} | {op:?} {idx}{extra}\n"));
                }
                // i16 operand (jumps)
                OpCode::Jump | OpCode::JumpIfFalse | OpCode::JumpIfTrue => {
                    let off = self.read_i16(offset);
                    offset += 2;
                    let target = (offset as i32 + off as i32) as usize;
                    out.push_str(&format!(
                        "{start:04}  {line:4} | {op:?} {off:+} (-> {target:04})\n"
                    ));
                }
                // u16 constant index for MatchInt
                OpCode::MatchInt => {
                    let idx = self.read_u16(offset);
                    offset += 2;
                    let desc = if let Some(Constant::Int(n)) = self.constants.get(idx as usize) {
                        format!(" (= {n})")
                    } else {
                        String::new()
                    };
                    out.push_str(&format!(
                        "{start:04}  {line:4} | {op:?} const[{idx}]{desc}\n"
                    ));
                }
                OpCode::MatchBool => {
                    let val = self.code[offset];
                    offset += 1;
                    let b = val != 0;
                    out.push_str(&format!("{start:04}  {line:4} | {op:?} {b}\n"));
                }
                // MakeClosure: u16 proto idx + N upvalue descriptors
                OpCode::MakeClosure => {
                    let proto_idx = self.read_u16(offset);
                    offset += 2;
                    let upval_count = if let Some(Constant::FnProto(p)) =
                        self.constants.get(proto_idx as usize)
                    {
                        p.upval_count
                    } else {
                        0
                    };
                    out.push_str(&format!(
                        "{start:04}  {line:4} | {op:?} proto[{proto_idx}] upvals={upval_count}\n"
                    ));
                    for _ in 0..upval_count {
                        let is_local = self.code[offset];
                        offset += 1;
                        let idx = self.read_u16(offset);
                        offset += 2;
                        let kind = if is_local != 0 { "local" } else { "upval" };
                        out.push_str(&format!("      |   {kind}[{idx}]\n"));
                    }
                }
                // CallBuiltin: u16 id + u8 argc
                OpCode::CallBuiltin => {
                    let id = self.read_u16(offset);
                    offset += 2;
                    let argc = self.code[offset];
                    offset += 1;
                    out.push_str(&format!(
                        "{start:04}  {line:4} | {op:?} builtin={id} argc={argc}\n"
                    ));
                }
                // MakeVariant: u16 name idx + u16 field count
                OpCode::MakeVariant => {
                    let name_idx = self.read_u16(offset);
                    offset += 2;
                    let field_count = self.read_u16(offset);
                    offset += 2;
                    let name = self
                        .names
                        .get(name_idx as usize)
                        .cloned()
                        .unwrap_or_default();
                    out.push_str(&format!(
                        "{start:04}  {line:4} | {op:?} {name} fields={field_count}\n"
                    ));
                }
                // Perform: u16 op name idx + u8 argc
                OpCode::Perform => {
                    let name_idx = self.read_u16(offset);
                    offset += 2;
                    let argc = self.code[offset];
                    offset += 1;
                    let name = self
                        .names
                        .get(name_idx as usize)
                        .cloned()
                        .unwrap_or_default();
                    out.push_str(&format!(
                        "{start:04}  {line:4} | {op:?} {name} argc={argc}\n"
                    ));
                }
                // PushHandler: u16 table idx + u16 state base + u8 state count
                OpCode::PushHandler => {
                    let table_idx = self.read_u16(offset);
                    offset += 2;
                    let state_base = self.read_u16(offset);
                    offset += 2;
                    let state_count = self.code[offset];
                    offset += 1;
                    out.push_str(&format!(
                        "{start:04}  {line:4} | {op:?} table={table_idx} state_base={state_base} state_count={state_count}\n"
                    ));
                }
                // PushEvidence: u16 table idx + u16 ev_local
                OpCode::PushEvidence => {
                    let table_idx = self.read_u16(offset);
                    offset += 2;
                    let ev_local = self.read_u16(offset);
                    offset += 2;
                    out.push_str(&format!(
                        "{start:04}  {line:4} | {op:?} table={table_idx} ev_local={ev_local}\n"
                    ));
                }
                // PerformEvidence: u16 ev_local + u16 op_name_idx + u8 argc
                OpCode::PerformEvidence => {
                    let ev_local = self.read_u16(offset);
                    offset += 2;
                    let name_idx = self.read_u16(offset);
                    offset += 2;
                    let argc = self.code[offset];
                    offset += 1;
                    let name = self
                        .names
                        .get(name_idx as usize)
                        .cloned()
                        .unwrap_or_default();
                    out.push_str(&format!(
                        "{start:04}  {line:4} | {op:?} ev_local={ev_local} {name} argc={argc}\n"
                    ));
                }
            }
        }
        out
    }

    /// Describe an operand for disassembly output.
    fn describe_operand(&self, op: OpCode, idx: u16) -> String {
        match op {
            OpCode::LoadConst => match self.constants.get(idx as usize) {
                Some(Constant::Int(n)) => format!(" (= {n})"),
                Some(Constant::Float(n)) => format!(" (= {n})"),
                Some(Constant::String(s)) => format!(" (= \"{s}\")"),
                Some(Constant::FnProto(p)) => {
                    let name = p.name.as_deref().unwrap_or("<anon>");
                    format!(" (= fn {name})")
                }
                None => String::new(),
            },
            OpCode::LoadGlobal | OpCode::StoreGlobal | OpCode::FieldAccess => {
                match self.names.get(idx as usize) {
                    Some(name) => format!(" ({name})"),
                    None => String::new(),
                }
            }
            _ => String::new(),
        }
    }
}
