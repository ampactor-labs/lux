# E_TypeMismatch

**Kind:** Error
**Emitted by:** inference (spec 04, `unify_shapes`)
**Applicability:** MachineApplicable (when one side is a literal)

## Summary

Two type handles that must be equal cannot be unified.

## Why it matters

Every unification failure is the compiler telling you that two
expressions you tied together have incompatible shapes. The Reason
chain on the resulting `NErrorHole` shows exactly which two
expressions and why they were tied.

## Canonical fix

- Check the immediate expression: literal vs. expected type, return
  value vs. annotation.
- Walk the Reason chain (`mentl query "why NAME"`): the mismatch often
  surfaces upstream — a parameter annotation propagating through
  several call sites.
- If the types differ structurally (e.g., `TList(Int)` vs.
  `TList(String)`), the fix is at the element level, not the list.

## Example

```lux
fn double(x: Int) -> Int = x * 2

let result = double("hello")
// E_TypeMismatch at line 3: expected Int, got String
//   reason: parameter 'x' of 'double' declared Int
//           call site passes String literal
//   fix: pass an Int, or change 'double' parameter type
```
