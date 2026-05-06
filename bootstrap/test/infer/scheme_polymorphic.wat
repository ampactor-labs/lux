  ;; ═══ scheme_polymorphic.wat — trace-harness ═══════════════════════
  ;; Executes: Hβ-infer-substrate.md §2.3 algorithm box + §11.2
  ;;           "Forall([qid], TList(TVar(qid)))" — fresh-handle
  ;;           minting per quantified slot
  ;; Exercises: scheme.wat — $generalize $instantiate $build_inst_mapping
  ;;            graph.wat — $graph_fresh_ty (per quantified slot),
  ;;                        $graph_chase (transitive TVar follow)
  ;; Per ROADMAP §5 + Hβ-infer-substrate.md §11.
  ;;
  ;; ─── Eight interrogations (per Hβ-infer §6.1 second pass) ─────────
  ;;   Graph?      Polymorphic body holds a free TVar handle h_q;
  ;;               $generalize chases h_fn (NBound(TList(TVar(h_q)))),
  ;;               collects h_q via $free_in_ty, wraps as
  ;;               Forall([h_q], TList(TVar(h_q))).
  ;;               $instantiate mints fresh handle per slot via
  ;;               $graph_fresh_ty.
  ;;   Handler?    Direct calls to scheme.wat helpers.
  ;;   Verb?       N/A.
  ;;   Row?        Pure.
  ;;   Ownership?  Refs only — fresh handles minted into the graph.
  ;;   Refinement? None.
  ;;   Gradient?   Forall([h], _) IS the open-gradient signal lower reads.
  ;;   Reason?     Each fresh handle's Reason is
  ;;               Instantiation("inst", Fresh(old)) — tag 232.
  ;;
  ;; Setup: h_q = fresh (NFree); h_fn = fresh, bound to TList(TVar(h_q)).
  ;; With transitive chase per src/graph.mn:269-272, chase(h_fn) returns
  ;; NBound(TList(TVar(h_q))) — stops at TList since TList ≠ TVar.
  ;; generalize extracts TList(TVar(h_q)), free_in_ty finds [h_q].
  ;; Result: Forall([h_q], TList(TVar(h_q))).

  ;; ─── Harness-private data segment ──
  (data (i32.const 3072) "\05\00\00\00PASS:")
  (data (i32.const 3084) "\05\00\00\00FAIL:")
  (data (i32.const 3096) "\01\00\00\00 ")
  (data (i32.const 3104) "\01\00\00\00\0a")

  (data (i32.const 3120) "\14\00\00\00scheme_polymorphic  ")

  (data (i32.const 3144) "\14\00\00\00quantified-not-one  ")
  (data (i32.const 3168) "\18\00\00\00quantified-wrong-handle ")
  (data (i32.const 3200) "\10\00\00\00body-not-tlist  ")
  (data (i32.const 3224) "\14\00\00\00elem-not-tvar       ")
  (data (i32.const 3248) "\18\00\00\00elem-wrong-handle       ")
  (data (i32.const 3280) "\18\00\00\00fresh-collides-with-old ")
  (data (i32.const 3312) "\10\00\00\00inst-not-tlist  ")
  (data (i32.const 3336) "\18\00\00\00fresh-reason-wrong-tag  ")

  ;; ─── _start ──
  (func $_start (export "_start")
    (local $failed i32)
    (local $h_q i32) (local $tv i32) (local $h_fn i32) (local $list_ty i32)
    (local $scheme i32) (local $qs i32) (local $body i32)
    (local $elem i32) (local $inst i32) (local $inst_elem i32)
    (local $h_fresh i32) (local $g_fresh i32)
    (local.set $failed (i32.const 0))
    (call $graph_init)

    ;; Allocate free quantified handle
    (local.set $h_q (call $graph_fresh_ty (i32.const 0)))
    ;; Build TList(TVar(h_q)) and bind h_fn to it
    (local.set $tv (call $ty_make_tvar (local.get $h_q)))
    (local.set $list_ty (call $ty_make_tlist (local.get $tv)))
    (local.set $h_fn (call $graph_fresh_ty (i32.const 0)))
    (call $graph_bind (local.get $h_fn) (local.get $list_ty) (i32.const 0))

    (local.set $scheme (call $generalize (local.get $h_fn)))
    (local.set $qs (call $scheme_quantified (local.get $scheme)))
    (local.set $body (call $scheme_body (local.get $scheme)))

    ;; Assert quantified length 1
    (if (i32.ne (call $len (local.get $qs)) (i32.const 1))
      (then
        (call $eprint_string (i32.const 3144))
        (call $eprint_string (i32.const 3104))
        (local.set $failed (i32.const 1))))

    ;; Assert quantified handle is h_q
    (if (i32.ne (call $list_index (local.get $qs) (i32.const 0)) (local.get $h_q))
      (then
        (call $eprint_string (i32.const 3168))
        (call $eprint_string (i32.const 3104))
        (local.set $failed (i32.const 1))))

    ;; Assert body is TList (tag 105)
    (if (i32.ne (call $ty_tag (local.get $body)) (i32.const 105))
      (then
        (call $eprint_string (i32.const 3200))
        (call $eprint_string (i32.const 3104))
        (local.set $failed (i32.const 1))))

    ;; Assert body's TList elem is TVar (tag 104)
    (local.set $elem (call $ty_tlist_elem (local.get $body)))
    (if (i32.ne (call $ty_tag (local.get $elem)) (i32.const 104))
      (then
        (call $eprint_string (i32.const 3224))
        (call $eprint_string (i32.const 3104))
        (local.set $failed (i32.const 1))))

    ;; Assert elem's TVar handle is h_q
    (if (i32.ne (call $ty_tvar_handle (local.get $elem)) (local.get $h_q))
      (then
        (call $eprint_string (i32.const 3248))
        (call $eprint_string (i32.const 3104))
        (local.set $failed (i32.const 1))))

    ;; Instantiate; observe fresh-handle minting
    (local.set $inst (call $instantiate (local.get $scheme)))

    ;; Assert inst is TList (tag 105)
    (if (i32.ne (call $ty_tag (local.get $inst)) (i32.const 105))
      (then
        (call $eprint_string (i32.const 3312))
        (call $eprint_string (i32.const 3104))
        (local.set $failed (i32.const 1))))

    ;; Assert inst's elem is TVar with a FRESH handle
    (local.set $inst_elem (call $ty_tlist_elem (local.get $inst)))
    (local.set $h_fresh (call $ty_tvar_handle (local.get $inst_elem)))

    ;; Assert fresh handle differs from quantified
    (if (i32.eq (local.get $h_fresh) (local.get $h_q))
      (then
        (call $eprint_string (i32.const 3280))
        (call $eprint_string (i32.const 3104))
        (local.set $failed (i32.const 1))))

    ;; Fresh handle's Reason is Instantiation(...) — tag 232
    (local.set $g_fresh (call $graph_node_at (local.get $h_fresh)))
    (if (i32.ne (call $tag_of (call $gnode_reason (local.get $g_fresh))) (i32.const 232))
      (then
        (call $eprint_string (i32.const 3336))
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
