  ;; ═══ walk_compound_lambda.wat — Hβ.lower trace-harness ═════════════
  ;; Executes: §4.2 + Lock #1+#11 — LambdaExpr([], LitInt(42))
  ;;           lowers to LMakeClosure(h, LowFn(int_to_str(h), 0, [], [42], Pure),
  ;;           caps=[], evs=[]).
  ;; Verifies: outer tag 311; caps/evs empty; fn field is LowFn tag 350
  ;; with the lambda-handle-derived name, arity 0, one-body list entry,
  ;; and Pure row.

  (data (i32.const 3072) "\05\00\00\00PASS:")
  (data (i32.const 3084) "\05\00\00\00FAIL:")
  (data (i32.const 3096) "\01\00\00\00 ")
  (data (i32.const 3104) "\01\00\00\00\0a")
  (data (i32.const 3120) "\19\00\00\00walk_compound_lambda    ")
  (data (i32.const 3152) "\07\00\00\00bad-tag")
  (data (i32.const 3164) "\08\00\00\00bad-caps")
  (data (i32.const 3176) "\07\00\00\00bad-evs")
  (data (i32.const 3188) "\09\00\00\00bad-lowfn")
  (data (i32.const 3204) "\08\00\00\00bad-body")
  (data (i32.const 3216) "\07\00\00\00bad-row")

  (func $_start (export "_start")
    (local $failed i32)
    (local $body_lit i32) (local $body_node i32)
    (local $params i32) (local $lambda_struct i32) (local $lambda_node i32)
    (local $r i32) (local $caps i32) (local $evs i32)
    (local $fn_ir i32) (local $fn_body i32) (local $body_expr i32)
    (local $expected_name i32)
    (local.set $failed (i32.const 0))
    (call $graph_init)
    (call $env_init)
    (call $lower_init)

    ;; body: LitInt(42).
    (local.set $body_lit  (call $mk_LitInt (i32.const 42)))
    (local.set $body_node (call $nexpr (local.get $body_lit) (i32.const 0)))

    ;; params: empty list.
    (local.set $params (call $make_list (i32.const 0)))

    ;; LambdaExpr [tag=89][params_list][body_node] — Lock #9 direct alloc.
    (local.set $lambda_struct (call $alloc (i32.const 12)))
    (i32.store          (local.get $lambda_struct) (i32.const 89))
    (i32.store offset=4 (local.get $lambda_struct) (local.get $params))
    (i32.store offset=8 (local.get $lambda_struct) (local.get $body_node))
    (local.set $lambda_node (call $nexpr (local.get $lambda_struct) (i32.const 0)))

    (local.set $r (call $lower_lambda (local.get $lambda_node)))

    ;; Outer must be LMakeClosure (tag 311).
    (if (i32.ne (call $tag_of (local.get $r)) (i32.const 311))
      (then
        (call $eprint_string (i32.const 3152))
        (call $eprint_string (i32.const 3104))
        (local.set $failed (i32.const 1)))
      (else
        ;; caps length must be 0 (Lock #1 empty seed).
        (local.set $caps (call $lexpr_lmakeclosure_caps (local.get $r)))
        (if (i32.ne (call $len (local.get $caps)) (i32.const 0))
          (then
            (call $eprint_string (i32.const 3164))
            (call $eprint_string (i32.const 3104))
            (local.set $failed (i32.const 1))))

        ;; evs length must be 0 (Lock #1 empty seed).
        (local.set $evs (call $lexpr_lmakeclosure_evs (local.get $r)))
        (if (i32.ne (call $len (local.get $evs)) (i32.const 0))
          (then
            (call $eprint_string (i32.const 3176))
            (call $eprint_string (i32.const 3104))
            (local.set $failed (i32.const 1))))

        ;; fn must be a real LowFn with name=int_to_str(lambda_handle).
        (local.set $fn_ir (call $lexpr_lmakeclosure_fn (local.get $r)))
        (local.set $expected_name
          (call $int_to_str (call $walk_expr_node_handle (local.get $lambda_node))))
        (if (i32.ne (call $tag_of (local.get $fn_ir)) (i32.const 350))
          (then
            (call $eprint_string (i32.const 3188))
            (call $eprint_string (i32.const 3104))
            (local.set $failed (i32.const 1))))
        (if (i32.eq (call $tag_of (local.get $fn_ir)) (i32.const 350))
          (then
            (if (i32.eqz (call $str_eq
                           (call $lowfn_name (local.get $fn_ir))
                           (local.get $expected_name)))
              (then
                (call $eprint_string (i32.const 3188))
                (call $eprint_string (i32.const 3104))
                (local.set $failed (i32.const 1))))
            (if (i32.ne (call $lowfn_arity (local.get $fn_ir)) (i32.const 0))
              (then
                (call $eprint_string (i32.const 3188))
                (call $eprint_string (i32.const 3104))
                (local.set $failed (i32.const 1))))
            (if (i32.ne (call $len (call $lowfn_params (local.get $fn_ir))) (i32.const 0))
              (then
                (call $eprint_string (i32.const 3188))
                (call $eprint_string (i32.const 3104))
                (local.set $failed (i32.const 1))))

            ;; Body list must contain one lowered literal 42.
            (local.set $fn_body (call $lowfn_body (local.get $fn_ir)))
            (if (i32.ne (call $len (local.get $fn_body)) (i32.const 1))
              (then
                (call $eprint_string (i32.const 3204))
                (call $eprint_string (i32.const 3104))
                (local.set $failed (i32.const 1))))
            (if (i32.eq (call $len (local.get $fn_body)) (i32.const 1))
              (then
                (local.set $body_expr (call $list_index (local.get $fn_body) (i32.const 0)))
                (if (i32.ne (call $tag_of (local.get $body_expr)) (i32.const 300))
                  (then
                    (call $eprint_string (i32.const 3204))
                    (call $eprint_string (i32.const 3104))
                    (local.set $failed (i32.const 1))))
                (if (i32.eq (call $tag_of (local.get $body_expr)) (i32.const 300))
                  (then
                    (if (i32.ne (call $lexpr_lconst_value (local.get $body_expr)) (i32.const 42))
                      (then
                        (call $eprint_string (i32.const 3204))
                        (call $eprint_string (i32.const 3104))
                        (local.set $failed (i32.const 1))))))))

            ;; Row must be Pure.
            (if (i32.eqz (call $row_is_pure (call $lowfn_row (local.get $fn_ir))))
              (then
                (call $eprint_string (i32.const 3216))
                (call $eprint_string (i32.const 3104))
                (local.set $failed (i32.const 1))))))))

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
