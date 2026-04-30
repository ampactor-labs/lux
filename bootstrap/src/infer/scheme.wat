  ;; ═══ scheme.wat — Forall + instantiate + generalize (Tier 5) ═════
  ;; Implements: Hβ-infer-substrate.md §2 (Scheme substrate; extended
  ;;             commits `38b0075` for reason gap-find + `17205e9` for
  ;;             14th Ty variant TAlias + ResumeDiscipline relocation
  ;;             220→250) + §2.4 ($generalize algorithm) + §2.3
  ;;             ($instantiate over Ty tag conventions) + §8.1 scheme.wat
  ;;             row + §8.4 ~250-line estimate (lands higher per the
  ;;             per-chunk pattern + 14-variant exhaustive walker
  ;;             coverage). Realizes the let-generalization layer of
  ;;             primitive #8 (HM inference) at the seed substrate:
  ;;             every $env_extend at FnStmt exit carries a Forall
  ;;             this chunk constructs; every VarRef instantiates one
  ;;             through this chunk's $instantiate.
  ;;
  ;; Exports:    $scheme_make_forall / $scheme_quantified / $scheme_body /
  ;;               $is_scheme,
  ;;             $instantiate,
  ;;             $generalize,
  ;;             $free_in_ty,
  ;;             $ty_substitute,
  ;;             $subst_map_make / $subst_map_extend /
  ;;               $subst_map_lookup,
  ;;             $list_concat,
  ;;             $free_in_params / $free_in_fields,
  ;;             $ty_substitute_params / $ty_substitute_fields
  ;; Uses:       $make_record / $record_get / $record_set / $tag_of
  ;;               (record.wat),
  ;;             $make_list / $list_index / $list_set / $list_extend_to /
  ;;               $len (list.wat),
  ;;             $graph_chase / $gnode_kind / $gnode_reason /
  ;;               $node_kind_tag / $node_kind_payload / $is_nbound /
  ;;               $is_nfree (graph.wat),
  ;;             $ty_tag / $ty_make_tvar / $ty_tvar_handle /
  ;;               $ty_make_tlist / $ty_tlist_elem /
  ;;               $ty_make_ttuple / $ty_ttuple_elems /
  ;;               $ty_make_tfun / $ty_tfun_params / $ty_tfun_return /
  ;;               $ty_tfun_row /
  ;;               $ty_make_tname / $ty_tname_name / $ty_tname_args /
  ;;               $ty_make_trecord / $ty_trecord_fields /
  ;;               $ty_make_trecordopen / $ty_trecordopen_fields /
  ;;               $ty_trecordopen_rowvar /
  ;;               $ty_make_trefined / $ty_trefined_base /
  ;;               $ty_trefined_pred /
  ;;               $ty_make_tcont / $ty_tcont_return /
  ;;               $ty_tcont_discipline /
  ;;               $ty_make_talias / $ty_talias_name /
  ;;               $ty_talias_resolved (ty.wat),
  ;;             $tparam_make / $tparam_name / $tparam_ty /
  ;;               $tparam_authored / $tparam_resolved (tparam.wat —
  ;;               for $ty_substitute_params rebuild),
  ;;             $field_pair_make / $field_pair_name / $field_pair_ty
  ;;               (tparam.wat — for $ty_substitute_fields rebuild),
  ;;             $reason_make_instantiation / $reason_make_fresh
  ;;               (reason.wat — for $instantiate's per-quantified-slot
  ;;               Reason and the inner Fresh(handle) wrap),
  ;;             $graph_fresh_ty (graph.wat — for fresh-handle minting
  ;;               at each instantiation site)
  ;; Test:       runtime_test/infer_scheme.wat (pending — first
  ;;             acceptance is $scheme_*-grep + wasm-validate per
  ;;             Hβ-infer-substrate.md §11)
  ;;
  ;; ═══ DESIGN ═══════════════════════════════════════════════════════
  ;;
  ;; Per spec 04 (04-inference.md §Env+Scheme + §Generalizations +
  ;; §Instantiations) + Hβ-infer-substrate.md §2 + src/types.nx
  ;; canonical Scheme ADT (line 78-79: `Scheme = Forall(List, Ty)`) +
  ;; src/infer.nx canonical algorithms (generalize 1818-1834,
  ;; chase_deep 1841-1867, free_in_ty 1891-1924, instantiate 1931-1998).
  ;;
  ;; What schemes ARE (per spec 04 + src/types.nx:74-79):
  ;;   `Forall(quantified_handles, body_type)`. A monomorphic binding
  ;;   is `Forall([], ty)`. env_lookup returns Option<(Scheme, Reason)>;
  ;;   FnStmt exit generalizes the inferred body type into a Scheme +
  ;;   stores under the fn name; every VarRef reads the Scheme back +
  ;;   instantiates (mints fresh handles per quantified slot, walks
  ;;   the body substituting old→fresh).
  ;;
  ;; What this chunk produces:
  ;;   - $scheme_make_forall(qs, body) — record(SCHEME_TAG=200, arity=2).
  ;;   - $instantiate(scheme) — walks body, replaces TVar(q) with
  ;;     TVar(fresh_handle) per a substitution map built once per call.
  ;;     Per src/infer.nx:1931-1938 + spec 04 §Instantiations.
  ;;   - $generalize(fn_handle) — chases the handle through the graph,
  ;;     dispatches on NodeKind. NBound → walk Ty to collect free
  ;;     handles, wrap as Forall(body_free, body_ty). Non-NBound →
  ;;     monotype Forall([], TVar(handle)). Per src/infer.nx:1818-1834.
  ;;   - $free_in_ty(ty) — recursive walker collecting handles
  ;;     reachable via TVar variants. Per src/infer.nx:1891-1924.
  ;;   - $ty_substitute(ty, map) — recursive walker rewriting TVar(q)
  ;;     to TVar(map[q]) where map.contains(q). Per src/infer.nx:1951-
  ;;     1973 (subst_ty). Other variants pass through unchanged or
  ;;     recurse on sub-types per the 14-variant Ty ADT.
  ;;
  ;; Substitution-map shape (per Hβ-infer §2.3 + drift mode 7 audit):
  ;;   Flat list of 2-field records `SUBST_PAIR_TAG=201` where
  ;;     field_0 = old handle (i32; from Forall's quantified list)
  ;;     field_1 = fresh handle (i32; minted via $graph_fresh_ty)
  ;;   This is record-shape, NOT parallel arrays — single list, each
  ;;   entry one record. Per drift-mode-7 audit + γ insight #9
  ;;   "records are the handler-state shape." Linear-scan lookup is
  ;;   fine at the typical per-scheme quantification count (0-3 per
  ;;   src/infer.nx evidence — `fn id(x) = x` is 1; most fns are
  ;;   monomorphic Forall([], _)).
  ;;
  ;; $generalize seed-tier-base (per Hβ-infer §2.4 + canonical wheel):
  ;;   The walkthrough §2.4 names an aspirational algorithm involving
  ;;   $set_diff(body_free, env_free). The canonical wheel
  ;;   (src/infer.nx:1818-1834) does NOT compute env_free — line 1825-
  ;;   1827 says "env_free_vars is optional — if unavailable, treat as
  ;;   empty. Conservatively: quantify all body-free handles."
  ;;
  ;;   Per Anchor 4 (build the wheel; never wrap the axle) + Anchor 0
  ;;   (dream code; each file assumes every other is perfect): this
  ;;   chunk implements the wheel's reduced form. Quantifying all
  ;;   body_free is sound (over-generalization at worst yields a
  ;;   broader Forall the env can still satisfy; spec 04 §Generalizations
  ;;   accepts this as the Damas-Milner fallback).
  ;;
  ;;   The aspirational $set_diff form lands when env iteration becomes
  ;;   needed by other surfaces (e.g., better diagnostic precision on
  ;;   "this var was generalized over a free env handle"). That's a
  ;;   named follow-up alongside an `$env_for_each_binding` primitive.
  ;;   The (scheme, reason) two-arg form Hβ-infer §4.2 named is now
  ;;   superseded — env.wat's $env_extend takes the canonical four-
  ;;   tuple directly per ROADMAP item 1 (name, Scheme, Reason,
  ;;   SchemeKind); see env.wat HEAP RECORD LAYOUTS comment.
  ;;
  ;;   Per H6 wildcard discipline: $generalize dispatches explicitly on
  ;;   ALL 5 NodeKind variants (NBOUND/NFREE/NROWBOUND/NROWFREE/
  ;;   NERRORHOLE — per src/infer.nx:1822-1832 same shape). No `_ =>`
  ;;   silent fallback that fabricates a monotype.
  ;;
  ;; TParam + TRecord recursion parity (closed 2026-04-26 per ROADMAP §3
  ;; + tparam.wat sibling chunk landing):
  ;;   Earlier draft of this chunk treated TFun's params + TRecord/
  ;;   TRecordOpen's fields as opaque, matching ty.wat's $chase_deep
  ;;   precedent. ROADMAP §3 surfaced this as a load-bearing recursion-
  ;;   parity gap: canonical src/infer.nx:1898 (free_in_params) +
  ;;   src/infer.nx:1900-1901 (free_in_fields) + src/infer.nx:1961-1962
  ;;   (subst_params) + src/infer.nx:1967-1968 (subst_fields) DO recurse
  ;;   through these list shapes. Without parity, `fn id(x: a) = x`
  ;;   generalizes wrong (param's TVar handle missed in body_free) and
  ;;   instantiated polymorphic record-shaped types lose substitution
  ;;   on their fields.
  ;;
  ;;   Resolution: tparam.wat sibling chunk (tag 202 TParam + tag 203
  ;;   field-pair + tags 260-262 Ownership) lands the substrate; this
  ;;   chunk's $free_in_ty / $ty_substitute extend their TFun + TRecord
  ;;   + TRecordOpen arms to recurse via $free_in_params / $free_in_fields
  ;;   / $ty_substitute_params / $ty_substitute_fields. Coverage now
  ;;   matches src/infer.nx:1890-1990 exactly.
  ;;
  ;;   ty.wat's $chase_deep is a separate substrate concern (ROADMAP §3
  ;;   acceptance scope is scheme.wat's $free_in_ty + $ty_substitute);
  ;;   $chase_deep recursion-parity extension is a named peer follow-up
  ;;   alongside the TFun-row chase (which row.wat owns).
  ;;
  ;; ═══ TAG REGION ═══════════════════════════════════════════════════
  ;;
  ;; Per Hβ-infer-substrate.md §2.1 + audit at acceptance criterion +
  ;; ROADMAP §3 recursion-parity substrate-gap closure (2026-04-26 —
  ;; tparam.wat sibling chunk lands TParam + field-pair + Ownership):
  ;;
  ;;   200    SCHEME_TAG               (this chunk — Forall record)
  ;;   201    SUBST_PAIR_TAG           (this chunk — (old, fresh) entry)
  ;;   202    TPARAM_TAG               (tparam.wat — TParam record arity 4)
  ;;   203    FIELD_PAIR_TAG           (tparam.wat — (name, Ty) record arity 2)
  ;;   204-209 reserved future infer non-Reason private records
  ;;
  ;; Verified non-colliding (per Hβ-infer §2.1 + state.wat / ty.wat /
  ;; tparam.wat / reason.wat / runtime substrate sweep):
  ;;   0-44       TokenKind sentinels (lexer.wat)
  ;;   50-99      graph.wat (NodeKind 60-64, GNode 80, Mutation 70-72)
  ;;   100-113    Ty variants (ty.wat — 14 variants + reserved 114-119)
  ;;   130-149    env.wat (ENV_BINDING_TAG=130 + reserved)
  ;;   150-179    row.wat
  ;;   180-199    verify.wat (VerifyObligation 180)
  ;;   200        SCHEME_TAG (this chunk)
  ;;   201        SUBST_PAIR_TAG (this chunk)
  ;;   202        TPARAM_TAG (tparam.wat)
  ;;   203        FIELD_PAIR_TAG (tparam.wat)
  ;;   204-209    reserved future infer non-Reason private
  ;;   210-212    state.wat (REF_ESCAPE_ENTRY / SPAN_INDEX_ENTRY /
  ;;              INTENT_INDEX_ENTRY)
  ;;   213-219    reserved
  ;;   220-242    reason.wat Reason variants (23)
  ;;   243-249    reserved future Reason
  ;;   250-252    ResumeDiscipline (ty.wat)
  ;;   253-259    reserved future ResumeDiscipline
  ;;   260-262    Ownership (tparam.wat — Inferred / Own / Ref)
  ;;   263-269    reserved future Ownership
  ;;   300-349    LowExpr (lower.wat — pending; per Hβ-lower §2)
  ;;
  ;; ═══ EIGHT INTERROGATIONS (per Hβ-infer-substrate.md §6.1) ═══════
  ;;
  ;; 1. Graph?      Schemes hold quantified graph handles + body Ty
  ;;                that references handles via TVar; $instantiate
  ;;                calls $graph_fresh_ty per quantified slot to mint
  ;;                a new handle; $generalize calls $graph_chase to
  ;;                read the inferred type back; $free_in_ty walks Ty
  ;;                + collects every TVar's handle (the graph IS the
  ;;                substrate; this chunk reads through it).
  ;; 2. Handler?    Direct functions at the seed level (passive data
  ;;                + algorithmic walks). The wheel's compiled form
  ;;                routes $instantiate through the FreshHandle effect
  ;;                (spec 04 §Instantiations + spec 06) — one function,
  ;;                two handlers (inference: mint via graph_fresh_ty;
  ;;                query: mint via display-id counter). Seed has only
  ;;                the inference handler — direct $graph_fresh_ty.
  ;;                @resume=OneShot per FreshHandle's typed discipline.
  ;; 3. Verb?       N/A at substrate level — $instantiate / $generalize
  ;;                are direct walkers, not pipelines.
  ;; 4. Row?        $generalize ideally quantifies BOTH type AND row
  ;;                free handles per spec 04 §Generalizations. This
  ;;                Tier-5 base focuses on type-handle quantification
  ;;                via $free_in_ty; row-handle quantification awaits
  ;;                row.wat's $row_substitute extension (Hβ-infer
  ;;                §12 named follow-up "Hβ.infer.row-normalize"). Per
  ;;                drift mode 9 surface: the type-side lands here;
  ;;                the row-side becomes the named follow-up handle
  ;;                rather than buried-in-this-commit silent gap.
  ;; 5. Ownership?  Schemes are reference-counted-once — $instantiate
  ;;                walks but doesn't deep-clone (rebuilds Ty records
  ;;                only at substitution sites; sub-Ty pointers
  ;;                preserved verbatim where unchanged). $generalize
  ;;                returns own Forall record; body_ty borrowed from
  ;;                the chased graph node.
  ;; 6. Refinement? TRefined(base, pred) inside scheme.body propagates
  ;;                through $instantiate — $ty_substitute on TRefined
  ;;                walks base + preserves pred ptr verbatim (predicate
  ;;                opaque per verify.wat:39 precedent — verify_smt
  ;;                swap (B.6 / Arc F.1) walks the Predicate ADT
  ;;                structurally; this chunk just carries the pointer).
  ;; 7. Gradient?   Each `Forall([], body)` with empty quantification
  ;;                IS a monomorphic binding — the gradient signal that
  ;;                lower (Hβ.lower) reads to choose direct-call
  ;;                lowering vs evidence-passing call_indirect (per
  ;;                spec 05 §Monomorphism + γ insight #11 lower's
  ;;                $row_is_ground reads). Each non-empty Forall
  ;;                represents an open gradient — the body has handles
  ;;                that future $instantiate calls fresh-rewrite.
  ;; 8. Reason?     $generalize records `Generalized(fn_name, span)`
  ;;                indirectly via the body's Reason chain (the seed
  ;;                stores Reasons in GNodes; generalize doesn't add
  ;;                a top-level Reason — the existing chain on the
  ;;                fn handle persists). $instantiate records
  ;;                `Instantiation(scheme_origin, Fresh(old_handle))`
  ;;                per quantified slot via $reason_make_instantiation
  ;;                wrapping $reason_make_fresh — matches src/infer.nx:
  ;;                1944's `mint(Instantiation("inst", Fresh(old)))`.
  ;;
  ;; ═══ FORBIDDEN PATTERNS AUDIT (per Hβ-infer-substrate.md §7.1) ═══
  ;;
  ;; - Drift 1 (Rust vtable):           $ty_substitute is recursive
  ;;                                    direct dispatch on $ty_tag;
  ;;                                    $generalize on $node_kind_tag;
  ;;                                    no dispatch tables.
  ;; - Drift 2 (Scheme env frame):      No `current_substitution`
  ;;                                    parameter threaded through
  ;;                                    every call; $instantiate
  ;;                                    builds the map locally for
  ;;                                    one walk; $generalize doesn't
  ;;                                    use a subst at all (graph IS
  ;;                                    the subst).
  ;; - Drift 3 (Python dict / string):  Map entries are integer
  ;;                                    handles + record dispatch by
  ;;                                    integer tag (200/201); not
  ;;                                    string-keyed.
  ;; - Drift 4 (Haskell monad transformer): $instantiate +
  ;;                                    $generalize are direct
  ;;                                    functions; no `SubstM` /
  ;;                                    `InferM` monad wrapping.
  ;; - Drift 5 (C calling convention):  Functions take direct i32
  ;;                                    parameters (scheme ptr, ty
  ;;                                    ptr, map ptr); no bundled
  ;;                                    "context struct" pseudo-state.
  ;; - Drift 6 (primitive-type-special-case): All 14 Ty variants get
  ;;                                    their arms in $free_in_ty +
  ;;                                    $ty_substitute uniformly. TInt
  ;;                                    has no compiler-intrinsic
  ;;                                    handling beyond the universal
  ;;                                    nullary-sentinel discipline.
  ;; - Drift 7 (parallel-arrays):       Schemes are 2-field records;
  ;;                                    subst-map entries are 2-field
  ;;                                    records — single list of
  ;;                                    record pointers, NOT parallel
  ;;                                    `(scheme_qs[], scheme_bodies[])`
  ;;                                    or `(map_olds[], map_freshes[])`
  ;;                                    arrays. Per γ insight #9 +
  ;;                                    drift-mode-7 audit.
  ;; - Drift 8 (mode flag):             $instantiate doesn't take an
  ;;                                    `inst_mode: Int` for "fresh
  ;;                                    vs display"; one function,
  ;;                                    one semantics (direct
  ;;                                    $graph_fresh_ty mint at the
  ;;                                    seed; the wheel layer routes
  ;;                                    via FreshHandle effect).
  ;; - Drift 9 (deferred-by-omission):  EVERY 14 Ty variants handled
  ;;                                    in $free_in_ty + $ty_substitute.
  ;;                                    EVERY 5 NodeKind variants
  ;;                                    handled in $generalize. No
  ;;                                    `_ =>` silent fallback. Trap
  ;;                                    via `(unreachable)` on unknown
  ;;                                    Ty/NodeKind tag.
  ;;
  ;; - Foreign fluency — type-class instances: NO "instance lookup",
  ;;                                    "type class resolution",
  ;;                                    "class dictionary",
  ;;                                    "implicit parameter" vocabulary.
  ;;                                    Schemes are Damas-Milner Forall
  ;;                                    per spec 04; no higher-rank or
  ;;                                    type-class machinery (out of
  ;;                                    Inka scope per spec 02).
  ;; - Foreign fluency — Algorithm W:   $instantiate / $generalize
  ;;                                    are NOT named after Algorithm
  ;;                                    W's `instantiate(σ)` /
  ;;                                    `generalize(Γ, τ)`; they ARE
  ;;                                    those operations but their
  ;;                                    signatures + return shapes
  ;;                                    follow spec 04 + src/infer.nx
  ;;                                    canonical (no `(subst, type)`
  ;;                                    return tuple — the graph
  ;;                                    holds the subst).

  ;; ─── Scheme record + accessors ────────────────────────────────────
  ;;
  ;; SCHEME_TAG=200; arity=2.
  ;;   field_0 = quantified handles (flat list of i32 — handle ints
  ;;             from src/types.nx Forall(List, Ty) per src/types.nx:79)
  ;;   field_1 = body Ty (heap pointer)
  ;;
  ;; Per src/types.nx:78-79 + Hβ-infer §2.1 layout. A monomorphic
  ;; binding has an empty quantified list ($len returns 0).

  (func $scheme_make_forall (param $qs i32) (param $body i32) (result i32)
    (local $s i32)
    (local.set $s (call $make_record (i32.const 200) (i32.const 2)))
    (call $record_set (local.get $s) (i32.const 0) (local.get $qs))
    (call $record_set (local.get $s) (i32.const 1) (local.get $body))
    (local.get $s))

  (func $scheme_quantified (param $s i32) (result i32)
    (call $record_get (local.get $s) (i32.const 0)))

  (func $scheme_body (param $s i32) (result i32)
    (call $record_get (local.get $s) (i32.const 1)))

  (func $is_scheme (param $s i32) (result i32)
    (i32.eq (call $tag_of (local.get $s)) (i32.const 200)))

  ;; ─── Substitution map (record-shape pairs) ───────────────────────
  ;;
  ;; SUBST_PAIR_TAG=201; arity=2.
  ;;   field_0 = old handle (i32 — from a Forall's quantified list)
  ;;   field_1 = fresh handle (i32 — minted via $graph_fresh_ty)
  ;;
  ;; Map IS a flat list of these record pointers. $subst_map_lookup
  ;; linear-scans (typical map size 0-3 per src/infer.nx evidence).
  ;; Lookup returns -1 (signed) when not found — handles are unsigned
  ;; i32 ≥ 0, so -1 (= 0xFFFFFFFF) is unambiguous as the "absent"
  ;; sentinel. Callers compare `result < 0` (signed).

  (func $subst_pair_make (param $old i32) (param $fresh i32) (result i32)
    (local $p i32)
    (local.set $p (call $make_record (i32.const 201) (i32.const 2)))
    (call $record_set (local.get $p) (i32.const 0) (local.get $old))
    (call $record_set (local.get $p) (i32.const 1) (local.get $fresh))
    (local.get $p))

  (func $subst_pair_old (param $p i32) (result i32)
    (call $record_get (local.get $p) (i32.const 0)))

  (func $subst_pair_fresh (param $p i32) (result i32)
    (call $record_get (local.get $p) (i32.const 1)))

  ;; $subst_map_make — fresh empty map (initial capacity 4; $list_extend_to
  ;; grows on demand per the Ω.3 buffer-counter substrate). Returns
  ;; (list_ptr, length=0) — but length lives outside (caller-tracked).
  ;; Per Hβ-infer §2 simpler form: callers track length alongside the
  ;; list reference; build_inst_mapping below maintains the count.
  (func $subst_map_make (result i32)
    (call $make_list (i32.const 4)))

  ;; $subst_map_extend(map, len, old, fresh) -> new_map_ptr
  ;;   Appends a new (old, fresh) record to the map. Returns the
  ;;   (possibly grown) map pointer; caller updates length to len+1.
  ;;   Per the Ω.3 buffer-counter pattern (CLAUDE.md operational
  ;;   essentials): $list_extend_to + $list_set + counter increment.
  (func $subst_map_extend (param $map i32) (param $len i32)
                           (param $old i32) (param $fresh i32) (result i32)
    (local $new_map i32) (local $entry i32)
    (local.set $entry (call $subst_pair_make (local.get $old) (local.get $fresh)))
    (local.set $new_map
      (call $list_extend_to (local.get $map)
                            (i32.add (local.get $len) (i32.const 1))))
    (drop (call $list_set (local.get $new_map) (local.get $len) (local.get $entry)))
    (local.get $new_map))

  ;; $subst_map_lookup(map, len, old) -> i32
  ;;   Linear scan over (old, fresh) pairs. Returns the fresh handle
  ;;   on hit; returns -1 (0xFFFFFFFF) when not found. Per src/infer.nx
  ;;   find_mapping (1993-1998) which uses -1 as the absent sentinel.
  (func $subst_map_lookup (param $map i32) (param $len i32) (param $old i32)
                           (result i32)
    (local $i i32) (local $entry i32)
    (local.set $i (i32.const 0))
    (block $done
      (loop $iter
        (br_if $done (i32.ge_u (local.get $i) (local.get $len)))
        (local.set $entry (call $list_index (local.get $map) (local.get $i)))
        (if (i32.eq (call $subst_pair_old (local.get $entry)) (local.get $old))
          (then (return (call $subst_pair_fresh (local.get $entry)))))
        (local.set $i (i32.add (local.get $i) (i32.const 1)))
        (br $iter)))
    (i32.const -1))

  ;; ─── $free_in_ty — Ty walker collecting free TVar handles ───────
  ;;
  ;; Per src/infer.nx:1891-1924. Recursive walker over the 14 Ty
  ;; variants; returns a flat list of i32 handles (each TVar's handle
  ;; appended as encountered). Per H6 wildcard discipline: each
  ;; variant has its arm explicit; trap on unknown.
  ;;
  ;; Coverage discipline (canonical parity with src/infer.nx:1890-1924
  ;; closed 2026-04-26 per ROADMAP §3 + tparam.wat sibling chunk):
  ;;   - Nullary sentinels (TInt/TFloat/TString/TUnit): empty list.
  ;;   - TVar(h): singleton [h].
  ;;   - TList(elem): recurse on elem.
  ;;   - TTuple(elems): recurse on each list element via $free_in_list.
  ;;   - TFun(params, ret, row): concat $free_in_params(params) +
  ;;     $free_in_ty(ret). Row stays opaque — row.wat owns the row's
  ;;     free-handle walk; this chunk reaches Ty-side parity only.
  ;;     Per src/infer.nx:1898-1899 exact recursion shape.
  ;;   - TName(name, args): recurse on each arg via $free_in_list.
  ;;   - TRecord(fields): recurse via $free_in_fields over field-pair
  ;;     list. Per src/infer.nx:1900.
  ;;   - TRecordOpen(fields, rowvar): [rowvar] ++ $free_in_fields(fields).
  ;;     Per src/infer.nx:1901 exact shape.
  ;;   - TRefined(base, pred): recurse on base; predicate ptr passed
  ;;     verbatim (verify.wat:39 precedent — predicate opaque to
  ;;     scheme; verify_smt walks it structurally).
  ;;   - TCont(ret, disc): recurse on ret; discipline sentinel passed
  ;;     verbatim (ResumeDiscipline ADT; ty.wat owns).
  ;;   - TAlias(name, resolved): recurse on resolved (per src/infer.nx:
  ;;     1905 — alias's inner Ty contributes free handles).

  (func $free_in_ty (param $ty i32) (result i32)
    (local $tag i32)
    (local.set $tag (call $ty_tag (local.get $ty)))
    ;; ── Nullary Ty sentinels — empty list ─────────────────────────
    (if (i32.eq (local.get $tag) (i32.const 100))   ;; TInt
      (then (return (call $make_list (i32.const 0)))))
    (if (i32.eq (local.get $tag) (i32.const 101))   ;; TFloat
      (then (return (call $make_list (i32.const 0)))))
    (if (i32.eq (local.get $tag) (i32.const 102))   ;; TString
      (then (return (call $make_list (i32.const 0)))))
    (if (i32.eq (local.get $tag) (i32.const 103))   ;; TUnit
      (then (return (call $make_list (i32.const 0)))))
    ;; ── TVar(h) — singleton [h] ────────────────────────────────────
    (if (i32.eq (local.get $tag) (i32.const 104))
      (then (return
        (call $singleton_handle (call $ty_tvar_handle (local.get $ty))))))
    ;; ── TList(elem) — recurse on elem ──────────────────────────────
    (if (i32.eq (local.get $tag) (i32.const 105))
      (then (return
        (call $free_in_ty (call $ty_tlist_elem (local.get $ty))))))
    ;; ── TTuple(elems) — concat free across element list ────────────
    (if (i32.eq (local.get $tag) (i32.const 106))
      (then (return
        (call $free_in_list (call $ty_ttuple_elems (local.get $ty))))))
    ;; ── TFun(params, ret, row) — recurse on params (via $free_in_params
    ;;    over TParam-list) + ret. Row stays opaque per Hβ-infer §6.1
    ;;    answer-4 + §12 row-normalize follow-up — row.wat owns row's
    ;;    free-handle walk; this chunk reaches Ty-side parity only. ──
    (if (i32.eq (local.get $tag) (i32.const 107))
      (then (return
        (call $list_concat
          (call $free_in_params (call $ty_tfun_params (local.get $ty)))
          (call $free_in_ty (call $ty_tfun_return (local.get $ty)))))))
    ;; ── TName(name, args) — concat free across arg list ────────────
    (if (i32.eq (local.get $tag) (i32.const 108))
      (then (return
        (call $free_in_list (call $ty_tname_args (local.get $ty))))))
    ;; ── TRecord(fields) — recurse via $free_in_fields over field-pair list ─
    (if (i32.eq (local.get $tag) (i32.const 109))
      (then (return
        (call $free_in_fields (call $ty_trecord_fields (local.get $ty))))))
    ;; ── TRecordOpen(fields, rowvar) — rowvar IS a free handle +
    ;;    fields recurse via $free_in_fields. Per src/infer.nx:1901
    ;;    `[v] ++ free_in_fields(fields)` exact parity. ──────────────
    (if (i32.eq (local.get $tag) (i32.const 110))
      (then (return
        (call $list_concat
          (call $singleton_handle (call $ty_trecordopen_rowvar (local.get $ty)))
          (call $free_in_fields (call $ty_trecordopen_fields (local.get $ty)))))))
    ;; ── TRefined(base, pred) — recurse on base; pred opaque ────────
    (if (i32.eq (local.get $tag) (i32.const 111))
      (then (return
        (call $free_in_ty (call $ty_trefined_base (local.get $ty))))))
    ;; ── TCont(ret, disc) — recurse on ret; discipline opaque ───────
    (if (i32.eq (local.get $tag) (i32.const 112))
      (then (return
        (call $free_in_ty (call $ty_tcont_return (local.get $ty))))))
    ;; ── TAlias(name, resolved) — recurse on resolved ───────────────
    (if (i32.eq (local.get $tag) (i32.const 113))
      (then (return
        (call $free_in_ty (call $ty_talias_resolved (local.get $ty))))))
    ;; ── Unknown tag — well-formed Ty cannot get here. Trap. ────────
    ;; Per H6 wildcard discipline + drift mode 9: NO `_ => empty`
    ;; default. Surface the bug rather than silently swallow handles.
    (unreachable))

  ;; $singleton_handle(h) — flat list of one i32 handle. Used by the
  ;; TVar + TRecordOpen-rowvar arms of $free_in_ty.
  (func $singleton_handle (param $h i32) (result i32)
    (local $list i32)
    (local.set $list (call $make_list (i32.const 1)))
    (drop (call $list_set (local.get $list) (i32.const 0) (local.get $h)))
    (local.get $list))

  ;; $free_in_list(tys) — concat $free_in_ty across each element in a
  ;; flat list of Ty pointers. Returns a flat list of i32 handles.
  ;;
  ;; The buffer-counter substrate per CLAUDE.md operational essentials
  ;; (Ω.3 swept the substrate; new code maintains it): allocate a
  ;; growing flat buffer + counter; per-element free-set extends the
  ;; buffer via $list_extend_to. Avoids `acc ++ [X]` O(N²) per the
  ;; CLAUDE.md bug-class.
  (func $free_in_list (param $tys i32) (result i32)
    (local $n i32) (local $i i32)
    (local $sub i32) (local $sub_n i32) (local $sub_j i32)
    (local $out i32) (local $out_n i32)
    (local.set $n (call $len (local.get $tys)))
    (local.set $out (call $make_list (i32.const 4)))
    (local.set $out_n (i32.const 0))
    (local.set $i (i32.const 0))
    (block $done
      (loop $iter
        (br_if $done (i32.ge_u (local.get $i) (local.get $n)))
        (local.set $sub (call $free_in_ty
          (call $list_index (local.get $tys) (local.get $i))))
        (local.set $sub_n (call $len (local.get $sub)))
        (local.set $sub_j (i32.const 0))
        (block $sub_done
          (loop $sub_iter
            (br_if $sub_done (i32.ge_u (local.get $sub_j) (local.get $sub_n)))
            (local.set $out
              (call $list_extend_to (local.get $out)
                                    (i32.add (local.get $out_n) (i32.const 1))))
            (drop (call $list_set (local.get $out) (local.get $out_n)
                                  (call $list_index (local.get $sub) (local.get $sub_j))))
            (local.set $out_n (i32.add (local.get $out_n) (i32.const 1)))
            (local.set $sub_j (i32.add (local.get $sub_j) (i32.const 1)))
            (br $sub_iter)))
        (local.set $i (i32.add (local.get $i) (i32.const 1)))
        (br $iter)))
    ;; Slice down to logical length so $len returns the right count.
    (call $slice (local.get $out) (i32.const 0) (local.get $out_n)))

  ;; $list_concat(a, b) — flat-list concatenation. Buffer-counter pattern
  ;; per CLAUDE.md operational essentials; avoids `acc ++ [X]` O(N²).
  (func $list_concat (param $a i32) (param $b i32) (result i32)
    (local $na i32) (local $nb i32) (local $i i32)
    (local $out i32)
    (local.set $na (call $len (local.get $a)))
    (local.set $nb (call $len (local.get $b)))
    (local.set $out (call $make_list (i32.add (local.get $na) (local.get $nb))))
    (local.set $i (i32.const 0))
    (block $done_a
      (loop $iter_a
        (br_if $done_a (i32.ge_u (local.get $i) (local.get $na)))
        (drop (call $list_set (local.get $out) (local.get $i)
          (call $list_index (local.get $a) (local.get $i))))
        (local.set $i (i32.add (local.get $i) (i32.const 1)))
        (br $iter_a)))
    (local.set $i (i32.const 0))
    (block $done_b
      (loop $iter_b
        (br_if $done_b (i32.ge_u (local.get $i) (local.get $nb)))
        (drop (call $list_set (local.get $out)
          (i32.add (local.get $na) (local.get $i))
          (call $list_index (local.get $b) (local.get $i))))
        (local.set $i (i32.add (local.get $i) (i32.const 1)))
        (br $iter_b)))
    (local.get $out))

  ;; $free_in_params(params) — concat $free_in_ty across each TParam's
  ;; Ty field. Per src/infer.nx:1911-1916 free_in_params recursion shape.
  (func $free_in_params (param $params i32) (result i32)
    (local $n i32) (local $i i32)
    (local $sub i32) (local $sub_n i32) (local $sub_j i32)
    (local $out i32) (local $out_n i32)
    (local.set $n (call $len (local.get $params)))
    (local.set $out (call $make_list (i32.const 4)))
    (local.set $out_n (i32.const 0))
    (local.set $i (i32.const 0))
    (block $done
      (loop $iter
        (br_if $done (i32.ge_u (local.get $i) (local.get $n)))
        (local.set $sub (call $free_in_ty
          (call $tparam_ty
            (call $list_index (local.get $params) (local.get $i)))))
        (local.set $sub_n (call $len (local.get $sub)))
        (local.set $sub_j (i32.const 0))
        (block $sub_done
          (loop $sub_iter
            (br_if $sub_done (i32.ge_u (local.get $sub_j) (local.get $sub_n)))
            (local.set $out
              (call $list_extend_to (local.get $out)
                                    (i32.add (local.get $out_n) (i32.const 1))))
            (drop (call $list_set (local.get $out) (local.get $out_n)
              (call $list_index (local.get $sub) (local.get $sub_j))))
            (local.set $out_n (i32.add (local.get $out_n) (i32.const 1)))
            (local.set $sub_j (i32.add (local.get $sub_j) (i32.const 1)))
            (br $sub_iter)))
        (local.set $i (i32.add (local.get $i) (i32.const 1)))
        (br $iter)))
    (call $slice (local.get $out) (i32.const 0) (local.get $out_n)))

  ;; $free_in_fields(fields) — same pattern over field-pair list.
  ;; Per src/infer.nx:1918-1923.
  (func $free_in_fields (param $fields i32) (result i32)
    (local $n i32) (local $i i32)
    (local $sub i32) (local $sub_n i32) (local $sub_j i32)
    (local $out i32) (local $out_n i32)
    (local.set $n (call $len (local.get $fields)))
    (local.set $out (call $make_list (i32.const 4)))
    (local.set $out_n (i32.const 0))
    (local.set $i (i32.const 0))
    (block $done
      (loop $iter
        (br_if $done (i32.ge_u (local.get $i) (local.get $n)))
        (local.set $sub (call $free_in_ty
          (call $field_pair_ty
            (call $list_index (local.get $fields) (local.get $i)))))
        (local.set $sub_n (call $len (local.get $sub)))
        (local.set $sub_j (i32.const 0))
        (block $sub_done
          (loop $sub_iter
            (br_if $sub_done (i32.ge_u (local.get $sub_j) (local.get $sub_n)))
            (local.set $out
              (call $list_extend_to (local.get $out)
                                    (i32.add (local.get $out_n) (i32.const 1))))
            (drop (call $list_set (local.get $out) (local.get $out_n)
              (call $list_index (local.get $sub) (local.get $sub_j))))
            (local.set $out_n (i32.add (local.get $out_n) (i32.const 1)))
            (local.set $sub_j (i32.add (local.get $sub_j) (i32.const 1)))
            (br $sub_iter)))
        (local.set $i (i32.add (local.get $i) (i32.const 1)))
        (br $iter)))
    (call $slice (local.get $out) (i32.const 0) (local.get $out_n)))

  ;; ─── $ty_substitute — Ty walker rewriting TVar(q) to TVar(map[q]) ─
  ;;
  ;; Per src/infer.nx:1951-1973 (subst_ty). Recursive walker over the
  ;; 14 Ty variants; rebuilds composite types only where substitution
  ;; OR sub-substitution applies. Identity semantics where no
  ;; substitution touches (returns the input pointer unchanged for
  ;; nullary sentinels; rebuilds for composites).
  ;;
  ;; Coverage discipline (canonical parity with src/infer.nx:1950-1990
  ;; closed 2026-04-26 per ROADMAP §3 + tparam.wat sibling chunk):
  ;;   - Nullary sentinels: identity (return as-is).
  ;;   - TVar(q): if map.contains(q), return TVar(map[q]); else identity.
  ;;   - TList/TTuple/TName/TRefined(base only)/TCont(ret only)/
  ;;     TAlias(resolved only): rebuild with substituted sub-Ty.
  ;;   - TFun(params, ret, row): rebuild with $ty_substitute_params(params)
  ;;     + $ty_substitute(ret) + row preserved verbatim. Row substitution
  ;;     awaits row.wat's $row_substitute extension (Hβ-infer §12 named
  ;;     follow-up "Hβ.infer.row-normalize").
  ;;   - TRecord(fields): rebuild with $ty_substitute_fields(fields).
  ;;   - TRecordOpen(fields, rowvar): rebuild with $ty_substitute_fields(
  ;;     fields) + rowvar preserved verbatim (rowvar substitution joins
  ;;     when row.wat's $row_substitute lands alongside).

  (func $ty_substitute (param $ty i32) (param $map i32) (param $map_len i32)
                        (result i32)
    (local $tag i32) (local $h i32) (local $fresh i32)
    (local.set $tag (call $ty_tag (local.get $ty)))
    ;; ── Nullary Ty sentinels — identity ───────────────────────────
    (if (i32.eq (local.get $tag) (i32.const 100))
      (then (return (local.get $ty))))
    (if (i32.eq (local.get $tag) (i32.const 101))
      (then (return (local.get $ty))))
    (if (i32.eq (local.get $tag) (i32.const 102))
      (then (return (local.get $ty))))
    (if (i32.eq (local.get $tag) (i32.const 103))
      (then (return (local.get $ty))))
    ;; ── TVar(q) — map lookup; rewrite if present ──────────────────
    (if (i32.eq (local.get $tag) (i32.const 104))
      (then
        (local.set $h (call $ty_tvar_handle (local.get $ty)))
        (local.set $fresh
          (call $subst_map_lookup (local.get $map) (local.get $map_len)
                                  (local.get $h)))
        (if (i32.lt_s (local.get $fresh) (i32.const 0))
          (then (return (local.get $ty)))     ;; absent — identity
          (else (return (call $ty_make_tvar (local.get $fresh)))))))
    ;; ── TList(elem) — rebuild with substituted elem ───────────────
    (if (i32.eq (local.get $tag) (i32.const 105))
      (then (return
        (call $ty_make_tlist
          (call $ty_substitute
            (call $ty_tlist_elem (local.get $ty))
            (local.get $map) (local.get $map_len))))))
    ;; ── TTuple(elems) — rebuild with substituted element list ────
    (if (i32.eq (local.get $tag) (i32.const 106))
      (then (return
        (call $ty_make_ttuple
          (call $ty_substitute_list
            (call $ty_ttuple_elems (local.get $ty))
            (local.get $map) (local.get $map_len))))))
    ;; ── TFun(params, ret, row) — substitute params (via TParam list
    ;;    walk) + ret. Row stays opaque per Hβ-infer §6.1 answer-4 +
    ;;    §12 row-normalize follow-up. Per src/infer.nx:1961-1965 exact
    ;;    recursion shape (subst_params + subst_ty + eff verbatim). ──
    (if (i32.eq (local.get $tag) (i32.const 107))
      (then (return
        (call $ty_make_tfun
          (call $ty_substitute_params
            (call $ty_tfun_params (local.get $ty))
            (local.get $map) (local.get $map_len))
          (call $ty_substitute
            (call $ty_tfun_return (local.get $ty))
            (local.get $map) (local.get $map_len))
          (call $ty_tfun_row (local.get $ty))))))
    ;; ── TName(name, args) — rebuild with substituted arg list ────
    (if (i32.eq (local.get $tag) (i32.const 108))
      (then (return
        (call $ty_make_tname
          (call $ty_tname_name (local.get $ty))
          (call $ty_substitute_list
            (call $ty_tname_args (local.get $ty))
            (local.get $map) (local.get $map_len))))))
    ;; ── TRecord(fields) — substitute via field-pair list walk. Per
    ;;    src/infer.nx:1967 `TRecord(subst_fields(fields, mapping))`. ──
    (if (i32.eq (local.get $tag) (i32.const 109))
      (then (return
        (call $ty_make_trecord
          (call $ty_substitute_fields
            (call $ty_trecord_fields (local.get $ty))
            (local.get $map) (local.get $map_len))))))
    ;; ── TRecordOpen(fields, rowvar) — substitute fields via field-pair
    ;;    list walk; preserve rowvar verbatim (rowvar substitution awaits
    ;;    row.wat $row_substitute extension — Hβ-infer §12 named follow-
    ;;    up). Per src/infer.nx:1968 `mk_record_open(subst_fields(fields,
    ;;    mapping), v)` — at the WAT layer the smart constructor is just
    ;;    $ty_make_trecordopen with the substituted fields + original v. ─
    (if (i32.eq (local.get $tag) (i32.const 110))
      (then (return
        (call $ty_make_trecordopen
          (call $ty_substitute_fields
            (call $ty_trecordopen_fields (local.get $ty))
            (local.get $map) (local.get $map_len))
          (call $ty_trecordopen_rowvar (local.get $ty))))))
    ;; ── TRefined(base, pred) — substitute base; preserve pred ───
    (if (i32.eq (local.get $tag) (i32.const 111))
      (then (return
        (call $ty_make_trefined
          (call $ty_substitute
            (call $ty_trefined_base (local.get $ty))
            (local.get $map) (local.get $map_len))
          (call $ty_trefined_pred (local.get $ty))))))
    ;; ── TCont(ret, disc) — substitute ret; preserve discipline ──
    (if (i32.eq (local.get $tag) (i32.const 112))
      (then (return
        (call $ty_make_tcont
          (call $ty_substitute
            (call $ty_tcont_return (local.get $ty))
            (local.get $map) (local.get $map_len))
          (call $ty_tcont_discipline (local.get $ty))))))
    ;; ── TAlias(name, resolved) — substitute resolved; preserve name ─
    (if (i32.eq (local.get $tag) (i32.const 113))
      (then (return
        (call $ty_make_talias
          (call $ty_talias_name (local.get $ty))
          (call $ty_substitute
            (call $ty_talias_resolved (local.get $ty))
            (local.get $map) (local.get $map_len))))))
    ;; ── Unknown tag — well-formed Ty cannot get here. Trap. ──────
    (unreachable))

  ;; $ty_substitute_list — apply $ty_substitute to each Ty in a flat
  ;; list, returning a fresh flat list. Caller's map is forwarded.
  ;; Per the same buffer-counter pattern as $free_in_list (avoids the
  ;; `acc ++ [X]` O(N²) bug-class).
  (func $ty_substitute_list (param $tys i32) (param $map i32) (param $map_len i32)
                             (result i32)
    (local $n i32) (local $i i32) (local $out i32)
    (local.set $n (call $len (local.get $tys)))
    (local.set $out (call $make_list (local.get $n)))
    (local.set $i (i32.const 0))
    (block $done
      (loop $iter
        (br_if $done (i32.ge_u (local.get $i) (local.get $n)))
        (drop (call $list_set
          (local.get $out)
          (local.get $i)
          (call $ty_substitute
            (call $list_index (local.get $tys) (local.get $i))
            (local.get $map) (local.get $map_len))))
        (local.set $i (i32.add (local.get $i) (i32.const 1)))
        (br $iter)))
    (local.get $out))

  ;; $ty_substitute_params — apply $ty_substitute to each TParam's Ty
  ;; field, preserving name / authored / resolved Ownership verbatim.
  ;; Per src/infer.nx:1978-1983.
  (func $ty_substitute_params (param $params i32) (param $map i32)
                               (param $map_len i32) (result i32)
    (local $n i32) (local $i i32) (local $out i32) (local $p i32)
    (local.set $n (call $len (local.get $params)))
    (local.set $out (call $make_list (local.get $n)))
    (local.set $i (i32.const 0))
    (block $done
      (loop $iter
        (br_if $done (i32.ge_u (local.get $i) (local.get $n)))
        (local.set $p (call $list_index (local.get $params) (local.get $i)))
        (drop (call $list_set
          (local.get $out)
          (local.get $i)
          (call $tparam_make
            (call $tparam_name (local.get $p))
            (call $ty_substitute
              (call $tparam_ty (local.get $p))
              (local.get $map) (local.get $map_len))
            (call $tparam_authored (local.get $p))
            (call $tparam_resolved (local.get $p)))))
        (local.set $i (i32.add (local.get $i) (i32.const 1)))
        (br $iter)))
    (local.get $out))

  ;; $ty_substitute_fields — apply $ty_substitute to each field-pair's
  ;; Ty field, preserving name verbatim. Per src/infer.nx:1985-1990.
  (func $ty_substitute_fields (param $fields i32) (param $map i32)
                               (param $map_len i32) (result i32)
    (local $n i32) (local $i i32) (local $out i32) (local $f i32)
    (local.set $n (call $len (local.get $fields)))
    (local.set $out (call $make_list (local.get $n)))
    (local.set $i (i32.const 0))
    (block $done
      (loop $iter
        (br_if $done (i32.ge_u (local.get $i) (local.get $n)))
        (local.set $f (call $list_index (local.get $fields) (local.get $i)))
        (drop (call $list_set
          (local.get $out)
          (local.get $i)
          (call $field_pair_make
            (call $field_pair_name (local.get $f))
            (call $ty_substitute
              (call $field_pair_ty (local.get $f))
              (local.get $map) (local.get $map_len)))))
        (local.set $i (i32.add (local.get $i) (i32.const 1)))
        (br $iter)))
    (local.get $out))

  ;; ─── $instantiate(scheme) -> Ty ────────────────────────────────────
  ;;
  ;; Per src/infer.nx:1931-1998 + spec 04 §Instantiations. Walks
  ;; scheme.body, substituting each quantified handle with one fresh-
  ;; minted via $graph_fresh_ty. The substitution map is built once
  ;; per call ($build_inst_mapping); $ty_substitute walks the body
  ;; once.
  ;;
  ;; Empty quantification short-circuits to identity (return body as-
  ;; is). Per src/infer.nx:1933 — `if len(qs) == 0 { ty }`.
  ;;
  ;; Reason discipline (per src/infer.nx:1944 + Hβ-infer §6.1 answer-8):
  ;;   Each fresh handle's reason is `Instantiation("inst",
  ;;   Fresh(old_handle))` — $reason_make_instantiation wraps
  ;;   $reason_make_fresh. The "inst" string is the seed's literal per
  ;;   src/infer.nx parity; the wheel's compiled form passes a richer
  ;;   ctx string (e.g., the scheme's origin name when known). Tier-5
  ;;   base uses the constant string at offset 1620 below.

  (func $instantiate (param $scheme i32) (result i32)
    (local $qs i32) (local $qs_n i32)
    (local $body i32)
    (local $map i32) (local $map_len i32)
    (local.set $qs (call $scheme_quantified (local.get $scheme)))
    (local.set $qs_n (call $len (local.get $qs)))
    (local.set $body (call $scheme_body (local.get $scheme)))
    ;; Empty quantification — monotype; identity.
    (if (i32.eqz (local.get $qs_n))
      (then (return (local.get $body))))
    ;; Build (old, fresh) map per quantified slot, then substitute.
    (local.set $map (call $build_inst_mapping
      (local.get $qs) (local.get $qs_n)))
    (local.set $map_len (local.get $qs_n))
    (call $ty_substitute (local.get $body) (local.get $map) (local.get $map_len)))

  ;; $build_inst_mapping(qs, qs_n) -> map
  ;;   For each handle in qs, mint a fresh handle via $graph_fresh_ty
  ;;   wrapped in `Instantiation("inst", Fresh(old))` Reason. Returns
  ;;   the populated map (flat list of subst-pair records).
  ;;
  ;; Per src/infer.nx:1940-1946 build_inst_mapping. Length tracked
  ;; alongside the list reference per the seed convention (caller
  ;; passes qs_n; map_len = qs_n at completion).
  (func $build_inst_mapping (param $qs i32) (param $qs_n i32) (result i32)
    (local $map i32) (local $i i32)
    (local $old i32) (local $reason i32) (local $fresh i32)
    (local.set $map (call $subst_map_make))
    (local.set $i (i32.const 0))
    (block $done
      (loop $iter
        (br_if $done (i32.ge_u (local.get $i) (local.get $qs_n)))
        (local.set $old (call $list_index (local.get $qs) (local.get $i)))
        ;; Reason = Instantiation("inst", Fresh(old))
        (local.set $reason
          (call $reason_make_instantiation
            (i32.const 1620)                           ;; "inst" string ptr
            (call $reason_make_fresh (local.get $old))))
        (local.set $fresh (call $graph_fresh_ty (local.get $reason)))
        (local.set $map (call $subst_map_extend
          (local.get $map) (local.get $i)
          (local.get $old) (local.get $fresh)))
        (local.set $i (i32.add (local.get $i) (i32.const 1)))
        (br $iter)))
    (local.get $map))

  ;; "inst" string constant for $instantiate's per-slot Reason. 4
  ;; bytes "inst" + 4-byte length prefix = 8 total. Lives at offset
  ;; 1620 (above ty.wat's ERROR_DEEP_CHASE at 1600/20bytes; well
  ;; below HEAP_BASE = 4096). Per CLAUDE.md memory model + ty.wat
  ;; precedent for static string sentinels.
  (data (i32.const 1620) "\04\00\00\00inst")

  ;; ─── $generalize(fn_handle) -> Scheme ─────────────────────────────
  ;;
  ;; Per src/infer.nx:1818-1834 + spec 04 §Generalizations + Hβ-infer
  ;; §2.4. Chases the fn_handle through the graph; dispatches on the
  ;; terminal NodeKind:
  ;;
  ;;   - NBound(ty): $chase_deep the ty + collect free handles via
  ;;     $free_in_ty + wrap as Forall(body_free, body_ty). The wheel
  ;;     conservatively quantifies all body_free (env_free unavailable
  ;;     at the seed Tier-5; named follow-up extends this when env
  ;;     iteration substrate lands per Hβ-infer §12).
  ;;   - NFree(_) | NRowBound(_) | NRowFree(_) | NErrorHole(_):
  ;;     monotype Forall([], TVar(handle)) — the handle is unresolved
  ;;     or non-Ty-shaped; can't quantify what isn't determined.
  ;;     Per src/infer.nx:1829-1832 H6 exhaustive enumeration —
  ;;     EVERY non-NBound NodeKind variant gets its arm explicit so
  ;;     a future variant addition fails at this site rather than
  ;;     silently wraps.
  ;;
  ;; NodeKind tag values per graph.wat:54-59:
  ;;   60 = NBOUND, 61 = NFREE, 62 = NROWBOUND, 63 = NROWFREE,
  ;;   64 = NERRORHOLE.

  (func $generalize (param $fn_handle i32) (result i32)
    (local $g i32) (local $nk i32) (local $nk_tag i32)
    (local $payload i32) (local $body_ty i32) (local $body_free i32)
    (local.set $g (call $graph_chase (local.get $fn_handle)))
    (local.set $nk (call $gnode_kind (local.get $g)))
    (local.set $nk_tag (call $node_kind_tag (local.get $nk)))
    ;; ── NBound(ty) — quantify body's free handles ─────────────────
    (if (i32.eq (local.get $nk_tag) (i32.const 60))
      (then
        (local.set $payload (call $node_kind_payload (local.get $nk)))
        (local.set $body_ty (call $chase_deep (local.get $payload)))
        (local.set $body_free (call $free_in_ty (local.get $body_ty)))
        (return (call $scheme_make_forall
          (local.get $body_free) (local.get $body_ty)))))
    ;; ── NFree(_) — unresolved; monotype Forall([], TVar(handle)) ──
    (if (i32.eq (local.get $nk_tag) (i32.const 61))
      (then (return
        (call $scheme_make_forall
          (call $make_list (i32.const 0))
          (call $ty_make_tvar (local.get $fn_handle))))))
    ;; ── NRowBound(_) — row handle, not a Ty; monotype ─────────────
    (if (i32.eq (local.get $nk_tag) (i32.const 62))
      (then (return
        (call $scheme_make_forall
          (call $make_list (i32.const 0))
          (call $ty_make_tvar (local.get $fn_handle))))))
    ;; ── NRowFree(_) — unresolved row; monotype ────────────────────
    (if (i32.eq (local.get $nk_tag) (i32.const 63))
      (then (return
        (call $scheme_make_forall
          (call $make_list (i32.const 0))
          (call $ty_make_tvar (local.get $fn_handle))))))
    ;; ── NErrorHole(_) — error; preserve handle for diagnostics ────
    (if (i32.eq (local.get $nk_tag) (i32.const 64))
      (then (return
        (call $scheme_make_forall
          (call $make_list (i32.const 0))
          (call $ty_make_tvar (local.get $fn_handle))))))
    ;; ── Unknown NodeKind — graph cannot produce one. Trap. ────────
    ;; Per H6 wildcard discipline + drift mode 9: NO `_ => fabricated`
    ;; default. Surface the bug rather than silently wrap.
    (unreachable))
