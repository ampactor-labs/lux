# Lux → Ultimate Form

*Every annotation is a conversation. The more you tell the compiler, the more it does for you. No levels — a gradient. No punishment — illumination.*

---

## The Gradient

Discrete levels are an artifact of limited design. The real truth:

**Every piece of knowledge you give the compiler changes what it can prove.**

```lux
// You write nothing. The compiler infers everything silently.
fn f(x) = x + 1

// You write the effect. The compiler can now memoize.
fn f(x) = x + 1 with Pure

// You write a refinement. The compiler can now prove properties.
fn f(x: Positive) -> Positive = x + 1

// You write ownership. The compiler can now guarantee zero-allocation.
fn f(x: own Int) -> own Int with Pure, !Alloc = x + 1
```

Same function. Each annotation unlocks MORE. The compiler tells you what each one buys:

```
  fn f: (Int) -> Int with Pure
    → you could add: with Pure        (unlocks memoization, parallelization)
    → you could add: -> Int           (confirms your understanding, catches drift)
    → you could add: x: Positive      (proves output > 0, eliminates runtime check)
```

This is not a hint. It's the compiler showing you the gradient — here's where you are, here's what's above you, here's what you'd get.

---

## The Pipe: Lux's Central Idiom

The pipe operator `|>` isn't syntax sugar. It's the fundamental way computation flows in Lux. Every domain maps onto it:

```lux
// Data pipeline — effects accumulate through the chain
users
  |> filter(|u| u.active)                    // Pure
  |> map(|u| fetch_profile(u.id))            // + IO
  |> sort_by(|p| p.score)                    // Pure (doesn't add effects)
  |> take(10)                                // Pure

// DSP signal chain — !Alloc propagates through
input
  |> highpass(cutoff: 80.0)                  // !Alloc, Pure
  |> compress(ratio: 4.0)                    // !Alloc, Pure
  |> saturate(drive: 1.5)                    // !Alloc, Pure
  |> limit(ceiling: -0.1)                    // !Alloc, Pure

// ML computation graph — same syntax, different effects
data
  |> conv2d(32, kernel: 3)                   // Compute
  |> relu                                    // Pure
  |> dense(10)                               // Compute
  |> softmax                                 // Pure

// Compiler pipeline — Lux compiling itself
source
  |> lex                                     // Fail<LexError>
  |> parse                                   // Fail<ParseError>
  |> check                                   // Fail<TypeError>
  |> compile                                 // Pure
```

The pipe makes effects VISIBLE. You can SEE the computation flowing left-to-right and the effects accumulating. This is visual programming through text.

**Auto-currying** makes this ergonomic: `|> f(a, b)` means `f(x, a, b)` where `x` is the pipe input. No partial application boilerplate.

---

## Emergent Capabilities

These aren't planned features. They FALL OUT of the right foundations:

### From Effects + Pipes
Every pipe stage has its own effect. The compiler infers the total effect of the chain. Swap ANY stage and the compiler immediately tells you how the effect profile changed. This is **live architectural feedback** — you can see your system's dependency graph in the types.

### From Effects + Handlers
Testing without frameworks. Replace the handler, test anything:
```lux
// Production
handle app() { use RealDb(), use RealAuth() }
// Test — SAME code, no mocks, no DI framework
handle app() { use InMemoryDb(), use FakeAuth(user: "test") }
```

### From Pure + Pipes
Pure pipe stages auto-parallelize. `data |> map(pure_fn) |> filter(pure_fn)` can be split across cores. The compiler PROVED it's safe — no data races possible.

### From !Alloc + Ownership
Real-time guarantees. `fn audio_callback() with !Alloc` means the ENTIRE transitive call graph is proven allocation-free. Not a convention — a proof. Every audio programmer dreams of this.

### From Refinements + Types
Division by zero is a compile error. Buffer overflow is a compile error. Out-of-bounds indexing is a compile error. Not because of runtime checks — because the types PROVE it can't happen.

### From Why Engine + Everything
The compiler can explain ANY aspect of your program. Why is this Int? Because... (full reasoning chain). Why is this Pure? Because... (no operation in the call graph performs an effect). Why can this be parallelized? Because... (Pure + independent data).

The compiler has *complete* knowledge of the type and effect system — not heuristic, not approximate. It explains every inference with a full reasoning chain.

---

## The 10 Phases

### Phase 1: Self-Hosted Codegen
*Lux compiles Lux.*

The bytecode emitter in Lux. Takes parser AST, produces VM bytecode. Once this works, the Lux compiler compiles itself (on the Rust VM).

```lux
type Chunk = { code: List, constants: List, names: List, arity: Int }

fn compile_program(stmts) -> Chunk    // the whole pipeline
fn emit_expr(ctx, expr) -> Ctx        // ctx carries bytecode buffer + scope
fn emit_stmt(ctx, stmt) -> Ctx
```

**Design**: Threading pattern — `Ctx` carries mutable state (bytecode buffer, scope stack, constant pool, forward-jump patch list). Same pattern as the checker's `(env, subst, counter)`.

**Key detail**: The codegen must handle closures (upvalue tracking), match compilation (decision trees), and effect handlers (PushHandler/PopHandler). The self-hosted parser AST already captures all these constructs.

**Unlocks**: Every subsequent phase is written in and compiled by Lux.

---

### Phase 2: Why Engine
*Every inference has a reasoning chain.*

Extend `unify` and `infer_expr` to carry `Reason` alongside every type:

```lux
type Reason
  = FromLiteral(String)
  | FromOperator(String, Ty, Ty, Reason)
  | FromUnification(Ty, Ty, Reason)
  | FromCallArg(String, Int, Reason)
  | FromReturn(String, Reason)
  | FromAnnotation(String)
  | Because(List)
```

Display at any depth. The default is one-line: `x: Int`. Expand to see: `x: Int ← * requires Num, unified with Int from literal 2`. Full expansion: multi-step reasoning chain.

**Unlocks**: Debugging everything that follows. When the effect algebra gets confused, the Why Engine shows WHERE and WHY.

---

### Phase 3: Effect Tracking
*Prove purity. See effects flow.*

Extend the checker to infer `EffectRow` for every expression:

```lux
type EffectRow = Pure | Row(List, Option)  // effects + optional row variable

fn infer_expr(...) -> (Ty, EffectRow, Subst, Counter, Reason)
```

Row polymorphism: `map(f, xs)` has effect `E` where `f: a -> b with E`. The effect flows through.

Pipe chains accumulate effects: `a |> f |> g` has effects `Ef + Eg`.

**The gradient reveal**: Functions without `with` annotations get their effects inferred and displayed. Add `with Pure` to LOCK it — now the compiler enforces purity and unlocks optimizations.

**Unlocks**: Phase 4 (effect algebra).

---

### Phase 4: Effect Algebra
*!E, E-F, E&F. The four gates.*

```lux
type EffectConstraint
  = Has(String)           // must have
  | Not(String)           // !E — must not have
  | Sub(EffectRow, List)  // E - F
  | Inter(EffectRow, EffectRow)  // E & F
```

The four compilation gates emerge for free:

| Constraint | Gate | What the compiler does |
|-----------|------|----------------------|
| `Pure` | Memoization | Cache return values |
| `!IO` | Compile-time eval | Evaluate at build time |
| `!IO, !Alloc` | GPU compilation | Offload to GPU |
| `!Network` | Sandbox | Capability restriction as types |

**Unlocks**: Phase 5 (ownership — `!Alloc` needs effect algebra), Phase 7 (native backend uses gates for optimization).

---

### Phase 5: Ownership
*own, ref, gc. Borrow inference. Deterministic cleanup.*

Within function bodies: ALL ownership inferred. At module boundaries: annotate `own` or `ref`.

```lux
fn process(data: own Buffer) -> own Result = {
  let header = data.slice(0, 4)    // compiler: auto-borrow (used again)
  let body = data.split_at(4)      // compiler: auto-move (last use)
  transform(body)
}
```

The compiler builds a borrow graph. Conflicts are errors WITH EXPLANATIONS (Why Engine):

```
error: cannot borrow `data` — already moved
  WHY: data was moved on line 3 (split_at takes ownership)
       but line 2 borrows a slice that references data's memory
  FIX: reorder — slice after split, or clone the header
```

**Unlocks**: `!Alloc` has teeth. Phase 7 (native codegen emits drop/move instructions).

---

### Phase 6: Refinement Types
*Predicates verified at compile time. Zero-cost guarantees.*

```lux
type Byte = Int where 0 <= self && self <= 255
type NonEmpty<T> = List<T> where len(self) > 0
type Sample = Float where -1.0 <= self && self <= 1.0
```

SMT solver (Z3) handles decidable queries. `assert` as escape hatch. Verification dashboard tracks the ratio proven/asserted/unverified.

**The gradient**: Start with no refinements (dynamic). Add `assert` (runtime). Tighten to refinement types (compile-time). The code never changes — only the guarantees increase.

**Unlocks**: Phase 9 (synthesis uses refinements to narrow search).

---

### Phase 7: Native Backend
*Faster than C for effectful code.*

Two backends: Cranelift (dev speed) and LLVM (release optimization).

Effect-specific compilation:
- Tail-resumptive handlers (~85%): evidence passing → zero overhead
- Linear handlers: single-use CPS → one allocation
- Multi-shot: full continuation capture → heap allocation

**The performance thesis**: Lux beats dynamic dispatch for effectful code because the compiler KNOWS which handlers are tail-resumptive. Languages using `dyn Trait` or vtable dispatch can't — Lux generates direct calls with evidence passed in registers.

**Unlocks**: Production deployment, real-time audio, embedded systems.

---

### Phase 8: The Gradient System
*Not levels — a continuous gradient of guarantees.*

The compiler tracks what it knows about each function and applies ALL applicable optimizations:

| What the compiler knows | What it does |
|------------------------|-------------|
| Types inferred | Catch type errors, enable completion |
| Effects inferred | Track dependencies, show effect flow |
| `with Pure` declared | Memoize, parallelize, compile-time eval |
| `with !Alloc` declared | Verify heap-free, enable real-time |
| Ownership annotated | Deterministic cleanup, zero-copy |
| Refinements added | Prove properties, eliminate runtime checks |
| Full signature | Type-directed synthesis, formal verification |

The compiler shows you WHERE YOU ARE on the gradient and WHAT THE NEXT STEP UNLOCKS. Not nagging — illuminating.

**Unlocks**: Education without discrete level boundaries. Every programmer finds their natural position on the gradient.

---

### Phase 9: Type-Directed Synthesis
*Write the type. Get the code.*

For parametrically polymorphic types, the free theorem guarantees at most one implementation:

```lux
fn id : a -> a = ?           // generates: |x| x
fn const : a -> b -> a = ?   // generates: |x, _| x
fn flip : (a -> b -> c) -> (b -> a -> c) = ?  // generates: |f, b, a| f(a, b)
```

For monomorphic types with refinements, the SMT solver narrows the search:

```lux
fn clamp : (x: Int, lo: Int, hi: Int where lo <= hi) -> Int where lo <= result && result <= hi = ?
// generates: if x < lo { lo } else { if x > hi { hi } else { x } }
```

**This is mathematical**: not AI guessing — proof search. The generated code is PROVABLY the only correct implementation.

**Unlocks**: The ultimate expression of "compiler does it for you" — but with mathematical certainty, not statistical approximation.

---

### Phase 10: Full Self-Hosting
*Delete every .rs file.*

Bootstrap: Rust compiles Lux-stage0 → Lux-stage0 compiles Lux-stage1 → match? Done.

The result: a single `lux` binary that IS everything. Compiler, REPL, package manager, test runner, teaching system. Written in Lux. Compiled by itself.

The Rust codebase becomes historical.

---

## Why the Teaching Compiler Changes How You Code

| Traditional tooling | Lux's compiler |
|---------------------|---------------|
| Infers intent heuristically | **Knows** intent from types + effects |
| Generates boilerplate | No boilerplate to generate (inference) |
| Suggests optimizations | Applies them automatically (effect gates) |
| Debugs runtime errors | Prevents them (refinement types) |
| Requires separate test frameworks | Effects ARE tests (handler swap) |
| External documentation tools | Why Engine explains everything |
| Refactoring requires analysis | Types guarantee safe refactoring |

The teaching compiler makes developers **sovereign** over their code.
You understand everything because the compiler explains everything.

---

## The Vision, Condensed

A language where the pipe operator IS the signal chain, the type signature IS the documentation, the effect row IS the architecture diagram, the compiler IS the teacher, and the programmer IS sovereign.

No Rust. No scaffolding. Just light.
