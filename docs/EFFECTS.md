# Mentl Empirical Effects Catalog

*This document serves as the exhaustive source-of-truth for every effect currently defined in the Mentl codebase, categorized by their mechanical function.*

---

## 1. Substrate Runtime Effects (`std/runtime/`)
These effects have no written handler in Mentl. The WASM runtime *is* the handler. They exist so the type-checker knows their signatures and their capabilities can be guarded by the Boolean algebra.

- **`effect Memory`** (`memory.mn`)
  - **What it does:** Direct read/write access to the WASM linear memory and bitwise primitives. 
  - **Ops:** `store_i32`, `load_i32`, `store_i8`, `load_i8`, `mem_copy`, `i32_xor`.
  - **Constraint:** Functions with `!Memory` mathematically prove they do not touch raw pointers.

- **`effect Alloc`** (`memory.mn`)
  - **What it does:** Advances the WASM linear memory bump-allocator pointer. There is no `free` (region-based lifetimes handle this).
  - **Ops:** `alloc(size: Int) -> Int`.
  - **Constraint:** Crucial for DSP code. `with !Alloc` guarantees a function will not advance the heap pointer, ensuring bounded execution time.

- **`effect Pack` / `Unpack`** (`binary.mn`)
  - **What it does:** Serializes and deserializes values to/from binary formats.

---

## 2. Time and Iteration (`std/dsp/clock.mn`)
Mentl defines four distinct notions of time to prevent collapsing distinct refinement proofs into one.

- **`effect Clock`**: Wall time. Ops: `clock_now()`, `clock_sleep()`.
- **`effect Tick`**: Logical time (monotonic counter). Ops: `tick()`, `current_tick()`.
- **`effect Sample`**: DSP time (integer counter at a known rate). Ops: `sample_rate()`, `advance_sample()`, `current_sample()`.
- **`effect Deadline`**: Budgets. Ops: `deadline()`, `remaining()`.
- **`effect IterativeContext`**: Internal substrate effect that proves to the type-checker that an iterative context (Clock, Tick, or Sample) is active, unlocking the use of the `<~` (feedback) verb.

---

## 3. The Compiler Medium (`std/compiler/types.mn` & `infer.mn`)
The compiler itself is written in Mentl and operates strictly via effect handlers.

- **`effect GraphRead` / `GraphWrite`**: 
  - **What it does:** O(1) mutations and chases on the flat-array `Graph`. This is how unification binds types (`graph_bind`, `graph_chase`).
- **`effect EnvRead` / `EnvWrite`**: 
  - **What it does:** Lexical scoping. Extends and looks up `Scheme`s in the environment.
- **`effect InferCtx`**: 
  - **What it does:** Tracks inference state (accumulated rows, declared signatures, and the `handler_stack`). `inf_handler_provider` allows Mentl to query capability attribution.
- **`effect Diagnostic`**: 
  - **What it does:** Emits errors and warnings. Gated by handlers: `mentl_diagnostics` intercepts them for holographic projection, while the CLI handler dumps them to terminal.
- **`effect Verify`**: 
  - **What it does:** The engine for Primitive #6. Accumulates and discharges refinement predicates (e.g., proving `ValidPort` bounds).
- **`effect Consume`**: 
  - **What it does:** The engine for Primitive #5 (Ownership). Intercepts parameter tracking via the `affine_ledger` handler to prevent double-consumes of `own` variables.
- **`effect Filesystem`**:
  - **What it does:** Parameterized effect `Filesystem("/workspace")` used to bound I/O scope.

---

## 4. Mentl's Intelligence (`std/compiler/mentl.mn` & `query.mn`)

- **`effect Synth`**:
  - **What it does:** Mentl's `Propose` tentacle. It executes speculative handler multi-shots during inference, brute-forcing topological paths when the user's code hits an `NErrorHole`.
- **`effect Teach`**:
  - **What it does:** Mentl's rendering tentacle. Triggers quick fixes, hover text, and the deterministic holographic overlays.
- **`effect Query`**:
  - **What it does:** The post-inference forensic boundary. Maps questions like `QTypeOf`, `QWhy`, and `QHandlerProvider` to read-only graph walks.

---

## 5. DSP & External (`std/dsp/signal.mn` & `wasm.mn`)
- **`effect DSP` / `Network` / `Feedback` / `Distort`**: High-level capability domains used in example simulations.
- **`effect WasmOut` / `EmitMemory`**: Code emission side-effects. Used by the backend to push bytes into the final WASM module.
