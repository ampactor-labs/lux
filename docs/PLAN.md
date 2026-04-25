# Inka — THE Plan

> **THE plan.** Singular, authoritative, evolvable. Edits land as
> commits; supersedes everything. No other document overrides this one.

---

## What this plan serves

Inka is the **ultimate intent → machine instruction medium**. Not a
programming language — a medium that sees every domain (frontend,
backend, DSP, robotics, sensors, ML, embedded, systems) through one
kernel, compiles to optimal code for every target through handler
choice, and teaches its users into better programmers through the
shape the medium imprints on their thinking.

The kernel is eight primitives (DESIGN.md §0.5, summary in
INSIGHTS.md, pointer in CLAUDE.md). Load-bearing together. Every
phase of this plan is work on the kernel (cascade-level) or work
composing handler projections from the kernel (Phase II and later).
**Nothing in this plan exists without a kernel grounding.**

The kernel, in shorthand: **(1)** Graph + Env / **(2)** handlers
with typed resume discipline `@resume=OneShot|MultiShot|Either` /
**(3)** five verbs `|> <| >< ~> <~` / **(4)** full Boolean effect
algebra with negation / **(5)** ownership as effect / **(6)**
refinement types / **(7)** continuous annotation gradient / **(8)**
HM inference live-productive-under-error with Reasons. Mentl — the
voice that reads the graph — explores hundreds of alternate
realities per second via primitive #2's MultiShot arms, and
surfaces ONE proven suggestion per turn. **Mentl is an octopus
because the kernel has eight primitives; each tentacle is one
primitive's voice surface (Query / Propose / Topology / Unlock /
Trace / Verify / Teach / Why).** The compiler IS the AI.

---

## Decisions Ledger — load-bearing commitments, dated

Every entry here is a decision that ripples across the repo and
supersedes earlier framings. Append-only; do not rewrite history
(except to fix typos).

- **2026-03-15** — Project inception as Lux (Rust prototype).
- **2026-04-18** — Lux → **Inka** rename; mascot **Mentl** (She/Her, octopus).
- **2026-04-18** — DESIGN.md v1 (manifesto, 12 chapters) frozen.
- **2026-04-19** — γ cascade closed (all handles landed substrate-complete).
- **2026-04-20** — Phase II reframed; LSP-as-paradigm dissolved into `Interact` effect; multi-shot `enumerate_inhabitants` owned by Mentl; VS Code plugin via LSP confirmed as v1 transport.
- **2026-04-20** — Nine-primitive kernel named; 9→8 merge (handlers + typed resume discipline fused) yields final eight-primitive kernel. 1-to-1-to-1 locked: primitives ↔ interrogations ↔ Mentl's tentacles. Mentl is octopus because kernel is eight.
- **2026-04-20** — Bootstrap direction: **hand-written WAT**, not Rust/C translator. Hand-WAT image IS the reference soundness artifact (kept forever, not deleted).
- **2026-04-20** — Four-pass audit sequence named: self-simulation → simplification → determinism → feature-usage, in that order, before hand-WAT.
- **2026-04-21** — **File extension: `.nx`** (flat-typography two-letter form, phonetic match to "Inka" via the nk/ks sound, zero collision verified). Supersedes `.nx`. Full migration folded into simplification/restructure.
- **2026-04-21** — **`Graph` → `Graph`** ADT rename. The substrate IS a graph; naming it Graph aligns ADT with INSIGHTS crystallization #6 ("The Graph IS the Program"). Keeps `GraphRead` / `GraphWrite` effect names unchanged.
- **2026-04-21** — **`examples/` as a miscellany directory dissolves; curated teaching content remains as `lib/tutorial/`.** *(Revised within-day after drift audit.)* Earlier framing claimed `examples/` dissolves entirely; that overstated. The dissolution is: no `examples/` dumping ground; compiler's `src/` is the reference Inka program; stdlib's `lib/` is the canonical domain demonstration; integration projects (Pulse, a-day.md) live in separate repositories. **But curated teaching content IS substance** — "how to teach the eight primitives in order" — and lives at `lib/tutorial/` as 5–10 escalating `.nx` files that Mentl's Teach tentacle narrates over. The files are runnable Inka code, not documentation; Mentl projects them into a tutorial experience. Not a directory of demos; curriculum substrate.
- **2026-04-21** — **`tests/` directory dissolves.** Training-pattern leak; tests dissolve via three collapses: (A) type system proves correctness directly (60-80% of peer-language tests disappear); (B) runnable behavior demonstrations ARE the stdlib + compiler source; (C) chaos/replay/fuzzing is handler swap via named entry-handlers declared at top-level in source. No `.test.nx` files anywhere. No separate test runner. `inka run . --with test_run` is the test invocation.
- **2026-04-21** — **Entry-handler paradigm (NOT a dedicated file).** *(Revised within-day after drift audit.)* Earlier framing claimed `run.nx` as a dedicated entry-handler file. That was Makefile/package.json-shaped drift. Correct form: entry-handlers are normal handlers declared at top-level in `main.nx` (or any imported module). CLI `--with <name>` resolves by handler symbol through ordinary import — no special filename, no manifest file. `src/main.nx` declares `compile_run`, `test_run`, `deterministic_run`, `audit_run` inline alongside `fn main`; the CLI reads the requested name and wraps `main()` in the resolved handler before emit. Handlers are handlers. No new file category.
- **2026-04-21** — **Repository interim six-directory shape** (pre-first-light): `src/` (compiler), `lib/` (stdlib, including `lib/tutorial/` for Mentl's curriculum content), `docs/` (docs), `bootstrap/` (hand-WAT), `tools/` (shell scripts for agent / git hooks), plus root-level markdown + license. No `examples/`, no `tests/`, no `std/`. **Further dissolution expected post-first-light:** `tools/` dissolves when its scripts can be rewritten as Inka programs (drift-audit becomes a handler on the graph); `docs/` partially dissolves when `doc_handler` generates from graph + `///` comments; final form probably `src/`, `lib/`, `bootstrap/`, minimal `docs/`. The six-dir shape is an honest interim template, not the terminal form.
- **2026-04-21** — **The plan itself eventually dissolves.** *(Within-day audit naming.)* This PLAN.md markdown file is a pre-first-light compromise. Post-first-light, "the plan" should be a handler projection: `plan_handler` reads graph provenance + commit history + pending-item state and speaks the plan through Mentl's Teach tentacle. The 51-item markdown list IS fluency residue (industrial-project-management shape imported from training); acceptable pre-first-light but explicitly named so it doesn't ossify as Inka-native.
- **2026-04-21** — **Hα — operator-semantics-as-handlers** named as open future-cascade handle.
  Today's BinOp + LBinOp + direct WAT emission is fixed-semantics.
  Dream form: `+` lowers to `perform add(l, r)` on parameterized
  `Arithmetic(mode: ArithMode)` effect; handler chain decides
  semantics (`Wrapping | Checked | Saturating`). Row algebra carries
  the mode. Cascade-level work — changes entire compilation pipeline.
  NOT in any current Pending Work item; surfaced during 11.B.1 audit
  as legitimate post-first-light substrate question. Walkthrough
  drafts only after first-light closes and Phase II absorbs the
  current Pending Work queue.
- **2026-04-22** — **Phase A: Substrate Truth-Telling** landed (`eafd973`).
  Eight high-priority architectural drifts and memory-safety bugs resolved:
  `row_subsumes` argument swap, `driver_extract_imports_loop` arity mismatch,
  grow-on-demand I/O buffers (replacing static 64 KiB), arity checks in
  `unify_type_lists`/`unify_args_to_params`, duplicate `MakeTupleExpr` arm
  removed, `int_to_str(INT_MIN)` + float-formatting padding bugs fixed,
  `driver_reinfer_module` → `driver_infer_module` ("no re-doing work" rule).
- **2026-04-22** — **Phase B: Cache Dissolution** landed (`7eee2b8`).
  Text-parsing cache layer dissolved; replaced with binary `Pack`/`Unpack`
  effects in `std/runtime/binary.nx`. Every Ty/Scheme/SchemeKind/EffRow/
  Ownership/ResumeDiscipline variant gets an exhaustive tag byte. The graph
  projects itself through its own effect system.
- **2026-04-22** — **`Pack` / `Unpack` effects** named as Inka's byte-direction
  primitives. Replaces the earlier exploration of Put/Get (too generic,
  collides with database/HTTP/state vocabulary), BinaryWrite/BinaryRead
  (verbose), and Encode/Decode (implies format knowledge). `Pack`/`Unpack`
  is precise, domain-free, unambiguous. Implementation: `std/runtime/binary.nx`
  with `buffer_packer` and `buffer_unpacker(source)` handlers.
- **2026-04-22** — **`|x| expr` lambda formalized** in SYNTAX.md as the canonical
  short-form lambda for inline closures. `fn (x) => expr` remains for block
  bodies. SYNTAX.md TPipe token updated to remove "(future)" qualifier.
  19 existing call sites across prelude.nx, ml/tensor.nx, dsp/processors.nx
  confirmed as canonical.
- **2026-04-22** — **Bitwise operators formally excluded.** `&` is claimed by
  effect intersection, `|` by ADT variants + pipes. XOR/shift/AND/OR don't
  pass the eight interrogations — they're hardware concerns that leak
  mechanism into vocabulary. Inka handles byte-level work through Memory
  effects (store_i32/load_i8) and Pack/Unpack effects.
- **2026-04-22** — **Unauthorized `^` operator** identified in cache.nx:78
  (used for FNV-1a XOR). Not in SYNTAX.md. Dissolved when cache.nx's text
  layer was replaced by Pack/Unpack. XOR reimplemented via byte-level
  arithmetic decomposition (bit extraction through `%` and `/`).
- **2026-04-22** — **`i32_xor` intrinsic** (`0dea2cb`). Replaced 35-line
  byte_xor arithmetic decomposition (64 division/modulus ops per i32 XOR)
  with `perform i32_xor(a, b)` — a Memory-level intrinsic the emitter
  lowers to WASM's single `i32.xor` instruction. Same pattern as
  `store_i32`, `load_i8`, `alloc`, `mem_copy`.
- **2026-04-22** — **`Memory` + `Alloc` effects declared** (`34f829e`).
  NEW: `std/runtime/memory.nx`. Memory (6 ops: `store_i32`, `load_i32`,
  `store_i8`, `load_i8`, `mem_copy`, `i32_xor`) and Alloc (1 op: `alloc`)
  were used 131+ times but declared NOWHERE. Now declared as proper effects
  with signatures. `Pure` documented as the empty effect row (keyword,
  not an effect). **Alloc separated from Memory** because `with Memory +
  !Alloc` is load-bearing for real-time audio paths.
- **2026-04-22** — **Effect declaration rule formalized:** if you can
  `perform` it, you can read its declaration. Every effect operation
  MUST have a source-level `effect` declaration. No invisible intrinsics.
  Co-location rule: **declarations live where their handlers live.**
  Current effect registry:
  - `std/runtime/memory.nx` — Memory, Alloc (substrate)
  - `std/runtime/binary.nx` — Pack, Unpack (structured byte I/O)
  - `std/compiler/types.nx` — Filesystem + 13 compiler effects (Filesystem to move to runtime in item 17')
  - `std/compiler/clock.nx` — Clock, Tick, Sample, Deadline, IterativeContext, HostClock (to move to dsp/ in item 17')
  - `std/prelude.nx` — Iterate
  - Various compiler modules — co-located with handlers
- **2026-04-22** — **Effect negation exercised** (`cc08f7f`). FV.1 moves
  from theoretical to exercised: 36 cache functions annotated with
  `with Pack + !Unpack` (18 serializers) and `with Unpack + !Pack`
  (18 deserializers). First real `!E` negation on non-trivial functions.
  Parser (parse_one_effect) and algebra (EfNeg/normalize_inter) already
  supported this; annotations were simply never applied.
- **2026-04-22** — **Parameterized effects confirmed implemented.**
  Parser: `parse_one_effect` handles `Effect(args)` syntax (parser.nx:430-447).
  Algebra: `EParameterized(name, args)` in effect name comparison
  (effects.nx:456). Types: `EffParamName` ADT. H3.1 walkthrough landed.
  Zero exercised sites in the compiler — 11.B.M (`Diagnostic(module)`)
  is the first real application. Not "future" — substrate ready, awaiting use.
- **2026-04-23** — **Bootstrap pivot: monolithic-file decision revised
  to modular `bootstrap/src/` + deterministic `build.sh` assembler.**
  Earlier 2026-04-21 decision framed the hand-WAT image as a single
  monolithic `bootstrap/inka.wat` ("auditability > editability").
  Implementation experience found the monolith unmaintainable at
  ~4,600 lines; the pivot keeps auditability (the output `inka.wat`
  is still a single assembled artifact, byte-for-byte reproducible)
  while splitting the SOURCE into 15 layered chunks under
  `bootstrap/src/` (Layer 2 lexer, Layer 3 parser, Layer 4 emit).
  `build.sh` concatenates chunks in dependency order between a
  preserved shell (Layer 0+1: module decl, WASI imports, memory,
  globals, runtime primitives) and `_start`. Output assembles with
  `wat2wasm` and validates with `wasm-validate`. Progress per last
  session: 15/15 Inka source files compile through the pipeline;
  1/15 (verify.nx) validates fully; the remaining 14 fail on
  cross-module references (expected for single-file compilation).
  **This pivot is the reference soundness artifact's new source
  form; the monolith was the fluency-preserved form that broke
  under editability.** Decision-ledger honesty: the monolith was
  overspec of auditability at editability's expense.
- **2026-04-23** — **File extension locked: `.nx` forevermore.**
  Supersedes the 2026-04-21 framing that called this settled
  (the PLAN text was sloppy on that line); Morgan explicitly
  confirmed today. All tree files are `.nx`; `.ka` and `.jxj` are
  archaeology. Memory store updated.
- **2026-04-23** — **Branch consolidation: `main` is the only
  branch.** The `rebuild` branch (cascade work + Phase A/B/C) and
  `gemini-wat` branch (Tier 1 → Tier 2 → modular-bootstrap pivot)
  collapse into `main`. Linear ancestry — all branches shared
  `33e6a52` as merge base; fast-forward only, no force-push.
  Going forward: single trunk.
- **2026-04-23** — **MSR walkthrough: multi-shot reality audit.**
  MS2's territory map audited against `src/*.nx` reality.
  Surprising finding: the oracle loop substrate is ALREADY
  implemented (`src/mentl.nx:155-175` — gradient_next +
  try_each_annotation_loop + apply_annotation_tentatively +
  verify_after_apply + trail-based rollback). ~25 of ~60 MS2
  claims are Category A (exists, bootstrap-gated). The gap is
  narrower than MS2's tone suggested: six bounded edits +
  first-light. MSR designs each:
  - **Edit 1** — MS runtime emit path (heap-captured continuation)
    → new walkthrough **H7-multishot-runtime.md** + substrate
    touching `src/lower.nx`, `src/backends/wasm.nx`,
    `bootstrap/src/emit_*.wat`.
  - **Edit 2** — `Choice` effect + `choose` MS op → new
    walkthrough **CE-choice-effect.md** + `lib/runtime/search.nx`.
  - **Edit 3** — `verify_smt` handler (Arc F.1) + theory-classifier
    → extend `src/verify.nx` + `lib/runtime/smt/` stub solvers,
    formalized under existing RT/VK walkthrough territory.
  - **Edit 4** — Arena-aware MS handlers (replay_safe /
    fork_deny / fork_copy) per DESIGN Ch 6.D.1 → new walkthrough
    **AM-arena-multishot.md** + `lib/runtime/arena_ms.nx`.
  - **Edit 5** — `race` handler combinator → `lib/runtime/combinators.nx`.
  - **Edit 6** — `lib/tutorial/02b-multishot.nx` — N-queens canonical.
  Sequencing: Phase α (BT linker + first-light-L1) → Phase β
  (six edits) → Phase γ (CRU crucibles run) → Phase δ (MV voice +
  tutorial + first-light-L2/L3). MSR names Priority-1 item 1.5
  (H7 substrate) slotted after current item 1 LFeedback. Each
  phase closes when its walkthrough-paragraph → substrate mapping
  is clean; no temporal budget.
- **2026-04-23** — **ΣU — SYNTAX unification (18 refinements A-R).**
  Comprehensive syntax audit against developer-friendliness + INSIGHTS's
  crystallized truths. Morgan + Opus reviewed every form, named every
  drift, landed 18 refinements (A-R) as one coherent amendment:

  - **A.** Remove unused reserved keywords (`loop` / `break` /
    `continue` / `return` / `for` / `in`). Imperative control-flow drift.
    Iteration via `|>`/`<~`/Iterate effect; early-exit via Abort effect.
  - **B.** Labeled call arguments (`f(label = value)`) for readability.
  - **C.** Default parameter values (pairs with B).
  - **D.** Formalize `xs[i]` indexing in SYNTAX.md.
  - **E.** Formalize nested `fn` declarations.
  - **F.** String interpolation `"{name}"` not `"${name}"` — drop
    dollar-sigil. Escape literal brace via `{{` / `}}`.
  - **G.** Single-quote `'...'` strings are LITERAL (no interpolation).
    Double-quote `"..."` interpolates. Triple-quoted forms inherit:
    `"""..."""` multi-line-interpolating; `'''...'''` multi-line-literal.
  - **H.** Optional `-> ()` on effect op declarations (absence = unit).
  - **I.** Canonicalize `resume()` not `resume(())` per Parameters-ARE-
    Tuples + No-Redundant-Form.
  - **J.** Braces REQUIRED for multi-line fn bodies (anchor for editor
    + reader). Single-line single-expr stays brace-free.
  - **K.** `if cond { body }` without `else` legal when body is unit.
  - **L.** Pattern alternation in match arms (`Some(0) | None =>`).
  - **M.** As-patterns (`x @ Some(v)` — bind whole + destructure).
  - **N.** Record spread update (`{...existing, field: new}`).
  - **O.** Trailing-comma uniformity across all list-like syntax.
  - **P.** Numeric literal underscores (`1_000_000`, `0xFF_00`).
  - **Q.** Hex / binary / octal literals (`0xFF`, `0b1010`, `0o755`).
  - **R.** No `pub`/`priv` visibility keywords — composition via
    capability effects, not modifier keywords.
  - **(prior)** Lambda unification: `(params) => body`; drop `|x|`
    pipe-fence; drop `fn (x) =>` form; `fn` keyword reserved for
    named declarations only. Zero-arg `() => expr` fills the gap
    `||` couldn't occupy (since `||` is TOrOr). Symbol `|` reduces
    to ONE clean role: type-variant separator + pattern-alternation
    (context-disambiguated, non-overlapping).

  **Symbol-role consolidation achieved:**
  | Symbol | After refinement |
  |---|---|
  | `()` | Universal function-shape bracket (params / call / unit / zero-arg) |
  | `|` | Type-variant separator + pattern-alternation (context-disambiguated) |
  | `||` | Logical OR ONLY |
  | `=` | Name-to-value binding (let, named-fn-decl) |
  | `=>` | Pattern-to-body mapping (lambda, match arm) |
  | `->` | Function-type arrow |
  | `...` | Rest/spread (patterns + types + record update) |

  Each symbol: one clean semantic role. No overloading that requires
  complex context tracking beyond what the eight interrogations
  already enforce.

  **Implications:**
  - SYNTAX.md rewritten with 18 amendments landed in a single commit
    (no versioning — Σ was the first canonical-syntax phase; ΣU is
    the unification amendment).
  - SYNTAX-exemplary sweep (new Phase B.12) touches every `.nx`
    file + every walkthrough code example to ensure the tree
    demonstrates the refinements.
  - Drift-audit patterns extended (tools/drift-patterns.tsv) to
    catch regressions: `\|x\| body` lambda-fence, `"${` dollar-sigil
    interpolation, imperative keywords, redundant `fn ()` on
    lambdas, etc.

  **Design philosophy preserved:** every refinement passes the eight
  interrogations, avoids all nine drift modes, honors "No redundant
  form" + "Layout IS contract" + "Every construct has graph
  correspondence." INSIGHTS.md crystallized truths unchanged — the
  refinements are surface-level; the kernel's eight primitives
  unmodified.
- **2026-04-23** — **SR audit: PLAN reality sweep.** Systematic
  audit of Status section + Decisions Ledger claims vs actual
  `src/*.nx` + `lib/**/*.nx`. Results in
  `docs/specs/simulations/SR-status-reality-audit.md`. Findings:
  - ~28 claims REAL (substrate confirmed by grep).
  - ~6 PARTIAL (explicit pending sub-handles).
  - ~3 ASPIRATIONAL mistaken-for-landed (tutorial stubs, IC.3
    as implicit-in-IC, `lib/tutorial/` 9-file curriculum).
  - ~5 DOCS-DRIFT (stale `docs/rebuild/` paths — swept 2026-04-23).
  - ~3 SUBSTRATE-DRIFT (duplicate `Alloc` effect name between
    `lib/dsp/signal.nx` and `lib/runtime/memory.nx`; runtime
    HandlerCatalog stayed static; main.nx pre-EH subcommand
    dispatch).
  Actions taken in this commit:
  - Swept PLAN.md for stale `docs/rebuild/` paths (18 hits
    updated to `docs/specs/`).
  - IC entry in Status §1.3 split: IC.1 + IC.2 landed; IC.3
    pending (flagged item 49); execution-gated on bootstrap-L1.
  - CLI-shape entry annotated `[IMPLEMENTATION PENDING — item 20]`.
  - Tutorial-contents entry annotated `[CONTENT PENDING 2026-04-23]`.
  Actions follow-up (own commits):
  - `AL-alloc-unification.md` walkthrough + rename sweep for
    duplicate Alloc.
  - Either `TU-tutorial.md` walkthrough + content, or MV.2's
    teach_narrative tentacle generating on-demand.
  - `tools/plan-audit.sh` script (pre-Mentl scaffolding) that
    greps Status claims against code; post-first-light becomes
    `mentl audit plan` handler projection.
  **The medium did not lie about itself.** The VFINAL compiler is
  real substrate; drift concentrated on doc edges.
- **2026-04-23** — **TH walkthrough: threading substrate named.**
  Morgan's prompt: "imagine how embarrassing it would be if Inka
  only used one core." Right. The substrate was sketched in
  DESIGN Ch 6 (Send/Sync via row) + Ch 7 (thread-local Alloc) +
  Ch 2 (`><` parallel compose) but no walkthrough specified it,
  no effect was declared, no crucible tested scaling. TH fills
  the gap:
  - **`Thread` effect** — spawn / await / current_id / num_cores.
  - **`SharedMemory` effect** — atomics (load/store/rmw) +
    wait/notify + fence for synchronization primitives.
  - **`parallel_compose` handler** — intercepts `><` branches,
    dispatches to OS threads via wasi-threads, installs
    per-thread bump_allocator. Multi-core is a handler
    installation; same source, add `~> parallel_compose`, the
    rest of the CPU lights up.
  - **Thread-local Alloc** per DESIGN Ch 7 — lock-free.
  - **Cross-thread data via Pack/Unpack bytes** — thread-safe
    by construction (no pointer crossing).
  - **Send/Sync via row subsumption** — no `T: Send` bounds;
    the compiler proves data-race freedom by walking effect
    rows, same mechanism as `!Alloc` transitivity.
  - **Graceful degradation** on WASI preview 1 / browsers
    without SharedArrayBuffer: sequential fallback; semantics
    preserved; row claims still satisfied.
  - **Sixth crucible** — `crucibles/crucible_parallel.nx` added
    to CRU §1f. Mandelbrot tile render; parallel vs sequential
    side-by-side; fitness: ≥ 2× speedup on 4-core + bit-identical
    outputs regardless of completion order.
  - **Not a keyword; not a type-class.** `Thread` is an effect;
    `parallel_compose` is a handler. The primitive is `><`;
    threading is its multi-core interpretation.
  - **Bootstrap impact:** hand-WAT needs Thread/SharedMemory
    emit path (atomics opcodes + wasi-threads imports) for L3;
    L1 unaffected (self-compile is single-threaded by intent).
  - PLAN Pending Work: TH as new Priority-2 item (alongside
    current 2 = Mentl voice); landing order is peer to β.2/β.3
    in MSR sequence.
- **2026-04-23** — **Bootstrap decomposition after MSR: L1 on
  hand-WAT, L2/L3 via Tier 3 self-hosting growth.** MSR surfaced
  that self-compile exercises `@resume=OneShot` only;
  `first-light-L1` (byte-identical diff) closes on CURRENT
  hand-WAT substrate without H7. L2/L3 of Hβ §12's Triangle
  require MS runtime (H7), adding substrate. **Original
  2026-04-20 "hand-written WAT, not Rust/C translator" decision
  stands unchanged.** Growth past L1 is via Hβ §2 Tier 3
  incremental self-hosting: VFINAL-on-partial-WAT compiles
  H7-extended `src/lower.nx` + `src/backends/wasm.nx`; diff into
  hand-WAT; integrate; audit per walkthrough paragraph. Inka
  bootstraps through Inka. Hβ §12.1-12.4 formalize this path.
  No foreign-language translator is introduced — the 2026-04-20
  rationale ("a Rust translator is ~4k lines of drift mode 1 /
  drift mode 5 risk") applies equally to Python (list-comp +
  dict drift) or any other host. Growth is via the substrate
  primitive (self-compile diff) that Hβ §2 Tier 3 named
  originally. BT §4 rewritten from timeboxed pivot criteria to
  structural continuation signals (walkthrough-paragraph
  traceability, module-by-module progress, reference-soundness
  audit). **Excises fluency drift: "N sessions" and "pivot to
  disposable translator" were project-management-shaped
  imports** (agile/scrum vocabulary + the "ship a throwaway
  translator in $OTHER_LANGUAGE" idiom). Inka measures in
  substrate clarity per walkthrough paragraph, not in temporal
  units.
- **2026-04-23** — **The Convergence: six threads keyed to the
  critical path.** Landed together as design contract before
  touching bootstrap substrate. Each thread reinforces the others:
  1. **MO-mentl-oracle-loop.md** — speculative gradient end-to-end
     (checkpoint → Synth → Verify → rollback) with concrete
     latency math. Research-risk gate for the "compiler IS the
     AI" thesis claim.
  2. **BT-bootstrap-triage.md** — per-module punch list for the
     14/15 cross-module reference failures; sequential close-out
     recommended with explicit timebox/pivot criteria (3 sessions
     or disposable translator).
  3. **CRU-crucibles.md** — five crucible `.nx` files as the
     thesis fitness function (DSP, ML, realtime, web, oracle).
     Pass/fail replaces engineering triage as the prioritization
     mechanism.
  4. **Hβ-bootstrap.md §12** — first-light is a TRIANGLE, not a
     diff: byte-identical self-compile + self-verifying refinement
     witness + cross-domain crucible pass. All three legs required
     for the first-light tag; partial passes get `first-light-L1`
     / `first-light-L2` tags.
  5. **MV-mentl-voice.md §2.9** — 20 canonical VoiceLines, one per
     (Tentacle × FormKind) surface, each compressing a graph-
     derivable proof. First-person "I" licensed only for refusals,
     multi-shot summaries, and proof-chain walks.
  6. **Five crucible `.nx` seeds under `crucibles/`** — each
     aspirational, compile-failing until its thesis substrate
     lands. Seeds drive the critical path by naming what's
     missing.
  **Why together:** each thread is load-bearing for the others —
  the oracle needs the crucibles to prove itself; the crucibles
  need the triangle to define victory; the triangle needs the
  linker (BT) to have anything to test; the voice needs the
  oracle to have something to speak; the voice also gives MV's
  §2.9 register concrete substance. Landing together avoids
  each piece ossifying in isolation and compounds the thesis.

### 2026-04-21 — pre-walkthrough decisions (hand-wave prevention)

*To prevent design sessions from exploding past safe scope when
each walkthrough lands, the following decisions are committed
inline HERE, not inside walkthroughs. Each becomes a constraint
the corresponding walkthrough must respect.*

- **`Interact` effect shape:** ONE effect with 8 tentacle ops (not 8 peer effects). Ops 1-1 the kernel primitives (`query`, `propose`, `topology`, `unlock`, `trace`, `verify`, `teach`, `why`). Plus shared ops: `focus(Cursor)`, `speak(VoiceLine)`, `edit(Patch)`, `ask(Question)`, `run_op(RunOp)`.
- **`propose`'s `enumerate_inhabitants`:** multi-shot resume per-candidate (streaming, not batch). Handler arm resumes with each verified candidate one at a time; accumulator handler collects what passes; cap N=8 branches per hole (per MV §5).
- **`speak` discipline:** one-shot per turn. One VoiceLine surfaces, gated by silence predicate. Streaming voice is not a substrate; silence is the default.
- **`Cursor` shape:** `type Cursor = { handle: Int, span: Span, intent: Option<Intent> }`. Handle is graph-native; span is human-visible; intent is declared-goal. Matches Records-Are-Handler-State-Shape (γ crystallization #9).
- **`.inka/` cache layout:** per-project root `.inka/cache/` + `.inka/handlers/` (content-addressed handler blobs). Per-user overlay `~/.inka/handlers/` consulted first via `~>` fall-through in default Package handler. Cache key is `(source_hash, handler_chain_hash)` — same source + different handler chain = different WAT; key encodes both.
- **CLI shape:** single `inka` binary, git-style subcommands. `inka --with <name>` is the universal form; subcommands are aliases: `inka compile` ≡ `--with compile_run`, `inka check` ≡ `--with check_run`, `inka audit` ≡ `--with audit_run`, `inka query <q>` ≡ `--with query_run` + arg, `inka teach` ≡ `--with teach_run`, `inka run` ≡ `--with compile_run && wasmtime output`. Bare `inka` (no args) launches Mentl over the current project (equivalent to `inka teach`); if no `main.nx` exists, Mentl offers to start from `lib/tutorial/`. **[IMPLEMENTATION PENDING — item 20.]** Today's `src/main.nx` uses pre-EH subcommand dispatch via `argv[1]` string switch (honest about its state in its own comments). EH paradigm + `--with` universal resolution lands when item 20 executes.
- **`inka new <project>` command:** creates a new project from `lib/tutorial/00-hello.nx` as template.
- **`Test` effect:**
  - `assert(cond)` — lifts to compile-time proof when `cond` is statically decidable (via `verify_assert` handler in compile-run chain); runtime check otherwise.
  - `assert_eq(a, b)` — structural equality (records by sorted fields, variants by tag + sub-eq, primitives direct); rejects closure comparison with `E_ComparesClosures` at compile time.
  - `assert_near(a, b, eps)` — explicit epsilon required; no default implicit; rejects calls missing epsilon at compile time.
- **Mentl's voice register (tiebreak chain for ranking candidates):** row-minimality → reason-chain depth (shorter = more local = preferred) → declared-intent alignment → source-span earliness → lexicographic on candidate name (deterministic fallback, load-bearing for first-light bit-identical output).
- **Mentl's voice personhood:** first-person "I" used SPARINGLY — for refusals, multi-shot summaries, proof-chain walks only. Suggestions drop first-person ("Adding `!Alloc` unlocks CRealTime", not "I suggest..."). Human addressed as "you" (pair-programmer register, not "we"). Refusals are firm + proof-linked: "I won't — `own` at line 40 forbids. Two fixes type: [#fix1] [#fix2]."
- **`lib/tutorial/` contents:** 9 files (00-08) keyed to kernel primitives:
  - `00-hello.nx` — minimum-teachable-subset (primitives 1 + 2 + 3)
  - `01-graph.nx` — primitive 1 (Graph + Env)
  - `02-handlers.nx` — primitive 2 (handlers + resume discipline)
  - `03-verbs.nx` — primitive 3 (five verbs)
  - `04-row.nx` — primitive 4 (Boolean effect algebra)
  - `05-ownership.nx` — primitive 5 (ownership as effect)
  - `06-refinement.nx` — primitive 6 (refinement types)
  - `07-gradient.nx` — primitive 7 (gradient)
  - `08-reasons.nx` — primitive 8 (HM + Reasons / Why Engine)
  Each ≤ 50 lines. Mentl's Teach tentacle walks in order. `00-hello.nx` doubles as `inka new <project>` template. **[CONTENT PENDING 2026-04-23.]** Today's 9 files exist as 1-line placeholder stubs; the 360-line curriculum is unwritten. Either a `TU-tutorial.md` walkthrough + content commit lands, or Mentl's teach_narrative tentacle (MV.2) generates content on demand from the graph. Option TBD; surfaced in SR audit §3.3.
- **Hand-WAT file organization:** single monolithic `bootstrap/inka.wat` file pre-first-light. No includes, no macros, no fragments. Auditability > editability for the reference soundness artifact. Post-first-light, if multi-file is desired, separate concern.
- **EH walkthrough scope:** absorbs the `src/main.nx` CLI rewrite (from current subcommand dispatch to entry-handler resolution). One walkthrough, complete design.

### 2026-04-21 — "Inka solves Inka" dissolutions of remaining hand-waves

*Running each previously-flagged item through the eight-interrogation
lens. Every one dissolves into existing kernel primitives + handler
composition. Nothing remains as a separate substrate question.*

- **Multi-shot × arena (D.1) dissolves** into three peer handlers on Resume + Alloc: `replay_safe`, `fork_deny`, `fork_copy`. User picks; compiler proves compatibility at handler install via row subsumption. Default v1: `replay_safe` matches trail rollback semantics. No policy-as-flag; three handlers.
- **Package effect signatures dissolve.** The three sketched ops (`fetch`, `resolve`, `audit`) collapse: `fetch` unifies with `Filesystem` as one `resolve_source(ModuleId) -> Source` where `ModuleId = LocalPath(Path) | Remote(Hash)`; handlers (`local_fs_resolver`, `hash_store_resolver`, `github_resolver`) chain via `~>`. `audit` is NOT a Package op — it's `inka audit`, a projection of primitive #4 (Boolean algebra) on GraphRead. `resolve(row)` is NOT a Package op — it's Mentl's Propose tentacle (primitive #2) asking HandlerCatalog. **One new op, unified with Filesystem. No separate Package effect.**
- **Cross-wire RPC serialization dissolves.** State struct = record. Record has canonical sorted-field layout (H2 substrate). Record bytes ARE the wire format. Function pointers cross as content-addressed hashes, resolved via `resolve_source(Remote(hash))` on receiver. No new format; composition of H2 + primitive #2 handler identity + content addressing.
- **"Terminal IDE" as a product dissolves.** Bare `inka` installs `mentl_voice_default` as minimum surface; adding `editor_handler` / `filetree_handler` / `command_palette_handler` upgrades it. Same program, different handler stack. "Terminal IDE" is industry-residue nomenclature; in Inka, it's just the handler stack the user chose.
- **`inka new <project>` dissolves** into `inka --with new_project(name="foo")` — an entry-handler with an argument. Same substrate as any `--with`. No special-case "new" mode.
- **REPL dissolves** into an entry-handler: `inka repl` ≡ `inka --with repl_run` where `repl_run` is a line-at-a-time handler reading stdin, compiling each line in current env, running, printing. Another `_run` alias. No new substrate.
- **Error triage (40 errors at once) dissolves.** Cursor-of-attention + silence predicate + one-at-a-time rule already triage: Mentl speaks about the cursor. Other errors exist in graph as `NErrorHole` nodes; human asks `inka query --all-errors` to surface them. No "triage mode"; composition of existing primitives.
- **First-invocation greeting dissolves.** Empty graph → no proof-surfaceable content → silence predicate returns "nothing to say." First VoiceLine fires when the first proof-derivable observation arises (user types first line, cursor moves to a handle with type/row/Reason content). No "greeting" substrate. Tone of what Mentl DOES say when graph is non-empty is character work (Morgan's).
- **Error catalog fate:** pre-first-light hand-maintained; post-first-light generated by `doc_handler` from `///` + graph provenance. Already in "Post-first-light dissolutions" section.
- **IDE integration beyond LSP:** LSP, DAP, custom-wire-protocol, terminal, web, plugin — each a handler on `Interact`. Already covered by "peer handlers on Interact."
- **Final subcommand-alias map** (adds REPL + new):
  - `inka` (bare) ≡ `inka --with teach_run` (Mentl over current project; silence if graph empty)
  - `inka compile` ≡ `--with compile_run`
  - `inka check` ≡ `--with check_run`
  - `inka audit` ≡ `--with audit_run`
  - `inka query <q>` ≡ `--with query_run <q>`
  - `inka teach` ≡ `--with teach_run`
  - `inka run` ≡ `--with compile_run && wasmtime output`
  - `inka repl` ≡ `--with repl_run`
  - `inka new <name>` ≡ `--with new_project(name)`
  - `inka test` ≡ `--with test_run` (dev sugar; `assert` + `assert_reporter` activated)

### What remains (not substrate — tone, implementation detail, Morgan's domain)

- Exact words in Mentl's example VoiceLines (20-line register test).
- CLI flag conventions (`--with <name>` positional vs keyword; long vs short).
- Content-addressed handler hash input (source-hash vs inferred-env-hash vs both).
- Whether CLI subcommand aliases are in-source-table or in-shell-wrapper.

**None of these trigger design sessions beyond safe scope.** They resolve as implementation encounters them or as Morgan decides register.

**The kernel is closed. The substrate is complete. What remains is mechanical transcription + handler composition.**

### 2026-04-21 — sequencing rule surfaced by drift-audit hook

*The first attempt at item 1 (LFeedback) revealed a cascade-level sequencing constraint the walkthroughs had not named.*

**The rule:** **Feature work on a file requires that file's drift-audit to be clean first.** The PreToolUse/PostToolUse hooks in the global config run `tools/drift-audit.sh` against any `.nx` file touched; a non-zero audit blocks the edit from counting as complete. Pre-existing drift in a file therefore blocks ANY edit to that file until the pre-existing drift is swept.

**What this means for item ordering:** priority substrate items (1, 2) cannot land before each target file's drift-audit is clean. If item 11's full-tree simplification hasn't run yet, each file must get a **narrow per-file drift sweep** as a pre-gate before feature work lands on it.

**New substrate discipline pattern:** before any feature-adding commit to a `.nx` file whose audit is non-zero:

1. Inspect pre-existing drift hits.
2. Apply narrow simplification to that file (rewrite drift-9 comment phrasing; suppress false-positive drift-12 matches ONLY where they're heuristic false-alarms for actually-mode-8 drift tracked for real item-11 sweep; convert real drift where scope permits).
3. Verify `drift-audit.sh <file>` exits 0.
4. Execute the feature-adding edit.
5. Verify audit remains 0.

**Tracked known-drift-sites (discovered during item 1 attempt, pending real fix at item 11 execution):**

- `src/backends/wasm.nx` (pre-restructure: `std/compiler/backends/wasm.nx`):
  - Line ~1387 `fn emit_binop(op: String)` + match on string literals `"+"`, `"=="`, `"<"`, etc. → **real drift mode 8 (string-keyed-when-structured);** should be `BinOp` ADT. Requires multi-file refactor touching `types.nx` (add `BinOp` ADT), `parser.nx` (construct BinOp not String), `infer.nx` (match BinOp in BinOpExpr arm), `lower.nx` (LBinOp carries BinOp), `wasm.nx` (match BinOp in emit_binop). **Tracked as simplification-sub-pattern for item 11 commit 11.B (drift-mode screen). For item 1's pre-gate, the ONE flagged line (the `"==" =>` arm which both drift-12 regexes happen to match) is suppressed with `// drift-audit: ignore` + explanatory comment.**

**This is the hook working exactly as intended.** The hook is not over-gating; it's enforcing the substrate discipline that simplification must lead feature work. The walkthrough underspecified by not naming the pre-gate constraint. Now named.

### 2026-04-21 — REVISED: dotted names ARE env entries (not modules-as-records)

*Initial framing was "modules ARE records at the type level." Running the eight interrogations at implementation time revealed that framing was drift-1-adjacent (record-of-functions namespace, from Rust/Haskell habits). The Inka-native resolution is simpler AND smaller.*

**The reframe.** Dotted names (`graph.chase`) are not record field accesses — they are **env entries with qualified keys**. The graph ALREADY stores `(name, Scheme, Reason, SchemeKind)` entries in env via `env_extend`; names are already strings. A qualified name like `"graph.chase"` is just another valid env key. **No new type variant. No module record. No record-of-schemes.**

**Substrate mechanics** (~15 lines total across driver.nx + infer.nx):

1. **In `driver.nx`'s install path** (~10 lines). After flat-installing each export `(name, scheme, reason, kind)` from an imported module, ALSO install `(module_short_name ++ "." ++ name, scheme, reason, kind)` as a second env entry with the qualified key. `module_short_name` = last path segment of the import path (e.g., `compiler/graph` → `graph`).

2. **In `infer.nx`'s `FieldExpr` arm** (~5 lines). Before constraining to record unification, check if the assembled dotted string (`left_side_name ++ "." ++ field`) resolves in env. Hit → use that binding's scheme. Miss → fall through to existing record-field-access path.

**Why this is Inka-native:**
- Graph? — env entries already keyed by names (strings); dotted names are more-qualified strings. Same substrate.
- Handler? — `env_lookup` is the existing handler. No new handler. No new effect.
- Verb? — no verb change; `graph.chase(h)` is still a unary call on a resolved name.
- Row? — no row change.
- All other interrogations: N/A.

**Drift modes avoided** (and named):
- **Drift 1 (Rust vtable)** — NOT building a record-of-functions namespace. Just env entries. The record-of-functions interpretation was the fluency-trap; this reframe avoids it.
- **Drift 6 (primitive-type-special-case)** — modules are not a special kind of thing; they contribute env entries like every other declaration.
- **Drift 8 (string-keyed-when-structured)** — the string IS the structured form here; env already keys by strings; dotted is more-structured-via-prefix, not less.

**Same mechanism. Same env. More entries.** No new type variant, no new handler, no new effect.

**Consequences for NS-naming §1.1:** the "modules-as-records" framing is superseded. The dot-access convention (`graph.chase(h)` instead of `graph_chase(h)`) becomes a mechanical rename + two env-extension + fieldexpr-arm extensions. Scope shrinks from "~30 lines of infer extension" to "~15 lines across driver + infer."

**This is the LAST substrate decision gating walkthroughs.** Everything past this is mechanical transcription or handler composition.

---

## Status — 2026-04-24 (kernel structurally closed — all 8 primitives substrate-live; first composition demo lands; next phase is composition + bootstrap, not invention)

**Kernel-closure milestone (insight #13, commit `9a726f2`):** with B.9
LFeedback emit landing (commit `7f8ff5f`), Primitive #3 (Five verbs)
joins the others — every kernel primitive now has substrate-live LIR
support, emit support, ≥1 handler implementation, and composes with
the rest. First composition demo: `lib/dsp/feedback.nx` (commit
`bba8d4d`) draws IIR filters via `<~ delay(1)` exercising five
primitives in one row.

**The next phase is composition, not invention.** B.10/B.11 Ultimate
domain rewrites, MV.2.e Interact handler arms, items 11.A/11.D
simplification audit, then bootstrap items 26-31 — each composes on
the closed kernel, none extends it.

**This-run substrate landed (12 commits):** H7 multi-shot keystone +
emit walker arms + capture-store helpers (4236b96 + ad78384 +
bafd63a); B.3 Choice (55553ad); B.4 race + first_verified_wins
(3da8d79); B.5 arena_ms replay_safe / fork_deny / fork_copy
(78075ee); C.1 six crucible seeds (ca12cf8); MV silence_predicate
queue-projection refactor (7fb8871); B.7 Thread + SharedMemory +
parallel_compose (8508417); B.9 LFeedback emit completion +
state-globals prologue (7f8ff5f); insight #13 kernel-closure
crystallization (9a726f2); B.10 first composition demo
`lib/dsp/feedback.nx` (bba8d4d); plus prior-run setup (b35c239
cache_map; a2edd50 graph_mutated at commit boundary; 4830a25
Realization Loop insight #12).

---

## Status — 2026-04-21 (γ cascade closed; all seven pre-migration walkthroughs LANDED; migrations + audits + bootstrap sequenced)

- **Specs.** Twelve specs in `docs/specs` plus `docs/SYNTAX.md`
  (Σ phase, canonical syntax). Read them as declarative contracts;
  update them when the code teaches us something better.
  *(Restructure item 17' relocates to `docs/specs/00–11`; spec 00
  retitled to `00-graph.md` reflecting `Graph → Graph`.)*
- **Cascade walkthroughs.** `docs/specs/simulations/H*.md` — one per
  handle. Each resolves design before code freeze. Riffle-back
  addenda capture how prior decisions read in new substrate.
  *(Restructure item 17' relocates to `docs/specs/simulations/`.)*
- **γ cascade — CLOSED.** All handles + their surfaced peers landed:
  Σ (SYNTAX.md), Ω.0–Ω.5 (audit sweeps + parser refactor + frame
  consolidation), H6 (wildcard audit), H3 (ADT instantiation),
  H3.1 (parameterized effects), H2 (structural records),
  HB (Bool transition + heap-base discriminator),
  H1 (full evidence wiring: substrate cleanup + BodyContext +
  LEvPerform offset arithmetic + LDeclareFn handler arm indexing
  + transient evidence at poly-call sites),
  H4 (full region escape: substrate + tag_alloc/check_escape sweep
  + region-join for compound-type field stores),
  H2.3 (nominal records), H5 substrate (AWrapHandler annotation +
  AuditReport records + severance enumeration + capability unlocks +
  static handler catalog).

- **γ cascade — future polish (not blocking):**
  - **Runtime HandlerCatalog** — convert today's static
    catalog_handled_effects table to an effect-based handler with
    runtime registration. Lands when user-level handler discovery
    is exercised (LSP integration, IDE handler picker).
  - **Gradient-candidate oracle** — verify-then-suggest pipeline
    for Mentl's I15 propositions (checkpoint → speculative
    annotation → re-infer → verify or rollback). Substrate
    (Synth effect, mentl_default handler, AWrapHandler arm) is
    in place; the oracle integration is its own focused pass.

- **Phase II landings (post-cascade, in-session):**
  - **FS substrate** (1debfdc) — Filesystem effect + WASI preview1
    path_open / fd_close / path_create_directory /
    path_filestat_get + wasi_filesystem handler. First post-
    cascade effect; exercises the substrate's discipline for
    adding new effects cleanly.
    Walkthrough: `docs/specs/simulations/FS-filesystem-effect.md`.
  - **IC.1 + IC.2 landed** (0116d5d, 573879c, b0008dd, 0b27b0c) — cache.nx
    (KaiFile record, FNV-1a hash, env serialization round-trip),
    driver.nx (DAG walk + cache hit/miss + env install),
    pipeline+main wiring through driver_check. `inka check
    <module>` operates incrementally; first post-cascade
    closure of drift mode 10 ("the graph as stateless cache").
    **IC.3 (graph chase walks per-module overlays) PENDING — item 49.**
    driver.nx top-comment flags: "Per-module env install merges
    flat into env_handler (no per-module overlay separation yet);
    per-module overlays land with IC.3's chase extension."
    **Execution-gated on bootstrap-L1** per MSR; IC substrate is
    live in `src/` but doesn't run until bootstrap closes.
    Walkthrough: `docs/specs/simulations/IC-incremental-compilation.md`.
  - **Phase A — Substrate Truth-Telling** (eafd973) — eight high-priority
    logic/memory-safety fixes across effects.nx, graph.nx, driver.nx,
    cache.nx, infer.nx, lower.nx, strings.nx, io.nx.
  - **Phase B — Cache Dissolution** (7eee2b8) — text-parsing cache layer
    dissolved. NEW: `std/runtime/binary.nx` (Pack/Unpack effects +
    buffer_packer/buffer_unpacker handlers). cache.nx rewritten from
    text serialization to binary Pack/Unpack (503 ins, 416 del).
    cache_compiler_version bumped to v3.

- **Integration trace (post-cascade):** `docs/traces/a-day.md`.
  One developer, one project (Pulse: real-time audio + browser UI +
  cloud server + training variant), one day. Every surface either
  fires `[LIVE]`, is `[LIVE · surface pending]`, or is one of two
  named substrate gaps post-reframe: **LFeedback state-machine
  lowering** (item 1) and **Mentl-voice substrate** (item 2, which
  absorbed the former teach_synthesize and HandlerCatalog gaps).
  Supersedes the per-domain DESIGN.md Ch 10 simulations as the
  integration artifact (those remain for thesis-level promises).
- **Bootstrap approach.** Hand-written WAT, not a Rust/C translator
  (decision 2026-04-20). Hand-WAT IS the reference soundness
  artifact; kept forever, not deleted. Item 26+ of Pending Work.
- **Four-pass audit sequence:** self-simulation → simplification →
  determinism → feature-usage, in that order, gating bootstrap.
  Items 11 + 23–25 of Pending Work.
- **Eight-primitive kernel locked.** 1-to-1-to-1 with Mentl's eight
  tentacles and the eight interrogations. See DESIGN.md §0.5 for
  the authoritative enumeration.
- **Error catalog.** String-coded (prefix-kind + self-documenting
  suffix). See `docs/errors/README.md` for the convention.
- **Language rename:** Lux → **Inka** (mascot: **Mentl**, She/Her, an octopus).
- **File extension:** `.nx` (decided 2026-04-21). Two letters,
  flat typography (no ascenders / descenders), zero collision
  verified, phonetic match to "Inka" via the N-K sound. Supersedes
  `.nx`. Migration is item 10 of Pending Work.
- **Repository shape:** six top-level directories (`src/` compiler,
  `lib/` stdlib, `docs/` docs, `bootstrap/` hand-WAT, `tools/`
  scripts, plus root markdown + license). No `examples/`, no
  `tests/`. Item 17' of Pending Work; shape IS the canonical Inka
  user-project template.

---

## Pending Work — single source of truth, exhaustive

Every item below is the work remaining between today and first-light,
with status, dependencies, scope, walkthrough reference, and
deliverables. Strictly ordered by dependency. Each item marked
`[PENDING]` / `[IN-FLIGHT]` / `[LANDED]` / `[DEFERRED]`. When an item
lands, mark `[LANDED]` here AND update the matching tag in
`docs/traces/a-day.md` where applicable.

**Legend:**
- 📋 = walkthrough (design document); lands as a file in `docs/specs/simulations/` before code freezes
- ⚙️ = substrate (code-level change)
- 🔁 = migration (repo-wide mechanical change; one focused commit)
- 📖 = documentation update (cross-cutting; folds into related work)
- 🧪 = audit pass (exhaustive review; produces inventory / diff / report)
- 🌱 = seed artifact (new file establishing a convention)

### Critical path overview

```
Priority 1 substrate gaps  (items 1-3)
        │
        ▼
Walkthroughs for naming + restructure + entry-handlers  (items 4-9)
        │
        ▼
Simplification + structural migration  (items 10-22)
        │
        ▼
Self-simulation + determinism + feature-usage audits  (items 23-25)
        │
        ▼
Bootstrap walkthrough + hand-WAT + first-light  (items 26-31)
        │
        ▼
Post-first-light handler projections  (items 32-49)
```

Items 4–22 are the "pre-bootstrap" block — design, simplify,
restructure, migrate extension, rename Graph. Items 23–25 are the
three audits that confirm readiness. Items 26–31 are bootstrap
itself. 32+ are post-first-light surfaces.

---

### Priority 1 substrate gaps (in-flight; close these before bootstrap prep begins)

1. **⚙️📋 `LFeedback` state-machine lowering.** **`[LANDED 2026-04-24]`** — commits `7f8ff5f` (B.9 emit) + `bba8d4d` (B.10 first composition demo).
   - Walkthrough `docs/specs/simulations/LF-feedback-lowering.md` (item 9) closed first.
   - Substrate: `src/backends/wasm.nx` collect_state_slots walker + emit_state_globals prologue + LFeedback emit completion (load-prior → emit body → tee-current → store-current → reload). `src/cache.nx` cache_compiler_version 4→5.
   - Closes Primitive #3 (Five verbs) — the kernel is structurally complete (insight #13, commit `9a726f2`).
   - First composition demonstration: `lib/dsp/feedback.nx` (commit `bba8d4d`) exercises `<~ delay(1)` end-to-end with refinement-typed Hz/Sample/Gain.
   - **Peer sub-handles named (each lands in its own commit):**
     - **LF.B** — Body-binding for prior. Parser + lower so `(prev) => f(input, prev)` resolves `prev` to `$__fb_prev_<h>`. Pre-LF.B body LIR sees current input only; structural shape emits but numerics await this handle.
     - **LF.M** — Handler-state-offset migration. Replaces module `$s<h>` globals with per-handler-state slots; required for threading × MS soundness.
     - **LF.1 / LF.2 / LF.3** — FbDelay(N>1) ring-buffer / FbState(init) typed carrier / FbFilter(N, coeffs) N-tap spec. Per LF walkthrough §10.
     - **LF.S** — verify_smt discharge of refinement obligations on Sample/Hz/Gain bounds (folds into Arc F.1).

2. **⚙️📋 Mentl-voice substrate.**
   - Status: `[IN-FLIGHT]` — walkthrough **§2 CLOSED 2026-04-21** (Situation record, VoiceLine shape, 8-tentacle × 8-FormKind mapping, 16-phrase modifier bank, silence predicate formal, turn anatomy via LSP methods, 10 acceptance tests AT1–AT10 locked as `mentl_voice_default` contract). Substrate **partial-LANDED** — silence_predicate + queue-projection refactor (commit `7fb8871`); oracle keystone (commit `f87abf3`); Tier 2 silence-as-queue-empty + tier_to_tentacle (commits Tier 2 of insight #11).
   - Remaining (MV.2.e): Interact handler arms (22 ops × handler bodies) + LSP adapter handler.
   - Deliverable: `Interact` effect declaration ✓ + `mentl_voice_default` 8-tentacle queue-projection ✓ + silence predicate ✓ + LSP adapter handler PENDING + VS Code extension package PENDING.
   - Depends on: nothing substrate-wise; §2 closure unblocks remaining MV.2.e implementation.
   - Gate for: VS Code plugin v1 shipping. NOT gating for bootstrap — Mentl-voice code can land post-first-light if needed.
   - Scope remaining: ~400–600 lines `.nx` (Interact handler arms + lsp_adapter.nx) + ~300 lines TypeScript extension glue.
   - Acceptance: `mentl_voice_default` correct iff AT1–AT10 (§2.8 of walkthrough) render as specified.

3. **⚙️ Three-gap residue swept.**
   - Status: `[DEFERRED INTO ITEMS 1+2]`. The three former Priority 1 gaps (LFeedback, teach_synthesize conductor, HandlerCatalog) are now: #1 LANDED; #2 and #3 were inside item 2 (both substrate-landed; only handler arms + LSP adapter remain).

---

### Walkthroughs to draft before migrations freeze (Anchor 7: walkthrough-first)

*All seven walkthroughs drafted 2026-04-21 in one focused session.*

4. **📋 `NS-naming.md`** (naming-audit walkthrough). **`[LANDED 2026-04-21]`** — 560 lines.
   - Covers: dot-access module convention (eliminates `module_fn` C-style prefixes); `lexer.nx`→`lex.nx` + `parser.nx`→`parse.nx` rename; `Graph → Graph` ADT rename; effect-name normalization (`HostClock` merged into Clock; `IterativeContext` dissolved into row constraint); docstring consistency (canonical template per module); delete `SYNTHESIS_CROSSWALK.md`; modules-as-records inference extension.
   - Gate for: item 11 simplification audit execution.

5. **📋 `NS-structure.md`** (structural-reshape walkthrough). **`[LANDED 2026-04-21]`** — 662 lines.
   - Covers: six-directory top-level (`src/`, `lib/`, `docs/`, `bootstrap/`, `tools/`, root). Maps every current file to new path. `lib/tutorial/` 9-file curriculum (00-hello + 01..08 per kernel primitive). `bootstrap/README.md` + `first-light.sh` scaffold. `.inka/` gitignored cache layout. README's "Repository layout" as canonical template. Post-first-light dissolutions named.
   - Gate for: item 17' structural migration.

6. **📋 `EH-entry-handlers.md`** (entry-handler substrate walkthrough). **`[LANDED 2026-04-21]`** — 700 lines.
   - Covers: entry-handlers as normal top-level handler declarations (NOT a dedicated file). CLI `--with <name>` universal form + subcommand alias table (compile/check/audit/query/teach/run/repl/test/new). `src/main.nx` rewrite from subcommand dispatch to entry-handler resolution. `Test` effect (assert + assert_eq + assert_near) + `assert_reporter` + `verify_assert` compile-time-lifting handler. Seven new error codes for the catalog.
   - Gate for: item 20 CLI `--with` substrate implementation.

7. **📋 `SIMP-simplification-audit.md`** (simplification-pass discipline walkthrough). **`[LANDED 2026-04-21]`** — 273 lines.
   - Covers: the eight-interrogation + nine-drift-mode pass methodology; per-site rewriting rules; 6-commit sequence for execution (11.A naming sweep → 11.B drift-mode screen → 11.C bug-class screen → 11.D eight-interrogation audit → 11.E docstring harmonization → 11.F cleanup/deletion).
   - Gate for: item 11 simplification audit execution.

8. **📋 `DET-determinism-audit.md`** (determinism-audit discipline walkthrough). **`[LANDED 2026-04-21]`** — 330 lines.
   - Covers: 10 determinism rules (canonical iteration order, no timestamps, no random seeds in emit, canonical number formatting, etc.); single-process double-compile test; cross-session test; `tools/determinism-gate.sh` regression harness; non-determinism detection patterns.
   - Gate for: item 24 determinism audit execution.

9. **📋 `LF-feedback-lowering.md`** (`<~` state-machine lowering walkthrough). **`[LANDED 2026-04-21]`** — 364 lines.
   - Covers: LFeedback lowering for `delay(1)` (v1 scope); state-slot allocation in enclosing handler's state record; `$fb_prior`/`$fb_current` WAT pattern; ~100-line rewrite of `LFeedback` emit arm in `src/backends/wasm.nx`; sub-handles LF.1/LF.2/LF.3 for delay(N), accumulate, filter_spec (post-first-light).
   - Gate for: item 1 LFeedback implementation.

10. **📋 `Hβ-bootstrap.md`** (final cascade handle — hand-WAT walkthrough). **`[LANDED 2026-04-21]`** — 371 lines.
    - Covers: 12 WAT emission conventions (HEAP_BASE invariant, graph layout, closure records with NO vtable, tail calls, match dispatch, string/list/tuple/record/row layout, feedback slots, entry-handler installation); three-tier hand-WAT structure (Tier 1 runtime → Tier 2 template-expansion → Tier 3 incremental self-hosting); ~200-line expander script approach.
    - Gate for: items 27-30 (hand-WAT writing + first-light harness).

*(Renumbering: the original "9. Hβ-bootstrap" becomes item 10 to accommodate LF-feedback-lowering as item 9; LFeedback is now specified by LF walkthrough (item 9) and implemented as item 1 separately. No cascade inconsistency — LF's walkthrough is the 9th walkthrough drafted; LFeedback lowering is the 1st Priority 1 substrate item to implement.)*

---

### Extension + Graph rename propagation (folded into simplification audit)

10. **🔁 `.nx` → `.nx` migration.**
    - Status: `[PENDING]`.
    - Deliverable: every `.nx` file renamed to `.nx`; every reference in every doc, memory file, comment, CLAUDE.md, README.md, DESIGN.md, PLAN.md, SYNTAX.md, INSIGHTS.md, errors/README.md, every spec, every walkthrough, every tool script, `.gitignore` updated for `.inka/` cache directory pattern; drift-audit.sh patterns updated if any reference `.nx`.
    - Depends on: walkthrough closure for items 4, 5.
    - Lands with: items 11–22 (single simplification+restructure commit or tightly-sequenced commits).

11. **🧪⚙️ Simplification audit execution.**
    - Status: `[IN-FLIGHT]` — 11.A partial (smoke test landed); 11.B **LANDED 2026-04-21**; 11.C pending.
    - Deliverable: every site in every `.nx` file rewritten to residue form per item 7's discipline. Includes: dot-access conversion (Finding 1 — ~548 `fn` declarations lose module prefixes; every call site rewritten); lex/parse rename; `Graph → Graph` rename; effect-name normalization; delete SYNTHESIS_CROSSWALK.md; drift-mode audit per file.
    - Depends on: item 4 walkthrough, item 7 walkthrough.
    - Gate for: items 23–25 audits.
    - Expected diff: 10-20% line reduction in `src/`; higher in what was `std/runtime/`.
    - **Commit sequence (per SIMP §7):**
      - **11.A** — Pass 1 naming sweep. Status: `[PARTIAL]`. Smoke test for dot-access at `cache.hash_source` landed in Phase II corpus commit `773f879`. Full sweep across remaining modules (driver_*, mentl_*, parse_*, lower_*, infer_*) pending post-11.B.
      - **11.B** — Pass 2 drift-mode screen (modes 1-9). **LANDED** via three sub-commits:
        - `773f879` — 11.B.1 BinOp + BinOpKind ADT (drift mode 8 cure at operator dispatch).
        - `94389fb` — 11.B.2 lexer.nx byte-native refactor (drift mode 12 cure; 14 hits).
        - `b1a2bf0` — 11.B.3 prelude.nx trim + parse_int byte-native (drift mode 12 cure; 2 hits).
        Full std/ tree (29 .nx files) drift-audit CLEAN post-11.B.3.
      - **11.C** — Pass 3 bug-class screen. Status: `[IN-FLIGHT]` — 11.T + 11.C.0 + 11.C.1 landed; 11.C.2 + 11.C.3 pending walkthroughs.
        - `944f443` — **11.T** drift-audit mode-11 regex fix (character-class escape; surfaced 22 previously-masked drift-11 hits).
        - (within `4bddfe4`) — **11.C.0** inline suppressions for 5 false positives (lower.nx one-time LBlock appends + prose comment + frame-record paired-list tracked for 11.C.2).
        - `4bddfe4` — **11.C.1** buffer-counter sweep for 13 genuine tail-recursive accumulator loops (lower/cache/driver/infer/wasm).
        - **11.C.2** — `[PENDING WALKTHROUGH]`. Frame-record paired-list restructure at lower.nx:1177/78 (local_handles + local_order both `++ [x]` in handler-arm record update). Requires frame-record field restructure (list→buffer+counter pair) or introduction of O(1) snoc primitive. Walkthrough-worthy substrate design.
        - **11.C.3** — `[WALKTHROUGH LANDED 2026-04-21]` — see `docs/specs/simulations/HC-handler-composition.md`. Pattern locked: **transform emits; materialize captures; `~>` composes.** Prelude refactor (map_h / filter_h / take_h / skip_h re-yield; collector captures via buf+count; sum_h / count_h as peer materializers) ready for implementation. Pattern ripples to 11.C.2 (frame-record as OrderedMap materializer), 11.B.M (Diagnostic module-parameterized materializer), Hα (Arithmetic(mode) materializer), and MV.2 (tentacles transform; LSP surfaces materialize). **HC is upstream of 4 downstream handler-composition moves.**
        - **11.C.4** — `[PENDING]`. Post-walkthrough bug-class screens: `_ => <fabricated>` sweep, `str_eq(a,b) == 1` Int-return anti-pattern check, `println` in report arms audit. Currently drift-audit-clean; may surface during 11.D semantic pass.
      - **11.D** — Pass 4 eight-interrogation audit (semantic).
      - **11.E** — Pass 5 docstring harmonization.
      - **11.F** — Cleanup (delete SYNTHESIS_CROSSWALK.md, etc.).
    - **Named peer sub-handles (land in their own commits inside 11.B / post-11):**
      - **11.B.1.R** — Refinement-typed `op_to_binop` parameter (primitive #6 exercise).
        Scope: refactor `fn op_to_binop(k)` from `Option<BinOp>` return to
        `fn op_to_binop(k) -> BinOp where is_binop_token(k)` refinement
        form; add `is_binop_token(k)` predicate; Verify discharges the
        refinement at the caller site in `binop_loop`. Eliminates the
        unreachable-ICE arm from 11.B.1. Lands post-11.B simplification-
        audit when refinement ledger substrate is exercised by Phase II.
      - **11.B.M** — Diagnostic module parameterization (primitive #2 parameterized-effect exercise).
        Scope: `effect Diagnostic(module: ModuleName) { report(...) }`;
        replace every `perform report("module_name", ...)` call site
        with `perform report(...)` under a module-parameterized handler
        installed at module entry. Dissolves drift mode 8 across every
        `report` call-site in the compiler. ModuleName ADT: ModParser,
        ModInfer, ModLower, ModWasm, ModDriver, ModCache, ... Row algebra
        distinguishes `Diagnostic(ModParser)` from `Diagnostic(ModInfer)`.
        Cross-cutting refactor; lands as its own focused commit.
      - **11.T** — drift-audit regex fix for mode 11 (bug-class tooling gap).
        Scope: `tools/drift-patterns.tsv` mode 11 regex `\+\+\s*\[[^\]]*\]`
        fails on multi-character contents inside brackets under GNU grep
        3.12's ERE (the escaped `\]` inside the character class parses
        inconsistently). Fix: `\+\+\s*\[[^]]*\]` (remove the backslash
        escape inside the class). Post-fix, mode 11 catches the 7 files
        currently masked: prelude.nx (4 hits in Iterate handler arms),
        cache.nx (3), driver.nx (1), pipeline.nx (1, suppressed), wasm.nx
        (4, one suppressed), lower.nx (1), infer.nx (2). Lands as the
        first commit inside 11.C; subsequent 11.C commits sweep the
        now-visible hits via buffer-counter substrate.

12. **📖 DESIGN.md updates**: `Graph → Graph` in §0.5 + Ch 4 (~40 refs); Ch 8 tentacle list verification; Ch 9.1 packaging rewrite (`.inka/` cache + `~>` as manifest); Ch 9.2 testing rewrite (entry-handler + `run.nx` paradigm; "no `tests/` directory" as substrate claim); Ch 9 examples-dissolution note; every Ch 10 scenario's file paths updated; extension `.nx → .nx` throughout.

13. **📖 INSIGHTS.md updates**: kernel shorthand `Graph → Graph`; any `std/compiler/` path refs; extension throughout.

14. **📖 CLAUDE.md updates**: Mentl's anchor kernel refs `Graph → Graph`; interrogation #1 refs; file map (every `std/compiler/X.nx` → `src/X.nx`); file-extension line (`.nx` → `.nx`); bug-classes path refs.

15. **📖 README.md updates**: kernel enumeration `Graph → Graph`; Repository layout rewritten to six-directory template; extension `.nx → .nx`.

16. **📖 SYNTAX.md updates**: file extension throughout; entry-handler declaration form (new section: `handler name_run { ~> stack }`); `Test` effect interaction; layout + token refs where `.nx` appears.

17. **📖 PLAN.md updates**: (this file, being updated now) — extension finalized; restructure step tracked; examples-dissolution tracked; `run.nx` substrate tracked; all future pending work rolled into item list.

18. **📖 errors/README.md updates**: extension; any file refs.

19. **📖 Per-spec files `docs/specs/00-11`**: 
    - `00-graph.md` retitled to `00-graph.md`; body rewritten to use `Graph`.
    - Cross-spec references to old paths updated.
    - Extension `.nx → .nx` in all examples.
20. **📖 All walkthroughs `docs/specs/simulations/`**: `HB`, `H1-H6`, `H2.3`, `H3.1`, `FS`, `IC`, `MV`, `TS` — each scanned for `Graph`, `std/compiler/` paths, `.nx` extension; updated.

21. **📖 `docs/traces/a-day.md`**: extension `.nx → .nx` and any path refs.

22. **📖 Memory files (`~/.claude/projects/-home-suds-Projects-inka/memory/`)**:
    - `MEMORY.md` index: extension / path refs.
    - `project_canonical_docs.md`: path refs.
    - `project_extension_ka.md`: REWRITE (or delete + new memory `project_extension_nx.md`) for `.nx`.
    - `project_mentl_voice_reframe.md`: `Graph` refs.
    - Every other memory scanned for path / Graph / extension refs.

---

### Structural migration (one focused commit, gated on item 5 walkthrough)

Lands after items 10-22 so simplification + extension migration ride through alongside restructure, avoiding twice-churn of call sites.

17'. **🔁 Directory restructure** — single commit:
- `std/compiler/*` → `src/*`
- `std/compiler/backends/` → `src/backends/`
- `std/runtime/` → `lib/runtime/`
- `std/prelude.nx` → `lib/prelude.nx`
- `std/test.nx` → `lib/test.nx`
- `std/types.nx` merged into `lib/prelude.nx` (absorbed)
- `std/dsp/` → `lib/dsp/`
- `std/ml/` → `lib/ml/`
- `docs/specs/` → `docs/specs/`
- `docs/specs/simulations/` → `docs/specs/simulations/`
- `bootstrap/` created with `README.md`, empty `inka.wat`, `first-light.sh` scaffold
- `lib/tutorial/` directory created with 5–10 escalating `.nx` files (curriculum content; Mentl's Teach tentacle narrates over these) — NOT a "starter template"; substantive teaching substrate
- Entry-handlers (compile_run / verify_run / deterministic_run / audit_run) declared at top-level in `src/main.nx` (NOT a separate `run.nx` file — corrected 2026-04-21)
- Every `import X` statement in every `.nx` file updated to new paths
- Every doc path reference updated
- `.gitignore` updated for `.inka/` cache
- README's Repository layout rewritten as canonical template

(Numbered 17' so it lands between items 17 and 23 in execution order without renumbering everything below.)

---

### Audit passes (gated on items 10–17' closing)

23. **🧪 Self-simulation audit of VFINAL source.**
    - Walk every `src/*.nx`, `lib/*.nx` through lex → parse → infer → lower → emit (on paper or via the self-hosted pipeline). Any site that would yield `NErrorHole` at LIR or blocking V_Pending is a correctness bug to fix. Walkthrough `SSA-self-simulation.md` drafted only if scope warrants (~if > 20 issues surface).
    - Deliverable: zero correctness bugs in VFINAL source; issue log committed to docs or closed in-place.

24. **🧪 Determinism audit execution** (per item 8 walkthrough).
    - Deliverable: every emit path proven deterministic; compile-same-source-twice-in-one-process yields byte-identical WAT; fix log committed.

25. **🧪📋 Feature-usage audit.**
    - Walkthrough `docs/specs/simulations/FU-feature-usage.md` **LANDED 2026-04-21.**
    - Descriptive finding: compiler uses 3/8 primitives (#1 graph, #2 handlers-OneShot-only, #8 HM+Reasons). Verbs: `|>` + `~>` used in bodies; `<|`, `><`, `<~` 0 body uses. Negation `!E`: 0. `Pure`: 0 declared. Ownership `own`/`ref`: 0. Refinement `where`: 0. String interpolation: 0. 27/630 fns annotated (~4% gradient density).
    - Normative output: **FV.1–FV.9 action items** closing the exemplar gap. None block first-light; all runnable in parallel with hand-WAT Tier 1.
    - Hand-WAT Tier 2 scope: ~1500-2000 lines; Tier 1 ~1000 lines; total ~2500-3000 lines. FV additions add ~35 lines to Tier 2 parser. Tractable.
    - **FV peer sub-handles (each becomes a named commit; can land in parallel with Tier 1):**
      - **FV.1** — `!E` negation sweep. `[IN-FLIGHT — first exercised exemplar landed 2026-04-22 · cc08f7f]`
        - **Exercised:** 36 cache functions annotated: `with Pack + !Unpack` (18)
          and `with Unpack + !Pack` (18). First real `!E` on non-trivial code.
        - Remaining FV.1 sub-handles (α, β, γ, δ) still pending walkthrough.
        - **Walkthrough.** `docs/specs/simulations/EN-effect-negation.md` —
          covers FV.1.α (intent preservation), FV.1.γ (lone-`!E` semantics),
          FV.1.δ (named capability bundles — `capability RealTime = !Alloc & !IO & !Network`),
          and FV.1.β (polymorphic applied exemplar). Ordering: α → γ → δ → β,
          with MV.2.capability-surfacing as the voice-layer consumer of α+δ.
        - **Parent context:** EN is one of eight peer walkthroughs in the
          **IR intent round-trip cluster**
          (`docs/specs/simulations/IR-intent-round-trip.md`). The IR
          discipline names the principle that every primitive's authored
          form round-trips to every handler projection surface. The eight
          peers (EN · RN · OW · VK · GR · RX · HI · DS) each close one
          primitive's intent gap. EN closes primitive #4's.
        - **Substrate finding.** Per `std/compiler/effects.nx:134-156`
          (`normalize_inter`), `Closed(A) & !Closed(B)` reduces to
          `Closed(A - B)` — which equals `Closed(A)` when `B ⊄ A`.
          Declaring `with Memory + Alloc + Filesystem + !Diagnostic`
          on a function whose body genuinely doesn't perform
          Diagnostic normalizes to `Closed([Memory, Alloc, Filesystem])`
          — the negation is syntactically preserved in
          `declared_effs` but algebraically collapsed before
          `row_subsumes` sees it. Inference already catches
          violations via "effect not listed in closed row → subsumption
          fails"; closed-row-ness IS the negation. Explicit `!E`
          on closed rows adds no substrate beyond signature-level
          documentation. This is NOT a bug — the algebra is
          internally consistent — but it means FV.1 as originally
          framed (declare `!E` on hot-path fns) would be decoration
          on monomorphic closed-row sites, which is the compiler's
          entire surface at every site investigated 2026-04-22
          (infer_program, lower_program, emit_module, cache_write,
          cache_read, driver_* functions).
        - `!E` earns load-bearing weight only on (a) effect-polymorphic
          open rows `EfOpen(pos, v) & !Closed([E])` — genuinely narrows
          what `v` can bind to — or (b) row-negation forms directly at
          the top level of a fn's declared row.
        - **FV.1.α — substrate decision (Opus judgment).** Decide whether
          declared `!E` on closed rows should preserve negation as signature
          metadata accessible to downstream handlers (`inka audit`,
          Mentl's teach pass, code-review surfaces) even though
          `normalize_inter` collapses it for row_subsumes purposes.
          Option 1: keep current algebra; `!E` on closed rows is a no-op
          and FV.1 doesn't apply there. Option 2: preserve declared
          negation as a separate field on the fn signature (parallel to
          `declared_effs`); normalize_inter still collapses for
          subsumption, but audit/mentl handlers can read the author's
          intent. `[PENDING — substrate walkthrough needed before code]`
        - **FV.1.β — polymorphic effect-row exemplar (Opus judgment).**
          Find a higher-order site in the compiler or prelude where
          the callback's effect row is genuinely polymorphic, and
          declare `!E` as a constraint that narrows what the callback
          can bind to. Candidate: prelude.nx's higher-order
          collection ops (map / filter / fold / iterate) — `fn map(f:
          fn(a) -> b with !Diagnostic + v, xs)` would prove map
          never propagates diagnostic reporting. Requires care (API
          change; breaks callers passing reporting callbacks).
          `[PENDING — substrate walkthrough needed before code]`
      - **FV.2** — `Pure` declaration sweep. `[LANDED 2026-04-22 · 005d66d]` — 55 Pure annotations across 11 files. Primitive #4c + #7.
      - **FV.3** — Refinement types. `[LANDED 2026-04-22 · f7c6774]` — 5 aliases (Handle / TagId / ValidOffset / NonEmptyList / ValidSpan) + `fn span_valid` predicate added to types.nx; `Handle` applied to `graph_fresh_ty` return type. Primitive #6 moves from 0 uses to 5 decls + 1 applied site.
        - **FV.3.1** `TagId` applied to ConstructorScheme tag_id fields + emit_match dispatch. `[PENDING]`
        - **FV.3.2** `ValidOffset` applied to lexer byte positions + parser token positions. `[LANDED]` — 12 sites in lexer.nx.
        - **FV.3.3** `NonEmptyList` applied wherever code asserts `len > 0` in prose. `[PENDING]`
        - **FV.3.4** `ValidSpan` applied to every Span construction site. `[IN-FLIGHT]` — 56 sites across parser.nx and infer.nx parameters.
      - **FV.4** — Ownership markers (`own` on consumed params, `ref` on borrowed, `!Mutate` on append-only frozen buffers). Primitive #5. `[PENDING]`
      - **FV.5** — Five-verb exemplar (`<|` in infer_expr, `><` in driver, `<~` in unification fixpoint). Primitive #3. `[PENDING — Opus-dispatch tier; judgment on sites]`
      - **FV.6** — String interpolation sweep (`str_concat` chains → `${}` form). `[PENDING — BLOCKED: lexer.nx's scan_string does not yet parse `${}` — FV.6 has a prerequisite lexer-substrate extension]`
      - **FV.7** — `~>` chain sweep (rewrite any nested `handle(handle(...))` as pipe chain). `[PENDING — likely no-op per pre-audit: all `handle` hits in the compiler are identifier-substrings, not nested handle expressions]`
      - **FV.8** — Parameterized Diagnostic (already named as 11.B.M; this is its FV framing). Primitive #2b. `[PENDING — Opus-dispatch tier; cross-cutting + judgment on ModuleName ADT shape]`
      - **FV.9** — Docstring harmonization per NS-naming canonical template (absorbs item 11.E). `[PENDING — Sonnet-dispatch; mechanical once template is locked]`

---

### Bootstrap — hand-written WAT (Phase III; gated on items 23–25)

26. **📋 `Hβ-bootstrap.md`** walkthrough (item 9) closed first. Re-confirmed here as the gate.

27. **🌱⚙️ Hand-WAT Tier 1: runtime + handler dispatch.**
    - Pure hand-written WAT for `lib/runtime/*.nx` (bump allocator, string/list/tuple primitives, WASI I/O) + handler dispatch machinery (closure record layout per HB, direct-call for OneShot, `call_indirect` through evidence-field for polymorphic MultiShot — NO vtable).
    - Scope: ~10–30k lines WAT.
    - Deliverable: `bootstrap/inka.wat` with Tier 1 sections populated; `wat2wasm` assembles; `wasm-validate` clean; a tiny test program (hello-world) runs under `wasmtime`.

28. **🌱⚙️ Hand-WAT Tier 2: template-expanded compiler modules.**
    - Template-expansion script (bash/awk, ~200 lines, no Inka semantics — just pastes WAT fragments from cascade walkthrough templates per `.nx` module) for repetitive compiler code: match dispatch, closure allocation, variant construction, pipeline lowering.
    - Scope: ~20–70k lines WAT generated.

29. **🌱⚙️ Hand-WAT Tier 3: incremental self-hosting.**
    - Order: `lib/runtime/*` → `src/types` → `src/graph` → `src/effects` → `src/infer` → `src/lower` → `src/backends/wasm` → `src/lex` → `src/parse` → `src/pipeline` → `src/main` + `src/mentl` + `src/query` + `src/cache` + `src/driver` + `src/own` + `src/verify` + `src/clock` + `src/run`.
    - Each module: once Tier 1+2 compile it, use VFINAL-on-partial-WAT to compile the next module; diff against hand-WAT; correct drift.
    - Deliverable: `bootstrap/inka.wat` complete; every compiler module compiles itself through the assembled binary.

30. **🌱 Assembly + first-light harness** — `bootstrap/first-light.sh`:
    ```bash
    wat2wasm bootstrap/inka.wat -o bootstrap/inka.wasm
    wasm-validate bootstrap/inka.wasm
    cat src/*.nx lib/**/*.nx | wasmtime run bootstrap/inka.wasm > inka2.wat
    diff bootstrap/inka.wat inka2.wat   # empty = first-light
    ```

31. **🎯 First-light.**
    - Run item 30. `diff` empty.
    - Tag: `first-light`.
    - Hand-WAT **kept forever** as reference soundness artifact (NOT deleted, unlike a Rust translator would be).
    - Update `docs/traces/a-day.md` — every `[LIVE · surface pending]` tag now either resolves or moves to post-first-light follow-up.

---

### Post-first-light dissolutions (tracked so interim shapes don't ossify)

The following are interim compromises that should dissolve once
the corresponding Inka-native substrate exists. Named explicitly
to prevent them from fossilizing as "Inka-native" just because they
shipped pre-first-light.

- **`tools/` directory dissolves.** `drift-audit.sh`,
  `setup-git-hooks.sh`, `apply-claude-config.sh` are shell because
  Inka didn't exist when they were written. Post-first-light,
  rewrite as Inka programs that users import from `lib/`. The
  drift audit becomes a handler on the graph (exactly the voice
  surface Mentl's Query tentacle already enables).
- **`docs/` largely dissolves.** DESIGN.md's §9.12 names
  documentation as a handler on the graph. Post-first-light, the
  `doc_handler` projects docs from `///` comments + graph
  provenance. DESIGN.md / INSIGHTS.md as human-written
  manifestos remain; generated specs / error catalogs /
  walkthroughs become projections.
- **`PLAN.md` itself dissolves.** This file is industrial-project-
  management-shaped. Post-first-light, "the plan" is a handler
  projection: `plan_handler` reads graph provenance + commit
  history + pending state and speaks the plan through Mentl's
  Teach tentacle. The 51-item markdown list is fluency residue;
  acceptable pre-first-light, explicitly named so it doesn't
  ossify. Decisions Ledger stays as append-only human-history
  record.
- **Six-directory shape → probably four.** Post-`tools/`-dissolution
  and post-`docs/`-partial-dissolution, final repo is `src/` +
  `lib/` + `bootstrap/` + minimal `docs/`. Four.

### Post-first-light handler projections (do not gate first-light; ship incrementally after)

**Priority P1 — user-facing surface:**

32. **⚙️ Mentl-voice surface code** — implement the `Interact` effect, `mentl_voice` 8-tentacle handler, silence predicate, LSP adapter handler, VS Code extension (per items 2 + MV walkthrough closure). Post-first-light because compiling the compiler doesn't need Mentl's voice — users do.

33. **⚙️ VS Code extension marketplace publish** — package, publish, auto-update handling.

34. **⚙️ Batch CLI unified with Mentl's voice** — `inka compile`, `inka check`, `inka audit`, `inka query`, `inka teach`, `inka run` all speak the same VoiceLine grammar.

**Priority P2 — deployment scenarios:**

35. **📋⚙️ Audit-driven linker dead-code severance** — reads `AuditReport.severable`; issues `--drop-import` at WAT → WASM. Walkthrough TBD.

36. **📋⚙️ Multi-backend emit** — per-target handler variants in `src/backends/`:
    - `browser.nx` — browser WASM with DOM import
    - `server.nx` — server WASM with WASI
    - `trainer.nx` — full imports + larger arena
    - `native.nx` — Arc F.5, hand-rolled x86-64

37. **📋⚙️ Runtime `HandlerCatalog` effect** — replaces static table with runtime-registered handler catalog (user-defined handlers register at module load; Mentl's `AWrapHandler` proposal reads the registry).

**Priority P3 — specific programs:**

38. **📋⚙️ Thread effect + per-thread region minting** — `spawn(f)` op; per-thread handler install pattern; region id per thread.

39. **📋⚙️ RPC/actor handler** — `~>` boundary handler that bifurcates emit and serializes the cross-wire state record.

40. **⚙️ Autodiff handler** — ~15 lines per DESIGN.md 10.2; records tape, resumes with forward values, `backward()` walks the tape in reverse.

41. **⚙️ SIMD intrinsic emission** — recognize `tanh`, `gain`, etc. as mappable to `v128.*` WAT opcodes.

42. **⚙️ Refinement SMT (Arc F.1)** — `verify_ledger` → `verify_smt` handler swap, with Z3/cvc5/Bitwuzla dispatch by residual theory.

**Priority P4 — polish:**

43. **⚙️ Commit message synthesis from graph provenance DAG.**

44. **⚙️ `inka rename` CLI handler** — cross-module graph rebind.

45. **⚙️ `///` docstring handler** — render docs from graph projection.

46. **📋⚙️ Terminal IDE (MV.3)** — native Inka surface, direct `Interact`, no LSP overhead.

47. **📋⚙️ Web playground (MV.4)** — browser-hosted, guided-tutorial first visit.

48. **Desktop client** — distant future, optional.

**Cascade follow-ups (lands when load-bearing):**

49. **⚙️ IC.3 — graph chase walks overlays** — per-module overlay separation. Lands when name collisions across modules become load-bearing. Driver currently merges envs flat; correct for today's project.

50. **⚙️ Cache format binary v3** — **`[LANDED 2026-04-22 · 7eee2b8]`**.
    Text-parsing cache layer dissolved; replaced with binary Pack/Unpack
    effects. Every Ty variant gets an exhaustive tag byte. Unauthorized
    `^` operator eliminated; XOR via byte-level arithmetic.

51. **⚙️ Cache dependency-hash invalidation v2** — full chain (cache hit on M requires every dep's recorded imports_hashes match dep's CURRENT hash). Substrate ready; policy adjustment small.

---

## The Approach: Write the Wheel, Then Hand-Write Its WAT

Traditional self-hosted compilers bootstrap forward: write V1, use V1
to compile V2, delete V1. This taints V2 with V1's constraints.

**Inka bootstraps backward.** Write the final-form compiler
unconstrained — the perfect, complete, un-improvable codebase — and
THEN solve "how do I compile this the first time?" as a separate,
honest engineering problem.

**Revised 2026-04-20:** the "how do I compile this the first time?"
answer is NOT a Rust/C translator. A Rust translator would duplicate
Inka's semantics in another language's idioms — importing fluency
drift into the soundness artifact. Instead, **hand-write the WAT
directly**, using the cascade walkthroughs as the transcription
spec. No intermediate semantic layer; no foreign-language fluency
taint; the hand-WAT is the reference soundness artifact **kept
forever**, not scaffolding to delete.

```
VFINAL (perfect Inka source, simplification-audited, determinism-proven)
    ↓
Hand-written WAT transcribed from cascade walkthroughs
    ↓ (wat2wasm, WABT, full-fidelity)
inka.wasm (the seed compiler)
    ↓ (wasmtime)
VFINAL source → inka2.wat
    ↓
diff bootstrap/inka.wat inka2.wat   # empty = first-light
```

**Why this is right:**
- VFINAL is designed for correctness. The hand-WAT is a direct
  transcription from walkthroughs that VFINAL already embodies.
  No third language in the loop.
- No architectural contamination from any prior compiler OR
  from any fluency-imported pattern.
- CLAUDE.md anchor #4: "Build the wheel. Never wrap the axle."
  VFINAL is the wheel. The hand-WAT is the wheel's serialization
  to binary — not scaffolding, but the reference artifact that
  proves self-compilation once and proves future targets forever.
- CLAUDE.md Mentl's anchor + drift mode 1 (Rust vtable): a Rust
  translator would be 4k lines of drift-mode-1 fluency risk. WAT
  is the substrate Inka targets anyway; transcribing directly is
  the honest path.

**The hand-WAT doesn't need to understand Inka semantics — the
cascade walkthroughs did that work.** Hand-WAT performs a
mechanical serialization:
- Runtime primitives (bump allocator, tagged values, string/list/tuple ops) — Tier 1, pure hand-written (~10-30k lines).
- Handler dispatch machinery (closure records, direct-call for OneShot, call_indirect through evidence-field for polymorphic MultiShot — NO vtable) — Tier 1 (~5-15k lines).
- Repetitive compiler-module patterns (match dispatch, ADT construction, pipe chain lowering) — Tier 2 template-expansion from walkthrough fragments (~20-70k lines).
- Module bodies — Tier 3 incremental self-hosting, using VFINAL-on-partial-WAT to compile subsequent modules as Tiers 1+2 light up.

No effect algebra re-implemented. No type inference re-implemented.
No refinement checking re-implemented. Walkthroughs specify the
WAT shape; hand-WAT transcribes it. Assembled via `wat2wasm`;
validated via `wasm-validate`; executed via `wasmtime`. **First-
light once; the hand-WAT stays forever as the reference.**

---

## Vision: the ultimate intent → machine instruction medium

Not "the ultimate programming language" — that undersells. Inka is
the medium that makes the language-vs-framework-vs-tool distinction
evaporate. What Inka IS when complete:

**One mechanism replaces six.** Exceptions, state, generators, async,
dependency injection, backtracking — all `handle`/`resume`. Master
one mechanism, understand every pattern.

**Boolean algebra over effects.** `+` union, `-` subtraction, `&`
intersection, `!` negation, `Pure` empty. Strictly more powerful than
Rust + Haskell + Koka + Austral combined (INSIGHTS.md). No other
language has effect negation.

**Inference IS the product.** The Graph + Env IS the program.
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
in `src/` IS the compiler (post-restructure, previously
`std/compiler/`). It is written to be correct, complete, and
un-improvable. It is not a stepping stone, not a draft, not a
version. It is the thing itself.

### 2. The bootstrap is hand-WAT, kept forever.

Superseded 2026-04-20: NOT "disposable translator, deleted forever."
The bootstrap is **hand-written WAT transcribed from cascade
walkthroughs**, assembled via `wat2wasm`, and **kept forever as the
reference soundness artifact**. No Rust/C translator. No third
language. Hand-WAT writes the compiler's binary image directly; the
VFINAL compiler self-compiles through it; the byte-identical diff
IS first-light. The hand-WAT stays — future Wasm targets/engines
are validated by re-running the fixed-point test against it.

### 3. The `~>` chain IS the extension point.

No plugin API. No framework. No hook system. New capabilities (LSP,
Mentl, format, lint, doc) are handlers installed via `~>`. Pipeline
callers compose their own chains. `pipeline.nx` is not modified to
add features — features are handlers.

### 4. No patches. Restructure or stop. Forever.

CLAUDE.md anchor #2. The rebuild exists because patching failed.
If the rebuild becomes patch-laden, we have accomplished nothing.

### 5. The closure moment is named `first-light`.

When `diff bootstrap/inka.wat inka2.wat` returns empty — when Inka
compiled through its hand-WAT reference image is byte-identical to
the hand-WAT itself — tag `first-light`. Morgan writes the tag.
Claude prepares the tree. The hand-WAT is preserved forever, not
deleted; it is the reference against which future Wasm targets
are validated.

### 6. Inka stands on research; the kernel is contribution.

2024-2026 research gives the foundation — Koka JFP 2022 for
effect-handler compilation, Affect POPL 2025 for resume-discipline
typing, Austral for linearity-as-effect, GRIN for whole-program
optimization, et al. The research proves the pieces are tractable.

The kernel adds what no existing medium holds in one substrate:

- **Boolean effect algebra with `!E` negation** — `!E` proves
  ABSENCE. Strictly more powerful than Rust + Haskell + Koka +
  Austral combined (INSIGHTS.md).
- **Five verbs as a complete topological basis** — `|>` `<|` `><`
  `~>` `<~`. `<~` feedback is genuine novelty: no other language
  makes back-edges visible, checkable, and optimizable.
- **The graph IS the program** — every output (source, WAT, docs,
  LSP, diagnostics) a handler projection on one Graph + Env.
- **Handler-chain-as-capability-stack** — `~>` ordering is a trust
  hierarchy, compiler-audited. Outermost = least trusted.
- **Eight-primitive kernel 1-to-1-to-1 with eight interrogations
  and Mentl's eight tentacles.** One method, one mascot, one
  kernel. (DESIGN.md §0.5.)
- **Typed resume discipline as part of each op's type** — `@resume=
  OneShot|MultiShot|Either`. MultiShot is Mentl's oracle substrate
  (hundreds of alternate realities per second).
- **Continuous annotation gradient** — one annotation, one capability
  unlock. Mentl surfaces one load-bearing next step per turn.
- **Mentl as oracle, not LLM** — Mentl PROVES suggestions through
  multi-shot speculative search; the compiler IS the AI. This
  disintermediates subscription coding tools at the architectural
  level, not the UX level.
- **The medium raises its users** — the shape Inka imprints on
  thinking teaches. This is a pedagogical thesis, not just a
  compiler claim.

The research is foundation. The kernel is contribution. Pretending
otherwise surrenders the thesis DESIGN.md spent 14.6k words proving.

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

## The Work: Four Phases

Phases I–IV replace the earlier "Three Phases" framing (Write VFINAL,
Bootstrap, First Light). What actually closed wasn't "write VFINAL
files"; it was the γ cascade — nine handles, ten crystallizations,
nine named drift modes, three substrate gaps named and scoped. The
work that remains is installing handler projections on the closed
substrate; bootstrap comes after.

### Phase I — γ cascade — CLOSED

The substrate is Inka-native at every layer. See
`docs/specs/simulations/H*.md` for per-handle reasoning and
`docs/traces/a-day.md` for integration verification.

Landings (chronological):
- **Σ** — SYNTAX.md canonical syntax
- **Ω.0–Ω.4** — audit sweeps + parser refactor (str_eq Bool sweep,
  list_extend_to substrate, Token ADT, full parser match-dispatch)
- **Ω.5** — frame consolidation (parallel arrays → records)
- **H6** — wildcard audit (exhaustive ADT matches across substrate)
- **H3** — ADT instantiation (SchemeKind, LMakeVariant tag_id,
  LMatch cascade, exhaustiveness check)
- **H3.1** — parameterized effects (EffName ADT; `Sample(44100)`
  structurally distinct from `Sample(48000)`)
- **H2** — structural records (MakeRecordExpr, LMakeRecord,
  PRecord with field-puning desugar)
- **HB** — Bool transition (TBool deleted; nullary-sentinel ADT;
  heap-base threshold discriminator for mixed-variant types)
- **H1** — evidence reification in full (LMakeClosure absorbs
  LBuildEvidence; BodyContext effect; real LEvPerform offset
  arithmetic; handler arm fn indexing via LDeclareFn; transient
  evidence at poly-call sites)
- **H4** — region escape in full (tag_alloc/check_escape; region-
  join for compound types per H4.1)
- **H2.3** — nominal record types (`type Person = {...}`)
- **H5 substrate** — Mentl's arms (AWrapHandler annotation;
  AuditReport records; severance + capability unlocks)

Net effect: every layer from character → token → AST → typed AST →
LIR → WAT is Inka-native. No primitive special cases. No string-
keyed-when-structured drift. No parallel-arrays-instead-of-record.
No int-mode-when-ADT. Records are the handler-state shape
everywhere. Row algebra is one mechanism over four element types.
The heap has one story.

### Phase II — Handler projection — IN FLIGHT

Every surface that exposes the substrate to users (editors,
deployment targets, concurrency, RPC, ML, audit-to-linker) is a
handler. Phase II installs them. Three of the items are genuine
substrate gaps, not surfaces — named explicitly below.

**Intent substrate gate (IR cluster, 2026-04-22).** Phase II handler
projections (MV.2, LSP hover, audit, capability graphs) depend on
intent substrate — the authored vocabulary that round-trips through
the compiler to reach downstream surfaces. The IR intent round-trip
cluster (`docs/specs/simulations/IR-intent-round-trip.md`) names
eight peer walkthroughs that close the intent gaps per kernel
primitive: EN (effects), RN (refinements), OW (ownership), VK
(verbs), GR (gradient), RX (reasons), HI (handlers), DS
(docstrings). Phase II surfaces are HIGH-FIDELITY only when the
corresponding intent substrate has landed:

- MV.2 Mentl-voice → depends on EN.α+δ (capabilities), RN (alias
  names), OW (ownership stance), GR (gradient query), DS
  (docstrings).
- LSP hover → depends on RN, OW, VK (verb identity), HI (handler
  identity), DS.
- `inka audit` → depends on EN.δ (capability stance), RX (reason
  quality), VK (verb topology).
- Error diagnostics → depends on RN (alias-named errors), OW
  (ownership-named errors), RX (intent-grade reasons).

The IR cluster is upstream of Phase II; surfaces that ship before
their intent substrate lands will speak mechanism instead of the
developer's vocabulary.

Priority order (what unblocks what):

**Priority 1 — unblocks developer use. The compiler must answer in
conversational latency; anything slower is the graph being
disrespected by the driver.**

- **Incremental compilation** *[LANDED — substrate]* — per-module
  `.kai` cached envs (cache.nx), module DAG walk + cache hit/miss
  (driver.nx), source-hash invalidation, env reconstruction from
  cache. The Filesystem effect (FS substrate) lands underneath,
  exposing path_open/fd_close/path_create_directory/
  path_filestat_get to the driver via wasi_filesystem handler.
  `inka compile <module>` and `inka check <module>` route through
  driver_check; cold compile equals today's behavior, warm
  compile after no-op or leaf-edit returns sub-second. Drift
  mode 10 ("the graph as stateless cache") closed at driver
  level. IC.3 (per-module overlay separation in graph chase)
  deferred until name collisions across modules become
  load-bearing.
- **Mentl-voice substrate** `[substrate pending]` — absorbs the
  former "teach_synthesize oracle" and "HandlerCatalog" gaps plus
  what was "LSP handler." The thesis: Mentl is the one proposer; the
  multi-shot `enumerate_inhabitants` op is how She covers the
  candidate space; the `Interact` effect is the one surface that
  REPL, CLI, web playground, and later IDE-like clients all
  project. LSP as a paradigm is dissolved here (the graph knows,
  so there is no editor↔compiler bridge to build). Walkthrough TBD
  as `simulations/MV-mentl-voice.md`; CLI/REPL (`inka live`)
  surfaces first — text transport forces voice discipline.
- **`LFeedback` state-machine lowering** `[substrate pending]` — emit-
  side rewrite of `<~ spec` to a state-machine LIR (handler-local state
  slot for the delayed sample; Z-transform structure for DSP; RNN hidden-
  state for training). The verb, row, type-inference all fire; emit
  stubs. **Independent of Mentl-voice work.**

**Priority 2 — unblocks deployment scenarios:**
- **Audit-driven linker dead-code severance** — reads
  `AuditReport.severable`, issues `--drop-import` at WAT → WASM.
- **Multi-backend emit** — per-target handler variants on `backends/`
  (browser, server, trainer, wasi). Today's single `backends/wasm.nx`
  generalizes; each target adds a handler.
- *(Former: Runtime `HandlerCatalog` effect — folded into
  Mentl-voice substrate at Priority 1. The registry is what Mentl
  reads when enumerating wrap candidates.)*

**Priority 3 — unblocks specific programs:**
- **Thread effect + per-thread region minting** — `spawn(f)` op;
  per-thread handler install pattern; region id per thread.
- **RPC/actor handler** — `~>` boundary handler that bifurcates
  emit and serializes the cross-wire state record.
- **Autodiff handler** — concrete ~15 lines per DESIGN.md 10.2;
  records tape, resumes with forward values, `backward()` walks
  the tape in reverse.
- **SIMD intrinsic emission** — recognize `tanh`, `gain`, etc. as
  mappable to `v128.*` WAT opcodes.

**Priority 4 — polish, not load-bearing:**
- Commit message synthesis from graph provenance DAG
- `inka rename` CLI handler
- `///` docstring handler (render from graph projection)

**Exit condition:** every `[LIVE · surface pending]` and every
`[substrate pending]` marker in `docs/traces/a-day.md` flips to
`[LIVE]`. The trace becomes the scoreboard.

### Phase III — Bootstrap (hand-WAT)

Deliberately last. **Hand-written WAT** transcribed from cascade
walkthroughs (not a Rust/C translator — see The Approach section
above for rationale). Tier 1 pure hand-write for runtime + handler
dispatch; Tier 2 template-expansion for repetitive compiler
patterns; Tier 3 incremental self-hosting as modules light up.
Assembled via `wat2wasm` (WABT). **Kept forever as reference
soundness artifact**, NOT deleted.

Items 26–30 of Pending Work. `Hβ-bootstrap.md` walkthrough (item 9)
gates the hand-write.

### Phase IV — First-light

The soundness proof:

```
wat2wasm bootstrap/inka.wat -o bootstrap/inka.wasm
wasm-validate bootstrap/inka.wasm
cat src/*.nx lib/**/*.nx | wasmtime run bootstrap/inka.wasm > inka2.wat
diff bootstrap/inka.wat inka2.wat     # empty = first-light
```

When the diff is empty, the substrate is self-compiling byte-
identically through its own hand-WAT image. Tag: `first-light`.
Hand-WAT is preserved as reference. Post-first-light arcs (items
32–51 of Pending Work — Mentl-voice surface, multi-backend emit,
audit-driven severance, refinement SMT, terminal IDE, web
playground, etc.) continue as ongoing work.

---

## The Substrate Gaps — revised 2026-04-20

Originally three named gaps (LFeedback, teach_synthesize,
HandlerCatalog). Post-reframe:

**Gap 1 remains independent:**

1. **`LFeedback` state-machine lowering.** At emit,
   `LFeedback(handle, body, spec)` currently emits
   `;; <~ feedback (iterative ctx)` as a stub. The verb, row,
   type inference, and AST all fire. What pends: lowering to a
   state-machine LIR — handler-local state slot for `<~ delay(N)`,
   RNN hidden-state structure for `<~ step_fn`. Templates in H3.1
   walkthrough. Scope: ~100 lines emit-side. **Item 1 of Pending
   Work.** Walkthrough `LF-feedback-lowering.md` (TBD).

**Gaps 2 + 3 absorbed into the Mentl-voice substrate:**

2. **Mentl-voice substrate** (absorbs former `teach_synthesize`
   conductor + static `HandlerCatalog`). The `Interact` effect;
   multi-shot `enumerate_inhabitants` as the proposing primitive
   Mentl owns; the voice grammar (eight tentacles, 1-to-1 with
   kernel primitives); the cursor-of-attention; session state.
   **Item 2 of Pending Work.** Walkthrough
   `MV-mentl-voice.md` (in-flight; has open §2 Q1-Q6 and §9
   first-hour scenario). Scope: walkthrough closure then
   ~600-1000 lines `.nx` + ~200 lines TypeScript extension glue.

Everything else is handler installation on the substrate that
already exists.

---

## Handler Projection Arcs (formerly Post-First-Light Arcs)

What was framed as "post-first-light" is actually Phase II
handler-projection work. Each arc below either landed during the
γ cascade as substrate (marked LANDED), is Phase II priority
(marked PRIORITY N), or is genuinely post-cascade exposure
(marked EXPOSURE). Bootstrap / first-light come after Phase II
closes the critical path.

Arc designs live in `docs/DESIGN.md` (chapter 9 — *What Dissolves*)
and in this document's per-arc sections below. When an arc picks up,
capture the concrete implementation in the relevant rebuild spec or
in a dedicated design doc at that time — the arcs are sketched here,
not locked.

### Arc F.1 — Refinement Verification  *[PRIORITY 3]*

`verify_ledger` → `verify_smt`. Handler swap; source unchanged.

**What it does:** Every `type Port = Int where 1 <= self && self <=
65535` annotation that Phase 1 accrues as a `V_Pending` obligation
now gets DISCHARGED at compile time via SMT. Invalid call sites
fail with `E_RefinementRejected`.

- Z3 for nonlinear arithmetic.
- cvc5 for finite-set/bag/map reasoning.
- Bitwuzla for bitvectors.
- **Research:** Liquid Haskell 2025, Generic Refinement Types POPL 2025.
- **Spec:** 02-ty.md (TRefined), 06 (Verify effect).

**What it unlocks:** Compile-time proof that array indices are in
bounds, that ports are valid, that buffer sizes are sufficient.
Erased at runtime — zero cost.

---

### Arc F.2 — Mentl-voice + `Interact` surfaces  *[PRIORITY 1 — REFRAMED 2026-04-20]*

**Formerly "LSP + ChatLSP."** LSP as a paradigm is dissolved by the
Inka thesis: LSP exists in other languages because editors don't
know what code means; Inka's graph IS the program, so there is no
editor↔compiler bridge to build. An LLM proposer (ChatLSP-style) is
a distant architectural possibility, not a Priority 1 substrate —
Mentl is the proposer, owning the multi-shot `enumerate_inhabitants`
primitive that covers the candidate space deterministically.

**What replaces it:** an `Interact` effect, projected by handlers
for the REPL (`inka live`), the CLI (`inka teach`, `inka audit`,
`inka query`), eventually a web playground and IDE-like client.
All peer handlers on one effect; Mentl's voice is shared substrate.

**Design + build order:**
- `simulations/MV-mentl-voice.md` walkthrough — `Interact` op
  set, voice grammar, register, session state, one-at-a-time
  surfacing discipline, silence predicate, rust-analyzer
  architecture study. Gating design session.
- **MV.2 — LSP adapter + VS Code extension (v1).** First
  integration. LSP JSON-RPC ↔ `Interact` ops; VS Code extension
  published to marketplace. How developers first meet Mentl.
- **Batch CLI subcommands** (`inka compile`, `inka audit`, etc.) —
  unified into the `Interact` substrate so their voice matches
  VS Code's. One-shot session shape.
- **MV.3 — Terminal IDE (later).** Native Inka surface, direct
  `Interact`, no LSP overhead. Designed after VS Code surface
  teaches us what Mentl's voice needs in practice.
- **MV.4 — Web playground (later).** Browser-hosted, guided-
  tutorial first visit. Onboarding surface.
- **Desktop client** — distant future, optional, post-first-light.

**What it unlocks:** Inka's own rendition of a pair-programmer
surface — a deterministic partner so effective that people will
want to call Her AI even though She transcends the definition.
The thesis that makes modern agentic coding AI obsolete, made
operational. No subscription. No hallucination. The oracle you
talk to.

---

### Arc F.3 — REPL + Multi-Shot Continuations  *[PRIORITY 3]*

Replace `load_chunk`. Execute arbitrary Inka expressions. Formalize
the three multi-shot continuation models. Substrate for one-shot
evidence lands with H1.6; multi-shot semantics extend the same
LMakeClosure ev_slots layout.

**What it does:**
- REPL: compile-to-WASM per line or LowIR interpreter. The REPL is
  a handler that redirects emitted WASM to an in-process evaluator.
- Multi-shot continuations with three semantic models:
  1. **Replay** (default) — re-execute thunk from top. Independent
     runs. O(work) per invocation. No allocation.
  2. **Fork** — `resume` called N times in one handler arm. Each
     call clones the continuation from the perform site. O(state)
     per clone. Powers backtracking search, SAT, amb/choose.
  3. **State machine** — compile-time transform of handled body
     into numbered states. O(struct) per clone. Subsumes replay
     and fork. Native backend (F.5) target.
- **Critical interaction:** `!Alloc` computations can be REPLAYED
  but NOT FORKED (forking allocates the continuation struct). The
  compiler enforces this via effect rows.
- Handler-local state at fork point: each fork gets a SNAPSHOT.
  Functional `with state = ...` update means mutations in one fork
  don't affect others.

- **F-note:** `multi-shot-continuations.md` (329 lines, detailed)
- **Spec:** 08-query.md, 06-effects-surface.md (@resume markers).

**What it unlocks:** Backtracking search (4-Queens validated),
hyperparameter sweep, Monte Carlo, speculative execution — all as
handler strategies over the same computation code.

---

### Arc F.4 — Scoped Arenas + Memory Strategy  *[substrate LANDED via H4; handler variants EXPOSURE]*

The arc where Inka proves GC is a handler. H4 landed region tracking
with tag_alloc_join (composite region-join for records/variants);
EmitMemory swap surface lands arenas as a handler swap. What remains
is the concrete `temp_arena` / `arena_pool` / `thread_local_arena`
handlers as alternate EmitMemory installations.

**What it does:**
- `temp_arena(size)` handler — O(1) region free, deterministic.
  Intercepts `alloc(size)` calls. When scope drops, reset pointer
  to zero — instant, deterministic "garbage collection."
- Ownership system prevents use-after-free: if `similar` escapes
  `temp_arena` scope, compiler forces copy into parent allocator.
- `own` + deterministic drop for game/embedded contexts.
- Multi-shot × arena semantics (the D.1 question): three policies:
  1. **Replay safe** — re-execute from perform site.
  2. **Fork deny** — error at capture if continuation escapes arena.
  3. **Fork copy** — deep-copy arena data into caller's arena.
- **Diagnostic arenas** — wrap memory-heavy mentorship code
  (Levenshtein suggestions, O(N³) string ops) in `temp_arena`.
  Mentorship code can be as sloppy as needed — arena isolates it.
  Zero-cost teaching.
- **Thread-local Alloc** — each thread gets its own Alloc handler.
  No global allocator mutex. Concurrency scales with zero locking.

- **F-note:** `scoped-memory.md` (73 lines, clear design)
- **Research:** Perceus PLDI'21, FBIP PLDI'24, bump-scope, Vale.
- **Spec:** 07-ownership.md (Consume × Alloc), 02-ty.md (TCont).

**What it unlocks:** Four memory models from one mechanism:

| Context | Handler | Guarantee |
|---|---|---|
| Compiler (batch) | `bump_allocator` | Allocate forward, exit frees all |
| Server (request) | `temp_arena(4MB)` | O(1) region free per request |
| Game (frame) | `own` + drop | Deterministic, zero-pause |
| Embedded/DSP | `!Alloc` | Proven zero allocation |
| Diagnostics | `diagnostic_arena` | Unbounded mentorship, zero cost |

---

### Arc F.5 — Native Backend  *[PRIORITY 2]*

Hand-rolled x86-64 from LowIR. The capstone performance arc.
Lands as an alternate `backends/native.nx` handler installation —
peer to `backends/wasm.nx`, not a rewrite. Multi-backend emit
infrastructure (Priority 2) is the prerequisite.

**What it does:** LowIR → native machine code. No WASM, no VM.
- Lexa zero-overhead handler compilation: direct stack-switching.
- Tail-resumptive handlers (85%) → `call` instruction.
- Linear handlers → state machine.
- Multi-shot → heap-allocated continuation struct.

- **Research:** Lexa OOPSLA 2024, Multiple Resumptions ICFP 2025.

**What it unlocks:** Performance parity with C/Rust for
compute-bound workloads. The Inka-compiles-itself loop runs at
native speed. DSP handlers meet real-time deadlines.

---

### Arc F.6 — Mentl Consolidation  *[substrate LANDED via H5; orchestration PRIORITY 1]*

The teaching substrate crystallized. The AI-obsolescence thesis
made concrete. H5 landed AWrapHandler, AuditReport records,
severance enumeration, capability unlocks. What remains is the
`teach_synthesize` oracle conductor (substrate gap 2) — the
composed handler that drives checkpoint/apply/verify/rollback over
gradient candidates.

**What it does:** Crystallize `mentl.nx` further. The five-op Teach
surface and the speculative oracle ship in Phase 1 as the structural
substrate; F.6 expands the reasoning depth (longer Why-chains,
richer error catalog, higher-leverage gradient suggestions) and
tightens the applicability tags on Mentl-proposed patches.

- **Research:** Elm/Roc/Dafny error catalogs, Hazel marked holes.
- **Spec:** 09-mentl.md.

**What it unlocks:** The compiler becomes the tutor. Every error
teaches. Every annotation unlocks power. The gradient from beginner
to expert is continuous — no cliff, no separate "advanced mode."

---

### Arc F.7 — Incremental Compilation  *[PRIORITY 4]*

Per-module caching via `.kai` interface files + Salsa 3 overlay.

**What it does:**
- Each `.nx` file is checked independently against the envs of its
  dependencies. Result: a fully-resolved type environment.
- After checking, serialize env to `<module>.kai` (Inka Interface):
  `[(name, Type, Reason)]` triples, content-hash keyed.
- On recompile: if `.kai` exists AND hash matches source, load env
  from cache (skip checking). Otherwise re-check and write cache.
- Topological module ordering: imports form a DAG. Modules checked
  in dependency order. No inference state leaks across modules.
- **Memory impact:** Instead of one `check_program` call on 10K+
  lines (GB-scale), each module checks independently (~20-50MB).
  Peak memory: the largest single module, not the sum.
- `graph_fork(module_name)` creates a persistent overlay per module.
- Grove CmRDT structural edits for cross-module re-inference.

- **F-note:** `incremental-compilation.md` (153 lines, detailed)
- **Research:** Salsa 3.0, Grove POPL 2025, Polonius 2026 alpha.
- **Spec:** 00-graph.md (graph_fork, epoch overlay).

**What it unlocks:**
- Sub-second recompilation for large codebases.
- Parallel compilation: independent modules check concurrently.
- LSP integration: module envs are the hover/completion source.
- Gradient dashboard: per-module verification scores from cached envs.

---

### Arc F.8 — Concurrency + Parallelism  *[PRIORITY 3]*

Deterministic parallelism via handler swap. Requires Thread effect
+ per-thread region minting (Priority 3 substrate work).

**What it does:**
- `Parallel` handler: `<|` branches run concurrently (not just
  sequentially).
- Vale-style `!Mutate` region-freeze for "N readers, no writers"
  proof via effect algebra.
- Fork-join over `><` parallel compose — each branch gets its own
  stack.
- Effect row ensures no data races: `!Mutate + !IO` proves
  deterministic parallelism.

- **Research:** Vale immutable regions, Austral linear capabilities.
- **Spec:** 10-pipes.md (`<|` and `><` semantics).

**What it unlocks:** Source-unchanged parallelism. Same Inka code,
different handler. Sequential for debugging, parallel for production.
The pipe topology SHOWS the parallelism opportunity — `<|` is a
fork point, `|>` convergence is a join.

---

### Arc F.9 — Package + Module System  *[audit LANDED; linker severance PRIORITY 2]*

The handler IS the package. The `~>` chain IS the manifest. There
is no package manager. There is only the compiler.

H5 landed `inka audit`'s report (AuditReport records with
severable/unlocks). What pends: the audit-driven linker pass that
reads `AuditReport.severable` and drops WASM imports (Priority 2).

**Thesis:** npm/Cargo/pip build ad-hoc untyped mini-languages (JSON,
TOML) to describe dependency graphs because their host languages
can't carry the information. In Inka, the language already knows
everything: `with Network, IO` replaces `dependencies = ["reqwest"]`.
Effect signatures ARE API contracts. Breaking change = signature
drift. Compatible change = signatures unify. The type checker IS
the version solver.

**What it does:**
- `Package` effect: `fetch(id: Hash) -> Source`,
  `resolve(row: EffRow) -> Hash`, `audit() -> List<Violation>`.
- Registry handlers are swappable: `~> local_cache_pkg`,
  `~> github_pkg`, `~> enterprise_registry_pkg`.
- Content-addressed model: hash = identity, name = resolution via
  handler. There is no lockfile — the hash IS the lock.
- Federation via handler stacking:
  `fetch_deps() ~> local_cache >< github_hub >< community_registry`
- **`inka audit` — the killer MVP.** Walk the `~>` chain in `main()`,
  collect effect rows transitively, print the capability set, suggest
  negations. Zero infrastructure. Runs locally. Mathematically proven
  capability analysis before compilation.
  ```
  $ inka audit main.nx
  Capabilities required:
    - Network (via router_axum)
    - Filesystem (via db_postgres)
  Suggestions:
    - Run sandboxed with `with !Process, !FFI`.
  ```

- **F-note:** `packaging-design.md` (128 lines, complete design)

**What it unlocks:** Package management without a package manager.
Effect signatures replace semver. `inka audit` proves what your
program can and cannot do — no other package manager can offer
mathematically proven capability analysis.

---

### Arc F.10 — ML Framework + Handler Features  *[PRIORITY 3]*

Machine learning as proof of thesis. The ten mechanisms composed.
Autodiff handler is ~15 lines per DESIGN.md 10.2; records tape,
resumes forward, backward walk. Substrate fully supports; the
concrete handler is a Priority 3 installation.

**What it does:**
- **Autodiff as effect.** `Compute` effect for matmul, conv1d, relu,
  softmax. Training handler intercepts + records tape. Inference
  handler just computes. Same model code, different semantics.
- **Optimizer as handler.** `Optimize` effect: `step(param, grad)`.
  SGD = stateless handler. Adam = handler with `m`, `v`, `t` state.
  Same training loop, different optimizer — swap the handler.
- **Refinement-typed tensors.** `type Tensor<T, Shape>` where
  `self.len() == product(Shape)`. Shape mismatches are compile
  errors. `LearningRate`, `Probability`, `BatchSize` as refined
  types — entire categories of ML bugs eliminated at compile time.
- **Hyperparameter search via multi-shot.** `Hyperparam` effect
  with `choose_lr()`, `choose_hidden()`, `choose_dropout()`.
  Handler resumes with each candidate — grid/random/Bayesian are
  handler strategies. Genuinely novel: no framework has language-
  level multi-shot hyperparameter search.
- **DSP-ML unification.** `mfcc` (DSP) and `conv1d` (ML) compose
  through `|>` with no adapter. A learned conv1d can replace a
  hand-designed mel filterbank — the swap is one line.
- **Compilation gates from effect algebra:**
  1. `!IO` → compile-time evaluation (constant folding)
  2. `Pure` → multi-core parallelization (safe, no annotation)
  3. `!IO, !Alloc` → GPU offload (F.5 backend required)
  4. `!Alloc` → embedded deployment (ARM Cortex-M7, Daisy Seed)
- **Progressive ML levels** (L1-L5): pure functional → + effects →
  + ownership → + refinements → full Inka. Never rewrite.
- **Handler parameters.** `handler lowpass(alpha: Float) with
  state = 0.0 { ... }` — named handlers take constructor arguments
  for configurable instantiation.
- **Handler composition.** Inference handler = training handler
  minus tape recording. No DRY violation.
- **Numeric polymorphism.** `Num` typeclass: one `sum` for all
  numeric types instead of `sum`/`sumf` split.

**What it unlocks:** The performance and native control of Rust
with the ergonomics of a functional language. Same model code trains
on desktop, deploys to ARM microcontroller with `!Alloc` proven at
compile time. The pipe topology shows DSP → ML → classification as
one continuous graph.

### Arc G — Rename (Lux → Inka)  *[LANDED]*

Done. Extension is `.nx` (2026-04-21); `.nx` is the previous
extension being migrated out per Pending Work item 10;
`lux3.wasm` is archaeology.

---

### Arc H — Examples-as-Proofs  *[DISSOLVED 2026-04-21]*

**Retired.** The `examples/` directory dissolves (see Decisions
Ledger 2026-04-21 entry). Every thesis claim originally scoped
as "one runnable example" is now satisfied by:

- The compiler's own `src/` — demonstrates handlers, pipes,
  effect algebra, ownership, refinements, HM inference,
  gradient, Reasons (every kernel primitive exercised in
  production).
- The stdlib's `lib/dsp/` — demonstrates `<~ delay(N)` feedback,
  `!Alloc + Sample(N)` proven real-time, DSP-as-handlers.
- The stdlib's `lib/ml/` — demonstrates autodiff-as-handler,
  training-vs-inference as handler swap.
- The stdlib's `lib/` more broadly — demonstrates Iterate effect,
  prelude, handlers-as-DI.
- `run.nx` entry-handlers — demonstrate testing-as-handler-swap,
  chaos testing, replay testing, all without separate test source.
- Integration projects (Pulse, a-day.md's worked scenarios) —
  live in their own separate repositories post-first-light.

The arc's original intent (one artifact per claim) is subsumed
by "the stdlib + compiler IS the set of artifacts." No separate
`examples/` directory.

---

### Arc I — DESIGN.md Audit

Trim to ≤500 lines. Core manifesto on one read.

---

### Arc J — Verification Dashboard

CI tracks `inka query --verify-debt` count per commit. Pre-F.1
measures accumulation; post-F.1 measures the trend toward zero.

---

## Spec Inventory

All twelve specs in `docs/specs/` (relocated from `docs/specs/`
per Pending Work item 17'):

| Spec | File (post-restructure) | Governs |
|---|---|---|
| 00 | 00-graph.md (was Graph) | Graph, flat array, O(1) chase |
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
| **Modal Effect Types** — `⟨E₁\|E₂⟩(E) = E₂ + (E − E₁)` as a principled semantics for Inka's `E - F`. Rows and Capabilities are both encodable in modal effects. | [Tang & Lindley POPL 2025](https://arxiv.org/abs/2407.11816) · [POPL 2026](https://arxiv.org/abs/2507.10301) | effects.nx |
| **Affect affine-tracked resume** — type-level distinction of one-shot vs multi-shot; Iris/Coq-mechanized. Directly solves Inka's D.1 (multi-shot × arena). | [Affect POPL 2025](https://iris-project.org/pdfs/2025-popl-affect.pdf) | effects.nx |
| **Koka evidence-passing compilation** — when the graph proves a call site's handler stack is monomorphic, emit `call $h_foo` directly. Kills val_concat drift at compile time. | [Generalized Evidence Passing JFP 2022](https://dl.acm.org/doi/10.1145/3473576) | lower.nx |
| **Perceus refcount + FBIP reuse** — precise RC + in-place update when ownership graph proves unique. Layer-2 memory fallback. | [Perceus PLDI'21](https://www.microsoft.com/en-us/research/wp-content/uploads/2021/06/perceus-pldi21.pdf) | Arc F.4 |
| **Lexa zero-overhead handler compilation** — direct stack-switching, linear vs quadratic dispatch. Makes effects free. | [Lexa OOPSLA 2024](https://cs.uwaterloo.ca/~yizhou/papers/lexa-oopsla2024.pdf) | Arc F.5 |
| **Salsa 3.0 / `ty` query-driven incremental** — flat-array substitution with epoch + persistent overlay. | [Astral ty](https://astral.sh/blog/ty) · [Salsa-rs](https://github.com/salsa-rs/salsa) | graph.nx |
| **Polonius 2026 alpha — lazy constraint rewrite** — location-sensitive reachability over subset+CFG. | [Polonius 2026](https://rust-lang.github.io/rust-project-goals/2026/polonius.html) | graph.nx, own.nx |
| **Flix Boolean unification** — 7% compile overhead for full Boolean algebra over effect rows. | [Fast Boolean Unification OOPSLA 2024](https://dl.acm.org/doi/10.1145/3622816) | effects.nx |
| **Abstracting Effect Systems** — parameterize over the effect algebra so +/-/&/! are instances of a Boolean-algebra interface. | [Abstracting Effect Systems ICFP 2024](https://icfp24.sigplan.org/details/icfp-2024-papers/18) | effects.nx |
| **Hazel marked-hole calculus** — every ill-typed expression becomes a marked hole; downstream services keep working. | [Total Type Error Localization POPL 2024](https://hazel.org/papers/marking-popl24.pdf) | types.nx |
| **ChatLSP typed-context exposure** — send type/binding/typing-context to LLM via LSP. Inka's `!Alloc` effect mask is free prompt budget. | [Statically Contextualizing LLMs OOPSLA 2024](https://arxiv.org/abs/2409.00921) | Arc F.2 |
| **Generic Refinement Types** — per-call-site refinement instantiation via unification. | [Generic Refinement Types POPL 2025](https://dl.acm.org/doi/10.1145/3704885) | Arc F.1 |
| **Canonical tactic-level synthesis** — proof terms AND program bodies for higher-order goals via structural recursion. | [Canonical ITP 2025](https://drops.dagstuhl.de/entities/document/10.4230/LIPIcs.ITP.2025.14) | Arc F (synthesis) |
| **Vale immutable region borrowing** — `!Mutate` on a region delivers "N readers, no writers" proof via existing effect algebra. | [Vale regions](https://verdagon.dev/blog/zero-cost-memory-safety-regions-overview) | Arc F (concurrency) |
| **bump-scope nested arenas** — checkpoints, default-Drop, directly mirrors Inka's scoped-arena-as-handler. | [bump-scope](https://docs.rs/bump-scope/) | Arc F.4 |
| **Austral linear capabilities at module boundaries** — capabilities ARE the transitivity proof. | [Austral](https://borretti.me/article/introducing-austral) | effects.nx |
| **Liquid Haskell 2025 SMT-by-theory** — Z3 for nonlinear arithmetic, cvc5 for finite-set/bag/map, Bitwuzla for bitvectors. | [Tweag 2025](https://www.tweag.io/blog/2025-03-20-lh-release/) | Arc F.1 |
| **Elm/Roc/Dafny error-catalog pattern** — stable error codes + canonical explanation + applicability-tagged fixes. | [Elm errors](https://elm-lang.org/news/compiler-errors-for-humans) | pipeline.nx |
| **Grove CmRDT structural edits** — edits commute; cross-module re-inference becomes a fold over commuting ops. | [Grove POPL 2025](https://hazel.org/papers/grove-popl25.pdf) | Arc F (incremental) |
| **Multiple Resumptions Directly (ICFP 2025)** — competitive LLVM numbers for multi-shot + local mutable state. | [ICFP 2025](https://dl.acm.org/doi/10.1145/3747529) | Arc F (multi-shot) |
| **Applicability-tagged diagnostics** — every "did you mean" emits a structured patch with confidence + effect-row delta. | [rustc-dev-guide](https://rustc-dev-guide.rust-lang.org/diagnostics.html) | pipeline.nx |

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

| Context | Strategy | Status |
|---|---|---|
| Compiler (batch) | Bump allocator — allocate forward, never free, exit | LANDED (emit_memory_bump) |
| Server (request-scoped) | Scoped arena handler — O(1) region free | substrate LANDED via H4; concrete handler PRIORITY 3 |
| Game (frame-scoped) | `own` + deterministic drop | substrate LANDED (affine_ledger); PRIORITY 3 refinement |
| Embedded/DSP | `!Alloc` — zero allocation, proven by types | LANDED (row subsumption + CRealTime unlock via H5) |

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

### Substrate invariant — HEAP_BASE = 4096

HB committed to a substrate-level threshold that separates sentinel
values from heap pointers:

- Bump allocator's `$heap_ptr` initializes at **1 MiB** (1048576).
- Sentinel values for nullary ADT variants (Bool's False=0 / True=1,
  Maybe's Nothing=0, etc.) live in `[0, 4096)`.
- Every heap allocation is **≥ 4096**, so sentinels and pointers are
  disambiguable by unsigned compare.
- Mixed-variant match dispatch (`emit_match_arms_mixed`) uses
  `(scrut < heap_base())` as the sentinel-or-pointer discriminator.
- `heap_base()` is a single-source-of-truth helper in
  `backends/wasm.nx`. Changing either the sentinel range or the
  heap initialization requires updating both at once.

This invariant enables nullary-sentinel compilation for every ADT
without per-type analysis. Bool is the canonical case;
user-declared `type Direction = Up | Down` inherits the same
zero-cost compilation.

---

## Structural Requirements — From Day One

Four structures that MUST be in the codebase from the start. Each,
if omitted, requires re-walking every AST node or every type to
retrofit. The cost of over-designing a field is trivial; the cost
of retrofitting one is measured in weeks.

1. **Ownership annotations in the Type ADT.** `TParam` carries
   `Ownership` (`Inferred | Own | Ref`). Without it, every function
   signature is ambiguous about move vs borrow, and `own.nx` has no
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

### Fully out of scope (never Inka, always handler projection)

- **Projectional AST.** Rejected. Text is canonical.
- **Fractional permissions.** Shelved; Vale region-freeze via
  `!Mutate` subsumes.
- **Multi-shot × arena full policy.** Structure in specs;
  handler semantics lands with concrete arena handlers.

### Substrate IN cascade, handler exposure PENDING

The γ cascade LANDED substrate for every category below. Handler
projection lands as Phase II work per the Handler Projection
Priority list.

- **Refinement types.** Substrate LIVE (`TRefined(Ty, Predicate)` in
  types.nx; `Verify` effect with `verify_ledger` accumulates
  obligations). Exposure PENDING: SMT handler swap (verify_smt with
  Z3/cvc5/Bitwuzla) — Arc F.1.

- **Mentl-voice surfaces** (formerly "LSP"). Substrate LIVE for the
  read side (`inka query` + Question/QueryResult ADT + render_query_result).
  Exposure PENDING: the `Interact` effect + Mentl's voice grammar +
  `enumerate_inhabitants` multi-shot primitive + REPL/CLI/playground
  peer handlers — Arc F.2 = Priority 1 (reframed). LSP as a paradigm
  is dissolved by the thesis.

- **Scoped arenas.** Substrate LIVE (Alloc effect, !Alloc negation,
  region_tracker with tag_alloc_join, EmitMemory swap surface).
  Exposure PENDING: concrete `temp_arena` / `thread_local_arena` /
  `diagnostic_arena` handlers — Priority 3.

- **REPL.** Substrate LIVE (pipeline variant with eval_expr handler
  is a one-handler install). Exposure PENDING: multi-shot
  continuation semantics (Replay / Fork / State machine) — Arc F.3.

- **Audit-driven severance.** Substrate LIVE (AuditReport records
  with severable + unlocks). Exposure PENDING: linker handler that
  reads severance list and drops WASM imports — Priority 2.

- **Native backend.** Substrate LIVE (multi-backend handler chain).
  Exposure PENDING: `backends/native.nx` as an alternate EmitBackend
  handler — Arc F.5 = Priority 2.

---

## Risk Register — post-cascade

Risks are categorized by phase. Closed risks from the γ cascade
are recorded for the project's memory; active risks lead.

### Active risks (Phase II + Phase III)

| Risk | Mitigation |
|---|---|
| Bootstrap translator is the one-shot moment a non-Inka language reads a closed substrate — a bug there corrupts the seed | Write the translator as a DIRECT TRACE of the cascade walkthroughs, not a separate interpretation. Verify by replaying the translator through `docs/traces/a-day.md`. |
| Mentl's voice ships before the voice design session closes; surfaces drift into cliché/chatbot register | `MV-mentl-voice.md` walkthrough is gating for ANY voice-surface code. Voice grammar (proof-shape templates, silence discipline) lands on paper before a single byte of REPL or CLI surface code. Character design is as load-bearing as substrate design here. |
| Mentl-voice surfaces proliferate before the core Interact effect stabilizes | Design order is CLI/REPL first; text transport forces discipline. Web playground, IDE-like client are later renderers on the same substrate. If Mentl's voice works in a terminal, it works everywhere; reverse is false. |
| Multi-shot `enumerate_inhabitants` thrashes checkpoint/rollback on branches that don't prove | Cap at N=8 verified-or-rejected branches per hole; pre-filter each resumed branch with `row_subsumes` before `graph_bind`; stop resuming once the cap is reached or the continuation exhausts. The pre-filter is load-bearing, not an optimization. |
| Multi-backend emit introduces per-target divergence that drifts over time | Shared substrate invariants live in `types.nx` and `effects.nx`; each backend handler declares its own effect row. Row subsumption proves which invariants the backend honors. |
| User-declared nullary variants collide with HEAP_BASE threshold (4096) | Total variants per type are bounded by tag_id length; no realistic ADT approaches 4096 variants. If a type ever does, the threshold widens; the invariant documents the coupling. |
| WASM stack overflow from deep recursion | Emit `return_call` for tail calls; wasmtime supports the proposal |

### Closed risks (γ cascade, now substrate-guarded)

| Risk (once) | Substrate that closes it |
|---|---|
| Substrate drift (patterns from other languages freezing Inka into foreign shapes) | 9 named drift modes in CLAUDE.md's Mentl anchor; H6 discipline refuses wildcards on load-bearing ADTs; every cascade step audited before commit. |
| ADT match silently absorbs a new variant via `_ => default` | H6 landed exhaustive matches at every load-bearing site. |
| Primitive-type special cases (TBool as C int-bool) | HB dissolved TBool; nullary-sentinel path compiles `type Bool = False \| True` to (i32.const 0/1) — same runtime as before, full ADT semantics at type level. |
| String-keyed when structured (effect names, constructor names, tokens) | Token ADT (Ω.4), EffName ADT (H3.1), SchemeKind ADT (H3), MatchShape ADT (HB audit) — all now structured. |
| Parallel-arrays-instead-of-record handler state | Ω.5 consolidated lower_scope and infer_ctx frames to records; H1.3 BodyContext state is a record; H4 region_tracker entries are records. |
| Evidence-as-sidecar (C calling convention) | H1's LMakeClosure unifies captures and evidence in one record shape — no `*const ()` vtable parameter. |
| VFINAL has bugs that surface during self-compilation | Deferred to first-light by design; substrate verified by simulation, not execution, per dream-code discipline. |

---

## Crystallized Insights

Ten load-bearing truths — defer to `CLAUDE.md` for the canonical
list (seven pre-cascade, three crystallized during γ). Summary:

1. Handler Chain Is a Capability Stack
2. Five Verbs = Complete Topological Basis
3. Visual Programming in Plain Text
4. `<~` Feedback Is Genuine Novelty
5. Effect Negation > Everything
6. The Graph IS the Program
7. Parameters ARE Tuples; `|>` Is a Wire
8. **The Heap Has One Story** (γ crystallization — closures +
   variants + records + closures-with-evidence share one
   emit_alloc swap surface)
9. **Records Are The Handler-State Shape** (γ crystallization —
   Ω.5 / BodyContext / region_tracker / AuditReport all converge)
10. **Row Algebra Is One Mechanism Over Different Element Types**
    (γ crystallization — string-set / name-set / field-set /
    tagged_values instances, one abstract pattern)

CLAUDE.md also names the **backward-bootstrap fixed-point** as
Phase IV's soundness proof (historically insight 7; kept as the
terminal invariant).

---

## Key Documents

*(Paths reflect post-restructure state — item 17' of Pending Work.
Pre-restructure: `docs/specs/` = `docs/specs/`, `.nx` = `.nx`,
`src/` = `std/compiler/`, `lib/` = `std/runtime/` + `std/*.nx`.)*

| Document | Role |
|---|---|
| **docs/PLAN.md** | THIS FILE. The single roadmap. Decisions Ledger + four phases + Pending Work exhaustive list (items 1–51). |
| **docs/DESIGN.md** | The manifesto. §0.5 enumerates the eight-primitive kernel; Ch 1–11 develop each; Ch 12 closes the medium thesis. Required reading end-to-end. |
| **docs/INSIGHTS.md** | Living compendium of crystallized truths. Kernel shorthand at top. |
| **docs/SYNTAX.md** | Canonical syntax. Every parser decision implements something here. Maps each surface to a kernel primitive + Mentl tentacle. |
| **docs/specs/00–11** | The 12 executable specs (`00-graph.md` onward). Each spec names its kernel primitive(s) and Mentl tentacle(s). |
| **docs/specs/simulations/H*.md** | Per-handle cascade walkthroughs. Reasoning record. |
| **docs/specs/simulations/MV-mentl-voice.md** | Mentl-voice substrate walkthrough (in-flight). |
| **docs/specs/simulations/IR-intent-round-trip.md** | Intent round-trip meta-walkthrough — names the principle; indexes the eight peer walkthroughs (EN · RN · OW · VK · GR · RX · HI · DS); gates Phase II. Seeded 2026-04-22. |
| **docs/specs/simulations/EN-effect-negation.md** | Effect-negation substrate walkthrough (primitive #4 intent round-trip — FV.1 reframed as α+γ+δ+β peers; seeded 2026-04-22). |
| **docs/specs/simulations/RN-refinement-alias.md** | Refinement-alias intent preservation (primitive #6 round-trip; seeded 2026-04-22). |
| **docs/specs/simulations/OW-ownership-intent.md** | Ownership-intent preservation (primitive #5 round-trip; seeded 2026-04-22). |
| **docs/specs/simulations/VK-verb-kind.md** | Verb-kind intent preservation (primitive #3 round-trip; seeded 2026-04-22). RX's `InferredPipeResult` carries verb identity in Why chains. VK.1 query op awaits AST span index. |
| **docs/specs/simulations/GR-gradient-delta.md** | Gradient-delta intent preservation (primitive #7 round-trip; seeded 2026-04-22). |
| **docs/specs/simulations/RX-reason-intent.md** | Reason-intent audit — **LANDED** `a783477`. 3 new Reason variants (InferredCallReturn, InferredPipeResult, FreshInContext), ~20 sites enriched Grade B→A, Grade C→structured. |
| **docs/specs/simulations/HI-handler-identity.md** | Handler-identity — **HI.1 LANDED** `0f0f26b`. ~> tee sites carry authored handler names (callee_name). HI.2 query op + HI.3 hover pending. |
| **docs/specs/simulations/DS-docstring-edge.md** | Docstring-as-intent-edge — **LANDED** `d8dd725`. Documented(String, Node) stmt wrapper + DocstringReason + parser attachment + infer threading + lower pass-through. |
| **docs/specs/simulations/NS-naming.md** | Naming-audit walkthrough (TBD, item 4 of Pending Work). |
| **docs/specs/simulations/NS-structure.md** | Structural-reshape walkthrough (TBD, item 5). |
| **docs/specs/simulations/EH-entry-handlers.md** | Entry-handler substrate walkthrough (TBD, item 6). |
| **docs/specs/simulations/SIMP-simplification-audit.md** | Simplification-pass discipline (TBD, item 7). |
| **docs/specs/simulations/DET-determinism-audit.md** | Determinism-audit walkthrough (TBD, item 8). |
| **docs/specs/simulations/LF-feedback-lowering.md** | LFeedback state-machine lowering (TBD, gates item 1). |
| **docs/specs/simulations/Hβ-bootstrap.md** | Final cascade handle — hand-WAT conventions (TBD, item 9). |
| **docs/traces/a-day.md** | Integration trace. One developer, one project, one day. Every claim tagged `[LIVE]` / `[LIVE · surface pending]` / `[substrate pending]`. The scoreboard. |
| **docs/errors/** | Error catalog (prefix-kind string codes, kernel-grounded). |
| **CLAUDE.md** | Mentl's anchor + eight interrogations (one per kernel primitive, one per tentacle) + nine drift modes + Session Zero + ten crystallizations. Required reading at session start. |
| **README.md** | First-read; kernel enumeration; Repository layout as canonical Inka-project template. |
| **bootstrap/inka.wat** | Hand-written WAT reference image (empty until hand-write begins post-item 9; kept forever post-first-light). |
| **bootstrap/first-light.sh** | Fixed-point test harness. |

---

## Handoff Posture — 2026-04-22 (Antigravity IDE / Opus 4.6 — single thread)

Claude Code weekly quota exhausted 2026-04-22 (99%). Work resumes in
Google Antigravity under Opus 4.6 for ~1 day. **Antigravity is a
single thread**: no skills (no `/inka-plan`), no subagent dispatch
(no `inka-planner`, no `inka-implementer`), no user settings for
hooks. Opus 4.6 plays every role inline. This block is a complete
self-contained operating manual.

### Read order on session open (every time — this IS Session Zero)
1. `CLAUDE.md` end-to-end (~8k words; non-negotiable).
2. `docs/DESIGN.md` end-to-end on first session; thereafter §0.5
   (kernel primitives) + the chapter for the module about to be
   touched.
3. The relevant `docs/specs/simulations/H*.md` or topical walkthrough
   (FU / HC / MV).
4. This Handoff Posture section.
5. `memory/MEMORY.md` index + any file it points to that feels relevant.
6. Synthesize back in 3–5 sentences touching each of the 8 kernel
   primitives. Only then propose or edit.

### Cursor (as of 2026-04-22)
- Last commits on `rebuild`: `1ae46f9` (initial handoff block),
  `934dedd` (FV.3.1 `TagId` applied). FV.2 at `005d66d`, FV.3 at
  `f7c6774`.
- Full `std/` tree (29 `.nx` files) drift-audit CLEAN.
- Zero uncommitted working-tree edits. Zero in-flight dispatches.

---

### The `inka-plan` contract — inlined (since the skill is unreachable)

**Every `.nx` edit follows this shape before tokens are typed.**
Write the plan either in chat or in your head; type the residue
only. Opus 4.6, you are the planner. Do not skip sections because
"it's just a small edit" — fluency is the trap this contract closes.

**§1 Session Zero stub (3-5 sentences).** Pre-filled template:
> This edit lands inside [handle / module]. The medium here is the
> [Graph / Env / handler chain / LowIR] already carrying [what].
> The one mechanism — graph + handler — means [how it hosts this
> without new substrate]. The verb drawing this topology is [`|>` /
> `<|` / `><` / `~>` / `<~`] because [reason]. Mentl, as oracle,
> already [projects / audits / teaches] [what]; the residue is [1-3
> lines of shape].

**§2 Walkthrough citation.** Quote the exact paragraph from the
relevant `docs/specs/simulations/*.md` that decides this design
point. **Not a summary — the paragraph.** If no walkthrough exists
for this work, the plan is premature; write the walkthrough first.

**§3 The 8 interrogations, answered per edit site.** (One per kernel
primitive; see `CLAUDE.md` §"Mentl's anchor" for the canonical
framing. Four-question and nine-question earlier forms are
superseded.)
- **Graph?** What handle / edge / Reason in Graph + Env already
  encodes this?
- **Handler?** What installed handler projects this — and with what
  resume discipline (`@resume=OneShot|MultiShot|Either`)?
- **Verb?** Which of `|>` `<|` `><` `~>` `<~` draws this topology?
- **Row?** What `+ - & ! Pure` constraint already gates this?
- **Ownership?** What `own` / `ref` / `Consume` / `!Alloc` /
  `!Mutate` already proves linearity or non-escape?
- **Refinement?** What `where` predicate or `Verify` obligation
  already bounds the value?
- **Gradient?** What annotation unlocks this as a compile-time
  capability instead of a runtime check?
- **Reason?** What Reason edge should this decision leave for the
  Why Engine?

**§4 Edits as literal tokens at file:line.** Not prose. Exact form:
```
std/compiler/<file>.nx:<line_range>
  DELETE: <current tokens, verbatim>
  WRITE:  <new tokens, verbatim, canonical formatting>
```
Canonical formatting (Anchor 6): `|>`/`~>` at LEFT edge, `><`/`<~`
at INDENTED CENTER, `<|` at left edge before branch tuple, handler
composition as `~>` chains not nested `handle(handle(...))`.

**§5 Forbidden-pattern list, scoped per edit.** For each of drift
modes 1-9 (`CLAUDE.md` → Mentl's anchor), name the specific pattern
that would silently absorb this edit if typed fluently, or write
"N/A — [why]." **Do not omit this section** — fluency is highest
precisely when you feel most competent.

Also screen for bug classes at the edit site: `_ => <fabricated>`
masks, `acc ++ [x]` loops, `list[i]` in Snoc paths, bare `==` on
strings (use `str_eq`), `println` inside `report`, `mode == 0`
int-coded dispatch, `|| true` failure-masks, `HEAP_BASE` constant
collisions.

**§6 Post-edit audit.** Always:
```
bash tools/drift-audit.sh <files touched>
```
Must exit 0. Non-zero = edit not complete. **Do not commit.**
Antigravity lacks Claude Code's PreToolUse hooks that auto-gate
this — the discipline is manual.

**§7 Landing discipline.** Is this a whole handle that lands in one
commit, or a peer sub-handle named in PLAN.md with its own
walkthrough? If "substrate done / wiring later" tempts you, STOP —
that is drift mode 9 (deferred-by-omission). Land whole, OR split
the deferred piece into its own named peer sub-handle with its own
walkthrough and its own plan.

---

### The `inka-implementer` discipline — inlined

Opus 4.6, you are the implementer too. Hold both roles honestly:

- **Refuse prose-only plans.** "Implement frame consolidation in
  H1.3" is not a plan. The plan is delete/write tokens at
  file:line. If you catch yourself planning in prose, restart in
  tokens.
- **Run drift-audit after every file touch.** Manual discipline —
  Antigravity has no hooks. `bash tools/drift-audit.sh <file>`.
- **Refuse to commit with non-zero audit.** Diagnose and fix.
  **Never `|| true`, never `--no-verify`.** If unsure how to fix,
  pause — do not decorate.
- **One peer sub-handle per commit.** No "substrate done / wiring
  later" splits.
- **No Claude attribution in commits.** Ever. No `Co-Authored-By`,
  no `🤖` trailer, no inline mentions. Morgan writes commits alone.
- **Never dream-code drift.** If a construct doesn't parse yet in
  the current compiler, that's fine — this IS dream code. But the
  shape must be Inka-native, not a foreign-language pattern in
  Inka clothing.

---

### FV queue order for single-thread Opus 4.6

All FV items are now single-tier (Opus 4.6 plans + edits + audits +
commits inline). Recommended order by **single-thread safety**
(mechanical first; judgment work deferred to fresh Claude Code):

| # | Item | Kind | Scope |
|---|---|---|---|
| 1 | **FV.3.2** `ValidOffset` → lexer + parser byte positions | Mechanical | ~15 sites in lexer.nx + parser.nx |
| 2 | **FV.3.4** `ValidSpan` → every `Span(sl,sc,el,ec)` construction | Mechanical | ~25 sites across lexer / parser / infer |
| 3 | **FV.3.3** `NonEmptyList<A>` → where comments assert `len > 0` | Mechanical | Grep for "len > 0" / "non-empty" assertions |
| 4 | **FV.9** docstring harmonization | Mechanical | BLOCKED — lock NS-naming template first |
| 5 | FV.4 ownership markers (`own` / `ref` / `!Mutate`) | Judgment | Per-fn analysis |
| 6 | FV.5 five-verb exemplar (`<\|` / `><` / `<~` one site each) | Judgment | Per-site judgment |
| 7 | FV.1 `!E` negation sweep | — | **BLOCKED — substrate cluster** (walkthrough at `docs/specs/simulations/EN-effect-negation.md`; reframed as α intent-preservation + γ lone-`!E`-semantics + δ named-capability-bundles + β polymorphic-applied-exemplar; ordering α→γ→δ→β) |
| 8 | FV.8 parameterized Diagnostic / 11.B.M | Judgment + cross-cutting | **Recommended to DEFER** |
| — | FV.6 string interpolation | BLOCKED | Lexer `scan_string` does not parse `${}` |
| — | FV.7 `~>` chain sweep | Likely no-op | Pre-audit found no nested `handle(handle(...))` |

**Why defer FV.1 / FV.8 to fresh Claude Code:** those items earn
cross-cutting judgment under the `inka-implementer` system prompt's
discipline that this inline contract approximates but does not
replicate fully (subagent-isolation, hooks, PostToolUse drift audit).
Mechanical FV.3.x items exercise the full inline discipline safely;
judgment items amplify drift risk in single-thread.

---

### Do NOT touch before first-light
Rise-after-floor-is-up surfaces. Drifting into any of them before
hand-WAT Tier 3 delivers byte-identical self-compilation is drift
mode 9 flipped (work landing before its prerequisite):
- **Syntax highlighting** / TextMate grammar / tree-sitter wrapper.
- **`mentl_voice_default` implementation.** `MV-mentl-voice.md`
  §2.8 AT1-AT10 ARE the contract; substrate lands post-first-light.
- **LSP adapter + VS Code extension.** Post-first-light.
- **Web playground / α-β-γ-ε options** from the 2026-04-22 brainstorm.
- **FV.6 string interpolation.** BLOCKED on lexer substrate.

### HC rosetta — 2026-04-21 crystallization (unchanged)
`HC-handler-composition.md` names four live ripple points:
- **11.C.2** frame-record restructure (parallel lists → OrderedMap).
- **11.B.M** parameterized Diagnostic (absorbs FV.8).
- **Hα** operator-semantics-as-handler (each of the five verbs).
- **MV.2** tentacles transform-yield; LSP surfaces materialize.

### Runtime tooling (Antigravity terminal-accessible)
- `bash tools/drift-audit.sh <files>` — exit 0 required before commit.
- `.githooks/pre-commit` — enforces drift-audit on staged `.nx`
  files. Ensure `git config core.hooksPath .githooks` is active
  (check with `git config --get core.hooksPath`; if not, run the
  command before the first commit).
- `git log --oneline -10` — current landing state.
- **WABT** (WebAssembly Binary Toolkit) — full inventory:
  - `wat2wasm` — WAT → WASM assembly. Flags: `--debug-names`,
    `--enable-tail-call`, `--enable-exceptions`, `-v`.
  - `wasm-validate` — spec conformance validation.
  - `wasm2wat` — WASM → WAT disassembly (round-trip verification).
  - `wasm-objdump` — section layout, imports/exports, disassembly.
  - `wasm-decompile` — WASM → C-like pseudocode (readable).
  - `wasm-interp` — stack-based interpreter (determinism cross-check).
  - `wasm-stats` — module statistics (function count, code sizes).
  - `wasm-strip` — remove debug/custom sections (production builds).
  - `wat-desugar` — canonicalize WAT formatting (diff normalization).
  - `wasm2c` — WASM → C source (escape hatch, distant future).
  See `docs/specs/simulations/Hβ-bootstrap.md` §5.1 for detailed
  roles + commands.
- **wasmtime** v44.0.0 (April 2026) — runtime target. Tail calls
  stable/default-on. WASI preview1 fully supported.
- **WASM 3.0** (W3C standard, September 2025) — tail calls, SIMD,
  multiple memories, exception handling, 64-bit memory all
  standardized. Inka uses tail calls (OneShot dispatch); does NOT
  use WasmGC (own bump allocator), Component Model, or WASI 0.2/0.3.

### If stuck — honest options
- **Pause.** Do not decorate, do not add flags, do not "get it
  working for now." Commit what's clean; stop.
- **Return to Claude Code when weekly resets** (check usage via the
  CLI). Some work (FV.1, FV.8, new walkthroughs) benefits from the
  `inka-implementer` / `inka-planner` subagent system prompts this
  inline section approximates but does not fully replicate.
- **Read, don't code.** If the medium is unclear, re-read the
  walkthrough. If the walkthrough is unclear, re-read DESIGN.md
  §0.5. **Reading is work. Drift is a regression.**

### Recommended first cut in Antigravity
**FV.3.2** (`ValidOffset` applied to lexer + parser byte positions).
Lowest-risk mechanical cut; exercises the full inline discipline
(plan → 8 interrogations → literal tokens → drift-audit → commit)
without cross-cutting judgment.

Inventory to seed the plan (grep before committing):
```
grep -n "pos: Int" std/compiler/lexer.nx
grep -n "pos: Int\|pos += \|self\.pos" std/compiler/parser.nx
```
(Expect ~15 applied sites between the two files. Actual count
depends on current shape; verify before planning.)

If FV.3.2 clears clean, proceed to FV.3.4 (`ValidSpan`) using the
same pattern.

### Do NOT attempt in Antigravity
- **FV.1 `!E` negation sweep.** BLOCKED on substrate finding
  2026-04-22 (closed-row negation collapses in `normalize_inter`;
  declarative `!E` adds no substrate on monomorphic closed-row
  sites — which is every site in the compiler). Reframed as two
  peer sub-handles (FV.1.α substrate decision + FV.1.β polymorphic
  exemplar) that each require a walkthrough before code. See the
  FV.1 entry in Pending Work item 25 for the full finding.
- **FV.8 parameterized Diagnostic / 11.B.M.** Cross-cutting judgment
  — save for fresh Claude Code session with `inka-implementer`
  under Opus-dispatch.

### Handoff endpoint
When weekly resets: `git log --oneline -20` to confirm Antigravity's
landings. Resume this handoff section from "FV queue order" — the
cursor will have advanced but the discipline framing is stable.
