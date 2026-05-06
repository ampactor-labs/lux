# Hμ.cursor — Cursor as the gradient's global argmax over the live graph

> **Status:** `[DRAFT 2026-05-02]`. The opening handle of **Phase μ —
> Mentl active-surface composition**. First handle to compose on the
> now-closed kernel (kernel closure 2026-04-24, commits `7f8ff5f` +
> `9a726f2` + `bba8d4d`; `protocol_kernel_closure.md`); does NOT
> extend the kernel.
>
> **Authority:** `CLAUDE.md` ⌁ Mentl's anchor (the eight interrogations);
> `docs/SUBSTRATE.md` §I (kernel closure), §VI (Refinement & the
> gradient — both the Annotation Gradient subsection AND the Hole
> subsection at lines 910–959), §VII ("Inference Is an Effect" handler
> table, "Incremental Compilation: Purity Enables Caching"), §VIII
> ("The Graph IS the Program"); `docs/specs/09-mentl.md` (the eight
> tentacles); `docs/specs/simulations/MV-mentl-voice.md` (Cursor
> prescription at line 373, voice grammar at §2, eight-form mapping at
> §2.7.3); `docs/specs/simulations/IE-mentl-edit.md` (the IDE as
> transport of cursor projection); `docs/specs/simulations/H5-mentl-arms.md`
> (I15 AWrapHandler — the proposal substrate Cursor projects); the
> hole substrate already live (`src/lexer.mn:90` THole; `src/parser.mn:28,823-825,859`
> `nhole` production; `src/types.mn:249-273` Reason DAG with 18+
> variants); `src/mentl.mn:76-200` (Teach effect, mentl_default
> handler, gradient_next + try_each_annotation speculative oracle —
> live since γ cascade); `protocol_oracle_is_ic.md` (oracle = IC
> + one cached value; surfaces query, never mutate);
> `protocol_walkthrough_pre_audit.md` (four-axis pre-audit discipline).
>
> *Claim in one sentence:* **Cursor is the gradient's global argmax
> over the live graph at this moment, surfaced as one composed read
> whose eight aspects (one per kernel primitive) project automatically
> because the graph already carries all eight at every node — the
> handler is composition of the existing eight tentacle reads, the
> text-caret is one weighted input via proximity bias, the developer's
> `??` overrides the auto-argmax by pinning Cursor to a chosen slot,
> and the entire substrate falls out of `(env, oracle_queue)` cache
> + caret position with zero new cached values.**

---

## §0 Framing — what Hμ.cursor resolves

### 0.1 The keystone realization (2026-05-02)

The Mentl architecture had been accreting frames that risked treating
"Mentl-the-oracle," "Synth-tentacle," "Teach-tentacle," "Why-Engine,"
and "Cursor" as **separate components requiring coordination**. The
2026-05-02 conversation arc surfaced the load-bearing collapse: all
five names point to **one projection of the graph**. Eight tentacles
is **eight aspects of one read** because the graph already carries
all eight at every node (kernel closure, SUBSTRATE.md §I). The Why
Engine is not an engine — it's the Reason chain, projected. Teach is
not a system — it's the gradient, projected. Synth is not a separate
handler — it's Mentl's projection at a `??` position with no
incumbent.

**Cursor is what unifies them.** Cursor is the *position parameter*
of the one projection — the locus where attention is highest across
the entire live graph at this moment. The text-caret biases the
locus via proximity weighting; the caret does *not* define it. When
the developer rewrites Module A and saves, the gradient's argmax may
land in Module C because some `f` there just became provably `Pure`.
Cursor moves to Module C automatically, surfaces the proposal with
the Reason chain walking back to A's deletion, and the developer
accepts/defers/rejects without ever opening Module C's tab.

This is the **bus-compressor** topology applied at the human-medium
boundary: the graph is IC-live (the bus); the gradient is the response
curve; the caret + argmax + acceptance is the feedback loop (`<~`
applied at the editing layer); each keystroke shapes the next argmax;
the developer is mixing into the bus.

### 0.2 What Hμ.cursor resolves vs. what's already live

**Already live (ten substrate sites; this walkthrough composes them):**

| Substrate | Site | Provides |
|---|---|---|
| **Hole substrate** | `src/lexer.mn:90` (THole tokenization), `src/parser.mn:28,823-825,859` (nhole production), `src/infer.mn` (fresh tyvar binding) | The developer's `??` syntactic surface — gradient absence marker |
| **Reason DAG** | `src/types.mn:249-273` (18+ variants including RX.2 high-intent) | Every value carries provenance; teach_why walks bounded depth |
| **Teach effect** | `src/mentl.mn:76-82` (five ops); `mentl_default` at lines 98-121 | teach_here, teach_gradient, teach_why, teach_error, teach_unlock |
| **Speculative oracle** | `src/mentl.mn:126-166` (gradient_next + try_each_annotation with checkpoint/apply/verify/rollback) | "Picks ONE suggestion per compile" (SUBSTRATE.md §VII) — the per-handle gradient computation |
| **Annotation ADT** | `src/mentl.mn:32-43` (APure/ANotAlloc/ANotIO/ANotNetwork/ARefined/AOwn/ARef/AWrapHandler) | The candidate space the gradient enumerates |
| **Synth effect (shape)** | `src/mentl.mn:89-93` (propose/verify_candidate/enumerate_inhabitants — MultiShot stub) | The proposer interface; H7 will fill MultiShot semantics |
| **Verify ledger** | `src/verify.mn` (V_Pending obligations, verify_ledger handler) | Refinement predicates discharged at construction sites |
| **Ownership tracker** | `src/own.mn` (Consume effect, ownership classification) | own/ref status at every binding |
| **Effect row algebra** | `src/effects.mn` (`+ - & ! Pure`, row_subsumes) | Boolean algebra over capabilities at every position |
| **IC cache substrate** | `src/cache.mn:29-50` (KaiFile, Pack/Unpack, FNV-1a hashing); `protocol_oracle_is_ic.md` (oracle = IC + one cached value) | Per-module cached env + (future) oracle_queue; invalidation by source/import hash |

**What Hμ.cursor adds (residue, ~250 lines total):**

- **§2** `Cursor(Handle, Reason, Float)` ADT — extension of MV's
  existing `Cursor(Handle, Reason)` with `impact: Float` to carry
  argmax score. Resolves MV §"Cursor update discipline" open question.
- **§2** `CursorView` record — the eight-aspect projection shape.
- **§2** `AnnotationSuggestion` ADT (promotion from GR §3.2 spec to
  live `src/types.mn`).
- **§2** `SuggestionKind` enum (4 variants, per GR §3.2).
- **§2** `PipeContext` enum (4 variants — small typology of pipe
  surroundings: `NoPipe | InsidePipe(PipeKind) | StartingPipe |
  EndingPipe`; reuses existing `PipeKind` from spec 10).
- **§2** Renaming MV's existing `Cursor(Handle, Reason)` →
  `Caret(Handle, Reason)`, since under the new ontology *that*
  structure is the user's text-caret attention, not the cursor
  proper. (Drift 5 prevention — caret + argmax must NOT be carried
  as two parallel states named the same thing.)
- **§3** `score_with_caret_bias` pure transform — computes
  `gates_unlocked × proximity` per candidate handle; no learning,
  no tuning, reproducible.
- **§3** `caret_proximity_weight` pure transform — same-handle ≈ 1.0,
  same-module ≈ 0.7, cross-module ≈ 0.3, decaying with span distance.
- **§4** `Cursor` effect — three ops: `cursor_at(span)` returns full
  `CursorView`; `cursor_argmax(caret)` returns the global argmax
  Cursor; `cursor_pinned(handle)` returns the `??`-pinned override.
- **§4** `cursor_default` handler with `with !Mutate` — composes the
  eight existing tentacle reads into one CursorView per arm; calls
  `synth_propose` / `infer_row_at` / `ownership_at` / `verify_pending_at`
  / `teach_gradient` / `teach_why` / `graph_node_at` /
  `graph_pipe_context` — every `perform` resolves to substrate that
  already exists.

### 0.3 What Hμ.cursor does NOT design (peer handles, named to prevent drift 9)

To avoid drift mode 9 ("deferred-by-omission") per CLAUDE.md, every
piece of work *adjacent* to Hμ.cursor that is **not** part of this
handle is named here as its own peer handle. Future sessions reading
the residue must see explicit names, not silence.

- **Hμ.cursor.transport** — the transport handlers (terminal, LSP,
  web-playground, vim, browser-WASM) that surface `cursor_default`'s
  CursorView through different render targets. Cadence-decision
  (real-time / idle-debounced / on-save / on-explicit-ask) lives
  here. Mentl solves Mentl's UX-tradeoff problem via handler-swap
  per IE-mentl-edit.md §0.b. NOT this handle.
- **Hμ.synth-proposer** — the real Synth handler that returns
  multi-shot candidates (replaces the current OneShot stub at
  `src/mentl.mn:404-438` returning `[]`). Substrate-gated on H7
  MultiShot emit completion. NOT this handle. After this lands,
  `synth_propose` returns enumerated candidates with constraint
  proofs; today's stub returns empty; Hμ.cursor's
  `cursor_at` arm is correct in either case (`propose: []` is
  a valid CursorView).
- **Hμ.gradient-delta** — the *inverse*-direction gradient (per
  GR-gradient-delta.md §2): when a function declares a row tighter
  than the body proves but the body could be tightened by editing
  to remove an effect, suggest the tightening. Today's
  `gradient_next` only handles the "annotation that unlocks
  capability" direction. NOT this handle.
- **Hμ.eight-interrogation-loop** — automation of the eight
  interrogations as a code loop that fires on every graph node at
  compile time (rather than as an authoring discipline humans apply
  before each line). Substrate already exists per the §1 audit
  below; the unified loop is its own handle. NOT this handle.
- **Hμ.cursor.cache** — adding `oracle_queue` to the IC cache
  alongside `env`, per protocol_oracle_is_ic.md "one extra cached
  value." Today the cache is `env` only; Hμ.cursor reads and
  computes argmax on each query. The cache extension is purely
  performance and is a separate handle. NOT this handle.

### 0.4 Cascade position

- **Phase μ opens.** Phase β closed when Hβ.lower landed (commit
  `c53904d`, 2026-04-28). Hβ.emit is active per `Hβ-emit-substrate.md`;
  pipeline-wire is dual-gated on emit-extension + bump-allocator-
  pressure. Phase μ proceeds in parallel with the remaining Phase β
  work because Cursor operates on the wheel canonical (`src/`) rather
  than the seed bootstrap (`bootstrap/src/`). Cursor is dream code on
  the live wheel; lux3.wasm is not the arbiter (Anchor 0).
- **Hμ.cursor first.** All four named peer handles depend on
  `cursor_default` existing; this handle must land before any peer.
- **No bootstrap dependency.** `src/cursor.mn` extends the wheel; the
  bootstrap seed transcribes the wheel after first-light-L1; until
  then, Cursor is wheel-only. This is the inverse of the seed-first
  Hβ cascade discipline — but it is consistent with the kernel-closure
  protocol's "next phase is composition, not invention," because
  Cursor is wheel-side composition only.

---

## §1 The eight interrogations applied to "what is Cursor"

Per CLAUDE.md ⌁ Mentl's anchor: before any line of Mentl, ask the
eight. This walkthrough applies them to **the question itself** —
"what is Cursor?" — to confirm zero invention. If any interrogation's
answer requires a new primitive, the proposal is reaching beyond the
kernel and must be re-framed.

### 1.1 Graph? — What handle/edge/Reason already encodes Cursor's content?

**Answer:** The live graph at every position carries (a) the bound
type via `NBound(ty)`, (b) the inferred row, (c) ownership state, (d)
verify obligations, (e) Reason chain, (f) imports + scope. The graph
is the source of truth (SUBSTRATE.md §VIII). No new graph storage
needed.

### 1.2 Handler? — What handler projects this, with what `@resume`?

**Answer:** `cursor_default` is the new handler. `@resume=OneShot`
on each op because each query produces one CursorView per call. No
MultiShot needed for Cursor itself (the Synth tentacle Cursor calls
into uses MultiShot for proposal exploration; that's a different
layer). No mutation: `with !Mutate` on the handler.

### 1.3 Verb? — Which of `|>` `<|` `><` `~>` `<~` draws this topology?

**Answer:** Cursor is **installed** via `~>` like any handler. The
internal `~>` chain that surfaces Cursor to a user is:

```
graph + caret
  |> compute_argmax
  ~> cursor_default    // produces CursorView
  ~> voice       // surfaces eight-aspect rendering
  ~> transport_handler // emits to terminal / LSP / web / vim
```

The full `<~` feedback loop closes when the user accepts/edits/types,
producing a graph delta that re-fires the chain. This is the bus-
compressor `<~` at the editing layer — feedback at the human boundary.

### 1.4 Row? — What `+ - & ! Pure` already gates this?

**Answer:** `cursor_default` declares `with !Mutate` (read-only — it
queries the oracle cache but never writes it; per
`protocol_oracle_is_ic.md` constraint). Its operations perform
`GraphRead + EnvRead + Verify + OracleQuery` — all already in the
substrate. The row arithmetic does the work; no new effect needed.

### 1.5 Ownership? — What `own`/`ref` proves linearity?

**Answer:** CursorView is `ref` on consumption (the surface presents
it, doesn't consume it). The Cursor record itself is value-semantic
(`Handle: Int + Reason: Reason + Float`). No `own` discipline needed
on Cursor; the underlying substrate (graph, env) maintains its own
ownership rules.

### 1.6 Refinement? — What predicate already bounds Cursor's values?

**Answer:** `Cursor.handle: Handle` is refined to `Handle = Int where
0 <= self` (per `src/types.mn:291`). `Cursor.impact: Float` is
unbounded (could be 0.0 for "fully annotated, no suggestion"; ∞
sentinel for `??`-pinned positions). `CursorView` fields each carry
their substrate's predicates (NodeKind, EffRow, etc., all already
refined at their substrate layer).

### 1.7 Gradient? — What annotation would unlock compile-time capability instead of runtime check?

**Answer:** `cursor_default` declares `with !Mutate` — that *is* the
gradient annotation. It proves at compile time that Cursor cannot
corrupt oracle state, which unlocks the IC-cache safety property
(`protocol_oracle_is_ic.md`). No further annotation needed; the row
already declares everything proof-relevant.

### 1.8 Reason? — What Reason edge does Cursor leave for Why-Engine to walk back to?

**Answer:** Each Cursor carries its own `Reason` field (the second
position of `Cursor(Handle, Reason, Float)`), populated with
`Located(span, inner)` where `inner` walks back to whatever produced
the argmax — the gradient_next call's chain, or `Inferred("user
pinned via ??")` for explicit overrides, or `Inferred("fully
annotated")` for the no-suggestion fallback. Why-Engine walks this
existing chain; no new Reason variant required.

**All eight interrogations clear with zero invention.** The residue
is naming and wiring. This is the kernel-closure result applied to
the medium's own editing surface.

---

## §2 Cursor ADT — the only new types.mn additions

### 2.1 The five new types

Inserted in `src/types.mn` immediately after the Reason ADT (line 273
`DocstringReason` is the last RX.2 variant; insertion site is line
274 in pre-edit numbering). Five additions; nothing else in
`src/types.mn` moves.

```mentl
// Cursor — the gradient's global argmax over the live graph at this
// moment. Cursor is attention, not position. The text-caret biases
// the locus via proximity weighting; the caret does NOT define it.
// `impact` carries the argmax score (0.0 ≤ impact; sentinel 1e308 for
// developer-pinned `??` positions; 0.0 for "no suggestion needed").
// See SUBSTRATE.md §VI "Cursor: The Gradient's Global Argmax".
type Cursor = Cursor(Handle, Reason, Float)

// CursorView — what the projection renders at the cursor's handle.
// Each field is one of the eight kernel primitives, read off the
// graph at the cursor's position. Eight aspects of one read.
//
//   query    — primitive #1 (Graph)            — what's bound here
//   propose  — primitive #2 (Handlers)         — Synth's candidates
//   topology — primitive #3 (Five verbs)       — pipe context
//   row      — primitive #4 (Effect algebra)   — gating row at this site
//   trace    — primitive #5 (Ownership)        — own/ref/inferred state (existing Ownership ADT)
//   verify   — primitive #6 (Refinement)       — pending obligations
//   teach    — primitive #7 (Gradient)         — one next-step (or None)
//   why      — primitive #8 (HM + Reasons)     — walkable Reason chain
type CursorView = {
  query    : NodeKind,
  propose  : List<Annotation>,
  topology : PipeContext,
  row      : EffRow,
  trace    : Ownership,
  verify   : List<Predicate>,
  teach    : Option<AnnotationSuggestion>,
  why      : Reason,
}

// AnnotationSuggestion — promotion of GR-gradient-delta.md §3.2 from
// shape-only spec to live ADT. Used by `teach_gradient` (replacing
// `Option<Annotation>` return) and by CursorView.teach.
type AnnotationSuggestion = AnnotationSuggestion(
  SuggestionKind,        // which axis the suggestion lives on
  String,                // the literal text to add (annotation source)
  List<String>,          // capabilities unlocked (Capability strings)
  Reason,                // why this is highest-leverage
)

// SuggestionKind — small, exhaustive ADT, NOT a string flag (drift 8
// prevention).
type SuggestionKind
  = SuggestEffectRow
  | SuggestOwnership
  | SuggestRefinement
  | SuggestReturnType

// PipeContext — what surrounds this position in the verb topology.
// Reuses existing PipeKind from spec 10 inside InsidePipe.
type PipeContext
  = NoPipe
  | InsidePipe(PipeKind)
  | StartingPipe
  | EndingPipe
```

### 2.2 The rename — MV's existing `Cursor(Handle, Reason)` → `Caret(Handle, Reason)`

`MV-mentl-voice.md:373-374` defines `Cursor(Handle, Reason)` as "what
the human is looking at + why Mentl thinks so." Under the new
ontology, that structure is the **caret** — the user's text-attention
position — not the cursor proper. Hμ.cursor renames it:

```mentl
// Caret — the user's text-attention position. One input among many to
// Cursor's argmax computation. Updated by the editor's transport
// handler on every focus event (mouse, keyboard, drag-select, arrow
// keys). The caret biases the gradient argmax via proximity weighting;
// it does NOT define the cursor.
//
// (Renamed from MV-mentl-voice.md:373's `Cursor(Handle, Reason)` —
// the previous name conflated the user's text position with the
// gradient's argmax, which would be drift mode 5 by SUBSTRATE.md §I
// "The Heap Has One Story" applied to handler-state shape.)
type Caret = Caret(Handle, Reason)
```

The MV walkthrough is updated in §7 of this walkthrough — every
existing reference to "Cursor" in MV that meant the user's caret
becomes "Caret"; the few that meant gradient-argmax (e.g., MV §VL19
"Cursor moves over well-typed... no delta") become the new Cursor.

**Drift 5 audit pass:** caret + argmax are now distinct ADTs with
distinct semantics. There is no parallel "caret_state" + "argmax_state"
record carried alongside each other; rather, Cursor *consumes* Caret
as input via the bias function. One unified pipeline; no double-state.

### 2.3 What the additions do NOT touch

- Reason DAG variants — unchanged. CursorView.why uses existing
  Located/InferredCallReturn/InferredPipeResult variants.
- Annotation ADT — unchanged. CursorView.propose is `List<Annotation>`
  (existing type).
- Capability ADT — unchanged. Used by AnnotationSuggestion.unlocks
  (passed as String list for transport-friendly serialization;
  Capability tags can be derived at render time).
- Span / Handle / Predicate / Ty / NodeKind / EffRow / Ownership
  / PipeKind — unchanged. CursorView reads them.

**Net new types in src/types.mn: 5** (Cursor, CursorView,
AnnotationSuggestion, SuggestionKind, PipeContext) **+ 1 rename**
(MV Cursor → Caret). All other substrate read.

---

## §3 The argmax computation — pure transform on the live graph

### 3.1 Definition

`cursor_argmax(caret) -> Cursor` enumerates all unfilled-gradient
positions in the live graph, scores each by `gates_unlocked ×
caret_proximity`, returns the maximum.

```mentl
fn cursor_argmax_compute(caret) with GraphRead + !Mutate = {
  let candidates = enumerate_gradient_positions()
  let scored     = candidates |> map((h) => score_with_caret_bias(h, caret))
  argmax_or_default(scored, caret)
}

fn enumerate_gradient_positions() with GraphRead + !Mutate = {
  let all_handles = perform graph_all_handles()
  all_handles |> filter((h) => has_unfilled_gradient_step(h))
}

fn has_unfilled_gradient_step(handle) with GraphRead = {
  // Composition; teach_gradient's substrate already does the proof.
  match perform teach_gradient(handle) {
    Some(_) => true,
    None    => false,
  }
}

fn score_with_caret_bias(handle, caret) with GraphRead + Pure = {
  let suggestion     = perform teach_gradient(handle)
  let gates_unlocked = match suggestion {
    Some(AnnotationSuggestion(_, _, unlocks, _)) => len(unlocks),
    None => 0,
  }
  let target_span = perform graph_span_of(handle)
  let proximity   = caret_proximity_weight(caret, target_span)
  int_to_float(gates_unlocked) * proximity
}

fn caret_proximity_weight(caret_span, target_span) with Pure = {
  let Caret(caret_h, _) = caret_span_to_caret(caret_span)
  // Same handle: 1.0. Same module (transitive scope): 0.7.
  // Cross-module: 0.3. Same-line: bonus toward 1.0.
  scope_proximity_decay(caret_h, target_span)
}

fn argmax_or_default(scored, caret) with Pure = {
  match scored {
    [] => {
      // Program is fully annotated at every position. Cursor still
      // exists; it has nothing to suggest. Co-locate with caret.
      let Caret(h, why) = caret
      Cursor(h, Located(graph_span_of_safe(h),
                        Inferred("fully annotated")),
             0.0)
    },
    _ => scored |> reduce_max_by_score
  }
}
```

### 3.2 Pure transform discipline (SUBSTRATE.md §V)

Every function in §3.1 declares either `with Pure` or `with GraphRead
+ !Mutate`. **No mutation; no state; reproducible.** Per
SUBSTRATE.md §V "Pure Transforms for Structure, Effects for Context":
the structure is the live graph + the caret span; cursor argmax is
a pure read on that structure. Effects (GraphRead) are for context
(reading from the graph), not for state.

### 3.3 Why this composes IC cleanly

`enumerate_gradient_positions` walks the live graph; `gradient_next`
already runs checkpoint/apply/verify/rollback per candidate. Both
are Pure-over-(graph+env). Per `protocol_oracle_is_ic.md`: cache the
result alongside `env`. **That cache extension is Hμ.cursor.cache —
not this handle.** Today, Cursor recomputes on each query. After
Hμ.cursor.cache lands, Cursor reads the cached `oracle_queue` filtered
by caret proximity. Same semantics; better latency.

### 3.4 No ML, no tuning, no learned weights

`gates_unlocked × proximity` is a pure arithmetic combination of two
graph-derived quantities. The proximity decay (1.0 / 0.7 / 0.3) is a
literal table indexed by scope distance, not a learned model. The
weighting can be made user-configurable by exposing a `cursor_weights`
handler that overrides the default decay table — but that's a peer
handle (Hμ.cursor.transport), not this one.

### 3.5 The `??` override

When the developer types `??`, the parser produces
`nhole(fresh_ph(span), span)`. Inference assigns a fresh tyvar.
Cursor's `cursor_pinned(handle)` op fires for that handle's position
and returns `Cursor(handle, Located(span, Inferred("user pinned via
??")), 1e308)` — sentinel-large impact. `argmax_or_default` always
picks `??`-pinned positions before any auto-argmax candidate.

This is read-mode/write-mode unified per SUBSTRATE.md §VI Hole
subsection: same machinery, different weight on the cursor's chosen
slot. No mode switch, no separate code path.

---

## §4 The projection handler — composition of the eight tentacle reads

### 4.1 The Cursor effect

```mentl
effect Cursor {
  cursor_at(Span) -> CursorView                 @resume=OneShot
  cursor_argmax(Caret) -> Cursor                @resume=OneShot
  cursor_pinned(Handle) -> Cursor               @resume=OneShot
}
```

Three ops; each `@resume=OneShot`. No MultiShot in Cursor itself —
that lives in Synth (the proposer Cursor calls into).

### 4.2 cursor_default — the handler

```mentl
handler cursor_default with !Mutate {

  cursor_at(span) => {
    let handle = perform graph_handle_at_span(span)
    resume(CursorView{
      query    : perform graph_node_kind_at(handle),
      propose  : perform synth_propose(perform infer_ty_at(handle),
                                        perform infer_row_at(handle),
                                        perform mentl_context_at(handle)),
      topology : perform graph_pipe_context(handle),
      row      : perform infer_row_at(handle),
      trace    : perform ownership_at(handle),
      verify   : perform verify_pending_at(handle),
      teach    : perform teach_gradient(handle),
      why      : perform teach_why(handle),
    })
  },

  cursor_argmax(caret) =>
    resume(cursor_argmax_compute(caret)),

  cursor_pinned(handle) => {
    let span = perform graph_span_of(handle)
    let why  = perform teach_why(handle)
    resume(Cursor(handle,
                  Located(span, Inferred("user pinned via ??")),
                  1e308))
  },
}
```

### 4.3 Composition tally — every `perform` resolves to live substrate

| `perform` call | Substrate site | Status |
|---|---|---|
| `graph_handle_at_span` | `src/graph.mn` | LIVE |
| `graph_node_kind_at` | `src/graph.mn` (via `graph_chase`) | LIVE |
| `synth_propose` | `src/mentl.mn:89-93` Synth effect (OneShot stub returns []; H7-gated for real candidates) | LIVE in shape |
| `infer_ty_at` | `src/infer.mn` (via NBound chase) | LIVE |
| `infer_row_at` | `src/infer.mn` | LIVE |
| `mentl_context_at` | `src/mentl.mn` Context ADT construction | LIVE |
| `graph_pipe_context` | new helper in `src/graph.mn` (small — walks parent chain to find PipeExpr ancestor) | NEW (small) |
| `ownership_at` | `src/own.mn` ownership tracker | LIVE |
| `verify_pending_at` | `src/verify.mn` Verify ledger | LIVE |
| `teach_gradient` | `src/mentl.mn:104-105` mentl_default arm | LIVE |
| `teach_why` | `src/mentl.mn:107-108` mentl_default arm | LIVE |
| `graph_span_of` | `src/graph.mn` | LIVE |

**One new helper** (`graph_pipe_context`) — small, 10–20 lines,
walks parent chain in graph, returns PipeContext. Trivial. Could
be inlined in cursor.mn if preferred (see §10 open question).

**Net: zero new effects beyond Cursor itself; one small helper in
graph.mn; everything else composition.**

### 4.4 mentl_default and cursor_default are the same handler at different abstraction levels

`mentl_default` (existing) surfaces individual Teach ops:
`teach_gradient(handle) -> Option<AnnotationSuggestion>`,
`teach_why(handle) -> Reason`, etc. — *one tentacle at a time*.

`cursor_default` (new) composes those same ops into one CursorView
*at a position*. It's the same projection at a higher abstraction —
"give me everything Mentl knows about this position, in one record."

A transport handler can install either one. `mentl edit` installs
`cursor_default` because it wants the eight-aspect view per cursor
move. A CLI debugger might install `mentl_default` and call individual
ops as the user issues commands. Same substrate, two abstraction
layers — `~>` chain composition lets them coexist.

---

## §5 Text-caret as bias, not definition

### 5.1 The bias function in detail

```mentl
fn caret_proximity_weight(caret, target_span) with Pure = {
  let Caret(caret_handle, _) = caret
  let caret_span = perform graph_span_of(caret_handle)

  // Distance in span terms — we use a distance over the lexical
  // structure of the graph, not over file bytes:
  //   - Same handle (caret IS at this position):  1.0
  //   - Same enclosing function/handler:           0.85
  //   - Same module:                                0.7
  //   - Different module (transitive import):      0.4
  //   - Cross-module (no transitive relation):     0.2
  scope_distance_decay(caret_span, target_span)
}

fn scope_distance_decay(caret, target) with Pure = {
  if span_eq(caret, target) { 1.0 }
  else if same_enclosing_decl(caret, target) { 0.85 }
  else if same_module(caret, target) { 0.7 }
  else if transitive_dep(caret, target) { 0.4 }
  else { 0.2 }
}
```

The weights are literal floats in the source. They are **not learned
weights**. They are the named constants `0.85`, `0.7`, `0.4`, `0.2`
that encode the design assumption "the developer's attention has a
gradient, but the gradient never reaches zero, because cross-module
impact still matters."

### 5.2 Why proximity dominates impact only locally

If the developer is editing Module A and there's a 1-gate annotation
at the caret position, its score is `1 × 1.0 = 1.0`. If Module C has
a 4-gate annotation that just became available because of A's
rewrite, its score is `4 × 0.4 = 1.6`. **Module C wins.** The Cursor
moves to Module C. The developer's text-caret stays in Module A; the
Cursor surfaces Module C's proposal in the Mentl panel. Per
IE-mentl-edit.md §0.e the IDE shows the eight tentacles voiced for
the Cursor's position, regardless of where the caret is.

This is the bus-compressor behavior: the developer's local action
gets shaped by the global gradient response. The developer doesn't
have to find the impact; the medium surfaces it.

### 5.3 What "same enclosing decl" means structurally

The graph already encodes scope nesting via the env. Walking from a
handle's parent chain gives the enclosing FnStmt/handler/effect/type.
Two spans are in the same enclosing decl if their parent walks
intersect at a same-handle decl ancestor. This is a pure read on the
graph — no new structure.

---

## §6 `??` as the override — read-mode/write-mode unified

### 6.1 The mechanism

Per SUBSTRATE.md §VI "The Hole Is the Gradient's Absence Marker":

> Read-mode (cursor at finished code) and write-mode (cursor at `??`)
> are not different modes. They are the same gradient interaction
> viewed from two angles: at finished code, Mentl's Synth tentacle
> proposes alternatives to the current selection; at a hole, Mentl's
> Synth tentacle proposes from the constraint space alone.

`cursor_pinned(handle)` is the API entry point for `??`. The handler
returns a Cursor with `impact = 1e308` (sentinel-infinity), guaranteeing
it wins argmax against any auto-candidate. `argmax_or_default`'s
`reduce_max_by_score` selects it. The transport handler renders the
Cursor at the `??` position with Synth's candidates surfaced in the
proposal panel.

Multiple `??` in the program: each is a pinned candidate. Argmax
picks the one with highest *secondary* score — proximity to the
caret, then gates-unlocked-by-completion. Developer can move caret
to focus a different `??` to surface its proposals.

### 6.2 What the developer experiences

```mentl
// User types in their editor:
fn process(samples) = ??
                       ^
                  (??-pin here)
```

The Mentl panel updates immediately to:

```
Mentl @ process body (?? at line 1, col 26)
─────────────────────────────────────────────
Query    │ NHole(handle: 47); ty: ?ph_47 (fresh)
Propose  │ Synth candidates for (samples: ?A) -> ?B with ?R:
         │   1. samples |> filter(predicate)            (rank 0.82)
         │   2. samples |> map(transform)               (rank 0.77)
         │   3. samples |> reduce(seed, combiner)       (rank 0.71)
         │   4. process_inner(samples, default_config)  (rank 0.65)
         │   5. {result: samples, processed: true}      (rank 0.41)
Topology │ NoPipe (body is the full expression)
Row      │ ?R (no constraints; would unlock with annotations)
Trace    │ samples: ref ?A (passed; not consumed)
Verify   │ (none — fresh)
Teach    │ Add `with !Alloc` to constrain candidates 1, 2 to non-allocating
Why      │ Located(line 1:26, Placeholder(span)) — user invited proposal
```

Eight aspects. One read. The user types one constraint (`with
!Alloc`); Cursor re-fires; candidates 3 (reduce: allocates), 4
(allocates), 5 (record alloc) drop; candidates 1 and 2 with non-
allocating predicate/transform now rank top. Constraint-tightening
is the gradient narrowing.

Add `with !Alloc + !IO` and the candidate space tightens further.
Add a refinement type on samples (`samples: NonEmpty<Sample>`) and
candidate 1's `filter` becomes problematic (could empty the list);
candidate 2's `map` survives. By the time enough constraints exist,
the candidate space collapses to one. The hole resolves to the
synthesized body.

This is the Circular Gradient (SUBSTRATE.md §VI): at the bottom
(loose constraints) `??` invites many candidates; at the top (tight
constraints) `??` resolves to one inhabitant — the program is the
proof is the specification is the program.

### 6.3 No new substrate beyond cursor_pinned

The user types `??`. Lexer emits THole. Parser emits nhole. Inference
mints a fresh tyvar. Cursor effect's cursor_pinned op fires. Synth
runs (today via the OneShot stub returning `[]`; after Hμ.synth-
proposer, with real MultiShot enumeration). Transport renders the
CursorView. **Every step is in substrate that exists today** (with
Synth gated on H7 for real candidates).

---

## §7 IC integration — Cursor falls out of (env, oracle_queue) cache + caret

### 7.1 Today (Hμ.cursor only — no cache extension)

`cursor_argmax(caret)` recomputes on each call:
1. Walk all handles in the live graph (`graph_all_handles` —
   transitively all per-module envs).
2. For each handle, call `teach_gradient(handle)` which runs
   checkpoint/apply/verify/rollback per candidate.
3. Score and argmax.

This is O(N · K) where N = handles, K = candidates per handle.
Acceptable for small programs; expensive at scale.

### 7.2 Tomorrow (Hμ.cursor.cache — peer handle, NOT this one)

Per `protocol_oracle_is_ic.md`: extend the IC cache from `env` to
`(env, oracle_queue)`. The `oracle_queue` is the per-module list of
`(handle, AnnotationSuggestion)` pairs computed lazily as
gradient_next runs. On graph delta:
- Modules whose source unchanged AND whose imports unchanged: keep
  cached env AND oracle_queue.
- Modules with delta: re-infer env, recompute oracle_queue.

`cursor_argmax(caret)` becomes: read all per-module oracle_queues;
score each entry by caret proximity; argmax. **O(N) where N =
candidates across the whole project.** No re-running gradient_next
on cache hits.

### 7.3 Per-keystroke cadence

IC re-infers on every keystroke (or every save, or every idle pause —
transport-handler decision). Every IC re-inference may invalidate
cached oracle_queue entries. cursor_argmax re-fires on the new graph.
The Cursor moves with each substrate change.

This is the bus-compressor at full speed: every keystroke is a
constraint addition; the graph updates; the gradient response curve
re-evaluates; the Cursor's argmax moves; the developer sees the new
locus of impact. Less is more — the developer doesn't manage state;
the medium maintains it.

### 7.4 No new cached value (`protocol_oracle_is_ic.md` constraint)

Cursor itself is not cached — it's a query result over the cached
substrate. The cached substrate is `(env, oracle_queue)`, exactly
per the protocol. Cursor adds **zero** to the IC invalidation
discipline; it reads what's already there.

---

## §8 Read-mode vs write-mode unified

This section restates SUBSTRATE.md §VI verbatim and verifies that
Hμ.cursor's substrate honors it.

> **Read-mode (cursor at finished code) and write-mode (cursor at
> `??`) are not different modes. They are the same gradient interaction
> viewed from two angles: at finished code, Mentl's Synth tentacle
> proposes alternatives to the current selection; at a hole, Mentl's
> Synth tentacle proposes from the constraint space alone.**
>
> — `docs/SUBSTRATE.md:915-921`

In Hμ.cursor:
- **Read-mode** = `cursor_at(span)` where `span` corresponds to a
  finished position. The CursorView includes `propose: List<Annotation>`
  populated by `synth_propose` running with the *current expression
  as one candidate*; alternatives surfaced are sibling candidates.
- **Write-mode** = `cursor_pinned(handle)` where `handle` corresponds
  to a `??` position. The CursorView's propose list is populated by
  `synth_propose` with *no incumbent*; all candidates are proposals to
  fill the slot.

**Same effect (`Cursor`). Same handler (`cursor_default`). Same
underlying substrate (`synth_propose` + the eight tentacle reads).
Different `impact` value (auto-argmax vs sentinel-infinity).** The
developer never enters or exits a "mode" — they move their caret,
which biases argmax; or they type `??`, which pins argmax.

Per SUBSTRATE.md §VI Hole subsection: "constraint tightness alone
determines the candidate-space size." Hμ.cursor's substrate enforces
this: the same proof-search runs at every position; what varies is
the constraints that survive and the incumbent's presence.

---

## §9 The three-module worked example

### 9.1 Setup

Three modules. Fully annotated. All clean. No outstanding gradient
suggestions.

```mentl
// Module A — module_a.mn
fn compute(x: Int) -> Int with Pure = x * 2
```

```mentl
// Module B — module_b.mn
import a/module_a {compute}

fn double_compute(y: Int) -> Int with Pure =
  compute(y) + compute(y)
```

```mentl
// Module C — module_c.mn
import a/module_a {compute}

/// Process a list by applying compute to each element.
fn f(xs: List<Int>) -> List<Int> with !Alloc =
  xs |> map(compute)
```

C's `f` declares `with !Alloc`. The body calls `map(compute)`. Today,
suppose `map`'s implementation is `with Alloc` (it allocates a new
list). C's `f` would fail compilation with E_EffectMismatch. To make
the example concrete, assume an arena-allocated map variant exists,
and the user's code declares `with !Alloc + Arena` — clean.

### 9.2 The user rewrites Module A

```mentl
// Module A — after rewrite
fn compute(x: Int) -> Int with Pure = {
  let doubled = x * 2
  let tripled = doubled + x  // changed: was just `x * 2`; now adds x
  tripled
}
```

Same row (`with Pure`). Same signature. New body. The user saves.

### 9.3 IC re-fires

IC's cache invalidation walks A's source hash → mismatch → re-infer
A. Re-infer succeeds; A's cached env updates with new body. Now IC
checks downstream:
- B imports A. B's cached env's hash of A's exports unchanged
  (signature is identical). **B's cache holds.**
- C imports A. C's cached env's hash of A's exports unchanged. **C's
  cache holds.**

### 9.4 But oracle_queue invalidates differently

A's body changed. A's gradient_next was run on the old body and may
have cached `oracle_queue_A`. The new body produces a different
oracle_queue. IC invalidates `oracle_queue_A`; gradient_next re-runs
on A's new body. Suppose the new body has zero unfilled gradient
positions — A is still fully annotated.

But **C's `f` changes**. Why? Because `f`'s gradient wasn't only
about its own body — it was about the *transitive* row reachable via
its calls. `gradient_next(C.f)` had been computed against the old A
where `compute = x * 2`, body row `Pure`. The new A has a different
body but still `Pure`, so structurally `f`'s row is unchanged.

So actually in this constructed example, gradient_queue_C also
holds. Cursor's argmax doesn't move. The developer's edit was
functionally invisible to the gradient.

### 9.5 The interesting case — A's row changes

Now suppose the rewrite IS substantial:

```mentl
// Module A — after substantial rewrite
fn compute(x: Int) -> Int = {
  perform log_compute(x)  // performs LogIO effect (was previously absent)
  x * 2
}
```

The signature originally was `with Pure`; now the body performs
LogIO. The user *removes* the `with Pure` annotation as part of the
edit; A now has body row `LogIO`. A's gradient_next on the new body:
maybe nothing to suggest (the user already declared the effect as
present).

But B's `double_compute` declared `with Pure` and calls compute. B
fails compilation: body performs LogIO via compute; declared row Pure.
The gradient on B has a new candidate: AWrapHandler proposing to wrap
the compute calls in a `silent_log` handler that absorbs LogIO.

Cursor's argmax over the new graph:
- A: 0 unfilled positions, score 0.
- B: 1 candidate (AWrapHandler) unlocking 0 capabilities (silent_log
  doesn't unlock new capability — it absorbs an effect). Score: 0 ×
  proximity = 0.
- B alternative: drop `with Pure` from B's signature. Score: this is
  a *gradient delta* — Hμ.gradient-delta's territory, NOT this handle.
  Skip.
- C: now `f` declares `!Alloc + Arena` and calls `map(compute)` which
  performs LogIO via compute. C also fails. Same AWrapHandler proposal
  candidate.

In short: the propagation is real but the argmax depends on what
gradient_next produces, which is gated on Hμ.synth-proposer for the
quality of the proposed wrap candidates.

### 9.6 The cleaner example — Pure becomes provable

The most pedagogically useful case: **A's rewrite removes the only
impure call from a transitive chain, making something downstream
*provably more pure than the user declared*.**

```mentl
// Module A — original
fn compute(x: Int) = perform log_compute(x); x * 2
                            // performs LogIO

// Module C — original  
import a/module_a {compute}
fn f(xs: List<Int>) -> List<Int> =
  xs |> map(compute)
// inferred: with LogIO (transitive via compute)
// — declared: nothing — the inferred row is wider than ideal
```

User rewrites A:

```mentl
// Module A — after rewrite (removes the perform)
fn compute(x: Int) -> Int with Pure = x * 2
```

IC invalidates A; A's new env has `compute` at `(Int) -> Int with
Pure`. C's cached env hash of A's exports changed (because the row
changed from LogIO to Pure). C's cache invalidates. C re-infers; C's
`f` is now `(List<Int>) -> List<Int> with Pure`.

C's new oracle_queue: gradient_next(C.f) sees the body is provably
Pure; the user's declared signature is *missing* the row clause; the
gradient suggests `with Pure` to make it explicit and unlock CMemoize +
CCompileTimeEval.

`AnnotationSuggestion(SuggestEffectRow, "with Pure", ["CMemoize",
"CCompileTimeEval"], Located(C.f.span, InferredCallReturn("compute",
Inferred("Pure after A rewrite"))))`.

### 9.7 Cursor's response

The user's caret is in Module A (just finished editing). Module A
has zero candidates. Module B has zero candidates. Module C has one
candidate at `f` worth 2 capability gates.

Score table:
- A's positions: gates_unlocked = 0; any caret_proximity_weight × 0 = 0.
- B's positions: gates_unlocked = 0; score 0.
- C's `f` position: gates_unlocked = 2; caret_proximity_weight = 0.4
  (cross-module). Score = 2 × 0.4 = 0.8.

argmax: C's `f`, score 0.8.

Cursor surfaces the proposal. The Mentl panel shows:

```
Mentl @ module_c.mn::f (line N)
────────────────────────────────────────────────
Caret    │ Module A, line M (your text-caret is elsewhere)
Cursor   │ Module C, line N — function `f` body
Teach    │ Adding `with Pure` to `f`'s signature would unlock:
         │   • CMemoize (same input → same output, guaranteed)
         │   • CCompileTimeEval (compute at compile time when
         │     inputs known)
Why      │ `f` body is now provably Pure because:
         │   • `f` calls `map(compute)` (line N)
         │   • `compute` was rewritten in module_a.mn (line K) to
         │     remove `perform log_compute`; now `with Pure`
         │   • `map` over `Pure` callee inherits `Pure`
         │ Located(module_c.mn:line N, InferredCallReturn("compute",
         │         Inferred("Pure after module_a.mn:line K rewrite")))
Propose  │ [Accept] [Defer] [Why deeper] [Don't show again]
```

The user accepts. Cursor synthesizes the patch (`with Pure`).
oracle_queue invalidates C; gradient_next re-runs C; nothing left to
suggest at `f`. Cursor moves to the next argmax position.

The user never opened Module C. Cursor surfaced the proposal at the
moment it became applicable, with the Reason chain walking back to
the originating action (the rewrite of A).

**This is what Mentl-driven editing feels like.** Bottom-up
debugging dissolves not because bugs are absent but because the
medium catches improvements at proof time, at the cursor's
projection.

---

## §10 Surfacing cadence — handler-decided

### 10.1 IC re-evaluation: continuous, mandatory

The graph stays live. Every keystroke is a candidate constraint
addition; IC re-infers as needed. This is non-negotiable —
`protocol_oracle_is_ic.md` locks it.

### 10.2 Cursor argmax recompute: pure, on graph delta

`cursor_argmax` is a pure read on the live graph. It recomputes when
the graph changes. With Hμ.cursor.cache (peer handle), it recomputes
on `oracle_queue` invalidations.

### 10.3 Surfacing: the transport handler decides

The transport handler — `terminal_transport`, `lsp_transport`,
`web_transport`, `vim_transport` — chooses *when* to emit the new
CursorView to the human:

| Cadence | When | Best for |
|---|---|---|
| Real-time | Every keystroke | Mentl edit (browser playground); zero-friction discovery |
| Idle-debounced (~250ms) | Pause in typing | Most editors; default |
| On-save | Explicit save event | Heavy projects; reduces visual noise |
| On-explicit-ask | User invokes "what's next?" | CLI; interactive shell |

These are four handler implementations. Same kernel. Same Cursor
substrate. The user picks via configuration which transport
handler is installed. Mentl solves Mentl's UX-tradeoff problem
through handler-swap, exactly as SUBSTRATE.md §III "The Handler IS
the Backend" prescribes for any multi-target output.

### 10.4 Default cadence

Recommendation for `mentl edit` (Hμ.cursor.transport): idle-debounced
~250ms. Rationale:
- Real-time on every keystroke creates visual flicker and breaks the
  developer's focus during typing.
- On-save creates discontinuity; the proposal might surface long
  after the action that produced it, breaking the bus-compressor
  closed-loop feel.
- ~250ms idle matches typical typing-pause boundaries (between
  tokens, between line completions). The proposal arrives "between
  thoughts," not "during typing."

### 10.5 Audit recovery from cadence

The transport-cadence decision is independent of correctness. If
~250ms turns out wrong, switch to 100ms or 500ms by swapping the
debounce constant in the transport handler. No Cursor substrate
change. This is the swap-surface property: the substrate is fixed;
the surfacing is configurable.

---

## §11 Drift-mode audit (preventive, all nine)

Per `tools/drift-audit.sh` and CLAUDE.md's nine drift modes. Each
mode is checked against Hμ.cursor's substrate explicitly.

### Mode 1 — Rust vtable (closure-as-vtable)

**Risk:** Cursor implementing dispatch over candidate types or
tentacle types via a function-pointer table.

**Mitigation:** `cursor_at` is a graph query that calls eight named
`perform` ops. There is no table at any layer — source, LowIR, WAT,
or emitted binary. Per SUBSTRATE.md §I "The Heap Has One Story":
"the word 'vtable' never appears in any correct description of Mentl
dispatch." Cursor honors this — it composes named handler effects.

**Verdict: PASS.**

### Mode 2 — Scheme env frame (scope-as-frame-stack)

**Risk:** Caret distance computation walking a frame stack.

**Mitigation:** `caret_proximity_weight` reads `Span` values and
walks the graph's parent chain (which is a graph traversal, not a
frame stack). The graph already encodes scope nesting via the env;
Cursor reads what's there. No frame stack constructed.

**Verdict: PASS.**

### Mode 3 — Python dict (effect-name-set as flat strings)

**Risk:** CursorView fields keyed by string names, or Annotation
representations as strings.

**Mitigation:** CursorView is a record with eight typed fields
(field offsets resolved at compile time). Annotation is the existing
ADT. SuggestionKind is a 4-variant ADT. Capability strings appear
in `AnnotationSuggestion.unlocks: List<String>`, but they are
*labels for transport*, not internal state — the substrate uses the
existing `Capability` ADT internally; the strings are produced by a
projection at the transport boundary. Drift-audit: this is a
boundary-conversion, not internal string-keyed state.

**Verdict: PASS.**

### Mode 4 — Haskell MTL (handler-chain-as-MTL)

**Risk:** `cursor_default` stacking on `mentl_default` +
`verify_default` + `query_default` + ... as separate single-concern
layers.

**Mitigation:** `cursor_default` is **one handler** with three arms
(`cursor_at`, `cursor_argmax`, `cursor_pinned`). Each arm composes
eight `perform` calls — the perform calls bubble up to whatever
handlers are installed in the surrounding `~>` chain (which already
exist independent of Cursor: `mentl_default` for Teach,
`verify_ledger` for Verify, etc.). This is *capability stacking*,
not concern-stacking — exactly what SUBSTRATE.md §III "The Handler
Chain Is a Capability Stack" prescribes.

**Verdict: PASS.**

### Mode 5 — C calling convention (separate `__closure`/`__ev` instead of unified `__state`)

**Risk:** Caret-position and gradient-argmax as separate state
records carried in parallel.

**Mitigation:** §2 enforces the rename: `Caret(Handle, Reason)` is
the user's text-caret; `Cursor(Handle, Reason, Float)` is the
gradient argmax. Cursor *consumes* Caret as input via
`cursor_argmax(caret) -> Cursor`. There is no parallel
"caret_state" + "argmax_state" record. One unified pipeline.
MV-mentl-voice.md is updated in §7 to use the new names.

**Verdict: PASS.**

### Mode 6 — Primitive-type-special-case

**Risk:** Cursor handling the "no candidates" case with a different
return type or different code path.

**Mitigation:** `argmax_or_default` returns a `Cursor` value with
`impact = 0.0` for the "fully annotated" case. Same shape, same
record, same code path. Transport handlers can render
`impact = 0.0` differently (e.g., "nothing to suggest" message), but
the substrate uniformity is preserved. HB.bool's discipline:
"every nullary ADT deserves the same compilation discipline" — same
applies to "every Cursor value, including the no-suggestion case,
deserves the same shape."

**Verdict: PASS.**

### Mode 7 — Parallel-arrays-instead-of-record

**Risk:** Eight separate lists (one per tentacle aspect) for eight
aspects of Cursor.

**Mitigation:** `CursorView` is one record with eight fields. Per
SUBSTRATE.md §IX "Records Are The Handler-State Shape": "frame
consolidation (Ω.5) turned parallel arrays into records; H1.3's
BodyContext, H4's region_tracker, H5's AuditReport all converge on
the same shape." Cursor's eight aspects are the *next instance* of
that convergence — and per the "three instances earn the
abstraction" rule, they reinforce the existing record discipline,
they don't create a new one.

**Verdict: PASS.**

### Mode 8 — String-keyed-when-structured

**Risk:** SuggestionKind as a string or int flag rather than an
ADT.

**Mitigation:** `SuggestionKind` is a 4-variant ADT
(`SuggestEffectRow | SuggestOwnership | SuggestRefinement |
SuggestReturnType`). Per CLAUDE.md drift 8: "every flag is an ADT
begging to exist." This is the ADT.

**Verdict: PASS.**

### Mode 9 — Deferred-by-omission

**Risk:** "Cursor handler shape now, eight wirings later" — landing
the handler with stub bodies and adding the actual reads in a follow-
up handle.

**Mitigation:** Every `perform` call in `cursor_default` resolves to
substrate that exists today (per the §4.3 composition tally). The
one new helper (`graph_pipe_context`) is small and lands in the
same commit. Synth's MultiShot completion is named as Hμ.synth-
proposer (peer handle) — but the OneShot stub returning `[]` IS
correct substrate today, not deferred-by-silence; cursor_default
behaves correctly with `propose: []` in the CursorView. Transport-
layer surfacing is named as Hμ.cursor.transport (peer handle) — not
deferred-by-silence; until that lands, cursor_default's output is
queryable but not auto-surfaced. **Both deferrals are named peer
handles, not silent omissions.**

**Verdict: PASS.**

### Audit summary

**All nine modes PASS.** The walkthrough's substrate is residue.
Drift-audit (`tools/drift-audit.sh`) is expected to return 0 after
each commit in §13 sequence.

---

## §12 Why this is the residue

### 12.1 Composition tally

| Substrate piece | Status | Used by Hμ.cursor for |
|---|---|---|
| 1. Hole substrate (lexer THole, parser nhole, infer fresh tyvar) | LIVE | `cursor_pinned(handle)` for `??` positions |
| 2. Synth effect (OneShot stub today; H7-gated for MultiShot) | SHAPE | `cursor_at`'s `propose` field; `synth_propose` perform call |
| 3. gradient_next + try_each_annotation (checkpoint/apply/verify/rollback) | LIVE | `enumerate_gradient_positions` + `score_with_caret_bias` via `teach_gradient` perform |
| 4. Reason DAG (18+ variants, RX.2 high-intent) | LIVE | `Cursor.reason` field; `CursorView.why` field |
| 5. IC cache (KaiFile, Pack/Unpack, FNV-1a) | LIVE | per-module env caching that Cursor reads |
| 6. Teach effect (5 ops: teach_here, teach_gradient, teach_why, teach_error, teach_unlock) | LIVE | `cursor_default` perform calls |
| 7. Verify ledger (V_Pending obligations) | LIVE | `CursorView.verify` field; `verify_pending_at` perform |
| 8. Ownership tracker (own/ref classification) | LIVE | `CursorView.trace` field; `ownership_at` perform |
| 9. Effect row algebra (`+ - & ! Pure`, row_subsumes) | LIVE | `CursorView.row` field; `infer_row_at` perform |
| 10. Canonical layout enforcement (parser; PipeKind in spec 10) | LIVE | `CursorView.topology` field; `graph_pipe_context` (new small helper) |

**Ten substrate pieces. One new small helper (graph_pipe_context).
Five new ADTs in types.mn. One new effect (Cursor) with three ops.
One new handler (cursor_default).** Everything else is composition.

Per `protocol_kernel_closure.md`: "the next phase is composition,
not invention." This is composition. The kernel is whole. Cursor is
the projection.

### 12.2 What this proves about the kernel

Hμ.cursor is the **first handle of Phase μ** — Mentl active-surface
composition. That every interrogation passes with zero invention
*proves* the kernel-closure claim from 2026-04-24: "all eight
primitives structurally live; the next phase composes." Cursor is
empirical evidence: a load-bearing user-facing feature whose
substrate is entirely composition of pre-existing pieces.

If a future session at this cursor finds itself reaching for a new
primitive or a new effect to "make Cursor work," that reach is
drift. Re-read this walkthrough; re-read `protocol_cursor_is_argmax.md`;
re-frame.

### 12.3 What this enables

After Hμ.cursor lands:

- **Hμ.cursor.transport** can wire CursorView to terminal/LSP/web/
  vim. The IDE becomes possible.
- **Hμ.synth-proposer** has a consumer for its MultiShot candidates
  (Cursor's `propose` field).
- **Hμ.gradient-delta** has a place to surface inverse-direction
  suggestions (Cursor's `teach` field gains a SuggestEffectRow
  variant when the proposal is a row tightening, not just an
  annotation addition).
- **Hμ.eight-interrogation-loop** has a substrate to automate
  against (Cursor's eight aspects ARE the interrogations as code).

Cursor is the keystone. The four peer handles compose on it.

---

## §13 Chunk decomposition (commit sequence)

Per the cascade discipline: each commit ends with `tools/drift-audit.sh`
clean. Walkthrough §11 audit is preventive; the actual audit fires
post-commit.

1. **Hygiene commit** — debug residue + bootstrap restore. (Already
   done at plan-execution start.)
2. **Walkthrough commit** — `docs/specs/simulations/Hμ-cursor.md`
   (this file). Pre-audit on four axes: eight + SYNTAX + SUBSTRATE +
   wheel. (Pre-audit completed inline with §1, §11 above.)
3. **Memory protocol commit** — `~/.claude/projects/-home-suds-Projects-mentl/memory/protocol_cursor_is_argmax.md`.
   (Local to ~/.claude; not in repo.)
4. **types.mn + GR commit** — five ADT additions; GR §3.2 promoted
   from shape to live. Drift-audit clean.
5. **mentl.mn commit** — teach_gradient + gradient_next return
   AnnotationSuggestion. Drift-audit clean.
6. **cursor.mn commit** — `src/cursor.mn` end-to-end + small
   `graph_pipe_context` helper added to `src/graph.mn`. Drift-audit
   clean.
7. **Authority docs commit** — SUBSTRATE.md §VI subsection; DESIGN.md
   Mentl chapter; CLAUDE.md anchor + JIT-trigger; 09-mentl.md
   Cursor section; MV-mentl-voice.md rename + tighten; IE-mentl-edit.md
   tighten.
8. **ROADMAP.md commit** — Phase μ section + Hμ.cursor entry +
   peer handle list (.transport, .synth-proposer, .gradient-delta,
   .cache, .eight-interrogation-loop).

Total: 7 commits + hygiene (already landed). Each clean. Each
testable independently.

---

## §14 Acceptance criteria

The handle is closed when **all six** hold:

1. **Drift audit clean** — `tools/drift-audit.sh` returns 0 after
   every commit in §13.
2. **Walkthrough pre-audit clean** — this file's §1 + §11 sections
   pass the four-axis audit (eight interrogations + SYNTAX.md
   token-discipline + SUBSTRATE.md theorem-alignment + wheel-
   canonical match).
3. **Composition tally verified** — every `perform` in `src/cursor.mn`
   resolves to a substrate site that already exists (see §4.3 +
   §12.1 tables).
4. **Drift-mode audit clean** — explicit walk through the nine modes
   per §11 confirms PASS for all nine.
5. **Authority docs cite each other** — closed loop:
   - SUBSTRATE.md §VI new "Cursor: The Gradient's Global Argmax"
     subsection references `src/cursor.mn` and this walkthrough.
   - CLAUDE.md JIT-trigger references `src/cursor.mn` + the new
     SUBSTRATE.md subsection + `protocol_cursor_is_argmax.md`.
   - DESIGN.md Mentl chapter cross-references SUBSTRATE.md §VI.
   - 09-mentl.md cross-references this walkthrough.
   - MV-mentl-voice.md uses the new Caret/Cursor split.
   - IE-mentl-edit.md cites `cursor_default` as the canonical eight-
     tentacle read.
6. **Three-module worked example traceable** — §9 of this walkthrough
   traces the example through `cursor.mn`'s code; a reader following
   §9 step-by-step against the cursor.mn source can see exactly which
   `perform` fires at which moment.

End-to-end runtime test is **not** part of acceptance (Anchor 0:
lux3.wasm is not the arbiter; verification is by simulation,
walkthrough, and audit). Hμ.cursor.transport will close the runtime
loop empirically when it lands.

---

## §15 Composition with cascade — what comes after

| Handle | Depends on Hμ.cursor for | Status |
|---|---|---|
| **Hμ.cursor.transport** | CursorView shape; cursor_default handler; cadence config interface | NEXT after Hμ.cursor |
| **Hμ.synth-proposer** | The Cursor effect's `propose` field as consumer; H7 MultiShot emit landing | Gated on H7; can land in parallel with Hμ.cursor.transport |
| **Hμ.gradient-delta** | AnnotationSuggestion ADT (lands here in types.mn); GR §2 inverse-direction substrate | After Hμ.cursor; before Hμ.cursor.transport for full surfacing |
| **Hμ.cursor.cache** | `(env, oracle_queue)` cache extension per `protocol_oracle_is_ic.md`; depends on Hμ.cursor reading the cache it extends | After Hμ.cursor; performance-only |
| **Hμ.eight-interrogation-loop** | Cursor's eight-aspect read as the canonical pattern to automate | After all four above |

The cascade is a tree, not a line. Hμ.cursor is the root. Phase μ
proceeds in parallel branches once the root lands.

---

## §16 Open questions + named follow-ups

### 16.1 graph_pipe_context — helper or inline?

Currently §4.3 names a new helper `graph_pipe_context(handle) ->
PipeContext` of ~10–20 lines walking the parent chain. This could
alternatively be inlined in cursor.mn as a private fn.

**Recommendation:** Inline initially (closer to point of use); if a
second consumer arrives, factor to graph.mn per "three instances
earn the abstraction." Today there's no second consumer.

### 16.2 Caret rename — backwards compatibility in MV walkthrough?

Renaming MV's `Cursor(Handle, Reason)` → `Caret(Handle, Reason)`
breaks any prose that uses the old name. The §7 doc-alignment commit
updates MV-mentl-voice.md, but third-party documentation (none yet —
project is pre-public) would also need to update.

**Recommendation:** Single-shot rename. Project is pre-public; cost
of the rename is bounded to the docs in this commit. No deprecation
path needed.

### 16.3 Surfacing cadence default

§10 recommends idle-debounced ~250ms. This is a preference, not a
substrate decision.

**Recommendation:** Codify ~250ms as the documented default in
Hμ.cursor.transport's walkthrough. Make it user-configurable via a
`cursor_weights` (or `cursor_transport_config`) handler.

### 16.4 Cross-module proximity for transitive imports

§5.1 prescribes `0.4` for "different module (transitive import)" and
`0.2` for "cross-module (no transitive relation)." The boundary
between the two requires walking the import DAG.

**Recommendation:** Use the existing IC dependency hash as the
proxy. If a module's import-hash includes the caret's module, it's
transitively connected. Otherwise cross-module. This composes on
existing IC substrate.

### 16.5 ?? at top-level vs. inside expressions

Today the parser produces `nhole(fresh_ph(span), span)` for any
`??` token. At top-level (e.g., `fn process(samples) = ??`), the
hole is the entire body. Inside an expression (e.g., `xs |> map(??)`),
the hole is one argument.

**Recommendation:** No new substrate. The existing nhole production
handles both cases uniformly. Cursor's `cursor_pinned(handle)` works
the same whether the handle is a top-level NHole or a nested one.

---

## §17 Closing

Hμ.cursor names what the kernel already does. The medium has been
ready for this since 2026-04-24's kernel closure; this handle just
*runs the projection at the human boundary*.

Mentl IS Cursor IS the gradient argmax IS the graph projected for the
human IS the program revealed where it's most ready to teach. All
five names point to one thing. Eight tentacles is eight aspects of
one read.

The bus is on. What follows is the medium being put to work.
