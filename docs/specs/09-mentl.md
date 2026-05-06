# 09 — Mentl: the teaching substrate as handler consolidation

**Purpose.** Name the subsystem that is the compiler's human-facing
surface. Mentl is the collective noun for the set of handlers on the
shared inference substrate — gradient, Why Engine, error catalog,
suggest, LSP hover, verification-obligation surface. Each is one of
Mentl's tentacles; the shared substrate is the Graph + Env
(specs 00, 04) read through effects.

**Kernel primitives implemented:** #7 (continuous annotation gradient
— Mentl's `teach_gradient` picks ONE highest-leverage next step per
turn) and consumer of ALL EIGHT. Specifically: primitive #2's
MultiShot-typed resume is **how** Mentl explores alternate realities
at substrate speed; primitive #8 (Reasons) is **what** She walks to
compress proofs into voice; the gradient (#7) is **the discipline
that governs what surfaces**. Mentl is not a primitive — She is
the primitive composition that makes the compiler a tutor instead
of an adversary. **Her eight tentacles (DESIGN.md Ch 8) are the
eight primitives made voice**, 1-to-1 — Query / Propose / Topology /
Unlock / Trace / Verify / Teach / Why. See also
`docs/specs/simulations/MV-mentl-voice.md` for the voice
substrate design session.

**Scope.** This spec defines the module `std/compiler/mentl.mn` — the
full teaching surface: gradient logic, Why Engine, suggest, error
catalog, LSP hover, verification-obligation rendering — plus the
`Teach` effect (spec 06) it exposes. One module, five ops, eight
tentacles.

**Research anchors.**
- Elm / Roc / Dafny error catalogs — stable codes, canonical
  explanations, applicability-tagged fixes.
- ChatLSP OOPSLA 2024 — typed context for LLM completion. Mentl's
  teaching surface IS ChatLSP's context substrate.
- Hazel POPL 2024 — marked holes. Mentl's teach_gradient tentacle
  nudges toward hole-fill candidates.
- Rust `rustc-dev-guide` — applicability tags, structured patches.
- DESIGN.md (manifesto) — the teaching-compiler-as-collaborator
  thesis and error-messages-as-mentorship discipline that this
  spec mechanizes.

---

## The architecture

```
                       ╔══════════════════════════════╗
                       ║   Graph + Env + Ty      ║
                       ║   (shared inference substrate)║
                       ╚══════════════════════════════╝
                                      │
       ┌──────────┬──────────┬────────┼────────┬──────────┬──────────┐
       │          │          │        │        │          │          │
    compile    check     query     why      teach      hover      suggest
    tentacle  tentacle  tentacle tentacle  tentacle  tentacle    tentacle
       │          │          │        │        │          │          │
   emit WAT   Diagnostic QueryResult  Reason  Annotation  LSP       Candidate
                                              Capability   JSON-RPC  +Verified
```

Each tentacle is one handler on the shared substrate. Tentacles don't
coordinate — they each read independently and reason locally. This
mirrors octopus neurology: eight arms, each with its own ganglion,
coordinated by a shared central nervous system. Distributed sense-
making with zero contention.

---

## The tentacle inventory

| Tentacle | Handler | Reads | Phase landed |
|---|---|---|---|
| **Compile** | `emit_wasm` | `GraphRead + LookupTy` | Phase 1 |
| **Check** | `check_pipeline` | `Diagnostic` | Phase 1 |
| **Query** | `query_default` | `GraphRead + EnvRead + FreshHandle` | **Phase 1** |
| **Why** | `why_default` | `GraphRead + EnvRead` | F.6 (formalize) |
| **Teach** | `mentl_default` | `GraphRead + EnvRead + Teach` | F.6 |
| **Hover** | `lsp_hover` | `Query + Why` | F.2 |
| **Verify** | `verify_ledger` → `verify_smt` | `GraphRead + Verify` | Phase 1, F.1 |
| **Suggest** | `synth_default` | `Synth + Verify` | F.1 / F.2 |

Eight. If a ninth emerges (doc extraction, visualization), it fits
the same pattern — a handler on the same substrate.

---

## Teach effect expansions (from spec 06)

Each op is a tentacle entry point:

```lux
effect Teach {
  teach_here(String, Span, Ty) -> ()              @resume=OneShot
  teach_gradient(Int) -> Option(Annotation)        @resume=OneShot
  teach_why(Int) -> Reason                         @resume=OneShot
  teach_error(String, Span, Reason) -> Explanation @resume=OneShot
  teach_unlock(Annotation) -> Capability           @resume=OneShot
}
```

### Supporting ADTs

```lux
// Each variant carries an Option(Span) — Some when the candidate
// originated from a user site (hovered hole, quick-fix request);
// None for fully-internal speculation. narrow_row threads this into
// the Located reason wrapper so the Why chain reads at the user's
// coordinates, not 0:0-0:0.
type Annotation
  = APure(Option(Span))                        // `with Pure`
  | ANotAlloc(Option(Span))                    // `with !Alloc`
  | ANotIO(Option(Span))                       // `with !IO`
  | ANotNetwork(Option(Span))                  // `with !Network`
  | ARefined(String, Predicate, Option(Span))  // `type X = T where P`
  | AOwn(String, Option(Span))                 // `own` marker on a parameter
  | ARef(String, Option(Span))                 // `ref` marker on a parameter

type Capability
  = CMemoize                     // Pure enables memoization
  | CParallelize                 // Pure enables parallelization
  | CCompileTimeEval             // Pure + !IO enables CTE
  | CRealTime                    // !Alloc proves real-time safety
  | CSandbox                     // !Network proves sandbox
  | CEliminateBoundsCheck        // Refinement eliminates runtime check
  | CZeroCopy                    // ref enables zero-copy
  | CDeterministicDrop           // own enables deterministic drop

type Explanation
  = Explanation(
      code: String,              // E_MissingVariable, V_Pending, W_Suggestion, ...
      canonical_md: String,      // path into docs/errors/<code>.md
      summary: String,           // one-line human-readable
      fix: Option(Patch),        // MachineApplicable → concrete patch
      reason_chain: Reason       // the Why chain that led here
    )

type Patch
  = Patch(Span, String)          // replace span with String
```

### Op semantics

- **`teach_here(name, span, ty)`** — register that binding `name` at
  `span` has type `ty`. Accumulator for LSP hover and --teach mode.

- **`teach_gradient(handle)`** — "what annotation would unlock a
  capability on this handle?" Examines the current type + effect row,
  returns the highest-leverage next annotation or `None`. Examples:
  Pure-capable function without `with Pure` → `Some(APure(None))`; mutable
  parameter used once → `Some(AOwn(name, None))`; function call graph with
  no Alloc → `Some(ANotAlloc(None))`. `None` for the span because
  these are oracle-internal candidates; user-site candidates carry
  `Some(site_span)`.

- **`teach_why(handle)`** — returns the Reason chain for the binding
  at `handle`. Wraps `graph_chase` + recursive traversal. The Why
  Engine made effectful.

- **`teach_why_string(handle)`** (plain fn, not a Teach op) — ties
  `teach_why` to `render_why`, producing a multi-line indented chase
  trail: one line per structural frame, Located frames render their
  `file:line:col-line:col` coordinates, leaves terminate via
  `show_reason`. This is what IDE hovers and `mentl explain` show to
  the user — the substrate's coordinate-aware reasoning made
  speakable (I18).

- **`teach_error(code, span, reason)`** — given a reserved code,
  returns the canonical explanation pulled from `docs/errors/<code>.md`
  with applicability-tagged patches. Replaces ad-hoc string error
  messages with structured mentorship.

- **`teach_unlock(annotation)`** — "if I add this annotation, what do
  I get?" Used by --teach mode to show the developer why an
  annotation matters before they commit.

---

## The error catalog

Canonical explanations live at `docs/errors/<CODE>.md`. Mentl's
`teach_error` op reads them. Structure per file:

```markdown
# E_MissingVariable

**Kind:** Error
**Emitted by:** inference
**Applicability:** MaybeIncorrect

## Summary
One-line human-readable.

## Why it matters
What this tells you about the program.

## Canonical fix
The idiomatic correction.

## Example
Minimal code triggering it + the fix.
```

Mentl's tentacle hits `docs/errors/<code>.md` by convention; absence
of a catalog file is itself a lint (`W_CatalogMissing`, reserved for
future use). Every reserved code in spec 06 has a corresponding file
shipped with Phase 1 as companion artifact — this is the error
catalog's first complete pass.

---

## Integration with other tentacles

### Mentl × Verify (spec 06)

When `verify_ledger` accumulates an obligation, Mentl's error tentacle
can render it as:

```
V_Pending at line 42:
  predicate: 1 <= self && self <= 65535
  bound on: port argument to bind_tcp(port: Port)
  suggestion: refine the call site, or add `assert port > 0` to discharge
  status: pending (no solver installed yet — Arc F.1)
```

When `verify_smt` (Arc F.1) rejects an obligation, Mentl surfaces
`E_RefinementRejected` with:
- The residual unsat core (from Z3/cvc5).
- The call chain that introduced the value.
- The canonical suggestion (narrow the caller, or add an assert).

### Mentl × Synth (F.1)

AI / synth proposals flow through `synth(hole_id, expected_ty,
context)`. Each candidate is:

1. Type-checked against `expected_ty`.
2. Verified (any refinement obligations it introduces are checked).
3. Wrapped in Mentl's `Explanation` structure — "here's the candidate,
   here's the Reason chain proving it fits, here's the capability it
   unlocks."

The developer sees the candidate + mentorship, not a raw code
suggestion. No AI-branded magic. The compiler verified it; Mentl
explains it.

### Mentl × LSP (F.2)

LSP requests map one-to-one onto Mentl tentacles over JSON-RPC:

- `textDocument/hover` → `Query(QTypeAt(span))` + `teach_why(handle)`
- `textDocument/publishDiagnostics` → `Diagnostic` effect with
  `teach_error` on each code.
- `textDocument/completion` → `Synth(hole_id, …)` wrapped in Mentl
  `Explanation`.
- `textDocument/codeAction` → `Explanation.fix` if
  `applicability=MachineApplicable`.

LSP is not new machinery — it is JSON-RPC transport for tentacles
that already exist.

---

## Module structure

```
std/compiler/mentl.mn          — the consolidated teaching module
  ├── handler mentl_default      — default Teach handler
  ├── handler why_default        — default Why tentacle
  ├── fn gradient_next(handle)   — gradient logic
  ├── fn load_catalog(code)      — reads docs/errors/<code>.md
  ├── fn render_explanation      — Explanation → String
  └── fn render_patch            — Patch → developer-facing diff
```

The single module `mentl.mn` hosts the full teaching substrate —
gradient logic, Why Engine, suggest surface, error-catalog loading.
One discoverable name for the subsystem. The mascot earns its keep
linguistically.

---

## Cursor — Mentl's projection at a position

**Status: LIVE per Hμ.cursor handle (2026-05-02).** See
`docs/specs/simulations/Hμ-cursor.md` for the walkthrough,
SUBSTRATE.md §VI "Cursor: The Gradient's Global Argmax" for the
authority, and `protocol_cursor_is_argmax.md` for the discipline.

**Cursor is Mentl's projection of the live graph for a human at a
position.** The "eight tentacles" of this spec are eight *aspects of
one read* at the cursor's position, not eight subsystems that
coordinate. The graph already carries all eight at every node
(kernel closure, SUBSTRATE.md §I); `cursor_default` (`src/cursor.mn`)
composes the eight reads into one `CursorView` record:

| Field | Tentacle | Read from |
|---|---|---|
| `query` | Query (#1) | `perform graph_chase(handle)` → `NodeKind` |
| `propose` | Propose (#2) | `perform synth_propose(...)` |
| `topology` | Topology (#3) | local helper `pipe_context_of_node` |
| `row` | Unlock (#4) | local helper `row_of_node` (via TFun row field) |
| `trace` | Trace (#5) | local helper `ownership_of_node` (TParam.resolved) |
| `verify` | Verify (#6) | `perform verify_debt()` filtered by handle |
| `teach` | Teach (#7) | `perform teach_gradient(handle)` (mentl_default arm) |
| `why` | Why (#8) | `perform teach_why(handle)` (mentl_default arm) |

**`cursor_default` and `mentl_default` are the same projection at
different abstraction levels.** `mentl_default` surfaces individual
Teach ops (one tentacle at a time); `cursor_default` composes them
at a position into one record. The IDE's developer experience IS
`cursor_default` surfaced through a transport handler
(Hμ.cursor.transport, peer handle).

**Cursor effect (`src/cursor.mn`):**

```
effect Cursor {
  cursor_at(Span) -> CursorView                @resume=OneShot
  cursor_argmax(Caret) -> Cursor               @resume=OneShot
  cursor_pinned(Handle) -> Cursor              @resume=OneShot
}
```

`cursor_default with !Mutate` proves at compile time that the
projection cannot corrupt oracle state — exactly the constraint
`protocol_oracle_is_ic.md` locks for "surfaces query, never write."

**Caret + Cursor must NOT be parallel state.** `Caret(Handle, Reason)`
is the user's text-attention position (one input). `Cursor(Handle,
Reason, Float)` is the gradient argmax (the result). Cursor consumes
Caret as a function parameter; one unified pipeline; no parallel
"caret_state" + "argmax_state" — drift mode 5 closure.

**`??` is the developer's override of Cursor's auto-argmax.** When
the developer types `??`, `cursor_pinned(handle)` returns a Cursor
with sentinel-large impact; `argmax_or_default` always picks the
pin. Read-mode (cursor at finished code) and write-mode (cursor at
`??`) are the same machinery with different weight on the cursor's
chosen slot.

---


## Consumed by

- `std/compiler/pipeline.mn` — installs `mentl_default` at compile
  entry (always active; zero-cost when no teach request is made).
- `src/cursor.mn` — Hμ.cursor's `cursor_default` composes Teach +
  Synth + Verify + GraphRead reads through `mentl_default`'s
  individual ops; the cursor handler is the position-scoped read
  surface.
- Arc F.1 `verify_smt` — emits through Mentl for catalog-backed
  diagnostics.
- Arc F.2 LSP — wraps Mentl tentacles as JSON-RPC methods (and
  Hμ.cursor.transport routes `cursor_default` through LSP for the
  IDE's per-cursor projection).
- `mentl query` — every query output routes through Mentl for
  consistent rendering.

---

## Rejected alternatives

- **Keep gradient / suggest / why as separate modules.** They serve
  one user-facing mode (teaching); separating them is an
  implementation artifact, not a design. Merge.
- **Teach as a single `teach_here` op with string payloads.** Weak
  typing of the teaching surface forfeits the guarantee that every
  explanation has a canonical fix + capability. The five-op surface
  makes mentorship first-class.
- **Embed catalog explanations as string literals in the compiler.**
  Coupling the catalog to the binary makes contribution harder.
  `docs/errors/*.md` is versioned, reviewable, translatable.
- **Let LSP invent its own hover/completion surface.** Duplicates
  Mentl. Keep LSP as a JSON-RPC wrapper only.
- **Ship Mentl in Phase 1.** Tempting, but the consolidation requires
  all eight tentacles to exist first (Verify ships C, Synth ships F.1,
  LSP ships F.2). F.6 is when the substrate is complete enough for a
  named consolidation to be meaningful.
