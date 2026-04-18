# V_Pending

**Kind:** Info (not Error, not Warning)
**Emitted by:** `verify_ledger` handler (spec 06 `Verify`)
**Applicability:** informational

## Summary

A refinement obligation was recorded but not yet discharged. The
code compiles; the obligation is tracked.

## Why it matters

Phase 1 ships the verification substrate without the SMT solver.
Every `TRefined` unification performs `verify(...)`; the default
handler (`verify_ledger`) accumulates obligations rather than
silently accepting them. This is deliberate: **no stub accepts
refinements silently.** Obligations are first-class structural
debt, queryable via `inka query <file> "verification debt"`.

When Arc F.1 lands, the default handler swaps to `verify_smt` and
each pending obligation is discharged or promoted to
`E_RefinementRejected`. Source code does not change.

## What this tells you

- Your refinements ARE being tracked (not silently dropped).
- They will be checked when the solver ships in Arc F.1.
- You can see the full debt via `inka query … "verification debt"`.

## Canonical fix

None required in Phase 1. If you want early verification:

- Discharge manually with `assert` at the call site.
- Wait for F.1; code is forward-compatible.

## Example

```
V_Pending: 7 verification obligations pending
  line 12:  port: Port → 1 <= self <= 65535
  line 27:  index: Nat → self >= 0
  line 42:  name: NonEmpty → len(self) > 0
  ...
  run `inka query <file> "verification debt"` for the full list.
  solver lands in Arc F.1.
```
