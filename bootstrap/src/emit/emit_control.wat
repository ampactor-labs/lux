  ;; ═══ emit_control.wat — Hβ.emit control family (Tier 6, chunk #5) ═══
  ;; Implements: Hβ-emit-substrate.md §2.3 (control family — LIf tag 314 +
  ;;             LBlock tag 315 + LMatch tag 321 + LReturn tag 310 +
  ;;             LRegion tag 328) + §5.1 (eight interrogations) + §7.1
  ;;             (chunk #5 emit_control.wat) + §11.3 dep order (chunk #5
  ;;             follows emit_local.wat which retrofitted $emit_lexpr
  ;;             with §2.2 arms).
  ;; Exports:    $emit_lif, $emit_lblock, $emit_lmatch, $emit_lreturn,
  ;;             $emit_lregion.
  ;; Uses:       $lexpr_lif_cond + $lexpr_lif_then + $lexpr_lif_else +
  ;;             $lexpr_lblock_stmts + $lexpr_lmatch_scrut +
  ;;             $lexpr_lmatch_arms + $lexpr_lreturn_x +
  ;;             $lexpr_lregion_body (lower/lexpr.wat),
  ;;             $emit_byte + $emit_str (emit_infra.wat),
  ;;             $emit_lexpr (emit_const.wat — partial dispatcher;
  ;;             this chunk RETROFITS its arm table for tags 310/314/315/
  ;;             321/328 per Hβ.emit.lexpr-dispatch-extension),
  ;;             $ec_emit_unreachable (emit_const.wat — reused for empty-
  ;;             arms LMatch + the LowPat-substrate-pending NAMED
  ;;             follow-up trap),
  ;;             $len + $list_index (runtime/list.wat).
  ;;
  ;; What this chunk IS (per Hβ-emit-substrate.md §2.3 + wheel canonical
  ;; src/backends/wasm.mn:1220-1223 + 1310-1319 + 1379-1394 + 1514+):
  ;;
  ;;   1. $emit_lreturn(r) — LReturn tag 310 (handle, x). Emits the inner
  ;;      LowExpr's value via $emit_lexpr, then "(return)" — the WASM
  ;;      control-flow primitive that hands the value back to the
  ;;      suspended `perform` site. NOT an imperative-`return` arm: Mentl
  ;;      has no `return` keyword (SYNTAX.md line 1335). LReturn is the
  ;;      lowered form of `resume(value)` inside a OneShot handler arm
  ;;      per Hβ.lower walk_call.wat Lock #6 (`ResumeExpr → LReturn`).
  ;;
  ;;   2. $emit_lif(r) — LIf tag 314 (handle, cond, then_branch, else_branch).
  ;;      Emits cond via $emit_lexpr, then "(if (result i32) (then ...)
  ;;      (else ...))" wrapping the two branches. Branches are stmt lists;
  ;;      each emitted via $ec5_emit_body sequential walk.
  ;;
  ;;   3. $emit_lblock(r) — LBlock tag 315 (handle, stmts). Sequential
  ;;      emit of the stmts list per wheel `LBlock(_h, stmts) =>
  ;;      emit_body(stmts)`. Each stmt's value pushed/popped on the
  ;;      WASM operand stack; the LAST stmt's value is the block's value.
  ;;
  ;;   4. $emit_lmatch(r) — LMatch tag 321 (handle, scrut, arms). Emits
  ;;      scrutinee via $emit_lexpr, then "(local.set $scrut_tmp)"
  ;;      capturing the value, then dispatches over arms. Empty arms
  ;;      emit "(unreachable)" — the exhaustiveness-violation runtime
  ;;      trap complementing the inference-time E_PatternInexhaustive
  ;;      check. Nonempty arms with LowPat substrate populated:
  ;;      threshold-aware HB mixed-variant dispatch per SUBSTRATE.md §IX
  ;;      "the heap has one story" — `(scrut < HEAP_BASE)` discriminates
  ;;      sentinel nullary variants from heap-record fielded variants
  ;;      without ambiguity. Lands per NAMED follow-up
  ;;      Hβ.emit.lmatch-pattern-compile when LowPat substrate becomes
  ;;      structured (per Hβ.lower.lvalue-lowfn-lpat-substrate).
  ;;
  ;;   5. $emit_lregion(r) — LRegion tag 328 (handle, body). Inert seed:
  ;;      emits the body's stmts via $ec5_emit_body without region-enter/
  ;;      exit emission. Region scoping populates this arm when the W5
  ;;      arena handler-swap lands per NAMED follow-up
  ;;      Hβ.emit.memory-arena-handler.
  ;;
  ;; Eight interrogations (per Hβ-emit-substrate.md §5.1 second pass):
  ;;
  ;;   1. Graph?       Each arm reads its LowExpr's record fields via
  ;;                   $lexpr_l*_* accessors. LIf / LBlock / LMatch /
  ;;                   LReturn / LRegion all recurse into sub-LowExprs
  ;;                   via $emit_lexpr — the dispatcher introduced in
  ;;                   chunk #3 + retrofitted by chunks #4 + this chunk.
  ;;                   Per Anchor 1: ask the graph; never re-derive.
  ;;   2. Handler?     At wheel: each arm is one branch of emit_expr
  ;;                   match per src/backends/wasm.mn. At seed: direct
  ;;                   fn dispatch via $emit_lexpr's tag table.
  ;;                   @resume=OneShot at the wheel (single-pass
  ;;                   emission per LowExpr tree).
  ;;   3. Verb?        |> — each arm's body is forward flow:
  ;;                   read fields → recurse-emit sub-expr → emit
  ;;                   instruction tokens. No verb-topology in the arms
  ;;                   themselves; the verbs (`<~` LFeedback,
  ;;                   `~>` LHandleWith, etc.) emerge in chunk #7
  ;;                   emit_handler.wat.
  ;;   4. Row?         WasmOut at wheel; row-silent at seed. Side-effect
  ;;                   on $out_base/$out_pos via $emit_byte. No
  ;;                   EmitMemory effect — control arms are read-only
  ;;                   on the heap; allocation lives in chunk #3
  ;;                   (LMake* arms).
  ;;   5. Ownership?   LowExpr `r` is `ref` (read-only structural
  ;;                   traversal). $out_base buffer OWNed program-wide.
  ;;                   No transfer.
  ;;   6. Refinement?  N/A — control arms have no refinement obligations.
  ;;                   LMatch's exhaustiveness is the inference-time
  ;;                   E_PatternInexhaustive obligation; emit-time
  ;;                   `(unreachable)` is the runtime complement.
  ;;   7. Gradient?    LMatch's HB threshold-aware mixed-variant dispatch
  ;;                   IS the gradient cash-out for ADT compile — Bool
  ;;                   is not special, every nullary variant compiles to
  ;;                   sentinel + threshold-discriminate at match. Lands
  ;;                   when LowPat substrate populates per
  ;;                   Hβ.emit.lmatch-pattern-compile follow-up.
  ;;   8. Reason?      Read-only — caller's $lookup_ty preserves Reason
  ;;                   chain on LowExpr's source handle. Control arms
  ;;                   do not write Reasons.
  ;;
  ;; Forbidden patterns audited (per Hβ-emit-substrate.md §6 + project
  ;; drift modes):
  ;;
  ;;   - Drift 1 (Rust vtable):      LMatch dispatch via tag-int
  ;;                                 comparison chain (post-LowPat-
  ;;                                 substrate); NO $emit_arm_table data
  ;;                                 segment, NO closure-record-of-fn-
  ;;                                 pointers. Word "vtable" appears
  ;;                                 nowhere.
  ;;   - Drift 5 (C calling conv):   Each arm takes ONE LowExpr ref
  ;;                                 param.
  ;;   - Drift 6 (Bool special):     LMatch (when LowPat substrate
  ;;                                 populates) uses HB threshold-aware
  ;;                                 mixed-variant dispatch — every
  ;;                                 nullary ADT variant gets the SAME
  ;;                                 sentinel discipline as Bool. NO
  ;;                                 Bool-narrow branch.
  ;;   - Drift 8 (string-keyed):     Tag dispatch in $emit_lexpr via
  ;;                                 integer constants (310/314/315/321/
  ;;                                 328); NEVER `str_eq($render_lowexpr,
  ;;                                 "LMatch")`.
  ;;   - Drift 9 (deferred-by-      LMatch's nonempty-arms path is a
  ;;                  omission):    NAMED follow-up
  ;;                                 Hβ.emit.lmatch-pattern-compile —
  ;;                                 lands when Hβ.lower.lvalue-lowfn-
  ;;                                 lpat-substrate populates LowPat.
  ;;                                 The empty-arms path is fully bodied
  ;;                                 here. Drift 9 closure via explicit
  ;;                                 naming.
  ;;   - Foreign fluency:           Vocabulary stays Mentl — "block",
  ;;                                "match", "return" (in the resume-
  ;;                                substrate sense per Lock #6),
  ;;                                "region", "scrutinee". Note: per
  ;;                                SYNTAX.md line 1335 + SUBSTRATE.md §II
  ;;                                Mentl has NO imperative loop / break /
  ;;                                continue / switch / for / in
  ;;                                constructs. Iteration is `<~`
  ;;                                feedback over Iterate effect;
  ;;                                early-exit is Abort effect via
  ;;                                catch_abort handler. The control
  ;;                                family is FIVE arms — those tags do
  ;;                                not exist in the LowExpr ADT.
  ;;
  ;; Named follow-ups (per Drift 9 + Hβ-emit-substrate.md §10):
  ;;   - Hβ.emit.lexpr-dispatch-extension: chunks #6-#7 retrofit
  ;;                                       $emit_lexpr's arm table.
  ;;   - Hβ.emit.lmatch-pattern-compile:   nonempty-arms HB threshold-
  ;;                                       aware mixed-variant dispatch;
  ;;                                       lands when
  ;;                                       Hβ.lower.lvalue-lowfn-lpat-
  ;;                                       substrate populates LowPat
  ;;                                       structurally.
  ;;   - Hβ.emit.memory-arena-handler:     LRegion enter/exit emission
  ;;                                       when W5 arena handler-swap
  ;;                                       lands.

  ;; ─── Chunk-private byte-emission helpers ──────────────────────────
  ;; Inline-byte design per emit_const.wat + emit_local.wat precedent —
  ;; the [0, 4096) data region is densely packed; inline $emit_byte
  ;; sequences are substrate-honest at the seed layer.

  (func $ec5_emit_return
    ;; emits: (return)
    (call $emit_byte (i32.const 40)) (call $emit_byte (i32.const 114))
    (call $emit_byte (i32.const 101)) (call $emit_byte (i32.const 116))
    (call $emit_byte (i32.const 117)) (call $emit_byte (i32.const 114))
    (call $emit_byte (i32.const 110)) (call $emit_byte (i32.const 41)))

  (func $ec5_emit_if_open_with_result_i32
    ;; emits: (if (result i32)
    (call $emit_byte (i32.const 40)) (call $emit_byte (i32.const 105))
    (call $emit_byte (i32.const 102)) (call $emit_byte (i32.const 32))
    (call $emit_byte (i32.const 40)) (call $emit_byte (i32.const 114))
    (call $emit_byte (i32.const 101)) (call $emit_byte (i32.const 115))
    (call $emit_byte (i32.const 117)) (call $emit_byte (i32.const 108))
    (call $emit_byte (i32.const 116)) (call $emit_byte (i32.const 32))
    (call $emit_byte (i32.const 105)) (call $emit_byte (i32.const 51))
    (call $emit_byte (i32.const 50)) (call $emit_byte (i32.const 41)))

  (func $ec5_emit_then_open
    ;; emits: (then
    (call $emit_byte (i32.const 40)) (call $emit_byte (i32.const 116))
    (call $emit_byte (i32.const 104)) (call $emit_byte (i32.const 101))
    (call $emit_byte (i32.const 110)))

  (func $ec5_emit_else_open
    ;; emits: (else
    (call $emit_byte (i32.const 40)) (call $emit_byte (i32.const 101))
    (call $emit_byte (i32.const 108)) (call $emit_byte (i32.const 115))
    (call $emit_byte (i32.const 101)))

  (func $ec5_emit_local_set_scrut_tmp
    ;; emits: (local.set $scrut_tmp)
    (call $emit_byte (i32.const 40)) (call $emit_byte (i32.const 108))
    (call $emit_byte (i32.const 111)) (call $emit_byte (i32.const 99))
    (call $emit_byte (i32.const 97)) (call $emit_byte (i32.const 108))
    (call $emit_byte (i32.const 46)) (call $emit_byte (i32.const 115))
    (call $emit_byte (i32.const 101)) (call $emit_byte (i32.const 116))
    (call $emit_byte (i32.const 32)) (call $emit_byte (i32.const 36))
    (call $emit_byte (i32.const 115)) (call $emit_byte (i32.const 99))
    (call $emit_byte (i32.const 114)) (call $emit_byte (i32.const 117))
    (call $emit_byte (i32.const 116)) (call $emit_byte (i32.const 95))
    (call $emit_byte (i32.const 116)) (call $emit_byte (i32.const 109))
    (call $emit_byte (i32.const 112)) (call $emit_byte (i32.const 41)))

  ;; ─── $ec5_emit_body — sequential emit of a stmt list ──────────────
  ;; Per wheel src/backends/wasm.mn:1319 `LBlock(_h, stmts) => emit_body(
  ;; stmts)` + LIf branch emission + LRegion body emission. Each stmt's
  ;; value pushed/popped on the WASM operand stack; the LAST stmt's
  ;; value is the surrounding construct's value.
  ;;
  ;; Drift 7 refusal: stmts is ONE list ptr field (record-shaped), not
  ;; parallel slot-arrays. Drift 9 refusal: empty list emits nothing
  ;; (the surrounding construct provides its own absence handling —
  ;; LBlock empty is a value-less block; LIf empty branches violate
  ;; type discipline at inference, not emit).
  (func $ec5_emit_body (param $stmts i32)
    (local $i i32) (local $n i32)
    (local.set $n (call $len (local.get $stmts)))
    (local.set $i (i32.const 0))
    (block $done
      (loop $iter
        (br_if $done (i32.ge_u (local.get $i) (local.get $n)))
        (call $emit_lexpr
          (call $list_index (local.get $stmts) (local.get $i)))
        (local.set $i (i32.add (local.get $i) (i32.const 1)))
        (br $iter))))

  ;; ─── $emit_lreturn — LReturn tag 310 emit arm per §2.3 ─────────────
  ;; Per src/backends/wasm.mn:1220-1223. LReturn carries the resumed
  ;; value of an OneShot `resume(value)` per Hβ.lower walk_call.wat
  ;; Lock #6. WAT-level `(return)` hands the value back to the
  ;; suspended `perform` call site.
  (func $emit_lreturn (param $r i32)
    (call $emit_lexpr (call $lexpr_lreturn_x (local.get $r)))
    (call $ec5_emit_return))

  ;; ─── $emit_lif — LIf tag 314 emit arm per §2.3 ─────────────────────
  ;; Per src/backends/wasm.mn:1310-1317. Emits:
  ;;   <cond>
  ;;   (if (result i32)
  ;;     (then <then_body>)
  ;;     (else <else_body>))
  ;; Both branches are stmt lists; $ec5_emit_body iterates each.
  (func $emit_lif (param $r i32)
    (call $emit_lexpr (call $lexpr_lif_cond (local.get $r)))
    (call $ec5_emit_if_open_with_result_i32)
    (call $ec5_emit_then_open)
    (call $ec5_emit_body (call $lexpr_lif_then (local.get $r)))
    (call $emit_close)
    (call $ec5_emit_else_open)
    (call $ec5_emit_body (call $lexpr_lif_else (local.get $r)))
    (call $emit_close)
    (call $emit_close))

  ;; ─── $emit_lblock — LBlock tag 315 emit arm per §2.3 ───────────────
  ;; Per src/backends/wasm.mn:1319 `LBlock(_h, stmts) => emit_body(stmts)`.
  ;; Sequential emit of stmts list — each stmt's value pushed/popped on
  ;; the WASM operand stack; the LAST stmt's value is the block's value.
  (func $emit_lblock (param $r i32)
    (call $ec5_emit_body (call $lexpr_lblock_stmts (local.get $r))))

  ;; ─── $emit_lmatch — LMatch tag 321 emit arm per §2.3 ───────────────
  ;; Per src/backends/wasm.mn:1379-1394 + emit_match_arms at line 1792+.
  ;;
  ;; Three-shape dispatch — the H6 gradient cash-out:
  ;;   PureNullary (shape 0): every LPCon has empty sub_pats.
  ;;     Scrutinee IS the sentinel. Direct compare: scrut == tag_id.
  ;;   PureFielded (shape 1): every LPCon has non-empty sub_pats.
  ;;     Scrutinee IS a heap pointer. Load tag at offset=0, compare.
  ;;   Mixed (shape 2): both kinds present. Threshold gate at
  ;;     heap_base=4096: (scrut < 4096) → nullary cascade, else fielded.
  ;;
  ;; Bool is NOT special. True/False are sentinels 0/1. Option.None is
  ;; a sentinel. Every nullary variant compiles through the same path.
  ;; One mechanism for all ADT matching. No Drift 6.
  ;;
  ;; Per SUBSTRATE.md §IX "the heap has one story" — sentinels live in
  ;; [0, 4096); heap pointers live at [1 MiB, ∞). The threshold
  ;; comparison discriminates without ambiguity.
  (func $emit_lmatch (param $r i32)
    (local $arms i32) (local $shape i32)
    (call $emit_lexpr (call $lexpr_lmatch_scrut (local.get $r)))
    (call $ec5_emit_local_set_scrut_tmp)
    (local.set $arms (call $lexpr_lmatch_arms (local.get $r)))
    (if (i32.eqz (call $len (local.get $arms)))
      (then (call $ec_emit_unreachable))
      (else
        (local.set $shape (call $ec5_classify_arms_shape (local.get $arms)))
        (if (i32.eq (local.get $shape) (i32.const 2))
          (then (call $ec5_emit_match_arms_mixed (local.get $arms)))
          (else (call $ec5_emit_match_arms_from
                  (local.get $arms) (i32.const 0) (local.get $shape)))))))

  ;; ─── $ec5_classify_arms_shape — classify arm set shape ──────────────
  ;; Per src/backends/wasm.mn:1807-1829 classify_arms_shape.
  ;; Walk arms list. For each LPCon, check len(sub_pats):
  ;;   0 → nullary, >0 → fielded. Track accumulated shape.
  ;; Returns: 0=PureNullary, 1=PureFielded, 2=Mixed.
  ;; Non-LPCon patterns (LPWild, LPVar, LPLit) are shape-neutral.
  (func $ec5_classify_arms_shape (param $arms i32) (result i32)
    (local $i i32) (local $n i32) (local $acc i32) (local $seen i32)
    (local $arm i32) (local $pat i32) (local $arm_shape i32)
    (local.set $n (call $len (local.get $arms)))
    (local.set $acc (i32.const 1))   ;; default PureFielded
    (local.set $seen (i32.const 0))
    (local.set $i (i32.const 0))
    (block $done
      (loop $iter
        (br_if $done (i32.ge_u (local.get $i) (local.get $n)))
        (local.set $arm (call $list_index (local.get $arms) (local.get $i)))
        (local.set $pat (call $lowpat_lparm_pat (local.get $arm)))
        (if (i32.eq (call $tag_of (local.get $pat)) (i32.const 363)) ;; LPCon
          (then
            (local.set $arm_shape
              (if (result i32)
                  (i32.eqz (call $len (call $lowpat_lpcon_args (local.get $pat))))
                (then (i32.const 0))   ;; PureNullary
                (else (i32.const 1)))) ;; PureFielded
            (if (i32.eqz (local.get $seen))
              (then
                (local.set $acc (local.get $arm_shape))
                (local.set $seen (i32.const 1)))
              (else
                (if (i32.ne (local.get $acc) (local.get $arm_shape))
                  (then (local.set $acc (i32.const 2))))))))  ;; Mixed
        (local.set $i (i32.add (local.get $i) (i32.const 1)))
        (br $iter)))
    (if (result i32) (local.get $seen)
      (then (local.get $acc))
      (else (i32.const 1))))   ;; No LPCon seen → PureFielded default

  ;; ─── $ec5_emit_match_arms_from — uniform-shape arm dispatch ─────────
  ;; Per src/backends/wasm.mn:1842-1903 emit_match_arms_uniform.
  ;; Recursive: emits arms starting from index $idx.
  ;; Per-arm dispatch on LowPat tag:
  ;;   LPCon (363): load scrut (shape-dependent), compare tag_id,
  ;;     emit (if (result i32) (then ...body...) (else ...rest...)).
  ;;   LPWild (361): always-match terminal. Emit body directly.
  ;;   LPVar (360): bind scrut to name, emit body.
  ;;   LPLit (362): scalar equality check on scrut value.
  ;;   LPTuple/LPList/LPRecord/LPAlt/LPAs: skip (NAMED follow-up).
  (func $ec5_emit_match_arms_from
        (param $arms i32) (param $idx i32) (param $shape i32)
    (local $arm i32) (local $pat i32) (local $body i32)
    (local $ptag i32) (local $sub_pats i32)
    ;; Base case: no more arms → unreachable (exhaustiveness trap).
    (if (i32.ge_u (local.get $idx) (call $len (local.get $arms)))
      (then (call $ec_emit_unreachable) (return)))
    (local.set $arm (call $list_index (local.get $arms) (local.get $idx)))
    (local.set $pat (call $lowpat_lparm_pat (local.get $arm)))
    (local.set $body (call $lowpat_lparm_body (local.get $arm)))
    (local.set $ptag (call $tag_of (local.get $pat)))

    ;; ── LPCon (363) — constructor pattern ──
    (if (i32.eq (local.get $ptag) (i32.const 363))
      (then
        (local.set $sub_pats (call $lowpat_lpcon_args (local.get $pat)))
        ;; Load scrutinee for comparison.
        (call $ec5_emit_local_get_scrut_tmp)
        ;; PureFielded (shape 1): load tag at offset=0 from heap record.
        (if (i32.eq (local.get $shape) (i32.const 1))
          (then (call $el_emit_i32_load_offset (i32.const 0))))
        ;; Compare tag.
        (call $emit_i32_const (call $lowpat_lpcon_tag_id (local.get $pat)))
        (call $ec5_emit_i32_eq)
        ;; (if (result i32) (then ...body...) (else ...rest...))
        (call $ec5_emit_if_open_with_result_i32)
        (call $ec5_emit_then_open)
        ;; Bind fields if fielded.
        (if (i32.eq (local.get $shape) (i32.const 1))
          (then (call $ec5_emit_pat_field_binds
                  (local.get $sub_pats) (i32.const 0))))
        (call $emit_lexpr (local.get $body))
        (call $emit_close)   ;; close then
        (call $ec5_emit_else_open)
        ;; Recurse on rest.
        (call $ec5_emit_match_arms_from
          (local.get $arms) (i32.add (local.get $idx) (i32.const 1))
          (local.get $shape))
        (call $emit_close)   ;; close else
        (call $emit_close)   ;; close if
        (return)))

    ;; ── LPWild (361) — always-match terminal ──
    (if (i32.eq (local.get $ptag) (i32.const 361))
      (then
        (call $emit_lexpr (local.get $body))
        (return)))

    ;; ── LPVar (360) — bind scrut to name ──
    (if (i32.eq (local.get $ptag) (i32.const 360))
      (then
        (call $ec5_emit_local_get_scrut_tmp)
        (call $ec_emit_local_set_dollar
          (call $lowpat_lpvar_name (local.get $pat)))
        (call $emit_lexpr (local.get $body))
        (return)))

    ;; ── LPLit (362) — scalar equality ──
    (if (i32.eq (local.get $ptag) (i32.const 362))
      (then
        (call $ec5_emit_local_get_scrut_tmp)
        (call $emit_i32_const (call $lowpat_lplit_value (local.get $pat)))
        (call $ec5_emit_i32_eq)
        (call $ec5_emit_if_open_with_result_i32)
        (call $ec5_emit_then_open)
        (call $emit_lexpr (local.get $body))
        (call $emit_close)
        (call $ec5_emit_else_open)
        (call $ec5_emit_match_arms_from
          (local.get $arms) (i32.add (local.get $idx) (i32.const 1))
          (local.get $shape))
        (call $emit_close)
        (call $emit_close)
        (return)))

    ;; ── LPTuple/LPList/LPRecord/LPAlt/LPAs — skip (NAMED follow-up) ──
    (call $ec5_emit_match_arms_from
      (local.get $arms) (i32.add (local.get $idx) (i32.const 1))
      (local.get $shape)))

  ;; ─── $ec5_emit_match_arms_mixed — threshold gate dispatch ───────────
  ;; Per src/backends/wasm.mn:1909-1922 emit_match_arms_mixed.
  ;; Emits:
  ;;   (local.get $scrut_tmp)(i32.const 4096)(i32.lt_u)
  ;;   (if (result i32)
  ;;     (then <nullary_cascade>)
  ;;     (else <fielded_cascade>))
  ;; Each cascade filters arms by shape, keeping wildcards/vars/lits
  ;; in both (they always-match irrespective of shape).
  (func $ec5_emit_match_arms_mixed (param $arms i32)
    (call $ec5_emit_local_get_scrut_tmp)
    (call $emit_i32_const (i32.const 4096))
    (call $ec5_emit_i32_lt_u)
    (call $ec5_emit_if_open_with_result_i32)
    (call $ec5_emit_then_open)
    ;; Nullary cascade — filter to PureNullary LPCon + always-match.
    (call $ec5_emit_match_arms_filtered_from
      (local.get $arms) (i32.const 0) (i32.const 0))
    (call $emit_close)   ;; close then
    (call $ec5_emit_else_open)
    ;; Fielded cascade — filter to PureFielded LPCon + always-match.
    (call $ec5_emit_match_arms_filtered_from
      (local.get $arms) (i32.const 0) (i32.const 1))
    (call $emit_close)   ;; close else
    (call $emit_close))  ;; close if

  ;; ─── $ec5_emit_match_arms_filtered_from — shape-filtered dispatch ───
  ;; Called from mixed-dispatch. Skips LPCon arms whose shape doesn't
  ;; match $want_shape; always processes LPWild/LPVar/LPLit.
  ;; $want_shape: 0=PureNullary, 1=PureFielded.
  (func $ec5_emit_match_arms_filtered_from
        (param $arms i32) (param $idx i32) (param $want_shape i32)
    (local $arm i32) (local $pat i32) (local $ptag i32)
    (local $arm_shape i32)
    ;; Base case: no more arms → unreachable.
    (if (i32.ge_u (local.get $idx) (call $len (local.get $arms)))
      (then (call $ec_emit_unreachable) (return)))
    (local.set $arm (call $list_index (local.get $arms) (local.get $idx)))
    (local.set $pat (call $lowpat_lparm_pat (local.get $arm)))
    (local.set $ptag (call $tag_of (local.get $pat)))
    ;; LPCon: check shape match.
    (if (i32.eq (local.get $ptag) (i32.const 363))
      (then
        (local.set $arm_shape
          (if (result i32)
              (i32.eqz (call $len (call $lowpat_lpcon_args (local.get $pat))))
            (then (i32.const 0))
            (else (i32.const 1))))
        (if (i32.ne (local.get $arm_shape) (local.get $want_shape))
          (then
            ;; Shape mismatch — skip this arm.
            (call $ec5_emit_match_arms_filtered_from
              (local.get $arms) (i32.add (local.get $idx) (i32.const 1))
              (local.get $want_shape))
            (return)))))
    ;; Shape matches, or non-LPCon (always process). Delegate to
    ;; uniform dispatch with the want_shape.
    (call $ec5_emit_match_arms_from
      (local.get $arms) (local.get $idx) (local.get $want_shape)))

  ;; ─── $ec5_emit_pat_field_binds — per-field sub-pattern binding ──────
  ;; Per src/backends/wasm.mn:1987-2009 emit_pat_field_binds.
  ;; For each LPVar sub-pattern at index i, emits:
  ;;   (local.get $scrut_tmp)(i32.load offset=4+4*i)(local.set $<name>)
  ;; LPWild sub-patterns bind nothing. Nested constructors skip (TODO).
  (func $ec5_emit_pat_field_binds (param $sub_pats i32) (param $i i32)
    (local $n i32) (local $p i32) (local $ptag i32)
    (local.set $n (call $len (local.get $sub_pats)))
    (block $done
      (loop $iter
        (br_if $done (i32.ge_u (local.get $i) (local.get $n)))
        (local.set $p (call $list_index (local.get $sub_pats) (local.get $i)))
        (local.set $ptag (call $tag_of (local.get $p)))
        ;; LPVar (360): bind from field offset.
        (if (i32.eq (local.get $ptag) (i32.const 360))
          (then
            (call $ec5_emit_local_get_scrut_tmp)
            (call $el_emit_i32_load_offset
              (i32.add (i32.const 4)
                       (i32.mul (i32.const 4) (local.get $i))))
            (call $ec_emit_local_set_dollar
              (call $lowpat_lpvar_name (local.get $p)))))
        ;; LPWild (361), others: skip.
        (local.set $i (i32.add (local.get $i) (i32.const 1)))
        (br $iter))))

  ;; ─── Byte-emission helpers for match dispatch ───────────────────────

  (func $ec5_emit_local_get_scrut_tmp
    ;; emits: (local.get $scrut_tmp)
    (call $emit_byte (i32.const 40)) (call $emit_byte (i32.const 108))
    (call $emit_byte (i32.const 111)) (call $emit_byte (i32.const 99))
    (call $emit_byte (i32.const 97)) (call $emit_byte (i32.const 108))
    (call $emit_byte (i32.const 46)) (call $emit_byte (i32.const 103))
    (call $emit_byte (i32.const 101)) (call $emit_byte (i32.const 116))
    (call $emit_byte (i32.const 32)) (call $emit_byte (i32.const 36))
    (call $emit_byte (i32.const 115)) (call $emit_byte (i32.const 99))
    (call $emit_byte (i32.const 114)) (call $emit_byte (i32.const 117))
    (call $emit_byte (i32.const 116)) (call $emit_byte (i32.const 95))
    (call $emit_byte (i32.const 116)) (call $emit_byte (i32.const 109))
    (call $emit_byte (i32.const 112)) (call $emit_byte (i32.const 41)))

  (func $ec5_emit_i32_eq
    ;; emits: (i32.eq)
    (call $emit_byte (i32.const 40)) (call $emit_byte (i32.const 105))
    (call $emit_byte (i32.const 51)) (call $emit_byte (i32.const 50))
    (call $emit_byte (i32.const 46)) (call $emit_byte (i32.const 101))
    (call $emit_byte (i32.const 113)) (call $emit_byte (i32.const 41)))

  (func $ec5_emit_i32_lt_u
    ;; emits: (i32.lt_u)
    (call $emit_byte (i32.const 40)) (call $emit_byte (i32.const 105))
    (call $emit_byte (i32.const 51)) (call $emit_byte (i32.const 50))
    (call $emit_byte (i32.const 46)) (call $emit_byte (i32.const 108))
    (call $emit_byte (i32.const 116)) (call $emit_byte (i32.const 95))
    (call $emit_byte (i32.const 117)) (call $emit_byte (i32.const 41)))

  ;; ─── $emit_lregion — LRegion tag 328 emit arm per §2.3 ─────────────
  ;; Per src/backends/wasm.mn:1514+. Inert seed: emits the body's stmts
  ;; via $ec5_emit_body without region-enter/exit emission. The W5
  ;; arena handler-swap populates region-enter/exit emission per NAMED
  ;; follow-up Hβ.emit.memory-arena-handler — at that point this arm
  ;; surrounds the body emission with arena_ptr snapshot/restore WAT.
  (func $emit_lregion (param $r i32)
    (call $ec5_emit_body (call $lexpr_lregion_body (local.get $r))))
