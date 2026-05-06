  ;; ═══ state.wat — Hβ.emit emit-time state ledger (Tier 4) ════════════
  ;; Implements: Hβ-emit-substrate.md §0.6 (emit IS one handler-on-graph)
  ;;             + §3 lines 400-413 (H1.4 single-handler-per-op naming +
  ;;             funcref-table layout) + §3.5 lines 324-396 (EmitMemory
  ;;             swap surface — seed defaults to bump strategy structurally)
  ;;             + §5.1 lines 444-454 (eight interrogations at dispatcher)
  ;;             + §7.1 lines 502-524 (chunk file layout — first chunk).
  ;; Exports:    $emit_init,
  ;;             $emit_funcref_register, $emit_funcref_lookup,
  ;;             $emit_funcref_count, $emit_funcref_at,
  ;;             $emit_set_body_context, $emit_body_captures_count,
  ;;             $emit_body_evidence, $emit_body_evidence_len,
  ;;             $emit_string_intern, $emit_string_lookup,
  ;;             $emit_string_table_count, $emit_string_table_at,
  ;;             $emit_fn_reset
  ;; Uses:       $alloc (alloc.wat),
  ;;             $make_list / $list_set / $list_index / $list_extend_to /
  ;;             $len (list.wat),
  ;;             $make_record / $record_get / $record_set (record.wat),
  ;;             $str_eq / $str_len (str.wat)
  ;; Test:       bootstrap/test/emit/state_init.wat (this commit)
  ;;
  ;; What this scratchpad IS (per Hβ-emit-substrate.md §0.6 + §3 + §3.5
  ;; + wheel canonical src/backends/wasm.nx:117-128 + 945-978):
  ;;   The emit walk needs THREE pieces of context across recursive
  ;;   emit_lexpr calls. Per spec 05 §Emitter handoff + Anchor 4 wheel
  ;;   parity (src/backends/wasm.nx 87 functions): emit-time state is
  ;;   the seed projection of the wheel's `body_context` +
  ;;   `string_table` handlers-with-state plus the implicit
  ;;   `collect_fn_names` pre-pass result.
  ;;
  ;;   1. Funcref-table accumulator (per §3 H1.4) — flat list of fn
  ;;      name str_ptrs. Append-only across the whole emit pass; emit
  ;;      reads at table-section emission via $emit_funcref_at(idx).
  ;;      Mirror of wheel's collect_fn_names sweep (lines 444-475)
  ;;      flattened across emit_handler.wat / emit_call.wat append
  ;;      sites. NOT a vtable (Drift 1 refusal); the table IS the
  ;;      dispatch substrate per kernel primitive #2 Handlers — closure
  ;;      record's fn_idx field + call_indirect IS the dispatch.
  ;;
  ;;   2. Body-context (per §5.2 + wheel src/backends/wasm.nx:960-961
  ;;      set_body_captures + set_body_evidence) — current fn's
  ;;      captures_count (the H1 fence between captures and evidence
  ;;      in __state) + evidence list (H1.6 LEvPerform offset
  ;;      arithmetic; list of fn_idx ints per evidence slot). Reset
  ;;      at fn-emit boundary via $emit_fn_reset.
  ;;
  ;;   3. String-intern table (per W5 + wheel src/backends/wasm.nx:
  ;;      117-128 string_table handler + 194-198 collect_string_literals
  ;;      pre-pass) — flat list of STRING_INTERN_ENTRY records (tag
  ;;      360, arity 2: str_ptr + offset_int). Append-on-miss via
  ;;      $emit_string_intern; lookup-or-fail via $emit_string_lookup.
  ;;      Persists program-wide; $emit_fn_reset does NOT clear it.
  ;;
  ;; Eight interrogations (per Hβ-emit-substrate.md §5.1 + §3.1-§3.5
  ;; of this commit's plan):
  ;;   1. Graph?       state.wat does not chase. Funcref-table holds
  ;;                   name strings (downstream emit reads via
  ;;                   $emit_funcref_at); body-context evidence holds
  ;;                   fn_idx ints; string-intern holds (str, offset)
  ;;                   pairs — none chase the graph.
  ;;   2. Handler?     Wheel's body_context (set_body_captures /
  ;;                   set_body_evidence at src/backends/wasm.nx:960-
  ;;                   961, @resume=OneShot) + string_table (lines
  ;;                   117-128, @resume=OneShot). Seed projection: direct
  ;;                   $emit_* functions; the wheel compiles handler-
  ;;                   shape from src/backends/wasm.nx.
  ;;   3. Verb?        N/A at substrate level.
  ;;   4. Row?         EfPure — state.wat performs no effect ops.
  ;;                   Wheel's body_context composes with WasmOut +
  ;;                   Diagnostic per spec 05; seed elides row machinery.
  ;;   5. Ownership?   Funcref-table OWNS by emit pass; body-context
  ;;                   replaced per fn at $emit_set_body_context;
  ;;                   string-intern OWNS by emit pass. Length-only
  ;;                   reset at $emit_fn_reset for body-context only;
  ;;                   funcref + string tables persist program-wide
  ;;                   per wheel canonical (emit_module builds them
  ;;                   once at lines 162-185).
  ;;   6. Refinement?  N/A — refinements verify-ledger-side, not emit.
  ;;   7. Gradient?    Funcref-table IS where H1.4 single-handler-per-op
  ;;                   becomes physical at WAT — each registered fn is
  ;;                   one direct-call-eligible entry; LSuspend's
  ;;                   call_indirect reads from this same table. The
  ;;                   row inference's monomorphic-vs-polymorphic
  ;;                   gradient cashes out at chunk #6 emit_call.wat
  ;;                   reading these.
  ;;   8. Reason?      Read-only via graph; state.wat carries no Reason
  ;;                   data. Mentl's Why-Engine (Arc F.6) walks GNode
  ;;                   chains at handles downstream chunks receive —
  ;;                   emit-state is invisible to Why.
  ;;
  ;; Forbidden patterns audited (per Hβ-emit-substrate.md §6 + project
  ;; drift modes):
  ;;   - Drift 1 (Rust vtable):           NO closure-record-of-functions;
  ;;                                      $emit_* are direct fns. Funcref-
  ;;                                      table IS the dispatch substrate
  ;;                                      per primitive #2 Handlers; the
  ;;                                      word "vtable" appears nowhere.
  ;;   - Drift 5 (C calling convention):  NO separate __closure/__ev split;
  ;;                                      body-context's evidence list is
  ;;                                      stored as a single list ptr +
  ;;                                      length, mirroring how the wheel
  ;;                                      passes it as one List parameter.
  ;;   - Drift 7 (parallel-arrays):       String-intern uses STRING_INTERN_
  ;;                                      ENTRY records (tag 360, arity 2)
  ;;                                      — NOT parallel keys-ptr + offsets-
  ;;                                      ptr arrays. Funcref-table stores
  ;;                                      raw str_ptrs in one list (single-
  ;;                                      field; no record wrap ceremony per
  ;;                                      wheel collect_fn_names shape).
  ;;   - Drift 8 (string-keyed-as-flag):  Tag region 360-379 is integer
  ;;                                      constants reserved emit-private;
  ;;                                      idempotent flag is i32 0/1 boolean.
  ;;   - Drift 9 (deferred-by-omission):  Every $emit_* helper has its body;
  ;;                                      no silent stubs. The string-intern
  ;;                                      handler-shape that the wheel uses
  ;;                                      composes structurally identical
  ;;                                      with seed's direct fn — no peer
  ;;                                      handle deferred.
  ;;   - Foreign fluency:                 Vocabulary stays Inka — "table"
  ;;                                      (WAT-native), "intern table"
  ;;                                      (W5-native), "body context"
  ;;                                      (wheel-native). NOT "registry" /
  ;;                                      "cache" / "manager."
  ;;
  ;; Tag region: emit-private 360-379.
  ;;   360   STRING_INTERN_ENTRY_TAG  — (str_ptr, offset_int) 2-field
  ;;   361-379 reserved for future emit-substrate records
  ;;
  ;; Named follow-ups (per Drift 9 + Hβ-emit-substrate.md §10):
  ;;   - Hβ.emit.evidence-slot-naming:  full op_<name>_idx naming
  ;;                                    convention per H1.4; ties to
  ;;                                    emit_handler.wat funcref-table
  ;;                                    layout. body-context evidence
  ;;                                    list currently holds raw fn_idx
  ;;                                    ints; named-follow-up resolves
  ;;                                    the per-op naming.
  ;;   - Hβ.emit.string-intern-pre-pass: wheel does
  ;;                                    collect_string_literals as a
  ;;                                    SEPARATE pre-pass (src/backends/
  ;;                                    wasm.nx:194-198) before
  ;;                                    emit_string_data emits all data
  ;;                                    segments. Seed currently runs
  ;;                                    intern lazily per LConst(LString)
  ;;                                    arm; chunk #9 main.wat closes
  ;;                                    via call $emit_string_data
  ;;                                    flushing the table — substrate
  ;;                                    matches wheel structurally.

  ;; ─── Module-level globals (per §2.6 of plan + wheel canonical) ──────

  ;; $emit_initialized — idempotent init flag.
  (global $emit_initialized              (mut i32) (i32.const 0))

  ;; Funcref-table accumulator. Flat list of fn name str_ptrs registered
  ;; via $emit_funcref_register (one per LDeclareFn / LMakeClosure /
  ;; LMakeContinuation emit per H1.4 single-handler-per-op naming).
  ;; Length tracked separately per buffer-counter substrate (Ω.3); buffer
  ;; grows via $list_extend_to as length crosses capacity. Mirror of
  ;; wheel collect_fn_names result shape (src/backends/wasm.nx:444-475).
  (global $emit_funcref_table_ptr        (mut i32) (i32.const 0))
  (global $emit_funcref_table_len_g      (mut i32) (i32.const 0))

  ;; Body-context: captures_count + evidence list. Per wheel
  ;; src/backends/wasm.nx:960-961 set_body_captures + set_body_evidence
  ;; perform sites + H1 closure-record fence (offset 8 + 4*nc + 4*j) +
  ;; H1.6 LEvPerform offset arithmetic. Replaced per fn at
  ;; $emit_set_body_context; cleared at $emit_fn_reset.
  (global $emit_body_captures_count_g    (mut i32) (i32.const 0))
  (global $emit_body_evidence_ptr        (mut i32) (i32.const 0))
  (global $emit_body_evidence_len_g      (mut i32) (i32.const 0))

  ;; String-intern table. Flat list of STRING_INTERN_ENTRY records
  ;; (tag 360, arity 2: str_ptr + offset_int). Per W5 + wheel
  ;; src/backends/wasm.nx:117-128 string_table handler + 194-198
  ;; collect_string_literals pre-pass. Persists program-wide;
  ;; $emit_fn_reset does NOT clear it. Initial offset 65536 per wheel
  ;; comment (line 191) — sits above static-closure region at 0x100
  ;; and below bump heap at 1MB.
  (global $emit_string_table_ptr         (mut i32) (i32.const 0))
  (global $emit_string_table_len_g       (mut i32) (i32.const 0))
  (global $emit_strings_next_offset_g    (mut i32) (i32.const 65536))

  ;; Fn-locals dedupe ledger. Per Hβ.first-light.match-arm-binding-
  ;; name-uniqueness Lock #4: per-fn-scoped, length-only-reset at
  ;; $emit_fn_reset; mirrors $emit_funcref_table_ptr shape.
  ;; $emit_pat_locals consults $emit_fn_local_check before each
  ;; (local $<name> i32) emission; duplicates short-circuit. The
  ;; substrate reads LPVar.name directly (Anchor 1) — no parallel
  ;; name source.
  (global $emit_fn_locals_ptr            (mut i32) (i32.const 0))
  (global $emit_fn_locals_len_g          (mut i32) (i32.const 0))

  ;; ─── Idempotent initializer (mirrors $lower_init / $infer_init) ────
  ;; Per the seed's discipline for module-level state chunks: every
  ;; public entry calls $emit_init first; subsequent calls no-op.
  ;; Initial capacity 8 per buffer; $list_extend_to grows on demand.
  ;; Initial body-context evidence list is also size-8 — empty fns
  ;; (top-level body-less functions) install (0, empty_list, 0) via
  ;; $emit_set_body_context per Hβ-emit §3 H1 closure-record discipline.
  (func $emit_init
    (if (i32.eqz (global.get $emit_initialized))
      (then
        (global.set $emit_funcref_table_ptr     (call $make_list (i32.const 8)))
        (global.set $emit_funcref_table_len_g   (i32.const 0))
        (global.set $emit_body_captures_count_g (i32.const 0))
        (global.set $emit_body_evidence_ptr     (call $make_list (i32.const 8)))
        (global.set $emit_body_evidence_len_g   (i32.const 0))
        (global.set $emit_string_table_ptr      (call $make_list (i32.const 8)))
        (global.set $emit_string_table_len_g    (i32.const 0))
        (global.set $emit_strings_next_offset_g (i32.const 65536))
        (global.set $emit_fn_locals_ptr         (call $make_list (i32.const 8)))
        (global.set $emit_fn_locals_len_g       (i32.const 0))
        (global.set $emit_initialized           (i32.const 1)))))

  ;; ─── $emit_funcref_register — append name; return assigned index ───
  ;; Per Hβ-emit-substrate.md §3 H1.4 + wheel src/backends/wasm.nx:444-475
  ;; collect_fn_names + 583-619 emit_fn_table + emit_fn_index_globals.
  ;; De-dup via $str_eq scan; if name already present return its existing
  ;; index. Otherwise append and return new index. Seed convention: the
  ;; index assigned here matches the slot in the eventual (elem $fns ...)
  ;; emission and the i32 value of (global $<name>_idx).
  (func $emit_funcref_register (param $name i32) (result i32)
    (local $existing i32) (local $new_idx i32) (local $new_len i32)
    (call $emit_init)
    (local.set $existing (call $emit_funcref_lookup (local.get $name)))
    (if (i32.ge_s (local.get $existing) (i32.const 0))
      (then (return (local.get $existing))))
    (local.set $new_idx (global.get $emit_funcref_table_len_g))
    (local.set $new_len (i32.add (local.get $new_idx) (i32.const 1)))
    (global.set $emit_funcref_table_ptr
      (call $list_extend_to (global.get $emit_funcref_table_ptr) (local.get $new_len)))
    (drop (call $list_set (global.get $emit_funcref_table_ptr)
                          (local.get $new_idx)
                          (local.get $name)))
    (global.set $emit_funcref_table_len_g (local.get $new_len))
    (local.get $new_idx))

  ;; ─── $emit_funcref_lookup — index if name registered; -1 otherwise ─
  ;; Walks start-to-end (insertion order matches funcref-table emission
  ;; order). Returns -1 (i32 -1 = 0xFFFFFFFF tested via i32.lt_s by
  ;; callers) when not found.
  (func $emit_funcref_lookup (param $name i32) (result i32)
    (local $i i32) (local $n i32) (local $entry_name i32)
    (call $emit_init)
    (local.set $i (i32.const 0))
    (local.set $n (global.get $emit_funcref_table_len_g))
    (block $done
      (loop $iter
        (br_if $done (i32.ge_u (local.get $i) (local.get $n)))
        (local.set $entry_name
          (call $list_index (global.get $emit_funcref_table_ptr) (local.get $i)))
        (if (call $str_eq (local.get $entry_name) (local.get $name))
          (then (return (local.get $i))))
        (local.set $i (i32.add (local.get $i) (i32.const 1)))
        (br $iter)))
    (i32.const -1))

  ;; ─── $emit_funcref_count — current registered-fn count ─────────────
  (func $emit_funcref_count (result i32)
    (call $emit_init)
    (global.get $emit_funcref_table_len_g))

  ;; ─── $emit_funcref_at — name str_ptr at registered index ───────────
  ;; Per wheel emit_fn_refs (src/backends/wasm.nx:599-605) — iterated
  ;; at (elem $fns ...) emission to write each $<name> reference.
  (func $emit_funcref_at (param $idx i32) (result i32)
    (call $emit_init)
    (call $list_index (global.get $emit_funcref_table_ptr) (local.get $idx)))

  ;; ─── $emit_fn_local_check — register-or-no-op; return "is new" ─────
  ;; Per Hβ.first-light.match-arm-binding-name-uniqueness Lock #1:
  ;; returns 1 IFF $name was not previously registered for the current
  ;; fn AND has just been appended to the ledger. Returns 0 IFF $name
  ;; was already present (no append performed). Mirrors
  ;; $emit_funcref_register's idempotent-on-repeat shape.
  (func $emit_fn_local_check (param $name i32) (result i32)
    (local $existing i32) (local $new_idx i32) (local $new_len i32)
    (call $emit_init)
    (local.set $existing (call $emit_fn_local_lookup (local.get $name)))
    (if (i32.ge_s (local.get $existing) (i32.const 0))
      (then (return (i32.const 0))))
    (local.set $new_idx (global.get $emit_fn_locals_len_g))
    (local.set $new_len (i32.add (local.get $new_idx) (i32.const 1)))
    (global.set $emit_fn_locals_ptr
      (call $list_extend_to (global.get $emit_fn_locals_ptr) (local.get $new_len)))
    (drop (call $list_set (global.get $emit_fn_locals_ptr)
                          (local.get $new_idx)
                          (local.get $name)))
    (global.set $emit_fn_locals_len_g (local.get $new_len))
    (i32.const 1))

  ;; ─── $emit_fn_local_lookup — idx if registered; -1 otherwise ───────
  ;; Mirrors $emit_funcref_lookup. Linear $str_eq scan. Insertion-order
  ;; preservation is incidental — only presence matters for the dedupe.
  (func $emit_fn_local_lookup (param $name i32) (result i32)
    (local $i i32) (local $n i32) (local $entry_name i32)
    (call $emit_init)
    (local.set $i (i32.const 0))
    (local.set $n (global.get $emit_fn_locals_len_g))
    (block $done
      (loop $iter
        (br_if $done (i32.ge_u (local.get $i) (local.get $n)))
        (local.set $entry_name
          (call $list_index (global.get $emit_fn_locals_ptr) (local.get $i)))
        (if (call $str_eq (local.get $entry_name) (local.get $name))
          (then (return (local.get $i))))
        (local.set $i (i32.add (local.get $i) (i32.const 1)))
        (br $iter)))
    (i32.const -1))

  ;; ─── $emit_set_body_context — install per-fn captures + evidence ───
  ;; Per Hβ-emit-substrate.md §5.2 + wheel src/backends/wasm.nx:960-961.
  ;; Called at fn-emit entry by chunk #7 emit_handler.wat at every
  ;; LMakeClosure / LMakeContinuation / LDeclareFn arm. ev_list_ptr
  ;; is `ref` from caller (LowExpr's evidence list per H1.6); state.wat
  ;; stores the pointer + length without copying.
  (func $emit_set_body_context (param $captures_count i32)
                                (param $ev_list_ptr i32)
                                (param $ev_list_len i32)
    (call $emit_init)
    (global.set $emit_body_captures_count_g (local.get $captures_count))
    (global.set $emit_body_evidence_ptr     (local.get $ev_list_ptr))
    (global.set $emit_body_evidence_len_g   (local.get $ev_list_len)))

  ;; ─── $emit_body_captures_count — current fn's captures count ───────
  (func $emit_body_captures_count (result i32)
    (call $emit_init)
    (global.get $emit_body_captures_count_g))

  ;; ─── $emit_body_evidence — current fn's evidence list ptr ──────────
  (func $emit_body_evidence (result i32)
    (call $emit_init)
    (global.get $emit_body_evidence_ptr))

  ;; ─── $emit_body_evidence_len — current fn's evidence list length ──
  (func $emit_body_evidence_len (result i32)
    (call $emit_init)
    (global.get $emit_body_evidence_len_g))

  ;; ─── $emit_string_intern — assign offset; de-dup via $str_eq ───────
  ;; Per W5 + wheel src/backends/wasm.nx:117-128 string_table handler +
  ;; 194-198 collect_string_literals. On miss: append STRING_INTERN_ENTRY
  ;; (tag 360, arity 2) with current $emit_strings_next_offset_g; bump
  ;; next_offset by aligned (4 + str_len) per wheel byte_len discipline
  ;; (line 211: aligned_size = (size + 3) / 4 * 4). Returns assigned
  ;; offset.
  (func $emit_string_intern (param $s i32) (result i32)
    (local $existing i32) (local $offset i32) (local $entry i32)
    (local $size i32) (local $aligned i32) (local $new_len i32)
    (call $emit_init)
    (local.set $existing (call $emit_string_lookup (local.get $s)))
    (if (i32.ge_s (local.get $existing) (i32.const 0))
      (then (return (local.get $existing))))
    (local.set $offset (global.get $emit_strings_next_offset_g))
    (local.set $entry (call $make_record (i32.const 360) (i32.const 2)))
    (call $record_set (local.get $entry) (i32.const 0) (local.get $s))
    (call $record_set (local.get $entry) (i32.const 1) (local.get $offset))
    (local.set $new_len
      (i32.add (global.get $emit_string_table_len_g) (i32.const 1)))
    (global.set $emit_string_table_ptr
      (call $list_extend_to (global.get $emit_string_table_ptr) (local.get $new_len)))
    (drop (call $list_set (global.get $emit_string_table_ptr)
                          (global.get $emit_string_table_len_g)
                          (local.get $entry)))
    (global.set $emit_string_table_len_g (local.get $new_len))
    ;; Bump next_offset by aligned (4 + str_len). Per wheel line 212
    ;; aligned_size = (size + 3) / 4 * 4.
    (local.set $size (i32.add (i32.const 4) (call $str_len (local.get $s))))
    (local.set $aligned
      (i32.mul (i32.div_u (i32.add (local.get $size) (i32.const 3))
                          (i32.const 4))
               (i32.const 4)))
    (global.set $emit_strings_next_offset_g
      (i32.add (local.get $offset) (local.get $aligned)))
    (local.get $offset))

  ;; ─── $emit_string_lookup — offset if interned; -1 otherwise ────────
  ;; Walks start-to-end (insertion order); $str_eq compares.
  (func $emit_string_lookup (param $s i32) (result i32)
    (local $i i32) (local $n i32) (local $entry i32) (local $entry_str i32)
    (call $emit_init)
    (local.set $i (i32.const 0))
    (local.set $n (global.get $emit_string_table_len_g))
    (block $done
      (loop $iter
        (br_if $done (i32.ge_u (local.get $i) (local.get $n)))
        (local.set $entry
          (call $list_index (global.get $emit_string_table_ptr) (local.get $i)))
        (local.set $entry_str (call $record_get (local.get $entry) (i32.const 0)))
        (if (call $str_eq (local.get $entry_str) (local.get $s))
          (then (return (call $record_get (local.get $entry) (i32.const 1)))))
        (local.set $i (i32.add (local.get $i) (i32.const 1)))
        (br $iter)))
    (i32.const -1))

  ;; ─── $emit_string_table_count — interned-string count ──────────────
  (func $emit_string_table_count (result i32)
    (call $emit_init)
    (global.get $emit_string_table_len_g))

  ;; ─── $emit_string_table_at — STRING_INTERN_ENTRY at index ──────────
  ;; Per wheel emit_string_data_loop (src/backends/wasm.nx:423-434) —
  ;; iterated at (data ...) segment emission to write each string body.
  ;; Returns the record (caller does record_get(0) for str + record_get(1)
  ;; for offset).
  (func $emit_string_table_at (param $idx i32) (result i32)
    (call $emit_init)
    (call $list_index (global.get $emit_string_table_ptr) (local.get $idx)))

  ;; ─── $emit_fn_reset — clear body-context at fn-emit boundary ───────
  ;; Per Hβ-emit-substrate.md §5.2 + wheel src/backends/wasm.nx:945-978
  ;; emit_fn_body invocation pattern (perform set_body_captures /
  ;; set_body_evidence each fn). Length-only-reset semantics for
  ;; evidence; does NOT clear funcref-table or string-intern (program-
  ;; wide per wheel emit_module sequence at lines 162-185). Mirror of
  ;; $ls_reset_function discipline at lower/state.wat:240-249.
  (func $emit_fn_reset
    (call $emit_init)
    (global.set $emit_body_captures_count_g (i32.const 0))
    (global.set $emit_body_evidence_len_g   (i32.const 0))
    (global.set $emit_fn_locals_len_g       (i32.const 0)))
