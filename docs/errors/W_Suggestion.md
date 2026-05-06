# W_Suggestion

**Kind:** Warning (informational; does not halt build)
**Emitted by:** Mentl's suggest tentacle (spec 09)
**Applicability:** MachineApplicable when confidence is high

## Summary

Mentl found a probable fix for a nearby error (E-code) and is
suggesting it. Usually "did you mean NAME?" style — Levenshtein over
in-scope bindings, similar-type candidates, or type-directed synth.

## Why it matters

Lowers the teaching friction. Instead of "name not found," the
developer sees both the error AND the fix. Mentl suggests rather
than auto-applies — the developer stays in control.

## Canonical fix

Accept the suggestion (`mentl --apply-fix`) or edit to match. If the
suggestion is wrong, Mentl treats the rejection as a signal — later
versions will learn from corrections via the Suggest effect's
feedback loop.

## Example

```
E_MissingVariable at line 2: 'nam' not in scope
W_Suggestion: did you mean 'name'? (edit distance 1)
  fix (MachineApplicable): replace 'nam' with 'name' at line 2 col 15
```
