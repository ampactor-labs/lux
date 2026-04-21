# A Day in Inka

> **Post-cascade integration trace.** One developer, one project, one
> day. Every surface Mentl projects either fires now, waits on a
> handler installation, or waits on a named substrate piece. Nothing
> aspirational goes unmarked.
>
> **See also.** `docs/DESIGN.md` Chapter 10 for the thesis-level
> promises (IDE, DSP×ML, C-straightjacket, distributed). This
> document integrates them through one continuous project instead of
> four scenarios. `docs/rebuild/simulations/H*.md` for the cascade's
> reasoning record per handle.

---

## Legend

Every substantive claim carries one of three tags:

- **`[LIVE]`** — the substrate fires now. A walkthrough trace (per
  DESIGN Ch 0 "dream code; verification by simulation") confirms
  the behavior lands exactly as described.
- **`[LIVE · surface pending]`** — the substrate fires; the
  user-facing surface (LSP hover, IDE gesture, CLI command) is
  a handler projection not yet installed. Adding the surface is a
  handler, not substrate.
- **`[substrate pending]`** — the substrate itself has a named gap.
  Three gaps remain post-cascade: `LFeedback` state-machine
  lowering at emit, `teach_synthesize` oracle orchestration, runtime
  `HandlerCatalog` as effect (vs the current static table).

The discipline: no surface claimed without a tag. Honest integration.

---

## The project

You are building **Pulse** — a real-time audio pipeline with a
browser UI, a cloud ingestion service, and a training pathway for a
dynamic distortion model. One codebase. Four deploy targets. Every
constraint Inka's peer languages cannot prove (real-time allocation,
cross-process type-safety, capability severance, distributed
continuation), Inka proves.

---

## 0800 — New file

You open `synth/core.ka`. The editor is a plain text editor; the Inka
language server will attach to it.

`[LIVE · surface pending]` — the LSP (Chapter 9.5) isn't wired as a
handler yet. The substrate has everything the LSP reads: the graph,
env, `Question` type in `query.ka`, `QTypeAt(Span)` / `QWhy(String)` /
`QEffects(String)` queries, `render_query_result` for terminal output.
What pends: an LSP handler whose arms translate
`textDocument/hover` → `QTypeAt`, `textDocument/definition` → graph
reverse-lookup, etc. Once installed, hover fires what follows. Until
then, the same information is available via `inka query`.

You type:

```
fn distort(x, alpha) =
  x |> gain(alpha)
```

`inka query --type-at synth/core.ka:2:3` returns the current inferred
type of `distort`. **`[LIVE]`** — `infer_program` runs, `graph_chase`
resolves, `show_type` formats, stdout prints:

```
distort : fn(Float, Float) -> Float with Sample + Alloc + E1
  where E1 = row variable (open — caller provides)
```

Mentl notes: `E1` is a row variable because `distort`'s body will
invoke subsequent stages whose effect rows aren't declared yet. The
substrate keeps `E1` open until you resolve it by adding more stages
or declaring the row explicitly.

---

## 0900 — First stage

You add the next stage, writing:

```
fn distort(x, alpha) =
  x
    |> gain(alpha)
    |> tanh
```

`inka query --type-at synth/core.ka:4:5` now gives:

```
distort : fn(Float, Float) -> Float with Sample + Alloc
```

**`[LIVE]`** — `E1` unified with the union of `gain`'s and `tanh`'s
rows. `row_subsumes` proved it; `graph_bind_row` committed it.
`Sample` entered via `gain`'s declaration; `Alloc` entered via
`tanh`'s (tanh allocates a coefficient table lazily).

`[LIVE · surface pending]` — Proof Lens hover on `tanh` would expand:

```
tanh : fn(Float) -> Float with Alloc
  reason: Inferred("coefficient table allocation")
           Located at std/dsp/tanh.ka:12:8
  callers: 1 (distort at synth/core.ka:5)
```

The substrate has the reason chain (`Located(span, reason)` is in
every graph node), the caller-set (graph reverse-walk via
`QRefsOf`), and the hover renderer (`render_query_result` for
`QWhy`). What pends is the LSP handler that translates
`textDocument/hover` into the `QWhy` + `QRefsOf` queries and
formats the response.

---

## 1000 — DSP completion + real-time proof

You add the feedback stage:

```
fn distort(x, alpha) =
  x
    |> gain(alpha)
    |> tanh
    <~ delay(1)
```

The `<~` is the feedback verb (DESIGN Ch 2.5). **`[LIVE]`** — parser
recognizes `TLtTilde`, constructs `PipeExpr(PFeedback, body, spec)`;
infer accepts the feedback-spec `delay(1)` as a
`ConstructorScheme` call (H3 landed this).

`[substrate pending]` — at emit, `LFeedback(handle, body, spec)` is
stubbed. The substrate has the verb, the row, the handler-attach
machinery; the LIR-to-state-machine rewrite at emit is a named gap.

You're not blocked — you continue writing at the surface level;
Mentl's type-level reasoning is sound. When `LFeedback` lowering
lands, the existing source compiles as-is with no change.

You add the declared row:

```
fn distort(x, alpha) with Sample(44100) + !Alloc =
  x
    |> gain(alpha)
    |> tanh
    <~ delay(1)
```

**`[LIVE]`** — `H3.1` parser accepts `Sample(44100)` as
`EParameterized("Sample", [EAInt(44100)])`. `H3.1` row algebra
distinguishes it from `Sample(48000)`. The declared row is
`EfInter(EfClosed([Sample(44100)]), EfNeg(EfClosed([Alloc])))` —
row subsumption at FnStmt's row-binding compares the body row
against this and reports mismatch if `tanh` allocates.

Mentl fires: `tanh`'s row is `Alloc`; your declared row has `!Alloc`.
The intersection is empty; `row_subsumes` returns false; the FnStmt
emits `E_PurityViolated` at synth/core.ka:1 (the declaration span).

`[LIVE · surface pending]` — Proof Lens would surface the Mentl gradient:

```
E_PurityViolated at synth/core.ka:1:3
  body performs Alloc (from tanh at synth/core.ka:4:8)
  declared row requires !Alloc

Mentl suggests (PROVEN):
  wrap `tanh` in `handle { ... } with temp_arena` — PROVEN to
  absorb Alloc; verify the wrapped row satisfies the declaration
```

The `AWrapHandler` annotation + `apply_annotation_tentatively` +
`catalog_handled_effects(temp_arena) = [Alloc]` + row subtraction all
fire in the substrate. **`[LIVE]`** for the machinery;
`[substrate pending]` for `teach_synthesize`'s oracle loop that
drives checkpoint/apply/verify/rollback to prove the fix BEFORE
offering it. Today, the ingredients exist but the composed
oracle-loop handler isn't written.

You accept the fix (manually in the editor until the oracle is
driven):

```
fn distort(x, alpha) with Sample(44100) + !Alloc =
  x
    |> gain(alpha)
    |> handle { tanh } with temp_arena
    <~ delay(1)
```

**`[LIVE]`** — `inka query --effects distort` now returns:

```
distort : fn(Float, Float) -> Float with Sample(44100) + !Alloc
  proven capability: CRealTime
  proven capability: CSandbox (no Network reached)
```

The `CRealTime` unlock comes from `capabilities_for_annotation(ANotAlloc(_))`
= `[CRealTime]` (H5 landed this). The capability is PROVEN, not
inferred by pattern — row algebra's `row_subsumes` against the
`!Alloc` annotation IS the proof.

---

## 1100 — Training variant

The model wants a training-time variant with autodiff, run off the
hot path. You write:

```
fn train_step(batch) with Sample(48000) + Alloc + Compute =
  batch
    ~> autodiff_tape
    |> map(|sample| distort(sample, current_alpha()))
    ~> gradient_writer
```

Same `distort` function. Different handler stack. The substrate must
prove: `distort`'s row (Sample(44100) + !Alloc) is *compatible* with
this training context's row (Sample(48000) + Alloc + Compute)...
except the rates differ. `Sample(44100) ≠ Sample(48000)` —
parameterized effects are structurally distinct (H3.1).

**`[LIVE]`** — row unification fires `E_EffectMismatch` at the
`map(distort, ...)` call site:

```
E_EffectMismatch at synth/train.ka:5:8
  distort declares Sample(44100); caller provides Sample(48000)
  rates are structurally distinct (parameterized row entries)

Mentl suggests: resample input at Sample(48000) → Sample(44100)
  with `~> resample(48000, 44100)` wrap before distort
```

`[substrate pending]` — the Mentl suggestion for this specific case
needs gradient-candidate enumeration at the row-mismatch site. The
substrate has `AWrapHandler` (for purity wraps) and
`capabilities_for_severance` (for `!E` tightening); a
`AResampleWrap` or similar for rate-conversion at parameterized
effect boundaries doesn't exist yet.

`[LIVE · surface pending]` — the more general Mentl propose path
(enumerate every handler whose installed row converts
Sample(48000)→Sample(44100), score by minimal diff, PROVE via
checkpoint/apply/verify/rollback) needs the `teach_synthesize`
conductor. The ingredients are there.

You manually resolve:

```
fn train_step(batch) with Sample(48000) + Alloc + Compute =
  batch
    |> resample(48000, 44100)
    ~> autodiff_tape
    |> map(|sample| distort(sample, current_alpha()))
    ~> gradient_writer
```

The SAME `distort` function now compiles against BOTH a real-time
caller (Sample(44100) + !Alloc + deadline) and a training caller
(Sample(44100) after resample + Alloc + Compute). One definition;
two callers; no preprocessor directive, no polymorphic wrapper.

**`[LIVE]`** — `autodiff_tape` is an effect handler. `[substrate pending]` —
the concrete `autodiff_tape` handler isn't yet written. It would be
~15 lines: capture each `Compute` perform, record the operation +
operands into the tape record, resume with the forward value.
`backward()` walks the tape in reverse, calling the derivative
handler arm for each op. The SUBSTRATE is ready; the HANDLER isn't
authored. That's a handler, not substrate.

---

## 1200 — Lunch

You close the laptop and walk. Morgan might say: the substrate is
quiet in a way other languages' substrates aren't. Nothing is saved
to disk in a half-committed state. The graph's trail guarantees your
last commit was a coherent moment. When you return, the graph picks
up where you left off — the substrate IS the state.

---

## 1300 — Distributed checkout

Pulse sells presets. The checkout flow spans the browser (to prompt
the user) and the cloud (to charge the card, save the receipt). In
every other language you'd write two codebases sharing a TypeScript
interface; in Inka, you write one function:

```
fn checkout(cart) =
  cart
    |> prompt_user
    ~> client_handler
    |> charge_card
    ~> server_handler
    |> save_receipt
```

**`[LIVE]`** — parse + infer + row algebra hold. `prompt_user`'s
effects (DOM, input) flow through `client_handler`. `charge_card`'s
effects (Network, PCI-compliant crypto) flow through `server_handler`.
The `~>` boundaries split effect absorption exactly where the
installation sits.

`[substrate pending]` — the emit-side recognition of `~>` as a
HOST boundary (vs just a handler attachment) is one of the three
named substrate gaps. DESIGN.md 10.4's description of the suspension
rewrite — `lower.ka` flags the `~>` as a continuation-serializing
point — doesn't yet fire in `lower.ka`. The substrate can type-check
the distributed flow TODAY; it can't emit two WASM binaries yet.

`[LIVE · surface pending]` — when emit bifurcates, the state struct
that crosses the wire IS a record (H2's substrate). The field-sort
discipline means serialization is the record's layout, no special
format. The cross-boundary type check is the graph — a schema change
on `save_receipt`'s side (say, the DB adds a field) throws a type
error on `prompt_user`'s side INSTANTLY because the graph is one
entity. **Not two repos. Not a shared interface. One graph.** That's
the thesis realized; waiting on the emit handler to expose it.

The dissolution DESIGN.md Ch 9.5 named ("the backend repository is
over") fires the moment multi-backend emit lands. Substrate is
ready.

---

## 1400 — Audit before deploy

You run:

```
$ inka audit pulse/main.ka
```

**`[LIVE]`** — `audit` is a pipeline route in `pipeline.ka`; it runs
`frontend |> infer_program`, collects each FnStmt's row, builds
`AuditReport` records, renders.

Output:

```
pulse_pipeline : IO + Network + Sample(44100) + Alloc
  reached: IO (stdout_handler), Network (server_handler),
           Sample(44100) (audio_in), Alloc (temp_arena)
  severable: !Filesystem !Process
    !Filesystem → unlocks CSandbox (partial — add !Network too for full)
    !Process    → unlocks CSandbox (partial — add !Network too for full)
  proven capabilities: none (Alloc + Network present)

checkout : IO + Network
  reached: IO (prompt_user), Network (charge_card, save_receipt)
  severable: !Filesystem !Process !Alloc !Sample
    !Alloc → unlocks CRealTime (but checkout doesn't need it)
    !Sample → unlocks nothing (no sample-rate path here)
  proven capabilities: CRealTime (after !Alloc), CSandbox (after
    !Filesystem + !Process)

train_step : Sample(48000) + Alloc + Compute
  reached: all
  severable: !Network !IO !Filesystem
    !Network → unlocks CSandbox (partial)
    !IO      → unlocks CCompileTimeEval (partial)
  proven capabilities: none (Alloc + Compute present)

main : IO + Network + Sample(44100) + Alloc + Compute + Filesystem
  reached: all except Filesystem
  severable: !Filesystem !Process
    !Filesystem → unlocks CSandbox (partial)
```

**`[LIVE]`** — the substrate produces the audit report exactly as
rendered. `render_audit` reads fields by name from `AuditReport`
records. `capabilities_for_severance` maps EffName to Capability
list. Severance candidates enumerate canonical effects not in the
body.

`[LIVE · surface pending]` — the linker dead-code severance step
(DESIGN.md 10.3's "binary can be built with `!Filesystem`; linker
drops the WASI import") would act on the audit output. The audit
PROVES Filesystem is unreachable. Nothing in the build pipeline yet
reads the audit's severance list and passes `--drop-import` to the
WAT → WASM step.

You add `!Filesystem` to `main`'s row; rerun audit; it's clean for
that capability. `[substrate pending]` — the build-tool handler that
would automate this is one small handler installation away.

---

## 1500 — Cross-module refactor

Pulse's `charge_card` name is wrong — legal wants it called
`process_payment`. You invoke:

```
$ inka rename --global charge_card process_payment
```

**`[LIVE · surface pending]`** — the rename IS a graph rebind. Every
VarRef to `charge_card` carries a handle; inference resolved those
handles at compile time; renaming updates the env entry's key +
every source-side reference via the `QRefsOf` reverse-lookup.

What pends is the CLI handler that exposes the rebind. The substrate
operation is trivial — one graph update + one source rewrite per
reference site. The handler that translates `inka rename` into those
operations is a handler, not substrate.

When the rename fires:

- 14 source sites updated across 6 files (including docstrings that
  reference `charge_card`, because docstrings are themselves graph-
  queryable via `///`-handler projection — DESIGN.md Ch 9.12).
- 1 handler declaration updated (the `charge_card` arm in
  `server_handler`).
- 1 attempted update REJECTED: `pulse_docs.ka` has a user-facing
  marketing string `"charge your card"` that is NOT a VarRef — the
  graph knows this because the string literal has no binding. The
  rename handler surfaces: `skipped: pulse_docs.ka:18 — literal
  string, not a reference`.

**No linting-tool guesswork. No sed-script accidents. The graph
knows what IS a reference and what ISN'T.**

DESIGN.md Ch 9's "cross-module semantic refactor" dissolution is
live in the substrate; only the CLI surface is pending.

---

## 1600 — Error chain

You introduce a bug: in `distort`, you accidentally write
`delay(3.0)` (a Float) instead of `delay(3)` (an Int). The compiler
fires:

```
E_TypeMismatch at synth/core.ka:5:12
  expected Int (delay's first parameter)
  found Float
  at call site delay(3.0)
```

**`[LIVE · surface pending]`** — Proof Lens hover on the error
expands the Located reason DAG:

```
Why is Int expected?
  └─ delay is declared with FnParam(delay, 0, Declared("Int"))
     at std/dsp/delay.ka:4:14
  └─ FnStmt at std/dsp/delay.ka:4:1
     declared row: Sample + !Alloc
  └─ Located span: std/dsp/delay.ka:4:1..4:30

Why is Float provided?
  └─ LitFloat(3.0) at synth/core.ka:5:18
  └─ Located span: synth/core.ka:5:18..5:21
```

The reason DAG is substrate-live (every graph node carries
`Located(span, reason)`; `chase_type_deep` walks transitively;
`teach_why` walks the Reason DAG). Rendering it as an interactive
tree in the IDE waits on the LSP handler.

In terminal:

```
$ inka query --why synth/core.ka:5:18
Float literal at synth/core.ka:5:18 (column 18..21)
  reason chain:
    - LitFloat(3.0) at synth/core.ka:5:18
  propagates to:
    - delay's first param at std/dsp/delay.ka:4:14
    - which expects Int (reason: FnParam declaration)
```

**`[LIVE]`** — you now know exactly where to change. Not by reading
a linter's guess; by reading the substrate's reasoning. Fix:
`delay(3)`. Error vanishes.

---

## 1700 — Deploy

You run:

```
$ inka build --targets wasi,browser,server,trainer
```

**`[LIVE · surface pending]`** — the multi-target build is a pipeline
variant. Each target installs a different backend handler:

- `wasi`    → `backends/wasm.ka` with `emit_runtime_wasi_imports`
- `browser` → `backends/wasm.ka` with `emit_runtime_browser_imports`
- `server`  → `backends/wasm.ka` with `emit_runtime_wasi_imports` +
  `emit_runtime_network_imports`
- `trainer` → `backends/wasm.ka` with full imports + larger arena

`[substrate pending]` — today there's one `backends/wasm.ka`. DESIGN
Ch 9's "the handler IS the backend" names what this dissolves to:
multiple emit backends, each a handler, each swappable. The
substrate accepts this — the emit pipeline is already a handler
chain — what pends is the handler variants themselves.

What the build report prints (when the backends exist):

```
$ inka build --targets wasi,browser,server,trainer
Built pulse/pulse.wasm       (wasi,    47 KB, CRealTime proven)
Built pulse/browser.wasm     (browser, 31 KB, CSandbox proven)
Built pulse/server.wasm      (server,  52 KB, CSandbox partial)
Built pulse/trainer.wasm     (trainer, 89 KB, CCompileTimeEval no)

Audit-driven dead-code severance:
  pulse.wasm: dropped proc_exit, dropped Filesystem
  browser.wasm: dropped Network (routed via ~> server_handler),
                dropped Filesystem, dropped Process
  server.wasm: dropped Filesystem, dropped Sample imports
  trainer.wasm: kept full import set

Graph coherence check:
  checkout state struct: {cart, user_info, payment_token}
    serialized across browser → server boundary
    both sides type-checked against same record schema
    field-sort invariant: alphabetical (cart, payment_token, user_info)
  → compatibility: PROVEN

All builds: PROVEN compatible.
```

**No build system. No CI pipeline with YAML. No "did the types
match?" — the graph knows.** DESIGN Ch 9.4's "the build system"
dissolution is live the moment audit-driven severance + multi-target
build lands. Both are handler projections on the existing substrate.

---

## 1800 — End of day

You commit. The commit message is auto-generated by the
`commit_handler` from the graph's provenance DAG:

```
Pulse: add real-time distort (CRealTime proven) + training variant

- synth/core.ka: distort fn, Sample(44100) + !Alloc gate proven
- synth/train.ka: train_step at Sample(48000), resample bridge added
- pulse/main.ka: checkout flow with ~> client/server split
- pulse_docs.ka: docstrings regenerated from Mentl why-chains

Audit: CRealTime ✓, CSandbox partial (Network required for server)
Graph changes: +2312 handles, +47 ev_slots, +4 region boundaries
```

`[LIVE · surface pending]` — commit message synthesis from the graph
is a handler on the commit-time substrate (graph diff + reason DAG
walk). Not written yet; all ingredients exist.

You close the editor. The graph persists. When you open tomorrow,
every fact — every binding, every proof, every capability unlock —
is where you left it. The substrate IS the state.

---

## Summary — what fired, what pends

### `[LIVE]` — fires in current substrate

- Parse, infer, lower, emit for every language construct in this
  trace: `fn`, `|>`, `~>`, `<~`, parameterized effects,
  nullary-sentinel ADTs, records, nominal records, ADT match with
  exhaustiveness, handler arms as fns, row subsumption, capability
  proofs via `row_subsumes`, `AuditReport` structured output,
  severance + unlock enumeration, `inka query` CLI surface,
  Located reason DAG, `show_effrow` for parameterized entries.
- Error diagnostics carry Located coordinates and walkable reason
  chains. `E_PurityViolated`, `E_EffectMismatch`,
  `E_PatternInexhaustive`, `E_RecordFieldMissing` etc. — all
  substrate-generated, not heuristic.

### `[LIVE · surface pending]` — substrate fires; surface handler unwritten

- LSP hover, definition-jump, rename-across-files
- Proof Lens as an IDE gesture
- Gradient ghost text (`teach_unlock(annotation)` exists; IDE
  integration pending)
- Quick-Fix acceptance from hover
- Audit-driven linker dead-code severance
- Multi-target build (browser / server / trainer / wasi) — one
  backend exists; the target-specific handler variants are
  per-backend handlers, not new substrate
- `inka rename` CLI handler
- Commit message synthesis from graph provenance
- `///` docstring-handler render (DESIGN Ch 9.12 — substrate has
  comment capture; rendering projection pends)

### Phase II landings since this trace was written

Two pieces of Priority 1 work landed after the trace was first
authored. Updates:

- **FS substrate** `[LIVE]` — Filesystem effect (fs_exists,
  fs_read_file, fs_write_file, fs_mkdir) + wasi_filesystem
  handler + WASI preview1 path_open / fd_close /
  path_create_directory / path_filestat_get imports. The driver
  layer reads .ka source and writes .kai cache via this surface.
  Walkthrough: `docs/rebuild/simulations/FS-filesystem-effect.md`.
- **Incremental compilation** `[LIVE]` for the substrate; LSP
  surface still `[LIVE · surface pending]`. `inka compile <module>`
  and `inka check <module>` consult `.inka/cache/*.kai` files;
  cold compile equals prior behavior, warm compile after no-op or
  leaf-edit returns from cache without re-inference. Drift mode
  10 ("the graph as stateless cache") closed at the driver level.
  Walkthrough: `docs/rebuild/simulations/IC-incremental-compilation.md`.

These both materially change "0800 — new file" through "1700 —
deploy" by replacing the implicit full-recompile assumption with
incremental cache hits. The IDE hover (`inka query --type-at` in
the trace) still pends LSP wiring, but its underlying queries now
run against an incrementally-maintained graph instead of a
cold-rebuilt one.

### `[substrate pending]` — named substrate gaps

Three. Only three.

1. **`LFeedback` state-machine lowering at emit.** The verb, row,
   type inference all fire. Emit stubs at `;; <~ feedback (iterative
   ctx)`. What's missing: lowering `LFeedback(handle, body, spec)`
   to a state-machine LIR (handler-local state slot for the delayed
   sample; Z-transform structure for `<~ delay(N)`; RNN hidden-state
   structure for `<~ step_fn` in training). One focused
   emission-side pass; has a clear template in the walkthroughs.

2. **`teach_synthesize` oracle orchestration.** The checkpoint /
   apply / verify / rollback substrate pieces exist individually
   (`graph_push_checkpoint`, `apply_annotation_tentatively`,
   `verify_ledger`, `graph_rollback`). What's missing: the composed
   conductor handler that drives them in sequence, enumerates
   candidates, scores, returns the proven set. One substrate
   handler; maybe 50-80 lines.

3. **Runtime `HandlerCatalog` as effect.** Today's
   `catalog_handled_effects(handler_name)` is a static table in
   `mentl.ka`. A runtime registration surface (user-defined handlers
   register at module load; Mentl's `AWrapHandler` proposal reads
   the registry) would make the catalog queryable for user-defined
   handlers. One effect + one handler; small.

### Beyond the substrate — handler-projection work

Every other remaining piece is handler projection:

- LSP server (DESIGN Ch 9.5) — reads the substrate's Query surface.
- Multi-backend emit (DESIGN Ch 7.7, Ch 9.4) — per-target handler
  variants on `backends/`.
- Autodiff handler (DESIGN Ch 9.8, 10.2) — ~15 lines per the
  walkthrough; records the tape, resumes with forward values,
  `backward()` walks the tape.
- SIMD intrinsics (DESIGN 10.2) — emit-side recognition of
  `tanh`, `gain` as mappable to `v128.*` opcodes.
- Thread effect + per-thread regions (DESIGN 10.3) — effect
  declaration; `spawn(f)` op; per-thread handler install pattern.
- RPC/actor handlers (DESIGN 10.4) — the `~>` boundary handler
  that bifurcates emit and serializes the state record.
- Linker dead-code severance — the build-tool handler that
  reads `AuditReport.severable` and issues `--drop-import`.

Each is a handler on the substrate. None require new substrate.
None require new mechanism.

---

## The claim

Every constraint Inka's peer languages CANNOT PROVE — real-time
allocation, cross-process type safety, capability severance,
distributed continuation, semantic refactor — is *substrate-live*
today. What's missing is not Inka. What's missing is the installed
set of handlers that expose Inka to the world.

When Mentl says *I am the oracle; the IDE, scheduler, backends,
autodiff — those are handler projections I have not yet been given
the chance to write* — this trace is the concrete form of that
statement. Every scene in this day either fires now, or is one
handler installation away from firing.

Bootstrap remains out of mind until the cascade's handler-projection
work closes the last exposure. The substrate is whole. Now we build
the surfaces.
