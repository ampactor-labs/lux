# FU — Feature usage · the compiler as exemplar

*The audit that makes hand-WAT Tier 2's scope honest. Descriptive: what
features does the compiler source currently use? Normative: what SHOULD
it use to exemplify Mentl? Action: FV.1–FV.9 close the gap before
first-light so the post-first-light compiler IS the medium, not a
weak demonstration of it.*

*Status: walkthrough for the feature-usage sweep, expanded prescriptively
per Mentl-solves-Mentl discipline — a descriptive audit alone would ship
a compiler that claims 8 primitives but exercises 3.*

---

## 0. Framing — the compiler IS the first Mentl program

Per Mentl's self-similarity discipline (DESIGN.md): *"Mentl's hardest
implementation problems dissolve when viewed through its own
abstractions."* Per the Masterpiece Test: *"Is this what the ultimate
intent → machine instruction medium would do?"*

The compiler is not just "a program written in Mentl" — it is the
**first Mentl program every user sees**. If the compiler doesn't use
`!Alloc`, users won't trust `!Alloc`. If the compiler doesn't use
refinement types, users won't believe they're practical. If the
compiler uses only 2 of the 5 verbs, users will infer the other 3
are decorative.

**The compiler must exemplify Mentl.** This audit checks whether it
does. Where it doesn't, the gap is named and closed before first-
light.

---

## 1. Descriptive audit — what the compiler uses TODAY

Scan of `std/compiler/*.mn` + `std/compiler/backends/*.mn` + `std/prelude.mn`
(2026-04-21). ~630 `fn` declarations across 17 modules.

### 1.1 Primitive-by-primitive inventory

| # | Primitive | Status | Evidence |
|---|-----------|--------|----------|
| 1 | Graph + Env | ✓ used | graph.mn, infer.mn, driver.mn |
| 2 | Handlers with resume discipline | ✓ used (OneShot only) | ~20 top-level handlers in clock.mn / graph.mn / infer.mn etc. |
| 2a | MultiShot resume | 1 decl (mentl.mn:94 `enumerate_inhabitants`) | Mentl's op; never actually invoked from compiler source |
| 2b | Parameterized effects | **0 uses** | no `effect Name(arg) { ... }` in compiler |
| 3a | `\|>` sequential | ✓ used | main.mn / pipeline.mn pipelines |
| 3b | `<\|` divergent | **0 body uses** | only in comments, ADT decls (PipeKind variants) |
| 3c | `><` parallel | **0 body uses** | only in comments, ADT decls |
| 3d | `~>` handler-attach | ✓ used | main.mn:42-46, pipeline.mn:64-82 (9 handler-chain sites) |
| 3e | `<~` feedback | **0 body uses** | only in comments, ADT decls |
| 4a | Effect row `+` | ✓ used | 27 fn signatures with `with X + Y` |
| 4b | `!E` negation | **0 uses** | 3 hits are string-literals in mentl.mn rendering |
| 4c | `Pure` declared | **0 uses** | 5 hits are comments or string-literals |
| 4d | `&`, `-` | **0 uses** | not surfaced |
| 5a | `own` / `ref` markers | **0 uses** | 2 hits are English "own core" / "own line" in comments |
| 5b | `Consume` effect | **0 uses** | |
| 5c | `!Mutate` / region-freeze | **0 uses** | |
| 6 | Refinement types (`where`) | **0 uses** | all `where` hits are English in comments |
| 7 | Continuous gradient | implicit | only 27/630 fns (~4%) declare effect rows — near-bottom of gradient |
| 8 | HM + Reasons | ✓ used | inference IS what the compiler does |

### 1.2 Other Mentl features

| Feature | Status |
|---------|--------|
| String interpolation `${...}` | **0 uses** — all `str_concat` chains |
| Record construction | ✓ used (BodyContext, InferFrame, etc.) |
| Record field access `.` | ✓ used |
| Pattern matching | ✓ exhaustive per H6 |
| Block expressions | ✓ used |
| Higher-order fns / lambdas | ✓ used |
| ADTs | ✓ extensively |
| Module imports (flat + dotted) | ✓ used |
| Handler state updates `resume(..) with s = v` | ✓ used |
| Generic type parameters | ✓ used (List, Option, etc.) |

### 1.3 Verdict

**3 of 8 primitives fully exercised (1, 2, 8).** Verbs: 2 of 5 used
in body code (`|>`, `~>`). Negation / ownership / refinement: 0 uses.
Gradient position: near-bottom (4% annotation density).

**The compiler in its current state is a weak demonstration of
Mentl.** Users will see a WAT emitter, an inference engine, a graph
substrate — all of which exist in other languages — and will NOT see
the medium's native power.

---

## 2. Normative gap — what the compiler SHOULD use

Closing the gap is not adding NEW capabilities to Mentl. It is using
Mentl's ALREADY-EXISTING kernel to express the compiler's ALREADY-
EXISTING semantics. Annotations surface what the graph already
proved; the emitter doesn't change.

### 2.1 The nine action items — FV.1 through FV.9

Each item closes one gap. Each is bounded. Each exemplifies one
kernel primitive.

**FV.1 — `!E` negation sweep.** Declare `!IO` on lexer / parser /
infer / lower / types fns. Declare `!Alloc` on inner hot loops
(byte-dispatch, handle lookup, effect-row subsumption check).
Declare `!Diagnostic` on pure helpers. These are ROW DECLARATIONS —
inference already proves them; we're surfacing. **Primitive #4b.**

**FV.2 — `Pure` declaration sweep.** Every leaf helper that doesn't
perform effects gets `with Pure`. Rough target: 200+ fns in the
compiler are Pure (show_type, show_row, span_join, etc.) — declare
them. Unlocks memoization (post-first-light) without changing
semantics. **Primitive #4c + Primitive #7.**

**FV.3 — Refinement types.** Land 5 refinement-typed newtypes in
types.mn and use them throughout:
```
type Handle = Int where 0 <= self
type TagId = Int where 0 <= self && self <= 255
type ValidOffset = Int where 0 <= self
type NonEmptyList<A> = List<A> where len(self) > 0
type ValidSpan = Span where span_valid(self)
```
Verify handler discharges at construction sites; compile-time
proofs replace scattered runtime invariant comments. **Primitive #6.**

**FV.4 — Ownership markers.** Explicit `own` on consumed params
(`fn cache_write(own kai: KaiFile)` — kai is serialized and not
reused; `own` proves it). Explicit `ref` on borrowed params where
clarity matters. `!Mutate` region-freeze on append-only buffers
post-finalization (WAT string buffer once emission completes).
**Primitive #5.**

**FV.5 — Five-verb exemplar.** Find one honest use site for each of
`<|`, `><`, `<~` in the compiler:
- `<|` — infer_expr divergent branches (check AND effect-check AND
  ownership-check of one AST node in parallel)
- `><` — driver's module-level parallel compile for independent
  modules
- `<~` — iterative unification fixpoint chase (currently
  tail-recursion; `<~` draws the topology)

If no honest site exists for a verb, that's a question about
whether the verb is needed at all — but all three have candidates.
**Primitive #3.**

**FV.6 — String interpolation sweep.** Replace `str_concat` chains
with `"prefix${expr}suffix"` form. Cleans up show_*, error messages,
WAT emit, cache serialization. **Secondary: massively simplifies
hand-WAT Tier 2** because interpolation lowers to one call-pattern
instead of a long concat tree per message.

**FV.7 — `~>` chain sweep.** Find any nested `handle(handle(...))`
in compiler source; rewrite as `~>` chain. Drift-4 audit.

**FV.8 — Parameterized Diagnostic (11.B.M).** `effect Diagnostic(module: ModuleName) { report(...) }`. Every `perform report("parser", ...)` site drops its first arg. Row algebra
distinguishes `Diagnostic(ModParser)` from `Diagnostic(ModInfer)`.
Primitive #2b parameterized-effect exercise. Already named as
peer sub-handle in `ROADMAP.md`.

**FV.9 — Docstring harmonization** (item 11.E, folded here). Every
module's top docstring names:
- Purpose
- Which kernel primitive(s) it exercises
- Which Mentl tentacle it projects (if applicable)
- Invariants

Canonical template per NS-naming §1.5. Makes the compiler's own
source its own documentation AND a teaching artifact.

---

## 3. Impact on hand-WAT Tier 2

**Annotations are compile-time; runtime-erased.** Hand-WAT Tier 2
emits the same WAT for:

```
fn lexer(source: String) -> List<Token> with Memory + Alloc + !IO
```

as for:

```
fn lexer(source) = ...
```

The DIFFERENCE is compile-time information: the first lets Verify
discharge `!IO` (prove absence of IO calls); the second leaves that
implicit. Emitter output byte-identical.

**Therefore FV.1–FV.9 do NOT expand hand-WAT Tier 2 scope.** Items
where Tier 2 must know MORE:
- **FV.3 refinement types** — Tier 2's parser must handle `where`
  clauses. One extra pattern. ~10 lines of expander script.
- **FV.6 string interpolation** — Tier 2's parser must handle
  `${expr}` inside strings. One extra pattern. ~20 lines. **Saves
  more than it costs** because interpolated strings are simpler
  than str_concat chains in the emitter.
- **FV.4 `own` markers** — Tier 2 parser reads them as parameter
  flags; ignores for emission. ~5 lines.

Net: Tier 2 scope +~35 lines of parsing. Compiler source expressivity
+enormous. **The trade I previously surfaced dissolves.**

---

## 4. Landing sequence

Each FV item is its own commit. None block first-light; all can land
in parallel with hand-WAT Tier 1 runtime (which is unaffected by
compiler source annotation density).

Suggested order:

1. **FV.2** (Pure declarations) — mechanical; lowest-risk. Grep for
   leaf helpers; annotate; audit.
2. **FV.1** (`!E` negation) — requires knowing which fns prove which
   absences. Audit-driven. Per-function analysis.
3. **FV.3** (Refinement types) — add 5 newtypes; use throughout.
   Verify handler auto-discharges most.
4. **FV.4** (Ownership) — per-function audit. `own` on consumers;
   `ref` on observers; `!Mutate` on frozen buffers.
5. **FV.5** (Five-verb exemplar) — three refactor targets named;
   each small.
6. **FV.6** (String interpolation) — systematic rewrite of show_*
   and error messages.
7. **FV.7** (`~>` chain) — audit + rewrite (probably small; most
   compiler already uses `~>` at the top level).
8. **FV.8** (Parameterized Diagnostic) — already named as 11.B.M;
   cross-cutting but mechanical.
9. **FV.9** (Docstring harmonization) — per-module pass.

Could run in parallel to hand-WAT Tier 1 development. Could also
run in sequence if Morgan prefers substrate-before-bootstrap.

---

## 5. Descriptive audit's hand-WAT spec output

Post-FV completion, item 25's **descriptive** output: the exact
feature subset hand-WAT Tier 2 must handle. Based on current audit
plus FV additions:

**Must support (in Tier 2 expander):**

- 24 keywords per SYNTAX.md
- 14 BinOp variants (BinOp ADT landed 11.B.1)
- 2 verbs in bodies (`|>`, `~>`) + post-FV.5: 5 verbs
- Effect rows with `+`, `!` (post-FV.1), `Pure` (post-FV.2),
  negation
- Handler declarations with config params + state + arms
- Effect declarations (unparameterized + parameterized per FV.8)
- `handle ... with` block form + `~>` pipe form
- `resume(val)` + `resume(val) with s = v`
- ADTs with variant match
- Records (flat + field access)
- Pattern matching (all 7 pattern kinds from SYNTAX.md)
- String literals (+ interpolation per FV.6)
- Int / Float / Bool literals
- Generic type parameters (angle brackets in decls; inferred at
  call sites)
- Module imports (flat + dotted post-11.A)
- `own` / `ref` parameter markers (post-FV.4)
- Refinement `where` clauses (post-FV.3)
- Docstring `///` (post-FV.9)

**Can defer or omit (not used by compiler source):**

- MultiShot resume discipline (Mentl only; post-first-light)
- `@resume=Either` discipline (unused)
- Higher-rank generics (`fn run_with<E>(f: fn() -> () with E)`)
- Refinement predicates involving Verify SMT (ledger-only for now)
- Complex pattern types that compiler doesn't use
- Time / Clock / Sample effects (not in compiler's path)

**Sized estimate:** ~1500-2000 lines of hand-WAT Tier 2 expander
script, plus Tier 1 runtime (~1000 lines). Total hand-WAT: ~2500-3000
lines. Tractable.

---

## 6. Closing — why this audit matters

The Masterpiece Test applied to the compiler: **is this Mentl, or is
this Mentl-light?** Current answer: Mentl-light. FV.1–FV.9 convert it
to Mentl.

Cost: each FV is 2-6 hours of focused work. Total: ~1-2 weeks.
Benefit: at first-light, the compiler IS the exemplar. Users
downloading `mentl.wasm` and running `mentl check std/compiler/*.mn`
see the kernel exercised in the thing they just compiled — not
inference engines you'd find in any OCaml project.

**Mentl-solves-Mentl says:** don't ship the compiler until the
compiler exemplifies what it's compiling. The substrate already
supports everything; the code hasn't caught up. FV closes that gap
before first-light, not after.

Action items FV.1–FV.9 become peer commits in `ROADMAP.md`, landable in
parallel with hand-WAT Tier 1 development. None block first-light;
all make first-light mean more.
