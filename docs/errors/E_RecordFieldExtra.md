# E_RecordFieldExtra

**Kind:** Error
**Emitted by:** `infer.nx` — `check_nominal_record_fields` (spec 04, record literal check)
**Applicability:** MaybeIncorrect

## Summary

A record literal includes a field name the declared type does not
contain.

## Why it matters

H2.3 nominal records have a fixed declared field set. A record
literal is checked against that set in lexicographic order; an
unmatched provided name is either a typo or a leftover field from
a refactor.

## Canonical fix

- If the field name is a typo, fix the spelling. The Reason chain
  shows the declared field set.
- If the field belongs in the type, add it to the declaration:
  `type Foo = { …, new_field: T }`.
- If the field is genuinely extra (e.g., copied from a sibling
  type), remove it from the literal.

## Example

```lux
type User = { name: String, age: Int }

let u = User { name: "a", age: 1, email: "x" }
// E_RecordFieldExtra: record literal has unknown field 'email' for type User
//   reason: User declares { name: String, age: Int }
//   fix: remove `email`, or add it to `type User = { …, email: String }`
```

## Related

- `E_RecordFieldMissing` — record literal omits a declared field.
- `E_NotARecordType` — the named type isn't a record at all.
