# Arc F.2: Span Indexing & `QTypeAt`
**Walkthrough ID:** F2-span-index
**Status:** `[LANDED 2026-04-22]`
**Scope:** Building the AST span index directly into the `Graph` substrate to unblock `QTypeAt` queries for Mentl.

---

## 1. The Realization: Mentl Solving Mentl

Mentl is the interactive soul of Mentl. It needs to know "what type is at the user's cursor?" to provide the signature gradient and hover feedback. 

Historically, this meant standing up a side-car LSP Language Server that maintained its own shadow AST and interval tree. 

Under the **"Mentl Solving Mentl"** ideal, this is a violation of Primitive #1: *The Graph IS the Program*. We do not build an external index; we project the existing graph. The index is merely a `GraphRead` capability over the universal `Graph` substrate.

## 2. The 8 Interrogations, Applied

We subjected the Span Index requirement to the eight interrogations:

1. **Graph?** Does the graph encode this? *Yes.* We extended the `Graph` ADT to hold `span_index: List<(ValidSpan, Int)>`.
2. **Handler?** What installed handler projects this? *The `graph_handler`.* It listens to `graph_index_span` writes and serves them via `graph_snapshot`.
3. **Verb?** Which verb draws this? The `~>` boundary instantiating `graph_handler`.
4. **Row?** What gates this? `GraphWrite` gates index building (during parse); `GraphRead` gates Mentl's querying.
5. **Ownership?** Mentl accesses the graph by `ref` (borrowed read-only).
6. **Refinement?** The span is guaranteed by `span: ValidSpan`. No invalid ranges ever enter the index.
7. **Gradient?** The index directly powers the Mentl context gradient (Arc F.2), answering `QTypeAt`.
8. **Reason?** It maps a `Span` directly to a TypeHandle `Int`, which in turn chases to the `Reason` DAG.

## 3. Execution Summary

1. **`types.mn`:** 
   - Expanded `Graph` to 5 elements (added `span_index`).
   - Added `graph_index_span(ValidSpan, Int)` to `GraphWrite`.
2. **`graph.mn`:**
   - Initialized `graph_handler` state with `span_index = []`.
   - Wrote the `graph_index_span` accumulator arm.
   - Piped `span_index` into `graph_snapshot`.
3. **`parser.mn`:**
   - Modified `fresh_ph(span: ValidSpan)` to natively emit `perform graph_index_span(span, handle)`.
4. **`query.mn`:**
   - Rewrote `QTypeAt(_span)` to take `graph_snapshot()`, fold over `span_index` via `find_tightest`, and chase the resolved handle.

Mentl is now fully contextualized to the cursor.
