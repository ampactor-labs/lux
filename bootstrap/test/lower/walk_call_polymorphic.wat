  ;; ═══ walk_call_polymorphic.wat — Hβ.lower trace-harness ═══════════
  ;; Executes: Hβ-lower-substrate.md §3.2 + §4.2 + Lock #1 + Lock #7 —
  ;;           Open-row callee → $lower_call → $lower_call_default →
  ;;           LSuspend tag 325 with empty evs (per Lock #7 conservative
  ;;           seed default; full row-naming lands at named follow-up
  ;;           Hβ.lower.derive-ev-slots-naming).
  ;; Exercises: walk_call.wat — $lower_call + $lower_call_default +
  ;;            $derive_ev_slots (empty-list path) + $monomorphic_at
  ;;            polymorphic gate.

  (data (i32.const 3072) "\05\00\00\00PASS:")
  (data (i32.const 3084) "\05\00\00\00FAIL:")
  (data (i32.const 3096) "\01\00\00\00 ")
  (data (i32.const 3104) "\01\00\00\00\0a")
  (data (i32.const 3120) "\18\00\00\00lower_call_polymorphic  ")
  (data (i32.const 3152) "\17\00\00\00call-not-LSUSPEND-325  ")

  (func $_start (export "_start")
    (local $failed i32)
    (local $rh i32) (local $names i32) (local $row i32)
    (local $params i32) (local $tfun i32)
    (local $callee_lit i32) (local $callee_node i32)
    (local $args_list i32) (local $call_struct i32) (local $call_node i32)
    (local $r i32)
    (local.set $failed (i32.const 0))
    (call $graph_init)
    (call $env_init)
    (call $lower_init)

    ;; Build EfOpen([], rowvar) — polymorphic row.
    (local.set $rh    (call $graph_fresh_row (i32.const 0)))
    (local.set $names (call $make_list (i32.const 0)))
    (local.set $row   (call $row_make_open (local.get $names) (local.get $rh)))

    ;; Build TFun([], TInt, EfOpen).
    (local.set $params (call $make_list (i32.const 0)))
    (local.set $tfun   (call $ty_make_tfun
                         (local.get $params)
                         (call $ty_make_tint)
                         (local.get $row)))

    ;; Build callee + CallExpr.
    (local.set $callee_lit  (call $mk_LitInt (i32.const 1)))
    (local.set $callee_node (call $nexpr (local.get $callee_lit) (i32.const 0)))
    (local.set $args_list   (call $make_list (i32.const 0)))
    (local.set $call_struct (call $mk_CallExpr (local.get $callee_node) (local.get $args_list)))
    (local.set $call_node   (call $nexpr (local.get $call_struct) (i32.const 0)))

    ;; Bind the call's handle to the polymorphic TFun.
    (call $graph_bind
      (call $walk_expr_node_handle (local.get $call_node))
      (local.get $tfun)
      (i32.const 0))

    ;; Lower.
    (local.set $r (call $lower_call (local.get $call_node)))

    ;; Verify tag 325 (LSuspend).
    (if (i32.ne (call $tag_of (local.get $r)) (i32.const 325))
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
