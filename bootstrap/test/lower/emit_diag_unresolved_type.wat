  ;; ═══ emit_diag_unresolved_type.wat — Hβ.lower trace-harness ════════
  ;; Executes: Hβ-lower-substrate.md §1.1 lines 165-172 + §11 — emit_diag.wat
  ;;           $lower_emit_unresolved_type writes to stderr without trapping
  ;;           (caller-side proc_exit + unreachable; helper is emit-only).
  ;; Exercises: emit_diag.wat — $lower_emit_unresolved_type.
  ;; Per Hβ-lower-substrate.md §10.1 + §10.4 acceptance + the chunk #4
  ;; harness convention (PASS = exit 0; emit-only path verified by
  ;; harness completing without trap).
  ;;
  ;; Eight interrogations:
  ;;   Graph?      $graph_init initializes graph state; the helper
  ;;               doesn't chase (handle integer is the only payload).
  ;;   Handler?    Direct call to $lower_emit_unresolved_type (seed
  ;;               Tier-6 emit-only projection of LookupTy's NFree arm
  ;;               default handler at the wheel).
  ;;   Verb?       N/A — sequential.
  ;;   Row?        Seed: Diagnostic only; harness ignores row gating.
  ;;   Ownership?  Message string `own` of bump allocator; harness
  ;;               verifies emit completes without trap (exit 0).
  ;;   Refinement? None.
  ;;   Gradient?   This harness IS the proof that the closed Drift 9
  ;;               (Hβ.lower.unresolved-emit-retrofit) emits a legible
  ;;               diagnostic before lookup.wat's caller-side trap.
  ;;   Reason?     Harness uses an arbitrary handle (42); the GNode's
  ;;               Reason chain is irrelevant for the seed's
  ;;               handle-integer-only message form.

  (data (i32.const 3072) "\05\00\00\00PASS:")
  (data (i32.const 3084) "\05\00\00\00FAIL:")
  (data (i32.const 3096) "\01\00\00\00 ")
  (data (i32.const 3104) "\01\00\00\00\0a")
  (data (i32.const 3120) "\1c\00\00\00lower_emit_unresolved_type ")

  (func $_start (export "_start")
    (call $graph_init)

    ;; Phase 1: Invoke $lower_emit_unresolved_type with an arbitrary
    ;; handle. Helper writes "E_UnresolvedType: lower-time NFree at
    ;; handle 42\n" to stderr and returns. The harness asserts the
    ;; helper RETURNED (didn't trap) — emit-only verification.
    (call $lower_emit_unresolved_type (i32.const 42))

    ;; Phase 2: PASS verdict. Exit 0.
    (call $eprint_string (i32.const 3072))
    (call $eprint_string (i32.const 3096))
    (call $eprint_string (i32.const 3120))
    (call $eprint_string (i32.const 3104))
    (call $wasi_proc_exit (i32.const 0)))
