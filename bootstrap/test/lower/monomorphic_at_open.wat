  ;; ═══ monomorphic_at_open.wat — Hβ.lower trace-harness ══════════════
  ;; Executes: Hβ-lower-substrate.md §3.2 — $monomorphic_at returns 0
  ;;           for a TFun whose row is EfOpen (rowvar present → polymorphic).
  ;; Exercises: lookup.wat — $monomorphic_at + $row_is_ground + $lookup_ty.
  ;; Per Hβ-lower-substrate.md §10.1 + §10.4 acceptance.
  ;;
  ;; Eight interrogations:
  ;;   Graph?      Mints fresh row handle via $graph_fresh_row; builds
  ;;               EfOpen([], rowvar) referencing it.
  ;;   Handler?    Direct.
  ;;   Verb?       N/A.
  ;;   Row?        EfOpen tag 152 — has rowvar → not ground.
  ;;   Ownership?  As above.
  ;;   Refinement? None.
  ;;   Gradient?   This harness IS the proof of the 5% polymorphic case
  ;;               — open rows route through evidence-thunk downstream
  ;;               (chunk #7 walk_call.wat).
  ;;   Reason?     reason ptr 0.

  (data (i32.const 3072) "\05\00\00\00PASS:")
  (data (i32.const 3084) "\05\00\00\00FAIL:")
  (data (i32.const 3096) "\01\00\00\00 ")
  (data (i32.const 3104) "\01\00\00\00\0a")
  (data (i32.const 3120) "\18\00\00\00lower_monomorphic_open  ")
  (data (i32.const 3152) "\1d\00\00\00monomorphic-not-false-on-open ")

  (func $_start (export "_start")
    (local $failed i32)
    (local $rh i32) (local $h i32) (local $tfun i32)
    (local $params i32) (local $names i32) (local $row i32) (local $result i32)
    (local.set $failed (i32.const 0))
    (call $graph_init)

    ;; Mint a fresh row handle and build EfOpen([], rh).
    (local.set $rh (call $graph_fresh_row (i32.const 0)))
    (local.set $names (call $make_list (i32.const 0)))
    (local.set $row (call $row_make_open (local.get $names) (local.get $rh)))
    ;; Build TFun([], TInt, EfOpen) and bind to fresh ty handle.
    (local.set $params (call $make_list (i32.const 0)))
    (local.set $tfun (call $ty_make_tfun
                       (local.get $params)
                       (call $ty_make_tint)
                       (local.get $row)))
    (local.set $h (call $graph_fresh_ty (i32.const 0)))
    (call $graph_bind (local.get $h) (local.get $tfun) (i32.const 0))

    ;; $monomorphic_at(h) must return 0.
    (local.set $result (call $monomorphic_at (local.get $h)))
    (if (i32.ne (local.get $result) (i32.const 0))
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
