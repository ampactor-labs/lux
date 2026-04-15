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

**Implementation references (2024-2026):**
- Wasm 3.0 (Sep 2025) stabilized native `throw`/`try-catch`; a Diagnostic "throw" can lower to a WASM exception instead of a return-sentinel. [Wasm 3.0 announcement](https://webassembly.org/news/2025-09-17-wasm-3.0/).
- Academic grounding for codegen-as-effect: *Type-Safe Code Generation With Algebraic Effects and Handlers* (GPCE 2024). [Paper](https://2024.splashcon.org/details/gpce-2024-papers/2/Type-Safe-Code-Generation-With-Algebraic-Effects-and-Handlers).

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

**Implementation references (2024-2026):**
- **Polonius 2026 alpha** abandoned Datalog for location-sensitive reachability over a subset+CFG graph with **lazy constraint rewrites** — the right shape for Lux's ownership pass; do NOT build a Datalog-style side structure. [Project goal](https://rust-lang.github.io/rust-project-goals/2026/polonius.html).
- **Scala 3 reach capabilities** (`x*`) are a syntactic precedent for capabilities reachable through a value — information Lux already tracks in the effect row. [Reference](https://docs.scala-lang.org/scala3/reference/experimental/cc.html).

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

**Implementation references (2024-2026):**
- **Koka evidence passing** (ICFP 2021, C backend 2024): when the handler set at a call site is monomorphic (which the DAG proves), emit `call $h_foo` directly instead of `global.get $__ev_op_foo; call_indirect`. **This kills the residual `val_concat`/`val_eq` polymorphic-fallback drift that made `lux3.wat ≠ lux4.wat`.** [Paper](https://xnning.github.io/papers/multip.pdf).
- **Salsa 3.0 / `ty`** (Dec 2025): convergent answer to "what subst representation?" — mutable flat array with **epoch + persistent per-module overlay**. Module-granular memoization sufficient; per-definition fine-grained is overkill (Pyrefly engineering retrospective). [ty / Salsa 3.0](https://lobste.rs/s/zjq0nl/ty_extremely_fast_python_type_checker).
- **Liquid Haskell 2025** overhaul: the biggest structural win was "stop re-typechecking modules; reuse the AST directly." Lux's `pipeline.lux:424` per-module `s` is the symptom this cures. [Release](https://www.tweag.io/blog/2025-03-20-lh-release/).
- **Polonius 2026 alpha** — lazy constraint graph rewrite. Applies equally to ownership (Item 3) and to env lookups here. [Project goal](https://rust-lang.github.io/rust-project-goals/2026/polonius.html).

## 7. The Effect Pipeline as an Execution Tree
When `handle { check_program() } with Diagnostic` is executed in Lux, the resulting compilation isn't a straight-line Call Stack. It is an **Effect Execution Tree**.

Nodes within the compiler (`infer`, `lookup`) act as generators, bubbling specific structured requests (`Alloc`, `Network`, `Diagnostic`) up the tree into isolated Router Hubs (Handlers). By explicitly separating the *Semantics* (The DAG algorithm) from the *Routing* (The Effect Tree handlers), Lux achieves total architectural purity without compromising O(1) mutability for the IDE interface.

**Implementation references (2024-2026):**
- **Lexa** (OOPSLA 2024) — direct stack-switching compilation of lexical effect handlers; linear-time dispatch vs quadratic for deep handler stacks. Native-backend optimization; pairs with Item 6's monomorphic evidence. [Paper](https://cs.uwaterloo.ca/~yizhou/papers/lexa-oopsla2024.pdf).
- **Modal effect types** (POPL 2025 / POPL 2026) provide a unified theoretical framing of rows and capabilities as modal effects — theoretical grounding for the Execution Tree as a routing calculus over handler modalities. [POPL 2025](https://homepages.inf.ed.ac.uk/slindley/papers/modal-effects.pdf) · [POPL 2026](https://popl26.sigplan.org/details/POPL-2026-popl-research-papers/34/Rows-and-Capabilities-as-Modal-Effects).

## 8. Affine-Tracked `resume` (candidate — from 2024-2026 research)

*Affect* (Van Rooij & Krebbers, POPL 2025) distinguishes one-shot from
multi-shot continuations in the **type system**, using affine types for
the continuation variable. The compiler then picks the efficient runtime
strategy per handler: one-shot can stack-allocate/stack-move; multi-shot
must heap-copy.

**Why Lux wants this:** Lux currently ships Replay + Fork as handler-level
runtime strategies — the cost is paid at every resume call. An affine
annotation on `resume` vs `resume*` (or tracking `own Resume` vs `ref
Resume`) lets the type system pick the implementation automatically. This
is "the inference IS the light" applied to continuations.

**Fit:** one-line type-system extension + codegen fork. Low risk. Ships
after Item 6 (DAG env monomorphizes the choice statically).

**Reference:** [Affect POPL 2025](https://iris-project.org/pdfs/2025-popl-affect.pdf).
