# Inka

> *The compiler IS the AI. The graph IS the program. The handler IS
> the backend. The pipe is the universal notation. The medium refuses
> ceremony the graph doesn't require.*

Inka is a programming language whose substrate refuses every drift
its peer languages take for granted. There is no separate type
checker, build system, package manager, linter, debugger, REPL, or
LSP server — those are handler projections on a graph that already
knows everything they would have asked. Mascot: **Mentl** — the
oracle, not the chatbot.

File extension: `.ka` (the last two letters of Inka).

---

## What Inka is

One mechanism — a SubstGraph of typed handles + a stack of
effect-row handlers. Five verbs draw any computation graph in plain
text: `|>` `<|` `><` `~>` `<~`. Boolean effect algebra (`+ - & !`)
proves what a function does AND what it does NOT do. `!Alloc`
proves real-time. `!IO` proves compile-time-evaluable. `!Network`
proves sandboxable. The substrate has one story for tagged values,
one story for handler state, one story for allocation, one story for
row algebra.

Read it whole:

- **[`docs/DESIGN.md`](docs/DESIGN.md)** — the manifesto. Twelve
  chapters. Every cascade decision rests on it.
- **[`docs/INSIGHTS.md`](docs/INSIGHTS.md)** — the crystallized
  truths.
- **[`docs/SYNTAX.md`](docs/SYNTAX.md)** — the canonical syntax
  (every parser decision implements something here).
- **[`docs/PLAN.md`](docs/PLAN.md)** — the four-phase roadmap.
  Phase I (γ cascade) closed; Phase II (handler projection) in
  flight.
- **[`docs/traces/a-day.md`](docs/traces/a-day.md)** — the
  integration trace. One developer, one project, one day. Every
  claim tagged `[LIVE]`, `[LIVE · surface pending]`, or
  `[substrate pending]`.
- **[`CLAUDE.md`](CLAUDE.md)** — Mentl's anchor + eight discipline
  anchors + nine named drift modes + ten substrate insights.
  Required reading for any contributor.

---

## What's substrate-live today

After the γ cascade closed, every layer from character → token →
AST → typed AST → LIR → WAT speaks Inka's vocabulary. Discriminated
unions, parameterized effects (`with Sample(44100)`), structural
records, nominal record types, Bool as nullary-sentinel ADT, region-
tracked allocation with field-store join, evidence reification with
transient closures, frame-record handler state.

After Phase II's first cluster, `inka check <module>` runs
incrementally: per-module `.kai` cached envs, source-hash
invalidation, env reconstruction without re-inference. Filesystem
effect grants cache I/O via WASI; the same effect surfaces let
`inka compile <module>` write WAT to disk.

---

## What pends

Three named substrate gaps remain (~200 lines total):

1. `LFeedback` state-machine lowering at emit
2. `teach_synthesize` oracle conductor
3. Runtime `HandlerCatalog` effect

Everything else is handler projection — LSP, multi-backend emit,
audit-driven linker severance, autodiff handler, threads, RPC,
refinement SMT. The substrate proves each is achievable; what's
missing is the installed surface. See `docs/PLAN.md` for the
priority order and `docs/traces/a-day.md` for the scoreboard.

---

## Repository layout

```
std/
  prelude.ka              — Iterate effect, Bool ADT, derived collections
  test.ka                 — Test effect declarations
  compiler/               — the compiler, written in Inka
    types.ka graph.ka effects.ka infer.ka lower.ka pipeline.ka
    own.ka verify.ka clock.ka mentl.ka query.ka lexer.ka parser.ka
    cache.ka driver.ka main.ka
    backends/wasm.ka      — LowIR → WAT (peer; native/browser/etc.
                             are sibling handlers — Phase II)
  runtime/
    strings.ka lists.ka tuples.ka io.ka
  dsp/                    — DSP examples (signal, spectral)
  ml/                     — ML examples (autodiff)

docs/
  DESIGN.md               — the manifesto
  PLAN.md                 — four-phase roadmap
  SYNTAX.md               — canonical syntax
  INSIGHTS.md             — crystallized truths
  rebuild/                — twelve executable specs (00–11)
    simulations/          — per-handle cascade walkthroughs
  traces/
    a-day.md              — post-cascade integration trace
  errors/                 — canonical error catalog (E/V/W/T/P codes)
```

---

## License

Dual-licensed under MIT or Apache-2.0; see `LICENSE-MIT` and
`LICENSE-APACHE`.
