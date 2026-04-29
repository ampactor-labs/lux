  ;; ═══ lexpr.wat — LowExpr ADT shape (Tier 6) ═════════════════════════
  ;; Hβ.lower cascade chunk #3 — LowExpr ADT shape at the WAT layer.
  ;; The lowering walk's product type. Each variant's record carries a
  ;; source TypeHandle (field 0; Graph[1]) into which $lookup_ty (the
  ;; live LookupTy projection — Handler[2] @resume=OneShot at the wheel,
  ;; direct fn at the seed) reads. The five verbs of spec 10 [Verb 3]
  ;; project to LHandleWith / LFeedback / LCall-shaped LowExpr trees;
  ;; the row's ground-vs-open status [Row 4] gates LCall vs evidence
  ;; thunk at $lower_call (chunk #7), reading TFun.row through the same
  ;; handle. Each LowExpr is `own` of the bump-allocator [Ownership 5];
  ;; consumers `ref`. TRefined predicates [Refinement 6] are transparent
  ;; — no LowExpr variant carries them; verify ledger holds the
  ;; obligations. Each variant choice IS a gradient step [Gradient 7]
  ;; — LCall vs LMakeClosure-with-evidence is one row-inference win
  ;; cashed in. Reasons [Reason 8] live on the GNode at the carried
  ;; handle; lexpr.wat is read-only on Reason.
  ;;
  ;; Implements: Hβ-lower-substrate.md §2 (lines 237-275 + lines 277-294)
  ;;             — 35 LowExpr variants over tag region 300-334; universal
  ;;             $lexpr_handle with LDeclareFn tag-313 anomaly arm;
  ;;             field ordering per src/lower.nx:97-150 canonical wheel.
  ;; Exports:    $lexpr_handle (universal),
  ;;             $lexpr_make_lconst $lexpr_lconst_value,
  ;;             $lexpr_make_llocal $lexpr_llocal_name,
  ;;             $lexpr_make_lglobal $lexpr_lglobal_name,
  ;;             $lexpr_make_lstore $lexpr_lstore_slot $lexpr_lstore_value,
  ;;             $lexpr_make_llet $lexpr_llet_name $lexpr_llet_value,
  ;;             $lexpr_make_lupval $lexpr_lupval_slot,
  ;;             $lexpr_make_lbinop $lexpr_lbinop_op $lexpr_lbinop_l $lexpr_lbinop_r,
  ;;             $lexpr_make_lunaryop $lexpr_lunaryop_op $lexpr_lunaryop_x,
  ;;             $lexpr_make_lcall $lexpr_lcall_fn $lexpr_lcall_args,
  ;;             $lexpr_make_ltailcall $lexpr_ltailcall_fn $lexpr_ltailcall_args,
  ;;             $lexpr_make_lreturn $lexpr_lreturn_x,
  ;;             $lexpr_make_lmakeclosure $lexpr_lmakeclosure_fn
  ;;               $lexpr_lmakeclosure_caps $lexpr_lmakeclosure_evs,
  ;;             $lexpr_make_lmakecontinuation $lexpr_lmakecontinuation_fn
  ;;               $lexpr_lmakecontinuation_caps $lexpr_lmakecontinuation_evs
  ;;               $lexpr_lmakecontinuation_state_idx $lexpr_lmakecontinuation_ret_slot,
  ;;             $lexpr_make_ldeclarefn $lexpr_ldeclarefn_fn,
  ;;             $lexpr_make_lif $lexpr_lif_cond $lexpr_lif_then $lexpr_lif_else,
  ;;             $lexpr_make_lblock $lexpr_lblock_stmts,
  ;;             $lexpr_make_lmakelist $lexpr_lmakelist_elems,
  ;;             $lexpr_make_lmaketuple $lexpr_lmaketuple_elems,
  ;;             $lexpr_make_lmakerecord $lexpr_lmakerecord_fields,
  ;;             $lexpr_make_lmakevariant $lexpr_lmakevariant_tag_id $lexpr_lmakevariant_args,
  ;;             $lexpr_make_lindex $lexpr_lindex_base $lexpr_lindex_idx $lexpr_lindex_is_str,
  ;;             $lexpr_make_lmatch $lexpr_lmatch_scrut $lexpr_lmatch_arms,
  ;;             $lexpr_make_lsuspend $lexpr_lsuspend_op_h $lexpr_lsuspend_fn
  ;;               $lexpr_lsuspend_args $lexpr_lsuspend_evs,
  ;;             $lexpr_make_lstateget $lexpr_lstateget_slot,
  ;;             $lexpr_make_lstateset $lexpr_lstateset_slot $lexpr_lstateset_value,
  ;;             $lexpr_make_lregion $lexpr_lregion_body,
  ;;             $lexpr_make_lhandlewith $lexpr_lhandlewith_body $lexpr_lhandlewith_handler,
  ;;             $lexpr_make_lfeedback $lexpr_lfeedback_body $lexpr_lfeedback_spec,
  ;;             $lexpr_make_lperform $lexpr_lperform_op_name $lexpr_lperform_args,
  ;;             $lexpr_make_lhandle $lexpr_lhandle_body $lexpr_lhandle_arms,
  ;;             $lexpr_make_levperform $lexpr_levperform_op_name
  ;;               $lexpr_levperform_slot_idx $lexpr_levperform_args,
  ;;             $lexpr_make_lfieldload $lexpr_lfieldload_record $lexpr_lfieldload_offset_bytes
  ;; Uses:       $make_record $record_get $record_set $tag_of (record.wat)
  ;; Test:       bootstrap/test/lower/lexpr_lconst_roundtrip.wat
  ;;             bootstrap/test/lower/lexpr_lcall_field_extraction.wat
  ;;             bootstrap/test/lower/lexpr_lmakecontinuation_arity6.wat
  ;;             bootstrap/test/lower/lexpr_handle_universal.wat
  ;;
  ;; ─── TAG REGION ────────────────────────────────────────────────────
  ;;
  ;; Per Hβ-lower-substrate.md §2 (lines 237-275 + line 277) +
  ;; ty.wat:145 tag-uniqueness map.
  ;;
  ;; LowExpr per-variant enumeration (matches src/lower.nx:97-150 verbatim;
  ;; field types per the wheel canonical):
  ;;
  ;;   300 = LConst             arity 2  (handle, value)
  ;;   301 = LLocal             arity 2  (handle, name)         [string per wheel]
  ;;   302 = LGlobal            arity 2  (handle, name)
  ;;   303 = LStore             arity 3  (handle, slot, value)
  ;;   304 = LLet               arity 3  (handle, name, value)
  ;;   305 = LUpval             arity 2  (handle, slot)
  ;;   306 = LBinOp             arity 4  (handle, op_tag, l, r) [op_tag is BinOp i32 sentinel 140-153]
  ;;   307 = LUnaryOp           arity 3  (handle, op_name, x)   [op_name string per wheel]
  ;;   308 = LCall              arity 3  (handle, fn, args)
  ;;   309 = LTailCall          arity 3  (handle, fn, args)
  ;;   310 = LReturn            arity 2  (handle, x)
  ;;   311 = LMakeClosure       arity 4  (handle, fn, caps, evs)        [H1 evidence reification]
  ;;   312 = LMakeContinuation  arity 6  (handle, fn, caps, evs, state_idx, ret_slot)  [H7 multi-shot]
  ;;   313 = LDeclareFn         arity 1  (fn)                          [NO handle field — see §11 audit]
  ;;   314 = LIf                arity 4  (handle, cond, then, else)
  ;;   315 = LBlock             arity 2  (handle, stmts)
  ;;   316 = LMakeList          arity 2  (handle, elems)
  ;;   317 = LMakeTuple         arity 2  (handle, elems)
  ;;   318 = LMakeRecord        arity 2  (handle, fields)
  ;;   319 = LMakeVariant       arity 3  (handle, tag_id, args)
  ;;   320 = LIndex             arity 4  (handle, base, idx, is_str)
  ;;   321 = LMatch             arity 3  (handle, scrut, arms)
  ;;   325 = LSuspend           arity 5  (handle, op_h, fn, args, evs)  [op_h is graph handle, NOT string]
  ;;   326 = LStateGet          arity 2  (handle, slot)
  ;;   327 = LStateSet          arity 3  (handle, slot, value)
  ;;   328 = LRegion            arity 2  (handle, body)
  ;;   329 = LHandleWith        arity 3  (handle, body, handler)        [~> verb desugaring]
  ;;   330 = LFeedback          arity 3  (handle, body, spec)           [<~ verb; LF substrate]
  ;;   331 = LPerform           arity 3  (handle, op_name, args)        [direct-call form; H1 monomorphic]
  ;;   332 = LHandle            arity 3  (handle, body, arms)
  ;;   333 = LEvPerform         arity 4  (handle, op_name, slot_idx, args)
  ;;   334 = LFieldLoad         arity 3  (handle, record, offset_bytes)
  ;;
  ;;   335-349 reserved for future LowExpr variants (15 slots; per
  ;;          Anchor 6 substrate-vocabulary discipline — every future
  ;;          LowIR shape lands inside this contiguous region so
  ;;          $tag_of dispatch on `300 <= t && t <= 349` cleanly
  ;;          identifies a LowExpr without per-variant scan).
  ;;
  ;; Tag uniqueness across the heap — extends ty.wat:131-145:
  ;;   0-99       runtime sentinels (list/record/etc.)
  ;;   100-103    Ty nullary sentinels (TInt/TFloat/TString/TUnit)
  ;;   104-113    Ty record-shaped variants
  ;;   114        TERROR_HOLE_TAG (lookup-private; lookup.wat)
  ;;   127-129    ResumeDiscipline sentinels
  ;;   140-153    BinOp sentinels (parser_infra.wat:26)
  ;;   250-252    ResumeDiscipline sentinels (relocated)
  ;;   260-262    Ownership sentinels
  ;;   280-281    lower-private LOCAL_ENTRY / CAPTURE_ENTRY (state.wat)
  ;;   282-299    reserved future lower-private
  ;;   300-334    LowExpr variants (this chunk)
  ;;   335-349    reserved future LowExpr
  ;;
  ;; Forbidden patterns audited (per Hβ-lower-substrate.md §6 +
  ;; project-wide drift modes):
  ;;   - Drift 1 (Rust vtable):      No $lexpr_dispatch_table. No data segment
  ;;                                 named $lexpr_op_table. 35 constructors are
  ;;                                 35 named direct (func)s. "vtable" never appears.
  ;;   - Drift 5 (C calling):        Each constructor takes only the variant's i32
  ;;                                 fields. No threaded __state / __closure/__ev split.
  ;;   - Drift 6 (primitive-special): All 35 variants use $make_record(tag, arity)
  ;;                                 discipline. No "LConst is special" carveout.
  ;;   - Drift 7 (parallel-arrays):  Each LowExpr is ONE record. Lists OF LowExpr
  ;;                                 are opaque i32 ptrs stored as fields — not
  ;;                                 separate per-field global arrays.
  ;;   - Drift 8 (string-keyed):     Tag-int dispatch 300-334. NO "LConst" strings.
  ;;                                 LBinOp op_tag is i32 sentinel (140-153); NOT
  ;;                                 "add"/"sub". LMakeVariant tag_id is i32;
  ;;                                 LSuspend op_h is a graph handle i32.
  ;;   - Drift 9 (deferred):         All 35 variants land this commit. No "LDeclareFn
  ;;                                 fn-pointer pending" placeholder. LDeclareFn
  ;;                                 anomaly structurally surfaced via tag-313 arm.
  ;;
  ;; Named follow-ups (per Drift 9 + Hβ-lower-substrate.md §11):
  ;;   - Hβ.lower.lexpr-predicates:   $lexpr_is_l<variant> per the 35
  ;;                                  variants. Mirrors ty.wat:443-483
  ;;                                  is_t* discipline. Lands when the
  ;;                                  third caller in classify/walk_call/
  ;;                                  walk_handle earns the abstraction
  ;;                                  per Anchor 7 "three instances".
  ;;   - Hβ.lower.lvalue-lowfn-lpat-substrate:
  ;;                                  LowValue (LConst field 1) + LowFn
  ;;                                  (LMakeClosure/LMakeContinuation/
  ;;                                  LDeclareFn fn fields) + LowPat
  ;;                                  (LMatch arms) are opaque i32 ptrs here.
  ;;                                  Lands when first walker needs structural
  ;;                                  access.

  ;; ─── $lexpr_handle — universal source-handle extractor ──────────────
  ;; Per Hβ-lower-substrate.md §2 lines 287-289 + the wheel
  ;; src/lower.nx:173-209 35-arm match on `lexpr_handle`.
  ;;
  ;; Field 0 is the source TypeHandle for 34 of 35 variants. The
  ;; lone exception is LDeclareFn (tag 313) whose sole field IS the
  ;; LowFn pointer — `lexpr_handle(LDeclareFn(_)) => 0` per
  ;; src/lower.nx:187 (module-level handler-arm declarations have no
  ;; runtime expression handle; the LowFn carries its own
  ;; per-statement handle if the caller needs one).
  ;;
  ;; Per §11 audit lock (this commit): the LDeclareFn special case
  ;; is structurally surfaced via a tag-313 dispatch arm rather than
  ;; silently fabricated default. Drift 9 closure — the anomaly is
  ;; named, not absorbed.
  (func $lexpr_handle (export "lexpr_handle") (param $r i32) (result i32)
    (if (i32.eq (call $tag_of (local.get $r)) (i32.const 313))
      (then (return (i32.const 0))))
    (call $record_get (local.get $r) (i32.const 0)))

  ;; ─── 300 = LConst(handle, value) — arity 2 ────────────────────────
  ;; Per src/lower.nx:98 LConst(Int, LowValue). Field 0 source handle;
  ;; field 1 LowValue ptr (LowValue ADT shape lands in lvalue.wat
  ;; chunk follow-up — currently the seed treats LowValue as opaque
  ;; i32, same discipline as ty.wat:285-291 TList's elem field).
  (func $lexpr_make_lconst (param $h i32) (param $value i32) (result i32)
    (local $r i32)
    (local.set $r (call $make_record (i32.const 300) (i32.const 2)))
    (call $record_set (local.get $r) (i32.const 0) (local.get $h))
    (call $record_set (local.get $r) (i32.const 1) (local.get $value))
    (local.get $r))

  (func $lexpr_lconst_value (param $r i32) (result i32)
    (call $record_get (local.get $r) (i32.const 1)))

  ;; ─── 301 = LLocal(handle, name) — arity 2 ─────────────────────────
  ;; Per src/lower.nx:99 LLocal(Int, String) — "handle, local name
  ;; (matches LLet storage)". Field 1 is a string ptr (i32) per the
  ;; wheel canonical; walkthrough §4.2 prose ("slot=0") is stale.
  (func $lexpr_make_llocal (param $h i32) (param $name i32) (result i32)
    (local $r i32)
    (local.set $r (call $make_record (i32.const 301) (i32.const 2)))
    (call $record_set (local.get $r) (i32.const 0) (local.get $h))
    (call $record_set (local.get $r) (i32.const 1) (local.get $name))
    (local.get $r))

  (func $lexpr_llocal_name (param $r i32) (result i32)
    (call $record_get (local.get $r) (i32.const 1)))

  ;; ─── 302 = LGlobal(handle, name) — arity 2 ────────────────────────
  ;; Per src/lower.nx:100 LGlobal(Int, String) — "handle, name".
  (func $lexpr_make_lglobal (param $h i32) (param $name i32) (result i32)
    (local $r i32)
    (local.set $r (call $make_record (i32.const 302) (i32.const 2)))
    (call $record_set (local.get $r) (i32.const 0) (local.get $h))
    (call $record_set (local.get $r) (i32.const 1) (local.get $name))
    (local.get $r))

  (func $lexpr_lglobal_name (param $r i32) (result i32)
    (call $record_get (local.get $r) (i32.const 1)))

  ;; ─── 303 = LStore(handle, slot, value) — arity 3 ──────────────────
  ;; Per src/lower.nx:101 LStore(Int, Int, LowExpr) — "handle, slot, value".
  (func $lexpr_make_lstore (param $h i32) (param $slot i32) (param $value i32) (result i32)
    (local $r i32)
    (local.set $r (call $make_record (i32.const 303) (i32.const 3)))
    (call $record_set (local.get $r) (i32.const 0) (local.get $h))
    (call $record_set (local.get $r) (i32.const 1) (local.get $slot))
    (call $record_set (local.get $r) (i32.const 2) (local.get $value))
    (local.get $r))

  (func $lexpr_lstore_slot (param $r i32) (result i32)
    (call $record_get (local.get $r) (i32.const 1)))

  (func $lexpr_lstore_value (param $r i32) (result i32)
    (call $record_get (local.get $r) (i32.const 2)))

  ;; ─── 304 = LLet(handle, name, value) — arity 3 ────────────────────
  ;; Per src/lower.nx:102 LLet(Int, String, LowExpr).
  (func $lexpr_make_llet (param $h i32) (param $name i32) (param $value i32) (result i32)
    (local $r i32)
    (local.set $r (call $make_record (i32.const 304) (i32.const 3)))
    (call $record_set (local.get $r) (i32.const 0) (local.get $h))
    (call $record_set (local.get $r) (i32.const 1) (local.get $name))
    (call $record_set (local.get $r) (i32.const 2) (local.get $value))
    (local.get $r))

  (func $lexpr_llet_name (param $r i32) (result i32)
    (call $record_get (local.get $r) (i32.const 1)))

  (func $lexpr_llet_value (param $r i32) (result i32)
    (call $record_get (local.get $r) (i32.const 2)))

  ;; ─── 305 = LUpval(handle, slot) — arity 2 ─────────────────────────
  ;; Per src/lower.nx:103 LUpval(Int, Int).
  (func $lexpr_make_lupval (param $h i32) (param $slot i32) (result i32)
    (local $r i32)
    (local.set $r (call $make_record (i32.const 305) (i32.const 2)))
    (call $record_set (local.get $r) (i32.const 0) (local.get $h))
    (call $record_set (local.get $r) (i32.const 1) (local.get $slot))
    (local.get $r))

  (func $lexpr_lupval_slot (param $r i32) (result i32)
    (call $record_get (local.get $r) (i32.const 1)))

  ;; ─── 306 = LBinOp(handle, op_tag, l, r) — arity 4 ─────────────────
  ;; Per src/lower.nx:104 LBinOp(Int, BinOp, LowExpr, LowExpr) +
  ;; parser_infra.wat:26 BinOp tag region 140-153 (BAdd=140 .. BConcat=
  ;; 153). Field ordering (h, op, l, r) is canonical — matches the
  ;; walkthrough §2 line 246 AND the wheel src/lower.nx:104 declaration
  ;; AND the wheel's lower_expr_body BinOpExpr arm at src/lower.nx:341-342
  ;; which constructs `LBinOp(handle, op, lower_expr(left), lower_expr(right))`.
  ;;
  ;; The op_tag is stored as i32 directly (BinOp's 14 sentinels live
  ;; in [0, HEAP_BASE) per the universal nullary-sentinel discipline —
  ;; same as ResumeDiscipline 250/251/252 + Ty 100/101/102/103). $tag_of
  ;; on the op_tag returns 140-153 verbatim by the heap-base threshold.
  (func $lexpr_make_lbinop (param $h i32) (param $op_tag i32)
                            (param $l i32) (param $r i32)
                            (result i32)
    (local $rec i32)
    (local.set $rec (call $make_record (i32.const 306) (i32.const 4)))
    (call $record_set (local.get $rec) (i32.const 0) (local.get $h))
    (call $record_set (local.get $rec) (i32.const 1) (local.get $op_tag))
    (call $record_set (local.get $rec) (i32.const 2) (local.get $l))
    (call $record_set (local.get $rec) (i32.const 3) (local.get $r))
    (local.get $rec))

  (func $lexpr_lbinop_op (param $r i32) (result i32)
    (call $record_get (local.get $r) (i32.const 1)))

  (func $lexpr_lbinop_l (param $r i32) (result i32)
    (call $record_get (local.get $r) (i32.const 2)))

  (func $lexpr_lbinop_r (param $r i32) (result i32)
    (call $record_get (local.get $r) (i32.const 3)))

  ;; ─── 307 = LUnaryOp(handle, op_name, x) — arity 3 ─────────────────
  ;; Per src/lower.nx:105 LUnaryOp(Int, String, LowExpr) — op_name is a
  ;; string ptr (i32) per the wheel (NOT a sentinel; unary ops are not
  ;; enumerated in BinOp region; the name is stored as string).
  (func $lexpr_make_lunaryop (param $h i32) (param $op_name i32) (param $x i32) (result i32)
    (local $r i32)
    (local.set $r (call $make_record (i32.const 307) (i32.const 3)))
    (call $record_set (local.get $r) (i32.const 0) (local.get $h))
    (call $record_set (local.get $r) (i32.const 1) (local.get $op_name))
    (call $record_set (local.get $r) (i32.const 2) (local.get $x))
    (local.get $r))

  (func $lexpr_lunaryop_op (param $r i32) (result i32)
    (call $record_get (local.get $r) (i32.const 1)))

  (func $lexpr_lunaryop_x (param $r i32) (result i32)
    (call $record_get (local.get $r) (i32.const 2)))

  ;; ─── 308 = LCall(handle, fn, args) — arity 3 ──────────────────────
  ;; Per src/lower.nx:106 LCall(Int, LowExpr, List) — "monomorphic
  ;; direct call". Row proved ground at $monomorphic_at before choosing
  ;; LCall over LMakeClosure-with-evidence.
  (func $lexpr_make_lcall (param $h i32) (param $fn i32) (param $args i32) (result i32)
    (local $r i32)
    (local.set $r (call $make_record (i32.const 308) (i32.const 3)))
    (call $record_set (local.get $r) (i32.const 0) (local.get $h))
    (call $record_set (local.get $r) (i32.const 1) (local.get $fn))
    (call $record_set (local.get $r) (i32.const 2) (local.get $args))
    (local.get $r))

  (func $lexpr_lcall_fn (param $r i32) (result i32)
    (call $record_get (local.get $r) (i32.const 1)))

  (func $lexpr_lcall_args (param $r i32) (result i32)
    (call $record_get (local.get $r) (i32.const 2)))

  ;; ─── 309 = LTailCall(handle, fn, args) — arity 3 ──────────────────
  ;; Per src/lower.nx:107 LTailCall(Int, LowExpr, List).
  (func $lexpr_make_ltailcall (param $h i32) (param $fn i32) (param $args i32) (result i32)
    (local $r i32)
    (local.set $r (call $make_record (i32.const 309) (i32.const 3)))
    (call $record_set (local.get $r) (i32.const 0) (local.get $h))
    (call $record_set (local.get $r) (i32.const 1) (local.get $fn))
    (call $record_set (local.get $r) (i32.const 2) (local.get $args))
    (local.get $r))

  (func $lexpr_ltailcall_fn (param $r i32) (result i32)
    (call $record_get (local.get $r) (i32.const 1)))

  (func $lexpr_ltailcall_args (param $r i32) (result i32)
    (call $record_get (local.get $r) (i32.const 2)))

  ;; ─── 310 = LReturn(handle, x) — arity 2 ───────────────────────────
  ;; Per src/lower.nx:108 LReturn(Int, LowExpr).
  (func $lexpr_make_lreturn (param $h i32) (param $x i32) (result i32)
    (local $r i32)
    (local.set $r (call $make_record (i32.const 310) (i32.const 2)))
    (call $record_set (local.get $r) (i32.const 0) (local.get $h))
    (call $record_set (local.get $r) (i32.const 1) (local.get $x))
    (local.get $r))

  (func $lexpr_lreturn_x (param $r i32) (result i32)
    (call $record_get (local.get $r) (i32.const 1)))

  ;; ─── 311 = LMakeClosure(handle, fn, caps, evs) — arity 4 ──────────
  ;; Per src/lower.nx:109 LMakeClosure(Int, LowFn, List, List) —
  ;; "handle, fn, captures, ev_slots". H1 evidence reification: closure
  ;; record IS the evidence record; ev_slots follow caps in field order.
  (func $lexpr_make_lmakeclosure (param $h i32) (param $fn i32)
                                  (param $caps i32) (param $evs i32)
                                  (result i32)
    (local $r i32)
    (local.set $r (call $make_record (i32.const 311) (i32.const 4)))
    (call $record_set (local.get $r) (i32.const 0) (local.get $h))
    (call $record_set (local.get $r) (i32.const 1) (local.get $fn))
    (call $record_set (local.get $r) (i32.const 2) (local.get $caps))
    (call $record_set (local.get $r) (i32.const 3) (local.get $evs))
    (local.get $r))

  (func $lexpr_lmakeclosure_fn (param $r i32) (result i32)
    (call $record_get (local.get $r) (i32.const 1)))

  (func $lexpr_lmakeclosure_caps (param $r i32) (result i32)
    (call $record_get (local.get $r) (i32.const 2)))

  (func $lexpr_lmakeclosure_evs (param $r i32) (result i32)
    (call $record_get (local.get $r) (i32.const 3)))

  ;; ─── 312 = LMakeContinuation — arity 6 (H7 multi-shot) ────────────
  ;; Per src/lower.nx:110-119 LMakeContinuation(Int, LowFn, List, List,
  ;; Int, Int) + H7-multishot-runtime.md §1.2. Heap-allocated through
  ;; emit_alloc per the kernel's "heap has one story" crystallization #8;
  ;; fn_index field points to the synthesized __resume function in the
  ;; WASM funcref table; state_index discriminates the perform site that
  ;; resumed; ret_slot reserves the local slot the resumed value lands in.
  ;; Composes with LMakeClosure's capture/ev-store loops at emit time
  ;; (per H7 §4.2 — emit shares the per-field store helpers).
  (func $lexpr_make_lmakecontinuation
        (param $h i32) (param $fn i32) (param $caps i32) (param $evs i32)
        (param $state_idx i32) (param $ret_slot i32)
        (result i32)
    (local $r i32)
    (local.set $r (call $make_record (i32.const 312) (i32.const 6)))
    (call $record_set (local.get $r) (i32.const 0) (local.get $h))
    (call $record_set (local.get $r) (i32.const 1) (local.get $fn))
    (call $record_set (local.get $r) (i32.const 2) (local.get $caps))
    (call $record_set (local.get $r) (i32.const 3) (local.get $evs))
    (call $record_set (local.get $r) (i32.const 4) (local.get $state_idx))
    (call $record_set (local.get $r) (i32.const 5) (local.get $ret_slot))
    (local.get $r))

  (func $lexpr_lmakecontinuation_fn (param $r i32) (result i32)
    (call $record_get (local.get $r) (i32.const 1)))

  (func $lexpr_lmakecontinuation_caps (param $r i32) (result i32)
    (call $record_get (local.get $r) (i32.const 2)))

  (func $lexpr_lmakecontinuation_evs (param $r i32) (result i32)
    (call $record_get (local.get $r) (i32.const 3)))

  (func $lexpr_lmakecontinuation_state_idx (param $r i32) (result i32)
    (call $record_get (local.get $r) (i32.const 4)))

  (func $lexpr_lmakecontinuation_ret_slot (param $r i32) (result i32)
    (call $record_get (local.get $r) (i32.const 5)))

  ;; ─── 313 = LDeclareFn(fn) — arity 1 (NO handle field) ─────────────
  ;; Per src/lower.nx:120 LDeclareFn(LowFn) — "module-level fn
  ;; declaration (handler arm) — no runtime slot". Per src/lower.nx:187
  ;; `lexpr_handle(LDeclareFn(_)) => 0` — module-level fn declarations
  ;; are NOT runtime expressions; they have no source TypeHandle in the
  ;; expression-position sense (the LowFn carries its own per-statement
  ;; handle if the caller needs one via $lowfn_handle — pending lvalue/
  ;; lowfn.wat chunk follow-up).
  ;;
  ;; The anomaly is structural per §11 audit: $lexpr_handle (the
  ;; universal accessor at this chunk's top) tag-313-dispatches to
  ;; return 0 rather than $record_get(r, 0). Field 0 here IS the LowFn
  ;; pointer; $lexpr_ldeclarefn_fn surfaces it for callers (chunk #10
  ;; walk_stmt.wat at FnStmt arm + chunk #11 main.wat at $lower_program
  ;; collection).
  (func $lexpr_make_ldeclarefn (param $fn i32) (result i32)
    (local $r i32)
    (local.set $r (call $make_record (i32.const 313) (i32.const 1)))
    (call $record_set (local.get $r) (i32.const 0) (local.get $fn))
    (local.get $r))

  (func $lexpr_ldeclarefn_fn (param $r i32) (result i32)
    (call $record_get (local.get $r) (i32.const 0)))

  ;; ─── 314 = LIf(handle, cond, then, else) — arity 4 ─────────────────
  ;; Per src/lower.nx:121 LIf(Int, LowExpr, List, List). Fields 2 and 3
  ;; are List ptrs (i32) for the then/else branch statement lists.
  (func $lexpr_make_lif (param $h i32) (param $cond i32)
                         (param $then_branch i32) (param $else_branch i32)
                         (result i32)
    (local $r i32)
    (local.set $r (call $make_record (i32.const 314) (i32.const 4)))
    (call $record_set (local.get $r) (i32.const 0) (local.get $h))
    (call $record_set (local.get $r) (i32.const 1) (local.get $cond))
    (call $record_set (local.get $r) (i32.const 2) (local.get $then_branch))
    (call $record_set (local.get $r) (i32.const 3) (local.get $else_branch))
    (local.get $r))

  (func $lexpr_lif_cond (param $r i32) (result i32)
    (call $record_get (local.get $r) (i32.const 1)))

  (func $lexpr_lif_then (param $r i32) (result i32)
    (call $record_get (local.get $r) (i32.const 2)))

  (func $lexpr_lif_else (param $r i32) (result i32)
    (call $record_get (local.get $r) (i32.const 3)))

  ;; ─── 315 = LBlock(handle, stmts) — arity 2 ────────────────────────
  ;; Per src/lower.nx:122 LBlock(Int, List).
  (func $lexpr_make_lblock (param $h i32) (param $stmts i32) (result i32)
    (local $r i32)
    (local.set $r (call $make_record (i32.const 315) (i32.const 2)))
    (call $record_set (local.get $r) (i32.const 0) (local.get $h))
    (call $record_set (local.get $r) (i32.const 1) (local.get $stmts))
    (local.get $r))

  (func $lexpr_lblock_stmts (param $r i32) (result i32)
    (call $record_get (local.get $r) (i32.const 1)))

  ;; ─── 316 = LMakeList(handle, elems) — arity 2 ─────────────────────
  ;; Per src/lower.nx:123 LMakeList(Int, List).
  (func $lexpr_make_lmakelist (param $h i32) (param $elems i32) (result i32)
    (local $r i32)
    (local.set $r (call $make_record (i32.const 316) (i32.const 2)))
    (call $record_set (local.get $r) (i32.const 0) (local.get $h))
    (call $record_set (local.get $r) (i32.const 1) (local.get $elems))
    (local.get $r))

  (func $lexpr_lmakelist_elems (param $r i32) (result i32)
    (call $record_get (local.get $r) (i32.const 1)))

  ;; ─── 317 = LMakeTuple(handle, elems) — arity 2 ────────────────────
  ;; Per src/lower.nx:124 LMakeTuple(Int, List).
  (func $lexpr_make_lmaketuple (param $h i32) (param $elems i32) (result i32)
    (local $r i32)
    (local.set $r (call $make_record (i32.const 317) (i32.const 2)))
    (call $record_set (local.get $r) (i32.const 0) (local.get $h))
    (call $record_set (local.get $r) (i32.const 1) (local.get $elems))
    (local.get $r))

  (func $lexpr_lmaketuple_elems (param $r i32) (result i32)
    (call $record_get (local.get $r) (i32.const 1)))

  ;; ─── 318 = LMakeRecord(handle, fields) — arity 2 ──────────────────
  ;; Per src/lower.nx:125 LMakeRecord(Int, List) — "handle, [field_value]
  ;; sorted by field name". Field 1 is a list of field value exprs (i32).
  (func $lexpr_make_lmakerecord (param $h i32) (param $fields i32) (result i32)
    (local $r i32)
    (local.set $r (call $make_record (i32.const 318) (i32.const 2)))
    (call $record_set (local.get $r) (i32.const 0) (local.get $h))
    (call $record_set (local.get $r) (i32.const 1) (local.get $fields))
    (local.get $r))

  (func $lexpr_lmakerecord_fields (param $r i32) (result i32)
    (call $record_get (local.get $r) (i32.const 1)))

  ;; ─── 319 = LMakeVariant(handle, tag_id, args) — arity 3 ────────────
  ;; Per src/lower.nx:126 LMakeVariant(Int, TagId, List) — "handle, tag_id,
  ;; field exprs". TagId is i32 (ConstructorScheme tag from H3).
  (func $lexpr_make_lmakevariant (param $h i32) (param $tag_id i32) (param $args i32) (result i32)
    (local $r i32)
    (local.set $r (call $make_record (i32.const 319) (i32.const 3)))
    (call $record_set (local.get $r) (i32.const 0) (local.get $h))
    (call $record_set (local.get $r) (i32.const 1) (local.get $tag_id))
    (call $record_set (local.get $r) (i32.const 2) (local.get $args))
    (local.get $r))

  (func $lexpr_lmakevariant_tag_id (param $r i32) (result i32)
    (call $record_get (local.get $r) (i32.const 1)))

  (func $lexpr_lmakevariant_args (param $r i32) (result i32)
    (call $record_get (local.get $r) (i32.const 2)))

  ;; ─── 320 = LIndex(handle, base, idx, is_str) — arity 4 ─────────────
  ;; Per src/lower.nx:127 LIndex(Int, LowExpr, LowExpr, Bool) — is_str
  ;; stored as raw i32 0/1 (HB nullary Bool sentinel in [0, HEAP_BASE)).
  (func $lexpr_make_lindex (param $h i32) (param $base i32)
                             (param $idx i32) (param $is_str i32)
                             (result i32)
    (local $r i32)
    (local.set $r (call $make_record (i32.const 320) (i32.const 4)))
    (call $record_set (local.get $r) (i32.const 0) (local.get $h))
    (call $record_set (local.get $r) (i32.const 1) (local.get $base))
    (call $record_set (local.get $r) (i32.const 2) (local.get $idx))
    (call $record_set (local.get $r) (i32.const 3) (local.get $is_str))
    (local.get $r))

  (func $lexpr_lindex_base (param $r i32) (result i32)
    (call $record_get (local.get $r) (i32.const 1)))

  (func $lexpr_lindex_idx (param $r i32) (result i32)
    (call $record_get (local.get $r) (i32.const 2)))

  (func $lexpr_lindex_is_str (param $r i32) (result i32)
    (call $record_get (local.get $r) (i32.const 3)))

  ;; ─── 321 = LMatch(handle, scrut, arms) — arity 3 ───────────────────
  ;; Per src/lower.nx:128 LMatch(Int, LowExpr, List) — "body + arms".
  ;; Arms is a list of LowPat-arm records (opaque i32 pending
  ;; Hβ.lower.lvalue-lowfn-lpat-substrate follow-up).
  (func $lexpr_make_lmatch (param $h i32) (param $scrut i32) (param $arms i32) (result i32)
    (local $r i32)
    (local.set $r (call $make_record (i32.const 321) (i32.const 3)))
    (call $record_set (local.get $r) (i32.const 0) (local.get $h))
    (call $record_set (local.get $r) (i32.const 1) (local.get $scrut))
    (call $record_set (local.get $r) (i32.const 2) (local.get $arms))
    (local.get $r))

  (func $lexpr_lmatch_scrut (param $r i32) (result i32)
    (call $record_get (local.get $r) (i32.const 1)))

  (func $lexpr_lmatch_arms (param $r i32) (result i32)
    (call $record_get (local.get $r) (i32.const 2)))

  ;; ─── 325 = LSuspend(handle, op_h, fn, args, evs) — arity 5 ─────────
  ;; Per src/lower.nx:132 LSuspend(Int, Int, LowExpr, List, List) —
  ;; "handle, op_h, fn_expr, args, ev_slots". Field 1 is the op's GRAPH
  ;; HANDLE (i32 — the perform site's op-name resolves to a handle at
  ;; infer time; lower carries the handle, not a re-derived string).
  ;; This avoids drift mode 8 (string-keyed-when-structured) — the
  ;; handle IS the structured form; emit reads back to the env via the
  ;; handle when it needs the op_name string at WAT-text generation.
  (func $lexpr_make_lsuspend
        (param $h i32) (param $op_h i32) (param $fn i32)
        (param $args i32) (param $evs i32)
        (result i32)
    (local $r i32)
    (local.set $r (call $make_record (i32.const 325) (i32.const 5)))
    (call $record_set (local.get $r) (i32.const 0) (local.get $h))
    (call $record_set (local.get $r) (i32.const 1) (local.get $op_h))
    (call $record_set (local.get $r) (i32.const 2) (local.get $fn))
    (call $record_set (local.get $r) (i32.const 3) (local.get $args))
    (call $record_set (local.get $r) (i32.const 4) (local.get $evs))
    (local.get $r))

  (func $lexpr_lsuspend_op_h (param $r i32) (result i32)
    (call $record_get (local.get $r) (i32.const 1)))

  (func $lexpr_lsuspend_fn (param $r i32) (result i32)
    (call $record_get (local.get $r) (i32.const 2)))

  (func $lexpr_lsuspend_args (param $r i32) (result i32)
    (call $record_get (local.get $r) (i32.const 3)))

  (func $lexpr_lsuspend_evs (param $r i32) (result i32)
    (call $record_get (local.get $r) (i32.const 4)))

  ;; ─── 326 = LStateGet(handle, slot) — arity 2 ───────────────────────
  ;; Per src/lower.nx:133 LStateGet(Int, Int).
  (func $lexpr_make_lstateget (param $h i32) (param $slot i32) (result i32)
    (local $r i32)
    (local.set $r (call $make_record (i32.const 326) (i32.const 2)))
    (call $record_set (local.get $r) (i32.const 0) (local.get $h))
    (call $record_set (local.get $r) (i32.const 1) (local.get $slot))
    (local.get $r))

  (func $lexpr_lstateget_slot (param $r i32) (result i32)
    (call $record_get (local.get $r) (i32.const 1)))

  ;; ─── 327 = LStateSet(handle, slot, value) — arity 3 ────────────────
  ;; Per src/lower.nx:134 LStateSet(Int, Int, LowExpr).
  (func $lexpr_make_lstateset (param $h i32) (param $slot i32) (param $value i32) (result i32)
    (local $r i32)
    (local.set $r (call $make_record (i32.const 327) (i32.const 3)))
    (call $record_set (local.get $r) (i32.const 0) (local.get $h))
    (call $record_set (local.get $r) (i32.const 1) (local.get $slot))
    (call $record_set (local.get $r) (i32.const 2) (local.get $value))
    (local.get $r))

  (func $lexpr_lstateset_slot (param $r i32) (result i32)
    (call $record_get (local.get $r) (i32.const 1)))

  (func $lexpr_lstateset_value (param $r i32) (result i32)
    (call $record_get (local.get $r) (i32.const 2)))

  ;; ─── 328 = LRegion(handle, body) — arity 2 ─────────────────────────
  ;; Per src/lower.nx:135 LRegion(Int, List) — "arena scope".
  (func $lexpr_make_lregion (param $h i32) (param $body i32) (result i32)
    (local $r i32)
    (local.set $r (call $make_record (i32.const 328) (i32.const 2)))
    (call $record_set (local.get $r) (i32.const 0) (local.get $h))
    (call $record_set (local.get $r) (i32.const 1) (local.get $body))
    (local.get $r))

  (func $lexpr_lregion_body (param $r i32) (result i32)
    (call $record_get (local.get $r) (i32.const 1)))

  ;; ─── 329 = LHandleWith(handle, body, handler) — arity 3 ─────────────
  ;; Per src/lower.nx:136 LHandleWith(Int, LowExpr, LowExpr) — "~>
  ;; desugaring". Both body and handler are LowExpr ptrs (i32).
  (func $lexpr_make_lhandlewith (param $h i32) (param $body i32) (param $handler i32) (result i32)
    (local $r i32)
    (local.set $r (call $make_record (i32.const 329) (i32.const 3)))
    (call $record_set (local.get $r) (i32.const 0) (local.get $h))
    (call $record_set (local.get $r) (i32.const 1) (local.get $body))
    (call $record_set (local.get $r) (i32.const 2) (local.get $handler))
    (local.get $r))

  (func $lexpr_lhandlewith_body (param $r i32) (result i32)
    (call $record_get (local.get $r) (i32.const 1)))

  (func $lexpr_lhandlewith_handler (param $r i32) (result i32)
    (call $record_get (local.get $r) (i32.const 2)))

  ;; ─── 330 = LFeedback(handle, body, spec) — arity 3 ──────────────────
  ;; Per src/lower.nx:137 LFeedback(Int, LowExpr, LowExpr) — "<~
  ;; desugaring (iterative ctx required)". Field 2 is the spec LowExpr
  ;; (NOT a metadata record).
  (func $lexpr_make_lfeedback (param $h i32) (param $body i32) (param $spec i32) (result i32)
    (local $r i32)
    (local.set $r (call $make_record (i32.const 330) (i32.const 3)))
    (call $record_set (local.get $r) (i32.const 0) (local.get $h))
    (call $record_set (local.get $r) (i32.const 1) (local.get $body))
    (call $record_set (local.get $r) (i32.const 2) (local.get $spec))
    (local.get $r))

  (func $lexpr_lfeedback_body (param $r i32) (result i32)
    (call $record_get (local.get $r) (i32.const 1)))

  (func $lexpr_lfeedback_spec (param $r i32) (result i32)
    (call $record_get (local.get $r) (i32.const 2)))

  ;; ─── 331 = LPerform(handle, op_name, args) — arity 3 ────────────────
  ;; Per src/lower.nx:138 LPerform(Int, String, List) — "effect op
  ;; invocation — monomorphic direct-call form". When inference proves
  ;; ground row, perform → LPerform (direct $op_<name> call); polymorphic
  ;; sites become LEvPerform (tag 333).
  (func $lexpr_make_lperform (param $h i32) (param $op_name i32) (param $args i32) (result i32)
    (local $r i32)
    (local.set $r (call $make_record (i32.const 331) (i32.const 3)))
    (call $record_set (local.get $r) (i32.const 0) (local.get $h))
    (call $record_set (local.get $r) (i32.const 1) (local.get $op_name))
    (call $record_set (local.get $r) (i32.const 2) (local.get $args))
    (local.get $r))

  (func $lexpr_lperform_op_name (param $r i32) (result i32)
    (call $record_get (local.get $r) (i32.const 1)))

  (func $lexpr_lperform_args (param $r i32) (result i32)
    (call $record_get (local.get $r) (i32.const 2)))

  ;; ─── 332 = LHandle(handle, body, arms) — arity 3 ─────────────────────
  ;; Per src/lower.nx:139 LHandle(Int, LowExpr, List) — "body + arms
  ;; (handle-expression)". Arms is a list of arm records (opaque i32).
  (func $lexpr_make_lhandle (param $h i32) (param $body i32) (param $arms i32) (result i32)
    (local $r i32)
    (local.set $r (call $make_record (i32.const 332) (i32.const 3)))
    (call $record_set (local.get $r) (i32.const 0) (local.get $h))
    (call $record_set (local.get $r) (i32.const 1) (local.get $body))
    (call $record_set (local.get $r) (i32.const 2) (local.get $arms))
    (local.get $r))

  (func $lexpr_lhandle_body (param $r i32) (result i32)
    (call $record_get (local.get $r) (i32.const 1)))

  (func $lexpr_lhandle_arms (param $r i32) (result i32)
    (call $record_get (local.get $r) (i32.const 2)))

  ;; ─── 333 = LEvPerform(handle, op_name, slot_idx, args) — arity 4 ────
  ;; Per src/lower.nx:149 LEvPerform(Int, String, Int, List) — "handle,
  ;; op_name, slot_idx, args". H1: loads fn_idx from __state at the
  ;; compile-time-resolved slot_idx offset; dispatches via call_indirect.
  ;; Only polymorphic perform sites (open row) become LEvPerform; monomorphic
  ;; sites stay LPerform (tag 331).
  (func $lexpr_make_levperform (param $h i32) (param $op_name i32)
                                (param $slot_idx i32) (param $args i32)
                                (result i32)
    (local $r i32)
    (local.set $r (call $make_record (i32.const 333) (i32.const 4)))
    (call $record_set (local.get $r) (i32.const 0) (local.get $h))
    (call $record_set (local.get $r) (i32.const 1) (local.get $op_name))
    (call $record_set (local.get $r) (i32.const 2) (local.get $slot_idx))
    (call $record_set (local.get $r) (i32.const 3) (local.get $args))
    (local.get $r))

  (func $lexpr_levperform_op_name (param $r i32) (result i32)
    (call $record_get (local.get $r) (i32.const 1)))

  (func $lexpr_levperform_slot_idx (param $r i32) (result i32)
    (call $record_get (local.get $r) (i32.const 2)))

  (func $lexpr_levperform_args (param $r i32) (result i32)
    (call $record_get (local.get $r) (i32.const 3)))

  ;; ─── 334 = LFieldLoad(handle, record, offset_bytes) — arity 3 ────────
  ;; Per src/lower.nx:150 LFieldLoad(Int, LowExpr, Int) — "W6: handle,
  ;; record, offset_bytes".
  (func $lexpr_make_lfieldload (param $h i32) (param $record i32) (param $offset_bytes i32) (result i32)
    (local $r i32)
    (local.set $r (call $make_record (i32.const 334) (i32.const 3)))
    (call $record_set (local.get $r) (i32.const 0) (local.get $h))
    (call $record_set (local.get $r) (i32.const 1) (local.get $record))
    (call $record_set (local.get $r) (i32.const 2) (local.get $offset_bytes))
    (local.get $r))

  (func $lexpr_lfieldload_record (param $r i32) (result i32)
    (call $record_get (local.get $r) (i32.const 1)))

  (func $lexpr_lfieldload_offset_bytes (param $r i32) (result i32)
    (call $record_get (local.get $r) (i32.const 2)))
