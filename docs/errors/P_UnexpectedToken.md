# P_UnexpectedToken

**Kind:** Error
**Emitted by:** parser (spec 03, `parse_primary` fallthrough)
**Applicability:** MaybeIncorrect

## Summary

The parser hit a token that cannot begin any expression (or
statement) in the current grammar state. Unlike `P_ExpectedToken`
(which names a specific expected token), this means the parser had
no single expectation — the position could admit many shapes but
this token admits none of them.

## Why it matters

The parser uses the Hazel pattern (spec 03): instead of halting on
an unexpected token, it plants an `NHole` and keeps parsing. You
see every parse error in one compile, not one-at-a-time. The hole
traps at runtime if ever reached.

## Canonical fix

The error names the token that threw it. Common causes:

- Stray operator (`+`, `-`, `*`) at the start of an expression
  position where a unary prefix is not valid.
- Keyword used out of place (`else` without a preceding `if`).
- Misplaced closing delimiter (`)`, `]`, `}`) where the opener was
  already consumed earlier.

Mentl's suggest tentacle runs edit-distance on keyword typos and
offers `W_Suggestion` patches when confident.

## Example

```
P_UnexpectedToken at line 5 col 9
  unexpected token: `else`
  reason: no open `if` at this position
  likely: the matching `if` is nested too shallow, or was deleted
  fix:    restore the `if cond { … }` before this `else`
```
