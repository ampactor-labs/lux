  ;; ═══ emit_local_arms.wat — Hβ.emit chunk #4 trace harness ═══════════
  ;; Executes: Hβ-emit-substrate.md §2.2 (local-scope family — LLocal
  ;;           tag 301 + LGlobal tag 302 + LStore tag 303 + LUpval tag 305
  ;;           + LStateGet tag 326 + LStateSet tag 327 + LFieldLoad tag
  ;;           334) + §5.1 (eight interrogations) + §8 acceptance + §11.3.
  ;; Exercises: bootstrap/src/emit/emit_local.wat — 7 §2.2 arms + the
  ;;            $emit_lexpr partial-dispatcher retrofit (chunk #4 adds
  ;;            tags 301/302/303/305/326/327/334 to the table).
  ;; Per ROADMAP §5 + Hβ-emit-substrate.md §8.1 + §11.4 acceptance.
  ;;
  ;; ─── Eight interrogations (per Hβ-emit §5.1 second pass) ──────────
  ;;   Graph?      Each phase constructs LowExpr records via $lexpr_make_*
  ;;               with bound handles; LStore/LStateSet/LFieldLoad sub-
  ;;               LowExprs are LConst-bound (TInt) so $emit_lexpr's
  ;;               recursion terminates at known dispatch arms.
  ;;   Handler?    Direct calls to $emit_l* (seed Tier-6 base);
  ;;               @resume=OneShot at wheel.
  ;;   Verb?       Sequential phases — N/A.
  ;;   Row?        Side-effect on $out_base/$out_pos via $emit_byte;
  ;;               no allocation in this chunk (read-only LowExpr
  ;;               traversal).
  ;;   Ownership?  LowExpr records OWN by harness; $out_base buffer
  ;;               OWNed program-wide.
  ;;   Refinement? None.
  ;;   Gradient?   Phase 4 (LUpval) IS the H1.6 evidence reification
  ;;               cash-out — proves closure record IS the unified
  ;;               __state (offset arithmetic on the record, no runtime
  ;;               evidence-table lookup).
  ;;   Reason?     N/A — round-trip verification only.
  ;;
  ;; ─── Forbidden patterns audited ───────────────────────────────────
  ;;   - Drift 1 (vtable):   $emit_lexpr direct (i32.eq tag N) dispatch
  ;;                         tested via byte-output round-trip.
  ;;   - Drift 5 (C calling): single LowExpr ref per arm.
  ;;   - Drift 8 (string-keyed): tag dispatch via integer constants;
  ;;                         names emitted AS strings via $emit_str
  ;;                         (appropriate use — the WAT identifier IS
  ;;                         the user-facing token).
  ;;   - Drift 9 (deferred): every assertion bodied; verdict explicit.

  ;; ─── Harness-private data segments ────────────────────────────────

  (data (i32.const 3072) "\05\00\00\00PASS:")
  (data (i32.const 3084) "\05\00\00\00FAIL:")
  (data (i32.const 3096) "\01\00\00\00 ")
  (data (i32.const 3104) "\01\00\00\00\0a")

  ;; Harness display name — offset 3120 (15 chars)
  (data (i32.const 3120) "\0f\00\00\00emit_local_arms")

  ;; Per-assertion FAIL labels — 28-byte slots (4 hdr + 24 body)
  (data (i32.const 3168) "\18\00\00\00phase1-llocal-pos-bad   ")
  (data (i32.const 3196) "\18\00\00\00phase1-llocal-bytes-bad ")
  (data (i32.const 3224) "\18\00\00\00phase2-lglobal-pos-bad  ")
  (data (i32.const 3252) "\18\00\00\00phase2-lglobal-bytes-bad")
  (data (i32.const 3280) "\18\00\00\00phase3-lstore-pos-bad   ")
  (data (i32.const 3308) "\18\00\00\00phase3-lstore-bytes-bad ")
  (data (i32.const 3336) "\18\00\00\00phase4-lupval-pos-bad   ")
  (data (i32.const 3364) "\18\00\00\00phase4-lupval-bytes-bad ")
  (data (i32.const 3392) "\18\00\00\00phase5-lsget-pos-bad    ")
  (data (i32.const 3420) "\18\00\00\00phase5-lsget-bytes-bad  ")
  (data (i32.const 3448) "\18\00\00\00phase6-lsset-pos-bad    ")
  (data (i32.const 3476) "\18\00\00\00phase6-lsset-bytes-bad  ")
  (data (i32.const 3504) "\18\00\00\00phase7-lfldload-pos-bad ")
  (data (i32.const 3532) "\18\00\00\00phase7-lfldload-bytes   ")

  ;; Local/global name strings (length-prefixed)
  (data (i32.const 3616) "\01\00\00\00x")     ;; LLocal name
  (data (i32.const 3624) "\01\00\00\00g")     ;; LGlobal name

  ;; ─── Expected emission bytes per phase (offsets ≥ 4096) ───────────

  ;; Phase 1 — LLocal(h, "x") → "(local.get $x)" (14 bytes payload)
  (data (i32.const 4096) "\0e\00\00\00(local.get $x)")

  ;; Phase 2 — LGlobal(h, "g") → "(global.get $g)" (15 bytes payload)
  (data (i32.const 4120) "\0f\00\00\00(global.get $g)")

  ;; Phase 3 — LStore(h, slot=3, LConst(7)) → "(i32.const 7)(local.set $l3)" (28 bytes)
  (data (i32.const 4144) "\1c\00\00\00(i32.const 7)(local.set $l3)")

  ;; Phase 4 — LUpval(h, slot=2) → "(local.get $__state)(i32.load offset=16)" (40 bytes)
  (data (i32.const 4184) "\28\00\00\00(local.get $__state)(i32.load offset=16)")

  ;; Phase 5 — LStateGet(h, slot=5) → "(global.get $s5)" (16 bytes)
  (data (i32.const 4232) "\10\00\00\00(global.get $s5)")

  ;; Phase 6 — LStateSet(h, slot=5, LConst(42)) → "(i32.const 42)(global.set $s5)" (30 bytes)
  (data (i32.const 4256) "\1e\00\00\00(i32.const 42)(global.set $s5)")

  ;; Phase 7 — LFieldLoad(h, LConst(999), offset=4) → "(i32.const 999)(i32.load offset=4)" (34 bytes)
  (data (i32.const 4296) "\22\00\00\00(i32.const 999)(i32.load offset=4)")

  ;; ─── _start ──────────────────────────────────────────────────────
  (func $_start (export "_start")
    (local $failed i32)
    (local $h_int i32) (local $h_var i32)
    (local $lc7 i32) (local $lc42 i32) (local $lc999 i32)
    (local $r_local i32) (local $r_global i32) (local $r_store i32)
    (local $r_upval i32) (local $r_sget i32) (local $r_sset i32)
    (local $r_fldload i32)
    (local.set $failed (i32.const 0))

    (call $emit_init)
    (call $graph_init)

    ;; Bind two TInt handles (for LConst sub-elements + outer wrappers).
    (local.set $h_int (call $graph_fresh_ty (call $reason_make_fresh (i32.const 0))))
    (call $graph_bind (local.get $h_int)
                      (call $ty_make_tint)
                      (call $reason_make_fresh (i32.const 0)))
    (local.set $h_var (call $graph_fresh_ty (call $reason_make_fresh (i32.const 1))))
    (call $graph_bind (local.get $h_var)
                      (call $ty_make_tint)
                      (call $reason_make_fresh (i32.const 1)))

    ;; LConst sub-elements for LStore/LStateSet/LFieldLoad.
    (local.set $lc7   (call $lexpr_make_lconst (local.get $h_int) (i32.const 7)))
    (local.set $lc42  (call $lexpr_make_lconst (local.get $h_int) (i32.const 42)))
    (local.set $lc999 (call $lexpr_make_lconst (local.get $h_int) (i32.const 999)))

    ;; ── Phase 1: LLocal(h, "x") → "(local.get $x)" ──
    (local.set $r_local
      (call $lexpr_make_llocal (local.get $h_var) (i32.const 3616)))
    (global.set $out_pos (i32.const 0))
    (call $emit_llocal (local.get $r_local))
    (if (i32.ne (global.get $out_pos) (i32.const 14))
      (then
        (call $eprint_string (i32.const 3168))
        (call $eprint_string (i32.const 3104))
        (local.set $failed (i32.const 1))))
    (if (i32.eqz (call $bytes_eq_at_outbase (i32.const 4096)))
      (then
        (call $eprint_string (i32.const 3196))
        (call $eprint_string (i32.const 3104))
        (local.set $failed (i32.const 1))))

    ;; ── Phase 2: LGlobal(h, "g") → "(global.get $g)" ──
    (local.set $r_global
      (call $lexpr_make_lglobal (local.get $h_var) (i32.const 3624)))
    (global.set $out_pos (i32.const 0))
    (call $emit_lglobal (local.get $r_global))
    (if (i32.ne (global.get $out_pos) (i32.const 15))
      (then
        (call $eprint_string (i32.const 3224))
        (call $eprint_string (i32.const 3104))
        (local.set $failed (i32.const 1))))
    (if (i32.eqz (call $bytes_eq_at_outbase (i32.const 4120)))
      (then
        (call $eprint_string (i32.const 3252))
        (call $eprint_string (i32.const 3104))
        (local.set $failed (i32.const 1))))

    ;; ── Phase 3: LStore(h, slot=3, LConst(7)) → "(i32.const 7)(local.set $l3)" ──
    (local.set $r_store
      (call $lexpr_make_lstore (local.get $h_var) (i32.const 3) (local.get $lc7)))
    (global.set $out_pos (i32.const 0))
    (call $emit_lstore (local.get $r_store))
    (if (i32.ne (global.get $out_pos) (i32.const 28))
      (then
        (call $eprint_string (i32.const 3280))
        (call $eprint_string (i32.const 3104))
        (local.set $failed (i32.const 1))))
    (if (i32.eqz (call $bytes_eq_at_outbase (i32.const 4144)))
      (then
        (call $eprint_string (i32.const 3308))
        (call $eprint_string (i32.const 3104))
        (local.set $failed (i32.const 1))))

    ;; ── Phase 4: LUpval(h, slot=2) → "(local.get $__state)(i32.load offset=16)" ──
    ;; H1.6 evidence reification cash-out: closure record IS the unified
    ;; __state; offset = 8 + 4*slot = 8 + 8 = 16.
    (local.set $r_upval
      (call $lexpr_make_lupval (local.get $h_var) (i32.const 2)))
    (global.set $out_pos (i32.const 0))
    (call $emit_lupval (local.get $r_upval))
    (if (i32.ne (global.get $out_pos) (i32.const 40))
      (then
        (call $eprint_string (i32.const 3336))
        (call $eprint_string (i32.const 3104))
        (local.set $failed (i32.const 1))))
    (if (i32.eqz (call $bytes_eq_at_outbase (i32.const 4184)))
      (then
        (call $eprint_string (i32.const 3364))
        (call $eprint_string (i32.const 3104))
        (local.set $failed (i32.const 1))))

    ;; ── Phase 5: LStateGet(h, slot=5) → "(global.get $s5)" ──
    (local.set $r_sget
      (call $lexpr_make_lstateget (local.get $h_var) (i32.const 5)))
    (global.set $out_pos (i32.const 0))
    (call $emit_lstateget (local.get $r_sget))
    (if (i32.ne (global.get $out_pos) (i32.const 16))
      (then
        (call $eprint_string (i32.const 3392))
        (call $eprint_string (i32.const 3104))
        (local.set $failed (i32.const 1))))
    (if (i32.eqz (call $bytes_eq_at_outbase (i32.const 4232)))
      (then
        (call $eprint_string (i32.const 3420))
        (call $eprint_string (i32.const 3104))
        (local.set $failed (i32.const 1))))

    ;; ── Phase 6: LStateSet(h, slot=5, LConst(42)) → "(i32.const 42)(global.set $s5)" ──
    (local.set $r_sset
      (call $lexpr_make_lstateset (local.get $h_var) (i32.const 5) (local.get $lc42)))
    (global.set $out_pos (i32.const 0))
    (call $emit_lstateset (local.get $r_sset))
    (if (i32.ne (global.get $out_pos) (i32.const 30))
      (then
        (call $eprint_string (i32.const 3448))
        (call $eprint_string (i32.const 3104))
        (local.set $failed (i32.const 1))))
    (if (i32.eqz (call $bytes_eq_at_outbase (i32.const 4256)))
      (then
        (call $eprint_string (i32.const 3476))
        (call $eprint_string (i32.const 3104))
        (local.set $failed (i32.const 1))))

    ;; ── Phase 7: LFieldLoad(h, LConst(999), offset=4) → "(i32.const 999)(i32.load offset=4)" ──
    (local.set $r_fldload
      (call $lexpr_make_lfieldload
        (local.get $h_var)
        (local.get $lc999)
        (i32.const 4)))
    (global.set $out_pos (i32.const 0))
    (call $emit_lfieldload (local.get $r_fldload))
    (if (i32.ne (global.get $out_pos) (i32.const 34))
      (then
        (call $eprint_string (i32.const 3504))
        (call $eprint_string (i32.const 3104))
        (local.set $failed (i32.const 1))))
    (if (i32.eqz (call $bytes_eq_at_outbase (i32.const 4296)))
      (then
        (call $eprint_string (i32.const 3532))
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

  ;; ─── $bytes_eq_at_outbase — same shape as emit_const_lconst ─────
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
