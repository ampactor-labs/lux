  ;; ═══ walk_expr_binop_arith.wat — trace harness ═══════════════════
  ;; Executes: Hβ-infer-substrate.md §4.3 production pattern 1 + §9.2
  ;;           worked trace — BinOpExpr BKArith path (BAdd = 140).
  ;; Per src/infer.mn:1554-1557 — BKArith arm:
  ;;             unify(lh, rh, OpConstraint(...));
  ;;             graph_bind(handle, TVar(lh), Located(span, OpConstraint(...))).
  ;; Per spec 04 §What the walk produces — structural-constraint pattern.
  ;; Verifies: BinOp(BAdd, LitInt(1), LitInt(2)) walked →
  ;;           - lh.kind = NBOUND, payload Ty tag = 100 (TInt)
  ;;           - rh.kind = NBOUND, payload Ty tag = 100 (TInt)
  ;;           - bh.kind = NBOUND (chases TVar(lh) → eventually TInt;
  ;;             we just check NBOUND, not chase-deep)
  ;; Exercises: walk_expr.wat — $infer_walk_expr_binop, $unify (nested),
  ;;            $ty_make_tint (via children's $infer_walk_expr_lit_int).
  ;;
  ;; ─── Eight interrogations ─────────────────────────────────────────
  ;;   Graph?      Three $graph_bind sites — children + result.
  ;;   Handler?    Direct seed call.
  ;;   Verb?       N/A.
  ;;   Row?        None at seed.
  ;;   Ownership?  None (literals, no consume).
  ;;   Refinement? None.
  ;;   Gradient?   Three NFree → NBound steps + one unify-driven bind.
  ;;   Reason?     Located(span, OpConstraint("140", left, right)).

  (data (i32.const 4096) "\05\00\00\00PASS:")
  (data (i32.const 4128) "\05\00\00\00FAIL:")
  (data (i32.const 4160) "\01\00\00\00 ")
  (data (i32.const 4192) "\01\00\00\00\0a")
  (data (i32.const 4224) "\17\00\00\00walk_expr_binop_arith  ")

  (data (i32.const 4256) "\14\00\00\00lh-not-bound        ")
  (data (i32.const 4288) "\14\00\00\00rh-not-bound        ")
  (data (i32.const 4320) "\14\00\00\00bh-not-bound        ")
  (data (i32.const 4352) "\14\00\00\00lh-not-tint         ")
  (data (i32.const 4384) "\14\00\00\00rh-not-tint         ")

  (func $_start (export "_start")
    (local $bspan i32) (local $lspan i32) (local $rspan i32)
    (local $litl i32) (local $litr i32) (local $bin i32)
    (local $lbody i32) (local $rbody i32) (local $bbody i32)
    (local $lnode i32) (local $rnode i32) (local $bnode i32)
    (local $lh i32) (local $rh i32) (local $bh i32)
    (local $g i32) (local $kind i32) (local $payload i32)
    (local $failed i32)
    (local.set $failed (i32.const 0))
    (call $graph_init)
    (call $env_init)
    (call $infer_init)

    ;; ── Build LitInt(1) at handle lh ──
    (local.set $lspan (call $alloc (i32.const 16)))
    (i32.store          (local.get $lspan) (i32.const 1))
    (i32.store offset=4 (local.get $lspan) (i32.const 1))
    (i32.store offset=8 (local.get $lspan) (i32.const 1))
    (i32.store offset=12 (local.get $lspan) (i32.const 2))
    (local.set $litl (call $alloc (i32.const 8)))
    (i32.store          (local.get $litl) (i32.const 80))
    (i32.store offset=4 (local.get $litl) (i32.const 1))
    (local.set $lbody (call $alloc (i32.const 8)))
    (i32.store          (local.get $lbody) (i32.const 110))
    (i32.store offset=4 (local.get $lbody) (local.get $litl))
    (local.set $lh (call $graph_fresh_ty (i32.const 0)))
    (local.set $lnode (call $alloc (i32.const 16)))
    (i32.store          (local.get $lnode) (i32.const 0))
    (i32.store offset=4 (local.get $lnode) (local.get $lbody))
    (i32.store offset=8 (local.get $lnode) (local.get $lspan))
    (i32.store offset=12 (local.get $lnode) (local.get $lh))

    ;; ── Build LitInt(2) at handle rh ──
    (local.set $rspan (call $alloc (i32.const 16)))
    (i32.store          (local.get $rspan) (i32.const 1))
    (i32.store offset=4 (local.get $rspan) (i32.const 5))
    (i32.store offset=8 (local.get $rspan) (i32.const 1))
    (i32.store offset=12 (local.get $rspan) (i32.const 6))
    (local.set $litr (call $alloc (i32.const 8)))
    (i32.store          (local.get $litr) (i32.const 80))
    (i32.store offset=4 (local.get $litr) (i32.const 2))
    (local.set $rbody (call $alloc (i32.const 8)))
    (i32.store          (local.get $rbody) (i32.const 110))
    (i32.store offset=4 (local.get $rbody) (local.get $litr))
    (local.set $rh (call $graph_fresh_ty (i32.const 0)))
    (local.set $rnode (call $alloc (i32.const 16)))
    (i32.store          (local.get $rnode) (i32.const 0))
    (i32.store offset=4 (local.get $rnode) (local.get $rbody))
    (i32.store offset=8 (local.get $rnode) (local.get $rspan))
    (i32.store offset=12 (local.get $rnode) (local.get $rh))

    ;; ── Build BinOpExpr(BAdd=140, lnode, rnode) at handle bh ──
    (local.set $bspan (call $alloc (i32.const 16)))
    (i32.store          (local.get $bspan) (i32.const 1))
    (i32.store offset=4 (local.get $bspan) (i32.const 1))
    (i32.store offset=8 (local.get $bspan) (i32.const 1))
    (i32.store offset=12 (local.get $bspan) (i32.const 6))
    ;; BinOpExpr layout: [tag=86][op][left][right]
    (local.set $bin (call $alloc (i32.const 16)))
    (i32.store           (local.get $bin) (i32.const 86))
    (i32.store offset=4  (local.get $bin) (i32.const 140))   ;; BAdd
    (i32.store offset=8  (local.get $bin) (local.get $lnode))
    (i32.store offset=12 (local.get $bin) (local.get $rnode))
    (local.set $bbody (call $alloc (i32.const 8)))
    (i32.store          (local.get $bbody) (i32.const 110))
    (i32.store offset=4 (local.get $bbody) (local.get $bin))
    (local.set $bh (call $graph_fresh_ty (i32.const 0)))
    (local.set $bnode (call $alloc (i32.const 16)))
    (i32.store          (local.get $bnode) (i32.const 0))
    (i32.store offset=4 (local.get $bnode) (local.get $bbody))
    (i32.store offset=8 (local.get $bnode) (local.get $bspan))
    (i32.store offset=12 (local.get $bnode) (local.get $bh))

    ;; ── Walk the BinOp ──
    (drop (call $infer_walk_expr (local.get $bnode)))

    ;; ── Assert: lh kind = NBOUND, payload = TInt ──
    (local.set $g    (call $graph_node_at (local.get $lh)))
    (local.set $kind (call $gnode_kind (local.get $g)))
    (if (i32.ne (call $node_kind_tag (local.get $kind)) (i32.const 60))
      (then
        (call $eprint_string (i32.const 4256))
        (call $eprint_string (i32.const 4192))
        (local.set $failed (i32.const 1)))
      (else
        (local.set $payload (call $node_kind_payload (local.get $kind)))
        (if (i32.ne (call $ty_tag (local.get $payload)) (i32.const 100))
          (then
            (call $eprint_string (i32.const 4352))
            (call $eprint_string (i32.const 4192))
            (local.set $failed (i32.const 1))))))

    ;; ── Assert: rh kind = NBOUND, payload = TInt ──
    (local.set $g    (call $graph_node_at (local.get $rh)))
    (local.set $kind (call $gnode_kind (local.get $g)))
    (if (i32.ne (call $node_kind_tag (local.get $kind)) (i32.const 60))
      (then
        (call $eprint_string (i32.const 4288))
        (call $eprint_string (i32.const 4192))
        (local.set $failed (i32.const 1)))
      (else
        (local.set $payload (call $node_kind_payload (local.get $kind)))
        (if (i32.ne (call $ty_tag (local.get $payload)) (i32.const 100))
          (then
            (call $eprint_string (i32.const 4384))
            (call $eprint_string (i32.const 4192))
            (local.set $failed (i32.const 1))))))

    ;; ── Assert: bh kind = NBOUND (chases TVar(lh)) ──
    (local.set $g    (call $graph_node_at (local.get $bh)))
    (local.set $kind (call $gnode_kind (local.get $g)))
    (if (i32.ne (call $node_kind_tag (local.get $kind)) (i32.const 60))
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
