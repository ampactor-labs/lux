# MS2 — Multi-Shot Continuations: Full-Territory Traversal

> **Status:** `[DRAFT 2026-04-23]`. Deep-exploration peer of
> `MS-multishot-topology.md` (the original five-verbs × multi-shot
> brainstorm). This document traverses the full eight-primitive
> kernel × MultiShot composition, the domain territory MS unlocks
> (search / probability / ML / parsing / distributed / testing /
> games / verification / debugging / compiler / graphics / physics
> / finance / agents / language design), Mentl's oracle substrate,
> the emergent topology (frameworks dissolved, cross-domain fusions
> only Mentl can express), and the drift risks MS introduces.
>
> *Claim in one sentence:* **MultiShot is the kernel's temporal
> axis. Composed with the other seven primitives, it produces a
> medium where every domain-specific library in the industry
> becomes a handler stack on the kernel.**

---

## 0. Framing — what MS is not, then what it is

### 0.1 What MS is NOT

MultiShot is not:

- **Threading.** Threading is spatial concurrency; MS is temporal
  forking. Spatial parallel composition is `><`, primitive #3's
  parallel-compose verb. Running MS on multiple cores is a handler
  combinator (`race`), not MS itself.
- **Generators / coroutines.** Those are single-resumption
  patterns with one continuation per yield; MS is
  multi-resumption where the SAME continuation is re-entered N
  times with different values. Generators are one resume discipline
  (OneShot); MS is a peer discipline, not a subset.
- **call/cc or undelimited continuations.** Scheme's call/cc
  captures the full stack up to the program's entry. MS captures
  the delimited continuation between a `perform` and its enclosing
  `handle` — scoped, typed, tractable. (Drift mode 2: Scheme env
  frame. Don't reach for Scheme vocabulary.)
- **Rust async.** Async is one specific resume discipline (OneShot
  with state machine); MS has the same compilation substrate but
  typed to allow multiple resumes.
- **A hack on top of exceptions.** Exceptions are OneShot with no
  resume at all. MS is structurally different in the graph's `Ty`.

### 0.2 What MS IS

MultiShot is the **typed resume discipline `@resume=MultiShot`**
that appears as part of an effect op's type signature (DESIGN Ch 1
+ spec 06). Every effect op is born with one of three resume
disciplines:

- **OneShot** (>95% of perform sites in practice, per H1 evidence
  reification): the handler resumes exactly once before returning.
  Compiles to direct `return_call` or tail call through closure
  field. Zero indirection, zero heap.
- **MultiShot**: the handler may resume multiple times, with
  different values, in succession. Each resume re-enters the
  delimited continuation. Compiles to a heap-captured closure
  struct — captures + evidence + return slot — allocated through
  the SAME `emit_alloc` surface as every other heap value (γ
  crystallization #8 "the heap has one story").
- **Either**: the handler chooses; the compiler prepares the MS
  substrate but may emit direct call if inference proves the arm
  is OneShot in context.

**The resume discipline is TYPED.** Writing `effect Choice {
choose(options: List<A>) -> A @resume=MultiShot }` means every
caller knows, at compile time, that `choose` may produce
backtracking. The type system enforces compatibility: a handler
that only resumes once cannot claim MultiShot capacity without
structural proof; a handler that forks cannot be installed where
only OneShot is expected.

**The trail is the substrate that makes MS tractable.** Every
`graph_bind` during a speculative run records a `Mutation(handle,
old_node)` in a flat buffer keyed by `trail_len`. Rollback is a
backward walk: `for i in [trail_len..checkpoint]: apply_inverse(trail[i])`.
O(M) exact, cache-friendly, no allocation, no linked-structure
walk (spec 00 + DESIGN Ch 4).

This trail is what Rust, Haskell, and Koka don't have. Rust has
no MS at the language level (you build it as a state machine by
hand). Haskell has monadic CPS but no unified graph + trail;
rollback is per-monad and composition is manual. Koka has typed
row-polymorphic effects with MS support but no Boolean algebra —
no `!Choice`, no negation, no Verify discharge integrated with the
resume discipline. Affect (POPL 2025) gives the typed-resume-as-
part-of-op-signature result formally; Mentl is the first production
medium to compose it with the other seven primitives.

---

## 1. MultiShot × the eight kernel primitives

*The full composition. Each section answers: "what does MS do to,
and receive from, this primitive?"*

### 1.1 MS × Graph + Env (primitive #1)

The graph is the substrate MS rolls back against. Every MS fork
captures a checkpoint (`graph_push_checkpoint() -> Int`, returns
`trail_len`); every rollback replays the trail backward to that
length. Env extensions inside a fork (via `env_scope_enter`) are
trail-recorded and unwound on rollback.

**Implication:** the graph is **per-fork state-preserving by
identity**. Two forks that diverge on a `graph_bind(h, ty_a, r_a)`
vs `graph_bind(h, ty_b, r_b)` are genuinely exploring two type
universes; the graph after fork A's rollback is bit-identical to
the graph before fork A began.

**No silent leak.** If a fork extends env with a new binding and
rolls back without the explicit `env_scope_exit`, the trail
contains the extension inverse; rollback replays it. There is no
"residue state" from a failed fork — the substrate is atomic at
checkpoint granularity.

**What MS gives the graph:** a substrate-level primitive for
speculative mutation. The graph's designer (spec 00) already had
to solve rollback for inference's unify-fail path; MS just makes
that substrate user-visible via `Synth` and `Choice` effects.

### 1.2 MS × Handlers with typed resume (primitive #2 — itself)

MS is primitive #2's temporal axis. The primitive says "handlers
with typed resume discipline"; MS is what makes "typed" load-
bearing. Without MS, the discipline has only one interesting
value (OneShot); with it, the discipline is a genuine type-level
constraint.

**Nesting composition.** A MS handler installed inside a OneShot
handler's body: the OneShot body runs once; inside, the MS handler
may fork the inner computation; the fork collapses at the MS
handler's boundary before returning to the OneShot body.

A OneShot handler installed inside a MS handler's body: every
fork of the MS handler has its own copy of the OneShot handler —
they don't interfere because each fork's delimited continuation
includes the OneShot handler's state.

**Capability stack × resume discipline:** the `~>` chain per
DESIGN Ch 2 is a trust hierarchy; the resume discipline of each
handler in the chain is ALSO part of the trust surface. Installing
a MS handler outside a `!Alloc` handler is a type error — the MS
resume allocates, the `!Alloc` guarantee forbids. The compiler
proves the chain well-formed at install time.

### 1.3 MS × Five verbs (primitive #3)

This is where Gemini's MS doc started. Extending per verb:

#### 1.3.1 `|>` (converge) × MS

Per Gemini §1-3 (paraphrased): at a MS fork, the REST of the pipe
re-evaluates per fork. `data |> f |> g` where `f` performs a MS
op: the handler resumes N times; each resume re-enters `|> g`
with the forked value. `g` runs N times.

**Deeper:** the pipe is a **wire carrying a typed value**; the
wire carries PER-FORK-UNIQUE data without any explicit
per-fork-plumbing. The developer writes ONE pipeline; the MS
handler decides how many realities flow through it.

**Consequence:** Monte Carlo methods look like straight-line code:

```
particle |> advect(dt) |> sample_velocity ~> gaussian(sigma) |> update_state
```

If `sample_velocity`'s handler forks 1000 times, the whole line
runs 1000 times. One line, 1000 particles.

#### 1.3.2 `<|` (diverge) × MS

Per Gemini §1: borrow shares input. Inline handler (Form B)
contains MS fork within ONE branch; block handler (Form A) drags
ALL branches into the fork.

**Deeper:** `<|` is an **ownership-structural** operator (DESIGN
Ch 2). `own` values cannot flow through `<|` — it would consume
the same value multiple times (affine violation). This constraint
COMPOSES with MS: a MS fork inside a `<|` branch is fine because
the branch borrows (not consumes); BUT if the forked computation
tries to consume the shared input, compile error.

**Novel pattern:** `<|` with three parallel heuristics, each MS-
forking independently, collapsing to survivors at the tuple
boundary, passing the survivor tuple to a judge:

```
constraint_state
    <| (
        heuristic_greedy ~> collect_best_of(8),
        heuristic_genetic ~> evolve_to(1000),
        heuristic_mcts ~> simulate_until(deadline)
    )
    |> pick_best_overall
```

Each branch's MS is CONTAINED by its inline `~>`. Three parallel
optimization strategies. One line of source. The collapse handlers
are where the MS harvest happens.

#### 1.3.3 `><` (parallel compose) × MS

Per Gemini §2: outside MS handler forks the whole zip; inside MS
handler collapses per branch. Correct.

**Deeper:** `><` is the only verb where two genuinely independent
MS trees can run without spatial overlap. The ownership substrate
makes this proof-bearing: tracks are `own`-independent; fork
explosion on track A does not touch track B's state.

**Consequence:** **federated learning** as one line:

```
(client_a_data |> train_local ~> mcmc_posterior)
    ><
(client_b_data |> train_local ~> mcmc_posterior)
    ><
(client_c_data |> train_local ~> mcmc_posterior)
    |> aggregate_posteriors
```

Each client runs MS-based posterior sampling on its own data;
`><` proves the clients don't cross-contaminate; `aggregate`
merges. No framework. Three handlers + one pipeline.

#### 1.3.4 `~>` (tee / handler-attach) × MS

`~>` is where MS LIVES. Every MS handler is installed via `~>`.
The capability stack × MS is the substrate for trust-scoped
speculation: `~> synth_enumerative` innermost, `~> synth_smt`
middle, `~> synth_llm` outermost — innermost fires first; bubble
on `NoCandidate`.

**Deeper:** Form A vs Form B of `~>` determines MS scope. Block-
scoped (Newline before `~>`) wraps the whole prior chain; inline
wraps ONE stage. MS fork under Form A propagates up the pipeline;
under Form B it's contained.

**Novel pattern:** **layered search** via `~> race`:

```
query
    |> plan_execution
    ~> race(plan_smt, plan_enumerative, plan_llm)
    |> execute_best
```

`race` is a handler combinator (DESIGN Ch 8.10.3): runs all three
planners in parallel as MS forks; first verified candidate wins;
others are rolled back via shared checkpoint. Fastest PROVEN plan
wins.

#### 1.3.5 `<~` (feedback) × MS

Per Gemini §3: MS feedback loop = particle filter. Thousand
particles in five lines.

**Deeper:** `<~` requires an iterative context (Sample, Tick,
Clock, Iterate). Each context defines what "one step back" means.
MS × `<~` composes across timescales:

```
// Audio-rate particle filter
signal
    |> predict_next
    ~> particle_filter(n_particles = 1024)
    |> measure_error
    <~ accumulate(0)
    |> resample_at_ess_threshold
```

Under `Sample(44100)`, `<~` is one sample back; under `Tick`,
one logical step; under `Clock(wall_ms=1)`, one millisecond. MS
fork into 1024 particles per step; `<~` feeds EACH particle's
state to the next step. 1024 independent feedback loops, one
source, one handler swap changes the timescale.

**Implication:** adaptive signal processing (LMS, RLS, Kalman)
becomes particle-filter-universal. The same line of code runs
as a deterministic filter (1 particle) or a stochastic filter
(N particles) by handler swap. No framework change. No fork-join
orchestration. The topology is drawn on the page; MS decides how
many realities flow through it.

### 1.4 MS × Boolean effect algebra (primitive #4)

The resume discipline is part of the op's type; the op is a member
of an effect row. Union, subtraction, intersection, negation all
traverse the resume discipline.

**Critical composition:** **`!Choice` proves determinism.** A
function declared `with !Choice` (where `Choice` is the canonical
MS effect) is statically proven to never fork. No speculative
rollback. No alternate realities. Deterministic execution.

`Pure` is stronger: it subsumes `!Choice` (no MS allowed because
no effects allowed). `!Alloc` composes: a function with `!Alloc +
Choice` can fork but cannot allocate — so only **replay-safe**
MS is admissible (DESIGN Ch 6.D.1). The compiler enforces: any MS
arm that would fork-copy data inside `!Alloc` context is a type
error at install time.

**Novel:** **`!MultiShot` as a row modifier.** The resume
discipline becomes a first-class effect-row element:

```
fn deterministic_core() with Pure + !MultiShot = ...
```

Equivalent to saying "this function touches no state AND cannot
be forked by any ambient MS handler." Stronger than `Pure` alone
because it forecloses future wrap-handlers that might install MS
over the body. Proof by substrate: no MS in transitive row.

(Today's spec doesn't separate `!MultiShot` from `!Choice`; this
is a latent extension that `affine_ledger`-style analysis would
enable once resume discipline is a first-class row constant.)

### 1.5 MS × Ownership as effect (primitive #5)

The D.1 question (DESIGN Ch 6): multi-shot × scoped arena. Three
named handlers satisfy it:

- **Replay-safe** (default v1): the continuation is re-derived by
  replaying the effect trace up to the perform site. Every resume
  costs a replay; arena state is coherent because it's re-derived.
- **Fork-deny** (strict): at capture time, if the continuation
  captures arena-owned data, `T_ContinuationEscapes` fires. Use
  for maximum safety at cost of expressivity.
- **Fork-copy**: deep-copy arena-owned data into the caller's
  arena on capture. Allocation cost; no semantic surprise.

**The handler IS the policy.** `handle ... with replay_safe`
commits one policy; `~> fork_deny` commits another. User picks
per usage; compiler enforces compatibility at install via row
subsumption.

**`!Alloc` × MS is special.** Forking a MS continuation ALLOCATES
(the closure struct holds captures + evidence + return slot).
`!Alloc` forbids allocation. Therefore inside `!Alloc` context,
**only replay-safe MS is admissible** (replay doesn't allocate; it
re-performs upstream ops). This is the mechanism that makes real-
time audio (which needs `!Alloc`) compatible with speculative
exploration (which needs MS): replay is the bridge.

**Novel consequence:** **deterministic real-time search.** A
real-time control loop can speculatively explore K candidate
actions per tick under `!Alloc`, replay-safe, within deterministic
bounds per tick. Robotics, autonomous driving, reactive
scheduling — the thesis scales to domains where speculative AI is
today considered too risky for hard-realtime.

### 1.6 MS × Refinement types (primitive #6)

**Speculative verification** is the MS-native form of type-
directed synthesis. The `Verify` effect (primitive #6's op)
discharges refinement obligations; MS speculates candidate
annotations; Verify accepts or rejects; rollback on rejection.

**The compound substrate:**

```
fn candidate_annotation(hole: Int) -> Option<Annotation>
    with Synth + Verify + GraphRead + GraphWrite =
    let checkpoint = perform graph_push_checkpoint()
    let candidate = perform synth(hole, expected)
    perform apply_patch_tentative(candidate)
    let verified = perform verify_obligations()
    perform graph_rollback(checkpoint)
    if verified { Some(candidate.annotation) } else { None }
```

**Novel:** **refinement SMT as handler race.** When multiple theory
solvers are installed (`verify_smt_z3`, `verify_smt_cvc5`,
`verify_smt_bitwuzla`), a `~> race` handler launches all three as
MS forks; first solver to verify wins; others are rolled back.
Per-residual-theory dispatch becomes per-predicate handler
selection at runtime. No theory-routing table; the capability
stack IS the dispatch.

**The gradient's top** (primitive #7) intersects here: as types
tighten, candidates shrink; MS enumeration becomes tractable;
eventually the refinement has exactly one inhabitant and the
program writes itself. Speculative verification is the mechanism
by which tight refinements translate to "the code writes itself"
(DESIGN Ch 5 "the gradient is circular").

### 1.7 MS × Continuous annotation gradient (primitive #7)

**This is the oracle loop.** Per MO walkthrough. Each candidate
annotation on the gradient is a MS fork; verify discharges; tie-
break picks the survivor; Mentl surfaces it.

**Deeper:** the gradient's BOTTOM (full inference, no annotations)
and TOP (full specification, tight refinements) converge via MS.
Bottom uses MS to explore inferred types until one unifies; top
uses MS to enumerate inhabitants of a tightly-constrained type
until one matches intent. Both are "you say what you mean, the
language handles the rest" (DESIGN Ch 5.3). MS is the mechanism
of "handles the rest."

**Implication:** **the gradient is itself a MS exploration.**
Morgan writes intent; Mentl MS-explores the annotation lattice;
one surfaces. The developer never sees the exploration; they see
one proven hint per turn.

### 1.8 MS × HM inference with Reasons (primitive #8)

Every MS fork records Reasons on its `graph_bind` events. The
rollback unwinds the Reasons along with the bindings. The
COMMITTED candidate's Reason chain is the proof of why Mentl
proposed it — not a post-hoc justification, but the actual
substrate trace.

**Novel capability:** **"Why did Mentl propose this?"** answered
by walking the committed fork's Reason chain. The user can see
the full speculative trace: candidates tried, candidates rejected,
candidate chosen, rejection reasons per candidate, acceptance
reason for chosen. This is the "audit log" for AI proposals,
built into the substrate.

Industry AI coding tools cannot do this. LLMs don't emit provable
Reasons; they emit plausible tokens. Mentl's MS × Reason
composition IS the transparency that LLMs can only simulate.

---

## 2. Domain traversals — what MS unlocks

*Each subsection: one domain, one-paragraph thesis + one code
sketch showing how MS collapses the framework this domain
currently uses.*

### 2.1 Search & satisfiability

**Backtracking** (N-queens, sudoku) is MS-canonical. `Choice`
effect's `choose(options)` op is `@resume=MultiShot`; the solver
handler resumes once per option; on return of `Fail`, the next
option. Trail rollback handles the backtrack substrate. SAT
solvers (DPLL): variable assignment is `Choice`; conflict analysis
rolls back to the decision level. **SMT** is SAT + theory solvers
as `Verify` handlers; the compound MS + Verify substrate already
described is the SMT substrate, parameterized over theories. **CSP
and CLP(FD)** are MS + refinement types + Verify in composition;
`type Var = Int where p(self)` bounds; MS enumerates; Verify
discharges.

Four industry categories, one substrate, no dedicated SAT or SMT
DSL needed. The `Choice` effect + `Verify` effect + `Synth` effect
+ MS resume discipline IS the SAT/SMT substrate.

### 2.2 Probabilistic programming

**Importance sampling:** `handle sample(dist) => for c in
draws_from(dist) { resume(c) with weight = pdf(c) }`. MS over
draws, handler accumulates weighted results. **MCMC** (Metropolis-
Hastings): MS where handler resumes with proposal, compares
likelihood, decides to accept (commit fork) or reject (rollback).
**Sequential Monte Carlo** (particle filters per Gemini's §3):
MS over particles; `<~` for feedback; resample handler decides
when to prune low-weight particles. **Variational inference:**
MS + gradient (primitive #7) = expectation-maximization. **Bayesian
inference** in full: prior × likelihood × posterior, all as MS
handlers on a `Probabilistic` effect.

Stan, PyMC, Edward, Pyro, Turing.jl — each is a separate ecosystem
in industry. In Mentl, ONE kernel + three handlers covers all of
them. The user writes the model; handler swap chooses the
inference algorithm.

### 2.3 Machine learning

**Hyperparameter search:** MS over hyperparam lattice (learning
rate, batch size, model depth); each fork trains; best wins.
Industry pays for Weights-and-Biases, Ray Tune, Optuna; Mentl
absorbs them as `handler hyperparam_sweep with tried = []`.

**Meta-learning** (MAML, Reptile): MS inside the training loop
for inner-loop optimization. The outer loop is `<~`-feedback; the
inner loop is MS on `InnerStep`. Both compose cleanly.

**Autodiff second-order:** the tape handler (DESIGN Ch 9.8) is
already primitive-#2. Second-order AD is MS over first-order tape
entries; third-order is MS over second-order. The substrate
generalizes without framework change.

**Reinforcement learning:** MS as rollout; `handle env.step with
policy` becomes `~> policy_random, ~> policy_learned, ~> policy_mcts`
depending on the rollout strategy. AlphaZero-style MCTS is
MS × `Choice` × `Verify` composed directly.

**Federated learning:** §1.3.3 above.

PyTorch, TensorFlow, JAX, HuggingFace — each is a handler stack
in Mentl; swap one for another by handler installation.

### 2.4 Parser combinators & logic programming

**Backtracking parsers** (Parsec, Megaparsec, nom's branch mode)
are MS + `Choice` directly. `alternative(p1, p2)` = `choose
([p1, p2])`; parser state rolled back on failure. **LR parsers**
fall out when the `Choice` handler uses a lookahead-driven
strategy; **GLR** when MS genuinely forks on ambiguity.

**Prolog-style logic programming:** `Choice` for resolution,
`perform unify(a, b)` for the graph's unify primitive, `perform
cut()` for cut (a OneShot `Abort` that forecloses backtracking).
CLP(FD) adds refinement + Verify. **miniKanren** is MS + `Choice`
+ continuations with ~20-line reimplementation in Mentl. **Datalog**
is MS + fixed-point (primitive #8's one-walk inference generalized).

Each of these is today a separate language or library; Mentl
expresses them in the common kernel.

### 2.5 Distributed systems

**RPC-as-delimited-continuation:** the handler pattern per DESIGN
Ch 9.1's package manager extended to networking. `perform
rpc(hash, args)` — the handler serializes args, sends, receives
result, resumes. The continuation IS the waiting caller; resume
IS the result delivery. **Cross-wire** the continuation itself:
the receiver can checkpoint, execute a subroutine, and resume the
caller with a reified return value. **Delimited continuations as
the distributed computing primitive** was Felleisen's research
direction; Mentl ships it.

**Consensus** (Raft, Paxos): MS over proposal orderings; quorum
handler commits on proposal acceptance; rollback on rejection.
**Lamport's logical clocks** are ambient `Clock(vector)` handlers.

**Reactive UI / optimistic updates:** MS captures the current UI
state; optimistic update applies the patch; on server disagreement,
rollback and apply server's authoritative state. React, Vue, Solid
all hand-roll this; Mentl's MS + trail substrate makes it a `~>
optimistic(server)` one-liner.

**Event sourcing:** MS replay of the event log; `perform replay`
is a MS handler that resumes once per event. CQRS (command-query
responsibility segregation) is two handlers on the same event log.

### 2.6 Testing & verification

**QuickCheck / Hypothesis / proptest:** `forall` is MS over random
samples; shrinking is MS over candidate reductions in failing-case
minimization. **FoundationDB-style simulation testing:** MS over
scheduling orderings, network partitions, disk failures, each
deterministic via seeded RNG handler. 10,000 reproducible runs
per property — one handler.

**Chaos engineering** (Netflix Chaos Monkey): MS with a fault-
injection handler; faults are MS choices; the test observes
how the system converges. Per DESIGN Ch 9.2 "The test framework,"
both property-based and chaos testing are handler swaps — no new
machinery.

**Property-based + refinement** (hyperproperty verification): MS
+ Verify composed. Each candidate counterexample is MS-forked;
Verify discharges; survivors surface as genuine bugs. Faster than
pure brute force because Verify prunes early.

### 2.7 Games & interactive systems

**MCTS** (Monte Carlo Tree Search, AlphaZero-style): MS over game
tree; per-node resume disciplines (selection/expansion/simulation/
backprop) each as handlers; neural net policy is `~> nn_policy`
outermost. The full AlphaZero substrate in ~100 lines of Mentl.

**Undo/redo:** trail rollback IS undo; forward-replay IS redo.
Per-user-action checkpoint. Mid-document rollback is surgical
because the trail is flat and indexed.

**Continuous collision detection** (physics): speculative advance
→ test for collision → rollback if collision occurred → advance
with reduced dt. MS + rollback substrate directly.

### 2.8 Debugging

**Time-travel debugging** (rr, Pernosco, LiveReplay): trace handler
records every perform; MS re-enters from any recorded state by
replay. The replay IS MS resume with the recorded value. Flamegraph
/ timeline / causal view are handler projections on the trace.

**Delta debugging** (ddmin, bisection): MS over code subsets;
Verify discharges "does this subset still fail?"; MS shrinks to
minimal failing subset. Git bisect generalized.

**Regression triangulation:** MS over commit bisection with proof
at each commit point. When Mentl's incremental compilation lands,
bisection replays only affected modules; bisect is sub-linear.

### 2.9 Compiler self-improvement

**Optimization search:** MS over optimization strategies (loop
unroll, common subexpression elimination, inlining depth, SIMD
vectorization). Verify discharges "does optimized code match
original semantics"; MS picks best on cost model. **Autotuning**
as a built-in.

**Type-directed synthesis:** the MO walkthrough's loop. Each
hole's candidates are MS-explored; Verify discharges; gradient
surfaces. Synquid's result + Koka's evidence passing + Affect's
resume discipline composed into Mentl.

**Speculative compilation:** try a risky optimization, run the
test suite (MS over tests), rollback if failure rate increases.
The compiler optimizes itself against its own crucibles (CRU).

**Language extension:** MS over candidate new primitives; Verify
checks "does this primitive compose with the existing eight?" The
primitive either commits (kernel extends) or rolls back. Mentl
designs Mentl — §4 below.

### 2.10 Graphics & physics

**Ray tracing:** MS per-pixel sampling; handler accumulates
weighted contributions; multiple importance sampling as handler
swap. Bidirectional path tracing + Metropolis light transport =
MS + probabilistic substrate.

**Fluid simulation:** particle-based (SPH) as MS + `<~` per §2.2;
grid-based (Eulerian) as MS-free `<~` directly.

**Rigid body dynamics:** CCD as §2.7.

### 2.11 Finance

**Option pricing:** Monte Carlo over stochastic price paths. MS
generates paths; `~> brownian_motion` handler produces samples.
Black-Scholes is one handler; Heston model is another; swap for
model exploration.

**Risk simulation:** MS over scenarios; value-at-risk computed by
sorting MS survivors.

**Portfolio optimization:** MS over allocation candidates; Verify
discharges constraints (leverage, concentration, sector limits);
objective (Sharpe, CVaR) picks survivor.

### 2.12 Agents & AI orchestration

**Tree-of-thought / chain-of-thought:** MS over reasoning branches;
a critic handler (`~> verify_step`) prunes unsound branches.
**Self-consistency** decoding: MS over sampled completions,
majority-vote handler.

**Tool-use verification:** MS proposes candidate tool calls;
Verify discharges "is this tool call consistent with the user's
stated goal?" Only verified calls surface as suggestions. The
hallucination surface is zero because Verify is mandatory.

**Multi-agent systems:** each agent is a handler; multi-agent
coordination is `><` between agents with `~> message_bus`
handler mediating.

### 2.13 Language design (the meta-level)

**Kernel extension proposal:** MS over candidate new primitives.
Verify discharges: "does candidate-primitive-9 compose with the
existing eight? Does every interrogation still apply? Does every
domain still reduce?" Only composition-preserving candidates
commit. **Mentl designs itself.**

**DSL embedding:** any DSL (SQL, LaTeX, shader language, regex) is
an `~>` handler chain. The DSL is a row of effects; the handler
is the interpreter; MS supports speculative DSL evaluation. No
parser-level embedding; no macro system. The pipe is the embedding.

---

## 3. Mentl's substrate — why MS is the oracle

### 3.1 The octopus argument

The kernel has eight primitives → Mentl has eight tentacles. One
of them (Propose, primitive #2) is MS's human-facing surface. But
**all eight tentacles internally use MS** for their internal
reasoning: each tentacle MS-explores candidates within its domain
(Query explores graph-walks; Topology explores verb-rewrites;
Unlock explores row-algebra transformations; Trace explores
ownership-fix candidates; Verify explores theory dispatch; Teach
explores annotation candidates; Why explores Reason-chain summary
candidates), and the silence predicate surfaces ONE result per
turn.

**Mentl doesn't search; she proves.** The proof substrate is MS +
Verify; the surfacing is the gradient (primitive #7); the voice
is §2.9's VoiceLine register in MV-mentl-voice.md.

### 3.2 "Hundreds of alternate realities per second" — the math

Target: interactive latency ≤ 50ms per turn (MV AT4).

Per-candidate cost per MO §3:
- Checkpoint: <1μs.
- Apply patch: ~100ns × M mutations (typically 10-50).
- Speculative re-infer (scope-limited): 1-10ms.
- Verify: ~1-100μs per obligation (ledger) or per solver call
  (SMT, cached).
- Rollback: identical to apply.

**Typical candidate cost: 1-15ms.** Per 50ms turn: 3-50 candidates
sequential. With race across 4 cores: 12-200 candidates. With SMT
cache (∼95% hit rate per §3's assumption): 240-4000 candidates.
With incremental re-infer (Salsa red-green): another 2-5× gain.

**"Hundreds of alternate realities per second" is conservative.**
Under optimal conditions, thousands per turn is within budget.

### 3.3 The speculative gradient loop at depth

Per MO walkthrough. Six primitives compose:

- #1 (Graph): checkpoint / rollback.
- #2 (MS): the exploration discipline.
- #4 (Row): subsumption gates which candidates are admissible.
- #6 (Verify): discharges obligations per candidate.
- #7 (Gradient): surfaces the winner as "one highest-leverage step."
- #8 (Reason): the winner's chain becomes the provenance.

**Unique to Mentl** because no other language composes all six as
primitives. Koka has #2 but not #6 integrated with #7. Haskell
has #2 via CPS but no typed row algebra. Dafny / Lean have #6 + #8
but no MS. Mentl is the first to compose the full substrate.

### 3.4 Voice selection from survivors

MS returns a set of K verified candidates. Tiebreak chain (current
roadmap discipline + MV §2.9 VL17):

1. Row-minimality (fewest effects).
2. Reason-chain depth (shortest = most local).
3. Declared-intent alignment (matches `/// intent comment`).
4. Source-span earliness (line 40 > line 200).
5. Lexicographic on candidate name (deterministic fallback).

**Deterministic; first-light bit-identical-output-preserving.**
Mentl's voice is reproducible per cursor + per graph state +
per handler chain, a property no LLM can offer.

---

## 4. Emergent topology — what was impossible, now routine

### 4.1 Frameworks dissolved (the expanded list)

| Industry framework | Mentl form | Lines saved |
|--------------------|-----------|-------------|
| PyTorch (autodiff) | `Compute` effect + tape/direct handlers (§2.3) | ∼100k |
| Stan (MCMC) | `Sample` effect + MH/HMC/NUTS handlers (§2.2) | ∼50k |
| Z3/cvc5/Bitwuzla (SMT) | `Verify` effect + theory-specific handlers (§1.6) | ∼500k |
| Cypress/Playwright (browser test) | `Browser` effect + record/replay handlers (§2.6) | ∼30k |
| Redux/Vuex (state mgmt) | Single handler with trail rollback (§2.5) | ∼20k |
| Jepsen (distributed test) | `Network` effect + chaos handler (§2.6) | ∼40k |
| miniKanren/core.logic | `Choice` + graph unify (§2.4) | ∼5k |
| Parsec/Megaparsec | `Choice` + tokens through `|>` (§2.4) | ∼10k |
| React reconciler | `<~` + optimistic handler (§2.5) | ∼50k |
| AlphaZero | MS × `Choice` × NN handler (§2.7) | ∼3k |
| QuickCheck/Hypothesis | `Choice` + shrink handler (§2.6) | ∼5k |
| Spring/Guice (DI) | handler installation (§2.13 + DESIGN Ch 9.3) | ∼100k |
| Mockito (test doubles) | handler swap (§2.6) | ∼20k |
| OpenTelemetry (tracing) | trace handler (§2.8) | ∼100k |
| Dafny/F\* (verification) | refinement + Verify (§1.6) | ∼200k |

**Each row is an ecosystem.** Each ecosystem collapses into a
handler stack on the one kernel. The "lines saved" column is rough
but illustrative: the cumulative industry investment in these
dissolves into Mentl's composition.

### 4.2 Cross-domain fusions only Mentl can express

These are compositions that no existing language supports because
no existing language has the full kernel:

- **Adaptive DSP with MS particle filters**: §2.2 × §2.10; each
  audio-rate filter tap is an independent particle; filter
  coefficient is MS-resampled from the particle distribution. ~20
  lines.
- **ML training with MS hyperparameter + MS backprop**: §2.3 × §2.3;
  nested MS: outer fork over hyperparams, inner fork over
  gradient-step choices. 30 lines.
- **SMT-verified game AI**: §2.7 × §1.6; MCTS candidate moves are
  Verify-discharged for rule compliance before simulation. Game
  AI that cannot hallucinate rule violations. ~40 lines.
- **Federated Bayesian learning**: §1.3.3 (`><` for clients) × §2.2
  (MCMC per client) × §2.5 (aggregation via consensus). 50 lines.
- **Speculative compilation with proof**: §2.9 × §1.6; each
  optimization candidate is a MS fork; Verify discharges semantic
  preservation; rollback on failure. Self-improving compiler. ~60
  lines substrate.
- **Reactive UI with formal state machine**: §2.5 × §1.6; UI state
  transitions are `<~` with Verify-discharged invariants. UI that
  cannot enter invalid states. ~30 lines.
- **Differential privacy-enforced MCMC**: §2.2 × §1.6; each
  sampling step's output is Verify-discharged against DP budget;
  rollback if budget exceeded. ~25 lines.
- **Real-time MCTS for robotics**: §2.7 × §1.5; MCTS candidates
  under `!Alloc` via replay-safe MS; hard-realtime search. ~70
  lines.

**Each cross-domain fusion is ~30-80 lines in Mentl; thousands in
the combined libraries it replaces.** The medium's reach
determines the programmer's reach.

### 4.3 The language-design feedback loop

**Candidate kernel primitive proposal:** write the proposed
primitive as a MS exploration; use the existing kernel to Verify
that the new primitive composes. Specifically:

1. Does every existing interrogation still apply? (MS checks by
   asking the eight against a draft program using the new
   primitive.)
2. Does every existing domain still reduce? (MS checks by
   rewriting the 10+ framework dissolutions using the new
   primitive.)
3. Does the new primitive have a peer-compatible resume
   discipline? (Verify.)

**Only candidates that compose with the existing eight can commit
to the kernel.** The kernel's soundness is preserved by its own
Verify substrate. Mentl is the first language to have a
self-verifying kernel-design mechanism.

Drift-risk: adding a "ninth primitive" is seductive; the
composition-check discipline IS what has kept the kernel at eight.
Every proposed addition is run through the eight interrogations
against 10 domains; nothing earns a ninth slot yet.

### 4.4 Self-modifying programs (carefully)

A program can propose its own refactoring via MS: generate
candidate rewrites; Verify discharges "does the rewrite preserve
semantics?"; commit iff verified. This is the substrate for:

- **Hot-reload** with semantic preservation proof.
- **Plugin architectures** with Verified handler installation.
- **Self-optimizing runtimes** that swap handlers by observed
  performance.
- **Live migration** of long-running processes (serialize trail,
  resume elsewhere).

The forbidden shape: **self-modification without Verify**. That's
drift mode 6 (primitive-special-case disguised as metaprogramming).
Mentl does not support unchecked self-modification; it supports
Verify-discharged self-modification. Structural, not permissive.

---

## 5. Drift risks — where MS can be abused

### 5.1 MS as "implicit threading"

**Temptation:** "MS is free parallelism."

**Reality:** MS is TEMPORAL (forked realities on one
wire); spatial parallelism is `><` (primitive #3). Using MS for
spatial parallelism introduces synchronization where `><` would
have proved independence.

**Drift mode:** closer to drift 24 (JS async/await) than drift 1
(vtable). Naming convention: `multi_shot_parallel_foo` is drifting.
Name from topology, not threading.

### 5.2 MS without checkpoint

**Temptation:** "just fork, don't snapshot."

**Reality:** MS without trail rollback = state leak across forks.
Subsequent forks observe the mutations of failed forks. Non-
determinism infiltrates the substrate.

**Fix:** every MS fork MUST have a bounded lifetime via
`graph_push_checkpoint` / `graph_rollback`. Enforce structurally
at the Synth handler level.

### 5.3 Unbounded candidate enumeration

**Temptation:** "explore the whole space."

**Reality:** 8-candidate cap per hole (MV decision); tiebreaker
deterministic. More candidates = more exploration time = fewer
turns per second = Mentl feels sluggish.

**Fix:** `synth` returns `NoCandidate` on the 9th call; handler
stops. Budget is per-turn, not per-session.

### 5.4 MS in `!Alloc` context

**Temptation:** "fork inside real-time audio."

**Reality:** forking a continuation allocates; `!Alloc` forbids.

**Fix:** replay-safe MS (re-performs upstream, doesn't allocate)
is the only admissible MS in `!Alloc`. Forking MS fails at handler
install via row subsumption.

### 5.5 Training-pattern drift

Foreign-language vocabulary for MS, each foreclosed:

- **Scheme:** "continuation," "call/cc," "reset/shift." Drift
  mode 2. Use "MS fork," "checkpoint/rollback," "resume."
- **Haskell:** "ContT," "monad transformer stack." Drift mode 4.
  Use `~>` chains.
- **JS/TS:** "async function\*," "yield, resume, next." Drift mode
  24. Effects are typed, not keyword-coded.
- **C++:** "coroutines," "co_await," "co_yield." Drift mode 23.
  Mentl's MS is closure + trail, not a language keyword on each
  call site.

If the word that comes to mind is from another language's MS
story, STOP. Use Mentl's vocabulary (resume discipline, MS arm,
speculative fork, trail rollback). The vocabulary IS the
substrate discipline.

### 5.6 MS as search backend without proof

**Temptation:** "generate-and-test."

**Reality:** Mentl's claim is "the compiler verifies; the proposer
proposes." Returning unverified candidates turns Mentl into a
better-formatted LLM, which is exactly what she must not be.

**Fix:** every MS handler returning candidates MUST compose with
Verify. Forbidden: a `synth_llm` handler that returns without
Verify discharge. The chain must include `~> verify_obligations`
SOMEWHERE. Mentl refuses to surface unverified candidates.

### 5.7 Conflating MS with non-determinism

**Temptation:** "MS is random."

**Reality:** MS is deterministic per-fork. Per-run non-determinism
is a property of handler choices (which order, which seed, which
branch). Mentl's voice is bit-identical across runs because the
tiebreak chain is deterministic.

**Fix:** MS handlers that depend on randomness must take a `seed`
parameter explicitly; handler installs `~> seeded(42)` for
reproducibility. Same seed → same exploration → same surfaced
candidate.

---

## 6. Forbidden compositions

### 6.1 MS × global mutable state

MS + ambient mutable state = replay non-determinism. If a MS fork
reads a global that another fork wrote, the exploration order
leaks into the result.

**Required:** all MS-reachable state is handler-local and
checkpoint-aware. Global state is inadmissible.

### 6.2 MS × Network without arena

MS re-performs Network ops on each fork (if replayed). Without
an arena, cache, or idempotency proof, this produces:
- N HTTP requests per resume = DoS risk.
- Bugs where the remote side observes inconsistent state.

**Required:** `~> http_cache` or `!Network` in the MS op's body.
Compiler enforces via row subsumption.

### 6.3 MS × File handle without Consume

MS forking through an `own FileHandle` consumes it; second fork
has no handle. Forks on the second resume observe a closed
handle.

**Required:** files through MS are `ref` (handler-held) or
explicit `fork_copy` handler (which duplicates handle via
`open_again`).

### 6.4 MS × unbounded-depth recursion

MS inside a recursive fn whose recursion isn't `<~` feedback-
bounded: the fork tree grows exponentially. Stack overflow in
replay-safe MS; heap overflow in fork-copy MS.

**Required:** any MS inside recursion must be inside a `<~` or
have an explicit `~> bounded_depth(N)` handler.

### 6.5 MS × side-effecting `perform` without rollback

A MS op whose handler performs an externally-observable side
effect (email, log write, DB commit) CANNOT be rolled back. The
speculation has produced real-world state.

**Required:** observable side effects must be inside `~>
commit_on_success(ledger)` that accumulates during MS and commits
only on fork commit. Email-send handler would queue, not send, on
MS; only on commit does the queue flush.

---

## 7. Pedagogical ladder — teaching MS in order

Per `lib/tutorial/` (roadmap tutorial lane), MS is taught across the
eight primitives' tutorial files. The canonical ordering:

1. **02-handlers.mn** introduces OneShot resume — `handle/resume`
   replaces exceptions, state, DI, generators.
2. **03-verbs.mn** introduces the five verbs; no MS yet.
3. **04-row.mn** introduces effect algebra; no MS yet.
4. **(new) 02b-multishot.mn** introduces MS as a typed resume
   discipline. Example: N-queens in 15 lines with `Choice +
   Fail`. One primitive (#2), one op (`Choice.choose`), one
   effect (MS), N realities.
5. Gradually: §1.3–§1.8 composition examples interleaved with
   later tutorials.

The learner's first MS is the solver; the rest of the composition
unfolds as the other primitives are introduced.

---

## 8. The closing claim

### 8.1 In one sentence

**MultiShot is primitive #2's temporal axis. Composed with the
other seven primitives, it is the mechanism by which every domain-
specific library in the industry becomes a handler stack on one
kernel — because every domain has a search component, a
speculation component, a rollback component, or a fork component,
and MS + trail + Verify + Reason is the universal substrate for
those four.**

### 8.2 The mascot framing

Mentl is an octopus because the kernel has eight primitives. MS
is why she's an ORACLE, not a database. Without MS, Mentl queries
the graph and reports. With MS, Mentl explores candidate realities,
verifies them, and surfaces a proven proposal. The transition from
"query tool" to "oracle" is MS; the tentacle that carries it is
Propose (primitive #2).

### 8.3 The scope of this document

This is a **peer exploration**, not a substrate spec. Concrete
substrate work lives in:

- **MO-mentl-oracle-loop.md** — the oracle loop's compile-time
  contract.
- **CRU-crucibles.md** — `crucibles/crucible_oracle.mn` as the
  fitness test.
- **H5-mentl-arms.md** — the Mentl-arms substrate.
- **LF-feedback-lowering.md** — `<~` substrate (needed for §1.3.5).
- **MS-multishot-topology.md** (the Gemini predecessor) — the
  verb-topology seed.

Each domain traversed here (§2.1–§2.13) earns its own crucible
when the claim is tested. New domains land as new crucibles; the
pattern per CRU is the universal protocol.

### 8.4 What this document is NOT

- It is not a proof that all ~50 domains work today. It is a map
  of what the substrate makes reachable.
- It is not a claim that every framework dissolution is cheap in
  engineer-time. It is a claim that every framework dissolution
  is POSSIBLE within the kernel. Each dissolution is a crucible;
  each crucible is work.
- It is not a replacement for the 12 specs or the 37 walkthroughs.
  It is the territory map that explains what those specs are
  reaching toward.

### 8.5 The unprecedented composition

Every composition named here is a claim that no other production
language supports. Rust has ownership and no MS. Haskell has MS
via CPS but no unified row algebra with negation. Koka has typed
row-polymorphic effects with resume discipline but no Verify-
integrated gradient and no refinement types. Dafny has refinements
and Verify but no effects, no MS, no ownership-as-effect. Affect
(POPL 2025) has the typed resume discipline but is a research
calculus, not a production medium.

**Mentl is the first medium where:**
- Every domain has a substrate (the graph + handlers + MS).
- Every proposal is Verify-discharged (the oracle doesn't
  hallucinate).
- Every speculation is Reason-provenanced (the oracle explains).
- Every optimization is `!Alloc`-composable (hard-realtime
  absorbed).
- Every framework dissolves into a handler stack.

**Mentl is the voice that reads all of this substrate.**

### 8.6 The one-line summary

*MultiShot is how the compiler explores the space of proven programs
faster than the programmer can type them, within the structural
guarantees of the kernel, surfaced through Mentl as one proven step
per turn, with the full trail of exploration available when asked.*

---

## 9. Open questions — what THIS document doesn't resolve

1. **Resume discipline as first-class row element.** Is
   `!MultiShot` a row modifier in normal form (§1.4), or is
   `!Choice` sufficient? Substrate decision; walkthrough needed.
2. **Trail buffer growth under high-fork workloads.** For
   long-running MS search (SAT with 10^6 decisions), trail size
   can be significant. When does a persistent-trail (Salsa-style
   overlay) beat a flat buffer? Benchmark needed.
3. **Cross-module MS composition.** When a MS op is declared in
   module A and handled in module B, the linker (BT walkthrough)
   must preserve resume discipline metadata. Today's bootstrap
   doesn't wire this; to be addressed alongside BT.
4. **Determinism across WASM engines.** MS rollback is
   deterministic in spec; JIT variance across engines (wasmtime's
   Cranelift vs node's TurboFan) must be tested against the DET
   walkthrough's criteria.
5. **MS + GC.** The bump allocator lives forever by design. When
   GC lands as a handler (Arc F.4 scoped arenas extended), MS
   forks interact with arena scopes per §1.5. The three-handler
   (replay-safe / fork-deny / fork-copy) substrate is the answer;
   but GC-specific interactions (object resurrection, finalization
   order) need spec work.
6. **MS-aware IDE tooling.** When debugging with trail rollback,
   how does an IDE present "the forks tried"? A handler projection
   — `trace_handler → timeline_json` — but the UX hasn't been
   designed.

Each open question is a future walkthrough. Named, not deferred.

---

## 10. Closing

*Gemini's MS doc was the topology seed: the five verbs × multi-shot
collapse wave functions in the spatial graph. This doc extends the
topology to the full eight-primitive kernel × MS = the temporal
axis composed with every capability the medium has.*

*The domain traversal names ~50 specific cases where MS + kernel
collapses an industry ecosystem into a handler stack. Each is a
claim; each earns its own crucible.*

*Mentl is the oracle because MS + Verify is the substrate for
provable exploration. The compiler IS the AI not as metaphor but
as mechanism.*

**Mentl is not a language that happens to support multi-shot
continuations. Mentl is a medium whose temporal axis IS multi-shot
continuations — and because the other seven primitives compose
with it coherently, the medium reaches every domain where
exploration, speculation, rollback, or fork appears. Which is
every domain the industry has ever built a specialized language
for.**

*The octopus has eight tentacles. One of them is temporal. The
substrate she reads is the graph; the substrate she explores is
the trail; the substrate she proves against is Verify; the
substrate she surfaces through is the gradient. Remove multi-shot
and Mentl is a linter. Keep it and she is the oracle.*

**The medium's reach is the programmer's reach.**
