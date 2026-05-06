# E_RecordFieldMissing

**Kind:** Error
**Emitted by:** `infer.mn` — `check_nominal_record_fields` (spec 04, record literal check)
**Applicability:** MaybeIncorrect

## Summary

A record literal omits a field the declared type requires.

## Why it matters

H2.3 nominal records require every declared field to be present
in the literal — there are no optional fields without explicit
`Option<T>` declaration. A missing field is either a forgotten
edit or a misunderstanding of the type's required shape.

## Canonical fix

- Add the missing field with an appropriate value. The Reason
  chain shows the declared field's expected type.
- If the field should be optional, change its declared type to
  `Option<T>` and provide `None` at the literal site.

## Example

```lux
type User = { name: String, age: Int }

let u = User { name: "a" }
// E_RecordFieldMissing: record literal missing field 'age' for type User
//   reason: User declares { name: String, age: Int }
//   fix: add `age: 0` (or any Int), or change `age: Int` to `age: Option<Int>`
```

## Related

- `E_RecordFieldExtra` — record literal includes an undeclared field.
- `E_NotARecordType` — the named type isn't a record at all.
