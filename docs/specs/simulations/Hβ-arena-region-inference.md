# Hβ-arena-region-inference.md — Tofte-Talpin region inference

**Status:** Named cascade. Per PLAN-to-first-light.md §3 post-Tier-3
+ ROADMAP Phase F.4 (scoped arenas as GC handler). Plan-doc.

## Context

Inka's memory model today: bump allocator, monotonic, never frees
(CLAUDE.md memory model). Traps at 16MB. GC is the named handler
substrate (Arc F.4). Tofte-Talpin region inference fits the kernel:
each handler scope IS a region; refinement types tag each value's
region; `own`/`ref` ownership composes with region lifetimes.

Replacement target: bump allocator → region-inference-driven
arena-pool. Each `~> handler` introduces a region; values
allocated within deallocate at scope exit. The compiler infers
which region each value belongs to via Tofte-Talpin's effect-row
discipline (regions ARE effects per the kernel).

## Handles (positive form)

1. **Hβ.region.region-as-effect** — formalize `Region(r)` as a
   first-class effect-row entry. Each handler scope adds a region
   to the row.
2. **Hβ.region.allocator-handler** — `Alloc` effect's default handler
   is per-region bump-arena; scope exit frees the arena.
3. **Hβ.region.region-inference-pass** — infer pass: walk fn bodies,
   propagate region constraints via unify; bind each allocation site
   to its enclosing region.
4. **Hβ.region.escape-analysis** — extend `H4.region-escape` (already
   landed) to use real region IDs from inference, not the seed's
   sentinel-Region tags.
5. **Hβ.region.refinement-region-tags** — refinement types carry
   region annotations; `value: ValidSpan @r` reads the region tag
   for liveness checking.
6. **Hβ.region.cross-region-borrow** — `ref X @r1 ~> r2` borrowing
   discipline; inference checks borrow lifetimes don't outlive the
   borrowed-from region.

## Acceptance

- `Alloc` handler can be swapped with a region-arena handler at any
  call site; per-region cleanup runs at handler scope exit.
- Inference produces `Region(N)` row entries on every value
  allocation; lower threads them to emit.
- Cross-region escape attempts produce `E_RegionEscape` diagnostic
  with region origin in the Reason chain.
- Memory pressure stays bounded by region size, not whole-program.

## Dep ordering

1 (region-as-effect) → 2 (allocator handler) → 3 (region inference)
→ 4 (escape analysis extension) → 5 (refinement integration) →
6 (cross-region borrow). Each composes on the prior.

## Cross-cascade dependencies

- **Gates on:** Phase H + Tier 3; full row substrate
  (Hβ.infer.row-normalize peer landed).
- **Composes with:** `Hβ-emit-refinement-typed-layout.md` (region
  tags as part of refined-layout).
- **Closes the F.4 named follow-up** (scoped arenas as GC handler).
