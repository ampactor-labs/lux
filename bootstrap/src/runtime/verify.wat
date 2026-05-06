  ;; ═══ verify.wat — Verify ledger primitives (Tier 4) ═══════════════
  ;; Implements: Hβ §1.11 + spec 06 (effects-surface) — Verify
  ;;             obligation accumulation. The seed's verify substrate
  ;;             holds an in-memory ledger of pending refinement
  ;;             obligations; real SMT discharge (verify_smt) is the
  ;;             handler swap shipped at B.6 / Arc F.1 post-L1.
  ;; Exports:    $verify_init,
  ;;             $verify_record,
  ;;             $verify_pending_count,
  ;;             $verify_get_pending,
  ;;             $verify_discharge_at,
  ;;             $verify_obligation_make/predicate/span/reason
  ;; Uses:       $alloc (alloc.wat), $make_record/$record_get/$record_set
  ;;             (record.wat), $make_list/$list_index/$list_set/
  ;;             $list_extend_to/$len (list.wat)
  ;; Test:       runtime_test/verify.wat
  ;;
  ;; ═══ DESIGN ═══════════════════════════════════════════════════════
  ;; Per spec 06 + DESIGN §0.5 primitive #6 (Refinement types):
  ;;
  ;; Refinement types are compile-time proofs; runtime erased per
  ;; spec 06. The Verify effect accumulates obligations that the
  ;; verify_ledger handler tracks; ground obligations (those decidable
  ;; from graph state alone — handle == constant predicates etc.)
  ;; can be discharged immediately. The remainder become V_Pending
  ;; until a richer handler (verify_smt — Arc F.1, swappable via
  ;; ~> verify_smt) discharges them via Z3 / cvc5 / Bitwuzla.
  ;;
  ;; The seed's verify substrate is the LEDGER ONLY — it accumulates
  ;; obligations as opaque records (predicate ptr + span ptr + reason
  ;; ptr) and exposes them for query/diagnosis. The seed never
  ;; discharges via SMT — that's post-L1 swap-handler work per
  ;; verify_kernel walkthrough (VK; pending walkthrough).
  ;;
  ;; ═══ HEAP RECORD LAYOUT ═══════════════════════════════════════════
  ;;
  ;; VerifyObligation record:
  ;;   $make_record(VERIFY_OBLIGATION_TAG=180, arity=3)
  ;;     offset  8: field_0 = predicate (opaque ptr — Ty/Expr ptr per
  ;;                          Hβ.infer; verify.wat treats as i32)
  ;;     offset 12: field_1 = span (opaque ptr — source location record)
  ;;     offset 16: field_2 = reason (opaque ptr — Reason record)
  ;;
  ;; Tag allocation: verify.wat private region 180-199 (avoids row.wat
  ;; 150-179 + env.wat 130-149 + graph.wat 50-99 + TokenKind 0-44).

  ;; ─── Module-level globals ─────────────────────────────────────────
  ;; $verify_ledger_ptr — flat list of VerifyObligation pointers
  ;;                      (the pending ledger).
  ;; $verify_ledger_len_g — logical count of pending obligations.
  ;; $verify_initialized — 1 once $verify_init has run.

  (global $verify_ledger_ptr   (mut i32) (i32.const 0))
  (global $verify_ledger_len_g (mut i32) (i32.const 0))
  (global $verify_initialized  (mut i32) (i32.const 0))

  ;; ─── Initialization ──────────────────────────────────────────────
  (func $verify_init
    (if (global.get $verify_initialized) (then (return)))
    (global.set $verify_ledger_ptr (call $make_list (i32.const 16)))
    (global.set $verify_ledger_len_g (i32.const 0))
    (global.set $verify_initialized (i32.const 1)))

  ;; ─── Obligation constructor + accessors ──────────────────────────

  (func $verify_obligation_make (param $predicate i32) (param $span i32) (param $reason i32)
                                (result i32)
    (local $o i32)
    (local.set $o (call $make_record (i32.const 180) (i32.const 3)))
    (call $record_set (local.get $o) (i32.const 0) (local.get $predicate))
    (call $record_set (local.get $o) (i32.const 1) (local.get $span))
    (call $record_set (local.get $o) (i32.const 2) (local.get $reason))
    (local.get $o))

  (func $verify_obligation_predicate (param $o i32) (result i32)
    (call $record_get (local.get $o) (i32.const 0)))

  (func $verify_obligation_span (param $o i32) (result i32)
    (call $record_get (local.get $o) (i32.const 1)))

  (func $verify_obligation_reason (param $o i32) (result i32)
    (call $record_get (local.get $o) (i32.const 2)))

  ;; ─── Record + query ──────────────────────────────────────────────

  ;; $verify_record — append a new obligation to the pending ledger.
  ;; Caller constructs (predicate, span, reason) opaque pointers per
  ;; Hβ.infer's Verify-effect handler arm.
  (func $verify_record (param $predicate i32) (param $span i32) (param $reason i32)
    (local $o i32)
    (call $verify_init)
    (local.set $o (call $verify_obligation_make
                    (local.get $predicate)
                    (local.get $span)
                    (local.get $reason)))
    (global.set $verify_ledger_ptr
      (call $list_set
        (call $list_extend_to (global.get $verify_ledger_ptr)
                              (i32.add (global.get $verify_ledger_len_g) (i32.const 1)))
        (global.get $verify_ledger_len_g)
        (local.get $o)))
    (global.set $verify_ledger_len_g
      (i32.add (global.get $verify_ledger_len_g) (i32.const 1))))

  ;; $verify_pending_count — number of pending obligations in the ledger.
  ;; Used by query / diagnostic surfaces (`mentl check` reports the
  ;; V_Pending count; B.6 verify_smt swap reduces this by discharging
  ;; ground obligations).
  (func $verify_pending_count (result i32)
    (call $verify_init)
    (global.get $verify_ledger_len_g))

  ;; $verify_get_pending — return obligation at index i (0..pending_count).
  ;; Out-of-range returns 0 (defensive — well-formed callers respect
  ;; the count).
  (func $verify_get_pending (param $i i32) (result i32)
    (call $verify_init)
    (if (i32.ge_u (local.get $i) (global.get $verify_ledger_len_g))
      (then (return (i32.const 0))))
    (call $list_index (global.get $verify_ledger_ptr) (local.get $i)))

  ;; $verify_discharge_at — mark obligation at index as discharged
  ;; (sets the slot to 0; pending_count unchanged for now — compaction
  ;; is the named follow-up). Per VK walkthrough discipline: real
  ;; discharge happens via verify_smt handler swap; this primitive
  ;; lets the ledger track discharge state without recompacting.
  ;;
  ;; Conservative scope: this Tier-4 base does NOT call out to SMT;
  ;; it simply records that an obligation has been resolved. Callers
  ;; (Hβ.infer + Hβ.lower + future verify_smt swap) own the discharge
  ;; semantics. Per Anchor 7: discharge logic is its own concern —
  ;; verify.wat owns the ledger storage.
  (func $verify_discharge_at (param $i i32)
    (call $verify_init)
    (if (i32.ge_u (local.get $i) (global.get $verify_ledger_len_g))
      (then (return)))
    (drop (call $list_set (global.get $verify_ledger_ptr)
                          (local.get $i)
                          (i32.const 0))))
