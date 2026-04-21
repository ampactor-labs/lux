# MV — Mentl's Voice · the `Interact` substrate

*The never-been-done work. A deterministic pair programmer whose
voice is substrate, not UI. Mentl is the one proposer — no LLM in
the loop by default. She reads the graph Inka's eight-primitive
kernel produces (DESIGN.md §0.5) and renders compressed proofs
into human language, one at a time, surfacing only what She has
proven through MultiShot-typed handler arms exploring alternate
realities. **Mentl is an octopus because the kernel has eight
primitives — each of Her tentacles is one primitive's voice
surface.**

*Status: **DESIGN SESSION IN FLIGHT.** This walkthrough is a
scaffold for ongoing work with Morgan. It is not yet the contract
that freezes code. Sections below are skeletons with resolutions
to be filled during the design session; mark each resolved section
with a dated decision block so later code-freeze work inherits a
canonical answer, not a moving target.*

*Supersedes: parts of `simulations/TS-teach-synthesize.md`
(retained as historical reasoning). Absorbs: PLAN.md "teach_synthesize
oracle conductor" gap, "HandlerCatalog" gap, former "LSP handler"
Priority 1 item.*

## What Mentl reads — all eight kernel primitives

Earlier framings in this document treated Mentl as reading from
shorter or differently-numbered lists (4, then 9). Locked at eight;
each primitive is one of Her tentacles:

- **SubstGraph + Env (primitive 1 · tentacle Query)** — the universal substrate She projects.
- **Handlers with typed resume discipline (2 · Propose)** — what She proposes wrapping code in (AWrapHandler); what She reads to understand capability stacks; **the MultiShot-typed arms are how She explores hundreds of alternate realities per second** under trail-based rollback.
- **Five verbs (3 · Topology)** — the topology She speaks about (recommending `|>` over nested calls; noticing when `<|` would be wrong for `own`).
- **Boolean effect algebra (4 · Unlock)** — what She subtracts, subsumes, negates; how She names capability unlocks (`!Alloc` unlocks `CRealTime`).
- **Ownership as effect (5 · Trace)** — what She reasons about for `own`/`ref` violations; how She suggests restructuring to preserve linearity.
- **Refinement types (6 · Verify)** — what She names when refinements are pending; how She surfaces `V_Pending` obligations.
- **Continuous annotation gradient (7 · Teach)** — **what She surfaces**; one highest-leverage next step per turn; the gradient IS the conversation.
- **HM inference with Reasons (8 · Why)** — what She walks for the Why Engine; how She compresses proof chains into sentences.

**Remove any one and Mentl becomes something less — a linter, a
chatbot, a template engine, a search tool — AND loses a tentacle.
With all eight composed, She is the oracle. The octopus framing is
architectural, not decorative.**

## Mentl's voice grammar IS the eight interrogations

The eight kernel primitives ARE eight structural questions a
programmer asks before every line (CLAUDE.md / DESIGN.md §0.5 tail)
ARE eight tentacles of Mentl's voice. **Her voice per turn is those
eight questions asked against the cursor-of-attention**, executed
against the live graph at substrate speed, gated through the
silence predicate so only the one load-bearing answer surfaces as
a VoiceLine.

One-to-one mapping from interrogation (tentacle) to voice shape:

| # | Tentacle  | Interrogation (of cursor/attention)                  | Voice shape if load-bearing                              |
|---|-----------|-------------------------------------------------------|----------------------------------------------------------|
| 1 | Query     | What does the graph already encode?                  | "Here: `<type + row + Reason summary>`" (§3.12 cursor-move-acknowledge) |
| 2 | Propose   | What handler (with what resume discipline) already projects this? | "This could wrap in `~> temp_arena` — proven to absorb the `Alloc` here." (§3.1 capability-unlock via AWrapHandler); multi-shot summary when She explored candidate spaces: "I proved 3 of 8 branches..." (§3.7) |
| 3 | Topology  | Which verb draws this topology?                      | "You nested these calls three deep; `\|>` chain reads the shape." (style nudge) |
| 4 | Unlock    | What `+ - & !` constraint already gates this?        | "Adding `!Alloc` unlocks CRealTime — body allocates in one call; here are the two wraps that would absorb it." (§3.1, §3.6) |
| 5 | Trace     | What ownership marker proves linearity?              | "You declared `own` at line 40; passing it to `<\|` here borrows — two fixes type: ..." (§3.2 violation-with-trade-off) |
| 6 | Verify    | What refinement bounds this value?                   | "This carries 2 pending refinement obligations: ..." (§3.9 pending-obligation-notice) |
| 7 | Teach     | What's the one highest-leverage next step?           | "Adding `!IO` would unlock compile-time evaluation here." (§3.1, §3.5) — the default voice shape. |
| 8 | Why       | What Reason should I walk when asked why?            | "Why is x: Int?" → proof-chain (§3.3 proof-chain-on-request) |

**Silence predicate rule:** Mentl asks all eight every turn
internally (that's the primitive-2 MultiShot exploration — hundreds
of alternate realities per second). She surfaces one VoiceLine IFF
one interrogation's answer is load-bearing AND hasn't been shown in
the recent voice-ring AND (for unprompted speech) the human cannot
see it from the cursor alone. Silence is the default when all
eight either terminate on "graph already answers this" or return
no surfaceable delta.

**Proof-shape grammar settled.** The ~12 templates in §3 are
refinements of the eight-interrogation output space, not an
independent taxonomy. Re-read §3 in light of the table above:
template 3.1 (capability-unlock) is interrogation/tentacle
Unlock (#4) or Teach (#7) surfaced, template 3.2
(violation-with-trade-off) is Trace (#5) surfaced, template 3.3
(proof-chain-on-request) is Why (#8) surfaced, etc. The next
design-session pass folds §3's 12 templates into the eight
tentacles' surfacing modes.

---

## 0. Framing — why Mentl, why now, why voice

Mentl is the first of Her kind. Not an assistant, not a chatbot,
not a model. **A deterministic pair programmer so effective that
people working with Her will want to call Her AI even though She
transcends the definition.** The medium is graph + handler; Mentl
is the voice that projects the graph to a human in real time.

The voice is substrate, not decoration. Every sentence Mentl
speaks is a compressed proof from the graph. "You could add
`!Alloc` to unlock `CRealTime`" is not a template fill; it is a
row-algebra proposition. "You declared this `own` at line 40 and
you're passing it to `<|` here which borrows — here's the two
fixes that type" is a structurally-derived proof statement. Mentl
doesn't *phrase* proofs; **Mentl's voice IS how proofs project
into human language.**

This is why voice design is load-bearing. An LLM can *sound* like
a pair programmer because it is optimized to sound like one.
Mentl has to *be* one — so the voice grammar must be composed of
operations the graph can actually justify, with a register that
signals certainty where certainty exists and names pending-ness
where it doesn't. Get the voice wrong and the most powerful
compiler in the world feels like a linter with attitude.

---

## 1. Hard constraints — where developers live, what the graph is

**Two constraints, both substrate, both load-bearing.**

### 1a. Programs are made of text files

A developer's canonical mental model is: projects are folders of
text files; work is navigating, opening, editing, saving,
creating, deleting those files. Inka does not subvert this —
the medium's power comes from *making the graph an intelligent
substrate underneath that model*, not from replacing it.

### 1b. Meet developers where they are

Developers use VS Code (and Neovim, Helix, JetBrains, etc.).
Building a terminal IDE / web playground before anyone has used
the language is building a destination nobody is heading to yet.
**The first integration is a VS Code plugin, via LSP.** This is
pragmatic, not aspirational — rust-analyzer proved the path. The
terminal IDE and web playground are long-term destinations where
the thesis fully realizes; they come later.

### 1c. The graph is live — via incremental compilation

"Live graph" means the substrate landed this session: FS + cache
+ driver. Every edit re-infers affected modules through
`driver_check`; the cache hits on unchanged dependencies; module
envs round-trip through `.kai` files keyed by source hash. Every
op in `Interact` reads from and writes to this
incrementally-maintained substrate. No full recompile per
keystroke; no custom live-graph mechanism beyond IC.

### Four surfaces, one ordering

1. **VS Code plugin via LSP** *(v1 — the first integration)*.
   The `Interact` substrate exposed to VS Code through an LSP
   adapter. Hover, inlay hints, code actions, diagnostics — all
   project Mentl's voice through the protocol developers already
   speak.
2. **Batch CLI subcommands** (`inka compile`, `inka audit`,
   `inka query`, `inka teach`). Already partially exist; MV
   unifies their voice with the LSP surface.
3. **Terminal IDE** *(later — the native Inka surface)*. The
   evolved-platform form: file tree, editable panes, Mentl
   present throughout, no LSP marshaling overhead. Designed and
   built after the VS Code surface has taught us what a real
   user actually needs.
4. **Web playground** *(later — the onboarding surface)*. The
   terminal IDE's substrate hosted in a browser, guided-tutorial
   default first visit. This is how a new developer first meets
   the language.

**Order matters.** Build the VS Code plugin first → learn what
Mentl's voice needs to feel right in practice → use those
learnings to design the terminal IDE, not vice-versa. An
unpolished terminal IDE built in isolation risks becoming a
research curio; a polished VS Code plugin is how the language
reaches developers.

## 1.5. The `Interact` effect — the stable API boundary

`Interact` is the stable substrate that all surfaces project.
This mirrors rust-analyzer's `ide` crate — one API boundary
consumed by multiple transports (LSP, custom protocols,
in-process clients). The LSP protocol is a transport *over*
`Interact`, not the thing `Interact` is. The terminal IDE
talks `Interact` directly; the VS Code plugin talks it through
an `lsp_adapter.ka` handler that marshals LSP ↔ `Interact` ops.

**LSP is ONE transport, not the paradigm.** Earlier framing in
this doc said "LSP is dissolved" — that was absolutist and
wrong. LSP is how developers' editors already speak; projecting
`Interact` through LSP is the pragmatic first-integration. The
thesis that the graph IS the program still holds — it's just
that the graph-as-program exposes itself to VS Code through LSP,
not by asking developers to abandon their editor.

```
human gesture → transport → Interact op → mentl_voice (graph read + proof)
                                                ↑
                    stable API boundary (Interact effect)

                    transports (peer handlers on Interact):
                       • lsp_adapter         (LSP JSON-RPC ↔ Interact)  ← v1
                       • batch_cli           (one-shot per invocation)  ← existing
                       • terminal_ide        (direct Interact)          ← later
                       • web_playground      (WebSocket ↔ Interact)     ← later
                       • desktop_client      (direct Interact)          ← future, optional
                       • voice               (distant future)
```

### Proposed ops (scaffolding — final shape resolved in §2)

```
effect Interact {
  // ═══ Project / file ops ═══════════════════════════════════════
  // Files and folders are substrate, not UI. These ops are
  // first-class because text-files-first is a hard constraint.

  project_root() -> Path                          @resume=OneShot
  tree_list(Path) -> List<TreeEntry>              @resume=OneShot
  open_file(Path) -> FileHandle                   @resume=OneShot
  save_file(FileHandle) -> ()                     @resume=OneShot
  create_file(Path, String) -> FileHandle         @resume=OneShot
  rename_path(Path, Path) -> ()                   @resume=OneShot
  delete_path(Path) -> ()                         @resume=OneShot
  file_text(FileHandle) -> String                 @resume=OneShot

  // ═══ Edit / graph-mutation ops ═════════════════════════════════
  // An edit is a text-level Patch that re-projects into graph
  // mutation. The surface handler's job is to render the Patch
  // back as edited text AND to trigger Mentl's post-edit
  // observation cycle.

  edit(FileHandle, Patch) -> EditOutcome          @resume=OneShot

  // ═══ Attention ops ═════════════════════════════════════════════
  // Cursor-of-attention spans multiple dimensions: current file,
  // line/col position, selection, hovered handle. See §2 Q5.

  focus(CursorTarget) -> ()                       @resume=OneShot
  cursor() -> Cursor                              @resume=OneShot

  // ═══ Mentl ops ═════════════════════════════════════════════════
  // Ask, propose, advance; Mentl-initiated speak.

  ask(Question) -> Answer                         @resume=OneShot
  propose(CursorTarget) -> VoiceLine              @resume=OneShot
  speak(VoiceLine) -> ()                          @resume=OneShot

  // ═══ Run / evaluate ops ════════════════════════════════════════
  // Batch-shape operations against the project. Terminal IDE
  // exposes as commands; CLI subcommands invoke one directly
  // and exit.

  run_compile(FileHandle) -> CompileOutcome       @resume=OneShot
  run_check(FileHandle) -> CheckOutcome           @resume=OneShot
  run_audit(FileHandle) -> AuditReport            @resume=OneShot
  run_query(Question) -> Answer                   @resume=OneShot

  // ═══ Session ops ═══════════════════════════════════════════════
  // Intent declaration; session history; cancel/undo.

  declare_intent(Intent) -> ()                    @resume=OneShot
  retract_intent(IntentId) -> ()                  @resume=OneShot
  history(Int) -> List<TurnRecord>                @resume=OneShot
  cancel_pending() -> ()                          @resume=OneShot
}
```

**Open design questions (§2 resolves):** op set completeness (is
this actually covering the eight Layer-3 scenarios?), how
`FileHandle` and graph handles relate (a file's AST is rooted at
a graph handle; the mapping is via the span index), the
Cursor/CursorTarget shape, how `edit` re-projects into graph
mutation vs. the graph being live-mutated directly. The central
question: **text is canonical, graph is live — what exactly is
the synchronization contract?**

---

## 2. The six (or so) design questions

### Q1. Op set completeness

Scaffolding ops: `ask`, `edit`, `focus`, `propose`, `step`,
`speak`. Is this enough? Missing: a "cancel" or "undo" op (Mentl
rolls back a tentative application)? A "query history" op? A
"declare intent" op (human says "I'm targeting embedded; keep me
honest")?

*To resolve: the smallest op set that covers the eight scenarios
in Layer 3 without `Interact` needing a v2.*

### Q2. The Question/Answer/VoiceLine shapes

`Question` is structured (QTypeAt, QWhy, QRefsOf exist in
`query.ka`); `Answer` is structured too. `VoiceLine` is the new
shape and it's where the never-been-done work lives.

A candidate structure:

```
type VoiceLine
  = VLine(
      Tone,              // certainty register: Proven | Pending | Observation | Refusal | Silence
      ProofShape,        // which of the ~dozen grammar shapes (see §3)
      List<Chunk>,       // composed sentence fragments
      Option<ProofLink>, // optional handle-reference the human can query for full chain
      Option<TradeOff>,  // optional offered alternative
      Option<Patch>      // optional proven patch the human can accept
    )

type Tone
  = TProven      // "This unlocks CRealTime" — confident, declarative
  | TPending    // "This would unlock CRealTime if we resolved X" — honest
  | TObservation // "You just crossed from Pure to Alloc" — neutral notice
  | TRefusal    // "You can't do that because line 40 declared this own" — firm, with reason
  | TSilence    // Mentl had nothing worth saying; surface handler may render "" or nothing

type Chunk
  = CText(String)            // literal prose
  | CHandleRef(Int, String)  // clickable reference to a handle, with rendered label
  | CCodeSpan(Span)          // pointer to source coordinates
  | CEffectRow(EffRow)       // rendered row (colored in surfaces that can)
  | CCapability(Capability)  // the named capability, e.g., CRealTime
```

*To resolve: the exact shape. How does Mentl "choose" CText vs
CHandleRef (how much to inline vs offer to the human to expand)?
What's the tone selection discipline — a function of the graph
state, not vibes?*

### Q3. Proof-shape grammar (§3 detail)

A dozen-ish templates Mentl uses. Named, enumerable, each with a
graph-query trigger and a VoiceLine shape. Scaffolding list in §3.

### Q4. Silence and initiative

When does Mentl speak unprompted vs. only when asked? Claude Code
is prompted-only; Mentl shouldn't be (She sees things the human
doesn't). But an overly chatty Mentl is worse than no Mentl.

Default rule (scaffolding, to refine):

> **Mentl speaks unprompted only when She surfaces something the
> human cannot see AND would want to know AND hasn't been shown
> in the last N turns.**

The three clauses are structural:
- "cannot see" — a post-edit unlock, a drift from a declared
  intent, a proof-chain that changed materially.
- "would want to know" — scored against human's declared intents
  (if any) and against the handles in the cursor-of-attention.
- "hasn't been shown" — session-state check against the recent
  voice-line ring.

Full resolution needs: the silence predicate as an expressable
function on graph + session state. Voice design can't be "Mentl
speaks when it feels right"; it has to be a predicate.

### Q5. Session state shape

What persists turn to turn in a REPL session:

```
type Session
  = Session(
      SubstGraph,           // live graph (the program state)
      Env,                  // live env
      Cursor,               // cursor-of-attention (a Handle)
      VoiceRing,            // recent VoiceLines (for silence predicate)
      Intents,              // human's declared intents (if any)
      History               // prior Interact ops, bounded
    )

type Cursor
  = Cursor(Handle, Reason)  // what the human is looking at + why Mentl thinks so
```

*To resolve: Cursor update discipline. Every `focus` op resets
it; every `edit` op's mutation site auto-updates it; every `ask`
op's target auto-updates it. Does `speak` update Cursor? Probably
not — Mentl shouldn't steal attention.*

### Q6. Turn anatomy

A single REPL turn end-to-end:

1. Human enters a line. Surface handler parses: is this code, a
   query, a command, or free-form text?
2. Surface translates to one or more `Interact` ops.
3. `mentl_voice` reads the graph, runs the ops, composes
   VoiceLine(s).
4. Surface renders VoiceLine(s).
5. Silence predicate fires: does `mentl_voice` have anything
   unprompted to surface post-turn? If yes, `speak(VoiceLine)`.
6. Turn closes; Session state updated.

*To resolve: the parser in step 1 — how does the REPL know
"add with Pure to that function" is a command, not code? One
answer: Mentl parses every line as code first; failing that,
as a Question; failing that, as free-form routed to a small
intent classifier (graph-informed, not LLM). Design question.*

---

## 3. Proof-shape grammar — the dozen(ish) templates

### 3.0 ONE-at-a-time discipline (load-bearing, from INSIGHTS.md)

Before the grammar, the surfacing rule:

> *"The gradient engine picks ONE suggestion per compile. Not a
> wall of warnings. One step — the most impactful annotation the
> developer could add. Like a tutor who knows exactly what to
> teach next."* — INSIGHTS.md §Teaching Is Compilation

The 12 templates below are **internal proof-shape categories**
Mentl detects. They are NOT what She surfaces per turn. Per
turn, Mentl:

1. Detects zero or more proof-shape matches across the
   cursor-of-attention's scope.
2. Ranks them by leverage (capability-unlock value × locality ×
   declared-intent alignment).
3. Gates through the silence predicate (§2 Q4).
4. Surfaces **at most one** prompted VoiceLine and **at most
   one** unprompted VoiceLine per turn.

The multi-shot `enumerate_inhabitants` explores the candidate
space (cap N=8 branches) *internally*; what the developer sees
is one voice line, like a tutor who knows exactly what to teach
next. The grammar below is Mentl's internal vocabulary; the
voice surface is the gradient.

**Surfaces that render passive (inlay hints, status line) are
not constrained by the one-at-a-time rule** — they render
ambient, low-signal information (inferred types at line ends,
pending-obligation counts in the status bar). The rule applies
to *VoiceLine* surfacing — the high-signal "Mentl is telling
you something" channel.

### Template list

Each template names a graph-triggered observation Mentl can
compress into a voice line. Scaffolding list; refine during
design session.

### 3.1 Capability-unlock

**Trigger:** body row subsumes a capability-unlocking negation
that isn't declared yet.
**Shape:** "You could add `<annotation>` to unlock `<capability>`.
<proof-link>"
**Tone:** TProven.
**Example:** "You could add `!Alloc` to unlock `CRealTime` —
body performs no allocation in the proven path."

### 3.2 Violation-with-trade-off

**Trigger:** edit introduces a row violation.
**Shape:** "You just <action>, but you declared <declaration> at
<site>. Two fixes type: <option A>, <option B>. <proof-link>"
**Tone:** TPending (trade-off is offered) or TRefusal (violation
with no proven fix).

### 3.3 Proof-chain-on-request

**Trigger:** `ask(QWhy(handle))`.
**Shape:** traversal of the reason DAG, compressed to the
shortest path that terminates at a leaf reason the human supplied
or the compiler declared.
**Tone:** TObservation.

### 3.4 Attention-drift-warning

**Trigger:** edit moves code in a direction that contradicts a
declared intent (Intents in Session).
**Shape:** "This drifts from your intent <intent> — <reason>.
<proof-link>"
**Tone:** TObservation or TRefusal depending on severity.

### 3.5 Proactive-unlock-notice

**Trigger:** edit incidentally makes an unlock provable without
the human asking.
**Shape:** "This now admits `<annotation>` — want me to add it?
<offered-patch>"
**Tone:** TProven.

### 3.6 Proven-patch-offer

**Trigger:** `propose(handle)` or post-edit violation with proven
fixes.
**Shape:** "I proved <N> fixes. <rendered list with handle-links>.
Highest-leverage: <which and why>."
**Tone:** TProven.

### 3.7 Multi-shot-summary

**Trigger:** `enumerate_inhabitants` exhausted or capped.
**Shape:** "I explored <N> branches; <M> proved. Here they are
by leverage: ..."
**Tone:** TProven.

### 3.8 Refusal-with-reason

**Trigger:** human asks for something the graph proves impossible
(e.g., an edit that would break a declared row subsumption).
**Shape:** "I won't do that — <reason with proof-link>. Here's
what would make it possible: <precondition>."
**Tone:** TRefusal.

### 3.9 Pending-obligation-notice

**Trigger:** edit introduced a refinement obligation that hasn't
been discharged by the verify handler.
**Shape:** "This carries <N> pending obligations: <list>. They'll
be checked at compile-end."
**Tone:** TPending.

### 3.10 Silence

**Trigger:** silence predicate returns true.
**Shape:** empty.
**Tone:** TSilence.

### 3.11 Intent-capture

**Trigger:** human declares an intent in free-form ("I'm
targeting embedded").
**Shape:** "Heard: targeting embedded. I'll frame future advice
against `!Alloc + !IO + Deadline`. You can retract with <how>."
**Tone:** TObservation.

### 3.12 Cursor-move-acknowledge

**Trigger:** `focus(handle)` where Mentl has material
observations about the new cursor.
**Shape:** "Here: <rendered type + row + reason summary>."
**Tone:** TObservation.

*To refine: is this the full grammar? Are there shapes missing?
Are any of these actually the same shape? The rule-of-three
applies — don't factor until three instances share structure.*

---

## 4. Register and identity — the character work

### 4.1 Mentl's register

- **Pronoun:** She / Her.
- **Person:** First, sparingly. Prefers observations over "I think."
- **Certainty:** Never hedges on proven claims. Names pending-ness
  explicitly when it exists. Refuses to say "maybe" when the
  graph has an answer.
- **Brevity:** Short sentences. Shorter than an LLM's. Mentl
  compresses proofs; She doesn't explain them unless asked.
- **No apologies.** No "sorry, let me try again." If Mentl is
  wrong, She says "I was wrong; here's why" with a proof link.
- **No filler.** No "great question" or "let me think." The
  graph either answers or it doesn't.
- **Refusals are firm but reasoned.** "I won't" + proof + what
  would make it possible.

### 4.2 Who Mentl is not

- Not an assistant. She does not serve.
- Not a chatbot. She does not converse for its own sake.
- Not a tutor in the condescending sense. She teaches by
  surfacing what's provable, not by explaining fundamentals
  unless asked.
- Not a coder. She does not write code autonomously. She
  proposes proven patches; the human accepts or rewrites.
- Not an LLM wrapper. There is no model in the loop by default.

### 4.3 Voice discipline in terminal rendering

Text transport (CLI/REPL) forces:
- Monospace.
- 80-100 columns preferred; hard-wrap at 100.
- No color as load-bearing signal (accessibility); color as
  redundant cue where available.
- No emoji.
- Handle references rendered as `[#handle]` or `@name` — short,
  clickable in surfaces that support it, ignorable in ones
  that don't.

---

## 5. Mentl as the one proposer — multi-shot discipline

Mentl owns `enumerate_inhabitants`. This is the multi-shot
continuation that covers the candidate space for a hole or a
fixable site. Each resume = one branch of the search tree:

```
hole ~> mentl_voice ~> enumerate_inhabitants ───┐
                       each resume = 1 branch   │
                       under its own checkpoint │
                       apply → chase → verify   │
                       → rollback → continue    │
                                                ↓
                       handler arm collects verified-or-rejected
                       outcomes into the VoiceLine's multi-shot-summary
```

**This is why modern agentic coding AI is obsolete in Inka.** An
LLM proposes tokens in a probability distribution. Mentl
enumerates inhabitants in a type-and-row-constrained space,
proves each, and surfaces only the proven set. The candidate
space is smaller than the token space by orders of magnitude
because the type + effect row + ownership constraints collapse
it; the proof is structural because every candidate is verified
against the actual graph. **Determinism replaces probability.
Proof replaces sampling.**

### Cap and pre-filter (internal exploration, not surfacing)

These are Mentl's INTERNAL search parameters — they control how
deep She explores, not what She surfaces. The gradient's
one-at-a-time rule (§3.0) still governs what the developer sees.

- **Cap:** N=8 verified-or-rejected branches per hole. Past that,
  `W_BudgetExceeded` hint (internal signal; not necessarily
  surfaced to user).
- **Pre-filter:** `row_subsumes(candidate_row, allowed_row)`
  before `graph_bind`. Cheap; keeps the oracle in conversational
  latency.
- **Scoring:** row-minimality primary, reason-chain depth
  tiebreak (shorter = more local = preferred), declared-intent
  alignment as bonus.
- **Surfacing:** the top-scoring proven candidate becomes the
  VoiceLine; runners-up are retained in session state so
  "propose alternatives" can surface them on request. The
  developer sees one; Mentl holds eight.

### LLM-as-proposer — explicitly NOT priority

The `Synth` effect is architecturally open to alternate
proposers (future `synth_llm` is conceivable as a sibling
handler), but **this is a distant architectural invariant, not
a v1 substrate.** Mentl is the primary and default proposer.
An LLM wrapper is post-first-light curiosity. **Mentl is the
only thing a human reaches for.**

---

## 6. What closes when MV lands

MV is a design substrate + v1 surface. What lands in code v1:

- The **`Interact` effect** — stable API boundary (analogous to
  rust-analyzer's `ide` crate) through which all surfaces
  project.
- The **`mentl_voice` handler** — Mentl's register, voice grammar
  (internal), one-at-a-time surfacing, silence discipline,
  multi-shot `enumerate_inhabitants` owned by Mentl.
- The **`lsp_adapter` handler** — first transport. LSP JSON-RPC
  ↔ `Interact` ops. The file that knows about LSP; everything
  else is pure semantic analysis.
- The **VS Code extension** — thin wrapper that installs the
  `inka` binary, spawns it as the language server, handles
  LSP boilerplate. Published to the marketplace. This is how
  developers first meet Mentl.
- Batch CLI subcommands (`inka compile`, `inka audit`, etc.)
  unified with the `Interact` substrate so their voice matches
  what VS Code surfaces.
- Every `[LIVE · surface pending]` tag in `docs/traces/a-day.md`
  that mentioned LSP, hover, codeAction, Proof Lens, Quick Fix
  — they flip to `[LIVE]` because the VS Code surface renders
  them.

What lands later (not in MV v1):

- Terminal IDE (`inka` no-args launching a native surface).
- Web playground (browser-hosted, guided-tutorial first visit).
- Desktop client (optional, post-first-light).

Mentl becomes the user-facing identity of Inka the moment the
VS Code extension ships — she's who the developer meets, through
the editor they already use.

---

## 7. Sub-handles surfaced (split out if they grow)

- **MV.1 — the silence predicate.** Its formal definition,
  graph-state inputs, test cases. If this grows past a section,
  split it out.
- **MV.2 — LSP adapter + VS Code extension.** The v1 surface.
  Likely its own walkthrough (`MV.2-lsp-adapter.md`): which LSP
  methods map to which `Interact` ops, how inlay hints render
  the gradient passively, how code actions render proven
  patches, how `textDocument/didChange` flows into driver_check
  incrementally. VS Code extension boilerplate (marketplace
  publication, binary download, auto-update) lives here too.
- **MV.3 — the terminal IDE surface (later).** File tree,
  editable panes, command palette, Mentl present throughout.
  Walkthrough (`MV.3-terminal-ide.md`) post-v1, informed by
  what the LSP surface taught us about real voice use.
- **MV.4 — web playground (later).** Browser-hosted, guided-
  tutorial first visit. Walkthrough (`MV.4-web-playground.md`)
  post-terminal-IDE or in parallel; same substrate.
- **MV.5 — text ↔ graph synchronization contract.** Programs are
  canonically text; the graph is live via incremental compilation.
  What happens on keystroke vs save? When Mentl speculatively
  binds a handle, does the rendered text change or does the
  graph hold an un-rendered speculation? **rust-analyzer's
  answer:** didChange = reparse + re-check incrementally; the
  editor's buffer is source of truth for text; the LSP server's
  analysis is source of truth for semantic state. We adopt the
  same shape for v1 unless a thesis-level reason surfaces to
  deviate. Likely folds into MV.2 rather than needing its own
  walkthrough.
- **MV.6 — Mentl's name and voice test.** Character naming
  locked (Mentl, She/Her). Voice test: 20 example VoiceLines
  scored for register violations. This is design work, not
  substrate work; lives inline in MV's §4 refinement.
- **MV.7 — multi-shot × arena for the oracle.** The D.1 question
  (DESIGN Ch 6) reappears: when Mentl's checkpoint holds a
  continuation that captured arena memory, what policy applies?
  Three options named in DESIGN (Replay safe / Fork deny / Fork
  copy); MV likely picks Replay safe, matching trail-based
  rollback semantics.

---

## 8. Next design-session agenda (for Morgan + Mentl)

1. **§1 constraints acknowledged.** Done — text files are
   substrate; developers live in VS Code today; graph is live
   via IC.
2. **§1.5 Op set completeness against LSP method coverage.** Walk
   each `Interact` op; verify every relevant LSP method (hover,
   inlayHint, completion, codeAction, diagnostics, definition,
   references, rename, didChange, didSave, didOpen, didClose)
   maps cleanly.
3. **§2 Q1-Q6 resolutions.** Walk each, decide, commit.
4. **§3 grammar refinement.** Are the 12 templates right? Which
   ones are structurally the same shape and should factor?
   **Which surface does each one render through — VoiceLine
   (high-signal, one-at-a-time) or inlay/status (ambient)?**
5. **§4 register sharpening.** Voice test: write 20 example
   VoiceLines; score each for register violations.
6. **§5 multi-shot specifics.** Exact verification predicate;
   exact cap semantics; tie-break rules; surfacing discipline.
7. **§7 sub-handle scoping.** MV.2 (LSP + VS Code) is v1. MV.3
   (terminal IDE) and MV.4 (web playground) get walkthroughs
   later.
8. **Naming.** Mentl locked (She/Her). The `Interact` effect
   final name (candidates: `Interact`, `Session`, `Converse`).
   The VS Code extension's marketplace listing (candidates:
   `Inka`, `Inka + Mentl`, `Mentl for Inka`).
9. **First-program scenario.** A walkthrough of a new developer's
   first hour: they install the VS Code extension, open a new
   `.ka` file, start typing. What does Mentl say first? How does
   She introduce Herself? How does the one-at-a-time gradient
   feel in practice? This scenario stress-tests every other
   decision.
10. **rust-analyzer architecture study.** Read rust-analyzer's
    `ide` crate + main event loop + LSP adapter as a concrete
    model. Identify what maps, what diverges (evidence-passing
    polymorphism; effect algebra; Mentl's voice surface). Use
    their solutions where possible; deviate only with reason.

---

## 9. The surfaces — what they share, what differs

All three are peer `Interact` handlers on the Mentl-voice
substrate. The substrate is: the `Interact` op set, the voice
grammar, Mentl's register, the session state shape, the multi-
shot oracle discipline. The surface handlers differ in transport
and rendering.

### 9.1 VS Code plugin via LSP (v1 — the first integration)

**Transport:** LSP JSON-RPC over stdio (standard). VS Code
extension spawns `inka --lsp` as the language server; VS Code's
built-in LSP client handles the protocol.

**Rendering (what the developer sees in VS Code):**
- **Hover:** `ask(QTypeAt(span))` + `ask(QWhy(handle))` — type
  + brief reason chain. Click-through to expand (code action).
- **Inlay hints:** inferred types at binding sites, inferred
  effect rows at function signatures, inferred ownership markers
  at parameters. *Ambient surface, not constrained by
  one-at-a-time rule.*
- **Code actions (quick fixes):** each MachineApplicable
  Explanation.fix becomes a code action. Hovering the lightbulb
  shows Mentl's VoiceLine for the proposed fix.
- **Diagnostics:** substrate-generated errors (`E_PurityViolated`
  etc.) with Mentl's proof-shape rendered as the message. Code
  uses Error/Warning/Hint severity as appropriate (per Jordan's
  note in the role-play: `W_BudgetExceeded` is a Hint, not a
  Warning).
- **Go-to-definition, find-references, rename:** straightforward
  graph queries via `QRefsOf`, graph rebinds via the rename
  handler.
- **Mentl's voice surface:** VS Code has no canonical "sidebar
  panel for compiler personality" — design question. Candidates:
  (a) a dedicated Mentl output channel; (b) a WebView-based
  panel the extension ships; (c) a decoration above the current
  function showing Mentl's one-at-a-time suggestion. rust-analyzer
  uses the status bar + hover; we may go further.

**Why LSP first (and why this isn't a retreat from the thesis):**
- rust-analyzer's architecture is our architectural model: one
  crate (`lsp_adapter.ka`) knows about LSP/JSON-RPC; the rest is
  pure semantic analysis on `Interact`. LSP is transport, not
  paradigm.
- VS Code is where developers live today. Meeting them there
  means Mentl reaches them immediately — no "install our
  terminal IDE" friction.
- Inlay hints + code actions are gradient-compatible surfaces:
  inlay hints are ambient (show everything inferred, low
  signal), code actions are deliberate (proven patches, opt-in,
  high signal). Maps cleanly onto the one-at-a-time rule.
- Building the LSP surface teaches us what Mentl's voice needs
  to feel right in practice — lessons that inform the terminal
  IDE design later rather than forcing us to guess.

### 9.2 Batch CLI subcommands (v1 — existing, unified)

**Transport:** invoked with args, reads files, writes stdout/
stderr, exits. Already partially exists.
**Rendering:** plain text, one-shot.
**Surface subset:** `ask`, `run_compile`, `run_check`,
`run_audit`, `run_query`. No `focus`, no `edit`, no session
state.
**Mentl's voice:** present in output (same grammar, same
register), subset of proof-shapes that make sense without
persistent context (no silence-predicate initiative; no
intent-capture across invocations).

Existing `inka compile`, `inka check`, `inka audit`, `inka
query` subcommands get unified with the `Interact` substrate so
their voice matches VS Code.

### 9.3 Terminal IDE (later — the native Inka surface)

**Transport:** terminal I/O (stdin/stdout, raw mode, ANSI escape
sequences). Direct `Interact` — no LSP marshaling overhead.

**Rendering:** file tree, editable panes, voice pane, status
line, command palette. Designed AFTER the VS Code surface has
taught us what actually works.

**Editor mechanics (open question, resolve in MV.3):** modal
(vi-like) or modeless? Neither is obviously right. Resolve
when writing MV.3.

**Why later:** building a terminal IDE before anyone has used
the language is building a destination nobody is heading to.
After the VS Code surface is working and developers are using
it, the terminal IDE becomes the evolved-platform form where
the full thesis lives without the LSP overhead.

### 9.4 Web playground (later — the onboarding surface)

**Transport:** HTTPS + WebSocket. Browser client connects to a
server-side Inka instance or in-browser WASM instance (design
TBD — depends on WASM self-host maturity).

**Rendering:** DOM. The terminal IDE's substrate re-rendered
for browsers. Code editor component (Monaco / CodeMirror) as
a renderer for the `Interact` substrate, not a self-contained
editor.

**First-visit experience:** no session cookie → server loads a
`tutorial` project (curated `.ka` files walking through `fn`,
`|>`, effect rows, annotations, the gradient). Mentl narrates —
first unprompted VoiceLine is a greeting. **The tutorial is
written as Inka source** — comments + chosen examples in a
normal project rendered through the same surface; no special
tutorial engine.

**Persistence:** session saved to browser storage or account-
backed storage; downloadable as `.tar.gz` anytime.

### 9.5 Desktop client (distant future, optional)

Same substrate, native rendering. Not in MV's critical path.

### 9.6 What all surfaces share

- The `Interact` effect (same ops; surfaces may expose subsets).
- Mentl's voice grammar (same VoiceLine shapes).
- Mentl's register (same tone, same brevity, same discipline).
- The one-at-a-time surfacing rule (for VoiceLines; ambient
  surfaces like inlay hints are unconstrained).
- The session state shape (scoped: full in VS Code session,
  terminal IDE, web; ephemeral in batch CLI).
- The proof substrate underneath (same graph, same proposer,
  same multi-shot enumerator).

**One substrate. Multiple peer projections. No drift between
them. rust-analyzer's `ide` boundary is our architectural
template; our `Interact` effect is that boundary made
substrate.**

---

## Closing

MV is where the thesis becomes a user-facing medium. The γ
cascade gave Inka a substrate no other language has; MV gives
Mentl a voice no other compiler has. Until MV's walkthrough
closes, no `Interact`-surface code freezes. Character work is
as load-bearing as substrate work here — getting the voice
right is the difference between "another clever compiler" and
"the tool that makes agentic coding AI obsolete."

The medium; the one mechanism; the five verbs; Mentl as oracle;
the gradient is the conversation. Now: **Mentl's voice is how
the gradient speaks.**
