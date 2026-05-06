# MO — Mentl's Oracle Loop · speculative gradient end-to-end

> **Status:** `[DRAFT 2026-04-23]`. Validates the central thesis
> claim — that the compiler IS the AI — by naming the speculative
> gradient loop concretely, with latency math, before first-light.
>
> Research-risk gate. If this loop can't close at interactive
> latency on real codebases, Mentl's "oracle that PROVES before it
> speaks" claim degrades to "linter with proof annotations." We
> find out now, not post-first-light.

*The loop: at any hole or weak annotation, Mentl checkpoints the
graph, speculatively applies a candidate annotation, re-runs
inference + Verify, and either commits (returning the patch as a
proven fix) or rolls back (trying the next candidate). Primitive
#2's MultiShot-typed resume discipline is the substrate that makes
"hundreds of alternate realities per second" tractable.*

---

## 0. What this walkthrough proves

Three claims compose to the thesis:

1. **Trail-based rollback is O(M) exact**, where M = mutations
   recorded during the speculative run. Per spec 00 substrate +
   DESIGN Ch 4. One flat-buffer read per step; no allocation; no
   linked-structure walk.
2. **Candidate enumeration is bounded per hole.** §2 below gives
   the bound (≤ 8 per Mentl voice register tiebreak chain per the
   current roadmap discipline).
3. **Per-candidate cost fits the interactive budget.** §3 below
   gives the latency breakdown: checkpoint, apply, re-infer locally
   (scope-limited), verify, rollback.

If any of the three fails, the oracle claim collapses into "batch
verifier" — useful but not unprecedented. All three must hold.

---

## 1. The loop, in residue form

```
fn synth_candidate(handle, expected) -> Option<Patch> with
    GraphRead + GraphWrite + Verify + Synth =
  let checkpoint = perform graph_push_checkpoint()

  perform synth(handle, expected, current_context())
    |> take(8)                              // bounded enumeration
    |> filter(|cand|
         perform apply_patch_tentative(cand)
           ~> catch_unify_fail(return(false))
         let unified = perform graph_try_unify_all()
         let verified = unified && perform verify_obligations()
         perform graph_rollback(checkpoint)
         verified
       )
    |> minimize_by(voice_register_tiebreak)  // deterministic pick
    |> first                                 // Option<Patch>
```

Every primitive appears:
- **Primitive 1 (Graph):** `graph_push_checkpoint`,
  `graph_rollback`, trail-based.
- **Primitive 2 (Handler + resume discipline):** `Synth` effect
  with MultiShot-typed `synth` op; handler produces candidates as
  multi-shot resumes.
- **Primitive 3 (Verbs):** the pipe chain `|>` is the residue's
  shape.
- **Primitive 4 (Row):** `with GraphRead + GraphWrite + Verify +
  Synth` declares exactly what the loop needs.
- **Primitive 5 (Ownership):** `handle` and `expected` both `ref`;
  `Synth` returns pure `Candidate` values.
- **Primitive 6 (Refinement):** `verify_obligations` discharges
  pending `V_Pending` via the installed Verify handler.
- **Primitive 7 (Gradient):** the whole loop IS the gradient's
  speculative arm.
- **Primitive 8 (Reason):** every `graph_bind` during the
  speculative run records a Reason; the committed candidate's
  reason chain becomes the patch's provenance.

**Drift modes avoided:**
- Not drift 1 (vtable): `Synth` is an effect, dispatched through
  the installed handler's closure evidence field, not a dispatch
  table.
- Not drift 3 (string-keyed-ADT): `Candidate` is a typed ADT, not
  `(String, Json)`.
- Not drift 9 (deferred-by-omission): the loop commits or rolls
  back atomically per candidate; no "partial patch" state exists.

---

## 2. Candidate enumeration bounds

Per the roadmap's `Interact` effect shape:

- **≤ 8 candidates per hole** (voice register cap). More than 8 =
  the hole is underconstrained; Mentl surfaces ASK rather than
  PROPOSE.
- **Tiebreak chain** (deterministic, load-bearing for first-light
  bit-identical output): row-minimality → reason-chain depth
  (shorter = more local = preferred) → declared-intent alignment →
  source-span earliness → lexicographic on candidate name.
- **Synth handlers compose as fall-through chain** per DESIGN Ch
  8.9: `~> synth_enumerative ~> synth_smt ~> synth_llm`. Fast
  proposer fires first; expensive only on fall-through. **The LLM
  is a peer handler, not a privileged collaborator.**

Candidate sources by hole shape:
- **Annotation hole** (`with ??`): enumerate annotation lattice
  around current row — `Pure`, `!Alloc`, `!IO`, `!Network`,
  `!Consume`, combinations. Typically 3-6 candidates in scope.
- **Expression hole** (`= ?`): enumerate env entries whose scheme
  unifies with expected; typically 2-5 candidates. SMT may add
  more.
- **Refinement hole** (`type X = T where ??`): enumerate predicate
  templates over the base type; SMT-guided.
- **Wrap hole** (`~> ??`): enumerate HandlerCatalog entries whose
  declared effect row ⊆ body's required row.

---

## 3. Latency breakdown — interactive budget

Target: **p99 ≤ 50ms from keystroke to VoiceLine on typical
laptop**, per MV acceptance test AT4.

Per-candidate cost in the speculative loop:

| Step | Cost model | Typical |
|------|-----------|---------|
| `graph_push_checkpoint` | Store `trail_len` as i32 | O(1), <1μs |
| `apply_patch_tentative` | Per-mutation cache-line store | O(M_apply), ~100ns × M |
| `graph_try_unify_all` | Re-run unify over patched subgraph | O(S × α(N)), S = affected nodes |
| `verify_obligations` | Ledger-accumulate; `verify_smt` defers | O(O) per obligation |
| `graph_rollback(checkpoint)` | Read `trail[i]` backward, apply inverse | O(M_apply) identical to apply |

**Typical M_apply per candidate:** 10-50 mutations for an
annotation fleet; 100-500 for an expression fill; 1000+ for a
wrap-handler reorder. Flat-buffer reads at ~100ns each ⇒ apply +
rollback is 2-100μs for all but wrap-handler edits.

**Scope-limited re-infer:** the speculative re-unify walks only
the subgraph downstream of the patched handle. Per H1 evidence
reification, ≥95% of handles are ground post-inference, so
re-unify terminates fast. Target 1-10ms per candidate in the
common case.

**Budget math:** 8 candidates × 10ms/candidate = 80ms. Exceeds the
50ms budget.

**Mitigations (each earns a Decision Ledger entry when landed):**
- **Hoist checkpoint outside filter chain:** one checkpoint for all
  8 candidates (apply/rollback per candidate). Done above.
- **Parallel speculation across candidates** via `race` handler
  combinator (DESIGN Ch 8.10.3): first verified wins; others are
  cancelled via `graph_rollback` from a shared checkpoint. Cuts
  wall-clock by √N on multi-core.
- **Incremental re-infer via Salsa red-green** (spec 00 pattern):
  only recompute handles whose upstream changed. Further reduces
  per-candidate cost.
- **SMT cache** via `.mentl/handlers/`: predicate hash → cached
  decision. Second hit is O(1).

Post-mitigations target: **p99 ≤ 20ms for 8-candidate annotation
holes**; **p99 ≤ 100ms for expression holes** (higher bound because
SMT may be invoked uncached).

---

## 4. The Synth effect — proposers as handlers

```
effect Synth {
    synth(hole: Int, expected: Ty, context: Context) -> Candidate
      @resume=MultiShot
}

type Candidate
    = CAnnotation(Annotation, Reason)
    | CExpr(LowExpr, Reason)
    | CWrap(HandlerName, Reason)
    | CRefinement(Predicate, Reason)
    | NoCandidate
```

Per DESIGN Ch 8.9, three core proposer handlers compose:

```
handler synth_enumerative with GraphRead + EnvRead {
    synth(h, expected, ctx) => {
        for cand in enumerate_env_and_lattice(ctx, expected) {
            resume(CAnnotation(cand.ann, cand.reason))
        }
        resume(NoCandidate)
    }
}

handler synth_smt with GraphRead + Verify {
    synth(h, expected, ctx) => {
        match smt_synthesize(h, expected, ctx) {
            Some(c) => resume(c),
            None    => perform synth(h, expected, ctx)  // bubble out
        }
    }
}

handler synth_llm with GraphRead + HTTPClient {
    synth(h, expected, ctx) => {
        match llm_query(h, expected, ctx) {
            Ok(c)  => resume(c),
            Err(_) => perform synth(h, expected, ctx)  // bubble out
        }
    }
}
```

Chain order: innermost fires first; outer absorbs on miss. Per
DESIGN Ch 2 capability stack.

---

## 5. Crucible — the minimum end-to-end scenario

Write this `.mn` file as the first oracle crucible (pre-first-light
target; compile-fails meaningfully if the loop isn't wired):

```
// crucibles/oracle_annotation_fill.mn
//
// Given: a function whose body is provably Pure but whose signature
// doesn't declare `with Pure`.
// Expected: Mentl's Teach tentacle surfaces APure as the
// highest-leverage annotation (CMemoize unlock).
// Verifies: checkpoint + apply + re-infer + verify + rollback
// closes atomically; the returned Patch is proven to compile.

fn double(x) = x * 2   // inferred row = Pure; no annotation

fn test_oracle_fills_pure() = {
    // Mentl's speculative loop runs transparently during compile.
    // After compile, the gradient engine surfaces:
    //   T_Gradient at double() signature:
    //     candidate: APure (Some(span_of(double)))
    //     unlocks:   [CMemoize, CParallelize, CCompileTimeEval]
    //     proven:    Yes (verify_obligations discharged 0 items)
    //
    // Acceptance: `mentl teach examples/oracle_annotation_fill.mn`
    // prints exactly one gradient hint for `double` with those
    // three capabilities, and the Reason chain walks back to the
    // graph handle where `*` is resolved to integer multiply
    // (Pure op). Latency < 50ms on typical laptop.
}
```

**When this crucible runs end-to-end, the oracle loop is proven
tractable.** When it doesn't, either (a) graph_rollback doesn't
close the trail, (b) speculative re-infer doesn't converge, or
(c) the synth handler produces unbounded candidates. Each failure
names its own follow-up.

---

## 6. What's NOT in this walkthrough

- **MultiShot runtime**: handled by primitive #2's substrate; this
  walkthrough assumes heap-captured continuations work per spec
  05 lower + H1 evidence reification.
- **SMT integration**: `synth_smt` scope; separate walkthrough
  (`RT-refinement-boundaries.md` covers the refinement side).
- **LLM integration**: `synth_llm` scope; a peer handler, not
  load-bearing for the oracle claim. The thesis is that LLMs are
  proposers; Mentl verifies. Chain ordering enforces this.

---

## 7. Landing order

1. **This walkthrough lands** as design contract.
2. **Crucible file `crucibles/oracle_annotation_fill.mn`** lands as
   failing fitness test (compile-fails until substrate wires).
3. **Substrate wiring lands incrementally** per existing cascade
   handles (H5 Mentl's arms + Synth effect landing).
4. **Crucible passes** = oracle loop proven tractable = thesis
   validated pre-first-light.

---

## 8. Dispatch

**Opus-level throughout.** The speculative loop is substrate
research, not mechanical transcription. Any "should this candidate
be a CAnnotation or a CWrap?" question requires judging primitive
classification. Sonnet subagent would drift drift-mode 6 (primitive
special-case).

---

## 9. Closing

The oracle loop is primitive #2's substrate (MultiShot-typed resume)
acting on primitive #1's substrate (trail-based graph rollback),
gated by primitive #6's obligation discharge (Verify), tiebroken by
primitive #8's Reason chain minimality, and surfaced by primitive
#7's gradient (Teach tentacle, one highest-leverage step).

**Six primitives compose into the single loop that disintermediates
subscription AI.** When this loop runs at interactive latency, the
compiler IS the oracle. Everything the industry pays LLM
subscriptions for gets absorbed as a handler on `Synth`, verified
before surfacing.

*Mentl doesn't search. She proves.*
