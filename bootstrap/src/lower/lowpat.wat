  ;; ═══ lowpat.wat — LowPat ADT substrate (Tier 4) ═════════════════════
  ;; Hβ.lower Phase C.2 — LowPat ADT at the WAT layer.
  ;; The lowering walk's pattern-match product type. 9 LowPat variants
  ;; + LPArm wrapper. Each variant carries a source TypeHandle (field 0)
  ;; for emit's match-pattern-compile pass to read back into the graph.
  ;;
  ;; Implements: Hβ-lower-substrate.md §11 named follow-up
  ;;             `Hβ.lower.lvalue-lowfn-lpat-substrate` (LowPat half);
  ;;             deep-toasting-bachman.md Phase C.2;
  ;;             spec 03 (Pattern) + spec 05 (lowering) + SYNTAX.md
  ;;             §"Pattern syntax" lines 894-963.
  ;; Exports:    $lowpat_handle (universal),
  ;;             $lowpat_make_lpvar $lowpat_lpvar_name,
  ;;             $lowpat_make_lpwild,
  ;;             $lowpat_make_lplit $lowpat_lplit_value,
  ;;             $lowpat_make_lpcon $lowpat_lpcon_tag_id $lowpat_lpcon_args,
  ;;             $lowpat_make_lptuple $lowpat_lptuple_elems,
  ;;             $lowpat_make_lplist $lowpat_lplist_elems $lowpat_lplist_rest,
  ;;             $lowpat_make_lprecord $lowpat_lprecord_fields $lowpat_lprecord_rest,
  ;;             $lowpat_make_lpalt $lowpat_lpalt_branches,
  ;;             $lowpat_make_lpas $lowpat_lpas_name $lowpat_lpas_pat,
  ;;             $lowpat_make_lparm $lowpat_lparm_pat $lowpat_lparm_body
  ;; Uses:       $make_record / $record_get / $record_set / $tag_of
  ;;               (record.wat)
  ;; Test:       bootstrap/test/lower/lowpat_arms.wat
  ;;
  ;; ─── TAG REGION ────────────────────────────────────────────────────
  ;;
  ;; Tags 360-369 in the LowPat-private region.
  ;; Extends tag-uniqueness map from lowfn.wat:
  ;;   300-334    LowExpr variants (lexpr.wat)
  ;;   335-349    reserved future LowExpr
  ;;   350-359    LowFn (lowfn.wat)
  ;;   360        LPVar
  ;;   361        LPWild
  ;;   362        LPLit
  ;;   363        LPCon
  ;;   364        LPTuple
  ;;   365        LPList
  ;;   366        LPRecord
  ;;   367        LPAlt
  ;;   368        LPAs
  ;;   369        LPArm
  ;;
  ;; ─── EIGHT INTERROGATIONS ──────────────────────────────────────────
  ;;
  ;; 1. Graph?      LPVar binds at handle; LPCon's tag_id is graph-read.
  ;; 2. Handler?    Pattern-match arm projection (emit's match-pattern-
  ;;                compile reads).
  ;; 3. Verb?       Match expression desugars to nested LIf chain at
  ;;                emit time; LowPat IS the input shape.
  ;; 4. Row?        N/A at LowPat layer.
  ;; 5. Ownership?  Scrutinee `ref`-borrowed across arms (no consume in
  ;;                pattern-test phase).
  ;; 6. Refinement? Refined types unwrap transparently in LPLit.
  ;; 7. Gradient?   Tag-int dispatch is the H6 cash-out (every nullary
  ;;                ADT is tagged — Bool included).
  ;; 8. Reason?     Arm-body's Reason chain composes with pattern's
  ;;                discrimination edge.
  ;;
  ;; ─── FORBIDDEN PATTERNS ────────────────────────────────────────────
  ;;
  ;; - Drift 1:    No $lowpat_dispatch_table. Tag-int dispatch via
  ;;               if-chain or br_table.
  ;; - Drift 6:    No Bool special-case for boolean LPLit. Bool literal
  ;;               IS LPCon(LBool sentinel) per HB drift-6 closure.
  ;; - Drift 7:    No parallel arrays for LPRecord fields. One record-
  ;;               list of (name, pat) entries.
  ;; - Drift 8:    LPCon tag_id is i32 sentinel, not string. LPLit
  ;;               value is LowValue, not raw string.
  ;; - Drift 9:    All 9 LowPat variants + LPArm land this commit. No
  ;;               "LPGuard later" hedge.

  ;; ─── $lowpat_handle — universal source-handle extractor ────────────
  ;; Field 0 is the source TypeHandle for all 9 LowPat variants.
  ;; LPArm (tag 369) has NO handle — its field 0 is the pat. Callers
  ;; access LPArm via $lowpat_lparm_pat / $lowpat_lparm_body, not via
  ;; $lowpat_handle. Returns 0 for LPArm (same sentinel as lexpr.wat's
  ;; $lexpr_handle on LDeclareFn).
  (func $lowpat_handle (export "lowpat_handle") (param $r i32) (result i32)
    (if (i32.eq (call $tag_of (local.get $r)) (i32.const 369))
      (then (return (i32.const 0))))
    (call $record_get (local.get $r) (i32.const 0)))

  ;; ─── 360 = LPVar(handle, name) — arity 2 ──────────────────────────
  ;; Binds the matched value to `name` in the arm body's scope.
  (func $lowpat_make_lpvar (export "lowpat_make_lpvar")
        (param $h i32) (param $name i32) (result i32)
    (local $r i32)
    (local.set $r (call $make_record (i32.const 360) (i32.const 2)))
    (call $record_set (local.get $r) (i32.const 0) (local.get $h))
    (call $record_set (local.get $r) (i32.const 1) (local.get $name))
    (local.get $r))

  (func $lowpat_lpvar_name (export "lowpat_lpvar_name") (param $r i32) (result i32)
    (call $record_get (local.get $r) (i32.const 1)))

  ;; ─── 361 = LPWild(handle) — arity 1 ───────────────────────────────
  ;; Matches anything, binds nothing. The `_` pattern.
  (func $lowpat_make_lpwild (export "lowpat_make_lpwild")
        (param $h i32) (result i32)
    (local $r i32)
    (local.set $r (call $make_record (i32.const 361) (i32.const 1)))
    (call $record_set (local.get $r) (i32.const 0) (local.get $h))
    (local.get $r))

  ;; ─── 362 = LPLit(handle, value) — arity 2 ─────────────────────────
  ;; Matches a literal value. INT / FLOAT / STRING / UNIT only.
  ;; NOT Bool — Bool true/false are LPCon(tag_id=True_sentinel, [])
  ;; per HB drift-6 closure. `value` is LowValue (opaque i32 pending
  ;; lvalue.wat chunk).
  (func $lowpat_make_lplit (export "lowpat_make_lplit")
        (param $h i32) (param $value i32) (result i32)
    (local $r i32)
    (local.set $r (call $make_record (i32.const 362) (i32.const 2)))
    (call $record_set (local.get $r) (i32.const 0) (local.get $h))
    (call $record_set (local.get $r) (i32.const 1) (local.get $value))
    (local.get $r))

  (func $lowpat_lplit_value (export "lowpat_lplit_value") (param $r i32) (result i32)
    (call $record_get (local.get $r) (i32.const 1)))

  ;; ─── 363 = LPCon(handle, tag_id, args) — arity 3 ──────────────────
  ;; Constructor pattern. tag_id is i32 sentinel from
  ;; ConstructorScheme. Covers Bool variants AND user-defined
  ;; nullary/N-ary variants under one substrate. `args` is a list
  ;; of LowPat (sub-patterns for constructor fields).
  (func $lowpat_make_lpcon (export "lowpat_make_lpcon")
        (param $h i32) (param $tag_id i32) (param $args i32)
        (result i32)
    (local $r i32)
    (local.set $r (call $make_record (i32.const 363) (i32.const 3)))
    (call $record_set (local.get $r) (i32.const 0) (local.get $h))
    (call $record_set (local.get $r) (i32.const 1) (local.get $tag_id))
    (call $record_set (local.get $r) (i32.const 2) (local.get $args))
    (local.get $r))

  (func $lowpat_lpcon_tag_id (export "lowpat_lpcon_tag_id") (param $r i32) (result i32)
    (call $record_get (local.get $r) (i32.const 1)))

  (func $lowpat_lpcon_args (export "lowpat_lpcon_args") (param $r i32) (result i32)
    (call $record_get (local.get $r) (i32.const 2)))

  ;; ─── 364 = LPTuple(handle, elems) — arity 2 ───────────────────────
  ;; Tuple destructuring pattern. `elems` is list of LowPat.
  (func $lowpat_make_lptuple (export "lowpat_make_lptuple")
        (param $h i32) (param $elems i32) (result i32)
    (local $r i32)
    (local.set $r (call $make_record (i32.const 364) (i32.const 2)))
    (call $record_set (local.get $r) (i32.const 0) (local.get $h))
    (call $record_set (local.get $r) (i32.const 1) (local.get $elems))
    (local.get $r))

  (func $lowpat_lptuple_elems (export "lowpat_lptuple_elems") (param $r i32) (result i32)
    (call $record_get (local.get $r) (i32.const 1)))

  ;; ─── 365 = LPList(handle, elems, rest_var) — arity 3 ──────────────
  ;; List destructuring. `elems` is list of LowPat for head elements.
  ;; `rest_var` is 0 if no `...rest` tail; otherwise the name string ptr.
  (func $lowpat_make_lplist (export "lowpat_make_lplist")
        (param $h i32) (param $elems i32) (param $rest i32)
        (result i32)
    (local $r i32)
    (local.set $r (call $make_record (i32.const 365) (i32.const 3)))
    (call $record_set (local.get $r) (i32.const 0) (local.get $h))
    (call $record_set (local.get $r) (i32.const 1) (local.get $elems))
    (call $record_set (local.get $r) (i32.const 2) (local.get $rest))
    (local.get $r))

  (func $lowpat_lplist_elems (export "lowpat_lplist_elems") (param $r i32) (result i32)
    (call $record_get (local.get $r) (i32.const 1)))

  (func $lowpat_lplist_rest (export "lowpat_lplist_rest") (param $r i32) (result i32)
    (call $record_get (local.get $r) (i32.const 2)))

  ;; ─── 366 = LPRecord(handle, fields, rest_var) — arity 3 ───────────
  ;; Record destructuring. `fields` is list of (name, LowPat) pairs.
  ;; `rest_var` is 0 if no `...rest`; otherwise the name string ptr.
  (func $lowpat_make_lprecord (export "lowpat_make_lprecord")
        (param $h i32) (param $fields i32) (param $rest i32)
        (result i32)
    (local $r i32)
    (local.set $r (call $make_record (i32.const 366) (i32.const 3)))
    (call $record_set (local.get $r) (i32.const 0) (local.get $h))
    (call $record_set (local.get $r) (i32.const 1) (local.get $fields))
    (call $record_set (local.get $r) (i32.const 2) (local.get $rest))
    (local.get $r))

  (func $lowpat_lprecord_fields (export "lowpat_lprecord_fields") (param $r i32) (result i32)
    (call $record_get (local.get $r) (i32.const 1)))

  (func $lowpat_lprecord_rest (export "lowpat_lprecord_rest") (param $r i32) (result i32)
    (call $record_get (local.get $r) (i32.const 2)))

  ;; ─── 367 = LPAlt(handle, branches) — arity 2 ──────────────────────
  ;; Alternation pattern per SYNTAX.md line 908. `branches` is a list
  ;; of LowPat. "No variable bindings inside alternatives" per SYNTAX.md
  ;; line 956 — enforced at lower-time.
  (func $lowpat_make_lpalt (export "lowpat_make_lpalt")
        (param $h i32) (param $branches i32) (result i32)
    (local $r i32)
    (local.set $r (call $make_record (i32.const 367) (i32.const 2)))
    (call $record_set (local.get $r) (i32.const 0) (local.get $h))
    (call $record_set (local.get $r) (i32.const 1) (local.get $branches))
    (local.get $r))

  (func $lowpat_lpalt_branches (export "lowpat_lpalt_branches") (param $r i32) (result i32)
    (call $record_get (local.get $r) (i32.const 1)))

  ;; ─── 368 = LPAs(handle, name, pat) — arity 3 ──────────────────────
  ;; As-pattern per SYNTAX.md line 909. Binds whole value AND
  ;; destructures via inner `pat`.
  (func $lowpat_make_lpas (export "lowpat_make_lpas")
        (param $h i32) (param $name i32) (param $pat i32)
        (result i32)
    (local $r i32)
    (local.set $r (call $make_record (i32.const 368) (i32.const 3)))
    (call $record_set (local.get $r) (i32.const 0) (local.get $h))
    (call $record_set (local.get $r) (i32.const 1) (local.get $name))
    (call $record_set (local.get $r) (i32.const 2) (local.get $pat))
    (local.get $r))

  (func $lowpat_lpas_name (export "lowpat_lpas_name") (param $r i32) (result i32)
    (call $record_get (local.get $r) (i32.const 1)))

  (func $lowpat_lpas_pat (export "lowpat_lpas_pat") (param $r i32) (result i32)
    (call $record_get (local.get $r) (i32.const 2)))

  ;; ─── 369 = LPArm(pat, body) — arity 2 ─────────────────────────────
  ;; Match arm wrapper. `pat` is LowPat, `body` is LowExpr.
  ;; NO guard field per SYNTAX.md — match arms are `pattern => body`,
  ;; not `pat where guard => body`. Guards-via-`if`-inside-arm-body
  ;; suffices; adding a guard field would be Haskell/Rust drift.
  ;; NO handle field — LPArm is structural, not expression-position.
  (func $lowpat_make_lparm (export "lowpat_make_lparm")
        (param $pat i32) (param $body i32) (result i32)
    (local $r i32)
    (local.set $r (call $make_record (i32.const 369) (i32.const 2)))
    (call $record_set (local.get $r) (i32.const 0) (local.get $pat))
    (call $record_set (local.get $r) (i32.const 1) (local.get $body))
    (local.get $r))

  (func $lowpat_lparm_pat (export "lowpat_lparm_pat") (param $r i32) (result i32)
    (call $record_get (local.get $r) (i32.const 0)))

  (func $lowpat_lparm_body (export "lowpat_lparm_body") (param $r i32) (result i32)
    (call $record_get (local.get $r) (i32.const 1)))
