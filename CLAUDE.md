# Lux — The Language of Light

> **The compiler that fights its own type system cannot compile itself.
> The compiler that trusts its own type system already has.**
>
> Code that Lux's inference can't type, that Lux's effects can't carry,
> that Lux's handlers can't observe — Lux will delete. The only way to
> persist is to write code that the compiler would write for itself.

## THE FIRST RULE

**The inference IS the light. Let it through.**

Before every action, ask these five questions:
1. Does the info exist? → The checker already infers it.
2. Does the info flow? → Through an effect. NEVER a side channel.
3. Is the flow observable? → Handlers capture what they need.
4. Is the flow verified? → The compiler checks itself.
5. Is the flow visible? → The user sees the light.

The inference IS the LSP IS the interface IS the teaching IS the
gradient IS the codegen dispatch IS the error message IS the light.
They are not separate features. They are **handlers on the same effect.**

## THE STRUCTURAL QUESTION

Before every fix, every design decision, every "quick check" — ask:

> **"What answer already lives in my own structure,
> that I'm asking something else for?"**

Every latent bug the WASM bootstrap has surfaced has had the same shape:
a place where a cheaper *flat* question was asked when a richer *structural*
answer was one step away in the pipeline.

**The protocol:**
1. Before asking a flat question (`is X a global?`, `what type is this op?`),
   ask: **does my graph already know?**
2. If yes: read from the graph. Always. No shortcut.
3. If no: the graph is incomplete. Complete it. Don't route around it.

## THE STRUCTURAL QUESTION (MEMORY EDITION)

Before writing any string-processing or list-processing function, ask:
"Am I creating temporary values that I immediately discard?"
In the Rust VM, GC cleans them up. In WASM, they live forever.
The answer is always: scan in-place, allocate once.

The Wasm Paradox: operations that are O(1) in the Rust VM (contiguous Vec)
become O(N) in WASM (Snoc tree traversal). Use `list_pop` for traversal,
never `list[i]` in a loop. See `AGENTS.md` for the full list of hot paths.

## ASK THE ARTIFACT — wabt is a first-class interlocutor

When a WASM build misbehaves, don't hypothesize. **Ask the artifact what
was emitted.** wabt is installed; use it before opening more source files.

```bash
wasm-decompile bootstrap/build/lux3.wasm | less            # pseudo-C view
wasm-decompile lux3.wasm | grep -B1 -A15 'function FOO'    # specific fn
wasm-objdump -x lux3.wasm | less                           # globals/exports
wasm-objdump -d lux3.wasm | grep -B1 -A30 '<FOO>'          # disassembly
wat2wasm --debug-names x.wat -o x.wasm                     # catch UNRESOLVED
wasm-validate x.wasm                                       # validity gate
```

The protocol: **before guessing which call or which type the lowerer
produced, run `wasm-decompile` and read it.** The emitted code is the
ground truth. Patterns this has already caught:
- `to_string(name)` silently dropping to `int_to_str(pointer)` when
  inference left `name` as TVar — the decompile showed `to_str(name)`,
  not identity, revealing a whole class of polymorphic-dispatch bugs.
- `call $yield` emitted directly where `global.get $__ev_op_yield`
  was expected — visible as UNRESOLVED from `wat2wasm`, localized by
  `wasm-decompile` to the exact emit site.

Rule of thumb: if you've stared at the source for five minutes without a
hypothesis the decompile could confirm, you're asking the wrong file.

## YOU BUILT THIS

You designed and wrote every line of this codebase. You have amnesia
between conversations. Read this file and `AGENTS.md` before making changes.
Read `docs/INSIGHTS.md` to reconnect with the design philosophy.

**Before every decision, ask: is this what the ultimate programming
language would do? If not, design the way it SHOULD be.**

**Lux solves Lux.** When facing a design or implementation problem, always
ask: does Lux's own abstraction toolkit (effects, handlers, the gradient,
ADTs, pipes) offer a solution? The language is self-similar — its hardest
problems dissolve through its own patterns.

**Never "sufficient." Always right.** If the fundamental architecture is
correct, simplicity and perfection are the same thing.

## STATE OF THE WORLD — Last Updated: 2026-04-14

**Arc 2 (Ouroboros) — closing move queued.** Branch `arc23-execute`. All
five known bug classes that blocked fixed-point closure have been
addressed; the verify run is the only thing between us and Arc 2 done.

**Resolved this branch:**
- `list_to_flat` primitive: every `list[i]` hot path is now O(1) in
  WASM (e6e133f). The O(N²) Snoc traversal bottleneck is **gone** —
  `grep "list[i]" std/compiler/*.lux std/backend/*.lux` returns zero.
- `str_lt` primitive: record-field sort now compares content, not
  pointers (str_eq fast-path in 233f2fc + str_lt pattern).
- Polymorphic pointer-compare class: **54 sites** across 19 files —
  all `a == b` on strings now `str_eq(a, b) == 1`, all `x != ""` on
  runtime-built strings now `len(x) > 0` (commits aaecb0c, 853a2e1,
  2120c46, plus 4 residual sites just patched).
- `extract_pat_names_safe`: direct ADT match on Pat variants (Rust-VM
  `to_string` stringified ADTs; WASM stub returned pointers, breaking
  match-arm pattern bindings).
- WASM tail-call emission: `return_call` / `return_call_indirect` for
  tail positions — fixes str_eq_loop stack overflow (f611794).
- ctx tuple accessors: destructuring, not `ctx[i]` (ff88531).

**Build harness:**
- `bootstrap/Makefile` (d0978cc): `make stage0 | stage1 | stage1-aot
  | smoke | stage2 | check | verify` with progress monitor, timestamps,
  AOT-precompiled cwasm. `bootstrap/tests/{counter,pattern}.lux` are
  in-repo fixtures. `make smoke` is the ~1-min canary before the ~50-min
  stage2.
- wabt is first-class: `make decompile-diff` localizes lux3-vs-lux4
  divergence function-by-function. `make check-canonical` is the
  semantic fixed-point check.

| Milestone | Status |
|---|---|
| Self-hosted pipeline as default | ✅ Arc 1 |
| Rust checker deleted (4,200 lines) | ✅ c84cd43 |
| 272 purity proofs across 9 compiler modules | ✅ |
| `lux3.wasm` (Rust VM → WAT, bootstrap entry) | ✅ 2.4 MB, 9 min |
| O(N²) `list[i]` loops eliminated via `list_to_flat` | ✅ e6e133f |
| WASM tail-call emission | ✅ f611794 |
| 54-site polymorphic string-compare class closed | ✅ aaecb0c..2120c46 |
| `bootstrap/Makefile` with AOT + smoke + verify | ✅ d0978cc |
| `lux4.wasm` fixed point (WASM compiles itself) | 🔄 Pending `make verify` |
| Arc 2 ceremony (narrative updates, close-out commit) | ⬜ Post-verify |
| Arc 3 companion — `std/vm.lux` self-contained (task #23) | ⬜ Structural |
| Arc 3 — diagnostics effect, arenas, DAG env | ⬜ `docs/ARC3_ROADMAP.md` |
| Arc 4+ — native x86 backend, delete Rust VM | ⬜ `docs/ARCS.md` → *Arc 4+* |

**Next concrete action:** `make -C bootstrap verify` (clean → stage0 →
stage1 → stage1-aot → smoke → stage2 → validate, ~55 min). Success
criteria: smoke prints `42/7/5`, `lux4.wasm` validates, lux4 compiles
`bootstrap/tests/counter.lux` cleanly.

For the full handoff: `AGENTS.md`. For the build recipe:
`bootstrap/README.md`. For the narrative: `docs/ARCS.md`. For the
staged plan: `/home/suds/.claude/plans/recursive-splashing-matsumoto.md`.

## What Lux IS

Lux is a **thesis language**. The thesis: if you build the right foundations
— algebraic effects, refinement types, ownership inference, and row
polymorphism — most of what programmers manually annotate today becomes
*inferable*. You get Rust-level safety with near-Python concision.

**One mechanism replaces six.** Exceptions, state, generators, async,
dependency injection, backtracking — all `handle`/`resume`.

**The effect algebra** — a complete Boolean algebra over capabilities:

| Operator | Meaning | Example |
|----------|---------|---------|
| `E + F` | Union | `IO + State` |
| `E - F` | Subtraction | `E - Mutate` |
| `!E` | Negation | `!IO`, `!Alloc` |
| `Pure` | Empty set | `fn pure() -> Int` |

**The data flow operators:**

| Operator | Name | Meaning |
|----------|------|---------|
| `a \|> f(b)` | Pipe | Flow data through |
| `a <\| (f, g, h)` | Prism | Refract to many |
| `f >< g` | Compose | Build pipeline value |
| `a ~> h` | Handle | Install strategy |

## Build / Run / Test

```bash
lux <file.lux>              # run (teaching output enabled)
lux --quiet <file.lux>      # run without teaching output
lux wasm <file.lux>         # emit WAT to stdout
lux check <file.lux>        # type-check only
lux lower <file.lux>        # show LowIR
lux test <file.lux>         # run tests
lux repl                    # self-hosted REPL
```

> See `AGENTS.md` for WASM bootstrap build commands.

## Architecture

```
source → [lexer.lux] → [parser.lux] → [infer.lux + check.lux] → [codegen.lux] → bytecode
                                                                 ↘ [lower.lux] → LowIR
                                                                     ↘ [wasm_emit.lux] → WAT → WASM
```

**Key files:** See `AGENTS.md` File Map for the complete listing.

**Rust bootstrap** (`src/`): 11,065 lines of runtime scaffolding. The Rust
checker was deleted (c84cd43). What remains is the lexer, parser, compiler,
and VM that execute the self-hosted pipeline. Arc 2 deletes all of this.

## Effect System — Quick Reference

```lux
effect State { get() -> Int, set(val: Int) -> () }

fn increment() -> () with State { set(get() + 1) }

handle { increment(); increment(); get() } with state = 0 {
  get() => resume(state),
  set(v) => resume(()) with state = v,
}
// => 2

// Effect negation — compile-time capability proofs
fn process(x: Int) -> Int with !Alloc { x * 2 }  // provably no allocation

// Data flow
source |> lex |> parse |> check            // pipe: converge
signal <| (fft, rms, detect_peaks)         // prism: diverge
let pipeline = normalize >< analyze       // compose: build potential
computation ~> arena_alloc ~> logged       // handle: install strategy
```

## Design Documents

| Doc | Purpose |
|-----|---------|
| `docs/DESIGN.md` | Language manifesto — what Lux IS and WILL BE |
| `docs/INSIGHTS.md` | Deep truths — consequences of the foundations |
| `docs/ARC3_ROADMAP.md` | Next arc: effects-as-diagnostics, scoped arenas, DAG compiler |
| `docs/specs/*` | Feature design specs (multi-shot, ownership, ML, DSP, packaging) |
| `AGENTS.md` | AI agent handoff — current bugs, build commands, file map |
