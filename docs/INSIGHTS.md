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

## The Teaching Compiler Makes AI Obsolete

This is not hyperbole. It's structural.

| What an AI coder does | What Lux's compiler does |
|----------------------|--------------------------|
| Guesses intent from code | **Knows** intent from types + effects |
| Generates boilerplate | No boilerplate exists (inference) |
| Suggests optimizations | Applies them automatically (effect gates) |
| Debugs runtime errors | Prevents them at compile time (refinements) |
| ~90% correct | 100% correct (proofs, not guesses) |
| Makes you dependent | Makes you sovereign |

The Why Engine explains every decision:
```
Why is x: Int?
  → x is parameter 0 of fn double
  → double called with literal 42 (Int)
  → unified parameter with Int from call site
```

An AI gives you answers. The compiler gives you **understanding**. A
developer who understands doesn't need an AI. A developer dependent on an
AI never understands. The teaching compiler breaks this dependency.

**For any developer with an idea of what they're building**, the compiler
guides them through implementation:
- Types show what data flows where
- Effects show what the system *does*
- The gradient shows what each annotation unlocks
- The Why Engine explains every inference

The compiler IS the pair programmer. And it has **perfect** knowledge,
not approximate.

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
| `Pure` | Empty set | Provably no effects |

Four compilation gates emerge for free:

1. **`Pure`** → memoize, parallelize, compile-time eval
2. **`!IO`** → safe for compile-time evaluation
3. **`!Alloc`** → safe for real-time audio, embedded, GPU
4. **`!Network`** → sandbox — capability security as types

`!Alloc` is the real-time holy grail. Rust CANNOT do this — `Vec::push` is
safe Rust and it allocates. In Lux, `!Alloc` propagates through the ENTIRE
transitive call graph. If any callee allocates, compile error.

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

This is the unification the user intuited: **there is no documentation
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
