  ;; ═══ emit_handler_arms.wat — Hβ.emit chunk #7 trace harness ════════
  ;; Per Hβ-emit-substrate.md §2.5 acceptance — the chunk where `~>` and
  ;; `<~` become physical at WAT. 7-phase byte-comparison over LLet,
  ;; LDeclareFn, LHandleWith, LHandle, LFeedback, LPerform, LEvPerform.
  ;;
  ;; Phase 5 (LFeedback) IS the `<~` substrate proof — SUBSTRATE.md §II
  ;; "Feedback IS Mentl's Genuine Novelty" made physical: load-prior →
  ;; emit body → tee-current → store-current → reload-current.
  ;;
  ;; Phase 7 (LEvPerform) IS the H1 evidence-reification + Drift 1
  ;; refusal proof — fn_idx is a FIELD on the closure record at offset
  ;; 8 + 4*body_capture_count + 4*slot_idx; call_indirect reads that
  ;; field. NO vtable.

  (data (i32.const 3072) "\05\00\00\00PASS:")
  (data (i32.const 3084) "\05\00\00\00FAIL:")
  (data (i32.const 3096) "\01\00\00\00 ")
  (data (i32.const 3104) "\01\00\00\00\0a")
  (data (i32.const 3120) "\12\00\00\00emit_handler_arms ")

  (data (i32.const 3168) "\18\00\00\00phase1-llet-pos-bad     ")
  (data (i32.const 3196) "\18\00\00\00phase1-llet-bytes-bad   ")
  (data (i32.const 3224) "\18\00\00\00phase2-ldeclarefn-pos   ")
  (data (i32.const 3252) "\18\00\00\00phase2-ldeclarefn-bytes ")
  (data (i32.const 3280) "\18\00\00\00phase3-lhandlewith-pos  ")
  (data (i32.const 3308) "\18\00\00\00phase3-lhandlewith-bytes")
  (data (i32.const 3336) "\18\00\00\00phase4-lhandle-pos      ")
  (data (i32.const 3364) "\18\00\00\00phase4-lhandle-bytes    ")
  (data (i32.const 3392) "\18\00\00\00phase5-lfeedback-pos    ")
  (data (i32.const 3420) "\18\00\00\00phase5-lfeedback-bytes  ")
  (data (i32.const 3448) "\18\00\00\00phase6-lperform-pos     ")
  (data (i32.const 3476) "\18\00\00\00phase6-lperform-bytes   ")
  (data (i32.const 3504) "\18\00\00\00phase7-levperform-pos   ")
  (data (i32.const 3532) "\18\00\00\00phase7-levperform-bytes ")

  ;; LLet name + LPerform op_name + LEvPerform op_name length-prefixed
  (data (i32.const 3616) "\01\00\00\00x")
  (data (i32.const 3624) "\05\00\00\00print")
  (data (i32.const 3640) "\02\00\00\00op")

  ;; Phase 1 (27 bytes): "(i32.const 7)(local.set $x)"
  (data (i32.const 4096) "\1b\00\00\00(i32.const 7)(local.set $x)")

  ;; Phase 2 (13 bytes): "(i32.const 0)"
  (data (i32.const 4128) "\0d\00\00\00(i32.const 0)")

  ;; Phase 3 (13 bytes): "(i32.const 7)" — body emitted, handler inert
  (data (i32.const 4152) "\0d\00\00\00(i32.const 7)")

  ;; Phase 4 (13 bytes): "(i32.const 7)"
  (data (i32.const 4176) "\0d\00\00\00(i32.const 7)")

  ;; Phase 5 (112 bytes): LFeedback h=42
  (data (i32.const 4200)
    "\70\00\00\00(global.get $s42)(local.set $__fb_prev_42)(i32.const 7)(local.tee $__fb_42)(global.set $s42)(local.get $__fb_42)")

  ;; Phase 6 (29 bytes): "(i32.const 7)(call $op_print)"
  (data (i32.const 4320) "\1d\00\00\00(i32.const 7)(call $op_print)")

  ;; Phase 7 (100 bytes): LEvPerform offset=16 (body_cc=0, slot=2)
  (data (i32.const 4356)
    "\64\00\00\00(local.get $__state)(i32.const 7)(local.get $__state)(i32.load offset=16)(call_indirect (type $ft2))")

  (func $_start (export "_start")
    (local $failed i32)
    (local $h_int i32) (local $h_var i32)
    (local $lc7 i32) (local $lc0 i32)
    (local $args_lc7 i32)
    (local $r_llet i32) (local $r_ldeclarefn i32)
    (local $r_lhw i32) (local $r_lh i32) (local $r_lfb i32)
    (local $r_lperform i32) (local $r_levperform i32)
    (local.set $failed (i32.const 0))

    (call $emit_init)
    (call $graph_init)

    (local.set $h_int (call $graph_fresh_ty (call $reason_make_fresh (i32.const 0))))
    (call $graph_bind (local.get $h_int)
                      (call $ty_make_tint)
                      (call $reason_make_fresh (i32.const 0)))
    (local.set $h_var (call $graph_fresh_ty (call $reason_make_fresh (i32.const 1))))
    (call $graph_bind (local.get $h_var)
                      (call $ty_make_tint)
                      (call $reason_make_fresh (i32.const 1)))

    (local.set $lc7 (call $lexpr_make_lconst (local.get $h_int) (i32.const 7)))
    (local.set $lc0 (call $lexpr_make_lconst (local.get $h_int) (i32.const 0)))

    (local.set $args_lc7 (call $make_list (i32.const 1)))
    (local.set $args_lc7 (call $list_extend_to (local.get $args_lc7) (i32.const 1)))
    (drop (call $list_set (local.get $args_lc7) (i32.const 0) (local.get $lc7)))

    ;; ── Phase 1: LLet(h, "x", LConst(7)) ──
    (local.set $r_llet
      (call $lexpr_make_llet
        (local.get $h_var)
        (i32.const 3616)                                ;; "x"
        (local.get $lc7)))
    (global.set $out_pos (i32.const 0))
    (call $emit_llet (local.get $r_llet))
    (if (i32.ne (global.get $out_pos) (i32.const 27))
      (then (call $eprint_string (i32.const 3168))
            (call $eprint_string (i32.const 3104))
            (local.set $failed (i32.const 1))))
    (if (i32.eqz (call $bytes_eq_at_outbase (i32.const 4096)))
      (then (call $eprint_string (i32.const 3196))
            (call $eprint_string (i32.const 3104))
            (local.set $failed (i32.const 1))))

    ;; ── Phase 2: LDeclareFn (lowfn opaque ptr; expression-position no-op) ──
    (local.set $r_ldeclarefn
      (call $lexpr_make_ldeclarefn (local.get $lc0)))   ;; opaque LowFn ptr
    (global.set $out_pos (i32.const 0))
    (call $emit_ldeclarefn (local.get $r_ldeclarefn))
    (if (i32.ne (global.get $out_pos) (i32.const 13))
      (then (call $eprint_string (i32.const 3224))
            (call $eprint_string (i32.const 3104))
            (local.set $failed (i32.const 1))))
    (if (i32.eqz (call $bytes_eq_at_outbase (i32.const 4128)))
      (then (call $eprint_string (i32.const 3252))
            (call $eprint_string (i32.const 3104))
            (local.set $failed (i32.const 1))))

    ;; ── Phase 3: LHandleWith(h, body=LConst(7), handler=LConst(0)) ──
    (local.set $r_lhw
      (call $lexpr_make_lhandlewith
        (local.get $h_var)
        (local.get $lc7)
        (local.get $lc0)))
    (global.set $out_pos (i32.const 0))
    (call $emit_lhandlewith (local.get $r_lhw))
    (if (i32.ne (global.get $out_pos) (i32.const 13))
      (then (call $eprint_string (i32.const 3280))
            (call $eprint_string (i32.const 3104))
            (local.set $failed (i32.const 1))))
    (if (i32.eqz (call $bytes_eq_at_outbase (i32.const 4152)))
      (then (call $eprint_string (i32.const 3308))
            (call $eprint_string (i32.const 3104))
            (local.set $failed (i32.const 1))))

    ;; ── Phase 4: LHandle(h, body=LConst(7), arms=[]) ──
    (local.set $r_lh
      (call $lexpr_make_lhandle
        (local.get $h_var)
        (local.get $lc7)
        (call $make_list (i32.const 0))))
    (global.set $out_pos (i32.const 0))
    (call $emit_lhandle (local.get $r_lh))
    (if (i32.ne (global.get $out_pos) (i32.const 13))
      (then (call $eprint_string (i32.const 3336))
            (call $eprint_string (i32.const 3104))
            (local.set $failed (i32.const 1))))
    (if (i32.eqz (call $bytes_eq_at_outbase (i32.const 4176)))
      (then (call $eprint_string (i32.const 3364))
            (call $eprint_string (i32.const 3104))
            (local.set $failed (i32.const 1))))

    ;; ── Phase 5: LFeedback(h=42, body=LConst(7), spec=LConst(0)) ──
    ;; Uses raw integer 42 as the handle to test $s<h> emission.
    (local.set $r_lfb
      (call $lexpr_make_lfeedback
        (i32.const 42)
        (local.get $lc7)
        (local.get $lc0)))
    (global.set $out_pos (i32.const 0))
    (call $emit_lfeedback (local.get $r_lfb))
    (if (i32.ne (global.get $out_pos) (i32.const 112))
      (then (call $eprint_string (i32.const 3392))
            (call $eprint_string (i32.const 3104))
            (local.set $failed (i32.const 1))))
    (if (i32.eqz (call $bytes_eq_at_outbase (i32.const 4200)))
      (then (call $eprint_string (i32.const 3420))
            (call $eprint_string (i32.const 3104))
            (local.set $failed (i32.const 1))))

    ;; ── Phase 6: LPerform(h, "print", [LConst(7)]) ──
    (local.set $r_lperform
      (call $lexpr_make_lperform
        (local.get $h_var)
        (i32.const 3624)                                ;; "print"
        (local.get $args_lc7)))
    (global.set $out_pos (i32.const 0))
    (call $emit_lperform (local.get $r_lperform))
    (if (i32.ne (global.get $out_pos) (i32.const 29))
      (then (call $eprint_string (i32.const 3448))
            (call $eprint_string (i32.const 3104))
            (local.set $failed (i32.const 1))))
    (if (i32.eqz (call $bytes_eq_at_outbase (i32.const 4320)))
      (then (call $eprint_string (i32.const 3476))
            (call $eprint_string (i32.const 3104))
            (local.set $failed (i32.const 1))))

    ;; ── Phase 7: LEvPerform(h, "op", slot=2, args=[LConst(7)]) ──
    ;; body_capture_count=0 (default; emit_init sets it).
    ;; offset = 8 + 4*0 + 4*2 = 16.
    (local.set $r_levperform
      (call $lexpr_make_levperform
        (local.get $h_var)
        (i32.const 3640)                                ;; "op"
        (i32.const 2)                                   ;; slot_idx
        (local.get $args_lc7)))
    (global.set $out_pos (i32.const 0))
    (call $emit_levperform (local.get $r_levperform))
    (if (i32.ne (global.get $out_pos) (i32.const 100))
      (then (call $eprint_string (i32.const 3504))
            (call $eprint_string (i32.const 3104))
            (local.set $failed (i32.const 1))))
    (if (i32.eqz (call $bytes_eq_at_outbase (i32.const 4356)))
      (then (call $eprint_string (i32.const 3532))
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
