//! Effect dispatch for the Lux VM: PushHandler, Perform, Resume, PopHandler.
//!
//! Handler bodies are compiled as separate `FnProto`s. When `Perform` dispatches
//! to a handler, the VM pushes a new call frame for the handler body. `Resume`
//! unwinds back to the perform site and pushes the resume value.

use std::sync::Arc;

use super::chunk::{Constant, FnProto};
use super::error::VmError;
use super::frame::{CallFrame, HandlerDispatchEntry, VmHandlerEntry, VmHandlerFrame};
use super::value::{VmContinuation, VmEvidence, VmEvidenceEntry, VmValue};
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

        // Resolve handler entries: static (from handler table) or dynamic (from record on stack).
        let entries = if table_idx == 0xFFFF {
            // Dynamic handler: pop record value from stack and build entries from its fields.
            let record = self.stack.pop().unwrap_or(VmValue::Unit);
            self.build_dynamic_handler_entries(record, frame_idx)?
        } else {
            self.resolve_handler_entries(frame_idx, table_idx)?
        };

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
            // Save resume state for the dispatch stack entry.
            let resume_ip = self.frames[frame_idx].ip;
            let resume_stack_height = self.stack.len();

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
                    stack_snapshot: self.handler_stack[handler_idx].stack_snapshot.clone(),
                    upvalues: self.frames[h_frame_idx].upvalues.clone(),
                    outer_handler_stack: self.handler_stack[..handler_idx].to_vec(),
                    outer_frame_count: h_frame_idx,
                };
                Some(VmValue::Continuation(Arc::new(cont)))
            } else {
                None
            };

            // Get the handler proto, state, and captured upvalues.
            let proto = self.handler_stack[handler_idx].entries[entry_idx]
                .proto
                .clone();
            let state = self.handler_stack[handler_idx].state.clone();
            let upvalues = self.handler_stack[handler_idx].entries[entry_idx]
                .upvalues
                .clone();

            // Push call frame for the handler body.
            if let Some(cont) = continuation {
                self.dispatch_handler_body_with_resume(proto, &args, &state, cont, upvalues)?;
            } else {
                self.dispatch_handler_body(proto, &args, &state, upvalues)?;
            }

            // Track dispatch with per-entry resume metadata.
            // Each entry carries its own resume point so re-entrant
            // dispatch on the same handler works correctly.
            self.handler_dispatch_stack.push(HandlerDispatchEntry {
                handler_idx,
                body_frame_idx: self.frames.len() - 1,
                resume_ip,
                resume_frame_idx: frame_idx,
                resume_stack_height,
            });

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

        if let Some(dispatch) = self.handler_dispatch_stack.pop() {
            let h_idx = dispatch.handler_idx;
            let body_frame_idx = dispatch.body_frame_idx;

            // Apply state updates to the handler frame.
            let handler = &mut self.handler_stack[h_idx];
            for (offset, value) in state_offsets.iter().zip(update_values.into_iter()) {
                let idx = *offset as usize;
                if idx < handler.state.len() {
                    handler.state[idx] = value;
                }
            }

            // Resume metadata comes from the dispatch entry, not the handler
            // frame. This enables re-entrant dispatch on the same handler.
            let resume_ip = dispatch.resume_ip;
            let resume_frame_idx = dispatch.resume_frame_idx;
            let resume_stack_height = dispatch.resume_stack_height;

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
            if resume_frame_idx < self.frames.len() {
                let code_len = self.frames[resume_frame_idx].proto.chunk.code.len();
                if resume_ip > code_len {
                    let line = self.frames[resume_frame_idx].current_line();
                    return Err(VmError::new(
                        format!("resume IP out of bounds: {resume_ip} > {code_len}"),
                        line,
                    ));
                }
                self.frames[resume_frame_idx].ip = resume_ip;
            }

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
    ///
    /// Captures upvalue values from the current frame — same mechanism as
    /// `MakeClosure`, but applied at `PushHandler` time so handler bodies
    /// can reference enclosing locals.
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

        let base = self.frames[frame_idx].stack_base;

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

            // Capture upvalues from the current frame (same as MakeClosure).
            let upvalues: Vec<VmValue> = entry
                .upvalue_descs
                .iter()
                .map(|&(is_local, idx)| {
                    if is_local {
                        self.stack
                            .get(base + idx as usize)
                            .cloned()
                            .unwrap_or(VmValue::Unit)
                    } else {
                        self.frames[frame_idx]
                            .upvalues
                            .get(idx as usize)
                            .cloned()
                            .unwrap_or(VmValue::Unit)
                    }
                })
                .collect();

            entries.push(VmHandlerEntry {
                op_name,
                proto,
                param_count: entry.param_count,
                tail_resumptive: entry.tail_resumptive,
                evidence_eligible: entry.evidence_eligible,
                upvalues,
            });
        }

        Ok(entries)
    }

    /// Build handler entries from a dynamic record value.
    ///
    /// Parses the record's `#record:field1,field2,...` tag to get operation names,
    /// then extracts closures from the fields to create handler entries. This enables
    /// `computation ~> handler_variable` where the handler is returned from a function.
    fn build_dynamic_handler_entries(
        &self,
        record: VmValue,
        frame_idx: usize,
    ) -> Result<Vec<VmHandlerEntry>, VmError> {
        let (tag, fields) = match record {
            VmValue::Variant { name, fields } => (name, fields),
            _ => {
                let line = self.frames[frame_idx].current_line();
                return Err(VmError::new("dynamic handler: expected record value", line));
            }
        };

        let tag_str = tag.as_str();
        if !tag_str.starts_with("#record:") {
            let line = self.frames[frame_idx].current_line();
            return Err(VmError::new(
                format!("dynamic handler: expected record, got variant '{tag_str}'"),
                line,
            ));
        }

        let field_part = &tag_str["#record:".len()..];
        let field_names: Vec<&str> = field_part.split(',').collect();

        let mut entries = Vec::with_capacity(field_names.len());
        for (i, name) in field_names.iter().enumerate() {
            let value = fields.get(i).cloned().unwrap_or(VmValue::Unit);
            let (proto, upvalues) = match value {
                VmValue::Closure(c) => (c.proto.clone(), c.upvalues.clone()),
                VmValue::BundledClosure { closure, evidence } => {
                    let mut ups = closure.upvalues.clone();
                    ups.extend((*evidence).iter().cloned());
                    (closure.proto.clone(), ups)
                }
                _ => {
                    let line = self.frames[frame_idx].current_line();
                    return Err(VmError::new(
                        format!("dynamic handler field '{name}': expected closure"),
                        line,
                    ));
                }
            };

            entries.push(VmHandlerEntry {
                op_name: name.to_string(),
                proto: proto.clone(),
                param_count: proto.arity as u8,
                tail_resumptive: true,
                evidence_eligible: false,
                upvalues,
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
        upvalues: Vec<VmValue>,
    ) -> Result<(), VmError> {
        self.dispatch_handler_body_with_resume(proto, args, state, VmValue::Unit, upvalues)
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
        upvalues: Vec<VmValue>,
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
            upvalues,
            ip: 0,
            stack_base,
            has_func_slot: false, // handler body, no function value below
        });

        Ok(())
    }

    // ── Evidence-passing (Phase 7+) ──────────────────────

    /// Process the `PushEvidence` opcode.
    ///
    /// Resolves handler entries from the evidence handler table, constructs
    /// a `VmEvidence` value, and stores it in the designated local slot.
    /// The handler must already be on the handler stack (via PushHandler).
    pub(super) fn op_push_evidence(&mut self, frame_idx: usize) -> Result<(), VmError> {
        let table_idx = self.frames[frame_idx].read_u16() as usize;
        let ev_local = self.frames[frame_idx].read_u16() as usize;

        // Resolve handler entries from the evidence handler table.
        let entries = self.resolve_handler_entries(frame_idx, table_idx)?;

        // Convert to evidence entries (carry upvalues through).
        let ev_entries: Vec<VmEvidenceEntry> = entries
            .into_iter()
            .map(|e| VmEvidenceEntry {
                op_name: e.op_name,
                proto: e.proto,
                param_count: e.param_count,
                upvalues: e.upvalues,
            })
            .collect();

        // Handler stack index is the topmost handler (just pushed by PushHandler).
        let handler_stack_idx = self.handler_stack.len() - 1;

        let evidence = VmEvidence {
            entries: ev_entries,
            handler_stack_idx,
        };

        // Store evidence in the pre-allocated local slot.
        let base = self.frames[frame_idx].stack_base;
        self.stack[base + ev_local] = VmValue::Evidence(Arc::new(evidence));

        Ok(())
    }

    /// Process the `PerformEvidence` opcode.
    ///
    /// Direct call through evidence — skips handler stack search and
    /// continuation capture. Calls the evidence-mode handler body
    /// synchronously (nested `execute()`), then unpacks state from the
    /// return tuple if the handler is stateful.
    pub(super) fn op_perform_evidence(&mut self, frame_idx: usize) -> Result<(), VmError> {
        let ev_local = self.frames[frame_idx].read_u16() as usize;
        let op_name_idx = self.frames[frame_idx].read_u16();
        let argc = self.frames[frame_idx].read_byte() as usize;

        let base = self.frames[frame_idx].stack_base;

        // Load evidence from local slot.
        let evidence = match &self.stack[base + ev_local] {
            VmValue::Evidence(ev) => ev.clone(),
            _ => {
                let line = self.frames[frame_idx].current_line();
                return Err(VmError::new("expected evidence value in local slot", line));
            }
        };

        // Resolve operation name from the current chunk.
        let op_name = self.frames[frame_idx]
            .proto
            .chunk
            .names
            .get(op_name_idx as usize)
            .cloned()
            .unwrap_or_default();

        // Find matching entry in evidence.
        let entry = evidence.entries.iter().find(|e| e.op_name == op_name);
        let entry = match entry {
            Some(e) => e,
            None => {
                let line = self.frames[frame_idx].current_line();
                return Err(VmError::new(
                    format!("evidence missing handler for: {op_name}"),
                    line,
                ));
            }
        };
        let proto = entry.proto.clone();
        let entry_upvalues = entry.upvalues.clone();
        let h_idx = evidence.handler_stack_idx;

        // Pop effect args from stack.
        let args_start = self.stack.len() - argc;
        let args: Vec<VmValue> = self.stack.drain(args_start..).collect();

        // Get handler state from the handler stack (shared with normal Perform path).
        // Clone state, push onto stack, then DROP the clone so it doesn't hold
        // Arc references that prevent COW in-place mutation during the body.
        let state_count = self.handler_stack[h_idx].state.len();

        // Build call frame for evidence handler body: [args..., state...].
        let call_base = self.stack.len();
        // Move args onto stack (not clone) to avoid holding extra Arc refs.
        for arg in args {
            self.stack.push(arg);
        }
        for i in 0..state_count {
            self.stack.push(self.handler_stack[h_idx].state[i].clone());
        }

        // Push extra locals (beyond params).
        let total_params = argc + state_count;
        let extra = (proto.local_count as usize).saturating_sub(total_params);
        for _ in 0..extra {
            self.stack.push(VmValue::Unit);
        }

        // Push call frame with captured upvalues.
        let target_depth = self.frames.len();
        self.frames.push(CallFrame {
            proto,
            upvalues: entry_upvalues,
            ip: 0,
            stack_base: call_base,
            has_func_slot: false,
        });

        // Execute handler body to completion (nested execute).
        let saved_depth = self.evidence_return_depth;
        self.evidence_return_depth = Some(target_depth);
        let result = self.execute();
        self.evidence_return_depth = saved_depth;

        let handler_result = match result {
            Ok(Some(val)) => val,
            Ok(None) => VmValue::Unit,
            Err(e) => return Err(e),
        };

        // Process result: unpack state tuple if stateful.
        // Tuple format: (resume_value, bitmask, state_0, ..., state_N)
        // The bitmask encodes which state variables were explicitly updated.
        // Only those slots are overwritten — unchanged slots keep their current
        // value (which may have been updated by nested dispatches).
        if state_count > 0 {
            if let VmValue::Tuple(elts) = &handler_result {
                let bitmask = match elts.get(1) {
                    Some(VmValue::Int(n)) => *n as u64,
                    _ => u64::MAX,
                };
                for i in 0..state_count {
                    if bitmask & (1 << i) != 0 {
                        if let Some(val) = elts.get(i + 2) {
                            self.handler_stack[h_idx].state[i] = val.clone();
                        }
                    }
                }
                // Push resume value.
                self.stack.push(elts[0].clone());
            } else {
                let line = self.frames.last().map(|f| f.current_line()).unwrap_or(0);
                return Err(VmError::new(
                    "evidence handler expected to return tuple for stateful handler",
                    line,
                ));
            }
        } else {
            // Stateless: result is the resume value.
            self.stack.push(handler_result);
        }

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
        let saved_stop = self.stop_at_handler_depth;

        // Set up replay state.
        self.replay_log = Some(replay_log);
        self.replay_pos = 0;
        // Stop when the handler stack drops back to the depth we're about
        // to push to. Inner nested handlers will push/pop above this depth
        // without triggering the stop condition.
        // (We set this BEFORE pushing our handler frame, so the depth is
        // the outer handler stack length from the continuation.)
        self.stop_at_handler_depth = Some(self.handler_stack.len());

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
        self.stop_at_handler_depth = saved_stop;

        match result {
            Ok(Some(val)) => Ok(val),
            Ok(None) => Ok(VmValue::Unit),
            Err(e) => Err(e),
        }
    }
}
