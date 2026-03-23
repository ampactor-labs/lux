# Lux

**A language where the compiler teaches you.**

Lux is a programming language built on one bet: if you get the foundations
right — algebraic effects, refinement types, ownership inference, row
polymorphism — most of what programmers manually annotate today becomes
*inferable*. You get Rust-level safety with near-Python concision.

Write code with no annotations. The compiler infers everything. Ask it
what it found:

```
$ lux --teach my_code.lux

=== lux teach ===

  fn add is pure (line 3)
    inferred: (a, a) -> a with Pure
    -> add `with Pure`
       parallelization, memoization, compile-time evaluation
  fn greet has effects (line 5)
    inferred: (String) -> () with Console
    -> add `with Console`
       explicit effect tracking — callers see their dependencies
  fn predict is pure (line 42)
    inferred: (Model, Input) -> Output with Pure
    -> add `with Pure`
       parallelization, memoization, compile-time evaluation
  3 functions checked: 2 pure (add `with Pure` to prove it), 1 with undeclared effects
```

Every hint is *proven*, not guessed. If the compiler says "add `with Pure`",
it's guaranteed to type-check. The gap between rapid prototype and proven
correct is a gradient — each hint is one step forward.

## One mechanism replaces six

Exceptions, state, generators, async, dependency injection, backtracking —
all `handle`/`resume`. An `effect` declares operations. A handler provides
their semantics. Zero special syntax.

```lux
// Declare what you need
effect Fail { fail(msg: String) -> Never }

fn parse_positive(n: Int) -> Int with Fail {
    if n < 0 { fail("negative: " ++ to_string(n)) }
    else { n }
}

// Caller decides how to handle it
let result = handle parse_positive(-5) {
    fail(msg) => resume(0)    // recover with default
}
// result = 0
```

Same pattern, different effect — state:

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

Testing without mocks — swap the handler:

```lux
effect Console { say(msg: String) -> () }

fn greet(name: String) -> String with Console {
    say("Greeting " ++ name ++ "...")
    "Hello, " ++ name ++ "!"
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

## The effect algebra

Lux has a complete algebra over capabilities. No other language has this.

| Operator | Syntax | Meaning |
|----------|--------|---------|
| Union | `with IO, State` | can perform IO and State |
| Negation | `with !IO` | provably cannot perform IO |
| Subtraction | `with E - Alloc` | E but provably no allocation |
| Pure | `with Pure` | provably no effects at all |

These compose. A function marked `with !Alloc` propagates that constraint
through its entire call chain — if any transitive callee allocates, the
compiler rejects it at compile time. This proves real-time safety, enables
GPU offloading, and gates auto-parallelization.

```lux
// The compiler proves this can never allocate
fn process(x: Float) -> Float with !Alloc {
    x * 0.8 |> soft_clip
}

// Subtraction reads as capability removal
fn sandbox(x: Float) -> Float with DSP - Network - Alloc {
    x |> gain(0.8) |> soft_clip
}

// Pure = provably no effects at all
fn safe_add(a: Int, b: Int) -> Int with Pure { a + b }
```

## The gradient

Every annotation you add changes what the compiler can do for you. There
are no levels — just more knowledge flowing to the compiler.

| What you write | What the compiler does |
|----------------|----------------------|
| No annotations | Infers everything. It runs. |
| Type annotations | Confirms your understanding |
| `with Pure` | Memoizes, parallelizes, compile-time evals |
| `with !Alloc` | Proves allocation-free for real-time |
| Refinement types | Proves properties, eliminates runtime checks |

The compiler shows you exactly where you are and what the next step
unlocks. It doesn't lecture — it illuminates.

## What falls out for free

These aren't planned features. They're consequences of the foundations:

- **`!Alloc` proves real-time safety.** Rust can't do this — `Vec::push` is
  safe Rust and it allocates. In Lux, `!Alloc` propagates through the entire
  call chain.
- **Pure functions parallelize.** The effect system proves it's safe. No
  annotations needed.
- **`!Network` is capability security.** Enforced by the type system, not a
  runtime sandbox.
- **Testing without mocks.** You don't mock, you `handle`. Same code,
  different handler. The type system guarantees the handler satisfies the
  effect signature.

## Current status

Lux is a research prototype. The Rust implementation is scaffolding for the
ideas — the goal is self-hosting.

**What works today:**
- Full effect system: declare, handle, resume, handler-local state
- Effect algebra: union, negation, subtraction, Pure
- Handler composition: named handlers, inheritance, bare references
- Teaching compiler (`--teach`): surfaces inferred types and effects
- Pipe operator: `x |> f |> g` for natural data flow
- Pattern matching with exhaustiveness warnings
- Self-hosted compiler: lexer → parser → checker → codegen, ALL in Lux
- ML framework: autodiff via effect handlers (XOR trains to convergence)
- DSP framework: provably safe audio processing via effect constraints
- Bytecode VM with evidence-passing optimization
- 28 working examples

**What's next:**
- Native codegen (Cranelift backend)
- Ownership inference (own/gc/rc as a menu, not a mandate)
- Refinement types (Z3-backed compile-time verification)
- Self-hosting (the compiler rewritten in Lux)

## Try it

```bash
git clone https://github.com/ampactor/lux
cd lux
cargo run -- examples/effects.lux          # see algebraic effects
cargo run -- examples/xor.lux              # ML via effect handlers
cargo run -- examples/dsp_framework.lux    # provably safe DSP
cargo run -- --teach examples/progressive_demo.lux  # the teaching compiler
```

## Design

The full language design document is at [`docs/DESIGN.md`](docs/DESIGN.md).
The implementation guide for contributors is [`CLAUDE.md`](CLAUDE.md).

## License

Licensed under either of

- Apache License, Version 2.0 ([LICENSE-APACHE](LICENSE-APACHE) or
  http://www.apache.org/licenses/LICENSE-2.0)
- MIT License ([LICENSE-MIT](LICENSE-MIT) or
  http://opensource.org/licenses/MIT)

at your option.
