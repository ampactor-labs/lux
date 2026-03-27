/// Interactive REPL for the Lux language.
///
/// The self-hosted REPL (`std/repl.lux`) is the primary interface. This module
/// is retained as a stub for the fallback path only.
use crate::error::LuxError;

/// Start the interactive REPL.
///
/// The main entry point routes to the self-hosted `std/repl.lux`. This function
/// is only called when `std/repl.lux` cannot be found (see `main.rs`).
pub fn run() -> Result<(), LuxError> {
    Err(LuxError::Runtime(crate::error::RuntimeError {
        kind: crate::error::RuntimeErrorKind::Internal("std/repl.lux not found".to_string()),
        span: crate::token::Span::dummy(),
    }))
}
