  ;; ═══ walk_handle_simple.wat — Hβ.lower trace-harness ═════════════
  ;; Executes: §4.2 + Lock #1 — HandleExpr empty arms + LitInt body
  ;;           lowers to LBlock(handle, [LHandle(handle, body, [])]).

  (data (i32.const 3072) "\05\00\00\00PASS:")
  (data (i32.const 3084) "\05\00\00\00FAIL:")
  (data (i32.const 3096) "\01\00\00\00 ")
  (data (i32.const 3104) "\01\00\00\00\0a")
  (data (i32.const 3120) "\14\00\00\00walk_handle_simple  ")
  (data (i32.const 3152) "\17\00\00\00outer-not-LBLOCK-315  ")
  (data (i32.const 3192) "\18\00\00\00inner-not-LHANDLE-332  ")

  (func $_start (export "_start")
    (local $failed i32)
    (local $body_lit i32) (local $body_node i32)
    (local $arms i32) (local $handle_struct i32) (local $handle_node i32)
    (local $r i32) (local $stmts i32) (local $inner i32)
    (local.set $failed (i32.const 0))
    (call $graph_init)
    (call $env_init)
    (call $lower_init)

    ;; body: LitInt(42).
    (local.set $body_lit  (call $mk_LitInt (i32.const 42)))
    (local.set $body_node (call $nexpr (local.get $body_lit) (i32.const 0)))

    ;; empty arms.
    (local.set $arms (call $make_list (i32.const 0)))

    ;; HandleExpr [tag=93][body_node][arms] (Lock #9 — direct alloc).
    (local.set $handle_struct (call $alloc (i32.const 12)))
    (i32.store        (local.get $handle_struct) (i32.const 93))
    (i32.store offset=4 (local.get $handle_struct) (local.get $body_node))
    (i32.store offset=8 (local.get $handle_struct) (local.get $arms))
    (local.set $handle_node (call $nexpr (local.get $handle_struct) (i32.const 0)))

    (local.set $r (call $lower_handle (local.get $handle_node)))

    ;; Outer must be LBlock (tag 315).
    (if (i32.ne (call $tag_of (local.get $r)) (i32.const 315))
      (then
        (call $eprint_string (i32.const 3152))
        (call $eprint_string (i32.const 3104))
        (local.set $failed (i32.const 1))))

    ;; LBlock.stmts: arm_decls (empty per Lock #7) + [LHandle] = 1 stmt.
    (local.set $stmts (call $lexpr_lblock_stmts (local.get $r)))
    (if (i32.ne (call $len (local.get $stmts)) (i32.const 1))
      (then
        (call $eprint_string (i32.const 3152))
        (call $eprint_string (i32.const 3104))
        (local.set $failed (i32.const 1))))

    ;; First stmt must be LHandle (tag 332) per Lock #1 — NOT LHandleWith.
    (local.set $inner (call $list_index (local.get $stmts) (i32.const 0)))
    (if (i32.ne (call $tag_of (local.get $inner)) (i32.const 332))
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
