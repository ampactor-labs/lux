  ;; ═══ match_arm_binding_uniqueness.wat ════════════════════════════════
  ;; Hβ.first-light.match-arm-binding-name-uniqueness harness.
  ;; Per docs/specs/simulations/Hβ-first-light.match-arm-binding-name-
  ;; uniqueness.md §8 + §10 (E.5 acceptance gate).
  ;;
  ;; Constructs a hand-authored LowFn whose body is:
  ;;   LMatch(scrut=LLocal($t), arms=[
  ;;     LPArm(LPCon(h, 0, [LPVar(h, "fields")]), LLocal($fields)),
  ;;     LPArm(LPCon(h, 1, [LPVar(h, "fields")]), LLocal($fields)),
  ;;   ])
  ;; Calls $emit_fn_body. Scans output for "(local $fields i32)"
  ;; occurrences. Exits 0 on PASS (count == 1), 1 on FAIL.
  ;;
  ;; Pre-fix behavior: $emit_pat_locals emitted (local $fields i32)
  ;; for each LPVar encountered with no de-dup; two arms binding
  ;; "fields" produced two preamble decls; wat2wasm rejected with
  ;; `redefinition of local "$fields"`.
  ;; Post-fix: $emit_fn_local_check is consulted before each
  ;; (local $<name> i32) emission; the second arm's LPVar lookup
  ;; finds "fields" already in the per-fn ledger and short-circuits.
  ;; The fn preamble has exactly one (local $fields i32).
  ;;
  ;; ─── Eight interrogations ───────────────────────────────────────────
  ;;   Graph?      Harness allocates handle h via $graph_fresh_ty +
  ;;               $graph_bind to TInt; LPVar carries name string-ptr.
  ;;   Handler?    Direct call to $emit_fn_body — the local-decl
  ;;               handler under test, plus the new $emit_fn_local_check
  ;;               state.wat ledger ($emit_fn_locals_ptr +
  ;;               $emit_fn_locals_len_g).
  ;;   Verb?       N/A — direct emission test.
  ;;   Row?        EmitMemory (writes to $out_base via $emit_str /
  ;;               $emit_cstr inside $emit_pat_locals; ledger ops via
  ;;               $list_extend_to / $list_set).
  ;;   Ownership?  LowPat / LowExpr / LowFn records owned by harness;
  ;;               ledger str_ptrs `ref`-stored.
  ;;   Refinement? LPVar.name non-zero string-ptr; $str_eq scan.
  ;;   Gradient?   Local-decl synthesis derived from LowPat structure.
  ;;               Compile-time cashout (LowFn.local_decl_set) named
  ;;               peer follow-up.
  ;;   Reason?     LPVar handle preserves chain (not exercised here).
  ;;
  ;; ─── Forbidden patterns audited ─────────────────────────────────────
  ;;   - Drift 1 (vtable):      No dispatch table; ledger is flat list.
  ;;   - Drift 6 (special):     Both arms walked through same path.
  ;;   - Drift 7 (parallel):    Single seen-name list; no parallel arrays.
  ;;   - Drift 8 (string-key):  LPCon tag_id is i32; LPVar name is
  ;;                            string because WAT $-tokens are.
  ;;   - Drift 9 (deferred):    All binding-introducing LowPat variants
  ;;                            covered by their own arms in $emit_pat_locals;
  ;;                            this harness exercises the LPCon-sub-LPVar
  ;;                            shape (the empirical motivator).

  ;; ─── Harness-private data segments ──────────────────────────────────
  (data (i32.const 3072) "\05\00\00\00PASS:")
  (data (i32.const 3084) "\05\00\00\00FAIL:")
  (data (i32.const 3096) "\01\00\00\00 ")
  (data (i32.const 3104) "\01\00\00\00\0a")

  ;; Harness display name — "match_arm_binding_uniqueness " (29 chars)
  (data (i32.const 3120) "\1d\00\00\00match_arm_binding_uniqueness ")

  ;; Per-assertion FAIL labels — 32-byte slots
  (data (i32.const 3168) "\1c\00\00\00local-fields-missing        ")
  (data (i32.const 3200) "\1c\00\00\00local-fields-duplicated     ")

  ;; Strings for the LowFn / pattern (length-prefixed):
  ;; "f" — 1 byte (fn name)
  (data (i32.const 3328) "\01\00\00\00f")
  ;; "t" — 1 byte (fn param)
  (data (i32.const 3344) "\01\00\00\00t")
  ;; "fields" — 6 bytes (binding name shared across both arms)
  (data (i32.const 3360) "\06\00\00\00fields")

  ;; Substring "(local $fields i32)" — 19 bytes — to scan for in output
  (data (i32.const 3392) "\13\00\00\00(local $fields i32)")

  ;; ─── _start ─────────────────────────────────────────────────────────
  (func $_start (export "_start")
    (local $failed i32)
    (local $h i32)
    (local $params i32)
    (local $arm0_pat_args i32)
    (local $arm0_pat i32) (local $arm0_body i32) (local $arm0 i32)
    (local $arm1_pat_args i32)
    (local $arm1_pat i32) (local $arm1_body i32) (local $arm1 i32)
    (local $arms i32)
    (local $scrut i32)
    (local $match_expr i32)
    (local $body_list i32)
    (local $fn_r i32)
    (local $count i32)
    (local.set $failed (i32.const 0))

    ;; Initialize emit + graph state.
    (call $emit_init)
    (call $graph_init)

    ;; Build handle h bound to TInt.
    (local.set $h (call $graph_fresh_ty (call $reason_make_fresh (i32.const 0))))
    (call $graph_bind (local.get $h)
                      (call $ty_make_tint)
                      (call $reason_make_fresh (i32.const 0)))

    ;; ─── Build params ["t"] ───────────────────────────────────────────
    (local.set $params (call $make_list (i32.const 1)))
    (local.set $params (call $list_extend_to (local.get $params) (i32.const 1)))
    (drop (call $list_set (local.get $params) (i32.const 0) (i32.const 3344))) ;; "t"

    ;; ─── Arm 0: LPArm(LPCon(h, 0, [LPVar(h, "fields")]), LLocal(h, "fields")) ─
    (local.set $arm0_pat_args (call $make_list (i32.const 1)))
    (local.set $arm0_pat_args (call $list_extend_to (local.get $arm0_pat_args) (i32.const 1)))
    (drop (call $list_set (local.get $arm0_pat_args) (i32.const 0)
            (call $lowpat_make_lpvar (local.get $h) (i32.const 3360))))
    (local.set $arm0_pat
      (call $lowpat_make_lpcon (local.get $h) (i32.const 0) (local.get $arm0_pat_args)))
    (local.set $arm0_body (call $lexpr_make_llocal (local.get $h) (i32.const 3360)))
    (local.set $arm0 (call $lowpat_make_lparm (local.get $arm0_pat) (local.get $arm0_body)))

    ;; ─── Arm 1: LPArm(LPCon(h, 1, [LPVar(h, "fields")]), LLocal(h, "fields")) ─
    ;; Same binding name as Arm 0 — the empirical bug shape.
    (local.set $arm1_pat_args (call $make_list (i32.const 1)))
    (local.set $arm1_pat_args (call $list_extend_to (local.get $arm1_pat_args) (i32.const 1)))
    (drop (call $list_set (local.get $arm1_pat_args) (i32.const 0)
            (call $lowpat_make_lpvar (local.get $h) (i32.const 3360))))
    (local.set $arm1_pat
      (call $lowpat_make_lpcon (local.get $h) (i32.const 1) (local.get $arm1_pat_args)))
    (local.set $arm1_body (call $lexpr_make_llocal (local.get $h) (i32.const 3360)))
    (local.set $arm1 (call $lowpat_make_lparm (local.get $arm1_pat) (local.get $arm1_body)))

    ;; ─── arms = [arm0, arm1] ──────────────────────────────────────────
    (local.set $arms (call $make_list (i32.const 2)))
    (local.set $arms (call $list_extend_to (local.get $arms) (i32.const 2)))
    (drop (call $list_set (local.get $arms) (i32.const 0) (local.get $arm0)))
    (drop (call $list_set (local.get $arms) (i32.const 1) (local.get $arm1)))

    ;; ─── Build LMatch(0, scrut=LLocal(h, "t"), arms) ──────────────────
    (local.set $scrut (call $lexpr_make_llocal (local.get $h) (i32.const 3344)))
    (local.set $match_expr
      (call $lexpr_make_lmatch (i32.const 0) (local.get $scrut) (local.get $arms)))

    ;; ─── body = [match_expr] (LowExpr list) ───────────────────────────
    (local.set $body_list (call $make_list (i32.const 1)))
    (local.set $body_list (call $list_extend_to (local.get $body_list) (i32.const 1)))
    (drop (call $list_set (local.get $body_list) (i32.const 0) (local.get $match_expr)))

    ;; ─── Build LowFn("f", 1, params, body, 0) ─────────────────────────
    (local.set $fn_r (call $lowfn_make
      (i32.const 3328)             ;; name "f"
      (i32.const 1)                ;; arity
      (local.get $params)
      (local.get $body_list)
      (i32.const 0)))              ;; row (unused in this test)

    ;; Reset and emit.
    (global.set $out_pos (i32.const 0))
    (call $emit_fn_body (local.get $fn_r))

    ;; ── Check 1: "(local $fields i32)" appears at least once ──
    (local.set $count (call $count_substr (i32.const 3392)))
    (if (i32.eqz (local.get $count))
      (then
        (call $eprint_string (i32.const 3168))
        (call $eprint_string (i32.const 3104))
        (local.set $failed (i32.const 1))))

    ;; ── Check 2: "(local $fields i32)" appears EXACTLY once ──
    (if (i32.gt_u (local.get $count) (i32.const 1))
      (then
        (call $eprint_string (i32.const 3200))
        (call $eprint_string (i32.const 3104))
        (local.set $failed (i32.const 1))))

    ;; ── Verdict ──
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

  ;; ─── $count_substr — count occurrences of length-prefixed string ────
  ;; in the output buffer [out_base, out_base+out_pos). Linear scan.
  (func $count_substr (param $needle i32) (result i32)
    (local $needle_len i32) (local $i i32) (local $j i32)
    (local $end i32) (local $ok i32) (local $count i32)
    (local.set $needle_len (i32.load (local.get $needle)))
    (local.set $count (i32.const 0))
    (if (i32.eqz (local.get $needle_len))
      (then (return (i32.const 0))))
    (if (i32.gt_u (local.get $needle_len) (global.get $out_pos))
      (then (return (i32.const 0))))
    (local.set $end (i32.sub (global.get $out_pos) (local.get $needle_len)))
    (local.set $i (i32.const 0))
    (block $done
      (loop $scan
        (br_if $done (i32.gt_u (local.get $i) (local.get $end)))
        (local.set $ok (i32.const 1))
        (local.set $j (i32.const 0))
        (block $cmp_done
          (loop $cmp
            (br_if $cmp_done (i32.ge_u (local.get $j) (local.get $needle_len)))
            (if (i32.ne
                  (i32.load8_u (i32.add (global.get $out_base)
                                        (i32.add (local.get $i) (local.get $j))))
                  (i32.load8_u (i32.add (i32.add (local.get $needle) (i32.const 4))
                                        (local.get $j))))
              (then
                (local.set $ok (i32.const 0))
                (br $cmp_done)))
            (local.set $j (i32.add (local.get $j) (i32.const 1)))
            (br $cmp)))
        (if (local.get $ok)
          (then (local.set $count (i32.add (local.get $count) (i32.const 1)))))
        (local.set $i (i32.add (local.get $i) (i32.const 1)))
        (br $scan)))
    (local.get $count))
