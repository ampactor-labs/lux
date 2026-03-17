//! Bytecode virtual machine for Lux.
//!
//! Stack-based VM with signal-based algebraic effects. Direct mechanical
//! translation of the tree-walking interpreter into bytecode for 10-100x
//! speedup while preserving identical semantics.
//!
//! Architecture: `source → lex → parse → check → compile → vm::run`

pub mod chunk;
pub mod error;
pub mod frame;
pub mod opcode;
pub mod value;
pub mod vm;
