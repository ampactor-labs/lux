  ;; ═══ walk_handle_arm_decls.wat — Hβ.lower trace-harness ════════════
  ;; Executes: walk_handle.wat's $lower_handler_arms_as_decls over one
  ;; handler arm {args:["x"], body:LitInt(7), op_name:"ping"}.
  ;; Verifies: returns [LDeclareFn(LowFn("op_ping", 1, ["x"], [7], Pure))]
  ;; shape and the arg binding scope is popped after lowering.

  (data (i32.const 3072) "\05\00\00\00PASS:")
  (data (i32.const 3084) "\05\00\00\00FAIL:")
  (data (i32.const 3096) "\01\00\00\00 ")
  (data (i32.const 3104) "\01\00\00\00\0a")
  (data (i32.const 3120) "\15\00\00\00walk_handle_arm_decls")
  (data (i32.const 3152) "\09\00\00\00bad-count")
  (data (i32.const 3168) "\07\00\00\00bad-tag")
  (data (i32.const 3184) "\09\00\00\00bad-lowfn")
  (data (i32.const 3200) "\08\00\00\00bad-body")
  (data (i32.const 3216) "\07\00\00\00bad-row")
  (data (i32.const 3232) "\09\00\00\00bad-scope")
  (data (i32.const 3248) "\01\00\00\00x")
  (data (i32.const 3256) "\04\00\00\00ping")
  (data (i32.const 3268) "\07\00\00\00op_ping")

  (func $_start (export "_start")
    (local $failed i32)
    (local $body_lit i32) (local $body_node i32)
    (local $args i32) (local $arm i32) (local $arms i32)
    (local $decls i32) (local $decl i32) (local $fn_ir i32)
    (local $params i32) (local $body_list i32) (local $body_expr i32)
    (local.set $failed (i32.const 0))
    (call $graph_init)
    (call $env_init)
    (call $lower_init)

    ;; body: LitInt(7)
    (local.set $body_lit  (call $mk_LitInt (i32.const 7)))
    (local.set $body_node (call $nexpr (local.get $body_lit) (i32.const 0)))

    ;; args: ["x"]
    (local.set $args (call $make_list (i32.const 0)))
    (local.set $args (call $list_extend_to (local.get $args) (i32.const 1)))
    (drop (call $list_set (local.get $args) (i32.const 0) (i32.const 3248)))

    ;; arm record = {args, body, op_name}
    (local.set $arm (call $make_record (i32.const 0) (i32.const 3)))
    (call $record_set (local.get $arm) (i32.const 0) (local.get $args))
    (call $record_set (local.get $arm) (i32.const 1) (local.get $body_node))
    (call $record_set (local.get $arm) (i32.const 2) (i32.const 3256))

    (local.set $arms (call $make_list (i32.const 0)))
    (local.set $arms (call $list_extend_to (local.get $arms) (i32.const 1)))
    (drop (call $list_set (local.get $arms) (i32.const 0) (local.get $arm)))

    (local.set $decls (call $lower_handler_arms_as_decls (local.get $arms)))

    (if (i32.ne (call $len (local.get $decls)) (i32.const 1))
      (then
        (call $eprint_string (i32.const 3152))
        (call $eprint_string (i32.const 3104))
        (local.set $failed (i32.const 1)))
      (else
        (local.set $decl (call $list_index (local.get $decls) (i32.const 0)))))

    (if (i32.ne (call $tag_of (local.get $decl)) (i32.const 313))
      (then
        (call $eprint_string (i32.const 3168))
        (call $eprint_string (i32.const 3104))
        (local.set $failed (i32.const 1)))
      (else
        (local.set $fn_ir (call $lexpr_ldeclarefn_fn (local.get $decl)))))

    (if (i32.ne (call $tag_of (local.get $fn_ir)) (i32.const 350))
      (then
        (call $eprint_string (i32.const 3184))
        (call $eprint_string (i32.const 3104))
        (local.set $failed (i32.const 1))))
    (if (i32.eq (call $tag_of (local.get $fn_ir)) (i32.const 350))
      (then
        (if (i32.eqz (call $str_eq (call $lowfn_name (local.get $fn_ir)) (i32.const 3268)))
          (then
            (call $eprint_string (i32.const 3184))
            (call $eprint_string (i32.const 3104))
            (local.set $failed (i32.const 1))))
        (if (i32.ne (call $lowfn_arity (local.get $fn_ir)) (i32.const 1))
          (then
            (call $eprint_string (i32.const 3184))
            (call $eprint_string (i32.const 3104))
            (local.set $failed (i32.const 1))))

        (local.set $params (call $lowfn_params (local.get $fn_ir)))
        (if (i32.ne (call $len (local.get $params)) (i32.const 1))
          (then
            (call $eprint_string (i32.const 3184))
            (call $eprint_string (i32.const 3104))
            (local.set $failed (i32.const 1))))
        (if (i32.eq (call $len (local.get $params)) (i32.const 1))
          (then
            (if (i32.eqz (call $str_eq
                           (call $list_index (local.get $params) (i32.const 0))
                           (i32.const 3248)))
              (then
                (call $eprint_string (i32.const 3184))
                (call $eprint_string (i32.const 3104))
                (local.set $failed (i32.const 1))))))

        (local.set $body_list (call $lowfn_body (local.get $fn_ir)))
        (if (i32.ne (call $len (local.get $body_list)) (i32.const 1))
          (then
            (call $eprint_string (i32.const 3200))
            (call $eprint_string (i32.const 3104))
            (local.set $failed (i32.const 1))))
        (if (i32.eq (call $len (local.get $body_list)) (i32.const 1))
          (then
            (local.set $body_expr (call $list_index (local.get $body_list) (i32.const 0)))
            (if (i32.ne (call $tag_of (local.get $body_expr)) (i32.const 300))
              (then
                (call $eprint_string (i32.const 3200))
                (call $eprint_string (i32.const 3104))
                (local.set $failed (i32.const 1))))
            (if (i32.eq (call $tag_of (local.get $body_expr)) (i32.const 300))
              (then
                (if (i32.ne (call $lexpr_lconst_value (local.get $body_expr)) (i32.const 7))
                  (then
                    (call $eprint_string (i32.const 3200))
                    (call $eprint_string (i32.const 3104))
                    (local.set $failed (i32.const 1))))))))

        (if (i32.eqz (call $row_is_pure (call $lowfn_row (local.get $fn_ir))))
          (then
            (call $eprint_string (i32.const 3216))
            (call $eprint_string (i32.const 3104))
            (local.set $failed (i32.const 1))))))

    ;; The arg binding scope must have been popped after lowering.
    (if (i32.ne (call $ls_lookup_local (i32.const 3248)) (i32.const -1))
      (then
        (call $eprint_string (i32.const 3232))
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
