# Inka — ROADMAP

> **Canonical roadmap.** This file is the single source of truth for
> execution order, current status, and session-to-session agent
> guidance. It supersedes `docs/PLAN.md` and
> `~/.claude/plans/the-residue.md` as live roadmap documents.

---

## Purpose

This file exists to reduce agent drift.

The previous roadmap state was split across two documents:

- `docs/PLAN.md` — broad historical roadmap + decisions ledger
- `~/.claude/plans/the-residue.md` — live tracker + session handoff

That split created avoidable ambiguity:

- which roadmap was current
- which statuses were stale
- which sequencing rule outranked which
- whether an agent should optimize for historical completeness or
  present execution reality

`ROADMAP.md` resolves that by collapsing live roadmap authority into
one file.

---

## Authority

`ROADMAP.md` is authoritative for:

- what matters now
- what order work should happen in
- what is blocked
- what the current phase and critical path are
- what a fresh session must read before acting

Other documents remain authoritative in their own layer:

- `CLAUDE.md` — discipline, anchors, drift modes, session-zero method
- `docs/DESIGN.md` — manifesto and kernel thesis
- `docs/INSIGHTS.md` — crystallized truths
- `docs/specs/00-11-*.md` — per-module contracts
- `docs/specs/simulations/*.md` — handle-level design contracts

If `ROADMAP.md` and a walkthrough disagree on a specific handle,
**stop and reconcile** before landing substrate. The walkthrough owns
the design of the handle; the roadmap owns sequencing and priority.

---

## Session Zero

Before any substrate proposal or code edit:

1. Read `CLAUDE.md`.
2. Read `docs/DESIGN.md`.
3. Read `docs/INSIGHTS.md`.
4. Read this file, `ROADMAP.md`.
5. Read the relevant walkthrough(s) for the handle being touched.
6. Read the relevant `docs/specs/00-11-*.md` module contract(s).

No substrate proposal from partial-corpus understanding.

---

## Current State

Current branch expectation:

- trunk is `main`
- branch should be clean before new work begins

Current architectural state:

- the eight-primitives kernel is structurally live
- the MultiShot substrate quartet is landed in `src/*.nx`
- bootstrap rewrite is framed as **kernel-complete first, bootstrap
  second**
- Hβ bootstrap work is the critical path to first-light

Current Hβ.infer bootstrap state:

- landed:
  - `state.wat` — `f1a0ed3`
  - `reason.wat` — `2609c82`
  - `ty.wat` — `1d43a73`
  - `scheme.wat` — `407ba4e`
  - `emit_diag.wat` — `9496299`
- pending:
  - `unify.wat`
  - `own.wat`
  - `walk_expr.wat`
  - `walk_stmt.wat`
  - `main.wat`

Current branch tip at roadmap consolidation time:

- cleanup commit: `039b77b` — ignore local `.codex` artifact

---

## Non-Negotiables

These are the live operating rules for roadmap execution:

1. Kernel-complete before bootstrap rewrite.
2. Walkthrough first, substrate second.
3. No “done except wiring” commits.
4. No substrate proposal from partial corpus reads.
5. No drift-budget vocabulary: no “timebox”, no “N sessions”, no
   “pivot criterion”.
6. Mentl is not a CLI prefix; commands are `inka <verb>`.
7. `///` reaches the graph; markdown does not.
8. `ROADMAP.md` is the live roadmap; old roadmap files are
   compatibility shims only.

---

## Immediate Priority

The immediate correctness lane is **pre-`unify.wat` canonicalization**.

Do not push deeper into Hβ.infer bootstrap transcription until these
five items are resolved.

### 1. Env ABI Canonicalization

**Problem**

`bootstrap/src/runtime/env.wat` stores env bindings as `(name,
handle)`, while canonical Inka models env entries as `(name, Scheme,
Reason, SchemeKind)`.

**Why this is load-bearing**

`walk_expr.wat` and `walk_stmt.wat` need env lookup and env extend to
compose on the real substrate, not a temporary shape. If they land
against the current two-field env shape, they will need structural
rewrite later.

**Canonical sources**

- `src/types.nx`
- `src/infer.nx`
- `docs/specs/04-inference.md`
- `docs/specs/simulations/Hβ-infer-substrate.md`

**Likely edit sites**

- `bootstrap/src/runtime/env.wat`
- `bootstrap/src/runtime/INDEX.tsv`
- `bootstrap/build.sh`
- any already-landed bootstrap infer chunks that assume handle-only env

**Acceptance**

- env binding shape in bootstrap matches canonical `(name, Scheme,
  Reason, SchemeKind)`
- lookup/extend semantics match canonical inference usage
- Hβ.infer walkthrough text and chunk headers no longer rely on the
  two-field shape

### 2. SchemeKind Canonicalization

**Problem**

Canonical `SchemeKind` in `src/types.nx` has four variants, but
`src/infer.nx` still refers to `CapabilityScheme`.

**Why this is load-bearing**

This is a design contradiction, not a cleanup nit. The bootstrap
cannot honestly transcribe inference and lowering while the canonical
surface disagrees on a central env classification type.

**Canonical sources**

- `src/types.nx`
- `src/infer.nx`
- relevant walkthroughs that mention env entries or capability
  expansion

**Required result**

One source of truth:

- either `CapabilityScheme` becomes canonical and `types.nx` grows it
- or capability bundles are re-expressed in the existing four-variant
  `SchemeKind`

**Acceptance**

- `src/types.nx` and `src/infer.nx` agree
- roadmap, walkthroughs, and bootstrap work stop referring to two
  incompatible realities

### 3. `scheme.wat` Recursion Parity

**Problem**

Bootstrap `scheme.wat` leaves TFun params and record fields opaque in
free-variable collection and substitution, while canonical `src/infer.nx`
recurses through them.

**Why this is load-bearing**

This affects generalization and instantiation correctness. If left
unfixed, later Hβ.infer chunks will be built on an intentionally
weakened type substrate.

**Canonical sources**

- `src/infer.nx` — `free_in_ty`, `free_in_params`, `free_in_fields`,
  `subst_ty`, `subst_params`, `subst_fields`
- `src/types.nx` — `TParam` and field shapes
- `bootstrap/src/infer/scheme.wat`

**Likely edit sites**

- `bootstrap/src/infer/scheme.wat`
- possibly `bootstrap/src/infer/ty.wat` if helper accessors are
  missing for parity
- `bootstrap/src/runtime/record.wat` or list helpers only if new
  substrate access is genuinely required

**Acceptance**

- bootstrap substitution and free-variable traversal match canonical
  recursion coverage
- no “opaque for now” treatment remains for TFun params / record fields
  unless the canonical source also treats them as opaque

### 4. Diagnostic Boundary Canonicalization

**Problem**

`emit_diag.wat` currently claims a narrower infer-diagnostic surface
than canonical `src/infer.nx` actually emits.

**Why this is load-bearing**

If diagnostic ownership is fuzzy, `unify.wat`, row-related chunks, and
walk arms will either duplicate logic or silently omit real canonical
diagnostics.

**Canonical sources**

- `src/infer.nx` `report(...)` call inventory
- `docs/errors/*.md`
- `bootstrap/src/infer/emit_diag.wat`
- `docs/specs/04-inference.md`

**Required result**

For each diagnostic emitted by canonical inference:

- either it belongs in `emit_diag.wat`
- or it is explicitly assigned to a peer chunk with a named reason

**Acceptance**

- no bootstrap header or walkthrough text says “not emitted by Hβ.infer”
  when canonical `src/infer.nx` does emit it
- helper inventory and ownership boundary are explicit and honest

### 5. Focused Executable Substrate Tests

**Problem**

`scheme.wat` and `emit_diag.wat` are validated mostly by build/grep
checks. That is not enough for load-bearing semantic substrate.

**Why this is load-bearing**

These chunks are dependency substrate for `unify.wat` and the walk
layers. Wrong semantics here cascade outward.

**Desired tests**

- instantiate/generalize focused tests for `scheme.wat`
- type-render / diagnostic bind behavior tests for `emit_diag.wat`

**Acceptance**

- at least one thin executable test path exists for each chunk
- validation covers behavior, not just symbol presence

### Suggested Commit Boundaries For A Fresh Session

1. Canonicalize `SchemeKind` in `src/types.nx` and `src/infer.nx`.
2. Extend bootstrap `env.wat` to the real binding shape.
3. Fix `scheme.wat` recursion parity to canonical `src/infer.nx`.
4. Canonicalize `emit_diag.wat` ownership boundary.
5. Add focused substrate tests for `scheme.wat` and `emit_diag.wat`.
6. Only then resume `unify.wat`.

### Fresh-Session Read List For This Lane

- `CLAUDE.md`
- `docs/DESIGN.md`
- `docs/INSIGHTS.md`
- `ROADMAP.md`
- `docs/specs/04-inference.md`
- `docs/specs/simulations/Hβ-infer-substrate.md`
- `src/types.nx`
- `src/infer.nx`
- `bootstrap/src/runtime/env.wat`
- `bootstrap/src/infer/scheme.wat`
- `bootstrap/src/infer/emit_diag.wat`

---

## Critical Path To First-Light

### Phase A — Hβ Bootstrap Rewrite

Status: **in progress**

Goal:

- rewrite bootstrap against the kernel-complete wheel
- close `first-light-L1`

Subphases:

- Hβ.runtime
- Hβ.lex
- Hβ.parse
- Hβ.infer
- Hβ.lower
- Hβ.emit
- Hβ.start
- Hβ.link
- Hβ.harness

Current immediate blocker inside Hβ.infer:

- the five pre-`unify.wat` canonicalization items above

### Phase B — Kernel Surface Completion

Status: **substantially landed**

Key reality:

- MultiShot substrate is live
- kernel closure is real
- remaining work is composition and demonstration, not primitive
  invention

Important landed substrate:

- H7 MultiShot runtime
- CE Choice effect
- HC2 race combinator
- AM arena × MultiShot
- threading substrate
- LFeedback lowering

Still open or partial:

- `verify_smt`
- per-module overlays
- Ultimate DSP rewrite
- Ultimate ML rewrite

### Phase C — Crucibles

Status: **seeded, not fully demonstrated**

Six base crucibles remain the demonstration gate:

- oracle
- DSP
- ML
- realtime
- web
- parallel

### Phase D — Voice And First-Light Triangle

Status: **partially landed**

Key goals:

- MV.2 voice surface complete
- `first-light-L2` verify witness
- `first-light` full triangle

### Phase E — Meta-Discipline

Status: **ongoing**

Goals:

- plan audit
- effect registry audit
- drift sentinels
- `.inka/` project-local substrate polish

### Phase F — Post-First-Light Dissolutions

Status: **future**

Goals:

- `inka doc`
- retirement of markdown as live orientation surface
- real SMT backend
- further crucibles
- arithmetic-as-handlers
- final tree simplification

---

## Near-Term Execution Order

Use this order unless a walkthrough explicitly forces a different one:

1. Pre-`unify.wat` canonicalization lane
2. Finish Hβ.infer (`unify.wat` → `own.wat` → `walk_expr.wat` →
   `walk_stmt.wat` → `main.wat`)
3. Hβ.lower
4. Hβ.emit / start / link / harness
5. `first-light-L1`
6. `verify_smt` witness path
7. crucible execution
8. MV.2 completion and user-facing surfaces

---

## MultiShot Status

Inka’s MultiShot continuation mechanism is part of the critical path,
not a side experiment.

Live substrate pieces:

- explicit MultiShot continuation lowering
- `Choice` as user-facing MultiShot surface
- `race` as handler combinator
- arena policy handlers:
  - `replay_safe`
  - `fork_deny`
  - `fork_copy`
- oracle speculation through checkpoint / rollback

Live principle:

- resume discipline belongs in the type
- speculation belongs on graph checkpoints and rollback
- MultiShot is not async/await with different spelling
- the substrate must stay explicit, deterministic, and handler-native

This mechanism is one of Inka’s strongest differentiators and should
be protected with real tests and careful canonicalization.

---

## Verification Commands

Use these as the default verification surface during bootstrap work:

```bash
git status --short
bash bootstrap/build.sh
wasm-validate bootstrap/inka.wasm
bash bootstrap/first-light.sh
bash tools/drift-audit.sh <file>
```

For Hβ.infer chunk validation:

```bash
wasm-objdump -x bootstrap/inka.wasm
rg -n "report\\(" src/infer.nx
rg -n "generalize|instantiate|free_in_ty|subst_ty" src/infer.nx
```

---

## Agent Operating Rules

For a fresh session agent:

1. Start by making sure `main` is clean.
2. Read Session Zero corpus before proposing substrate work.
3. Treat `ROADMAP.md` as the roadmap root.
4. Treat walkthroughs as handle-design contracts.
5. If the canonical source and bootstrap substrate disagree, fix the
   canonical contradiction first.
6. Do not continue Hβ.infer depth-first if the substrate beneath it is
   knowingly non-canonical.
7. Use plain commit messages; no AI signature or attribution.

---

## Compatibility Policy

`docs/PLAN.md` and `~/.claude/plans/the-residue.md` are retained only
as compatibility shims after this consolidation.

Their role is:

- point humans and agents to `ROADMAP.md`
- stop split-authority drift
- preserve a stable path for older references while clearly marking
  themselves non-canonical

They should not be used as live roadmap documents after this merge.

---

## Archive Policy

Historical roadmap detail belongs in:

- git history
- walkthrough history
- `docs/INSIGHTS.md` crystallizations
- old roadmap files as archived compatibility pointers

The live roadmap should stay optimized for:

- impact
- clarity
- execution ordering
- reduction of agent drift

When in doubt, make this file shorter, sharper, and more operational.

