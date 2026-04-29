  ;; ═══ walk_stmt_fn.wat — Hβ.lower trace-harness ═══════════════════
  ;; Executes: §4.3 + Lock #1/#2/#3 — FnStmt("double", [], _, _, LitInt(0))
  ;;           → LLet tag 304 wrapping LMakeClosure tag 311 whose fn
  ;;           field is LowFn("double", 0, [], [0], Pure).

  (data (i32.const 3072) "\05\00\00\00PASS:")
  (data (i32.const 3084) "\05\00\00\00FAIL:")
  (data (i32.const 3096) "\01\00\00\00 ")
  (data (i32.const 3104) "\01\00\00\00\0a")
  (data (i32.const 3120) "\0f\00\00\00walk_stmt_fn   ")
  (data (i32.const 3152) "\07\00\00\00bad-tag")
  (data (i32.const 3164) "\08\00\00\00bad-name")
  (data (i32.const 3176) "\0b\00\00\00bad-closure")
  (data (i32.const 3192) "\09\00\00\00bad-lowfn")
  (data (i32.const 3208) "\08\00\00\00bad-body")
  (data (i32.const 3224) "\07\00\00\00bad-row")
  (data (i32.const 3232) "\06\00\00\00double")

  (func $_start (export "_start")
    (local $failed i32)
    (local $name i32) (local $params i32) (local $effs i32)
    (local $ret_lit i32) (local $ret_node i32)
    (local $body_lit i32) (local $body_node i32)
    (local $stmt_struct i32) (local $stmt_node i32)
    (local $r i32) (local $closure i32) (local $fn_ir i32)
    (local $body_list i32) (local $body_expr i32)
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
        (local.set $failed (i32.const 1)))
      (else
        (if (i32.eqz (call $str_eq
                       (call $lexpr_llet_name (local.get $r))
                       (i32.const 3232)))
          (then
            (call $eprint_string (i32.const 3164))
            (call $eprint_string (i32.const 3104))
            (local.set $failed (i32.const 1))))

        ;; Verify inner is LMakeClosure (tag 311).
        (local.set $closure (call $lexpr_llet_value (local.get $r)))
        (if (i32.ne (call $tag_of (local.get $closure)) (i32.const 311))
          (then
            (call $eprint_string (i32.const 3176))
            (call $eprint_string (i32.const 3104))
            (local.set $failed (i32.const 1)))
          (else
            (if (i32.ne (call $len (call $lexpr_lmakeclosure_caps (local.get $closure))) (i32.const 0))
              (then
                (call $eprint_string (i32.const 3176))
                (call $eprint_string (i32.const 3104))
                (local.set $failed (i32.const 1))))
            (if (i32.ne (call $len (call $lexpr_lmakeclosure_evs (local.get $closure))) (i32.const 0))
              (then
                (call $eprint_string (i32.const 3176))
                (call $eprint_string (i32.const 3104))
                (local.set $failed (i32.const 1))))

            ;; Verify the real LowFn payload.
            (local.set $fn_ir (call $lexpr_lmakeclosure_fn (local.get $closure)))
            (if (i32.ne (call $tag_of (local.get $fn_ir)) (i32.const 350))
              (then
                (call $eprint_string (i32.const 3192))
                (call $eprint_string (i32.const 3104))
                (local.set $failed (i32.const 1))))
            (if (i32.eq (call $tag_of (local.get $fn_ir)) (i32.const 350))
              (then
                (if (i32.eqz (call $str_eq (call $lowfn_name (local.get $fn_ir)) (i32.const 3232)))
                  (then
                    (call $eprint_string (i32.const 3192))
                    (call $eprint_string (i32.const 3104))
                    (local.set $failed (i32.const 1))))
                (if (i32.ne (call $lowfn_arity (local.get $fn_ir)) (i32.const 0))
                  (then
                    (call $eprint_string (i32.const 3192))
                    (call $eprint_string (i32.const 3104))
                    (local.set $failed (i32.const 1))))
                (if (i32.ne (call $len (call $lowfn_params (local.get $fn_ir))) (i32.const 0))
                  (then
                    (call $eprint_string (i32.const 3192))
                    (call $eprint_string (i32.const 3104))
                    (local.set $failed (i32.const 1))))

                (local.set $body_list (call $lowfn_body (local.get $fn_ir)))
                (if (i32.ne (call $len (local.get $body_list)) (i32.const 1))
                  (then
                    (call $eprint_string (i32.const 3208))
                    (call $eprint_string (i32.const 3104))
                    (local.set $failed (i32.const 1))))
                (if (i32.eq (call $len (local.get $body_list)) (i32.const 1))
                  (then
                    (local.set $body_expr (call $list_index (local.get $body_list) (i32.const 0)))
                    (if (i32.ne (call $tag_of (local.get $body_expr)) (i32.const 300))
                      (then
                        (call $eprint_string (i32.const 3208))
                        (call $eprint_string (i32.const 3104))
                        (local.set $failed (i32.const 1))))
                    (if (i32.eq (call $tag_of (local.get $body_expr)) (i32.const 300))
                      (then
                        (if (i32.ne (call $lexpr_lconst_value (local.get $body_expr)) (i32.const 0))
                          (then
                            (call $eprint_string (i32.const 3208))
                            (call $eprint_string (i32.const 3104))
                            (local.set $failed (i32.const 1))))))))

                (if (i32.eqz (call $row_is_pure (call $lowfn_row (local.get $fn_ir))))
                  (then
                    (call $eprint_string (i32.const 3224))
                    (call $eprint_string (i32.const 3104))
                    (local.set $failed (i32.const 1))))))))))

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
