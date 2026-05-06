  ;; ═══ unify_var_bind_occurs_fail.wat — trace-harness ═══════════════
  ;; Executes: Hβ-infer-substrate.md §3 + §11 acceptance — TVar(h_a) ×
  ;;           TList(TVar(h_a)) refused-gradient path. Calling
  ;;           $unify_types(TVar(h_a), TList(TVar(h_a))) directly
  ;;           bypasses $unify's NFree short-circuit and goes through the
  ;;           104-arm. Per src/infer.mn:1067-1078: TVar arm runs
  ;;           $occurs_in(h_a, b); $free_in_ty(TList(TVar(h_a))) yields
  ;;           [h_a]; the linear-scan finds it; $occurs_in returns 1; the
  ;;           arm calls $infer_emit_occurs_check which (per
  ;;           emit_diag.wat:737-741) binds h_a to
  ;;           NErrorHole(Inferred("occurs check")) — Reason tag 221, but
  ;;           NodeKind tag 64 (NErrorHole) is the verifiable structural
  ;;           proof of the refused gradient.
  ;; Exercises: unify.wat — $unify_types (TVar arm) $occurs_in +
  ;;            scheme.wat $free_in_ty + emit_diag.wat
  ;;            $infer_emit_occurs_check
  ;; Per ROADMAP §5 + Hβ-infer-substrate.md §11 acceptance.
  ;;
  ;; ─── Eight interrogations ─────────────────────────────────────────
  ;;   Graph?      One NFree handle (h_a). After the call, h_a binds to
  ;;               NErrorHole — the gradient refused, the graph carries
  ;;               the refusal as a Reason.
  ;;   Handler?    Direct seed call.
  ;;   Verb?       N/A.
  ;;   Row?        Pure.
  ;;   Ownership?  NErrorHole record owned by h_a's new GNode.
  ;;   Refinement? None.
  ;;   Gradient?   Refused gradient step — the test is exactly the case
  ;;               where unification would close a TVar→Ty cycle.
  ;;   Reason?     Inferred("occurs check") attached to the NErrorHole.

  (data (i32.const 3500) "\05\00\00\00PASS:")
  (data (i32.const 3512) "\05\00\00\00FAIL:")
  (data (i32.const 3524) "\01\00\00\00 ")
  (data (i32.const 3532) "\01\00\00\00\0a")

  (data (i32.const 3552) "\1a\00\00\00unify_var_bind_occurs_fail")
  (data (i32.const 3584) "\14\00\00\00h_a-not-nerrorhole  ")

  (func $_start (export "_start")
    (local $failed i32)
    (local $h_a i32) (local $tvar_a i32) (local $tlist i32)
    (local $g i32) (local $nk i32)
    (local.set $failed (i32.const 0))
    (call $graph_init)

    ;; ── Setup: h_a NFree; build b = TList(TVar(h_a)) ──
    (local.set $h_a (call $graph_fresh_ty (i32.const 0)))
    (local.set $tvar_a (call $ty_make_tvar (local.get $h_a)))
    (local.set $tlist (call $ty_make_tlist (local.get $tvar_a)))

    ;; ── Exercise: $unify_types directly (bypassing $unify entry) so
    ;;    the TVar arm fires. $occurs_in(h_a, TList(TVar(h_a))) returns 1
    ;;    via $free_in_ty's TList → TVar arm. $infer_emit_occurs_check
    ;;    binds h_a → NErrorHole. ──
    (call $unify_types (local.get $tvar_a) (local.get $tlist)
                        (i32.const 0) (i32.const 0))

    ;; ── Assert chase(h_a) → NErrorHole (NodeKind tag 64) ──
    (local.set $g (call $graph_node_at (local.get $h_a)))
    (local.set $nk (call $gnode_kind (local.get $g)))
    (if (i32.ne (call $node_kind_tag (local.get $nk)) (i32.const 64))
      (then
        (call $eprint_string (i32.const 3584))
        (call $eprint_string (i32.const 3532))
        (local.set $failed (i32.const 1))))

    ;; ── Verdict ──
    (if (local.get $failed)
      (then
        (call $eprint_string (i32.const 3512))
        (call $eprint_string (i32.const 3524))
        (call $eprint_string (i32.const 3552)))
      (else
        (call $eprint_string (i32.const 3500))
        (call $eprint_string (i32.const 3524))
        (call $eprint_string (i32.const 3552))))
    (call $eprint_string (i32.const 3532))
    (call $wasi_proc_exit (i32.const 0)))
