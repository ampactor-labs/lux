# F.1 — `mentl doc` walkthrough

*The terminal-handler manifestation of the toolchain unification. The
same pipe that produces binaries produces understanding when the doc
handler is installed.*

**Handle:** F.1 (Phase F — post-first-light surface; design contract
lands ahead of substrate per Mentl's substrate-first posture).
**Status:** 2026-04-24 · seeded.
**Authority:** `docs/DESIGN.md` §9.12 (Documentation as handler);
`docs/SUBSTRATE.md` §VIII "The Graph IS the Program" + §III "The
Handler IS the Backend" + §III "The Handler Chain Is a Capability
Stack" + §II "Visual Programming in Plain Text"; `docs/DESIGN.md`
(meta-unification, three things, documentation-as-effect,
pipe-flows-understanding, examples-not-tests, crucible pattern —
the vision-level claims this walkthrough composes from) +
§"AI Obsolescence Mechanized" (L689).
**Walkthrough peers:** `DS-docstring-edge.md` (substrate for `///` →
graph), `MV-mentl-voice.md` (Mentl's tentacle handlers), `EH-entry-handlers.md`
(`mentl --with` dispatch), `CRU-crucibles.md` (crucible framing).

---

## §0 Framing

`mentl doc` is the terminal-handler manifestation of the toolchain
unification. The same compile pipeline that produces binaries produces
understanding when the doc handler is installed. There is no
documentation generator separate from the compiler — there is one
pipeline and a handler that reads it. Per INSIGHTS L588: *"The pipe
doesn't just flow data. It flows understanding."* F.1 IS that flow's
terminal handler.

This frames every section. F.1 is not "rustdoc-but-better." It is the
terminal-handler form of a unification that already includes
`compile_run`, `test_run`, `chaos_run`, and (cursor-time) Mentl's
`mentl_voice_default`. Differentiation against rustdoc / ExDoc / DocC /
Hoogle / Lean Finder is structural, not competitive — those systems
extract from a parse external to their compiler; F.1 reads the same
graph the compiler proves on.

The "AI obsolescence mechanized" claim (INSIGHTS L689) has its
doc-surface manifestation here. F.1 is what makes Mentl's docs
un-driftable from code, which makes them strictly more useful than
any extracted-comment doc to LLM-tool consumers (Cursor / Aider /
Continue / RAG frameworks) — because the proof always exists in the
graph, every claim cites a Reason chain, and consumers get a corpus
no extracted-comment system can match.

---

## §1 Sequencing — what gates F.1

F.1 lands as a Phase F handle (post-first-light), but the walkthrough
lands ahead of substrate. Substrate gates, in dependency order:

1. **D.1.c** (silence_predicate) — landed `1e8ddce`. Pure tentacle
   firing rules per MV §2.7.5. F.1 reuses these gates.
2. **DS** (`DS-docstring-edge.md`) — `///` reaches the graph as
   `DocstringReason(String, Span)` edge per DS §3.2 candidate B + §3.1
   candidate A+C. Parser attaches; inference threads to env. F.1's doc
   handler reads `DocstringReason` via existing `GraphRead`. **No new
   `effect Document` declaration**; INSIGHTS L570's framing
   ("`///` emits a `Document` effect") is satisfied semantically
   (docstrings reach the doc handler) by DS's lighter Reason-edge
   substrate. The compile handler discards the Reason at codegen; the
   doc handler reads it.
3. **D.1.e** (`mentl_voice_default`) — interface contract refines to
   `Situation -> List<VoiceLine>` (silence-gated per tentacle). LSP
   picks one for cursor surface; F.1 renders all. The wrap is one fold
   over the 8 tentacles; additive over the in-flight handler arms.
4. **Synthetic Module handle** — graph extension; one variant on
   `NodeBody` (`NModule(path, decls)`) wired in `pipeline.mn` or
   `driver.mn`. Module-level `///` attaches via DS to the Module
   handle, not to a workaround. Per INSIGHTS L1858 — re-parsing source
   to find module docs would be reading-the-shadow.
5. **F.1 substrate proper** — doc handler + render handlers + transport
   handlers + adaptive shell dispatch.

**Pre-B.2 graceful degradation.** Teach tentacle silent for most decls
(no MultiShot-computed `gradient_next`). Honest substrate behavior, not
a defect — Mentl says nothing where she can prove nothing. Query /
Verify / Why / Trace / Unlock all work fine on the OneShot graph today.
Post-B.2, the gradient-rich form arrives without changing F.1's surface.

---

## §2 The Eight Interrogations

Per CLAUDE.md / DESIGN.md §0.5 / Mentl's anchor — eight per kernel
primitive, exhaustive coverage, no skips.

| # | Primitive | Authority | What F.1 has vs needs |
|---|-----------|-----------|----------------------|
| 1 | **Graph + Env** (Query) | INSIGHTS L1858 ("Graph IS the Program"); L1469 ("Self-Containment"); L622 (Document = Effect captured by handler) | Already has: every decl handle, Reason DAG (incl. `DocstringReason` via DS), effect rows, refinements, ownership markers, handler entries, gradient_next. **Adds:** synthetic `Module` handle per file. |
| 2 | **Handlers + resume discipline** (Propose) | INSIGHTS L509 ("compiler/teacher/doc/LSP same pipeline"); L713 (`compile_documenting` form); L1346 ("Handler IS the Backend") | `doc_handler` is the form. All ops `@resume=OneShot` (no MS for F.1's machinery; `gradient_next` arrives pre-computed in Situation). F.1 reuses MV.2.e — `mentl_voice_default(situation) -> List<VoiceLine>` — same handler, different iteration scope from cursor-time. |
| 3 | **Five verbs** (Topology) | INSIGHTS L1565 ("Five Verbs Complete Basis"); L1601 ("shape on page IS the graph") | Pipeline: `source \|> lex \|> parse \|> infer ~> doc_handler ~> render_<target> ~> transport_<target>`. Per-decl projection: `decl \|> situation_for \|> mentl_voice_default <\| (render_md, render_html, render_llms, render_terminal)` for fanout when multi-target. **Constraint:** rendered handler-chain decls preserve canonical multi-line `~>`/`\|>` formatter shape (verb-shape IS doc element). |
| 4 | **Effect row algebra** (Unlock) | INSIGHTS L302 (negation); L1520 (capability stack) | doc_handler **performs** `GraphRead + EnvRead + Verify`; **declares** `!Mutate` (proves it can't edit what it documents — graph-shadow doctrine enforced by row); render handler performs `Render`; transport handler performs `Console + WASI + Network` per target. Three-tier chain; row algebra proves composition. |
| 5 | **Ownership as effect** (Trace) | INSIGHTS L347 (Allocation IS effect); L1322 ("Pure Transforms for Structure") | Graph state `ref` to doc handler. VoiceLines `own`. `DocstringReason` content `own` to graph. Render output `own` to transport. Pure transforms on structure (signature → display string), effects only for context (graph queries). |
| 6 | **Refinement types** (Verify) | INSIGHTS L327 (Annotation Gradient) | For F.1 itself: `type DocPort = Int where 1024 <= self <= 65535` for `--serve`; `type DocPath` for output; `type RenderTarget` ADT (not int-flag — drift mode 8). For docs PRODUCED: every decl's refinements ARE doc surface; Verify tentacle surfaces V_Pending counts inline with type. |
| 7 | **Annotation gradient** (Teach) | INSIGHTS L327; L1011 ("Compound Interest of Self-Reference") | F.1 gradient itself: `with Pure` on per-decl projector (memoize per `(graph_hash, decl_handle)`), `with !Alloc` on render inner loop (real-time `--serve` updates), `with !Network` on render (proves no exfil), `with !IO` on projection-not-transport (compile-time eval). For DOCS PRODUCED: Teach tentacle's per-decl render IS the gradient surface. |
| 8 | **HM inference + Reasons** (Why) | INSIGHTS L51 ("Inference IS the Light"); L1011 (Why Engine debugs itself) | Every VoiceLine cites its Reason. doc_handler records `Reason::DocProjected(decl_handle, transport)` so doc generation itself is provenance-tracked. Clicking ANY claim in `--serve` walks the Reason DAG; nothing is unsourced. |

All eight clear. Residue: synthetic Module handle, `mentl_voice_default`
return-shape refinement, `~>`-preserving render, four render handlers,
`http_serve` transport, adaptive dispatch. Each named below.

---

## §3 Substrate proposal

### §3.1 `///` as graph edge — defer to DS

DS-docstring-edge.md owns the substrate for `///` reaching the graph.
F.1 imports its design contract:

- `Documented(String, Stmt)` AST wrapper at parse time
- `DocstringReason(String, Span)` Reason edge in graph
- Inference threads docstring into env-extend's Reason chain
- Hover / Mentl / audit read via existing `GraphRead`

**F.1 does not declare a `Document` effect.** INSIGHTS L570's framing
("`///` emits a `Document` effect that the doc handler captures") is
satisfied by DS's substrate semantically — `///` does reach the doc
handler, via Reason-edge read instead of perform-and-capture. The
architectural property is preserved (docstrings are first-class graph
substrate Mentl reads); the mechanical form is lighter (one graph
write at inference, not one perform per `///`).

If a future composability case requires per-handler `///` filtering
(e.g., `compile_summary` captures only first paragraph), the upgrade
is to wrap the `DocstringReason` read in a thin `effect DocFilter`;
the substrate won't need to grow until the use case arrives.

**F.1 depends on DS.1 + DS.2 + DS.3 landing.** DS.4 (hover/Mentl
docstring display) is the cursor-time projection of the same data F.1
projects in batch — they share the substrate.

### §3.2 Synthetic `Module` handle

Per INSIGHTS L1858, every "output" is a handler reading the same graph.
For module-level `///` to reach F.1's projection, the module must be a
first-class graph entity — anything else is reading-the-shadow.

**Substrate addition** (`src/types.mn`):

```nx
type NodeBody
  = ...existing variants...
  | NModule({ path: String, decls: List<Handle>, span: Span })
```

**Wiring** (`src/pipeline.mn` or `src/driver.mn`): per-file inference
creates one `NModule` handle. The `Documented(String, Stmt)` wrapper at
the start of a file (no preceding declaration) attaches its docstring
to the Module handle's `DocstringReason`, not to the next declaration.

**Render consequence:** F.1's `render_index` op surfaces module
docstrings; per-module pages render the module-level `///` as the
opening prose for the page.

**Acceptance:** `mentl doc src/graph.mn` (no symbol arg) renders the
Module handle's docstring + decl list. Drift-clean.

### §3.3 `mentl_voice_default` — interface refinement

Current in-flight MV.2 substrate (per `src/mentl_voice.mn`) is shaped
around per-tentacle handler arms each producing one `VoiceLine`.
The cursor-time use case picks one per LSP surface (hover / inlayHint
/ diagnostic / codeAction). F.1's batch use case wants all 8 (silence-
gated per tentacle).

**Refinement** (lands as part of D.1.e):

```nx
fn mentl_voice_default(situation: Situation) -> List<VoiceLine>
                                                   with Pure =
  // Fold over the 8 tentacles. For each tentacle:
  //   - compose tentacle-specific Situation (set situation.tentacle)
  //   - check silence_predicate(situation_t)
  //   - if passes, call the tentacle's render arm and collect its VoiceLine
  //   - if fails, skip
  // Result: 0 to 8 VoiceLines, in kernel order (Query → Why).
```

Cursor-time consumers (LSP) call `mentl_voice_default(situation)` and
filter to the cursor-surface tentacle. Batch consumers (F.1) call the
same handler and render the full list. **Same machinery; different
iteration scope.** This is the unification per INSIGHTS L509.

### §3.4 The `Render` effect

Render is a per-target effect — markdown, HTML, llms.txt, terminal.
Each target is a peer handler (per INSIGHTS L1346 — "Handler IS the
Backend"); transport-mode flag would be drift mode 8 (int-coded
dispatch, see CLAUDE.md drift modes).

**Substrate** (`lib/doc/render.mn`):

```nx
type RenderedDecl
  = RenderedDecl({
      signature:    String,    // canonical signature with effect row + refinements
      docstring:    Option,    // Option<String> — author's verbatim ///
      voicelines:   List,      // List<RenderedVoiceLine> — Mentl per tentacle
      reason_links: List       // List<ReasonLink> — Why Engine entry points
    })

type RenderedTopology
  = RenderedTopology({
      chain_form:   String,    // canonical multi-line ~>/|> formatter shape
      handlers:     List       // List<HandlerEntry> with their /// + rows
    })

type RenderedIndex
  = RenderedIndex({
      modules:      List,      // List<RenderedModule>
      crucibles:    List       // List<RenderedConversation>
    })

type RenderedConversation
  = RenderedConversation({
      crucible:     String,
      claim:        Option,    // author's /// disintermediation claim
      compiles:     Bool,      // does the aspirational program compile?
      voicelines:   List       // Mentl over the crucible source
    })

effect Render {
  render_decl(decl: Handle, voicelines: List, doc: Option) -> RenderedDecl   @resume=OneShot
  render_handler_chain(chain: List) -> RenderedTopology                      @resume=OneShot
  render_index(modules: List) -> RenderedIndex                               @resume=OneShot
  render_crucible(crucible: Handle, claim: Option) -> RenderedConversation   @resume=OneShot
}
```

Four ops cover the four declaration-shape templates (regular decl,
handler chain, project index, crucible). Each render handler implements
all four; per-target form differs in output bytes, not in op set.

### §3.5 The `doc_handler`

```nx
// lib/doc/handler.mn

handler doc_handler {
  // Captures DocstringReason reads via GraphRead.
  // For each declaration in the project (or focused symbol):
  //   - compose Situation (tentacle = TentQuery as default seed)
  //   - call mentl_voice_default(situation) → List<VoiceLine>
  //   - read DocstringReason from env entry (via GraphRead)
  //   - perform render_decl(handle, voicelines, doc)
  // For each Module handle:
  //   - perform render_index(...)
  // For each crucible decl (per CRU walkthrough):
  //   - perform render_crucible(...)

  state {
    target:   RenderTarget,    // Md | Html | LlmsTxt | Terminal
    focus:    Option           // Option<Handle> — None = whole project
  }

  return(()) => {
    // doc_handler completes when the project walk finishes.
    // Render handler downstream collected results into RenderedX values.
    // Transport handler downstream emits.
    ()
  }
}
```

State is two fields (`target`, `focus`) — record per Insight #9
(Records Are The Handler-State Shape). `target` selects which render
handler runs downstream (transport-mode-via-handler-swap, not flag).

### §3.6 The four render handlers

Four peer handlers; each implements `Render`'s four ops:

- `render_md` — markdown, file-tree-mirrored output. Default for piped
  invocation. Reason links as `[label](path#anchor)`. Handler chains
  as fenced code blocks preserving `~>` indentation per INSIGHTS L1601.
- `render_html` — HTML for `--serve`. Reason links as `<a>` clickable.
  CSS canonical (Mentl-styled, single theme). No JavaScript except for
  Reason-DAG-walk navigation. Handler chains rendered with the same
  visual indentation as canonical formatter.
- `render_llms` — `llms.txt` and `llms-full.txt` per the 2026 standard.
  Markdown-formatted index for AI-tool consumers. Substrate-cited form;
  every claim carries its Reason citation inline. Transport writes both
  files to project root.
- `render_terminal` — plain text for stdout. Single decl when `mentl doc
  <symbol>` invoked. Reason links as `path:line` (editor go-to format).

**No "default render handler" picked at the Render effect declaration
level.** Selection happens at adaptive dispatch time (§3.8).

### §3.7 Transport handlers

Reuse existing transports:

- `stdout_console` — for piped invocation OR focused symbol
- `file_io` — for `--target=md` (writes file tree) and `--target=llms`
  (writes `llms.txt` + `llms-full.txt`)

**One new transport:**

- `http_serve` — for `--serve`. Listens on `DocPort`. Serves
  `RenderedX` values via `render_html`. WebSocket for live re-render
  on file change (via `~> file_watcher` peer, optional handler swap).
  Performs `Network + WASI`. Per the capability-stack doctrine
  (INSIGHTS L1520), a future audit can install `~> read_only_serve`
  outside `http_serve` to prove the docs server has zero write
  capability.

### §3.8 Adaptive shell dispatch

Per the testing-as-handler-swap doctrine (plan §99 + EH walkthrough):
`mentl run` → `compile_run`; `mentl test` → `test_run`; `mentl chaos` →
`chaos_run`. Same shape for `mentl doc`:

```nx
// src/main.mn — mentl doc dispatch
fn dispatch_doc(argv) =
  let focus  = parse_focus_arg(argv)          // Option<symbol-name-or-path>
  let target = parse_target_arg(argv)         // explicit --target=X | --serve | None

  match (target, isatty(stdout)) {
    (Some(t), _)     => run_with_target(t, focus),
    (None, true)     => run_with_target(Html, focus) ~> http_serve(default_port),
    (None, false)    => run_with_target(Md, focus)   ~> stdout_console
  }
```

The shell picks transport based on `(--target | --serve | none)` and
TTY context. Same `doc_handler` upstream; different render + transport
downstream.

**CLI surfaces** (mapped to dispatch):

| Invocation | Render | Transport | When |
|------------|--------|-----------|------|
| `mentl doc` | render_html | http_serve | TTY context |
| `mentl doc` | render_md | stdout_console | Pipe context |
| `mentl doc <symbol>` | render_terminal | stdout_console | Focused decl |
| `mentl doc src/graph.mn` | render_html OR render_md | http_serve OR stdout_console | Module focus |
| `mentl doc --target=md` | render_md | file_io to `mentl-doc/` | Explicit md tree |
| `mentl doc --target=html` | render_html | file_io to `mentl-doc/` | Explicit html tree |
| `mentl doc --target=llms` | render_llms | file_io to project root | Explicit llms |
| `mentl doc --serve [--port=N]` | render_html | http_serve | Explicit serve |
| `mentl doc --crucibles` | (target-per-context) | (transport-per-context) | Crucibles index focus |

---

## §4 The compile pipeline with doc handler installed

```
source
    |> lex
    |> parse                     // Documented(...) wrappers attached per DS
    |> infer                     // DocstringReason threaded into env per DS
    ~> doc_handler               // captures DocstringReason via GraphRead;
                                 //   walks per-decl Situation;
                                 //   calls mentl_voice_default;
                                 //   performs Render ops
    ~> render_<target>           // implements Render: produces RenderedX values
                                 //   render_md | render_html | render_llms | render_terminal
    ~> transport_<target>        // emits to where the reader is
                                 //   stdout_console | file_io | http_serve
```

Per INSIGHTS L1601 — verb-shape on the page IS the topology. Pipeline
above renders in the canonical multi-line formatter shape. F.1's
`render_handler_chain` op preserves this shape when documenting other
handler chains (the doc IS what the formatter produced).

**Capability stack** (per INSIGHTS L1520, reading bottom-to-top):
- `transport_<target>` outermost — least trusted, highest grant scope
  (Network / WASI). Has no escape; whatever it writes IS the output.
- `render_<target>` middle — grants Render; bounded by transport's
  scope.
- `doc_handler` innermost — grants Document/Render; bounded by
  render's scope.

A future audit-time install of `~> read_only_doc` outside doc_handler
proves doc generation has zero graph-write capability — by row
algebra, not by code review.

---

## §5 Per-declaration doc shape (canonical render)

For every decl the doc handler walks, render handlers emit this
content (transport-format varies; content is invariant):

```
─── canonical signature (substrate, always) ────────────────────────
fn lowpass_filter(samples: List<Sample>) -> List<Sample> with !Alloc

─── /// (author voice, verbatim, when present) ─────────────────────
Single-pole IIR low-pass with cutoff frequency parameterized by the
sample rate. Real-time-safe.

─── Mentl (substrate voice, only tentacles silence_predicate passes) ─
[Query]   Bound at lib/dsp/processors.mn:42. Row !Alloc proven
          transitively (state stack-alloc; <~ feedback no heap;
          inner ops all !Alloc).
[Verify]  Sample refined `Float where -1.0 <= self <= 1.0`. All
          callers discharge at construction. 0 V_Pending.
[Why]     Why !Alloc? Walk → state field is stack; <~ uses pre-
          allocated slot; map body's inner row is !Alloc. (3 hops.)
[Teach]   Adding `with Sample(44100)` here unlocks one-sample-delay
          specialization for `<~`.
─── Reasons (Why Engine entry points, walkable in --serve) ─────────
↗ LetBinding(lowpass_filter, L42, Inferred("from body"))
↗ RowNarrowed(!Alloc, L42, Reason::FeedbackStateStackAlloc)
↗ RefinementDischarged(Sample, L42, Reason::ConstructionSiteCheck)
↗ DocstringReason("Single-pole IIR ...", L41)
```

**Render rules — substrate, not editorial:**

1. Tentacles render in kernel order: Query → Propose → Topology →
   Unlock → Trace → Verify → Teach → Why.
2. Each tentacle renders iff its `silence_predicate` arm passes
   (per MV §2.7.5 — pure exhaustive predicates; no "non-trivial" or
   "non-obvious" gating; substrate either has the predicate-true
   condition or doesn't).
3. Author `///` always renders verbatim when present; never absorbed
   into Mentl's voice; never overridden. Two voices, no editorial third.
4. Reason links render per transport: HTML `<a href>`, markdown
   `[label](path#anchor)`, terminal `path:line`.
5. **No "documentation generator's voice."** Two speakers (author +
   substrate); no third inserted. No editorial gating. No "may want
   to" hedges. No adjective-gated rendering ("noteworthy",
   "interesting", "advanced") — those are subjective predicates and
   substrate has no opinion on subjective predicates.

**Forbidden adjective-gated language in render handler bodies** (drift
mode 32 — wildcard-on-load-bearing-ADT analog at the prose layer):

- "non-obvious" / "non-trivial" / "interesting" / "noteworthy" — all
  smuggle subjective predicates into deterministic substrate. Replace
  with the named substrate predicate that fires the tentacle.
- "complex" / "subtle" — likewise; substrate either has the structure
  or doesn't.
- "advanced" / "important" — marketing prose; never reaches Mentl.
- "may want to" / "might consider" — hedging that masks a missing
  predicate. Either the gradient unlock exists (Teach fires) or it
  doesn't.
- "deprecated" / "legacy" / "previously" / "no longer" — temporal
  ecosystem-lifecycle vocabulary; positive-form discipline (CLAUDE.md
  global). Doc shows what IS, not what was.

---

## §6 Special pages

### §6.1 Module pages

When `mentl doc src/graph.mn` (path arg) is invoked, the focus is the
Module handle for `src/graph.mn`. Render shape:

```
─── canonical module declaration (substrate) ──────────────────────
module src/graph.mn

─── /// (module-level author voice, when present) ─────────────────
Graph substrate (spec 00). O(1) chase via flat-array representation;
trail-based rollback for speculative writes.

─── Module-level Mentl (only tentacles that fire on Module topic) ─
[Query]   Module exports: Handle, NodeBody, NLetBinding, NParam,
          ... (47 declarations).
[Topology] Imports: types, runtime/lists, runtime/strings.

─── Declaration list ────────────────────────────────────────────────
type Handle             at L23   (refinement: Handle where 0 <= self < 2^31)
type NodeBody           at L42
fn graph_chase          at L98   with GraphRead, !Alloc
fn graph_bind           at L142  with GraphRead, GraphWrite
... (each links to its per-decl rendered page)
```

Module handle's `DocstringReason` IS the opening prose. Decl list is
generated from the module handle's `decls` field (substrate, not
re-parsed from source).

### §6.2 Handler pages

Handler decls render with extra substrate fields beyond regular decls:

```
─── canonical handler declaration ──────────────────────────────────
handler verify_smt {
  state { obligations: List<Predicate>, cache: Map<Hash, Result> }
  // verify(pred) arms ...
}

─── /// (author voice when present) ────────────────────────────────
SMT-backed refinement discharger. Falls through to verify_ledger
when SMT class doesn't apply (Q-B.6.3 nested chain).

─── Handler substrate ──────────────────────────────────────────────
absorbs:        Verify
performs:       SmtSolve, Cache (state)
resume:         OneShot per op
install sites:  3 (src/main.mn:42, src/driver.mn:118, lib/test.mn:67)

─── Composition (rendered with canonical multi-line ~> shape) ──────
Default install chain at src/main.mn:42:

source
    |> lex |> parse |> infer
    ~> verify_smt              ← THIS HANDLER
    ~> verify_ledger
    ~> diagnostics
─── Mentl tentacles (gated as usual) ───────────────────────────────
[Trace]   Handler position: 3rd from outer (verify_smt is least
          trusted of three). Per capability stack, can perform
          SmtSolve + Cache; cannot perform Network (not in chain).
[Verify]  State refinement: cache.size <= MAX_CACHE_ENTRIES.
          Discharged at install time via verify_ledger.
─── Reasons ────────────────────────────────────────────────────────
↗ HandlerDeclared(verify_smt, src/verify.mn:201, Reason::SmtBridge)
↗ AbsorbsRowProof(Verify, ...)
↗ InstallReason(src/main.mn:42, Reason::DefaultPipeline)
```

**Handler-chain rendering preserves canonical multi-line `~>` shape**
per INSIGHTS L1601 — verb-shape IS the doc element for composition.
Don't collapse to bullet list.

### §6.3 Crucible pages

Per INSIGHTS L1161, crucibles are NOT tests. They are conversations
with Mentl's future self. Per plan F.1, F.1 surfaces the crucible-to-
ecosystem-disintermediation map. Render shape:

```
─── crucible declaration ───────────────────────────────────────────
crucible crucible_dsp at crucibles/crucible_dsp.mn

─── /// (author's disintermediation claim, when present) ───────────
The DSP processor JUCE wishes it could be. Allocation-free in the
audio callback (proved via `with !Alloc` transitively). Sample-rate
parameterized via `Sample(rate)` effect. Three filter implementations
(IIR low-pass, FIR low-pass, biquad) compose under `<~` feedback.

JUCE has no equivalent proof — its audio callback may allocate
transitively because C++ has no transitive allocation analysis.

─── Compilation status (substrate fact) ────────────────────────────
compiles: true
runtime:  passes (when invoked via `mentl run crucibles/crucible_dsp.mn`)

─── Mentl over the crucible source (gated as usual) ────────────────
[Query]   The crucible exercises 3 effect rows: Sample(rate), !Alloc,
          and (via <~) IterativeContext.
[Verify]  All 17 refinement obligations discharged at construction
          sites. 0 V_Pending.
[Trace]   Ownership: own State consumed by inner_loop linearly per
          iteration; no escape per fork-deny (AM walkthrough §4).
[Topology] Five verbs used: |> (chain), <~ (feedback), <| (parallel
          filter compare), ~> (handler attach for Sample(rate)).

─── Reasons ────────────────────────────────────────────────────────
↗ CrucibleDeclared(crucible_dsp, crucibles/crucible_dsp.mn:1)
↗ RowProof(!Alloc, crucible_dsp, transitive)
↗ DocstringReason("The DSP processor JUCE wishes ...", L1)
```

**`mentl doc --crucibles`** renders the crucibles index — list of
`RenderedConversation` values. Index framing per INSIGHTS L1161 is
"conversations Mentl has had with its future self," NOT test-summary.
Each entry shows: name, compiles bool, author's claim's first
sentence, link to the per-crucible page.

---

## §7 Search — structural, deterministic, no embeddings

`--serve` includes structural search. Per the "Mentl is 100%
deterministic" doctrine + INSIGHTS L1858 ("Graph IS the Program") +
the substrate-IS-the-knowledge-graph thesis, Mentl does NOT use
semantic embeddings or vector search. The substrate carries enough
information that structural queries return precise answers.

**Search forms** (Hoogle-evolved per `WebSearch` survey):

- **By name:** substring match across decl names. Fast; flat scan.
- **By signature:** `(List<Sample>) -> List<Sample> with !Alloc`
  returns DSP filters with allocation-free guarantee. Type fingerprint
  + structural unification (same machinery as Hoogle's, plus effect
  rows + refinements as discriminating dimensions).
- **By row alone:** `with !Alloc + !IO` returns all candidate
  real-time-safe decls.
- **By refinement:** `Sample` returns every binding refined to that
  type. Cross-references the decl's ancestor type chain.
- **By effect:** `with Choice` returns every fn that performs Choice
  (and by transitivity, every caller of those).

**No free-text search v1. No embeddings ever.** SOTA systems' move
toward embeddings is a response to impoverished doc surfaces. Mentl's
substrate carries effect rows + refinements + Reason chains; structural
search is strictly more discriminating. AI tools downstream
(consuming `llms.txt`) do their own semantic-search-against-the-richest-
corpus thing — Mentl provides them the corpus, not the search.

---

## §8 Transports + adaptive default — handler swap, not modes

Per INSIGHTS L1346 — "Handler IS the Backend." Three render handlers +
three transport handlers are PEER handlers, not modes on a single
generator. Per drift mode 8 (CLAUDE.md): `target == 0/1/2` int-coded
dispatch is forbidden; `RenderTarget` is an ADT.

Default selection is at the dispatch boundary (`src/main.mn`) per
adaptive rules in §3.8. Same `doc_handler` upstream of every
combination; transport context picks the handler combo at runtime.

This matches the testing-as-handler-swap doctrine: `mentl run` →
`compile_run`; `mentl test` → `test_run`; `mentl doc` → adaptive
selection of (render, transport) handlers from the doc family.

---

## §9 Forbidden patterns per edit site (drift modes)

Per CLAUDE.md's nine named drift modes + generalized fluency-taint
check. Edit sites + per-site forbidden patterns:

**`lib/doc/render_*.mn`** (four render handlers):
- **Drift 1 (Rust vtable):** no `dispatch_table[target_idx](decl)`.
  Handlers are peer instances of `Render` effect; resolve via existing
  handler chain.
- **Drift 8 (int-coded dispatch):** `RenderTarget` is ADT (Md | Html |
  LlmsTxt | Terminal); never int.
- **Drift 21 (OOP):** no `renderer.render(decl)`. Effect ops only.
- **Drift 25 (OOP method):** no `decl.render(target)`. `render_decl`
  is an effect op the doc_handler performs; render handler captures.
- **Foreign-framework drift:** not Pandoc-shape templating; not Jinja;
  not Handlebars; not Mustache; not Jekyll; not Hugo. Render handlers
  produce strings via Mentl's existing string substrate (lib/runtime/strings.mn).

**`lib/doc/handler.mn`** (doc_handler):
- **Drift 9 (deferred-by-omission):** doc_handler walks ALL decl
  shapes (regular, handler, crucible, module). No "todo: handle
  crucibles later" inside a "complete" commit. If crucible support
  splits, name it as F.1.crucibles peer sub-handle.
- **Drift 7 (parallel-arrays-not-record):** doc_handler state is one
  record (`{target, focus}`), not parallel `(targets, focuses)`.
- **Editorial-gating drift:** no "is this decl interesting enough"
  branches. Tentacles fire per silence_predicate; no second-guessing.

**`lib/doc/render_handler_chain` rendering:**
- **Verb-shape preservation drift:** the canonical multi-line
  formatter shape (per INSIGHTS L1601 + spec 10) IS the rendered
  output. Do NOT collapse `~>` chains to bullet lists or comma-
  separated names. Verb-shape on the page IS the doc element.
- **Foreign drift (Sphinx :func: directives, JSDoc @-tags):** none.
  Handler chain is rendered as mentl source per the canonical
  formatter; cross-references are mentl identifiers in backticks,
  resolved by render handler.

**`lib/doc/transport_http_serve.mn`** (new transport):
- **Drift 21/24 (async/await):** no `async fn handle_request`. HTTP
  ops are `Network` effect performs; handler arms.
- **Drift 1:** no routing table as data structure; route patterns
  match in handler arms.
- **Foreign drift:** not Express middleware shape; not Rails routes;
  not Phoenix plugs. Mentl's request handling IS handler chain on
  Network effect.

**`src/main.mn` (adaptive dispatch addition):**
- **Drift 8:** `RenderTarget` ADT, not flag-as-int.
- **Drift 9:** all four targets (Md, Html, LlmsTxt, Terminal) wired
  in dispatch in one commit; no "register md, html later."

**Generalized fluency-taint check across all sites:**
- Pattern came from rustdoc / ExDoc / DocC / Sphinx / Hoogle? If yes,
  restructure until it composes from the eight primitives alone. The
  shape Mentl draws is not "rustdoc but with effect rows added on";
  it's the substrate-cited form that those systems can't produce.

---

## §10 Acceptance

**AT-F1.1** `mentl doc src/graph.mn` (TTY) starts http_serve at
`localhost:<port>`; opening the URL renders the graph module's page —
module-level `///` + decl list + per-decl rendered pages reachable.
Reason chains walkable via `<a>` links.

**AT-F1.2** `mentl doc src/graph.mn | bat` (pipe) writes markdown to
stdout; same content as AT-F1.1, transport-format markdown.

**AT-F1.3** `mentl doc lowpass_filter` (focused symbol) renders one
decl in terminal form to stdout; signature + `///` + Mentl tentacles
+ Reason links as `path:line`.

**AT-F1.4** `mentl doc --target=md` writes `mentl-doc/` mirror tree of
markdown files; per-source-file rendered to per-`*.md`.

**AT-F1.5** `mentl doc --target=llms` writes `llms.txt` (index) +
`llms-full.txt` (full corpus) to project root. Cursor / Aider /
Continue can ingest `llms-full.txt` and see substrate-cited
declarations.

**AT-F1.6** `mentl doc --crucibles` lists crucible conversations with
their disintermediation claims (author's `///` first sentence) + a
"compiles ✓" or "compiles ✗" badge per crucible.

**AT-F1.7** Hover-cursor in editor + LSP picks one VoiceLine for the
hover surface; same `mentl_voice_default(situation)` call, same
silence-gating, single VoiceLine returned via tentacle filter. F.1's
batch render shows all 8. Same machinery; different iteration scope.
**No drift between hover info and `mentl doc` content** — they cite
the same Reasons.

**AT-F1.8** A `.mn` decl with no `///` renders without an author-voice
section; Mentl tentacles still fire per silence_predicate; no
"empty docstring" placeholder.

**AT-F1.9** A `///` example block containing mentl source: the example
IS rendered (syntax-highlighted on HTML, fenced on markdown). If
the example doesn't compile, `mentl doc` ITSELF fails at the
inference site — there is no separate doc-test runner per INSIGHTS
L398. **No `--check` flag.**

**AT-F1.10** `mentl doc` re-run with no source change is bit-identical.
Pure projection of the graph; same graph → same docs. Memoization
via `with Pure` on the per-decl projector + `(graph_hash,
decl_handle)` cache key.

**AT-F1.11** Search (in `--serve`): typing `with !Alloc` in the
search box returns every decl with `!Alloc` in its row. Typing
`Sample` returns every decl referencing the Sample type. Results are
deterministic and ordered by structural relevance.

**AT-F1.12** Capability-stack-as-security: installing
`~> read_only_serve` outside `http_serve` and inside `doc_handler`
gates network writes; row algebra proves http_serve cannot perform
graph writes (even though doc_handler reads graph). Verifiable via
`mentl check`.

---

## §11 What `mentl doc` replaces (disintermediation map)

| External system | What it does | What `mentl doc` does instead |
|-----------------|--------------|------------------------------|
| rustdoc / docs.rs | Extract from `///` + signatures, emit HTML; doctests as compilable examples | doc_handler reads `DocstringReason` (DS substrate); signatures carry effect row + refinements rustdoc cannot render; `///` example code uses the same compile pipeline as production (no separate doctest runner per INSIGHTS L398) |
| ExDoc / hexdocs.pm | Auto-link across deps + dark mode UX + llms.txt + version dropdown | Capability-stack handler installs cross-package linker (`~> remote_doc_resolver`); `--target=llms` is peer transport from day one; UX is render_html concern; versioning is git-tag context, not in-doc dropdown |
| Swift DocC | Interactive tutorials with step-by-step diff | `lib/tutorial/` files are this; doc_handler over those files renders the tutorial form; no separate authoring tool |
| Hoogle | Type-directed search by signature | Structural search by signature **plus effect row plus refinement** — strictly more discriminating |
| Lean Finder / LeanExplore | Hybrid semantic + lexical + PageRank search | Substrate IS the knowledge graph; embeddings unneeded; structural search precise |
| Unison `Doc` literals | Doc as first-class value | `///` reaches graph as `DocstringReason` per DS; values flow through the same handler chain as everything else |
| `llms.txt` (general) | Markdown index for AI consumers (844K sites adopted) | `--target=llms` projects substrate-cited form; AI tools get higher-quality corpus than any extracted-comment form because every claim cites a Reason chain |

**The disintermediation claim** (per plan §1693, §1697): post-first-light
+ Mentl-at-cursor + F.1, the markdown corpus retires (`docs/DESIGN.md`
+ `docs/SUBSTRATE.md` + walkthroughs become historical archive).
Runtime orientation comes from Mentl's voice + `mentl doc` projection +
`///` on declarations. **The claim is mechanical, not aspirational** —
every other system requires the doc generator to drift from the
compiler; `mentl doc` is the compiler reading itself out loud.

---

## §12 Open questions answered

Per plan-style open-question resolution. Each answer cites authority.

**Q-F1.1.** What counts as a "declaration" for doc surface purposes?

> Top-level `type`, `fn`, `effect`, `handler`, top-level `let`, plus
> the synthetic `Module` handle. Module-private helpers per NS-structure
> appear (no `pub`/`priv` visibility — what's exported is what's in
> the doc; this matches NS-structure doctrine). Nested `let` inside fn
> bodies do NOT get doc entries (internal). Generated handles do NOT
> appear (substrate-internal).

**Q-F1.2.** Module-level `///` — synthetic Module handle?

> **Yes.** Per INSIGHTS L1858 — re-parsing source to find module docs
> would be reading-the-shadow. Substrate per §3.2.

**Q-F1.3.** Handler catalog page — peer template?

> **Yes.** Per INSIGHTS L1601 — preserve canonical `~>` verb-shape on
> chain rendering. Substrate per §3.4 (`render_handler_chain` op).

**Q-F1.4.** Crucible disintermediation as per-crucible decl extension?

> **Yes** plus `mentl doc --crucibles` index. Framing per INSIGHTS L1161
> is "conversations Mentl has had with its future self," NOT
> test-pass/fail summary. Substrate per §6.3.

**Q-F1.5.** Doc tests via `mentl test`; `mentl doc --check` runs both?

> **No.** Per INSIGHTS L398 — Mentl has no doc-tests as a separate
> category. `///` example code uses the same compile pipeline as
> production. Compilation IS the verification. **No `--check` flag.**
> If a `///` example fails to compile, `mentl doc` itself fails at the
> inference site.

**Q-F1.6.** Existing `docs/` markdown corpus retires?

> **Yes** post-first-light. F.1 doesn't try to derive DESIGN/INSIGHTS
> from substrate — those are authoring-period crystallizations, not
> substrate residue. The retirement claim is "developers no longer
> need to read DESIGN.md to use Mentl because `mentl doc` covers
> everything they need at-cursor and at-batch."

**Q-F1.7.** F.1 reuses MV.2.e directly, gates on D.1.e first?

> **Yes.** `mentl_voice_default(situation) -> List<VoiceLine>`
> (silence-gated per tentacle); LSP picks one for cursor surface;
> F.1 renders all. Tier-1 unification per INSIGHTS L509. Substrate
> per §3.3.

**Q-F1.8.** `///` performs `effect Document` vs reaches graph as
Reason edge?

> **Reason edge per DS.** INSIGHTS L570's "`///` emits a Document
> effect" framing is satisfied semantically by DS's lighter substrate
> (Reason edges, not effect performs). doc_handler reads via existing
> `GraphRead`. No new `effect Document` declaration. Substrate per §3.1.

**Q-F1.9.** Cross-package doc linking?

> Capability-stack handler. Install `~> remote_doc_resolver` in the
> doc handler chain when cross-package links wanted. Absent: docs are
> local-only. Per INSIGHTS L1520 capability-stack doctrine. Substrate
> for `remote_doc_resolver` lives in packaging-design walkthrough
> (out of F.1 scope; ecosystem item per `ROADMAP.md`).

**Q-F1.10.** Tentacle render order when multiple fire?

> Kernel order: Query → Propose → Topology → Unlock → Trace → Verify
> → Teach → Why. Per CLAUDE.md / DESIGN.md §0.5 ordering.

**Q-F1.11.** Versioning (multi-version dropdown)?

> None v1. Post-first-light: version is git-tag; transport handler
> picks. Per the substrate-first posture — no UX feature without a
> substrate question.

**Q-F1.12.** Source view (does the doc render decl body too)?

> Off by default; `--source` flag opt-in. Don't bury the doc surface.

**Q-F1.13.** Theming?

> Mentl-canonical only v1. Theme = handler swap on render but not
> a v1 surface. Single CSS for `render_html`.

**Q-F1.14.** `@deprecated` / `@since` markers?

> None. Per CLAUDE.md global "positive-form discipline." Doc shows
> what IS, not what was. Lifecycle vocabulary (deprecated, legacy,
> previously, no longer) is forbidden in `///` and in render handler
> bodies (drift mode flagged in §9 above).

**Q-F1.15.** Diagnostics integration?

> Yes via Verify tentacle (V_Pending counts inline) and Trace tentacle
> (T_Pending). Substrate already in MV.2 silence_predicate.

**Q-F1.16.** Top-level index page?

> Auto-generated structural index — module list → per-module decl list.
> No curation. Per the editorial-gating-is-drift doctrine.

**Q-F1.17.** Search — structural only?

> Yes. Per §7. No free-text v1; no embeddings ever.

---

## §13 Implementation notes

For the future implementer (Sonnet via mentl-implementer; Opus authors
this plan; PostToolUse drift-audit verifies):

**File creation order** (after gates §1 are satisfied):

1. `src/types.mn` — add `NModule({path, decls, span})` to `NodeBody`.
   One variant; ~3 lines; drift-clean.
2. `src/pipeline.mn` (or `src/driver.mn`) — wire `NModule` handle
   creation per file in inference; route module-level `Documented(...)`
   wrapper to attach `DocstringReason` to Module handle.
3. `src/mentl_voice.mn` — `mentl_voice_default` interface refinement
   to return `List<VoiceLine>` (D.1.e dependency; lands as part of
   D.1.e itself). Fold over 8 tentacles + silence-gating.
4. `lib/doc/render.mn` — declare `Render` effect + `RenderedX` records.
5. `lib/doc/handler.mn` — `doc_handler` body. Walks Situation per decl;
   calls `mentl_voice_default`; performs `Render` ops.
6. `lib/doc/render_md.mn` — markdown render handler.
7. `lib/doc/render_html.mn` — HTML render handler.
8. `lib/doc/render_llms.mn` — llms.txt + llms-full.txt render handler.
9. `lib/doc/render_terminal.mn` — terminal stdout render handler.
10. `lib/doc/transport_http_serve.mn` — http_serve transport for
    `--serve`. Performs `Network + WASI`.
11. `src/main.mn` — adaptive dispatch addition per §3.8.

Each file lands as its own commit with walkthrough citation in body.
Drift-audit (`bash tools/drift-audit.sh <file>`) must exit 0 before
commit.

**Estimated load:**
- Substrate types + module handle: ~30 lines
- mentl_voice_default refinement: ~40 lines (additive over MV.2.e in-flight)
- Render effect + records: ~80 lines
- doc_handler: ~150 lines
- Four render handlers: ~200-300 lines each (markdown lightest, html
  with CSS heaviest)
- http_serve transport: ~150 lines
- Adaptive dispatch: ~30 lines

Total: ~1500-2000 lines across 11 commits. Comparable to MV.2 voice
substrate scope.

**Substrate-first posture reminder:** every render handler arm cites
its source authority — INSIGHTS line / DESIGN section / spec section.
Render output IS substrate residue; no editorial intermediary between
graph and reader.

**Pre-B.2 testing of F.1:** Teach tentacle silent for most decls
(no MS-computed gradient_next). All other tentacles fire per their
silence predicates. AT-F1.1 through AT-F1.12 pass on pre-B.2 graph
state with reduced Teach paragraphs; post-B.2 the gradient-rich form
arrives without changing F.1's surface.

---

## §14 What F.1 refuses

- **A separate doc generator subsystem.** F.1 IS a handler on the
  compile pipeline; not a parallel parse-and-extract path. Per INSIGHTS
  L1858 reading-the-shadow doctrine.
- **Mode flags.** Render targets are peer handlers (Md | Html | LlmsTxt
  | Terminal as ADT); not `target == 0/1/2` int dispatch (drift mode 8).
- **Doctests.** Per INSIGHTS L398. `///` example code IS just mentl
  source; the compile pipeline verifies it. No separate runner.
- **Editorial gating.** No "non-trivial" / "non-obvious" / "interesting"
  predicates between substrate and render. silence_predicate (pure,
  exhaustive, deterministic) is the only gate.
- **Embeddings / semantic search / LLM augmentation.** Per
  Mentl-is-100%-deterministic doctrine. Substrate carries effect rows
  + refinements + Reason chains; structural search is strictly more
  discriminating than embeddings.
- **JSDoc/JavaDoc-style tags inside `///`.** No `@param`, `@returns`,
  `@throws`. Mentl's effect row + refinement substrate already carries
  that information; tags would duplicate.
- **Markdown-as-substrate-of-`///`.** The `///` content is raw String
  per DS §8. Render handlers interpret per target (HTML may render
  backticks as `<code>`, terminal renders as ANSI italic, etc.).
  Substrate stores; handler interprets. One mechanism.
- **Versioning UX in v1.** Out of F.1 scope. Post-first-light only.
- **`--check` flag for doc-tests.** Compilation IS the test (INSIGHTS
  L398).

---

## §15 Connection to the kernel

Per CLAUDE.md / DESIGN.md §0.5 — F.1 composes from the eight primitives:

- **Primitive #1 (Graph + Env)** — F.1 reads the graph; nothing else.
  Every claim a render handler emits cites a graph fact.
- **Primitive #2 (Handlers + resume discipline)** — F.1 IS a handler
  swap on the compile pipeline. doc_handler + render handler +
  transport handler form a three-tier capability stack. All `@resume=
  OneShot` (no MS for projection itself).
- **Primitive #3 (Five verbs)** — pipeline composes via `|>` and `~>`;
  per-target fanout via `<|`. No `<~` or `><` needed.
- **Primitive #4 (Effect row algebra)** — three-tier handler chain has
  three declared rows; row subsumption proves chain composes; `!Mutate`
  on doc_handler proves graph-shadow doctrine enforced by row.
- **Primitive #5 (Ownership as effect)** — graph state `ref`;
  VoiceLines and rendered output `own`. Pure transforms on structure;
  effects on context.
- **Primitive #6 (Refinement types)** — F.1's own substrate uses
  refinements (DocPort, DocPath, RenderTarget); for docs PRODUCED,
  every decl's refinements ARE doc surface.
- **Primitive #7 (Annotation gradient)** — F.1's per-decl projector
  invites `with Pure` (memoize) + `with !Alloc` (real-time) + `with
  !Network` (no-exfil-proof). For docs PRODUCED: Teach tentacle's
  per-decl render IS the gradient surface — what makes Mentl docs
  unique.
- **Primitive #8 (HM inference + Reasons)** — every VoiceLine cites
  its Reason; doc generation itself records `DocProjected` Reason;
  every claim walkable. The Why Engine IS doc UI.

**Mentl tentacle mapping.** F.1 IS Mentl batch — eight tentacles
projected per declaration. Same `mentl_voice_default` machinery used
at cursor time. The unification per INSIGHTS L509 is structural; F.1
makes it manifest at scale.

---

*Mentl solves Mentl. The pipe doesn't just flow data — it flows
understanding. F.1 is the terminal handler where that flow becomes
the reader's substrate.*
