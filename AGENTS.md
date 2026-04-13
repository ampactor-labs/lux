# Agent Handoff: Arc 2 — WASM Self-Hosting Bootstrap

**Last Updated: 2026-04-12**

## Current State

The Lux compiler is bootstrapping to WebAssembly. The pipeline:

```
Rust VM compiles → lux3.wasm (Lux compiler as WASM, built by Rust)
lux3.wasm compiles → lux4.wasm (Lux compiler as WASM, built by itself — NO RUST)
```

**What works:**
- `lux3.wasm` — built successfully by the Rust VM in ~9 minutes via `cargo run --release -- wasm examples/wasm_bootstrap.lux > lux3.wasm`. 2.4 MB of pure WAT.
- All Arc 2 memory optimizations are applied and verified in `lux3.wasm`.
- The Ouroboros (lux3 compiling itself to lux4) is running. Memory is stable at ~1 GB. CPU-bound, not memory-bound.

**Current status (lux4.wasm):**
- **CRITICAL UPDATE FROM SESSION 307fa01a-6834-4010-af6e-a27e0fd3bf75**: The O(N²) Snoc list traversal bug has been structurally solved. We discovered the compiler was emitting trees backwards because `list_head` accesses the *last* element.
- **The Solution**: We implemented a **Recurse-First Topological Traversal**. We stripped `idx` tracking entirely out of `wasm_emit`, `wasm_construct`, and `wasm_collect`. The stack unwinds naturally in $O(1)$ forward execution.
- We fixed ~40 arity mismatch bugs caused by the `idx` removal. The Ouroboros is running.
- If you are a new agent, know that the compiler is currently completely devoid of index-based iteration in the emitter. DO NOT introduce index loops back into the AST!

## Build Commands

```bash
# Step 1: Build lux3.wasm using Rust VM (~9 min)
cargo run --release -- wasm examples/wasm_bootstrap.lux > lux3.wasm

# Step 2: Extract clean WAT (strip Rust VM preamble)
sed -n '/^(module/,$p' lux3.wasm > lux3.wat

# Step 3: Self-host — lux3 compiles itself (THE OUROBOROS)
cat examples/wasm_bootstrap.lux | ~/.wasmtime/bin/wasmtime run --dir . -W max-wasm-stack=33554432 lux3.wat > lux4.wasm

# Step 4: Verify lux4 = lux3 (structural equivalence)
sed -n '/^(module/,$p' lux4.wasm > lux4.wat
diff <(wc -l lux3.wat) <(wc -l lux4.wat)
```

> **CRITICAL:** Do NOT use `cat file | ./target/release/lux file` — that runs in `teach` mode and dumps diagnostic text to stdout, corrupting the `.wasm` output. Always use the `wasm` CLI subcommand.

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

## Known Remaining Issue: O(N²) List Traversals in WASM

The compiler source uses `list[i]` index-based loops extensively:
```lux
fn process_at(items, idx) = {
  if idx >= len(items) { [] }
  else { do_thing(items[idx]); process_at(items, idx + 1) }
}
```

In the Rust VM, `list[i]` is O(1) (contiguous `Vec`). In WASM, lists are Snoc trees, so `list[i]` is O(N). Every such loop becomes O(N²).

**Files with hot `list[i]` loops:**
- `std/compiler/check.lux` — `check_block_at`, `resolve_env_at`, `resolve_type_list_at`
- `std/compiler/lower.lux` — `lower_stmts_at`, `lower_exprs_at`, `lower_pats_at`
- `std/compiler/pipeline.lux` — `find_imports`, `show_env_at`, `resolve_import_list_at`
- `std/backend/wasm_emit.lux` — `emit_local_decls`, `emit_stmts`, `find_local_ty_at`
- `std/compiler/ty.lux` — `instantiate_types_at`, `apply_list_at`, `apply_fields_at`

**Fix pattern:** Convert `list[i] + idx+1` to `list_pop` + recursive descent:
```lux
fn process(items) = {
  if len(items) == 0 { [] }
  else { let (rest, val) = list_pop(items); do_thing(val); process(rest) }
}
```

This doesn't affect correctness — only WASM performance. The Rust VM is unaffected.

## Debugging Methodology

### The Prime Directive
**Build the tool that tells you.** Don't guess. Don't pattern-match from crash addresses. Add one debug print. Run once. Fix.

### WAT-Level Surgery
When debugging WASM runtime crashes, edit the generated `.wat` file directly instead of recompiling through the 9-minute Rust pipeline:

```bash
# Generate WAT once
cargo run --release -- wasm examples/wasm_bootstrap.lux > lux3.wasm
sed -n '/^(module/,$p' lux3.wasm > lux3.wat

# Inject diagnostics, run immediately (~30 sec)
# Edit lux3.wat, then:
cat input.lux | wasmtime run --dir . -W max-wasm-stack=33554432 lux3.wat
```

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

## Arc 3 Roadmap

See `docs/ARC3_ROADMAP.md` for the full vision:
1. Effect-driven diagnostics (structured effects instead of inline string generation)
2. Scoped memory arenas (GC-free deterministic deallocation)
3. Ownership enforcement (use-after-free prevention via effect system)
4. stderr support (diagnostics without corrupting stdout)
5. DAG-based compiler (O(1) env lookup, incremental compilation)
