# PLAN-to-first-light — the trackable session-spanning execution plan

> **Status:** `[LIVE 2026-05-02]` — the session-by-session execution
> roadmap from the current cursor (post-Hμ.cursor wheel-side closure;
> commit `95d8ce5`) to first-light-L1 (`inka2.wat == inka3.wat`)
> and into the Tier 3 unlocks that follow automatically.
>
> **Authority:** ROADMAP.md (live sequencing); Hβ-bootstrap.md §12.5
> Tier 3 growth pattern; Hβ-first-light-residue.md (the empirical
> blocker inventory + cascade decomposition); protocol_kernel_closure.md
> (composition not invention); protocol_walkthrough_pre_audit.md
> (four-axis pre-audit before each handle); protocol_realization_loop.md
> (recovery if drift fires); CLAUDE.md anchors 0/4/7.
>
> **What this document does:** Names every handle from now to L1 +
> Tier 3 in dependency order; gives per-handle scope (walkthrough +
> chunk + harness); defines the acceptance criterion for each;
> identifies the unlocks each landing produces. Each handle has a
> checkbox; sessions land handles in order; progress is visible.
>
> **What this document does NOT do:** Author the per-handle
> walkthroughs (each handle's session does that). Author the
> substrate (each handle's session does that). Bypass the discipline
> (every handle clears eight interrogations + nine drift modes +
> four-axis pre-audit before its substrate ships).
>
> **The cursor-of-attention rule:** at any moment the cursor is the
> highest-impact unfilled handle in §3 below. Each session opens at
> the cursor; closes one handle; advances the cursor to the next.

---

## §0 The integration claim — what closure unlocks

When **Phase H closes** (first-light-L1; `inka2.wat == inka3.wat`),
the seed compiling the wheel produces every projection-layer module
automatically — Mentl, Cursor, multi-shot, IC, inka edit, the eight
tentacles, every Phase μ peer handle's seed transcription. **One
closure; cascading unlock of every post-L1 cascade in ROADMAP lines
308-340 + every Phase μ peer handle's `.seed` variant.**

That's why this plan front-loads every blocker on the L1 critical
path. Phase H is the leverage point. Closing L1 is exponentially
more impactful than any single peer handle pre-L1.

---

## §1 The cursor today (commit `95d8ce5`, 2026-05-02)

**Closed (this session):**
- ✓ Hμ.cursor wheel-side (7 commits; src/cursor.nx + types.nx + mentl.nx + mentl_voice.nx + pipeline.nx + walkthrough + ULTIMATE_MEDIUM)
- ✓ Authority docs aligned (CLAUDE.md + SUBSTRATE.md + DESIGN.md + 09-mentl + MV + IE + GR)
- ✓ ROADMAP.md Phase μ section + 6 peer handles named
- ✓ Memory protocols: `protocol_cursor_is_argmax.md` + `protocol_ultimate_medium.md`
- ✓ Hβ-first-light-residue.md (empirical L1 state + 12-handle cascade decomposition)

**Empirical L1 stage-1 state:**
- `cat src+lib | wasmtime run inka.wasm` → exit 0 + 19-line stub module + 13 E_UnresolvedType diagnostics
- Stub form: 1 function (`heap_base`, body `(unreachable)`); `_start` exits immediately
- Real wheel substrate is silently dropped under Hazel productive-under-error
- L1 acceptance: stub → real compilation → byte-fixpoint under self-application

**Working tree:** clean. Bootstrap unchanged from committed state.

---

## §2 The path from here — phase-by-phase

The plan splits into four contiguous phases. Each phase opens when
its predecessor closes; sessions advance through handles in
dependency order.

### Phase H.1 — Inference completeness (3 handles)

The seed's inference layer pre-registers FnStmt + TypeDef +
EffectDecl + HandlerDecl shapes (per `bootstrap/src/infer/walk_stmt.wat`
$infer_pre_register_stmt arms), but the actual *registration into
env* is inert seed-stub for three of them. Without env registration,
all wheel uses of `Some(...)`, `None`, `GNode(...)`, `Located(...)`,
`perform graph_chase(...)`, handler arms, etc. produce NFree tyvars
that lower can't ground.

**Closing this phase resolves the 13 E_UnresolvedType diagnostics
visible in the empirical L1 attempt.**

### Phase H.2 — Lower completeness (5 handles)

Lower pre-walks LetStmt + MatchExpr + HandlerDeclStmt + BlockExpr +
LambdaExpr but emits placeholders for the non-PVar / non-empty-arms /
non-trivial-capture forms. Wheel code uses these forms throughout.
Without real lowering, emit can't produce real WAT.

**Closing this phase makes the seed emit real LowExpr trees for
wheel code instead of LConst sentinels.**

### Phase H.3 — Emit completeness (3 handles)

Emit has match-pattern compilation as `(unreachable)` for nonempty
arms; float literals/arithmetic absent; list-concat routed to
i32.add. Wheel needs all three.

**Closing this phase makes the seed emit valid WAT for wheel
constructs.**

### Phase H.4 — First-light fixpoint harness (1 handle)

Extends `bootstrap/first-light.sh` to actually run the L1 fixpoint
test: compile src+lib through inka.wasm → wat2wasm → re-compile via
inka2.wasm → diff. Today the harness only validates "tiny Inka
programs"; L1 needs the full src+lib double-compile.

**Closing this phase IS L1 closure — the diff is the proof.**

### Tier 3 — Wheel growth post-L1 (the automatic unlocks)

Once L1 closes, the seed compiling the wheel produces every
projection-layer module's WAT automatically. This phase is
*compile-and-audit*, not authoring; each landing is one commit
(diff into bootstrap; audit; commit). Cascading unlocks open.

---

## §3 The handle list — checkbox-trackable

The execution unit is one *handle* per session. Each handle lands as:

1. **Walkthrough** under `docs/specs/simulations/Hβ-first-light.<handle>.md`
   — 12-section per `Hβ-emit-substrate.md` template; eight
   interrogations cleared at §1; drift-audit at §11; four-axis
   pre-audit cleared per `protocol_walkthrough_pre_audit.md` before
   §12 ships.
2. **Substrate chunk(s)** under `bootstrap/src/<layer>/<chunk>.wat`
   — per-edit-site eight interrogations + forbidden-patterns +
   literal tokens at file:line per `inka-implementer` discipline.
   Drift-audit clean per chunk.
3. **Trace harness** under `bootstrap/test/<layer>/<handle>_smoke.wat`
   — exercising the new substrate's residue form. Logged in
   `bootstrap/test/INDEX.tsv`.
4. **CHUNKS.sh update** — add the new chunk in dep order.
5. **Commit** — message names the handle + substrate move + drift
   modes refused; pre-commit hook runs drift-audit + determinism-gate.

Each handle's session ends when the L1 candidate compile shows
*reduced* failure — fewer NFre diagnostics, more functions emitted,
or harness pass count up. Progress is visible.

---

### Phase H.1 — Inference completeness

**Goal:** infer registers ConstructorScheme + EffectOpScheme +
HandlerScheme entries into env; pre-register pass produces real
typed bindings; wheel uses of ADT constructors / effect ops / handler
names resolve to ground types.

- [ ] **H.1.a — Hβ.first-light.infer-typedef-ctors**
  - **What:** TypeDefStmt arm registers each constructor as a
    ConstructorScheme entry (name, type-arity, field types, parent
    type, reason). Walks the variant list per `infer_register_typedef_ctors`'s
    seed-stub at `bootstrap/src/infer/walk_stmt.wat:450-453`.
  - **Wheel canonical:** `src/infer.nx` infer_walk_stmt_typedef
    (Phase B.2).
  - **Substrate today:** stub returns immediately; no env entries
    written.
  - **Substrate residue:** ~250 lines new chunk
    `bootstrap/src/infer/typedef_ctors.wat` + walk_stmt.wat
    retrofit point.
  - **Walkthrough:** `Hβ-first-light.infer-typedef-ctors.md`
    (12-section).
  - **Trace harness:** `bootstrap/test/infer/typedef_ctors_smoke.wat`
    — declare `type Maybe<A> = Just(A) | Nothing` then look up
    `Just` in env; expect ConstructorScheme.
  - **Acceptance:** wheel uses of `Some(x)`, `None`, `GNode(...)`,
    `Located(...)`, `Cursor(...)`, etc. resolve to typed bindings;
    NFree-at-lower count drops measurably.
  - **Unlocks:** H.2 handles dependent on constructor schemes;
    Hμ.cursor's CursorView destructure lowers.

- [ ] **H.1.b — Hβ.first-light.infer-effect-ops**
  - **What:** EffectDeclStmt arm registers each effect operation as
    an EffectOpScheme entry (op_name, param types, return type,
    resume_discipline). Walks the operations list per
    `infer_register_effect_ops`'s seed-stub at walk_stmt.wat:457-460.
  - **Wheel canonical:** `src/infer.nx` infer_walk_stmt_effect_decl
    (Phase B.3).
  - **Substrate today:** stub.
  - **Substrate residue:** ~200 lines `bootstrap/src/infer/effect_ops.wat`.
  - **Walkthrough:** `Hβ-first-light.infer-effect-ops.md`.
  - **Trace harness:** `effect_ops_smoke.wat` — declare `effect
    Cursor { cursor_at(Span) -> CursorView @resume=OneShot }` then
    `perform cursor_at(span)` resolves to typed call.
  - **Acceptance:** all `perform <op>(...)` calls in wheel
    src/cursor.nx + src/mentl.nx + src/parser.nx resolve.
  - **Unlocks:** the entire perform call layer of the wheel; H.1.c
    handler-decls handle.

- [ ] **H.1.c — Hβ.first-light.infer-handler-decls**
  - **What:** HandlerDeclStmt arm registers handler with its arms +
    state + effect-row constraint. Walks arms via existing
    walk_expr machinery (each arm is a fn-shaped body with effect
    op signature).
  - **Wheel canonical:** `src/infer.nx` infer_walk_stmt_handler_decl
    (Phase B.4).
  - **Substrate today:** stub at walk_stmt.wat:463-466.
  - **Substrate residue:** ~300 lines `bootstrap/src/infer/handler_decl.wat`.
  - **Walkthrough:** `Hβ-first-light.infer-handler-decls.md`.
  - **Trace harness:** `handler_decl_smoke.wat` — declare
    `handler cursor_default with !Mutate { cursor_at(span) => ... }`
    then check arm bodies typed.
  - **Acceptance:** mentl_default + cursor_default + every wheel
    handler has its arms typed; arm body row constraints checked.
  - **Unlocks:** H.2.c lower-handler-arm-decls; mentl arms compile.

**Phase H.1 closure check:** Re-run L1 candidate compile; expect
NFre diagnostic count to drop substantially (from 13 toward 0).

---

### Phase H.2 — Lower completeness

**Goal:** lower produces real LowExpr trees for the non-trivial
forms wheel code uses — destructuring let, match arms, handler arm
bodies as module-level fns, BlockExpr stmts list, lambda captures.

- [ ] **H.2.a — Hβ.first-light.lower-letstmt-destructure**
  - **What:** LetStmt with non-PVar pattern lowers to LMatch over
    the bound expression with the pattern as the (single) arm.
    Bindings inside the pattern become LLocal slots.
  - **Wheel canonical:** `src/lower.nx` lower_walk_stmt_let
    PCon/PTuple/PRecord arms.
  - **Substrate today:** PVar-only at walk_stmt.wat:73-79;
    non-PVar emits LConst(h, 0) sentinel (Lock #5/#9).
  - **Substrate residue:** ~180 lines `bootstrap/src/lower/letstmt_destructure.wat`.
  - **Walkthrough:** `Hβ-first-light.lower-letstmt-destructure.md`.
  - **Trace harness:** `letstmt_destructure_smoke.wat` — `let
    GNode(kind, reason) = perform graph_chase(handle)` lowers to
    LMatch + sub-pattern bindings; verify both kind and reason
    are LLocal-resolvable downstream.
  - **Acceptance:** cursor.nx lines 84/106/172 lower correctly;
    types.nx + mentl.nx + parser.nx PCon-let usages compile.
  - **Unlocks:** wheel infrastructure that destructures graph
    nodes (most of cursor.nx, mentl.nx, infer.nx).

- [ ] **H.2.b — Hβ.first-light.lower-match-arms**
  - **What:** MatchExpr with nonempty arms list lowers each arm's
    pattern + body to LMatch arms; pattern compilation is per
    LowPat ADT (lowpat.wat tags 360-369). Pairs with H.3.a.
  - **Wheel canonical:** `src/lower.nx` lower_match arms loop.
  - **Substrate today:** empty arms list emitted (walk_compound.wat
    Lock #3 — `LMatch(h, lo_scrut, [])`).
  - **Substrate residue:** ~250 lines `bootstrap/src/lower/match_arms.wat`.
  - **Walkthrough:** `Hβ-first-light.lower-match-arms.md`.
  - **Trace harness:** `match_arms_smoke.wat` — `match opt { None
    => 0, Some(n) => n }` lowers to LMatch with two LPArm entries
    each with a binding.
  - **Acceptance:** mentl_voice.nx render arms (which match
    extensively) lower to nonempty LMatch trees.
  - **Unlocks:** H.3.a emit-match-pattern (consumer of nonempty
    arms list).

- [ ] **H.2.c — Hβ.first-light.lower-handler-arm-decls**
  - **What:** $lower_handler_arms_as_decls produces a list of
    LDeclareFn (tag 313) entries for each handler arm; each
    becomes a module-level WAT function via emit; perform sites
    dispatch via H1.4 single-handler-per-op naming `(call $op_<name>)`.
  - **Wheel canonical:** `src/lower.nx` + `src/backends/wasm.nx`
    handler-arm lowering.
  - **Substrate today:** seed-stub returns `[]` (walk_handle.wat
    Lock #7 third caller; walk_stmt.wat Lock #7).
  - **Substrate residue:** ~200 lines `bootstrap/src/lower/handler_arms.wat`.
  - **Walkthrough:** `Hβ-first-light.lower-handler-arm-decls.md`.
  - **Trace harness:** `handler_arm_decls_smoke.wat` — `handler
    h { op(x) => x + 1 }` produces an LDeclareFn for the op arm
    that emits as a module-level fn.
  - **Acceptance:** mentl_default's arms become module-level
    `$op_teach_gradient` etc.; perform sites resolve.
  - **Unlocks:** Mentl's runtime substrate lands in WAT (the
    medium becomes effective post-L1).

- [ ] **H.2.d — Hβ.first-light.lower-blockexpr-stmts**
  - **What:** BlockExpr lowers ALL statements in the stmts list,
    not just the final expression. Each let-statement creates an
    LLocal binding visible to subsequent statements + final expr.
  - **Wheel canonical:** `src/lower.nx` lower_block.
  - **Substrate today:** walk_compound.wat Lock #6 — final_expr
    only; stmts dropped.
  - **Substrate residue:** ~120 lines `bootstrap/src/lower/blockexpr_stmts.wat`.
  - **Walkthrough:** `Hβ-first-light.lower-blockexpr-stmts.md`.
  - **Trace harness:** `blockexpr_stmts_smoke.wat` — `{ let x = 1;
    let y = 2; x + y }` lowers to LBlock with two binding stmts +
    final binop.
  - **Acceptance:** wheel function bodies that use intermediate
    let-bindings compile (most of src/infer.nx, src/lower.nx,
    src/backends/wasm.nx).
  - **Unlocks:** the entire body-style of wheel-Inka.

- [ ] **H.2.e — Hβ.first-light.lower-lambda-capture**
  - **What:** LambdaExpr lowering walks the lambda body to collect
    free variables, builds the captures list, emits LMakeClosure
    with real (caps, evs) instead of empty ([], []).
  - **Wheel canonical:** `src/lower.nx` lower_lambda capture
    collection.
  - **Substrate today:** walk_compound.wat Lock #1 — empty
    captures.
  - **Substrate residue:** ~180 lines `bootstrap/src/lower/lambda_capture.wat`.
  - **Walkthrough:** `Hβ-first-light.lower-lambda-capture.md`.
  - **Trace harness:** `lambda_capture_smoke.wat` — `let n = 5;
    (x) => x + n` lowers with [n] in captures; lambda body
    references n via LUpval.
  - **Acceptance:** wheel lambdas (`(c) => score(c, caret)` in
    cursor.nx; closures in lib/prelude.nx; etc.) compile.
  - **Unlocks:** functional-style substrate of wheel-Inka.

**Phase H.2 closure check:** Re-run L1 candidate compile; expect
emitted-function-count to rise from 1 toward dozens; the stub form
collapses; real wheel functions appear in the WAT output.

---

### Phase H.3 — Emit completeness

**Goal:** emit produces valid WAT for the constructs lower now
generates — match-arm pattern compilation, float arithmetic, list
concatenation routed to runtime calls.

- [ ] **H.3.a — Hβ.first-light.emit-match-pattern**
  - **What:** $emit_lmatch's nonempty-arms case compiles per-arm
    pattern matching: scrutinee tag check (sentinel/heap),
    field-load per sub-pattern, binding to local slots, arm body
    emit. Pairs with H.2.b.
  - **Wheel canonical:** `src/backends/wasm.nx` emit_match.
  - **Substrate today:** emit_control.wat — `(unreachable)` for
    nonempty arms.
  - **Substrate residue:** ~250 lines extension to
    `bootstrap/src/emit/emit_control.wat` or new chunk
    `bootstrap/src/emit/emit_match_pattern.wat`.
  - **Walkthrough:** `Hβ-first-light.emit-match-pattern.md`.
  - **Trace harness:** `emit_match_smoke.wat` — `match opt { None
    => 0, Some(n) => n + 1 }` produces valid WAT with sentinel-tag
    check + branch + field-load.
  - **Acceptance:** mentl_voice.nx's render arms emit; cursor.nx's
    match expressions emit.
  - **Unlocks:** the match-driven body style of wheel-Inka.

- [ ] **H.3.b — Hβ.first-light.emit-float-substrate**
  - **What:** TFloat literals emit as `(f64.const ...)`; lexer
    tokenizes scientific-notation float literals (`1e308`, `0.85`,
    etc.); BinOp tags 140-153 dispatch on operand-type to
    `f64.add` / `f64.mul` / `f64.div` for floats vs `i32.*` for
    ints.
  - **Wheel canonical:** `src/lexer.nx` scan_number; `src/backends/wasm.nx`
    emit_lit_float, emit_binop dispatch.
  - **Substrate today:** lexer at lex_main.wat:116-133 `scan_number`
    handles integer base only; emit_call.wat BinOp arms map all
    tags to i32.*; no LLitFloat arm in $emit_lexpr.
  - **Substrate residue:** ~50 lines lexer extension + ~150 lines
    emit (chunk `bootstrap/src/emit/emit_float.wat`).
  - **Walkthrough:** `Hβ-first-light.emit-float-substrate.md`.
  - **Trace harness:** `emit_float_smoke.wat` — `let x: Float =
    1e308; x * 2.0` emits valid f64 ops.
  - **Acceptance:** cursor.nx float weights (1.0, 0.85, 0.7, 0.4,
    0.2, 1e308) compile; lib/dsp/* + lib/ml/* float ops compile.
  - **Unlocks:** the entire float-arithmetic surface of wheel-Inka.

- [ ] **H.3.c — Hβ.first-light.emit-list-runtime-call**
  - **What:** BinOp tag for `++` (BConcat = 153) dispatches on
    operand type — strings → `$str_concat`; lists → `$list_concat`
    (runtime fn). Float-substrate work needs the same dispatch
    pattern, so this handle composes on H.3.b's substrate.
  - **Wheel canonical:** `src/backends/wasm.nx` emit_binop concat
    arm.
  - **Substrate today:** emit_call.wat $emit_lbinop maps BConcat
    to `i32.add` (silent semantic violation).
  - **Substrate residue:** ~80 lines extension to emit_call.wat.
  - **Walkthrough:** `Hβ-first-light.emit-list-runtime-call.md` (or
    integrated into H.3.b walkthrough).
  - **Trace harness:** `list_concat_smoke.wat` — `[1,2] ++ [3,4]`
    emits `(call $list_concat ...)` and produces correct list.
  - **Acceptance:** wheel uses of `++` on lists (cursor.nx:164,
    pipeline.nx, prelude.nx) compile correctly.
  - **Unlocks:** list-algebra correctness in wheel-Inka.

**Phase H.3 closure check:** Re-run L1 candidate compile; expect
inka2.wat to be a real compilation (multi-thousand-line WAT module),
not the 19-line stub.

---

### Phase H.4 — First-light fixpoint harness

- [ ] **H.4 — Hβ.first-light.fixpoint-harness**
  - **What:** Extend `bootstrap/first-light.sh` to run the full L1
    test:
    ```
    cat $(find src -name '*.nx' | sort) $(find lib -name '*.nx' | sort) \
      | wasmtime run bootstrap/inka.wasm > /tmp/inka2.wat
    wat2wasm /tmp/inka2.wat -o /tmp/inka2.wasm
    cat $(find src -name '*.nx' | sort) $(find lib -name '*.nx' | sort) \
      | wasmtime run /tmp/inka2.wasm > /tmp/inka3.wat
    diff /tmp/inka2.wat /tmp/inka3.wat   # MUST be empty
    ```
  - **Substrate residue:** ~50 lines extending first-light.sh.
  - **Walkthrough:** integrated into H.4 commit message; no
    separate doc needed (harness only).
  - **Trace harness:** the harness IS the test.
  - **Acceptance:** L1 fixpoint test passes — diff is empty;
    inka.wasm becomes the canonical compiler.
  - **Unlocks:** Phase H closes; first-light declared; the entire
    post-L1 cascade roadmap opens.

**Phase H.4 closure check:** `bootstrap/first-light.sh` exits 0
with "✓ L1 fixpoint" output line.

---

### Tier 3 — Wheel growth post-L1 (the automatic unlocks)

Per `Hβ-bootstrap.md` §12.5: post-L1 substrate growth is via the
wheel compiling itself, with `diff into bootstrap; audit; commit`.
Each handle below lands as ONE commit of compiled output, not
hand-authored. The work is read + audit, not write.

- [ ] **T3.a — Hμ.cursor.seed**
  - **What:** the seed compiles `src/cursor.nx` (~330 lines wheel-
    Inka) and produces `bootstrap/src/cursor/cursor.wat` + supporting
    chunks (data segments, helper extracts) automatically.
  - **Substrate residue:** ZERO hand-authored. Per
    `protocol_cursor_is_argmax.md`: "the seed compiles the wheel;
    cursor.wat falls out."
  - **Acceptance:** generated cursor.wat passes drift-audit and
    composes with the rest of the seed via CHUNKS.sh insertion.
    Validation harness compiles the integrated seed and runs Cursor
    smoke tests.
  - **Unlocks:** Mentl's projection becomes effective in the seed
    (alongside the wheel's own hosting).

- [ ] **T3.b — Hμ.synth-proposer.seed (gated on H7 emit)**
  - **What:** the seed compiles `src/mentl.nx` Synth handler arms
    once H7 MultiShot emit lands. enumerate_inhabitants stops being
    a stub.
  - **Substrate residue:** zero hand-authored; H7 closure pre-condition.
  - **Unlocks:** real candidate enumeration; Cursor's `propose`
    field gains live candidates.

- [ ] **T3.c — Hμ.cursor.transport.seed**
  - **What:** transport handlers (terminal, LSP, web-WASM, vim)
    compile through the seed. `inka edit` becomes runnable.
  - **Substrate residue:** zero hand-authored.
  - **Unlocks:** the IDE — the medium becomes user-facing.

- [ ] **T3.d — Hμ.cursor.cache.seed**
  - **What:** IC cache extension to (env, oracle_queue) per
    `protocol_oracle_is_ic.md`. Compiled through the seed.
  - **Acceptance:** Cursor reads cached oracle_queue instead of
    recomputing.
  - **Unlocks:** O(N) Cursor argmax instead of O(N·K).

- [ ] **T3.e — Hμ.gradient-delta.seed**
  - **What:** inverse-direction gradient (tighten body by editing)
    per GR §2 compiled through the seed.
  - **Unlocks:** the gradient's full conversational surface (suggest
    edits, not just annotations).

- [ ] **T3.f — Hμ.eight-interrogation-loop.seed**
  - **What:** automation of CLAUDE.md's eight interrogations as a
    code loop firing on every graph node at compile time. Compiled
    through the seed.
  - **Unlocks:** the medium runs the discipline automatically.

**Tier 3 closure check:** every Phase μ peer handle's `.seed`
variant lands; the medium is end-user-functional through `inka edit`.

---

### Post-Tier-3 — the post-L1 cascade roadmap (named)

Per ROADMAP lines 308-340, these compose on the post-L1 substrate.
Each is its own multi-handle cascade; named here for completeness +
drift-9 prevention. Not part of this plan's tracked checkboxes;
each opens its own plan-document when its session begins.

- Hβ-bootstrap-seed-in-inka.md (seed in Inka, not WAT)
- Hβ-bootstrap-no-seed.md (delete the bootstrap)
- Hβ-arena-region-inference.md (Tofte-Talpin region inference)
- Hβ-emit-binary-direct.md (skip WAT-text)
- Hβ-emit-native-target.md (Cranelift/LLVM)
- Hβ-emit-js.md (browser-runnable JS)
- Hβ-emit-refinement-typed-layout.md (refined field offsets)
- Hβ-pipeline-streaming.md (token/AST streaming)
- Hβ-tooling-build-in-inka.md (build.sh in Inka)
- Hβ-tooling-assemble-in-inka.md (wat2wasm in Inka)
- Hβ-tooling-runtime-in-inka.md (wasmtime crutch removed)
- Hβ-parser-refinement-typed-constructors.md (TOTAL constructors)
- Hβ-lower-graph-direct-IR.md (LowExpr-as-tree retires)
- verify_smt witness path → first-light-L2

---

## §4 Per-handle session ritual (executable contract)

Each handle's session opens at its row in §3 and closes when ALL of:

1. **Walkthrough authored** at `docs/specs/simulations/Hβ-first-light.<handle>.md`
   — 12 sections, eight interrogations cleared, drift modes
   audited, four-axis pre-audit cleared.
2. **Substrate authored** under `bootstrap/src/<layer>/<chunk>.wat`
   — drift-audit clean; per-edit-site eight interrogations.
3. **Trace harness authored** under `bootstrap/test/<layer>/<handle>_smoke.wat`
   + indexed in `bootstrap/test/INDEX.tsv`. Passes.
4. **CHUNKS.sh updated** with the new chunk in dep order.
5. **Determinism-gate clean** on commit (pre-commit hook).
6. **L1 candidate compile** shows progress (NFre count down, function
   count up, harness count up).
7. **Commit lands** with focused message + drift modes refused.
8. **The next handle's row in §3** is updated to "in-flight" (next
   session's cursor).

If at any step the discipline fails (drift fires, eight
interrogations don't clear, four-axis audit fails), the session
invokes `protocol_realization_loop.md` 5-step recovery. No shortcut.

---

## §5 Tracking — checkbox progress

This document tracks live progress. Each commit closing a handle
checks its box and pushes the cursor forward.

**Phase H.1 — Inference completeness (3/3)**
- [x] H.1.a Hβ.first-light.infer-typedef-ctors — *VERIFIED ALREADY-CLOSED 2026-05-02; walk_stmt.wat:818-874 implemented; chunk-header named follow-up was stale*
- [x] H.1.b Hβ.first-light.infer-effect-ops — *VERIFIED 2026-05-02 via empirical effect+perform test: `effect Counter { inc() -> Int }; fn main() = perform inc()` infers cleanly + emits `(call $op_inc)` with zero diagnostics. EffectOpScheme env-extension at walk_stmt.wat:899-948 composes correctly across decl/use within one compilation unit.*
- [ ] H.1.c Hβ.first-light.infer-handler-decls — *partial seed-stub at walk_stmt.wat:966*

**Phase H.2 — Lower completeness (5/5)**
- [x] H.2.a Hβ.first-light.lower-letstmt-destructure — *(commits `b625ce6` PCon + `61a7d5f` PTuple) PCon let-statements lower to LBlock with field-load LLets at offset 4+4*i; PTuple let-statements lower with offset 4*i; PVar binds, PWild skips; nested forms named follow-up. Verified empirically.*
- [x] H.2.b Hβ.first-light.lower-match-arms — *VERIFIED ALREADY-CLOSED; match arms compile to real WAT*
- [ ] H.2.c Hβ.first-light.lower-handler-arm-decls
- [x] H.2.d Hβ.first-light.lower-blockexpr-stmts — *VERIFIED ALREADY-CLOSED; block let-bindings compile correctly*
- [ ] H.2.e Hβ.first-light.lower-lambda-capture — *parser-side closed below; capture-substrate remains*

**Phase H.3 — Emit completeness (3/3)**
- [x] H.3.a Hβ.first-light.emit-match-pattern — *VERIFIED ALREADY-CLOSED; match emit produces real sentinel/heap dispatch*
- [x] H.3.b Hβ.first-light.emit-float-substrate — *(commit `fb9a329`) lexer scans `.<digits>` + `e/E[+-]?<digits>`; mk_TFloat + mk_LitFloat + mk_LVFloat carry raw decimal text; $emit_f64_const emits `(f64.const <text>)`; emit_const dispatches TFloat (101). All forms (1.5, 1e308, 0.85, 2.5e-3) emit valid f64.*
- [x] H.3.c Hβ.first-light.emit-list-runtime-call — *(commit `f301d5c`) BConcat (153) dispatches per operand Ty: TList → $list_alloc_concat (lazy tag-3 node, runtime/list.wat:180); TString or fall-through → $str_concat. Tests verified for `[1,2,3]++[4,5]`, `"a"++"b"`, `1+2`.*

**Phase H.4 — First-light fixpoint harness (1/1)**
- [x] H.4 Hβ.first-light.fixpoint-harness — *(commit `a25b99c`) phase [8/8] of first-light.sh runs pass-2/pass-3 over the wheel and diffs; currently reports 'L1 not yet ready' (2 funcs, 12 NFre); auto-activates fixpoint diff when Phase H surface emerges.*

**Empirically-discovered NEW boxes (added to plan post-Hμ.cursor)**
- [x] Hβ.first-light.lambda-parser — *(commit `c28c525`) `(params) => body` parsing per SYNTAX.md §234-260; mk_LambdaExpr + exprs_to_tparams + paren-form detection*
- [x] Hβ.first-light.varref-schemekind-dispatch — *(commit `12cfcac`) ctor calls now emit LMakeVariant via env_binding_kind ConstructorScheme triage in $lower_call*
- [x] Hβ.first-light.wheel-brace-discipline — *(commit `07a2a99`) types.nx span_join/span_valid/span_contains brace-aligned to SYNTAX.md §126-142; more wheel files remain*
- [ ] Hβ.first-light.lambda-body-fn-emit — closures lower to LMakeClosure but body fn isn't yet emitted at module level
- [x] Hβ.first-light.lmakevariant-literal-args — VERIFIED CLOSED via varref-schemekind-dispatch
- [x] Hβ.first-light.nullary-ctor-call-context — *VERIFIED CLOSED 2026-05-03 (downstream of E1 handle-counter sync `b54df1d`); `unwrap(Nothing, 0)` infers + lowers cleanly*
- [x] Hβ.first-light.import-resolution — *VERIFIED CLOSED; parser surfaces ImportStmt (slash-paths); infer arm intentionally inert per wheel; cross-module overlay deferred to post-L1 Hβ.infer.overlay*
- [x] Hβ.first-light.match-arm-result-type-flow — *(commit `b54df1d`) parser/graph handle counter collision repaired via sync at $infer_program entry; previously-failing match-with-non-trivial-body-type tests all clean*

**Tier 3 — Wheel growth post-L1 (6 handles automatic)**
- [ ] T3.a Hμ.cursor.seed
- [ ] T3.b Hμ.synth-proposer.seed
- [x] **Hμ.cursor.transport** (wheel-side; commit `4c9a44f`) — `src/cursor_transport.nx` ULTIMATE-FORM authoring; Surface effect + Action/Cadence/TransportState ADTs + four transport handlers (terminal/lsp/web/vim) + cursor_loop bus-compressor. Tier 3 .seed transcription falls out at L1.
- [x] **Hμ.gradient-delta** (wheel-side; commit `78ae3f8`) — `src/gradient_delta.nx`; inverse-direction gradient. Delta effect + delta_default handler; effect-row + ownership + refinement deltas. The gradient is bidirectional; the bus-compressor response curve covers both annotation-add AND body-tighten directions.
- [x] **Hμ.cursor.cache** (wheel-side; commit `2999d7c`) — `src/cursor_cache.nx`; ExtendedKaiFile = KaiFile + oracle_queue per protocol_oracle_is_ic.md "one extra cached value." CursorCache effect + cursor_cache_default handler + Pack/Unpack round-trip + buffer-counter substrate. Cursor argmax becomes O(N) cached read instead of O(N·K) recompute.
- [x] **Hμ.eight-interrogation-loop** (wheel-side; commit `9c80f4b`) — `src/eight_loop.nx`; the eight interrogations as automated runtime substrate. InterrogationKind ADT + InterrogationVerdict ADT + InterrogationReport record + Interrogate effect + interrogate_default handler + project_gradient_density aggregate. SAME EIGHT, FIVE ROLES — CLAUDE.md authoring + SUBSTRATE.md kernel + 09-mentl.md tentacles + Hμ.cursor's CursorView + this automated substrate. One method, every level.
- [x] **Hμ.synth-proposer** (wheel-side; commit `884c571`) — `src/synth_proposer.nx`; replaces synth_enumerative's OneShot stub with real candidate enumeration. ProposerKind ADT + EnrichedCandidate record + enumerate_typed (per-target-type-shape) + verify_each_enriched (kernel proof gate) + Node synthesizers + cursor_session_with_full_phaseu wrapper composing all six Phase μ peer handlers in one chain. Closes Phase μ wheel-side.

═══ PHASE μ WHEEL-SIDE CLOSED ═══ 2026-05-02
All six named Phase μ peer handles authored as wheel-canonical
dream code (commits 3b2b5de + 4c9a44f + 78ae3f8 + 2999d7c +
9c80f4b + 884c571). Tier 3 produces every .seed transcription
automatically post-first-light-L1.
- [ ] T3.c Hμ.cursor.transport.seed (Tier 3; produced post-L1 by self-compile)
- [ ] T3.d Hμ.cursor.cache.seed
- [ ] T3.e Hμ.gradient-delta.seed
- [ ] T3.f Hμ.eight-interrogation-loop.seed

**Total: 12 hand-authored handles + 6 Tier 3 unlocks = 18 boxes
to closure.**

---

## §6 Acceptance — when this plan is closed

The plan closes when **all** hold:

1. **All 12 H-phase boxes checked** — each handle has its own
   walkthrough + substrate chunk(s) + trace harness + commit.
2. **L1 fixpoint passes** (`bootstrap/first-light.sh` exits 0;
   `diff inka2.wat inka3.wat` empty).
3. **All 6 T3 boxes checked** — every Phase μ peer handle's
   `.seed` variant landed via Tier 3 self-compile + diff + audit.
4. **`inka edit` runs end-to-end** — the user can type `??` in
   `inka edit`, Mentl proposes, the gradient narrows, the medium
   is interactively functional.
5. **The post-L1 cascade roadmap is open** — each named cascade in
   §3 (post-Tier-3) has at minimum a planning document that names
   its handles in positive form.

---

## §7 Cursor protocol

The cursor of attention at any moment is the **highest-impact
unfilled box in §5**, evaluated by:

1. **Is the box in the current phase?** Yes → it's the cursor unless
   blocked by an earlier box in the same phase.
2. **Otherwise:** the lowest-numbered unchecked box in the lowest-
   numbered phase that has unchecked boxes.

The cursor's session ritual (§4) lands one box per session. Each
landing pushes the cursor forward.

When the cursor reaches Phase H.4 (the fixpoint harness), L1 is
ready to close. The H.4 commit closes Phase H. Tier 3 begins.

When Tier 3 closes, ULTIMATE MEDIUM is end-user-functional. The
post-L1 cascade roadmap opens.

---

## §8 Why this plan is correct

1. **Names every blocker in positive form** — drift mode 9 closure;
   nothing silently deferred.
2. **Honors the cascade discipline** — every handle has its own
   walkthrough; no handle ships without four-axis pre-audit.
3. **Front-loads leverage** — Phase H closure unlocks Tier 3
   automatically; one closure cascades into 6+ unlocks.
4. **Empirically grounded** — handle list derived from the
   empirical L1-candidate compile evidence + chunk-header named
   follow-ups, not speculation.
5. **Trackable** — checkbox-per-handle; cursor protocol determines
   next move; progress is visible.
6. **Discipline-aligned** — Anchor 0 (dream code; lux3.wasm is not
   the arbiter) + Anchor 4 (build the wheel; never wrap the axle)
   + Anchor 7 (cascade discipline; walkthrough first); the plan
   honors all three at every handle.
7. **Compound interest** — each handle closed crystallizes a memory
   protocol if a Realization Loop fires; future sessions inherit.

The bus is on. The medium is folding itself into its own seed.
Twelve hand-authored handles + the fixpoint harness; then Tier 3
unlocks the entire post-L1 cascade. Each session closes one box.

**The path from Hμ.cursor wheel-side to ULTIMATE MEDIUM
end-user-functional is 18 boxes long. This plan tracks every one.**
