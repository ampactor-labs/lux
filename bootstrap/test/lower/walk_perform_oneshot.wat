  ;; ═══ walk_perform_oneshot.wat — Hβ.lower trace-harness ═══════════
  ;; Executes: Hβ-lower-substrate.md §4.2 + Lock #2 — wheel-parity
  ;;           LPerform regardless of ResumeDiscipline. PerformExpr →
  ;;           $lower_perform → LPerform tag 331.
  ;; Exercises: walk_call.wat — $lower_perform.

  (data (i32.const 3072) "\05\00\00\00PASS:")
  (data (i32.const 3084) "\05\00\00\00FAIL:")
  (data (i32.const 3096) "\01\00\00\00 ")
  (data (i32.const 3104) "\01\00\00\00\0a")
  (data (i32.const 3120) "\17\00\00\00lower_perform_oneshot  ")
  (data (i32.const 3152) "\17\00\00\00perform-not-LPERFORM-331")
  (data (i32.const 3184) "\08\00\00\00test_op ")

  (func $_start (export "_start")
    (local $failed i32)
    (local $args_list i32) (local $perform_struct i32) (local $perform_node i32)
    (local $r i32)
    (local.set $failed (i32.const 0))
    (call $graph_init)
    (call $env_init)
    (call $lower_init)

    ;; Build PerformExpr("test_op", []) → wrap.
    (local.set $args_list      (call $make_list (i32.const 0)))
    (local.set $perform_struct (call $mk_PerformExpr (i32.const 3184) (local.get $args_list)))
    (local.set $perform_node   (call $nexpr (local.get $perform_struct) (i32.const 0)))

    ;; Lower.
    (local.set $r (call $lower_perform (local.get $perform_node)))

    ;; Verify tag 331 (LPerform).
    (if (i32.ne (call $tag_of (local.get $r)) (i32.const 331))
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
