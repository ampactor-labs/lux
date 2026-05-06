  ;; ═══ lexpr_handle_universal.wat — Hβ.lower trace-harness ════════════
  ;; Executes: Hβ-lower-substrate.md §2 lines 287-289 + §6 + §11 —
  ;;           $lexpr_handle universal accessor across 4 variants,
  ;;           including the tag-313 LDeclareFn anomaly arm.
  ;; Exercises: lexpr.wat — $lexpr_make_lconst, $lexpr_make_lcall,
  ;;            $lexpr_make_lif, $lexpr_make_ldeclarefn, $lexpr_handle.
  ;; Per Hβ-lower-substrate.md §9 + §13 acceptance.
  ;;
  ;; Eight interrogations:
  ;;   Graph?      Three variants carry real graph handles (100, 200, 300);
  ;;               LDeclareFn carries a LowFn ptr (999) and returns 0.
  ;;   Handler?    Direct calls; no handler dispatch at constructor layer.
  ;;   Verb?       N/A — harness is a sequential roundtrip check.
  ;;   Row?        Pure at constructor layer.
  ;;   Ownership?  Each $lexpr_make_* returns own of its record; harness
  ;;               reads back via ref $lexpr_handle.
  ;;   Refinement? None at this layer.
  ;;   Gradient?   The tag-313 arm of $lexpr_handle IS the load-bearing
  ;;               gradient step: LDeclareFn returns 0, NOT 999. Without
  ;;               the dispatch arm, $record_get(r, 0) would return 999
  ;;               (the LowFn ptr) — a semantic error masked silently.
  ;;               This harness catches that regression.
  ;;   Reason?     Graph handles are sentinels; no Reason chain needed.

  (data (i32.const 3072) "\05\00\00\00PASS:")
  (data (i32.const 3084) "\05\00\00\00FAIL:")
  (data (i32.const 3096) "\01\00\00\00 ")
  (data (i32.const 3104) "\01\00\00\00\0a")
  (data (i32.const 3120) "\18\00\00\00lexpr_handle_universal ")

  (func $_start (export "_start")
    (local $failed i32)
    (local $r1 i32) (local $r2 i32) (local $r3 i32) (local $r4 i32)
    (local.set $failed (i32.const 0))

    ;; r1 = LConst(h=100, value=0) → $lexpr_handle(r1) == 100
    (local.set $r1 (call $lexpr_make_lconst (i32.const 100) (i32.const 0)))
    (if (i32.ne (call $lexpr_handle (local.get $r1)) (i32.const 100))
      (then (local.set $failed (i32.const 1))))

    ;; r2 = LCall(h=200, fn=0, args=0) → $lexpr_handle(r2) == 200
    (local.set $r2 (call $lexpr_make_lcall (i32.const 200) (i32.const 0) (i32.const 0)))
    (if (i32.ne (call $lexpr_handle (local.get $r2)) (i32.const 200))
      (then (local.set $failed (i32.const 1))))

    ;; r3 = LIf(h=300, cond=0, then=0, else=0) → $lexpr_handle(r3) == 300
    (local.set $r3 (call $lexpr_make_lif (i32.const 300) (i32.const 0) (i32.const 0) (i32.const 0)))
    (if (i32.ne (call $lexpr_handle (local.get $r3)) (i32.const 300))
      (then (local.set $failed (i32.const 1))))

    ;; r4 = LDeclareFn(fn=999) → $lexpr_handle(r4) == 0 (NOT 999)
    ;; tag-313 dispatch arm in $lexpr_handle returns i32.const 0 per
    ;; src/lower.mn:187 wheel canonical + §11 audit lock.
    (local.set $r4 (call $lexpr_make_ldeclarefn (i32.const 999)))
    (if (i32.ne (call $lexpr_handle (local.get $r4)) (i32.const 0))
      (then (local.set $failed (i32.const 1))))

    ;; Also verify $lexpr_ldeclarefn_fn returns 999 (field 0 IS the fn ptr).
    (if (i32.ne (call $lexpr_ldeclarefn_fn (local.get $r4)) (i32.const 999))
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
