  ;; ═══ walk_stmt_program.wat — Hβ.lower trace-harness ═══════════════
  ;; Executes: §4.3 + Lock #11 — $lower_stmt_list over 3-stmt list
  ;;           (ExprStmt(LitInt 1) + ExprStmt(LitInt 2) + ExprStmt(LitInt 3))
  ;;           → list of 3 LConst LowExprs.

  (data (i32.const 3072) "\05\00\00\00PASS:")
  (data (i32.const 3084) "\05\00\00\00FAIL:")
  (data (i32.const 3096) "\01\00\00\00 ")
  (data (i32.const 3104) "\01\00\00\00\0a")
  (data (i32.const 3120) "\14\00\00\00walk_stmt_program   ")
  (data (i32.const 3152) "\10\00\00\00program-len-not-3")

  (func $build_expr_stmt (param $n i32) (result i32)
    (local $lit i32) (local $val_node i32) (local $stmt_struct i32)
    (local.set $lit         (call $mk_LitInt (local.get $n)))
    (local.set $val_node    (call $nexpr (local.get $lit) (i32.const 0)))
    (local.set $stmt_struct (call $mk_ExprStmt (local.get $val_node)))
    (call $nstmt (local.get $stmt_struct) (i32.const 0)))

  (func $_start (export "_start")
    (local $failed i32)
    (local $stmts i32) (local $r i32)
    (local.set $failed (i32.const 0))
    (call $graph_init)
    (call $env_init)
    (call $lower_init)

    (local.set $stmts (call $make_list (i32.const 0)))
    (local.set $stmts (call $list_extend_to (local.get $stmts) (i32.const 3)))
    (drop (call $list_set (local.get $stmts) (i32.const 0)
            (call $build_expr_stmt (i32.const 1))))
    (drop (call $list_set (local.get $stmts) (i32.const 1)
            (call $build_expr_stmt (i32.const 2))))
    (drop (call $list_set (local.get $stmts) (i32.const 2)
            (call $build_expr_stmt (i32.const 3))))

    (local.set $r (call $lower_stmt_list (local.get $stmts)))

    ;; Verify result list has 3 elements.
    (if (i32.ne (call $len (local.get $r)) (i32.const 3))
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
