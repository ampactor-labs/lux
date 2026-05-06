  ;; ═══ state.wat — inference per-walk scratchpads (Tier 4) ═══════════
  ;; Implements: Hβ-infer-substrate.md §1 — module-level globals for
  ;;             the inference walk (ref-escape tracker, fn-stack,
  ;;             span/intent indices) + $infer_init idempotent.
  ;; Exports:    $infer_init,
  ;;             $infer_ref_escape_push, $infer_ref_escape_len,
  ;;             $infer_ref_escape_clear_state,
  ;;             $infer_fn_stack_push, $infer_fn_stack_pop,
  ;;             $infer_fn_stack_top, $infer_fn_stack_len,
  ;;             $infer_span_index_append, $infer_intent_index_append,
  ;;             $infer_reset_walk
  ;; Uses:       $alloc (alloc.wat),
  ;;             $make_list / $list_set / $list_index / $list_extend_to /
  ;;             $len (list.wat),
  ;;             $make_record / $record_get / $record_set (record.wat)
  ;; Test:       runtime_test/infer_state.wat (pending — first acceptance is
  ;;             $infer_*-grep + wasm-validate per Hβ-infer-substrate.md §11)
  ;;
  ;; What these scratchpads ARE (per Hβ-infer-substrate.md §1):
  ;;   The inference walk maintains FOUR per-walk scratchpads beyond
  ;;   what graph.wat (the constraint store) and env.wat (the scope
  ;;   stack) hold. They are scoped to the walk; downstream passes
  ;;   (lower / emit / query) read graph.wat instead. Materialized
  ;;   into graph entries at appropriate boundaries.
  ;;
  ;;   1. ref-escape tracker  — list of (name_str_ptr, span_ptr).
  ;;      VarRefs annotated `ref` push here at lookup; FnStmt exit
  ;;      walks against return position per spec 07 escape analysis.
  ;;   2. fn-stack            — list of i32 (FnStmt handles).
  ;;      Stack-shaped for nested fns; $generalize at FnStmt exit
  ;;      reads top to know which env entries are part of THIS fn's
  ;;      body. Pure i32 entries — no record wrap.
  ;;   3. span index          — list of (span_ptr, handle).
  ;;      Per src/graph.mn graph_index_span; query layer reads after
  ;;      inference for cursor-position lookups.
  ;;   4. intent index        — list of (handle, declared_effects).
  ;;      Per src/graph.mn graph_index_intent; query reads for
  ;;      "what handlers would this fn need?" surfaces.
  ;;
  ;; Eight interrogations at this chunk's edit sites (per §6.1):
  ;;   1. Graph?       fn_stack holds graph handles allocated by
  ;;                   $graph_fresh_ty/_row at FnStmt; span/intent
  ;;                   indices pair handles with source positions.
  ;;   2. Handler?     The seed's inference is direct functions; the
  ;;                   wheel compiles handler-shape from src/infer.mn.
  ;;                   These globals are the seed's interim — they do
  ;;                   NOT survive into the wheel's compiled form.
  ;;   3. Verb?        N/A at substrate level.
  ;;   4. Row?         ref_escape interacts with the Consume row entry
  ;;                   per spec 04 §Ownership; intent_index records
  ;;                   declared effects per FnStmt.
  ;;   5. Ownership?   Scratchpads OWN by inference walk; cleared at
  ;;                   $infer_reset_walk; entries `ref` to source spans
  ;;                   + handles allocated upstream.
  ;;   6. Refinement?  N/A — refinement obligations land in verify.wat's
  ;;                   ledger, not here.
  ;;   7. Gradient?    fn_stack depth is one gradient signal (nesting
  ;;                   level for diagnostics); ref_escape length signals
  ;;                   how many borrows are still live at any point.
  ;;   8. Reason?      span/intent indices are query-layer surfaces
  ;;                   that walk reasons later (the entries themselves
  ;;                   carry no Reason — they index TO Reason chains
  ;;                   stored in graph.wat's NBound nodes).
  ;;
  ;; Forbidden patterns audited (per §7):
  ;;   - Drift 1 (vtable):                  no dispatch table; helpers are direct fns.
  ;;   - Drift 7 (parallel-arrays-vs-record): (name, span) and (span, handle)
  ;;                                        and (handle, effs) all use $make_record(2)
  ;;                                        — NOT parallel `_names_ptr` + `_spans_ptr` arrays.
  ;;   - Drift 8 (string-keyed):            record tags are integer constants
  ;;                                        (210/211/212) per the walkthrough's
  ;;                                        reserved 200-219 region for infer-private records.
  ;;   - Drift 9 (deferred-by-omission):    every helper named here has its body;
  ;;                                        no `;; TODO:` placeholders.

  ;; ─── Per-walk scratchpads (module-level globals) ─────────────────
  (global $infer_initialized        (mut i32) (i32.const 0))

  ;; Ref-escape tracker. Flat list of (name_str_ptr, span_ptr) records
  ;; tagged REF_ESCAPE_ENTRY_TAG=210. Length tracked separately per
  ;; the buffer-counter substrate (Ω.3); buffer grows via
  ;; $list_extend_to as length crosses capacity.
  (global $infer_ref_escape_ptr     (mut i32) (i32.const 0))
  (global $infer_ref_escape_len_g   (mut i32) (i32.const 0))

  ;; FnStmt-handle stack. Flat list of i32 handles (no record wrap —
  ;; pure i32 entries). Length tracks current top-of-stack + 1.
  (global $infer_fn_stack_ptr       (mut i32) (i32.const 0))
  (global $infer_fn_stack_len_g     (mut i32) (i32.const 0))

  ;; Span index. Flat list of (span_ptr, handle) records tagged
  ;; SPAN_INDEX_ENTRY_TAG=211.
  (global $infer_span_index_ptr     (mut i32) (i32.const 0))
  (global $infer_span_index_len_g   (mut i32) (i32.const 0))

  ;; Intent index. Flat list of (handle, eff_row_ptr) records tagged
  ;; INTENT_INDEX_ENTRY_TAG=212.
  (global $infer_intent_index_ptr   (mut i32) (i32.const 0))
  (global $infer_intent_index_len_g (mut i32) (i32.const 0))

  ;; ─── Idempotent initializer ──────────────────────────────────────
  ;; Allocates initial buffers for all four scratchpads. Public-entry
  ;; chunks ($infer_expr / $infer_stmt / $generalize) call this so the
  ;; seed can drive inference from any entry point. Initial capacity
  ;; 8 per buffer — $list_extend_to grows on demand.
  (func $infer_init
    (if (i32.eqz (global.get $infer_initialized))
      (then
        (global.set $infer_ref_escape_ptr   (call $make_list (i32.const 8)))
        (global.set $infer_ref_escape_len_g (i32.const 0))
        (global.set $infer_fn_stack_ptr     (call $make_list (i32.const 8)))
        (global.set $infer_fn_stack_len_g   (i32.const 0))
        (global.set $infer_span_index_ptr   (call $make_list (i32.const 8)))
        (global.set $infer_span_index_len_g (i32.const 0))
        (global.set $infer_intent_index_ptr (call $make_list (i32.const 8)))
        (global.set $infer_intent_index_len_g (i32.const 0))
        (global.set $infer_initialized      (i32.const 1)))))

  ;; ─── Ref-escape tracker helpers ──────────────────────────────────

  ;; Append (name_str, span) record to the ref-escape tracker.
  (func $infer_ref_escape_push (param $name i32) (param $span i32)
    (local $entry i32) (local $new_len i32)
    (call $infer_init)
    (local.set $entry (call $make_record (i32.const 210) (i32.const 2)))
    (call $record_set (local.get $entry) (i32.const 0) (local.get $name))
    (call $record_set (local.get $entry) (i32.const 1) (local.get $span))
    (local.set $new_len (i32.add (global.get $infer_ref_escape_len_g) (i32.const 1)))
    (global.set $infer_ref_escape_ptr
      (call $list_extend_to (global.get $infer_ref_escape_ptr) (local.get $new_len)))
    (drop (call $list_set (global.get $infer_ref_escape_ptr)
                          (global.get $infer_ref_escape_len_g)
                          (local.get $entry)))
    (global.set $infer_ref_escape_len_g (local.get $new_len)))

  ;; Current length of the ref-escape tracker.
  (func $infer_ref_escape_len (result i32)
    (call $infer_init)
    (global.get $infer_ref_escape_len_g))

  ;; ─── FnStmt-handle stack helpers ─────────────────────────────────

  ;; Push a FnStmt handle onto the inference stack.
  (func $infer_fn_stack_push (param $fn_handle i32)
    (local $new_len i32)
    (call $infer_init)
    (local.set $new_len (i32.add (global.get $infer_fn_stack_len_g) (i32.const 1)))
    (global.set $infer_fn_stack_ptr
      (call $list_extend_to (global.get $infer_fn_stack_ptr) (local.get $new_len)))
    (drop (call $list_set (global.get $infer_fn_stack_ptr)
                          (global.get $infer_fn_stack_len_g)
                          (local.get $fn_handle)))
    (global.set $infer_fn_stack_len_g (local.get $new_len)))

  ;; Pop the topmost FnStmt handle. Decrements length; the buffer slot
  ;; remains (bump allocator never frees) but is logically dead.
  ;; Trap on underflow — Hβ.infer's discipline is push-then-pop balanced
  ;; per FnStmt entry/exit; underflow signals a walk bug to surface.
  (func $infer_fn_stack_pop
    (call $infer_init)
    (if (i32.eqz (global.get $infer_fn_stack_len_g))
      (then (unreachable)))
    (global.set $infer_fn_stack_len_g
      (i32.sub (global.get $infer_fn_stack_len_g) (i32.const 1))))

  ;; Read the topmost FnStmt handle (without popping). Trap on empty.
  (func $infer_fn_stack_top (result i32)
    (call $infer_init)
    (if (i32.eqz (global.get $infer_fn_stack_len_g))
      (then (unreachable)))
    (call $list_index (global.get $infer_fn_stack_ptr)
                      (i32.sub (global.get $infer_fn_stack_len_g) (i32.const 1))))

  ;; Current depth of the FnStmt stack.
  (func $infer_fn_stack_len (result i32)
    (call $infer_init)
    (global.get $infer_fn_stack_len_g))

  ;; ─── Span index helpers ──────────────────────────────────────────

  ;; Append (span_ptr, handle) record to the span index.
  (func $infer_span_index_append (param $span i32) (param $handle i32)
    (local $entry i32) (local $new_len i32)
    (call $infer_init)
    (local.set $entry (call $make_record (i32.const 211) (i32.const 2)))
    (call $record_set (local.get $entry) (i32.const 0) (local.get $span))
    (call $record_set (local.get $entry) (i32.const 1) (local.get $handle))
    (local.set $new_len (i32.add (global.get $infer_span_index_len_g) (i32.const 1)))
    (global.set $infer_span_index_ptr
      (call $list_extend_to (global.get $infer_span_index_ptr) (local.get $new_len)))
    (drop (call $list_set (global.get $infer_span_index_ptr)
                          (global.get $infer_span_index_len_g)
                          (local.get $entry)))
    (global.set $infer_span_index_len_g (local.get $new_len)))

  ;; ─── Intent index helpers ────────────────────────────────────────

  ;; Append (handle, eff_row_ptr) record to the intent index.
  (func $infer_intent_index_append (param $handle i32) (param $effs i32)
    (local $entry i32) (local $new_len i32)
    (call $infer_init)
    (local.set $entry (call $make_record (i32.const 212) (i32.const 2)))
    (call $record_set (local.get $entry) (i32.const 0) (local.get $handle))
    (call $record_set (local.get $entry) (i32.const 1) (local.get $effs))
    (local.set $new_len (i32.add (global.get $infer_intent_index_len_g) (i32.const 1)))
    (global.set $infer_intent_index_ptr
      (call $list_extend_to (global.get $infer_intent_index_ptr) (local.get $new_len)))
    (drop (call $list_set (global.get $infer_intent_index_ptr)
                          (global.get $infer_intent_index_len_g)
                          (local.get $entry)))
    (global.set $infer_intent_index_len_g (local.get $new_len)))

  ;; ─── Defensive walk reset ────────────────────────────────────────
  ;; Clear all scratchpads. Called between top-level FnStmt walks if
  ;; needed; defensive against stale entries leaking across walks.
  ;; Length-only reset — buffers themselves stay (bump allocator never
  ;; frees); next push reuses the existing flat storage.
  (func $infer_reset_walk
    (call $infer_init)
    (global.set $infer_ref_escape_len_g   (i32.const 0))
    (global.set $infer_fn_stack_len_g     (i32.const 0))
    (global.set $infer_span_index_len_g   (i32.const 0))
    (global.set $infer_intent_index_len_g (i32.const 0)))

  ;; ─── Per-FnStmt-exit ref-escape reset ────────────────────────────
  ;; Finer-grained than $infer_reset_walk — clears only the ref-escape
  ;; tracker (not fn-stack / span-index / intent-index). Called by
  ;; own.wat's $infer_ref_escape_clear at FnStmt exit per src/own.mn:371-376
  ;; check_ref_escape lifecycle. Length-only reset (buffers stay).
  (func $infer_ref_escape_clear_state
    (call $infer_init)
    (global.set $infer_ref_escape_len_g (i32.const 0)))
