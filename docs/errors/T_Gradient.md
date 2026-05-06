# T_Gradient

**Kind:** Teach (informational; gradient nudge)
**Emitted by:** Mentl's teach tentacle (spec 09 `teach_gradient`)
**Applicability:** informational

## Summary

Mentl identified an annotation that would unlock a compilation
capability on the current binding. This is the gradient made
visible — not nagging, not a warning, an invitation.

## Why it matters

The annotation gradient (DESIGN.md) says: write nothing, everything
infers; add annotations, each unlocks a specific capability. Mentl's
teach tentacle surfaces the highest-leverage next step. Over time,
code naturally evolves from loose prototype to verified production
— not through pressure, through visibility.

## Canonical fix

None required. `T_Gradient` is informational. If the capability
matters to you, add the annotation. If not, ignore — no accumulating
warnings, no escalation. Mentl emits at most one `T_Gradient` per
binding per compile, and only when `mentl teach` is active (silent in
normal compile).

## Example

```
T_Gradient at line 12: 'normalize' is Pure-capable
  adding `with Pure` would unlock:
    • memoization (same input → same output, guaranteed)
    • parallelization (no side effects)
    • compile-time evaluation (if inputs are known)
  current inferred effects: {} (empty — already Pure)
  add: `fn normalize(x: Float) -> Float with Pure = ...`
```

```
T_Gradient at line 30: 'process_audio' is !Alloc-capable
  adding `with !Alloc` would unlock:
    • real-time audio safety (no GC pauses)
    • GPU / kernel offload eligibility
  transitive call graph: no Alloc effect detected
```
