# Inka — The Medium

*A design manifesto. Not a description of the current implementation —
a declaration of what Inka IS. Written unconstrained, measured against
the vision alone.*

---

## 0. The Gap

There is a gap. It runs through every modern programming language, and
it is the largest single source of bugs, complexity, and frustration in
software.

The gap is not between a programmer and their tools. It is between
what a programmer *means* and what they are *forced to write*. A
programmer thinks: "this function parses a file and might fail." They
write:

```rust
async fn parse(path: &Path) -> Result<Config, Box<dyn Error>>
```

None of that is what they meant. It is ceremony — async-ness,
borrowing, error boxing, lifetime elision, trait-object dispatch —
demanded by the language to compensate for what the compiler cannot
figure out on its own. The bridge between human thought and machine
instruction yielded, long ago, to the machine.

Inka closes the gap.

Not by being sloppy. Not by hiding complexity under untyped dynamism.
Not by papering over memory with a runtime garbage collector. By being
**smarter about inference** — by giving the compiler a single
mechanism so expressive that every ceremony dissolves into something
the compiler already knows.

The programmer writes what they mean:

```
fn parse(path: Path) -> Config with IO, Fail<ParseError> =
    path
        |> read_file
        |> decode
```

The compiler infers that `path` is borrowed (used once, not stored);
that `IO` propagates into `parse`'s effect row because `read_file`
performs I/O and `|>` unions effect rows along the chain; that
`Fail<ParseError>` appears because `decode` might fail; that the
pipe chain is three stages with a composed effect row. All ceremony,
handled by the machine — not the programmer.

This is the surface. Beneath the surface, Inka is not a language. It
is a **medium**.

A tool is something you pick up and put down. A medium is something
you see through. When the medium is right, you forget it is there;
you see your intent, realized. That is Inka's destination. A lens so
clear the programmer looks through it and sees their program — not the
language.

This document is the design of that medium. It is written assuming
every module is already perfect. It measures itself against the
vision, not against any bootstrap compiler. It is the wheel, not the
lathe.

**There is one mechanism. Everything else falls out.**

---

## 1. The One Mechanism

Exceptions. State. Generators. Async. Dependency injection.
Backtracking. Every mainstream language has ad-hoc mechanisms for these
six patterns — special syntax, special types, special runtime support.
They don't compose. They barely interoperate. A Rust programmer who
masters async does not, by that mastery, understand exceptions; a
Haskell programmer who masters monads does not, by that mastery,
understand backtracking.

In Inka, all six are the same thing: an **effect operation** intercepted
by a **handler** with a **continuation**.

```
effect Fail<E>       { fail(error: E) -> Never }
effect State<S>      { get() -> S; set(v: S) -> () }
effect Iterate       { yield(v: T) -> () }
effect Async         { spawn(task: () -> A) -> Handle<A>; await() -> () }
effect Choice        { choose(options: List<A>) -> A }
effect Console       { print(msg: String) -> () }
```

The angle-bracketed names (`<E>`, `<S>`, and the free `A` / `T` inside
op signatures) are **generic type parameters** — placeholders for "any
type." `Fail<E>` means "for any type `E`, here is a `fail` op that
takes an `E`." At every call site, inference binds the parameter
concretely from context. Same mechanic as Haskell's type variables
and Rust's `<T>`; zero syntactic ceremony — the compiler just fills
them in.

An `effect` declares operations. A `handler` provides their semantics.
The `resume` continuation gives the handler control over what happens
after the operation returns. **One mechanism. Six patterns. Zero
special syntax.**

```
// Exception handling — handler chooses not to resume
handle parse(input) { fail(e) => default_value }

// State threading — handler-local state evolves across resumes
handle computation() with s = 0 {
    get()    => resume(s),
    set(v)   => resume(()) with s = v,
}

// Generator — handler collects yielded values
handle range(1, 10) with xs = [] {
    yield(v) => resume(()) with xs = push(xs, v),
}

// Dependency injection — handler provides the dependency
handle app() { get_db() => resume(connect("postgres://...")) }

// Backtracking search — handler calls resume N times, picks first success
handle solve(puzzle) {
    choose(options) => options |> find_map(|o| try { resume(o) })
}
```

**Reading `handle`.** The shape is `handle <expression> { op_name(args)
=> <arm_body> }`. The expression on the left is the computation you
want to run; the arms on the right intercept *effect operations* the
expression performs. An `op` inside an arm is the name declared by
some `effect` block. Normal function calls pass through unhandled;
only declared effect ops route to arms. So in the DI example above,
`app()` is the body; somewhere inside `app`, code performs `get_db()`
(an effect op), and the arm fires to supply a real connection.
`app()` never said where the DB came from — the handler decided.
That is dependency injection with no container.

The backtracking example is the densest of the six; worth glossing
carefully. The lambda `|o| try { resume(o) }` takes one candidate and
tries resuming the rest of `solve` with that candidate; `try { ... }`
swallows a failure if the continuation dead-ends. `find_map` walks
the options, applying the lambda to each, returning the first
candidate that didn't dead-end. The handler calls `resume`
potentially many times — one per candidate explored. This is
multi-shot continuation: the same continuation re-entered with
different values, each exploring a different branch of the search
tree.

Master one mechanism, understand every pattern. But this is only the
surface observation. The deeper claim is structural:

### The graph IS the program

Every Inka compilation produces a substrate — `SubstGraph + Env` —
that contains every type, every effect row, every ownership marker,
every reason, every binding the program ever established. Every
*output* the compiler produces is a handler projection of that
substrate.

```
                          SubstGraph + Env
                   (the universal representation)
                                 │
         ┌───────┬───────┬───────┼───────┬───────┬───────┐
         │       │       │       │       │       │       │
       emit   format    doc    query   teach   hover  audit
      handler handler handler handler handler handler handler
         │       │       │       │       │       │       │
       WAT   source   markdown answer  hint   JSON-RPC capability
                                                          set
```

The WASM bytes are a projection. The formatted source code is a
projection. The hover info in an IDE is a projection. The error
messages are a projection. The Why-chain that explains why a value has
the type it has is a projection. The capability audit that proves a
program cannot touch the filesystem is a projection. All of them read
the *same* graph, through the *same* effect discipline, and return
different shapes of the same underlying knowledge.

This is not architecture. It is consequence. Once you decide that
inference produces knowledge, and that every consumer of knowledge
reads it the same way, every feature the industry has been shipping as
a separate tool becomes a handler on a shared substrate.

### The commitment

Throughout this document, one rule holds:

> **If it needs to exist, it's a handler.**

If a capability cannot be expressed as a handler on the graph, the
graph is incomplete — extend the graph. Never route around it. This is
load-bearing. It is why garbage collection, package management, test
frameworks, dependency injection, documentation generators, language
servers, REPLs, debuggers, and verifiers all dissolve into one thing.
They were never separate. They were missing primitives in the host
language, hiding as libraries.

Inka's one primitive is the graph + the handler. The rest of this
document shows what falls out.

---

## 2. The Five Verbs

Computation is a directed graph. Every program — a DSP signal chain, a
machine-learning model, a compiler pipeline, a control loop, a data
pipeline, a business workflow — is a shape on a page: nodes, edges,
branches, joins, cycles. The industry has been drawing these shapes on
separate whiteboards for fifty years, in separate notations (block
diagrams, PyTorch graphs, Unix pipes, Cargo dependency trees) that
cannot interoperate because their host languages cannot express the
shared algebra.

Inka has five operators. Together they draw every computation graph
the industry has ever drawn.

| Verb | Topology | Shape | Reading |
|---|---|---|---|
| `\|>` | converge | funnel (∧→) | "flow forward, merge at narrowing" |
| `<\|` | diverge | fanout (∨→) | "flow forward, split at widening" |
| `><` | parallel compose | cross (✕) | "two pipelines interact side-by-side" |
| `~>` | tee / handler-attach | side-channel (⌐) | "observe; install handler" |
| `<~` | feedback | loop-back (⟲) | "close a cycle" |

### Topological completeness

Every directed graph you can draw on a whiteboard decomposes into one
expression in these five operators. The proof is structural:

- The first four (`|>`, `<|`, `><`, `~>`) cover all directed *acyclic*
  graphs. Any DAG is a composition of series (`|>`), parallel (`><`),
  fanout (`<|`), and annotation (`~>`).
- `<~` adds cycle closure, extending coverage to all directed graphs
  with feedback.

Five verbs, one precedence table, one layout rule — enough to
notate any computation the industry has ever needed to draw.

### `|>` — Converge

Data flows left-to-right. Each stage receives the previous stage's
output.

```
source |> lex |> parse |> infer |> emit
// equivalent: emit(infer(parse(lex(source))))

audio |> highpass(80.0) |> compress(4.0) |> limit(-0.1)
// DSP signal chain — same operator

input |> mfcc(40) |> conv1d(32) |> relu |> dense(12) |> softmax
// ML computation graph — same operator
```

`|>` is a **transparent wire**. It does not unwrap tuples. It does not
repack values. It passes whatever is on the left to whatever is on the
right, by structural unification of types.

**Type rule.** `row(x |> f |> g) = row(x) + row(f) + row(g)`. If
either side performs effect `E`, the composition performs `E`.

### `<|` — Diverge

One input, multiple parallel branches, each receives the same input
independently. The branches' outputs combine into a tuple, which the
next `|>` then carries forward as a single tuple value. `|>` itself
does not unwrap or repack; it is the *value on the wire* that happens
to be a tuple. When that tuple reaches a function whose parameter
list has matching arity, structural unification pairs tuple slots
with parameters — the same unification that pairs `TInt` with `TInt`
(see *Parameters ARE tuples*, below).

```
signal <| (analyze_spectrum, measure_rms, detect_peaks)
// = (analyze_spectrum(signal), measure_rms(signal), detect_peaks(signal))

audio
    |> preprocess
    <| (fft, envelope, pitch_detect)
    |> merge_features
    |> classify
```

**Ownership.** `<|` implicitly *borrows* the input for all branches.
`own` values cannot flow through `<|` — it would consume the same
value multiple times, an affine violation (E004). `ref` values borrow
per branch. Pure values fan out by copy.

**Type rule.** If `input: T` and branches are `(T -> A, T -> B, T -> C)`,
the result is `(A, B, C)`. Row: union of all branch rows plus the
upstream row.

### `><` — Parallel compose

Two or more pipelines run as peers, outputs tupled. Independent
inputs (unlike `<|`).

```
(audio_left |> compress |> limit)
    ><
(audio_right |> compress |> limit)
|> stereo_mix

(read_file("config") |> parse_json)
    ><
(read_file("schema") |> parse_schema)
|> validate
```

Note the canonical layout: `><` sits at the indented center between
the two branches; the consuming `|> stereo_mix` (or `|> validate`)
returns to the **left edge** because it continues the top-level pipe
chain. Sequential operators always sit at the left edge; convergent
operators sit at the indented center. The shape draws what the
computation does.

**Ownership.** `><` has fully independent tracks. Each branch can
consume its own `own` input. No crossover, no affine restriction.

The `<|` / `><` distinction is **structurally ownership**: `<|`
shares input, `><` splits it. Look at a program; if data flows from
one source into many, it's `<|`; if independent data flows converge,
it's `><`. The compiler catches misuse because the ownership effect
sees the topology.

### `~>` — Tee / handler-attach

Data flows forward and a handler observes. `~>` is handler
installation made visible on the pipeline.

**Semantics.** `expr ~> h` ≡ `handle expr with h`. The handler's arms
intercept the effects `expr` performs, potentially transforming or
absorbing them; the result of `expr` (post-handling) flows out.

Two forms, layout-disambiguated:

```
// Form A — block-scoped: handler wraps the whole prior chain
source
    |> lex |> parse |> infer
    ~> env_handler          // wraps (lex |> parse |> infer)
    ~> graph_handler        // wraps env_handler(...)
    ~> diagnostics_handler  // outermost — the sandbox boundary

// Form B — inline: handler scoped to the immediately-preceding stage
raw_string
    |> parse_json ~> catch_parse_error(default = "{}")
    |> validate_schema ~> log_warnings
    |> save_to_db
```

A `Newline` before `~>` means Form A — the handler wraps the whole
prior pipe chain. No newline means Form B — the handler wraps only
the immediately preceding stage. This is the *one* place in Inka where
whitespace is semantically load-bearing, and it is load-bearing because
the visual layout *is* the computation graph.

**Type rule.** `row(expr ~> h) = row(expr) - handled(h) + row(h)`.
The handler subtracts what it absorbs; anything its arms themselves
perform is added. This falls out of the effect algebra (Chapter 3).

**The `~>` chain IS a capability stack.** Ordering is a trust
hierarchy. Reading top-to-bottom (i.e., inner-to-outer):

- Outermost = least trusted. `diagnostics_handler` is the sandbox
  boundary — it catches everything and has no outward escape.
- Innermost = most capability. The compilation body has access to
  every handler in the chain.
- Handler position in the `~>` chain *is* the capability grant. Move
  a handler outside `graph_handler` and its `perform graph_bind` is a
  type error — not policy, but **structurally proven by effect-row
  subsumption at handler install time**.

This is a security model. If you want a plugin that reads the graph
but cannot write it, install it inside `graph_handler` with only
`SubstGraphRead` in its declared effect row. The sandbox is not
enforced by runtime policy, not by audit, not by inspection. It is
airtight by type.

### `<~` — Feedback

A stage's output, delayed or filtered, feeds back into an earlier
stage.

```
// IIR filter — DSP feedback
input |> add(a) <~ delay(1, init=0) |> output

// RNN — hidden state feeds back
input |> rnn_cell <~ delay(1, init=zero_state) |> output

// PID controller — error feeds back through integrator
sensor_diff |> proportional <~ integrate <~ delay(1) |> actuator
```

`<~` places a **feedback edge** from the right side's output back
into the left side's input. The RHS is a *feedback specifier*
(`state(init=v)`, `delay(n, init=v)`, `filter(f, init=s)`) describing
the back-edge's behavior.

`<~` is the one verb no other mainstream language has. Every other
language hides feedback inside mutable assignment, recursion, or a
library's state machine. In Inka, the back-edge is on the page,
visible to the parser, checkable by the compiler, optimizable by the
backend.

**Desugaring.** `<~` is sugar for a stateful handler capturing
output and re-injecting it on the next iteration:

```
// surface:   y = x |> f <~ delay(1, init=0)
// desugars:  handler feedback with state = 0 {
//              pull()  => resume(state),
//              push(v) => resume(()) with state = v
//            }
//            handle iterate(x, |cx| {
//              let fb  = perform pull()
//              let out = f(cx, fb)
//              perform push(out)
//              out
//            }) with feedback
```

**Iterative context required.** `<~` requires an ambient `Iterate`,
`Clock`, `Tick`, or `Sample` handler. Absence is a compile error
(`E_FeedbackNoContext`), not a hang. The compiler sees the cycle and
demands the clock that makes it well-defined.

**Handler-dependent timing.** `<~ delay(1)` means one *unit* of
delay; the unit is the handler's choice. Under `Sample(44100)` it is
one sample (an IIR filter); under `Tick` it is one logical step (an
iterative algorithm); under `Clock(wall_ms=10)` it is 10 ms (a
control loop). **One operator. Handler decides interpretation.**

An IIR filter and an RNN's hidden state are the same topology. The
compiler proves it by lowering both to the same state machine.

### The closed algebra

| Op | Shape | Operates on | Produces | When |
|----|-------|-------------|----------|------|
| `\|>` | ∧→ converge | value, function | value | Data flows NOW |
| `<\|` | ∨→ diverge | value, functions | values | Data fans NOW |
| `><` | ✕ parallel | pipelines | tupled outputs | Independent now |
| `~>` | ⌐ tee | value, handler | observed value | Handler sees effects |
| `<~` | ⟲ feedback | value, feedback-spec | iterated value | Cycle closes |

Any computation graph — sequential, parallel, diamond, hourglass,
feedback loop — is expressible as a combination of these five.

### Canonical formatting — the shape IS the graph

The formatter emits pipe chains in a canonical layout where **the
position of the operator is the topology.**

- **Sequential operators (`|>`, `~>`) sit at the LEFT edge** because
  flow goes *down* the page. The eye scans down the left margin and
  reads the pipeline.
- **Convergent and feedback operators (`><`, `<~`) sit at the
  INDENTED CENTER** because they draw a pinch or loop shape. The eye
  sees convergence or cyclic return.
- **`<|` sits at the left edge before its tuple of branches** because
  fanout begins at the wire and radiates.

```
source
    |> frontend
    |> infer_program
    ~> env_handler
    ~> graph_handler

(read_config(path) |> parse_toml)
    ><
(read_schema(path) |> parse_json)
|> validate

input |> transform
    <~ delay(1)

input <| (low_pass, band_pass, high_pass) |> mix
```

`git diff` of a pipe chain shows which edges changed in the
computation graph. The formatter is a handler — it reads the graph
and emits source text in canonical shape. **The shape of the code on
the page IS the shape of the computation graph. Not by metaphor. The
parser reads the shape.**

### Parameters ARE tuples

A function `fn f(a, b, c)` has type `(A, B, C) -> D`. The parameter
list *is* a tuple. `|>` is a wire; it passes whatever is on the left
to whatever is on the right.

When `<|` or `><` produces a tuple `(A, B, C)` and the next `|>`
delivers it to `merge: fn(A, B, C) -> D`, the inference engine
structurally unifies the tuple type against the function's parameter
list. This is not "auto-splatting." It is the same unification that
pairs `TInt` with `TInt`.

```
input <| (low_pass, band_pass, high_pass) |> mix_3
// mix_3: fn(Low, Mid, High) -> Out. Tuple arity matches parameter arity.

input <| (low_pass, band_pass, high_pass) |> fn(bands) => log(bands)
// fn has ONE parameter of tuple type. Unification pairs (L,M,H) with ((L,M,H))
```

The developer controls arity through their function signature. No
language rule. No special case. **One mechanism.**

This is settled. It will never be re-opened. It is in INSIGHTS.md, it
is in CLAUDE.md's seven anchors, it is in spec 10. The answer was
always *unification*.

---

## 3. The Boolean Effect Algebra

Row polymorphism — the ability to say "this function performs some
effects, plus these specific ones" — is the baseline. Koka has it.
Effekt has it. A handful of research languages have it. Inka's
algebra goes considerably further.

Inka has a **complete Boolean algebra over effect capabilities:**

| Operator | Meaning |
|----------|---------|
| `E + F` | Union — effects from E or F |
| `E - F` | Subtraction — E except F |
| `E & F` | Intersection — only effects in both |
| `!E` | Negation — any effect *except* E |
| `Pure` | Empty set (identity; sugar for `!Everything`) |

No other language has this. The load-bearing novelty is **negation**:
`!E` proves the *absence* of a capability. Koka can say "this
function performs `IO + State`"; it cannot prove "this function does
NOT perform `Alloc`". Haskell can distinguish `IO` from pure; it
cannot track allocation as an effect at all. Rust can prove no data
races; it cannot prove no allocation, no I/O, no network access. Inka
can.

### Normal form

Every EffRow normalizes to one of three canonical shapes:

1. `EfPure` — the empty set, `{}`.
2. `EfClosed(names)` — a finite, sorted, deduplicated set of effect
   names, e.g. `{IO, Alloc}`. No row variable.
3. `EfOpen(names, handle)` — known names plus a row-variable handle,
   e.g. `{IO, ..r}`.

Intermediate forms `EfNeg(E)`, `EfSub(A, B)`, `EfInter(A, B)` exist
during construction and reduce before unification:

- `EfNeg` folds via De Morgan.
- `EfSub(A, B) ≡ A & !B` — always expanded, never kept as a residual.
- `EfInter(Closed(A), Closed(B)) = Closed(A ∩ B)`.

Normalization is decidable and has known complexity (Flix Boolean
unification, OOPSLA 2024, reports 7% compile-time overhead for full
Boolean row algebra on production codebases).

### Subsumption — the proof engine

A handler signature `effect E { op(...) -> T with F }` admits a body
of inferred row `B` iff `B ⊆ F`. Decidable on the normal form:

- `B ⊆ Pure` iff `B = Pure`.
- `B ⊆ Closed(F)` iff `names(B) ⊆ F` and `B` has no row variable.
- `B ⊆ Open(F, v)` iff `names(B) ⊆ F ∪ names_of(chase(v))`.

**`row_subsumes` IS the proof engine.** Every capability check in
Inka is a subsumption query. Every compilation gate is a subsumption
query. The four headline gates below are not separate machinery; they
are *four uses of the same mechanism*.

### The four compilation gates — derived, not added

Each gate is a subsumption test against a fixed row:

1. **`Pure` → memoize / parallelize / compile-time-evaluate.**
   `effs ⊆ Pure`. A pure function's output depends only on inputs; same
   inputs → same outputs; therefore cacheable, parallelizable, and
   evaluable at compile time.

2. **`!IO` → safe for compile-time evaluation.** `effs ⊆ !Closed(["IO"])`.
   Weaker than `Pure` — allows state, allocation, exceptions, but no
   I/O. Values are reproducible at build time.

3. **`!Alloc` → real-time / GPU / kernel-safe.**
   `effs ⊆ !Closed(["Alloc"])`. Propagates transitively through the
   entire call graph. If any callee allocates, the constraint fails at
   compile time. This is the real-time-audio holy grail that the
   industry has spent decades trying to achieve with conventions, code
   review, and runtime monitoring. In Inka, it is a type-level proof.

4. **`!Network` → sandbox.** `effs ⊆ !Closed(["Network"])`. The program
   cannot reach the network — proven, not monitored.

No special bits. No per-gate tracking. No compiler-intrinsic knowledge
of which effect names mean what. **The gates are subsumption queries
applied at compilation.** The compiler treats `Alloc`, `IO`, `Network`
the same as it treats any user-defined effect. If a library declares
`effect Logging`, the programmer can write `fn silent() with !Logging
-> T` and the compiler proves it.

### Handler absorption

When a handler installs, it *subtracts* effects from the body:

```
handle { body with E } { arms for F }
```

The resulting effect row is `normalize((E - F) + arms_row)`.

- Body's inferred row is `E`.
- Handler covers effects in `F`.
- Handler arms themselves perform an extra row (e.g., an arm that
  `perform report(...)` adds `Diagnostic` to the outer row).

This algebra falls out of the Boolean mechanism. There is no special
"handler absorption" rule. There is only row subtraction with row
addition.

### `!Alloc`, propagated

This is worth drawing out because it is the single most powerful
consequence of the algebra.

```
fn dsp_process(x: Float) -> Float with !Alloc =
    x |> gain(0.8) |> soft_clip
```

The compiler walks the transitive call graph of `dsp_process`. If
*any* function it calls — through any depth, through any handler
stack, through any library — performs `Alloc`, the `with !Alloc`
constraint fails at compile time. One annotation, total proof.

Languages without effect tracking cannot memoize because they cannot
prove purity. Languages with implicit allocation cannot prove zero
allocation. **Inka proves both, because `Alloc` is an effect and `!`
negates effects.**

This is the effect algebra doing what it does: turning capability
negation into a compile-time proof. Every specialized mechanism that
other languages ship — Rust's `#[no_std]`, C++'s `noexcept`,
Haskell's `ST`, C#'s `readonly` — becomes an instance of one pattern.

### Modal encoding (for the theorists)

Research by Tang and Lindley (POPL 2025) shows that row-polymorphic
effects and capability-based effects are the same thing under a modal
semantics: `⟨E₁ | E₂⟩(E) = E₂ + (E − E₁)`. Inka presents rows at the
surface (every function has an effect row); capabilities fall out as
a view on rows. The algebra is decidable, sound, and documented.

The mechanism is not novel at the theory level. What is novel is **no
production language has shipped this algebra end-to-end**. Inka does.

---

## 4. Inference Is the Light

*This is the first truth. Everything else in this document is a
consequence.*

The type inference engine produces knowledge: what every binding is,
what every expression returns, what effects every function performs,
what ownership each parameter carries, what refinement each value
satisfies. **That knowledge IS the product. Not compilation. Not
error checking. The KNOWLEDGE ITSELF.**

Every consumer of that knowledge is a handler:

- **Codegen** — the handler that turns type knowledge into machine code
- **LSP** — the handler that turns type knowledge into hover info
- **Teaching** — the handler that turns type knowledge into the gradient
- **Errors** — the handler that turns type knowledge into diagnostics
- **Documentation** — the handler that extracts typed signatures
- **The programmer** — the handler that turns type knowledge into understanding

One inference. Many handlers. Same mechanism as everything else in
Inka.

### The SubstGraph

The substrate is a flat-array graph:

```
type NodeKind
  = NBound(Ty)         // resolved — chase terminates here
  | NFree(Int)         // unresolved — epoch at allocation time
  | NRowBound(EffRow)
  | NRowFree(Int)
  | NErrorHole(Reason) // terminal error — inference observed a failure

type GNode
  = GNode(NodeKind, Reason)  // every node carries its justification

type SubstGraph
  = SubstGraph(List, Int, Int, List)
//               │    │    │    └─ per-module overlays
//               │    │    └────── next fresh handle
//               │    └─────────── epoch counter
//               └──────────────── flat array: nodes indexed by handle
```

**The handle IS the index.** If you know a handle, you know its node
in one array read. `chase` walks `NBound`/`NRowBound` links until
terminal — in practice amortized O(1), since chains are shallow. No
side tables. No subst-apply sidecar. No cached `Ty` on any AST node.

This is the Salsa 3.0 shape — flat array plus epoch plus persistent
per-module overlay. Astral's `ty` Python type checker demonstrates
the same substrate delivering 4.7ms incremental recompile; Meta's
Pyrefly engineering confirms module granularity is sufficient for
real codebases.

### Live chase, not cache

Every type read in the compiler goes through the same effect:

```
effect SubstGraphRead {
    graph_chase(Int) -> GNode
    graph_epoch() -> Int
    graph_reason_edge(Int, Int) -> Reason
    graph_snapshot() -> SubstGraph
}

effect SubstGraphWrite {
    graph_fresh_ty(Reason) -> Int
    graph_bind(Int, Ty, Reason) -> ()
    graph_fork(String) -> ()
    graph_push_checkpoint() -> Int
    graph_rollback(Int) -> ()
    // ...
}

effect LookupTy { lookup_ty(Int) -> Ty }
```

When lowering asks for the type of an expression, it does **not**
read a cached `Ty` field on the AST node. It performs `lookup_ty(h)`
on the node's handle, which dispatches to a handler that performs
`graph_chase(h)`, which chases to terminal and returns the current
type. **Always live. Always through the graph.**

This is why every type in Inka is always correct: there is no cache
to go stale. The entire class of bug that plagued earlier iterations
— `val_concat` drift, polymorphic-dispatch fallback, stale subst —
is structurally unreachable because the graph *is* the subst, not a
mirror of it.

### Writer isolation by effect row

```
inference declares  with SubstGraphRead + SubstGraphWrite + ...
lowering declares   with SubstGraphRead                    + ...
query declares      with SubstGraphRead                    + ...
```

A `perform graph_bind` inside the lowering handler stack fails
type-check at handler install — because `SubstGraphWrite` is not in
the available effect row. **"One writer" is not policy. It is
structural.** The Boolean effect algebra gates the invariant at
compile time. Runtime enforcement is unnecessary because runtime
violation is unrepresentable.

Env is the peer of the graph: `EnvRead`, `EnvWrite`. Scoped bindings
push and pop through `env_scope_enter` / `env_scope_exit`. Neither
the graph nor the env is ever passed as an argument; both are
effect-mediated, peer substrates of ambient post-inference knowledge.

### One walk

`infer.jxj` is a single recursive walk over the AST:

```
fn infer_expr(node)  -> ()     // walks node, binds node.handle
fn infer_stmt(stmt)  -> ()     // walks stmt, binds contained nodes
fn generalize(fn_node) -> Scheme   // quantifies at FnStmt
```

HM with Damas-Milner let-generalization. Effects inferred alongside
types (one row per `TFun`). Ownership inferred in the same walk
(every `VarRef` of an `own` parameter performs `Consume`). No
separate "check" vs "infer" phases. No two-pass model. No prescan
carrying a snapshot that goes stale.

Unification writes directly to the graph:

```
fn unify(h_a, h_b, reason) -> () = {
    let na = perform graph_chase(h_a)
    let nb = perform graph_chase(h_b)
    match (na.kind, nb.kind) {
        (NFree(_), _)            => perform graph_bind(h_a, reify(h_b), reason),
        (_, NFree(_))            => perform graph_bind(h_b, reify(h_a), reason),
        (NBound(ta), NBound(tb)) => unify_shapes(ta, tb, reason),
        _                        => unify_row_kind(na, nb, reason)
    }
}
```

No subst argument. No returned pair. The graph IS the subst. The graph
is external.

### Reification — the third truth

*Abstract algebra must materialize into physical pointers.*

`infer.jxj` does not just type-check. Its ultimate duty is to
**physically synthesize Evidence Dictionaries** — vtables — for
polymorphic effects. At each function definition whose effect row is
polymorphic (some effect is implemented by the caller), the inference
pass rewrites the function's AST to accept an opaque Evidence Vector
(`*const ()`). At each `handle` block, it synthesizes the concrete
dictionary that is passed at runtime.

The result: polymorphic effect calls become WASM `call_indirect`
through a runtime-known vtable. **Monomorphization-speed without
code bloat.** One compiled function body per polymorphic function,
one pointer per effect row at the call site.

This is Koka's generalized evidence passing (JFP 2022), applied
systematically. The graph knows when a call site's handler stack is
ground (>95% of call sites in practice, for real Inka programs); for
those, the compiler emits a direct `call $h_op`. The remaining
polymorphic minority goes through `call_indirect`. **The `val_concat`
class of runtime type-test dispatch is unreachable in emitted code**
— because the graph either proves monomorphism or emits explicit
evidence, with no fallback.

### Productive inference under error — the Hazel pattern

Inference never halts on a type error. A mismatch:

1. Emits `perform report(..., code="E002", kind="TypeMismatch", ...)`.
2. Binds the handle to `NErrorHole(UnifyFailed(a, b))` — a terminal
   error node.
3. Continues the walk.

Lowering tolerates `NErrorHole` by emitting a WASM `unreachable` trap.
The user sees a type error and a runtime trap if they exercise that
path — but all *other* well-typed code still compiles. Query, LSP
hover, and Mentl's teaching surface all keep working on the partially
typed program.

The compiler is not an adversary that rejects on first error. It is a
collaborator that types as much as it can, surfaces every mismatch
with a marked hole, and lets the programmer make progress.

Ten mismatches produce ten error holes, not one-and-halt. The IDE
keeps delivering hover info. Mentl keeps suggesting annotations.
Inference stays productive.

### Occurs check, no silent failure

Before `graph_bind(h, ty, r)`, the unifier walks `ty` for free
handles containing `h`. If any, emit `E_OccursCheck` and refuse the
bind. No silent binding. No infinite loop. No cycle at all, except
through the explicit `<~` feedback operator (Chapter 2).

### Env + Scheme

```
type Scheme = Forall(List, Ty)  // quantified handles, body type
type Env    = Env(List)         // [(name, Scheme, Reason)]
```

`env_lookup(name) -> Option((Scheme, Reason))`. `env_extend(name,
scheme, reason)`. `env_scope_enter / env_scope_exit` for block-scoped
bindings. Same discipline as the graph: effect-mediated, one writer,
ambient.

A Reason accompanies every binding. When the programmer asks "why is
x an Int?", the reason chain answers, traced through every unification
that led to the current type. The Why Engine (Chapter 8) walks this
chain.

### What this replaces

Every earlier iteration of the compiler threaded a `(subst, env, ...)`
tuple through every recursive call. Every pass had its own partial
mirror of the type state, and every mirror drifted. The bug classes
that resulted — `val_concat` polymorphic drift, cross-module TVar
collisions, stale env snapshots — cost more engineer-hours than every
other bug category combined.

**They do not exist in this architecture.** There is one graph. There
is one env. Every reader reads through the same effect. There is
nothing to drift.

---

## 5. The Annotation Gradient

Inka does not have levels. It does not have modes. It does not have
`strict_mode: true`. It has a **gradient** — a continuous conversation
between programmer and compiler where every annotation unlocks a
specific capability.

### No annotations — it works

```
fn double(x) = x * 2
```

The compiler infers `double: (Int) -> Int with Pure`. You wrote
nothing extra. The type, the effect row, the purity — all inferred.
The program compiles. The program runs.

### Add `with Pure` — unlock optimizations

```
fn double(x) = x * 2 with Pure
```

Same function. Same source otherwise. Now the compiler can memoize
calls, parallelize batches, evaluate the function at compile time.
You told it one thing; it gave you three capabilities.

### Add a refinement — unlock proofs

```
fn double(x: Positive) -> Positive = x * 2 with Pure
```

Now the compiler proves the output is positive. The SMT solver
(Verify effect, Chapter 9) discharges the obligation at compile time
and erases it at runtime. Buffer overflows on `double`'s output are
impossible.

### Add ownership — unlock real-time

```
fn double(x: own Int) -> own Int with Pure, !Alloc = x * 2
```

Now the compiler proves this function never allocates. The output is
safe for audio callbacks, embedded systems, GPU kernels, interrupt
handlers.

### Each annotation is a conversation

The compiler can show you the next step:

```
fn double: (Int) -> Int with Pure
    → adding `with Pure` unlocks: memoization, parallelization
    → adding `x: Positive` unlocks: output proof, zero-cost bounds
    → adding `with !Alloc` unlocks: real-time safety, GPU eligibility
```

This is not nagging. It is illumination. Mentl's `teach_gradient`
tentacle surfaces the single highest-leverage next annotation — not a
wall of warnings, one concrete suggestion that unlocks something
specific. Over many sessions, code drifts from "loose" toward
"formally verified" one step at a time. **There is no cliff, no
separate advanced mode, no "production switch."** The gradient is
continuous.

### The gradient is circular

This is the deepest claim of this chapter.

At the **bottom** of the gradient — zero annotations — the compiler
infers everything. The programmer writes almost nothing. The machine
does all the work.

In the **middle** — annotations accumulate. `with Pure`. `with !Alloc`.
`type Sample = Float where -1.0 <= self <= 1.0`. The programmer
provides more information; the compiler proves more invariants. They
collaborate.

At the **top** — the annotations become the program. The types are
so precise, the effects so constrained, the refinements so tight, that
there is only one implementation satisfying them. **The code writes
itself.** The programmer writes almost nothing. The machine does all
the work.

The bottom and the top are the same experience. Total inference and
total specification converge. At the bottom, the compiler guesses; at
the top, it proves. But in both cases — **you say what you mean, and
the language handles the rest.**

This is what type-directed synthesis actually is. Not a feature bolted
on — the inevitable destination of every mechanism the language
already has. Refinement types constrain the space. Effect algebra
narrows it further. Ownership eliminates more candidates. Eventually
the constraint space has exactly one inhabitant. The program is the
proof is the specification is the program.

**The ultimate form: the language becomes invisible.** Not gone —
transparent. The programmer looks through the medium and sees their
intent, realized.

### Why this breaks industry expectations

Every language that has tried to offer "progressive strictness" did
so *bimodally*: Python's `mypy --strict`, TypeScript's `"strict":
true`, Racket's teaching languages. Discrete dialects. Discrete
ladders. Cliff between levels.

Inka is continuous. The same syntax is valid at every point. An
annotation is not a level switch; it is a capability grant. The
compiler's power scales continuously with how much you tell it.
**Python-style prototyping. Rust-level safety. One syntax. No modes.**

---

## 6. Ownership Is an Effect

Rust treats ownership as a type system feature. Inka treats it as an
**effect**.

Every use of an `own` parameter performs `Consume`. A handler
(`affine_ledger`) enforces affine linearity. Read-only proof is
`!Consume`. Zero allocation is `!Alloc`. All derived from the same
Boolean effect algebra (Chapter 3). **No separate ownership
analysis.** No separate compiler pass. One walk; the effect system
handles it.

### The Consume effect

```
effect Consume {
    consume(name: String, span: Span) -> ()    @resume=OneShot
}
```

Every `own`-annotated parameter's use performs
`perform consume(name, node.span)`. Inference records the event; the
handler enforces linearity.

### Ownership markers

```
type Ownership
    = Inferred    // compiler decides (default)
    | Own         // affine: consumed at use
    | Ref         // borrowed: cannot escape

type TParam = TParam(String, Ty, Ownership)
```

Function parameters carry ownership markers. `TFun` equality
includes ownership: `fn(Own(Int)) -> Int` is *not* equal to
`fn(Ref(Int)) -> Int`. Subsumption:

- `Own ⊆ Inferred` (calling with an `Inferred` slot accepts an `Own`).
- `Ref ⊆ Inferred` (same for `Ref`).
- `Own` ≠ `Ref` (incompatible disciplines).

### The affine_ledger handler

```
handler affine_ledger with !Consume {
    consume(name, span) => {
        if list_contains(self.used, name) {
            let first_span = find_first_use(self.used_sites, name)
            perform report(self.source, "E004", "OwnershipError",
                "'" ++ name ++ "' consumed twice (first at "
                    ++ show_span(first_span) ++ ")",
                span, "MachineApplicable")
            resume(())
        } else {
            resume((), {
                used: push(self.used, name),
                used_sites: push(self.used_sites, (name, span)),
                source: self.source
            })
        }
    }
}
```

`with !Consume` on the handler means the handler's own arms cannot
recurse through `consume` — a structural gate from the Boolean algebra
(Chapter 3). No infinite loops. No policy.

Installed at every `FnStmt` entry. At `FnStmt` exit, any `own`
parameter not in `self.used` emits `T001 OwnNeverConsumed` — a
teaching hint surfaced by Mentl, not an error.

### `ref` as structural escape check

`ref` parameters cannot appear in return position:

```
fn head_ref(xs: ref List<String>) -> ref String = xs[0]  // ERROR E004
// the returned ref outlives the borrow
```

A structural walk checks every return position for ref-marked
parameters. Violations emit `E004` with `applicability=MaybeIncorrect`
(the fix might be to change `ref` to `own`, or to refactor; the
compiler cannot decide for you).

### `!Alloc` = row subtraction

`!Alloc` is not a separate analysis. It is a row claim: "this
function's body has effects E where `Alloc ∉ names_of(E)`." Row
subtraction from the Boolean algebra (Chapter 3) discharges it:

1. Inference walks the body, accumulating its row.
2. Normalized body row is tested against `!Alloc` via subsumption.
3. Any `Alloc` in the body without a handler absorbing it emits
   `E004` with `applicability=MachineApplicable` (the fix is
   deterministic: add a handler, or promote to caller, or drop the
   claim).

The same mechanism proves `!IO`, `!Network`, `!Random`, `!Consume`,
and any user-defined `!MyEffect`. There is no special support for
ownership. **Ownership fell out.**

### `<|` vs `><` — ownership is the structural difference

```
// <| (Diverge)
//             ┌──► branch_a ──┐
// [input] ────┤               ├─► (out_a, out_b)
//             └──► branch_b ──┘
// Input is SHARED (borrowed).
// Cannot consume own values. (E004)

// >< (Parallel Compose)
// [input_a] ──► process_a ──┐
//                           ├─► (out_a, out_b)
// [input_b] ──► process_b ──┘
// Inputs are INDEPENDENT.
// Can safely consume own values.
```

The distinction between `<|` and `><` is not a style choice. It is
ownership. `<|` implicitly borrows the input; `own` through `<|` is an
affine violation. `><` has fully independent tracks; `own` through
`><` is fine.

Inka tells the compiler which topology you mean, and the compiler
proves ownership without asking you for `&` or `&mut`.

### Multi-shot × arena — the D.1 question

A multi-shot continuation captured inside a scoped-arena handler
raises a semantic question: what happens when the continuation is
resumed after the arena has been reset?

Three policies:

1. **Replay safe.** The continuation is re-derived by replaying the
   effect trace. Resume re-executes from the perform site.
2. **Fork deny.** Forking a continuation that captured arena memory is
   an error at capture time (`T002 ContinuationEscapesArena`).
3. **Fork copy.** Capture deep-copies arena-owned data into the
   caller's arena. Allocation cost; no semantic surprise.

The type of a multi-shot continuation captured in a `temp_arena`
handler is `TCont(ret, MultiShot)` (Chapter 4). A refinement tag
`@via_arena=ArenaId` makes the capture visible to the Fork
deny/copy logic.

**`!Alloc` computations cannot be forked — only replayed.** Forking
allocates the continuation struct; `!Alloc` forbids allocation; the
compiler enforces the combination. This is a genuine Inka
contribution — no prior language integrates multi-shot continuations
with scoped arenas cleanly (Affect POPL 2025 provides the type
machinery; Inka provides the semantics).

### What other languages have and Inka doesn't need

- Lifetime annotations (`&'a`, `'static`). The graph knows. Inference
  fills them. You never write them.
- `Send` / `Sync` traits. Thread-safety is an effect row question:
  handlers installed per-thread; cross-thread transfer is a row
  constraint; the compiler proves freedom from data races without
  user-visible bounds.
- Fractional permissions (Chalice, VerCors). Vale's region-freeze
  via `!Mutate` delivers "N parallel readers, no writers" through the
  existing effect algebra. No numeric accounting.

Ownership in Inka is not a separate discipline to learn. **If you
understand effects, you already understand ownership.**

---

## 7. Memory Is Physical

*Memory is not a hidden runtime system. It is physical, and it is
governed by effect algebras.*

Every allocation in Inka performs the `Alloc` effect. Every memory
access — `load_i32`, `store_i32`, `load_i8`, `mem_copy` — performs
the `Memory` effect. **There is no garbage collector.** There is no
hidden free list. There is no finalizer thread. There is a handler,
and the handler decides.

```
effect Alloc  { alloc(size: Int) -> Int }

effect Memory {
    load_i32(addr: Int) -> Int
    store_i32(addr: Int, val: Int) -> ()
    load_i8(addr: Int) -> Int
    store_i8(addr: Int, val: Int) -> ()
    mem_copy(dst: Int, src: Int, size: Int) -> ()
    byte_at(s: Int, i: Int) -> Int
    byte_len(s: Int) -> Int
}
```

### Four memory models, one mechanism

| Context | Strategy | Handler |
|---|---|---|
| Compiler (batch) | Bump — allocate forward, never free, exit frees all | `bump_allocator` |
| Server (request) | Scoped arena — O(1) region free per request | `temp_arena(4MB)` |
| Game (frame) | `own` + deterministic drop | `own_tracker` |
| Embedded / DSP | `!Alloc` — zero allocation, proven by types | (type-level) |
| Diagnostics | Sloppy code, isolated arena | `diagnostic_arena` |

Different programs install different handlers. **No runtime GC. No
framework. Handler swap.**

### The bump allocator — a handler, not a builtin

```
handler bump_allocator with ptr = 0 {
    alloc(size) => {
        let aligned = align(ptr, 8)
        resume(aligned) with ptr = aligned + size
    }
}
```

The compiler's own memory model. Monotonic. Never frees. Exits free
everything in one traversal. Perfect for batch compilation where
allocations are permanent within a phase.

### Scoped arenas — GC is a handler

```
let similar = handle {
    find_similar_name(e, name)   // allocates 50MB of dead string fragments
} with temp_arena(size = 64_000_000)
```

`temp_arena` intercepts all `alloc(size)` calls within its block.
When the handler's scope drops, its internal pointer resets to zero.
**50MB died in O(1) time.** No sweep, no scan, no stop-the-world
pause. Deterministic. Instantaneous. Zero fragmentation.

Multiple arenas nest. Bump inside bump. Arena inside arena. Each
scope dies independently.

### Region inference prevents escape — Tofte-Talpin, done quietly

Scoped allocators exist in C++ (std::pmr::monotonic_buffer_resource,
Boost pool allocators) and are notoriously dangerous. If
`find_similar_name` returns a pointer to a string that *lives inside*
the `temp_arena`, the moment the scope drops, that pointer becomes a
dangling reference — classic use-after-free.

**Inka's compiler prevents this.** The ownership graph tracks every
pointer to its allocating handler. If a returned value is traceable
to a handler whose scope exits before the return site's scope exits,
the compiler refuses to compile:

```
error: 'similar' escapes the lifetime of 'temp_arena'
    at: std/compiler/diagnostics.jxj:47
    bound by: scoped allocator closes at line 42
    fix: copy the value into the parent allocator's scope
```

The programmer writes `let owned = copy(similar)` or restructures
the return. Either way, the error surfaces at compile time. The
dangling pointer is unrepresentable.

This is Tofte-Talpin region inference from 1997 research
(`Region-Based Memory Management`), but layered on the effect system
so that region identity IS handler identity. The user never writes
region annotations. The ownership graph is the region analysis.

### `!Alloc` for embedded / real-time

For code that must not allocate under any circumstance (audio
callbacks, interrupt handlers, control loops), declare `with !Alloc`
on the function signature. The compiler proves it at compile time.

```
fn audio_callback(input: own Block<Sample>) -> own Block<Sample>
    with !Alloc, !IO =
    input
        |> highpass(80.0)
        |> compress(4.0, threshold = -12.0)
        |> saturate(1.5)
        |> limit(-0.1)
```

Each stage's effects compose through `|>`. If any stage allocates,
the constraint fails. This function provably does not allocate — not
by convention, not by reviewer policy, **by compile-time proof**. The
entire transitive call graph is audited.

Same function at the top of a DSP pipeline. Same function deployed to
an ARM Cortex-M7 with 64MB of SDRAM and hard deadlines. Same source
code. Only the memory handler differs.

### Thread-local `Alloc` — lock-free concurrency

WASM threads traditionally require a global allocator protected by
an atomic mutex; every allocation bottlenecks threads. In Inka, if
`Alloc` is handled thread-locally by default — each thread installs
its own `bump_allocator` handler — there is no shared allocator
state. Threads scale linearly with zero locking.

The effect system proves it: data that doesn't cross thread
boundaries cannot be accessed by another thread's allocator, because
the types carry the region and the region is handler-scoped.
**Thread-safety is handler topology.** `Send` and `Sync` traits are
unnecessary.

### Diagnostic arenas — zero-cost mentorship

Some code — Levenshtein-distance suggestions, "did you mean?",
error-message formatting — is naturally O(N³) and string-heavy. It
would exhaust a bump allocator in a large compilation. But the code
is *not hot* — it runs once per error.

Wrap it in `diagnostic_arena`:

```
let suggestion = handle { find_similar_name(candidates, typo) }
                  with diagnostic_arena(size = 16_000_000)
```

The sloppy O(N³) Levenshtein code runs inside the arena. All its
temporary strings — thousands of intermediate concatenations — live
in the arena. The arena drops. **Mentorship code doesn't need to be
fast. It needs to be isolated.** Zero cost to the outer
compilation.

### The handler IS the backend

The WASM emitter is not a "code generator." It is a **handler for
the Memory effect**. When the lowered program performs
`load_i32(addr)`, the WASM handler emits `i32.load`. When it performs
`alloc(size)`, the handler emits `call $alloc` (the bump allocator).
When it performs `fd_write(...)`, the handler emits the WASI import.

A native x86 backend is not "a new code generator." It is **a
different handler for the same effects**. `load_i32` → `MOV`.
`alloc` → `mmap`. `fd_write` → `syscall`. Same Inka program.
Different handler. Different binary.

A test backend is **another handler**. `load_i32` → array lookup.
`alloc` → vector push. `fd_write` → in-memory string buffer. Same
program. Different handler. Fully isolated.

**The compiler does not have backends. It has handlers.**

### The memory effect is complete

Three effects replace the entire runtime:

- **Memory** — read and write bytes
- **Alloc** — obtain new memory
- **WASI** — talk to the OS (`fd_write`, `fd_read`, exit codes)

Everything else — `str_concat`, `str_eq`, `int_to_str`, `print_line`,
`split`, `chars`, `range`, `push`, `pop`, list access, record field
lookup — is pure Inka built on these three effects. The
`std/runtime/memory.jxj` file IS the runtime. No hand-written WAT.
No C code. No assembly. **There are no primitives. There are only
effects and handlers.**

---

## 8. Mentl — The Oracle

*The thesis made flesh. Mentl must render all modern agentic coding AI
obsolete. Through the gradient, the Why Engine, and multi-shot
speculative search, Mentl is an oracle that PROVES its suggestions —
not an LLM that guesses. The compiler IS the AI.*

Mentl is not a feature of Inka. Mentl is what the substrate *becomes*
when you project it toward a human. Eight tentacles, each a handler
on the shared inference substrate, each reasoning locally, each
independent — the mascot is an octopus because octopus neurology
*is* the architecture. Distributed cognition over a shared central
nervous system.

### The architecture

```
                ╔═══════════════════════════════════════╗
                ║       SubstGraph + Env + Ty           ║
                ║    (shared inference substrate)       ║
                ╚═══════════════════════════════════════╝
                                    │
    ┌──────────┬──────────┬─────────┼─────────┬──────────┬──────────┐
    │          │          │         │         │          │          │
 compile    check      query      why       teach      hover     suggest
    │          │          │         │         │          │          │
  WAT     Diagnostic  QueryResult  Reason  Annotation   LSP     Candidate
                                          + Capability JSON-RPC  + Verified
```

(The verify tentacle is the eighth — it reads the same substrate via
the `Verify` effect; see Chapter 9.7.)

Each tentacle reads the same graph through `SubstGraphRead`, the same
env through `EnvRead`. None coordinate with each other. Each reasons
locally and surfaces a projection for the human.

### The Teach effect

```
effect Teach {
    teach_here(name: String, span: Span, ty: Ty) -> ()
    teach_gradient(handle: Int) -> Option(Annotation)
    teach_why(handle: Int) -> Reason
    teach_error(code: String, span: Span, reason: Reason) -> Explanation
    teach_unlock(annotation: Annotation) -> Capability
}
```

Five ops. Each is a tentacle entry point.

**Supporting ADTs:**

```
type Annotation
    = APure                        // `with Pure`
    | ANotAlloc                    // `with !Alloc`
    | ANotIO                       // `with !IO`
    | ANotNetwork                  // `with !Network`
    | ARefined(String, Predicate)  // `type X = T where P`
    | AOwn(String)                 // `own` marker on a parameter
    | ARef(String)                 // `ref` marker on a parameter

type Capability
    = CMemoize | CParallelize | CCompileTimeEval
    | CRealTime | CSandbox | CEliminateBoundsCheck
    | CZeroCopy | CDeterministicDrop

type Explanation
    = Explanation(
        code: String,             // E001, V001, W017, ...
        canonical_md: String,     // path into docs/errors/<code>.md
        summary: String,          // one-line human-readable
        fix: Option(Patch),       // MachineApplicable → concrete patch
        reason_chain: Reason
    )

type Patch = Patch(Span, String)  // replace span with String
```

### `teach_why` — the reason chain, recursed

When the programmer hovers over a binding and asks "why is x an
Int?", the Why Engine walks the reason chain. Every unification, every
literal, every parameter binding, every return-type inference left a
`Reason` in the graph. `teach_why` recursively expands them:

```
Why is x: Int?
  → x is parameter 0 of fn double
  → double called with literal 42 (Int)
  → unified parameter type with Int from call site (line 14, col 8)

Why is the call site line 14 col 8 inferred Int?
  → literal 42 is Int by default
  → 42 passed to double, which has parameter type TVar(41)
  → TVar(41) unified with Int at column 8
```

Every inference decision is recorded. Every step is visible. **The
compiler makes its reasoning transparent.** This is an ability no
external tool — no LLM, no linter, no IDE plugin — can match, because
no external tool has direct access to the inference substrate.

### `teach_gradient` — the single next step

At any handle in the graph, `teach_gradient` examines the current
type + effect row and returns the single highest-leverage annotation
the programmer could add:

```
$ inka teach std/compiler/infer.jxj

    infer.jxj:47  let's_generalize is Pure
        → adding `with Pure` would unlock:
             • memoization (same input → same output, guaranteed)
             • parallelization
             • compile-time evaluation
```

Not a wall of warnings. One step. The compiler knows which annotation
would unlock the most capability, because it knows what capability
means in terms of its own mechanism. **Like a tutor who knows exactly
what to teach next.**

Over many sessions, code evolves from loose to formally verified one
annotation at a time. The gradient (Chapter 5) is the path; Mentl is
the guide.

### `teach_error` — the catalog

Every error code in Inka has a canonical explanation at
`docs/errors/<CODE>.md`. `teach_error` loads the file, formats the
Explanation, and returns it with the full reason chain:

```markdown
# E001 — MissingVariable

**Kind:** Error
**Emitted by:** inference
**Applicability:** MaybeIncorrect

## Summary
You referenced a name that is not bound in the current scope.

## Why it matters
The compiler could not find a definition for this name — so it
cannot infer a type or compile a reference.

## Canonical fix
Did you mean one of the following?
    - close_match_1
    - close_match_2

Or define the name before use.

## Example
...
```

Elm / Roc / Dafny demonstrate that structured error catalogs
materially improve newcomer experience. Mentl's `teach_error` loads
the catalog dynamically; the catalog is versioned, reviewed,
translatable, and non-load-bearing on the binary.

### `teach_unlock` — what this annotation would grant

Before the programmer commits to adding an annotation, Mentl answers
what it *would* grant:

```
teach_unlock(APure)        → CMemoize, CParallelize, CCompileTimeEval
teach_unlock(ANotAlloc)    → CRealTime
teach_unlock(ANotNetwork)  → CSandbox
teach_unlock(ARefined(...))→ CEliminateBoundsCheck
```

Reduces annotation-anxiety. The programmer sees cost and benefit
before paying the cost.

### The speculative gradient — Mentl's oracle loop

This is the mechanism that makes Mentl unprecedented.

Consider: the programmer writes a function whose signature asserts
`with Pure`. The body contains an `Alloc`. Inference fails. A linter
would emit a warning and move on. **Mentl does more.**

```
// Mentl's oracle loop, conceptually:
fn synth_candidate(handle, expected) -> Option(Patch) = {
    let checkpoint = perform graph_push_checkpoint()

    // Try each candidate annotation
    for annotation in candidate_annotations(handle, expected) {
        let patch = annotation_to_patch(annotation, handle)
        perform apply_patch_tentative(patch)
        let result = perform graph_try_unify_all()
        match result {
            Ok => {
                let verified = perform verify_obligations()
                if verified {
                    perform graph_rollback(checkpoint)
                    return Some(patch)
                }
            }
            _ => ()
        }
        perform graph_rollback(checkpoint)
    }
    None
}
```

Mentl **speculatively applies** a candidate annotation — wrapping in
`temp_arena`, adding `with Pure`, strengthening a refinement, filling
a hole — **runs the full inference pass**, **runs Verify to check
refinement obligations**, and if everything succeeds, returns the
patch as a *proven* fix. It then rolls back the graph.

The key mechanisms:

- **Trail-based backtracking.** Every `graph_bind` records its prior
  state in a trail. `graph_rollback(checkpoint)` walks the trail
  backwards and restores every node. O(M) where M is mutations
  recorded. Nothing leaks.
- **Multi-shot continuation over candidates.** Each candidate is a
  fork of the same continuation. The handler collects results across
  all forks.
- **Verify is installed in the speculative run.** A candidate that
  type-checks but introduces a refinement violation is caught before
  the patch is offered to the user.

**The verified candidate wins.** The programmer is offered a fix
that is *proven* to compile, not a suggestion that *might* work.

### `Synth` — proposers as handlers

```
effect Synth {
    synth(hole: Int, expected: Ty, context: Context) -> Candidate
}
```

Enumerative search, SMT-guided, LLM-guided, symbolic-execution —
**all are handlers on the same `Synth` effect**:

```
handler synth_enumerative with SubstGraphRead + EnvRead {
    synth(h, expected, ctx) => resume(enumerate_candidates(...))
}

handler synth_smt with SubstGraphRead + Verify {
    synth(h, expected, ctx) => resume(smt_synthesize(...))
}

handler synth_llm with SubstGraphRead + HTTPClient {
    synth(h, expected, ctx) => resume(llm_query(...))
}
```

The programmer picks a handler — or stacks several via `~>` as a
fall-through chain:

```
main()
    ~> synth_enumerative
    ~> synth_smt
    ~> synth_llm
    ~> mentl_default
```

Innermost fires first (the capability-stack reading from Chapter 2).
If `synth_enumerative` returns `NoCandidate`, its arm re-performs
`synth(...)`, bubbling the op to `synth_smt`; if `synth_smt` can't
decide, bubble to `synth_llm`. Fast proposer fires first; expensive
only on fall-through. All proposers return candidates through the
same `Synth` effect; all candidates flow through the same `Verify`
effect. **The compiler verifies; the proposer merely proposes.**

(Running proposers in genuine parallel — all three forking candidates
simultaneously, first verified wins — would be a handler combinator:
`~> race(synth_enumerative, synth_smt, synth_llm)`. `race` is a
library function, not a new operator. Handlers compose as values, so
their combination is a function-level concern.)

### The AI obsolescence argument, mechanized

The subscription coding AI is selling three things:

**(a) Inference of what the AI would have filled in.** An LLM guesses
what the type "probably" should be. Inka's compiler *knows*, because
the type is already constrained by the refinement, the effect row,
and the call context. The hole has a single inhabitant or a narrow
candidate set. `teach_synthesize` fills it with a *verified*
candidate; there is no hallucination surface.

**(b) Verification of what the AI would have checked.** An LLM looks
at code and tries to find bugs. In Inka, code that hallucinates
cannot type-check. No `any`. No escape hatch. Effect rows and
refinements are mandatory. **The hallucination surface is zero.**

**(c) Teaching the pattern the AI would have suggested.** An LLM
offers a pattern it learned from training. Inka's Why Engine offers
the *actual* reasoning chain the compiler used. Mentl's
`teach_gradient` surfaces the annotation the compiler can *prove*
unlocks a capability. **The compiler is the tutor the AI was
pretending to be — deterministic, verified, cached.**

The one sentence: **Inka does not compete with AI; Inka makes AI a
handler on the same `Synth` effect the compiler exposes.** The code
that gets generated must satisfy types, effects, and refinements
written by humans. AI without Inka hallucinates. AI with Inka cannot
— because the compiler verifies before the patch reaches the user.

Subscription gets disintermediated at the architectural level. The AI
is not wrong; the AI is a proposer. **The oracle was always the
compiler.**

### Integration with LSP (Chapter 9.5)

Mentl's tentacles map one-to-one onto LSP methods:

- `textDocument/hover` → `Query(QTypeAt(span))` + `teach_why(handle)`
- `textDocument/publishDiagnostics` → `Diagnostic` + `teach_error`
- `textDocument/completion` → `Synth(hole, ...)` wrapped in
  `Explanation`
- `textDocument/codeAction` → `Explanation.fix` when
  `applicability=MachineApplicable`

LSP is not new machinery. LSP is JSON-RPC transport for tentacles
that already exist. The IDE becomes a thin wrapper over the
compiler's own substrate.

### `inka query` — the forensic substrate

Before LSP, there is `inka query`:

```
$ inka query std/compiler/infer.jxj "type of generalize"
→ generalize : (Node) -> Scheme with SubstGraphRead + EnvRead
  Reason chain:
    - bound at FnStmt at infer.jxj:142
    - return type unified with Forall(qs, body_ty) at line 147
    - body_ty chased from handle 847
    - quantified vars: [142, 148, 153]

$ inka query std/compiler/infer.jxj "why infer_expr performs EnvWrite"
→ infer_expr : (Node) -> () with SubstGraphWrite + EnvWrite + ...
  Reason:
    - extends env at LetStmt (infer.jxj:210)
    - enters scope at BlockExpr (infer.jxj:187)
```

`inka query` is read-only by `SubstGraphRead + EnvRead` subsumption
— a `perform graph_bind` inside the query handler is a type error.
Write attempts cannot corrupt a compilation. The forensic substrate
is airtight by type.

Every LSP method is a `Question` variant over the same Query effect.
There is no separate LSP server substrate.

### Mentl is Phase 1, not polish

Every prior compiler shipped the teaching surface as an afterthought
— a feature added after the core was stable. Inka cannot do this,
because Mentl IS the thesis. The gradient, the Why Engine, the
speculative oracle, `inka audit`, `inka query`, the error catalog —
these are the substrate the programmer experiences. The compilation
path is one projection; Mentl is every other projection.

The structural prerequisites — Teach effect signatures, error-catalog
wiring, graph checkpointing, trail-based backtracking — land from
day one. The Synth handlers (enumerative, SMT, LLM) are independent
shipments; each is a peer handler on the same effect. Any proposer
can be added later without modifying the substrate. **The surface is
closed; the ecosystem is open.**

---

## 9. What Dissolves

*Every framework exists because its host language lacks Inka's
primitives. Given the substrate, each one collapses into a handler.*

Thirteen short demonstrations. Each is an industry category — a
thing the world builds in separate tools, with separate config
languages, separate vendors, separate documentation — that in Inka
is a handler on the shared substrate.

### 9.1 The package manager

There is no package manager. There is no `Cargo.toml`. There is no
`package.json`. There is no lockfile. **There is only the compiler.**

```
fn main() =
    run_app()
        ~> router_axum
        ~> db_postgres
        ~> alloc_arena
```

The `~>` chain in `main()` **is** the manifest. Each `~>` installs a
package. The manifest is type-checked code.

Effect signatures are API contracts. Breaking change = signature
drift. Compatible change = signatures unify. **The type checker IS
the version solver.** If the program compiles, the versions are
compatible. No untyped string matching in a TOML file.

The `Package` effect:

```
effect Package {
    fetch(id: Hash) -> Source
    resolve(row: EffRow) -> Hash
    audit() -> List<Violation>
}
```

Registry handlers are swappable: `~> local_cache_pkg`,
`~> github_pkg`, `~> enterprise_registry`. Federation is a
fall-through chain of `Package` handlers — innermost tries first,
outer handlers pick up what bubbles:

```
fetch_deps()
    ~> local_cache
    ~> github_hub
    ~> community_registry
```

`local_cache` answers from disk if possible; on miss, re-performs
`fetch(hash)` so `github_hub` takes over; on miss there, falls
through to `community_registry`. No lockfile. Hash is identity.
Name is resolution through a registry handler. **The hash IS the
lock.**

**`inka audit` — the capability analyzer.** Walk the `~>` chain,
collect effect rows transitively, print the capability set:

```
$ inka audit main.jxj

Capabilities required:
  - Network (via router_axum)
  - Filesystem (via db_postgres)
  - Alloc (via alloc_arena)

Suggestions:
  - Run sandboxed with `with !Process, !FFI`.
```

Zero infrastructure. No remote service. Runs locally against source.
**Mathematically proven capability analysis before compilation.** No
other package manager can offer this.

### 9.2 The test framework

There is no test framework. There is handler swap.

```
// Production
handle user_app() with real_console, real_clock, real_db

// Test — deterministic inputs, fake clock, in-memory DB
handle user_app() with test_console(["World"]), test_clock(0), test_db(seed_data)
```

`test_console`, `test_clock`, `test_db` are handlers. They intercept
`Console`, `Clock`, `DB` effects and substitute controlled behavior.
**The code under test is identical in both.** No `#[cfg(test)]`, no
mocking library, no dependency injection container, no `testify`,
no `mockito`. **Handler swap. That's the test framework.**

FoundationDB-style simulation testing — deterministic scheduling,
seeded randomness, controlled time — is one handler:

```
handler chaos_sim(seed: Int) intercepts Async + Http + Clock + Random {
    // deterministic scheduling, simulated partitions, seeded RNG
}

#[simulation(iterations = 10_000)]
fn test_consensus() {
    handle run_protocol(nodes = 5) with chaos_sim(seed = test_seed())
}
```

10,000 reproducible distributed-system test runs. One handler.

### 9.3 The DI container

There is no DI container. There is `handle` with a handler.

```
handle app() {
    get_config() => resume(Config::from_env()),
    get_db()     => resume(connect("postgres://...")),
    get_logger() => resume(stdout_logger()),
}
```

Spring. Guice. Dagger. NestJS. Every dependency injection framework
ever written. **A handler.** That's it.

### 9.4 The build system

There is no build system. There is the compiler's own cache.

Every Inka module checks independently against the envs of its
dependencies. After checking, the env serializes to
`<module>.jxji` (Inka Interface) keyed by source content hash.

```
resolve_imports(source)
    → for each import:
        if .jxji exists AND hash matches .jxj:
            load env from .jxji (skip checking)
        else:
            check module against dependency envs
            write .jxji
    → check user source against accumulated env
    → lower → emit
```

**Checker is Pure** (modulo `Diagnostic`, which is externally Pure —
a handler catches it). Same input → same output. Cache hit semantics
are trivial: if the source hash matches, the env is identical.

Peak memory: the largest single module (~50MB for the biggest file),
not the sum (GB scale for a 10K-line monolithic check). Sub-second
incremental recompilation for large codebases. Parallel compilation:
independent modules check concurrently.

Salsa 3.0 red-green algorithm applies. Grove CmRDT commuting edits
for cross-module re-inference. Content-addressed storage of module
interfaces. **Everything the build system industry has figured out,
implemented as one effect handler on the graph.**

No `make`. No `ninja`. No `Bazel`. No `gradle`. No build DAG to
maintain separately from the source. The compiler proves what's
pure; the compiler uses that knowledge for its own build.

### 9.5 The LSP

There is no separate LSP server. There is JSON-RPC wrapping of the
Query and Teach effects.

```
LSP method                   Inka handler chain
──────────────────────────   ────────────────────────────────────
textDocument/hover           Query(QTypeAt(span)) + teach_why
textDocument/completion      Synth(hole, expected, ctx)
textDocument/diagnostics     Diagnostic + teach_error (per code)
textDocument/codeAction      Explanation.fix (when MachineApplicable)
textDocument/rename          Query(QRefsOf(name)) + edit_handler
```

The LSP server is a thin transport. It accepts JSON-RPC requests,
translates them to Query and Teach performs, runs the handler chain,
serializes the result. No new semantics. No new substrate. **The
compiler IS the language server.**

The `--teach` CLI mode and the LSP hover mode share the same
handler. They diverge only in output format.

### 9.6 The REPL

There is no REPL as a separate program. There is `inka repl` —
a handler that compiles each line to LowIR and evaluates through an
in-process interpreter, or compiles to WASM and invokes a sandboxed
runtime.

Each line's effect row is visible immediately:

```
inka> let x = read_file("data.txt")
  x : String with IO, Fail<IOError>

inka> let y = x |> parse_json
  y : Json with IO, Fail<IOError + ParseError>
```

The REPL handler intercepts effects differently in an interactive
session than in batch compilation — `read_file` prompts to confirm;
`fail` returns to the prompt instead of halting. Multi-shot
continuations preserve the session state across forks (try multiple
inputs to the same computation).

### 9.7 The SMT solver

There is no SMT integration framework. There is `verify_ledger` →
`verify_smt` handler swap.

**Default: `verify_ledger`.** Accumulates refinement obligations in a
structured debt record. At compile end, prints
`N verification obligations pending`. Code compiles; obligations
are visible, countable, queryable.

```
fn bind_port(p: Int) -> Port = p

// Compile output:
// V001 VerificationPending at line 12:
//   predicate: 1 <= self && self <= 65535
//   bound on: port argument to bind_port
//   suggestion: refine the call site, or add `assert p > 0 && p <= 65535`
//   status: pending (no solver installed)
```

**Install `verify_smt`:** the same predicates dispatch to Z3 / cvc5 /
Bitwuzla by residual theory. Z3 for nonlinear arithmetic. cvc5 for
finite-set / bag / map. Bitwuzla for bitvectors. Handler picks the
right solver for the predicate shape.

```
// After `~> verify_smt`:
// E200 RefinementRejected at line 12:
//   predicate: 1 <= self && self <= 65535
//   rejected: self := user_input (no bounds proof)
//   fix: add an assertion or narrow the caller
```

**Handler swap. Source code unchanged.** No flag. No config. No
compile-time feature gate. The `~>` chain names the handler. The
substrate is the substrate.

### 9.8 The ML framework

There is no ML framework as a separate library. There are effects
for `Compute`, `Optimize`, and `Hyperparam`, and handlers for
training, inference, and search.

**Autodiff as an effect.** Model code performs `Compute` operations.
It does not know about gradients.

```
effect Compute {
    matmul<M, N, K>(a: Matrix<M, K>, b: Matrix<K, N>) -> Matrix<M, N>
    relu<S>(x: Tensor<f32, S>) -> Tensor<f32, S>
    softmax<N>(x: Vector<N>) -> Vector<N>
    ...
}

fn forward(model, input) -> Tensor with Compute =
    input
        |> matmul(model.w1)
        |> relu
        |> matmul(model.w2)
        |> softmax
```

**Training handler** records the tape:

```
handle forward(model, x) with tape = [] {
    matmul(a, b) => {
        let out = native_matmul(a, b)
        resume(out) with tape = push(tape, MatMul { a, b, out })
    },
    relu(x) => { let out = native_relu(x)
                 resume(out) with tape = push(tape, Relu { x, out }) },
    ...
}
```

**Inference handler** just computes:

```
handle forward(model, x) with !Alloc, !Random {
    matmul(a, b) => resume(native_matmul(a, b)),
    relu(x)     => resume(native_relu(x)),
    ...
}
```

The inference handler declares `with !Alloc, !Random`. **Provable
determinism. Provable zero allocation.** Safe for embedded
deployment. Same model code.

**Training vs. inference is a handler swap.** Same `forward`. Not
two code paths. Not two implementations. Not a "conversion step."
Handler swap.

**Optimizer as handler.**

```
// SGD — stateless
handler sgd(lr: LearningRate) intercepts Optimize {
    step(p, g) => resume(p - lr * g)
}

// Adam — state in handler
handler adam(lr: LearningRate) with m = zeros(), v = zeros(), t = 0 {
    step(p, g) => {
        let t1 = t + 1
        let m1 = 0.9 * m + 0.1 * g
        let v1 = 0.999 * v + 0.001 * (g * g)
        let m_hat = m1 / (1.0 - pow(0.9, t1))
        let v_hat = v1 / (1.0 - pow(0.999, t1))
        resume(p - lr * m_hat / (sqrt(v_hat) + 1e-8))
            with m = m1, v = v1, t = t1
    }
}
```

Same training loop. Different optimizer. **Swap the handler.**

**Hyperparameter search via multi-shot.** The `Hyperparam` effect
exposes choice points; a handler resumes with each candidate; the
continuation collects all results:

```
handle {
    let lr       = choose_lr()
    let hidden   = choose_hidden()
    let dropout  = choose_dropout()
    let model    = train(config(lr, hidden, dropout), data)
    [(lr, hidden, dropout, evaluate(model))]
} {
    choose_lr()      => flat_map(|lr| resume(lr),      [0.001, 0.01, 0.1]),
    choose_hidden()  => flat_map(|h|  resume(h),       [64, 128, 256]),
    choose_dropout() => flat_map(|d|  resume(d),       [0.1, 0.3, 0.5]),
}
// → all 27 combinations, each with its evaluation score
```

Grid search, random search, Bayesian optimization — **all are handler
strategies** over the same training code. Multi-shot continuations
resume the computation with each candidate. **Genuinely novel** — no
existing ML framework has hyperparameter search at the language
level.

**Shape refinement types** eliminate categories of bugs:

```
type LearningRate = Float where 0.0 < self && self < 1.0
type Probability  = Float where 0.0 <= self && self <= 1.0
type BatchSize    = Int where self > 0 && is_power_of_two(self)

type Tensor<T, Shape> = Buffer<T> where self.len() == product(Shape)

fn matmul<M, N, K>(a: Matrix<M, K>, b: Matrix<K, N>) -> Matrix<M, N>
```

Mismatched dimensions: compile error. Learning rate accidentally set
to 10.0: compile error. Probability outside [0, 1]: compile error.

**Same model code, four deployment targets:**

- **`!IO`** → compile-time evaluation (constant folding of weight init).
- **`Pure`** → multi-core parallelization (safe by construction).
- **`!IO + !Alloc`** → GPU offload (future native backend).
- **`!Alloc`** → embedded / ARM Cortex-M7 deployment (proven zero
  allocation at compile time).

**The handler decides the target.**

### 9.9 The DSP framework

There is no DSP framework. There are `<~`, `Sample`, `!Alloc + Deadline`.

```
fn audio_callback(input: own Block<Sample>) -> own Block<Sample>
    with Sample, !Alloc, Deadline =
    input
        |> highpass(80.0)
        |> compress(4.0, threshold = -12.0)
        |> saturate(1.5)
        |> limit(-0.1)
```

`Sample` effect provides the sample-rate context. `!Alloc` proves
zero allocation transitively. `Deadline` requires budget-bounded
completion. **Four constraints; hard real-time guarantee.** The
industry has been shipping DSP frameworks (JUCE, PortAudio, iPlug2)
for thirty years to manage this. In Inka, it is a function signature.

IIR filter with feedback:

```
audio_in |> biquad(a) <~ delay(1) |> audio_out
```

Under `Sample(44100)`, `<~ delay(1)` is a one-sample delay — the
compiler emits the direct-form IIR filter.

Signal chains are first-class because **functions are first-class.**
A sequential chain is just a function whose body pipes through each
stage:

```
fn eq(x) with !Alloc =
    x
        |> highpass(80.0)
        |> lowshelf(200.0, 3.0)
        |> highshelf(8000.0, -2.0)

fn dynamics(x) with !Alloc =
    x
        |> compress(4.0)
        |> limit(-0.1)

fn master(x) with !Alloc =
    x
        |> eq
        |> dynamics
```

`eq`, `dynamics`, and `master` are reusable values — named chains
waiting to be applied. Install `master` anywhere with `|>`; the
`!Alloc` constraint propagates through the entire composed chain at
compile time. The `|>` operator doesn't just flow data *now*; over
a function body it composes sequential behavior *as a value*. No
point-free composition operator is needed — `fn` plus `|>` already
expresses it.

`><` is reserved for its actual job: **parallel tracks with
independent inputs**. Stereo DSP is the canonical example:

```
fn process_stereo(left: own Sample, right: own Sample) -> (own Sample, own Sample)
    with !Alloc =
    (left |> master)
        ><
    (right |> master)
```

Two independent audio channels, each processed by `master`, outputs
tupled. This is where `><` draws the correct shape.

**DSP and ML compose through the same pipes:**

```
audio |> mfcc(40, 160) |> conv1d(40, 32) |> relu |> dense(12) |> softmax
```

`mfcc` is DSP. `conv1d` is ML. They compose through `|>` with no
adapter, no boundary, no FFI shim. A learned `conv1d` can replace a
hand-designed mel filterbank — the swap is one line.

### 9.10 Concurrency

There is no concurrency library. There is the `Parallel` handler.

`<|` draws the **data topology**: one source, each branch receives
the same input. The **execution topology** — whether the branches
run sequentially, concurrently across threads, deterministically
simulated, or forked — is the handler's choice.

```
// Default: deterministic-sequential. Branches evaluate in order.
audio <| (fft, envelope, pitch_detect)

// Concurrent: same source, different handler. Branches run in parallel.
audio <| (fft, envelope, pitch_detect)
    ~> parallel_handler
```

The `~> parallel_handler` on its own continuation line is the
block-scoped form (Form A from Chapter 2) — it wraps the whole
preceding `<|` expression in the parallel handler, so every branch
runs concurrently. **Source unchanged** from the default version;
only the handler differs. Debug sequentially; deploy in parallel;
test under chaos. One computation. Three execution topologies.

Thread-local `Alloc`: each thread installs its own allocator; no
shared state; no mutex; linear scaling.

Vale-style region-freeze via `!Mutate`:

```
fn parallel_scan(data: ref Buffer) -> Count with !Mutate, Pure =
    data |> chunks(1000) |> parallel_map(count_in_chunk) |> sum
```

`!Mutate` on the region declares "no one writes to this data during
the parallel block." The compiler proves it. **N readers, no writers,
zero data races — through the same effect algebra that proves
`!Alloc`.**

Structured concurrency (child tasks reaped on parent cancel) falls
out: cancel is an effect on child handlers; parent's scope drops →
children's handlers drop → children's computations abort.

Fork-join over `><`:

```
(task_a |> computation_a)
    ><
(task_b |> computation_b)
|> merge
```

Each branch gets its own stack, its own allocator, its own local
state. The parallel handler drives them concurrently. `|>` convergence
is the join.

**Source-unchanged parallelism.** Same code. Different handler.
Sequential for debugging, parallel for production. The pipe topology
*shows* where the parallelism is. `<|` is a fork point; `|>`
convergence is a join.

### 9.11 Time

There is no date-time library with its own semantics. There are four
peer time effects, each with default / test / record / replay
handlers.

```
effect Clock {
    now() -> Instant
    sleep(Duration) -> ()
    deadline_remaining() -> Option(Duration)
}

effect Tick  { tick() -> (); current_tick() -> Int }
effect Sample { sample_rate() -> Int; advance_sample() -> (); current_sample() -> Int }
effect Deadline { deadline() -> Instant; remaining() -> Duration }
```

**Four, not one**, because different domains need different notions
of time:
- **Clock** — wall time. For logs, timeouts, wall-clock deadlines.
- **Tick** — logical time. Monotonic counter, no wall relationship.
  For iterative algorithms, causal/vector clocks.
- **Sample** — DSP time. Integer sample counter at known rate. For
  audio, sensors, fixed-rate simulation.
- **Deadline** — budget. Separate from Clock because the *capability*
  is different — a `Deadline` handler guarantees completion within
  budget, independent of reading wall time.

Test clock:

```
handler test_clock with state = Instant(0) {
    now()                => resume(state),
    sleep(d)             => resume(()) with state = state + d,
    deadline_remaining() => resume(None),
}

// The test body calls now() / sleep() normally
handle test_body() with test_clock
```

No `#ifdef`. No `mock.patch`. No dependency-injection framework.
Handler swap.

Time-travel debugging:

```
handler clock_record with real_clock + capture = [] {
    now() => {
        let t = perform real_now()
        resume(t) with capture = push(capture, t)
    },
    ...
}

handler clock_replay(log: List<Instant>) with !IO {
    now() => match pop(log) { Some(t) => resume(t), None => resume(Instant(0)) },
    ...
}
```

Record in production; replay in debugging. Full deterministic
reproduction of a time-dependent bug. **Same source code.** Same
effect operations. Different handler.

### 9.12 Documentation

There is no documentation generator. Documentation is a handler.

```
source
    |> lex |> parse |> infer
    ~> doc_handler   // captures Document effect, extracts signatures + doc comments
```

Every `///` doc comment emits a `Document` effect during inference;
the doc handler collects them alongside the typed signatures. Output:
markdown that matches the types the compiler already proved.

Doc tests are not a separate runner. A `///` block containing Inka
source is submitted to the same compilation pipeline; if it compiles,
the doc test passes.

No `rustdoc`. No `typedoc`. No `Sphinx`. No format-specific tool.
**Handler on the compile effect.**

### 9.13 The debugger

There is no debugger as a separate process. Every effect is
interceptable. Wrap any computation in a tracing handler:

```
handler trace_all(inner) {
    // Intercept every effect operation, log input/output, then delegate
}
```

Zero application-code changes. Time-travel for free — a trace
handler records every perform; replay in reverse or fast-forward by
feeding the log back through a replay handler.

For audio DSP: wrap the processing chain in `trace_all`. Every
sample, every filter state update, every gain calculation —
recorded. Replay forwards or backwards. **The effect system gives
you this for free because effects are the ONLY way to perform
operations.**

---

## 10. Simulations — The Gap Closed

*Four scenarios where the full machinery above composes. Each is a
trace, not a theorem. Each shows what the programmer experiences
when the medium works.*

### 10.1 The Code SAT Solver — Mentl in the IDE

**Scenario.** A developer is editing the Inka compiler's source. They
add a `List.sort` call inside a function whose signature asserts
`with Pure`. The sort function allocates.

**Trace.**

1. **The editor types the character.** The LSP (Chapter 9.5) sends
   `textDocument/didChange`. The handler chain runs. Module-incremental
   recompilation (Chapter 9.4) loads cached `.jxji` envs in microseconds;
   the one module the developer is editing is re-inferred.

2. **Inference walks the edited function.** At the call to `sort`,
   the inferred row now contains `Alloc`. The `with Pure` constraint
   fails. Inference binds the handle to `NErrorHole(PurityViolated)`
   and continues — the rest of the file still types.

3. **Mentl wakes up.** The error-hole triggers `teach_synthesize`.
   Mentl's speculative gradient:
   - `graph_push_checkpoint()` — save the graph state.
   - Candidate 1: wrap the `sort` call in `temp_arena`. Apply
     patch tentatively. Run inference. Row now subsumes `Pure`
     because `temp_arena` absorbs `Alloc`. Verify passes.
   - Candidate found. `graph_rollback(checkpoint)` — restore the
     original graph.
   - Return `Explanation` with `fix = Some(Patch(span, wrapped_source))`.

4. **The IDE shows the fix.** Hovering reveals:
   ```
   Mentl suggests (MachineApplicable):
     wrap `List.sort(items)` in `handle { … } with temp_arena`

   This preserves `with Pure` because `temp_arena` absorbs `Alloc`.
   The allocated scratch space dies in O(1) when the handler scope drops.
   ```
   Quick-fix accepts the patch. Inference re-runs. The error vanishes.

**What this demonstrates.**

- **Linter obsolescence.** A linter emits a warning and guesses a fix
  from a pattern database. Mentl proves the fix compiles before
  offering it. Every Quick Fix is guaranteed.
- **Global causality, local scope.** The graph traces `Provenance`
  across module boundaries. If the `Pure` constraint came from a
  function five files away, Mentl's Why Engine (Chapter 8) shows the
  exact line that established it.
- **Agentic reasoning via the substrate.** Combining effect algebra
  with O(M) trail-based rollbacks, the compiler explores hundreds of
  candidate patches per second. This is the AI obsolescence
  argument, concretized: the compiler is the agent; the LLM was
  pretending.

### 10.2 The Unified Tensor — DSP × ML

**Scenario.** A non-linear distortion curve, `dynamic_distortion(x, α)`.
On **Thread A** (audio callback) it must process live audio in 2.6ms
with zero allocations. On **Thread B** (background) it must process
historical audio, record gradients, and allocate an autodiff tape.

**Trace.**

1. **The developer writes one function:**
   ```
   fn dynamic_distortion(x, alpha) =
       x |> gain(alpha) |> tanh |> saturate <~ delay(1)
   ```
   No `#if REALTIME`. No `if (training)`. One definition. The
   `<~ delay(1)` is a feedback loop that interpretation varies by
   handler.

2. **Thread A installs the real-time handler stack:**
   ```
   fn process_thread_a() with Sample, !Alloc, Deadline =
       ...
           ~> sample_handler(44100)
           ~> bump_allocator
   ```
   `!Alloc` is declared on the function signature (it's a row
   constraint, not an installable handler); the `~>` chain installs
   the actual handlers. **Evidence Engine** (Chapter 4) synthesizes a
   monomorphized dispatch: `<~ delay(1)` becomes a one-sample delay
   (state in handler-local); `tanh` lowers to a SIMD intrinsic; `gain`
   is a multiplication. Zero allocations. The compiler emits a tight
   loop.

3. **Thread B installs the training handler stack:**
   ```
   fn train_thread_b() with Sample, Compute, Alloc =
       ...
           ~> sample_handler(48000)
           ~> temp_arena(64MB)
           ~> autodiff_tape
   ```
   The same `dynamic_distortion` function is inferred against a
   different effect row. `autodiff_tape` intercepts each `Compute`
   call, records the operation, allocates into the arena. After each
   batch, gradients propagate backward; the arena drops; memory
   returns instantly.

4. **The feedback loop is a state machine both times.** Under
   `Sample(44100)`, `<~ delay(1)` is a Z-transform — classic IIR
   filter. Under `Sample(48000)`, same. Under `Tick` with iteration
   context, the same `<~` would be an RNN's hidden-state recurrence.
   **`infer.jxj` proves they are the same topology** and lowers both
   to the same state machine structure.

**What this demonstrates.**

- **Time is an effect.** The Z-transform (DSP) and the RNN recurrence
  (ML) are not different machinery; they are the same `<~` under
  different handlers.
- **The end of frameworks.** PyTorch and JUCE exist because Python and
  C++ lack effect algebras. In Inka, autodiff is a 15-line handler.
  The language IS the framework.
- **Training vs inference is a handler swap.** Not a translation step.
  Not a porting project. Not a model-conversion tool. Same AST node;
  different Evidence Dictionary passed at runtime.

### 10.3 The C-Straightjacket — concurrency × FFI × capability severance

**Scenario.** A generic `parallel_map` function spawns threads and
applies a polymorphic function. The user passes it a C library
function (compiled to WASM) that declares `FFI, Network, Filesystem`.

**Trace.**

1. **Row-polymorphic evidence.** `parallel_map<A, B, E>(f: fn(A) -> B
   with E, xs: List<A>) -> List<B> with E + Parallel`. When called
   with a function whose row is `FFI`, inference binds the effect
   variable. **The function is higher-order**, so inference
   synthesizes an opaque Evidence Vector (`*const ()`) and rewrites
   the signature to pass the vector at runtime. Monomorphization
   speed, zero code bloat.

2. **Per-thread regions.** `parallel_map` performs `Alloc`. Inference
   mints a hidden Region variable `ρ1` for each spawned thread. The
   `bump_allocator` handler is instantiated per-thread — each thread
   gets its own ρ. Ownership proves no pointers escape their ρ.
   **Thread-safety is handler topology.**

3. **Capability severance via audit.** `inka audit` traces `main()`'s
   `~>` chain. The developer only calls `parallel_map`; they never
   use the C library's `Network` or `Filesystem` capabilities. The
   audit trees the reachable effects and proves `Network` and
   `Filesystem` are unreached. The final binary has them *severed* —
   mathematically proven unreachable; linker dead-codes the
   corresponding imports.

   ```
   $ inka audit main.jxj
   Capabilities required:
     - FFI (via c_lib_foo)
     - Parallel
     - Alloc
   Suggestions:
     - Binary can be built with `with !Network, !Filesystem, !Process`.
   ```

**What this demonstrates.**

- **Generics without bloat.** Rust monomorphizes and bloats. Inka
  compiles `parallel_map` once; the polymorphic effect becomes a
  hidden vtable pointer at runtime.
- **Thread-safety is handler topology, not type traits.** No `Send`.
  No `Sync`. Per-thread handlers prove isolation.
- **Straightjacket on unsafe C.** FFI's declared effects are ambient;
  `inka audit` mathematically proves which of them are reachable in
  this program's dataflow — and severs the rest. Vulnerabilities in
  unused paths cannot execute, because the paths aren't in the binary.

### 10.4 The Distributed Cloud Topography — RPC as delimited continuation

**Scenario.** A checkout flow: `prompt_user` on the browser,
`charge_card` and `save_receipt` on a secure cloud cluster. One
function; two machines.

**Trace.**

1. **The developer writes one function:**
   ```
   fn checkout(items: Cart) -> Receipt =
       items
           |> prompt_user
           ~> client_handler
           |> charge_card
           ~> server_handler
           |> save_receipt
   ```
   The `~>` chain names the split point. Effects from `prompt_user`
   are handled by `client_handler`; effects from `charge_card` /
   `save_receipt` by `server_handler`.

2. **Lower phase sees the split.** `lower.jxj` realizes the handler
   boundary is also a host boundary. It flags the point as a
   **suspension**: a perform-site where the continuation serializes.
   The function is rewritten as an **enum state machine** — each
   suspension a numbered state, locals captured in the state struct.

3. **Emit bifurcates.** `emit.jxj` generates two WASM binaries: client
   and server. The client binary emits code through state N,
   serializes `{state_index = N+1, locals}`, sends the struct over
   the network. The server binary accepts the struct, matches
   `state_index`, restores locals, continues.

**What this demonstrates.**

- **RPC is a delimited continuation.** A network request is
  mathematically identical to a local `yield`. The compiler
  serializes the state struct, fires it across the wire, resumes on
  the remote node.
- **The death of the backend repository.** You do not build APIs.
  Full-stack type safety is not achieved by sharing TypeScript
  interfaces across repositories; it is achieved because **there is
  no stack**. There is only the graph. If the database schema
  changes on State 2, it instantly throws a type error on the UI
  logic of State 0. One compilation. Two binaries. One graph.
- **Infrastructure as handlers.** Terraform configures "the outside
  of a program." In Inka, the outside is the outermost handler.
  Changing deployment from AWS Lambda to a Raspberry Pi cluster is
  swapping `rpc_invoke("aws")` with `actor_send("local_pi")`.

---

## 11. The Closing Fixed Point

Inka has one terminal invariant: the compiler compiles itself to a
**byte-identical** output.

```
inka.wasm < std/compiler/*.jxj  >  inka2.wat
inka.wasm < std/compiler/*.jxj  >  inka3.wat
diff inka2.wat inka3.wat              # empty
```

When this holds, the topology has closed on itself. The graph +
handler mechanism is expressive enough to describe the compiler that
runs it. The fixed point IS the soundness proof — **stronger than any
refinement checker, because it is concrete: the compiler's own image
is reproducible under its own semantics.**

This is the closing moment named `first-light`. It is an execution
concern, not a design concern — its mechanics, bootstrap translator
shape, and rollout are documented in `docs/PLAN.md`. The design
commits to making first-light achievable: every mechanism above is
shaped so the compiler itself fits inside Inka's own expressive
surface, and the Evidence Engine makes self-compilation efficient.

First-light is not the end. It is the beginning. After first-light,
every improvement to Inka is written in Inka, compiled by Inka,
verified by Inka's own refinements, audited by Inka's own `inka
audit`. The scaffolding (the bootstrap translator) is deleted
forever. **The tool and the subject are the same thing.**

---

## 12. Inka Is a Medium

Every language that came before Inka was a tool — something a
programmer picks up, wields, and puts down. Inka is not that.

The compiler does not *check* your program; it *understands* it.
Every type was chosen for a reason; the Reason is recorded in the
graph; Mentl's Why Engine shows you the chain whenever you ask.
Every effect is a capability; the algebra proves presence and
absence; the four gates fall out. Every memory strategy is a handler;
the four models compose; `!Alloc` proves real-time safety end-to-end.
Every topological shape is a pipe; the five verbs draw the graph;
the formatter is a handler that emits the canonical shape. Every
framework dissolves; packaging, testing, DI, build, LSP, REPL, SMT,
ML, DSP, concurrency, time, documentation, debugging — each a
handler.

**There is one mechanism. Everything else falls out.**

The programmer does not use Inka. The programmer **thinks through**
Inka. The pipe operator is not syntax — it is how the programmer
already chains transformations in their head. The effect system is
not type theory — it is how the programmer already separates *what*
from *how*. The handler pattern is not a language feature — it is how
the programmer already thinks about context-dependent meaning.

The gradient is the collaboration pattern encoded. Write nothing; the
compiler infers. Write one annotation; a capability unlocks. Write
more annotations; the compiler proves more; Mentl teaches you what
the next step unlocks. Over sessions, the code drifts from loose to
formally verified, one step at a time. The compiler is the tutor the
AI was pretending to be — but deterministic, verified, cached, yours.
At the top of the gradient, the types are so precise the code writes
itself. Total inference (bottom) and total specification (top) are
the same experience. **You say what you mean, and the language
handles the rest.**

When the medium is right, you forget it is there. You see your
intent, realized. You never see syntax. You never see ceremony. You
see the program you meant, running.

This is Inka. Not a language. A medium. The lens through which the
gap between human thought and machine instruction finally closes.

---

*Design v1 — 2026-04-18. See `docs/PLAN.md` for execution roadmap,
`docs/rebuild/00–11` for per-module contracts, `docs/errors/` for
the error catalog, `docs/INSIGHTS.md` for the living compendium of
crystallized truths, `CLAUDE.md` for session anchors.*
