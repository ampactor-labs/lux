  ;; ═══ walk_expr_lit_int.wat — trace harness ════════════════════════
  ;; Executes: Hβ-infer-substrate.md §4.3 production pattern 1 — LitInt arm.
  ;; Per src/infer.mn:493 — graph_bind(handle, TInt, Located(span,
  ;;                                                Inferred("int literal"))).
  ;; Verifies: synthetic LitInt N node walked → graph_chase(handle).kind = NBOUND
  ;;           NBound payload Ty tag = 100 (TInt).
  ;;           Productive-under-error NOT triggered (no NErrorHole / tag 64).
  ;; Exercises: walk_expr.wat — $infer_walk_expr, $infer_walk_expr_lit_int,
  ;;            $graph_bind (via the arm), $ty_make_tint.
  ;; Per ROADMAP §5 + Hβ-infer-substrate.md §11.
  ;;
  ;; ─── Eight interrogations ─────────────────────────────────────────
  ;;   Graph?      One $graph_bind on the AST handle (TInt + Located reason).
  ;;   Handler?    Direct seed call.
  ;;   Verb?       N/A (literal arm has no verb topology).
  ;;   Row?        None at the seed (lit literals add no Pure offset).
  ;;   Ownership?  None (LitInt has no owned name to consume).
  ;;   Refinement? None.
  ;;   Gradient?   Handle moves NFree → NBound on TInt — the canonical
  ;;               structural-constraint gradient step.
  ;;   Reason?     Located(span, Inferred("int literal")) — Why Engine
  ;;               walks back to the literal site.

  ;; Verdict labels (above 4096 ceiling per harness convention).
  (data (i32.const 4096) "\05\00\00\00PASS:")
  (data (i32.const 4128) "\05\00\00\00FAIL:")
  (data (i32.const 4160) "\01\00\00\00 ")
  (data (i32.const 4192) "\01\00\00\00\0a")
  (data (i32.const 4224) "\14\00\00\00walk_expr_lit_int   ")

  ;; Per-assertion FAIL labels (20 bytes each, 32-byte-stride slots).
  (data (i32.const 4256) "\14\00\00\00not-nbound          ")
  (data (i32.const 4288) "\14\00\00\00not-tint            ")
  (data (i32.const 4320) "\14\00\00\00bound-errhole       ")

  (func $_start (export "_start")
    (local $h i32) (local $node i32) (local $expr i32) (local $body i32)
    (local $span i32) (local $g i32) (local $kind i32) (local $payload i32)
    (local $failed i32)
    (local.set $failed (i32.const 0))
    (call $graph_init)
    (call $env_init)
    (call $infer_init)

    ;; ── Build synthetic AST: LitInt(42) at fresh handle ──
    ;; Span(line=1, col=1, line=1, col=3) — 4 i32 fields × 4 bytes = 16
    (local.set $span (call $alloc (i32.const 16)))
    (i32.store          (local.get $span) (i32.const 1))
    (i32.store offset=4 (local.get $span) (i32.const 1))
    (i32.store offset=8 (local.get $span) (i32.const 1))
    (i32.store offset=12 (local.get $span) (i32.const 3))

    ;; LitInt(42): [tag=80][n=42] — 8 bytes
    (local.set $expr (call $alloc (i32.const 8)))
    (i32.store          (local.get $expr) (i32.const 80))
    (i32.store offset=4 (local.get $expr) (i32.const 42))

    ;; NExpr wrap: [tag=110][expr]
    (local.set $body (call $alloc (i32.const 8)))
    (i32.store          (local.get $body) (i32.const 110))
    (i32.store offset=4 (local.get $body) (local.get $expr))

    ;; N(body, span, handle) — fresh handle from graph
    (local.set $h (call $graph_fresh_ty (i32.const 0)))
    (local.set $node (call $alloc (i32.const 16)))
    (i32.store          (local.get $node) (i32.const 0))
    (i32.store offset=4 (local.get $node) (local.get $body))
    (i32.store offset=8 (local.get $node) (local.get $span))
    (i32.store offset=12 (local.get $node) (local.get $h))

    ;; ── Walk ──
    (drop (call $infer_walk_expr (local.get $node)))

    ;; ── Assert: graph_chase(h).kind tag = 60 (NBOUND) ──
    (local.set $g    (call $graph_node_at (local.get $h)))
    (local.set $kind (call $gnode_kind (local.get $g)))
    (if (i32.ne (call $node_kind_tag (local.get $kind)) (i32.const 60))
      (then
        (call $eprint_string (i32.const 4256))
        (call $eprint_string (i32.const 4192))
        (local.set $failed (i32.const 1))))

    ;; ── Assert: payload Ty tag = 100 (TInt) ──
    (local.set $payload (call $node_kind_payload (local.get $kind)))
    (if (i32.ne (call $ty_tag (local.get $payload)) (i32.const 100))
      (then
        (call $eprint_string (i32.const 4288))
        (call $eprint_string (i32.const 4192))
        (local.set $failed (i32.const 1))))

    ;; ── Assert NOT NErrorHole (tag 64) ──
    (if (i32.eq (call $node_kind_tag (local.get $kind)) (i32.const 64))
      (then
        (call $eprint_string (i32.const 4320))
        (call $eprint_string (i32.const 4192))
        (local.set $failed (i32.const 1))))

    ;; ── Verdict ──
    (if (local.get $failed)
      (then
        (call $eprint_string (i32.const 4128))
        (call $eprint_string (i32.const 4160))
        (call $eprint_string (i32.const 4224)))
      (else
        (call $eprint_string (i32.const 4096))
        (call $eprint_string (i32.const 4160))
        (call $eprint_string (i32.const 4224))))
    (call $eprint_string (i32.const 4192))
    (call $wasi_proc_exit (i32.const 0)))
