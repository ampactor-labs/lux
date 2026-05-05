# Hβ-emit-native-target.md — Native target via Cranelift / LLVM

**Status:** Named cascade. Per PLAN-to-first-light.md §3 post-Tier-3.
Plan-doc.

## Context

Inka currently targets WASM. The kernel — graph + handlers + verbs +
rows — is target-agnostic. This cascade adds a native code target:
Cranelift (lighter, faster compile) or LLVM (heavier, more
optimizations). Per Anchor 5 — every backend IS a handler on the
LowIR contract.

Replacement target: `src/backends/wasm.nx` SIBLING `src/backends/
native.nx` (Cranelift IR emission) and/or `src/backends/llvm.nx`
(LLVM IR emission). The LowIR substrate (`src/lower.nx` output) is
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
5. **Hβ.native.target-handler-swap** — `inka --target=wasm` /
   `--target=cranelift` / `--target=llvm` selects which `Emit`
   handler installs at the pipeline boundary.
6. **Hβ.native.runtime-shim** — native targets don't have WASI
   imports; provide a libc-shim (or similar) for `read_stdin`,
   `eprint_string`, `proc_exit`.
7. **Hβ.native.fixpoint-validation** — Inka self-compiles to native;
   the native `inka` binary compiles the wheel byte-identically to
   the WASM-pipeline output (same source produces same logical
   program).

## Acceptance

- `inka --target=cranelift` produces `.o` or executable directly.
- `inka --target=llvm` produces `.ll` or `.bc`; standard tools
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
  on same Emit interface); `Hβ-tooling-runtime-in-inka.md` (replaces
  wasmtime crutch with native execution).
- **Builds the wheel** per Anchor 4 — native target is a peer
  handler, not a wrap of the WASM backend.
