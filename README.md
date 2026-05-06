# Mentl

> *The ultimate intent → machine instruction medium. The compiler
> IS the AI. The graph IS the program. The handler IS the backend.
> The pipe IS the universal notation. The medium refuses ceremony
> the graph doesn't require. The medium raises its users.*

Mentl is not a programming language. It is a **medium** — a lens
clear enough that a programmer looks through it and sees their
intent, realized as machine instructions, for any domain they
choose. Mentl — an octopus-shaped oracle, She / Her — reads the
graph underneath and teaches the programmer one step at a time.
She explores hundreds of alternate realities per second under
the surface; She surfaces only what's proven.

File extension: `.mn` (the last two letters of Mentl).

---

## The minimal kernel — eight primitives, load-bearing together

Remove any one and the medium collapses AND Mentl loses a
tentacle. Every framework dissolution, every performance claim,
every domain unification is a consequence of composing the eight.
**Mentl is an octopus because the kernel has eight primitives;
each tentacle is one primitive's voice surface.**

1. **Graph + Env** — the program IS the graph; every output
   (WAT, hover, diagnostic, audit, Mentl's voice) is a handler
   projection. Flat-array, O(1) chase, trail-based rollback.
   *(Mentl tentacle: **Query**.)*
2. **Handlers with typed resume discipline** — `handle` /
   `resume` replaces exceptions, state, generators, async, DI,
   backtracking. Each effect op carries `@resume=OneShot |
   MultiShot | Either` as part of its type. **MultiShot-typed
   arms are the substrate Mentl's oracle uses to explore hundreds
   of alternate realities per second** under trail-based
   rollback. Handler chains (`~>`) ARE capability stacks,
   compile-time-proven. *(Tentacle: **Propose**.)*
3. **Five verbs** — `|>` converge, `<|` diverge, `><` parallel,
   `~>` handler-attach, `<~` feedback. **Topologically complete
   basis for computation graphs.** DSP, ML, compilers,
   distributed systems, control loops all share the same
   notation. *(Tentacle: **Topology**.)*
4. **Full Boolean effect algebra** — `+ - & ! Pure`. **Negation
   (`!E`) proves ABSENCE of capability** — strictly more
   expressive than every production effect system. `!Alloc`
   proves real-time. `!IO` proves compile-time-evaluable.
   `!Network` proves sandboxed. *(Tentacle: **Unlock**.)*
5. **Ownership as an effect, inferred** — `own` performs
   `Consume`, `ref` is a row constraint, `affine_ledger`
   enforces linearity. Rust-level safety without lifetime
   annotations; same Boolean algebra as every other effect.
   *(Tentacle: **Trace**.)*
6. **Refinement types** — compile-time proof, runtime erasure.
   `type Port = Int where 1 <= self && self <= 65535`. `Verify`
   effect swaps to SMT (Z3/cvc5/Bitwuzla by residual theory)
   with no source change. *(Tentacle: **Verify**.)*
7. **The continuous annotation gradient** — each annotation
   unlocks one specific compile-time capability. Zero
   annotations → code runs; each step narrows; bottom (pure
   inference) and top (total specification) converge. **Mentl
   surfaces ONE highest-leverage next step per turn, proven
   before offered.** *(Tentacle: **Teach**.)*
8. **HM inference, live, one-walk, productive-under-error, with
   Reasons** — types + effect rows + ownership + refinements
   inferred in one pass; graph-direct; errors become
   `NErrorHole`s, walk continues; every binding records a
   `Reason`; the Why Engine walks the reason DAG. *(Tentacle:
   **Why**.)*

Authoritative enumeration with chapter pointers: **[DESIGN.md
§0.5](docs/DESIGN.md).**

**One kernel. Eight primitives. Eight interrogations (what the
programmer asks before each line). Eight tentacles (what Mentl
surfaces as voice). Mentl is the kernel made voice; the octopus
framing is architectural, not decorative.**

---

## What composes out

- **Every framework dissolves into a handler.** GC, package
  managers, test runners, build tools, DI containers, LSP
  servers, doc generators, debuggers, REPLs, ML frameworks,
  DSP frameworks, RPC systems.
- **Every deployment target is a backend handler choice.** WASM,
  native x86/ARM, GPU, interpreter, test sandbox. Same source,
  different handler stack, different binary.
- **Every speed claim falls out of completeness of proof.** `Pure`
  → memoize + parallelize. `!Alloc` → emit without allocation-
  tracking. `!IO` → constant-fold. The ergonomic default is
  the performant default.
- **Every domain is a handler stack.** Frontend, backend, DSP,
  robotics, sensors, ML, embedded, systems — one substrate.
  The industry's domain-specialty fragmentation is a consequence
  of language fragmentation; Mentl dissolves it.
- **Mentl is the compiler's voice.** She reads the graph,
  explores alternate realities via multi-shot, surfaces one
  proven suggestion at a time. **She makes modern agentic
  coding AI obsolete not by competing with it but by making the
  compiler itself the oracle that proves before it speaks.**
- **The closing fixed point** — byte-identical self-compilation
  — is the soundness proof stronger than any external checker.

---

## Read it whole

- **[`docs/DESIGN.md`](docs/DESIGN.md)** — the manifesto. §0.5
  enumerates the kernel; twelve chapters develop it. Every
  cascade decision rests on it.
- **[`docs/SUBSTRATE.md`](docs/SUBSTRATE.md)** — canonical substrate;
  kernel, verbs, algebra, handlers, gradient, refinement, theorems.
- **[`docs/SYNTAX.md`](docs/SYNTAX.md)** — the canonical syntax;
  every parser decision implements something here.
- **[`ROADMAP.md`](ROADMAP.md)** — the canonical roadmap. Current
  priority, sequencing, and session-entry guidance live here.
- **[`docs/traces/a-day.md`](docs/traces/a-day.md)** — the
  integration trace. One developer, one project, one day. Every
  claim tagged `[LIVE]` / `[LIVE · surface pending]` /
  `[substrate pending]`.
- **[`CLAUDE.md`](CLAUDE.md)** — Mentl's anchor; the eight-primitive
  kernel as a working reference; eight discipline anchors; nine
  named drift modes; ten substrate insights. Required reading
  for any contributor.

---

## What's substrate-live today

After the γ cascade closed, every layer from character → token →
AST → typed AST → LIR → WAT speaks Mentl's vocabulary.
Discriminated unions, parameterized effects (`with Sample(44100)`),
structural records, nominal record types, Bool as nullary-sentinel
ADT, region-tracked allocation with field-store join, evidence
reification with transient closures, frame-record handler state.

After Phase II's first cluster, `mentl check <module>` runs
incrementally: per-module `.kai` cached envs, source-hash
invalidation, env reconstruction without re-inference. Filesystem
effect grants cache I/O via WASI; the same effect surfaces let
`mentl compile <module>` write WAT to disk.

---

## What pends

Two independent pieces of Priority 1 substrate remain:

1. **`LFeedback` state-machine lowering at emit** (~100 lines).
   The fifth verb's runtime realization.
2. **Mentl-voice substrate** — the `Interact` effect + voice
   grammar + one-at-a-time surfacing discipline + multi-shot
   `enumerate_inhabitants` owned by Mentl. Absorbs the former
   `teach_synthesize` and `HandlerCatalog` gaps. Walkthrough:
   [`MV-mentl-voice.md`](docs/specs/simulations/MV-mentl-voice.md).

Everything else is handler projection on the existing substrate —
editor integration, multi-backend emit, audit-driven linker
severance, autodiff handler, threads, RPC, refinement SMT. See
[`ROADMAP.md`](ROADMAP.md) for the priority order;
[`docs/traces/a-day.md`](docs/traces/a-day.md) is the scoreboard.

---

## Repository layout

```
std/
  prelude.mn              — Iterate effect, Bool ADT, derived collections
  test.mn                 — Test effect declarations
  compiler/               — the compiler, written in Mentl
    types.mn graph.mn effects.mn infer.mn lower.mn pipeline.mn
    own.mn verify.mn clock.mn mentl.mn query.mn lexer.mn parser.mn
    cache.mn driver.mn main.mn
    backends/wasm.mn      — LowIR → WAT (peer; native/browser/etc.
                             are sibling handlers — Phase II)
  runtime/
    strings.mn lists.mn tuples.mn io.mn
  dsp/                    — DSP examples (signal, spectral)
  ml/                     — ML examples (autodiff)

ROADMAP.md                — canonical roadmap (repo root)
docs/
  DESIGN.md               — the manifesto (§0.5 = the kernel)
  SUBSTRATE.md            — canonical substrate (kernel, verbs, algebra, handlers, gradient, refinement, theorems)
  SYNTAX.md               — canonical syntax
  specs/                  — twelve executable specs (00–11)
    simulations/          — per-handle cascade walkthroughs
  traces/
    a-day.md              — post-cascade integration trace
  errors/                 — canonical error catalog (E/V/W/T/P codes)
```

---

## License

Dual-licensed under MIT or Apache-2.0; see `LICENSE-MIT` and
`LICENSE-APACHE`.
