  ;; ═══ classify.wat — Hβ.lower handler-elimination strategy classifier (Tier 7) ═══
  ;; Hβ.lower cascade chunk #5 of 11 per Hβ-lower-substrate.md §12.3 dep order.
  ;;
  ;; What this chunk IS (per Hβ-lower-substrate.md §3.1 lines 304-348):
  ;;   The seed's projection of spec 05 §Handler elimination strategy
  ;;   classification. Reads TCont(_, discipline) via $lookup_ty +
  ;;   $resume_discipline_of (chunk #2 lookup.wat) and returns one of
  ;;   three strategy codes the chunks #7/#8 walk_call/walk_handle
  ;;   consume to choose lowering shape:
  ;;
  ;;     0 = TailResumptive  →  direct (call $h_op ...) — zero indirection
  ;;                            per H1 evidence reification + spec 05 §Handler
  ;;                            elimination "OneShot-typed arms become direct
  ;;                            call". The 85% case in self-hosted Inka
  ;;                            (per spec 05 + H1 §1.2).
  ;;     1 = Linear          →  state machine — per-perform-site state ordinal +
  ;;                            saved locals; same shape as MultiShot but with
  ;;                            at-most-one-resume invariant. Per spec 05 §Handler
  ;;                            elimination + Hβ-lower-substrate.md §3 table.
  ;;     2 = MultiShot       →  heap-captured continuation per H7 — $alloc_continuation
  ;;                            + cont.wat. Per H7 §1.2 + Hβ-lower-substrate.md §3
  ;;                            line 307 + LMakeContinuation arity-6 at lexpr.wat
  ;;                            tag 312. Mentl's hot path per insight #11.
  ;;
  ;; Strategy-code enum (sentinel < HEAP_BASE = 4096):
  ;;     STRATEGY_TAIL_RESUMPTIVE = 0
  ;;     STRATEGY_LINEAR          = 1
  ;;     STRATEGY_MULTISHOT       = 2
  ;;
  ;; Vocabulary lock (per Hβ-lower-substrate.md §6.2 + spec 05): the
  ;; strategy names are TailResumptive / Linear / MultiShot. NEVER
  ;; "promise-like" / "async" / "future" (foreign fluency JS async/await).
  ;; NEVER "call/cc" / "undelimited" (foreign fluency Scheme). NEVER
  ;; "calling convention enum" (foreign fluency LLVM/GHC). The
  ;; continuations are DELIMITED — scoped to the handler-install
  ;; boundary per H7 §3.2.
  ;;
  ;; Implements: Hβ-lower-substrate.md §3.1 lines 304-348 — $classify_handler
  ;;             4-arm dispatch on TCont.discipline (250/251/252) with
  ;;             $is_tail_resumptive subdiscrimination for OneShot;
  ;;             §11 lock — $either_strategy returns Linear (1) per the
  ;;             Either-discipline seed default ("Linear (1) when handler
  ;;             body's static check can't classify TailResumptive. Per
  ;;             src/lower.nx classify_handler precedent" — line 922).
  ;; Exports:    $classify_handler,
  ;;             $is_tail_resumptive,
  ;;             $either_strategy
  ;; Uses:       $lookup_ty (lower/lookup.wat — chunk #2),
  ;;             $resume_discipline_of (lower/lookup.wat — chunk #2),
  ;;             $ty_tag (infer/ty.wat — TCONT_TAG=112 precondition guard)
  ;; Test:       bootstrap/test/lower/classify_oneshot.wat,
  ;;             bootstrap/test/lower/classify_multishot.wat,
  ;;             bootstrap/test/lower/classify_either.wat
  ;;
  ;; ═══ EIGHT INTERROGATIONS (per Hβ-lower-substrate.md §5.2 projected
  ;;                            onto classify.wat) ═══════════════════════
  ;;
  ;; 1. Graph?       $classify_handler reads through $lookup_ty(handler_handle)
  ;;                 — which is $graph_chase + NodeKind tag dispatch (chunk #2).
  ;;                 The graph IS the substrate; classify is a lens that reads
  ;;                 the bound TCont.discipline field via $resume_discipline_of.
  ;;                 No graph mutation; row at the wheel is GraphRead + LookupTy
  ;;                 (no GraphWrite — structural isolation by effect-row
  ;;                 subsumption per spec 05 §The LookupTy effect).
  ;;
  ;; 2. Handler?     At the wheel: classification is part of LookupTy + LowerCtx
  ;;                 effect composition (@resume=OneShot — single call, scalar
  ;;                 return). At the seed: direct dispatch on TCont.discipline
  ;;                 sentinel via 3-arm if-chain over (250 / 251 / 252) +
  ;;                 explicit (unreachable) trap on non-TCont input or unknown
  ;;                 discipline (compiler-internal bug per spec 05 invariant).
  ;;                 NO vtable. NO dispatch_table. NO $op_table data segment.
  ;;                 NO _lookup_handler_for_op function.
  ;;
  ;; 3. Verb?        N/A. Verb projection (~> / <~) lands at chunks #7/#8 as
  ;;                 LHandleWith (lexpr.wat tag 329) / LFeedback (lexpr.wat
  ;;                 tag 330). Classify is verb-silent.
  ;;
  ;; 4. Row?         N/A. The row-ground gate ($row_is_ground / $monomorphic_at
  ;;                 at lookup.wat) is a sibling concern at chunk #7 walk_call's
  ;;                 monomorphic-vs-polymorphic dispatch decision. Per
  ;;                 Hβ-lower-substrate.md §3.2 last paragraph: "the 95/5 split
  ;;                 is about MONOMORPHIC vs POLYMORPHIC dispatch, NOT about
  ;;                 OneShot vs MultiShot resume discipline" — the two
  ;;                 questions are orthogonal.
  ;;
  ;; 5. Ownership?   Read-only on Ty + GNode. No allocation; no `own` transfer.
  ;;                 Inputs: handler_handle (i32 value). Outputs: strategy code
  ;;                 i32 sentinel < HEAP_BASE. The discipline value read via
  ;;                 $resume_discipline_of is a sentinel (250/251/252); same
  ;;                 nullary discipline as TInt/TFloat/TString/TUnit
  ;;                 (ty.wat:100-103) — no allocation, no transfer.
  ;;
  ;; 6. Refinement?  N/A at the seed. TRefined transparent — would never wrap
  ;;                 a TCont (refinement on a continuation type is ill-formed);
  ;;                 classify's precondition guards on ($ty_tag == 112) which
  ;;                 traps via (unreachable) on any wrapper type.
  ;;
  ;; 7. Gradient?    $classify_handler IS the gradient measurement for handler
  ;;                 dispatch. Each strategy choice cashes one inference-earned
  ;;                 win:
  ;;                   - TailResumptive (0) collapses to direct (call $h_op ...)
  ;;                     zero-indirection per H1 evidence reification;
  ;;                   - Linear (1) avoids heap continuation alloc — state
  ;;                     machine via per-perform-site state ordinal;
  ;;                   - MultiShot (2) opens H7's heap-captured-continuation
  ;;                     path — full first-class continuation for Mentl's
  ;;                     speculative inference per insight #11.
  ;;                 The classification IS the cash-out: each handler arm whose
  ;;                 type is proven OneShot at infer time becomes a direct call
  ;;                 at lower time; that's one row-inference win materialized
  ;;                 as compile-time capability.
  ;;
  ;; 8. Reason?      Read-only. The TCont's parent GNode (the handler_handle
  ;;                 chase target) carries the Reason chain via $gnode_reason
  ;;                 (graph.wat); classify.wat does not surface it (downstream
  ;;                 emit_diag.wat uses Reason when building diagnostics for
  ;;                 handler-uninstallable errors per §11 boundary lock —
  ;;                 those errors live in infer-owned emit_diag, not
  ;;                 lower-owned). This chunk is Reason-silent.
  ;;
  ;; ═══ FORBIDDEN PATTERNS AUDIT (per Hβ-lower-substrate.md §6.2 +
  ;;                                project-wide drift modes 1-9) ════════
  ;;
  ;; - Drift 1 (Rust vtable):              CRITICAL per walkthrough §6.2
  ;;                                       lines 619-626. The seed's emit
  ;;                                       must NOT generate a dispatch_table
  ;;                                       for handler ops. Per H1 evidence
  ;;                                       reification: closure record's
  ;;                                       fn_index FIELD + call_indirect
  ;;                                       at emit time. Three named drift
  ;;                                       signals to refuse:
  ;;                                         - "dispatch_table" / "dispatch
  ;;                                           table" in any chunk comment
  ;;                                         - any data segment named
  ;;                                           $op_table or $handler_dispatch
  ;;                                         - any function returning i32
  ;;                                           named _lookup_handler_for_op
  ;;                                       This chunk's classifier is a
  ;;                                       3-arm (if (i32.eq disc 250/251/252))
  ;;                                       chain — direct sentinel comparison;
  ;;                                       no table indirection.
  ;;
  ;; - Drift 4 (Haskell monad transformer): No ClassifyM. Single i32 input
  ;;                                       (handler_handle), single i32 output
  ;;                                       (strategy code). Direct.
  ;;
  ;; - Drift 5 (C calling convention):     Per H7 §1.2: ONE $cont_ptr parameter
  ;;                                       on resume_fn. N/A at this chunk —
  ;;                                       $classify_handler takes ONE i32,
  ;;                                       returns ONE i32. The discipline
  ;;                                       applies downstream when chunk #8's
  ;;                                       LMakeContinuation lands.
  ;;
  ;; - Drift 6 (primitive-special-case):   ResumeDiscipline 250/251/252 are
  ;;                                       nullary sentinels — same compilation
  ;;                                       discipline as TInt/TFloat/TString/
  ;;                                       TUnit at ty.wat:100-103 (per HB
  ;;                                       anchor). NO "OneShot is special
  ;;                                       because it's tail" carveout.
  ;;
  ;; - Drift 8 (string-keyed):             Tag-int dispatch only —
  ;;                                       (i32.eq disc 250), NOT
  ;;                                       (if str_eq(disc_name, "OneShot")).
  ;;                                       Strategy codes are i32 sentinels
  ;;                                       0/1/2, NOT strings at the dispatch
  ;;                                       surface.
  ;;
  ;; - Drift 9 (deferred-by-omission):     All three exports land FULLY BODIED
  ;;                                       this commit. $classify_handler
  ;;                                       complete 4-arm dispatch.
  ;;                                       $is_tail_resumptive returns
  ;;                                       conservative Linear (1) — bodied
  ;;                                       with explicit reasoning — NOT a
  ;;                                       stub. The structural body-walk
  ;;                                       enrichment is named follow-up
  ;;                                       Hβ.lower.tail-resumptive-discrimination
  ;;                                       (per the wheel src/lower.nx 1284-line
  ;;                                       inventory: the wheel itself does
  ;;                                       NOT yet implement TailResumptive
  ;;                                       discrimination — handler arms lower
  ;;                                       via lower_handler_arms_as_decls to
  ;;                                       LDeclareFn entries; the seed's
  ;;                                       Linear default matches the wheel's
  ;;                                       current behavior per Anchor 4
  ;;                                       "build the wheel; never wrap the
  ;;                                       axle"). $either_strategy returns
  ;;                                       Linear (1) per §11 lock; same
  ;;                                       discipline.
  ;;
  ;; - Foreign fluency — JS async/await:   NEVER "promise-like" / "async" /
  ;;                                       "future". Vocabulary is
  ;;                                       TailResumptive / Linear / MultiShot
  ;;                                       per spec 05.
  ;;
  ;; - Foreign fluency — Scheme call/cc:   Continuations here are DELIMITED
  ;;                                       (scoped to handler-install boundary),
  ;;                                       NOT undelimited. Per H7 §3.2.
  ;;
  ;; - Foreign fluency — backend enums:    Strategy codes 0/1/2 are NOT a
  ;;                                       generic "calling convention" enum
  ;;                                       (LLVM/GHC). Vocabulary stays Inka:
  ;;                                       TailResumptive / Linear / MultiShot
  ;;                                       per spec 05 §Handler elimination.
  ;;
  ;; Tag region: no new tags claimed. Composes on lookup.wat's
  ;; $resume_discipline_of (which composes on ty.wat:410-411
  ;; $ty_tcont_discipline) + ty.wat 250/251/252 ResumeDiscipline sentinels
  ;; + 112 TCONT_TAG. Strategy codes 0/1/2 are FUNCTION RETURNS, never
  ;; stored as record tags.
  ;;
  ;; Named follow-ups (per Drift 9 + Hβ-lower-substrate.md §11):
  ;;
  ;;   - Hβ.lower.tail-resumptive-discrimination:
  ;;                              $is_tail_resumptive currently returns
  ;;                              conservative Linear (1) for all OneShot
  ;;                              handler arms. Future enrichment walks the
  ;;                              handler arm body's LowExpr tree post-lower
  ;;                              + checks every ResumeExpr is in tail
  ;;                              position. When tail-position invariant
  ;;                              holds, returns 0 (TailResumptive); else
  ;;                              stays 1 (Linear). Lands when:
  ;;                                (a) chunk #8 walk_handle.wat has lowered
  ;;                                    handler arm bodies to LowExpr trees;
  ;;                                (b) the wheel src/lower.nx grows the
  ;;                                    canonical structural-body-walk
  ;;                                    classifier per Anchor 4 (the seed
  ;;                                    follows the wheel; the wheel hasn't
  ;;                                    grown this substrate yet — wheel
  ;;                                    inventory full 1284 lines: zero
  ;;                                    classify_handler/is_tail_resumptive
  ;;                                    function bodies; lower_handler_arms_as_decls
  ;;                                    lowers ALL arms to LDeclareFn —
  ;;                                    Linear by structure).
  ;;
  ;;   - Hβ.lower.either-install-negotiation:
  ;;                              $either_strategy currently returns Linear
  ;;                              (1) per §11 walkthrough lock (line 922 +
  ;;                              line 950). Future enrichment performs
  ;;                              install-time negotiation between
  ;;                              TailResumptive (0) and Linear (1) based on
  ;;                              the handler-install context's expected
  ;;                              behavior. Lands when handler-install
  ;;                              substrate grows past simple resume-on-arm
  ;;                              (post-Wave-2.E.lower; potentially
  ;;                              post-L1).
  ;;
  ;;   - Hβ.lower.classify-trap-testing:
  ;;                              The (unreachable) traps for non-TCont input
  ;;                              and unknown discipline are not currently
  ;;                              trace-harness-covered (the harness shell
  ;;                              expects exit 0 / exit 1 via $wasi_proc_exit;
  ;;                              wasm trap aborts process out-of-band). Lands
  ;;                              when harness shell grows trap-expected mode.

  ;; ─── $classify_handler — the strategy-code dispatcher ─────────────
  ;; Per Hβ-lower-substrate.md §3.1 lines 309-342. Reads the handler's
  ;; TCont type via $lookup_ty + extracts the discipline sentinel via
  ;; $resume_discipline_of (chunk #2 lookup.wat). Three-arm dispatch
  ;; on the discipline (250 OneShot / 251 MultiShot / 252 Either)
  ;; returning the strategy code; (unreachable) on non-TCont input
  ;; (compiler-internal bug — caller passed a non-handler handle) or
  ;; unknown discipline sentinel (compiler-internal bug — ResumeDiscipline
  ;; ADT extended without retrofitting this dispatcher).
  ;;
  ;; Dispatch order matches expected frequency per spec 05 + H1 + H7:
  ;; OneShot first (>85% case in self-hosted Inka per spec 05 §Handler
  ;; elimination); MultiShot second (Mentl hot path per insight #11);
  ;; Either third (rare; install-time negotiation).
  (func $classify_handler (export "classify_handler")
                            (param $handler_handle i32)
                            (result i32)
    (local $ty i32)
    (local $disc i32)
    (local.set $ty (call $lookup_ty (local.get $handler_handle)))
    ;; Precondition guard: $ty_tag == 112 (TCONT_TAG). Calling
    ;; $classify_handler on a non-TCont handle is a compiler-internal
    ;; bug. Mirrors $resume_discipline_of's same-precondition discipline
    ;; (lookup.wat) + spec 05 invariant 2.
    (if (i32.ne (call $ty_tag (local.get $ty)) (i32.const 112))
      (then (unreachable)))
    (local.set $disc (call $resume_discipline_of (local.get $ty)))
    ;; OneShot — discriminate TailResumptive (0) vs Linear (1) by
    ;; structural body check. Per the conservative seed default +
    ;; named follow-up Hβ.lower.tail-resumptive-discrimination,
    ;; $is_tail_resumptive returns 1 (Linear) unconditionally for V1.
    (if (i32.eq (local.get $disc) (i32.const 250))
      (then (return (call $is_tail_resumptive (local.get $handler_handle)))))
    ;; MultiShot — heap-captured continuation per H7. LMakeContinuation
    ;; arity-6 at lexpr.wat tag 312; cont.wat owns the runtime alloc.
    (if (i32.eq (local.get $disc) (i32.const 251))
      (then (return (i32.const 2))))
    ;; Either — install-time negotiation; seed default Linear (1) per
    ;; Hβ-lower-substrate.md §11 line 922 + named follow-up
    ;; Hβ.lower.either-install-negotiation.
    (if (i32.eq (local.get $disc) (i32.const 252))
      (then (return (call $either_strategy (local.get $handler_handle)))))
    ;; Unknown ResumeDiscipline sentinel — compiler-internal bug
    ;; (ADT extended at ty.wat without retrofitting this dispatcher).
    (unreachable))

  ;; ─── $is_tail_resumptive — OneShot subdiscriminator (seed: Linear) ─
  ;; Per Hβ-lower-substrate.md §3.1 lines 344-348 + §11 named follow-up
  ;; Hβ.lower.tail-resumptive-discrimination.
  ;;
  ;; CONSERVATIVE SEED DEFAULT: returns 1 (Linear) unconditionally for V1.
  ;;
  ;; The structural body-walk that discriminates TailResumptive (0) vs
  ;; Linear (1) — checking every ResumeExpr in the handler arm body is
  ;; in tail position — is named-follow-up substrate. Reasoning:
  ;;
  ;;   1. The wheel src/lower.nx (full 1284-line inventory) does NOT
  ;;      yet implement TailResumptive discrimination. The wheel's
  ;;      lower_handler_arms_as_decls lowers ALL handler arms via the
  ;;      same path: LDeclareFn entries at module level + emit-time
  ;;      fn_idx lookup. That IS the Linear shape. The seed returning 1
  ;;      (Linear) for OneShot defaults to wheel parity per Anchor 4.
  ;;
  ;;   2. Dep-order surfacing: the structural body walk needs handler
  ;;      arm bodies as LowExpr trees BUT the arm bodies themselves
  ;;      are not lowered until walk_handle.wat (chunk #8). classify.wat
  ;;      lands at #5 — BEFORE walk_handle.wat. That substrate is its
  ;;      own peer handle, not a chunk-#5 sub-concern.
  ;;
  ;;   3. Drift-9 closure: the deferred work is named, not absorbed.
  ;;
  ;; The function exists at the named symbol, returns a defensible value
  ;; matching the wheel's current behavior, and Drift-1 vtable refusal +
  ;; spec-05-invariant trap shape are preserved.
  (func $is_tail_resumptive (export "is_tail_resumptive")
                              (param $handler_handle i32)
                              (result i32)
    ;; Conservative seed default — Linear. Future enrichment per named
    ;; follow-up Hβ.lower.tail-resumptive-discrimination.
    (i32.const 1))

  ;; ─── $either_strategy — Either-discipline strategy chooser ────────
  ;; Per Hβ-lower-substrate.md §11 line 922 + line 950 walkthrough lock:
  ;; "Linear (1) when handler body's static check can't classify
  ;; TailResumptive. Per src/lower.nx classify_handler precedent."
  ;;
  ;; Seed default: returns 1 (Linear) unconditionally. Future enrichment
  ;; under named follow-up Hβ.lower.either-install-negotiation.
  ;;
  ;; The handler_handle parameter is reserved for the future negotiation
  ;; signature; the seed's body does not consult it (yet — preserved at
  ;; the export shape so future enrichment doesn't break callers).
  (func $either_strategy (export "either_strategy")
                          (param $handler_handle i32)
                          (result i32)
    ;; Seed default — Linear. See §11 walkthrough lock + named follow-up.
    (i32.const 1))
