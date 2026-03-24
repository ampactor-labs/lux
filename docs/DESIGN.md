# Lux — The Language of Light

*A design manifesto. Not a description of the current implementation —
a declaration of what Lux IS and WILL BE.*

---

## The Gap

The single biggest source of bugs, complexity, and frustration in programming
isn't syntax or performance — it's the **gap between what a programmer means
and what they're forced to write.**

A programmer thinks: *"this function reads a file, parses it, and might fail."*

They write:

```rust
async fn parse(path: &Path) -> Result<Config, Box<dyn Error>>
```

They've had to manually encode: async-ness, borrowing, error boxing, lifetime
elision, trait object dispatch. None of that is what they *meant*. It's
ceremony demanded by the language to compensate for things the compiler could
figure out.

What if a language could close this gap? Not by being sloppy — not by hiding
complexity like Python or erasing types like JavaScript — but by being
**smarter about inference**?

---

## The Thesis

If you build the right foundations — algebraic effects, refinement types,
ownership inference, and row polymorphism — most of what programmers manually
annotate today becomes *inferable*. You get Rust-level safety with
near-Python-level concision. Not by being sloppy, but by being smarter
about inference.

The programmer writes what they mean:

```lux
fn parse(path: Path) -> Config with IO, Fail<ParseError> {
  let text = read_file(path)
  decode(text)
}
```

The compiler infers: that `path` is borrowed (used once, not stored), that the
`IO` effect is needed because `read_file` performs I/O, that `Fail<ParseError>`
appears because `decode` might fail. All the ceremony — borrowing, async-ness,
error boxing — handled by the machine, not the programmer.

---

## Programs Are Typed Effect Graphs

Every program does three things: **transforms data**, **performs effects**,
and **manages resources**. These aren't independent. Data shapes the effect
graph; the effect graph shapes how data flows. Types constrain which effects
are possible; effects constrain which types can exist. They're dual-coupled.

Most languages handle these three things with three separate mechanisms that
don't compose. Lux unifies them through the effect system. Effects aren't
just for I/O — they're the fundamental abstraction for anything that isn't
a pure computation.

---

## One Mechanism

Exceptions, state, generators, async, dependency injection, backtracking —
every language has ad-hoc mechanisms for these. Special syntax, special types,
special runtime support. They don't compose. They barely interoperate.

In Lux, they're all the same thing:

```lux
effect Console {
  print(msg: String) -> ()
  read_line() -> String
}

effect Fail<E> {
  fail(error: E) -> Never
}

effect State<S> {
  get() -> S
  set(val: S) -> ()
}

effect Async {
  spawn<A>(task: () -> A) -> Handle<A>
  yield() -> ()
}

effect Choice {
  choose<A>(options: List<A>) -> A
}
```

An `effect` declares operations. A `handler` provides their semantics. The
`resume` continuation gives the handler control over what happens after the
operation returns. This is one mechanism. Six patterns. Zero special syntax.

```lux
// Exception handling
handle parse(input) {
  fail(e) => default_value   // don't resume — exception caught
}

// State threading
handle computation() with state = 0 {
  get() => resume(state),
  set(v) => resume(()) with state = v,
}

// Generator / iterator
handle range(1, 10) {
  yield(v) => {
    collect(v)
    resume(())
  }
}

// Dependency injection
handle app() {
  get_config() => resume(Config::from_env()),
  get_db() => resume(connect("postgres://...")),
}

// Backtracking search
handle solve(puzzle) {
  choose(options) => {
    options.find_map(|opt| try { resume(opt) })
  }
}
```

The `with` clause on handlers introduces handler-local state — mutable
bindings scoped to the handler that evolve across resume calls:

```lux
handle computation() with count = 0, log = [] {
  increment() => resume(()) with count = count + 1,
  record(msg) => resume(()) with log = push(log, msg),
}
```

---

## The Annotation Gradient

Lux doesn't have discrete levels. Every annotation you add changes what
the compiler can prove about your code. The compiler's power scales
continuously with how much you tell it.

### No annotations: it works

```lux
fn double(x) = x * 2
```

The compiler infers `double: (Int) -> Int with Pure`. You wrote nothing
extra. It knows the type, the effect (none), and it works.

### Add `with Pure`: unlock optimizations

```lux
fn double(x) = x * 2 with Pure
```

Same function. Now the compiler can memoize it, parallelize calls,
evaluate it at compile time. You told it one thing; it gave you three
capabilities.

### Add a refinement: unlock proofs

```lux
fn double(x: Positive) -> Positive = x * 2 with Pure
```

Now the compiler proves the output is positive. Division by zero is
impossible. Buffer overflows can't happen. The SMT solver handles it.

### Add ownership: unlock real-time

```lux
fn double(x: own Int) -> own Int with Pure, !Alloc = x * 2
```

Now the compiler proves this function never allocates. Safe for audio
callbacks, embedded systems, GPU kernels.

### The compiler shows you the gradient

```
  fn double: (Int) -> Int with Pure
    → adding `with Pure` unlocks: memoization, parallelization
    → adding `x: Positive` unlocks: output proof, zero-cost bounds
    → adding `with !Alloc` unlocks: real-time safety, GPU eligibility
```

Each annotation is a conversation with the compiler. You tell it
something; it tells you what that unlocks. There's no `lux level set` —
there's just more knowledge flowing between you and the machine.

The gradient is real: Python-style prototyping → gradually tighten →
every annotation unlocks guarantees. All syntax is always valid.
You don't need everything to ship production software.

---

## The Compiler as Collaborator

Most compilers are adversaries. They reject your code and make you guess why.
Lux's compiler is a collaborator — it shows you what it knows, teaches you
what you don't, and helps you improve code you already wrote.

### The "Why" Button

Hover over any inferred annotation. See the reasoning chain:

```
let x = vec.get(idx)
          ^^^^^^^^
  Inferred: Option<ref String>

  Why Option?
    → vec.get returns Option because idx might be out of bounds
    → if you can prove idx < vec.len(), use vec[idx] which returns ref String directly

  Why ref?
    → vec owns its elements
    → get() borrows rather than moving, because vec is used again on line 12
    → if you need ownership, use vec.remove(idx) which returns own String

  Why String?
    → vec: List<String> (inferred from line 3 where you pushed a string literal)
```

Every inference has a reason. The compiler makes its reasoning transparent.

### Optimization Advisor

The compiler notices optimization opportunities and explains them:

```
advice: this function is pure — consider adding 'const' for compile-time evaluation
  15 | fn default_port() -> Port = 8080
   = this function has no effects and constant inputs

advice: this effect handler is tail-resumptive — it compiles to zero-cost direct style
   = the State handler's resume() calls are all in tail position
   = compiled representation: extra function parameters (register-passed)
   = runtime overhead: none
```

### Verification Dashboard

```
lux verify --dashboard

  Verification Status: src/
  ═══════════════════════════════════════════════
  ██████████████████████░░░  84% statically proven
  ███░░░░░░░░░░░░░░░░░░░░░  12% runtime assertions
  █░░░░░░░░░░░░░░░░░░░░░░░   4% unverified

  Unverified regions:
    src/parser.lux:42-58    — SMT timeout on recursive predicate
      hint: add intermediate assertion at line 50
```

Escape hatches are tracked. The goal is 100%. The dashboard shows your
strictness score and tells you exactly what remains unverified.

### Effect Profiler

```
  Effect Breakdown:
  Http        ████████████████░░░░  42%   (network I/O)
  Async       ████████████░░░░░░░░  31%   (task scheduling)
  Db          █████░░░░░░░░░░░░░░░  14%   (database queries)
  Pure comp   ███░░░░░░░░░░░░░░░░░   9%   (business logic)
  Log         █░░░░░░░░░░░░░░░░░░░   4%   (logging)
```

*A language should be a tool for thought, not a tax on expression.*
*And if you build it right, the tool teaches you to think better.*

---

## The Effect Algebra

Row polymorphism gives you "whatever effects, plus these." But Lux goes
further with a **complete Boolean algebra over capabilities**:

| Operator | Meaning | Example |
|----------|---------|---------|
| `E + F` | Union — effects from E or F | `IO + State` |
| `E - F` | Subtraction — E except F | `E - Mutate` |
| `E & F` | Intersection — only effects in both | `E1 & E2` |
| `!E` | Negation — any effect *except* E | `!IO`, `!Alloc` |
| `Pure` | The empty set (sugar for `!Everything`) | `fn pure() -> Int` |

No other language has this. The closest is Koka's row polymorphism, which
gives you `+` but not `-`, `&`, or `!`.

```lux
// Freeze: remove mutation capability
fn freeze<A, E>(action: () -> A with E) -> A with E - Mutate {
  handle action() {
    set(_) => compile_error!("mutation not allowed in frozen context")
  }
}

// Pure gate: provably no side effects
fn pure_computation<A>(f: () -> A with !IO) -> A { f() }

// Restrict to intersection
fn restricted<A, E1, E2>(f: () -> A with E1 & E2) -> A with E1 & E2 { f() }

// Module-level purity constraint
module type PureStorage {
  fn get(key: Key) -> Option<Value> with !IO
}
```

### Four Gates from One Algebra

The effect algebra gives you four compilation gates for free:

1. **Compile-time evaluation gate.** `!IO` functions have no observable side
   effects. The compiler can evaluate them at compile time, cache results,
   memoize across builds.

2. **Formal verification gate.** Pure functions are provable. Feed them to
   the SMT solver, prove properties, eliminate runtime checks.

3. **GPU compilation gate.** Pure functions with `!IO, !Alloc` can be
   offloaded to GPU. The compiler knows because the algebra proves it.

4. **Sandbox gate.** Effect restriction IS capability restriction. `!Network`
   means provably no network access — enforced by the type system, not
   a runtime sandbox.

---

## Refinement Types

Types with predicates, verified at compile time by Z3. Erased at runtime —
zero cost.

```lux
type Byte = Int where 0 <= self && self <= 255
type NonEmpty<T> = List<T> where self.len() > 0
type Percentage = Float where 0.0 <= self && self <= 100.0
type Port = Int where 1 <= self && self <= 65535
type Sorted<T: Ord> = List<T> where self.is_sorted()
```

The SMT solver handles the heavy lifting. The programmer writes natural
predicates:

```lux
fn head<T>(list: NonEmpty<T>) -> T = list[0]
```

You cannot call `head` on a possibly-empty list. The compiler rejects it
at the call site:

```lux
let data: List<Int> = get_data()
head(data)                          // COMPILE ERROR: List<Int> is not NonEmpty<Int>

if data.len() > 0 {
  head(data)                        // OK: guard proves non-emptiness
}
```

### Gradual Verification

When the solver can't decide, you can always write `assert` to discharge
a proof obligation at runtime:

```lux
let items = fetch_items()
assert items.len() > 0, "API guarantees non-empty response"
head(items)  // OK: assertion discharges the refinement
```

The verification dashboard tracks these. The goal is to gradually eliminate
them — tighten runtime assertions into compile-time proofs as the codebase
matures.

---

## Ownership

Ownership isn't a religion — it's a tool. GC doesn't solve everything
(try managing a socket pool with GC). Ownership doesn't solve everything
(try writing a graph data structure with affine types). Lux gives you the
real menu of tradeoffs and lets you pick per-value:

```lux
let precise = own Connection::new()   // affine: tracked, zero-cost, deterministic cleanup
let flexible = gc HashMap::new()       // GC'd: shared freely, collected eventually
let shared = rc Node::new()            // ref-counted: shared ownership
```

### Borrow Inference

Within function bodies, the compiler performs whole-body ownership inference.
It builds a "borrow graph" — conflicts are compile errors. Programmers never
write `&`, `&mut`, or lifetime annotations inside function bodies.

```lux
fn process(data: own Buffer) -> own Result {
  let header = data.slice(0, 4)   // auto-borrow: compiler sees data used later
  let body = data.split_at(4)      // auto-move: last use of data
  transform(body)
}
```

At module boundaries only: annotate `own` for ownership transfer, `ref`
for borrowing. The interface is explicit; the implementation is inferred.

### Containment Rules

The soundness solution for mixing ownership modes:

| Container | Can hold |
|-----------|----------|
| `own` | `own`, `ref`, copy types |
| `gc` | `gc`, `rc`, copy types (NOT `own`) |
| `rc` | `rc`, `gc`, copy types (NOT `own`) |

Crossing a boundary is explicit:

```lux
cache.insert("db", gc conn)  // choosing different cleanup semantics
```

---

## What You Get For Free

The best designs produce things the designer didn't plan. Here's what falls
out of the interaction between effects, refinements, ownership, and the
effect algebra — emergent capabilities that exist because the foundations
are right.

### `!Alloc` — The Real-Time Holy Grail

```lux
fn audio_callback(input: own Block<Sample>) -> own Block<Sample> with !Alloc, !IO {
  // The compiler PROVES this function:
  // - Never allocates heap memory (!Alloc)
  // - Never performs I/O (!IO)
  // - Processes audio in bounded time
  input
    |> highpass(cutoff: 80.0)
    |> compress(ratio: 4.0, threshold: -12.0)
    |> saturate(drive: 1.5)
    |> limit(ceiling: -0.1)
}
```

This is not a planned feature. It's a *consequence* of having effect negation.
`!Alloc` falls out of the algebra for free. And it solves the #1 problem in
real-time systems programming: "prove this code doesn't allocate."

Other languages can't guarantee this. Some forbid `unsafe`, but none can forbid
allocation — safe standard library operations allocate freely. In Lux, `!Alloc`
is a type-level
proof that propagates through the entire call chain. If any function in
`audio_callback`'s transitive call graph allocates, the constraint fails at
compile time.

### Automatic Parallelization

Pure functions (`!Everything`) can safely be executed in parallel — the compiler
knows because the effect system proved it. No annotations needed:

```lux
// The compiler sees: map over pure function = safe to parallelize
let results = data
  |> chunk(1000)
  |> parallel_map(|chunk| chunk.map(expensive_pure_transform))
  |> flatten()
```

### Capability Security

Effects ARE capabilities. A module without `IO` in its effect signature
cannot perform I/O — proven by the type system, not a sandbox:

```lux
// This plugin can compute and log, but CANNOT access network or filesystem
fn run_plugin(code: Plugin) -> Result with Compute, Log {
  evaluate(code)
}
```

### Testing Without a Framework

Effects make traditional testing frameworks obsolete. You don't mock — you
**handle**:

```lux
handler test_console(inputs: List<String>): Console {
  print(_) => resume(())
  read_line() => {
    let (first, rest) = inputs.split_first()
    resume(first)
  }
}

// Test with deterministic inputs — no mock library, no DI framework
handle greet() { use test_console(["World"]) }
```

### Deterministic Simulation

FoundationDB-style simulation as a language feature. Replace all
nondeterminism with handlers and you get reproducible distributed testing:

```lux
handler chaos_sim(seed: u64): Async + Http + Clock + Random {
  // Deterministic scheduling, simulated network partitions,
  // controlled clock, seeded randomness
}

#[simulation(iterations: 10000)]
fn test_distributed_consensus() {
  handle run_consensus_protocol(nodes: 5) { use chaos_sim(seed: test_seed()) }
}
```

### Free Memoization

Pure functions, same inputs → same outputs. The compiler can memoize across
builds. A cache that's provably correct — because the type system guarantees
the function has no side effects.

### Hot Code Reloading

Erlang-style hot code reloading. Swap handlers at runtime — the type system
guarantees the new handler satisfies the same effect signature. Zero downtime
deployments where the compiler proves the swap is safe.

### Free Observability

Wrap any handler with tracing — zero application code changes:

```lux
handler traced<H: Handler>(inner: H): H.Effects {
  // Intercept every effect operation, log it, then delegate to inner
}
```

### Effect-Based State Machines

Effect handlers that restrict available effects at each state give you
type-safe protocol state machines — session types for free:

```lux
effect Connection {
  connect(addr: Address) -> ()       // only in Disconnected state
  send(data: Bytes) -> ()            // only in Connected state
  disconnect() -> ()                 // only in Connected state
}
```

---

## DSP in Lux

The entire design maps onto DSP with eerie precision.

### Refinement Types for Audio

```lux
type Sample = Float where -1.0 <= self && self <= 1.0
type SampleRate = Int where self > 0
type BlockSize = Int where self.is_power_of_two()
type Frequency = Float where self > 0.0 && self < nyquist
type BiquadCoeffs = {
  b0: Float, b1: Float, b2: Float,
  a1: Float, a2: Float,
} where self.poles_inside_unit_circle()
```

The compiler PROVES your audio doesn't clip. `soft_clip` returns `Sample` —
the output is guaranteed in range by construction:

```lux
fn soft_clip(x: Float) -> Sample =
  (2.0 / pi) * atan(x)     // atan bounds output to (-pi/2, pi/2), scaled to (-1, 1)
```

### The Pipe Operator IS a Signal Chain

```lux
fn process(input: own Block<Sample>) -> own Block<Sample> with !Alloc, !IO {
  input
    |> highpass(cutoff: 80.0)
    |> compress(ratio: 4.0, threshold: -12.0)
    |> saturate(drive: 1.5)
    |> limit(ceiling: -0.1)
}
```

The `!Alloc` constraint propagates through the pipe chain — if `highpass`
allocates, the constraint on `process` fails. Every function in your signal
chain is proven allocation-free. This is the real-time audio guarantee that
every audio programmer manually enforces through code review and convention.
In Lux, it's a compiler proof.

### Audio Backends as Effect Handlers

Same DSP code, different backends:

```lux
handle dsp_graph() { use CoreAudioHandler(sample_rate: 48000, block_size: 256) }
handle dsp_graph() { use JackHandler(sample_rate: 96000, block_size: 128) }
handle dsp_graph() { use AlsaHandler(device: "hw:0", block_size: 512) }
```

The handler decides the backend. The DSP code is pure — it doesn't know
or care where the samples come from.

---

## Neural Networks and ML in Lux

The same architecture that makes Lux perfect for DSP makes it perfect for ML.
ML exercises all ten of Lux's foundational mechanisms simultaneously — making
it the ideal stress test for the language thesis.

> **Full ML framework spec:** `docs/specs/lux-ml-design.md`
> covers the complete design including autodiff as effect handling, reverse-mode
> backpropagation, optimizer state as handler-local state, hyperparameter search
> via multi-shot continuations, `!Alloc` embedded deployment, and the DSP-ML
> unification. What follows is the summary.

### The Ten Mechanisms Applied to ML

| Mechanism | ML Capability |
|-----------|--------------|
| Effects | Autodiff — model performs `Compute`, handler records tape |
| Handler-local state | Optimizer state (Adam momentum/variance) |
| Effect algebra | `!Random` deterministic inference, `!Alloc` embedded deployment |
| Refinement types | Compile-time shape checking, parameter constraints |
| Ownership | Zero-copy data pipelines, deterministic memory |
| Pipes | Model = computation graph = DSP signal chain |
| Multi-shot | Hyperparameter search as handler strategy |
| Row polymorphism | Effect-generic model combinators |
| Evidence-passing | Zero-overhead autodiff at compile time |
| Progressive levels | ML education path L1→L5 |

### Compile-Time Dimension Checking

```lux
type Layer<In, Out> = Tensor where self.shape == (In, Out)

fn forward(input: Tensor<784>, w1: Layer<784, 256>, w2: Layer<256, 10>) -> Tensor<10> {
  input |> matmul(w1) |> relu |> matmul(w2) |> softmax
}
```

Mismatched layer dimensions are compile errors, not runtime crashes.
`Layer<784, 256>` connected to `Layer<128, 10>` fails at compile time.

### Autodiff as Effect Handling

Model code performs `Compute` effects — it does not know about gradients.
The training handler intercepts operations, computes forward, and records
the tape. The inference handler just computes. Same model code, different
handler.

```lux
effect Compute {
  matmul<M, N, K>(a: Matrix<M, K>, b: Matrix<K, N>) -> Matrix<M, N>
  relu<S>(x: Tensor<f32, S>) -> Tensor<f32, S>
  // ...
}

// Training: records tape in handler-local state
handle model.forward(input) with tape = [] {
  matmul(a, b) => {
    let out = native_matmul(a, b)
    resume(out) with tape = push(tape, MatMul { a: a, b: b, out: out })
  },
}

// Inference: just computes — with !Alloc, !Random proves safety
handle model.forward(input) {
  matmul(a, b) => resume(native_matmul(a, b)),
}
```

### GPU Dispatch as a Compilation Gate

`!IO, !Alloc` functions can be automatically offloaded to GPU — the compiler
proves it's safe. No CUDA, no `.to(device)`. This requires Phase 12 (LLVM).

### The Pipe Operator IS the Computation Graph

```lux
audio |> mfcc(40, 160) |> conv1d(40, 32, kernel: 3) |> relu |> dense(12) |> softmax
```

DSP and ML compose in one pipe. Pure functions auto-parallelize across
data shards. Every DSP stage is a candidate for replacement by a learned
component — and vice versa.

---

## Error Messages That Illuminate

Three principles: **say what's wrong in domain terms** (not type theory
jargon), **show what the compiler knows** (and what it can't prove),
**suggest a fix** that's actually idiomatic.

```
error: this list might be empty
  --> src/main.lux:12:15
   |
12 |   let first = head(user_input)
   |               ^^^^^^^^^^^^^^^^
   |
   = head requires NonEmpty<T> (a list with at least one element)
   = user_input: List<String> — could be empty

   help: add a guard before this call
   |
11 +   if user_input.is_empty() { return default_value }
12 |    let first = head(user_input)  // now proven non-empty
```

The compiler knows types, effects, ownership, and refinements at every point
in the program. It can give you the error message you actually need — not
"`expected NonEmpty<List<String>>, found List<String>`" but "this list might
be empty" with a fix that proves it isn't.

```
note: handler for `Choice` uses multi-shot continuation
 --> src/search.lux:15:3
  |
  = each `resume` allocates O(stack_depth) bytes
  = this is expected for backtracking search
```

Even dependency auditing speaks in human terms:

```
  json-parser v1.2.0
    effects: (pure)                    ✓ expected for a parser

  sketchy-logger v0.4.0
    effects: Log, Http, FileSystem     ⚠ WARNING: a logger that needs Http and FileSystem?
```

---

## Compilation Targets and Self-Hosting

Every language starts as a parasite. The first C compiler was written in
assembly. The first Rust compiler was written in OCaml. Lux starts as a
Rust project — and Lux will kill the host.

### The Bootstrap Path

| Phase | What |
|-------|------|
| Phase 1-2 | Compiler written in Rust (bootstrap) |
| Phase 3 | Self-hosting begins — parser and type checker rewritten in Lux |
| Phase 4+ | Full self-hosting — Lux compiler compiled by Lux |
| Final | The Rust implementation becomes historical |

Self-hosting isn't vanity — it's the proof that the language works. If Lux
can express its own compiler cleanly, it can express anything.

### Why Rust for the Host

Speed. LLVM bindings. Z3 bindings for the refinement checker's SMT solver.
Memory safety without GC pauses. Algebraic types for representing AST nodes.
Rust is the best language for writing a language that will replace it.

### The Compiler's Own Effects

```lux
effect Compile {
  parse(source: String) -> Ast with Fail<ParseError>
  type_check(ast: Ast) -> TypedAst with Fail<TypeError>
  check_refinements(typed: TypedAst) -> VerifiedAst with Smt, Fail<RefineError>
  compile_effects(verified: VerifiedAst) -> EffectIr
  generate_code(ir: EffectIr) -> MachineCode with IO
}

effect Smt {
  query(predicate: Predicate) -> SmtResult
  push_scope() -> ()
  pop_scope() -> ()
}
```

### Compilation Pipeline

```
Parsing + Desugaring → Core AST
  → Bidirectional type inference → Typed AST (types, effects, ownership)
    → Refinement checking → SMT queries to Z3
      → Effect compilation → CPS transform (handlers → continuation frames)
        → Ownership compilation → Insert drops, borrows, moves
          → SSA optimization + effect-specific (handler inlining, allocation sinking)
            → Code generation → LLVM IR → native code
```

### Effect Representation Polymorphism

The performance answer — different handlers compile differently:

| Handler Pattern | Compiled Form | Overhead |
|----------------|---------------|----------|
| Tail-resumptive (~85% of handlers) | Evidence passing — extra function args | ~0 (register-passed) |
| Linear (resume once) | CPS, single-use continuation | One allocation per handler install |
| Multi-shot (resume many) | Full continuation capture | Heap allocation per resume |

### Targets

| Target | Backend | Use Case |
|--------|---------|----------|
| Native (dev) | Cranelift | Fast compilation, REPL, development |
| Native (release) | LLVM | Maximum optimization, production |
| WebAssembly | Cranelift/LLVM | Browser playground, web apps |
| Embedded | LLVM | `!Alloc` verified, no_std, real-time |

Cranelift first, LLVM for release. Incremental compilation from day one
(Salsa-style demand-driven computation). The compiler must be fast enough
for the REPL to feel instant.

### Bytecode VM (Intermediate Target)

Before native codegen: a stack-based bytecode VM. 10-100x speedup over
tree-walking interpretation. Enables the browser playground (WASM-compiled VM).
Evidence-passing compilation (Koka-style) delivers near-native performance
for the common case.

---

## What Lux Must Avoid

1. **Haskell's ecosystem fragmentation.** Too many ways to do the same
   thing — five string types, three build systems, competing effect
   libraries. Lux has ONE string type, ONE effect system, ONE way to do I/O.

2. **Rust's compile time pain.** Cranelift first, LLVM for release.
   Incremental compilation from day one (Salsa). The compiler must be fast
   enough for the REPL to feel instant.

3. **Go's simplicity trap.** Go was so simple it pushed complexity onto
   the programmer. Omitting generics didn't eliminate complexity — it moved
   it into runtime casts and code generation. A language should handle
   complexity in the compiler, not the programmer's head.

4. **TypeScript's "any" escape hatch culture.** Gradual features should
   be tracked and gradually eliminated. The verification dashboard shows
   your strictness score. The goal is 100%.

5. **Java's ceremony.** Every feature should make programs *shorter*,
   not longer. If a feature adds syntax without removing annotation
   burden elsewhere, it's not worth having.

---

## What Makes Lux Different

Not Koka — which has row-polymorphic effects but no ownership, no
refinements, no progressive levels.

Not OCaml 5 — which bolted effects onto an existing language as a
runtime mechanism.

Not Eff — which is a research language that proved effects work but
never aimed at production.

Not Rust — which has ownership but no effects, no refinement types,
and makes you encode everything manually.

Not Haskell — which has a sophisticated type system but encoded effects
in monads and never unified the approach.

Lux is a thesis language taken to production. The thesis: that effects,
refinements, and ownership compose into something greater than their sum.
The proof: every example that runs, every program that type-checks, every
`!Alloc` constraint that propagates.

---

## Lux as Connective Tissue

Lux isn't a standalone project. It's the language that every other project
in the portfolio has been asking for.

**sonido** (real-time audio): `!Alloc` proves audio callbacks are real-time
safe. Effects replace plugin host adapters. Refinement types prove Sample
bounds and filter stability. The pipe operator IS the signal chain.

**hourglass / EEQ** (unified theory): Refinement types on mathematical
structures. The dual coupling — data shapes effect graph, effect graph
shapes data flow — IS the versor architecture expressed as a type system.

**flowpilot** (algorithmic trading): `!Alloc` for hot-path order execution.
Effect state machines for position lifecycle management. Safety gates as
effect handlers — the type system enforces risk limits.

Every constraint hit in languages without effect algebra — "can't prove no
allocation," "can't express capability restriction," "mocking requires a
framework" — Lux resolves structurally. The language is the throughline project. Everything else is
a projection.

---

## The Unification

What does the programmer get?

**Six things to learn become one.** Exceptions, state, generators, async,
DI, backtracking — all `handle`/`resume`. Master one mechanism, understand
six patterns.

**Honesty about resources.** Not the false choice between "GC everything"
and "own everything." A real menu — `own`, `ref`, `gc` — where the compiler
infers most choices and you override where it matters.

**The error messages you'd want to write.** The compiler knows types,
effects, ownership, and refinements at every point. It has more information
than any existing compiler. It uses that information to teach, not punish.

**The effect algebra.** A complete Boolean algebra over capabilities that
gives you, as emergent properties, real-time proofs, auto-parallelization,
capability security, and formal verification gates.

---

## Why "Lux"

Latin for light. A unit of illumination.

On the surface: a language that makes your program's structure *visible*.
Types, effects, ownership, refinements — all illuminated at every point.
Light through a prism, separating into its constituent effects.

Deeper: **clarity**, not simplicity. Simplicity can be reductive — papering
over real complexity with false ease. Clarity means the complexity is real
and present, but *visible*. The compiler is a collaborator that illuminates
rather than an adversary that rejects. The gap between what you mean and
what you write approaches zero, not because the language is simple, but
because it's *clear*.

A language where nothing is hidden. Where the tool teaches you to think
better. Where the type system doesn't constrain your expression — it
amplifies it.

Lux. Light. The medium of understanding.

*(It helps that monosyllabic language names — Rust, Zig, Go, Nim — have
a good track record.)*

---

## The Prototype Is the Thesis Prover

The current implementation is a bytecode VM written in Rust, with a
self-hosted compiler (lexer, parser, checker, codegen) written in Lux itself.
The Rust code is scaffolding. Every example that runs is evidence. Every
handler that composes is proof. The goal is full self-hosting — deleting
every `.rs` file.

The thesis: algebraic effects + refinement types + ownership inference
close the gap between what programmers mean and what they write.

The proof: the Lux programs that already exist.

The destination: a compiled language with its own compiler, its own
toolchain, its own identity. A language of light.
