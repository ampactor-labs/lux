  ;; ═══ emit_lmatch.wat — Hβ.emit.match-pattern-compile harness ═════════
  ;; Executes: Phase E — $emit_lmatch (tag 321) three-shape match dispatch
  ;;           per Hβ-emit-substrate.md §2.3 + src/backends/wasm.mn:1792+.
  ;;           Proves the H6 gradient cash-out: Bool is NOT special, every
  ;;           nullary variant compiles through the same PureNullary path.
  ;;           One mechanism for all ADT matching. No Drift 6.
  ;; Exercises: emit_control.wat $emit_lmatch, $ec5_classify_arms_shape,
  ;;            $ec5_emit_match_arms_from, $ec5_emit_local_get_scrut_tmp,
  ;;            $ec5_emit_i32_eq, $ec_emit_unreachable, $emit_lexpr
  ;;            recursion into LConst sub-elements, lowpat.wat LPArm/LPCon
  ;;            /LPWild ADT accessors.
  ;; Per ROADMAP Phase E + Hβ-emit-substrate.md §8.1.
  ;;
  ;; ─── Eight interrogations (per Hβ-emit §5.1 / SUBSTRATE §I) ────────
  ;;   Graph?      Harness constructs handle h bound to TInt via
  ;;               $graph_fresh_ty + $graph_bind. LConst body arms
  ;;               recurse through $emit_lexpr → graph lookup → TInt →
  ;;               (i32.const N). Per Anchor 1: ask the graph.
  ;;   Handler?    Direct call to $emit_lmatch. The three-shape dispatch
  ;;               IS handler-projection at the value level — pattern
  ;;               matching on ADT variants is the same structural
  ;;               operation as handler-arm dispatch on effect ops.
  ;;   Verb?       scrut → classify shape → dispatch chain → per-arm
  ;;               body emission. Linear |> topology.
  ;;   Row?        EmitMemory side-effect on $out_base/$out_pos via
  ;;               $emit_byte. No allocation — pure control flow.
  ;;   Ownership?  Scrutinee ref-borrowed across arm tests. LowExpr
  ;;               records OWN by harness. $out_base OWNed program-wide.
  ;;   Refinement? Exhaustiveness is inference-time obligation;
  ;;               emit-time (unreachable) is the runtime complement.
  ;;   Gradient?   THIS IS the H6 gradient cash-out. Every nullary
  ;;               ADT variant compiles to sentinel + direct compare.
  ;;               No Bool special case. One mechanism.
  ;;   Reason?     Pattern discrimination edge composes with arm-body's
  ;;               Reason chain via $lexpr_handle.
  ;;
  ;; ─── Forbidden patterns audited ─────────────────────────────────────
  ;;   - Drift 1 (vtable):     Tag-int comparison chain via (i32.eq).
  ;;                            NO dispatch table, NO fn-pointer array.
  ;;   - Drift 6 (Bool):       PureNullary handles Bool identically to
  ;;                            every other nullary ADT. No Bool branch.
  ;;   - Drift 8 (string-key): LPCon tag_id is i32 sentinel, not string.
  ;;   - Drift 9 (deferred):   PureNullary + LPWild arms bodied.

  ;; ─── Harness-private data segments ──────────────────────────────────
  (data (i32.const 3072) "\05\00\00\00PASS:")
  (data (i32.const 3084) "\05\00\00\00FAIL:")
  (data (i32.const 3096) "\01\00\00\00 ")
  (data (i32.const 3104) "\01\00\00\00\0a")

  ;; Harness display name — "emit_lmatch " (12 chars)
  (data (i32.const 3120) "\0c\00\00\00emit_lmatch ")

  ;; Per-assertion FAIL labels — 32-byte slots
  (data (i32.const 3168) "\1c\00\00\00nullary-pos-bad             ")
  (data (i32.const 3200) "\1c\00\00\00nullary-bytes-bad           ")
  (data (i32.const 3232) "\1c\00\00\00wild-pos-bad                ")
  (data (i32.const 3264) "\1c\00\00\00wild-bytes-bad              ")

  ;; ─── Expected emission: PureNullary match ───────────────────────────
  ;; LMatch(0, LConst(h,7), [
  ;;   LPArm(LPCon(h, 0, []), LConst(h, 42)),
  ;;   LPArm(LPCon(h, 1, []), LConst(h, 99))
  ;; ])
  ;; Emits:
  ;;   (i32.const 7)             ← scrutinee
  ;;   (local.set $scrut_tmp)
  ;;   (local.get $scrut_tmp)(i32.const 0)(i32.eq)
  ;;   (if (result i32)(then
  ;;     (i32.const 42)
  ;;   )(else
  ;;     (local.get $scrut_tmp)(i32.const 1)(i32.eq)
  ;;     (if (result i32)(then
  ;;       (i32.const 99)
  ;;     )(else
  ;;       (unreachable)
  ;;     ))
  ;;   ))
  ;; 220 bytes = 0xdc → LE prefix \dc\00\00\00
  (data (i32.const 4096)
    "\dc\00\00\00(i32.const 7)(local.set $scrut_tmp)(local.get $scrut_tmp)(i32.const 0)(i32.eq)(if (result i32)(then(i32.const 42))(else(local.get $scrut_tmp)(i32.const 1)(i32.eq)(if (result i32)(then(i32.const 99))(else(unreachable)))))")

  ;; ─── Expected emission: LPWild terminal ─────────────────────────────
  ;; LMatch(0, LConst(h,7), [LPArm(LPWild(h), LConst(h,42))])
  ;; Emits:
  ;;   (i32.const 7)(local.set $scrut_tmp)(i32.const 42)
  ;; 49 bytes = 0x31 → LE prefix \31\00\00\00
  (data (i32.const 4352)
    "\31\00\00\00(i32.const 7)(local.set $scrut_tmp)(i32.const 42)")

  ;; ─── _start ─────────────────────────────────────────────────────────
  (func $_start (export "_start")
    (local $failed i32)
    (local $h i32)
    (local $scrut i32)
    (local $arm0 i32) (local $arm1 i32)
    (local $arms i32)
    (local $r i32)
    (local.set $failed (i32.const 0))

    ;; Initialize emit + graph state.
    (call $emit_init)
    (call $graph_init)

    ;; Build handle h bound to TInt.
    (local.set $h (call $graph_fresh_ty (call $reason_make_fresh (i32.const 0))))
    (call $graph_bind (local.get $h)
                      (call $ty_make_tint)
                      (call $reason_make_fresh (i32.const 0)))

    ;; ═══ Phase 1: PureNullary match ═══════════════════════════════════
    ;; match LConst(h,7) { Con(0,[]) => LConst(42), Con(1,[]) => LConst(99) }
    (local.set $scrut (call $lexpr_make_lconst (local.get $h) (i32.const 7)))

    ;; Arm 0: LPArm(LPCon(h, 0, []), LConst(h, 42))
    (local.set $arm0
      (call $lowpat_make_lparm
        (call $lowpat_make_lpcon (local.get $h) (i32.const 0)
              (call $make_list (i32.const 0)))
        (call $lexpr_make_lconst (local.get $h) (i32.const 42))))

    ;; Arm 1: LPArm(LPCon(h, 1, []), LConst(h, 99))
    (local.set $arm1
      (call $lowpat_make_lparm
        (call $lowpat_make_lpcon (local.get $h) (i32.const 1)
              (call $make_list (i32.const 0)))
        (call $lexpr_make_lconst (local.get $h) (i32.const 99))))

    ;; arms = [arm0, arm1]
    (local.set $arms (call $make_list (i32.const 2)))
    (local.set $arms (call $list_extend_to (local.get $arms) (i32.const 2)))
    (drop (call $list_set (local.get $arms) (i32.const 0) (local.get $arm0)))
    (drop (call $list_set (local.get $arms) (i32.const 1) (local.get $arm1)))

    ;; Build LMatch(0, scrut, arms)
    (local.set $r (call $lexpr_make_lmatch
      (i32.const 0) (local.get $scrut) (local.get $arms)))

    ;; Reset and emit.
    (global.set $out_pos (i32.const 0))
    (call $emit_lmatch (local.get $r))

    ;; ── Check 1: PureNullary length — $out_pos must equal 220 ──
    (if (i32.ne (global.get $out_pos) (i32.const 220))
      (then
        (call $eprint_string (i32.const 3168))
        (call $eprint_string (i32.const 3104))
        (local.set $failed (i32.const 1))))

    ;; ── Check 2: PureNullary exact byte match ──
    (if (i32.eqz (call $bytes_eq_at_outbase (i32.const 4096)))
      (then
        (call $eprint_string (i32.const 3200))
        (call $eprint_string (i32.const 3104))
        (local.set $failed (i32.const 1))))

    ;; ═══ Phase 2: LPWild terminal match ═══════════════════════════════
    ;; match LConst(h,7) { _ => LConst(h,42) }
    (local.set $arm0
      (call $lowpat_make_lparm
        (call $lowpat_make_lpwild (local.get $h))
        (call $lexpr_make_lconst (local.get $h) (i32.const 42))))
    (local.set $arms (call $make_list (i32.const 1)))
    (local.set $arms (call $list_extend_to (local.get $arms) (i32.const 1)))
    (drop (call $list_set (local.get $arms) (i32.const 0) (local.get $arm0)))
    (local.set $r (call $lexpr_make_lmatch
      (i32.const 0) (local.get $scrut) (local.get $arms)))

    ;; Reset and emit.
    (global.set $out_pos (i32.const 0))
    (call $emit_lmatch (local.get $r))

    ;; ── Check 3: LPWild length — $out_pos must equal 49 ──
    (if (i32.ne (global.get $out_pos) (i32.const 49))
      (then
        (call $eprint_string (i32.const 3232))
        (call $eprint_string (i32.const 3104))
        (local.set $failed (i32.const 1))))

    ;; ── Check 4: LPWild exact byte match ──
    (if (i32.eqz (call $bytes_eq_at_outbase (i32.const 4352)))
      (then
        (call $eprint_string (i32.const 3264))
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

  ;; ─── $bytes_eq_at_outbase ───────────────────────────────────────────
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
