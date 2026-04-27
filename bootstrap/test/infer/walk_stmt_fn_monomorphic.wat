  ;; ═══ walk_stmt_fn_monomorphic.wat — trace harness ═════════════════
  ;; Executes: Hβ-infer-substrate.md §4.2 + §11.2 — FnStmt arm two-pass
  ;;           discipline: enter scope, mint per-param + return + row
  ;;           handles, env-extend each param + pre-bind fn name with
  ;;           placeholder Forall, walk body, unify body ↔ ret, exit
  ;;           scope, generalize, re-extend fn name with generalized
  ;;           scheme.
  ;; Per src/infer.nx:262-369 — infer_fn (canonical wheel).
  ;; Setup: synthetic FnStmt(name="f",
  ;;                          params=[TParam("n", _, Inferred, Inferred)],
  ;;                          ret=NExpr(LitUnit),
  ;;                          effs=[],
  ;;                          body=NExpr(VarRef("n"))) at fresh handle.
  ;; Verifies: env_lookup("f") returns binding; binding.scheme is a
  ;;           Scheme record (tag 200); scheme.body is a TFun (tag 107);
  ;;           NOT NErrorHole on the fn handle.
  ;; Exercises: walk_stmt.wat — $infer_stmt, $infer_walk_stmt_fn,
  ;;            $walk_stmt_build_inferred_params; walk_expr.wat —
  ;;            $infer_walk_expr_var_ref (body); state.wat —
  ;;            $infer_fn_stack_push/_pop; env.wat — $env_scope_enter/
  ;;            _exit, $env_extend; scheme.wat — $scheme_make_forall,
  ;;            $generalize; unify.wat — $unify.
  ;;
  ;; ─── Eight interrogations ─────────────────────────────────────────
  ;;   Graph?      $graph_bind on fn handle (TFun); body's VarRef binds
  ;;               sub-handle.
  ;;   Handler?    Direct seed call.
  ;;   Verb?       N/A at stmt level.
  ;;   Row?        Fresh row_h on the TFun; row composition deferred per
  ;;               Hβ.infer.row-normalize.
  ;;   Ownership?  Param ownership preserved through TParam tag 202;
  ;;               body's VarRef's affine-ledger fires inside walk_expr.
  ;;   Refinement? None.
  ;;   Gradient?   Two-pass discipline IS the gradient evolution from
  ;;               "fn declared" → "body inferred" → "scheme generalized".
  ;;   Reason?     Located(span, Declared("f")) on fn handle bind +
  ;;               re-extend; Located(span, Inferred("param")) on each
  ;;               param handle's mint; FnReturn("f", Inferred("return"))
  ;;               on body↔ret unify.

  (data (i32.const 4096) "\05\00\00\00PASS:")
  (data (i32.const 4128) "\05\00\00\00FAIL:")
  (data (i32.const 4160) "\01\00\00\00 ")
  (data (i32.const 4192) "\01\00\00\00\0a")
  (data (i32.const 4224) "\14\00\00\00walk_stmt_fn_mono   ")

  (data (i32.const 4256) "\14\00\00\00env-lookup-miss     ")
  (data (i32.const 4288) "\14\00\00\00scheme-not-forall   ")
  (data (i32.const 4320) "\14\00\00\00body-not-tfun       ")
  (data (i32.const 4352) "\14\00\00\00fn-handle-errhole   ")

  ;; Static name strings
  (data (i32.const 4928) "\01\00\00\00f")
  (data (i32.const 4944) "\01\00\00\00n")

  (func $_start (export "_start")
    (local $span i32)
    (local $tparam i32) (local $params i32)
    (local $ret_unit_expr i32) (local $ret_unit_body i32) (local $ret_unit_node i32) (local $ret_unit_h i32)
    (local $body_var i32) (local $body_body i32) (local $body_node i32) (local $body_h i32)
    (local $effs i32)
    (local $stmt i32) (local $stmt_body i32) (local $stmt_h i32) (local $stmt_node i32)
    (local $binding i32) (local $scheme i32) (local $body_ty i32)
    (local $g i32) (local $kind i32)
    (local $failed i32)
    (local.set $failed (i32.const 0))
    (call $graph_init)
    (call $env_init)
    (call $infer_init)

    ;; ── Build span ──
    (local.set $span (call $alloc (i32.const 16)))
    (i32.store          (local.get $span) (i32.const 1))
    (i32.store offset=4 (local.get $span) (i32.const 1))
    (i32.store offset=8 (local.get $span) (i32.const 1))
    (i32.store offset=12 (local.get $span) (i32.const 20))

    ;; ── Build TParam("n", 0, 170, 170) — parser tag=190, 5 fields, 20 bytes ──
    (local.set $tparam (call $alloc (i32.const 20)))
    (i32.store          (local.get $tparam) (i32.const 190))
    (i32.store offset=4 (local.get $tparam) (i32.const 4944))   ;; "n"
    (i32.store offset=8 (local.get $tparam) (i32.const 0))      ;; ty (opaque to seed)
    (i32.store offset=12 (local.get $tparam) (i32.const 170))   ;; own = Inferred
    (i32.store offset=16 (local.get $tparam) (i32.const 170))

    ;; ── Build params list = [tparam] ──
    (local.set $params (call $make_list (i32.const 0)))
    (local.set $params (call $list_extend_to (local.get $params) (i32.const 1)))
    (drop (call $list_set (local.get $params) (i32.const 0) (local.get $tparam)))

    ;; ── Build NExpr(LitUnit) for default ret per parser_fn.wat:202 ──
    ;; LitUnit is a sentinel (tag 84 < HEAP_BASE) — passed as-is into NExpr.
    (local.set $ret_unit_body (call $alloc (i32.const 8)))
    (i32.store          (local.get $ret_unit_body) (i32.const 110))
    (i32.store offset=4 (local.get $ret_unit_body) (i32.const 84))
    (local.set $ret_unit_h (call $graph_fresh_ty (i32.const 0)))
    (local.set $ret_unit_node (call $alloc (i32.const 16)))
    (i32.store          (local.get $ret_unit_node) (i32.const 0))
    (i32.store offset=4 (local.get $ret_unit_node) (local.get $ret_unit_body))
    (i32.store offset=8 (local.get $ret_unit_node) (local.get $span))
    (i32.store offset=12 (local.get $ret_unit_node) (local.get $ret_unit_h))

    ;; ── Build empty effs list ──
    (local.set $effs (call $make_list (i32.const 0)))

    ;; ── Build body: VarRef("n") wrapped in NExpr ──
    (local.set $body_var (call $alloc (i32.const 8)))
    (i32.store          (local.get $body_var) (i32.const 85))   ;; VarRef tag
    (i32.store offset=4 (local.get $body_var) (i32.const 4944)) ;; "n"
    (local.set $body_body (call $alloc (i32.const 8)))
    (i32.store          (local.get $body_body) (i32.const 110))
    (i32.store offset=4 (local.get $body_body) (local.get $body_var))
    (local.set $body_h (call $graph_fresh_ty (i32.const 0)))
    (local.set $body_node (call $alloc (i32.const 16)))
    (i32.store          (local.get $body_node) (i32.const 0))
    (i32.store offset=4 (local.get $body_node) (local.get $body_body))
    (i32.store offset=8 (local.get $body_node) (local.get $span))
    (i32.store offset=12 (local.get $body_node) (local.get $body_h))

    ;; ── Build FnStmt(name="f", params, ret, effs, body) — 24 bytes ──
    (local.set $stmt (call $alloc (i32.const 24)))
    (i32.store          (local.get $stmt) (i32.const 121))
    (i32.store offset=4  (local.get $stmt) (i32.const 4928))    ;; "f"
    (i32.store offset=8  (local.get $stmt) (local.get $params))
    (i32.store offset=12 (local.get $stmt) (local.get $ret_unit_node))
    (i32.store offset=16 (local.get $stmt) (local.get $effs))
    (i32.store offset=20 (local.get $stmt) (local.get $body_node))

    ;; ── Wrap in NStmt ──
    (local.set $stmt_body (call $alloc (i32.const 8)))
    (i32.store          (local.get $stmt_body) (i32.const 111))
    (i32.store offset=4 (local.get $stmt_body) (local.get $stmt))

    ;; ── Wrap in N node ──
    (local.set $stmt_h (call $graph_fresh_ty (i32.const 0)))
    (local.set $stmt_node (call $alloc (i32.const 16)))
    (i32.store          (local.get $stmt_node) (i32.const 0))
    (i32.store offset=4 (local.get $stmt_node) (local.get $stmt_body))
    (i32.store offset=8 (local.get $stmt_node) (local.get $span))
    (i32.store offset=12 (local.get $stmt_node) (local.get $stmt_h))

    ;; ── Walk the fn stmt ──
    (call $infer_stmt (local.get $stmt_node))

    ;; ── Assert: env_lookup("f") returns non-null binding ──
    (local.set $binding (call $env_lookup (i32.const 4928)))
    (if (i32.eqz (local.get $binding))
      (then
        (call $eprint_string (i32.const 4256))
        (call $eprint_string (i32.const 4192))
        (local.set $failed (i32.const 1)))
      (else
        ;; ── Assert: binding.scheme is a Scheme record (tag 200) ──
        (local.set $scheme (call $env_binding_scheme (local.get $binding)))
        (if (i32.eqz (call $is_scheme (local.get $scheme)))
          (then
            (call $eprint_string (i32.const 4288))
            (call $eprint_string (i32.const 4192))
            (local.set $failed (i32.const 1))))

        ;; ── Assert: scheme.body is a TFun (tag 107) ──
        (local.set $body_ty (call $scheme_body (local.get $scheme)))
        (if (i32.ne (call $ty_tag (local.get $body_ty)) (i32.const 107))
          (then
            (call $eprint_string (i32.const 4320))
            (call $eprint_string (i32.const 4192))
            (local.set $failed (i32.const 1))))

        ;; ── Assert: fn handle NOT bound to NErrorHole (tag 64) ──
        (local.set $g    (call $graph_node_at (local.get $stmt_h)))
        (local.set $kind (call $gnode_kind (local.get $g)))
        (if (i32.eq (call $node_kind_tag (local.get $kind)) (i32.const 64))
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
