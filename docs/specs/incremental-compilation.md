# Incremental Module Compilation for Lux

## Context

The bootstrap compiler OOMs (12.7GB → killed) because `compile_wasm` re-resolves
and re-checks ALL imported modules from scratch. A single call to `check_program_with`
processes ~10K lines of combined source, growing the substitution quadratically.
The Rust VM's `op_perform` clones handler state on every dispatch, making effect-based
unification cost 5.5GB for real code. This blocks the bootstrap: Lux cannot compile
itself to WASM without exhausting 16GB RAM.

The fix: check each module ONCE, cache the result, never re-derive what's already proven.

## The Lux Principle

From INSIGHTS.md: "The type inference engine produces KNOWLEDGE. That knowledge IS
the product." The checked type environment — `[(name, Type, Reason)]` — is proven
knowledge. Re-inferring it is re-deriving what the checker already proved.

One source of truth. Different handlers tap it. The env is the source. Compilation,
LSP, teaching, errors — all handlers on the same env.

## Design: Module Environments as Cached Knowledge

### Unit of Compilation: Module (file)

Each `.lux` file is checked independently against the environments of its dependencies.
The result: a fully-resolved type environment. No inference state leaks across modules.

### Cache Format: `.luxi` (Lux Interface)

After checking a module, serialize its env to `<module>.luxi`:
- Content: `[(name, Type, Reason)]` triples, fully resolved
- Key: content hash of the `.lux` source file
- Location: alongside the `.lux` file (or in a cache directory)

### Compilation Flow

```
resolve_imports(source)
  → for each import:
      if .luxi exists AND hash matches .lux:
        load env from .luxi (skip checking)
      else:
        check module against dependency envs
        write .luxi
  → check user source against accumulated env
  → lower combined AST
  → emit
```

### What Changes in pipeline.lux

`resolve_imports_tracked` currently concatenates source text. New behavior:

```lux
fn resolve_module(path, dep_env) = {
  let source = read_file("std/" ++ path ++ ".lux")
  let hash = content_hash(source)
  let cache_path = "std/" ++ path ++ ".luxi"
  
  // Try cache
  let cached = try_load_cache(cache_path, hash)
  if cached != [] { cached }
  else {
    // Check this module against dependency env
    let ast = source |> frontend
    let env = ast |> check_program_with(dep_env, next_n)
    write_cache(cache_path, hash, env)
    env
  }
}
```

### What Changes in check_program_with

Nothing. It already accepts an initial env and start_n. Each module passes its
dependency env as the initial env. The checker runs on just that module's AST.

### Topological Module Ordering

Imports form a DAG. Modules must be checked in dependency order:
1. ty.lux (no deps except prelude)
2. eff.lux (depends on ty)
3. check.lux (depends on ty, eff, infer, ...)
4. etc.

`resolve_imports_tracked` already resolves in dependency order (transitive closure
with cycle detection). The new code adds caching to each step.

### Memory Impact

Instead of one `check_program_with` call on 10K lines (5.5GB):
- prelude.lux: ~200 lines → ~50MB
- ty.lux: ~280 lines → ~20MB  
- eff.lux: ~290 lines → ~20MB
- check.lux: ~370 lines → ~30MB
- Each module checked independently, env from previous modules loaded

Peak memory: the LARGEST single module check (~50MB for prelude), not the sum.
Total: under 100MB for the entire compiler.

### The Gradient Connection

The gradient says: more annotations → more knowledge for the compiler → better output.
Module interfaces are the ultimate annotation — the checker PROVED these types. Loading
a cached env is loading proven knowledge. The gradient flows BETWEEN modules through
the interface files.

### Serialization

The env is `[(String, Type, Reason)]`. Type and Reason are ADTs (TInt, TFun, TVar, ...).
These are already representable as Lux values. Serialization = `to_string(env)`.
Deserialization = parsing the string back to a Lux value.

For v1: use `to_string` + a simple deserializer.
For v2: binary format keyed by content hash.

### What This Enables

1. **Bootstrap compiles in <100MB** — each module checked separately
2. **Incremental recompilation** — change one module, only re-check it + dependents
3. **LSP integration** — module envs are the hover/completion source
4. **Parallel compilation** — independent modules can be checked in parallel
5. **The gradient dashboard** — per-module verification scores from cached envs

### Verification

```bash
# After implementation:
lux wasm examples/wasm_bootstrap.lux > /tmp/bootstrap.wat
# Should complete in <100MB, <2 minutes

# .luxi files created alongside .lux files
ls std/compiler/*.luxi

# Cache hit on second run
lux wasm examples/wasm_bootstrap.lux > /tmp/bootstrap2.wat
# Should be faster (cache hits)

# Bootstrap runs on wasmtime
grep "^(module" /tmp/bootstrap.wat
echo "fn f(x) = x * 2" | wasmtime /tmp/bootstrap_clean.wat
```

## Sources

- [Salsa red-green algorithm](https://salsa-rs.github.io/salsa/reference/algorithm.html)
- [Zig incremental compilation](https://github.com/ziglang/zig/issues/21165)
- [Koka language](https://koka-lang.github.io/koka/doc/book.html)
- [LLVM Content-Addressable Storage](https://llvm.org/docs/ContentAddressableStorage.html)
- [Generalized Evidence Passing for Effect Handlers](https://www.semanticscholar.org/paper/144aac0788b43a99087446d7f89e08b81e6484dd)
