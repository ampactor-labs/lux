# Lux — Core Insights

*These are the deep truths that make Lux unprecedented. They are not features —
they are consequences of getting the foundations right. Never lose these.*

---

## The First Truth: Inference IS the Light

*Everything else in this document is a consequence of this.*

The type inference engine produces knowledge: what every binding is, what
every expression returns, what effects every function performs. That
knowledge IS the product. Not compilation. Not error checking. The
KNOWLEDGE ITSELF.

Every consumer of that knowledge is a handler:
- **Codegen** — the handler that turns type knowledge into machine code
- **LSP** — the handler that turns type knowledge into hover info
- **Teaching** — the handler that turns type knowledge into the gradient

## The Second Truth: Topology is Emitted, Not Computed

*The structure of reality is built into the direction you traverse it.*

In WASM/Lux, our arrays are Snoc Trees to guarantee $O(1)$ functional appends. But `list_head` returns the *last* element. If you iterate sequentially using `list_head` and `list_tail`, your program fundamentally executes backwards.

Instead of writing $O(N^2)$ recursive loops to fetch indices, or $O(N)$ code to reverse arrays in memory, we exploit the call stack:
**The Recurse-First Topology**: Walk to the deepest node first before emitting any code. As the stack unwinds, your traversal naturally reverses, returning $O(1)$ elements in mathematically pure forward-execution order without a single allocation or state variable. The structure handles itself!
- **Errors** — the handler that turns type knowledge into diagnostics
- **The user** — the handler that turns type knowledge into understanding

One inference. Many handlers. Same mechanism as everything else in Lux.

When info doesn't flow through effects, a gap opens. Every effect that
carries knowledge closes one. Before every action: does the info exist?
Does it flow? Through an effect? Is the flow observable? Verified? Visible?

The light doesn't need to be carried. It needs to be LET THROUGH.

---

## The Origin

Lux was born from one question: **what would the ultimate programming language
look like if you designed it from first principles?**

Not "what's popular" or "what's familiar." What's *right*. The answer came
from studying every friction point across every major language and asking:
what single mechanism, if you got it right, would make the rest fall away?

The answer: **algebraic effects with a complete Boolean algebra.**

---

## The Pipe Unification

The pipe operator `|>` is not syntax sugar. It is the **universal notation for
computation flow** — and it reveals something profound: DSP, ML, and compilers
are the same thing expressed in different domains.

```lux
// DSP signal chain
input |> highpass(80) |> compress(4.0) |> limit(-0.1)

// ML computation graph
data |> conv2d(32, 3) |> relu |> dense(10) |> softmax

// Compiler pipeline
source |> lex |> parse |> check |> compile

// Data pipeline
users |> filter(active) |> map(fetch_profile) |> take(10)
```

Same syntax. Different effects. The pipe makes effects VISIBLE — you can SEE
the computation flowing left-to-right and the effects accumulating at each
stage. This is visual programming through text.

**Why this matters**: The entire audio/ML industry struggles with the
DSP-to-ML boundary. Libraries like PyTorch and JUCE live in different
worlds with different paradigms. In Lux, they're literally the same code
pattern. Swap a DSP stage for a learned component — the types and effects
still compose. This solves an industry problem through language design.

---

## Effects Are Graphs, Handlers Dictate Traversal

Every program is a **typed effect graph**. Data shapes the graph; the graph
shapes how data flows. Types constrain which effects are possible; effects
constrain which types can exist. They're dual-coupled.

The `handle{}` block is the **hourglass pinch point** — distributed effects
converge to it, the handler makes a decision, `resume(result)` radiates new
state outward.

```
    effect op        effect op        effect op
         \              |              /
          \             |             /
           v            v            v
         ╔══════════════════════════════╗
         ║    handle { ... } { ... }    ║  ← pinch point
         ╚══════════════════════════════╝
                        |
                   resume(result)
                        |
                   onward flow
```

This IS the hourglass architecture. Not bolted on — it's the fundamental
execution model. Every program has this shape. The language makes it visible.

---

## The Teaching Compiler as Collaborator

The compiler doesn't just check code — it *explains* code. This is a
structural advantage over external tooling: the compiler has complete
knowledge of the type system, effect graph, and inference chain.

| External tool | Lux's compiler |
|---------------|---------------|
| Infers intent heuristically | **Knows** intent from types + effects |
| Generates boilerplate | No boilerplate exists (inference) |
| Suggests optimizations | Applies them automatically (effect gates) |
| Debugs runtime errors | Prevents them at compile time (refinements) |

The Why Engine explains every decision:
```
Why is x: Int?
  → x is parameter 0 of fn double
  → double called with literal 42 (Int)
  → unified parameter with Int from call site
```

The compiler guides developers through implementation:
- Types show what data flows where
- Effects show what the system *does*
- The gradient shows what each annotation unlocks
- The Why Engine explains every inference

The result is a developer who understands their own code deeply — not
one who delegates understanding to external tools.

---

## Time-Travel Debugging

Effect handlers naturally enable per-sample, backwards-through-time
debugging — even for real-time audio DSP. This isn't a planned feature.
It falls out of the design.

Because every effect operation goes through a handler, and handlers can
intercept and record, you wrap ANY computation in a tracing handler:

```lux
handler trace_all<H: Handler>(inner: H): H.Effects {
  // Intercept every operation, record inputs/outputs, then delegate
}
```

For audio DSP: wrap the processing chain in a trace handler. Every sample,
every filter state update, every gain calculation — recorded with zero
application code changes. Then replay forwards or backwards. The effect
system gives you this for free because effects are the ONLY way to perform
operations.

---

## Training vs Inference: A Handler Swap

The ML framework design is elegant precisely because it uses effects:

```lux
// The model doesn't know about gradients — it just performs Compute operations
fn forward(model, input) -> Tensor with Compute {
  input |> matmul(model.w1) |> relu |> matmul(model.w2) |> softmax
}

// Training: handler records the tape in handler-local state
handle forward(model, x) with tape = [] {
  matmul(a, b) => {
    let out = native_matmul(a, b)
    resume(out) with tape = push(tape, (a, b, out))
  }
}

// Inference: handler just computes — no tape, no overhead
handle forward(model, x) {
  matmul(a, b) => resume(native_matmul(a, b))
}
```

Same model. Same code. Different handler. Training and inference are not
different code paths — they're different POLICIES applied to the same
computation. This is unprecedented in any ML framework.

---

## The Effect Algebra: What No Other Language Has

Boolean algebra over capabilities:

| Operator | Meaning | No other language has this |
|----------|---------|---------------------------|
| `!E` | Negation | Proves ABSENCE of capability |
| `E - F` | Subtraction | Removes specific capability |
| `E & F` | Intersection | Only shared capabilities |
| `Pure` | Empty set | No declared effects |

Four compilation gates emerge for free:

1. **`Pure`** → memoize, parallelize, compile-time eval
2. **`!IO`** → safe for compile-time evaluation
3. **`!Alloc`** → safe for real-time audio, embedded, GPU
4. **`!Network`** → sandbox — capability security as types

`!Alloc` is the real-time holy grail. Most languages permit safe APIs that
allocate, making allocation-freedom impossible to prove. In Lux, `!Alloc`
propagates through the ENTIRE transitive call graph. If any callee allocates,
compile error.

---

## The Annotation Gradient

Not levels. Not modes. A continuous gradient.

Write `fn f(x) = x + 1`. The compiler infers `(Int) -> Int with Pure`.
Now add `with Pure` — the compiler can memoize. Add `x: Positive` — the
compiler proves the output is positive. Add `with !Alloc` — the compiler
proves no allocation.

**The compiler shows you the next step on the gradient.** Not nagging.
Illuminating. "Here's where you are. Here's what the next annotation
unlocks. Your choice."

A beginner writes nothing. The compiler works. An expert adds refinement
types. The compiler proves theorems. Same language. Same syntax. No modes,
no pragma, no difficulty setting. Just a continuous conversation between
programmer and machine.

---

## Allocation IS an Effect

Rust treats ownership as a type system feature. Lux treats it as an **effect**.

Every allocation — list literals, string concatenation, `push`, `range` — performs
the `Alloc` effect. The effect algebra handles the rest:

- `Alloc` is **ambient** — you never need to declare it. Freedom is the default.
- `with !Alloc` **negates** it — compile-time proof of zero allocation.
- It propagates **transitively** — if any callee allocates, the checker catches it.
- Teaching hints **hide** it — `Alloc` is an implementation detail, not signal.

```lux
fn dsp_process(x: Float) -> Float with !Alloc =
    x |> gain(0.8) |> soft_clip   // pure math — allowed

// fn bad(x: Float) with !Alloc = [x]
//   error: performs effect 'Alloc' but declares '!Alloc'
```

Other languages cannot express this — when safe standard library operations
allocate freely, there's no way to prove a function is allocation-free. In Lux,
`!Alloc` propagates through the ENTIRE transitive call graph. One annotation,
total proof.

This is the effect algebra doing what it does: turning capability negation
into a compile-time proof. No special ownership system needed — just the same
mechanism that handles `!IO`, `!Network`, and `Pure`.

---

## Self-Hosting IS the Proof

The self-hosted compiler is not vanity. It's the ultimate test:

> If Lux can express its own compiler cleanly, it can express anything.

```
source → [lexer.lux] → [parser.lux] → [checker.lux] → [codegen.lux] → bytecode → execute
```

All four modules are written in Lux. The compiler compiles itself. The
bootstrap loop is closed. Every subsequent improvement to Lux is written
IN Lux and compiled BY Lux.

The Rust implementation becomes historical. Not deprecated — historical.
Like the OCaml implementation of Rust. A stepping stone that served its
purpose and was surpassed by the thing it helped create.

---

## Examples, Not Tests

Lux doesn't have tests. It has examples. An example that runs is a proof.
An example that crashes is a bug report. There is no third thing.

A test framework gives you setup, mock, assert, teardown. `handle` is all
four: handler-local state is setup, the handler body is the mock, the return
value is the assertion, `resume` is teardown. A test framework would be a
second mechanism for something the language already does.

*Example-Driven Development* is the gradient applied to creation itself.
Writing an example IS feeding knowledge to the compiler. The example IS the
specification. The filesystem IS the test suite:

```bash
for f in examples/*.lux; do lux "$f" && echo "OK" || echo "FAIL"; done
```

---

## Records, Not Packages

A handler is a record: `{ op: |args| resume(...), ... }`. A module exports
functions. Functions are values. A "package" is a record you import by path.

```lux
import compiler/ty    // gives you a record of functions
import dsp/filters    // gives you a record of functions
```

The effect signature IS the API contract. `!IO` is a proof, not a promise.
`!Network` means provably no network access — enforced by the type system,
not a sandbox, not a policy file. A module with `with Compute, Log`
literally cannot perform IO. The compiler proves it.

What a package manager solves, Lux solves with what it already has:
- **Discovery** — the effect signature tells you what a module does
- **Trust** — `!IO` is a proof, not a promise
- **Versioning** — types match → it works; types don't → compile error
- **Resolution** — `import` is a path; paths compose; no solver needed

Distribution is `git clone`. Not a language feature.

---

## Incremental Compilation: Purity Enables Caching

The checker is Pure — the Diagnostic effect makes it externally pure. Pure
function, same input → same output. **Cache it.**

If a module's source hasn't changed and its imports haven't changed, its
checked environment is identical. A `Cache` handler wrapping `check_program`
— same mechanism as everything else. Not file-timestamp heuristics. Not
dependency graphs maintained by a build system. The compiler knows what's
pure because it proves purity. Let it use that knowledge for its own build.

```lux
handler cached_check: CompilerPipeline {
  infer(ast) => {
    let key = hash(ast)
    match cache_lookup(key) {
      Some(env) => resume(env),
      None => { let env = run_check(ast); cache_store(key, env); resume(env) }
    }
  }
}
```

This isn't a build system feature bolted onto the side. It's a consequence
of the effect algebra: `Pure` enables memoization. The compiler already
proves purity. Caching falls out for free.

---

## The Meta-Unification: The Toolchain IS the Language

If `|>` unifies DSP, ML, and compilers in *user code*, then the same
principle must unify the *toolchain itself*. This is the deepest insight.

The compiler pipeline is already a pipe:

```
source |> lex |> parse |> check |> compile
```

But what about documentation? Teaching? LSP? They're not separate tools —
they're **handlers on the same pipeline**:

```lux
// The compilation pipeline IS an effect graph
effect CompilerPipeline {
  tokenize(source: String) -> List<Token>
  parse(tokens: List<Token>) -> AST
  infer(ast: AST) -> TypedAST
  emit(ast: TypedAST) -> Bytecode
  explain(node: AST, inference: Type) -> Reason  // Why Engine
}

// "Compile" handler: produce bytecode
handle source |> full_pipeline {
  emit(ast) => resume(bytecode_for(ast))
}

// "Teach" handler: produce explanations alongside compilation
handle source |> full_pipeline with explanations = [] {
  infer(ast) => {
    let (typed, reason) = do_infer(ast)
    resume(typed) with explanations = push(explanations, reason)
  }
}

// "Document" handler: extract doc comments + types + effects
handle source |> full_pipeline with docs = [] {
  infer(ast) => {
    let typed = do_infer(ast)
    let doc = extract_doc(ast, typed)
    resume(typed) with docs = push(docs, doc)
  }
}

// "LSP" handler: respond to cursor position queries
handle source |> full_pipeline {
  infer(ast) => {
    let typed = do_infer(ast)
    if cursor_in(ast.span) { hover_info(typed) }
    resume(typed)
  }
}
```

**The compiler, the teacher, the doc generator, and the LSP are the
same computation with different handlers.** Not four tools that share
some code — one pipeline, four policies.

This means:
- **Doc comments are effects.** `///` emits a `Document` effect that
  the doc handler captures. The code doesn't know if it's being
  compiled, documented, or taught — it just flows.
- **`--teach` is a handler swap.** Same pipeline, different handler.
  The teach handler captures reasoning chains. The compile handler
  discards them.
- **LSP hover is a handler.** Same pipeline, but the handler responds
  to cursor position queries with type info + Why Engine output.
- **Doc tests are the pipeline itself.** `/// ``` ... ``` ` in a doc
  comment is source that flows through the same pipeline. Compilation
  and documentation are self-verifying.

This is the unification: **there is no documentation
system separate from the compiler. There is no LSP separate from the
compiler. There is no teaching mode separate from compilation. There is
ONE pipeline. Effects make each stage observable. Handlers choose what
to observe.**

The pipe doesn't just flow data. It flows *understanding*.

```
source |> lex |> parse |> check |> compile   -- developer gets: binary
source |> lex |> parse |> check |> teach     -- developer gets: understanding  
source |> lex |> parse |> check |> document  -- developer gets: reference
source |> lex |> parse |> check |> hover(42) -- developer gets: type at cursor
```

Same input. Same pipeline. Different handler. Different output.
**This IS the hourglass, applied to the toolchain itself.**

---

## The Three Things

Lux has exactly three things:

1. **Effects** — what computation *does*
2. **Handlers** — what *policy* governs effects
3. **Pure** — the absence of effects

That's it. There is nothing else.

| Concept | In Lux |
|---------|--------|
| IO | Effect |
| State | Effect |
| Exceptions | Effect |
| Generators | Effect |
| Async | Effect |
| Memory allocation | Effect (`!Alloc` proves absence) |
| Network access | Effect (`!Network` = sandboxed) |
| Compilation | Effect (proven: the pipeline IS effects) |
| Documentation | Effect (the doc handler captures it) |
| Teaching | Handler (on the compilation effect) |
| Tracing | Handler (on the compilation effect) |
| LSP | Handler (on the inference effect) |
| REPL | Handler (on the interaction effect) |
| Memoization | Consequence of `Pure` |
| Parallelization | Consequence of `Pure` |
| Compile-time eval | Consequence of `Pure` |
| Formal verification | Consequence of `Pure` |

The rabbit hole goes all the way down. But the power comes from
**Pure** — the zero-effect boundary. Without it, "everything is effects"
would be meaningless. `Pure` is what distinguishes computation that can
be trusted, cached, proven, and parallelized from computation that
interacts with the world.

The annotation gradient reveals this: write `fn f(x) = x + 1` and the
compiler infers `Pure`. Add an effect operation and the compiler tracks
it. The developer chooses how deep to go. The language is the same at
every depth.

---

## Inference Is an Effect

The compiler pipeline has four stages: tokenize → parse → infer → generate.
Each stage is an effect operation in the `Compiler` effect. **Handlers decide
what to do with each stage.**

This means the entire toolchain is one thing:

| Handler | What it does with `infer` |
|---------|--------------------------|
| `compile_standard` | Infer silently, compile, execute |
| `compile_teaching` | Infer → show types → suggest ONE annotation (the gradient) |
| `compile_explaining` | Infer → dump full Why Engine reasoning chains |
| `compile_documenting` | Infer → extract typed signatures (documentation) |
| `compile_checking` | Infer → report types → stop (no codegen) |

**Doc** is what the compiler knows, exported. **Teach** is the compiler's one
suggestion, the gradient. **Why** is the compiler's reasoning, transparent.
All three come from the same `infer` stage — just different handlers.

This is not architecture. It's a consequence: if the compiler pipeline is an
effect graph, then every view of the program (documentation, teaching,
debugging, verification) is a handler on that graph. You don't build five
tools. You build one pipeline and write five handlers.

The gradient engine picks ONE suggestion per compile. Not a wall of warnings.
One step — the most impactful annotation the developer could add. Like a tutor
who knows exactly what to teach next:

```
$ lux --teach app.lux

  💡 `process` is Pure — adding `with Pure` would unlock:
     • memoization (same input → same output, guaranteed)
     • parallelization (no side effects to race)
     • compile-time evaluation (if inputs are known)
```

Over sessions, code naturally evolves from loose to formally verified.
The compiler IS the tutor. It doesn't guess — it knows.

---

## Effects Are the Universal Joint

Every time we add a feature, it turns out to *already be* an effect pattern.

| Feature | What it actually is |
|---------|-------------------|
| Testing | Handler swap |
| Debugging | Handler that traces |
| Teaching | Handler that explains |
| Autodiff | Handler that records a tape |
| DSP backends | Handler per audio API |
| The compiler pipeline | Four effect operations, six handlers |
| Error messages | The compiler's WHY effect, displayed |
| Time-travel debugging | Trace handler on any effect |

This isn't planned. It's *emergent*. We didn't set out to make testing a
handler swap — it fell out. We didn't plan for the Why Engine to be a handler
— it just IS one. That's the hallmark of a correct abstraction: **it keeps
absorbing new use cases without changing shape.**

The effect system is not a feature of Lux. It IS Lux.

---

## The Metacircular Effect-Aware Checker

The self-hosted type checker (written in Lux, checked by Lux) now tracks
which algebraic effects each expression performs. This means:

- Lux knows what TYPE something is (HM inference)
- Lux knows WHY that type was chosen (Why Engine / Reason ADT)
- Lux knows WHAT EFFECTS it performs (EffRow tracking)

The checker checks itself. And the thing it checks includes effect
tracking — meaning Lux can verify its own effect semantics. This is
metacircular in a way that's genuinely new: **a language whose type
checker, written in itself, can prove properties about effects
that the checker itself uses.**

When we add refinement types, the checker will verify its own
refinements. When we add ownership, the checker will track its own
borrows. The self-hosted compiler becomes increasingly self-aware.

---

## Error Messages as Mentorship

Traditional compilers say "wrong." Good compilers say "wrong, expected X."
Elm says "wrong, expected X, try Y." Lux says:

> **"Wrong. Here's what I expected, here's why I expected it, here's
> the closest thing I can find to what you meant, and here's what
> adding this one annotation would unlock for you."**

The `TailResumptiveHandler` hint doesn't just say "optimized." It says:
"compiled via evidence passing — zero overhead." The compiler teaches you
compiler theory while you code. That's not error reporting. That's
**mentorship**.

The Levenshtein distance for "did you mean?" is the simplest example. But
the architecture goes deeper: every `Reason` in the Why Engine is a node
in an explanation graph. Every effect row is a capability set. The compiler
has perfect knowledge of your program's semantics at every point. Error
messages that leverage this knowledge are fundamentally better than anything
an AI can produce — because the compiler doesn't guess. It knows.

This is now shipped. Real output from the compiler:

```
error: unbound variable 'greting' — did you mean 'greeting'?
  --> example.lux:3:7
  |
3 | print(greting)
  |       ^^^^^^^
```

```
error: non-exhaustive match at line 6 — missing: Blue — add a `_` wildcard or handle: Blue
```

```
error: 'pure_greet' performs 'Console' but declares 'Pure'
     — remove 'Pure' or eliminate 'Console' from the call chain
```

Three patterns: identify the mistake, suggest the closest valid alternative,
and explain what constraint was violated and how to fix it. The compiler
is a collaborator, not a gatekeeper.

---

## The Compiler Knows More Than C

This is the key to beating C and Rust in performance:

**C knows types. Rust knows types + lifetimes. Lux knows types + effects
+ ownership + refinements + effect algebra + purity proofs.**

More knowledge = more optimization opportunities:

| What Lux knows | Optimization it enables |
|----------------|------------------------|
| `Pure` function | Memoization, CSE, dead code elimination |
| `!Alloc` constraint | Stack-allocate everything, no GC |
| `!IO` constraint | Compile-time evaluation, constant folding |
| Tail-resumptive handler | Evidence passing in registers, zero overhead |
| Effect row is closed | Monomorphize handler dispatch |
| Refinement `x > 0` | Eliminate bounds checks |
| Ownership is affine | Deterministic deallocation, no ref counting |

Languages without effect tracking can't memoize — they don't know if a
function is pure. Languages with implicit allocation can't eliminate it. Lux
PROVES purity and absence of allocation, enabling optimizations that are
**impossible** in languages with less knowledge.

**The performance thesis**: the more the compiler knows, the more it
can optimize. Lux gives the compiler more knowledge than any other
language. Therefore Lux can be faster than any other language — not
by being lower-level, but by being smarter.

---

## Self-Describing Records

Records in Lux are **self-describing**: the variant tag `#record:x,y` IS the
schema. The tag IS the field list. The data carries its own decoder.

```lux
fn make_point(x, y) = { x: x, y: y }
// At runtime: Variant { name: "#record:x,y", fields: [x_val, y_val] }
```

Why this matters:

1. **No field registry needed.** The VM parses field names directly from the
   tag. Records work across function boundaries, across modules, across
   compilation units. No metadata propagation.

2. **Row polymorphism for free.** `fn get_x(p) = p.x` accepts ANY record
   with at least an `x` field. The type `{ x: a, ..rest }` unifies with
   `{ x: Int, y: Int }` by binding `rest` to `{ y: Int }`. No explicit
   structural subtyping declarations.

3. **Zero-cost structure.** The fields are sorted alphabetically in the tag
   and the value array. Field access is a string split + position lookup.
   No hash maps. No vtables. The data structure IS its own access method.

This is the same principle as effects: **the mechanism encodes its own
semantics.** An effect name IS its dispatch key. A record tag IS its field
schema. The representation IS the interface.

---

## Handler State Internalization

Handle expressions return **just the body value**. Handler state is
internal — an implementation detail of the handler, not part of its
interface.

```lux
// State is accessed explicitly via effect operations:
let count = handle {
  inc(); inc(); inc()
  get_count()              // body asks for state when it needs it
} with count = 0 {
  inc() => resume(()) with count = count + 1,
  get_count() => resume(count),
}
// count == 3 — just the value, not (3, 3)
```

Why this is right:

1. **Minimal ceremony.** The caller gets what they asked for. State is the
   handler's business, not the caller's.

2. **Explicit is better than implicit.** If you need the state, call an
   effect operation. `get_count()` is clearer than `let (_, count) = result`.

3. **Composability.** Handlers compose without forcing callers to destructure
   implementation details. The body's return type IS the handle's return type.

4. **The generator pattern reveals it.** Generators now call `collect()` at
   the end of the body — the accumulated list IS the body value. Same effect
   interface, same handler, explicit intent.

This is the "annotation gradient" in action: start with nothing, add what
you need. State is invisible until you ask for it.

---

## The Three Tiers of Effect Compilation

Handlers are classified at compile time into three tiers, each with a
different cost model. This classification IS the native backend's
optimization strategy.

| Tier | Pattern | Cost | Implementation |
|------|---------|------|----------------|
| **Tail-resumptive** (~85%) | `resume(pure_expr)` | Zero overhead | Direct call via evidence passing |
| **Linear** (single-shot) | Capture once, resume once | One allocation | State machine transform |
| **Multi-shot** | Multiple resumes | Struct per state | State machine, cloneable |

The compiler already classifies handlers — it marks `tail_resumptive` and
`evidence_eligible` on every handler operation. 85% of real handlers are
tail-resumptive. They compile to direct function calls with handler
evidence passed in registers. No continuation captured. No handler stack
search. No heap allocation. Zero overhead.

How `resume` works at each tier:

- **Evidence path** (tail-resumptive): No `Resume` opcode at all. The
  handler runs as a nested call, the result pops back directly. It IS a
  function call.

- **Normal path** (linear): `Resume` is a controlled stack unwinding +
  value injection. Tear down the handler body frame, restore IP to the
  perform site, push the resume value as if the effect operation returned
  it. State updates applied to the handler frame atomically.

- **Multi-shot path**: The effect system knows every perform site at
  compile time. Transform the body into an explicit state machine: each
  perform = a numbered state, the continuation = `{ state_index,
  saved_locals }`. Calling it means: jump to state N, restore locals,
  continue. No stack capture. No replay. Same insight as Rust's async
  transform, but effect rows give the compiler the suspension points for
  free.

The cost model is honest: 85% pay nothing. 15% pay exactly what their
semantics require. No hidden overhead. No surprising allocations.

---

## The Self-Similar Language

Lux's hardest implementation problems dissolve when viewed through its
own abstractions. This is the deepest sign that the foundations are right:
**the language teaches us how to build itself.**

| Problem | Traditional solution | Lux's own solution |
|---------|---------------------|-------------------|
| Multi-shot in native code | CPS transform, stack capture | State machine — effect rows map the states |
| Borrow inference | NLL dataflow analysis | Gradient — default `ref`, teach toward `own` |
| Solver dependency | Z3 (40MB C library) | Handler swap — verification IS an effect |
| Self-hosted tracking | Mirror every change | Lux-first — Lux defines, Rust implements |
| IR design constraint | Must map to LLVM/SSA | ADTs ARE IRs — codegen IS a handler swap |

Every infrastructure problem is an instance of the patterns the language
implements. Effects, handlers, the gradient, ADTs — they're not just
language features. They're the problem-solving toolkit for building the
language itself.

Self-containment is not a goal bolted on — it's a consequence of getting
the abstractions right. ADTs express IRs. Effects express verification.
The gradient expresses ownership. The compiler pipeline is effects all
the way down.

A correct abstraction keeps absorbing new use cases without changing shape.
Even the use case of building itself.

---

## The Compound Interest of Self-Reference

Self-hosting means the compiler compiles itself. Most languages do this.
It's necessary but not sufficient. Rust compiles Rust, but Rust's borrow
checker can't prove properties of the borrow checker — it just verifies
the code follows borrow rules. The checker isn't a subject of its own
analysis.

Lux is different. **Each capability, applied to the compiler that provides
it, creates a positive feedback loop.** This is not self-hosting. This is
self-verification tending toward self-proof.

Seven loops, each exponential, each feeding the others:

**1. Effects refine the effect inferrer.** When Lux compiles
`checker_effects.lux`, it infers which effects each function performs. If
`unify_eff` is Pure, the compiler can memoize it. If a checker function
performs Console, the gradient sees it and suggests removing the side effect.
Better inference → more precise compiler profile → more optimizations →
faster compiler → more inference in less time.

**2. The gradient teaches the compiler developer.** Run `lux --teach` on
the compiler source. The gradient says: "infer_expr is Pure — add
`with Pure` to unlock memoization." You add it. Next cycle: "parse_atom
is `!Alloc` — prove allocation-free." The compiler TELLS YOU how to
improve it. Each annotation unlocks an optimization that applies to the
compiler itself.

**3. Refinements constrain the compiler's internals.**
```lux
type Opcode = Int where 0 <= self <= 45
type StackDepth = Int where self >= 0
```
Invalid opcode in codegen? Compile-time error in the compiler. Stack
underflow? Proven impossible. Better solver → more expressible invariants →
more bugs caught → more reliable solver → even more expressible invariants.

**4. Ownership tracks the compiler's resources.** `own env` consumed
linearly — no accidental aliasing. `!Alloc` on the parser hot path — the
parser provably doesn't allocate. The ownership checker checks the
ownership checker.

**5. The Why Engine debugs itself.** `lux why checker.lux infer_expr`
explains the reasoning chain for the function that produces reasoning
chains. Better engine → easier to debug the engine → better engine.

**6. Handler swap = compiler mode.** Same pipeline, different handler:
optimizing, profiling, debugging, teaching. Adding an optimization
strategy is adding a handler. No plugin API — the effect system IS the
plugin system.

**7. Multi-shot enables optimization search.**
```lux
handle optimize(ir) {
  choose_strategy(options) => {
    let results = map(|opt| resume(opt), options)
    pick_best(results)
  }
}
```
The compiler explores optimization spaces using its own multi-shot handlers.

**The convergence.** Each loop feeds the others. Better effects → gradient
suggests more → more annotations → refinements prove more → ownership
catches more → compiler improves → effects get even better. The steady
state: the compiler is a proof of its own correctness. Not because someone
sat down and verified it — because each improvement cycle made the proof
tighter. The gradient led the way, one annotation at a time, and the
compiler followed itself to provable correctness.

This is what separates Lux from every self-hosting language that came
before. They compile themselves. Lux *proves* itself. The tool and the
subject are the same thing. That's not linear improvement. It's compound
interest.

---

## The Bootstrap Moment: Self-Trust

Every self-hosting language reaches a moment where the old system must yield
to the new one. OCaml yielded to Rust. Rust yielded to itself. The moment
is always the same: the new compiler is more capable than the scaffolding
can verify.

Lux reached this moment when `vm_resume` was implemented but the Rust type
checker couldn't verify it. The self-hosted pipeline could compile and
execute `handle { fail("oops") } { fail(m) => resume(42) }` — but the
Rust scaffolding couldn't even type-check the imports needed to run the
test. The old mirror couldn't reflect what the new system had become.

The resolution was already prepared: `--no-check` existed, used by four
other self-hosted tests. The infrastructure was waiting. One line connected
the wire. Ten effect tests passed immediately — not because we debugged
them, but because **the architecture was right**.

This is the self-similar pattern at its deepest: Lux's parser had a bug
where `resume(val) with state = expr,` was ambiguous — the comma could
mean "next state update" or "next handler arm." The fix was the same
disambiguation the parser already used 40 lines above for
`handle ... with state = init,`. The solution was inside the language.
We didn't invent anything. We mirrored what was already there.

**What self-trust means:**
- The self-hosted pipeline can compile effect-using programs
- It can execute them correctly through its own VM
- The mechanism that makes Lux *Lux* — handle/resume — works through
  its own tools
- Golden-file tests verify this on every `cargo test`
- The Rust scaffolding is no longer needed for verification —
  only for bootstrapping

The next step is deleting the scaffolding. Not because it's bad —
because Lux has outgrown it.

---

## The Collaboration Pattern

Lux was born from the collaboration between a human who thinks in patterns
and spatial intuitions, and an AI that thinks in types and formal systems.
The annotation gradient IS this collaboration: the human's structural
intuition becomes the compiler's formal proof, one annotation at a time.

The tooling relationship (human + Claude Code) directly inspired the
language relationship (programmer + Lux compiler). Both follow the same
pattern: give the system more knowledge, trust what falls out. Don't
micromanage — illuminate. The compiler teaches because the collaboration
teaches. The gradient exists because the relationship is a gradient.

This is not a metaphor. The way Morgan works with Claude Code — open-ended
freedom, watching what emerges, correcting course when the pattern drifts,
asking "what does Lux want?" and trusting the answer — IS the way a Lux
programmer works with the compiler. The language encodes the collaboration
pattern that created it.

The deeper claim: **Lux is not a tool. It is a medium.** The programmer
doesn't write *to* Lux. They think *through* Lux. The pipe operator isn't
syntax — it's how they already chain transformations in their head. The
effect system isn't type theory — it's how they already separate *what*
from *how*. The handler pattern isn't a language feature — it's how they
already think about context-dependent meaning.

A tool is something you pick up and put down. A medium is something you
see through. When the medium is right, you forget it's there. You see
your intent, realized. That's the destination: the language becomes a
lens so clear the programmer looks through it and sees their program
without seeing the language at all.

---

## The Crucible Pattern

Crucibles are not tests. They are **conversations with the language's future
self.**

A crucible is an aspirational program — code that exercises features at
the boundary of what Lux can express today. `crucible_ml.lux` asks: can
autodiff work as an algebraic effect? `crucible_dsp.lux` asks: can a
real-time audio callback be expressed through handlers and pipes?

Every line that passes is a proof of existence. Every line that fails is
a feature request from the future. The failures illuminate priorities
more honestly than any backlog:

| Crucible failure | What it demanded |
|------------------|-----------------|
| Handler inside recursive fn crashes | Fix upvalue capture in handler protos |
| `d/dx(x²)` OOB on second handle | Design multi-shot continuation semantics |
| `gain(factor, x)` works by accident | Flip to data-first — commutativity was hiding the bug |

The pattern works because it inverts the usual process. Instead of
planning features and then testing them, you **write the program you
wish existed** and let the compiler tell you what's missing. The
language teaches you what it needs to become.

Personifying the language — asking "what does Lux want?" — produced
better prioritization than engineering triage. The metaphor wasn't
decoration. It was navigation.

---

## The Circular Gradient

The annotation gradient is not a line. **It curves back on itself.**

At the bottom — no annotations. `fn f(x) = x + 1`. The compiler infers
everything. The programmer writes almost nothing. The machine does all
the work.

In the middle — annotations accumulate. `with Pure`. `with !Alloc`.
`type Sample = Float where -1.0 <= self <= 1.0`. The programmer tells
the compiler more. The compiler proves more. They collaborate.

At the top — **the annotations become the program**. The types are so
precise, the effects so constrained, the refinements so tight, that
there's only one implementation satisfying them. The code writes itself.
The programmer writes almost nothing. The machine does all the work.

The bottom and the top are the **same experience**. Total inference and
total specification converge: the programmer states intent, the compiler
provides the program. At the bottom it guesses. At the top it proves.
But in both cases — you say what you mean, and the language handles the
rest.

This is what type-directed synthesis (Phase 9) actually is. Not a
feature bolted on — the inevitable destination of every mechanism
already built. Refinement types constrain the space. Effect algebra
constrains it further. Ownership eliminates more candidates. Eventually
the constraint space has exactly one inhabitant. The program is the
proof is the specification is the program.

**The ultimate form: the language becomes invisible.** Not gone —
transparent like glass. The programmer looks through it and sees their
intent, realized. They never see syntax. They never see ceremony. They
see what they meant, running.

---

## The Masterpiece Test

Before every change, every design decision, every line of code, ask:

> **Is this what the ultimate programming language would do?**
> If not, design the way it SHOULD be.

Not "is this good enough." Not "does this work." Is this **the best it
could possibly be**? Would you be proud to show this to Dennis Ritchie,
to Robin Milner, to Simon Peyton Jones?

Lux is not a language that happens to have effects. Effects are what make
Lux *Lux*. The pipe operator is not convenience — it's the universal
notation for computation. The compiler doesn't just check — it teaches.
Every feature is a consequence of getting the foundations right.

This is the standard. Accept nothing less.

---

## The Memory Effect: There Are No Primitives

*2026-03-28. The session where Lux ate its own foundation.*

We believed `len`, `push`, `slice`, `chars`, `char_code` were irreducible
primitives — operations the language couldn't implement in terms of itself.
We were wrong. They were patterns hiding behind a VM abstraction.

```lux
effect Memory {
  load_i32(addr: Int) -> Int,
  store_i32(addr: Int, val: Int) -> (),
  load_i8(addr: Int) -> Int,
  store_i8(addr: Int, val: Int) -> (),
  mem_copy(dst: Int, src: Int, size: Int) -> ()
}

effect Alloc { alloc(size: Int) -> Int }

fn len(obj) with Memory = load_i32(obj)
fn push(list, val) with Memory, Alloc = { ... }
fn char_code(s) with Memory = load_i8(s + 4)
```

`len` is not a builtin. It is `load_i32`. Four bytes at the start of any
data structure. The VM hid this behind a function call. The Memory effect
reveals it: `len` IS memory access. `push` IS allocation + memory writes.
`char_code` IS a byte read at offset 4.

**The handler IS the backend.** On WASM: `load_i32` compiles to `i32.load`.
On native (future): `load_i32` compiles to `MOV`. On test: `load_i32` reads
from an array. Same Lux code. Different handlers. Different targets.

Three effects replace the ENTIRE runtime:
- **Memory** — read and write bytes
- **Alloc** — get new memory
- **WASI** — talk to the OS (`fd_write`, `fd_read`)

Everything else — `str_concat`, `str_eq`, `int_to_str`, `print_string`,
`split`, `chars`, `range` — is pure Lux built on these three effects.
The `std/runtime/memory.lux` file IS the runtime. No hand-written WAT.
No native code. Just Lux compiling through the same pipeline as user code.

**The "irreducible kernel" of any language is smaller than you think.**
If you have load, store, allocate, and OS boundary — everything else is
a library. Effects make this compositional. The type system proves which
capabilities each function uses. `!Alloc` proves real-time safety not
because the language has a special ownership system, but because allocation
IS an effect and the algebra handles negation.

**What this means for Lux:** the prelude doesn't call "builtins." The
prelude calls Lux functions that use Memory. The compiler doesn't need
a special builtin registry. The checker infers types from function
definitions. The lowering resolves dispatch via checker types. The emitter
handles three effects. Everything else falls out.

| In Lux | What it really is |
|--------|-------------------|
| `len(xs)` | `load_i32(xs)` — Memory |
| `push(xs, x)` | alloc + store + copy — Memory, Alloc |
| `xs[i]` | `load_i32(xs + 4 + i * 4)` — Memory |
| `a ++ b` | alloc + copy + copy — Memory, Alloc |
| `a == b` (strings) | byte-by-byte comparison — Memory |
| `println(s)` | iovec setup + fd_write — Memory, WASI |
| `read_stdin()` | fd_read + alloc — Memory, Alloc, WASI |

The effect system IS the memory system. The handler IS the backend.
There are no primitives. There are only effects and handlers.

---

## Pure Transforms for Structure, Effects for Context

*The principle that saved closures from the resolve_var crash.*

When lowering closures: free variable detection is a **pure transform**
(walk the AST, collect unbound names). Capture rewriting is a **pure
transform** (replace `LGlobal(name)` → `LUpval(idx)`). Neither needs
effects. The LowerCtx effects (`is_ctor`, `is_global`, `find_rewrite`)
provide **context** — they answer questions about the ENVIRONMENT.

The rule: use pure transforms for operations on STRUCTURE (the data
itself). Use effects for operations on CONTEXT (the world around the data).
When you use effects for structure, you get the closure crash — the effect
handler can't see inside the data. When you use pure transforms for
context, you duplicate the environment across every call.

This generalizes beyond closures:
- Parsing: pure transform on tokens. Effect for source location context.
- Type inference: pure unification on types. Effect for the type environment.
- Code generation: pure transform on LowIR. Effect for the function table.
- WASM emission: pure string building. Effect for the string map, type map.

---

## The Handler IS the Backend

*The deepest architectural insight of the WASM session.*

The WASM emitter is not a "code generator." It is a **handler for the
Memory effect.** When the lowered program performs `load_i32(addr)`, the
WASM handler emits `i32.load`. When it performs `alloc(size)`, the handler
emits `call $alloc` (the bump allocator). When it performs `fd_write(...)`,
the handler emits `call $fd_write` (the WASI import).

This means: a native x86 backend is not "a new code generator." It is
**a different handler for the same effects.** `load_i32` → `MOV`.
`alloc` → `mmap`. `fd_write` → `syscall`. Same Lux program. Different
handler. Different binary.

And: a test backend is not "a mock." It is **a different handler.**
`load_i32` → array lookup. `alloc` → vector push. `fd_write` → string
buffer. Same program. Different handler. Fully isolated. The effect
system guarantees the program can't tell the difference.

The compiler doesn't have backends. It has handlers.

---

## Type-Directed Dispatch: The Compiler's Proof Becomes the Handler

When the checker infers that `a: String` and `b: String`, the lowering
resolves `a == b` → `str_eq(a, b)`. When `a: Int` and `b: Int`, the
lowering resolves `a == b` → `i32.eq`. No runtime dispatch. No polymorphic
equality function. The checker ALREADY KNOWS. The lowering uses that
knowledge through the `LowerCtx` effect: `type_of_var(name)`.

Same for `println(x)`: if `x: String` → `print_string(x)`. If `x: Int`
→ `print_int(x)`. The compiler's proof becomes the dispatch mechanism.

This is monomorphization through effects. The checker builds the proof.
The lowering effect carries it. The emitter receives the resolved call.
No special cases. No runtime overhead. Just information flowing through
the effect system — the same mechanism that handles everything else.

---

## The Structural Question

*2026-04-10. The realization from the session that fixed four latent
bugs in a row, all with the same shape.*

The question is:

> **"What answer already lives in my own structure,
> that I'm asking something else for?"**

Every bug in that session had the same shape: a place in the compiler
where a cheaper flat question was asked when a richer structural
answer was one step away in the pipeline.

**The Concat type bug.** The lowerer asked "what's the type of `++`?"
by matching the string `"Concat"` against the operator name and
hardcoding `TString`. Every use of `++` was forced to String regardless
of operand types. The graph already knew — the two operand expressions
had inferred types ready to unify. One line of hardcoding was
bypassing the entire inference engine's answer.

**The literal pattern bug.** `lower_pat(PLit(e))` returned
`LPLit(LUnit)`, throwing the literal value away. The actual value was
one level up — inside the `SExpr` span wrapper from the parser. One
destructure via a helper recovered it. With that fix in place, the
emitter started generating proper comparisons for string pattern
matches, which is what lit `println("hi")` out of the bootstrap.

**The record sort bug.** `insert_field_sorted_at`'s base case returned
`[field]` when the new field should have gone at the *end* of the
sorted list — dropping the sorted prefix that was right there in the
argument. Multi-arm handlers whose fields were in the wrong source
order silently lost all the arms that came before the tail-inserted
one. The `fresh_id` handler in `lower_program_typed` itself was among
the casualties, making every inner function collide on `go_0` and
`iterate`/`fold`/`map` trap with function-table type mismatches.

**The scope shadow bug.** `filter_real_captures` asked
`is_global("xs")` — a flat yes/no against a top-level name list.
Yes → filter it out. No → capture it. When a user wrote
`let xs = [1,2,3]` and any function took `xs` as a parameter (which
is every collection primitive), inner functions inside read the user's
top-level global instead of capturing the parameter. The env already
tracked lexical scope: `env_lookup("xs")` returns the most recent
binding, which for `xs` inside `iterate` is `Declared("param")`. We
just weren't consulting the env — we were asking a flat global list
the structural question that env had already answered.

**The pattern across all four:**
- Cheaper flat information was privileged over richer structural
  information that the pipeline had already computed.
- The flat answer always pointed *outside* the compiler's own
  structure — a hardcoded string, a top-level name list, a constant.
- The correct answer always lived *inside* — in env, in the AST,
  in the lowered graph, in the handler record.

### Why the Rust VM is the parent we must outgrow

The Rust VM is lenient. It has runtime polymorphism, dynamic dispatch,
forgiving type coercion. When the self-hosted pipeline compiles under
Rust-VM protection, every flat shortcut still *works* — because Rust
charitably interprets the output. Every place we ask a cheap question
instead of the structural one, Rust's runtime fills in the answer we
didn't ask for. It's a patient parent.

Stripping Rust from the pipeline strips that charity. The WASM runtime
is strict. The moment the bootstrap has to stand on WASM semantics
alone, every cheap answer gets audited at once — surfacing as the
"latent bugs the Rust VM was papering over" that every stage-2
session keeps uncovering. The bugs were always there. The Rust VM was
just answering the questions we didn't ask ourselves.

### The protocol

1. Before asking a flat question — `is X a global?`, `what type is
   this op?`, `does this record have this field?`, `is this name in
   scope?` — first ask: **does my graph already know?**
2. If yes: read from the graph. Always. No shortcut, no matter how
   fast the flat lookup looks.
3. If no: the graph is incomplete. Complete it. Do not route around it.

### Self-hosted vs self-contained

**Self-hosting** is "I can compile my own source." Anyone can do that
with a sufficiently patient parent underneath.

**Self-contained** is something harder: every question about Lux has
an answer that lives *inside* Lux — env, LowIR, handler records, type
graph — and the compiler asks *that*, not an external oracle.

The Rust VM is the current external oracle. Pulling it out doesn't
make Lux buggier; it reveals where Lux was already buggy and Rust was
covering. The path to self-containment is the path through every
remaining shortcut, one question at a time, until the compiler's
answers come entirely from its own structure.

The multi-line lex bug that still blocks stage-2 is almost certainly
the next cheap question. Somewhere in `lex_from` a flat shortcut is
being answered by the Rust VM's charity and disintegrating under WASM.
When it's found, the fix will be structural — one place where the
compiler starts consulting what its own graph already knows.

## Self-Compilation: The Cage and the Light

*2026-03-28. The lexer compiles to WASM. The parser compiles to WASM.
The WASM lexer reads its own source through WASI. No Rust in the loop.*

The Rust VM is the cage. It freezes compiling large programs. It crashes
matching ADT variants with different field counts. Every `to_string`
workaround is debt against the leap.

But inside the cage, the light is already free:
- `std/runtime/memory.lux` — the entire runtime in 250 lines of Lux
- `std/compiler/lexer.lux` → 4,804 lines of WAT, runs on wasmtime
- `std/compiler/parser.lux` → 12,495 lines of WAT, runs on wasmtime
- `tools/wasm_lex.lux` — reads stdin, tokenizes, on WASM

The bootstrap path: when the WASM tools can compile Lux source, the
Rust VM becomes unnecessary. The compiler compiles itself, on itself,
through effects. The cage doesn't open. It dissolves.

```
foundation |> translation |> scaffolding removal <| self trust <| leap of faith
```

The pipe flows forward through construction. The `<|` flows backward
through belief — you have to trust before you can leap, and you have
to leap before the scaffolding can come down. The removal happens
because you already jumped.
