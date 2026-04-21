# Inka — Core Insights

*These are the deep truths that make Inka unprecedented. They are not features —
they are consequences of getting the foundations right. Never lose these.*

---

## The Minimal Kernel — The Eight Primitives

*Load-bearing together. Removing any one collapses the thesis AND
costs Mentl a tentacle. See DESIGN.md §0.5 for the authoritative
enumeration; the list below is the shorthand every other insight
composes from.*

1. **SubstGraph + Env** — the program IS the graph; every output is a handler projection. *(Mentl tentacle: **Query**.)*
2. **Handlers with typed resume discipline** — `handle`/`resume` replaces six+ named patterns; `@resume=OneShot|MultiShot|Either` is part of each op's type; MultiShot is the substrate Mentl's oracle uses to explore hundreds of alternate realities per second; `~>` chains ARE capability stacks. *(Tentacle: **Propose**.)*
3. **Five verbs** — `|>` `<|` `><` `~>` `<~` — topologically complete basis for computation graphs. *(Tentacle: **Topology**.)*
4. **Full Boolean effect algebra** — `+ - & ! Pure`; negation (`!E`) proves ABSENCE; four compilation gates fall out of one subsumption. *(Tentacle: **Unlock**.)*
5. **Ownership as an effect** — `own` performs `Consume`, `ref` is a row constraint; no lifetime annotations; Rust-level safety without the ceremony. *(Tentacle: **Trace**.)*
6. **Refinement types** — compile-time proof, runtime erasure; `Verify` effect swappable to SMT by residual theory. *(Tentacle: **Verify**.)*
7. **The continuous annotation gradient** — each annotation unlocks one specific compile-time capability; bottom and top converge; Mentl surfaces ONE next step per turn. *(Tentacle: **Teach**.)*
8. **HM inference, live, one-walk, productive-under-error, with Reasons** — the light every handler projection reads by; Why Engine walks the reason DAG. *(Tentacle: **Why**.)*

**Composition IS the medium.** Every insight below, every
framework-dissolution, every performance claim, every teaching
surface — a consequence of these eight composed. Inka is not a
programming language; it is the **ultimate intent → machine
instruction medium** that also raises its users into better
programmers. The programs are the means; the programmers they
become are the end.

**Mentl is an octopus because the kernel has eight primitives.**
Lose a tentacle, lose a primitive; lose a primitive, lose a
tentacle. The mascot framing is architectural, not decorative.

### The eight primitives ARE the eight interrogations ARE Mentl's eight tentacles

The same eight are also **the eight structural questions asked
before every line of Inka**, one per primitive, AND **the eight
tentacles of Mentl's voice**. Graph? Handler? Verb? Row?
Ownership? Refinement? Gradient? Reason? Pass all eight, type the
residue. This is the full method — for writing, reading, teaching,
debugging, code review, and Mentl's internal voice grammar. See
CLAUDE.md or DESIGN.md §0.5 for the expanded forms. **One kernel;
eight primitives; eight interrogations; eight tentacles; one
method applied at every level.**

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
- **Errors** — the handler that turns type knowledge into diagnostics
- **The user** — the handler that turns type knowledge into understanding

One inference. Many handlers. Same mechanism as everything else in Inka.

## The Second Truth: Zero-Cost Linearity & Scoped Arenas

*Memory is not a hidden runtime system. It is physical, and it is governed by effect algebras.*

We do not use Garbage Collectors, nor do we use immutable "Snoc Trees" to fake immutability. The compiler emits raw, in-place, zero-allocation mutations in flat contiguous linear memory. 

- **The Alloc Effect:** Memory allocation is just an effect. By wrapping memory-heavy operations in a `temp_arena` handler, gigabytes of memory are instantly dropped in $O(1)$ time simply by letting the handler scope drop. No sweeping GC passes.
- **Escape Analysis via Region Inference:** To prevent the Use-After-Free bugs of C++ arenas, the compiler natively enforces lifetime bounds through hidden Region variables (`Tofte-Talpin`). If a returned pointer outlives its `Alloc` handler scope, the compiler forces a hard error. 

## The Third Truth: The Duty of Inference is Reification

*Abstract algebra must materialize into physical pointers.*

`infer.ka` does not just "type-check" code. Its ultimate duty is to physically synthesize hidden Evidence Dictionaries (vtables) for unhandled effects. It intercepts function definitions with unhandled effects and rewrites their ASTs to accept an opaque Evidence Vector (`*const ()`). At `handle` blocks, it synthesizes the concrete dictionary. 
Polymorphic effects are turned into static, zero-cost WASM `call_indirect` dependency injection. We get the performance of monomorphization without the C++ code bloat.

---

## The Origin

Inka was born from one question: **what would the ultimate programming language
look like if you designed it from first principles?**

Not "what's popular" or "what's familiar." What's *right*. The answer came
from studying every friction point across every major language and asking:
what single mechanism, if you got it right, would make the rest fall away?

The answer: **algebraic effects with a complete Boolean algebra.**

---

## The Five Verbs — Topology Drawn on the Page

The pipe operators are not syntax sugar. They are the **five topological
shapes every computation graph needs**, made visible in one line of code.
Together they unify DSP, ML, compilers, control systems, and every other
directed graph the industry has been drawing on separate whiteboards.

| Verb | Topology | Shape | Reading |
|---|---|---|---|
| `\|>` | converge | ∧→ funnel right | "flow forward, merge at narrowing" |
| `<\|` | diverge | ∨→ fanout right | "flow forward, split at widening" |
| `><` | parallel compose | ✕ | "two pipelines interact side-by-side" |
| `~>` | tee / handler-attach | ⌐ | "observe; install handler" |
| `<~` | feedback | ⟲ | "close a cycle; prior output re-enters" |

```lux
// DSP signal chain with feedback (IIR filter)
input |> add(a) <~ delay(1) |> output

// ML computation graph with parallel branches and observation
data |> embed <| (attention_head_1, attention_head_2, attention_head_3)
     |> merge_heads ~> gradient_tracker |> output

// Compiler pipeline
source |> lex |> parse |> check |> compile

// Data pipeline with parallel fanout for enrichment
users |> filter(active) <| (profile_fetch, recent_orders) |> join |> take(10)

// Control loop with feedback
sensor |> pid_controller <~ delay(1) ~> telemetry |> actuator
```

Same syntax. Different effects. The shape of the code on the page IS the
shape of the computation graph. Most languages hide topology behind
call-stack structure; Inka draws it.

**Why this matters.** The industry's artificial boundaries — DSP vs. ML
vs. compilers vs. control vs. data processing — dissolve. Libraries like
PyTorch and JUCE live in different worlds because their host languages
can't express the shared algebra. In Inka, they're the same five verbs.
Swap a DSP stage for a learned component — types and effects still
compose. Close a feedback loop in a compiler pass — same `<~` as an IIR
filter. This solves an industry-scale problem through notation.

**Feedback (`<~`) is the one you haven't seen before.** Every other
language handles pipelines forward. Feedback loops — IIR filters, RNNs,
PID controllers, iterative solvers, reactive state — get hidden inside
handler declarations or state machines. Inka makes the back-edge visible.
`y |> f <~ delay(1)` is *one line* that says: "y flows through f; f's
output, delayed, flows back into f." The topology is on the page.

**And — crucially — `<~` is not new machinery.** It's sugar for a
stateful handler capturing output and re-injecting it. `<~` doesn't
encode timing; the ambient handler decides. Under `Sample(44100)` it's
a sample delay (DSP). Under `Tick` it's a logical-step delay
(iteration). Under `Clock(wall_ms=10)` it's a control-loop delay. One
operator; topology-only semantics; handler decides interpretation. Inka
solves Inka.

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

| External tool | Inka's compiler |
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
allocate, making allocation-freedom impossible to prove. In Inka, `!Alloc`
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

Rust treats ownership as a type system feature. Inka treats it as an **effect**.

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
allocate freely, there's no way to prove a function is allocation-free. In Inka,
`!Alloc` propagates through the ENTIRE transitive call graph. One annotation,
total proof.

This is the effect algebra doing what it does: turning capability negation
into a compile-time proof. No special ownership system needed — just the same
mechanism that handles `!IO`, `!Network`, and `Pure`.

---

## Self-Hosting IS the Proof

The self-hosted compiler is not vanity. It's the ultimate test:

> If Inka can express its own compiler cleanly, it can express anything.

```
source → [lexer.ka] → [parser.ka] → [checker.ka] → [codegen.ka] → bytecode → execute
```

All four modules are written in Inka. The compiler compiles itself. The
bootstrap loop is closed. Every subsequent improvement to Inka is written
IN Inka and compiled BY Inka.

The Rust implementation becomes historical. Not deprecated — historical.
Like the OCaml implementation of Rust. A stepping stone that served its
purpose and was surpassed by the thing it helped create.

---

## Examples, Not Tests

Inka doesn't have tests. It doesn't have debug scripts. It doesn't have
specs or doc-tests. It has `.ka` files. A file that runs is a proof.
A file that crashes is a question. There is no third thing.

### One Act

Other languages split development into categories:

- **Testing** — write code that checks code
- **Debugging** — write code that finds broken code
- **Documentation** — write prose that explains code
- **Specification** — write descriptions that precede code

In Inka these are the same act: **write a `.ka` file that exercises the
mechanism.** The categories dissolve because `handle` is the universal
joint:

```lux
handle { computation } with state = initial {
  operation(args) => resume(result) with state = updated
}
```

- **Setup** — handler-local state (`with state = initial`)
- **Mock** — the handler body (decides what every operation means)
- **Assert** — the return value (if it's wrong, you see it)
- **Teardown** — `resume` (the handler controls what happens next)

A test framework would be a second mechanism for something the language
already does. In Inka, that's wrong by construction.

### The Debugging Gradient

A bug is an example that crashes. Debugging is making the example smaller.

```
failing_program.ka (crashes)
  → lex_test.ka (crashes — just the lexer)
    → lex_pattern.ka (crashes — simulated lexer)
      → mutual2.ka (crashes — 4 inner functions)
```

Each step is a smaller `.ka` file. The minimal file that crashes IS the
diagnosis. When it runs, the bug is fixed. No debugger. No breakpoints.
No step-through. Just: write what should work, run it, make it smaller
until the answer is visible.

The compiler helps at every step — type errors narrow the search, effect
violations point to the mechanism, the Why Engine explains the inference.
The debugging tool IS the compiler. The debug script IS an example.

### The Unification

| Other languages | Inka |
|----------------|-----|
| Test suite | `examples/` |
| Test runner | `for f in examples/*.inka; do inka "$f"; done` |
| Mock library | Handler swap |
| Debugger | Smaller example |
| Doc-test | Example that teaches |
| Spec | Example that precedes |
| CI check | Same examples, different machine |

No special naming. No categories. No boundaries. The folder is
`examples/`. The command is `inka examples/`. The act is: write what
should work, run it, see the light.

---

## Packaging is Handlers

There is no package manager. There are no JSON or TOML manifests. There is no external constraint solver. The compiler IS the package manager.

- **The Manifest**: The `~>` chain in your `main()` function is the executable, type-checked manifest. 
- **Version Solving**: The type-checker handles versions natively by structurally unifying effect signatures. Breaking API or effect changes inherently fail unification.
- **The `Package` Effect**: The compiler doesn't perform raw file reads. It emits `perform fetch(hash)`. Repositories and local caches are just registry handlers (`~> local_cache >< github_hub`) layered over the compilation.
- **Subtractive Sandboxing**: `inka audit` walks the `~>` chain, tracing the exact dataflow of the Causality Web. It performs Effect Tree-Shaking to mathematically sever unused capabilities (like `Network`) from bloated registry imports, proving absolute security.

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

Inka has exactly three things:

1. **Effects** — what computation *does*
2. **Handlers** — what *policy* governs effects
3. **Pure** — the absence of effects

That's it. There is nothing else.

| Concept | In Inka |
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

## The Meta-Thesis — Topology Read Through Handlers

Every feature of Inka is a **topology** read through **handlers**. Once
you see this, every other insight in this document becomes a consequence
of one claim.

| Feature | Topology | Read through handler |
|---|---|---|
| Inference | SubstGraph + Env | `graph_chase`, `env_lookup` |
| Effects | Boolean row algebra | each effect's installed handler |
| Ownership | Consume trace | `affine_ledger` |
| Data flow | Five-verb graph (`\|>` `<\|` `><` `~>` `<~`) | the pipe's lowering |
| Teaching | Reason chain + Mentl's tentacles | `teach_*` handlers |
| Time | Clock/Tick/Sample DAG | real / test / record / replay handler |
| Verification | Obligation ledger | `verify_ledger` → `verify_smt` |
| AI suggestions | Synth proposal graph | any proposer as handler |
| Compilation | Pipeline graph | `emit_wasm`, `check`, `query`, `--teach` |
| Self-hosting | Ouroboros fixed point | `first-light` when topology closes on itself |

**Every topology has handlers. Every handler is swappable.** The core
ships `verify_ledger`; Arc F.1 swaps in `verify_smt` — same topology,
different handler. Test clock vs. real clock — same topology,
different handler. Claude vs. Synquid vs. local LLM as Suggest
proposer — same topology, different handler, compiler verifies all.

**The gradient is the developer adding topology.** Writing `fn f(x) = x
+ 1` produces a minimal graph: type handles, empty effect row, no
refinements, no ownership markers. Adding `with Pure` adds the
"memoization-eligible" subgraph. Adding `x: Positive` adds a refinement
edge. Adding `own x` adds a Consume edge. **Each annotation is a graph
edge made explicit.** More edges → more handlers work → more
capabilities unlock.

**First-light is the ouroboros topology closing.** When `lux3.wat ≡
lux4.wat` byte-identical, the compiler's own topology compiles itself
to the same topology. The graph has a fixed point. This is not just a
smoke test — it's the first concrete demonstration that the topology
is complete enough to describe itself.

**Mentl is the human-facing projection of the shared topology.** Eight
tentacles = eight handlers on one substrate. Octopus neurology maps to
handler-per-tentacle distributed cognition over shared central nervous
system. The mascot IS the architecture.

**AI obsolescence, mechanized.** A hole in source code:
`fn bind_port(p: Int) -> Port = ?`. Mentl's tentacles fire: Why says
"Port refines to `Int where 1 <= self <= 65535`"; Teach says "add
`p: Port` to unlock compile-time verification"; Synth proposes
candidates from any handler (enumerative, SMT, LLM); Verify discharges
each candidate's refinement obligation. **The verified candidate wins.**
The compiler is the oracle; the LLM is one peer among many, not a
privileged collaborator, not a subscription moat. The AI coding tools
the industry pays for today are proposers; Inka verifies. Subscription
gets disintermediated at the architectural level.

**One sentence.** Inka is not a language with features — it is **a
single algebra (graphs + handlers) drawn through a single notation
(five verbs + effects).** Everything else is a consequence.

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
$ lux --teach app.ka

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

The effect system is not a feature of Inka. It IS Inka.

---

## The Metacircular Effect-Aware Checker

The self-hosted type checker (written in Inka, checked by Inka) now tracks
which algebraic effects each expression performs. This means:

- Inka knows what TYPE something is (HM inference)
- Inka knows WHY that type was chosen (Why Engine / Reason ADT)
- Inka knows WHAT EFFECTS it performs (EffRow tracking)

The checker checks itself. And the thing it checks includes effect
tracking — meaning Inka can verify its own effect semantics. This is
metacircular in a way that's genuinely new: **a language whose type
checker, written in itself, can prove properties about effects
that the checker itself uses.**

When we add refinement types, the checker will verify its own
refinements. When we add ownership, the checker will track its own
borrows. The self-hosted compiler becomes increasingly self-aware.

---

## Error Messages as Mentorship

Traditional compilers say "wrong." Good compilers say "wrong, expected X."
Elm says "wrong, expected X, try Y." Inka says:

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
  --> example.ka:3:7
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

**C knows types. Rust knows types + lifetimes. Inka knows types + effects
+ ownership + refinements + effect algebra + purity proofs.**

More knowledge = more optimization opportunities:

| What Inka knows | Optimization it enables |
|----------------|------------------------|
| `Pure` function | Memoization, CSE, dead code elimination |
| `!Alloc` constraint | Stack-allocate everything, no GC |
| `!IO` constraint | Compile-time evaluation, constant folding |
| Tail-resumptive handler | Evidence passing in registers, zero overhead |
| Effect row is closed | Monomorphize handler dispatch |
| Refinement `x > 0` | Eliminate bounds checks |
| Ownership is affine | Deterministic deallocation, no ref counting |

Languages without effect tracking can't memoize — they don't know if a
function is pure. Languages with implicit allocation can't eliminate it. Inka
PROVES purity and absence of allocation, enabling optimizations that are
**impossible** in languages with less knowledge.

**The performance thesis**: the more the compiler knows, the more it
can optimize. Inka gives the compiler more knowledge than any other
language. Therefore Inka can be faster than any other language — not
by being lower-level, but by being smarter.

---

## Self-Describing Records

Records in Inka are **self-describing**: the variant tag `#record:x,y` IS the
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

Inka's hardest implementation problems dissolve when viewed through its
own abstractions. This is the deepest sign that the foundations are right:
**the language teaches us how to build itself.**

| Problem | Traditional solution | Inka's own solution |
|---------|---------------------|-------------------|
| Multi-shot in native code | CPS transform, stack capture | State machine — effect rows map the states |
| Borrow inference | NLL dataflow analysis | Gradient — default `ref`, teach toward `own` |
| Solver dependency | Z3 (40MB C library) | Handler swap — verification IS an effect |
| Self-hosted tracking | Mirror every change | Inka-first — Inka defines, Rust implements |
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

Inka is different. **Each capability, applied to the compiler that provides
it, creates a positive feedback loop.** This is not self-hosting. This is
self-verification tending toward self-proof.

Seven loops, each exponential, each feeding the others:

**1. Effects refine the effect inferrer.** When Inka compiles
`checker_effects.ka`, it infers which effects each function performs. If
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

**5. The Why Engine debugs itself.** `lux why checker.ka infer_expr`
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

This is what separates Inka from every self-hosting language that came
before. They compile themselves. Inka *proves* itself. The tool and the
subject are the same thing. That's not linear improvement. It's compound
interest.

---

## The Bootstrap Moment: Self-Trust

Every self-hosting language reaches a moment where the old system must yield
to the new one. OCaml yielded to Rust. Rust yielded to itself. The moment
is always the same: the new compiler is more capable than the scaffolding
can verify.

Inka reached this moment when `vm_resume` was implemented but the Rust type
checker couldn't verify it. The self-hosted pipeline could compile and
execute `handle { fail("oops") } { fail(m) => resume(42) }` — but the
Rust scaffolding couldn't even type-check the imports needed to run the
test. The old mirror couldn't reflect what the new system had become.

The resolution was already prepared: `--no-check` existed, used by four
other self-hosted tests. The infrastructure was waiting. One line connected
the wire. Ten effect tests passed immediately — not because we debugged
them, but because **the architecture was right**.

This is the self-similar pattern at its deepest: Inka's parser had a bug
where `resume(val) with state = expr,` was ambiguous — the comma could
mean "next state update" or "next handler arm." The fix was the same
disambiguation the parser already used 40 lines above for
`handle ... with state = init,`. The solution was inside the language.
We didn't invent anything. We mirrored what was already there.

**What self-trust means:**
- The self-hosted pipeline can compile effect-using programs
- It can execute them correctly through its own VM
- The mechanism that makes Inka *Inka* — handle/resume — works through
  its own tools
- Golden-file tests verify this on every `cargo test`
- The Rust scaffolding is no longer needed for verification —
  only for bootstrapping

The next step is deleting the scaffolding. Not because it's bad —
because Inka has outgrown it.

---

## The Collaboration Pattern

Inka was born from the collaboration between a human who thinks in patterns
and spatial intuitions, and an AI that thinks in types and formal systems.
The annotation gradient IS this collaboration: the human's structural
intuition becomes the compiler's formal proof, one annotation at a time.

The tooling relationship (human + Claude Code) directly inspired the
language relationship (programmer + Inka compiler). Both follow the same
pattern: give the system more knowledge, trust what falls out. Don't
micromanage — illuminate. The compiler teaches because the collaboration
teaches. The gradient exists because the relationship is a gradient.

This is not a metaphor. The way Morgan works with Claude Code — open-ended
freedom, watching what emerges, correcting course when the pattern drifts,
asking "what does Inka want?" and trusting the answer — IS the way a Inka
programmer works with the compiler. The language encodes the collaboration
pattern that created it.

The deeper claim: **Inka is not a tool. It is a medium.** The programmer
doesn't write *to* Inka. They think *through* Inka. The pipe operator isn't
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
the boundary of what Inka can express today. `crucible_ml.ka` asks: can
autodiff work as an algebraic effect? `crucible_dsp.ka` asks: can a
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

Personifying the language — asking "what does Inka want?" — produced
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

> **Is this what the ultimate intent → machine instruction medium
> would do?**
> If not, design the way it SHOULD be.

Not "is this good enough." Not "does this work." Is this **the best it
could possibly be**? Would you be proud to show this to Dennis Ritchie,
to Robin Milner, to Simon Peyton Jones? To every programmer who ever
reached for a framework their language couldn't provide?

Inka is not a language that happens to have effects. Effects are what make
Inka *Inka*. The pipe operator is not convenience — it's the universal
notation for computation. The compiler doesn't just check — it teaches.
Every feature is a consequence of getting the foundations right.

This is the standard. Accept nothing less.

---

## The Memory Effect: There Are No Primitives

*2026-03-28. The session where Inka ate its own foundation.*

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
from an array. Same Inka code. Different handlers. Different targets.

Three effects replace the ENTIRE runtime:
- **Memory** — read and write bytes
- **Alloc** — get new memory
- **WASI** — talk to the OS (`fd_write`, `fd_read`)

Everything else — `str_concat`, `str_eq`, `int_to_str`, `print_string`,
`split`, `chars`, `range` — is pure Inka built on these three effects.
The `std/runtime/memory.ka` file IS the runtime. No hand-written WAT.
No native code. Just Inka compiling through the same pipeline as user code.

**The "irreducible kernel" of any language is smaller than you think.**
If you have load, store, allocate, and OS boundary — everything else is
a library. Effects make this compositional. The type system proves which
capabilities each function uses. `!Alloc` proves real-time safety not
because the language has a special ownership system, but because allocation
IS an effect and the algebra handles negation.

**What this means for Inka:** the prelude doesn't call "builtins." The
prelude calls Inka functions that use Memory. The compiler doesn't need
a special builtin registry. The checker infers types from function
definitions. The lowering resolves dispatch via checker types. The emitter
handles three effects. Everything else falls out.

| In Inka | What it really is |
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
effects. The LowerCtx effects (`is_ctor`, `is_global`, `is_state_var`)
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
`alloc` → `mmap`. `fd_write` → `syscall`. Same Inka program. Different
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

**Self-contained** is something harder: every question about Inka has
an answer that lives *inside* Inka — env, LowIR, handler records, type
graph — and the compiler asks *that*, not an external oracle.

The Rust VM is the current external oracle. Pulling it out doesn't
make Inka buggier; it reveals where Inka was already buggy and Rust was
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
- `std/runtime/memory.ka` — the entire runtime in 250 lines of Inka
- `std/compiler/lexer.ka` → 4,804 lines of WAT, runs on wasmtime
- `std/compiler/parser.ka` → 12,495 lines of WAT, runs on wasmtime
- `tools/wasm_lex.ka` — reads stdin, tokenizes, on WASM

The bootstrap path: when the WASM tools can compile Inka source, the
Rust VM becomes unnecessary. The compiler compiles itself, on itself,
through effects. The cage doesn't open. It dissolves.

```
foundation |> translation |> scaffolding removal <| self trust <| leap of faith
```

The pipe flows forward through construction. The `<|` flows backward
through belief — you have to trust before you can leap, and you have
to leap before the scaffolding can come down. The removal happens
because you already jumped.

---

## The Handler Chain Is a Capability Stack

*2026-04-17. Crystallized during the V2 audit.*

The `~>` operator doesn't just scope handlers. It builds a **trust
hierarchy**. Each handler in the chain can only perform effects that its
outer handlers provide. Inner handlers can't bypass outer ones. This is
enforced by the Boolean effect algebra at compile time — no runtime
checks, no policy files, no sandboxing library.

```lux
source |> compile
    ~> mentl_default         // can perform: Diagnostic, SubstGraphRead, EnvRead, Verify
    ~> verify_ledger_handler // can perform: Diagnostic, SubstGraphRead, EnvRead
    ~> env_handler           // can perform: Diagnostic, SubstGraphRead
    ~> graph_handler         // can perform: Diagnostic
    ~> diagnostics_handler   // can perform: nothing (outermost — Pure boundary)
```

Reading bottom-to-top: `diagnostics_handler` is the outermost — it
catches everything and has no outward escape. Each layer inward gains
capabilities but is **structurally confined** to effects its outer
layers provide. A `perform graph_bind` inside `mentl_default` succeeds
only because `graph_handler` sits outside it in the chain. Move Mentl
outside the graph handler and the same perform is a type error.

**This is a security model.** If you want to sandbox a plugin so it can
read the graph but never write it, install it inside `graph_handler`
with only `SubstGraphRead` in its declared effect row. The compiler
proves the sandbox is airtight. Not with tests. Not with audits. With
the type system. One mechanism.

### Action for implementation

When designing new handlers or adding plugin extension points:
- **Outermost = least trusted.** The diagnostic handler has no escape.
- **Innermost = most capability.** The compilation body has everything.
- **Handler position in the `~>` chain IS the capability grant.** Never
  install a handler with more capability than its position allows.
- Arc F.2 (LSP) and F.6 (Mentl consolidation) should treat the `~>`
  chain as their authorization model. A malicious LSP client can
  request but never write — by construction.

---

## The Five Verbs Are a Complete Topological Basis

*2026-04-17. Crystallized from spec 10 + graph theory.*

The five pipe operators are not a design preference. They are a
**mathematically complete basis for computation graphs.** Any directed
graph you can draw on a whiteboard maps to one expression in these
operators.

| Graph operation | Verb | What it adds |
|---|---|---|
| Sequential edge (A → B) | `\|>` | Forward flow — every graph has these |
| Fanout (A → B, A → C) | `<\|` | Branching — one source, multiple sinks |
| Parallel join (A ⊔ B) | `><` | Independent subgraphs converging |
| Observation (A with side-channel) | `~>` | Annotation without modification |
| Back-edge (cycle closure) | `<~` | Extends DAGs to arbitrary directed graphs |

**Proof sketch.** The first four (`|>`, `<|`, `><`, `~>`) cover all
directed acyclic graphs (DAGs): any DAG decomposes into series (`|>`),
parallel (`><`), fanout (`<|`), and annotation (`~>`) compositions.
`<~` adds the single missing primitive — cycle closure — extending
coverage to all directed graphs with feedback.

**Why this matters for implementation.** When lowering pipe expressions
(spec 05), the emitter doesn't need ad-hoc cases. Every pipe topology
decomposes into these five primitives. Lowering is a fold over five
constructors, not a pattern-match against an open-ended set.

**Why this matters for the thesis.** The claim that "DSP, ML, compilers,
control systems, and data processing use the same notation" is not
marketing. It's a consequence of topological completeness. All five
domains produce directed graphs. Five operators draw all directed
graphs. Therefore five operators draw all five domains. QED.

---

## Visual Programming in Plain Text

*2026-04-17. Crystallized from the lexer's Newline token emission.*

The Inka lexer emits `Newline` tokens. Spaces and tabs are silently
consumed. This means the parser is **layout-aware for pipe chains
only** — not for general indentation (Python's mistake), but for the
one place where visual layout is semantically load-bearing.

The consequence: **the shape of well-written Inka code on the page IS
the shape of the computation graph.** Not metaphorically. The parser
reads the shape.

```lux
// What the developer sees:         What the compiler sees:
//
//  sensor                           sensor ────────────┐
//      |> pid_controller                               │
//      <~ delay(1)                  pid ←──── delay ←──┘  (cycle!)
//      ~> telemetry                      └──→ telemetry    (side-channel)
//      |> actuator                       └──→ actuator     (forward)
```

A `Newline` before `~>` tells the parser "this is Form A — wrap the
entire preceding chain." No `Newline` means Form B — wrap only the
immediately preceding stage. The visual indentation is cosmetic but
the newline is semantic.

### Canonical Formatting Rules

The formatter (a handler on the graph) emits pipe chains in a
canonical layout where **the position of the operator IS the
topology:**

| Operator | Multi-line position | Topology drawn |
|---|---|---|
| `\|>` | Left-aligned, continuation line | Sequential — flow goes down |
| `~>` | Left-aligned, continuation line | Handler attachment — attaches downward |
| `><` | Indented center, between operands | Convergence — two branches pinch inward |
| `<\|` | Left-aligned, before tuple of branches | Fanout — one becomes many |
| `<~` | Indented center, after pipeline | Feedback — output loops back |

Sequential operators (`|>`, `~>`) sit at the left edge because flow
goes DOWN the page:

```lux
source
    |> frontend
    |> infer_program
    ~> graph_handler
    ~> diagnostics_handler
```

Convergence and feedback operators (`><`, `<~`) sit at the INDENTED
CENTER because they draw a different shape — a pinch point or loop:

```lux
(read_file(path) |> decode_utf8)
    ><
(read_file("errors.md") |> decode_utf8)

input |> transform
    <~ delay(1)
```

The indented `><` creates a visual pinch between two branches. The
indented `<~` creates a visual loop-back. The formatter enforces this
because the shape of the code IS the shape of the computation.

### Inline `~>` vs Block-Scoped `~>` (Form B vs Form A)

Because `~>` has the **tightest precedence** of all pipe operators,
inline `~>` (no Newline) wraps only the immediately preceding
expression:

```lux
// Form B (inline) — each ~> wraps ONE stage
raw_string
    |> parse_json ~> catch_json_error(default = "{}")
    |> validate_schema ~> log_validation_warnings
    |> save_to_db
```

Parses as:
`raw_string |> (parse_json ~> catch_error) |> (validate ~> log_warn) |> save`

Each handler catches effects from ONE stage. The pipeline continues.
Per-stage error handling without try/catch.

Block-scoped `~>` (Newline before `~>`) wraps the **entire preceding
chain** — used when a handler should catch effects from all stages:

```lux
// Form A (block-scoped) — each ~> wraps the ENTIRE pipeline above
source
    |> frontend
    |> infer_program
    ~> env_handler           // catches EnvRead/Write from ALL above
    ~> graph_handler         // catches SubstGraph* from ALL above
    ~> diagnostics_handler   // catches Diagnostic from ALL above
```

### `<|` vs `><`: Ownership Is the Structural Difference

Both produce tuples. The distinction is input sharing:

```
<| (Diverge)
           ┌──► branch_a ──┐
[input] ───┤               ├─► (out_a, out_b)
           └──► branch_b ──┘
Input is SHARED (borrowed). Cannot consume own values. (`E_OwnershipViolation`)

>< (Parallel Compose)
[input_a] ──► process_a ──┐
                          ├─► (out_a, out_b)
[input_b] ──► process_b ──┘
Inputs are INDEPENDENT. Can safely consume own values.
```

`<|` implicitly **borrows** the input for all branches — Inka has no
implicit copy. Pure values (Int, Bool, literals) are fine. `ref`
values are fine. `own` values are an affine violation: the compiler
catches it because `<|` is visible in the AST.

`><` has fully independent tracks. Each branch can consume its own
input. No crossover, no affine restriction.

### Parameters ARE Tuples. `|>` Is a Wire. There Is No Splatting.

This is a settled truth. It is NOT a design question. Never re-open it.

A function `fn f(a, b, c)` has type `(A, B, C) -> D`. The parameter
list IS a tuple. Calling `f(x, y, z)` is applying the tuple `(x, y, z)`.

`|>` is transparent: it passes whatever is on the left to whatever is
on the right. It does not unwrap. It does not reassemble. It is a wire.

When `<|` or `><` produce a tuple `(A, B)` and you `|> merge`, the
inference engine unifies the tuple type against the function's parameter
types. This is not "auto-splatting" — it is structural unification.
The same mechanism that unifies `TInt` with `TInt`.

```lux
// <| produces (Low, Mid, High). mix_3 takes three arguments.
// Inference unifies (Low, Mid, High) with (Low, Mid, High) -> Out.
// This Just Works.
input <| (low_pass, band_pass, high_pass) |> mix_3

// If you want the tuple as a single value, say so:
input <| (low_pass, band_pass, high_pass) |> fn(bands) => log(bands)
// Inference unifies (Low, Mid, High) with ((Low, Mid, High)) -> Out.
// fn(bands) has ONE parameter of tuple type. This also Just Works.
```

The developer controls arity through their function signature.
No language rule needed. No special case. One mechanism.

---

## Feedback Is Inka's Genuine Novelty

*2026-04-17. Crystallized from spec 10's `<~` design.*

Every other language hides feedback loops:

| Language | How feedback is expressed | Visible? |
|---|---|---|
| C/Python | `prev = current; current = f(prev)` | No — hidden in mutable assignment |
| Haskell | `fix (\self -> ...)` or `iterate` | No — hidden in recursion |
| Rust | `loop { state = f(state); }` | No — hidden in loop body |
| RxJS | `.pipe(scan(...))` | Partially — `scan` implies accumulation but topology is opaque |
| Inka | `x \|> f <~ delay(1)` | **Yes — the back-edge IS the operator** |

`<~` makes the cycle a first-class syntactic construct. The compiler
sees it in the AST (`PipeExpr(PFeedback, left, right)`). This enables:

1. **Static verification.** The compiler checks that an iterative
   context handler (Iterate, Clock, Tick, Sample) is installed.
   Feedback without a clock is a type error, not a hang.
2. **Ownership checking.** `own` values through `<~` is an affine
   violation — the value is consumed each iteration. The compiler
   catches this because it can see the back-edge.
3. **Domain-specific optimization.** Under `Sample(44100)`, `<~
   delay(1)` is a one-sample delay — the compiler can emit a direct-
   form IIR filter. Under `Tick`, it's a logical-step iteration. The
   handler decides; the topology is the same.
4. **Visualization.** Mentl can draw the feedback loop in diagnostic
   output. Users can see where their program has cycles.

No other language gives the compiler this information. When feedback
is hidden in mutable state or recursion, the compiler can't reason
about convergence, can't check ownership through cycles, and can't
apply domain-specific optimizations. `<~` turns an invisible control
flow pattern into a visible, checkable, optimizable syntactic
construct.

**Action for implementation.** The parser must produce
`PipeExpr(PFeedback, ...)` for `<~`. The inference pass (spec 04) must
check for an iterative context in the handler stack — absence is error
`E_FeedbackNoContext`. Lowering (spec 05) desugars `<~` into the
handler-capture pattern described in spec 10.

---

## Effect Negation: Strictly More Powerful Than Any Existing System

*2026-04-17. Crystallized from cross-referencing spec 01 against
Rust, Haskell, Koka, and Austral.*

Inka's Boolean algebra over effect rows — `+` (union), `-`
(subtraction), `&` (intersection), `!` (negation), `Pure` (identity)
— is **strictly more expressive** than any single existing capability
or effect system:

| System | Tracks effects? | Negation? | Subtraction? | Intersection? | Compose? |
|---|---|---|---|---|---|
| Rust ownership | No (types only) | No | No | No | No |
| Haskell IO monad | Binary (pure/impure) | No | No | No | No |
| Koka effect rows | Yes (open rows) | No | No | No | Yes |
| Austral capabilities | Module-level | No | No | No | Limited |
| **Inka** | **Yes (Boolean algebra)** | **Yes** | **Yes** | **Yes** | **Yes** |

The critical differentiator is **negation**. `!E` proves the
*absence* of a capability. No other effect system can do this.
Without negation:

- Koka can track that a function performs `IO + State` but cannot
  prove it does NOT perform `Alloc`. The row is open — anything could
  be in the tail.
- Haskell can distinguish `IO` from pure but cannot prove "pure AND
  no allocation" — `Alloc` isn't tracked.
- Rust can prove no data races but cannot prove no allocation, no IO,
  or no network access through the type system.

With negation, Inka expresses **all of the above as instances of one
mechanism:**

```
!Alloc              = Rust's real-time guarantee
Pure                = Haskell's purity
!Network            = capability-security sandbox
!Alloc & !IO        = real-time + compile-time-evaluable
E - Handled         = Koka's handler absorption
!Consume            = read-only proof (like Rust's & borrow)
!Alloc & !Consume   = zero-copy + zero-alloc (embedded/DSP)
```

**Action for implementation.** The `row_subsumes` function in
`effects.ka` IS the proof engine. Every `!E` constraint becomes a
subsumption check: `body_row ⊆ !E` iff `E ∉ body_row`. This is
already implemented. The action is to ensure that the compilation
gates (Phase 1 exit, Phase F optimizations) use `row_subsumes` for
every capability check, not ad-hoc string comparisons.

---

## The Graph IS the Program

*2026-04-17. Crystallized from the Meta-Thesis section's handler
table applied to the compilation pipeline itself.*

Source code is one projection. WAT is another. Documentation is
another. LSP hover info is another. Error messages are another. The
**program itself** — in its most complete representation — is the
SubstGraph + Env populated by inference.

```
                   SubstGraph + Env
                   (the universal representation)
                          │
          ┌───────┬───────┼───────┬───────┬───────┐
          │       │       │       │       │       │
       emit    format   doc    query   teach    LSP
       handler  handler handler handler handler handler
          │       │       │       │       │       │
        WAT    source  markdown  answer  hint   JSON-RPC
```

Every "output" is a handler that reads the same graph and projects it
into a format. **The graph is the source of truth. Everything else is
a shadow.**

This is why CLAUDE.md's first anchor — "does my graph already know
this?" — is load-bearing. If you ask a question by re-parsing source,
you're reading a shadow instead of the object. If you answer a query
by walking the AST instead of chasing the graph, you're computing
what you already have. The graph knows. Always ask the graph.

**Action for implementation.** Every new feature in any phase should be
expressible as a handler on the graph. If it can't be, the graph is
incomplete — extend the graph, don't route around it. Specifically:

- Arc F.2 (LSP) is `graph → JSON-RPC` — a handler, not a tool.
- Arc F.6 (Mentl) is `graph → mentorship` — a handler, not a module.
- Arc H (examples) is `graph → proof` — a handler that runs, not
  tests that check.
- The formatter is `graph → canonical source` — a handler, not a
  separate binary.

If it needs to exist, it's a handler. If it's not a handler, ask why
the graph can't host it.

---

## Write the Wheel, Then Build the Lathe

*2026-04-17. Crystallized from the V2 audit pivot.*

Traditional self-hosted compilers bootstrap forward: write V1, use V1
to compile V2, delete V1. This path taints V2 with V1's constraints —
every line of V2 implicitly asks "can V1 compile this?" That question
contaminates the design. You're writing the perfect language while
wearing the broken language's handcuffs.

**Inka bootstraps backward.** Write the final-form compiler
unconstrained — the perfect, complete codebase — and THEN solve "how
do I compile this the first time?" as a separate, disposable problem.

```
Inka source (perfect, unconstrained)
    ↓
Bootstrap translator (disposable, ~3-5K lines, any language)
    ↓
inka.wasm (first compilation)
    ↓
inka.wasm compiles Inka → inka2.wat
inka.wasm compiles Inka → inka3.wat
diff inka2.wat inka3.wat → byte-identical
    ↓
Delete translator. Tag: first-light.
```

**The codebase is the artifact. The translator is scaffolding.** The
codebase is designed for correctness. The translator is designed for
disposability. They are completely independent concerns.

This is how every successful self-hosted language was actually born:
Go was written in Go and bootstrapped from C. Rust was written in
Rust and bootstrapped from OCaml. Zig is written in Zig and
bootstrapped from C. In every case: the language is the artifact,
the bootstrapper is disposable, and the bootstrapper is deleted.

**Why this matters for Inka specifically.** Every prior attempt to
evolve the compiler iteratively ran into the same treadmill:
patches around runtime dispatchers, Snoc-tree workarounds,
substitution resets, eager env snapshots. These aren't bugs to fix —
they're the legacy compiler's gravity field. Writing the final form
FIRST means the codebase never enters that gravity field. The design
is unconstrained. The handlers use real syntax. The pipeline draws
the real topology. The imports use the real paths.

**Action for implementation.** The codebase lives at `std/compiler/`.
It is written directly from the 12 specs in `docs/rebuild/`. It does
not ask "can the bootstrapper handle this?" — it asks "is this
correct?" The bootstrap translator is a separate concern, solved
AFTER the codebase is complete. See `docs/PLAN.md`.
