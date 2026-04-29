  ;; ═══ lookup_dispatch.wat — Hβ.emit trace-harness ══════════════════
  ;; Executes: Hβ-emit-substrate.md §2.1 (LConst Ty-tag dispatch shape) +
  ;;           §2.4 (LCall arity reads via $emit_arity_of_tfun) + §3
  ;;           (H1.4 single-handler-per-op naming via $emit_op_symbol) +
  ;;           §5.1 (eight interrogations at dispatcher) + §8 acceptance.
  ;; Exercises: bootstrap/src/emit/lookup.wat — $emit_wat_type_for
  ;;            $emit_arity_of_tfun $emit_is_terror_hole $emit_op_symbol.
  ;; Per ROADMAP §5 + Hβ-emit-substrate.md §8.1 + §11.4 acceptance.
  ;;
  ;; ─── Eight interrogations (per Hβ-emit §5.1 second pass) ──────────
  ;;   Graph?      Constructs Ty values via $ty_make_tint (sentinel 100),
  ;;               $ty_make_tfun (record tag 107 with 2 params + ret +
  ;;               row), $ty_make_terror_hole (sentinel 114). $ty_tag
  ;;               reads through $tag_of which handles both sentinels
  ;;               and records uniformly per ty.wat:248-249. The harness
  ;;               does NOT chase via $graph_chase (no NBound/NFree
  ;;               nodes — the Tys are constructed locally; no
  ;;               $graph_init/$env_init needed).
  ;;   Handler?    Direct calls to $emit_* (seed Tier-5 base; @resume=
  ;;               OneShot at the wheel per render_ty-like dispatch
  ;;               shape).
  ;;   Verb?       N/A — sequential helper invocations.
  ;;   Row?        EfPure for the harness; the TFun's row field is
  ;;               $row_make_pure (sentinel 150) but lookup.wat does
  ;;               not read it (chunk #6 emit_call.wat does).
  ;;   Ownership?  TFun record + params list OWN by harness; $str_concat
  ;;               result OWNed (bump heap). No transfer; harness verifies
  ;;               value round-trips via $str_eq.
  ;;   Refinement? None.
  ;;   Gradient?   This harness IS one pixel of §8.1 acceptance — proves
  ;;               type-driven dispatch lands so chunks #3-#7 + #9 can
  ;;               compose on it. $emit_arity_of_tfun's TFun→arity vs
  ;;               non-TFun→-1 dispatch IS the gradient cash-out site.
  ;;   Reason?     N/A — Tys constructed locally, no Reason chain
  ;;               attached. Mentl-Why walks happen on real-graph Tys
  ;;               that downstream chunks see; this harness verifies
  ;;               the value-level round-trip.

  ;; ─── Harness-private data segment (offsets ≥ 3072, < HEAP_BASE) ──

  (data (i32.const 3072) "\05\00\00\00PASS:")
  (data (i32.const 3084) "\05\00\00\00FAIL:")
  (data (i32.const 3096) "\01\00\00\00 ")
  (data (i32.const 3104) "\01\00\00\00\0a")

  ;; Harness display name — offset 3120 (20 chars, padded)
  (data (i32.const 3120) "\14\00\00\00emit_lookup_dispatch")

  ;; Per-assertion FAIL labels — offsets 3144+ (24-byte slots; 4 hdr + 20 body)
  (data (i32.const 3144) "\14\00\00\00wat-type-int-not-488")
  (data (i32.const 3168) "\14\00\00\00wat-type-fun-not-488")
  (data (i32.const 3192) "\14\00\00\00wat-type-hol-not-488")
  (data (i32.const 3216) "\14\00\00\00arity-tfun-not-two  ")
  (data (i32.const 3240) "\14\00\00\00arity-tint-not-neg1 ")
  (data (i32.const 3264) "\14\00\00\00is-hole-true-failed ")
  (data (i32.const 3288) "\14\00\00\00is-hole-false-failed")
  (data (i32.const 3312) "\14\00\00\00op-symbol-not-op-foo")

  ;; Test input strings — name + expected concat result for $str_eq
  (data (i32.const 3336) "\03\00\00\00foo")
  (data (i32.const 3344) "\06\00\00\00op_foo")

  ;; ─── _start ──────────────────────────────────────────────────────
  (func $_start (export "_start")
    (local $failed i32)
    (local $t_int i32) (local $t_fun i32) (local $t_hole i32)
    (local $params i32)
    (local $wat_int i32) (local $wat_fun i32) (local $wat_hole i32)
    (local $arity_fun i32) (local $arity_int i32)
    (local $is_hole_yes i32) (local $is_hole_no i32)
    (local $sym i32)
    (local.set $failed (i32.const 0))

    ;; Construct test Tys.
    (local.set $t_int (call $ty_make_tint))
    (local.set $params (call $make_list (i32.const 2)))   ;; len=2; arity 2
    (local.set $t_fun
      (call $ty_make_tfun (local.get $params)
                          (local.get $t_int)
                          (call $row_make_pure)))
    (local.set $t_hole (call $ty_make_terror_hole))

    ;; ── Phase 1: $emit_wat_type_for(TInt) returns "i32" str_ptr 488 ──
    (local.set $wat_int (call $emit_wat_type_for (local.get $t_int)))
    (if (i32.ne (local.get $wat_int) (i32.const 488))
      (then
        (call $eprint_string (i32.const 3144))
        (call $eprint_string (i32.const 3104))
        (local.set $failed (i32.const 1))))

    ;; ── Phase 2: $emit_wat_type_for(TFun) returns "i32" — UNIFORM ──
    (local.set $wat_fun (call $emit_wat_type_for (local.get $t_fun)))
    (if (i32.ne (local.get $wat_fun) (i32.const 488))
      (then
        (call $eprint_string (i32.const 3168))
        (call $eprint_string (i32.const 3104))
        (local.set $failed (i32.const 1))))

    ;; ── Phase 3: $emit_wat_type_for(TError-hole) returns "i32" ──
    (local.set $wat_hole (call $emit_wat_type_for (local.get $t_hole)))
    (if (i32.ne (local.get $wat_hole) (i32.const 488))
      (then
        (call $eprint_string (i32.const 3192))
        (call $eprint_string (i32.const 3104))
        (local.set $failed (i32.const 1))))

    ;; ── Phase 4: $emit_arity_of_tfun(TFun-with-2-params) returns 2 ──
    (local.set $arity_fun (call $emit_arity_of_tfun (local.get $t_fun)))
    (if (i32.ne (local.get $arity_fun) (i32.const 2))
      (then
        (call $eprint_string (i32.const 3216))
        (call $eprint_string (i32.const 3104))
        (local.set $failed (i32.const 1))))

    ;; ── Phase 5: $emit_arity_of_tfun(TInt) returns -1 (non-TFun) ──
    (local.set $arity_int (call $emit_arity_of_tfun (local.get $t_int)))
    (if (i32.ne (local.get $arity_int) (i32.const -1))
      (then
        (call $eprint_string (i32.const 3240))
        (call $eprint_string (i32.const 3104))
        (local.set $failed (i32.const 1))))

    ;; ── Phase 6: $emit_is_terror_hole(TError-hole) returns 1 ──
    (local.set $is_hole_yes (call $emit_is_terror_hole (local.get $t_hole)))
    (if (i32.eqz (local.get $is_hole_yes))
      (then
        (call $eprint_string (i32.const 3264))
        (call $eprint_string (i32.const 3104))
        (local.set $failed (i32.const 1))))

    ;; ── Phase 7: $emit_is_terror_hole(TInt) returns 0 ──
    (local.set $is_hole_no (call $emit_is_terror_hole (local.get $t_int)))
    (if (local.get $is_hole_no)
      (then
        (call $eprint_string (i32.const 3288))
        (call $eprint_string (i32.const 3104))
        (local.set $failed (i32.const 1))))

    ;; ── Phase 8: $emit_op_symbol("foo") returns "op_foo" ──
    (local.set $sym (call $emit_op_symbol (i32.const 3336)))
    (if (i32.eqz (call $str_eq (local.get $sym) (i32.const 3344)))
      (then
        (call $eprint_string (i32.const 3312))
        (call $eprint_string (i32.const 3104))
        (local.set $failed (i32.const 1))))

    ;; ── Verdict ──
    (if (local.get $failed)
      (then
        (call $eprint_string (i32.const 3084))   ;; "FAIL:"
        (call $eprint_string (i32.const 3096))   ;; " "
        (call $eprint_string (i32.const 3120))   ;; "emit_lookup_dispatch"
        (call $eprint_string (i32.const 3104))   ;; "\n"
        (call $wasi_proc_exit (i32.const 1)))
      (else
        (call $eprint_string (i32.const 3072))   ;; "PASS:"
        (call $eprint_string (i32.const 3096))   ;; " "
        (call $eprint_string (i32.const 3120))   ;; "emit_lookup_dispatch"
        (call $eprint_string (i32.const 3104))   ;; "\n"
        (call $wasi_proc_exit (i32.const 0)))))
