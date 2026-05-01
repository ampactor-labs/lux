  ;; ═══ walk_stmt.wat — statement inference walk (Tier 7) ═══════════════
  ;; Implements: Hβ-infer-substrate.md §3 + §4.2 + §6.3 + §7.2 + §8.1
  ;;             walk_stmt.wat row + §8.4 ~400-line estimate + §11.2 +
  ;;             §13.3 #9 (peer Tier 7 chunk forward-declared from
  ;;             walk_expr.wat:824 BlockExpr arm) +
  ;;             docs/specs/04-inference.md §What the walk produces +
  ;;             docs/specs/03-typed-ast.md (canonical Stmt shape) +
  ;;             canonical wheel src/infer.nx:182-260 (infer_program /
  ;;             infer_stmt_list / infer_stmt) +
  ;;             :262-369 (infer_fn — two-pass discipline) +
  ;;             :2001-2019 (mint_params / build_param_types) +
  ;;             :1587-1592 (infer_pat PVar arm; LetStmt-binding shape) +
  ;;             :2028-2098 (register_type_constructors / register_effect_ops).
  ;;
  ;; Realizes the §4.2 walk projection of primitive #8 (HM inference live +
  ;; productive-under-error + with Reasons — DESIGN.md §0.5) at the seed
  ;; substrate. Every Stmt variant the parser tags 120-128
  ;; (parser_infra.wat:21-23) gets one arm; LetStmt + FnStmt + ExprStmt
  ;; carry full bodies. TypeDefStmt + EffectDeclStmt + HandlerDeclStmt +
  ;; RefineStmt + ImportStmt + Documented are inert seed-stubs with
  ;; explicit named follow-ups (drift mode 9 closure — peer handles, NOT
  ;; silent deferral). Per §7.2 foreign-fluency: ONE walk; no
  ;; bidirectional check-vs-infer split. Per Damas-Milner + walkthrough §12:
  ;; generalize at FnStmt only; LetStmt PVar binding is monomorphic.
  ;;
  ;; Exports:    $infer_stmt_list (BlockExpr arm callsite from
  ;;               walk_expr.wat:824),
  ;;             $infer_stmt (Stmt-tag dispatcher),
  ;;             $infer_walk_stmt_let,
  ;;             $infer_walk_stmt_fn (two-pass discipline — load-bearing),
  ;;             $infer_walk_stmt_typedef,
  ;;             $infer_walk_stmt_effect_decl,
  ;;             $infer_walk_stmt_handler_decl,
  ;;             $infer_walk_stmt_expr,
  ;;             $infer_walk_stmt_import,
  ;;             $infer_walk_stmt_refine,
  ;;             $infer_walk_stmt_documented,
  ;;             $infer_program (toplevel orchestrator)
  ;; Uses:       $alloc (alloc.wat),
  ;;             $str_alloc (str.wat),
  ;;             $make_list / $list_index / $list_set / $list_extend_to /
  ;;               $len (list.wat),
  ;;             $make_record / $record_get / $record_set / $tag_of (record.wat),
  ;;             $graph_init / $graph_fresh_ty / $graph_fresh_row /
  ;;               $graph_bind (graph.wat),
  ;;             $env_init / $env_extend / $env_scope_enter / $env_scope_exit /
  ;;               $schemekind_make_fn (env.wat),
  ;;             $infer_init / $infer_fn_stack_push / $infer_fn_stack_pop
  ;;               (state.wat),
  ;;             $reason_make_located / $reason_make_inferred /
  ;;               $reason_make_declared / $reason_make_letbinding /
  ;;               $reason_make_fnreturn (reason.wat),
  ;;             $ty_make_tvar / $ty_make_tfun (ty.wat),
  ;;             $tparam_make / $ownership_make_inferred (tparam.wat),
  ;;             $scheme_make_forall / $generalize (scheme.wat),
  ;;             $unify (unify.wat),
  ;;             $infer_walk_expr (walk_expr.wat — peer Tier 7).
  ;; Test:       bootstrap/test/infer/walk_stmt_let_simple.wat,
  ;;             bootstrap/test/infer/walk_stmt_fn_monomorphic.wat,
  ;;             bootstrap/test/infer/walk_stmt_fn_recursive.wat,
  ;;             bootstrap/test/infer/walk_stmt_block_with_stmts.wat
  ;;
  ;; ═══ EIGHT INTERROGATIONS (per Hβ-infer-substrate.md §6.3 applied to
  ;;                            walk_stmt.wat per-arm walk) ════════════════
  ;;
  ;; 1. Graph?      Each arm ends in at most ONE $graph_bind on the AST
  ;;                handle. LetStmt binds NOTHING on the let-stmt's own
  ;;                handle — only the embedded value-expr's handle (via
  ;;                $infer_walk_expr) and the bound name's env entry.
  ;;                FnStmt arm binds the fn handle ONCE via $graph_bind on
  ;;                the placeholder TFun, then the body walk + unify
  ;;                resolve through it. $graph_fresh_ty / _row mint param +
  ;;                return + row handles.
  ;; 2. Handler?    Direct seed call. Wheel's @resume=OneShot discipline of
  ;;                $env_extend / $env_scope_enter / _exit / $generalize /
  ;;                $instantiate maps 1-1 onto direct WAT function calls;
  ;;                no resume-state machinery at the seed.
  ;; 3. Verb?       N/A at stmt-list level — stmts are sequential by
  ;;                definition, not verb-drawn. The verbs enter inside
  ;;                $infer_walk_expr (which this chunk delegates to for
  ;;                every stmt body).
  ;; 4. Row?        EffectDeclStmt arm WOULD seed env entries whose schemes
  ;;                carry $graph_fresh_row handles per src/infer.nx:2081-
  ;;                2098 register_effect_ops. Seed-stubbed pending row.wat
  ;;                composition substrate (Hβ.infer.row-normalize +
  ;;                Hβ.infer.effect-ops named follow-ups). FnStmt's own
  ;;                row handle minted via $graph_fresh_row stays opaque —
  ;;                row composition lands later.
  ;; 5. Ownership?  FnStmt body's ref-escape state lives in state.wat's
  ;;                $infer_ref_escape_*; clearing at $env_scope_exit gates
  ;;                on Hβ.infer.ref-escape-fn-exit named follow-up. Param's
  ;;                own/ref annotation (parser TParam offset 12, raw int
  ;;                170/171/172) preserved through the seed bridge into
  ;;                tag-202 TParams via $walk_stmt_build_inferred_params;
  ;;                affine ledger fires inside walk_expr arms (already
  ;;                wired), not here.
  ;; 6. Refinement? RefineStmt arm WOULD construct TAlias(name,
  ;;                TRefined(base, pred)) + emit verify obligation per
  ;;                src/infer.nx:230-235. Seed-stubbed pending parser
  ;;                surfacing the pred record stably (Hβ.infer.refine-stmt
  ;;                named follow-up).
  ;; 7. Gradient?   Each $env_extend with `Forall([], _)` is a monomorphic
  ;;                gradient pin (lower will direct-call); each
  ;;                `Forall([h1,...,hn], _)` is an open gradient (lower
  ;;                will evidence-pass). FnStmt's two-pass discipline
  ;;                (pre-bind placeholder Forall, walk body, generalize,
  ;;                re-extend) IS the gradient's continuous evolution from
  ;;                "fn declared" → "fn body inferred" → "fn scheme
  ;;                generalized".
  ;; 8. Reason?     Every $env_extend's reason is a non-trivial Reason
  ;;                chain. FnStmt: $reason_make_located(span,
  ;;                $reason_make_declared(name)) matching src/infer.nx:280.
  ;;                LetStmt PVar arm: $reason_make_located(span,
  ;;                $reason_make_letbinding(name,
  ;;                  $reason_make_inferred("pattern"))) matching
  ;;                src/infer.nx:1589-1591. FnStmt body unify uses
  ;;                $reason_make_fnreturn(name,
  ;;                  $reason_make_inferred("return")) matching :289.
  ;;
  ;; ═══ FORBIDDEN PATTERNS AUDIT (per Hβ-infer-substrate.md §7.2 +
  ;;                                applied to walk_stmt.wat) ═════════════
  ;;
  ;; - Drift 1 (Rust vtable):           NO closure-array indexed by Stmt
  ;;                                    tag. $infer_stmt dispatches via
  ;;                                    direct (if (i32.eq tag K)) chain.
  ;;                                    The chain IS the variant
  ;;                                    enumeration.
  ;; - Drift 2 (Scheme env frame):      env.wat owns scope state. NO
  ;;                                    sidecar `current_env` parameter
  ;;                                    threaded through stmt arms.
  ;; - Drift 3 (Python dict):           Stmt tags are integer constants
  ;;                                    (120-128 per parser_infra.wat:21-
  ;;                                    23). Reason-ctx strings live in
  ;;                                    data-segment offsets passed as
  ;;                                    string ptrs to
  ;;                                    $reason_make_inferred; NOT
  ;;                                    $str_eq enum dispatch.
  ;; - Drift 4 (Haskell monad transformer): NO $walk_stmt_M_bind /
  ;;                                    $walk_stmt_M_return. infer_stmt_list
  ;;                                    iterates a flat list and calls
  ;;                                    $infer_stmt on each entry; pure
  ;;                                    WAT iteration over the list
  ;;                                    payload.
  ;; - Drift 5 (C calling convention):  Each arm takes
  ;;                                    (param $stmt i32) (param $handle i32)
  ;;                                    (param $span i32) — three i32s.
  ;;                                    NO bundled context-struct + state
  ;;                                    ptr.
  ;; - Drift 6 (primitive special-case): LetStmt is NOT special. It's one
  ;;                                    of nine arms. FnStmt is NOT a
  ;;                                    fast-path; it follows the same
  ;;                                    dispatch shape as the others.
  ;; - Drift 7 (parallel-arrays):       Schemes are 2-field records
  ;;                                    (scheme.wat). Bindings are 4-field
  ;;                                    records (env.wat). FnStmt's
  ;;                                    param_handles is one flat list of
  ;;                                    i32; tparam_list is one flat list
  ;;                                    of tag-202 TParam records — single
  ;;                                    list, NOT (handles[], names[])
  ;;                                    parallel.
  ;; - Drift 8 (mode flag / string-keyed): Stmt arm dispatch via integer
  ;;                                    tag (120-128); NEVER on
  ;;                                    `kind == "let"` / `kind == "fn"`.
  ;;                                    Pat tag dispatch (PVar=130) via
  ;;                                    integer (parser_infra.wat:24).
  ;;                                    Ownership annotations preserved as
  ;;                                    integer tags 170/171/172 passed
  ;;                                    to $ownership_make_inferred /
  ;;                                    _own / _ref constructors; NEVER
  ;;                                    string-keyed mode dispatch.
  ;; - Drift 9 (deferred-by-omission):  EVERY Stmt tag (120-128) gets an
  ;;                                    arm. TypeDefStmt + EffectDeclStmt +
  ;;                                    HandlerDeclStmt + RefineStmt +
  ;;                                    Documented land as inert seed-
  ;;                                    stubs with explicit
  ;;                                    Hβ.infer.constructors /
  ;;                                    .effect-ops / .handler-decls /
  ;;                                    .refine-stmt / .docstring-reason
  ;;                                    named follow-ups (see below).
  ;;                                    Each follow-up is a peer handle,
  ;;                                    NOT silent deferral.
  ;;
  ;; - Foreign fluency — type-check vs. infer split: NO $check_stmt peer;
  ;;                                    ONE $infer_stmt. Per §7.2 + spec
  ;;                                    04 §Three operations.
  ;; - Foreign fluency — let-generalization at let-stmt: NO. Per
  ;;                                    walkthrough §12 + Damas-Milner +
  ;;                                    src/infer.nx:1588-1591: PVar binds
  ;;                                    Forall([], TVar(eh)) —
  ;;                                    monomorphic. Generalization
  ;;                                    happens ONLY at FnStmt exit.
  ;; - Foreign fluency — pre-resolution of recursive fn: YES. Per
  ;;                                    src/infer.nx:279, the fn name is
  ;;                                    bound BEFORE walking the body so
  ;;                                    `fact(n - 1)` inside the body
  ;;                                    resolves. The arm SHAPE here is
  ;;                                    a two-pass discipline: pre-bind
  ;;                                    placeholder Forall, walk body,
  ;;                                    generalize, re-extend. One-pass
  ;;                                    transcription would fail
  ;;                                    recursive fns to typecheck
  ;;                                    (drift mode 9).
  ;;
  ;; ═══ TAG REGION ═══════════════════════════════════════════════════════
  ;;
  ;; This chunk introduces NO new tags. It dispatches on:
  ;;   parser_infra.wat:14-19  Expr variants  80-101 (delegated to walk_expr)
  ;;   parser_infra.wat:20     NodeBody       110/111 (NExpr / NStmt)
  ;;   parser_infra.wat:21-23  Stmt           120-128 (LetStmt..Documented)
  ;;   parser_infra.wat:24     Pat            130 (PVar; PWild..PRecord
  ;;                                              gate on Hβ.infer.walk_pat)
  ;;   parser_infra.wat:29     Ownership      170-172 (Inferred/Own/Ref)
  ;;   reason.wat              Reason         220-242
  ;;   tparam.wat              TParam         202 + Ownership 260-262
  ;;   scheme.wat              SCHEME         200
  ;;
  ;; ═══ NAMED FOLLOW-UPS (per Drift 9 + Hβ-infer §12) ═══════════════════
  ;;
  ;; - Hβ.infer.constructors: TypeDefStmt arm seed-stub. Wheel's
  ;;   register_type_constructors (src/infer.nx:2028-2066) iterates
  ;;   variants + env_extends each ConstructorScheme(tag_id, total). Seed
  ;;   landing gates on parser_decl.wat:30-118 variant emission stabilizing
  ;;   the variant-record offset shape.
  ;; - Hβ.infer.effect-ops: EffectDeclStmt arm seed-stub. Wheel's
  ;;   register_effect_ops (src/infer.nx:2081-2098) registers each op as
  ;;   Forall([], TFun(params, ret, mk_ef_closed([ENamed(eff)]))) under
  ;;   EffectOpScheme(eff). Seed landing gates on row.wat sibling for
  ;;   mk_ef_closed substrate.
  ;; - Hβ.infer.handler-decls: HandlerDeclStmt arm seed-stub. Wheel's
  ;;   register_handler (src/infer.nx:2100-2109) env-extends with
  ;;   TName("Handler", [TName(eff)]) under FnScheme. Seed landing gates
  ;;   on parser surfacing the handler-decl record shape stably.
  ;; - Hβ.infer.refine-stmt: RefineStmt arm seed-stub. Wheel
  ;;   (src/infer.nx:230-235) constructs TAlias(name, TRefined(base, pred))
  ;;   + emits verify obligation. Verify.wat substrate already exists;
  ;;   landing gates on parser surfacing the pred ADT.
  ;; - Hβ.infer.docstring-reason: Documented arm seed-stub (parser doesn't
  ;;   emit Documented today; lands pre-DS.3). Same handle walk_expr.wat
  ;;   named at its line 243.
  ;; - Hβ.infer.fn-stmt-param-names: parser TParam tag 190 carries the
  ;;   real param name at offset 4; FnStmt arm preserves it via
  ;;   $env_extend(param_name, ...). The substrate TParam tag 202
  ;;   constructed by $walk_stmt_build_inferred_params uses anon names
  ;;   (empty string) per the seed bridge; full name preservation through
  ;;   the substrate tparam record lands when emit_diag.wat's $render_ty
  ;;   needs them per the renderer's TParam recursion.
  ;; - Hβ.infer.ref-escape-fn-exit: FnStmt arm currently leaves
  ;;   $infer_ref_escape state untouched at scope_exit. Wheel
  ;;   (src/infer.nx:296) walks the ref-escape candidates against the
  ;;   return position via $infer_ref_escape_check_at_return. Lands when
  ;;   the seed has return-position substrate (currently parser emits
  ;;   LitUnit at offset 12, opaque to seed).
  ;; - Hβ.infer.declared-effs-enforcement: FnStmt's parser-level effs
  ;;   list (offset 16) currently empty. Wheel (src/infer.nx:298-362)
  ;;   subsumes the inferred row against the declared row; lands when
  ;;   row.wat's $row_subsumes substrate matures.
  ;; - Hβ.infer.toplevel-pre-register: $infer_program seed walks stmts
  ;;   in declared order. Wheel (src/infer.nx:96-149)
  ;;   pre_register_fn_sigs walks all FnStmts FIRST with placeholder
  ;;   schemes so forward-references resolve. Lands when first src/*.nx
  ;;   breaks the topological ordering (currently src/*.nx satisfies it).
  ;; - Hβ.infer.fnstmt-ret-annotation: FnStmt offset 12 (parser ret) is
  ;;   currently parsed as LitUnit-N when no annotation is present;
  ;;   when an explicit return type is given the wheel
  ;;   (src/infer.nx:286-289) unifies it against ret_h. Lands when
  ;;   parse_fn_stmt surfaces the annotation handle vs sentinel.

  ;; ─── Data segment — Reason-inner string fragments ────────────────────
  ;;
  ;; Offsets ≥ 4032 to sit above walk_expr.wat's last segment (4008 +
  ;; 10-byte payload incl. 4-byte length prefix = 4018 high-water; 14-byte
  ;; safety gap). Below HEAP_BASE = 4096 per CLAUDE.md memory model.
  ;; Length-prefix uses the actual byte count of the payload per emit_diag
  ;; lessons.
  ;;
  ;; NOTE: "return" already exists at walk_expr.wat:285 (offset 3672) and
  ;; "effects" at walk_expr.wat:286 (offset 3696). Cross-chunk data offset
  ;; reuse couples the two chunks tightly; for the seed declare fresh
  ;; copies here. Drift-audit on duplicate identical content does not fire.

  (data (i32.const 4032) "\07\00\00\00pattern")              ;;  7 bytes
  (data (i32.const 4048) "\02\00\00\00fn")                   ;;  2 bytes
  (data (i32.const 4056) "\05\00\00\00param")                ;;  5 bytes
  (data (i32.const 4064) "\06\00\00\00return")               ;;  6 bytes
  (data (i32.const 4080) "\07\00\00\00effects")              ;;  7 bytes

  ;; ─── Private helpers ─────────────────────────────────────────────────

  ;; $walk_stmt_node_handle(N) — extract handle (offset 12) from the N
  ;; record (parser_infra.wat:32-39 layout: [tag=0][body][span][handle]).
  (func $walk_stmt_node_handle (param $n i32) (result i32)
    (i32.load offset=12 (local.get $n)))

  ;; $walk_stmt_node_span(N) — extract span (offset 8) from the N record.
  (func $walk_stmt_node_span (param $n i32) (result i32)
    (i32.load offset=8 (local.get $n)))

  ;; $walk_stmt_node_body(N) — extract body (offset 4) from the N record.
  (func $walk_stmt_node_body (param $n i32) (result i32)
    (i32.load offset=4 (local.get $n)))

  ;; $walk_stmt_stmt_tag(stmt) — get the Stmt variant tag (120-128).
  ;; Stmt records always heap-allocated; $tag_of dispatches through the
  ;; heap path per record.wat:49 precedent.
  (func $walk_stmt_stmt_tag (param $stmt i32) (result i32)
    (call $tag_of (local.get $stmt)))

  ;; $walk_stmt_build_inferred_params(arg_handles) — for each handle h,
  ;; build TParam(name=anon, ty=TVar(h), authored=Inferred,
  ;; resolved=Inferred). Mirrors src/infer.nx:2021-2026
  ;; build_inferred_params + walk_expr.wat:365
  ;; $walk_expr_build_inferred_params (which is private to that chunk —
  ;; per Anchor 4 we duplicate rather than cross-chunk private export).
  (func $walk_stmt_build_inferred_params (param $arg_handles i32) (result i32)
    (local $n i32) (local $i i32) (local $buf i32)
    (local $h i32) (local $tparam i32) (local $anon i32)
    (local.set $anon (call $str_alloc (i32.const 0)))   ;; empty string
    (local.set $n (call $len (local.get $arg_handles)))
    (local.set $buf (call $make_list (i32.const 0)))
    (local.set $buf (call $list_extend_to (local.get $buf) (local.get $n)))
    (local.set $i (i32.const 0))
    (block $done
      (loop $each
        (br_if $done (i32.ge_u (local.get $i) (local.get $n)))
        (local.set $h (call $list_index (local.get $arg_handles) (local.get $i)))
        (local.set $tparam (call $tparam_make
          (local.get $anon)
          (call $ty_make_tvar (local.get $h))
          (call $ownership_make_inferred)
          (call $ownership_make_inferred)))
        (drop (call $list_set (local.get $buf) (local.get $i) (local.get $tparam)))
        (local.set $i (i32.add (local.get $i) (i32.const 1)))
        (br $each)))
    (local.get $buf))

  ;; ─── Toplevel FnStmt pre-registration ─────────────────────────────
  ;;
  ;; Before statement inference walks bodies, every top-level function
  ;; name is visible in env with a placeholder TFun. Forward calls then
  ;; unify against the declaration handle instead of emitting
  ;; E_MissingVariable. The later FnStmt arm unifies this placeholder
  ;; with the body-derived type before re-binding the handle.
  (func $infer_pre_register_fn_sig
        (param $stmt i32) (param $handle i32) (param $span i32)
    (local $name i32) (local $params i32)
    (local $n_params i32) (local $i i32)
    (local $param_h i32) (local $param_handles i32)
    (local $ret_h i32) (local $row_h i32)
    (local $tparam_list i32) (local $fn_ty i32)
    (local $reason i32)
    ;; FnStmt: [tag=121][name][params][ret][effs][body]
    (local.set $name   (i32.load offset=4 (local.get $stmt)))
    (local.set $params (i32.load offset=8 (local.get $stmt)))

    (local.set $param_handles (call $make_list (i32.const 0)))
    (local.set $n_params (call $len (local.get $params)))
    (local.set $param_handles
      (call $list_extend_to (local.get $param_handles) (local.get $n_params)))
    (local.set $i (i32.const 0))
    (block $params_done
      (loop $each_param
        (br_if $params_done (i32.ge_u (local.get $i) (local.get $n_params)))
        (local.set $param_h (call $graph_fresh_ty
          (call $reason_make_located (local.get $span)
            (call $reason_make_inferred (i32.const 4056)))))   ;; "param"
        (drop (call $list_set (local.get $param_handles) (local.get $i)
                              (local.get $param_h)))
        (local.set $i (i32.add (local.get $i) (i32.const 1)))
        (br $each_param)))

    (local.set $ret_h (call $graph_fresh_ty
      (call $reason_make_located (local.get $span)
        (call $reason_make_inferred (i32.const 4064)))))   ;; "return"
    (local.set $row_h (call $graph_fresh_row
      (call $reason_make_located (local.get $span)
        (call $reason_make_inferred (i32.const 4080)))))   ;; "effects"
    (local.set $tparam_list
      (call $walk_stmt_build_inferred_params (local.get $param_handles)))
    (local.set $fn_ty (call $ty_make_tfun
      (local.get $tparam_list)
      (call $ty_make_tvar (local.get $ret_h))
      (local.get $row_h)))
    (local.set $reason (call $reason_make_located
      (local.get $span)
      (call $reason_make_declared (local.get $name))))
    (call $graph_bind (local.get $handle) (local.get $fn_ty)
                      (local.get $reason))
    ;; Pre-registered fn_ty is fully polymorphic — quantify over every
    ;; fresh handle so each call site instantiates fresh TVars rather
    ;; than mutating the placeholder. Mirrors generalize() at fn-stmt
    ;; exit; here the body hasn't walked yet so the quantifier is
    ;; literally [param_handles..., ret_h, row_h].
    (call $env_extend
      (local.get $name)
      (call $scheme_make_forall
        (call $infer_pre_register_quantifier
          (local.get $param_handles) (local.get $ret_h) (local.get $row_h))
        (local.get $fn_ty))
      (local.get $reason)
      (call $schemekind_make_fn)))

  ;; $infer_pre_register_quantifier: cons each param handle, ret handle,
  ;; and row handle into one List<i32>. Quantifying over all of them
  ;; means every call-site instantiation produces fresh TVars per the
  ;; Forall→fresh-substitution discipline of $instantiate.
  (func $infer_pre_register_quantifier
        (param $param_handles i32) (param $ret_h i32) (param $row_h i32)
        (result i32)
    (local $n i32) (local $out i32) (local $i i32)
    (local.set $n (call $len (local.get $param_handles)))
    (local.set $out
      (call $list_extend_to (call $make_list (i32.const 0))
                            (i32.add (local.get $n) (i32.const 2))))
    (local.set $i (i32.const 0))
    (block $copy_done
      (loop $copy
        (br_if $copy_done (i32.ge_u (local.get $i) (local.get $n)))
        (drop (call $list_set (local.get $out) (local.get $i)
          (call $list_index (local.get $param_handles) (local.get $i))))
        (local.set $i (i32.add (local.get $i) (i32.const 1)))
        (br $copy)))
    (drop (call $list_set (local.get $out) (local.get $n) (local.get $ret_h)))
    (drop (call $list_set (local.get $out)
                          (i32.add (local.get $n) (i32.const 1))
                          (local.get $row_h)))
    (local.get $out))

  (func $infer_pre_register_stmt (param $node i32)
    (local $body i32) (local $stmt i32) (local $tag i32)
    (local $handle i32) (local $span i32) (local $inner_node i32)
    (local.set $body   (call $walk_stmt_node_body   (local.get $node)))
    (local.set $span   (call $walk_stmt_node_span   (local.get $node)))
    (local.set $handle (call $walk_stmt_node_handle (local.get $node)))
    (if (i32.ne (i32.load (local.get $body)) (i32.const 111))
      (then (return)))
    (local.set $stmt (i32.load offset=4 (local.get $body)))
    (local.set $tag (call $walk_stmt_stmt_tag (local.get $stmt)))
    (if (i32.eq (local.get $tag) (i32.const 121))
      (then
        (call $infer_pre_register_fn_sig
          (local.get $stmt) (local.get $handle) (local.get $span))
        (return)))
    (if (i32.eq (local.get $tag) (i32.const 122))
      (then
        (call $infer_register_typedef_ctors
          (i32.load offset=4 (local.get $stmt))
          (i32.load offset=12 (local.get $stmt))
          (local.get $span))
        (return)))
    (if (i32.eq (local.get $tag) (i32.const 123))
      (then
        (call $infer_register_effect_ops
          (i32.load offset=4 (local.get $stmt))
          (i32.load offset=8 (local.get $stmt))
          (local.get $span))
        (return)))
    (if (i32.eq (local.get $tag) (i32.const 124))
      (then
        (call $infer_walk_stmt_handler_decl
          (local.get $stmt) (local.get $handle) (local.get $span))
        (return)))
    (if (i32.eq (local.get $tag) (i32.const 128))
      (then
        ;; Documented(doc, inner_node): inner Node at offset 8.
        (local.set $inner_node (i32.load offset=8 (local.get $stmt)))
        (call $infer_pre_register_stmt (local.get $inner_node)))))

  (func $infer_pre_register_fn_sigs (param $stmts i32)
    (local $n i32) (local $i i32) (local $stmt_node i32)
    (local.set $n (call $len (local.get $stmts)))
    (local.set $i (i32.const 0))
    (block $done
      (loop $each
        (br_if $done (i32.ge_u (local.get $i) (local.get $n)))
        (local.set $stmt_node (call $list_index (local.get $stmts) (local.get $i)))
        (call $infer_pre_register_stmt (local.get $stmt_node))
        (local.set $i (i32.add (local.get $i) (i32.const 1)))
        (br $each))))

  ;; ─── Per-Stmt-variant arms ───────────────────────────────────────────

  ;; LetStmt arm (tag 120) — src/infer.nx:200-204 + 1588-1592.
  ;; Layout: [tag=120][pat][val] per parser_infra.wat:163.
  ;; Walk the value expression; delegate to $infer_walk_pat (B.5 landed)
  ;; for all Pat variants: PVar binding, PWild no-op, PLit constraint,
  ;; PCon constructor destructure, PTuple, PList. PRecord deferred.
  ;;
  ;; Per walkthrough §12 + Damas-Milner + src/infer.nx:1588-1591: PVar
  ;; binds Forall([], TVar(eh)) — MONOMORPHIC. Generalization happens at
  ;; FnStmt only. NEVER call $generalize here.
  (func $infer_walk_stmt_let
        (export "infer_walk_stmt_let")
        (param $stmt i32) (param $handle i32) (param $span i32)
    (local $pat i32) (local $val i32) (local $eh i32)
    ;; Layout: [tag=120][pat][val]
    (local.set $pat (i32.load offset=4 (local.get $stmt)))
    (local.set $val (i32.load offset=8 (local.get $stmt)))
    (drop (local.get $handle))   ;; LetStmt has no own bound type at the
                                  ;; seed — the pat handles or the embedded
                                  ;; expr handle carry the type info.
    ;; Walk the value expression (mutates graph, returns expr's handle).
    (local.set $eh (call $infer_walk_expr (local.get $val)))
    ;; Walk pattern via $infer_walk_pat (B.5 landed). Handles all Pat
    ;; variants: PVar (binding), PWild (no-op), PLit (type constraint),
    ;; PCon (constructor destructure), PTuple, PList. Per Damas-Milner:
    ;; all bindings monomorphic Forall([], TVar(scrut_h)). Generalization
    ;; happens ONLY at FnStmt exit — NEVER here.
    (call $infer_walk_pat (local.get $pat) (local.get $eh) (local.get $span))
    )

  ;; FnStmt arm (tag 121) — src/infer.nx:206-210 + infer_fn 262-369.
  ;; Layout: [tag=121][name][params][ret][effs][body] per
  ;; parser_infra.wat:171-179.
  ;;
  ;; Two-pass discipline (the load-bearing surface): push fn handle onto
  ;; inference stack, enter scope, mint per-param handles + env-extend
  ;; each name, mint return + row handles, build placeholder TFun,
  ;; $graph_bind fn handle + pre-extend env (so recursive calls resolve
  ;; mid-body), $infer_walk_expr body, $unify body_h ↔ ret_h,
  ;; $env_scope_exit, $generalize, re-extend env with generalized scheme,
  ;; pop fn from stack.
  ;;
  ;; Seed-stubs (Drift 9 closure — peer follow-ups named in header):
  ;;   - inf_set_declared / declared-effs enforcement: omitted at seed
  ;;     per Hβ.infer.declared-effs-enforcement.
  ;;   - param-name preservation through substrate TParam: parser TParam
  ;;     tag 190 carries name at offset 4; substrate TParam built via
  ;;     $walk_stmt_build_inferred_params uses anon names per
  ;;     Hβ.infer.fn-stmt-param-names.
  ;;   - check_escape (src/infer.nx:296): omitted at seed per
  ;;     Hβ.infer.ref-escape-fn-exit.
  (func $infer_walk_stmt_fn
        (export "infer_walk_stmt_fn")
        (param $stmt i32) (param $handle i32) (param $span i32)
    (local $name i32) (local $params i32) (local $body_node i32)
    (local $n_params i32) (local $i i32) (local $param i32) (local $param_name i32)
    (local $param_h i32) (local $param_handles i32)
    (local $ret_h i32) (local $row_h i32)
    (local $tparam i32) (local $param_ty i32)
    (local $tparam_list i32) (local $fn_ty i32) (local $placeholder_scheme i32)
    (local $declared_reason i32)
    (local $existing_g i32) (local $existing_kind i32)
    (local $existing_tag i32) (local $existing_ty i32)
    (local $body_h i32)
    (local $generalized_scheme i32)
    ;; Layout: [tag=121][name][params][ret][effs][body]
    (local.set $name      (i32.load offset=4  (local.get $stmt)))
    (local.set $params    (i32.load offset=8  (local.get $stmt)))
    ;; offset 12 = ret  (parser-LitUnit-N currently — opaque to seed
    ;;                   per Hβ.infer.fnstmt-ret-annotation follow-up)
    ;; offset 16 = effs (parser empty-list currently — opaque to seed
    ;;                   per Hβ.infer.declared-effs-enforcement)
    (local.set $body_node (i32.load offset=20 (local.get $stmt)))

    ;; Push fn handle onto inference stack so $generalize knows current
    ;; quantification scope (state.wat substrate; consumed by future
    ;; Hβ.infer.scope-aware-generalize follow-up — at the seed
    ;; $generalize uses chase + $free_in_ty so the stack is bookkeeping).
    (call $infer_fn_stack_push (local.get $handle))

    ;; Enter fn-body scope. Param env-extends + body's let-extends live
    ;; in this scope; on exit they all go out.
    (call $env_scope_enter)

    ;; If pre-registered, extract existing. Otherwise mint.
    (local.set $existing_g (call $graph_chase (local.get $handle)))
    (local.set $existing_kind (call $gnode_kind (local.get $existing_g)))
    (local.set $existing_tag (call $node_kind_tag (local.get $existing_kind)))
    (if (i32.eq (local.get $existing_tag) (i32.const 60))   ;; NBOUND
      (then
        (local.set $fn_ty (call $node_kind_payload (local.get $existing_kind)))
        (local.set $tparam_list (call $ty_tfun_params (local.get $fn_ty)))
        (local.set $ret_h (call $ty_tvar_handle (call $ty_tfun_return (local.get $fn_ty))))
        (local.set $row_h (call $ty_tfun_row (local.get $fn_ty)))
        
        ;; Extend env with extracted params
        (local.set $n_params (call $len (local.get $params)))
        (local.set $i (i32.const 0))
        (block $params_done_ex
          (loop $each_param_ex
            (br_if $params_done_ex (i32.ge_u (local.get $i) (local.get $n_params)))
            (local.set $param (call $list_index (local.get $params) (local.get $i)))
            (local.set $param_name (i32.load offset=4 (local.get $param)))
            (local.set $tparam (call $list_index (local.get $tparam_list) (local.get $i)))
            (call $env_extend
              (local.get $param_name)
              (call $scheme_make_forall
                (call $make_list (i32.const 0))
                (call $tparam_ty (local.get $tparam)))
              (call $reason_make_located
                (local.get $span)
                (call $reason_make_declared (local.get $param_name)))
              (call $schemekind_make_fn))
            (local.set $i (i32.add (local.get $i) (i32.const 1)))
            (br $each_param_ex)))
      )
      (else
        ;; Not pre-registered (e.g. nested). Mint fresh.
        (local.set $param_handles (call $make_list (i32.const 0)))
        (local.set $n_params (call $len (local.get $params)))
        (local.set $param_handles
          (call $list_extend_to (local.get $param_handles) (local.get $n_params)))
        (local.set $i (i32.const 0))
        (block $params_done_mint
          (loop $each_param_mint
            (br_if $params_done_mint (i32.ge_u (local.get $i) (local.get $n_params)))
            (local.set $param (call $list_index (local.get $params) (local.get $i)))
            (local.set $param_name (i32.load offset=4 (local.get $param)))
            (local.set $param_h (call $graph_fresh_ty
              (call $reason_make_located (local.get $span)
                (call $reason_make_inferred (i32.const 4056)))))   ;; "param"
            (drop (call $list_set (local.get $param_handles) (local.get $i)
                                  (local.get $param_h)))
            (call $env_extend
              (local.get $param_name)
              (call $scheme_make_forall
                (call $make_list (i32.const 0))
                (call $ty_make_tvar (local.get $param_h)))
              (call $reason_make_located
                (local.get $span)
                (call $reason_make_declared (local.get $param_name)))
              (call $schemekind_make_fn))
            (local.set $i (i32.add (local.get $i) (i32.const 1)))
            (br $each_param_mint)))

        (local.set $ret_h (call $graph_fresh_ty
          (call $reason_make_located (local.get $span)
            (call $reason_make_inferred (i32.const 4064)))))   ;; "return"
        (local.set $row_h (call $graph_fresh_row
          (call $reason_make_located (local.get $span)
            (call $reason_make_inferred (i32.const 4080)))))   ;; "effects"

        (local.set $tparam_list
          (call $walk_stmt_build_inferred_params (local.get $param_handles)))
        (local.set $fn_ty (call $ty_make_tfun
          (local.get $tparam_list)
          (call $ty_make_tvar (local.get $ret_h))
          (local.get $row_h)))
        (local.set $declared_reason (call $reason_make_located
          (local.get $span)
          (call $reason_make_declared (local.get $name))))
        (call $graph_bind (local.get $handle) (local.get $fn_ty)
                          (local.get $declared_reason))

        ;; Pre-extend env with placeholder Forall
        (local.set $placeholder_scheme (call $scheme_make_forall
          (call $make_list (i32.const 0))
          (local.get $fn_ty)))
        (call $env_extend
          (local.get $name) (local.get $placeholder_scheme)
          (local.get $declared_reason)
          (call $schemekind_make_fn))
      )
    )

    ;; ─── Walk fn body ────────────────────────────────────────────────
    (local.set $body_h (call $infer_walk_expr (local.get $body_node)))
    ;; Body's type unifies with declared return per src/infer.nx:289
    ;; unify(body_handle, ret_handle, span, FnReturn(name,
    ;;                                              Inferred("body"))).
    (call $unify
      (local.get $body_h) (local.get $ret_h) (local.get $span)
      (call $reason_make_fnreturn (local.get $name)
        (call $reason_make_inferred (i32.const 4064))))   ;; "return"

    ;; ─── Exit scope, generalize, re-extend env ───────────────────────
    (call $env_scope_exit)
    (local.set $generalized_scheme (call $generalize (local.get $handle)))
    (call $env_extend
      (local.get $name) (local.get $generalized_scheme)
      (local.get $declared_reason)
      (call $schemekind_make_fn))

    ;; Pop fn handle from inference stack.
    (call $infer_fn_stack_pop))

  ;; ─── parser-Ty → infer-Ty translator ────────────────────────────
  ;; Per parser_fn.wat:36-37 + parser_decl.wat the parser emits one of:
  ;;   sentinel 200 TyInt    → $ty_make_tint
  ;;   sentinel 201 TyFloat  → $ty_make_tfloat
  ;;   sentinel 202 TyString → $ty_make_tstring
  ;;   sentinel 204 TyUnit   → $ty_make_tunit
  ;;   tag-205 record TyName(name)  → $ty_make_tname(name, [])
  ;;   tag-206 record TyVar(handle) → $ty_make_tvar(fresh handle)
  ;;
  ;; Seed handles monomorphic types directly. Polymorphic generics
  ;; (Tree<A>, List<A>, Option<A>) defer to peer cascade
  ;; `Hβ-infer-constructors-generics.md` post-L1 — when first src/*.nx
  ;; site exercises generic constructor instantiation that needs proper
  ;; TVar handling beyond the productive-under-error fallback below.
  (func $walk_stmt_parser_ty_to_ty (param $pty i32) (result i32)
    (local $tag i32) (local $fields i32)
    (if (i32.eq (local.get $pty) (i32.const 200))
      (then (return (call $ty_make_tint))))
    (if (i32.eq (local.get $pty) (i32.const 201))
      (then (return (call $ty_make_tfloat))))
    (if (i32.eq (local.get $pty) (i32.const 202))
      (then (return (call $ty_make_tstring))))
    (if (i32.eq (local.get $pty) (i32.const 204))
      (then (return (call $ty_make_tunit))))
    ;; Heap-allocated record — read tag from offset 0.
    (local.set $tag (i32.load (local.get $pty)))
    ;; tag=205 TyName(name) — extract name + build TName(name, [])
    (if (i32.eq (local.get $tag) (i32.const 205))
      (then (return (call $ty_make_tname
        (i32.load offset=4 (local.get $pty))
        (call $make_list (i32.const 0))))))
    ;; tag=206 TyVar — fresh TVar via graph (productive-under-error
    ;; ignores the parser's variable name; future generics work will
    ;; thread the name through tparam.wat substrate).
    (if (i32.eq (local.get $tag) (i32.const 206))
      (then (return (call $ty_make_tvar
        (call $graph_fresh_ty
          (call $reason_make_inferred (i32.const 4056)))))))   ;; "param"
    ;; tag=207 TyRecord(fields) — convert each (name, parser-Ty)
    ;; field pair into the canonical TRecord field-list shape.
    (if (i32.eq (local.get $tag) (i32.const 207))
      (then
        (local.set $fields
          (call $walk_stmt_parser_record_fields_to_ty_fields
            (i32.load offset=4 (local.get $pty))))
        (return (call $ty_make_trecord (local.get $fields)))))
    ;; Unknown shape — productive-under-error: fresh TVar.
    (call $ty_make_tvar
      (call $graph_fresh_ty
        (call $reason_make_inferred (i32.const 4056)))))

  ;; ─── parser record fields → canonical Ty field pairs ─────────────
  ;; Parser record fields are list entries shaped as 2-tuples
  ;; (name, parser-Ty). Convert only the Ty slot; preserve the field
  ;; name as the graph-visible record label.
  (func $walk_stmt_parser_record_fields_to_ty_fields
        (param $fields i32) (result i32)
    (local $n i32) (local $i i32) (local $out i32)
    (local $field i32) (local $name i32) (local $pty i32)
    (local $ty i32) (local $pair i32)
    (local.set $n (call $len (local.get $fields)))
    (local.set $out (call $list_extend_to
      (call $make_list (local.get $n))
      (local.get $n)))
    (local.set $i (i32.const 0))
    (block $done
      (loop $iter
        (br_if $done (i32.ge_u (local.get $i) (local.get $n)))
        (local.set $field
          (call $list_index (local.get $fields) (local.get $i)))
        (local.set $name (call $list_index (local.get $field) (i32.const 0)))
        (local.set $pty  (call $list_index (local.get $field) (i32.const 1)))
        (local.set $ty (call $walk_stmt_parser_ty_to_ty (local.get $pty)))
        (local.set $pair (call $make_list (i32.const 2)))
        (drop (call $list_set (local.get $pair) (i32.const 0) (local.get $name)))
        (drop (call $list_set (local.get $pair) (i32.const 1) (local.get $ty)))
        (drop (call $list_set (local.get $out) (local.get $i) (local.get $pair)))
        (local.set $i (i32.add (local.get $i) (i32.const 1)))
        (br $iter)))
    (local.get $out))

  ;; ─── $walk_stmt_build_field_tparams — parser field-tys → List<TParam> ──
  ;; Per parser_decl.wat:60-63 each variant 2-tuple is (vname,
  ;; field_types). field_types is a List<parser-Ty>; convert each
  ;; into a TParam record per spec 02:55-58 + ty.wat:305 — TFun's
  ;; params field MUST be List<TParam>, not List<Ty>. Constructor
  ;; field params have no name (positional) and Inferred ownership;
  ;; the name slot becomes empty-string per str_alloc(0).
  (func $walk_stmt_build_field_tparams (param $field_tys i32) (result i32)
    (local $n i32) (local $i i32) (local $out i32)
    (local $pty i32) (local $ty i32) (local $tp i32) (local $empty_name i32)
    (local.set $n (call $len (local.get $field_tys)))
    (local.set $out (call $list_extend_to
      (call $make_list (local.get $n))
      (local.get $n)))
    (local.set $empty_name (call $str_alloc (i32.const 0)))
    (local.set $i (i32.const 0))
    (block $done
      (loop $iter
        (br_if $done (i32.ge_u (local.get $i) (local.get $n)))
        (local.set $pty
          (call $list_index (local.get $field_tys) (local.get $i)))
        (local.set $ty (call $walk_stmt_parser_ty_to_ty (local.get $pty)))
        (local.set $tp (call $tparam_make
          (local.get $empty_name)
          (local.get $ty)
          (call $ownership_make_inferred)
          (call $ownership_make_inferred)))
        (drop (call $list_set (local.get $out) (local.get $i) (local.get $tp)))
        (local.set $i (i32.add (local.get $i) (i32.const 1)))
        (br $iter)))
    (local.get $out))

  ;; ─── TypeDefStmt arm (tag 122) — Phase B.2 ultimate-form substrate ──
  ;;
  ;; Per src/infer.nx:212-213 + register_type_constructors 2028-2066 +
  ;; deep-toasting-bachman plan Phase B.2.
  ;;
  ;; For each variant in TypeDefStmt(name, targs, variants) the arm
  ;; registers a ConstructorScheme(tag_id, total) entry in env via
  ;; $env_extend. Constructor's type:
  ;;   nullary variant (no fields) → TName(typename, [])
  ;;   N-ary variant (1+ fields)   → TFun(field_tys, TName(typename, []),
  ;;                                       EfPure_row)
  ;;
  ;; The tag_id is the variant's INDEX in the variants list (0-based);
  ;; the total is the number of variants. This satisfies the refinement
  ;; `0 <= tag_id < total` which Verify discharges for exhaustiveness
  ;; (post-L2 substrate composition; the predicate IS in scope at the
  ;; SchemeKind level today).
  ;;
  ;; Drift-6 closure: nullary AND N-ary variants pass through the SAME
  ;; ConstructorScheme registration. No Bool special-case. Bool's True/
  ;; False are nullary variants under `type Bool = False | True` per
  ;; types.nx:32 — they get ConstructorScheme(0, 2) and (1, 2) just like
  ;; any other ADT's nullary variants.
    (func $infer_register_typedef_ctors
        (param $type_name i32) (param $variants i32) (param $span i32)
    (local $total i32)
    (local $tag_id i32) (local $variant i32)
    (local $vname i32) (local $field_tys_parser i32)
    (local $field_tys i32) (local $field_count i32)
    (local $result_ty i32) (local $ctor_ty i32)
    (local $row_h i32) (local $scheme i32) (local $reason i32)

    (local.set $total (call $len (local.get $variants)))
    ;; Build the result type once: TName(type_name, []) — every variant
    ;; constructor returns this.
    (local.set $result_ty (call $ty_make_tname
      (local.get $type_name)
      (call $make_list (i32.const 0))))
    (local.set $tag_id (i32.const 0))
    (block $done
      (loop $each
        (br_if $done (i32.ge_u (local.get $tag_id) (local.get $total)))
        (local.set $variant
          (call $list_index (local.get $variants) (local.get $tag_id)))
        ;; Each variant is a 2-tuple (vname, field_tys_parser) per
        ;; parser_decl.wat:60-63.
        (local.set $vname
          (call $list_index (local.get $variant) (i32.const 0)))
        (local.set $field_tys_parser
          (call $list_index (local.get $variant) (i32.const 1)))
        (local.set $field_count (call $len (local.get $field_tys_parser)))
        ;; Build ctor type — nullary uses result_ty directly; N-ary
        ;; wraps in TFun(field_tys, result_ty, EfPure_row).
        (if (i32.eqz (local.get $field_count))
          (then (local.set $ctor_ty (local.get $result_ty)))
          (else
            (local.set $field_tys
              (call $walk_stmt_build_field_tparams
                (local.get $field_tys_parser)))
            (local.set $row_h (call $graph_fresh_row
              (call $reason_make_located (local.get $span)
                (call $reason_make_inferred (i32.const 4080)))))   ;; "effects"
            (local.set $ctor_ty (call $ty_make_tfun
              (local.get $field_tys)
              (local.get $result_ty)
              (local.get $row_h)))))
        (local.set $scheme (call $scheme_make_forall
          (call $make_list (i32.const 0))
          (local.get $ctor_ty)))
        (local.set $reason (call $reason_make_located
          (local.get $span)
          (call $reason_make_declared (local.get $vname))))
        (call $env_extend
          (local.get $vname)
          (local.get $scheme)
          (local.get $reason)
          (call $schemekind_make_ctor
            (local.get $tag_id) (local.get $total)))
        (local.set $tag_id (i32.add (local.get $tag_id) (i32.const 1)))
        (br $each))))

  (func $infer_walk_stmt_typedef
        (export "infer_walk_stmt_typedef")
        (param $stmt i32) (param $handle i32) (param $span i32)
    (drop (local.get $handle))
    (call $infer_register_typedef_ctors
      (i32.load offset=4 (local.get $stmt))
      (i32.load offset=12 (local.get $stmt))
      (local.get $span)))

  ;; ─── EffectDeclStmt arm (tag 123) — Phase B.3 ultimate-form ──────
  ;;
  ;; Per src/infer.nx:215-216 + register_effect_ops 2081-2098.
  ;;
  ;; For each op in EffectDeclStmt(name, ops) where each op is a
  ;; 3-tuple (op_name, param_types, ret_ty): build TFun(param_tys,
  ;; ret_ty, EfPure_row) — the seed's row composition is row-silent
  ;; here per the H1.4 separation (effect names appear in the env-
  ;; entry's name field, not in dispatch). env_extend with op_name +
  ;; EffectOpScheme(effect_name).
  ;;
  ;; The effect-name field on EffectOpScheme is the surface for
  ;; handler-arm matching at handler installation; the wheel's
  ;; row.wat substrate composes on this.
    (func $infer_register_effect_ops
        (param $eff_name i32) (param $ops i32) (param $span i32)
    (local $n_ops i32) (local $i i32)
    (local $op i32) (local $op_name i32) (local $param_tys_parser i32)
    (local $ret_ty_parser i32) (local $param_tys i32) (local $ret_ty i32)
    (local $row_h i32) (local $op_ty i32) (local $scheme i32) (local $reason i32)
    (local.set $n_ops (call $len (local.get $ops)))
    (local.set $i (i32.const 0))
    (block $done
      (loop $each
        (br_if $done (i32.ge_u (local.get $i) (local.get $n_ops)))
        (local.set $op (call $list_index (local.get $ops) (local.get $i)))
        ;; Each op is a 3-tuple (op_name, param_tys_parser, ret_ty_parser)
        ;; per parser_decl.wat:186-190.
        (local.set $op_name (call $list_index (local.get $op) (i32.const 0)))
        (local.set $param_tys_parser
          (call $list_index (local.get $op) (i32.const 1)))
        (local.set $ret_ty_parser
          (call $list_index (local.get $op) (i32.const 2)))
        (local.set $param_tys
          (call $walk_stmt_build_field_tparams (local.get $param_tys_parser)))
        (local.set $ret_ty
          (call $walk_stmt_parser_ty_to_ty (local.get $ret_ty_parser)))
        (local.set $row_h (call $graph_fresh_row
          (call $reason_make_located (local.get $span)
            (call $reason_make_inferred (i32.const 4080)))))   ;; "effects"
        (local.set $op_ty (call $ty_make_tfun
          (local.get $param_tys) (local.get $ret_ty) (local.get $row_h)))
        (local.set $scheme (call $scheme_make_forall
          (call $make_list (i32.const 0))
          (local.get $op_ty)))
        (local.set $reason (call $reason_make_located
          (local.get $span)
          (call $reason_make_declared (local.get $op_name))))
        (call $env_extend
          (local.get $op_name)
          (local.get $scheme)
          (local.get $reason)
          (call $schemekind_make_effectop (local.get $eff_name)))
        (local.set $i (i32.add (local.get $i) (i32.const 1)))
        (br $each))))

  (func $infer_walk_stmt_effect_decl
        (export "infer_walk_stmt_effect_decl")
        (param $stmt i32) (param $handle i32) (param $span i32)
    (drop (local.get $handle))
    (call $infer_register_effect_ops
      (i32.load offset=4 (local.get $stmt))
      (i32.load offset=8 (local.get $stmt))
      (local.get $span)))

  ;; ─── HandlerDeclStmt arm (tag 124) — Phase B.4 ultimate-form ─────
  ;;
  ;; Per src/infer.nx:222-223 + register_handler 2100-2109.
  ;;
  ;; The seed's parser emits HandlerDeclStmt as [tag=124][name][effect=
  ;; ""][arms=[]] (parser_toplevel.wat:65-72) — a stub shape until
  ;; parser_handler.wat lands the full handler-arm parsing. With this
  ;; minimal shape the seed's discipline is: env-extend with the
  ;; handler name bound to TVar(fresh) under FnScheme so subsequent
  ;; references to the handler name don't miss env_lookup.
  ;;
  ;; When parser_handler.wat surfaces the full handler shape (effect-
  ;; intercepted + per-arm bodies + resume disciplines), this arm
  ;; expands to the full register_handler logic. That expansion is the
  ;; named peer cascade `Hβ-infer-handler-decls-full.md` (requires
  ;; walkthrough).
  (func $infer_walk_stmt_handler_decl
        (export "infer_walk_stmt_handler_decl")
        (param $stmt i32) (param $handle i32) (param $span i32)
    (local $handler_name i32) (local $tvar_h i32) (local $tvar_ty i32)
    (local $scheme i32) (local $reason i32)
    (drop (local.get $handle))
    ;; HandlerDeclStmt: [tag=124][name][effect][arms]
    (local.set $handler_name (i32.load offset=4 (local.get $stmt)))
    (local.set $tvar_h (call $graph_fresh_ty
      (call $reason_make_located (local.get $span)
        (call $reason_make_declared (local.get $handler_name)))))
    (local.set $tvar_ty (call $ty_make_tvar (local.get $tvar_h)))
    (local.set $scheme (call $scheme_make_forall
      (call $make_list (i32.const 0))
      (local.get $tvar_ty)))
    (local.set $reason (call $reason_make_located
      (local.get $span)
      (call $reason_make_declared (local.get $handler_name))))
    (call $env_extend
      (local.get $handler_name)
      (local.get $scheme)
      (local.get $reason)
      (call $schemekind_make_fn)))

  ;; ExprStmt arm (tag 125) — src/infer.nx:225-226. Wraps a bare
  ;; expression at statement position. Layout: [tag=125][node]. Walk the
  ;; inner node via $infer_walk_expr.
  (func $infer_walk_stmt_expr
        (export "infer_walk_stmt_expr")
        (param $stmt i32) (param $handle i32) (param $span i32)
    (local $node i32)
    (drop (local.get $handle))
    (drop (local.get $span))
    (local.set $node (i32.load offset=4 (local.get $stmt)))
    (drop (call $infer_walk_expr (local.get $node))))

  ;; ImportStmt arm (tag 126) — src/infer.nx:228 (NStmt(ImportStmt(_)) =>
  ;; ()). Module imports are env-composition concerns the seed doesn't
  ;; resolve (single-module compilation). Hβ.infer.overlay (named
  ;; follow-up §12) lands cross-module env composition.
  (func $infer_walk_stmt_import
        (export "infer_walk_stmt_import")
        (param $stmt i32) (param $handle i32) (param $span i32)
    (drop (local.get $stmt))
    (drop (local.get $handle))
    (drop (local.get $span)))

  ;; RefineStmt arm (tag 127) — src/infer.nx:230-235. Constructs
  ;; TAlias(name, TRefined(base_ty, pred)), env-extends with
  ;; Forall([], aliased), then emits a verify obligation (seed-stub per
  ;; Hβ.infer.refine-stmt — verify.wat substrate already exists, but the
  ;; parser-emitted pred ADT isn't yet stable). Inert seed-stub.
  (func $infer_walk_stmt_refine
        (export "infer_walk_stmt_refine")
        (param $stmt i32) (param $handle i32) (param $span i32)
    (drop (local.get $stmt))
    (drop (local.get $handle))
    (drop (local.get $span)))

  ;; Documented arm (tag 128) — src/infer.nx:240-257. Wraps an inner
  ;; stmt with a docstring; recurses on the inner stmt + threads
  ;; docstring as DocstringReason in the env entry. Inert seed-stub per
  ;; Hβ.infer.docstring-reason named follow-up (parser doesn't emit
  ;; Documented today).
  (func $infer_walk_stmt_documented
        (export "infer_walk_stmt_documented")
        (param $stmt i32) (param $handle i32) (param $span i32)
    (drop (local.get $stmt))
    (drop (local.get $handle))
    (drop (local.get $span)))

  ;; ─── Per-Stmt dispatch ──────────────────────────────────────────────
  ;;
  ;; $infer_stmt(node) — per src/infer.nx:197-260. Reads N's body to get
  ;; the NStmt tag (111), reads NStmt's inner Stmt tag (120-128),
  ;; dispatches to the per-variant arm.
  ;;
  ;; Per H6 wildcard discipline: every Stmt tag has its arm; unknown tag
  ;; traps so future variant addition forces this dispatch to be
  ;; extended (drift mode 9 prevention).
  (func $infer_stmt (export "infer_stmt")
        (param $node i32)
    (local $body i32) (local $stmt i32) (local $tag i32)
    (local $handle i32) (local $span i32)
    (call $infer_init)
    (call $env_init)
    (call $graph_init)
    (local.set $body   (call $walk_stmt_node_body   (local.get $node)))
    (local.set $span   (call $walk_stmt_node_span   (local.get $node)))
    (local.set $handle (call $walk_stmt_node_handle (local.get $node)))
    ;; Body MUST be NStmt (tag 111). Non-NStmt at stmt position is
    ;; parser-bug surface; trap to surface (consistent with H6 +
    ;; walk_expr.wat:1450-1451 NExpr discipline).
    (if (i32.ne (i32.load (local.get $body)) (i32.const 111))
      (then (unreachable)))
    (local.set $stmt (i32.load offset=4 (local.get $body)))
    (local.set $tag (call $walk_stmt_stmt_tag (local.get $stmt)))
    ;; Dispatch on Stmt tag (120-128) per parser_infra.wat:21-23.
    (if (i32.eq (local.get $tag) (i32.const 120))
      (then (return (call $infer_walk_stmt_let
              (local.get $stmt) (local.get $handle) (local.get $span)))))
    (if (i32.eq (local.get $tag) (i32.const 121))
      (then (return (call $infer_walk_stmt_fn
              (local.get $stmt) (local.get $handle) (local.get $span)))))
    (if (i32.eq (local.get $tag) (i32.const 122))
      (then (return (call $infer_walk_stmt_typedef
              (local.get $stmt) (local.get $handle) (local.get $span)))))
    (if (i32.eq (local.get $tag) (i32.const 123))
      (then (return (call $infer_walk_stmt_effect_decl
              (local.get $stmt) (local.get $handle) (local.get $span)))))
    (if (i32.eq (local.get $tag) (i32.const 124))
      (then (return (call $infer_walk_stmt_handler_decl
              (local.get $stmt) (local.get $handle) (local.get $span)))))
    (if (i32.eq (local.get $tag) (i32.const 125))
      (then (return (call $infer_walk_stmt_expr
              (local.get $stmt) (local.get $handle) (local.get $span)))))
    (if (i32.eq (local.get $tag) (i32.const 126))
      (then (return (call $infer_walk_stmt_import
              (local.get $stmt) (local.get $handle) (local.get $span)))))
    (if (i32.eq (local.get $tag) (i32.const 127))
      (then (return (call $infer_walk_stmt_refine
              (local.get $stmt) (local.get $handle) (local.get $span)))))
    (if (i32.eq (local.get $tag) (i32.const 128))
      (then (return (call $infer_walk_stmt_documented
              (local.get $stmt) (local.get $handle) (local.get $span)))))
    ;; Unknown Stmt tag — H6 wildcard discipline: trap so future Stmt
    ;; variants force this dispatch table to be extended (drift mode 9
    ;; prevention).
    (unreachable))

  ;; $infer_stmt_list(stmts) — per src/infer.nx:188-193. Iterate flat
  ;; list of stmt N nodes, walk each via $infer_stmt. Productive-under-
  ;; error: a stmt that fails (e.g., unbound name in expr; PCon-on-pat
  ;; at the seed) emits diagnostic via emit_diag chain and returns; the
  ;; list walk continues. NEVER abort.
  ;;
  ;; This is the function walk_expr.wat:824 BlockExpr arm forward-
  ;; declared (per Hβ.infer §13.3 #9 peer chunk discipline). Once this
  ;; chunk lands, the BlockExpr arm is retrofitted to call
  ;; $infer_stmt_list before walking final_expr.
  (func $infer_stmt_list (export "infer_stmt_list")
        (param $stmts i32)
    (local $n i32) (local $i i32) (local $stmt_node i32)
    (local.set $n (call $len (local.get $stmts)))
    (local.set $i (i32.const 0))
    (block $done
      (loop $each
        (br_if $done (i32.ge_u (local.get $i) (local.get $n)))
        (local.set $stmt_node (call $list_index (local.get $stmts) (local.get $i)))
        (call $infer_stmt (local.get $stmt_node))
        (local.set $i (i32.add (local.get $i) (i32.const 1)))
        (br $each))))

  ;; $infer_program(stmts) — per src/infer.nx:182-186. Top-level entry
  ;; from main.wat (peer Tier 8 chunk pending). Initializes graph + env +
  ;; infer state, then walks the stmt list. The wheel wraps in
  ;; `handle … with infer_ctx` (effect handler for row accumulation);
  ;; seed has no row accumulation so the handler is inert.
  ;;
  ;; Toplevel pre-register pass (src/infer.nx:96-149 pre_register_fn_sigs):
  ;; the wheel pre-registers all FnStmt names with placeholder schemes
  ;; before walking, so forward-references resolve. SEED-STUB per
  ;; Hβ.infer.toplevel-pre-register named follow-up — at the seed
  ;; FnStmts must be defined in topological order (which currently
  ;; src/*.nx satisfies).
  (func $infer_program (export "infer_program")
        (param $stmts i32)
    (call $graph_init)
    (call $env_init)
    (call $infer_init)
    (call $infer_pre_register_fn_sigs (local.get $stmts))
    (call $infer_stmt_list (local.get $stmts)))

