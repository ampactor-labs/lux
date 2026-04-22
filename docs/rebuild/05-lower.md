# 05 — Lower: LowIR from live graph observation

**Purpose.** Lower the typed AST (spec 03) to LowIR (WASM-shaped IR)
by reading types LIVE from the SubstGraph (spec 00). No cached types
in LowExpr nodes. No per-module subst snapshot. An unresolved handle
at lower time is a build failure, not a fallback.

**Kernel primitives implemented:** consumer of #1 (reads graph live)
and #8 (reads Reasons). Lowers #2 handlers to direct calls (>95%
monomorphic) — OneShot-typed arms become direct `call`,
MultiShot-typed arms become heap-captured continuations, Either
dynamic dispatch; #3 five verbs to control flow.

**Research anchor.** Koka generalized evidence passing (JFP 2022) +
Koka C backend (2024). When the graph proves a call's handler stack
is monomorphic, emit `call $h_foo` directly. Kills `val_concat` drift
at compile time, not runtime.

---

## The LookupTy effect

```lux
effect LookupTy {
  lookup_ty(Int) -> Ty    // handle → resolved type (via graph chase)
}
```

**Lowering declares `with SubstGraphRead + EnvRead + LookupTy + LowerCtx
+ …` (spec 06).** EnvRead is the peer of SubstGraphRead — global binding
lookups resolve through the same effect discipline, not through a
passed-in `env` argument. No pass threads env. Zero arguments between
passes carry inference state.

Default handler, installed once in `pipeline.compile`:

```lux
handler lookup_ty_graph with SubstGraphRead {
  lookup_ty(h) => {
    let GNode(kind, _) = perform graph_chase(h)
    match kind {
      NBound(t) => resume(t),
      NErrorHole(_) => resume(TName("ERROR_HOLE", [])),
      NFree(epoch) => {
        perform report("", "E_UnresolvedType", "UnresolvedType",
          "handle " ++ show(h) ++ " @epoch=" ++ show(epoch),
          Span(0, 0, 0, 0), "MaybeIncorrect")
        resume(TName("UNRESOLVED", []))    // sentinel — halts build
      },
      _ => panic("LookupTy on row-kind handle")
    }
  }
}
```

**Invariant.** After inference, every expression node's handle is
either `NBound` (well-typed) or `NErrorHole` (explicit failure from
spec 04). `NErrorHole` lowers to a WASM `unreachable` trap — the
build continues, the user sees a runtime trap if they hit that path,
but all other well-typed code compiles. `NFree` is a compiler-
internal bug (inference failed to populate); emits `E_UnresolvedType` and halts.
No silent fallback to TUnit. No `val_concat` reachable.

The `with SubstGraphRead` declaration is load-bearing: this handler
has read-only access to the graph by effect-row subsumption (spec 00).
An accidental `perform graph_bind` inside this handler would fail
type-check at handler install — no runtime policy needed.

---

## LowIR

A WASM-shaped IR. Every LowExpr variant carries the source node's
`TypeHandle` (Int), never a cached `Ty`. Type reads go through
`lookup_ty(h)`.

```lux
type LowExpr
  = LConst(Int, LowValue)      // handle, value
  | LLocal(Int, Int)           // handle, slot
  | LGlobal(Int, String)       // handle, name
  | LStore(Int, Int, LowExpr)  // handle, slot, value
  | LLet(Int, String, LowExpr)
  | LUpval(Int, Int)
  | LBinOp(Int, String, LowExpr, LowExpr)
  | LUnaryOp(Int, String, LowExpr)
  | LCall(Int, LowExpr, List)
  | LTailCall(Int, LowExpr, List)
  | LReturn(Int, LowExpr)
  | LMakeClosure(Int, LowFn, List)
  | LIf(Int, LowExpr, List, List)
  | LBlock(Int, List)
  | LMakeList(Int, List)
  | LMakeTuple(Int, List)
  | LMakeVariant(Int, String, List)
  | LIndex(Int, LowExpr, LowExpr, Bool)
  | LMatch(Int, LowExpr, List)
  | LLoop(Int, List)
  | LBreak(Int, LowExpr)
  | LSwitch(Int, LowExpr, List)
  | LSuspend(Int, Int, LowExpr, List)
  | LStateGet(Int, Int)
  | LStateSet(Int, Int, LowExpr)
  | LRegion(Int, List)
```

`lexpr_ty` is now a live query:

```lux
fn lexpr_ty(e) = match e {
  LConst(h, _) => perform lookup_ty(h),
  LLocal(h, _) => perform lookup_ty(h),
  LBinOp(h, _, _, _) => perform lookup_ty(h),
  // ... one arm per variant; all read the handle
}
```

No `_ => TUnit` wildcard fallback. If a new variant is added,
`lexpr_ty` must get a matching arm — type-checker exhaustiveness
enforces this by construction.

---

## Handler elimination

`classify_handler` classifies every handler body as TailResumptive,
Linear, or MultiShot based on its `resume` pattern. The classification
drives compilation strategy.

**Monomorphic dispatch.** When a perform's handler context is provably
monomorphic (the effect's handler chain is ground), lowering emits a
direct call to the handler body rather than indirect dispatch.

Graph check at each perform site:
- Walk the handle for the TFun carrying the perform's effect row.
- If the row is `EfClosed` and every effect name has a known handler
  in the current compilation context → emit direct `call $h_op`.
- If `EfOpen` (row variable unbound) → emit evidence-passing thunk.

In a self-hosted Inka compilation, >95% of call sites prove
monomorphic. The remaining 5% take the evidence-passing path through
a function-pointer FIELD on the closure record (H1's `LMakeClosure`;
CLAUDE.md's drift-mode-1 guard — no vtable). There is no runtime
type-test dispatcher; `val_concat` is unreachable in emitted code.

**HandlerTier derives from TCont.discipline.** `HandlerTier`
(TailResumptive / Linear / MultiShot) is lowering's
compilation-strategy classification. `TCont.discipline` (spec 02) is
the type-level contract: the continuation permits this many resumes.
The two never conflict — a TailResumptive body on a MultiShot
continuation is safe (resumes once, permitted). The inverse
(MultiShot body on a OneShot continuation) is a type error caught at
handler install. `classify_handler` reads `TCont.discipline` as its
ground truth and specializes downward; `TailResumptive` is a
refinement, never a widening.

---

## No subst threading

The lowering walk is clean over the typed AST — no `(subst,
lowered_ast, accum)` tuple threaded through recursive calls:

```lux
fn lower_expr(node) -> LowExpr = {
  let h = node.handle
  match node.body {
    NExpr(LitInt(v)) => LConst(h, LInt(v)),
    NExpr(BinOpExpr(op, l, r)) => {
      let lo_l = lower_expr(l)
      let lo_r = lower_expr(r)
      LBinOp(h, op, lo_l, lo_r)
    },
    NExpr(CallExpr(f, args)) => {
      let fn_ty = perform lookup_ty(f.handle)
      let lo_f = lower_expr(f)
      let lo_args = map(lower_expr, args)
      if monomorphic_at(node.handle) {
        LCall(h, lo_f, lo_args)
      } else {
        emit_evidence_thunk(h, lo_f, lo_args)
      }
    },
    // ... one arm per Expr variant
  }
}
```

The only "context" lowering needs — local slot assignments, closure
upvalue indices — comes from the `LowerCtx` effect (spec 06). No
graph writes, no rebinds, no snapshots.

---

## Invariants (enforced structurally)

1. **Read-only by effect-row subsumption.** Lowering declares
   `with SubstGraphRead` (not Write). Any `perform graph_bind` fails
   type-check at handler install. No runtime policy; the Boolean
   effect algebra (spec 01) gates the invariant by construction.

2. **Complete.** Every LowExpr whose handle chases to `NBound` has a
   ground type; handles that chase to `NErrorHole` lower to
   `unreachable`; `NFree` is a compiler-internal error (`E_UnresolvedType`). No
   silent TUnit fallback.

3. **No defaults.** No `_ => TUnit`. No wildcard arms without
   enumeration. Exhaustiveness is a checker concern — missing arms
   are type errors, not preflight shell-script errors.

---

## Emitter handoff

The emitter (`std/backend/wasm_emit.ka`) reads LowExpr handles the
same way:

```lux
let wasm_ty = ty_to_wasm(perform lookup_ty(expr.handle))
```

`ty_to_wasm` reads live through the handler chain, so a stale subst
cannot produce the wrong wasm type — there is no subst to be stale.

---

## What does not exist

By design, the following are unrepresentable:

- Per-module `subst` threading — the graph is handler-scoped.
- `_ => TUnit` fallback in `lexpr_ty` — every variant must have an
  arm; exhaustiveness is enforced.
- Polymorphic-dispatch match-arm fallback idioms — no `match _`
  without every variant enumerated.
- Runtime `val_concat` / `val_eq` type-test dispatchers — dispatch is
  resolved at compile time via monomorphic proof or evidence passing.

---

## Consumed by

- `std/backend/wasm_emit.ka` — reads LowExpr, emits WAT.
- `07-ownership.md` — ownership escape check operates on typed AST
  (clearer than on LowIR) but reads ownership via TFun's TParam list,
  resolved through `lookup_ty`.
- `08-query.md` — `type at L:C` query reads node handles at source
  positions.

---

## Rejected alternatives

- **Cache lookups locally per pass.** Premature. Salsa 3 proves
  flat-array + epoch is fast enough. No profiling shows we need it.
- **Bind UNRESOLVED to TInt as a fallback at lower time.** The exact
  mechanism that masked `val_concat` drift in v1. Refused.
- **Separate `low_ir_check` pass.** `LookupTy` handler IS the check.
  Every emit that passes through lookup_ty is validated in the same
  step.
- **Type-erased LowIR.** Tempting for smaller IR, but the emitter
  needs type info for `ty_to_wasm`. Keep handles; keep the live read.
