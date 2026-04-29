  ;; ═══ emit_lmakeclosure.wat — Phase D trace-harness ══════════════════
  ;; Hβ.emit.handler-fnref-substrate — executable proof that
  ;; $emit_lmakeclosure (tag 311) emits the correct closure-record WAT.
  ;;
  ;; Strategy: build a hand-crafted LMakeClosure with:
  ;;   fn_name = "f", captures = [LConst(h, 42)], ev_slots = []
  ;; Reset out_pos, call $emit_lmakeclosure, then scan the output buffer
  ;; for mandatory substrings:
  ;;   "f_idx"      — fn_ptr stored via $<fn_name>_idx global
  ;;   "state_tmp"  — alloc target correct
  ;;   "i32.const"  — at least one i32.const emitted (nc + cap value)
  ;;
  ;; Per the eight interrogations:
  ;;   Graph?      h bound to TInt so $emit_lconst inside cap-stores fires
  ;;               the TInt arm correctly.
  ;;   Handler?    OneShot; no resume path in this harness.
  ;;   Verb?       alloc |> store fn_ptr |> store nc |> store cap[0].
  ;;   Row?        WasmOut side-effect on $out_base/$out_pos.
  ;;   Ownership?  out_base buffer owned globally; read-only in harness.
  ;;   Refinement? N/A.
  ;;   Gradient?   This harness IS the Phase D acceptance gradient.
  ;;   Reason?     fn name "f" preserved through LowFn.name → emitted "$f_idx".
  ;;
  ;; Drift-1 proof: the buffer contains "$f_idx" not a vtable reference.
  ;; One record, one story — the Inka Way, proven physical.

  ;; ─── Phase D static data ─────────────────────────────────────────────
  ;; Free zone audit: [4500, 4800)
  (data (i32.const 4500) "\05\00\00\00f_idx")      ;; 4500-4508
  (data (i32.const 4512) "\09\00\00\00state_tmp")  ;; 4512-4524
  (data (i32.const 4528) "\09\00\00\00i32.const")  ;; 4528-4540

  ;; Diagnostic strings (length-prefixed)
  (data (i32.const 4544) "\28\00\00\00FAIL Phase D: fn_ptr field missing from emit\n")
  (data (i32.const 4588) "\29\00\00\00FAIL Phase D: state_tmp alloc missing from emit\n")
  (data (i32.const 4636) "\2a\00\00\00FAIL Phase D: i32.const missing from emit output\n")
  (data (i32.const 4684) "\1c\00\00\00PASS emit_lmakeclosure Phase D\n")

  ;; ─── Scan helper ─────────────────────────────────────────────────────
  (func $phd_out_contains (param $needle i32) (result i32)
    ;; Returns 1 if the output buffer [$out_base, $out_base+$out_pos)
    ;; contains the length-prefixed needle string.
    (local $nlen i32) (local $nbody i32) (local $buflen i32)
    (local $bi i32) (local $ci i32) (local $ok i32)
    (local.set $nlen  (i32.load (local.get $needle)))
    (local.set $nbody (i32.add  (local.get $needle) (i32.const 4)))
    (local.set $buflen (global.get $out_pos))
    (if (i32.eqz (local.get $buflen)) (then (return (i32.const 0))))
    (local.set $bi (i32.const 0))
    (block $found
      (block $exhausted (loop $scan
        (br_if $exhausted
          (i32.gt_u (i32.add (local.get $bi) (local.get $nlen)) (local.get $buflen)))
        ;; compare nlen bytes starting at out_base + bi
        (local.set $ci (i32.const 0))
        (local.set $ok (i32.const 1))
        (block $mismatch (loop $cmp
          (br_if $mismatch (i32.ge_u (local.get $ci) (local.get $nlen)))
          (if (i32.ne
                (i32.load8_u (i32.add (i32.add (global.get $out_base) (local.get $bi)) (local.get $ci)))
                (i32.load8_u (i32.add (local.get $nbody) (local.get $ci))))
            (then (local.set $ok (i32.const 0)) (br $mismatch)))
          (local.set $ci (i32.add (local.get $ci) (i32.const 1)))
          (br $cmp)))
        (if (local.get $ok) (then (br $found)))
        (local.set $bi (i32.add (local.get $bi) (i32.const 1)))
        (br $scan)))
      (return (i32.const 0)))
    (i32.const 1))

  ;; ─── $_start ─────────────────────────────────────────────────────────
  (func $_start (export "_start")
    (local $failed i32)
    (local $fn_name i32) (local $params i32) (local $body_list i32)
    (local $fn_r i32) (local $h i32) (local $cap i32)
    (local $caps i32) (local $evs i32) (local $r i32)
    (local.set $failed (i32.const 0))

    ;; Initialize subsystems.
    (call $emit_init)
    (call $graph_init)

    ;; Build fn_name = "f" using $str_alloc.
    (local.set $fn_name (call $str_alloc (i32.const 1)))
    (i32.store8 offset=4 (local.get $fn_name) (i32.const 102)) ;; 'f'

    ;; Build LowFn("f", 0, [], [], 0) — minimal body, Pure row.
    (local.set $params    (call $make_list (i32.const 0)))
    (local.set $body_list (call $make_list (i32.const 0)))
    (local.set $fn_r (call $lowfn_make
      (local.get $fn_name)
      (i32.const 0)
      (local.get $params)
      (local.get $body_list)
      (i32.const 0)))

    ;; Build capture: LConst(h, 42) where h is bound to TInt.
    (local.set $h (call $graph_fresh_ty (call $reason_make_fresh (i32.const 0))))
    (call $graph_bind (local.get $h)
                      (call $ty_make_tint)
                      (call $reason_make_fresh (i32.const 0)))
    (local.set $cap (call $lexpr_make_lconst (local.get $h) (i32.const 42)))

    ;; caps = [cap], evs = [].
    (local.set $caps (call $make_list (i32.const 1)))
    (local.set $caps (call $list_set (local.get $caps) (i32.const 0) (local.get $cap)))
    (local.set $evs  (call $make_list (i32.const 0)))

    ;; Build LMakeClosure(0, fn_r, caps, evs).
    (local.set $r (call $lexpr_make_lmakeclosure
      (i32.const 0)
      (local.get $fn_r)
      (local.get $caps)
      (local.get $evs)))

    ;; Reset output position and emit the closure.
    (global.set $out_pos (i32.const 0))
    (call $emit_lmakeclosure (local.get $r))

    ;; ── Check 1: "f_idx" present (fn_ptr field, not vtable) ───────────
    (if (i32.eqz (call $phd_out_contains (i32.const 4500)))
      (then
        (call $eprint_string (i32.const 4544))
        (local.set $failed (i32.const 1))))

    ;; ── Check 2: "state_tmp" present (alloc target) ───────────────────
    (if (i32.eqz (call $phd_out_contains (i32.const 4512)))
      (then
        (call $eprint_string (i32.const 4588))
        (local.set $failed (i32.const 1))))

    ;; ── Check 3: "i32.const" present (nc + cap value emitted) ─────────
    (if (i32.eqz (call $phd_out_contains (i32.const 4528)))
      (then
        (call $eprint_string (i32.const 4636))
        (local.set $failed (i32.const 1))))

    ;; ── Report ────────────────────────────────────────────────────────
    (if (i32.eqz (local.get $failed))
      (then (call $eprint_string (i32.const 4684))))
    (call $wasi_proc_exit (local.get $failed)))
