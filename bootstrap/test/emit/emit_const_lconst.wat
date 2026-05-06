  ;; ═══ emit_const_lconst.wat — Hβ.emit chunk #3 trace-harness ══════════
  ;; Executes: Hβ-emit-substrate.md §2.1 (LConst tag 300 → Ty-tag dispatch
  ;;           per $lookup_ty($lexpr_handle(r))) + §3.5 (EmitMemory swap
  ;;           surface — emission routes through emit_infra) + §5.1 (eight
  ;;           interrogations at dispatcher) + §8 acceptance.
  ;; Exercises: bootstrap/src/emit/emit_const.wat — $emit_lconst across
  ;;            all four Ty-tag arms (TInt-100, TUnit-103, TError-hole-114,
  ;;            TString-102). Verifies output bytes round-trip via
  ;;            $out_base/$out_pos byte-comparison.
  ;; Per ROADMAP §5 + Hβ-emit-substrate.md §8.1 + §11.4 acceptance.
  ;;
  ;; ─── Eight interrogations (per Hβ-emit §5.1 second pass) ──────────
  ;;   Graph?      Constructs Ty bindings via $graph_fresh_ty +
  ;;               $graph_bind so $lookup_ty(handle) chases through
  ;;               NBound to return the bound Ty. The graph IS populated
  ;;               at-emit-time per Anchor 1; emit reads it live.
  ;;   Handler?    Direct calls to $emit_lconst (seed Tier-6 base; @resume=
  ;;               OneShot at the wheel — single-pass emission per
  ;;               src/backends/wasm.mn LConst arm shape).
  ;;   Verb?       N/A — sequential per-phase setup + emit.
  ;;   Row?        EfPure for $lookup_ty (read-only); EmitMemory side-
  ;;               effect on $out_base/$out_pos via $emit_byte. The harness
  ;;               does not consult the row.
  ;;   Ownership?  Tys + LConst records OWN by harness; $out_base buffer
  ;;               OWN by emit pass globally (substrate-level reference per
  ;;               §3.5). Harness reads bytes back via i32.load8_u for
  ;;               byte-comparison; ref-only.
  ;;   Refinement? None.
  ;;   Gradient?   This harness IS one pixel of §8.1 acceptance — proves
  ;;               LConst's per-Ty-tag emission round-trips so chunks #4-#9
  ;;               can compose on it. The fall-through TInt arm + TString
  ;;               intern + TUnit sentinel + TError-hole "(unreachable)"
  ;;               are the four cardinal cash-out points.
  ;;   Reason?     $reason_make_fresh attached at $graph_fresh_ty +
  ;;               $graph_bind sites; harness verifies value round-trip,
  ;;               does not walk Reason chain.

  ;; ─── Harness-private data segment (offsets ≥ 3072, < HEAP_BASE 4096) ──

  (data (i32.const 3072) "\05\00\00\00PASS:")
  (data (i32.const 3084) "\05\00\00\00FAIL:")
  (data (i32.const 3096) "\01\00\00\00 ")
  (data (i32.const 3104) "\01\00\00\00\0a")

  ;; Harness display name — offset 3120 (17 chars, padded to 24)
  (data (i32.const 3120) "\11\00\00\00emit_const_lconst")

  ;; Per-assertion FAIL labels — offsets 3144+ (24-byte slots: 4 hdr + 20 body)
  (data (i32.const 3144) "\14\00\00\00phase1-tint-pos-bad ")
  (data (i32.const 3168) "\14\00\00\00phase1-tint-bytes   ")
  (data (i32.const 3192) "\14\00\00\00phase2-tunit-pos-bad")
  (data (i32.const 3216) "\14\00\00\00phase2-tunit-bytes  ")
  (data (i32.const 3240) "\14\00\00\00phase3-thole-pos-bad")
  (data (i32.const 3264) "\14\00\00\00phase3-thole-bytes  ")
  (data (i32.const 3288) "\14\00\00\00phase4-tstr-pos-bad ")
  (data (i32.const 3312) "\14\00\00\00phase4-tstr-bytes   ")

  ;; Expected emission bytes per phase (length-prefixed, then padded).
  ;; Phase 1: "(i32.const 7)" = 13 bytes
  (data (i32.const 3336) "\0d\00\00\00(i32.const 7)")
  ;; Phase 2: "(i32.const 0)" = 13 bytes
  (data (i32.const 3356) "\0d\00\00\00(i32.const 0)")
  ;; Phase 3: "(unreachable)" = 13 bytes
  (data (i32.const 3376) "\0d\00\00\00(unreachable)")
  ;; Phase 4: "(i32.const 65536)" = 17 bytes (first intern offset is 65536
  ;; per emit/state.wat:182 — wheel-canonical initial-offset constant)
  (data (i32.const 3396) "\11\00\00\00(i32.const 65536)")

  ;; Phase-4 input string — "hello" = 5 bytes
  (data (i32.const 3420) "\05\00\00\00hello")

  ;; ─── _start ──────────────────────────────────────────────────────
  (func $_start (export "_start")
    (local $failed i32)
    (local $h1 i32) (local $h2 i32) (local $h3 i32) (local $h4 i32)
    (local $r1 i32) (local $r2 i32) (local $r3 i32) (local $r4 i32)
    (local.set $failed (i32.const 0))

    ;; Initialize emit + graph state (idempotent).
    (call $emit_init)
    (call $graph_init)

    ;; ── Phase 1: TInt LConst, value=7 → "(i32.const 7)" ──
    (local.set $h1 (call $graph_fresh_ty (call $reason_make_fresh (i32.const 0))))
    (call $graph_bind (local.get $h1)
                      (call $ty_make_tint)
                      (call $reason_make_fresh (i32.const 0)))
    (local.set $r1 (call $lexpr_make_lconst (local.get $h1) (i32.const 7)))
    (global.set $out_pos (i32.const 0))
    (call $emit_lconst (local.get $r1))
    (if (i32.ne (global.get $out_pos) (i32.const 13))
      (then
        (call $eprint_string (i32.const 3144))
        (call $eprint_string (i32.const 3104))
        (local.set $failed (i32.const 1))))
    (if (i32.eqz (call $bytes_eq_at_outbase (i32.const 3336)))
      (then
        (call $eprint_string (i32.const 3168))
        (call $eprint_string (i32.const 3104))
        (local.set $failed (i32.const 1))))

    ;; ── Phase 2: TUnit LConst, value=0 → "(i32.const 0)" ──
    (local.set $h2 (call $graph_fresh_ty (call $reason_make_fresh (i32.const 1))))
    (call $graph_bind (local.get $h2)
                      (call $ty_make_tunit)
                      (call $reason_make_fresh (i32.const 1)))
    (local.set $r2 (call $lexpr_make_lconst (local.get $h2) (i32.const 0)))
    (global.set $out_pos (i32.const 0))
    (call $emit_lconst (local.get $r2))
    (if (i32.ne (global.get $out_pos) (i32.const 13))
      (then
        (call $eprint_string (i32.const 3192))
        (call $eprint_string (i32.const 3104))
        (local.set $failed (i32.const 1))))
    (if (i32.eqz (call $bytes_eq_at_outbase (i32.const 3356)))
      (then
        (call $eprint_string (i32.const 3216))
        (call $eprint_string (i32.const 3104))
        (local.set $failed (i32.const 1))))

    ;; ── Phase 3: TError-hole LConst → "(unreachable)" ──
    ;; Bind the handle to the TError-hole sentinel (114) — $graph_chase
    ;; walks NBound → returns 114; $ty_tag(114) = 114 via $tag_of's
    ;; sentinel-aware dispatch (ty.wat:248-249).
    (local.set $h3 (call $graph_fresh_ty (call $reason_make_fresh (i32.const 2))))
    (call $graph_bind (local.get $h3)
                      (call $ty_make_terror_hole)
                      (call $reason_make_fresh (i32.const 2)))
    (local.set $r3 (call $lexpr_make_lconst (local.get $h3) (i32.const 0)))
    (global.set $out_pos (i32.const 0))
    (call $emit_lconst (local.get $r3))
    (if (i32.ne (global.get $out_pos) (i32.const 13))
      (then
        (call $eprint_string (i32.const 3240))
        (call $eprint_string (i32.const 3104))
        (local.set $failed (i32.const 1))))
    (if (i32.eqz (call $bytes_eq_at_outbase (i32.const 3376)))
      (then
        (call $eprint_string (i32.const 3264))
        (call $eprint_string (i32.const 3104))
        (local.set $failed (i32.const 1))))

    ;; ── Phase 4: TString LConst, value=str_ptr → "(i32.const 65536)" ──
    ;; First intern lands at offset 65536 per state.wat:182. Phase 4
    ;; runs after Phases 1-3 which never call $emit_string_intern, so
    ;; "hello" is the FIRST interned string and gets 65536.
    (local.set $h4 (call $graph_fresh_ty (call $reason_make_fresh (i32.const 3))))
    (call $graph_bind (local.get $h4)
                      (call $ty_make_tstring)
                      (call $reason_make_fresh (i32.const 3)))
    (local.set $r4 (call $lexpr_make_lconst (local.get $h4) (i32.const 3420)))
    (global.set $out_pos (i32.const 0))
    (call $emit_lconst (local.get $r4))
    (if (i32.ne (global.get $out_pos) (i32.const 17))
      (then
        (call $eprint_string (i32.const 3288))
        (call $eprint_string (i32.const 3104))
        (local.set $failed (i32.const 1))))
    (if (i32.eqz (call $bytes_eq_at_outbase (i32.const 3396)))
      (then
        (call $eprint_string (i32.const 3312))
        (call $eprint_string (i32.const 3104))
        (local.set $failed (i32.const 1))))

    ;; ── Verdict ──
    (if (local.get $failed)
      (then
        (call $eprint_string (i32.const 3084))   ;; "FAIL:"
        (call $eprint_string (i32.const 3096))   ;; " "
        (call $eprint_string (i32.const 3120))   ;; "emit_const_lconst"
        (call $eprint_string (i32.const 3104))   ;; "\n"
        (call $wasi_proc_exit (i32.const 1)))
      (else
        (call $eprint_string (i32.const 3072))   ;; "PASS:"
        (call $eprint_string (i32.const 3096))   ;; " "
        (call $eprint_string (i32.const 3120))   ;; "emit_const_lconst"
        (call $eprint_string (i32.const 3104))   ;; "\n"
        (call $wasi_proc_exit (i32.const 0)))))

  ;; ─── $bytes_eq_at_outbase — compare $out_pos bytes at $out_base
  ;;     against expected length-prefixed string at $expected.
  ;; Returns 1 if length matches AND every byte matches; 0 otherwise.
  ;; Used by every phase to verify exact emission shape.
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
