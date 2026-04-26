  ;; ═══ own_branch_collision.wat — trace-harness ═════════════════════
  ;; Executes: Hβ-infer-substrate.md §5 + src/own.nx:118-154 branch
  ;;           protocol + §11.2 acceptance — branch_enter / divider /
  ;;           exit with shared name "x" consumed in two parallel
  ;;           branches. Per src/own.nx:140-152:
  ;;             - branch_enter: snapshot used (empty); push frame.
  ;;             - branch1 consumes "x" via $infer_consume_use(h1, "x", ...).
  ;;             - branch_divider: capture branch1's delta = {x};
  ;;               reset used to base = {}.
  ;;             - branch2 consumes "x" via $infer_consume_use(h2, "x", ...).
  ;;             - branch_exit: capture branch2's delta = {x};
  ;;               $own_check_branch_collisions emits per-name collision
  ;;               via $infer_emit_branch_collision; merge used =
  ;;               base ∪ union(deltas) = {x}; pop frame.
  ;; Exercises: own.wat — $infer_branch_enter / _divider / _exit,
  ;;            $own_check_branch_collisions, $infer_emit_branch_collision.
  ;; Per ROADMAP §5 + Hβ-infer-substrate.md §11.
  ;;
  ;; ─── Eight interrogations ─────────────────────────────────────────
  ;;   Graph?      Two NFree handles; collision diagnostic does NOT
  ;;               $graph_bind_kind (per src/own.nx:343 — per-name,
  ;;               not per-handle). The handles' silent path is checked
  ;;               via "x is in used after merge" assertion.
  ;;   Handler?    Direct seed call.
  ;;   Verb?       Branch protocol simulates `><` / `<|` topology
  ;;               (branch_divider IS the verb's per-branch boundary
  ;;               at inference time).
  ;;   Row?        Caller's row gains Consume per branch; delta-set
  ;;               algebra preserves the parallel semantics.
  ;;   Ownership?  Frame stack OWNs per-branch deltas; merge restores
  ;;               base ∪ union semantics so post-exit "x" is in used
  ;;               (the violation surfaces as diagnostic, not as
  ;;               removed-name).
  ;;   Refinement? None.
  ;;   Gradient?   Collision IS gradient signal: same name in parallel
  ;;               branches = the affine constraint violated.
  ;;   Reason?     Per src/own.nx:343 the collision diagnostic drops
  ;;               the reason (no $graph_bind_kind to tie it to). The
  ;;               cause-chain Reason flows through caller's enclosing
  ;;               structural Reason (Located(branch_span, ...)).

  ;; Verdict labels (offsets ≥ 4096 to sit ABOVE own.wat's production
  ;; data range 3136-3382; harness/production overlap on diagnostic
  ;; emit paths broke the first iteration of this harness).
  (data (i32.const 4096) "\05\00\00\00PASS:")
  (data (i32.const 4128) "\05\00\00\00FAIL:")
  (data (i32.const 4160) "\01\00\00\00 ")
  (data (i32.const 4192) "\01\00\00\00\0a")

  ;; Harness display name
  (data (i32.const 4224) "\14\00\00\00own_branch_collision")

  ;; Per-assertion FAIL labels
  (data (i32.const 4256) "\14\00\00\00branches-not-empty  ")
  (data (i32.const 4288) "\14\00\00\00x-not-in-used-merged")

  ;; Static argument string
  (data (i32.const 4928) "\01\00\00\00x")

  (func $_start (export "_start")
    (local $failed i32)
    (local $h1 i32) (local $h2 i32)
    (local.set $failed (i32.const 0))
    (call $graph_init)
    (call $infer_used_clear)

    ;; ── Setup: branch_enter snapshots empty used ──
    (call $infer_branch_enter)

    ;; ── Branch 1: consume "x" on handle h1 ──
    (local.set $h1 (call $graph_fresh_ty (i32.const 0)))
    (call $infer_consume_use (local.get $h1) (i32.const 4928)
                              (i32.const 100) (i32.const 0))

    ;; ── Branch divider: capture branch1's delta = {x}; reset used ──
    (call $infer_branch_divider)

    ;; ── Branch 2: consume "x" on handle h2 (same name; different handle) ──
    (local.set $h2 (call $graph_fresh_ty (i32.const 0)))
    (call $infer_consume_use (local.get $h2) (i32.const 4928)
                              (i32.const 200) (i32.const 0))

    ;; ── Branch exit: capture branch2's delta + collision check + pop ──
    (call $infer_branch_exit (i32.const 300) (i32.const 0))

    ;; ── Assert $infer_branches_len_g == 0 after exit ──
    (if (i32.ne (global.get $infer_branches_len_g) (i32.const 0))
      (then
        (call $eprint_string (i32.const 4256))
        (call $eprint_string (i32.const 4192))
        (local.set $failed (i32.const 1))))

    ;; ── Assert "x" still in used after merge (base ∪ deltas semantics) ──
    (if (i32.eqz (call $infer_consume_seen (i32.const 4928)))
      (then
        (call $eprint_string (i32.const 4288))
        (call $eprint_string (i32.const 4192))
        (local.set $failed (i32.const 1))))

    ;; ── Verdict ──
    (if (local.get $failed)
      (then
        (call $eprint_string (i32.const 4128))
        (call $eprint_string (i32.const 4160))
        (call $eprint_string (i32.const 4224)))
      (else
        (call $eprint_string (i32.const 4096))
        (call $eprint_string (i32.const 4160))
        (call $eprint_string (i32.const 4224))))
    (call $eprint_string (i32.const 4192))
    (call $wasi_proc_exit (i32.const 0)))
