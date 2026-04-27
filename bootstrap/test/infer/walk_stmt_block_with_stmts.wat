  ;; ═══ walk_stmt_block_with_stmts.wat — trace harness ═══════════════
  ;; Executes: Hβ-infer-substrate.md §4.2 + §13.3 #9 closure —
  ;;           BlockExpr arm now calls $infer_stmt_list before walking
  ;;           final_expr. Per the Edit 6 retrofit of walk_expr.wat:824.
  ;; Setup: synthetic `{ let x = 5; x }` — BlockExpr(stmts=[NStmt(LetStmt(
  ;;        PVar("x"), LitInt(5)))], final_expr=NExpr(VarRef("x"))).
  ;;        Without the §13.3 #9 closure (drop $stmts; never walk), the
  ;;        let-extend never lands and final_expr's VarRef("x") env_lookup
  ;;        misses → NErrorHole on block's own handle.
  ;; Verifies: block handle's $graph_chase yields NBOUND (NOT
  ;;           NErrorHole); the chained chase resolves through TVar(eh)
  ;;           where eh ultimately resolves to TInt (from the let value).
  ;; Exercises: walk_expr.wat — $infer_walk_expr_block (the retrofitted
  ;;            arm); walk_stmt.wat — $infer_stmt_list, $infer_walk_stmt_let;
  ;;            env.wat — $env_extend during let, $env_lookup during
  ;;            VarRef.
  ;;
  ;; ─── Eight interrogations ─────────────────────────────────────────
  ;;   Graph?      Block handle binds to TVar(final_h); final_h resolves
  ;;               to TVar(let_val_h); let_val_h binds to TInt. Each step
  ;;               is one $graph_bind.
  ;;   Handler?    Direct seed call.
  ;;   Verb?       N/A at stmt level.
  ;;   Row?        EfPure.
  ;;   Ownership?  None.
  ;;   Refinement? None.
  ;;   Gradient?   block handle moves NFree → NBound through the chain.
  ;;   Reason?     Located(span, Inferred("block result")) on block bind;
  ;;               LetBinding("x", Inferred("pattern")) on the env entry;
  ;;               VarLookup("x", ...) on the final_expr's handle.

  (data (i32.const 4096) "\05\00\00\00PASS:")
  (data (i32.const 4128) "\05\00\00\00FAIL:")
  (data (i32.const 4160) "\01\00\00\00 ")
  (data (i32.const 4192) "\01\00\00\00\0a")
  (data (i32.const 4224) "\14\00\00\00walk_stmt_block_stmt")

  (data (i32.const 4256) "\14\00\00\00block-not-bound     ")
  (data (i32.const 4288) "\14\00\00\00block-is-errhole    ")
  (data (i32.const 4320) "\14\00\00\00final-not-bound     ")

  ;; Static name string "x"
  (data (i32.const 4928) "\01\00\00\00x")

  (func $_start (export "_start")
    (local $span i32)
    ;; LetStmt sub-pieces:
    (local $let_val_expr i32) (local $let_val_body i32) (local $let_val_h i32) (local $let_val_node i32)
    (local $pat i32)
    (local $let_stmt i32) (local $let_stmt_body i32) (local $let_stmt_h i32) (local $let_stmt_node i32)
    ;; BlockExpr sub-pieces:
    (local $stmts i32)
    (local $final_var i32) (local $final_body i32) (local $final_h i32) (local $final_node i32)
    (local $block i32) (local $block_body i32) (local $block_h i32) (local $block_node i32)
    ;; Assertions:
    (local $g i32) (local $kind i32) (local $kind_tag i32)
    (local $g_final i32) (local $kind_final i32) (local $kind_final_tag i32)
    (local $failed i32)
    (local.set $failed (i32.const 0))
    (call $graph_init)
    (call $env_init)
    (call $infer_init)

    ;; ── span ──
    (local.set $span (call $alloc (i32.const 16)))
    (i32.store          (local.get $span) (i32.const 1))
    (i32.store offset=4 (local.get $span) (i32.const 1))
    (i32.store offset=8 (local.get $span) (i32.const 1))
    (i32.store offset=12 (local.get $span) (i32.const 18))

    ;; ── Build LitInt(5) wrapped in NExpr ──
    (local.set $let_val_expr (call $alloc (i32.const 8)))
    (i32.store          (local.get $let_val_expr) (i32.const 80))
    (i32.store offset=4 (local.get $let_val_expr) (i32.const 5))
    (local.set $let_val_body (call $alloc (i32.const 8)))
    (i32.store          (local.get $let_val_body) (i32.const 110))
    (i32.store offset=4 (local.get $let_val_body) (local.get $let_val_expr))
    (local.set $let_val_h (call $graph_fresh_ty (i32.const 0)))
    (local.set $let_val_node (call $alloc (i32.const 16)))
    (i32.store          (local.get $let_val_node) (i32.const 0))
    (i32.store offset=4 (local.get $let_val_node) (local.get $let_val_body))
    (i32.store offset=8 (local.get $let_val_node) (local.get $span))
    (i32.store offset=12 (local.get $let_val_node) (local.get $let_val_h))

    ;; ── PVar("x") ──
    (local.set $pat (call $alloc (i32.const 8)))
    (i32.store          (local.get $pat) (i32.const 130))
    (i32.store offset=4 (local.get $pat) (i32.const 4928))

    ;; ── LetStmt(pat, val_node) wrapped in NStmt + N ──
    (local.set $let_stmt (call $alloc (i32.const 12)))
    (i32.store          (local.get $let_stmt) (i32.const 120))
    (i32.store offset=4 (local.get $let_stmt) (local.get $pat))
    (i32.store offset=8 (local.get $let_stmt) (local.get $let_val_node))

    (local.set $let_stmt_body (call $alloc (i32.const 8)))
    (i32.store          (local.get $let_stmt_body) (i32.const 111))
    (i32.store offset=4 (local.get $let_stmt_body) (local.get $let_stmt))

    (local.set $let_stmt_h (call $graph_fresh_ty (i32.const 0)))
    (local.set $let_stmt_node (call $alloc (i32.const 16)))
    (i32.store          (local.get $let_stmt_node) (i32.const 0))
    (i32.store offset=4 (local.get $let_stmt_node) (local.get $let_stmt_body))
    (i32.store offset=8 (local.get $let_stmt_node) (local.get $span))
    (i32.store offset=12 (local.get $let_stmt_node) (local.get $let_stmt_h))

    ;; ── stmts list = [let_stmt_node] ──
    (local.set $stmts (call $make_list (i32.const 0)))
    (local.set $stmts (call $list_extend_to (local.get $stmts) (i32.const 1)))
    (drop (call $list_set (local.get $stmts) (i32.const 0) (local.get $let_stmt_node)))

    ;; ── final_expr = NExpr(VarRef("x")) ──
    (local.set $final_var (call $alloc (i32.const 8)))
    (i32.store          (local.get $final_var) (i32.const 85))
    (i32.store offset=4 (local.get $final_var) (i32.const 4928))
    (local.set $final_body (call $alloc (i32.const 8)))
    (i32.store          (local.get $final_body) (i32.const 110))
    (i32.store offset=4 (local.get $final_body) (local.get $final_var))
    (local.set $final_h (call $graph_fresh_ty (i32.const 0)))
    (local.set $final_node (call $alloc (i32.const 16)))
    (i32.store          (local.get $final_node) (i32.const 0))
    (i32.store offset=4 (local.get $final_node) (local.get $final_body))
    (i32.store offset=8 (local.get $final_node) (local.get $span))
    (i32.store offset=12 (local.get $final_node) (local.get $final_h))

    ;; ── BlockExpr(stmts, final_expr) — [tag=91][stmts][final] — 12 bytes ──
    (local.set $block (call $alloc (i32.const 12)))
    (i32.store          (local.get $block) (i32.const 91))
    (i32.store offset=4 (local.get $block) (local.get $stmts))
    (i32.store offset=8 (local.get $block) (local.get $final_node))

    (local.set $block_body (call $alloc (i32.const 8)))
    (i32.store          (local.get $block_body) (i32.const 110))
    (i32.store offset=4 (local.get $block_body) (local.get $block))

    (local.set $block_h (call $graph_fresh_ty (i32.const 0)))
    (local.set $block_node (call $alloc (i32.const 16)))
    (i32.store          (local.get $block_node) (i32.const 0))
    (i32.store offset=4 (local.get $block_node) (local.get $block_body))
    (i32.store offset=8 (local.get $block_node) (local.get $span))
    (i32.store offset=12 (local.get $block_node) (local.get $block_h))

    ;; ── Walk via $infer_walk_expr (entry; exercises BlockExpr arm
    ;;    which now calls $infer_stmt_list — Edit 6 retrofit) ──
    (drop (call $infer_walk_expr (local.get $block_node)))

    ;; ── Assert: block_h is NBOUND, NOT NErrorHole ──
    (local.set $g (call $graph_node_at (local.get $block_h)))
    (local.set $kind (call $gnode_kind (local.get $g)))
    (local.set $kind_tag (call $node_kind_tag (local.get $kind)))
    (if (i32.ne (local.get $kind_tag) (i32.const 60))
      (then
        (call $eprint_string (i32.const 4256))
        (call $eprint_string (i32.const 4192))
        (local.set $failed (i32.const 1))))
    (if (i32.eq (local.get $kind_tag) (i32.const 64))
      (then
        (call $eprint_string (i32.const 4288))
        (call $eprint_string (i32.const 4192))
        (local.set $failed (i32.const 1))))

    ;; ── Assert: final_h (the VarRef) is NBOUND — i.e., env_lookup hit ──
    ;; This is the load-bearing assertion: Edit 6's retrofit means stmts
    ;; populate env before final_expr walks. Without the retrofit,
    ;; env_lookup("x") misses → final_h binds NErrorHole.
    (local.set $g_final (call $graph_node_at (local.get $final_h)))
    (local.set $kind_final (call $gnode_kind (local.get $g_final)))
    (local.set $kind_final_tag (call $node_kind_tag (local.get $kind_final)))
    (if (i32.ne (local.get $kind_final_tag) (i32.const 60))
      (then
        (call $eprint_string (i32.const 4320))
        (call $eprint_string (i32.const 4192))
        (local.set $failed (i32.const 1))))

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
