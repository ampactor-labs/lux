  ;; ═══ state_init.wat — Hβ.lower trace-harness ═══════════════════════
  ;; Executes: Hβ-lower-substrate.md §1.2 — LowerCtx state shape
  ;;           (locals + captures ledgers + slot counter + idempotent init).
  ;; Exercises: state.wat — $lower_init $ls_bind_local $ls_lookup_local
  ;;            $ls_lookup_or_capture $ls_reset_function $lower_locals_len
  ;;            $lower_captures_len.
  ;; Per ROADMAP §5 + Hβ-lower-substrate.md §10.1 + §10.4 acceptance.
  ;;
  ;; ─── Eight interrogations (per Hβ-lower §5.1 second pass) ─────────
  ;;   Graph?      Mints fresh ty handles via $graph_fresh_ty for the
  ;;               LOCAL_ENTRY ty_handle field; state.wat itself never
  ;;               chases — the harness verifies the field round-trips.
  ;;   Handler?    Direct calls to $ls_* (seed Tier-4 base; @resume=OneShot
  ;;               at the wheel per LowerState ops src/lower.nx:45-92).
  ;;   Verb?       N/A — sequential helper invocations.
  ;;   Row?        Pure — no row touched.
  ;;   Ownership?  Locals + captures OWN by current "function" (the harness
  ;;               simulates a single fn lifecycle); $ls_reset_function
  ;;               clears between checkpoints.
  ;;   Refinement? None.
  ;;   Gradient?   This harness IS one pixel of §10.1 acceptance —
  ;;               proves the LowerCtx ledger shape lands correctly so
  ;;               walk_*.wat can compose on it.
  ;;   Reason?     ty_handle field round-trip; the GNode at that handle
  ;;               carries the Reason — harness only verifies handle
  ;;               equality, not Reason content.

  ;; ─── Harness-private data segment (offsets ≥ 3072, < HEAP_BASE) ──

  (data (i32.const 3072) "\05\00\00\00PASS:")
  (data (i32.const 3084) "\05\00\00\00FAIL:")
  (data (i32.const 3096) "\01\00\00\00 ")
  (data (i32.const 3104) "\01\00\00\00\0a")

  ;; Harness display name — offset 3120
  (data (i32.const 3120) "\10\00\00\00lower_state_init")

  ;; Per-assertion FAIL labels — offsets 3144+
  (data (i32.const 3144) "\14\00\00\00slot-x-not-zero     ")
  (data (i32.const 3168) "\12\00\00\00slot-y-not-one    ")
  (data (i32.const 3192) "\11\00\00\00lookup-x-miss    ")
  (data (i32.const 3216) "\11\00\00\00lookup-y-miss    ")
  (data (i32.const 3240) "\1c\00\00\00lookup-z-not-negative-one   ")
  (data (i32.const 3272) "\14\00\00\00reset-locals-len    ")
  (data (i32.const 3296) "\17\00\00\00reset-slot-counter-x   ")
  (data (i32.const 3324) "\1a\00\00\00captures-len-not-zero-init")
  (data (i32.const 3356) "\1c\00\00\00captures-len-not-one-after  ")
  (data (i32.const 3388) "\17\00\00\00capture-idx-not-zero   ")
  (data (i32.const 3416) "\1a\00\00\00capture-recall-not-same   ")

  ;; Test names — minimal source strings for binding
  (data (i32.const 3448) "\01\00\00\00x")
  (data (i32.const 3456) "\01\00\00\00y")
  (data (i32.const 3464) "\01\00\00\00z")
  (data (i32.const 3472) "\01\00\00\00w")

  ;; ─── _start ──────────────────────────────────────────────────────
  (func $_start (export "_start")
    (local $failed i32)
    (local $h_x i32) (local $h_y i32)
    (local $slot_x i32) (local $slot_y i32)
    (local $look_x i32) (local $look_y i32) (local $look_z i32)
    (local $cap_idx_first i32) (local $cap_idx_recall i32)
    (local.set $failed (i32.const 0))
    (call $graph_init)
    (call $env_init)
    (call $lower_init)

    ;; ── Phase 1: $ls_bind_local assigns slot 0, then 1 ──
    (local.set $h_x (call $graph_fresh_ty (i32.const 0)))
    (local.set $h_y (call $graph_fresh_ty (i32.const 0)))
    (local.set $slot_x (call $ls_bind_local (i32.const 3448) (local.get $h_x)))
    (local.set $slot_y (call $ls_bind_local (i32.const 3456) (local.get $h_y)))

    (if (i32.ne (local.get $slot_x) (i32.const 0))
      (then
        (call $eprint_string (i32.const 3144))
        (call $eprint_string (i32.const 3104))
        (local.set $failed (i32.const 1))))

    (if (i32.ne (local.get $slot_y) (i32.const 1))
      (then
        (call $eprint_string (i32.const 3168))
        (call $eprint_string (i32.const 3104))
        (local.set $failed (i32.const 1))))

    ;; ── Phase 2: $ls_lookup_local resolves both names ──
    (local.set $look_x (call $ls_lookup_local (i32.const 3448)))
    (local.set $look_y (call $ls_lookup_local (i32.const 3456)))

    (if (i32.ne (local.get $look_x) (i32.const 0))
      (then
        (call $eprint_string (i32.const 3192))
        (call $eprint_string (i32.const 3104))
        (local.set $failed (i32.const 1))))

    (if (i32.ne (local.get $look_y) (i32.const 1))
      (then
        (call $eprint_string (i32.const 3216))
        (call $eprint_string (i32.const 3104))
        (local.set $failed (i32.const 1))))

    ;; ── Phase 3: lookup-miss returns -1 ──
    ;; "z" is neither a local nor in env (env_init pushed empty global scope).
    (local.set $look_z (call $ls_lookup_local (i32.const 3464)))
    (if (i32.ne (local.get $look_z) (i32.const -1))
      (then
        (call $eprint_string (i32.const 3240))
        (call $eprint_string (i32.const 3104))
        (local.set $failed (i32.const 1))))

    ;; ── Phase 4: $ls_reset_function clears locals + slot counter ──
    (call $ls_reset_function)

    (if (i32.ne (call $lower_locals_len) (i32.const 0))
      (then
        (call $eprint_string (i32.const 3272))
        (call $eprint_string (i32.const 3104))
        (local.set $failed (i32.const 1))))

    ;; Bind a fresh local; slot must be 0 again (counter reset).
    (if (i32.ne (call $ls_bind_local (i32.const 3448) (local.get $h_x))
                (i32.const 0))
      (then
        (call $eprint_string (i32.const 3296))
        (call $eprint_string (i32.const 3104))
        (local.set $failed (i32.const 1))))

    ;; ── Phase 5: $ls_lookup_or_capture records a capture ──
    ;; Reset, then extend env to bind "w" so env_contains("w") returns 1.
    (call $ls_reset_function)
    ;; Push a binding into env to make "w" outer-scope-reachable.
    ;; Use sentinel scheme/reason/kind ptrs (0 — env.wat's $env_extend
    ;; accepts these as opaque pointers; the harness never reads them).
    (call $env_extend (i32.const 3472) (i32.const 0) (i32.const 0)
                       (call $schemekind_make_fn))

    ;; First lookup_or_capture("w") records capture at index 0.
    (local.set $cap_idx_first (call $ls_lookup_or_capture (i32.const 3472)))
    (if (i32.ne (call $lower_captures_len) (i32.const 1))
      (then
        (call $eprint_string (i32.const 3356))
        (call $eprint_string (i32.const 3104))
        (local.set $failed (i32.const 1))))

    (if (i32.ne (local.get $cap_idx_first) (i32.const 0))
      (then
        (call $eprint_string (i32.const 3388))
        (call $eprint_string (i32.const 3104))
        (local.set $failed (i32.const 1))))

    ;; Second lookup_or_capture("w") returns same capture index (no dup).
    (local.set $cap_idx_recall (call $ls_lookup_or_capture (i32.const 3472)))
    (if (i32.ne (local.get $cap_idx_recall) (local.get $cap_idx_first))
      (then
        (call $eprint_string (i32.const 3416))
        (call $eprint_string (i32.const 3104))
        (local.set $failed (i32.const 1))))

    ;; ── Verdict ──
    (if (local.get $failed)
      (then
        (call $eprint_string (i32.const 3084))   ;; "FAIL:"
        (call $eprint_string (i32.const 3096))   ;; " "
        (call $eprint_string (i32.const 3120))   ;; "lower_state_init"
        (call $eprint_string (i32.const 3104))   ;; "\n"
        (call $wasi_proc_exit (i32.const 1)))
      (else
        (call $eprint_string (i32.const 3072))   ;; "PASS:"
        (call $eprint_string (i32.const 3096))   ;; " "
        (call $eprint_string (i32.const 3120))   ;; "lower_state_init"
        (call $eprint_string (i32.const 3104))   ;; "\n"
        (call $wasi_proc_exit (i32.const 0)))))
