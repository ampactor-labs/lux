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

- **Phase II landings (post-cascade, in-session):**
  - **FS substrate** (1debfdc) — Filesystem effect + WASI preview1
    path_open / fd_close / path_create_directory /
    path_filestat_get + wasi_filesystem handler. First post-
    cascade effect; exercises the substrate's discipline for
    adding new effects cleanly.
    Walkthrough: `docs/rebuild/simulations/FS-filesystem-effect.md`.
  - **IC cluster** (0116d5d, 573879c, b0008dd, 0b27b0c) — cache.ka
    (KaiFile record, FNV-1a hash, env serialization round-trip),
    driver.ka (DAG walk + cache hit/miss + env install),
    pipeline+main wiring through driver_check. `inka check
    <module>` operates incrementally; first post-cascade
    closure of drift mode 10 ("the graph as stateless cache").
    Walkthrough: `docs/rebuild/simulations/IC-incremental-compilation.md`.

- **Integration trace (post-cascade):** `docs/traces/a-day.md`.
  One developer, one project (Pulse: real-time audio + browser UI +
  cloud server + training variant), one day. Every surface either
  fires `[LIVE]`, is `[LIVE · surface pending]`, or is one of three
  named `[substrate pending]` gaps: LFeedback state-machine lowering,
  teach_synthesize oracle conductor, runtime HandlerCatalog effect.
  Supersedes the per-domain DESIGN.md Ch 10 simulations as the
  integration artifact (those remain for thesis-level promises).
- **Bootstrap translator.** Not started; out of mind until Phase II
  Priority 1 closes.
- **Error catalog.** String-coded (prefix-kind + self-documenting
  suffix). See `docs/errors/README.md` for the convention.
- **Language rename:** Lux → **Inka** (mascot: **Mentl**, an octopus).
- **File extension:** `.ka` — the last two letters of Inka.

---

## Pending Work — single source of truth

Strictly ordered by what unblocks what. Every item links to its
walkthrough (existing or to-be-written) and its phase position.
When an item lands, mark it `[LANDED]` here AND update the matching
tag in `docs/traces/a-day.md`.

### Three substrate gaps (Phase II Priority 1; ~200 lines total)

1. **`LFeedback` state-machine lowering** — emit-side rewrite of
   `<~ spec` to a state-machine LIR. Templates in
   `docs/rebuild/simulations/H3.1-parameterized-effects.md` plus
   the `<~` discussion in DESIGN.md Ch 2.5. Walkthrough TBD as
   `simulations/LF-feedback-lowering.md` before code freezes.
   ~100 lines emit-side.
2. **`teach_synthesize` oracle conductor** — composed handler in
   mentl.ka driving checkpoint → apply_annotation_tentatively →
   verify → commit-or-rollback over gradient candidates. Substrate
   pieces all exist. Walkthrough section already in
   `simulations/H5-mentl-arms.md`; expand to its own
   `simulations/TS-teach-synthesize.md` as design questions
   surface. ~50-80 lines.
3. **Runtime `HandlerCatalog` effect** — convert the static table
   in mentl.ka to an effect with runtime registration. Walkthrough
   section in H5-mentl-arms.md already names the design.
   ~40 lines.

### Phase II surface handlers (Priority 1, depends on substrate gaps)

4. **LSP handler** — wraps `inka query` in JSON-RPC; couples to
   `driver_check` via `textDocument/didChange` for incremental
   re-check. Walkthrough TBD as `simulations/LSP-language-server.md`.
   The integration trace `docs/traces/a-day.md` describes every
   surface this lands; flip those tags from `[LIVE · surface
   pending]` to `[LIVE]` as it ships.

### Phase II Priority 2 (deployment scenarios)

5. **Audit-driven linker dead-code severance** — reads
   `AuditReport.severable`; drops WASM imports for proven-severed
   capabilities. Walkthrough TBD.
6. **Multi-backend emit** — per-target handler variants on
   `backends/` (browser, server, trainer, native). Walkthrough TBD;
   shape mirrors `backends/wasm.ka`'s structure.

### Phase II Priority 3 (specific programs)

7. **Thread effect + per-thread region minting** — Walkthrough TBD.
8. **RPC/actor handler** — `~>` boundary handler that bifurcates
   emit and serializes the cross-wire state record. Walkthrough TBD.
9. **Autodiff handler** — concrete ~15 lines per DESIGN.md 10.2.
10. **SIMD intrinsic emission** — recognize `tanh` / `gain` etc.
    as mappable to `v128.*` WAT opcodes.

### Phase II Priority 4 (polish)

11. Commit message synthesis from graph provenance DAG.
12. `inka rename` CLI handler.
13. `///` docstring handler.

### Phase II open follow-ups (cascade peers)

14. **IC.3 — graph chase walks overlays** — per-module overlay
    separation. Lands when name collisions across modules become
    load-bearing. Driver currently merges envs flat; correct for
    today's project.
15. **Cache format binary v3** — only if the textual v2 format
    measures as a bottleneck. v2 round-trips name + Scheme +
    SchemeKind; Reasons regenerate as placeholders on cache load.
16. **Cache dependency-hash invalidation** — currently source-hash
    only; full chain (cache hit on M requires every dep's recorded
    imports_hashes match dep's CURRENT hash) lives in IC v2 of
    `driver_check_module`. Substrate ready; policy adjustment small.

### Phase III (deferred until Phase II Priority 1 closes)

17. **Bootstrap translator** — written as a direct trace of cascade
    walkthroughs in any language (Rust / Python / hand-WAT —
    decided at that moment). ~3-5K lines. Deleted forever after
    Phase IV closes.

### Phase IV

18. **First-light** — `diff inka2.wat inka3.wat` empty.

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

## The Work: Four Phases

Phases I–IV replace the earlier "Three Phases" framing (Write VFINAL,
Bootstrap, First Light). What actually closed wasn't "write VFINAL
files"; it was the γ cascade — nine handles, ten crystallizations,
nine named drift modes, three substrate gaps named and scoped. The
work that remains is installing handler projections on the closed
substrate; bootstrap comes after.

### Phase I — γ cascade — CLOSED

The substrate is Inka-native at every layer. See
`docs/rebuild/simulations/H*.md` for per-handle reasoning and
`docs/traces/a-day.md` for integration verification.

Landings (chronological):
- **Σ** — SYNTAX.md canonical syntax
- **Ω.0–Ω.4** — audit sweeps + parser refactor (str_eq Bool sweep,
  list_extend_to substrate, Token ADT, full parser match-dispatch)
- **Ω.5** — frame consolidation (parallel arrays → records)
- **H6** — wildcard audit (exhaustive ADT matches across substrate)
- **H3** — ADT instantiation (SchemeKind, LMakeVariant tag_id,
  LMatch cascade, exhaustiveness check)
- **H3.1** — parameterized effects (EffName ADT; `Sample(44100)`
  structurally distinct from `Sample(48000)`)
- **H2** — structural records (MakeRecordExpr, LMakeRecord,
  PRecord with field-puning desugar)
- **HB** — Bool transition (TBool deleted; nullary-sentinel ADT;
  heap-base threshold discriminator for mixed-variant types)
- **H1** — evidence reification in full (LMakeClosure absorbs
  LBuildEvidence; BodyContext effect; real LEvPerform offset
  arithmetic; handler arm fn indexing via LDeclareFn; transient
  evidence at poly-call sites)
- **H4** — region escape in full (tag_alloc/check_escape; region-
  join for compound types per H4.1)
- **H2.3** — nominal record types (`type Person = {...}`)
- **H5 substrate** — Mentl's arms (AWrapHandler annotation;
  AuditReport records; severance + capability unlocks)

Net effect: every layer from character → token → AST → typed AST →
LIR → WAT is Inka-native. No primitive special cases. No string-
keyed-when-structured drift. No parallel-arrays-instead-of-record.
No int-mode-when-ADT. Records are the handler-state shape
everywhere. Row algebra is one mechanism over four element types.
The heap has one story.

### Phase II — Handler projection — IN FLIGHT

Every surface that exposes the substrate to users (editors,
deployment targets, concurrency, RPC, ML, audit-to-linker) is a
handler. Phase II installs them. Three of the items are genuine
substrate gaps, not surfaces — named explicitly below.

Priority order (what unblocks what):

**Priority 1 — unblocks developer use. The compiler must answer in
conversational latency; anything slower is the graph being
disrespected by the driver.**

- **Incremental compilation** *[LANDED — substrate]* — per-module
  `.kai` cached envs (cache.ka), module DAG walk + cache hit/miss
  (driver.ka), source-hash invalidation, env reconstruction from
  cache. The Filesystem effect (FS substrate) lands underneath,
  exposing path_open/fd_close/path_create_directory/
  path_filestat_get to the driver via wasi_filesystem handler.
  `inka compile <module>` and `inka check <module>` route through
  driver_check; cold compile equals today's behavior, warm
  compile after no-op or leaf-edit returns sub-second. Drift
  mode 10 ("the graph as stateless cache") closed at driver
  level. IC.3 (per-module overlay separation in graph chase)
  deferred until name collisions across modules become
  load-bearing.
- **LSP handler** — wraps `inka query` in JSON-RPC; maps
  `textDocument/hover` → `QTypeAt` + `QWhy`, `textDocument/rename` →
  cross-module graph rebind, `textDocument/codeAction` → `Explanation.fix`,
  `textDocument/didChange` → incremental re-check (shared with above).
  Substrate already queryable; what pends is the JSON-RPC handler.
- **`teach_synthesize` oracle conductor** `[substrate pending]` — the
  composed handler that drives checkpoint → apply_annotation_tentatively →
  verify → commit-or-rollback in a loop over gradient candidates. Substrate
  pieces all exist; the conductor that sequences them is ~50-80 lines.
- **`LFeedback` state-machine lowering** `[substrate pending]` — emit-
  side rewrite of `<~ spec` to a state-machine LIR (handler-local state
  slot for the delayed sample; Z-transform structure for DSP; RNN hidden-
  state for training). The verb, row, type-inference all fire; emit
  stubs.

**Priority 2 — unblocks deployment scenarios:**
- **Audit-driven linker dead-code severance** — reads
  `AuditReport.severable`, issues `--drop-import` at WAT → WASM.
- **Multi-backend emit** — per-target handler variants on `backends/`
  (browser, server, trainer, wasi). Today's single `backends/wasm.ka`
  generalizes; each target adds a handler.
- **Runtime `HandlerCatalog` effect** `[substrate pending]` — today's
  static `catalog_handled_effects` table becomes an effect-based
  registry. User-defined handlers register at module load; Mentl's
  `AWrapHandler` proposal reads the registry.

**Priority 3 — unblocks specific programs:**
- **Thread effect + per-thread region minting** — `spawn(f)` op;
  per-thread handler install pattern; region id per thread.
- **RPC/actor handler** — `~>` boundary handler that bifurcates
  emit and serializes the cross-wire state record.
- **Autodiff handler** — concrete ~15 lines per DESIGN.md 10.2;
  records tape, resumes with forward values, `backward()` walks
  the tape in reverse.
- **SIMD intrinsic emission** — recognize `tanh`, `gain`, etc. as
  mappable to `v128.*` WAT opcodes.

**Priority 4 — polish, not load-bearing:**
- Commit message synthesis from graph provenance DAG
- `inka rename` CLI handler
- `///` docstring handler (render from graph projection)

**Exit condition:** every `[LIVE · surface pending]` and every
`[substrate pending]` marker in `docs/traces/a-day.md` flips to
`[LIVE]`. The trace becomes the scoreboard.

### Phase III — Bootstrap

Deliberately last. A one-shot translator (Rust / Python / hand-
written WAT — language TBD at that moment) that reads the closed
substrate and produces the first `inka.wasm`. The translator is
written as a DIRECT TRACE of the cascade simulations, not as a
separate interpretation — this is the mitigation for the main risk
(a bug in the translator corrupts the seed).

Scope estimate: ~3-5K lines of whichever language, reading the
substrate at its walkthrough-verified form. Deleted forever after
Phase IV closes.

### Phase IV — First-light

The soundness proof:

```
bootstrap/translate std/compiler/*.ka -o inka.wasm       # one-shot
cat std/compiler/*.ka | wasmtime run inka.wasm  > inka2.wat
wat2wasm inka2.wat -o inka2.wasm
cat std/compiler/*.ka | wasmtime run inka2.wasm > inka3.wat
diff inka2.wat inka3.wat                                  # empty
```

When the diff is empty, the substrate is self-compiling byte-
identically. Bootstrap deletes. Inka is. Post-first-light arcs
(the Phase II handler projections that weren't on the critical
path) continue as ongoing work, not as a separate phase.

---

## The Three Substrate Gaps

Three — and only three — genuine substrate pieces remain.
Everything else is handler projection on the closed cascade. Each
gap lives within a Phase II Priority 1 item.

1. **`LFeedback` state-machine lowering.** At emit, `LFeedback(handle,
   body, spec)` currently emits `;; <~ feedback (iterative ctx)` as
   a stub. The verb, row, type inference, and AST all fire. What
   pends: lowering to a state-machine LIR — handler-local state slot
   for `<~ delay(N)`, RNN hidden-state structure for `<~ step_fn`.
   Templates in H3.1 walkthrough. Scope: ~100 lines emit-side.

2. **`teach_synthesize` oracle conductor.** `graph_push_checkpoint` /
   `apply_annotation_tentatively` / `verify` / `graph_rollback` all
   fire individually. What pends: the composed handler that
   sequences them over a gradient-candidate list, scores by row
   subsumption, returns the proven set. Walkthrough in
   H5-mentl-arms.md. Scope: ~50-80 lines; one new handler in
   mentl.ka plus a conductor function.

3. **Runtime `HandlerCatalog` effect.** Today's static table in
   `mentl.ka` (`catalog_handled_effects`) serves the compiler-built-
   in handlers. For user-level handler discovery (the AWrapHandler
   proposal reading user-defined absorbers), the catalog becomes an
   effect: `catalog_register(name, handled_effects, op_arms)` at
   module load; `catalog_lookup_for(effect)` at Mentl propose time.
   Scope: ~one effect declaration + one handler, ~40 lines.

Total substrate remaining: ~200 lines across three focused pieces.
Everything else is handler installation on the substrate that
already exists.

---

## Handler Projection Arcs (formerly Post-First-Light Arcs)

What was framed as "post-first-light" is actually Phase II
handler-projection work. Each arc below either landed during the
γ cascade as substrate (marked LANDED), is Phase II priority
(marked PRIORITY N), or is genuinely post-cascade exposure
(marked EXPOSURE). Bootstrap / first-light come after Phase II
closes the critical path.

Arc designs live in `docs/DESIGN.md` (chapter 9 — *What Dissolves*)
and in this document's per-arc sections below. When an arc picks up,
capture the concrete implementation in the relevant rebuild spec or
in a dedicated design doc at that time — the arcs are sketched here,
not locked.

### Arc F.1 — Refinement Verification  *[PRIORITY 3]*

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

### Arc F.2 — LSP + ChatLSP  *[PRIORITY 1]*

Query + Mentl tentacles wrapped in JSON-RPC. No new substrate.
The `inka query` surface is live; the JSON-RPC handler that translates
LSP methods to Query/Mentl ops is the unwritten projection.

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

### Arc F.3 — REPL + Multi-Shot Continuations  *[PRIORITY 3]*

Replace `load_chunk`. Execute arbitrary Inka expressions. Formalize
the three multi-shot continuation models. Substrate for one-shot
evidence lands with H1.6; multi-shot semantics extend the same
LMakeClosure ev_slots layout.

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

### Arc F.4 — Scoped Arenas + Memory Strategy  *[substrate LANDED via H4; handler variants EXPOSURE]*

The arc where Inka proves GC is a handler. H4 landed region tracking
with tag_alloc_join (composite region-join for records/variants);
EmitMemory swap surface lands arenas as a handler swap. What remains
is the concrete `temp_arena` / `arena_pool` / `thread_local_arena`
handlers as alternate EmitMemory installations.

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

### Arc F.5 — Native Backend  *[PRIORITY 2]*

Hand-rolled x86-64 from LowIR. The capstone performance arc.
Lands as an alternate `backends/native.ka` handler installation —
peer to `backends/wasm.ka`, not a rewrite. Multi-backend emit
infrastructure (Priority 2) is the prerequisite.

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

### Arc F.6 — Mentl Consolidation  *[substrate LANDED via H5; orchestration PRIORITY 1]*

The teaching substrate crystallized. The AI-obsolescence thesis
made concrete. H5 landed AWrapHandler, AuditReport records,
severance enumeration, capability unlocks. What remains is the
`teach_synthesize` oracle conductor (substrate gap 2) — the
composed handler that drives checkpoint/apply/verify/rollback over
gradient candidates.

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

### Arc F.7 — Incremental Compilation  *[PRIORITY 4]*

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

### Arc F.8 — Concurrency + Parallelism  *[PRIORITY 3]*

Deterministic parallelism via handler swap. Requires Thread effect
+ per-thread region minting (Priority 3 substrate work).

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

### Arc F.9 — Package + Module System  *[audit LANDED; linker severance PRIORITY 2]*

The handler IS the package. The `~>` chain IS the manifest. There
is no package manager. There is only the compiler.

H5 landed `inka audit`'s report (AuditReport records with
severable/unlocks). What pends: the audit-driven linker pass that
reads `AuditReport.severable` and drops WASM imports (Priority 2).

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

### Arc F.10 — ML Framework + Handler Features  *[PRIORITY 3]*

Machine learning as proof of thesis. The ten mechanisms composed.
Autodiff handler is ~15 lines per DESIGN.md 10.2; records tape,
resumes forward, backward walk. Substrate fully supports; the
concrete handler is a Priority 3 installation.

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

### Arc G — Rename (Lux → Inka)  *[LANDED]*

Done. `.ka` is the extension; `lux3.wasm` is archaeology.

---

### Arc H — Examples-as-Proofs  *[PRIORITY 4]*

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

| Context | Strategy | Status |
|---|---|---|
| Compiler (batch) | Bump allocator — allocate forward, never free, exit | LANDED (emit_memory_bump) |
| Server (request-scoped) | Scoped arena handler — O(1) region free | substrate LANDED via H4; concrete handler PRIORITY 3 |
| Game (frame-scoped) | `own` + deterministic drop | substrate LANDED (affine_ledger); PRIORITY 3 refinement |
| Embedded/DSP | `!Alloc` — zero allocation, proven by types | LANDED (row subsumption + CRealTime unlock via H5) |

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

### Substrate invariant — HEAP_BASE = 4096

HB committed to a substrate-level threshold that separates sentinel
values from heap pointers:

- Bump allocator's `$heap_ptr` initializes at **1 MiB** (1048576).
- Sentinel values for nullary ADT variants (Bool's False=0 / True=1,
  Maybe's Nothing=0, etc.) live in `[0, 4096)`.
- Every heap allocation is **≥ 4096**, so sentinels and pointers are
  disambiguable by unsigned compare.
- Mixed-variant match dispatch (`emit_match_arms_mixed`) uses
  `(scrut < heap_base())` as the sentinel-or-pointer discriminator.
- `heap_base()` is a single-source-of-truth helper in
  `backends/wasm.ka`. Changing either the sentinel range or the
  heap initialization requires updating both at once.

This invariant enables nullary-sentinel compilation for every ADT
without per-type analysis. Bool is the canonical case;
user-declared `type Direction = Up | Down` inherits the same
zero-cost compilation.

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

### Fully out of scope (never Inka, always handler projection)

- **Projectional AST.** Rejected. Text is canonical.
- **Fractional permissions.** Shelved; Vale region-freeze via
  `!Mutate` subsumes.
- **Multi-shot × arena full policy.** Structure in specs;
  handler semantics lands with concrete arena handlers.

### Substrate IN cascade, handler exposure PENDING

The γ cascade LANDED substrate for every category below. Handler
projection lands as Phase II work per the Handler Projection
Priority list.

- **Refinement types.** Substrate LIVE (`TRefined(Ty, Predicate)` in
  types.ka; `Verify` effect with `verify_ledger` accumulates
  obligations). Exposure PENDING: SMT handler swap (verify_smt with
  Z3/cvc5/Bitwuzla) — Arc F.1.

- **LSP.** Substrate LIVE (`inka query` surface, Question/QueryResult
  ADT, render_query_result). Exposure PENDING: JSON-RPC handler,
  ChatLSP extensions — Arc F.2 = Priority 1.

- **Scoped arenas.** Substrate LIVE (Alloc effect, !Alloc negation,
  region_tracker with tag_alloc_join, EmitMemory swap surface).
  Exposure PENDING: concrete `temp_arena` / `thread_local_arena` /
  `diagnostic_arena` handlers — Priority 3.

- **REPL.** Substrate LIVE (pipeline variant with eval_expr handler
  is a one-handler install). Exposure PENDING: multi-shot
  continuation semantics (Replay / Fork / State machine) — Arc F.3.

- **Audit-driven severance.** Substrate LIVE (AuditReport records
  with severable + unlocks). Exposure PENDING: linker handler that
  reads severance list and drops WASM imports — Priority 2.

- **Native backend.** Substrate LIVE (multi-backend handler chain).
  Exposure PENDING: `backends/native.ka` as an alternate EmitBackend
  handler — Arc F.5 = Priority 2.

---

## Risk Register — post-cascade

Risks are categorized by phase. Closed risks from the γ cascade
are recorded for the project's memory; active risks lead.

### Active risks (Phase II + Phase III)

| Risk | Mitigation |
|---|---|
| Bootstrap translator is the one-shot moment a non-Inka language reads a closed substrate — a bug there corrupts the seed | Write the translator as a DIRECT TRACE of the cascade walkthroughs, not a separate interpretation. Verify by replaying the translator through `docs/traces/a-day.md`. |
| LSP handler surfaces substrate errors that didn't fire through terminal `inka query` | Mirror every CLI query's test through the LSP handler before Priority 2 lands. The trace's `[LIVE · surface pending]` tags ARE the test list. |
| `teach_synthesize` oracle conductor thrashes checkpoint/rollback on candidates that don't prove | Cap exploration at N candidates per error (default 8); score by EffName subsumption before apply; reject candidates whose apply cost exceeds a budget. |
| Multi-backend emit introduces per-target divergence that drifts over time | Shared substrate invariants live in `types.ka` and `effects.ka`; each backend handler declares its own effect row. Row subsumption proves which invariants the backend honors. |
| User-declared nullary variants collide with HEAP_BASE threshold (4096) | Total variants per type are bounded by tag_id length; no realistic ADT approaches 4096 variants. If a type ever does, the threshold widens; the invariant documents the coupling. |
| WASM stack overflow from deep recursion | Emit `return_call` for tail calls; wasmtime supports the proposal |

### Closed risks (γ cascade, now substrate-guarded)

| Risk (once) | Substrate that closes it |
|---|---|
| Substrate drift (patterns from other languages freezing Inka into foreign shapes) | 9 named drift modes in CLAUDE.md's Mentl anchor; H6 discipline refuses wildcards on load-bearing ADTs; every cascade step audited before commit. |
| ADT match silently absorbs a new variant via `_ => default` | H6 landed exhaustive matches at every load-bearing site. |
| Primitive-type special cases (TBool as C int-bool) | HB dissolved TBool; nullary-sentinel path compiles `type Bool = False \| True` to (i32.const 0/1) — same runtime as before, full ADT semantics at type level. |
| String-keyed when structured (effect names, constructor names, tokens) | Token ADT (Ω.4), EffName ADT (H3.1), SchemeKind ADT (H3), MatchShape ADT (HB audit) — all now structured. |
| Parallel-arrays-instead-of-record handler state | Ω.5 consolidated lower_scope and infer_ctx frames to records; H1.3 BodyContext state is a record; H4 region_tracker entries are records. |
| Evidence-as-sidecar (C calling convention) | H1's LMakeClosure unifies captures and evidence in one record shape — no `*const ()` vtable parameter. |
| VFINAL has bugs that surface during self-compilation | Deferred to first-light by design; substrate verified by simulation, not execution, per dream-code discipline. |

---

## Crystallized Insights

Ten load-bearing truths — defer to `CLAUDE.md` for the canonical
list (seven pre-cascade, three crystallized during γ). Summary:

1. Handler Chain Is a Capability Stack
2. Five Verbs = Complete Topological Basis
3. Visual Programming in Plain Text
4. `<~` Feedback Is Genuine Novelty
5. Effect Negation > Everything
6. The Graph IS the Program
7. Parameters ARE Tuples; `|>` Is a Wire
8. **The Heap Has One Story** (γ crystallization — closures +
   variants + records + closures-with-evidence share one
   emit_alloc swap surface)
9. **Records Are The Handler-State Shape** (γ crystallization —
   Ω.5 / BodyContext / region_tracker / AuditReport all converge)
10. **Row Algebra Is One Mechanism Over Different Element Types**
    (γ crystallization — string-set / name-set / field-set /
    tagged_values instances, one abstract pattern)

CLAUDE.md also names the **backward-bootstrap fixed-point** as
Phase IV's soundness proof (historically insight 7; kept as the
terminal invariant).

---

## Key Documents

| Document | Role |
|---|---|
| **docs/PLAN.md** | THIS FILE. The single roadmap. Four phases, the three substrate gaps, handler-projection priority. |
| **docs/SYNTAX.md** | Σ canonical syntax. The wheel the parser was shaped to. |
| **docs/rebuild/00–11** | The 12 executable specs. |
| **docs/rebuild/simulations/H*.md** | Per-handle cascade walkthroughs with riffle-back addenda. Reasoning record. |
| **docs/traces/a-day.md** | Post-cascade integration trace. One developer, one project, one day. Every claim tagged `[LIVE]` / `[LIVE · surface pending]` / `[substrate pending]`. The scoreboard. |
| **docs/INSIGHTS.md** | Core truths. Living compendium. |
| **docs/DESIGN.md** | Language manifesto. Chapter 10 is the thesis-level simulations; `docs/traces/a-day.md` is the integration. |
| **CLAUDE.md** | Anchors + eight-anchor discipline + nine drift modes + ten crystallizations. Required reading at session start. |
| **docs/errors/** | Error catalog (prefix-kind string codes). |
| **CLAUDE.md** | Session Zero + seven anchors for AI assistants. |
