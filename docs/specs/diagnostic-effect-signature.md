# Diagnostic Effect Signature

**Status:** Active (Arc 3 Phase 1 precondition for P1-C4..C8)
**Decides:** one effect with `kind` discriminant vs a family of effects

## The decision

**One effect, one op, `kind` as a String discriminant.** The current signature
(`std/compiler/ty.lux:20-22`) stays:

```lux
effect Diagnostic {
  report(source: String, kind: String, msg: String, line: Int, col: Int) -> ()
}
```

Phase 1 does NOT split `Diagnostic` into a family (`Diagnostic`, `Suggest`,
`Teach`, `OwnershipError`, …). Handlers dispatch on `kind` internally.

## Why one effect

**Cost of splitting later vs merging later — asymmetric.**

- If we split upfront and later want a single `ide_observer` handler to
  intercept everything, we need N handler definitions composing through
  inheritance, with per-handler plumbing. Aggregation is painful.
- If we merge upfront and later want a specialized `ContinuationEscapesArena`
  handler that only fires on one kind, we write `match kind { "ContinuationEscapesArena" => … ; _ => resume(()) }`. Specialization is cheap.

The 42 `println`/`print(` conversion sites in Phase 1 (P1-C4..C8) produce
call sites of the form `perform report(src, kind, msg, line, col)`. Merging
early means each site writes one string literal as `kind`; splitting means
each site imports and calls the right op. Merging is less churn.

## The `kind` strings

Callers pass well-known kind strings. No enum yet — string is sufficient
for Phase 1 (Arc 3 carries refinement types; `kind: String where ...`
can tighten this once that lands).

Reserved kinds (call sites standardize on these):

| `kind` | Emitted by | Phase 1 sites (approx) |
|--------|-----------|------------------------|
| `Error`                     | generic type/parse errors                       | many |
| `MissingVariable`           | `check.lux` / `infer.lux` on unknown identifier | few |
| `TypeMismatch`              | `infer.lux` unification failure                 | several |
| `PatternInexhaustive`       | `check.lux` exhaustiveness check                | few |
| `OwnershipError`            | `own.lux`, `check.lux` escape check             | Phase 3 |
| `Suggestion`                | `suggest.lux` Levenshtein candidates            | many (P1-C7) |
| `Refinement`                | `solver.lux` SMT failures                       | few |
| `Teach`                     | gradient / teaching output                      | varies |
| `ContinuationEscapesArena`  | Phase 3 ownership × arenas                      | Phase 3 |

New kinds must be documented here before their first call site.

## Handler composition (Item 6 preview)

Multiple handlers on one effect compose via the handler inheritance syntax:

```lux
handler ide_observer : print_diagnostics {
  report(src, kind, msg, line, col) => {
    perform emit_json(kind, msg, line, col)
    resume(())
  }
}
```

The child handler overrides the parent's `report` arm but inherits all other
ops. For a single-op effect this is equivalent to full replacement, but
the syntax scales uniformly when we add ops later (e.g., `suggest`, `teach`
as separate ops if string kinds prove too loose).

## What remains single-handler

`print_diagnostics` (pipeline.lux) is the sole installed handler through
Phase 1. It routes every `kind` to stderr via `eprint_string`, formatted as
`${kind}: ${msg}\n`. It ignores `src`, `line`, `col`. A richer pretty-printer
is out of scope for Phase 1.

## Migration rule for P1-C4..C8

**Every `println(x)` inside a checker module becomes:**

```lux
perform report(source, kind_string, x, line, col)
```

Where `source`, `line`, `col` come from the surrounding AST node (the check/
infer functions already thread these). If a site lacks that context, it
means the site is in non-checker code and should stay `println` (stdout
is the correct channel for non-diagnostic output).

**No site may:**
- Perform `println` inside a `report(...) =>` handler arm (would corrupt stdout
  under `print_diagnostics`). Enforced by a future preflight check.
- Invent a new `kind` string not in the table above. Document first, then use.

## Why not an enum type

Because Lux does not yet have stabilized ADT-in-effect-signature support
worth betting Phase 1 on. When Arc 3 Item 5 (DAG env) lands, the kind
enum can be refined into a sum type across modules without rewriting the
call sites — they'd change from passing a string literal to passing a
constructor, mechanical rewrite.
