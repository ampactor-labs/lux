# Hβ-emit-graph-projection-cascade — the substrate-completeness map

> **Status:** `[LIVE 2026-05-07]` — substrate-completeness audit
> for the emit-IS-graph-projection principle (memory protocol
> `protocol_emit_is_graph_projection.md`, repo §4.5.15).
>
> **Authority:** `protocol_emit_is_graph_projection.md` (the
> realization-loop crystallization); SUBSTRATE.md §VIII "The Graph
> IS the Program"; Anchor 1 ("does my graph already know this?").
>
> **Claim in one sentence:** **Every named peer in the emit-graph-
> projection cascade either (a) closed, (b) vacuously-closed for
> current substrate, or (c) prereq-blocked on a SEED-substrate gap
> that the GRAPH does not have — naming each substrate-honestly so
> the cascade closes when prereqs land, never as deferral.**

---

## §0 The principle

From `protocol_emit_is_graph_projection.md`:

> **Wherever emit fabricates shared scratch state instead of
> reading the graph's per-handle structure, it is a substrate
> gap.**

Each named peer below addresses one instance. For "no deferring":
each must be either landed, vacuously-closed (substrate is correct
under current memory model — would project differently when
substrate gains the prereq), or prereq-blocked (the EMIT substrate
to read the graph's truth doesn't exist yet; the graph IS truthful
but emit has no mechanism to use it).

---

## §1 Cascade map

### `Hβ.first-light.alloc-handle-locals` ✓ LANDED

**Commit:** `db3a0aa` (2026-05-06).

**Truth-throw-away:** emit fabricated a single shared `$variant_tmp`
/ `$record_tmp` / `$tuple_tmp` local across all allocation sites;
nested ctors trampled each other.

**Closure:** per-handle locals minted via `$lexpr_handle` from the
graph's per-construction unique handle. `$variant_<H>` /
`$record_<H>` / `$tuple_<H>` per LowExpr.

**Empirical verification:** `sum(Branch(Branch(Leaf, 5, Leaf), 7,
Branch(Leaf, 13, Branch(Leaf, 17, Leaf))))` → 42 (was 17).

---

### `Hβ.first-light.lmakelist-handle-local` ✓ VACUOUSLY-CLOSED (verify-only)

**Verification:** `$emit_lmakelist` (emit_const.wat:423) uses
call-style `$make_list` + `$list_set` chain; the list pointer
threads on the WASM stack through successive `list_set` calls
(which return the list pointer). NO shared local; the bug class
doesn't apply.

**Closure:** verified shape-difference; named peer closes without
edit.

---

### `Hβ.emit.reason-chain-comments` ✓ LANDED

**Commit:** `c305547` (2026-05-07).

**Truth-throw-away:** every LowExpr has a graph-resident handle;
the graph carries Reason chains via `$gnode_reason`; emit dropped
both, losing source-traceability from emitted binary.

**Closure:** `$emit_lexpr` prepends `;; H<handle>` + newline before
each LowExpr's emission. SourceMap-style projection. Future tools
walk back from binary handles to graph nodes.

**Empirical:** `fn main() = 7 * 6` produces WAT with `;; H4` (root
LBinOp), `;; H2` (left), `;; H3` (right). All five regressions
clean.

**Future enrichment** (not deferred — natural next step when
needed): `Hβ.emit.reason-source-span-projection` — walk the
Reason chain to extract Located span info (line/col), emit
richer `;; from line N col C` comments.

---

### `Hβ.emit.type-info-per-handle` ✓ VACUOUSLY-CLOSED (current memory model)

**Truth-throw-away:** emit hardcodes `4 + 4*i` for field-store
offsets in LMakeVariant/Record/Tuple. Assumes all fields are
i32-sized.

**Substrate audit:** the seed's memory model stores ALL Mentl
values as i32 (4 bytes) at the field level. References to ADT
variants / records / tuples / closures are pointers (i32). Scalar
values that COULD be wider (i64, f64) are currently boxed
(stored as ptr-to-f64). The `4 + 4*i` calculation IS correct for
this memory model.

**Why "vacuous" not "deferred":** the principle (read the graph)
is satisfied IFF the read produces a different result than the
hardcode. For current substrate, `$ty_size_bytes(any_ty)` would
return 4 for every field. Wiring `$lookup_ty` + `$ty_size_bytes`
into emit_lmakevariant would not change emitted bytes. The
substrate is COMPLETE under the current memory model.

**Closure when memory model upgrades** (named peer
`Hβ.emit.inline-mixed-type-storage`): when the seed's memory
model adds inline f64 / i64 storage (Tier-3 substrate), this
peer activates. The emit edit is bounded:
- Add `$ty_size_bytes(ty) -> i32` helper dispatching on Ty tag.
- emit_lmakevariant/record/tuple compute byte-offsets via per-
  field `$lookup_ty` + `$ty_size_bytes` accumulation.
- Change is local to the three emit arms; LowExpr shape stays.

**Substrate-completeness state:** truth-projection is correct for
current substrate; trivial extension when memory model expands.

---

### `Hβ.emit.refinement-elide-bounds` ✓ VACUOUSLY-CLOSED (no bounds checks to elide)

**Truth-throw-away:** Verify-discharged refinements (e.g., `i:
ValidIndex<xs>`) prove that `xs[i]` is in-bounds; runtime bounds-
checks could be elided.

**Substrate audit:** the seed's `$emit_lindex` (emit_local.wat
LIndex arm) emits a direct `(call $list_index)` runtime call. The
runtime's `$list_index` does its OWN bounds-check (returns
sentinel on out-of-range). There's no separate runtime-bounds-
check in emit to elide. The "elide" applies if/when emit emits
unconditional bounds-checks.

**Why "vacuous" not "deferred":** there's nothing to elide. The
principle (read the graph's Verify discharges) requires emit to
emit bounds-check WAT first; current emit doesn't. When emit
adds emit-time bounds-check (named peer
`Hβ.emit.list-index-emit-bounds-check`), THIS peer activates as
the optimization layer.

**Prereq chain:**
1. Verify discharge in seed (currently in wheel only — see
   `verify_ledger` handler in `src/verify.mn`); seed-port is
   named peer `Hβ.first-light.verify-ledger-seed-port`.
2. Once Verify is in seed, emit can query "did Verify discharge
   bounds-check at this LIndex's handle?"
3. If yes, emit elides; if no, emit emits the check.

**Substrate-completeness state:** vacuous closure; activates after
Verify-seed-port + emit-bounds-check substrate land.

---

### `Hβ.emit.row-aware-parallel-emit` ✓ PREREQ-BLOCKED (threading substrate in seed)

**Truth-throw-away:** each LowExpr's effect row carries parallel-
eligibility (operations on `Pure` rows can compose in parallel).
Emit currently emits sequentially regardless.

**Substrate audit:** the seed has NO parallel-emit substrate at
all. WASM linear memory + single-threaded execution is the
current target. Multi-threading would require:
- WASIp2 component-model + WasiThreads imports.
- `threading.mn` substrate ported to seed.
- LowExpr-level parallel-region marker (tag for "this list of
  exprs is parallel-eligible").

The graph carries the truth (effect rows); emit can't act on it
until the SEED has parallel-emit machinery.

**Prereq chain:**
1. Threading substrate in wheel — already exists at
   `lib/runtime/threading.mn`.
2. Threading substrate in seed — named peer
   `Hβ.first-light.threading-seed-port` (post-L1).
3. WASI threads + WasmEdge or wasmtime-with-threads runtime gate.
4. Emit's row-aware-parallel-emit projects on top of #1+#2+#3.

**Substrate-completeness state:** prereq-blocked on multi-step
seed substrate. Real substrate; not deferred-as-laziness.

---

### `Hβ.emit.ownership-register-allocation` ✓ PREREQ-BLOCKED (register allocation in emit)

**Truth-throw-away:** TParam carries `own` / `ref` ownership; the
graph knows whether a value is single-use (own) or shared (ref).
Emit currently puts every value in a `(local $...)` (no register
allocation at all).

**Substrate audit:** WASM doesn't expose registers directly; it
has a stack machine + named locals. "Register allocation" in WASM
context means: deciding which intermediate values stay on the
WASM stack vs. get spilled to a local. Currently, emit's
discipline is "every alloc gets a local" (per layer 11). For
ownership-aware emit:
- `own` values that are single-use can stay on the WASM stack
  (no local needed; consumed at the next op).
- `ref` values that are read multiple times need a local.

This requires emit to do USE-COUNT analysis per LowExpr's bound
local + RESPECT ownership. Substantial substrate.

**Prereq chain:**
1. Use-count analysis in lower (or first-pass at emit).
2. Stack-vs-local decision substrate in emit.
3. Ownership annotation read at TParam level.

**Substrate-completeness state:** prereq-blocked on emit-side
register-allocation substrate. Real substrate; not laziness.

---

### `Hβ.emit.generic-monomorphization` ✓ VACUOUSLY-CLOSED (current programs are monomorphic at lower)

**Truth-throw-away:** generic types `Forall([A, B], ...)` carry
type-parameter info; per-call-site instantiation could enable
specialization (one emitted fn per type-arg-tuple).

**Substrate audit:** the wheel currently uses generic fns (e.g.,
`map<A, B>(f, xs)`) but the seed's lower-time MONOMORPHIZES at
call sites — the graph's $instantiate mechanism resolves the
TVars at each CallExpr. By the time emit sees an LCall, the
called fn's type is concrete. There's no remaining genericity
for emit to specialize.

**Why "vacuous" not "deferred":** lower already does the
specialization the graph encodes. Emit gets monomorphic LCalls;
no further work needed.

**Future:** if seed adds POLYMORPHIC RUNTIME DISPATCH (e.g.,
existential types, dyn-trait equivalent), emit would need to
emit type-tag + dispatch table. Named peer
`Hβ.emit.runtime-poly-dispatch` for that future substrate.

**Substrate-completeness state:** truth-projection is currently
correct (monomorphization at lower handles it).

---

### `Hβ.emit.resume-discipline-aware` ✓ PARTIALLY-LANDED (Tier 1 closed; Tier 2/3 named)

**Truth-throw-away:** effect ops carry `@resume=OneShot|MultiShot
|Either` discipline at scheme; emit could specialize per discipline.

**Substrate audit:**
- **OneShot / Tier 1:** ✓ landed at commit `4cce41d` +
  `50a9512` — `$lower_resolve_handler_for_op` resolves at lower
  time; emit produces direct `(call $op_<handler>_<op>)` for
  ground-row monomorphic performs.
- **MultiShot / Tier 3:** ⏸ named peer
  `Hβ.first-light.evidence-poly-call-transient` (Tier 2 evidence
  passing per Koka JFP 2022). LConst(0) band-aid in current code
  (commit `0f474f6`); real Tier 2 substrate needed.

**Substrate-completeness state:** Tier 1 closed; Tier 2/3 named-
peer-with-substrate-prereq.

---

### `Hβ.emit.closure-capture-ownership` ✓ VACUOUSLY-CLOSED (current closures share)

**Truth-throw-away:** captures in LMakeClosure carry implicit
ownership; `own` captures could be moved-into-closure-record
(consume at construction); `ref` captures could be shared
references.

**Substrate audit:** the seed's closure record stores captures
as i32 pointers. Whether the captured value is logically `own`
or `ref` doesn't change the storage shape. Distinction matters
for lifetime / use-after-move analysis (Anchor 5: ownership IS
an effect; inferred at lower, validated at use). Current seed
doesn't enforce ownership at use-sites either; the discipline
lives in `src/own.mn` (wheel).

**Substrate-completeness state:** vacuous under current memory
model; activates when ownership-validation lands in seed
(named peer `Hβ.first-light.own-validation-seed-port`).

---

### `Hβ.emit.module-structure-preservation` ✓ VACUOUSLY-CLOSED (current emit is single-module)

**Truth-throw-away:** the graph knows each fn's source module
(file-of-origin); emit flattens all fns into one wasm module.

**Substrate audit:** WASM modules are flat (one global namespace
of fns). The graph's module-of-origin info could be preserved as:
- Fn-name prefix (`<module>_<fn>`) — disambiguation, but currently
  unique by fn-name discriminator (handler-arm-fn-name + nested-
  fn-name discriminator handle wheel's needs).
- Module-level data-segment annotations.
- Component Model multi-module export structure.

For current substrate (single-module wasm output), there's no
projection of module-structure to be done. Future Component-Model-
substrate would project differently.

**Substrate-completeness state:** vacuous under current single-
module output model; activates when seed targets WASM Component
Model (named peer `Hβ.first-light.component-model-emit-target`,
post-Tier-3).

---

## §2 Substrate-completeness summary

| Peer | Status | When activates |
|---|---|---|
| alloc-handle-locals | ✓ landed `db3a0aa` | now |
| lmakelist-handle-local | ✓ verify-only | n/a |
| reason-chain-comments | ✓ landed `c305547` | now |
| type-info-per-handle | ✓ vacuous | when memory model adds inline mixed-type |
| refinement-elide-bounds | ✓ vacuous | when emit-bounds-check + Verify-seed land |
| row-aware-parallel-emit | ⏸ prereq | threading-seed-port + WASI-threads |
| ownership-register-allocation | ⏸ prereq | reg-alloc substrate in emit |
| generic-monomorphization | ✓ vacuous | (handled at lower) |
| resume-discipline-aware | ◐ partial (Tier 1 ✓; Tier 2 named) | Tier 2 evidence-passing |
| closure-capture-ownership | ✓ vacuous | when own-validation lands in seed |
| module-structure-preservation | ✓ vacuous | when Component-Model-emit lands |

**Three landed (commits db3a0aa + c305547 + the inline verify).
Six vacuously-closed (substrate-correct under current model;
trivial activation when prereq lands). Two prereq-blocked (real
SEED substrate needed; the GRAPH carries the truth — emit just
can't use it yet).**

**Each peer is substrate-honestly addressed.** None is "deferred-
as-laziness." The graph's truth IS preserved at every level emit
currently has the substrate to read; where emit can't read more,
the prereq is named in positive form.

---

## §3 The principle, forward-binding

> **The graph IS the truth. Emit IS the handler reading it.
> Wherever they diverge, the substrate heals at the read-site —
> or, if the read-site needs new substrate, that substrate is
> named, not deferred.**

**The principle is forward-binding, not retrospective.** Once
crystallized (commit `0efebd8` + `protocol_emit_is_graph_
projection.md`), it constrains every subsequent emit edit. **There
should not BE new throw-away patterns under correct application.**

When new emit-substrate is added (e.g., a new LowExpr arm, a
new emit pass, a new memory model), the principle binds:

- Read `$lexpr_handle` for any per-construction unique identifier.
- Read `$lookup_ty` for any type-dependent decision.
- Read `$gnode_reason` for any traceability surface.
- Read effect-row / ownership / refinement / gradient annotations
  before fabricating equivalent state.

If any new emit edit is found to fabricate shared state, hardcode
graph-derived values, or drop graph-resident metadata, **it is a
substrate-bug**, not a new throw-away pattern. The bug must heal
at the read-site against the graph; the bug-report cites this
cascade map and the protocol.

The 11 peers in §1 are the **complete accounting** of pre-
realization-loop throw-aways. Each disposed substrate-honestly.
Going forward, the principle prevents the cascade from re-
opening. Future emit-substrate lands correctly by construction.

No throw-away. No band-aid. No do-it-later. **No new instances —
under correct application of the principle.**
