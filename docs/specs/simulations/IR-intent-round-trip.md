# IR — Intent Round-trip Discipline Across the Kernel

*Meta-walkthrough. Names the principle; indexes the eight peer
walkthroughs that apply it (EN · RN · OW · VK · GR · RX · HI · DS);
establishes the invariant every Phase II handler-projection surface
depends on.*

**Status: 2026-04-22 · seeded.** Derived from the EN finding
(`docs/specs/simulations/EN-effect-negation.md`) that primitive #4's
explicit `!E` is algebraically collapsed at normalization, losing
authored intent. The pattern recurs across the kernel; IR names the
discipline and gates every Phase II handler-projection arc (MV.2, LSP,
audit, hover) on intent substrate first.

---

## §1 Principle

**Every primitive's authored form round-trips to every handler
projection surface.**

Distinguish:

- **Semantic substrate** — what the machine needs to execute
  correctly (unified types, normalized rows, resolved names, lowered
  IR, emitted bytes).
- **Intent substrate** — what the developer meant (authored aliases,
  explicit negations, verb identities, annotation history, capability
  vocabulary, ownership stance, docstrings).

Current compiler: semantic substrate is strong (that's what inference
+ lowering produce). Intent substrate is partial — parts preserved on
the AST, parts dropped at normalization, parts never entered the graph
at all.

**Handler projection surfaces that read intent:**

- Mentl (teach, audit, voice per MV-mentl-voice.md)
- LSP hover
- `mentl audit` reports
- Error messages / diagnostics
- Gradient next-step suggestions
- Capability graphs
- Documentation generation

Each surface fails or becomes low-fidelity when intent is lost
upstream. "Type mismatch" → generic mechanism. "Your `Port` refinement's
upper bound failed for literal 70000" → intent-shaped. The quality
delta IS the round-trip.

---

## §2 The eight peer clusters

| Handle | Primitive | Gap | Walkthrough |
|---|---|---|---|
| **EN** | #4 effect algebra | Explicit `!E` collapses at `normalize_inter`; lone `!E` over-broad; no named capability bundles | [EN-effect-negation.md](EN-effect-negation.md) |
| **RN** | #6 refinements | Alias name dropped post-normalize; diagnostics speak predicate instead of alias | [RN-refinement-alias.md](RN-refinement-alias.md) |
| **OW** | #5 ownership | `own` / `ref` flatten to effect row; diagnostics speak `Consume` instead of "consumed" | [OW-ownership-intent.md](OW-ownership-intent.md) |
| **VK** | #3 five verbs | Verb identity flattens in LowIR; hover / audit speak control-flow instead of "feedback" | [VK-verb-kind.md](VK-verb-kind.md) |
| **GR** | #7 gradient | Inferred-vs-declared delta unqueryable; Mentl can't teach "one next annotation" | [GR-gradient-delta.md](GR-gradient-delta.md) |
| **RX** | #8 reasons | Reasons mixed high-intent vs low-intent (mechanism); audit pass needed | [RX-reason-intent.md](RX-reason-intent.md) |
| **HI** | #2 handlers | Provider-handler identity lost at op-call; hover can't name "which handler provided this" | [HI-handler-identity.md](HI-handler-identity.md) |
| **DS** | cross-cutting | Docstrings discarded at lex; never enter the graph as Reason edges | [DS-docstring-edge.md](DS-docstring-edge.md) |

Each handle resolves its design questions and enumerates commit-sized
peer sub-handles.

---

## §3 Recommended landing order

Not strict dependency — parallelizable by crew. Leverage ordering:

1. **EN** (seeded 2026-04-22) — biggest single gap; drives most
   capability-vocabulary work. Four peers (α γ δ β) + MV.2.cap.
2. **RN + OW** (parallel) — primitive #5 and #6 nearest applied
   exemplars. FV.3.x (RN consumer) and FV.4 (OW consumer) already
   touch them.
3. **RX** — audit sweep across existing Reason sites; doesn't extend
   the graph, upgrades what's there. Low risk; high propagation
   (every diagnostic improves).
4. **VK** — load-light; unlocks verb identity in hover / audit.
5. **GR** — moderate; prerequisite for MV.2's teach arm.
6. **HI** — moderate; prerequisite for LSP hover's handler-naming +
   handler-stack error messages.
7. **DS** — moderate; unlocks docstring-to-Mentl flow. Least blocking;
   most visible to users.

**Phase II handler-projection work (MV.2 / LSP / audit / capability
graph) GATES on:**

- EN.α + EN.δ → capability-vocabulary surfacing.
- RN → alias-named diagnostics / hover.
- OW → ownership-named diagnostics / hover.
- RX → every Reason-touching surface.
- GR → Mentl teach arm's "next step" query.
- HI → LSP hover's handler-provider display.
- DS → docstring flow to Mentl / hover / audit.

Currently Phase II is queued as "handler projections on existing
substrate." The IR discipline names that "existing substrate" is
partial — eight substrate gaps must close before the handler
projections are high-fidelity.

---

## §4 Invariant

**Every annotation a developer types round-trips to every handler
projection surface that touches that annotation's scope.**

- Write `own` → hover + errors + Mentl name the ownership stance.
- Write `type Port = Int where ...` → hover + errors + Verify name
  "Port" when it's the relevant reference.
- Write `<~` → hover + audit identify the feedback topology.
- Write `with RealTime` → hover + audit + Mentl speak "real-time"
  (post-EN).
- Write `/// Charges the card; idempotent across retries.` → Mentl's
  teach surfaces relevant lines (post-DS).
- Write nothing → Mentl's gradient suggests the highest-leverage next
  annotation (post-GR).

When any of these fails — the annotation was authored but the surface
shows mechanism instead of intent — that is an IR leak. The pattern
is the leak. Naming it IS the discipline.

---

## §5 Mentl's dependency

Mentl's voice per MV-mentl-voice.md §2.7 surfaces ONE load-bearing
capability per turn. Her ability depends on intent substrate being
queryable — she cannot surface "real-time" if the substrate only knows
"closed row excludes Alloc."

**IR is Mentl's substrate precondition.** Her eight tentacles each
read intent at a specific primitive:

| Tentacle | Primitive | Walkthrough read |
|---|---|---|
| Query | #1 graph | everything (cross-cutting) |
| Propose | #2 handlers | HI |
| Topology | #3 verbs | VK |
| Unlock | #4 effects | EN |
| Trace | #5 ownership | OW |
| Verify | #6 refinements | RN |
| Teach | #7 gradient | GR |
| Why | #8 reasons | RX |

One primitive per tentacle; one intent gap per primitive; one peer
walkthrough per gap. The 1-to-1-to-1-to-1 maps close.

DS is cross-cutting — docstrings attach to any primitive's declaration
site; every tentacle reads DS-edges when present.

---

## §6 Acceptance — the invariant in practice

**AT-IR1.** For any annotation the developer types across all eight
primitives, `perform intent_of(handle)` returns a structured record
preserving the authored form. No alias-dropping; no row-collapsing;
no annotation-flattening.

**AT-IR2.** Every error diagnostic surfaces in authored vocabulary
(alias names, capability names, annotation names, verb names,
docstring quotes) rather than mechanism vocabulary (TVar handles,
raw effect names, control-flow node kinds, lowered IR nodes).

**AT-IR3.** Mentl's teach surfaces the highest-leverage next
annotation per turn (MV.2 AT4). Dependencies upstream: GR for delta
queries; RN / OW / EN / DS for vocabulary.

**AT-IR4.** LSP hover on any identifier reflects authored form
(RN refinement names, EN capabilities, OW ownership, HI handler
identities, VK verb topology, DS docstrings) plus optionally the
normalized / resolved form below.

**AT-IR5.** `mentl audit` reports speak capability-stance vocabulary
per fn and per module. Audit rows name (via IR): capability stance
(EN.δ), ownership stance (OW), feedback structure (VK), handler chain
(HI), declared-vs-inferred delta (GR), refinement aliases in use (RN).

**AT-IR6.** Round-trip invariant — any intent a developer types
appears unchanged in at least one handler projection surface's
rendering of that scope.

---

## §7 What IR refuses

- **"Fix the handler projection" without fixing the substrate.** A
  polished Mentl voice line built atop a row-collapsed substrate
  speaks mechanism dressed as intent. Drift mode 9 at the surface.
- **"Close one round-trip at a time without naming the pattern."** Each
  peer resolves one gap, but the principle is systemic. Losing the
  systemic lens means future primitives added to the kernel won't
  automatically inherit the discipline.
- **Over-engineering intent storage.** Most intent already exists on
  the AST; the work is often surfacing, not duplicating. Candidate
  choices across the peers bias toward query-handlers reading
  existing nodes over parallel stores.
- **Breaking semantic substrate.** Intent preservation MUST NOT alter
  normalization results inference depends on. Intent is an overlay;
  semantics is the structure. Normalization continues to compute what
  it computes; intent queries read what was authored before
  normalization ran.

---

## §8 Residue

*The medium Mentl speaks of must be the medium Mentl is.*

At primitive #2 the developer sees the handler chain; hover names the
provider. (HI)

At primitive #3 the developer writes `<~`; LowIR realizes it; audit
names the feedback. (VK)

At primitive #4 the developer writes `with RealTime`; Mentl understands
it; Mentl speaks it. (EN)

At primitive #5 the developer writes `own`; Mentl proves linearity;
errors speak it. (OW)

At primitive #6 the developer writes `type Port`; Mentl validates by
predicate; hover names it. (RN)

At primitive #7 the developer writes nothing; Mentl teaches what would
help next. (GR)

At primitive #8 the developer reads a Reason and sees their own
vocabulary reflected back. (RX)

Across everything the developer's `///` docstrings live in the graph.
(DS)

**One round-trip per primitive. One medium, writing and reading itself
in one vocabulary.**
