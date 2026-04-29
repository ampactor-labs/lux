  ;; ═══ emit_control_arms.wat — Hβ.emit chunk #5 trace harness ════════
  ;; Executes: Hβ-emit-substrate.md §2.3 (control family — LReturn tag
  ;;           310 + LIf tag 314 + LBlock tag 315 + LMatch tag 321 +
  ;;           LRegion tag 328) + §5.1 (eight interrogations) + §8
  ;;           acceptance + §11.3.
  ;; Exercises: bootstrap/src/emit/emit_control.wat — 5 §2.3 arms +
  ;;            $emit_lexpr partial-dispatcher retrofit (chunk #5 adds
  ;;            tags 310/314/315/321/328 to the table).
  ;; Per ROADMAP §5 + Hβ-emit-substrate.md §8.1 + §11.4 acceptance.
  ;;
  ;; ─── Eight interrogations (per Hβ-emit §5.1 second pass) ──────────
  ;;   Graph?      Each phase constructs a control-family LowExpr via
  ;;               $lexpr_make_l*. Sub-LowExprs (cond/then/else/scrut/
  ;;               body) are LConst-bound (TInt) so $emit_lexpr's
  ;;               recursion terminates at known dispatch arms.
  ;;   Handler?    Direct calls to $emit_l* (seed Tier-6 base);
  ;;               @resume=OneShot at wheel.
  ;;   Verb?       Sequential phases — N/A.
  ;;   Row?        Side-effect on $out_base/$out_pos via $emit_byte;
  ;;               read-only LowExpr traversal.
  ;;   Ownership?  LowExpr records OWN by harness; $out_base buffer
  ;;               OWNed program-wide.
  ;;   Refinement? None.
  ;;   Gradient?   Phase 4 (LMatch empty arms → "(unreachable)") proves
  ;;               the exhaustiveness-violation runtime trap that
  ;;               complements the inference-time E_PatternInexhaustive
  ;;               check. The HB threshold-aware mixed-variant dispatch
  ;;               at the gradient cash-out lands per NAMED follow-up
  ;;               Hβ.emit.lmatch-pattern-compile when LowPat substrate
  ;;               populates.
  ;;   Reason?     N/A — round-trip verification only.
  ;;
  ;; ─── Forbidden patterns audited ───────────────────────────────────
  ;;   - Drift 1 (vtable):      $emit_lexpr direct (i32.eq tag N)
  ;;                            dispatch tested via byte-output round-trip.
  ;;   - Drift 5 (C calling):   single LowExpr ref per arm.
  ;;   - Drift 6 (Bool special): N/A this chunk; LMatch's HB threshold
  ;;                            substrate is the named follow-up.
  ;;   - Drift 8 (string-keyed): tag dispatch via integer constants.
  ;;   - Drift 9 (deferred):    every assertion bodied; LMatch nonempty-
  ;;                            arms is the NAMED follow-up
  ;;                            Hβ.emit.lmatch-pattern-compile (positive-
  ;;                            form deferral via explicit naming).

  ;; ─── Harness-private data segments ────────────────────────────────

  (data (i32.const 3072) "\05\00\00\00PASS:")
  (data (i32.const 3084) "\05\00\00\00FAIL:")
  (data (i32.const 3096) "\01\00\00\00 ")
  (data (i32.const 3104) "\01\00\00\00\0a")

  ;; Harness display name — offset 3120 (18 chars)
  (data (i32.const 3120) "\12\00\00\00emit_control_arms ")

  ;; Per-assertion FAIL labels — 28-byte slots (4 hdr + 24 body)
  (data (i32.const 3168) "\18\00\00\00phase1-lreturn-pos-bad  ")
  (data (i32.const 3196) "\18\00\00\00phase1-lreturn-bytes-bad")
  (data (i32.const 3224) "\18\00\00\00phase2-lif-pos-bad      ")
  (data (i32.const 3252) "\18\00\00\00phase2-lif-bytes-bad    ")
  (data (i32.const 3280) "\18\00\00\00phase3-lblock-pos-bad   ")
  (data (i32.const 3308) "\18\00\00\00phase3-lblock-bytes-bad ")
  (data (i32.const 3336) "\18\00\00\00phase4-lmatch-pos-bad   ")
  (data (i32.const 3364) "\18\00\00\00phase4-lmatch-bytes-bad ")
  (data (i32.const 3392) "\18\00\00\00phase5-lregion-pos-bad  ")
  (data (i32.const 3420) "\18\00\00\00phase5-lregion-bytes-bad")

  ;; ─── Expected emission bytes per phase (offsets ≥ 4096) ───────────

  ;; Phase 1 — LReturn(h, LConst(7)) → "(i32.const 7)(return)" (21 bytes)
  (data (i32.const 4096) "\15\00\00\00(i32.const 7)(return)")

  ;; Phase 2 — LIf(h, LConst(1), [LConst(7)], [LConst(8)]) (68 bytes)
  ;;   "(i32.const 1)(if (result i32)(then(i32.const 7))(else(i32.const 8)))"
  (data (i32.const 4128)
    "\44\00\00\00(i32.const 1)(if (result i32)(then(i32.const 7))(else(i32.const 8)))")

  ;; Phase 3 — LBlock(h, [LConst(7), LConst(8)]) → "(i32.const 7)(i32.const 8)" (26 bytes)
  (data (i32.const 4208) "\1a\00\00\00(i32.const 7)(i32.const 8)")

  ;; Phase 4 — LMatch(h, LConst(7), []) — empty arms (48 bytes)
  ;;   "(i32.const 7)(local.set $scrut_tmp)(unreachable)"
  (data (i32.const 4240) "\30\00\00\00(i32.const 7)(local.set $scrut_tmp)(unreachable)")

  ;; Phase 5 — LRegion(h, [LConst(7)]) → "(i32.const 7)" (13 bytes; inert seed)
  (data (i32.const 4296) "\0d\00\00\00(i32.const 7)")

  ;; ─── _start ──────────────────────────────────────────────────────
  (func $_start (export "_start")
    (local $failed i32)
    (local $h_int i32) (local $h_var i32)
    (local $lc1 i32) (local $lc7 i32) (local $lc8 i32)
    (local $then_branch i32) (local $else_branch i32)
    (local $block_stmts i32) (local $region_body i32)
    (local $r_return i32) (local $r_if i32) (local $r_block i32)
    (local $r_match i32) (local $r_region i32)
    (local.set $failed (i32.const 0))

    (call $emit_init)
    (call $graph_init)

    ;; Bind two TInt handles.
    (local.set $h_int (call $graph_fresh_ty (call $reason_make_fresh (i32.const 0))))
    (call $graph_bind (local.get $h_int)
                      (call $ty_make_tint)
                      (call $reason_make_fresh (i32.const 0)))
    (local.set $h_var (call $graph_fresh_ty (call $reason_make_fresh (i32.const 1))))
    (call $graph_bind (local.get $h_var)
                      (call $ty_make_tint)
                      (call $reason_make_fresh (i32.const 1)))

    ;; LConst sub-elements.
    (local.set $lc1 (call $lexpr_make_lconst (local.get $h_int) (i32.const 1)))
    (local.set $lc7 (call $lexpr_make_lconst (local.get $h_int) (i32.const 7)))
    (local.set $lc8 (call $lexpr_make_lconst (local.get $h_int) (i32.const 8)))

    ;; Single-element then/else/region branches.
    (local.set $then_branch (call $make_list (i32.const 1)))
    (local.set $then_branch (call $list_extend_to (local.get $then_branch) (i32.const 1)))
    (drop (call $list_set (local.get $then_branch) (i32.const 0) (local.get $lc7)))

    (local.set $else_branch (call $make_list (i32.const 1)))
    (local.set $else_branch (call $list_extend_to (local.get $else_branch) (i32.const 1)))
    (drop (call $list_set (local.get $else_branch) (i32.const 0) (local.get $lc8)))

    (local.set $region_body (call $make_list (i32.const 1)))
    (local.set $region_body (call $list_extend_to (local.get $region_body) (i32.const 1)))
    (drop (call $list_set (local.get $region_body) (i32.const 0) (local.get $lc7)))

    ;; Two-element block stmts list.
    (local.set $block_stmts (call $make_list (i32.const 2)))
    (local.set $block_stmts (call $list_extend_to (local.get $block_stmts) (i32.const 2)))
    (drop (call $list_set (local.get $block_stmts) (i32.const 0) (local.get $lc7)))
    (drop (call $list_set (local.get $block_stmts) (i32.const 1) (local.get $lc8)))

    ;; ── Phase 1: LReturn(h, LConst(7)) → "(i32.const 7)(return)" ──
    (local.set $r_return
      (call $lexpr_make_lreturn (local.get $h_var) (local.get $lc7)))
    (global.set $out_pos (i32.const 0))
    (call $emit_lreturn (local.get $r_return))
    (if (i32.ne (global.get $out_pos) (i32.const 21))
      (then
        (call $eprint_string (i32.const 3168))
        (call $eprint_string (i32.const 3104))
        (local.set $failed (i32.const 1))))
    (if (i32.eqz (call $bytes_eq_at_outbase (i32.const 4096)))
      (then
        (call $eprint_string (i32.const 3196))
        (call $eprint_string (i32.const 3104))
        (local.set $failed (i32.const 1))))

    ;; ── Phase 2: LIf(h, LConst(1), [LConst(7)], [LConst(8)]) ──
    (local.set $r_if
      (call $lexpr_make_lif
        (local.get $h_var)
        (local.get $lc1)
        (local.get $then_branch)
        (local.get $else_branch)))
    (global.set $out_pos (i32.const 0))
    (call $emit_lif (local.get $r_if))
    (if (i32.ne (global.get $out_pos) (i32.const 68))
      (then
        (call $eprint_string (i32.const 3224))
        (call $eprint_string (i32.const 3104))
        (local.set $failed (i32.const 1))))
    (if (i32.eqz (call $bytes_eq_at_outbase (i32.const 4128)))
      (then
        (call $eprint_string (i32.const 3252))
        (call $eprint_string (i32.const 3104))
        (local.set $failed (i32.const 1))))

    ;; ── Phase 3: LBlock(h, [LConst(7), LConst(8)]) ──
    (local.set $r_block
      (call $lexpr_make_lblock (local.get $h_var) (local.get $block_stmts)))
    (global.set $out_pos (i32.const 0))
    (call $emit_lblock (local.get $r_block))
    (if (i32.ne (global.get $out_pos) (i32.const 26))
      (then
        (call $eprint_string (i32.const 3280))
        (call $eprint_string (i32.const 3104))
        (local.set $failed (i32.const 1))))
    (if (i32.eqz (call $bytes_eq_at_outbase (i32.const 4208)))
      (then
        (call $eprint_string (i32.const 3308))
        (call $eprint_string (i32.const 3104))
        (local.set $failed (i32.const 1))))

    ;; ── Phase 4: LMatch(h, LConst(7), []) — empty arms ──
    (local.set $r_match
      (call $lexpr_make_lmatch
        (local.get $h_var)
        (local.get $lc7)
        (call $make_list (i32.const 0))))
    (global.set $out_pos (i32.const 0))
    (call $emit_lmatch (local.get $r_match))
    (if (i32.ne (global.get $out_pos) (i32.const 48))
      (then
        (call $eprint_string (i32.const 3336))
        (call $eprint_string (i32.const 3104))
        (local.set $failed (i32.const 1))))
    (if (i32.eqz (call $bytes_eq_at_outbase (i32.const 4240)))
      (then
        (call $eprint_string (i32.const 3364))
        (call $eprint_string (i32.const 3104))
        (local.set $failed (i32.const 1))))

    ;; ── Phase 5: LRegion(h, [LConst(7)]) — inert seed ──
    (local.set $r_region
      (call $lexpr_make_lregion (local.get $h_var) (local.get $region_body)))
    (global.set $out_pos (i32.const 0))
    (call $emit_lregion (local.get $r_region))
    (if (i32.ne (global.get $out_pos) (i32.const 13))
      (then
        (call $eprint_string (i32.const 3392))
        (call $eprint_string (i32.const 3104))
        (local.set $failed (i32.const 1))))
    (if (i32.eqz (call $bytes_eq_at_outbase (i32.const 4296)))
      (then
        (call $eprint_string (i32.const 3420))
        (call $eprint_string (i32.const 3104))
        (local.set $failed (i32.const 1))))

    ;; ── Verdict ──
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

  ;; ─── $bytes_eq_at_outbase — same shape as prior emit/* harnesses ──
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
