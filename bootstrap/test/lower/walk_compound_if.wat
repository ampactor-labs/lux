  ;; ═══ walk_compound_if.wat — Hβ.lower trace-harness ════════════════
  ;; Executes: §4.2 + Lock #10 — IfExpr(LitBool(true), LitInt(1), LitInt(2))
  ;;           lowers to LIf(h, lo_cond, [lo_then], [lo_else]) tag 314.

  (data (i32.const 3072) "\05\00\00\00PASS:")
  (data (i32.const 3084) "\05\00\00\00FAIL:")
  (data (i32.const 3096) "\01\00\00\00 ")
  (data (i32.const 3104) "\01\00\00\00\0a")
  (data (i32.const 3120) "\14\00\00\00walk_compound_if    ")
  (data (i32.const 3152) "\10\00\00\00not-LIF-314     ")
  (data (i32.const 3176) "\14\00\00\00then-len-not-1      ")
  (data (i32.const 3208) "\14\00\00\00else-len-not-1      ")

  (func $_start (export "_start")
    (local $failed i32)
    (local $cond_lit i32) (local $cond_node i32)
    (local $then_lit i32) (local $then_node i32)
    (local $else_lit i32) (local $else_node i32)
    (local $if_struct i32) (local $if_node i32)
    (local $r i32) (local $then_branch i32) (local $else_branch i32)
    (local.set $failed (i32.const 0))
    (call $graph_init)
    (call $env_init)
    (call $lower_init)

    ;; cond: LitBool(1).
    (local.set $cond_lit  (call $mk_LitBool (i32.const 1)))
    (local.set $cond_node (call $nexpr (local.get $cond_lit) (i32.const 0)))
    ;; then: LitInt(1).
    (local.set $then_lit  (call $mk_LitInt (i32.const 1)))
    (local.set $then_node (call $nexpr (local.get $then_lit) (i32.const 0)))
    ;; else: LitInt(2).
    (local.set $else_lit  (call $mk_LitInt (i32.const 2)))
    (local.set $else_node (call $nexpr (local.get $else_lit) (i32.const 0)))

    ;; IfExpr via mk_IfExpr (parser_infra.wat:119-125).
    (local.set $if_struct (call $mk_IfExpr
                            (local.get $cond_node)
                            (local.get $then_node)
                            (local.get $else_node)))
    (local.set $if_node   (call $nexpr (local.get $if_struct) (i32.const 0)))

    (local.set $r (call $lower_if (local.get $if_node)))

    ;; Outer must be LIf (tag 314).
    (if (i32.ne (call $tag_of (local.get $r)) (i32.const 314))
      (then
        (call $eprint_string (i32.const 3152))
        (call $eprint_string (i32.const 3104))
        (local.set $failed (i32.const 1))))

    ;; then_branch length must be 1.
    (local.set $then_branch (call $lexpr_lif_then (local.get $r)))
    (if (i32.ne (call $len (local.get $then_branch)) (i32.const 1))
      (then
        (call $eprint_string (i32.const 3176))
        (call $eprint_string (i32.const 3104))
        (local.set $failed (i32.const 1))))

    ;; else_branch length must be 1.
    (local.set $else_branch (call $lexpr_lif_else (local.get $r)))
    (if (i32.ne (call $len (local.get $else_branch)) (i32.const 1))
      (then
        (call $eprint_string (i32.const 3208))
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
