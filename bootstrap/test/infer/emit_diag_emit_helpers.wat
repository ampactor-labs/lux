  ;; ═══ emit_diag_emit_helpers.wat — trace-harness ═══════════════════
  ;; Executes: emit_diag.wat:648-908 11 emit helpers + Hazel
  ;;           productive-under-error pattern (handle bound to NErrorHole;
  ;;           caller's walk continues — never halts)
  ;; Exercises: emit_diag.wat — $infer_emit_type_mismatch, _missing_var,
  ;;            _occurs_check, _feedback_no_context, _handler_uninstallable,
  ;;            _pattern_inexhaustive, _over_declared, _not_a_record_type,
  ;;            _record_field_extra, _record_field_missing,
  ;;            _cannot_negate_capability
  ;; Per ROADMAP §5 + Hβ-infer-substrate.md §11.
  ;;
  ;; ─── Eight interrogations ─────────────────────────────────────────
  ;;   Graph?      Each helper binds offending handle to NErrorHole(reason)
  ;;               via $graph_bind + $node_kind_make_nerrorhole. We
  ;;               $graph_node_at the handle post-call and inspect
  ;;               NodeKind tag (64=NErrorHole) + Reason payload tag.
  ;;               Exception: T_OverDeclared (Warning kind) does NOT
  ;;               bind — handle remains NFree (tag 61).
  ;;   Handler?    Direct functions; @resume=OneShot per the report
  ;;               effect's wheel form.
  ;;   Verb?       N/A.
  ;;   Row?        Diagnostic + GraphWrite at wheel; direct $eprint_string
  ;;               + $graph_bind at seed.
  ;;   Ownership?  Handle bound to NErrorHole takes ownership of the
  ;;               Reason payload; caller passed message ref.
  ;;   Refinement? Each NErrorHole carries a different Reason variant
  ;;               (UnifyFailed=233 / MissingVar=236 / Inferred=221).
  ;;   Gradient?   Each helper IS one gradient signal — Mentl's voice
  ;;               composes on this surface.
  ;;   Reason?     The whole purpose of each helper is to leave a
  ;;               Reason edge on the bound NErrorHole.

  ;; Each data segment occupies (4 + payload_len) bytes; 32-byte slots
  ;; throughout to keep layout verifiable by inspection. Static-data
  ;; region [3072, 1048576) sits below bump allocator's $heap_ptr init.

  ;; ─── Verdict labels (32-byte slots starting at 3072) ──────────────
  (data (i32.const 3072) "\05\00\00\00PASS:")
  (data (i32.const 3104) "\05\00\00\00FAIL:")
  (data (i32.const 3136) "\01\00\00\00 ")
  (data (i32.const 3168) "\01\00\00\00\0a")

  ;; ─── Harness display name ────────────────────────────────────────
  (data (i32.const 3200) "\14\00\00\00emit_diag_emit_helpr")

  ;; ─── Per-helper FAIL labels (32-byte slots; offsets 3232+) ────────
  (data (i32.const 3232) "\14\00\00\00type-mismatch-nk    ")
  (data (i32.const 3264) "\14\00\00\00type-mismatch-reason")
  (data (i32.const 3296) "\14\00\00\00missing-var-nk      ")
  (data (i32.const 3328) "\14\00\00\00missing-var-reason  ")
  (data (i32.const 3360) "\14\00\00\00occurs-check-nk     ")
  (data (i32.const 3392) "\14\00\00\00occurs-check-reason ")
  (data (i32.const 3424) "\14\00\00\00feedback-no-ctx-nk  ")
  (data (i32.const 3456) "\14\00\00\00feedback-no-ctx-rsn ")
  (data (i32.const 3488) "\14\00\00\00handler-uninst-nk   ")
  (data (i32.const 3520) "\14\00\00\00handler-uninst-rsn  ")
  (data (i32.const 3552) "\14\00\00\00pattern-inex-nk     ")
  (data (i32.const 3584) "\14\00\00\00pattern-inex-rsn    ")
  (data (i32.const 3616) "\14\00\00\00over-declared-nk    ")
  (data (i32.const 3648) "\14\00\00\00not-record-type-nk  ")
  (data (i32.const 3680) "\14\00\00\00not-record-type-rsn ")
  (data (i32.const 3712) "\14\00\00\00field-extra-nk      ")
  (data (i32.const 3744) "\14\00\00\00field-extra-rsn     ")
  (data (i32.const 3776) "\14\00\00\00field-missing-nk    ")
  (data (i32.const 3808) "\14\00\00\00field-missing-rsn   ")
  (data (i32.const 3840) "\14\00\00\00neg-capability-nk   ")
  (data (i32.const 3872) "\14\00\00\00neg-capability-rsn  ")

  ;; ─── Static argument strings (variable names, type names, etc.) ──
  (data (i32.const 3904) "\01\00\00\00x")
  (data (i32.const 3936) "\06\00\00\00MyType")
  (data (i32.const 3968) "\01\00\00\00f")
  (data (i32.const 4000) "\03\00\00\00Net")

  (func $_start (export "_start")
    (local $failed i32)
    (local $h i32) (local $g i32) (local $nk i32) (local $reason i32)
    (local $tint i32) (local $tfloat i32)
    (local.set $failed (i32.const 0))
    (call $graph_init)

    (local.set $tint (call $ty_make_tint))
    (local.set $tfloat (call $ty_make_tfloat))

    ;; ── 1. $infer_emit_type_mismatch — NErrorHole(UnifyFailed) ──
    (local.set $h (call $graph_fresh_ty (i32.const 0)))
    (call $infer_emit_type_mismatch (local.get $h)
                                     (local.get $tint) (local.get $tfloat)
                                     (i32.const 0))
    (local.set $g (call $graph_node_at (local.get $h)))
    (local.set $nk (call $gnode_kind (local.get $g)))
    (if (i32.ne (call $node_kind_tag (local.get $nk)) (i32.const 64))
      (then
        (call $eprint_string (i32.const 3232))
        (call $eprint_string (i32.const 3168))
        (local.set $failed (i32.const 1))))
    (local.set $reason (call $node_kind_payload (local.get $nk)))
    (if (i32.ne (call $tag_of (local.get $reason)) (i32.const 233))
      (then
        (call $eprint_string (i32.const 3264))
        (call $eprint_string (i32.const 3168))
        (local.set $failed (i32.const 1))))

    ;; ── 2. $infer_emit_missing_var — NErrorHole(MissingVar) ──
    (local.set $h (call $graph_fresh_ty (i32.const 0)))
    (call $infer_emit_missing_var (local.get $h) (i32.const 3904) (i32.const 0))
    (local.set $g (call $graph_node_at (local.get $h)))
    (local.set $nk (call $gnode_kind (local.get $g)))
    (if (i32.ne (call $node_kind_tag (local.get $nk)) (i32.const 64))
      (then
        (call $eprint_string (i32.const 3296))
        (call $eprint_string (i32.const 3168))
        (local.set $failed (i32.const 1))))
    (local.set $reason (call $node_kind_payload (local.get $nk)))
    (if (i32.ne (call $tag_of (local.get $reason)) (i32.const 236))
      (then
        (call $eprint_string (i32.const 3328))
        (call $eprint_string (i32.const 3168))
        (local.set $failed (i32.const 1))))

    ;; ── 3. $infer_emit_occurs_check — NErrorHole(Inferred) ──
    (local.set $h (call $graph_fresh_ty (i32.const 0)))
    (call $infer_emit_occurs_check (local.get $h) (local.get $tint) (i32.const 0))
    (local.set $g (call $graph_node_at (local.get $h)))
    (local.set $nk (call $gnode_kind (local.get $g)))
    (if (i32.ne (call $node_kind_tag (local.get $nk)) (i32.const 64))
      (then
        (call $eprint_string (i32.const 3360))
        (call $eprint_string (i32.const 3168))
        (local.set $failed (i32.const 1))))
    (local.set $reason (call $node_kind_payload (local.get $nk)))
    (if (i32.ne (call $tag_of (local.get $reason)) (i32.const 221))
      (then
        (call $eprint_string (i32.const 3392))
        (call $eprint_string (i32.const 3168))
        (local.set $failed (i32.const 1))))

    ;; ── 4. $infer_emit_feedback_no_context — NErrorHole(Inferred) ──
    (local.set $h (call $graph_fresh_ty (i32.const 0)))
    (call $infer_emit_feedback_no_context (local.get $h) (i32.const 0))
    (local.set $g (call $graph_node_at (local.get $h)))
    (local.set $nk (call $gnode_kind (local.get $g)))
    (if (i32.ne (call $node_kind_tag (local.get $nk)) (i32.const 64))
      (then
        (call $eprint_string (i32.const 3424))
        (call $eprint_string (i32.const 3168))
        (local.set $failed (i32.const 1))))
    (local.set $reason (call $node_kind_payload (local.get $nk)))
    (if (i32.ne (call $tag_of (local.get $reason)) (i32.const 221))
      (then
        (call $eprint_string (i32.const 3456))
        (call $eprint_string (i32.const 3168))
        (local.set $failed (i32.const 1))))

    ;; ── 5. $infer_emit_handler_uninstallable — NErrorHole(Inferred) ──
    (local.set $h (call $graph_fresh_ty (i32.const 0)))
    (call $infer_emit_handler_uninstallable (local.get $h) (i32.const 0))
    (local.set $g (call $graph_node_at (local.get $h)))
    (local.set $nk (call $gnode_kind (local.get $g)))
    (if (i32.ne (call $node_kind_tag (local.get $nk)) (i32.const 64))
      (then
        (call $eprint_string (i32.const 3488))
        (call $eprint_string (i32.const 3168))
        (local.set $failed (i32.const 1))))
    (local.set $reason (call $node_kind_payload (local.get $nk)))
    (if (i32.ne (call $tag_of (local.get $reason)) (i32.const 221))
      (then
        (call $eprint_string (i32.const 3520))
        (call $eprint_string (i32.const 3168))
        (local.set $failed (i32.const 1))))

    ;; ── 6. $infer_emit_pattern_inexhaustive — NErrorHole(Inferred) ──
    (local.set $h (call $graph_fresh_ty (i32.const 0)))
    (call $infer_emit_pattern_inexhaustive (local.get $h) (i32.const 0))
    (local.set $g (call $graph_node_at (local.get $h)))
    (local.set $nk (call $gnode_kind (local.get $g)))
    (if (i32.ne (call $node_kind_tag (local.get $nk)) (i32.const 64))
      (then
        (call $eprint_string (i32.const 3552))
        (call $eprint_string (i32.const 3168))
        (local.set $failed (i32.const 1))))
    (local.set $reason (call $node_kind_payload (local.get $nk)))
    (if (i32.ne (call $tag_of (local.get $reason)) (i32.const 221))
      (then
        (call $eprint_string (i32.const 3584))
        (call $eprint_string (i32.const 3168))
        (local.set $failed (i32.const 1))))

    ;; ── 7. $infer_emit_over_declared — Warning kind, does NOT bind ──
    ;;    Handle remains NFree (tag 61). Per emit_diag.wat:810-822.
    (local.set $h (call $graph_fresh_ty (i32.const 0)))
    (call $infer_emit_over_declared (local.get $h) (i32.const 0))
    (local.set $g (call $graph_node_at (local.get $h)))
    (local.set $nk (call $gnode_kind (local.get $g)))
    (if (i32.ne (call $node_kind_tag (local.get $nk)) (i32.const 61))
      (then
        (call $eprint_string (i32.const 3616))
        (call $eprint_string (i32.const 3168))
        (local.set $failed (i32.const 1))))

    ;; ── 8. $infer_emit_not_a_record_type — NErrorHole(Inferred) ──
    (local.set $h (call $graph_fresh_ty (i32.const 0)))
    (call $infer_emit_not_a_record_type (local.get $h) (i32.const 3936) (i32.const 0))
    (local.set $g (call $graph_node_at (local.get $h)))
    (local.set $nk (call $gnode_kind (local.get $g)))
    (if (i32.ne (call $node_kind_tag (local.get $nk)) (i32.const 64))
      (then
        (call $eprint_string (i32.const 3648))
        (call $eprint_string (i32.const 3168))
        (local.set $failed (i32.const 1))))
    (local.set $reason (call $node_kind_payload (local.get $nk)))
    (if (i32.ne (call $tag_of (local.get $reason)) (i32.const 221))
      (then
        (call $eprint_string (i32.const 3680))
        (call $eprint_string (i32.const 3168))
        (local.set $failed (i32.const 1))))

    ;; ── 9. $infer_emit_record_field_extra — NErrorHole(Inferred) ──
    (local.set $h (call $graph_fresh_ty (i32.const 0)))
    (call $infer_emit_record_field_extra (local.get $h) (i32.const 3968)
                                          (i32.const 3936) (i32.const 0))
    (local.set $g (call $graph_node_at (local.get $h)))
    (local.set $nk (call $gnode_kind (local.get $g)))
    (if (i32.ne (call $node_kind_tag (local.get $nk)) (i32.const 64))
      (then
        (call $eprint_string (i32.const 3712))
        (call $eprint_string (i32.const 3168))
        (local.set $failed (i32.const 1))))
    (local.set $reason (call $node_kind_payload (local.get $nk)))
    (if (i32.ne (call $tag_of (local.get $reason)) (i32.const 221))
      (then
        (call $eprint_string (i32.const 3744))
        (call $eprint_string (i32.const 3168))
        (local.set $failed (i32.const 1))))

    ;; ── 10. $infer_emit_record_field_missing — NErrorHole(Inferred) ──
    (local.set $h (call $graph_fresh_ty (i32.const 0)))
    (call $infer_emit_record_field_missing (local.get $h) (i32.const 3968)
                                            (i32.const 3936) (i32.const 0))
    (local.set $g (call $graph_node_at (local.get $h)))
    (local.set $nk (call $gnode_kind (local.get $g)))
    (if (i32.ne (call $node_kind_tag (local.get $nk)) (i32.const 64))
      (then
        (call $eprint_string (i32.const 3776))
        (call $eprint_string (i32.const 3168))
        (local.set $failed (i32.const 1))))
    (local.set $reason (call $node_kind_payload (local.get $nk)))
    (if (i32.ne (call $tag_of (local.get $reason)) (i32.const 221))
      (then
        (call $eprint_string (i32.const 3808))
        (call $eprint_string (i32.const 3168))
        (local.set $failed (i32.const 1))))

    ;; ── 11. $infer_emit_cannot_negate_capability — NErrorHole(Inferred) ──
    (local.set $h (call $graph_fresh_ty (i32.const 0)))
    (call $infer_emit_cannot_negate_capability (local.get $h) (i32.const 4000) (i32.const 0))
    (local.set $g (call $graph_node_at (local.get $h)))
    (local.set $nk (call $gnode_kind (local.get $g)))
    (if (i32.ne (call $node_kind_tag (local.get $nk)) (i32.const 64))
      (then
        (call $eprint_string (i32.const 3840))
        (call $eprint_string (i32.const 3168))
        (local.set $failed (i32.const 1))))
    (local.set $reason (call $node_kind_payload (local.get $nk)))
    (if (i32.ne (call $tag_of (local.get $reason)) (i32.const 221))
      (then
        (call $eprint_string (i32.const 3872))
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
