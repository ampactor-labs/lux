  ;; ═══ walk_stmt_fn.wat — Hβ.lower trace-harness ═══════════════════
  ;; Executes: §4.3 + Lock #1/#2/#3 — FnStmt("double", [], _, _, LitInt(0))
  ;;           → LLet tag 304 wrapping LMakeClosure tag 311 with caps/evs/fn=0.

  (data (i32.const 3072) "\05\00\00\00PASS:")
  (data (i32.const 3084) "\05\00\00\00FAIL:")
  (data (i32.const 3096) "\01\00\00\00 ")
  (data (i32.const 3104) "\01\00\00\00\0a")
  (data (i32.const 3120) "\0f\00\00\00walk_stmt_fn   ")
  (data (i32.const 3152) "\11\00\00\00fn-not-LLET-304 ")
  (data (i32.const 3192) "\1d\00\00\00fn-inner-not-LMAKECLOSURE-311 ")
  (data (i32.const 3232) "\06\00\00\00double")

  (func $_start (export "_start")
    (local $failed i32)
    (local $name i32) (local $params i32) (local $effs i32)
    (local $ret_lit i32) (local $ret_node i32)
    (local $body_lit i32) (local $body_node i32)
    (local $stmt_struct i32) (local $stmt_node i32)
    (local $r i32) (local $closure i32)
    (local.set $failed (i32.const 0))
    (call $graph_init)
    (call $env_init)
    (call $lower_init)

    ;; name: "double"
    (local.set $name (i32.const 3232))

    ;; params: empty list
    (local.set $params (call $make_list (i32.const 0)))
    (local.set $effs   (call $make_list (i32.const 0)))

    ;; ret: LitUnit(0) wrapped — placeholder per parser_stmts.wat:219
    (local.set $ret_lit  (call $mk_LitInt (i32.const 0)))
    (local.set $ret_node (call $nexpr (local.get $ret_lit) (i32.const 0)))

    ;; body: LitInt(0) wrapped
    (local.set $body_lit  (call $mk_LitInt (i32.const 0)))
    (local.set $body_node (call $nexpr (local.get $body_lit) (i32.const 0)))

    ;; FnStmt(name, params, ret, effs, body)
    (local.set $stmt_struct (call $mk_FnStmt
                              (local.get $name)
                              (local.get $params)
                              (local.get $ret_node)
                              (local.get $effs)
                              (local.get $body_node)))
    (local.set $stmt_node (call $nstmt (local.get $stmt_struct) (i32.const 0)))

    (local.set $r (call $lower_stmt (local.get $stmt_node)))

    ;; Verify outer tag 304 (LLet).
    (if (i32.ne (call $tag_of (local.get $r)) (i32.const 304))
      (then
        (call $eprint_string (i32.const 3152))
        (call $eprint_string (i32.const 3104))
        (local.set $failed (i32.const 1))))

    ;; Verify inner is LMakeClosure (tag 311).
    (local.set $closure (call $lexpr_llet_value (local.get $r)))
    (if (i32.ne (call $tag_of (local.get $closure)) (i32.const 311))
      (then
        (call $eprint_string (i32.const 3192))
        (call $eprint_string (i32.const 3104))
        (local.set $failed (i32.const 1))))

    ;; Verify Lock #2 fn_ir=0.
    (if (i32.ne (call $lexpr_lmakeclosure_fn (local.get $closure)) (i32.const 0))
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
