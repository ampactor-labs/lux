  ;; ═══ emit_const_make_arms.wat — Hβ.emit.const-make-arms harness ════
  ;; Executes: Hβ-emit-substrate.md §2.1 (5-arm Const family closure —
  ;;           LMakeList tag 316 + LMakeTuple tag 317 + LMakeRecord tag 318
  ;;           + LMakeVariant tag 319) + §3.5 (EmitMemory swap surface
  ;;           via $emit_alloc bump-pattern emission) + §5.1 (eight
  ;;           interrogations at dispatcher) + §8 acceptance + §11.3.
  ;; Exercises: bootstrap/src/emit/emit_const.wat post Hβ.emit.const-make-
  ;;            arms peer landing — $emit_lmakelist, $emit_lmaketuple,
  ;;            $emit_lmakerecord, $emit_lmakevariant (nullary + fielded
  ;;            paths), $emit_lexpr partial dispatcher (recursion through
  ;;            LConst sub-elements), $emit_alloc bump-pattern emission.
  ;; Per ROADMAP §5 + Hβ-emit-substrate.md §8.1 + §11.4 acceptance.
  ;;
  ;; ─── Eight interrogations (per Hβ-emit §5.1 second pass) ──────────
  ;;   Graph?      Each phase constructs LowExpr records via $lexpr_make_*
  ;;               with handles bound to TInt via $graph_fresh_ty +
  ;;               $graph_bind. $emit_lexpr's recursion into elem/field/arg
  ;;               sub-LowExprs traverses these via $list_index +
  ;;               $tag_of dispatch. Per Anchor 1: harness asks the
  ;;               constructed LowExpr graph; emit reads it.
  ;;   Handler?    Direct calls to $emit_lmake* (seed Tier-6 base);
  ;;               @resume=OneShot at the wheel. The chunk-private
  ;;               $emit_alloc is the SUBSTRATE-LEVEL HANDLER REFERENCE
  ;;               per §3.5.1 — future arena/gc swap is one fn-body Edit.
  ;;   Verb?       Sequential per-phase setup + emit + byte-comparison.
  ;;   Row?        EmitMemory at wheel; row-silent at seed harness.
  ;;               Side-effect on $out_base/$out_pos via $emit_byte.
  ;;   Ownership?  LowExpr records OWN by harness (allocated via $alloc
  ;;               on bump heap); $out_base buffer OWNed program-wide.
  ;;               $bytes_eq_at_outbase reads i32.load8_u — ref-only.
  ;;   Refinement? None.
  ;;   Gradient?   Phase 4 (LMakeVariant nullary, tag_id=0) IS the
  ;;               gradient cash-out — proves Bool/Nothing/Up/Down/etc.
  ;;               compile to (i32.const tag_id) sentinel, NOT a heap-
  ;;               allocated record. Phase 5 (fielded, tag_id=42, 1 arg)
  ;;               proves the heap-alloc branch via $emit_alloc. Together:
  ;;               drift-6 closure proven at runtime.
  ;;   Reason?     N/A — harness verifies value round-trip; Reason chains
  ;;               on graph handles preserved upstream.
  ;;
  ;; ─── Forbidden patterns audited ───────────────────────────────────
  ;;   - Drift 1 (vtable):   $emit_lexpr direct (i32.eq tag N) dispatch
  ;;                         tested via byte-output round-trip. NO harness
  ;;                         re-encoding of tags as closure-record fields.
  ;;   - Drift 5 (C calling): single LowExpr ref per arm; no __closure/__ev.
  ;;   - Drift 6 (Bool special): Phase 4 + 5 prove LMakeVariant universal
  ;;                         (no Bool special-case path).
  ;;   - Drift 7 (parallel arrays): elems/fields/args accessed as ONE
  ;;                         list ptr per LowExpr field; no parallel-arrays.
  ;;   - Drift 8 (string-keyed): tag dispatch via integer constants;
  ;;                         harness uses $tag_of integer comparison.
  ;;   - Drift 9 (deferred): every assertion bodied; verdict explicit.
  ;;   - acc ++ [x] loop:   N/A — no list-append patterns.
  ;;   - list[i] in Snoc:   harness elems list constructed flat (tag 0)
  ;;                         via $make_list + $list_set; $list_index
  ;;                         resolves through tag.

  ;; ─── Harness-private data segments ────────────────────────────────
  ;; PASS/FAIL/sp/nl + harness name at standard offsets [3072, 3168).
  ;; Per-phase FAIL labels at [3168, 3360). Expected emission bytes at
  ;; [4096, 5500) — above HEAP_BASE 4096 (≥ HEAP_BASE so pointer-interp
  ;; safe; below bump allocator's 1 MiB start so no heap collision).
  ;; This is HARNESS-OWNED static data; production never reads here.

  (data (i32.const 3072) "\05\00\00\00PASS:")
  (data (i32.const 3084) "\05\00\00\00FAIL:")
  (data (i32.const 3096) "\01\00\00\00 ")
  (data (i32.const 3104) "\01\00\00\00\0a")

  ;; Harness display name — offset 3120 (21 chars: emit_const_make_arms)
  (data (i32.const 3120) "\15\00\00\00emit_const_make_arms ")

  ;; Per-assertion FAIL labels — offsets 3168+ (32-byte slots: 4 hdr + 28 body)
  (data (i32.const 3168) "\1c\00\00\00phase1-lmakelist-pos-bad    ")
  (data (i32.const 3200) "\1c\00\00\00phase1-lmakelist-bytes-bad  ")
  (data (i32.const 3232) "\1c\00\00\00phase2-lmaketuple-pos-bad   ")
  (data (i32.const 3264) "\1c\00\00\00phase2-lmaketuple-bytes-bad ")
  (data (i32.const 3296) "\1c\00\00\00phase3-lmakerecord-pos-bad  ")
  (data (i32.const 3328) "\1c\00\00\00phase3-lmakerecord-bytes-bad")
  (data (i32.const 3360) "\1c\00\00\00phase4-variant-null-pos-bad ")
  (data (i32.const 3392) "\1c\00\00\00phase4-variant-null-bytes   ")
  (data (i32.const 3424) "\1c\00\00\00phase5-variant-fld-pos-bad  ")
  (data (i32.const 3456) "\1c\00\00\00phase5-variant-fld-bytes-bad")

  ;; ─── Expected emission bytes per phase ────────────────────────────

  ;; Phase 1 — LMakeList([LConst(7), LConst(8)]) @ 4096 (114 bytes payload)
  (data (i32.const 4096)
    "\72\00\00\00(i32.const 2)(call $make_list)(i32.const 0)(i32.const 7)(call $list_set)(i32.const 1)(i32.const 8)(call $list_set)")

  ;; Phase 2 — LMakeTuple([LConst(7), LConst(8)]) @ 4216 (242 bytes payload)
  (data (i32.const 4216)
    "\f2\00\00\00(global.get $heap_ptr)(local.set $tuple_tmp)(global.get $heap_ptr)(i32.const 8)(i32.add)(global.set $heap_ptr)(local.get $tuple_tmp)(i32.const 7)(i32.store offset=0)(local.get $tuple_tmp)(i32.const 8)(i32.store offset=4)(local.get $tuple_tmp)")

  ;; Phase 3 — LMakeRecord([LConst(7), LConst(8)]) @ 4464 (246 bytes payload)
  (data (i32.const 4464)
    "\f6\00\00\00(global.get $heap_ptr)(local.set $record_tmp)(global.get $heap_ptr)(i32.const 8)(i32.add)(global.set $heap_ptr)(local.get $record_tmp)(i32.const 7)(i32.store offset=0)(local.get $record_tmp)(i32.const 8)(i32.store offset=4)(local.get $record_tmp)")

  ;; Phase 4 — LMakeVariant nullary tag_id=0 @ 4720 (13 bytes payload)
  ;; (Phase 3 at 4464 occupies 4+246=250 bytes through 4713; 4720 is post-end.)
  (data (i32.const 4720) "\0d\00\00\00(i32.const 0)")

  ;; Phase 5 — LMakeVariant fielded tag_id=42 args=[LConst(7)] @ 4744 (251 bytes)
  ;; (Phase 4 at 4720 occupies 4+13=17 bytes through 4736; 4744 is post-end.)
  (data (i32.const 4744)
    "\fb\00\00\00(global.get $heap_ptr)(local.set $variant_tmp)(global.get $heap_ptr)(i32.const 8)(i32.add)(global.set $heap_ptr)(local.get $variant_tmp)(i32.const 42)(i32.store offset=0)(local.get $variant_tmp)(i32.const 7)(i32.store offset=4)(local.get $variant_tmp)")

  ;; ─── _start ──────────────────────────────────────────────────────
  (func $_start (export "_start")
    (local $failed i32)
    (local $h_int_a i32) (local $h_int_b i32) (local $h_var i32)
    (local $lc7 i32) (local $lc8 i32) (local $elems2 i32) (local $args1 i32)
    (local $r_list i32) (local $r_tuple i32) (local $r_record i32)
    (local $r_var_null i32) (local $r_var_fielded i32)
    (local.set $failed (i32.const 0))

    ;; Initialize emit + graph state (idempotent).
    (call $emit_init)
    (call $graph_init)

    ;; Bind two fresh handles to TInt (so LConst sub-elements emit
    ;; via the fall-through (i32.const value) arm).
    (local.set $h_int_a (call $graph_fresh_ty (call $reason_make_fresh (i32.const 0))))
    (call $graph_bind (local.get $h_int_a)
                      (call $ty_make_tint)
                      (call $reason_make_fresh (i32.const 0)))
    (local.set $h_int_b (call $graph_fresh_ty (call $reason_make_fresh (i32.const 1))))
    (call $graph_bind (local.get $h_int_b)
                      (call $ty_make_tint)
                      (call $reason_make_fresh (i32.const 1)))
    (local.set $h_var (call $graph_fresh_ty (call $reason_make_fresh (i32.const 2))))
    (call $graph_bind (local.get $h_var)
                      (call $ty_make_tint)
                      (call $reason_make_fresh (i32.const 2)))

    ;; Build LConst(h_int_a, 7) and LConst(h_int_b, 8); reuse across phases.
    (local.set $lc7 (call $lexpr_make_lconst (local.get $h_int_a) (i32.const 7)))
    (local.set $lc8 (call $lexpr_make_lconst (local.get $h_int_b) (i32.const 8)))

    ;; Build the 2-element elems list [lc7, lc8] for LMakeList/Tuple/Record.
    (local.set $elems2 (call $make_list (i32.const 2)))
    (local.set $elems2 (call $list_extend_to (local.get $elems2) (i32.const 2)))
    (drop (call $list_set (local.get $elems2) (i32.const 0) (local.get $lc7)))
    (drop (call $list_set (local.get $elems2) (i32.const 1) (local.get $lc8)))

    ;; Build the 1-element args list [lc7] for LMakeVariant fielded.
    (local.set $args1 (call $make_list (i32.const 1)))
    (local.set $args1 (call $list_extend_to (local.get $args1) (i32.const 1)))
    (drop (call $list_set (local.get $args1) (i32.const 0) (local.get $lc7)))

    ;; ── Phase 1: LMakeList([LConst(7), LConst(8)]) ──
    (local.set $r_list
      (call $lexpr_make_lmakelist (local.get $h_var) (local.get $elems2)))
    (global.set $out_pos (i32.const 0))
    (call $emit_lmakelist (local.get $r_list))
    (if (i32.ne (global.get $out_pos) (i32.const 114))
      (then
        (call $eprint_string (i32.const 3168))
        (call $eprint_string (i32.const 3104))
        (local.set $failed (i32.const 1))))
    (if (i32.eqz (call $bytes_eq_at_outbase (i32.const 4096)))
      (then
        (call $eprint_string (i32.const 3200))
        (call $eprint_string (i32.const 3104))
        (local.set $failed (i32.const 1))))

    ;; ── Phase 2: LMakeTuple([LConst(7), LConst(8)]) ──
    (local.set $r_tuple
      (call $lexpr_make_lmaketuple (local.get $h_var) (local.get $elems2)))
    (global.set $out_pos (i32.const 0))
    (call $emit_lmaketuple (local.get $r_tuple))
    (if (i32.ne (global.get $out_pos) (i32.const 242))
      (then
        (call $eprint_string (i32.const 3232))
        (call $eprint_string (i32.const 3104))
        (local.set $failed (i32.const 1))))
    (if (i32.eqz (call $bytes_eq_at_outbase (i32.const 4216)))
      (then
        (call $eprint_string (i32.const 3264))
        (call $eprint_string (i32.const 3104))
        (local.set $failed (i32.const 1))))

    ;; ── Phase 3: LMakeRecord([LConst(7), LConst(8)]) ──
    (local.set $r_record
      (call $lexpr_make_lmakerecord (local.get $h_var) (local.get $elems2)))
    (global.set $out_pos (i32.const 0))
    (call $emit_lmakerecord (local.get $r_record))
    (if (i32.ne (global.get $out_pos) (i32.const 246))
      (then
        (call $eprint_string (i32.const 3296))
        (call $eprint_string (i32.const 3104))
        (local.set $failed (i32.const 1))))
    (if (i32.eqz (call $bytes_eq_at_outbase (i32.const 4464)))
      (then
        (call $eprint_string (i32.const 3328))
        (call $eprint_string (i32.const 3104))
        (local.set $failed (i32.const 1))))

    ;; ── Phase 4: LMakeVariant nullary (tag_id=0, args=[]) ──
    ;; HB drift-6 closure: nullary variant compiles to sentinel, no alloc.
    (local.set $r_var_null
      (call $lexpr_make_lmakevariant
        (local.get $h_var)
        (i32.const 0)
        (call $make_list (i32.const 0))))
    (global.set $out_pos (i32.const 0))
    (call $emit_lmakevariant (local.get $r_var_null))
    (if (i32.ne (global.get $out_pos) (i32.const 13))
      (then
        (call $eprint_string (i32.const 3360))
        (call $eprint_string (i32.const 3104))
        (local.set $failed (i32.const 1))))
    (if (i32.eqz (call $bytes_eq_at_outbase (i32.const 4720)))
      (then
        (call $eprint_string (i32.const 3392))
        (call $eprint_string (i32.const 3104))
        (local.set $failed (i32.const 1))))

    ;; ── Phase 5: LMakeVariant fielded (tag_id=42, args=[LConst(7)]) ──
    ;; Heap-allocated branch: alloc(4 + 4*1 = 8) + tag store + 1 field store.
    (local.set $r_var_fielded
      (call $lexpr_make_lmakevariant
        (local.get $h_var)
        (i32.const 42)
        (local.get $args1)))
    (global.set $out_pos (i32.const 0))
    (call $emit_lmakevariant (local.get $r_var_fielded))
    (if (i32.ne (global.get $out_pos) (i32.const 251))
      (then
        (call $eprint_string (i32.const 3424))
        (call $eprint_string (i32.const 3104))
        (local.set $failed (i32.const 1))))
    (if (i32.eqz (call $bytes_eq_at_outbase (i32.const 4744)))
      (then
        (call $eprint_string (i32.const 3456))
        (call $eprint_string (i32.const 3104))
        (local.set $failed (i32.const 1))))

    ;; ── Verdict ──
    (if (local.get $failed)
      (then
        (call $eprint_string (i32.const 3084))   ;; "FAIL:"
        (call $eprint_string (i32.const 3096))   ;; " "
        (call $eprint_string (i32.const 3120))   ;; "emit_const_make_arms"
        (call $eprint_string (i32.const 3104))   ;; "\n"
        (call $wasi_proc_exit (i32.const 1)))
      (else
        (call $eprint_string (i32.const 3072))   ;; "PASS:"
        (call $eprint_string (i32.const 3096))   ;; " "
        (call $eprint_string (i32.const 3120))   ;; "emit_const_make_arms"
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
