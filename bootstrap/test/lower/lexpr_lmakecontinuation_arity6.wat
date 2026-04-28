  ;; ═══ lexpr_lmakecontinuation_arity6.wat — Hβ.lower trace-harness ═════
  ;; Executes: Hβ-lower-substrate.md §2 — LMakeContinuation (tag 312,
  ;;           arity 6) — H7 multi-shot; all 6 accessors roundtrip.
  ;; Exercises: lexpr.wat — $lexpr_make_lmakecontinuation,
  ;;            $lexpr_handle, $lexpr_lmakecontinuation_fn,
  ;;            $lexpr_lmakecontinuation_caps, $lexpr_lmakecontinuation_evs,
  ;;            $lexpr_lmakecontinuation_state_idx,
  ;;            $lexpr_lmakecontinuation_ret_slot.
  ;; Per Hβ-lower-substrate.md §9 + §13 acceptance.
  ;;
  ;; Eight interrogations:
  ;;   Graph?      LMakeContinuation field 0 is graph handle (h=1).
  ;;   Handler?    Direct call to $lexpr_make_lmakecontinuation.
  ;;   Verb?       <~ shape — LMakeContinuation is the H7 multi-shot
  ;;               continuation substrate; resumes are iterative feedback.
  ;;   Row?        Pure at constructor layer; row checks at walk_handle.
  ;;   Ownership?  Returned own from bump allocator; 6 $record_set calls.
  ;;   Refinement? None at this layer.
  ;;   Gradient?   This harness IS the proof that all 6 $record_set
  ;;               offsets (0-5) are correctly ordered. A swap between
  ;;               any pair — e.g., state_idx and ret_slot — would
  ;;               surface here. Critical for H7 correctness.
  ;;   Reason?     Graph handle h=1 is a sentinel; no Reason needed.

  (data (i32.const 3072) "\05\00\00\00PASS:")
  (data (i32.const 3084) "\05\00\00\00FAIL:")
  (data (i32.const 3096) "\01\00\00\00 ")
  (data (i32.const 3104) "\01\00\00\00\0a")
  (data (i32.const 3120) "\21\00\00\00lexpr_lmakecontinuation_arity6 ")

  (func $_start (export "_start")
    (local $failed i32)
    (local $r i32)
    (local.set $failed (i32.const 0))

    ;; Build LMakeContinuation(h=1, fn=2, caps=3, evs=4, state_idx=5, ret_slot=6).
    (local.set $r (call $lexpr_make_lmakecontinuation
      (i32.const 1) (i32.const 2) (i32.const 3)
      (i32.const 4) (i32.const 5) (i32.const 6)))

    ;; Check tag == 312.
    (if (i32.ne (call $tag_of (local.get $r)) (i32.const 312))
      (then (local.set $failed (i32.const 1))))

    ;; Check $lexpr_handle returns h=1.
    (if (i32.ne (call $lexpr_handle (local.get $r)) (i32.const 1))
      (then (local.set $failed (i32.const 1))))

    ;; Check fn=2.
    (if (i32.ne (call $lexpr_lmakecontinuation_fn (local.get $r)) (i32.const 2))
      (then (local.set $failed (i32.const 1))))

    ;; Check caps=3.
    (if (i32.ne (call $lexpr_lmakecontinuation_caps (local.get $r)) (i32.const 3))
      (then (local.set $failed (i32.const 1))))

    ;; Check evs=4.
    (if (i32.ne (call $lexpr_lmakecontinuation_evs (local.get $r)) (i32.const 4))
      (then (local.set $failed (i32.const 1))))

    ;; Check state_idx=5.
    (if (i32.ne (call $lexpr_lmakecontinuation_state_idx (local.get $r)) (i32.const 5))
      (then (local.set $failed (i32.const 1))))

    ;; Check ret_slot=6.
    (if (i32.ne (call $lexpr_lmakecontinuation_ret_slot (local.get $r)) (i32.const 6))
      (then (local.set $failed (i32.const 1))))

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
