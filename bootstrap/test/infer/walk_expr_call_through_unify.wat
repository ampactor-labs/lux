  ;; ═══ walk_expr_call_through_unify.wat — trace harness ════════════
  ;; Executes: Hβ-infer-substrate.md §4.3 production pattern 2
  ;;           (unifications) + §9 worked trace — CallExpr unifies callee
  ;;           against built TFun.
  ;; Per src/infer.mn:820-846 — infer_call:
  ;;             ret_h = mint(InferredCallReturn(...));
  ;;             expected = TFun(build_inferred_params(arg_handles),
  ;;                              TVar(ret_h), row_h);
  ;;             unify(callee_h, expected_h, ...);
  ;;             graph_bind(handle, TVar(ret_h), ...).
  ;; Setup: env preseeded with `id : Forall([qid], TFun([TParam("x",
  ;;                                                       TVar(qid),
  ;;                                                       Inferred,
  ;;                                                       Inferred)],
  ;;                                                    TVar(qid),
  ;;                                                    row_h))`.
  ;; Verifies: synthetic CallExpr(VarRef("id"), [LitInt(7)]) walked →
  ;;           call-result handle chases to NBOUND (the unify cascade
  ;;           resolves the polymorphic qid to TInt via the LitInt arg).
  ;; Exercises: walk_expr.wat — $infer_walk_expr_call,
  ;;            $infer_walk_expr_var_ref (callee), $infer_walk_expr_lit_int
  ;;            (arg); scheme.wat — $instantiate; unify.wat — $unify.
  ;;
  ;; ─── Eight interrogations ─────────────────────────────────────────
  ;;   Graph?      Multiple binds: callee handle (instantiated id type),
  ;;               arg handle (TInt), expected_h (built TFun), result handle.
  ;;   Handler?    Direct seed call.
  ;;   Verb?       CallExpr is implicit `|>` topology — degenerate.
  ;;   Row?        row_h fresh for the call's effect row; no composition
  ;;               at seed.
  ;;   Ownership?  No own params.
  ;;   Refinement? None.
  ;;   Gradient?   Each handle locks down through the unification cascade.
  ;;   Reason?     InferredCallReturn(callee, ...) chain on every step.

  (data (i32.const 4096) "\05\00\00\00PASS:")
  (data (i32.const 4128) "\05\00\00\00FAIL:")
  (data (i32.const 4160) "\01\00\00\00 ")
  (data (i32.const 4192) "\01\00\00\00\0a")
  (data (i32.const 4224) "\14\00\00\00walk_expr_call      ")

  (data (i32.const 4256) "\14\00\00\00ch-not-bound        ")
  (data (i32.const 4288) "\14\00\00\00ch-is-errhole       ")

  ;; Static argument string — the function name "id"
  (data (i32.const 4928) "\02\00\00\00id")

  (func $_start (export "_start")
    (local $qid i32) (local $tparam i32) (local $param_list i32)
    (local $row_h i32) (local $body i32) (local $qs i32) (local $scheme i32)
    (local $cspan i32) (local $vspan i32) (local $aspan i32)
    (local $vexpr i32) (local $aexpr i32) (local $cexpr i32)
    (local $vbody i32) (local $abody i32) (local $cbody i32)
    (local $vnode i32) (local $anode i32) (local $cnode i32)
    (local $args i32)
    (local $vh i32) (local $ah i32) (local $ch i32)
    (local $g i32) (local $kind i32)
    (local $failed i32)
    (local.set $failed (i32.const 0))
    (call $graph_init)
    (call $env_init)
    (call $infer_init)

    ;; ── Build polymorphic id scheme: Forall([qid], TFun([TParam("x",
    ;;    TVar(qid), Inferred, Inferred)], TVar(qid), row_h)) ──
    (local.set $qid (call $graph_fresh_ty (i32.const 0)))
    (local.set $tparam (call $tparam_make
      (call $str_alloc (i32.const 0))   ;; anon param name
      (call $ty_make_tvar (local.get $qid))
      (call $ownership_make_inferred)
      (call $ownership_make_inferred)))
    (local.set $param_list (call $make_list (i32.const 0)))
    (local.set $param_list (call $list_extend_to (local.get $param_list) (i32.const 1)))
    (drop (call $list_set (local.get $param_list) (i32.const 0) (local.get $tparam)))
    (local.set $row_h (call $graph_fresh_row (i32.const 0)))
    (local.set $body (call $ty_make_tfun
      (local.get $param_list)
      (call $ty_make_tvar (local.get $qid))
      (local.get $row_h)))
    (local.set $qs (call $make_list (i32.const 0)))
    (local.set $qs (call $list_extend_to (local.get $qs) (i32.const 1)))
    (drop (call $list_set (local.get $qs) (i32.const 0) (local.get $qid)))
    (local.set $scheme (call $scheme_make_forall (local.get $qs) (local.get $body)))
    ;; env_extend("id", scheme, reason=0, FnScheme)
    (call $env_extend
      (i32.const 4928)
      (local.get $scheme)
      (i32.const 0)
      (call $schemekind_make_fn))

    ;; ── Build VarRef("id") at handle vh ──
    (local.set $vspan (call $alloc (i32.const 16)))
    (i32.store          (local.get $vspan) (i32.const 1))
    (i32.store offset=4 (local.get $vspan) (i32.const 1))
    (i32.store offset=8 (local.get $vspan) (i32.const 1))
    (i32.store offset=12 (local.get $vspan) (i32.const 3))
    (local.set $vexpr (call $alloc (i32.const 8)))
    (i32.store          (local.get $vexpr) (i32.const 85))
    (i32.store offset=4 (local.get $vexpr) (i32.const 4928))
    (local.set $vbody (call $alloc (i32.const 8)))
    (i32.store          (local.get $vbody) (i32.const 110))
    (i32.store offset=4 (local.get $vbody) (local.get $vexpr))
    (local.set $vh (call $graph_fresh_ty (i32.const 0)))
    (local.set $vnode (call $alloc (i32.const 16)))
    (i32.store          (local.get $vnode) (i32.const 0))
    (i32.store offset=4 (local.get $vnode) (local.get $vbody))
    (i32.store offset=8 (local.get $vnode) (local.get $vspan))
    (i32.store offset=12 (local.get $vnode) (local.get $vh))

    ;; ── Build LitInt(7) at handle ah ──
    (local.set $aspan (call $alloc (i32.const 16)))
    (i32.store          (local.get $aspan) (i32.const 1))
    (i32.store offset=4 (local.get $aspan) (i32.const 4))
    (i32.store offset=8 (local.get $aspan) (i32.const 1))
    (i32.store offset=12 (local.get $aspan) (i32.const 5))
    (local.set $aexpr (call $alloc (i32.const 8)))
    (i32.store          (local.get $aexpr) (i32.const 80))
    (i32.store offset=4 (local.get $aexpr) (i32.const 7))
    (local.set $abody (call $alloc (i32.const 8)))
    (i32.store          (local.get $abody) (i32.const 110))
    (i32.store offset=4 (local.get $abody) (local.get $aexpr))
    (local.set $ah (call $graph_fresh_ty (i32.const 0)))
    (local.set $anode (call $alloc (i32.const 16)))
    (i32.store          (local.get $anode) (i32.const 0))
    (i32.store offset=4 (local.get $anode) (local.get $abody))
    (i32.store offset=8 (local.get $anode) (local.get $aspan))
    (i32.store offset=12 (local.get $anode) (local.get $ah))

    ;; ── Build args list = [anode] ──
    (local.set $args (call $make_list (i32.const 0)))
    (local.set $args (call $list_extend_to (local.get $args) (i32.const 1)))
    (drop (call $list_set (local.get $args) (i32.const 0) (local.get $anode)))

    ;; ── Build CallExpr(vnode, args) at handle ch ──
    (local.set $cspan (call $alloc (i32.const 16)))
    (i32.store          (local.get $cspan) (i32.const 1))
    (i32.store offset=4 (local.get $cspan) (i32.const 1))
    (i32.store offset=8 (local.get $cspan) (i32.const 1))
    (i32.store offset=12 (local.get $cspan) (i32.const 6))
    ;; CallExpr layout: [tag=88][callee][args]
    (local.set $cexpr (call $alloc (i32.const 12)))
    (i32.store          (local.get $cexpr) (i32.const 88))
    (i32.store offset=4 (local.get $cexpr) (local.get $vnode))
    (i32.store offset=8 (local.get $cexpr) (local.get $args))
    (local.set $cbody (call $alloc (i32.const 8)))
    (i32.store          (local.get $cbody) (i32.const 110))
    (i32.store offset=4 (local.get $cbody) (local.get $cexpr))
    (local.set $ch (call $graph_fresh_ty (i32.const 0)))
    (local.set $cnode (call $alloc (i32.const 16)))
    (i32.store          (local.get $cnode) (i32.const 0))
    (i32.store offset=4 (local.get $cnode) (local.get $cbody))
    (i32.store offset=8 (local.get $cnode) (local.get $cspan))
    (i32.store offset=12 (local.get $cnode) (local.get $ch))

    ;; ── Walk the call ──
    (drop (call $infer_walk_expr (local.get $cnode)))

    ;; ── Assert: ch.kind = NBOUND (60), NOT NErrorHole (64) ──
    (local.set $g    (call $graph_node_at (local.get $ch)))
    (local.set $kind (call $gnode_kind (local.get $g)))
    (if (i32.ne (call $node_kind_tag (local.get $kind)) (i32.const 60))
      (then
        (call $eprint_string (i32.const 4256))
        (call $eprint_string (i32.const 4192))
        (local.set $failed (i32.const 1))))
    (if (i32.eq (call $node_kind_tag (local.get $kind)) (i32.const 64))
      (then
        (call $eprint_string (i32.const 4288))
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
