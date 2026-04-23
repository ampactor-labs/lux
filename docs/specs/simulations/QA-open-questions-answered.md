# QA — Open Questions Answered · decisions ahead of substrate

> **Status:** `[DECISIONS 2026-04-23]`. Every open question surfaced
> in the 2026-04-23 planning round (MS2 §9, MSR §6 risks, MO §6, TH
> §12, Hβ §10, BT §4, MV §8, HC closure, SR §5, and all phase items
> in `alright-let-s-put-together-silly-nova.md`) resolved with a
> proposed answer + reasoning + drift-mode check. Morgan-specific
> preferences surfaced as **DECISION REQUIRED** rather than answered.
>
> *Answering these ahead of substrate means the implementer reads
> prescribed tokens, not design questions. Every "I need to decide
> X" that would have fired during B.2 H7 is settled here.*

---

## 0. Ground rule

Every answer below cites:
- **Primitive** (which of the eight it composes from).
- **Drift check** (what drift mode was avoided by this answer).
- **Reversibility** (can this be revised at a later walkthrough without cascade consequences? Or is it load-bearing for downstream work?).

When the answer is Morgan-specific, it's flagged **DECISION REQUIRED** with options.

---

## Phase A — Bootstrap linker

### Q-A.1.1: `<module>__<symbol>` hash-collision suffix needed?

**Answer:** No suffix. Single-namespace rename via `<module>__<symbol>` is collision-free by construction (module names are unique source paths; symbols are unique per module).

**Reasoning:**
- Primitive #1 (graph): the env already stores unique qualified names; the linker transcribes.
- Drift check: drift 8 (string-keyed-when-structured) avoided — we don't need a hash suffix because the structured form (module path + symbol) IS the unique key.

**If collision ever arises** (two modules ship the same path — edge case in federated package registry, F.5 post-first-light): emit `E_CrossModuleSymbolCollision` diagnostic; user resolves via import-time alias.

**Reversibility:** fully reversible; if a collision happens, add a hash suffix then.

### Q-A.1.2: Per-module handler-chain composition at link time?

**Answer:** Linker is symbol-resolution only. Handler-chain composition happens at infer/lower time, before the linker runs.

**Reasoning:**
- Primitive #2 (handlers): HC walkthrough established "transform emits; materialize captures; `~>` composes" — composition IS lowered output, not linker concern.
- Drift check: drift 1 (vtable) avoided — no "dispatch table" assembled by the linker; handlers remain closure-based.

**Reversibility:** load-bearing. Changing this would restructure BT + HC substrate.

---

## Phase B.1 — AL unification

### Q-B.1.1 / SR-Q1: Drift-audit pattern for duplicate effect declarations?

**Answer:** Yes, but as a NEW separate script `tools/effect-registry-audit.sh` — cross-file analysis doesn't fit drift-audit's per-file scan model.

**Reasoning:**
- drift-audit is file-local; effect-name uniqueness is a repo-global invariant.
- Post-first-light, this dissolves into `mentl audit effects` handler projection (F.3).

**Scope (E.2 addendum):**
```bash
# tools/effect-registry-audit.sh
# Collects every `effect X {` declaration across src/*.nx + lib/**/*.nx
# Flags any effect name appearing in 2+ files.
# Exits 0 clean; exits 1 with citation on duplicate.
```

**Reversibility:** fully reversible; audit is additive.

### DP-B.1: AL resolution — option α vs β?

**Answer:** **α — rename DSP version to `BufferAlloc`.**

**Reasoning:**
- Option α preserves domain-specific semantics. DSP "buffer allocation" and substrate "byte allocation" are genuinely distinct operations at different abstraction layers.
- Option β would collapse them into one effect with two ops — reduces clarity, adds unrelated op to substrate.
- Drift check: option β risks drift 8 (over-collapse of semantically distinct things into one structured bucket).

**Implications:**
- `lib/dsp/signal.nx:18` declaration changes: `effect BufferAlloc { alloc_buffer(...) }`.
- Every caller in `lib/dsp/**/*.nx` updates.
- AL-alloc-unification.md walkthrough formalizes the rename.

**Reversibility:** small blast radius; reversible via second rename.

---

## Phase B.2 — H7 MS runtime

### Q-B.2.1 / MS2-Q1: `!MultiShot` as first-class row modifier?

**Answer:** DEFER. Keep `!Choice` (effect-level negation) sufficient until exercised need surfaces.

**Reasoning:**
- Primitive #4 (row algebra): `!<EffectName>` negation is already primitive-supported. Adding `!MultiShot` as a row-level modifier requires extending row algebra — significant substrate work.
- The concrete claim `"this function cannot be forked"` is today expressed as `!Choice + !<other_ms_effect>` (enumerating the MS effects in scope).
- If H7 walkthrough surfaces a case where enumeration is brittle (e.g., many MS effects in scope), land `!MultiShot` as a peer row-level modifier in a separate walkthrough.

**Drift check:** drift 6 (primitive-type-special-case) avoided — not creating a special-case row element when existing negation suffices.

**Reversibility:** fully reversible; row algebra can be extended later.

### Q-B.2.2 / MS2-Q4: Determinism across WASM engines?

**Answer:** Cross-check via `wasm-interp` per DET walkthrough. Add to `tools/determinism-gate.sh` as a regression test.

**Reasoning:**
- `wasm-interp` is the stack-based reference interpreter — no JIT, no optimization, no non-determinism. Ground truth.
- DET §cross-check-harness already specifies this pattern; B.2 lands the concrete test.

**Scope (at B.2 commit):**
```bash
# tools/determinism-gate.sh extension
cat <file.nx> | wasmtime run bootstrap/inka.wasm > /tmp/out-jit.wat
cat <file.nx> | wasm-interp --run-all-exports bootstrap/inka.wasm > /tmp/out-interp.wat
diff /tmp/out-jit.wat /tmp/out-interp.wat   # empty = deterministic
```

**Reversibility:** fully reversible; determinism is test-observable.

### Q-B.2.3: Cache schema versioning v3 → v4?

**Answer:** Bump `cache_compiler_version` to v4 at B.2 commit. Existing cache.nx invalidation logic handles the migration automatically.

**Reasoning:**
- cache.nx line 45: version enum bumps on binary format change. `LMakeContinuation` addition to `LowExpr` IS a binary change.
- driver.nx's `driver_check_module` already checks cache_compiler_version; stale .kai files get discarded on mismatch.

**Drift check:** drift 9 (deferred-by-omission) avoided — we don't leave stale v3 .kai files around "to migrate later."

**Reversibility:** N/A (one-way forward; bump = migrate).

---

## Phase B.3 — Choice effect

### Q-B.3.1: `Choice(T)` parameterized or bare?

**Answer:** Bare variant. `effect Choice { choose(options: List<A>) -> A @resume=MultiShot }` — `A` is a generic type parameter, NOT an effect parameter.

**Reasoning:**
- Primitive #4 (row algebra) + H3.1 (parameterized effects): parameterized effects distinguish instances at the row level (e.g., `Sample(44100)` vs `Sample(48000)` are different effects in the row).
- `Choice` doesn't need instance distinction. One `Choice` effect; each `choose` call's type parameter `A` is inferred from context.

**Drift check:** drift 6 (primitive-type-special-case) avoided — we don't parameterize effects when generic op-types suffice.

**Reversibility:** fully reversible if a Choice instance becomes load-bearing (e.g., `Choice(strategy)`).

### Q-B.3.2: `choose([])` on empty list?

**Answer:** Runtime Abort. Handler decides semantics; `backtrack` treats as dead-end, `pick_first` performs Abort.

**Reasoning:**
- Primitive #6 (refinement): compile-time detection via `List.nonempty` refinement requires refinement propagation across call sites — expensive for a minor case.
- Primitive #2 (handlers): the handler's arms naturally handle the empty case without substrate work.
- User can opt-in to compile-time safety via explicit refinement at call site: `fn my_choose(ref opts: NonEmptyList<A>) = perform choose(opts)`.

**Drift check:** drift 9 (deferred-by-omission) avoided — the runtime semantic is defined; refinement opt-in is named.

**Reversibility:** fully reversible; refinement-substrate can be added when exercised.

---

## Phase B.4 — race combinator

### Q-B.4.1: `race` semantics — wall-clock or tiebreak chain?

**Answer:** **Tiebreak chain always.** `race` enumerates all verified survivors (up to timeout), then applies the canonical tiebreak chain (per MV decision ledger), then commits one. Wall-clock ordering is non-deterministic; forbidden as an outcome selector.

**Reasoning:**
- Primitive #8 (Reason / determinism): first-light bit-identical self-compile requires deterministic candidate selection at every site.
- Wall-clock "winner" is schedule-dependent; violates primitive #1's graph-determinism claim at render time.
- The PARALLELISM is wall-clock (all forks run in parallel); the CHOICE is deterministic (tiebreak over survivors).

**Drift check:** drift 9 (deferred-by-omission) avoided — the semantic is settled up front.

**Tiebreak chain** (per PLAN.md Decisions Ledger 2026-04-21):
1. Row-minimality (fewest effects).
2. Reason-chain depth (shortest = most local).
3. Declared-intent alignment.
4. Source-span earliness.
5. Lexicographic on candidate name.

**Reversibility:** load-bearing for first-light determinism. Changing this would break L1.

### Q-B.4.2: Rollback of losers — shared checkpoint at race install?

**Answer:** Yes. Single `graph_push_checkpoint()` at race install; all non-winning forks roll back to this checkpoint at race close; winner's mutations persist.

**Reasoning:**
- Primitive #1 (graph) + primitive #2 (handlers): trail-based rollback is O(M) per DESIGN Ch 4; one checkpoint for N forks is O(N × M) total.
- Matches MO §3 speculative loop pattern — checkpoint-hoisting is named mitigation.

**Drift check:** drift 7 (parallel arrays) avoided — state is one trail shared across forks, not per-fork parallel structures.

**Reversibility:** load-bearing for O(N × M) rollback cost.

---

## Phase B.5 — Arena-MS

### Q-B.5.1 / MS2-Q5: MS + GC finalization / resurrection?

**Answer:** DEFER to Arc F.4 (GC as handler). Currently bump-allocator-only; GC-specific semantics surface at F.4 walkthrough.

**Reasoning:**
- The three D.1 handlers are semantically well-defined for bump allocators today.
- GC introduces finalization order + object resurrection concerns that compose with each D.1 handler differently. Specification belongs with the GC handler landing.

**Drift check:** drift 9 (deferred-by-omission) — NOT deferred-by-omission here because the gap is explicitly named and scoped to F.4. We don't land incomplete GC + MS semantics; we wait for GC to have its own walkthrough.

**Reversibility:** fully reversible.

### Q-B.5.2: Fork-copy allocator-choice?

**Answer:** Auto parent arena by default; user override via `fork_copy(target_arena)` parameter.

**Reasoning:**
- Primitive #5 (ownership): the ambient allocator at install time IS the natural parent-arena target; ownership-as-effect tracks this.
- User override supports advanced cases (explicit cross-arena copy) without complicating the default.

**Drift check:** drift 7 (parallel arrays) avoided — target_arena is a handler parameter, not a per-fork array.

**Reversibility:** fully reversible.

---

## Phase B.6 — verify_smt

### Q-B.6.1: Theory classification list?

**Answer:** Five-variant ADT — `TLinearArith | TBitvector | TArray | TUF | TNonlinear`. Sub-theory handling inside each bridge handler.

**Reasoning:**
- Covers residual-theory dispatch per DESIGN 9.7 (Z3 for nonlinear, cvc5 for finite-set/bag/map, Bitwuzla for bitvectors).
- Sub-classes (e.g., `TLinearRealArith` vs `TLinearIntArith`) are the theory-bridge handler's concern, not the classifier's. Classifier routes to the right bridge; bridge dispatches internally.

**Drift check:** drift 8 (string-keyed) avoided — typed ADT; drift 6 (primitive special-case) avoided — five variants, not "arith + others."

**Reversibility:** fully reversible; new theory-class variants can be added (growing the ADT is structurally safe per primitive #4 algebra).

### Q-B.6.2: SMT cache key?

**Answer:** Triple-key `(fnv1a(predicate_ast), theory_class, fnv1a(env_context_hash))`.

**Reasoning:**
- Predicate AST hash captures predicate identity (alpha-equivalent predicates canonicalize to same hash).
- Theory class disambiguates cross-theory cache entries (same predicate routed to different solvers could have different cached results under different bridges — defensive).
- Env context hash captures the subgraph the predicate refers to (a predicate about `x` where `x` is Int should not hit a cache entry where `x` was Float).

**Drift check:** drift 8 avoided — structured triple, not concatenated string.

**Reversibility:** fully reversible; cache format bumps version on key-shape change.

### Q-B.6.3 / DP-B.6: SMT chain shape?

**Answer:** **Nested `~>` fall-through.** `~> smt_linear_arith ~> smt_bitvector ~> smt_nonlinear` — innermost fires first, bubbles on `NoDecision`.

**Reasoning:**
- Matches existing capability-stack semantics (DESIGN Ch 2 + Ch 9.1 federation pattern).
- Predictable: user reads the chain top-to-bottom (inner-to-outer in `~>` order); solvers run in declared order.
- `race` stays available when user wants genuine parallel across cores — for the default install, nested is deterministic + cache-friendly.

**Drift check:** drift 4 (monad transformer) avoided — `~>` chain, not nested `handle(handle(...))`.

**Reversibility:** fully reversible; user can compose `race` at will.

---

## Phase B.7 — threading

### Q-B.7.1: Browser SharedArrayBuffer — runtime or compile-time?

**Answer:** Runtime detection. `num_cores()` returns 1 if SharedArrayBuffer unavailable; `parallel_compose` degrades to sequential on miss.

**Reasoning:**
- Primitive #2 (handler): the handler IS the runtime-feature abstraction; compile-time gating violates the "handler decides" discipline.
- Cross-platform substrate: same source compiles; runtime feature-detects.

**Drift check:** drift 9 (deferred-by-omission) avoided — graceful degradation is specified semantics, not "deal with it later."

**Reversibility:** fully reversible.

### Q-B.7.2: Thread pool strategy?

**Answer:** OS threads direct for v1. Thread pool is a peer handler (`pool_compose`) installed post-first-light.

**Reasoning:**
- v1 scope: prove `><` × handler-dispatch across OS threads; pool is a performance optimization.
- Pool as handler: `~> pool_compose(workers = 4)` replaces `~> parallel_compose` at install.

**Drift check:** drift 9 avoided — pool is named as peer, not deferred-inside-main.

**Reversibility:** fully reversible; pool_compose ships when pooling is exercised.

### Q-B.7.3: Deterministic `><` output order?

**Answer:** **ALWAYS.** `parallel_compose` preserves branch order in output tuple regardless of completion timing.

**Reasoning:**
- Primitive #3 (verbs): `><` produces tuples; tuples have fixed element order. Order must reflect source, not schedule.
- Non-negotiable for first-light bit-identical output.

**Implementation:** each thread writes into a pre-indexed slot (index = branch position); await phase reads slots in order.

**Drift check:** drift 8 avoided — index is structural (tuple position), not string-keyed.

**Reversibility:** load-bearing; test in `crucible_parallel`.

---

## Phase B.8 — IC.3 overlays

### Q-B.8.1: Overlay lookup order?

**Answer:** Module's own overlay first, then imports in declaration order. Matches existing env_lookup scope-walk semantics.

**Reasoning:**
- Primitive #1 (env): existing env_handler walks scopes inner-to-outer; overlays extend this pattern.
- NS-naming dot-access: qualified names (`module.fn`) check overlay directly; unqualified walks the chain.

**Drift check:** drift 2 (Scheme env frame) avoided — we don't reintroduce parent-pointer walks; overlay is flat-array per module (per spec 00).

**Reversibility:** fully reversible.

### Q-B.8.2: Overlay persistence via cache?

**Answer:** Yes. Cache entry stores per-module overlay state alongside env entries.

**Reasoning:**
- Primitive #1 (graph): overlay IS graph state; cache round-trips via existing Pack/Unpack substrate (Phase B).
- Miss → rebuild is already the semantics; overlay fits.

**Drift check:** drift 9 avoided — full round-trip specified.

**Reversibility:** fully reversible.

---

## Phase B.9 — LFeedback

### Q-B.9.1: Feedback state slot — growth mid-handler?

**Answer:** State record is FINAL at handler declaration. Dynamic state = separate handler composition.

**Reasoning:**
- Primitive #2 (handler): handler state is declared at install; mid-execution growth breaks the substrate contract.
- If dynamic state is needed: inner handler with its own state composes via `~>`.

**Drift check:** drift 9 avoided — no "state grows sometimes" half-spec.

**Reversibility:** load-bearing for LF substrate; changing would cascade through handler semantics.

---

## Phase C — crucibles

### Q-C.3.1: DSP primitives already carry `!Alloc`?

**Answer:** NO, per grep. `lib/dsp/processors.nx` has handlers without `!Alloc` annotations. C.3 landing requires sweep.

**Action:** at C.3 commit, add `!Alloc` annotations to every DSP primitive (highpass, compress, limit, etc.). Transitive propagation validates `stereo_callback`'s `!Alloc` claim.

**Reasoning:**
- Primitive #4 (row algebra): `!Alloc` propagates transitively; DSP primitives must themselves declare `!Alloc` for the claim to hold at the callback level.

**Drift check:** drift 9 avoided — annotations land before the crucible expects them.

**Reversibility:** fully reversible.

### Q-C.4.1: `native_matmul` — pure Inka or FFI?

**Answer:** Pure Inka naive for v1. O(M×N×K) loop. SIMD/BLAS is post-first-light (F.5 + Hα).

**Reasoning:**
- Crucible tests handler-swap thesis, not BLAS performance.
- "Handler IS the backend" (INSIGHTS): later, `~> blas_compute` handler swaps in BLAS via FFI.

**Drift check:** drift 9 avoided — pure Inka today; BLAS as named follow-up.

**Reversibility:** fully reversible.

### Q-C.6.1: Function identity hash — compile-time or runtime?

**Answer:** Compile-time. `hash_of(fn_name)` is a compile-time intrinsic returning content-addressed hash of the function's lowered form.

**Reasoning:**
- Primitive #8 (Reason/provenance): compile-time hash is stable across compilations; runtime hash of closures is unstable (captures may differ).
- Matches PLAN 2026-04-21 "cross-wire RPC serialization" — content addressing at compile time.

**Drift check:** drift 8 avoided — structural hash, not `"fn_name"` string.

**Reversibility:** load-bearing for cross-wire RPC; changing cascades through C.6 + F.5 distributed crucibles.

---

## Phase D — voice + tutorial

### Q-D.1.1 — D.1.5: MV voice register / CLI / publishing

**Answer: DECISION REQUIRED (Morgan-specific).** These are character + product decisions.

**Options surfaced for each:**

- **Q-D.1.1 Voice register exact words:** ongoing MV.2 work with Morgan; no single answer.
- **Q-D.1.2 CLI flags (positional vs keyword):**
  - Option α: positional — `inka compile main`.
  - Option β: keyword — `inka --with compile_run main`.
  - Both can coexist (alias pattern per PLAN 2026-04-21).
  - **Recommendation:** both. Positional subcommand aliases for common verbs; `--with` for extensibility.
- **Q-D.1.3 Handler hash input:**
  - Option α: source-hash only.
  - Option β: inferred-env-hash only.
  - Option γ: tuple.
  - **Recommendation:** γ tuple `(source_hash, inferred_env_hash)`. Matches cache discipline (Q-B.6.2).
- **Q-D.1.4 Subcommand aliases:**
  - Option α: in-source table in `src/main.nx`.
  - Option β: in-shell-wrapper.
  - **Recommendation:** α. The `main.nx` IS the canonical manifest per EH discipline.
- **Q-D.1.5 VS Code extension publishing:**
  - Option α: pre-first-light (alpha channel).
  - Option β: post-first-light (stable).
  - **Recommendation:** β. `first-light-L1` tag is the PR-worthy milestone.

### DP-D.2 / Q-D.2.1: Tutorial content strategy?

**Answer:** **Hybrid.** Minimal seed content (~15-20 lines per file with a canonical example) + Mentl's `teach_narrative` narrates over at runtime.

**Reasoning:**
- Minimal seeds serve `inka new <project>` template (00-hello.nx must be non-empty for the template to work).
- Mentl narrates at teach-time, projecting the example into primitive-specific instruction.
- Option β alone requires MV.2 ready before learners can onboard; hybrid bridges.

**Drift check:** drift 9 avoided — content strategy explicit, not "content later."

**Reversibility:** fully reversible; seeds can grow or shrink based on MV.2 narration quality.

### Q-D.3.1: 02b-multishot.nx uses Choice directly?

**Answer:** Direct. `perform choose(...)` with `~> backtrack` handler in view.

**Reasoning:**
- Primitive #2 tutorial: the file teaches MS resume discipline; wrapping hides what learner must see.
- Pedagogical: learners should see `@resume=MultiShot` + `perform choose` + `~> backtrack` composed inline.

**Drift check:** drift 6 avoided — no "helper function" wrapper around the primitive.

**Reversibility:** fully reversible.

---

## Phase E — meta-discipline

### Q-E.1.1: plan-audit git hook integration?

**Answer:** Yes. Extend `tools/setup-git-hooks.sh` to install plan-audit as pre-commit check on PLAN.md + substrate changes.

**Reasoning:**
- Prevent PLAN drift at commit time, not at audit time.
- Matches drift-audit's pre-commit pattern.

**Drift check:** drift 9 avoided — hook explicit.

**Reversibility:** fully reversible.

### Q-E.1.2 / DP-E.1: PLAN aspirational-claims convention?

**Answer:** **Separate section.** Add explicit `## Aspirational Claims` section to PLAN.md; plan-audit skips this section.

**Reasoning:**
- Primitive #8 (Reason): explicit aspirational-flagging makes intent legible.
- Inline suppressions (`// plan-audit: ignore`) are drift-adjacent — hide rather than declare.

**Drift check:** drift 9 avoided — aspirational IS aspirational, not masquerading as landed.

**Reversibility:** fully reversible.

### Q-E.2.1: Ship-gate vocabulary regex?

**Answer:** Five initial patterns:
```
\b\d+\s*sessions?\b
\btimebox\b
\bpivot criterion\b
\bN\s*sessions?\b
\bship\s*gate\b
```

Iterate as false-positives surface.

**Reasoning:**
- Narrow patterns that catch agile/scrum imports without false-positiving on legitimate Inka vocabulary (e.g., "pivot" alone is too broad — Mentl's tentacles pivot).

**Drift check:** drift 8 avoided — structured catalog, not ad-hoc matching.

**Reversibility:** fully reversible.

### Q-E.4.1: `.inka/handlers/` discovery order?

**Answer:** Project-local first, then user-global (`~/.inka/handlers/`). Matches `~>` capability-stack ordering.

**Reasoning:**
- Primitive #2 (handler): project-specific overrides global; parallel to env_scope_enter semantics.

**Drift check:** drift 2 avoided — not a Scheme-style lexical frame walk; flat lookup with explicit fallback.

**Reversibility:** fully reversible.

### Q-E.4.2: Handler hash input — source/env/both?

**Answer:** Both. `(source_hash, inferred_env_hash)` tuple per Q-D.1.3.

**Reasoning:** Same source + different handler chain = different compiled WAT. Tuple key captures this per PLAN 2026-04-21.

**Reversibility:** cache invalidates on key-shape change.

### Q-E.6.1: HandlerCatalog runtime registration trigger?

**Answer:** Module-import time. `driver.nx`'s install phase fires `perform register_handler(name, rows)` per module's handlers.

**Reasoning:**
- Primitive #2 + primitive #1: handlers declared in a module ARE graph entries; registration is a projection.
- No separate CLI registration needed — import-time is substrate-native.

**Drift check:** drift 9 avoided — registration fires on known event, not "sometime."

**Reversibility:** fully reversible; explicit `inka register-handler` CLI is a peer if needed.

---

## Phase F — post-first-light

### Q-F.5.1 / MS2-Q2: Trail buffer growth under high-fork SAT?

**Answer:** Defer to SAT crucible benchmark. Flat buffer today; measure at 10^6+ decisions; compare against Salsa-overlay. Don't add persistent-trail substrate prematurely.

**Reasoning:**
- Engineering judgment: measure before optimizing.
- Primitive #1 (graph): current substrate is flat; Salsa is a well-documented upgrade path.

**Drift check:** drift 9 avoided — deferred with named triggering event.

**Reversibility:** fully reversible; substrate upgrade is additive.

### Q-F.5.2 / MS2-Q6: MS-aware IDE tooling?

**Answer:** Handler projection pattern. `trace_handler → timeline_json` composition. Substrate clear; UX deferred.

**Reasoning:**
- Primitive #2: "every output is a handler projection" — IDE timeline is just another projection.
- UX design is product work; substrate is specified.

**Drift check:** drift 9 avoided — handler pattern named, not handwaved.

**Reversibility:** fully reversible.

### Q-F.7.1: Web playground runtime?

**Answer:** Hybrid. v1 server-side (wasmtime-in-cloud); v2 browser-only post-first-light when WASM threads + SharedArrayBuffer reliably available.

**Reasoning:**
- v1 scope: minimum viable web surface.
- v2 scope: fully-browser playground requires WASM threads for parallel_compose to demonstrate across domain-crucibles.

**Drift check:** drift 9 avoided — two explicit phases, not "figure it out later."

**Reversibility:** fully reversible.

### DP-F.5: First post-first-light domain?

**Answer: DECISION REQUIRED.** Morgan's call when first-light lands; likely driven by first user project per CRU protocol.

**Options:**
- **Pulse** (per existing integration trace `docs/traces/a-day.md`) — real-time audio + browser UI + cloud server + training variant. Exercises DSP + ML + web + realtime crucibles simultaneously.
- **A specific new crucible from MS2 §2** (SAT, logic prog, distributed, games, etc.).

**Recommendation:** Pulse — the integration trace is already the specification; first-light extends from there.

---

## Summary — decisions ledger table

| Question | Answer | Morgan review? |
|----------|--------|----------------|
| Q-A.1.1 | No hash suffix; `<module>__<symbol>` | Proceed |
| Q-A.1.2 | Linker = symbol resolution only | Proceed |
| Q-B.1.1 | Add `tools/effect-registry-audit.sh` | Proceed |
| DP-B.1 | α (rename DSP's Alloc → BufferAlloc) | Proceed |
| Q-B.2.1 | Defer `!MultiShot` row modifier | Proceed |
| Q-B.2.2 | `wasm-interp` cross-check in DET gate | Proceed |
| Q-B.2.3 | v3 → v4 cache bump at B.2 | Proceed |
| Q-B.3.1 | Bare `Choice` (no effect-level param) | Proceed |
| Q-B.3.2 | Runtime Abort; handler decides | Proceed |
| Q-B.4.1 | Tiebreak chain always | Proceed |
| Q-B.4.2 | Shared checkpoint at race install | Proceed |
| Q-B.5.1 | Defer MS+GC to F.4 landing | Proceed |
| Q-B.5.2 | Auto parent arena; override via param | Proceed |
| Q-B.6.1 | 5-variant TheoryClass ADT | Proceed |
| Q-B.6.2 | Triple-key cache | Proceed |
| Q-B.6.3 | Nested `~>` fall-through | Proceed |
| Q-B.7.1 | Runtime SharedArrayBuffer detection | Proceed |
| Q-B.7.2 | OS threads direct for v1 | Proceed |
| Q-B.7.3 | `><` order-preserving always | Proceed |
| Q-B.8.1 | Own overlay first, imports in decl order | Proceed |
| Q-B.8.2 | Overlay persisted in cache | Proceed |
| Q-B.9.1 | State record immutable post-declaration | Proceed |
| Q-C.3.1 | `!Alloc` sweep at C.3 landing | Proceed |
| Q-C.4.1 | Pure-Inka naive matmul for v1 | Proceed |
| Q-C.6.1 | Compile-time function hash | Proceed |
| Q-D.1.1 | **DECISION REQUIRED** — voice register words | Morgan |
| Q-D.1.2 | Both positional + `--with` (recommended) | Morgan confirm |
| Q-D.1.3 | Tuple `(source, env)` hash | Proceed |
| Q-D.1.4 | In-source subcommand table | Proceed |
| Q-D.1.5 | Post-first-light publishing | Morgan confirm |
| DP-D.2 | Hybrid (seed + Mentl narration) | Proceed |
| Q-D.3.1 | Direct `Choice` in 02b-multishot | Proceed |
| Q-E.1.1 | Install plan-audit as pre-commit hook | Proceed |
| DP-E.1 | Separate "Aspirational Claims" section | Proceed |
| Q-E.2.1 | Five-pattern ship-gate regex catalog | Proceed |
| Q-E.4.1 | Project-local first; user-global fallback | Proceed |
| Q-E.4.2 | Tuple `(source, env)` hash | Proceed |
| Q-E.6.1 | Module-import time registration | Proceed |
| Q-F.5.1 | Defer to SAT crucible benchmark | Proceed |
| Q-F.5.2 | Handler projection; UX later | Proceed |
| Q-F.7.1 | v1 server-side; v2 browser | Proceed |
| DP-F.5 | **DECISION REQUIRED** — Pulse (recommended) | Morgan |

**Morgan review flagged on 4 items; all others have Inka-discipline-derived answers that the implementer can use as contract.**

---

## Load-bearing vs reversible

Decisions that cascade if changed:
- **Q-A.1.2** (linker = symbol resolution) — cascades through BT + HC.
- **Q-B.4.1** (tiebreak determinism) — load-bearing for first-light.
- **Q-B.7.3** (`><` order-preserving) — load-bearing for first-light.
- **Q-B.9.1** (state record immutability) — cascades through LF + HC.
- **Q-C.6.1** (compile-time function hash) — load-bearing for cross-wire RPC.

Everything else is reversible. Revise if substrate discovery demands.

---

## Closing

Every question surfaced in the 2026-04-23 planning round now has:
- An answer grounded in Inka's primitives.
- A drift-mode check.
- A reversibility assessment.
- Morgan review flagged where preference (not discipline) decides.

**The plan file can now reference this as settled contract.** When B.2 H7 walkthrough opens, the implementer doesn't ask "should Choice be parameterized?" — they read Q-B.3.1 and transcribe. When BT linker closes, the implementer doesn't ask "do we hash-suffix module symbols?" — they read Q-A.1.1 and transcribe.

*Questions answered ahead of substrate means the residue is what gets typed. Inka solves Inka, and Mentl's eight interrogations gave every answer their structural form.*
