  ;; ═══ walk_handle.wat — Hβ.lower HandleExpr/PipeExpr arms (Tier 7) ═══
  ;; Hβ.lower cascade chunk #8 of 11 per Hβ-lower-substrate.md §12.3 dep order.
  ;;
  ;; What this chunk IS (per Hβ-lower-substrate.md §4.2 lines 495-518 +
  ;;                     spec 10 + src/lower.nx:430-517):
  ;;   The seed's verb-projection layer. The kernel's primitive #3 (five
  ;;   verbs) made physical at the lowering layer.
  ;;
  ;;   HandleExpr (parser tag 93) — surface `handle body with arms`:
  ;;     → LBlock(handle, arm_decls ++ [LHandle(handle, body, arm_records)])
  ;;     Per src/lower.nx:430-440 wheel canonical (Lock #1).
  ;;     LHandle is tag 332 — the inline `handle ... with arms` form;
  ;;     LHandleWith (tag 329) is reserved for the `body ~> handler` PIPE.
  ;;
  ;;   PipeExpr (parser tag 101) — 5-PipeKind dispatch (parser_infra.wat:27-28):
  ;;     PForward  (160) → LCall      (tag 308)  — `left |> right` desugar
  ;;     PDiverge  (161) → LMakeTuple (tag 317)  — `<|` per Lock #3
  ;;     PCompose  (162) → LMakeTuple (tag 317)  — `><` independent pair
  ;;     PTeeBlock (163) → LHandleWith (tag 329) — `~>` block (Lock #2)
  ;;     PTeeInline(164) → LHandleWith (tag 329) — `~>` inline (Lock #2)
  ;;     PFeedback (165) → LFeedback  (tag 330)  — `<~` per LF substrate
  ;;
  ;; Implements: Hβ-lower-substrate.md §4.2 + §6.2 + §11 + §12.3 #8;
  ;;             src/lower.nx:430-440 HandleExpr arm (Lock #1);
  ;;             src/lower.nx:463-504 PipeExpr arm (Lock #2 PTee collapse);
  ;;             src/lower.nx:506-517 lower_diverge_branches (Lock #3).
  ;; Exports:    $lower_handle,
  ;;             $lower_pipe,
  ;;             $lower_pipe_forward,
  ;;             $lower_pipe_diverge,
  ;;             $lower_pipe_compose,
  ;;             $lower_pipe_handle,
  ;;             $lower_pipe_feedback,
  ;;             $lower_handler_arms_as_decls
  ;; Uses:       $walk_expr_node_handle (infer/walk_expr.wat:306-307),
  ;;             $lexpr_make_lblock / lhandle / lhandlewith / lmaketuple /
  ;;               lfeedback / lcall / lmakevariant (lower/lexpr.wat),
  ;;             $lexpr_lmaketuple_elems (Lock #3 LMakeTuple introspection),
  ;;             $lower_expr (lower/walk_call.wat — retrofitted at this commit
  ;;               to add tag-93 + tag-101 arms),
  ;;             $tag_of (runtime/record.wat),
  ;;             $make_list / $list_index / $list_set / $list_extend_to /
  ;;               $len (runtime/list.wat — buffer-counter Ω.3),
  ;;             $make_record / $record_get / $record_set (runtime/record.wat)
  ;; Test:       bootstrap/test/lower/walk_handle_simple.wat,
  ;;             bootstrap/test/lower/walk_pipe_forward.wat,
  ;;             bootstrap/test/lower/walk_pipe_compose.wat,
  ;;             bootstrap/test/lower/walk_pipe_feedback.wat
  ;;
  ;; ═══ LOCKS (wheel-canonical override walkthrough §4.2 prose) ═════════
  ;;
  ;; Lock #1: HandleExpr (tag 93) → LBlock(arm_decls ++ [LHandle(...)])
  ;;          per src/lower.nx:430-440. NOT LHandleWith. Tag 332 (LHandle)
  ;;          is the inline `handle body with arms` form; tag 329
  ;;          (LHandleWith) is the `body ~> handler` PIPE projection.
  ;;          Two distinct surface forms; two distinct LowExpr shapes.
  ;;
  ;; Lock #2: PTeeBlock (163) + PTeeInline (164) collapse identically to
  ;;          LHandleWith per src/lower.nx:494-497. $lower_pipe dispatches
  ;;          both through one combined $lower_pipe_handle arm.
  ;;
  ;; Lock #3: PDiverge requires lowered right to be LMakeTuple (tag 317).
  ;;          $tag_of(lo_r) == 317 → introspect via $lexpr_lmaketuple_elems
  ;;          + apply each branch to lo_l. Else fall back to
  ;;          [LCall(0, lo_r, [lo_l])] per src/lower.nx:509.
  ;;
  ;; Lock #4: $classify_handler (chunk #5) NOT INVOKED at $lower_handle
  ;;          per src/lower.nx:430-440 wheel canonical — classification
  ;;          deferred to emit-time. Walkthrough §4.2 prose aspirational;
  ;;          wheel says emit handles it. Named follow-up
  ;;          Hβ.lower.classify-at-handle-site.
  ;;
  ;; Lock #5: LFeedback emits straight LFeedback (no state-slot allocation
  ;;          at lower-time) per src/lower.nx:501-502 + LF §1.12.
  ;;          State-slot allocation is EMIT-TIME concern.
  ;;
  ;; Lock #6: LMakeContinuation NOT constructed in HandleExpr/PipeExpr
  ;;          arms in the wheel. Construction lives in $lower_perform's
  ;;          MultiShot branch (chunk #7 deferred via
  ;;          Hβ.lower.perform-multishot-dispatch). This chunk is
  ;;          LMakeContinuation-silent.
  ;;
  ;; Lock #7: $lower_handler_arms_as_decls earns the abstraction this
  ;;          commit (third caller per Anchor 7 — chunks #5 + #7 cited
  ;;          it; chunk #8 invokes it). With LowFn now substrate-live
  ;;          (tag 350), handler arms lower as real
  ;;          LDeclareFn(LowFn("op_" + op_name, ...)) entries per
  ;;          src/lower.nx:745-755. arm_records list (the {args, body,
  ;;          op_name} form) remains the paired metadata list for LHandle.
  ;;
  ;; Lock #8: arm-record shape {args, body, op_name} per src/lower.nx:742.
  ;;          Sorted-by-name discipline (Ω.5) → record offsets:
  ;;            offset 0 → args (list of name strings)
  ;;            offset 4 → body (LowExpr ptr)
  ;;            offset 8 → op_name (string ptr)
  ;;          Wheel field-order canonical (alphabetical).
  ;;
  ;; Lock #9: HandleExpr AST layout assumption: [tag=93][body_node][arms]
  ;;          per src/parser.nx pattern. $mk_HandleExpr does NOT exist in
  ;;          parser_infra.wat. Drift-9-safe: layout-match is harness
  ;;          verification responsibility. Named follow-up
  ;;          Hβ.lower.handle-pipe-harness-builders.
  ;;
  ;; Lock #10: $lower_expr retrofit lands as two-file commit per chunk #4
  ;;           emit_diag.wat precedent. walk_call.wat:293-318 dispatcher
  ;;           gets tag-93 + tag-101 arms inside this same commit per
  ;;           Hβ.lower.lower-expr-dispatch-extension follow-up.
  ;;
  ;; ═══ EIGHT INTERROGATIONS (per Hβ-lower-substrate.md §5.3) ══════════
  ;;
  ;; 1. Graph?       Each arm reads $walk_expr_node_handle(node) (offset 12).
  ;;                 Read-only on graph. Effect row at the wheel: GraphRead
  ;;                 + LookupTy + Diagnostic — NO GraphWrite (spec 05
  ;;                 invariant 1).
  ;;
  ;; 2. Handler?     Wheel: 4-effect chain @resume=OneShot. Seed: 8 direct
  ;;                 functions. $classify_handler NOT INVOKED per Lock #4.
  ;;
  ;; 3. Verb?        LOAD-BEARING. All 5 verbs project here:
  ;;                   |>  (160) → LCall      (308)
  ;;                   <|  (161) → LMakeTuple (317) of LCalls per Lock #3
  ;;                   ><  (162) → LMakeTuple (317) pair
  ;;                   ~>  (163, 164) → LHandleWith (329) per Lock #2
  ;;                   <~  (165) → LFeedback (330) per Lock #5
  ;;                 The kernel's primitive #3 made physical at the
  ;;                 lowering layer.
  ;;
  ;; 4. Row?         Silent. Monomorphism fired at walk_call. Sub-expressions
  ;;                 preserve row via $lower_expr recursion.
  ;;
  ;; 5. Ownership?   LowExpr records `own` of bump. Arm-decls list `own`
  ;;                 (empty per Lock #7 conservative). arm-records list
  ;;                 `own` (one record per arm). Sub-LowExprs `ref`.
  ;;
  ;; 6. Refinement?  Transparent.
  ;;
  ;; 7. Gradient?    LDeclareFn-per-arm IS the gradient substrate made
  ;;                 physical here. Each arm body becomes a named LowFn
  ;;                 `op_<name>` declaration, which is exactly the shape
  ;;                 emit reads to cash the OneShot direct-call path.
  ;;
  ;; 8. Reason?      Read-only. GNode at carried handle preserves Reason
  ;;                 chain. Emit walks back when surfacing handler-
  ;;                 uninstallable / pipe-arity diagnostics.
  ;;
  ;; ═══ FORBIDDEN PATTERNS AUDIT ═════════════════════════════════════
  ;;
  ;; - Drift 1 (Rust vtable):        CRITICAL. PipeKind dispatch is 5-arm
  ;;                                  (if (i32.eq kind N) ...) chain — direct
  ;;                                  sentinel comparison; no table indirection.
  ;;                                  Handler arm dispatch via LDeclareFn list
  ;;                                  + emit-time direct call / call_indirect
  ;;                                  split at H1.4. NO
  ;;                                  $op_table / $pipe_kind_table data segment.
  ;;                                  NO _lookup_pipe_kind_for_tag function.
  ;;                                  Word "vtable" appears NOWHERE except in
  ;;                                  this audit.
  ;;
  ;; - Drift 4 (monad transformer):   No LowerM. Each $lower_pipe_<v> is
  ;;                                  (param i32) (result i32). Direct.
  ;;
  ;; - Drift 5 (C calling convention): LMakeContinuation NOT constructed
  ;;                                  here per Lock #6 — discipline N/A
  ;;                                  this chunk. $lower_handle / $lower_pipe_*
  ;;                                  take ONE i32, return ONE i32.
  ;;
  ;; - Drift 6 (primitive-special-case): PipeKind 160-165 nullary sentinels.
  ;;                                  NO "PForward is special because common-
  ;;                                  case" carveout.
  ;;
  ;; - Drift 7 (parallel-arrays):     Arm-decls is ONE list. NOT parallel
  ;;                                  _names_ptr + _bodies_ptr. arm-record
  ;;                                  is ONE record per Ω.5; fields {args,
  ;;                                  body, op_name} alphabetical at 0/4/8.
  ;;
  ;; - Drift 8 (string-keyed):        Tag-int dispatch only. PipeKind i32
  ;;                                  sentinels 160-165, NOT
  ;;                                  if str_eq(pipe_kind_name, "PForward").
  ;;
  ;; - Drift 9 (deferred-by-omission): All 8 exports land FULLY BODIED.
  ;;                                  $lower_handler_arms_as_decls returns a
  ;;                                  fully populated LDeclareFn list per
  ;;                                  Lock #7; no inert placeholder path.
  ;;
  ;; - Foreign fluency JS async/await: NEVER "promise" / "async" / "future"
  ;;                                  / "await". Vocabulary: LHandleWith /
  ;;                                  LFeedback / "verb projection" per spec 10.
  ;;
  ;; - Foreign fluency Scheme call/cc: Continuations DELIMITED. NEVER
  ;;                                  "undelimited" / "call/cc" / "captured stack."
  ;;
  ;; - Foreign fluency LLVM/GHC IR:   NEVER "SSA" / "phi" / "calling
  ;;                                  convention enum". Vocabulary stays Inka.
  ;;
  ;; ═══ Named follow-ups (Drift 9 closure) ═══════════════════════════
  ;;
  ;;   - Hβ.lower.classify-at-handle-site:
  ;;             chunk #5 $classify_handler gets first caller when emit
  ;;             grows resume-discipline-aware arm dispatch.
  ;;
  ;;   - Hβ.lower.handle-pipe-harness-builders:
  ;;             $mk_HandleExpr + $mk_PipeExpr in parser_infra.wat enable
  ;;             structured harness construction.
  ;;
  ;;   - Hβ.lower.feedback-state-slot-allocation:
  ;;             Per LF §1.12 — when emit grows lower-time state-slot
  ;;             pre-allocation (currently emit-time per Lock #5).
  ;;
  ;;   - Hβ.lower.diverge-irregular-fallback-harness:
  ;;             Trace-harness for `<|` non-LMakeTuple right (single branch).
  ;;
  ;;   - Hβ.lower.lower-handler-arms-as-decls-promotion:
  ;;             Fourth caller emerges (post chunks #9-#11) → promote to
  ;;             peer file walk_arms.wat per Anchor 7.
  ;;
  ;;   - Hβ.lower.lower-expr-dispatch-extension:
  ;;             (extending from chunk #7) chunks #9-#10 add their tag arms
  ;;             to walk_call.wat:293-318 dispatcher.
  ;;
  ;;   - Hβ.lower.handle-expr-arm-row-passthrough:
  ;;             Wheel src/lower.nx:760 hardcodes EfPure on LFn for handler
  ;;             arms; row-on-arm propagation lands when wheel grows.

  ;; Static data — lower-private string literals within the pre-heap
  ;; region. 504-510 is free between emit/lookup.wat's 496 "op_" peer
  ;; and lexer_data.wat's 512 " tokens, " string; we duplicate the
  ;; literal locally so lowering stays self-contained and does not
  ;; depend on emit-private offsets.
  (data (i32.const 504) "\03\00\00\00op_")

  ;; ─── $bind_handler_arg_names — bind each arm arg with sentinel 0 ───
  ;; Per src/lower.nx:758-766. Handler-arm args do not currently thread
  ;; per-param type handles into lower-time scope; the op signature
  ;; carries them inferentially, so 0 stands as the seed's sentinel.
  (func $bind_handler_arg_names (param $names i32)
    (local $n i32) (local $i i32)
    (call $lower_init)
    (local.set $n (call $len (local.get $names)))
    (local.set $i (i32.const 0))
    (block $done
      (loop $each
        (br_if $done (i32.ge_u (local.get $i) (local.get $n)))
        (drop (call $ls_bind_local
                (call $list_index (local.get $names) (local.get $i))
                (i32.const 0)))
        (local.set $i (i32.add (local.get $i) (i32.const 1)))
        (br $each))))

  ;; ─── $lower_handler_arm_body — scoped lowering shared by both paths ──
  ;; ─── $extract_handler_arg_names — map pat list to string list ──────
  (func $extract_handler_arg_names (param $pats i32) (result i32)
    (local $n i32) (local $i i32) (local $buf i32)
    (local $pat i32) (local $tag i32) (local $name i32)
    (local.set $n   (call $len (local.get $pats)))
    (local.set $buf (call $make_list (i32.const 0)))
    (local.set $buf (call $list_extend_to (local.get $buf) (local.get $n)))
    (local.set $i   (i32.const 0))
    (block $done
      (loop $each
        (br_if $done (i32.ge_u (local.get $i) (local.get $n)))
        (local.set $pat (call $list_index (local.get $pats) (local.get $i)))
        (local.set $name (call $str_alloc (i32.const 1)))
        (i32.store8 offset=4 (local.get $name) (i32.const 95)) ;; '_' default
        (if (i32.ne (local.get $pat) (i32.const 131))
          (then
            (local.set $tag (call $tag_of (local.get $pat)))
            (if (i32.eq (local.get $tag) (i32.const 130)) ;; PVar
              (then
                (local.set $name (i32.load offset=4 (local.get $pat)))))))
        (drop (call $list_set (local.get $buf) (local.get $i) (local.get $name)))
        (local.set $i (i32.add (local.get $i) (i32.const 1)))
        (br $each)))
    (local.get $buf))

  ;; Handler-arm args bind into the arm body's scope and MUST be popped
  ;; after lowering so names do not leak into sibling arms.
  (func $lower_handler_arm_body (param $args i32) (param $body_node i32) (result i32)
    (local $cp i32) (local $lo_body i32)
    (local.set $cp (call $ls_push_scope))
    (call $bind_handler_arg_names (local.get $args))
    (local.set $lo_body (call $lower_expr (local.get $body_node)))
    (call $ls_pop_scope (local.get $cp))
    (local.get $lo_body))

  ;; ─── $lower_handler_arms_as_decls — Lock #7 real LDeclareFn list ───
  ;; Per src/lower.nx:745-755. Each arm becomes
  ;; LDeclareFn(LowFn("op_" + op_name, len(args), args, [lo_body], Pure)).
  (func $lower_handler_arms_as_decls (export "lower_handler_arms_as_decls")
        (param $arms i32) (result i32)
    (local $n i32) (local $i i32) (local $buf i32)
    (local $arm i32) (local $args i32) (local $arg_names i32) (local $body_node i32)
    (local $op_name i32) (local $lo_body i32) (local $fn_name i32)
    (local $fn_body i32) (local $fn_ir i32)
    (local.set $n   (call $len (local.get $arms)))
    (local.set $buf (call $make_list (i32.const 0)))
    (local.set $buf (call $list_extend_to (local.get $buf) (local.get $n)))
    (local.set $i   (i32.const 0))
    (block $done
      (loop $each
        (br_if $done (i32.ge_u (local.get $i) (local.get $n)))
        (local.set $arm       (call $list_index (local.get $arms) (local.get $i)))
        (local.set $args      (call $record_get (local.get $arm) (i32.const 0)))
        (local.set $arg_names (call $extract_handler_arg_names (local.get $args)))
        (local.set $body_node (call $record_get (local.get $arm) (i32.const 1)))
        (local.set $op_name   (call $record_get (local.get $arm) (i32.const 2)))
        (local.set $lo_body   (call $lower_handler_arm_body
                                (local.get $arg_names)
                                (local.get $body_node)))
        (local.set $fn_name   (call $str_concat (i32.const 504) (local.get $op_name)))
        (local.set $fn_body   (call $make_list (i32.const 0)))
        (local.set $fn_body   (call $list_extend_to (local.get $fn_body) (i32.const 1)))
        (drop (call $list_set (local.get $fn_body) (i32.const 0) (local.get $lo_body)))
        (local.set $fn_ir (call $lowfn_make
                            (local.get $fn_name)
                            (call $len (local.get $arg_names))
                            (local.get $arg_names)
                            (local.get $fn_body)
                            (call $row_make_pure)))
        (drop (call $list_set (local.get $buf) (local.get $i)
                (call $lexpr_make_ldeclarefn (local.get $fn_ir))))
        (local.set $i (i32.add (local.get $i) (i32.const 1)))
        (br $each)))
    (local.get $buf))

  ;; ─── $lower_handler_arms_records — chunk-private arm-record list ──
  ;; Per src/lower.nx:732-744 wheel canonical. Returns list of
  ;; {args, body, op_name} records (Lock #8) — alphabetical offsets 0/4/8.
  ;; The body is lowered under the same scoped arg-bind discipline as
  ;; the decl path so sibling arms stay lexically isolated.
  ;; Buffer-counter (Ω.3) — same discipline as walk_call's $lower_args.
  (func $lower_handler_arms_records (param $arms i32) (result i32)
    (local $n i32) (local $i i32) (local $buf i32)
    (local $arm i32) (local $args i32) (local $body_node i32)
    (local $op_name i32) (local $lo_body i32) (local $arm_rec i32)
    (local.set $n   (call $len (local.get $arms)))
    (local.set $buf (call $make_list (i32.const 0)))
    (local.set $buf (call $list_extend_to (local.get $buf) (local.get $n)))
    (local.set $i   (i32.const 0))
    (block $done
      (loop $each
        (br_if $done (i32.ge_u (local.get $i) (local.get $n)))
        (local.set $arm       (call $list_index (local.get $arms) (local.get $i)))
        (local.set $args      (call $record_get (local.get $arm) (i32.const 0)))
        (local.set $body_node (call $record_get (local.get $arm) (i32.const 1)))
        (local.set $op_name   (call $record_get (local.get $arm) (i32.const 2)))
        (local.set $lo_body   (call $lower_handler_arm_body
                                (local.get $args)
                                (local.get $body_node)))
        ;; arm_rec = {args, body: lo_body, op_name} per Lock #8 alphabetical.
        ;; Tag 0 — chunk-private record (no $tag_of dispatch on arm-records;
        ;; only structural field access).
        (local.set $arm_rec (call $make_record (i32.const 0) (i32.const 3)))
        (call $record_set (local.get $arm_rec) (i32.const 0) (local.get $args))
        (call $record_set (local.get $arm_rec) (i32.const 1) (local.get $lo_body))
        (call $record_set (local.get $arm_rec) (i32.const 2) (local.get $op_name))
        (drop (call $list_set (local.get $buf) (local.get $i) (local.get $arm_rec)))
        (local.set $i (i32.add (local.get $i) (i32.const 1)))
        (br $each)))
    (local.get $buf))

  ;; ─── $lower_handle — HandleExpr arm (parser tag 93) ───────────────
  ;; Per src/lower.nx:430-440 + Lock #1.
  ;; AST: $node N-wrapper → offset 4 NExpr → offset 4 HandleExpr
  ;;      [tag=93][body_node][arms]
  ;; Output: LBlock(h, arm_decls ++ [LHandle(h, body, arm_records)]).
  (func $lower_handle (export "lower_handle") (param $node i32) (result i32)
    (local $h i32) (local $body i32) (local $handle_struct i32)
    (local $body_node i32) (local $arms i32)
    (local $arm_decls i32) (local $arm_records i32)
    (local $lo_body i32) (local $lhandle i32)
    (local $stmts i32) (local $i i32) (local $n i32)
    (local.set $h            (call $walk_expr_node_handle (local.get $node)))
    (local.set $body         (i32.load offset=4 (local.get $node)))
    (local.set $handle_struct(i32.load offset=4 (local.get $body)))
    (local.set $body_node    (i32.load offset=4 (local.get $handle_struct)))
    (local.set $arms         (i32.load offset=8 (local.get $handle_struct)))
    (local.set $arm_decls    (call $lower_handler_arms_as_decls (local.get $arms)))
    (local.set $arm_records  (call $lower_handler_arms_records  (local.get $arms)))
    (local.set $lo_body      (call $lower_expr (local.get $body_node)))
    (local.set $lhandle      (call $lexpr_make_lhandle
                               (local.get $h)
                               (local.get $lo_body)
                               (local.get $arm_records)))
    ;; Build LBlock stmts = arm_decls ++ [lhandle]. Buffer-counter (Ω.3).
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
    (drop (call $list_set (local.get $stmts) (local.get $n) (local.get $lhandle)))
    (call $lexpr_make_lblock (local.get $h) (local.get $stmts)))

  ;; ─── $lower_pipe — PipeExpr arm (parser tag 101) — 5-verb dispatch ──
  ;; Per src/lower.nx:470-504 + spec 10. Five PipeKinds, one arm each.
  ;; Lock #2: PTeeBlock + PTeeInline collapse to one arm.
  ;;
  ;; AST: $node N-wrapper → offset 4 NExpr → offset 4 PipeExpr
  ;;      [tag=101][kind][left][right] per parser_infra.wat $mk_PipeExpr.
  (func $lower_pipe (export "lower_pipe") (param $node i32) (result i32)
    (local $h i32) (local $body i32) (local $pipe_struct i32)
    (local $kind i32) (local $left_node i32) (local $right_node i32)
    (local $lo_l i32) (local $lo_r i32)
    (local.set $h           (call $walk_expr_node_handle (local.get $node)))
    (local.set $body        (i32.load offset=4 (local.get $node)))
    (local.set $pipe_struct (i32.load offset=4 (local.get $body)))
    (local.set $kind        (i32.load offset=4 (local.get $pipe_struct)))
    (local.set $left_node   (i32.load offset=8 (local.get $pipe_struct)))
    (local.set $right_node  (i32.load offset=12 (local.get $pipe_struct)))
    (local.set $lo_l        (call $lower_expr (local.get $left_node)))
    (local.set $lo_r        (call $lower_expr (local.get $right_node)))
    ;; PForward (160) — `left |> right` → LCall(h, right, [left]).
    (if (i32.eq (local.get $kind) (i32.const 160))
      (then (return (call $lower_pipe_forward
                      (local.get $h) (local.get $lo_l) (local.get $lo_r)))))
    ;; PDiverge (161) — `<|` per Lock #3.
    (if (i32.eq (local.get $kind) (i32.const 161))
      (then (return (call $lower_pipe_diverge
                      (local.get $h) (local.get $lo_l) (local.get $lo_r)))))
    ;; PCompose (162) — `><` independent pair.
    (if (i32.eq (local.get $kind) (i32.const 162))
      (then (return (call $lower_pipe_compose
                      (local.get $h) (local.get $lo_l) (local.get $lo_r)))))
    ;; PTeeBlock (163) + PTeeInline (164) — Lock #2 collapse.
    (if (i32.eq (local.get $kind) (i32.const 163))
      (then (return (call $lower_pipe_handle
                      (local.get $h) (local.get $lo_l) (local.get $lo_r)))))
    (if (i32.eq (local.get $kind) (i32.const 164))
      (then (return (call $lower_pipe_handle
                      (local.get $h) (local.get $lo_l) (local.get $lo_r)))))
    ;; PFeedback (165) — `<~` per Lock #5.
    (if (i32.eq (local.get $kind) (i32.const 165))
      (then (return (call $lower_pipe_feedback
                      (local.get $h) (local.get $lo_l) (local.get $lo_r)))))
    ;; Unknown PipeKind — compiler-internal bug.
    (unreachable))

  ;; ─── $lower_pipe_forward — `|>` arm ───────────────────────────────
  ;; Per src/lower.nx:476: PForward => LCall(handle, lo_r, [lo_l]).
  (func $lower_pipe_forward (export "lower_pipe_forward")
        (param $h i32) (param $lo_l i32) (param $lo_r i32) (result i32)
    (local $args i32)
    (local.set $args (call $make_list (i32.const 0)))
    (local.set $args (call $list_extend_to (local.get $args) (i32.const 1)))
    (drop (call $list_set (local.get $args) (i32.const 0) (local.get $lo_l)))
    (call $lexpr_make_lcall (local.get $h) (local.get $lo_r) (local.get $args)))

  ;; ─── $lower_pipe_diverge — `<|` arm per Lock #3 ───────────────────
  ;; Per src/lower.nx:480-481 + 506-517. Right MUST be LMakeTuple (tag 317);
  ;; introspect via $lexpr_lmaketuple_elems + apply each branch to lo_l.
  (func $lower_pipe_diverge (export "lower_pipe_diverge")
        (param $h i32) (param $lo_l i32) (param $lo_r i32) (result i32)
    (local $tag i32) (local $branches i32) (local $applied i32)
    (local $fallback i32) (local $args i32) (local $single_call i32)
    (local.set $tag (call $tag_of (local.get $lo_r)))
    (if (i32.eq (local.get $tag) (i32.const 317))
      (then
        (local.set $branches (call $lexpr_lmaketuple_elems (local.get $lo_r)))
        (local.set $applied  (call $lower_diverge_apply (local.get $lo_l)
                                                          (local.get $branches)))
        (return (call $lexpr_make_lmaketuple (local.get $h) (local.get $applied)))))
    ;; Irregular fallback — single-branch shape per src/lower.nx:509.
    (local.set $args (call $make_list (i32.const 0)))
    (local.set $args (call $list_extend_to (local.get $args) (i32.const 1)))
    (drop (call $list_set (local.get $args) (i32.const 0) (local.get $lo_l)))
    (local.set $single_call (call $lexpr_make_lcall
                              (i32.const 0) (local.get $lo_r) (local.get $args)))
    (local.set $fallback (call $make_list (i32.const 0)))
    (local.set $fallback (call $list_extend_to (local.get $fallback) (i32.const 1)))
    (drop (call $list_set (local.get $fallback) (i32.const 0) (local.get $single_call)))
    (call $lexpr_make_lmaketuple (local.get $h) (local.get $fallback)))

  ;; ─── $lower_diverge_apply — chunk-private branch applicator ───────
  ;; Per src/lower.nx:512-517. Buffer-counter (Ω.3).
  (func $lower_diverge_apply (param $lo_input i32) (param $branches i32) (result i32)
    (local $n i32) (local $i i32) (local $buf i32)
    (local $branch i32) (local $args i32) (local $call i32)
    (local.set $n   (call $len (local.get $branches)))
    (local.set $buf (call $make_list (i32.const 0)))
    (local.set $buf (call $list_extend_to (local.get $buf) (local.get $n)))
    (local.set $i   (i32.const 0))
    (block $done
      (loop $each
        (br_if $done (i32.ge_u (local.get $i) (local.get $n)))
        (local.set $branch (call $list_index (local.get $branches) (local.get $i)))
        (local.set $args   (call $make_list (i32.const 0)))
        (local.set $args   (call $list_extend_to (local.get $args) (i32.const 1)))
        (drop (call $list_set (local.get $args) (i32.const 0) (local.get $lo_input)))
        (local.set $call (call $lexpr_make_lcall
                           (i32.const 0)
                           (local.get $branch)
                           (local.get $args)))
        (drop (call $list_set (local.get $buf) (local.get $i) (local.get $call)))
        (local.set $i (i32.add (local.get $i) (i32.const 1)))
        (br $each)))
    (local.get $buf))

  ;; ─── $lower_pipe_compose — `><` arm ───────────────────────────────
  ;; Per src/lower.nx:484-485: PCompose => LMakeTuple(handle, [lo_l, lo_r]).
  (func $lower_pipe_compose (export "lower_pipe_compose")
        (param $h i32) (param $lo_l i32) (param $lo_r i32) (result i32)
    (local $pair i32)
    (local.set $pair (call $make_list (i32.const 0)))
    (local.set $pair (call $list_extend_to (local.get $pair) (i32.const 2)))
    (drop (call $list_set (local.get $pair) (i32.const 0) (local.get $lo_l)))
    (drop (call $list_set (local.get $pair) (i32.const 1) (local.get $lo_r)))
    (call $lexpr_make_lmaketuple (local.get $h) (local.get $pair)))

  ;; ─── $lower_pipe_handle — `~>` arm per Lock #2 ────────────────────
  ;; Per src/lower.nx:494-497: PTeeBlock + PTeeInline collapse identically.
  ;; LHandleWith(handle, body, handler) — tag 329.
  (func $lower_pipe_handle (export "lower_pipe_handle")
        (param $h i32) (param $lo_l i32) (param $lo_r i32) (result i32)
    (call $lexpr_make_lhandlewith
      (local.get $h)
      (local.get $lo_l)
      (local.get $lo_r)))

  ;; ─── $lower_pipe_feedback — `<~` arm per Lock #5 ──────────────────
  ;; Per src/lower.nx:501-502: PFeedback => LFeedback(handle, lo_l, lo_r).
  ;; State-slot allocation deferred to emit-time per LF substrate.
  (func $lower_pipe_feedback (export "lower_pipe_feedback")
        (param $h i32) (param $lo_l i32) (param $lo_r i32) (result i32)
    (call $lexpr_make_lfeedback
      (local.get $h)
      (local.get $lo_l)
      (local.get $lo_r)))
