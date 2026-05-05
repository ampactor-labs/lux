# Hβ-tooling-runtime-in-inka.md — wasmtime crutch removed

**Status:** Named cascade. Per PLAN-to-first-light.md §3 post-Tier-3.
Plan-doc.

## Context

Today: Inka compiles to WASM and runs via `wasmtime`. wasmtime is a
substantial Rust dependency. Per Anchor 3 — Inka solves Inka. This
cascade removes the wasmtime dependency: either by adding a native
target (composes with `Hβ-emit-native-target.md`) or by writing a
WASM interpreter in Inka.

Two approaches:
- **A: Native target.** Compiler emits to native; no WASM runtime
  needed.
- **B: WASM interpreter in Inka.** A small interpreter parses
  `.wasm` binary and executes it. Useful for environments where
  native compilation isn't available.

This cascade plans BOTH; the user picks per environment.

Replacement target: wasmtime → native execution OR
`tools/wasm-runtime.nx`.

## Handles (positive form — Approach A: native)

1. **Hβ.runtime.native-via-cranelift** — composes with
   `Hβ-emit-native-target.md` Cranelift backend.
2. **Hβ.runtime.native-via-llvm** — composes with same plan's LLVM
   backend.
3. **Hβ.runtime.native-shim** — libc shim for stdin/stdout/proc_exit
   replaces WASI imports.

## Handles (positive form — Approach B: WASM interpreter in Inka)

4. **Hβ.runtime.wasm-binary-decoder** — parse `.wasm` per the WASM
   spec into in-memory representation (sections, types, fns,
   instructions).
5. **Hβ.runtime.wasm-interpreter-loop** — execute fn bodies one
   instruction at a time. Stack-based VM. ~50 opcodes for the core
   subset Inka uses.
6. **Hβ.runtime.wasi-emulation** — `fd_write`, `fd_read`,
   `proc_exit` emulated via Inka's IO effect.
7. **Hβ.runtime.linear-memory** — linear memory as a byte buffer
   in Inka. `i32.load` / `i32.store` translate to byte-buffer
   reads/writes.

## Acceptance (either approach)

- Inka programs run without wasmtime in the toolchain.
- Self-compile fixpoint holds for the chosen approach.
- Boot time + memory profile documented vs. wasmtime baseline.

## Dep ordering

A: composes on `Hβ-emit-native-target.md`. Lands when that does.

B: 4 → 5 → (6, 7) parallel. Self-contained but slower than native.

## Cross-cascade dependencies

- **Gates on:** Phase H + Tier 3 + (Approach A: `Hβ-emit-native-
  target.md`) OR (Approach B: substantial-but-self-contained).
- **Closes:** Anchor 3 fully — Inka has no non-Inka runtime
  dependency.
- **Composes with:** `Hβ-tooling-build-in-inka.md`,
  `Hβ-tooling-assemble-in-inka.md`. Together: a self-hosted
  toolchain.
