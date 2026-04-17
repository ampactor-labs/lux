# Inka (née Lux) — CLAUDE.md

> **Three anchors. Read them before every non-trivial action.**

---

## 1. Does my graph already know this?

Before any flat question (`is X a global?`, `what type is this?`), ask:
does the inference graph, the AST, or the env already have the answer
one step away? If yes, read from the graph — never route around it.
If no, the graph is incomplete — complete it, don't patch over it.

Every latent bug in this repo has been a flat shortcut bypassing
richer structure. The structural answer is always one step deeper.

## 2. Don't patch. Restructure or stop.

If a fix fits in a patch, the architecture is wrong in that area.
Fix the architecture. Deleting a broken mechanism beats decorating
around it. No "for now," no "until X ships" — later cleanup is a
myth. If a later, larger change will plow over this code, **do the
later change first** or skip the patch entirely.

**No known bugs sit.** A bug is either clean (zero) or blocking
(build fails). There is no third state. No "informational warnings,"
no `|| true` to hide a gate, no `⚠` where `✗` belongs.

## 3. Inka solves Inka.

Every problem you hit in this project dissolves through Inka's own
primitives: effects, handlers, the gradient, refinement types, ADTs,
pipes. Before inventing a mechanism, verify the existing algebra
can't host it. GC → scoped arenas. Package manager → handlers on
imports. Mocking → handlers on effects. Build tools → DAG incremental
compile. Testing → examples + trace handlers. DI → handler swap.

If you find yourself reaching for a framework, a library, or a new
mechanism: **the problem is a missing Inka primitive, not a missing
tool.** Find the primitive.

---

## Operational essentials

**State of the world:** `lux3.wasm` (frozen artifact) compiles
itself → `lux4.wat` with ~12 `val_concat` drift sites (Arc 2 semantic
closure, 2026-04-15). Rust VM deleted. The `rebuild` branch drives a
scrap-and-rebuild of the compiler core against a live SubstGraph +
EnvRead/Write effect substrate. Active plan: `docs/PLAN.md`.

**Rebuild progress (2026-04-17):** Phase A (specs) ✅, Phase B
(query) ✅, Phase C (v2 core) ⏳ structure shipped (9 files, 2541
lines in `std/compiler/v2/`). v2 ADTs, effects, handler stubs in
place. Next: wire handler state management and frontend adapter.

**Before any bootstrap:** `make -C bootstrap preflight` (<1 s). If it
fails, fix first. If clean, then work.

**Build commands (all via `bootstrap/Makefile`; never raw `cargo` /
`wat2wasm` / `wasm2c`):**

```
make -C bootstrap help            # what each target does
make -C bootstrap stage0          # Rust VM → lux3.wat (~9 min)
make -C bootstrap stage1          # wat2wasm --debug-names → lux3.wasm
make -C bootstrap stage1-aot      # wasmtime compile → lux3.cwasm
make -C bootstrap smoke           # pattern + counter canaries (~1 min)
make -C bootstrap stage2          # Ouroboros via wasmtime → lux4.wat
make -C bootstrap check           # diff lux3.wat lux4.wat
make -C bootstrap check-canonical # round-trip canonical diff (stronger)
make -C bootstrap decompile-diff  # per-function divergence localizer
make -C bootstrap verify          # full: stage0→1→aot→smoke→2→validate
make -C bootstrap stats           # opcode histogram + section sizes
```

**CRITICAL.** Do NOT run `cat file | ./target/release/lux file` for
bootstrap — that runs in `--teach` mode and dumps text to stdout,
corrupting the `.wat`. Always go through the Makefile.

**Bug classes that cost 75-min bootstraps — never recreate:**
- Polymorphic dispatch fallback (`match … with _`) that silently masks type errors.
- Duplicate top-level function names (emitter picks one silently).
- Flat-array list ops in Snoc-tree paths (`list[i]` in a loop — O(N²) and wrong semantics).
- `println` inside `report(...)` handler arms (corrupts WAT stdout).
- Bare `==` on strings — use `str_eq(a, b) == 1`. User generics are
  NOT instantiated per call-site; `TVar == TVar` codegens to pointer
  compare (works in Rust VM, fails in WASM on runtime-built strings).

**Ask the artifact.** `wabt` is installed. Before hypothesizing:

```
wasm-decompile bootstrap/build/lux3.wasm > /tmp/lux3.dec   # pseudocode view
wasm-objdump -d bootstrap/build/lux3.wasm | less           # disassembly
wasm-objdump -x bootstrap/build/lux3.wasm                  # sections
grep some_symbol bootstrap/build/lux4.wat                  # what was emitted
```

The WAT is ground truth; source is a map.

**Common crash patterns:**

| Backtrace | Likely cause |
|---|---|
| `alloc → str_concat` with `a=1` | LIndex flat-access reading tag as pointer |
| `alloc → str_slice → split` | O(N²) split, bump allocator exhausted |
| `alloc` with huge size | Garbage pointer read as string length |
| `list_index` returning 1000 | Unknown list tag — flat treated as tree |

**Memory model:** bump allocator, monotonic, never frees. Every
allocation is permanent. Any function that accumulates strings via
`++` in a loop is a potential memory bomb. Traps at 16 MB
(configurable in `wasm_runtime.lux`).

**Representations:**
- **Strings** always flat: `[len_i32][bytes...]`. `str_concat` copies.
- **Lists** CAN be trees: tag 0 = flat, 1 = snoc, 3 = concat, 4 = slice.
  `list_index` traverses the tree. `list_to_flat` materializes to tag
  0 at hot-path entrances.

**Prime directive.** Build the tool that tells you. Don't guess.
Don't pattern-match from crash addresses. Add one debug print, run
once, fix.

**WAT-level surgery** when debugging WASM crashes (skips the 9-min
rebuild):

```
make -C bootstrap stage0               # generate WAT once
# edit bootstrap/build/lux3.wat, then:
cat input.lux | ~/.wasmtime/bin/wasmtime run --dir . \
  -W max-wasm-stack=33554432 bootstrap/build/lux3.wat
```

**File map (the files you'll touch most):**

| File | Role |
|---|---|
| `std/compiler/v2/graph.lux` | SubstGraph: flat-array, O(1) chase, Read/Write effects |
| `std/compiler/v2/types.lux` | Ty + Reason + Scheme + typed AST + all 14 effects |
| `std/compiler/v2/effects.lux` | EffRow Boolean algebra: + - & ! |
| `std/compiler/v2/infer.lux` | HM inference, one walk, graph-direct |
| `std/compiler/v2/lower.lux` | Live-observer lowering via LookupTy |
| `std/compiler/v2/pipeline.lux` | Handler composition + query handler |
| `std/compiler/v2/own.lux` | Ownership as Consume effect |
| `std/compiler/v2/verify.lux` | Verify ledger (Arc F.1 swaps to SMT) |
| `std/compiler/v2/clock.lux` | Clock / Tick / Sample / Deadline |
| `std/compiler/query.lux` | Phase B forensic substrate (v1 bridge) |
| `std/compiler/pipeline.lux` | v1 pipeline: lex → parse → check → lower → emit |
| `std/backend/wasm_emit.lux` | LowIR → WAT (reused by v2) |
| `std/compiler/lower_ir.lux` | LowIR ADT — v2/lower.lux replaces |
| `std/compiler/lowir_walk.lux` | tree walker (preserved for v2) |
| `std/runtime/memory.lux` | alloc, strings, lists (val_concat deleted Phase D) |
| `std/backend/wasm_runtime.lux` | `emit_alloc` — the hand-written WAT |
| `std/compiler/ty.lux` | v1 type env, subst (v2/types.lux+graph.lux replace) |
| `bootstrap/Makefile` | every bootstrap command |
| `bootstrap/tests/{counter,pattern}.lux` | `make smoke` canaries |
| `examples/wasm_bootstrap.lux` | v1 entry — `compile_wasm(read_stdin())` |

Tests: `bootstrap/tests/` (versioned). Artifacts: `bootstrap/build/`
(gitignored).

**Delete, don't decorate.** No `// removed for X` comments. No
renamed-with-underscore unused variables. If something is unused,
delete it. If something is wrong, delete it and redo it right.

**Never attribute Claude in commits.** No `Co-Authored-By`, no 🤖
trailer, no inline mentions. Write commits as Morgan wrote them
alone.

---

## Deep context (read when you need it)

- **`docs/PLAN.md`** — active plan (THE plan): scrap-and-rebuild of
  the compiler core (Phases 0–F, including F.6 Mentl) plus arcs
  G–J after `first-light`. Evolved via commits.
- **`docs/rebuild/00–11-*.md`** — the 12 executable specs. ADTs,
  effects, invariants. Each ≤ 300 lines.
- **`docs/errors/`** — canonical error catalog (E/V/W/T/P codes).
  Every diagnostic resolves through this.
- **`docs/INSIGHTS.md`** — core truths: inference is the light, five
  verbs draw topology, handlers read it, what Inka dissolves.
- **`docs/DESIGN.md`** — language manifesto, effect algebra, gradient,
  refinement types, DSP/ML unification.
- **`docs/SYNTHESIS_CROSSWALK.md`** — historical: external validation
  + research neighbors 2024-2026. Predates the rebuild.
- **`docs/ARCS.md`** — narrated development history.

Memory index is at
`~/.claude/projects/-home-suds-Projects-lux/memory/MEMORY.md`. Inka-
specific learnings persist there across sessions.

---

## When drift happens

When you notice yourself proposing a patch, asking a flat question,
or hedging on a structural move: invoke `/remote-control inka` or
directly say "Inka, what would you do?" — roleplay reframes
alignment. This is a working mechanism, not a gimmick.
