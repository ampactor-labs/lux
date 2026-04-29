  ;; ═══ lowfn_smoke.wat — Hβ.lower Phase C.1 trace-harness ══════════════
  ;; Exercises: lowfn.wat — $lowfn_make + 5 accessors roundtrip.
  ;; Constructs LowFn("double", 1, params_list, body_sentinel, row_sentinel)
  ;; and verifies all fields round-trip correctly.

  (data (i32.const 3072) "\05\00\00\00PASS:")
  (data (i32.const 3084) "\05\00\00\00FAIL:")
  (data (i32.const 3096) "\01\00\00\00 ")
  (data (i32.const 3104) "\01\00\00\00\0a")
  (data (i32.const 3120) "\0b\00\00\00lowfn_smoke")

  (func $_start (export "_start")
    (local $failed i32)
    (local $r i32)
    (local $name i32)
    (local.set $failed (i32.const 0))

    ;; Build a name string "double".
    (local.set $name (call $str_alloc (i32.const 6)))
    (i32.store8 offset=4 (local.get $name) (i32.const 100))  ;; d
    (i32.store8 offset=5 (local.get $name) (i32.const 111))  ;; o
    (i32.store8 offset=6 (local.get $name) (i32.const 117))  ;; u
    (i32.store8 offset=7 (local.get $name) (i32.const 98))   ;; b
    (i32.store8 offset=8 (local.get $name) (i32.const 108))  ;; l
    (i32.store8 offset=9 (local.get $name) (i32.const 101))  ;; e

    ;; Build LowFn(name="double", arity=1, params=77, body=88, row=99).
    ;; params/body/row are sentinel i32s for roundtrip verification.
    (local.set $r (call $lowfn_make
      (local.get $name) (i32.const 1) (i32.const 77)
      (i32.const 88) (i32.const 99)))

    ;; Check tag == 350.
    (if (i32.ne (call $tag_of (local.get $r)) (i32.const 350))
      (then (local.set $failed (i32.const 1))))

    ;; Check $lowfn_name returns name ptr.
    (if (i32.ne (call $lowfn_name (local.get $r)) (local.get $name))
      (then (local.set $failed (i32.const 1))))

    ;; Check $lowfn_arity returns 1.
    (if (i32.ne (call $lowfn_arity (local.get $r)) (i32.const 1))
      (then (local.set $failed (i32.const 1))))

    ;; Check $lowfn_params returns 77.
    (if (i32.ne (call $lowfn_params (local.get $r)) (i32.const 77))
      (then (local.set $failed (i32.const 1))))

    ;; Check $lowfn_body returns 88.
    (if (i32.ne (call $lowfn_body (local.get $r)) (i32.const 88))
      (then (local.set $failed (i32.const 1))))

    ;; Check $lowfn_row returns 99.
    (if (i32.ne (call $lowfn_row (local.get $r)) (i32.const 99))
      (then (local.set $failed (i32.const 1))))

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
