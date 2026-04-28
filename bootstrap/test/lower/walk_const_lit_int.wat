  ;; ═══ walk_const_lit_int.wat — Hβ.lower trace-harness ════════════════════
  ;; Executes: Hβ-lower-substrate.md §4.2 LitInt arm + §10.1 acceptance —
  ;;           LitInt(42) round-trips through LConst tag 300 with handle
  ;;           and value fields correct.
  ;; Exercises: walk_const.wat — $lower_lit_int, $walk_const_payload_i32.
  ;;
  ;; Eight interrogations:
  ;;   Graph?      $nexpr assigns a fresh handle via $fresh_handle; the N-wrapper
  ;;               carries it at offset 12; $walk_expr_node_handle reads it.
  ;;   Handler?    Direct call to $lower_lit_int (seed Tier-7 base).
  ;;   Verb?       N/A — sequential.
  ;;   Row?        N/A — LitInt carries no effect row.
  ;;   Ownership?  $lower_lit_int produces an `own` LConst record; harness reads
  ;;               fields via $lexpr_handle + $lexpr_lconst_value (ref access).
  ;;   Refinement? None.
  ;;   Gradient?   This harness IS the proof that LitInt round-trips through
  ;;               LConst tag 300 with value field 42 intact (Lock #4 — LowValue
  ;;               is opaque i32 passthrough today).
  ;;   Reason?     $nexpr calls $fresh_handle; no Reason edge surfaced here.

  (data (i32.const 3072) "\05\00\00\00PASS:")
  (data (i32.const 3084) "\05\00\00\00FAIL:")
  (data (i32.const 3096) "\01\00\00\00 ")
  (data (i32.const 3104) "\01\00\00\00\0a")
  (data (i32.const 3120) "\19\00\00\00lower_walk_const_lit_int ")

  (data (i32.const 3152) "\1c\00\00\00lit-int-tag-not-300")
  (data (i32.const 3180) "\1c\00\00\00lit-int-value-not-42")
  (data (i32.const 3208) "\20\00\00\00lit-int-handle-mismatch")

  (func $_start (export "_start")
    (local $failed i32)
    (local $node i32)
    (local $r i32)
    (local $expected_h i32)
    (local.set $failed (i32.const 0))

    ;; Phase 1: build LitInt(42) AST → wrap in NExpr → wrap in N.
    ;; $nexpr(e, span) = N(NExpr(e), span=0, fresh_handle())
    ;; The fresh_handle is stored at offset 12 of the N-wrapper.
    (local.set $node
      (call $nexpr
        (call $mk_LitInt (i32.const 42))
        (i32.const 0)))

    ;; Capture the expected handle (offset 12 of the N-wrapper).
    (local.set $expected_h (i32.load offset=12 (local.get $node)))

    ;; Phase 2: lower the node.
    (local.set $r (call $lower_lit_int (local.get $node)))

    ;; Verify tag == 300 (LCONST_TAG).
    (if (i32.ne (call $tag_of (local.get $r)) (i32.const 300))
      (then
        (call $eprint_string (i32.const 3152))
        (call $eprint_string (i32.const 3104))
        (local.set $failed (i32.const 1))))

    ;; Verify value == 42.
    (if (i32.ne (call $lexpr_lconst_value (local.get $r)) (i32.const 42))
      (then
        (call $eprint_string (i32.const 3180))
        (call $eprint_string (i32.const 3104))
        (local.set $failed (i32.const 1))))

    ;; Verify handle == expected_h (the N-wrapper's fresh_handle).
    (if (i32.ne (call $lexpr_handle (local.get $r)) (local.get $expected_h))
      (then
        (call $eprint_string (i32.const 3208))
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
