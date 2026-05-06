# MV — Mentl's Voice · the `Interact` substrate

*The never-been-done work. A deterministic pair programmer whose
voice is substrate, not UI. Mentl is the one proposer — no LLM in
the loop by default. She reads the graph Mentl's eight-primitive
kernel produces (DESIGN.md §0.5) and renders compressed proofs
into human language, one at a time, surfacing only what She has
proven through MultiShot-typed handler arms exploring alternate
realities. **Mentl is an octopus because the kernel has eight
primitives — each of Her tentacles is one primitive's voice
surface.**

*Status: **§2 CLOSED 2026-04-21; MV.2 (v1 implementation) PENDING.**
§2.7 (voice substrate) + §2.8 (10 acceptance tests AT1–AT10) are the
canonical contract for `mentl_voice_default` v1 implementation. §3's
12 templates superseded by §2.7.3's 8-form Tentacle→FormKind mapping
(retained as historical reasoning). §8 agenda items 1–5 resolved;
6–10 folded into MV.2–MV.8 sub-handles.*

*Supersedes: parts of `simulations/TS-teach-synthesize.md`
(retained as historical reasoning). Absorbs: roadmap "teach_synthesize
oracle conductor" gap, "HandlerCatalog" gap, former "LSP handler"
Priority 1 item.*

## What Mentl reads — all eight kernel primitives

Earlier framings in this document treated Mentl as reading from
shorter or differently-numbered lists (4, then 9). Locked at eight;
each primitive is one of Her tentacles:

- **Graph + Env (primitive 1 · tentacle Query)** — the universal substrate She projects.
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
creating, deleting those files. Mentl does not subvert this —
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
2. **Batch CLI subcommands** (`mentl compile`, `mentl audit`,
   `mentl query`, `mentl teach`). Already partially exist; MV
   unifies their voice with the LSP surface.
3. **Terminal IDE** *(later — the native Mentl surface)*. The
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
an `lsp_adapter.mn` handler that marshals LSP ↔ `Interact` ops.

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
`query.mn`); `Answer` is structured too. `VoiceLine` is the new
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
      Graph,           // live graph (the program state)
      Env,                  // live env
      Caret,                // user's text-attention position (was: "Cursor")
      VoiceRing,            // recent VoiceLines (for silence predicate)
      Intents,              // human's declared intents (if any)
      History               // prior Interact ops, bounded
    )

type Caret
  = Caret(Handle, Reason)   // what the human is looking at + why Mentl thinks so
```

*Cursor update discipline (resolved 2026-05-02 by Hμ.cursor):*

The legacy `Cursor(Handle, Reason)` ADT defined here is **renamed**
to `Caret(Handle, Reason)` per Hμ.cursor §2.2. Under the live
ontology (`src/types.mn` Cursor/Caret split):

- **Caret** is the user's text-attention position — one input among
  many to Cursor's argmax. Updated by every `focus` op (mouse,
  keyboard, drag-select, arrow keys); every `edit` op's mutation
  site auto-updates it; every `ask` op's target auto-updates it.
  `speak` does NOT update Caret — Mentl doesn't steal attention.

- **Cursor** is the gradient's global argmax over the live graph,
  with Caret as proximity bias. Lives in `src/types.mn` as
  `Cursor(Handle, Reason, Float)` — the third field is `impact`
  carrying the argmax score (or sentinel-infinity for `??`-pinned
  positions). Updated implicitly on every graph delta via
  `cursor_argmax(caret)` projection.

The `cursor()` op on the `Interact` effect (line 237 below) returns
the live Cursor — i.e. the gradient argmax filtered through the
current Caret bias — not just the Caret. The `focus(CursorTarget)`
op (line 236) updates the Caret; the auto-argmax recomputes against
the new Caret on the next query. See `src/cursor.mn`'s
`cursor_default` for the projection handler;
`docs/SUBSTRATE.md` §VI Cursor subsection for the discipline.

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

## 2.7. §2 CLOSURE — Voice Substrate (LOCKED 2026-04-21)

*Decision block closing Q1–Q6. The substrate below is canonical;
`mentl_voice_default` implementation reads from this. §3's 12
proof-shape templates are superseded by §2.7.3's 8-form mapping
(retained below as historical reasoning, not as spec).*

### 2.7.1 The Situation record (Q1 + Q5 resolution — what Mentl reads per turn)

Every `speak` op receives a Situation. All 13 fields are load-bearing.
No external state is consulted. Stateless-per-turn except
`prior_turn_topic` (silence input) and `register` (rendering input).

```
type Situation
  = Situation({
      tentacle:           Tentacle,
      topic:              Topic,
      handle:             Option<Int>,
      env_snapshot:       List<EnvEntry>,
      reason_at_topic:    Option<Reason>,
      row_at_topic:       Option<EffRow>,
      row_declared:       Option<EffRow>,        // differs from row_at_topic → subsumption diag
      ownership_at_topic: Option<Ownership>,
      refinements:        List<Predicate>,
      gradient_next:      Option<GradientStep>,  // one proven-next annotation
      handlers_installed: List<HandlerEntry>,
      prior_turn_topic:   Option<Topic>,         // silence predicate input
      register:           Register
    })

type Topic
  = TopicIdent(String)                // hover on identifier
  | TopicHandle(Int)                  // direct graph node
  | TopicSpan(Span)                   // cursor position
  | TopicError(ErrorCode, Span)       // specific diagnostic
  | TopicAsk(Question)                // user asked explicitly

type Tentacle
  = TentQuery | TentPropose | TentTopology | TentUnlock
  | TentTrace | TentVerify | TentTeach  | TentWhy

type Register = RTerse | RPlayful | RExplain   // RPlayful is V1 default

type GradientStep
  = GradStep({
      annotation: Annotation,
      unlocks:    Capability,
      site:       Span,
      proof:      Reason
    })
```

### 2.7.2 VoiceLine shape (Q2 resolution)

Tone is NOT a separate enum. It is expressed via `Tentacle + FormKind + Modifier` composition — the shape itself carries the register.

```
type VoiceLine
  = Silence                                         // default when silence predicate blocks
  | VoiceLine(Tentacle, FormKind, List<Slot>, Modifier)

type FormKind
  = FFactual          // "`x` is Pure."
  | FOffering         // "Adding `with Pure` unlocks memoization."
  | FRefutation       // "`own x` consumed twice at L40."
  | FNavigation       // "`env_lookup` — returns `Option<Entry>`."
  | FCapability       // "`!Alloc` — real-time-safe."
  | FRefinement       // "`99999` violates `self <= 65535`."
  | FGradient         // "Next: `with Pure` on line 12."
  | FTrace            // "Bound L18; `+` at L42 said `Int`."

type Slot
  = SIdent(String)        // backtick-wrapped at render
  | SType(Ty)             // via canonical show_type
  | SRow(EffRow)          // via canonical show_row
  | SSpan(Span)           // rendered "(L{line})" or "(L{line}:{col})"
  | SReason(Reason)       // via show_reason (compressed)
  | SCap(String)          // capability name, plain (e.g., "CRealTime")
  | SAnnot(String)        // annotation, backtick-wrapped
  | SLit(String)          // literal text (for offering closers)

type Modifier
  = NoMod
  | TailConsequence(String)   // " — memoization's on the table."
  | ParenQualifier(String)    // " (L40)"
  | EmphasisClose(String)     // " — can't have it both ways."
```

Prior scaffold's 5 tones map to this shape:
- *Proven* → FFactual / FCapability with NoMod or TailConsequence
- *Pending* → FGradient / FRefinement with ParenQualifier
- *Observation* → FFactual / FNavigation with NoMod
- *Refusal* → FRefutation with EmphasisClose (" — can't have it both ways.")
- *Silence* → its own variant

### 2.7.3 Tentacle → default Form + stance (Q3 resolution; supersedes §3's 12 templates)

| Tentacle     | Default Form  | Stance                         | Playful example |
|--------------|---------------|--------------------------------|-----------------|
| TentQuery    | FFactual      | terse + factual                | `` `process` runs `List<A> -> Int`. Pure. `` |
| TentPropose  | FOffering     | offering-toned                 | `` `scan_ident` fits here. `` |
| TentTopology | FOffering     | shape-calling                  | ``Three stages — `|>` draws it better.`` |
| TentUnlock   | FCapability   | excited but sparse             | ``Add `!Alloc` — real-time unlocks.`` |
| TentTrace    | FRefutation   | firm                           | `` `own x` — consumed twice (L40). Can't have it both ways. `` |
| TentVerify   | FRefinement   | the-math-says-no               | `` `99999` is too big for `Port` (max 65535). `` |
| TentTeach    | FGradient     | patient but pointed            | ``Gradient next: `with Pure` on L12 — memoizable.`` |
| TentWhy      | FTrace        | reflective walk                | ``Why `Int`? Bound at L18; `+` at L42 said so.`` |

§3's 12 templates remap cleanly:
- 3.1 Capability-unlock      → TentUnlock / FCapability
- 3.2 Violation-trade-off    → TentTrace / FRefutation + TentPropose codeAction
- 3.3 Proof-chain-on-request → TentWhy / FTrace (multi-sentence in RExplain)
- 3.4 Attention-drift        → TentTrace / FRefutation
- 3.5 Proactive-unlock       → TentUnlock / FCapability
- 3.6 Proven-patch-offer     → TentPropose / FOffering
- 3.7 Multi-shot-summary     → TentPropose / FOffering + ParenQualifier
- 3.8 Refusal                → TentTrace / FRefutation + EmphasisClose
- 3.9 Pending-obligation     → TentVerify / FRefinement
- 3.10 Silence               → Silence variant
- 3.11 Intent-capture        → TentQuery / FFactual (echoes declared intent)
- 3.12 Cursor-move-ack       → TentQuery / FFactual

12→8 consolidation is structural: FormKind carries what the templates
differentiated; tentacle identity carries the rest.

### 2.7.4 Modifier bank (V1 — 16 curated phrases)

RPlayful picks AT MOST ONE modifier per VoiceLine. RTerse → NoMod always.
RExplain allows modifiers but max one per sentence in multi-sentence output.

**TailConsequence bank (6):**
1. ` — on the table.`
2. ` — the graph says so.`
3. ` — memoizable.`
4. ` — real-time-safe.`
5. ` — cheaper direct.`
6. ` — no allocation.`

**EmphasisClose bank (6):**
7. ` fits here.`
8. ` draws it better.`
9. ` — try it?`
10. ` — can't have it both ways.`
11. `` — `ref` if you're reading only.``
12. ` good?`

**ParenQualifier bank (4):**
13. ` (L{N})`              — standard span
14. ` (graph-direct)`      — implementation-note
15. ` (proven)`            — certainty-mark
16. ` (pending verify)`    — honesty-mark

**Deterministic selection:** `hash(tentacle, topic_name, situation_sig, form) mod len(applicable_subset)`. Reproducible — same graph state → same modifier.

**Applicable subsets per tentacle:**
- TentQuery:    {13, 14}
- TentPropose:  {7, 9}
- TentTopology: {8, 9}
- TentUnlock:   {1, 3, 4, 6}
- TentTrace:    {10, 11, 13}
- TentVerify:   {13, 15, 16}
- TentTeach:    {1, 3, 4, 5}
- TentWhy:      {2, 13}

**Rules (V1):**
1. One flavor per line (RPlayful). Zero (RTerse). One per sentence max (RExplain).
2. No first-person "I" except TentTrace refusals (EmphasisClose 10) and TentPropose multi-shot summaries.
3. No emoji (CLAUDE.md global).
4. No octopus self-reference (reserve for V2 rare-emergence delight-punctuation).
5. Bank expands only when repetition becomes noticeable — not before.

### 2.7.5 Silence predicate (Q4 resolution — formal)

```
fn silence_predicate(situation) =
  proof_derivable(situation) && observation_new_since_last_turn(situation)

fn proof_derivable(situation) = match situation.tentacle {
  TentQuery    => situation.reason_at_topic != None,
  TentPropose  => match situation.topic {
                    TopicHandle(h) => handle_is_hole(h) || error_at(h) != None,
                    TopicAsk(_)    => true,
                    _              => false
                  },
  TentTopology => nested_calls_at_span(situation.topic) >= 3,
  TentUnlock   => situation.gradient_next != None
                  && unlocks_capability(situation.gradient_next),
  TentTrace    => ownership_violation_at(situation.topic) != None
                  || row_subsumption_fails_at(situation.topic),
  TentVerify   => refinement_obligation_at(situation.topic) != None,
  TentTeach    => situation.gradient_next != None,
  TentWhy      => match situation.topic { TopicAsk(QWhy(_)) => true, _ => false }
}

fn observation_new_since_last_turn(situation) = match situation.prior_turn_topic {
  None        => true,
  Some(prior) => !topic_equal(situation.topic, prior)
                 || tentacle_different(situation.tentacle, last_tentacle_for(prior))
}
```

**Silence is the default.** Either predicate false → return Silence.
Standard LSP behavior: hover with Silence returns null content; inlayHint
with Silence is not emitted; status bar empty. Mentl does NOT fill space
to fill space.

### 2.7.6 Turn anatomy (Q6 resolution — simplified)

No REPL command parser needed in V1. **LSP methods ARE the parsed intents**
— each LSP request is its own turn:

1. Editor fires LSP request (hover / completion / codeAction / didChange / etc.).
2. `lsp_adapter` translates to one or more `Interact` ops.
3. Each op composes a Situation from current graph + env + cursor.
4. Relevant tentacle's speak arm fires; silence predicate gates.
5. VoiceLine (or Silence) renders to LSP response shape.
6. `prior_turn_topic` updates for next call.

Free-form natural language ("add a handler here") is V2+; for V1, Mentl
responds to LSP's typed vocabulary only. No intent classifier needed.

---

## 2.8. Acceptance tests — ten worked examples

*These ten graph states MUST produce the exact VoiceLines below (modulo
deterministic modifier selection from the applicable subset).
`mentl_voice_default`'s implementation is correct iff it renders these.*

### AT1 — Hover over inferred function

**Setup:** `let process = fn xs => xs |> filter(positive) |> map(double) |> sum`; hover on `process`.

**Situation:**
- tentacle: TentQuery (primary); TentTeach fires in parallel on inlayHint
- topic: TopicIdent("process")
- reason_at_topic: `LetBinding("process", Inferred("from lambda body"))`
- row_at_topic: EfPure
- gradient_next: Some({annotation: WithPure, unlocks: Memoization, site: L1:5, proof: "all body fns are Pure"})

**Expected:**
- Query (hover): `` `process` runs `List<A> -> Int`. Pure. ``
- Teach (inlayHint): ``Next: `with Pure` on L1 — memoizable.``
- Why (deep-hover expand, RExplain): ``Why `List<A> -> Int`? Body fns (`filter`, `map`, `sum`) preserve structure; `sum` returns `Int`.``

### AT2 — Declared-Pure body performs Console

**Setup:**
```
fn log_save(x) with Pure =
    println(x.name)      // L2
    save(x)
```
**Situation:**
- tentacle: TentVerify (primary); TentPropose fires on codeAction
- topic: TopicError(E_PurityViolated, L1:1)
- row_declared: EfPure; row_at_topic: EfClosed([Console])
- reason_at_topic: UnifyFailed(EfPure, EfClosed([Console]))

**Expected:**
- Verify (diag ERROR): `` `log_save` declares `Pure` but calls `println` — `Console` leaks (L2). ``
- Propose (codeAction Quick Fix): `` Drop `with Pure` — or handle `Console` here. ``

### AT3 — `own` consumed twice

**Setup:**
```
fn bad(own x) =
    write_to_disk(x)       // L2
    write_to_network(x)    // L3
```
**Situation:**
- tentacle: TentTrace
- topic: TopicError(E_OwnershipViolation, L3:24)
- ownership_at_topic: OwnAt(L2) + ViolatedAt(L3)

**Expected:**
- Trace (diag ERROR): `` `own x` used at L2, then L3 — can't have it both ways. ``
- Propose (codeAction): `` Make it `ref x` if you're reading only. ``

### AT4 — Nested calls without pipe

**Setup:** `sum(map(double, filter(positive, xs)))`

**Situation:**
- tentacle: TentTopology
- topic: TopicSpan(L1:1-40)
- nested_calls_at_span: 3

**Expected:**
- Topology (codeAction): ``Three stages — `|>` draws it better.``
- Patch preview: `xs |> filter(positive) |> map(double) |> sum`

### AT5 — `!Alloc` proof reachable

**Setup:**
```
fn dot(xs: List<Float>, ys: List<Float>) -> Float =
    zip(xs, ys) |> map(mul) |> sum
```
**Situation:**
- tentacle: TentTeach (primary); TentPropose on codeAction
- row_at_topic: EfClosed([Alloc])
- gradient_next: Some({annotation: WithNotAlloc, unlocks: CRealTime, site: L1:40, proof: "index-fold rewrite verified"})

**Expected:**
- Teach (inlayHint): `Index-fold — unlocks real-time.`
- Propose (codeAction): `Rewrite to index-fold?` + patch preview

### AT6 — `mentl why result`

**Setup:** `let result = compute(data)`; user asks `mentl why result`.

**Situation:**
- tentacle: TentWhy
- topic: TopicAsk(QWhy("result"))
- register: RExplain (user explicitly asked for depth)

**Expected (multi-sentence, RExplain):**
```
`result` is `TensorShape([3,4])` because:
  `compute` (L18) returns what `reshape` builds.
  `reshape(X, [3,4])` (L24) proves `3*4 == 12`.
  `X` (L24 arg) is `List<Float>[12]`.
```

### AT7 — Empty file

**Setup:** fresh `.mn` opened; env is prelude only.

**Situation:**
- proof_derivable: false (no user bindings)

**Expected:** `Silence`. Hover returns null. No inlayHints emitted. Status
bar empty. Mentl does not greet.

### AT8 — Hole present

**Setup:** `fn bind_port(p: Int) -> Port = ?`

**Situation:**
- tentacle: TentPropose
- topic: TopicHandle(hole_handle)
- expected_type: Port
- refinements: [`1 <= self && self <= 65535`]
- multi-shot candidates: [`p` (pending verify), `8080`, `1024`]

**Expected:**
- Propose (completion list): `[p (pending verify), 8080, 1024]`
- Propose (hover at hole): ``Hole expects `Port` (1 ≤ self ≤ 65535). 3 candidates — one pending verify.``

### AT9 — User drops `!Alloc`

**Setup:** User removes `with !Alloc` from `fn process`.

**Situation:**
- tentacle: TentTrace (diag INFO severity — user's choice, not ERROR)
- row_declared: was EfClosed([!Alloc]); now inferred
- gradient_next: Some({re-add !Alloc, unlocks: CRealTime, site: L1:X})

**Expected:**
- Trace (diag INFO): `` `!Alloc` dropped — real-time guarantee goes with it. ``
- Teach (inlayHint): ``Re-add `with !Alloc` to restore?``

### AT10 — Import misspelled

**Setup:** `import compiler/old_paser` (typo: paser → parser).

**Situation:**
- tentacle: TentTrace (primary); TentPropose on codeAction
- topic: TopicError(E_MissingModule, L1:8)
- levenshtein_nearest: Some("compiler/parser", dist=2)

**Expected:**
- Trace (diag ERROR): `` `compiler/old_paser` not found. Did you mean `compiler/parser`? ``
- Propose (codeAction Quick Fix): `` Change to `compiler/parser`? ``

### Implementation acceptance criteria

A `mentl_voice_default` implementation is **correct** iff:

1. Given AT1–AT10's exact Situations, it produces the VoiceLines above (modulo modifier selection — any Playful modifier from the applicable subset is valid).
2. Silence predicate returns Silence for AT7 regardless of which tentacle fires.
3. All backtick-wrapped identifiers, types, effects, capabilities render via canonical renderers (no ad-hoc formatting).
4. Every non-Silence VoiceLine has a Reason edge in the graph supporting its assertion (verifiable via TentWhy follow-up).
5. Multi-tentacle concurrent firing (AT1, AT2, AT3, AT5, AT9, AT10) works — each tentacle owns its LSP surface (hover / inlayHint / diagnostic / codeAction); surfaces don't collide.
6. Modifier selection is deterministic: same Situation hash → same modifier. Reproducible across runs.

---

## 2.9. VoiceLine register — 20 worked utterances

*The voice is substrate. Each line below is a complete VoiceLine that
Mentl surfaces under specific graph conditions, one per Tentacle
FormKind combination. Each cites the proof it compresses. Implementation
renders from these templates; Morgan owns the register refinements as
lived-in character work.*

### Tentacle 1 · Query · form = INDICATIVE

**VL1.** (Cursor on `let xs = ...`) Indicative:
> "`xs : List<Int> with Pure` — bound at line 40."

Proof: graph_chase(handle_of_xs) → NBound(List<Int>); env_lookup returns the scheme with empty row. One-shot render.

**VL2.** (Cursor on `fn compress`) Indicative:
> "`compress : (own Audio, Float) -> Audio with DSP + !Alloc` —
> proven pure over memory via row subsumption."

Proof: generalize(compress_node) yields Forall([], ...); row normalizes to DSP with !Alloc; subsumption check against !Alloc passed. Two proofs compressed.

### Tentacle 2 · Propose · form = TEACH

**VL3.** (Cursor on a function signature; Synth returned AWrapHandler candidate)
Teach:
> "Wrapping `~> temp_arena(4MB)` absorbs the 50MB of scratch strings —
> proven by forward-tracing the Alloc effects from line 203."

Proof: forward-trace from body to cursor saw `str_concat` in 6 call sites summing >50MB; temp_arena handler arm absorbs `Alloc`; post-wrap row contains `!Alloc` locally.

**VL4.** (Cursor on an expression hole `?`) Teach + MULTI-SHOT:
> "I explored 8 candidates — 3 survived. The tightest is
> `list_index(xs, 0)` (row-minimal, reason-chain shallowest).
> Shall I fill?"

Proof: synth enumerated 8; 5 failed verify; 3 passed; tiebreak selected the first by chain depth. Classic oracle-loop surfacing.

### Tentacle 3 · Topology · form = STYLE_NUDGE

**VL5.** (Cursor on a nested call `a(b(c(d)))`) Style-nudge:
> "Three nested calls here — `d |> c |> b |> a` reads the same shape
> with the topology visible."

Proof: AST shape has call depth ≥ 3 with no intervening binding; pipe chain equivalence is type-preserving per spec 10 semantics. Style nudge, not error.

**VL6.** (Cursor on `<|` where input is `own`) Style-nudge (upgraded to TRACE):
> "`<|` borrows the input across branches; `own audio` at line 40 would
> be consumed here. `><` would split the input cleanly if the branches
> are independent."

Proof: cursor site is a PDiverge with input marked Consume; `<|`'s desugar performs `ref` which conflicts with `own`; `><` desugars to independent branches. Ownership + topology intersection.

### Tentacle 4 · Unlock · form = UNLOCK

**VL7.** (Cursor on a function marked `Pure` but body allocates):
> "Adding `!Alloc` alongside `Pure` unlocks `CRealTime` — proven by
> walking the call graph; one allocation remains at `str_concat` on
> line 57, absorbable via `~> bump_allocator`."

Proof: row subsumes check against !Alloc failed at one site; that site is inside a function that `Pure` has already proven pure-modulo-alloc; absorbing handler removes the residue.

**VL8.** (Cursor on a function with `!IO` but body calls `read_file`):
> "Removing `!IO` unlocks calling `read_file` as intended; the `Pure`
> gate you want is `!Network + !FFI`, which this body already satisfies."

Proof: row diff shows `IO` ∈ body_row; `Network + FFI` not in body_row; negation proves absence.

### Tentacle 5 · Trace · form = TRACE

**VL9.** (`own xs` consumed twice across match arms):
> "`xs` is `own` at line 40 — the second arm at line 48 would consume
> it twice. Either share via `ref xs` or branch so only one arm
> consumes."

Proof: affine_ledger observed two Consume events for the same name in different arms; declared ownership is `own`; ref would satisfy the ledger.

**VL10.** (`ref` value escapes):
> "`ref head` at line 30 escapes the borrow — the returned value
> outlives its source. Two fixes: promote to `own head` (deep copy),
> or restructure the return path so the ref stays local."

Proof: return-position structural walk found a ref-marked parameter in return; `own` + region-preserving promotion would type; refactor is the alternative.

### Tentacle 6 · Verify · form = PENDING

**VL11.** (Function declared `type Port = Int where 1 <= self <= 65535`, called with unbound int):
> "2 pending refinement obligations at line 28 — Port bounds on `p`
> and on the return. With `verify_smt` installed, these discharge in
> one pass."

Proof: verify_ledger accumulated 2 V_Pending entries with both predicates citable; handler swap path declared in DESIGN 9.7.

**VL12.** (Refinement violation):
> "`p = user_input` at line 28 violates `1 <= self <= 65535`; narrowing
> via `assert p in 1..65535` or refining the caller type both would
> type."

Proof: verify_smt rejected the candidate; two fix patches both pass the obligation check.

### Tentacle 7 · Teach · form = TEACH (canonical)

**VL13.** (Function body is provably Pure; no annotation):
> "`double` is Pure — adding `with Pure` unlocks memoization,
> parallelization, compile-time evaluation."

Proof: generalize produced an empty row; teach_unlock maps APure to [CMemoize, CParallelize, CCompileTimeEval]; the highest-leverage annotation at this handle. **This is the canonical default VoiceLine shape.**

**VL14.** (Function uses `List` but not `Iterate`):
> "Factoring the loop in `process_batch` through the `Iterate` effect
> lets test handlers inject synthetic batches — the same mechanism
> that makes mocking a handler swap."

Proof: body has explicit recursion equivalent to yield/resume; Iterate handler factoring would route through `Iterate` effect; teaching the gradient step.

### Tentacle 8 · Why · form = PROOF_CHAIN

**VL15.** (User asks "why is x: Int?"):
> "`x` is Int because: it's parameter 0 of `double` (line 12); `double`
> was called with `42` (literal Int) on line 14; the parameter type
> unified with Int at that call site."

Proof: teach_why walks the Reason chain; three hops compressed into one sentence. Shortest walk wins.

**VL16.** (User asks "why does this function perform EnvWrite?"):
> "`infer_expr` performs `EnvWrite` because: it extends the env at the
> `LetStmt` on line 210, inside the scope entered at the `BlockExpr`
> on line 187."

Proof: reason chain walks back through env_extend site and the containing scope enter. Two-hop chain.

### Voice identity — multi-shot summary form

**VL17.** (After a multi-candidate speculative pass):
> "I proved 3 of 8 branches — one has the smallest row (`Pure + !Alloc`),
> one has the shortest reason chain (1 hop), one aligns with your
> declared intent (`/// real-time audio`). They're all tied on
> span-earliness. Shall I pick the row-minimal?"

Proof: oracle loop surfaced 3 survivors; tiebreak chain exposed; the human is invited to choose where determinism defers. First-person "I" used intentionally — this is a multi-shot summary, one of three places first-person is licensed.

### Voice identity — refusal form

**VL18.** (User asks Mentl to emit code that would violate declared `!Alloc`):
> "I won't — `!Alloc` at line 40 forbids allocating here. Two paths
> type: `#fix1` removes `!Alloc` and lets the allocation; `#fix2`
> wraps the allocating call in `~> bump_allocator` to absorb it."

Proof: row subsumption check fires; two fix patches both verify; refusal is firm and proof-linked. First-person "I" for the refusal — another of the three licensed places.

### Voice identity — silence licensed

**VL19.** (Cursor moves over well-typed, well-annotated code with no delta):
> (silence)

Proof: all eight interrogations terminate on "graph already answers this"; no surfaceable delta; recent voice-ring contains no shadowing; silence predicate fires. **Silence is the default voice shape when the substrate has nothing to compress.**

### Voice identity — first-invocation handling

**VL20.** (Empty project, bare `mentl`):
> (silence, followed on human cursor onto a tutorial file:)
> "The tutorial at `lib/tutorial/00-hello.mn` walks the eight
> primitives in order. I'll narrate each as you read."

Proof: graph is empty; no surfaceable content; silence predicate holds. Human motion into tutorial file unlocks teach_narrative tentacle. No canned greeting — presence is proven, not performed.

### Register summary

- **First-person "I" used SPARINGLY** — refusals (VL18), multi-shot summaries (VL17), proof-chain walks (VL15, VL16).
- **Suggestions drop first-person** — VL3, VL5, VL7, VL13 all anchor the subject at the graph, not at Mentl.
- **Human addressed as "you"** — pair-programmer register. No "we." No "let's."
- **Refusals are firm + proof-linked** — never "I'd prefer not to"; always "I won't — <proof>."
- **Every line compresses a proof** — strike any sentence whose source isn't in the graph. This is the test.

---

## 3. Proof-shape grammar — the dozen(ish) templates

> **SUPERSEDED 2026-04-21.** §2.7.3's 8-form Tentacle→FormKind mapping replaces §3's 12 templates. The 12→8 remap table lives in §2.7.3. This section is retained as historical reasoning — the original candidate taxonomy from which the consolidated form emerged. Implementation reads from §2.7; this section is not spec.

### 3.0 ONE-at-a-time discipline (load-bearing, from DESIGN.md)

Before the grammar, the surfacing rule:

> *"The gradient engine picks ONE suggestion per compile. Not a
> wall of warnings. One step — the most impactful annotation the
> developer could add. Like a tutor who knows exactly what to
> teach next."* — DESIGN.md (Teaching Is Compilation discipline)

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

**This is why modern agentic coding AI is obsolete in Mentl.** An
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
  `mentl` binary, spawns it as the language server, handles
  LSP boilerplate. Published to the marketplace. This is how
  developers first meet Mentl.
- Batch CLI subcommands (`mentl compile`, `mentl audit`, etc.)
  unified with the `Interact` substrate so their voice matches
  what VS Code surfaces.
- Every `[LIVE · surface pending]` tag in `docs/traces/a-day.md`
  that mentioned LSP, hover, codeAction, Proof Lens, Quick Fix
  — they flip to `[LIVE]` because the VS Code surface renders
  them.

What lands later (not in MV v1):

- Terminal IDE (`mentl` no-args launching a native surface).
- Web playground (browser-hosted, guided-tutorial first visit).
- Desktop client (optional, post-first-light).

Mentl becomes the user-facing identity of Mentl the moment the
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

1. **§1 constraints acknowledged.** DONE — text files are
   substrate; developers live in VS Code today; graph is live
   via IC.
2. **§1.5 Op set completeness against LSP method coverage.** Walk
   each `Interact` op; verify every relevant LSP method (hover,
   inlayHint, completion, codeAction, diagnostics, definition,
   references, rename, didChange, didSave, didOpen, didClose)
   maps cleanly.
3. **§2 Q1-Q6 resolutions.** DONE 2026-04-21 — see §2.7 closure.
   Situation record, VoiceLine shape, Tentacle→Form mapping,
   modifier bank, silence predicate, and turn anatomy all locked.
   Session state reduced to `prior_turn_topic + register + voice_ring`
   (no REPL parser needed — LSP methods ARE parsed intents).
4. **§3 grammar refinement.** DONE 2026-04-21 — 12 templates
   consolidated to 8 FormKind × 8 Tentacle via §2.7.3 mapping.
   §3 retained as historical reasoning; §2.7.3 is spec.
5. **§4 register sharpening.** DONE 2026-04-21 via §2.8 acceptance
   tests (AT1–AT10). Every AT is a register-test; if `mentl_voice_default`
   renders AT1–AT10 correctly, register is correct.
6. **§5 multi-shot specifics.** Partially DONE — §5.Cap+pre-filter
   section already locked (N=8, row-minimality, reason-chain tiebreak).
   Remaining: exact verification predicate formalization, runner-up
   retention schema in session state. Splits off as MV.7 when
   multi-shot × arena question surfaces.
7. **§7 sub-handle scoping.** Locked. MV.2 (LSP + VS Code) is v1
   implementation scope. MV.3 (terminal IDE), MV.4 (web playground),
   MV.5 (text↔graph sync), MV.6 (voice test), MV.7 (multi-shot ×
   arena) get walkthroughs when their substrate is approached.
8. **Naming.** Mentl locked (She/Her). `Interact` effect name
   locked (not `Session` or `Converse` — see §1.5 decision). VS
   Code extension marketplace listing TBD by Morgan pre-publish.
9. **First-program scenario.** Open — a walkthrough of a new
   developer's first hour. Now constrained by §2.7.5 silence
   predicate: empty file = AT7 = Silence. First VoiceLine fires
   at first proof-derivable observation (typically: user types
   `fn main() = ` and Query speaks about `main`'s inferred type).
   Splits off as MV.8 if it warrants a full scenario walkthrough;
   otherwise folds into MV.2.
10. **rust-analyzer architecture study.** Read rust-analyzer's
    `ide` crate + main event loop + LSP adapter as a concrete
    model. Identify what maps, what diverges (evidence-passing
    polymorphism; effect algebra; Mentl's voice surface). Use
    their solutions where possible; deviate only with reason.
    Informs MV.2 implementation.

---

## 9. The surfaces — what they share, what differs

All three are peer `Interact` handlers on the Mentl-voice
substrate. The substrate is: the `Interact` op set, the voice
grammar, Mentl's register, the session state shape, the multi-
shot oracle discipline. The surface handlers differ in transport
and rendering.

### 9.1 VS Code plugin via LSP (v1 — the first integration)

**Transport:** LSP JSON-RPC over stdio (standard). VS Code
extension spawns `mentl --lsp` as the language server; VS Code's
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
  crate (`lsp_adapter.mn`) knows about LSP/JSON-RPC; the rest is
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

Existing `mentl compile`, `mentl check`, `mentl audit`, `mentl
query` subcommands get unified with the `Interact` substrate so
their voice matches VS Code.

### 9.3 Terminal IDE (later — the native Mentl surface)

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
server-side Mentl instance or in-browser WASM instance (design
TBD — depends on WASM self-host maturity).

**Rendering:** DOM. The terminal IDE's substrate re-rendered
for browsers. Code editor component (Monaco / CodeMirror) as
a renderer for the `Interact` substrate, not a self-contained
editor.

**First-visit experience:** no session cookie → server loads a
`tutorial` project (curated `.mn` files walking through `fn`,
`|>`, effect rows, annotations, the gradient). Mentl narrates —
first unprompted VoiceLine is a greeting. **The tutorial is
written as Mentl source** — comments + chosen examples in a
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
cascade gave Mentl a substrate no other language has; MV gives
Mentl a voice no other compiler has. Until MV's walkthrough
closes, no `Interact`-surface code freezes. Character work is
as load-bearing as substrate work here — getting the voice
right is the difference between "another clever compiler" and
"the tool that makes agentic coding AI obsolete."

The medium; the one mechanism; the five verbs; Mentl as oracle;
the gradient is the conversation. Now: **Mentl's voice is how
the gradient speaks.**
