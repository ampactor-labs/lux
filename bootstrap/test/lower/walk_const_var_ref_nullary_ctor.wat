  ;; ═══ walk_const_var_ref_nullary_ctor.wat — Hβ.lower trace-harness ════
  ;; Executes: Hβ-first-light.nullary-ctor-call-context §F (Lock #2.0 proof).
  ;;           Nullary ConstructorScheme bindings flowing through
  ;;           $lower_var_ref short-circuit to LMakeVariant(h, tag_id, [])
  ;;           BEFORE the locals/captures/global triage. Wheel parity
  ;;           src/lower.nx:333-337.
  ;; Exercises: walk_const.wat — $lower_var_ref Lock #2.0 SchemeKind dispatch.
  ;;
  ;; Eight interrogations:
  ;;   Graph?      $env_extend writes a binding with ConstructorScheme(1, 2);
  ;;               $env_lookup reads it; $env_binding_kind/$env_binding_scheme
  ;;               project the SchemeKind + Forall body Ty. The graph already
  ;;               carries the discriminant; this harness just verifies the
  ;;               read.
  ;;   Handler?    Direct call to $lower_var_ref. Resume: OneShot.
  ;;   Verb?       N/A — VarRef leaf.
  ;;   Row?        N/A — nullary ctor scheme body is TName (no row).
  ;;   Ownership?  Env binding `ref`-shared; LMakeVariant record `own` of bump.
  ;;   Refinement? `0 <= tag_id < total` — discharged at typedef registration.
  ;;   Gradient?   THIS IS the gradient cash-out: env-binding SchemeKind
  ;;               → compile-time `(i32.const tag_id)` instead of a runtime
  ;;               closure-state load. Drift 6 refusal: Bool's True/False
  ;;               flow through the SAME arm.
  ;;   Reason?     Reason chain on the binding preserved through LMakeVariant.

  (data (i32.const 3072) "\05\00\00\00PASS:")
  (data (i32.const 3084) "\05\00\00\00FAIL:")
  (data (i32.const 3096) "\01\00\00\00 ")
  (data (i32.const 3104) "\01\00\00\00\0a")
  (data (i32.const 3120) "\26\00\00\00lower_walk_const_var_ref_nullary_ctor ")

  ;; "Nothing" length-prefixed flat string (len=7).
  (data (i32.const 3160) "\07\00\00\00Nothing")
  ;; "Maybe" length-prefixed flat string (len=5).
  (data (i32.const 3172) "\05\00\00\00Maybe")
  ;; "Just" length-prefixed flat string (len=4).
  (data (i32.const 3184) "\04\00\00\00Just")

  (data (i32.const 3200) "\23\00\00\00nullary-ctor-tag-not-319-LMakeVariant")
  (data (i32.const 3260) "\1d\00\00\00nullary-ctor-tag_id-not-1")
  (data (i32.const 3296) "\1f\00\00\00nullary-ctor-args-not-empty")
  (data (i32.const 3336) "\28\00\00\00nary-ctor-tag-still-LMakeVariant-not-319")

  (func $_start (export "_start")
    (local $failed i32)
    (local $maybe_ty i32)
    (local $reason_n i32)
    (local $scheme_n i32)
    (local $kind_n i32)
    (local $node_nothing i32)
    (local $r_nothing i32)
    (local $args_nothing i32)
    (local.set $failed (i32.const 0))
    (call $env_init)
    (call $graph_init)
    (call $lower_init)

    ;; ─── Phase 1: register Nothing as ConstructorScheme(1, 2) ─────────
    ;; Nothing's Forall body is TName("Maybe", []) — nullary ctor whose
    ;; result type IS the typedef (matches walk_stmt.wat:847-860 nullary
    ;; arm).
    (local.set $maybe_ty
      (call $ty_make_tname (i32.const 3172) (call $make_list (i32.const 0))))
    (local.set $reason_n (call $reason_make_declared (i32.const 3160)))
    (local.set $scheme_n
      (call $scheme_make_forall (call $make_list (i32.const 0)) (local.get $maybe_ty)))
    (local.set $kind_n
      (call $schemekind_make_ctor (i32.const 1) (i32.const 2)))
    (call $env_extend
      (i32.const 3160)
      (local.get $scheme_n)
      (local.get $reason_n)
      (local.get $kind_n))

    ;; ─── Phase 2: build VarRef("Nothing") AST node ───────────────────
    (local.set $node_nothing
      (call $nexpr (call $mk_VarRef (i32.const 3160)) (i32.const 0)))

    ;; ─── Phase 3: lower the VarRef — must short-circuit to LMakeVariant.
    (local.set $r_nothing (call $lower_var_ref (local.get $node_nothing)))

    ;; Verify tag == 319 (LMAKEVARIANT_TAG).
    (if (i32.ne (call $tag_of (local.get $r_nothing)) (i32.const 319))
      (then
        (call $eprint_string (i32.const 3200))
        (call $eprint_string (i32.const 3104))
        (local.set $failed (i32.const 1))))

    ;; Verify tag_id field == 1 (Nothing's tag_id from the
    ;; ConstructorScheme(1, 2) registration).
    (if (i32.ne
          (call $lexpr_lmakevariant_tag_id (local.get $r_nothing))
          (i32.const 1))
      (then
        (call $eprint_string (i32.const 3260))
        (call $eprint_string (i32.const 3104))
        (local.set $failed (i32.const 1))))

    ;; Verify args list is empty (nullary ctor → zero args).
    (local.set $args_nothing
      (call $lexpr_lmakevariant_args (local.get $r_nothing)))
    (if (i32.ne (call $len (local.get $args_nothing)) (i32.const 0))
      (then
        (call $eprint_string (i32.const 3296))
        (call $eprint_string (i32.const 3104))
        (local.set $failed (i32.const 1))))

    ;; Verdict.
    (if (local.get $failed)
      (then
        (call $eprint_string (i32.const 3084))
        (call $eprint_string (i32.const 3096))
        (call $eprint_string (i32.const 3120))
        (call $eprint_string (i32.const 3104))
        (call $wasi_proc_exit (i32.const 1)))
      (else
        (call $eprint_string (i32.const 3072))
        (call $eprint_string (i32.const 3096))
        (call $eprint_string (i32.const 3120))
        (call $eprint_string (i32.const 3104))
        (call $wasi_proc_exit (i32.const 0)))))
