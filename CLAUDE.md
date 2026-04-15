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

## NO KNOWN BUGS SIT

When a bug is **known** — reproduced, localized, understood — it is the
top of the attack list until fixed. There are only two acceptable states
for any signal the build emits:

1. **Clean.** Zero.
2. **Blocking.** The build will not proceed past it.

There is no "informational-for-now," no "soft warning," no "let's track
it and move on." If you're tempted to write `|| true` to hide a grep
count, or `⚠` where the right symbol is `✗`, you are burying a bug that
will cost 75+ minutes of bootstrap time the next week.

Every latent bug in this repo has eventually manifested as a ruined
bootstrap. The cost of tolerating is always higher than the cost of
attacking.

**The protocol when a bug is found:**
1. Reproduce it in seconds, not a full rebuild. (Fast-repro or die.)
2. Gate it in the build. `exit 1` on the signal. No exceptions.
3. Fix the root cause — not the symptom, not the gate.
4. Only then strengthen the gate's scope (baseline, regression diff).

If the bug is inconvenient to fix, that is not a license to tolerate it.
It is a signal that the architecture is wrong in that area, and the fix
should be architectural. See THE STRUCTURAL QUESTION.

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

## STATE OF THE WORLD — Last Updated: 2026-04-15

**Arc 2 (Ouroboros) — semantic closure achieved.** Branch `arc23-execute`.
`lux3.wasm` compiles itself → `lux4.wat` (UNRESOLVED=0, validates).
`lux4.wasm` compiles `counter.lux` → valid WAT → wasm validates → runs
to exit 0. The Rust VM's charity is no longer a load-bearing input.

**Semantic vs strict closure.** There is ~4 lines of textual difference
between `lux3.wat` and `lux4.wat` (not byte-perfect fixed point). The
drift is 12 `val_concat` fallback sites in lux4 that aren't in lux3 —
cosmetic artifacts of cross-module TVar visibility that surface as
polymorphic runtime dispatch instead of monomorphic typed dispatch.
Both paths compute correct results; one is just slower. **Closing the
strict fixed-point is carried forward to Arc 3 Item 5 (DAG env as single
source of truth) — see the deferred work in `ARC3_ROADMAP.md`.**

**Resolved in the Arc 2 close (2026-04-15):**
- **Inliner deleted** — `apply_rewrite`, `find_rewrite`, ~150 lines of
  parallel closure-capture machinery removed. Every effect op now
  dispatches through `__ev_op_NAME` (one mechanism, many handlers).
  Removed the `state_names` regression + 7 latent sibling bugs that were
  waiting for a refactor to surface.
- **Duplicate fn names eliminated** — `memory.lux` had flat-array
  versions of `list_contains`, `head`, `tail`, `index_of`, `replace`,
  `starts_with`, etc. that shadowed Snoc-safe versions elsewhere. The
  emitter silently picked the flat ones. Fatal on Snoc trees; Rust VM
  charitably tolerated. All memory.lux shadows removed. `effect_names`
  duplicate in `lower.lux` also removed.
- **Cross-module TVar collision fixed** — `pipeline.lux:424` used a
  heuristic `dep_n + len(mod_env) * 10` for the fresh-counter bump
  between modules. `count_fresh_vars` (defined above in the same file
  but never wired up) is now the actual bump. Reduced `val_concat`
  drift from 33 sites to 17, then 17 to 12 after the tactical fix in
  `collect_free_stmt`.
- **VarRef edit reverted** — briefly broke local shadowing of
  effect-op names; the emitter's resolution hierarchy already does the
  right thing. Kept emitter unified.
- **Emitter diagnostic loudness** — `wasm_emit.lux`'s UNRESOLVED
  fallback now writes to stderr before emitting the marker. The build
  halts visibly instead of silently producing a validated-but-wrong
  lux4.

**Tooling now in place (use before and after every stage0):**
- `bootstrap/tools/preflight.sh` — instant static checks before
  compile: duplicate fn names, duplicate effect-op names, flat-array
  list ops (Snoc-tree breakers), with-clause effect declarations,
  println-as-value. Runs in <1 s. Wired as a dep of `make stage0`.
- `bootstrap/tools/check_wat.sh` — WAT-level drift gate: UNRESOLVED
  count, regression diff vs baseline, null-fn-ptr patterns, polymorphic
  fallback (val_concat/val_eq) growth detection. Runs in <1 s.
- `bootstrap/tools/baseline.sh capture|diff|promote` — structural
  fingerprint of a WAT artifact for detecting drift without requiring
  byte-perfect fixed point. `bootstrap/baselines/lux3.fp` captures the
  current Rust-VM-produced lux3.wat.
- `bootstrap/tests/handler_capture.lux`, `handler_capture3.lux`,
  `list_concat_direct.lux` — fast-repro fixtures (~2 s) for the bug
  classes surfaced today: handler closure capture, nested-fn-in-handle,
  list-op type inference.

| Milestone | Status |
|---|---|
| Self-hosted pipeline as default | ✅ Arc 1 |
| Rust checker deleted (4,200 lines) | ✅ c84cd43 |
| 272 purity proofs across 9 compiler modules | ✅ |
| `lux3.wasm` (Rust VM → WAT, bootstrap entry) | ✅ 2.4 MB, ~6 min |
| O(N²) `list[i]` loops eliminated via `list_to_flat` | ✅ e6e133f |
| WASM tail-call emission | ✅ f611794 |
| 54-site polymorphic string-compare class closed | ✅ aaecb0c..2120c46 |
| `bootstrap/Makefile` with preflight + gates + drift | ✅ d0978cc + 2026-04-15 |
| Inliner deleted (apply_rewrite / find_rewrite) | ✅ 2026-04-15 |
| Name-collision hygiene (memory.lux shadows removed) | ✅ 2026-04-15 |
| `count_fresh_vars` wired (cross-module TVar integrity) | ✅ 2026-04-15 |
| `lux4.wasm` **semantic** Ouroboros (compiles counter.lux) | ✅ 2026-04-15 |
| `lux4.wasm` **strict** fixed-point (`lux3.wat == lux4.wat`) | 🔄 Arc 3 carry-over |
| Arc 3 — diagnostics effect, arenas, DAG env | ⬜ `docs/ARC3_ROADMAP.md` |
| Arc 4+ — native x86 backend, delete Rust VM | ⬜ `docs/ARCS.md` → *Arc 4+* |

**Next concrete action** (for the next session): read `AGENTS.md` +
`docs/ARC3_ROADMAP.md`. The remaining strict-fixed-point drift is a
natural case study for Arc 3 Item 5 (env as DAG, one substitution
graph across modules). Before starting any code change, run
`make -C bootstrap preflight` to confirm the invariants haven't
regressed since this closure.

For the full handoff: `AGENTS.md`. For the build recipe:
`bootstrap/README.md`. For the narrative: `docs/ARCS.md`.

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
