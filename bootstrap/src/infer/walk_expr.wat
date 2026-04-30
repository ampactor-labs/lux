  ;; ═══ walk_expr.wat — expression inference walk (Tier 7) ═════════════
  ;; Implements: Hβ-infer-substrate.md §3 + §4.1 + §4.3 + §5 + §6.3 +
  ;;             §7.2 + §8.1 walk_expr.wat row + §8.4 ~900-line estimate +
  ;;             §9 worked example + §11 acceptance + §13.3 dep order #8 +
  ;;             docs/specs/04-inference.md §What the walk produces +
  ;;             docs/specs/03-typed-ast.md (canonical AST shape) +
  ;;             canonical wheel src/infer.nx:490-765 (infer_expr arms) +
  ;;             :782-810 (infer_var_ref / check_consume_at_use) +
  ;;             :820-846 (infer_call + row chase) +
  ;;             :898-974 (infer_pipe / per-PipeKind arms) +
  ;;             :985-1030 (infer_compose / infer_diverge) +
  ;;             :1543-1583 (infer_binop / infer_unaryop) +
  ;;             :1701-1733 (infer_match_arms + iter) +
  ;;             :1795-1805 (infer_handler_arms).
  ;;
  ;; Realizes the walk projection of primitive #8 (HM inference live +
  ;; productive-under-error + with Reasons — DESIGN.md §0.5) at the seed
  ;; substrate. Every Expr variant tagged 80-101 by the parser
  ;; (parser_infra.wat:14-19) gets one arm; each arm ends with exactly
  ;; ONE $graph_bind on the AST handle (modulo branch arms that bind
  ;; sub-handles too; the per-handle invariant is "one bind per AST
  ;; handle" per src/infer.nx:493-498 line shape). Per Hazel productive-
  ;; under-error: env_lookup miss, handler-uninstallable, pattern-
  ;; inexhaustive, feedback-no-context all emit-and-bind-NErrorHole-and-
  ;; continue rather than aborting. The chunk drives one walk; it never
  ;; checks vs. infers (no bidirectional split per §7.2 foreign-fluency).
  ;;
  ;; Exports:    $infer_walk_expr,
  ;;             $infer_walk_expr_lit_int, $infer_walk_expr_lit_float,
  ;;             $infer_walk_expr_lit_string, $infer_walk_expr_lit_bool,
  ;;             $infer_walk_expr_lit_unit,
  ;;             $infer_walk_expr_var_ref,
  ;;             $infer_walk_expr_binop, $infer_walk_expr_unaryop,
  ;;             $infer_walk_expr_call,
  ;;             $infer_walk_expr_lambda,
  ;;             $infer_walk_expr_if,
  ;;             $infer_walk_expr_block,
  ;;             $infer_walk_expr_match, $infer_walk_expr_match_arms,
  ;;             $infer_walk_expr_make_list, $infer_walk_expr_make_tuple,
  ;;             $infer_walk_expr_make_record, $infer_walk_expr_named_record,
  ;;             $infer_walk_expr_field,
  ;;             $infer_walk_expr_perform,
  ;;             $infer_walk_expr_handle, $infer_walk_expr_resume,
  ;;             $infer_walk_expr_pipe,
  ;;             $infer_walk_expr_pipe_forward,
  ;;             $infer_walk_expr_pipe_compose,
  ;;             $infer_walk_expr_pipe_diverge,
  ;;             $infer_walk_expr_pipe_tee,
  ;;             $infer_walk_expr_pipe_feedback
  ;; Uses:       $alloc (alloc.wat),
  ;;             $str_eq / $str_concat / $str_alloc (str.wat),
  ;;             $int_to_str (int.wat),
  ;;             $make_list / $list_index / $list_set / $list_extend_to /
  ;;               $len / $slice (list.wat),
  ;;             $make_record / $record_get / $record_set / $tag_of (record.wat),
  ;;             $eprint_string (wasi.wat),
  ;;             $graph_init / $graph_fresh_ty / $graph_fresh_row /
  ;;               $graph_chase / $graph_node_at / $graph_bind /
  ;;               $graph_bind_kind / $gnode_kind / $node_kind_tag /
  ;;               $node_kind_payload / $node_kind_make_nerrorhole (graph.wat),
  ;;             $env_init / $env_lookup / $env_extend /
  ;;               $env_scope_enter / $env_scope_exit /
  ;;               $env_binding_scheme / $env_binding_reason /
  ;;               $env_binding_kind (env.wat),
  ;;             $infer_init / $infer_span_index_append (state.wat),
  ;;             $reason_make_located / $reason_make_inferred /
  ;;               $reason_make_opconstraint / $reason_make_varlookup /
  ;;               $reason_make_inferredcallreturn /
  ;;               $reason_make_inferredpiperesult /
  ;;               $reason_make_ifbranch / $reason_make_matchbranch /
  ;;               $reason_make_listelement (reason.wat),
  ;;             $ty_make_tint / $ty_make_tfloat / $ty_make_tstring /
  ;;               $ty_make_tunit / $ty_make_tvar / $ty_make_tlist /
  ;;               $ty_make_ttuple / $ty_make_tfun / $ty_make_tname /
  ;;               $ty_make_trecord / $ty_make_trecordopen /
  ;;               $ty_tag / $ty_tvar_handle (ty.wat),
  ;;             $tparam_make / $ownership_make_inferred /
  ;;               $field_pair_make (tparam.wat),
  ;;             $instantiate / $scheme_make_forall (scheme.wat),
  ;;             $infer_emit_missing_var /
  ;;               $infer_emit_feedback_no_context /
  ;;               $infer_emit_pattern_inexhaustive /
  ;;               $infer_emit_not_a_record_type (emit_diag.wat),
  ;;             $unify (unify.wat),
  ;;             $infer_consume_use / $infer_branch_enter /
  ;;               $infer_branch_divider / $infer_branch_exit (own.wat),
  ;;             $infer_stmt_list (walk_stmt.wat — peer Tier 7).
  ;; Test:       bootstrap/test/infer/walk_expr_lit_int.wat,
  ;;             bootstrap/test/infer/walk_expr_var_ref_miss.wat,
  ;;             bootstrap/test/infer/walk_expr_binop_arith.wat,
  ;;             bootstrap/test/infer/walk_expr_call_through_unify.wat
  ;;
  ;; ═══ EIGHT INTERROGATIONS (per Hβ-infer-substrate.md §6.3 applied to
  ;;                            walk_expr.wat per-arm walk) ═══════════════
  ;;
  ;; 1. Graph?      Every arm ends in exactly ONE $graph_bind on the AST
  ;;                handle (one bind per AST handle, per src/infer.nx
  ;;                invariant). Branch arms (BinOp BKBool, IfExpr) ALSO
  ;;                bind sub-handles for taught-typing — but each handle
  ;;                gets bound at most once per the per-handle invariant.
  ;; 2. Handler?    Direct seed call. Wheel's $inf_enter_fn / $inf_exit_fn /
  ;;                $inf_add_row / $inf_push_handler / $inf_pop_handler
  ;;                (src/infer.nx:36-153) are seed-stubbed as no-ops with
  ;;                named peer follow-up Hβ.infer.row-normalize +
  ;;                Hβ.infer.handler-stack. The walk arms are SHAPED so the
  ;;                wheel's @resume=OneShot resume-discipline maps 1-1 onto
  ;;                the seed's direct return.
  ;; 3. Verb?       PipeExpr arm dispatches on PipeKind tag (160-165 per
  ;;                parser_infra.wat:27): PForward / PDiverge / PCompose /
  ;;                PTeeBlock / PTeeInline / PFeedback. Each verb arm's
  ;;                topology builds the typed AST per src/infer.nx
  ;;                infer_pipe / infer_compose / infer_diverge.
  ;; 4. Row?        TFun construction at CallExpr / LambdaExpr uses
  ;;                $ty_make_tfun(params, return_ty, row_h) where row_h
  ;;                comes from $graph_fresh_row. Arms that "add to the
  ;;                current accumulating row" call seed-stub
  ;;                $walk_expr_inf_add_row (no-op pass-through; row.wat
  ;;                sibling lands the composition per Hβ.infer.row-normalize).
  ;; 5. Ownership?  Every VarRef arm calls $infer_consume_use(handle, name,
  ;;                span, located_reason) (own.wat). The affine ledger
  ;;                decides whether to fire the diagnostic; the walk does
  ;;                not gate. Branch verbs (PCompose, PDiverge with
  ;;                MakeTupleExpr right) wrap their sub-walks in
  ;;                $infer_branch_enter / $infer_branch_divider /
  ;;                $infer_branch_exit so parallel consumes collide.
  ;; 6. Refinement? TRefined predicates arrive via parser AST type-
  ;;                annotations and pass through unify; predicates compose
  ;;                via verify.wat's ledger when the handle's chained
  ;;                Reason carries a refinement. NO walk arm constructs
  ;;                TRefined directly (parser's job).
  ;; 7. Gradient?   Each $graph_bind is one gradient step (NFree → NBound).
  ;;                Productive-under-error arms (env_lookup miss; handler-
  ;;                uninstallable; pattern-inexhaustive; feedback-no-
  ;;                context) emit-then-bind-NErrorHole-then-return — never
  ;;                abort. emit_diag.wat helpers do the bind via
  ;;                $graph_bind_kind + $node_kind_make_nerrorhole.
  ;; 8. Reason?     Every $graph_bind wraps its Reason via
  ;;                $reason_make_located(span, inner). Arm-specific inner
  ;;                Reasons via $reason_make_inferred (literal arms),
  ;;                $reason_make_opconstraint (BinOp / UnaryOp),
  ;;                $reason_make_varlookup (VarRef),
  ;;                $reason_make_inferredcallreturn (CallExpr),
  ;;                $reason_make_inferredpiperesult (PipeExpr),
  ;;                $reason_make_ifbranch (IfExpr),
  ;;                $reason_make_matchbranch (MatchExpr arms).
  ;;
  ;; ═══ FORBIDDEN PATTERNS AUDIT (per Hβ-infer-substrate.md §7.2 +
  ;;                                applied to walk_expr.wat) ═══════════
  ;;
  ;; - Drift 1 (Rust vtable):           NO closure-array indexed by tag.
  ;;                                    Arms dispatch via direct
  ;;                                    (if (i32.eq tag …)) chain in
  ;;                                    $infer_walk_expr. The chain IS the
  ;;                                    substrate's variant enumeration,
  ;;                                    NOT a table.
  ;; - Drift 2 (Scheme env frame):      env.wat owns all scope state; this
  ;;                                    chunk threads NO sidecar context.
  ;; - Drift 3 (Python dict):           Reason-ctx strings live in
  ;;                                    data-segment offsets passed as
  ;;                                    string ptrs to $reason_make_inferred;
  ;;                                    NOT $str_eq enum dispatch.
  ;; - Drift 4 (Haskell monad transformer): NO $walk_expr_M_bind /
  ;;                                    $walk_expr_M_return. Arms call
  ;;                                    $infer_walk_expr recursively on
  ;;                                    subnodes; return i32 (the bound
  ;;                                    handle for caller convenience).
  ;; - Drift 5 (C calling convention):  Signature is (param $node i32)
  ;;                                    (result i32) — single i32 in (the
  ;;                                    wrapped N record), single i32 out
  ;;                                    (the AST handle the caller already
  ;;                                    knows but returning IT mirrors
  ;;                                    src/infer.nx's `let N(_, _, h) =
  ;;                                    node` pattern). NO bundled context-
  ;;                                    struct + state ptr.
  ;; - Drift 6 (primitive special-case): TInt / TFloat / TString / TUnit
  ;;                                    flow through the SAME $graph_bind +
  ;;                                    $reason_make_located + $reason_make_
  ;;                                    inferred shape; no fast-path.
  ;; - Drift 7 (parallel-arrays):       Arg-handle collection uses the
  ;;                                    buffer-counter substrate (one flat
  ;;                                    list of handles); NEVER parallel
  ;;                                    (ty_ptrs[], reason_ptrs[]) arrays.
  ;; - Drift 8 (mode flag / string-keyed): BinOp arm dispatches on BinOp
  ;;                                    tag (140-153 per parser_infra.wat:
  ;;                                    26+329-343); NEVER on string.
  ;;                                    PipeKind dispatches on tag (160-165);
  ;;                                    NEVER on `kind == "|>"`.
  ;; - Drift 9 (deferred-by-omission):  Every Expr tag (80-101) gets an
  ;;                                    arm. BlockExpr forward-declares
  ;;                                    $infer_stmt_list (walk_stmt.wat —
  ;;                                    peer Tier 7 chunk per §13.3 #9, NOT
  ;;                                    silent deferral). LambdaExpr,
  ;;                                    HandleExpr's row + handler-stack
  ;;                                    ops compose on inert seed-stubs
  ;;                                    named at chunk-end as Hβ.infer.row-
  ;;                                    normalize / .handler-stack. Inert
  ;;                                    stubs are NOT TODOs; they are
  ;;                                    explicit named-no-ops with peer
  ;;                                    follow-up handles.
  ;;
  ;; - Foreign fluency — type-check vs. infer split: NO $check_expr peer;
  ;;                                    ONE $infer_walk_expr. NO bidirectional
  ;;                                    dispatch. Per §7.2 + spec 04 §Three
  ;;                                    operations.
  ;; - Foreign fluency — Algorithm W return tuple: arms return i32 (the
  ;;                                    AST handle); they do NOT return
  ;;                                    (subst, type) pairs. Subst IS the
  ;;                                    graph; the handle's NBound payload
  ;;                                    is the type. Per §7.1.
  ;; - Foreign fluency — exception machinery: NO "throw" / "panic" /
  ;;                                    "raise" / "exception" / "catch"
  ;;                                    vocabulary. NErrorHole IS the
  ;;                                    productive-under-error substrate.
  ;;
  ;; ═══ TAG REGION ═══════════════════════════════════════════════════
  ;;
  ;; This chunk introduces NO new tags. It dispatches on:
  ;;   parser_infra.wat:14-19  Expr variants  80-101 (LitInt..PipeExpr)
  ;;   parser_infra.wat:20     NodeBody       110 (NExpr)
  ;;   parser_infra.wat:26     BinOp          140-153 (BAdd..BConcat)
  ;;   parser_infra.wat:27     PipeKind       160-165 (PForward..PFeedback)
  ;;   ty.wat:248              Ty             100-113 (TInt..TAlias)
  ;;   reason.wat              Reason         220-242
  ;;   own.wat                 USED_SITE_ENTRY 213, BRANCH_FRAME 214
  ;;
  ;; ═══ NAMED FOLLOW-UPS (per Drift 9 + Hβ-infer §12) ═══════════════════
  ;;
  ;; - Hβ.infer.row-normalize: $walk_expr_inf_add_row /
  ;;   $walk_expr_inf_enter_fn / $walk_expr_inf_exit_fn are inert seed-
  ;;   stubs. Wheel's inf_* arms (src/infer.nx:36-153) compose row
  ;;   composition on row.wat substrate that lands in the row.wat sibling
  ;;   chunk. Until then PForward / CallExpr / PerformExpr's "row flows
  ;;   into caller" line in src/infer.nx:843+869+919 is a no-op at the
  ;;   seed.
  ;; - Hβ.infer.handler-stack: $walk_expr_inf_push_handler /
  ;;   $walk_expr_inf_pop_handler (src/infer.nx:127-138) similarly inert.
  ;;   HandleExpr / PTeeBlock / PTeeInline arms still bind correctly (the
  ;;   body's type IS the result type) without handler-stack tracking; W4
  ;;   monomorphic-dispatch read happens later.
  ;; - Hβ.infer.region-tracker: H4 tag_alloc_join calls
  ;;   (src/infer.nx:524-587) inert. Region tracking lands when Hβ.lower's
  ;;   Alloc surface matures.
  ;; - Hβ.infer.docstring-reason: Documented Stmt arm omitted (parser
  ;;   doesn't emit Documented today; landing pre-DS.3).
  ;; - Hβ.infer.walk_pat: LANDED (Phase B.5 commit). $infer_walk_pat
  ;;   dispatches PVar/PWild/PLit/PCon/PTuple/PList per spec 03;
  ;;   called from MatchExpr arm + LetStmt arm. PCon threads
  ;;   constructor field types to sub-patterns via TFun param extraction.
  ;; - Hβ.infer.match-exhaustive: exhaustiveness check
  ;;   (src/infer.nx:1709-1718) omitted at the seed; MatchExpr arm
  ;;   delegates to $infer_emit_pattern_inexhaustive on demand only.
  ;; - Hβ.infer.named-record-validate: check_nominal_record_fields
  ;;   (src/infer.nx:1397-1450) omitted; uses already-landed
  ;;   $infer_emit_record_field_extra / _missing helpers.
  ;; - Hβ.infer.iterative-context: <~ arm pessimistically emits
  ;;   feedback-no-context always; lands when Clock/Tick/Sample handler-
  ;;   stack-walk substrate matures.
  ;; - Hβ.infer.qualified-name: FieldExpr's dotted-name fallback
  ;;   (src/infer.nx:710-722) deferred; seed treats every FieldExpr as
  ;;   record field access.
  ;; - walk_stmt.wat (peer Tier 7 chunk per §13.3 #9): LANDED. Provides
  ;;   $infer_stmt_list; BlockExpr arm now calls it directly (Hβ.infer
  ;;   §13.3 #9 closure complete).

  ;; ─── Data segment — Reason-inner string fragments ────────────────────
  ;;
  ;; Offsets ≥ 3392 to sit above own.wat's last segment (3352 + 26 = 3378
  ;; high-water; 14-byte safety gap). Below HEAP_BASE = 4096 per
  ;; CLAUDE.md memory model. Length-prefix uses the actual byte count of
  ;; the payload per §11.5 emit_diag.wat lessons.

  (data (i32.const 3392) "\0b\00\00\00int literal")          ;; 11 bytes
  (data (i32.const 3416) "\0d\00\00\00float literal")        ;; 13 bytes
  (data (i32.const 3440) "\0e\00\00\00string literal")       ;; 14 bytes
  (data (i32.const 3464) "\0c\00\00\00bool literal")         ;; 12 bytes
  (data (i32.const 3480) "\04\00\00\00unit")                 ;;  4 bytes
  (data (i32.const 3504) "\04\00\00\00Bool")                 ;;  4 bytes
  (data (i32.const 3520) "\07\00\00\00var ref")              ;;  7 bytes
  (data (i32.const 3552) "\04\00\00\00left")                 ;;  4 bytes
  (data (i32.const 3568) "\05\00\00\00right")                ;;  5 bytes
  (data (i32.const 3584) "\06\00\00\00result")               ;;  6 bytes
  (data (i32.const 3600) "\07\00\00\00operand")              ;;  7 bytes
  (data (i32.const 3616) "\0a\00\00\00comparison")           ;; 10 bytes
  (data (i32.const 3632) "\06\00\00\00concat")               ;;  6 bytes
  (data (i32.const 3648) "\06\00\00\00<call>")               ;;  6 bytes
  (data (i32.const 3672) "\06\00\00\00return")               ;;  6 bytes
  (data (i32.const 3696) "\07\00\00\00effects")              ;;  7 bytes
  (data (i32.const 3720) "\08\00\00\00expected")             ;;  8 bytes
  (data (i32.const 3744) "\0b\00\00\00unification")          ;; 11 bytes
  (data (i32.const 3768) "\0c\00\00\00if condition")         ;; 12 bytes
  (data (i32.const 3792) "\0b\00\00\00if branches")          ;; 11 bytes
  (data (i32.const 3816) "\09\00\00\00if result")            ;;  9 bytes
  (data (i32.const 3840) "\0c\00\00\00block result")         ;; 12 bytes
  (data (i32.const 3864) "\08\00\00\00arm body")             ;;  8 bytes
  (data (i32.const 3888) "\0d\00\00\00record result")        ;; 13 bytes
  (data (i32.const 3912) "\0c\00\00\00tuple result")         ;; 12 bytes
  (data (i32.const 3936) "\0b\00\00\00list result")          ;; 11 bytes
  (data (i32.const 3960) "\0a\00\00\00empty list")           ;; 10 bytes
  (data (i32.const 3984) "\06\00\00\00lambda")               ;;  6 bytes
  (data (i32.const 4008) "\06\00\00\00<expr>")               ;;  6 bytes

  ;; ─── Private helpers ─────────────────────────────────────────────────

  ;; $walk_expr_node_handle(N) — extract handle (offset 12) from the N
  ;; record (parser_infra.wat:32-39 layout: [tag=0][body][span][handle]).
  (func $walk_expr_node_handle (param $n i32) (result i32)
    (i32.load offset=12 (local.get $n)))

  ;; $walk_expr_node_span(N) — extract span (offset 8) from the N record.
  (func $walk_expr_node_span (param $n i32) (result i32)
    (i32.load offset=8 (local.get $n)))

  ;; $walk_expr_node_body(N) — extract body (offset 4) from the N record.
  (func $walk_expr_node_body (param $n i32) (result i32)
    (i32.load offset=4 (local.get $n)))

  ;; $walk_expr_expr_tag(expr) — get the Expr variant tag (80-101). Uses
  ;; $tag_of so LitUnit (sentinel 84 < HEAP_BASE) routes correctly per
  ;; record.wat:49 precedent. Heap-tag Expr variants load tag at offset 0
  ;; via the same $tag_of dispatch.
  (func $walk_expr_expr_tag (param $expr i32) (result i32)
    (call $tag_of (local.get $expr)))

  ;; $walk_expr_make_inferred_located(span, ctx) — wraps
  ;; Located(span, Inferred(ctx)). Common pattern across literal arms.
  (func $walk_expr_make_inferred_located (param $span i32) (param $ctx i32)
                                          (result i32)
    (call $reason_make_located
      (local.get $span)
      (call $reason_make_inferred (local.get $ctx))))

  ;; $walk_expr_unify_handles(h_a, h_b, span, reason) — thin readability
  ;; wrapper over $unify. Some arms call this; some call $unify directly.
  (func $walk_expr_unify_handles (param $h_a i32) (param $h_b i32)
                                  (param $span i32) (param $reason i32)
    (call $unify (local.get $h_a) (local.get $h_b)
                  (local.get $span) (local.get $reason)))

  ;; $walk_expr_collect_arg_handles(args) — buffer-counter substrate per
  ;; CLAUDE.md bug class. Walks each arg N node via $infer_walk_expr (which
  ;; mutates the graph) and collects each child's handle into a fresh flat
  ;; list. Returns the list (callers index it for $tparam_make + $unify).
  (func $walk_expr_collect_arg_handles (param $args i32) (result i32)
    (local $n i32) (local $i i32) (local $buf i32)
    (local $arg_node i32) (local $arg_h i32)
    (local.set $n (call $len (local.get $args)))
    (local.set $buf (call $make_list (i32.const 0)))
    (local.set $buf (call $list_extend_to (local.get $buf) (local.get $n)))
    (local.set $i (i32.const 0))
    (block $done
      (loop $each
        (br_if $done (i32.ge_u (local.get $i) (local.get $n)))
        (local.set $arg_node (call $list_index (local.get $args) (local.get $i)))
        (local.set $arg_h (call $infer_walk_expr (local.get $arg_node)))
        (drop (call $list_set (local.get $buf) (local.get $i) (local.get $arg_h)))
        (local.set $i (i32.add (local.get $i) (i32.const 1)))
        (br $each)))
    (local.get $buf))

  ;; $walk_expr_build_inferred_params(arg_handles) — for each handle h,
  ;; build TParam(name=anon, ty=TVar(h), authored=Inferred,
  ;; resolved=Inferred). Mirrors src/infer.nx:828 build_inferred_params.
  ;; The anon name is the empty string; renders correctly through
  ;; emit_diag.wat's $render_ty walker (which already handles empty
  ;; TParam names).
  (func $walk_expr_build_inferred_params (param $arg_handles i32) (result i32)
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

  ;; $walk_expr_inf_add_row — Hβ.infer.row-normalize stub. Wheel's
  ;; inf_add_row composes the callee's row into the caller's accumulating
  ;; row (src/infer.nx:843); seed pass-through no-op until row.wat sibling
  ;; lands.
  (func $walk_expr_inf_add_row (param $row i32)
    (drop (local.get $row)))

  ;; $walk_expr_inf_enter_fn — Hβ.infer.row-normalize stub. Wheel's
  ;; inf_enter_fn pushes a row scope onto the FnStmt stack
  ;; (src/infer.nx:36-50); seed no-op.
  (func $walk_expr_inf_enter_fn (param $row_h i32) (param $span i32)
    (drop (local.get $row_h))
    (drop (local.get $span)))

  ;; $walk_expr_inf_exit_fn — Hβ.infer.row-normalize stub. Wheel's
  ;; inf_exit_fn pops the FnStmt row scope; seed no-op.
  (func $walk_expr_inf_exit_fn
    (nop))

  ;; $walk_expr_inf_push_handler — Hβ.infer.handler-stack stub. Wheel's
  ;; inf_push_handler tags the handler-stack frame with handled-effect
  ;; identity (src/infer.nx:127-132); seed no-op.
  (func $walk_expr_inf_push_handler (param $tag i32)
    (drop (local.get $tag)))

  ;; $walk_expr_inf_pop_handler — Hβ.infer.handler-stack stub.
  (func $walk_expr_inf_pop_handler
    (nop))

  ;; $walk_expr_callee_name(func_node) — extracts callee name for Reason
  ;; chains: if func is VarRef, return its name string ptr; if FieldExpr,
  ;; return field name; else return data-segment "<expr>". Mirrors
  ;; src/infer.nx:812-818.
  (func $walk_expr_callee_name (param $func_node i32) (result i32)
    (local $body i32) (local $expr i32) (local $tag i32)
    (local.set $body (call $walk_expr_node_body (local.get $func_node)))
    ;; If body isn't NExpr (110), fall through to "<expr>".
    (if (i32.ne (i32.load (local.get $body)) (i32.const 110))
      (then (return (i32.const 4008))))
    (local.set $expr (i32.load offset=4 (local.get $body)))
    (local.set $tag (call $walk_expr_expr_tag (local.get $expr)))
    ;; VarRef (85): name at offset 4
    (if (i32.eq (local.get $tag) (i32.const 85))
      (then (return (i32.load offset=4 (local.get $expr)))))
    ;; FieldExpr (100): field at offset 8 ([tag=100][rec][field])
    (if (i32.eq (local.get $tag) (i32.const 100))
      (then (return (i32.load offset=8 (local.get $expr)))))
    (i32.const 4008))   ;; "<expr>"

  ;; $walk_expr_collect_handled_effects(arms) — placeholder per
  ;; Hβ.infer.handler-stack named follow-up. Returns empty list.
  (func $walk_expr_collect_handled_effects (param $arms i32) (result i32)
    (drop (local.get $arms))
    (call $make_list (i32.const 0)))

  ;; $walk_expr_handle_arm_iter(arms, body_h, span) — iterate handler
  ;; arms; for each: scope_enter, walk arm.body, unify arm_body_h ↔
  ;; body_h, scope_exit. Mirrors src/infer.nx:1795-1805. The seed treats
  ;; each arm as an opaque record whose .body field lives at offset 4
  ;; (parser-emitted shape; lands as a peer record in walk_stmt.wat with
  ;; HANDLER_ARM tag — for now opaque-deref by offset).
  (func $walk_expr_handle_arm_iter (param $arms i32) (param $body_h i32)
                                    (param $span i32)
    (local $n i32) (local $i i32)
    (local $arm i32) (local $arm_body i32) (local $abh i32)
    (local.set $n (call $len (local.get $arms)))
    (local.set $i (i32.const 0))
    (block $done
      (loop $each
        (br_if $done (i32.ge_u (local.get $i) (local.get $n)))
        (local.set $arm (call $list_index (local.get $arms) (local.get $i)))
        (call $env_scope_enter)
        ;; Arm body field is at offset 4 of the arm record. Forward-
        ;; declared record shape: walk_stmt.wat lands HANDLER_ARM
        ;; constructors per Hβ.infer §13.3 #9.
        (local.set $arm_body (i32.load offset=4 (local.get $arm)))
        (local.set $abh (call $infer_walk_expr (local.get $arm_body)))
        (call $unify (local.get $abh) (local.get $body_h)
                      (local.get $span)
                      (call $reason_make_inferred (i32.const 3864)))   ;; "arm body"
        (call $env_scope_exit)
        (local.set $i (i32.add (local.get $i) (i32.const 1)))
        (br $each))))

  ;; ─── Per-Expr-variant arms ───────────────────────────────────────────

  ;; LitInt arm — src/infer.nx:493
  (func $infer_walk_expr_lit_int
        (export "infer_walk_expr_lit_int")
        (param $expr i32) (param $handle i32) (param $span i32)
        (result i32)
    (drop (local.get $expr))
    (call $graph_bind
      (local.get $handle)
      (call $ty_make_tint)
      (call $reason_make_located (local.get $span)
        (call $reason_make_inferred (i32.const 3392))))   ;; "int literal"
    (local.get $handle))

  ;; LitFloat arm — src/infer.nx:494
  (func $infer_walk_expr_lit_float
        (export "infer_walk_expr_lit_float")
        (param $expr i32) (param $handle i32) (param $span i32)
        (result i32)
    (drop (local.get $expr))
    (call $graph_bind
      (local.get $handle)
      (call $ty_make_tfloat)
      (call $reason_make_located (local.get $span)
        (call $reason_make_inferred (i32.const 3416))))   ;; "float literal"
    (local.get $handle))

  ;; LitString arm — src/infer.nx:495
  (func $infer_walk_expr_lit_string
        (export "infer_walk_expr_lit_string")
        (param $expr i32) (param $handle i32) (param $span i32)
        (result i32)
    (drop (local.get $expr))
    (call $graph_bind
      (local.get $handle)
      (call $ty_make_tstring)
      (call $reason_make_located (local.get $span)
        (call $reason_make_inferred (i32.const 3440))))   ;; "string literal"
    (local.get $handle))

  ;; LitBool arm — src/infer.nx:496. Bool is TName("Bool", []).
  (func $infer_walk_expr_lit_bool
        (export "infer_walk_expr_lit_bool")
        (param $expr i32) (param $handle i32) (param $span i32)
        (result i32)
    (drop (local.get $expr))
    (call $graph_bind
      (local.get $handle)
      (call $ty_make_tname (i32.const 3504) (call $make_list (i32.const 0)))
      (call $reason_make_located (local.get $span)
        (call $reason_make_inferred (i32.const 3464))))   ;; "bool literal"
    (local.get $handle))

  ;; LitUnit arm — src/infer.nx:497. expr is the sentinel 84; do not deref.
  (func $infer_walk_expr_lit_unit
        (export "infer_walk_expr_lit_unit")
        (param $expr i32) (param $handle i32) (param $span i32)
        (result i32)
    (drop (local.get $expr))
    (call $graph_bind
      (local.get $handle)
      (call $ty_make_tunit)
      (call $reason_make_located (local.get $span)
        (call $reason_make_inferred (i32.const 3480))))   ;; "unit"
    (local.get $handle))

  ;; VarRef arm — src/infer.nx:499 + 787-810. Productive-under-error on
  ;; env miss: emit_missing_var binds NErrorHole + caller continues.
  (func $infer_walk_expr_var_ref
        (export "infer_walk_expr_var_ref")
        (param $expr i32) (param $handle i32) (param $span i32)
        (result i32)
    (local $name i32) (local $binding i32)
    (local $scheme i32) (local $reason i32) (local $ty i32)
    ;; VarRef layout: [tag=85][name_ptr] — name at offset 4
    (local.set $name (i32.load offset=4 (local.get $expr)))
    (local.set $binding (call $env_lookup (local.get $name)))
    (if (i32.eqz (local.get $binding))
      (then
        ;; Hazel productive-under-error: emit + bind NErrorHole + return.
        (call $infer_emit_missing_var
          (local.get $handle) (local.get $name)
          (call $reason_make_located (local.get $span)
            (call $reason_make_inferred (i32.const 3520))))   ;; "var ref"
        (return (local.get $handle))))
    ;; Hit: instantiate scheme + bind.
    (local.set $scheme (call $env_binding_scheme (local.get $binding)))
    (local.set $reason (call $env_binding_reason (local.get $binding)))
    (local.set $ty     (call $instantiate (local.get $scheme)))
    (call $graph_bind
      (local.get $handle)
      (local.get $ty)
      (call $reason_make_located (local.get $span)
        (call $reason_make_varlookup (local.get $name) (local.get $reason))))
    ;; Ownership is row-gated, not globally tracked. Consume fires ONLY
    ;; for params declared `own X`. Default = ref = !Consume. Wire-up
    ;; through env_binding ownership marker is the SchemeKind extension
    ;; (Hβ.infer.ownership-row-gate). Until then: no false positives.
    (local.get $handle))

  ;; BinOpExpr arm — src/infer.nx:501-507 + 1543-1572. Dispatches on
  ;; BinOp tag via numeric range (140-153 grouped into BKArith / BKCmp /
  ;; BKBool / BKConcat per src/types.nx binop_kind table).
  (func $infer_walk_expr_binop
        (export "infer_walk_expr_binop")
        (param $expr i32) (param $handle i32) (param $span i32)
        (result i32)
    (local $op i32) (local $left i32) (local $right i32)
    (local $lh i32) (local $rh i32) (local $op_str i32)
    ;; Layout: [tag=86][op][left][right]
    (local.set $op    (i32.load offset=4  (local.get $expr)))
    (local.set $left  (i32.load offset=8  (local.get $expr)))
    (local.set $right (i32.load offset=12 (local.get $expr)))
    ;; Walk children
    (local.set $lh (call $infer_walk_expr (local.get $left)))
    (local.set $rh (call $infer_walk_expr (local.get $right)))
    (local.set $op_str (call $int_to_str (local.get $op)))
    ;; BKArith: BAdd/BSub/BMul/BDiv/BMod (140-144)
    (if (i32.le_u (local.get $op) (i32.const 144))
      (then
        (call $unify (local.get $lh) (local.get $rh) (local.get $span)
          (call $reason_make_opconstraint
            (local.get $op_str)
            (call $reason_make_inferred (i32.const 3552))    ;; "left"
            (call $reason_make_inferred (i32.const 3568))))  ;; "right"
        (call $graph_bind (local.get $handle)
          (call $ty_make_tvar (local.get $lh))
          (call $reason_make_located (local.get $span)
            (call $reason_make_opconstraint
              (local.get $op_str)
              (call $reason_make_inferred (i32.const 3584))   ;; "result"
              (call $reason_make_inferred (i32.const 3600))))) ;; "operand"
        (return (local.get $handle))))
    ;; BKCmp: BEq/BNe/BLt/BGt/BLe/BGe (145-150)
    (if (i32.le_u (local.get $op) (i32.const 150))
      (then
        (call $unify (local.get $lh) (local.get $rh) (local.get $span)
          (call $reason_make_opconstraint
            (local.get $op_str)
            (call $reason_make_inferred (i32.const 3552))
            (call $reason_make_inferred (i32.const 3568))))
        (call $graph_bind (local.get $handle)
          (call $ty_make_tname (i32.const 3504) (call $make_list (i32.const 0)))
          (call $reason_make_located (local.get $span)
            (call $reason_make_opconstraint
              (local.get $op_str)
              (call $reason_make_inferred (i32.const 3616))   ;; "comparison"
              (call $reason_make_inferred (i32.const 3504))))) ;; "Bool"
        (return (local.get $handle))))
    ;; BKBool: BAnd/BOr (151-152) — bind both sides + result to Bool
    (if (i32.le_u (local.get $op) (i32.const 152))
      (then
        (call $graph_bind (local.get $lh)
          (call $ty_make_tname (i32.const 3504) (call $make_list (i32.const 0)))
          (call $reason_make_located (local.get $span)
            (call $reason_make_opconstraint
              (local.get $op_str)
              (call $reason_make_inferred (i32.const 3552))
              (call $reason_make_inferred (i32.const 3504)))))
        (call $graph_bind (local.get $rh)
          (call $ty_make_tname (i32.const 3504) (call $make_list (i32.const 0)))
          (call $reason_make_located (local.get $span)
            (call $reason_make_opconstraint
              (local.get $op_str)
              (call $reason_make_inferred (i32.const 3568))
              (call $reason_make_inferred (i32.const 3504)))))
        (call $graph_bind (local.get $handle)
          (call $ty_make_tname (i32.const 3504) (call $make_list (i32.const 0)))
          (call $reason_make_located (local.get $span)
            (call $reason_make_opconstraint
              (local.get $op_str)
              (call $reason_make_inferred (i32.const 3584))
              (call $reason_make_inferred (i32.const 3504)))))
        (return (local.get $handle))))
    ;; BKConcat: BConcat (153)
    (call $unify (local.get $lh) (local.get $rh) (local.get $span)
      (call $reason_make_opconstraint
        (local.get $op_str)
        (call $reason_make_inferred (i32.const 3552))
        (call $reason_make_inferred (i32.const 3568))))
    (call $graph_bind (local.get $handle)
      (call $ty_make_tvar (local.get $lh))
      (call $reason_make_located (local.get $span)
        (call $reason_make_opconstraint
          (local.get $op_str)
          (call $reason_make_inferred (i32.const 3632))    ;; "concat"
          (call $reason_make_inferred (i32.const 3600)))))  ;; "operand"
    (local.get $handle))

  ;; UnaryOpExpr arm — src/infer.nx:509-513 + 1574-1583. Op is stored as
  ;; an opaque ptr (string today; may move to ADT later — peer follow-up
  ;; if so). Default arm: bind handle ↔ TVar(inner_h). The wheel's "Neg"/
  ;; "Not" string comparisons require a $str_eq surface that the seed
  ;; can't yet drive on a literal "Neg"/"Not" string-pointer (no data-
  ;; segment for them); seed treats every UnaryOp as "default" (TVar
  ;; transparent). Per Hβ.infer.unaryop-class peer follow-up.
  (func $infer_walk_expr_unaryop
        (export "infer_walk_expr_unaryop")
        (param $expr i32) (param $handle i32) (param $span i32)
        (result i32)
    (local $op i32) (local $inner i32) (local $ih i32)
    ;; Layout: [tag=87][op][inner]
    (local.set $op    (i32.load offset=4 (local.get $expr)))
    (local.set $inner (i32.load offset=8 (local.get $expr)))
    (drop (local.get $op))
    (local.set $ih (call $infer_walk_expr (local.get $inner)))
    (call $graph_bind (local.get $handle)
      (call $ty_make_tvar (local.get $ih))
      (call $reason_make_located (local.get $span)
        (call $reason_make_inferred (i32.const 3600))))   ;; "operand"
    (local.get $handle))

  ;; CallExpr arm — src/infer.nx:515-527 + 820-846.
  (func $infer_walk_expr_call
        (export "infer_walk_expr_call")
        (param $expr i32) (param $handle i32) (param $span i32)
        (result i32)
    (local $func i32) (local $args i32) (local $fh i32)
    (local $arg_handles i32) (local $params i32)
    (local $ret_h i32) (local $row_h i32)
    (local $expected i32) (local $expected_h i32)
    (local $cname i32)
    ;; Layout: [tag=88][callee][args]
    (local.set $func (i32.load offset=4 (local.get $expr)))
    (local.set $args (i32.load offset=8 (local.get $expr)))
    ;; Walk callee + collect arg handles via recursion.
    (local.set $fh (call $infer_walk_expr (local.get $func)))
    (local.set $arg_handles (call $walk_expr_collect_arg_handles (local.get $args)))
    (local.set $cname (call $walk_expr_callee_name (local.get $func)))
    ;; Mint fresh return handle + row handle
    (local.set $ret_h (call $graph_fresh_ty
      (call $reason_make_inferredcallreturn (local.get $cname)
        (call $reason_make_inferred (i32.const 3672)))))   ;; "return"
    (local.set $row_h (call $graph_fresh_row
      (call $reason_make_inferredcallreturn (local.get $cname)
        (call $reason_make_inferred (i32.const 3696)))))   ;; "effects"
    ;; Build expected TFun
    (local.set $params (call $walk_expr_build_inferred_params (local.get $arg_handles)))
    (local.set $expected (call $ty_make_tfun
      (local.get $params)
      (call $ty_make_tvar (local.get $ret_h))
      (local.get $row_h)))
    (local.set $expected_h (call $graph_fresh_ty
      (call $reason_make_inferredcallreturn (local.get $cname)
        (call $reason_make_inferred (i32.const 3720)))))   ;; "expected"
    (call $graph_bind
      (local.get $expected_h) (local.get $expected)
      (call $reason_make_located (local.get $span)
        (call $reason_make_inferredcallreturn (local.get $cname)
          (call $reason_make_inferred (i32.const 3720)))))
    ;; Unify the function-side handle with the expected TFun shape
    (call $unify (local.get $fh) (local.get $expected_h) (local.get $span)
      (call $reason_make_inferredcallreturn (local.get $cname)
        (call $reason_make_inferred (i32.const 3744))))    ;; "unification"
    ;; Bind result to TVar(ret_h)
    (call $graph_bind (local.get $handle)
      (call $ty_make_tvar (local.get $ret_h))
      (call $reason_make_located (local.get $span)
        (call $reason_make_inferredcallreturn (local.get $cname)
          (call $reason_make_inferred (i32.const 3584)))))  ;; "result"
    ;; Row composition: src/infer.nx:842-845 chases row_h + adds to caller.
    ;; SEED-STUB per Hβ.infer.row-normalize.
    (call $walk_expr_inf_add_row (local.get $row_h))
    (local.get $handle))

  ;; LambdaExpr arm — src/infer.nx:724-740. Builds TFun([], TVar(body_h),
  ;; row=fresh) at the seed; param-list typing/env-extend lives in the
  ;; wheel's mint_params path which depends on parser-emitted Param record
  ;; structure (Hβ.infer.lambda-params named follow-up). Per Drift 9
  ;; closure: arm binds the lambda handle even with empty params; future
  ;; commit fills the params.
  (func $infer_walk_expr_lambda
        (export "infer_walk_expr_lambda")
        (param $expr i32) (param $handle i32) (param $span i32)
        (result i32)
    (local $body_node i32) (local $bh i32)
    (local $row_h i32) (local $params i32)
    ;; Layout: [tag=89][params][body]
    (drop (i32.load offset=4 (local.get $expr)))   ;; params (Hβ.infer.lambda-params)
    (local.set $body_node (i32.load offset=8 (local.get $expr)))
    (call $env_scope_enter)
    (local.set $row_h (call $graph_fresh_row
      (call $reason_make_inferred (i32.const 3984))))   ;; "lambda"
    (call $walk_expr_inf_enter_fn (local.get $row_h) (local.get $span))
    (local.set $bh (call $infer_walk_expr (local.get $body_node)))
    (call $walk_expr_inf_exit_fn)
    (local.set $params (call $make_list (i32.const 0)))
    (call $graph_bind (local.get $handle)
      (call $ty_make_tfun
        (local.get $params)
        (call $ty_make_tvar (local.get $bh))
        (local.get $row_h))
      (call $reason_make_located (local.get $span)
        (call $reason_make_inferred (i32.const 3984))))   ;; "lambda"
    (call $env_scope_exit)
    (local.get $handle))

  ;; IfExpr arm — src/infer.nx:529-539. cond ↔ Bool; then/else unified;
  ;; result = TVar(then_h).
  (func $infer_walk_expr_if
        (export "infer_walk_expr_if")
        (param $expr i32) (param $handle i32) (param $span i32)
        (result i32)
    (local $cond i32) (local $then_e i32) (local $else_e i32)
    (local $ch i32) (local $th i32) (local $eh i32)
    ;; Layout: [tag=90][cond][then][else]
    (local.set $cond   (i32.load offset=4  (local.get $expr)))
    (local.set $then_e (i32.load offset=8  (local.get $expr)))
    (local.set $else_e (i32.load offset=12 (local.get $expr)))
    (local.set $ch (call $infer_walk_expr (local.get $cond)))
    (local.set $th (call $infer_walk_expr (local.get $then_e)))
    (local.set $eh (call $infer_walk_expr (local.get $else_e)))
    ;; cond ↔ Bool
    (call $graph_bind (local.get $ch)
      (call $ty_make_tname (i32.const 3504) (call $make_list (i32.const 0)))
      (call $reason_make_located (local.get $span)
        (call $reason_make_inferred (i32.const 3768))))   ;; "if condition"
    ;; then/else unified
    (call $unify (local.get $th) (local.get $eh) (local.get $span)
      (call $reason_make_ifbranch
        (call $reason_make_inferred (i32.const 3792))))   ;; "if branches"
    ;; result type
    (call $graph_bind (local.get $handle)
      (call $ty_make_tvar (local.get $th))
      (call $reason_make_located (local.get $span)
        (call $reason_make_ifbranch
          (call $reason_make_inferred (i32.const 3816))))) ;; "if result"
    (local.get $handle))

  ;; BlockExpr arm — src/infer.nx:541-548. stmts walked via forward-
  ;; declared $infer_stmt_list; final_expr walked normally; block type =
  ;; TVar(final_expr_h).
  ;;
  ;; Forward-decl: $infer_stmt_list lands in walk_stmt.wat per Hβ.infer
  ;; §13.3 #9 (peer Tier 7 chunk; NOT silent deferral). Until walk_stmt
  ;; lands the seed binds the block as TVar(final_h) without having
  ;; processed the stmts — degenerate but type-sound for blocks whose
  ;; stmts don't shadow names used in final_expr (which is the common
  ;; case). The peer chunk's call site is parameterized by the stmts list
  ;; from offset 4.
  (func $infer_walk_expr_block
        (export "infer_walk_expr_block")
        (param $expr i32) (param $handle i32) (param $span i32)
        (result i32)
    (local $stmts i32) (local $final_e i32) (local $fh i32)
    ;; Layout: [tag=91][stmts][final_expr]
    (local.set $stmts   (i32.load offset=4 (local.get $expr)))
    (local.set $final_e (i32.load offset=8 (local.get $expr)))
    (call $env_scope_enter)
    ;; walk_stmt.wat peer chunk now landed (Hβ.infer §13.3 #9 closed):
    ;; walk the block's stmts so their let-extends populate env before
    ;; final_expr's VarRefs read.
    (call $infer_stmt_list (local.get $stmts))
    (local.set $fh (call $infer_walk_expr (local.get $final_e)))
    (call $graph_bind (local.get $handle)
      (call $ty_make_tvar (local.get $fh))
      (call $reason_make_located (local.get $span)
        (call $reason_make_inferred (i32.const 3840))))   ;; "block result"
    (call $env_scope_exit)
    (local.get $handle))

  ;; ─── $infer_walk_pat — Phase B.5 ultimate-form pattern walk ─────────
  ;;
  ;; Recursive constructor-aware pattern walker. Dispatches on Pat tag
  ;; (130-136 per parser_pat.wat). Called from MatchExpr arms + LetStmt.
  ;;
  ;; Eight interrogations:
  ;;   1. Graph:      PCon unifies ctor result type with scrut_h.
  ;;   2. Handler:    Direct seed call, recursive.
  ;;   3. Verb:       N/A — structural.
  ;;   4. Row:        Opaque per Hβ.infer.row-normalize.
  ;;   5. Ownership:  Patterns INTRODUCE names (env_extend). No Consume.
  ;;   6. Refinement: PCon carries tag_id via ConstructorScheme.
  ;;   7. Gradient:   PVar is Forall([], TVar(h)) — monomorphic pin.
  ;;   8. Reason:     PVar: Located(span, LetBinding(name, Inferred("pattern"))).
  ;;
  ;; Drift-6 closure: Bool match through PLit(LVBool), not PCon.
  ;; Same dispatch path as any other literal pattern.
  ;;
  ;; Exports: $infer_walk_pat (called from walk_stmt.wat LetStmt arm).
  (func $infer_walk_pat
        (export "infer_walk_pat")
        (param $pat i32) (param $scrut_h i32) (param $span i32)
    (local $tag i32) (local $name i32) (local $reason i32)
    (local $ctor_name i32) (local $sub_pats i32)
    (local $binding i32) (local $scheme i32)
    (local $ctor_ty i32) (local $ctor_tag i32)
    (local $params i32) (local $result_ty i32) (local $result_h i32)
    (local $n_params i32) (local $n_subs i32) (local $min_n i32)
    (local $i i32) (local $sub_pat i32) (local $sub_h i32)
    (local $tparam i32) (local $tp_ty i32)
    (local $lit_val i32) (local $lit_tag i32)
    (local $elems i32) (local $n_elems i32) (local $elem_h i32)
    ;; PWild sentinel (131) — no binding, no unification.
    (if (i32.eq (local.get $pat) (i32.const 131))
      (then (return)))
    ;; Below HEAP_BASE and not PWild → unknown sentinel; no-op.
    (if (i32.lt_u (local.get $pat) (global.get $heap_base))
      (then (return)))
    (local.set $tag (call $tag_of (local.get $pat)))
    ;; ── PVar (130) ──────────────────────────────────────────────
    (if (i32.eq (local.get $tag) (i32.const 130))
      (then
        (local.set $name (i32.load offset=4 (local.get $pat)))
        (local.set $reason (call $reason_make_located
          (local.get $span)
          (call $reason_make_letbinding (local.get $name)
            (call $reason_make_inferred (i32.const 4032)))))  ;; "pattern"
        (call $env_extend
          (local.get $name)
          (call $scheme_make_forall
            (call $make_list (i32.const 0))
            (call $ty_make_tvar (local.get $scrut_h)))
          (local.get $reason)
          (call $schemekind_make_fn))
        (return)))
    ;; ── PLit (132) ──────────────────────────────────────────────
    (if (i32.eq (local.get $tag) (i32.const 132))
      (then
        (local.set $lit_val (i32.load offset=4 (local.get $pat)))
        (local.set $lit_tag (call $tag_of (local.get $lit_val)))
        (local.set $reason (call $reason_make_located
          (local.get $span)
          (call $reason_make_inferred (i32.const 4032))))  ;; "pattern"
        (if (i32.eq (local.get $lit_tag) (i32.const 180))  ;; LVInt
          (then
            (call $graph_bind (local.get $scrut_h)
              (call $ty_make_tint) (local.get $reason))
            (return)))
        (if (i32.eq (local.get $lit_tag) (i32.const 181))  ;; LVFloat
          (then
            (call $graph_bind (local.get $scrut_h)
              (call $ty_make_tfloat) (local.get $reason))
            (return)))
        (if (i32.eq (local.get $lit_tag) (i32.const 182))  ;; LVString
          (then
            (call $graph_bind (local.get $scrut_h)
              (call $ty_make_tstring) (local.get $reason))
            (return)))
        (if (i32.eq (local.get $lit_tag) (i32.const 183))  ;; LVBool
          (then
            (call $graph_bind (local.get $scrut_h)
              (call $ty_make_tname (i32.const 3504)
                (call $make_list (i32.const 0)))
              (local.get $reason))
            (return)))
        (return)))
    ;; ── PCon (133) — constructor-aware pattern ──────────────────
    (if (i32.eq (local.get $tag) (i32.const 133))
      (then
        (local.set $ctor_name (i32.load offset=4 (local.get $pat)))
        (local.set $sub_pats (i32.load offset=8 (local.get $pat)))
        (local.set $binding (call $env_lookup (local.get $ctor_name)))
        (if (i32.eqz (local.get $binding))
          (then
            ;; Constructor not in env — walk sub_pats with fresh handles
            ;; (productive-under-error: inner PVar bindings still land).
            (local.set $n_subs (call $len (local.get $sub_pats)))
            (local.set $i (i32.const 0))
            (block $miss_done
              (loop $miss_each
                (br_if $miss_done
                  (i32.ge_u (local.get $i) (local.get $n_subs)))
                (local.set $sub_h (call $graph_fresh_ty
                  (call $reason_make_inferred (i32.const 4032))))
                (call $infer_walk_pat
                  (call $list_index (local.get $sub_pats) (local.get $i))
                  (local.get $sub_h) (local.get $span))
                (local.set $i (i32.add (local.get $i) (i32.const 1)))
                (br $miss_each)))
            (return)))
        ;; Found — instantiate constructor's scheme.
        (local.set $scheme
          (call $env_binding_scheme (local.get $binding)))
        (local.set $ctor_ty (call $instantiate (local.get $scheme)))
        (local.set $ctor_tag (call $ty_tag (local.get $ctor_ty)))
        (local.set $reason (call $reason_make_located
          (local.get $span)
          (call $reason_make_declared (local.get $ctor_name))))
        ;; N-ary constructor: TFun(params, result_ty, row)
        (if (i32.eq (local.get $ctor_tag) (i32.const 107))
          (then
            ;; Unify result type with scrutinee.
            (local.set $result_ty
              (call $ty_tfun_return (local.get $ctor_ty)))
            (local.set $result_h
              (call $graph_fresh_ty (local.get $reason)))
            (call $graph_bind (local.get $result_h)
              (local.get $result_ty) (local.get $reason))
            (call $unify (local.get $result_h) (local.get $scrut_h)
              (local.get $span) (local.get $reason))
            ;; Walk sub-patterns with constructor field types.
            (local.set $params
              (call $ty_tfun_params (local.get $ctor_ty)))
            (local.set $n_params (call $len (local.get $params)))
            (local.set $n_subs (call $len (local.get $sub_pats)))
            (local.set $min_n (local.get $n_params))
            (if (i32.lt_u (local.get $n_subs) (local.get $min_n))
              (then (local.set $min_n (local.get $n_subs))))
            (local.set $i (i32.const 0))
            (block $con_done
              (loop $con_each
                (br_if $con_done
                  (i32.ge_u (local.get $i) (local.get $min_n)))
                (local.set $tparam
                  (call $list_index (local.get $params) (local.get $i)))
                (local.set $tp_ty
                  (call $tparam_ty (local.get $tparam)))
                (local.set $sub_h
                  (call $graph_fresh_ty (local.get $reason)))
                (call $graph_bind (local.get $sub_h)
                  (local.get $tp_ty) (local.get $reason))
                (call $infer_walk_pat
                  (call $list_index
                    (local.get $sub_pats) (local.get $i))
                  (local.get $sub_h) (local.get $span))
                (local.set $i
                  (i32.add (local.get $i) (i32.const 1)))
                (br $con_each)))
            (return)))
        ;; Nullary constructor: unify ctor_ty with scrutinee.
        (local.set $result_h
          (call $graph_fresh_ty (local.get $reason)))
        (call $graph_bind (local.get $result_h)
          (local.get $ctor_ty) (local.get $reason))
        (call $unify (local.get $result_h) (local.get $scrut_h)
          (local.get $span) (local.get $reason))
        (return)))
    ;; ── PTuple (134) ────────────────────────────────────────────
    (if (i32.eq (local.get $tag) (i32.const 134))
      (then
        (local.set $elems (i32.load offset=4 (local.get $pat)))
        (local.set $n_elems (call $len (local.get $elems)))
        (local.set $params (call $make_list (i32.const 0)))
        (local.set $params
          (call $list_extend_to (local.get $params) (local.get $n_elems)))
        (local.set $i (i32.const 0))
        (block $tup_done
          (loop $tup_each
            (br_if $tup_done
              (i32.ge_u (local.get $i) (local.get $n_elems)))
            (local.set $elem_h (call $graph_fresh_ty
              (call $reason_make_inferred (i32.const 4032))))
            (call $infer_walk_pat
              (call $list_index (local.get $elems) (local.get $i))
              (local.get $elem_h) (local.get $span))
            (drop (call $list_set (local.get $params) (local.get $i)
              (call $ty_make_tvar (local.get $elem_h))))
            (local.set $i (i32.add (local.get $i) (i32.const 1)))
            (br $tup_each)))
        (local.set $result_h (call $graph_fresh_ty
          (call $reason_make_inferred (i32.const 4032))))
        (call $graph_bind (local.get $result_h)
          (call $ty_make_ttuple (local.get $params))
          (call $reason_make_located (local.get $span)
            (call $reason_make_inferred (i32.const 4032))))
        (call $unify (local.get $result_h) (local.get $scrut_h)
          (local.get $span)
          (call $reason_make_located (local.get $span)
            (call $reason_make_inferred (i32.const 4032))))
        (return)))
    ;; ── PList (135) ─────────────────────────────────────────────
    (if (i32.eq (local.get $tag) (i32.const 135))
      (then
        (local.set $elems (i32.load offset=4 (local.get $pat)))
        (local.set $n_elems (call $len (local.get $elems)))
        (local.set $elem_h (call $graph_fresh_ty
          (call $reason_make_inferred (i32.const 4032))))
        (local.set $i (i32.const 0))
        (block $list_done
          (loop $list_each
            (br_if $list_done
              (i32.ge_u (local.get $i) (local.get $n_elems)))
            (call $infer_walk_pat
              (call $list_index (local.get $elems) (local.get $i))
              (local.get $elem_h) (local.get $span))
            (local.set $i (i32.add (local.get $i) (i32.const 1)))
            (br $list_each)))
        (local.set $result_h (call $graph_fresh_ty
          (call $reason_make_inferred (i32.const 4032))))
        (call $graph_bind (local.get $result_h)
          (call $ty_make_tlist
            (call $ty_make_tvar (local.get $elem_h)))
          (call $reason_make_located (local.get $span)
            (call $reason_make_inferred (i32.const 4032))))
        (call $unify (local.get $result_h) (local.get $scrut_h)
          (local.get $span)
          (call $reason_make_located (local.get $span)
            (call $reason_make_inferred (i32.const 4032))))
        (return)))
    ;; ── PRecord (136) — peer follow-up Hβ.infer.walk_pat.record ─
    ;; Record pattern field-name matching deferred to peer cascade.
    )

  ;; MatchExpr arm — src/infer.nx:550-553 + 1701-1733. Walks scrutinee +
  ;; each arm-body; pattern walk via $infer_walk_pat (B.5 landed);
  ;; exhaustiveness check (Hβ.infer.match-exhaustive) is a named follow-up.
  (func $infer_walk_expr_match
        (export "infer_walk_expr_match")
        (param $expr i32) (param $handle i32) (param $span i32)
        (result i32)
    (local $scrut i32) (local $arms i32) (local $sh i32)
    ;; Layout: [tag=92][scrut][arms]
    (local.set $scrut (i32.load offset=4 (local.get $expr)))
    (local.set $arms  (i32.load offset=8 (local.get $expr)))
    (local.set $sh (call $infer_walk_expr (local.get $scrut)))
    (call $infer_walk_expr_match_arms
      (local.get $arms) (local.get $handle) (local.get $sh)
      (local.get $span))
    (local.get $handle))

  ;; MatchExpr arms iterator — for each arm: scope_enter, walk pattern
  ;; via $infer_walk_pat (B.5), walk arm-body, unify body_h ↔ result_h,
  ;; scope_exit. Mirrors src/infer.nx:1721-1731.
  ;; Arms are 2-tuple lists (pat, body) per parser_pat.wat:357-360.
  (func $infer_walk_expr_match_arms
        (export "infer_walk_expr_match_arms")
        (param $arms i32) (param $result_h i32) (param $scrut_h i32)
        (param $span i32)
    (local $n i32) (local $i i32)
    (local $arm i32) (local $pat i32) (local $body i32)
    (local $bh i32) (local $first i32)
    (local.set $n (call $len (local.get $arms)))
    (local.set $i (i32.const 0))
    (local.set $first (i32.const 1))
    (block $done
      (loop $each
        (br_if $done (i32.ge_u (local.get $i) (local.get $n)))
        (local.set $arm (call $list_index (local.get $arms) (local.get $i)))
        (call $env_scope_enter)
        ;; Walk pattern — binds PVar names into this arm's scope.
        (local.set $pat
          (call $list_index (local.get $arm) (i32.const 0)))
        (call $infer_walk_pat
          (local.get $pat) (local.get $scrut_h) (local.get $span))
        ;; Walk body.
        (local.set $body
          (call $list_index (local.get $arm) (i32.const 1)))
        (local.set $bh (call $infer_walk_expr (local.get $body)))
        ;; First arm: bind result_h ↔ TVar(first_arm_h). Subsequent: unify.
        (if (local.get $first)
          (then
            (call $graph_bind (local.get $result_h)
              (call $ty_make_tvar (local.get $bh))
              (call $reason_make_located (local.get $span)
                (call $reason_make_matchbranch
                  (call $reason_make_inferred (i32.const 3864))   ;; "arm body"
                  (call $reason_make_inferred (i32.const 3584))))) ;; "result"
            (local.set $first (i32.const 0)))
          (else
            (call $unify (local.get $bh) (local.get $result_h)
              (local.get $span)
              (call $reason_make_matchbranch
                (call $reason_make_inferred (i32.const 3864))
                (call $reason_make_inferred (i32.const 3584))))))
        (call $env_scope_exit)
        (local.set $i (i32.add (local.get $i) (i32.const 1)))
        (br $each))))

  ;; HandleExpr arm — src/infer.nx:623-695. Body walked + arms walked +
  ;; arm-bodies unified to body_h. Row absorption, region tracking, and
  ;; handler-uninstallable check are seed-stubs per Hβ.infer.row-normalize
  ;; / .handler-stack / .region-tracker named follow-ups.
  (func $infer_walk_expr_handle
        (export "infer_walk_expr_handle")
        (param $expr i32) (param $handle i32) (param $span i32)
        (result i32)
    (local $body_node i32) (local $arms i32) (local $bh i32)
    (local $body_row_h i32) (local $arm_row_h i32)
    ;; Layout: [tag=93][body][arms]
    (local.set $body_node (i32.load offset=4 (local.get $expr)))
    (local.set $arms      (i32.load offset=8 (local.get $expr)))
    ;; handler-stack push (seed-stub)
    (call $walk_expr_inf_push_handler
      (call $walk_expr_collect_handled_effects (local.get $arms)))
    ;; Body inference under its own row scope (seed-stub)
    (local.set $body_row_h (call $graph_fresh_row
      (call $reason_make_inferred (i32.const 3696))))   ;; "effects"
    (call $walk_expr_inf_enter_fn (local.get $body_row_h) (local.get $span))
    (local.set $bh (call $infer_walk_expr (local.get $body_node)))
    (call $walk_expr_inf_exit_fn)
    ;; Arms inference
    (local.set $arm_row_h (call $graph_fresh_row
      (call $reason_make_inferred (i32.const 3696))))
    (call $walk_expr_inf_enter_fn (local.get $arm_row_h) (local.get $span))
    (call $walk_expr_handle_arm_iter
      (local.get $arms) (local.get $bh) (local.get $span))
    (call $walk_expr_inf_exit_fn)
    ;; handler-stack pop
    (call $walk_expr_inf_pop_handler)
    ;; Handle expression's TYPE = body's type
    (call $graph_bind (local.get $handle)
      (call $ty_make_tvar (local.get $bh))
      (call $reason_make_located (local.get $span)
        (call $reason_make_inferred (i32.const 3584))))   ;; "result"
    (local.get $handle))

  ;; PerformExpr arm — src/infer.nx:618-621 + 852-876. env_lookup the op;
  ;; on miss emit_missing_var; on hit instantiate scheme + walk args +
  ;; bind handle to scheme's return type.
  (func $infer_walk_expr_perform
        (export "infer_walk_expr_perform")
        (param $expr i32) (param $handle i32) (param $span i32)
        (result i32)
    (local $op_name i32) (local $args i32) (local $arg_handles i32)
    (local $binding i32) (local $scheme i32) (local $reason i32)
    (local $op_ty i32) (local $tag i32)
    ;; Layout: [tag=94][op_name][args]
    (local.set $op_name (i32.load offset=4 (local.get $expr)))
    (local.set $args    (i32.load offset=8 (local.get $expr)))
    (local.set $arg_handles (call $walk_expr_collect_arg_handles (local.get $args)))
    (drop (local.get $arg_handles))
    (local.set $binding (call $env_lookup (local.get $op_name)))
    (if (i32.eqz (local.get $binding))
      (then
        (call $infer_emit_missing_var
          (local.get $handle) (local.get $op_name)
          (call $reason_make_located (local.get $span)
            (call $reason_make_inferred (i32.const 3520))))   ;; "var ref"
        (return (local.get $handle))))
    (local.set $scheme (call $env_binding_scheme (local.get $binding)))
    (local.set $reason (call $env_binding_reason (local.get $binding)))
    (local.set $op_ty  (call $instantiate (local.get $scheme)))
    (local.set $tag (call $ty_tag (local.get $op_ty)))
    ;; If TFun (107), bind to its return type. Else bind to op_ty directly.
    (if (i32.eq (local.get $tag) (i32.const 107))
      (then
        (call $graph_bind (local.get $handle)
          (call $record_get (local.get $op_ty) (i32.const 1))   ;; ty_tfun_return
          (call $reason_make_located (local.get $span)
            (call $reason_make_varlookup (local.get $op_name) (local.get $reason))))
        ;; Row composition (seed-stub): row at offset 2 of TFun.
        (call $walk_expr_inf_add_row
          (call $record_get (local.get $op_ty) (i32.const 2))))
      (else
        (call $graph_bind (local.get $handle)
          (local.get $op_ty)
          (call $reason_make_located (local.get $span)
            (call $reason_make_varlookup (local.get $op_name) (local.get $reason))))))
    (local.get $handle))

  ;; ResumeExpr arm — src/infer.nx:697-701. Walk val; bind handle to TUnit.
  (func $infer_walk_expr_resume
        (export "infer_walk_expr_resume")
        (param $expr i32) (param $handle i32) (param $span i32)
        (result i32)
    (local $val i32) (local $vh i32)
    ;; Layout: [tag=95][val][state_updates] — second field unused at seed
    (local.set $val (i32.load offset=4 (local.get $expr)))
    (local.set $vh (call $infer_walk_expr (local.get $val)))
    (drop (local.get $vh))
    (call $graph_bind (local.get $handle)
      (call $ty_make_tunit)
      (call $reason_make_located (local.get $span)
        (call $reason_make_inferred (i32.const 3480))))   ;; "unit"
    (local.get $handle))

  ;; MakeListExpr arm — src/infer.nx:556-569. Empty: TList(TVar(fresh)).
  ;; Non-empty: unify all elements to first; bind to TList(TVar(first_h)).
  (func $infer_walk_expr_make_list
        (export "infer_walk_expr_make_list")
        (param $expr i32) (param $handle i32) (param $span i32)
        (result i32)
    (local $elems i32) (local $n i32) (local $i i32)
    (local $first i32) (local $fh i32)
    (local $elem i32) (local $eh i32) (local $elem_h i32)
    ;; Layout: [tag=96][elems]
    (local.set $elems (i32.load offset=4 (local.get $expr)))
    (local.set $n (call $len (local.get $elems)))
    (if (i32.eqz (local.get $n))
      (then
        (local.set $elem_h (call $graph_fresh_ty
          (call $reason_make_inferred (i32.const 3960))))   ;; "empty list"
        (call $graph_bind (local.get $handle)
          (call $ty_make_tlist (call $ty_make_tvar (local.get $elem_h)))
          (call $reason_make_located (local.get $span)
            (call $reason_make_inferred (i32.const 3960))))   ;; "empty list"
        (return (local.get $handle))))
    ;; Non-empty: walk first
    (local.set $first (call $list_index (local.get $elems) (i32.const 0)))
    (local.set $fh (call $infer_walk_expr (local.get $first)))
    ;; Walk + unify rest
    (local.set $i (i32.const 1))
    (block $done
      (loop $each
        (br_if $done (i32.ge_u (local.get $i) (local.get $n)))
        (local.set $elem (call $list_index (local.get $elems) (local.get $i)))
        (local.set $eh (call $infer_walk_expr (local.get $elem)))
        (call $unify (local.get $eh) (local.get $fh) (local.get $span)
          (call $reason_make_listelement
            (call $reason_make_inferred (i32.const 3936))))   ;; "list result"
        (local.set $i (i32.add (local.get $i) (i32.const 1)))
        (br $each)))
    (call $graph_bind (local.get $handle)
      (call $ty_make_tlist (call $ty_make_tvar (local.get $fh)))
      (call $reason_make_located (local.get $span)
        (call $reason_make_inferred (i32.const 3936))))   ;; "list result"
    (local.get $handle))

  ;; MakeTupleExpr arm — src/infer.nx:571-575.
  (func $infer_walk_expr_make_tuple
        (export "infer_walk_expr_make_tuple")
        (param $expr i32) (param $handle i32) (param $span i32)
        (result i32)
    (local $elems i32) (local $n i32) (local $i i32)
    (local $tvar_list i32) (local $elem i32) (local $eh i32)
    ;; Layout: [tag=97][elems]
    (local.set $elems (i32.load offset=4 (local.get $expr)))
    (local.set $n (call $len (local.get $elems)))
    (local.set $tvar_list (call $make_list (i32.const 0)))
    (local.set $tvar_list (call $list_extend_to (local.get $tvar_list) (local.get $n)))
    (local.set $i (i32.const 0))
    (block $done
      (loop $each
        (br_if $done (i32.ge_u (local.get $i) (local.get $n)))
        (local.set $elem (call $list_index (local.get $elems) (local.get $i)))
        (local.set $eh (call $infer_walk_expr (local.get $elem)))
        (drop (call $list_set (local.get $tvar_list) (local.get $i)
                              (call $ty_make_tvar (local.get $eh))))
        (local.set $i (i32.add (local.get $i) (i32.const 1)))
        (br $each)))
    (call $graph_bind (local.get $handle)
      (call $ty_make_ttuple (local.get $tvar_list))
      (call $reason_make_located (local.get $span)
        (call $reason_make_inferred (i32.const 3912))))   ;; "tuple result"
    (local.get $handle))

  ;; MakeRecordExpr arm — src/infer.nx:577-587. Builds a list of
  ;; (name, TVar(value_h)) field-pair records and binds to TRecord.
  ;; Parser pre-sorts fields per src/parser.nx.
  (func $infer_walk_expr_make_record
        (export "infer_walk_expr_make_record")
        (param $expr i32) (param $handle i32) (param $span i32)
        (result i32)
    (local $fields i32) (local $n i32) (local $i i32)
    (local $field_pair_list i32) (local $entry i32)
    (local $name i32) (local $val_node i32) (local $vh i32)
    (local $fp i32)
    ;; Layout: [tag=98][fields]; each fields entry is a (name, val_node)
    ;; pair record in tparam.wat's field-pair shape (FIELD_PAIR=203) —
    ;; parser emits ([name_str, value_node]) per src/parser.nx.
    (local.set $fields (i32.load offset=4 (local.get $expr)))
    (local.set $n (call $len (local.get $fields)))
    (local.set $field_pair_list (call $make_list (i32.const 0)))
    (local.set $field_pair_list
      (call $list_extend_to (local.get $field_pair_list) (local.get $n)))
    (local.set $i (i32.const 0))
    (block $done
      (loop $each
        (br_if $done (i32.ge_u (local.get $i) (local.get $n)))
        (local.set $entry (call $list_index (local.get $fields) (local.get $i)))
        (local.set $name     (call $record_get (local.get $entry) (i32.const 0)))
        (local.set $val_node (call $record_get (local.get $entry) (i32.const 1)))
        (local.set $vh (call $infer_walk_expr (local.get $val_node)))
        (local.set $fp (call $field_pair_make
          (local.get $name)
          (call $ty_make_tvar (local.get $vh))))
        (drop (call $list_set (local.get $field_pair_list)
                              (local.get $i) (local.get $fp)))
        (local.set $i (i32.add (local.get $i) (i32.const 1)))
        (br $each)))
    (call $graph_bind (local.get $handle)
      (call $ty_make_trecord (local.get $field_pair_list))
      (call $reason_make_located (local.get $span)
        (call $reason_make_inferred (i32.const 3888))))   ;; "record result"
    (local.get $handle))

  ;; NamedRecordExpr arm — src/infer.nx:589-616. env_lookup the type name;
  ;; on miss emit_missing_var; on hit non-RecordSchemeKind emit_not_a_
  ;; record_type; on hit record-shape, walk fields + bind handle to
  ;; TName(type_name, []). Field validation against declared (extra/
  ;; missing) is named follow-up Hβ.infer.named-record-validate.
  (func $infer_walk_expr_named_record
        (export "infer_walk_expr_named_record")
        (param $expr i32) (param $handle i32) (param $span i32)
        (result i32)
    (local $type_name i32) (local $fields i32)
    (local $n i32) (local $i i32) (local $entry i32) (local $val_node i32)
    (local $binding i32)
    ;; Layout: [tag=99][type_name][fields]
    (local.set $type_name (i32.load offset=4 (local.get $expr)))
    (local.set $fields    (i32.load offset=8 (local.get $expr)))
    (local.set $binding (call $env_lookup (local.get $type_name)))
    (if (i32.eqz (local.get $binding))
      (then
        (call $infer_emit_missing_var
          (local.get $handle) (local.get $type_name)
          (call $reason_make_located (local.get $span)
            (call $reason_make_inferred (i32.const 3888))))   ;; "record result"
        (return (local.get $handle))))
    ;; Walk every field value (regardless of kind validation).
    (local.set $n (call $len (local.get $fields)))
    (local.set $i (i32.const 0))
    (block $done
      (loop $each
        (br_if $done (i32.ge_u (local.get $i) (local.get $n)))
        (local.set $entry (call $list_index (local.get $fields) (local.get $i)))
        (local.set $val_node (call $record_get (local.get $entry) (i32.const 1)))
        (drop (call $infer_walk_expr (local.get $val_node)))
        (local.set $i (i32.add (local.get $i) (i32.const 1)))
        (br $each)))
    ;; Per Hβ.infer.named-record-validate: seed binds without exhaustive
    ;; check. Field-extra / field-missing diagnostics land in the named
    ;; follow-up via emit_diag.wat's already-landed helpers.
    (call $graph_bind (local.get $handle)
      (call $ty_make_tname (local.get $type_name) (call $make_list (i32.const 0)))
      (call $reason_make_located (local.get $span)
        (call $reason_make_inferred (i32.const 3888))))   ;; "record result"
    (local.get $handle))

  ;; FieldExpr arm — src/infer.nx:703-722 + 771-781. Treats every
  ;; FieldExpr as record-field access. Dotted-name fallback (src/infer.nx
  ;; :710-722) is named follow-up Hβ.infer.qualified-name.
  (func $infer_walk_expr_field
        (export "infer_walk_expr_field")
        (param $expr i32) (param $handle i32) (param $span i32)
        (result i32)
    (local $rec i32) (local $field i32) (local $rh i32)
    (local $field_h i32) (local $row_h i32)
    (local $expected i32) (local $expected_h i32)
    (local $field_pair_list i32) (local $fp i32)
    ;; Layout: [tag=100][rec][field]
    (local.set $rec   (i32.load offset=4 (local.get $expr)))
    (local.set $field (i32.load offset=8 (local.get $expr)))
    (local.set $rh (call $infer_walk_expr (local.get $rec)))
    (local.set $field_h (call $graph_fresh_ty
      (call $reason_make_inferred (i32.const 3888))))   ;; "record result"
    (local.set $row_h (call $graph_fresh_row
      (call $reason_make_inferred (i32.const 3696))))   ;; "effects"
    ;; Build TRecordOpen([(field, TVar(field_h))], row_h)
    (local.set $fp (call $field_pair_make
      (local.get $field) (call $ty_make_tvar (local.get $field_h))))
    (local.set $field_pair_list (call $make_list (i32.const 0)))
    (local.set $field_pair_list
      (call $list_extend_to (local.get $field_pair_list) (i32.const 1)))
    (drop (call $list_set (local.get $field_pair_list)
                          (i32.const 0) (local.get $fp)))
    (local.set $expected
      (call $ty_make_trecordopen (local.get $field_pair_list) (local.get $row_h)))
    (local.set $expected_h (call $graph_fresh_ty
      (call $reason_make_inferred (i32.const 3720))))   ;; "expected"
    (call $graph_bind (local.get $expected_h) (local.get $expected)
      (call $reason_make_located (local.get $span)
        (call $reason_make_inferred (i32.const 3720))))
    (call $unify (local.get $rh) (local.get $expected_h) (local.get $span)
      (call $reason_make_inferred (i32.const 3744)))   ;; "unification"
    (call $graph_bind (local.get $handle)
      (call $ty_make_tvar (local.get $field_h))
      (call $reason_make_located (local.get $span)
        (call $reason_make_inferred (i32.const 3888))))   ;; "record result"
    (local.get $handle))

  ;; ─── PipeExpr — five-verb dispatch ────────────────────────────────────
  ;; src/infer.nx:742-755 + 898-974. Dispatches on PipeKind tag (160-165).
  ;; Per spec 10 + Hβ-infer §4.3 production pattern 4.

  (func $infer_walk_expr_pipe
        (export "infer_walk_expr_pipe")
        (param $expr i32) (param $handle i32) (param $span i32)
        (result i32)
    (local $kind i32) (local $left i32) (local $right i32)
    ;; Layout: [tag=101][kind][left][right]
    (local.set $kind  (i32.load offset=4  (local.get $expr)))
    (local.set $left  (i32.load offset=8  (local.get $expr)))
    (local.set $right (i32.load offset=12 (local.get $expr)))
    ;; PForward (160)
    (if (i32.eq (local.get $kind) (i32.const 160))
      (then (return (call $infer_walk_expr_pipe_forward
                          (local.get $left) (local.get $right)
                          (local.get $handle) (local.get $span)))))
    ;; PDiverge (161)
    (if (i32.eq (local.get $kind) (i32.const 161))
      (then (return (call $infer_walk_expr_pipe_diverge
                          (local.get $left) (local.get $right)
                          (local.get $handle) (local.get $span)))))
    ;; PCompose (162)
    (if (i32.eq (local.get $kind) (i32.const 162))
      (then (return (call $infer_walk_expr_pipe_compose
                          (local.get $left) (local.get $right)
                          (local.get $handle) (local.get $span)))))
    ;; PTeeBlock (163) / PTeeInline (164) — same shape per src/infer.nx:944-955
    (if (i32.eq (local.get $kind) (i32.const 163))
      (then (return (call $infer_walk_expr_pipe_tee
                          (local.get $left) (local.get $right)
                          (local.get $handle) (local.get $span)))))
    (if (i32.eq (local.get $kind) (i32.const 164))
      (then (return (call $infer_walk_expr_pipe_tee
                          (local.get $left) (local.get $right)
                          (local.get $handle) (local.get $span)))))
    ;; PFeedback (165)
    (if (i32.eq (local.get $kind) (i32.const 165))
      (then (return (call $infer_walk_expr_pipe_feedback
                          (local.get $left) (local.get $right)
                          (local.get $handle) (local.get $span)))))
    ;; Unknown PipeKind — H6 wildcard discipline: trap.
    (unreachable))

  ;; PForward (|>) — src/infer.nx:907-925.
  (func $infer_walk_expr_pipe_forward
        (export "infer_walk_expr_pipe_forward")
        (param $left i32) (param $right i32)
        (param $handle i32) (param $span i32)
        (result i32)
    (local $lh i32) (local $rh i32)
    (local $ret_h i32) (local $row_h i32)
    (local $param i32) (local $param_list i32)
    (local $expected i32) (local $expected_h i32)
    (local $pipe_str i32)
    (local.set $lh (call $infer_walk_expr (local.get $left)))
    (local.set $rh (call $infer_walk_expr (local.get $right)))
    (local.set $pipe_str (call $int_to_str (i32.const 160)))
    (local.set $ret_h (call $graph_fresh_ty
      (call $reason_make_inferredpiperesult (local.get $pipe_str)
        (call $reason_make_inferred (i32.const 3672)))))   ;; "return"
    (local.set $row_h (call $graph_fresh_row
      (call $reason_make_inferredpiperesult (local.get $pipe_str)
        (call $reason_make_inferred (i32.const 3696)))))   ;; "effects"
    ;; Build [TParam("_", TVar(lh), Inferred, Inferred)]
    (local.set $param (call $tparam_make
      (call $str_alloc (i32.const 0))
      (call $ty_make_tvar (local.get $lh))
      (call $ownership_make_inferred)
      (call $ownership_make_inferred)))
    (local.set $param_list (call $make_list (i32.const 0)))
    (local.set $param_list (call $list_extend_to (local.get $param_list) (i32.const 1)))
    (drop (call $list_set (local.get $param_list) (i32.const 0) (local.get $param)))
    (local.set $expected (call $ty_make_tfun
      (local.get $param_list)
      (call $ty_make_tvar (local.get $ret_h))
      (local.get $row_h)))
    (local.set $expected_h (call $graph_fresh_ty
      (call $reason_make_inferredpiperesult (local.get $pipe_str)
        (call $reason_make_inferred (i32.const 3720)))))   ;; "expected"
    (call $graph_bind (local.get $expected_h) (local.get $expected)
      (call $reason_make_located (local.get $span)
        (call $reason_make_inferredpiperesult (local.get $pipe_str)
          (call $reason_make_inferred (i32.const 3720)))))
    (call $unify (local.get $rh) (local.get $expected_h) (local.get $span)
      (call $reason_make_inferredpiperesult (local.get $pipe_str)
        (call $reason_make_inferred (i32.const 3744))))   ;; "unification"
    (call $graph_bind (local.get $handle)
      (call $ty_make_tvar (local.get $ret_h))
      (call $reason_make_located (local.get $span)
        (call $reason_make_inferredpiperesult (local.get $pipe_str)
          (call $reason_make_inferred (i32.const 3584)))))  ;; "result"
    ;; Row composition seed-stub
    (call $walk_expr_inf_add_row (local.get $row_h))
    (local.get $handle))

  ;; PCompose (><) — src/infer.nx:985-995. branch_enter; walk left;
  ;; branch_divider; walk right; branch_exit. Bind handle to
  ;; TTuple([TVar(lh), TVar(rh)]).
  (func $infer_walk_expr_pipe_compose
        (export "infer_walk_expr_pipe_compose")
        (param $left i32) (param $right i32)
        (param $handle i32) (param $span i32)
        (result i32)
    (local $lh i32) (local $rh i32)
    (local $tuple_elems i32)
    (call $infer_branch_enter)
    (local.set $lh (call $infer_walk_expr (local.get $left)))
    (call $infer_branch_divider)
    (local.set $rh (call $infer_walk_expr (local.get $right)))
    (call $infer_branch_exit (local.get $span)
      (call $reason_make_inferred (i32.const 3912)))   ;; "tuple result"
    ;; TTuple([TVar(lh), TVar(rh)])
    (local.set $tuple_elems (call $make_list (i32.const 0)))
    (local.set $tuple_elems (call $list_extend_to (local.get $tuple_elems) (i32.const 2)))
    (drop (call $list_set (local.get $tuple_elems) (i32.const 0)
                          (call $ty_make_tvar (local.get $lh))))
    (drop (call $list_set (local.get $tuple_elems) (i32.const 1)
                          (call $ty_make_tvar (local.get $rh))))
    (call $graph_bind (local.get $handle)
      (call $ty_make_ttuple (local.get $tuple_elems))
      (call $reason_make_located (local.get $span)
        (call $reason_make_inferred (i32.const 3912))))   ;; "tuple result"
    (local.get $handle))

  ;; PDiverge (<|) — src/infer.nx:997-1022. Walk left; if right is
  ;; MakeTupleExpr, branch_enter + walk each branch + branch_divider +
  ;; branch_exit + bind right to TTuple of branch_h. Bind handle to
  ;; TVar(rh).
  (func $infer_walk_expr_pipe_diverge
        (export "infer_walk_expr_pipe_diverge")
        (param $left i32) (param $right i32)
        (param $handle i32) (param $span i32)
        (result i32)
    (local $lh i32) (local $rh i32)
    (local $rbody i32) (local $rexpr i32) (local $rtag i32)
    (local $branches i32) (local $n i32) (local $i i32)
    (local $branch i32) (local $branch_h i32)
    (local $tuple_elems i32)
    (drop (call $infer_walk_expr (local.get $left)))
    (local.set $lh (call $walk_expr_node_handle (local.get $left)))
    (drop (local.get $lh))
    ;; Check if right's body is NExpr containing MakeTupleExpr (97).
    (local.set $rbody (call $walk_expr_node_body (local.get $right)))
    (if (i32.eq (i32.load (local.get $rbody)) (i32.const 110))
      (then
        (local.set $rexpr (i32.load offset=4 (local.get $rbody)))
        (local.set $rtag (call $walk_expr_expr_tag (local.get $rexpr)))
        (if (i32.eq (local.get $rtag) (i32.const 97))
          (then
            (local.set $branches (i32.load offset=4 (local.get $rexpr)))
            (local.set $n (call $len (local.get $branches)))
            (if (i32.eqz (local.get $n))
              (then
                ;; Degenerate: <| () — empty branch tuple. Walk right normally.
                (drop (call $infer_walk_expr (local.get $right))))
              (else
                (call $infer_branch_enter)
                (local.set $i (i32.const 0))
                (local.set $tuple_elems (call $make_list (i32.const 0)))
                (local.set $tuple_elems
                  (call $list_extend_to (local.get $tuple_elems) (local.get $n)))
                (block $done
                  (loop $each
                    (br_if $done (i32.ge_u (local.get $i) (local.get $n)))
                    (local.set $branch (call $list_index (local.get $branches) (local.get $i)))
                    (local.set $branch_h (call $infer_walk_expr (local.get $branch)))
                    (drop (call $list_set (local.get $tuple_elems)
                                          (local.get $i)
                                          (call $ty_make_tvar (local.get $branch_h))))
                    ;; branch_divider between branches (not after last).
                    (if (i32.lt_u
                          (i32.add (local.get $i) (i32.const 1))
                          (local.get $n))
                      (then (call $infer_branch_divider)))
                    (local.set $i (i32.add (local.get $i) (i32.const 1)))
                    (br $each)))
                (call $infer_branch_exit (local.get $span)
                  (call $reason_make_inferred (i32.const 3912)))   ;; "tuple result"
                ;; Bind right's handle to TTuple(...).
                (call $graph_bind
                  (call $walk_expr_node_handle (local.get $right))
                  (call $ty_make_ttuple (local.get $tuple_elems))
                  (call $reason_make_located (local.get $span)
                    (call $reason_make_inferred (i32.const 3912)))))))
          (else
            ;; Single-branch form: walk right normally.
            (drop (call $infer_walk_expr (local.get $right))))))
      (else
        (drop (call $infer_walk_expr (local.get $right)))))
    (local.set $rh (call $walk_expr_node_handle (local.get $right)))
    (call $graph_bind (local.get $handle)
      (call $ty_make_tvar (local.get $rh))
      (call $reason_make_located (local.get $span)
        (call $reason_make_inferred (i32.const 3912))))   ;; "tuple result"
    (local.get $handle))

  ;; PTeeBlock / PTeeInline (~>) — src/infer.nx:944-955. Result type =
  ;; TVar(lh). handler-stack push/pop seed-stubs.
  (func $infer_walk_expr_pipe_tee
        (export "infer_walk_expr_pipe_tee")
        (param $left i32) (param $right i32)
        (param $handle i32) (param $span i32)
        (result i32)
    (local $lh i32) (local $rh i32) (local $cname i32)
    (local.set $lh (call $infer_walk_expr (local.get $left)))
    (local.set $rh (call $infer_walk_expr (local.get $right)))
    (drop (local.get $rh))
    (local.set $cname (call $walk_expr_callee_name (local.get $right)))
    (call $walk_expr_inf_push_handler (local.get $cname))
    (call $graph_bind (local.get $handle)
      (call $ty_make_tvar (local.get $lh))
      (call $reason_make_located (local.get $span)
        (call $reason_make_inferredpiperesult
          (call $int_to_str (i32.const 164))
          (call $reason_make_inferred (i32.const 3584)))))   ;; "result"
    (call $walk_expr_inf_pop_handler)
    (local.get $handle))

  ;; PFeedback (<~) — src/infer.nx:959-973. Pessimistic seed: emit
  ;; feedback-no-context unconditionally + bind handle ↔ TVar(lh) per
  ;; Hazel productive-under-error. Hβ.infer.iterative-context lands the
  ;; handler-stack-walk that detects Clock/Tick/Sample.
  (func $infer_walk_expr_pipe_feedback
        (export "infer_walk_expr_pipe_feedback")
        (param $left i32) (param $right i32)
        (param $handle i32) (param $span i32)
        (result i32)
    (local $lh i32) (local $rh i32)
    (local.set $lh (call $infer_walk_expr (local.get $left)))
    (local.set $rh (call $infer_walk_expr (local.get $right)))
    (drop (local.get $rh))
    ;; Productive-under-error: emit + bind NErrorHole via emit_diag helper.
    (call $infer_emit_feedback_no_context
      (local.get $handle)
      (call $reason_make_located (local.get $span)
        (call $reason_make_inferredpiperesult
          (call $int_to_str (i32.const 165))
          (call $reason_make_inferred (i32.const 3520)))))   ;; "var ref"
    ;; emit_diag binds NErrorHole; we don't bind again (one-bind invariant).
    (drop (local.get $lh))
    (local.get $handle))

  ;; ─── Entry-point dispatch ────────────────────────────────────────────
  ;;
  ;; $infer_walk_expr(node) -> handle. Per src/infer.nx:490-765. Reads N's
  ;; body to get the NExpr tag (110), reads NExpr's inner Expr tag (80-101),
  ;; dispatches to the per-variant arm.

  (func $infer_walk_expr (export "infer_walk_expr")
        (param $node i32) (result i32)
    (local $body i32) (local $expr i32) (local $tag i32)
    (local $handle i32) (local $span i32)
    (call $infer_init)
    (call $env_init)
    (call $graph_init)
    (local.set $body   (call $walk_expr_node_body   (local.get $node)))
    (local.set $span   (call $walk_expr_node_span   (local.get $node)))
    (local.set $handle (call $walk_expr_node_handle (local.get $node)))
    ;; Span-index append for query-layer consumers post-walk.
    (call $infer_span_index_append (local.get $span) (local.get $handle))
    ;; Body MUST be NExpr (tag 110). Non-NExpr at expression position is
    ;; parser-bug surface; trap to surface (consistent with H6 wildcard
    ;; discipline + Anchor 0 dream-code stance).
    (if (i32.ne (i32.load (local.get $body)) (i32.const 110))
      (then (unreachable)))
    (local.set $expr (i32.load offset=4 (local.get $body)))
    (local.set $tag (call $walk_expr_expr_tag (local.get $expr)))
    ;; Dispatch on Expr tag (80-101) per parser_infra.wat:14-19.
    (if (i32.eq (local.get $tag) (i32.const 80))
      (then (return (call $infer_walk_expr_lit_int
              (local.get $expr) (local.get $handle) (local.get $span)))))
    (if (i32.eq (local.get $tag) (i32.const 81))
      (then (return (call $infer_walk_expr_lit_float
              (local.get $expr) (local.get $handle) (local.get $span)))))
    (if (i32.eq (local.get $tag) (i32.const 82))
      (then (return (call $infer_walk_expr_lit_string
              (local.get $expr) (local.get $handle) (local.get $span)))))
    (if (i32.eq (local.get $tag) (i32.const 83))
      (then (return (call $infer_walk_expr_lit_bool
              (local.get $expr) (local.get $handle) (local.get $span)))))
    (if (i32.eq (local.get $tag) (i32.const 84))
      (then (return (call $infer_walk_expr_lit_unit
              (local.get $expr) (local.get $handle) (local.get $span)))))
    (if (i32.eq (local.get $tag) (i32.const 85))
      (then (return (call $infer_walk_expr_var_ref
              (local.get $expr) (local.get $handle) (local.get $span)))))
    (if (i32.eq (local.get $tag) (i32.const 86))
      (then (return (call $infer_walk_expr_binop
              (local.get $expr) (local.get $handle) (local.get $span)))))
    (if (i32.eq (local.get $tag) (i32.const 87))
      (then (return (call $infer_walk_expr_unaryop
              (local.get $expr) (local.get $handle) (local.get $span)))))
    (if (i32.eq (local.get $tag) (i32.const 88))
      (then (return (call $infer_walk_expr_call
              (local.get $expr) (local.get $handle) (local.get $span)))))
    (if (i32.eq (local.get $tag) (i32.const 89))
      (then (return (call $infer_walk_expr_lambda
              (local.get $expr) (local.get $handle) (local.get $span)))))
    (if (i32.eq (local.get $tag) (i32.const 90))
      (then (return (call $infer_walk_expr_if
              (local.get $expr) (local.get $handle) (local.get $span)))))
    (if (i32.eq (local.get $tag) (i32.const 91))
      (then (return (call $infer_walk_expr_block
              (local.get $expr) (local.get $handle) (local.get $span)))))
    (if (i32.eq (local.get $tag) (i32.const 92))
      (then (return (call $infer_walk_expr_match
              (local.get $expr) (local.get $handle) (local.get $span)))))
    (if (i32.eq (local.get $tag) (i32.const 93))
      (then (return (call $infer_walk_expr_handle
              (local.get $expr) (local.get $handle) (local.get $span)))))
    (if (i32.eq (local.get $tag) (i32.const 94))
      (then (return (call $infer_walk_expr_perform
              (local.get $expr) (local.get $handle) (local.get $span)))))
    (if (i32.eq (local.get $tag) (i32.const 95))
      (then (return (call $infer_walk_expr_resume
              (local.get $expr) (local.get $handle) (local.get $span)))))
    (if (i32.eq (local.get $tag) (i32.const 96))
      (then (return (call $infer_walk_expr_make_list
              (local.get $expr) (local.get $handle) (local.get $span)))))
    (if (i32.eq (local.get $tag) (i32.const 97))
      (then (return (call $infer_walk_expr_make_tuple
              (local.get $expr) (local.get $handle) (local.get $span)))))
    (if (i32.eq (local.get $tag) (i32.const 98))
      (then (return (call $infer_walk_expr_make_record
              (local.get $expr) (local.get $handle) (local.get $span)))))
    (if (i32.eq (local.get $tag) (i32.const 99))
      (then (return (call $infer_walk_expr_named_record
              (local.get $expr) (local.get $handle) (local.get $span)))))
    (if (i32.eq (local.get $tag) (i32.const 100))
      (then (return (call $infer_walk_expr_field
              (local.get $expr) (local.get $handle) (local.get $span)))))
    (if (i32.eq (local.get $tag) (i32.const 101))
      (then (return (call $infer_walk_expr_pipe
              (local.get $expr) (local.get $handle) (local.get $span)))))
    ;; Unknown tag — H6 wildcard discipline: trap so future Expr variants
    ;; force this dispatch table to be extended (drift mode 9 prevention).
    (unreachable))
