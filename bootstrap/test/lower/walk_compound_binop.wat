  ;; ═══ walk_compound_binop.wat — Hβ.lower trace-harness ═════════════
  ;; Executes: src/lower.nx:341-342 — BinOpExpr(op, l, r) → LBinOp tag 306.
  ;; Closes Hβ.lower.binop-arm named follow-up surfaced at chunk #9 landing.

  (data (i32.const 3072) "\05\00\00\00PASS:")
  (data (i32.const 3084) "\05\00\00\00FAIL:")
  (data (i32.const 3096) "\01\00\00\00 ")
  (data (i32.const 3104) "\01\00\00\00\0a")
  (data (i32.const 3120) "\14\00\00\00walk_compound_binop ")
  (data (i32.const 3152) "\17\00\00\00binop-not-LBINOP-306   ")

  (func $_start (export "_start")
    (local $failed i32)
    (local $left_lit i32) (local $left_node i32)
    (local $right_lit i32) (local $right_node i32)
    (local $binop_struct i32) (local $binop_node i32)
    (local $r i32)
    (local.set $failed (i32.const 0))
    (call $graph_init)
    (call $env_init)
    (call $lower_init)

    ;; Build LitInt(2) + LitInt(3) wrapped.
    (local.set $left_lit  (call $mk_LitInt (i32.const 2)))
    (local.set $left_node (call $nexpr (local.get $left_lit) (i32.const 0)))
    (local.set $right_lit  (call $mk_LitInt (i32.const 3)))
    (local.set $right_node (call $nexpr (local.get $right_lit) (i32.const 0)))

    ;; BinOpExpr(BAdd=140, left, right) via $mk_BinOpExpr.
    (local.set $binop_struct (call $mk_BinOpExpr
                               (i32.const 140)
                               (local.get $left_node)
                               (local.get $right_node)))
    (local.set $binop_node (call $nexpr (local.get $binop_struct) (i32.const 0)))

    (local.set $r (call $lower_binop (local.get $binop_node)))

    (if (i32.ne (call $tag_of (local.get $r)) (i32.const 306))
      (then
        (call $eprint_string (i32.const 3152))
        (call $eprint_string (i32.const 3104))
        (local.set $failed (i32.const 1))))

    ;; Verify op field is 140 (BAdd).
    (if (i32.ne (call $lexpr_lbinop_op (local.get $r)) (i32.const 140))
      (then
        (call $eprint_string (i32.const 3152))
        (call $eprint_string (i32.const 3104))
        (local.set $failed (i32.const 1))))

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
