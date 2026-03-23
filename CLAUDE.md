# Lux — The Language of Light

## READ THIS FIRST — What Lux IS

Lux is a **thesis language**. The thesis: if you build the right foundations
— algebraic effects, refinement types, ownership inference, and row
polymorphism — most of what programmers manually annotate today becomes
*inferable*. You get Rust-level safety with near-Python concision. Not by
being sloppy, but by being smarter about inference.

**The gap Lux closes:** between what a programmer *means* and what they're
*forced to write*. "This reads a file and might fail" becomes four lines of
ceremony in Rust (async, borrowing, error boxing, lifetimes). In Lux the
effect system infers all of it.

**One mechanism replaces six.** Exceptions, state, generators, async,
dependency injection, backtracking — all `handle`/`resume`. An `effect`
declares operations. A handler provides their semantics. The `resume`
continuation gives the handler control over what happens next. Zero special
syntax. Handler-local state (`with` clause) gives handlers mutable bindings
that evolve across resume calls.

**The effect algebra** — no other language has this. A complete Boolean
algebra over capabilities:

| Operator | Meaning | Example |
|----------|---------|---------|
| `E + F` | Union | `IO + State` |
| `E - F` | Subtraction | `E - Mutate` |
| `E & F` | Intersection | `E1 & E2` |
| `!E` | Negation | `!IO`, `!Alloc` |
| `Pure` | Empty set | `fn pure() -> Int` |

Koka has `+` via row polymorphism. Lux has the full algebra.

### Emergent Capabilities — Consequences, Not Features

These are not planned features. They fall out of the interaction between
effects, refinements, and ownership. This is the core insight:

- **`!Alloc` proves real-time safety.** Falls out of effect negation for
  free. Rust *cannot* do this — `Vec::push` is safe Rust and it allocates.
  In Lux, `!Alloc` propagates through the entire call chain. If any
  transitive callee allocates, the constraint fails at compile time.

- **Auto-parallelization.** Pure functions (`!Everything`) can be executed
  in parallel — the effect system proves it's safe. No annotations needed.

- **GPU compilation gate.** `!IO, !Alloc` functions can be offloaded to
  GPU. The compiler knows because the algebra proves it.

- **Capability security IS effect restriction.** `!Network` means provably
  no network access — enforced by the type system, not a runtime sandbox.
  A plugin with `with Compute, Log` literally cannot perform I/O.

- **Testing without a framework.** You don't mock, you `handle`. Swap the
  production handler for a test handler. Same code, different semantics.
  The type system guarantees the handler satisfies the effect signature.

- **"More performant than C" is a real claim.** Not because the runtime is
  faster, but because the type system can prove things that enable
  optimizations no manually-disciplined language can match: provable purity
  enables compile-time evaluation, memoization, and dead code elimination
  that unsafe languages must conservatively skip.

### Refinement Types

Types with predicates, verified at compile time by Z3, erased at runtime:

```lux
type Sample = Float where -1.0 <= self <= 1.0    // compiler PROVES audio doesn't clip
type NonEmpty<T> = List<T> where self.len() > 0   // head on empty list is a compile error
type Port = Int where 1 <= self <= 65535
```

Gradual verification: `assert` as runtime fallback, verification dashboard
tracks strictness score toward 100%.

### Ownership as a Menu

Not GC-everything or own-everything. A real menu: `own` (affine, zero-cost,
deterministic cleanup), `gc` (shared, collected), `rc` (ref-counted). Borrow
inference within function bodies — programmers never write `&` or lifetime
annotations inside functions. Explicit only at module boundaries.

### The Gradient (not discrete levels)

Every annotation you add changes what the compiler knows, and what it
knows determines what it can do for you. Write `fn f(x) = x + 1` — the
compiler infers `(Int) -> Int with Pure`. Add `with Pure` — the compiler
can now memoize, parallelize, evaluate at compile time. Add a refinement
type — the compiler proves properties. There are no "levels" — there's
just MORE KNOWLEDGE flowing to the compiler. The compiler's power scales
continuously with how much you tell it.

### What This Means for Development

Every decision in this project serves the thesis. When choosing between
approaches, ask: does this prove the language is sufficient for its own
expression? Migrating Rust builtins to pure Lux proves sufficiency.
Self-hosting the stdlib proves the language works. The Rust prototype is
scaffolding — every line of Rust is debt to be repaid in Lux.

> Full manifesto: `docs/DESIGN.md` (971 lines). Read it before proposing
> architectural changes or new language features.

## Throughline

Lux is the connective tissue between all projects. The effect system IS
the hourglass: distributed effects converge to the `handle{}` block (pinch
point), then `resume(result)` radiates new state.

**Kernel Pattern:** `handle { computation }` (pure computation) →
handler-local state (configuration) → `resume(result)` (interface)

**Cross-Project:** `!Alloc` = sonido no_std; pipe operator = signal chain
DSL; effect handlers = flowpilot safety gates; mock handlers = forge test
isolation

**DSP Connection:**
- Pipe operator `|>` IS a signal chain: `input |> highpass(80) |> compress(4.0) |> limit(-0.1)`
- Refinement types (Phase 10): `type Sample = Float where -1.0 <= self <= 1.0` proves audio bounds
- `!Alloc` effect negation (Phase 9): compiler proves real-time safety, replacing sonido's manual no_std discipline
- Effect handlers = audio backend adaptation: `handle dsp_graph() { use CoreAudioHandler(48000, 256) }`

**ML Connection** (spec: `docs/specs/lux-ml-design.md`):
- ML framework as pure Lux library exercising all 10 mechanisms simultaneously
- Autodiff as Compute effect handler (model doesn't know about gradients)
- `!Alloc` inference deploys to Daisy Seed; `!Random` proves determinism
- Multi-shot continuations = hyperparameter search; handler-local state = optimizer state
- DSP and ML compose identically through `|>` — interchangeable, not just composable
- Demo target: keyword recognition for escape room on embedded hardware
- ML is the throughline connecting Phases 7-12 to a concrete demanding workload

## Build / Run / Test
- `cargo run -- <file.lux>` — run a program (teaching output enabled by default)
- `cargo run -- --quiet <file.lux>` — run without teaching output
- `cargo run` — start REPL
- `cargo check` — type check the compiler
- `cargo clippy` — lint (zero warnings policy)
- `cargo fmt --check` — format check
- `cargo test` — run all tests (36 type checker + golden-file tests)
- `for f in examples/*.lux; do cargo run --quiet -- --quiet "$f"; done` — run all examples

## Architecture

**Rust prototype (temporary scaffolding):**
```
source → lex → parse → check → compile → VM
```
Pipeline: `lexer.rs` → `parser/` → `checker/` → `compiler/` → `vm/`
Shared types: `token.rs`, `ast.rs`, `types.rs`, `error.rs`
Frontend: `main.rs` (CLI), `repl.rs` (VM-backed REPL), `lib.rs` (prelude loader)

**Self-hosted compiler (Lux-in-Lux, running on the Rust VM):**
```
source → [lexer.lux] → [parser.lux] → [checker.lux] → [codegen.lux] → bytecode
```
All four components working. The self-hosted compiler can parse, type-check,
and emit bytecode for Lux programs. See `std/compiler/`.

Standard library: `std/prelude.lux`, `std/test.lux`, `std/types.lux`, `std/dsp/`, `std/ml/`

## Key Files (Rust prototype)

| File | Owns | Survives self-hosting? |
|------|------|----------------------|
| `src/token.rs` | Token types, Span | Rewritten in Lux |
| `src/lexer.rs` | Tokenization, string interpolation | Rewritten in Lux |
| `src/ast.rs` | AST nodes, patterns, type expressions | Rewritten in Lux |
| `src/parser/` | Recursive descent, Pratt precedence climbing | Rewritten in Lux |
| `src/types.rs` | Internal types, row-polymorphic effects, ADT defs | Rewritten in Lux |
| `src/checker/` | HM inference, effect tracking, exhaustive match, trait resolution | Rewritten in Lux |
| `src/compiler/` | Bytecode compiler (expressions, effects, patterns) | Rewritten in Lux |
| `src/vm/` | Stack-based VM (execution, effects, builtins) | Rewritten in Lux |
| `src/error.rs` | Error types, source-context formatting, teaching hints | Rewritten in Lux |
| `src/loader.rs` | Module import resolution, cycle detection | Rewritten in Lux |
| `std/compiler/lexer.lux` | Self-hosted tokenizer | **YES — Lux forever** |
| `std/compiler/parser.lux` | Self-hosted recursive descent parser (ADT-based AST) | **YES — Lux forever** |
| `std/compiler/checker.lux` | Self-hosted HM type checker with Why Engine (Reason trees on every inference) | **YES — Lux forever** |
| `std/compiler/codegen.lux` | Self-hosted bytecode emitter + disassembler | **YES — Lux forever** |
| `std/prelude.lux` | Self-hosted stdlib (38 functions: map, filter, fold, sort, etc.) | **YES — Lux forever** |
| `std/test.lux` | Native test framework (assert_eq, run_tests) | **YES — Lux forever** |
| `std/types.lux` | Option/Result ADTs | **YES — Lux forever** |
| `std/ml/` | Tensor ops, autodiff via Compute effect | **YES — Lux forever** |
| `std/dsp/` | DSP effects, processor library, spectral analysis | **YES — Lux forever** |
| `examples/*.lux` | Language examples and test cases | **YES — Lux forever** |
| `tests/type_tests.rs` | Unit tests for type checker (36 tests) | Rewritten in Lux |
| `tests/examples.rs` | Golden-file integration tests | Rewritten in Lux |

## Effect System — Syntax Reference

```lux
effect Fail { fail(msg: String) -> Never }
effect State { get() -> Int, set(val: Int) -> () }

// Declare what you need
fn increment() -> () with State { set(get() + 1) }

// Caller decides how to provide it
handle { increment(); increment(); get() } with state = 0 {
  get() => resume(state),
  set(v) => resume(()) with state = v,
}
// => 2

// Let destructuring (tuple, nested, wildcard)
let (a, b) = (1, 2)
let (out, recorded_tape) = handle { forward(model, x) } with tape = [] { ... }
let (_, second) = some_tuple

// Handler composition — named, reusable handlers
handler compute_forward {
  forward_mat_vec_mul(w, xv) => resume(mat_vec_mul(w, xv)),
  forward_vec_add(a, b) => resume(vec_add(a, b)),
}

// Bare handler reference (inference = one-liner)
handle { forward(model, x) } with compute_forward

// Handler inheritance
handler logging_compute: compute_forward {
  forward_mat_vec_mul(w, xv) => { println("mul"); resume(mat_vec_mul(w, xv)) },
}

// Override clauses inline
handle { body } with compute_forward { forward_relu(xs) => resume(relu_vec(xs)) }

// Effect negation — compile-time capability proofs
fn process(x: Int) -> Int with !Alloc { x * 2 }    // provably no allocation
fn sandbox(x: Int) -> Int with Log, !Network { ... } // can log, provably no network
fn pure_add(a: Int, b: Int) -> Int with Pure { a + b } // provably no effects at all

// Effect subtraction — capability removal (same as negation, reads as transformation)
fn safe_v1(x: Float) -> Float with DSP, !Network, !Alloc { ... } // traditional negation
fn safe_v2(x: Float) -> Float with DSP - Network - Alloc { ... }  // subtraction syntax
// Both are equivalent — same constraints, different emphasis
```

## VM Internals

> These are implementation details of the bytecode VM.
> They will be replaced when self-hosting or Cranelift codegen lands.

- Stack-based execution with `VmValue` enum (Int, Float, Bool, String, List, Closure, etc.)
- `FnProto` for compiled function prototypes, `Closure` for captured upvalues
- `HandlerFrame` stack for effect dispatch
- Evidence-passing for direct handler dispatch (bypass handler stack search)
- Tail-resumptive fast-path: skips continuation capture for `resume(pure_expr)` handlers
- `BundledClosure` for passing effect-requiring functions as values

## Phase History

| Phase | What | Commit |
|-------|------|--------|
| 1 | MVP: lexer, parser, checker, interpreter, REPL | 87d69ed |
| 2 | Strings, loops, tuples, match guards, error formatting | 2f5f88a |
| 3 | Row-polymorphic effects, generators, traits, 5 examples | ce9fc26 |
| 4 | Generics, stdlib prelude, TCO, Arc environments | 1de80df |
| 5 | Stateful effect handlers (handler-local state) | 1985aad |
| 6A | Named record fields, list patterns, or-patterns | HEAD |
| 6B | Multi-shot continuations via replay-based re-evaluation | HEAD |
| 6C | Bytecode VM, module system, VM parity (15/15 examples) | 5787bb1..d933893 |
| 6C+ | Pipe-aware calls, prelude expansion, exhaustive match warnings, assert | ffb8ae2..a23cbf9 |
| 4 | Stdlib migration: sort/enumerate/min/max/clamp/flat_map/unique/words/lines to pure Lux; removed 10 shadowed Rust builtins | HEAD |
| ML | ML framework: autodiff via effects, XOR trains to convergence. Thesis proven. | HEAD |
| ML+ | Parser newline-aware postfix, checker numeric inference (no more `: Float` ceremony) | HEAD |
| 7A | Handler state as return value — eliminates `get_tape()` anti-pattern. VM pattern match stack fix. | b33d1ee |
| 7A.5 | Let destructuring | `let (a, b) = expr` — tuple/list/wildcard/record patterns in let bindings. 13 match→let conversions across examples. | HEAD |
| 7C | Handler composition | `handler` top-level item, bare handler ref (`with handler_name`), inheritance (`: base`), `use` clause. XOR predict becomes one-liner. | HEAD |
| 7B | Tail-resumptive fast-path — VM skips continuation capture for `resume(pure_expr)` handlers. Compiler detection, Resume opcode routing. | 1ec1d77 |
| 7+ | Evidence-passing (local) — direct handler dispatch for evidence-eligible ops. Compiler classifies handlers, emits PushEvidence/PerformEvidence. VM mini-loop for synchronous handler call. 12 of 19 examples use evidence path; XOR gets 4024 evidence dispatches. | HEAD |
| 8A | Effect algebra (negation) — `!Effect` and `Pure` constraints in function signatures. Parser: `!Name` syntax. Checker: validates body effects against negation constraints. Purely compile-time, zero runtime cost. | HEAD |
| 8A-DSP | Effect-algebraic DSP framework — std/dsp/ library, pipe operator first usage, four-mode proof | HEAD |
| 8B | Effect subtraction syntax `E - F` in annotations — desugars to negation constraint. Same semantics as `E, !F` but reads as capability removal. Enables readable sandbox patterns. Generic subtraction (row variables) deferred to Phase 9+. | HEAD |
| 8C | Teaching compiler (`--teach`) — surfaces inferred types/effects, suggests annotations that unlock guarantees. Friendly type vars (a, b, c), import boundary tracking, purity/effect discovery. Progressive levels foundation. | HEAD |
| 8D | Evidence-passing for higher-order functions — checker adds effect routing for function-typed Var refs, VM BundledClosure allocates extra locals, BundleEvidence opcode decoder fix. `dsp_sandbox` passes, removed from skip list. | HEAD |
| 9A | Self-hosted lexer (`std/compiler/lexer.lux`) — tokenizer written in Lux generating Token ADTs. | HEAD |
| 9B | Self-hosted parser (`std/compiler/parser.lux`) — ADT-based recursive descent parser in Lux. Handles expressions, let bindings, fn declarations, if/else, match, lists, tuples, pipes, blocks. | HEAD |
| 9C | Self-hosted type checker (`std/compiler/checker.lux`) — HM type inference with unification, occurs check, and constraint propagation. Infers Int, String, Bool, List<T>, function types. | HEAD |
| 9D | Self-hosted codegen (`std/compiler/codegen.lux`) — bytecode emitter producing correct opcodes for all core constructs + full disassembler. Lux compiles Lux. | 81b8ed7 |
| 9E | Why Engine (`std/compiler/checker.lux`) — every type inference carries a Reason ADT tree. 14 reason variants. `check_and_explain(source, name, depth)` explains any binding at any depth. The compiler teaches, not just checks. | 3b2eae4 |

## Roadmap

> Full roadmap: `docs/ROADMAP.md` (10 phases to ultimate Lux)

**Completed:** Phases 1-8D (VM, effects, evidence passing, effect algebra, teaching compiler)

**Current:** Self-hosted compiler pipeline (lexer → parser → checker → codegen) ALL working in Lux.

**Next 10 Phases** (see ROADMAP.md for full details):

| Phase | What |
|-------|------|
| 1 | Self-hosted codegen (**DONE**) |
| 2 | Why Engine — reasoning chains on every inference |
| 3 | Effect tracking — Pure proofs, effect rows |
| 4 | Effect algebra — !E, E-F, E&F, compilation gates |
| 5 | Ownership — own/ref/gc, borrow inference |
| 6 | Refinement types — Z3-backed compile-time predicates |
| 7 | Native backend — Cranelift (dev) + LLVM (release) |
| 8 | Gradient system — continuous annotation→guarantee curve |
| 9 | Type-directed synthesis — write the type, get the code |
| 10 | Full self-hosting — delete every .rs file |

## Doc-to-Code Mapping

| Source File(s) | Documentation Target(s) | What to Update |
|---|---|---|
| `src/ast.rs` (Expr variants) | CLAUDE.md (Architecture), docs/DESIGN.md | New expression forms |
| `src/types.rs` (Type, EffectRow) | docs/DESIGN.md (Type System) | New type constructs |
| `src/checker/` (TypeEnv) | docs/DESIGN.md (Type System) | Inference changes |
| `src/compiler/` (compiler.rs, effects.rs) | CLAUDE.md (Architecture) | Bytecode compilation |
| `src/vm/` (vm.rs, opcode.rs) | CLAUDE.md (VM Internals) | VM opcodes, execution |
| `examples/*.lux` | CLAUDE.md (Effect System), docs/DESIGN.md | New patterns |
| `std/prelude.lux` | CLAUDE.md (Key Files) | New stdlib functions |
| `std/ml/*.lux`, `std/dsp/*.lux` | `docs/specs/lux-ml-design.md` | ML/DSP framework changes |
| `Cargo.toml` | CLAUDE.md (Build) | Dependencies, features |
