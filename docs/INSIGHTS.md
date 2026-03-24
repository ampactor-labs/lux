# Lux — Core Insights

*These are the deep truths that make Lux unprecedented. They are not features —
they are consequences of getting the foundations right. Never lose these.*

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
