# Hβ-emit-native-target.md — Native target via Cranelift / LLVM

**Status:** Named cascade. Per PLAN-to-first-light.md §3 post-Tier-3.
Plan-doc.

## Context

Mentl currently targets WASM. The kernel — graph + handlers + verbs +
rows — is target-agnostic. This cascade adds a native code target:
Cranelift (lighter, faster compile) or LLVM (heavier, more
optimizations). Per Anchor 5 — every backend IS a handler on the
LowIR contract.

Replacement target: `src/backends/wasm.mn` SIBLING `src/backends/
native.mn` (Cranelift IR emission) and/or `src/backends/llvm.mn`
(LLVM IR emission). The LowIR substrate (`src/lower.mn` output) is
target-neutral; backends consume it.

## Handles (positive form)

1. **Hβ.native.cranelift-builder-effect** — `CraneliftBuild` effect:
   `add_function`, `add_block`, `add_inst`. Default handler links
   against the Cranelift FFI / library.
2. **Hβ.native.lowir-to-cranelift** — translate each LowExpr tag
   (300-329) into Cranelift instructions. LMakeClosure → record
   alloc + fn ptr table; LCall → indirect call; etc.
3. **Hβ.native.llvm-builder-effect** — same shape for LLVM IR.
4. **Hβ.native.lowir-to-llvm** — translate LowExpr to LLVM IR.
5. **Hβ.native.target-handler-swap** — `mentl --target=wasm` /
   `--target=cranelift` / `--target=llvm` selects which `Emit`
   handler installs at the pipeline boundary.
6. **Hβ.native.runtime-shim** — native targets don't have WASI
   imports; provide a libc-shim (or similar) for `read_stdin`,
   `eprint_string`, `proc_exit`.
7. **Hβ.native.fixpoint-validation** — Mentl self-compiles to native;
   the native `mentl` binary compiles the wheel byte-identically to
   the WASM-pipeline output (same source produces same logical
   program).

## Acceptance

- `mentl --target=cranelift` produces `.o` or executable directly.
- `mentl --target=llvm` produces `.ll` or `.bc`; standard tools
  (`llc`, `clang`) link to executable.
- Compile time + runtime performance documented vs. WASM baseline.
- Self-compile fixpoint holds for the chosen native target.

## Dep ordering

(1, 2) and (3, 4) are independent; either backend can land first.
5 (handler swap) gates on at least one backend. 6 (runtime shim) is
needed by any native target. 7 closes the cascade.

## Cross-cascade dependencies

- **Gates on:** Phase H + Tier 3; LowIR stable.
- **Composes with:** `Hβ-emit-binary-direct.md` (parallel handler
  on same Emit interface); `Hβ-tooling-runtime-in-mentl.md` (replaces
  wasmtime crutch with native execution).
- **Builds the wheel** per Anchor 4 — native target is a peer
  handler, not a wrap of the WASM backend.
