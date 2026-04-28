  ;; ═══ walk_compound_lambda.wat — Hβ.lower trace-harness ═════════════
  ;; Executes: §4.2 + Lock #1+#11 — LambdaExpr([], LitInt(42))
  ;;           lowers to LMakeClosure(h, fn=0, caps=[], evs=[]) tag 311.
  ;; Verifies: outer tag 311; caps length 0; evs length 0; fn sentinel 0.

  (data (i32.const 3072) "\05\00\00\00PASS:")
  (data (i32.const 3084) "\05\00\00\00FAIL:")
  (data (i32.const 3096) "\01\00\00\00 ")
  (data (i32.const 3104) "\01\00\00\00\0a")
  (data (i32.const 3120) "\19\00\00\00walk_compound_lambda    ")
  (data (i32.const 3152) "\16\00\00\00not-LMAKECLOSURE-311")
  (data (i32.const 3176) "\14\00\00\00caps-len-not-0      ")
  (data (i32.const 3208) "\14\00\00\00evs-len-not-0       ")
  (data (i32.const 3240) "\14\00\00\00fn-not-0-sentinel   ")

  (func $_start (export "_start")
    (local $failed i32)
    (local $body_lit i32) (local $body_node i32)
    (local $params i32) (local $lambda_struct i32) (local $lambda_node i32)
    (local $r i32) (local $caps i32) (local $evs i32)
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
        (local.set $failed (i32.const 1))))

    ;; caps length must be 0 (Lock #1 empty seed).
    (local.set $caps (call $lexpr_lmakeclosure_caps (local.get $r)))
    (if (i32.ne (call $len (local.get $caps)) (i32.const 0))
      (then
        (call $eprint_string (i32.const 3176))
        (call $eprint_string (i32.const 3104))
        (local.set $failed (i32.const 1))))

    ;; evs length must be 0 (Lock #1 empty seed).
    (local.set $evs (call $lexpr_lmakeclosure_evs (local.get $r)))
    (if (i32.ne (call $len (local.get $evs)) (i32.const 0))
      (then
        (call $eprint_string (i32.const 3208))
        (call $eprint_string (i32.const 3104))
        (local.set $failed (i32.const 1))))

    ;; fn must be 0 sentinel (Lock #1 — LFn ADT not yet landed).
    (if (i32.ne (call $lexpr_lmakeclosure_fn (local.get $r)) (i32.const 0))
      (then
        (call $eprint_string (i32.const 3240))
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
