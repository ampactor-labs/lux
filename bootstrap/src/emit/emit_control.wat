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
  ;; src/backends/wasm.nx:1220-1223 + 1310-1319 + 1379-1394 + 1514+):
  ;;
  ;;   1. $emit_lreturn(r) — LReturn tag 310 (handle, x). Emits the inner
  ;;      LowExpr's value via $emit_lexpr, then "(return)" — the WASM
  ;;      control-flow primitive that hands the value back to the
  ;;      suspended `perform` site. NOT an imperative-`return` arm: Inka
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
  ;;                   match per src/backends/wasm.nx. At seed: direct
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
  ;;   - Foreign fluency:           Vocabulary stays Inka — "block",
  ;;                                "match", "return" (in the resume-
  ;;                                substrate sense per Lock #6),
  ;;                                "region", "scrutinee". Note: per
  ;;                                SYNTAX.md line 1335 + SUBSTRATE.md §II
  ;;                                Inka has NO imperative loop / break /
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
  ;; Per wheel src/backends/wasm.nx:1319 `LBlock(_h, stmts) => emit_body(
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
  ;; Per src/backends/wasm.nx:1220-1223. LReturn carries the resumed
  ;; value of an OneShot `resume(value)` per Hβ.lower walk_call.wat
  ;; Lock #6. WAT-level `(return)` hands the value back to the
  ;; suspended `perform` call site.
  (func $emit_lreturn (param $r i32)
    (call $emit_lexpr (call $lexpr_lreturn_x (local.get $r)))
    (call $ec5_emit_return))

  ;; ─── $emit_lif — LIf tag 314 emit arm per §2.3 ─────────────────────
  ;; Per src/backends/wasm.nx:1310-1317. Emits:
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
  ;; Per src/backends/wasm.nx:1319 `LBlock(_h, stmts) => emit_body(stmts)`.
  ;; Sequential emit of stmts list — each stmt's value pushed/popped on
  ;; the WASM operand stack; the LAST stmt's value is the block's value.
  (func $emit_lblock (param $r i32)
    (call $ec5_emit_body (call $lexpr_lblock_stmts (local.get $r))))

  ;; ─── $emit_lmatch — LMatch tag 321 emit arm per §2.3 ───────────────
  ;; Per src/backends/wasm.nx:1379-1394 + emit_match_arms at line 1815+.
  ;; Empty arms emit "(unreachable)" — the exhaustiveness-violation
  ;; runtime trap complementing the inference-time E_PatternInexhaustive
  ;; check (SYNTAX.md "Exhaustiveness" §). Nonempty arms invoke the HB
  ;; threshold-aware mixed-variant dispatch which depends on LowPat
  ;; substrate; lands per NAMED follow-up Hβ.emit.lmatch-pattern-compile
  ;; when Hβ.lower.lvalue-lowfn-lpat-substrate populates LowPat.
  (func $emit_lmatch (param $r i32)
    (call $emit_lexpr (call $lexpr_lmatch_scrut (local.get $r)))
    (call $ec5_emit_local_set_scrut_tmp)
    (call $ec_emit_unreachable))

  ;; ─── $emit_lregion — LRegion tag 328 emit arm per §2.3 ─────────────
  ;; Per src/backends/wasm.nx:1514+. Inert seed: emits the body's stmts
  ;; via $ec5_emit_body without region-enter/exit emission. The W5
  ;; arena handler-swap populates region-enter/exit emission per NAMED
  ;; follow-up Hβ.emit.memory-arena-handler — at that point this arm
  ;; surrounds the body emission with arena_ptr snapshot/restore WAT.
  (func $emit_lregion (param $r i32)
    (call $ec5_emit_body (call $lexpr_lregion_body (local.get $r))))
