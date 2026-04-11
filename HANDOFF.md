# Handoff — WASM Self-Compilation: WORKING

## TL;DR

**The WASM-compiled compiler now compiles Lux programs.** First time ever. Commit `16885cf`. The cage is unlocked. The remaining work is finite and well-defined: fix println string dispatch, prove bootstrap-compiles-itself, then begin pulling Rust scaffolding down.

**The goal:** Lux is the ultimate programming language. The teaching gradient is so good it makes coding-AI obsolete. Self-containment (no Rust) is **priority #1** — not because deleting Rust is the destination, but because building anything on top of Rust-VM-only behavior is wasted effort. Every fix to the WASM bootstrap is verifying a load-bearing claim of the thesis. (See `docs/INSIGHTS.md` and `docs/DESIGN.md`.)

**Read first:** `docs/INSIGHTS.md` "Pure Transforms for Structure" and "Self-Compilation: The Cage and the Light", then the rest of this file.

## Why "delete Rust" is priority #1 even though it's not the goal

Morgan's logic, condensed: when we eventually have to make Lux self-contained, many implementations will need to change. So anything we build NOW on Rust-VM assumptions is potentially throwaway. Get the foundation right first, then build on solid ground. Also: the playground requires WASM bootstrap (browsers run WASM, not the Rust VM). So this isn't even abstract — there's a concrete demo vehicle that can't ship without it.

## How we got here (the chain that worked)

The Rust VM has lenient memory semantics — its own allocator, its own runtime polymorphism, its own closure model. The self-hosted compiler was written assuming all of those, and was never stress-tested against WASM's strict semantics. Every WASM bootstrap crash was a *latent bug* the Rust VM had been papering over for as long as that code existed.

Eight commits between `57cbe8e` (the consolidation refactor that made the bootstrap able to even reach the runtime) and `16885cf` (the actual fix that made it work). In order:

1. **`d2e7ea7` walk_ir into LMakeClosure fn_def** — the IR walker was blind to closure bodies, so `subst_state_to_cells` couldn't reach handler state variables hidden inside handler arm closures. The checker's substitution `s` got emitted as a null pointer, and the WASM-compiled checker read source-code bytes ("fn f") as type pointers. *Fixed: pure structural transform — walk into the body too.*

2. **`d2e7ea7` substitute the handler record before storing** — `install_stateful_evidence` was running `subst_state_to_cells` on `LIndex(record, i)`, a runtime extraction expression with zero state variable names in it. Always a no-op. Now substitute the *whole* `lowered_handler` so closures inside get their `s → __hs_s_42` renames.

3. **`d2e7ea7` `__call_ptr` double-emit** — the `57cbe8e` consolidation introduced a single `__call_ptr` temp for indirect calls. Nested closure calls (`lex_from(skip_comment(pos+2), ...)`) clobber it. *Fixed: emit the func expression twice — computed func exprs in this position are pure capture reads.*

4. **`d2e7ea7` `is_state_var` effect** — `collect_free` walks the AST without knowing which names are handler state variables. So state vars (`s`, `n`, `acc`) got falsely captured by handler arm closures, then the closure read them by value at creation time, missing all the mutations. *Fixed: add `is_state_var(name) → Bool` to `LowerCtx`. `lower_handle` installs a handler that knows the current `state_names`. `filter_real_captures` fires the effect to drop state vars from capture lists. Same mechanism as `is_ctor` and `is_global`.*

5. **`d2e7ea7` ResumeExpr stash** — `lower_expr` for `ResumeExpr(value, updates)` was dropping the updates entirely. The Rust VM doesn't care because resume is a VM opcode that handles updates separately, but the WASM closure body needs them to be actual writes. Now stash the value, apply updates, return stash. Order is critical: the value reads OLD state, then updates fire.

6. **`d2e7ea7` `collect_free` AST coverage** — added `TupleExpr`, `ListExpr`, `MatchExpr`, `ResumeExpr`, `HandleExpr`. Without these the capture detector fell through `_ => []` and missed any free variables hidden inside resume bodies, match arms, or tuple/list expressions. `MatchExpr` extracts pattern-bound names so they don't become false-positive captures. `HandleExpr` adds state binding names to bound so they don't propagate as outer-function captures.

7. **`24dfdc5` LRegion unsound for TUnit** — `is_region_safe_ty` had `TUnit => true`. The lowerer wrapped any handle block with a Unit-typed body in `LRegion`, which resets `heap_ptr` after the body. But effect operations declare `-> ()` (Unit) while handlers can resume with arbitrary heap values (List, Tuple, Variant). `map(f, xs)` is the archetype: body is `iterate(xs); result()`, declared Unit, but resumes with `acc` (a List). LRegion freed the returned List the moment `map` returned. *Fixed: TUnit removed from region-safe set.*

8. **`24dfdc5` aggressive alloc + sanity trap** — `emit_alloc` was growing memory by exactly the pages needed (causes fragmentation/grow thrash) and silently dropped `memory.grow`'s return value (so failures became delayed memory faults). Now grows by the larger of (need, current size) — doubling strategy — and traps explicitly on grow failure.

9. **`ab2ed0d` larger vstack + bigger initial memory** — `__vsp` is a per-program "variant stack" the WASM emitter uses to save intermediate pointers during nested expression construction. It was 1024 slots (4 KB). Deeply nested expressions in the self-hosted compiler push more than 1024, overflowing into the heap and silently corrupting whatever was there. Bumped to 256 K slots (1 MB).

10. **`16885cf` THE root cause: `infer.lux` Concat type** — the checker had `if op == "Concat" { TString }`. Unconditionally. Every `a ++ b` was inferred as a String regardless of operand types. The Rust VM's `OpCode::Concat` dispatches on runtime types, so it always worked. But the self-hosted WASM lowerer trusts inferred types to pick `str_concat` vs `list_concat`. Polymorphic functions like `string_union(a, b)` got `a : String` even though `a` was a list, and the WASM-compiled code called `str_concat` on list data, byte-copying instead of i32-copying, corrupting every pointer. *Fixed: defer like arithmetic — unify operands, resolve, commit only when one side is concretely TString or TList; if both are TVars, return the unified tvar.*

## The methodology that finally worked

I spent **hours** chasing crash addresses, increasing memory limits, adding sanity checks, guessing at root causes. Each "fix" revealed another layer. The breakthrough came in ~30 minutes when I **stopped guessing and built instrumentation**.

**Instrumentation that broke open the wall** (commit `16885cf` discovery path):
1. Added a `;;EGD idx=N nlen=L` debug print at the start of every iteration in `emit_global_decls`. **First run**: showed every name in `top_globals` had the same corrupted length (7820 bytes — turned out to be `fd_write`'s nwritten count from the previous print, read as a "name length" because the name pointer was actually `__closure + 8` from a falsely-captured pattern variable).
2. Added `CONCAT lt=... rt=... left_ast=...` print to `lower.lux`'s BinOp Concat handler. **First run**: showed `CONCAT lt=TString rt=TList(TUnit) left_ast=S(VarRef("a"), 4, 16)`. Line 4 col 16 of the test file was the `a` in `union`. Inferred as TString. Pointed straight to `infer.lux`.

**The lesson — and Morgan's directive going forward:** when you don't know what's wrong, BUILD A TOOL THAT TELLS YOU. Instrumentation is cheap. Guessing is expensive. The pattern that worked was always *one debug print revealing the root cause in one run*. Stop pattern-matching from symptoms.

**Concretely going forward:** before chasing any new WASM bug, write the smallest possible debug print that distinguishes the hypothesis. Run it once. Then fix.

## Verification commands

```bash
# All four crucibles (Rust VM produces WASM)
lux wasm examples/wasm_hello.lux > /tmp/t.wat 2>/dev/null && wasmtime run --dir . /tmp/t.wat   # Hello, World!
lux wasm examples/wasm_ultimate.lux > /tmp/t.wat 2>/dev/null && wasmtime run --dir . /tmp/t.wat # fib(10) = 55
lux wasm examples/wasm_counter.lux > /tmp/t.wat 2>/dev/null && wasmtime run --dir . /tmp/t.wat  # count = 3
lux wasm examples/wasm_check.lux > /tmp/t.wat 2>/dev/null && wasmtime run --dir . -W max-wasm-stack=33554432 /tmp/t.wat # 21

# Build the bootstrap (~5 min)
lux wasm examples/wasm_bootstrap.lux > /tmp/bs.wat 2>/dev/null
wasmtime compile /tmp/bs.wat -o /tmp/bs.cwasm

# Run the bootstrap on a Lux program — THIS IS THE WIN
echo 'let x = 42' | wasmtime run --allow-precompiled --dir . -W max-wasm-stack=16777216 /tmp/bs.cwasm > /tmp/out.wat
wc -l /tmp/out.wat       # ~6685 lines
grep -c UNRESOLVED /tmp/out.wat  # 0
wasmtime compile /tmp/out.wat -o /tmp/out.cwasm  # validates clean
```

## What's still broken

### 1. println(string) prints blank (NEXT — small fix, probably)

When the WASM-compiled compiler emits a program that calls `println("...")`, the program runs without crashing but prints nothing visible. The dispatch from `println` to `print_string` vs `print_int` is type-driven, and for compile-time-known string literals it's miswiring somewhere. Same family of issue as the mini_checker observation way earlier where `println(some_int)` dispatched as `print_string`.

**Methodology:** instrument first. Write a one-line test (`println("hi")`), compile via WASM bootstrap, look at the generated WAT for the println call site, see whether it's `call $print_string` or `call $print_int` and what the operand pointer is. The answer should be obvious from the WAT.

### 2. Bootstrap-compiles-itself not yet verified

The big claim: feed `wasm_bootstrap.lux` to `bs22.cwasm` and get a new bootstrap WAT. If that new WAT compiles cleanly and runs the same way, we have actual fixed-point self-hosting. Until this works, "self-compiling" is a partial claim.

```bash
cat examples/wasm_bootstrap.lux | wasmtime run --allow-precompiled --dir . -W max-wasm-stack=33554432 /tmp/bs.cwasm > /tmp/stage2.wat
wasmtime compile /tmp/stage2.wat -o /tmp/stage2.cwasm
echo 'let x = 42' | wasmtime run --allow-precompiled --dir . /tmp/stage2.cwasm > /tmp/stage2_out.wat
diff /tmp/out.wat /tmp/stage2_out.wat   # should be identical (or close)
```

This will probably reveal more latent bugs. Use the instrumentation methodology — don't guess.

### 3. Then: tear down `src/`

Once stage2 works and produces identical output to stage1, the self-hosted compiler is fully self-contained. The Rust VM is no longer needed for the actual compilation work. What remains:

- Audit `src/` for what's still required (probably: just the bootstrap loader that runs `bs.cwasm` from `lux` CLI)
- Replace `lux` with a thin shell wrapper / Rust shim that calls `wasmtime run bootstrap.cwasm` with stdin/stdout plumbing
- Delete the Rust lexer, parser, compiler, VM, etc.
- Ship `bootstrap.cwasm` in the repo as a binary asset

## What the playground needs (the downstream prize)

When `rm -rf src/` is done, the playground becomes possible:

- A browser textarea for Lux source
- A WASI shim for the browser (small JS that maps `fd_write`/`fd_read`/`path_open` to in-browser filesystem)
- `bootstrap.cwasm` runs in the browser via wasmtime-web or wasmer-js or just direct WebAssembly instantiation
- User types Lux → bootstrap.cwasm compiles to WAT → another WASM compile → run → output pane
- Bonus: **the teaching gradient runs alongside** — every annotation suggestion, every inferred type, every effect propagation visible in real time

This is the demo that proves the thesis: a compiler that teaches you in your browser.

## Where to start the next session

**Immediate task: fix `println(string)` in self-compiled output.**

1. Build the current bootstrap if not already: `lux wasm examples/wasm_bootstrap.lux > /tmp/bs.wat && wasmtime compile /tmp/bs.wat -o /tmp/bs.cwasm`
2. Compile a one-liner: `echo 'println("hi")' | wasmtime run --allow-precompiled --dir . -W max-wasm-stack=16777216 /tmp/bs.cwasm > /tmp/p.wat`
3. Inspect `/tmp/p.wat` — find the println call site. What does it call? `$print_string`? `$print_int`? With what operand?
4. Compare against the same program compiled by the Rust VM: `lux wasm /tmp/whatever.lux`. The Rust VM path produces working output, so the WAT difference IS the bug.
5. Find the dispatch logic in `lower.lux` — search for `println` or `print_string`. Trace back to where the type came from. Fix the type inference, not the dispatch.

**Then:** run the stage-2 self-compile test. Use the same instrumentation discipline.

**Then:** `rm -rf src/` planning and the playground.

## Key files (latest hot zones)

- `std/compiler/infer.lux` — `infer_binop` (the line we just fixed). Also `lookup`, `bind`, `subst_apply`, `subst_bind`, `unify` handler arms. Type inference is where most "Rust VM papers over it" bugs live.
- `std/compiler/lower.lux` — `lower_handle`, `lower_expr` ResumeExpr, `is_region_safe_ty`, `lower_program_typed`, BinOp Concat dispatch
- `std/compiler/lower_closure.lux` — `collect_free` (AST walker), `filter_real_captures` (uses `is_state_var`)
- `std/compiler/lower_ir.lux` — `LowerCtx` effect (with `is_state_var`)
- `std/compiler/lowir_walk.lux` — `walk_ir` (now recurses into `LMakeClosure` fn_def)
- `std/backend/wasm_emit.lux` — `emit_module` (memory layout, vstack base), `emit_call_expr` (double-emit fix), `emit_global_decls`
- `std/backend/wasm_runtime.lux` — `emit_alloc` (doubling + grow trap)
- `std/runtime/memory.lux` — `str_concat`, `list_concat`, `val_concat`, `print_string`, `print_int`, `println` dispatch

## Recent commits (most relevant first)

- `16885cf` **fix(infer): defer Concat type until a side resolves — WASM bootstrap runs!**
- `ab2ed0d` wip(wasm): larger vstack, bigger initial memory, sanity checks
- `24dfdc5` fix(wasm): LRegion unsound for TUnit, aggressive alloc, sanity trap
- `d2e7ea7` fix(lower): state vars in closures — walk_ir into fn_def, effect-filtered captures
- `57cbe8e` refactor(wasm): consolidate backend — single source of truth

All commits are real fixes. None should be reverted.

## Critical warnings for the next session

1. **Build the tool first.** Don't guess. Don't pattern-match from crash addresses. Add a debug print or instrument the function before forming a hypothesis. You'll save hours.

2. **Bootstrap rebuilds take ~5 min on a T490.** Background them and work on something else. `lux wasm examples/wasm_bootstrap.lux > /tmp/bs.wat 2>/dev/null &`

3. **Don't delete `bs.cwasm` files in `/tmp` between tests** — wasmtime caches AOT compilation; reusing a `.cwasm` is much faster than re-`compile`ing the WAT.

4. **`grep -c UNRESOLVED /tmp/whatever.wat`** is your tripwire. UNRESOLVED at compile time is a hundred times cheaper to debug than a memory fault at runtime.

5. **The WASM bootstrap reflects EVERY divergence between Rust-VM behavior and WASM semantics**, not just the bug you're chasing. When you fix one, expect the next layer down to surface. That's progress, not regression. Each fix is peeling away another assumption the Rust VM was hiding.

6. **The Rust VM is still the source of truth for "does this Lux program work."** When in doubt about whether something is a checker bug or a WASM bug, run the same code via `lux <file.lux>` (Rust VM). If it works there but not in the WASM bootstrap, the bug is in WASM lowering or runtime divergence. If it fails in both, the bug is in the Lux source itself.

## The thesis

(Written here so a fresh context picks it up:)

Lux is the connective tissue of every project Morgan touches. It's a thesis language: the foundations — algebraic effects, refinement types, ownership inference, row polymorphism — close the gap between what a programmer means and what they have to write. The teaching gradient (the compiler showing you what each annotation unlocks) is so powerful it makes coding-AI obsolete, because the compiler *knows* your program in a way no AI can guess at. Self-containment is necessary because the playground is a key demo, and because building infrastructure on Rust-VM-only assumptions is throwaway work.

The proof of the thesis is every example that runs, every handler that composes, every `!Alloc` that propagates, every `with Pure` that the gradient suggests. Right now, the proof is also: a compiler written in Lux, compiled to WASM, that compiles Lux programs in a sandbox. The cage is unlocked.

Don't lose this.
