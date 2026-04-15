# Arcs — The Development Narrative of Lux

*Phases numbered. Arcs narrated. This is the canonical history.*

Lux's development organized itself into **arcs** — long structural
chapters, each ending when a foundation hardens and a new layer of
abstraction becomes reachable. Phases are the fine-grained numbered
steps; arcs are the story.

The *ROADMAP.md* shows where we're going. This file shows where we've
been and exactly what got us here.

---

## Arc 0 — The Rust Foundation

*"Every language starts as a parasite." — DESIGN.md*

The language design was prototyped on a Rust-hosted bytecode VM. The
goal was to prove the thesis: algebraic effects + refinement types +
ownership inference compose into something greater than their sum.

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
| 4 (stdlib) | sort/enumerate/min/max/clamp/flat_map/unique/words/lines to pure Lux | HEAD |
| ML | ML framework: autodiff via effects, XOR trains to convergence. **Thesis proven.** | HEAD |
| ML+ | Parser newline-aware postfix, checker numeric inference (no more `: Float` ceremony) | HEAD |
| 7A | Handler state as return value — eliminates `get_tape()` anti-pattern | b33d1ee |
| 7A.5 | Let destructuring — tuple/list/wildcard/record patterns in let bindings | HEAD |
| 7C | Handler composition — `handler` top-level item, inheritance (`: base`), `use` clause | HEAD |
| 7B | Tail-resumptive fast-path — VM skips continuation capture for `resume(pure_expr)` | 1ec1d77 |
| 7+ | Evidence-passing (local) — direct handler dispatch for evidence-eligible ops | HEAD |
| 8A | Effect algebra (negation) — `!Effect`, `Pure` constraints | HEAD |
| 8A-DSP | Effect-algebraic DSP framework — std/dsp/, pipe-first, four-mode proof | HEAD |
| 8B | Effect subtraction `E - F` — desugars to negation; readable sandbox patterns | HEAD |
| 8C | Teaching compiler (`--teach`) — gradient engine foundation | HEAD |
| 8D | Evidence-passing for higher-order functions — `dsp_sandbox` passes | HEAD |

**Arc 0 outcome:** A Rust-hosted bytecode VM that executes the full
effect system, ownership, refinements, and teaching. The language is
real. The thesis holds.

---

## Arc 1 — Self-Hosting

*"If Lux can express its own compiler cleanly, it can express anything."*

The compiler gets rewritten in Lux. Every module. The Rust checker gets
deleted. What remains of Rust is scaffolding: the lexer, parser, and
bytecode VM that execute the self-hosted pipeline.

| Phase | What | Commit |
|-------|------|--------|
| 9A | Self-hosted lexer (`std/compiler/lexer.lux`) | HEAD |
| 9B | Self-hosted parser (`std/compiler/parser.lux`) — ADT-based recursive descent | HEAD |
| 9C | Self-hosted type checker (`std/compiler/checker.lux`) — HM + unification + occurs check | HEAD |
| 9D | Self-hosted codegen (`std/compiler/codegen.lux`) — bytecode emitter + disassembler | 81b8ed7 |
| 9E | Why Engine (`std/compiler/checker.lux`) — 14 Reason variants, explain at any depth | 3b2eae4 |
| 9F | Self-compilation — match expressions, lambdas, type declarations, import paths, read_file | 1b951f6 |
| 9G | Elm-quality errors — Levenshtein did-you-mean, exhaustive-match hints, effect-violation fixes | 64e5793 |
| 10A | Ownership as effect — `own` = affine, `ref` = scoped, if/else branch merging for linearity | c028f75 |
| 10B | `!Alloc` transitivity — resolve-then-check, open-row rejection (Approach B) | HEAD |
| 11A | Refinement type syntax — `type Name = Base where predicate`, `self` references typed value | HEAD |
| 11B | Refinement verification — `solver.rs`, literal substitution, Proven/Disproven/Unknown | HEAD |
| 12A | Self-hosted VM (`std/vm.lux`) — 930 lines, 46 opcodes, 45 builtins. fib(10)=55 in Lux. | cda9833 |
| 13A | Effects all the way down — `vm_resume`, checker real inference for all expr variants | fb1bf35 |
| 13B | Effect handler golden-file verification — 10 effect tests via self-hosted pipeline | 607baa1 |
| 14 | Checker split + effect unification — `checker_effects.lux`, Counter carries eff_subst | a6de722 |
| 15 | Ownership + SExpr spans + diagnostics — `parse_fn_params` with `own`/`ref`, caret underlines | HEAD |
| 16 | Did-you-mean + exhaustive match + refinement solver (all self-hosted) | 2c73e67 |
| 17 | Oracle parity — self-hosted vs Rust: 27/30 match, 0 mismatches, 3 surpass Rust | 26a412d |
| 18 | Self-hosted pipeline as default — `lux run` / `lux check` route through Lux | c26b942 |
| 19 | **Rust checker deleted** — 4,200 lines retired. The student surpassed the teacher. | c84cd43 |
| 20A | Self-hosted let-patterns — constructor destructuring in let bindings | 277b291 |
| 20B | Tuple match patterns — `PTuple` variant, zero parse errors across all modules | 03244d0 |
| 21 | **Arc 3 Phase 2: Effect purity** — 272 functions across 9 modules annotated `with Pure` | 15be0d0..4718c09 |
| 22 | **Diagnostic effect** — 11 println sites in checker replaced with effect operations | e2bebb9 |

**Arc 1 outcome:** The compiler is Lux. The Rust checker is gone. The
self-hosted pipeline is the default. Every improvement going forward is
written in Lux and compiled by Lux.

---

## Arc 2 — The Ouroboros

*"Stripping Rust from the pipeline strips its charity."*

Target: the self-hosted compiler emits WebAssembly, then the WASM
compiler emits itself, with no Rust in the loop. Every "cheap flat
question" that the Rust VM was answering charitably must now be
answered by Lux's own graph structure.

| Phase | What | Commit |
|-------|------|--------|
| F | **LowIR** — 26-variant ADT. Three-tier handler classification. `lux lower` CLI. 541 lines. | 3731c6a..f5aaf97 |
| G | **WASM emitter** — LowIR → WAT. fib(10)=55 on wasmtime. 313 lines, 30 Pure. | 113713f..b100617 |
| G+ | Strings, handler state, ADTs, match, closures — The Ultimate Test. Runtime split to wasm_runtime.lux. | 6a130fa..01aa77d |
| G++ | Perfection Plan session — 6 fixes (type_of shadow, rewrite→Call, locals shadow, val_eq, list_concat) | 63964ae..d7f7274 |
| G³ | **Evidence passing** — effects flow across function boundaries in WASM. 8/8 crucibles. | ce05534 |
| G4 | **Arc 2 Ouroboros Bootstrap** — O(N²) Snoc list bottlenecks erased. Recurse-First Topological Traversal. Native `lux4.wasm` from `lux3.wasm` without the Rust VM. | HEAD |
| G5 | **Inliner deletion + name-collision hygiene + cross-module TVar integrity** — ~150 lines removed (apply_rewrite / find_rewrite), memory.lux flat-array shadows deleted, count_fresh_vars wired at pipeline.lux:424. `lux4.wasm` now compiles `counter.lux` to working output. Semantic Ouroboros closed 2026-04-15. | HEAD |

**Arc 2 outcome (2026-04-15):** `lux3.wasm` (2.4 MB WAT) builds via the
Rust VM in ~6 min. `lux3.wasm` then compiles the self-hosted source to
`lux4.wat` — UNRESOLVED=0, validates. `lux4.wasm` compiles
`counter.lux` to valid WAT in ~2 s, which in turn compiles to a wasm
that runs to exit 0. The Rust VM's charity is no longer load-bearing.

**Semantic vs strict closure:** lux3.wat and lux4.wat differ by ~4
lines — 12 `val_concat` polymorphic-fallback sites in lux4 whose
element types inferred as TVar (runtime-correct but textually drifted).
The structural cure — unified substitution across modules (current
code gives each module a private `s`) — is the same design item as
Arc 3 Item 5 (DAG env), so strict byte-perfect fixed-point is
carried forward instead of tactically patched.

**Bootstrap hygiene now enforced:**
- `bootstrap/tools/preflight.sh` runs before `stage0` (<1 s) and
  hard-fails on: duplicate top-level fn names, duplicate effect-op
  names, signature mismatches, flat-array patterns in list-named fns,
  println/print as a value.
- `bootstrap/tools/check_wat.sh` runs after stage2 (<1 s) and
  hard-fails on: UNRESOLVED markers, new polymorphic-fallback sites
  vs baseline, null-function-pointer patterns.
- `bootstrap/tools/baseline.sh` fingerprints lux3.wat / lux4.wat for
  drift detection; promote to golden only after a verified clean close.
- Fast-repro fixtures in `bootstrap/tests/handler_capture*.lux` and
  `list_concat_direct.lux` reproduce the bug classes surfaced during
  Arc 2 close in ~2 s each.

**Previous remaining bottleneck (resolved):** O(N²) `list[i]` loops
throughout the compiler source — fixed via `list_to_flat` primitive
(commit e6e133f).

---

## Arc 3 — Native Superpowers (in progress)

*"We don't need a garbage collector. We already have everything we need
built into Lux's core philosophy."*

See [`ARC3_ROADMAP.md`](ARC3_ROADMAP.md) for the living roadmap. The
seven items in brief:

1. **Effect-driven diagnostics** — structured `Diagnostic` effects, not
   inline strings. Frees the compiler's semantic core from O(N³)
   Levenshtein and string concatenation.
2. **Scoped memory arenas** — bump-allocator *handlers* (not GC).
   Heavy-functional code runs inside a scope that drops in O(1).
3. **Ownership enforcement** — the existing ownership pass now protects
   scope-escapes from arenas. Use-after-free becomes a compile error.
4. **`stderr` support** — diagnostics stop corrupting `stdout`. The
   compiler recovers its voice.
5. **DAG-based compiler** — env as a structural graph, not a linked
   list. O(1) lookup. The single source of truth for every pipeline
   consumer.
6. **Effect execution tree** — `handle { ... } with Diagnostic` produces
   a routed execution tree, not a call stack. Semantics separate from
   routing.
7. **DSP and ML horizons** — scoped arenas enable zero-GC-pause audio;
   `GPU_Alloc` handlers enable transparent tensor offload.

See also:
- `specs/scoped-memory.md` — ownership + arenas deep-dive
- `specs/incremental-compilation.md` — the `.luxi` module-cache design

---

## Arc 4+ — Toward Self-Containment

*"Self-hosted" is "I can compile my own source."
"Self-contained" is: every question Lux asks has an answer that lives
inside Lux. No external oracle. No patient parent. This arc's thesis
is the deletion of every external handler in the chain.*

Today's chain still borrows handlers: Rust VM, `wat2wasm`, `wasm2c`,
`gcc`, `wasmtime`. Each is a dependency that can answer questions Lux's
own graph ought to answer itself. Arc 4+ removes them.

**Phase 0 (Arc 3 opening move, per active plan):** freeze `lux3.wasm` as
a versioned bootstrap artifact, delete `src/`, tag `rust-vm-final`. Before
deletion, run **Diverse Double-Compiling** (Wheeler, [trusting-trust](https://dwheeler.com/trusting-trust/))
to fingerprint-match output of the two independent compilers. This is the
Rust oracle deletion — the largest one in the tree.

Candidate phases ordered by "which external oracle does this delete?"
(this is the selection rule, not "what's cool"):

### Arc 4 #1 — Native WASM binary emitter (deletes `wat2wasm`)

Skip the text format entirely. Lux writes the binary `.wasm` directly.
The info already exists (section layout, type tables, opcode encoding);
we just haven't let it flow through Lux.

Reference implementation pattern: typed section builder emitting LEB128
to a buffer. See [Thunderseethe — emit-base](https://thunderseethe.dev/posts/emit-base/).
Kills the `wat2wasm` dependency. Proves the byte-emission discipline the
native backend will reuse.

### Arc 4 #2 — Native x86 / aarch64 backend (deletes `wasm2c + gcc`)

`std/backend/x86_emit.lux`, `aarch64_emit.lux` — the `Memory` effect
handled directly: `load_i32` → `MOV`, `alloc` → arena on stack,
`fd_write` → syscall. **This is the primary self-containment milestone.**

**Implementation choice decision matrix:**

| Choice | Pros | Cons | Verdict |
|--------|------|------|---------|
| **Hand-rolled x86/aarch64 from LowIR** | No external dependency; aligns with "Lux solves Lux" thesis | Largest implementation cost | **Long-term target.** |
| **QBE via C FFI** ([c9x.me/compile](https://c9x.me/compile/)) | ~70% LLVM perf in ~10% code; portable amd64/arm64/riscv64 | Requires a C toolchain in the build | **Good intermediate step.** |
| **Cranelift** ([cranelift.dev](https://cranelift.dev/)) | 10× faster codegen than LLVM; battle-tested (Wasmtime) | Pulls Rust back into the native path — contradicts Phase 0 | **Rejected** post Phase 0. |
| **LLVM** | Best peak perf | Multi-minute compile times (Lean's experience); external oracle writ large | **Rejected.** |

**Dev-backend split (Roc pattern):** ship two backends — release
(hand-rolled or QBE) + dev (bespoke byte-stitching, surgical-linker) for
interactive rebuild latency. See [Roc surgical linker](https://sycl.it/agenda/day2/roc-surgical-linker/).

### Arc 4 #3 — Self-hosted WASM runtime (deletes `wasmtime`)

Eventually `std/runtime/wasm_vm.lux` so the Ouroboros check doesn't need
`wasmtime`. Only meaningful after #2 lands; otherwise the native path
still needs wasmtime for validation.

### Arc 4 #4 — Capability layer target: WASIp3 (late 2025 RC / mid-2026 stable)

WASIp3 is designed explicitly to eliminate the "function coloring"
problem: async imports connect seamlessly to sync exports. **This is
convergent with Lux's effect algebra.** An `IO + Async` effect row
compiles to a WASIp3 async import without requiring the caller to be
annotated. Target WASIp3 as the primary capability layer. See
[WASIp3 preview (Fermyon)](https://www.fermyon.com/blog/looking-ahead-to-wasip3).

### Arc 4 #5 — Fractional permissions for concurrency

**Shelved.** Vale's region-freeze approach via `!Mutate` on a region
delivers the same "N parallel readers, no mutation" proof using the
existing effect algebra with no numeric permission accounting. See
`SYNTHESIS_CROSSWALK.md` → *Research Neighbors* Tier 4.

### Arc 4 #6 — Projectional AST (storage only)

Downgraded: **content-addressing lives in the `.luxi` cache** (see
`specs/incremental-compilation.md`). Text remains canonical. Darklang's
retreat from structural editing ("buggy and frustrating") and Hazel
staying in research validate rejecting projectional editors. See
`SYNTHESIS_CROSSWALK.md` → *Research Neighbors* Tier 4.

### Arc 4 #7 — Type-directed synthesis (capstone)

Original Phase 9 in `DESIGN.md`. Write the type, derive the code.
Refinement-narrowed proof search. The "top of the gradient." **Generalizes
via effects:** enumerative search, SMT-guided, LLM-guided — all become
handlers on a single `Suggest` effect. The verifier (`check.lux`) is the
oracle; any proposer is a handler. Lean 4's "macros are Lean functions"
is the nearest neighbor; Lux generalizes further. Needs #1–#4 stable first.

### Arc 4 optional — WASM GC as alternative emission target

Wasm 3.0 (Sep 2025) stabilized GC. Kotlin/Scala/Dart/Go/OCaml adopted.
**Rejected as default** because `struct.new` hides allocation, defeating
`!Alloc`. **Option:** Lux could ship a WASM GC backend for pure-functional
code (compiler passes themselves) where the ownership graph proves the
function is GC-safe. Decision deferred to when the native backend is
stable. See [Wasm 3.0 announcement](https://webassembly.org/news/2025-09-17-wasm-3.0/).

---

**The selection rule is not "what's cool" but "which external oracle
does this delete?"** Every arc graduates Lux closer to answering its
own questions.

---

## How to update this file

When a phase completes, add a row to its arc. When a structural shift
happens — a whole class of problem becomes newly expressible, or a
whole class of external dependency becomes newly deletable — begin a
new arc.

Arcs close when their thesis is proven:

- Arc 0 proved **the effect system** — one mechanism, six patterns.
- Arc 1 proved **self-hosting** — the Rust checker was deleted.
- Arc 2 proves **the Ouroboros** — Lux compiles itself to WASM.
- Arc 3 will prove **native superpowers** — arenas, diagnostics, DAG,
  all inside Lux.
- Arc 4+ proves **self-containment** — no external handler remains in
  the production path.

The arc is the unit of proof. The foundation stops needing whatever
the previous arc borrowed.
