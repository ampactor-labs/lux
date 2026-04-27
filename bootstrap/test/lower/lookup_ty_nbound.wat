  ;; ═══ lookup_ty_nbound.wat — Hβ.lower trace-harness ═════════════════
  ;; Executes: Hβ-lower-substrate.md §1.1 — $lookup_ty NBound arm
  ;;           returns the bound Ty pointer.
  ;; Exercises: lookup.wat — $lookup_ty.
  ;; Per Hβ-lower-substrate.md §10.1 + §10.4 acceptance.
  ;;
  ;; Eight interrogations:
  ;;   Graph?      $graph_fresh_ty + $graph_bind populate the NBound
  ;;               edge $lookup_ty chases.
  ;;   Handler?    Direct call to $lookup_ty (seed Tier-5 base).
  ;;   Verb?       N/A — sequential.
  ;;   Row?        Pure — TInt is nullary sentinel.
  ;;   Ownership?  Bound Ty is `ref` (graph owns); harness verifies
  ;;               sentinel equality.
  ;;   Refinement? None.
  ;;   Gradient?   This harness IS the proof that the live read returns
  ;;               the bound Ty round-trip.
  ;;   Reason?     $graph_bind records the reason; harness ignores it.

  (data (i32.const 3072) "\05\00\00\00PASS:")
  (data (i32.const 3084) "\05\00\00\00FAIL:")
  (data (i32.const 3096) "\01\00\00\00 ")
  (data (i32.const 3104) "\01\00\00\00\0a")
  (data (i32.const 3120) "\14\00\00\00lower_lookup_nbound ")
  (data (i32.const 3144) "\14\00\00\00lookup-not-tint     ")

  (func $_start (export "_start")
    (local $failed i32)
    (local $h i32) (local $tint i32) (local $looked i32)
    (local.set $failed (i32.const 0))
    (call $graph_init)

    ;; Phase 1: bind a fresh handle to TInt (sentinel 100).
    (local.set $h (call $graph_fresh_ty (i32.const 0)))
    (local.set $tint (call $ty_make_tint))
    (call $graph_bind (local.get $h) (local.get $tint) (i32.const 0))

    ;; Phase 2: $lookup_ty(h) returns TInt sentinel (100).
    (local.set $looked (call $lookup_ty (local.get $h)))
    (if (i32.ne (local.get $looked) (i32.const 100))
      (then
        (call $eprint_string (i32.const 3144))
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
