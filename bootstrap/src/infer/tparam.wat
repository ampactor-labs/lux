  ;; ═══ tparam.wat — TParam + record-field-pair + Ownership (Tier 5) ═
  ;; Implements: Hβ-infer-substrate.md §2.3 (TParam payload note —
  ;;             substrate gap closure 2026-04-26) + ROADMAP §3
  ;;             scheme.wat recursion parity prerequisite + spec 02
  ;;             src/types.mn:54-63 canonical TParam + Ownership ADTs.
  ;;
  ;;             Per the ty.wat:147-165 documented gap: ty.wat treats
  ;;             TFun's params + TRecord/TRecordOpen's fields as opaque
  ;;             pending the TParam + record-field-pair substrate. This
  ;;             chunk closes that gap so scheme.wat's $free_in_ty +
  ;;             $ty_substitute can recurse to canonical parity.
  ;;
  ;; Exports:    $tparam_make / $tparam_name / $tparam_ty /
  ;;               $tparam_authored / $tparam_resolved / $is_tparam,
  ;;             $field_pair_make / $field_pair_name / $field_pair_ty /
  ;;               $is_field_pair,
  ;;             $ownership_make_inferred / $ownership_make_own /
  ;;               $ownership_make_ref,
  ;;             $is_ownership_inferred / $is_ownership_own /
  ;;               $is_ownership_ref
  ;; Uses:       $make_record / $record_get / $record_set / $tag_of
  ;;               (record.wat)
  ;; Test:       runtime_test/infer_tparam.wat (pending — first acceptance
  ;;             is $tparam_*-grep + wasm-validate per Hβ-infer §11)

  ;; ─── 202 = TParam(String, Ty, Ownership, Ownership) — arity 4 ────
  (func $tparam_make (param $name i32) (param $ty i32)
                      (param $authored i32) (param $resolved i32)
                      (result i32)
    (local $p i32)
    (local.set $p (call $make_record (i32.const 202) (i32.const 4)))
    (call $record_set (local.get $p) (i32.const 0) (local.get $name))
    (call $record_set (local.get $p) (i32.const 1) (local.get $ty))
    (call $record_set (local.get $p) (i32.const 2) (local.get $authored))
    (call $record_set (local.get $p) (i32.const 3) (local.get $resolved))
    (local.get $p))

  (func $tparam_name (param $p i32) (result i32)
    (call $record_get (local.get $p) (i32.const 0)))

  (func $tparam_ty (param $p i32) (result i32)
    (call $record_get (local.get $p) (i32.const 1)))

  (func $tparam_authored (param $p i32) (result i32)
    (call $record_get (local.get $p) (i32.const 2)))

  (func $tparam_resolved (param $p i32) (result i32)
    (call $record_get (local.get $p) (i32.const 3)))

  (func $is_tparam (param $p i32) (result i32)
    (i32.eq (call $tag_of (local.get $p)) (i32.const 202)))

  ;; ─── 203 = (String, Ty) record-field-pair — arity 2 ──────────────
  (func $field_pair_make (param $name i32) (param $ty i32) (result i32)
    (local $p i32)
    (local.set $p (call $make_record (i32.const 203) (i32.const 2)))
    (call $record_set (local.get $p) (i32.const 0) (local.get $name))
    (call $record_set (local.get $p) (i32.const 1) (local.get $ty))
    (local.get $p))

  (func $field_pair_name (param $p i32) (result i32)
    (call $record_get (local.get $p) (i32.const 0)))

  (func $field_pair_ty (param $p i32) (result i32)
    (call $record_get (local.get $p) (i32.const 1)))

  (func $is_field_pair (param $p i32) (result i32)
    (i32.eq (call $tag_of (local.get $p)) (i32.const 203)))

  ;; ─── 260-262 = Ownership (3 nullary sentinels) ───────────────────
  (func $ownership_make_inferred (result i32) (i32.const 260))
  (func $ownership_make_own      (result i32) (i32.const 261))
  (func $ownership_make_ref      (result i32) (i32.const 262))

  (func $is_ownership_inferred (param $o i32) (result i32)
    (i32.eq (call $tag_of (local.get $o)) (i32.const 260)))

  (func $is_ownership_own (param $o i32) (result i32)
    (i32.eq (call $tag_of (local.get $o)) (i32.const 261)))

  (func $is_ownership_ref (param $o i32) (result i32)
    (i32.eq (call $tag_of (local.get $o)) (i32.const 262)))
