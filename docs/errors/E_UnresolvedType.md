# E_UnresolvedType

**Kind:** Error (compiler-internal)
**Emitted by:** lower (spec 05, `lookup_ty_graph` handler)
**Applicability:** MaybeIncorrect

## Summary

Lowering encountered a TypeHandle that chases to `NFree` (unbound
TVar) in the SubstGraph — meaning inference completed but failed to
populate this handle.

## Why it matters

Every expression node must have a ground type by lower time. An
`NFree` at this stage is a compiler-internal bug: inference
missed a constraint, or a structural walk skipped a node. This is
NOT a type error in the user's code — it's a gap in the compiler.

## Canonical fix

- Run `inka query <file> "unresolved"` to list every such handle and
  the source position.
- Run `inka query <file> "subst trace for TVar(N)"` for the offending
  N. The trace shows which pass left the handle unbound.
- File as a compiler bug. User code is innocent.

## Example

```
E_UnresolvedType at line 42, col 7
  handle 142 @epoch=5
  trace: bound in infer_expr at BinOpExpr("+"), never closed
  this is a compiler bug; run:
    inka query <file> "subst trace for TVar(142)"
```
