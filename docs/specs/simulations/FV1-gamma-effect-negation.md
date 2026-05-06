# FV.1.γ: Lone Effect Negation & Ownership
**Walkthrough ID:** FV1-gamma-effect-negation
**Status:** `[LANDED 2026-04-22]`
**Scope:** Implementing "universe-minus" logic for lone negations (`with !Mutate`) to unblock Primitive #5 (Ownership Markers) via Primitive #4 (Boolean Effects).

---

## 1. The Insight

The user astutely pointed out that FV.4 (`!Mutate` ownership sweep) and FV.1 (Effect Negation) are fundamentally the exact same mechanism. 

Mentl unifies regions, ownership, and effects into a single Boolean algebra. An immutable borrow (`ref`) mathematically translates to a region-freeze under a `!Mutate` effect constraint. A value that cannot escape translates to `!Alloc`.

## 2. The FV.1.γ Fix

Before this change, if a developer typed `fn process(buffer) with !Mutate`, Mentl's `build_declared_row` would start with `EfPure` and intersect the negation against it, collapsing the row to `EfPure`. This broke capability-security by preventing a function from declaring a DENY-list ("anything except Mutate").

We rewrote the builder to properly isolate `EfNeg(Closed([Mutate]))`:

```mentl
fn build_from_partition(pos, neg) =
  if len(pos) == 0 && len(neg) == 0 { EfPure }
  else if len(pos) == 0 { neg_row(mk_ef_closed(neg)) } // NEW: Universe-minus
  else {
    let base = mk_ef_closed(pos)
    fold_negations(neg, base)
  }
```

We also updated `unify_row_canonical` in `effects.mn` to properly unify `EfNeg` nodes, preventing infinite loops when higher-order functions unify their universe-minus capability constraints.

## 3. Mentl Solving Mentl (The Test)

Following Mentl's testing philosophy ("no `tests/` directory as substrate claim"), we did not write an external test script. Instead, we wrote the test *directly into the compiler's own effect engine*:

```mentl
// ═══ Substrate Tests (Mentl solving Mentl) ═══════════════════════════
// This function exists to statically prove FV.1.γ (Lone Effect Negation).
// It declares `with !Mutate`. The compiler's own type inference will
// now infer its row as EfNeg(Closed([Mutate])) instead of collapsing it
// to EfPure. The very act of the compiler type-checking itself is the test.

fn test_mutate_freeze(buffer: ValidSpan) with !Mutate = buffer
```

Because `test_mutate_freeze` resides in `effects.mn`, the Mentl compiler must successfully parse and statically verify it. This proves that `!Mutate` (FV.4 ownership marker) is now fully native to the architecture.

## 4. The 8 Interrogations, Applied

1. **Graph?** Evaluated directly into the `GNode(NBound(EfNeg(..)))` representation.
2. **Handler?** Handled by `graph_bind_row` during inference unification.
3. **Verb?** Propagates down the `|>` data flow.
4. **Row?** It *is* the row constraint!
5. **Ownership?** It explicitly establishes `ref` (borrowed immutable) semantics.
6. **Refinement?** Tested alongside `buffer: ValidSpan`.
7. **Gradient?** Mentl can now accurately display `!Mutate` capability stances rather than incorrectly showing `Pure`.
8. **Reason?** Subsumption failures link directly to the mismatched effect.
