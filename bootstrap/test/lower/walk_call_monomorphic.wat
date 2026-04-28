  ;; ═══ walk_call_monomorphic.wat — Hβ.lower trace-harness ═══════════
  ;; Executes: Hβ-lower-substrate.md §3.2 + §4.2 + Lock #1 — Pure-row
  ;;           callee bound at handle h_callee; CallExpr at h_call →
  ;;           $lower_call → $lower_call_default → LCall tag 308.
  ;; Exercises: walk_call.wat — $lower_call + $lower_call_default +
  ;;            $monomorphic_at delegation + cross-chunk recursion via
  ;;            $lower_expr partial dispatcher.

  (data (i32.const 3072) "\05\00\00\00PASS:")
  (data (i32.const 3084) "\05\00\00\00FAIL:")
  (data (i32.const 3096) "\01\00\00\00 ")
  (data (i32.const 3104) "\01\00\00\00\0a")
  (data (i32.const 3120) "\18\00\00\00lower_call_monomorphic  ")
  (data (i32.const 3152) "\14\00\00\00call-not-LCALL-308  ")

  (func $_start (export "_start")
    (local $failed i32)
    (local $h_callee i32) (local $tfun i32) (local $params i32) (local $row i32)
    (local $callee_lit i32) (local $callee_node i32)
    (local $args_list i32) (local $call_struct i32) (local $call_node i32)
    (local $r i32)
    (local.set $failed (i32.const 0))
    (call $graph_init)
    (call $env_init)
    (call $lower_init)

    ;; Build callee TFun([], TInt, EfPure) and bind a fresh handle h_callee.
    (local.set $params (call $make_list (i32.const 0)))
    (local.set $row    (call $row_make_pure))
    (local.set $tfun   (call $ty_make_tfun
                         (local.get $params)
                         (call $ty_make_tint)
                         (local.get $row)))
    (local.set $h_callee (call $graph_fresh_ty (i32.const 0)))
    (call $graph_bind (local.get $h_callee) (local.get $tfun) (i32.const 0))

    ;; Build callee N-wrapper. Use LitInt(1) as the callee's expr (any
    ;; AST shape works; we just need the recursion to land somewhere).
    (local.set $callee_lit  (call $mk_LitInt (i32.const 1)))
    (local.set $callee_node (call $nexpr (local.get $callee_lit) (i32.const 0)))

    ;; Build CallExpr(callee_node, []) → wrap.
    (local.set $args_list   (call $make_list (i32.const 0)))
    (local.set $call_struct (call $mk_CallExpr (local.get $callee_node) (local.get $args_list)))
    (local.set $call_node   (call $nexpr (local.get $call_struct) (i32.const 0)))

    ;; Bind the call N-wrapper's handle to TInt so monomorphic_at's
    ;; tfun-row check fires on the *callee* handle.
    ;; (Actually monomorphic_at reads $lookup_ty(call_handle); we want
    ;; the call_node's handle bound to the callee TFun for the gate.)
    (call $graph_bind
      (call $walk_expr_node_handle (local.get $call_node))
      (local.get $tfun)
      (i32.const 0))

    ;; Lower.
    (local.set $r (call $lower_call (local.get $call_node)))

    ;; Verify tag 308.
    (if (i32.ne (call $tag_of (local.get $r)) (i32.const 308))
      (then
        (call $eprint_string (i32.const 3152))
        (call $eprint_string (i32.const 3104))
        (local.set $failed (i32.const 1))))

    ;; Verdict.
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
