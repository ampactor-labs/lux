# VK — Verb-Kind Intent Preservation

*Primitive #3 round-trip. Preserves the five-verb identity through
lowering so hover, audit, and Mentl's Topology tentacle can name
the authored topology — not its lowered mechanism.*

**Part of: IR cluster ([IR-intent-round-trip.md](IR-intent-round-trip.md)).**
**Status: 2026-04-22 · seeded.**

---

## §1 Frame

Mentl's primitive #3 is the five verbs: `|>` `<|` `><` `~>` `<~`.
Each draws a distinct topology. The developer writes `x <~ f` meaning
"feedback — iterative with state-slot." The developer writes
`source |> transform ~> logger` meaning "tee — handler attachment
wrapping the preceding chain."

**Gap.** By LowIR, verb identity is dissolved:

- `|> converge` → `LCall(handle, lo_r, [lo_l])` (lower.mn:409)
- `<| diverge` → `LMakeTuple(handle, lower_diverge_branches(...))` (lower.mn:413-414)
- `>< compose` → `LMakeTuple(handle, [lo_l, lo_r])` (lower.mn:417-418)
- `~> tee` → `LHandleWith(handle, lo_l, lo_r)` (lower.mn:427-430)
- `<~ feedback` → `LFeedback(handle, lo_l, lo_r)` (lower.mn:434-435)

Of these, `LFeedback` and `LHandleWith` retain structural identity —
their LowIR variant names correspond to the verb. But `LCall` is
indistinguishable from any other function call; `LMakeTuple` is
indistinguishable from any other tuple construction. A hover on an
`|>` expression shows "call" not "forward pipe." A hover on `><`
shows "tuple" not "parallel compose."

The topology — which IS the computation graph's shape made visible
(DESIGN Ch 2, CLAUDE.md Anchor 6) — is lost in the very layer
where it should be most readable.

**Diagnostic quality delta:** *"function call at line 12"* vs
*"forward pipe (|>) at line 12 — applies transform to data."*
*"tuple construction at line 15"* vs *"parallel compose (><) at
line 15 — independent inputs, tupled output."*

---

## §2 Trace — where intent drops today

### Parser (parser.mn)

The parser emits `PipeExpr(PipeKind, left, right)` with `PipeKind`
carrying full verb identity: `PForward | PDiverge | PCompose |
PTeeBlock | PTeeInline | PFeedback`.

### Inference (infer.mn:644-657)

`infer_expr` dispatches on `PipeExpr(kind, left, right)`. The
`PipeKind` is available for each verb's inference rule. The
`handler_stack` (infer.mn:45-47) tracks handler installation for
`~>` sites via `inf_push_handler("pipe_tee")` — but the handler name
is a flat string, not the PipeKind.

### Lowering (lower.mn:403-436)

`lower_pipe` dispatches on PipeKind and emits the appropriate LowIR
node. After this point:
- `PForward` → `LCall` — verb identity gone. LCall is the universal
  "apply f to args" node.
- `PDiverge` → `LMakeTuple` of `LCall` branches — verb identity gone.
- `PCompose` → `LMakeTuple` — verb identity gone.
- `PTeeBlock` / `PTeeInline` → `LHandleWith` — verb PARTIALLY
  preserved (LHandleWith is tee-specific).
- `PFeedback` → `LFeedback` — verb preserved (LFeedback is
  feedback-specific).

### Emit (wasm.mn)

Emit works from LowIR. It never sees PipeKind. No verb identity
reaches the WAT layer (nor should it — WAT has no topology).

### Hover/audit

No downstream surface currently reads PipeKind from the AST. The
AST node `PipeExpr(kind, left, right)` carries it, but no handler
queries it.

---

## §3 Design candidates + Mentl's choice

**Candidate A: Query handler reads PipeKind from AST.**
No LowIR change. When hover/audit needs verb identity, it reads the
original AST node's PipeKind via `perform pipe_kind_at(handle)`.
The handle → AST lookup is a graph read (the handle IS the AST
node's type handle; the AST is indexed by handle).

**Candidate B: PipeOrigin tag on LowIR nodes.**
Each LowIR node that came from a PipeExpr carries an optional
`PipeOrigin(PipeKind)`. `LCall` becomes `LCall(h, f, args)` but
the emitter can ignore the origin tag while hover reads it.

**Candidate C: Preserve PipeKind at the LowIR level.**
Replace `LCall` from pipe with `LPipeForward(h, f, arg)`,
`LMakeTuple` from compose/diverge with `LPipeCompose(h, l, r)`,
etc. Each verb gets its own LowIR variant.

**Mentl's choice: A — query handler reads AST.** The intent lives
on the AST already. LowIR's job is to express the lowered mechanism
for emit; duplicating intent there is substrate-layer confusion
(§7 of IR-intent-round-trip.md: "intent queries read what was
authored before normalization ran"). Candidate B embeds intent in
the lowered form, fighting the separation. Candidate C multiplies
LowIR variants for diagnostic purposes — 27+ variants instead of
the current 24.

**Access path.** The AST node carries `PipeExpr(kind, left, right)`.
The node's handle is the type handle. A query op
`perform pipe_topology(handle) -> Option<PipeKind>` reads the AST
via the handle. Hover resolves the result:
- `Some(PForward)` → "forward pipe (|>)"
- `Some(PDiverge)` → "diverge (<|) — borrows input"
- `Some(PCompose)` → "compose (><) — independent inputs"
- `Some(PTeeBlock)` or `Some(PTeeInline)` → "tee (~>) — handler"
- `Some(PFeedback)` → "feedback (<~) — iterative"
- `None` → not a pipe expression; show the LowIR form

**Load.** Light. One query op, one handler arm reading the AST index,
one hover-arm formatting function. No LowIR changes. No inference
changes.

---

## §4 Layer touch-points

### parser.mn
No change. PipeExpr already carries PipeKind.

### types.mn
No change. PipeKind already defined (types.mn:398-404).

### infer.mn
No change. PipeKind flows through PipeExpr inference unchanged.

### lower.mn
No change. Intent is read from the AST, not from LowIR.

### query / hover handler (future)
New query op: `pipe_topology(handle) -> Option<PipeKind>`.
Handler reads the AST node at the given handle. If the node body
is `PipeExpr(kind, _, _)`, return `Some(kind)`. Otherwise `None`.

### Mentl / audit
Mentl's Topology tentacle reads `pipe_topology` to surface the
verb identity per turn. Audit per-fn report includes a verb-usage
summary: how many `|>`, `<|`, `><`, `~>`, `<~` sites in the
function's body.

---

## §5 Acceptance

**AT-VK1.** Hover on `x |> f` displays "forward pipe (|>)" and the
inferred type, not just "call."

**AT-VK2.** Hover on `x <~ spec` displays "feedback (<~) — iterative
with state-slot" and the inferred state type.

**AT-VK3.** Hover on `source |> transform ~> logger` at the `~>` site
displays "tee (~>) — handler attachment wrapping the chain."

**AT-VK4.** Audit per-fn verb-usage row lists the count of each verb
used in the function body: `{|>: 3, ~>: 1, <~: 0, ...}`.

**AT-VK5.** A `PForward` pipe that was lowered to `LCall` — the
query handler still returns `Some(PForward)` because it reads the
AST, not the LowIR.

---

## §6 Scope + peer split

| Peer | Surface | Load |
|---|---|---|
| VK.1 | `pipe_topology` query op + handler arm | Light (~25L query.mn) |
| VK.2 | Hover formatting for verb identity | Light (~20L hover handler) |
| VK.3 | Audit verb-usage row | Moderate (~30L audit handler) |

Total: ~75 lines. Three commits, VK.1 first (unblocks VK.2/VK.3).

---

## §7 Dependencies

- **Upstream:** none. Standalone primitive #3 work.
- **Downstream:** MV.2's Topology tentacle reads VK-preserved verb
  identity. Audit per-fn reports gain verb-topology columns post-VK.
  LF (feedback lowering) walkthrough depends on VK for the feedback
  verb's identity to round-trip.

---

## §8 What VK refuses

- **Duplicating PipeKind into LowIR.** Intent reads from the AST;
  LowIR speaks mechanism. The separation is the IR discipline's
  core invariant (IR §7: "intent preservation MUST NOT alter
  normalization results inference depends on").
- **Treating |> as "just a function call."** `|>` IS a function call
  at the mechanism layer. But it is a TOPOLOGY at the intent layer —
  the developer wrote it because the data flows left to right. The
  medium speaks both layers; VK preserves the one that matters to
  humans.
- **Per-verb LowIR variants.** LowIR's 24 variants serve emit.
  Adding 5 more for hover to read is substrate confusion — hover
  should read the authored form, not a parallel copy.

---

## §9 Connection to the kernel

- **Primitive #3** substrate gains an intent layer. Every verb the
  developer types is queryable at every downstream surface.
- **Primitive #1** (graph) — the handle on every PipeExpr node IS
  the access path. `pipe_topology(handle)` is a graph read, not a
  traversal.
- **Primitive #7** gradient — verb suggestion: Mentl's Teach can
  say "this nested call pattern reads as |> — refactor for topology
  clarity" when the function uses nested calls instead of pipes.
- **Mentl tentacle Topology** reads VK to surface verb identity
  in hover and teach. One verb per turn; the verb IS the topology.
