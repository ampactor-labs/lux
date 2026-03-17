//! Call frames and handler frames for the Lux VM.
//!
//! `CallFrame` tracks function execution state (instruction pointer, stack base).
//! `VmHandlerFrame` tracks algebraic effect handler state.

use std::sync::Arc;

use super::chunk::FnProto;
use super::value::VmValue;

/// A single call frame on the VM's call stack.
///
/// Each function invocation pushes a frame. The frame stores the return
/// address (instruction pointer), the stack base (where this function's
/// locals start), and the function prototype being executed.
#[derive(Debug)]
pub struct CallFrame {
    /// The function prototype being executed.
    pub proto: Arc<FnProto>,
    /// Captured upvalues for this closure invocation.
    pub upvalues: Vec<VmValue>,
    /// Instruction pointer — index into `proto.chunk.code`.
    pub ip: usize,
    /// Stack base — index into `Vm.stack` where this frame's locals start.
    pub stack_base: usize,
}

impl CallFrame {
    /// Read the next byte and advance IP.
    pub fn read_byte(&mut self) -> u8 {
        let byte = self.proto.chunk.code[self.ip];
        self.ip += 1;
        byte
    }

    /// Read a u16 (big-endian) and advance IP by 2.
    pub fn read_u16(&mut self) -> u16 {
        let val = self.proto.chunk.read_u16(self.ip);
        self.ip += 2;
        val
    }

    /// Read an i16 (big-endian) and advance IP by 2.
    pub fn read_i16(&mut self) -> i16 {
        let val = self.proto.chunk.read_i16(self.ip);
        self.ip += 2;
        val
    }

    /// Current source line for error reporting.
    pub fn current_line(&self) -> u32 {
        self.proto
            .chunk
            .lines
            .get(self.ip.saturating_sub(1))
            .copied()
            .unwrap_or(0)
    }
}

/// An active effect handler on the handler stack.
///
/// Tracks which effects are being handled, handler state variables,
/// and the execution context needed to dispatch and resume effects.
#[derive(Debug)]
pub struct VmHandlerFrame {
    /// Index into the chunk's handler table.
    pub handler_table_idx: u16,
    /// Call frame index when the handler was pushed.
    pub frame_idx: usize,
    /// Stack height when the handler was pushed (for unwinding).
    pub stack_height: usize,
    /// Handler-local state values.
    pub state: Vec<VmValue>,
    /// Instruction pointer to resume at after handler completes.
    pub resume_ip: usize,
}
