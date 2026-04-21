# Error catalog

Canonical explanations for every error/warning/teach code the
compiler emits. Mentl's `teach_error` op (spec 09) resolves each
reserved code to its file here.

**Kernel grounding.** Errors are not punitive — they are Mentl's
voice catching the developer at the moment the graph noticed
something load-bearing. Every entry traces to one or more of the
eight kernel primitives (DESIGN.md §0.5): `E_OwnershipViolation`
to primitive #5 (tentacle Trace), `E_PurityViolated` /
`E_EffectMismatch` to #4 (Unlock), `E_RefinementRejected` /
`V_*` to #6 (Verify), `E_FeedbackNoContext` to #3 (Topology),
`E_PatternInexhaustive` / `E_OccursCheck` to #8 (Why / infer),
`T_*` to #7 (Teach). The structured-code + canonical-explanation +
applicability-tagged-fix format IS the projection of the gradient
(#7) — every `E_` has a canonical fix when mechanically derivable;
every `T_` is a gradient nudge; every `V_` is a pending proof
obligation.

**Naming.** Codes are strings of the form `<kind-prefix>_<Name>`.
No numbers; no renumbering; the code IS the name.

| Prefix | Kind | Emitted by |
|---|---|---|
| `E_` | Error — compile-time failure | inference, lowering, effects, ownership, clock replay |
| `V_` | Verification — refinement obligation | `verify_ledger`, `verify_smt` |
| `W_` | Warning — non-blocking, actionable | Mentl suggest tentacle |
| `T_` | Teach — informational gradient nudge | Mentl teach tentacle |
| `P_` | Parse — lexer/parser error | parser |

**File convention.** One file per code, named `<CODE>.md`. Structure:

```markdown
# <CODE>

**Kind:** Error | Warning | Teach | Info
**Emitted by:** <module / phase>
**Applicability:** MachineApplicable | MaybeIncorrect | informational

## Summary
One-line human-readable.

## Why it matters
What this tells you about the program.

## Canonical fix
The idiomatic correction. If MachineApplicable, the patch is exact.

## Example
Minimal code triggering it + the fix.
```

**Catalogued codes:**

| Code | Emitted by |
|---|---|
| [E_MissingVariable](E_MissingVariable.md) | `infer.ka` — VarRef handling |
| [E_TypeMismatch](E_TypeMismatch.md) | `infer.ka` — unify_types |
| [E_PatternInexhaustive](E_PatternInexhaustive.md) | `infer.ka` — match exhaustiveness |
| [E_OwnershipViolation](E_OwnershipViolation.md) | `own.ka` — affine_ledger |
| [E_OccursCheck](E_OccursCheck.md) | `graph.ka`, `infer.ka` — bind guard |
| [E_UnresolvedType](E_UnresolvedType.md) | `pipeline.ka` — lookup_ty_graph |
| [E_RefinementRejected](E_RefinementRejected.md) | `verify.ka` — Arc F.1 SMT |
| [E_FeedbackNoContext](E_FeedbackNoContext.md) | `infer.ka` — `<~` checking |
| [E_PurityViolated](E_PurityViolated.md) | `effects.ka` — unify_row |
| [E_EffectMismatch](E_EffectMismatch.md) | `effects.ka` — unify_row |
| [E_ReplayExhausted](E_ReplayExhausted.md) | `clock.ka` — replay handlers |
| [P_ExpectedToken](P_ExpectedToken.md) | `parser.ka` — `expect` helper |
| [P_UnexpectedToken](P_UnexpectedToken.md) | `parser.ka` — primary fallthrough |
| [V_Pending](V_Pending.md) | `verify.ka` — verify_ledger |
| [W_Suggestion](W_Suggestion.md) | Mentl suggest tentacle |
| [T_Gradient](T_Gradient.md) | Mentl teach tentacle |
| [T_ContinuationEscapes](T_ContinuationEscapes.md) | Arc F.4 scoped-arena × multi-shot |

New codes land here before their first call site. Every `perform
report(...)` names a code whose file exists.
