# 05 — Lower: LowIR from live graph observation

**Purpose.** Lower the typed AST (spec 03) to LowIR (WASM-shaped IR)
by reading types LIVE from the SubstGraph (spec 00). No cached types
in LowExpr nodes. No per-module subst snapshot. An unresolved handle
at lower time is a build failure, not a fallback.

**Supersedes.** `lower.lux` (1108 lines), `lower_ir.lux` (207 lines).
Target combined: ~900 lines.

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

Default handler, installed once in `pipeline.compile`:

```lux
handler lookup_ty_graph with SubstGraphRead {
  lookup_ty(h) => {
    let GNode(kind, _) = perform graph_chase(h)
    match kind {
      NBound(t) => resume(t),
      NErrorHole(_) => resume(TName("ERROR_HOLE", [])),
      NFree(epoch) => {
        perform report("", "E100", "UnresolvedType",
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
internal bug (inference failed to populate); emits `E100` and halts.
No silent fallback to TUnit. No `val_concat` reachable.

The `with SubstGraphRead` declaration is load-bearing: this handler
has read-only access to the graph by effect-row subsumption (spec 00).
An accidental `perform graph_bind` inside this handler would fail
type-check at handler install — no runtime policy needed.

---

## LowIR (from `lower_ir.lux:52-118`)

Retained verbatim structurally. The ONE change: the Ty field on each
LowExpr variant is removed; LowExpr carries the node's `TypeHandle`
(Int). Reads go through `lookup_ty(h)`.

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

The `_ => TUnit` fallback from v1 (`lower_ir.lux:117`) is DELETED. No
wildcard arm. If a new variant is added, `lexpr_ty` must get a
matching arm — type-checker exhaustiveness enforces this (no
preflight rule needed).

---

## Handler elimination

Classification via `classify_handler` from `lower_ir.lux:147-207` —
TailResumptive, Linear, MultiShot. The logic is retained unchanged.

**New behavior.** When a perform's handler context is provably
monomorphic (the effect's handler chain is ground), lowering emits a
direct call to the handler body rather than indirect dispatch.

Graph check at each perform site:
- Walk the handle for the TFun carrying the perform's effect row.
- If the row is `EfClosed` and every effect name has a known handler
  in the current compilation context → emit direct `call $h_op`.
- If `EfOpen` (row variable unbound) → emit evidence-passing thunk.

In a self-hosted Lux compilation, >95% of call sites prove
monomorphic. The remaining 5% take the evidence-passing path; they
no longer fall through to a runtime type-test dispatcher.
`val_concat` is unreachable in emitted code.

**HandlerTier derives from TCont.discipline.** `HandlerTier`
(TailResumptive / Linear / MultiShot, preserved from
`lower_ir.lux:142-145`) is lowering's compilation-strategy
classification. `TCont.discipline` (spec 02) is the type-level
contract: the continuation permits this many resumes. The two never
conflict — a TailResumptive body on a MultiShot continuation is safe
(resumes once, permitted). The inverse (MultiShot body on a OneShot
continuation) is a type error caught at handler install.
`classify_handler` reads `TCont.discipline` as its ground truth and
specializes downward; `TailResumptive` is a refinement, never a
widening.

---

## No subst threading

v1 lowering threaded `(subst, lowered_ast, accum)` through every
recursive call. DELETED. The lowering walk is clean over typed AST:

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
upvalue indices — comes from `LowerCtx` (`lower_ir.lux:15-21`), which
is preserved unchanged. No graph writes, no rebinds, no snapshots.

---

## Invariants (enforced structurally)

1. **Read-only by effect-row subsumption.** Lowering declares
   `with SubstGraphRead` (not Write). Any `perform graph_bind` fails
   type-check at handler install. No runtime policy; the Boolean
   effect algebra (spec 01) gates the invariant by construction.

2. **Complete.** Every LowExpr whose handle chases to `NBound` has a
   ground type; handles that chase to `NErrorHole` lower to
   `unreachable`; `NFree` is a compiler-internal error (E100). No
   silent TUnit fallback.

3. **No defaults.** No `_ => TUnit`. No wildcard arms without
   enumeration. Exhaustiveness is a checker concern — missing arms
   are type errors, not preflight shell-script errors.

---

## Emitter handoff

The emitter (`std/backend/wasm_emit.lux`, preserved) reads LowExpr
handles the same way:

```lux
let wasm_ty = ty_to_wasm(perform lookup_ty(expr.handle))
```

`ty_to_wasm` (`lower_ir.lux:121`) stays. It now reads live through
the handler chain, so a stale subst cannot produce the wrong wasm
type — because there's no subst to be stale.

---

## What's deleted

- Per-module `subst` threading in `pipeline.lux`'s lowering-facing
  tuple — gone, graph is handler-scoped.
- The `_ => TUnit` fallback in `lexpr_ty`.
- Polymorphic-dispatch match-arm fallback idioms (see feedback
  memory: "Silent polymorphic dispatch fallback"). No `match _`
  without every variant enumerated.
- The `val_concat` runtime function (`std/runtime/memory.lux`). Phase
  D's delete list.
- The `val_eq` runtime function. Same fate.

---

## Consumed by

- `std/backend/wasm_emit.lux` (preserved) — reads LowExpr, emits WAT.
- `std/compiler/lower_print.lux` (preserved) — pretty printer.
- `std/compiler/lowir_walk.lux` (preserved with minor handle-type
  adapt).
- `std/compiler/lower_closure.lux` (preserved) — closure conversion.
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
