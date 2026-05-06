# BT — Bootstrap Triage · the cross-module reference punch list

> **Status:** `[DRAFT 2026-04-23]`. Survey of the 14/15 `.mn` files
> that compile through the bootstrap pipeline but fail to validate
> standalone, categorized by failure shape. Drives the sequential
> close-out OR the timebox-and-pivot decision.
>
> **Companion to Hβ-bootstrap.md.** Hβ names the conventions;
> this walkthrough names the remaining work.

*Baseline: 10,629 lines of Mentl across 15 `src/*.mn` files
assemble a 4,733-line bootstrap `mentl.wat` (27,808 bytes of WASM).
1/15 (`verify.mn`, 63 lines, single `types` import) validates
fully. The other 14 compile through the lex/parse/emit pipeline
but fail to validate as standalone WAT because they reference
identifiers defined in sibling modules that aren't in the same
compilation unit.*

---

## 0. Framing — what "cross-module reference failure" is

Each `.mn` file is compiled INDEPENDENTLY by the bootstrap seed
compiler. When `graph.mn` performs `list_index(...)` (defined in
`lib/runtime/lists.mn`), the seed compiler emits a WAT `(call
$list_index ...)` instruction but no function import/export binds
`list_index` across compilation units. `wasm-validate` rejects the
module: "undefined function `list_index`".

**This is NOT a parser/inference bug.** It's the substrate's
missing module-linking pass.

Two honest ways forward:

1. **Sequential close-out.** Land a cross-module linker pass in the
   bootstrap (read every `.mn`'s exports; resolve every import to
   a ground symbol before emit; link). Scope: ~500-1000 lines WAT.
2. **Timebox + pivot.** If sequential close-out exceeds $N$ sessions
   (2-3 recommended), write a disposable translator in a
   well-typed host language (Rust / TypeScript / Python) that
   compiles the whole `src/` + `lib/` tree together. Keep the
   modular hand-WAT under `bootstrap/src/` as the reference
   soundness artifact; the disposable translator becomes the
   active first-compile path. Go / Rust / Zig all took this route
   and it is well-understood.

The evidence for which path to take lives in §2 below — the
per-module inventory.

---

## 1. The baseline — what validates

```
lib/prelude.mn                          →  ?  (not in current set)
lib/runtime/lists.mn                    →  ?  (dependency leaf)
src/verify.mn      (63 lines)           →  ✓  1 import (types), fully standalone
```

`verify.mn` validates because its imports don't produce
cross-module calls — `types` is ADT declarations, not function
definitions. Every other file imports modules that provide function
calls.

---

## 2. Per-module failure inventory

*Columns: module, line count, import count, primary failure shape.*
*Ordering: topological by dependency (leaves first).*

| Module | Lines | Imports | Primary failure shape |
|--------|-------|---------|----------------------|
| `src/verify.mn` | 63 | 1 | ✓ validates |
| `src/types.mn` | 1099 | 0-1 | Forward-declares ADTs; likely validates on its own if we split out one field |
| `src/graph.mn` | 484 | 3 (types, effects, runtime/strings) | Calls `str_concat`, `list_index`, `EfClosed` — all cross-module |
| `src/effects.mn` | 690 | 2 (types, runtime/strings) | Row-algebra primitives cross-referenced |
| `src/query.mn` | 311 | 3 (types, graph, runtime/strings) | Read-only; lightest cross-module surface |
| `src/lexer.mn` | 284 | 2 (types, runtime/strings) | Byte primitives from runtime |
| `src/parser.mn` | 1402 | 2-3 (types, lexer, runtime) | Large surface but pure lookups |
| `src/own.mn` | 588 | 3 (types, graph, effects) | `consume()` ops cross-module |
| `src/infer.mn` | 2210 | 5+ (types, graph, effects, own, runtime) | Heaviest cross-module surface |
| `src/lower.mn` | 1243 | 4+ (types, graph, effects, runtime) | IR construction |
| `src/pipeline.mn` | 506 | 5+ (types, effects, all handlers) | Handler composition |
| `src/cache.mn` | 640 | 4 (types, runtime/binary, io, strings) | Pack/Unpack crosses modules |
| `src/driver.mn` | 311 | 4+ (cache, parser, lexer, infer) | Top-level orchestration |
| `src/mentl.mn` | 703 | 4+ (types, graph, effects, others) | Teach substrate |
| `src/main.mn` | 95 | 3+ (driver, pipeline, others) | Entry point |

**Observations:**
- **Import graph is mostly acyclic** (types → effects/graph → {infer, own} → lower → pipeline → driver → main).
- **`types.mn` is the root;** everything else imports it.
- **Two modules (`infer.mn` + `parser.mn`) account for ~34% of the tree** — linker load concentrates here.
- **No file has more than ~6 import lines;** module graph is sparse.

---

## 3. The linking work — what closing the gap actually requires

A bootstrap-level cross-module linker pass reads:
1. **Every `.mn` file's exports** — every top-level `fn`, `effect`,
   `handler`, `type` declaration's symbol + scheme.
2. **Every `.mn` file's imports** — which external symbols each
   file's emitted WAT references.
3. **Emits** one assembled `mentl.wat` with:
   - All functions collected, renamed to avoid collision
     (`<module>__<symbol>`).
   - All handlers collected; handler-chain composition resolved at
     link time.
   - WASI imports deduplicated.
   - `_start` wired to `main.mn`'s `main()`.

**Scope estimate:** 300-800 lines WAT in a new `bootstrap/src/link.wat`
chunk + adjustments to `build.sh` to run the link pass before
`wat2wasm`. **~1-3 sessions** at Opus pace.

**Alternative scope estimate:** a Python linker doing the same work
as a pre-assembly pass over `bootstrap/src/*.wat` chunks. ~200
lines. **~0.5-1 sessions.** Post-first-light, the Python linker
dissolves into an Mentl `link_handler` on the graph.

---

## 4. Structural continuation signals — what tells us sequential close-out is working

*Revised 2026-04-23. Prior version included session-count and
line-budget pivot criteria, and named a disposable-translator
pivot option. Both were fluency-drift imports (agile/scrum
vocabulary + the "write a translator in $OTHER_LANGUAGE" idiom).
Morgan's 2026-04-20 decision stands: hand-WAT is the reference
soundness artifact; growth past L1 is via Hβ §2 Tier 3 incremental
self-hosting, never via a foreign-language translator.*

**Continue sequential close-out when:**

1. **Each linker addition traces to a substrate walkthrough
   paragraph.** If the pass resolves cross-module symbols per a
   shape the existing walkthroughs already name (import graph,
   scheme serialization, handler chain composition), the work is
   transcription, not re-design.

2. **The first module past `verify.mn` validates without
   surfacing a substrate gap.** If the second module requires only
   the linker pass (no new effect declarations, no new primitive
   semantics), the pattern generalizes to the other twelve.

3. **Morgan + Opus can audit each linker extension against its
   walkthrough in one sitting.** Reference-soundness is intact.

**Stop and reshape (not pivot to a foreign tool) when:**

1. **The linker requires substrate the existing walkthroughs
   haven't named.** Example: if cross-module handler-chain
   composition needs a mechanism Hβ / H1 / HC haven't specified,
   the design question isn't resolved yet. Stop; write the
   walkthrough (or extend an existing one); resume linker work
   only after the contract is on the page.

2. **A module reveals thesis-scale regression** — refinement
   obligations don't serialize across modules, or evidence
   passing breaks at module boundaries. Stop; name the gap as a
   new substrate walkthrough; land it; resume.

3. **The linker itself starts duplicating Mentl substrate logic.**
   If the linker pass is reimplementing env_extend or
   handler_chain in Python/shell, it has become a second
   compiler. Stop; move the logic to `src/` where it belongs;
   call it from the linker as the substrate.

**No temporal criteria.** "Three sessions" was project-management
vocabulary that Mentl doesn't speak. The linker lands when its
walkthrough paragraphs have been transcribed to WAT and the
audit is clean. Scope is a consequence of substrate necessity.

**No disposable translator.** If a Python/Rust/C translator would
"speed things up," it would do so by importing that language's
fluency into the seed compiler's emit shape — the exact drift
Morgan's 2026-04-20 decision excludes. Growth past L1 is via
Tier 3 (Hβ §2): VFINAL-on-partial-WAT compiles extended `src/*.mn`;
diff against hand-WAT; integrate; audit per walkthrough
paragraph. Mentl bootstraps through Mentl.

---

## 5. The recommended path — sequential close-out, leaves-first

**Session 1:** Land a Python pre-link pass that:
- Reads every `bootstrap/src/*.wat` chunk.
- Collects function/global/memory declarations.
- Renames collisions (none expected; single namespace).
- Produces one concatenated, validated `mentl.wat`.

**Fitness test:** `bootstrap/build.sh` + `wasm-validate mentl.wasm`
exits 0. Today's `types.mn` + `verify.mn` + `runtime/strings.mn` +
`runtime/lists.mn` compile and validate together.

**Session 2:** Extend the linker to run on `src/*.mn` output:
- Every seed-compiled `.mn` produces a partial WAT.
- Linker concatenates partial WATs, emits unified module.
- Each validated module = one commit.

**Fitness test:** `graph.mn` + `effects.mn` + their dependencies
validate.

**Session 3:** Close out the remaining modules.

**Fitness test:** full `src/*.mn` + `lib/**/*.mn` assembles into
one `mentl.wasm` that `wasmtime` executes.

**Following session (4):** first-light test — run the assembled
`mentl.wasm` on `src/*.mn` input; compare output to `mentl.wat`;
diff.

---

## 6. Forbidden patterns in the linker

- **Drift 1 (vtable):** the linker is NOT building a dispatch
  table. Each `perform op_name(args)` site is already known-ground
  (direct `call`) or polymorphic (call_indirect through closure
  field) BEFORE linking. The linker resolves names, not dispatch.
- **Drift 8 (string-keyed-when-structured):** symbol resolution
  uses a structured `ModuleId = LocalModule(ModName) |
  RuntimeModule(ModName)` ADT, not flat string matching.
- **Drift 9 (deferred-by-omission):** no "later we'll do X"
  comments. Every symbol either resolves or compile-fails with a
  named diagnostic.

---

## 7. Post-linking — what STILL blocks first-light

Once the linker lands and all 15 modules validate together:

1. **Runtime stubs may still be unimplemented** (e.g., some
   `list_*` ops that the seed compiler emits but the hand-WAT
   runtime doesn't provide). Fitness test: the assembled
   `mentl.wasm` runs `wasmtime` without trapping on a missing
   symbol when fed `src/verify.mn` as input.
2. **`_start` needs to read stdin, compile, write stdout.** Today's
   `bootstrap/src/emit_module.wat` wraps an imperative top-level in
   `_start`, but a full self-compile harness needs WASI scaffolding.
3. **Constructor mangling** across modules — if two modules define
   a constructor with the same name, symbol collisions. Scope:
   none expected today but audit before claiming ready.
4. **Match-in-expr** — noted in the prior session as incremental;
   may surface as runtime traps rather than validator rejects.

**Each is named, each is bounded, none is research-grade.** The
thesis-scale research is in MO (oracle loop); this walkthrough is
mechanical transcription within known substrate.

---

## 8. Dispatch

- **Linker work:** Opus inline or Opus subagent. The pass is small
  (~200-800 lines) but every drift-mode guard matters.
- **Post-linking runtime fill-in:** mentl-implementer suitable once
  the specific missing runtime primitive is named and given a
  walkthrough citation.

---

## 9. Closing

The 14/15 cross-module failure is a single concrete gap — module
linking — not a cloud of bugs. Three sessions at sequential pace
close it. If three sessions don't close it, one of three named
diagnostics fires, naming the pivot precisely. **No vibes-based
pivot; explicit fitness criteria.**

*Cross-module linking is what every bootstrapped language
eventually builds. Mentl's version is smaller because the modules
are smaller and the kernel is tighter. Three sessions or one
explicit pivot.*

---

## §11 Riffle-back addendum — per-file compile diagnosis (2026-04-25)

**Per `LF-feedback-lowering.md` §11 precedent (commit `5681202`) +
the realization-loop discipline (insight #12): every walkthrough
that lands substrate (or whose framing gets exercised + corrected)
gets a riffle-back addendum naming what landed exactly, what
landed differently, and what didn't land.**

### §11.1 The finding

**Date:** 2026-04-25.
**Test:** ran `cat src/graph.mn | wasmtime run bootstrap/mentl.wasm`
to verify BT §1's claim that "the other 14 [src/*.mn files] compile
through the lex/parse/emit pipeline but fail to validate as
standalone WAT because they reference identifiers defined in
sibling modules that aren't in the same compilation unit."

**Result:** the seed produces only 34 lines of degenerate WAT for
src/graph.mn (484 lines of source). The generated `_start_fn`
contains a single line: `(drop (i32.div_s (local.get $runtime)
(local.get $strings)))` referencing nonexistent locals `$runtime`
and `$strings` — leftover from parsing graph.mn's import statements
(`import types`, `import effects`, `import runtime/strings`) as
identifier-expressions rather than as module imports.

**Diagnosis:** this is NOT BT §1's stated cross-module-ref failure
(where seed-emitted `(call $list_index)` references a sibling
module's function). It's earlier in the pipeline — the seed's
parser handles `import` statements partially / incorrectly,
emitting identifier-expressions that the emit phase produces as
undefined locals.

### §11.2 What this means for BT's framing

BT §1's per-module inventory said:

> | Module | Lines | Imports | Primary failure shape |
> |--------|-------|---------|----------------------|
> | `src/graph.mn` | 484 | 3 | Calls `str_concat`, `list_index`, `EfClosed` — all cross-module |

The "Primary failure shape" column is **partially aspirational**:
graph.mn doesn't compile through to the cross-module-ref stage; it
fails earlier at the import-handling boundary. The same likely
applies to the other 13/15 modules in BT §1 — their stated failure
shape assumes compilation reaches the emit-cross-module-call stage,
but reality may be earlier-stage parser/emit incompleteness.

**Per-module inventory needs verification:** test each of the 13
non-verify modules through the seed; categorize actual failure
shape (parser? emit? cross-module-ref? something else?). The
inventory then drives the actual substrate-extension work
per-module.

### §11.3 What this means for the linker work (BT §3)

**The Python pre-link pass (`bootstrap/src/link.py`) works on the
ASSUMPTION that per-file compilation produces link-needing WAT
(valid syntactic WAT with cross-module symbol references).** Today
that assumption holds for verify.mn alone; for graph.mn + others,
the pre-link pass would link DEGENERATE WAT.

**The linker is therefore not the next move.** The next move is
**extending the seed's per-file compilation surface** (parser +
emit per Hβ §1 conventions) to handle the full src/*.mn surface.
THEN the linker becomes load-bearing as designed.

### §11.4 Sub-handles surfaced

**Per Anchor 7 cascade discipline + the substrate-honesty principle:**

- **BT.A.0** — per-module-failure-shape verification sweep. Run
  every src/*.mn + lib/**/*.mn file through the seed; categorize
  actual failure shape per file; update §1 per-module inventory
  with reality. Substrate gap: a test harness script (~50 lines
  bash) that runs the seed against each module + reports failure
  category. Lands as its own commit.
- **BT.A.1** — per-failure-category-substrate-extension work. For
  each failure category (parser-incomplete / emit-incomplete /
  cross-module-ref / runtime-stub-missing), the corresponding
  bootstrap chunk extension closes the gap. Per Hβ §1 conventions
  + per-module sub-handles. Lands per Anchor 7.
- **BT.A.2** — `bootstrap/src/link.py` per BT §3 + Hβ §2.3.
  Lands AFTER BT.A.1 produces link-needing per-file outputs.
- **BT.A.3** — bootstrap/first-light.sh per Hβ §2.4. Closes Leg 1
  of the First-Light Triangle.

### §11.5 The corrective sequencing

Per Hβ §13 ultimate-form bootstrap rewrite path:

1. ~~A.1 = Python pre-link pass (BT §5 Session 1)~~ — superseded;
   the pass would link broken outputs.
2. **A.1 (revised) = BT.A.0 + BT.A.1 + BT.A.2 + BT.A.3** —
   per-module verification sweep, per-failure-category extension
   work, then linker, then harness. Each substrate piece per Hβ
   §1 conventions; per-module per BT §11.4 sub-handles.
3. **A.2 = first-light-L1 tag** — when the harness exits 0.

**Estimated scope:** dependent on what BT.A.0 surfaces. If most
modules have similar parser-incompleteness shape, the extension
work converges on a handful of parser chunks + emit chunks. If
each module has a unique failure shape, scope grows. The substrate
discipline is honest measurement, not pre-estimation.

### §11.6 Why this discipline matters

Per insight #12 (Realization Loop) + Anchor 7 cascade discipline:
**walkthroughs are LIVE contracts; framing that gets corrected by
substrate experience earns its riffle-back.** BT §1's framing was
correct per its 2026-04-23 authoring; my 2026-04-25 finding shows
the framing's per-module-failure-shape claims need verification
before driving substantive substrate work.

The walkthrough stays the contract; the addendum records the
residue between intent and substrate. Per the LF.B precedent
(LF walkthrough §11 + B.9 substrate landing): future-session work
on BT.A.* reads §11 first; doesn't re-discover the finding from
seed behavior.

**Mentl solves Mentl.** The walkthrough's role is to specify what
IS; my discovery's role is to align the specification with what
seed-runtime experience proves.

---
