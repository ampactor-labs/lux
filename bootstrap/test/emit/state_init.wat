  ;; ═══ state_init.wat — Hβ.emit trace-harness ═══════════════════════
  ;; Executes: Hβ-emit-substrate.md §3 (H1.4 funcref-table) + §3.5
  ;;           (EmitMemory swap-surface — substrate-level reference) +
  ;;           §5.1 (eight interrogations at dispatcher) + §7.1 (chunk
  ;;           file layout — chunk #1) + §8 acceptance criteria.
  ;; Exercises: bootstrap/src/emit/state.wat — $emit_init
  ;;            $emit_funcref_register $emit_funcref_lookup
  ;;            $emit_funcref_count $emit_funcref_at
  ;;            $emit_set_body_context $emit_body_captures_count
  ;;            $emit_body_evidence $emit_body_evidence_len
  ;;            $emit_string_intern $emit_string_lookup
  ;;            $emit_string_table_count $emit_string_table_at
  ;;            $emit_fn_reset.
  ;; Per ROADMAP §5 + Hβ-emit-substrate.md §8.1 + §11.4 acceptance.
  ;;
  ;; ─── Eight interrogations (per Hβ-emit §5.1 + §5.2 second pass) ────
  ;;   Graph?      N/A — emit-state never chases. Harness passes
  ;;               synthetic 2-element evidence list (not graph handles)
  ;;               to $emit_set_body_context per chunk-header line 134-
  ;;               137 named follow-up Hβ.emit.evidence-slot-naming.
  ;;   Handler?    Direct calls to $emit_* (seed Tier-4 base; @resume=
  ;;               OneShot at the wheel per src/backends/wasm.mn:117-128
  ;;               string_table + 960-961 set_body_captures/_evidence).
  ;;   Verb?       N/A — sequential helper invocations.
  ;;   Row?        EfPure — no effect ops performed.
  ;;   Ownership?  Funcref-table OWNS program-wide; body-context REPLACED
  ;;               per $emit_set_body_context; string-intern OWNS
  ;;               program-wide. Phase 7 below verifies $emit_fn_reset
  ;;               clears body-context BUT NOT funcref-table or string-
  ;;               intern (length-only-reset semantics).
  ;;   Refinement? None.
  ;;   Gradient?   This harness IS one pixel of §8.1 acceptance — proves
  ;;               the emit-time state shape lands correctly so chunks
  ;;               #2-#9 compose on it.
  ;;   Reason?     N/A — emit-state carries no Reason data per state.wat
  ;;               line 87-90.

  ;; ─── Harness-private data segment (offsets ≥ 3072, < HEAP_BASE) ──

  (data (i32.const 3072) "\05\00\00\00PASS:")
  (data (i32.const 3084) "\05\00\00\00FAIL:")
  (data (i32.const 3096) "\01\00\00\00 ")
  (data (i32.const 3104) "\01\00\00\00\0a")

  ;; Harness display name — offset 3120
  (data (i32.const 3120) "\0f\00\00\00emit_state_init")

  ;; Per-assertion FAIL labels — offsets 3144+
  (data (i32.const 3144) "\17\00\00\00funcref-alpha-not-zero ")
  (data (i32.const 3176) "\1a\00\00\00funcref-count-not-one     ")
  (data (i32.const 3208) "\1a\00\00\00funcref-at-zero-mismatch  ")
  (data (i32.const 3240) "\1c\00\00\00funcref-dedup-not-zero      ")
  (data (i32.const 3272) "\1b\00\00\00funcref-dedup-grew-count   ")
  (data (i32.const 3304) "\17\00\00\00funcref-beta-not-one   ")
  (data (i32.const 3336) "\18\00\00\00funcref-gamma-not-two   ")
  (data (i32.const 3368) "\1b\00\00\00funcref-count-not-three    ")
  (data (i32.const 3400) "\1d\00\00\00funcref-lookup-miss-not-neg  ")
  (data (i32.const 3432) "\17\00\00\00body-captures-not-two  ")
  (data (i32.const 3464) "\17\00\00\00body-evidence-len-not-2")
  (data (i32.const 3496) "\1c\00\00\00body-reset-captures-nonzero ")
  (data (i32.const 3528) "\1d\00\00\00body-reset-evidence-len-nz   ")
  (data (i32.const 3560) "\1f\00\00\00funcref-cleared-by-fn-reset!  ")
  (data (i32.const 3592) "\1d\00\00\00str-intern-hello-not-65536   ")
  (data (i32.const 3624) "\1c\00\00\00str-intern-count-not-one    ")
  (data (i32.const 3656) "\1d\00\00\00str-intern-dedup-mismatch    ")
  (data (i32.const 3688) "\1c\00\00\00str-intern-world-bad-offset ")
  (data (i32.const 3720) "\1e\00\00\00str-intern-count-not-two-end  ")
  (data (i32.const 3752) "\1c\00\00\00str-lookup-miss-not-neg-one ")
  (data (i32.const 3784) "\1d\00\00\00str-table-at-zero-mismatch   ")

  ;; Test names — minimal source strings for funcref + string-intern
  (data (i32.const 3816) "\05\00\00\00alpha")
  (data (i32.const 3828) "\04\00\00\00beta")
  (data (i32.const 3836) "\05\00\00\00gamma")
  (data (i32.const 3848) "\05\00\00\00delta")
  (data (i32.const 3860) "\05\00\00\00hello")
  (data (i32.const 3872) "\05\00\00\00world")
  (data (i32.const 3884) "\07\00\00\00missing")

  ;; ─── _start ──────────────────────────────────────────────────────
  (func $_start (export "_start")
    (local $failed i32)
    (local $idx_alpha i32) (local $idx_beta i32) (local $idx_gamma i32)
    (local $idx_dedup i32) (local $count_after_dedup i32)
    (local $lookup_miss i32) (local $lookup_alpha i32)
    (local $ev_list i32)
    (local $offset_hello i32) (local $offset_hello_dedup i32)
    (local $offset_world i32) (local $expected_world_offset i32)
    (local $entry_zero i32) (local $entry_str i32)
    (local.set $failed (i32.const 0))
    (call $emit_init)

    ;; ── Phase 1: $emit_funcref_register("alpha") returns 0 ──
    (local.set $idx_alpha
      (call $emit_funcref_register (i32.const 3816)))
    (if (i32.ne (local.get $idx_alpha) (i32.const 0))
      (then
        (call $eprint_string (i32.const 3144))
        (call $eprint_string (i32.const 3104))
        (local.set $failed (i32.const 1))))

    ;; ── Phase 2: $emit_funcref_count == 1 after one register ──
    (if (i32.ne (call $emit_funcref_count) (i32.const 1))
      (then
        (call $eprint_string (i32.const 3176))
        (call $eprint_string (i32.const 3104))
        (local.set $failed (i32.const 1))))

    ;; ── Phase 3: $emit_funcref_at(0) round-trips str_ptr "alpha" ──
    (if (i32.eqz
          (call $str_eq (call $emit_funcref_at (i32.const 0))
                        (i32.const 3816)))
      (then
        (call $eprint_string (i32.const 3208))
        (call $eprint_string (i32.const 3104))
        (local.set $failed (i32.const 1))))

    ;; ── Phase 4: dedup — register("alpha") again returns 0, count UNCHANGED ──
    (local.set $idx_dedup
      (call $emit_funcref_register (i32.const 3816)))
    (if (i32.ne (local.get $idx_dedup) (i32.const 0))
      (then
        (call $eprint_string (i32.const 3240))
        (call $eprint_string (i32.const 3104))
        (local.set $failed (i32.const 1))))

    (local.set $count_after_dedup (call $emit_funcref_count))
    (if (i32.ne (local.get $count_after_dedup) (i32.const 1))
      (then
        (call $eprint_string (i32.const 3272))
        (call $eprint_string (i32.const 3104))
        (local.set $failed (i32.const 1))))

    ;; ── Phase 5: register("beta") → 1, register("gamma") → 2, count → 3 ──
    (local.set $idx_beta
      (call $emit_funcref_register (i32.const 3828)))
    (if (i32.ne (local.get $idx_beta) (i32.const 1))
      (then
        (call $eprint_string (i32.const 3304))
        (call $eprint_string (i32.const 3104))
        (local.set $failed (i32.const 1))))

    (local.set $idx_gamma
      (call $emit_funcref_register (i32.const 3836)))
    (if (i32.ne (local.get $idx_gamma) (i32.const 2))
      (then
        (call $eprint_string (i32.const 3336))
        (call $eprint_string (i32.const 3104))
        (local.set $failed (i32.const 1))))

    (if (i32.ne (call $emit_funcref_count) (i32.const 3))
      (then
        (call $eprint_string (i32.const 3368))
        (call $eprint_string (i32.const 3104))
        (local.set $failed (i32.const 1))))

    ;; ── Phase 6: $emit_funcref_lookup("delta") miss returns -1 ──
    (local.set $lookup_miss
      (call $emit_funcref_lookup (i32.const 3848)))
    (if (i32.ne (local.get $lookup_miss) (i32.const -1))
      (then
        (call $eprint_string (i32.const 3400))
        (call $eprint_string (i32.const 3104))
        (local.set $failed (i32.const 1))))

    ;; ── Phase 7: body-context set + read + reset; funcref unchanged ──
    ;; Build a synthetic 2-element evidence list: [42, 17]. These are
    ;; raw fn_idx ints per chunk-header line 134-137; not graph handles.
    (local.set $ev_list (call $make_list (i32.const 8)))
    (local.set $ev_list
      (call $list_extend_to (local.get $ev_list) (i32.const 2)))
    (drop (call $list_set (local.get $ev_list) (i32.const 0) (i32.const 42)))
    (drop (call $list_set (local.get $ev_list) (i32.const 1) (i32.const 17)))

    (call $emit_set_body_context (i32.const 2)
                                  (local.get $ev_list)
                                  (i32.const 2))

    (if (i32.ne (call $emit_body_captures_count) (i32.const 2))
      (then
        (call $eprint_string (i32.const 3432))
        (call $eprint_string (i32.const 3104))
        (local.set $failed (i32.const 1))))

    (if (i32.ne (call $emit_body_evidence_len) (i32.const 2))
      (then
        (call $eprint_string (i32.const 3464))
        (call $eprint_string (i32.const 3104))
        (local.set $failed (i32.const 1))))

    ;; $emit_fn_reset clears body-context BUT NOT funcref-table per
    ;; state.wat:362-364 length-only-reset discipline.
    (call $emit_fn_reset)

    (if (i32.ne (call $emit_body_captures_count) (i32.const 0))
      (then
        (call $eprint_string (i32.const 3496))
        (call $eprint_string (i32.const 3104))
        (local.set $failed (i32.const 1))))

    (if (i32.ne (call $emit_body_evidence_len) (i32.const 0))
      (then
        (call $eprint_string (i32.const 3528))
        (call $eprint_string (i32.const 3104))
        (local.set $failed (i32.const 1))))

    ;; Funcref-table count UNCHANGED by $emit_fn_reset (program-wide).
    (if (i32.ne (call $emit_funcref_count) (i32.const 3))
      (then
        (call $eprint_string (i32.const 3560))
        (call $eprint_string (i32.const 3104))
        (local.set $failed (i32.const 1))))

    ;; ── Phase 8: $emit_string_intern("hello") returns initial offset 65536 ──
    (local.set $offset_hello
      (call $emit_string_intern (i32.const 3860)))
    (if (i32.ne (local.get $offset_hello) (i32.const 65536))
      (then
        (call $eprint_string (i32.const 3592))
        (call $eprint_string (i32.const 3104))
        (local.set $failed (i32.const 1))))

    (if (i32.ne (call $emit_string_table_count) (i32.const 1))
      (then
        (call $eprint_string (i32.const 3624))
        (call $eprint_string (i32.const 3104))
        (local.set $failed (i32.const 1))))

    ;; ── Phase 9: dedup — intern("hello") again returns same offset ──
    (local.set $offset_hello_dedup
      (call $emit_string_intern (i32.const 3860)))
    (if (i32.ne (local.get $offset_hello_dedup) (local.get $offset_hello))
      (then
        (call $eprint_string (i32.const 3656))
        (call $eprint_string (i32.const 3104))
        (local.set $failed (i32.const 1))))

    ;; ── Phase 10: intern("world") returns 65536 + aligned(4 + 5) = 65548 ──
    ;; aligned_size = (size + 3) / 4 * 4 per state.wat:317-320.
    ;; size = 4 + str_len("hello") = 4 + 5 = 9; aligned = (9+3)/4*4 = 12.
    ;; world's offset = 65536 + 12 = 65548.
    (local.set $expected_world_offset (i32.const 65548))
    (local.set $offset_world
      (call $emit_string_intern (i32.const 3872)))
    (if (i32.ne (local.get $offset_world) (local.get $expected_world_offset))
      (then
        (call $eprint_string (i32.const 3688))
        (call $eprint_string (i32.const 3104))
        (local.set $failed (i32.const 1))))

    (if (i32.ne (call $emit_string_table_count) (i32.const 2))
      (then
        (call $eprint_string (i32.const 3720))
        (call $eprint_string (i32.const 3104))
        (local.set $failed (i32.const 1))))

    ;; ── Phase 11: $emit_string_lookup("missing") miss returns -1 ──
    (if (i32.ne (call $emit_string_lookup (i32.const 3884)) (i32.const -1))
      (then
        (call $eprint_string (i32.const 3752))
        (call $eprint_string (i32.const 3104))
        (local.set $failed (i32.const 1))))

    ;; ── Phase 12: $emit_string_table_at(0) round-trips STRING_INTERN_ENTRY ──
    ;; record_get(entry, 0) is str_ptr — must equal "hello" str_ptr.
    (local.set $entry_zero (call $emit_string_table_at (i32.const 0)))
    (local.set $entry_str
      (call $record_get (local.get $entry_zero) (i32.const 0)))
    (if (i32.eqz (call $str_eq (local.get $entry_str) (i32.const 3860)))
      (then
        (call $eprint_string (i32.const 3784))
        (call $eprint_string (i32.const 3104))
        (local.set $failed (i32.const 1))))

    ;; ── Verdict ──
    (if (local.get $failed)
      (then
        (call $eprint_string (i32.const 3084))   ;; "FAIL:"
        (call $eprint_string (i32.const 3096))   ;; " "
        (call $eprint_string (i32.const 3120))   ;; "emit_state_init"
        (call $eprint_string (i32.const 3104))   ;; "\n"
        (call $wasi_proc_exit (i32.const 1)))
      (else
        (call $eprint_string (i32.const 3072))   ;; "PASS:"
        (call $eprint_string (i32.const 3096))   ;; " "
        (call $eprint_string (i32.const 3120))   ;; "emit_state_init"
        (call $eprint_string (i32.const 3104))   ;; "\n"
        (call $wasi_proc_exit (i32.const 0)))))
