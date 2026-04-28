  ;; ═══ classify_either.wat — Hβ.lower trace-harness ══════════════════
  ;; Executes: Hβ-lower-substrate.md §3.1 lines 337-340 + §11 line 922 —
  ;;           $classify_handler on a TCont(_, Either=252) handle returns
  ;;           1 (Linear) per the §11 walkthrough seed-default lock at
  ;;           $either_strategy.
  ;; Exercises: classify.wat — $classify_handler + $either_strategy.
  ;;
  ;; Eight interrogations:
  ;;   Graph?      $graph_fresh_ty + $graph_bind populate the NBound edge.
  ;;   Handler?    Direct call to $classify_handler.
  ;;   Verb?       N/A.
  ;;   Row?        Pure.
  ;;   Ownership?  ref (graph owns).
  ;;   Refinement? None.
  ;;   Gradient?   This harness IS the proof that Either defaults to
  ;;               Linear per §11 lock; future install-time negotiation
  ;;               under named follow-up Hβ.lower.either-install-negotiation.
  ;;   Reason?     $graph_bind reason 0; not surfaced.

  (data (i32.const 3072) "\05\00\00\00PASS:")
  (data (i32.const 3084) "\05\00\00\00FAIL:")
  (data (i32.const 3096) "\01\00\00\00 ")
  (data (i32.const 3104) "\01\00\00\00\0a")
  (data (i32.const 3120) "\16\00\00\00lower_classify_either ")
  (data (i32.const 3152) "\1b\00\00\00classify-either-not-linear")

  (func $_start (export "_start")
    (local $failed i32)
    (local $h i32) (local $tint i32) (local $tcont i32) (local $strat i32)
    (local.set $failed (i32.const 0))
    (call $graph_init)

    ;; Phase 1: build TCont(TInt, Either=252).
    (local.set $tint (call $ty_make_tint))
    (local.set $tcont (call $ty_make_tcont (local.get $tint) (i32.const 252)))

    ;; Phase 2: bind a fresh handle to TCont.
    (local.set $h (call $graph_fresh_ty (i32.const 0)))
    (call $graph_bind (local.get $h) (local.get $tcont) (i32.const 0))

    ;; Phase 3: $classify_handler returns 1 (Linear) per §11 line 922
    ;; Either-discipline seed-default lock.
    (local.set $strat (call $classify_handler (local.get $h)))
    (if (i32.ne (local.get $strat) (i32.const 1))
      (then
        (call $eprint_string (i32.const 3152))
        (call $eprint_string (i32.const 3104))
        (local.set $failed (i32.const 1))))

    ;; Verdict.
    (if (local.get $failed)
      (then
        (call $eprint_string (i32.const 3084))
        (call $eprint_string (i32.const 3096))
        (call $eprint_string (i32.const 3120))
        (call $eprint_string (i32.const 3104))
        (call $wasi_proc_exit (i32.const 1)))
      (else
        (call $eprint_string (i32.const 3072))
        (call $eprint_string (i32.const 3096))
        (call $eprint_string (i32.const 3120))
        (call $eprint_string (i32.const 3104))
        (call $wasi_proc_exit (i32.const 0)))))
