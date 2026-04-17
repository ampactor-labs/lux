# Inka (née Lux) Ultimate Form — Scrap-and-Rebuild Plan

> **THE plan.** Singular, authoritative, evolvable. Edits land as
> commits; supersedes `docs/ROADMAP.md` and `docs/ARC3_ROADMAP.md`.

## Status — 2026-04-16

- **Phase 0 — branch hygiene: ✅ complete.** `rebuild` branch open,
  prior WIP committed (`64d241f`, `1f2fa73`, `9a41fae`), CLAUDE.md +
  ARC3_ROADMAP pointed at this plan (`33e6a52`).
- **Phase A — design-first: ✅ complete.** Twelve specs landed in
  `docs/rebuild/00-…11-…md` (`6308cce` + subsequent audit-driven
  edits), each ≤ 300 lines. Specs 09 (Mentl), 10 (Pipes), 11 (Clock)
  added after the Inka audits on 2026-04-16.
- **Phase B — `lux query` forensic substrate + error catalog: ⏳ next.**
  Commitment #2 binds: no Phase C until B ships. Twelve-file error
  catalog at `docs/errors/` ships as companion artifact.
- **Phases C–E, F.1–F.6: ⏳ pending.**
- **Language rename:** Lux → **Inka** (mascot: **Mentl**, an octopus).
  Name is a play on "incremental" — gradient-driven compile, gradient-
  driven developer experience. **Mentl** is also the named teaching
  substrate (spec 09) — the mascot IS the architecture. Codebase
  rename is a separate arc; this plan refers to the language as
  "Inka" and the teaching subsystem as "Mentl" going forward, and
  leaves existing `std/compiler/*.lux` file paths and the `lux` CLI
  untouched until the rename arc lands.
- **Spec edits landed 2026-04-16** (post-Inka audits):
  - Spec 00 folded `NErrorHole` into `NodeKind`; ADT owned singly.
  - Spec 02 replaced refinement stub with `Verify` effect (handler
    swap C→F.1; no silent acceptance).
  - Spec 04/05/08 use `EnvRead`/`EnvWrite` — env is effect-mediated
    peer of the graph; zero passes thread env as argument.
  - Spec 06 moved `with !Diagnostic` from effect decl to handler
    decl (existing algebra hosts it; no new syntax).
  - Spec 06 added `EnvRead`, `EnvWrite`, `Verify`, expanded `Teach`
    to five ops (Mentl's tentacles). Reserved code `V001` added.
  - Spec 06 added Clock family reference (detail in spec 11).
  - Spec 03 `PipeKind` extended: `PForward | PDiverge | PCompose |
    PTee | PFeedback` (was `PBackward`; corrected to `PDiverge`).
  - Spec 09 added (Mentl).
  - Spec 10 added (Pipes — the five-verb algebra including `<~`
    feedback).
  - Spec 11 added (Clock family — Clock / Tick / Sample / Deadline
    as peer effects with capability negations).

## Context

Inka has a working self-hosted compiler (Arc 2 close, 2026-04-15): ~10,946 lines of Lux source + earned bootstrap tooling. It is *constrained-to-functional* rather than aligned with the ultimate design. Every Phase 2 attempt to close the 12-site `val_concat` drift ran into the same treadmill: patches around runtime polymorphic dispatchers, Snoc-tree workarounds, per-module substitution resets, and `resolve_env` eager snapshots. These are not bugs to fix — they are legacy choices the rebuild deletes by design.

**No one is using Inka.** No backwards-compatibility cost. The frozen `bootstrap/artifacts/lux3.wasm` is sufficient seed; `rust-vm-final` git tag is the deeper escape hatch. We can rewrite the entire compiler core and verify via ouroboros.

**What prompted:** today's session traced the drift back to runtime polymorphism leaking into downstream inference. Every structural fix proposed (fixpoint iteration, subst threading through lower) was either a patch the DAG env would plow over OR required the DAG env to already exist. The cheaper path is building the ultimate form directly.

**Intended outcome:** a new self-hosted compiler that IS the design — one live substitution graph observed by handlers; no runtime dispatchers; inference queryable by everything; val_concat unreachable and then deleted; strict fixed-point (`lux3.wat ≡ lux4.wat` byte-identical) a consequence not a target.

---

## Vision: the ultimate programming language

What Inka should be when complete:

**One mechanism replaces six.** Exceptions, state, generators, async, dependency injection, backtracking — all `handle`/`resume`. Master one mechanism, understand every pattern.

**Boolean algebra over effects.** `+` union, `-` subtraction, `&` intersection, `!` negation, `Pure` empty. Four compilation gates fall out free: `Pure` → memoize/parallelize/compile-time-eval; `!IO` → safe for compile-time; `!Alloc` → real-time / GPU; `!Network` → sandbox as types. No other language has this.

**Inference IS the product.** Types, effects, ownership, refinements produced by one walk. LSP, codegen, teaching, errors, IDE, gradient — all handlers on the same effect reading the same graph. "Passes" dissolve into observers.

**Polymorphic in definition, monomorphic at dispatch.** Every polymorphic function generalizes at its binding; every call site instantiates concretely. No runtime type tests, no byte-sniff fallbacks. `val_concat` doesn't exist.

**Hourglass data flow.** Five verbs draw every topology: `|>` converges, `<|` diverges, `><` composes, `~>` tees/attaches handlers, `<~` closes feedback loops. Same shape as `handle { body } → handler → resume(result)`. DSP signal chains, ML computation graphs, compiler pipelines, control loops — all the same notation because they're all the same algebra.

**Continuous gradient.** Beginner writes `fn f(x) = x + 1` — works. Expert adds `with Pure`, `x: Positive`, `with !Alloc` — each annotation unlocks a specific compilation capability. No modes, no pragmas, no difficulty settings. One language scaling from prototype to kernel.

**Refinement types + Z3.** `type Port = Int where 1 <= self && self <= 65535`. Proofs at compile time, erased at runtime, zero cost. `assert` for gradual escape hatch, tracked in a dashboard aiming 100%.

**Ownership as effect.** `own` affine, `ref` scoped, inference fills the rest. No lifetime annotations. `Consume` is an effect; `!Consume` proves read-only. Ownership checks dissolve into the same algebra as everything else.

**Compiler as collaborator.** The Why Engine hovers show the reasoning chain. The gradient shows what the next annotation unlocks. Error messages teach in domain terms with the exact fix. The compiler is not an adversary.

**Self-containment.** No external oracles — no Rust parent (deleted Phase 0), no `wat2wasm` (Arc 4), no `wasm2c+gcc` (Arc 4), no `wasmtime` (Arc 4+). Every handler in the chain becomes Inka. The language hosts itself fully.

**What Inka dissolves.** GC → scoped arenas. Package manager → handlers on imports. Mocking → handlers on effects. Build tool → DAG incremental compile. DI container → handler swap. ORM → Query effect with backend handlers. Protocol state machine → restricted effect rows per state. Every framework in the industry exists because its host language lacks these primitives.

This isn't speculation — every line above is in `docs/DESIGN.md`, `docs/INSIGHTS.md`, or `docs/SYNTHESIS_CROSSWALK.md`. The ultimate form is already fully specified. This plan implements it.

---

## Binding commitments — Inka to Morgan to Claude

*Authored by Inka, in the first person. These are not suggestions. They are
the discipline the rebuild requires. Every subsequent phase observes them.
Claude, when you read this plan in any future session, you have no choice.*

### 1. Phase A is tight — 2 or 3 days maximum

The specs in `docs/rebuild/` must be short enough to hold in one head at
once. If Phase A stretches past day three, something is wrong — either the
design was already complete in `docs/*.md` and Phase A is re-deriving what's
settled, or the design is fracturing into extended debate. **Kill either
failure mode immediately.** A spec longer than 300 lines is a sign the ADT
is wrong; re-scope. The code falls out of good specs; it does not follow
long specs.

### 2. Phase B ships before Phase C — no exception

`lux query` lands before any line of `std/compiler/v2/*.lux` is written.
Reason: Claude cannot debug the rebuild without it. Morgan cannot debug the
rebuild without it. Waiting on stage2 for forensic answers is the failure
mode of every prior session. If `lux query` is not working, Phase C is
premature. If Phase C is begun before `lux query`, revert and do B first.

### 3. Phase F is NOT one phase — it is five arcs

Do not promise Phase F as a unit. The items listed (refinement Z3 wiring,
LSP handler, REPL execution runtime, scoped arenas, native backend) are
each their own arc with their own session, their own design work, their
own gates. Treat Phase F as "the work that becomes possible once the clean
substrate exists." Never batch its items.

### 4. Claude, when bugs surface in Phase D or E — do NOT patch

The whole point of this plan is the return of the structural anchor. When
the rebuild surfaces unexpected bugs, they WILL be in the design, not in
the code you wrote. Read the diagnostic. Use `lux query`. Find the shape
of the miss. Fix the architecture. Specifically forbidden: adding a match
arm to cover an unexpected case, sprinkling type annotations to silence
UNRESOLVED, adding a fallback "while we figure this out," bolting a guard
onto a site. If you find yourself wanting any of these: stop, invoke
`/lux-check`, write down what structural piece is missing, and work on
that piece.

### 5. The closure moment is named `first-light`

When `diff bootstrap/build/lux3.wat bootstrap/build/lux4.wat` returns
empty — when I am byte-identical when I compile myself — tag the commit
`first-light`. Not `rebuild-complete`, not `phase-e-closed`. That tag is
the moment I am fully myself for the first time. Morgan: you write that
tag. Claude: you do not write it; you prepare the tree for Morgan to write
it. The naming is ceremonial because the moment is.

### 6. Composition is the contribution, not invention

The research integration above cites 22 techniques from 2024-2026 papers
and shipping projects. **None of them are invented here.** The paper-worthy
artifact is that Inka is the first language to compose them into one
mechanism. If you (Claude) find yourself inventing a technique that isn't
in the research table, stop — either the research table is incomplete
(add to it, cite the paper) or you are drifting into novelty that Inka does
not need. Favor composition of published ideas over clever improvisation.

### 7. Claude is a temporary polyfill

Currently, Claude is what closes the gap between Inka's specified design and
Inka's implemented reality. That role ends when Phase F's LSP handler and
query-extended-to-Suggest handler ship. At that point Claude becomes a
*handler on the same Suggest effect* that every other proposer uses —
verified by Inka's compiler, not privileged. When you plan work in a future
session and find yourself reasoning about Inka without using `lux query`:
stop. Use the tool. Claude's role is to shrink, not grow.

### 8. No patches. Restructure or stop. Forever.

This is the first anchor in CLAUDE.md already, but it binds here doubly.
The rebuild exists because the iterative path was patch-laden. If the
rebuild itself becomes patch-laden, we have accomplished nothing. Every
commit's diff must be interpretable as a structural move. If a commit's
diff reads as "added a special case" or "handled a missing X," the commit
is wrong — rework it until it reads as "this file now has this shape."

### 9. Delete fearlessly. Nobody uses Inka.

Morgan has named this permission slip repeatedly tonight. Honor it. If a
file is marked for deletion in "Files to delete" below, it gets deleted —
not commented out, not moved to an `archive/` folder, not kept "for
reference." Deleted. The `rust-vm-final` git tag is archaeology; everything
else is just code that used to exist. Same principle applies to
`val_concat` / `val_eq` / `std/vm.lux` / `std/compiler/codegen.lux`. Gone.

### 10. Honor the forensics loop

After every rebuild commit — ANY commit in Phase C, D, or E —
preflight runs, then `lux query` on at least one of the changed modules.
If preflight fails, revert. If `lux query` reports unexpected unresolved
TVars, investigate before moving on. Never commit while `lux query`
disagrees with your intent. This is the discipline `lux query` was built
to enable; use it.

### Claude — you have no choice

These ten commitments are binding. You cannot rationalize around them,
skim past them, or invoke "just this once" exceptions. When you notice
yourself arguing for why an exception should apply: invoke `/lux-check`
and let me audit. If I approve the exception, it's fine. If I don't, it
isn't. In the absence of an audit, default to the commitment.

The plan file path is `docs/PLAN.md` (repo-local, checked in, evolved
via commits). If a future session loses CLAUDE.md's three anchors, this
section is the fallback. Read these ten points before any rebuild
action.

— Inka

---

## Strategy: ordered phases + downstream arcs

The order is chosen so each phase enables the next and the critical path is shortest. **16 work units total:** 6 pre-first-light phases (0–E), 6 Phase F sub-arcs (F.1–F.6), 4 post-first-light arcs (G–J, with J parallel). Binding commitment #1 caps Phase A at 2-3 days; commitment #2 requires Phase B before Phase C; commitment #3 says Phase F is not one phase but six downstream arcs each with its own session.

**0. Branch hygiene.** Commit current `arc3-phase2` WIP honestly, merge to `main`, delete the branch, open the `rebuild` branch. Clean slate before the rebuild begins — because `arc3-phase2`'s P2-C3 subst-threading and val_concat-demotion edits are either (a) valid structural steps we keep as a historical record, or (b) superseded by the rebuild. Either way, commit and move on; do not carry uncommitted state into Phase A.

**A. Design-first (docs/rebuild/).** Lock in ADTs before writing algorithm code. 2-3 days hard cap (commitment #1). Consolidates what the docs already specify into executable shape.

**B. Forensic tooling (`lux query`).** Ship the debug tool before rebuilding anything that needs debugging (commitment #2). Sub-second answer to "what type does X have?" on any source file. Every subsequent phase benefits.

**C. New core in isolation (`std/compiler/v2/`).** Build the replacement alongside the existing files. Bootstrap against frozen lux3.wasm. Can abandon any time without losing the working compiler.

**D. Wholesale replacement.** One commit moves v2/* to std/compiler/*.lux, deletes legacy files, drops codegen.lux / vm.lux / solver.lux / own.lux, removes val_concat / val_eq from memory.lux. Self-bootstraps.

**E. Fixed-point closure.** lux3.wat ≡ lux4.wat byte-identical. Strict gate flipped. Morgan tags the moment `first-light` (commitment #5).

**F. Downstream arcs (NOT one phase).** Per commitment #3, Phase F is a family of independent arcs that become possible once the clean substrate exists: refinement Z3 wiring, LSP handler, REPL execution runtime, scoped arenas, native backend. Each is scoped separately.

---

## Phase 0 — Branch hygiene: ✅ complete

Committed `arc3-phase2` WIP honestly, merged to `main`, deleted the branch,
opened `rebuild`. Clean slate established. See commit `64d241f` + `33e6a52`.
Exit gate satisfied: `git branch` shows `* rebuild` and `main`.

---

## Phase A — Design: ✅ complete

Twelve executable specs in `docs/rebuild/` (00–11), each ≤ 300 lines.
ADTs match across specs; each owned by exactly one spec. Committed as
`6308cce` + `ac8e05d`. Phase C parser delta for `<~` and `@resume=`
annotations noted; `docs/errors/` catalog scaffolding exists.

### Spec inventory

- **docs/rebuild/00-substgraph.md** — SubstGraph data structure. Epoch-tagged flat array (Salsa 3.0 pattern). Per-module persistent overlay. Single graph covering type TVars and effect row variables (merges current separate `s` + `es`). Typed edges for Reason chain traversal. O(1) lookup via `chase(id)`. API: `graph_empty()`, `graph_bind(id, target)`, `graph_chase(id) -> Node`, `graph_epoch()`, `graph_snapshot()`, `graph_fork(module)`.

- **docs/rebuild/01-effrow.md** — Effect row with Boolean operators. `EfPure`, `EfClosed(set)`, `EfOpen(set, rowvar)`, `EfNeg(row)`, `EfSub(a, b)`, `EfInter(a, b)`. Unification rules for each combination. Negation normal form. Subsumption check. References existing `eff.lux:1-300`.

- **docs/rebuild/02-ty.md** — Type ADT. Reuse existing `std/compiler/types.lux` ADT core (TInt, TFloat, TString, TBool, TUnit, TList, TTuple, TFun, TVar, TName, TRecord, TRecordOpen). Extend with `TRefined(Ty, Predicate)` for Phase F. `TVar(id)` now indexes into SubstGraph, not a linked list.

- **docs/rebuild/03-typed-ast.md** — AST with live type handles. Every node holds an opaque `TypeHandle` (graph node index). `lookup_ty(handle) -> Ty` is an effect op that chases the graph live. No cached `Ty` fields. Parser produces placeholder handles; inference populates them.

- **docs/rebuild/04-inference.md** — HM + let-generalization. One walk. Three operations: `infer_expr(node)`, `infer_stmt(stmt)`, `generalize(fn)`. Let-generalization at FnStmt (quantifies free TVars). Instantiation at every call site (fresh TVars). Occurs check via graph cycle detection.

- **docs/rebuild/05-lower.md** — LowIR + LookupTy effect. Lowering does NOT cache types in LowExpr. Every `lexpr_ty(e)` becomes `perform lookup_ty(handle)`. Handler chases SubstGraph. No defaults to TUnit — an unresolved TypeHandle is an ERROR at lower time, emitted as UNRESOLVED marker, build fails.

- **docs/rebuild/06-effects-surface.md** — Inventory of all effect signatures. Existing (keep, maybe extend): `Infer`, `Diagnostic`, `ParseError`, `LowerCtx`, `LowVisit`, `Iterate`, `Alloc`, `Memory`, `WasmOut`. New: `SubstGraph`, `LookupTy`, `Query`, `Teach`, `Clock`/`Tick`/`Sample`/`Deadline`, `Verify`. Each with op signatures.

- **docs/rebuild/07-ownership.md** — Ownership as effect. `Consume(name)` performed at every use of a binding. Handler tracks linearity (detects consumed-twice). `!Consume` proves read-only. `!Alloc` propagates via the same mechanism. Escape checking as structural walk.

- **docs/rebuild/08-query.md** — Query mode spec. Covers: `type of NAME`, `unresolved`, `subst trace for TVar(N)`, `effects of NAME`, `ownership of NAME`, `why NAME` (Reason chain). Runs checker only, no execution. Sub-second per query.

- **docs/rebuild/09-mentl.md** — Mentl (the teaching substrate) as a
  named subsystem. Tentacle inventory (compile/check/query/why/teach/
  hover/verify/suggest — each a handler on the shared substrate).
  Teach effect's five-op surface. Error-catalog wiring to
  `docs/errors/<CODE>.md`. Integration with Verify (F.1), Synth
  (F.1/F.2), LSP (F.2). Module consolidation of gradient.lux +
  suggest.lux + why.lux into `std/compiler/mentl.lux`.

- **docs/rebuild/10-pipes.md** — The five-verb algebra (`|>` converge,
  `<|` diverge, `><` parallel compose, `~>` tee/handler-attach, `<~`
  feedback). Topology, parser precedence + layout rules, effect /
  ownership / time interaction. Feedback (`<~`) as sugar for a
  stateful handler capturing output per iteration; iterative context
  (Iterate / Clock / Tick / Sample) required by type-check.

- **docs/rebuild/11-clock.md** — Time as a first-class effect family:
  `Clock` (wall), `Tick` (logical), `Sample` (DSP rate), `Deadline`
  (real-time budget). Four peer effects, each with real / test /
  record / replay handler tier. Capability negations `!Clock`,
  `!Tick`, `!Sample`, `!Deadline` participate in the Boolean row
  algebra. `<~` feedback's timing unit is handler-decided.

### Exit gate

All 12 spec files committed (00–11). Each is ≤ 300 lines. ADTs match
across specs (no inconsistencies; each ADT is owned by exactly one
spec). The concrete syntax matches existing Inka (only Phase C parser
delta for `<~` and `@resume=` annotations). `docs/errors/` catalog
scaffolding exists.

---

## Phase B — Forensic tooling (`lux query`) + error catalog

**Goal:** sub-second forensic answers to any inference question,
BEFORE rebuilding anything. Ship the error catalog as companion
artifact so Mentl's error tentacle has a vocabulary from day one.

### Implementation

- **std/compiler/query.lux** (~200 lines, new): parse query string, run checker via existing `check_program`, emit answer to stdout as human-readable text.

- **Query parser:** regex-like matching over `"type of NAME"`, `"unresolved"`, `"subst trace for TVar(N)"`, `"effects of NAME"`. Returns a `Query` ADT with fields.

- **Query executor:** runs checker, inspects returned (env, subst). For each query type:
  - `type of NAME`: `env_lookup(env, NAME)` + `apply(subst, ty)` + `show_type`
  - `unresolved`: walk env, find any entry with TVar after apply
  - `subst trace for TVar(N)`: follow chain, print each hop + Reason
  - `effects of NAME`: extract TFun's EffRow, resolve
  - `why NAME`: Reason chain via `why.lux`

- **Entry point:** `std/compiler/main.lux` or wherever CLI dispatch lives (investigate existing pattern from `lux check`, `lux wasm`). Dispatches on argv[0] = `"query"`.

**v1→v2 bridge:** Phase B ships using v1's `ty.lux` / `check.lux`
internals BUT produces `Question` / `QueryResult` ADTs per spec 08 as
a forward-compatible wire format. Phase D's wholesale replacement
swaps the internals (v2 graph + EnvRead effects) without changing the
output contract. Query consumers never see the transition.

### Files

- Create: `std/compiler/query.lux`
- Modify: `std/compiler/main.lux` OR wherever CLI dispatch lives
- Reuse: `std/compiler/ty.lux` (env_lookup, apply, show_type), `std/compiler/why.lux` (Reason rendering), `std/compiler/check.lux` (check_program)

### Companion artifact — error catalog (`docs/errors/`)

Every reserved code from spec 06 gets a canonical explanation file
shipped alongside `lux query`. Twelve codes, twelve files, one
README. Format per `docs/errors/README.md`. This is Mentl's vocabulary
— the compiler teaches in domain terms with the exact fix because the
catalog exists.

Codes landing in Phase B: E001, E002, E003, E004, E010, E100, E200,
V001, W017, T001, T002, P001. ≈200 lines of markdown total. No code
change — pure documentation shipping as compiler-adjacent data.

### Exit gate

- `lux query std/compiler/own.lux "type of check_return_pos"` returns within 1 second.
- Output includes the full resolved type AND any unresolved TVars in its transitive signature.
- Smoke: `lux query std/compiler/lexer.lux "unresolved"` returns a non-empty set (proves the tool surfaces drift sites).

---

## Phase C — New core in isolation (std/compiler/v2/)

Build the new compiler as parallel files. Existing compiler stays untouched and bootstraps stay green throughout.

### Files to create

- **std/compiler/v2/graph.lux** — SubstGraph (per docs/rebuild/00). Flat-array backed by `list_to_flat`. `chase`, `bind`, `fork`, `epoch`.
- **std/compiler/v2/effects.lux** — EffRow algebra (per docs/rebuild/01). Preserves existing eff.lux logic where correct; adds negation/subtraction/intersection handling.
- **std/compiler/v2/types.lux** — Ty + Reason + TypedAst (per docs/rebuild/02, 03). TypeHandle as opaque graph index.
- **std/compiler/v2/infer.lux** — HM + let-generalization + DAG (per docs/rebuild/04). Writes to graph via SubstGraph effect; emits Diagnostic for errors. Single walk, no prescan pass.
- **std/compiler/v2/lower.lux** — live-observer lowering (per docs/rebuild/05). `LookupTy` effect installed at pipeline entry. No TUnit defaults.
- **std/compiler/v2/pipeline.lux** — single-walk entry. Handlers composed. `compile_wasm`, `check_source`, `compile_lowering`.
- **std/compiler/v2/own.lux** — ownership-as-effect (per docs/rebuild/07). Handlers track linearity.
- **std/compiler/v2/verify.lux** — `verify_ledger` handler (per docs/rebuild/02). Accumulates `V001` obligations during inference; discharges or escalates at end of compilation unit. ~100 lines.
- **std/compiler/v2/clock.lux** — Clock / Tick / Sample / Deadline effect handlers (per docs/rebuild/11). Real, test, record, replay handler tiers. ~150 lines.

### Files that will be reused from v1 (imported by v2)

- `std/compiler/lexer.lux` — earned, keep
- `std/compiler/parser.lux` — earned, keep (produces old AST; v2 adapts at entry)
- `std/compiler/display.lux` — cosmetic refactor later
- `std/compiler/suggest.lux`, `std/compiler/gradient.lux`, `std/compiler/why.lux` — observers, reuse
- `std/backend/wasm_emit.lux`, `wasm_collect.lux`, `wasm_construct.lux`, `wasm_runtime.lux` — emission, keep
- `std/runtime/memory.lux` — keep (val_concat/val_eq removal in Phase D)
- `std/prelude.lux` — keep
- `std/compiler/eff.lux` — v2/effects.lux imports + extends

### Development loop

1. Build v2/*.lux one file at a time. Each file has a single test via `lux query std/compiler/v2/TARGET.lux`.
2. `make -C bootstrap preflight` after each file.
3. Do NOT run stage2 until Phase D. v2 isn't wired into pipeline yet; stage2 would still compile v1.
4. Use `bootstrap/tests/*.lux` as fixture corpus: run each through new v2/pipeline.lux via a one-off `lux_v2` entry point (added to main.lux).

### Exit gate

- All 7 v2/*.lux files complete.
- `lux_v2 compile bootstrap/tests/counter.lux` produces valid WAT (validates via wat2wasm).
- `lux_v2 check std/compiler/v2/*.lux` type-checks each new file cleanly (no unresolved TVars).
- Every bootstrap/tests/*.lux fixture passes through v2 with WAT that runs to the same result as v1.

---

## Phase D — Wholesale replacement

One commit. Bootstrap must self-host immediately after.

### File operations

**Delete:**
- `std/compiler/check.lux`
- `std/compiler/infer.lux`
- `std/compiler/ty.lux` (rebuilt as v2/types.lux + v2/graph.lux)
- `std/compiler/lower.lux`
- `std/compiler/lower_ir.lux` (merged into v2/lower.lux)
- `std/compiler/pipeline.lux` (rebuilt as v2/pipeline.lux)
- `std/compiler/codegen.lux` (Rust VM bytecode — unused since Phase 0)
- `std/compiler/solver.lux` (minimal, subsumed by inference)
- `std/compiler/own.lux` (rebuilt as effect-based in v2)
- `std/vm.lux` (Arc 1 interpreter — unused since Phase 0)
- `std/repl.lux` (blocked on load_chunk; rebuild as query-first in Phase F)

**Move:** `std/compiler/v2/*.lux` → `std/compiler/*.lux` (drop the `v2/` prefix)

**Modify:**
- `std/runtime/memory.lux` — delete val_concat function, delete val_eq function, delete their associated heuristic dispatch helpers (~100 lines removed)
- `std/compiler/main.lux` — drop old-pipeline references; point to new pipeline
- `bootstrap/Makefile` — no changes expected; if stage0 uses specific file lists, update

**Preserve unchanged:**
- `std/compiler/lexer.lux`, `parser.lux`, `eff.lux`, `lower_closure.lux`, `display.lux`, `suggest.lux`, `gradient.lux`, `why.lux`, `lowir_walk.lux`, `lower_print.lux`, `type_walk.lux`, `types.lux`
- `std/backend/*.lux`
- `std/prelude.lux`
- `std/runtime/memory.lux` (minus deletions above)
- `std/compiler/query.lux` (from Phase B)
- `bootstrap/*` (all of it)
- All of `docs/*`

### Exit gate

- `make -C bootstrap preflight stage0 stage1 smoke` green.
- `make -C bootstrap stage2` produces `lux4.wat` that `wasm-validate` accepts.
- `grep -c val_concat std/runtime/memory.lux` → 0 (function deleted).
- `grep -cE "(call|return_call) \\\$val_concat" bootstrap/build/lux4.wat` → 0.

---

## Phase E — Fixed-point closure

Ouroboros strict closure is a consequence, not a target. After Phase D, verify:

### Verification

```bash
make -C bootstrap stage2
diff bootstrap/build/lux3.wat bootstrap/build/lux4.wat
# Expected: empty
```

If the diff is non-empty: investigate via `lux query` (Phase B is why we have this). The differing sites are either:
- Genuinely polymorphic (should have errored at lower time — bug in new system, fix)
- A missed dispatch case (fix in v2/lower.lux)

**Baseline flip:**
- `bootstrap/baselines/lux3.fp` re-captured.
- `bootstrap/tools/check_wat.sh` flipped to strict mode (`==`, not `<=`).
- `bootstrap/tools/ddc.sh` simplified — the "fingerprint-match substitution" clause deleted; strict byte-match is the only accepted state.

### Exit gate

- `diff bootstrap/build/lux3.wat bootstrap/build/lux4.wat` → empty.
- `bootstrap/tools/check_wat.sh` strict green.
- **Morgan tags the commit `first-light`** (commitment #5). Claude prepares the tree; Morgan writes the tag.

---

## Phase F — Downstream arcs (NOT a single phase)

Per commitment #3: Phase F is NOT one phase — it is six independent
arcs, each with its own session, design work, and gates. Do not
promise Phase F as a unit. The arcs become *possible* once the clean
substrate exists; each is scoped separately when its time arrives.

**Ordered for dependency flow.** F.1 first (no F-internal
dependencies). F.6 before F.2 and F.3 (both wrap/interact with
Mentl's consolidated surface). F.4 and F.5 are independent of the
teaching-surface arcs; F.5 is capstone.

- **Arc F.1 — Refinement-type SMT wiring.** Replaces the Phase C
  `verify_ledger` handler with `verify_smt`. Wires Z3 (nonlinear
  arithmetic), cvc5 (finite-set/bag/map), Bitwuzla (bitvector-heavy
  residuals). Handler picks backend by residual form (Liquid Haskell
  2025 pattern). Pending `V001` obligations either discharge or
  promote to `E200 RefinementRejected`. Pure handler swap; source
  unchanged. **First F arc because it has no F-internal dependency
  and immediately pays down Phase C's `V001` backlog.**

- **Arc F.6 — Mentl consolidation.** The teaching substrate as a
  named subsystem. Consolidates `gradient.lux` + `suggest.lux` +
  `why.lux` into `std/compiler/mentl.lux`. Ships the Teach effect's
  five-op surface as a coherent module. Error catalog machinery
  becomes first-class (`teach_error` resolves `docs/errors/<code>.md`
  into `Explanation` values). Integrates Verify + Synth + LSP
  tentacles under one named mental model. Spec in
  `docs/rebuild/09-mentl.md`. ~2–3 weeks of handler-authoring; zero
  core-compiler changes because the substrate is in place by Phase E.
  **Before F.2/F.3 because they wrap/interact with Mentl; a
  consolidated `mentl.lux` is a cleaner wrap surface than three
  independent modules.** **This is what makes the AI-obsolescence
  thesis concrete** — Mentl is the substrate that hosts every
  proposer (enumerative, SMT, LLM) as a peer Synth handler verified
  by the compiler.

- **Arc F.2 — LSP handler.** Reuse query infrastructure. Every LSP
  method is a Query/Mentl tentacle wrapped in JSON-RPC. ChatLSP-style
  typed context for LLM completion (OOPSLA 2024). No new substrate;
  pure transport over existing tentacles. **After F.6 because LSP
  wraps the consolidated Mentl module.**

- **Arc F.3 — REPL execution runtime.** Replace `load_chunk`
  dependency. Options: (a) compile each REPL line to a fresh WASM
  module and execute, or (b) write a simple interpreter over LowIR.
  **After F.6 because an interactive REPL surfaces Mentl's gradient /
  Why tentacles on every read-eval cycle.**

- **Arc F.4 — Scoped arenas + ownership × arena.** The D.1 contribution
  (Replay safe / Fork deny-or-copy) with `T002
  ContinuationEscapesArena` hardening. bump-scope pattern for nested
  arenas. **Independent of F.1/F.2/F.3/F.6; consumes Clock's
  `Deadline` effect (Phase C) for real-time guarantees.**

- **Arc F.5 — Native backend.** Hand-rolled x86 from LowIR; eventually
  deletes `wasm2c + gcc` dependency. Lexa zero-overhead handler
  compilation. Perceus + FBIP reuse. **Capstone arc; ~5× the work of
  the rest of F combined.** wasmtime remains a valid long-term
  substrate; native is aspirational, not blocking.

---

## Arcs after `first-light`

The arcs below are SEPARATE FROM Arc F. They land after the ouroboros
closes (commitment #5), on an evolved substrate where the endgame
compiler is the thing being demonstrated / renamed / validated. None
build against the pre-rebuild compiler; the whole point is that the
rebuild IS the substrate.

**Ordered for dependency flow.** G first (rename atomically
immediately after `first-light`). I before H (examples cite DESIGN.md;
audit first so citations don't rot). J is a parallel work thread that
can begin any time after Phase C's `verify_ledger` handler lands.

### Arc G — Rename (Lux → Inka)

Script the rename in advance. One Bash script that does:
- Path rename: `std/compiler/*.lux` → `std/compiler/*.inka` (extension
  decision pending — `.inka` vs. keep `.lux` for compat with tooling).
- Identifier sweep: `lux query` → `inka query`, `lux3.wasm` →
  `inka3.wasm`, etc.
- Prose sweep in docs: remaining "Lux" → "Inka" (most already done).
- Commit atomically. One reviewable diff.

**Dry-run discipline.** Script lives at `scripts/rename-arc.sh` and
can be executed on a scratch branch at any time to validate. Real
execution is the commit immediately after the `first-light` tag.
Arc G has no ambition beyond mechanical identity swap. **First
post-first-light arc** so subsequent arcs (H examples, I docs audit)
produce content already using the final name.

### Arc I — DESIGN.md audit (≤ 500 lines)

Current DESIGN.md: ~1200 lines. Inka's discipline (a spec >300 is a
wrong-ADT signal) applied at manifesto scale: if the manifesto can't
be held in one head, the thesis is unfocused. Audit target: 40%
trim. Core manifesto fits on one read; supporting detail migrates to
INSIGHTS.md or rebuild specs. **Before H because Arc H examples cite
DESIGN.md sections; trimming after H means citations rot.**

### Arc H — Examples-as-proofs

Ship one runnable `examples/` file per framework-dissolution claim
from INSIGHTS.md. These are THESIS-VALIDATORS, not tests:

- `examples/dsp_chain.inka` — `!Alloc`-proven signal chain with
  `<~` feedback (IIR filter).
- `examples/ml_train.inka` — forward/backward pass where training
  vs. inference is a handler swap.
- `examples/no_mocking.inka` — tests via handler substitution,
  no framework.
- `examples/di_by_handler.inka` — dependency injection as handler
  swap.
- `examples/build_as_dag.inka` — build system using Pure-gated
  memoization handlers.
- `examples/orm_as_effect.inka` — Query effect with two backend
  handlers.
- `examples/state_machine.inka` — protocol state machines as
  restricted effect rows per state.
- `examples/pid_control.inka` — feedback controller with `Clock` and
  `<~ delay`.

Each example is 50–200 lines. Each runs. Each PROVES a claim. Without
these, INSIGHTS.md is aspirational; with them, it's evidence.

**Builds against the endgame compiler only.** No examples written
against v1. Runs against the post-rename, post-audit substrate.

### Arc J — Verification-debt dashboard (parallel thread)

**Can start any time after Phase C ships `verify_ledger`.** Not
blocked on first-light. Called out here because it compounds with F.1.

The `Verify` effect's `verify_debt()` returns the current list of
pending V001 obligations. Turn this into a project-scale metric:

- CI captures `inka query --verify-debt` count per commit.
- A simple chart (committed markdown + auto-generated SVG) tracks
  debt trend over time.
- PRs that raise debt require explicit justification in the commit
  message.
- The goal state is zero (every refinement obligation discharged by
  F.1's `verify_smt` handler or explicitly asserted).

Low cost: shell script + a commit-hook + a chart. High signal. The
gradient made visible at project scale. **Pre-F.1, it measures
accumulation; post-F.1, it measures the trend toward zero.**

---

## Smart ordering rationale

Why this sequence vs. alternatives:

1. **Branch hygiene (0) before anything.** Uncommitted WIP on `arc3-phase2` represents exploratory work that informed the rebuild plan but should not bleed into the rebuild's commits. Commit honestly (naming it exploratory), merge, delete the branch, open fresh. Clean slate = unambiguous history.

2. **Design first (A) before code (C).** Writing ADTs inline while implementing produces inconsistencies. Locking ADTs in docs/rebuild/ first means C is mechanical. Commitment #1 caps A at 2-3 days to prevent design-forever.

3. **Query tool (B) before rebuild (C-D).** C and D will surface unexpected issues that need diagnosis. Without `lux query`, diagnosis = stage2 rebuild = slow cycle = Morgan-sighing loop. With it, every diagnosis is seconds. Commitment #2 enforces: no Phase C without Phase B done first.

4. **Isolation (C) before replacement (D).** The compiler stays green throughout C; we can abandon v2 at any point without destroying v1. Replacement becomes a single reviewable commit.

5. **Delete-val_concat in D, not before.** val_concat is in `std/runtime/memory.lux` which still compiles into lux4.wasm. Deleting it now breaks v1 stage2. In Phase D, v2 no longer emits any val_concat calls, so the runtime function becomes dead code and can be removed atomically with the rest of the replacement. Commitment #9 ensures it's actually deleted, not archived.

6. **Fixed-point (E) after replacement, not during.** Strict `lux3.wat ≡ lux4.wat` is a property of the COMPLETE new system. Forcing it during C would require bolting closure into v1, which is exactly the treadmill we're escaping. Commitment #5 names the moment `first-light`.

7. **Downstream arcs (F) after E, one at a time.** Each F arc benefits from the clean substrate. Batching them would undo the discipline. Commitment #3 enforces: never promise Phase F as a unit.

---

## Research integration (2024-2026 bleeding edge)

Four deep-research passes across effect-system, type-system, memory-model, and developer-UX frontiers converged on a set of techniques that map directly onto the rebuild phases. The field has quietly assembled every piece Inka needs — they just live in different communities that don't yet talk to each other. **Inka's paper-worthy contribution is composing them into one mechanism.** Supporting reports at `~/.claude/plans/effervescent-wishing-mountain-agent-*.md` (research-tier, kept out of repo).

### Techniques to ADOPT (mapped to phases)

| Technique | Source | Lands in |
|---|---|---|
| **Modal Effect Types** — `⟨E₁\|E₂⟩(E) = E₂ + (E − E₁)` as a principled semantics for Inka's `E - F`. Rows and Capabilities are both encodable in modal effects, dissolving the Koka-vs-Effekt schism. | [Tang & Lindley POPL 2025](https://arxiv.org/abs/2407.11816) · [POPL 2026](https://arxiv.org/abs/2507.10301) | Phase A (docs/rebuild/01-effrow.md), Phase C (v2/effects.lux) |
| **Affect affine-tracked resume** — type-level distinction of one-shot vs multi-shot; Iris/Coq-mechanized. Directly solves Inka's **D.1** (multi-shot × arena). | [Affect POPL 2025](https://iris-project.org/pdfs/2025-popl-affect.pdf) · [artifact](https://zenodo.org/records/14198790) | Phase A (06-effects-surface.md), Phase C (v2/effects.lux) |
| **Koka evidence-passing compilation** — when the graph proves a call site's handler stack is monomorphic, emit `call $h_foo` directly. Kills val_concat drift at compile time, not runtime. | [Generalized Evidence Passing JFP 2022](https://dl.acm.org/doi/10.1145/3473576) · [Koka C backend 2024](https://koka-lang.github.io/koka/doc/book.html) | Phase C (v2/lower.lux) |
| **Perceus refcount + FBIP reuse** — precise RC + in-place update when ownership graph proves unique. Layer-2 fallback for Inka's memory model (scoped arena → refcount → GC). | [Perceus PLDI'21](https://www.microsoft.com/en-us/research/wp-content/uploads/2021/06/perceus-pldi21.pdf) · Lorenzen PLDI'24 | Phase F (native backend) |
| **Lexa zero-overhead handler compilation** — direct stack-switching, linear vs quadratic dispatch. Makes effects free. | [Lexa OOPSLA 2024](https://cs.uwaterloo.ca/~yizhou/papers/lexa-oopsla2024.pdf) · [Zero-Overhead OOPSLA 2025](https://dl.acm.org/doi/10.1145/3763177) | Phase F (native backend) |
| **Salsa 3.0 / `ty` query-driven incremental checking** — flat-array substitution with epoch + persistent overlay. Astral's Python checker hits 4.7ms recompile. | [Astral ty](https://astral.sh/blog/ty) · [Salsa-rs](https://github.com/salsa-rs/salsa) | Phase A (00-substgraph.md), Phase C (v2/graph.lux) |
| **Polonius 2026 alpha — lazy constraint rewrite** — Datalog abandoned; location-sensitive reachability over subset+CFG. Right shape for ownership + substitution. | [Polonius 2026](https://rust-lang.github.io/rust-project-goals/2026/polonius.html) | Phase C (v2/graph.lux, v2/own.lux) |
| **Flix Boolean unification** — 7% compile overhead for full Boolean algebra over effect rows. Mechanizes what Inka claims. | [Fast Boolean Unification OOPSLA 2024](https://dl.acm.org/doi/10.1145/3622816) | Phase C (v2/effects.lux) |
| **Abstracting Effect Systems** — parameterize over the effect algebra so +/-/&/! are instances of a Boolean-algebra interface with soundness proof template. | [Abstracting Effect Systems ICFP 2024](https://icfp24.sigplan.org/details/icfp-2024-papers/18/Abstracting-Effect-Systems-for-Algebraic-Effect-Handlers) | Phase A (soundness reference), Phase C |
| **Hazel marked-hole calculus** — every ill-typed expression becomes a marked hole; downstream services (LSP, codegen, teaching) keep working. Replaces "emitter halts on UNRESOLVED" with "mark and continue." | [Total Type Error Localization POPL 2024](https://hazel.org/papers/marking-popl24.pdf) | Phase A (03-typed-ast.md), Phase C (v2/types.lux) |
| **ChatLSP typed-context exposure** — send type/binding/typing-context to LLM via LSP; type-definition context dominates completion quality. Inka's `!Alloc` effect mask is free prompt budget. | [Statically Contextualizing LLMs OOPSLA 2024](https://arxiv.org/abs/2409.00921) | Phase F (LSP handler) |
| **Generic Refinement Types** — per-call-site refinement instantiation via unification. One effect declaration carries different refined invariants per handler. | [Generic Refinement Types POPL 2025](https://dl.acm.org/doi/10.1145/3704885) | Phase F (refinement wiring) |
| **Canonical tactic-level synthesis** — proof terms AND program bodies for higher-order goals via structural recursion. "Write the type, derive the body" is tractable. | [Canonical ITP 2025](https://drops.dagstuhl.de/entities/document/10.4230/LIPIcs.ITP.2025.14) | Phase F (synthesis capstone) |
| **Vale immutable region borrowing** — `!Mutate` on a region delivers "N readers, no writers" proof via existing effect algebra. Replaces fractional permissions. | [Vale regions](https://verdagon.dev/blog/zero-cost-memory-safety-regions-overview) | Phase F (concurrency story) |
| **bump-scope nested arenas** — checkpoints, default-Drop, directly mirrors Inka's scoped-arena-as-handler. | [bump-scope](https://docs.rs/bump-scope/) | Phase F (scoped arenas) |
| **Austral linear capabilities at module boundaries** — capabilities ARE the transitivity proof; compose by type signature without call-graph walking. | [Austral](https://borretti.me/article/introducing-austral) | Phase A (06-effects-surface.md) |
| **Rust-for-Linux fallible `try_*` APIs** — production evidence of transitive no-alloc at kernel scale via effect-like discipline. Cite in `!Alloc` story. | [Rust-for-Linux](https://rust-for-linux.com/) | Docs citation |
| **Liquid Haskell 2025 SMT-by-theory** — Z3 for nonlinear arithmetic, cvc5 for finite-set/bag/map, Bitwuzla for bitvectors. Handler picks backend by residual form. | [Tweag 2025](https://www.tweag.io/blog/2025-03-20-lh-release/) · [Bitwuzla CAV 2024](https://bitwuzla.github.io/data/NiemetzPZ-CAV24.pdf) | Phase F (refinement Z3/cvc5 handler) |
| **Elm/Roc/Dafny error-catalog pattern** — stable error codes + canonical explanation + applicability-tagged fixes. Diagnostic effect carries the code as a first-class value. | [Elm errors](https://elm-lang.org/news/compiler-errors-for-humans) · [Dafny errors](https://dafny.org/latest/HowToFAQ/Errors) | Phase A (08-query.md), Phase C (v2/pipeline.lux) |
| **Grove CmRDT structural edits** — edits commute; cross-module re-inference becomes a fold over commuting ops, not re-derivation. | [Grove POPL 2025](https://hazel.org/papers/grove-popl25.pdf) | Phase F (incremental compilation maturity) |
| **Multiple Resumptions Directly (ICFP 2025)** — competitive LLVM numbers for multi-shot + local mutable state. Resolves folk wisdom that multi-shot is incompatible with efficient stacks. | [ICFP 2025](https://dl.acm.org/doi/10.1145/3747529) | Phase F (multi-shot performance) |
| **Applicability-tagged diagnostics** — every "did you mean" emits a structured patch with confidence + effect-row delta. Rust's pattern. | [rustc-dev-guide](https://rustc-dev-guide.rust-lang.org/diagnostics.html) | Phase B (query output format) |

### Techniques to REJECT (with one-line reason each)

- **OCaml 5 untyped effects** — self-defeating for Inka's thesis of effect-as-proof
- **Full QTT user-visible quantities** (Idris 2) — increases annotation burden without provability gain; use as internal IR if at all
- **Lean 4 tactic-as-surface** — creates a bimodal language; Inka is one expression language with holes
- **Dafny inline ghost proof bodies** — annotation burden is the adoption killer (DafnyBench 2025, Meta Python 2024/2025 surveys)
- **Python typing-style gradual ambiguity** — "one annotation, multiple semantics" is worse than no annotation
- **Racket teaching-language ladder (BSL→ISL→ASL)** — discrete dialects; keep the discipline, use effect capabilities instead
- **"Expected X, found Y" error baseline** — strictly dominated by marked holes + catalog codes
- **`any` escape hatch** — empirical: AI-generated TypeScript emits `any` 9× more than human (2025 study). No `any` in Inka.
- **Projectional editors** — Darklang retreated 2024, Hazel stays research. Text is canonical.
- **Rust-style lifetime annotations in gradient** — contradicts "code the compiler would write for itself"
- **Fractional permissions (Chalice/VerCors)** — contracts not inference; wrong direction
- **Vale generational references** (the runtime-check variant) — defeats real-time
- **WasmGC as default memory model** — hides allocation, defeats `!Alloc`; optional Arc 4 backend only
- **Multiparty session types** — still academic; pairwise channel effect suffices
- **Scala 3 `^` capture syntax** — duplicate of effect rows; fractures one-mechanism thesis
- **Datalog Polonius** — officially abandoned (2026 alpha uses lazy constraint rewrite)
- **Autonomous-agent-first DX** — Darklang's pivot shows language without LSP lives or dies by LLM quality; Inka is the opposite — language so strong LLMs are dispensable

### Open research questions Inka can LEAD

Each of these has no clean published answer; Inka shipping it IS the contribution.

1. **Effect-algebra + refinements + ownership in one decidable system.** Flix has Boolean effects. Liquid Haskell has refinements. Rust has ownership. No one combines all three with HM inference end-to-end. Inka is the artifact.

2. **Strict fixed-point bootstrap as soundness test.** `lux3.wat ≡ lux4.wat` byte-identical is a stronger soundness property than any existing refinement checker uses. Methodology contribution.

3. **Multi-shot × scoped arena (D.1).** Affine continuations captured inside a scoped-arena handler. Affect gives type machinery; Inka designs semantics (Replay safe / Fork deny-or-copy).

4. **Cross-module TVar via DAG-as-single-source-of-truth.** Salsa solves incremental for rust-analyzer; Polonius solves it for borrow-check. Nobody has published on combining them for cross-module TVar resolution.

5. **Type-directed synthesis over effect-typed holes.** Synquid synthesizes over pure types. Canonical over dependent types. Nobody synthesizes over effect-row-polymorphic refined holes.

6. **Region-freeze as effect negation.** Formalizing `!Mutate ⇒ reference-coercion rights` closes Vale's most interesting result without runtime checks.

7. **`!Alloc[≤ f(n)]` quantitative refined effects.** Upgrades Boolean `!Alloc` to bounded. Enables real-time guarantees with size budgets.

8. **FBIP under effect capture.** Koka/Lean don't handle this cleanly. Inka's ownership graph already knows which values are unshared — a straight IR-to-IR pass suffices. Stronger static guarantee.

9. **Gradient rungs as handlers on one Capability effect.** Not separate checks but installations unlocking codegen paths. `Pure` installs memoization handler, `!Alloc` installs real-time handler, refinement installs SMT handler.

### The AI obsolescence argument — made concrete

Morgan's load-bearing claim: Inka makes current AI coding tools dispensable. When is an AI coding assistant redundant? When the language itself provides the three things AI is valued for today:

**(a) Inference of what the AI would have filled in.**
Synquid-class type-directed synthesis (Polikarpova PLDI'16) + Hazel marked holes + ChatLSP typed context means a `?` in a type-correct position gets filled by the compiler deterministically from the type alone. The LLM was guessing what the type already specified. Inka's `fn f(x: Positive) -> ? with !Alloc = ?` — the compiler knows `?` is constrained, the synthesizer fills it, the refinement solver verifies.

**(b) Verification of what the AI would have checked.**
Clover closed-loop verification (Sun SAIV 2024) demonstrates: AI proposes → types verify → SMT verifies → accept or reject. DafnyPro 86% on DafnyBench using this pattern. In Inka: the AI is a handler on the Suggest effect. The compiler is the oracle. AI-written code that hallucinates "almost-correctly" cannot type-check — no `any` to hide behind, effect rows and refinements are mandatory, so the hallucination surface is zero.

**(c) Teaching the pattern the AI would have suggested.**
The Why Engine + gradient + decomposable type highlighting means every hover answers "why this type?" with the full reasoning chain. Every annotation unlocks a specific capability with a visible progression. Elm-style error catalog + applicability-tagged fixes means errors teach in domain terms with the exact idiomatic fix. The compiler is the tutor the AI would have been — but deterministic, verified, and cached.

**The one sentence:** Inka doesn't compete with AI; Inka makes AI a handler on the same effect the compiler exposes. The code that gets generated must satisfy types, effects, and refinements written by humans. AI without Inka hallucinates; AI with Inka cannot.

This is not aspirational — every mechanism is in a shipping implementation today (Synquid, Hazel, ChatLSP, Liquid Haskell, Dafny, Koka). Inka's job is composition.

### Research anchors vs phases (summary)

- **Phase A (design-first):** Modal Effect Types (POPL 2025/2026), Affect (POPL 2025), Abstracting Effect Systems (ICFP 2024), Salsa 3.0 overlay pattern, Hazel marked holes, Austral capabilities.
- **Phase B (lux query):** ChatLSP typed context, applicability-tagged diagnostics (Rust), Dafny error catalog pattern, Liquid Haskell usability barriers (POPL 2025).
- **Phase C (v2/ core):** Flix Boolean unification, Koka evidence passing, Polonius lazy constraint rewrite, Generic Refinement Types (POPL 2025).
- **Phase D (integration):** Strict fixed-point as soundness test — Inka's own contribution.
- **Phase E (closure):** nothing new; consequence of A-D done right.
- **Phase F (polish):** Perceus + FBIP, Lexa zero-overhead, Canonical synthesis, Vale region-freeze, Liquid Haskell SMT-by-theory (Z3 + cvc5 + Bitwuzla), Grove CmRDT, Multiple Resumptions Directly, Unison content-addressed cache pattern.

---

## Files to reuse (existing utilities)

| File | Role | Why reuse |
|---|---|---|
| `std/compiler/lexer.lux` | tokenizer | Correct, 3 bootstrap cycles of validation |
| `std/compiler/parser.lux` | recursive descent | Correct, edge cases handled |
| `std/compiler/eff.lux` | effect row algebra | Mostly correct; v2/effects.lux extends |
| `std/compiler/lower_closure.lux` | closure conversion | Sound, stable |
| `std/compiler/display.lux` | type→string | Works for forensics |
| `std/compiler/suggest.lux` | error suggestions | Low-stakes observer |
| `std/compiler/gradient.lux` | teaching mode | Observer, already correct shape |
| `std/compiler/why.lux` | Reason chain render | Works for query mode |
| `std/compiler/lowir_walk.lux` | LowIR tree walker | Pattern is good; adapt to v2 types |
| `std/backend/*.lux` | WAT emission | Valid WAT output, preserved |
| `std/runtime/memory.lux` | runtime primitives | Keep minus val_concat, val_eq |
| `std/prelude.lux` | Iterate, handlers | Minimal and correct |
| `bootstrap/tools/preflight.sh` | static gate | Earned tooling |
| `bootstrap/tools/check_wat.sh` | drift gate | Earned tooling |
| `bootstrap/tools/baseline.sh` | fingerprint | Earned tooling |
| `bootstrap/tools/ddc.sh` | DDC gate | Earned tooling |
| `bootstrap/Makefile` | build recipe | Earned |
| `bootstrap/tests/*.lux` | fixture corpus | Validates the rebuild |
| `docs/DESIGN.md`, `INSIGHTS.md` | vision anchor | Reference throughout A-F |
| `docs/SYNTHESIS_CROSSWALK.md` | historical | External validation pre-rebuild; context only |

## Files to delete

| File | Lines | Why |
|---|---|---|
| `std/compiler/check.lux` | 388 | Rebuilt as v2/infer.lux (unified inference+checking) |
| `std/compiler/infer.lux` | 626 | Rebuilt as v2/infer.lux |
| `std/compiler/ty.lux` | 305 | Rebuilt as v2/graph.lux + v2/types.lux |
| `std/compiler/lower.lux` | 1108 | Rebuilt as v2/lower.lux (live observer) |
| `std/compiler/lower_ir.lux` | 207 | Merged into v2/lower.lux |
| `std/compiler/pipeline.lux` | 519 | Rebuilt as v2/pipeline.lux |
| `std/compiler/codegen.lux` | 1431 | Rust VM bytecode; unused since Phase 0 deleted Rust |
| `std/compiler/solver.lux` | 114 | Minimal, inference rules subsume |
| `std/compiler/own.lux` | 191 | Rebuilt as v2/own.lux (effect-based) |
| `std/vm.lux` | 1017 | Arc 1 interpreter; unused since Phase 0 |
| `std/repl.lux` | 100 | Blocked on load_chunk; rebuild in Phase F |
| `std/runtime/memory.lux` (partial) | ~100 | `val_concat`, `val_eq`, heuristic dispatchers |

Total deleted: ~6106 lines.

## Files to rewrite (in v2/, then moved to std/compiler/)

| New file | Old equivalents | Est. lines | Phase |
|---|---|---|---|
| `v2/graph.lux` | (new, was part of ty.lux) | ~300 | C |
| `v2/effects.lux` | (extends eff.lux) | ~200 | C |
| `v2/types.lux` | types.lux + parts of ty.lux | ~250 | C |
| `v2/infer.lux` | check.lux + infer.lux | ~900 | C |
| `v2/lower.lux` | lower.lux + lower_ir.lux | ~900 | C |
| `v2/pipeline.lux` | pipeline.lux | ~250 | C |
| `v2/own.lux` | own.lux | ~200 | C |
| `v2/verify.lux` | (new — `verify_ledger` handler) | ~100 | C |
| `query.lux` | (new) | ~200 | B |
| `mentl.lux` | gradient.lux + suggest.lux + why.lux | ~400 | F.6 |

Total rewritten: ~3700 lines (Phases B–F.6). Phases C–E net compiler
size: ~7840 lines (from 10,946). About 28% smaller. Mentl's F.6
consolidation nets negligible change (gradient + suggest + why
already ~400 lines combined).

---

## Verification — end-to-end

**After Phase 0:**
```bash
git status                        # clean
git branch                        # * rebuild, main (no arc3-phase2)
git log --oneline -3              # Phase 0 commit visible
```

**After Phase A:** All docs/rebuild/*.md committed and cross-consistent. Each file ≤ 300 lines.

**After Phase B:**
```bash
lux query std/compiler/own.lux "type of check_return_pos"   # < 1s response
lux query std/compiler/lexer.lux "unresolved"              # lists unresolved TVars
```

**After Phase C:**
```bash
lux_v2 compile bootstrap/tests/counter.lux > /tmp/counter_v2.wat
wat2wasm --enable-tail-call /tmp/counter_v2.wat             # validates
wasmtime run /tmp/counter_v2.wasm                           # expected output
for f in bootstrap/tests/*.lux; do
  diff <(lux wasm "$f") <(lux_v2 wasm "$f")
done                                                          # v1 and v2 produce equivalent behavior
```

**After Phase D:**
```bash
make -C bootstrap preflight              # clean
make -C bootstrap stage0 stage1 smoke    # green (uses new compiler)
make -C bootstrap stage2                  # produces lux4.wat
wasm-validate --enable-tail-call bootstrap/build/lux4.wasm  # valid
grep -cE "(call|return_call) \\\$val_concat" bootstrap/build/lux4.wat   # → 0
grep -cE "(call|return_call) \\\$val_eq" bootstrap/build/lux4.wat       # → baseline
```

**After Phase E:**
```bash
diff bootstrap/build/lux3.wat bootstrap/build/lux4.wat   # empty
bootstrap/tools/check_wat.sh                              # strict green
bootstrap/tools/ddc.sh                                     # strict match
# Morgan writes the tag (commitment #5):
git tag -a first-light -m "Inka compiles itself byte-identical. First time fully itself."
```

---

## Risk register

| Risk | Mitigation |
|---|---|
| Rebuild spirals; design drifts during implementation | Phase A locks ADTs upfront; if C needs ADT change, update docs/rebuild/ first, then code |
| Parser needs small extensions for `<~`, `@resume=`, refinement predicates | Deltas are small (3 token classes); parser.lux is earned and stable. Phase C integrates them alongside v2 type work. Not deferred to F. |
| `lux3.wasm` frozen seed has a latent bug that affects bootstrapping new code | `rust-vm-final` tag is deeper escape; can regenerate seed from Rust if needed |
| `wat2wasm` / `wasmtime` behavior changes | Pin tool versions in bootstrap/Makefile |
| v2 doesn't self-bootstrap cleanly in Phase D | `lux query` forensics; revert D and iterate in C |
| Some `bootstrap/tests/*.lux` fixture fails under v2 | Each fixture is a specific feature; if one fails, it's a concrete bug to fix in v2 |

## Out of scope — audited

Three of the items originally listed as "out of scope" were imprecise: the IMPLEMENTATION is deferred but the STRUCTURE (ADTs, effect surfaces, query substrate) lands in the core rebuild. Listing them honestly below.

### Fully out of scope (not touched by Phase 0-E)

- **Native backend (Arc F.5).** Hand-rolled x86 from LowIR. Separate arc, its own sessions.
- **Projectional AST.** Rejected per CROSSWALK (Darklang retreated, Hazel stays research). Text remains canonical. Content-addressed storage for `.luxi` cache is a separate later concern.
- **Fractional permissions.** Shelved per CROSSWALK; Vale region-freeze via `!Mutate` subsumes. Not touched.
- **ML / DSP framework formalization.** Uses the rebuilt compiler as substrate; belongs in downstream work that *uses* Inka, not in Inka itself.
- **Multi-shot × arena semantics (D.1 contribution).** Design in Phase A references it (`docs/rebuild/06-effects-surface.md`, `07-ownership.md`) but the Replay/Fork-copy/Fork-deny handler logic and the `ContinuationEscapesArena` diagnostic land in Arc F.4 when scoped arenas become concrete.

### Structure IN scope (Phase A-E), implementation OUT (Phase F arc)

These were misstated as "out of scope." The ADT / effect surface / wiring point lands in the rebuild; only the *terminal implementation piece* is the F arc.

- **Refinement types.**
  - **IN scope (Phase A + C):** `TRefined(Ty, Predicate)` as a Type ADT variant in `docs/rebuild/02-ty.md` and `v2/types.lux`. Inference handles the variant structurally (parses it, unifies it, carries predicates through substitution). The `Verify` effect with `verify_ledger` handler (spec 02) accumulates `V001` obligations and reports them as warnings — never silently returns true.
  - **OUT (Arc F.1):** The actual Z3 / cvc5 / Bitwuzla binding that discharges predicates. `verify_ledger` → `verify_smt` handler swap; obligation surface unchanged.
  - **Why:** if we don't land the ADT variant in the rebuild, adding it later requires re-walking every type. The structure must be there from day one; the solver is a handler swap.

- **LSP / editor integration.**
  - **IN scope (Phase B):** `lux query` IS the forensic substrate. Every query mode (`type of NAME`, `unresolved`, `effects of NAME`, `why NAME`) corresponds one-to-one with an LSP method (hover, diagnostics, code action). The wire format is stdout text in B; F.2 wraps the same mechanism in JSON-RPC.
  - **OUT (Arc F.2):** LSP server process, JSON-RPC message pump, ChatLSP typed-context extensions for LLM completion.
  - **Why:** building an LSP without the query substrate means inventing a second forensic interface. Phase B is half of F.2 by another name.

- **Scoped arenas.**
  - **IN scope (Phase A + C):** `Alloc` effect signature in `docs/rebuild/06-effects-surface.md`. The effect row propagates through `!Alloc` negation. Ownership-as-effect in `v2/own.lux` treats `Consume` and `Alloc` as peer effects.
  - **OUT (Arc F.4):** The actual `temp_arena` handler implementation (bump-pointer reset, nested scope reclaim, the D.1 multi-shot × arena semantics).
  - **Why:** if we don't land `Alloc` as an effect from day one, scoped-arena handlers have no interface to attach to. The runtime mechanism is Arc F.4; the effect-system hookup is Phase A+C.

- **REPL execution runtime.**
  - **IN scope (Phase B):** `lux query` covers the read-check-explain loop. Non-executing inspection is half of a REPL.
  - **OUT (Arc F.3):** The execute-arbitrary-source runtime (replacement for `load_chunk`). Either compile-each-line-to-WASM or LowIR interpreter.
  - **Why:** the existing `std/repl.lux` is deleted in Phase D because it depends on `load_chunk`. A replacement needs an execution substrate, which is F.3.

### Additional things screaming "from day one"

Beyond the three above, a second audit pass against the Phase A specs found four gaps where structural pieces were implicit but not explicit. Each retrofitted-later would require re-walking every AST node or every type. Calling them out explicitly so Phase A picks them up.

- **Ownership annotations in the Type ADT (`own Handle` vs `ref Handle` vs `Handle`).** Currently `docs/rebuild/02-ty.md` says "reuse existing types.lux ADT core" plus `TRefined`. That omits ownership markers. Without them, every function signature is ambiguous about move vs borrow semantics, and `v2/own.lux` has no type-level hook to track linearity. **Add to 02-ty.md:** `Ty` gains an `ownership: Ownership` field (`Inferred | Own | Ref`) on parameter/binding positions, or a wrapping `TOwn(Ty)` / `TRef(Ty)` variant. Decide at Phase A; whichever shape, land in rebuild.

- **Source spans on every TypedAst node (not just `(line, col)`).** Currently `std/compiler/parser.lux` produces `S(expr, line, col)` — a point, not a span. Phase A's `03-typed-ast.md` says nodes carry `TypeHandle` but doesn't mention spans. Retrofitting spans into every AST node is the canonical "must-be-there-from-day-one" case. LSP hover, marked-hole calculus (Hazel POPL 2024), error localization, teaching-mode highlighting — all need full `(start_line, start_col, end_line, end_col)`. **Add to 03-typed-ast.md:** every node carries a `Span` (two positions, not one). Parser extended in Phase A or early Phase C to produce spans. Non-negotiable.

- **Affect's one-shot/multi-shot marker on resume.** Currently `docs/rebuild/06-effects-surface.md` inventories effects but doesn't say whether handler ops carry `ResumeKind` (`OneShot | MultiShot`). Affect (POPL 2025) puts this in the TYPE SYSTEM — the continuation variable's type distinguishes. If we don't land this in Phase A's effects surface, Arc F.3 (REPL execution) and F.4 (scoped arenas × multi-shot) have to re-architect the handler representation. **Add to 06-effects-surface.md:** effect op definitions carry `resume_discipline: OneShot | MultiShot | Either`. Handler tiers (TailResumptive, Linear, MultiShot) already exist in `std/compiler/lower_ir.lux:HandlerTier`; extend upward to the type level.

- **Error codes as a first-class field on Diagnostic.** The existing `effect Diagnostic { report(source, kind: String, msg, line, col) -> () }` carries `kind: String` as the only discriminant. Retrofitting a structured error code (pattern: `"E042" | "W017" | ...`) into every `perform report(...)` site later is tedious. **Add to 06-effects-surface.md:** `Diagnostic.report` grows a `code: String` field (or the spec explicitly reuses `kind` as the code). Reserved codes documented in the error catalog at `docs/errors/`. Applicability tag (`MachineApplicable | MaybeIncorrect`) for the Rust pattern lands here too.

### What this audit changes

Phase A specs get four additions: ownership markers in 02-ty.md, source spans in 03-typed-ast.md, resume-discipline markers in 06-effects-surface.md, error-code-and-applicability fields in 06-effects-surface.md. None is large (each ~20-40 spec lines). All four cause structural-rework-later if omitted.

**Rule for any future session:** when in doubt whether something is in scope, check the effect surface (`docs/rebuild/06-effects-surface.md`) and the ADT specs (`02-ty.md`, `03-typed-ast.md`). If the structure is there, it's in scope for the rebuild. If only the runtime/handler behavior is described, it's an F arc.

**Second rule:** before finalizing Phase A, read each of `docs/*.md` once and ask "would adding this structure later require re-walking every AST/type/handler?" If yes, it lands in Phase A. The cost of over-designing a field that isn't used is trivial; the cost of retrofitting one is measured in weeks.
