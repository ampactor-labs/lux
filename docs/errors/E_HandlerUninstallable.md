# E_HandlerUninstallable

**Kind:** Error
**Emitted by:** `infer.ka` (spec 04, HandleExpr arm) and `pipeline.ka`
(handler-install subsumption check — spec I14/I16)
**Applicability:** MachineApplicable

## Summary

A `handle … with …` (or `~> handler`) site installs a handler whose
arms require effects that the enclosing function's declared row does
not admit. The install is illegal — if the arms can't run, the
handler can't be installed.

## Why it matters

A handler's arms execute in the enclosing context. Installing a
handler whose arms need `IO` inside a `with Pure` function silently
violates the purity declaration — except the algebra catches it at
the install site, before the effect leaks into the fn's accumulated
row. This diagnostic is strictly more precise than
`E_EffectMismatch` at function exit: it points to the handler-install
span (the source of the contradiction), not to the function
signature (the downstream witness).

## Canonical fix

- Either install the handler from a context that admits its arm's
  effects (e.g. promote the enclosing fn from `with Pure` to
  `with IO` if the arms legitimately need `IO`).
- Or install an *outer* handler for the arm's effects first, so
  they're absorbed before the inner handler's arms execute.
- Or restructure the arm body to avoid the effect (e.g. log via a
  pure accumulator rather than `perform io_print`).

## Example

```lux
handler mem_logger {
  alloc(n) => {
    perform io_print("alloc " |> str_concat(int_to_str(n)))
    resume(n)
  }
}

fn pure_op() with Pure = {
  handle {
    List.sort(items)
  } with mem_logger
  // E_HandlerUninstallable at the `handle` site:
  //   handler arms require effects not admitted by the enclosing
  //   declaration (IO ⊄ Pure)
  //   fix: widen `pure_op` to `with IO`, or rewrite mem_logger's
  //   alloc arm to not perform io_print.
}
```

## Related

- `E_EffectMismatch` — surfaces at fn exit when the handler-install
  check didn't fire (e.g. the fn had no declared row).
- `E_PurityViolated` — surfaces when a `with Pure` fn's body
  inferred any non-pure effect, regardless of how.
