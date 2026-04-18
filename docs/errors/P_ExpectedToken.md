# P_ExpectedToken

**Kind:** Error
**Emitted by:** parser (spec 03, `expect` helper)
**Applicability:** MaybeIncorrect

## Summary

The parser expected a specific token at this position and saw a
different one. This is the structured version: a concrete expected
vs. got pair. See `P_UnexpectedToken` for the open-ended variant
(the parser hit a token it cannot fit anywhere in the current
grammar state).

## Why it matters

Parse errors halt further parsing on the local construct, but Inka's
parser uses the `ParseError` effect's `unexpected` op to return a
Node holding `NHole` — parsing continues for the rest of the file.
You see every parse error in one compile, not one-at-a-time.

## Canonical fix

The error message names what was expected and what was seen. Common
cases:

- Missing semicolon / comma.
- Unclosed `{`, `(`, `[`.
- Mismatched `if` / `else` / `end` structure.
- Typo in a keyword.

Mentl's suggest tentacle runs edit-distance on keyword typos and
offers `W_Suggestion` patches when confident.

## Example

```
P_ExpectedToken at line 7 col 3
  expected: Eq
  got:      RBrace
  likely:   missing `()` body or stray closing brace
  fix:      add expression before closing brace
```
