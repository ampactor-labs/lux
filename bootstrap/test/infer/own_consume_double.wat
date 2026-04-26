  ;; ═══ own_consume_double.wat — trace-harness ═══════════════════════
  ;; Executes: Hβ-infer-substrate.md §5 + §11 acceptance — double-consume
  ;;           path per src/own.nx:88-103 consume arm + §11.2 Hazel
  ;;           productive-under-error pattern. Two $infer_consume_use
  ;;           calls with the same name on the SAME handle:
  ;;             - First call inserts silently.
  ;;             - Second call emits E_OwnershipViolation via
  ;;               $infer_emit_ownership_violation + binds handle to
  ;;               NErrorHole(Inferred("ownership double-consume")).
  ;; Exercises: own.wat — $infer_consume_use, $infer_emit_ownership_violation,
  ;;            $own_find_first_span (called inside the violation arm).
  ;; Per ROADMAP §5 + Hβ-infer-substrate.md §11.
  ;;
  ;; ─── Eight interrogations ─────────────────────────────────────────
  ;;   Graph?      Handle bound to NErrorHole(reason=Inferred(...))
  ;;               via $graph_bind_kind. We $graph_node_at the handle
  ;;               post-second-call and inspect NodeKind tag (64) +
  ;;               wrapped Reason tag (221 = Inferred).
  ;;   Handler?    Direct seed call; @resume=OneShot.
  ;;   Verb?       N/A.
  ;;   Row?        Diagnostic + GraphWrite at wheel; direct $eprint_string +
  ;;               $graph_bind_kind at seed.
  ;;   Ownership?  Handle takes ownership of NErrorHole(Reason) payload;
  ;;               caller passed `name` ref.
  ;;   Refinement? None.
  ;;   Gradient?   The diagnostic IS the gradient signal — Mentl's voice
  ;;               surfaces here (canonical fix proposal lands post-L1).
  ;;   Reason?     NErrorHole wraps Inferred("ownership double-consume")
  ;;               (Reason tag 221 per reason.wat ADT).

  ;; Verdict labels (offsets ≥ 4096 to sit ABOVE own.wat's production
  ;; data range 3136-3382; harness/production overlap on diagnostic
  ;; emit paths broke the first iteration of this harness).
  (data (i32.const 4096) "\05\00\00\00PASS:")
  (data (i32.const 4128) "\05\00\00\00FAIL:")
  (data (i32.const 4160) "\01\00\00\00 ")
  (data (i32.const 4192) "\01\00\00\00\0a")

  ;; Harness display name
  (data (i32.const 4224) "\14\00\00\00own_consume_double  ")

  ;; Per-assertion FAIL labels
  (data (i32.const 4256) "\14\00\00\00handle-not-errhole  ")
  (data (i32.const 4288) "\14\00\00\00reason-not-inferred ")

  ;; Static argument string
  (data (i32.const 4928) "\01\00\00\00x")

  (func $_start (export "_start")
    (local $failed i32)
    (local $h_a i32) (local $g i32) (local $nk i32) (local $reason i32)
    (local.set $failed (i32.const 0))
    (call $graph_init)
    (call $infer_used_clear)

    ;; ── Setup: mint h_a (NFree); first consume silently records ──
    (local.set $h_a (call $graph_fresh_ty (i32.const 0)))
    (call $infer_consume_use (local.get $h_a) (i32.const 4928)
                              (i32.const 10) (i32.const 0))

    ;; ── Exercise: second consume on SAME handle + same name ──
    ;;             (span2 = 20 distinct from span1 = 10)
    (call $infer_consume_use (local.get $h_a) (i32.const 4928)
                              (i32.const 20) (i32.const 0))

    ;; ── Assert h_a's NodeKind tag == 64 (NErrorHole) ──
    (local.set $g (call $graph_node_at (local.get $h_a)))
    (local.set $nk (call $gnode_kind (local.get $g)))
    (if (i32.ne (call $node_kind_tag (local.get $nk)) (i32.const 64))
      (then
        (call $eprint_string (i32.const 4256))
        (call $eprint_string (i32.const 4192))
        (local.set $failed (i32.const 1))))

    ;; ── Assert wrapped Reason tag == 221 (Inferred) ──
    (local.set $reason (call $node_kind_payload (local.get $nk)))
    (if (i32.ne (call $tag_of (local.get $reason)) (i32.const 221))
      (then
        (call $eprint_string (i32.const 4288))
        (call $eprint_string (i32.const 4192))
        (local.set $failed (i32.const 1))))

    ;; ── Verdict ──
    (if (local.get $failed)
      (then
        (call $eprint_string (i32.const 4128))
        (call $eprint_string (i32.const 4160))
        (call $eprint_string (i32.const 4224)))
      (else
        (call $eprint_string (i32.const 4096))
        (call $eprint_string (i32.const 4160))
        (call $eprint_string (i32.const 4224))))
    (call $eprint_string (i32.const 4192))
    (call $wasi_proc_exit (i32.const 0)))
