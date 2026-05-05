# Hβ-lower-graph-direct-IR.md — LowExpr-as-tree retires

**Status:** Named cascade. Per PLAN-to-first-light.md §3 post-Tier-3.
Plan-doc.

## Context

Today: `src/lower.nx` produces `LowExpr` records — a tree-shaped IR
mirroring the typed AST. The graph (per the kernel) is the
substitution; LowExpr-as-tree is a SECOND IR layer alongside the
graph. This cascade retires the tree IR: lower mutates the GRAPH
directly with low-level annotations. emit walks the graph; no
LowExpr tree.

Per Anchor 1 — the graph already knows. LowExpr is "patch the AST
with lower info"; restructuring puts the info in the graph.

Replacement target: `src/lower.nx` LowExpr ADT → graph annotations
+ Reasons. Emit walks graph nodes directly.

## Handles (positive form)

1. **Hβ.graph-direct.lowering-as-graph-annotation** — lower's job
   becomes: for each AST handle, set its NodeKind payload to a
   "lowered" representation (instead of constructing an LowExpr
   record).
2. **Hβ.graph-direct.emit-walks-graph** — emit walks AST nodes
   in topological order; reads each node's lowered annotation;
   emits target code.
3. **Hβ.graph-direct.lowir-deletion** — remove `LowExpr` ADT,
   `lexpr_make_*` helpers, `lower/lexpr.wat` chunk. Lower becomes
   pure graph annotation; emit's surface narrows.
4. **Hβ.graph-direct.reason-for-lowering** — each lower-time
   decision (closure cap, match-arm dispatch shape, etc.)
   leaves a Reason in the node's GNode reason chain.
5. **Hβ.graph-direct.fixpoint-validation** — wheel compiles
   itself with the new IR; output matches the LowExpr-tree-IR
   pipeline byte-for-byte.

## Acceptance

- `LowExpr` ADT no longer exists in `src/lower.nx` or
  `bootstrap/src/lower/lexpr.wat`.
- Compile-time memory drops (no second IR allocation).
- Reason chains carry richer trace data (lower's decisions are
  visible to Why Engine).
- Self-compile fixpoint holds.

## Dep ordering

1 (annotation discipline) → 2 (emit reads graph) — these can
develop in parallel using a "shadow" pipeline that produces both
LowExpr trees AND graph annotations to validate equivalence. Then
3 (deletion). 4 (Reason discipline) and 5 (fixpoint) close.

## Cross-cascade dependencies

- **Gates on:** Phase H + Tier 3 + `inka edit` working (so we can
  iteratively migrate without breaking).
- **Composes with:** `Hβ-bootstrap-seed-in-inka.md` — the seed-in-
  Inka rewrite is the natural moment to retire LowExpr (don't
  port the dead form).
- **Realizes Anchor 1 fully** — the graph already knows; lower
  decorates the same graph rather than minting a parallel IR.
