# NS-structure — Structural-reshape walkthrough

> **Status:** `[PENDING]`. Gates Pending Work item 17' (directory restructure, single commit). Depends on NS-naming.md closure. After this walkthrough closes, item 17' has no design left — only move + import-path rewrite.

*The repo's shape IS the canonical Inka-project template. Every Inka programmer's first `ls` should teach them the shape every future project inherits.*

---

## 0. Framing — why structure is substrate, not filing

Inka dissolves framework boundaries into handler composition. The repo's shape encodes what distinctions Inka honors. Peer languages have `tests/` because their type systems can't prove correctness; `examples/` because their docs rot; `node_modules/` because their resolution is textual. **Inka has NONE of these because its kernel dissolves each.** The repo's shape must reflect the dissolutions, or the medium leaks the boundaries it claims to close.

This walkthrough resolves the final top-level shape + every file's new home. Item 17' (restructure commit) then performs the moves mechanically, gated by drift-audit.

**What this walkthrough gates:**
- Item 17' — structural migration (single commit)
- Items 19, 20, 21, 22 — doc/walkthrough/trace/memory updates reflecting new paths (fold into the restructure commit where possible; item 17' absorbs them)

**What this walkthrough does NOT cover:**
- Naming within files (that's NS-naming, item 4 — already drafted; closes before this)
- Entry-handler paradigm (that's EH-entry-handlers, item 6 — whose `main.nx` rewrite rides the restructure)
- Simplification discipline (that's SIMP, item 7)

**Dependency:** NS-naming must close first. Rationale: restructure moves files; if naming is still in flight, every rename rewrites imports across modules; doing them in one pass avoids twice-churn.

---

## 1. The five structural decisions

### 1.1 Six top-level directories (interim; post-first-light dissolves further)

**Current state.** The repo has `std/` (holding compiler + runtime + prelude + dsp + ml all mixed), `docs/` (with `rebuild/` inside), `tools/`, plus root-level markdown + license. No separation between compiler source and stdlib-that-users-import. No dedicated bootstrap directory.

**Canonical shape (post-restructure):**

```
inka/
├── README.md
├── CLAUDE.md
├── LICENSE-{MIT,APACHE}
│
├── src/                      ← the Inka compiler source
├── lib/                      ← the stdlib (what user programs import)
├── docs/                     ← documentation
├── bootstrap/                ← hand-WAT reference image + first-light harness
└── tools/                    ← dev scripts (bash, pre-Inka; dissolves post-first-light)
```

**Why six, not more:**
- Every directory pulls load-bearing weight. No category directory (`examples/`, `tests/`, `benchmarks/`) exists for convention's sake.
- `src/` + `lib/` split: compiler is WHAT IS WRITTEN; stdlib is WHAT USERS IMPORT. Different audiences; different lifecycle.
- `bootstrap/` is substrate artifact (the hand-WAT reference image kept forever); holds its own README + `first-light.sh`.
- `tools/` is pre-Inka scaffolding; dissolves post-first-light when scripts can be rewritten as Inka.
- `docs/` is pre-first-light documentation; partially dissolves post-first-light when `doc_handler` generates from `///` comments + graph provenance.

**Post-first-light dissolutions (tracked in PLAN.md Decisions Ledger):**
- `tools/` dissolves → scripts become Inka programs in `lib/`.
- `docs/` shrinks to human-written manifestos (DESIGN.md, INSIGHTS.md, remaining walkthroughs + Decisions Ledger); per-module specs + error catalog generated.
- Final form probably **four directories**: `src/`, `lib/`, `bootstrap/`, minimal `docs/`.

**The six-directory interim IS the Inka-project template for a developer's own projects.** Most user projects won't have `bootstrap/` or `tools/` or full `docs/`; they'll have:

```
my-project/
├── README.md
├── src/
│   ├── main.nx
│   └── <modules>.nx
└── .inka/                   ← gitignored; IC cache + content-addressed handlers
```

Minimal, honest, Inka-native.

**Drift modes foreclosed:**
- **#6 (primitive-type-special-case):** `examples/`, `tests/`, `benchmarks/`, `scripts/` as "special directories with special semantics" dissolved. Nothing is special.
- **#9 (deferred-by-omission):** `SYNTHESIS_CROSSWALK.md` as archive-folder-as-file (deleted in NS-naming). Every remaining directory earns its keep or dissolves post-first-light.

### 1.2 `src/` — the Inka compiler source

**Current location:** `std/compiler/`. Conceptually mis-filed — the compiler isn't stdlib (users don't `import std/compiler/infer`). Move to `src/`.

**Post-restructure `src/` contents:**

```
src/
├── main.nx                   ← compiler entry point + entry-handler declarations
│                                (compile_run / check_run / audit_run / query_run /
│                                 teach_run / test_run / repl_run / new_project)
├── types.nx                  ← THE vocabulary (Ty, Reason, Scheme, typed AST)
├── graph.nx                  ← the Graph substrate (flat-array, O(1) chase)
├── effects.nx                ← EffRow Boolean algebra
├── infer.nx                  ← HM, one walk, graph-direct
├── lower.nx                  ← LowIR via LookupTy
├── lex.nx                    ← tokenizer (was: lexer.nx)
├── parse.nx                  ← parser (was: parser.nx)
├── pipeline.nx               ← pipeline composition via ~>
├── own.nx                    ← ownership as Consume effect
├── verify.nx                 ← Verify ledger → SMT
├── clock.nx                  ← Clock / Tick / Sample / Deadline
├── mentl.nx                  ← teaching substrate (8 tentacles)
├── query.nx                  ← forensic substrate + CLI query
├── cache.nx                  ← per-module .kai cache
├── driver.nx                 ← DAG walk + cache hit/miss
└── backends/
    └── wasm.nx               ← LowIR → WAT (peer; other backends sibling)
```

**Rename mapping:**
- `std/compiler/lexer.nx` → `src/lex.nx` (NS-naming decision 1.3)
- `std/compiler/parser.nx` → `src/parse.nx` (NS-naming decision 1.3)
- Every other `std/compiler/*.nx` → `src/<same-name>.nx` (extension migration per item 10)
- `std/compiler/backends/wasm.nx` → `src/backends/wasm.nx`

**Import-path rewrites:** every `import compiler/X` → `import X` OR `import src/X` (depending on how the import resolver treats "project-relative" vs "absolute-from-repo-root"). **Resolution:** project-relative. The compiler IS its own project; imports within `src/` are project-relative (`import graph` resolves to `src/graph.nx`). Cross-project imports use the full path (`import lib/prelude` resolves to `lib/prelude.nx`).

### 1.3 `lib/` — the stdlib

**Current location:** `std/` root + `std/runtime/` + `std/prelude.nx` + `std/test.nx` + `std/types.nx` + `std/dsp/` + `std/ml/`. Mixed purposes.

**Post-restructure `lib/` contents:**

```
lib/
├── prelude.nx               ← Iterate effect, Bool ADT, Option/Result/Some/None,
│                                derived collection ops, user-facing Option helpers
│                                (ABSORBS former std/types.nx)
├── test.nx                  ← Test effect (assert, assert_eq, assert_near),
│                                assert_reporter handler, verify_assert lifting handler
├── runtime/
│   ├── io.nx                ← WASI iov scratch + print/read
│   ├── lists.nx             ← tagged list ops + buffer-counter primitive
│   ├── strings.nx           ← flat string primitives + sorted-set algebra
│   └── tuples.nx            ← tuple value layout + accessors
├── dsp/                     ← real DSP handlers (NOT "examples" — library code)
│   ├── signal.nx
│   ├── spectral.nx
│   └── processors.nx
├── ml/                      ← real ML handlers (NOT "examples" — library code)
│   ├── tensor.nx
│   └── autodiff.nx
└── tutorial/                ← Mentl's teaching curriculum (8 primitives)
    ├── 00-hello.nx          ← minimum-teachable-subset (primitives 1+2+3);
    │                           DOUBLES as `inka new <project>` template
    ├── 01-graph.nx          ← primitive 1 (Graph + Env)
    ├── 02-handlers.nx       ← primitive 2 (handlers + resume discipline)
    ├── 03-verbs.nx          ← primitive 3 (five verbs)
    ├── 04-row.nx            ← primitive 4 (Boolean effect algebra)
    ├── 05-ownership.nx      ← primitive 5 (ownership as effect)
    ├── 06-refinement.nx     ← primitive 6 (refinement types)
    ├── 07-gradient.nx       ← primitive 7 (gradient)
    └── 08-reasons.nx        ← primitive 8 (HM + Reasons / Why Engine)
```

**Rename mapping:**
- `std/prelude.nx` + `std/types.nx` → merged into `lib/prelude.nx`
- `std/test.nx` → `lib/test.nx`
- `std/runtime/*.nx` → `lib/runtime/*.nx`
- `std/dsp/*.nx` → `lib/dsp/*.nx`
- `std/ml/*.nx` → `lib/ml/*.nx`
- **New:** `lib/tutorial/` directory created with 9 files (scaffolded stubs pre-first-light; Morgan writes the curriculum content; Mentl narrates over them).

**Why `lib/dsp/` and `lib/ml/` are NOT examples:**
- They export handlers users import: `import lib/dsp/signal`, `import lib/ml/autodiff`.
- They're real library code with real users (any program doing DSP or ML work).
- The thesis "every framework is a handler" requires library handlers for DSP + ML to actually exist in-tree.
- Calling them "examples" would demote substantive library modules to demo status.

**Why `lib/tutorial/` IS curriculum, not examples:**
- Files are ordered (00-08), matching the eight kernel primitives + a warmup.
- Mentl's Teach tentacle narrates over them (per MV walkthrough §3).
- `00-hello.nx` doubles as the `inka new <project>` template — when a developer creates a new project, they START from 00.
- Each file demonstrates ONE primitive; they're not runnable demos for marketing, they're pedagogical substrate.

### 1.4 `bootstrap/` — the hand-WAT reference image

**New directory.** Created by the restructure; empty scaffold pre-first-light; fully populated as Hβ-bootstrap walkthrough + hand-WAT writing progresses.

**Post-restructure `bootstrap/` contents:**

```
bootstrap/
├── README.md                 ← explains hand-WAT strategy; points to Hβ walkthrough
├── inka.wat                  ← EMPTY until item 27 (Tier 1 hand-WAT) begins;
│                                eventually 50–150k lines of hand-written WAT;
│                                KEPT FOREVER as reference soundness artifact
└── first-light.sh            ← the fixed-point test harness:
                                  wat2wasm bootstrap/inka.wat -o bootstrap/inka.wasm
                                  wasm-validate bootstrap/inka.wasm
                                  cat src/*.nx lib/**/*.nx | wasmtime run bootstrap/inka.wasm > inka2.wat
                                  diff bootstrap/inka.wat inka2.wat
```

**Why a dedicated directory:**
- The hand-WAT is ONE FILE (single monolithic `inka.wat` per Decisions Ledger); its presence at repo root would clutter.
- `first-light.sh` belongs with its artifact, not in `tools/`.
- Post-first-light, `bootstrap/` is the **soundness verification substrate**: any future Wasm target runs the fixed-point test against the preserved hand-WAT.

### 1.5 `docs/` — documentation (partially dissolves post-first-light)

**Current location:** `docs/` with `docs/rebuild/` inside (archaeology name).

**Post-restructure `docs/` contents:**

```
docs/
├── DESIGN.md                 ← the manifesto (§0.5 kernel + 12 chapters)
├── INSIGHTS.md               ← crystallized truths
├── PLAN.md                   ← roadmap + Decisions Ledger
├── SYNTAX.md                 ← canonical syntax
├── errors/                   ← canonical error catalog (E/V/W/T/P codes)
│   ├── README.md
│   └── <CODE>.md             ← one file per error code
├── specs/                    ← the 12 per-module specs (was: rebuild/)
│   ├── 00-graph.md           ← was: 00-Graph.md (NS-naming rename)
│   ├── 01-effrow.md
│   ├── 02-ty.md
│   ├── 03-typed-ast.md
│   ├── 04-inference.md
│   ├── 05-lower.md
│   ├── 06-effects-surface.md
│   ├── 07-ownership.md
│   ├── 08-query.md
│   ├── 09-mentl.md
│   ├── 10-pipes.md
│   ├── 11-clock.md
│   └── simulations/          ← per-handle cascade walkthroughs
│       ├── H1-evidence-reification.md
│       ├── H2-record-construction.md
│       ├── H2.3-nominal-records.md
│       ├── H3-adt-instantiation.md
│       ├── H3.1-parameterized-effects.md
│       ├── H4-region-escape.md
│       ├── H5-mentl-arms.md
│       ├── H6-wildcard-audit.md
│       ├── HB-bool-transition.md
│       ├── FS-filesystem-effect.md
│       ├── IC-incremental-compilation.md
│       ├── MV-mentl-voice.md
│       ├── NS-naming.md                 ← this walkthrough's sibling
│       ├── NS-structure.md              ← THIS FILE
│       ├── EH-entry-handlers.md         ← item 6, TBD
│       ├── SIMP-simplification-audit.md ← item 7, TBD
│       ├── DET-determinism-audit.md     ← item 8, TBD
│       ├── LF-feedback-lowering.md      ← item 1, TBD
│       ├── Hβ-bootstrap.md              ← item 9, TBD
│       └── TS-teach-synthesize.md       ← SUPERSEDED (kept historical)
└── traces/
    └── a-day.md              ← integration scoreboard
```

**Deleted:**
- `docs/SYNTHESIS_CROSSWALK.md` — per NS-naming decision 1.6.
- `docs/rebuild/` directory — renamed to `docs/specs/`.

**Post-first-light dissolutions:**
- `docs/errors/<CODE>.md` files become `doc_handler` projections from error declarations + `///` comments.
- `docs/specs/00-11.md` files become `doc_handler` projections from each module's kernel-primitive-served declaration + structural analysis.
- `docs/specs/simulations/*.md` remain (cascade reasoning record is historical; doesn't auto-regenerate).
- `DESIGN.md`, `INSIGHTS.md`, `PLAN.md`'s Decisions Ledger, `SYNTAX.md` — remain human-written manifestos.

### 1.6 Root-level files

```
inka/
├── README.md                 ← first-read; kernel enumeration; canonical-template
├── CLAUDE.md                 ← agent discipline (Session Zero, anchors, drift modes)
├── LICENSE-MIT
└── LICENSE-APACHE
```

No `.gitignore` changes beyond adding `.inka/` cache pattern. No new root-level files.

---

## 2. The four interrogations, applied to this walkthrough

### Graph?

What does the graph know about directory structure? The module resolver (driver.nx) reads import paths and resolves them to source files. Currently it resolves `compiler/X` to `std/compiler/X.nx`; post-restructure it resolves `X` (project-relative) to `src/X.nx` for compiler-internal, and `lib/X` for stdlib imports. **The graph's import resolution IS the directory structure's interface.**

### Handler?

What handler resolves imports? `driver.nx`'s module-DAG walk + `Filesystem` effect. Post-restructure, the handler chain is:
```
resolve_source(ModuleId)  ~>  project_local_resolver  (looks in src/)
                          ~>  lib_resolver            (looks in lib/)
                          ~>  hash_store_resolver     (looks in .inka/handlers/)
                          ~>  github_resolver         (fetches remote)
```
Each resolver is a handler on `resolve_source(ModuleId) -> Source`. The directory hierarchy IS the ordered list of places resolvers look. **The structure is handler-chain-shape.**

### Verb?

No pipe-verb change. Directory structure is namespace, not data flow. **N/A.**

### Row?

No effect row change. Restructure doesn't alter what effects are performed; it alters where the code implementing them lives. **N/A.**

### Ownership?

No `own`/`ref` change. **N/A.**

### Refinement?

No refinement change. **N/A.**

### Gradient?

Post-restructure, the `lib/tutorial/` directory IS a gradient-projection: each file escalates through one kernel primitive. Mentl's Teach tentacle (primitive 7 / Teach) narrates over them in order. **This is the gradient realized as curriculum.** The directory's ordering IS the gradient's steps.

### Reason?

Every file move generates `Reason::Inferred("moved per NS-structure.md:<section>")` in the graph's provenance. Post-restructure, the Why Engine can walk "why is this file here?" → "per NS-structure §1.3."

---

## 3. Forbidden-pattern list, per decision

### Decision 1.1 — six top-level directories

- **Drift 6 (primitive-type-special-case):** forbidden to introduce `special/` or `experimental/` or `sandbox/` directories. Every top-level directory earns its keep or doesn't exist.
- **Drift 9 (deferred-by-omission):** forbidden to create a directory "for future use" with a placeholder file. Create when needed; not before.

### Decision 1.2 — `src/` layout

- **Drift 5 (C calling convention):** forbidden to organize `src/` by "what acts" (lexers/, parsers/, etc.). Files are named by what they DO (infer, lower, verify) or what they HOLD (types, graph, effects).
- **Drift 9 (deferred-by-omission):** every file from `std/compiler/` moves in the same restructure commit; none deferred "to split up the PR."

### Decision 1.3 — `lib/` layout

- **Drift 6 (primitive-type-special-case):** `lib/dsp/` and `lib/ml/` are NOT "examples" or "demos"; they're library code users import. Forbidden to rename them `examples/dsp/` or prefix with `demo_`.
- **Drift 9 (deferred-by-omission):** `lib/tutorial/` files are stubbed with TODO content pre-first-light is OK (Morgan writes the curriculum post-MV walkthrough closure), but the DIRECTORY + FILENAMES land in the restructure commit so the structure is stable.

### Decision 1.4 — `bootstrap/`

- **Drift 9 (deferred-by-omission):** `bootstrap/inka.wat` starts empty; `bootstrap/README.md` is written in the restructure commit; `bootstrap/first-light.sh` is scaffolded in the restructure commit (functional but guarded-against-empty-wat). No deferred scaffolding.

### Decision 1.5 — `docs/` layout

- **Drift 9 (deferred-by-omission):** the `docs/rebuild/` → `docs/specs/` rename lands with the restructure; not split across commits.
- **Drift 6 (primitive-type-special-case):** `docs/specs/` does NOT have sub-categorization (`docs/specs/kernel/`, `docs/specs/handlers/`, etc.). One flat structure. The 12 specs are peers; the simulations are peers under simulations/.

### Decision 1.6 — root-level files

- No new root-level files unless they serve load-bearing purpose. `ROADMAP.md` is now the canonical roadmap; git history is changelog; `CLAUDE.md` is contribution discipline.

### Cross-cutting bug classes at restructure-execution sites

- **`acc ++ [x]` loops** in any import-path rewriting logic: use buffer-counter substrate per Ω.3.
- **`if str_eq(a, b) == 1`** in any directory-comparison logic: use `if str_eq(a, b) {}` canonical form.
- **Flag/mode-as-int** in directory-type-dispatch: use ADT (e.g., `type DirKind = Src | Lib | Docs | Bootstrap | Tools`).
- **`_ => <fabricated>`** in match over directory kinds: enumerate every kind explicitly.

---

## 4. Edits as literal tokens (prescriptive)

Item 17' (restructure commit) performs these moves mechanically.

### 4.1 File moves (compiler → src/)

```
mv std/compiler/types.nx       → src/types.nx
mv std/compiler/graph.nx       → src/graph.nx
mv std/compiler/effects.nx     → src/effects.nx
mv std/compiler/infer.nx       → src/infer.nx
mv std/compiler/lower.nx       → src/lower.nx
mv std/compiler/lexer.nx       → src/lex.nx          (NS-naming 1.3)
mv std/compiler/parser.nx      → src/parse.nx        (NS-naming 1.3)
mv std/compiler/pipeline.nx    → src/pipeline.nx
mv std/compiler/own.nx         → src/own.nx
mv std/compiler/verify.nx      → src/verify.nx
mv std/compiler/clock.nx       → src/clock.nx
mv std/compiler/mentl.nx       → src/mentl.nx
mv std/compiler/query.nx       → src/query.nx
mv std/compiler/cache.nx       → src/cache.nx
mv std/compiler/driver.nx      → src/driver.nx
mv std/compiler/main.nx        → src/main.nx
mkdir src/backends/
mv std/compiler/backends/wasm.nx → src/backends/wasm.nx
```

### 4.2 File moves (stdlib → lib/)

```
mv std/prelude.nx              → lib/prelude.nx
# std/types.nx contents absorbed into lib/prelude.nx (merged at restructure)
mv std/test.nx                 → lib/test.nx
mkdir lib/runtime/
mv std/runtime/io.nx           → lib/runtime/io.nx
mv std/runtime/lists.nx        → lib/runtime/lists.nx
mv std/runtime/strings.nx      → lib/runtime/strings.nx
mv std/runtime/tuples.nx       → lib/runtime/tuples.nx
mkdir lib/dsp/
mv std/dsp/signal.nx           → lib/dsp/signal.nx
mv std/dsp/spectral.nx         → lib/dsp/spectral.nx
mv std/dsp/processors.nx       → lib/dsp/processors.nx
mkdir lib/ml/
mv std/ml/tensor.nx            → lib/ml/tensor.nx
mv std/ml/autodiff.nx          → lib/ml/autodiff.nx
```

### 4.3 lib/tutorial/ — new directory with stub files

```
mkdir lib/tutorial/
touch lib/tutorial/00-hello.nx
touch lib/tutorial/01-graph.nx
touch lib/tutorial/02-handlers.nx
touch lib/tutorial/03-verbs.nx
touch lib/tutorial/04-row.nx
touch lib/tutorial/05-ownership.nx
touch lib/tutorial/06-refinement.nx
touch lib/tutorial/07-gradient.nx
touch lib/tutorial/08-reasons.nx
```

Each file gets a docstring header naming its primitive + placeholder body marked `TODO: curriculum content` + a compile-checkable skeleton (imports + empty main). **Intentionally minimal** — Morgan writes the curriculum content post-MV walkthrough closure; restructure just establishes the shell.

### 4.4 bootstrap/ — new directory

```
mkdir bootstrap/
touch bootstrap/inka.wat           ← empty; populated by item 27+
```

`bootstrap/README.md` written in the restructure commit (content below).

`bootstrap/first-light.sh` written in the restructure commit (content below).

**`bootstrap/README.md` content (exact):**

```markdown
# bootstrap/ — hand-WAT reference image

This directory holds Inka's bootstrap soundness artifact.

- `inka.wat` — the hand-written WAT that compiles to `inka.wasm`,
  the seed compiler. Empty until Pending Work item 27 (Tier 1
  hand-WAT) begins. Kept forever post-first-light as the
  reference image against which future Wasm targets validate.
- `first-light.sh` — the fixed-point test harness. Runs the full
  loop: assemble inka.wat → validate → compile Inka's own source
  through it → diff. Empty diff means first-light.

See `docs/specs/simulations/Hβ-bootstrap.md` for the hand-WAT
walkthrough + conventions. See `ROADMAP.md` for the bootstrap
critical path.

**Hand-WAT is NOT deleted post-first-light** (unlike disposable
Rust/C translators would be). It IS the reference soundness
artifact. Every future Wasm target / engine / runtime is
validated by running `first-light.sh` against it.
```

**`bootstrap/first-light.sh` content (exact):**

```bash
#!/usr/bin/env bash
# bootstrap/first-light.sh — the fixed-point test
#
# Empty diff at the end == first-light. Tag the commit.
# Hand-WAT preserved forever.

set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
WAT="$ROOT/bootstrap/inka.wat"
WASM="$ROOT/bootstrap/inka.wasm"

if [[ ! -s "$WAT" ]]; then
  echo "bootstrap/inka.wat is empty or missing — hand-WAT not yet started." >&2
  echo "See docs/specs/simulations/Hβ-bootstrap.md + ROADMAP.md." >&2
  exit 1
fi

# Assemble and validate
wat2wasm "$WAT" -o "$WASM"
wasm-validate "$WASM"

# Compile Inka's source through the hand-WAT image
cat "$ROOT"/src/*.nx "$ROOT"/lib/**/*.nx \
  | wasmtime run "$WASM" > "$ROOT/bootstrap/inka2.wat"

# Fixed-point check
if diff -q "$WAT" "$ROOT/bootstrap/inka2.wat" > /dev/null; then
  echo "✓ first-light: hand-WAT is byte-identical to self-compiled WAT."
  echo "  Hand-WAT preserved as reference artifact."
  exit 0
else
  echo "✗ first-light FAILED: diff non-empty."
  echo "  Inspect: diff $WAT $ROOT/bootstrap/inka2.wat" >&2
  exit 2
fi
```

### 4.5 docs/ reshape

```
mv docs/rebuild/              → docs/specs/
mv docs/specs/00-Graph.md → docs/specs/00-graph.md  (NS-naming 1.2)
# Rewrite title + content of 00-graph.md to use "Graph" throughout
# (NS-naming.md rewrite rules apply).

rm docs/SYNTHESIS_CROSSWALK.md  (NS-naming 1.6)
```

### 4.6 Import-path rewrite across all moved .nx files

**Pattern:** every `import compiler/X` → `import X` (project-local to src/).
**Pattern:** every `import runtime/X` → `import lib/runtime/X` (now in lib/).
**Pattern:** `import dsp/X` → `import lib/dsp/X`.
**Pattern:** `import ml/X` → `import lib/ml/X`.
**Pattern:** `import std/prelude` → `import lib/prelude`.
**Pattern:** `import std/test` → `import lib/test`.
**Pattern:** `import std/types` → remove (merged into prelude); any users refer to `lib/prelude` now.
**Pattern:** `import compiler/types` (from within compiler) → `import types`.
**Pattern:** `import compiler/graph` → `import graph`. etc.

**Resolution rule:** within `src/`, imports that start with no directory prefix resolve project-local (to `src/<name>.nx`). Imports prefixed with `lib/` resolve to `lib/<path>.nx`. Explicit is better than implicit for cross-tree imports.

### 4.7 `.gitignore` additions

```
# Inka project cache (per-project + IC cache)
.inka/
bootstrap/inka.wasm
bootstrap/inka2.wat
```

### 4.8 Every doc reference updates

Every `.md` file referencing `std/compiler/`, `std/runtime/`, `std/dsp/`, `std/ml/`, `std/prelude.nx`, `std/test.nx`, `std/types.nx`, `docs/rebuild/`, `.nx` gets path-updated in the restructure commit. Files affected (per NS-naming.md §6 commit H, now absorbed into restructure):

- `docs/DESIGN.md` — every Ch 10 scenario, every file-reference.
- `docs/INSIGHTS.md` — every file-reference.
- `ROADMAP.md` — the canonical roadmap's future sections.
- `docs/SYNTAX.md` — every file-reference.
- `CLAUDE.md` — the File Map section + Session Zero references.
- `README.md` — the Repository layout (gets completely rewritten to reflect new shape).
- `docs/errors/README.md` — any file references.
- `docs/specs/00-11/*` — each spec's cross-references.
- `docs/specs/simulations/*` — each walkthrough's cross-references.
- `docs/traces/a-day.md` — every path reference.
- `tools/drift-patterns.tsv` — path-based patterns updated.
- Memory files at `~/.claude/projects/-home-suds-Projects-inka/memory/`:
  - `MEMORY.md` index
  - `project_canonical_docs.md` — path refs
  - `project_extension_ka.md` — RENAME to `project_extension_nx.md` + rewrite
  - `project_mentl_voice_reframe.md` — path refs
  - Every other memory with path refs

### 4.9 README's Repository layout rewrite

The README's current Repository layout section (already shown once) gets replaced with the six-directory template as the canonical Inka-project shape. Explicit statement: "every Inka project follows this template; subset as needed for simpler projects."

---

## 5. Post-edit audit command

```
bash ~/Projects/inka/tools/drift-audit.sh
```

The audit checks for:
- Residual `std/compiler/`, `std/runtime/`, `std/dsp/`, `std/ml/` path references in any `.md` or `.nx` file.
- Residual `docs/rebuild/` references.
- Residual `.nx` extension references (post extension migration).
- Residual `import compiler/X` patterns (should be `import X` project-local or `import lib/...`).
- Presence of `bootstrap/README.md` and `bootstrap/first-light.sh`.
- Presence of all 9 `lib/tutorial/*.nx` stubs.
- Absence of `docs/SYNTHESIS_CROSSWALK.md`.
- Absence of `std/` directory (fully migrated).

**Exit 0 required** or restructure commit doesn't land.

**New drift patterns added to `tools/drift-patterns.tsv`:**
- `\bstd/compiler/` → flags residual compiler path
- `\bstd/runtime/` → flags residual runtime path
- `\bstd/dsp/`, `\bstd/ml/` → flags residual example paths
- `\bdocs/rebuild/` → flags residual archaeology directory name
- `\.nx\b` → flags residual extension (fires late in sweep; may false-positive during simplification transition)
- `import compiler/` → flags old import prefix

---

## 6. Landing discipline

**This walkthrough lands as a SINGLE FOCUSED COMMIT** (item 17'), not split across "restructure-part-1 / restructure-part-2." Reasoning:

- Every import path changes in the same sweep; partial commits have broken import states.
- Doc updates ride through the commit so no documentation references stale paths.
- Drift-audit clean at the single commit's close verifies completeness.

**Ordering within the commit** (logical, though executed as one unit):
1. Update import-path resolver rules (if any code changes in `driver.nx`/`pipeline.nx` are needed for project-local resolution).
2. Move files per §4.1, §4.2.
3. Create new directories per §4.3, §4.4, §4.5.
4. Merge `std/types.nx` into `lib/prelude.nx`.
5. Rewrite every import across all `.nx` files.
6. Delete empty directories (`std/`, `docs/rebuild/`) + `docs/SYNTHESIS_CROSSWALK.md`.
7. Write `bootstrap/README.md` + `bootstrap/first-light.sh`.
8. Write `lib/tutorial/*.nx` stubs.
9. Update all doc path references.
10. Update all memory file path references.
11. Update `.gitignore`.
12. Update `tools/drift-patterns.tsv` with new path patterns.
13. Rewrite `README.md`'s Repository layout section.
14. Run drift-audit; confirm exit 0.

**This walkthrough does NOT split into sub-handles.** NS-structure is one handle; it lands whole.

---

## 7. Dispatch

Same three options as NS-naming.md:

**Option A (dual-tier Sonnet implementer):** preferred for the mechanical bulk (file moves, import rewrites, doc-path updates).

**Option B (Opus-on-Opus):** preferred for the merge (`std/types.nx` → `lib/prelude.nx`) + the bootstrap README/script writing + tutorial stubs (where a subtle decision might surface).

**Option C (Opus inline, current session):** full restructure in session. Feasible but large; ~50+ file moves, ~200+ import rewrites, ~30+ doc updates. Likely Option A is more efficient.

**My recommendation:** Option A (inka-implementer Sonnet) for the bulk; spot-check commits during execution; any surprise triggers Opus intervention.

---

## 8. What closes when NS-structure lands

- Item 17' (structural migration) complete.
- Items 19, 20, 21, 22 (spec + walkthrough + trace + memory path updates) absorbed into the same commit.
- Items 12–16 (doc updates) mostly absorbed (the path-reference portions; content updates from NS-naming rename are already in).
- The compiler's repo IS the canonical Inka-project template.
- Users copying the template get a working `src/ main.nx` starter from `lib/tutorial/00-hello.nx`.
- Drift-audit gains six new path patterns permanently defending against regression.
- The "rebuild" archaeology is gone forever.

**Sub-handles split off:**

None. Every decision in this walkthrough is complete.

---

## 9. Riffle-back items (audit after NS-structure lands)

1. **Verify `inka new <project>` works.** Once item 17' commits, test `inka --with new_project(name="testproj")` to confirm it clones `lib/tutorial/00-hello.nx` + creates `.inka/` + produces a compilable starter.
2. **Verify drift-audit catches accidental `std/` reintroduction.** Add a test that fails if any file creates `std/*`.
3. **Verify `lib/tutorial/` stubs actually compile.** Every stub file, even empty of curriculum content, must type-check against `lib/prelude` — they're compile-targets for regression testing even pre-curriculum.
4. **Audit the `Repository layout` section in README.md for clarity.** First-read audience: do they understand what each directory does in <30 seconds? Iterate if not.
5. **Per-user `~/.inka/handlers/` overlay substrate** — Decisions Ledger named this but no implementation yet. After restructure lands, it can be added incrementally in the Package-handler post-first-light work (item 41-ish).

---

## 10. Closing

NS-structure takes the current `std/`-as-dumping-ground tree and shapes it into the six-directory canonical form: compiler in `src/`, stdlib in `lib/` (including DSP + ML library modules + Mentl's tutorial curriculum), docs in `docs/`, hand-WAT in `bootstrap/`, scripts in `tools/`, plus root-level markdown + licenses. Every directory earns its keep; none exist for convention's sake. Four of the six (`tools/` + `docs/` partial + the 51-item PLAN + eventually others) dissolve post-first-light; the interim six-directory shape is the explicit pre-first-light template.

**The repo's shape IS the canonical Inka-project template.** When a new Inka developer creates a project, they start from this shape (or a minimal subset). The medium's thesis imprints on the filesystem: no frameworks, no test directory, no manifest files, no examples directory — just source, library, and Mentl.

**One walkthrough, one commit, one Inka-native repository shape.**
