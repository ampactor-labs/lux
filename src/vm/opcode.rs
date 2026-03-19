//! Bytecode opcodes for the Lux VM.
//!
//! All opcodes are a single `u8`. Multi-byte operands follow in big-endian.
//! Categories: literals, locals, globals, arithmetic, comparison,
//! control flow, functions, collections, patterns, effects, loops.

/// Single-byte opcodes for the Lux VM instruction set.
///
/// Operand conventions:
/// - `u8` operands follow immediately after the opcode byte
/// - `u16` operands are big-endian (high byte first)
/// - "idx" means an index into the chunk's constant/name table
#[derive(Debug, Clone, Copy, PartialEq, Eq)]
#[repr(u8)]
pub enum OpCode {
    // ── Literals ──────────────────────────────────────────
    /// Push constant from pool. Operand: u16 constant index.
    LoadConst = 0,
    /// Push small integer (-128..127). Operand: i8.
    LoadInt = 1,
    /// Push `true` or `false`. Operand: u8 (0=false, 1=true).
    LoadBool = 2,
    /// Push `()`.
    LoadUnit = 3,

    // ── Locals ────────────────────────────────────────────
    /// Push local variable. Operand: u16 slot index.
    LoadLocal = 10,
    /// Store top-of-stack into local. Operand: u16 slot index.
    StoreLocal = 11,
    /// Push captured upvalue. Operand: u16 upvalue index.
    LoadUpval = 12,

    // ── Globals ───────────────────────────────────────────
    /// Push global by name index. Operand: u16 name index.
    LoadGlobal = 20,
    /// Store top-of-stack as global. Operand: u16 name index.
    StoreGlobal = 21,

    // ── Arithmetic ────────────────────────────────────────
    Add = 30,
    Sub = 31,
    Mul = 32,
    Div = 33,
    Mod = 34,
    Neg = 35,
    Not = 36,

    // ── Comparison ────────────────────────────────────────
    Eq = 40,
    Neq = 41,
    Lt = 42,
    LtEq = 43,
    Gt = 44,
    GtEq = 45,

    // ── String/List ───────────────────────────────────────
    /// Concatenate two strings or lists.
    Concat = 50,

    // ── Control flow ──────────────────────────────────────
    /// Unconditional jump. Operand: i16 offset (signed, relative to AFTER this instruction).
    Jump = 60,
    /// Jump if top-of-stack is false. Pops condition. Operand: i16 offset.
    JumpIfFalse = 61,
    /// Jump if top-of-stack is true. Pops condition. Operand: i16 offset.
    JumpIfTrue = 62,
    /// Pop top-of-stack.
    Pop = 63,
    /// Duplicate top-of-stack.
    Dup = 64,

    // ── Functions ─────────────────────────────────────────
    /// Create closure from FnProto. Operand: u16 constant index (FnProto),
    /// followed by N upvalue descriptors (is_local: u8, index: u16).
    MakeClosure = 70,
    /// Call function. Operand: u8 arg count.
    Call = 71,
    /// Return from function.
    Return = 72,
    /// Tail call. Operand: u8 arg count.
    TailCall = 73,
    /// Call builtin function. Operand: u16 builtin id, u8 arg count.
    CallBuiltin = 74,

    // ── Collections ───────────────────────────────────────
    /// Create list from N stack values. Operand: u16 element count.
    MakeList = 80,
    /// Create tuple from N stack values. Operand: u16 element count.
    MakeTuple = 81,
    /// Index into list. Stack: \[list, index\] → element.
    ListIndex = 82,
    /// Access field by name. Operand: u16 name index.
    FieldAccess = 83,
    /// Create ADT variant. Operand: u16 name index, u16 field count.
    MakeVariant = 84,

    // ── Patterns ──────────────────────────────────────────
    /// Match integer. Operand: i64 via constant. Pushes bool.
    MatchInt = 90,
    /// Match boolean. Operand: u8 (0=false, 1=true). Pushes bool.
    MatchBool = 91,
    /// Match string via constant index. Operand: u16. Pushes bool.
    MatchString = 92,
    /// Match variant by name. Operand: u16 name index. Pushes bool.
    MatchVariant = 93,
    /// Match tuple with N elements. Operand: u16 count. Pushes bool.
    MatchTuple = 94,
    /// Match list cons (head :: tail). Operand: u16 min elements. Pushes bool.
    MatchListCons = 95,
    /// Match empty list. Pushes bool.
    MatchListEmpty = 96,
    /// Always matches (wildcard). Pushes true.
    MatchWildcard = 97,
    /// Bind matched value to local slot. Operand: u16 slot.
    BindLocal = 98,
    /// Match list with exactly N elements. Operand: u16 count. Pushes bool.
    MatchListExact = 99,

    // ── Effects ───────────────────────────────────────────
    /// Perform effect operation. Operand: u16 op name index, u8 arg count.
    Perform = 110,
    /// Push handler frame. Operand: u16 handler table index,
    /// u16 state slot base, u8 state count.
    PushHandler = 111,
    /// Pop handler frame.
    PopHandler = 112,
    /// Resume from handler. Operand: u8 state update count.
    Resume = 113,
    /// Create continuation value.
    MakeContinuation = 114,

    // ── Loops ─────────────────────────────────────────────
    /// Break out of loop. Pops to loop boundary.
    BreakLoop = 120,
    /// Continue loop. Jumps to loop header.
    ContinueLoop = 121,

    // ── Misc ──────────────────────────────────────────────
    /// Build interpolated string from N parts. Operand: u16 part count.
    StringInterp = 130,
}

impl OpCode {
    /// Decode a byte into an opcode, returning None for unknown values.
    pub fn from_byte(byte: u8) -> Option<Self> {
        // Safety: we validate the byte matches a known variant
        match byte {
            0 => Some(Self::LoadConst),
            1 => Some(Self::LoadInt),
            2 => Some(Self::LoadBool),
            3 => Some(Self::LoadUnit),
            10 => Some(Self::LoadLocal),
            11 => Some(Self::StoreLocal),
            12 => Some(Self::LoadUpval),
            20 => Some(Self::LoadGlobal),
            21 => Some(Self::StoreGlobal),
            30 => Some(Self::Add),
            31 => Some(Self::Sub),
            32 => Some(Self::Mul),
            33 => Some(Self::Div),
            34 => Some(Self::Mod),
            35 => Some(Self::Neg),
            36 => Some(Self::Not),
            40 => Some(Self::Eq),
            41 => Some(Self::Neq),
            42 => Some(Self::Lt),
            43 => Some(Self::LtEq),
            44 => Some(Self::Gt),
            45 => Some(Self::GtEq),
            50 => Some(Self::Concat),
            60 => Some(Self::Jump),
            61 => Some(Self::JumpIfFalse),
            62 => Some(Self::JumpIfTrue),
            63 => Some(Self::Pop),
            64 => Some(Self::Dup),
            70 => Some(Self::MakeClosure),
            71 => Some(Self::Call),
            72 => Some(Self::Return),
            73 => Some(Self::TailCall),
            74 => Some(Self::CallBuiltin),
            80 => Some(Self::MakeList),
            81 => Some(Self::MakeTuple),
            82 => Some(Self::ListIndex),
            83 => Some(Self::FieldAccess),
            84 => Some(Self::MakeVariant),
            90 => Some(Self::MatchInt),
            91 => Some(Self::MatchBool),
            92 => Some(Self::MatchString),
            93 => Some(Self::MatchVariant),
            94 => Some(Self::MatchTuple),
            95 => Some(Self::MatchListCons),
            96 => Some(Self::MatchListEmpty),
            97 => Some(Self::MatchWildcard),
            98 => Some(Self::BindLocal),
            99 => Some(Self::MatchListExact),
            110 => Some(Self::Perform),
            111 => Some(Self::PushHandler),
            112 => Some(Self::PopHandler),
            113 => Some(Self::Resume),
            114 => Some(Self::MakeContinuation),
            120 => Some(Self::BreakLoop),
            121 => Some(Self::ContinueLoop),
            130 => Some(Self::StringInterp),
            _ => None,
        }
    }

    /// Encode this opcode as a byte.
    pub fn as_byte(self) -> u8 {
        self as u8
    }
}
