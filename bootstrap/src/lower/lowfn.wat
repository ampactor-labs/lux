  ;; ═══ lowfn.wat — LowFn record substrate (Tier 4) ═══════════════════
  ;; Hβ.lower Phase C.1 — LowFn ADT record at the WAT layer.
  ;; Per src/lower.nx canonical: `LFn(name, arity, params, body, row)`.
  ;; The lowering walk's fn-declaration product type. Each LowFn carries
  ;; its source name (String), static arity (Int), parameter name list,
  ;; lowered body (LowExpr), and effect row handle — the row IS the
  ;; first-class effect-tracking field that Mentl's Why Engine walks.
  ;;
  ;; Implements: Hβ-lower-substrate.md §11 named follow-up
  ;;             `Hβ.lower.lvalue-lowfn-lpat-substrate` (LowFn half);
  ;;             deep-toasting-bachman.md Phase C.1.
  ;; Exports:    $lowfn_make, $lowfn_name, $lowfn_arity, $lowfn_params,
  ;;             $lowfn_body, $lowfn_row
  ;; Uses:       $make_record / $record_get / $record_set (record.wat)
  ;; Test:       bootstrap/test/lower/lowfn_smoke.wat
  ;;
  ;; ─── TAG REGION ────────────────────────────────────────────────────
  ;;
  ;; Tag 350 in the LowFn-private region (350-359 reserved).
  ;; Extends lexpr.wat tag-uniqueness map:
  ;;   300-334    LowExpr variants (lexpr.wat)
  ;;   335-349    reserved future LowExpr
  ;;   350        LowFn (this chunk)
  ;;   351-359    reserved future LowFn
  ;;   360-369    LowPat variants (lowpat.wat — Phase C.2 peer)
  ;;
  ;; ─── EIGHT INTERROGATIONS ──────────────────────────────────────────
  ;;
  ;; 1. Graph?      LowFn carries fn's source handle in body's
  ;;                LReturn; row is graph-read via $lookup_ty.
  ;; 2. Handler?    LDeclareFn handler-arm-as-fn projection; emit's
  ;;                LMakeClosure/LMakeContinuation arms read LowFn.
  ;;                @resume=N/A (LowFn is a record, not a handler op).
  ;; 3. Verb?       `|>` lowering produces LDeclareFn(LowFn(...)).
  ;; 4. Row?        LowFn carries the fn's effect row directly per
  ;;                src/lower.nx:109 `LMakeClosure(Int, LowFn, ...)`.
  ;; 5. Ownership?  `own` LowFn — passed-through-once into
  ;;                LMakeClosure/LMakeContinuation/LDeclareFn.
  ;; 6. Refinement? N/A at record level.
  ;; 7. Gradient?   classify_handler reads `$lowfn_row` to drive
  ;;                TailResumptive/Linear/MultiShot strategy.
  ;; 8. Reason?     Source FnStmt's Reason chain unchanged; LowFn
  ;;                does not add its own Reason.
  ;;
  ;; ─── FORBIDDEN PATTERNS ────────────────────────────────────────────
  ;;
  ;; - Drift 1:    No $lowfn_dispatch_table. One tag, one record shape.
  ;; - Drift 5:    No threaded `__ctx` param. Five fields, all explicit.
  ;; - Drift 6:    No special-case for "main" or nullary fns.
  ;; - Drift 7:    Single record. No parallel arrays.
  ;; - Drift 8:    Tag-int 350, not string "LowFn".
  ;; - Drift 9:    All five fields land. No "row later" deferral.
  ;;
  ;; ─── SURPASS ───────────────────────────────────────────────────────
  ;;
  ;; LowFn carrying `row` AS A FIRST-CLASS FIELD surpasses:
  ;;   - LLVM Function: no graph, no Reason, no compile-time arity check
  ;;   - GHC Core Lambda: effect tracking via type but not on IR record
  ;;   - OCaml Lambda: effects in 5.0 but not first-class on IR
  ;;   - Rust MIR: no refinement, no Reasons
  ;; The row field IS the seed for what refinement types discharge at
  ;; compile time and what the Why Engine walks back through.

  ;; ─── 350 = LowFn(name, arity, params, body, row) — arity 5 ────────
  ;; Per src/lower.nx canonical LFn record shape.
  ;;   field_0 = name (String — fn name for WAT $-prefix)
  ;;   field_1 = arity (i32 — static param count)
  ;;   field_2 = params (List of String — parameter names)
  ;;   field_3 = body (LowExpr — lowered fn body)
  ;;   field_4 = row (i32 — effect row handle; graph-read via $lookup_ty)
  (func $lowfn_make (export "lowfn_make")
        (param $name i32) (param $arity i32) (param $params i32)
        (param $body i32) (param $row i32)
        (result i32)
    (local $r i32)
    (local.set $r (call $make_record (i32.const 350) (i32.const 5)))
    (call $record_set (local.get $r) (i32.const 0) (local.get $name))
    (call $record_set (local.get $r) (i32.const 1) (local.get $arity))
    (call $record_set (local.get $r) (i32.const 2) (local.get $params))
    (call $record_set (local.get $r) (i32.const 3) (local.get $body))
    (call $record_set (local.get $r) (i32.const 4) (local.get $row))
    (local.get $r))

  (func $lowfn_name (export "lowfn_name") (param $r i32) (result i32)
    (call $record_get (local.get $r) (i32.const 0)))

  (func $lowfn_arity (export "lowfn_arity") (param $r i32) (result i32)
    (call $record_get (local.get $r) (i32.const 1)))

  (func $lowfn_params (export "lowfn_params") (param $r i32) (result i32)
    (call $record_get (local.get $r) (i32.const 2)))

  (func $lowfn_body (export "lowfn_body") (param $r i32) (result i32)
    (call $record_get (local.get $r) (i32.const 3)))

  (func $lowfn_row (export "lowfn_row") (param $r i32) (result i32)
    (call $record_get (local.get $r) (i32.const 4)))
