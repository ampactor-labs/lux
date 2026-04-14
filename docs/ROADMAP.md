# Roadmap

*Not a checklist — a gradient. This file is the single place to check
"where is Lux now" and "where does it go next."*

For the full manifesto of **what Lux IS**, see [`DESIGN.md`](DESIGN.md).
For the narrated **history** of how it got here, see [`ARCS.md`](ARCS.md).
For deep **insights** that fall out of the design, see [`INSIGHTS.md`](INSIGHTS.md).

---

## Current State — 2026-04-13

### What works today

| Subsystem | Status |
|---|---|
| Effect system (declare, handle, resume, handler state) | ✅ Shipped |
| Multi-shot continuations (replay + fork) | ✅ Shipped |
| Nested handler composition | ✅ Shipped |
| Effect algebra (`+`, `-`, `&`, `!`, `Pure`) | ✅ Shipped |
| Teaching compiler (`--teach` + gradient engine) | ✅ Shipped |
| Self-hosted pipeline (lexer, parser, checker, codegen — all Lux) | ✅ Shipped |
| Self-hosted VM (`std/vm.lux`) | ✅ Shipped |
| Ownership enforcement (`own` affine, `ref` scoped) | ✅ Shipped |
| Refinement types with Z3 verification | ✅ Shipped |
| Row-polymorphic records | ✅ Shipped |
| Pipe operators (`\|>`, `<\|`, `><`, `~>`) | ✅ Shipped |
| `!Alloc` transitivity (Approach B: inferred) | ✅ Shipped |
| Diagnostic effect (cleanup of 11 println sites) | ✅ Shipped |
| LowIR + WASM emitter — `lux wasm` produces WAT | ✅ Shipped |
| Rust checker deleted (4,200 lines retired) | ✅ Shipped (c84cd43) |
| 272 purity proofs (9 self-hosted modules) | ✅ Shipped |
| WASM bootstrap: `lux3.wasm` built by Rust VM in 9 min | ✅ Shipped |
| Native ELF via `wasm2c + gcc -O2` | ✅ Shipped (bootstrap/build/lux3-native) |
| **Ouroboros fixed-point** (`lux3.wasm == lux4.wasm`) | 🔄 Blocked on O(N²) list loops |

### Near-term focus: finish Arc 2

See `AGENTS.md` → *Known Remaining Issue*. The compiler source uses
`list[i]` index-based loops that are O(1) on the Rust VM (contiguous
`Vec`) but O(N) in WASM (Snoc trees). Each such loop is O(N²) in the
Ouroboros. Fix pattern: convert to `list_pop` tail recursion. Target
files named there.

### Next: Arc 3 — Native Superpowers

See [`ARC3_ROADMAP.md`](ARC3_ROADMAP.md). Seven items, each a structural
shift, each resolvable through Lux's own abstractions (effects,
handlers, ownership, the gradient). In brief:

1. Effect-driven diagnostics
2. Scoped memory arenas
3. Ownership enforcement around arenas
4. `stderr` support
5. DAG-based compiler (env as structural graph)
6. Effect execution tree
7. DSP + ML horizons (scoped arenas enable zero-GC-pause audio;
   `GPU_Alloc` handlers enable tensor offload)

### Beyond Arc 3 — open

- **Custom native x86 backend** (the destination of the `wasm2c`
  stepping stone). See `DESIGN.md` → *Custom Native Backend*.
- **Projectional AST + content addressing**. See
  [`SYNTHESIS_CROSSWALK.md`](SYNTHESIS_CROSSWALK.md) → Pillar I.
- **Type-directed synthesis** — write the type, derive the code.
  Refinement-narrowed proof search. See `DESIGN.md` → *Phase 9*.

---

## The Gradient

The operational view of "where am I on the power curve."

| You write | The compiler can |
|-----------|------------------|
| Nothing | Infer everything — it runs |
| Types | Catch mismatches, enable completion |
| `with Pure` | Memoize, parallelize, compile-time eval |
| `with !Alloc` | Prove real-time safety, enable GPU offload |
| `own` / `ref` | Deterministic cleanup, zero-copy |
| Refinement types | Prove properties, eliminate runtime checks |
| Full signature | Type-directed synthesis, formal verification |

Each annotation is a conversation with the compiler. You tell it
something; it tells you what that unlocks. There is no `lux level set`.
There is only more or less knowledge flowing between you and the
machine.

---

## The Dependency Lattice

```
Effect algebra ──→ Ownership ──→ Native backend ──→ Self-containment
     │                │               │
     │                └──→ Refinements ──→ Synthesis
     │
     └──→ Gradient system ←── threads through everything
```

Each step unlocks the next. The native backend needs ownership (to emit
drop/move). Synthesis needs refinements (to narrow search). The gradient
system threads through all of them because *every* annotation moves a
program up the lattice.

---

## The masterpiece test

Before every change:

> **Is this what the ultimate programming language would do?**
> If not, design the way it SHOULD be.

Not "is this good enough." Not "does this work." Is this **the best it
could possibly be**? Accept nothing less.
