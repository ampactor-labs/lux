# E_NotARecordType

**Kind:** Error
**Emitted by:** `infer.nx` — NamedRecordExpr (spec 04, record-update target check)
**Applicability:** MaybeIncorrect

## Summary

A named-record literal `Foo { … }` resolved `Foo` in the env, but
the binding's `SchemeKind` is not `RecordSchemeKind` — so `Foo` is
not a record type.

## Why it matters

The named-record syntax requires the type name to resolve to a
declared record schema (per H2.3 nominal-records substrate). When
`Foo` is a function scheme, a constructor scheme, an effect-op
scheme, or a capability bundle, the literal can't be checked
against a field shape — there are no fields.

## Canonical fix

- If `Foo` is a function or constructor and you meant to call it,
  use call syntax: `Foo(arg)` not `Foo { field: arg }`.
- If you intended a different type, check imports — `Foo` may
  shadow the record type from a closer scope.
- If the record type is missing, declare it: `type Foo = { … }`.

## Example

```lux
type Bar = { x: Int }
fn Foo(x: Int) -> Int = x

let bad = Foo { x: 1 }
// E_NotARecordType: 'Foo' is not a record type
//   reason: 'Foo' resolves to a function scheme, not a record
//   fix: write `Foo(1)` or define `type Foo = { … }`
```

## Related

- `E_RecordFieldExtra` — record literal has fields the type doesn't declare.
- `E_RecordFieldMissing` — record literal omits fields the type requires.
