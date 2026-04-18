# E010 — OccursCheck

**Kind:** Error
**Emitted by:** SubstGraph bind (spec 00 invariant 1)
**Applicability:** MaybeIncorrect

## Summary

Binding a TVar to a type that recursively contains the same TVar
would create an infinite type (`a ~ List(a)` etc.).

## Why it matters

Self-referential types have no finite representation and are almost
always a mistake — usually an accidental self-application, a
polymorphic recursion without an annotation, or a missing pattern
match unwrap. The graph refuses to close the cycle and surfaces it
as an error instead of looping forever.

## Canonical fix

- Check recent recursive calls — are you passing the result of `f(x)`
  back into `f`?
- Check pattern matches — did you forget to unwrap a variant?
- If genuinely recursive (e.g., `type Tree = Leaf | Node(Tree, Tree)`),
  the fix is to declare the recursive type nominally, not to let
  inference infer it structurally.

## Example

```lux
fn weird(x) = weird(weird(x))
// E010 at line 1: occurs check — inferred type would be infinite
//   chain: 'weird' returns T where T requires T as input
//   fix: add an explicit type annotation, or refactor
```
