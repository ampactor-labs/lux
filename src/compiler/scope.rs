//! Lexical scope tracking for the bytecode compiler.
//!
//! Resolves variable names to u16 slot indices at compile time.
//! Handles nested scopes (blocks, functions) and upvalue capture.

/// A local variable in the current scope.
#[derive(Debug, Clone)]
pub struct LocalVar {
    pub name: String,
    pub slot: u16,
    pub depth: u32,
    /// Whether this local has been captured as an upvalue by a nested function.
    pub is_captured: bool,
}

/// An upvalue descriptor — how to capture a variable from an enclosing scope.
#[derive(Debug, Clone)]
pub struct Upvalue {
    /// If true, captured from the immediately enclosing function's locals.
    /// If false, captured from the enclosing function's upvalue array.
    pub is_local: bool,
    /// Index into the source (local slot or upvalue array).
    pub index: u16,
}

/// Scope tracker for the compiler.
///
/// Maintains a stack of local variables with depth tracking for nested
/// blocks. Each function gets its own `Scope`; upvalue resolution crosses
/// scope boundaries.
#[derive(Debug)]
pub struct Scope {
    pub locals: Vec<LocalVar>,
    pub upvalues: Vec<Upvalue>,
    pub scope_depth: u32,
    pub next_slot: u16,
    /// Enclosing scope (for upvalue resolution across function boundaries).
    pub enclosing: Option<Box<Scope>>,
}

impl Scope {
    pub fn new() -> Self {
        Self {
            locals: Vec::new(),
            upvalues: Vec::new(),
            scope_depth: 0,
            next_slot: 0,
            enclosing: None,
        }
    }

    /// Begin a new block scope.
    pub fn begin_scope(&mut self) {
        self.scope_depth += 1;
    }

    /// End a block scope, returning the number of locals to pop.
    pub fn end_scope(&mut self) -> u16 {
        self.scope_depth -= 1;
        let mut count = 0u16;
        while let Some(local) = self.locals.last() {
            if local.depth <= self.scope_depth {
                break;
            }
            self.locals.pop();
            count += 1;
        }
        self.next_slot -= count;
        count
    }

    /// Declare a local variable, returning its slot index.
    pub fn declare_local(&mut self, name: &str) -> u16 {
        let slot = self.next_slot;
        self.locals.push(LocalVar {
            name: name.to_string(),
            slot,
            depth: self.scope_depth,
            is_captured: false,
        });
        self.next_slot += 1;
        slot
    }

    /// Resolve a name to a local variable slot.
    pub fn resolve_local(&self, name: &str) -> Option<u16> {
        // Search from most recent (innermost) to oldest (outermost)
        for local in self.locals.iter().rev() {
            if local.name == name {
                return Some(local.slot);
            }
        }
        None
    }

    /// Resolve a name to an upvalue index, capturing from enclosing scopes.
    pub fn resolve_upvalue(&mut self, name: &str) -> Option<u16> {
        let Some(enclosing) = &mut self.enclosing else {
            return None;
        };

        // Check enclosing function's locals first
        if let Some(local_slot) = enclosing.resolve_local(name) {
            // Mark the local as captured
            for local in &mut enclosing.locals {
                if local.name == name {
                    local.is_captured = true;
                    break;
                }
            }
            return Some(self.add_upvalue(true, local_slot));
        }

        // Check enclosing function's upvalues (transitive capture)
        if let Some(upval_idx) = enclosing.resolve_upvalue(name) {
            return Some(self.add_upvalue(false, upval_idx));
        }

        None
    }

    /// Add an upvalue descriptor, deduplicating.
    fn add_upvalue(&mut self, is_local: bool, index: u16) -> u16 {
        // Check if already captured
        for (i, uv) in self.upvalues.iter().enumerate() {
            if uv.is_local == is_local && uv.index == index {
                return i as u16;
            }
        }
        let idx = self.upvalues.len() as u16;
        self.upvalues.push(Upvalue { is_local, index });
        idx
    }

    /// Current number of local slots used (for FnProto.local_count).
    pub fn local_count(&self) -> u16 {
        self.next_slot
    }
}
