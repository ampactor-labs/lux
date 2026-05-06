  ;; ═══ reason_promote_smoke.wat — Hβ.first-light.infer-perm-pressure ═
  ;; Substrate acceptance per Hβ-first-light.infer-perm-pressure-substrate.md
  ;; §F + §E.5 (verification gate). Six-phase explicit-surface acceptance
  ;; for the promote-on-bind discipline:
  ;;
  ;;   Phase 1 — $make_record_stage range:
  ;;     $make_record_stage(220, 1) returns ptr in [1537 MiB, 1921 MiB).
  ;;   Phase 2 — $reason_in_perm predicate (stage):
  ;;     $reason_in_perm(stage_ptr) returns 0 (stage region is NOT perm).
  ;;   Phase 3 — $reason_in_perm predicate (perm):
  ;;     $reason_in_perm(perm_ptr) returns 1 (perm region IS stable).
  ;;   Phase 4 — $reason_promote_deep recursive promotion:
  ;;     Build $reason_make_located(span, $reason_make_inferred(ctx)) in
  ;;     stage. Promote. Outer ptr lands in perm; inner field-1 also in perm.
  ;;   Phase 5 — $reason_promote_deep idempotency on perm input:
  ;;     Promoting an already-perm Reason returns the input unchanged.
  ;;   Phase 6 — $gnode_make promote-on-bind + survive $stage_reset:
  ;;     $gnode_make(nk, stage_reason) returns a GNode whose reason field
  ;;     is in perm region. After $stage_reset, the reason field is still
  ;;     dereferenceable and the tag matches the original.
  ;;
  ;; Per drift-mode-9 closure: every export added by §C.1-§C.4
  ;; ($make_record_stage / $reason_in_perm / $reason_promote_deep /
  ;; $gnode_make-with-promote) is exercised by at least one phase.

  (data (i32.const 3072) "\05\00\00\00PASS:")
  (data (i32.const 3084) "\05\00\00\00FAIL:")
  (data (i32.const 3096) "\01\00\00\00 ")
  (data (i32.const 3104) "\01\00\00\00\0a")
  (data (i32.const 3120) "\14\00\00\00reason_promote_smoke")

  (data (i32.const 3168) "\1d\00\00\00phase1-stage-range-bad       ")
  (data (i32.const 3200) "\1f\00\00\00phase2-in-perm-stage-bad     ")
  (data (i32.const 3232) "\1e\00\00\00phase3-in-perm-perm-bad      ")
  (data (i32.const 3264) "\1d\00\00\00phase4-promote-outer-range   ")
  (data (i32.const 3296) "\1d\00\00\00phase4-promote-inner-range   ")
  (data (i32.const 3328) "\1d\00\00\00phase5-idempotency-bad       ")
  (data (i32.const 3360) "\1d\00\00\00phase6-gnode-reason-range    ")
  (data (i32.const 3392) "\1d\00\00\00phase6-post-reset-tag-bad    ")

  (func $_start (export "_start")
    (local $failed i32)
    (local $stage_r i32) (local $perm_r i32)
    (local $stage_inner i32) (local $stage_outer i32)
    (local $promoted i32) (local $promoted_inner i32)
    (local $idempotent i32)
    (local $nk i32) (local $reason_after_bind i32) (local $g i32)
    (local $reason_field i32)
    (local.set $failed (i32.const 0))

    ;; ─── Phase 1: $make_record_stage in stage region ────────────────
    ;; Reason variant 220 = Declared(String); arity 1 → 12 bytes.
    (local.set $stage_r (call $make_record_stage (i32.const 220) (i32.const 1)))
    (if (i32.or
          (i32.lt_u (local.get $stage_r) (i32.const 1611137024))
          (i32.ge_u (local.get $stage_r) (i32.const 2014314496)))
      (then (call $eprint_string (i32.const 3168))
            (call $eprint_string (i32.const 3104))
            (local.set $failed (i32.const 1))))

    ;; ─── Phase 2: $reason_in_perm returns 0 for stage ptr ──────────
    (if (call $reason_in_perm (local.get $stage_r))
      (then (call $eprint_string (i32.const 3200))
            (call $eprint_string (i32.const 3104))
            (local.set $failed (i32.const 1))))

    ;; ─── Phase 3: $reason_in_perm returns 1 for perm ptr ──────────
    ;; $make_record routes through $alloc → $perm_alloc; result is perm.
    (local.set $perm_r (call $make_record (i32.const 220) (i32.const 1)))
    (if (i32.eqz (call $reason_in_perm (local.get $perm_r)))
      (then (call $eprint_string (i32.const 3232))
            (call $eprint_string (i32.const 3104))
            (local.set $failed (i32.const 1))))

    ;; ─── Phase 4: $reason_promote_deep recursive on Located/Inferred
    ;; Build an Inferred(ctx_string=0) in stage. Tag 221 arity 1.
    (local.set $stage_inner (call $reason_make_inferred (i32.const 0)))
    ;; Build a Located(span=0, inner) wrapping the Inferred in stage.
    ;; $reason_make_located is tag 238 arity 2; field 0 = span (opaque),
    ;; field 1 = inner Reason. Both records sit in stage at this point.
    (local.set $stage_outer
      (call $reason_make_located (i32.const 0) (local.get $stage_inner)))
    ;; Promote-deep: outer should land in perm; inner field should also
    ;; land in perm (recursive descent is the §B.8 protocol).
    (local.set $promoted (call $reason_promote_deep (local.get $stage_outer)))
    (if (i32.eqz (call $reason_in_perm (local.get $promoted)))
      (then (call $eprint_string (i32.const 3264))
            (call $eprint_string (i32.const 3104))
            (local.set $failed (i32.const 1))))
    ;; field 1 of the promoted Located is the promoted inner Inferred.
    (local.set $promoted_inner
      (call $record_get (local.get $promoted) (i32.const 1)))
    (if (i32.eqz (call $reason_in_perm (local.get $promoted_inner)))
      (then (call $eprint_string (i32.const 3296))
            (call $eprint_string (i32.const 3104))
            (local.set $failed (i32.const 1))))

    ;; ─── Phase 5: idempotency on perm-resident input ──────────────
    ;; Promoting an already-perm Reason returns the input unchanged
    ;; (i.e., pointer-equal).
    (local.set $idempotent (call $reason_promote_deep (local.get $promoted)))
    (if (i32.ne (local.get $idempotent) (local.get $promoted))
      (then (call $eprint_string (i32.const 3328))
            (call $eprint_string (i32.const 3104))
            (local.set $failed (i32.const 1))))

    ;; ─── Phase 6: $gnode_make promote-on-bind + survives $stage_reset
    ;; Allocate a fresh stage Reason and a NodeKind. $node_kind_make_nfree
    ;; returns a perm-region NodeKind. $gnode_make should promote the
    ;; stage Reason to perm BEFORE storing it in the GNode.
    (local.set $reason_after_bind
      (call $reason_make_inferred (i32.const 0)))
    (local.set $nk (call $node_kind_make_nfree (i32.const 0)))
    (local.set $g
      (call $gnode_make (local.get $nk) (local.get $reason_after_bind)))
    (local.set $reason_field (call $gnode_reason (local.get $g)))
    (if (i32.eqz (call $reason_in_perm (local.get $reason_field)))
      (then (call $eprint_string (i32.const 3360))
            (call $eprint_string (i32.const 3104))
            (local.set $failed (i32.const 1))))
    ;; Reset the stage arena. The original $reason_after_bind pointer is
    ;; now invalid; the GNode's reason field MUST still be readable
    ;; because it points at the perm copy, not the stage original.
    (call $stage_reset)
    ;; Re-read the gnode's reason field; the tag must still be 221
    ;; (Inferred). $tag_of dereferences the pointer to read the stored tag.
    (if (i32.ne (call $tag_of (call $gnode_reason (local.get $g)))
                 (i32.const 221))
      (then (call $eprint_string (i32.const 3392))
            (call $eprint_string (i32.const 3104))
            (local.set $failed (i32.const 1))))

    ;; ─── Verdict ──────────────────────────────────────────────────
    (if (local.get $failed)
      (then (call $eprint_string (i32.const 3084))
            (call $eprint_string (i32.const 3096))
            (call $eprint_string (i32.const 3120))
            (call $eprint_string (i32.const 3104))
            (call $wasi_proc_exit (i32.const 1)))
      (else (call $eprint_string (i32.const 3072))
            (call $eprint_string (i32.const 3096))
            (call $eprint_string (i32.const 3120))
            (call $eprint_string (i32.const 3104))
            (call $wasi_proc_exit (i32.const 0)))))
