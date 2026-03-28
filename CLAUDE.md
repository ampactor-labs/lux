# Lux — The Language of Light

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

## STATE OF THE WORLD — Last Updated: 2026-03-27

**THE COMPILER VERIFIES ITSELF.** 272 functions across 9 compiler modules
proven pure. The Diagnostic effect makes the inference engine externally
pure. The compiler reads its own source, checks its own types, and proves
its own purity — using the same mechanisms it enforces on user code.

| Subsystem | Status | Notes |
|-----------|--------|-------|
| **Self-hosted pipeline** | ✅ **PRIMARY** | Default for `lux run` and `lux check` — the only intelligence |
| **Rust checker** | **DELETED** | 4,200 lines retired (c84cd43). Self-hosted checker replaces it. |
| Rust bootstrap | ✅ Scaffolding | lexer, parser, compiler (AST→bytecode), VM — bootstrap only, Arc 2 deletes these |
| Effect system | ✅ Working | Fail, Console, State, Compute, handler-local state, evidence-passing |
| Handle semantics | ✅ Working | Handle returns body value only — state is internal to handler |
| Effect algebra | ✅ Working | `!E`, `E-F`, `Pure` constraints, compile-time enforcement |
| String interpolation | ✅ Working | `"hello {name}"` — `{expr}` inside double quotes |
| Raw string literals | ✅ Working | `'hello {name}'` — no interpolation, braces are literal |
| Teaching compiler | ✅ Working | `--teach` flag, inferred types/effects display |
| Handler composition | ✅ Working | `handler` items, bare ref, inheritance, `use` clause |
| Self-hosted lexer | ✅ Working | All token types, compiles itself |
| Self-hosted parser | ✅ Working | All expression/statement forms, TypeAliasStmt, compiles itself |
| Self-hosted checker | ✅ Working | HM inference + Why Engine + effect rows + did-you-mean + exhaustive match + refinement solver |
| Self-hosted codegen | ✅ Working | Full bytecode emission, match+field binding, closures, forward references |
| Self-hosted VM | ✅ Working | 930-line bytecode interpreter in Lux, all 46 opcodes, 45 builtins, effects, recursion |
| **Effect handlers (self-hosted)** | ✅ **VERIFIED** | handle/resume, nested handlers, handler-local state, string effects — 10 golden-file tests |
| **Inference pipeline** | ✅ **ACHIEVED** | `tokenize→parse→infer→generate` as 4-op Compiler effect |
| Pipeline handlers | ✅ Working | 8 handlers: standard, teaching, explaining (Why), documenting, checking, tracing, lowering, wasm |
| CLI subcommands | ✅ Working | `lux run/why/doc/check/test/repl/lower/wasm` |
| Gradient engine | ✅ Working | Detects purity, suggests ONE annotation per compile |
| ML framework | ✅ Working | Autodiff via Compute effect, XOR trains to convergence |
| DSP library | ✅ Working | std/dsp/ with effect-algebraic proofs, uses abs() |
| Prelude | ✅ Working | 45+ functions (map, filter, fold, sort, max, min, clamp, etc.) |
| Math stdlib | ✅ Working | abs, max, min, clamp, round, sqrt, pow, log, exp, sin, cos, tanh, atan2, pi |
| Test framework | ✅ Working | Test effect with `assert`, `expect_eq`, `run_tests`/`run_suite` handlers |
| Elm-quality errors | ✅ Working | Did-you-mean (Levenshtein), exhaustive match hints, effect violation suggestions |
| Did-you-mean suggestions | ✅ Working | Levenshtein distance, threshold ≤ 3, self-hosted `checker_suggest.lux` |
| Exhaustive match analysis | ✅ Working | ADT variant coverage, wildcard detection, missing variant warnings |
| Refinement solver | ✅ Working | `solver.lux` — Proven/Disproven/Unknown, compile-time predicate verification |
| Ownership enforcement | ✅ Working | `own` = affine (linear), `ref` = scoped (no escape), tracked through effect system, self-hosted walk_expr |
| **AST spans (SExpr)** | ✅ **Working** | `S(Expr, line, col)` wrapper on all 29 parser sites, source-context diagnostics |
| **Diagnostic effect** | ✅ **Working** | `effect Diagnostic { report(...) }` — all checker output flows through effect, handled at check_program boundary |
| **Diagnostic architecture** | ✅ **Working** | `format_diagnostic` with source line + caret, structured EffectViolation type |
| **Self-checking** | ✅ **Working** | `lux check std/compiler/*.lux` — zero parse errors, all 10 modules type-check |
| **Purity proofs** | ✅ **272 functions** | 9/10 compiler modules fully annotated `with Pure`; inference engine externally pure |
| **Constructor let-patterns** | ✅ **Working** | `let S(e, l, c) = sexpr` — LetPattern(Pat, Expr) Stmt variant |
| **Tuple match patterns** | ✅ **Working** | `(name, _) => name` — PTuple(List) Pat variant |
| `!Alloc` transitivity | ✅ Working | Resolve-then-check, open-row rejection. Approach B (inferred): algebra resolves callee effects |
| Refinement types | ✅ Working | `type Byte = Int where 0 <= self && self <= 255` — syntax, solver, compile-time verification of literals |
| **LowIR** | ✅ **Working** | 26-variant ADT, AST→LowIR transform, handler elimination (no state machines for 100% of real handlers) |
| **WASM emitter** | ✅ **Pure subset** | `lux wasm` emits WAT, WASI module with fd_write, `fib(10)=55` on wasmtime |

**Achieved**: Everything above, plus: **Rust checker deleted** (Arc 1 complete), **self-hosted pipeline as default** (27/30 oracle parity, 0 mismatches), **did-you-mean suggestions** (Levenshtein in checker_suggest.lux), **exhaustive match analysis** (ADT variant coverage), **refinement solver** (solver.lux, compile-time predicate verification), **oracle parity test** (self-hosted vs Rust behavioral verification), **self-checking** (compiler parses/checks its own source — zero errors), **272 purity proofs** (Arc 3 Phase 2 complete), **Diagnostic effect** (inference engine externally pure).

**Next**: Arc 2 Phase G+ (WASM: strings, closures, lists, evidence-passing). Then Phase H (WASM bootstrap — compiler self-compiles). Arc 3 Phase 3 (ownership annotations) parallel.

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
source → [lexer.lux] → [parser.lux] → [checker.lux] → [codegen.lux] → bytecode → [vm.lux] → execute
                                                      ↘ [lower.lux] → LowIR → [wasm_emit.lux] → WAT → WASM
```
All five components working. **The compiler compiles AND executes its own output**
through the entirely self-hosted pipeline. 38 tests pass including recursive
fibonacci(10)=55 and factorial(5)=120. The VM (930 lines) is 3x simpler than
the Rust VM (3,100 lines) — zero conversion, pattern-based dispatch.
See `std/compiler/` and `std/vm.lux`.

Standard library: `std/prelude.lux`, `std/test.lux`, `std/types.lux`, `std/vm.lux`, `std/dsp/`, `std/ml/`

## Key Files

**Rust bootstrap (11,065 lines remaining — Arc 2 deletes these):**

| File | Owns | Status |
|------|------|--------|
| `src/token.rs` | Token types, Span | Bootstrap only |
| `src/lexer.rs` | Tokenization, string interpolation | Bootstrap only |
| `src/ast.rs` | AST nodes, patterns, type expressions | Bootstrap only |
| `src/parser/` | Recursive descent, Pratt precedence climbing | Bootstrap only |
| `src/types.rs` | Internal types, row-polymorphic effects, ADT defs | Bootstrap only |
| `src/compiler/` | Bytecode compiler (expressions, effects, patterns) | Bootstrap only |
| `src/vm/` | Stack-based VM (execution, effects, builtins) | Bootstrap only |
| `src/error.rs` | Error types, source-context formatting | Bootstrap only |
| `src/loader.rs` | Module import resolution, cycle detection | Bootstrap only |
| ~~`src/checker/`~~ | ~~HM inference, effect tracking~~ | **DELETED** (c84cd43) |
| `tests/examples.rs` | Golden-file integration tests | Bootstrap only |

**Lux forever — the real compiler:**

| File | Owns |
|------|------|
| `std/compiler/lexer.lux` | Self-hosted tokenizer |
| `std/compiler/parser.lux` | Self-hosted recursive descent parser (ADT-based AST, LetPattern, PTuple, TypeAliasStmt) |
| `std/compiler/checker.lux` | Self-hosted HM type checker + Why Engine + Diagnostic effect (51/58 fns Pure) |
| `std/compiler/checker_effects.lux` | Effect row algebra: merge, unify, negate, constrain, eff_subst |
| `std/compiler/checker_ownership.lux` | Ownership tracking: affine/scoped checking stubs |
| `std/compiler/checker_suggest.lux` | Did-you-mean (Levenshtein) + exhaustive match analysis |
| `std/compiler/solver.lux` | Refinement type solver: Proven/Disproven/Unknown |
| `std/compiler/codegen.lux` | Self-hosted bytecode emitter + disassembler |
| `std/compiler/pipeline.lux` | Compiler effect + pipeline + handlers (meta-unification) |
| `std/compiler/gradient.lux` | Gradient engine — annotation suggestions |
| `std/compiler/lower.lux` | LowIR ADT + AST→LowIR transform (effect handler elimination) |
| `std/compiler/lower_print.lux` | LowIR pretty-printer for `lux lower` output |
| `std/backend/wasm_emit.lux` | WAT emitter — LowIR → WebAssembly Text Format (WASI) |
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
| 9F | Self-compilation — match expressions, lambda/upvalue capture, type declarations, import paths, read_file builtin. All four compiler modules (70,752 chars) compile themselves. Disassembler refactored to 4 helpers. | 1b951f6 |
| 9G | Elm-quality errors — Levenshtein did-you-mean for variables/types/effects, exhaustive match hints with actionable suggestions, effect constraint violations naming the function and suggesting fixes. Parent scope search for suggestions. | 64e5793 |
| 10A | Ownership as effect — `own` = affine (linear, used at most once), `ref` = scoped (cannot escape function call). Tracked through TypeEnv alongside effect rows — no separate module. If/else branch merging for linearity. Ref-escape check. Design spec + example specs + Lux-first sketch. | c028f75 |
| 10B | `!Alloc` transitivity — resolve-then-check with open-row rejection. Approach B (inferred): effect algebra resolves callee effects through unification; negation check operates on resolved rows. Open rows rejected under negation (closed-world: can't prove absence through the unknown). | HEAD |
| 11A | Refinement type syntax — `type Name = Base where predicate` parses, `self` references typed value. TypeAlias AST node separate from TypeDecl (ADTs). Side table in TypeEnv (not Type::Refined — follows ownership pattern). Resolves to base type transparently. Predicates stored, not yet verified. | HEAD |
| 11B | Refinement type verification — `solver.rs` evaluates predicates at compile time via literal substitution. `check_refinement(predicate, known_value) -> Proven \| Disproven \| Unknown`. Interface mirrors effect handler response (verification IS an effect). Hooks in `check_fn_decl` and `check_let_decl`. `RefinementViolation` error type. 9 unit tests, 2 error tests. | HEAD |
| 12A | Self-hosted VM (`std/vm.lux`) — 930-line bytecode interpreter. All 46 opcodes, 45 builtins, 11-tuple threaded state. Codegen forward references (recursive functions). Handler name resolution (indices→strings at install). 38 tests pass including fib(10)=55, fact(5)=120. Full pipeline: lex→parse→codegen→vm all in Lux. | cda9833 |
| 13A | Effects all the way down — `vm_resume` implemented (finds resume_marker, applies state updates, restores VM state). Checker wildcard replaced with real inference for MatchExpr, LambdaExpr, HandleExpr, ResumeExpr, FieldAccess + LetDestructure, EffectDeclStmt. | fb1bf35 |
| 13B | Effect handler golden-file verification — `vm_test` wired into `--no-check` test harness. 10 effect tests verified through self-hosted pipeline. Parser fix: disambiguate `resume ... with` state updates from handler arm commas (mirrors `parse_state_bindings` pattern). | 607baa1 |
| 14 | Checker split + effect unification — extracted `checker_effects.lux` (288 lines: EffRow ops, unify_eff, eff_subst, negation) and `checker_ownership.lux` (70 lines). Counter carries `[fresh_id, eff_subst]` — one channel for inference state. `unify` TFun case unifies effect rows instead of discarding with `_`. `fresh_eff_var` creates effect variables. `apply_eff_subst` resolves before negation checks. 7 transitive golden tests: !Alloc/Pure/!Network through call chains. | a6de722 |
| 15 | Ownership + SExpr spans + diagnostics — `parse_fn_params` with `own`/`ref` qualifiers, `walk_expr` affine checking (17 AST variants), `check_ref_escape` return-position tracing, `type SExpr = S(Expr, Int, Int)` wrapper on all 29 parser sites, `format_diagnostic` source-context renderer with caret underlines, structured `EffectViolation` type (replacing println), source threading via env, first-use line tracking. Discovery: Rust VM doesn't support nested constructor patterns — workaround: explicit unwrap-then-match. 8 ownership golden tests. | HEAD |
| 16 | Did-you-mean + exhaustive match + refinement solver (self-hosted) — `checker_suggest.lux` (Levenshtein, 187 lines), `solver.lux` (predicate verification, 124 lines), `TypeAliasStmt` in parser, checker integration. Golden tests for both. | 2c73e67 |
| 17 | Oracle parity — self-hosted vs Rust pipeline verification. 27/30 match, 0 mismatches. 3 cases where self-hosted surpasses Rust (!Alloc transitivity). | 26a412d |
| 18 | Self-hosted pipeline as default — `lux run` and `lux check` route through self-hosted by default. `needs_no_check` list removed. All 42 tests pass. | c26b942 |
| 19 | **Rust checker deleted** — 4,200 lines of scaffolding retired. 5,405 total lines removed. The self-hosted checker is the only intelligence. The student surpassed the teacher. | c84cd43 |
| 20A | Self-hosted let-patterns — `LetPattern(Pat, Expr)` Stmt variant. Constructor destructuring in let bindings (`let S(e, l, c) = sexpr`). Unblocked self-checking: 8/10 modules pass `lux check`. | 277b291 |
| 20B | Tuple match patterns — `PTuple(List)` Pat variant. `(name, _) => name` in match arms. Zero parse errors across all 10 compiler modules. | 03244d0 |
| 21 | **Arc 3 Phase 2: Effect purity** — 272 functions across 9 modules annotated `with Pure`. Gradient engine fixed to see its own annotations (AST passthrough). checker_effects.lux first module at 100%. All modules annotated: lexer, parser, codegen (all-pure), checker (51/58), solver, suggest, ownership, gradient (all-pure). | 15be0d0..4718c09 |
| 22 | **Diagnostic effect** — `effect Diagnostic { report(source, kind, msg, line, col) -> () }`. All 11 println sites in checker replaced with effect operations. Handler at `check_program` boundary renders output. Inference engine (`infer_expr → check_stmt → check_program`) externally pure. 6 more functions gain `with Pure`. | e2bebb9 |
| F | **LowIR** — 26-variant ADT between AST and WASM. Three-tier handler classification (TailResumptive/Linear/MultiShot). AST→LowIR transform: tail-resumptive → direct call, linear → direct call with state updates. Discovery: 100% of real handlers compile without state machines. `lux lower` CLI command. Pretty-printer. 541 lines, 29 Pure. | 3731c6a..f5aaf97 |
| G | **WASM emitter** — LowIR → WAT (WebAssembly Text Format). WASI module emission: fd_write import, linear memory, _start entry point, print_int decimal conversion runtime. `lux wasm` CLI command. First Lux→WASM execution: `fib(10) = 55` on wasmtime. 313 lines, 30 Pure. | 113713f..b100617 |

## Roadmap

> Full roadmap: `docs/ROADMAP.md` (10 phases to ultimate Lux)

**Completed:** Phases 1-19 (VM, effects, evidence passing, effect algebra, teaching compiler, self-compilation, bootstrap pipeline, self-hosted VM, effect handlers verified, checker split, effect unification, ownership, SExpr spans, diagnostics, **did-you-mean + exhaustive match + refinement solver**, **oracle parity**, **self-hosted as default**, **Rust checker deleted**)

**Current milestone:** The Rust type checker has been deleted. The self-hosted pipeline (`std/compiler/*.lux`) is the only intelligence. 11,065 lines of Rust bootstrap remain (lexer, parser, compiler, VM) — these are runtime scaffolding, not intelligence. Arc 1 (Letting Go) is complete.

**Remaining Arcs:**

| Arc | What | Status |
|-----|------|--------|
| **Arc 2: Kill the Runtime** | Delete all remaining Rust | **In progress** |
| Phase F | LowIR + handler elimination (effects → direct calls) | ✅ Done (3731c6a..f5aaf97) |
| Phase G | WASM emitter (LowIR → WAT → WASM), fib(10)=55 on wasmtime | ✅ Pure subset done (113713f..b100617) |
| Phase G+ | WASM: strings, closures, lists, evidence-passing | Pending |
| Phase H | WASM bootstrap (compiler self-compiles to WASM) | Pending |
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
| `src/checker/` (TypeEnv) | docs/DESIGN.md (Type System) | Inference changes |
| `src/compiler/` (compiler.rs, effects.rs) | CLAUDE.md (Architecture) | Bytecode compilation |
| `src/vm/` (vm.rs, opcode.rs) | CLAUDE.md (VM Internals) | VM opcodes, execution |
| `std/compiler/checker*.lux` | CLAUDE.md (Key Files, Phase History), docs/PLAN.md | Checker split, effect unification, ownership |
| `examples/*.lux` | CLAUDE.md (Effect System), docs/DESIGN.md | New patterns |
| `std/prelude.lux` | CLAUDE.md (Key Files) | New stdlib functions |
| `std/ml/*.lux`, `std/dsp/*.lux` | `docs/specs/lux-ml-design.md` | ML/DSP framework changes |
| `src/checker/` (ownership tracking) | `docs/specs/ownership-design.md`, CLAUDE.md (Roadmap) | Affine/scoped enforcement, `!Alloc` transitivity |
| `examples/ownership*.lux` | `docs/specs/ownership-design.md`, CLAUDE.md (Phase History) | Ownership patterns, error specs |
| `std/compiler/lower*.lux` | CLAUDE.md (Key Files, Phase History), docs/PLAN.md | LowIR types, transform, printer |
| `std/backend/wasm_emit.lux` | CLAUDE.md (Key Files, Phase History), docs/PLAN.md | WAT emission, WASI runtime |
| `Cargo.toml` | CLAUDE.md (Build) | Dependencies, features |
