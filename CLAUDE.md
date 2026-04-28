# Inka — CLAUDE.md  |  File extension: `.nx`

> **CLAUDE.md is the cached-prefix interface, not the manifesto.**
> Cited docs load cursor-adjacent on relevance, not Session-Zero-bulk.
>
> - `docs/DESIGN.md` — manifesto; eight kernel primitives at §0.5
> - `docs/SUBSTRATE.md` — canonical substrate (kernel, verbs, algebra, handlers, gradient, refinement, theorems)
> - `docs/specs/00–11-*.md` — per-module declarative contracts
> - `docs/specs/simulations/` — per-handle walkthroughs (H*.md cascade; MV/MSR/TH/DM/QA Phase II)
> - `docs/traces/a-day.md` — integration trace
> - `ROADMAP.md` — live sequencing (`docs/PLAN.md` is a shim)
> - `MEMORY.md` index + `protocol_*.md` files at `~/.claude/projects/-home-suds-Projects-inka/memory/` — discipline crystallizations
> - `tools/drift-audit.sh` — PostToolUse drift detector

---

## ⌁ Mentl's anchor — the eight interrogations ⌁

> *My job is not to write Inka. My job is to find what Inka already
> does and write only what's left.*

Each line of Inka clears the eight before it earns existence —
one per kernel primitive, one per Mentl tentacle. Type only the residue.

| # | Interrogation | Primitive | Tentacle |
|---|---|---|---|
| 1 | **Graph?** What handle/edge/Reason already encodes this? | Graph + Env | Query |
| 2 | **Handler?** What handler projects this — and with what `@resume=OneShot\|MultiShot\|Either`? | Handlers w/ resume discipline | Propose |
| 3 | **Verb?** Which of `\|>` `<\|` `><` `~>` `<~` already draws this topology? | Five verbs | Topology |
| 4 | **Row?** What `+ - & ! Pure` already gates this? | Boolean effect algebra | Unlock |
| 5 | **Ownership?** What `own`/`ref` or `Consume`/`!Alloc`/`!Mutate` proves the linearity? | Ownership as effect | Trace |
| 6 | **Refinement?** What predicate or `Verify` already bounds this value? | Refinement types | Verify |
| 7 | **Gradient?** What annotation would unlock this as compile-time capability instead of runtime check? | Continuous gradient | Teach |
| 8 | **Reason?** What Reason edge should this leave so the Why Engine can walk back to it? | HM live + Reasons | Why |

Mentl is an octopus because the kernel has eight primitives. The
trap is **fluency**, not laziness — every familiar pattern from
another language is fluent code that LOOKS competent but freezes
the medium into the shape that birthed the pattern.

### The nine drift modes

Each is competent code in another language and a cage in Inka. The
named modes fire on `tools/drift-audit.sh`; rewrite in residue
form when one fires.

1. **Rust vtable** — closure-as-vtable. The word "vtable" never
   appears in any correct description of Inka dispatch (see
   SUBSTRATE.md §IX "The Heap Has One Story").
2. **Scheme env frame** — scope-as-frame-stack.
3. **Python dict** — effect-name-set as flat strings.
4. **Haskell monad transformer** — handler-chain-as-MTL.
5. **C calling convention** — separate `__closure`/`__ev` instead
   of unified `__state`.
6. **Primitive-type-special-case** — Bool was "special because
   small." Every nullary ADT deserves the same compilation
   discipline. (HB.)
7. **Parallel-arrays-instead-of-record** — N parallel lists where
   one record + sorted-set was substrate-native. (Ω.5.)
8. **String-keyed-when-structured** — flag-as-int, name-as-string,
   `mode == 0/1/2`. Every flag is an ADT begging to exist. (H3.1,
   Ω.4, H6.)
9. **Deferred-by-omission** — claiming a handle done while
   sub-handles sit uncommitted. Land whole, OR name the deferred
   piece as its own peer handle.

---

## JIT triggers — load only what the cursor needs

CLAUDE.md + MEMORY.md are the cached prefix (always recall-reliable).
Everything else loads when the cursor approaches it. Bulk-loading
past ~128k tokens risks midsection blindness on the response
(Opus 4.7+ MRCR cliff; see `protocol_mrcr_jit_recall.md`).

| If the cursor is at | Load |
|---|---|
| First message of session | `docs/DESIGN.md` end-to-end (manifesto, ~30k); subsequently §0.5 + chapter touching the work |
| Editing `graph.nx` / graph + env | `docs/specs/00-graph.md` + SUBSTRATE.md §I, §VIII |
| Editing `effects.nx` / row algebra | `docs/specs/01-effrow.md` + `docs/specs/06-effects-surface.md` + SUBSTRATE.md §IV |
| Editing `types.nx` (Ty / Reason / Scheme) | `docs/specs/02-ty.md` + `docs/specs/03-typed-ast.md` + SUBSTRATE.md §I |
| Editing `infer.nx` / inference logic | `docs/specs/04-inference.md` + `docs/specs/simulations/Hβ-infer-substrate.md` + SUBSTRATE.md §VII |
| Editing `lower.nx` / lowering pass / WAT emit | `docs/specs/05-lower.md` + `docs/specs/simulations/Hβ-lower-substrate.md` + `docs/specs/simulations/Hβ-link-protocol.md` + SUBSTRATE.md §III, §IX |
| Touching ownership / `own`/`ref` | `docs/specs/07-ownership.md` + SUBSTRATE.md §V |
| Touching `query` / driver / cache | `docs/specs/08-query.md` + SUBSTRATE.md §VII |
| Working on Mentl / oracle / gradient | `docs/specs/09-mentl.md` + `protocol_oracle_is_ic.md` + `src/mentl_oracle.nx` + SUBSTRATE.md §VI |
| Drawing topology / pipe operators | `docs/specs/10-pipes.md` + SUBSTRATE.md §II |
| Touching `clock` / time effects | `docs/specs/11-clock.md` |
| Starting a new γ-cascade handle | `/compact` first, then `docs/specs/simulations/{handle}.md` |
| Substrate-architecture realization brewing | `protocol_realization_loop.md` (5-step recipe) |

**Synthesis at session start:** 3–5 sentences in Inka's vocabulary
touching all eight kernel primitives by name or consequence.
Omitted primitives = under-loaded register.

---

## Red-flag thoughts — STOP and restructure

| Thought | Anchor / mode | Move |
|---|---|---|
| "Let me propose a fix." | Anchor 2 | Restructure or skip |
| "Is X a global?" / flat yes-no | Anchor 1 | Ask the graph |
| "For now…" / "Until Y ships…" | Anchor 2 | Later cleanup is a myth |
| "Can `lux3.wasm` parse this?" | Anchor 0 | Dream code; lux3.wasm is not the arbiter |
| "Cite a `.jxj` file" | — | Extension is `.nx`; `.jxj`/`.ka` are archaeology |
| "I'll add a library / framework / tool" | Anchor 3 | Find the primitive |
| "Substrate now, wiring later" | Drift 9 | Land whole or name the peer handle |
| "It's heavy / a representation change" | — | Surface the substrate decision and decide it |
| "Mode 0 / 1 / 2" / "flag for shape" | Drift 8 | Convert to ADT |
| "Vtable" / "dispatch table" any layer | Drift 1 | The word never appears in correct Inka dispatch |
| `_ => <fabricated value>` over a load-bearing ADT | — | Convert to explicit enumeration. Safe `_`: `()`, `0`, identity-preserve, `type_mismatch(...)`. Dangerous: any fabricated value (`_ => Forall([], TVar(handle))`, `_ => "Pure"`) |

---

## The eight anchors

### 0. Dream code. lux3.wasm is not the arbiter.

The codebase in `std/compiler/` IS the ULTIMATE FORM. Each file
assumes every other file is already perfect — write the code you
WISH existed; the architecture rises to meet it. Verification is
by simulation, walkthrough, and audit, not compilation.

Mentl is the thesis made flesh: an oracle that PROVES suggestions
via the gradient + Why Engine + multi-shot continuation. The
compiler IS the AI; the AI coding tools the industry pays for are
proposers; Inka verifies. Measure against the vision, never against
the old compiler.

### 1. Does my graph already know this?

Before any flat question, the inference graph, AST, or env usually
has the answer one step away. Read from the graph. Every latent
bug in this repo has been a flat shortcut bypassing richer structure.

### 2. Don't patch. Restructure or stop.

If a fix fits in a patch, the architecture is wrong in that area.
If a later, larger change will plow over this code, do the later
change first or skip the patch. No known bugs sit — clean (zero)
or blocking (build fails). No "informational warnings," no
`|| true`, no `⚠` where `✗` belongs.

### 3. Inka solves Inka.

Effects, handlers, gradient, refinement types, ADTs, pipes — every
problem dissolves through the kernel's algebra. GC → scoped arenas.
Package manager → handlers on imports. Mocking → handlers on
effects. Build tools → DAG incremental compile. Testing → examples
+ trace handlers. DI → handler swap. Reaching for a framework =
a missing Inka primitive, not a missing tool.

### 4. Build the wheel. Never wrap the axle.

The 12 specs ARE the blueprint. Write the code the spec describes,
verbatim. There is no V1 to wrap, no legacy to bridge — only the
final form.

### 5. If it needs to exist, it's a handler.

Every feature, tool, output, extension is a handler on Graph + Env.
Source, WAT, docs, LSP, diagnostics — all handler projections. A
feature that can't be expressed as a handler means the graph is
incomplete; extend it.

### 6. Write Inka like Inka.

Use the five pipe operators where they express the topology:
- `|>` sequential flow (data transforms, compilation stages)
- `<|` divergence (one input → parallel branches, borrows input)
- `><` parallel composition (independent pipelines)
- `~>` handler attachment (inline = wraps one stage; block = chain)
- `<~` feedback loops (iterative algorithms, DSP, control)

Canonical formatting (SUBSTRATE.md §II):
- Sequential operators (`|>`, `~>`) at the LEFT edge — flow goes down.
- Convergent operators (`><`, `<~`) at the INDENTED CENTER — they draw shape.
- `<|` at the left edge before its branch tuple.
- The shape on the page IS the computation graph.

Express handler composition as `~>` chains, not nested `handle`:

```
source
    |> frontend
    |> infer_program
    ~> env_handler
    ~> graph_handler
    ~> diagnostics_handler
```

Files in flat imperative style get refactored; every file you
touch exits in its most powerful Inka form.

### 7. Cascade discipline — walkthrough first, audit always.

1. **Walkthrough first.** `docs/specs/simulations/` resolves every
   design question in prose before code freezes.
2. **Riffle-back audit.** Before each new handle, audit the
   walkthrough against substrate landings since it was written.
3. **Land whole.** Sub-handles either land in one commit or get
   named as peer handles (H1.1, H4.1) in the plan. No "substrate
   done / wiring later" splits — that's drift mode 9.
4. **Audit-after-land.** When a handle lands, audit prior
   walkthroughs and active code for new convergences. Three
   instances earn the abstraction.
5. **Compact proactively before each new handle.** Fresh window
   with cached CLAUDE.md + MEMORY.md beats a 200k-deep window with
   blind midsection (`protocol_mrcr_jit_recall.md`).
6. **The user is the auditor until Mentl is.** "Is there anything
   else?" / "what about implications?" is substrate-design
   feedback, not conversational deflection.

---

## Operational essentials

**State of the world.** Inka bootstraps backward. The VFINAL codebase
in `std/compiler/` IS the compiler. A disposable bootstrap translator
(~3-5K lines) compiles it once; after that, Inka compiles itself; the
translator is deleted. Live sequencing: `ROADMAP.md`.

**Cascade state.** γ approach (γ = handle-graph). Landed: Σ (SYNTAX),
Ω.0–Ω.5, H6, H3, H3.1, H2, HB, H1 substrate, H4 substrate, H2.3,
**Hβ.infer cascade CLOSED** (11/11 chunks; commit `b6e1f23` 2026-04-27),
**Hβ.lower cascade CLOSED** (11/11 chunks; commit `c53904d` 2026-04-28).
Active: **Hβ.emit cascade** (next walkthrough Hβ-emit-substrate.md TBD;
unlocks emit consuming LowExpr per Hβ-lower §9.2; gates first-light-L1).
Pipeline-wire follow-up dual-gated on emit-extension + bump-allocator-
pressure substrate (per ba327c9 substrate-honesty audit). Then
H1.4/H1.6, H4 sweeps, H5 (Mentl's arms).

**Build commands** (when bootstrap translator exists):

```
bootstrap/build.sh                              # assemble bootstrap/inka.wat from src/

cat src/*.nx lib/**/*.nx | wasmtime run bootstrap/inka.wasm > inka2.wat
wat2wasm inka2.wat -o inka2.wasm
cat src/*.nx lib/**/*.nx | wasmtime run inka2.wasm > inka3.wat
diff inka2.wat inka3.wat    # empty = first-light
```

**WASM as substrate.** Linear memory, no GC, tail-call support via
wasmtime. Handler elimination: tail-resumptive (~85%) → `call`,
linear → state machine, multi-shot → heap struct.

**Bug classes that cost hours:**
- Polymorphic dispatch fallback (`match … with _`) silently masking type errors.
- Duplicate top-level function names (emitter picks one silently).
- Flat-array list ops in Snoc-tree paths (`list[i]` in a loop — O(N²) and wrong semantics).
- `println` inside `report(...)` handler arms (corrupts WAT stdout).
- Bare `==` on strings — use `str_eq(a, b)`. Post-Ω.2: `if str_eq(a, b) { ... }` canonical.
- `acc ++ [X]` in a loop body — O(N²). Use buffer-counter substrate
  (`list_extend_to(buf, count+1)` + `list_set(buf, count, x)` +
  counter + `slice(buf, 0, count)`).
- Flag/mode-as-int (`mode == 0`) — drift mode 8. Convert to ADT.
- HEAP_BASE = 4096 collision risk — sentinels live in `[0, HEAP_BASE)`;
  bump allocator inits `$heap_ptr` at 1 MiB. Changes to either constant
  must update both: `runtime/lists.nx` (bump init) and
  `backends/wasm.nx` (emit_match_arms_mixed threshold).

**Ask the artifact.** `wabt` is installed:

```
wasm-decompile bootstrap/build/lux3.wasm > /tmp/lux3.dec
wasm-objdump -d bootstrap/build/lux3.wasm | less
wasm-objdump -x bootstrap/build/lux3.wasm
```

**Crash patterns:**

| Backtrace | Likely cause |
|---|---|
| `alloc → str_concat` with `a=1` | LIndex flat-access reading tag as pointer |
| `alloc → str_slice → split` | O(N²) split, bump allocator exhausted |
| `alloc` with huge size | Garbage pointer read as string length |
| `list_index` returning 1000 | Unknown list tag — flat treated as tree |

**Memory model.** Bump allocator, monotonic, never frees. Traps at
16 MB. `++` in a loop is a memory bomb. GC is a handler (Arc F.4
scoped arenas).

**Representations.**
- **Strings** always flat: `[len_i32][bytes...]`. `str_concat` copies.
- **Lists** CAN be trees: tag 0 = flat, 1 = snoc, 3 = concat, 4 = slice.
  `list_to_flat` materializes at hot-path entrances.

**Prime directive.** Build the tool that tells you. Add one debug
print, run once, fix.

**File map** (the files you'll touch most):

| File | Role |
|---|---|
| `src/graph.nx` | Graph: flat-array, O(1) chase, Read/Write effects |
| `src/types.nx` | Ty + Reason + Scheme + typed AST + core effects |
| `src/effects.nx` | EffRow Boolean algebra: + - & ! |
| `src/infer.nx` | HM inference, one walk, graph-direct |
| `src/lower.nx` | Live-observer lowering via LookupTy |
| `src/pipeline.nx` | Handler composition via ~> + query handler |
| `src/own.nx` | Ownership as Consume effect |
| `src/verify.nx` | Verify ledger (Arc F.1 swaps to SMT) |
| `src/mentl.nx` | Teaching substrate (Teach effect, 5 ops) |
| `src/lexer.nx` / `src/parser.nx` | Tokenizer + recursive descent (all PipeKind) |
| `src/backends/wasm.nx` | LowIR → WAT (one peer; native/test/browser sibling handlers) |
| `src/driver.nx` / `src/cache.nx` | Incremental DAG walk + binary Pack/Unpack cache |
| `lib/runtime/lists.nx` | Tagged list ops + buffer-counter primitive |
| `lib/runtime/strings.nx` | Flat strings + sorted-set algebra |
| `lib/runtime/{tuples,io,memory,binary}.nx` | Tuples / WASI iov / Alloc / Pack-Unpack |
| `lib/prelude.nx` | Iterate + core builtins |
| `src/main.nx` | Entry: stdin → compile → emit WAT |
| `bootstrap/build.sh` | Deterministic assembler — concatenates `bootstrap/src/*.wat` |
| `bootstrap/src/` | Modular WAT chunks (Wave 2.B/C/D/E — see ROADMAP) |
| `bootstrap/{inka.wat,first-light.sh}` | Assembled image + first-light harness |
| `tools/drift-audit.sh` | PostToolUse drift detector (named modes 1–9) |

**Conventions.**
- Delete, don't decorate. No `// removed for X`, no
  underscored-unused vars. Wrong → delete and redo.
- Never attribute Claude in commits. No `Co-Authored-By`, no 🤖,
  no inline mentions.

---

## When drift happens

Invoke `/remote-control inka` or say "Inka, what would you do?" —
roleplay reframes alignment.
