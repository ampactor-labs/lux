# E_CannotNegateCapability

**Kind:** Error
**Emitted by:** `infer.nx` — `expand_capabilities` (spec 04 + spec 06, with-clause expansion)
**Applicability:** MachineApplicable

## Summary

A `with` clause attempted to negate a capability bundle (e.g.,
`with !Network`) where `Network` is a `CapabilityScheme(_)` — a
named bundle of multiple effects. Capability bundles cannot
appear under `!` because negation is per-effect, not per-bundle.

## Why it matters

Capability bundles (`type capability Network = IO + Alloc`, etc.)
are env-side aliases that expand at use-site to their constituent
effects. The Boolean effect-row algebra (spec 01) defines `!E` as
the per-effect negation that proves the row contains no `E` —
which is well-defined for atomic effects (`!Alloc`, `!IO`) and
ill-defined for a bundle (`!Network` could mean !IO ∧ !Alloc, or
!IO ∨ !Alloc, or some other reading). Inka picks neither — the
author writes the per-effect negation they mean.

## Canonical fix

- Replace `with !Bundle` with the explicit per-effect negation:
  `with !IO + !Alloc` (or whichever subset of `Bundle`'s effects
  the function genuinely refuses).
- If the bundle's full row is to be excluded, expand it manually
  in the `with` clause and negate each member.

## Example

```lux
type capability Network = IO + Alloc

fn pure_compute(x: Int) -> Int with !Network = x * 2
// E_CannotNegateCapability: cannot negate capability bundle Network
//   reason: Network expands to IO + Alloc; per-bundle negation undefined
//   fix: write `with !IO + !Alloc` to refuse both, or pick the subset
```

## Related

- `E_PurityViolated` — function declared Pure but body has effects.
- `E_EffectMismatch` — body's row not subsumed by declared row.
