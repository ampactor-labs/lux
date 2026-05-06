  ;; ═══ unify_var_bind_no_occurs.wat — trace-harness ═════════════════
  ;; Executes: Hβ-infer-substrate.md §3 + §11 acceptance — TVar(h_a) ×
  ;;           NBound(TInt) at h_b. h_a is NFree at $unify entry. Per
  ;;           src/infer.mn:1046-1047: NFree-on-left arm binds h_a →
  ;;           TVar(h_b) via $graph_bind. The graph state after:
  ;;             chase(h_a) → NBound(TVar(h_b)),
  ;;             ty_tvar_handle(payload) == h_b,
  ;;             chase(h_b) → NBound(TInt) [unchanged].
  ;; Exercises: unify.wat — $unify (NFree-on-left arm) + $graph_bind
  ;; Per ROADMAP §5 + Hβ-infer-substrate.md §11 acceptance.
  ;;
  ;; ─── Eight interrogations ─────────────────────────────────────────
  ;;   Graph?      One NFree handle (h_a) + one NBound(TInt) handle (h_b).
  ;;               $unify mutates h_a → NBound(TVar(h_b)) via $graph_bind.
  ;;   Handler?    Direct seed call.
  ;;   Verb?       N/A.
  ;;   Row?        Pure.
  ;;   Ownership?  TVar(h_b) record owned by h_a's new GNode.
  ;;   Refinement? None.
  ;;   Gradient?   ONE gradient step — NFree narrows to NBound(TVar).
  ;;   Reason?     Located(span=0, reason=0) per the harness's no-Reason
  ;;               input — reason ptr 0 is "no reason recorded" per
  ;;               graph.wat:247.

  (data (i32.const 3500) "\05\00\00\00PASS:")
  (data (i32.const 3512) "\05\00\00\00FAIL:")
  (data (i32.const 3524) "\01\00\00\00 ")
  (data (i32.const 3532) "\01\00\00\00\0a")

  (data (i32.const 3552) "\18\00\00\00unify_var_bind_no_occurs")
  (data (i32.const 3584) "\14\00\00\00h_a-not-nbound      ")
  (data (i32.const 3616) "\14\00\00\00h_a-payload-not-tvar")
  (data (i32.const 3648) "\14\00\00\00tvar-handle-not-h_b ")
  (data (i32.const 3680) "\14\00\00\00h_b-not-nbound      ")
  (data (i32.const 3712) "\14\00\00\00h_b-payload-not-tint")

  (func $_start (export "_start")
    (local $failed i32)
    (local $h_a i32) (local $h_b i32)
    (local $g i32) (local $nk i32) (local $payload i32)
    (local.set $failed (i32.const 0))
    (call $graph_init)

    ;; ── Setup: h_a NFree (no $graph_bind), h_b NBound(TInt) ──
    (local.set $h_a (call $graph_fresh_ty (i32.const 0)))
    (local.set $h_b (call $graph_fresh_ty (i32.const 0)))
    (call $graph_bind (local.get $h_b) (call $ty_make_tint) (i32.const 0))

    ;; ── Exercise: $unify(h_a, h_b) — NFree-on-left arm fires ──
    (call $unify (local.get $h_a) (local.get $h_b) (i32.const 0) (i32.const 0))

    ;; ── Assert chase(h_a) → NBound(TVar(h_b)) ──
    (local.set $g (call $graph_node_at (local.get $h_a)))
    (local.set $nk (call $gnode_kind (local.get $g)))
    (if (i32.ne (call $node_kind_tag (local.get $nk)) (i32.const 60))
      (then
        (call $eprint_string (i32.const 3584))
        (call $eprint_string (i32.const 3532))
        (local.set $failed (i32.const 1))))
    (local.set $payload (call $node_kind_payload (local.get $nk)))
    (if (i32.ne (call $ty_tag (local.get $payload)) (i32.const 104))
      (then
        (call $eprint_string (i32.const 3616))
        (call $eprint_string (i32.const 3532))
        (local.set $failed (i32.const 1))))

    ;; ── Assert ty_tvar_handle(payload) == h_b ──
    (if (i32.ne (call $ty_tvar_handle (local.get $payload)) (local.get $h_b))
      (then
        (call $eprint_string (i32.const 3648))
        (call $eprint_string (i32.const 3532))
        (local.set $failed (i32.const 1))))

    ;; ── Assert h_b unchanged: NBound(TInt) ──
    (local.set $g (call $graph_node_at (local.get $h_b)))
    (local.set $nk (call $gnode_kind (local.get $g)))
    (if (i32.ne (call $node_kind_tag (local.get $nk)) (i32.const 60))
      (then
        (call $eprint_string (i32.const 3680))
        (call $eprint_string (i32.const 3532))
        (local.set $failed (i32.const 1))))
    (local.set $payload (call $node_kind_payload (local.get $nk)))
    (if (i32.ne (call $ty_tag (local.get $payload)) (i32.const 100))
      (then
        (call $eprint_string (i32.const 3712))
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
