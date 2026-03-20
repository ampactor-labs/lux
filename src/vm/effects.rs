//! Effect dispatch for the Lux VM: PushHandler, Perform, Resume, PopHandler.
//!
//! Handler bodies are compiled as separate `FnProto`s. When `Perform` dispatches
//! to a handler, the VM pushes a new call frame for the handler body. `Resume`
//! unwinds back to the perform site and pushes the resume value.

use std::sync::Arc;

use super::chunk::{Constant, FnProto};
use super::error::VmError;
use super::frame::{CallFrame, VmHandlerEntry, VmHandlerFrame};
use super::value::{VmContinuation, VmValue};
use super::vm::Vm;

impl Vm {
    /// Process the `PushHandler` opcode.
    ///
    /// Reads handler table from the current chunk, resolves entries to
    /// concrete strings and FnProtos, copies state from stack locals,
    /// and pushes a `VmHandlerFrame` onto the handler stack.
    pub(super) fn op_push_handler(&mut self, frame_idx: usize) -> Result<(), VmError> {
        let table_idx = self.frames[frame_idx].read_u16() as usize;
        let _state_base = self.frames[frame_idx].read_u16() as usize;
        let state_count = self.frames[frame_idx].read_byte() as usize;

        // Pop state init values from the stack (pushed by compile_handle).
        let start = self.stack.len() - state_count;
        let state: Vec<VmValue> = self.stack.drain(start..).collect();

        // Resolve handler entries from the current chunk's handler table.
        let entries = self.resolve_handler_entries(frame_idx, table_idx)?;

        // Record body start IP (current position after reading PushHandler operands).
        let body_start_ip = self.frames[frame_idx].ip;

        // Capture stack snapshot at PushHandler time for continuation replay.
        // This is the "clean" state before the body modifies locals.
        let h_frame_idx = self.frames.len() - 1;
        let snap_base = self.frames[h_frame_idx].stack_base;
        let stack_snapshot = self.stack[snap_base..].to_vec();

        self.handler_stack.push(VmHandlerFrame {
            entries,
            frame_idx: h_frame_idx,
            stack_height: self.stack.len(),
            initial_state: state.clone(),
            state,
            resume_ip: 0,
            resume_frame_idx: 0,
            resume_stack_height: 0,
            body_start_ip,
            stack_snapshot,
        });

        Ok(())
    }

    /// Process the `PopHandler` opcode.
    pub(super) fn op_pop_handler(&mut self) {
        self.handler_stack.pop();
    }

    /// Process the `Perform` opcode.
    ///
    /// In replay mode, returns the next value from the replay log.
    /// Otherwise, pops effect args, searches the handler stack for a matching
    /// handler, saves resume state, and pushes a call frame for the handler body.
    /// For stateless handlers, creates a `VmContinuation` and passes it as `resume`.
    pub(super) fn op_perform(&mut self, frame_idx: usize) -> Result<(), VmError> {
        let op_name_idx = self.frames[frame_idx].read_u16();
        let argc = self.frames[frame_idx].read_byte() as usize;

        // Resolve the operation name from the current chunk.
        let op_name = self.frames[frame_idx]
            .proto
            .chunk
            .names
            .get(op_name_idx as usize)
            .cloned()
            .unwrap_or_default();

        // Pop effect arguments from the stack.
        let args_start = self.stack.len() - argc;
        let args: Vec<VmValue> = self.stack.drain(args_start..).collect();

        // Replay mode: consume from log if available.
        if let Some(ref log) = self.replay_log {
            if self.replay_pos < log.len() {
                let val = log[self.replay_pos].clone();
                self.replay_pos += 1;
                self.stack.push(val);
                return Ok(());
            }
        }

        // Normal dispatch: search handler stack for a matching handler.
        let found = self.find_handler(&op_name);

        if let Some((handler_idx, entry_idx)) = found {
            // Save resume state on the handler frame.
            let resume_ip = self.frames[frame_idx].ip;
            let resume_stack_height = self.stack.len();

            {
                let handler = &mut self.handler_stack[handler_idx];
                handler.resume_ip = resume_ip;
                handler.resume_frame_idx = frame_idx;
                handler.resume_stack_height = resume_stack_height;
            }

            // Determine if this handler is stateless (multi-shot capable).
            let is_stateless = self.handler_stack[handler_idx].state.is_empty();
            let is_tail_res = self.handler_stack[handler_idx].entries[entry_idx].tail_resumptive;

            // Build continuation for stateless, non-tail-resumptive handlers.
            // Tail-resumptive handlers never need a continuation — they always
            // resume with a direct value and cannot be re-entered.
            let continuation = if is_stateless && !is_tail_res {
                // Capture replay log so far (entries consumed before this perform).
                let replay_log_so_far = self
                    .replay_log
                    .as_ref()
                    .map(|log| log[..self.replay_pos].to_vec())
                    .unwrap_or_default();

                let h_frame_idx = self.handler_stack[handler_idx].frame_idx;
                let cont = VmContinuation {
                    replay_log: replay_log_so_far,
                    proto: self.frames[h_frame_idx].proto.clone(),
                    body_start_ip: self.handler_stack[handler_idx].body_start_ip,
                    handler_entries: self.handler_stack[handler_idx].entries.clone(),
                    initial_state: self.handler_stack[handler_idx].initial_state.clone(),
                    // Use the snapshot captured at PushHandler time (clean state
                    // before the body modified locals via block-scoped lets).
                    stack_snapshot: self.handler_stack[handler_idx].stack_snapshot.clone(),
                    upvalues: self.frames[h_frame_idx].upvalues.clone(),
                    outer_handler_stack: self.handler_stack[..handler_idx].to_vec(),
                    outer_frame_count: h_frame_idx,
                };
                Some(VmValue::Continuation(Arc::new(cont)))
            } else {
                None
            };

            // Get the handler proto and state.
            let proto = self.handler_stack[handler_idx].entries[entry_idx]
                .proto
                .clone();
            let state = self.handler_stack[handler_idx].state.clone();

            // Push call frame for the handler body.
            if let Some(cont) = continuation {
                self.dispatch_handler_body_with_resume(proto, &args, &state, cont)?;
            } else {
                self.dispatch_handler_body(proto, &args, &state)?;
            }

            // Track that we're in a handler dispatch (stack for nesting).
            self.handler_dispatch_stack
                .push((handler_idx, self.frames.len() - 1));

            Ok(())
        } else {
            let line = self.frames[frame_idx].current_line();
            Err(VmError::new(
                format!("unhandled effect operation: {op_name}"),
                line,
            ))
        }
    }

    /// Process the `Resume` opcode.
    ///
    /// Pops state update values and resume value from the stack, applies
    /// state updates to the handler frame, unwinds the handler body frame,
    /// and restores execution at the perform site with the resume value.
    pub(super) fn op_resume(&mut self, frame_idx: usize) -> Result<(), VmError> {
        let update_count = self.frames[frame_idx].read_byte() as usize;

        // Read state offset indices.
        let mut state_offsets = Vec::with_capacity(update_count);
        for _ in 0..update_count {
            state_offsets.push(self.frames[frame_idx].read_u16());
        }

        // Pop state update values (reverse order: last pushed = last offset).
        let mut update_values = Vec::with_capacity(update_count);
        for _ in 0..update_count {
            update_values.push(self.stack.pop().unwrap_or(VmValue::Unit));
        }
        update_values.reverse();

        // Pop resume value.
        let resume_value = self.stack.pop().unwrap_or(VmValue::Unit);

        if let Some((h_idx, body_frame_idx)) = self.handler_dispatch_stack.pop() {
            // Apply state updates to the handler frame.
            let handler = &mut self.handler_stack[h_idx];
            for (offset, value) in state_offsets.iter().zip(update_values.into_iter()) {
                let idx = *offset as usize;
                if idx < handler.state.len() {
                    handler.state[idx] = value;
                }
            }

            let resume_ip = handler.resume_ip;
            let resume_frame_idx = handler.resume_frame_idx;
            let resume_stack_height = handler.resume_stack_height;

            // Unwind all frames above and including the handler body frame.
            while self.frames.len() > body_frame_idx {
                let base = self.frames.last().unwrap().stack_base;
                self.stack.truncate(base);
                self.frames.pop();
            }

            // Restore stack to the perform site's height.
            self.stack.truncate(resume_stack_height);

            // Push resume value — this becomes the Perform expression's result.
            self.stack.push(resume_value);

            // Set IP in the performing frame to continue from after Perform.
            self.frames[resume_frame_idx].ip = resume_ip;

            Ok(())
        } else {
            let line = self.frames.last().map(|f| f.current_line()).unwrap_or(0);
            Err(VmError::new("resume outside of handler dispatch", line))
        }
    }

    /// Search the handler stack (top-down) for a handler matching `op_name`.
    /// Returns `(handler_stack_idx, entry_idx)`.
    fn find_handler(&self, op_name: &str) -> Option<(usize, usize)> {
        for (h_idx, frame) in self.handler_stack.iter().enumerate().rev() {
            for (e_idx, entry) in frame.entries.iter().enumerate() {
                if entry.op_name == op_name {
                    return Some((h_idx, e_idx));
                }
            }
        }
        None
    }

    /// Resolve handler table entries from the current chunk.
    fn resolve_handler_entries(
        &self,
        frame_idx: usize,
        table_idx: usize,
    ) -> Result<Vec<VmHandlerEntry>, VmError> {
        let chunk = &self.frames[frame_idx].proto.chunk;
        let table = chunk.handler_tables.get(table_idx).ok_or_else(|| {
            VmError::new(
                format!("invalid handler table index: {table_idx}"),
                self.frames[frame_idx].current_line(),
            )
        })?;

        let mut entries = Vec::with_capacity(table.entries.len());
        for entry in &table.entries {
            let op_name = chunk
                .names
                .get(entry.op_name_idx as usize)
                .cloned()
                .unwrap_or_default();

            let proto = match chunk.constants.get(entry.proto_idx as usize) {
                Some(Constant::FnProto(p)) => p.clone(),
                _ => {
                    return Err(VmError::new(
                        "invalid handler proto constant",
                        self.frames[frame_idx].current_line(),
                    ));
                }
            };

            entries.push(VmHandlerEntry {
                op_name,
                proto,
                param_count: entry.param_count,
                tail_resumptive: entry.tail_resumptive,
            });
        }

        Ok(entries)
    }

    /// Push a call frame for a handler body FnProto (single-shot, no resume param).
    ///
    /// The handler body's parameters are: `[effect_args..., state_vars..., resume]`.
    /// For single-shot dispatch, `resume` is Unit (the Resume opcode handles it).
    fn dispatch_handler_body(
        &mut self,
        proto: Arc<FnProto>,
        args: &[VmValue],
        state: &[VmValue],
    ) -> Result<(), VmError> {
        self.dispatch_handler_body_with_resume(proto, args, state, VmValue::Unit)
    }

    /// Push a call frame for a handler body FnProto with a `resume` value.
    ///
    /// Parameters pushed to the stack: `[effect_args..., state_vars..., resume]`.
    /// For multi-shot handlers, `resume` is a `VmContinuation`.
    fn dispatch_handler_body_with_resume(
        &mut self,
        proto: Arc<FnProto>,
        args: &[VmValue],
        state: &[VmValue],
        resume: VmValue,
    ) -> Result<(), VmError> {
        let stack_base = self.stack.len();

        // Push effect args.
        for arg in args {
            self.stack.push(arg.clone());
        }

        // Push state values.
        for s in state {
            self.stack.push(s.clone());
        }

        // Push resume parameter.
        self.stack.push(resume);

        // Push extra locals (beyond params).
        let total_params = args.len() + state.len() + 1; // +1 for resume
        let extra = proto.local_count as usize - total_params.min(proto.local_count as usize);
        for _ in 0..extra {
            self.stack.push(VmValue::Unit);
        }

        self.frames.push(CallFrame {
            proto,
            upvalues: Vec::new(),
            ip: 0,
            stack_base,
            has_func_slot: false, // handler body, no function value below
        });

        Ok(())
    }

    /// Call a VmContinuation: replay the handle body with extended replay log.
    ///
    /// This runs a sub-execution loop: sets up the handle body frame with
    /// replay mode, executes until the body completes, and returns the result.
    pub(super) fn call_continuation(
        &mut self,
        cont: &VmContinuation,
        resume_value: VmValue,
    ) -> Result<VmValue, VmError> {
        // Build extended replay log.
        let mut replay_log = cont.replay_log.clone();
        replay_log.push(resume_value);

        // Save VM state.
        let saved_frames = std::mem::take(&mut self.frames);
        let saved_stack = std::mem::take(&mut self.stack);
        let saved_handler_stack = std::mem::take(&mut self.handler_stack);
        let saved_dispatch_stack = std::mem::take(&mut self.handler_dispatch_stack);
        let saved_replay = self.replay_log.take();
        let saved_replay_pos = self.replay_pos;
        let saved_stop = self.stop_at_pop_handler;

        // Set up replay state.
        self.replay_log = Some(replay_log);
        self.replay_pos = 0;
        self.stop_at_pop_handler = true;

        // Restore outer handler stack from the continuation snapshot.
        self.handler_stack = cont.outer_handler_stack.clone();

        // Restore the enclosing frame's stack (locals at time of PushHandler).
        let stack_base = 0;
        self.stack = cont.stack_snapshot.clone();

        // Push a frame for the enclosing function, starting at body_start_ip.
        self.frames.push(CallFrame {
            proto: cont.proto.clone(),
            upvalues: cont.upvalues.clone(),
            ip: cont.body_start_ip,
            stack_base,
            has_func_slot: false,
        });

        // Push handler frame (re-install the handler for the body).
        let handler_frame_idx = self.frames.len() - 1;
        self.handler_stack.push(VmHandlerFrame {
            entries: cont.handler_entries.clone(),
            frame_idx: handler_frame_idx,
            stack_height: self.stack.len(),
            initial_state: cont.initial_state.clone(),
            state: cont.initial_state.clone(),
            resume_ip: 0,
            resume_frame_idx: 0,
            resume_stack_height: 0,
            body_start_ip: cont.body_start_ip,
            stack_snapshot: cont.stack_snapshot.clone(),
        });

        // Execute the body.
        let result = self.execute();

        // Restore VM state.
        self.frames = saved_frames;
        self.stack = saved_stack;
        self.handler_stack = saved_handler_stack;
        self.handler_dispatch_stack = saved_dispatch_stack;
        self.replay_log = saved_replay;
        self.replay_pos = saved_replay_pos;
        self.stop_at_pop_handler = saved_stop;

        match result {
            Ok(Some(val)) => Ok(val),
            Ok(None) => Ok(VmValue::Unit),
            Err(e) => Err(e),
        }
    }
}
