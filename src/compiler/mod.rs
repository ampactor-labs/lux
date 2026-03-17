//! Bytecode compiler for Lux.
//!
//! Single-pass compilation from AST to bytecode chunks. Resolves names
//! to slot indices at compile time — no string hashing at runtime.
//!
//! Build order: pure expressions (6C-2) → closures/calls (6C-4) → effects (6C-5/6)

mod compiler;
mod patterns;
mod scope;

pub use compiler::compile;
