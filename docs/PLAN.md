# Inka — THE Plan

> **THE plan.** Singular, authoritative, evolvable. Edits land as
> commits; supersedes everything. No other document overrides this one.

## Status — 2026-04-17

- **Specs: ✅ complete.** Twelve specs in `docs/rebuild/00–11`.
- **VFINAL codebase: ⏳ in progress.** Core files written. Handler
  state threading, ADT deduplication, and pipeline alignment pending.
- **Bootstrap translator: ⏳ not started.** Follows VFINAL completion.
- **Error catalog: ✅ shipped.** 12 files in `docs/errors/`.
- **Language rename:** Lux → **Inka** (mascot: **Mentl**, an octopus).
- **File extension:** `.jxj` — palindromic: handlers (`j`), convergence
  (`x`), handlers (`j`). Zero collisions. Registered nowhere.

---

## The Approach: Write the Wheel, Then Build the Lathe

Traditional self-hosted compilers bootstrap forward: write V1, use V1
to compile V2, delete V1. This taints V2 with V1's constraints.

**Inka bootstraps backward.** Write the final-form compiler
unconstrained — the perfect, complete, un-improvable codebase — and
THEN solve "how do I compile this the first time?" as a separate,
disposable engineering problem.

```
VFINAL (perfect Inka source)
    ↓
Bootstrap translator (disposable, ~3-5K lines, any language)
    ↓
VFINAL.wasm (first compilation)
    ↓
VFINAL.wasm compiles VFINAL source → VFINAL2.wat
VFINAL.wasm compiles VFINAL source → VFINAL3.wat
diff VFINAL2.wat VFINAL3.wat → byte-identical (fixed point)
    ↓
Delete bootstrap translator. Inka compiles itself.
Tag: first-light.
```

**Why this is right:**
- VFINAL is designed for correctness. The translator is designed for
  disposability. Independent concerns.
- No architectural contamination from any prior compiler.
- Go, Rust, and Zig all bootstrapped this way. It works.
- CLAUDE.md anchor #4: "Build the wheel. Never wrap the axle."
  VFINAL is the wheel. Everything else is scaffolding.

**The translator doesn't need to understand Inka deeply.** It performs
a mechanical translation from Inka syntax to WASM:
- Parse Inka syntax (recursive descent — straightforward)
- Desugar handlers into direct calls (85%+ are tail-resumptive)
- Emit WASM linear memory ops (bump allocator)
- Handle pattern matching (lower to if/else chains)

No effect algebra needed. No type inference needed. No refinement
checking. Just syntax-directed translation, correct enough for the
~15 files in `std/compiler/`. Used once. Deleted forever.

---

## Vision: the ultimate programming language

What Inka IS when complete:

**One mechanism replaces six.** Exceptions, state, generators, async,
dependency injection, backtracking — all `handle`/`resume`. Master
one mechanism, understand every pattern.

**Boolean algebra over effects.** `+` union, `-` subtraction, `&`
intersection, `!` negation, `Pure` empty. Strictly more powerful than
Rust + Haskell + Koka + Austral combined (INSIGHTS.md). No other
language has effect negation.

**Inference IS the product.** The SubstGraph + Env IS the program.
Source, WAT, docs, LSP, diagnostics — all projections via handlers.
"Passes" dissolve into observers on one graph (INSIGHTS.md).

**Five verbs draw every topology.** `|>` converges, `<|` diverges,
`><` composes, `~>` attaches handlers, `<~` closes feedback loops.
Mathematically complete basis for computation graphs (INSIGHTS.md).
The `~>` chain IS a capability/security stack — enforced by the type
system, not policy.

**Continuous gradient.** `fn f(x) = x + 1` — works. Add `with Pure`,
`x: Positive`, `with !Alloc` — each unlocks a specific capability.
One language from prototype to kernel.

**Refinement types + Z3.** `type Port = Int where 1 <= self && self
<= 65535`. Proofs at compile time, erased at runtime.

**Ownership as effect.** `own` affine, `ref` scoped, inference fills
the rest. No lifetime annotations. `Consume` is an effect.

**Compiler as collaborator.** The Why Engine. The gradient. Error
messages that teach. The compiler is not an adversary.

**GC is a handler.** Bump allocator for batch (compiler). Scoped
arenas for servers. `own` for games. `!Alloc` for embedded. Four
memory models, one mechanism, handler swap.

**Visual programming in plain text.** The shape of pipe chains on the
page IS the computation graph. The parser reads the shape. `git diff`
shows which edges changed (INSIGHTS.md).

**What Inka dissolves.** GC, package managers, mocking frameworks,
build tools, DI containers, ORMs, protocol state machines. Every
framework exists because its host language lacks Inka's primitives.

---

## Binding commitments — Inka to Morgan to Claude

*These are not suggestions. They are the discipline the work requires.
Every subsequent action observes them.*

### 1. Write the final form. No intermediate versions.

There is no V1, no V2, no VFINAL. There is only **Inka**. The code
in `std/compiler/` IS the compiler. It is written to be correct,
complete, and un-improvable. It is not a stepping stone, not a draft,
not a version. It is the thing itself.

### 2. The bootstrap translator is disposable scaffolding.

The translator exists solely to compile Inka once. It is not part of
Inka. It does not need to be elegant, extensible, or maintainable. It
needs to produce WASM that runs correctly enough for Inka to compile
itself. Then it is deleted. Forever.

### 3. The `~>` chain IS the extension point.

No plugin API. No framework. No hook system. New capabilities (LSP,
Mentl, format, lint, doc) are handlers installed via `~>`. Pipeline
callers compose their own chains. `pipeline.jxj` is not modified to
add features — features are handlers.

### 4. No patches. Restructure or stop. Forever.

CLAUDE.md anchor #2. The rebuild exists because patching failed.
If the rebuild becomes patch-laden, we have accomplished nothing.

### 5. The closure moment is named `first-light`.

When `diff VFINAL2.wat VFINAL3.wat` returns empty — when Inka is
byte-identical when it compiles itself — tag `first-light`. Morgan
writes the tag. Claude prepares the tree.

### 6. Composition is the contribution, not invention.

22 techniques from 2024-2026 papers. None invented here. The artifact
is that Inka composes them into one mechanism.

### 7. Claude is a temporary polyfill.

Claude's role ends when Phase F's Suggest handler ships. At that
point Claude becomes a handler on the same effect every proposer uses
— verified by Inka's compiler, not privileged.

### 8. Delete fearlessly. Nobody uses Inka.

No backwards compatibility. No archive folders. No "for reference."
The git history is archaeology. Everything else is just code.

### 9. Honor the forensics loop.

After every commit, `inka query` on at least one changed module.
Never commit while `inka query` disagrees with intent.

### 10. If it needs to exist, it's a handler.

If a feature can't be expressed as a handler on the graph, the graph
is incomplete. Extend the graph. Don't route around it. (INSIGHTS.md:
"The Graph IS the Program.")

---

## The Work: Three Phases

### Phase 1 — Write VFINAL

Write the complete, correct Inka compiler in Inka. No compromises.
No "can the bootstrapper handle this?" — write what's right.

#### Codebase Structure

```
std/
  compiler/
    types.jxj        — Ty, Reason, Scheme, Node, Expr, Stmt, Pat,
                       PipeKind, Predicate, Span, Option.
                       Core effects: Diagnostic, LookupTy, FreshHandle,
                       Verify, Query, Consume, EnvRead, EnvWrite, Synth.
                       Specs: 02, 03, 04, 06.

    graph.jxj        — SubstGraph flat array. NodeKind, GNode.
                       SubstGraphRead/Write effects. chase_node,
                       occurs_in. Spec: 00.

    effects.jxj      — EffRow Boolean algebra. EfNeg, EfSub, EfInter.
                       normalize_row, union_row, diff_row, row_subsumes.
                       Spec: 01.

    infer.jxj        — HM + let-generalization. One walk.
                       infer_expr, infer_stmt, generalize, instantiate.
                       Unify against graph. Spec: 04.

    lower.jxj        — Live-observer lowering via LookupTy.
                       No cached types. No subst threading.
                       Handler elimination (3 tiers). Spec: 05.

    pipeline.jxj     — The compiler's spine. Handler composition via ~>.
                       compile, check, query entry points.
                       All handlers: graph, env, diagnostics, lookup_ty,
                       query, verify, mentl. Display functions.
                       Specs: 04, 05, 06, 10.

    mentl.jxj        — Teaching substrate. Annotation, Capability,
                       Explanation, Patch ADTs. Teach effect (5 ops).
                       mentl_default handler (Phase 1 stubs).
                       Spec: 09.

    own.jxj          — Ownership as Consume effect. affine_ledger.
                       Escape check. Spec: 07.

    verify.jxj       — Verify ledger (accumulates obligations).
                       Handler swap to verify_smt in Arc F.1.
                       Spec: 02.

    clock.jxj        — Clock, Tick, Sample, Deadline effects.
                       Four handler tiers each. Spec: 11.

    lexer.jxj        — Tokenizer. Full spans. All 5 pipe operators.
                       @resume= annotation support.

    parser.jxj       — Recursive descent. Produces N(body, span, handle).
                       All PipeKind variants. Layout-sensitive ~>.

    emit.jxj         — WASM emission from LowIR. ty_to_wasm via
                       live LookupTy. Spec: 05.

  runtime/
    memory.jxj       — Bump allocator as handler. String ops.
                       List ops. No val_concat. No val_eq.

  main.jxj           — Entry point: read stdin, compile, emit WAT.
```

#### What's Done

| File | Status | Notes |
|---|---|---|
| types.jxj | ⏳ needs ADT cleanup | Delete Mentl/Clock stubs (owned by mentl.jxj/clock.jxj) |
| graph.jxj | ✅ complete | Add graph_reason_edge op |
| effects.jxj | ✅ complete | — |
| infer.jxj | ✅ structurally complete | Fix import style |
| lower.jxj | ✅ structurally complete | Fix import style |
| pipeline.jxj | ⏳ needs state threading | Implement real graph_handler, env_handler state |
| mentl.jxj | ⏳ needs fixes | RUser phantom, empty handler, str_concat |
| own.jxj | ✅ complete | — |
| verify.jxj | ✅ complete | — |
| clock.jxj | ✅ complete | — |
| lexer.jxj | ✅ patched for pipes | — |
| parser.jxj | ✅ patched for pipes | — |
| emit.jxj | ⏳ not started | Port from std/backend/wasm_emit.jxj |
| runtime/ | ⏳ not started | Port from std/runtime/memory.jxj |
| main.jxj | ⏳ not started | Simple entry point |

#### Remaining Work for Phase 1

**1. ADT Ownership Resolution** (types.jxj, mentl.jxj)
- Delete stub Annotation/Capability/Explanation/Teach from types.jxj
  (lines 266-295). Correct versions live in mentl.jxj (spec 09).
- Delete stub Clock/Tick/Sample/Deadline from types.jxj. Correct
  versions live in clock.jxj (spec 11).
- Delete query.jxj (dead duplicate of pipeline.jxj code).
- Zero duplicate ADTs across the codebase.

**2. Handler State Threading** (pipeline.jxj)
- graph_handler: real flat-array state via `with nodes=[], epoch=0, next=0`.
  `graph_fresh_ty` extends array and bumps next. `graph_bind` sets node
  and bumps epoch. Occurs check refuses circular binds.
- env_handler: real scoped binding stack via `with entries=[], scopes=[]`.
  `env_extend` prepends. `env_scope_enter` pushes len. `env_scope_exit`
  truncates to mark.
- This is the critical path. Without state, handlers are inert.

**3. Pipeline Topology** (pipeline.jxj)
- compile/check/query as `|>` chains with `~>` handler attachment.
- lower_program uses `~>` (not handle-with block) for consistency.
- Capability stack comments on every `~>` line.
- Delete dead query_handler and duplicate parse_query.

**4. Fix mentl.jxj**
- `RUser(handle)` → `Fresh(handle)` (phantom Reason variant).
- Delete empty `why_default` handler (parse error).
- `str_concat("a", b, "c")` → `"a" ++ b ++ "c"`.

**5. Complete graph.jxj**
- Add `graph_reason_edge(Int, Int) -> Reason` to SubstGraphRead.
- Add handler arm in graph_handler.

**6. Import Consistency**
- All files: `import "std/compiler/graph"` (quoted, std/ prefix).

**7. Emit + Runtime + Main**
- Port wasm_emit.jxj into std/compiler/emit.jxj.
- Port runtime into std/runtime/memory.jxj (allocator as handler).
- Write main.jxj entry point.

**8. Error Catalog**
- Verify every error code referenced in source has a
  `docs/errors/<CODE>.md` entry.

#### Phase 1 Exit Gate

```
inka_compile bootstrap/tests/counter.jxj → valid WAT
inka_compile bootstrap/tests/pattern.jxj → valid WAT
Both WATs run correctly under wasmtime.
```

No duplicate ADTs. No duplicate effects. No phantom references.
All imports use quoted std/ style. Every handler threads real state.

---

### Phase 2 — Bootstrap

Build a disposable translator that compiles VFINAL once.

**Options (choose one when Phase 1 is complete):**

| Option | Effort | Notes |
|---|---|---|
| Rust translator (~3-5K lines) | ~1 week | Familiar, fast, reliable |
| Python translator (~2-4K lines) | ~1 week | Faster to write, slower to run |
| LLM-generated translator | ~1-2 days | Feed specs + source + WASM spec → one-shot |
| Hand-written WAT | ~2-3 weeks | Purest but most labor-intensive |
| Use lux3.wasm as temporary translator | ~1 day | If current Inka files happen to compile under it |

**The translator only needs to handle:**
- Inka syntax parsing (recursive descent)
- Handler desugaring (tail-resumptive → direct calls)
- Pattern matching (→ if/else chains)
- WASM emission (linear memory, bump allocator)
- String/list primitives

**The translator does NOT need:**
- Type inference (we know the types)
- Effect algebra (type-level only)
- Refinement checking (deferred to Arc F.1)
- Optimization (correctness only)

#### Phase 2 Exit Gate

```
translator compiles std/compiler/*.jxj → inka.wasm
inka.wasm validates under wasm-validate
inka.wasm runs: reads stdin, produces WAT output
```

---

### Phase 3 — First Light

Inka compiles itself. The fixed point closes.

```bash
# Inka compiles itself → first output
cat std/compiler/*.jxj | wasmtime run inka.wasm > inka2.wat
wat2wasm inka2.wat -o inka2.wasm

# Inka2 compiles itself → second output
cat std/compiler/*.jxj | wasmtime run inka2.wasm > inka3.wat

# Fixed point check
diff inka2.wat inka3.wat
# Expected: empty
```

If empty: **Morgan tags `first-light`.** The translator is deleted.
Inka is fully itself for the first time.

If non-empty: use `inka query` to diagnose. The differing sites are
concrete bugs in VFINAL. Fix in Phase 1, re-bootstrap via Phase 2.

---

## Post-First-Light Arcs

Per commitment #3: each arc is independent, scoped separately.

### Arc F — Downstream (NOT a single phase)

- **F.1 — Refinement SMT wiring.** `verify_ledger` → `verify_smt`.
  Z3/cvc5/Bitwuzla. Handler swap; source unchanged.
- **F.6 — Mentl consolidation.** Full teaching substrate. Five-op
  Teach surface. Error catalog integration. The AI-obsolescence thesis
  made concrete.
- **F.2 — LSP handler.** Query + Mentl tentacles wrapped in JSON-RPC.
  ChatLSP typed context. No new substrate; pure transport.
- **F.3 — REPL.** Replace `load_chunk`. Either compile-to-WASM per
  line or LowIR interpreter.
- **F.4 — Scoped arenas.** bump-scope, nested arenas, D.1 multi-shot
  × arena semantics.
- **F.5 — Native backend.** Hand-rolled x86 from LowIR. Capstone arc.

### Arc G — Rename (Lux → Inka)

One script, one commit. `.jxj` → `.inka`. `lux` → `inka` everywhere.

### Arc H — Examples-as-Proofs

One runnable example per framework-dissolution claim. Each 50-200
lines. Each runs. Each proves a claim from INSIGHTS.md.

### Arc I — DESIGN.md Audit

Trim to ≤500 lines. Core manifesto on one read.

### Arc J — Verification Dashboard

CI tracks `inka query --verify-debt` count per commit. Pre-F.1
measures accumulation; post-F.1 measures the trend toward zero.

---

## Spec Inventory

All twelve specs in `docs/rebuild/`:

| Spec | File | Governs |
|---|---|---|
| 00 | 00-substgraph.md | SubstGraph, flat array, O(1) chase |
| 01 | 01-effrow.md | EffRow Boolean algebra |
| 02 | 02-ty.md | Ty ADT, TRefined, TCont, Verify |
| 03 | 03-typed-ast.md | Node, Span, Expr, Stmt, Pat, PipeKind |
| 04 | 04-inference.md | HM inference, one walk |
| 05 | 05-lower.md | LowIR, LookupTy, handler elimination |
| 06 | 06-effects-surface.md | All 14+ effects, resume discipline |
| 07 | 07-ownership.md | Consume effect, affine_ledger |
| 08 | 08-query.md | Query effect, forensic substrate |
| 09 | 09-mentl.md | Teach effect, Mentl tentacles |
| 10 | 10-pipes.md | Five verbs, topology, layout rules |
| 11 | 11-clock.md | Clock/Tick/Sample/Deadline family |

---

## Research Integration (2024-2026 bleeding edge)

22 techniques from 2024-2026 papers. **None are invented here.** The
paper-worthy artifact is that Inka composes them into one mechanism.

### Techniques to ADOPT (mapped to files)

| Technique | Source | Lands in |
|---|---|---|
| **Modal Effect Types** — `⟨E₁\|E₂⟩(E) = E₂ + (E − E₁)` as a principled semantics for Inka's `E - F`. Rows and Capabilities are both encodable in modal effects. | [Tang & Lindley POPL 2025](https://arxiv.org/abs/2407.11816) · [POPL 2026](https://arxiv.org/abs/2507.10301) | effects.jxj |
| **Affect affine-tracked resume** — type-level distinction of one-shot vs multi-shot; Iris/Coq-mechanized. Directly solves Inka's D.1 (multi-shot × arena). | [Affect POPL 2025](https://iris-project.org/pdfs/2025-popl-affect.pdf) | effects.jxj |
| **Koka evidence-passing compilation** — when the graph proves a call site's handler stack is monomorphic, emit `call $h_foo` directly. Kills val_concat drift at compile time. | [Generalized Evidence Passing JFP 2022](https://dl.acm.org/doi/10.1145/3473576) | lower.jxj |
| **Perceus refcount + FBIP reuse** — precise RC + in-place update when ownership graph proves unique. Layer-2 memory fallback. | [Perceus PLDI'21](https://www.microsoft.com/en-us/research/wp-content/uploads/2021/06/perceus-pldi21.pdf) | Arc F.4 |
| **Lexa zero-overhead handler compilation** — direct stack-switching, linear vs quadratic dispatch. Makes effects free. | [Lexa OOPSLA 2024](https://cs.uwaterloo.ca/~yizhou/papers/lexa-oopsla2024.pdf) | Arc F.5 |
| **Salsa 3.0 / `ty` query-driven incremental** — flat-array substitution with epoch + persistent overlay. | [Astral ty](https://astral.sh/blog/ty) · [Salsa-rs](https://github.com/salsa-rs/salsa) | graph.jxj |
| **Polonius 2026 alpha — lazy constraint rewrite** — location-sensitive reachability over subset+CFG. | [Polonius 2026](https://rust-lang.github.io/rust-project-goals/2026/polonius.html) | graph.jxj, own.jxj |
| **Flix Boolean unification** — 7% compile overhead for full Boolean algebra over effect rows. | [Fast Boolean Unification OOPSLA 2024](https://dl.acm.org/doi/10.1145/3622816) | effects.jxj |
| **Abstracting Effect Systems** — parameterize over the effect algebra so +/-/&/! are instances of a Boolean-algebra interface. | [Abstracting Effect Systems ICFP 2024](https://icfp24.sigplan.org/details/icfp-2024-papers/18) | effects.jxj |
| **Hazel marked-hole calculus** — every ill-typed expression becomes a marked hole; downstream services keep working. | [Total Type Error Localization POPL 2024](https://hazel.org/papers/marking-popl24.pdf) | types.jxj |
| **ChatLSP typed-context exposure** — send type/binding/typing-context to LLM via LSP. Inka's `!Alloc` effect mask is free prompt budget. | [Statically Contextualizing LLMs OOPSLA 2024](https://arxiv.org/abs/2409.00921) | Arc F.2 |
| **Generic Refinement Types** — per-call-site refinement instantiation via unification. | [Generic Refinement Types POPL 2025](https://dl.acm.org/doi/10.1145/3704885) | Arc F.1 |
| **Canonical tactic-level synthesis** — proof terms AND program bodies for higher-order goals via structural recursion. | [Canonical ITP 2025](https://drops.dagstuhl.de/entities/document/10.4230/LIPIcs.ITP.2025.14) | Arc F (synthesis) |
| **Vale immutable region borrowing** — `!Mutate` on a region delivers "N readers, no writers" proof via existing effect algebra. | [Vale regions](https://verdagon.dev/blog/zero-cost-memory-safety-regions-overview) | Arc F (concurrency) |
| **bump-scope nested arenas** — checkpoints, default-Drop, directly mirrors Inka's scoped-arena-as-handler. | [bump-scope](https://docs.rs/bump-scope/) | Arc F.4 |
| **Austral linear capabilities at module boundaries** — capabilities ARE the transitivity proof. | [Austral](https://borretti.me/article/introducing-austral) | effects.jxj |
| **Liquid Haskell 2025 SMT-by-theory** — Z3 for nonlinear arithmetic, cvc5 for finite-set/bag/map, Bitwuzla for bitvectors. | [Tweag 2025](https://www.tweag.io/blog/2025-03-20-lh-release/) | Arc F.1 |
| **Elm/Roc/Dafny error-catalog pattern** — stable error codes + canonical explanation + applicability-tagged fixes. | [Elm errors](https://elm-lang.org/news/compiler-errors-for-humans) | pipeline.jxj |
| **Grove CmRDT structural edits** — edits commute; cross-module re-inference becomes a fold over commuting ops. | [Grove POPL 2025](https://hazel.org/papers/grove-popl25.pdf) | Arc F (incremental) |
| **Multiple Resumptions Directly (ICFP 2025)** — competitive LLVM numbers for multi-shot + local mutable state. | [ICFP 2025](https://dl.acm.org/doi/10.1145/3747529) | Arc F (multi-shot) |
| **Applicability-tagged diagnostics** — every "did you mean" emits a structured patch with confidence + effect-row delta. | [rustc-dev-guide](https://rustc-dev-guide.rust-lang.org/diagnostics.html) | pipeline.jxj |

### Techniques to REJECT (with one-line reason each)

- **OCaml 5 untyped effects** — self-defeating for Inka's thesis of effect-as-proof
- **Full QTT user-visible quantities** (Idris 2) — annotation burden without provability gain
- **Lean 4 tactic-as-surface** — creates a bimodal language; Inka is one expression language with holes
- **Dafny inline ghost proof bodies** — annotation burden is the adoption killer
- **Python typing-style gradual ambiguity** — "one annotation, multiple semantics" is worse than none
- **Racket teaching-language ladder (BSL→ISL→ASL)** — discrete dialects; use effect capabilities instead
- **`any` escape hatch** — AI-generated TypeScript emits `any` 9× more than human (2025). No `any` in Inka.
- **Projectional editors** — Darklang retreated 2024, Hazel stays research. Text is canonical.
- **Fractional permissions (Chalice/VerCors)** — contracts not inference; wrong direction
- **WasmGC as default memory model** — hides allocation, defeats `!Alloc`; optional backend only
- **Multiparty session types** — still academic; pairwise channel effect suffices
- **Scala 3 `^` capture syntax** — duplicate of effect rows; fractures one-mechanism thesis
- **Datalog Polonius** — officially abandoned (2026 alpha uses lazy constraint rewrite)
- **Autonomous-agent-first DX** — language so strong LLMs are dispensable, not required

### Open research questions Inka can LEAD

Each has no clean published answer; Inka shipping it IS the contribution.

1. **Effect-algebra + refinements + ownership in one decidable system.** Flix has Boolean effects. Liquid Haskell has refinements. Rust has ownership. No one combines all three with HM inference. Inka is the artifact.

2. **Strict fixed-point bootstrap as soundness test.** Byte-identical self-compilation is a stronger soundness property than any existing refinement checker. Methodology contribution.

3. **Multi-shot × scoped arena (D.1).** Affine continuations captured inside a scoped-arena handler. Affect gives type machinery; Inka designs semantics (Replay safe / Fork deny-or-copy).

4. **Cross-module TVar via DAG-as-single-source-of-truth.** Nobody has published on combining Salsa + Polonius for cross-module TVar resolution.

5. **Type-directed synthesis over effect-typed holes.** Synquid synthesizes over pure types. Nobody synthesizes over effect-row-polymorphic refined holes.

6. **Region-freeze as effect negation.** Formalizing `!Mutate ⇒ reference-coercion rights` closes Vale's result without runtime checks.

7. **`!Alloc[≤ f(n)]` quantitative refined effects.** Upgrades Boolean `!Alloc` to bounded. Enables real-time guarantees with size budgets.

8. **FBIP under effect capture.** Koka/Lean don't handle this cleanly. Inka's ownership graph knows which values are unshared — a straight IR pass suffices.

9. **Gradient rungs as handlers on one Capability effect.** Not separate checks but installations unlocking codegen paths. `Pure` installs memoization, `!Alloc` installs real-time, refinement installs SMT.

### The AI obsolescence argument — made concrete

Morgan's load-bearing claim: Inka makes current AI coding tools
dispensable. When is an AI assistant redundant? When the language
provides the three things AI is valued for:

**(a) Inference of what the AI would have filled in.**
`fn f(x: Positive) -> ? with !Alloc = ?` — the compiler knows `?` is
constrained, the synthesizer fills it, the refinement solver verifies.
The LLM was guessing what the type already specified.

**(b) Verification of what the AI would have checked.**
AI-written code that hallucinates cannot type-check — no `any` to hide
behind, effect rows and refinements are mandatory, so the hallucination
surface is zero.

**(c) Teaching the pattern the AI would have suggested.**
The Why Engine + gradient + error catalog means every hover answers
"why this type?" with the full reasoning chain. The compiler is the
tutor the AI would have been — deterministic, verified, cached.

**The one sentence:** Inka doesn't compete with AI; Inka makes AI a
handler on the same Suggest effect the compiler exposes. The code that
gets generated must satisfy types, effects, and refinements written by
humans. AI without Inka hallucinates; AI with Inka cannot.

---

## WASM as Target Substrate

WASM is the right first compilation target:

- **No GC** — Inka doesn't want one. Handlers manage memory.
- **Linear memory** — perfect canvas for bump/arena allocators.
- **Runs everywhere** — browser, wasmtime, cloud edge, embedded.
- **Someone else's maintenance burden** — Bytecode Alliance, Google.
- **Handler elimination maps cleanly** — tail-resumptive (85%) →
  direct `call`. Linear → state machine. Multi-shot → heap struct.
- **Tail call support** — wasmtime implements the proposal.
  `LTailCall` → `return_call`.

A custom VM (`inka.vm`) is not needed. WASM is sufficient. If WASM
ever proves insufficient, `wasm2c` or wasmtime AOT are escape hatches.

---

## Memory Model

| Context | Strategy | Ships |
|---|---|---|
| Compiler (batch) | Bump allocator — allocate forward, never free, exit | Phase 1 |
| Server (request-scoped) | Scoped arena handler — O(1) region free | Arc F.4 |
| Game (frame-scoped) | `own` + deterministic drop | Arc F.4 |
| Embedded/DSP | `!Alloc` — zero allocation, proven by types | Phase 1 (proof); F.4 (enforcement) |

**GC is a handler.** The bump allocator IS a handler:
```lux
handler bump_allocator with ptr = 0 {
  alloc(size) => {
    let aligned = align(ptr, 8)
    resume(aligned) with ptr = aligned + size
  }
}
```

Different programs install different handlers. No runtime GC. No
framework. Handler swap.

---

## Structural Requirements — From Day One

Four structures that MUST be in the codebase from the start. Each,
if omitted, requires re-walking every AST node or every type to
retrofit. The cost of over-designing a field is trivial; the cost
of retrofitting one is measured in weeks.

1. **Ownership annotations in the Type ADT.** `TParam` carries
   `Ownership` (`Inferred | Own | Ref`). Without it, every function
   signature is ambiguous about move vs borrow, and `own.jxj` has no
   type-level hook to track linearity. Spec: 02-ty.md.

2. **Source spans on every AST node.** Full `Span(start_line,
   start_col, end_line, end_col)` — not point positions. LSP hover,
   marked holes (Hazel), error localization, teaching-mode
   highlighting all need spans. Non-negotiable. Spec: 03-typed-ast.md.

3. **Resume discipline markers on effect ops.** `@resume=OneShot |
   MultiShot | Either`. Without this, Arc F.3 (REPL) and F.4 (arenas
   × multi-shot) must re-architect handler representation. Affects
   handler elimination tier classification. Spec: 06-effects-surface.md.

4. **Error codes as first-class Diagnostic fields.** `report` carries
   `code: String` and `applicability: Applicability`. Every `perform
   report(...)` site includes the structured code. Catalog entries in
   `docs/errors/`. Spec: 06-effects-surface.md.

**Rule:** before writing any new code, check the effect surface
(spec 06) and the ADT specs (02, 03). If the structure is there,
it's in scope. If only the runtime/handler behavior is described,
it's an F arc.

---

## Out of Scope — Audited

### Fully out of scope (not touched by Phase 1-3)

- **Native backend (Arc F.5).** Hand-rolled x86 from LowIR.
- **Projectional AST.** Rejected. Text is canonical.
- **Fractional permissions.** Shelved; Vale region-freeze via
  `!Mutate` subsumes.
- **ML / DSP framework formalization.** Downstream; uses Inka,
  not part of Inka.
- **Multi-shot × arena semantics (D.1).** Structure in specs;
  handler logic in Arc F.4.

### Structure IN scope (Phase 1), implementation OUT (Arc F)

- **Refinement types.** IN: `TRefined(Ty, Predicate)` as a Ty
  variant. Inference handles it structurally. `Verify` effect with
  `verify_ledger` accumulates `V001` obligations. OUT: Z3/cvc5
  binding that discharges predicates (Arc F.1 handler swap).

- **LSP.** IN: `inka query` IS the forensic substrate. Every query
  mode maps to an LSP method. OUT: JSON-RPC server, ChatLSP
  extensions (Arc F.2).

- **Scoped arenas.** IN: `Alloc` effect signature. `!Alloc` negation
  propagates. `own.jxj` treats `Consume` and `Alloc` as peers. OUT:
  actual `temp_arena` handler (Arc F.4).

- **REPL.** IN: `inka query` covers read-check-explain. OUT:
  execute-arbitrary-source runtime (Arc F.3).

---

## Risk Register

| Risk | Mitigation |
|---|---|
| VFINAL has bugs that surface during self-compilation | `inka query` forensics; fix in Phase 1, re-bootstrap |
| Bootstrap translator takes longer than expected | Use lux3.wasm as temporary bootstrapper if its parser handles the syntax |
| Handler state syntax (`with state = ...`) has edge cases | 85%+ of handlers are tail-resumptive → trivial to translate |
| WASM stack overflow from deep recursion | Emit `return_call` for tail calls; wasmtime supports the proposal |
| Phase 1 stretches too long | Codebase is ~80% written. Remaining work is structural fixes, not new code. |

---

## Crystallized Insights (INSIGHTS.md, 2026-04-17)

Six load-bearing truths that guide all implementation:

1. **The Handler Chain Is a Capability Stack.** `~>` ordering is a
   trust hierarchy. Outermost = least trusted. Compiler-proven.
2. **The Five Verbs Are a Complete Topological Basis.** Any directed
   graph decomposes into `|>`, `<|`, `><`, `~>`, `<~`. Proven.
3. **Visual Programming in Plain Text.** Newlines are semantic tokens.
   The shape of the code IS the computation graph.
4. **Feedback (`<~`) Is Inka's Genuine Novelty.** No other language
   makes back-edges visible and checkable.
5. **Effect Negation Is Strictly More Powerful.** `!E` proves absence.
   Rust+Haskell+Koka+Austral combined can't do this.
6. **The Graph IS the Program.** SubstGraph + Env is the universal
   representation. Everything else is a handler projection.

---

## Key Documents

| Document | Role |
|---|---|
| **docs/PLAN.md** | THIS FILE. The single roadmap. |
| **docs/rebuild/00–11** | The 12 executable specs. |
| **docs/INSIGHTS.md** | Core truths. Six crystallized insights. |
| **docs/DESIGN.md** | Language manifesto. |
| **docs/errors/** | Error catalog (E/V/W/T/P codes). |
| **CLAUDE.md** | Session anchors for AI assistants. |
