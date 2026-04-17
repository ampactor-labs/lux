# 09 — Mentl: the teaching substrate as handler consolidation

**Purpose.** Name the subsystem that is the compiler's human-facing
surface. Mentl is the collective noun for the set of handlers on the
shared inference substrate — gradient, Why Engine, error catalog,
suggest, LSP hover, verification-obligation surface. Each is one of
Mentl's tentacles; the shared substrate is the SubstGraph + Env
(specs 00, 04) read through effects.

**Scope.** This spec consolidates three currently-separate modules —
`gradient.jxj`, `suggest.jxj`, `why.jxj` — and the Teach effect (spec
06) into one coherent subsystem: `std/compiler/mentl.jxj`. Ships in
Arc F.6 as the capstone on the rebuild's teaching surface. Structural
prerequisites (Teach effect signatures, error-catalog wiring) land in
Phase 1.

**Research anchors.**
- Elm / Roc / Dafny error catalogs — stable codes, canonical
  explanations, applicability-tagged fixes.
- ChatLSP OOPSLA 2024 — typed context for LLM completion. Mentl's
  teaching surface IS ChatLSP's context substrate.
- Hazel POPL 2024 — marked holes. Mentl's teach_gradient tentacle
  nudges toward hole-fill candidates.
- Rust `rustc-dev-guide` — applicability tags, structured patches.
- INSIGHTS.md *The Teaching Compiler as Collaborator*, *Error
  Messages as Mentorship* — the thesis this spec mechanizes.

---

## The architecture

```
                       ╔══════════════════════════════╗
                       ║   SubstGraph + Env + Ty      ║
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
| **Compile** | `emit_wasm` | `SubstGraphRead + LookupTy` | Phase 1 |
| **Check** | `check_pipeline` | `Diagnostic` | Phase 1 |
| **Query** | `query_default` | `SubstGraphRead + EnvRead + FreshHandle` | **Phase 1** |
| **Why** | `why_default` | `SubstGraphRead + EnvRead` | F.6 (formalize) |
| **Teach** | `mentl_default` | `SubstGraphRead + EnvRead + Teach` | F.6 |
| **Hover** | `lsp_hover` | `Query + Why` | F.2 |
| **Verify** | `verify_ledger` → `verify_smt` | `SubstGraphRead + Verify` | Phase 1, F.1 |
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
type Annotation
  = APure                        // `with Pure`
  | ANotAlloc                    // `with !Alloc`
  | ANotIO                       // `with !IO`
  | ANotNetwork                  // `with !Network`
  | ARefined(String, Predicate)  // `type X = T where P`
  | AOwn(String)                 // `own` marker on a parameter
  | ARef(String)                 // `ref` marker on a parameter

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
      code: String,              // E001, V001, W017, ...
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
  Pure-capable function without `with Pure` → `Some(APure)`; mutable
  parameter used once → `Some(AOwn(name))`; function call graph with
  no Alloc → `Some(ANotAlloc)`.

- **`teach_why(handle)`** — returns the Reason chain for the binding
  at `handle`. Wraps `graph_chase` + recursive traversal. The Why
  Engine made effectful.

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
# E001 — MissingVariable

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
V001 VerificationPending at line 42:
  predicate: 1 <= self && self <= 65535
  bound on: port argument to bind_tcp(port: Port)
  suggestion: refine the call site, or add `assert port > 0` to discharge
  status: pending (no solver installed yet — Arc F.1)
```

When `verify_smt` (Arc F.1) rejects an obligation, Mentl surfaces
`E200 RefinementRejected` with:
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
std/compiler/mentl.jxj          — the consolidated teaching module
  ├── handler mentl_default      — default Teach handler
  ├── handler why_default        — default Why tentacle
  ├── fn gradient_next(handle)   — gradient logic
  ├── fn load_catalog(code)      — reads docs/errors/<code>.md
  ├── fn render_explanation      — Explanation → String
  └── fn render_patch            — Patch → developer-facing diff
```

Replaces the currently separate `gradient.jxj`, `suggest.jxj`,
`why.jxj` by merging them (or, if sizes dictate, coordinating them
under one entry). The name `mentl.jxj` makes the subsystem
discoverable in the code tree. The mascot earns its keep linguistically.

---

## What this consolidates

| Existing | Folded into |
|---|---|
| `std/compiler/gradient.jxj` | `mentl.jxj` → `gradient_next` |
| `std/compiler/suggest.jxj` | `mentl.jxj` → suggest handler |
| `std/compiler/why.jxj` | `mentl.jxj` → `why_default` |
| ad-hoc error strings | `docs/errors/*.md` + `load_catalog` |
| `teach_here` (sole op) | `Teach` effect's five-op surface |

---

## Consumed by

- `std/compiler/pipeline.jxj` — installs `mentl_default` at compile
  entry (always active; zero-cost when no teach request is made).
- Arc F.1 `verify_smt` — emits through Mentl for catalog-backed
  diagnostics.
- Arc F.2 LSP — wraps Mentl tentacles as JSON-RPC methods.
- `inka query` — every query output routes through Mentl for
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
