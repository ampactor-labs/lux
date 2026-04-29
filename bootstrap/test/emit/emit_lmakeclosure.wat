  ;; ═══ emit_lmakeclosure.wat — Hβ.emit.handler-fnref-substrate harness ═
  ;; Executes: Phase D — $emit_lmakeclosure (tag 311) closure-record
  ;;           materialization per H1 evidence reification + SUBSTRATE.md
  ;;           §I third truth "abstract algebra must materialize into one
  ;;           concrete shape". Proves the closure record layout truthful:
  ;;           fn_ptr at offset 0, capture_count at offset 4, captures at
  ;;           offset 8+4*i. Handler IS state — one record, one story.
  ;; Exercises: bootstrap/src/emit/emit_handler.wat $emit_lmakeclosure,
  ;;            $ec8_emit_global_get_name_idx, $ec8_emit_local_get_state_tmp,
  ;;            $ec8_emit_cap_stores, $emit_alloc bump-pattern, $emit_lexpr
  ;;            recursion into LConst sub-elements.
  ;; Per ROADMAP §5 + Hβ-emit-substrate.md §8.1 + Phase D acceptance.
  ;;
  ;; ─── Eight interrogations (per Hβ-emit §5.1 / SUBSTRATE §I) ────────
  ;;   Graph?      Harness constructs handle h bound to TInt via
  ;;               $graph_fresh_ty + $graph_bind. $emit_lmakeclosure reads
  ;;               captures list → $emit_lexpr recurses into LConst(h,42)
  ;;               → graph lookup resolves h to TInt → (i32.const 42).
  ;;               Per Anchor 1: harness populates graph; emit reads it.
  ;;   Handler?    Direct call to $emit_lmakeclosure (seed Tier-6 base);
  ;;               @resume=OneShot at the wheel. $emit_alloc IS the
  ;;               substrate-level handler reference per §3.5.1 — future
  ;;               arena/gc swap is one fn-body Edit.
  ;;   Verb?       alloc → store fn_ptr → store nc → store cap[0] →
  ;;               result ptr. Linear verb topology; sequential WAT.
  ;;   Row?        EmitMemory side-effect on $out_base/$out_pos via
  ;;               $emit_byte. Row-silent at seed harness.
  ;;   Ownership?  LowExpr records OWN by harness (allocated via $alloc
  ;;               on bump heap); $out_base buffer OWNed program-wide.
  ;;               $bytes_eq_at_outbase reads i32.load8_u — ref-only.
  ;;   Refinement? None.
  ;;   Gradient?   This harness IS the Phase D acceptance gradient.
  ;;               Proves Third Truth — closure record IS __state;
  ;;               fn_ptr is an i32 field, NOT a vtable entry.
  ;;   Reason?     fn name "f" preserved through LowFn.name →
  ;;               $ec8_emit_global_get_name_idx → "(global.get $f_idx)"
  ;;               in output. Name identity tracks source → LIR → WAT.
  ;;
  ;; ─── Forbidden patterns audited ─────────────────────────────────────
  ;;   - Drift 1 (vtable):     buffer contains "$f_idx" — fn_ptr is a
  ;;                            FIELD at offset 0, NOT a vtable reference.
  ;;                            No $emit_arm_table, no op_table.
  ;;   - Drift 5 (C calling):  single LowExpr ref per arm; no
  ;;                            __closure/__ev split parameter pair.
  ;;   - Drift 7 (parallel):   captures is ONE list ptr field;
  ;;                            not parallel keys + counts arrays.
  ;;   - Drift 8 (string-key): tag dispatch via integer constants;
  ;;                            harness uses $tag_of integer comparison.
  ;;   - Drift 9 (deferred):   every assertion bodied; verdict explicit.

  ;; ─── Harness-private data segments ──────────────────────────────────
  ;; PASS/FAIL/sp/nl + harness name at standard offsets [3072, 3168).
  ;; Per-check FAIL labels at [3168, 3232). Expected emission bytes at
  ;; [4096, 4416). HARNESS-OWNED static data; production never reads.

  (data (i32.const 3072) "\05\00\00\00PASS:")
  (data (i32.const 3084) "\05\00\00\00FAIL:")
  (data (i32.const 3096) "\01\00\00\00 ")
  (data (i32.const 3104) "\01\00\00\00\0a")

  ;; Harness display name — "emit_lmakeclosure " (18 chars)
  (data (i32.const 3120) "\12\00\00\00emit_lmakeclosure ")

  ;; Per-assertion FAIL labels — 32-byte slots (4 hdr + 28 body)
  (data (i32.const 3168) "\1c\00\00\00closure-pos-bad             ")
  (data (i32.const 3200) "\1c\00\00\00closure-bytes-bad           ")

  ;; ─── Expected emission bytes ────────────────────────────────────────
  ;; LMakeClosure(0, LowFn("f",...), [LConst(h,42)], []) emits:
  ;;   $emit_alloc(12, 2244):
  ;;     (global.get $heap_ptr)(local.set $state_tmp)
  ;;     (global.get $heap_ptr)(i32.const 12)(i32.add)(global.set $heap_ptr)
  ;;   fn_ptr store:
  ;;     (local.get $state_tmp)(global.get $f_idx)(i32.store offset=0)
  ;;   capture_count store (nc=1, the evidence fence):
  ;;     (local.get $state_tmp)(i32.const 1)(i32.store offset=4)
  ;;   cap[0] store (LConst(h,42) → (i32.const 42) via TInt dispatch):
  ;;     (local.get $state_tmp)(i32.const 42)(i32.store offset=8)
  ;;   result ptr:
  ;;     (local.get $state_tmp)
  ;;
  ;; 305 bytes = 0x131 → LE length prefix \31\01\00\00
  (data (i32.const 4096)
    "\31\01\00\00(global.get $heap_ptr)(local.set $state_tmp)(global.get $heap_ptr)(i32.const 12)(i32.add)(global.set $heap_ptr)(local.get $state_tmp)(global.get $f_idx)(i32.store offset=0)(local.get $state_tmp)(i32.const 1)(i32.store offset=4)(local.get $state_tmp)(i32.const 42)(i32.store offset=8)(local.get $state_tmp)")

  ;; ─── _start ─────────────────────────────────────────────────────────
  (func $_start (export "_start")
    (local $failed i32)
    (local $fn_name i32) (local $fn_r i32)
    (local $h i32) (local $cap i32)
    (local $caps i32) (local $evs i32) (local $r i32)
    (local.set $failed (i32.const 0))

    ;; Initialize emit + graph state (idempotent).
    (call $emit_init)
    (call $graph_init)

    ;; Build fn_name = "f" via $str_alloc — length-prefixed string on heap.
    (local.set $fn_name (call $str_alloc (i32.const 1)))
    (i32.store8 offset=4 (local.get $fn_name) (i32.const 102)) ;; 'f'

    ;; Build LowFn("f", 0, [], [], 0) — minimal fn, Pure row.
    (local.set $fn_r (call $lowfn_make
      (local.get $fn_name)
      (i32.const 0)
      (call $make_list (i32.const 0))
      (call $make_list (i32.const 0))
      (i32.const 0)))

    ;; Build capture: LConst(h, 42) where h is bound to TInt.
    ;; Graph interrogation: h → TInt means $emit_lexpr dispatches to
    ;; the (i32.const value) arm — the truthful path.
    (local.set $h (call $graph_fresh_ty (call $reason_make_fresh (i32.const 0))))
    (call $graph_bind (local.get $h)
                      (call $ty_make_tint)
                      (call $reason_make_fresh (i32.const 0)))
    (local.set $cap (call $lexpr_make_lconst (local.get $h) (i32.const 42)))

    ;; caps = [cap], evs = [].
    (local.set $caps (call $make_list (i32.const 1)))
    (local.set $caps (call $list_extend_to (local.get $caps) (i32.const 1)))
    (drop (call $list_set (local.get $caps) (i32.const 0) (local.get $cap)))
    (local.set $evs (call $make_list (i32.const 0)))

    ;; Build LMakeClosure(0, fn_r, [LConst(h,42)], []).
    ;; This IS the Third Truth materialized: abstract algebra → one record.
    (local.set $r (call $lexpr_make_lmakeclosure
      (i32.const 0)
      (local.get $fn_r)
      (local.get $caps)
      (local.get $evs)))

    ;; Reset output position and emit.
    (global.set $out_pos (i32.const 0))
    (call $emit_lmakeclosure (local.get $r))

    ;; ── Check 1: Length — $out_pos must equal 305 ──
    (if (i32.ne (global.get $out_pos) (i32.const 305))
      (then
        (call $eprint_string (i32.const 3168))
        (call $eprint_string (i32.const 3104))
        (local.set $failed (i32.const 1))))

    ;; ── Check 2: Exact byte match against expected ──
    (if (i32.eqz (call $bytes_eq_at_outbase (i32.const 4096)))
      (then
        (call $eprint_string (i32.const 3200))
        (call $eprint_string (i32.const 3104))
        (local.set $failed (i32.const 1))))

    ;; ── Verdict ──
    (if (local.get $failed)
      (then
        (call $eprint_string (i32.const 3084))   ;; "FAIL:"
        (call $eprint_string (i32.const 3096))   ;; " "
        (call $eprint_string (i32.const 3120))   ;; "emit_lmakeclosure "
        (call $eprint_string (i32.const 3104))   ;; "\n"
        (call $wasi_proc_exit (i32.const 1)))
      (else
        (call $eprint_string (i32.const 3072))   ;; "PASS:"
        (call $eprint_string (i32.const 3096))   ;; " "
        (call $eprint_string (i32.const 3120))   ;; "emit_lmakeclosure "
        (call $eprint_string (i32.const 3104))   ;; "\n"
        (call $wasi_proc_exit (i32.const 0)))))

  ;; ─── $bytes_eq_at_outbase — compare $out_pos bytes at $out_base
  ;;     against expected length-prefixed string at $expected.
  ;; Returns 1 if length matches AND every byte matches; 0 otherwise.
  (func $bytes_eq_at_outbase (param $expected i32) (result i32)
    (local $expected_len i32) (local $i i32)
    (local $exp_byte i32) (local $out_byte i32)
    (local.set $expected_len (i32.load (local.get $expected)))
    (if (i32.ne (local.get $expected_len) (global.get $out_pos))
      (then (return (i32.const 0))))
    (local.set $i (i32.const 0))
    (block $done
      (loop $cmp
        (br_if $done (i32.ge_u (local.get $i) (local.get $expected_len)))
        (local.set $exp_byte
          (i32.load8_u
            (i32.add (i32.add (local.get $expected) (i32.const 4))
                     (local.get $i))))
        (local.set $out_byte
          (i32.load8_u
            (i32.add (global.get $out_base) (local.get $i))))
        (if (i32.ne (local.get $exp_byte) (local.get $out_byte))
          (then (return (i32.const 0))))
        (local.set $i (i32.add (local.get $i) (i32.const 1)))
        (br $cmp)))
    (i32.const 1))
