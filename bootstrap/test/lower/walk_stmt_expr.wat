  ;; ═══ walk_stmt_expr.wat — Hβ.lower trace-harness ═══════════════════
  ;; Executes: §4.3 + Lock #8 — ExprStmt(LitInt(7)) → LConst tag 300
  ;;           passthrough.

  (data (i32.const 3072) "\05\00\00\00PASS:")
  (data (i32.const 3084) "\05\00\00\00FAIL:")
  (data (i32.const 3096) "\01\00\00\00 ")
  (data (i32.const 3104) "\01\00\00\00\0a")
  (data (i32.const 3120) "\11\00\00\00walk_stmt_expr   ")
  (data (i32.const 3152) "\14\00\00\00expr-not-LCONST-300 ")

  (func $_start (export "_start")
    (local $failed i32)
    (local $val_lit i32) (local $val_node i32)
    (local $stmt_struct i32) (local $stmt_node i32)
    (local $r i32)
    (local.set $failed (i32.const 0))
    (call $graph_init)
    (call $env_init)
    (call $lower_init)

    (local.set $val_lit  (call $mk_LitInt (i32.const 7)))
    (local.set $val_node (call $nexpr (local.get $val_lit) (i32.const 0)))

    (local.set $stmt_struct (call $mk_ExprStmt (local.get $val_node)))
    (local.set $stmt_node   (call $nstmt (local.get $stmt_struct) (i32.const 0)))

    (local.set $r (call $lower_stmt (local.get $stmt_node)))

    ;; Verify tag 300 (LConst — ExprStmt unwraps to inner LitInt's lowering).
    (if (i32.ne (call $tag_of (local.get $r)) (i32.const 300))
      (then
        (call $eprint_string (i32.const 3152))
        (call $eprint_string (i32.const 3104))
        (local.set $failed (i32.const 1))))

    ;; Verify value field is 7 (passed through walk_const $lower_lit_int).
    (if (i32.ne (call $lexpr_lconst_value (local.get $r)) (i32.const 7))
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
