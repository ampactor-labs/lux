  ;; ═══ arena_smoke.wat — Hβ.arena Tier 0 trace harness ═══════════════
  ;; Substrate acceptance per Hβ-arena-substrate.md §1.2 (three
  ;; allocators) + §1.3 (reset primitives) + §4 (ownership-transfer
  ;; via $perm_promote) + Anchor 0/5 (caller-determined explicit
  ;; arena per site; no ambient dispatch).
  ;;
  ;; Smoke-tests the arena substrate independently of the cascade
  ;; pipeline. Each phase exercises one explicit entry point:
  ;;
  ;;   Phase 1 — $alloc (perm-alias):
  ;;     pointer falls in [1 MiB, 16 MiB) — perm region.
  ;;   Phase 2 — $stage_alloc:
  ;;     pointer falls in [16 MiB, 28 MiB) — stage-arena region.
  ;;   Phase 3 — $stage_reset:
  ;;     stage_arena_ptr rewound; next $stage_alloc returns the same
  ;;     pointer as the first stage_alloc post-reset.
  ;;   Phase 4 — $fn_alloc:
  ;;     pointer falls in [28 MiB, 32 MiB) — fn-arena region.
  ;;   Phase 5 — $fn_reset:
  ;;     fn_arena_ptr rewound; next $fn_alloc returns the same pointer
  ;;     as the first fn_alloc post-reset.
  ;;   Phase 6 — $perm_promote (ownership-transfer):
  ;;     allocate a 16-byte record in stage-arena, write a sentinel
  ;;     pattern; $perm_promote returns a perm-region pointer; verify
  ;;     the bytes were copied byte-for-byte AND the new pointer is
  ;;     in [1 MiB, 16 MiB).
  ;;
  ;; Per drift-mode-9 closure: every export of arena.wat is exercised
  ;; by at least one phase ($perm_alloc-via-$alloc / $stage_alloc /
  ;; $fn_alloc / $stage_reset / $fn_reset / $perm_promote).

  (data (i32.const 3072) "\05\00\00\00PASS:")
  (data (i32.const 3084) "\05\00\00\00FAIL:")
  (data (i32.const 3096) "\01\00\00\00 ")
  (data (i32.const 3104) "\01\00\00\00\0a")
  (data (i32.const 3120) "\0b\00\00\00arena_smoke")

  (data (i32.const 3168) "\1a\00\00\00phase1-perm-range-bad     ")
  (data (i32.const 3200) "\1a\00\00\00phase2-stage-range-bad    ")
  (data (i32.const 3232) "\1a\00\00\00phase3-stage-reset-bad    ")
  (data (i32.const 3264) "\1a\00\00\00phase4-fn-range-bad       ")
  (data (i32.const 3296) "\1a\00\00\00phase5-fn-reset-bad       ")
  (data (i32.const 3328) "\1a\00\00\00phase6-promote-range-bad  ")
  (data (i32.const 3360) "\1a\00\00\00phase6-promote-bytes-bad  ")

  (func $_start (export "_start")
    (local $failed i32)
    (local $p1 i32) (local $p2a i32) (local $p2b i32) (local $p3 i32)
    (local $p4a i32) (local $p4b i32) (local $p5 i32)
    (local $stage_src i32) (local $perm_dst i32)
    (local.set $failed (i32.const 0))

    ;; ─── Phase 1: $alloc (= $perm_alloc) returns a perm-region ptr ──
    ;; Range constants track arena.wat's partition (2 GiB layout):
    ;;   perm  [1 MiB, 1537 MiB) = [1048576, 1611137024)
    ;;   stage [1537 MiB, 1921 MiB) = [1611137024, 2014314496)
    ;;   fn    [1921 MiB, 2048 MiB) = [2014314496, 2147483648)
    (local.set $p1 (call $alloc (i32.const 16)))
    (if (i32.or
          (i32.lt_u (local.get $p1) (i32.const 1048576))
          (i32.ge_u (local.get $p1) (i32.const 1611137024)))
      (then (call $eprint_string (i32.const 3168))
            (call $eprint_string (i32.const 3104))
            (local.set $failed (i32.const 1))))

    ;; ─── Phase 2: $stage_alloc returns a stage-region ptr ───────────
    (local.set $p2a (call $stage_alloc (i32.const 32)))
    (if (i32.or
          (i32.lt_u (local.get $p2a) (i32.const 1611137024))
          (i32.ge_u (local.get $p2a) (i32.const 2014314496)))
      (then (call $eprint_string (i32.const 3200))
            (call $eprint_string (i32.const 3104))
            (local.set $failed (i32.const 1))))
    ;; Advance the stage pointer; will compare against $p3 below.
    (local.set $p2b (call $stage_alloc (i32.const 32)))

    ;; ─── Phase 3: $stage_reset rewinds stage_arena_ptr ─────────────
    (call $stage_reset)
    (local.set $p3 (call $stage_alloc (i32.const 32)))
    (if (i32.ne (local.get $p3) (local.get $p2a))
      (then (call $eprint_string (i32.const 3232))
            (call $eprint_string (i32.const 3104))
            (local.set $failed (i32.const 1))))

    ;; ─── Phase 4: $fn_alloc returns a fn-region ptr ────────────────
    (local.set $p4a (call $fn_alloc (i32.const 64)))
    (if (i32.or
          (i32.lt_u (local.get $p4a) (i32.const 2014314496))
          (i32.ge_u (local.get $p4a) (i32.const 2147483648)))
      (then (call $eprint_string (i32.const 3264))
            (call $eprint_string (i32.const 3104))
            (local.set $failed (i32.const 1))))
    (local.set $p4b (call $fn_alloc (i32.const 64)))

    ;; ─── Phase 5: $fn_reset rewinds fn_arena_ptr ──────────────────
    (call $fn_reset)
    (local.set $p5 (call $fn_alloc (i32.const 64)))
    (if (i32.ne (local.get $p5) (local.get $p4a))
      (then (call $eprint_string (i32.const 3296))
            (call $eprint_string (i32.const 3104))
            (local.set $failed (i32.const 1))))

    ;; ─── Phase 6: $perm_promote ownership-transfer ────────────────
    ;; Allocate 16 bytes in stage-arena and write a sentinel pattern.
    (local.set $stage_src (call $stage_alloc (i32.const 16)))
    (i32.store8 (local.get $stage_src) (i32.const 0xDE))
    (i32.store8 (i32.add (local.get $stage_src) (i32.const 1)) (i32.const 0xAD))
    (i32.store8 (i32.add (local.get $stage_src) (i32.const 2)) (i32.const 0xBE))
    (i32.store8 (i32.add (local.get $stage_src) (i32.const 3)) (i32.const 0xEF))

    ;; Promote the 16-byte record to perm.
    (local.set $perm_dst (call $perm_promote (local.get $stage_src) (i32.const 16)))

    ;; Expect $perm_dst in [1 MiB, 1537 MiB) — perm region.
    (if (i32.or
          (i32.lt_u (local.get $perm_dst) (i32.const 1048576))
          (i32.ge_u (local.get $perm_dst) (i32.const 1611137024)))
      (then (call $eprint_string (i32.const 3328))
            (call $eprint_string (i32.const 3104))
            (local.set $failed (i32.const 1))))

    ;; Verify the bytes were copied correctly.
    (if (i32.or
          (i32.or
            (i32.ne (i32.load8_u (local.get $perm_dst)) (i32.const 0xDE))
            (i32.ne (i32.load8_u (i32.add (local.get $perm_dst) (i32.const 1)))
                    (i32.const 0xAD)))
          (i32.or
            (i32.ne (i32.load8_u (i32.add (local.get $perm_dst) (i32.const 2)))
                    (i32.const 0xBE))
            (i32.ne (i32.load8_u (i32.add (local.get $perm_dst) (i32.const 3)))
                    (i32.const 0xEF))))
      (then (call $eprint_string (i32.const 3360))
            (call $eprint_string (i32.const 3104))
            (local.set $failed (i32.const 1))))

    ;; ─── Verdict ──────────────────────────────────────────────────
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
