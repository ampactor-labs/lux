  ;; ═══ walk_stmt_let.wat — Hβ.lower trace-harness ═══════════════════
  ;; Executes: §4.3 + Lock #5/#6 — LetStmt(PVar("x"), LitInt(42))
  ;;           → LLet tag 304 with name "x" + LConst-value tag 300.

  (data (i32.const 3072) "\05\00\00\00PASS:")
  (data (i32.const 3084) "\05\00\00\00FAIL:")
  (data (i32.const 3096) "\01\00\00\00 ")
  (data (i32.const 3104) "\01\00\00\00\0a")
  (data (i32.const 3120) "\10\00\00\00walk_stmt_let   ")
  (data (i32.const 3152) "\14\00\00\00let-not-LLET-304    ")
  (data (i32.const 3192) "\14\00\00\00let-name-mismatch   ")
  (data (i32.const 3232) "\01\00\00\00x")

  (func $_start (export "_start")
    (local $failed i32)
    (local $pat i32) (local $val_lit i32) (local $val_node i32)
    (local $stmt_struct i32) (local $stmt_node i32)
    (local $r i32)
    (local.set $failed (i32.const 0))
    (call $graph_init)
    (call $env_init)
    (call $lower_init)

    ;; pat: PVar("x")
    (local.set $pat (call $mk_PVar (i32.const 3232)))

    ;; val: LitInt(42) wrapped as N-expr.
    (local.set $val_lit  (call $mk_LitInt (i32.const 42)))
    (local.set $val_node (call $nexpr (local.get $val_lit) (i32.const 0)))

    ;; LetStmt(pat, val_node) wrapped as N-stmt.
    (local.set $stmt_struct (call $mk_LetStmt (local.get $pat) (local.get $val_node)))
    (local.set $stmt_node   (call $nstmt (local.get $stmt_struct) (i32.const 0)))

    (local.set $r (call $lower_stmt (local.get $stmt_node)))

    ;; Verify tag 304 (LLet).
    (if (i32.ne (call $tag_of (local.get $r)) (i32.const 304))
      (then
        (call $eprint_string (i32.const 3152))
        (call $eprint_string (i32.const 3104))
        (local.set $failed (i32.const 1))))

    ;; Verify name field round-trips as "x".
    (if (i32.eqz (call $str_eq (call $lexpr_llet_name (local.get $r))
                                (i32.const 3232)))
      (then
        (call $eprint_string (i32.const 3192))
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
