# Lux → Self-Containment: The Holistic Plan

*Crystallized 2026-03-25. Living document — update phase status as work lands.*
*See also: `docs/ROADMAP.md` (10-phase vision), `docs/INSIGHTS.md` (design philosophy)*

## Context

Phase 13 is complete: vm_resume works, 10 effect handler golden-file tests pass,
the self-hosted checker enforces `!Alloc`/`Pure`/`!Network` negation and catches
violations, and the gradient engine teaches the next annotation to add. Seven commits
this session built the mechanism (13A), the proof (13B), the parser fix (disambiguation),
the enforcement (negation), the propagation (callee effects), and the teaching (gradient).

This plan maps the path from here to `rm -rf src/` — Lux compiling itself, by itself,
for itself. Three arcs run in parallel:

- **Correctness**: Close checker gaps until semantically equivalent to Rust checker
- **Trust**: Oracle testing and parity thresholds gate each transition
- **Backend**: Grow from symbolic bytecode to native/WASM machine code

Each phase is independently valuable. Each builds on the last.

---

## Immediate: Checker Split (pre-Phase 14)

`checker.lux` is 1,154 lines — over the 500-line budget. Before adding more:
- Extract `std/compiler/checker_effects.lux` (effect row ops: unify_eff, eff_subst, negation)
- Extract `std/compiler/checker_ownership.lux` (walk_expr, check_ref_escape, affine check)
- `checker.lux` becomes the orchestrator importing these modules

This also makes Phases 14-15 parallelizable by separate agents.

---

## Phase 14: Effect Unification — Small/Medium

**What**: `unify` currently discards effect rows on TFun with `_`. Fix it to unify
`eff1` with `eff2`. Add `eff_subst` as a parallel substitution map alongside type
subst. `apply_subst` resolves EfOpen variables before negation checks.

**Proves**: The checker can reason about transitive effect flows.
**Unlocks**: Phase 15 (transitive negation).
**Files**: `std/compiler/checker.lux` (or `checker_effects.lux` after split)
**Verify**: Existing 10 effect golden tests pass. Add 3-4 transitive tests: `!Alloc`
function calling `!Alloc` callee passes; calling Alloc callee fails.

## Phase 15: Transitive `!Alloc` Proof — Medium

**What**: With effect unification, implement resolve-then-check for negation. Open rows
rejected under negation (closed-world). Close ownership stubs: real `walk_expr` (count
uses for affine check) and `check_ref_escape` (linear scan of return expression).

**Proves**: `!Alloc` end-to-end through self-hosted pipeline. Real-time safety claim
provable through Lux's own tools.
**Unlocks**: DSP verification without Rust checker.
**Files**: `std/compiler/checker_effects.lux`, `std/compiler/checker_ownership.lux`
**Verify**: Port ownership/!Alloc golden tests from `examples/ownership*.lux`.

## Phase 16: Refinement Solver Port — Small

**What**: Port Rust `solver.rs` (190 lines, pure recursive eval) to Lux.
`check_refinement(predicate, value) -> Proven | Disproven | Unknown`. Hook into
FnStmt and LetStmt for type aliases with predicates. The solver itself is Pure, !Alloc —
verified by the checker that invokes it (self-referential proof).

**Proves**: Compile-time property verification through self-hosted pipeline.
**Unlocks**: `type Sample = Float where -1.0 <= self <= 1.0` works end-to-end.
**Files**: New `std/compiler/solver.lux` (<200 lines), `std/compiler/checker.lux`
**Verify**: Port 9 refinement unit tests + 2 error tests to golden files.

## ~~Phase 17: Wire Checker into compile()~~ ✓ Complete (2026-03-25)

**What**: `compile(source)` in codegen.lux now runs the checker before codegen:
`lex → parse → check → codegen`. Added `compile_checked()` returning both chunk
and check result.

**Proves**: Self-hosted pipeline enforces type safety. Rejected programs don't compile.
**Unlocks**: Oracle testing (Phase 18), teaching output grounded in real inference.
**Files**: `std/compiler/codegen.lux`, `tests/examples.rs`, `examples/type_error_test.lux`
**Verify**: 3 golden tests pass: checked compile, compile_checked with type info, effects through checker.

## Phase 18: Oracle Testing — Medium

**What**: Systematic harness running every `examples/*.lux` through both Rust pipeline
and self-hosted pipeline, comparing outputs. Discrepancies become targeted fixes.

**Proves**: Self-hosted pipeline has functional parity with Rust pipeline.
**Unlocks**: Phase 19 (self-hosted as primary). Trust threshold for removing Rust.
**Files**: New `examples/oracle_test.lux` or `tests/oracle/`, pipeline fixes
**Verify**: Self-verifying. Target: 100% of examples pass oracle testing.

## Phase 19: Self-Hosted Pipeline as Primary — Medium

**What**: Flip the `lux` CLI to route through self-hosted pipeline by default. Rust
pipeline becomes fallback (`--rust` flag). Error formatting parity with Elm-quality
Rust errors (did-you-mean, exhaustive hints, effect suggestions).

**Proves**: Users interact with Lux through Lux.
**Unlocks**: Lux-first development. Phase 22 (retire Rust checker/parser).
**Files**: `src/main.rs` (routing), `std/compiler/checker.lux` (error formatting)
**Verify**: All golden-file tests pass via self-hosted. `lux --rust` = identical output.

## Phase 20: Codegen Coverage (14 Missing Opcodes) — Medium/Large

**What**: Close gap between 32 self-hosted opcodes and all 46. Missing: tail calls,
evidence opcodes, some pattern-match opcodes. Split codegen.lux (1094 lines) before
extending: `codegen.lux`, `codegen_patterns.lux`, `codegen_effects.lux`.

**Proves**: Self-hosted codegen complete. Can compile any program Rust codegen compiles.
**Unlocks**: Phase 21 (self-compilation verification).
**Files**: `std/compiler/codegen.lux` → split into 3 modules
**Verify**: Evidence-passing, tail calls, complex patterns compile correctly.

## Phase 21: Self-Compilation Verification — Small + Debug

**What**: Run self-hosted compiler through itself. Verify the output bytecode is
semantically correct (self-compiled checker checks programs correctly, oracle-verified).

**Proves**: Bootstrap completeness. Self-hosted pipeline stable under self-application.
**Unlocks**: Phase 22 (retire Rust checker).
**Files**: `std/compiler/`, `examples/oracle_test.lux` (extended)
**Verify**: Self-compiled checker passes oracle on all 48+ tests.

## Phase 22: Retire Rust Checker + Parser — Medium

**What**: Delete `src/checker/` and `src/parser/`. Rust codebase = main.rs + VM + token.rs.
Thread self-hosted checker errors through CLI for display.

**Proves**: Semantic intelligence entirely in Lux. ~2000 lines of Rust deleted.
**Unlocks**: New features implemented only in Lux.
**Files**: `src/checker/` (deleted), `src/parser/` (deleted), `src/main.rs`
**Verify**: All tests pass with checker/parser deleted. `cargo check` clean.

---

## Backend Arc (Phases 23-27)

### Phase 23: Backend Target — WASM First (decided 2026-03-25)

WASM first, native later. The state machine transform (the hard problem) is
platform-agnostic — implement once, emit to either target. WASM gives Lux a
distribution story immediately: browser playground, WASI, edge. Native comes
later reusing the same LowIR, adding register allocation and ELF/Mach-O emission.

### Phase 24: Effect Handler State Machine Transform — Large

**What**: Rewrite `HandleExpr` into explicit state machines. Each `resume` point =
numbered state. Handler state = struct. Runtime loop drives transitions. Output:
`LowIR` with no Handle/Perform/Resume — only Loop, Switch, State, Call.

Written in Lux as a compilation pass (handler over `Compiler` effect). Validated
against existing VM tests via a LowIR interpreter before any backend emission.

**Proves**: Effects are first-class compiled constructs, not interpreter magic.
**Unlocks**: Phase 25 (WASM emitter) and eventual native emitter.
**Files**: New `std/compiler/lower.lux` (<500 lines)
**Verify**: Programs with handle/resume produce identical output before and after transform.

### Phase 25: WASM Emitter — Large

**What**: `LowIR -> WASM`. Start with WAT (text format) for debuggability. Handle
arithmetic, locals, calls, loops/switches from state machine, linear memory for dynamic
values. Small JS/WASI runtime shim for builtins.

**Proves**: Lux programs run without Rust.
**Files**: New `std/backend/wasm_emit.lux`, `std/backend/wasm_types.lux`
**Verify**: Subset of examples compile to WASM, run in Node.js, output matches.

### Phase 26: WASM Bootstrap — Medium

**What**: Compile the Lux compiler itself to WASM. `lux.wasm` compiles test programs.
Oracle-verify against Rust-bootstrapped output.

**Proves**: Self-hosting at binary level. Users need no Rust toolchain.
**Files**: `bootstrap/lux.wasm`, verification scripts

### Phase 27: Retire Rust VM — Medium

**What**: Delete `src/vm/`. CLI routes through WASM execution. 3,100 lines of Rust gone.
**Files**: `src/vm/` (deleted), `src/main.rs` (minimized or replaced by shell script)

---

## Endgame (Phases 28-29)

### Phase 28: Self-Contained Bootstrap — Large

**What**: `lux-bootstrap.wasm` is a pre-built minimal artifact. Users download it, it
compiles the full compiler, no Rust needed. Bootstrap is versioned and auditable.

### Phase 29: Delete Every .rs File

`rm -rf src/ Cargo.toml`. The language IS the compiler IS the teacher IS the proof engine.
Build: `lux build std/compiler/`. Test: `lux test examples/`. No Rust anywhere.

---

## Summary

| Phase | Name | Scope | What it proves |
|-------|------|-------|---------------|
| — | Checker split | Small | File discipline |
| 14 | Effect unification | Med | Transitive effect reasoning |
| 15 | Transitive !Alloc | Med | Real-time safety proof |
| 16 | Refinement solver | Small | Property verification |
| 17 | Wire checker into compile() | Small | Type safety enforced |
| 18 | Oracle testing | Med | Rust/self-hosted parity |
| 19 | Self-hosted as primary | Med | Users use Lux's Lux |
| 20 | Codegen coverage | Med-Lg | Complete compilation |
| 21 | Self-compilation | Sm+Debug | Bootstrap stability |
| 22 | Retire Rust checker/parser | Med | Frontend all-Lux |
| 23 | Backend decision | — | Architecture fork |
| 24 | State machine transform | Large | Effects = compiled |
| 25 | WASM emitter | Large | Rust-free execution |
| 26 | WASM bootstrap | Med | Binary self-hosting |
| 27 | Retire Rust VM | Med | Core Rust gone |
| 28 | Self-contained bootstrap | Large | Zero-Rust install |
| 29 | Delete every .rs file | Sm+Doc | Self-containment |

## Completed: Checker Split + Phase 14 (2026-03-25)

**Checker split** (file discipline):
- Extracted `std/compiler/checker_effects.lux` (288 lines) — EffRow type, merge/union/contains,
  effect negation enforcement, **plus Phase 14 additions**: unify_eff, eff_subst, apply_eff_subst
- Extracted `std/compiler/checker_ownership.lux` (70 lines) — OwnershipTier, ConsumeState,
  check_ownership stubs
- `checker.lux` (976 lines) orchestrates via `import compiler/checker_effects` and
  `import compiler/checker_ownership`

**Phase 14** (effect unification):
- Counter carries `[fresh_id, eff_subst]` — one channel for inference state. Effect
  substitution rides alongside the fresh variable counter, threaded through every
  inference function for free. No signature changes to infer_expr.
- `unify` TFun case now calls `unify_eff(eff1, eff2)` instead of discarding with `_`.
  Effects are first-class in unification.
- `fresh_eff_var(counter)` creates fresh effect variables alongside fresh type vars.
- Call case uses fresh effect variable in expected function type.
- `check_effect_constraints` resolves effect variables via `apply_eff_subst` before
  negation checks.
- 7 transitive golden-file tests (`examples/effect_unification.lux`):
  pure callee in !Alloc ✓, Alloc violation detected ✓, three-level chain ✓,
  Pure calls Pure ✓, effect union from callees ✓, gradient suggestion ✓,
  !Alloc on arithmetic ✓

## Next Session: Phase 15 → Phase 16

**Phase 15** (transitive !Alloc proof):
- Resolve-then-check with open-row rejection
- Real `walk_expr` (count uses for affine check) and `check_ref_escape`
- Handle expression should subtract handled effects from body row
- Port ownership/!Alloc golden tests from `examples/ownership*.lux`

**Phase 16** (refinement solver port):
- Port `solver.rs` (190 lines) to `std/compiler/solver.lux`
- Hook into checker FnStmt and LetStmt for type aliases with predicates
- Port 9 refinement unit tests + 2 error tests to golden files

## Completed: Phase 17 — Wire Checker into compile() (2026-03-25)

- `codegen.lux` imports `compiler/checker`, calls `check_program(stmts)` before
  `compile_program(stmts)` in `compile()`. Self-hosted pipeline now flows:
  lex → parse → **check** → codegen → VM.
- Added `compile_checked(source)` returning `(chunk, check_result)` for downstream
  consumers that want type info alongside the compiled bytecode.
- New `examples/type_error_test.lux` golden test: checked compile, compile_checked
  with env inspection, effects through checked path. All pass.
- All 42 unit + golden tests pass. Zero regressions.
