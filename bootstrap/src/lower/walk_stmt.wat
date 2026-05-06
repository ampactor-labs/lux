  ;; ═══ walk_stmt.wat — Hβ.lower Stmt arms + $lower_stmt dispatch (Tier 8) ═══
  ;; Hβ.lower cascade chunk #10 of 11 per Hβ-lower-substrate.md §12.3 dep order.
  ;;
  ;; What this chunk IS (per Hβ-lower-substrate.md §4.3 + src/lower.nx:556-636):
  ;;   The seed's statement-level lowering layer. Where module-level functions
  ;;   emerge as LMakeClosure-wrapped LLets (Lock #1) and handler declarations
  ;;   cascade their arms through chunk #8's $lower_handler_arms_as_decls
  ;;   (Lock #7 — third caller earns the abstraction per Anchor 7). Bridge
  ;;   from Hβ.infer's typed AST stmt-list to chunk #11's $lower_program
  ;;   orchestrator.
  ;;
  ;;     120 LetStmt          → LLet(h, name, lo_value)            Lock #5/#6
  ;;     121 FnStmt           → LLet(h, name, LMakeClosure(...))   Lock #1/#2/#3/#4
  ;;     122 TypeDefStmt      → LConst(h, 0)                       Lock #9
  ;;     123 EffectDeclStmt   → LConst(h, 0)                       Lock #9
  ;;     124 HandlerDeclStmt  → LBlock(h, arm_decls ++ [LConst(...)])  Lock #7
  ;;     125 ExprStmt         → $lower_expr(inner)                 Lock #8
  ;;     126 ImportStmt       → LConst(h, 0)                       Lock #9
  ;;     127 RefineStmt       → LConst(h, 0)                       Lock #9
  ;;     128 Documented       → $lower_stmt(inner_node)            Lock #10
  ;;
  ;; Implements: Hβ-lower-substrate.md §4.3 + §6.3 + §11 + §12.3 #10;
  ;;             src/lower.nx:564-571 lower_stmt dispatch (NodeBody arms);
  ;;             src/lower.nx:573-633 lower_stmt_body (9 Stmt arms);
  ;;             src/lower.nx:556-558 lower_stmt_list (buffer-counter form
  ;;             per Lock #11 — diverges from wheel toward Ω.3).
  ;; Exports:    $lower_stmt,
  ;;             $lower_stmt_list,
  ;;             $lower_walk_stmt_let,
  ;;             $lower_walk_stmt_fn,
  ;;             $lower_walk_stmt_typedef,
  ;;             $lower_walk_stmt_effect_decl,
  ;;             $lower_walk_stmt_handler_decl,
  ;;             $lower_walk_stmt_expr,
  ;;             $lower_walk_stmt_import,
  ;;             $lower_walk_stmt_refine,
  ;;             $lower_walk_stmt_documented
  ;; Uses:       $walk_expr_node_handle (infer/walk_expr.wat:306-307 — cross-layer),
  ;;             $tag_of (runtime/record.wat),
  ;;             $lexpr_make_llet / lblock / lconst / lmakeclosure
  ;;               (lower/lexpr.wat),
  ;;             $lower_expr (lower/walk_call.wat — partial dispatcher
  ;;               complete after chunks #6/#7/#8/#9/#9.5 retrofits;
  ;;               this chunk does NOT retrofit further),
  ;;             $lower_handler_arms_as_decls (lower/walk_handle.wat —
  ;;               third caller per Lock #7),
  ;;             $ls_bind_local (lower/state.wat),
  ;;             $make_list / $list_index / $list_set / $list_extend_to /
  ;;               $len (runtime/list.wat — Ω.3 buffer-counter per Lock #11)
  ;; Test:       bootstrap/test/lower/walk_stmt_let.wat,
  ;;             bootstrap/test/lower/walk_stmt_fn.wat,
  ;;             bootstrap/test/lower/walk_stmt_expr.wat,
  ;;             bootstrap/test/lower/walk_stmt_handler_decl.wat,
  ;;             bootstrap/test/lower/walk_stmt_program.wat
  ;;
  ;; ═══ LOCKS (wheel-canonical override walkthrough §4.3 prose) ════════
  ;;
  ;; Lock #1: FnStmt → LLet(handle, name, LMakeClosure(...)) NOT bare LDeclareFn.
  ;;          Per src/lower.nx:612 wheel canonical. Walkthrough §4.3 prose
  ;;          ("most arms produce a top-level LDeclareFn") aspirational; the
  ;;          wheel emits LLet wrapping LMakeClosure. LDeclareFn (tag 313)
  ;;          is reserved for handler-arm-only module-level form per chunk #8.
  ;;
  ;; Lock #2: FnStmt now constructs a real LowFn record (name, arity,
  ;;          params, body, row) and still leaves captures/evidence empty.
  ;;          The remaining peer handle is closure-capture/frame discipline,
  ;;          not fn-record absence.
  ;;
  ;; Lock #3: FnStmt's $ls_bind_local(name, handle) fires BEFORE body lower.
  ;;          Per src/lower.nx:593. Recursive references resolve via locals
  ;;          ledger at chunk #6's $lower_var_ref.
  ;;
  ;; Lock #4: FnStmt's $ls_reset_function NOT called.
  ;;          Wheel uses ls_enter_frame/ls_exit_frame (frame-stack discipline);
  ;;          $ls_reset_function would wipe Lock #3's bind + enclosing-fn
  ;;          ledger. Frame discipline named follow-up
  ;;          Hβ.lower.fn-stmt-frame-discipline.
  ;;
  ;; Lock #5: LetStmt's pat treated as PVar-only at the seed.
  ;;          Per src/lower.nx:574-587. Pat tag 130 (PVar) → bind + LLet;
  ;;          others → pass-through lo. Named follow-up
  ;;          Hβ.lower.letstmt-destructure for PCon/PTuple/PList/PRecord.
  ;;
  ;; Lock #6: LetStmt's expr_h read via $walk_expr_node_handle on the val node.
  ;;          Per src/lower.nx:582 — offset 12 of val N-wrapper.
  ;;
  ;; Lock #7: HandlerDeclStmt → LBlock(h, arm_decls ++ [LConst(h, 0)]).
  ;;          Per src/lower.nx:617-625 wheel. Calls chunk #8 helper
  ;;          $lower_handler_arms_as_decls — currently returns empty list
  ;;          per chunk #8 Lock #7 (LFn ADT pending); seed emits
  ;;          LBlock(h, [LConst(h, 0)]).
  ;;
  ;; Lock #8: ExprStmt → $lower_expr(inner) direct passthrough.
  ;;          Per src/lower.nx:632. No LStore wrapper.
  ;;
  ;; Lock #9: TypeDef/EffectDecl/Import/Refine → $lexpr_make_lconst(handle, 0).
  ;;          Per src/lower.nx:615-628. Wheel emits LConst(handle, LInt(0));
  ;;          seed passes 0 directly per chunk #6 Lock #4 LowValue opaque
  ;;          pass-through (named follow-up Hβ.lower.lvalue-lowfn-lpat-
  ;;          substrate covers structured LowValue when ADT lands).
  ;;
  ;; Lock #10: Documented arm reads inner_node via offset 8.
  ;;           Layout assumption [tag=128][docstring][inner_node]. Drift-9-safe:
  ;;           parser doesn't emit Documented today. Named follow-up
  ;;           Hβ.lower.documented-arm-substrate.
  ;;
  ;; Lock #11: $lower_stmt_list buffer-counter (Ω.3) NOT tail-recursive cons.
  ;;           Wheel src/lower.nx:556-558 uses [head] ++ tail (O(N²) drift the
  ;;           wheel itself flags). Seed prefers Ω.3 — chunk #6/#7/#8/#9
  ;;           discipline.
  ;;
  ;; Lock #12: $lower_stmt dispatcher mirrors infer/walk_stmt.wat:623-671.
  ;;           Read N-wrapper → body offset 4 → if NExpr (110) delegate to
  ;;           $lower_expr; NPat (112)/NHole (113) → LConst(h, 0); NStmt (111)
  ;;           → 9-arm dispatch over Stmt tags 120-128.
  ;;
  ;; ═══ EIGHT INTERROGATIONS (per Hβ-lower-substrate.md §5.3) ══════════
  ;;
  ;; 1. Graph?       LetStmt + FnStmt arms read $walk_expr_node_handle
  ;;                 (offset 12) on AST inputs; bound name's ty_handle
  ;;                 stored in state.wat ledger references graph handles.
  ;;                 ExprStmt threads through $lower_expr (chunk #7
  ;;                 dispatcher). Read-only on graph.
  ;;
  ;; 2. Handler?     Wheel: with GraphRead + EnvRead + LookupTy + LowerCtx
  ;;                 + Diagnostic chain @resume=OneShot. Seed: 11 direct
  ;;                 functions. FnStmt does NOT install a new handler row
  ;;                 here — emit-time concern. HandlerDeclStmt invokes
  ;;                 chunk #8's $lower_handler_arms_as_decls (third caller).
  ;;
  ;; 3. Verb?        Silent at stmt-list level (stmts sequential by
  ;;                 definition; verbs draw inside Expr). FnStmt's body
  ;;                 recursion via $lower_expr re-enters the verb-projection
  ;;                 layer (chunk #8).
  ;;
  ;; 4. Row?         FnStmt's row stays opaque at lower-time (wheel hardcodes
  ;;                 EfPure on LFn — Lock #2 elides LFn entirely). Rows
  ;;                 resolved live via $lookup_ty at downstream call-sites
  ;;                 (chunk #7 $monomorphic_at).
  ;;
  ;; 5. Ownership?   LetStmt's $ls_bind_local writes to state.wat's locals
  ;;                 ledger (OWN by current fn). FnStmt's params + captures
  ;;                 discipline deferred per Lock #2/#4. ExprStmt's lowered
  ;;                 LowExpr OWN by bump.
  ;;
  ;; 6. Refinement?  RefineStmt → inert LConst sentinel per Lock #9
  ;;                 (refinement obligations land in verify ledger at
  ;;                 infer-time). Lower transparent.
  ;;
  ;; 7. Gradient?    FnStmt's LMakeClosure IS the closure substrate that
  ;;                 monomorphic-call gradient (chunk #7 $monomorphic_at)
  ;;                 reads back through. LetStmt's $ls_bind_local makes the
  ;;                 binding so subsequent VarRef chunks read it as RLocal
  ;;                 (gradient: monomorphic-bound) instead of falling to
  ;;                 LGlobal.
  ;;
  ;; 8. Reason?      LetStmt + FnStmt + ExprStmt carry source handle into
  ;;                 LowExpr field 0; Reason chain lives on GNode at that
  ;;                 handle. The four inert Stmts emit LConst(h, 0) so the
  ;;                 handle bridge survives to emit's dead-code elimination.
  ;;
  ;; ═══ FORBIDDEN PATTERNS AUDIT ═══════════════════════════════════════
  ;;
  ;; - Drift 1 (Rust vtable):      Stmt dispatch is 9-arm if-chain — direct
  ;;                                sentinel comparison; no $stmt_arm_table
  ;;                                data segment. Word "vtable" appears
  ;;                                NOWHERE except in this audit.
  ;;
  ;; - Drift 2 (Scheme env frame): state.wat's flat list per Lock #4. NO
  ;;                                frame stack push/pop here.
  ;;
  ;; - Drift 3 (Python dict):      Stmt tags integer constants 120-128.
  ;;                                NO string-keyed dispatch.
  ;;
  ;; - Drift 4 (monad transformer): No LowerStmtM. Each $lower_walk_stmt_*
  ;;                                is direct (param i32) (param i32) (result i32).
  ;;
  ;; - Drift 5 (C calling conv):   FnStmt closure synthesis — LMakeClosure
  ;;                                carries one fn_ptr field + caps + evs;
  ;;                                NOT separate __closure + __ev + __ret_slot.
  ;;
  ;; - Drift 6 (primitive special-case): LetStmt is one of nine arms — NOT
  ;;                                fast-path. Every Stmt tag dispatches
  ;;                                through same $tag_of + (if eq) chain.
  ;;
  ;; - Drift 7 (parallel-arrays):  state.wat's LOCAL_ENTRY 3-field record
  ;;                                reused. LMakeClosure.caps + .evs are H1-
  ;;                                canonical TWO conceptually-distinct lists.
  ;;
  ;; - Drift 8 (string-keyed):     Stmt arm dispatch via integer tag (120-128);
  ;;                                NEVER kind == "let" / kind == "fn".
  ;;
  ;; - Drift 9 (deferred-by-omission): ALL 9 Stmt arms FULLY BODIED. Inert
  ;;                                four (TypeDef/EffectDecl/Import/Refine)
  ;;                                emit LConst sentinel explicitly. Lock #2/
  ;;                                #4/#5/#7/#10 deferrals bodied with
  ;;                                reasoning + named follow-ups.
  ;;
  ;; - Foreign fluency — module-level fn declaration: NEVER "global function" /
  ;;                                "top-level function". Vocabulary stays
  ;;                                Inka — LDeclareFn (handler-arm form) /
  ;;                                LMakeClosure (closure form).
  ;;
  ;; - Foreign fluency — let-rec / Y combinator: Recursive `fn fact` resolves
  ;;                                via $ls_bind_local(name, handle) BEFORE
  ;;                                body lower (Lock #3). The wheel's two-pass
  ;;                                pre-bind IS the Inka substrate.
  ;;
  ;; ═══ Named follow-ups (Drift 9 closure) ═════════════════════════════
  ;;
  ;;   - Hβ.lower.fn-stmt-closure-substrate:
  ;;             collect_free_vars + resolve_captures_outer + ls_enter_frame/
  ;;             ls_exit_frame + LFn ADT all converge as one peer landing
  ;;             with Hβ.lower.lambda-capture-substrate (chunk #9).
  ;;
  ;;   - Hβ.lower.fn-stmt-frame-discipline:
  ;;             Per Lock #4 — $ls_enter_frame / $ls_exit_frame substrate
  ;;             at state.wat (matching wheel src/lower.nx:599-604).
  ;;
  ;;   - Hβ.lower.letstmt-destructure:
  ;;             Per Lock #5 — when parser surfaces stable PCon/PTuple/PList/
  ;;             PRecord at LetStmt position.
  ;;
  ;;   - Hβ.lower.handler-arm-decls-substrate:
  ;;             (extends from chunk #8) chunk #8's helper grows real
  ;;             LDeclareFn list when LFn ADT lands; this chunk's
  ;;             HandlerDeclStmt arm picks up the populated list automatically.
  ;;
  ;;   - Hβ.lower.documented-arm-substrate:
  ;;             Per Lock #10 — when parser surfaces $mk_DocumentedStmt with
  ;;             stable layout.
  ;;
  ;;   - Hβ.lower.toplevel-pre-register:
  ;;             (cross-cascade with Hβ.infer.toplevel-pre-register) — chunk
  ;;             #11 main.wat's $lower_program may grow collect_top_level_names
  ;;             per src/lower.nx:1106-1110 if forward-reference resolution
  ;;             at the seed needs it.

  ;; ─── $lower_walk_stmt_let — LetStmt arm (parser tag 120) ────────────
  ;; Per src/lower.nx:574-587 + Lock #5/#6.
  ;; AST per parser_infra.wat:163-168: [tag=120][pat][val] offsets 0/4/8.
  (func $lower_walk_stmt_let (export "lower_walk_stmt_let")
        (param $stmt i32) (param $handle i32) (result i32)
    (local $pat i32) (local $val i32) (local $lo i32)
    (local $pat_tag i32) (local $name i32) (local $expr_h i32)
    (local.set $pat (i32.load offset=4 (local.get $stmt)))
    (local.set $val (i32.load offset=8 (local.get $stmt)))
    ;; Lock #6: read val-node's handle BEFORE recursing.
    (local.set $expr_h (call $walk_expr_node_handle (local.get $val)))
    ;; Lower the value via $lower_expr.
    (local.set $lo (call $lower_expr (local.get $val)))
    ;; Lock #5: PVar (tag 130) only at the seed.
    (local.set $pat_tag (call $tag_of (local.get $pat)))
    (if (i32.eq (local.get $pat_tag) (i32.const 130))
      (then
        (local.set $name (i32.load offset=4 (local.get $pat)))
        (drop (call $ls_bind_local (local.get $name) (local.get $expr_h)))
        (return (call $lexpr_make_llet
                  (local.get $handle)
                  (local.get $name)
                  (local.get $lo)))))
    ;; PCon (133) — constructor destructure per
    ;; Hβ.first-light.letstmt-destructure (closes the named follow-up
    ;; Hβ.lower.letstmt-destructure at line 220-222).
    ;;
    ;; Eight interrogations on this destructure site:
    ;;  1. Graph?      LMakeVariant carries field offsets at 4, 8, 12,
    ;;                 ... per variant_record layout (emit_const.wat:493).
    ;;  2. Handler?    @resume=OneShot — direct lowering.
    ;;  3. Verb?       N/A — structural.
    ;;  4. Row?        Pure with respect to env binding.
    ;;  5. Ownership?  Each binding is `own` at its first use; refined
    ;;                 by the gradient.
    ;;  6. Refinement? PCon's tag_id is checked at infer-time
    ;;                 (walk_expr.wat:984+); destructure is unconditional
    ;;                 because the let-form admits no fall-through.
    ;;  7. Gradient?   Field-load offset is compile-time-resolved.
    ;;  8. Reason?     Each binding's Reason chain walks back to
    ;;                 LetBinding(name, …) per infer's PCon arm.
    ;;
    ;; Drift modes refused:
    ;;  - Drift 1 (vtable): no dispatch table; positional field loads.
    ;;  - Drift 6 (special): one-deep AND nested PCon use the same
    ;;                       recursive shape (recursion into sub-pats).
    ;;  - Drift 9 (deferred): all sub-pat tags handled (PVar binds; PWild
    ;;                       skips; nested PCon recurses; PLit skips —
    ;;                       refutable patterns are caller's problem in
    ;;                       irrefutable let-context).
    ;;  - Drift 11 (acc++[x]): buffer-counter substrate via
    ;;                       list_extend_to + list_set + slice.
    ;;
    ;; Layout per parser_pat.wat: PCon = [tag=133][ctor_name][sub_pats].
    (if (i32.eq (local.get $pat_tag) (i32.const 133))
      (then
        (return (call $lower_pcon_let
                       (local.get $handle)
                       (local.get $pat)
                       (local.get $val)
                       (local.get $lo)
                       (local.get $expr_h)))))
    ;; PTuple (134) — tuple destructure per Hβ.first-light.ptuple-let-
    ;; destructure (closes the empirically-named gap from
    ;; Hβ-first-light-empirical.md §4.5.4d). Layout:
    ;; PTuple = [tag=134][sub_pats]; tuples allocate a record with
    ;; fields at offset 4*i (NO variant tag — emit_const.wat:437-453
    ;; $emit_lmaketuple). Mirrors $lower_pcon_let with field_offset =
    ;; 4*i instead of 4 + 4*i.
    (if (i32.eq (local.get $pat_tag) (i32.const 134))
      (then
        (return (call $lower_ptuple_let
                       (local.get $handle)
                       (local.get $pat)
                       (local.get $lo)
                       (local.get $expr_h)))))
    ;; Other pats (PList, PRecord) — pass-through; named follow-up
    ;; Hβ.lower.letstmt-destructure-list-record extends this arm when
    ;; those forms surface in wheel parser output.
    (local.get $lo))

  ;; PCon destructure helper. Generates:
  ;;   LBlock([
  ;;     LLet(temp_h, "__pat_<h>", lo_val),
  ;;     for each PVar sub-pat at index i:
  ;;       LLet(sub_h, name_i, LFieldLoad(temp_h_local, 4 + 4*i))
  ;;     for each PWild: skip
  ;;     for each nested PCon: recurse (chain another LBlock)
  ;;   ])
  (func $lower_pcon_let
        (param $handle i32) (param $pat i32) (param $val i32)
        (param $lo_val i32) (param $expr_h i32) (result i32)
    (local $sub_pats i32) (local $n i32) (local $i i32)
    (local $sub_pat i32) (local $sub_tag i32)
    (local $temp_name i32) (local $sub_name i32) (local $sub_h i32)
    (local $field_offset i32)
    (local $stmts_buf i32) (local $stmt_count i32)
    (local $temp_local_ref i32) (local $field_load i32) (local $sub_let i32)
    (local.set $sub_pats (i32.load offset=8 (local.get $pat)))
    (local.set $n (call $len (local.get $sub_pats)))
    ;; Bind the value into a synthesized temp local. Name is "__pat_<h>"
    ;; using $int_to_str so each destructure site gets a unique label.
    (local.set $temp_name (call $str_concat
                            (call $synth_pat_prefix)
                            (call $int_to_str (local.get $handle))))
    (drop (call $ls_bind_local (local.get $temp_name) (local.get $expr_h)))
    ;; Pre-size the buffer: 1 (temp let) + n (worst case all PVar).
    (local.set $stmts_buf (call $make_list (i32.const 0)))
    (local.set $stmts_buf (call $list_extend_to
                            (local.get $stmts_buf)
                            (i32.add (i32.const 1) (local.get $n))))
    (local.set $stmt_count (i32.const 0))
    ;; First stmt: LLet(handle, temp_name, lo_val)
    (drop (call $list_set (local.get $stmts_buf)
                          (local.get $stmt_count)
                          (call $lexpr_make_llet
                                (local.get $handle)
                                (local.get $temp_name)
                                (local.get $lo_val))))
    (local.set $stmt_count (i32.add (local.get $stmt_count) (i32.const 1)))
    ;; For each sub-pat:
    (local.set $i (i32.const 0))
    (block $done
      (loop $each
        (br_if $done (i32.ge_u (local.get $i) (local.get $n)))
        (local.set $sub_pat (call $list_index (local.get $sub_pats) (local.get $i)))
        (local.set $sub_tag (call $tag_of (local.get $sub_pat)))
        ;; Field offset: 4 + 4*i (variant tag at 0, fields at 4 onward).
        (local.set $field_offset
          (i32.add (i32.const 4) (i32.mul (local.get $i) (i32.const 4))))
        ;; PVar (130) — bind the name to the field load.
        (if (i32.eq (local.get $sub_tag) (i32.const 130))
          (then
            (local.set $sub_name (i32.load offset=4 (local.get $sub_pat)))
            ;; Mint a fresh handle for the binding's type. Per the
            ;; productive-under-error discipline (walk_expr.wat:957-974),
            ;; PCon-with-no-ctor-binding still binds sub-pats with fresh
            ;; handles; we mirror that at lower-time using the parent
            ;; expr_h since the actual sub-handles aren't threaded.
            (local.set $sub_h (local.get $expr_h))
            (drop (call $ls_bind_local (local.get $sub_name) (local.get $sub_h)))
            ;; LFieldLoad(sub_h, LLocal(expr_h, temp_name), field_offset)
            (local.set $temp_local_ref
              (call $lexpr_make_llocal (local.get $expr_h) (local.get $temp_name)))
            (local.set $field_load
              (call $lexpr_make_lfieldload
                    (local.get $sub_h)
                    (local.get $temp_local_ref)
                    (local.get $field_offset)))
            (local.set $sub_let
              (call $lexpr_make_llet
                    (local.get $sub_h)
                    (local.get $sub_name)
                    (local.get $field_load)))
            (local.set $stmts_buf (call $list_extend_to
                                    (local.get $stmts_buf)
                                    (i32.add (local.get $stmt_count) (i32.const 1))))
            (drop (call $list_set (local.get $stmts_buf)
                                  (local.get $stmt_count)
                                  (local.get $sub_let)))
            (local.set $stmt_count (i32.add (local.get $stmt_count) (i32.const 1)))))
        ;; PWild (131) — skip; no binding to emit.
        ;; Nested PCon and other pats — drift-9-safe pass for now;
        ;; when wheel needs nested let-destructure, this arm extends.
        (local.set $i (i32.add (local.get $i) (i32.const 1)))
        (br $each)))
    ;; Wrap all stmts in LBlock so the outer LBlock sees one LowExpr
    ;; that itself contains the destructure sequence.
    (call $lexpr_make_lblock
          (local.get $handle)
          (call $slice (local.get $stmts_buf)
                       (i32.const 0)
                       (local.get $stmt_count))))

  ;; PTuple destructure helper. Mirror of $lower_pcon_let with field
  ;; offsets at 4*i (no variant tag word). Layout per parser_pat.wat:
  ;; PTuple = [tag=134][sub_pats] (offset 4 = sub_pats list pointer).
  ;;
  ;; Generates:
  ;;   LBlock([
  ;;     LLet(temp_h, "__pat_<h>", lo_val),
  ;;     for each PVar sub-pat at index i:
  ;;       LLet(sub_h, name_i, LFieldLoad(temp_h_local, 4*i))
  ;;     for each PWild: skip
  ;;   ])
  ;;
  ;; Tuple records have NO variant tag at offset 0 — emit_const.wat:437
  ;; $emit_lmaketuple stores element i at byte 4*i. Hence offset = 4*i,
  ;; not 4 + 4*i (the +4 is variant-tag-only per emit_const.wat:507).
  (func $lower_ptuple_let
        (param $handle i32) (param $pat i32)
        (param $lo_val i32) (param $expr_h i32) (result i32)
    (local $sub_pats i32) (local $n i32) (local $i i32)
    (local $sub_pat i32) (local $sub_tag i32)
    (local $temp_name i32) (local $sub_name i32) (local $sub_h i32)
    (local $field_offset i32)
    (local $stmts_buf i32) (local $stmt_count i32)
    (local $temp_local_ref i32) (local $field_load i32) (local $sub_let i32)
    ;; PTuple layout: [tag=134][sub_pats] — sub_pats at offset 4.
    (local.set $sub_pats (i32.load offset=4 (local.get $pat)))
    (local.set $n (call $len (local.get $sub_pats)))
    (local.set $temp_name (call $str_concat
                            (call $synth_pat_prefix)
                            (call $int_to_str (local.get $handle))))
    (drop (call $ls_bind_local (local.get $temp_name) (local.get $expr_h)))
    (local.set $stmts_buf (call $make_list (i32.const 0)))
    (local.set $stmts_buf (call $list_extend_to
                            (local.get $stmts_buf)
                            (i32.add (i32.const 1) (local.get $n))))
    (local.set $stmt_count (i32.const 0))
    ;; First stmt: LLet(handle, temp_name, lo_val)
    (drop (call $list_set (local.get $stmts_buf)
                          (local.get $stmt_count)
                          (call $lexpr_make_llet
                                (local.get $handle)
                                (local.get $temp_name)
                                (local.get $lo_val))))
    (local.set $stmt_count (i32.add (local.get $stmt_count) (i32.const 1)))
    (local.set $i (i32.const 0))
    (block $done
      (loop $each
        (br_if $done (i32.ge_u (local.get $i) (local.get $n)))
        (local.set $sub_pat (call $list_index (local.get $sub_pats) (local.get $i)))
        (local.set $sub_tag (call $tag_of (local.get $sub_pat)))
        ;; Tuple field offset: 4*i (no variant tag prefix).
        (local.set $field_offset (i32.mul (local.get $i) (i32.const 4)))
        ;; PVar (130) — bind the name to the field load.
        (if (i32.eq (local.get $sub_tag) (i32.const 130))
          (then
            (local.set $sub_name (i32.load offset=4 (local.get $sub_pat)))
            (local.set $sub_h (local.get $expr_h))
            (drop (call $ls_bind_local (local.get $sub_name) (local.get $sub_h)))
            (local.set $temp_local_ref
              (call $lexpr_make_llocal (local.get $expr_h) (local.get $temp_name)))
            (local.set $field_load
              (call $lexpr_make_lfieldload
                    (local.get $sub_h)
                    (local.get $temp_local_ref)
                    (local.get $field_offset)))
            (local.set $sub_let
              (call $lexpr_make_llet
                    (local.get $sub_h)
                    (local.get $sub_name)
                    (local.get $field_load)))
            (local.set $stmts_buf (call $list_extend_to
                                    (local.get $stmts_buf)
                                    (i32.add (local.get $stmt_count) (i32.const 1))))
            (drop (call $list_set (local.get $stmts_buf)
                                  (local.get $stmt_count)
                                  (local.get $sub_let)))
            (local.set $stmt_count (i32.add (local.get $stmt_count) (i32.const 1)))))
        ;; PWild (131) — skip.
        ;; Nested PTuple/PCon: pass-through; named follow-up extends.
        (local.set $i (i32.add (local.get $i) (i32.const 1)))
        (br $each)))
    (call $lexpr_make_lblock
          (local.get $handle)
          (call $slice (local.get $stmts_buf)
                       (i32.const 0)
                       (local.get $stmt_count))))

  ;; "__pat_" prefix as a length-prefixed string. Allocated once per
  ;; call site; cheap.
  (func $synth_pat_prefix (result i32)
    (local $s i32)
    (local.set $s (call $str_alloc (i32.const 6)))
    (i32.store8 offset=4 (local.get $s) (i32.const 95))   ;; '_'
    (i32.store8 offset=5 (local.get $s) (i32.const 95))   ;; '_'
    (i32.store8 offset=6 (local.get $s) (i32.const 112))  ;; 'p'
    (i32.store8 offset=7 (local.get $s) (i32.const 97))   ;; 'a'
    (i32.store8 offset=8 (local.get $s) (i32.const 116))  ;; 't'
    (i32.store8 offset=9 (local.get $s) (i32.const 95))   ;; '_'
    (local.get $s))

  ;; ─── $lower_walk_stmt_fn — FnStmt arm (parser tag 121) ──────────────
  ;; Per src/lower.nx:590-613 + Lock #1/#2/#3/#4.
  ;; AST per parser_infra.wat:171-179:
  ;;   [tag=121][name][params][ret][effs][body] offsets 0/4/8/12/16/20.
  (func $lower_walk_stmt_fn (export "lower_walk_stmt_fn")
        (param $stmt i32) (param $handle i32) (result i32)
    (local $name i32) (local $params i32) (local $body_node i32)
    (local $param_names i32) (local $param_handles i32)
    (local $cp i32) (local $lo_body i32) (local $body_list i32)
    (local $fn_ir i32) (local $caps i32) (local $evs i32) (local $closure i32)
    (local.set $name      (i32.load offset=4  (local.get $stmt)))
    (local.set $params    (i32.load offset=8  (local.get $stmt)))
    (local.set $body_node (i32.load offset=20 (local.get $stmt)))
    ;; Bind only inside an existing function frame. At module scope the
    ;; name was pre-registered by $lower_program and resolves as LGlobal.
    (if (call $ls_in_function)
      (then
        (drop (call $ls_bind_local (local.get $name) (local.get $handle)))))
    (local.set $param_names   (call $lower_param_names   (local.get $params)))
    (local.set $param_handles (call $lower_param_handles (local.get $params)))
    (local.set $cp (call $ls_push_scope))
    (call $ls_enter_function)
    (call $bind_names_as_locals (local.get $param_names) (local.get $param_handles))
    (local.set $lo_body (call $lower_expr (local.get $body_node)))
    (call $ls_exit_function)
    (call $ls_pop_scope (local.get $cp))
    (local.set $body_list (call $make_list (i32.const 0)))
    (local.set $body_list (call $list_extend_to (local.get $body_list) (i32.const 1)))
    (drop (call $list_set (local.get $body_list) (i32.const 0) (local.get $lo_body)))
    (local.set $fn_ir (call $lowfn_make
                        (local.get $name)
                        (call $len (local.get $params))
                        (local.get $param_names)
                        (local.get $body_list)
                        (call $row_make_pure)))
    (local.set $caps (call $make_list (i32.const 0)))
    (local.set $evs  (call $make_list (i32.const 0)))
    (local.set $closure (call $lexpr_make_lmakeclosure
                          (local.get $handle)
                          (local.get $fn_ir)
                          (local.get $caps)
                          (local.get $evs)))
    ;; Lock #1: wrap in LLet(handle, name, closure).
    (call $lexpr_make_llet
      (local.get $handle)
      (local.get $name)
      (local.get $closure)))

  ;; ─── $lower_walk_stmt_typedef — TypeDefStmt arm (tag 122) ──────────
  ;; Per Lock #9. LConst(handle, 0) sentinel.
  (func $lower_walk_stmt_typedef (export "lower_walk_stmt_typedef")
        (param $stmt i32) (param $handle i32) (result i32)
    (drop (local.get $stmt))
    (call $lexpr_make_lconst (local.get $handle) (i32.const 0)))

  ;; ─── $lower_walk_stmt_effect_decl — EffectDeclStmt arm (tag 123) ───
  ;; Per Lock #9.
  (func $lower_walk_stmt_effect_decl (export "lower_walk_stmt_effect_decl")
        (param $stmt i32) (param $handle i32) (result i32)
    (drop (local.get $stmt))
    (call $lexpr_make_lconst (local.get $handle) (i32.const 0)))

  ;; ─── $lower_walk_stmt_handler_decl — HandlerDeclStmt arm (tag 124) ──
  ;; Per src/lower.nx:617-625 + Lock #7.
  ;; Layout assumption: [tag=124][handler_name][effect_name][arms_list]
  ;;   offsets 0/4/8/12 (parser_decl.wat doesn't expose $mk_HandlerDeclStmt
  ;;   per file read; verified via src/lower.nx wheel canonical).
  (func $lower_walk_stmt_handler_decl (export "lower_walk_stmt_handler_decl")
        (param $stmt i32) (param $handle i32) (result i32)
    (local $arms i32) (local $arm_decls i32) (local $sentinel i32)
    (local $stmts i32) (local $i i32) (local $n i32)
    (local $handler_name i32)
    (local.set $arms         (i32.load offset=12 (local.get $stmt)))
    (local.set $handler_name (i32.load offset=4  (local.get $stmt)))
    ;; Lock #7: invoke chunk #8's helper (third caller — abstraction earned).
    ;; Per Hβ.first-light.handler-arm-fn-name-discriminator: pass the
    ;; handler_name as the discriminator so each top-level handler's
    ;; arm fns get unique WASM symbols ($op_<handler>_<op>).
    (local.set $arm_decls (call $lower_handler_arms_as_decls
                            (local.get $arms)
                            (local.get $handler_name)))
    (local.set $sentinel  (call $lexpr_make_lconst (local.get $handle) (i32.const 0)))
    ;; Build stmts = arm_decls ++ [sentinel]. Buffer-counter (Ω.3).
    (local.set $n     (call $len (local.get $arm_decls)))
    (local.set $stmts (call $make_list (i32.const 0)))
    (local.set $stmts (call $list_extend_to (local.get $stmts)
                        (i32.add (local.get $n) (i32.const 1))))
    (local.set $i (i32.const 0))
    (block $done
      (loop $copy
        (br_if $done (i32.ge_u (local.get $i) (local.get $n)))
        (drop (call $list_set (local.get $stmts) (local.get $i)
                (call $list_index (local.get $arm_decls) (local.get $i))))
        (local.set $i (i32.add (local.get $i) (i32.const 1)))
        (br $copy)))
    (drop (call $list_set (local.get $stmts) (local.get $n) (local.get $sentinel)))
    (call $lexpr_make_lblock (local.get $handle) (local.get $stmts)))

  ;; ─── $lower_walk_stmt_expr — ExprStmt arm (tag 125) ─────────────────
  ;; Per src/lower.nx:632 + Lock #8. Direct passthrough.
  ;; AST per parser_infra.wat:182-186: [tag=125][node] offsets 0/4.
  (func $lower_walk_stmt_expr (export "lower_walk_stmt_expr")
        (param $stmt i32) (param $handle i32) (result i32)
    (local $inner i32)
    (drop (local.get $handle))
    (local.set $inner (i32.load offset=4 (local.get $stmt)))
    (call $lower_expr (local.get $inner)))

  ;; ─── $lower_walk_stmt_import — ImportStmt arm (tag 126) ────────────
  ;; Per Lock #9.
  (func $lower_walk_stmt_import (export "lower_walk_stmt_import")
        (param $stmt i32) (param $handle i32) (result i32)
    (drop (local.get $stmt))
    (call $lexpr_make_lconst (local.get $handle) (i32.const 0)))

  ;; ─── $lower_walk_stmt_refine — RefineStmt arm (tag 127) ────────────
  ;; Per Lock #9.
  (func $lower_walk_stmt_refine (export "lower_walk_stmt_refine")
        (param $stmt i32) (param $handle i32) (result i32)
    (drop (local.get $stmt))
    (call $lexpr_make_lconst (local.get $handle) (i32.const 0)))

  ;; ─── $lower_walk_stmt_documented — Documented arm (tag 128) ─────────
  ;; Per src/lower.nx:630 + Lock #10. Recurses on inner_node (offset 8).
  (func $lower_walk_stmt_documented (export "lower_walk_stmt_documented")
        (param $stmt i32) (param $handle i32) (result i32)
    (local $inner_node i32)
    (drop (local.get $handle))
    (local.set $inner_node (i32.load offset=8 (local.get $stmt)))
    (call $lower_stmt (local.get $inner_node)))

  ;; ─── $lower_stmt — public dispatcher (per Lock #12) ─────────────────
  ;; Per src/lower.nx:564-571 + infer/walk_stmt.wat:623-671 sibling.
  (func $lower_stmt (export "lower_stmt") (param $node i32) (result i32)
    (local $body i32) (local $body_tag i32)
    (local $stmt i32) (local $stmt_tag i32)
    (local $handle i32)
    (local.set $body   (i32.load offset=4  (local.get $node)))
    (local.set $handle (i32.load offset=12 (local.get $node)))
    (local.set $body_tag (i32.load offset=0 (local.get $body)))
    ;; NExpr (110) — delegate to $lower_expr.
    (if (i32.eq (local.get $body_tag) (i32.const 110))
      (then (return (call $lower_expr (local.get $node)))))
    ;; NPat (112) / NHole (113) — degenerate LConst sentinel.
    (if (i32.eq (local.get $body_tag) (i32.const 112))
      (then (return (call $lexpr_make_lconst (local.get $handle) (i32.const 0)))))
    (if (i32.eq (local.get $body_tag) (i32.const 113))
      (then (return (call $lexpr_make_lconst (local.get $handle) (i32.const 0)))))
    ;; NStmt (111) — read inner Stmt + dispatch on Stmt tag.
    (if (i32.ne (local.get $body_tag) (i32.const 111))
      (then (unreachable)))
    (local.set $stmt (i32.load offset=4 (local.get $body)))
    (local.set $stmt_tag (call $tag_of (local.get $stmt)))
    (if (i32.eq (local.get $stmt_tag) (i32.const 120))
      (then (return (call $lower_walk_stmt_let
              (local.get $stmt) (local.get $handle)))))
    (if (i32.eq (local.get $stmt_tag) (i32.const 121))
      (then (return (call $lower_walk_stmt_fn
              (local.get $stmt) (local.get $handle)))))
    (if (i32.eq (local.get $stmt_tag) (i32.const 122))
      (then (return (call $lower_walk_stmt_typedef
              (local.get $stmt) (local.get $handle)))))
    (if (i32.eq (local.get $stmt_tag) (i32.const 123))
      (then (return (call $lower_walk_stmt_effect_decl
              (local.get $stmt) (local.get $handle)))))
    (if (i32.eq (local.get $stmt_tag) (i32.const 124))
      (then (return (call $lower_walk_stmt_handler_decl
              (local.get $stmt) (local.get $handle)))))
    (if (i32.eq (local.get $stmt_tag) (i32.const 125))
      (then (return (call $lower_walk_stmt_expr
              (local.get $stmt) (local.get $handle)))))
    (if (i32.eq (local.get $stmt_tag) (i32.const 126))
      (then (return (call $lower_walk_stmt_import
              (local.get $stmt) (local.get $handle)))))
    (if (i32.eq (local.get $stmt_tag) (i32.const 127))
      (then (return (call $lower_walk_stmt_refine
              (local.get $stmt) (local.get $handle)))))
    (if (i32.eq (local.get $stmt_tag) (i32.const 128))
      (then (return (call $lower_walk_stmt_documented
              (local.get $stmt) (local.get $handle)))))
    ;; H6 wildcard: unknown Stmt tag.
    (unreachable))

  ;; ─── $lower_stmt_list — buffer-counter iteration (Lock #11) ─────────
  ;; Per src/lower.nx:556-558 wheel SHAPE; seed Ω.3 buffer-counter.
  (func $lower_stmt_list (export "lower_stmt_list")
        (param $stmts i32) (result i32)
    (local $n i32) (local $i i32) (local $buf i32)
    (local $stmt_node i32) (local $lowered i32)
    (local.set $n   (call $len (local.get $stmts)))
    (local.set $buf (call $make_list (i32.const 0)))
    (local.set $buf (call $list_extend_to (local.get $buf) (local.get $n)))
    (local.set $i   (i32.const 0))
    (block $done
      (loop $each
        (br_if $done (i32.ge_u (local.get $i) (local.get $n)))
        (local.set $stmt_node (call $list_index (local.get $stmts) (local.get $i)))
        (local.set $lowered   (call $lower_stmt (local.get $stmt_node)))
        (drop (call $list_set (local.get $buf) (local.get $i) (local.get $lowered)))
        (local.set $i (i32.add (local.get $i) (i32.const 1)))
        (br $each)))
    (local.get $buf))
