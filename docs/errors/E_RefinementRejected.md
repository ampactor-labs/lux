# E_RefinementRejected

**Kind:** Error
**Emitted by:** Arc F.1 `verify_smt` handler (spec 06 `Verify`)
**Applicability:** MaybeIncorrect

## Summary

A refinement predicate cannot be discharged against the actual value
flow. The SMT solver returned unsat for the obligation's satisfiability
(or sat for its negation) — the property does not hold on this path.

## Why it matters

Refinement types are compile-time proofs. `E200` is the compiler
saying "I tried to prove this property and found a concrete
counterexample." The code that's rejected would not uphold the
refinement at runtime.

## Canonical fix

Mentl surfaces the unsat core and the call chain. Three options:

- **Narrow the caller.** Add a refinement at the caller that implies
  the callee's requirement. `fn open(port: Int)` calling
  `bind(port: Port)` → refine `open` to take `Port` too.
- **Assert at the boundary.** If the value genuinely comes from
  external input, add `assert port > 0 && port < 65536` to discharge
  the obligation at that point. The assert is tracked in the
  verification dashboard.
- **Relax the refinement.** If the callee's precondition is too strict
  for the actual use, loosen it.

## Example

```
E_RefinementRejected at line 12
  predicate: 1 <= self && self <= 65535
  on: port argument to bind_tcp(port: Port)
  counterexample: port = 0 (from read_int on line 8)
  unsat core: read_int has no lower bound
  fix options:
    - assert port > 0 && port < 65536 before the call
    - refine read_int to return a Port
```
