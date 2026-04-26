  ;; ═══ unify_ground_mismatch.wat — trace-harness ════════════════════
  ;; Executes: Hβ-infer-substrate.md §3 + §11 acceptance — TInt × TString
  ;;           Hazel productive-under-error path. Per src/infer.nx:1183 +
  ;;           1536-1541 + DESIGN paragraph in unify.wat: $type_mismatch
  ;;           mints a fresh diagnostic carrier handle, then routes
  ;;           through $infer_emit_type_mismatch which (a) prints
  ;;           E_TypeMismatch on stderr, (b) builds Reason
  ;;           UnifyFailed(ty_a, ty_b) (tag 233 per reason.wat:98), and
  ;;           (c) binds the carrier handle to NErrorHole carrying that
  ;;           Reason. Original h_a + h_b remain NBound — $type_mismatch
  ;;           does NOT mutate them. The walk continues at the call site.
  ;; Exercises: unify.wat — $unify $unify_types $expect_same $same_ground
  ;;            $type_mismatch + emit_diag.wat $infer_emit_type_mismatch
  ;; Per ROADMAP §5 + Hβ-infer-substrate.md §11 acceptance.
  ;;
  ;; ─── Eight interrogations ─────────────────────────────────────────
  ;;   Graph?      Two NBound input handles + ONE freshly-minted
  ;;               diagnostic handle. We capture $graph_next_handle
  ;;               BEFORE $unify and confirm it advanced by 1 after.
  ;;   Handler?    Direct seed call.
  ;;   Verb?       N/A.
  ;;   Row?        Pure (diagnostic emission is stderr — no row pollution).
  ;;   Ownership?  Diagnostic handle owns the new GNode + NErrorHole record.
  ;;   Refinement? None.
  ;;   Gradient?   Refused gradient step — error rather than narrow.
  ;;   Reason?     The diagnostic handle carries Reason UnifyFailed(TInt,
  ;;               TString) per emit_diag.wat:686-690.

  (data (i32.const 3500) "\05\00\00\00PASS:")
  (data (i32.const 3512) "\05\00\00\00FAIL:")
  (data (i32.const 3524) "\01\00\00\00 ")
  (data (i32.const 3532) "\01\00\00\00\0a")

  (data (i32.const 3552) "\15\00\00\00unify_ground_mismatch")
  (data (i32.const 3584) "\14\00\00\00next-handle-not-+1  ")
  (data (i32.const 3616) "\14\00\00\00diag-not-nerrorhole ")

  (func $_start (export "_start")
    (local $failed i32)
    (local $h_a i32) (local $h_b i32) (local $diag_h i32)
    (local $next_before i32) (local $next_after i32)
    (local $g i32) (local $nk i32)
    (local.set $failed (i32.const 0))
    (call $graph_init)

    ;; ── Setup: h_a → TInt, h_b → TString ──
    (local.set $h_a (call $graph_fresh_ty (i32.const 0)))
    (local.set $h_b (call $graph_fresh_ty (i32.const 0)))
    (call $graph_bind (local.get $h_a) (call $ty_make_tint)    (i32.const 0))
    (call $graph_bind (local.get $h_b) (call $ty_make_tstring) (i32.const 0))

    ;; ── Capture next-handle counter pre-$unify ──
    (local.set $next_before (call $graph_next_handle))

    ;; ── Exercise: $unify on (TInt, TString) — $type_mismatch fires ──
    (call $unify (local.get $h_a) (local.get $h_b) (i32.const 0) (i32.const 0))

    ;; ── Assert next-handle counter advanced by exactly 1 ──
    (local.set $next_after (call $graph_next_handle))
    (if (i32.ne
          (i32.sub (local.get $next_after) (local.get $next_before))
          (i32.const 1))
      (then
        (call $eprint_string (i32.const 3584))
        (call $eprint_string (i32.const 3532))
        (local.set $failed (i32.const 1))))

    ;; ── Assert that newly-minted handle has NodeKind tag 64 (NErrorHole) ──
    (local.set $diag_h (local.get $next_before))   ;; the just-allocated handle
    (local.set $g (call $graph_node_at (local.get $diag_h)))
    (local.set $nk (call $gnode_kind (local.get $g)))
    (if (i32.ne (call $node_kind_tag (local.get $nk)) (i32.const 64))
      (then
        (call $eprint_string (i32.const 3616))
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
