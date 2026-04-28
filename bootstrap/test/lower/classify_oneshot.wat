  ;; ═══ classify_oneshot.wat — Hβ.lower trace-harness ═════════════════
  ;; Executes: Hβ-lower-substrate.md §3.1 lines 331-334 — $classify_handler
  ;;           on a TCont(_, OneShot) handle returns 1 (Linear) per the
  ;;           conservative-seed default at $is_tail_resumptive.
  ;; Exercises: classify.wat — $classify_handler + $is_tail_resumptive.
  ;;
  ;; Eight interrogations:
  ;;   Graph?      $graph_fresh_ty + $graph_bind populate the NBound edge
  ;;               $lookup_ty chases.
  ;;   Handler?    Direct call to $classify_handler (seed Tier-7 base).
  ;;   Verb?       N/A — sequential.
  ;;   Row?        Pure — TCont sentinel handler discipline only.
  ;;   Ownership?  Bound TCont is `ref` (graph owns); harness verifies
  ;;               return code equality.
  ;;   Refinement? None.
  ;;   Gradient?   This harness IS the proof that OneShot defaults to
  ;;               Linear per the seed's wheel-parity discipline.
  ;;   Reason?     $graph_bind records reason 0 (sentinel); not surfaced.

  (data (i32.const 3072) "\05\00\00\00PASS:")
  (data (i32.const 3084) "\05\00\00\00FAIL:")
  (data (i32.const 3096) "\01\00\00\00 ")
  (data (i32.const 3104) "\01\00\00\00\0a")
  (data (i32.const 3120) "\17\00\00\00lower_classify_oneshot ")
  (data (i32.const 3152) "\1c\00\00\00classify-oneshot-not-linear")

  (func $_start (export "_start")
    (local $failed i32)
    (local $h i32) (local $tint i32) (local $tcont i32) (local $strat i32)
    (local.set $failed (i32.const 0))
    (call $graph_init)

    ;; Phase 1: build TCont(TInt, OneShot=250).
    (local.set $tint (call $ty_make_tint))
    (local.set $tcont (call $ty_make_tcont (local.get $tint) (i32.const 250)))

    ;; Phase 2: bind a fresh handle to TCont.
    (local.set $h (call $graph_fresh_ty (i32.const 0)))
    (call $graph_bind (local.get $h) (local.get $tcont) (i32.const 0))

    ;; Phase 3: $classify_handler returns 1 (Linear) per
    ;; conservative-Linear $is_tail_resumptive seed default.
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
