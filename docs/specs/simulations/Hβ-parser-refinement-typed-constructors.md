# Hβ-parser-refinement-typed-constructors.md — TOTAL refinement-typed constructors

**Status:** Named cascade. Per PLAN-to-first-light.md §3 post-Tier-3.
Plan-doc.

## Context

Today: parser produces nullary + N-ary constructors per
`type T = A | B(X) | C(Y, Z)`. The kernel's refinement primitive
(#6) lets values carry predicates. This cascade extends type decls
to allow REFINEMENT-TYPED constructors:

```
type ValidSpan = Span(sl, sc, el, ec)
  where sl >= 1 && sc >= 1 && el >= sl && ec >= sc
```

Constructors become TOTAL — invariant-preserving by construction.
The compiler refuses to allocate `ValidSpan(0, 0, 0, 0)` at compile
time when the literal can be proven to fail the predicate.

Replacement target: `src/parser.nx` + `src/types.nx` ADT shapes
extend with predicate fields; `src/verify.nx` integrates at the
constructor site.

## Handles (positive form)

1. **Hβ.refined-ctors.parser-where-clause** — extend
   `parse_type_stmt` to accept `where <predicate>` after the
   constructor list.
2. **Hβ.refined-ctors.predicate-ast** — Predicate ADT (already
   stubbed at `Hβ.first-light.refine-predicate-parser`):
   PAnd/POr/PNot/PExpr (boolean expression as predicate).
3. **Hβ.refined-ctors.constructor-scheme-with-predicate** —
   ConstructorScheme gets an optional predicate field;
   instantiation includes the predicate in the resulting type.
4. **Hβ.refined-ctors.verify-at-construction** — every constructor
   call site emits a Verify obligation: "args satisfy predicate".
5. **Hβ.refined-ctors.compile-time-verify** — when args are
   compile-time literals, the verifier evaluates the predicate at
   compile time → reject obviously-bad calls + elide the runtime
   check.
6. **Hβ.refined-ctors.runtime-verify-fallback** — when args aren't
   compile-time literals, emit a runtime check; fallback handler
   raises `E_RefinementViolation`.
7. **Hβ.refined-ctors.smt-witness** — composes with
   `Hβ.verify.smt-witness` named follow-up; SMT-solved obligations
   become compile-time discharged.

## Acceptance

- Wheel-canonical refinement types like `ValidSpan` DO refuse
  obviously-invalid constructions at compile time.
- Runtime fallback fires only when predicates depend on runtime
  values.
- `inka edit`'s gradient narrows when a refinement is added —
  invalid ctors at the cursor become Mentl proposals.

## Dep ordering

1 → 2 → 3 → 4 → 5 → 6. 7 (SMT) is parallel; lands when SMT
substrate matures.

## Cross-cascade dependencies

- **Gates on:** Phase H + Tier 3 + `Hβ.first-light.refine-predicate-
  parser` (named follow-up at parser_decl.wat:62).
- **Composes with:** `Hβ-emit-refinement-typed-layout.md` (refined
  ctors enable layout sharing across variants); `verify_smt
  witness path → first-light-L2`.
- **Closes Anchor 6** more fully — refinement types are
  load-bearing at construction time, not just annotation.
