# E_OwnershipViolation

**Kind:** Error
**Emitted by:** `own.ka` (affine_ledger handler, spec 07)
**Applicability:** varies (see below)

## Summary

An `own`-annotated binding was consumed twice, or a `ref`-annotated
parameter escaped its scope.

## Why it matters

`own` is affine: consumed exactly once. `ref` is scoped: cannot
escape through return, storage, or closure capture. Violating either
would invalidate the zero-cost drop/borrow story the compiler relies
on for codegen.

## Canonical fix

**Consumed-twice (MachineApplicable):** the second use is the bug.
Mentl points at both spans and suggests cloning at the first use if
both consumptions are intentional.

**Ref-escaped (MaybeIncorrect):** either change the parameter to
`own` (move ownership to the callee), or refactor to not return the
borrow. The fix depends on the caller's intent.

## Example

```lux
fn process(own buf: Buffer) -> () = {
  save(buf)       // consumes buf
  log(buf)        // E_OwnershipViolation: 'buf' consumed twice
                  //   first use at line 2
                  //   fix: log before save, or clone before save
}
```

```lux
fn get_ref(ref x: Int) -> Int = x
// E_OwnershipViolation at line 1: 'x' is a ref parameter that escapes through return
//   fix: change `ref x` to `own x`, or return a copy not the ref
```
