# T_OverDeclared

**Kind:** Warning (teaching)
**Emitted by:** `infer.ka` (spec 04, FnStmt declared-effects check — spec I19)
**Applicability:** MachineApplicable

## Summary

A function declares a wider effect row than its body actually uses.
The declaration is accepted (subsumption holds), but the extra
declared effects reserve capabilities the body never exercises. The
tightest signature that body inference supports would unlock
additional compile-time capabilities (memoization for `Pure`,
real-time for `!Alloc`, sandbox for `!Network`, etc.).

## Why it matters

A `with E` declaration is an UPPER bound — "this function uses at
MOST these effects." When the body uses strictly fewer, the upper
bound is loose: callers pessimistically assume the wider row when
generating evidence vectors or picking dispatch strategies. Tighter
rows unlock more capabilities (the teaching gradient, per DESIGN
Ch 8). `T_OverDeclared` surfaces the gap so the author can tighten
the signature deliberately rather than leaving capabilities on the
floor.

## Canonical fix

- Narrow the declaration to match the body's inferred row. Examples:
  - `with IO + Alloc` but body only uses `IO` → `with IO`.
  - `with IO` but body is actually pure → `with Pure` (unlocks
    memoization, parallelization, compile-time evaluation).
  - `with !Alloc` already proved, but signature declared `with Pure`
    which is looser — tighten to `with Pure` if you can, or accept
    `with !Alloc` if realtime safety is the gradient you want.
- If the declared row is intentional (e.g., future-proofing a
  public API for callers that may pass in handlers with richer
  needs), dismiss the warning by explicitly routing a placeholder
  effect through the body.
- If the body USED to use the declared effect but no longer does,
  tightening is probably the right move — the declaration is legacy.

## Example

```lux
fn stringify(x: Int) with IO + Alloc = {
  int_to_str(x)
  // body row: just Alloc (int_to_str allocates the string buffer)
}

// T_OverDeclared at line 1: declares IO + Alloc but body only uses Alloc
//   fix: change `with IO + Alloc` to `with Alloc`
```

## Related

- `E_EffectMismatch` — emitted when body row is NOT ⊆ declared row
  (the opposite failure mode — body exceeds the declaration).
- `T_Gradient` — Mentl's proposer for annotations that would unlock
  a capability. After tightening per T_OverDeclared, Mentl may
  propose an even tighter annotation.
