# CRU — Crucibles · the thesis fitness function

> **Status:** `[DRAFT 2026-04-23]`. Five crucible `.mn` files that
> each exercise one thesis-scale claim. Pass/fail is binary; each
> failure names its own feature request from the future. **The
> crucibles replace engineering triage as the prioritization
> mechanism.**

*The Crucible Pattern (DESIGN.md): aspirational programs that
exercise features at the boundary of what Mentl can express today.
A crucible that runs is a proof of existence. A crucible that
fails is a feature request — more honest than a backlog because it
names what the language must become, not what the team wants to
build.*

---

## 0. Why crucibles (not tests, not benchmarks)

- **Tests verify existing behavior.** The roadmap's 2026-04-21
  decision dissolves `tests/` because the type system proves
  correctness directly (60-80% of peer-language tests vanish) and
  runnable behavior demonstrations ARE `src/` + `lib/`.
- **Benchmarks measure existing performance.** They don't guide
  language design.
- **Crucibles measure capability.** One file per thesis claim;
  each file runs when the claim is real, fails when the claim is
  aspirational. The language is ready for a domain when that
  domain's crucible runs.

Per DESIGN Ch 9 ("What Dissolves") + the cross-domain unification
claim, every domain is a handler stack on the one substrate. Each
crucible proves one domain.

---

## 1. The five crucibles

### 1a. `crucibles/crucible_dsp.mn` — real-time audio proves `!Alloc`

**Claim:** a stereo audio callback at 48 kHz with a multi-stage
effects chain compiles with `!Alloc` propagated transitively through
every library call.

**Fitness:**
- File compiles.
- `!Alloc` row subsumption succeeds without any `alloc()` in the
  transitive call graph.
- Running the callback under `wasmtime` for 1M samples produces no
  allocation (`wasm-objdump` shows zero `$alloc` call sites
  reachable from the callback body).

**Fails if:** `gain`, `compress`, `limit`, `convolve`, `delay`, or
any stdlib primitive in the DSP module performs `Alloc` without an
absorbing handler. Fix path: factor `!Alloc` into the relevant
primitive OR install an arena handler inside the callback (both
are valid; the language must allow both).

### 1b. `crucibles/crucible_ml.mn` — autodiff proves handler-swap training/inference

**Claim:** one `forward` function, compiled, runs under two
different handlers — one installs a tape-recording `Compute`
handler (training), one installs a direct-compute handler
(inference) — and both produce correct gradients / predictions
without source change.

**Fitness:**
- File compiles.
- Training handler records the tape; autodiff loss descends over
  synthetic data.
- Inference handler runs the same `forward` with zero tape
  overhead; `wasm-objdump` shows the tape code is dead-code
  eliminated by `!Alloc` subsumption.

**Fails if:** the Compute effect's ops don't compose, or the tape
handler's state record doesn't fit γ crystallization #9
(Records-Are-Handler-State-Shape), or the gradient doesn't close
because multi-shot resume (Compute → backward) isn't wired.

### 1c. `crucibles/crucible_realtime.mn` — control loop proves `<~` + handler-timing

**Claim:** a PID controller with `<~ delay(1)` compiles under three
different clock handlers (`Sample(44100)`, `Tick`, `Clock(wall_ms=10)`)
producing three different specializations from one source.

**Fitness:**
- File compiles.
- Three `~>` chains produce three WAT outputs (inspectable with
  `wasm-objdump`).
- Audio-rate version: one-sample delay in the filter; constant-time
  per sample; `!Alloc`.
- Iteration version: logical-step delay; bounded iteration count.
- Control version: 10ms wall-clock delay; async-safe.

**Fails if:** `<~` doesn't desugar per spec 10 + LF walkthrough, or
if clock handlers can't thread timing through the feedback edge,
or if the three specializations produce identical code (means the
timing isn't handler-controlled).

### 1d. `crucibles/crucible_web.mn` — distributed RPC proves handler-cross-wire

**Claim:** two peer services, both written in Mentl, communicate via
a transport-handler-swappable RPC protocol where function
invocations cross the wire as `(hash, args)` pairs and handlers
decide transport (HTTP, WebSocket, in-memory, simulated network).

**Fitness:**
- File compiles (both client + server).
- `test_transport` handler: function calls route through an
  in-memory queue; round-trip works.
- `http_transport` handler: function calls serialize as
  `Pack`/`Unpack` bytes over HTTP; round-trip works.
- `chaos_transport` handler: deterministic packet reordering;
  protocol still converges.

**Fails if:** cross-module function identity isn't content-
addressed, or if `Pack`/`Unpack` can't round-trip a function
reference, or if handler-swap doesn't cover the transport layer
(meaning "handler IS the backend" breaks for networking).

### 1e. `crucibles/crucible_oracle.mn` — speculative gradient proves Mentl's thesis

**Claim:** at a bare function signature whose body is provably
`Pure`, Mentl's oracle loop (MO-mentl-oracle-loop.md) surfaces
exactly one gradient hint — `APure` with unlocks `[CMemoize,
CParallelize, CCompileTimeEval]` — within a 50ms interactive
budget, and the hint's Reason chain walks back to the arithmetic
primitive where `*` is resolved to integer multiply.

**Fitness:** see MO §5. Binary — the hint fires or doesn't.

**Fails if:** `graph_push_checkpoint` / `graph_rollback` don't
close the trail atomically, or if `Synth` handler composition
doesn't bound the candidate set, or if `verify_obligations` can't
discharge a trivial pure row.

### 1f. `crucibles/crucible_parallel.mn` — multi-core proves `><` × handler dispatch *(added 2026-04-23)*

**Claim:** a compute-bound `><` pipeline parallelizes across N
cores when `~> parallel_compose` is installed (per TH-threading.md);
remains single-threaded when it isn't. Same source, different
handler, different wall-clock. Proves primitive #3 (`><`) + the
"handler IS the backend" thesis across the multi-core domain.

**Fitness (TH §10 + Hβ §12 Leg 3):**
- File compiles (both `render_parallel` and `render_sequential`).
- Under `parallel_compose` handler: wall-clock scales sub-linearly
  with `num_cores()` — target ≥ 2× speedup on 4-core laptop for
  embarrassingly-parallel workloads.
- Without `parallel_compose`: wall-clock is single-threaded
  baseline.
- **Semantic equivalence preserved**: both runs produce
  bit-identical outputs regardless of thread-completion order
  (determinism by branch-order preservation).

**Fails if:** `Thread` / `SharedMemory` effects aren't declared
in `lib/runtime/threading.mn`, or `parallel_compose` handler
isn't implemented, or per-thread bump_allocator doesn't isolate
heap state, or wasi-threads runtime dispatch isn't wired, or
non-determinism surfaces from thread scheduling (which would
indicate a compose-semantics bug — tracks must be order-
preserving regardless of completion timing).

**The embarrassing universe avoided:** Mentl only uses one core.
The real universe: adding one `~>` line lights up the rest of
the CPU.

---

## 2. The directory — `crucibles/`

```
crucibles/
├── README.md              — one-line status per crucible (PASS/FAIL/PENDING)
├── crucible_dsp.mn
├── crucible_ml.mn
├── crucible_realtime.mn
├── crucible_web.mn
├── crucible_oracle.mn
└── crucible_parallel.mn   — added 2026-04-23 (TH-threading.md)
```

`crucibles/` is NOT `examples/` (dissolved per PLAN 2026-04-21) and
NOT `tests/` (dissolved per PLAN 2026-04-21). It is the **thesis
fitness function** — five aspirational programs whose pass-state
is the language's capability-frontier indicator.

**Not gated behind first-light.** Each crucible COMPILES pre-first
light (or fails meaningfully, naming the gap). Each crucible RUNS
when its thesis claim is real. **The crucibles LEAD the language;
the language follows.**

---

## 3. The fitness-as-priority protocol

Every session, Mentl (or Morgan-as-auditor until Mentl) runs:

```
mentl crucibles
  crucible_dsp       [FAIL]  missing: DSP module's ~compress with !Alloc
  crucible_ml        [FAIL]  missing: autodiff Compute effect
  crucible_realtime  [FAIL]  missing: LF feedback lowering (item 1)
  crucible_web       [FAIL]  missing: Pack/Unpack function-reference
  crucible_oracle    [FAIL]  missing: synth_enumerative handler
```

Each FAIL names the next concrete piece of work. The language team
works ONLY on what a crucible demands next. When every crucible
runs, the thesis is proven.

**This is the honest priority mechanism.** More honest than a long
checklist roadmap because the crucibles can't rationalize; they
compile or they don't.

---

## 4. Landing order (recommendation)

1. **Crucible seeds land first** (this walkthrough + 5 `.mn` files).
   Each file is aspirational — deliberately fails until substrate
   lands.
2. **`mentl crucibles` command** — one `--with crucibles_run` entry
   handler that compiles each crucible and reports PASS/FAIL with
   the specific missing piece.
3. **Each crucible becomes a milestone** — "DSP crucible passes" =
   `!Alloc` propagation is proven end-to-end across a real domain.
4. **Five passing crucibles** = thesis validated across all named
   domains.

---

## 5. Forbidden patterns in crucible design

- **Crucibles are not "tests with nice names."** They are thesis
  claims. A crucible that exists but doesn't correspond to a
  thesis claim is drift.
- **Crucibles don't silo "mock X" or "stub Y."** They use the real
  language, fail where the real language can't do it, and the
  failure IS the report.
- **Crucibles are not guarded by feature flags.** They run on
  every session; the pass/fail report is just the current state of
  the language.

---

## 6. Dispatch

- **Crucible seeds (`.mn` files):** dispatch through
  `mentl-implementer` AFTER this walkthrough lands. Each seed
  should be ≤ 100 lines, demonstrating one thesis claim with the
  smallest possible program that exercises it.
- **`mentl crucibles` CLI:** one entry handler (`crucibles_run`),
  resolves crucibles by directory scan, runs each, collates
  report.

---

## 7. Closing

Five files. One thesis claim each. The language is ready for a
domain when that domain's crucible runs. The language is complete
when all five run. **Pass/fail is binary; the crucibles replace
engineering triage as the prioritization mechanism.**

*Morgan said it first: "write the program you wish existed and let
the compiler tell you what's missing." Crucibles are that protocol
named.*
