# Hβ-emit-refinement-typed-layout.md — Refinement-typed field offsets

**Status:** Named cascade. Per PLAN-to-first-light.md §3 post-Tier-3.
Plan-doc.

## Context

Today: record fields have positional offsets (4*i bytes). Refinement
types let the compiler reason about field VALUES (`field >= 0`,
`field < other_field`, `field is non-empty list`). This cascade
extends emit to USE refinement constraints to optimize layout —
elide null checks, pack flags into bits, share representations,
compute offsets from refinement-derived gradients.

Replacement target: `src/backends/wasm.mn` emit_record_field_stores
extended with refinement-aware offset computation.

## Handles (positive form)

1. **Hβ.refined-layout.predicate-to-layout-hint** — for each field's
   refinement predicate, compute a "layout hint" (bit-packed; sign;
   range-encoded; null-elided; etc.).
2. **Hβ.refined-layout.bit-packed-bools** — `Bool` fields with
   `Either(true, false)` refinement pack into a single bit (8x
   savings on Bool-heavy records).
3. **Hβ.refined-layout.range-encoded-ints** — `Int @ x in 0..255`
   stores as i8 instead of i32.
4. **Hβ.refined-layout.null-elision** — `Maybe X` where the X is
   refined-non-null elides the Just/Nothing tag.
5. **Hβ.refined-layout.shared-representation** — sum types where
   ALL variants share a common prefix can share that storage; the
   verifier checks the variant tag determines the suffix shape.
6. **Hβ.refined-layout.field-offset-graph** — emit-time graph
   computes offsets per record-shape; LFieldLoad reads from the
   correct offset based on resolved refinement.
7. **Hβ.refined-layout.gradient-cash-out** — every refinement that
   was a runtime check at the seed becomes a compile-time layout
   choice via the gradient.

## Acceptance

- Bool-heavy records (8 Bools = 8 bytes today) pack to 1 byte.
- `Int @ 0..255` records use i8 storage; emit reads via i32.load8_u.
- Maybe types where the X is refined-non-null lose the tag word
  (one byte savings; faster access).
- `wasm-validate` accepts; runtime semantics preserved.
- Benchmark shows measurable size + speed improvements on
  refinement-heavy programs.

## Dep ordering

1 (predicate-to-hint) is the foundation. 2/3/4/5 are independent
optimizations on the same substrate. 6 (offset graph) composes
across all of them. 7 (gradient cash-out) is the meta-handle.

## Cross-cascade dependencies

- **Gates on:** Verify substrate matures (`Hβ.verify.predicate-ADT`
  named follow-up); refinement composition lands.
- **Composes with:** `Hβ-arena-region-inference.md` (region tags
  on refined values); `Hβ-parser-refinement-typed-constructors.md`
  (TOTAL ctors enable layout sharing).
- **The gradient's emit-time payoff** — refinement types now PAY
  OFF in compile-time layout decisions, not just runtime guards.
