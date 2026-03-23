# Lux

[![build](https://github.com/ampactor/lux/actions/workflows/ci.yml/badge.svg)](https://github.com/ampactor/lux/actions)
[![license: MIT/Apache-2.0](https://img.shields.io/badge/license-MIT%2FApache--2.0-blue.svg)](#license)

**The compiler teaches you what it knows.**

Lux is a programming language where you write code with zero annotations and
the compiler infers types, effects, purity, and allocation behavior — then
tells you what it found and what you can unlock by being more explicit.

```
$ lux examples/alloc.lux

=== lux teach ===

  fn double is allocation-free (line 13)
    inferred: (Int) -> Int with Pure
    -> add `with Pure`
       parallelization, memoization, compile-time evaluation
    -> add `with !Alloc`
       real-time audio safety, GPU offload, embedded deployment
  fn squares is pure (line 24)
    inferred: (Int) -> List<a> with Pure
    -> add `with Pure`
       parallelization, memoization, compile-time evaluation
  fn say_hello has effects (line 31)
    inferred: (a) -> () with Console
    -> add `with Console`
       explicit effect tracking — callers see their dependencies
  5 functions checked: 2 alloc-free, 2 pure, 1 effectful
```

Every suggestion is *proven*, not guessed. The gap between rapid prototype and
proven-correct is a gradient — each annotation is one step forward, and the
compiler shows you where to step next.

## Why Lux

Most languages force a choice: write fast with no safety, or write safe with
ceremony. Lux bets that the right foundations — algebraic effects, row
polymorphism, ownership inference, refinement types — make safety *inferable*.
You get Rust-level guarantees with near-Python concision.

**One mechanism replaces six.** Exceptions, state, generators, async,
dependency injection, backtracking — all one pattern: `handle`/`resume`.

```lux
effect State { get() -> Int, set(val: Int) -> () }

fn increment() -> () with State { set(get() + 1) }

let count = handle {
    increment(); increment(); increment(); get()
} with state = 0 {
    get()    => resume(state),
    set(v)   => resume(()) with state = v,
}
// count = 3
```

**Testing without mocks.** Same code, different handler:

```lux
effect Console { say(msg: String) -> () }

fn greet(name: String) -> String with Console {
    say("Hello, " ++ name ++ "!")
    name
}

// Production: real output
handle greet("Morgan") {
    say(msg) => { println(msg); resume(()) }
}

// Test: silenced — same code, different semantics
handle greet("World") {
    say(msg) => resume(())
}
```

**A complete algebra over capabilities:**

| Syntax | Meaning |
|--------|---------|
| `with IO, State` | Can perform IO and State |
| `with !IO` | Provably cannot perform IO |
| `with E - Alloc` | E minus allocation |
| `with Pure` | Provably no effects at all |

`!Alloc` propagates through the entire call chain. If any transitive callee
allocates, compilation fails. This proves real-time safety, gates GPU
offloading, and enables auto-parallelization — all from one annotation.

## The gradient

There are no "levels" — just more knowledge flowing to the compiler:

| You write | The compiler can |
|-----------|-----------------|
| Nothing | Infers everything — it runs |
| Types | Catches mismatches at compile time |
| `with Pure` | Memoize, parallelize, evaluate at compile time |
| `with !Alloc` | Prove real-time safety, offload to GPU |
| Refinement types | Prove properties, eliminate runtime checks |

## What falls out

These aren't planned features. They're consequences of the algebra:

- **`!Alloc` proves real-time safety.** Rust can't — `Vec::push` is safe Rust
  and it allocates.
- **Pure functions auto-parallelize.** The effect system proves it's safe.
- **`!Network` is capability security.** Type-system enforced, not sandboxed.
- **Testing = handler swap.** No mock framework, no DI container.

## Status

Lux is a research language under active development.

| Subsystem | Status |
|-----------|--------|
| Effect system (declare, handle, resume, handler state) | Working |
| Effect algebra (union, negation, subtraction, Pure) | Working |
| Handler composition (named, inheritance, bare refs) | Working |
| Teaching compiler (three-tier: alloc-free / pure / effectful) | Working |
| Self-hosted compiler (lexer, parser, checker, codegen — all Lux) | Working |
| Bytecode VM with evidence-passing optimization | Working |
| ML framework (autodiff via effects, XOR convergence) | Working |
| DSP framework (provably safe audio via effect constraints) | Working |
| Pattern matching with exhaustiveness warnings | Working |
| Records with row polymorphism | Working |
| Pipe operator (`x \|> f \|> g`) | Working |
| 38 examples, 31 golden-file tested | Passing |

**Next:** ownership inference (`own`/`ref`/`gc`), native codegen (Cranelift),
refinement types (Z3), full self-hosting.

## Try it

```bash
git clone https://github.com/ampactor/lux && cd lux
cargo install --path .

lux examples/effects.lux              # algebraic effects
lux examples/xor.lux                  # ML via effect handlers
lux examples/generators.lux           # generators as effects
lux examples/effect_algebra.lux       # !Alloc, Pure, negation
lux examples/alloc.lux                # three-tier teach output
lux examples/ownership.lux            # the annotation gradient
lux --quiet examples/benchmark.lux    # comprehensive test suite
```

## Prism

Lux's mascot is **Prism**, a bioluminescent comb jelly. Comb jellies diffract
white light into cascading rainbow spectra along their cilia — a living prism.
Many species also generate their own light from within.

Unannotated code enters the compiler like white light. The teach system reveals
the spectrum hidden inside — types, effects, purity, allocation freedom — each
a different band. The language illuminates itself.

## Design

The full language design is at [`docs/DESIGN.md`](docs/DESIGN.md). Deep design
philosophy and insights: [`docs/INSIGHTS.md`](docs/INSIGHTS.md).

## Contributing

Lux is early-stage and contributions are welcome. The `examples/` directory is
the best way to understand the language. Pick an example, read it, modify it,
see what the compiler tells you.

## License

Licensed under either of

- Apache License, Version 2.0 ([LICENSE-APACHE](LICENSE-APACHE) or
  http://www.apache.org/licenses/LICENSE-2.0)
- MIT License ([LICENSE-MIT](LICENSE-MIT) or
  http://opensource.org/licenses/MIT)

at your option.
