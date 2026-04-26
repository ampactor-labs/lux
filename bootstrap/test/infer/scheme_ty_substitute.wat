  ;; ═══ scheme_ty_substitute.wat — trace-harness ═════════════════════
  ;; Executes: Hβ-infer-substrate.md §2.3 + scheme.wat:676-781
  ;;           14-arm walker (canonical parity src/infer.nx:1950-1990)
  ;; Exercises: scheme.wat — $ty_substitute $ty_substitute_list
  ;; Per ROADMAP §5 + Hβ-infer-substrate.md §11.
  ;;
  ;; ─── Eight interrogations ─────────────────────────────────────────
  ;;   Graph?      Substitution operates on Ty records; no graph touch.
  ;;   Handler?    Direct call to $ty_substitute over [(7→999)] map.
  ;;   Verb?       N/A.
  ;;   Row?        TFun's row preserved verbatim per scheme.wat:716-726.
  ;;   Ownership?  Result Ty records own; map ref.
  ;;   Refinement? Predicate ptr (TRefined) preserved verbatim.
  ;;               Discipline (TCont) preserved verbatim.
  ;;               Alias name (TAlias) preserved verbatim.
  ;;   Gradient?   The 14 explicit substitution arms ARE the parity
  ;;               with src/infer.nx:1950-1990.
  ;;   Reason?     N/A — pure substitution.

  (data (i32.const 3072) "\05\00\00\00PASS:")
  (data (i32.const 3084) "\05\00\00\00FAIL:")
  (data (i32.const 3096) "\01\00\00\00 ")
  (data (i32.const 3104) "\01\00\00\00\0a")

  (data (i32.const 3120) "\14\00\00\00scheme_ty_substitute")

  (data (i32.const 3144) "\09\00\00\00tint-id  ")
  (data (i32.const 3168) "\0b\00\00\00tfloat-id  ")
  (data (i32.const 3184) "\0c\00\00\00tstring-id  ")
  (data (i32.const 3200) "\0a\00\00\00tunit-id  ")
  (data (i32.const 3216) "\10\00\00\00tvar-handle-7   ")
  (data (i32.const 3240) "\18\00\00\00tvar-absent-not-identity")
  (data (i32.const 3272) "\0e\00\00\00tlist-handle  ")
  (data (i32.const 3288) "\0f\00\00\00ttuple-handle  ")
  (data (i32.const 3304) "\11\00\00\00tfun-ret-handle  ")
  (data (i32.const 3328) "\14\00\00\00tfun-row-preserved  ")
  (data (i32.const 3352) "\14\00\00\00tfun-param-handle   ")
  (data (i32.const 3376) "\0e\00\00\00tname-handle  ")
  (data (i32.const 3392) "\10\00\00\00trecord-handle  ")
  (data (i32.const 3416) "\14\00\00\00trecordopen-handle  ")
  (data (i32.const 3440) "\14\00\00\00trecordopen-rowvar  ")
  (data (i32.const 3464) "\11\00\00\00trefined-handle  ")
  (data (i32.const 3488) "\13\00\00\00trefined-pred-keep ")
  (data (i32.const 3512) "\0e\00\00\00tcont-handle  ")
  (data (i32.const 3528) "\11\00\00\00tcont-disc-keep  ")
  (data (i32.const 3552) "\0f\00\00\00talias-handle  ")
  (data (i32.const 3568) "\11\00\00\00talias-name-keep ")

  ;; Static name strings
  (data (i32.const 3600) "\06\00\00\00Option")

  (func $_start (export "_start")
    (local $failed i32)
    (local $tv7 i32) (local $tv9 i32)
    (local $map i32)
    (local $own_inf i32)
    (local $result i32) (local $inner i32)
    (local $elems i32) (local $params i32) (local $args i32) (local $fields i32)
    (local $p i32) (local $f0 i32)
    (local $tfun_in i32) (local $tfun_out i32) (local $params_out i32)
    (local.set $failed (i32.const 0))
    (call $graph_init)

    (local.set $tv7 (call $ty_make_tvar (i32.const 7)))
    (local.set $tv9 (call $ty_make_tvar (i32.const 9)))     ;; absent in map
    (local.set $own_inf (call $ownership_make_inferred))

    ;; Build map [(7 → 999)]
    (local.set $map (call $subst_map_make))
    (local.set $map (call $subst_map_extend (local.get $map) (i32.const 0)
                                            (i32.const 7) (i32.const 999)))

    ;; ── 1. TInt → identity ──
    (local.set $result (call $ty_substitute (call $ty_make_tint) (local.get $map) (i32.const 1)))
    (if (i32.ne (call $ty_tag (local.get $result)) (i32.const 100))
      (then
        (call $eprint_string (i32.const 3144))
        (call $eprint_string (i32.const 3104))
        (local.set $failed (i32.const 1))))

    ;; ── 2. TFloat → identity ──
    (local.set $result (call $ty_substitute (call $ty_make_tfloat) (local.get $map) (i32.const 1)))
    (if (i32.ne (call $ty_tag (local.get $result)) (i32.const 101))
      (then
        (call $eprint_string (i32.const 3168))
        (call $eprint_string (i32.const 3104))
        (local.set $failed (i32.const 1))))

    ;; ── 3. TString → identity ──
    (local.set $result (call $ty_substitute (call $ty_make_tstring) (local.get $map) (i32.const 1)))
    (if (i32.ne (call $ty_tag (local.get $result)) (i32.const 102))
      (then
        (call $eprint_string (i32.const 3184))
        (call $eprint_string (i32.const 3104))
        (local.set $failed (i32.const 1))))

    ;; ── 4. TUnit → identity ──
    (local.set $result (call $ty_substitute (call $ty_make_tunit) (local.get $map) (i32.const 1)))
    (if (i32.ne (call $ty_tag (local.get $result)) (i32.const 103))
      (then
        (call $eprint_string (i32.const 3200))
        (call $eprint_string (i32.const 3104))
        (local.set $failed (i32.const 1))))

    ;; ── 5. TVar(7) → TVar(999) ──
    (local.set $result (call $ty_substitute (local.get $tv7) (local.get $map) (i32.const 1)))
    (if (i32.ne (call $ty_tvar_handle (local.get $result)) (i32.const 999))
      (then
        (call $eprint_string (i32.const 3216))
        (call $eprint_string (i32.const 3104))
        (local.set $failed (i32.const 1))))

    ;; TVar(9) absent → identity (same pointer)
    (local.set $result (call $ty_substitute (local.get $tv9) (local.get $map) (i32.const 1)))
    (if (i32.ne (local.get $result) (local.get $tv9))
      (then
        (call $eprint_string (i32.const 3240))
        (call $eprint_string (i32.const 3104))
        (local.set $failed (i32.const 1))))

    ;; ── 6. TList(TVar(7)) → TList(TVar(999)) ──
    (local.set $result (call $ty_substitute
                         (call $ty_make_tlist (local.get $tv7)) (local.get $map) (i32.const 1)))
    (if (i32.ne (call $ty_tvar_handle (call $ty_tlist_elem (local.get $result))) (i32.const 999))
      (then
        (call $eprint_string (i32.const 3272))
        (call $eprint_string (i32.const 3104))
        (local.set $failed (i32.const 1))))

    ;; ── 7. TTuple([TVar(7)]) → TTuple([TVar(999)]) ──
    (local.set $elems (call $make_list (i32.const 1)))
    (drop (call $list_set (local.get $elems) (i32.const 0) (local.get $tv7)))
    (local.set $result (call $ty_substitute
                         (call $ty_make_ttuple (local.get $elems)) (local.get $map) (i32.const 1)))
    (local.set $inner (call $list_index (call $ty_ttuple_elems (local.get $result)) (i32.const 0)))
    (if (i32.ne (call $ty_tvar_handle (local.get $inner)) (i32.const 999))
      (then
        (call $eprint_string (i32.const 3288))
        (call $eprint_string (i32.const 3104))
        (local.set $failed (i32.const 1))))

    ;; ── 8. TFun([TParam("x", TVar(7), Inferred, Inferred)], TVar(7), 0xCAFE)
    ;;       → TFun([TParam("x", TVar(999), Inferred, Inferred)], TVar(999), 0xCAFE)
    ;;    Verifies ret-substituted, params-substituted, row preserved verbatim.
    (local.set $params (call $make_list (i32.const 1)))
    (local.set $p (call $tparam_make (i32.const 3600) (local.get $tv7)
                                      (local.get $own_inf) (local.get $own_inf)))
    (drop (call $list_set (local.get $params) (i32.const 0) (local.get $p)))
    (local.set $tfun_in (call $ty_make_tfun (local.get $params) (local.get $tv7) (i32.const 0xCAFE)))
    (local.set $tfun_out (call $ty_substitute (local.get $tfun_in) (local.get $map) (i32.const 1)))

    (if (i32.ne (call $ty_tvar_handle (call $ty_tfun_return (local.get $tfun_out))) (i32.const 999))
      (then
        (call $eprint_string (i32.const 3304))
        (call $eprint_string (i32.const 3104))
        (local.set $failed (i32.const 1))))

    (if (i32.ne (call $ty_tfun_row (local.get $tfun_out)) (i32.const 0xCAFE))
      (then
        (call $eprint_string (i32.const 3328))
        (call $eprint_string (i32.const 3104))
        (local.set $failed (i32.const 1))))

    (local.set $params_out (call $ty_tfun_params (local.get $tfun_out)))
    (if (i32.ne
          (call $ty_tvar_handle
            (call $tparam_ty (call $list_index (local.get $params_out) (i32.const 0))))
          (i32.const 999))
      (then
        (call $eprint_string (i32.const 3352))
        (call $eprint_string (i32.const 3104))
        (local.set $failed (i32.const 1))))

    ;; ── 9. TName("Option", [TVar(7)]) → TName("Option", [TVar(999)]) ──
    (local.set $args (call $make_list (i32.const 1)))
    (drop (call $list_set (local.get $args) (i32.const 0) (local.get $tv7)))
    (local.set $result (call $ty_substitute
                         (call $ty_make_tname (i32.const 3600) (local.get $args))
                         (local.get $map) (i32.const 1)))
    (local.set $inner (call $list_index (call $ty_tname_args (local.get $result)) (i32.const 0)))
    (if (i32.ne (call $ty_tvar_handle (local.get $inner)) (i32.const 999))
      (then
        (call $eprint_string (i32.const 3376))
        (call $eprint_string (i32.const 3104))
        (local.set $failed (i32.const 1))))

    ;; ── 10. TRecord([("x", TVar(7))]) → TRecord([("x", TVar(999))]) ──
    (local.set $fields (call $make_list (i32.const 1)))
    (local.set $f0 (call $field_pair_make (i32.const 3600) (local.get $tv7)))
    (drop (call $list_set (local.get $fields) (i32.const 0) (local.get $f0)))
    (local.set $result (call $ty_substitute
                         (call $ty_make_trecord (local.get $fields))
                         (local.get $map) (i32.const 1)))
    (local.set $inner (call $field_pair_ty
                        (call $list_index (call $ty_trecord_fields (local.get $result)) (i32.const 0))))
    (if (i32.ne (call $ty_tvar_handle (local.get $inner)) (i32.const 999))
      (then
        (call $eprint_string (i32.const 3392))
        (call $eprint_string (i32.const 3104))
        (local.set $failed (i32.const 1))))

    ;; ── 11. TRecordOpen([("x", TVar(7))], rowvar=11)
    ;;       → TRecordOpen([("x", TVar(999))], rowvar=11) (rowvar preserved) ──
    (local.set $fields (call $make_list (i32.const 1)))
    (local.set $f0 (call $field_pair_make (i32.const 3600) (local.get $tv7)))
    (drop (call $list_set (local.get $fields) (i32.const 0) (local.get $f0)))
    (local.set $result (call $ty_substitute
                         (call $ty_make_trecordopen (local.get $fields) (i32.const 11))
                         (local.get $map) (i32.const 1)))
    (local.set $inner (call $field_pair_ty
                        (call $list_index (call $ty_trecordopen_fields (local.get $result)) (i32.const 0))))
    (if (i32.ne (call $ty_tvar_handle (local.get $inner)) (i32.const 999))
      (then
        (call $eprint_string (i32.const 3416))
        (call $eprint_string (i32.const 3104))
        (local.set $failed (i32.const 1))))
    (if (i32.ne (call $ty_trecordopen_rowvar (local.get $result)) (i32.const 11))
      (then
        (call $eprint_string (i32.const 3440))
        (call $eprint_string (i32.const 3104))
        (local.set $failed (i32.const 1))))

    ;; ── 12. TRefined(TVar(7), 0xDEADBEEF)
    ;;       → TRefined(TVar(999), 0xDEADBEEF) (predicate preserved verbatim) ──
    (local.set $result (call $ty_substitute
                         (call $ty_make_trefined (local.get $tv7) (i32.const 0xDEADBEEF))
                         (local.get $map) (i32.const 1)))
    (if (i32.ne (call $ty_tvar_handle (call $ty_trefined_base (local.get $result))) (i32.const 999))
      (then
        (call $eprint_string (i32.const 3464))
        (call $eprint_string (i32.const 3104))
        (local.set $failed (i32.const 1))))
    (if (i32.ne (call $ty_trefined_pred (local.get $result)) (i32.const 0xDEADBEEF))
      (then
        (call $eprint_string (i32.const 3488))
        (call $eprint_string (i32.const 3104))
        (local.set $failed (i32.const 1))))

    ;; ── 13. TCont(TVar(7), 250)
    ;;       → TCont(TVar(999), 250) (discipline preserved verbatim) ──
    (local.set $result (call $ty_substitute
                         (call $ty_make_tcont (local.get $tv7) (i32.const 250))
                         (local.get $map) (i32.const 1)))
    (if (i32.ne (call $ty_tvar_handle (call $ty_tcont_return (local.get $result))) (i32.const 999))
      (then
        (call $eprint_string (i32.const 3512))
        (call $eprint_string (i32.const 3104))
        (local.set $failed (i32.const 1))))
    (if (i32.ne (call $ty_tcont_discipline (local.get $result)) (i32.const 250))
      (then
        (call $eprint_string (i32.const 3528))
        (call $eprint_string (i32.const 3104))
        (local.set $failed (i32.const 1))))

    ;; ── 14. TAlias("Option", TVar(7))
    ;;       → TAlias("Option", TVar(999)) (name preserved verbatim) ──
    (local.set $result (call $ty_substitute
                         (call $ty_make_talias (i32.const 3600) (local.get $tv7))
                         (local.get $map) (i32.const 1)))
    (if (i32.ne (call $ty_tvar_handle (call $ty_talias_resolved (local.get $result))) (i32.const 999))
      (then
        (call $eprint_string (i32.const 3552))
        (call $eprint_string (i32.const 3104))
        (local.set $failed (i32.const 1))))
    (if (i32.ne (call $ty_talias_name (local.get $result)) (i32.const 3600))
      (then
        (call $eprint_string (i32.const 3568))
        (call $eprint_string (i32.const 3104))
        (local.set $failed (i32.const 1))))

    ;; ── Verdict ──
    (if (local.get $failed)
      (then
        (call $eprint_string (i32.const 3084))
        (call $eprint_string (i32.const 3096))
        (call $eprint_string (i32.const 3120)))
      (else
        (call $eprint_string (i32.const 3072))
        (call $eprint_string (i32.const 3096))
        (call $eprint_string (i32.const 3120))))
    (call $eprint_string (i32.const 3104))
    (call $wasi_proc_exit (i32.const 0)))
