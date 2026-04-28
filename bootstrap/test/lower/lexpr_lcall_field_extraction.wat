  ;; ═══ lexpr_lcall_field_extraction.wat — Hβ.lower trace-harness ═══════
  ;; Executes: Hβ-lower-substrate.md §2 — LCall (tag 308, arity 3)
  ;;           constructor + all 3 field accessors roundtrip.
  ;; Exercises: lexpr.wat — $lexpr_make_lcall, $lexpr_handle,
  ;;            $lexpr_lcall_fn, $lexpr_lcall_args.
  ;; Per Hβ-lower-substrate.md §9 + §13 acceptance.
  ;;
  ;; Eight interrogations:
  ;;   Graph?      LCall field 0 is the graph handle (i32 = 10).
  ;;   Handler?    Direct call to $lexpr_make_lcall (seed Tier-6 base).
  ;;   Verb?       |> topology — LCall is the |> monomorphic-direct-call
  ;;               LowExpr variant (row proved ground at $monomorphic_at).
  ;;   Row?        Pure — constructor layer; row check is at callers.
  ;;   Ownership?  $lexpr_make_lcall returns own; accessors ref.
  ;;   Refinement? None at this layer.
  ;;   Gradient?   Proves field ordering: h=10 at field 0, fn=20 at
  ;;               field 1, args=30 at field 2. A swap between any pair
  ;;               would surface here.
  ;;   Reason?     Not applicable at the constructor harness level.

  (data (i32.const 3072) "\05\00\00\00PASS:")
  (data (i32.const 3084) "\05\00\00\00FAIL:")
  (data (i32.const 3096) "\01\00\00\00 ")
  (data (i32.const 3104) "\01\00\00\00\0a")
  (data (i32.const 3120) "\1c\00\00\00lexpr_lcall_field_extraction ")

  (func $_start (export "_start")
    (local $failed i32)
    (local $r i32)
    (local.set $failed (i32.const 0))

    ;; Build LCall(h=10, fn=20, args=30).
    (local.set $r (call $lexpr_make_lcall (i32.const 10) (i32.const 20) (i32.const 30)))

    ;; Check tag == 308.
    (if (i32.ne (call $tag_of (local.get $r)) (i32.const 308))
      (then (local.set $failed (i32.const 1))))

    ;; Check $lexpr_handle returns h=10.
    (if (i32.ne (call $lexpr_handle (local.get $r)) (i32.const 10))
      (then (local.set $failed (i32.const 1))))

    ;; Check $lexpr_lcall_fn returns fn=20.
    (if (i32.ne (call $lexpr_lcall_fn (local.get $r)) (i32.const 20))
      (then (local.set $failed (i32.const 1))))

    ;; Check $lexpr_lcall_args returns args=30.
    (if (i32.ne (call $lexpr_lcall_args (local.get $r)) (i32.const 30))
      (then (local.set $failed (i32.const 1))))

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
