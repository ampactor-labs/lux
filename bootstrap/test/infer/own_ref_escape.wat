  ;; ═══ own_ref_escape.wat — trace-harness ═══════════════════════════
  ;; Executes: Hβ-infer-substrate.md §5 + src/own.mn:371-376 +
  ;;           §11.2 acceptance — ref-escape candidate matches return
  ;;           leaf, NErrorHole bound + diagnostic emitted; silent
  ;;           path negation also covered.
  ;;
  ;; Positive: $infer_ref_escape_push("buf", span_a) registers "buf"
  ;;           as a ref binding live in scope; returning "buf"
  ;;           (leaves = ["buf"]) at body_handle invokes
  ;;           $infer_ref_escape_check_at_return which detects the
  ;;           match via $own_list_contains_str and emits ref-escape
  ;;           diagnostic via $infer_emit_ref_escape, binding
  ;;           body_handle to NErrorHole(Inferred("ownership ref escape")).
  ;;
  ;; Negative: After clearing state, registering "buf" again but with
  ;;           leaves = ["other"] does NOT match; new body_handle
  ;;           remains NFree (silent path).
  ;;
  ;; Exercises: own.wat — $infer_ref_escape_check_at_return,
  ;;            $infer_emit_ref_escape; state.wat — $infer_ref_escape_push.
  ;; Per ROADMAP §5 + Hβ-infer-substrate.md §11.
  ;;
  ;; ─── Eight interrogations ─────────────────────────────────────────
  ;;   Graph?      Positive: body_handle bound to NErrorHole(reason).
  ;;               Negative: body_handle stays NFree (tag 61).
  ;;   Handler?    Direct seed call.
  ;;   Verb?       N/A.
  ;;   Row?        Caller's row composes Consume; this harness checks
  ;;               the structural escape detector.
  ;;   Ownership?  ref-escape entry OWNed by state.wat ledger; cleared
  ;;               between positive and negative cases via
  ;;               $infer_ref_escape_clear.
  ;;   Refinement? None.
  ;;   Gradient?   Diagnostic IS the gradient signal — Mentl voice
  ;;               surfaces canonical fix (change `ref` to `own` OR
  ;;               refactor return position) post-L1.
  ;;   Reason?     NErrorHole wraps Inferred("ownership ref escape")
  ;;               (Reason tag 221 per reason.wat).

  ;; Verdict labels (offsets ≥ 4096 to sit ABOVE own.wat's production
  ;; data range 3136-3382; harness/production overlap on diagnostic
  ;; emit paths broke the first iteration of this harness).
  (data (i32.const 4096) "\05\00\00\00PASS:")
  (data (i32.const 4128) "\05\00\00\00FAIL:")
  (data (i32.const 4160) "\01\00\00\00 ")
  (data (i32.const 4192) "\01\00\00\00\0a")

  ;; Harness display name
  (data (i32.const 4224) "\14\00\00\00own_ref_escape      ")

  ;; Per-assertion FAIL labels
  (data (i32.const 4256) "\14\00\00\00pos-handle-not-errh ")
  (data (i32.const 4288) "\14\00\00\00pos-reason-not-infrd")
  (data (i32.const 4320) "\14\00\00\00neg-handle-not-nfree")

  ;; Static argument strings
  (data (i32.const 4928) "\03\00\00\00buf")
  (data (i32.const 4960) "\05\00\00\00other")

  (func $_start (export "_start")
    (local $failed i32)
    (local $body_h_pos i32) (local $body_h_neg i32)
    (local $leaves_pos i32) (local $leaves_neg i32)
    (local $g i32) (local $nk i32) (local $reason i32)
    (local.set $failed (i32.const 0))
    (call $graph_init)
    (call $infer_ref_escape_clear)
    (call $infer_used_clear)

    ;; ── POSITIVE: register "buf" then check leaves = ["buf"] ──
    (call $infer_ref_escape_push (i32.const 4928) (i32.const 50))   ;; ("buf", span=50)

    ;; Build leaves list ["buf"]
    (local.set $leaves_pos (call $make_list (i32.const 1)))
    (drop (call $list_set (local.get $leaves_pos) (i32.const 0) (i32.const 4928)))

    ;; Mint body_handle (NFree)
    (local.set $body_h_pos (call $graph_fresh_ty (i32.const 0)))

    ;; Exercise: ref-escape check at return
    (call $infer_ref_escape_check_at_return
      (local.get $body_h_pos) (local.get $leaves_pos) (i32.const 0))

    ;; Assert body_h_pos NodeKind tag == 64 (NErrorHole)
    (local.set $g (call $graph_node_at (local.get $body_h_pos)))
    (local.set $nk (call $gnode_kind (local.get $g)))
    (if (i32.ne (call $node_kind_tag (local.get $nk)) (i32.const 64))
      (then
        (call $eprint_string (i32.const 4256))
        (call $eprint_string (i32.const 4192))
        (local.set $failed (i32.const 1))))

    ;; Assert wrapped Reason tag == 221 (Inferred)
    (local.set $reason (call $node_kind_payload (local.get $nk)))
    (if (i32.ne (call $tag_of (local.get $reason)) (i32.const 221))
      (then
        (call $eprint_string (i32.const 4288))
        (call $eprint_string (i32.const 4192))
        (local.set $failed (i32.const 1))))

    ;; ── NEGATIVE: clear ledger, register "buf", check leaves = ["other"] ──
    (call $infer_ref_escape_clear)
    (call $infer_ref_escape_push (i32.const 4928) (i32.const 60))   ;; ("buf", span=60)

    ;; Build leaves list ["other"]
    (local.set $leaves_neg (call $make_list (i32.const 1)))
    (drop (call $list_set (local.get $leaves_neg) (i32.const 0) (i32.const 4960)))

    ;; New body_handle
    (local.set $body_h_neg (call $graph_fresh_ty (i32.const 0)))

    (call $infer_ref_escape_check_at_return
      (local.get $body_h_neg) (local.get $leaves_neg) (i32.const 0))

    ;; Assert body_h_neg NodeKind tag == 61 (NFree) — silent path
    (local.set $g (call $graph_node_at (local.get $body_h_neg)))
    (local.set $nk (call $gnode_kind (local.get $g)))
    (if (i32.ne (call $node_kind_tag (local.get $nk)) (i32.const 61))
      (then
        (call $eprint_string (i32.const 4320))
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
