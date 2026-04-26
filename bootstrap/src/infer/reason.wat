  ;; ═══ reason.wat — Reason record constructors (Tier 5) ═════════════
  ;; Implements: Hβ-infer-substrate.md §1 (extended commit `38b0075`) +
  ;;             §8.1 reason.wat row + §8.4 line estimate. Realizes
  ;;             primitive #8 (HM inference, productive-under-error,
  ;;             with Reasons) at the seed substrate layer:
  ;;             every $graph_bind / $graph_fresh_*  call carries a
  ;;             Reason; the Why Engine walks this DAG (spec 09).
  ;; Exports:    $reason_tag,
  ;;             $reason_make_declared / $reason_declared_name,
  ;;             $reason_make_inferred / $reason_inferred_ctx,
  ;;             $reason_make_fresh / $reason_fresh_id,
  ;;             $reason_make_opconstraint / $reason_opconstraint_op /
  ;;               $reason_opconstraint_left / $reason_opconstraint_right,
  ;;             $reason_make_varlookup / $reason_varlookup_name /
  ;;               $reason_varlookup_inner,
  ;;             $reason_make_fnreturn / $reason_fnreturn_name /
  ;;               $reason_fnreturn_inner,
  ;;             $reason_make_fnparam / $reason_fnparam_name /
  ;;               $reason_fnparam_idx / $reason_fnparam_inner,
  ;;             $reason_make_matchbranch / $reason_matchbranch_left /
  ;;               $reason_matchbranch_right,
  ;;             $reason_make_listelement / $reason_listelement_inner,
  ;;             $reason_make_ifbranch / $reason_ifbranch_inner,
  ;;             $reason_make_letbinding / $reason_letbinding_name /
  ;;               $reason_letbinding_inner,
  ;;             $reason_make_unified / $reason_unified_left /
  ;;               $reason_unified_right,
  ;;             $reason_make_instantiation / $reason_instantiation_name /
  ;;               $reason_instantiation_inner,
  ;;             $reason_make_unifyfailed / $reason_unifyfailed_left /
  ;;               $reason_unifyfailed_right,
  ;;             $reason_make_placeholder / $reason_placeholder_span,
  ;;             $reason_make_binopplaceholder / $reason_binopplaceholder_op,
  ;;             $reason_make_missingvar / $reason_missingvar_name,
  ;;             $reason_make_refinement / $reason_refinement_left /
  ;;               $reason_refinement_right,
  ;;             $reason_make_located / $reason_located_span /
  ;;               $reason_located_inner,
  ;;             $reason_make_inferredcallreturn /
  ;;               $reason_inferredcallreturn_callee /
  ;;               $reason_inferredcallreturn_inner,
  ;;             $reason_make_inferredpiperesult /
  ;;               $reason_inferredpiperesult_verb /
  ;;               $reason_inferredpiperesult_inner,
  ;;             $reason_make_freshincontext /
  ;;               $reason_freshincontext_handle /
  ;;               $reason_freshincontext_ctx,
  ;;             $reason_make_docstringreason /
  ;;               $reason_docstringreason_doc /
  ;;               $reason_docstringreason_span
  ;; Uses:       $make_record / $record_get / $tag_of (record.wat)
  ;; Test:       runtime_test/infer_reason.wat (pending — first acceptance is
  ;;             $reason_make_*-grep + wasm-validate per Hβ-infer-substrate.md
  ;;             §11)
  ;;
  ;; ═══ DESIGN ═══════════════════════════════════════════════════════
  ;;
  ;; Per spec 02 (Reason ADT — vocabulary types) + spec 08 (query —
  ;; Why Engine walks the DAG) + src/types.nx canonical Reason ADT
  ;; (lines 231-255): 23 variants. Every graph node and every
  ;; unification records a Reason. show_reason at src/types.nx:982
  ;; walks every field of every variant — so the seed needs constructors
  ;; AND accessors per field; downstream emit_diag.wat / query layer
  ;; cannot rebuild a show_reason equivalent without them.
  ;;
  ;; Reasons compose with GNode per spec 00:
  ;;   GNode = GNode(NodeKind, Reason)
  ;; The seed's $gnode_make (graph.wat:62) takes (kind_record, reason_ptr)
  ;; and stores the reason at offset 1; chase walks return GNodes whose
  ;; reason field is one of these 23-variant records.
  ;;
  ;; ═══ TAG REGION ═══════════════════════════════════════════════════
  ;;
  ;; Per Hβ-infer-substrate.md §2.1 (extended 2026-04-26 per Wave 2.E.infer.reason
  ;; substrate-gap finding):
  ;;   200-219 — non-Reason infer-private records (state.wat consumed
  ;;             210/211/212 for REF_ESCAPE_ENTRY / SPAN_INDEX_ENTRY /
  ;;             INTENT_INDEX_ENTRY)
  ;;   220-249 — Reason variants (30 slots; this chunk uses 220-242 for
  ;;             current 23 variants; 243-249 reserved for future
  ;;             Reason variants per src/types.nx evolution)
  ;;
  ;; Per-variant tag enumeration (alphabetical by ADT order in
  ;; src/types.nx lines 231-255):
  ;;   220 = Declared(String)                          arity 1
  ;;   221 = Inferred(String)                          arity 1
  ;;   222 = Fresh(Int)                                arity 1
  ;;   223 = OpConstraint(String, Reason, Reason)      arity 3
  ;;   224 = VarLookup(String, Reason)                 arity 2
  ;;   225 = FnReturn(String, Reason)                  arity 2
  ;;   226 = FnParam(String, Int, Reason)              arity 3
  ;;   227 = MatchBranch(Reason, Reason)               arity 2
  ;;   228 = ListElement(Reason)                       arity 1
  ;;   229 = IfBranch(Reason)                          arity 1
  ;;   230 = LetBinding(String, Reason)                arity 2
  ;;   231 = Unified(Reason, Reason)                   arity 2
  ;;   232 = Instantiation(String, Reason)             arity 2
  ;;   233 = UnifyFailed(Ty, Ty)                       arity 2
  ;;   234 = Placeholder(Span)                         arity 1
  ;;   235 = BinOpPlaceholder(BinOp)                   arity 1
  ;;   236 = MissingVar(String)                        arity 1
  ;;   237 = Refinement(Predicate, Predicate)          arity 2
  ;;   238 = Located(Span, Reason)                     arity 2
  ;;   239 = InferredCallReturn(String, Reason)        arity 2
  ;;   240 = InferredPipeResult(String, Reason)        arity 2
  ;;   241 = FreshInContext(Int, String)               arity 2
  ;;   242 = DocstringReason(String, Span)             arity 2
  ;;
  ;; Ty / Span / Predicate / BinOp payloads are stored as opaque i32
  ;; pointers per the verify.wat:39 precedent (verify.wat treats its
  ;; predicate field as opaque Ty/Expr ptr — Hβ.infer's verify-effect
  ;; arm passes the structured pointer, the substrate just stores it).
  ;; ty.wat (Tier 5 sibling) + parser substrate (Layer 3) own the
  ;; structured payload shapes; reason.wat just carries them as i32.
  ;;
  ;; ═══ EIGHT INTERROGATIONS (per Hβ-infer-substrate.md §6) ══════════
  ;; 1. Graph?      Reasons live INLINE in GNodes per spec 00 GNode =
  ;;                (NodeKind, Reason). Constructors here produce records
  ;;                that graph.wat $gnode_make accepts as the second arg.
  ;; 2. Handler?    Direct constructors at the seed level; the wheel's
  ;;                compiled form is also direct (Reasons are passive data).
  ;; 3. Verb?       N/A.
  ;; 4. Row?        N/A; pure data.
  ;; 5. Ownership?  Payloads typically `ref` (spans + handles + names
  ;;                borrowed; not consumed).
  ;; 6. Refinement? N/A at constructor level.
  ;; 7. Gradient?   Reasons feed the Why Engine; each variant is a
  ;;                gradient step the Why-walker traces.
  ;; 8. Reason?     These constructors ARE the Reason substrate.
  ;;
  ;; ═══ FORBIDDEN PATTERNS AUDIT (per Hβ-infer-substrate.md §7) ══════
  ;; - Drift 7 (parallel-arrays):     every variant is ONE record;
  ;;                                  no parallel arrays.
  ;; - Drift 8 (string-keyed):        integer constant tags 220-242;
  ;;                                  not "OpConstraint" strings.
  ;; - Drift 9 (deferred-by-omission): every variant in src/types.nx
  ;;                                  Reason ADT gets its constructor
  ;;                                  in this commit. No `;; TODO add
  ;;                                  Synth Reasons later` placeholders.
  ;; - Foreign fluency:               no "stack trace" / "log entry" /
  ;;                                  "audit record" vocabulary. Names
  ;;                                  match src/types.nx variants exactly
  ;;                                  (lowercased for WAT convention).

  ;; ─── Universal tag accessor ──────────────────────────────────────
  ;; Returns the Reason record's tag (220-242). Downstream dispatch
  ;; (emit_diag.wat show_reason equivalent, query layer Why-walker)
  ;; reads this to choose the variant arm.
  (func $reason_tag (param $reason i32) (result i32)
    (call $tag_of (local.get $reason)))

  ;; ─── 220 = Declared(String) ──────────────────────────────────────
  (func $reason_make_declared (param $name i32) (result i32)
    (local $r i32)
    (local.set $r (call $make_record (i32.const 220) (i32.const 1)))
    (call $record_set (local.get $r) (i32.const 0) (local.get $name))
    (local.get $r))

  (func $reason_declared_name (param $r i32) (result i32)
    (call $record_get (local.get $r) (i32.const 0)))

  ;; ─── 221 = Inferred(String) ──────────────────────────────────────
  (func $reason_make_inferred (param $ctx i32) (result i32)
    (local $r i32)
    (local.set $r (call $make_record (i32.const 221) (i32.const 1)))
    (call $record_set (local.get $r) (i32.const 0) (local.get $ctx))
    (local.get $r))

  (func $reason_inferred_ctx (param $r i32) (result i32)
    (call $record_get (local.get $r) (i32.const 0)))

  ;; ─── 222 = Fresh(Int) ────────────────────────────────────────────
  (func $reason_make_fresh (param $id i32) (result i32)
    (local $r i32)
    (local.set $r (call $make_record (i32.const 222) (i32.const 1)))
    (call $record_set (local.get $r) (i32.const 0) (local.get $id))
    (local.get $r))

  (func $reason_fresh_id (param $r i32) (result i32)
    (call $record_get (local.get $r) (i32.const 0)))

  ;; ─── 223 = OpConstraint(String, Reason, Reason) ──────────────────
  (func $reason_make_opconstraint (param $op i32) (param $left i32) (param $right i32)
                                   (result i32)
    (local $r i32)
    (local.set $r (call $make_record (i32.const 223) (i32.const 3)))
    (call $record_set (local.get $r) (i32.const 0) (local.get $op))
    (call $record_set (local.get $r) (i32.const 1) (local.get $left))
    (call $record_set (local.get $r) (i32.const 2) (local.get $right))
    (local.get $r))

  (func $reason_opconstraint_op (param $r i32) (result i32)
    (call $record_get (local.get $r) (i32.const 0)))

  (func $reason_opconstraint_left (param $r i32) (result i32)
    (call $record_get (local.get $r) (i32.const 1)))

  (func $reason_opconstraint_right (param $r i32) (result i32)
    (call $record_get (local.get $r) (i32.const 2)))

  ;; ─── 224 = VarLookup(String, Reason) ─────────────────────────────
  (func $reason_make_varlookup (param $name i32) (param $inner i32) (result i32)
    (local $r i32)
    (local.set $r (call $make_record (i32.const 224) (i32.const 2)))
    (call $record_set (local.get $r) (i32.const 0) (local.get $name))
    (call $record_set (local.get $r) (i32.const 1) (local.get $inner))
    (local.get $r))

  (func $reason_varlookup_name (param $r i32) (result i32)
    (call $record_get (local.get $r) (i32.const 0)))

  (func $reason_varlookup_inner (param $r i32) (result i32)
    (call $record_get (local.get $r) (i32.const 1)))

  ;; ─── 225 = FnReturn(String, Reason) ──────────────────────────────
  (func $reason_make_fnreturn (param $name i32) (param $inner i32) (result i32)
    (local $r i32)
    (local.set $r (call $make_record (i32.const 225) (i32.const 2)))
    (call $record_set (local.get $r) (i32.const 0) (local.get $name))
    (call $record_set (local.get $r) (i32.const 1) (local.get $inner))
    (local.get $r))

  (func $reason_fnreturn_name (param $r i32) (result i32)
    (call $record_get (local.get $r) (i32.const 0)))

  (func $reason_fnreturn_inner (param $r i32) (result i32)
    (call $record_get (local.get $r) (i32.const 1)))

  ;; ─── 226 = FnParam(String, Int, Reason) ──────────────────────────
  (func $reason_make_fnparam (param $name i32) (param $idx i32) (param $inner i32)
                              (result i32)
    (local $r i32)
    (local.set $r (call $make_record (i32.const 226) (i32.const 3)))
    (call $record_set (local.get $r) (i32.const 0) (local.get $name))
    (call $record_set (local.get $r) (i32.const 1) (local.get $idx))
    (call $record_set (local.get $r) (i32.const 2) (local.get $inner))
    (local.get $r))

  (func $reason_fnparam_name (param $r i32) (result i32)
    (call $record_get (local.get $r) (i32.const 0)))

  (func $reason_fnparam_idx (param $r i32) (result i32)
    (call $record_get (local.get $r) (i32.const 1)))

  (func $reason_fnparam_inner (param $r i32) (result i32)
    (call $record_get (local.get $r) (i32.const 2)))

  ;; ─── 227 = MatchBranch(Reason, Reason) ───────────────────────────
  (func $reason_make_matchbranch (param $left i32) (param $right i32) (result i32)
    (local $r i32)
    (local.set $r (call $make_record (i32.const 227) (i32.const 2)))
    (call $record_set (local.get $r) (i32.const 0) (local.get $left))
    (call $record_set (local.get $r) (i32.const 1) (local.get $right))
    (local.get $r))

  (func $reason_matchbranch_left (param $r i32) (result i32)
    (call $record_get (local.get $r) (i32.const 0)))

  (func $reason_matchbranch_right (param $r i32) (result i32)
    (call $record_get (local.get $r) (i32.const 1)))

  ;; ─── 228 = ListElement(Reason) ───────────────────────────────────
  (func $reason_make_listelement (param $inner i32) (result i32)
    (local $r i32)
    (local.set $r (call $make_record (i32.const 228) (i32.const 1)))
    (call $record_set (local.get $r) (i32.const 0) (local.get $inner))
    (local.get $r))

  (func $reason_listelement_inner (param $r i32) (result i32)
    (call $record_get (local.get $r) (i32.const 0)))

  ;; ─── 229 = IfBranch(Reason) ──────────────────────────────────────
  (func $reason_make_ifbranch (param $inner i32) (result i32)
    (local $r i32)
    (local.set $r (call $make_record (i32.const 229) (i32.const 1)))
    (call $record_set (local.get $r) (i32.const 0) (local.get $inner))
    (local.get $r))

  (func $reason_ifbranch_inner (param $r i32) (result i32)
    (call $record_get (local.get $r) (i32.const 0)))

  ;; ─── 230 = LetBinding(String, Reason) ────────────────────────────
  (func $reason_make_letbinding (param $name i32) (param $inner i32) (result i32)
    (local $r i32)
    (local.set $r (call $make_record (i32.const 230) (i32.const 2)))
    (call $record_set (local.get $r) (i32.const 0) (local.get $name))
    (call $record_set (local.get $r) (i32.const 1) (local.get $inner))
    (local.get $r))

  (func $reason_letbinding_name (param $r i32) (result i32)
    (call $record_get (local.get $r) (i32.const 0)))

  (func $reason_letbinding_inner (param $r i32) (result i32)
    (call $record_get (local.get $r) (i32.const 1)))

  ;; ─── 231 = Unified(Reason, Reason) ───────────────────────────────
  (func $reason_make_unified (param $left i32) (param $right i32) (result i32)
    (local $r i32)
    (local.set $r (call $make_record (i32.const 231) (i32.const 2)))
    (call $record_set (local.get $r) (i32.const 0) (local.get $left))
    (call $record_set (local.get $r) (i32.const 1) (local.get $right))
    (local.get $r))

  (func $reason_unified_left (param $r i32) (result i32)
    (call $record_get (local.get $r) (i32.const 0)))

  (func $reason_unified_right (param $r i32) (result i32)
    (call $record_get (local.get $r) (i32.const 1)))

  ;; ─── 232 = Instantiation(String, Reason) ─────────────────────────
  (func $reason_make_instantiation (param $name i32) (param $inner i32) (result i32)
    (local $r i32)
    (local.set $r (call $make_record (i32.const 232) (i32.const 2)))
    (call $record_set (local.get $r) (i32.const 0) (local.get $name))
    (call $record_set (local.get $r) (i32.const 1) (local.get $inner))
    (local.get $r))

  (func $reason_instantiation_name (param $r i32) (result i32)
    (call $record_get (local.get $r) (i32.const 0)))

  (func $reason_instantiation_inner (param $r i32) (result i32)
    (call $record_get (local.get $r) (i32.const 1)))

  ;; ─── 233 = UnifyFailed(Ty, Ty) ───────────────────────────────────
  ;; Ty payloads opaque per verify.wat:39 precedent. ty.wat owns the
  ;; structured Ty record shape; this constructor takes whatever ptr
  ;; ty.wat's $ty_make_* returned.
  (func $reason_make_unifyfailed (param $left i32) (param $right i32) (result i32)
    (local $r i32)
    (local.set $r (call $make_record (i32.const 233) (i32.const 2)))
    (call $record_set (local.get $r) (i32.const 0) (local.get $left))
    (call $record_set (local.get $r) (i32.const 1) (local.get $right))
    (local.get $r))

  (func $reason_unifyfailed_left (param $r i32) (result i32)
    (call $record_get (local.get $r) (i32.const 0)))

  (func $reason_unifyfailed_right (param $r i32) (result i32)
    (call $record_get (local.get $r) (i32.const 1)))

  ;; ─── 234 = Placeholder(Span) ─────────────────────────────────────
  ;; Span payload opaque per verify.wat:39 precedent. parser substrate
  ;; (Layer 3 already-landed) owns Span construction.
  (func $reason_make_placeholder (param $span i32) (result i32)
    (local $r i32)
    (local.set $r (call $make_record (i32.const 234) (i32.const 1)))
    (call $record_set (local.get $r) (i32.const 0) (local.get $span))
    (local.get $r))

  (func $reason_placeholder_span (param $r i32) (result i32)
    (call $record_get (local.get $r) (i32.const 0)))

  ;; ─── 235 = BinOpPlaceholder(BinOp) ───────────────────────────────
  ;; BinOp payload opaque per verify.wat:39 precedent. parser substrate
  ;; owns BinOp tag construction (the 14 BAdd..BConcat variants per
  ;; src/types.nx:182).
  (func $reason_make_binopplaceholder (param $op i32) (result i32)
    (local $r i32)
    (local.set $r (call $make_record (i32.const 235) (i32.const 1)))
    (call $record_set (local.get $r) (i32.const 0) (local.get $op))
    (local.get $r))

  (func $reason_binopplaceholder_op (param $r i32) (result i32)
    (call $record_get (local.get $r) (i32.const 0)))

  ;; ─── 236 = MissingVar(String) ────────────────────────────────────
  (func $reason_make_missingvar (param $name i32) (result i32)
    (local $r i32)
    (local.set $r (call $make_record (i32.const 236) (i32.const 1)))
    (call $record_set (local.get $r) (i32.const 0) (local.get $name))
    (local.get $r))

  (func $reason_missingvar_name (param $r i32) (result i32)
    (call $record_get (local.get $r) (i32.const 0)))

  ;; ─── 237 = Refinement(Predicate, Predicate) ──────────────────────
  ;; Predicate payloads opaque per verify.wat:39 precedent. The Verify
  ;; effect's verify_smt swap-handler (B.6 / Arc F.1) walks the
  ;; Predicate ADT structurally; reason.wat just carries the pointers.
  (func $reason_make_refinement (param $left i32) (param $right i32) (result i32)
    (local $r i32)
    (local.set $r (call $make_record (i32.const 237) (i32.const 2)))
    (call $record_set (local.get $r) (i32.const 0) (local.get $left))
    (call $record_set (local.get $r) (i32.const 1) (local.get $right))
    (local.get $r))

  (func $reason_refinement_left (param $r i32) (result i32)
    (call $record_get (local.get $r) (i32.const 0)))

  (func $reason_refinement_right (param $r i32) (result i32)
    (call $record_get (local.get $r) (i32.const 1)))

  ;; ─── 238 = Located(Span, Reason) ─────────────────────────────────
  ;; spec I13 site-annotated reasoning edge.
  (func $reason_make_located (param $span i32) (param $inner i32) (result i32)
    (local $r i32)
    (local.set $r (call $make_record (i32.const 238) (i32.const 2)))
    (call $record_set (local.get $r) (i32.const 0) (local.get $span))
    (call $record_set (local.get $r) (i32.const 1) (local.get $inner))
    (local.get $r))

  (func $reason_located_span (param $r i32) (result i32)
    (call $record_get (local.get $r) (i32.const 0)))

  (func $reason_located_inner (param $r i32) (result i32)
    (call $record_get (local.get $r) (i32.const 1)))

  ;; ─── 239 = InferredCallReturn(String, Reason) ────────────────────
  ;; RX.2 high-intent variant — "return of call to 'process'", not
  ;; "return of process".
  (func $reason_make_inferredcallreturn (param $callee i32) (param $inner i32)
                                          (result i32)
    (local $r i32)
    (local.set $r (call $make_record (i32.const 239) (i32.const 2)))
    (call $record_set (local.get $r) (i32.const 0) (local.get $callee))
    (call $record_set (local.get $r) (i32.const 1) (local.get $inner))
    (local.get $r))

  (func $reason_inferredcallreturn_callee (param $r i32) (result i32)
    (call $record_get (local.get $r) (i32.const 0)))

  (func $reason_inferredcallreturn_inner (param $r i32) (result i32)
    (call $record_get (local.get $r) (i32.const 1)))

  ;; ─── 240 = InferredPipeResult(String, Reason) ────────────────────
  ;; RX.2 high-intent variant — pipe verb identity ("|>", "~>", "<~")
  ;; surfaces in the Why chain.
  (func $reason_make_inferredpiperesult (param $verb i32) (param $inner i32)
                                          (result i32)
    (local $r i32)
    (local.set $r (call $make_record (i32.const 240) (i32.const 2)))
    (call $record_set (local.get $r) (i32.const 0) (local.get $verb))
    (call $record_set (local.get $r) (i32.const 1) (local.get $inner))
    (local.get $r))

  (func $reason_inferredpiperesult_verb (param $r i32) (result i32)
    (call $record_get (local.get $r) (i32.const 0)))

  (func $reason_inferredpiperesult_inner (param $r i32) (result i32)
    (call $record_get (local.get $r) (i32.const 1)))

  ;; ─── 241 = FreshInContext(Int, String) ───────────────────────────
  ;; RX.2 high-intent variant — "fresh in 'process'", not "fresh 42".
  (func $reason_make_freshincontext (param $handle i32) (param $ctx i32)
                                      (result i32)
    (local $r i32)
    (local.set $r (call $make_record (i32.const 241) (i32.const 2)))
    (call $record_set (local.get $r) (i32.const 0) (local.get $handle))
    (call $record_set (local.get $r) (i32.const 1) (local.get $ctx))
    (local.get $r))

  (func $reason_freshincontext_handle (param $r i32) (result i32)
    (call $record_get (local.get $r) (i32.const 0)))

  (func $reason_freshincontext_ctx (param $r i32) (result i32)
    (call $record_get (local.get $r) (i32.const 1)))

  ;; ─── 242 = DocstringReason(String, Span) ─────────────────────────
  ;; DS.1 — authored /// docstring as intent edge.
  (func $reason_make_docstringreason (param $doc i32) (param $span i32)
                                       (result i32)
    (local $r i32)
    (local.set $r (call $make_record (i32.const 242) (i32.const 2)))
    (call $record_set (local.get $r) (i32.const 0) (local.get $doc))
    (call $record_set (local.get $r) (i32.const 1) (local.get $span))
    (local.get $r))

  (func $reason_docstringreason_doc (param $r i32) (result i32)
    (call $record_get (local.get $r) (i32.const 0)))

  (func $reason_docstringreason_span (param $r i32) (result i32)
    (call $record_get (local.get $r) (i32.const 1)))
