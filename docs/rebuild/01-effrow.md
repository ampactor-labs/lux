# 01 — EffRow: Boolean algebra over effect rows

**Purpose.** Lift the current ternary EffRow (`EfPure | EfClosed | EfOpen`
in `types.lux:30-33`) to a full Boolean algebra `+ - & !` with Pure as
identity, so that the gradient's four compilation gates (Pure, !IO,
!Alloc, !Network) and handler absorption (`body - handled`) fall out of
one mechanism.

**Research anchors.**
- Tang & Lindley POPL 2025 / 2026 — Modal Effect Types, `⟨E₁|E₂⟩(E) =
  E₂ + (E − E₁)`. Rows and capabilities both encodable.
- Flix Boolean Unification (OOPSLA 2024) — 7% compile overhead for
  full Boolean algebra. Mechanizes what DESIGN.md lines 418-429 claim.
- Abstracting Effect Systems ICFP 2024 — soundness proof template for
  a parameterized effect algebra.

---

## ADT (extends `types.lux:30-33`)

```lux
type EffRow
  = EfPure
  | EfClosed(List)               // sorted, deduped set of effect names
  | EfOpen(List, Int)            // known names + row-variable handle
  | EfNeg(EffRow)                // negation: any effect not in inner
  | EfSub(EffRow, EffRow)        // left minus right
  | EfInter(EffRow, EffRow)      // intersection
```

**Invariant.** After normalization, an EffRow is always in one of
three canonical forms: `EfPure`, `EfClosed(...)`, or `EfOpen(..., v)`.
`EfNeg / EfSub / EfInter` appear as intermediate forms during
construction but normalize before unification.

---

## Operators

Surface operators reduce to ADT constructors:
- `E + F` → `normalize(EfClosed(names_of(E) ∪ names_of(F)))` (or
  EfOpen if either side has a rowvar).
- `E - F` → `normalize(EfSub(E, F))`.
- `E & F` → `normalize(EfInter(E, F))`.
- `!E`   → `normalize(EfNeg(E))`.
- `Pure` → `EfPure`.

No syntax extensions needed in Phase A — these read as normal
function/constructor calls at the source level until Phase F revisits
operator ergonomics.

---

## Normal form

The normalization function produces one of:
1. `EfPure`
2. `EfClosed(sorted_unique(names))`
3. `EfOpen(sorted_unique(names), rowvar)`

Reductions:
- `EfNeg` reduces via De Morgan after the inner form normalizes.
- `EfSub(A, B) ≡ A & !B` — always expanded, never kept as sub.
- `EfInter(Closed(A), Closed(B))` = `Closed(A ∩ B)`.
- `EfInter(Closed(A), Open(B, v))` = `Closed(A ∩ B)` (the rowvar can
  contribute nothing to the intersection beyond what it shares).
- `EfInter(Open(A, v₁), Open(B, v₂))` = `Open(A ∩ B, v_fresh)` with
  `v_fresh` bound to the intersection of v₁ and v₂ at unification.

---

## Unification rules

One function: `unify_row(a, b, reason) -> ()`. Writes through
`graph_bind_row` (spec 00).

| LHS            | RHS            | Action                                               |
|----------------|----------------|------------------------------------------------------|
| Pure           | Pure           | ok                                                   |
| Pure           | Closed(∅)      | ok                                                   |
| Pure           | Closed(≠∅)     | emit `PurityViolated`                                |
| Pure           | Open(∅, v)     | `graph_bind_row(v, EfPure, reason)`                  |
| Pure           | Open(≠∅, _)    | emit `PurityViolated`                                |
| Closed(A)      | Closed(B)      | ok iff A = B (as sets)                               |
| Closed(A)      | Open(B, v)     | `graph_bind_row(v, Closed(A − B), reason)`           |
| Open(A, v₁)    | Open(B, v₂)    | if v₁=v₂: unify A/B as sets; else bind v₁→Open(B−A, v₂) |
| Neg / Sub / Inter | any          | normalize LHS first, then re-dispatch                |

Effect-row variable handles live in the same SubstGraph as type
variables (spec 00). Unification writes through the same
`graph_bind_*` ops.

---

## Subsumption

A handler signature `effect E { op(...) -> T with F }` admits a body
of inferred row `B` iff `B ⊆ F`. Decidable on the normal form:

- `B ⊆ Pure` iff `B = Pure`.
- `B ⊆ Closed(F)` iff `names(B) ⊆ F` AND `B` has no rowvar.
- `B ⊆ Open(F, v)` iff `names(B) ⊆ F ∪ names_of(chase(v))`.

This is what gates the four compilation passes below.

---

## The four compilation gates (derived, not added)

Each is a subsumption test against a fixed row:
- **Pure → memoize / parallelize / compile-time eval.** `effs ⊆ Pure`.
- **!IO → safe for compile-time.** `effs ⊆ !Closed(["IO"])`.
- **!Alloc → real-time / GPU / kernel.** `effs ⊆ !Closed(["Alloc"])`.
- **!Network → sandbox.** `effs ⊆ !Closed(["Network"])`.

No per-gate bit-flag tracking. No intrinsic knowledge in the compiler
about which effect names mean what. The gates are subsumption queries
applied at codegen.

---

## Handler absorption

`handle { body with E } { arms for F }` has effects
`normalize(EfSub(E, F) + extra_arms)`.

Algebra applied at handler elimination:
- Body's inferred row = E.
- Handler's absorbed row = F (set of effects the handler's arms
  cover).
- Handler arms themselves perform an extra row (e.g., a Diagnostic
  arm performs `Diagnostic`).
- Result row = normalize of `(E - F) + extra`.

---

## What's preserved from `eff.lux`

The file already implements the `EfPure | EfClosed | EfOpen` core and
the 3×3 unification matrix. The rebuild keeps:
- `merge_effects` logic — becomes the `+` operator's reduction.
- `list_union / list_contains / list_subset / list_diff` (lines 30–
  183) verbatim. These become methods on normalized row names.
- `check_effect_constraints / apply_negations` (lines 194–275) — their
  logic folds into `normalize(EfSub / EfNeg)`.

The rebuild adds:
- `EfNeg`, `EfSub`, `EfInter` ADT variants.
- `normalize(row) -> row` function.
- Unification writes to graph instead of to an `esubst` list.

---

## Consumed by

- `02-ty.md` — `TFun(params, ret, EffRow)` carries this.
- `04-inference.md` — TFun unification calls `unify_row`.
- `05-lower.md` — handler elimination reads normalized rows to decide
  direct-call vs evidence-passing.
- `06-effects-surface.md` — every effect op decl uses this algebra.
- `07-ownership.md` — `!Consume`, `!Alloc` are rows in this algebra.

---

## Rejected alternatives

- **Capabilities as the primary mechanism.** Koka/Effekt schism.
  Modal Effect Types resolves by encoding both. Lux presents rows at
  the surface; capabilities fall out as a view.
- **Scala 3 `^` capture syntax.** Parallel mechanism to rows.
  Fractures the one-mechanism thesis. Rejected.
- **Quantitative effect counts (`!Alloc[≤ f(n)]`).** Out of scope
  Phase A–E. Listed in Arc F.1 as an open research question.
- **Effect presence bit-vectors instead of names.** Fails at module
  boundaries — bit indexes aren't stable across modules. Names are.
