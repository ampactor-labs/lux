  ;; ═══ lexpr_lconst_roundtrip.wat — Hβ.lower trace-harness ═════════════
  ;; Executes: Hβ-lower-substrate.md §2 — LConst (tag 300, arity 2)
  ;;           constructor + $lexpr_handle + $lexpr_lconst_value roundtrip.
  ;; Exercises: lexpr.wat — $lexpr_make_lconst, $lexpr_handle, $lexpr_lconst_value.
  ;; Per Hβ-lower-substrate.md §9 + §13 acceptance.
  ;;
  ;; Eight interrogations:
  ;;   Graph?      LConst field 0 is the graph handle (i32 = 42 here,
  ;;               a concrete sentinel used for roundtrip verification).
  ;;   Handler?    Direct call to $lexpr_make_lconst (seed Tier-6 base).
  ;;   Verb?       N/A — sequential.
  ;;   Row?        Pure — no effect rows at the constructor layer.
  ;;   Ownership?  $lexpr_make_lconst returns own; harness reads back
  ;;               via ref accessors; bump allocator owns the record.
  ;;   Refinement? None at this layer.
  ;;   Gradient?   This harness IS the proof that the LConst constructor
  ;;               + field 0/1 layout is correct per the wheel's arity-2
  ;;               discipline. Also verifies $tag_of returns 300.
  ;;   Reason?     Graph handle 42 is a sentinel; no Reason chain needed
  ;;               for the roundtrip verification.

  (data (i32.const 3072) "\05\00\00\00PASS:")
  (data (i32.const 3084) "\05\00\00\00FAIL:")
  (data (i32.const 3096) "\01\00\00\00 ")
  (data (i32.const 3104) "\01\00\00\00\0a")
  (data (i32.const 3120) "\17\00\00\00lexpr_lconst_roundtrip ")

  (func $_start (export "_start")
    (local $failed i32)
    (local $r i32)
    (local.set $failed (i32.const 0))

    ;; Build LConst(h=42, value=99).
    (local.set $r (call $lexpr_make_lconst (i32.const 42) (i32.const 99)))

    ;; Check tag == 300.
    (if (i32.ne (call $tag_of (local.get $r)) (i32.const 300))
      (then (local.set $failed (i32.const 1))))

    ;; Check $lexpr_handle returns h=42.
    (if (i32.ne (call $lexpr_handle (local.get $r)) (i32.const 42))
      (then (local.set $failed (i32.const 1))))

    ;; Check $lexpr_lconst_value returns value=99.
    (if (i32.ne (call $lexpr_lconst_value (local.get $r)) (i32.const 99))
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
