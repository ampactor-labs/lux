# Handle 6 — Wildcard Audit

*Role-play as Mentl, tracing each wildcard against a hypothetical
new ADT variant. The walkthrough names what the substrate silently
absorbs today, what the explicit enumeration guarantees instead, and
which wildcards are CORRECT-BY-CONSTRUCTION (keep) versus
LATENT-BUG (transform).*

---

## Anchor

CLAUDE.md Session Zero red-flag:

> Writing `_ => <non-trivial-default>` in a match over a
> load-bearing ADT (Ty, NodeBody, LowExpr, EffRow, Reason). Safe
> `_` arms: `_ => ()`, `_ => 0`, `_ => reason` (identity preserve),
> `_ => type_mismatch(...)` (correct default for unrecognized
> pairs). Dangerous `_` arms: any that return a FABRICATED value.
> The dangerous form silently absorbs a new variant and emits
> wrong output; convert to explicit enumeration.

This walkthrough operationalizes the anchor.

---

## Load-bearing ADTs

Every ADT whose shape the substrate REASONS ABOUT structurally:

| ADT              | Where declared       | Why load-bearing                                |
|------------------|----------------------|------------------------------------------------|
| `Ty`             | types.mn             | Every type-directed decision reads its shape   |
| `NodeBody`       | types.mn             | AST walk discriminator; every pass matches     |
| `Stmt`           | types.mn             | Statement-level variants (FnStmt, LetStmt, …)  |
| `Expr`           | types.mn             | Expression-level variants (PipeExpr, VarRef, …)|
| `Pat`            | types.mn             | Pattern-level variants                          |
| `LowExpr`        | lower.mn             | LIR walk; every emit and analysis matches      |
| `EffRow`         | types.mn             | Effect algebra's shape discriminator           |
| `Reason`         | types.mn             | Why Engine rendering, graph reason-edge walk   |
| `PipeKind`       | types.mn             | Verb dispatch in infer/lower                   |
| `Annotation`     | mentl.mn             | Oracle candidate discriminator                 |
| `Resolution`     | types.mn             | Scope resolution discriminator                 |
| `NodeKind`       | types.mn             | Graph node kind (NFree, NBound, …)             |

Any `match x { … _ => Y }` where `x` is one of these and `Y` is a
fabricated non-identity value is a LATENT BUG at the point a new
variant ships.

---

## Simulation 1 — the fabricated-value trap

**Today, mentl.mn:424:**

```
fn extract_row(ty) = match ty {
  TFun(_, _, row) => row,
  _               => EfPure
}
```

*Trace (role-play as Mentl):*

> A new `Ty` variant ships — say `TLazy(Ty)` for thunked values,
> added to types.mn. It carries its own effect row because thunks
> can force effects at observation time. But `extract_row` matches
> `_ => EfPure` — so every `TLazy(...)` handle whose row was meant
> to be non-trivial now reads as `EfPure` in `teach_synthesize`'s
> candidate enumeration. Mentl proposes patches that type-check
> against a false `Pure` constraint. The oracle silently lies.

**Transformation:**

```
fn extract_row(ty) = match ty {
  TFun(_, _, row)   => row,
  TInt              => EfPure,
  TFloat            => EfPure,
  TString           => EfPure,
  TBool             => EfPure,
  TUnit             => EfPure,
  TVar(_)           => EfPure,
  TName(_, _)       => EfPure,
  TList(_)          => EfPure,
  TTuple(_)         => EfPure,
  TRecord(_)        => EfPure,
  TRecordOpen(_, _) => EfPure,
  TRefined(base, _) => extract_row(base),      // recurse — refinements carry base's row
  TCont(_, _)       => EfPure
}
```

**What closes:** every existing variant is explicit; any future
addition fails compilation with "pattern not exhaustive" until the
author decides whether `EfPure` is still correct or the new variant
needs a distinct extraction.

---

## Simulation 2 — the silent-identity trap

**Today, infer.mn:1145 (chase_deep):**

```
fn chase_deep(ty) = match ty {
  TVar(handle) =>
    let GNode(kind, _) = perform graph_chase(handle)
    match kind {
      NBound(inner) => chase_deep(inner),
      _             => ty
    },
  TList(inner)     => TList(chase_deep(inner)),
  TTuple(elems)    => TTuple(chase_deep_list(elems)),
  TFun(params, r, row) => TFun(chase_deep_params(params), chase_deep(r), row),
  TRefined(base, pred) => TRefined(chase_deep(base), pred),
  TCont(ret, disc) => TCont(chase_deep(ret), disc),
  _ => ty
}
```

*Trace:*

> A new `Ty` variant ships — `TVariant(String, List)` for sum-type
> instances. It carries a list of payload types that themselves
> may contain `TVar` handles awaiting chase. Today's `_ => ty`
> returns `TVariant` unchanged — the embedded `TVar`s inside the
> payload never chase. Inference "works" but every variant-value
> carries stale handles forever. The graph is inconsistent.

**Transformation:** enumerate every `Ty` variant. For each, decide
whether it has sub-types to recurse into (like `TList`, `TFun`) or
is a terminal scalar (`TInt`, `TBool`). `_ => ty` as identity is
always a HIDDEN DECISION — forcing the enumeration surfaces the
decision at variant-add time.

Same pattern applies to:
- `infer.mn:1157` (another chase variant)
- `infer.mn:1188` (free_in_ty)
- `infer.mn:1248` (subst_ty)
- `graph.mn:338` (occurs_in — most dangerous; missed occurs → infinite types)

---

## Simulation 3 — the stub-is-silence trap

**Today, infer.mn:518:**

```
fn infer_expr(node) =
  let N(body, span, handle) = node
  match body {
    NExpr(LitInt(_))    => perform graph_bind(handle, TInt, …),
    NExpr(VarRef(name)) => infer_var_ref(name, handle, span),
    NExpr(BinOpExpr(…)) => …,
    …
    NHole(_) => (),
    _ => ()
  }
```

*Trace:*

> A new `Expr` variant ships — `AsyncExpr(Node)` for suspended
> futures. Parser emits it. `infer_expr` matches `_ => ()`. The
> expression's handle stays `NFree` forever. Downstream: lookup_ty
> emits `E_UnresolvedType` at codegen — but the diagnostic points
> to the handle, not to the unhandled variant. The author chases
> the wrong trail.

**Transformation:** enumerate every `Expr` and `Stmt` variant
explicitly. For truly-no-op variants (e.g., `ExprPlaceholder`),
keep `=> ()` but name the variant; for `NHole`, keep `NHole(_) => ()`.
For unanticipated cases, emit `E_NotHandled` with the variant
name — a failure mode with coordinates, not silence.

Same pattern applies to:
- `infer.mn:1078` (infer_pat — new Pat variants silently ignored)
- `own.mn:355` (count_uses — new NExpr silently has zero uses of any name)
- `own.mn:281` (walk_return_positions — new NExpr silently doesn't return refs)
- `lower.mn:628` (cfv_expr — new NExpr silently captures nothing)
- `lower.mn:676` (lower_expr_body fallback — new Expr silently lowers to LConst(0))

---

## Simulation 4 — the LIR-backend trap

**Today, backends/wasm.mn:342 (and 619, 692):**

```
fn collect_fn_names_expr(expr, acc) = match expr {
  LMakeClosure(…) => …,
  LCall(…)        => …,
  …
  LBuildEvidence(…) => …,
  LEvPerform(…)     => …,
  LFieldLoad(…)     => …,
  _                 => acc
}
```

*Trace:*

> A new `LowExpr` variant ships — `LRegionDrop(Int)` for I12 full
> wiring. Lowering emits it at region exit. But the backend's
> `collect_fn_names_expr` matches `_ => acc` — any fn name inside
> the dropped region is INVISIBLE to the function-table builder.
> Result: fn_idx globals miss entries; call_indirect indices become
> wrong; WAT fails to validate with cryptic offset errors.

**Transformation:** the backend has 5 match sites on `LowExpr`
(collect_fn_names, collect_strings, emit_fns, emit_let_locals,
emit_expr). Every one must enumerate every LIR variant. A new
variant means 5 files/functions to extend — this is the
COST of explicit enumeration, but it's the cost PAID AT
COMPILE TIME rather than at runtime-trap time.

---

## Simulation 5 — the identity-preserve case (SAFE — keep)

**Today, graph.mn:265:**

```
fn merge_row(names, row) = match row {
  EfClosed(inner)  => mk_ef_closed(set_union(names, inner)),
  EfOpen(inner, v) => mk_ef_open(set_union(names, inner), v),
  _ => row
}
```

*Trace:*

> A new `EffRow` variant ships — say `EfIntersect(EffRow, EffRow)`
> (hypothetical; we already have `EfInter`). `merge_row(names,
> EfIntersect(a, b))` matches `_ => row` — returns `EfIntersect(a, b)`
> unchanged. The merge is deferred through the structure.

This is SAFE when the function's CONTRACT is "merge these names
into a row IF the row has a clear slot for them; otherwise leave
unchanged." The wildcard preserves structure; it doesn't fabricate.
The documentation of the contract matters — the wildcard should
carry a comment naming what "leave unchanged" means.

**Keep as-is, but add one-line comment:** `// EfNeg / EfInter / …
— no direct name-set to merge; structure preserved.`

---

## Inventory (complete)

*Every `_ => X` arm in std/compiler/, classified.*

### DANGEROUS (transform to explicit enumeration)

| File:line                    | Match subject | Current arm | Simulation of new variant | Priority |
|------------------------------|---------------|-------------|---------------------------|----------|
| mentl.mn:424                 | `Ty`          | `_ => EfPure` | New `Ty` → row silently Pure | HIGH |
| pipeline.mn:295              | `Ty`          | `_ => "Pure"` | New `Ty` → diagnostic says Pure | HIGH |
| infer.mn:1135                | `NodeKind`    | `_ => Forall([], TVar(handle))` | Fabricated scheme | HIGH (CLAUDE.md-named) |
| infer.mn:1145                | `Ty`          | `_ => ty` | New `Ty` with sub-types → stale handles | HIGH |
| infer.mn:1157                | `Ty`          | `_ => ty` | Same as above | HIGH |
| infer.mn:1188                | `Ty`          | `_ => []` | New `Ty` with TVars → missing free-var inference | HIGH |
| infer.mn:1248                | `Ty`          | `_ => ty` | New `Ty` subst-blind | HIGH |
| graph.mn:338                 | `Ty`          | `_ => false` | occurs_in misses new shape → infinite types | CRITICAL |
| infer.mn:518                 | `NodeBody`    | `_ => ()` | New `Expr` never inferred | HIGH |
| infer.mn:1078                | `Pat`         | `_ => ()` | New `Pat` silently unbinds | HIGH |
| own.mn:281                   | `NodeBody`    | `_ => ()` | New `Expr` can't escape-check | HIGH |
| own.mn:355                   | `NodeBody`    | `_ => 0`  | New `Expr` has zero own-uses | HIGH |
| lower.mn:362                 | `NodeBody`    | `_ => LConst(handle, LInt(0))` | New body-kind → integer zero emitted | HIGH |
| lower.mn:378                 | `Pat`         | `_ => lo` | New `Pat` doesn't bind name | MEDIUM |
| lower.mn:446                 | `Pat`         | `_ => ()` | New `Pat` unbound in cfv | MEDIUM |
| lower.mn:628                 | `Expr`        | `_ => []` | New `Expr` captures nothing | HIGH |
| lower.mn:635                 | `Stmt`        | `_ => []` | New `Stmt` captures nothing | HIGH |
| lower.mn:676                 | `Expr`        | `_ => { LConst(h, LInt(0)) }` | New `Expr` lowers to 0 | HIGH |
| lower.mn:718                 | `Pat`         | `_ => []` | New `Pat` binds nothing | MEDIUM |
| lower.mn:806                 | `NodeBody`    | `_ => acc` | New top-level stmt kind not indexed | MEDIUM |
| backends/wasm.mn:342         | `LowExpr`     | `_ => acc` | New `LowExpr` invisible to fn table | HIGH |
| backends/wasm.mn:359         | `LowExpr`     | `_ => ""`  | New top-level kind has no name | MEDIUM |
| backends/wasm.mn:512         | `LowExpr`     | `_ => 0` | New `LowExpr` doesn't count arity | HIGH |
| backends/wasm.mn:619         | `LowExpr`     | `_ => ()` | New `LowExpr` not emitted to fn table | HIGH |
| backends/wasm.mn:692         | `LowExpr`     | `_ => ()` | New `LowExpr` doesn't declare locals | HIGH |
| infer.mn:883                 | `Ty`          | `_ => false` | expect_same misses new primitive | MEDIUM |
| infer.mn:944                 | `Ty`          | `_ => arity_mismatch(...)` | Non-tuple type → arity error | BOUNDARY |

### SAFE (keep; add one-line comment naming contract)

| File:line                    | Match subject | Arm           | Contract                                           |
|------------------------------|---------------|---------------|----------------------------------------------------|
| graph.mn:235, 242, 244, 255  | `NodeKind`/`Ty`| `_ => chased` / `_ => GNode(kind, reason)` | Identity preserve — chase terminates on non-indirection |
| graph.mn:265                 | `EffRow`      | `_ => row`    | Merge has no slot for this row shape — structure preserved |
| effects.mn:131               | `EffRow`      | `_ => EfNeg(row)` | Default negation for non-algebraic rows |
| effects.mn:155,157,174,176,178 | `EffRow`    | `_ => EfInter(a, b)` | Deferred intersection — algebra can't simplify |
| effects.mn:269,275,282,292,294| `EffRow`     | `_ => false`  | Subsumption refuses to prove what isn't provable |
| effects.mn:332,346,368,370   | `EffRow`      | `_ => unify_row_canonical(normalize_row(...), ...)` | Re-enter via canonicalization |
| infer.mn:1425                | `Ty`          | `_ => []`     | Non-function types have no effect row names |
| infer.mn:1434                | `EffRow`      | `_ => []`     | Non-named rows have no names |
| infer.mn:1440                | `NodeKind`    | `_ => EfPure` | Unresolved row handle defaults to Pure for read |
| infer.mn:572, 639            | `GNode`       | `_ => ()`     | Non-NRowBound chase results: row isn't resolved yet |
| infer.mn:597                 | `NodeKind`    | `_ => { … }`  | Fallback branch for non-TFun op types — reports diagnostic |
| infer.mn:865, 883            | `Ty`          | `_ => type_mismatch(...)` | Explicit mismatch — the DOCUMENTED fallback |
| mentl.mn:142, 144            | `NodeKind`    | `_ => None`   | gradient_next returns None when handle isn't a fn |
| mentl.mn:209                 | `Ty`          | `_ => ()`     | narrow_row: only narrow TFun rows; no-op for others |
| mentl.mn:347                 | `Reason`      | `_ => reason` | why_expand identity-preserves leaves |
| mentl.mn:376                 | `NodeKind`    | `_ => resume(false)` | verify_after_apply: only NBound proves; else false |
| mentl.mn:418                 | (proven list) | `_ => None`   | No proven annotations → None |
| mentl.mn:465                 | String        | `_ => "Unknown error code: …"` | Explicit unknown — the DOCUMENTED fallback |
| own.mn:251                   | `Own`         | `_ => collect_ref_params_loop(...)` | Non-Ref ownership: skip in ref-param collection |
| own.mn:312                   | `Own`         | `_ => own`    | Preserve Own/Ref markers; only Inferred is reclassified |
| pipeline.mn:250, 284         | `NodeBody`    | `_ => []`     | Query iterator: only top-level FnStmts contribute |
| pipeline.mn:344, 348, 354, 356 | String      | `_ => QUnknown(q)` | Explicit unknown query variant |
| lower.mn:144                 | `Ty`          | `_ => true`   | monomorphic_at: non-function types are trivially monomorphic |
| lower.mn:319                 | `LowExpr`     | `_ => [LCall(...)]` | Single-branch `<\|` — treat as one LCall |
| lower.mn:340                 | `Ty`          | `_ => 0`      | Field offset lookup: non-record types → 0 |
| lower.mn:569                 | `NodeBody`    | `_ => []`     | cfv_node: NPat/NHole contribute no free vars |
| backends/wasm.mn:1071, 1083  | String        | `_ => { … }`  | Unknown binop/unaryop — diagnostic comment |

---

## Transformation strategy

1. **DANGEROUS arms first.** Every row in the DANGEROUS table transforms from `_ => X` to explicit enumeration. Where the default was correct for all current variants (e.g., `_ => EfPure` on every Ty), every variant gets an explicit `TVariant => EfPure` arm. Where the default was plausibly WRONG (e.g., `_ => ty` in `chase_deep` for a variant that might contain sub-TVars), each variant's arm is decided explicitly: recurse or return.

2. **Order of operations, per file:** start at the lowest-level ADT (Ty → EffRow → Reason → Pat → Expr → Stmt → NodeBody → LowExpr) and work up. A Ty-level fix reveals whether higher-level matches on types also need enumeration. Each fix commits; next fix lands on a more-coherent substrate.

3. **SAFE arms: add a one-line comment.** No structural change, but every kept wildcard carries its contract in the code. Future reviewers see "identity preserve — intentional" rather than wondering.

4. **Add a verification invariant.** At the end of H6, every wildcard in std/compiler/ either (a) has been enumerated or (b) carries a comment naming its contract. `grep -rn "_ =>"` across std/compiler/ returns only arms with contract comments — a greppable audit rule.

5. **Runtime files (std/runtime/)** are out of scope for H6 unless they have load-bearing ADT matches. Quick sweep confirms they don't — lists.mn and strings.mn operate on scalar structures.

---

## What closes when H6 is done

- Every `match` over a load-bearing ADT is exhaustive.
- A new Ty/Expr/Stmt/LowExpr/EffRow/Reason variant added tomorrow
  fails compilation until handled everywhere — the substrate
  forces the author to close every site before shipping.
- Every kept wildcard carries its contract in one line. Intent
  is visible at the match site.
- The CLAUDE.md red-flag rule becomes a greppable invariant, not a
  memory-discipline.

---

## What H6 reveals (expected surprise)

I expect closing H6 will reveal:

- **At least one fabricated-value arm in code I thought was safe.**
  Not every wildcard looks dangerous at a glance; tracing through
  the simulation on a hypothetical variant addition is what
  exposes them.

- **One or two design ambiguities** where "identity preserve"
  turns out to be the wrong contract. Example: `chase_deep`
  handling of `TVariant` — do we recurse into payload types or
  treat the variant as opaque? That's a DESIGN decision, not a
  mechanical one. H6 surfaces it before it hides as a bug.

- **Handler-level exhaustiveness.** Effect handlers (affine_ledger,
  infer_ctx, etc.) have arm lists — adding a new op to an effect
  requires every handler implementing that effect to extend. That
  isn't a wildcard match but the same principle — and there's no
  `match` to grep for. **This may surface a related handle we
  didn't name.**

If any of these surprises is bigger than expected, we pause and
discuss. Per γ's protocol: the walkthrough reveals, not the
implementation.

---

## Estimated scope

- **~18 DANGEROUS sites to transform** (mixed-file sweep).
- **~30 SAFE sites to annotate** with one-line contract comments.
- **Single commit** — H6 lands in one pass because each
  transformation is mechanical once the inventory is fixed.
- **Sub-handle** (possibly): if handler-arm exhaustiveness surfaces
  as an analogous problem, it becomes H6.1. Named before
  addressed, consistent with γ.
