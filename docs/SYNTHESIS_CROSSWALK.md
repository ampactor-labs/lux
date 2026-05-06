# Synthesis Manifesto — Crosswalk to Mentl

> **Status: historical context, not a living spec.** This doc predates
> the current roadmap (`ROADMAP.md`). It remains as confidence — external
> validation that the major design choices align with a manifesto
> produced independently. Recommendations from this doc that survived
> audit are now absorbed into `docs/specs/*.md`; recommendations that
> didn't are marked "rejected" in the table below.

*An external, context-free conversation produced an eight-pillar
"Synthesis" manifesto. This doc maps each pillar to where Mentl (then
called Lux) already is, where it converges, and what's genuinely new.
Source document is reproduced verbatim at the bottom so future readers
can see exactly what we were comparing against.*

**Posture:** this is a **crosswalk**, not an adoption plan. Each pillar
gets a verdict: **✅ already Lux**, **🔀 convergent** (Lux has it under
a different name), or **🆕 new for Lux** (worth formalizing into an
arc). The implementation plan discussion decides what becomes an arc.

---

## The short answer

Six of eight pillars are Lux. Two bring ideas worth adopting:

| Pillar | Verdict | Where it lives in Lux |
|---|---|---|
| I. Projectional AST | ❌ rejected | text is canonical; Darklang retreated 2024, Hazel stays research |
| II. Algebraic Effects | ✅ already Lux | `DESIGN.md` → *One Mechanism* |
| III. Data-Oriented Design + SIMD | 🔀 convergent | `!Alloc` covers allocation; Spans/SIMD are new |
| IV. Ownership Inference | ✅ already Lux | `specs/ownership-design.md` |
| V. Types as Proofs | ✅ already Lux | `DESIGN.md` → *Refinement Types* |
| VI. Concurrency | 🔀 convergent | colorless async ✅; fractional permissions 🆕 |
| VII. Demand-Driven DAG Compiler | 🔀 convergent | `ARC3_ROADMAP.md` item 6 + `specs/incremental-compilation.md` |
| VIII. AI-Native Symbiosis | 🔀 convergent | `DESIGN.md` — collaboration discipline (compiler-verifies, collaborator-proposes) |

**The genuinely new ideas, ranked by fit:**

1. ~~**Fractional permissions for concurrent reads** (Pillar VI)~~ —
   **SUPERSEDED.** See *2024–2026 Research Neighbors* (Tier 4): Vale's
   region-freeze via `!Mutate` delivers the same proof via Lux's existing
   effect algebra with no numeric permission accounting.
   `specs/fractional-permissions.md` is shelved.
2. **FBIP — Functional But In-Place** (Pillar IV) — pure functional
   updates compiled to destructive in-place mutation when the value is
   unshared. A native-backend optimization that pays off exactly where
   Lux's gradient is strongest. **Refined:** via ownership graph directly,
   not post-hoc RC analysis (see Tier 5). Stronger static guarantee than
   Koka/Lean's approach.
3. **Projectional AST + content-addressed storage** (Pillar I + VII) —
   **DOWNGRADED to storage-only.** Text remains canonical (Darklang's
   retreat from structural editing confirms). Content-addressing lives
   in the `.luxi` cache (`specs/incremental-compilation.md`). No
   projectional editor. See *Research Neighbors* Tier 4.
4. **AI-native as an explicit design principle** (Pillar VIII) — Lux's
   collaboration discipline (`DESIGN.md`) is exactly this, unnamed.
   Worth promoting to a first-class design constraint. **Operationalized**
   as one-mechanism `Suggest` effect — any proposer (enumerative,
   SMT-guided, LLM-guided) is a handler; the verifier is the oracle.
   See Tier 5.
5. **SIMD auto-gen for byte scans** (Pillar III) — a native-backend
   optimization for the lexer hot path. Lands when the x86 emitter lands.

---

## Pillar-by-pillar

### Pillar I — The Medium (Projectional AST) — 🆕 new

> *"Synthesis abandons text files as the source of truth. Code is
> stored natively as a rich, structured AST — a database of pure logic
> secured by cryptographic hashes."*

**Lux today:** text files. `.lux` source, parsed on demand. The
[packaging spec](specs/packaging-design.md) already adopts hash-based
identity ("the hash IS the lock") for module distribution, but the
source of truth remains text.

**What's new:** making the AST itself the persistent medium. Syntax
becomes a projection — different developers can view the same program
with different surface syntax. Refactoring becomes a graph operation.

**Fit with Lux:** philosophically perfect. "The inference IS the light"
(`CLAUDE.md`) extends naturally to "the AST IS the artifact." But it's
a profound shift with huge tooling surface. Not near-term.

**Verdict:** candidate for Arc 4+, low priority vs. self-containment.
The `specs/packaging-design.md` hash-addressing is the gateway drug.

### Pillar II — State & I/O (Algebraic Effects) — ✅ already Lux

> *"Impure, real-world workflows written with pure, mathematical
> mechanics. Functions are pure by default. When a function needs to
> touch the outside world, it does not execute — it yields an effect."*

**Lux today:** this is the core. Every bullet in Pillar II is in
`DESIGN.md`:
- Purity by default → `Pure` is inferred when no effects detected.
- Effects as intent → `effect Foo { op() -> () }` + `perform`.
- Ultimate DI → `handle { body } with HandlerImpl` is exactly this.
- Delimited continuations → `resume` + multi-shot are shipped.

**Verdict:** validation, not new content. Lux got here first.

### Pillar III — Mechanical Sympathy (DOD, SIMD, Zero-Alloc) — 🔀 convergent

> *"Parse is the machine's job; Read is the human's job."*
> *"Zero-allocation layouts — spans point directly to original buffers."*
> *"SIMD instructions sweep raw byte buffers at maximum hardware throughput."*

**Lux today:** `!Alloc` proves allocation absence transitively. Scoped
arenas (Arc 3 item 2) deliver zero-cost deterministic cleanup. The
runtime has flat string representation `[len_i32][bytes...]` — already
span-shaped.

**What's convergent:** Lux thinks about allocation; Synthesis thinks
about *data layout and SIMD*. Complementary framings.

**What's new:**

- **Explicit `Span<T>` type** — a zero-copy view into an existing
  buffer. Lux currently slices lists via `list_pop` / offset tags, but
  there's no user-visible `Span` type for bytes/strings. Would compose
  with `!Alloc` as the "nothing copied, nothing allocated" proof.
- **Parse/Read separation** — Lux doesn't explicitly distinguish
  "scan bytes" from "materialize values." The lexer *is* byte-scan,
  but the distinction isn't elevated.
- **Auto-SIMD for byte scans** — the x86 backend (Arc 4+) could emit
  SIMD for the lexer's character-class tests and delimiter searches.
  The types already tell the compiler these are `!Alloc` byte scans.

**Verdict:** fold `Span<T>` into the Arc 3 memory work
(`specs/scoped-memory.md`). SIMD auto-gen lands with the native
backend. Parse/Read separation is a teaching/documentation angle.

### Pillar IV — Memory Model (Ownership Inference) — ✅ already Lux

> *"Usage-Based Inference — read = zero-cost reference; mutate =
> exclusive lock; thread boundary = silent transfer. You never type
> `<'a>` or `&mut`."*
> *"FBIP — Functional But In-Place. Pure functional updates compiled
> to destructive C-style mutation."*
> *"Graceful Degradation — isolated GC only for unresolvable cycles."*

**Lux today:** `specs/ownership-design.md`. `own` = affine, `ref` =
scoped, everything else inferred. No lifetime annotations, ever.
`gc` internal-only (Arc). `!Alloc` proves transitively.

**What's convergent:** exact alignment. Synthesis's "exclusive lock"
= Lux's `own`. "Silent transfer" = Lux's move semantics. "Graceful
degradation" = Lux's internal `gc` tier.

**What's new:**

- **FBIP** (Functional But In-Place) — explicit compiler transform: if
  a pure function updates an unshared data structure, emit destructive
  mutation. The algorithmic payoff is huge (functional ergonomics,
  C performance). Lux already *could* do this — the ownership graph
  knows which values are unshared. The transform just hasn't been
  written. Fits naturally in the native backend.

**Verdict:** FBIP lands in Arc 4+ native backend. Everything else is
already Lux under different names.

### Pillar V — The Type System (Types as Proofs) — ✅ already Lux

> *"Progressive strictness — Python-like prototyping, production locks
> module boundaries. Dependent types — `Int where value >= 0 && value
> <= 120` refuses to build if negative is logically possible. Absolute
> null safety — Algebraic Data Types force explicit failure handling."*

**Lux today:** the gradient (`DESIGN.md` → *The Annotation Gradient*)
is exactly "progressive strictness." Refinement types (Phases 11A/11B)
are "dependent types." ADTs + match exhaustiveness is "absolute null
safety."

**Verdict:** validation. Lux's gradient is more elegantly continuous
than Synthesis's "prototyping / production" bimodal framing.

### Pillar VI — Concurrency (Physics, not Libraries) — 🔀 convergent

> *"Fractional Permissions — if a variable is passed to three
> concurrent readers, each gets 0.33. Because no thread holds 1.0,
> mutation is mathematically impossible. Zero data races, zero mutexes."*
> *"Colorless Async — async is a `Suspend` effect handled by the event
> loop. Function coloring doesn't exist."*
> *"Structured Concurrency — child threads reaped when parent cancels."*

**Lux today:** colorless async falls out of effects (`DESIGN.md` Ch 4
+ `SUBSTRATE.md` §IV). Structured concurrency is implicit. Fractional
permissions are NOT in Lux.

**What's new:**

- **Fractional permissions** — a rigorous alternative to affine
  ownership for concurrent *readers*. Lux's `own` forbids sharing;
  `ref` forbids escape. Neither cleanly expresses "N threads read in
  parallel, no one can write." Fractional permissions do, and they
  compose with the effect system (a `with !Mutate` constraint would
  be provable by holding a fraction < 1.0).

**Fit with Lux:** excellent. Ownership-as-effect already treats
consumption as `Consume` effect. Extending to *permission* effects
is a natural generalization. Falls out of the algebra.

**Verdict:** formal spec candidate for Arc 4+. Worth a
`specs/fractional-permissions.md` proposal.

### Pillar VII — The Engine (Demand-Driven DAG) — 🔀 convergent

> *"No Passes, Only Queries. O(1) Recompilation via AST hashes. The
> IDE is the Compiler. Native Cloud Swarm — CI's compiled artifacts
> downloadable by hash."*

**Lux today:** `ARC3_ROADMAP.md` item 6 ("Compiler as Data Structure")
explicitly proposes the DAG env. `specs/incremental-compilation.md`
defines `.luxi` module caches keyed by content hash. The
`specs/packaging-design.md` hash-addressing extends across the
network.

**What's convergent:** Synthesis's DAG = Lux's DAG. Synthesis's AST
hash = Lux's `.luxi` content hash. Synthesis's "cloud swarm" = Lux's
"package as handler, registry as handler."

**What's new (or more ambitious):**

- **"The IDE is the Compiler"** — Lux's medium already says
  "LSP is a handler on the compile effect" (`SUBSTRATE.md` §III).
  Synthesis goes further:
  the daemon IS the source of truth, editor is just a query client.
  This is a deployment/tooling stance, not a language feature.
- **O(1) recompilation invalidation** — needs structural signatures
  (hash the function's *public* shape separately from its body) so
  internal edits don't cascade. `.luxi` design should adopt this.

**Verdict:** the DAG plan is already Arc 3 item 6. Adopt the
structural-signature idea into `specs/incremental-compilation.md`. The
"IDE as compiler client" framing goes into `DESIGN.md` eventually.

### Pillar VIII — AI-Native Symbiosis — 🔀 convergent

> *"AI cannot hallucinate bad syntax — dependent types + AST logic
> prevent it. Mathematical verification — the AI is physically
> incapable of introducing a memory bug."*

**Lux today:** Lux's collaboration discipline (`DESIGN.md` +
`CLAUDE.md`) says the same thing about human + Claude collaboration:
"the compiler verifies, so the collaborator's suggestions are either
correct or caught." Not elevated to a design principle.

**What's new:** **promoting this to a named principle.** Lux's entire
gradient architecture is an AI-and-human interface by accident — make
it explicit. Types-as-proofs + effect algebra = a verified surface
where AI's role is proposing; the compiler's role is verifying.

**Verdict:** add an explicit "AI-Native" section to `DESIGN.md`
that names what's already there. No new mechanism needed — just
documentation.

---

## What Lux has that Synthesis doesn't

For completeness — the convergence is not total. Things Lux has that
the manifesto didn't surface:

- **The effect algebra** (`!E`, `E - F`, `E & F`) — Synthesis mentions
  effects but not the Boolean algebra. The four compilation gates
  (`!IO`, `!Alloc`, etc.) fall out of the algebra, not from pillars.
- **Multi-shot continuations** — `specs/multi-shot-continuations.md`
  shows hyperparameter search, backtracking, autodiff handler-swaps.
  Synthesis's "delimited continuations" are single-shot.
- **The teaching compiler / gradient** — "progressive strictness" is
  binary in Synthesis; Lux has a continuous gradient where every
  annotation unlocks a specific optimization.
- **DSP/ML framing** — pillars don't mention the language as a domain
  unification. Lux's `|>` collapses DSP, ML, search, compiler pipeline
  into one notation (see `DESIGN.md` → *The Pipe Unification*).

These are not gaps in Synthesis; they are evidence Lux's design space
is genuinely wider. The convergence on six pillars validates the
foundation; the divergence on these items is where Lux's thesis lives.

---

## Recommendations for discussion

When we pause to discuss the implementation plan, these crosswalk
items are candidates for scoping:

**For Arc 3 (active):**
- Adopt structural-signature hashing in
  `specs/incremental-compilation.md` (from Pillar VII).

**For Arc 4+ (open):**
- ~~`specs/fractional-permissions.md`~~ — **shelved** per *Research
  Neighbors* Tier 4 (Vale's region-freeze is cleaner).
- `specs/span-types.md` — new spec (from Pillar III).
- **FBIP** transform as a native-backend milestone (from Pillar IV) —
  via the ownership graph directly (see *Research Neighbors* Tier 5).
- **SIMD auto-gen** for byte scans (from Pillar III).
- ~~**Projectional AST** as a full arc thesis~~ — **downgraded** to
  storage-only (see *Research Neighbors* Tier 4). Text stays canonical.

**Documentation-only (can happen any time):**
- Name the AI-native principle explicitly (from Pillar VIII).
- Document Parse/Read separation as a Lux teaching point (from Pillar III).

---

## 2024–2026 Research Neighbors

*Extending the crosswalk beyond the Synthesis Manifesto. What academic
and industrial language design in 2024–2026 says Lux should absorb,
reframe, or reject. Same verdict format: ✅ already Lux, 🔀 convergent,
🆕 new, ❌ reject.*

### The short answer

Most 2024-2026 research converges on what Lux has already chosen. The
interesting findings are **implementation techniques** — how to make what
Lux has already designed run faster, infer more precisely, or emit cleaner
bytes — not new primitives.

| Neighbor | Verdict | Fit |
|---|---|---|
| Affect (POPL 2025) — affine-tracked `resume` | 🆕 new | Arc 3 candidate Item 8 |
| Koka evidence-passing (ICFP 2021, Koka 2024 C backend) | 🆕 impl. technique | Arc 3 Item 5 (`val_concat` drift fix) |
| Polonius 2026 alpha — lazy constraint rewrite | 🆕 impl. technique | Arc 3 Item 5 (ownership pass) |
| Salsa 3.0 / `ty` — flat-array subst + epoch + persistent overlay | 🆕 impl. technique | Arc 3 Item 5 (substitution representation) |
| Liquid Haskell 2025 — SMT by theory | 🔀 convergent | Arc 3 (`SMT` effect; handler picks Z3 / cvc5) |
| Modal effect types (POPL 2025 / POPL 2026) | 🔀 convergent reframe | theoretical grounding for `E - F` |
| Idris 2 QTT (ECOOP 2021) | 🔀 display only | `--teach` renders `0/1/ω` presentation |
| Wasm 3.0 exceptions + tail calls (Sep 2025) | 🆕 new | Arc 3 Item 1 (Diagnostic), Arc 4 |
| WASIp3 async effect ABI (late 2025 RC) | 🆕 new | Arc 3/4 capability layer |
| Direct WASM binary emission (Thunderseethe pattern) | 🆕 pattern | Arc 4 #1 (delete `wat2wasm`) |
| Lexa (OOPSLA 2024) — direct stack-switching | 🆕 new | Arc 4 native-backend optimization |
| GPCE 2024 — typed codegen via effects | ✅ validation | cite in Codegen-as-effect commit |
| Rust 2025 bootstrap redesign + Crystal tarball + DDC | ✅ validates | Phase 0 of Arc 3 (freeze+delete Rust) |
| Vale region-freeze with `!Mutate` | 🔀 supersedes fractional permissions | update Pillar VI below |
| Darklang projectional retreat | ❌ validates rejection | update Pillar I below |
| Unison 1.0 content-addressed codebase | 🔀 storage only | names stay canonical |
| Scala 3 capture checking `^` | ❌ reject | redundant with effect rows |
| WASM 3.0 GC | ❌ reject as default | optional Arc 4 backend |

### Tier 1 — load-bearing for Arc 3

**Affect (POPL 2025) — affine-tracked `resume`.** Types distinguish one-shot
from multi-shot resume; compiler picks stack-alloc vs heap-copy per handler.
Exactly "the inference IS the light" applied to continuations. Candidate new
**Arc 3 Item 8**. [Paper](https://iris-project.org/pdfs/2025-popl-affect.pdf).

**Koka evidence passing — monomorphic handler dispatch.** When the DAG env
(Item 5) proves a call site's handler stack is monomorphic, emit
`call $h_foo` directly instead of `global.get $__ev_op_foo; call_indirect`.
**This kills the `val_concat`/`val_eq` polymorphic-fallback drift at the
compile stage, not runtime.** [Paper](https://xnning.github.io/papers/multip.pdf).

**Polonius 2026 alpha — lazy constraint rewrite.** Abandoned Datalog for
location-sensitive reachability over subset+CFG with lazy rewrites. Correct
shape for Lux's ownership pass; don't build a Datalog-style side structure.
[Project goal](https://rust-lang.github.io/rust-project-goals/2026/polonius.html).

**Salsa 3.0 / `ty` — flat-array substitution with epoch + persistent
per-module overlay (Dec 2025).** Convergent answer to Item 5's subst
representation decision. Module granularity is sufficient; fine-grained
per-definition is overkill (Pyrefly engineering confirms at Meta scale).
[ty / Salsa 3.0](https://lobste.rs/s/zjq0nl/ty_extremely_fast_python_type_checker).

### Tier 2 — Arc 4 / native backend

- **Wasm 3.0** (Sep 2025): exceptions + tail calls standardized. Diagnostic lowers cheap. [Announcement](https://webassembly.org/news/2025-09-17-wasm-3.0/).
- **WASIp3 async ABI**: `IO + Async` row → WASIp3 async imports, no caller coloring. [Preview](https://www.fermyon.com/blog/looking-ahead-to-wasip3).
- **Direct WASM binary emission** (Thunderseethe 2024): typed section builder emitting LEB128. [Reference](https://thunderseethe.dev/posts/emit-base/).
- **Lexa** (OOPSLA 2024): direct stack-switching for lexical handlers; linear vs quadratic. [Paper](https://cs.uwaterloo.ca/~yizhou/papers/lexa-oopsla2024.pdf).
- **Native-backend ranking** (hand-rolled x86 > QBE > Cranelift > LLVM): see `ROADMAP.md`.
- **Roc surgical linker + dev-backend split**: release (LLVM/QBE) + dev (bespoke) for interactive latency. [Roc](https://sycl.it/agenda/day2/roc-surgical-linker/).

### Tier 3 — reframes (no redesign, citations)

- **Modal effect types** (POPL 2025 / POPL 2026): Lux's `E - F` as relative modality. [2025](https://homepages.inf.ed.ac.uk/slindley/papers/modal-effects.pdf) · [2026](https://popl26.sigplan.org/details/POPL-2026-popl-research-papers/34/Rows-and-Capabilities-as-Modal-Effects).
- **Idris 2 QTT** (ECOOP 2021): display convention `0/1/ω` in `--teach`. Semantics stays own/ref. [Paper](https://arxiv.org/abs/2104.00480).
- **GPCE 2024 — typed codegen via effects**: academic grounding for `specs/codegen-effect-design.md`. Cite in Phase 1 commit. [Paper](https://2024.splashcon.org/details/gpce-2024-papers/2/Type-Safe-Code-Generation-With-Algebraic-Effects-and-Handlers).
- **Liquid Haskell 2025 — SMT split**: `SMT` effect; handler picks Z3/cvc5 by residual form. [Release](https://www.tweag.io/blog/2025-03-20-lh-release/).
- **Scala 3 reach capabilities** (`x*`): syntactic precedent for "capability reachable through `x`"; information already in Lux's effect row. [Reference](https://docs.scala-lang.org/scala3/reference/experimental/cc.html).

### Tier 4 — rejections (overriding earlier recommendations)

**Supersedes "Fractional permissions for concurrent reads" (ranked #1 in
the earlier recommendations list, Pillar VI).** Vale's region-freeze via
`!Mutate` on a region delivers the same "N parallel readers, no mutation"
proof using Lux's existing effect algebra with no numeric permission
accounting. **Shelve `specs/fractional-permissions.md`.** [Vale regions](https://verdagon.dev/blog/zero-cost-memory-safety-regions-overview).

**Downgrades "Projectional AST" (Pillar I) from "full arc thesis" to
"storage-only."** Darklang retreated from structural editing after
production failure ("buggy and frustrating"); Hazel stays research. **Text
remains canonical.** Adopt content-addressing for the `.luxi` storage
layer only — which the existing `specs/incremental-compilation.md` already
does. No projectional editor in Lux's future. [Darklang status](https://blog.darklang.com/an-overdue-status-update/).

**Rejects WASM 3.0 GC as default memory model.** `struct.new` hides
allocation, defeating `!Alloc`. **Optional Arc 4 alternative backend** for
pure-functional code (compiler passes themselves) where ownership inference
proves the function is GC-safe. [Wasm 3.0 announcement](https://webassembly.org/news/2025-09-17-wasm-3.0/).

**Rejects content-addressed code as source of truth (Unison 1.0).** Hashed
identity breaks user-visible names in the gradient/teaching output. Keep
names. Use hashing for the `.luxi` cache only.

**Rejects capture-checking as parallel syntax (Scala 3 `^`).** Same info
Lux already tracks in effect rows. Adding a second mechanism fractures
the one-mechanism thesis.

**Rejects dependent types as semantics (Idris 2 QTT).** Elaboration blowup;
no SMT automation. Refinement + Z3 keeps inference linear. Keep the
display convention (Tier 3), reject the semantics.

### Tier 5 — Lux-original contributions worth publishing

**Multi-shot continuations + scoped arenas.** When a captured continuation
closes over an `own Arena`, the arena's drop defers until all reachable
continuations are discarded. **No current language integrates these.**
Affect (POPL 2025) provides the type machinery; semantics is Lux's.
Arc 3 Items 2 + 3 together.

**FBIP via ownership graph (not post-hoc RC analysis).** Koka/Lean do reuse
analysis *after* RC'ing the IR. Lux's ownership graph already knows which
values are unshared — a straight IR-to-IR pass suffices. Stronger static
guarantee, simpler implementation. Arc 4 after native backend.

**One-mechanism synthesis/diagnostics.** All proposers (enumerative,
SMT-guided, LLM-guided) become handlers on a single `Suggest` effect. The
verifier (`check.lux`) is the oracle; any proposer is a handler. Lean 4's
"macros are Lean functions" is the nearest neighbor; Lux generalizes
further via effects. Arc 4+ synthesis capstone.

### Rebranded old ideas (flagged)

- "Capability capture sets" (Scala 3) = effect rows with different sugar.
- "Generational references" (Vale) = Pony's ORCA recast.
- "Quantitative type theory" (Idris 2) = Girard's bounded linear logic + erasure, repackaged.
- "Capture tracking for ownership" (System Capybara, SPLASH 2025) = Rust's borrow checker in a different formalism.

Each validates Lux's direction without offering a replacement primitive.

---

## Source: the Synthesis Manifesto (verbatim)

*Preserved for reference. Contributed by an external party with no
prior knowledge of Lux. The convergence is independent.*

> **The Synthesis Manifesto: A Blueprint for the Ultimate Programming
> Language.** For decades, software engineering has been paralyzed by
> the **Language Trilemma**: the forced compromise between *Execution
> Speed* (C/C++, Rust), *Developer Velocity* (Python, JavaScript), and
> *Mathematical Correctness* (Haskell, Lean). Synthesis abandons these
> compromises. It acts as an adaptive environment scaling from a
> five-line script to a zero-allocation OS kernel.
>
> **Pillar I — The Medium (Projectional AST):** code stored as a
> cryptographically-hashed AST, not text. Syntax is a UI lens.
> Dependency Hell is mathematically impossible.
>
> **Pillar II — State & I/O (Algebraic Effects):** Purity by default.
> Functions *yield* effects rather than executing them. Handlers
> intercept in production or in tests. Delimited continuations unify
> exceptions, generators, and async.
>
> **Pillar III — Mechanical Sympathy (Data-Oriented Design):** Parse
> is the machine's job; Read is the human's. SIMD-first byte scans.
> Zero-allocation spans into the original buffer. Schema-less
> extensibility with binary-protocol speed.
>
> **Pillar IV — Memory Model (Ownership Inference):** Usage-based
> inference — no lifetime annotations, no `&mut`. FBIP: pure
> functional updates compiled to destructive in-place mutation.
> Graceful degradation: microscopic GC only at unresolvable cycles.
>
> **Pillar V — The Type System (Types as Proofs):** Progressive
> strictness — Python in prototyping, iron contracts in production.
> Dependent types — `Int where value >= 0 && value <= 120` refuses to
> build if negatives are logically possible. Absolute null safety via
> ADTs.
>
> **Pillar VI — Concurrency (Physics, Not Libraries):** Fractional
> permissions — 0.33 per reader means no one holds 1.0, mutation is
> mathematically impossible. Colorless async via the `Suspend` effect.
> Structured concurrency — child threads reaped when parent cancels.
>
> **Pillar VII — The Engine (Demand-Driven DAG Compiler):** No passes,
> only queries. O(1) recompilation via AST hashes. The IDE is the
> compiler. Native cloud swarm — CI artifacts by hash.
>
> **Pillar VIII — AI-Native Symbiosis:** Human intent + AI as
> optimization engine. Dependent types + AST logic prevent
> hallucination. The AI is physically incapable of introducing memory
> bugs or data races.
>
> **Conclusion:** un-opinionated about thought, fiercely opinionated
> about correctness. Reads like Python, manages dependencies like
> Unison, scales concurrency like Erlang, handles memory with
> zero-alloc DOD sympathy, routes effects with Koka-level rigor, and
> executes at Rust speed. The cognitive burden shifts from the human
> to a hyper-intelligent DAG solver.
