# Handle 1 — Evidence Reification (Full Wiring)

*Role-play as Mentl, tracing a polymorphic function `my_op` that
performs `alloc`, called inside a `handle { ... } with mem_bump`
scope. Names every substrate piece that must come together: how
inference synthesizes the evidence shape, how the closure record
grows to hold evidence slots, how `perform` dispatches through
the slot, and — importantly — whether the Phase D-prepped
LBuildEvidence stays or dissolves into LMakeClosure.*

---

## The scenario

```
fn my_op() = perform alloc(1)

fn main() = handle {
  my_op()
  my_op()
} with mem_bump
```

`my_op` is polymorphic over the `Alloc` effect — its body performs
alloc but doesn't install a handler for it. The caller must
PROVIDE evidence (which handler arm to dispatch to) when invoking
my_op. Two separate invocations inside the `handle` share the
same evidence.

What has to work? Trace each layer.

---

## Layer 1 — Inference: evidence shape synthesis

### Current state

After Phase C's handler_stack extension, inference tracks which
handler names are installed at any point. The accumulated effect
row knows what's been performed. What's MISSING: the per-fn
"evidence shape" — the ordered list of effect ops this fn needs
evidence for when called.

### The synthesis

For each FnStmt (and LambdaExpr):

```
let body_row       = accumulated effect row of the body
let handled_by_self = union of effects handled by body's HandleExpr scopes
let ev_shape       = sort(body_row \ handled_by_self)
                     as [(op_name, slot_idx)] pairs
```

`body_row \ handled_by_self` = the effects the body performs BUT
doesn't absorb itself. These need to be provided by the caller —
the fn's evidence.

`sort` by op_name gives a stable slot assignment. Slot 0 is the
alphabetically-first op, slot 1 is next, etc. Consistency
across caller and callee is by shared alphabetical order.

### Where this lives

A new per-fn piece of metadata: `ev_shape: List[(String, Int)]`.
Stored where? Two candidates:

**Candidate α — on the Scheme itself.**
`Forall(vars, TFun(params, ret, row, ev_shape))` — extend TFun.

**Candidate β — in env alongside Scheme.**
env entry becomes `(name, Scheme, Reason, SchemeKind, ev_shape)`.

**Candidate γ — derived from the row at every use.**
ev_shape = sort(row names). No storage; recompute on demand.

γ is cleanest IF row is always resolved by the time we need
ev_shape. For monomorphic functions with fully-ground rows, this
is true. For polymorphic functions (row variable not yet bound),
it might not be. But in a finalized program (post-inference),
every fn's row IS bound — it's ground after the row-binding pass.

**Mentl's choice: γ.** Derive from the fn's ground row at lower
time. Zero new state; the graph already knows.

Caveat: the FUNCTION VALUE (what's in env as the scheme) has a
fully-bound row. If the row is still open (TVar), the function
isn't finalized for dispatch yet. That's a separate error
condition — `E_UnresolvedRow` or similar.

---

## Layer 2 — Lowering: LMakeClosure grows evidence

### The Phase D substrate-prep assumed LBuildEvidence

Phase D landed `LBuildEvidence(Int, LowExpr, List)` as a distinct
LIR variant. The intent: at HandleExpr, the body is wrapped in
LBuildEvidence with the handler's arms as the evidence list.

**This turns out to NOT be the right abstraction.** Trace:

> LBuildEvidence as a SCOPE construct would need to allocate a
> NEW __state record dominating its body. But __state is the
> calling convention's implicit first param — every function
> reads from its OWN __state, not from a scope's __state. A
> scope-level evidence record is orthogonal to the calling
> convention; it can't replace __state.
>
> The alternative — LBuildEvidence allocates a transient wrapper
> and rebinds __state to it — is correct but then LBuildEvidence
> is DOING LMakeClosure's job. Two LIR variants for the same
> thing.

**Design surpass (surfaced for approval):** delete LBuildEvidence.
Grow LMakeClosure's signature.

```
Before (Phase D):
  | LMakeClosure(Int, LowFn, List)            // handle, fn, captures
  | LBuildEvidence(Int, LowExpr, List)        // handle, body, ev_slots

After (proposed):
  | LMakeClosure(Int, LowFn, List, List)      // handle, fn, captures, ev_slots
  // LBuildEvidence deleted
```

The closure record at runtime: `[fn_ptr, capture_count, captures..., ev_slots...]`.
Captures at offset 8 + 4*i; ev_slots at offset 8 + 4*capture_count + 4*j.
Size = 8 + 4 * (capture_count + ev_count).

**This is the "handler IS state" thesis in its ULTIMATE FORM.**
A closure IS its frozen handler state. Captures and evidence are
the same KIND of slot — they're both "data the calling
convention provides to the body." Separating them into two LIR
variants was a drift from the unification DESIGN Ch 4 names.

**Reason this surpasses Phase D cleanly:** Phase D's plan said
"header grows from 8 to 12 bytes" OR "ev_count field added."
Landing LMakeClosure with ev_slots instead lets ev_count be
computed from the LowFn's metadata at emit time (its ev_shape is
derivable from the row). No header change. Tighter.

**Awaiting approval:** if γ's approach and this LMakeClosure
growth are approved, Phase D's LBuildEvidence variant is
removed in the same cascade.

### Lower's translation rules

**FnStmt**: no change — the fn body is lowered normally. The
ev_shape is derived from the fn's row at emit time when its
closure record is constructed (not at lowering time).

**LambdaExpr**: `LMakeClosure(handle, LFn(...), captures, [])` —
ev_slots is empty at lower time. Emit fills them based on the
lambda's ev_shape and the surrounding handler_stack.

**HandleExpr**: lowers to `LHandleWith(handle, body, handler)`.
No LBuildEvidence. The handler's arms are registered as known
dispatch targets for body's poly calls.

**CallExpr** to a polymorphic fn:
- If handler_stack at call site covers all of callee's ev_shape,
  each slot resolves to a CONCRETE fn_idx. The LCall is
  EQUIVALENT to the current LCall except the closure record it
  invokes has been built WITH evidence slots filled.
- The CLOSURE CONSTRUCTION is where evidence enters. If the
  callee is a TOP-LEVEL FN (its closure is static-top), we need
  a PER-SCOPE variant of the closure — one with ev_slots filled
  for THIS scope's handlers. This is built transiently at the
  call site.
- If the callee is a LAMBDA already captured with ev_slots, the
  ev_slots are baked in at capture time.

### Transient closures for top-level fns called in handler scope

Top-level `my_op`'s static closure has `[fn_ptr, 0, <no-ev>]`.
At the call site `my_op()` inside `handle { ... } with mem_bump`,
we need `[fn_ptr, 0, <mem_bump's alloc_arm fn_idx>]`.

Options:

**Option 1 — transient alloc.** At call site, emit:
```
(emit_alloc 12 "call_tmp")
(local.get $call_tmp) <fn_ptr> (i32.store offset=0)
(local.get $call_tmp) (i32.const 0) (i32.store offset=4)
(local.get $call_tmp) <alloc_arm_fn_idx> (i32.store offset=8)
(local.get $call_tmp) ;; __state for call
... call_indirect
```

Cost: N bytes of arena per poly-call. Adds arena pressure but
matches the handler's scope lifetime (the arena reclaims when
the scope exits).

**Option 2 — per-handler-scope cached closure.** At HandleExpr
entry, pre-build a version of every top-level poly fn's closure
with this scope's evidence. Store in a scope-local table. Calls
look up the cached version.

Cost: upfront work per HandleExpr. Pays off if the scope
contains multiple calls to the same poly fn.

**Option 3 — lazy caching.** On first call to a poly fn in a
scope, build & cache. Subsequent calls reuse.

**Mentl's choice: Option 1 with arena-aware allocation.**
Simplest. The arena handler (emit_memory_arena, landed Phase E)
reclaims per-scope — evidence records are born and die with
their handler scope. Zero cross-scope retention. The cost is
reasonable because polymorphic poly-call chains are bounded by
program structure.

Option 3 can be a future optimization if benchmarks show it
matters. Mentl's discipline: simpler now.

### CallExpr translation — the concrete shape

```
CallExpr(f, args) where callee is a polymorphic fn:

  1. Evaluate f's closure pointer.
  2. Read f's ev_shape (derived at emit time from its row).
  3. For each (op_name, slot_idx) in ev_shape:
       Resolve op_name in current handler_stack.
       Get handler arm's fn_idx.
  4. If ev_shape is empty (monomorphic): just LCall.
     If non-empty: allocate transient evidence record:
       ptr = emit_alloc(8 + 4*(f.capture_count + len(ev_shape)))
       copy fn_ptr and capture_count from f's closure
       copy each capture_i from f's closure
       store each ev_slot_j at offset 8 + 4*capture_count + 4*j
     Use transient ptr as __state in call_indirect.

Monomorphic case (handler_stack covers all of ev_shape): all
slot values are concrete fn_idx constants; no runtime evidence
fetch.

Polymorphic pass-through case (caller itself lacks a handler for
some op): the caller's own __state contains that op's evidence
slot. Caller resolves slot_idx_in_caller's_state, loads, stores
into transient record's slot.
```

---

## Layer 3 — Emission

### LMakeClosure grown emit

Today:

```
LMakeClosure(_h, LFn(fn_name, …), captures_exprs) => {
  let n = len(captures_exprs)
  let size = 8 + n * 4
  perform emit_alloc(size, "state_tmp")
  <store fn_ptr at 0>
  <store capture_count at 4>
  <store each capture at 8 + 4*i>
}
```

After H1:

```
LMakeClosure(_h, LFn(fn_name, …), captures_exprs, ev_exprs) => {
  let nc = len(captures_exprs)
  let ne = len(ev_exprs)
  let size = 8 + 4 * (nc + ne)
  perform emit_alloc(size, "state_tmp")
  <store fn_ptr at 0>
  <store capture_count at 4>   // still capture_count, not total
  <store each capture at 8 + 4*i>
  <store each ev_slot at 8 + 4*nc + 4*j>
}
```

Header semantics: `capture_count` remains the fence between
captures and evidence. Readers (lambdas accessing captures /
evidence) compute their offsets at their OWN emit time using
THEIR OWN known capture_count.

### LEvPerform emit (substrate prep landed; wire up)

```
LEvPerform(_h, op_name, slot_idx, args) => {
  emit_expr_list(args)
  // Load ev_slot_j from current __state:
  //   offset = 8 + 4 * body_capture_count + 4 * slot_idx
  // body_capture_count is known at body emit time — it's THIS
  // function's own capture_count, not the callee's.
  let body_cc = <fetched from body emit context>
  let absolute_offset = 8 + 4 * body_cc + 4 * slot_idx
  perform wat_emit("    (local.get $__state)\n")
  perform wat_emit("    (i32.load offset=")
  perform wat_emit(int_to_str(absolute_offset))
  perform wat_emit(")\n")
  perform wat_emit("    (call_indirect (type $ft")
  perform wat_emit(int_to_str(len(args) + 1))
  perform wat_emit("))\n")
}
```

**Subtle:** body_capture_count must be threaded to every
LEvPerform emit site inside a body. Solutions:

**Option A.** Thread through as a handler-state effect:
`perform current_body_captures() -> Int`. A BodyContext effect.

**Option B.** Compute once at emit_fn_body entry and pass as
parameter through the emit walk.

**Option C.** Store on each emitted function's metadata, looked
up by name at emit time.

**Mentl's choice: Option A.** A BodyContext effect with
`current_body_captures()` reads like "ask the graph for the
current body's capture count." Handler-state is Inka-native.
Installed per-fn-body.

```
effect BodyContext {
  current_body_captures() -> Int
  current_body_evidence() -> List   // [(op, slot)]
}

handler body_context with captures = 0, evidence = [] {
  current_body_captures() => resume(captures)
  current_body_evidence() => resume(evidence)
}
```

`emit_fn_body` installs a fresh handler instance with the body's
specific captures/evidence before emitting the body expressions.

### CallExpr emit — with transient evidence

The existing LCall emit pushes __state from the callee's closure.
For polymorphic callees, it instead constructs a transient:

```
LCall(_h, f, args) when f has nonempty ev_shape => {
  emit_expr(f)                                    // f's closure ptr
  perform wat_emit("    (local.set $callee_closure)\n")
  let ev_shape = <fetched from f's type>
  let cc      = <f's capture_count, known at emit time>
  let ec      = len(ev_shape)
  let total_size = 8 + 4 * (cc + ec)
  perform emit_alloc(total_size, "state_tmp")
  // Copy header + captures from callee_closure
  emit_copy_slots("callee_closure", "state_tmp", 0, 8 + 4*cc)
  // Resolve each evidence slot from current handler_stack and store
  emit_ev_slot_stores(ev_shape, 8 + 4*cc, "state_tmp")
  // Call with state_tmp as __state
  perform wat_emit("    (local.get $state_tmp)\n")
  emit_expr_list(args)
  perform wat_emit("    (local.get $state_tmp) (i32.load offset=0)\n")
  perform wat_emit("    (call_indirect (type $ft")
  perform wat_emit(int_to_str(len(args) + 1))
  perform wat_emit("))\n")
}
```

`emit_ev_slot_stores` iterates ev_shape and for each
`(op_name, slot_j)`:
- Look up op_name in HANDLER_STACK_AT_EMIT_TIME.
- Get the handler arm's fn_idx (a known global: `$<handler_name>_<op_name>_idx`).
- Store at offset 8 + 4*cc + 4*j in state_tmp.

Handler-stack-at-emit-time is another BodyContext read:
`current_handler_stack() -> List`.

### emit_fn_index_globals extension

Each handler arm needs a registered fn_idx. Today only
LMakeClosure fns get indices. H1 extends: every handler arm
(the body of each arm in each handler definition) is emitted as
a WASM function and registered with an fn_idx global.

Naming: `$<handler_name>_<op_name>_idx`. For mem_bump's alloc
arm: `$mem_bump_alloc_idx`. Emit:

```
(global $mem_bump_alloc_idx i32 (i32.const N))
```

Where N is its slot in the function table. Same pattern as
existing per-fn idx globals.

---

## Layer 4 — Inference: handler_stack grown

Phase C's handler_stack stored just handler names. H1 needs
richer metadata:

```
handler_stack: List[(String, List)]
  // handler_name, handled_op_names
```

At each `handle body with h` / `body ~> h`:
- Push (handler_name, [op_names_h_handles])
- After body: pop

Existing `inf_push_handler(name)` extends to
`inf_push_handler(name, op_names)`.

**Per-handler op_names retrieval.** Each HandlerDeclStmt already
lists its arms; infer can extract op_names from arms. For PTee
inline/block, the handler is a VALUE whose type is a handler-
record — today untyped. That's a separate sub-handle (already
flagged in Phase C as requiring handler-value typing). For
HandleExpr with arms literal, op_names are trivially read.

---

## Layer 5 — what closes when H1 lands

- `fn my_op() = perform alloc(1)` — inference synthesizes
  ev_shape = [("alloc", 0)].
- `handle { my_op() } with mem_bump` — compile-time resolves
  slot_0 to `$mem_bump_alloc_idx`.
- Emit produces a transient evidence record per call; calls
  `$mem_bump_alloc_idx` through call_indirect.
- Pure monomorphic chains (handler_stack covers every perform)
  emit identical-to-today WAT via LPerform direct calls.
- Polymorphic pass-through (caller itself polymorphic) works:
  caller's __state carries the evidence; call site propagates.
- The substrate gains fully-reified evidence. Handler IS state
  is operational, not aspirational.

---

## What H1 reveals (expected surprise — big ones here)

### Revelation A — LBuildEvidence is redundant

As traced above: separate LIR variant for "build evidence"
is duplicating LMakeClosure's job. Unifying into LMakeClosure
tightens the substrate. **Requires Phase D's LIR variant to be
removed in the same cascade.** Design surpass — surfaced for
approval.

### Revelation B — BodyContext effect

Emitting LEvPerform / LCall-with-evidence requires knowing the
current body's capture_count and handler_stack. Threading these
through every emit call would be invasive; a handler-state
effect per body is the Inka-native solution. **This is a NEW
EFFECT to add to the substrate: BodyContext.**

### Revelation C — Handler arm fn indexing

Handler arms must become first-class emitted WASM functions
with fn_idx globals. Today only LMakeClosure bodies get
registered. The emitter's fn table generation needs extension
to include handler arms. **Possibly a sub-handle: H1.1 handler-
arm emission.**

### Revelation D — Handler value typing (interaction with PTee)

For `body ~> handler_val` (PTee), the RHS is a handler VALUE
whose type should describe what it handles. Today that type is
opaque. Without handler-value typing, PTee sites cannot
synthesize evidence correctly — they can't know which ops the
handler covers.

Options:
1. Scope H1 to HandleExpr (arms literal) only. PTee remains
   evidence-less until handler-value typing lands.
2. Introduce handler-value typing in the same pass: a new Ty
   variant `THandler(List)` that carries handled-op names. PTee
   infers RHS as THandler, reads handled-ops.

**Mentl's recommendation: Option 1 for this cascade.** PTee
handler-value typing is substantial on its own — it's C4's
deferred piece (Phase C flagged PTee subsumption as requiring
W4-level handler-value typing). H1 closes HandleExpr's evidence
wiring; PTee evidence arrives when handler-value typing does.
Scope-consistent with protocol_substrate_first.

### Revelation E — Effect-op dispatch relationship to H3's SchemeKind

In H3, effect ops get `EffectOpScheme(effect_name)`. A
`perform alloc(1)` looks up "alloc" → EffectOpScheme("Alloc").
At lower: the lookup distinguishes "alloc is an effect op,
dispatch via evidence" from "alloc is a regular fn, LCall."

**H1 and H3 are more tightly coupled than they appeared.**
H3's EffectOpScheme IS the trigger for LEvPerform emission.
Without H3, lower can't tell a perform site from a regular call.

Order in cascade: H3 first provides the SchemeKind machinery;
H1 consumes it to route perform sites to LEvPerform/LPerform.

---

## Design synthesis (for approval)

**Inference synthesizes ev_shape derivably** (candidate γ) — no
new storage, computed from the fn's fully-bound row at emit
time.

**LMakeClosure's signature grows to include ev_slots**
(surpass of Phase D). LBuildEvidence LIR variant is DELETED.
The closure record IS the evidence record; one concept.

**LEvPerform emission consults body_context** — a new
BodyContext effect installed per-fn-body providing
capture_count + handler_stack.

**Transient evidence record per poly call** — allocated from
EmitMemory (arena-aware). Emit-time-resolved slot values from
current handler_stack.

**Handler arm fn indexing** — emit every handler arm as a WASM
function with `$<handler>_<op>_idx` global. Sub-handle H1.1 if
big enough to split.

**PTee evidence scope** — OUT. Handler-value typing is a
separate piece; PTee subsumption + evidence arrives with it.
Named; post-six-handles discussion.

---

## Dependencies

- H6 FIRST (substrate hygiene; wildcard audit).
- H3 BEFORE (SchemeKind's EffectOpScheme distinguishes perform
  sites from calls — the trigger for LEvPerform).
- H2 BEFORE (unrelated; enables records which `__state` slots
  may hold, no structural coupling but same cascade order).
- H1 follows. Substantial work; H1.1 (handler arm emission) may
  surface as sub-handle.

---

## Estimated scope

- ~6 files touched: types.ka (BodyContext effect), infer.ka
  (handler_stack grown, ev_shape as derivable, handler arm
  registration), lower.ka (LMakeClosure signature +
  LBuildEvidence deletion, LCall-with-evidence branch), effects.ka
  (possibly row-arithmetic for ev_shape derivation), 
  backends/wasm.ka (LMakeClosure grown emit, LEvPerform wired
  with body_context, transient evidence emit for poly calls,
  handler arm fn_idx globals), pipeline.ka (install body_context
  handler at emit_module).
- **Major commit.** Larger than any prior phase. Tight internal
  coupling justifies single commit.
- **Sub-handles:** H1.1 handler arm emission (possibly), H1.2
  PTee handler-value typing (deferred to post-six).
