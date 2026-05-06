# Mentl Capability Axis: Intent Preservation & Named Bundles
**Walkthrough ID:** MC-mentl-capability-axis
**Status:** `[LANDED 2026-04-22]`
**Scope:** Closing FV.1.α (Intent Preservation) and FV.1.δ (Named Capability Bundles), unifying the Boolean effect algebra with Mentl's interactive capability surfacing.

---

## 1. The Insight

The Mentl toolset empowers the IDE to read the Graph. However, the Type Inference phase (specifically `build_declared_row`) normalizes complex `with` declarations into Canonical Row Form. 
When a user declares `with !Mutate`, it normalizes to `EfNeg(Closed([Mutate]))`. If a user declares `capability RealTime = !Alloc + !IO`, it expands and normalizes to `EfNeg(Closed([Alloc, IO]))`. 
While this is mathematically pure for capability-security checking, it prevents Mentl from knowing *why* a function is restricted (was it a `RealTime` bundle, or explicitly authored as `!Alloc + !IO`?).

The fix is **Intent Preservation** natively wired into the graph substrate.

## 2. Intent Preservation (FV.1.α)

We augmented the `Graph` ADT with an `intent_index: [(Int, List)]` which maps AST Node Handles directly to their *authored* effect lists `List<(EffName, negated: Bool)>`.

During parsing (`parse_fn_stmt`), the moment an AST Node Handle is minted, the parser emits a `GraphWrite` operation:
```mentl
  let stmt_node = nstmt(FnStmt(name, params, ret_node, effs, body), start)
  let N(_, _, h) = stmt_node
  perform graph_index_intent(h, effs)
```

This perfectly aligns with Primitive #1 ("The Graph IS the Program"). The authored intent lives in the immutable Graph snapshot, queryable by Mentl via the new `QIntentOf(handle)` oracle without relying on brittle textual analysis or external caches.

## 3. Named Capability Bundles (FV.1.δ)

To elevate Boolean effects into composable guarantees, we introduced the `capability` keyword:
```mentl
capability RealTime = !Alloc + !IO + !Network
```

*   **Syntax:** Uses the same underlying `parse_effect_list` as function declarations.
*   **Environment:** Registers globally as `CapabilityScheme`.
*   **Inference Splicing:** When `build_declared_row` evaluates a function's capabilities, `expand_capabilities` resolves any references to `CapabilityScheme` and splices their authored `effs` directly into the stream prior to partitioning and normalization.

## 4. The 8 Interrogations, Applied

1. **Graph?** Stored globally in the new `intent_index` projection.
2. **Handler?** Handled directly by `graph_handler` via `graph_index_intent`.
3. **Verb?** Propagates implicitly down the `|>` data flow.
4. **Row?** Synthesizes correctly into `EfNeg` row forms.
5. **Ownership?** Connects `!Mutate` capability stances directly to `ref` parameters.
6. **Refinement?** N/A (Intent is orthogonal to refinements).
7. **Gradient?** Mentl can now precisely display "RealTime" in hover tooltips instead of raw decomposed rows.
8. **Reason?** Capability mismatches throw `E_CannotNegateCapability` for syntactic clarity.
