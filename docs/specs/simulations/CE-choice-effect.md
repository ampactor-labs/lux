# CE — Choice Effect · canonical multi-shot user effect

> **Status:** `[DRAFT 2026-04-23]`. MSR Edit 2 walkthrough. Designs
> the canonical user-visible multi-shot effect (`Choice` with one
> op, `choose`), its two canonical handlers (`pick_first`,
> `backtrack`), and its interaction with the trail rollback
> substrate primitive #1 + #2 already provide. Opens the door to
> SAT / CSP / logic-prog / probabilistic-programming domain
> crucibles per MS2 §2.1 + §2.4.
>
> *Claim in one sentence:* **Choice is MultiShot's minimum user
> surface — one effect, one op, one type parameter inferred per call
> site — and its two canonical handlers (`pick_first` OneShot-
> terminal, `backtrack` MultiShot-try-each) prove that every
> industry search/backtracking framework is a handler stack on this
> one effect.**

---

## 0. Framing — why `Choice` is the canonical MS effect

### 0.1 What makes `Choice` canonical

Per MS2 §2.1, every SAT / CSP / backtracking-parser / logic-prog
framework is `perform choose(...)` composed with a handler that
decides how to resume. The kernel primitive is #2 (handlers with
typed resume discipline); the substrate is trail-based rollback
(primitive #1); `Choice` is the minimum user-visible *surface* over
both. Every domain MS2 §2.1–§2.4 names reduces to `Choice` +
a domain-specific handler + (optionally) `Verify`:

- **N-queens, sudoku** — `Choice` + `backtrack`.
- **DPLL-style SAT** — `Choice` + variable-assignment handler +
  conflict-driven-learning as handler state.
- **Backtracking parsers (Parsec, Megaparsec)** — `Choice`
  + parser-state trail + `backtrack`.
- **CLP(FD) / CSP** — `Choice` + refinement types (primitive #6)
  + `Verify` discharge.
- **Prolog** — `Choice` for resolution + graph `unify` (primitive
  #1) + `cut` as OneShot `Abort` forecloses backtracking.
- **miniKanren** — `Choice` + graph unify. ~20 lines.
- **Probabilistic sampling** — `Choice` + weighted-resume handler
  (importance sampling, MCMC) per MS2 §2.2.

**One effect. One op. N domains.** The thesis of MS2 made
concrete.

### 0.2 Named domains this unlocks

When `Choice` lands + `H7` MS runtime emit closes, the following
crucibles become writable in ≤50 lines each (not exhaustive, per
MS2 §4.1):

| Crucible | Shape | Rough size |
|----------|-------|-----------|
| `crucible_search` — N-queens + sudoku | `Choice` + `backtrack` + `fail` | ~40 lines |
| `crucible_sat` — 3-SAT DPLL | `Choice` + `backtrack` + unit-propagation handler | ~120 lines |
| `crucible_parser` — backtracking combinators | `Choice` + `Fail` + parser-state trail | ~80 lines |
| `crucible_kanren` — relational programming | `Choice` + graph unify | ~60 lines |
| `crucible_sampling` — importance sampling | `Choice` + weighted resume + `Verify` | ~70 lines |

Each earns its own `CRU` entry when exercised. CE itself does NOT
ship the crucibles; CE ships the effect + the two handlers + the
tutorial exemplar.

### 0.3 What's in scope

- **§1** — `effect Choice` declaration.
- **§1** — `handler pick_first` (OneShot, picks first option, fail
  path performs Abort).
- **§1** — `handler backtrack` (MultiShot, tries each option,
  survives on first non-abort, trail-rolls losers).
- **§2** — Per-edit-site eight-interrogation table.
- **§3** — Forbidden-pattern enumeration per edit site — all nine
  drift modes (1–9) plus generalized fluency-taint checks for
  Scheme `amb` / `call/cc`, Haskell `MonadPlus`, miniKanren
  `conde`, Prolog `cut`, DPLL solver-framework idioms.
- **§4** — Literal substrate touch sites at file:line targets with
  the actual tokens to insert.
- **§5** — `lib/tutorial/02b-multishot.mn` (D.3) N-queens example.
- **§6** — Composition with other MS substrate (race, arena
  handlers, Synth).
- **§7** — Acceptance criteria.
- **§8** — Open questions (expected: zero).
- **§9** — Dispatch.
- **§10** — Closing.

### 0.4 What's out of scope

- **H7 MS runtime emit path.** Its own walkthrough. CE declares
  `choose` as `@resume=MultiShot`; execution at runtime waits for
  H7. Until H7 lands, `perform choose(...)` type-checks and
  row-algebras correctly, but runtime fork is undefined — which
  matches the MSR §3 phasing (β.2 CE can land before β.1 H7; MS
  *declaration* is type-level, MS *execution* is runtime).
- **`race` combinator.** MSR Edit 5; its own walkthrough territory
  (HC2 or CE-extension per MSR §3.Edit-5). CE composes with `race`
  but doesn't ship it.
- **Arena-aware MS handlers** (`replay_safe` / `fork_deny` /
  `fork_copy`). MSR Edit 4; AM walkthrough.
- **SAT / CSP / Prolog crucibles.** Each earns its own CRU entry
  and walkthrough.

---

## 1. The substrate — effect declaration + two canonical handlers

The complete CE landing is ONE file: `lib/runtime/search.mn`. It
adds one effect declaration, two handlers, and documentation. No
`types.mn` edit (halt-signal §4.0.1 below). No `parser.mn` edit.
No `infer.mn` edit. No `lower.mn` edit. No emit edit. CE is pure
declaration + handler composition over substrate primitives that
already exist.

### 1.1 Effect declaration — `Choice`

```mentl
// ═══ Choice — canonical multi-shot user effect ═════════════════════
// One op. Generic over the element type A (inferred per call site
// from the options list's type). @resume=MultiShot declares that
// the handler may resume the continuation multiple times, once per
// explored option; trail-based rollback (primitive #1) bounds each
// speculative resume. Primitive #2's typed resume discipline makes
// the multi-shot contract part of the op's signature — callers see
// at compile time that choose may fork.
//
// Bare, not parameterized in the H3.1 sense. Two choose call sites
// with different element types (List<Int> vs List<String>) are
// distinguished by the type system through HM inference on A; they
// are NOT distinct row entries. Contrast with Sample(44100) vs
// Sample(48000) — where the rate matters at row-subsumption time.
// For Choice, call sites are semantically identical regardless of
// A; only the element type flows.

effect Choice {
  choose(options: List<A>) -> A   @resume=MultiShot
}
```

### 1.2 Handler — `pick_first` (OneShot terminal)

```mentl
// ═══ pick_first — OneShot: first option wins, no backtracking ══════
// Terminal handler. On each choose call, resume with options[0] (the
// FIRST option) once and only once. If options is empty, perform
// Abort — the runtime contract matches the QA Q-B.3.2 decision
// (handler decides empty-list semantics; pick_first chooses Abort).
//
// No speculation, no rollback, no trail. Commit path. Useful as a
// deterministic default: "the first thing you suggested is the
// thing we ran." Also useful as a capability-stack outer: install
// pick_first outermost to guarantee "no more than one reality is
// explored at this boundary."
//
// Resume discipline: the ARM resumes once; the op is declared
// MultiShot, but pick_first's INSTALLATION narrows it to OneShot
// at this site. Primitive #2's @resume=Either pattern would
// formalize this; for CE's v1, pick_first is simply named
// OneShot-at-install and row subsumption at handler install lets
// it pass.

handler pick_first {
  choose(options) =>
    if len(options) == 0 { perform abort() }
    else { resume(options[0]) }
}
```

### 1.3 Handler — `backtrack` (MultiShot try-each)

```mentl
// ═══ backtrack — MultiShot: try each option, first non-Abort wins ══
// For each option, push a checkpoint, resume the continuation with
// that option, and either accept the outcome (commit; break out)
// or catch an Abort and try the next option (rollback the trail to
// the checkpoint). Empty list → propagate Abort (dead-end). First
// success commits; others never ran in the caller's observable
// state.
//
// The trail-rollback semantics are primitive #1's substrate —
// graph_push_checkpoint + graph_rollback, O(M) exact per spec 00.
// backtrack does NOT allocate per-fork state; it re-uses the one
// checkpoint-scoped trail buffer. Primitive #5 (ownership as
// effect): options is ref (borrowed, not consumed); each fork
// observes the same options list.
//
// Composition: typically installed with a Fail handler that
// converts dead-ends into the Abort that backtrack catches.
// Nothing in backtrack is Prolog-specific or DPLL-specific; it's
// the substrate primitive for every "try each alternative, commit
// the first that doesn't dead-end" pattern.

handler backtrack with Choice + GraphRead + GraphWrite {
  choose(options) => {
    fn try_each(i) =
      if i >= len(options) { perform abort() }
      else {
        let checkpoint = perform graph_push_checkpoint()
        perform try_with_abort_catch(
          fn () => resume(options[i]),
          fn () => { perform graph_rollback(checkpoint); try_each(i + 1) }
        )
      }
    try_each(0)
  }
}
```

*Note on try_with_abort_catch:* this is a tiny combinator over the
`Abort` effect — it installs a one-shot catch around an inner
computation. The runtime shape comes from primitive #2's one-shot
abort + handler install; the combinator is substrate-native, NOT a
try/catch/exception reach. If `try_with_abort_catch` isn't yet in
`lib/runtime/abort.mn`, it ships alongside CE as a peer (the `Fail`
/ `Abort` effect substrate is a prerequisite for `backtrack`; its
absence earns a sub-handle under CE).

**Halt-signal (§4.0.2):** if the `Abort` effect + `try_with_abort_catch`
combinator don't yet exist in `lib/runtime/`, backtrack can't
land cleanly. Surface the prerequisite as a peer handle; don't
inline an ad-hoc abort-catch inside `backtrack`.

---

## 2. Per-edit-site eight interrogations table

Every edit site passes all eight primitives before being
admissible. One line per primitive; the residue is the code.

### 2.1 `effect Choice { choose(options: List<A>) -> A @resume=MultiShot }`

| # | Primitive | Interrogation answer |
|---|-----------|---------------------|
| 1 | **Graph?** | No graph extension. Effect registration adds one env entry with `EffectOpScheme("Choice")` metadata — existing H3 substrate. |
| 2 | **Handler?** | No handler at declaration; handlers ship separately below. Resume discipline on the op is `@resume=MultiShot` — primitive-#2's substrate carries this; inference + row algebra enforce compatibility at install time. |
| 3 | **Verb?** | No verb at the declaration; `~>` attaches at handler install, not at op-declaration. |
| 4 | **Row?** | Row `Choice` enters the algebra as `ENamed("Choice")` (a string inside the existing EffName ADT — substrate reality; see §4.0.1 halt-signal). `with Choice` / `with !Choice` / `with Choice - Fail` compose through the existing Boolean algebra with zero extension. |
| 5 | **Ownership?** | `options: List<A>` is implicitly `ref` (borrowed; function doesn't consume). Return `A` is ownership-polymorphic (inherits the option's ownership marker). No Consume effect at the op surface. |
| 6 | **Refinement?** | Not required for declaration. Empty-list detection is handler-decided (Q-B.3.2). Optional user opt-in at call site via `NonEmptyList<A>` refinement — orthogonal. |
| 7 | **Gradient?** | Declaring `Choice` unlocks `CSearch` capability for user code that installs a handler on it. Mentl's Teach tentacle will suggest `~> backtrack` when the user has a `choose` site with no installed handler — surfaced post-H5 Mentl's arms. |
| 8 | **Reason?** | Effect declaration carries `Declared("effect Choice at <span>")` Reason on the env entry. Every `perform choose(...)` site carries an `OpConstraint("choose", <site_reason>, <type_reason>)` Reason on its result type — existing infer.mn substrate. |

### 2.2 `handler pick_first { choose(options) => … }`

| # | Primitive | Interrogation answer |
|---|-----------|---------------------|
| 1 | **Graph?** | Handler declaration adds one env entry for the handler name + effect name — existing registration substrate. |
| 2 | **Handler?** | THIS IS a handler. Resume discipline at this installation: the arm resumes ONCE with `options[0]`. At handler install under `~>`, this narrows the op's declared MultiShot to OneShot-at-this-site. Row subsumption permits narrowing (MultiShot-capable op with OneShot-discipline install — the inverse narrowing (OneShot-declared op with MultiShot-discipline install) is the forbidden case). |
| 3 | **Verb?** | `~> pick_first` installs. No verb inside the arm. |
| 4 | **Row?** | Handler claims `Choice + Abort` from its body's row (consumes `Choice`; may perform `Abort` on empty-options path). |
| 5 | **Ownership?** | `options: ref List<A>` — borrowed. `options[0]` indexing takes a `ref A`; `resume(options[0])` passes it to the continuation as `ref A` (or via copy for non-`own` types). |
| 6 | **Refinement?** | Empty-list check via `len(options) == 0` — runtime; not a refinement obligation. |
| 7 | **Gradient?** | Installing `pick_first` outermost unlocks `CDeterministic` (one reality explored only). Compatible with `!Alloc` context because pick_first never forks (no closure allocation at resume time). |
| 8 | **Reason?** | Each arm's resume records `Resume("pick_first::choose", Fresh(<slot>))` in the continuation's graph bindings — existing handler-arm substrate. |

### 2.3 `handler backtrack { choose(options) => try_each(0) }`

| # | Primitive | Interrogation answer |
|---|-----------|---------------------|
| 1 | **Graph?** | Uses existing `graph_push_checkpoint` + `graph_rollback` effects declared in `src/types.mn` and implemented in `src/graph.mn`. O(M) rollback per spec 00. No new graph substrate. |
| 2 | **Handler?** | THIS IS a MultiShot-executing handler. Resume arm is invoked up to `len(options)` times; each invocation re-enters the continuation with a different option value. Primitive #2's substrate — H7 MS runtime emit lands this at wasm level; at source level `resume(options[i])` is the typed-multi-shot form. |
| 3 | **Verb?** | `~> backtrack` installs. Inside the arm, recursive `try_each(i+1)` is tail-recursion across options — an implicit sequence, no verb. |
| 4 | **Row?** | Handler claims `Choice` from body; declares `with Choice + GraphRead + GraphWrite + Abort` — the three graph effects + the abort surface. The row algebra proves the handler's declared row ⊇ the handled op's row at install. |
| 5 | **Ownership?** | `options: ref` — borrowed; each fork sees the same list. The checkpoint (`Int`) is `Pure` — just an index into the trail buffer; no allocation. Primitive #5: replay-safe by construction (no per-fork captures allocated in this handler itself; H7 may add allocation for the continuation closure at emit time, which requires `replay_safe` / `fork_deny` / `fork_copy` arena discipline per MSR Edit 4). |
| 6 | **Refinement?** | Empty-list → Abort (runtime), matching Q-B.3.2. No refinement obligation at this level. |
| 7 | **Gradient?** | Installing `backtrack` unlocks `CBacktracking` capability. Compatible with `!Alloc` ONLY under `replay_safe` discipline (MSR Edit 4). Under `!Alloc + fork_copy`, compile-time error. Under `!Alloc + replay_safe`, admissible; replay cost is M per resume. |
| 8 | **Reason?** | Each `resume(options[i])` records `Resume("backtrack::choose::attempt_" + i, Located(<option_site>, <parent_reason>))`. Checkpoint / rollback record `Speculate(checkpoint_handle, Fresh(<trail_len>))` on the trail. First commit preserves its Reason chain; rolled-back forks' Reasons are trail-erased per primitive #1's substrate. |

### 2.4 N-queens example (tutorial 02b)

| # | Primitive | Interrogation answer (for the tutorial's `place_row` fn) |
|---|-----------|---------------------|
| 1 | **Graph?** | Board handle (primitive-#1 owned by the `Board` record-shape); each recursive `place_row` call returns an updated `Board`. No graph query inside the example (deliberate: keep tutorial simple). |
| 2 | **Handler?** | Tutorial shows `perform choose(...)` + `~> backtrack ~> first_success` composition. Learner SEES the handler chain; it's not hidden behind a helper (Q-D.3.1). |
| 3 | **Verb?** | `~>` attaches both handlers. No other verb — keep the tutorial minimal. |
| 4 | **Row?** | `place_row` declares `with Choice + Abort`. Handler stack consumes both. Outermost caller has `with Pure` (solution found) or aborts (no solution). |
| 5 | **Ownership?** | `Board` passed by value (copy-on-update in tutorial's representation). Each fork's board is its own; commits persist. |
| 6 | **Refinement?** | `row: Int where 0 <= self && self < 8` optional — keep tutorial without refinements to avoid scope creep. Note in comment that refinements tighten this. |
| 7 | **Gradient?** | Example demonstrates the gradient step "typed MultiShot op unlocks backtracking search without any loop/recursion-builder framework." Mentl's Teach tentacle, when MV.2 ships, would narrate over this file. |
| 8 | **Reason?** | Each `choose` site's Reason + each `safe` check's Reason walks back to `OpConstraint("choose", ...)` then `VarLookup("row", ...)`, etc. Visible via `mentl query` once MV.2 lands. |

---

## 3. Forbidden patterns per edit site

*Every drift mode 1–9 from CLAUDE.md named explicitly for each
site. Plus generalized fluency-taint check for language-specific
vocabulary that must NOT sneak in.*

### 3.1 At the `Choice` declaration site (`lib/runtime/search.mn:<effect_line>`)

| # | Drift | Forbidden shape |
|---|-------|-----------------|
| 1 | **Rust vtable** | NO "dispatch table" for `choose` — it is an op declaration; primitive #2's evidence passing resolves at install time, not via a table. The word "vtable" appears in NO comment or variable name. |
| 2 | **Scheme env frame** | NO comment mentioning `call/cc`, `reset`, `shift`, "undelimited continuation." `choose` is a TYPED DELIMITED MS op; the delimitation is the enclosing handler's scope. |
| 3 | **Python dict / string-keyed** | Effect name `"Choice"` inside `ENamed("Choice")` is structured — it's a String inside a typed ADT variant, not a raw string key in a map. No op_name-to-handler dict. |
| 4 | **Haskell monad transformer** | NO `ChoiceT`, no `MonadPlus`, no `mplus`/`mzero` vocabulary. `Choice` is one effect on the Boolean algebra; `+` composes rows, not monads. |
| 5 | **C calling convention** | At declaration level, irrelevant — no emit code here. At H7 emit time (separate walkthrough), forbidden to emit `__closure` + `__ev` as separate i32 parameters; unified `__state` only. |
| 6 | **Primitive-type-special-case** | `Choice` is declared EXACTLY like `Iterate`, `Memory`, `Alloc`, `Pack`, `Unpack`. No compiler intrinsic; no special-case in EffName ADT (halt-signal §4.0.1); no hardcoded knowledge of `"Choice"` anywhere in `src/`. If an existing effect treats `Choice` as special, FLAG. |
| 7 | **Parallel-arrays-instead-of-record** | `options: List<A>` is ONE list. NOT `(option_values, option_weights, option_sources)` — if the caller needs multiple axes per option, they wrap in a record. |
| 8 | **String-keyed-when-structured** | The op's resume discipline is the **ADT** `ResumeDiscipline::MultiShot`, not `"multishot"` string. The `@resume=MultiShot` syntax already gives us this — verify the parser produces the ADT, not a string. |
| 9 | **Deferred-by-omission** | Declaration ships with BOTH handlers in the SAME FILE in the SAME COMMIT. If `pick_first` ships today and `backtrack` is "coming next commit" — that's drift 9. Land all three (effect + 2 handlers) or none. |

**Generalized fluency-taint check for the Choice declaration:**

| Foreign idiom | Mentl substrate | If the word comes to mind |
|---------------|----------------|---------------------------|
| Scheme `amb` | `Choice.choose` | STOP. Do not name a function, variable, or comment `amb`. Use `choose`. |
| Haskell `MonadPlus` | row `with Choice` | STOP. Never `MonadPlus`. Use "row entry `Choice`." |
| miniKanren `conde`, `disj`, `conj` | `choose([...])` over a list of candidate goals | STOP. Use `choose([goal_a, goal_b])` + explicit list construction. |
| Prolog `;` (disjunction) or clause database | `handler backtrack` composing resolution | STOP. Not comma-vs-semicolon syntax; typed effect + handler. |
| DPLL "decide level", "unit prop", "conflict clause" | Per-crucible handler state; not at the Choice effect level | STOP. `Choice` has zero DPLL vocabulary. DPLL belongs to its own crucible handler. |
| JS `Promise.any`, Rust `tokio::select!`, Go `select` | `~> race(...)` — MSR Edit 5 | STOP. Not concurrency vocabulary. `race` is a handler combinator over `Choice`. |

### 3.2 At `pick_first` handler site

| # | Drift | Forbidden shape |
|---|-------|-----------------|
| 1 | **Rust vtable** | No "pick_first is a struct with a choose method." The handler IS a closure + evidence; primitive #2's substrate. |
| 2 | **Scheme env frame** | No stack-walking the "calling context"; the continuation is delimited; handler scope IS the delimitation. |
| 3 | **Python dict / string-keyed** | Effect arm dispatch is `$op_choose` (function-pointer-field on closure struct, per DESIGN γ crystallization #8 + H1 evidence reification) — NOT a string-to-fn-ptr map. |
| 4 | **Haskell monad transformer** | No `lift`, no `runFirst`. Just `handler pick_first { choose(options) => ... }`. |
| 5 | **C calling convention** | At source level: no concern. At emit time: single `__state` parameter. |
| 6 | **Primitive-type-special-case** | `pick_first` is declared exactly like any handler in `lib/runtime/binary.mn` (e.g., `buffer_packer`). No compiler special-case. |
| 7 | **Parallel-arrays-instead-of-record** | `options` accessed by single `options[0]` index — not (options_values, options_metadata). |
| 8 | **String-keyed-when-structured** | The empty check is `len(options) == 0`, an integer comparison. NOT `if options == "empty"` or `if tag_of(options) == "empty_list_tag"` — structured. |
| 9 | **Deferred-by-omission** | Empty-list path performs `abort()`, a proper op — not `// TODO: handle empty` comment. |

### 3.3 At `backtrack` handler site

| # | Drift | Forbidden shape |
|---|-------|-----------------|
| 1 | **Rust vtable** | No "BacktrackVTable." Resume-per-option is primitive #2's substrate; H7 emit path (when it lands) uses closure evidence fields, not tables. |
| 2 | **Scheme env frame** | No `reset` / `shift` vocabulary. Checkpoint/rollback operates on the trail buffer (primitive #1), not on a control-frame stack. |
| 3 | **Python dict / string-keyed** | Trail entries are `Mutation` ADT variants (per types.mn), not `(string_key, old_value)` tuples. |
| 4 | **Haskell monad transformer** | No `BacktrackT`, no `>>=` for composition. Just a recursive `try_each` over option indices + the substrate's `graph_push_checkpoint` / `graph_rollback`. |
| 5 | **C calling convention** | At emit time (H7), forbidden to pass checkpoint as a separate i32 parameter apart from `__state`; single `__state` only. |
| 6 | **Primitive-type-special-case** | `backtrack` is declared exactly like `collector` in prelude.mn — `handler <name> { op(...) => ... }`. No compiler intrinsic. |
| 7 | **Parallel-arrays-instead-of-record** | If `backtrack` ever needs per-fork metadata (e.g., "which fork is this? what's its depth?"), wrap in a record `ForkInfo { depth: Int, parent: Int, ... }`. Never `(depths, parents, ...)` parallel lists. |
| 8 | **String-keyed-when-structured** | The checkpoint is an `Int` (trail length) — NOT `"checkpoint_<depth>"` string key. The trail itself is `List<Mutation>` — typed ADT throughout. |
| 9 | **Deferred-by-omission** | Rollback path is COMPLETE: `graph_rollback(checkpoint); try_each(i + 1)`. NOT "rollback; [TODO: handle partial resume elsewhere]." The handler either commits the whole fork or rolls the whole trail. |

**Generalized fluency-taint check for backtrack specifically:**

| Foreign idiom | Substrate answer |
|---------------|------------------|
| Prolog `cut` as a built-in of the handler | `cut` is a user-level `perform cut()` on an `Abort`-like effect the user composes WITH `backtrack`. It's NOT baked into `backtrack`. |
| Scheme `fail` as a special form | `fail()` / `abort()` is an Abort-effect op — primitive #2. Not a special form. |
| miniKanren infinite streams / lazy lists | `backtrack` is strict left-to-right. Streaming lazy enumeration is a DIFFERENT handler (`streaming_backtrack` — future; not in CE scope). |
| JS async generator + `for await` | `backtrack` is synchronous; primitive #2's MS is NOT async-await. If an op is Future-returning, it's a different effect entirely. |
| Rust `futures::stream::iter` / `tokio::select!` | Same — MS is not async. |

### 3.4 At the tutorial `lib/tutorial/02b-multishot.mn` site

| # | Drift | Forbidden shape |
|---|-------|-----------------|
| 9 | **Deferred-by-omission** | Tutorial ships complete — N-queens produces correct solutions for N=4 AND N=8. NOT "N=4 works; N=8 is an exercise for the reader." |
| 11 | **(bug-class) `acc ++ [x]` loop body** | CRITICAL — tutorial sets tone. Any accumulator pattern MUST use the buffer-counter substrate or `[x] ++ acc` (prepend-then-reverse). NEVER `acc ++ [x]` in a recursive call. |
| 30 | **(bug-class) for/while loop** | Tutorial uses RECURSION, not `for` / `while`. Iteration for loop composition is via `Iterate` effect handlers; for MS backtracking, recursion is the canonical form. |
| — | **Fluency-taint** | No Python `itertools.product`. No Haskell `do { x <- xs; ... }`. No Prolog-like syntactic tricks. The tutorial is INKA code — `perform choose`, `~> backtrack`, five verbs, eight primitives. |

---

## 4. Substrate touch sites — literal tokens at file:line

### 4.0 Halt-signal corrections to MSR source

**§4.0.1 `types.mn` does NOT need `Choice` added.**

MSR §3 Edit 2 says: *"Add `Choice` to `EffName` ADT (enumerate
alongside Alloc, IO, Network, etc.)"* — this misreads the
substrate. `src/types.mn:130-132` defines:

```mentl
type EffName
  = ENamed(String)
  | EParameterized(String, List)    // name + List<EffArg>
```

`Alloc`, `IO`, `Memory`, `Pack`, `Unpack`, `Iterate` are NOT
variants of `EffName`. They are effect NAMES declared via
`effect NAME { ops }` source blocks in their respective files;
the effect-name string `"Alloc"` lives inside `ENamed("Alloc")`
at runtime. Adding a third `EffName` variant `| EChoice(...)`
would be drift 6 (primitive-type-special-case) — elevating one
effect above the registered-via-source-declaration substrate.

**Correction to MSR Edit 2 scope:** the substrate touch is
**ZERO lines in `src/types.mn`**; **ZERO lines in `src/effects.mn`**;
**ZERO lines in `src/infer.mn`**; **ZERO lines in `src/lower.mn`**;
**ZERO lines in `src/backends/wasm.mn`**. CE is pure declaration
in ONE new file: `lib/runtime/search.mn`.

**§4.0.2 `Abort` / `try_with_abort_catch` prerequisite.**

`backtrack`'s arm uses `try_with_abort_catch(inner, on_abort)`.
If this combinator (or the `Abort` effect it catches) is NOT yet
declared in `lib/runtime/`, there are two paths:

- **Path A (preferred):** declare `lib/runtime/abort.mn` with
  `effect Abort { abort() -> () @resume=OneShot }` + the
  `try_with_abort_catch` combinator, as a peer handle to CE. Land
  both in the same commit; CE depends on Abort.
- **Path B (fallback):** use an existing `Fail` effect if one
  already exists in the repo. Grep first: `grep -rn "effect Abort\|effect Fail" lib/ src/`. If `Fail` exists and
  matches the shape, reuse it instead of introducing `Abort`.

**Implementer directive:** before writing `backtrack`, run:

```bash
grep -rn "effect Abort\|effect Fail\|try_with_abort_catch\|abort()\|fail()" \
  ~/Projects/mentl/lib ~/Projects/mentl/src
```

Classify the output into:
- Existing Abort-like effect → reuse.
- No existing form → declare as peer handle (Path A); ship in CE
  commit or as named sub-handle CE.1 in `ROADMAP.md`.

Do NOT inline an ad-hoc abort mechanism inside `backtrack`.

**§4.0.3 `graph_push_checkpoint` / `graph_rollback` are PRE-EXISTING.**

Per MSR §1.1, the trail + checkpoint substrate is REAL at
`src/graph.mn:218-224` + `src/types.mn:609,618`. CE composes
with them; no new graph substrate.

### 4.1 The new file — `lib/runtime/search.mn`

Create new file `lib/runtime/search.mn` (full contents below).
Literal tokens; every line is the line to write. No pseudocode.

```mentl
// search.mn — Choice effect + canonical handlers (MSR Edit 2, CE)
//
// The canonical multi-shot user effect. One op, two handlers, zero
// compiler intrinsic. Every SAT / CSP / backtracking-parser /
// logic-prog / probabilistic framework in the industry is Choice
// composed with a domain handler — this file ships the effect +
// the two simplest composers; crucibles ship the domain handlers.
//
// Declared here, not in types.mn, because effect NAMES are runtime
// strings inside ENamed — the registered-via-source-declaration
// substrate. Choice is not compiler-special; it is a user effect
// that happens to be the canonical MS example.
//
// Composes with:
//   - lib/runtime/abort.mn — Abort effect + try_with_abort_catch
//     (prerequisite; backtrack catches Abort to skip dead-end forks)
//   - src/graph.mn — graph_push_checkpoint + graph_rollback (trail
//     rollback substrate, primitive #1)
//   - H7 MS runtime emit (pending) — enables backtrack to actually
//     fork at runtime. Until H7, Choice type-checks and row-algebras
//     correctly; backtrack's fork semantics are specified but not
//     executable.
//
// Not here: race combinator (MSR Edit 5); arena-aware MS handlers
// (MSR Edit 4); SAT / CSP / Prolog crucibles (per-domain).

import runtime/abort         // Abort effect + try_with_abort_catch
import types                 // ResumeDiscipline, EffRow, Reason

// ═══ Choice — the canonical multi-shot user effect ═════════════════

effect Choice {
  choose(options: List<A>) -> A   @resume=MultiShot
}

// ═══ pick_first — OneShot terminal ═════════════════════════════════

handler pick_first {
  choose(options) =>
    if len(options) == 0 { perform abort() }
    else { resume(options[0]) }
}

// ═══ backtrack — MultiShot try-each ════════════════════════════════

handler backtrack with Choice + GraphRead + GraphWrite + Abort {
  choose(options) => {
    fn try_each(i) =
      if i >= len(options) { perform abort() }
      else {
        let checkpoint = perform graph_push_checkpoint()
        perform try_with_abort_catch(
          fn () => resume(options[i]),
          fn () => { perform graph_rollback(checkpoint); try_each(i + 1) }
        )
      }
    try_each(0)
  }
}
```

### 4.2-4.6 No edits to `src/*.mn`

Per §4.0.1: `src/types.mn`, `src/effects.mn`, `src/parser.mn`,
`src/infer.mn`, `src/lower.mn`, `src/backends/wasm.mn` — all
UNCHANGED. The substrate already supports `Choice` via the existing
ENamed / EffectOpScheme / handler-install machinery.

### 4.7 Possible peer file — `lib/runtime/abort.mn`

**Conditional** (per §4.0.2 grep directive). If the Abort substrate
doesn't yet exist:

```mentl
// abort.mn — Abort effect + try_with_abort_catch combinator
//
// Shipped alongside CE. Abort is a OneShot effect — performing it
// transfers control to the nearest installed catch; no resume back
// to caller. try_with_abort_catch installs a scope-local catch.

import types

effect Abort {
  abort() -> ()   @resume=OneShot
}

// try_with_abort_catch — scope-local abort catch
// Runs inner; if inner performs abort, runs on_abort; otherwise
// returns inner's result.

fn try_with_abort_catch(inner, on_abort) = {
  handle inner() {
    abort() => on_abort()
  }
}
```

If `lib/runtime/abort.mn` already exists with matching shape,
skip this peer and adjust `search.mn`'s import accordingly.

### 4.8 `ROADMAP.md` update note (post-CE-land)

After CE ships, update `ROADMAP.md` to note: CE landed, zero `src/`
edits, Abort substrate shipped as peer if missing, unblocks
crucible_search / crucible_sat / crucible_parser / crucible_kanren /
crucible_sampling; runtime MS fork execution awaits H7.

---

## 5. Tutorial — `lib/tutorial/02b-multishot.mn` (MSR Edit 6 / D.3)

Per QA Q-D.3.1: direct `Choice` exposure, no helper wrappers.
Canonical N-queens (N=4 for visualization; N=8 for the full
classic).

### 5.1 The tutorial file — literal tokens

```mentl
// 02b-multishot.mn — MultiShot resume discipline by example
//
// Primitive #2's MultiShot arm in residue form. One effect (Choice);
// one op (choose); one handler (backtrack) that resumes the
// continuation once per option; trail rollback reverses each
// speculative attempt's graph bindings.

import runtime/search    // effect Choice + handler backtrack
import runtime/abort     // effect Abort + try_with_abort_catch

// ─── N-queens: place one queen per row ──────────────────────────────

fn safe(row, col, board) with Pure =
  fn check(i) =
    if i >= row { true }
    else {
      let col_i = board[i]
      if col_i == col { false }
      else if col_i - col == row - i { false }   // diagonal down-right
      else if col - col_i == row - i { false }   // diagonal down-left
      else { check(i + 1) }
    }
  check(0)

fn place_row(row, n, board) with Choice + Abort =
  if row >= n { board }   // all rows placed — solution
  else {
    let col = perform choose(range(0, n))
    if safe(row, col, board) {
      place_row(row + 1, n, push(board, col))
    } else {
      perform abort()
    }
  }

// ─── Entry: solve N-queens ──────────────────────────────────────────

fn solve_nqueens(n) =
  place_row(0, n, [])
    ~> backtrack
    ~> pick_first

fn main() =
  let sol_4 = solve_nqueens(4)
  let sol_8 = solve_nqueens(8)
  println("4-queens: ")
  println(show_board(sol_4))
  println("8-queens: ")
  println(show_board(sol_8))

fn show_board(cols) =
  fn show_row(i) =
    if i >= len(cols) { "" }
    else { str_concat(str_concat(int_to_str(cols[i]), " "), show_row(i + 1)) }
  show_row(0)
```

---

## 6. Composition with other MS substrate

### 6.1 `Choice` × `race` (MSR Edit 5)

```
query
    |> enumerate_candidates
    ~> race(
        backtrack_depth_first,
        backtrack_iterative_deepening,
        backtrack_mcts_guided
      )
    ~> verify_obligations
    |> accept_first_verified
```

`race` enumerates `choose` options via three handlers in parallel
forks; tiebreak chain ranks survivors deterministically. Shared
`graph_push_checkpoint` at race install rolls back all non-winning
forks atomically (Q-B.4.2).

### 6.2 `Choice` × arena-aware MS handlers (MSR Edit 4)

Under `!Alloc` context, only `replay_safe` MS is admissible. Choice
works here BECAUSE backtrack composes with replay_safe: the
continuation's resumes re-perform upstream ops rather than
capturing their state, so no allocation per fork.

Under `fork_copy` or `fork_deny` in `!Alloc` context: compile-time
error at handler install via row subsumption (MSR Edit 4 substrate).

### 6.3 `Choice` × Mentl's Synth effect

Synth and Choice are DIFFERENT effects with DIFFERENT purposes.
Synth is Mentl's proposer chain — returns Candidate ADT per MO §4.
Choice is the user-visible search primitive — returns user-typed A
per call site. Neither subsumes the other. Both are
`@resume=MultiShot`; both compose with graph rollback; both are
primitive #2's substrate. Peer effects.

### 6.4 `Choice` × `Verify` (refinement discharge)

Speculative verification: each choose outcome's value is
Verify-discharged against the expected refinement; failed
discharge rolls back the fork. MS2 §1.6's compound substrate with
Choice as the enumeration surface.

---

## 7. Acceptance criteria

### 7.1 Type-level acceptance (pre-H7, post-CE-land)

- **AC1:** `lib/runtime/search.mn` parses cleanly.
- **AC2:** Type-checks cleanly. `perform choose(options)` sites
  infer correctly across `List<Int>`, `List<String>`, `List<A>`.
- **AC3:** Row algebra admits `with Choice`, `with !Choice`,
  `with Choice + Abort`, `with Choice - Alloc` without error.
- **AC4:** Handler install via `~>` composes correctly.
- **AC5:** `drift-audit.sh lib/runtime/search.mn` returns 0.
- **AC6:** `tools/effect-registry-audit.sh` reports `Choice` as
  singly-declared in `lib/runtime/search.mn`.

### 7.2 Runtime acceptance (post-H7, post-CE-land)

- **AC7:** `solve_nqueens(4)` produces valid 4-queens solution.
- **AC8:** `solve_nqueens(8)` produces valid 8-queens solution.
- **AC9:** `pick_first`'s fast path runs without allocation under
  `!Alloc`.
- **AC10:** `backtrack`'s rollback is O(M) per fork.

### 7.3 Tutorial acceptance

- **AC11:** `lib/tutorial/02b-multishot.mn` reads top-to-bottom as
  learner-facing.
- **AC12:** Every line of the tutorial passes all eight interrogations.
- **AC13:** Post-MV.2: `mentl teach 02b-multishot.mn` surfaces
  VoiceLines narrating the handler chain's structure.

---

## 8. Open questions — zero

All design decisions are pre-resolved in QA:

| Question | Source | Resolved |
|----------|--------|----------|
| `Choice(T)` parameterized or bare? | Q-B.3.1 | Bare |
| `choose([])` semantics? | Q-B.3.2 | Runtime Abort; handler decides |
| Tutorial uses Choice directly? | Q-D.3.1 | Direct |
| `race` integration? | Q-B.4.1, Q-B.4.2 | Peer combinator |
| Arena discipline? | Q-B.5.1, Q-B.5.2 | Three handlers |

If a new question surfaces during implementation, STOP and surface
— do NOT silently decide.

---

## 9. Dispatch

**mentl-implementer (Sonnet).** CE is pure declaration + two
canonical handlers over existing substrate. Zero substrate
extensions (§4.0.1). Mechanical transcription of §4.1 (and
conditionally §4.7 if Abort substrate is missing).

Deliverables:
- `lib/runtime/search.mn` (§4.1, full contents)
- `lib/runtime/abort.mn` (§4.7, if grep misses Abort)
- `lib/tutorial/02b-multishot.mn` (§5.1, full contents)

Post-edit audit: `bash tools/drift-audit.sh lib/runtime/search.mn
lib/tutorial/02b-multishot.mn [lib/runtime/abort.mn]`.

Acceptance: §7.1 AC1–AC6 clean. No commit; Morgan reviews first.

---

## 10. Closing

**CE is the smallest possible MS substrate walkthrough.** It adds
ONE effect with ONE op + TWO handlers + ONE tutorial file. It
touches ZERO `src/*.mn` files. It is pure declaration over the
substrate primitives #1, #2, #4 already shipped.

**The reach of this one walkthrough:** SAT, CSP, logic
programming, backtracking parsers, miniKanren, probabilistic
sampling, importance sampling — reduced to `perform choose(...)`
+ a handler. Each domain earns its own crucible; CE ships the
substrate every crucible composes from.

**One effect. One op. Two handlers. N domains.**

*Choice is MultiShot's surface to the user. Backtrack is the
surface to search. Trail rollback is the surface to
time-reversal. Primitive #1 and primitive #2 compose into the
substrate; Choice is the minimum name users need to know to reach
it.*

**CE is the walkthrough that proves `Choice` is not a library — it
is a residue the kernel renders.**
