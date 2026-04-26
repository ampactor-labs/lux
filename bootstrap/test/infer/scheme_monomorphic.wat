  ;; ═══ scheme_monomorphic.wat — trace-harness ═══════════════════════
  ;; Executes: Hβ-infer-substrate.md §2.4 empty-quantification short-
  ;;           circuit + §11.2 #2 "Forall([], _) for monomorphic binding"
  ;; Exercises: scheme.wat — $generalize $instantiate $scheme_make_forall
  ;;            $scheme_quantified $scheme_body $is_scheme
  ;; Per ROADMAP §5 + Hβ-infer-substrate.md §11.
  ;;
  ;; ─── Eight interrogations (per Hβ-infer §6.1 second pass) ─────────
  ;;   Graph?      Mints one fresh ty handle via $graph_fresh_ty +
  ;;               binds it to TInt via $graph_bind. $generalize chases
  ;;               that handle and observes NBound(TInt) → empty Forall.
  ;;   Handler?    Direct call to $generalize / $instantiate (seed Tier-5
  ;;               base; @resume=OneShot per FreshHandle effect).
  ;;   Verb?       N/A at substrate level.
  ;;   Row?        Pure — no row touched.
  ;;   Ownership?  All values ref through the harness; no consume.
  ;;   Refinement? None — TInt is unrefined.
  ;;   Gradient?   This harness IS one pixel of §11.2 acceptance #2 —
  ;;               proves Forall([], TInt) shape lands correctly.
  ;;   Reason?     The fresh-handle Reason is reason ptr 0 (no chain at
  ;;               this layer). $generalize does NOT add a top-level
  ;;               Reason per scheme.wat:242-249.

  ;; ─── Harness-private data segment (offsets ≥ 3072, < HEAP_BASE) ──

  (data (i32.const 3072) "\05\00\00\00PASS:")
  (data (i32.const 3084) "\05\00\00\00FAIL:")
  (data (i32.const 3096) "\01\00\00\00 ")
  (data (i32.const 3104) "\01\00\00\00\0a")

  ;; Harness display name — offset 3120
  (data (i32.const 3120) "\14\00\00\00scheme_monomorphic  ")

  ;; Per-assertion FAIL labels — offsets 3144+
  (data (i32.const 3144) "\1b\00\00\00quantified-not-empty       ")
  (data (i32.const 3176) "\10\00\00\00body-not-tint   ")
  (data (i32.const 3200) "\0a\00\00\00not-scheme")
  (data (i32.const 3216) "\1c\00\00\00instantiate-not-identity    ")

  ;; ─── _start ──────────────────────────────────────────────────────
  (func $_start (export "_start")
    (local $failed i32)
    (local $tint i32) (local $h i32) (local $scheme i32) (local $inst i32)
    (local.set $failed (i32.const 0))
    (call $graph_init)

    ;; ── Body: monomorphic Forall([], TInt) ──
    (local.set $tint (call $ty_make_tint))
    (local.set $h (call $graph_fresh_ty (i32.const 0)))
    (call $graph_bind (local.get $h) (local.get $tint) (i32.const 0))
    (local.set $scheme (call $generalize (local.get $h)))

    ;; Assert quantified list is empty
    (if (i32.ne (call $len (call $scheme_quantified (local.get $scheme))) (i32.const 0))
      (then
        (call $eprint_string (i32.const 3144))
        (call $eprint_string (i32.const 3104))
        (local.set $failed (i32.const 1))))

    ;; Assert body is TInt verbatim
    (if (i32.ne (call $scheme_body (local.get $scheme)) (local.get $tint))
      (then
        (call $eprint_string (i32.const 3176))
        (call $eprint_string (i32.const 3104))
        (local.set $failed (i32.const 1))))

    ;; Assert $is_scheme recognises it
    (if (i32.eqz (call $is_scheme (local.get $scheme)))
      (then
        (call $eprint_string (i32.const 3200))
        (call $eprint_string (i32.const 3104))
        (local.set $failed (i32.const 1))))

    ;; Empty-quantification short-circuit: $instantiate returns body identity
    (local.set $inst (call $instantiate (local.get $scheme)))
    (if (i32.ne (local.get $inst) (local.get $tint))
      (then
        (call $eprint_string (i32.const 3216))
        (call $eprint_string (i32.const 3104))
        (local.set $failed (i32.const 1))))

    ;; ── Verdict ──
    (if (local.get $failed)
      (then
        (call $eprint_string (i32.const 3084))
        (call $eprint_string (i32.const 3096))
        (call $eprint_string (i32.const 3120)))
      (else
        (call $eprint_string (i32.const 3072))
        (call $eprint_string (i32.const 3096))
        (call $eprint_string (i32.const 3120))))
    (call $eprint_string (i32.const 3104))
    (call $wasi_proc_exit (i32.const 0)))
