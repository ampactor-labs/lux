# 00 — SubstGraph: one live graph, all variables

**Purpose.** A single graph that holds every type and effect-row
variable the program produces and exposes a live, O(1) chase interface
to every downstream observer. One substrate, many readers.

**Research anchor.** Salsa 3.0 — flat-array storage with epoch +
persistent overlay. Astral `ty` Python checker (SYNTHESIS_CROSSWALK.md
Tier 1): 4.7ms recompile. Polonius 2026 alpha — lazy constraint
rewrite over subset + CFG; the shape we use for ownership edges.

---

## Data structure

```lux
type NodeKind
  = NBound(Ty)          // resolved — chase terminates here
  | NFree(Int)          // unresolved — epoch at allocation time
  | NRowBound(EffRow)
  | NRowFree(Int)
  | NErrorHole(Reason)  // terminal error — inference recorded a failure
                        // here (spec 04 Hazel pattern); lowering traps on
                        // this with WASM `unreachable`.

type GNode
  = GNode(NodeKind, Reason)  // every node carries its justification
                             // (G-prefix avoids collision with spec 03's AST Node)

type SubstGraph
  = SubstGraph(
      List,          // flat array: nodes indexed by handle
      Int,           // epoch counter (bumps on every bind)
      Int,           // next fresh handle
      List           // per-module overlays: [(module_name, List[handle])]
    )
```

**Invariant (load-bearing).** The handle IS the index into the flat
array. `chase` walks `NBound`/`NRowBound` links until terminal
(`NBound`, `NFree`, `NRowFree`, or `NErrorHole`); path compression on
read is optional (Salsa 3.0 skips it; we skip it too until profiling
proves otherwise). No side-tables. If you know a handle, you know its
node in one array read.

**Error-hole terminal semantics.** `NErrorHole(reason)` is a terminal
node whose presence means "inference observed a failure at this
handle and chose to continue." The reason carries the captured
failure (e.g., `UnifyFailed(a, b)`). Downstream passes tolerate it:
lowering (spec 05) emits WASM `unreachable`; query (spec 08) surfaces
the reason to the user; the build does not halt on a single error.
This is the Hazel marked-hole pattern — productive inference under
error.

---

## API

```lux
effect SubstGraphRead {
  graph_chase(Int) -> GNode                   @resume=OneShot
  graph_epoch() -> Int                        @resume=OneShot
  graph_reason_edge(Int, Int) -> Reason       @resume=OneShot
  graph_snapshot() -> SubstGraph              @resume=OneShot
}

effect SubstGraphWrite {
  graph_fresh_ty(Reason) -> Int               @resume=OneShot
  graph_fresh_row(Reason) -> Int              @resume=OneShot
  graph_bind(Int, Ty, Reason) -> ()           @resume=OneShot
  graph_bind_row(Int, EffRow, Reason) -> ()   @resume=OneShot
  graph_fork(String) -> ()                    @resume=OneShot
}
```

**Writer isolation is structural, not policy.** Inference declares
`with SubstGraphWrite + SubstGraphRead`. Lowering and query declare
`with SubstGraphRead` only. A `perform graph_bind` in lowering is a
missing-effect type error — caught by the checker at handler install,
never shipped to runtime. No preflight rule; the Boolean effect
algebra (spec 01) gates the invariant by construction.

- `graph_fresh_*` allocates a new handle, tags it `NFree(epoch)` /
  `NRowFree(epoch)`, returns the index.
- `graph_bind*` is the only write. Idempotent on an already-bound
  handle iff the new target unifies with the old; otherwise it emits
  a `Diagnostic` and refuses (NOT a silent patch).
- `graph_chase` is the only legal read. Never index the flat array
  directly from outside this module.

---

## Invariants enforced at the API boundary

1. **Chase terminates.** Cycle detection triggers `E_OccursCheck`, not
   an infinite loop. Before `graph_bind(h, ty, r)`, walk `ty` for free
   handles containing `h`; if any, emit and refuse.

2. **Epoch monotonic.** Epoch only grows. Downstream observers that
   cache observations (query, LSP later) key on `(handle, epoch)`.
   Bumping invalidates.

3. **Write-once semantics via unify.** A handle may be the target of
   at most one concrete bind. A second `graph_bind(h, _)` is a unify
   call, not a rebind — the new target must unify with the existing
   target.

4. **Live, not snapshot.** No consumer snapshots the graph and reasons
   from the copy. Consumers read via `chase` every time. O(1) per read
   makes repeated reads free.

---

## Fork / overlay semantics

Each module compiled produces an overlay — a list of handles allocated
during that module's compilation. When module B imports module A, B's
compilation sees A's overlay + base graph as a read-only layered view;
B's overlay is writable.

Mirrors Salsa's per-function overlay but at module granularity. Meta's
Pyrefly confirms module scope is sufficient for real codebases;
per-definition is Arc F future work if profiling warrants.

**Cross-module TVar resolution.** A handle allocated in module A and
referenced from module B is chased through A's overlay after B's. No
eager snapshot crosses the boundary; cross-module drift (the
`P2-C3` treadmill) is structurally impossible.

---

## What is NOT in the graph

- **Row bodies with concrete effect names.** `EfClosed(["IO", "Alloc"])`
  lives in the Ty/EffRow ADT, not as graph nodes. Only the row
  VARIABLE (the `EfOpen(_, handle)` handle) is a node.
- **Type constructor arguments.** `TList(TVar(42))` has one handle
  (42), not two. Shape is structural; only variables are nodes.
- **Reasons as separate entities.** Every node carries its Reason
  inline; Reasons are not reachable without first reaching their
  node.

---

## Default handler

The pipeline installs one `graph_default` handler at `compile`
entry. It threads a single mutable `SubstGraph` value through the
effect's state. Downstream passes (infer, lower, query) see the same
graph; the handler routes their perform calls to the same underlying
state.

**Writer isolation via effect row.** Inference is the only pass that
declares `with SubstGraphWrite`. Lowering and query have `with
SubstGraphRead` only. The invariant "one writer" is therefore
structural — a `perform graph_bind` in lowering fails type-check at
handler install (see the effect split above).

---

## Consumed by

- `02-ty.md` — `TVar(Int)` is a handle into this graph.
- `03-typed-ast.md` — every AST node carries a handle allocated here.
- `04-inference.md` — inference is the only writer.
- `05-lower.md` — `LookupTy` handler delegates to `graph_chase`.
- `06-effects-surface.md` — both `SubstGraphRead` and
  `SubstGraphWrite` listed in the inventory.
- `08-query.md` — every query walks the graph via chase + epoch.

---

## Rejected alternatives

- **Separate typegraph and rowgraph.** Doubles the fork/overlay
  machinery. One structure for all variables makes cross-kind
  constraints (an effect row containing a TVar) trivial.
- **Linked-list subst chains.** O(depth) per chase. Rejected: even
  shallow chains accumulate into measurable perf drift, and the
  flat-array model makes the chase amortized O(1).
- **Immutable graph + persistent functional updates.** Effect handlers
  already give us scoped state; rebuilding the graph per bind would
  cost more than the mutation.
- **Per-definition overlay granularity.** Overkill for current
  codebase sizes; revisit only if profiling shows module granularity
  bottlenecking incremental recompile.
