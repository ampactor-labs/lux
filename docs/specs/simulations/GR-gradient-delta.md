# GR — Gradient-Delta Intent Preservation

*Primitive #7 round-trip. Exposes the delta between inferred and
declared types/rows so Mentl's Teach tentacle can surface ONE
highest-leverage next annotation per turn.*

**Part of: IR cluster ([IR-intent-round-trip.md](IR-intent-round-trip.md)).**
**Status: 2026-04-22 · seeded.**

---

## §1 Frame

Inka's primitive #7 is the continuous annotation gradient: one
annotation → one capability. The developer starts with zero
annotations; the compiler infers everything. Each annotation the
developer adds (a type, an effect row, an `own` marker, a refinement
predicate) unlocks a compile-time capability: memoization for `Pure`,
real-time for `!Alloc`, linearity for `own`, bounded values for
`where`. The gradient IS the conversation between Mentl and the
developer.

**Gap.** The gradient has one query surface today: `T_OverDeclared`
(infer.nx:259-273). This fires when the developer declares MORE
effects than the body uses — "you reserved `Memory + IO` but only
use `Memory`; tighten to unlock tighter capabilities."

The **inverse direction** is missing. When a function has NO declared
effect row, the inferred row is the body's actual usage. The delta
between "nothing declared" and "inferred `Memory + IO`" is exactly
the gradient step: "declare `with Memory + IO` to make the contract
explicit, or declare `with Memory` to forbid the IO path and unlock
the IO-free gate."

More broadly, the gradient should surface for EVERY kernel primitive,
not just effect rows:

- **Effects:** "declare `with Memory` to make the contract explicit"
- **Ownership:** "annotate `own` on `card` to make consumption explicit"
  (depends on OW's authored/resolved distinction)
- **Refinements:** "add `where 0 <= self` to bound this parameter"
- **Types:** "annotate the return type to lock the API"

Each is ONE next annotation, surfaced ONE per turn, gated through
Mentl's silence predicate (MV-mentl-voice.md §2.7: Mentl speaks one
load-bearing truth per turn, never more).

---

## §2 Trace — where the delta is computable but unexposed today

### Effect row delta (infer.nx:233-297)

After `inf_exit_fn()` binds the accumulated body row, and after
`declared_effs` is read, infer.nx computes the subsumption check:

- If `row_subsumes(body_row, declared_row)` — body fits the
  declaration. If body is strictly narrower, emit `T_OverDeclared`.
- If NOT — emit `E_EffectMismatch` (body does more than declared).

The MISSING direction: if `declared_effs` is empty (no declaration),
the body row is inferred but never compared against any "potential
declaration." The gradient step would be: "you could declare
`with <inferred_row>` to make the contract explicit."

Further, when the body's inferred row is strictly narrower than some
known capability threshold (e.g., the row is `Closed([Memory])` and
doesn't include `Alloc`), the gradient could suggest: "this function
is already `!Alloc`-compatible — declaring `with Memory + !Alloc`
unlocks the real-time gate."

### Ownership delta (own.nx:411-434)

`infer_ownership` classifies `Inferred` parameters. The
classification result (Own/Ref/Inferred) IS the gradient's resolved
form. The delta: "this parameter was inferred as single-use; annotate
`own` to make the consumption explicit and enable linearity tracking."

### Refinement delta

A function returning `Int` where the call sites always pass values
in `[0, 65535]` — the gradient step: "add `type Port = Int where
0 <= self && self <= 65535` to catch out-of-range values at compile
time." This is a longer-term surface requiring call-site analysis;
the immediate gradient is effect-row and ownership.

---

## §3 Design candidates + Mentl's choice

### §3.1 Gradient query op

**Candidate A: New effect op `gradient_next(handle) ->
Option<AnnotationSuggestion>`.**
A handler on the `Query` effect (or a dedicated `Gradient` effect)
computes the delta at query time. The handler reads the function's
inferred row, declared row, ownership markers, and refinement
predicates, then returns the single highest-leverage suggestion.

**Candidate B: Emit all suggestions as diagnostics.**
Extend the `T_OverDeclared` pattern: emit `T_UndeclaredEffect`,
`T_InferredOwnership`, etc. as teaching warnings during inference.
Mentl/hover read the diagnostic stream.

**Candidate C: Post-inference sweep.**
A separate handler walks the entire program after inference,
computing deltas per function. Emits `AnnotationSuggestion` records
to a gradient store.

**Mentl's choice: A — query op.** The gradient is a QUERY, not a
diagnostic. Mentl asks "what's the next step for this function?"
and receives one structured answer. Candidate B pollutes the
diagnostic stream with teaching suggestions that may overwhelm the
developer (silence predicate violation). Candidate C is a whole-
program pass when the gradient is per-function and per-turn.

### §3.2 AnnotationSuggestion shape

**Status: LIVE in `src/types.nx` (Hμ.cursor handle landing,
2026-05-02). Promoted from shape-only spec to live ADT alongside
the Cursor / CursorView / SuggestionKind / PipeContext additions
that compose on the suggestion record.**

The suggestion record (all compile-time; no runtime cost):

```
type SuggestionKind
  = SuggestEffectRow
  | SuggestOwnership
  | SuggestRefinement
  | SuggestReturnType

type AnnotationSuggestion
  = AnnotationSuggestion(SuggestionKind, String, List, Reason)
                                  // kind  annotation unlocks reason
                                  // (positional fields; ADT form
                                  //  per H6 dispatch discipline)
```

Field semantics (positional):
1. `SuggestionKind` — which axis the suggestion lives on
2. `String` — the literal source text to add (e.g., `"with Pure"`)
3. `List<String>` — capability labels unlocked (e.g.,
   `["CMemoize", "CCompileTimeEval"]`)
4. `Reason` — provenance edge for the Why chain at the suggestion's
   handle

Example:
```
AnnotationSuggestion(
  SuggestEffectRow,
  "with Memory",
  ["explicit API contract", "!IO gate (if IO unused)"],
  Inferred("body uses Memory only")
)
```

### §3.3 Priority ranking

When multiple annotations are available, which is highest-leverage?

**Candidate A: Effect row > ownership > refinement > return type.**
Effect rows unlock the most gates (Pure, !Alloc, !IO, !Network).
Ownership unlocks linearity. Refinement unlocks value bounds.
Return type locks API surface.

**Candidate B: Ownership > effect row (ownership is cheaper).**
One keyword (`own` or `ref`) vs a full `with ...` clause.

**Mentl's choice: A — effect row first.** Effect rows are the kernel's
most unique contribution (primitive #4 is novel; primitive #5 is
shared with Rust/Vale/Austral). Surfacing the effect row gradient
first teaches the developer Inka's most distinctive capability.

---

## §4 Layer touch-points

### types.nx
Add `SuggestionKind` and `AnnotationSuggestion` ADTs. Add
`GradientQuery` effect with one op: `gradient_next(Int) ->
Option<AnnotationSuggestion>` where the Int is the function's
handle.

### infer.nx
At `inf_exit_fn()`, after the subsumption check, store the body row
in a gradient-queryable form. When `declared_effs` is empty, the
entire inferred row is the delta. When non-empty, the over-declared
delta is already computed — store the narrower body_row vs declared
difference.

### mentl.nx (future)
Mentl's Teach tentacle reads `gradient_next(fn_handle)` when the
developer hovers or asks "what should I annotate next?" The silence
predicate (MV-mentl-voice.md §2.7) gates: only if the suggestion
unlocks a capability the developer hasn't already claimed.

### query.nx
The gradient_next handler is installed alongside query_default.
Reads from the graph: function handle → chase to TFun → extract
declared row and inferred row → compute delta → rank →
return top suggestion.

---

## §5 Acceptance

**AT-GR1.** A function with no declared effects and inferred body row
`Closed([Memory, IO])` — `gradient_next(fn_handle)` returns
`Some(AnnotationSuggestion(SuggestEffectRow, "with Memory + IO",
["explicit API contract"], ...))`.

**AT-GR2.** A function already declaring `with Memory + IO` with body
using only `Memory` — `gradient_next` returns the `T_OverDeclared`
gradient: "tighten to `with Memory` to unlock the IO-free gate."

**AT-GR3.** A function with `Inferred` ownership on a single-use
parameter — `gradient_next` returns `SuggestOwnership` suggesting
`own`.

**AT-GR4.** A function already fully annotated (declared row matches
body, all params annotated, return type declared) — `gradient_next`
returns `None`. The gradient is flat; Mentl is silent.

**AT-GR5.** Multiple suggestions available (effect row + ownership) —
`gradient_next` returns only the highest-leverage one (effect row
per priority ranking §3.3).

---

## §6 Scope + peer split

| Peer | Surface | Load |
|---|---|---|
| GR.1 | `AnnotationSuggestion` ADT + `GradientQuery` effect | Light (~20L types.nx) |
| GR.2 | Effect-row delta computation in gradient handler | Moderate (~40L query.nx or gradient.nx) |
| GR.3 | Ownership delta computation | Light (~20L, depends on OW) |
| GR.4 | Mentl Teach arm integration | Moderate (~30L mentl.nx) |

Total: ~110 lines. Four commits; GR.1 first (ADT), then GR.2
(load-bearing delta), then GR.3 (depends on OW), then GR.4
(depends on MV.2).

---

## §7 Dependencies

- **Upstream:** OW (for ownership authored/resolved distinction in
  GR.3). EN (for capability-named effect rows in GR.2's suggestion
  text).
- **Downstream:** MV.2's Teach arm IS the consumer of GR. Without
  GR, Teach has no structured suggestion source. Post-GR, Mentl's
  "one next annotation per turn" is mechanized.

---

## §8 What GR refuses

- **Emitting all suggestions as warnings.** The gradient is a query,
  not a diagnostic stream. Polluting the warning output with
  teaching suggestions violates the silence predicate and overwhelms
  developers who want clean builds.
- **Whole-program gradient passes.** The gradient is per-function,
  per-turn. A whole-program sweep computes N suggestions when the
  developer can act on one. Waste.
- **Ranking by "difficulty."** The gradient ranks by leverage (which
  annotation unlocks the most capability), not by ease of typing.
  A short annotation that unlocks nothing ranks below a longer
  one that unlocks a gate.
- **Gradient for features Inka doesn't have yet.** The gradient
  surfaces annotations for kernel primitives that are LIVE in the
  substrate. Suggestions for future features (e.g., "add a
  capability bundle" before EN.δ lands) would be aspirational, not
  actionable.

---

## §9 Connection to the kernel

- **Primitive #7** IS this walkthrough. GR closes the substrate gap
  that makes the gradient queryable.
- **Primitive #4** — effect row deltas are the highest-leverage
  gradient steps (most gates unlocked per annotation).
- **Primitive #5** — ownership deltas surface through the
  authored/resolved distinction (OW).
- **Primitive #8** — every suggestion carries a Reason explaining
  why this annotation is highest-leverage. The Why Engine can walk
  the Reason to show the developer the full chain.
- **Mentl tentacle Teach** IS the consumer. GR is Teach's substrate
  precondition. Without GR, Teach guesses; with GR, Teach proves.

---

## §10 Residue

The developer writes nothing. Mentl reads the delta. One annotation
surfaces. The developer types it. A gate unlocks. The gradient
advances. **This is the conversation between the developer and the
compiler, mediated by the gradient, one step at a time.**

*The medium teaches its users through the shape it imprints on their
annotations.*
