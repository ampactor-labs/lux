# 04 — Inference: HM + let-generalization, one walk

**Purpose.** A single walk over the AST, classic Hindley-Milner with
Damas-Milner let-generalization, that writes bindings directly into
the SubstGraph (spec 00) as it encounters them. Every expression
contributes bindings or binds a handle; every FnStmt generalizes.
Types, effects, and ownership all fall out of this one walk.

**Research anchors.**
- Salsa 3.0 — flat-array + epoch + overlay pattern (from spec 00).
- Polonius 2026 alpha — lazy constraint rewrite for refinement
  constraints not solved immediately.
- Abstracting Effect Systems ICFP 2024 — soundness template for
  inference against a Boolean effect algebra.
- Hazel POPL 2024 — total type error localization; inference stays
  productive under error.

---

## Three operations

```lux
fn infer_expr(node) -> ()        // walks node, binds node.handle
fn infer_stmt(stmt) -> ()        // walks stmt, binds contained nodes
fn generalize(fn_node) -> Scheme // quantifies free TVars at FnStmt
```

One pass. No separate "check" vs "infer" phases. Outputs are a typed
AST (handles populated in graph) and an updated Env. The subst does
not escape as a sidecar value — downstream passes read the SubstGraph
directly through `graph_chase`. There is no `(env, subst)` tuple
threaded between passes.

---

## Env + Scheme

```lux
type Scheme
  = Forall(List, Ty)   // quantified handles, body type

type Env
  = Env(List)         // [(name, Scheme, Reason)]
```

**Env is effect-mediated (spec 06: `EnvRead` + `EnvWrite`).** Peer
with the SubstGraph — both are ambient post-inference knowledge read
through effects, not threaded as arguments. Inference declares
`with EnvRead + EnvWrite + SubstGraphRead + SubstGraphWrite + …`;
lowering and query declare `with EnvRead + SubstGraphRead` only.
Writer isolation is structural (one writer per kind).

- `env_empty`, `env_with_source`, `env_with_primitives` — initial
  handler state the default `env_default` handler installs at compile
  entry.
- `env_extend(name, scheme, reason)` — performed via `EnvWrite`.
  Monomorphic bindings wrap as `Forall([], ty)`.
- `env_lookup(name) -> Option((Scheme, Reason))` — performed via
  `EnvRead`. Callers destructure
  `match perform env_lookup(n) { None => ..., Some((sch, r)) => ... }`.
- `env_scope_enter()` / `env_scope_exit()` — performed via `EnvWrite`.
  Block-scoped bindings added during inference are popped on exit.

No subst field in Env. The graph is the subst; the graph is external.
Env itself is external — both are read through the same effect
discipline. **Zero pass threads state as arguments.** That uniformity
is the reason issue 8 (query's ambient `env`) disappears: query reads
env the same way it reads the graph.

---

## What the walk produces

1. **Structural constraints.** `BinOpExpr("+", l, r)`:
   ```lux
   graph_bind(l.handle, TInt, OpConstraint("+", l_reason, Declared("int")))
   graph_bind(r.handle, TInt, OpConstraint("+", r_reason, Declared("int")))
   graph_bind(node.handle, TInt, OpConstraint("+", ...))
   ```

2. **Unifications.** `CallExpr(f, args)`:
   - Infer each arg (recursive).
   - Infer f.
   - Allocate fresh return handle, fresh row handle.
   - Build fn type: `TFun(arg_params, TVar(ret_h), EfOpen([], row_h))`
     where each `arg_param = TParam("_", TVar(arg.handle), Inferred)`.
   - Unify f's handle with the fn type.
   - Bind node.handle to `TVar(ret_h)`.

3. **Generalizations.** At a `FnStmt`:
   ```lux
   fn generalize(fn_node) = {
     let body_ty = chase_deep(perform lookup_ty(fn_node.handle))
     let body_free = free_handles(body_ty)
     let env_free = free_in_env()
     let quantified = set_diff(body_free, env_free)
     Forall(quantified, body_ty)
   }
   ```

4. **Instantiations.** At `VarRef(name)`:
   ```lux
   match perform env_lookup(name) {
     None => {
       perform report("", "E001", "MissingVariable", name,
                      node.span, "MaybeIncorrect")
       graph_bind(node.handle, NErrorHole(MissingVar(name)), ...)
     },
     Some((scheme, reason)) => {
       let ty = instantiate(scheme)
       graph_bind(node.handle, ty, VarLookup(name, reason))
     }
   }
   ```

`instantiate(Forall(qs, t))` walks `t`, substituting each quantified
handle with one minted via `perform mint(Instantiation(...))`. The
`FreshHandle` effect (spec 06) lets the same function serve both
inference (handler: `mint(r) => resume(perform graph_fresh_ty(r))`)
and query (handler: `mint(r) => resume(next_placeholder_id(r))`):

```lux
effect FreshHandle {
  mint(Reason) -> Int        @resume=OneShot
}
```

One function, two handlers. No `instantiate_for_display`.

---

## Unification

```lux
fn unify(h_a, h_b, reason) -> () = {
  let na = perform graph_chase(h_a)
  let nb = perform graph_chase(h_b)
  match (na.kind, nb.kind) {
    (NFree(_), _) => perform graph_bind(h_a, reify(h_b), reason),
    (_, NFree(_)) => perform graph_bind(h_b, reify(h_a), reason),
    (NBound(ta), NBound(tb)) => unify_shapes(ta, tb, reason),
    _ => { /* row-kind handles go through unify_row */ }
  }
}

fn unify_shapes(a, b, r) = match (a, b) {
  (TInt, TInt) => (),
  (TList(x), TList(y)) => unify_sub(x, y, ListElement(r)),
  (TFun(ps1, r1, e1), TFun(ps2, r2, e2)) => {
    unify_params(ps1, ps2, r)
    unify_sub(r1, r2, FnReturn("fn", r))
    unify_row(e1, e2, r)
  },
  (TRefined(a, p), TRefined(b, q)) => {
    unify_shapes(a, b, r)
    perform report("R", "Refinement", show_pred(PAnd(p, q)), ..., "MaybeIncorrect")
  },
  // ... one arm per ADT shape pair
  _ => perform report("E002", "TypeMismatch", show_mismatch(a, b), ..., "MachineApplicable")
}
```

Unification is entirely against the graph. No subst argument, because
the subst IS the graph.

---

## Row unification

Delegates to `unify_row` from spec 01. Rows live in the same graph as
types, so the graph-bind mechanics are identical.

---

## Ownership inference

Happens as part of this same walk — no separate ownership pass. At
every `VarRef`:
- If the referenced binding is an `own`-annotated parameter, emit
  `perform consume(name)` in the inferred effect row. The row handle
  gets a Consume name added.
- If `ref`, add the name to the ref-escape tracker threaded through
  the walk.
- FnStmt exits check the ref-escape tracker against return positions.

The structural escape check runs in this walk (see spec 07); affine
linearity is tracked by the `Consume` effect's handler
(`affine_ledger`), not by a separate pass.

---

## Occurs check

Via `graph_chase` cycle detection (spec 00). Before `graph_bind(h, ty,
r)`, walk ty for free handles containing h; if any, emit
`E_OccursCheck` and refuse. No silent binding, no infinite loop.

---

## Error handling (Hazel pattern)

Inference never halts on a type error. A mismatch:
1. Emits `perform report(..., code="E002", kind="TypeMismatch", ...)`.
2. Binds the handle to `NErrorHole(UnifyFailed(a, b))` — a terminal
   error node (spec 00 NodeKind variant). Lowering tolerates
   `NErrorHole` by emitting a WASM `unreachable` trap; query surfaces
   it as an error hole. Inference continues; downstream sees an
   error-typed node, not an unbound TVar.
3. Continues the walk.

The compiler stays productive under multiple errors — ten mismatches
produce ten error holes, not one-and-halt. IDE surfaces keep working.
`NErrorHole(Reason)` is a NodeKind variant owned by spec 00; this spec
uses it but does not extend the ADT.

---

## Monomorphism is a graph read, not a sidecar

At each CallExpr, lowering (spec 05) chooses direct-call vs evidence-
passing based on whether the callee's effect row is ground. No
sidecar map; the answer lives in the graph:

```lux
fn monomorphic_at(h: Int) -> Bool = match perform lookup_ty(h) {
  TFun(_, _, row) => row_is_ground(row),
  _ => true
}

fn row_is_ground(row: EffRow) -> Bool = match row {
  EfPure => true,
  EfClosed(_) => true,
  _ => false
}
```

In a self-hosted Inka compilation, >95% of call sites chase to a
ground row; the remaining 5% route through evidence-passing. The
`val_concat` class of bugs originated in v1 where this information
wasn't derivable from the graph; here it is a pure function of the
handle.

---

## Consumed by

- `05-lower.md` — lowering reads the post-inference graph via
  `lookup_ty`.
- `07-ownership.md` — ownership effect tracking runs inside this
  walk.
- `08-query.md` — query inspects (env, graph) produced here; the
  same `env_lookup` and `graph_chase` serve both.

---

## Rejected alternatives

- **Bidirectional type checking.** Inka's surface is HM-inferable;
  bidirectional adds annotation burden. Use HM + marked holes (spec
  03) for guidance where annotations help.
- **Two passes: prescan + infer.** Any prescan carries a snapshot
  that goes stale. Single walk + live graph avoids the snapshot
  problem by construction.
- **Constraint-collecting then batch-solve.** Over-engineered for HM.
  The graph IS the constraint store.
- **Separate effect inference pass.** Effects are in every TFun — you
  can't infer function types without inferring rows simultaneously.
  One walk.
