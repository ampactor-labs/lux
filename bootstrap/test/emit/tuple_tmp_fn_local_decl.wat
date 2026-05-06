  ;; ═══ tuple_tmp_fn_local_decl.wat ═══════════════════════════════════
  ;; Hβ.first-light.tuple-tmp-fn-local-decl harness.
  ;; Per docs/specs/simulations/Hβ-first-light.tuple-tmp-fn-local-decl.md
  ;; §F + §10 (E.1 acceptance gate).
  ;;
  ;; Constructs a hand-authored LowFn whose body is:
  ;;   LMakeTuple(handle, [LConst(handle, 1), LConst(handle, 2)])
  ;; Calls $emit_fn_body. Scans output for "(local $tuple_tmp i32)"
  ;; exactly once in the function preamble. Exits 0 on PASS, 1 on FAIL.
  ;;
  ;; Pre-fix behavior: $emit_standard_locals didn't declare $tuple_tmp;
  ;; (local.set $tuple_tmp)/(local.get $tuple_tmp) appeared in body
  ;; from $emit_lmaketuple via $emit_alloc; wat2wasm rejected with
  ;; "undefined local variable $tuple_tmp".
  ;; Post-fix: $emit_standard_locals declares $tuple_tmp alongside
  ;; $variant_tmp and $record_tmp; preamble contains exactly one
  ;; (local $tuple_tmp i32).
  ;;
  ;; ─── Eight interrogations ───────────────────────────────────────────
  ;;   Graph?      Harness allocates handle h via $graph_fresh_ty +
  ;;               $graph_bind to TInt; LMakeTuple constructed with two
  ;;               LConst sub-elements via $lexpr_make_lmaketuple.
  ;;   Handler?    Direct call to $emit_fn_body — the preamble handler
  ;;               under test.
  ;;   Verb?       N/A — direct emission test.
  ;;   Row?        EmitMemory (writes to $out_base via $emit_str /
  ;;               $emit_cstr inside $emit_local_decl_str).
  ;;   Ownership?  LowExpr / LowFn records owned by harness.
  ;;   Refinement? String at offset 1536 length-prefixed; declaration
  ;;               via $emit_local_decl_str honors that contract.
  ;;   Gradient?   Compile-time unconditional preamble-decl; future
  ;;               LowFn-carries-local-decl-set is named follow-up.
  ;;   Reason?     Not exercised here.
  ;;
  ;; ─── Forbidden patterns audited ─────────────────────────────────────
  ;;   - Drift 1 (vtable):      No dispatch table; direct call.
  ;;   - Drift 6 (special):     tuple_tmp walks same path as record_tmp,
  ;;                            variant_tmp.
  ;;   - Drift 7 (parallel):    No name-accumulator; substring scan.
  ;;   - Drift 8 (string-key):  Pointer is i32 constant; static-data
  ;;                            length-prefixed string.
  ;;   - Drift 9 (deferred):    Test exercises 2-elem LMakeTuple; the
  ;;                            walkthrough §3 lock #5 covers all
  ;;                            $emit_alloc-target scratch-locals.

  ;; ─── Harness-private data segments ──────────────────────────────────
  (data (i32.const 3072) "\05\00\00\00PASS:")
  (data (i32.const 3084) "\05\00\00\00FAIL:")
  (data (i32.const 3096) "\01\00\00\00 ")
  (data (i32.const 3104) "\01\00\00\00\0a")

  ;; Harness display name — "tuple_tmp_fn_local_decl " (24 chars)
  (data (i32.const 3120) "\18\00\00\00tuple_tmp_fn_local_decl ")

  ;; Per-assertion FAIL labels — 32-byte slots
  (data (i32.const 3168) "\1c\00\00\00local-tuple-tmp-missing     ")
  (data (i32.const 3200) "\1c\00\00\00local-tuple-tmp-duplicated  ")

  ;; "pair" — fn name (4 bytes)
  (data (i32.const 3328) "\04\00\00\00pair")

  ;; Substring "(local $tuple_tmp i32)" — 22 bytes — to scan for in output
  (data (i32.const 3392) "\16\00\00\00(local $tuple_tmp i32)")

  ;; ─── _start ─────────────────────────────────────────────────────────
  (func $_start (export "_start")
    (local $failed i32)
    (local $h i32)
    (local $params i32)
    (local $elems i32)
    (local $lc1 i32) (local $lc2 i32)
    (local $tuple_expr i32)
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

    ;; ─── Build params [] (arity 0 — `fn pair() = ...`) ─────────────────
    (local.set $params (call $make_list (i32.const 0)))

    ;; ─── Build elems = [LConst(h, 1), LConst(h, 2)] ───────────────────
    (local.set $lc1 (call $lexpr_make_lconst (local.get $h) (i32.const 1)))
    (local.set $lc2 (call $lexpr_make_lconst (local.get $h) (i32.const 2)))
    (local.set $elems (call $make_list (i32.const 2)))
    (local.set $elems (call $list_extend_to (local.get $elems) (i32.const 2)))
    (drop (call $list_set (local.get $elems) (i32.const 0) (local.get $lc1)))
    (drop (call $list_set (local.get $elems) (i32.const 1) (local.get $lc2)))

    ;; ─── Build LMakeTuple(h, elems) ───────────────────────────────────
    (local.set $tuple_expr (call $lexpr_make_lmaketuple (local.get $h) (local.get $elems)))

    ;; ─── body = [tuple_expr] (LowExpr list) ───────────────────────────
    (local.set $body_list (call $make_list (i32.const 1)))
    (local.set $body_list (call $list_extend_to (local.get $body_list) (i32.const 1)))
    (drop (call $list_set (local.get $body_list) (i32.const 0) (local.get $tuple_expr)))

    ;; ─── Build LowFn("pair", 0, [], body, 0) ──────────────────────────
    (local.set $fn_r (call $lowfn_make
      (i32.const 3328)             ;; name "pair"
      (i32.const 0)                ;; arity
      (local.get $params)
      (local.get $body_list)
      (i32.const 0)))              ;; row (unused in this test)

    ;; Reset and emit.
    (global.set $out_pos (i32.const 0))
    (call $emit_fn_body (local.get $fn_r))

    ;; ── Check 1: "(local $tuple_tmp i32)" appears at least once ──
    (local.set $count (call $count_substr (i32.const 3392)))
    (if (i32.eqz (local.get $count))
      (then
        (call $eprint_string (i32.const 3168))
        (call $eprint_string (i32.const 3104))
        (local.set $failed (i32.const 1))))

    ;; ── Check 2: "(local $tuple_tmp i32)" appears EXACTLY once ──
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
  ;; Verbatim copy from match_arm_pat_binding_local_decl.wat — three
  ;; harnesses now use this scan helper (this one + match_arm_pat_binding +
  ;; the existing emit_const_make_arms phase-comparisons would benefit
  ;; from it too); third instance earns the abstraction per Anchor 7 +
  ;; named follow-up Hβ.test.count_substr-promote (planner cycle named
  ;; in this walkthrough's §9 if surfaces).
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
