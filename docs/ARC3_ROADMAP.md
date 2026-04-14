# Arc 3 Roadmap — Native Superpowers & Memory Independence

*The active arc. Captures architectural insights from Arc 2 and the
path to native, memory-aware Lux. For the full narrative and
prerequisites, see [`ARCS.md`](ARCS.md).*

**Crystalized:** 2026-04-12 (during the Ouroboros bootstrap)
**Status:** In progress — scoped on top of Arc 2 fixed-point

### Companion specs

- [`specs/scoped-memory.md`](specs/scoped-memory.md) — ownership +
  arena deep-dive (problem, bootstrap insight, superpowers)
- [`specs/incremental-compilation.md`](specs/incremental-compilation.md)
  — `.luxi` module cache design (the memory-scaling foundation for DAG)
- [`specs/codegen-effect-design.md`](specs/codegen-effect-design.md) —
  `CodegenCtx` as an effect (replaces the manual 10-tuple threading)
- [`specs/ownership-design.md`](specs/ownership-design.md) — the
  ownership-as-effect design that protects arena escapes

---

## 1. Effect-Driven Diagnostics (Mentorship as a Service)

In Arc 2, diagnostics (like "did you mean" Levenshtein suggestions) were computed violently inline during structural passes (like `check.lux`). This polluted the semantic algorithm with heavy text manipulations, leading to O(N³) memory growth and bump-allocator exhaustion.

**The Arc 3 Solution:**
- Structural passes (`parse`, `check`, `infer`) will no longer import string-heavy libraries or generate error text.
- They will instead **yield structured diagnostic effects**: `perform Diagnostic(MissingVariable, name, env)`
- A top-level handler in `pipeline.lux` will catch these effects. 
- *Why this matters*: The core compiler stays purely semantic, brutally fast, and memory-light. The handler translates the semantics into rich, mentorship-driven diagnostic strings at its leisure.

## 2. Scoped Memory Arenas (GC-Free Determinism)

We do *not* need to implement a traditional Garbage Collector (Mark & Sweep) for Lux. 

Because `Alloc` is implemented as an Effect, memory management is natively controllable from user-space Lux. We maintain `wasm_runtime.lux`'s bump allocator as the top-level unbreakable handler, but introduce **Scoped Arenas** for heavy functional operations:

```lux
handle { 
  // Computes diagnostic strings using O(N³) recursive algorithms
  find_similar_name(e, name) 
} with DiagnosticArena
```

When the handler finishes, the `DiagnosticArena` instantly drops its pointer to zero, freeing gigabytes of intermediate string allocations safely and deterministically without GC pauses.

## 3. Eliminating Use-After-Free via Ownership

Scoped Arenas natively introduce Use-After-Free vulnerabilities (dangling pointers). Lux solves this via its existing **Ownership compiler pass**.

If the diagnostic handler returns a string, that string is statically known to be owned by `DiagnosticArena`. If the developer tries to return it outside the scope, the compiler enforces an ownership violation. The developer is explicitly forced to `copy` the string into the parent's `Alloc` scope. 

**Result**: We get the flawless memory safety of Rust and the frictionless ergonomics of a functional language, completely orchestrated by our native effect system.

## 4. Standard Error (`stderr`) Native Support

Arc 2 relied completely on `stdout` (`print()`), meaning diagnostics had to be silenced under WebAssembly so they wouldn't corrupt the `.wat` output stream.

**The Arc 3 First Step:**
- Implement `eprint_string` in `memory.lux` mapping to `fd_write(2, ...)`.
- Update `report()` to yield to `stderr`.
- Remove `silent_diagnostics` from `compile_wasm`.
- *Status*: Restores the compiler's voice and mentorship without compromising binary emission.

## 5. DSP and Machine Learning Horizons
By combining Scoped Arenas and Effects:
- **Audio (DSP)**: Handlers guarantee zero-GC-pause real-time audio threads.
- **Machine Learning**: `GPU_Alloc` handlers can intercept mathematical tensor operations and transparently assign them to GPU VRAM, while `Tensor[C,H,W]` types provide compile-time guarantees against runtime tensor dimension mismatches.  

## 6. The Compiler as a Data Structure: The Dependency DAG
In traditional compilers, the `env` (environment) is a linear list or stack. In Arc 2, representing `env` as an immutable linked list led to an O(N²) time complexity catastrophe during bootstrap (due to repeated `list[i]` full-traversals from the root node on every check).

**The Arc 3 Evolution:**
- The Global Environment (`env`) and Substitution Map (`subst`) must evolve from immutable lists into **O(1) Data Structures**.
- `subst` will be a mutable Flat Array, capitalizing on the sequential nature of Hindley-Milner type inference.
- The `env` will become a **Directed Acyclic Graph (DAG)**. 
- *The Single Source of Truth*: The DAG *is* the single source of truth for the entire compiler pipeline. A variable definition isn't just a type mapping; it's a structural node with directed edges pointing exactly to its dependencies.
- When the IDE Handler intercepts an `Infer` effect, it doesn't just read an error string. It structurally queries the DAG to determine *precisely* what broke and exactly how far the blast radius extends.

## 7. The Effect Pipeline as an Execution Tree
When `handle { check_program() } with Diagnostic` is executed in Lux, the resulting compilation isn't a straight-line Call Stack. It is an **Effect Execution Tree**.

Nodes within the compiler (`infer`, `lookup`) act as generators, bubbling specific structured requests (`Alloc`, `Network`, `Diagnostic`) up the tree into isolated Router Hubs (Handlers). By explicitly separating the *Semantics* (The DAG algorithm) from the *Routing* (The Effect Tree handlers), Lux achieves total architectural purity without compromising O(1) mutability for the IDE interface.
