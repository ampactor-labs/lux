# Lux

[![build](https://github.com/ampactor/lux/actions/workflows/ci.yml/badge.svg)](https://github.com/ampactor/lux/actions)
[![license: MIT/Apache-2.0](https://img.shields.io/badge/license-MIT%2FApache--2.0-blue.svg)](#license)

**Effects are the universal abstraction. The pipe is the universal notation. The compiler is a teacher.**

Lux is a programming language built on algebraic effects. You write code
with zero annotations and the compiler infers types, effects, purity, and
allocation behavior — then teaches you what it found and what you can unlock
by being more explicit.

```lux
// A neural network. An audio callback. A search algorithm.
// Same mechanism: handle/resume. Same notation: |>

fn tiny_net(x) =
  x |> linear("h1", 1, 1) |> d_tanh |> linear("out", 1, 1)

fn audio_callback(sample) =
  sample |> gain(drive) |> soft_clip |> mix(dry, wet)

fn solve(n, placed, row) = {
  let col = choose(range(1, n + 1))
  if safe(placed, row, col) { solve(n, push(placed, col), row + 1) }
  else { [] }
}
```

## One mechanism replaces six

Exceptions, state, generators, async, dependency injection, backtracking —
all one pattern: `effect`/`handle`/`resume`.

```lux
effect State { get() -> Int, set(val: Int) -> () }

fn increment() -> () with State { set(get() + 1) }

let count = handle {
    increment(); increment(); increment(); get()
} with state = 0 {
    get()  => resume(state),
    set(v) => resume(()) with state = v,
}
// count = 3
```

Same code, different handler — testing without mocks:

```lux
effect Console { say(msg: String) -> () }

// Production: real output
handle greet("World") { say(msg) => { println(msg); resume(()) } }

// Test: silenced — same code, different semantics
handle greet("World") { say(msg) => resume(()) }
```

## Nondeterministic search

`resume()` can be called multiple times in one handler arm.
This turns any computation into a search:

```lux
effect Choose { choose(options: List) -> Int }

fn solve_queens(n, placed, row) = {
  if row > n { placed }
  else {
    let col = choose(range(1, n + 1))
    if threatens(placed, row, col) { [] }
    else { solve_queens(n, push(placed, [row, col]), row + 1) }
  }
}

// First solution:
let solution = handle { solve_queens(4, [], 1) } {
  choose(options) => fold(options, [], |acc, opt|
    if len(acc) > 0 { acc } else { resume(opt) })
}
// => [[1,2], [2,4], [3,1], [4,3]]  ✓
```

```
. Q . .
. . . Q
Q . . .
. . Q .
```

## Hyperparameter search as an effect

Choose wraps training. Search wraps ML. Effects compose vertically:

```lux
let results = handle {
  let lr = choose([0.01, 0.05, 0.1, 0.3, 0.5])
  let final_w = train(20, target, lr)
  [[lr, final_w, compute_loss(final_w, target)]]
} {
  choose(options) => fold(options, [], |acc, opt| acc ++ resume(opt))
}
// => all 5 (lr, w, loss) results — grid search in 5 lines
```

```
lr=0.01  w=0.999  loss=1.003
lr=0.05  w=1.818  loss=0.033  ███████████████████████████████
lr=0.1   w=1.983  loss=0.000  ████████████████████████████████████████████████
lr=0.3   w=2.000  loss=0.000  ████████████████████████████████████████████████
lr=0.5   w=2.000  loss=0.000  ████████████████████████████████████████████████
```

No framework. No library. The effect system that handles state also handles
nondeterminism. The handler that catches failures also drives backtracking.
Same mechanism. Different handler. Different math.

## The differentiable audio pipeline

DSP processors are pure functions. ML optimizes their parameters.
Search picks the best hyperparameters. Three effect systems, nested:

```lux
fn audio_process(sample, drive, mix_amt) =
  sample |> dsp_gain(drive) |> soft_clip |> dsp_gain(0.7)
  |> dsp_mix(sample, mix_amt)

// Same callback — inference or training. Just change the params.
let targets = process_batch(inputs, 2.5, 0.7)       // target sound
let learned = train_loop(inputs, targets, 0.5, 0.2)  // learn params
// loss: 0.12 → 0.0000000000000000000000000074  ✓

// Search over learning rates × training × DSP — three layers
let best = handle {
  let lr = choose([0.1, 0.3, 0.5, 1.0, 2.0])
  let params = train_loop(inputs, targets, 0.5, 0.2, lr, 30)
  [[lr, signal_loss(params, targets)]]
} {
  choose(options) => fold(options, [], |acc, opt| acc ++ resume(opt))
}
```

The synthesizer that tunes itself. No framework boundaries between
DSP, ML, and search — they're all effects, and effects compose.

## The gradient

There are no "levels" — just more knowledge flowing to the compiler:

| You write | The compiler can |
|-----------|-----------------|
| Nothing | Infers everything — it runs |
| Types | Catches mismatches at compile time |
| `with Pure` | Memoize, parallelize, evaluate at compile time |
| `with !Alloc` | Prove real-time safety, offload to GPU |
| Refinement types | Prove properties, eliminate runtime checks |

**A complete algebra over capabilities:**

| Syntax | Meaning |
|--------|---------|
| `with IO, State` | Can perform IO and State |
| `with !IO` | Provably cannot perform IO |
| `with E - Alloc` | E minus allocation |
| `with Pure` | No declared effects — safe to memoize and parallelize |

## What falls out

These aren't planned features. They're consequences of the algebra:

- **`!Alloc` proves real-time safety.** Audio callbacks, embedded systems —
  compile-time proof that no heap allocation occurs in the entire call chain.
- **Autodiff as an effect.** Same model code trains or infers depending on
  which handler wraps it. `d/dx(x²) at x=3 ≈ 6.0` ✓
- **DSP × ML × Search.** Differentiable audio pipelines with hyperparameter
  search. Three effect layers, nested, composing without adapter code.
- **Search as an effect.** `choose()` + multi-shot `resume()` = backtracking,
  constraint solving, hyperparameter sweeps — all user-defined handlers.
- **Pure functions auto-parallelize.** The effect system proves it's safe.
- **Testing = handler swap.** No mock framework, no DI container.

## Status

Lux is a research language under active development.

| Subsystem | Status |
|-----------|--------|
| Effect system (declare, handle, resume, handler state) | ✅ Working |
| Multi-shot continuations (resume N times in one handler) | ✅ Working |
| Nested handler composition (handlers inside resumed continuations) | ✅ Working |
| Effect algebra (union, negation, subtraction, Pure) | ✅ Working |
| Teaching compiler (infers types, effects, purity, !Alloc) | ✅ Working |
| Self-hosted compiler (lexer, parser, checker, codegen — all Lux) | ✅ Working |
| Self-hosted VM (1016 lines of Lux, full compile+execute pipeline) | ✅ Working |
| **Bootstrap (Lux compiles and executes Lux programs)** | **✅ Working** |
| Bytecode VM with evidence-passing optimization | ✅ Working |
| Ownership enforcement (`own` = affine, `ref` = scoped) | ✅ Working |
| Refinement types with Z3 verification | ✅ Working |
| Pattern matching with exhaustiveness checking | ✅ Working |
| Records with row polymorphism | ✅ Working |
| Pipe operator (`x \|> f \|> g`) | ✅ Working |
| 52 examples, 42 unit tests, 7 crucibles | ✅ Passing |

## Try it

```bash
git clone https://github.com/ampactor/lux && cd lux
cargo install --path .

# The crucibles — aspirational programs that stress-test the language
lux examples/crucible_search.lux       # N-Queens via backtracking effects
lux examples/crucible_ml.lux           # autodiff as algebraic effects
lux examples/crucible_dsp.lux          # real-time audio via effect handlers
lux examples/crucible_dsp_stateful.lux # biquad filter with handler-local state
lux examples/crucible_compose.lux      # vertical effect composition
lux examples/crucible_dsp_ml.lux       # differentiable audio pipeline

# The bootstrap — Lux compiling and executing itself
lux --no-check examples/crucible_bootstrap.lux  # self-hosted pipeline end-to-end

# Foundations
lux examples/effects.lux               # algebraic effects
lux examples/stateful.lux              # handler-local state
lux examples/generators.lux            # generators as effects
lux examples/effect_algebra.lux        # !Alloc, Pure, negation
lux examples/alloc.lux                 # teaching compiler output
lux examples/ownership.lux             # the annotation gradient
lux --quiet examples/benchmark.lux     # comprehensive test suite
```

## Prism

Lux's mascot is **Prism**, a bioluminescent comb jelly — a creature that
diffracts white light into rainbow spectra along its cilia. Unannotated code
enters the compiler like white light; the teach system reveals the spectrum
hidden inside.

## Design

The full language design is at [`docs/DESIGN.md`](docs/DESIGN.md). Deep design
philosophy and insights: [`docs/INSIGHTS.md`](docs/INSIGHTS.md). Specification
for multi-shot continuations: [`docs/specs/multi-shot-continuations.md`](docs/specs/multi-shot-continuations.md).

## Contributing

Lux is early-stage and contributions are welcome. The `examples/` directory is
the best way to understand the language. Start with the crucibles — they show
what the language can do today and what it demands next.

## License

Licensed under either of

- Apache License, Version 2.0 ([LICENSE-APACHE](LICENSE-APACHE) or
  http://www.apache.org/licenses/LICENSE-2.0)
- MIT License ([LICENSE-MIT](LICENSE-MIT) or
  http://opensource.org/licenses/MIT)

at your option.
