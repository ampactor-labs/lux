//! VM runtime errors.

use std::fmt;

/// A runtime error from the VM.
#[derive(Debug)]
pub struct VmError {
    pub message: String,
    pub line: u32,
}

impl VmError {
    pub fn new(message: impl Into<String>, line: u32) -> Self {
        Self {
            message: message.into(),
            line,
        }
    }
}

impl fmt::Display for VmError {
    fn fmt(&self, f: &mut fmt::Formatter<'_>) -> fmt::Result {
        write!(f, "runtime error at line {}: {}", self.line, self.message)
    }
}

impl std::error::Error for VmError {}

impl From<VmError> for crate::error::LuxError {
    fn from(e: VmError) -> Self {
        crate::error::LuxError::Runtime(crate::error::RuntimeError {
            kind: crate::error::RuntimeErrorKind::Internal(e.message),
            span: crate::token::Span::new(0, 0, e.line as usize, 0),
        })
    }
}
