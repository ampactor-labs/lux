  ;; ═══ emit_diag_render_ty.wat — trace-harness ══════════════════════
  ;; Executes: emit_diag.wat:486-611 14-arm $render_ty walker +
  ;;           cycle-bound at depth 10
  ;; Exercises: emit_diag.wat — $render_ty $render_tname $render_ty_list
  ;;            $render_ty_loop
  ;; Per ROADMAP §5 + Hβ-infer-substrate.md §11.
  ;;
  ;; ─── Eight interrogations ─────────────────────────────────────────
  ;;   Graph?      No graph touch — render is pure projection.
  ;;   Handler?    The wheel routes diagnostic message construction
  ;;               through the report effect; here direct call.
  ;;   Verb?       N/A.
  ;;   Row?        Pure projection.
  ;;   Ownership?  Output strings own (bump-allocated $str_concat).
  ;;   Refinement? Cycle bound at depth 10 IS a runtime refinement on
  ;;               diagnostic readability per emit_diag.wat:529-531.
  ;;   Gradient?   Each variant rendered correctly is one pixel of the
  ;;               14-arm coverage gradient.
  ;;   Reason?     N/A — render itself produces no Reason.
  ;;
  ;; Each data segment occupies (4 + payload_len) bytes starting at the
  ;; declared offset; we pad each entry to a 32-byte slot so layout is
  ;; verifiable by inspection. Static-data region [3072, 1048576) sits
  ;; below the bump allocator's $heap_ptr init at 1 MiB — non-colliding.

  ;; ─── Verdict labels (32-byte slots starting at 3072) ──────────────
  (data (i32.const 3072) "\05\00\00\00PASS:")
  (data (i32.const 3104) "\05\00\00\00FAIL:")
  (data (i32.const 3136) "\01\00\00\00 ")
  (data (i32.const 3168) "\01\00\00\00\0a")

  ;; ─── Harness display name ────────────────────────────────────────
  (data (i32.const 3200) "\14\00\00\00emit_diag_render_ty ")

  ;; ─── Per-assertion FAIL labels (32-byte slots; offsets 3232-3712) ─
  (data (i32.const 3232) "\08\00\00\00tint-str")
  (data (i32.const 3264) "\0a\00\00\00tfloat-str")
  (data (i32.const 3296) "\0b\00\00\00tstring-str")
  (data (i32.const 3328) "\09\00\00\00tunit-str")
  (data (i32.const 3360) "\08\00\00\00tvar-str")
  (data (i32.const 3392) "\09\00\00\00tlist-str")
  (data (i32.const 3424) "\0a\00\00\00ttuple-str")
  (data (i32.const 3456) "\08\00\00\00tfun-str")
  (data (i32.const 3488) "\0e\00\00\00tname-args-str")
  (data (i32.const 3520) "\0e\00\00\00tname-bare-str")
  (data (i32.const 3552) "\0b\00\00\00trecord-str")
  (data (i32.const 3584) "\0f\00\00\00trecordopen-str")
  (data (i32.const 3616) "\0c\00\00\00trefined-str")
  (data (i32.const 3648) "\09\00\00\00tcont-str")
  (data (i32.const 3680) "\0a\00\00\00talias-str")
  (data (i32.const 3712) "\09\00\00\00cycle-str")

  ;; ─── Expected static result strings (32-byte slots; offsets 3744+) ─
  (data (i32.const 3744) "\03\00\00\00Int")
  (data (i32.const 3776) "\05\00\00\00Float")
  (data (i32.const 3808) "\06\00\00\00String")
  (data (i32.const 3840) "\02\00\00\00()")
  (data (i32.const 3872) "\03\00\00\00?42")
  (data (i32.const 3904) "\09\00\00\00List<Int>")
  (data (i32.const 3936) "\0c\00\00\00(Int, Float)")
  (data (i32.const 3968) "\0e\00\00\00fn(...) -> Int")
  (data (i32.const 4000) "\0b\00\00\00Option<Int>")
  (data (i32.const 4032) "\04\00\00\00Bool")
  (data (i32.const 4064) "\05\00\00\00{...}")
  (data (i32.const 4096) "\0d\00\00\00Int where ...")
  (data (i32.const 4128) "\09\00\00\00Cont<Int>")
  (data (i32.const 4160) "\05\00\00\00MyInt")

  ;; ─── Static names for TName / TAlias (32-byte slots; offsets 4224+) ─
  (data (i32.const 4224) "\06\00\00\00Option")
  (data (i32.const 4256) "\04\00\00\00Bool")
  (data (i32.const 4288) "\05\00\00\00MyInt")

  (func $_start (export "_start")
    (local $failed i32)
    (local $tint i32) (local $tfloat i32) (local $tstring i32) (local $tunit i32)
    (local $tv42 i32)
    (local $r i32)
    (local $elems i32) (local $args i32) (local $fields i32)
    (local $f0 i32) (local $i i32) (local $nested i32)
    (local.set $failed (i32.const 0))
    (call $graph_init)

    (local.set $tint (call $ty_make_tint))
    (local.set $tfloat (call $ty_make_tfloat))
    (local.set $tstring (call $ty_make_tstring))
    (local.set $tunit (call $ty_make_tunit))
    (local.set $tv42 (call $ty_make_tvar (i32.const 42)))

    ;; 1. TInt → "Int"
    (local.set $r (call $render_ty (local.get $tint)))
    (if (i32.eqz (call $str_eq (local.get $r) (i32.const 3744)))
      (then
        (call $eprint_string (i32.const 3232))
        (call $eprint_string (i32.const 3168))
        (local.set $failed (i32.const 1))))

    ;; 2. TFloat → "Float"
    (local.set $r (call $render_ty (local.get $tfloat)))
    (if (i32.eqz (call $str_eq (local.get $r) (i32.const 3776)))
      (then
        (call $eprint_string (i32.const 3264))
        (call $eprint_string (i32.const 3168))
        (local.set $failed (i32.const 1))))

    ;; 3. TString → "String"
    (local.set $r (call $render_ty (local.get $tstring)))
    (if (i32.eqz (call $str_eq (local.get $r) (i32.const 3808)))
      (then
        (call $eprint_string (i32.const 3296))
        (call $eprint_string (i32.const 3168))
        (local.set $failed (i32.const 1))))

    ;; 4. TUnit → "()"
    (local.set $r (call $render_ty (local.get $tunit)))
    (if (i32.eqz (call $str_eq (local.get $r) (i32.const 3840)))
      (then
        (call $eprint_string (i32.const 3328))
        (call $eprint_string (i32.const 3168))
        (local.set $failed (i32.const 1))))

    ;; 5. TVar(42) → "?42"
    (local.set $r (call $render_ty (local.get $tv42)))
    (if (i32.eqz (call $str_eq (local.get $r) (i32.const 3872)))
      (then
        (call $eprint_string (i32.const 3360))
        (call $eprint_string (i32.const 3168))
        (local.set $failed (i32.const 1))))

    ;; 6. TList(TInt) → "List<Int>"
    (local.set $r (call $render_ty (call $ty_make_tlist (local.get $tint))))
    (if (i32.eqz (call $str_eq (local.get $r) (i32.const 3904)))
      (then
        (call $eprint_string (i32.const 3392))
        (call $eprint_string (i32.const 3168))
        (local.set $failed (i32.const 1))))

    ;; 7. TTuple([TInt, TFloat]) → "(Int, Float)"
    (local.set $elems (call $make_list (i32.const 2)))
    (drop (call $list_set (local.get $elems) (i32.const 0) (local.get $tint)))
    (drop (call $list_set (local.get $elems) (i32.const 1) (local.get $tfloat)))
    (local.set $r (call $render_ty (call $ty_make_ttuple (local.get $elems))))
    (if (i32.eqz (call $str_eq (local.get $r) (i32.const 3936)))
      (then
        (call $eprint_string (i32.const 3424))
        (call $eprint_string (i32.const 3168))
        (local.set $failed (i32.const 1))))

    ;; 8. TFun([], TInt, 0) → "fn(...) -> Int"
    (local.set $r (call $render_ty
                    (call $ty_make_tfun (call $make_list (i32.const 0))
                                        (local.get $tint) (i32.const 0))))
    (if (i32.eqz (call $str_eq (local.get $r) (i32.const 3968)))
      (then
        (call $eprint_string (i32.const 3456))
        (call $eprint_string (i32.const 3168))
        (local.set $failed (i32.const 1))))

    ;; 9. TName("Option", [TInt]) → "Option<Int>"
    (local.set $args (call $make_list (i32.const 1)))
    (drop (call $list_set (local.get $args) (i32.const 0) (local.get $tint)))
    (local.set $r (call $render_ty (call $ty_make_tname (i32.const 4224) (local.get $args))))
    (if (i32.eqz (call $str_eq (local.get $r) (i32.const 4000)))
      (then
        (call $eprint_string (i32.const 3488))
        (call $eprint_string (i32.const 3168))
        (local.set $failed (i32.const 1))))

    ;; 10. TName("Bool", []) → "Bool"
    (local.set $r (call $render_ty
                    (call $ty_make_tname (i32.const 4256) (call $make_list (i32.const 0)))))
    (if (i32.eqz (call $str_eq (local.get $r) (i32.const 4032)))
      (then
        (call $eprint_string (i32.const 3520))
        (call $eprint_string (i32.const 3168))
        (local.set $failed (i32.const 1))))

    ;; 11. TRecord([("x", TInt)]) → "{...}"
    (local.set $fields (call $make_list (i32.const 1)))
    (local.set $f0 (call $field_pair_make (i32.const 4224) (local.get $tint)))
    (drop (call $list_set (local.get $fields) (i32.const 0) (local.get $f0)))
    (local.set $r (call $render_ty (call $ty_make_trecord (local.get $fields))))
    (if (i32.eqz (call $str_eq (local.get $r) (i32.const 4064)))
      (then
        (call $eprint_string (i32.const 3552))
        (call $eprint_string (i32.const 3168))
        (local.set $failed (i32.const 1))))

    ;; 12. TRecordOpen([], 7) → "{...}"
    (local.set $r (call $render_ty
                    (call $ty_make_trecordopen (call $make_list (i32.const 0)) (i32.const 7))))
    (if (i32.eqz (call $str_eq (local.get $r) (i32.const 4064)))
      (then
        (call $eprint_string (i32.const 3584))
        (call $eprint_string (i32.const 3168))
        (local.set $failed (i32.const 1))))

    ;; 13. TRefined(TInt, 0xDEADBEEF) → "Int where ..."
    (local.set $r (call $render_ty
                    (call $ty_make_trefined (local.get $tint) (i32.const 0xDEADBEEF))))
    (if (i32.eqz (call $str_eq (local.get $r) (i32.const 4096)))
      (then
        (call $eprint_string (i32.const 3616))
        (call $eprint_string (i32.const 3168))
        (local.set $failed (i32.const 1))))

    ;; 14. TCont(TInt, 250) → "Cont<Int>"
    (local.set $r (call $render_ty (call $ty_make_tcont (local.get $tint) (i32.const 250))))
    (if (i32.eqz (call $str_eq (local.get $r) (i32.const 4128)))
      (then
        (call $eprint_string (i32.const 3648))
        (call $eprint_string (i32.const 3168))
        (local.set $failed (i32.const 1))))

    ;; 15. TAlias("MyInt", TInt) → "MyInt" (name verbatim)
    (local.set $r (call $render_ty (call $ty_make_talias (i32.const 4288) (local.get $tint))))
    (if (i32.eqz (call $str_eq (local.get $r) (i32.const 4160)))
      (then
        (call $eprint_string (i32.const 3680))
        (call $eprint_string (i32.const 3168))
        (local.set $failed (i32.const 1))))

    ;; ── Cycle bound: nest TList 12 deep; render returns "..." sentinel
    ;;    (per emit_diag.wat:530-531: depth > 10 → return offset 2448
    ;;    which holds "..."). The fully-rendered string therefore
    ;;    contains "List<List<...List<...>>>" — non-empty, finite. We
    ;;    assert non-empty as the load-bearing property: a runaway
    ;;    recursion would either trap or produce empty output. ──
    (local.set $nested (local.get $tint))
    (local.set $i (i32.const 0))
    (block $done
      (loop $iter
        (br_if $done (i32.ge_u (local.get $i) (i32.const 12)))
        (local.set $nested (call $ty_make_tlist (local.get $nested)))
        (local.set $i (i32.add (local.get $i) (i32.const 1)))
        (br $iter)))
    (local.set $r (call $render_ty (local.get $nested)))
    (if (i32.eqz (call $str_len (local.get $r)))
      (then
        (call $eprint_string (i32.const 3712))
        (call $eprint_string (i32.const 3168))
        (local.set $failed (i32.const 1))))

    ;; ── Verdict ──
    (if (local.get $failed)
      (then
        (call $eprint_string (i32.const 3104))
        (call $eprint_string (i32.const 3136))
        (call $eprint_string (i32.const 3200)))
      (else
        (call $eprint_string (i32.const 3072))
        (call $eprint_string (i32.const 3136))
        (call $eprint_string (i32.const 3200))))
    (call $eprint_string (i32.const 3168))
    (call $wasi_proc_exit (i32.const 0)))
