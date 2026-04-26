  ;; ═══ ty.wat — Ty constructors + tag conventions + chase_deep (Tier 5) ═
  ;; Implements: Hβ-infer-substrate.md §1 + §2.3 (extended commits
  ;;             `38b0075` for Reason gap-find + `17205e9` for the
  ;;             14th Ty variant TAlias + ResumeDiscipline relocation
  ;;             220→250) + §8.1 ty.wat row + §8.4 ~430-line estimate.
  ;;             Realizes the Ty layer the rest of inference reads
  ;;             through: 14 Ty variants (4 nullary sentinels + 10
  ;;             record-shaped) + 3 ResumeDiscipline sentinels +
  ;;             $chase_deep(ty) walking through TVar handles via
  ;;             $graph_chase per Hβ-infer §2.3 + §2.4.
  ;;
  ;;             Per Hβ-lower-substrate.md §7.1: ty.wat is SHARED with
  ;;             Hβ.lower (lower's $lookup_ty composes on the same Ty
  ;;             record shape; lower lands as the second consumer).
  ;;             ty.wat lives in bootstrap/src/infer/ as the EARLIER
  ;;             consumer per the Hβ §13.3 dep order.
  ;;
  ;; Exports:    $ty_tag,
  ;;             $ty_make_tint, $ty_make_tfloat, $ty_make_tstring, $ty_make_tunit,
  ;;             $ty_make_tvar / $ty_tvar_handle,
  ;;             $ty_make_tlist / $ty_tlist_elem,
  ;;             $ty_make_ttuple / $ty_ttuple_elems,
  ;;             $ty_make_tfun / $ty_tfun_params / $ty_tfun_return / $ty_tfun_row,
  ;;             $ty_make_tname / $ty_tname_name / $ty_tname_args,
  ;;             $ty_make_trecord / $ty_trecord_fields,
  ;;             $ty_make_trecordopen / $ty_trecordopen_fields / $ty_trecordopen_rowvar,
  ;;             $ty_make_trefined / $ty_trefined_base / $ty_trefined_pred,
  ;;             $ty_make_tcont / $ty_tcont_return / $ty_tcont_discipline,
  ;;             $ty_make_talias / $ty_talias_name / $ty_talias_resolved,
  ;;             $is_tint, $is_tfloat, $is_tstring, $is_tunit,
  ;;             $is_tvar, $is_tlist, $is_ttuple, $is_tfun,
  ;;             $is_tname, $is_trecord, $is_trecordopen, $is_trefined,
  ;;             $is_tcont, $is_talias,
  ;;             $resume_make_oneshot, $resume_make_multishot, $resume_make_either,
  ;;             $is_resume_oneshot, $is_resume_multishot, $is_resume_either,
  ;;             $chase_deep
  ;; Uses:       $make_record / $record_get / $tag_of (record.wat),
  ;;             $graph_chase / $gnode_kind / $node_kind_tag /
  ;;               $node_kind_payload (graph.wat),
  ;;             $make_list / $list_index / $list_set / $len (list.wat),
  ;;             $str_alloc (str.wat — for the ERROR_DEEP_CHASE sentinel
  ;;             only, allocated lazily via $ty_error_deep_chase_name)
  ;; Test:       runtime_test/infer_ty.wat (pending — first acceptance is
  ;;             $ty_make_*-grep + wasm-validate per Hβ-infer-substrate.md §11)
  ;;
  ;; ═══ DESIGN ═══════════════════════════════════════════════════════
  ;;
  ;; Per spec 02 (Ty ADT) + Hβ-infer-substrate.md §2.3 + Hβ-lower-
  ;; substrate.md §7.1 (lower reads via $graph_chase + $tag_of dispatch
  ;; on the same records this chunk produces) + src/types.nx canonical
  ;; Ty (lines 35-49, 14 variants).
  ;;
  ;; Nullary-sentinel discipline (per HB-bool-transition + γ insight #8
  ;; — "the heap has one story" + drift mode 6 audit):
  ;;   The four nullary primitive Ty variants (TInt, TFloat, TString,
  ;;   TUnit) take the SAME compilation discipline as every other
  ;;   nullary ADT variant — they ARE i32 sentinel constants in the
  ;;   [0, HEAP_BASE) region. $tag_of (record.wat:49) dispatches via
  ;;   the heap-base threshold; values < HEAP_BASE return themselves as
  ;;   tags. So $ty_tag(TINT_TAG=100) = 100 directly; no heap record.
  ;;   Same discipline for the 3 ResumeDiscipline variants (250-252).
  ;;   This is NOT a "Bool special-case" — it's the universal nullary
  ;;   substrate the kernel applies uniformly.
  ;;
  ;; RN.1 substrate (TAlias):
  ;;   Per src/types.nx:48 + Hβ-infer §2.3 (extended for Wave 2.E.infer.ty
  ;;   gap finding 2026-04-26): TAlias(name, resolved) preserves the
  ;;   developer-authored alias name (e.g. "Port") wrapping the resolved
  ;;   type (e.g. TRefined(TInt, _)). The intent edge is load-bearing —
  ;;   show_type at src/types.nx:815 returns the alias name verbatim
  ;;   for diagnostics rather than expanding to the resolved form.
  ;;   Without this Ty variant, intent-aware rendering collapses; the
  ;;   user reads expanded refinements where they wrote a single name.
  ;;
  ;; ResumeDiscipline relocation (220→250):
  ;;   Per Hβ-lower-substrate.md §3.1 + §11 (locked 2026-04-26):
  ;;   earlier draft put ResumeDiscipline tags at 220/221/222 which now
  ;;   collide with reason.wat's 220-242 Reason variants. Per Wave
  ;;   2.E.infer.ty gap-finding the relocation lands at 250-252 to
  ;;   preserve $tag_of uniqueness across the heap. ResumeDiscipline
  ;;   region 250-259 reserved (3 variants used + 7 future-headroom).
  ;;
  ;; $chase_deep semantics (per Hβ-infer §2.3 + §2.4 — used by
  ;; $generalize at FnStmt exit + $lookup_ty in lower):
  ;;   $graph_chase (graph.wat:261) is Tier-3 base — walks NBound /
  ;;   NRowBound until terminal but does NOT decompose Ty structure to
  ;;   follow nested TVar(handle) transitively. $chase_deep is the
  ;;   caller-side helper that DOES that: it walks each composite Ty
  ;;   variant recursively, follows TVar through $graph_chase + recurses
  ;;   on the resolved Ty, returns a fully-resolved Ty tree (no TVar
  ;;   handles still pointing at NBound chains).
  ;;
  ;;   Cycle bound at depth 100 — same threshold as $graph_chase (so
  ;;   $chase_deep budget composes naturally). On overflow: returns
  ;;   TName("ERROR_DEEP_CHASE", []) — opaque sentinel the caller can
  ;;   detect; emit_diag.wat (Tier 6) surfaces a diagnostic. The
  ;;   sentinel is a real TName record (tag 108), not a magic int —
  ;;   $is_tname predicate identifies it; $ty_tname_name returns the
  ;;   error string for the diagnostic chain.
  ;;
  ;; ═══ TAG REGION ═══════════════════════════════════════════════════
  ;;
  ;; Per Hβ-infer-substrate.md §2.3 + §13.3 dep order:
  ;;
  ;;   100-113 — Ty variants (14 slots; 100-103 nullary sentinels,
  ;;             104-113 record-shaped; 114-119 reserved for future
  ;;             Ty variants per src/types.nx evolution)
  ;;   250-259 — ResumeDiscipline sentinels (3 used, 6 reserved)
  ;;
  ;; Ty per-variant enumeration (matches src/types.nx:35-49 verbatim):
  ;;   100 = TInt                                              (nullary sentinel)
  ;;   101 = TFloat                                            (nullary sentinel)
  ;;   102 = TString                                           (nullary sentinel)
  ;;   103 = TUnit                                             (nullary sentinel)
  ;;   104 = TVar(Int)                                         arity 1
  ;;   105 = TList(Ty)                                         arity 1
  ;;   106 = TTuple(List)                                      arity 1 (List of Ty ptrs)
  ;;   107 = TFun(List, Ty, EffRow)                            arity 3 (params=List of TParam, return Ty, eff row ptr)
  ;;   108 = TName(String, List)                               arity 2 (Bool/Option/etc. live here)
  ;;   109 = TRecord(List)                                     arity 1 (List of (name, Ty) pairs)
  ;;   110 = TRecordOpen(List, Int)                            arity 2 (fields list + rowvar handle)
  ;;   111 = TRefined(Ty, Predicate)                           arity 2 (base Ty + opaque predicate ptr)
  ;;   112 = TCont(Ty, ResumeDiscipline)                       arity 2 (return Ty + discipline sentinel)
  ;;   113 = TAlias(String, Ty)                                arity 2 (RN.1 — alias name + resolved Ty)
  ;;
  ;; ResumeDiscipline per-variant (matches src/types.nx:70-73 verbatim):
  ;;   250 = OneShot                                           (nullary sentinel)
  ;;   251 = MultiShot                                         (nullary sentinel)
  ;;   252 = Either                                            (nullary sentinel)
  ;;
  ;; Tag uniqueness across the heap (no collisions — per Hβ-infer
  ;; §2.1 + §13.3 + Hβ-lower §3.1 + per audit at acceptance criterion):
  ;;   0-44       TokenKind sentinels (lexer.wat)
  ;;   50-99      graph.wat (NodeKind 60-64, GNode 80, Mutation 70-72)
  ;;   100-113    Ty variants (this chunk)
  ;;   114-119    reserved future Ty
  ;;   130-149    env.wat
  ;;   150-179    row.wat
  ;;   180-199    verify.wat (VerifyObligation 180)
  ;;   200-219    infer non-Reason private (state.wat 210-212)
  ;;   220-242    reason.wat Reason variants (23)
  ;;   243-249    reserved future Reason
  ;;   250-252    ResumeDiscipline (this chunk)
  ;;   253-259    reserved future ResumeDiscipline
  ;;   300-349    LowExpr (lower.wat — pending; per Hβ-lower §2)
  ;;
  ;; TParam payload note (per Hβ-infer §2.3 + spec 02 src/types.nx:55-58
  ;; + ROADMAP §3 substrate-gap closure 2026-04-26):
  ;;   TFun's params field is a List of TParam records — TParam is its
  ;;   own ADT (TParam(name, ty, authored_ownership, resolved_ownership)
  ;;   per OW.2). TParam records land in tparam.wat (sibling Tier-5
  ;;   chunk; tag 202 + accessors $tparam_name / $tparam_ty /
  ;;   $tparam_authored / $tparam_resolved). ty.wat continues to store
  ;;   the params List as opaque ptr at the constructor / accessor
  ;;   layer; the WALKERS that need to recurse INTO TParam (scheme.wat's
  ;;   $free_in_params + $ty_substitute_params; eventually own.wat's
  ;;   ownership-row composition; eventually a peer $chase_deep_param
  ;;   helper) compose on tparam.wat directly.
  ;;
  ;;   $chase_deep currently does NOT recurse into TParam's inner Ty
  ;;   (this chunk's $chase_deep_loop TFun arm at line ~615 preserves
  ;;   params verbatim). That parity gap is ROADMAP-tracked separately
  ;;   from the scheme.wat $free_in_ty / $ty_substitute parity (which
  ;;   ROADMAP §3 closed); $chase_deep extension is a named peer
  ;;   follow-up that lands when the TFun-row chase substrate (row.wat-
  ;;   owned) lands alongside.
  ;;
  ;; ═══ EIGHT INTERROGATIONS (per Hβ-infer-substrate.md §6 + this
  ;;     chunk's edit sites per the dispatch contract) ═════════════════
  ;;
  ;; 1. Graph?       TVar(handle) variants reference graph handles;
  ;;                 $chase_deep composes on $graph_chase to follow
  ;;                 NBound chains. The graph IS the substrate Ty
  ;;                 handles point INTO; the Ty is the lens.
  ;; 2. Handler?     Direct constructors at the seed level (passive
  ;;                 data); the wheel's compiled form is also direct
  ;;                 (Ty values aren't routed through handlers).
  ;; 3. Verb?        N/A — pure data construction.
  ;; 4. Row?         TFun's arity-3 carries an EffRow ptr to row.wat
  ;;                 substrate; $chase_deep treats row as opaque
  ;;                 (row.wat owns row chase semantics).
  ;; 5. Ownership?   Ty values typically `ref` (handles + names + sub-Ty
  ;;                 borrowed); $chase_deep returns `own` Ty (allocates
  ;;                 fresh records when reconstructing the chased tree).
  ;; 6. Refinement?  TRefined predicate stored as opaque ptr per
  ;;                 verify.wat:39 precedent. $chase_deep on TRefined
  ;;                 chases the base Ty + preserves the predicate ptr.
  ;; 7. Gradient?    Each `$ty_make_*` constructor IS a gradient
  ;;                 lockdown — once a Ty record is built, its tag
  ;;                 fixes the variant; no later mutation. Each
  ;;                 nullary sentinel is the smallest possible
  ;;                 commitment (no heap allocation).
  ;; 8. Reason?      Ty values don't carry Reasons; Reasons live in
  ;;                 GNodes (graph.wat:200) wrapping NodeKind around
  ;;                 the Ty pointer. $chase_deep is read-only on
  ;;                 Reasons (it walks Ty, not GNodes).
  ;;
  ;; ═══ FORBIDDEN PATTERNS AUDIT (per Hβ-infer-substrate.md §7) ══════
  ;;
  ;; - Drift 1 (Rust vtable):              $chase_deep is recursive
  ;;                                       direct dispatch via $tag_of;
  ;;                                       no dispatch table.
  ;; - Drift 6 (primitive-type-special-case): TInt is just a Ty variant
  ;;                                       with tag 100 — no compiler-
  ;;                                       intrinsic handling beyond the
  ;;                                       universal sentinel discipline
  ;;                                       (which applies UNIFORMLY to
  ;;                                       all 4 nullary Ty variants +
  ;;                                       all 3 ResumeDiscipline
  ;;                                       sentinels).
  ;; - Drift 7 (parallel-arrays):          TTuple's elements are ONE
  ;;                                       List; TFun's params are ONE
  ;;                                       List (each entry a TParam
  ;;                                       record per spec 02:55).
  ;; - Drift 8 (mode flag):                ADT tag dispatch via i32
  ;;                                       const compares; not strings.
  ;;                                       ResumeDiscipline is its OWN
  ;;                                       ADT (3 sentinels) — NOT a
  ;;                                       "discipline_mode i32" flag.
  ;; - Drift 9 (deferred-by-omission):     EVERY 14 Ty variants AND 3
  ;;                                       ResumeDiscipline variants
  ;;                                       get their constructors in
  ;;                                       this commit. EVERY non-trivial
  ;;                                       field gets its accessor. No
  ;;                                       `;; TODO TAlias accessors
  ;;                                       later` placeholders.
  ;; - Foreign fluency:                    no "type kind" / "discriminator"
  ;;                                       / "ADT runtime" generic
  ;;                                       vocabulary. Names match
  ;;                                       src/types.nx variants exactly
  ;;                                       (lowercased for WAT
  ;;                                       convention).

  ;; ─── ERROR_DEEP_CHASE sentinel string (data segment) ─────────────
  ;; Used by $chase_deep on cycle / depth-overflow as the TName payload.
  ;; 16-byte string "ERROR_DEEP_CHASE" — length 16 + 16 bytes = 20 total.
  ;; Lives at offset 1600 (well above emit_data.wat's highest at 1525,
  ;; well below HEAP_BASE = 4096); the [0, HEAP_BASE) sentinel region
  ;; per CLAUDE.md memory model. Read-only string constant; no GC concern.
  (data (i32.const 1600) "\10\00\00\00ERROR_DEEP_CHASE")

  ;; ─── Universal Ty tag accessor ───────────────────────────────────
  ;; Returns the Ty record's tag (100-113). For nullary sentinels
  ;; (TINT/TFLOAT/TSTRING/TUNIT, values 100-103), $tag_of returns the
  ;; sentinel value itself (heap-base threshold per record.wat:49).
  ;; For record-shaped variants (TVAR..TALIAS, allocated above
  ;; HEAP_BASE), $tag_of loads from offset 0. Single dispatch surface.
  (func $ty_tag (param $ty i32) (result i32)
    (call $tag_of (local.get $ty)))

  ;; ─── 100 = TInt (nullary sentinel) ───────────────────────────────
  ;; Per nullary-sentinel discipline: TInt IS the i32 const 100; no
  ;; heap record. $tag_of(100) returns 100 (sentinel < HEAP_BASE = 4096).
  (func $ty_make_tint (result i32)
    (i32.const 100))

  ;; ─── 101 = TFloat (nullary sentinel) ─────────────────────────────
  (func $ty_make_tfloat (result i32)
    (i32.const 101))

  ;; ─── 102 = TString (nullary sentinel) ────────────────────────────
  (func $ty_make_tstring (result i32)
    (i32.const 102))

  ;; ─── 103 = TUnit (nullary sentinel) ──────────────────────────────
  (func $ty_make_tunit (result i32)
    (i32.const 103))

  ;; ─── 104 = TVar(Int) — arity 1 ───────────────────────────────────
  ;; Field 0: graph handle (i32). The handle indexes into graph.wat's
  ;; nodes buffer; $graph_chase + $chase_deep follow it through NBound
  ;; chains.
  (func $ty_make_tvar (param $handle i32) (result i32)
    (local $t i32)
    (local.set $t (call $make_record (i32.const 104) (i32.const 1)))
    (call $record_set (local.get $t) (i32.const 0) (local.get $handle))
    (local.get $t))

  (func $ty_tvar_handle (param $t i32) (result i32)
    (call $record_get (local.get $t) (i32.const 0)))

  ;; ─── 105 = TList(Ty) — arity 1 ───────────────────────────────────
  ;; Field 0: element Ty pointer (heap ptr or sentinel).
  (func $ty_make_tlist (param $elem i32) (result i32)
    (local $t i32)
    (local.set $t (call $make_record (i32.const 105) (i32.const 1)))
    (call $record_set (local.get $t) (i32.const 0) (local.get $elem))
    (local.get $t))

  (func $ty_tlist_elem (param $t i32) (result i32)
    (call $record_get (local.get $t) (i32.const 0)))

  ;; ─── 106 = TTuple(List) — arity 1 ────────────────────────────────
  ;; Field 0: List of element Ty pointers.
  (func $ty_make_ttuple (param $elems i32) (result i32)
    (local $t i32)
    (local.set $t (call $make_record (i32.const 106) (i32.const 1)))
    (call $record_set (local.get $t) (i32.const 0) (local.get $elems))
    (local.get $t))

  (func $ty_ttuple_elems (param $t i32) (result i32)
    (call $record_get (local.get $t) (i32.const 0)))

  ;; ─── 107 = TFun(List, Ty, EffRow) — arity 3 ──────────────────────
  ;; Field 0: params List (each entry a TParam record per spec 02:55-58).
  ;; Field 1: return Ty pointer.
  ;; Field 2: effect row pointer (row.wat record).
  (func $ty_make_tfun (param $params i32) (param $ret i32) (param $row i32)
                       (result i32)
    (local $t i32)
    (local.set $t (call $make_record (i32.const 107) (i32.const 3)))
    (call $record_set (local.get $t) (i32.const 0) (local.get $params))
    (call $record_set (local.get $t) (i32.const 1) (local.get $ret))
    (call $record_set (local.get $t) (i32.const 2) (local.get $row))
    (local.get $t))

  (func $ty_tfun_params (param $t i32) (result i32)
    (call $record_get (local.get $t) (i32.const 0)))

  (func $ty_tfun_return (param $t i32) (result i32)
    (call $record_get (local.get $t) (i32.const 1)))

  (func $ty_tfun_row (param $t i32) (result i32)
    (call $record_get (local.get $t) (i32.const 2)))

  ;; ─── 108 = TName(String, List) — arity 2 ─────────────────────────
  ;; Field 0: name string ptr (e.g. "Bool", "Option", "ERROR_DEEP_CHASE").
  ;; Field 1: type-args List (List of Ty ptrs; nullary names take an
  ;;          empty list).
  ;; Per spec 02: Bool / Option / Result / nominal types live here.
  (func $ty_make_tname (param $name i32) (param $args i32) (result i32)
    (local $t i32)
    (local.set $t (call $make_record (i32.const 108) (i32.const 2)))
    (call $record_set (local.get $t) (i32.const 0) (local.get $name))
    (call $record_set (local.get $t) (i32.const 1) (local.get $args))
    (local.get $t))

  (func $ty_tname_name (param $t i32) (result i32)
    (call $record_get (local.get $t) (i32.const 0)))

  (func $ty_tname_args (param $t i32) (result i32)
    (call $record_get (local.get $t) (i32.const 1)))

  ;; ─── 109 = TRecord(List) — arity 1 ───────────────────────────────
  ;; Field 0: fields List — each entry a (name, Ty) pair record.
  ;; Pair-record substrate lives in tparam.wat / records-substrate
  ;; chunk (peer; pending). ty.wat treats fields entries as opaque
  ;; per the same discipline as TParam in TFun.
  (func $ty_make_trecord (param $fields i32) (result i32)
    (local $t i32)
    (local.set $t (call $make_record (i32.const 109) (i32.const 1)))
    (call $record_set (local.get $t) (i32.const 0) (local.get $fields))
    (local.get $t))

  (func $ty_trecord_fields (param $t i32) (result i32)
    (call $record_get (local.get $t) (i32.const 0)))

  ;; ─── 110 = TRecordOpen(List, Int) — arity 2 ──────────────────────
  ;; Field 0: fields List (same shape as TRecord's).
  ;; Field 1: rowvar handle (i32) — the open row variable per spec 01.
  (func $ty_make_trecordopen (param $fields i32) (param $rowvar i32)
                              (result i32)
    (local $t i32)
    (local.set $t (call $make_record (i32.const 110) (i32.const 2)))
    (call $record_set (local.get $t) (i32.const 0) (local.get $fields))
    (call $record_set (local.get $t) (i32.const 1) (local.get $rowvar))
    (local.get $t))

  (func $ty_trecordopen_fields (param $t i32) (result i32)
    (call $record_get (local.get $t) (i32.const 0)))

  (func $ty_trecordopen_rowvar (param $t i32) (result i32)
    (call $record_get (local.get $t) (i32.const 1)))

  ;; ─── 111 = TRefined(Ty, Predicate) — arity 2 ─────────────────────
  ;; Field 0: base Ty pointer.
  ;; Field 1: predicate opaque ptr — verify.wat owns the Predicate
  ;;          structure; ty.wat carries the ptr per verify.wat:39
  ;;          precedent. The verify_smt swap (B.6 / Arc F.1) walks
  ;;          the Predicate ADT structurally.
  (func $ty_make_trefined (param $base i32) (param $pred i32) (result i32)
    (local $t i32)
    (local.set $t (call $make_record (i32.const 111) (i32.const 2)))
    (call $record_set (local.get $t) (i32.const 0) (local.get $base))
    (call $record_set (local.get $t) (i32.const 1) (local.get $pred))
    (local.get $t))

  (func $ty_trefined_base (param $t i32) (result i32)
    (call $record_get (local.get $t) (i32.const 0)))

  (func $ty_trefined_pred (param $t i32) (result i32)
    (call $record_get (local.get $t) (i32.const 1)))

  ;; ─── 112 = TCont(Ty, ResumeDiscipline) — arity 2 ─────────────────
  ;; Field 0: return Ty pointer.
  ;; Field 1: ResumeDiscipline sentinel (250-252).
  ;; Per spec 02: handler continuation type — Hβ.lower's
  ;; $classify_handler reads the discipline field via $ty_tcont_discipline
  ;; to choose TailResumptive / Linear / MultiShot lowering strategy.
  (func $ty_make_tcont (param $ret i32) (param $disc i32) (result i32)
    (local $t i32)
    (local.set $t (call $make_record (i32.const 112) (i32.const 2)))
    (call $record_set (local.get $t) (i32.const 0) (local.get $ret))
    (call $record_set (local.get $t) (i32.const 1) (local.get $disc))
    (local.get $t))

  (func $ty_tcont_return (param $t i32) (result i32)
    (call $record_get (local.get $t) (i32.const 0)))

  (func $ty_tcont_discipline (param $t i32) (result i32)
    (call $record_get (local.get $t) (i32.const 1)))

  ;; ─── 113 = TAlias(String, Ty) — arity 2 (RN.1 substrate) ─────────
  ;; Field 0: alias name string ptr (e.g. "Port" for type Port = Refined(Int, ...)).
  ;; Field 1: resolved Ty pointer (the type the alias unwraps to).
  ;;
  ;; Per src/types.nx:48 — preserves authored alias name for intent-aware
  ;; rendering. show_type at src/types.nx:815 returns the alias name
  ;; verbatim rather than expanding the resolved Ty for diagnostics —
  ;; the user reads "Port" instead of "Refined(Int, port_predicate)".
  ;; $chase_deep does NOT unwrap TAlias (would lose the intent edge);
  ;; the unwrap belongs to a peer $ty_unalias helper if a downstream
  ;; consumer needs the resolved form.
  (func $ty_make_talias (param $name i32) (param $resolved i32)
                         (result i32)
    (local $t i32)
    (local.set $t (call $make_record (i32.const 113) (i32.const 2)))
    (call $record_set (local.get $t) (i32.const 0) (local.get $name))
    (call $record_set (local.get $t) (i32.const 1) (local.get $resolved))
    (local.get $t))

  (func $ty_talias_name (param $t i32) (result i32)
    (call $record_get (local.get $t) (i32.const 0)))

  (func $ty_talias_resolved (param $t i32) (result i32)
    (call $record_get (local.get $t) (i32.const 1)))

  ;; ─── Per-variant predicates ──────────────────────────────────────
  ;; Each $is_t<variant> compares $ty_tag against the variant's tag.
  ;; Used by $unify_shapes per spec 04 (one match arm per variant pair)
  ;; + $lookup_ty per spec 05 (NBound dispatch).

  (func $is_tint (param $t i32) (result i32)
    (i32.eq (call $ty_tag (local.get $t)) (i32.const 100)))

  (func $is_tfloat (param $t i32) (result i32)
    (i32.eq (call $ty_tag (local.get $t)) (i32.const 101)))

  (func $is_tstring (param $t i32) (result i32)
    (i32.eq (call $ty_tag (local.get $t)) (i32.const 102)))

  (func $is_tunit (param $t i32) (result i32)
    (i32.eq (call $ty_tag (local.get $t)) (i32.const 103)))

  (func $is_tvar (param $t i32) (result i32)
    (i32.eq (call $ty_tag (local.get $t)) (i32.const 104)))

  (func $is_tlist (param $t i32) (result i32)
    (i32.eq (call $ty_tag (local.get $t)) (i32.const 105)))

  (func $is_ttuple (param $t i32) (result i32)
    (i32.eq (call $ty_tag (local.get $t)) (i32.const 106)))

  (func $is_tfun (param $t i32) (result i32)
    (i32.eq (call $ty_tag (local.get $t)) (i32.const 107)))

  (func $is_tname (param $t i32) (result i32)
    (i32.eq (call $ty_tag (local.get $t)) (i32.const 108)))

  (func $is_trecord (param $t i32) (result i32)
    (i32.eq (call $ty_tag (local.get $t)) (i32.const 109)))

  (func $is_trecordopen (param $t i32) (result i32)
    (i32.eq (call $ty_tag (local.get $t)) (i32.const 110)))

  (func $is_trefined (param $t i32) (result i32)
    (i32.eq (call $ty_tag (local.get $t)) (i32.const 111)))

  (func $is_tcont (param $t i32) (result i32)
    (i32.eq (call $ty_tag (local.get $t)) (i32.const 112)))

  (func $is_talias (param $t i32) (result i32)
    (i32.eq (call $ty_tag (local.get $t)) (i32.const 113)))

  ;; ─── 250-252 = ResumeDiscipline (3 nullary sentinels) ────────────
  ;; Per src/types.nx:70-73 + Hβ-infer §2.3 + Hβ-lower §3.1 (relocated
  ;; 220→250 for tag uniqueness with reason.wat). Same nullary-sentinel
  ;; discipline as TInt/TFloat/TString/TUnit — values are i32 const
  ;; sentinels; no heap allocation. Hβ.lower's $classify_handler
  ;; reads via $ty_tcont_discipline + compares against these constants.

  (func $resume_make_oneshot (result i32)
    (i32.const 250))

  (func $resume_make_multishot (result i32)
    (i32.const 251))

  (func $resume_make_either (result i32)
    (i32.const 252))

  (func $is_resume_oneshot (param $d i32) (result i32)
    (i32.eq (call $tag_of (local.get $d)) (i32.const 250)))

  (func $is_resume_multishot (param $d i32) (result i32)
    (i32.eq (call $tag_of (local.get $d)) (i32.const 251)))

  (func $is_resume_either (param $d i32) (result i32)
    (i32.eq (call $tag_of (local.get $d)) (i32.const 252)))

  ;; ─── ERROR_DEEP_CHASE sentinel constructor ───────────────────────
  ;; Returns TName("ERROR_DEEP_CHASE", []) — the cycle-overflow sentinel
  ;; produced by $chase_deep when depth exceeds 100. The TName variant
  ;; lets downstream callers ($is_tname + $ty_tname_name) detect + render
  ;; the error via emit_diag.wat (Tier 6) without a special-case Ty
  ;; variant. Per Anchor 0 dream-code: callers should never encounter
  ;; this in well-formed inputs; cycle detection is the productive-
  ;; under-error fallback.
  ;;
  ;; The string lives in the data segment at offset 1600 (16-byte
  ;; "ERROR_DEEP_CHASE" with 4-byte length prefix); the empty args
  ;; list is freshly allocated each call (could be amortized to a
  ;; module-level cached singleton; deferred until profiling shows hot).
  (func $ty_error_deep_chase (result i32)
    (call $ty_make_tname
      (i32.const 1600)            ;; "ERROR_DEEP_CHASE" string ptr
      (call $make_list (i32.const 0))))

  ;; ─── $chase_deep — recursive Ty walker via $graph_chase ──────────
  ;; Per Hβ-infer-substrate.md §2.3 + §2.4. Walks the Ty structure
  ;; recursively, following TVar(handle) through $graph_chase + recursing
  ;; on the resolved Ty. Cycle bound at depth 100; on overflow returns
  ;; $ty_error_deep_chase (TName("ERROR_DEEP_CHASE", [])).
  ;;
  ;; Dispatches on $ty_tag (which uses $tag_of's heap-base threshold):
  ;;   - Nullary sentinels (TInt/TFloat/TString/TUnit, ResumeDiscipline
  ;;     sentinels passed in via TCont's discipline field): return as-is.
  ;;   - TVar(handle): chase through $graph_chase; if NBound, recurse on
  ;;     the resolved Ty payload; if NFree/NErrorHole/NRowFree/NRowBound,
  ;;     return the original TVar (unbound type variable preserved per
  ;;     spec 04 § Ownership inference — generalize quantifies these).
  ;;   - TList(elem): rebuild with chased elem.
  ;;   - TTuple(elems): rebuild with chased elements (List walk).
  ;;   - TFun(params, ret, row): rebuild with chased ret (params + row
  ;;     opaque per the TParam-substrate-pending discipline).
  ;;   - TName(name, args): rebuild with chased args.
  ;;   - TRecord(fields): preserve fields opaque (fields-pair substrate
  ;;     pending; same opaque discipline as TParam).
  ;;   - TRecordOpen(fields, rowvar): preserve fields + rowvar opaque.
  ;;   - TRefined(base, pred): rebuild with chased base; preserve pred ptr.
  ;;   - TCont(ret, disc): rebuild with chased ret; preserve discipline
  ;;     sentinel.
  ;;   - TAlias(name, resolved): preserve as-is — chase_deep does NOT
  ;;     unwrap aliases (preserves intent edge per RN.1 substrate).
  ;;
  ;; Returns a fully-resolved Ty (no TVar handles still pointing at
  ;; NBound chains in the graph). Used by $generalize (scheme.wat —
  ;; pending) at FnStmt exit + $lookup_ty (lower.wat — pending) when
  ;; lower needs the terminal Ty for emit handoff.
  (func $chase_deep (param $ty i32) (result i32)
    (call $chase_deep_loop (local.get $ty) (i32.const 0)))

  (func $chase_deep_loop (param $ty i32) (param $depth i32) (result i32)
    (local $tag i32)
    (local $g i32) (local $nk i32) (local $nk_tag i32)
    ;; Cycle bound — same threshold as $graph_chase.
    (if (i32.gt_u (local.get $depth) (i32.const 100))
      (then (return (call $ty_error_deep_chase))))
    (local.set $tag (call $ty_tag (local.get $ty)))
    ;; ── Nullary Ty sentinels — return as-is ──────────────────────
    (if (i32.eq (local.get $tag) (i32.const 100))   ;; TInt
      (then (return (local.get $ty))))
    (if (i32.eq (local.get $tag) (i32.const 101))   ;; TFloat
      (then (return (local.get $ty))))
    (if (i32.eq (local.get $tag) (i32.const 102))   ;; TString
      (then (return (local.get $ty))))
    (if (i32.eq (local.get $tag) (i32.const 103))   ;; TUnit
      (then (return (local.get $ty))))
    ;; ── TVar(handle) — chase through graph + recurse ─────────────
    (if (i32.eq (local.get $tag) (i32.const 104))
      (then
        (local.set $g
          (call $graph_chase (call $ty_tvar_handle (local.get $ty))))
        (local.set $nk (call $gnode_kind (local.get $g)))
        (local.set $nk_tag (call $node_kind_tag (local.get $nk)))
        ;; NBound — recurse on the resolved Ty payload.
        (if (i32.eq (local.get $nk_tag) (i32.const 60))   ;; NBOUND
          (then
            (return
              (call $chase_deep_loop
                (call $node_kind_payload (local.get $nk))
                (i32.add (local.get $depth) (i32.const 1))))))
        ;; NFree / NErrorHole / NRowFree / NRowBound — return original
        ;; TVar (the type variable is genuinely unbound; generalize
        ;; quantifies these per spec 04 §Generalizations).
        (return (local.get $ty))))
    ;; ── TList(elem) — rebuild with chased elem ───────────────────
    (if (i32.eq (local.get $tag) (i32.const 105))
      (then
        (return
          (call $ty_make_tlist
            (call $chase_deep_loop
              (call $ty_tlist_elem (local.get $ty))
              (i32.add (local.get $depth) (i32.const 1)))))))
    ;; ── TTuple(elems) — rebuild with chased element list ─────────
    (if (i32.eq (local.get $tag) (i32.const 106))
      (then
        (return
          (call $ty_make_ttuple
            (call $chase_deep_list
              (call $ty_ttuple_elems (local.get $ty))
              (i32.add (local.get $depth) (i32.const 1)))))))
    ;; ── TFun(params, ret, row) — rebuild with chased ret ─────────
    ;; Params + row preserved opaque (TParam substrate + row.wat own
    ;; their own chase semantics; when those land peer chase helpers
    ;; reach in).
    (if (i32.eq (local.get $tag) (i32.const 107))
      (then
        (return
          (call $ty_make_tfun
            (call $ty_tfun_params (local.get $ty))
            (call $chase_deep_loop
              (call $ty_tfun_return (local.get $ty))
              (i32.add (local.get $depth) (i32.const 1)))
            (call $ty_tfun_row (local.get $ty))))))
    ;; ── TName(name, args) — rebuild with chased args list ────────
    (if (i32.eq (local.get $tag) (i32.const 108))
      (then
        (return
          (call $ty_make_tname
            (call $ty_tname_name (local.get $ty))
            (call $chase_deep_list
              (call $ty_tname_args (local.get $ty))
              (i32.add (local.get $depth) (i32.const 1)))))))
    ;; ── TRecord(fields) — preserve fields opaque ─────────────────
    ;; Pair substrate pending; same opaque discipline as TParam.
    (if (i32.eq (local.get $tag) (i32.const 109))
      (then (return (local.get $ty))))
    ;; ── TRecordOpen(fields, rowvar) — preserve opaque ────────────
    (if (i32.eq (local.get $tag) (i32.const 110))
      (then (return (local.get $ty))))
    ;; ── TRefined(base, pred) — rebuild with chased base ──────────
    (if (i32.eq (local.get $tag) (i32.const 111))
      (then
        (return
          (call $ty_make_trefined
            (call $chase_deep_loop
              (call $ty_trefined_base (local.get $ty))
              (i32.add (local.get $depth) (i32.const 1)))
            (call $ty_trefined_pred (local.get $ty))))))
    ;; ── TCont(ret, disc) — rebuild with chased ret ──────────────
    (if (i32.eq (local.get $tag) (i32.const 112))
      (then
        (return
          (call $ty_make_tcont
            (call $chase_deep_loop
              (call $ty_tcont_return (local.get $ty))
              (i32.add (local.get $depth) (i32.const 1)))
            (call $ty_tcont_discipline (local.get $ty))))))
    ;; ── TAlias(name, resolved) — preserve verbatim (RN.1) ───────
    ;; chase_deep does NOT unwrap TAlias — that would lose the intent
    ;; edge (show_type prefers the alias name over the expanded form).
    ;; Peer $ty_unalias helper is the one that follows the resolved
    ;; pointer when callers genuinely need the unwrapped Ty.
    (if (i32.eq (local.get $tag) (i32.const 113))
      (then (return (local.get $ty))))
    ;; ── Unknown tag — well-formed Ty cannot get here. Trap. ──────
    ;; Per H6 wildcard discipline + drift mode 9: NO `_ => fabricated`
    ;; default. Surface the bug rather than silently absorb a new variant.
    (unreachable))

  ;; $chase_deep_list — apply $chase_deep_loop to each element of a
  ;; flat list, returning a fresh flat list. Caller's depth budget
  ;; is forwarded to the per-element recursion.
  ;;
  ;; The list is materialized as flat (callers pass element lists from
  ;; TTuple/TName/etc. which are typically flat post-parse). Per the
  ;; CLAUDE.md bug-class on $list_index in hot loops: this walker is
  ;; bounded by Ty arity (small N typically); $list_to_flat at hot
  ;; entrances is the wheel's discipline if a non-flat list shows up.
  (func $chase_deep_list (param $list i32) (param $depth i32) (result i32)
    (local $n i32) (local $i i32) (local $out i32)
    (local.set $n (call $len (local.get $list)))
    (local.set $out (call $make_list (local.get $n)))
    (local.set $i (i32.const 0))
    (block $done
      (loop $iter
        (br_if $done (i32.ge_u (local.get $i) (local.get $n)))
        (drop
          (call $list_set
            (local.get $out)
            (local.get $i)
            (call $chase_deep_loop
              (call $list_index (local.get $list) (local.get $i))
              (local.get $depth))))
        (local.set $i (i32.add (local.get $i) (i32.const 1)))
        (br $iter)))
    (local.get $out))
