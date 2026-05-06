  ;; ═══ walk_stmt_fn_recursive.wat — trace harness ═══════════════════
  ;; Executes: Hβ-infer-substrate.md §4.2 + state.wat §1 fn-stack —
  ;;           FnStmt arm pre-binds the fn name with placeholder Forall
  ;;           BEFORE walking the body, so the body's recursive VarRef
  ;;           resolves through env_lookup mid-walk. Per src/infer.mn:279.
  ;; Setup: synthetic `fn rec(n) = rec` (the body is the simplest
  ;;        possible recursive reference — VarRef("rec")). If the FnStmt
  ;;        arm one-pass'd (walk body before pre-bind), the body's
  ;;        VarRef("rec") would env_lookup miss, emit
  ;;        E_MissingVariable, and bind NErrorHole on the body handle.
  ;;        Two-pass discipline lets the body's lookup hit.
  ;; Verifies: env_lookup("rec") returns non-null binding;
  ;;           binding.scheme is a Scheme; scheme.body is a TFun;
  ;;           the body-VarRef's handle is NOT bound to NErrorHole
  ;;           (the load-bearing assertion: pre-bind worked).
  ;; Exercises: walk_stmt.wat — $infer_walk_stmt_fn (two-pass discipline),
  ;;            $env_extend pre-bind path; walk_expr.wat —
  ;;            $infer_walk_expr_var_ref (the recursive reference);
  ;;            scheme.wat — $generalize at exit; env.wat — $env_lookup
  ;;            mid-body.
  ;;
  ;; ─── Eight interrogations ─────────────────────────────────────────
  ;;   Graph?      $graph_bind on fn handle (pre-bind placeholder TFun);
  ;;               body's VarRef binds the inner handle.
  ;;   Handler?    Direct seed call.
  ;;   Verb?       N/A at stmt level.
  ;;   Row?        Fresh row_h on the TFun.
  ;;   Ownership?  Param has Inferred ownership.
  ;;   Refinement? None.
  ;;   Gradient?   The pre-bind IS the gradient step that lets the body
  ;;               infer; without it the gradient hits NErrorHole.
  ;;   Reason?     Located(span, Declared("rec")) on pre-bind +
  ;;               re-extend; the body VarRef gets Located(span,
  ;;               VarLookup("rec", ...)).

  (data (i32.const 4096) "\05\00\00\00PASS:")
  (data (i32.const 4128) "\05\00\00\00FAIL:")
  (data (i32.const 4160) "\01\00\00\00 ")
  (data (i32.const 4192) "\01\00\00\00\0a")
  (data (i32.const 4224) "\14\00\00\00walk_stmt_fn_recursi")

  (data (i32.const 4256) "\14\00\00\00env-lookup-miss     ")
  (data (i32.const 4288) "\14\00\00\00scheme-not-forall   ")
  (data (i32.const 4320) "\14\00\00\00body-not-tfun       ")
  (data (i32.const 4352) "\14\00\00\00body-handle-errhole ")

  ;; Static name strings
  (data (i32.const 4928) "\03\00\00\00rec")
  (data (i32.const 4944) "\01\00\00\00n")

  (func $_start (export "_start")
    (local $span i32)
    (local $tparam i32) (local $params i32)
    (local $ret_unit_body i32) (local $ret_unit_node i32) (local $ret_unit_h i32)
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

    (local.set $span (call $alloc (i32.const 16)))
    (i32.store          (local.get $span) (i32.const 1))
    (i32.store offset=4 (local.get $span) (i32.const 1))
    (i32.store offset=8 (local.get $span) (i32.const 1))
    (i32.store offset=12 (local.get $span) (i32.const 30))

    ;; ── TParam("n", _, Inferred, Inferred) — parser layout ──
    (local.set $tparam (call $alloc (i32.const 20)))
    (i32.store          (local.get $tparam) (i32.const 190))
    (i32.store offset=4 (local.get $tparam) (i32.const 4944))
    (i32.store offset=8 (local.get $tparam) (i32.const 0))
    (i32.store offset=12 (local.get $tparam) (i32.const 170))
    (i32.store offset=16 (local.get $tparam) (i32.const 170))

    (local.set $params (call $make_list (i32.const 0)))
    (local.set $params (call $list_extend_to (local.get $params) (i32.const 1)))
    (drop (call $list_set (local.get $params) (i32.const 0) (local.get $tparam)))

    ;; ── default ret = NExpr(LitUnit) ──
    (local.set $ret_unit_body (call $alloc (i32.const 8)))
    (i32.store          (local.get $ret_unit_body) (i32.const 110))
    (i32.store offset=4 (local.get $ret_unit_body) (i32.const 84))
    (local.set $ret_unit_h (call $graph_fresh_ty (i32.const 0)))
    (local.set $ret_unit_node (call $alloc (i32.const 16)))
    (i32.store          (local.get $ret_unit_node) (i32.const 0))
    (i32.store offset=4 (local.get $ret_unit_node) (local.get $ret_unit_body))
    (i32.store offset=8 (local.get $ret_unit_node) (local.get $span))
    (i32.store offset=12 (local.get $ret_unit_node) (local.get $ret_unit_h))

    (local.set $effs (call $make_list (i32.const 0)))

    ;; ── body = NExpr(VarRef("rec")) — the recursive reference ──
    (local.set $body_var (call $alloc (i32.const 8)))
    (i32.store          (local.get $body_var) (i32.const 85))
    (i32.store offset=4 (local.get $body_var) (i32.const 4928))
    (local.set $body_body (call $alloc (i32.const 8)))
    (i32.store          (local.get $body_body) (i32.const 110))
    (i32.store offset=4 (local.get $body_body) (local.get $body_var))
    (local.set $body_h (call $graph_fresh_ty (i32.const 0)))
    (local.set $body_node (call $alloc (i32.const 16)))
    (i32.store          (local.get $body_node) (i32.const 0))
    (i32.store offset=4 (local.get $body_node) (local.get $body_body))
    (i32.store offset=8 (local.get $body_node) (local.get $span))
    (i32.store offset=12 (local.get $body_node) (local.get $body_h))

    ;; ── FnStmt(name="rec", params, ret_unit, effs, body) ──
    (local.set $stmt (call $alloc (i32.const 24)))
    (i32.store          (local.get $stmt) (i32.const 121))
    (i32.store offset=4  (local.get $stmt) (i32.const 4928))
    (i32.store offset=8  (local.get $stmt) (local.get $params))
    (i32.store offset=12 (local.get $stmt) (local.get $ret_unit_node))
    (i32.store offset=16 (local.get $stmt) (local.get $effs))
    (i32.store offset=20 (local.get $stmt) (local.get $body_node))

    (local.set $stmt_body (call $alloc (i32.const 8)))
    (i32.store          (local.get $stmt_body) (i32.const 111))
    (i32.store offset=4 (local.get $stmt_body) (local.get $stmt))

    (local.set $stmt_h (call $graph_fresh_ty (i32.const 0)))
    (local.set $stmt_node (call $alloc (i32.const 16)))
    (i32.store          (local.get $stmt_node) (i32.const 0))
    (i32.store offset=4 (local.get $stmt_node) (local.get $stmt_body))
    (i32.store offset=8 (local.get $stmt_node) (local.get $span))
    (i32.store offset=12 (local.get $stmt_node) (local.get $stmt_h))

    ;; ── Walk ──
    (call $infer_stmt (local.get $stmt_node))

    ;; ── Assert: env_lookup("rec") returns binding ──
    (local.set $binding (call $env_lookup (i32.const 4928)))
    (if (i32.eqz (local.get $binding))
      (then
        (call $eprint_string (i32.const 4256))
        (call $eprint_string (i32.const 4192))
        (local.set $failed (i32.const 1)))
      (else
        (local.set $scheme (call $env_binding_scheme (local.get $binding)))
        (if (i32.eqz (call $is_scheme (local.get $scheme)))
          (then
            (call $eprint_string (i32.const 4288))
            (call $eprint_string (i32.const 4192))
            (local.set $failed (i32.const 1))))

        (local.set $body_ty (call $scheme_body (local.get $scheme)))
        (if (i32.ne (call $ty_tag (local.get $body_ty)) (i32.const 107))
          (then
            (call $eprint_string (i32.const 4320))
            (call $eprint_string (i32.const 4192))
            (local.set $failed (i32.const 1))))

        ;; ── Load-bearing: body VarRef's handle NOT NErrorHole ──
        ;; The pre-bind placeholder env_extend lets the body's VarRef
        ;; ("rec") env_lookup hit. If pre-bind was skipped (one-pass
        ;; transcription bug), the body would env_lookup miss and bind
        ;; body_h to NErrorHole.
        (local.set $g    (call $graph_node_at (local.get $body_h)))
        (local.set $kind (call $gnode_kind (local.get $g)))
        (if (i32.eq (call $node_kind_tag (local.get $kind)) (i32.const 64))
          (then
            (call $eprint_string (i32.const 4352))
            (call $eprint_string (i32.const 4192))
            (local.set $failed (i32.const 1))))))

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
