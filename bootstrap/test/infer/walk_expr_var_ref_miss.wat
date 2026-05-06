  ;; ═══ walk_expr_var_ref_miss.wat — trace harness ═══════════════════
  ;; Executes: Hβ-infer-substrate.md §4.3 production pattern 4 +
  ;;           Hazel productive-under-error pattern.
  ;; Per src/infer.mn:790 — VarRef on env-miss emits E_MissingVariable +
  ;;                        binds NErrorHole + caller continues. Seed
  ;;                        projection: $infer_emit_missing_var routes
  ;;                        $graph_bind_kind(handle, NErrorHole(reason)).
  ;; Verifies: synthetic VarRef("undefined") walked → graph_chase(h).kind
  ;;           tag = 64 (NErrorHole), NOT 60 (NBOUND).
  ;; Exercises: walk_expr.wat — $infer_walk_expr_var_ref;
  ;;            env.wat — $env_lookup (returns 0 on miss);
  ;;            emit_diag.wat — $infer_emit_missing_var.
  ;;
  ;; ─── Eight interrogations ─────────────────────────────────────────
  ;;   Graph?      One $graph_bind_kind on AST handle (NErrorHole).
  ;;   Handler?    Direct seed call.
  ;;   Verb?       N/A.
  ;;   Row?        None at seed.
  ;;   Ownership?  No consume (env-miss path skips check_consume_at_use).
  ;;   Refinement? None.
  ;;   Gradient?   Handle moves NFree → NBound(NErrorHole) — productive-
  ;;               under-error gradient step (Hazel pattern).
  ;;   Reason?     MissingVar via emit_diag's reason composition.

  (data (i32.const 4096) "\05\00\00\00PASS:")
  (data (i32.const 4128) "\05\00\00\00FAIL:")
  (data (i32.const 4160) "\01\00\00\00 ")
  (data (i32.const 4192) "\01\00\00\00\0a")
  (data (i32.const 4224) "\16\00\00\00walk_expr_var_ref_miss")

  (data (i32.const 4256) "\14\00\00\00not-errhole         ")
  (data (i32.const 4288) "\14\00\00\00bound-not-errhole   ")

  ;; Static argument string — the unresolved name "undefined"
  (data (i32.const 4928) "\09\00\00\00undefined")

  (func $_start (export "_start")
    (local $h i32) (local $node i32) (local $expr i32) (local $body i32)
    (local $span i32) (local $g i32) (local $kind i32)
    (local $failed i32)
    (local.set $failed (i32.const 0))
    (call $graph_init)
    (call $env_init)
    (call $infer_init)
    ;; Ensure env has a scope (env_lookup over empty scope returns 0; an
    ;; empty enter / exit pair leaves no bindings — which is what we want).
    (call $env_scope_enter)

    ;; ── Build synthetic AST: VarRef("undefined") ──
    (local.set $span (call $alloc (i32.const 16)))
    (i32.store          (local.get $span) (i32.const 2))
    (i32.store offset=4 (local.get $span) (i32.const 1))
    (i32.store offset=8 (local.get $span) (i32.const 2))
    (i32.store offset=12 (local.get $span) (i32.const 10))

    ;; VarRef("undefined"): [tag=85][name_ptr] — 8 bytes
    (local.set $expr (call $alloc (i32.const 8)))
    (i32.store          (local.get $expr) (i32.const 85))
    (i32.store offset=4 (local.get $expr) (i32.const 4928))

    ;; NExpr wrap
    (local.set $body (call $alloc (i32.const 8)))
    (i32.store          (local.get $body) (i32.const 110))
    (i32.store offset=4 (local.get $body) (local.get $expr))

    ;; N(body, span, h)
    (local.set $h (call $graph_fresh_ty (i32.const 0)))
    (local.set $node (call $alloc (i32.const 16)))
    (i32.store          (local.get $node) (i32.const 0))
    (i32.store offset=4 (local.get $node) (local.get $body))
    (i32.store offset=8 (local.get $node) (local.get $span))
    (i32.store offset=12 (local.get $node) (local.get $h))

    ;; ── Walk ──
    (drop (call $infer_walk_expr (local.get $node)))

    ;; ── Assert: graph_chase(h).kind tag = 64 (NErrorHole) ──
    (local.set $g    (call $graph_node_at (local.get $h)))
    (local.set $kind (call $gnode_kind (local.get $g)))
    (if (i32.ne (call $node_kind_tag (local.get $kind)) (i32.const 64))
      (then
        (call $eprint_string (i32.const 4256))
        (call $eprint_string (i32.const 4192))
        (local.set $failed (i32.const 1))))

    ;; ── Assert NOT NBOUND (tag 60) — productive-under-error must NOT
    ;;    produce a regular bound type when the var lookup misses ──
    (if (i32.eq (call $node_kind_tag (local.get $kind)) (i32.const 60))
      (then
        (call $eprint_string (i32.const 4288))
        (call $eprint_string (i32.const 4192))
        (local.set $failed (i32.const 1))))

    (call $env_scope_exit)

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
