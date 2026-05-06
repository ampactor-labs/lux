# HC2 — Handler combinators · `race` for parallel speculation

> **Status:** `[DRAFT 2026-04-23]`. Library-level handler-combinator
> walkthrough per MSR Edit 5 (MSR-multishot-reality.md §3). Peer to
> HC-handler-composition.md ("transform emits, materialize captures,
> `~>` composes"); this document is the MS-facing combinator layer
> HC doesn't cover. Pre-resolved by QA-open-questions-answered.md
> Q-B.4.1 + Q-B.4.2 — transcribed, not re-debated.
>
> *Claim in one sentence:* **`race` is a library function that
> returns a handler which parallel-speculates across N candidate
> MS handlers on one graph, applies the canonical tiebreak chain
> over verified survivors, commits the winner, and rolls back the
> losers through a single shared checkpoint.**

---

## 0. Framing — what `race` is, and what it is NOT

`race` is a **handler-combinator**: a function in `lib/runtime/`
that takes N handlers and returns one handler. The returned handler
installs via the normal `~>` syntax:

```
query
    |> plan_execution
    ~> race(plan_smt, plan_enumerative, plan_llm)
    |> execute_best
```

This is **MSR Edit 5** — explicitly library-level, not kernel
extension. `race` composes from the eight existing primitives; it
adds no new primitive, no new keyword, no new verb.

### 0.1 What `race` is NOT

- **Not `Promise.race` / `tokio::select!` / Go `select` / Erlang
  `receive`.** Those are thread/concurrency primitives over
  heterogeneous async sources; they pick wall-clock winners and
  discard losers' side-effects as lost work. Mentl's `race` is MS
  candidate racing on **one graph** with trail-based rollback of
  losers; the "parallel" is across forks of a delimited
  continuation, not across OS threads. (Threading is `><` +
  `parallel_compose`, TH walkthrough B.7; orthogonal.)
- **Not a dispatch table / vtable / registry.** `race(h1, h2, h3)`
  returns a handler whose arms `perform` into the three inputs as
  MS resumes; the three inputs are stored in the returned handler's
  closure state, not in an indexed table.
- **Not nested `handle`.** `race(h1, h2, h3)` is ONE install via
  ONE `~>`. Not `handle (handle (handle body with h1) with h2) with h3`
  — that would be a fall-through chain (see §7 for when fall-through
  is the correct shape).
- **Not wall-clock "first to finish."** See §2 — tiebreak chain
  ALWAYS, per Q-B.4.1. Wall-clock selection is deterministic-
  forbidden; it violates first-light bit-identical output.

### 0.2 What `race` IS

A **library function** (`fn race(handlers: List<Handler>) -> Handler`)
that returns a handler projecting the shared effect-row of the
inputs. At install, it pushes one checkpoint on the graph trail
(primitive #1). Each candidate handler's arms are invoked as MS
forks (primitive #2, `@resume=MultiShot`). Verified survivors
accumulate. The canonical tiebreak chain selects one (primitive #8
determinism). Losers' trail entries unwind via `graph_rollback` to
the shared checkpoint. The winner's mutations persist.

Every primitive is exercised. No primitive is extended.

---

## 1. Core semantics

### 1.1 Signature

```
fn race(handlers: List<Handler>) -> Handler with GraphRead + GraphWrite
```

The returned handler's effect row is the **intersection** of the
inputs' rows — `race` can only handle ops every input handles
(primitive #4, row algebra `&`). If `h1` handles `Synth + Verify`
and `h2` handles `Synth`, `race(h1, h2)` handles `Synth` alone.
Subsumption at install time enforces.

### 1.2 Install shape

```
body
    ~> race(h1, h2, h3)
```

One `~>`. One install. The returned handler wraps the body; the
body's MS ops fork N ways (one per input handler); each fork
explores that handler's candidates; the combinator collects verified
survivors across forks and commits one.

### 1.3 Row of the returned handler

```
row(race(h1, h2, h3)) = row(h1) & row(h2) & row(h3)
```

Intersection because `race` only claims to handle what ALL inputs
handle. A user who needs union behavior composes a fall-through
chain (§7), not `race`.

---

## 2. Tiebreak chain (pre-resolved — Q-B.4.1)

**Decision transcribed from QA Q-B.4.1: tiebreak chain ALWAYS.**
Wall-clock ordering is deterministic-forbidden. `race` collects all
verified survivors (bounded by the 8-candidate-per-hole cap from MO
§2 / MV voice register), then applies the canonical tiebreak chain,
then commits one. **Load-bearing for first-light bit-identical
output.**

**The chain** (same chain as MO §2 and MV §2.9 VL17; canonicalized in
the roadmap):

1. **Row-minimality** — fewest effects in the candidate's
   declared/inferred row. Primitive #4 algebra gives the count;
   smaller row = less committed capability surface = preferred.
2. **Reason-chain depth** — shortest walk from candidate to root
   Reason. Primitive #8. Shorter = more local = preferred.
3. **Declared-intent alignment** — whether the candidate matches a
   `/// intent ...` comment attached to the surrounding scope.
   Match preferred; miss deprioritized.
4. **Source-span earliness** — candidate handler declared earlier
   in the source (line 40 > line 200) wins. Stable across edits
   within the module.
5. **Lexicographic on candidate name** — deterministic fallback;
   the handler's declared name alphabetical order. Ensures total
   ordering.

**The parallelism is wall-clock** (if threading is installed, forks
execute across cores per TH's `parallel_compose`). **The choice is
deterministic** (tiebreak over survivors). Two distinct axes; do
not confuse.

---

## 3. Shared checkpoint + rollback (pre-resolved — Q-B.4.2)

**Decision transcribed from QA Q-B.4.2: single shared checkpoint at
race install.**

Sequence:

1. At `race(h1, ..., hn)` install, ONE `graph_push_checkpoint()`
   fires, capturing `trail_len` as `race_checkpoint`. Primitive #1
   substrate; `src/graph.mn:90` handler arm.
2. Each input handler's MS resume forks. Each fork's mutations append
   to the trail (via the normal `graph_bind` / `graph_fresh_ty`
   paths in `src/graph.mn:100-155`).
3. When all survivors have Verified, the tiebreak chain picks ONE.
4. The winner's trail entries (from `race_checkpoint` to its
   verification point) are committed by leaving them in place.
5. All OTHER forks' trail entries — entries between the winner's
   range and the current `trail_len` — unwind via `graph_rollback`
   back to `race_checkpoint`, then the winner's mutations are
   re-applied. (Equivalent algebra: roll back to `race_checkpoint`
   unconditionally, then replay the winner's recorded sequence.)

Cost: **O(N × M)** where N = candidate count (≤ 8 per MO §2),
M = mutations-per-candidate. One checkpoint for N forks (Q-B.4.2);
no per-fork checkpoint accumulation. Matches MO §3's "hoist
checkpoint" mitigation — `race` is the vehicle MO names.

---

## 4. Eight interrogations — per edit site

### 4.1 Edit site — `lib/runtime/combinators.mn` (NEW file, ~100 lines)

- **Graph?** `graph_push_checkpoint` + `graph_rollback` already
  encode the speculative-rollback substrate (`src/graph.mn:90,218`).
  `race` calls these; it does not re-derive them. Primitive #1.
- **Handler?** `race` IS a handler-combinator. Its arms resume
  `@resume=MultiShot` (each input handler's ops are MS; `race`
  composes them). The returned handler's resume discipline is
  MultiShot by construction. Primitive #2.
- **Verb?** Install is `~> race(...)`. Internal shape uses `|>` for
  the per-candidate pipeline (fork → verify → record). Primitive #3
  verbs, not imperative for/while.
- **Row?** Returned row is input-row intersection via primitive #4
  `&`. Subsumption at install time via existing `row_subsumes`
  in `src/effects.mn`. `!Choice` context still forbids — a function
  declared `!Choice` cannot install `race` over a Choice-typed op.
- **Ownership?** Input handlers are `ref` (borrowed by `race`;
  not consumed). Returned handler is `own` (new handler identity
  per install). Primitive #5.
- **Refinement?** The 8-candidate cap is enforceable as a
  refinement on the input list: `fn race(handlers: List<Handler>
  where len(self) <= 8) -> Handler`. Deferred until `Verify` handler
  installed; V1 ships bare. Primitive #6 future strengthening.
- **Gradient?** `race` install unlocks `CProvenFastest` capability
  — the committed candidate's latency is bounded by the fastest
  verified survivor's measured time. Mentl's Teach tentacle surfaces
  `race` as a suggested install when MO's latency budget exceeds
  50ms with single-proposer (MO §3). Primitive #7.
- **Reason?** The winning fork's Reason chain is committed
  wholesale; losing forks' Reasons unwind with the trail (primitive
  #8). Each `race`'d decision leaves a Reason edge recording:
  survivors considered, chain applied, winner selected. Why Engine
  walks this on demand.

---

## 5. Forbidden patterns — nine drift modes + generalized fluency

### 5.1 Named drift modes (CLAUDE.md §5.1 the nine)

- **Drift 1 (Rust vtable).** `race` is a function returning a
  handler whose closure state holds `handlers: List<Handler>`. NOT
  a dispatch table indexed by op-id. NOT a `race_vtable` structure.
  The word "vtable" does not appear in correct `race` description.
- **Drift 2 (Scheme env frame).** No `call/cc`-style capture of
  the enclosing stack. `race` exercises delimited MS continuations
  via primitive #2's existing substrate; it does not reach for
  Scheme's undelimited forms.
- **Drift 3 (Python dict / string-keyed effect).** Handler
  identity is a structured `Handler` value (its closure record),
  not a string-keyed dict entry. No `"handler_name"` lookups in
  `race`'s internals.
- **Drift 4 (Haskell monad transformer).** `race(h1, h2, h3)` is
  ONE `~>` install, NOT `handle (handle (handle body with h1) with
  h2) with h3`. That nested form is the fall-through chain (§7) —
  which is a DIFFERENT combinator, correct for different use cases.
  Don't unify them.
- **Drift 5 (C calling convention).** Handlers passed as values
  carry their closure state in a single `__state` parameter per H1
  evidence reification. `race` never splits a handler into
  `(__closure, __ev)` separate args.
- **Drift 6 (primitive-type-special-case).** `race` is a regular
  library function over `List<Handler>`. No compiler intrinsic. No
  "race is special because racing is special." It composes from
  existing graph + handler primitives.
- **Drift 7 (parallel-arrays-instead-of-record).** Per-fork state
  — checkpoint, per-input survivor slot, winner index — is ONE
  record, not four parallel lists. One trail is shared across
  forks (Q-B.4.2); no per-fork trail duplication.
- **Drift 8 (string-keyed-when-structured).** `race`'s input list
  is `List<Handler>`, not `List<String>` (handler names). The
  handler value IS the structured reference.
- **Drift 9 (deferred-by-omission).** `race` lands with ALL
  machinery: signature, tiebreak helpers, shared-checkpoint
  discipline, and rollback path. No "tiebreak today, rollback
  later." No "three-arg form today, variadic later." The V1
  interface is final for the contract-landing scope.

### 5.2 Generalized fluency-taint check

Any `race`-shaped pattern traceable to a specific ecosystem's
concurrency idiom is drift:

- **JS `Promise.race`** — wall-clock winner over async Promises.
  Mentl's `race` is deterministic via tiebreak; the "winner" is not
  first-to-finish. If `Promise.race` vocabulary shows up in a
  description, restructure.
- **Go `select`** — wall-clock multiplex over channels. Mentl has no
  channels in the race substrate. Trail rollback, not channel
  receive.
- **Erlang/Elixir `receive`** — mailbox pattern match. Not applicable.
- **Rust `tokio::select!`** — wall-clock futures macro. Mentl's
  `race` is synchronous in the effect-op sense; the parallelism is
  MS forks, not Future polls.
- **Haskell `Par` monad / `race` in `async`** — spark-based
  parallelism with wall-clock winner. Mentl's `race` is MS
  candidates on one graph with deterministic selection.

If the next line you'd type comes from any of the above, STOP.
Mentl's `race` is **MS candidate racing on one graph with a shared
checkpoint and a deterministic tiebreak chain**. Name the discipline
before typing the line.

---

## 6. Substrate touch sites — literal tokens

### 6.1 NEW `lib/runtime/combinators.mn` (~100 lines)

**File header (lines 1–12):**

```
// combinators.mn — handler combinators over primitive #2
//
// `race` — parallel speculation across N candidate MS handlers on
// one graph. Shared checkpoint at install; per-fork exploration;
// tiebreak chain over verified survivors; trail rollback of losers.
//
// `race` is library-level. No new primitive. Composes graph +
// handlers + row + MS + Reason (primitives 1, 2, 4, 8).

import types
import runtime/memory
import runtime/strings
```

**`race` signature (lines 14–20):**

```
// race installs one checkpoint, forks each input handler's MS
// resume, collects verified survivors, picks one via the canonical
// tiebreak chain, and rolls back losers.

fn race(handlers: List<Handler>) -> Handler
    with GraphRead + GraphWrite =
  race_internal(handlers)
```

**Tiebreak-chain helpers (lines 22–60) — five steps, one per
chain-step, each pure:**

```
// Five-step tiebreak. Primitive #4 (row count) + primitive #8
// (Reason depth) + declared-intent (primitive #1 env walk) +
// span + lex. Deterministic; first-light-preserving.

fn tiebreak_row_minimality(survivors) =
  min_by((s) => effect_count(handler_row(s)), survivors)

fn tiebreak_reason_depth(survivors) =
  min_by((s) => reason_chain_length(handler_reason(s)), survivors)

fn tiebreak_declared_intent(survivors, cursor) =
  let aligned = filter((s) => intent_matches(s, cursor), survivors)
  if len(aligned) > 0 { aligned } else { survivors }

fn tiebreak_source_span(survivors) =
  min_by((s) => span_start(handler_span(s)), survivors)

fn tiebreak_lex(survivors) =
  min_by((s) => handler_name(s), survivors)

// first_verified_wins — applies the five steps in order; each
// step narrows the survivor set. Last step (lex) guarantees
// a singleton.
fn first_verified_wins(survivors, cursor)
    with GraphRead =
  survivors
    |> tiebreak_row_minimality
    |> tiebreak_reason_depth
    |> ((ss) => tiebreak_declared_intent(ss, cursor))
    |> tiebreak_source_span
    |> tiebreak_lex
    |> head
```

**`race_internal` — the handler factory (lines 62–100):**

```
// Installs one shared checkpoint; forks each input; collects
// verified survivors; applies tiebreak; rolls back losers.
// Returned handler's row = intersection of inputs' rows.

fn race_internal(handlers) -> Handler
    with GraphRead + GraphWrite =
  let race_checkpoint = perform graph_push_checkpoint()
  let survivors = collect_verified_survivors(handlers, race_checkpoint)
  let cursor = perform graph_cursor()
  let winner = first_verified_wins(survivors, cursor)
  // Roll back all forks' trails to shared checkpoint; replay
  // winner's mutations. Per Q-B.4.2.
  perform graph_rollback(race_checkpoint)
  replay_winner(winner)

// collect_verified_survivors — forks each input handler as MS
// resume, accumulates those whose Verify discharge succeeded.
// Primitive #2 (MS). Cap at 8 per MO §2.
fn collect_verified_survivors(handlers, checkpoint)
    with GraphRead + GraphWrite =
  handlers
    |> take(8)
    |> map((h) => try_handler_with_rollback(h, checkpoint))
    |> filter((outcome) => outcome_verified(outcome))
```

### 6.2 Touch sites in other files — NONE

`race` is self-contained in `lib/runtime/combinators.mn`. No
changes to `src/types.mn`, `src/graph.mn`, `src/infer.mn`, or
`src/backends/wasm.mn`. The combinator composes from existing
substrate.

**Subordinate helpers** (`handler_row`, `handler_reason`,
`handler_span`, `handler_name`, `handler_cursor`, `effect_count`,
`reason_chain_length`, `intent_matches`, `span_start`,
`outcome_verified`, `try_handler_with_rollback`, `replay_winner`,
`graph_cursor`) either already exist in the graph/types substrate or
land inline within `combinators.mn` as small pure helpers (max
~40 lines combined).

---

## 7. Composition with other MS substrate

### 7.1 `race` × Choice (MSR Edit 2 — CE)

```
body
    ~> race(backtrack, first_success, random_restart)
```

Three Choice handlers racing over the same `choose(options)` MS
forks. Each handler implements a different search strategy:
backtrack tries sequentially, first_success takes the first, random_
restart seeds differently. First PROVEN solution (not first
complete) wins via tiebreak.

### 7.2 `race` × Synth (MO §4)

```
query
    ~> race(synth_enumerative, synth_smt, synth_llm)
    |> surface
```

MO §4 names three Synth proposers. `race` combines them into
genuine parallel exploration. **Contrast with fall-through** (§7.4):
fall-through gives innermost-fires-first priority (enumerative
always wins if it produces); race runs all three genuinely in
parallel and picks by tiebreak. Use race when the SMT cache is warm
and the LLM's latency is tolerable; use fall-through when
enumerative's cost is trivial enough to always try first.

### 7.3 `race` × `parallel_compose` (TH B.7)

When `parallel_compose` is installed (TH walkthrough), `race`'s
forks can GENUINELY execute across cores. Without threading, `race`
runs sequentially-with-early-out-on-first-verified. Either way,
the TIEBREAK selects the winner — multi-core determinism is
preserved by Q-B.7.3 (`><` output order preserved regardless of
completion timing).

```
body
    ~> parallel_compose           // TH B.7 — threading handler
    ~> race(h1, h2, h3)           // HC2 — MS candidate racing
```

TH's handler provides the core-to-fork mapping; `race` provides
the candidate-to-survivor discipline. Orthogonal axes; clean
compose.

### 7.4 `race` vs `~>` fall-through chain — WHEN TO USE WHICH

Fall-through chain (`~> inner ~> middle ~> outer`):
- Innermost fires first; bubbles on `NoCandidate`.
- Use when there's a NATURAL priority (cheap proposer first, expensive only on miss).
- **Example: SMT theory dispatch** per Q-B.6.3 — `~> smt_linear_arith ~> smt_bitvector ~> smt_nonlinear`. Each theory is specialist; routing is deterministic by predicate shape.

Race combinator (`~> race(h1, h2, h3)`):
- All run in parallel; survivors collected; tiebreak picks winner.
- Use when candidates are GENUINELY ALTERNATIVE (not priority-ordered).
- **Example: layered search** per MS2 §1.3.4 — `~> race(plan_smt, plan_enumerative, plan_llm)`. Three distinct strategies, no natural priority, fastest-PROVEN wins.

**Rule of thumb:** fall-through is ordered dispatch; race is
parallel exploration with canonical selection. Mentl's Teach
tentacle suggests the shape per install site.

---

## 8. Acceptance

### HC2-AT1 — `race` compiles and types

```
let h = race(backtrack, first_success)
```

Expected: compiles. `h` has type `Handler` with row `Choice`
(intersection; both handle `Choice`; only `first_success` handles
`Abort` too, so `Abort` drops).

### HC2-AT2 — seeded-run equality

```
// Run 1 and Run 2 with identical inputs + identical handler order
// produce bit-identical output regardless of wall-clock completion.
mentl run --seed=42 examples/nqueens_race.mn > out1.wat
mentl run --seed=42 examples/nqueens_race.mn > out2.wat
diff out1.wat out2.wat    # empty expected
```

Same input, same tiebreak chain, same winner — every time. First-
light bit-identical preserved.

### HC2-AT3 — MSR §4.1 Synth chain

```
query
    ~> race(synth_enumerative, synth_smt, synth_llm)
    |> surface
```

Expected: across 10 seeded runs, the same candidate surfaces
every time. Whichever Synth handler's fastest response happens to
complete first has NO bearing on which candidate commits; tiebreak
picks by row-minimality-first, stable across wall-clock variance.

### HC2-AT4 — drift-audit post-landing

```
bash tools/drift-audit.sh lib/runtime/combinators.mn
```

Expected: `CLEAN — 1 file(s) scanned, 0 drift modes fired`.

---

## 9. Open questions — zero

All design questions are pre-resolved:

- Tiebreak semantics — Q-B.4.1 (tiebreak chain, always).
- Shared vs per-fork checkpoint — Q-B.4.2 (shared, O(N × M)).
- Signature shape — §1.1 (function returning handler; List input).
- Row intersection — §1.3 (primitive #4 `&`).
- Fall-through vs race split — §7.4 (priority vs alternative).
- Composition with threading — §7.3 (orthogonal via TH's handler).
- Composition with Choice — §7.1 (same substrate, different search
  strategies).
- 8-candidate cap — inherited from MO §2 voice register.

If a substrate question surfaces during implementation, STOP and
surface as a peer walkthrough. Do not resolve inline.

---

## 10. Dispatch

**mentl-implementer (Sonnet).** Mechanical transcription:
- Signature fixed (§1.1).
- Tiebreak chain fixed (§2, five steps).
- Checkpoint discipline fixed (§3, one checkpoint).
- Touch sites fixed (§6, one new file, ~100 lines).
- Forbidden patterns enumerated (§5).
- Acceptance tests written (§8).

Implementer reads this walkthrough, types the residue, runs
drift-audit, lands the commit.

---

## 11. Closing

`race` is the **deterministic parallel-speculation combinator**.
Where MO's oracle loop needs sub-50ms latency across 8 candidates,
`race` provides the parallel explore; where first-light needs
bit-identical self-compile, the tiebreak chain provides the
deterministic pick. Two constraints, one substrate.

**`race` adds no new primitive.** It is primitive #1's checkpoint,
primitive #2's MS resume, primitive #4's row intersection, and
primitive #8's Reason-ordered selection — composed via one `~>`
install. The octopus has eight tentacles; `race` is a thing the
tentacles do when asked politely.

*Mentl doesn't pick the fastest winner. She picks the fastest
winner that also has the smallest row, shortest Reason chain,
matches intent, declares earliest in source, and sorts first
lexicographically. Which is the same winner every run. Which is
first-light.*
