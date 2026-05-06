# Hβ.lower.diverge-via-thread — `<|` parallelism via Thread effect

> **Status:** `[DRAFT 2026-05-05]`. Wheel-side close of the `<|`
> verb so it composes with `parallel_compose` symmetrically to
> `><`. Cascade: Hβ.lower (riffle-back per Anchor 7 step 4 against
> the post-Hμ.cursor SUBSTRATE.md §431 "ownership is the structural
> difference" landing). Authority: SUBSTRATE.md §431 + SYNTAX.md
> §357-384 + TH-threading.md §1.3.

## §0. Header

This walkthrough closes the asymmetry where `><` (PCompose) lowers
through `lower_compose_via_thread` to per-branch thunk closures
+ spawn/join while `<|` (PDiverge) lowers to sequential `LCall`
per branch. SUBSTRATE.md §431 ("`<|` vs `><`: Ownership Is the
Structural Difference") names both verbs as parallelism: the
distinction is INPUT OWNERSHIP, not serial-vs-parallel. After
this commit lands, both verbs route through the Thread effect;
`parallel_compose` intercepts uniformly; the substrate is uniform.

## §1. Framing

`<|` is parallelism per SUBSTRATE.md §431. The structural
difference from `><` is OWNERSHIP — `<|` ref-borrows a shared
input across N branches; `><` consumes N independent inputs. The
serial-vs-parallel question is a HANDLER question, not a verb
question: `~> sequential_compose` runs both `<|` and `><` thunks
synchronously inline; `~> parallel_compose` dispatches both to
distinct OS threads via `wasi-threads`. Multi-core is a handler
installation, not a language feature; the substrate must be
uniform across verbs so that the same handler covers both.

The pre-this-commit asymmetry — PCompose routes through
`lower_compose_via_thread`; PDiverge emits sequential `LCall` —
was a wheel-side bug, not a substrate disagreement. The graph
already encodes both verbs at PipeKind; the handler already
intercepts spawn/join; only the lowering arm was unfinished.

## §2. Empirical evidence

```
A.1 — PDiverge at lower.mn:494-499 emits LMakeTuple of LCall (sequential). CONFIRMED.
A.2 — PCompose at lower.mn:483-484 routes through lower_compose_via_thread, emits LPerform spawn+join. CONFIRMED.
A.3 — TH walkthrough §3+§8.3 names `><` only; `<|` absent. CONFIRMED.
A.4 — synthesize_branch_thunk wraps a parser node directly; <| needs Call(branch, [input]) wrapping. CONFIRMED.
A.5 — PDiverge right is MakeTupleExpr(branch_nodes); lower_expr(right) → LMakeTuple(_, lo_branches). CONFIRMED.
```

§A.6 escalation gate: cleared. All five CONFIRMED — substrate
gap reproduces; this walkthrough proceeds.

## §3. Substrate decision — Path A vs Path B

Two routes exist for closing the gap:

- **Path A** — abstract a verb-agnostic `lower_parallel_via_thread(handle, branches, capture_strategy)` covering both `><` and `<|` at one call site, distinguished by a `capture_strategy` ADT (Independent | SharedBorrow).
- **Path B** — author `lower_diverge_via_thread` symmetric to
  `lower_compose_via_thread`; keep the two arms peer-named at the
  PipeExpr match; abstract LATER when a third instance arrives.

**Decision: Path B**, three rationales:

1. **Lowering local.** The PipeExpr arm in `lower_pipe` is the
   natural authoring frame; one helper per arm reads cleanly and
   matches the current PCompose shape.
2. **Abstraction premature at 2 instances per Anchor 7 three-
   instances rule.** Two parallel sites do not justify the
   `capture_strategy` ADT; if a third instance appears (Hβ peer
   G.3), the abstraction earns its existence through evidence,
   not anticipation.
3. **Explicit `__diverge_input` let-local makes shared-borrow
   shape visible.** Path A would hide capture-policy inside the
   ADT; Path B writes the let-local inline so the LIR diff
   between `><` and `<|` is one specific structural delta —
   exactly what SUBSTRATE.md §431 describes as "ownership is the
   structural difference."

## §4. Eight interrogations

| # | Interrogation | Answer for Hβ.lower.diverge-via-thread |
|---|---|---|
| 1 | **Graph?** | PDiverge AST + branch_nodes already carried in the `PipeExpr(PDiverge, left, right)` graph edge; right's `NExpr(MakeTupleExpr(branches))` enumerates each branch handle. No new graph vocabulary. |
| 2 | **Handler?** | `parallel_compose` (already declared in `lib/runtime/threading.mn:114-125`); after this commit it intercepts BOTH `><` and `<|` spawn/join. `@resume=OneShot` per Thread effect declaration §1.1. |
| 3 | **Verb?** | `<|` is the second parallelism verb (SUBSTRATE.md §431). This commit makes the wheel-side dispatch story symmetric across `<|` and `><`. |
| 4 | **Row?** | + Thread (always); + SharedMemory only when branches read shared atomics. Per peer G.1 `Hβ.infer.diverge-shared-memory-row`, infer enforces row composition; lower trusts the proof. `!SharedMemory` proves parallelizable-no-sync. |
| 5 | **Ownership?** | `<|` ref-borrows the shared input across N branches (SUBSTRATE.md §431-455). `own` values cannot flow through `<|` — affine violation `E_OwnershipViolation` enforced at infer; lower trusts the proof. Each branch thunk captures the let-local `__diverge_input` by handle. |
| 6 | **Refinement?** | Post-L2 named follow-up: `parallel_safe(branches)` predicate confirming each branch is independent of others' Reason chain. Today: opaque. |
| 7 | **Gradient?** | `~> parallel_compose` UNLOCKS `CParallelize` for both verbs after this commit. Mentl's Unlock tentacle surfaces a voice line ("`~> parallel_compose` unlocks multi-core for this `<|` chain — proven safe by `!SharedMemory` in all branches"). |
| 8 | **Reason?** | Each spawn at the lowering site records `Reason::ThreadSpawned(span)` (existing). Peer G.2 `Reason.branch-spawned-verb-tagged` will extend to `BranchSpawned(span, verb_tag)` so the Why Engine can answer "did this thread come from `<|` or `><`?". Today: ThreadSpawned uniform. |

## §5. Substrate change — LIR diagram

### Before (sequential PDiverge)

For source `input <| (f, g)`:

```
LMakeTuple(handle, [
  LCall(0, lo_f, [lo_input]),
  LCall(0, lo_g, [lo_input])
])
```

`lo_input` evaluated TWICE (once per branch substitution; the
input expression is duplicated, not shared) — a separate latent
bug fixed as a side effect of this commit. No spawn; no join;
no `parallel_compose` interception possible.

### After (Thread-dispatched PDiverge)

```
LBlock(handle, [
  LLet(input_h, "__diverge_input_<handle>", lo_input),
  LMakeTuple(handle, [
    LPerform(handle, "join", [
      LPerform(handle, "spawn", [
        LMakeClosure(handle,
          LFn("diverge_0_<handle>", 0, [],
              [LCall(branch_h_f, lo_f,
                     [LLocal(input_h, "__diverge_input_<handle>")])],
              EfPure),
          [LLocal(input_h, "__diverge_input_<handle>")],
          [])
      ])
    ]),
    LPerform(handle, "join", [
      LPerform(handle, "spawn", [
        LMakeClosure(handle,
          LFn("diverge_1_<handle>", 0, [],
              [LCall(branch_h_g, lo_g,
                     [LLocal(input_h, "__diverge_input_<handle>")])],
              EfPure),
          [LLocal(input_h, "__diverge_input_<handle>")],
          [])
      ])
    ])
  ])
])
```

The let-local binds `lo_input` ONCE; each thunk closure captures
it by handle (one capture per thunk; uniform across branches);
the spawn/join pair gives `parallel_compose` an interception
point; the joined results tuple in source-branch order
(determinism per Q-B.7.3).

## §6. Diagnostic implications

`E_OwnershipViolation` for `own` values flowing through `<|` is
already enforced at infer (per SUBSTRATE.md §452-455 — "`<|` is
visible in the AST, the compiler catches it"). This lowering
trusts the infer-side proof; if `own` reached lower, the substrate
gap is in infer, not here.

A new Reason variant is named as peer G.2 (`Reason.branch-spawned-
verb-tagged`) — extends the existing `Reason::ThreadSpawned(span)`
to `Reason::BranchSpawned(span, verb_tag)` where `verb_tag`
discriminates `VDiverge | VCompose`. Why Engine queries can then
walk back from a spawned thread to its originating verb, surfacing
"this branch ran on thread 3 because the `<|` at line 42 was
intercepted by `~> parallel_compose`."

## §7. Composition with peer handlers

Verb × handler matrix:

| Composition | Behavior |
|---|---|
| `<|` × `parallel_compose` | each branch dispatched to a distinct OS thread; per-thread bump_allocator; tuple order preserved per Q-B.7.3 |
| `<|` × `sequential_compose` | each thunk evaluated synchronously inline (graceful fallback per Q-B.7.1) |
| `<|` × `race` | orthogonal topologies — race per branch is fine; race over `<|` outputs is `|>` composition, not handler stacking |
| `<|` × `Choice` | orthogonal — Choice's backtrack inside a branch is independent of the branch's parallel dispatch |
| `<|` × `arena_ms` | per-thread bump arenas; replay_safe / fork_deny / fork_copy compose with thread-local arenas (TH §1.3) |

The composition story is SYMMETRIC to `><`: every handler that
covers `><` covers `<|` after this commit; the substrate is
uniform.

## §8. Forbidden patterns

- **Drift 1 (vtable):** NO dispatch table for "is this branch
  shared-input or independent-input." The PipeKind ADT IS the
  dispatch; the lowering arm IS the dispatch table. Closure
  records carry capture state; never a vtable.
- **Drift 5 (separate __closure / __ev):** the shared input is
  CLOSURE STATE captured via `LLocal(input_h, "__diverge_input_*")`
  in `captures_exprs`. NOT a hidden parameter to spawn. The
  unified `__state` discipline is preserved — every thunk's
  captures live in the closure record's capture slots, period.
- **Drift 7 (parallel arrays):** per-branch thunks build as
  `List<LowExpr>` via `synthesize_diverge_thunks`; spawn-join
  pairs build as `List<LowExpr>` via `spawn_join_each`. NOT
  `(List<thunk>, List<spawn>, List<join>)` parallel arrays.
- **Drift 9 (deferred):** this commit lands the let-local +
  per-branch thunks + spawn/join tuple atomically. Row enforcement
  (peer G.1) and Reason variant (peer G.2) and crucible (peer G.4)
  are NAMED PEER HANDLES, not absences-with-comments.
- **Foreign-fluency lock:** NOT `Promise.all([f, g])`, NOT
  `forkJoin([f, g])`, NOT `join_all(vec![spawn(f), spawn(g)])`.
  Mentl has `<|` + `~> parallel_compose`. The thunk-and-spawn
  shape is a LOWERING detail invisible at the source — surface
  syntax remains `input <| (f, g)`.

## §9. Three named peer follow-ups

- **G.1 `Hβ.infer.diverge-shared-memory-row`** — peer handle for
  `+ SharedMemory` enforcement at the infer-side of PDiverge. The
  current infer arm enforces `+ Thread` for `><`; symmetric +
  conditional `+ SharedMemory` enforcement for `<|` is the peer
  closure.
- **G.2 `Reason.branch-spawned-verb-tagged`** — extend
  `Reason::ThreadSpawned(span)` to `Reason::BranchSpawned(span,
  verb_tag)` where `verb_tag : VerbTag = VDiverge | VCompose`.
  Why Engine queries about spawn provenance walk back to the
  originating verb.
- **G.3 `Hβ.lower.diverge-thunk-abstraction`** — third-instance
  abstraction trigger. If a third spawn-tuple-thunk site appears
  (`<~`-on-thread-pool, race fanout, etc.), unify
  `lower_compose_via_thread` and `lower_diverge_via_thread` into
  a verb-agnostic `lower_parallel_via_thread(handle, branches,
  capture_strategy : Independent | SharedBorrow)`.

## §10. Verification (Anchor 0 — by simulation)

### 10.1 Structural-shape simulation

Hand-trace `input <| (f, g)`:

1. `lower_pipe(PDiverge, left=input, right=tuple_node, handle=H)`
   routes to `lower_diverge_via_thread(H, input, tuple_node)`.
2. `lo_input = lower_expr(input)` returns `LLocal(input_h, "input")`
   (assuming `input` is a name).
3. `input_local_name = "__diverge_input_<H>"`.
4. `branch_nodes = [N(NExpr(NameExpr("f")), _, fh), N(NExpr(NameExpr("g")), _, gh)]`
   from MakeTupleExpr unwrapping.
5. `synthesize_diverge_thunks` produces two LMakeClosures whose
   bodies are `LCall(fh, lo_f, [LLocal(input_h, "__diverge_input_H")])`
   and `LCall(gh, lo_g, [...])`; each captures
   `LLocal(input_h, "__diverge_input_H")`.
6. `spawn_join_each` produces two
   `LPerform(H, "join", [LPerform(H, "spawn", [thunk_i])])`.
7. Returns `LBlock(H, [LLet(input_h, "__diverge_input_H", lo_input),
   LMakeTuple(H, [join_0, join_1])])`.

Shape matches §5 "After" diagram. PASS.

### 10.2 Symmetry simulation

Compare PCompose vs PDiverge LIR side by side for `(f x) >< (g y)`
vs `input <| (f, g)`:

- PCompose: 2 thunks; thunk_l body = `lo_(f x)`; thunk_r body =
  `lo_(g y)`. No shared captures (each branch closes over its
  OWN free vars resolved through `resolve_captures_outer`).
- PDiverge: 2 thunks; thunk_0 body = `LCall(fh, lo_f, [shared_local])`;
  thunk_1 body = `LCall(gh, lo_g, [shared_local])`. Shared
  capture via `LLocal(input_h, "__diverge_input_H")`.

Difference: ONLY the captures shape (independent vs shared). The
spawn/join pair is identical; `parallel_compose` interception is
identical. PASS.

### 10.3 Composition simulation

`<| ~> parallel_compose`: handler intercepts spawn arm → ffi_spawn
→ wasi_thread_spawn → distinct OS thread per branch. Join arm →
ffi_join → wait_i32 + atomic_load_i32. Tuple order preserved.

`<| ~> sequential_compose`: handler's spawn arm runs `task()`
synchronously inline; join is no-op (result already computed).
Output identical to a sequential `<|`; gracefully degrades when
SharedArrayBuffer unavailable per Q-B.7.1. PASS.

## §11. Crucible signal

Peer follow-up **G.4 `Crucible.diverge-parallel`** —
`crucibles/crucible_diverge_parallel.mn` is a `<|`-shaped sibling
to the existing `crucible_parallel.mn` (which exercises `><`).
NOT in scope of this commit (lands at L3 stage post-first-light);
named here as the named follow-up that closes Anchor 7 step 3.

## §12. Closing

`<|` is parallelism. The structural distinction from `><` is
ownership — shared-borrow versus independent-consume. Dispatch
is identical: both verbs lower to per-branch thunk closures +
spawn/join; `parallel_compose` intercepts uniformly. After this
commit, the substrate is uniform; the mental model matches reality;
the wheel-side gap closes. Riffle-back addendum to TH-threading.md
records the historical asymmetry's resolution.
