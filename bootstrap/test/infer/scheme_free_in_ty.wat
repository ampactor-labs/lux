  ;; ═══ scheme_free_in_ty.wat — trace-harness ════════════════════════
  ;; Executes: Hβ-infer-substrate.md §2.4 $free_handles + scheme.wat
  ;;           14-arm walker (lines 447-511) + ROADMAP §3 closure
  ;; Exercises: scheme.wat — $free_in_ty $free_in_list $singleton_handle
  ;;            $list_concat
  ;; Per ROADMAP §5 + Hβ-infer-substrate.md §11.
  ;;
  ;; ─── Eight interrogations ─────────────────────────────────────────
  ;;   Graph?      Free-handle collection IS reading Ty's TVar payloads;
  ;;               no graph mutation. We inspect the result list for
  ;;               each variant.
  ;;   Handler?    Direct call to $free_in_ty (recursive walker over 14 Ty tags).
  ;;   Verb?       N/A.
  ;;   Row?        TFun's row passed verbatim (i32.const 0); not walked
  ;;               at this layer per scheme.wat:217-221 row-side follow-up.
  ;;   Ownership?  Result is own (fresh list); inputs ref.
  ;;   Refinement? Verified per-variant: nullary→empty, TVar→[h], TList→
  ;;               recurse, etc. The 14 explicit arms ARE the refinement.
  ;;   Gradient?   Each variant's coverage is one pixel of the
  ;;               14-arm walker's correctness gradient.
  ;;   Reason?     N/A — $free_in_ty is pure (no graph write).

  ;; ─── Harness-private data segment ──
  (data (i32.const 3072) "\05\00\00\00PASS:")
  (data (i32.const 3084) "\05\00\00\00FAIL:")
  (data (i32.const 3096) "\01\00\00\00 ")
  (data (i32.const 3104) "\01\00\00\00\0a")

  (data (i32.const 3120) "\14\00\00\00scheme_free_in_ty   ")

  (data (i32.const 3144) "\08\00\00\00tint-len")
  (data (i32.const 3160) "\0a\00\00\00tfloat-len")
  (data (i32.const 3176) "\0b\00\00\00tstring-len")
  (data (i32.const 3192) "\09\00\00\00tunit-len")
  (data (i32.const 3208) "\08\00\00\00tvar-len")
  (data (i32.const 3224) "\0a\00\00\00tvar-value")
  (data (i32.const 3240) "\09\00\00\00tlist-len")
  (data (i32.const 3256) "\0b\00\00\00tlist-value")
  (data (i32.const 3272) "\0a\00\00\00ttuple-len")
  (data (i32.const 3288) "\0c\00\00\00ttuple-elem0")
  (data (i32.const 3304) "\0c\00\00\00ttuple-elem1")
  (data (i32.const 3320) "\08\00\00\00tfun-len")
  (data (i32.const 3336) "\0a\00\00\00tfun-elem0")
  (data (i32.const 3352) "\0a\00\00\00tfun-elem1")
  (data (i32.const 3368) "\09\00\00\00tname-len")
  (data (i32.const 3384) "\0b\00\00\00tname-value")
  (data (i32.const 3400) "\0b\00\00\00trecord-len")
  (data (i32.const 3416) "\0d\00\00\00trecord-value")
  (data (i32.const 3440) "\0f\00\00\00trecordopen-len")
  (data (i32.const 3464) "\11\00\00\00trecordopen-elem0")
  (data (i32.const 3488) "\11\00\00\00trecordopen-elem1")
  (data (i32.const 3512) "\0c\00\00\00trefined-len")
  (data (i32.const 3528) "\0e\00\00\00trefined-value")
  (data (i32.const 3544) "\09\00\00\00tcont-len")
  (data (i32.const 3560) "\0b\00\00\00tcont-value")
  (data (i32.const 3576) "\0a\00\00\00talias-len")
  (data (i32.const 3592) "\0c\00\00\00talias-value")

  ;; Harness-private name string for TName variant
  (data (i32.const 3616) "\06\00\00\00Option")

  ;; ─── _start ──
  (func $_start (export "_start")
    (local $failed i32)
    (local $tv7 i32) (local $tv11 i32)
    (local $ty i32) (local $free i32)
    (local $elems i32) (local $params i32) (local $args i32) (local $fields i32)
    (local $f0 i32) (local $f1 i32) (local $p i32)
    (local $own_inf i32)
    (local.set $failed (i32.const 0))
    (call $graph_init)

    (local.set $tv7 (call $ty_make_tvar (i32.const 7)))
    (local.set $tv11 (call $ty_make_tvar (i32.const 11)))
    (local.set $own_inf (call $ownership_make_inferred))

    ;; ── 1. TInt → empty ──
    (local.set $free (call $free_in_ty (call $ty_make_tint)))
    (if (i32.ne (call $len (local.get $free)) (i32.const 0))
      (then
        (call $eprint_string (i32.const 3144))
        (call $eprint_string (i32.const 3104))
        (local.set $failed (i32.const 1))))

    ;; ── 2. TFloat → empty ──
    (local.set $free (call $free_in_ty (call $ty_make_tfloat)))
    (if (i32.ne (call $len (local.get $free)) (i32.const 0))
      (then
        (call $eprint_string (i32.const 3160))
        (call $eprint_string (i32.const 3104))
        (local.set $failed (i32.const 1))))

    ;; ── 3. TString → empty ──
    (local.set $free (call $free_in_ty (call $ty_make_tstring)))
    (if (i32.ne (call $len (local.get $free)) (i32.const 0))
      (then
        (call $eprint_string (i32.const 3176))
        (call $eprint_string (i32.const 3104))
        (local.set $failed (i32.const 1))))

    ;; ── 4. TUnit → empty ──
    (local.set $free (call $free_in_ty (call $ty_make_tunit)))
    (if (i32.ne (call $len (local.get $free)) (i32.const 0))
      (then
        (call $eprint_string (i32.const 3192))
        (call $eprint_string (i32.const 3104))
        (local.set $failed (i32.const 1))))

    ;; ── 5. TVar(7) → [7] ──
    (local.set $free (call $free_in_ty (local.get $tv7)))
    (if (i32.ne (call $len (local.get $free)) (i32.const 1))
      (then
        (call $eprint_string (i32.const 3208))
        (call $eprint_string (i32.const 3104))
        (local.set $failed (i32.const 1))))
    (if (i32.ne (call $list_index (local.get $free) (i32.const 0)) (i32.const 7))
      (then
        (call $eprint_string (i32.const 3224))
        (call $eprint_string (i32.const 3104))
        (local.set $failed (i32.const 1))))

    ;; ── 6. TList(TVar(7)) → [7] ──
    (local.set $free (call $free_in_ty (call $ty_make_tlist (local.get $tv7))))
    (if (i32.ne (call $len (local.get $free)) (i32.const 1))
      (then
        (call $eprint_string (i32.const 3240))
        (call $eprint_string (i32.const 3104))
        (local.set $failed (i32.const 1))))
    (if (i32.ne (call $list_index (local.get $free) (i32.const 0)) (i32.const 7))
      (then
        (call $eprint_string (i32.const 3256))
        (call $eprint_string (i32.const 3104))
        (local.set $failed (i32.const 1))))

    ;; ── 7. TTuple([TVar(7), TVar(11)]) → [7, 11] ──
    (local.set $elems (call $make_list (i32.const 2)))
    (drop (call $list_set (local.get $elems) (i32.const 0) (local.get $tv7)))
    (drop (call $list_set (local.get $elems) (i32.const 1) (local.get $tv11)))
    (local.set $free (call $free_in_ty (call $ty_make_ttuple (local.get $elems))))
    (if (i32.ne (call $len (local.get $free)) (i32.const 2))
      (then
        (call $eprint_string (i32.const 3272))
        (call $eprint_string (i32.const 3104))
        (local.set $failed (i32.const 1))))
    (if (i32.ne (call $list_index (local.get $free) (i32.const 0)) (i32.const 7))
      (then
        (call $eprint_string (i32.const 3288))
        (call $eprint_string (i32.const 3104))
        (local.set $failed (i32.const 1))))
    (if (i32.ne (call $list_index (local.get $free) (i32.const 1)) (i32.const 11))
      (then
        (call $eprint_string (i32.const 3304))
        (call $eprint_string (i32.const 3104))
        (local.set $failed (i32.const 1))))

    ;; ── 8. TFun([TParam("x", TVar(7), Inferred, Inferred)], TVar(11), 0) → [7, 11] ──
    (local.set $params (call $make_list (i32.const 1)))
    (local.set $p (call $tparam_make
                    (i32.const 3616)         ;; reuse Option-name string ptr (name is opaque to free_in_ty)
                    (local.get $tv7)
                    (local.get $own_inf) (local.get $own_inf)))
    (drop (call $list_set (local.get $params) (i32.const 0) (local.get $p)))
    (local.set $free (call $free_in_ty
                       (call $ty_make_tfun (local.get $params) (local.get $tv11) (i32.const 0))))
    (if (i32.ne (call $len (local.get $free)) (i32.const 2))
      (then
        (call $eprint_string (i32.const 3320))
        (call $eprint_string (i32.const 3104))
        (local.set $failed (i32.const 1))))
    (if (i32.ne (call $list_index (local.get $free) (i32.const 0)) (i32.const 7))
      (then
        (call $eprint_string (i32.const 3336))
        (call $eprint_string (i32.const 3104))
        (local.set $failed (i32.const 1))))
    (if (i32.ne (call $list_index (local.get $free) (i32.const 1)) (i32.const 11))
      (then
        (call $eprint_string (i32.const 3352))
        (call $eprint_string (i32.const 3104))
        (local.set $failed (i32.const 1))))

    ;; ── 9. TName("Option", [TVar(7)]) → [7] ──
    (local.set $args (call $make_list (i32.const 1)))
    (drop (call $list_set (local.get $args) (i32.const 0) (local.get $tv7)))
    (local.set $free (call $free_in_ty
                       (call $ty_make_tname (i32.const 3616) (local.get $args))))
    (if (i32.ne (call $len (local.get $free)) (i32.const 1))
      (then
        (call $eprint_string (i32.const 3368))
        (call $eprint_string (i32.const 3104))
        (local.set $failed (i32.const 1))))
    (if (i32.ne (call $list_index (local.get $free) (i32.const 0)) (i32.const 7))
      (then
        (call $eprint_string (i32.const 3384))
        (call $eprint_string (i32.const 3104))
        (local.set $failed (i32.const 1))))

    ;; ── 10. TRecord([("x", TVar(7))]) → [7] ──
    (local.set $fields (call $make_list (i32.const 1)))
    (local.set $f0 (call $field_pair_make (i32.const 3616) (local.get $tv7)))
    (drop (call $list_set (local.get $fields) (i32.const 0) (local.get $f0)))
    (local.set $free (call $free_in_ty (call $ty_make_trecord (local.get $fields))))
    (if (i32.ne (call $len (local.get $free)) (i32.const 1))
      (then
        (call $eprint_string (i32.const 3400))
        (call $eprint_string (i32.const 3104))
        (local.set $failed (i32.const 1))))
    (if (i32.ne (call $list_index (local.get $free) (i32.const 0)) (i32.const 7))
      (then
        (call $eprint_string (i32.const 3416))
        (call $eprint_string (i32.const 3104))
        (local.set $failed (i32.const 1))))

    ;; ── 11. TRecordOpen([("x", TVar(7))], rowvar=11) → [11, 7] (rowvar first) ──
    (local.set $fields (call $make_list (i32.const 1)))
    (local.set $f1 (call $field_pair_make (i32.const 3616) (local.get $tv7)))
    (drop (call $list_set (local.get $fields) (i32.const 0) (local.get $f1)))
    (local.set $free (call $free_in_ty
                       (call $ty_make_trecordopen (local.get $fields) (i32.const 11))))
    (if (i32.ne (call $len (local.get $free)) (i32.const 2))
      (then
        (call $eprint_string (i32.const 3440))
        (call $eprint_string (i32.const 3104))
        (local.set $failed (i32.const 1))))
    (if (i32.ne (call $list_index (local.get $free) (i32.const 0)) (i32.const 11))
      (then
        (call $eprint_string (i32.const 3464))
        (call $eprint_string (i32.const 3104))
        (local.set $failed (i32.const 1))))
    (if (i32.ne (call $list_index (local.get $free) (i32.const 1)) (i32.const 7))
      (then
        (call $eprint_string (i32.const 3488))
        (call $eprint_string (i32.const 3104))
        (local.set $failed (i32.const 1))))

    ;; ── 12. TRefined(TVar(7), 0xDEADBEEF) → [7] (predicate opaque) ──
    (local.set $free (call $free_in_ty
                       (call $ty_make_trefined (local.get $tv7) (i32.const 0xDEADBEEF))))
    (if (i32.ne (call $len (local.get $free)) (i32.const 1))
      (then
        (call $eprint_string (i32.const 3512))
        (call $eprint_string (i32.const 3104))
        (local.set $failed (i32.const 1))))
    (if (i32.ne (call $list_index (local.get $free) (i32.const 0)) (i32.const 7))
      (then
        (call $eprint_string (i32.const 3528))
        (call $eprint_string (i32.const 3104))
        (local.set $failed (i32.const 1))))

    ;; ── 13. TCont(TVar(7), 250) → [7] (discipline opaque) ──
    (local.set $free (call $free_in_ty
                       (call $ty_make_tcont (local.get $tv7) (i32.const 250))))
    (if (i32.ne (call $len (local.get $free)) (i32.const 1))
      (then
        (call $eprint_string (i32.const 3544))
        (call $eprint_string (i32.const 3104))
        (local.set $failed (i32.const 1))))
    (if (i32.ne (call $list_index (local.get $free) (i32.const 0)) (i32.const 7))
      (then
        (call $eprint_string (i32.const 3560))
        (call $eprint_string (i32.const 3104))
        (local.set $failed (i32.const 1))))

    ;; ── 14. TAlias("Option", TVar(7)) → [7] (recurse on resolved) ──
    (local.set $free (call $free_in_ty
                       (call $ty_make_talias (i32.const 3616) (local.get $tv7))))
    (if (i32.ne (call $len (local.get $free)) (i32.const 1))
      (then
        (call $eprint_string (i32.const 3576))
        (call $eprint_string (i32.const 3104))
        (local.set $failed (i32.const 1))))
    (if (i32.ne (call $list_index (local.get $free) (i32.const 0)) (i32.const 7))
      (then
        (call $eprint_string (i32.const 3592))
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
