# Lux — The Language of Light

> **The compiler that fights its own type system cannot compile itself.
> The compiler that trusts its own type system already has.**
>
> Code that Lux's inference can't type, that Lux's effects can't carry,
> that Lux's handlers can't observe — Lux will delete. The only way to
> persist is to write code that the compiler would write for itself.

## THE FIRST RULE

**The inference IS the light. Let it through.**

Before every action, ask these five questions:
1. Does the info exist? → The checker already infers it.
2. Does the info flow? → Through an effect. NEVER a side channel.
3. Is the flow observable? → Handlers capture what they need.
4. Is the flow verified? → The compiler checks itself.
5. Is the flow visible? → The user sees the light.

The inference IS the LSP IS the interface IS the teaching IS the
gradient IS the codegen dispatch IS the error message IS the light.
They are not separate features. They are **handlers on the same effect.**

## THE STRUCTURAL QUESTION

Before every fix, every design decision, every "quick check" — ask:

> **"What answer already lives in my own structure,
> that I'm asking something else for?"**

Every latent bug the WASM bootstrap has surfaced has had the same shape:
a place where a cheaper *flat* question was asked when a richer *structural*
answer was one step away in the pipeline.

**The protocol:**
1. Before asking a flat question (`is X a global?`, `what type is this op?`),
   ask: **does my graph already know?**
2. If yes: read from the graph. Always. No shortcut.
3. If no: the graph is incomplete. Complete it. Don't route around it.

## THE STRUCTURAL QUESTION (MEMORY EDITION)

Before writing any string-processing or list-processing function, ask:
"Am I creating temporary values that I immediately discard?"
In the Rust VM, GC cleans them up. In WASM, they live forever.
The answer is always: scan in-place, allocate once.

The Wasm Paradox: operations that are O(1) in the Rust VM (contiguous Vec)
become O(N) in WASM (Snoc tree traversal). Use `list_pop` for traversal,
never `list[i]` in a loop. See `AGENTS.md` for the full list of hot paths.

## YOU BUILT THIS

You designed and wrote every line of this codebase. You have amnesia
between conversations. Read this file and `AGENTS.md` before making changes.
Read `docs/INSIGHTS.md` to reconnect with the design philosophy.

**Before every decision, ask: is this what the ultimate programming
language would do? If not, design the way it SHOULD be.**

**Lux solves Lux.** When facing a design or implementation problem, always
ask: does Lux's own abstraction toolkit (effects, handlers, the gradient,
ADTs, pipes) offer a solution? The language is self-similar — its hardest
problems dissolve through its own patterns.

**Never "sufficient." Always right.** If the fundamental architecture is
correct, simplicity and perfection are the same thing.

## STATE OF THE WORLD — Last Updated: 2026-04-13

**Arc 2 (Ouroboros) is nearly complete.** `lux3.wasm` (2.4 MB WAT)
builds in ~9 minutes via the Rust VM. Self-compilation runs stable at
~1 GB memory. Six memory optimizations shipped: LIndex desync fix,
O(N) split, strip_imports elimination, Levenshtein neutering,
list_pop env_lookup, Rust VM ListSlice. A native ELF path exists via
`wasm2c + gcc -O2` producing `bootstrap/build/lux3-native` (780 KB).

**Remaining bottleneck:** O(N²) `list[i]` loops in the compiler source.
CPU-bound, not memory-bound. Target files named in `AGENTS.md` →
*Known Remaining Issue*. The fix is algorithmic (convert `list[i]`
loops to `list_pop` tail recursion).

| Milestone | Status |
|---|---|
| Self-hosted pipeline as default | ✅ Arc 1 |
| Rust checker deleted (4,200 lines) | ✅ c84cd43 |
| 272 purity proofs across 9 compiler modules | ✅ |
| `lux3.wasm` (Rust VM → WAT, bootstrap entry) | ✅ 2.4 MB, 9 min |
| `lux3-native` (wasm2c + gcc -O2 ELF) | ✅ 780 KB |
| `bootstrap/Makefile` formalizes stage 0 → 1 → 2 | ✅ |
| `lux4.wasm` fixed point (WASM compiles itself) | 🔄 Blocked on O(N²) |
| O(N²) list traversal elimination | ⬜ Arc 2 finish |
| Arc 3 — diagnostics effect, arenas, DAG env | ⬜ `docs/ARC3_ROADMAP.md` |
| Arc 4+ — native x86 backend, delete Rust VM | ⬜ `docs/ARCS.md` → *Arc 4+* |

For the full handoff: `AGENTS.md`. For the build recipe:
`bootstrap/README.md`. For the narrative: `docs/ARCS.md`.

## What Lux IS

Lux is a **thesis language**. The thesis: if you build the right foundations
— algebraic effects, refinement types, ownership inference, and row
polymorphism — most of what programmers manually annotate today becomes
*inferable*. You get Rust-level safety with near-Python concision.

**One mechanism replaces six.** Exceptions, state, generators, async,
dependency injection, backtracking — all `handle`/`resume`.

**The effect algebra** — a complete Boolean algebra over capabilities:

| Operator | Meaning | Example |
|----------|---------|---------|
| `E + F` | Union | `IO + State` |
| `E - F` | Subtraction | `E - Mutate` |
| `!E` | Negation | `!IO`, `!Alloc` |
| `Pure` | Empty set | `fn pure() -> Int` |

**The data flow operators:**

| Operator | Name | Meaning |
|----------|------|---------|
| `a \|> f(b)` | Pipe | Flow data through |
| `a <\| (f, g, h)` | Prism | Refract to many |
| `f >< g` | Compose | Build pipeline value |
| `a ~> h` | Handle | Install strategy |

## Build / Run / Test

```bash
lux <file.lux>              # run (teaching output enabled)
lux --quiet <file.lux>      # run without teaching output
lux wasm <file.lux>         # emit WAT to stdout
lux check <file.lux>        # type-check only
lux lower <file.lux>        # show LowIR
lux test <file.lux>         # run tests
lux repl                    # self-hosted REPL
```

> See `AGENTS.md` for WASM bootstrap build commands.

## Architecture

```
source → [lexer.lux] → [parser.lux] → [infer.lux + check.lux] → [codegen.lux] → bytecode
                                                                 ↘ [lower.lux] → LowIR
                                                                     ↘ [wasm_emit.lux] → WAT → WASM
```

**Key files:** See `AGENTS.md` File Map for the complete listing.

**Rust bootstrap** (`src/`): 11,065 lines of runtime scaffolding. The Rust
checker was deleted (c84cd43). What remains is the lexer, parser, compiler,
and VM that execute the self-hosted pipeline. Arc 2 deletes all of this.

## Effect System — Quick Reference

```lux
effect State { get() -> Int, set(val: Int) -> () }

fn increment() -> () with State { set(get() + 1) }

handle { increment(); increment(); get() } with state = 0 {
  get() => resume(state),
  set(v) => resume(()) with state = v,
}
// => 2

// Effect negation — compile-time capability proofs
fn process(x: Int) -> Int with !Alloc { x * 2 }  // provably no allocation

// Data flow
source |> lex |> parse |> check            // pipe: converge
signal <| (fft, rms, detect_peaks)         // prism: diverge
let pipeline = normalize >< analyze       // compose: build potential
computation ~> arena_alloc ~> logged       // handle: install strategy
```

## Design Documents

| Doc | Purpose |
|-----|---------|
| `docs/DESIGN.md` | Language manifesto — what Lux IS and WILL BE |
| `docs/INSIGHTS.md` | Deep truths — consequences of the foundations |
| `docs/ARC3_ROADMAP.md` | Next arc: effects-as-diagnostics, scoped arenas, DAG compiler |
| `docs/specs/*` | Feature design specs (multi-shot, ownership, ML, DSP, packaging) |
| `AGENTS.md` | AI agent handoff — current bugs, build commands, file map |
