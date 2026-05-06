  ;; ═══ emit_call_arms.wat — Hβ.emit chunk #6 trace harness ═══════════
  ;; THE GRADIENT CASH-OUT acceptance per Hβ-emit §2.4 + §8 + §11.3 +
  ;; SUBSTRATE.md §I "Duty of Inference is Reification" (three resume
  ;; disciplines on one substrate). 6-phase byte-comparison over the
  ;; call family; UnaryOp ADT integer-tag dispatch (UNeg=160 / UNot=161
  ;; per src/types.mn) substrate-honesty proven; LIndex's $list_index /
  ;; $byte_at substrate-correct dispatch proven (vs wheel's flat-
  ;; arithmetic drift).
  ;;
  ;; Drift 1 refusal proven via LCall's W7 closure-call convention —
  ;; fn_ptr is FIELD on closure record, NOT vtable indirection.

  ;; ─── Harness data segments ────────────────────────────────────────

  (data (i32.const 3072) "\05\00\00\00PASS:")
  (data (i32.const 3084) "\05\00\00\00FAIL:")
  (data (i32.const 3096) "\01\00\00\00 ")
  (data (i32.const 3104) "\01\00\00\00\0a")
  (data (i32.const 3120) "\0f\00\00\00emit_call_arms ")

  (data (i32.const 3168) "\18\00\00\00phase1-lbinop-pos-bad   ")
  (data (i32.const 3196) "\18\00\00\00phase1-lbinop-bytes-bad ")
  (data (i32.const 3224) "\18\00\00\00phase2-uneg-pos-bad     ")
  (data (i32.const 3252) "\18\00\00\00phase2-uneg-bytes-bad   ")
  (data (i32.const 3280) "\18\00\00\00phase3-unot-pos-bad     ")
  (data (i32.const 3308) "\18\00\00\00phase3-unot-bytes-bad   ")
  (data (i32.const 3336) "\18\00\00\00phase4-lidx-list-pos-bad")
  (data (i32.const 3364) "\18\00\00\00phase4-lidx-list-bytes  ")
  (data (i32.const 3392) "\18\00\00\00phase5-lidx-str-pos-bad ")
  (data (i32.const 3420) "\18\00\00\00phase5-lidx-str-bytes   ")
  (data (i32.const 3448) "\18\00\00\00phase6-lcall-pos-bad    ")
  (data (i32.const 3476) "\18\00\00\00phase6-lcall-bytes-bad  ")

  ;; Phase 1 — LBinOp(BAdd=140, LConst(7), LConst(8)) (35 bytes)
  ;;   "(i32.const 7)(i32.const 8)(i32.add)"
  (data (i32.const 4096) "\23\00\00\00(i32.const 7)(i32.const 8)(i32.add)")

  ;; Phase 2 — LUnaryOp(UNeg=160, LConst(7)) (35 bytes)
  ;;   "(i32.const 7)(i32.const 0)(i32.sub)"
  (data (i32.const 4136) "\23\00\00\00(i32.const 7)(i32.const 0)(i32.sub)")

  ;; Phase 3 — LUnaryOp(UNot=161, LConst(7)) (22 bytes)
  ;;   "(i32.const 7)(i32.eqz)"
  (data (i32.const 4176) "\16\00\00\00(i32.const 7)(i32.eqz)")

  ;; Phase 4 — LIndex(LConst(7), LConst(1), is_str=0) (44 bytes)
  ;;   "(i32.const 7)(i32.const 1)(call $list_index)"
  (data (i32.const 4208) "\2c\00\00\00(i32.const 7)(i32.const 1)(call $list_index)")

  ;; Phase 5 — LIndex(LConst(7), LConst(1), is_str=1) (41 bytes)
  ;;   "(i32.const 7)(i32.const 1)(call $byte_at)"
  (data (i32.const 4256) "\29\00\00\00(i32.const 7)(i32.const 1)(call $byte_at)")

  ;; Phase 6 — LCall(LConst(99), []) — empty args, W7 (126 bytes)
  ;;   "(i32.const 99)(local.set $state_tmp)(local.get $state_tmp)(local.get $state_tmp)(i32.load offset=0)(call_indirect (type $ft1))"
  (data (i32.const 4304)
    "\7e\00\00\00(i32.const 99)(local.set $state_tmp)(local.get $state_tmp)(local.get $state_tmp)(i32.load offset=0)(call_indirect (type $ft1))")

  (func $_start (export "_start")
    (local $failed i32)
    (local $h_int i32)
    (local $lc7 i32) (local $lc8 i32) (local $lc99 i32) (local $lc1 i32)
    (local $r_binop i32) (local $r_uneg i32) (local $r_unot i32)
    (local $r_lidx_list i32) (local $r_lidx_str i32) (local $r_lcall i32)
    (local.set $failed (i32.const 0))

    (call $emit_init)
    (call $graph_init)

    (local.set $h_int (call $graph_fresh_ty (call $reason_make_fresh (i32.const 0))))
    (call $graph_bind (local.get $h_int)
                      (call $ty_make_tint)
                      (call $reason_make_fresh (i32.const 0)))

    (local.set $lc7  (call $lexpr_make_lconst (local.get $h_int) (i32.const 7)))
    (local.set $lc8  (call $lexpr_make_lconst (local.get $h_int) (i32.const 8)))
    (local.set $lc1  (call $lexpr_make_lconst (local.get $h_int) (i32.const 1)))
    (local.set $lc99 (call $lexpr_make_lconst (local.get $h_int) (i32.const 99)))

    ;; ── Phase 1: LBinOp(BAdd=140) ──
    (local.set $r_binop
      (call $lexpr_make_lbinop
        (local.get $h_int)
        (i32.const 140)                                  ;; BAdd
        (local.get $lc7)
        (local.get $lc8)))
    (global.set $out_pos (i32.const 0))
    (call $emit_lbinop (local.get $r_binop))
    (if (i32.ne (global.get $out_pos) (i32.const 35))
      (then (call $eprint_string (i32.const 3168))
            (call $eprint_string (i32.const 3104))
            (local.set $failed (i32.const 1))))
    (if (i32.eqz (call $bytes_eq_at_outbase (i32.const 4096)))
      (then (call $eprint_string (i32.const 3196))
            (call $eprint_string (i32.const 3104))
            (local.set $failed (i32.const 1))))

    ;; ── Phase 2: LUnaryOp(UNeg=160) ──
    (local.set $r_uneg
      (call $lexpr_make_lunaryop
        (local.get $h_int)
        (i32.const 160)                                  ;; UNeg
        (local.get $lc7)))
    (global.set $out_pos (i32.const 0))
    (call $emit_lunaryop (local.get $r_uneg))
    (if (i32.ne (global.get $out_pos) (i32.const 35))
      (then (call $eprint_string (i32.const 3224))
            (call $eprint_string (i32.const 3104))
            (local.set $failed (i32.const 1))))
    (if (i32.eqz (call $bytes_eq_at_outbase (i32.const 4136)))
      (then (call $eprint_string (i32.const 3252))
            (call $eprint_string (i32.const 3104))
            (local.set $failed (i32.const 1))))

    ;; ── Phase 3: LUnaryOp(UNot=161) ──
    (local.set $r_unot
      (call $lexpr_make_lunaryop
        (local.get $h_int)
        (i32.const 161)                                  ;; UNot
        (local.get $lc7)))
    (global.set $out_pos (i32.const 0))
    (call $emit_lunaryop (local.get $r_unot))
    (if (i32.ne (global.get $out_pos) (i32.const 22))
      (then (call $eprint_string (i32.const 3280))
            (call $eprint_string (i32.const 3104))
            (local.set $failed (i32.const 1))))
    (if (i32.eqz (call $bytes_eq_at_outbase (i32.const 4176)))
      (then (call $eprint_string (i32.const 3308))
            (call $eprint_string (i32.const 3104))
            (local.set $failed (i32.const 1))))

    ;; ── Phase 4: LIndex non-string ──
    (local.set $r_lidx_list
      (call $lexpr_make_lindex
        (local.get $h_int)
        (local.get $lc7)
        (local.get $lc1)
        (i32.const 0)))
    (global.set $out_pos (i32.const 0))
    (call $emit_lindex (local.get $r_lidx_list))
    (if (i32.ne (global.get $out_pos) (i32.const 44))
      (then (call $eprint_string (i32.const 3336))
            (call $eprint_string (i32.const 3104))
            (local.set $failed (i32.const 1))))
    (if (i32.eqz (call $bytes_eq_at_outbase (i32.const 4208)))
      (then (call $eprint_string (i32.const 3364))
            (call $eprint_string (i32.const 3104))
            (local.set $failed (i32.const 1))))

    ;; ── Phase 5: LIndex string ──
    (local.set $r_lidx_str
      (call $lexpr_make_lindex
        (local.get $h_int)
        (local.get $lc7)
        (local.get $lc1)
        (i32.const 1)))
    (global.set $out_pos (i32.const 0))
    (call $emit_lindex (local.get $r_lidx_str))
    (if (i32.ne (global.get $out_pos) (i32.const 41))
      (then (call $eprint_string (i32.const 3392))
            (call $eprint_string (i32.const 3104))
            (local.set $failed (i32.const 1))))
    (if (i32.eqz (call $bytes_eq_at_outbase (i32.const 4256)))
      (then (call $eprint_string (i32.const 3420))
            (call $eprint_string (i32.const 3104))
            (local.set $failed (i32.const 1))))

    ;; ── Phase 6: LCall(LConst(99), []) — empty args, W7 closure-call ──
    (local.set $r_lcall
      (call $lexpr_make_lcall
        (local.get $h_int)
        (local.get $lc99)
        (call $make_list (i32.const 0))))
    (global.set $out_pos (i32.const 0))
    (call $emit_lcall (local.get $r_lcall))
    (if (i32.ne (global.get $out_pos) (i32.const 126))
      (then (call $eprint_string (i32.const 3448))
            (call $eprint_string (i32.const 3104))
            (local.set $failed (i32.const 1))))
    (if (i32.eqz (call $bytes_eq_at_outbase (i32.const 4304)))
      (then (call $eprint_string (i32.const 3476))
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
