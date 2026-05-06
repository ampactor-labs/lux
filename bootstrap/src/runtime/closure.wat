  ;; ═══ closure.wat — closure record substrate (Tier 2) ══════════════
  ;; Implements: Hβ §1.3 — closure record per H1 evidence reification.
  ;;             [tag:i32][fn_index:i32][captures...][evidence_slots...]
  ;; Exports:    $make_closure, $closure_get_slot, $closure_set_slot
  ;; Uses:       $alloc (alloc.wat)
  ;; Test:       runtime_test/closure.wat
  ;;
  ;; Same allocation surface as records (record.wat) — the heap has one
  ;; story (γ crystallization #8). Closures are records with a known
  ;; field-0 tag + field-1 fn_index; subsequent slots hold captures
  ;; (lexical environment) followed by evidence (handler function-
  ;; pointers for polymorphic effect dispatch per H1).
  ;;
  ;; Handler dispatch per Hβ §1.3 + H1 evidence reification:
  ;;   - Ground site (>95% per H1):  (call $op_<name> <args>) — direct
  ;;   - Polymorphic site:           call_indirect via fn_index field
  ;;     loaded from a closure's evidence slot at compile-time-resolved
  ;;     offset.
  ;;
  ;; THERE IS NO VTABLE. The fn_index is a FIELD on the record;
  ;; evidence is a SLOT on the record; dispatch reads the field. Per
  ;; CLAUDE.md anchor "There is no vtable in Mentl" + Koka JFP 2022
  ;; evidence-passing compilation.
  ;;
  ;; cont.wat (H7 — multi-shot continuation; future Wave 2.B addition)
  ;; extends this layout with state_index + ret_slot fields per H7
  ;; §1.2; same allocation path, same dispatch pattern, additional
  ;; fields. Mentl's oracle loop (insight #11 — speculative inference
  ;; firing on every save/edit) drives high-volume multi-shot continuously
  ;; through cont.wat — that substrate is the hot path, not a minority
  ;; case.

  ;; ─── Closure Primitives ───────────────────────────────────────────
  ;; Same layout as records: [tag:i32][fn_index:i32][slots...]

  (func $make_closure (param $tag i32) (param $fn_idx i32) (param $num_slots i32) (result i32)
    (local $ptr i32)
    (local.set $ptr (call $alloc
      (i32.add (i32.const 8) (i32.mul (local.get $num_slots) (i32.const 4)))))
    (i32.store (local.get $ptr) (local.get $tag))
    (i32.store offset=4 (local.get $ptr) (local.get $fn_idx))
    (local.get $ptr))

  (func $closure_get_slot (param $ptr i32) (param $idx i32) (result i32)
    (i32.load
      (i32.add
        (i32.add (local.get $ptr) (i32.const 8))
        (i32.mul (local.get $idx) (i32.const 4)))))

  (func $closure_set_slot (param $ptr i32) (param $idx i32) (param $val i32)
    (i32.store
      (i32.add
        (i32.add (local.get $ptr) (i32.const 8))
        (i32.mul (local.get $idx) (i32.const 4)))
      (local.get $val)))
