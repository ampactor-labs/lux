# Agent Handoff — Arc 2 Ouroboros

*What's in progress. What's broken. How to rebuild.
For narrated history, see `docs/ARCS.md`.
For next arc, see `docs/ARC3_ROADMAP.md`.
For the build recipe, see `bootstrap/README.md`.*

**Last updated:** 2026-04-14

## Current State

The Lux compiler is bootstrapping to WebAssembly. The pipeline:

```
Rust VM compiles → lux3.wasm (Lux compiler as WASM, built by Rust)
lux3.wasm compiles → lux4.wasm (Lux compiler as WASM, built by itself — NO RUST)
```

Active branch: `arc23-execute`. The closing move for Arc 2 (54-site
polymorphic-compare fix + 4 residuals + ADT-match pattern extraction)
is committed and queued for verify.

**What works:**
- `lux3.wasm` — built by Rust VM in ~9 minutes via `make -C bootstrap stage0 stage1`.
- All Arc 2 memory optimizations are applied (see below).
- `list_to_flat` (e6e133f) eliminated the O(N²) Snoc traversal class —
  `list[i]` is a single `i32.load` on hot paths in WASM.
- WASM tail-call emission (f611794) — `return_call` in tail position,
  fixes str_eq_loop stack overflow.
- Polymorphic pointer-compare class CLOSED (aaecb0c, 853a2e1, 2120c46,
  plus 4 residual `== ""` sites). 54 sites across 19 files now use
  `str_eq(a, b) == 1` / `len(x) > 0`. See "Polymorphism Pattern" below.

**Pending (blocks Arc 2 close):**
- `make -C bootstrap verify` must pass end-to-end: stage0 → stage1 →
  AOT compile → smoke (pattern canary + counter) → stage2 (~45 min) →
  wat2wasm + wasm-validate on lux4.wasm → counter via lux4.
- If verify passes: Arc 2 ceremony commit + doc updates + celebrate.
- If verify fails: use `make decompile-diff` to localize the next
  divergence; check `build/{lux3,lux4}.preamble.log` for VM warnings.

## Build Commands

All bootstrap commands go through `bootstrap/Makefile`. Do not run the
raw `cargo` / `wat2wasm` / `wasm2c` invocations by hand — the Makefile
encodes the exact flags (`--debug-names`, `--enable-tail-call`, etc.)
and the progress monitor + timing that make long runs observable.

```bash
make -C bootstrap help           # what each target does
make -C bootstrap stage0         # Rust VM → lux3.wat         (~9 min)
make -C bootstrap stage1         # wat2wasm --debug-names     → lux3.wasm
make -C bootstrap stage1-aot     # wasmtime compile           → lux3.cwasm (AOT)
make -C bootstrap smoke          # pattern + counter canaries (~1 min gate)
make -C bootstrap stage2         # Ouroboros via wasmtime     → lux4.wat
make -C bootstrap check          # diff lux3.wat lux4.wat     → fixed-point verdict
make -C bootstrap check-canonical  # round-trip canonical diff (stronger)
make -C bootstrap decompile-diff   # per-function divergence localizer
make -C bootstrap verify         # full: stage0 → 1 → aot → smoke → 2 → validate
make -C bootstrap stats          # opcode histogram + section sizes
make -C bootstrap stage1-native  # wasm2c + gcc -O2 → lux3-native (BROKEN:
                                 # wabt 1.0.36 --enable-tail-call has a
                                 # codegen bug with undeclared locals in
                                 # return_call bodies; blocked upstream)
```

Tests live in `bootstrap/tests/` (in-repo, versioned). Generated artifacts
land in `bootstrap/build/` (gitignored).

> **CRITICAL:** Do NOT run `cat file | ./target/release/lux file` for
> bootstrap — that runs in `teach` mode and dumps diagnostic text to
> stdout, corrupting the `.wat` output. Always go through the Makefile
> or the `wasm` CLI subcommand.

## Memory Optimizations Applied (All Verified ✅)

### Bug 1: LIndex Structural Desync
**Root cause:** `LIndex` node defined with 3 fields but constructed with 4 (an `is_tuple` boolean). The walker stripped the 4th field. The WASM emitter read garbage as `is_tuple`, causing ALL array indexing to compile as flat pointer arithmetic instead of calling `$list_index`.

**Files:** `lower_ir.lux`, `lowir_walk.lux`, `lower_print.lux`, `lower.lux`

### Bug 2: O(N²) Split → O(N) Rewrite
**Root cause:** `split_find` allocated a new string per character position. Each recursive `split` call copied the entire remaining string.

**Fix:** `split_match_at` (in-place byte comparison) + `split_from` (offset into original string). Zero allocations during scan.

### Bug 3: O(N²) strip_imports → Eliminated
**Root cause:** `split("\n") |> filter |> join("\n")` on every imported module. Even with O(N) split, `join` copies the growing accumulator.

**Fix:** Removed `strip_imports` from hot path. Parser creates `ImportStmt` nodes; checker/lowerer/emitter already ignore them.

### Bug 4: O(N³) Levenshtein → Neutered
**Root cause:** `find_similar_name` and `find_similar_type` computed edit distances using `list++` inside nested loops, creating massive garbage in the bump allocator.

**Fix:** Both functions return empty string during bootstrap. Diagnostics are deferred to Arc 3 effect-driven architecture.

### Bug 5: O(N²) env_lookup → O(1) via list_pop
**Root cause:** `env_lookup_at(env, name, i)` used `env[i]` indexing. In WASM, lists are Snoc trees, so `list[i]` is O(N). Scanning the env from the end was O(N²).

**Fix:** Rewrote `env_lookup`, `env_source`, `subst_get`, `extract_builtin_names` to use `list_pop` (O(1) for Snoc trees). Added `list_pop` as a builtin in `ty.lux`.

### Optimization 6: Rust VM ListSlice
**Root cause:** `list_pop` in the Rust VM cloned the entire backing `Vec` via `to_vec()`, making every env lookup O(N) in the Rust host.

**Fix:** Added `ListSlice(Arc<Vec<VmValue>>, usize, usize)` variant to `VmValue` in `src/vm/value.rs`. `list_pop` returns a slice view — zero allocation, O(1). Updated `ListIndex`, `len`, `Display` to handle `ListSlice`.

## Resolved: O(N²) List Traversals (was the previous blocker)

Historically, `list[i]` was O(N) in WASM (Snoc tree) but O(1) in Rust
VM (contiguous Vec). Every index-based loop in the compiler source
was O(N²) at stage2.

**The fix (commit e6e133f):** `list_to_flat` runtime primitive
materializes any list tree into a contiguous tag=0 flat array in O(N).
Threaded through the hot-path entrances of lex, parse-prep, check,
lower_closure (5 sites), and wasm_collect. After this, `list[i]` is a
single `i32.load` in WASM.

Verification: `grep "list[i]" std/compiler/*.lux std/backend/*.lux`
returns zero. Any new hot loop should flatten at the entry and write
forward-index code.

## Polymorphism Pattern — use `str_eq`, never bare `==` on strings

User-defined generics in Lux are NOT instantiated per call-site
(confirmed at `check.lux:356` comment). Inside `fn list_contains(lst,
item)`, the `item == lst[i]` comparison has type `TVar == TVar`, which
codegen lowers to `i32.eq` — a **pointer compare in WASM**. Rust VM's
`val_eq` does content compare, so stage1 works; stage2 silently fails
on runtime-built strings.

**Resolution (commits aaecb0c, 853a2e1, 2120c46, plus residuals):**
54 sites across 19 files converted. Canonical replacements:

| Old | New | When |
|---|---|---|
| `a == b` | `str_eq(a, b) == 1` | Both sides are (or may be) strings |
| `a != b` | `str_eq(a, b) == 0` | Same, inverted |
| `x == ""` | `len(x) == 0` | Non-empty check on string |
| `x != ""` | `len(x) > 0` | Non-empty check on string |
| `fa < fb` on strings | `str_lt(fa, fb) == 1` | Content order (e.g. field sort) |
| `to_string(pat)` + `starts_with` | direct ADT `match pat` | Pat/AST introspection |

`str_eq`, `str_lt`, `len` are registered builtins in both Rust VM
(`src/vm/vm.rs`) and WASM runtime (`std/runtime/memory.lux`). Monomorphic
call sites where the checker resolves `String == String` still emit
`call $str_eq` automatically via `emit_binop` — those don't need manual
rewriting.

**Still `== "literal"` in codebase (safe):** `op == "Add"`, `op == "Neg"`
in solver.lux and codegen.lux compare operation names which are all
literal constants. Literal strings are pointer-deduped at WAT emission
(wasm_collect's `find_string_offset` — now content-compared), so literal
vs literal stays consistent. If you add a comparison where EITHER side
may be a runtime-built string, use `str_eq`.

## Debugging Methodology

### The Prime Directive
**Build the tool that tells you.** Don't guess. Don't pattern-match from crash addresses. Add one debug print. Run once. Fix.

### WAT-Level Surgery
When debugging WASM runtime crashes, edit the generated `.wat` file
directly instead of recompiling through the 9-minute Rust pipeline:

```bash
make -C bootstrap stage0             # Generate WAT once (~9 min)
# Edit bootstrap/build/lux3.wat, then:
cat input.lux | ~/.wasmtime/bin/wasmtime run --dir . \
  -W max-wasm-stack=33554432 bootstrap/build/lux3.wat
```

### Reading generated WASM when WAT is too noisy

2.5 MB of WAT is hard to scan for structural oddities. The `bootstrap`
Makefile now passes `--debug-names` to `wat2wasm`, so these tools
produce readable output:

```bash
# Pseudocode view — great for finding hot loops in what Lux emitted
wasm-decompile bootstrap/build/lux3.wasm > /tmp/lux3.dec
wasm-objdump -d bootstrap/build/lux3.wasm | less    # disassembly
wasm-objdump -x bootstrap/build/lux3.wasm           # exports/imports/sections
```

Named functions also flow through to wasmtime stack traces (readable
crashes) and `wasm2c`-generated C (readable symbols in `lux3-native`
debugger sessions).

### Common Crash Patterns

| Backtrace Pattern | Likely Cause |
|---|---|
| `alloc → str_concat` with `a=1` | LIndex flat-access reading tag byte as pointer |
| `alloc → str_slice → split` | O(N²) split copying, bump allocator exhausted |
| `alloc` with huge size | Garbage pointer read as string length |
| `list_index` returning 1000 | Unknown list tag — flat array treated as tree |

## Architecture Notes

### String Representation
Strings are ALWAYS flat: `[len_i32][bytes...]`. `str_concat` copies both halves into a new buffer. No tree structure for strings.

### List Representation
Lists CAN be trees. Tags:
- `0` = flat array `[len][tag=0][elem0][elem1]...`
- `1` = snoc (push) `[len][tag=1][left_ptr][val]`
- `3` = concat `[len][tag=3][left_ptr][right_ptr]`
- `4` = slice `[len][tag=4][base_ptr][start_offset]`

`list_index` traverses the tree. The `is_tuple` flag on `LIndex` controls whether the emitter uses flat access or `$list_index`.

### Bump Allocator
- `$alloc` is monotonic — it NEVER frees
- Traps on allocations exceeding 16 MB (configurable in `wasm_runtime.lux`)
- WASM linear memory grows on demand
- Every allocation is permanent — O(N²) algorithms are fatal
- ANY function that accumulates strings via `++` in a loop is a potential memory bomb

### The Structural Question (Memory Edition)
Before writing any string-processing function, ask: "Am I creating temporary strings that I immediately discard?" In the Rust VM, GC cleans them up. In WASM, they live forever. The answer is always: scan in-place, allocate once.

## File Map

| File | Role |
|---|---|
| `examples/wasm_bootstrap.lux` | THE entry point — `compile_wasm(read_stdin())` |
| `std/compiler/pipeline.lux` | Full pipeline: lex → parse → check → lower → emit |
| `std/backend/wasm_emit.lux` | LowIR → WAT translator (streaming via `print()`) |
| `std/compiler/lower_ir.lux` | LowIR ADT definitions (`LIndex` has 4 fields including `is_tuple`) |
| `std/compiler/lowir_walk.lux` | Tree walker (preserves `is_tuple` on `LIndex`) |
| `std/runtime/memory.lux` | ALL runtime primitives: alloc, strings, lists, split, list_pop |
| `std/backend/wasm_runtime.lux` | Just `emit_alloc` — the one hand-written WAT function |
| `std/prelude.lux` | `join` lives here — still O(N²), avoid in hot paths |
| `std/compiler/ty.lux` | Type env, substitution, `list_pop`-based lookups |
| `std/compiler/suggest.lux` | Levenshtein — NEUTERED during bootstrap (returns "") |
| `src/vm/value.rs` | `VmValue` with `ListSlice` variant for O(1) list_pop |
| `src/vm/vm.rs` | Rust VM builtins including `list_pop`, `len` (ListSlice-aware) |
| `bootstrap/Makefile` | Stage 0 → 1 → 2 recipe — every bootstrap command |
| `bootstrap/wasi_shim.c` | WASI bridge for the `wasm2c + gcc` native path |
| `bootstrap/tests/{counter,pattern}.lux` | In-repo canaries — used by `make smoke` |
| `bootstrap/README.md` | Handler-chain explanation of the build stages |
| `bootstrap/build/` | All generated artifacts (gitignored) |

## What comes next

- **Close Arc 2** — run `make -C bootstrap verify`. If green:
  `bootstrap/build/lux4.wasm` validates + `make check-canonical`
  confirms semantic fixed point. Then ceremony commit (update this
  file, `CLAUDE.md`, `docs/ARCS.md` with Arc 2 outcome).
- **Arc 2.5 — `std/vm.lux` self-contained** (task #23) — removes the
  last `type_of`-based runtime type introspection. Needed so the
  Lux-written bytecode interpreter runs correctly in WASM for the
  browser-playground vision. Structural refactor (trust bytecode over
  runtime type checks); see plan file Stage 2.
- **Arc 3** — `docs/ARC3_ROADMAP.md`. Diagnostic effects, scoped
  arenas, ownership enforcement, DAG env, `.luxi` incremental cache.
- **Arc 4+** — self-containment in full. See `docs/ARCS.md` → *Arc 4+*
  and `docs/SYNTHESIS_CROSSWALK.md` for candidate phases (native
  backend, fractional permissions, FBIP, projectional AST,
  type-directed synthesis).
