  ;; ═══ unify_ground_match.wat — trace-harness ═══════════════════════
  ;; Executes: Hβ-infer-substrate.md §3 + §11 acceptance — TInt × TInt
  ;;           ground-match success path. $unify on two NBound(TInt)
  ;;           handles is a no-op in the canonical algorithm
  ;;           (src/infer.mn:1051 + 1062 + 1190 + 1183) — both handles
  ;;           remain NBound(TInt); $expect_same's $same_ground arm
  ;;           returns 1 and falls through to ().
  ;; Exercises: unify.wat — $unify $unify_types $expect_same $same_ground
  ;; Per ROADMAP §5 + Hβ-infer-substrate.md §11 acceptance.
  ;;
  ;; ─── Eight interrogations (per Hβ-infer §6.2 second pass) ─────────
  ;;   Graph?      Mints two fresh handles + binds both to TInt; $unify
  ;;               chases them, observes (NBound, NBound), recurses to
  ;;               $unify_types(TInt, TInt) which $expect_same → ground-
  ;;               equal → no mutation. Final state: both handles still
  ;;               NBound(TInt).
  ;;   Handler?    Direct seed call ($unify dispatches on tag).
  ;;   Verb?       N/A.
  ;;   Row?        Pure — no row touched.
  ;;   Ownership?  Both handles ref through the harness.
  ;;   Refinement? None — TInt is unrefined.
  ;;   Gradient?   Identity gradient — successful $expect_same is the
  ;;               "no narrowing needed" baseline.
  ;;   Reason?     reason ptr 0 — harness uses no Reason chain.

  ;; ─── Harness-private data segment (offsets 3500+ to avoid unify.wat
  ;; data at 3008-3120 + Layer 0 globals reserved space) ──────────────
  (data (i32.const 3500) "\05\00\00\00PASS:")
  (data (i32.const 3512) "\05\00\00\00FAIL:")
  (data (i32.const 3524) "\01\00\00\00 ")
  (data (i32.const 3532) "\01\00\00\00\0a")

  ;; Harness display name — 20 bytes
  (data (i32.const 3552) "\14\00\00\00unify_ground_match  ")

  ;; Per-assertion FAIL labels — 20 bytes each
  (data (i32.const 3584) "\14\00\00\00h_a-not-nbound      ")
  (data (i32.const 3616) "\14\00\00\00h_a-payload-not-tint")
  (data (i32.const 3648) "\14\00\00\00h_b-not-nbound      ")
  (data (i32.const 3680) "\14\00\00\00h_b-payload-not-tint")

  (func $_start (export "_start")
    (local $failed i32)
    (local $h_a i32) (local $h_b i32)
    (local $g i32) (local $nk i32) (local $payload i32)
    (local.set $failed (i32.const 0))
    (call $graph_init)

    ;; ── Setup: mint two fresh handles, bind both to TInt ──
    (local.set $h_a (call $graph_fresh_ty (i32.const 0)))
    (local.set $h_b (call $graph_fresh_ty (i32.const 0)))
    (call $graph_bind (local.get $h_a) (call $ty_make_tint) (i32.const 0))
    (call $graph_bind (local.get $h_b) (call $ty_make_tint) (i32.const 0))

    ;; ── Exercise: $unify on two NBound(TInt) handles ──
    (call $unify (local.get $h_a) (local.get $h_b) (i32.const 0) (i32.const 0))

    ;; ── Assert h_a remains NBound(TInt) ──
    (local.set $g (call $graph_node_at (local.get $h_a)))
    (local.set $nk (call $gnode_kind (local.get $g)))
    (if (i32.ne (call $node_kind_tag (local.get $nk)) (i32.const 60))
      (then
        (call $eprint_string (i32.const 3584))
        (call $eprint_string (i32.const 3532))
        (local.set $failed (i32.const 1))))
    (local.set $payload (call $node_kind_payload (local.get $nk)))
    (if (i32.ne (call $ty_tag (local.get $payload)) (i32.const 100))
      (then
        (call $eprint_string (i32.const 3616))
        (call $eprint_string (i32.const 3532))
        (local.set $failed (i32.const 1))))

    ;; ── Assert h_b remains NBound(TInt) ──
    (local.set $g (call $graph_node_at (local.get $h_b)))
    (local.set $nk (call $gnode_kind (local.get $g)))
    (if (i32.ne (call $node_kind_tag (local.get $nk)) (i32.const 60))
      (then
        (call $eprint_string (i32.const 3648))
        (call $eprint_string (i32.const 3532))
        (local.set $failed (i32.const 1))))
    (local.set $payload (call $node_kind_payload (local.get $nk)))
    (if (i32.ne (call $ty_tag (local.get $payload)) (i32.const 100))
      (then
        (call $eprint_string (i32.const 3680))
        (call $eprint_string (i32.const 3532))
        (local.set $failed (i32.const 1))))

    ;; ── Verdict ──
    (if (local.get $failed)
      (then
        (call $eprint_string (i32.const 3512))
        (call $eprint_string (i32.const 3524))
        (call $eprint_string (i32.const 3552)))
      (else
        (call $eprint_string (i32.const 3500))
        (call $eprint_string (i32.const 3524))
        (call $eprint_string (i32.const 3552))))
    (call $eprint_string (i32.const 3532))
    (call $wasi_proc_exit (i32.const 0)))
