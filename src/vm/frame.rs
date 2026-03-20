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
    /// True if there's a function value slot at `stack_base - 1` that
    /// must be cleaned up on Return (frames pushed via `Call`).
    pub has_func_slot: bool,
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

/// A resolved handler entry — operation name + compiled handler body.
///
/// Created at `PushHandler` time by resolving the chunk's `HandlerTable`
/// entries to concrete strings and FnProtos. Stored in `VmHandlerFrame`
/// so that `Perform` can dispatch across frames (different chunks).
#[derive(Debug, Clone)]
pub struct VmHandlerEntry {
    /// Resolved effect operation name (e.g., "get", "set", "fail").
    pub op_name: String,
    /// Compiled handler body function prototype.
    pub proto: Arc<FnProto>,
    /// Number of effect operation parameters (not including state vars).
    pub param_count: u8,
    /// True if handler body is tail-resumptive (skip continuation capture).
    pub tail_resumptive: bool,
}

/// An active effect handler on the handler stack.
///
/// Tracks which effects are being handled, handler state variables,
/// and the execution context needed to dispatch and resume effects.
#[derive(Debug, Clone)]
pub struct VmHandlerFrame {
    /// Resolved handler entries (name + FnProto for each operation).
    pub entries: Vec<VmHandlerEntry>,
    /// Call frame index when the handler was pushed.
    pub frame_idx: usize,
    /// Stack height when the handler was pushed (for unwinding).
    pub stack_height: usize,
    /// Handler-local state values (updated by `Resume`).
    pub state: Vec<VmValue>,
    /// IP in the performing frame to resume at (set by `Perform`).
    pub resume_ip: usize,
    /// Frame index where `Perform` happened (set by `Perform`).
    pub resume_frame_idx: usize,
    /// Stack height at the `Perform` site after popping args (set by `Perform`).
    pub resume_stack_height: usize,
    /// IP of the handle body start (right after PushHandler operands).
    /// Used for multi-shot continuation replay.
    pub body_start_ip: usize,
    /// Stack snapshot at PushHandler time (for continuation replay).
    /// Captures locals from the enclosing frame's base to the handler's stack_height.
    pub stack_snapshot: Vec<VmValue>,
    /// Initial state values (snapshot at PushHandler time, for replay).
    pub initial_state: Vec<VmValue>,
}
