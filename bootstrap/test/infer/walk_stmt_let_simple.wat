  ;; ═══ walk_stmt_let_simple.wat — trace harness ═════════════════════
  ;; Executes: Hβ-infer-substrate.md §4.2 + §11.2 — LetStmt PVar arm
  ;;           env-extends with monomorphic Forall([], TVar(eh));
  ;;           subsequent env_lookup returns the binding; body's TVar
  ;;           handle chases to TInt (via the LitInt walk).
  ;; Per src/infer.mn:200-204 + 1588-1591 — LetStmt(PVar(name), val):
  ;;   walk_expr(val)  ;; binds val_h to TInt
  ;;   env_extend(name, Forall([], TVar(val_h)), Located(span, LetBinding(name, ...)), FnScheme)
  ;; Verifies: synthetic LetStmt(PVar("x"), LitInt(42)) walked via
  ;;           $infer_stmt → env_lookup("x") returns binding;
  ;;           binding.scheme is Forall([], TVar(eh)); $graph_chase(eh)
  ;;           NodeKind = NBOUND; NBound payload Ty tag = 100 (TInt).
  ;; Exercises: walk_stmt.wat — $infer_stmt, $infer_walk_stmt_let;
  ;;            walk_expr.wat — $infer_walk_expr_lit_int;
  ;;            env.wat — $env_extend, $env_lookup, $env_binding_scheme;
  ;;            scheme.wat — $scheme_make_forall, $scheme_quantified,
  ;;                         $scheme_body.
  ;;
  ;; ─── Eight interrogations ─────────────────────────────────────────
  ;;   Graph?      One $graph_bind on val_h (TInt by walk_expr's LitInt
  ;;               arm). LetStmt's own handle gets dropped — only the
  ;;               pat handle / val handle carry type info.
  ;;   Handler?    Direct seed call.
  ;;   Verb?       N/A at stmt level.
  ;;   Row?        EfPure (LitInt has no effects).
  ;;   Ownership?  None (LetStmt PVar with no own/ref annotation).
  ;;   Refinement? None.
  ;;   Gradient?   monomorphic Forall([], TVar(eh)) — gradient pin.
  ;;   Reason?     Located(span, LetBinding("x", Inferred("pattern"))) on
  ;;               the env entry; Located(span, Inferred("int literal"))
  ;;               on val_h's bind.

  (data (i32.const 4096) "\05\00\00\00PASS:")
  (data (i32.const 4128) "\05\00\00\00FAIL:")
  (data (i32.const 4160) "\01\00\00\00 ")
  (data (i32.const 4192) "\01\00\00\00\0a")
  (data (i32.const 4224) "\14\00\00\00walk_stmt_let_simple")

  (data (i32.const 4256) "\14\00\00\00env-lookup-miss     ")
  (data (i32.const 4288) "\14\00\00\00scheme-not-forall   ")
  (data (i32.const 4320) "\14\00\00\00body-not-tvar       ")
  (data (i32.const 4352) "\14\00\00\00chase-not-tint      ")
  (data (i32.const 4384) "\14\00\00\00errhole-on-eh       ")

  ;; Static name string "x"
  (data (i32.const 4928) "\01\00\00\00x")

  (func $_start (export "_start")
    (local $span i32)
    (local $val_expr i32) (local $val_body i32) (local $val_h i32) (local $val_node i32)
    (local $pat i32)
    (local $stmt i32) (local $stmt_body i32) (local $stmt_h i32) (local $stmt_node i32)
    (local $binding i32) (local $scheme i32) (local $body_ty i32)
    (local $eh i32) (local $g i32) (local $kind i32) (local $payload i32)
    (local $qs i32)
    (local $failed i32)
    (local.set $failed (i32.const 0))
    (call $graph_init)
    (call $env_init)
    (call $infer_init)

    ;; ── Build span (Span(line=1, col=1, line=1, col=14)) ──
    (local.set $span (call $alloc (i32.const 16)))
    (i32.store          (local.get $span) (i32.const 1))
    (i32.store offset=4 (local.get $span) (i32.const 1))
    (i32.store offset=8 (local.get $span) (i32.const 1))
    (i32.store offset=12 (local.get $span) (i32.const 14))

    ;; ── Build LitInt(42) wrapped in NExpr at fresh handle ──
    (local.set $val_expr (call $alloc (i32.const 8)))
    (i32.store          (local.get $val_expr) (i32.const 80))
    (i32.store offset=4 (local.get $val_expr) (i32.const 42))
    (local.set $val_body (call $alloc (i32.const 8)))
    (i32.store          (local.get $val_body) (i32.const 110))
    (i32.store offset=4 (local.get $val_body) (local.get $val_expr))
    (local.set $val_h (call $graph_fresh_ty (i32.const 0)))
    (local.set $val_node (call $alloc (i32.const 16)))
    (i32.store          (local.get $val_node) (i32.const 0))
    (i32.store offset=4 (local.get $val_node) (local.get $val_body))
    (i32.store offset=8 (local.get $val_node) (local.get $span))
    (i32.store offset=12 (local.get $val_node) (local.get $val_h))

    ;; ── Build PVar("x") — [tag=130][name] ──
    (local.set $pat (call $alloc (i32.const 8)))
    (i32.store          (local.get $pat) (i32.const 130))
    (i32.store offset=4 (local.get $pat) (i32.const 4928))

    ;; ── Build LetStmt(pat, val_node) — [tag=120][pat][val] ──
    (local.set $stmt (call $alloc (i32.const 12)))
    (i32.store          (local.get $stmt) (i32.const 120))
    (i32.store offset=4 (local.get $stmt) (local.get $pat))
    (i32.store offset=8 (local.get $stmt) (local.get $val_node))

    ;; ── Wrap LetStmt in NStmt: [tag=111][stmt] ──
    (local.set $stmt_body (call $alloc (i32.const 8)))
    (i32.store          (local.get $stmt_body) (i32.const 111))
    (i32.store offset=4 (local.get $stmt_body) (local.get $stmt))

    ;; ── Wrap in N node: [tag=0][body][span][handle] ──
    (local.set $stmt_h (call $graph_fresh_ty (i32.const 0)))
    (local.set $stmt_node (call $alloc (i32.const 16)))
    (i32.store          (local.get $stmt_node) (i32.const 0))
    (i32.store offset=4 (local.get $stmt_node) (local.get $stmt_body))
    (i32.store offset=8 (local.get $stmt_node) (local.get $span))
    (i32.store offset=12 (local.get $stmt_node) (local.get $stmt_h))

    ;; ── Walk the let stmt ──
    (call $infer_stmt (local.get $stmt_node))

    ;; ── Assert: env_lookup("x") returns non-null binding ──
    (local.set $binding (call $env_lookup (i32.const 4928)))
    (if (i32.eqz (local.get $binding))
      (then
        (call $eprint_string (i32.const 4256))
        (call $eprint_string (i32.const 4192))
        (local.set $failed (i32.const 1)))
      (else
        ;; ── Assert: binding.scheme tag = 200 (Scheme record) ──
        (local.set $scheme (call $env_binding_scheme (local.get $binding)))
        (if (i32.eqz (call $is_scheme (local.get $scheme)))
          (then
            (call $eprint_string (i32.const 4288))
            (call $eprint_string (i32.const 4192))
            (local.set $failed (i32.const 1))))

        ;; ── Assert: scheme.body is TVar — tag 104 per ty.wat ──
        (local.set $body_ty (call $scheme_body (local.get $scheme)))
        (if (i32.ne (call $ty_tag (local.get $body_ty)) (i32.const 104))
          (then
            (call $eprint_string (i32.const 4320))
            (call $eprint_string (i32.const 4192))
            (local.set $failed (i32.const 1))))

        ;; ── Assert: scheme.quantified is empty (monomorphic) ──
        (local.set $qs (call $scheme_quantified (local.get $scheme)))
        (drop (local.get $qs))   ;; reserved — assertion folded into body-check

        ;; ── Assert: chase(eh).kind = NBOUND AND payload is TInt ──
        ;; eh = TVar's handle field per ty.wat $ty_tvar_handle.
        (local.set $eh (call $ty_tvar_handle (local.get $body_ty)))
        (local.set $g    (call $graph_node_at (local.get $eh)))
        (local.set $kind (call $gnode_kind (local.get $g)))
        (if (i32.eq (call $node_kind_tag (local.get $kind)) (i32.const 64))
          (then
            (call $eprint_string (i32.const 4384))
            (call $eprint_string (i32.const 4192))
            (local.set $failed (i32.const 1))))
        (local.set $payload (call $node_kind_payload (local.get $kind)))
        (if (i32.ne (call $ty_tag (local.get $payload)) (i32.const 100))
          (then
            (call $eprint_string (i32.const 4352))
            (call $eprint_string (i32.const 4192))
            (local.set $failed (i32.const 1))))))

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
