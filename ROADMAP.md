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
- `docs/SUBSTRATE.md` — canonical substrate (kernel, verbs, algebra, handlers, gradient, refinement, theorems)
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
3. Read `docs/SUBSTRATE.md` cursor-adjacent (not bulk).
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

Current Hβ.infer bootstrap state — **CASCADE CLOSED (11/11 chunks live)**:

- landed (Tier 4–8, all live in build):
  - `state.wat` — `f1a0ed3` (Tier 4)
  - `reason.wat` — `2609c82` (Tier 5)
  - `ty.wat` — `1d43a73` (Tier 5)
  - `tparam.wat` — `b2b9e82` (Tier 5; substrate-gap closure 2026-04-26)
  - `scheme.wat` — `407ba4e` + recursion parity `b2b9e82` (Tier 5)
  - `emit_diag.wat` — `9496299` + boundary canonicalization `88992bc` (Tier 6)
  - `unify.wat` — `facbc3e` (Tier 6 — type unification engine, 25 exports)
  - `own.wat` — `7d0ebd2` (Tier 7 — affine ledger + branch protocol + ref escape)
  - `walk_expr.wat` — `48d5674` (Tier 7 — 22 Expr-tag arms, 29 exports)
  - `walk_stmt.wat` — `945afa2` (Tier 7 — 12 exports, closes §13.3 #9)
  - `main.wat` — `b6e1f23` (Tier 8 — `$inka_infer` pipeline-stage boundary)
- closure metrics:
  - 7,712 lines of inference substrate under `bootstrap/src/infer/`
  - assembled image: 14,645 lines / 71,095 bytes
  - 25/25 trace-harnesses PASS; first-light Tier 1 LIVE non-regression
  - drift-audit clean
- named follow-up peer handles (per drift-mode-9 discipline):
  - **Hβ.infer.pipeline-wire** — retrofit `$sys_main` (build.sh Layer 6 inline)
    to chain `$inka_infer` between `$parse_program` and `$emit_program`.
    Gated on Hβ.lower arrival per Hβ-infer-substrate.md §10.3 (the clean
    handoff is infer→lower; emit_program does not consume graph state).
    When Hβ.lower's `$inka_lower` lands, `$sys_main` becomes:
    `stdin |> read_all_stdin |> lex |> parse_program |> $inka_infer
    |> $inka_lower |> $emit_program |> proc_exit`.
  - additional Hβ.infer follow-ups named in chunk headers + walkthrough §12:
    row-normalize, handler-stack, walk_pat, match-exhaustive,
    named-record-validate, iterative-context, qualified-name,
    lambda-params, unaryop-class, region-tracker, docstring-reason,
    used-binary-search, used-sites-deque, refinement-compose, synth.

Current Hβ.lower bootstrap state — **CASCADE CLOSED (11/11 chunks live)**:

- landed (Tier 4–9, all live in build):
  - `state.wat` — `8af659a` (Tier 4)
  - `lookup.wat` — `e1209cc` (Tier 5)
  - `lexpr.wat` — `50f842a` (Tier 6)
  - `emit_diag.wat` — `d417332` (Tier 6)
  - `classify.wat` — `3ae5200` (Tier 7)
  - `walk_const.wat` — `d4d537c` (Tier 7)
  - `walk_call.wat` — `fbc0295` (Tier 7)
  - `walk_handle.wat` — `f01ea67` (Tier 7)
  - `walk_compound.wat` — `92a9a30` (Tier 7) + binop closure `ab76cc9`
  - `walk_stmt.wat` — `f104ddd` (Tier 8 — 11 exports, closes §13.3 #10)
  - `main.wat` — `c53904d` (Tier 9 — `$inka_lower` pipeline-stage boundary)
- closure metrics:
  - 59/59 trace-harnesses PASS; first-light Tier 1 LIVE non-regression
  - drift-audit clean
- named follow-up peer handles (per drift-mode-9 discipline):
  - **Hβ.infer.pipeline-wire** — UNGATED — retrofit `$sys_main` (build.sh
    Layer 6 inline) to chain `$inka_infer` + `$inka_lower` between
    `$parse_program` and `$emit_program`. The cascade closure ungates this;
    immediate-next-commit per Lock #4 two-stage discipline. `$sys_main`
    becomes: `stdin |> read_all_stdin |> lex |> parse_program |> $inka_infer
    |> $inka_lower |> $emit_program |> proc_exit`.
  - **Hβ.lower.toplevel-pre-register** — wheel-parity two-pass globals
    pre-registration per src/lower.nx:1106-1110 + Lock #1.
  - **Hβ.lower.emit-extension** — extend Layer 6 emit_*.wat to consume
    LowExpr per Hβ-lower-substrate.md §9.2; Hβ-emit-substrate.md walkthrough
    TBD per Hβ-lower §13 sibling list.
  - additional Hβ.lower follow-ups named in chunk headers + walkthrough §11:
    evidence-thunk, either, refinement-erasure, cross-module,
    fn-stmt-closure-substrate, fn-stmt-frame-discipline, letstmt-destructure,
    handler-arm-decls-substrate, documented-arm-substrate,
    tail-resumptive-discrimination, either-install-negotiation,
    classify-trap-testing, lvalue-lowfn-lpat-substrate, upval-handle-resolution,
    varref-schemekind-dispatch, state-entry-accessor, perform-multishot-dispatch,
    derive-ev-slots-naming, op-type-resolution, classify-at-handle-site,
    handle-pipe-harness-builders, feedback-state-slot-allocation,
    diverge-irregular-fallback-harness, lambda-capture-substrate,
    blockexpr-stmts-substrate, match-arm-pattern-substrate,
    field-offset-resolution, synth.

Current branch tip:

- `b6e1f23` — `substrate: bootstrap/src/infer/main.wat — Hβ.infer cascade closure`
- `c53904d` — `substrate: bootstrap/src/lower/main.wat — Hβ.lower cascade closure`

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

The Hβ.infer + Hβ.lower cascades are both **closed** (11/11 + 11/11 chunks
live). The cursor advances to **Hβ.infer.pipeline-wire** — the named peer-
handle commit retrofitting `$sys_main` to chain `$inka_infer + $inka_lower`
into the pipeline. Lock #4 two-stage cascade-closure-then-peer-handle-
retrofit discipline is now formalized as a third instance per Anchor 7.4.

### Hβ.infer.pipeline-wire Entry Surface

The retrofit lives in `bootstrap/build.sh` Layer 6 inline `$sys_main` (or
wherever `$sys_main` is currently defined). Pipeline becomes:

```
stdin |> read_all_stdin |> lex |> parse_program
      |> $inka_infer |> $inka_lower |> $emit_program |> proc_exit
```

After this lands, the seed performs the full classical pipeline (lex /
parse / infer / lower / emit) where every primitive is welded to the
kernel's eight (DESIGN.md §0.5).

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

Current state inside Hβ.infer:

- **closed** (11/11 chunks live as of `b6e1f23`)

Current state inside Hβ.lower:

- **closed** (11/11 chunks live; cursor advances to Hβ.infer.pipeline-wire)

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

1. **Hβ.infer.pipeline-wire** (UNGATED — retrofit `$sys_main` to chain
   `$inka_infer + $inka_lower`; immediate next commit per Lock #4)
2. Hβ.emit / start / link / harness
3. `first-light-L1`
4. `verify_smt` witness path
5. crucible execution
6. MV.2 completion and user-facing surfaces

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

## Archive

### Pre-`unify.wat` Canonicalization Lane (RESOLVED 2026-04-26)

All five items landed before the rest of the cascade:

1. **Env ABI** — canonical 4-tuple `(name, Scheme, Reason, SchemeKind)`
   landed in `683f064`.
2. **SchemeKind** — `CapabilityScheme` is canonical in `src/types.nx`
   alongside the other three variants; `src/types.nx` and `src/infer.nx`
   agree.
3. **`scheme.wat` recursion parity** — `b2b9e82` closed TFun params +
   record fields recursion; `tparam.wat` substrate-gap closure landed
   alongside.
4. **Diagnostic boundary** — `88992bc` canonicalized `emit_diag.wat`
   ownership boundary against canonical `report(...)` inventory.
5. **Focused executable substrate tests** — `0e3e641` added trace-
   harnesses for `scheme.wat` + `emit_diag.wat`; subsequent chunks
   each added their own; current count is 25/25 PASS.

---

## Archive Policy

Historical roadmap detail belongs in:

- git history
- walkthrough history
- `docs/SUBSTRATE.md` crystallizations
- old roadmap files as archived compatibility pointers

The live roadmap should stay optimized for:

- impact
- clarity
- execution ordering
- reduction of agent drift

When in doubt, make this file shorter, sharper, and more operational.

