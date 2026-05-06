# E_PurityViolated

**Kind:** Error
**Emitted by:** `effects.mn` (spec 01, `unify_row`)
**Applicability:** MachineApplicable

## Summary

A function declared `with Pure` (or whose context requires purity)
has an inferred effect row that is not empty. The Boolean algebra
(spec 01) proves `body_row ⊆ Pure` holds only when `body_row = Pure`;
this mismatch broke that proof.

## Why it matters

`Pure` is the strongest purity claim: the function has no side
effects, so its output depends only on its inputs. This unlocks
memoization, parallelization, and compile-time evaluation (spec 01).
A purity violation means one of those guarantees is being asserted
without support — the compiler refuses rather than silently weaken
the row.

## Canonical fix

Three options, in order of preference:

- **Handle the effect inside the function body.** Wrap the offending
  call in `handle { … } with <handler>` — the handler absorbs the
  effect, and the body becomes Pure again.
- **Weaken the function's declared effects.** Remove `with Pure`, or
  declare the specific effect that's present (`with IO`,
  `with Alloc`). The call sites lose the purity-unlocked
  optimizations but the row tells the truth.
- **Use `!<Effect>` for selective purity.** If the function is pure
  *except* for one specific effect, say so: `with !Alloc` is weaker
  than `Pure` but still proves real-time safety.

## Example

```lux
fn double(x: Int) -> Int with Pure =
  perform log("doubling " ++ int_to_str(x))    // Log effect
  x * 2
// E_PurityViolated at line 2: expected Pure but found effects: Log
//   fix: install a log handler around the call, or drop `with Pure`
```
