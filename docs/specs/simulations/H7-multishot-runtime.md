# H7 — MultiShot Runtime · heap-captured continuation as the emit residue

> **Status:** `[DRAFT 2026-04-23]`. MSR Edit 1 walkthrough. Peer to
> H1 (evidence reification): H1 designed the OneShot runtime emit
> path — evidence as slot-set on `LMakeClosure`, direct `call $op_<n>`
> for monomorphic perform sites, `call_indirect` through a
> closure-field for polymorphic sites. H7 designs the MultiShot
> runtime emit path — the heap-allocated **continuation struct**
> that captures the state-machine slice a handler arm will resume
> (once for OneShot-at-install, many times for backtrack, zero
> times for abort). Same `emit_alloc` swap surface (γ crystallization
> #8 — the heap has one story). No vtable. No MS allocator. No
> foreign-language vocabulary. The continuation is captures + evidence
> + state_index + ret_slot — four fields, one heap record, one
> `call_indirect` at resume.
>
> *Claim in one sentence:* **Every `@resume=MultiShot` op emits a
> call to `LMakeContinuation` at the perform site, allocating a
> heap struct via the same `emit_alloc` handler that allocates
> closures and variants; handler arms resume the captured struct
> via `call_indirect` on `fn_index`; trail-based rollback
> (primitive #1) bounds speculation; the substrate the oracle loop
> has been waiting for goes live.**

---

## 0. Framing — why H7 is the keystone of Phase B

### 0.1 What H7 resolves

DESIGN §0.5 primitive #2 names MultiShot-typed resume discipline as
load-bearing: *"MultiShot → heap-captured continuation. The
MultiShot-typed arms are the substrate Mentl's oracle uses to
explore hundreds of alternate realities per second under trail-
based rollback — also powers backtracking, hyperparameter search,
speculative execution, distributed RPC-as-delimited-continuation."*
(DESIGN.md:135-141.)

The substrate has known this for the entire γ cascade. `src/types.mn:70-73`
declares `type ResumeDiscipline = OneShot | MultiShot | Either`.
`src/lower.mn:15` has carried the comment *"MultiShot → heap
continuation struct"* since H1. `src/backends/wasm.mn:14` promises
*"MultiShot have already been rewritten into state machines or
heap continuation structs by lower.mn."* `src/cache.mn:273-276`
already persists `ResumeDiscipline` tags across the Pack/Unpack
boundary.

**The substrate knows. The emit path hasn't been written.**

Today, the tree contains exactly ONE op declared `@resume=MultiShot`:
`enumerate_inhabitants` at `src/mentl.mn:94`. Its handler arm at
`src/mentl.mn:453` is the substrate's honest stub:

```
enumerate_inhabitants(_ty, _eff, _ctx) => resume([])
```

A single `resume([])` — one-shot, empty result, no fork. Mentl's
oracle loop (§1.1.5 of MO walkthrough — the MS-powered reality
explorer) cannot fire until H7 lands; until then it surfaces no
candidates. The gradient oracle is present in the graph
(`src/mentl.mn:127-175 — gradient_next`), but the speculative
branch of it — *exploring hundreds of alternate realities* — is
substrate-gated on MS emit.

H7 lands that substrate. After H7:

- `enumerate_inhabitants` can fork — real proposers (enumerative,
  SMT, LLM) ship as sibling `Synth` handlers, each a MS handler
  that resumes per-candidate.
- `Choice` (CE walkthrough) executes — `backtrack` handler resumes
  per-option under trail rollback.
- `race` (HC2 walkthrough) executes — parallel speculation over MS
  candidate handlers.
- Arena policies (AM walkthrough) decide — `replay_safe` re-performs,
  `fork_deny` rejects, `fork_copy` deep-copies.
- Pulse (DP-F.5) exists — autodiff's backward pass is MS.
- The oracle loop at `src/mentl.mn:134 — gradient_next` completes its
  speculative semantics.

H7 is the one substrate edit that unblocks Phase B's MS-dependent
remainder (B.4 race × MS, B.5 arena-MS, B.11 ML training, C.2
crucible_oracle, C.4 crucible_ml, D.4 L2 tag, D.5 L3 tag). The
critical-path graph in `alright-let-s-put-together-silly-nova.md`
identifies it as the single largest β piece.

### 0.2 What H7 designs

- **§1** — Three emit shapes: existing `LPerform`, existing
  `LEvPerform` (H1), new `LMakeContinuation` (H7). Relationship
  to H1's evidence substrate.
- **§1** — Heap layout of the continuation struct.
- **§1** — State-machine desugaring — the *numbered states per
  perform* rewrite (DESIGN Ch 10.4 / line 2959).
- **§2** — Per-edit-site eight-interrogation table.
- **§3** — Forbidden-pattern enumeration per edit site — all nine
  drift modes (1–9) plus generalized fluency-taint against
  JS `async`/`await`/`yield`, Python generators, Rust `async fn`,
  Scheme `call/cc`, delimited-continuation-library-ese.
- **§4** — Substrate touch sites at file:line targets. Halt-signal
  §4.0 corrects MSR Edit 1's LowExpr location.
- **§5** — Worked example — `enumerate_inhabitants` rewritten pre-H7
  vs post-H7, with the numbered-state form made concrete.
- **§6** — Composition with other MS substrate (CE, AM, HC2, BT, IC).
- **§7** — Three design candidates + Mentl's choice.
- **§8** — Acceptance criteria.
- **§9** — Open questions (pre-answered per MSR + QA).
- **§10** — Dispatch + closing.

### 0.3 What H7 does NOT design

- **`Choice` effect + `choose` op.** CE walkthrough. H7 provides
  the *emit substrate* any MS op uses; CE provides the specific
  user-visible effect. `Choice` will emit via `LMakeContinuation`
  once H7 lands — no CE-specific emit logic.
- **Arena-aware MS handlers** (`replay_safe` / `fork_deny` /
  `fork_copy`). AM walkthrough. H7 provides the default heap
  capture via `emit_alloc`; AM designs the three policies that
  intercept that `emit_alloc` handler for arena-scoped captures.
- **`race` handler combinator.** HC2 walkthrough. `race` composes
  MS candidate handlers; H7 makes their forking real at runtime.
- **Cross-module MS dispatch** (the BT linker's resume-discipline
  metadata preservation). BT walkthrough §4. H7 specifies what
  metadata the emit needs; BT ensures it survives the link pass.
- **Tier-3 bootstrap growth.** Hβ §2 Tier-3 (post-L1 incremental
  self-hosting). H7's bootstrap edit
  (`bootstrap/src/emit_expr.wat`) is deferred post-L1 by design;
  pre-L1 self-compile exercises only OneShot ops.
- **SMT discharge of MS obligations.** Orthogonal to H7; lives in
  B.6 verify_smt (VK walkthrough).

### 0.4 Relationship to H1 (evidence reification)

H1 designed OneShot's emit path. H7 is the MultiShot peer.

| Axis | H1 (OneShot) | H7 (MultiShot) |
|------|-------------|----------------|
| Kernel primitive | #2 handlers + resume discipline (OneShot arm) | #2 handlers + resume discipline (MultiShot arm) |
| Resume count | Exactly once — `return_call $op_<n>` or `call_indirect` via closure field | Zero or more times — `call_indirect` on continuation's `fn_index` |
| Capture shape | Evidence = slot-set on `LMakeClosure`'s ev_slots (added in H1) | Evidence = slot-set on continuation record; captures likewise; state_index + ret_slot peer fields |
| Heap record | Closure record: `fn_index \| captures[] \| ev_slots[]` | Continuation record: `fn_index \| state_index \| captures[] \| ev_slots[] \| ret_slot` |
| Allocation | `emit_alloc(size, target_local)` — γ #8 | Same. |
| Dispatch (monomorphic site) | `LPerform` → `call $op_<n>` | `LMakeContinuation` → capture, then handler arm resumes via `call_indirect` |
| Dispatch (polymorphic site) | `LEvPerform` → `call_indirect` through ev_slot | `LMakeContinuation` — same resume shape regardless of polymorphism |
| State-machine desugaring | Not needed (OneShot returns; caller continues inline) | Required (resume re-enters after suspension; function is split into numbered states) |
| Trail interaction | None — OneShot commits straight through | Every resume commits; arena handlers decide what capturing means |

**H1 was closure-as-evidence.** H7 is **continuation-as-peer-record**.
Same heap discipline; different resume topology. The continuation
struct IS the closure record with two more fields (`state_index`,
`ret_slot`). Neither is an OOP object, neither is a JS Promise,
neither is a Rust `Future`. Both are records allocated through the
one `emit_alloc` swap surface.

---

## 1. The substrate — three emit shapes, one allocator, one dispatch

### 1.1 The existing OneShot emit shapes (H1 territory — read-only context for H7)

**`LPerform(Int, String, List)` — monomorphic direct-call.** Per
`src/lower.mn:66`. Emitted when inference determines the perform
site is monomorphic (row is ground; handler identity known at compile
time). Lowers to `(call $op_<n> <args>)` in WAT. No closure struct;
no `call_indirect`; no runtime dispatch. Every op the compiler
can resolve statically takes this path. This is >95% of all perform
sites per H1 evidence reification's statistics.

**`LEvPerform(Int, String, Int, List)` — polymorphic evidence-passing.**
Per `src/lower.mn:77`. Emitted when inference determines the perform
site is polymorphic (row carries a row variable; handler evidence
reaches the site via a closure field populated at handler install).
Lowers to `(call_indirect ... (i32.load offset=<slot_offset> $closure))`
— the op's function index is a field on the closure record. Per
H1 evidence reification, this is the *only* polymorphic dispatch
form: the closure record IS the evidence record. There is no vtable.
There is no dispatch table. `fn_index` is a FIELD on the record.

**`LSuspend(Int, Int, LowExpr, List, List)` — polymorphic first-class
function call with ev_slots.** Per `src/lower.mn:60`. Emitted by
`lower_app` (line 178) when the callee is a polymorphic first-class
function. Same closure-field-read discipline as `LEvPerform`, but for
function calls rather than perform sites. Read-only context for H7.

**None of these three variants capture a continuation.** They all
return to their caller inline after the callee completes. OneShot.
One return per invocation.

### 1.2 The new MultiShot emit shape — `LMakeContinuation`

```
// src/lower.mn — LowExpr ADT (see §4.0 halt-signal for location
// correction relative to MSR Edit 1's table)
type LowExpr
  = ...existing variants...
  | LMakeContinuation(Int, LowFn, List, List, Int, Int)
    //                ^    ^       ^      ^      ^      ^
    //                |    |       |      |      |      |
    //                handle (the source TypeHandle; matches other variants)
    //                |    |       |      |      |      |
    //                resume_fn (the LowFn the handler will call_indirect;
    //                |         its body is a switch on state_index that
    //                |         jumps to the correct state arm)
    //                |       |      |      |      |
    //                captures_exprs (List<LowExpr>; values to store into
    //                |              the record at capture time;
    //                |              identical shape to LMakeClosure's captures)
    //                |              |      |      |
    //                ev_slots (List<Int>; evidence slot indices;
    //                         identical shape to LMakeClosure's ev_slots —
    //                         H1 evidence reification carries forward)
    //                         |      |      |
    //                state_index (Int; the numbered state the resume_fn
    //                            should enter when called; fixed at
    //                            capture time — this perform site is
    //                            state N, so resume jumps to state N+1)
    //                            |      |
    //                ret_slot (Int; local slot where the resumed value
    //                         is written before control returns to the
    //                         continuation body; populated by resume(v))
```

**One variant. Six fields. Four capture semantics.** Every field has
a precedent in existing LowExpr variants:

- `handle: Int` — every variant carries this (type handle in the graph);
  `lexpr_handle` (src/lower.mn:126+) preserves it.
- `resume_fn: LowFn` — same type as `LMakeClosure`'s second field. The
  function that the handler arm will invoke via `call_indirect`. Its
  body is a `switch` on `state_index` (a LowSwitch; already emit-able)
  that restores captures + executes the correct state arm.
- `captures_exprs: List<LowExpr>` — identical in shape and emit path
  to `LMakeClosure`'s third field. The captured locals at the
  perform site — values that must survive until resume. Emitted as
  stores into the heap record at fixed offsets.
- `ev_slots: List<Int>` — identical in shape and emit path to
  `LMakeClosure`'s fourth field (H1 evidence reification). The
  handler-install evidence (function indices for polymorphic ops in
  scope) that must remain accessible across the suspension.
- `state_index: Int` — **new field**. Literal integer; the numbered
  state the resume_fn should execute. Compile-time constant per
  perform site (lower.mn assigns state ordinals in traversal order).
  Stored as a field on the heap record so the resume_fn's switch can
  read it.
- `ret_slot: Int` — **new field**. Local slot in the continuation
  frame where `resume(v)` writes `v` before dispatching into the
  continuation body. The handler's `resume(v)` action is: *store v
  to ret_slot, then jump to state_index*. Decoupling v's delivery
  from the switch makes `resume()` (unit-return) and `resume(v)`
  (valued-return) one mechanism with different ret_slot behavior.

### 1.3 Heap layout of the continuation struct

`LMakeContinuation` emits into a heap record whose layout mirrors
`LMakeClosure`'s with two additional fields. In the notation of
`src/backends/wasm.mn`'s `emit_alloc` output:

```
offset  field           type    shape reference
──────  ──────────────  ─────── ─────────────────────────────────
  0     fn_index        i32     same as LMakeClosure[0]
  4     state_index     i32     NEW — numbered state to enter
  8     n_captures      i32     same as LMakeClosure[4] (after fn_index slot)
 12     capture[0]      i32     each capture is i32 (flat/pointer); same as LMakeClosure
 16     capture[1]      i32
 ...    ...
 12+4k  n_evidence      i32     same as LMakeClosure after captures
 ...    evidence[i]     i32     function indices per ev_slots (H1 discipline)
 ...    ret_slot        i32     NEW — where resume(v) writes v
```

(Exact byte offsets computed at emit time per `emit_alloc`'s
`size` argument; layout constants are substrate, not user-visible.
The layout is not a new convention — it is LMakeClosure's layout
plus two 4-byte fields.)

**One heap record. One allocation. One allocator.** All of it
through `perform emit_alloc(size, target_local)` —
`src/backends/wasm.mn:72-74`. The default `emit_memory_bump`
handler monotonically bumps `$heap_ptr`. Arena handlers (`emit_memory_arena`,
B.5 AM-arena-multishot) intercept with region-tracking discipline.
GC handlers (F.4 post-first-light) intercept with tracing discipline.
**H7 allocates the continuation struct via the one
`emit_alloc` swap surface.** γ crystallization #8 (the heap has
one story) is preserved.

### 1.4 State-machine desugaring — the numbered-state rewrite

The caller's function is split at every MS perform site into numbered
state slices. DESIGN §10.4 (line 2959) specifies the shape: *"The
function is rewritten as an enum state machine — each suspension
a numbered state, locals captured in the state struct."*

Pre-desugar (user-visible):

```
fn explore(ctx) with Choice + Verify = {
  let fresh = graph_fresh_ty(reason_synth())
  let candidate = perform choose(options_for(ctx))
  let accepted = perform verify_candidate(candidate)
  if accepted { Some(candidate) } else { None }
}
```

Post-desugar (LowIR, conceptual — actual IR shape is
`LMakeContinuation` nested in `LHandle`):

```
// State 0: entry up to the first MS perform.
fn explore__state_0(ctx) with Choice + Verify = {
  let fresh = graph_fresh_ty(reason_synth())
  let opts = options_for(ctx)
  // Suspension point: allocate continuation capturing { fresh, opts, ctx },
  //                   ev_slots [verify_candidate ev], state_index=1, ret_slot=$candidate_slot
  //                   then perform choose(opts); the handler will resume with each option.
  LMakeContinuation(
    handle=h_cont,
    resume_fn=explore__resume,
    captures_exprs=[ctx, fresh, opts],
    ev_slots=[verify_ev_slot],
    state_index=1,
    ret_slot=candidate_slot
  )
  perform choose(opts)  // handler receives the above continuation
}

// State 1: after choose resumes. resume_fn's switch dispatches here.
fn explore__state_1(captures, candidate) = {
  let (ctx, fresh, opts) = captures
  let accepted = perform verify_candidate(candidate)
  if accepted { Some(candidate) } else { None }
}

// The resume_fn — one function per capturing fn; switch on state_index.
fn explore__resume(cont_ptr) = {
  let state = (i32.load offset=4 cont_ptr)  // state_index field
  switch state {
    1 => {
      let ctx      = (i32.load offset=12 cont_ptr)
      let fresh    = (i32.load offset=16 cont_ptr)
      let opts     = (i32.load offset=20 cont_ptr)
      let ret_slot = (i32.load offset=<ret_offset> cont_ptr)
      let candidate = (i32.load (local.get ret_slot))
      explore__state_1((ctx, fresh, opts), candidate)
    }
    // state 0 is the ENTRY and is never resumed into (function calls it directly)
    _ => unreachable  // OR E_UnknownContState at runtime if resume discipline violated
  }
}
```

**Multiple perform sites ⇒ multiple states.** A function with three
`perform` suspensions has states 0 (entry) → 1 (after first perform)
→ 2 (after second) → 3 (after third). The resume_fn's switch has
three arms (1, 2, 3). Each `LMakeContinuation` fixes its
`state_index` at the one the handler arm should jump to.

**The resume_fn is synthesized per capturing function**, not per
perform site. One function, N switch arms, one heap record shape
per function (captures + ret_slot vary only in which union-compat
bytes are valid per state). lower.mn tracks this as a per-function
state table during the MS-aware lowering pass.

### 1.5 Handler-arm semantics at resume

The handler for `choose` (e.g., `backtrack` in CE walkthrough §1.3)
receives a continuation pointer implicitly via the op's calling
convention. Inside the handler body:

- `resume(v)` emits:
  1. Store `v` into `cont.ret_slot` (i.e., `(i32.store (local.get
     ret_slot_local) v)`).
  2. Tail-call the resume_fn via `call_indirect` on `cont.fn_index`,
     passing `cont_ptr`.
- `resume()` (unit variant) emits: skip the store, tail-call.
- **Resume-zero** (the handler doesn't call resume — `pick_first`'s
  empty-options arm that performs `abort()` is an example): no call;
  control flows into whatever the arm produces (typically an `Abort`
  perform).
- **Resume-multi** (backtrack loops over options, calling resume once
  per): each call_indirect is a fresh execution of the continuation
  body. Trail checkpoints (primitive #1's `graph_push_checkpoint` /
  `graph_rollback`) bound each speculative resume. Per-option state
  in the continuation record is NOT MUTATED between resumes — captures
  are read-only per state arm. Trail rollback undoes any graph
  mutations the speculative resume produced.

**Resume discipline is carried by the op's type, checked at type-check
time**, enforced at handler-install time (the handler's `resume` calls
must be consistent with the op's declared discipline). Runtime carries
no discipline tag on the record; once emit succeeds, the record IS a
MS continuation and the handler's arm IS the authority.

---

## 2. Per-edit-site eight interrogations

Every edit site passes the eight before being admissible. One line
per primitive. Residue → code.

### 2.1 `src/lower.mn` — add `LMakeContinuation` variant to `LowExpr`

| # | Primitive | Interrogation answer |
|---|-----------|---------------------|
| 1 | **Graph?** | `LowExpr` is consumed by emit; the graph carries the source TypeHandle on every variant. `LMakeContinuation` carries `Int` handle (field 0) — same as its peers. `lexpr_handle` (`src/lower.mn:126+`) extends by one arm returning `h`. No new graph edge type needed. |
| 2 | **Handler?** | The continuation's allocation routes through `perform emit_alloc(size, target_local)` — the SAME handler that allocates closures, variants, records, tuples, and strings. Three arena-aware handlers (AM / B.5) are peer swaps. `emit_memory_bump` is the default; `emit_memory_arena` intercepts for scoped allocs; `emit_memory_gc` intercepts post-F.4. No new handler surface. |
| 3 | **Verb?** | N/A at this edit site. LMakeContinuation is an IR node, not a surface verb. Composition via `~>` (handler install) surrounds the perform site; the continuation captures the downstream slice of that `~>` chain. |
| 4 | **Row?** | Resume discipline is part of the op's type (`TCont(ret, MultiShot)`); row algebra already handles it via primitive #2's type-level resume discipline (`ResumeDiscipline` ADT at `src/types.mn:70-73`). No row algebra extension. `!MultiShot` as a row modifier is DEFERRED per QA Q-B.2.1 — `!Choice`, `!Synth`, etc. (effect-name-level negations) suffice until a concrete need surfaces. |
| 5 | **Ownership?** | Captures are recorded `own` where the source binding was `own`; `ref` captures would fail the fork-deny arena policy (AM §4). H7 does NOT decide fork-deny — that's B.5. H7 stores captures as-is; ownership discipline enforces at the arena handler layer. Per H1's evidence reification addendum, evidence slots carry `fn_index` values (Int, `ref`-level); ownership is borrowed. |
| 6 | **Refinement?** | N/A at the variant declaration. Refinement on MS resume-count ("handler MUST resume at least once on non-empty options") is a user-level refinement opportunity on specific handlers (e.g., `handler pick_first with NonEmpty(options)`); not substrate-level. |
| 7 | **Gradient?** | `LMakeContinuation` in LowIR unlocks `CMultiShotRuntime` as a gradient capability — present post-H7 for user code. (Naming per PLAN ledger Capability ADT extension; not substrate-blocking.) |
| 8 | **Reason?** | Each `LMakeContinuation` construction records a Reason on the graph_bind of its handle — `Inferred("h7 ms capture at <perform_site_span>")` per existing graph_bind conventions. When a handler arm resumes, `graph_push_checkpoint` / `graph_rollback` compose with the continuation's per-resume trail; no new Reason vocabulary. |

### 2.2 `src/lower.mn` — `lower_perform` arm on MS op

The `lower_app` / `lower_expr` path currently emits `LPerform`
(monomorphic) or `LEvPerform` (polymorphic) for every perform site.
H7 adds a third branch: when the op's resume discipline is
`MultiShot`, emit `LMakeContinuation` + the suspension.

| # | Primitive | Interrogation answer |
|---|-----------|---------------------|
| 1 | **Graph?** | Resume discipline is read from the op's TCont — graph-resident. `graph_chase` on the op's handle returns `TCont(ret, MultiShot)` for MS ops; on `TCont(ret, OneShot)` the existing LPerform/LEvPerform path stays. One new match arm at `lower_expr`'s perform-site branch. |
| 2 | **Handler?** | The `lower_expr` body is inside the LookupTy + GraphRead handler chain; no new handler at this site. The MS branch calls `perform ms_state_alloc(handle)` — a new LowerState effect op that returns the state ordinal for this perform site within its enclosing function. (LowerState is a small MS-only peer effect within lower.mn; details §4.1.) |
| 3 | **Verb?** | N/A (lower arm is internal; verbs are surface-level). |
| 4 | **Row?** | The arm's row is the existing lower.mn row (GraphRead + EnvRead + LookupTy + Diagnostic); MS emit adds the new `LowerState` effect. `LowerState` is installed by the function-boundary handler; MS-free functions never perform it. |
| 5 | **Ownership?** | Captures determined by free-var analysis (existing `collect_free_vars` helper, same as H1); ownership per-capture preserved in the capture list. Existing machinery. |
| 6 | **Refinement?** | N/A. |
| 7 | **Gradient?** | N/A at lower-time. |
| 8 | **Reason?** | `graph_bind(h_cont, TCont(ret, MultiShot), Inferred("ms capture site"))` at the LMakeContinuation's handle — one reason per MS perform site. When unification through the capture's type happens at emit, existing `graph_bind` Reason forwarding fires per standard machinery. |

### 2.3 `src/backends/wasm.mn` — `LMakeContinuation` emit arm

The backend matches on LowExpr variants and emits WAT. H7 adds one
arm (analogous to the existing `LMakeClosure` arm; they share ≥70% of
their emit sequence — captures store loop + ev_slots store loop are
identical; the two new fields are two extra i32 stores at fixed
offsets).

| # | Primitive | Interrogation answer |
|---|-----------|---------------------|
| 1 | **Graph?** | Emit reads types via `perform lookup_ty(h)` to size captures; no new read. The continuation record's total size is `(3 + n_captures + 1 + n_evidence + 1) * 4` bytes — compile-time known at emit time. |
| 2 | **Handler?** | `perform emit_alloc(size, target_local)` — the SAME handler as LMakeClosure / LMakeVariant / LMakeRecord. No new EmitMemory op. The allocation strategy — bump / arena / GC — is at the installed handler's discretion. |
| 3 | **Verb?** | N/A. |
| 4 | **Row?** | wasm.mn's `with WasmOut + EmitMemory + LookupTy + GraphRead + Diagnostic` row is unchanged. |
| 5 | **Ownership?** | Capture stores write each source expr's value to its fixed offset; ownership discipline is enforced at lower-time (the fork-deny / fork-copy / replay-safe policy that AM/B.5 adds). Emit is ownership-agnostic — it stores i32s. |
| 6 | **Refinement?** | N/A. |
| 7 | **Gradient?** | The MS capability-unlock is at the user's source level; emit just materializes the substrate. |
| 8 | **Reason?** | Emit is read-only wrt Reason — graph carries the Reasons; emit doesn't write new ones. |

### 2.4 `src/cache.mn` — version bump `v3 → v4`

Per QA Q-B.2.3 (resolved). H7 introduces new LowExpr variants and
new emit sequences. Pack/Unpack is version-gated (`src/cache.mn:43-46`);
v3's serialized `.kai` files never contain LMakeContinuation and
would be silently valid if read back under v4 — a correctness risk.
Version bump forces full invalidation.

| # | Primitive | Interrogation answer |
|---|-----------|---------------------|
| 1 | **Graph?** | N/A (cache serializes the graph, isn't structurally part of it). |
| 2 | **Handler?** | Pack/Unpack effects (`lib/runtime/binary.mn` + peer handlers) — no new ops; one new variant encoding inside the existing `pack_lowexpr` / `unpack_lowexpr` match. (The new variant adds eight encode/decode lines per 2 x 4 byte fields, mirroring LMakeClosure's encoding.) |
| 3 | **Verb?** | N/A. |
| 4 | **Row?** | N/A. |
| 5 | **Ownership?** | N/A. |
| 6 | **Refinement?** | N/A. |
| 7 | **Gradient?** | N/A. |
| 8 | **Reason?** | Old `.kai` files with `compiler_version=3` fail the version check in `cache.mn:614` and trigger full recompile — the existing cache-invalidation Reason chain handles this. No new Reason vocabulary. |

### 2.5 `src/mentl.mn` — `enumerate_inhabitants` arm unlocked (post-H7)

Currently at `src/mentl.mn:453`: `enumerate_inhabitants(_ty, _eff, _ctx) => resume([])`.
After H7 substrate lands, this stub arm remains (still an honest
empty-search default — the substrate doesn't hallucinate proposers).
What CHANGES: sibling `Synth` handlers (enumerative, SMT, LLM) can now
ship. Each installs via `~>` above `mentl_default` and resumes with a
non-empty candidate list. Per-option resume is the MS semantics H7
unlocks; `mentl_default`'s fallback `resume([])` is OneShot-at-install
semantics (the `choose` is MS-typed but resuming once is a valid MS
instance — the first option is `[]`, there's no second option to try,
semantics hold).

**No source change to `mentl.mn:453` is required for H7 to land.**
The arm is already correctly shaped. H7 unblocks the *fleet of
sibling handlers* that will arrive post-H7; the arm-as-baseline is
honest about what the default handler does. §4.4 clarifies that H7's
landing commit does not touch mentl.mn; it touches lower.mn + wasm.mn
+ cache.mn only.

### 2.6 `bootstrap/src/emit_expr.wat` — Tier 3 growth (deferred post-L1)

Per MSR Edit 1 landing signal and Hβ §2 Tier 3: hand-WAT grows from
VFINAL's own output post-L1. Until L1 tags, the bootstrap WAT emits
only OneShot ops — which is fine, because self-compile exercises
only OneShot (only `enumerate_inhabitants` is MS, and its arm
resumes `[]` — no continuation capture required for a resume-with-
empty-list).

| # | Primitive | Interrogation answer |
|---|-----------|---------------------|
| 1 | **Graph?** | N/A at bootstrap level (hand-WAT has no graph; Tier 3 is mechanical transcription of VFINAL's emit into bootstrap after VFINAL self-hosts). |
| 2 | **Handler?** | The bootstrap's emit_alloc is hardcoded (bump); arena handlers are a post-L1 peer. |
| 3 | **Verb?** | N/A. |
| 4 | **Row?** | N/A. |
| 5 | **Ownership?** | N/A at hand-WAT. |
| 6 | **Refinement?** | N/A. |
| 7 | **Gradient?** | N/A. |
| 8 | **Reason?** | N/A. |

**§4.5 specifies this sub-handle as DEFERRED to the post-L1 Tier 3
sweep.** H7's landing commit does NOT include a bootstrap edit.

---

## 3. Forbidden patterns per edit site

Every edit site passes the nine named drift modes + generalized
fluency-taint. Foreign-ecosystem signals are flagged and refused.

### 3.1 At `LMakeContinuation` variant declaration (src/lower.mn)

- **Drift 1 (Rust vtable):** CRITICAL. The continuation record's
  `fn_index` field is ONE i32, populated at capture time from a
  compile-time resolved function index. It is NOT a vtable lookup;
  it is NOT an index into a dispatch table; it is NOT a jump table.
  The function index comes from the WASM funcref table entry for
  the synthesized `resume_fn` — one entry per capturing function,
  populated at module-init via `(elem ...)`. Per `src/mentl.mn:228`
  `catalog_handled_effects` precedent (and E.6 HandlerCatalog runtime
  — soon-to-be effectful): the catalog is a handler registry, not a
  vtable. Same here.
- **Drift 3 (Python dict / string-keyed effect):** `state_index` is
  `Int`, NOT `"state_0"` string. Same discipline as `TagId`
  (`src/types.mn:101` — `ConstructorScheme(TagId, Int)`) and
  `ResumeDiscipline` (enum). If you're about to type
  `"state_<N>"`, stop — it's a drift mode 8 in disguise.
- **Drift 5 (C calling convention):** ONE `$cont_ptr`
  parameter on the resume_fn. NOT `$closure + $ev + $ret_slot`
  separated. Offsets INTO the record. Same as H1 evidence reification
  (one `$state` parameter, offsets in).
- **Drift 6 (primitive-type-special-case):** `LMakeContinuation` is
  a LowExpr variant, peer to LMakeClosure; emit_alloc is the SHARED
  allocator. No "MS allocator". No "multi-shot memory". No "ms_heap".
  One heap, one allocator, one story.
- **Drift 7 (parallel-arrays-instead-of-record):** `captures_exprs`
  and `ev_slots` are two LIST fields on the ADT variant, matching
  LMakeClosure's parallel-fields shape (captures and ev_slots are
  likewise parallel on LMakeClosure). If lower.mn later wants to
  fuse (captures, captures_handles, ev_slots, ev_types) into a
  single record, that's Ω.5 consolidation — across ALL LMake* variants
  at once, not H7-specific. H7 matches the existing LMakeClosure
  shape; the consolidation is a separate cascade.
- **Drift 8 (mode flags):** No `mode: Int` field on the continuation
  record indicating "replay/deny/copy". The three arena policies are
  three peer handlers (B.5); they intercept `emit_alloc` at install
  time. The continuation record itself carries no policy tag.
- **Drift 9 (deferred-by-omission):** H7's commit lands ALL of:
  - LMakeContinuation variant added to LowExpr.
  - lower_perform MS arm.
  - wasm.mn emit arm.
  - cache.mn v3→v4 bump.
  - Drift-audit clean after edit.
  Bootstrap Tier 3 (§2.6) IS the single explicit deferred piece,
  named as its own sub-handle post-L1 (drift mode 9 discipline:
  "name the deferred piece, don't hide it in a 'complete' commit").
  The mentl.mn arm (§2.5) needs no change — verified-clean, not
  hidden-deferred.

### 3.2 At `lower_perform` MS arm (src/lower.mn)

- **Drift 2 (Scheme env frame):** State-slot assignment per function
  is a flat counter + map `(perform_site_span → state_index)`
  populated in one pass, NOT a linked-frame walk per resume site.
  Same discipline as LowerScope's existing flat-frame model
  (`src/types.mn:686-692 — effect LowerScope`).
- **Drift 4 (Haskell monad transformer):** The MS emit arm COMPOSES
  with the existing OneShot arm under the SAME `lower_expr` match;
  it does NOT introduce a "multi-shot monad" wrapping. One function,
  one match statement, three arms (OneShot monomorphic / OneShot
  polymorphic / MultiShot).
- **Drift 8 (string-keyed):** The dispatch on resume discipline is
  via `match` on `ResumeDiscipline` ADT (`OneShot | MultiShot |
  Either`), NOT string equality on `"MultiShot"`. The ADT already
  exists at `src/types.mn:70-73`; H7 composes on it.
- **Foreign fluency — JS async/await:** Do NOT import `yield` /
  `suspend` / `await` / `Promise` vocabulary into the emit path.
  The vocabulary is: *perform site* (the surface), *suspension*
  (the lower concept), *capture* (the substrate act), *resume*
  (the handler act), *continuation* (the heap record).
  DESIGN §0.5 primitive #2 fixes this lexicon.
- **Foreign fluency — Python generators:** Do NOT model the state
  machine as an *iterator protocol* (`next()` / `StopIteration`).
  The continuation is resumed by `call_indirect` on a record field,
  not by iterator-protocol dispatch. State 0 is NOT "iterator
  initialized"; it is "entry slice of the capturing function."
- **Foreign fluency — Rust async fn:** Do NOT introduce a `Future`
  trait, `Poll::Pending / Poll::Ready`, `impl Future`, or any trait
  infrastructure. Mentl has no traits; dispatch is via evidence
  passing (H1) or continuation capture (H7) — both records, neither
  a trait object.
- **Foreign fluency — Scheme call/cc:** The continuation here is
  *delimited* (scoped to the handler's installation boundary), not
  *undelimited* like Scheme's `call/cc`. The distinction matters:
  `backtrack`'s resume returns to the handler, not to the
  program's top-level. H7 is delimited-continuation substrate —
  Affect POPL 2025, not Scheme 1975.

### 3.3 At `src/backends/wasm.mn` emit arm

- **Drift 1 (vtable):** The `fn_index` stored at offset 0 of the
  continuation record is a WASM funcref table index — a compile-time
  integer. NOT a vtable pointer. NOT a pointer-to-function-pointer.
- **Drift 5 (C calling convention):** `call_indirect` uses ONE
  `$cont_ptr` parameter. No separate closure + evidence + args
  parameters.
- **Drift 6 (primitive-type-special-case):** Emit calls
  `perform emit_alloc(size, target_local)` — same as every other
  heap record. No MS-specific emit path.
- **Foreign fluency — bespoke allocator:** Do NOT generate inline
  `(global.get $heap_ptr) (local.set $ms_ptr) ...` directly. That
  is the default handler's body; emit calls it via `perform emit_alloc`
  to preserve the swap surface. DESIGN §7 "The handler IS the backend".

### 3.4 At `src/cache.mn` version bump

- **Drift 9 (deferred-by-omission):** The v3→v4 bump AND the
  LMakeContinuation Pack/Unpack arms land in the same H7 commit; the
  version number without the encoder is a corrupt cache format.
- **Drift 5 / byte-order confusion:** `pack_int` / `unpack_int` already
  byte-order-stable per IC.2 landing; H7 composes on existing machinery.

### 3.5 Generalized fluency-taint — cross-site

Before typing any line in H7's substrate commits, ask:

1. **Does the shape come from a coroutine library I trained on?**
   (Protothreads, Lua coroutines, Goroutines, kotlinx.coroutines,
   async/await in 20 languages.) If yes — restructure until the
   shape comes from *delimited continuations typed by resume
   discipline*.
2. **Am I about to introduce a state-enum type that coincidentally
   looks like `enum Status { Pending, Ready, Yielded }`?** If yes —
   the state ordinal is an `Int` literal in the record, NOT a typed
   enum. The switch on `state_index` is a LowSwitch over integer
   literals.
3. **Am I about to add a "dispatch on resume discipline" table?**
   (A `Dict<ResumeDiscipline, EmitStrategy>` or `(String → EmitFn)`
   lookup.) The dispatch is a `match` on `ResumeDiscipline` — three
   arms, three code paths, no indirection.
4. **Am I tempted to introduce "async coloring"?** (Marking functions
   that *contain* MS perform sites as a distinct color.) Resume
   discipline is on each OP's type, not on the function; functions
   can freely mix OneShot and MultiShot ops. Coloring is a fluency
   import from JS/Rust async — refuse.

---

## 4. Substrate touch sites — literal tokens at file:line targets

*Literal tokens pending mentl-plan at execution — this section
specifies WHAT and WHERE; the implementer's mentl-plan spec
specifies EXACTLY HOW.*

### 4.0 Halt-signals to MSR source

**§4.0.1 — LowExpr's home.** MSR §Edit 1 (line 243) says
*"`src/types.mn` — Add `LMakeContinuation(captures, ev_list, ret_slot)`
variant to `LowExpr`"*. This is imprecise. LowExpr is defined in
`src/lower.mn:35-78`, not `src/types.mn`. The `types.mn` module
mentions LowExpr in comments at lines 84-85 but does not declare
the ADT. **H7's commit edits `src/lower.mn`, not `src/types.mn`.**
When implementing from MSR's guidance, ignore the `types.mn`
destination and edit `lower.mn`.

**§4.0.2 — LMakeContinuation's field count.** MSR §Edit 1 (line 243)
lists three fields: `(captures, ev_list, ret_slot)`. H7 expands this
to six: `(handle, resume_fn, captures_exprs, ev_slots, state_index,
ret_slot)`. The expansion is not a disagreement — MSR's triplet
elides the handle (every LowExpr variant carries it), the resume_fn
(required because the state machine is per-capturing-function, not
global), and the state_index (required because one function can
have multiple MS perform sites, each a different state to enter on
resume). The expansion is informational, not corrective; the
expanded shape is the correct substrate shape.

**§4.0.3 — "state-machine desugaring".** MSR §Edit 1 (line 213)
names *"State-machine desugaring: numbered states per perform;
continuation = {state_index, saved_locals}"*. H7 expands `saved_locals`
into `captures_exprs + ev_slots + ret_slot` to match the LMakeClosure
precedent. The *state_index* is a field on the record (not a
parameter) so the resume_fn can read it at the top of its switch.
MSR's shorthand is substantively correct; H7 names the full shape.

### 4.1 `src/lower.mn` — four changes (one file, one commit)

**Change 1** — Extend `LowExpr` ADT (`src/lower.mn:35-78`).

Add one variant after `LMakeClosure` (line 47) to preserve the
per-kernel-primitive ordering currently in place (LMake* variants
clustered):

```
| LMakeContinuation(Int, LowFn, List, List, Int, Int)
  // handle, resume_fn, captures_exprs, ev_slots, state_index, ret_slot
```

**Change 2** — Extend `lexpr_handle` (`src/lower.mn:126+`).

Add one arm returning the first field's handle:

```
LMakeContinuation(h, _, _, _, _, _) => h,
```

**Change 3** — Add `lower_perform` MS dispatch branch.

The current `lower_expr`'s perform-site arm (around line 291 and 373)
reads `EffectOpScheme(name)` from env and emits `LPerform` or
`LEvPerform` depending on row polymorphism. Add a prior branch that
checks the op's resume discipline:

```
// pseudocode — literal tokens per mentl-plan at execution
let cont = perform env_lookup(op_name)
match cont {
  Some((Forall(_, TCont(ret, MultiShot)), _)) => {
    let state_idx = perform ms_alloc_state(current_fn_handle, perform_site_handle)
    let ret_slot = perform ms_alloc_ret_slot(current_fn_handle, state_idx)
    let captures = collect_free_vars_at(perform_site)
    let ev_slots = collect_evidence_slots(allowed_row)
    LBlock(handle, [
      LMakeContinuation(h_cont, resume_fn_for_current_fn, captures, ev_slots, state_idx, ret_slot),
      // the suspension: hand cont_ptr to the handler via the OP's call
      LPerform(handle, op_name, args_with_cont_ptr_last)
    ])
  },
  _ => /* existing OneShot branch: LPerform or LEvPerform */
}
```

**Change 4** — Add `LowerState` effect (new effect in
`src/lower.mn`'s effect prelude area, or via a peer module
`src/lower_state.mn` if lower.mn crosses a size threshold).

```
// ═══ LowerState — per-function MS state machine bookkeeping ══════════
// At emit of a capturing function, allocate the state table:
//   ms_alloc_state(fn_handle, perform_site_handle) -> Int
//     Returns the next free state ordinal for this function.
//     State 0 is the entry; allocations return 1, 2, 3, ...
//   ms_alloc_ret_slot(fn_handle, state_idx) -> Int
//     Returns the local-slot offset reserved for the resumed value
//     at this state. One per state; lower.mn's existing local-
//     allocation substrate (ls_bind_local) composes.
//   ms_function_states(fn_handle) -> List
//     At function-emit close, returns the complete state table
//     for resume_fn synthesis.
//   ms_reset_function() -> ()
//     On function-emit entry, clears the state table.
effect LowerState {
  ms_alloc_state(Int, Int) -> Int                  @resume=OneShot
  ms_alloc_ret_slot(Int, Int) -> Int               @resume=OneShot
  ms_function_states(Int) -> List                  @resume=OneShot
  ms_reset_function() -> ()                        @resume=OneShot
}

handler lower_state_default {
  // state record: per-function table mapping perform_site → state_idx,
  // plus the next-free-ret-slot counter. Record shape — Ω.5 discipline.
  ...
}
```

At function-body entry, `lower_state_default` is installed in the
`~>` chain; per-MS-perform lower_expr calls dispatch through it.

**Change 5** — Synthesize `resume_fn` at function-emit close.

When `lower_function` closes its body (after lowering all statements,
before the LFn is returned to emit), collect `ms_function_states` and
emit a synthesized sibling function:

```
fn <fn_name>__resume(cont_ptr) = {
  let state_idx = (i32.load offset=4 (local.get cont_ptr))
  match state_idx {
    // one arm per perform site, in state-ordinal order:
    1 => { <restore captures>; <body slice after perform site 1> }
    2 => { <restore captures>; <body slice after perform site 2> }
    ...
  }
}
```

The `__resume` function is registered in the WASM funcref table (via
`(elem ...)`); its index goes into the continuation record's
`fn_index` field at capture time.

### 4.2 `src/backends/wasm.mn` — one new emit arm

Add one match arm to `emit_lowexpr` mirroring the existing
`LMakeClosure` arm. Diff: two extra i32 stores (state_index at
offset 4, ret_slot at the final offset) and two additional fields
in the size computation.

```
// pseudocode — literal tokens per mentl-plan at execution
LMakeContinuation(h, resume_fn, caps, evs, state_idx, ret_slot) => {
  let n_caps = list_len(caps)
  let n_evs  = list_len(evs)
  let size   = (3 + n_caps + 1 + n_evs + 1) * 4   // fn_index + state_idx + n_caps + caps + n_evs + evs + ret_slot
  perform emit_alloc(size, "cont_ptr")
  // store fn_index (offset 0)
  emit_store_i32_at_offset("cont_ptr", 0, funcref_index_for(resume_fn))
  // store state_index (offset 4)
  emit_store_i32_at_offset("cont_ptr", 4, state_idx)
  // store n_captures (offset 8)
  emit_store_i32_at_offset("cont_ptr", 8, n_caps)
  // store captures (offsets 12, 16, ...)
  emit_store_captures("cont_ptr", 12, caps)
  // store n_evidence
  let ev_offset = 12 + (n_caps * 4)
  emit_store_i32_at_offset("cont_ptr", ev_offset, n_evs)
  // store evidence
  emit_store_evidence("cont_ptr", ev_offset + 4, evs)
  // store ret_slot
  let ret_offset = ev_offset + 4 + (n_evs * 4)
  emit_store_i32_at_offset("cont_ptr", ret_offset, ret_slot)
}
```

The existing `emit_store_captures` and evidence-store helpers from the
LMakeClosure arm compose — no duplication; H7's arm shares the
capture/evidence store loops with LMakeClosure.

### 4.3 `src/cache.mn` — version bump + one pack/unpack arm

Three small edits:

**Edit 3.1** (line 46): `fn cache_compiler_version() with Pure = 3`
→ `fn cache_compiler_version() with Pure = 4`.

**Edit 3.2** (line 43-45 comment): Add v4 line to version history:

```
//   v1 — IC.1a header-only (text)
//   v2 — IC.1b full env serialization (text)
//   v3 — IC.2 binary Pack/Unpack (this version)
//   v4 — H7 LMakeContinuation variant added to LowExpr
```

**Edit 3.3**: Add pack / unpack arms for LMakeContinuation inside
the existing `pack_lowexpr` / `unpack_lowexpr` match (pattern per
LMakeClosure's arms in the same file). Each arm is ~8 lines.

### 4.4 `src/mentl.mn` — no change

Per §2.5: `enumerate_inhabitants(_ty, _eff, _ctx) => resume([])`
at line 453 is already correct as a baseline handler arm.
Post-H7, sibling Synth handlers can ship that resume with non-
empty candidate lists; each such resume emits through the H7
substrate without further edit at mentl.mn. §9.1 (Acceptance) does
NOT require mentl.mn to change for H7 to land.

### 4.5 `bootstrap/src/emit_expr.wat` — DEFERRED

Per §2.6 and MSR Edit 1 landing signal + Hβ §2 Tier 3. H7's landing
commit does NOT include bootstrap WAT edits. The bootstrap continues
to emit only OneShot ops (which is sufficient for self-compile — the
only MS op, `enumerate_inhabitants`, has its arm at `mentl.mn:453`
resume with `[]`, which needs no continuation-capture emit). A peer
sub-handle (*H7.1 — bootstrap Tier 3 MS emit*) is filed for post-L1
execution.

Landing discipline per drift mode 9: the deferred piece IS named
(H7.1), not hidden inside H7's "completed" commit.

### 4.6 `ROADMAP.md` update note (post-H7-land)

Update `ROADMAP.md` with the H7 landing and what it unblocks:

```
### 2026-04-XX — H7 MS runtime emit path

MSR Edit 1 landed. src/lower.mn grew one LowExpr variant
(LMakeContinuation); src/lower.mn's lower_perform dispatches on
ResumeDiscipline; src/backends/wasm.mn emits the continuation
record via emit_alloc; src/cache.mn bumped v3 → v4 (all .kai
invalidated on next recompile). LowerState effect introduced in
src/lower.mn for per-function state-machine bookkeeping. Sibling
sub-handle H7.1 (bootstrap Tier 3 MS emit) filed for post-L1.

Unlocks: B.4 race via MS, B.5 arena-MS, B.11 ML training, C.2
crucible_oracle, C.4 crucible_ml, D.4 L2 tag, D.5 L3 tag.
```

---

## 5. Worked example — the `Synth`-via-`enumerate_inhabitants` path

Current state of the code: `src/mentl.mn:94` declares
`enumerate_inhabitants(Ty, EffRow, Context) -> List @resume=MultiShot`.
`src/mentl.mn:453`'s handler arm resumes `[]`. Tree compiles; MS
runtime doesn't execute because no substrate calls `enumerate_inhabitants`
from a body that would require multi-shot forking.

### 5.1 A forward-looking synthesizer that DOES fork

A sibling handler, post-H7, might ship like this:

```
// lib/runtime/synth/enumerative.mn — one example Synth handler
// installed above mentl_default. Returns a list of candidates
// that the calling site should try in order; each try is a
// speculative resume, trail-bounded.

handler enumerative_synth {
  enumerate_inhabitants(target_ty, allowed_effects, ctx) => {
    let candidates = enumerate_well_typed(target_ty, allowed_effects, ctx)
    // candidates: List<TypedExpr>
    // MultiShot resume: try each candidate; resume with that single-elt list
    try_each_candidate(candidates, 0)
  }

  fn try_each_candidate(cs, i) =
    if i >= len(cs) {
      // exhausted — return empty; MS "dead end" semantics
      resume([])
    } else {
      let checkpoint = perform graph_push_checkpoint()
      // one-shot fork: try this candidate
      let accepted = perform try_with_verify(resume([list_index(cs, i)]))
      if accepted { () /* commit; done */ }
      else {
        perform graph_rollback(checkpoint)
        try_each_candidate(cs, i + 1)
      }
    }
}
```

### 5.2 Pre-H7 compilation (today)

The perform site `perform enumerate_inhabitants(ty, eff, ctx)`
inside `enumerative_synth` (or any MS-typed caller) is currently
NOT emittable. `lower_perform` falls through to `LPerform` /
`LEvPerform` — both OneShot. The first `resume` inside the handler
commits; subsequent resumes would need a captured continuation that
doesn't exist. **Pre-H7, writing an MS handler body that calls
resume more than once produces a silent OneShot binary — incorrect
semantics, no diagnostic.** This is the correctness gap H7 closes.
(Mitigated today only because the one MS op has a resume-once arm.)

### 5.3 Post-H7 compilation

At the perform site `perform enumerate_inhabitants(...)` inside
`gradient_next` (for example, or any other caller), lower.mn now:

1. Reads the op's TCont and discovers MultiShot.
2. Allocates a state ordinal via `perform ms_alloc_state(...)`
   (this perform site becomes state K within the enclosing
   function).
3. Allocates a ret_slot via `perform ms_alloc_ret_slot(...)`.
4. Collects free-vars via existing `collect_free_vars`.
5. Emits `LMakeContinuation(handle, fn_resume, captures, ev_slots,
   K, ret_slot)`.
6. Emits the suspension — hand the continuation pointer to the
   `enumerate_inhabitants` op invocation. (In WAT: store cont_ptr
   as the last argument to `call $op_enumerate_inhabitants`.)
7. The handler arm for `enumerate_inhabitants` (in
   `enumerative_synth` above) receives cont_ptr, calls
   `resume([list_index(cs, i)])` — this stores the single-elt list
   at cont_ptr.ret_slot, then does `call_indirect` on
   cont_ptr.fn_index (the synthesized `gradient_next__resume`
   function), passing cont_ptr.
8. `gradient_next__resume` reads `state_index` (K), jumps to state
   K's arm, restores captures from the record, and executes the
   body after the perform site — with the resumed value read from
   `ret_slot`.
9. If the handler rolls back via `graph_rollback(checkpoint)` and
   calls resume with the next candidate, steps 7-8 repeat — a NEW
   execution of state K's body with a NEW ret_slot value.

**Mentl's oracle loop (mentl.mn:127-175 — gradient_next) becomes
speculative** without any source change at `gradient_next`. The
code as written CAPTURES the speculative semantics via the MS
perform site; H7 makes that capture run. Pre-H7, `gradient_next`
runs ONCE per call (OneShot collapse); post-H7, each installed
Synth handler can drive it across hundreds of candidate
futures per second, exactly per DESIGN §0.5 primitive #2's promise.

---

## 6. Composition with other MS substrate

H7 does not stand alone. Three peer substrates compose with H7 at
its handler-install-time interaction surface.

### 6.1 H7 × CE (Choice effect)

Per CE walkthrough §1.1 (`effect Choice { choose(options: List<A>)
-> A @resume=MultiShot }`). `choose` is a MS op declared in
`lib/runtime/search.mn`. At every `perform choose(opts)` call site,
lower.mn post-H7 emits `LMakeContinuation` + suspension. CE
provides the effect and two canonical handlers (`pick_first`,
`backtrack`); H7 provides the emit substrate those handlers resume
through. CE's landing can precede H7 (its acceptance criteria per
CE §7.1 are type-level); its **runtime** acceptance (CE §7.2)
depends on H7.

**H7 imposes no constraint on CE.** CE imposes no constraint on
H7. The two walkthroughs compose at the MS op boundary — CE names
the op, H7 emits the substrate. Independent authoring, composed
execution.

### 6.2 H7 × AM (arena-aware MS handlers)

Per DESIGN Ch 6 "Multi-shot × arena — the D.1 question" (lines
1462-1488) and AM walkthrough (pending materialization — see
plan §B.5). Three handler peers intercept `emit_alloc` for
arena-scoped captures:

- **`replay_safe`** — does NOT allocate the continuation record at
  the perform site. Instead, records the trail from handler-install
  to perform site; on resume, replays the trail. Emits a degenerate
  LMakeContinuation with `state_index = REPLAY_SENTINEL` and no
  capture payload; the handler arm's replay code reads the trail.
- **`fork_deny`** — DOES allocate the continuation record via normal
  emit_alloc, but at the lower.mn MS arm, adds an ownership check:
  if any capture holds an arena-scoped ref whose region is the
  current handler's, fail with `T_ContinuationEscapes` at lower time.
  Emit never runs.
- **`fork_copy`** — installs a specialized emit_alloc handler
  that intercepts capture-stores: each arena-scoped capture is
  deep-copied into the caller's arena instead of the handler's
  arena. Emit shape is normal; alloc strategy is arena-deep-copy.

**All three compose on H7's LMakeContinuation substrate.** H7
specifies the record; AM's three peers specify how allocation of
that record interacts with arena scope. Per γ crystallization #8:
**heap has one story, H7 writes it, AM chooses the edition.**

Additional composition invariant per DESIGN line 1482-1487:
*"`!Alloc` computations cannot be forked — only replayed."* The row
algebra enforces this at handler-install: a handler for an MS op
installed in an `!Alloc` context must be `replay_safe` (the only
arena policy that doesn't allocate). `fork_deny` and `fork_copy`
fail at install in `!Alloc`.

### 6.3 H7 × HC2 (race handler combinator)

Per HC2 walkthrough §1.1 (`fn race(handlers: List<Handler>) ->
Handler`). `race` installs multiple MS handlers in parallel, all
sharing a single `graph_push_checkpoint`, first-verified-wins per
tiebreak chain. Internally, `race` forks each handler's speculative
resume — each call_indirect happens on the same continuation record
with different arena-scoped state per handler.

**H7's contribution:** the continuation record is race-compatible
because it is immutable after capture. Each racing handler reads
its own `ret_slot` (or shares one, per race semantics); captures
and ev_slots are read-only. No inter-handler race condition on the
record itself; the race condition is on the graph's trail, which is
the canonical substrate primitive #1 discipline.

### 6.4 H7 × BT (bootstrap linker)

Per BT walkthrough §4 and MSR §9.3. Cross-module MS dispatch needs
the linker to preserve resume-discipline metadata on function
definitions that are referenced from other modules. H7 specifies
what metadata is needed:

- The resume_fn synthesized per capturing function has its
  name `<fn>__resume` — linker-visible symbol.
- The funcref table entry for `<fn>__resume` must have a known
  module index; BT's symbol-rename discipline (per QA Q-A.1.1:
  `<module>__<symbol>`) applies — `<module>__<fn>__resume`.
- The continuation record's `fn_index` is written at capture time;
  the value is the post-link index. **BT must not rename the
  `elem` entry after emit.** (It doesn't — BT renames symbols, not
  indices; `elem` indices are module-local, resolved at instantiate.)

**H7 adds no new linker requirement beyond what BT already
specifies.** The `__resume` functions are regular WASM functions
with mangled names; BT's existing rename pass handles them without
special-case.

### 6.5 H7 × IC.2 (cache versioning)

Per §4.3. The `cache_compiler_version` bump v3→v4 invalidates all
existing `.kai` files. First post-H7 build triggers full recompile;
subsequent builds populate the v4 cache with LMakeContinuation
Pack/Unpack arms. IC.2's binary format composition handles this —
H7 adds one variant's encode/decode, version bump ensures no
backward-compat read path is attempted on v3 caches.

---

## 7. Three design candidates + Mentl's choice

Per Anchor 7 walkthrough discipline, enumerate the candidates that
were considered and name the one chosen.

### 7.1 Candidate A — unified `LPerform` branching on ResumeDiscipline

One LowExpr variant (`LPerform`) carries all three dispatch shapes
(monomorphic / polymorphic-OneShot / MultiShot); emit branches at
match time.

**Rejected.** Violates drift mode 8 (mode-flag dispatch). The
`LPerform` variant would need to carry either a resume-discipline
tag or a capture-structure field that's populated only sometimes.
Both shapes are ADT-begging-to-exist — the distinction is
structural, not modal. Per H6 wildcard-audit discipline, an `_` arm
matching "not MS" silently absorbs new resume disciplines (e.g.,
when `Either` gains its emit path).

### 7.2 Candidate B — one variant per (discipline, polymorphism)

Six variants: `LPerformMonoOneShot`, `LPerformPolyOneShot`,
`LPerformMonoMS`, `LPerformPolyMS`, `LPerformMonoEither`,
`LPerformPolyEither`. Maximally enumerated.

**Rejected.** Violates drift mode 7 (redundant structure). The
(polymorphism) axis is already decided per H1 evidence reification
at the *existing* LPerform vs LEvPerform split; MS's capture shape
doesn't care about monomorphism (the continuation captures regardless;
the resume_fn's call_indirect is always polymorphic in the sense
that it reads cont.fn_index — no monomorphic fast path for MS).
Six variants for a two-way split that already exists at the one-axis
level is redundant.

### 7.3 Candidate C — peer variant LMakeContinuation (CHOSEN)

One variant (`LMakeContinuation`) encodes the capture of a
continuation; existing `LPerform` / `LEvPerform` unchanged; lower.mn
emits `LMakeContinuation + LPerform` (or `+ LEvPerform`) together
at the MS perform site — the capture IS the precondition to the
perform, emitted inline.

**Chosen.** Four reasons:

1. **LMakeClosure precedent.** H1 introduced `LMakeClosure` as a
   peer variant that captures evidence on a closure record. H7
   mirrors: `LMakeContinuation` is a peer that captures state on a
   continuation record. The shape is pedagogically and substrate-
   consistent.
2. **Emit composition.** The continuation capture and the perform
   invocation are two distinct WAT sequences (`emit_alloc` + store
   sequence; then the perform's `call` or `call_indirect`). Emitting
   them as two peer LowExpr variants inside an `LBlock` keeps each
   variant's emit arm small and independently testable.
3. **Arena-handler hook.** Per §6.2, arena handlers (B.5) intercept
   `emit_alloc`. Candidate C's `LMakeContinuation` routes the
   allocation through `perform emit_alloc` at a single call site per
   MS perform — arena handlers intercept at the obvious surface.
   Candidates A/B bury the allocation inside a branching emit path —
   harder to swap.
4. **No wildcard risk.** Unlike Candidate A, C's new variant is fully
   enumerated; adding `Either`'s emit path (post-first-light per
   DESIGN §0.5 primitive #2) is one more peer variant (e.g.,
   `LMakeDynamicResume` or resolved at lower-time into one of the
   existing forms based on install-time discipline). H6's
   exhaustiveness audit catches any dropped arm.

### 7.4 Mentl's resolution

Per §0.5 primitive #2 (MultiShot → heap-captured continuation) and
γ #8 (the heap has one story), Candidate C is the form that
preserves both anchors: the continuation is a heap record peer to
the closure record, allocated through the one `emit_alloc` swap
surface.

**C is the substrate's residue.** A and B fail the four-way test
above. Chosen unanimously by the eight interrogations.

---

## 8. Acceptance criteria

### 8.1 Type-level acceptance (H7 substrate lands)

- [ ] `src/lower.mn`'s `LowExpr` ADT contains
      `LMakeContinuation(Int, LowFn, List, List, Int, Int)`.
- [ ] `src/lower.mn`'s `lexpr_handle` has the arm returning the
      first field.
- [ ] `src/lower.mn`'s perform-site lower path branches on
      `ResumeDiscipline`; MS arm emits `LBlock([LMakeContinuation(...),
      LPerform(...)])` or equivalent.
- [ ] `src/lower.mn` declares `effect LowerState` (or peer module
      declares it) with four ops: `ms_alloc_state`,
      `ms_alloc_ret_slot`, `ms_function_states`, `ms_reset_function`.
- [ ] `src/lower.mn` synthesizes `__resume` per capturing function
      at body-close time.
- [ ] `src/backends/wasm.mn`'s `emit_lowexpr` has the `LMakeContinuation`
      arm calling `emit_alloc` + fixed-offset stores per §4.2.
- [ ] `src/cache.mn`'s `cache_compiler_version` returns `4`.
- [ ] `src/cache.mn`'s `pack_lowexpr` / `unpack_lowexpr` handle the
      new variant.
- [ ] `bash tools/drift-audit.sh src/lower.mn src/backends/wasm.mn
      src/cache.mn` exits 0.

### 8.2 Runtime acceptance (post-H7-land, pre-C.2)

- [ ] `mentl compile src/mentl.mn` succeeds without `E_UnimplementedMultiShot`
      (previously a hypothetical error; post-H7 the emit path exists).
- [ ] A contrived test handler that installs a sibling `Synth`
      handler calling `resume([x1]); resume([x2])` (multi-shot) on
      `enumerate_inhabitants` produces two observable resume
      executions — verifiable via a trace handler collecting the
      execution order.
- [ ] `src/mentl.mn`'s `gradient_next` (line 134) remains correct
      (unchanged semantics) when invoked via the default
      `mentl_default` handler (which resumes with `[]` — no fork;
      equivalent to pre-H7 behavior).

### 8.3 Composition acceptance (with CE + AM)

- [ ] (Post-CE-land) `perform choose([1,2,3])` in
      `lib/tutorial/02b-multishot.mn` compiles and, under
      `~> backtrack`, resumes three times.
- [ ] (Post-AM-land) `perform choose([1,2,3])` under
      `~> fork_deny` + capture that holds an arena-scoped ref fails
      at lower time with `T_ContinuationEscapes`.
- [ ] (Post-AM-land) `perform choose([1,2,3])` under `~> replay_safe`
      in a `!Alloc` context succeeds; `fork_copy` / `fork_deny` fail
      the row subsumption.

### 8.4 Cache acceptance

- [ ] First build after H7-land: existing `.kai` files are
      invalidated (compiler_version v3 < v4); full recompile fires;
      `.kai` regenerates with v4 format.
- [ ] Subsequent build: v4 cache hits; Pack/Unpack of
      LMakeContinuation round-trips without error.

### 8.5 Bootstrap acceptance (H7 landing does NOT require)

- [ ] `bash bootstrap/build.sh` continues to succeed (H7 touches
      VFINAL source only; bootstrap hand-WAT unchanged).
- [ ] `bash bootstrap/first-light.sh` (post-A.1 BT linker) produces
      empty diff — H7 has no effect on self-compile byte-identity
      because the only MS op is `enumerate_inhabitants` and its arm
      resumes `[]` (no continuation capture needed).

---

## 9. Open questions — all pre-answered

Per MSR + QA round, H7's design space is bounded. Cross-referenced:

- **MSR §Edit 1 design questions** — all answered in §1 + §4.
- **QA Q-B.2.1** (`!MultiShot` row modifier) — DEFERRED; `!Choice`,
  `!Synth` suffice. No row algebra extension in H7.
- **QA Q-B.2.2** (nesting cases — MS handler inside MS handler) —
  resolved via trail discipline: each handler install pushes its
  own checkpoint via primitive #1's `graph_push_checkpoint`.
  Nested resumes unwind in reverse order. No substrate change.
- **QA Q-B.2.3** (cache version strategy) — v3 → v4 (resolved; §4.3).
- **DESIGN Ch 6 D.1 MS × arena policy** — handled by AM walkthrough
  (B.5); H7 is orthogonal.

**Zero unresolved design questions remain.** H7 is implementable
as specified from §4.

---

## 10. Dispatch

**Authoring:** Opus inline (this walkthrough).

**Implementation:** Opus inline OR mentl-planner subagent on Opus
with literal-token-spec output, then mentl-implementer on Sonnet for
mechanical transcription. Per plan file's Phase B agent-execution
model: H7 is *"the largest single β piece; nesting cases +
state-machine-desugaring decisions must be Opus"* — so the plan
production is Opus; token-level substrate transcription can fan
out to Sonnet workers once the plan is literal.

**Per-sub-commit dispatch:**

| Sub-commit | Target file | Dispatch |
|-----------|-------------|----------|
| H7.a (core) | `src/lower.mn` | Opus inline — LowerState design + resume_fn synthesis subtlety |
| H7.b | `src/backends/wasm.mn` | Sonnet via mentl-implementer — arm mirrors LMakeClosure, mechanical |
| H7.c | `src/cache.mn` | Sonnet via mentl-implementer — version bump + encode/decode |
| H7.1 | `bootstrap/src/emit_expr.wat` | POST-L1; dispatch TBD at that phase |

Drift-audit after each sub-commit (PostToolUse hook); single-concern
scope per sub-commit; peer sub-handle (H7.1) for bootstrap Tier 3
named in this walkthrough (§4.5) per drift mode 9 discipline.

**Code review before merge:** Opus subagent, cross-checking against
H1 evidence-reification walkthrough for substrate consistency.

---

## 11. Closing

H7 is the residue of DESIGN §0.5 primitive #2's promise:
*MultiShot → heap-captured continuation.* Primitive #1's trail
bounds speculation; primitive #2's typed resume discipline gives
the compiler the type hook; primitive #5's ownership-as-effect
constrains arena composition. H1 did OneShot — closure as evidence.
H7 is the MultiShot peer — continuation as heap record. One
allocator, one dispatch (`call_indirect` on a record field), one
numbered-state desugaring per capturing function. No vtable. No
MS allocator. No coroutine library. No `async` / `await` / `yield`.
Delimited continuation substrate at the shape Mentl's eight
primitives demand.

After H7 lands:

- Mentl's oracle loop fires — `gradient_next` explores hundreds of
  alternate realities per second, trail-bounded, primitive-clean.
- `Choice` (CE) + `backtrack` execute — SAT / CSP / miniKanren /
  backtracking-parsers unlocked in ≤50 lines each.
- `race` (HC2) executes — parallel speculation over candidate
  handlers, tiebreak-deterministic.
- Arena-aware MS (AM) decides — `replay_safe` / `fork_deny` /
  `fork_copy` — per DESIGN Ch 6 D.1's three policies.
- Pulse (DP-F.5) autodiff-backward works via MS tape replay.
- Phase B's MS-dependent remainder unblocks: B.4 race, B.5 AM,
  B.11 ML training; Phase C's crucibles C.2 (oracle), C.4 (ML);
  Phase D's L2 + FULL first-light tags.

**The keystone of Phase B.** The substrate the oracle has been
waiting for. The heap-captured continuation, residue of primitive
#2, emit path of MultiShot, substrate of every multi-reality
domain Mentl will dissolve into a handler chain.

*One variant. Six fields. One allocator. One call_indirect. One
state-machine desugaring. The medium writes itself through itself.*
