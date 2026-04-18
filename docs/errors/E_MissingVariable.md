# E_MissingVariable

**Kind:** Error
**Emitted by:** inference (spec 04, `VarRef` handling)
**Applicability:** MaybeIncorrect

## Summary

A name was referenced that isn't bound in any enclosing scope.

## Why it matters

Inference cannot produce a type for a reference with no binding.
Continuing would either fabricate a type (hiding the mistake) or halt
the build. Mentl binds the handle to `NErrorHole(MissingVar(name))`
and continues — the rest of the file still compiles, the hole traps
at runtime if ever reached.

## Canonical fix

- Check spelling. Mentl's suggest tentacle (`W_Suggestion`) runs
  Levenshtein over in-scope names and surfaces the closest match.
- Check imports. The name may live in a module you haven't imported.
- Check scope. A binding in an inner block is not visible at the
  outer scope.

## Example

```lux
fn greet(name: String) -> String =
  "Hello, " ++ nam    // <- typo

// E_MissingVariable at line 2: 'nam' not in scope
// suggestion (W_Suggestion): did you mean 'name'?
```
