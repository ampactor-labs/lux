# E_PatternInexhaustive

**Kind:** Error
**Emitted by:** inference (match exhaustiveness check)
**Applicability:** MachineApplicable

## Summary

A `match` expression does not cover every constructor of the
scrutinee's ADT.

## Why it matters

An unhandled variant at runtime has no type — the match would need to
fabricate a value. Inka rejects this at compile time. Every ADT's
variants are known; exhaustiveness is decidable.

## Canonical fix

Mentl names the missing variant(s) and offers one of two patches:

1. Add explicit arms for each missing variant (preferred — makes
   intent visible).
2. Add a wildcard `_ => …` arm (only when the catch-all semantics
   are genuinely desired; otherwise this is silent fallback, which
   Inka's discipline discourages — anchor 2).

## Example

```lux
type Color = Red | Green | Blue

fn to_hex(c: Color) -> String = match c {
  Red => "#ff0000",
  Green => "#00ff00"
}
// E_PatternInexhaustive at line 3: missing variant: Blue
// fix: add `Blue => "#0000ff"` arm
```
