  ;; ═══ walk_compound.wat — Hβ.lower compound-Expr arms (Tier 7) ═══════
  ;; Hβ.lower cascade chunk #9 of 11 per Hβ-lower-substrate.md §12.3 dep order.
  ;;
  ;; What this chunk IS (per Hβ-lower-substrate.md §4.2 lines 369-461 +
  ;;                     src/lower.nx:344-461 lower_expr_body compound arms):
  ;;   Ten compound-Expr arms — the recursion sites where the kernel's
  ;;   primitive #1 graph carries source TypeHandles through into LowExpr
  ;;   records (LMakeList/LMakeTuple/LMakeRecord/LMakeVariant/LIf/LBlock/
  ;;   LMatch/LFieldLoad/LUnaryOp/LMakeClosure):
  ;;
  ;;     87  UnaryOpExpr     → LUnaryOp     (tag 307)
  ;;     89  LambdaExpr      → LMakeClosure (tag 311)  Lock #1 caps+evs empty seed
  ;;     90  IfExpr          → LIf          (tag 314)  Lock #10 single-elem branches
  ;;     91  BlockExpr       → LBlock       (tag 315)  Lock #2 final-only seed
  ;;     92  MatchExpr       → LMatch       (tag 321)  Lock #3 arms empty seed
  ;;     96  MakeListExpr    → LMakeList    (tag 316)
  ;;     97  MakeTupleExpr   → LMakeTuple   (tag 317)
  ;;     98  MakeRecordExpr  → LMakeRecord  (tag 318)  Lock #6 value-only fields
  ;;     99  NamedRecordExpr → LMakeRecord  (tag 318)  Lock #5 H2.3 collapse
  ;;     100 FieldExpr       → LFieldLoad   (tag 334)  Lock #4 offset 0 seed
  ;;
  ;;   Plus retrofits walk_call.wat:295-324 dispatcher with the above
  ;;   ten tag arms (per chunk #8 Lock #10 two-file precedent).
  ;;
  ;; Implements: Hβ-lower-substrate.md §4.2 + §6.3 + §11 + §12.3 #9;
  ;;             src/lower.nx:344-345 UnaryOpExpr arm;
  ;;             src/lower.nx:369-372 IfExpr arm (Lock #10);
  ;;             src/lower.nx:374-380 BlockExpr arm (Lock #2);
  ;;             src/lower.nx:382-383 MatchExpr arm (Lock #3);
  ;;             src/lower.nx:385-389 MakeList/MakeTuple arms;
  ;;             src/lower.nx:391-399 MakeRecord/NamedRecord arms (Lock #5+#6);
  ;;             src/lower.nx:401-428 LambdaExpr arm (Lock #1+#11);
  ;;             src/lower.nx:450-461 FieldExpr arm (Lock #4);
  ;;             src/lower.nx:1063-1068 lower_record_field_values.
  ;; Exports:    $lower_binop,
  ;;             $lower_unary_op,
  ;;             $lower_lambda,
  ;;             $lower_if,
  ;;             $lower_block,
  ;;             $lower_match,
  ;;             $lower_make_list,
  ;;             $lower_make_tuple,
  ;;             $lower_make_record,
  ;;             $lower_named_record,
  ;;             $lower_field
  ;; Uses:       $walk_expr_node_handle (infer/walk_expr.wat:306-307),
  ;;             $lexpr_make_lunaryop / lmakeclosure / lif / lblock /
  ;;               lmatch / lmakelist / lmaketuple / lmakerecord /
  ;;               lmakevariant / lfieldload (lower/lexpr.wat),
  ;;             $lower_expr (lower/walk_call.wat — retrofitted at this
  ;;               commit to add tag-87/89/90/91/92/96/97/98/99/100 arms),
  ;;             $make_list / $list_index / $list_set / $list_extend_to /
  ;;               $len (runtime/list.wat — buffer-counter Ω.3),
  ;;             $record_get (runtime/record.wat — for MakeRecord field-pair
  ;;               value extraction per Lock #6)
  ;; Test:       bootstrap/test/lower/walk_compound_if.wat,
  ;;             bootstrap/test/lower/walk_compound_make_list.wat,
  ;;             bootstrap/test/lower/walk_compound_make_tuple.wat,
  ;;             bootstrap/test/lower/walk_compound_field.wat,
  ;;             bootstrap/test/lower/walk_compound_lambda.wat
  ;;
  ;; ═══ LOCKS (wheel-canonical override walkthrough §4.2 prose) ════════
  ;;
  ;; Lock #1: LambdaExpr seed defaults — caps=empty, evs=empty, fn=0.
  ;;          Wheel src/lower.nx:411-417 calls collect_free_vars +
  ;;          resolve_captures_outer + ls_enter_frame/ls_exit_frame —
  ;;          NONE of which exist at the seed (state.wat exposes only
  ;;          ls_bind_local/ls_lookup_local/ls_lookup_or_capture/
  ;;          ls_reset_function). LFn ADT not yet seed-substrate
  ;;          (lexpr.wat:160 lvalue-lowfn-lpat-substrate follow-up).
  ;;          Seed emits LMakeClosure(h, 0, empty_list, empty_list).
  ;;          Body recursively lowered via $lower_expr — result DROPPED
  ;;          per Lock #11 (graph reads still fire). Named follow-up
  ;;          Hβ.lower.lambda-capture-substrate covers full wheel parity
  ;;          when collect_free_vars + resolve_captures_outer +
  ;;          ls_enter_frame/ls_exit_frame + LFn ADT all converge.
  ;;
  ;; Lock #2: BlockExpr seed lowers final_expr ONLY; stmts list empty.
  ;;          Wheel src/lower.nx:374-380 lowers stmts via lower_stmt_list +
  ;;          appends final via [lo_final]. $lower_stmt lands at chunk #10;
  ;;          BlockExpr's stmts (parser_compound.wat:130-137 wraps each as
  ;;          nstmt(mk_ExprStmt(...))) require chunk-#10 dispatcher. Seed
  ;;          emits LBlock(h, [lo_final]) — single-element stmts list.
  ;;          Named follow-up Hβ.lower.blockexpr-stmts-substrate covers
  ;;          full wheel parity when chunk #10 lands $lower_stmt.
  ;;          Substrate-honest deferral per Lock #2 — bodied with reasoning,
  ;;          NOT silent stub.
  ;;
  ;; Lock #3: MatchExpr seed lowers scrut ONLY; arms list empty. Wheel
  ;;          src/lower.nx:382-383 calls lower_match_arms which calls
  ;;          bind_pat_locals + lower_pat + ls_push_scope/ls_pop_scope —
  ;;          NONE of which exist at the seed. LowPat ADT opaque per
  ;;          lexpr.wat:570 lvalue-lowfn-lpat-substrate follow-up. Seed
  ;;          emits LMatch(h, lo_scrut, empty_list). Named follow-up
  ;;          Hβ.lower.match-arm-pattern-substrate covers full wheel
  ;;          parity.
  ;;
  ;; Lock #4: FieldExpr offset is sentinel 0 at seed. Wheel
  ;;          src/lower.nx:457-460 + 525-552 calls resolve_field_offset
  ;;          which walks TRecord fields via lookup_ty + structural
  ;;          accessor. ty.wat exposes $ty_tag + $ty_tfun_row +
  ;;          $ty_tcont_discipline (per lookup.wat) but NOT
  ;;          $ty_trecord_fields list-walker at the lower layer. Seed
  ;;          emits LFieldLoad(h, lo_rec, 0) — matches wheel's
  ;;          src/lower.nx:543 `_ => 0` fallback (which fires when
  ;;          lookup returns non-record type). Named follow-up
  ;;          Hβ.lower.field-offset-resolution covers full
  ;;          field-byte-offset arithmetic when ty.wat exposes
  ;;          structural record-fields walker.
  ;;
  ;; Lock #5: NamedRecordExpr (tag 99) collapses to MakeRecord per H2.3.
  ;;          Wheel src/lower.nx:394-399: nominal records lower
  ;;          identically to bare record literals — type identity is
  ;;          type-system-only; runtime sees raw fields. type_name
  ;;          preserved in AST for diagnostics ONLY (drift-8 audit:
  ;;          threaded-not-compared). $lower_make_record + $lower_named_record
  ;;          both call $lower_make_record_body — chunk-private factor;
  ;;          third caller earns the abstraction per Anchor 7 (currently
  ;;          two callers; ready for Hβ.lower.makerecord-promotion).
  ;;
  ;; Lock #6: MakeRecordExpr fields list lowered via per-field value
  ;;          extraction (record_get offset 4 of pair-record), NOT
  ;;          $lower_expr_list. Per wheel src/lower.nx:391-392 +
  ;;          1063-1068 lower_record_field_values. Each fields-list
  ;;          element is a `(name, value)` pair-record with alphabetical
  ;;          Ω.5 layout (name=offset 0, value=offset 4). Drift 7
  ;;          closure: ONE lowered-value list (sort-order = layout-order).
  ;;
  ;; Lock #7: AST navigation per chunk #6/#7/#8 precedent — every arm
  ;;          reads $h = $walk_expr_node_handle($node); then $body =
  ;;          i32.load offset=4 $node; then variant-struct = i32.load
  ;;          offset=4 $body; then variant-specific offsets. NO local
  ;;          re-derivation of $node_handle.
  ;;
  ;; Lock #8: $lower_expr dispatcher retrofit at walk_call.wat:295-324.
  ;;          This commit retrofits TEN tag arms (87/89/90/91/92/96/97/
  ;;          98/99/100). Per chunk #8 Lock #10 two-file precedent. The
  ;;          terminal (unreachable) trap STAYS — guards future Expr-region
  ;;          growth.
  ;;
  ;; Lock #9: AST layouts for tags lacking parser_*.wat constructors.
  ;;          Five of the ten tags lack $mk_*: 87 (UnaryOp), 89 (Lambda),
  ;;          98 (MakeRecord), 99 (NamedRecord), 100 (FieldExpr).
  ;;          Confirmed exist: 90 (mk_IfExpr parser_infra.wat:119),
  ;;          91 (mk_BlockExpr parser_infra.wat:128), 92 (mk_MatchExpr
  ;;          parser_infra.wat:136), 96 (mk_MakeListExpr parser_compound
  ;;          .wat:77), 97 (mk_MakeTupleExpr parser_compound.wat:70).
  ;;          Harnesses for the missing five use direct $alloc + i32.store
  ;;          per chunk #8 walk_handle_simple.wat:31-34 precedent. Layouts:
  ;;            87 [tag=87][op_name_str][inner_node]  offsets 0/4/8
  ;;            89 [tag=89][params_list][body_node]   offsets 0/4/8
  ;;            98 [tag=98][fields_list]              offsets 0/4
  ;;            99 [tag=99][type_name_str][fields]    offsets 0/4/8
  ;;            100 [tag=100][rec_node][field_str]    offsets 0/4/8
  ;;          Drift-9-safe: an unconstructible AST tag will simply never
  ;;          reach this arm; if/when parser produces these tags, body is
  ;;          correct per wheel canonical. Named follow-up
  ;;          Hβ.lower.compound-mk-constructors covers parser-side
  ;;          constructor landing.
  ;;
  ;; Lock #10: IfExpr branches are SINGLE-ELEMENT lists — [lo_then],
  ;;           [lo_else]. Per wheel src/lower.nx:369-372 canonical.
  ;;           lexpr.wat:455-467 LIf field 2/3 are List per src/lower.nx:121
  ;;           LIf(Int, LowExpr, List, List) — current parser_compound.wat:
  ;;           163-188 already handles `if cond { block }` by recursing into
  ;;           parse_block (producing a BlockExpr); IfExpr's then_e/else_e
  ;;           is a single BlockExpr node, NOT a stmts list.
  ;;
  ;; Lock #11: $lower_lambda recursively lowers body via $lower_expr,
  ;;           DROPS the result. The graph reads + $lookup_ty side
  ;;           effects fire; the LowExpr is unused (LFn ADT not landed).
  ;;           Drop is explicit (not silent omission) — surfaces in
  ;;           Hβ.lower.lambda-capture-substrate when LFn lands.
  ;;
  ;; ═══ EIGHT INTERROGATIONS (per Hβ-lower-substrate.md §5.3) ══════════
  ;;
  ;; 1. Graph?       Each arm reads $walk_expr_node_handle($node) (offset
  ;;                 12 of N-wrapper). Each LowExpr's field 0 IS the source
  ;;                 TypeHandle for $lookup_ty live read. Read-only on graph.
  ;;
  ;; 2. Handler?     Wheel: 4-effect chain (LookupTy + LowerCtx + EnvRead
  ;;                 + Diagnostic) @resume=OneShot. Seed: 10 direct
  ;;                 functions + 1 chunk-private helper $lower_record_field_values.
  ;;                 $classify_handler NOT INVOKED here.
  ;;
  ;; 3. Verb?        Mostly silent. LambdaExpr is the substrate that the
  ;;                 ~> verb's HandleExpr/PipeExpr arms compose on — but
  ;;                 verb-projection itself is walk_handle.wat's domain.
  ;;
  ;; 4. Row?         Silent at this chunk. LambdaExpr's row-classification
  ;;                 is set during inference; lower reads via $lookup_ty
  ;;                 when downstream call-sites query monomorphism (chunk #7).
  ;;
  ;; 5. Ownership?   Each $lexpr_make_l* output is `own` of bump.
  ;;                 Sub-LowExprs `ref`. Lists via Ω.3 buffer-counter.
  ;;
  ;; 6. Refinement?  Transparent. TRefined dispatches via $lookup_ty;
  ;;                 verify ledger holds obligations.
  ;;
  ;; 7. Gradient?    LMakeRecord/LMakeVariant/LMakeTuple/LMakeList all
  ;;                 use the SAME $make_record(tag, arity) construction
  ;;                 path — drift-6 closure. Lambda's eventual full
  ;;                 LMakeClosure IS the closure-capture cash-out
  ;;                 (deferred per Lock #1). FieldExpr's resolved offset
  ;;                 IS the W6 record-offset cash-out (deferred per Lock #4).
  ;;
  ;; 8. Reason?      Read-only. Every LowExpr's field 0 carries the handle
  ;;                 whose GNode preserves Reason chain.
  ;;
  ;; ═══ FORBIDDEN PATTERNS AUDIT ════════════════════════════════════════
  ;;
  ;; - Drift 1 (Rust vtable):        No $compound_dispatch_table. The
  ;;                                  retrofitted dispatcher at walk_call.wat:
  ;;                                  295-324 is a 12-arm (if (i32.eq tag N) ...)
  ;;                                  chain — direct sentinel comparison; no
  ;;                                  table indirection. Word "vtable" appears
  ;;                                  NOWHERE except in this audit.
  ;;
  ;; - Drift 2 (Scheme env frame):   The seed's state.wat is one flat list;
  ;;                                  this chunk does NOT push/pop frame
  ;;                                  stacks. Lambda's frame-discipline
  ;;                                  deferred per Lock #1.
  ;;
  ;; - Drift 4 (monad transformer):  No LowerM. Each $lower_<arm> is
  ;;                                  (param i32) (result i32). Direct.
  ;;
  ;; - Drift 5 (C calling conv):     Single $node param + single i32
  ;;                                  return per arm. NO __closure/__ev
  ;;                                  split. LMakeClosure arity-4 fields
  ;;                                  ALL set at construction.
  ;;
  ;; - Drift 6 (primitive-special):  LMakeList/LMakeTuple/LMakeRecord/
  ;;                                  LMakeVariant ALL use $make_record(tag,
  ;;                                  arity) — same discipline as every
  ;;                                  other LowExpr. NO "tuples special
  ;;                                  because pair." LitBool's nullary-ADT
  ;;                                  precedent (chunk #6 Lock #3) carries
  ;;                                  through.
  ;;
  ;; - Drift 7 (parallel-arrays):    LMakeRecord.fields is ONE list of
  ;;                                  values (Lock #6 sort-order = layout-
  ;;                                  order). LMakeVariant.args is ONE list.
  ;;                                  LMatch.arms is ONE list (Lock #3
  ;;                                  empty-seed). LMakeClosure's caps +
  ;;                                  evs are TWO conceptually-distinct
  ;;                                  lists per H1 reification (caps =
  ;;                                  closure values, evs = evidence slots)
  ;;                                  — wheel-canonical, NOT parallel-arrays.
  ;;
  ;; - Drift 8 (string-keyed):       Tag-int dispatch only. UnaryOp's
  ;;                                  op_name THREADED not COMPARED.
  ;;                                  NamedRecordExpr's type_name similarly
  ;;                                  threaded-then-discarded per H2.3
  ;;                                  (Lock #5).
  ;;
  ;; - Drift 9 (deferred-by-omission): All TEN arms FULLY BODIED this commit.
  ;;                                  Lock #1/#2/#3/#4 deferrals bodied
  ;;                                  with reasoning + named follow-ups —
  ;;                                  NOT silent stubs.
  ;;
  ;; - Foreign fluency JS async/await: NEVER "promise" / "async" / "future"
  ;;                                  / "await". Vocabulary stays Inka.
  ;;
  ;; - Foreign fluency Scheme call/cc: NEVER "captured stack" /
  ;;                                  "undelimited."
  ;;
  ;; - Foreign fluency LLVM/GHC IR / OCaml closure conversion: NEVER "SSA"
  ;;                                  / "phi" / "closure conversion pass" /
  ;;                                  "Lambda lifting." Closure construction
  ;;                                  IS LMakeClosure per spec 05.
  ;;
  ;; ═══ Named follow-ups (Drift 9 closure) ═══════════════════════════════
  ;;
  ;;   - Hβ.lower.lambda-capture-substrate:
  ;;             Wheel src/lower.nx:411-417 collect_free_vars +
  ;;             resolve_captures_outer + ls_enter_frame + ls_exit_frame
  ;;             + LFn ADT all converge as one peer landing. Replaces
  ;;             Lock #1+#11 stubs with full closure-capture cash-out.
  ;;
  ;;   - Hβ.lower.blockexpr-stmts-substrate:
  ;;             Per Lock #2. When chunk #10 walk_stmt.wat lands
  ;;             $lower_stmt + adds tag-91 BlockExpr stmt-list lowering,
  ;;             this arm grows the stmts-then-final shape.
  ;;
  ;;   - Hβ.lower.match-arm-pattern-substrate:
  ;;             Per Lock #3. LowPat ADT (lexpr.wat:570 follow-up) +
  ;;             ls_push_scope/ls_pop_scope at state.wat + bind_pat_locals
  ;;             + lower_pat all converge.
  ;;
  ;;   - Hβ.lower.field-offset-resolution:
  ;;             Per Lock #4. ty.wat structural record-fields walker
  ;;             ($ty_trecord_fields + $ty_trecord_open_fields) lands;
  ;;             $resolve_field_offset becomes a real walk per
  ;;             src/lower.nx:525-552.
  ;;
  ;;   - Hβ.lower.compound-mk-constructors:
  ;;             Per Lock #9. parser_compound.wat (or parser_infra.wat)
  ;;             grows mk_UnaryOpExpr / mk_LambdaExpr / mk_MakeRecordExpr /
  ;;             mk_NamedRecordExpr / mk_FieldExpr — five constructors.
  ;;             Harnesses migrate from direct-alloc to structured.
  ;;
  ;;   - Hβ.lower.makerecord-promotion:
  ;;             Per Lock #5. When third caller emerges (e.g., a future
  ;;             record-pattern lowering site), $lower_make_record_body
  ;;             promotes from chunk-private factor to peer file.
  ;;
  ;;   - Hβ.lower.lower-expr-dispatch-extension:
  ;;             (extending from chunk #7 + #8) walk_call.wat:295-324
  ;;             retrofit completes with this commit's TEN tag arms.
  ;;             Future Expr-region growth lands additional arms.

  ;; ─── $lower_record_field_values — chunk-private (Lock #6) ──────────
  ;; Per src/lower.nx:1063-1068 lower_record_field_values. Each fields-list
  ;; element is a `(name, value)` pair-record with alphabetical Ω.5 layout
  ;; (name=offset 0, value=offset 4); extract value + recursively $lower_expr.
  ;; Buffer-counter (Ω.3). Sort-order = layout-order; ONE lowered list.
  (func $lower_record_field_values (param $fields i32) (result i32)
    (local $n i32) (local $i i32) (local $buf i32)
    (local $field_pair i32) (local $value_node i32) (local $lo_value i32)
    (local.set $n   (call $len (local.get $fields)))
    (local.set $buf (call $make_list (i32.const 0)))
    (local.set $buf (call $list_extend_to (local.get $buf) (local.get $n)))
    (local.set $i   (i32.const 0))
    (block $done
      (loop $each
        (br_if $done (i32.ge_u (local.get $i) (local.get $n)))
        (local.set $field_pair (call $list_index (local.get $fields) (local.get $i)))
        ;; Lock #6: pair-record offset 4 = value (alphabetical name<value).
        (local.set $value_node (call $record_get (local.get $field_pair) (i32.const 1)))
        (local.set $lo_value   (call $lower_expr (local.get $value_node)))
        (drop (call $list_set (local.get $buf) (local.get $i) (local.get $lo_value)))
        (local.set $i (i32.add (local.get $i) (i32.const 1)))
        (br $each)))
    (local.get $buf))

  ;; ─── $lower_expr_list_compound — chunk-private buffer-counter helper ─
  ;; Per src/lower.nx:1055-1057 lower_expr_list. Same shape as walk_call's
  ;; $lower_args; chunk-private until third caller emerges.
  (func $lower_expr_list_compound (param $nodes i32) (result i32)
    (local $n i32) (local $i i32) (local $buf i32)
    (local $node i32) (local $lo i32)
    (local.set $n   (call $len (local.get $nodes)))
    (local.set $buf (call $make_list (i32.const 0)))
    (local.set $buf (call $list_extend_to (local.get $buf) (local.get $n)))
    (local.set $i   (i32.const 0))
    (block $done
      (loop $each
        (br_if $done (i32.ge_u (local.get $i) (local.get $n)))
        (local.set $node (call $list_index (local.get $nodes) (local.get $i)))
        (local.set $lo   (call $lower_expr (local.get $node)))
        (drop (call $list_set (local.get $buf) (local.get $i) (local.get $lo)))
        (local.set $i (i32.add (local.get $i) (i32.const 1)))
        (br $each)))
    (local.get $buf))

  ;; ─── Parameter + pattern helpers ───────────────────────────────────

  (func $lower_param_names (param $params i32) (result i32)
    (local $n i32) (local $i i32) (local $buf i32) (local $param i32)
    (local.set $n   (call $len (local.get $params)))
    (local.set $buf (call $make_list (i32.const 0)))
    (local.set $buf (call $list_extend_to (local.get $buf) (local.get $n)))
    (local.set $i   (i32.const 0))
    (block $done
      (loop $each
        (br_if $done (i32.ge_u (local.get $i) (local.get $n)))
        (local.set $param (call $list_index (local.get $params) (local.get $i)))
        (drop (call $list_set (local.get $buf) (local.get $i)
                (i32.load offset=4 (local.get $param))))
        (local.set $i (i32.add (local.get $i) (i32.const 1)))
        (br $each)))
    (local.get $buf))

  (func $lower_param_handles (param $params i32) (result i32)
    (local $n i32) (local $i i32) (local $buf i32)
    (local $param i32) (local $ty i32) (local $h i32)
    (local.set $n   (call $len (local.get $params)))
    (local.set $buf (call $make_list (i32.const 0)))
    (local.set $buf (call $list_extend_to (local.get $buf) (local.get $n)))
    (local.set $i   (i32.const 0))
    (block $done
      (loop $each
        (br_if $done (i32.ge_u (local.get $i) (local.get $n)))
        (local.set $param (call $list_index (local.get $params) (local.get $i)))
        (local.set $ty    (i32.load offset=8 (local.get $param)))
        (local.set $h     (i32.const 0))
        (if (i32.eq (call $ty_tag (local.get $ty)) (i32.const 104))
          (then
            (local.set $h (call $ty_tvar_handle (local.get $ty)))))
        (drop (call $list_set (local.get $buf) (local.get $i) (local.get $h)))
        (local.set $i (i32.add (local.get $i) (i32.const 1)))
        (br $each)))
    (local.get $buf))

  (func $bind_names_as_locals (param $names i32) (param $handles i32)
    (local $n i32) (local $i i32)
    (local.set $n (call $len (local.get $names)))
    (local.set $i (i32.const 0))
    (block $done
      (loop $each
        (br_if $done (i32.ge_u (local.get $i) (local.get $n)))
        (drop (call $ls_bind_local
                (call $list_index (local.get $names) (local.get $i))
                (call $list_index (local.get $handles) (local.get $i))))
        (local.set $i (i32.add (local.get $i) (i32.const 1)))
        (br $each))))

  (func $bind_pat_locals_fields (param $fields i32)
    (local $n i32) (local $i i32) (local $entry i32)
    (local.set $n (call $len (local.get $fields)))
    (local.set $i (i32.const 0))
    (block $done
      (loop $each
        (br_if $done (i32.ge_u (local.get $i) (local.get $n)))
        (local.set $entry (call $list_index (local.get $fields) (local.get $i)))
        (call $bind_pat_locals (call $record_get (local.get $entry) (i32.const 1)))
        (local.set $i (i32.add (local.get $i) (i32.const 1)))
        (br $each))))

  (func $bind_pat_locals_list (param $pats i32)
    (local $n i32) (local $i i32)
    (local.set $n (call $len (local.get $pats)))
    (local.set $i (i32.const 0))
    (block $done
      (loop $each
        (br_if $done (i32.ge_u (local.get $i) (local.get $n)))
        (call $bind_pat_locals (call $list_index (local.get $pats) (local.get $i)))
        (local.set $i (i32.add (local.get $i) (i32.const 1)))
        (br $each))))

  (func $bind_pat_locals (param $pat i32)
    (local $tag i32)
    (if (i32.eq (local.get $pat) (i32.const 131))
      (then (return)))
    (if (i32.lt_u (local.get $pat) (global.get $heap_base))
      (then (unreachable)))
    (local.set $tag (call $tag_of (local.get $pat)))
    (if (i32.eq (local.get $tag) (i32.const 130))
      (then
        (drop (call $ls_bind_local (i32.load offset=4 (local.get $pat)) (i32.const 0)))
        (return)))
    (if (i32.eq (local.get $tag) (i32.const 133))
      (then
        (call $bind_pat_locals_list (i32.load offset=8 (local.get $pat)))
        (return)))
    (if (i32.eq (local.get $tag) (i32.const 134))
      (then
        (call $bind_pat_locals_list (i32.load offset=4 (local.get $pat)))
        (return)))
    (if (i32.eq (local.get $tag) (i32.const 135))
      (then
        (call $bind_pat_locals_list (i32.load offset=4 (local.get $pat)))
        (return)))
    (if (i32.eq (local.get $tag) (i32.const 136))
      (then
        (call $bind_pat_locals_fields (i32.load offset=4 (local.get $pat)))
        (return))))

  (func $lower_pat_record_fields (param $fields i32) (param $field_idx i32) (param $scrut_h i32) (result i32)
    (local $n i32) (local $i i32) (local $buf i32)
    (local $entry i32) (local $name i32) (local $sub_pat i32)
    (local $lo_pat i32) (local $triple i32)
    (local.set $n   (call $len (local.get $fields)))
    (local.set $buf (call $make_list (i32.const 0)))
    (local.set $buf (call $list_extend_to (local.get $buf) (local.get $n)))
    (local.set $i   (i32.const 0))
    (block $done
      (loop $each
        (br_if $done (i32.ge_u (local.get $i) (local.get $n)))
        (local.set $entry   (call $list_index (local.get $fields) (local.get $i)))
        (local.set $name    (call $record_get (local.get $entry) (i32.const 0)))
        (local.set $sub_pat (call $record_get (local.get $entry) (i32.const 1)))
        (local.set $lo_pat  (call $lower_pat (local.get $sub_pat) (local.get $scrut_h)))
        (local.set $triple  (call $make_record (i32.const 0) (i32.const 3)))
        (call $record_set (local.get $triple) (i32.const 0) (local.get $name))
        (call $record_set (local.get $triple) (i32.const 1)
          (i32.mul (i32.add (local.get $field_idx) (local.get $i)) (i32.const 4)))
        (call $record_set (local.get $triple) (i32.const 2) (local.get $lo_pat))
        (drop (call $list_set (local.get $buf) (local.get $i) (local.get $triple)))
        (local.set $i (i32.add (local.get $i) (i32.const 1)))
        (br $each)))
    (local.get $buf))

  (func $lower_pats (param $pats i32) (param $scrut_h i32) (result i32)
    (local $n i32) (local $i i32) (local $buf i32)
    (local $pat i32) (local $lo_pat i32)
    (local.set $n   (call $len (local.get $pats)))
    (local.set $buf (call $make_list (i32.const 0)))
    (local.set $buf (call $list_extend_to (local.get $buf) (local.get $n)))
    (local.set $i   (i32.const 0))
    (block $done
      (loop $each
        (br_if $done (i32.ge_u (local.get $i) (local.get $n)))
        (local.set $pat    (call $list_index (local.get $pats) (local.get $i)))
        (local.set $lo_pat (call $lower_pat (local.get $pat) (local.get $scrut_h)))
        (drop (call $list_set (local.get $buf) (local.get $i) (local.get $lo_pat)))
        (local.set $i (i32.add (local.get $i) (i32.const 1)))
        (br $each)))
    (local.get $buf))

  (func $lower_pat (param $pat i32) (param $scrut_h i32) (result i32)
    (local $tag i32) (local $lit i32) (local $lit_tag i32)
    (local $name i32) (local $subs i32)
    (local $binding i32) (local $kind i32) (local $ctor_tag_id i32)
    (if (i32.eq (local.get $pat) (i32.const 131))
      (then (return (call $lowpat_make_lpwild (local.get $scrut_h)))))
    (if (i32.lt_u (local.get $pat) (global.get $heap_base))
      (then (unreachable)))
    (local.set $tag (call $tag_of (local.get $pat)))
    (if (i32.eq (local.get $tag) (i32.const 130))
      (then
        (return (call $lowpat_make_lpvar
                  (local.get $scrut_h)
                  (i32.load offset=4 (local.get $pat))))))
    (if (i32.eq (local.get $tag) (i32.const 132))
      (then
        (local.set $lit     (i32.load offset=4 (local.get $pat)))
        (local.set $lit_tag (call $tag_of (local.get $lit)))
        (if (i32.eq (local.get $lit_tag) (i32.const 183))
          (then
            (return (call $lowpat_make_lpcon
                      (local.get $scrut_h)
                      (i32.load offset=4 (local.get $lit))
                      (call $make_list (i32.const 0))))))
        (return (call $lowpat_make_lplit (local.get $scrut_h) (local.get $lit)))))
    (if (i32.eq (local.get $tag) (i32.const 133))
      (then
        (local.set $name (i32.load offset=4 (local.get $pat)))
        (local.set $subs (i32.load offset=8 (local.get $pat)))
        (local.set $ctor_tag_id (i32.const -1))
        (local.set $binding (call $env_lookup (local.get $name)))
        (if (i32.ne (local.get $binding) (i32.const 0))
          (then
            (local.set $kind (call $env_binding_kind (local.get $binding)))
            (if (i32.eq (call $schemekind_tag (local.get $kind)) (i32.const 132))
              (then
                (local.set $ctor_tag_id
                  (call $schemekind_ctor_tag_id (local.get $kind)))))))
        (return (call $lowpat_make_lpcon
                  (local.get $scrut_h)
                  (local.get $ctor_tag_id)
                  (call $lower_pats (local.get $subs) (local.get $scrut_h))))))
    (if (i32.eq (local.get $tag) (i32.const 134))
      (then
        (return (call $lowpat_make_lptuple
                  (local.get $scrut_h)
                  (call $lower_pats
                    (i32.load offset=4 (local.get $pat))
                    (local.get $scrut_h))))))
    (if (i32.eq (local.get $tag) (i32.const 135))
      (then
        (return (call $lowpat_make_lplist
                  (local.get $scrut_h)
                  (call $lower_pats
                    (i32.load offset=4 (local.get $pat))
                    (local.get $scrut_h))
                  (i32.const 0)))))
    (if (i32.eq (local.get $tag) (i32.const 136))
      (then
        (return (call $lowpat_make_lprecord
                  (local.get $scrut_h)
                  (call $lower_pat_record_fields
                    (i32.load offset=4 (local.get $pat))
                    (i32.const 0)
                    (local.get $scrut_h))
                  (i32.const 0)))))
    (unreachable))

  (func $lower_match_arms (param $arms i32) (param $scrut_h i32) (result i32)
    (local $n i32) (local $i i32) (local $buf i32)
    (local $arm i32) (local $pat i32) (local $body_node i32)
    (local $cp i32) (local $lo_body i32) (local $lo_pat i32)
    (local $lparm i32)
    (local.set $n   (call $len (local.get $arms)))
    (local.set $buf (call $make_list (i32.const 0)))
    (local.set $buf (call $list_extend_to (local.get $buf) (local.get $n)))
    (local.set $i   (i32.const 0))
    (block $done
      (loop $each
        (br_if $done (i32.ge_u (local.get $i) (local.get $n)))
        (local.set $arm      (call $list_index (local.get $arms) (local.get $i)))
        (local.set $pat      (call $list_index (local.get $arm) (i32.const 0)))
        (local.set $body_node(call $list_index (local.get $arm) (i32.const 1)))
        (local.set $cp       (call $ls_push_scope))
        (call $bind_pat_locals (local.get $pat))
        (local.set $lo_body  (call $lower_expr (local.get $body_node)))
        (call $ls_pop_scope (local.get $cp))
        (local.set $lo_pat   (call $lower_pat (local.get $pat) (local.get $scrut_h)))
        (local.set $lparm    (call $lowpat_make_lparm (local.get $lo_pat) (local.get $lo_body)))
        (drop (call $list_set (local.get $buf) (local.get $i) (local.get $lparm)))
        (local.set $i (i32.add (local.get $i) (i32.const 1)))
        (br $each)))
    (local.get $buf))

  ;; ─── $lower_binop — BinOpExpr arm (parser tag 86) ──────────────────
  ;; Per src/lower.nx:341-342: BinOpExpr(op, left, right) =>
  ;;   LBinOp(handle, op, lower_expr(left), lower_expr(right)).
  ;; AST per parser_infra.wat:101-107:
  ;;   [tag=86][op][left_node][right_node] offsets 0/4/8/12.
  ;; The op is a BinOp i32 sentinel (BAdd=140..BConcat=153 per
  ;; parser_infra.wat:26 — same nullary-sentinel discipline as
  ;; ResumeDiscipline 250-252; $tag_of(op) returns 140-153 by heap-base
  ;; threshold). Lock-closure for Hβ.lower.binop-arm named follow-up
  ;; surfaced at chunk #9 landing — the wheel src/lower.nx places this
  ;; arm in lower_expr_body alongside UnaryOp; the seed honors the
  ;; pairing here at walk_compound (the §7.1 walkthrough's "walk_const
  ;; owns BinOp" was prose drift; wheel canonical pairs binop+unaryop
  ;; structurally as the two arithmetic-like compound arms).
  (func $lower_binop (export "lower_binop") (param $node i32) (result i32)
    (local $h i32) (local $body i32) (local $binop_struct i32)
    (local $op i32) (local $left_node i32) (local $right_node i32)
    (local $lo_l i32) (local $lo_r i32)
    (local.set $h            (call $walk_expr_node_handle (local.get $node)))
    (local.set $body         (i32.load offset=4 (local.get $node)))
    (local.set $binop_struct (i32.load offset=4 (local.get $body)))
    (local.set $op           (i32.load offset=4 (local.get $binop_struct)))
    (local.set $left_node    (i32.load offset=8 (local.get $binop_struct)))
    (local.set $right_node   (i32.load offset=12 (local.get $binop_struct)))
    (local.set $lo_l         (call $lower_expr (local.get $left_node)))
    (local.set $lo_r         (call $lower_expr (local.get $right_node)))
    (call $lexpr_make_lbinop
      (local.get $h)
      (local.get $op)
      (local.get $lo_l)
      (local.get $lo_r)))

  ;; ─── $lower_unary_op — UnaryOpExpr arm (parser tag 87) ──────────────
  ;; Per src/lower.nx:344-345: UnaryOpExpr(op, inner) =>
  ;;   LUnaryOp(handle, op, lower_expr(inner)).
  ;; AST per Lock #9: [tag=87][op][inner_node] offsets 0/4/8 — op is
  ;; UnaryOp ADT i32 sentinel (UNeg=160 / UNot=161) per src/types.nx
  ;; UnaryOp ADT in 160-179 region. Drift 8 refusal: integer-tag
  ;; sentinel, NOT string-keyed.
  (func $lower_unary_op (export "lower_unary_op") (param $node i32) (result i32)
    (local $h i32) (local $body i32) (local $unary_struct i32)
    (local $op i32) (local $inner_node i32) (local $lo_inner i32)
    (local.set $h            (call $walk_expr_node_handle (local.get $node)))
    (local.set $body         (i32.load offset=4 (local.get $node)))
    (local.set $unary_struct (i32.load offset=4 (local.get $body)))
    (local.set $op           (i32.load offset=4 (local.get $unary_struct)))
    (local.set $inner_node   (i32.load offset=8 (local.get $unary_struct)))
    (local.set $lo_inner     (call $lower_expr (local.get $inner_node)))
    (call $lexpr_make_lunaryop
      (local.get $h)
      (local.get $op)
      (local.get $lo_inner)))

  ;; ─── $lower_if — IfExpr arm (parser tag 90) ──────────────────────────
  ;; Per src/lower.nx:369-372 + Lock #10: each branch is single-element
  ;; list [lo_branch]. AST per parser_infra.wat:119-125:
  ;;   [tag=90][cond_node][then_node][else_node] offsets 0/4/8/12.
  (func $lower_if (export "lower_if") (param $node i32) (result i32)
    (local $h i32) (local $body i32) (local $if_struct i32)
    (local $cond_node i32) (local $then_node i32) (local $else_node i32)
    (local $lo_cond i32) (local $lo_then i32) (local $lo_else i32)
    (local $then_branch i32) (local $else_branch i32)
    (local.set $h          (call $walk_expr_node_handle (local.get $node)))
    (local.set $body       (i32.load offset=4 (local.get $node)))
    (local.set $if_struct  (i32.load offset=4 (local.get $body)))
    (local.set $cond_node  (i32.load offset=4  (local.get $if_struct)))
    (local.set $then_node  (i32.load offset=8  (local.get $if_struct)))
    (local.set $else_node  (i32.load offset=12 (local.get $if_struct)))
    (local.set $lo_cond    (call $lower_expr (local.get $cond_node)))
    (local.set $lo_then    (call $lower_expr (local.get $then_node)))
    (local.set $lo_else    (call $lower_expr (local.get $else_node)))
    ;; Lock #10: single-element branches. Buffer-counter (Ω.3).
    (local.set $then_branch (call $make_list (i32.const 0)))
    (local.set $then_branch (call $list_extend_to (local.get $then_branch) (i32.const 1)))
    (drop (call $list_set (local.get $then_branch) (i32.const 0) (local.get $lo_then)))
    (local.set $else_branch (call $make_list (i32.const 0)))
    (local.set $else_branch (call $list_extend_to (local.get $else_branch) (i32.const 1)))
    (drop (call $list_set (local.get $else_branch) (i32.const 0) (local.get $lo_else)))
    (call $lexpr_make_lif
      (local.get $h)
      (local.get $lo_cond)
      (local.get $then_branch)
      (local.get $else_branch)))

  ;; ─── $lower_block — BlockExpr arm (parser tag 91) ────────────────────
  ;; Per src/lower.nx:374-380 + Lock #2 (seed lowers final_expr only).
  ;; AST per parser_infra.wat:128-133:
  ;;   [tag=91][stmts_list][final_expr_node] offsets 0/4/8.
  (func $lower_block (export "lower_block") (param $node i32) (result i32)
    (local $h i32) (local $body i32) (local $block_struct i32)
    (local $stmt_nodes i32) (local $final_node i32)
    (local $cp i32) (local $lo_stmts i32) (local $lo_final i32)
    (local $stmts i32) (local $n i32) (local $i i32)
    (local.set $h            (call $walk_expr_node_handle (local.get $node)))
    (local.set $body         (i32.load offset=4 (local.get $node)))
    (local.set $block_struct (i32.load offset=4 (local.get $body)))
    (local.set $stmt_nodes   (i32.load offset=4 (local.get $block_struct)))
    (local.set $final_node   (i32.load offset=8 (local.get $block_struct)))
    (local.set $cp           (call $ls_push_scope))
    (local.set $lo_stmts     (call $lower_stmt_list (local.get $stmt_nodes)))
    (local.set $lo_final     (call $lower_expr (local.get $final_node)))
    (call $ls_pop_scope (local.get $cp))
    (local.set $n     (call $len (local.get $lo_stmts)))
    (local.set $stmts (call $make_list (i32.const 0)))
    (local.set $stmts (call $list_extend_to (local.get $stmts)
                        (i32.add (local.get $n) (i32.const 1))))
    (local.set $i (i32.const 0))
    (block $copy_done
      (loop $copy
        (br_if $copy_done (i32.ge_u (local.get $i) (local.get $n)))
        (drop (call $list_set (local.get $stmts) (local.get $i)
                (call $list_index (local.get $lo_stmts) (local.get $i))))
        (local.set $i (i32.add (local.get $i) (i32.const 1)))
        (br $copy)))
    (drop (call $list_set (local.get $stmts) (local.get $n) (local.get $lo_final)))
    (call $lexpr_make_lblock
      (local.get $h)
      (local.get $stmts)))

  ;; ─── $lower_match — MatchExpr arm (parser tag 92) ────────────────────
  ;; Per src/lower.nx:382-383 + Lock #3 (seed arms list empty pending
  ;; pattern substrate). AST per parser_infra.wat:136-141:
  ;;   [tag=92][scrut_node][arms_list] offsets 0/4/8.
  (func $lower_match (export "lower_match") (param $node i32) (result i32)
    (local $h i32) (local $body i32) (local $match_struct i32)
    (local $scrut_node i32) (local $arms_list i32)
    (local $scrut_h i32) (local $lo_scrut i32) (local $arms i32)
    (local.set $h            (call $walk_expr_node_handle (local.get $node)))
    (local.set $body         (i32.load offset=4 (local.get $node)))
    (local.set $match_struct (i32.load offset=4 (local.get $body)))
    (local.set $scrut_node   (i32.load offset=4 (local.get $match_struct)))
    (local.set $arms_list    (i32.load offset=8 (local.get $match_struct)))
    (local.set $scrut_h      (call $walk_expr_node_handle (local.get $scrut_node)))
    (local.set $lo_scrut     (call $lower_expr (local.get $scrut_node)))
    (local.set $arms         (call $lower_match_arms (local.get $arms_list) (local.get $scrut_h)))
    (call $lexpr_make_lmatch
      (local.get $h)
      (local.get $lo_scrut)
      (local.get $arms)))

  ;; ─── $lower_make_list — MakeListExpr arm (parser tag 96) ─────────────
  ;; Per src/lower.nx:385-386: MakeListExpr(elems) =>
  ;;   LMakeList(handle, lower_expr_list(elems)).
  ;; AST per parser_compound.wat:77-81: [tag=96][elems_list] offsets 0/4.
  (func $lower_make_list (export "lower_make_list") (param $node i32) (result i32)
    (local $h i32) (local $body i32) (local $list_struct i32)
    (local $elems i32) (local $lo_elems i32)
    (local.set $h           (call $walk_expr_node_handle (local.get $node)))
    (local.set $body        (i32.load offset=4 (local.get $node)))
    (local.set $list_struct (i32.load offset=4 (local.get $body)))
    (local.set $elems       (i32.load offset=4 (local.get $list_struct)))
    (local.set $lo_elems    (call $lower_expr_list_compound (local.get $elems)))
    (call $lexpr_make_lmakelist
      (local.get $h)
      (local.get $lo_elems)))

  ;; ─── $lower_make_tuple — MakeTupleExpr arm (parser tag 97) ───────────
  ;; Per src/lower.nx:388-389: MakeTupleExpr(elems) =>
  ;;   LMakeTuple(handle, lower_expr_list(elems)).
  ;; AST per parser_compound.wat:70-74: [tag=97][elems_list] offsets 0/4.
  (func $lower_make_tuple (export "lower_make_tuple") (param $node i32) (result i32)
    (local $h i32) (local $body i32) (local $tup_struct i32)
    (local $elems i32) (local $lo_elems i32)
    (local.set $h          (call $walk_expr_node_handle (local.get $node)))
    (local.set $body       (i32.load offset=4 (local.get $node)))
    (local.set $tup_struct (i32.load offset=4 (local.get $body)))
    (local.set $elems      (i32.load offset=4 (local.get $tup_struct)))
    (local.set $lo_elems   (call $lower_expr_list_compound (local.get $elems)))
    (call $lexpr_make_lmaketuple
      (local.get $h)
      (local.get $lo_elems)))

  ;; ─── $lower_make_record — MakeRecordExpr arm (parser tag 98) ─────────
  ;; Per src/lower.nx:391-392 + Lock #6: MakeRecordExpr(fields) =>
  ;;   LMakeRecord(handle, lower_record_field_values(fields)).
  ;; AST per Lock #9: [tag=98][fields_list] offsets 0/4. Each fields-list
  ;; element is pair-record (name=0, value=4) per Lock #6.
  (func $lower_make_record (export "lower_make_record") (param $node i32) (result i32)
    (local $h i32) (local $body i32) (local $rec_struct i32)
    (local $fields i32) (local $lo_fields i32)
    (local.set $h          (call $walk_expr_node_handle (local.get $node)))
    (local.set $body       (i32.load offset=4 (local.get $node)))
    (local.set $rec_struct (i32.load offset=4 (local.get $body)))
    (local.set $fields     (i32.load offset=4 (local.get $rec_struct)))
    (local.set $lo_fields  (call $lower_record_field_values (local.get $fields)))
    (call $lexpr_make_lmakerecord
      (local.get $h)
      (local.get $lo_fields)))

  ;; ─── $lower_named_record — NamedRecordExpr arm (parser tag 99) ───────
  ;; Per src/lower.nx:394-399 + Lock #5 (H2.3 collapse — type_name discarded
  ;; at lower-time; runtime sees raw fields). AST per Lock #9:
  ;;   [tag=99][type_name_str][fields_list] offsets 0/4/8.
  (func $lower_named_record (export "lower_named_record") (param $node i32) (result i32)
    (local $h i32) (local $body i32) (local $named_struct i32)
    (local $fields i32) (local $lo_fields i32)
    (local.set $h            (call $walk_expr_node_handle (local.get $node)))
    (local.set $body         (i32.load offset=4 (local.get $node)))
    (local.set $named_struct (i32.load offset=4 (local.get $body)))
    ;; type_name at offset 4 — Lock #5 H2.3 discards (drift-8 closure:
    ;; threaded-not-compared). fields_list at offset 8.
    (local.set $fields       (i32.load offset=8 (local.get $named_struct)))
    (local.set $lo_fields    (call $lower_record_field_values (local.get $fields)))
    (call $lexpr_make_lmakerecord
      (local.get $h)
      (local.get $lo_fields)))

  ;; ─── $lower_field — FieldExpr arm (parser tag 100) ───────────────────
  ;; Per src/lower.nx:450-461 + Lock #4 (offset sentinel 0 at seed pending
  ;; ty.wat record-fields walker). AST per Lock #9:
  ;;   [tag=100][rec_node][field_name_str] offsets 0/4/8.
  ;; field_name_str THREADED but NOT COMPARED (drift-8 closure).
  (func $lower_field (export "lower_field") (param $node i32) (result i32)
    (local $h i32) (local $body i32) (local $field_struct i32)
    (local $rec_node i32) (local $lo_rec i32)
    (local.set $h            (call $walk_expr_node_handle (local.get $node)))
    (local.set $body         (i32.load offset=4 (local.get $node)))
    (local.set $field_struct (i32.load offset=4 (local.get $body)))
    (local.set $rec_node     (i32.load offset=4 (local.get $field_struct)))
    (local.set $lo_rec       (call $lower_expr (local.get $rec_node)))
    ;; Lock #4: offset sentinel 0 — ty.wat structural record-fields walker
    ;; not yet exposed at lower layer; matches wheel src/lower.nx:543
    ;; non-record-type fallback semantics.
    (call $lexpr_make_lfieldload
      (local.get $h)
      (local.get $lo_rec)
      (i32.const 0)))

  ;; ─── $lower_lambda — LambdaExpr arm (parser tag 89) ──────────────────
  ;; Per src/lower.nx:401-428 + Lock #1+#11. Seed defaults: caps=empty,
  ;; evs=empty, fn=0. Body recursively lowered for graph-side effects;
  ;; result DROPPED per Lock #11 (LFn ADT not yet seed-substrate).
  ;; AST per Lock #9: [tag=89][params_list][body_node] offsets 0/4/8.
  (func $lower_lambda (export "lower_lambda") (param $node i32) (result i32)
    (local $h i32) (local $body i32) (local $lambda_struct i32)
    (local $params i32) (local $body_node i32)
    (local $param_names i32) (local $param_handles i32)
    (local $cp i32) (local $lo_body i32) (local $body_list i32)
    (local $fn_ir i32) (local $caps i32) (local $evs i32)
    (local.set $h             (call $walk_expr_node_handle (local.get $node)))
    (local.set $body          (i32.load offset=4 (local.get $node)))
    (local.set $lambda_struct (i32.load offset=4 (local.get $body)))
    (local.set $params        (i32.load offset=4 (local.get $lambda_struct)))
    (local.set $body_node     (i32.load offset=8 (local.get $lambda_struct)))
    (local.set $param_names   (call $lower_param_names (local.get $params)))
    (local.set $param_handles (call $lower_param_handles (local.get $params)))
    (local.set $cp            (call $ls_push_scope))
    (call $bind_names_as_locals (local.get $param_names) (local.get $param_handles))
    (local.set $lo_body       (call $lower_expr (local.get $body_node)))
    (call $ls_pop_scope (local.get $cp))
    (local.set $body_list (call $make_list (i32.const 0)))
    (local.set $body_list (call $list_extend_to (local.get $body_list) (i32.const 1)))
    (drop (call $list_set (local.get $body_list) (i32.const 0) (local.get $lo_body)))
    (local.set $fn_ir (call $lowfn_make
                        (call $int_to_str (local.get $h))
                        (call $len (local.get $params))
                        (local.get $param_names)
                        (local.get $body_list)
                        (call $row_make_pure)))
    (local.set $caps (call $make_list (i32.const 0)))
    (local.set $evs  (call $make_list (i32.const 0)))
    (call $lexpr_make_lmakeclosure
      (local.get $h)
      (local.get $fn_ir)
      (local.get $caps)
      (local.get $evs)))
