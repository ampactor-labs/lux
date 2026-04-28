  ;; ═══ walk_pipe_compose.wat — Hβ.lower trace-harness ═══════════════
  ;; Executes: §4.2 + spec 10 PCompose — `f >< g` → LMakeTuple (tag 317).

  (data (i32.const 3072) "\05\00\00\00PASS:")
  (data (i32.const 3084) "\05\00\00\00FAIL:")
  (data (i32.const 3096) "\01\00\00\00 ")
  (data (i32.const 3104) "\01\00\00\00\0a")
  (data (i32.const 3120) "\13\00\00\00walk_pipe_compose  ")
  (data (i32.const 3152) "\1a\00\00\00pipe-not-LMAKETUPLE-317   ")
  (data (i32.const 3184) "\01\00\00\00f")
  (data (i32.const 3192) "\01\00\00\00g")

  (func $_start (export "_start")
    (local $failed i32)
    (local $left_var i32) (local $left_node i32)
    (local $right_var i32) (local $right_node i32)
    (local $pipe_struct i32) (local $pipe_node i32)
    (local $r i32) (local $elems i32)
    (local.set $failed (i32.const 0))
    (call $graph_init)
    (call $env_init)
    (call $lower_init)

    (local.set $left_var  (call $mk_VarRef (i32.const 3184)))
    (local.set $left_node (call $nexpr (local.get $left_var) (i32.const 0)))
    (local.set $right_var  (call $mk_VarRef (i32.const 3192)))
    (local.set $right_node (call $nexpr (local.get $right_var) (i32.const 0)))

    (local.set $pipe_struct (call $mk_PipeExpr
                              (i32.const 162)
                              (local.get $left_node)
                              (local.get $right_node)))
    (local.set $pipe_node (call $nexpr (local.get $pipe_struct) (i32.const 0)))

    (local.set $r (call $lower_pipe (local.get $pipe_node)))

    (if (i32.ne (call $tag_of (local.get $r)) (i32.const 317))
      (then
        (call $eprint_string (i32.const 3152))
        (call $eprint_string (i32.const 3104))
        (local.set $failed (i32.const 1))))

    (local.set $elems (call $lexpr_lmaketuple_elems (local.get $r)))
    (if (i32.ne (call $len (local.get $elems)) (i32.const 2))
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
