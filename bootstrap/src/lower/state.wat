  ;; ═══ state.wat — Hβ.lower per-function locals/captures ledger (Tier 4) ═══
  ;; Implements: Hβ-lower-substrate.md §1.2 — module-level globals for
  ;;             the lowering walk's LowerCtx state (locals ledger,
  ;;             captures ledger, next-slot counter) + idempotent
  ;;             $lower_init + $ls_* helpers per §1.2 lines 204-223.
  ;; Exports:    $lower_init,
  ;;             $ls_bind_local, $ls_lookup_local, $ls_lookup_or_capture,
  ;;             $ls_register_globals, $ls_is_global,
  ;;             $ls_enter_function, $ls_exit_function, $ls_in_function,
  ;;             $ls_push_scope, $ls_pop_scope, $ls_reset_function,
  ;;             $lower_locals_len, $lower_captures_len
  ;; Uses:       $alloc (alloc.wat),
  ;;             $make_list / $list_set / $list_index / $list_extend_to /
  ;;             $len (list.wat),
  ;;             $make_record / $record_get / $record_set (record.wat),
  ;;             $str_eq (str.wat),
  ;;             $env_contains (env.wat — for $ls_lookup_or_capture's
  ;;                            outer-scope reachability test)
  ;; Test:       bootstrap/test/lower/state_init.wat (this commit)
  ;;
  ;; What this scratchpad IS (per Hβ-lower-substrate.md §1.2):
  ;;   The lowering walk needs ONE piece of context across recursive
  ;;   $lower_expr calls: the current function's locals + captures
  ;;   ledger. Per spec 05 §No subst threading: "no (subst, lowered_ast,
  ;;   accum) tuple threaded through recursive calls." LowerCtx is the
  ;;   wheel's effect (src/lower.nx:45-92 LowerState); the seed projects
  ;;   to module globals + direct-call helpers.
  ;;
  ;;   1. locals ledger — flat list of LOCAL_ENTRY records (3 fields:
  ;;      name_str, slot_idx, ty_handle). Tag 280. Append-on-bind via
  ;;      $ls_bind_local; lookup via $ls_lookup_local (walks end-to-start
  ;;      so the most-recent binding for a name wins — see Open Question
  ;;      O.1 in the named-follow-ups block below for seed-vs-wheel
  ;;      divergence).
  ;;
  ;;   2. captures ledger — flat list of CAPTURE_ENTRY records (2 fields:
  ;;      upvalue_name_str, src_slot_idx). Tag 281. Populated by
  ;;      $ls_lookup_or_capture when a name lookup misses locals but
  ;;      $env_contains returns 1; src_slot_idx is the seed's sentinel
  ;;      (0) pending Hβ.lower.upval-slot-resolution follow-up.
  ;;
  ;;   3. next-slot counter — monotonic; incremented by $ls_bind_local;
  ;;      reset to 0 by $ls_reset_function at FnStmt entry.
  ;;
  ;; Eight interrogations (per Hβ-lower-substrate.md §5.1 at LookupTy +
  ;; LowerCtx primitives, projected onto state.wat specifically):
  ;;   1. Graph?       state.wat does not chase. Each LOCAL_ENTRY's
  ;;                   ty_handle field references graph handles; lookup.wat
  ;;                   reads them via $graph_chase. State is transit.
  ;;   2. Handler?     LowerCtx effect at the wheel (src/lower.nx:45-92
  ;;                   LowerState — @resume=OneShot per §1.2). Seed projection
  ;;                   is direct $ls_* functions; the wheel compiles
  ;;                   handler-shape from src/lower.nx.
  ;;   3. Verb?        N/A at substrate level.
  ;;   4. Row?         EfPure — state.wat performs no effect ops. Wheel's
  ;;                   LowerState composes with LookupTy + EnvRead +
  ;;                   Diagnostic per spec 05; seed elides row machinery.
  ;;   5. Ownership?   Locals + captures OWN by current function; cleared
  ;;                   length-only at $ls_reset_function (matches
  ;;                   infer/state.wat:218-223 discipline; bump allocator
  ;;                   never frees).
  ;;   6. Refinement?  N/A — refinement obligations land in verify ledger,
  ;;                   not here.
  ;;   7. Gradient?    Each ledger entry IS gradient: name-with-slot =
  ;;                   monomorphic-bound; name-as-capture = closure
  ;;                   evidence-slot at H1 time.
  ;;   8. Reason?      ty_handle preserves Reason chain (graph-side).
  ;;                   State.wat is read-only on Reason.
  ;;
  ;; Forbidden patterns audited (per Hβ-lower-substrate.md §6.1 +
  ;; project-wide drift modes):
  ;;   - Drift 1 (vtable):                  no closure-record-of-functions;
  ;;                                        $ls_* are direct fns.
  ;;   - Drift 2 (Scheme env frame):        locals ledger is ONE flat list;
  ;;                                        no parent-pointer-frame stack;
  ;;                                        $ls_lookup_local walks the
  ;;                                        single list (not a frame chain).
  ;;   - Drift 5 (C calling convention):    no __closure/__ev split params;
  ;;                                        helpers take only their i32 args.
  ;;   - Drift 7 (parallel-arrays-vs-record): LOCAL_ENTRY/CAPTURE_ENTRY
  ;;                                        are $make_record(tag, arity) —
  ;;                                        NOT parallel _names_ptr +
  ;;                                        _slots_ptr + _handles_ptr arrays.
  ;;   - Drift 8 (string-keyed):            ledger tags are integer constants
  ;;                                        (280/281) per the lower-private
  ;;                                        280-299 reserved tag region.
  ;;   - Drift 9 (deferred-by-omission):    every $ls_* helper has its body;
  ;;                                        seed-vs-wheel divergences (O.1
  ;;                                        scope-stack, O.2 upval slot)
  ;;                                        named as peer follow-ups below,
  ;;                                        NOT silent TODOs.
  ;;
  ;; Tag region: lower-private 280-299.
  ;;   280   LOCAL_ENTRY_TAG       — (name, slot_idx, ty_handle) 3-field
  ;;   281   CAPTURE_ENTRY_TAG     — (upvalue_name, src_slot_idx) 2-field
  ;;   282-299 reserved for future lower-substrate records
  ;;
  ;; Named follow-ups (per Drift 9 + Hβ-lower-substrate.md §11):
  ;;   - Hβ.lower.scope-stack:  block-scope / handler-arm / lambda-frame
  ;;                            push/pop discipline (wheel src/lower.nx
  ;;                            lines 375-378, 414-419, 738, 741, 755, 758).
  ;;                            Seed deliberately omits per §0.1 transcription
  ;;                            simplification — most-recent binding wins via
  ;;                            end-to-start walk in $ls_lookup_local.
  ;;                            Lands when handler-arm or shadowed-block
  ;;                            usage in self-compile breaks something.
  ;;   - Hβ.lower.upval-slot-resolution:  src_slot_idx in CAPTURE_ENTRY is
  ;;                            sentinel 0 in the seed; the wheel's emit-side
  ;;                            closure-record evidence-slot population (per
  ;;                            H1) reads the actual outer-fn slot index.
  ;;                            Lands alongside walk_handle.wat's
  ;;                            LMakeContinuation / LMakeClosure population.

  ;; ─── Module-level globals (per §1.2 lines 182-198) ──────────────────

  ;; $lower_initialized — idempotent init flag.
  (global $lower_initialized       (mut i32) (i32.const 0))

  ;; $lower_locals_ptr: flat list of LOCAL_ENTRY records (tag 280) —
  ;; (name_str_ptr, slot_idx, ty_handle) for the CURRENT function being
  ;; lowered. Length tracked separately per the buffer-counter substrate
  ;; (Ω.3); buffer grows via $list_extend_to as length crosses capacity.
  (global $lower_locals_ptr        (mut i32) (i32.const 0))
  (global $lower_locals_len_g      (mut i32) (i32.const 0))

  ;; Monotonic slot counter; reset to 0 per $ls_reset_function.
  (global $lower_next_slot_g       (mut i32) (i32.const 0))

  ;; $lower_captures_ptr: flat list of CAPTURE_ENTRY records (tag 281) —
  ;; (upvalue_name_str_ptr, src_slot_idx) pairs for upvalues this fn
  ;; captures from enclosing scopes.
  (global $lower_captures_ptr      (mut i32) (i32.const 0))
  (global $lower_captures_len_g    (mut i32) (i32.const 0))

  ;; Top-level names registered by $lower_program before walking. VarRef
  ;; resolution uses this set to emit LGlobal instead of capturing or
  ;; inventing a function-local binding for module-level closures.
  (global $lower_globals_ptr       (mut i32) (i32.const 0))
  (global $lower_globals_len_g     (mut i32) (i32.const 0))

  ;; Function nesting depth. Depth 0 means the walker is at module scope;
  ;; top-level FnStmt names are globals, not locals in later function bodies.
  (global $lower_function_depth_g  (mut i32) (i32.const 0))

  ;; H.2.e frame-start: index in $lower_locals_ptr where the CURRENT
  ;; function's locals begin. Lookups search only [frame_start, len),
  ;; so a lambda body's $ls_lookup_local doesn't "see" the enclosing
  ;; function's locals as its own (those become captures via
  ;; $ls_lookup_or_capture's outer-scope path). Approximation of the
  ;; wheel's ls_enter_frame/ls_exit_frame frame-stack ADT (named
  ;; follow-up Hβ.lower.lambda-nested-frame for the full discipline).
  (global $lower_frame_start_g     (mut i32) (i32.const 0))

  ;; ─── Idempotent initializer (mirrors $infer_init / $graph_init) ────
  ;; Per the seed's discipline for module-level state chunks: every
  ;; public entry calls $lower_init first; subsequent calls no-op.
  ;; Initial capacity 8 per buffer; $list_extend_to grows on demand.
  (func $lower_init
    (if (i32.eqz (global.get $lower_initialized))
      (then
        (global.set $lower_locals_ptr     (call $make_list (i32.const 8)))
        (global.set $lower_locals_len_g   (i32.const 0))
        (global.set $lower_next_slot_g    (i32.const 0))
        (global.set $lower_captures_ptr   (call $make_list (i32.const 8)))
        (global.set $lower_captures_len_g (i32.const 0))
        (global.set $lower_globals_ptr    (call $make_list (i32.const 8)))
        (global.set $lower_globals_len_g  (i32.const 0))
        (global.set $lower_function_depth_g (i32.const 0))
        (global.set $lower_frame_start_g    (i32.const 0))
        (global.set $lower_initialized    (i32.const 1)))))

  ;; ─── $ls_register_globals — install top-level names for this walk ──
  (func $ls_register_globals (param $names i32)
    (call $lower_init)
    (global.set $lower_globals_ptr (local.get $names))
    (global.set $lower_globals_len_g (call $len (local.get $names))))

  ;; ─── $ls_is_global — membership in the top-level name set ──────────
  (func $ls_is_global (param $name i32) (result i32)
    (local $i i32) (local $entry_name i32)
    (call $lower_init)
    (local.set $i (i32.const 0))
    (block $done
      (loop $iter
        (br_if $done (i32.ge_u (local.get $i) (global.get $lower_globals_len_g)))
        (local.set $entry_name
          (call $list_index (global.get $lower_globals_ptr) (local.get $i)))
        (if (call $str_eq (local.get $entry_name) (local.get $name))
          (then (return (i32.const 1))))
        (local.set $i (i32.add (local.get $i) (i32.const 1)))
        (br $iter)))
    (i32.const 0))

  ;; ─── Function-depth surfaces for top-level/global distinction ──────
  (func $ls_enter_function
    (call $lower_init)
    (global.set $lower_function_depth_g
      (i32.add (global.get $lower_function_depth_g) (i32.const 1))))

  (func $ls_exit_function
    (call $lower_init)
    (if (i32.gt_u (global.get $lower_function_depth_g) (i32.const 0))
      (then
        (global.set $lower_function_depth_g
          (i32.sub (global.get $lower_function_depth_g) (i32.const 1))))))

  (func $ls_in_function (result i32)
    (call $lower_init)
    (i32.gt_u (global.get $lower_function_depth_g) (i32.const 0)))

  ;; ─── $ls_bind_local — append a new local; return its slot index ────
  ;; Per Hβ-lower-substrate.md §1.2 lines 204-207 + wheel src/lower.nx:771
  ;; (bind_names_as_locals). Appends a LOCAL_ENTRY record to the locals
  ;; ledger; bumps $lower_next_slot_g; returns the slot.
  (func $ls_bind_local (param $name i32) (param $ty_handle i32) (result i32)
    (local $entry i32) (local $slot i32) (local $new_len i32)
    (call $lower_init)
    (local.set $slot (global.get $lower_next_slot_g))
    (local.set $entry (call $make_record (i32.const 280) (i32.const 3)))
    (call $record_set (local.get $entry) (i32.const 0) (local.get $name))
    (call $record_set (local.get $entry) (i32.const 1) (local.get $slot))
    (call $record_set (local.get $entry) (i32.const 2) (local.get $ty_handle))
    (local.set $new_len (i32.add (global.get $lower_locals_len_g) (i32.const 1)))
    (global.set $lower_locals_ptr
      (call $list_extend_to (global.get $lower_locals_ptr) (local.get $new_len)))
    (drop (call $list_set (global.get $lower_locals_ptr)
                          (global.get $lower_locals_len_g)
                          (local.get $entry)))
    (global.set $lower_locals_len_g  (local.get $new_len))
    (global.set $lower_next_slot_g   (i32.add (local.get $slot) (i32.const 1)))
    (local.get $slot))

  ;; ─── $ls_lookup_local — slot index if name is a local; -1 otherwise ─
  ;; Walks end-to-start so the most-recent binding for a given name
  ;; wins (see Open Question O.1 — seed's intentional looseness vs the
  ;; wheel's scope-stack discipline). Returns -1 (i32 -1 = 0xFFFFFFFF
  ;; tested via i32.lt_s by callers) when not found.
  (func $ls_lookup_local (param $name i32) (result i32)
    (local $i i32) (local $entry i32) (local $entry_name i32)
    (call $lower_init)
    (local.set $i (global.get $lower_locals_len_g))
    (block $done
      (loop $iter
        ;; H.2.e frame-start: stop scanning at frame_start so outer-fn
        ;; locals are NOT visible to a lambda body's lookup. Names not
        ;; in the lambda's own frame fall through to
        ;; $ls_lookup_or_capture and become captures.
        (br_if $done (i32.le_u (local.get $i) (global.get $lower_frame_start_g)))
        (local.set $i (i32.sub (local.get $i) (i32.const 1)))
        (local.set $entry
          (call $list_index (global.get $lower_locals_ptr) (local.get $i)))
        (local.set $entry_name (call $record_get (local.get $entry) (i32.const 0)))
        (if (call $str_eq (local.get $entry_name) (local.get $name))
          (then
            (return (call $record_get (local.get $entry) (i32.const 1)))))
        (br $iter)))
    (i32.const -1))

  ;; ─── $ls_lookup_or_capture — local slot, capture index, or -1 ──────
  ;; Per Hβ-lower-substrate.md §1.2 lines 213-217. Locals first; if not
  ;; local but $env_contains says the name is bound in some outer env
  ;; scope, record a CAPTURE_ENTRY (src_slot_idx sentinel 0 — see Open
  ;; Question O.2 / Hβ.lower.upval-slot-resolution follow-up) and return
  ;; the capture's index in $lower_captures_ptr. If neither, return -1
  ;; (caller emits LGlobal — wheel parity, src/lower.nx:336-337).
  (func $ls_lookup_or_capture (param $name i32) (result i32)
    (local $local_slot i32) (local $i i32) (local $entry i32)
    (local $entry_name i32) (local $cap_entry i32) (local $cap_idx i32)
    (local $new_len i32)
    (call $lower_init)
    ;; Try locals first.
    (local.set $local_slot (call $ls_lookup_local (local.get $name)))
    (if (i32.ge_s (local.get $local_slot) (i32.const 0))
      (then (return (local.get $local_slot))))
    ;; Not local — scan existing captures (avoid duplicates; one
    ;; CAPTURE_ENTRY per upvalue name per function lowering).
    (local.set $i (global.get $lower_captures_len_g))
    (block $cap_done
      (loop $cap_iter
        (br_if $cap_done (i32.eqz (local.get $i)))
        (local.set $i (i32.sub (local.get $i) (i32.const 1)))
        (local.set $entry
          (call $list_index (global.get $lower_captures_ptr) (local.get $i)))
        (local.set $entry_name (call $record_get (local.get $entry) (i32.const 0)))
        (if (call $str_eq (local.get $entry_name) (local.get $name))
          (then (return (local.get $i))))
        (br $cap_iter)))
    ;; Not local, not yet a capture — check outer-scope reachability
    ;; via three paths (any positive → capture):
    ;;   (a) top-level globals set → return -1 (caller emits LGlobal)
    ;;   (b) OUTER FRAMES of lower's locals ledger (indices
    ;;       [0, frame_start)) — H.2.e closure-capture path.
    ;;   (c) infer's env (env_contains) — preserves the contract used
    ;;       by lower/state_init.wat harness + standalone lookups.
    ;; If neither (b) nor (c), return -1 (productive-under-error per
    ;; Hazel — caller emits LGlobal; emit_diag fires if genuinely
    ;; missing).
    (if (call $ls_is_global (local.get $name))
      (then (return (i32.const -1))))
    ;; (b) Outer-frame locals scan.
    (local.set $local_slot (i32.const -1))   ;; reuse as "found" flag
    (local.set $i (global.get $lower_frame_start_g))
    (block $outer_done
      (loop $outer_iter
        (br_if $outer_done (i32.eqz (local.get $i)))
        (local.set $i (i32.sub (local.get $i) (i32.const 1)))
        (local.set $entry
          (call $list_index (global.get $lower_locals_ptr) (local.get $i)))
        (local.set $entry_name (call $record_get (local.get $entry) (i32.const 0)))
        (if (call $str_eq (local.get $entry_name) (local.get $name))
          (then
            (local.set $local_slot (i32.const 0))   ;; sentinel "found"
            (br $outer_done)))
        (br $outer_iter)))
    ;; (c) env fallback if outer-frame scan didn't find it.
    (if (i32.lt_s (local.get $local_slot) (i32.const 0))
      (then
        (if (i32.eqz (call $env_contains (local.get $name)))
          (then (return (i32.const -1))))))
    ;; Record a fresh CAPTURE_ENTRY. src_slot_idx = 0 sentinel pending
    ;; Hβ.lower.upval-slot-resolution.
    (local.set $cap_idx (global.get $lower_captures_len_g))
    (local.set $cap_entry (call $make_record (i32.const 281) (i32.const 2)))
    (call $record_set (local.get $cap_entry) (i32.const 0) (local.get $name))
    (call $record_set (local.get $cap_entry) (i32.const 1) (i32.const 0))
    (local.set $new_len (i32.add (global.get $lower_captures_len_g) (i32.const 1)))
    (global.set $lower_captures_ptr
      (call $list_extend_to (global.get $lower_captures_ptr) (local.get $new_len)))
    (drop (call $list_set (global.get $lower_captures_ptr)
                          (local.get $cap_idx)
                          (local.get $cap_entry)))
    (global.set $lower_captures_len_g (local.get $new_len))
    (local.get $cap_idx))

  ;; ─── $ls_push_scope / $ls_pop_scope — lexical-scope checkpoints ───
  ;; The seed's LowerCtx is still a flat locals ledger, but block / arm /
  ;; pattern scopes need honest truncation rather than ambient leakage.
  ;; Wheel parity uses a frame record's local_order length as the checkpoint;
  ;; the seed projects that to the current logical locals length.
  (func $ls_push_scope (result i32)
    (call $lower_init)
    (global.get $lower_locals_len_g))

  (func $ls_pop_scope (param $checkpoint i32)
    (call $lower_init)
    (if (i32.le_u (local.get $checkpoint) (global.get $lower_locals_len_g))
      (then
        (global.set $lower_locals_len_g (local.get $checkpoint))
        (global.set $lower_next_slot_g (local.get $checkpoint)))))

  ;; ─── $ls_reset_function — clear at FnStmt entry ────────────────────
  ;; Per Hβ-lower-substrate.md §1.2 lines 219-223 + wheel src/lower.nx:86-90
  ;; (LowerState ms_reset_function). Length-only reset; bump-allocator
  ;; buffers stay (matches infer/state.wat:218-223 $infer_reset_walk
  ;; discipline). Next $ls_bind_local reuses the existing flat storage.
  (func $ls_reset_function
    (call $lower_init)
    (global.set $lower_locals_len_g    (i32.const 0))
    (global.set $lower_next_slot_g     (i32.const 0))
    (global.set $lower_captures_len_g  (i32.const 0))
    (global.set $lower_function_depth_g (i32.const 0)))

  ;; ─── $ls_enter_frame — push a new frame for nested fn (lambda) ─────
  ;; Per H.2.e: when entering a lambda, the lambda's body should see
  ;; only its own locals, not the enclosing fn's. Returns the previous
  ;; $lower_frame_start_g so the caller can restore it on exit.
  (func $ls_enter_frame (result i32)
    (local $prev i32)
    (call $lower_init)
    (local.set $prev (global.get $lower_frame_start_g))
    (global.set $lower_frame_start_g (global.get $lower_locals_len_g))
    (local.get $prev))

  ;; ─── $ls_exit_frame — restore frame_start after nested fn exits ────
  (func $ls_exit_frame (param $prev_frame_start i32)
    (call $lower_init)
    (global.set $lower_frame_start_g (local.get $prev_frame_start)))

  ;; ─── $lower_captures_ptr_get — read-only access to captures buffer ─
  ;; Per H.2.e: $lower_lambda iterates captures appended during body
  ;; walk to materialize caps_exprs. The captures buffer is module-
  ;; private; this accessor exposes it without making the global itself
  ;; cross-chunk-mutable.
  (func $lower_captures_ptr_get (result i32)
    (call $lower_init)
    (global.get $lower_captures_ptr))

  ;; ─── $ls_truncate_captures — restore captures_len to a snapshot ────
  ;; Per H.2.e step 6: after a lambda's body walk consumes new
  ;; captures, the lambda OWNS them in its LMakeClosure caps list.
  ;; Restoring length to the pre-lambda snapshot keeps the outer fn's
  ;; captures-ledger clean (frame-stack-stack discipline approximation;
  ;; full ADT is named follow-up Hβ.lower.lambda-nested-frame). Buffer
  ;; capacity preserved per buffer-counter substrate.
  (func $ls_truncate_captures (param $checkpoint i32)
    (call $lower_init)
    (if (i32.le_u (local.get $checkpoint) (global.get $lower_captures_len_g))
      (then
        (global.set $lower_captures_len_g (local.get $checkpoint)))))

  ;; ─── Read-only length surfaces (for harness + downstream chunks) ───
  (func $lower_locals_len (result i32)
    (call $lower_init)
    (global.get $lower_locals_len_g))

  (func $lower_captures_len (result i32)
    (call $lower_init)
    (global.get $lower_captures_len_g))
