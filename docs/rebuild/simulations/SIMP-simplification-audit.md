# SIMP — Simplification-audit discipline walkthrough

> **Status:** `[PENDING]`. Defines the simplification-pass methodology: what gets audited, how to audit, what counts as "pass," and what the executor does when a site fails. Gates Pending Work item 11 (simplification execution). After this walkthrough closes, item 11 has a prescriptive method — no design left, only mechanical application.

*The simplification audit is Inka's discipline self-applied. Every site in every `.nx` file asked the eight interrogations + screened against the nine drift modes. The output is the most residue-form Inka code possible — the compiler that emerges is Inka-native before Mentl ever audits it.*

---

## 0. Framing — why simplification is substrate work

The cascade landed substrate across the γ cascade + Phase II first cluster. The compiler's own source WAS written under cascade discipline but accumulated fluency drift over ~500 commits — not because discipline failed, but because every author (including me, Claude) reaches for familiar patterns unless named drift modes are running in real-time audit.

**The simplification audit is the whole-codebase application of the eight interrogations + nine drift modes.** Every top-level declaration, every function body, every match arm, every `|>` chain, every effect invocation is asked: *does the graph already know this? does a handler already project this? which verb draws this? what row already gates this? what ownership/refinement/gradient/Reason applies?* — and the nine drift modes screened against the answer.

**Impact:** 10-20% source-line reduction + equivalent 30-60% reduction in hand-WAT downstream (every line deleted in `.nx` saves 3-5 lines of WAT). **This is exponential cost-reduction before bootstrap.**

**What this walkthrough gates:**
- Item 11 — simplification audit execution across `src/` + `lib/`.

**What this walkthrough does NOT cover:**
- Specific naming rules (NS-naming.md closed that).
- Directory structure (NS-structure.md closed that).
- Entry-handler substrate (EH-entry-handlers.md closed that).
- Determinism verification (DET-determinism-audit.md, item 8).

**Dependency:** NS-naming + NS-structure + EH must close before SIMP executes. Rationale: simplification rewrites at the site level; restructure rewrites at the path level; naming rewrites at the identifier level. If any of these three land AFTER simplification, call sites churn twice.

---

## 1. The audit methodology

### 1.1 Per-site discipline — ask the eight

For every non-trivial code site (function body, match arm, pipe chain stage, handler arm, effect declaration), apply the eight interrogations. The site PASSES if every applicable interrogation terminates on "the substrate already encodes this, and this code reads through it." The site FAILS if any interrogation returns "this code re-derives substrate content."

**The eight interrogations** (from CLAUDE.md, canonical form):

1. **Graph?** What handle/edge/Reason in the Graph already encodes this? *(If the graph has it, don't re-derive it.)*
2. **Handler?** What installed handler already projects this? *(If a handler holds it, don't route around.)*
3. **Verb?** Which of `|>` / `<|` / `><` / `~>` / `<~` draws this topology? *(If a verb draws the shape, don't draw imperatively.)*
4. **Row?** What `+ - & ! Pure` constraint already gates this? *(If the algebra expresses it, don't hand-roll.)*
5. **Ownership?** What `own`/`ref` or `Consume`/`!Alloc`/`!Mutate` already proves this linearity/non-escape? *(If ownership proves it, don't write lifetime analysis.)*
6. **Refinement?** What predicate or `Verify` obligation already bounds this value? *(If a refinement encodes it, don't add a runtime check.)*
7. **Gradient?** What annotation would unlock this as a compile-time capability? *(If the gradient has a step for it, don't hand-encode the capability.)*
8. **Reason?** What edge should this decision leave so the Why Engine can walk back? *(If a later reader will ask "why did this bind to that?", write the Reason now.)*

### 1.2 Per-site screen — the nine drift modes

For every site, scan for each of the nine named drift modes:

1. **Rust vtable (closure-as-vtable)** — any code treating closure-captured data as a method dispatch table. Recognition: separate `vtable` / `dispatch` / `table of functions` structures.
2. **Scheme env frame (scope-as-frame-stack)** — any code manually maintaining a frame stack instead of using `env_scope_enter` / `env_scope_exit` effects. Recognition: explicit `push_frame` / `pop_frame` / frame-list manipulation.
3. **Python dict (string-keyed sets for structured things)** — any `List<(String, Value)>` where an ADT would serve. Recognition: string-keyed lookups on what should be variant dispatch.
4. **Haskell monad transformer (handler chain as monad transformer)** — any code treating `~>` as monad composition needing explicit lifts. Recognition: `lift` functions, manual bind-chains simulating transformers.
5. **C calling convention (separate `__closure` / `__ev` / `__state`)** — any function with separate environment + evidence + state parameters instead of one unified closure record. Recognition: multiple state-like parameters threaded through every call.
6. **Primitive-type-special-case** — any ADT variant hardcoded as "special" outside the canonical nullary-sentinel or fielded-heap paths. Recognition: `if x == 0 { primitive case } else { regular case }`-style dispatches.
7. **Parallel-arrays-instead-of-record** — any `(List<A>, List<B>, List<C>, List<D>)` where `(a[i], b[i], c[i], d[i])` are semantically one record. Recognition: multiple parallel lists indexed by the same position.
8. **String-keyed-when-structured / int-coded-when-ADT** — any `mode == 0 / mode == 1 / mode == 2` dispatch, any `kind_str == "foo"` branching. Recognition: scalar equality dispatches that should be variant matches.
9. **Deferred-by-omission** — any comment mentioning "for now," "until later," "TODO," "placeholder," or any substrate-cleanup left for a future commit. Recognition: those literal strings, or semantic incompleteness in a claimed-complete handle.

### 1.3 Bug classes (CLAUDE.md operational essentials)

In addition to the nine, every site screened for:

- **`_ => <fabricated>`** in match arms over load-bearing ADTs (Ty, NodeBody, LowExpr, EffRow, Reason, EntryHandlerInvocation, etc.). Safe: `_ => ()`, `_ => 0`, `_ => identity_preserve_value`, `_ => type_mismatch(...)`. Dangerous: `_ => Forall([], TVar(handle))`, `_ => "Pure"`, `_ => FakeConstructor(...)`.
- **`acc ++ [x]` in loops** — O(N²) allocation; replace with buffer-counter substrate.
- **`if str_eq(a, b) == 1`** — post-Ω.2 deprecated; replace with `if str_eq(a, b) { ... }`.
- **Flat-array list ops in Snoc-tree paths** (`list[i]` in a loop) — use `list_to_flat` at hot-path entrances.
- **`println` inside `report(...)` handler arms** — corrupts WAT stdout.
- **Bare `==` on strings** — use `str_eq(a, b)`.

---

## 2. The execution method — sweep order

Simplification executes across the full `src/` + `lib/` tree. Single-pass-per-file is insufficient; multiple passes compound.

**Pass ordering** (each pass over the whole tree):

### Pass 1 — Naming sweep (rides NS-naming)

Applies NS-naming.md's rewrite rules mechanically:
- `SubstGraph → Graph` ADT rename
- `module_fn()` → `module.fn()` or selective-import bare calls
- `HostClock → Clock`, `IterativeContext → row constraint`
- `lexer.nx → lex.nx`, `parser.nx → parse.nx` (files renamed; imports follow)

**Exit condition:** drift-audit with NS-naming patterns exits 0.

### Pass 2 — Drift-mode screen (per-file)

For each file in `src/` + `lib/`:
- Read the file.
- Screen every site for drift modes 1-9.
- For each hit: rewrite in-place OR name the residue as a named follow-up (see §3).

**Exit condition:** drift-audit with drift-mode patterns exits 0.

### Pass 3 — Bug-class screen

For each file:
- Grep for each bug-class pattern (`_ => <fabricated>`, `acc ++ [x]`, `str_eq(a, b) == 1`, etc.).
- Rewrite each hit.

**Exit condition:** drift-audit with bug-class patterns exits 0.

### Pass 4 — Eight-interrogation audit (semantic, slower)

This is the deepest pass. For each non-trivial site:
- Ask each applicable interrogation.
- If any says "graph/handler/verb/row/ownership/refinement/gradient/Reason already encodes this," rewrite to read-through or eliminate the site.

Unlike passes 1-3, this pass CANNOT be fully automated by drift-audit. It requires reading + reasoning per site. **Pass 4 IS the cost-reduction pass.**

**Exit condition:** every module re-audited; no site admits a primitive-redundancy rewrite that hasn't been applied.

### Pass 5 — Docstring harmonization

Per NS-naming.md decision 1.5: every module's top gets the canonical docstring (purpose, kernel primitive served, Mentl tentacle projected, invariants).

**Exit condition:** every `src/*.nx` and `lib/**/*.nx` has the canonical docstring.

---

## 3. What happens when a site fails

When Pass 4 (eight-interrogation audit) finds a site that fails: **rewrite in-place, don't flag.** Per CLAUDE.md protocol `protocol_transform_dont_flag`: *"writing a flag costs as much as doing the fix; do the fix."*

**Exception:** if the rewrite requires substrate that doesn't exist yet (e.g., a new graph-op or a new handler), name the residue as a **named follow-up handle** in PLAN.md's Pending Work and leave the current site with a minimal comment pointing to the follow-up. Do NOT leave the site with `// TODO: simplify later` — that's drift mode 9. The minimum discipline is "either fix now or name the sub-handle that will fix later."

**Sub-handles that might surface during Pass 4** (tracked during execution, not predicted):
- Surprise convergences: three modules with similar shapes that earn an abstraction (rule of three per CLAUDE.md Anchor 7.4). Record the third-instance site; land the factoring in the next handle that benefits.
- Substrate gaps: if Pass 4 surfaces that a primitive-level affordance is missing (e.g., "the graph needs a new op"), that's cascade-level work, not simplification; name it as a peer handle in PLAN.md.

---

## 4. Measurement — what counts as "done"

**Quantitative metrics** tracked during execution:

- **Source-line count reduction.** Expected: 10-20% on `src/`, higher on `lib/runtime/`. Measured as `wc -l` diff before/after.
- **`fn` declaration count reduction.** Expected: same count (functions aren't deleted, just renamed); but unique-name length reduction. Measured as sum of `fn` name lengths.
- **Match-arm count changes.** Simplification may consolidate arms if drift mode 7 (parallel-arrays) collapsed a dispatch. Measured by comparing `match \w+ \{` blocks' arm counts.
- **Drift-audit exit code = 0 on every file** after each pass.
- **Self-simulation still passes** (item 23 / SSA audit — every module still typechecks through its own inference walk).

**Qualitative gate:** every module's top docstring names the kernel primitive it serves; if a module resists fitting one of the eight primitives, that's a substrate-level concern (module is mis-factored) worth surfacing to Morgan.

---

## 5. The eight interrogations, applied TO this walkthrough

### Graph?

The plan-level graph (Pending Work items) already encodes simplification's dependency on NS-naming + NS-structure + EH. Nothing re-derived.

### Handler?

Drift-audit.sh IS the handler that projects "did this site pass?" into CI-visible output. No new handler needed; extend `tools/drift-patterns.tsv` with per-pass patterns.

### Verb?

Sweep passes are sequential `|>` composition: `pass_1 |> pass_2 |> pass_3 |> pass_4 |> pass_5`. Each pass reads the tree's current state and produces the next.

### Row?

Simplification execution's row: `Filesystem + Alloc + IO + Diagnostic`. No new effect introduced; standard pipeline.

### Ownership?

N/A at the pass level. (Within each rewrite, ownership discipline applies to the rewritten code.)

### Refinement?

The "site pass/fail" predicate is binary; no refinement needed at the methodology level.

### Gradient?

Post-simplification, the `src/` + `lib/` code is closer to the gradient's residue form. Each annotation the compiler-self-author added is one gradient step that Mentl's Teach tentacle could have suggested automatically. **This is the gradient validating the code.**

### Reason?

Every rewrite should leave a Reason in the graph if the rewrite is applied via a source edit (git history carries the "why" at the commit level; in-code Reason edges matter post-first-light when the compiler re-infers itself).

---

## 6. Forbidden-pattern list

- **Drift 9 (deferred-by-omission):** the simplification audit MUST complete in one sweep-sequence; splitting into "simplify phase 1 / simplify phase 2" across commits is drift mode 9.
- **Drift 6 (primitive-type-special-case):** no file is exempt from the audit. `src/types.nx` is subject to the same eight interrogations as any other module.
- **`// TODO: simplify`:** forbidden residue. Fix now or split into named sub-handle; nothing else.

---

## 7. Sequencing within item 11 — concrete commit plan

Item 11's execution lands as a sequence of commits (each auditable + revertable):

**Commit 11.A — Pass 1 naming sweep** (mechanical; largest diff):
- `SubstGraph → Graph`
- Module function prefix → dot-access (or selective import for hot paths)
- `HostClock → Clock`, `IterativeContext` dissolution
- File renames
- Drift-audit exits 0 against NS-naming patterns.

**Commit 11.B — Pass 2 drift-mode screen**:
- Per-file drift-mode-1-through-9 rewrites.
- Drift-audit exits 0 against all nine modes.

**Commit 11.C — Pass 3 bug-class screen**:
- `acc ++ [x]` loop rewrites.
- `str_eq(a, b) == 1` → `if str_eq(a, b)`.
- `_ => <fabricated>` → explicit enumeration.
- Drift-audit exits 0 against bug-class patterns.

**Commit 11.D — Pass 4 eight-interrogation audit** (largest semantic pass):
- Per-site audits + rewrites.
- Diff review: every rewrite justified by "this interrogation returned a substrate that the old code re-derived."
- Drift-audit clean.
- Self-simulation passes.

**Commit 11.E — Pass 5 docstring harmonization**:
- Every module's top matches canonical template.
- Drift-audit adds a pattern for missing-canonical-docstring; exits 0.

**Commit 11.F — Cleanup**:
- Delete `docs/SYNTHESIS_CROSSWALK.md`.
- Remove any stale pointers to it.
- Final drift-audit run.

**Between commits:** `bash tools/drift-audit.sh` + test compilation (once a simple build step exists) must pass. **No commit lands with non-zero drift audit.**

---

## 8. Dispatch

**Option A (dual-tier Sonnet):** preferred for commits 11.A + 11.B + 11.C + 11.F (mechanical sweeps). The inka-implementer system prompt already carries the drift-audit discipline.

**Option B (Opus-on-Opus):** preferred for commit 11.D (semantic audit — where judgment calls surface).

**Option C (Opus inline):** full sequence in-session. Possible but large; probably Option A for mechanical passes + Option B for Pass 4 is the most efficient distribution.

**Recommendation:** Option A for 11.A/B/C/F; Option B for 11.D; Option C for small surprises.

---

## 9. What closes when SIMP's method lands

- Item 11 (simplification audit execution) has prescriptive method.
- `tools/drift-patterns.tsv` extended with SIMP's patterns.
- Post-SIMP, `src/` + `lib/` are in residue form; the hand-WAT transcription has 10-20% less source to handle.
- Pass 4's findings produce a list of "surfaced convergences" tracked in PLAN.md for future factoring.

**Sub-handles split off:**

None in this walkthrough; Pass 4 may surface some during execution, each tracked as a named follow-up in PLAN.md.

---

## 10. Riffle-back after SIMP

1. Re-audit cascade walkthroughs (H1-H6, HB, etc.) to verify the simplification's rewrites preserve the walkthroughs' stated invariants. If any walkthrough's substrate assumption no longer matches post-SIMP code, addendum required.
2. Verify drift-audit performance remains sub-second over the simplified tree.
3. Check tutorial stubs (`lib/tutorial/*.nx`) still compile against the simplified `lib/prelude.nx`.
4. Run self-simulation (item 23) immediately after SIMP to confirm no `NErrorHole` survives to LIR.

---

## 11. Closing

SIMP is Inka's discipline running over Inka. Every line that survives the sweeps passed the eight interrogations + nine drift modes + bug-class screens. Every line that didn't survive got rewritten. Post-SIMP, the compiler's own source IS the reference Inka-native form — and the hand-WAT that comes next has the minimum possible surface to transcribe.

**One walkthrough, a sequence of 6 commits, Inka's discipline self-applied.**
