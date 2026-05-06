  ;; ═══ own_consume_first.wat — trace-harness ════════════════════════
  ;; Executes: Hβ-infer-substrate.md §5 + §11 acceptance — first-time
  ;;           consume path. Per src/own.mn:104-113 consume arm:
  ;;             - $infer_consume_seen returns 0 before call.
  ;;             - $infer_consume_use(handle, name, span, reason)
  ;;               inserts name into used + pushes (name, span) to
  ;;               used_sites; NO diagnostic; NO graph mutation.
  ;;             - $infer_consume_seen returns 1 after call.
  ;;             - Handle's NodeKind tag NOT 64 (NErrorHole) — silent path.
  ;; Exercises: own.wat — $infer_consume_use, $infer_consume_seen,
  ;;            $own_used_insert, $own_used_sites_push.
  ;; Per ROADMAP §5 + Hβ-infer-substrate.md §11.
  ;;
  ;; ─── Eight interrogations ─────────────────────────────────────────
  ;;   Graph?      One NFree handle. Silent path = no $graph_bind_kind.
  ;;   Handler?    Direct seed call.
  ;;   Verb?       N/A.
  ;;   Row?        Caller's row gains Consume; this harness exercises
  ;;               the ledger detector, not row composition.
  ;;   Ownership?  Ledger acquires "x"; ledger entry owned by FnStmt-scope
  ;;               (which the harness simulates via fresh $own_init state).
  ;;   Refinement? None.
  ;;   Gradient?   First consume IS the gradient step from "no info" to
  ;;               "name consumed once" — a teaching-relevant transition.
  ;;   Reason?     No Reason on the handle (silent path).

  ;; Verdict labels (32-byte slots from 4096; sit ABOVE own.wat's
  ;; production data range 3136-3382 to avoid harness/production overlap
  ;; on diagnostic emit paths).
  (data (i32.const 4096) "\05\00\00\00PASS:")
  (data (i32.const 4128) "\05\00\00\00FAIL:")
  (data (i32.const 4160) "\01\00\00\00 ")
  (data (i32.const 4192) "\01\00\00\00\0a")

  ;; Harness display name
  (data (i32.const 4224) "\14\00\00\00own_consume_first   ")

  ;; Per-assertion FAIL labels
  (data (i32.const 4256) "\14\00\00\00seen-before-call    ")
  (data (i32.const 4288) "\14\00\00\00not-seen-after-call ")
  (data (i32.const 4320) "\14\00\00\00handle-bound-errhole")

  ;; Static argument string — the consumed name "x"
  (data (i32.const 4928) "\01\00\00\00x")

  (func $_start (export "_start")
    (local $failed i32)
    (local $h i32) (local $g i32) (local $nk i32)
    (local.set $failed (i32.const 0))
    (call $graph_init)
    (call $infer_used_clear)

    ;; ── Setup: fresh handle (NFree) ──
    (local.set $h (call $graph_fresh_ty (i32.const 0)))

    ;; ── Assert $infer_consume_seen("x") == 0 before call ──
    (if (call $infer_consume_seen (i32.const 4928))
      (then
        (call $eprint_string (i32.const 4256))
        (call $eprint_string (i32.const 4192))
        (local.set $failed (i32.const 1))))

    ;; ── Exercise: $infer_consume_use(h, "x", span=42, reason=0) ──
    (call $infer_consume_use (local.get $h) (i32.const 4928)
                              (i32.const 42) (i32.const 0))

    ;; ── Assert $infer_consume_seen("x") == 1 after call ──
    (if (i32.eqz (call $infer_consume_seen (i32.const 4928)))
      (then
        (call $eprint_string (i32.const 4288))
        (call $eprint_string (i32.const 4192))
        (local.set $failed (i32.const 1))))

    ;; ── Assert handle's NodeKind tag NOT 64 (NErrorHole) — silent path ──
    (local.set $g (call $graph_node_at (local.get $h)))
    (local.set $nk (call $gnode_kind (local.get $g)))
    (if (i32.eq (call $node_kind_tag (local.get $nk)) (i32.const 64))
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
