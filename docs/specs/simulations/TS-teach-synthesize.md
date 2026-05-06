# TS — teach_synthesize · the oracle conductor

> **⚠ SUPERSEDED — 2026-04-20.** This walkthrough was drafted as a
> standalone handle for the `teach_synthesize` oracle conductor. Two
> mid-draft conversations reframed the work:
>
> 1. The proposing primitive is **multi-shot `enumerate_inhabitants`**
>    — Mentl owns the enumerator; there is no plural "proposers."
>    The flat-list shape in Q1 and the `Synth`-chain framing in Q4
>    are both wrong.
> 2. `teach_synthesize` is not a standalone handle. It is the
>    `propose` arm of a larger **Mentl-voice substrate** whose surface
>    is an `Interact` effect. REPL, CLI, web playground, and the
>    (formerly-named) LSP are all handler projections on `Interact`.
>    LSP as a concept is dissolved by the paradigm.
>
> This document stays in the repo as historical reasoning. The
> successor walkthrough is **`MV-mentl-voice.md`** (to be written);
> the `teach_synthesize` conductor lands as one section inside it.
>
> Do not use this walkthrough to freeze code. Until `MV-mentl-voice.md`
> exists, the three substrate gaps in the roadmap are reframed: gap 2
> (`teach_synthesize` conductor) and gap 3 (`HandlerCatalog`) fold
> into the Mentl-voice substrate; gap 1 (`LFeedback` emit) is
> independent.

---

*Role-play as Mentl filling a typed hole. H5 resolved the annotation
path (narrow a row, checkpoint/verify/rollback, pick highest
leverage). The hole-fill path is a different shape — a proposed AST
fragment, not a row narrowing — and it needs its own walkthrough
before the conductor freezes in code.*

*See also:* `docs/specs/simulations/H5-mentl-arms.md` (annotation
oracle, already landed) · `docs/DESIGN.md` Ch 8 (Mentl architecture,
the speculative gradient, the Synth effect) · `ROADMAP.md` (this is
the voice/synth substrate lane).

---

## The scenario

```
fn sandbox_audit(src) with !Alloc + !Network =
  src
    |> parse
    |> ???               // <- user-typed hole; typed Ty known from context
    |> report
```

The hole at `|> ???` has a known type from context: inference
computed the surrounding pipeline's wire type. Call it
`expected = TFun([TString], TString, row_var(r))` with the row
constrained by the declared `!Alloc + !Network` envelope. Today,
`teach_synthesize(hole_handle, context)` (`mentl.mn:476-487`) asks
the installed `Synth` handler for candidates and trusts the first
one — no oracle discipline. The user gets a guess, not a proof.

**Mentl's TS proposition:** the same checkpoint → apply → verify →
rollback loop that `gradient_next` already runs for annotations,
applied to `Candidate(Node, Reason)` fragments. Every fragment
reaching the user is PROVEN to typecheck and satisfy the declared
row. If the proposer chain returns ten candidates and three prove,
the user sees three; if zero prove, the user sees "no proven
candidate" — **the substrate never hallucinates on Mentl's
surface.**

---

## Layer 1 — the shape split between annotation and hole-fill

### Annotation path (H5, landed)

```
gradient_next(handle)                        # fn handle
  → enumerate base_candidates + param_candidates
  → for each: graph_push_checkpoint
             apply_annotation_tentatively    # narrows ROW via graph_bind
             verify_after_apply              # handle is NBound?
             graph_rollback
  → pick_highest_leverage(proven_set)
```

The apply step is a **row narrowing** on the fn's handle. One
`graph_bind` per candidate; trail reverts on rollback.

### Hole-fill path (TS, this walkthrough)

```
teach_synthesize(hole_handle, context)       # Node handle (AST hole)
  → perform propose(expected_ty, allowed_row, context) -> [Candidate]
  → for each: graph_push_checkpoint
             apply_candidate_tentatively     # binds HOLE handle to ty
             verify_after_apply              # same
             graph_rollback
  → pick_highest_leverage(proven_set)        # shared helper
```

The apply step is a **hole binding** — the hole's handle is NFree
(or NBound to the expected type's row variable); the candidate
carries a `Node` whose own handle already has a type (the proposer
typechecked against the context when it produced the candidate).
The tentative apply unifies: `hole_handle`'s type gets bound to
`chase(candidate.node.handle)`'s type. One `graph_bind` per
candidate; trail reverts on rollback.

**The conductor is the same shape; only the apply primitive
differs.** This is Crystallization #10 (row algebra as one
mechanism over different element types) applied to the oracle:
**one oracle-loop over two candidate types.**

---

## Layer 2 — the six questions, resolved

### Q1. Apply mechanism

**Decision.** Add `apply_candidate_tentatively(hole_handle,
candidate) -> ()` in `mentl.mn`, peer to
`apply_annotation_tentatively`. Arm:

```
fn apply_candidate_tentatively(hole_handle, candidate) = {
  let Candidate(Node(_, _, cand_h), reason) = candidate
  let GNode(kind, _) = perform graph_chase(cand_h)
  match kind {
    NBound(ty) =>
      perform graph_bind(hole_handle, ty,
        Located(span_of_handle(hole_handle),
                Inferred("mentl synth-candidate"))),
    _ => ()        // candidate has no ground type; skip (verify will fail)
  }
}
```

No AST splicing. The tentative apply binds the hole's TYPE to the
candidate's type; verification checks that binding sticks without
conflict. Source-text splicing is a render concern (the Patch in
the Explanation), not a verification concern. The graph knows
whether the binding held; the source text is cosmetic.

### Q2. Scoring

**Decision.** Reuse `pick_highest_leverage`. For candidates the
scoring metric is row-minimality: the candidate whose resulting
row most tightly subsumes `allowed_row`. Add
`candidate_leverage(cand, allowed) -> Int` = count of effects in
`allowed` that the candidate's row strictly doesn't use. Ties
break by reason-chain depth (shorter reason = closer to the hole's
context = more local = preferred).

No LLM-style confidence scores. No frequency weighting. The
metric is row algebra, which is the only currency the oracle
speaks. This is Anchor 3 — Mentl solves Mentl.

### Q3. Budget

**Decision.** Cap at **N = 8** candidates per call (from the roadmap
discipline). Pre-filter: before calling `apply_*_tentatively`,
check `row_subsumes(candidate_row, allowed_row)`. If the
candidate's declared row already overshoots `allowed`, skip it —
no checkpoint needed. This is a cheap pre-filter (one subsumption
query, no bind), not an apply-cost measurement; "cost budget"
wording in PLAN is concretized here as "subsumption pre-filter
plus a hard count cap."

The conductor stops after the first 8 candidates pass the
pre-filter and attempt apply. Subsequent candidates (if any) are
dropped with a `W_BudgetExceeded` diagnostic so the proposer
chain learns to return fewer.

### Q4. Synth chain interaction

**Decision.** Proposers (`synth_enumerative`, future SMT, future
LLM) are **pure producers**. They return `Candidate` lists; they
do NOT self-verify beyond typechecking-at-production. The
conductor runs the shared oracle loop over whatever the chain
returns. `verify_candidate` is retained as the `Synth` effect's
per-op verification primitive (used inside a proposer when it
wants to discard candidates before surfacing them), but the
conductor does not rely on it — the conductor uses
`verify_after_apply` directly.

This makes the LLM-swap thesis concrete: a `synth_llm` proposer
can return ten garbage candidates; the oracle discards nine and
surfaces one; **the proposer's quality never leaks to the user
surface.**

### Q5. Verification row

**Decision.** `verify_after_apply` today checks only
`NBound | NErrorHole | NFree`. For hole-fill, extend the check to
also verify the fn-enclosing-hole's declared row still subsumes
the post-apply body row:

```
fn verify_hole_fill(hole_handle, fn_handle) = {
  if !verify_after_apply(hole_handle) { false }
  else {
    let GNode(NBound(TFun(_, _, body_row)), _) = perform graph_chase(fn_handle)
    let declared_row = declared_row_of(fn_handle)
    row_subsumes(body_row, declared_row)
  }
}
```

Verify ledger (V_Pending for refinements) is NOT checked by the
conductor — refinement verification is out-of-scope for the
oracle loop; it fires at compile-end. A candidate that introduces
an unfulfilled refinement obligation passes the oracle and
surfaces with the refinement pending; the user sees the
obligation in the next compile pass. This is honest: the oracle
proves types + rows, not refinements.

### Q6. Multi-site candidates

**Decision.** OUT OF SCOPE for the v1 conductor. A candidate
binds one hole. If the proposer wants to propose a cross-site
patch (e.g., "rename X to Y everywhere"), it packages that as a
single candidate whose `Node` represents the edit-set and returns
it — but the conductor only verifies the hole's handle. The
cross-site verification problem belongs to the `mentl rename` CLI
handler (PLAN §12, Priority 4), which has its own substrate (a
different graph-walk pattern).

Named sub-handle if this ever changes: **TS.1 multi-site
conductor.** Not taken on now.

---

## Layer 3 — what lands in code

### Edit surface (bounded)

All edits land inside `std/compiler/mentl.mn`. No other file is
touched by TS. Line estimates:

- `apply_candidate_tentatively` — ~10 lines, peer to
  `apply_annotation_tentatively`.
- `candidate_leverage` + integration with `pick_highest_leverage`
  (rename to shared helper or split) — ~15 lines.
- `try_each_candidate_loop` — ~20 lines, mirror of
  `try_each_annotation_loop` with the pre-filter gate.
- `verify_hole_fill` — ~8 lines.
- Rewrite `teach_synthesize` to drive the conductor — ~12 lines
  replacing the current 12-line stub.

Total: ~65 lines net, within the 50-80 band PLAN predicted.

### Dependencies on landed substrate

- `graph_push_checkpoint` / `graph_rollback` / `graph_bind` —
  LIVE (graph.mn).
- `row_subsumes` — LIVE (effects.mn).
- `Candidate(Node, Reason)` ADT — LIVE (mentl.mn).
- `Synth` effect + `synth_enumerative` handler — LIVE (mentl.mn:
  420-454).
- `verify_after_apply` — LIVE (mentl.mn:288-297).

No new substrate. No new effect. No new ADT variant. **The
conductor is the residue.**

---

## What TS reveals (expected surprise)

### Revelation A — declared_row_of must exist

`verify_hole_fill` reads the enclosing fn's declared row. Today
the substrate has `perform row_at_handle(target) -> EffRow` for
ambient-row-at-site queries, but not a declared-row lookup on an
fn handle. Either extend `row_at_handle` to return declared-row
when the handle is an FnStmt, or add a peer
`declared_row_of(fn_handle) -> EffRow`. Small; the infer pass
already stores this.

### Revelation B — span_of_handle may need widening

The tentative bind's `Located` reason wants the hole's source
span. Today graph nodes carry their `Reason` which sometimes
includes a `Located(span, _)` wrapper, but not every node has a
retrievable span. For the hole case specifically the parser
always records a span on the AST Node carrying the hole; threading
it to the conductor is a parameter on `teach_synthesize` —
already present as part of `context` but not extracted. Minor.

### Revelation C — pre-filter is load-bearing

Without the `row_subsumes` pre-filter, a proposer that returns 50
candidates triggers 50 checkpoint/apply/rollback cycles per hole.
With the pre-filter, 50 → ~3-5 viable on average (empirical
estimate based on how much declared rows actually constrain).
The pre-filter is not an optimization; it's how the oracle stays
within conversational latency. Name this in the implementer's
forbidden patterns list (drift mode 3 — don't let the pre-filter
devolve to a flat name check; keep it row-algebraic).

---

## Design synthesis (for approval)

**Direction approved for planning:**

- One conductor pattern, two candidate types. Annotation path
  landed in H5; hole-fill path lands in TS using the same shape.
- Apply primitive = `graph_bind` of hole_handle to
  candidate.node's type. No AST splicing; Patch text is a render
  concern.
- Scoring via row-minimality (count effects in allowed that the
  candidate doesn't use); ties break by reason-chain depth.
- Budget: 8-candidate cap + row_subsumes pre-filter before apply.
- Proposers are pure producers. Conductor owns the oracle loop.
- Verification = handle-is-NBound AND enclosing-fn body row still
  subsumes declared row. Refinement obligations NOT checked here
  (they fire at compile-end).
- Multi-site candidates out of v1 scope; named as TS.1 if ever
  needed.

### Dependencies

- H5 substrate (AWrapHandler + catalog + `try_each_annotation_loop`
  + `verify_after_apply`): LANDED.
- H1 evidence reification (type bindings are ground enough for
  verify): LANDED.
- H4 region escape (the pre-filter + verify path won't step into
  a region-escape hole without noticing): LANDED.

### Sub-handles surfaced

- **TS.1** — multi-site candidate verification. Not taken on now.
  Named in PLAN if ever load-bearing.
- **Revelation A follow-up** — decide whether `declared_row_of`
  is a new helper or an extension to `row_at_handle`. Absorbed
  into TS if the answer is "3-line extension"; split if it needs
  its own walkthrough.

---

## Riffle-back items (audit after TS lands)

1. Re-read H5's `try_each_annotation_loop` in light of TS's
   `try_each_candidate_loop` — do they share enough shape to
   factor into one generic `try_each_with_oracle`? **Rule of
   three:** don't factor until a third use case arrives.
   Fragment-fill via `Synth` + annotation via `gradient_next` are
   two; we wait for the third (likely refinement-strengthening at
   Arc F.1 SMT land).
2. Proposer fall-through order: today `synth_enumerative` is the
   only handler. When SMT / LLM proposers ship as siblings, the
   `~>` chain order determines who tries first. TS's conductor
   doesn't need to know the order — it runs on whatever
   `propose` returns. Document this in spec 09 when the second
   proposer lands.
3. `W_BudgetExceeded` diagnostic — add to `docs/errors/` when TS
   lands. Canonical explanation: "Mentl capped exploration at 8
   candidates. Tighten the hole's context or install a
   higher-leverage proposer."

---

## Closing

TS is not new substrate. It is the conductor that composes
substrate pieces that already fire individually. The work is
small (~65 lines) and contained (one file). The design questions
above are answered. The implementer types the residue.

**What closes when TS lands.** Every `[LIVE · surface pending]`
tag in `docs/traces/a-day.md` that depends on "Mentl suggests
(PROVEN)" transitions from "mechanism pending" to "mechanism
live" — the subsequent LSP handler integration surfaces PROVEN
candidates from day one, not first-proposer guesses. The AI
obsolescence thesis gains its load-bearing surface: the oracle
proves; the proposer merely proposes.
