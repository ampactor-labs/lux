  ;; ═══ main_inka_emit_smoke.wat — Hβ.emit chunk #8 trace harness ═════
  ;; CASCADE CLOSURE acceptance per Hβ-emit-substrate.md §11 +
  ;; Hβ-bootstrap.md §1.15. Smoke-tests $inka_emit's pipeline-stage
  ;; boundary by building a 2-element LowExpr list ([LConst(7),
  ;; LConst(8)]) and verifying $inka_emit walks it via $emit_lexpr and
  ;; emits the expected concatenated WAT byte stream.
  ;;
  ;; Phase 1: empty list — zero bytes emitted.
  ;; Phase 2: [LConst(7), LConst(8)] → "(i32.const 7)(i32.const 8)" (26 bytes).

  (data (i32.const 3072) "\05\00\00\00PASS:")
  (data (i32.const 3084) "\05\00\00\00FAIL:")
  (data (i32.const 3096) "\01\00\00\00 ")
  (data (i32.const 3104) "\01\00\00\00\0a")
  (data (i32.const 3120) "\14\00\00\00main_inka_emit_smoke")

  (data (i32.const 3168) "\18\00\00\00phase1-empty-pos-bad    ")
  (data (i32.const 3196) "\18\00\00\00phase2-2-elem-pos-bad   ")
  (data (i32.const 3224) "\18\00\00\00phase2-2-elem-bytes-bad ")

  ;; Phase 2 expected (26 bytes): "(i32.const 7)(i32.const 8)"
  (data (i32.const 4096) "\1a\00\00\00(i32.const 7)(i32.const 8)")

  (func $_start (export "_start")
    (local $failed i32)
    (local $h_int i32)
    (local $lc7 i32) (local $lc8 i32)
    (local $stmts2 i32)
    (local.set $failed (i32.const 0))

    (call $emit_init)
    (call $graph_init)

    (local.set $h_int (call $graph_fresh_ty (call $reason_make_fresh (i32.const 0))))
    (call $graph_bind (local.get $h_int)
                      (call $ty_make_tint)
                      (call $reason_make_fresh (i32.const 0)))

    (local.set $lc7 (call $lexpr_make_lconst (local.get $h_int) (i32.const 7)))
    (local.set $lc8 (call $lexpr_make_lconst (local.get $h_int) (i32.const 8)))

    ;; ── Phase 1: $inka_emit over empty list ──
    (global.set $out_pos (i32.const 0))
    (call $inka_emit (call $make_list (i32.const 0)))
    (if (i32.ne (global.get $out_pos) (i32.const 0))
      (then (call $eprint_string (i32.const 3168))
            (call $eprint_string (i32.const 3104))
            (local.set $failed (i32.const 1))))

    ;; ── Phase 2: $inka_emit over [LConst(7), LConst(8)] ──
    (local.set $stmts2 (call $make_list (i32.const 2)))
    (local.set $stmts2 (call $list_extend_to (local.get $stmts2) (i32.const 2)))
    (drop (call $list_set (local.get $stmts2) (i32.const 0) (local.get $lc7)))
    (drop (call $list_set (local.get $stmts2) (i32.const 1) (local.get $lc8)))
    (global.set $out_pos (i32.const 0))
    (call $inka_emit (local.get $stmts2))
    (if (i32.ne (global.get $out_pos) (i32.const 26))
      (then (call $eprint_string (i32.const 3196))
            (call $eprint_string (i32.const 3104))
            (local.set $failed (i32.const 1))))
    (if (i32.eqz (call $bytes_eq_at_outbase (i32.const 4096)))
      (then (call $eprint_string (i32.const 3224))
            (call $eprint_string (i32.const 3104))
            (local.set $failed (i32.const 1))))

    (if (local.get $failed)
      (then (call $eprint_string (i32.const 3084))
            (call $eprint_string (i32.const 3096))
            (call $eprint_string (i32.const 3120))
            (call $eprint_string (i32.const 3104))
            (call $wasi_proc_exit (i32.const 1)))
      (else (call $eprint_string (i32.const 3072))
            (call $eprint_string (i32.const 3096))
            (call $eprint_string (i32.const 3120))
            (call $eprint_string (i32.const 3104))
            (call $wasi_proc_exit (i32.const 0)))))

  (func $bytes_eq_at_outbase (param $expected i32) (result i32)
    (local $expected_len i32) (local $i i32)
    (local $exp_byte i32) (local $out_byte i32)
    (local.set $expected_len (i32.load (local.get $expected)))
    (if (i32.ne (local.get $expected_len) (global.get $out_pos))
      (then (return (i32.const 0))))
    (local.set $i (i32.const 0))
    (block $done
      (loop $cmp
        (br_if $done (i32.ge_u (local.get $i) (local.get $expected_len)))
        (local.set $exp_byte
          (i32.load8_u
            (i32.add (i32.add (local.get $expected) (i32.const 4))
                     (local.get $i))))
        (local.set $out_byte
          (i32.load8_u
            (i32.add (global.get $out_base) (local.get $i))))
        (if (i32.ne (local.get $exp_byte) (local.get $out_byte))
          (then (return (i32.const 0))))
        (local.set $i (i32.add (local.get $i) (i32.const 1)))
        (br $cmp)))
    (i32.const 1))
