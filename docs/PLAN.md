# Inka — THE Plan

> **THE plan.** Singular, authoritative, evolvable. Edits land as
> commits; supersedes everything. No other document overrides this one.

## Status — 2026-04-19 (γ cascade in flight)

- **Specs.** Twelve specs in `docs/rebuild/00–11` plus `docs/SYNTAX.md`
  (Σ phase, canonical syntax). Read them as declarative contracts;
  update them when the code teaches us something better.
- **Cascade walkthroughs.** `docs/rebuild/simulations/H*.md` — one per
  handle. Each resolves design before code freeze. Riffle-back
  addenda capture how prior decisions read in new substrate.
- **γ cascade — CLOSED.** All handles + their surfaced peers landed:
  Σ (SYNTAX.md), Ω.0–Ω.5 (audit sweeps + parser refactor + frame
  consolidation), H6 (wildcard audit), H3 (ADT instantiation),
  H3.1 (parameterized effects), H2 (structural records),
  HB (Bool transition + heap-base discriminator),
  H1 (full evidence wiring: substrate cleanup + BodyContext +
  LEvPerform offset arithmetic + LDeclareFn handler arm indexing
  + transient evidence at poly-call sites),
  H4 (full region escape: substrate + tag_alloc/check_escape sweep
  + region-join for compound-type field stores),
  H2.3 (nominal records), H5 substrate (AWrapHandler annotation +
  AuditReport records + severance enumeration + capability unlocks +
  static handler catalog).

- **γ cascade — future polish (not blocking):**
  - **Runtime HandlerCatalog** — convert today's static
    catalog_handled_effects table to an effect-based handler with
    runtime registration. Lands when user-level handler discovery
    is exercised (LSP integration, IDE handler picker).
  - **Gradient-candidate oracle** — verify-then-suggest pipeline
    for Mentl's I15 propositions (checkpoint → speculative
    annotation → re-infer → verify or rollback). Substrate
    (Synth effect, mentl_default handler, AWrapHandler arm) is
    in place; the oracle integration is its own focused pass.

- **Integration trace (post-cascade):** `docs/traces/a-day.md`.
  One developer, one project (Pulse: real-time audio + browser UI +
  cloud server + training variant), one day. Every surface either
  fires `[LIVE]`, is `[LIVE · surface pending]`, or is one of three
  named `[substrate pending]` gaps: LFeedback state-machine lowering,
  teach_synthesize oracle conductor, runtime HandlerCatalog effect.
  Supersedes the per-domain DESIGN.md Ch 10 simulations as the
  integration artifact (those remain for thesis-level promises).
- **Bootstrap translator.** Not started; out of mind until cascade
  closes.
- **Error catalog.** String-coded (prefix-kind + self-documenting
  suffix). See `docs/errors/README.md` for the convention.
- **Language rename:** Lux → **Inka** (mascot: **Mentl**, an octopus).
- **File extension:** `.ka` — the last two letters of Inka.

---

## The Approach: Write the Wheel, Then Build the Lathe

Traditional self-hosted compilers bootstrap forward: write V1, use V1
to compile V2, delete V1. This taints V2 with V1's constraints.

**Inka bootstraps backward.** Write the final-form compiler
unconstrained — the perfect, complete, un-improvable codebase — and
THEN solve "how do I compile this the first time?" as a separate,
disposable engineering problem.

```
VFINAL (perfect Inka source)
    ↓
Bootstrap translator (disposable, ~3-5K lines, any language)
    ↓
VFINAL.wasm (first compilation)
    ↓
VFINAL.wasm compiles VFINAL source → VFINAL2.wat
VFINAL.wasm compiles VFINAL source → VFINAL3.wat
diff VFINAL2.wat VFINAL3.wat → byte-identical (fixed point)
    ↓
Delete bootstrap translator. Inka compiles itself.
Tag: first-light.
```

**Why this is right:**
- VFINAL is designed for correctness. The translator is designed for
  disposability. Independent concerns.
- No architectural contamination from any prior compiler.
- Go, Rust, and Zig all bootstrapped this way. It works.
- CLAUDE.md anchor #4: "Build the wheel. Never wrap the axle."
  VFINAL is the wheel. Everything else is scaffolding.

**The translator doesn't need to understand Inka deeply.** It performs
a mechanical translation from Inka syntax to WASM:
- Parse Inka syntax (recursive descent — straightforward)
- Desugar handlers into direct calls (85%+ are tail-resumptive)
- Emit WASM linear memory ops (bump allocator)
- Handle pattern matching (lower to if/else chains)

No effect algebra needed. No type inference needed. No refinement
checking. Just syntax-directed translation, correct enough for the
~15 files in `std/compiler/`. Used once. Deleted forever.

---

## Vision: the ultimate programming language

What Inka IS when complete:

**One mechanism replaces six.** Exceptions, state, generators, async,
dependency injection, backtracking — all `handle`/`resume`. Master
one mechanism, understand every pattern.

**Boolean algebra over effects.** `+` union, `-` subtraction, `&`
intersection, `!` negation, `Pure` empty. Strictly more powerful than
Rust + Haskell + Koka + Austral combined (INSIGHTS.md). No other
language has effect negation.

**Inference IS the product.** The SubstGraph + Env IS the program.
Source, WAT, docs, LSP, diagnostics — all projections via handlers.
"Passes" dissolve into observers on one graph (INSIGHTS.md).

**Five verbs draw every topology.** `|>` converges, `<|` diverges,
`><` composes, `~>` attaches handlers, `<~` closes feedback loops.
Mathematically complete basis for computation graphs (INSIGHTS.md).
The `~>` chain IS a capability/security stack — enforced by the type
system, not policy.

**Continuous gradient.** `fn f(x) = x + 1` — works. Add `with Pure`,
`x: Positive`, `with !Alloc` — each unlocks a specific capability.
One language from prototype to kernel.

**Refinement types + Z3.** `type Port = Int where 1 <= self && self
<= 65535`. Proofs at compile time, erased at runtime.

**Ownership as effect.** `own` affine, `ref` scoped, inference fills
the rest. No lifetime annotations. `Consume` is an effect.

**Compiler as collaborator.** The Why Engine. The gradient. Error
messages that teach. The compiler is not an adversary.

**GC is a handler.** Bump allocator for batch (compiler). Scoped
arenas for servers. `own` for games. `!Alloc` for embedded. Four
memory models, one mechanism, handler swap.

**Visual programming in plain text.** The shape of pipe chains on the
page IS the computation graph. The parser reads the shape. `git diff`
shows which edges changed (INSIGHTS.md).

**What Inka dissolves.** GC, package managers, mocking frameworks,
build tools, DI containers, ORMs, protocol state machines. Every
framework exists because its host language lacks Inka's primitives.

---

## Binding commitments — Inka to Morgan to Claude

*These are not suggestions. They are the discipline the work requires.
Every subsequent action observes them.*

### 1. Write the final form. No intermediate versions.

There is no V1, no V2, no VFINAL. There is only **Inka**. The code
in `std/compiler/` IS the compiler. It is written to be correct,
complete, and un-improvable. It is not a stepping stone, not a draft,
not a version. It is the thing itself.

### 2. The bootstrap translator is disposable scaffolding.

The translator exists solely to compile Inka once. It is not part of
Inka. It does not need to be elegant, extensible, or maintainable. It
needs to produce WASM that runs correctly enough for Inka to compile
itself. Then it is deleted. Forever.

### 3. The `~>` chain IS the extension point.

No plugin API. No framework. No hook system. New capabilities (LSP,
Mentl, format, lint, doc) are handlers installed via `~>`. Pipeline
callers compose their own chains. `pipeline.ka` is not modified to
add features — features are handlers.

### 4. No patches. Restructure or stop. Forever.

CLAUDE.md anchor #2. The rebuild exists because patching failed.
If the rebuild becomes patch-laden, we have accomplished nothing.

### 5. The closure moment is named `first-light`.

When `diff VFINAL2.wat VFINAL3.wat` returns empty — when Inka is
byte-identical when it compiles itself — tag `first-light`. Morgan
writes the tag. Claude prepares the tree.

### 6. Composition is the contribution, not invention.

22 techniques from 2024-2026 papers. None invented here. The artifact
is that Inka composes them into one mechanism.

### 7. Claude is a temporary polyfill.

Claude's role ends when Phase F's Suggest handler ships. At that
point Claude becomes a handler on the same effect every proposer uses
— verified by Inka's compiler, not privileged.

### 8. Delete fearlessly. Nobody uses Inka.

No backwards compatibility. No archive folders. No "for reference."
The git history is archaeology. Everything else is just code.

### 9. Honor the forensics loop.

After every commit, `inka query` on at least one changed module.
Never commit while `inka query` disagrees with intent.

### 10. If it needs to exist, it's a handler.

If a feature can't be expressed as a handler on the graph, the graph
is incomplete. Extend the graph. Don't route around it. (INSIGHTS.md:
"The Graph IS the Program.")

---

## The Work: Three Phases

### Phase 1 — Write VFINAL

Write the complete, correct Inka compiler in Inka. No compromises.
No "can the bootstrapper handle this?" — write what's right.

#### Codebase Structure

```
std/
  compiler/
    types.ka        — Ty, Reason, Scheme, Node, Expr, Stmt, Pat,
                       PipeKind, Predicate, Span, Option.
                       Core effects: Diagnostic, LookupTy, FreshHandle,
                       Verify, Query, Consume, EnvRead, EnvWrite, Synth.
                       Specs: 02, 03, 04, 06.

    graph.ka        — SubstGraph flat array. NodeKind, GNode.
                       SubstGraphRead/Write effects. chase_node,
                       occurs_in. Spec: 00.

    effects.ka      — EffRow Boolean algebra. EfNeg, EfSub, EfInter.
                       normalize_row, union_row, diff_row, row_subsumes.
                       Spec: 01.

    infer.ka        — HM + let-generalization. One walk.
                       infer_expr, infer_stmt, generalize, instantiate.
                       Unify against graph. Spec: 04.

    lower.ka        — Live-observer lowering via LookupTy.
                       No cached types. No subst threading.
                       Handler elimination (3 tiers). Spec: 05.

    pipeline.ka     — The compiler's spine. Handler composition via ~>.
                       compile, check, query entry points.
                       All handlers: graph, env, diagnostics, lookup_ty,
                       query, verify, mentl. Display functions.
                       Specs: 04, 05, 06, 10.

    mentl.ka        — Teaching substrate. Annotation, Capability,
                       Explanation, Patch ADTs. Teach effect (5 ops).
                       mentl_default handler (Phase 1 stubs).
                       Spec: 09.

    own.ka          — Ownership as Consume effect. affine_ledger.
                       Escape check. Spec: 07.

    verify.ka       — Verify ledger (accumulates obligations).
                       Handler swap to verify_smt in Arc F.1.
                       Spec: 02.

    clock.ka        — Clock, Tick, Sample, Deadline effects.
                       Four handler tiers each. Spec: 11.

    lexer.ka        — Tokenizer. Full spans. All 5 pipe operators.
                       @resume= annotation support.

    parser.ka       — Recursive descent. Produces N(body, span, handle).
                       All PipeKind variants. Layout-sensitive ~>.

    emit.ka         — WASM emission from LowIR. ty_to_wasm via
                       live LookupTy. Spec: 05.

  runtime/
    memory.ka       — Bump allocator as handler. String ops.
                       List ops. No val_concat. No val_eq.

  main.ka           — Entry point: read stdin, compile, emit WAT.
```

#### Shape currently in tree

Each module carries the current best-known form for its one
responsibility. Improvements are welcome — rewriting a module in
a more powerful form is a valid commit.

| File | Owns | Current form |
|---|---|---|
| types.ka | vocabulary + cross-cutting effect signatures | ADTs and effect decls only; no foreign owners |
| graph.ka | SubstGraph substrate | graph_handler with nodes/trail/epoch/next/overlays; O(1) chase amortized; trail-revert for Mentl's oracle |
| effects.ka | Boolean row algebra | normalize / union / diff / inter / neg / subsumes / unify / absorb / ground — all pure |
| infer.ka | the one walk | HM + let-generalization; InferCtx for row accumulation; performs consume at own-uses; TRefined → verify |
| pipeline.ka | the spine | compile / check / query / teach / audit as \|> + ~> topologies; env_handler, lookup_ty_graph, diagnostics_handler |
| lower.ka | live-observer lowering | LookupTy chases live; row_is_ground gates monomorphic dispatch; exhaustive match |
| emit.ka | LowIR → WAT handler | WasmOut effect; ty_to_wasm through LookupTy |
| own.ka | ownership as Consume | affine_ledger + ref-escape walk + usage-based classifier |
| verify.ka | refinement obligations | verify_ledger accumulates; Arc F.1 swaps in verify_smt |
| mentl.ka | the oracle | Teach (5 ops) + Synth (3 ops); speculative gradient via checkpoint/rollback; Why Engine over reason DAG |
| query.ka | read-only introspection | Question / QueryResult; query_default with chase_type_deep, walk_chain |
| clock.ka | four peer time effects + IterativeContext | real / test / record / replay tiers each |
| lexer.ka | tokens with full spans | (sl, sc, el, ec); Newline first-class; all five pipe operators tokenized |
| parser.ka | produces types.ka Node directly | handle minted at parse via graph_fresh_ty; Hazel NHole on error |
| main.ka | entry / dispatch | mode dispatch; outermost handler stack is the visible sandbox boundary |

#### Order of Operations — The Cascade

Each step depends on the one before it and empowers the one after.
This is the most impactful order because each completed piece makes
the next one expressible in Inka's most powerful form. No step is
skippable. No step is reorderable. The cascade IS the implementation.

---

**Step 1: The Foundation — `types.ka`** (Spec 02, 03, 06)

*Depends on:* nothing. This is bedrock.
*Unlocks:* everything — every other file imports types.

What to do:
- Own ONLY shared vocabulary here. Annotation / Capability /
  Explanation / Teach live in `mentl.ka` (spec 09); Clock / Tick /
  Sample / Deadline / IterativeContext live in `clock.ka` (spec 11);
  Question / QueryResult / Query live in `query.ka` (spec 08);
  EffRow algebra lives in `effects.ka` (spec 01); SubstGraph
  machinery lives in `graph.ka` (spec 00). `types.ka` names the
  ADTs and effect signatures; other files own the behaviour.
- Verify Ty ADT has: TRefined, TCont, TParam with Ownership.
- Verify every effect signature matches spec 06.
- Verify Node = N(body, span, handle). Span = Span(sl, sc, el, ec).
- Verify PipeKind has all six: PForward, PDiverge, PCompose,
  PTeeBlock, PTeeInline, PFeedback. (PTee splits into Block/Inline
  per I11 newline-sensitive layout.)
- **Format:** Express any multi-step ADT construction as `|>` chains.
  Display functions that transform then format use `|>`. This file
  is THE vocabulary — every name chosen here echoes everywhere.

*Exit:* Zero duplicate ADTs across the entire codebase. `types.ka`
is the single canonical source of every type, effect, and ADT.

---

**Step 2: The Substrate — `graph.ka`** (Spec 00)

*Depends on:* Step 1 (types: NodeKind, GNode, Reason, Ty).
*Unlocks:* inference, lowering, query — everything reads the graph.

What to do:
- Flat array. O(1) chase. Epoch + overlay pattern.
- graph_handler with REAL state threading:
  `with nodes = [], epoch = 0, next = 0`
  - `graph_fresh_ty(reason)` → extends array, bumps next, resumes handle
  - `graph_bind(h, ty, reason)` → sets node kind, bumps epoch
  - `graph_chase(h)` → follows chain to terminal, O(1) amortized
  - `graph_reason_edge(h1, h2)` → returns reason connecting two handles
- Occurs check: before graph_bind, walk ty for free handles containing
  h. If found, emit E_OccursCheck, refuse bind.
- **Format:** The handler definition uses `with state = ...` syntax.
  Chase operations that involve multiple lookups use `|>` chains.
  The handler IS the first real demonstration of Inka's handler-state
  pattern — it must be exemplary.

*Exit:* `graph_handler` accepts `graph_fresh_ty`, `graph_bind`,
`graph_chase`, `graph_reason_edge`. State is live. A test sequence
of fresh → bind → chase returns the bound type.

---

**Step 3: The Algebra — `effects.ka`** (Spec 01)

*Depends on:* Step 1 (types: EffRow ADT).
*Unlocks:* inference (effect row unification), ownership (!Consume),
  capability proofs (!Alloc, !Clock), handler subsumption checks.

What to do:
- Boolean algebra: `+` union, `-` subtraction, `&` intersection,
  `!` negation, `Pure` = empty row.
- normalize_row: canonical form for comparison.
- row_subsumes: `row_a ⊇ row_b` — the gate for handler installation.
- union_row, diff_row, inter_row: algebraic operations.
- **Format:** Each algebraic operation reads as a mathematical
  transformation. Chain normalize → compare → decide via `|>`.
  This file is pure functions on data — the cleanest possible Inka.

*Exit:* `row_subsumes(EfClosed([Alloc, IO]), EfClosed([IO]))` = true.
`diff_row(row, EfClosed([Alloc]))` removes Alloc. `!Alloc` negation
works via normalize + subsumption.

---

**Step 4: The Engine — `infer.ka`** (Spec 04)

*Depends on:* Step 1 (types), Step 2 (graph — writes bindings into
  the live graph), Step 3 (effects — unifies effect rows).
*Unlocks:* lowering (reads the post-inference graph), query (reads
  env + graph), ownership (runs inside this walk).

What to do:
- One walk. `infer_expr`, `infer_stmt`, `generalize`, `instantiate`.
- Unification against the graph (not a sidecar subst).
- Effect row unification via Step 3's algebra.
- Ownership tracking runs INSIDE this walk — `perform consume(name)`
  at every `own`-parameter use (spec 07 piggybacks on spec 04).
- Error handling: Hazel pattern. Mismatch → NErrorHole, continue.
  Never halt on a type error.
- **Format:** The inference walk is the canonical `|>` pipeline
  through AST nodes. `match node.body { ... }` arms are the dispatch.
  Effect performs (`perform graph_bind`, `perform env_extend`) replace
  all argument-threading. This file demonstrates WHY effects eliminate
  state-passing.

*Exit:* `infer_program(ast)` populates graph handles for every node.
`perform env_lookup(name)` returns typed schemes. No subst sidecar.

---

**Step 5: The Env — `env_handler` in `pipeline.ka`** (Spec 04)

*Depends on:* Step 1 (types: Env, Scheme), Step 4 (inference uses
  EnvRead + EnvWrite effects).
*Unlocks:* inference can run end-to-end (it needs both graph_handler
  and env_handler installed to function).

What to do:
- env_handler with real scoped binding stack:
  `with entries = [], scopes = []`
  - `env_extend(name, scheme, reason)` → prepend to entries
  - `env_lookup(name)` → linear scan, return Option((Scheme, Reason))
  - `env_scope_enter()` → push len(entries) onto scopes
  - `env_scope_exit()` → truncate entries to top-of-scopes mark, pop
- env_with_primitives: install Int, String, Bool, List, Option.
- **Format:** The handler uses `with state = ...` syntax just like
  graph_handler. The scoping mechanism (push/pop mark) is elegant
  Inka — no mutable pointers, just functional list truncation.

*Exit:* env_handler + graph_handler together allow inference to run.
`env_lookup("x")` after `env_extend("x", ...)` returns the scheme.
Scoping works: enter → extend → exit → lookup returns None.

---

**Step 6: The Observer — `lower.ka`** (Spec 05)

*Depends on:* Step 2 (graph — reads via LookupTy), Step 4 (inference
  populated the graph), Step 5 (env — reads via EnvRead).
*Unlocks:* emit (consumes LowIR), the proof that inference produced
  a complete graph.

What to do:
- Live-observer lowering. Every `lexpr_ty(e)` calls
  `perform lookup_ty(e.handle)`. No cached types. No subst.
- Handler elimination: classify_handler (TailResumptive / Linear /
  MultiShot). Monomorphic calls → direct `call $h_op`. Polymorphic
  → evidence-passing thunk.
- No `_ => TUnit` fallback. No wildcard arms. Exhaustive.
- **Format:** `lower_expr(node)` is a clean `match node.body { ... }`
  dispatch. The monomorphic check at each CallExpr reads:
  ```
  if monomorphic_at(node.handle) { LCall(...) }
  else { emit_evidence_thunk(...) }
  ```
  This is where the graph's power becomes visible — lowering is a
  PURE READER of the inference substrate, proven read-only by its
  effect row (`with SubstGraphRead` — no Write).

*Exit:* `lower_program(ast)` produces LowIR. Every node has a handle
that chases to NBound or NErrorHole. No NFree survives.

---

**Step 7: The Spine — `pipeline.ka`** (Spec 04, 05, 06, 10)

*Depends on:* Steps 1–6 (all components exist). This is assembly.
*Unlocks:* the compiler runs end-to-end. Compilation is one
  expression. `inka query` works.

What to do:
- `compile`, `check`, `query` as `|>` + `~>` topology:
  ```
  fn compile(source) =
    source
        |> lex
        |> parse
        |> infer_program
        |> lower_program
        |> emit_module
        ~> mentl_default
        ~> verify_ledger
        ~> env_handler
        ~> graph_handler
        ~> diagnostics_handler
  ```
- `check` = same pipeline minus `lower_program |> emit_module`.
- `query` = same pipeline minus lowering, plus `~> query_handler`.
- Every `~>` line has a capability-stack comment explaining what
  effects it handles and what passes through.
- **Format:** THIS IS THE FILE. The `~>` chain is the visual proof
  that Inka solves Inka. The handler stack IS the compiler's
  architecture, visible on the page. Sequential `|>` flows down.
  Block-scoped `~>` wraps the whole chain. The shape of this file
  IS the shape of the compiler.

*Exit:* `compile(source)` produces WAT. `check(source)` produces
diagnostics. `query(source, question)` returns structured answers.
One expression each.

---

**Step 8: The Emitter — `emit.ka`** (Spec 05)

*Depends on:* Step 6 (lower — produces LowIR), Step 2 (graph —
  `ty_to_wasm` reads handles via LookupTy).
*Unlocks:* actual WASM output. The compiler produces something
  runnable.

What to do:
- Port from existing `std/backend/wasm_emit.ka`.
- `ty_to_wasm` reads `perform lookup_ty(h)` — live, not cached.
- Emit WAT text format (not binary — keep debugging easy).
- **Format:** WASM emission is inherently sequential — `|>` chains
  of instruction emission. Each function → section → module builds
  up via `|>`.

*Exit:* `emit_module(low_ir)` produces valid WAT that passes
`wasm-validate`.

---

**Step 9: The Runtime — `runtime/memory.ka`** (Spec 06)

*Depends on:* nothing architecturally, but produces the runtime
  primitives that emitted WASM calls into.
*Unlocks:* compiled programs actually run.

What to do:
- Bump allocator as a handler (Alloc effect).
- String ops: length, concat, compare, slice — all via Memory effect.
- List ops: cons, head, tail, length — all via Memory effect.
- **No val_concat. No val_eq.** These are the exact functions that
  caused v1's type drift. They do not exist.
- **Format:** Memory operations are `perform load_i32`, `perform
  store_i32` — clean effect-mediated access. The allocator handler
  demonstrates `with state = ...` for bump pointer tracking.

*Exit:* String and list operations work in compiled output.
Bump allocator serves all allocation needs.

---

**Step 10: The Entry — `main.ka`**

*Depends on:* Steps 7–9 (pipeline, emit, runtime all exist).
*Unlocks:* `inka.wasm` — the compiler is a runnable binary.

What to do:
- Read stdin (source code).
- Call `compile(source)`.
- Write WAT to stdout.
- Install top-level handlers: stderr_diagnostics, real Memory.
- **Format:** This file is ~30 lines. It is the simplest possible
  Inka program:
  ```
  fn main() =
    read_stdin()
        |> compile
        |> write_stdout
        ~> stderr_diagnostics
        ~> memory_handler
  ```

*Exit:* `wasmtime run inka.wasm < source.ka > output.wat` works.

---

**Step 11: The Catalog — `docs/errors/*.md`**

*Depends on:* Steps 1–10 (every error code used in source exists).
*Unlocks:* Mentl's teach_error can load canonical explanations.

What to do:
- Walk every `perform report(...)` call in the codebase.
- Verify each error code has a `docs/errors/<CODE>.md` entry.
- Each entry: Summary, Why it matters, Canonical fix, Example.
- **Format:** Markdown. Elm/Roc/Dafny catalog pattern.

*Exit:* Every error code in source has a catalog entry. Zero orphans.

---

**Step 12: The Proof — Integration**

*Depends on:* All of the above.
*Unlocks:* Phase 2 (bootstrap translator has something to compile).

What to do:
- `inka query` on every file in `std/compiler/`.
- Verify: zero duplicate ADTs, zero phantom references, zero dead
  imports, every handler threads real state.
- Run the exit gate tests:
  ```
  inka_compile bootstrap/tests/counter.ka → valid WAT
  inka_compile bootstrap/tests/pattern.ka → valid WAT
  Both WATs run correctly under wasmtime.
  ```
- Every file follows Anchor 6: pipe topology expressed, canonical
  formatting applied, handler composition via `~>`.

*Exit:* Phase 1 is complete. The VFINAL codebase compiles test
programs to working WASM. Every file is in its most powerful form.
The cascade is closed. Inka is ready to compile herself.

---

### Phase 2 + Phase 3 — Bootstrap + First Light *(deferred post-cascade)*

The original Phase 2 (bootstrap translator) and Phase 3 (self-compilation fixed point at `first-light`) were the project's traditional sequel to Phase 1. **They are explicitly out of mind for the current execution.**

Per the active session plan (`/home/suds/.claude/plans/sight-so-absorb-what-s-majestic-taco.md` — the audit-integrated cascade Σ → Ω → γ): bootstrap design fails on an inconsistent graph or a graph dressed in other languages' clothes. The Ω + γ cascade closes both. When Inka's substrate is genuinely Inka-native at every level AND simulation-verified end-to-end, bootstrap becomes DISCOVERABLE rather than designed — and the conversation about translator approach (Rust / Python / LLM-generated / hand-written WAT) returns with the substrate in its ultimate form.

The bootstrap discussion will resume post-cascade. Until then, verification is by simulation, walkthrough, and audit — not by compilation.

The full historical Phase 2 + Phase 3 specifications (translator options, exit gates, fixed-point diff procedure) are preserved in git history (commits before this prune) for reference at the post-cascade conversation.

---

## Post-First-Light Arcs

Per commitment #3: each arc is independent and scoped separately.
These are not "someday" features — they are the capabilities that
make Inka unprecedented. Phase 1 lays the structural foundation for
every arc. Each arc is a handler swap, a new handler, or an
extension to the graph. No arc requires rewriting the compiler core.

Arc designs live in `docs/DESIGN.md` (chapter 9 — *What Dissolves*)
and in this document's per-arc sections below. When an arc picks up,
capture the concrete implementation in the relevant rebuild spec or
in a dedicated design doc at that time — the arcs are sketched here,
not locked.

### Arc F.1 — Refinement Verification

`verify_ledger` → `verify_smt`. Handler swap; source unchanged.

**What it does:** Every `type Port = Int where 1 <= self && self <=
65535` annotation that Phase 1 accrues as a `V_Pending` obligation
now gets DISCHARGED at compile time via SMT. Invalid call sites
fail with `E_RefinementRejected`.

- Z3 for nonlinear arithmetic.
- cvc5 for finite-set/bag/map reasoning.
- Bitwuzla for bitvectors.
- **Research:** Liquid Haskell 2025, Generic Refinement Types POPL 2025.
- **Spec:** 02-ty.md (TRefined), 06 (Verify effect).

**What it unlocks:** Compile-time proof that array indices are in
bounds, that ports are valid, that buffer sizes are sufficient.
Erased at runtime — zero cost.

---

### Arc F.2 — LSP + ChatLSP

Query + Mentl tentacles wrapped in JSON-RPC. No new substrate.

**What it does:** Every `inka query` command becomes an LSP method:
- `textDocument/hover` → `QTypeAt` + `teach_why`
- `textDocument/completion` → `Synth` effect
- `textDocument/diagnostics` → `Diagnostic` + `teach_error`
- `textDocument/codeAction` → `Explanation.fix`

ChatLSP extension: typed context (bindings, effect rows, ownership)
sent to LLM for completion. `!Alloc` masks free prompt budget.

- **Research:** ChatLSP OOPSLA 2024.
- **Spec:** 08-query.md, 09-mentl.md.

**What it unlocks:** IDE intelligence that is the compiler's own
reasoning, not a separate ML model. Mentl teaches; the IDE renders.

---

### Arc F.3 — REPL + Multi-Shot Continuations

Replace `load_chunk`. Execute arbitrary Inka expressions. Formalize
the three multi-shot continuation models.

**What it does:**
- REPL: compile-to-WASM per line or LowIR interpreter. The REPL is
  a handler that redirects emitted WASM to an in-process evaluator.
- Multi-shot continuations with three semantic models:
  1. **Replay** (default) — re-execute thunk from top. Independent
     runs. O(work) per invocation. No allocation.
  2. **Fork** — `resume` called N times in one handler arm. Each
     call clones the continuation from the perform site. O(state)
     per clone. Powers backtracking search, SAT, amb/choose.
  3. **State machine** — compile-time transform of handled body
     into numbered states. O(struct) per clone. Subsumes replay
     and fork. Native backend (F.5) target.
- **Critical interaction:** `!Alloc` computations can be REPLAYED
  but NOT FORKED (forking allocates the continuation struct). The
  compiler enforces this via effect rows.
- Handler-local state at fork point: each fork gets a SNAPSHOT.
  Functional `with state = ...` update means mutations in one fork
  don't affect others.

- **F-note:** `multi-shot-continuations.md` (329 lines, detailed)
- **Spec:** 08-query.md, 06-effects-surface.md (@resume markers).

**What it unlocks:** Backtracking search (4-Queens validated),
hyperparameter sweep, Monte Carlo, speculative execution — all as
handler strategies over the same computation code.

---

### Arc F.4 — Scoped Arenas + Memory Strategy

The arc where Inka proves GC is a handler.

**What it does:**
- `temp_arena(size)` handler — O(1) region free, deterministic.
  Intercepts `alloc(size)` calls. When scope drops, reset pointer
  to zero — instant, deterministic "garbage collection."
- Ownership system prevents use-after-free: if `similar` escapes
  `temp_arena` scope, compiler forces copy into parent allocator.
- `own` + deterministic drop for game/embedded contexts.
- Multi-shot × arena semantics (the D.1 question): three policies:
  1. **Replay safe** — re-execute from perform site.
  2. **Fork deny** — error at capture if continuation escapes arena.
  3. **Fork copy** — deep-copy arena data into caller's arena.
- **Diagnostic arenas** — wrap memory-heavy mentorship code
  (Levenshtein suggestions, O(N³) string ops) in `temp_arena`.
  Mentorship code can be as sloppy as needed — arena isolates it.
  Zero-cost teaching.
- **Thread-local Alloc** — each thread gets its own Alloc handler.
  No global allocator mutex. Concurrency scales with zero locking.

- **F-note:** `scoped-memory.md` (73 lines, clear design)
- **Research:** Perceus PLDI'21, FBIP PLDI'24, bump-scope, Vale.
- **Spec:** 07-ownership.md (Consume × Alloc), 02-ty.md (TCont).

**What it unlocks:** Four memory models from one mechanism:

| Context | Handler | Guarantee |
|---|---|---|
| Compiler (batch) | `bump_allocator` | Allocate forward, exit frees all |
| Server (request) | `temp_arena(4MB)` | O(1) region free per request |
| Game (frame) | `own` + drop | Deterministic, zero-pause |
| Embedded/DSP | `!Alloc` | Proven zero allocation |
| Diagnostics | `diagnostic_arena` | Unbounded mentorship, zero cost |

---

### Arc F.5 — Native Backend

Hand-rolled x86-64 from LowIR. The capstone performance arc.

**What it does:** LowIR → native machine code. No WASM, no VM.
- Lexa zero-overhead handler compilation: direct stack-switching.
- Tail-resumptive handlers (85%) → `call` instruction.
- Linear handlers → state machine.
- Multi-shot → heap-allocated continuation struct.

- **Research:** Lexa OOPSLA 2024, Multiple Resumptions ICFP 2025.

**What it unlocks:** Performance parity with C/Rust for
compute-bound workloads. The Inka-compiles-itself loop runs at
native speed. DSP handlers meet real-time deadlines.

---

### Arc F.6 — Mentl Consolidation

The teaching substrate crystallized. The AI-obsolescence thesis
made concrete.

**What it does:** Crystallize `mentl.ka` further. The five-op Teach
surface and the speculative oracle ship in Phase 1 as the structural
substrate; F.6 expands the reasoning depth (longer Why-chains,
richer error catalog, higher-leverage gradient suggestions) and
tightens the applicability tags on Mentl-proposed patches.

- **Research:** Elm/Roc/Dafny error catalogs, Hazel marked holes.
- **Spec:** 09-mentl.md.

**What it unlocks:** The compiler becomes the tutor. Every error
teaches. Every annotation unlocks power. The gradient from beginner
to expert is continuous — no cliff, no separate "advanced mode."

---

### Arc F.7 — Incremental Compilation

Per-module caching via `.kai` interface files + Salsa 3 overlay.

**What it does:**
- Each `.ka` file is checked independently against the envs of its
  dependencies. Result: a fully-resolved type environment.
- After checking, serialize env to `<module>.kai` (Inka Interface):
  `[(name, Type, Reason)]` triples, content-hash keyed.
- On recompile: if `.kai` exists AND hash matches source, load env
  from cache (skip checking). Otherwise re-check and write cache.
- Topological module ordering: imports form a DAG. Modules checked
  in dependency order. No inference state leaks across modules.
- **Memory impact:** Instead of one `check_program` call on 10K+
  lines (GB-scale), each module checks independently (~20-50MB).
  Peak memory: the largest single module, not the sum.
- `graph_fork(module_name)` creates a persistent overlay per module.
- Grove CmRDT structural edits for cross-module re-inference.

- **F-note:** `incremental-compilation.md` (153 lines, detailed)
- **Research:** Salsa 3.0, Grove POPL 2025, Polonius 2026 alpha.
- **Spec:** 00-substgraph.md (graph_fork, epoch overlay).

**What it unlocks:**
- Sub-second recompilation for large codebases.
- Parallel compilation: independent modules check concurrently.
- LSP integration: module envs are the hover/completion source.
- Gradient dashboard: per-module verification scores from cached envs.

---

### Arc F.8 — Concurrency + Parallelism

Deterministic parallelism via handler swap.

**What it does:**
- `Parallel` handler: `<|` branches run concurrently (not just
  sequentially).
- Vale-style `!Mutate` region-freeze for "N readers, no writers"
  proof via effect algebra.
- Fork-join over `><` parallel compose — each branch gets its own
  stack.
- Effect row ensures no data races: `!Mutate + !IO` proves
  deterministic parallelism.

- **Research:** Vale immutable regions, Austral linear capabilities.
- **Spec:** 10-pipes.md (`<|` and `><` semantics).

**What it unlocks:** Source-unchanged parallelism. Same Inka code,
different handler. Sequential for debugging, parallel for production.
The pipe topology SHOWS the parallelism opportunity — `<|` is a
fork point, `|>` convergence is a join.

---

### Arc F.9 — Package + Module System

The handler IS the package. The `~>` chain IS the manifest. There
is no package manager. There is only the compiler.

**Thesis:** npm/Cargo/pip build ad-hoc untyped mini-languages (JSON,
TOML) to describe dependency graphs because their host languages
can't carry the information. In Inka, the language already knows
everything: `with Network, IO` replaces `dependencies = ["reqwest"]`.
Effect signatures ARE API contracts. Breaking change = signature
drift. Compatible change = signatures unify. The type checker IS
the version solver.

**What it does:**
- `Package` effect: `fetch(id: Hash) -> Source`,
  `resolve(row: EffRow) -> Hash`, `audit() -> List<Violation>`.
- Registry handlers are swappable: `~> local_cache_pkg`,
  `~> github_pkg`, `~> enterprise_registry_pkg`.
- Content-addressed model: hash = identity, name = resolution via
  handler. There is no lockfile — the hash IS the lock.
- Federation via handler stacking:
  `fetch_deps() ~> local_cache >< github_hub >< community_registry`
- **`inka audit` — the killer MVP.** Walk the `~>` chain in `main()`,
  collect effect rows transitively, print the capability set, suggest
  negations. Zero infrastructure. Runs locally. Mathematically proven
  capability analysis before compilation.
  ```
  $ inka audit main.ka
  Capabilities required:
    - Network (via router_axum)
    - Filesystem (via db_postgres)
  Suggestions:
    - Run sandboxed with `with !Process, !FFI`.
  ```

- **F-note:** `packaging-design.md` (128 lines, complete design)

**What it unlocks:** Package management without a package manager.
Effect signatures replace semver. `inka audit` proves what your
program can and cannot do — no other package manager can offer
mathematically proven capability analysis.

---

### Arc F.10 — ML Framework + Handler Features

Machine learning as proof of thesis. The ten mechanisms composed.

**What it does:**
- **Autodiff as effect.** `Compute` effect for matmul, conv1d, relu,
  softmax. Training handler intercepts + records tape. Inference
  handler just computes. Same model code, different semantics.
- **Optimizer as handler.** `Optimize` effect: `step(param, grad)`.
  SGD = stateless handler. Adam = handler with `m`, `v`, `t` state.
  Same training loop, different optimizer — swap the handler.
- **Refinement-typed tensors.** `type Tensor<T, Shape>` where
  `self.len() == product(Shape)`. Shape mismatches are compile
  errors. `LearningRate`, `Probability`, `BatchSize` as refined
  types — entire categories of ML bugs eliminated at compile time.
- **Hyperparameter search via multi-shot.** `Hyperparam` effect
  with `choose_lr()`, `choose_hidden()`, `choose_dropout()`.
  Handler resumes with each candidate — grid/random/Bayesian are
  handler strategies. Genuinely novel: no framework has language-
  level multi-shot hyperparameter search.
- **DSP-ML unification.** `mfcc` (DSP) and `conv1d` (ML) compose
  through `|>` with no adapter. A learned conv1d can replace a
  hand-designed mel filterbank — the swap is one line.
- **Compilation gates from effect algebra:**
  1. `!IO` → compile-time evaluation (constant folding)
  2. `Pure` → multi-core parallelization (safe, no annotation)
  3. `!IO, !Alloc` → GPU offload (F.5 backend required)
  4. `!Alloc` → embedded deployment (ARM Cortex-M7, Daisy Seed)
- **Progressive ML levels** (L1-L5): pure functional → + effects →
  + ownership → + refinements → full Inka. Never rewrite.
- **Handler parameters.** `handler lowpass(alpha: Float) with
  state = 0.0 { ... }` — named handlers take constructor arguments
  for configurable instantiation.
- **Handler composition.** Inference handler = training handler
  minus tape recording. No DRY violation.
- **Numeric polymorphism.** `Num` typeclass: one `sum` for all
  numeric types instead of `sum`/`sumf` split.

**What it unlocks:** The performance and native control of Rust
with the ergonomics of a functional language. Same model code trains
on desktop, deploys to ARM microcontroller with `!Alloc` proven at
compile time. The pipe topology shows DSP → ML → classification as
one continuous graph.

### Arc G — Rename (Lux → Inka)

One script, one commit. `.lux` → `.ka`. `lux` → `inka` everywhere.
Repo rename via `gh repo rename`. Update all existing file extensions.

---

### Arc H — Examples-as-Proofs

One runnable example per framework-dissolution claim. Each 50-200
lines. Each runs. Each proves a claim from INSIGHTS.md:

- **Web server** — handler swap: same code, different transport.
- **DSP audio** — `<~` feedback loop, `!Alloc` + `Sample` proven.
- **Parser combinator** — effects as backtracking.
- **State machine** — handlers as state transitions.
- **Dependency injection** — handler swap, no framework.
- **Iterator/generator** — `Iterate` effect, `yield` via perform.
- **Error handling** — `~>` per-stage vs block-scoped.
- **Testing** — handler swap for every effect (clock, IO, memory).

Each example demonstrates the five pipe operators where they
naturally express the computation's topology.

---

### Arc I — DESIGN.md Audit

Trim to ≤500 lines. Core manifesto on one read.

---

### Arc J — Verification Dashboard

CI tracks `inka query --verify-debt` count per commit. Pre-F.1
measures accumulation; post-F.1 measures the trend toward zero.

---

## Spec Inventory

All twelve specs in `docs/rebuild/`:

| Spec | File | Governs |
|---|---|---|
| 00 | 00-substgraph.md | SubstGraph, flat array, O(1) chase |
| 01 | 01-effrow.md | EffRow Boolean algebra |
| 02 | 02-ty.md | Ty ADT, TRefined, TCont, Verify |
| 03 | 03-typed-ast.md | Node, Span, Expr, Stmt, Pat, PipeKind |
| 04 | 04-inference.md | HM inference, one walk |
| 05 | 05-lower.md | LowIR, LookupTy, handler elimination |
| 06 | 06-effects-surface.md | All 14+ effects, resume discipline |
| 07 | 07-ownership.md | Consume effect, affine_ledger |
| 08 | 08-query.md | Query effect, forensic substrate |
| 09 | 09-mentl.md | Teach effect, Mentl tentacles |
| 10 | 10-pipes.md | Five verbs, topology, layout rules |
| 11 | 11-clock.md | Clock/Tick/Sample/Deadline family |

---

## Research Integration (2024-2026 bleeding edge)

22 techniques from 2024-2026 papers. **None are invented here.** The
paper-worthy artifact is that Inka composes them into one mechanism.

### Techniques to ADOPT (mapped to files)

| Technique | Source | Lands in |
|---|---|---|
| **Modal Effect Types** — `⟨E₁\|E₂⟩(E) = E₂ + (E − E₁)` as a principled semantics for Inka's `E - F`. Rows and Capabilities are both encodable in modal effects. | [Tang & Lindley POPL 2025](https://arxiv.org/abs/2407.11816) · [POPL 2026](https://arxiv.org/abs/2507.10301) | effects.ka |
| **Affect affine-tracked resume** — type-level distinction of one-shot vs multi-shot; Iris/Coq-mechanized. Directly solves Inka's D.1 (multi-shot × arena). | [Affect POPL 2025](https://iris-project.org/pdfs/2025-popl-affect.pdf) | effects.ka |
| **Koka evidence-passing compilation** — when the graph proves a call site's handler stack is monomorphic, emit `call $h_foo` directly. Kills val_concat drift at compile time. | [Generalized Evidence Passing JFP 2022](https://dl.acm.org/doi/10.1145/3473576) | lower.ka |
| **Perceus refcount + FBIP reuse** — precise RC + in-place update when ownership graph proves unique. Layer-2 memory fallback. | [Perceus PLDI'21](https://www.microsoft.com/en-us/research/wp-content/uploads/2021/06/perceus-pldi21.pdf) | Arc F.4 |
| **Lexa zero-overhead handler compilation** — direct stack-switching, linear vs quadratic dispatch. Makes effects free. | [Lexa OOPSLA 2024](https://cs.uwaterloo.ca/~yizhou/papers/lexa-oopsla2024.pdf) | Arc F.5 |
| **Salsa 3.0 / `ty` query-driven incremental** — flat-array substitution with epoch + persistent overlay. | [Astral ty](https://astral.sh/blog/ty) · [Salsa-rs](https://github.com/salsa-rs/salsa) | graph.ka |
| **Polonius 2026 alpha — lazy constraint rewrite** — location-sensitive reachability over subset+CFG. | [Polonius 2026](https://rust-lang.github.io/rust-project-goals/2026/polonius.html) | graph.ka, own.ka |
| **Flix Boolean unification** — 7% compile overhead for full Boolean algebra over effect rows. | [Fast Boolean Unification OOPSLA 2024](https://dl.acm.org/doi/10.1145/3622816) | effects.ka |
| **Abstracting Effect Systems** — parameterize over the effect algebra so +/-/&/! are instances of a Boolean-algebra interface. | [Abstracting Effect Systems ICFP 2024](https://icfp24.sigplan.org/details/icfp-2024-papers/18) | effects.ka |
| **Hazel marked-hole calculus** — every ill-typed expression becomes a marked hole; downstream services keep working. | [Total Type Error Localization POPL 2024](https://hazel.org/papers/marking-popl24.pdf) | types.ka |
| **ChatLSP typed-context exposure** — send type/binding/typing-context to LLM via LSP. Inka's `!Alloc` effect mask is free prompt budget. | [Statically Contextualizing LLMs OOPSLA 2024](https://arxiv.org/abs/2409.00921) | Arc F.2 |
| **Generic Refinement Types** — per-call-site refinement instantiation via unification. | [Generic Refinement Types POPL 2025](https://dl.acm.org/doi/10.1145/3704885) | Arc F.1 |
| **Canonical tactic-level synthesis** — proof terms AND program bodies for higher-order goals via structural recursion. | [Canonical ITP 2025](https://drops.dagstuhl.de/entities/document/10.4230/LIPIcs.ITP.2025.14) | Arc F (synthesis) |
| **Vale immutable region borrowing** — `!Mutate` on a region delivers "N readers, no writers" proof via existing effect algebra. | [Vale regions](https://verdagon.dev/blog/zero-cost-memory-safety-regions-overview) | Arc F (concurrency) |
| **bump-scope nested arenas** — checkpoints, default-Drop, directly mirrors Inka's scoped-arena-as-handler. | [bump-scope](https://docs.rs/bump-scope/) | Arc F.4 |
| **Austral linear capabilities at module boundaries** — capabilities ARE the transitivity proof. | [Austral](https://borretti.me/article/introducing-austral) | effects.ka |
| **Liquid Haskell 2025 SMT-by-theory** — Z3 for nonlinear arithmetic, cvc5 for finite-set/bag/map, Bitwuzla for bitvectors. | [Tweag 2025](https://www.tweag.io/blog/2025-03-20-lh-release/) | Arc F.1 |
| **Elm/Roc/Dafny error-catalog pattern** — stable error codes + canonical explanation + applicability-tagged fixes. | [Elm errors](https://elm-lang.org/news/compiler-errors-for-humans) | pipeline.ka |
| **Grove CmRDT structural edits** — edits commute; cross-module re-inference becomes a fold over commuting ops. | [Grove POPL 2025](https://hazel.org/papers/grove-popl25.pdf) | Arc F (incremental) |
| **Multiple Resumptions Directly (ICFP 2025)** — competitive LLVM numbers for multi-shot + local mutable state. | [ICFP 2025](https://dl.acm.org/doi/10.1145/3747529) | Arc F (multi-shot) |
| **Applicability-tagged diagnostics** — every "did you mean" emits a structured patch with confidence + effect-row delta. | [rustc-dev-guide](https://rustc-dev-guide.rust-lang.org/diagnostics.html) | pipeline.ka |

### Techniques to REJECT (with one-line reason each)

- **OCaml 5 untyped effects** — self-defeating for Inka's thesis of effect-as-proof
- **Full QTT user-visible quantities** (Idris 2) — annotation burden without provability gain
- **Lean 4 tactic-as-surface** — creates a bimodal language; Inka is one expression language with holes
- **Dafny inline ghost proof bodies** — annotation burden is the adoption killer
- **Python typing-style gradual ambiguity** — "one annotation, multiple semantics" is worse than none
- **Racket teaching-language ladder (BSL→ISL→ASL)** — discrete dialects; use effect capabilities instead
- **`any` escape hatch** — AI-generated TypeScript emits `any` 9× more than human (2025). No `any` in Inka.
- **Projectional editors** — Darklang retreated 2024, Hazel stays research. Text is canonical.
- **Fractional permissions (Chalice/VerCors)** — contracts not inference; wrong direction
- **WasmGC as default memory model** — hides allocation, defeats `!Alloc`; optional backend only
- **Multiparty session types** — still academic; pairwise channel effect suffices
- **Scala 3 `^` capture syntax** — duplicate of effect rows; fractures one-mechanism thesis
- **Datalog Polonius** — officially abandoned (2026 alpha uses lazy constraint rewrite)
- **Autonomous-agent-first DX** — language so strong LLMs are dispensable, not required

### Open research questions Inka can LEAD

Each has no clean published answer; Inka shipping it IS the contribution.

1. **Effect-algebra + refinements + ownership in one decidable system.** Flix has Boolean effects. Liquid Haskell has refinements. Rust has ownership. No one combines all three with HM inference. Inka is the artifact.

2. **Strict fixed-point bootstrap as soundness test.** Byte-identical self-compilation is a stronger soundness property than any existing refinement checker. Methodology contribution.

3. **Multi-shot × scoped arena (D.1).** Affine continuations captured inside a scoped-arena handler. Affect gives type machinery; Inka designs semantics (Replay safe / Fork deny-or-copy).

4. **Cross-module TVar via DAG-as-single-source-of-truth.** Nobody has published on combining Salsa + Polonius for cross-module TVar resolution.

5. **Type-directed synthesis over effect-typed holes.** Synquid synthesizes over pure types. Nobody synthesizes over effect-row-polymorphic refined holes.

6. **Region-freeze as effect negation.** Formalizing `!Mutate ⇒ reference-coercion rights` closes Vale's result without runtime checks.

7. **`!Alloc[≤ f(n)]` quantitative refined effects.** Upgrades Boolean `!Alloc` to bounded. Enables real-time guarantees with size budgets.

8. **FBIP under effect capture.** Koka/Lean don't handle this cleanly. Inka's ownership graph knows which values are unshared — a straight IR pass suffices.

9. **Gradient rungs as handlers on one Capability effect.** Not separate checks but installations unlocking codegen paths. `Pure` installs memoization, `!Alloc` installs real-time, refinement installs SMT.

### The AI obsolescence argument — made concrete

Morgan's load-bearing claim: Inka makes current AI coding tools
dispensable. When is an AI assistant redundant? When the language
provides the three things AI is valued for:

**(a) Inference of what the AI would have filled in.**
`fn f(x: Positive) -> ? with !Alloc = ?` — the compiler knows `?` is
constrained, the synthesizer fills it, the refinement solver verifies.
The LLM was guessing what the type already specified.

**(b) Verification of what the AI would have checked.**
AI-written code that hallucinates cannot type-check — no `any` to hide
behind, effect rows and refinements are mandatory, so the hallucination
surface is zero.

**(c) Teaching the pattern the AI would have suggested.**
The Why Engine + gradient + error catalog means every hover answers
"why this type?" with the full reasoning chain. The compiler is the
tutor the AI would have been — deterministic, verified, cached.

**The one sentence:** Inka doesn't compete with AI; Inka makes AI a
handler on the same Suggest effect the compiler exposes. The code that
gets generated must satisfy types, effects, and refinements written by
humans. AI without Inka hallucinates; AI with Inka cannot.

---

## WASM as Target Substrate

WASM is the right first compilation target:

- **No GC** — Inka doesn't want one. Handlers manage memory.
- **Linear memory** — perfect canvas for bump/arena allocators.
- **Runs everywhere** — browser, wasmtime, cloud edge, embedded.
- **Someone else's maintenance burden** — Bytecode Alliance, Google.
- **Handler elimination maps cleanly** — tail-resumptive (85%) →
  direct `call`. Linear → state machine. Multi-shot → heap struct.
- **Tail call support** — wasmtime implements the proposal.
  `LTailCall` → `return_call`.

A custom VM (`inka.vm`) is not needed. WASM is sufficient. If WASM
ever proves insufficient, `wasm2c` or wasmtime AOT are escape hatches.

---

## Memory Model

| Context | Strategy | Ships |
|---|---|---|
| Compiler (batch) | Bump allocator — allocate forward, never free, exit | Phase 1 |
| Server (request-scoped) | Scoped arena handler — O(1) region free | Arc F.4 |
| Game (frame-scoped) | `own` + deterministic drop | Arc F.4 |
| Embedded/DSP | `!Alloc` — zero allocation, proven by types | Phase 1 (proof); F.4 (enforcement) |

**GC is a handler.** The bump allocator IS a handler:
```lux
handler bump_allocator with ptr = 0 {
  alloc(size) => {
    let aligned = align(ptr, 8)
    resume(aligned) with ptr = aligned + size
  }
}
```

Different programs install different handlers. No runtime GC. No
framework. Handler swap.

---

## Structural Requirements — From Day One

Four structures that MUST be in the codebase from the start. Each,
if omitted, requires re-walking every AST node or every type to
retrofit. The cost of over-designing a field is trivial; the cost
of retrofitting one is measured in weeks.

1. **Ownership annotations in the Type ADT.** `TParam` carries
   `Ownership` (`Inferred | Own | Ref`). Without it, every function
   signature is ambiguous about move vs borrow, and `own.ka` has no
   type-level hook to track linearity. Spec: 02-ty.md.

2. **Source spans on every AST node.** Full `Span(start_line,
   start_col, end_line, end_col)` — not point positions. LSP hover,
   marked holes (Hazel), error localization, teaching-mode
   highlighting all need spans. Non-negotiable. Spec: 03-typed-ast.md.

3. **Resume discipline markers on effect ops.** `@resume=OneShot |
   MultiShot | Either`. Without this, Arc F.3 (REPL) and F.4 (arenas
   × multi-shot) must re-architect handler representation. Affects
   handler elimination tier classification. Spec: 06-effects-surface.md.

4. **Error codes as first-class Diagnostic fields.** `report` carries
   `code: String` and `applicability: Applicability`. Every `perform
   report(...)` site includes the structured code. Catalog entries in
   `docs/errors/`. Spec: 06-effects-surface.md.

**Rule:** before writing any new code, check the effect surface
(spec 06) and the ADT specs (02, 03). If the structure is there,
it's in scope. If only the runtime/handler behavior is described,
it's an F arc.

---

## Out of Scope — Audited

### Fully out of scope (not touched by Phase 1-3)

- **Native backend (Arc F.5).** Hand-rolled x86 from LowIR.
- **Projectional AST.** Rejected. Text is canonical.
- **Fractional permissions.** Shelved; Vale region-freeze via
  `!Mutate` subsumes.
- **ML / DSP framework formalization.** Downstream; uses Inka,
  not part of Inka.
- **Multi-shot × arena semantics (D.1).** Structure in specs;
  handler logic in Arc F.4.

### Structure IN scope (Phase 1), implementation OUT (Arc F)

- **Refinement types.** IN: `TRefined(Ty, Predicate)` as a Ty
  variant. Inference handles it structurally. `Verify` effect with
  `verify_ledger` accumulates `V_Pending` obligations. OUT: Z3/cvc5
  binding that discharges predicates (Arc F.1 handler swap).

- **LSP.** IN: `inka query` IS the forensic substrate. Every query
  mode maps to an LSP method. OUT: JSON-RPC server, ChatLSP
  extensions (Arc F.2).

- **Scoped arenas.** IN: `Alloc` effect signature. `!Alloc` negation
  propagates. `own.ka` treats `Consume` and `Alloc` as peers. OUT:
  actual `temp_arena` handler (Arc F.4).

- **REPL.** IN: `inka query` covers read-check-explain. OUT:
  execute-arbitrary-source runtime (Arc F.3).

---

## Risk Register

| Risk | Mitigation |
|---|---|
| VFINAL has bugs that surface during self-compilation | `inka query` forensics; fix in Phase 1, re-bootstrap |
| Bootstrap translator takes longer than expected | Use lux3.wasm as temporary bootstrapper if its parser handles the syntax |
| Handler state syntax (`with state = ...`) has edge cases | 85%+ of handlers are tail-resumptive → trivial to translate |
| WASM stack overflow from deep recursion | Emit `return_call` for tail calls; wasmtime supports the proposal |
| Phase 1 stretches too long | Codebase is ~80% written. Remaining work is structural fixes, not new code. |

---

## Crystallized Insights (INSIGHTS.md, 2026-04-17)

Seven load-bearing truths that guide all implementation:

1. **The Handler Chain Is a Capability Stack.** `~>` ordering is a
   trust hierarchy. Outermost = least trusted. Compiler-proven.
2. **The Five Verbs Are a Complete Topological Basis.** Any directed
   graph decomposes into `|>`, `<|`, `><`, `~>`, `<~`. Proven.
3. **Visual Programming in Plain Text.** Newlines are semantic tokens.
   The shape of the code IS the computation graph.
4. **Feedback (`<~`) Is Inka's Genuine Novelty.** No other language
   makes back-edges visible and checkable.
5. **Effect Negation Is Strictly More Powerful.** `!E` proves absence.
   Rust+Haskell+Koka+Austral combined can't do this.
6. **The Graph IS the Program.** SubstGraph + Env is the universal
   representation. Everything else is a handler projection.
7. **Backward Bootstrap.** Write the perfect compiler unconstrained.
   Build a disposable translator to compile it once. Delete forever.
   The fixed point (`diff inka2.wat inka3.wat → empty`) IS soundness.

---

## Key Documents

| Document | Role |
|---|---|
| **docs/PLAN.md** | THIS FILE. The single roadmap. |
| **docs/rebuild/00–11** | The 12 executable specs. |
| **docs/INSIGHTS.md** | Core truths. Living compendium. |
| **docs/DESIGN.md** | Language manifesto. Chapter 9 describes the F-arcs at thesis level. |
| **docs/errors/** | Error catalog (prefix-kind string codes). |
| **CLAUDE.md** | Session Zero + seven anchors for AI assistants. |
