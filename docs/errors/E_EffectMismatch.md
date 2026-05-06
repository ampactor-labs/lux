# E_EffectMismatch

**Kind:** Error
**Emitted by:** `effects.mn` (spec 01, `unify_row`)
**Applicability:** MachineApplicable

## Summary

Two function types were unified but their effect rows disagree.
Either the named sets of effects differ, or the same row variable
was constrained to two incompatible sets.

## Why it matters

Function type unification (spec 04) propagates effect constraints
across call sites. When two calls demand the same function with
different effect rows, one is wrong — either a caller is passing a
function that does more than the callee's signature admits, or a
signature under-declares what the body actually does. The algebra
catches the mismatch at the boundary, not at runtime.

## Canonical fix

- Compare the two rows named in the error. The missing (or extra)
  effect is the starting point.
- If a caller demands a narrower row (`with IO`) but the function
  does more (`with IO + Alloc`), either widen the caller's
  annotation or install a handler for `Alloc` before the call.
- If two callers demand incompatible rows, route them through
  different handlers — the compiler has proven they need different
  capability stacks.

## Example

```lux
fn run(task: fn() -> () with IO) = task()

fn work() with IO + Alloc = {
  perform log("working")
  perform alloc(256)
}

run(work)
// E_EffectMismatch at line 8: effect row mismatch: IO vs IO + Alloc
//   fix: widen `run`'s signature, or handle Alloc before the call
```
