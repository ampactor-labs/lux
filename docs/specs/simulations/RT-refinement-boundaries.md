# Refinement Types as Intent Boundaries
**Walkthrough ID:** RT-refinement-boundaries
**Status:** `[LANDED 2026-04-22]`
**Scope:** Formalizes the distinction between mechanical type inference and semantic intent boundaries. Replaces implicit prose with graph-backed `Verify` obligations for `pos` and `span` across the compiler.

---

## 1. The Realization

Mentl is built on Hindley-Milner (HM) type inference. Historically, Mentl functions omitted type annotations:
```mentl
fn lex_from(source, n, pos, line, col, buf, count) =
```
This is because HM inference mechanically derives that `source` is `String` and `n`/`pos` are `Int`. Adding `source: String` provides zero new information to the graph; it merely placates the programmer's anxiety. Therefore, under the "ultimate intent-manifestation" principle, structural annotations were omitted.

However, during the `FV.3` refinement type sweep, we observed a gap: `pos` isn't just an `Int`. It is an `Int` that must be non-negative. This was previously asserted via prose or assumed by the author.

When we applied the **eight interrogations** to `pos`, we asked:
* **Refinement?** What predicate bounds this value?
* **Graph?** What edge encodes this constraint?

The answer: *Nothing did.* It was mechanical, not intentional.

## 2. The Rule: Intent Boundaries

To solve this, we introduced the **Intent Boundary Rule**:

> **Parameter type annotations are strictly reserved for Intent Boundaries.** Do not use them to declare structural/mechanical types (like `String` or `Int`) which HM infers perfectly. Use them *only* to encode intent that inference cannot guess: Refinement Types (`ValidOffset`), Ownership Markers (`own`), and Row Constraints (`Pure`).

By explicitly typing `pos: ValidOffset` or `span: ValidSpan`, we shift the burden from ad-hoc prose into a unified `Verify` obligation that the handler can attempt to statically discharge. 

```mentl
fn lex_from(source, n: ValidOffset, pos: ValidOffset, line, col, buf, count) =
```

This transforms the function signature from a "memory blueprint" into a "semantic contract."

## 3. The 8 Interrogations, Applied

This discovery perfectly aligns with Mentl's core primitives:

1. **Graph:** The annotation injects a `TRefined` node into the reasoning trail.
2. **Handler:** The `Verify` effect handler intercepts the predicate and statically discharges it or surfaces a `V_Pending` warning.
3. **Verb:** A refinement acts as a convergent filter `|>` on the type space.
4. **Row:** Predicates like `span_valid` are strictly gated by `Pure`.
5. **Ownership:** Refinements evaluate values by `ref` (borrow).
6. **Refinement:** This is Primitive #6 made explicit at the boundary.
7. **Gradient:** Mentl uses this boundary to project a Confidence Gradient (green for statically verified, yellow for deferred).
8. **Reason:** The annotation attaches a `Reason` to the obligation, so failures state *why* a bounds-check was required.

## 4. Execution

This walkthrough was followed by mechanically applying this rule across the compiler:
- `FV.3.2`: 12 sites in `lexer.mn` updated with `n: ValidOffset` and `pos: ValidOffset`.
- `FV.3.4`: 56 sites in `parser.mn` and `infer.mn` updated with `span: ValidSpan`.

These are not mechanical patches—they are 68 new nodes in the graph proving the correctness of the compiler against itself.
