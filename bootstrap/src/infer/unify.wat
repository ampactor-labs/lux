  ;; ═══ unify.wat — Type unification engine (Tier 6) ═════════════════
  ;; Implements: Hβ-infer-substrate.md §3 (the unify primitive — lines
  ;;             333-407) + §6.2 (eight interrogations at unify) + §7.1
  ;;             (forbidden patterns) + §8.1 unify.wat row + §8.4 ~700-
  ;;             line estimate + §11 acceptance. Realizes the
  ;;             unification core of primitive #8 (HM inference) at the
  ;;             seed substrate: every type relationship Hβ.infer's walk
  ;;             arms discover routes through this chunk via $unify(h_a,
  ;;             h_b, span, reason); the graph mutates via $graph_chase
  ;;             + $graph_bind + $graph_bind_kind; mismatches surface via
  ;;             emit_diag.wat helpers; productive-under-error per Hazel
  ;;             (POPL 2024) — every detected mismatch binds NErrorHole
  ;;             + returns; the walk continues.
  ;;
  ;; Exports:    $unify, $unify_types, $unify_type_lists,
  ;;             $unify_param_lists, $unify_record_fields_closed,
  ;;             $unify_record_fields_loop, $unify_record_open_against_closed,
  ;;             $unify_record_open_subset, $unify_two_open_records,
  ;;             $pair_fn_params, $try_tuple_decompose,
  ;;             $unify_tuple_elems_with_params, $param_types_flat,
  ;;             $occurs_in, $expect_same, $same_ground, $type_mismatch,
  ;;             $arity_mismatch, $find_record_field_pos,
  ;;             $find_record_field_pos_loop, $intersect_record_fields,
  ;;             $intersect_record_fields_loop, $record_fields_diff,
  ;;             $record_fields_diff_loop, $mk_record_row_residual
  ;; Uses:       $graph_chase / $graph_bind / $graph_bind_row /
  ;;               $graph_bind_kind / $gnode_kind / $node_kind_tag /
  ;;               $node_kind_payload / $node_kind_make_nerrorhole /
  ;;               $graph_fresh_ty (graph.wat),
  ;;             $make_record / $record_get / $record_set / $tag_of
  ;;               (record.wat),
  ;;             $make_list / $list_index / $list_set /
  ;;               $list_extend_to / $len / $slice (list.wat),
  ;;             $str_eq / $str_concat (str.wat),
  ;;             $eprint_string (wasi.wat),
  ;;             $int_to_str (int.wat),
  ;;             $ty_tag / $ty_tvar_handle / $ty_tlist_elem /
  ;;               $ty_ttuple_elems / $ty_tfun_params / $ty_tfun_return /
  ;;               $ty_tfun_row / $ty_tname_name / $ty_tname_args /
  ;;               $ty_trecord_fields / $ty_trecordopen_fields /
  ;;               $ty_trecordopen_rowvar / $ty_trefined_base /
  ;;               $ty_tcont_return / $ty_talias_resolved /
  ;;               $ty_make_tvar / $ty_make_ttuple / $ty_make_trecord
  ;;               (ty.wat),
  ;;             $tparam_ty / $field_pair_name / $field_pair_ty
  ;;               (tparam.wat),
  ;;             $free_in_ty (scheme.wat),
  ;;             $reason_make_located / $reason_make_listelement /
  ;;               $reason_make_fnreturn (reason.wat),
  ;;             $infer_emit_type_mismatch / $infer_emit_occurs_check /
  ;;               $infer_emit_record_field_extra /
  ;;               $infer_emit_record_field_missing (emit_diag.wat).
  ;; Test:       bootstrap/test/infer/unify_ground_match.wat,
  ;;             bootstrap/test/infer/unify_ground_mismatch.wat,
  ;;             bootstrap/test/infer/unify_var_bind_no_occurs.wat,
  ;;             bootstrap/test/infer/unify_var_bind_occurs_fail.wat
  ;;
  ;; ═══ DESIGN ═══════════════════════════════════════════════════════
  ;;
  ;; What unification IS. Per DESIGN.md §0.5 + src/types.mn:21: the
  ;; graph IS the substitution. There is no Algorithm-W (subst, type)
  ;; tuple threaded through unification; there is no constraint set;
  ;; there is no UnifyM monad. $unify(h_a, h_b, span, reason) walks the
  ;; graph: chase both handles, dispatch on the (NodeKind_a, NodeKind_b)
  ;; pair, recurse on the underlying Ty pair via $unify_types' 14-arm
  ;; shape dispatch. Mutations land via $graph_bind / $graph_bind_kind;
  ;; both write the trail entry that supports rollback and bump the
  ;; epoch that observers key on. No sidecar.
  ;;
  ;; Hazel productive-under-error (POPL 2024). Per spec 04 §Error
  ;; handling + §3 of the walkthrough: a detected mismatch is NOT a halt.
  ;; Each mismatch path is a four-step discipline: (1) emit the
  ;; diagnostic on stderr via the emit_diag.wat helper; (2) write the
  ;; UnifyFailed/Inferred Reason; (3) bind the offending handle to
  ;; NErrorHole carrying that Reason; (4) return so the walk continues.
  ;; Every emit helper (already landed in emit_diag.wat) bakes steps 1+2+3
  ;; together; this chunk's $type_mismatch and $arity_mismatch arms call
  ;; them with the appropriate handle.
  ;;
  ;; Row preservation. TFun's row field is opaque carry through this
  ;; chunk. Per Hβ-infer-substrate.md §8.1's unify.wat row + §12 named
  ;; follow-up Hβ.infer.row-normalize: the canonical $unify_row + row.wat
  ;; primitives ship as a peer chunk. unify.wat's TFun arm unifies
  ;; params + return; the row field is preserved verbatim and the
  ;; eventual row.wat sibling will compose on the same NRowBound /
  ;; NRowFree dispatch shape.
  ;;
  ;; Refinement composition. Per Hβ-infer-substrate.md §6.2 answer-6 +
  ;; §12 named follow-up Hβ.infer.refinement-compose: TRefined's
  ;; predicate field is opaque carry at the seed; verify.wat's
  ;; $verify_record fires the actual PAnd composition when verify-effect
  ;; lands. Seed unifies BASE TYPES of paired TRefined arms only; TRefined
  ;; vs non-TRefined unwraps the LEFT base and recurses.
  ;;
  ;; Symmetric arms. Per src/infer.mn:1083 et al: when LEFT side of
  ;; $unify_types is non-TVar and RIGHT is TVar(_), the canonical
  ;; algorithm recurses with arguments flipped — `unify_types(b, a, ...)`.
  ;; This compresses what would otherwise be N copies of TVar-handling
  ;; into one TVar arm. Each compound arm (TList / TTuple / TFun / TName /
  ;; TRecord / TRecordOpen / TCont / TAlias) checks (b is TVar) BEFORE
  ;; falling to $type_mismatch and recurses with arguments swapped.
  ;;
  ;; ═══ EIGHT INTERROGATIONS (per Hβ-infer-substrate.md §6.2) ════════
  ;; 1. Graph?      $graph_chase reads, $graph_bind / $graph_bind_kind /
  ;;                $graph_bind_row write — the ONLY mutations this chunk
  ;;                emits. No side-channel.
  ;; 2. Handler?    Direct seed function. The wheel routes via report +
  ;;                graph_bind effects; both have @resume=OneShot per
  ;;                Hβ-infer-substrate.md §3 closing.
  ;; 3. Verb?       N/A — primitive call from walk_expr.wat / walk_stmt.wat
  ;;                arms; topology lives at the call sites.
  ;; 4. Row?        TFun row preserved verbatim (see DESIGN above). NRowBound /
  ;;                NRowFree carry to row.wat (named follow-up).
  ;; 5. Ownership?  Both handles are `ref` — unify reads the GNodes via
  ;;                $graph_chase, writes new GNode records via $graph_bind.
  ;;                The new GNode allocation is the only fresh ownership.
  ;; 6. Refinement? TRefined arm unifies bases only at seed; predicate
  ;;                composition is opaque carry per DESIGN above.
  ;; 7. Gradient?   Each successful $graph_bind narrows NFree → NBound —
  ;;                one gradient step per the Mentl voice's vocabulary.
  ;; 8. Reason?     Every $graph_bind in this chunk carries the Located
  ;;                wrap of (span, reason); arm-specific rewraps via
  ;;                $reason_make_listelement (TList recursion) and
  ;;                $reason_make_fnreturn (TFun return recursion).
  ;;
  ;; ═══ FORBIDDEN PATTERNS AUDIT (per Hβ-infer-substrate.md §7.1) ════
  ;; - Drift 1 (Rust vtable):     i32.eq dispatch on tag constants;
  ;;                              NO closure-of-handlers table, NO
  ;;                              vtable-by-tag indirection.
  ;; - Drift 2 (Scheme env frame): graph IS the substitution. NO
  ;;                              current_substitution parameter
  ;;                              threaded through unify.
  ;; - Drift 3 (Python dict / string-keyed): Ty variants dispatch via
  ;;                              i32 tag constants 100-113. The TName
  ;;                              arm uses $str_eq for nominal name
  ;;                              equality — that is structural payload
  ;;                              comparison, not flag-as-string.
  ;; - Drift 4 (Haskell monad transformer): $unify is a direct WAT
  ;;                              function. NO UnifyM / InferM /
  ;;                              constraint-set machinery.
  ;; - Drift 5 (C calling convention): $unify takes (h_a, h_b, span,
  ;;                              reason) — four i32 params. NO bundled
  ;;                              context-struct + state-pointer.
  ;; - Drift 6 (primitive-type-special-case): TInt / TFloat / TString /
  ;;                              TUnit all share the same $expect_same
  ;;                              path. No carve-out.
  ;; - Drift 7 (parallel-arrays):  TParam list = list-of-records via
  ;;                              tparam.wat; field-pair list =
  ;;                              list-of-records via tparam.wat. NO
  ;;                              parallel name[]/ty[] arrays.
  ;; - Drift 8 (mode flag):        ONE $unify; mismatches emit + bind
  ;;                              NErrorHole + return. NO mode: i32 for
  ;;                              "strict" / "lax" / "subtype".
  ;; - Drift 9 (deferred-by-omission): All 14 Ty variants have explicit
  ;;                              arms in $unify_types. All 5 NodeKind
  ;;                              cases handled in $unify. NO `_ =>`
  ;;                              fallback. Row + refinement gaps NAMED
  ;;                              as peer follow-ups (Hβ.infer.row-
  ;;                              normalize, Hβ.infer.refinement-compose)
  ;;                              in DESIGN above per §12.
  ;;
  ;; Foreign-fluency forbiddens (per Hβ-infer-substrate.md §7.1 table):
  ;;   NO "Algorithm W (subst, type)" return shape.
  ;;   NO "constraint set" / "Pottier CHKL" vocabulary.
  ;;   NO "Algorithm M bidirectional" framing.
  ;;   NO "exception machinery" — Hazel productive-under-error replaces it.

  ;; ─── Data segments (offsets 3008-3120, below HEAP_BASE 4096) ──────
  ;; emit_diag.wat ends at 2933 (last segment "<" at 2928, payload 1
  ;; byte → 2932 inclusive). 3008 leaves 75 bytes of headroom.
  ;;
  ;; Length-prefix discipline: each (data) segment writes the i32 length
  ;; header (LE byte-encoded) followed by the UTF-8 payload. The payload
  ;; byte-count MUST match the prefix byte-count. Verified by inspection:
  ;;   3008  "fn"                          → 2 bytes  → \02\00\00\00
  ;;   3024  "function arity mismatch: "   → 25 bytes → \19\00\00\00
  ;;   3056  " param(s) vs "               → 13 bytes → \0d\00\00\00
  ;;   3072  " param(s)"                   → 9 bytes  → \09\00\00\00
  ;;   3088  "type list arity mismatch: "  → 26 bytes → \1a\00\00\00
  ;;   3120  " vs "                        → 4 bytes  → \04\00\00\00
  ;;
  ;; Per-segment offsets are 16-aligned to keep visual inspection of WAT
  ;; consistent (matches emit_diag.wat's 32-byte slot convention loosely;
  ;; this chunk's six segments fit within a 16-byte cadence).
  (data (i32.const 3008) "\02\00\00\00fn")
  (data (i32.const 3024) "\19\00\00\00function arity mismatch: ")
  (data (i32.const 3056) "\0d\00\00\00 param(s) vs ")
  (data (i32.const 3072) "\09\00\00\00 param(s)")
  (data (i32.const 3088) "\1a\00\00\00type list arity mismatch: ")
  (data (i32.const 3120) "\04\00\00\00 vs ")

  ;; ─── $unify — entry-point dispatch ───────────────────────────────
  ;;
  ;; Per src/infer.mn:1038-1058 + Hβ-infer-substrate.md §3:
  ;; identity short-circuit; chase both handles; dispatch on
  ;; (NodeKind_a, NodeKind_b).
  ;;
  ;; NodeKind tags from graph.wat:55-59:
  ;;   60 = NBOUND        — payload is a Ty pointer
  ;;   61 = NFREE         — payload is the epoch the handle was minted at
  ;;   62 = NROWBOUND     — payload is a Row pointer (row.wat follow-up)
  ;;   63 = NROWFREE      — payload is the epoch (row.wat follow-up)
  ;;   64 = NERRORHOLE    — productive-under-error sink, no recursion
  (func $unify (param $h_a i32) (param $h_b i32)
                (param $span i32) (param $reason i32)
    (local $na i32) (local $nb i32)
    (local $ka i32) (local $kb i32)
    (local $ta i32) (local $tb i32)
    (local $located i32)

    ;; Identity short-circuit (src/infer.mn:1039)
    (if (i32.eq (local.get $h_a) (local.get $h_b))
      (then (return)))

    (local.set $na (call $graph_chase (local.get $h_a)))
    (local.set $nb (call $graph_chase (local.get $h_b)))
    (local.set $ka (call $node_kind_tag (call $gnode_kind (local.get $na))))
    (local.set $kb (call $node_kind_tag (call $gnode_kind (local.get $nb))))

    (local.set $located (call $reason_make_located
      (local.get $span) (local.get $reason)))

    ;; ka = NFree (61): bind h_a → TVar(h_b) regardless of kb
    ;; (src/infer.mn:1046-1047)
    (if (i32.eq (local.get $ka) (i32.const 61))
      (then
        (call $graph_bind (local.get $h_a)
                          (call $ty_make_tvar (local.get $h_b))
                          (local.get $located))
        (return)))

    ;; ka = NBound (60): payload Ty pointer; behavior depends on kb
    (if (i32.eq (local.get $ka) (i32.const 60))
      (then
        ;; kb = NFree: bind h_b → TVar(h_a)
        (if (i32.eq (local.get $kb) (i32.const 61))
          (then
            (call $graph_bind (local.get $h_b)
                              (call $ty_make_tvar (local.get $h_a))
                              (local.get $located))
            (return)))
        ;; kb = NBound: extract Ty payloads + recurse via $unify_types
        (if (i32.eq (local.get $kb) (i32.const 60))
          (then
            (local.set $ta (call $node_kind_payload (call $gnode_kind (local.get $na))))
            (local.set $tb (call $node_kind_payload (call $gnode_kind (local.get $nb))))
            (call $unify_types
              (local.get $ta) (local.get $tb)
              (local.get $span) (local.get $reason))
            (return)))
        ;; kb = NErrorHole / NRowBound / NRowFree: no-op per src/infer.mn:1052-1053
        (return)))

    ;; ka = NErrorHole (64): no-op (src/infer.mn:1055)
    (if (i32.eq (local.get $ka) (i32.const 64))
      (then (return)))

    ;; ka = NRowBound (62) / NRowFree (63): no-op at seed.
    ;; row.wat owns the row-side dispatch per Hβ-infer-substrate.md §12
    ;; named follow-up Hβ.infer.row-normalize. The seed's $unify accepts
    ;; row-handles silently to keep the call surface uniform across
    ;; ty/row dispatch (drift mode 8 — no separate $unify_row at the
    ;; call site).
    (if (i32.eq (local.get $ka) (i32.const 62))
      (then (return)))
    (if (i32.eq (local.get $ka) (i32.const 63))
      (then (return)))

    ;; Per H6 wildcard discipline + drift mode 9: every NodeKind tag
    ;; in graph.wat:55-59 is enumerated above. Unknown ka is a graph
    ;; corruption — surface it.
    (unreachable))

  ;; ─── $unify_types — 14-arm shape dispatcher ──────────────────────
  ;;
  ;; Per src/infer.mn:1060-1175. Dispatches on Ty's tag (100-113) for
  ;; the LEFT side; each arm handles RIGHT-side cases. TVar on the right
  ;; is handled in each compound arm by recursive flip.
  ;;
  ;; Ty tags from ty.wat:251-432:
  ;;   100=TInt, 101=TFloat, 102=TString, 103=TUnit (nullary sentinels)
  ;;   104=TVar, 105=TList, 106=TTuple, 107=TFun
  ;;   108=TName, 109=TRecord, 110=TRecordOpen
  ;;   111=TRefined, 112=TCont, 113=TAlias
  (func $unify_types (param $a i32) (param $b i32)
                      (param $span i32) (param $reason i32)
    (local $ta i32) (local $tb i32)
    (local $ha i32) (local $hb i32)
    (local $la i32) (local $lb i32)
    (local $located i32)
    (local $base_a i32)
    (local $resolved_a i32) (local $resolved_b i32)

    (local.set $ta (call $ty_tag (local.get $a)))

    ;; ── 100 TInt / 101 TFloat / 102 TString / 103 TUnit ─────────────
    ;; Ground scalars: $expect_same handles TVar-on-right + ground-match.
    ;; Per drift mode 6: all four sentinels share one path; no carve-out.
    (if (i32.eq (local.get $ta) (i32.const 100))
      (then
        (call $expect_same (local.get $a) (local.get $b)
                            (local.get $span) (local.get $reason))
        (return)))
    (if (i32.eq (local.get $ta) (i32.const 101))
      (then
        (call $expect_same (local.get $a) (local.get $b)
                            (local.get $span) (local.get $reason))
        (return)))
    (if (i32.eq (local.get $ta) (i32.const 102))
      (then
        (call $expect_same (local.get $a) (local.get $b)
                            (local.get $span) (local.get $reason))
        (return)))
    (if (i32.eq (local.get $ta) (i32.const 103))
      (then
        (call $expect_same (local.get $a) (local.get $b)
                            (local.get $span) (local.get $reason))
        (return)))

    ;; ── 104 TVar(ha) ────────────────────────────────────────────────
    ;; Per src/infer.mn:1067-1078:
    ;;   if b is TVar(hb) → $unify on the two handles
    ;;   else            → occurs-check; bind ha → b (or emit on cycle)
    (if (i32.eq (local.get $ta) (i32.const 104))
      (then
        (local.set $ha (call $ty_tvar_handle (local.get $a)))
        (local.set $tb (call $ty_tag (local.get $b)))
        (if (i32.eq (local.get $tb) (i32.const 104))
          (then
            (local.set $hb (call $ty_tvar_handle (local.get $b)))
            (call $unify (local.get $ha) (local.get $hb)
                          (local.get $span) (local.get $reason))
            (return)))
        ;; b is non-TVar: occurs-check, then bind or emit
        (if (call $occurs_in (local.get $ha) (local.get $b))
          (then
            (call $infer_emit_occurs_check
              (local.get $ha) (local.get $b) (local.get $reason))
            (return)))
        (local.set $located (call $reason_make_located
          (local.get $span) (local.get $reason)))
        (call $graph_bind (local.get $ha) (local.get $b) (local.get $located))
        (return)))

    ;; ── 105 TList(ea) ──────────────────────────────────────────────
    ;; Per src/infer.mn:1080-1085. Element recursion threads
    ;; ListElement(reason) Reason rewrap.
    (if (i32.eq (local.get $ta) (i32.const 105))
      (then
        (local.set $tb (call $ty_tag (local.get $b)))
        (if (i32.eq (local.get $tb) (i32.const 105))
          (then
            (call $unify_types
              (call $ty_tlist_elem (local.get $a))
              (call $ty_tlist_elem (local.get $b))
              (local.get $span)
              (call $reason_make_listelement (local.get $reason)))
            (return)))
        (if (i32.eq (local.get $tb) (i32.const 104))
          (then
            (call $unify_types (local.get $b) (local.get $a)
                                (local.get $span) (local.get $reason))
            (return)))
        (call $type_mismatch (local.get $a) (local.get $b)
                              (local.get $span) (local.get $reason))
        (return)))

    ;; ── 106 TTuple(ea) ─────────────────────────────────────────────
    ;; Per src/infer.mn:1087-1092. Element-list pairwise unification.
    (if (i32.eq (local.get $ta) (i32.const 106))
      (then
        (local.set $tb (call $ty_tag (local.get $b)))
        (if (i32.eq (local.get $tb) (i32.const 106))
          (then
            (call $unify_type_lists
              (call $ty_ttuple_elems (local.get $a))
              (call $ty_ttuple_elems (local.get $b))
              (local.get $span) (local.get $reason))
            (return)))
        (if (i32.eq (local.get $tb) (i32.const 104))
          (then
            (call $unify_types (local.get $b) (local.get $a)
                                (local.get $span) (local.get $reason))
            (return)))
        (call $type_mismatch (local.get $a) (local.get $b)
                              (local.get $span) (local.get $reason))
        (return)))

    ;; ── 107 TFun(pa, ra, ea) ───────────────────────────────────────
    ;; Per src/infer.mn:1094-1111. Three-step structural unification:
    ;;   $pair_fn_params  — DESIGN Ch 2 Insight 7 tuple-decomposition
    ;;   $unify_types     — return types with FnReturn("fn", reason) Reason
    ;;   row preserved    — see DESIGN Row-preservation paragraph above
    (if (i32.eq (local.get $ta) (i32.const 107))
      (then
        (local.set $tb (call $ty_tag (local.get $b)))
        (if (i32.eq (local.get $tb) (i32.const 107))
          (then
            (call $pair_fn_params
              (call $ty_tfun_params (local.get $a))
              (call $ty_tfun_params (local.get $b))
              (local.get $span) (local.get $reason))
            (call $unify_types
              (call $ty_tfun_return (local.get $a))
              (call $ty_tfun_return (local.get $b))
              (local.get $span)
              (call $reason_make_fnreturn (i32.const 3008) (local.get $reason)))
            ;; Row preserved verbatim — row.wat $row_unify is the named
            ;; Hβ.infer.row-normalize follow-up per Hβ-infer-substrate.md
            ;; §12. Drop the row reads to satisfy WAT (zero-arg discard
            ;; of the chase-side view; the actual row mutation lands when
            ;; row.wat ships).
            (drop (call $ty_tfun_row (local.get $a)))
            (drop (call $ty_tfun_row (local.get $b)))
            (return)))
        (if (i32.eq (local.get $tb) (i32.const 104))
          (then
            (call $unify_types (local.get $b) (local.get $a)
                                (local.get $span) (local.get $reason))
            (return)))
        (call $type_mismatch (local.get $a) (local.get $b)
                              (local.get $span) (local.get $reason))
        (return)))

    ;; ── 108 TName(name, args) ──────────────────────────────────────
    ;; Per src/infer.mn:1113-1121. Nominal equality — name-string match
    ;; (structural payload comparison via $str_eq, NOT flag-as-string
    ;; per drift mode 8) + arg-list unification.
    (if (i32.eq (local.get $ta) (i32.const 108))
      (then
        (local.set $tb (call $ty_tag (local.get $b)))
        (if (i32.eq (local.get $tb) (i32.const 108))
          (then
            (if (call $str_eq
                  (call $ty_tname_name (local.get $a))
                  (call $ty_tname_name (local.get $b)))
              (then
                (call $unify_type_lists
                  (call $ty_tname_args (local.get $a))
                  (call $ty_tname_args (local.get $b))
                  (local.get $span) (local.get $reason))
                (return))
              (else
                (call $type_mismatch (local.get $a) (local.get $b)
                                      (local.get $span) (local.get $reason))
                (return)))))
        (if (i32.eq (local.get $tb) (i32.const 104))
          (then
            (call $unify_types (local.get $b) (local.get $a)
                                (local.get $span) (local.get $reason))
            (return)))
        (call $type_mismatch (local.get $a) (local.get $b)
                              (local.get $span) (local.get $reason))
        (return)))

    ;; ── 109 TRecord(fields) ────────────────────────────────────────
    ;; Per src/infer.mn:1123-1130. Closed × closed → pointwise; closed ×
    ;; open → open-side subset must appear in closed.
    (if (i32.eq (local.get $ta) (i32.const 109))
      (then
        (local.set $tb (call $ty_tag (local.get $b)))
        (if (i32.eq (local.get $tb) (i32.const 109))
          (then
            (call $unify_record_fields_closed
              (call $ty_trecord_fields (local.get $a))
              (call $ty_trecord_fields (local.get $b))
              (local.get $span) (local.get $reason))
            (return)))
        (if (i32.eq (local.get $tb) (i32.const 110))
          (then
            (call $unify_record_open_against_closed
              (call $ty_trecord_fields (local.get $a))
              (call $ty_trecordopen_fields (local.get $b))
              (call $ty_trecordopen_rowvar (local.get $b))
              (local.get $span) (local.get $reason))
            (return)))
        (if (i32.eq (local.get $tb) (i32.const 104))
          (then
            (call $unify_types (local.get $b) (local.get $a)
                                (local.get $span) (local.get $reason))
            (return)))
        (call $type_mismatch (local.get $a) (local.get $b)
                              (local.get $span) (local.get $reason))
        (return)))

    ;; ── 110 TRecordOpen(fields, rowvar) ────────────────────────────
    ;; Per src/infer.mn:1132-1140. Mirror of TRecord arm.
    (if (i32.eq (local.get $ta) (i32.const 110))
      (then
        (local.set $tb (call $ty_tag (local.get $b)))
        (if (i32.eq (local.get $tb) (i32.const 109))
          (then
            (call $unify_record_open_against_closed
              (call $ty_trecord_fields (local.get $b))
              (call $ty_trecordopen_fields (local.get $a))
              (call $ty_trecordopen_rowvar (local.get $a))
              (local.get $span) (local.get $reason))
            (return)))
        (if (i32.eq (local.get $tb) (i32.const 110))
          (then
            (call $unify_two_open_records
              (call $ty_trecordopen_fields (local.get $a))
              (call $ty_trecordopen_rowvar (local.get $a))
              (call $ty_trecordopen_fields (local.get $b))
              (call $ty_trecordopen_rowvar (local.get $b))
              (local.get $span) (local.get $reason))
            (return)))
        (if (i32.eq (local.get $tb) (i32.const 104))
          (then
            (call $unify_types (local.get $b) (local.get $a)
                                (local.get $span) (local.get $reason))
            (return)))
        (call $type_mismatch (local.get $a) (local.get $b)
                              (local.get $span) (local.get $reason))
        (return)))

    ;; ── 111 TRefined(base, pred) ───────────────────────────────────
    ;; Per src/infer.mn:1142-1152 + DESIGN Refinement-composition above.
    ;; Both-TRefined: unify bases (predicate composition is the named
    ;; Hβ.infer.refinement-compose follow-up). TRefined × non-TRefined:
    ;; unwrap LEFT base + recurse.
    (if (i32.eq (local.get $ta) (i32.const 111))
      (then
        (local.set $tb (call $ty_tag (local.get $b)))
        (local.set $base_a (call $ty_trefined_base (local.get $a)))
        (if (i32.eq (local.get $tb) (i32.const 111))
          (then
            (call $unify_types
              (local.get $base_a)
              (call $ty_trefined_base (local.get $b))
              (local.get $span) (local.get $reason))
            (return)))
        ;; LEFT-unwrap recursion (predicate carry opaque per DESIGN above)
        (call $unify_types (local.get $base_a) (local.get $b)
                            (local.get $span) (local.get $reason))
        (return)))

    ;; ── 112 TCont(ret, disc) ───────────────────────────────────────
    ;; Per src/infer.mn:1154-1159. Discipline opaque carry per src/infer.mn:1156
    ;; (canonical also unifies returns only at this layer).
    (if (i32.eq (local.get $ta) (i32.const 112))
      (then
        (local.set $tb (call $ty_tag (local.get $b)))
        (if (i32.eq (local.get $tb) (i32.const 112))
          (then
            (call $unify_types
              (call $ty_tcont_return (local.get $a))
              (call $ty_tcont_return (local.get $b))
              (local.get $span) (local.get $reason))
            (return)))
        (if (i32.eq (local.get $tb) (i32.const 104))
          (then
            (call $unify_types (local.get $b) (local.get $a)
                                (local.get $span) (local.get $reason))
            (return)))
        (call $type_mismatch (local.get $a) (local.get $b)
                              (local.get $span) (local.get $reason))
        (return)))

    ;; ── 113 TAlias(name, resolved) ─────────────────────────────────
    ;; Per src/infer.mn:1161-1167. RN.2 unification alias preservation:
    ;; b TVar → flip; b TAlias → pair resolved bodies; else → unwrap
    ;; LEFT alias + recurse with (resolved_a, b).
    (if (i32.eq (local.get $ta) (i32.const 113))
      (then
        (local.set $tb (call $ty_tag (local.get $b)))
        (local.set $resolved_a (call $ty_talias_resolved (local.get $a)))
        (if (i32.eq (local.get $tb) (i32.const 104))
          (then
            (call $unify_types (local.get $b) (local.get $a)
                                (local.get $span) (local.get $reason))
            (return)))
        (if (i32.eq (local.get $tb) (i32.const 113))
          (then
            (local.set $resolved_b (call $ty_talias_resolved (local.get $b)))
            (call $unify_types (local.get $resolved_a) (local.get $resolved_b)
                                (local.get $span) (local.get $reason))
            (return)))
        (call $unify_types (local.get $resolved_a) (local.get $b)
                            (local.get $span) (local.get $reason))
        (return)))

    ;; Unknown LEFT tag — well-formed Ty cannot reach here. Per H6 +
    ;; drift mode 9: surface the bug rather than silently absorb.
    (unreachable))

  ;; ─── $expect_same — ground-equality + TVar-on-right ──────────────
  ;;
  ;; Per src/infer.mn:1177-1183. If b is TVar(hb), bind hb → a; else
  ;; check $same_ground(a, b); on mismatch route through $type_mismatch.
  (func $expect_same (param $a i32) (param $b i32)
                      (param $span i32) (param $reason i32)
    (local $hb i32)
    (local $located i32)
    (if (i32.eq (call $ty_tag (local.get $b)) (i32.const 104))
      (then
        (local.set $hb (call $ty_tvar_handle (local.get $b)))
        (local.set $located (call $reason_make_located
          (local.get $span) (local.get $reason)))
        (call $graph_bind (local.get $hb) (local.get $a) (local.get $located))
        (return)))
    (if (call $same_ground (local.get $a) (local.get $b))
      (then (return)))
    (call $type_mismatch (local.get $a) (local.get $b)
                          (local.get $span) (local.get $reason)))

  ;; ─── $same_ground — H6 exhaustive Ty enumeration ─────────────────
  ;;
  ;; Per src/infer.mn:1189-1205. Ground scalars (100-103) match their
  ;; same-variant; compound types (104-113) return 0 — same_ground does
  ;; NOT recurse. unify_types handles structural recursion separately.
  ;;
  ;; Per drift mode 9: every Ty variant has its arm; no `_ =>` fallback.
  (func $same_ground (param $a i32) (param $b i32) (result i32)
    (local $ta i32) (local $tb i32)
    (local.set $ta (call $ty_tag (local.get $a)))
    (local.set $tb (call $ty_tag (local.get $b)))
    ;; Ground scalars
    (if (i32.eq (local.get $ta) (i32.const 100))
      (then (return (i32.eq (local.get $tb) (i32.const 100)))))
    (if (i32.eq (local.get $ta) (i32.const 101))
      (then (return (i32.eq (local.get $tb) (i32.const 101)))))
    (if (i32.eq (local.get $ta) (i32.const 102))
      (then (return (i32.eq (local.get $tb) (i32.const 102)))))
    (if (i32.eq (local.get $ta) (i32.const 103))
      (then (return (i32.eq (local.get $tb) (i32.const 103)))))
    ;; Compound types — same_ground rejects; unify_types handles structurally
    (if (i32.eq (local.get $ta) (i32.const 104)) (then (return (i32.const 0))))
    (if (i32.eq (local.get $ta) (i32.const 105)) (then (return (i32.const 0))))
    (if (i32.eq (local.get $ta) (i32.const 106)) (then (return (i32.const 0))))
    (if (i32.eq (local.get $ta) (i32.const 107)) (then (return (i32.const 0))))
    (if (i32.eq (local.get $ta) (i32.const 108)) (then (return (i32.const 0))))
    (if (i32.eq (local.get $ta) (i32.const 109)) (then (return (i32.const 0))))
    (if (i32.eq (local.get $ta) (i32.const 110)) (then (return (i32.const 0))))
    (if (i32.eq (local.get $ta) (i32.const 111)) (then (return (i32.const 0))))
    (if (i32.eq (local.get $ta) (i32.const 112)) (then (return (i32.const 0))))
    (if (i32.eq (local.get $ta) (i32.const 113)) (then (return (i32.const 0))))
    (unreachable))

  ;; ─── $type_mismatch — Hazel productive-under-error: emit + bind ──
  ;;
  ;; Per src/infer.mn:1536-1541 + DESIGN Hazel-productive-under-error
  ;; paragraph above. The canonical algorithm uses `perform report(...)`
  ;; which doesn't itself bind a handle — but the seed's emit_diag.wat
  ;; helper bakes "emit + bind to NErrorHole(UnifyFailed)" together,
  ;; requiring a carrier handle. We mint a fresh diagnostic handle,
  ;; let the helper bind it to NErrorHole, and surface the diagnostic
  ;; on stderr. The walk continues at the call site.
  (func $type_mismatch (param $a i32) (param $b i32)
                        (param $span i32) (param $reason i32)
    (local $diag_h i32)
    (local $located i32)
    (local.set $located (call $reason_make_located
      (local.get $span) (local.get $reason)))
    (local.set $diag_h (call $graph_fresh_ty (local.get $located)))
    (call $infer_emit_type_mismatch
      (local.get $diag_h) (local.get $a) (local.get $b) (local.get $reason)))

  ;; ─── $arity_mismatch — function param-count diagnostic ───────────
  ;;
  ;; Per src/infer.mn:1527-1534. Constructs a stderr message; does NOT
  ;; bind to NErrorHole (canonical uses `perform report(...)` only —
  ;; control-level signal, not a handle being typed). $span dropped to
  ;; satisfy WAT.
  (func $arity_mismatch (param $la i32) (param $lb i32) (param $span i32)
    (local $msg i32)
    (local.set $msg (i32.const 3024))                       ;; "function arity mismatch: "
    (local.set $msg (call $str_concat
      (local.get $msg) (call $int_to_str (local.get $la))))
    (local.set $msg (call $str_concat
      (local.get $msg) (i32.const 3056)))                   ;; " param(s) vs "
    (local.set $msg (call $str_concat
      (local.get $msg) (call $int_to_str (local.get $lb))))
    (local.set $msg (call $str_concat
      (local.get $msg) (i32.const 3072)))                   ;; " param(s)"
    (call $eprint_string (local.get $msg))
    (drop (local.get $span)))

  ;; ─── $occurs_in — handle-in-Ty membership via $free_in_ty ────────
  ;;
  ;; Per src/infer.mn canonical occurs-check (and Hβ-infer-substrate.md
  ;; §3 cycle prevention). $free_in_ty walks the Ty's structure; we
  ;; linear-scan its handle-list for $h.
  (func $occurs_in (param $h i32) (param $ty i32) (result i32)
    (local $free i32) (local $n i32) (local $i i32)
    (local.set $free (call $free_in_ty (local.get $ty)))
    (local.set $n (call $len (local.get $free)))
    (local.set $i (i32.const 0))
    (block $done
      (loop $iter
        (br_if $done (i32.ge_u (local.get $i) (local.get $n)))
        (if (i32.eq (call $list_index (local.get $free) (local.get $i))
                     (local.get $h))
          (then (return (i32.const 1))))
        (local.set $i (i32.add (local.get $i) (i32.const 1)))
        (br $iter)))
    (i32.const 0))

  ;; ─── $unify_type_lists — pairwise list unification ───────────────
  ;;
  ;; Per src/infer.mn:1207-1221. Used by TTuple + TName arms. Both
  ;; empty → ok; arity mismatch → emit on stderr (control-level
  ;; signal, no NErrorHole); both non-empty → flat-index pairwise
  ;; recursion.
  (func $unify_type_lists (param $as_list i32) (param $bs_list i32)
                            (param $span i32) (param $reason i32)
    (local $na i32) (local $nb i32) (local $i i32)
    (local $msg i32)
    (local.set $na (call $len (local.get $as_list)))
    (local.set $nb (call $len (local.get $bs_list)))
    (if (i32.and (i32.eqz (local.get $na)) (i32.eqz (local.get $nb)))
      (then (return)))
    (if (i32.or (i32.eqz (local.get $na)) (i32.eqz (local.get $nb)))
      (then
        (local.set $msg (i32.const 3088))                   ;; "type list arity mismatch: "
        (local.set $msg (call $str_concat
          (local.get $msg) (call $int_to_str (local.get $na))))
        (local.set $msg (call $str_concat
          (local.get $msg) (i32.const 3120)))               ;; " vs "
        (local.set $msg (call $str_concat
          (local.get $msg) (call $int_to_str (local.get $nb))))
        (call $eprint_string (local.get $msg))
        (drop (local.get $span))
        (return)))
    ;; Both non-empty + same length (canonical uses recursive head/tail;
    ;; the seed flat-indexes both for O(N) without snoc-walk allocations).
    ;; Per CLAUDE.md hot-path discipline: flat-index loop on tag-0 lists.
    (local.set $i (i32.const 0))
    (block $done
      (loop $iter
        (br_if $done (i32.ge_u (local.get $i) (local.get $na)))
        (br_if $done (i32.ge_u (local.get $i) (local.get $nb)))
        (call $unify_types
          (call $list_index (local.get $as_list) (local.get $i))
          (call $list_index (local.get $bs_list) (local.get $i))
          (local.get $span) (local.get $reason))
        (local.set $i (i32.add (local.get $i) (i32.const 1)))
        (br $iter))))

  ;; ─── $unify_param_lists — pairwise TParam unification ────────────
  ;;
  ;; Per src/infer.mn:1452-1459. Same shape as $unify_type_lists but
  ;; reaches through $tparam_ty for each entry's type.
  (func $unify_param_lists (param $a i32) (param $b i32)
                             (param $span i32) (param $reason i32)
    (local $na i32) (local $nb i32) (local $i i32) (local $n i32)
    (local.set $na (call $len (local.get $a)))
    (local.set $nb (call $len (local.get $b)))
    ;; min(na, nb) iteration — canonical short-circuits on either empty
    (if (i32.or (i32.eqz (local.get $na)) (i32.eqz (local.get $nb)))
      (then (return)))
    (local.set $n (local.get $na))
    (if (i32.lt_u (local.get $nb) (local.get $n))
      (then (local.set $n (local.get $nb))))
    (local.set $i (i32.const 0))
    (block $done
      (loop $iter
        (br_if $done (i32.ge_u (local.get $i) (local.get $n)))
        (call $unify_types
          (call $tparam_ty (call $list_index (local.get $a) (local.get $i)))
          (call $tparam_ty (call $list_index (local.get $b) (local.get $i)))
          (local.get $span) (local.get $reason))
        (local.set $i (i32.add (local.get $i) (i32.const 1)))
        (br $iter))))

  ;; ─── $pair_fn_params — DESIGN Ch 2 Insight 7: Parameters ARE tuples
  ;;
  ;; Per src/infer.mn:1472-1478. Three structural cases:
  ;;   la == lb        — pair positionally
  ;;   la == 1         — single LEFT param decomposed against many RIGHT
  ;;   lb == 1         — single RIGHT param decomposed against many LEFT
  ;;   else            — arity mismatch (control-level)
  (func $pair_fn_params (param $pa i32) (param $pb i32)
                          (param $span i32) (param $reason i32)
    (local $la i32) (local $lb i32)
    (local.set $la (call $len (local.get $pa)))
    (local.set $lb (call $len (local.get $pb)))
    (if (i32.eq (local.get $la) (local.get $lb))
      (then
        (call $unify_param_lists (local.get $pa) (local.get $pb)
                                  (local.get $span) (local.get $reason))
        (return)))
    (if (i32.eq (local.get $la) (i32.const 1))
      (then
        (call $try_tuple_decompose
          (call $list_index (local.get $pa) (i32.const 0))
          (local.get $pb)
          (local.get $span) (local.get $reason))
        (return)))
    (if (i32.eq (local.get $lb) (i32.const 1))
      (then
        (call $try_tuple_decompose
          (call $list_index (local.get $pb) (i32.const 0))
          (local.get $pa)
          (local.get $span) (local.get $reason))
        (return)))
    (call $arity_mismatch (local.get $la) (local.get $lb) (local.get $span)))

  ;; ─── $try_tuple_decompose — single-param × many-params reconciliation
  ;;
  ;; Per src/infer.mn:1485-1500. Three structural cases for the single
  ;; param's type:
  ;;   TTuple(elems) of matching arity — pairwise element/param unify
  ;;   TVar(_)                          — bind TVar → TTuple(many param types)
  ;;   else                             — arity mismatch (la=1, lm)
  (func $try_tuple_decompose (param $single_param i32) (param $many_params i32)
                                (param $span i32) (param $reason i32)
    (local $pty i32) (local $ptag i32) (local $lm i32) (local $le i32)
    (local $tup_ty i32)
    (local.set $pty (call $tparam_ty (local.get $single_param)))
    (local.set $ptag (call $ty_tag (local.get $pty)))
    (local.set $lm (call $len (local.get $many_params)))
    (if (i32.eq (local.get $ptag) (i32.const 106))           ;; TTuple
      (then
        (local.set $le (call $len (call $ty_ttuple_elems (local.get $pty))))
        (if (i32.eq (local.get $le) (local.get $lm))
          (then
            (call $unify_tuple_elems_with_params
              (call $ty_ttuple_elems (local.get $pty))
              (local.get $many_params)
              (local.get $span) (local.get $reason)
              (i32.const 0) (local.get $lm))
            (return))
          (else
            (call $arity_mismatch (local.get $le) (local.get $lm) (local.get $span))
            (return)))))
    (if (i32.eq (local.get $ptag) (i32.const 104))           ;; TVar
      (then
        (local.set $tup_ty (call $ty_make_ttuple
          (call $param_types_flat (local.get $many_params))))
        (call $unify_types (local.get $pty) (local.get $tup_ty)
                            (local.get $span) (local.get $reason))
        (return)))
    (call $arity_mismatch (i32.const 1) (local.get $lm) (local.get $span)))

  ;; ─── $unify_tuple_elems_with_params — pairwise tuple-elem × TParam-ty
  ;;
  ;; Per src/infer.mn:1504-1511. Flat-index loop avoids snoc-walk
  ;; allocation on either input.
  (func $unify_tuple_elems_with_params (param $elems i32) (param $params i32)
                                          (param $span i32) (param $reason i32)
                                          (param $i i32) (param $n i32)
    (block $done
      (loop $iter
        (br_if $done (i32.ge_u (local.get $i) (local.get $n)))
        (call $unify_types
          (call $list_index (local.get $elems) (local.get $i))
          (call $tparam_ty (call $list_index (local.get $params) (local.get $i)))
          (local.get $span) (local.get $reason))
        (local.set $i (i32.add (local.get $i) (i32.const 1)))
        (br $iter))))

  ;; ─── $param_types_flat — fresh tag-0 list of TParam types ────────
  ;;
  ;; Per src/infer.mn:1516-1525. O(N) flat-list construction via
  ;; pre-sized buffer + $list_set; result is tag-0 (flat); subsequent
  ;; $list_index is O(1).
  (func $param_types_flat (param $params i32) (result i32)
    (local $n i32) (local $i i32) (local $acc i32)
    (local.set $n (call $len (local.get $params)))
    (local.set $acc (call $make_list (local.get $n)))
    (local.set $i (i32.const 0))
    (block $done
      (loop $iter
        (br_if $done (i32.ge_u (local.get $i) (local.get $n)))
        (local.set $acc (call $list_set
          (local.get $acc) (local.get $i)
          (call $tparam_ty
            (call $list_index (local.get $params) (local.get $i)))))
        (local.set $i (i32.add (local.get $i) (i32.const 1)))
        (br $iter)))
    (local.get $acc))

  ;; ─── $unify_record_fields_closed — closed × closed entry ─────────
  ;;
  ;; Per src/infer.mn:1229-1234. Length equality precondition; on
  ;; mismatch wrap as TRecord and route through $type_mismatch (so the
  ;; emit_diag.wat helper sees a stable Ty pair — drift-7-clean).
  (func $unify_record_fields_closed (param $fa i32) (param $fb i32)
                                       (param $span i32) (param $reason i32)
    (if (i32.ne (call $len (local.get $fa)) (call $len (local.get $fb)))
      (then
        (call $type_mismatch
          (call $ty_make_trecord (local.get $fa))
          (call $ty_make_trecord (local.get $fb))
          (local.get $span) (local.get $reason))
        (return)))
    (call $unify_record_fields_loop
      (local.get $fa) (local.get $fb)
      (i32.const 0) (call $len (local.get $fa))
      (local.get $span) (local.get $reason)))

  ;; ─── $unify_record_fields_loop — pointwise field-pair unification
  ;;
  ;; Per src/infer.mn:1236-1247. Both lists arrive sorted (parser +
  ;; smart-constructor invariant). On name-mismatch route through
  ;; $type_mismatch on the whole TRecord pair.
  (func $unify_record_fields_loop (param $fa i32) (param $fb i32)
                                     (param $i i32) (param $n i32)
                                     (param $span i32) (param $reason i32)
    (local $ea i32) (local $eb i32)
    (block $done
      (loop $iter
        (br_if $done (i32.ge_u (local.get $i) (local.get $n)))
        (local.set $ea (call $list_index (local.get $fa) (local.get $i)))
        (local.set $eb (call $list_index (local.get $fb) (local.get $i)))
        (if (call $str_eq
              (call $field_pair_name (local.get $ea))
              (call $field_pair_name (local.get $eb)))
          (then
            (call $unify_types
              (call $field_pair_ty (local.get $ea))
              (call $field_pair_ty (local.get $eb))
              (local.get $span) (local.get $reason)))
          (else
            (call $type_mismatch
              (call $ty_make_trecord (local.get $fa))
              (call $ty_make_trecord (local.get $fb))
              (local.get $span) (local.get $reason))
            (return)))
        (local.set $i (i32.add (local.get $i) (i32.const 1)))
        (br $iter))))

  ;; ─── $unify_record_open_against_closed — open-side rowvar binding
  ;;
  ;; Per src/infer.mn:1249-1256. Open-side fields must subset closed-
  ;; side; rowvar binds to the residual (closed-only) fields wrapped as
  ;; a TRecord row.
  (func $unify_record_open_against_closed
        (param $closed_fields i32) (param $open_fields i32)
        (param $open_var i32) (param $span i32) (param $reason i32)
    (local $residual i32)
    (local $located i32)
    (call $unify_record_open_subset
      (local.get $open_fields) (local.get $closed_fields)
      (local.get $span) (local.get $reason))
    (local.set $residual (call $record_fields_diff
      (local.get $closed_fields) (local.get $open_fields)))
    (local.set $located (call $reason_make_located
      (local.get $span) (local.get $reason)))
    (call $graph_bind_row
      (local.get $open_var)
      (call $mk_record_row_residual (local.get $residual))
      (local.get $located)))

  ;; ─── $unify_record_open_subset — open ⊆ closed check + unify ─────
  ;;
  ;; Per src/infer.mn:1258-1270. Linear-scan each needed field's
  ;; presence in available; on miss → $type_mismatch (TRecord wrappers
  ;; preserve drift-7 record-shape discipline).
  (func $unify_record_open_subset (param $needed i32) (param $available i32)
                                     (param $span i32) (param $reason i32)
    (local $nn i32) (local $i i32) (local $entry i32)
    (local $name i32) (local $ty i32) (local $pos i32) (local $other i32)
    (local.set $nn (call $len (local.get $needed)))
    (local.set $i (i32.const 0))
    (block $done
      (loop $iter
        (br_if $done (i32.ge_u (local.get $i) (local.get $nn)))
        (local.set $entry (call $list_index (local.get $needed) (local.get $i)))
        (local.set $name (call $field_pair_name (local.get $entry)))
        (local.set $ty   (call $field_pair_ty   (local.get $entry)))
        (local.set $pos
          (call $find_record_field_pos (local.get $available) (local.get $name)))
        (if (i32.lt_s (local.get $pos) (i32.const 0))
          (then
            (call $type_mismatch
              (call $ty_make_trecord (local.get $needed))
              (call $ty_make_trecord (local.get $available))
              (local.get $span) (local.get $reason))
            (return))
          (else
            (local.set $other
              (call $list_index (local.get $available) (local.get $pos)))
            (call $unify_types
              (local.get $ty)
              (call $field_pair_ty (local.get $other))
              (local.get $span) (local.get $reason))))
        (local.set $i (i32.add (local.get $i) (i32.const 1)))
        (br $iter))))

  ;; ─── $unify_two_open_records — open × open intersection + dual bind
  ;;
  ;; Per src/infer.mn:1272-1290. Intersect known fields (unify shared
  ;; types) + bind each rowvar to the residual relative to the other.
  ;; If rowvars are already linked (==), only verify residuals are
  ;; empty; otherwise dual $graph_bind_row.
  (func $unify_two_open_records (param $fa i32) (param $va i32)
                                   (param $fb i32) (param $vb i32)
                                   (param $span i32) (param $reason i32)
    (local $shared i32) (local $extra_a i32) (local $extra_b i32)
    (local $i i32) (local $n i32)
    (local $name i32) (local $pa i32) (local $pb i32)
    (local $ea i32) (local $eb i32)
    (local $located i32)
    (local.set $shared (call $intersect_record_fields
      (local.get $fa) (local.get $fb)))
    ;; Iterate shared field-pairs (NAME-keyed lookup in both sides) +
    ;; unify the matched types. The shared list holds field-pairs from
    ;; fa (intersect_record_fields side-of-truth); we look the name up
    ;; in fb to fetch the paired ty.
    (local.set $n (call $len (local.get $shared)))
    (local.set $i (i32.const 0))
    (block $done
      (loop $iter
        (br_if $done (i32.ge_u (local.get $i) (local.get $n)))
        (local.set $name (call $field_pair_name
          (call $list_index (local.get $shared) (local.get $i))))
        (local.set $pa (call $find_record_field_pos
          (local.get $fa) (local.get $name)))
        (local.set $pb (call $find_record_field_pos
          (local.get $fb) (local.get $name)))
        (if (i32.and
              (i32.ge_s (local.get $pa) (i32.const 0))
              (i32.ge_s (local.get $pb) (i32.const 0)))
          (then
            (local.set $ea (call $list_index (local.get $fa) (local.get $pa)))
            (local.set $eb (call $list_index (local.get $fb) (local.get $pb)))
            (call $unify_types
              (call $field_pair_ty (local.get $ea))
              (call $field_pair_ty (local.get $eb))
              (local.get $span) (local.get $reason))))
        (local.set $i (i32.add (local.get $i) (i32.const 1)))
        (br $iter)))
    (local.set $extra_a (call $record_fields_diff (local.get $fa) (local.get $fb)))
    (local.set $extra_b (call $record_fields_diff (local.get $fb) (local.get $fa)))
    (if (i32.eq (local.get $va) (local.get $vb))
      (then
        (if (i32.and (i32.eqz (call $len (local.get $extra_a)))
                      (i32.eqz (call $len (local.get $extra_b))))
          (then (return)))
        (call $type_mismatch
          (local.get $fa) (local.get $fb)
          (local.get $span) (local.get $reason))
        (return)))
    (local.set $located (call $reason_make_located
      (local.get $span) (local.get $reason)))
    (call $graph_bind_row (local.get $va)
      (call $mk_record_row_residual (local.get $extra_b))
      (local.get $located))
    (call $graph_bind_row (local.get $vb)
      (call $mk_record_row_residual (local.get $extra_a))
      (local.get $located)))

  ;; ─── $find_record_field_pos — linear scan returning -1 on absent ─
  ;;
  ;; Per src/infer.mn:1347-1356.
  (func $find_record_field_pos (param $fields i32) (param $name i32) (result i32)
    (call $find_record_field_pos_loop
      (local.get $fields) (local.get $name)
      (i32.const 0) (call $len (local.get $fields))))

  (func $find_record_field_pos_loop (param $fields i32) (param $name i32)
                                       (param $i i32) (param $n i32) (result i32)
    (local $existing i32)
    (block $done
      (loop $iter
        (br_if $done (i32.ge_u (local.get $i) (local.get $n)))
        (local.set $existing (call $field_pair_name
          (call $list_index (local.get $fields) (local.get $i))))
        (if (call $str_eq (local.get $existing) (local.get $name))
          (then (return (local.get $i))))
        (local.set $i (i32.add (local.get $i) (i32.const 1)))
        (br $iter)))
    (i32.const -1))

  ;; ─── $intersect_record_fields — buffer-counter accumulation ──────
  ;;
  ;; Per src/infer.mn:1306-1324. NO `acc ++ [X]` — uses
  ;; $list_extend_to + $list_set + counter + $slice per CLAUDE.md
  ;; bug-class buffer-counter substrate.
  ;;
  ;; Returns flat list of field-pair entries from $fa whose names
  ;; appear in $fb. Field-pair from fa is the source-of-truth; the
  ;; caller (e.g. $unify_two_open_records) re-lookups in fb to fetch
  ;; the paired ty.
  (func $intersect_record_fields (param $fa i32) (param $fb i32) (result i32)
    (local $n i32) (local $buf i32) (local $count i32)
    (local.set $n (call $len (local.get $fa)))
    (local.set $buf (call $make_list (local.get $n)))
    (local.set $count (i32.const 0))
    (call $intersect_record_fields_loop
      (local.get $fa) (local.get $fb)
      (i32.const 0) (local.get $n)
      (local.get $buf) (local.get $count)))

  (func $intersect_record_fields_loop (param $fa i32) (param $fb i32)
                                         (param $i i32) (param $n i32)
                                         (param $buf i32) (param $count i32)
                                         (result i32)
    (local $entry i32) (local $name i32) (local $extended i32)
    (block $done
      (loop $iter
        (br_if $done (i32.ge_u (local.get $i) (local.get $n)))
        (local.set $entry (call $list_index (local.get $fa) (local.get $i)))
        (local.set $name (call $field_pair_name (local.get $entry)))
        (if (i32.ge_s (call $find_record_field_pos
                        (local.get $fb) (local.get $name))
                       (i32.const 0))
          (then
            (local.set $extended (call $list_extend_to
              (local.get $buf) (i32.add (local.get $count) (i32.const 1))))
            (local.set $buf (call $list_set
              (local.get $extended) (local.get $count) (local.get $entry)))
            (local.set $count (i32.add (local.get $count) (i32.const 1)))))
        (local.set $i (i32.add (local.get $i) (i32.const 1)))
        (br $iter)))
    (call $slice (local.get $buf) (i32.const 0) (local.get $count)))

  ;; ─── $record_fields_diff — buffer-counter accumulation ───────────
  ;;
  ;; Per src/infer.mn:1326-1345. Returns left-side field-pair entries
  ;; whose names are absent from right-side. Same buffer-counter
  ;; discipline as $intersect_record_fields.
  (func $record_fields_diff (param $left i32) (param $right i32) (result i32)
    (local $n i32) (local $buf i32) (local $count i32)
    (local.set $n (call $len (local.get $left)))
    (local.set $buf (call $make_list (local.get $n)))
    (local.set $count (i32.const 0))
    (call $record_fields_diff_loop
      (local.get $left) (local.get $right)
      (i32.const 0) (local.get $n)
      (local.get $buf) (local.get $count)))

  (func $record_fields_diff_loop (param $left i32) (param $right i32)
                                    (param $i i32) (param $n i32)
                                    (param $buf i32) (param $count i32)
                                    (result i32)
    (local $entry i32) (local $name i32) (local $extended i32)
    (block $done
      (loop $iter
        (br_if $done (i32.ge_u (local.get $i) (local.get $n)))
        (local.set $entry (call $list_index (local.get $left) (local.get $i)))
        (local.set $name (call $field_pair_name (local.get $entry)))
        (if (i32.lt_s (call $find_record_field_pos
                        (local.get $right) (local.get $name))
                       (i32.const 0))
          (then
            (local.set $extended (call $list_extend_to
              (local.get $buf) (i32.add (local.get $count) (i32.const 1))))
            (local.set $buf (call $list_set
              (local.get $extended) (local.get $count) (local.get $entry)))
            (local.set $count (i32.add (local.get $count) (i32.const 1)))))
        (local.set $i (i32.add (local.get $i) (i32.const 1)))
        (br $iter)))
    (call $slice (local.get $buf) (i32.const 0) (local.get $count)))

  ;; ─── $mk_record_row_residual — wrap residual fields as TRecord ────
  ;;
  ;; Per src/infer.mn:1358-1360. Empty residual yields TRecord([]); the
  ;; row.wat follow-up will canonicalize the empty-row form.
  (func $mk_record_row_residual (param $fields i32) (result i32)
    (if (i32.eqz (call $len (local.get $fields)))
      (then (return (call $ty_make_trecord (call $make_list (i32.const 0))))))
    (call $ty_make_trecord (local.get $fields)))
