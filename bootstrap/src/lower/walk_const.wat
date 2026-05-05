  ;; ═══ walk_const.wat — literal + var-ref arm bodies (Tier 7) ════════════
  ;; Hβ.lower cascade chunk #6 of 11 per Hβ-lower-substrate.md §12.3 dep order.
  ;;
  ;; What this chunk IS (per Hβ-lower-substrate.md §4.1 + §4.2 + §6.3 + §11):
  ;;   Six per-variant arm bodies for the six leaf Expr tags (80-85):
  ;;     80 = LitInt    → LConst(handle, value)       tag 300
  ;;     81 = LitFloat  → LConst(handle, raw_f32)     tag 300
  ;;     82 = LitString → LConst(handle, str_ptr)     tag 300
  ;;     83 = LitBool   → LMakeVariant(handle, b, []) tag 319  (HB drift-6 closure)
  ;;     84 = LitUnit   → LConst(handle, 0)           tag 300
  ;;     85 = VarRef    → LLocal/LUpval/LGlobal triage per Lock #2
  ;;   Plus one chunk-private helper $walk_const_payload_i32 that reads the
  ;;   raw i32 from the AST body at offset 4 (the "body payload").
  ;;
  ;; The dispatcher ($lower_expr over Expr tags 80-101) lands at chunk #11
  ;; main.wat — this chunk ONLY owns the per-variant arm bodies.
  ;;
  ;; Wheel canonical: src/lower.nx lines 296-339 (lower_expr + lower_expr_body
  ;; literal + VarRef arms), 309-315 (LitBool → LMakeVariant per HB),
  ;; 318-339 (VarRef → RLocal/RUpval/RGlobal triage), 96-150 (LowExpr ADT).
  ;;
  ;; Six Locks (plan §2 — override walkthrough §4.2 prose where it conflicts):
  ;;   Lock #1  LLocal field 0 IS local_h (BINDING-SITE handle from LOCAL_ENTRY
  ;;            field 2), NOT the VarRef's own AST handle.
  ;;   Lock #2  $ls_lookup_local first; then $ls_lookup_or_capture; -1 = global.
  ;;            EXTENDED by Lock #2.0 (Hβ.first-light.nullary-ctor-call-context):
  ;;            $env_binding_kind ConstructorScheme + nullary scheme Ty
  ;;            short-circuits to LMakeVariant(h, tag_id, []) BEFORE local
  ;;            triage. Wheel parity src/lower.nx:333-337.
  ;;   Lock #3  LitBool → LMakeVariant(h, b, []) — NOT $lexpr_make_lconst.
  ;;   Lock #4  LowValue is opaque i32; no LowValue wrapper today.
  ;;   Lock #5  LitFloat/LitUnit arms land this commit; harnesses deferred to
  ;;            named follow-up Hβ.lower.litfloat-litunit-harness.
  ;;   Lock #6  (Hβ.first-light.nullary-ctor-call-context) Env SchemeKind
  ;;            dispatch wins over local shadow — wheel divergence is
  ;;            intentional. Future shadow-discipline ADT lands as named
  ;;            follow-up Hβ.lower.ctor-shadow-discipline if surfaces.
  ;;
  ;; Exports:  $lower_lit_int $lower_lit_float $lower_lit_string
  ;;           $lower_lit_bool $lower_lit_unit $lower_var_ref
  ;;           $walk_const_payload_i32
  ;; Uses:     $walk_expr_node_handle (infer/walk_expr.wat:304-307 — cross-layer
  ;;             reuse; DO NOT redefine),
  ;;           $lexpr_make_lconst $lexpr_make_lmakevariant $lexpr_make_llocal
  ;;             $lexpr_make_lupval $lexpr_make_lglobal (lower/lexpr.wat),
  ;;           $ls_lookup_local $ls_lookup_or_capture (lower/state.wat),
  ;;           $lower_locals_ptr (lower/state.wat global — direct read per Lock #2;
  ;;             named follow-up Hβ.lower.state-entry-accessor for future factor),
  ;;           $list_index $record_get (runtime/list.wat + runtime/record.wat),
  ;;           $make_list (runtime/list.wat — empty args list for LMakeVariant),
  ;;           $env_lookup $env_binding_kind $env_binding_scheme (runtime/env.wat —
  ;;             cross-layer reuse for SchemeKind dispatch per Lock #6),
  ;;           $schemekind_tag $schemekind_ctor_tag_id (runtime/env.wat —
  ;;             ConstructorScheme tag is 132; tag_id field is record offset 0),
  ;;           $scheme_body (infer/scheme.wat — Forall body Ty accessor),
  ;;           $ty_tag (infer/ty.wat — TName tag 108 nullary discriminator vs
  ;;             TFun tag 107 N-ary)
  ;; Test:     bootstrap/test/lower/walk_const_lit_int.wat
  ;;           bootstrap/test/lower/walk_const_var_ref_local.wat
  ;;           bootstrap/test/lower/walk_const_var_ref_global.wat
  ;;
  ;; ═══ EIGHT INTERROGATIONS (per Hβ-lower-substrate.md §5 projected
  ;;                            onto walk_const.wat) ══════════════════════
  ;;
  ;; 1. Graph?       Each arm reads $walk_expr_node_handle(node) — the handle
  ;;                 at offset 12 of the N-wrapper (parser_infra.wat:32-39
  ;;                 layout: [tag=0][body][span][handle]). This IS the source
  ;;                 TypeHandle from the inference pass; it is the live bridge
  ;;                 that $lookup_ty (chunk #2 lookup.wat) walks back to
  ;;                 $graph_chase. No graph mutation; walk_const is read-only
  ;;                 on the graph per spec 05 §The LookupTy effect.
  ;;
  ;; 2. Handler?     Wheel: lower_expr_body participates in LookupTy +
  ;;                 LowerCtx + Diagnostic effect chain @resume=OneShot (one
  ;;                 call per Expr node, scalar LowExpr return). Seed: six
  ;;                 direct functions. LowerCtx state accessed via state.wat
  ;;                 globals ($lower_locals_ptr, $lower_locals_len_g).
  ;;                 NO vtable. NO dispatch_table. NO _lookup_handler_for_op.
  ;;
  ;; 3. Verb?        N/A — literals + var-refs are leaf positions. Verb arms
  ;;                 ($lower_pipe for ~> / <~) land at chunk #8 walk_handle.
  ;;
  ;; 4. Row?         N/A — literals carry no effect row. VarRef's row-ground
  ;;                 gate ($monomorphic_at) lives at chunk #7 walk_call's
  ;;                 call-site dispatch decision. Per Hβ-lower-substrate.md
  ;;                 §3.2 last paragraph: row-monomorphism and resume-discipline
  ;;                 are orthogonal axes; walk_const is silent on both.
  ;;
  ;; 5. Ownership?   Each $lexpr_make_* produces a fresh `own` record from the
  ;;                 bump allocator. $ls_lookup_or_capture's side effect of
  ;;                 recording CAPTURE_ENTRYs in $lower_captures_ptr IS the
  ;;                 ownership trace for captured names. Inputs ($node) are
  ;;                 `ref` (caller retains); outputs are `own`.
  ;;
  ;; 6. Refinement?  Transparent. TRefined wrappers pass through $lookup_ty
  ;;                 verbatim; no predicate-check happens at walk_const.
  ;;
  ;; 7. Gradient?    LitBool → LMakeVariant proves nullary-ADT compilation
  ;;                 discipline per HB (drift-mode-6 closure: Bool is not
  ;;                 "special because small"). VarRef's RLocal/RUpval/RGlobal
  ;;                 triage IS the gradient cash-out: each branch cashes one
  ;;                 inference-earned scope-resolution win. VarRef → LLocal
  ;;                 when a binding exists at BIND time (not at use time) —
  ;;                 Lock #1 makes this explicit.
  ;;
  ;; 8. Reason?      Read-only. Each LowExpr field 0 carries the GNode's
  ;;                 TypeHandle whose Reason chain $gnode_reason walks back.
  ;;                 walk_const does not write any Reason edges.
  ;;
  ;; ═══ FORBIDDEN PATTERNS AUDIT (per Hβ-lower-substrate.md §6 +
  ;;                                project-wide drift modes 1-9) ════════
  ;;
  ;; - Drift 1 (Rust vtable):       No dispatch_table. Six named direct
  ;;                                (func)s. Dispatcher lives at chunk #11.
  ;;                                "vtable" never appears in any arm.
  ;;
  ;; - Drift 2 (Scheme env-frame):  state.wat's locals ledger is a single
  ;;                                flat list — NOT a frame stack. $ls_lookup_local
  ;;                                walks the flat list end-to-start. This chunk
  ;;                                does NOT iterate a frame stack.
  ;;
  ;; - Drift 4 (monad transformer): No LowerM. Each arm is a direct (func);
  ;;                                single $node i32 input, single i32 LowExpr
  ;;                                output. No threading of LowerCtx struct.
  ;;
  ;; - Drift 5 (C calling conv):    Single $node parameter per arm; single
  ;;                                i32 return. No __closure/__ev split.
  ;;
  ;; - Drift 6 (primitive-special): LitBool MUST route through LMakeVariant
  ;;                                per Lock #3. Bool is NOT special because
  ;;                                small — same nullary-ADT discipline as
  ;;                                every other nullary constructor per HB.
  ;;
  ;; - Drift 7 (parallel-arrays):   Each LowExpr is ONE record. No per-field
  ;;                                parallel globals.
  ;;
  ;; - Drift 8 (string-keyed):      Tag-int dispatch only. No "VarRef" string
  ;;                                comparisons in dispatch; no "local"/"global"
  ;;                                string-keyed arm selection.
  ;;
  ;; - Drift 9 (deferred-by-omission): ALL SIX ARMS land this commit, fully
  ;;                                bodied. LitFloat and LitUnit arms land even
  ;;                                though harnesses are deferred (named follow-up
  ;;                                Hβ.lower.litfloat-litunit-harness per Lock #5).
  ;;                                No "pending" placeholder arms.
  ;;
  ;; - Foreign fluency — LLVM/GHC:  NO "constant folding", NO "literal pool",
  ;;                                NO "SSA value". Vocabulary stays Inka.
  ;;
  ;; Named follow-ups (per Drift 9 + Hβ-lower-substrate.md §11):
  ;;
  ;;   - Hβ.lower.lvalue-lowfn-lpat-substrate:
  ;;                              LowValue (LConst field 1) is opaque i32
  ;;                              here. Lands when first walker needs
  ;;                              structural access to LowValue variants.
  ;;
  ;;   - Hβ.lower.upval-handle-resolution:
  ;;                              LUpval's handle field uses the VarRef's
  ;;                              own AST handle ($walk_expr_node_handle)
  ;;                              as a seed-honest fallback. The wheel's
  ;;                              RUpval arm uses the CLOSURE binding-time
  ;;                              handle. Lands when walk_handle.wat's
  ;;                              LMakeClosure population wires the
  ;;                              capture-index → binding-site handle map.
  ;;
  ;;   - Hβ.lower.varref-schemekind-dispatch: LANDED (Hβ.first-light.nullary-
  ;;                              ctor-call-context). $lower_var_ref dispatches
  ;;                              env-binding SchemeKind FIRST: nullary
  ;;                              ConstructorScheme → LMakeVariant(h, tag_id, [])
  ;;                              short-circuit (matches wheel src/lower.nx:
  ;;                              333-337 RGlobal-with-ConstructorScheme arm).
  ;;                              N-ary ctor + EffectOpScheme dispatch named
  ;;                              as peer follow-up Hβ.lower.unsaturated-ctor /
  ;;                              Hβ.lower.varref-effectop-dispatch.
  ;;
  ;;   - Hβ.lower.state-entry-accessor:
  ;;                              $ls_local_entry_at(slot) factor when the
  ;;                              third caller earns the abstraction per
  ;;                              Anchor 7 "three instances".
  ;;
  ;;   - Hβ.lower.litfloat-litunit-harness:
  ;;                              LitFloat/LitUnit arms land this commit
  ;;                              (Lock #5 drift-9 closure) but harnesses
  ;;                              are deferred until $mk_LitFloat /
  ;;                              $mk_LitUnit builders exist in
  ;;                              parser_infra.wat. Lands when parser
  ;;                              substrate firms those two constructors.
  ;;
  ;;   - Hβ.lower.walk_const-lupval-harness:
  ;;                              LUpval arm coverage deferred to when
  ;;                              chunk #8 walk_handle.wat composition
  ;;                              permits synthetic closure construction
  ;;                              in a harness without env_extend.

  ;; ─── $walk_const_payload_i32 — read AST body payload at offset 4 ─────
  ;; Chunk-private helper. Navigation:
  ;;   $node  = N-wrapper  [tag=0][body][span][handle]  (16 bytes)
  ;;   offset=4 → $nexpr  = NExpr-wrapper [tag=110][e]  (8 bytes)
  ;;   offset=4 → $expr   = Expr node     [tag=80..85][payload] (8 bytes)
  ;;   offset=4 → the raw i32 payload (int value / float bits / str ptr / bool flag / name ptr)
  ;;
  ;; Per parser_infra.wat:32-39 ($mk_node layout) + $mk_NExpr layout +
  ;; $mk_LitInt/$mk_VarRef/etc. all store payload at offset=4.
  ;; Avoids Drift 2 (no frame-stack walk) — direct offset arithmetic only.
  (func $walk_const_payload_i32 (param $node i32) (result i32)
    (local $nexpr i32)
    (local $expr i32)
    (local.set $nexpr (i32.load offset=4 (local.get $node)))
    (local.set $expr  (i32.load offset=4 (local.get $nexpr)))
    (i32.load offset=4 (local.get $expr)))

  ;; ─── $lower_lit_int — tag 80 → LConst(handle, value) tag 300 ─────────
  ;; Per src/lower.nx:296-307 lower_expr_body LitInt arm + Lock #4 (LowValue
  ;; is opaque i32 today — the raw integer is passed through directly to
  ;; LConst field 1). Avoids Drift 6 (no special-case for int vs other lit).
  (func $lower_lit_int (export "lower_lit_int") (param $node i32) (result i32)
    ;; Avoids Drift 1: direct call, no dispatch table.
    ;; Avoids Drift 9: fully bodied, not a stub.
    (call $lexpr_make_lconst
      (call $walk_expr_node_handle (local.get $node))
      (call $walk_const_payload_i32 (local.get $node))))

  ;; ─── $lower_lit_float — tag 81 → LConst(handle, raw_f32_bits) tag 300 ─
  ;; Per src/lower.nx:296-307 lower_expr_body literal fallthrough +
  ;; Lock #4 (LowValue opaque i32). Identical body to $lower_lit_int;
  ;; variant distinction handled by chunk #11's tag-80 vs tag-81 dispatch.
  ;; Avoids Lock #5 drift-9: arm lands even without a harness today
  ;; (named follow-up Hβ.lower.litfloat-litunit-harness).
  (func $lower_lit_float (export "lower_lit_float") (param $node i32) (result i32)
    (call $lexpr_make_lconst
      (call $walk_expr_node_handle (local.get $node))
      (call $walk_const_payload_i32 (local.get $node))))

  ;; ─── $lower_lit_string — tag 82 → LConst(handle, str_ptr) tag 300 ─────
  ;; Per src/lower.nx:296-307 lower_expr_body + Lock #4. str_ptr from the
  ;; AST payload is passed as the LConst value field directly.
  ;; Avoids Drift 8: no string-keyed dispatch here — tag-82 at chunk #11.
  (func $lower_lit_string (export "lower_lit_string") (param $node i32) (result i32)
    (call $lexpr_make_lconst
      (call $walk_expr_node_handle (local.get $node))
      (call $walk_const_payload_i32 (local.get $node))))

  ;; ─── $lower_lit_bool — tag 83 → LMakeVariant(handle, b, []) tag 319 ───
  ;; Per src/lower.nx:309-315 LitBool arm + Lock #3 (HB drift-6 closure).
  ;; LitBool(b) → LMakeVariant(handle, tag=b, args=[]) where b is 0 (False)
  ;; or 1 (True). The AST payload IS the tag_id (0 or 1); passed directly
  ;; to $lexpr_make_lmakevariant field 1.
  ;;
  ;; MUST route through $lexpr_make_lmakevariant, NOT $lexpr_make_lconst.
  ;; Bool is not "special because small" — same nullary-ADT compilation
  ;; discipline as every other nullary constructor (HB substrate).
  ;; Avoids Drift 6: no primitive-special-case carveout for LitBool.
  (func $lower_lit_bool (export "lower_lit_bool") (param $node i32) (result i32)
    ;; Avoids Drift 6: LMakeVariant not LConst.
    ;; Avoids Drift 9: fully bodied per Lock #3.
    (call $lexpr_make_lmakevariant
      (call $walk_expr_node_handle (local.get $node))
      (call $walk_const_payload_i32 (local.get $node))    ;; AST b 0/1 IS the tag_id
      (call $make_list (i32.const 0))))                    ;; empty args list

  ;; ─── $lower_lit_unit — tag 84 → LConst(handle, 0) tag 300 ──────────────
  ;; Per src/lower.nx:296-307 + Lock #4 + Lock #5. Unit sentinel 0 is in
  ;; [0, HEAP_BASE) — the standard nullary-sentinel discipline (same as
  ;; TInt/TFloat at ty.wat:100-101). Passed as opaque i32 directly.
  ;; Arm lands this commit; harness deferred to Hβ.lower.litfloat-litunit-harness.
  ;; Avoids Drift 9: arm is fully bodied (not a stub), even without a harness.
  (func $lower_lit_unit (export "lower_lit_unit") (param $node i32) (result i32)
    (call $lexpr_make_lconst
      (call $walk_expr_node_handle (local.get $node))
      (i32.const 0)))    ;; unit sentinel — zero in [0, HEAP_BASE)

  ;; ─── $lower_var_ref — tag 85 → LLocal/LUpval/LGlobal triage ────────────
  ;; Per src/lower.nx:318-339 VarRef arm + Locks #1 + #2.
  ;;
  ;; Discrimination order (Lock #2):
  ;;   1. $ls_lookup_local(name): >= 0 → local slot; emit LLocal(local_h, name)
  ;;      where local_h is CAPTURE_ENTRY field 2 (ty_handle from bind site) per
  ;;      Lock #1 — NOT the VarRef's own AST handle.
  ;;   2. $ls_lookup_or_capture(name): >= 0 → capture index; emit LUpval(h, cap_idx)
  ;;      using VarRef's AST handle as seed fallback (named follow-up
  ;;      Hβ.lower.upval-handle-resolution).
  ;;   3. -1 from both → global; emit LGlobal(h, name).
  ;;
  ;; Lock #1 detail: $ls_bind_local stores (name, slot, ty_handle) as a
  ;; LOCAL_ENTRY record (tag 280) at arity-3. Field 2 = ty_handle from the
  ;; BINDING SITE. This is what LLocal field 0 must carry (the binding-time
  ;; TypeHandle, not the VarRef's fresh AST handle).
  ;;
  ;; Avoids Drift 2: no frame-stack walk — $lower_locals_ptr is a flat list.
  ;; Avoids Drift 8: name is a string ptr (i32) threaded opaque, never compared
  ;;   with string literals in dispatch logic here.
  (func $lower_var_ref (export "lower_var_ref") (param $node i32) (result i32)
    (local $name i32)
    (local $h i32)
    (local $local_slot i32)
    (local $cap_idx i32)
    (local $entry i32)
    (local $local_h i32)
    (local $binding i32)
    (local $kind i32)
    (local $scheme i32)
    (local $ctor_ty i32)
    (local $ctor_ty_tag i32)
    (local $tag_id i32)
    ;; Extract name (VarRef payload) and h (VarRef's own AST handle).
    (local.set $name (call $walk_const_payload_i32 (local.get $node)))
    (local.set $h    (call $walk_expr_node_handle  (local.get $node)))
    ;; Lock #2.0 (Hβ.first-light.nullary-ctor-call-context): env-binding
    ;; SchemeKind dispatch FIRST. Nullary ConstructorScheme short-circuits
    ;; to LMakeVariant(h, tag_id, []) per wheel src/lower.nx:333-337.
    ;; Nullary detection: ctor's scheme body Ty is TName(_, []) (tag 108) —
    ;; N-ary ctor schemes are TFun (tag 107) per walk_stmt.wat:847-860.
    ;; Avoids Drift 6 (Bool not special — Bool's True/False register as
    ;; ConstructorScheme(0,2)/(1,2) and flow through this same arm because
    ;; their scheme bodies are TName("Bool", [])).
    (local.set $binding (call $env_lookup (local.get $name)))
    (if (i32.ne (local.get $binding) (i32.const 0))
      (then
        (local.set $kind (call $env_binding_kind (local.get $binding)))
        (if (i32.eq (call $schemekind_tag (local.get $kind)) (i32.const 132))
          (then
            (local.set $scheme (call $env_binding_scheme (local.get $binding)))
            (local.set $ctor_ty (call $scheme_body (local.get $scheme)))
            (local.set $ctor_ty_tag (call $ty_tag (local.get $ctor_ty)))
            (if (i32.eq (local.get $ctor_ty_tag) (i32.const 108))
              (then
                (local.set $tag_id (call $schemekind_ctor_tag_id (local.get $kind)))
                (return (call $lexpr_make_lmakevariant
                  (local.get $h)
                  (local.get $tag_id)
                  (call $make_list (i32.const 0))))))))))
    ;; Lock #2 step 1: try locals first.
    (local.set $local_slot (call $ls_lookup_local (local.get $name)))
    (if (i32.ge_s (local.get $local_slot) (i32.const 0))
      (then
        ;; Local found. Lock #1: local_h from LOCAL_ENTRY field 2 (ty_handle),
        ;; NOT from the VarRef's AST handle $h.
        (local.set $entry
          (call $list_index
            (global.get $lower_locals_ptr)
            (local.get $local_slot)))
        (local.set $local_h (call $record_get (local.get $entry) (i32.const 2)))
        (return (call $lexpr_make_llocal (local.get $local_h) (local.get $name)))))
    ;; Lock #2 step 2: try capture / outer-scope lookup.
    ;; $ls_lookup_or_capture returns >= 0 if name is a captured upvalue, else -1.
    (local.set $cap_idx (call $ls_lookup_or_capture (local.get $name)))
    (if (i32.ge_s (local.get $cap_idx) (i32.const 0))
      (then
        ;; Capture found. Use VarRef's own AST handle as seed-honest fallback
        ;; for LUpval field 0 (named follow-up Hβ.lower.upval-handle-resolution).
        (return (call $lexpr_make_lupval (local.get $h) (local.get $cap_idx)))))
    ;; Lock #2 step 3: neither local nor capture → global.
    (call $lexpr_make_lglobal (local.get $h) (local.get $name)))
