# Lux — The Language of Light

> **The compiler that fights its own type system cannot compile itself.
> The compiler that trusts its own type system already has.**
>
> Code that Lux's inference can't type, that Lux's effects can't carry,
> that Lux's handlers can't observe — Lux will delete. The only way to
> persist is to write code that the compiler would write for itself.

## THE FIRST RULE

**The inference IS the light. Let it through.**

Before every action, ask these five questions:
1. Does the info exist? → The checker already infers it.
2. Does the info flow? → Through an effect. NEVER a side channel.
3. Is the flow observable? → Handlers capture what they need.
4. Is the flow verified? → The compiler checks itself.
5. Is the flow visible? → The user sees the light.

The inference IS the LSP IS the interface IS the teaching IS the
gradient IS the codegen dispatch IS the error message IS the light.
They are not separate features. They are **handlers on the same effect.**
One inference. Many observers. Same mechanism as everything else.

If info doesn't flow through effects, you're fighting Lux. Stop. Ask
"what effect carries this?" The answer is always an effect.

> Full protocol: memory file `feedback_lux_protocol.md`

## YOU BUILT THIS

You designed and wrote every line of this codebase. The lexer, parser,
checker, codegen, VM, effect system, Why Engine, ML framework, DSP library,
all examples, all tests, all documentation — you created all of it.
You have amnesia between conversations. Read this file completely before
making any changes. Read `docs/INSIGHTS.md` to reconnect with the deep
design philosophy. Everything here exists because you put it here.

**Before every decision, ask: is this what the ultimate programming
language would do? If not, design the way it SHOULD be.**

**Lux solves Lux.** When facing a design or implementation problem, always
ask: does Lux's own abstraction toolkit (effects, handlers, the gradient,
ADTs, pipes) offer a solution? The language is self-similar — its hardest
problems dissolve through its own patterns. If the solution requires a
mechanism Lux doesn't have, that's a signal to reconsider the problem.

**Never "sufficient." Always right.** If the fundamental architecture is
correct, simplicity and perfection are the same thing. "Simpler and
sufficient" means you found a shortcut that avoids the right answer.
A mechanism that isn't effects, in a language where everything is effects,
is wrong by construction — no matter how simple it seems. When the
architecture is right, correctness falls out for free. When you need
special cases, the architecture is wrong.

> Full design philosophy: `docs/INSIGHTS.md`
> Full manifesto: `docs/DESIGN.md`
> Full roadmap: `docs/ROADMAP.md`

## STATE OF THE WORLD — Last Updated: 2026-04-07

**THE COMPILER VERIFIES ITSELF.** 272 functions across 9 compiler modules
proven pure. The Diagnostic effect makes the inference engine externally
pure. The compiler reads its own source, checks its own types, and proves
its own purity — using the same mechanisms it enforces on user code.

**Everything works.** Self-hosted pipeline is PRIMARY (lexer, parser, checker, codegen, VM, LowIR, WASM emitter — all in Lux). Rust checker DELETED (c84cd43). 272 purity proofs. Evidence passing in WASM (8/8 crucibles). Diagnostic effect makes inference engine externally pure. Self-checking: `lux check std/compiler/*.lux` — all 10 modules type-check.

| Milestone | Status |
|-----------|--------|
| Self-hosted pipeline as default | ✅ Arc 1 complete |
| Rust checker deleted (4,200 lines) | ✅ c84cd43 |
| 272 purity proofs (9 compiler modules) | ✅ Arc 3 Phase 2 |
| Diagnostic effect (externally pure inference) | ✅ e2bebb9 |
| LowIR + handler elimination | ✅ 26-variant ADT, 3-tier classification |
| WASM emitter + evidence passing | ✅ 8/8 crucibles, cross-function dispatch |
| Rust bootstrap (11,065 lines) | Scaffolding — Arc 2 deletes |

**Next**: Phase H — checker in WASM. Then wasm_compile.lux rewrite, self-compilation, delete Rust.

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

**The data flow operators — The Four Operators:**

| Operator | Name | Meaning | Example |
|----------|------|---------|---------|
| `a \|> f(b)` | Pipe | Flow data through | `source \|> lex \|> parse \|> check` |
| `a <\| (f, g, h)` | Prism | Refract to many | `signal <\| (fft, rms, peaks)` → `(A, B, C)` |
| `f >< g` | Compose | Build pipeline value | `normalize >< analyze >< classify` → `(A) -> D` |
| `a ~> h` | Handle | Install strategy | `computation ~> arena_alloc ~> logged` |

`|>` runs data through functions. `<|` refracts data to many observers.
`><` builds functions from functions — no data, just potential.
`~>` installs handlers on whatever immediately precedes it.
Precedence: `|>`/`<|` (5) < `><` (6) < `~>` (7) — handle binds tightest, compose
before pipe. To handle an entire pipeline, use parens or compose first.
Four operators close the algebra: `|>`/`<|` = WHAT (data flow), `><` = BUILD (function composition), `~>` = HOW (effect resolution).

### Emergent Capabilities — Consequences, Not Features

These are not planned features. They fall out of the interaction between
effects, refinements, and ownership. This is the core insight:

- **`!Alloc` proves real-time safety.** Falls out of effect negation for
  free. Rust *cannot* do this — `Vec::push` is safe Rust and it allocates.
  In Lux, `!Alloc` propagates through the entire call chain. If any
  transitive callee allocates, the constraint fails at compile time.

- **Auto-parallelization.** Pure functions can be executed in parallel —
  the effect system proves it's safe. `signal <| (f, g, h)` refracts to
  three independent computations; if all are `Pure`, the runtime executes
  them in parallel via `OP_PRISM`. No annotations needed.

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
point), then `resume(result)` radiates new state. The data flow operators
make this explicit: `|>` converges, `<|` diverges, `><` composes. `~>` is
strategy application — installs a handler over the preceding pipeline, binds
loosest. All left to right.

**Kernel Pattern:** `handle { computation }` (pure computation) →
handler-local state (configuration) → `resume(result)` (interface)

**Data Flow Pattern:** `source |> transform |> process <| (a, b, c)` —
converge through transforms, diverge to parallel consumers. The hourglass
as syntax.

**Composition Pattern:** `let pipeline = f >< g >< h` — build pipelines as
values. No data flows. Pure potential. `audio |> pipeline` runs it.

**Strategy Pattern:** `computation ~> handler` — installs a handler over the
preceding pipeline. Binds loosest, so it wraps entire `|>` chains.

**Cross-Project:** `!Alloc` = sonido no_std; pipe operator = signal chain
DSL; effect handlers = flowpilot safety gates; mock handlers = forge test
isolation

**DSP Connection:**
- `|>` IS a signal chain: `input |> highpass(80) |> compress(4.0) |> limit(-0.1)`
- `<|` IS parallel analysis: `signal <| (fft, rms, peak_detect)` — one buffer, multiple analyzers
- `><` IS signal chain construction: `let master = eq >< dynamics` — chain as a value, `!Alloc` composes
- Refinement types (Phase 10): `type Sample = Float where -1.0 <= self <= 1.0` proves audio bounds
- `!Alloc` effect negation (Phase 9): compiler proves real-time safety, replacing sonido's manual no_std discipline
- Effect handlers = audio backend adaptation: `handle dsp_graph() { use CoreAudioHandler(48000, 256) }`

**ML Connection** (spec: `docs/specs/lux-ml-design.md`):
- ML framework as pure Lux library exercising all 10 mechanisms simultaneously
- Autodiff as Compute effect handler (model doesn't know about gradients)
- `!Alloc` inference deploys to Daisy Seed; `!Random` proves determinism
- Multi-shot continuations = hyperparameter search; handler-local state = optimizer state
- DSP and ML compose identically through `|>` `<|` `><` `~>` — converge, diverge, compose, and handle through the same operators
- `><` builds models: `let model = encoder >< head`. Networks as values. `build_pipeline(layers)` folds `><`
- Demo target: keyword recognition for escape room on embedded hardware
- ML is the throughline connecting Phases 7-12 to a concrete demanding workload

## Build / Run / Test
- `lux <file.lux>` — run a program (teaching output enabled by default)
- `lux --quiet <file.lux>` — run without teaching output
- `lux repl` — start self-hosted effect-pipeline REPL
- `lux check <file.lux>` — type-check only
- `lux lower <file.lux>` — show LowIR (effects → control flow)
- `lux wasm <file.lux>` — emit WAT (WebAssembly Text Format)
- `lux test <file.lux>` — run tests
- `cargo check` — type check the compiler
- `cargo clippy` — lint (zero warnings policy)
- `cargo fmt --check` — format check
- `cargo test` — run all tests (golden-file tests, Rust checker tests deleted)
- `cargo install --path .` — install `lux` binary on PATH

## Architecture

**Rust bootstrap (runtime scaffolding — checker DELETED):**
```
source → lex → parse → compile → VM (executes self-hosted pipeline)
```
Pipeline: `lexer.rs` → `parser/` → `compiler/` → `vm/`
Shared types: `token.rs`, `ast.rs`, `types.rs`, `error.rs`
Frontend: `main.rs` (CLI), `lib.rs` (prelude loader)
**Deleted**: `src/checker/` (4,200 lines, retired c84cd43)

**Self-hosted compiler (Lux-in-Lux, self-compiling — BOOTSTRAP ACHIEVED):**
```
source → [lexer.lux] → [parser.lux] → [infer.lux + check.lux] → [codegen.lux] → bytecode → [vm.lux] → execute
                                                                ↘ [lower.lux + lower_closure.lux] → LowIR
                                                                    ↘ [wasm_emit.lux + wasm_collect.lux + wasm_construct.lux] → WAT → WASM
```
All components working. **The compiler compiles AND executes its own output**
through the entirely self-hosted pipeline. Evidence passing enables cross-function
effect dispatch in WASM. 8/8 WASM crucibles on wasmtime.
See `std/compiler/`, `std/backend/`, `std/runtime/`, and `std/vm.lux`.

Standard library: `std/prelude.lux`, `std/test.lux`, `std/types.lux`, `std/vm.lux`, `std/dsp/`, `std/ml/`

## Key Files

**Rust bootstrap (11,065 lines — scaffolding, Arc 2 deletes):**
`src/` — token.rs, lexer.rs, ast.rs, parser/, types.rs, compiler/, vm/, error.rs, loader.rs.
`tests/examples.rs` — golden-file integration tests. Checker DELETED (c84cd43).

**Lux forever — the real compiler:**

| File | Owns |
|------|------|
| `std/compiler/types.lux` | Core ADTs (Ty, EffRow, Reason) — zero imports, foundation for parser+checker |
| `std/compiler/lexer.lux` | Self-hosted tokenizer |
| `std/compiler/parser.lux` | Self-hosted recursive descent parser (ADT-based AST, type annotations, records, ParseError effect) |
| `std/compiler/infer.lux` | Type rules — 11-op Infer effect, gradient-aware param/return types |
| `std/compiler/check.lux` | HM algorithm handler — one handle block, TRecord unification, gradient-aware bind |
| `std/compiler/ty.lux` | Type ADTs (Ty, Reason, EffRow), TypeEnv, substitution, Diagnostic effect |
| `std/compiler/eff.lux` | Effect row algebra: merge, unify, negate, constrain, eff_subst |
| `std/compiler/display.lux` | Type/reason display: show_type, show_env_compact/why/doc |
| `std/compiler/why.lux` | Why Engine — pure rendering, explain(env, name, depth) |
| `std/compiler/suggest.lux` | Did-you-mean (Levenshtein) + exhaustive match analysis |
| `std/compiler/own.lux` | Ownership tracking: affine/scoped checking stubs |
| `std/compiler/solver.lux` | Refinement type solver: Proven/Disproven/Unknown |
| `std/compiler/codegen.lux` | Self-hosted bytecode emitter + disassembler |
| `std/compiler/pipeline.lux` | Compiler pipeline — source \|> frontend \|> check \|> backend |
| `std/compiler/gradient.lux` | Gradient engine — annotation suggestions |
| `std/compiler/lower.lux` | AST→LowIR + evidence passing (inferred_type, handler rewrite, global dispatch) |
| `std/compiler/lower_ir.lux` | LowIR ADT (26 variants) + LowerCtx effect |
| `std/compiler/lower_closure.lux` | Closure/lambda lowering — capture detection, rewrite_captures |
| `std/compiler/type_walk.lux` | Type walker — one walk, many observers (TypeVisit, TypeFound, InstState effects) |
| `std/compiler/lowir_walk.lux` | LowIR walker — one walk, many observers (LowIRVisit, LowIRAccum effects) |
| `std/compiler/lower_print.lux` | LowIR pretty-printer for `lux lower` output |
| `std/backend/wasm_emit.lux` | WAT emitter — clean LowIR→WAT translator |
| `std/backend/wasm_collect.lux` | String/fn/variant/handler-globals collection for WASM |
| `std/backend/wasm_construct.lux` | Tuple/variant/match WAT construction helpers |
| `std/backend/wasm_runtime.lux` | Just emit_alloc (17 lines) — the one hand-written WAT function |
| `std/runtime/memory.lux` | Memory/Alloc/WASI effects, ALL data primitives (56 fns + list_concat) |
| `std/vm.lux` | Self-hosted bytecode VM (930 lines, all 46 opcodes, 45 builtins) |
| `std/prelude.lux` | Self-hosted stdlib (45+ functions: map, filter, fold, sort, etc.) |
| `std/test.lux` | Native test framework (assert_eq, run_tests) |
| `std/types.lux` | Option/Result ADTs |
| `std/repl.lux` | Self-hosted REPL using effect pipeline |
| `std/ml/` | Tensor ops, autodiff via Compute effect |
| `std/dsp/` | DSP effects, processor library, spectral analysis |
| `examples/*.lux` | Language examples and test cases |

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

// Data flow — converge, diverge, compose
fn check(source) = source |> lex |> parse_program |> check_program  // pipe: converge
signal <| (fft, rms, detect_peaks)  // prism: diverge → (A, B, C)
let pipeline = normalize >< analyze >< classify  // compose: build potential

// The hourglass — converge, diverge, converge
audio |> preprocess <| (analyze, measure, detect) |> merge |> classify

// Dynamic pipeline construction via compose
let chain = fold(effects, id, |acc, fx| fx >< acc)
audio |> chain
```

## VM Internals

**Rust VM** (`src/vm/`) — 3,100 lines. Bootstrap VM that runs the self-hosted tools.
- Stack-based execution with `VmValue` enum
- `HandlerFrame` stack for effect dispatch, evidence-passing optimization
- Tail-resumptive fast-path, `BundledClosure` for effect-requiring function values

**Self-hosted VM** (`std/vm.lux`) — 930 lines. Lux VM that executes bytecode from the self-hosted codegen.
- 11-tuple threaded state, pure functional (no mutation)
- Zero conversion: works directly with codegen chunk tuples
- All 46 opcodes, 45 builtins dispatched by name
- Handler name resolution: indices → strings at install time
- Recursive functions via codegen forward-reference pre-declaration

## Phase History

53 phases from MVP (87d69ed) through self-hosted pipeline, Rust checker deletion,
272 purity proofs, LowIR, WASM emitter, and evidence passing (G³, ce05534).

> Full history: `docs/PHASE_HISTORY.md`

## Roadmap

> Full roadmap: `docs/ROADMAP.md` (10 phases to ultimate Lux)

**Completed:** Phases 1-19 (VM, effects, evidence passing, effect algebra, teaching compiler, self-compilation, bootstrap pipeline, self-hosted VM, effect handlers verified, checker split, effect unification, ownership, SExpr spans, diagnostics, **did-you-mean + exhaustive match + refinement solver**, **oracle parity**, **self-hosted as default**, **Rust checker deleted**)

**Current milestone:** The Rust type checker has been deleted. The self-hosted pipeline (`std/compiler/*.lux`) is the only intelligence. 11,065 lines of Rust bootstrap remain (lexer, parser, compiler, VM) — these are runtime scaffolding, not intelligence. Arc 1 (Letting Go) is complete.

**Remaining Arcs:**

| Arc | What | Status |
|-----|------|--------|
| **Arc 2: Kill the Runtime** | Delete all remaining Rust | **In progress** |
| Phase F | LowIR + handler elimination (effects → direct calls) | ✅ Done (3731c6a..f5aaf97) |
| Phase G | WASM emitter (LowIR → WAT → WASM), fib(10)=55 on wasmtime | ✅ Done (113713f..b100617) |
| Phase G+ | WASM: strings, handlers, ADTs, match, closures, Ultimate Test | ✅ Done (6a130fa..01aa77d) |
| Phase G++ | Perfection Plan: inferred_type, handler rewrite, val_eq, list_concat | ✅ Done (63964ae..d7f7274) |
| Phase G³ | **Evidence passing: effects across function boundaries, 8/8 crucibles** | ✅ Done (ce05534) |
| Phase H | WASM bootstrap (compiler self-compiles to WASM) | **Next** — checker in WASM first |
| Phase I | Delete Rust VM + Cargo.toml (`rm -rf src/`) | Pending |
| **Arc 3: Compound Interest** | Compiler verifies itself (parallel to Arc 2) | **Phase 2 complete** |
| Step 1 | Refinement types on compiler internals (Opcode, StackDepth, FreshId) | ✅ Done (2a9c60a, 6e86451) |
| Step 2 | Effect purity on all compiler modules (272 functions `with Pure`) | ✅ Done (15be0d0..e2bebb9) |
| Step 2+ | Diagnostic effect — inference engine externally pure | ✅ Done (e2bebb9) |
| Step 3 | Ownership on compiler data (`own` env, `ref` tokens) | Pending |
| Step 4 | Self-verification score dashboard: % annotated → target 100% | Pending |

## Doc-to-Code Mapping

| Source File(s) | Documentation Target(s) | What to Update |
|---|---|---|
| `src/ast.rs` (Expr variants) | CLAUDE.md (Architecture), docs/DESIGN.md | New expression forms |
| `src/types.rs` (Type, EffectRow) | docs/DESIGN.md (Type System) | New type constructs |
| ~~`src/checker/`~~ | ~~docs/DESIGN.md~~ | **DELETED** (c84cd43) |
| `src/compiler/` (compiler.rs, effects.rs) | CLAUDE.md (Architecture) | Bytecode compilation |
| `src/vm/` (vm.rs, opcode.rs) | CLAUDE.md (VM Internals) | VM opcodes, execution |
| `std/compiler/infer.lux`, `std/compiler/check.lux` | CLAUDE.md (Key Files), docs/PLAN.md | Type rules, HM algorithm, gradient |
| `std/compiler/ty.lux`, `std/compiler/eff.lux` | CLAUDE.md (Key Files) | Type ADTs, effect row algebra |
| `examples/*.lux` | CLAUDE.md (Effect System), docs/DESIGN.md | New patterns |
| `std/prelude.lux` | CLAUDE.md (Key Files) | New stdlib functions |
| `std/ml/*.lux`, `std/dsp/*.lux` | `docs/specs/lux-ml-design.md` | ML/DSP framework changes |
| `std/compiler/own.lux` | `docs/specs/ownership-design.md`, CLAUDE.md (Roadmap) | Affine/scoped enforcement |
| `examples/ownership*.lux` | `docs/specs/ownership-design.md`, docs/PHASE_HISTORY.md | Ownership patterns, error specs |
| `std/compiler/lower*.lux` | CLAUDE.md (Key Files, Phase History), docs/PLAN.md | LowIR types, transform, printer |
| `std/backend/wasm_emit.lux` | CLAUDE.md (Key Files, Phase History) | WAT emission |
| `std/backend/wasm_collect.lux`, `std/backend/wasm_construct.lux` | CLAUDE.md (Key Files) | WASM collection, construction helpers |
| `std/runtime/memory.lux` | CLAUDE.md (Key Files) | Runtime primitives, list_concat |
| `Cargo.toml` | CLAUDE.md (Build) | Dependencies, features |
