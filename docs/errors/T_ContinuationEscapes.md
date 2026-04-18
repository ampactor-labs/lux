# T_ContinuationEscapes

**Kind:** Teach / Warning (hardens to Error when F.4 semantics finalize)
**Emitted by:** Arc F.4 handler (scoped arenas × multi-shot continuations)
**Applicability:** MaybeIncorrect

## Summary

A multi-shot continuation was captured inside a scoped-arena handler
body. Resuming it after arena reset would access freed memory unless
one of the three D.1 policies (Replay safe / Fork deny / Fork copy)
is applied.

## Why it matters

This is Inka's open research contribution (D.1 per PLAN.md). Affect
POPL 2025 gives the type machinery (one-shot vs. multi-shot at the
type level); spec 02's `TCont(ret, discipline)` carries it. Arc F.4
resolves the runtime semantics. Until then, Mentl surfaces
`T_ContinuationEscapes` to make the interaction visible.

## Canonical fix

Pick one of three policies at the handler declaration:

- **Replay safe** — `@replay` tag on the handler. Continuation is
  re-derived by replaying the effect trace. Valid only if body
  effects satisfy Affect's safe shape.
- **Fork deny** — `@no_fork` tag. Forking the continuation is a
  compile-time error. Simplest; applies to most cases.
- **Fork copy** — `@deep_copy` tag. Capture deep-copies arena-owned
  data into the caller's arena. Allocation cost, no semantic surprise.

## Example

```lux
handle transform(signal) with arena {
  @no_fork {
    filter(x) => resume(process(x))   // one-shot; can't fork
  }
}
```

When F.4 semantics lock, `T_ContinuationEscapes` hardens into an
error with the above three fixes shipped as machine-applicable
patches.
