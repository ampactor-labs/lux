# Lux

## Throughline
Lux is the language that replaces manual discipline with static proof — the connective tissue between all projects. The effect system IS the hourglass: distributed effects converge to the handle{} block (pinch point), then resume(result) radiates new state.

**Kernel Pattern:** handle { computation } (pure computation) → handler-local state (configuration) → resume(result) (interface)
**Cross-Project:** !Alloc = sonido no_std; pipe operator = signal chain DSL; effect handlers = flowpilot safety gates; mock handlers = forge test isolation
**Current Priority:** Phase 6 (bytecode VM) — the interpreter proves the thesis, the VM makes it usable

### DSP Connection
- Pipe operator `|>` IS a signal chain: `input |> highpass(80) |> compress(4.0) |> limit(-0.1)`
- Refinement types (Phase 10): `type Sample = Float where -1.0 <= self <= 1.0` proves audio bounds
- `!Alloc` effect negation (Phase 9): compiler proves real-time safety, replacing sonido's manual no_std discipline
- Effect handlers = audio backend adaptation: `handle dsp_graph() { use CoreAudioHandler(48000, 256) }`

Lux ("light") — a compiled language where algebraic effects, refinement types,
and ownership inference close the gap between what programmers mean and what
they write. Rust-level safety with near-Python concision. The interpreter is
the thesis prover; the compiler is the destination.

## Build / Run / Test
- `cargo run -- <file.lux>` — run a program
- `cargo run` — start REPL
- `cargo check` — type check the compiler
- `cargo clippy` — lint
- `for f in examples/*.lux; do cargo run --quiet -- "$f"; done` — run all examples
- `/lux-feature` — guided workflow for adding new language constructs

## Architecture (Rust prototype — temporary scaffolding)

```
source → lex → parse → check → interpret   ← current (tree-walking, Rust)
                          ↓
                    codegen (future)         ← Cranelift → LLVM → self-hosted
```

Pipeline: `lexer.rs` → `parser.rs` → `checker.rs` → `interpreter.rs`
Shared types: `token.rs`, `ast.rs`, `types.rs`, `error.rs`
Runtime: `env.rs` (Rust `Arc`-based scoped environments — prototype only)
Frontend: `main.rs` (CLI), `repl.rs` (REPL), `lib.rs` (prelude loader)
Standard library: `std/prelude.lux` (self-hosted in Lux — this part stays)

## Key Files (Rust prototype)

| File | Owns | Survives self-hosting? |
|------|------|----------------------|
| `src/token.rs` | Token types, Span | Rewritten in Lux |
| `src/lexer.rs` | Tokenization, string interpolation | Rewritten in Lux |
| `src/ast.rs` | AST nodes, patterns, type expressions | Rewritten in Lux |
| `src/parser.rs` | Recursive descent, Pratt precedence climbing | Rewritten in Lux |
| `src/types.rs` | Internal types, row-polymorphic effects, ADT defs | Rewritten in Lux |
| `src/checker.rs` | HM inference, effect tracking, trait resolution | Rewritten in Lux |
| `src/interpreter.rs` | Tree-walking eval, multi-shot continuations | Deleted |
| `src/builtins.rs` | Built-in function registration | Deleted |
| `src/patterns.rs` | Pattern matching (list, or, record patterns) | Deleted |
| `src/env.rs` | Arc-shared lexical scoping (Rust runtime) | Deleted |
| `src/error.rs` | Error types, source-context formatting | Rewritten in Lux |
| `src/loader.rs` | Module import resolution, cycle detection | Rewritten in Lux |
| `src/compiler/` | Bytecode compiler (expressions, effects, patterns) | Rewritten in Lux |
| `src/vm/` | Stack-based VM (execution, effects, builtins) | Rewritten in Lux |
| `std/prelude.lux` | Self-hosted stdlib (38 functions: map, filter, fold, sort, enumerate, min, max, clamp, flat_map, unique, words, lines, etc.) | **YES — Lux forever** |
| `examples/*.lux` | Language examples and test cases | **YES — Lux forever** |
| `tests/examples.rs` | Golden-file integration tests + VM parity checks | Rewritten in Lux |

## Effect System (the core)

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
```

One mechanism replaces: exceptions, state, generators, async, DI, backtracking.

## Rust Prototype Internals

> These are implementation details of the Rust tree-walking interpreter,
> NOT part of Lux the language. They will be replaced by codegen.

- `Signal` enum for control flow (Return, Resume, Perform, HandleDone, Break, Continue, TailCall)
- `HandlerFrame` stack for effect dispatch
- `Arc<Environment>` for O(1) closure capture
- Trampoline loop for TCO
- Thread-based generators via `std::sync::mpsc` rendezvous channels

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

## Roadmap (beyond interpreter)

| Phase | Layer | Deliverable |
|-------|-------|-------------|
| 6C | Modules + VM | Module system, bytecode compiler, stack-based VM (**DONE**) |
| 7 | Evidence-passing | Koka-style effect compilation, near-native performance |
| 8 | Codegen | Cranelift backend, native binaries (Linux/Mac/Windows) |
| 9 | Ownership | own/ref/gc inference, borrow checking |
| 9.5 | Concurrent handlers | Parallel resume with ownership-proven isolation |
| 10 | Refinements | Z3-backed refinement types, !Alloc proof, gradual verification |
| 11 | Self-hosting | Parser + checker rewritten in Lux |
| 12 | Polish | LLVM backend, LSP, package manager, progressive levels |

## Doc-to-Code Mapping

| Source File(s) | Documentation Target(s) | What to Update |
|---|---|---|
| `src/ast.rs` (Expr variants) | CLAUDE.md (Architecture), docs/DESIGN.md | New expression forms |
| `src/types.rs` (Type, EffectRow) | docs/DESIGN.md (Type System) | New type constructs |
| `src/interpreter.rs` (Signal, HandlerFrame) | CLAUDE.md (Conventions) | New control flow signals |
| `src/checker.rs` (TypeEnv) | docs/DESIGN.md (Type System) | Inference changes |
| `examples/*.lux` | CLAUDE.md (Effect System), docs/DESIGN.md | New patterns |
| `std/prelude.lux` | CLAUDE.md (Key Files) | New stdlib functions |
| `Cargo.toml` | CLAUDE.md (Build) | Dependencies, features |
