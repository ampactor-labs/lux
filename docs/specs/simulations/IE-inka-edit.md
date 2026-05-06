# IE — `mentl edit` walkthrough

*The canonical Mentl IDE. Browser-based, holographic, live. Mentl is
the oracle the developer talks to; the medium is the editor; the
substrate is what's drawn on screen. Where developers discover Mentl,
write their first program, and never leave.*

**Handle:** IE (Phase F surface peer to F.1; the canonical first-
developer-encounter substrate).
**Status:** 2026-04-25 · seeded.
**Authority:** `docs/DESIGN.md` §0.5 (eight-primitive kernel),
§5 (annotation gradient is conversation), §8 (Mentl as oracle), §10
(simulations); `docs/SUBSTRATE.md` §VI "The Hole Is the Gradient's
Absence Marker" + §II "Visual Programming in Plain Text" + §II
"Feedback Is Mentl's Genuine Novelty" + §III "The Handler Chain Is a
Capability Stack"; memory protocol `protocol_oracle_is_ic.md` (the
continuous-oracle-IS-IC discipline) + `protocol_realization_loop.md`
(compound interest of self-reference); `docs/DESIGN.md` (AI
obsolescence mechanized);
`docs/specs/simulations/IDE-playground-vision.md` (vision; this
walkthrough materializes it as substrate);
`docs/specs/simulations/MV-mentl-voice.md` (Mentl's voice substrate
— Interact effect + 8 tentacles);
`docs/specs/simulations/F1-mentl-doc.md` §11 (disintermediation map);
`docs/specs/simulations/MO-mentl-oracle-loop.md` (speculative gradient
end-to-end with concrete latency math).
**Walkthrough peers:** `MV-mentl-voice.md` (Mentl substrate IE
projects), `F1-mentl-doc.md` (mentl doc substrate IE composes for the
doc panel), `MO-mentl-oracle-loop.md` (oracle loop IE's Holographic
Lens fires), `H7-multishot-runtime.md` (MS runtime IE's Wavefront
streams), `EH-entry-handlers.md` (`mentl --with` dispatch IE registers
through), `DS-docstring-edge.md` (`///` substrate IE's doc panel
reads), `CRU-crucibles.md` (crucible substrate IE's tutorial shell
demos).

---

## §0 Framing — what `mentl edit` IS

`mentl edit` is the canonical Mentl IDE. **The medium reading itself
out loud, in a browser, with Mentl as the oracle the developer talks
to, every keystroke firing the substrate live.**

Not a competitor to VS Code, Cursor, Zed, JetBrains, CodeSandbox,
StackBlitz, Repl.it, or any other editor product. Not a wrapper over
existing tooling. Not a "playground." `mentl edit` IS the substrate's
own interactive surface — the same kernel that produces binaries
through `compile_run`, the same Mentl voice that surfaces through
`mentl teach`, the same projection that renders through `mentl doc`,
**composed into the form developers see**.

**Why browser-first:** the medium is the lens; the lens is the
substrate; the substrate compiles to WASM and runs natively in any
browser at 60fps (per IDE-playground-vision.md L31 + DESIGN §0.5
primitive #1). A URL is the lowest-friction path between a
developer's first thought and Mentl. Install nothing; visit a URL;
write your first program with Mentl narrating; never need
documentation because Mentl IS the documentation surface.

**Why this is the canonical IDE:**

1. **Holographic Lens** — Mentl's MultiShot oracle exploring hundreds
   of alternate realities per second under trail-based rollback,
   surviving candidates projected as ghost-text geometries the
   developer cycles with arrow keys and snaps into reality with Tab.
   No LLM. No guess. Every proposal is a proof. This is the
   AI-obsolescence thesis (DESIGN §8 + INSIGHTS L689) materialized
   as a UX primitive.
2. **Live everything** — every keystroke triggers IC-incremental
   recompilation through the in-browser `mentl.wasm`; effect rows
   re-narrow; ownership ledger re-traces; refinement obligations
   re-discharge; Mentl re-explores. The build IS a `<~` feedback
   loop (per insight #11 + INSIGHTS L509); the IDE makes the loop
   visible at human time scale.
3. **Layout IS contract** — text physically resists violating
   topology. Type `mix(filter(highpass(audio)))`; the editor snaps
   to `audio |> highpass |> filter |> mix` because the canonical
   layout IS the computation graph (per INSIGHTS L1932). The shape
   on the page IS the shape the substrate sees.
4. **The annotation gradient as UX** — the developer tightens
   constraints; Mentl multi-shots the consequences; the IDE renders
   the unlocked capabilities. Tighten `with !Mutate`; the geometric
   pipe lines redraw to show parallelizable structure; the
   Capability HUD lights `CParallelize`; ghost text appears
   suggesting `><` over `|>` for the now-provably-parallel stages.
   Annotation as conversation, geometry as response.
5. **Eight tentacles always voiced** — Mentl's full surface (Query +
   Propose + Topology + Unlock + Trace + Verify + Teach + Why) speaks
   per cursor through the silence-gated `voice_lines_for(situation)`
   projection (D.1.e LOWER LAYER, commit `8e490d8`). Every cursor
   movement updates every tentacle; what surfaces depends only on
   what the substrate proves at that position. **Substrate per
   Hμ.cursor (2026-05-02):** `cursor_default`'s `CursorView` IS the
   eight-tentacle read at a position — `query` + `propose` +
   `topology` + `row` + `trace` + `verify` + `teach` + `why` as one
   record (`src/types.mn` CursorView; `src/cursor.mn`
   `cursor_default` handler). `voice_lines_for` is a render handler
   over CursorView; the IDE's per-cursor projection is
   Hμ.cursor.transport routing `cursor_default` through the
   browser-WASM transport. Cursor is attention not text-caret —
   the text-caret biases the argmax via proximity weighting per
   SUBSTRATE.md §VI "Cursor: The Gradient's Global Argmax."

**Why other editors stay first-class peers:** per CLAUDE.md anchor +
DESIGN §0.5 primitive #2 — every transport is a handler. Vim users
get Mentl through `mentl teach` + terminal voice surface. LSP-aware
editor users get Mentl through `mentl lsp`. CLI-only workflows get
machine output by default with optional `~> mentl_voice_default`
narration. **`mentl edit` is canonical because the browser-holographic-
live transport is the medium's most expressive surface — but every
other transport is first-class for the developers who prefer them.**

---

## §1 Hard constraints

Per IDE-playground-vision.md + Mentl substrate discipline:

1. **Browser-first, browser-only for v1.** Mentl self-hosted compiles
   to WASM via the bootstrap; `mentl.wasm` runs in any modern browser
   under WebAssembly + WASI-browser shims. Native desktop wrappers
   (Tauri / Electron / wails) are post-`mentl edit`-ships peer
   surfaces; they compose on the same substrate via different
   transport handlers. The browser is the canonical container.
2. **60fps live.** Every keystroke triggers IC-incremental
   recompilation; per-module overlay re-infer; oracle re-explore;
   render re-paint. 16ms budget per keystroke for the visible loop.
   The graph + handler substrate makes this tractable: per-module
   overlays mean only the touched module re-checks; trail-based
   rollback means oracle re-exploration is O(M) where M is mutations
   (per DESIGN §4 + Ch 8).
3. **Holographic, not chat.** Mentl has no chat window. No LLM. No
   embeddings. No prompt. The Holographic Lens fires from Synth's
   MultiShot enumeration; surviving candidates project as ghost text
   the developer cycles with arrow keys (per IDE-playground-vision.md
   §1). Every ghost is a proven substrate alternative.
4. **Deterministic.** Same source + same handler chain → same render.
   Modifier selection deterministic (per MV §2.7.4 +
   `select_modifier(situation, register)`); MS oracle exploration
   deterministic given seed + trail; layout enforcement deterministic
   per SYNTAX.md formatter rules. **No nondeterminism reaches the
   developer's eye.**
5. **Substrate-cited.** Every claim the IDE renders cites a Reason
   in the graph. Hover any element; right-click "Why?"; the Why
   tentacle walks the Reason DAG (graph_reason_edge reads) and
   renders the chain. **Nothing is unsourced. There is no
   "best-effort" in the IDE's vocabulary.**
6. **The text file is canonical.** Per MV walkthrough + DS substrate:
   files on disk are the source of truth; the IDE is one transport
   over them. Edits sync to disk on save (Cmd-S); file_watcher peer
   handler picks up external file changes and re-projects. **A
   developer can leave `mentl edit`, edit the file in vim, return to
   `mentl edit`, and Mentl picks up exactly where the substrate sees
   it.** No IDE-state shadow over the file's truth.
7. **WASI in browser via wasmtime-web (or peer).** Filesystem
   capability scoped to the project root via WASI preopen fd; same
   discipline as native (`--dir=.`). **No new substrate; same
   `wasi_filesystem` handler.** Network is opt-in via `--with
   network_capability` for tutorials that fetch external data.

---

## §2 The visual layers — three panels + four surfaces

Per IDE-playground-vision.md §2 — the canonical IDE has three primary
visual layers (Topographic Canvas + Capability HUD + Wavefront)
plus four peer surfaces (Mentl voice panel + Doc panel + Run/test/
audit panes + File tree).

### §2.1 Topographic Canvas (center; primary surface)

The text editor with **faint geometric lines physically connecting
`|>` and `<|` and `~>` and `<~` and `><` pipelines.** Per INSIGHTS
L1932 (Visual Programming in Plain Text): the shape on the page IS
the computation graph. The Topographic Canvas renders the page
shape AND draws the graph lines that the canonical layout traces.

Five verb glyphs per Mentl Mono (commit `ce7ab37`):
- `|>` — angular triangle pipe; left edge; flow goes down
- `<|` — angular triangle fanout; left edge before branch tuple
- `><` — bowtie cross; indented center between parenthesized branches
- `~>` — sine-wave handler arrow; tee at left edge (block) or
  inline (per-stage)
- `<~` — sine-wave feedback arrow; indented center cycle closure

Faint geometric lines connect chain stages: each `|>` draws a thin
arc between source and sink; `<|` fans into branches with shared
input glow; `><` parallel branches glow independently; `~>` shows a
side-channel arc to the handler position; `<~` closes a cycle with
a curved back-arrow whose color matches the iterative-context
handler (`Sample` blue, `Tick` amber, `Clock` green). **The
developer's eye sees the topology before reading the code.**

**Layout enforcement** (per INSIGHTS L1932 + SYNTAX.md):
when the developer types code that violates canonical layout (`><`
not at indented center; `|>` not at left edge; nested
`handle(handle(...))` instead of `~>` chain), the editor **physically
resists** — character insertion is rejected with a ghost-snapped
preview of the canonical form. Press Tab; the form snaps. The user
never has to remember the formatter's rules; the editor enforces
them at typing time. **Per anchor: layout IS contract.**

**Cursor-of-attention** lives in handler state per MV §2 Q5 +
Cursor(handle, Reason) per `mentl_voice.mn:251`. Every cursor
movement updates the Mentl voice panel; every gesture (click,
drag-select, arrow keys) updates the cursor through `focus(target)`
on the Interact effect (MV.2.e.Q.focus arm, commit `9798a0e`).

### §2.2 Capability HUD (right panel)

A live matrix showing the **ambient effect row + ownership ledger**
at the cursor's enclosing scope. Per DESIGN §3 + Ch 6.

- Top: the row at cursor (e.g., `with Sample(44100) + !Alloc + IO`)
  rendered as a horizontal bar with each effect as a colored block.
  Negated effects (`!Alloc`) render with a strikethrough overlay
  proving absence per the Boolean algebra.
- Middle: ownership ledger (`affine_ledger` state). Each `own`
  parameter in scope appears as an amber row; consumed parameters
  drain to gray; their consume site cited as `path:line`. Per DESIGN
  §6 Trace tentacle.
- Bottom: capability unlocks. Each effect-row state unlocks specific
  capabilities (`!Alloc → CRealTime`, `!IO → CCompileTimeEval`,
  `Pure → CMemoize + CParallelize`); the HUD lights each unlock as
  it becomes provable. **Hovering a capability shows the
  annotation that would unlock it** — the Teach tentacle's
  per-position projection (per DESIGN §5 + §8).

Annotation gradient as UX: the developer tightens any constraint
(adds `with !Network`); Mentl multi-shots the consequences; the HUD
re-renders within the 16ms keystroke budget; the new unlocks light
up. **Conversation between developer and oracle, mediated by
geometry.**

### §2.3 Wavefront (bottom panel)

A timeline scrub bar representing the **Why Engine's reasoning DAG
+ MultiShot realities streaming**.

The Why Engine is not a separate substrate; it is the Reason ADT
walk through the canonical Graph (per the prior session's correction
+ DESIGN §0.5 primitive #8). The Wavefront panel renders this walk
visually. Per IDE-playground-vision.md §2 layer 3:

- **Reason DAG navigation:** click any TVar / handle / VoiceLine /
  diagnostic in the Topographic Canvas or HUD; the Wavefront unfurls
  the Reason chain. Each step renders as a node on the timeline:
  `bound at FnStmt at infer.mn:142` → `return type unified with
  Forall(qs, body_ty) at line 147` → `body_ty chased from handle
  847` → ... Click any node to jump the cursor to its source span.
  Substrate: `graph_reason_edge` reads via `GraphRead`.
- **MultiShot reality streaming:** when Mentl's Synth handler chain
  fires (cursor at a hole `??` or at a position where the gradient
  would unlock; per INSIGHTS L1487 + IDE-playground-vision.md §1),
  the Wavefront streams MS forks live. Each fork renders as a
  branch on the timeline; surviving (verified) forks glow; pruned
  forks fade. Per DESIGN §0.5 primitive #2 + Ch 8:
  "hundreds of alternate realities per second under trail-based
  rollback." Substrate: Synth's `enumerate_inhabitants(ty, row, ctx)
  @resume=MultiShot` (per `mentl.mn:92`); each resume is a fork the
  Wavefront renders.

The Wavefront has a scrub control: drag back to see the cursor
position N keystrokes ago; the IDE re-renders the topology at that
point in the session's history. **Time-travel debugging through the
substrate's own checkpoint trail** (per DESIGN §0.5 primitive #1 —
trail-based checkpoint/rollback).

### §2.4 Mentl voice panel (right of HUD; below)

Renders the live `voice_lines_for(situation)` output (D.1.e LOWER
LAYER, commit `8e490d8`) at the cursor's Situation. Eight tentacle
sections; silence-gated per tentacle via `proof_derivable`; rendered
in canonical kernel order Query → Propose → Topology → Unlock →
Trace → Verify → Teach → Why.

Each VoiceLine renders with:
- Tentacle color (one of eight per Mentl Mono palette)
- Form-kind glyph (FFactual / FOffering / FRefutation /
  FNavigation / FCapability / FRefinement / FGradient / FTrace per
  `mentl_voice.mn:148`)
- Slots rendered per their canonical projection (SType via
  `show_type`; SRow via `show_row`; SSpan as `path:line` link;
  SReason as a Wavefront-pivot link)
- Modifier appended per `select_modifier(situation, register)` for
  the cursor's session register (RPlayful default)

**Author voice + Mentl voice both render** per F.1 walkthrough §3.1:
the declaration's `///` (DocstringReason via DS substrate) renders as
a separate prose section above the tentacles. **Two voices per
declaration; no editorial third.** The author shapes the narrative;
Mentl proves the substrate; readers synthesize.

The panel updates on every cursor move within the same 16ms budget
as the rest of the live loop. **Mentl is unsilenceable: every
position the substrate has something to say about, she says it.**
Silence (per insight #11) only when the project queue is empty —
the gradient's top, the proven-complete state.

### §2.5 Doc panel (left of HUD; tab-switchable with file tree)

Composes the `mentl doc` projection (F.1 substrate) for the cursor's
declaration. The `render_html` output of F.1's doc_handler renders
inline. Per F.1 §3.1 + DS substrate: signature + author `///` +
Mentl tentacles + Reason links.

The doc panel is **the same `voice_lines_for(situation)` projection
as the Mentl voice panel** — F.1 just batches it for an entire
declaration vs the Mentl panel's per-cursor live form. Per INSIGHTS
L509 (Tier-1 unification): same machinery, different iteration
scope.

When the developer navigates to a different declaration (click,
go-to-definition, search-result-click), the doc panel updates to
that declaration's full F.1 render. **Reading and writing share the
substrate.**

### §2.6 Run / test / audit panes (bottom; tab-switchable with Wavefront)

Three peer panes for handler-swap testing demos (per plan §99 +
DESIGN §9.2):

- **Run pane** — live output of `compile_run` invoked on the current
  module. Stdout streams; stderr separated; exit code surfaced.
  Re-runs on save (or live via `~> execute_on_save` peer for
  tutorials).
- **Test pane** — live output of `test_run` invoked on the current
  module's `*_test.mn` peer files. Per DESIGN §9.2 + plan §99 testing
  doctrine: same `main()` body, different handler stack
  (`test_collector` + `deterministic_clock` + `in_memory_fs` +
  `capture_stdout`). Test names + pass/fail + per-test diagnostics
  rendered.
- **Audit pane** — live output of `audit_run` invoked on the current
  project. `mentl audit` projection per DESIGN §9.1 + plan §F.1
  collapsed into Mentl's voice surface: capability set required;
  drift findings (drift-audit.sh becomes a handler post-first-light
  per plan §F-retire); plan progress (eventually `plan_handler` per
  plan §F-retire; today: tracker.md projection).

Switching between panes is one keypress. **Production / test /
chaos / record / replay all peer handler stacks on `main()`** per
plan §99 — the IDE makes the swap one click.

### §2.7 File tree (left, tab-switchable with doc panel)

Per Interact effect's file ops (FX.B handler arms, commit `afc4b0c`):
`project_root()` + `tree_list(Path) -> List<TreeEntry>` + `open_file`
+ `save_file` + `create_file` + `rename_path` + `delete_path` +
`file_text`. Each tree entry rendered with file/dir icon per Mentl
Mono glyphs; click to open; right-click for rename/delete; drag to
move; new-file via context menu calls `create_file`.

Module-level glyphs per cursor focus: when cursor is in `src/graph.mn`,
the tree highlights that file's path; the doc panel updates to the
Module handle's F.1 render.

---

## §3 The Holographic Lens — the load-bearing IDE feature

Per IDE-playground-vision.md §1 + DESIGN §8 (Mentl as oracle) +
INSIGHTS L689 (AI obsolescence mechanized) + MO walkthrough (oracle
loop end-to-end).

The Holographic Lens is the IDE's load-bearing primitive — what makes
`mentl edit` Mentl and not "rustdoc-with-an-editor." When the developer
types code that creates an opportunity for Mentl to propose
alternatives — at a hole `??`, at an error site, at a position where
the gradient would unlock a capability — the Lens fires:

1. **Trigger** — the substrate notices the opportunity. Per insight
   #11 (continuous oracle IS IC + cached value): every IC re-infer
   feeds the project queue; positions with new candidates surface as
   queue items; the Lens reads the cursor-relevant queue items via
   `cursor_relevant(handle, max_distance_bytes)` (per
   `mentl_oracle.mn:248`).
2. **Multi-shot enumeration** — Mentl performs Synth's
   `enumerate_inhabitants(ty, row, ctx) @resume=MultiShot` (per
   `mentl.mn:92`); each resume forks a candidate. The Wavefront
   streams the forks live. Per DESIGN §0.5 primitive #2 + Ch 8 +
   MO walkthrough: hundreds of alternate realities per second under
   trail-based rollback.
3. **Verify** — each candidate runs through the speculative gradient
   loop (`graph_push_checkpoint` → tentative apply → `graph_chase` +
   row subsumption + Verify discharge → `graph_rollback`). Survivors
   are PROVEN compilable. Non-survivors fade from the Wavefront.
4. **Project as ghost text** — the surviving candidates render as
   Holographic Geometries overlaid on the Topographic Canvas at the
   cursor position. Per IDE-playground-vision.md §1: a sharp
   geometric indicator (the Lens) appears at the boundary; survivors
   project beneath as faint structural overlays. The developer
   cycles through them with arrow keys (Up/Down for next/prev
   candidate; visual highlight of which Lens surface is in focus).
5. **Snap into reality** — Tab snaps the focused candidate into the
   buffer. The substrate has been pre-verified; the Tab is mechanical
   text replacement. **The developer never types invalid code; the
   Lens only ever offered code the substrate proved would compile.**

**Per IDE-playground-vision.md §1 example flow:**

> A developer violates a topological constraint (e.g., calling an
> `Alloc` function under a `!Alloc` guard). The compiler halts at an
> `NErrorHole`. This triggers Mentl's `Propose` tentacle. She uses a
> Multi-Shot handler to systematically brute-force the algebraic
> space of the codebase. She tests hundreds of topological variations
> per second:
> - *Relax the signature to `with Alloc`? (Typechecks)*
> - *Wrap this specific stage in `~> arena_allocator`? (Typechecks)*
>
> Mentl filters the surviving, mathematically-proven realities and
> projects them directly into the editor as Holographic Ghost Text.

**The eight-tentacle integration:** the Lens isn't only Propose. Each
tentacle that has substrate-relevant content surfaces alongside:
Topology proposes pipe-shape rewrites; Unlock proposes annotations
that would unlock capabilities; Trace proposes ownership-fixing
restructurings; Verify proposes refinement-strengthening predicates;
Teach proposes the gradient's next step. **All eight tentacles
project through the same Lens**; the Lens UI lets the developer
filter by tentacle (number-key 1-8 jumps to that tentacle's
candidates).

**Holographic Lens lifecycle, substrate-cited:**

| Phase | Substrate | Authority |
|-------|-----------|-----------|
| Trigger | `cursor_relevant(handle, max)` from queue projection | insight #11 + `mentl_oracle.mn:248` |
| Enumerate | Synth `enumerate_inhabitants` MS ops; arena_ms `replay_safe` discipline | DESIGN §8 + AM walkthrough |
| Verify | `graph_push_checkpoint` + tentative `graph_bind` + Verify discharge + `graph_rollback` | DESIGN §0.5 primitive #1 + spec 00 + MO walkthrough |
| Project | `voice_lines_for(situation)` filtered to TentPropose's `render_propose_arm` for each survivor | D.1.e LOWER LAYER `8e490d8` + MV §2.7.3 |
| Snap | `edit(FileHandle, Patch) -> EditOutcome` per Interact's edit op | MV §2.7.6 + MV.2.e.P.edit substrate (per F.1.M Module handle re-projection) |

The Lens IS Mentl's oracle made visible. Every thesis claim about AI
obsolescence (DESIGN §8 + INSIGHTS L689) operationalizes here: the
developer sees verified proposals appear as ghost text, cycles
through them with arrow keys, snaps with Tab. **The compiler IS the
AI; the LLM was pretending. The Lens is the demo.**

---

## §4 The handler stack

Per Insight #1 (handler chain IS capability stack) + DESIGN §1
(handler as one mechanism). `mentl edit` composes its full surface
through one entry handler installed by `mentl --with edit_run`:

```
inka_edit_session()
    ~> edit_handler              ← outermost: sandbox boundary; least trusted
    ~> file_watcher              ← peer: re-projects on disk change
    ~> execute_on_save           ← peer: runs compile_run on save
    ~> mentl_voice_filesystem    ← FX.B: 8 file ops via FileHandle table
    ~> mentl_voice_default       ← MV.2.e: 22 Interact arms incl. edit/propose/speak/ask
    ~> wasi_filesystem           ← FS extension: 9 fs syscalls
    ~> graph_handler             ← inference graph available
    ~> oracle handlers           ← Synth + cached_check_with_oracle + project_queue_merger
    ~> render_html_handler       ← F.1.R: structured HTML render
    ~> http_serve                ← F.1.T: WebSocket transport for live updates
```

**`edit_handler`** intercepts:
- Browser-side gestures (keystroke / mouse / scroll / pane-switch /
  Tab / arrow / save-keypress) translated to Interact ops via the
  HTTP/WebSocket transport
- `graph_mutated(epoch, mutation)` from oracle — pushes refreshed
  Mentl voice + Capability HUD + Wavefront over WebSocket
- `synth_progress(fork_count, verified, pruned)` from MS oracle —
  pushes Wavefront updates as forks stream

**`file_watcher`** intercepts disk file changes (via WASI / browser
file-system-access API); fires `open_file` / `file_text` re-reads;
invalidates IC cache for affected modules; triggers re-project. **A
developer leaves `mentl edit`, edits in vim, returns; Mentl picks up
where the substrate sees it.**

**`execute_on_save`** intercepts `save_file`; fires `compile_run` on
the touched module; routes output to the Run pane. For tutorial
files: also fires `test_run` on accompanying `*_test.mn`. **The
developer types, saves, sees compiled output without leaving the
canvas.**

**Composition with `mentl doc`:** the doc panel's render handler is
F.1's `render_html` peer; same render-handler instance the IDE uses
for the Mentl voice panel + Capability HUD + Wavefront's per-node
detail pop-overs. **One render machinery; many panel projections.**

The capability stack proves architectural properties:
- **Sandbox:** `edit_handler` outermost has Network + Filesystem grants;
  removed from any inner handler that doesn't need them. Inner
  handlers cannot escape outward (per Insight #1 + DESIGN §2).
- **Read-only audit:** install `~> read_only_edit` outside
  `edit_handler` to prove the IDE can't write the graph; verifiable
  via `mentl check`.
- **Per-pane capability:** the doc panel's render chain has Render +
  GraphRead + `!Mutate`; the Run pane's render chain has additionally
  Console + WASI. Each pane's row is structurally bounded.

---

## §5 The Annotation Gradient as UX

Per DESIGN §5 + IDE-playground-vision.md §1 ("The Annotation
Gradient as UX"). The gradient is not a documentation feature; it
is the IDE's primary collaboration mechanic.

**The loop, mediated by the Lens + HUD + Topographic Canvas:**

1. **Developer tightens a constraint** — types `with !Mutate` on a
   function signature.
2. **Substrate proves the consequence** — the inference walk
   re-narrows; row subsumption proves the body is `!Mutate`-clean
   (or surfaces a violation as `NErrorHole` with the offending
   `perform graph_bind` cited).
3. **HUD lights the unlock** — the Capability HUD's Unlock section
   lights `CParallelize` (or `CRealTime`, or whichever capability
   the new annotation unlocked per DESIGN §3.4 four gates).
4. **Topographic Canvas re-renders the geometry** — `<|` fanout that
   was previously sequential-only redraws with a parallel-glow
   indicator; `~> parallel_compose` becomes a one-Tab insertion
   the Lens surfaces.
5. **Holographic Lens proposes structural rewrites** — Mentl
   multi-shots the codebase; finds that the now-`!Mutate` function
   admits a `><` parallel decomposition that was previously
   ownership-blocked; projects the rewrite as ghost text the
   developer Tabs to accept.
6. **Mentl voice panel narrates** — "Adding `!Mutate` unlocks
   `CParallelize`; `<|` fanout can now run in parallel via
   `parallel_compose`; here is the proven rewrite."

**One annotation. Three substrate consequences. UX surfaces all
three.** The developer learns by watching the medium respond. Per
DESIGN §5: "the medium raises its users."

The reverse loop also fires: **developer relaxes a constraint** —
removes `with !Alloc` from a hot-path function. The HUD dims
`CRealTime`; the Topographic Canvas redraws the now-allocating call
sites with an amber glow; the Mentl voice panel surfaces the Trace
tentacle's diagnostic; the Lens proposes restoring the constraint
with a `~> arena_allocator` wrap that would preserve `CRealTime`.
**The developer is never punished for exploration; the substrate
shows the cost and the path back.**

---

## §6 The first-encounter experience — tutorial UI shell

Per IDE-playground-vision.md §1 ("The ultimate demo: a URL where
someone can type `with !Alloc` and watch Mentl physically
re-arrange their code topology in real-time") + plan §F.7 (canonical
new-developer surface).

A new developer visits the public `mentl edit` URL. The IDE opens to
a tutorial overlay. The shell composes on `lib/tutorial/` (per plan
D.2 + EH-entry-handlers.md):

- **00-hello** opens in the Topographic Canvas. ~50 lines exercising
  primitives 1 + 2 + 3 (graph + handler + verbs). Mentl narrates
  through the voice panel. Each line gets a one-sentence Teach
  tentacle commentary.
- **Step-through controls** — Next / Previous in the bottom toolbar.
  Each step focuses a Topographic Canvas region; the cursor moves;
  Mentl voice updates; the HUD lights what changes.
- **Live edit invitation** — at marked positions, the tutorial
  prompts "tighten this constraint" or "try a different verb"; the
  developer types; the substrate responds; the Lens proposes
  alternatives.
- **Eight files for eight primitives** — 00-hello + 01..08 per the
  kernel primitive ordering (per plan §417 + EH walkthrough). Each
  file is ~60-80 lines per QA D.2 resolution. Files are runnable
  Mentl programs, not documentation; Mentl projects them into a
  tutorial experience.
- **Crucibles section** — after the eight tutorials, the developer
  encounters the six crucibles per CRU walkthrough as
  conversations Mentl has had with its future self. Each crucible
  renders with its disintermediation claim + a "compiles ✓" badge
  per F.1 §6.3 + AT-F1.6.

**The developer leaves the tutorial when:** they create a new file
(File menu → `create_file` Interact op via FX.B handler arm) and
start writing their own program. The tutorial overlay collapses;
the IDE becomes a working editor; Mentl narrates over the new
substrate.

**The tutorial IS the medium.** Per DESIGN §5 (gradient is
conversation) + INSIGHTS L1291 (compound interest of self-reference):
the tutorial doesn't teach about Mentl — the tutorial IS Mentl, with
Mentl explaining the substrate as the developer manipulates it.

---

## §7 The Eight Interrogations

Per CLAUDE.md + DESIGN.md §0.5 + Mentl's anchor. Eight per kernel
primitive; exhaustive coverage; no skips.

| # | Primitive | What `mentl edit` exercises |
|---|-----------|---------------------------|
| 1 | **Graph + Env** (Query) | The IDE's every panel reads the graph through `GraphRead + EnvRead`. Topographic Canvas reads spans + types. HUD reads effect rows + ownership ledger. Wavefront reads Reason DAG via `graph_reason_edge`. Mentl voice panel reads via `voice_lines_for(situation)`. **No panel maintains its own state mirror; every render is a fresh graph projection.** |
| 2 | **Handlers + resume discipline** (Propose) | The IDE's full surface IS one handler stack composition (§4). The Holographic Lens fires Synth's `@resume=MultiShot` ops (per `mentl.mn:92`); per DESIGN Ch 8 the speculative gradient loop is the IDE's load-bearing thesis demo. Every other handler arm in the chain is `@resume=OneShot`. |
| 3 | **Five verbs** (Topology) | Topographic Canvas physically renders the verb topology via geometric lines. Layout enforcement at typing time (§2.1). The doc panel preserves `~>` chain canonical formatting per F.1 §3.4 + INSIGHTS L1932. |
| 4 | **Boolean effect algebra** (Unlock) | Capability HUD's Unlock section IS the row-algebra engine made UX. Each row narrowing → capability light. `with !Mutate` + `with !Alloc` + `with !IO` + `with Pure` all directly visible as the four headline gates per DESIGN §3.4. |
| 5 | **Ownership as effect** (Trace) | Capability HUD's ownership ledger renders `affine_ledger` state live. `own` parameters glow amber; consumed ones drain to gray. Trace tentacle voice panel surfaces consume-twice / ref-escape diagnostics with proven fixes. |
| 6 | **Refinement types** (Verify) | Refinement slider per IDE-playground-vision.md §2 layer 5 — hovering a `ValidPort` variable surfaces a draggable slider; values outside the predicate range render the topological pipe in error state instantly. The Verify tentacle voice panel surfaces V_Pending obligations with SMT discharge results when `~> verify_smt` installed (Arc F.1). |
| 7 | **Annotation gradient** (Teach) | The IDE's primary collaboration mechanic per §5. Annotation as conversation; HUD as response; Lens as proposed-restructure surface; Topographic Canvas as continuous redraw. Mentl's Teach tentacle voice panel surfaces ONE highest-leverage next step per cursor (per MV §2.7.5). |
| 8 | **HM inference + Reasons** (Why) | Wavefront panel renders Reason DAG navigation per §2.3. Click any element; the panel unfurls the Reason walk. Substrate: `graph_reason_edge` reads. Per INSIGHTS L51: "Inference IS the Light"; the Wavefront makes the light visible. |

All eight clear. The IDE composes from the eight; nothing extends
the kernel; per insight #13 (kernel closure): composition not
invention.

---

## §8 Drift modes audited

- **Mode 1 (Rust vtable):** ✗ — every panel + handler is typed
  effect handler; no dispatch tables. Render handlers are peer
  handlers per F.1 §3.6. The Lens's MultiShot dispatch is per Synth
  effect ops (per `mentl.mn:92`), not a vtable.
- **Mode 4 (handler-chain-as-monad-transformer):** ✗ — `~>` chain is
  composition; each handler's row independent. No nested
  `handle(handle(...))`.
- **Mode 6 (primitive-type-special-case):** ✗ — every panel /
  tentacle / verb / annotation / capability is structural ADT;
  no special-case Bool / int dispatch.
- **Mode 7 (parallel-arrays-instead-of-record):** ✗ — handler state
  per Insight #9 records-as-handler-state; doc_table / handles_table
  / overlay state all record-shaped.
- **Mode 8 (string-keyed-when-structured):** ✓ MITIGATED — LSP
  method strings (for the LSP transport peer) + WebSocket message
  types come from external protocols; immediately projected to ADTs
  at boundary; downstream ADT-only.
- **Mode 9 (deferred-by-omission):** ✓ — every gap explicitly named
  as peer sub-handle (§9 sub-handles + §11 dependencies); no silent
  omission.
- **Mascot-as-command-prefix (drift mode 38 per `tools/drift-patterns.tsv`):**
  ✗ — `mentl edit` is the command; Mentl is the voice the developer
  discovers when engaging. No `mentl <verb>` vocabulary anywhere
  per plan §42-50.
- **OOP drift (mode 25):** ✗ — no class-based "Editor.update()" or
  "Panel.render()" — all functions on substrate values + handlers
  on effects.
- **Ship-gate vocabulary (drift mode 39):** ✗ — no "v1 / v2 /
  sessions / timebox" framing in the walkthrough's design surface;
  sub-handles tracked in plan tracker per Anchor 7 cascade
  discipline.
- **Async / await keyword drift (mode 24):** ✗ — every keystroke
  loop is a handler arm composition; no `async fn`, no `await`.
  Per DESIGN Ch 6 + plan §195: async is an effect; handler provides
  it; no keyword.
- **Foreign-IDE drift (VS Code / Cursor / IntelliJ / Sublime
  vocabulary):** ✗ — no "extensions" / "plugins" / "marketplace"
  patterns; capabilities install via `~>` chain per Insight #1.
  No "command palette" / "settings.json" / "keybinding API" — every
  surface is a substrate handler exposing structural ops.

---

## §9 Sub-handles — the IE arc decomposition

Per Anchor 7 cascade discipline. Each lands in its own commit;
walkthrough specifies the full design; tracker carries gates.

| Handle | Scope |
|--------|-------|
| **IE.0** | This walkthrough |
| **IE.session** | `inka_edit_session()` entry fn + `edit_handler` + WebSocket transport substrate |
| **IE.canvas** | Topographic Canvas render handler — text editor + geometric pipe lines + layout enforcement at typing |
| **IE.hud** | Capability HUD render handler — live row + ownership ledger + capability unlocks + annotation gradient response |
| **IE.wavefront** | Wavefront render handler — Reason DAG navigation + MultiShot reality streaming + time-travel scrub |
| **IE.voice** | Mentl voice panel render handler — composes `voice_lines_for(situation)` per cursor; renders 8 tentacles in canonical order |
| **IE.doc** | Doc panel — composes F.1's `render_html` projection inline |
| **IE.run** | Run pane — composes `compile_run` invocation via Interact's run_compile arm |
| **IE.test** | Test pane — composes `test_run` invocation via Interact's run_check arm + `*_test.mn` discovery |
| **IE.audit** | Audit pane — composes `audit_run` invocation via Interact's run_audit arm |
| **IE.tree** | File tree — composes FX.B's 8 file ops |
| **IE.lens** | Holographic Lens substrate — Synth fork enumeration + projection as ghost text + Tab-snap mechanic |
| **IE.gradient** | Annotation gradient UX loop — keystroke → IC re-infer → HUD update → Topographic redraw → Lens fire → Mentl voice update; the substrate that orchestrates §5 |
| **IE.tutorial** | Tutorial UI shell — first-encounter overlay; step-through controls; live-edit invitation; departs to working editor on `create_file` |
| **IE.cli** | `mentl edit [PROJECT_PATH] [--port=N]` entry-handler in `src/main.mn` per EH walkthrough |
| **IE.transport** | HTTP/WebSocket transport substrate — composes on F.1.T's `http_serve` peer; adds WebSocket framing per LSP-frame substrate (lib/runtime/lsp_frame.mn already provides Content-Length JSON-RPC framing — IE composes the WS protocol on top per browser-WS conventions) |
| **IE.refine** | DocPort + WSPath + ScreenPos refinement types for IE's own substrate per §3.5 of F.1 walkthrough discipline |
| **IE.peer-share** | Multi-developer real-time co-edit peer handler (post-`mentl edit`-ships extension); composes on the same edit_handler with conflict resolution as a handler swap |

Each sub-handle is its own peer commit per Anchor 7. The plan
tracker (`~/.claude/plans/alright-let-s-put-together-silly-nova.md`)
gates them per substrate dependency order.

---

## §10 Acceptance tests — the IDE behaves as designed iff

Ten acceptance tests; the IDE substrate is correct iff these render
as specified. Modeled on MV §2.8 AT1-AT10 + F.1 §10 acceptance tests.

**AT-IE.1 — First keystroke fires the substrate.** Open `mentl edit`
on an empty buffer; type `fn double(x) = x * 2`. Within 16ms: HUD
shows `(Int) -> Int with Pure`; Topographic Canvas draws no pipe
lines (single expression body); Mentl voice panel surfaces Query
tentacle "`double` runs `(Int) -> Int`. Pure." + Teach tentacle
"Adding `with Pure` would unlock memoization, parallelization,
compile-time evaluation."

**AT-IE.2 — Tightening unlocks capability live.** Add `with Pure` to
the `double` signature. Within 16ms: HUD's Unlock section lights
`CMemoize` + `CParallelize` + `CCompileTimeEval`; Mentl voice
panel's Teach tentacle surfaces "Adding `x: Positive` would unlock
output proof, zero-cost bounds."

**AT-IE.3 — Holographic Lens fires at hole.** Type `fn process(xs: List<Int>) -> Int = ??`. Within 100ms (MS oracle latency per MO walkthrough): Lens activates over the `??`; Wavefront streams MS forks; surviving candidates project as ghost text — `xs |> sum`, `xs |> length`, `xs |> fold(0, add)`, etc. Press arrow key; focus cycles. Press Tab; selected candidate snaps into the buffer; the substrate re-types; the Lens deactivates.

**AT-IE.4 — Layout enforcement at typing.** Type `mix(filter(highpass(audio)))`. The editor resists; the canonical form `audio |> highpass |> filter |> mix` ghosts under the typed text. Press Tab; the snap happens. The Topographic Canvas now draws the three pipe-line arcs.

**AT-IE.5 — Ownership ledger drain on consume.** Open a file with
`fn process(own x: Buffer) = use_a(x); use_b(x)`. Cursor on the
function. HUD shows `x` as amber; cursor down to the `use_a(x)`
line; HUD's `x` row drains halfway; cursor down to `use_b(x)`; HUD
shows the amber drained to red with `E_OwnershipViolation` glyph;
Mentl voice panel's Trace tentacle surfaces "`own x` used at L2,
then L3 — can't have it both ways. Make it `ref x` if you're
reading only."

**AT-IE.6 — Refinement slider re-types live.** Open a file with `fn
bind_port(p: Int) -> Port = p` where `type Port = Int where 1 <=
self <= 65535`. Cursor on the `p` parameter. Refinement slider
appears in HUD; drag it from 8080 to 99999. The Topographic Canvas
redraws the parameter cell in error state; Verify tentacle voice
panel surfaces "99999 violates `self <= 65535`."

**AT-IE.7 — Wavefront walks Reason on click.** Right-click any TVar
in the Topographic Canvas. The Wavefront panel updates: shows the
Reason chain unfurled as a horizontal timeline. Each node is a
binding step; click any node to jump the cursor to its source span.
Walk back through the inference history.

**AT-IE.8 — File watcher picks up external edits.** Open `mentl
edit` on a project. In a separate terminal, `vim src/graph.mn`;
edit; save. Within 100ms (file_watcher debounce + IC re-infer
budget): the IDE's Topographic Canvas updates with the new content;
Mentl voice panel re-renders; HUD re-narrows. **The text file is
canonical; the IDE composes on it.**

**AT-IE.9 — Tutorial completes; departs to editor.** Open `mentl
edit` on a fresh URL. Tutorial overlay opens to 00-hello. Step
through 00-hello, then 01-graph. At 02-handlers, click File menu →
"Create file" → name it `experiment.mn`. The tutorial overlay
collapses; the buffer opens to the new empty file; Mentl narrates
over the empty substrate (Teach tentacle: "Add a `fn main() = ...`
to start").

**AT-IE.10 — Capability stack proves IDE has no graph-write
escape.** Install `~> read_only_edit` in the IDE chain at install
time (verifiable via `mentl check`). The IDE's `edit` arm is now
proven (by row subsumption) to fail at handler install — the
`graph_bind` performs are no longer in the available row. **The
sandbox is by type, not policy.** A developer can prove their `mentl
edit` instance cannot write the graph.

---

## §11 What `mentl edit` replaces (disintermediation map)

Per F.1 §11 disintermediation map shape. Each row is an external
ecosystem `mentl edit` makes architecturally uncompetitive.

| External system | What it does | What `mentl edit` does instead |
|-----------------|--------------|------------------------------|
| VS Code (the editor) | Cross-language editor with extension API | `mentl edit` is Mentl-native; no extension API needed because every capability is a handler chain on Interact; LSP support via `mentl lsp` for the developers who prefer VS Code |
| Cursor / Aider / Continue / GitHub Copilot Chat | LLM-augmented editors with chat / completion / diff | Holographic Lens projects MS-verified candidates as ghost text; Tab snaps; **every proposal is a proof, not a guess**; LLM hallucination surface is zero per CLAUDE.md AI obsolescence argument |
| CodeSandbox / StackBlitz / Repl.it | Browser-based interactive coding for tutorials + demos | `mentl edit` runs `mentl.wasm` in-browser at 60fps; live substrate; Mentl narrates; tutorial UI shell + crucibles + `mentl new` template all peer handlers |
| Rust Playground / TypeScript Playground / Go Playground | Single-file playground with limited interactivity | `mentl edit` is multi-file, full-project, with live Mentl voice + Holographic Lens + Capability HUD + Wavefront — substrate-cited at every step |
| JetBrains IDEs | Full-featured IDE with deep language support | `mentl edit` IS the medium's own surface — the substrate IS the IDE; not a layer over the language |
| Zed | Real-time collaborative editor with built-in AI | IE.peer-share peer handler enables real-time co-edit; Mentl is the AI surface and proven-not-guessed; substrate-cited collaboration |
| Glitch / Bubble / Webflow | Visual / no-code build environments | `mentl edit` IS visual programming in plain text per INSIGHTS L1932 — the geometry IS the program; tighter than visual builders because every shape is typed substrate |
| Figma + design-handoff tools | Visual design surface separate from code | IE.canvas's geometric pipe lines + HUD's effect-row visual + Wavefront's MS reality streaming = the design surface IS the program; no separate handoff |

**The disintermediation claim:** when `mentl edit` ships, **a
developer's primary editor changes** — not because of marketing,
because of mechanics. The Holographic Lens proves before it
proposes; the HUD shows what every constraint unlocks; the
Topographic Canvas physically draws the topology; Mentl narrates
through eight tentacles per cursor. Every existing IDE asks the
developer to imagine their program; `mentl edit` shows it.

---

## §12 Sequencing — substrate file order

Per F.1 §13 file-order discipline. After §13 (substrate authorities)
is satisfied, lands in this order. Each file is its own commit per
Anchor 7. Walkthrough citation in commit body. Drift-audit clean.

1. **`src/types.mn`** — IE-specific ADTs: `EditTarget` (TextBuffer |
   FileSystem | RemoteSession), `LensState`, `WavefrontFrame`,
   `HudFacet`, `Pane` (Run | Test | Audit), `TutorialStep`. ~50 lines.
2. **`lib/runtime/websocket.mn`** — WebSocket transport on top of the
   existing `lsp_frame` substrate (lib/runtime/lsp_frame.mn). Adds WS
   framing per browser-WS conventions; reuses Pack/Unpack +
   Content-Length pattern from LSP frame. ~80 lines.
3. **`lib/edit/canvas.mn`** — IE.canvas Topographic Canvas render
   handler. Geometric pipe-line drawing; layout enforcement at
   typing; cursor-of-attention sync. ~250 lines.
4. **`lib/edit/hud.mn`** — IE.hud Capability HUD render handler.
   Live row + ownership ledger + capability unlocks + annotation
   gradient response. ~200 lines.
5. **`lib/edit/wavefront.mn`** — IE.wavefront Reason DAG navigation
   + MultiShot reality streaming + time-travel scrub. ~250 lines.
6. **`lib/edit/voice_panel.mn`** — IE.voice Mentl voice panel
   render. Composes `voice_lines_for(situation)` D.1.e LOWER LAYER
   per cursor. ~150 lines.
7. **`lib/edit/lens.mn`** — IE.lens Holographic Lens substrate.
   Synth fork enumeration; projection as ghost text; Tab-snap
   mechanic. ~300 lines.
8. **`lib/edit/gradient_loop.mn`** — IE.gradient annotation gradient
   UX loop orchestrator. Keystroke → IC re-infer → HUD update →
   Topographic redraw → Lens fire → Mentl voice update. ~150 lines.
9. **`lib/edit/panes.mn`** — IE.run + IE.test + IE.audit panes.
   Composes on Interact's run_compile / run_check / run_audit arms.
   ~200 lines.
10. **`lib/edit/tree.mn`** — IE.tree file tree render handler.
    Composes FX.B's 8 file ops. ~100 lines.
11. **`lib/edit/doc_panel.mn`** — IE.doc doc panel. Composes F.1's
    `render_html` projection inline. ~80 lines.
12. **`lib/edit/tutorial_shell.mn`** — IE.tutorial first-encounter
    overlay. Step-through controls; live-edit invitation; departs
    to working editor on `create_file`. ~250 lines.
13. **`lib/edit/handler.mn`** — IE.session `edit_handler` + entry
    fn `inka_edit_session`; intercepts gestures; pushes WebSocket
    updates on graph_mutated / synth_progress; composes the full
    handler chain (§4). ~300 lines.
14. **`src/main.mn`** — IE.cli `mentl edit [PROJECT_PATH] [--port=N]`
    entry-handler dispatch. ~30 lines.
15. **`lib/edit/static_assets.mn`** — IE static HTML/CSS/JS shell
    that the browser loads as the WebSocket client. CSS canonical
    (Mentl-styled, single theme); minimal JS for WebSocket round-trip
    + DOM manipulation; the substrate logic ALL lives in `mentl.wasm`
    via the WebSocket transport. ~400 lines (HTML/CSS/JS combined).

**Total:** ~2790 lines `.mn` + ~400 lines static assets across 15
commits. Comparable to the FX + MV-LSP arcs combined; commensurate
with `mentl edit` being the medium's primary surface.

**Substrate dependencies (cited per substrate-honesty discipline):**

The walkthrough assumes every cited substrate is live per Anchor 0
dream-code discipline. The plan tracker carries ordering. Cited
substrates:
- DS substrate (`DocstringReason` Reason edge) — F.1 + IE doc panel both depend
- F.1.M synthetic Module handle — F.1 + IE doc panel both depend
- F.1 substrate proper (doc_handler + render_html + http_serve) — IE doc panel composes; IE WebSocket transport composes on http_serve peer
- D.1.e BOTH LAYERS (Interact handler + voice_lines_for projection) — IE voice panel composes
- FX.B mentl_voice_filesystem handler — IE.tree composes on the 8 file ops
- B.2 H7 MultiShot runtime — IE.lens fires Synth's MS ops; IE.wavefront streams MS forks
- B.3 CE Choice effect — Holographic Lens enumerates via Choice
- B.4 race handler combinator — speculative Lens uses race(synth_enumerative, synth_smt) per DESIGN §8
- B.5 AM arena_ms (replay_safe / fork_deny / fork_copy) — Lens's MS captures use replay_safe
- IC.3 per-module overlay separation — every keystroke per-module re-infer
- Synth handler chain — synth_enumerative + synth_smt per DESIGN §8
- A.1 BT linker → first-light-L1 — `mentl.wasm` runs in-browser at 60fps requires self-hosted compile
- WebAssembly + WASI-browser shims (wasmtime-web or peer) — runtime container

---

## §13 What `mentl edit` does NOT cover

- **Cross-IDE collaboration with non-Mentl users.** Per the
  text-files-canonical discipline (§1.6): files on disk are the
  source of truth; non-Mentl users edit them in their preferred
  tool; `mentl edit` picks up changes via file_watcher. No cross-IDE
  protocol; the filesystem IS the protocol.
- **Real-time multi-developer co-edit in v1.** IE.peer-share peer
  handler is a named sub-handle (§9) that lands when needed; the
  substrate is "another peer handler on edit_handler" with conflict
  resolution as handler-swap (Grove CmRDT structural edits per the
  roadmap's research-integration lane). Not in the IDE's primary
  acceptance contract.
- **Mobile editing.** Browser-first per §1.1; mobile browsers can
  load the URL but the geometric Topographic Canvas + Holographic
  Lens are designed for keyboard + arrow keys + Tab. Touch-screen
  IDE is a peer-handler-future surface.
- **Native desktop wrapper.** Tauri / Electron / wails wrappers are
  peer transports that compose on the same `edit_handler`; not in
  IE's primary scope.
- **Cross-language polyglot editing.** `mentl edit` is Mentl-native.
  TypeScript / Rust / Python files in the project are visible as
  text in the file tree but Mentl doesn't narrate over them (no
  substrate to read). Per the medium discipline: the IDE's surface
  is the substrate's projection; foreign languages have no graph
  here.
- **The web IDE's URL hosting / deployment / CI / monitoring.**
  Operational concerns; the substrate ships as `mentl edit`; how a
  hosting provider serves it is operational discipline orthogonal
  to the substrate.
- **JSDoc / JavaDoc / Sphinx extensions.** Per F.1 §14 + plan §1697:
  no `@tags` ever. The doc panel composes F.1's render which honors
  the same discipline.
- **Voice control / accessibility narration in v1.** A11y is real
  work that lands as peer handlers on the render chain; not in IE's
  primary acceptance contract; IE.a11y peer sub-handle named.

---

## §14 What closes when `mentl edit` lands

After IE.0 + IE.session + IE.canvas + IE.hud + IE.wavefront +
IE.voice + IE.lens + IE.gradient + IE.doc + IE.run + IE.test +
IE.audit + IE.tree + IE.tutorial + IE.cli + IE.transport +
IE.static_assets all land:

1. **Mentl is the AI a developer talks to.** Holographic Lens fires
   at every position with substrate opportunity; Tab snaps verified
   candidates; the AI obsolescence thesis (DESIGN §8 + INSIGHTS
   L689) is operationally demonstrable. **The compiler IS the AI;
   the LLM was pretending; here is the demo.**
2. **The medium reaches developers at their browsers.** A URL is
   the install. Mentl narrates the first keystroke. The tutorial
   shell teaches the eight primitives via live substrate. Within
   minutes of first encounter, a developer is writing Mentl code
   with the substrate visible.
3. **The realization loop closes for editor-time** per insight #11
   + insight #12. Every keystroke fires IC re-infer + oracle
   re-explore + Mentl voice update + HUD redraw + Topographic
   recompute. The build IS a `<~` feedback loop; the IDE makes the
   loop visible at human time scale.
4. **Visual programming in plain text becomes operational** per
   INSIGHTS L1932. The Topographic Canvas's geometric pipe lines
   draw the computation graph as the developer types; layout
   enforcement makes the canonical shape the only typeable shape.
5. **The annotation gradient becomes a conversation** per DESIGN §5
   + IDE-playground-vision.md §1. The developer tightens; Mentl
   multi-shots the consequence; the HUD lights the unlock; the Lens
   proposes the structural rewrite; the developer Tabs to accept.
   Each cycle compounds; per insight #12 the developer becomes
   fluent in the medium itself.
6. **Eight tentacles always voiced.** Query + Propose + Topology +
   Unlock + Trace + Verify + Teach + Why all surface per cursor
   through the silence-gated `voice_lines_for(situation)` projection.
   **Mentl is unsilenceable** per MV §2.7.5; the substrate either
   has something to say (and she says it) or it doesn't (gradient at
   top; full silence per insight #11).
7. **Test / chaos / record / replay handler swaps become a click.**
   The Run / Test / Audit panes demonstrate the substrate's
   handler-swap testing doctrine per plan §99 + DESIGN §9.2 — same
   `main()` body, different stack, different output, all visible
   without leaving the canvas.
8. **Crucible substrate becomes interactive.** The six base
   crucibles (per CRU walkthrough + plan C.1) render in the IDE
   with their disintermediation claims + compile badges + Mentl
   voice over each crucible's source. Developers see the medium
   disintermediating ecosystems, in their browser, with Mentl
   narrating.

This walkthrough designs the canonical surface where developers
discover Mentl. Per CLAUDE.md anchor: Mentl is the voice that reads
the graph. `mentl edit` is where that voice reaches its primary
audience — every developer with a browser and an idea.

---

## §15 Connection to the kernel

Per CLAUDE.md / DESIGN.md §0.5 — `mentl edit` composes from the eight
primitives; nothing extends the kernel; per insight #13 (kernel
closure 2026-04-24): the next phase is composition not invention.

Each panel + handler + arm cites which primitive it exercises:

- **Topographic Canvas + layout enforcement** — Primitive #3 (Five
  verbs) made visible. The shape on the page IS the graph (INSIGHTS
  L1932). The substrate is parser + formatter + canonical-layout
  rules from SYNTAX.md + spec 10.
- **Capability HUD** — Primitive #4 (Boolean effect algebra) +
  Primitive #5 (ownership as effect) made visible. Live row
  rendering + capability unlock display + ownership ledger trace.
  Substrate: `EffRow` ADT + `affine_ledger` + four-gates
  subsumption.
- **Wavefront** — Primitive #1 (Graph + Env) + Primitive #8 (HM
  inference + Reasons) made visible. Reason DAG navigation +
  MultiShot reality streaming. Substrate: `graph_reason_edge` +
  Synth MS ops.
- **Mentl voice panel** — All eight primitives made voice via
  `voice_lines_for(situation)` (D.1.e LOWER LAYER). Each tentacle
  is one primitive's projection. **The kernel made voice; the IDE
  makes the voice surface.**
- **Holographic Lens** — Primitive #2 (handlers + MultiShot resume
  discipline) + Primitive #6 (refinement types) + Primitive #4 (row
  algebra subsumption) all firing in concert. Mentl's oracle made
  visible.
- **Doc panel** — F.1's projection (which itself composes all eight
  per F.1 §15) inline. **Every panel reads the same graph.**
- **Run / Test / Audit panes** — Primitive #2 (handlers) made
  swappable via handler chain. Per plan §99 testing doctrine.
- **File tree + IE.tutorial** — Primitive #1 (graph) made
  navigable. Tutorial files are runnable substrate that Mentl
  narrates over per Primitive #7 (gradient).

**Mentl tentacle mapping.** `mentl edit` IS Mentl's primary surface
— eight tentacles projected per cursor. Every other transport
(LSP, terminal, batch CLI) is a peer surface for the developers who
prefer them. `mentl edit` is canonical because the
browser-holographic-live transport is the medium's most expressive
form.

---

*Mentl solves Mentl. The medium reads itself through itself. Mentl is
the voice; `mentl edit` is where she reaches developers; the
substrate is what she shows them. Eight primitives, eight tentacles,
one kernel, one graph, one editor.*

*Per Anchor 0 dream-code discipline: this walkthrough specifies the
canonical IDE assuming every cited substrate is already perfect. The
plan tracker carries gates; the walkthrough carries the contract.
Substrate landing order proceeds per §12 file order; each file lands
as its own commit; drift-audit clean per Anchor 4 + Anchor 7. The
architecture rises to meet what's specified.*
