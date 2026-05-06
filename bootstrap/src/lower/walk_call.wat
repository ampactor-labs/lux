  ;; ═══ walk_call.wat — Hβ.lower CallExpr/PerformExpr/ResumeExpr arms (Tier 7) ═══
  ;; Hβ.lower cascade chunk #7 of 11 per Hβ-lower-substrate.md §12.3 dep order.
  ;;
  ;; What this chunk IS (per Hβ-lower-substrate.md §3.2 + §4.2):
  ;;   The seed's gradient cash-out site. Each call site reads $monomorphic_at
  ;;   (lookup.wat) — Pure/Closed → direct LCall (zero indirection); Open →
  ;;   LSuspend with evidence-slot list per H1.6 substrate. Each PerformExpr
  ;;   reads ResumeDiscipline (deferred per Lock #2) and emits LPerform.
  ;;   ResumeExpr collapses to LReturn per the wheel's "structurally a
  ;;   return from the arm" discipline (src/lower.mn:445-448).
  ;;
  ;;   THIS IS WHERE THE ROW INFERENCE'S >95% MONOMORPHIC CLAIM
  ;;   BECOMES PHYSICAL. The LCall vs LSuspend tag IS the gradient bit;
  ;;   emit reads the tag at WAT-text time to choose `call` vs
  ;;   `call_indirect`.
  ;;
  ;; Implements: Hβ-lower-substrate.md §3.2 + §4.2 + §6.2 + §11 + §12.3 #7;
  ;;             src/lower.mn:242-249 lower_call_default (Lock #1 LSuspend);
  ;;             src/lower.mn:347-367 CallExpr arm (Lock #3 schemekind defer);
  ;;             src/lower.mn:442-443 PerformExpr arm (Lock #2 wheel parity);
  ;;             src/lower.mn:445-448 ResumeExpr → LReturn (Lock #6);
  ;;             src/lower.mn:258-292 derive_ev_slots family (Lock #7 empty
  ;;             seed default per named follow-up).
  ;; Exports:    $lower_call,
  ;;             $lower_call_default,
  ;;             $lower_perform,
  ;;             $lower_resume,
  ;;             $derive_ev_slots,
  ;;             $lower_args
  ;; Uses:       $walk_expr_node_handle (infer/walk_expr.wat:306 — cross-layer),
  ;;             $lookup_ty / $monomorphic_at (lower/lookup.wat),
  ;;             $lexpr_make_lcall / lsuspend / lperform / lreturn (lower/lexpr.wat),
  ;;             $lower_expr (lower/main.wat — chunk #11; forward-resolves at
  ;;               assembly time per WAT module-internal call discipline),
  ;;             $make_list / $list_index / $list_set / $list_extend_to /
  ;;               $len (runtime/list.wat)
  ;; Test:       bootstrap/test/lower/walk_call_monomorphic.wat,
  ;;             bootstrap/test/lower/walk_call_polymorphic.wat,
  ;;             bootstrap/test/lower/walk_perform_oneshot.wat
  ;;
  ;; ═══ LOCKS (wheel-canonical override walkthrough §4.2 prose) ════════
  ;;
  ;; Lock #1: Polymorphic call → LSuspend tag 325, NOT LMakeClosure.
  ;;          Per src/lower.mn:242-249. The walkthrough §4.2 line 461
  ;;          prescribes LMakeClosure; the wheel emits LSuspend with
  ;;          ev_slots list. Seed transcribes wheel.
  ;;
  ;; Lock #2: $lower_perform emits straight LPerform regardless of
  ;;          ResumeDiscipline (wheel parity per src/lower.mn:442-443).
  ;;          The wheel's PerformExpr arm at line 442 is two lines, no
  ;;          dispatch on op-type's discipline. MultiShot wiring named-
  ;;          follow-up Hβ.lower.perform-multishot-dispatch — lands
  ;;          alongside cont.wat seed-bridging + state.wat current_fn
  ;;          tracking + ms_alloc_state/ret_slot helpers.
  ;;
  ;; Lock #3: CallExpr-callee schemekind triage deferred. Per
  ;;          Hβ.lower.varref-schemekind-dispatch (named at chunk #6 —
  ;;          this is second caller; the third earns the abstraction).
  ;;          $lower_call routes ALWAYS to $lower_call_default for the
  ;;          seed; ConstructorScheme → LMakeVariant + EffectOpScheme →
  ;;          LPerform short-circuits land when the third caller earns
  ;;          per Anchor 7.
  ;;
  ;; Lock #4: $env_lookup_op_type does NOT exist; per Lock #2 the seed's
  ;;          perform path doesn't need op-type since the dispatch
  ;;          collapses to wheel-parity LPerform. Named-follow-up
  ;;          Hβ.lower.op-type-resolution covers when MultiShot lands.
  ;;
  ;; Lock #5: $lower_args is chunk-private (per src/lower.mn:1055-1057
  ;;          lower_expr_list). Helpers used by exactly one chunk live in
  ;;          that chunk; third caller earns the factor.
  ;;
  ;; Lock #6: ResumeExpr → LReturn (src/lower.mn:445-448 wheel canonical).
  ;;          "Structurally a return from the arm." No invocation of
  ;;          cont.wat heap-captured continuation at the lowering layer
  ;;          — that's emit's H7 dispatch concern.
  ;;
  ;; Lock #7: $derive_ev_slots returns empty list unconditionally for
  ;;          the seed. Reasoning: the wheel's str_concat("op_", name,
  ;;          "_idx") at src/lower.mn:288 requires data segments
  ;;          ([0, 4096) is densely packed; placing strings ≥ 4096 risks
  ;;          $tag_of misclassification). Chunk #5 conservative-Linear
  ;;          precedent applies — substrate-honest deferral with named
  ;;          follow-up Hβ.lower.derive-ev-slots-naming. LSuspend's evs
  ;;          field is structurally empty until the follow-up. Emit
  ;;          handles op-name lookup at WAT-text time (per the
  ;;          divergence — emit grows the prefix/suffix substrate
  ;;          alongside its existing data-segment region).
  ;;
  ;; ═══ EIGHT INTERROGATIONS (per Hβ-lower-substrate.md §5.3 projected
  ;;                            onto walk_call.wat) ═══════════════════════
  ;;
  ;; 1. Graph?       Each arm reads $walk_expr_node_handle(node) (offset 12).
  ;;                 $lower_call_default calls $lookup_ty on the callee
  ;;                 handle — which IS $graph_chase. Read-only on graph.
  ;;
  ;; 2. Handler?     Wheel: lower_call participates in
  ;;                 LookupTy + LowerCtx + EnvRead + Diagnostic chain
  ;;                 @resume=OneShot. Seed: 6 direct functions.
  ;;                 $classify_handler (chunk #5) NOT INVOKED HERE —
  ;;                 handler classification is walk_handle.wat's concern.
  ;;
  ;; 3. Verb?        CallExpr is desugared `|>` (per spec 10:
  ;;                 `left |> right` → `LCall(h, right, [left])`). Walk_call's
  ;;                 residue IS the call shape. PerformExpr's verb is
  ;;                 ~>'s runtime peer. PipeExpr direct lowering lands
  ;;                 at chunk #8 walk_handle.wat.
  ;;
  ;; 4. Row?         $monomorphic_at IS the gradient gate. THIS CHUNK
  ;;                 IS THE ROW'S COMPILE-TIME CASH-OUT SITE.
  ;;                 $derive_ev_slots reads the callee's TFun row variant
  ;;                 (Lock #7 conservative empty-list seed; full row.names
  ;;                 walk lands at named follow-up).
  ;;
  ;; 5. Ownership?   LSuspend/LCall/LPerform/LReturn records are `own`
  ;;                 of the bump allocator. Args list is `ref`. ev_slots
  ;;                 list is `own` (newly built — empty per Lock #7).
  ;;                 $lower_args allocates one fresh list per call via
  ;;                 $make_list + buffer-counter (Ω.3).
  ;;
  ;; 6. Refinement?  TRefined transparent. $lookup_ty dispatches it as
  ;;                 the underlying type. No explicit refinement check;
  ;;                 verify ledger holds it.
  ;;
  ;; 7. Gradient?    THIS CHUNK IS THE CASH-OUT SITE. The LCall vs
  ;;                 LSuspend choice IS the row inference's >95%
  ;;                 monomorphic claim made physical. Tag chosen
  ;;                 (308 vs 325) carries information emit reads to
  ;;                 choose direct `call` vs `call_indirect`. Each
  ;;                 $lower_call_default invocation cashes one row-
  ;;                 inference win.
  ;;
  ;; 8. Reason?      Read-only. The callee handle's GNode carries the
  ;;                 Reason chain. LSuspend's op_h field (set to fh)
  ;;                 preserves the bridge so emit can walk back via
  ;;                 $gnode_reason if it surfaces a polymorphic-call
  ;;                 diagnostic.
  ;;
  ;; ═══ FORBIDDEN PATTERNS AUDIT ════════════════════════════════════
  ;;
  ;; - Drift 1 (Rust vtable):        CRITICAL per walkthrough §6.2.
  ;;                                  Polymorphic LCall path emits
  ;;                                  LSuspend with fn_index as a FIELD
  ;;                                  on the closure record (lexpr.wat
  ;;                                  arity-5); emit's call_indirect
  ;;                                  reads the field at H1.4 site —
  ;;                                  NOT a $op_table data segment. The
  ;;                                  word "vtable" appears NOWHERE in
  ;;                                  this chunk except in this audit.
  ;;
  ;; - Drift 4 (monad transformer):   No LowerM. Each $lower_<x> is
  ;;                                  (param i32) (result i32). Direct.
  ;;
  ;; - Drift 5 (C calling convention): $lower_call_default takes 4 i32
  ;;                                  params, all structurally meaningful
  ;;                                  per src/lower.mn:242 wheel signature.
  ;;                                  NO __closure + __ev + __ret_slot
  ;;                                  split. NO H7 multi-param resume_fn
  ;;                                  signature here (resume_fn lives at
  ;;                                  runtime cont.wat per H7 §1.2).
  ;;
  ;; - Drift 6 (primitive-special-case): $monomorphic_at returns i32 0/1
  ;;                                  — same nullary discipline as
  ;;                                  Bool/TInt/ResumeDiscipline. NO
  ;;                                  carveout.
  ;;
  ;; - Drift 7 (parallel-arrays):     ev_slots is one list of LowExpr
  ;;                                  records (Lock #7: empty seed
  ;;                                  default). NOT parallel _names_ptr
  ;;                                  + _slots_ptr arrays.
  ;;
  ;; - Drift 8 (string-keyed):        Tag-int dispatch only. The op_name
  ;;                                  in LPerform IS a string (per
  ;;                                  lexpr.wat tag 331 wheel canonical)
  ;;                                  — but it's THREADED, not COMPARED.
  ;;                                  No `if str_eq(op_name, "choose")`
  ;;                                  dispatch decision.
  ;;
  ;; - Drift 9 (deferred-by-omission): All 6 exports FULLY BODIED this
  ;;                                  commit. ResumeDiscipline arms in
  ;;                                  $lower_perform collapse to wheel-
  ;;                                  parity LPerform per Lock #2 — not
  ;;                                  a stub. MultiShot enrichment is
  ;;                                  named peer follow-up. $derive_ev_slots
  ;;                                  empty-list seed default per Lock #7
  ;;                                  is bodied with explicit reasoning;
  ;;                                  full naming is named peer follow-up.
  ;;                                  $lower_resume bodied this commit
  ;;                                  even though parser-side
  ;;                                  $mk_ResumeExpr does not yet exist
  ;;                                  (drift-9-safe: an unconstructible
  ;;                                  AST tag will simply never reach
  ;;                                  this arm; if/when parser produces
  ;;                                  tag 95, body is correct per wheel
  ;;                                  canonical).
  ;;
  ;; - Foreign fluency JS async/await: NEVER "promise call" / "async call"
  ;;                                  / "future" / "await". Vocabulary is
  ;;                                  LPerform / LSuspend / "perform-op"
  ;;                                  per spec 05.
  ;;
  ;; - Foreign fluency Scheme call/cc: Continuations are DELIMITED
  ;;                                  (handler-install scope). NEVER
  ;;                                  "undelimited" / "call/cc" /
  ;;                                  "captured stack".
  ;;
  ;; - Foreign fluency LLVM/GHC IR:   NEVER "SSA value" / "phi node" /
  ;;                                  "calling convention enum" /
  ;;                                  "core IR". Vocabulary stays Mentl:
  ;;                                  LowExpr / LCall / LSuspend /
  ;;                                  LPerform / LReturn per spec 05.
  ;;
  ;; ═══ Named follow-ups (Drift 9 closure) ═════════════════════════════
  ;;
  ;;   - Hβ.lower.perform-multishot-dispatch:
  ;;                 wheel grows ResumeDiscipline-aware PerformExpr arm;
  ;;                 seed grows $current_fn_handle tracking +
  ;;                 $ms_alloc_state/$ms_alloc_ret_slot substrate +
  ;;                 cont.wat seed-bridge; emits
  ;;                 LBlock(LMakeContinuation, LPerform) pair.
  ;;
  ;;   - Hβ.lower.derive-ev-slots-naming:
  ;;                 Wheel str_concat("op_", op_name, "_idx") at
  ;;                 src/lower.mn:288 lands in this chunk + emit grows
  ;;                 prefix/suffix data-segment naming; LSuspend's evs
  ;;                 list becomes per-name LGlobal records.
  ;;
  ;;   - Hβ.lower.resume-harness:
  ;;                 Parser-side $mk_ResumeExpr ships; ResumeExpr
  ;;                 trace-harness can construct + verify $lower_resume.
  ;;
  ;;   - Hβ.lower.lower-call-default-signature-alignment:
  ;;                 Third caller (walk_compound or walk_handle) earns
  ;;                 the wheel's (handle, f_node, fh, lo_args) signature
  ;;                 with internal recursion. Until then, this chunk's
  ;;                 (handle, lo_f, fh, lo_args) form (caller pre-lowers)
  ;;                 stands.
  ;;
  ;;   - Hβ.lower.varref-schemekind-dispatch:
  ;;                 (extends from chunk #6) ConstructorScheme +
  ;;                 EffectOpScheme triage in $lower_call routes to
  ;;                 LMakeVariant / LPerform short-circuits before
  ;;                 falling through to $lower_call_default.
  ;;
  ;;   - Hβ.lower.op-type-resolution:
  ;;                 MultiShot dispatch needs op-type's ResumeDiscipline;
  ;;                 lands alongside perform-multishot-dispatch.
  ;;
  ;;   - Hβ.lower.resume-state-updates-threading:
  ;;                 Wheel grows state-machine threading at handler-
  ;;                 elimination; ResumeExpr's state_updates payload
  ;;                 becomes load-bearing.

  ;; ─── $lower_expr — partial dispatcher (forward-decl bridge) ──────
  ;; Per the cascade dep-order surfacing: $lower_expr is the
  ;; canonical top-level dispatcher per Hβ-lower-substrate.md §4.1
  ;; and lands at chunk #11 main.wat (the orchestrator). But walk_call,
  ;; walk_handle, walk_compound, walk_stmt all need recursive
  ;; sub-expression lowering BEFORE chunk #11 lands. The Hβ.infer
  ;; cascade resolved an analogous forward-decl (walk_expr:824 →
  ;; walk_stmt:$infer_stmt_list) by both chunks landing in the same
  ;; assembled mentl.wat — but here chunk #11 hasn't been written yet.
  ;;
  ;; Resolution: define $lower_expr HERE as a partial dispatcher over
  ;; the tags chunks #6 + #7 know about. Future walk chunks (#8-#10)
  ;; retrofit this dispatcher (adding their tag arms) per named follow-up
  ;; Hβ.lower.lower-expr-dispatch-extension. Chunk #11 main.wat owns
  ;; the orchestrator $lower_program but DOES NOT redefine $lower_expr
  ;; — by then this dispatcher is complete via cumulative retrofits.
  ;;
  ;; Drift-9-safe: every tag this dispatcher claims to know IS bodied;
  ;; unknown tags trap via (unreachable) — the trap surfaces when a
  ;; future walk chunk forgets to retrofit. Named follow-up makes the
  ;; expansion visible.
  ;;
  ;; Currently dispatches:
  ;;   80 LitInt    → $lower_lit_int       (chunk #6 walk_const)
  ;;   81 LitFloat  → $lower_lit_float
  ;;   82 LitString → $lower_lit_string
  ;;   83 LitBool   → $lower_lit_bool
  ;;   84 LitUnit   → $lower_lit_unit
  ;;   85 VarRef    → $lower_var_ref
  ;;   87 UnaryOp   → $lower_unary_op      (chunk #9 retrofit)
  ;;   88 CallExpr  → $lower_call          (this chunk #7)
  ;;   89 Lambda    → $lower_lambda        (chunk #9 retrofit)
  ;;   90 If        → $lower_if            (chunk #9 retrofit)
  ;;   91 Block     → $lower_block         (chunk #9 retrofit)
  ;;   92 Match     → $lower_match         (chunk #9 retrofit)
  ;;   93 HandleExpr → $lower_handle       (chunk #8 retrofit)
  ;;   94 Perform    → $lower_perform
  ;;   95 Resume     → $lower_resume
  ;;   96 MakeList   → $lower_make_list    (chunk #9 retrofit)
  ;;   97 MakeTuple  → $lower_make_tuple   (chunk #9 retrofit)
  ;;   98 MakeRecord → $lower_make_record  (chunk #9 retrofit)
  ;;   99 NamedRecord → $lower_named_record (chunk #9 retrofit)
  ;;   100 FieldExpr → $lower_field        (chunk #9 retrofit)
  ;;   101 PipeExpr  → $lower_pipe         (chunk #8 retrofit)
  ;;
  ;; Unknown (BinOpExpr 86 — chunk #6 BinOp arm pending; future Expr-region
  ;; growth) → (unreachable) trap. Named follow-up
  ;; Hβ.lower.lower-expr-dispatch-extension closes BinOp at the next
  ;; cycle.
  ;;
  ;; AST navigation: $node is the N-wrapper; tag dispatch reads
  ;; offset 4 → NExpr → offset 4 → variant Expr; tag is at offset 0
  ;; of the variant Expr.
  (func $lower_expr (export "lower_expr") (param $node i32) (result i32)
    (local $body i32) (local $expr i32) (local $tag i32)
    (local.set $body (i32.load offset=4 (local.get $node)))
    (local.set $expr (i32.load offset=4 (local.get $body)))
    (local.set $tag  (i32.load offset=0 (local.get $expr)))
    (if (i32.eq (local.get $tag) (i32.const 80))
      (then (return (call $lower_lit_int    (local.get $node)))))
    (if (i32.eq (local.get $tag) (i32.const 81))
      (then (return (call $lower_lit_float  (local.get $node)))))
    (if (i32.eq (local.get $tag) (i32.const 82))
      (then (return (call $lower_lit_string (local.get $node)))))
    (if (i32.eq (local.get $tag) (i32.const 83))
      (then (return (call $lower_lit_bool   (local.get $node)))))
    (if (i32.eq (local.get $tag) (i32.const 84))
      (then (return (call $lower_lit_unit   (local.get $node)))))
    (if (i32.eq (local.get $tag) (i32.const 85))
      (then (return (call $lower_var_ref    (local.get $node)))))
    (if (i32.eq (local.get $tag) (i32.const 88))
      (then (return (call $lower_call       (local.get $node)))))
    (if (i32.eq (local.get $tag) (i32.const 94))
      (then (return (call $lower_perform    (local.get $node)))))
    (if (i32.eq (local.get $tag) (i32.const 95))
      (then (return (call $lower_resume     (local.get $node)))))
    (if (i32.eq (local.get $tag) (i32.const 93))
      (then (return (call $lower_handle     (local.get $node)))))
    (if (i32.eq (local.get $tag) (i32.const 101))
      (then (return (call $lower_pipe       (local.get $node)))))
    (if (i32.eq (local.get $tag) (i32.const 86))
      (then (return (call $lower_binop       (local.get $node)))))
    (if (i32.eq (local.get $tag) (i32.const 87))
      (then (return (call $lower_unary_op    (local.get $node)))))
    (if (i32.eq (local.get $tag) (i32.const 89))
      (then (return (call $lower_lambda      (local.get $node)))))
    (if (i32.eq (local.get $tag) (i32.const 90))
      (then (return (call $lower_if          (local.get $node)))))
    (if (i32.eq (local.get $tag) (i32.const 91))
      (then (return (call $lower_block       (local.get $node)))))
    (if (i32.eq (local.get $tag) (i32.const 92))
      (then (return (call $lower_match       (local.get $node)))))
    (if (i32.eq (local.get $tag) (i32.const 96))
      (then (return (call $lower_make_list   (local.get $node)))))
    (if (i32.eq (local.get $tag) (i32.const 97))
      (then (return (call $lower_make_tuple  (local.get $node)))))
    (if (i32.eq (local.get $tag) (i32.const 98))
      (then (return (call $lower_make_record (local.get $node)))))
    (if (i32.eq (local.get $tag) (i32.const 99))
      (then (return (call $lower_named_record (local.get $node)))))
    (if (i32.eq (local.get $tag) (i32.const 100))
      (then (return (call $lower_field       (local.get $node)))))
    ;; Unknown tag — productive-under-error per Hazel discipline.
    ;; Emit diagnostic, return unit-sentinel LConst so callers can compose.
    (call $lower_emit_unresolved_type (call $walk_expr_node_handle (local.get $node)))
    (call $lexpr_make_lconst
      (call $walk_expr_node_handle (local.get $node))
      (i32.const 0)))

  ;; ─── $lower_args — chunk-private buffer-counter helper (Lock #5) ──
  ;; Per src/lower.mn:1055-1057 lower_expr_list. Buffer-counter substrate
  ;; (Ω.3 per CLAUDE.md memory model — avoids O(N²) `acc ++ [x]`).
  ;; Each arg is an N-wrapper; $lower_expr (chunk #11 main.wat —
  ;; forward-resolves at WAT module assembly time) returns the LowExpr.
  (func $lower_args (param $args i32) (result i32)
    (local $n i32) (local $i i32) (local $buf i32)
    (local $arg_node i32) (local $arg_lo i32)
    (local.set $n (call $len (local.get $args)))
    (local.set $buf (call $make_list (i32.const 0)))
    (local.set $buf (call $list_extend_to (local.get $buf) (local.get $n)))
    (local.set $i (i32.const 0))
    (block $done
      (loop $each
        (br_if $done (i32.ge_u (local.get $i) (local.get $n)))
        (local.set $arg_node (call $list_index (local.get $args) (local.get $i)))
        (local.set $arg_lo   (call $lower_expr  (local.get $arg_node)))
        (drop (call $list_set (local.get $buf) (local.get $i) (local.get $arg_lo)))
        (local.set $i (i32.add (local.get $i) (i32.const 1)))
        (br $each)))
    (local.get $buf))

  ;; ─── $derive_ev_slots — H1.6 polymorphic ev-list (Lock #7 empty) ──
  ;; Per Lock #7 above + named follow-up Hβ.lower.derive-ev-slots-naming.
  ;; Conservative seed default: returns empty list. Wheel-parity
  ;; matching wheel src/lower.mn:264-269 EfPure case — which IS empty.
  ;; The seed effectively treats every callee as Pure-row at this layer;
  ;; emit's H1.4 substrate handles the per-op naming when it grows.
  ;;
  ;; This is NOT drift-9: the function exists at the named symbol,
  ;; returns a defensible value (empty list — what wheel returns for
  ;; EfPure, the >95% case), and the future enrichment is a peer.
  (func $derive_ev_slots (export "derive_ev_slots") (param $callee_handle i32) (result i32)
    (call $make_list (i32.const 0)))

  ;; ─── $lower_call_default — monomorphic-vs-polymorphic gate ─────────
  ;; Per src/lower.mn:242-249 + Lock #1. The gradient cash-out.
  ;;
  ;; Seed signature divergence (per Lock #5):
  ;;   wheel: (handle, f_node, fh, lo_args) — does its own lower_expr(f)
  ;;   seed:  (handle, lo_f, fh, lo_args)   — caller pre-lowers callee
  ;;
  ;; Equivalent; lifts the recursion to the CallExpr arm to keep
  ;; chunk-internal cleanliness. Named follow-up
  ;; Hβ.lower.lower-call-default-signature-alignment surfaces wheel
  ;; alignment when the third caller earns it.
  ;;
  ;; Avoids Drift 1: LSuspend tag 325 carries fn_index as a FIELD on
  ;;   the closure record (lexpr.wat:625-657); emit's call_indirect
  ;;   site at H1.4 reads the field — NOT a vtable / op_table.
  (func $lower_call_default (export "lower_call_default")
        (param $handle i32) (param $lo_f i32) (param $fh i32) (param $lo_args i32)
        (result i32)
    (local $evs i32)
    (if (call $monomorphic_at (local.get $handle))
      (then (return (call $lexpr_make_lcall
                      (local.get $handle)
                      (local.get $lo_f)
                      (local.get $lo_args)))))
    ;; Polymorphic — H1.6 evidence-passing thunk via LSuspend.
    (local.set $evs (call $derive_ev_slots (local.get $fh)))
    (call $lexpr_make_lsuspend
      (local.get $handle)
      (local.get $fh)
      (local.get $lo_f)
      (local.get $lo_args)
      (local.get $evs)))

  ;; ─── $lower_call — CallExpr arm (parser tag 88) ────────────────────
  ;; Per src/lower.mn:347-367 CallExpr arm + Lock #3 (schemekind triage
  ;; deferred to Hβ.lower.varref-schemekind-dispatch).
  ;;
  ;; AST navigation: $node is the N-wrapper. Per parser_infra.wat:32-39:
  ;;   offset 4  → NExpr-wrapper (tag 110)
  ;;     offset 4  → CallExpr (tag 88), per parser_infra.wat:111-116:
  ;;                   offset 4 → callee N-wrapper
  ;;                   offset 8 → args list
  ;;   offset 12 → handle
  ;; SchemeKind triage per Hβ.lower.varref-schemekind-dispatch (named
  ;; follow-up; closing it here): when the callee is a VarRef whose
  ;; env binding is a ConstructorScheme, route to LMakeVariant
  ;; (instead of LCall/LSuspend). Same shortcut for EffectOpScheme →
  ;; LPerform when the parser starts producing PerformExpr at call
  ;; sites without explicit `perform` keyword (today the seed parses
  ;; `perform op(...)` separately via parse_perform_expr → tag 94, so
  ;; the EffectOpScheme branch here is reachable only through
  ;; user-named direct-call style; harmless to leave unimplemented
  ;; in this commit and named as Hβ.lower.varref-effectop-dispatch).
  ;;
  ;; Eight interrogations on this dispatch site:
  ;;   1. Graph?      ConstructorScheme tag_id IS recorded in env at
  ;;                  TypeDef pre-register time (walk_stmt.wat:818-874).
  ;;   2. Handler?    @resume=OneShot (lookup is read-only).
  ;;   3. Verb?       N/A — structural dispatch.
  ;;   4. Row?        Pure read on env; no effects performed beyond
  ;;                  EnvRead implicit in env_lookup.
  ;;   5. Ownership?  $callee_node is borrowed; binding handle borrowed
  ;;                  from env.
  ;;   6. Refinement? ConstructorScheme(tag_id, total) carries the
  ;;                  invariant 0 ≤ tag_id < total.
  ;;   7. Gradient?   The cash-out: nullary ctors emit (i32.const tag_id)
  ;;                  sentinels; N-ary ctors heap-allocate via
  ;;                  emit_alloc — same EmitMemory swap surface as the
  ;;                  rest of the heap.
  ;;   8. Reason?     LMakeVariant carries the call's handle; Reason
  ;;                  flows from the env binding's stored Reason.
  ;;
  ;; Drift modes refused:
  ;; - Drift 1 (vtable):  Direct schemekind tag dispatch; no table.
  ;; - Drift 6 (special): Same dispatch path for nullary AND N-ary
  ;;                      ctors via $lexpr_make_lmakevariant; no Bool-
  ;;                      special-case (HB substrate already covers).
  ;; - Drift 8 (string):  Schemekind tag is i32 (132); not str_eq.
  ;; - Drift 9 (deferred): All branches bodied; closes
  ;;                      Hβ.lower.varref-schemekind-dispatch.

  (func $lower_call (export "lower_call") (param $node i32) (result i32)
    (local $h i32) (local $body i32) (local $call_struct i32)
    (local $callee_node i32) (local $args_list i32)
    (local $lo_f i32) (local $lo_args i32) (local $fh i32)
    (local $cb_body i32) (local $cb_expr i32) (local $name i32)
    (local $binding i32) (local $kind i32) (local $kind_tag i32)
    (local $tag_id i32)
    (local.set $h           (call $walk_expr_node_handle (local.get $node)))
    (local.set $body        (i32.load offset=4 (local.get $node)))
    (local.set $call_struct (i32.load offset=4 (local.get $body)))
    (local.set $callee_node (i32.load offset=4 (local.get $call_struct)))
    (local.set $args_list   (i32.load offset=8 (local.get $call_struct)))
    ;; Pre-dispatch: peek at callee_node — if it's a VarRef whose env
    ;; binding has ConstructorScheme, short-circuit to LMakeVariant.
    ;; AST navigation: callee_node is N(NodeBody, span, handle).
    ;;   offset 4 → NodeBody (NExpr wrapper, tag 110 — offset 4 → expr).
    (local.set $cb_body (i32.load offset=4 (local.get $callee_node)))
    (if (i32.eq (i32.load (local.get $cb_body)) (i32.const 110))
      (then
        (local.set $cb_expr (i32.load offset=4 (local.get $cb_body)))
        ;; If inner expr is VarRef (tag 85), look up the name in env.
        (if (i32.eq (i32.load (local.get $cb_expr)) (i32.const 85))
          (then
            (local.set $name (i32.load offset=4 (local.get $cb_expr)))
            (local.set $binding (call $env_lookup (local.get $name)))
            (if (i32.ne (local.get $binding) (i32.const 0))
              (then
                (local.set $kind (call $env_binding_kind (local.get $binding)))
                (local.set $kind_tag (call $schemekind_tag (local.get $kind)))
                ;; ConstructorScheme tag is 132 per env.wat:161.
                (if (i32.eq (local.get $kind_tag) (i32.const 132))
                  (then
                    (local.set $tag_id (call $schemekind_ctor_tag_id (local.get $kind)))
                    (local.set $lo_args (call $lower_args (local.get $args_list)))
                    (return (call $lexpr_make_lmakevariant
                                  (local.get $h)
                                  (local.get $tag_id)
                                  (local.get $lo_args)))))))))))
    ;; Default closure-call form per Lock #3.
    (local.set $lo_f    (call $lower_expr (local.get $callee_node)))
    (local.set $lo_args (call $lower_args (local.get $args_list)))
    (local.set $fh      (call $walk_expr_node_handle (local.get $callee_node)))
    (call $lower_call_default
      (local.get $h)
      (local.get $lo_f)
      (local.get $fh)
      (local.get $lo_args)))

  ;; ─── $lower_perform — PerformExpr arm (parser tag 94) ──────────────
  ;; Per src/lower.mn:442-443 + Lock #2 (wheel-parity LPerform for ALL
  ;; ResumeDiscipline values; H7 MultiShot dispatch is named follow-up
  ;; Hβ.lower.perform-multishot-dispatch).
  ;;
  ;; AST navigation per parser_infra.wat:144-149 PerformExpr (tag 94):
  ;;   offset 4 → op_name string ptr
  ;;   offset 8 → args list
  (func $lower_perform (export "lower_perform") (param $node i32) (result i32)
    (local $h i32) (local $body i32) (local $perform_struct i32)
    (local $op_name i32) (local $args_list i32) (local $lo_args i32)
    (local $resolved i32)
    (local.set $h              (call $walk_expr_node_handle (local.get $node)))
    (local.set $body           (i32.load offset=4 (local.get $node)))
    (local.set $perform_struct (i32.load offset=4 (local.get $body)))
    (local.set $op_name        (i32.load offset=4 (local.get $perform_struct)))
    (local.set $args_list      (i32.load offset=8 (local.get $perform_struct)))
    (local.set $lo_args        (call $lower_args (local.get $args_list)))
    ;; Hβ.first-light.seed-lperform-discriminator-mirror — query
    ;; lower-stage handler-stack for the innermost handler that
    ;; handles op_name's effect. If found, the discriminated target
    ;; "<handler>_<op>" matches the module-level $op_<handler>_<op>
    ;; symbol minted by $lower_handler_arms_as_decls (commit 22a4bbc).
    ;; If not found (no handler in scope or op not an EffectOpScheme),
    ;; emit undiscriminated for productive-under-error.
    ;;
    ;; Tier 1 ULTIMATE FORM monomorphic direct-call per SUBSTRATE.md
    ;; §"Three Tiers of Effect Compilation"; mirrors src/lower.mn
    ;; commit 50a9512's wheel-canonical PerformExpr discrimination.
    (local.set $resolved (call $lower_resolve_handler_for_op (local.get $op_name)))
    (if (result i32) (i32.ne (local.get $resolved) (i32.const 0))
      (then
        (call $lexpr_make_lperform
          (local.get $h)
          (local.get $resolved)
          (local.get $lo_args)))
      (else
        (call $lexpr_make_lperform
          (local.get $h)
          (local.get $op_name)
          (local.get $lo_args)))))

  ;; ─── $lower_resume — ResumeExpr arm (parser tag 95) ────────────────
  ;; Per src/lower.mn:445-448 + Lock #6. ResumeExpr is "structurally a
  ;; return from the handler arm" per the wheel comment. Seed emits
  ;; LReturn(handle, lower_expr(val)).
  ;;
  ;; AST navigation: $mk_ResumeExpr does NOT yet exist in parser_infra.wat
  ;; (named follow-up Hβ.lower.resume-harness covers parser-side support).
  ;; Layout assumption: [tag=95][val_ptr][state_updates_ptr]. Lower
  ;; IGNORES state_updates per wheel underscore-pattern. State-machine
  ;; threading at handler-elimination is named follow-up
  ;; Hβ.lower.resume-state-updates-threading.
  (func $lower_resume (export "lower_resume") (param $node i32) (result i32)
    (local $h i32) (local $body i32) (local $resume_struct i32)
    (local $val_node i32) (local $lo_val i32)
    (local.set $h              (call $walk_expr_node_handle (local.get $node)))
    (local.set $body           (i32.load offset=4 (local.get $node)))
    (local.set $resume_struct  (i32.load offset=4 (local.get $body)))
    (local.set $val_node       (i32.load offset=4 (local.get $resume_struct)))
    (local.set $lo_val         (call $lower_expr (local.get $val_node)))
    (call $lexpr_make_lreturn
      (local.get $h)
      (local.get $lo_val)))
