# AM — Arena × MultiShot · three policies at handler-install

> **Status:** `[DRAFT 2026-04-23]`. MSR Edit 4 walkthrough. Closes
> DESIGN Ch 6 D.1 (lines 1462-1488) — *"A multi-shot continuation
> captured inside a scoped-arena handler raises a semantic question:
> what happens when the continuation is resumed after the arena has
> been reset?"* Three peer handlers on the `EmitMemory` swap surface:
> `replay_safe` (trace-replay; no capture struct), `fork_deny`
> (compile-time refusal; `T_ContinuationEscapes`), `fork_copy`
> (deep-copy into caller's arena). One invariant from the row
> algebra: **`!Alloc` × MS ⇒ `replay_safe` is the only admissible
> policy** — forking allocates; `!Alloc` forbids allocation; the
> compiler enforces the combination at handler-install time. AM is
> the Inka-native answer to Tofte-Talpin × Affect POPL 2025 × region-
> based memory management × delimited continuations: the arena
> handler decides how captures interact with arena lifetime; the
> continuation record is allocated through the same `emit_alloc`
> surface every other heap record uses; escape analysis composes on
> H4's `region_tracker` substrate already wired in `src/own.nx:199-306`.
>
> *Claim in one sentence:* **Three peer handlers on the one
> `emit_alloc` swap surface resolve the MS × arena question — pick
> at handler-install time; the compiler proves which combinations
> are admissible via row subsumption; `fork_deny` emits
> `T_ContinuationEscapes` at lower-time on arena-escaped captures;
> no prior language integrates multi-shot continuations with scoped
> arenas cleanly.**

---

## 0. Framing — why AM is the keystone of `!Alloc × MS` composition

### 0.1 What AM resolves

DESIGN Ch 6 D.1 has sat open as a named design question since the
manifesto was written. Three policies were enumerated; none
materialized. The error code `T_ContinuationEscapes` has existed in
`docs/errors/` as *"Teach / Warning (hardens to Error when F.4
semantics finalize)"* — a placeholder pending AM. H4
(`region_tracker` in `src/own.nx:199-306`) landed the
region-escape substrate for OneShot Alloc escapes; its arms
(`region_enter` / `tag_alloc` / `check_escape`) are already wired,
with the note at `src/own.nx:210-214` that *"the full Alloc-tagging
path (every `perform alloc(n)` runs through tag_alloc) will land
when EmitMemory arena semantics bind region identities to alloc
returns."*

**The substrate is ready. The handlers are unwritten. AM writes them.**

Per the plan file's critical-path graph (`alright-let-s-put-together-silly-nova.md`
§B.5), AM is one of three peer walkthroughs in the Phase B MS
substrate quartet: H7 (the MS emit path), CE (the canonical MS
user effect), HC2 (the race combinator), AM (arena policies).
With H7 landed, AM closes the quartet. After AM:

- **`!Alloc × MS` is admissible** — specifically, `replay_safe` +
  `!Alloc` compose (no allocation, only trail-replay). The four-
  compilation-gate `!Alloc` claim (DESIGN §3.4) extends to MS
  computations cleanly for the first time.
- **`fork_deny` is emittable** — `T_ContinuationEscapes` hardens
  from `Teach/Warning` to `Error` with the three canonical fixes
  shipped as machine-applicable patches (per `docs/errors/T_ContinuationEscapes.md:44-46`).
- **`fork_copy` runs** — deep-copy traversal lands in
  `lib/runtime/arena_ms.nx`; per-batch autodiff tape in B.11 ML
  training uses it; `><` parallel-speculate branches via `race` +
  `fork_copy` land as one-pattern composition.
- **Mentl's Trace tentacle** (`src/mentl.nx` — primitive #5
  surface) surfaces one of the three policies as a gradient hint
  when the user installs an arena handler around an MS-typed body;
  the default is `replay_safe` per Q-B.5.2.
- **B.11 ML training substrate** — autodiff's MS backward pass
  allocates per-batch into an arena; `fork_copy` hoists the tape
  into the caller's arena on every candidate learning-rate fork;
  B.11 can author substrate cleanly.

**AM is the Inka-native answer** to a research question POPL 2025's
Affect paper raised at the type level but left open at the runtime
semantics. Inka's residue: three handlers, one swap surface, one
row-algebra invariant.

### 0.2 Named policies (all from DESIGN Ch 6 D.1)

The three policies are not new design space. They are DESIGN's three
options ratified with substrate residue. Each is a handler on the
same `EmitMemory` effect; the existing `emit_memory_bump` peer
(`src/backends/wasm.nx:76+`) is the baseline default. Per anchor 5:
*"if it needs to exist, it's a handler."*

| Policy | Capture behavior | Runtime cost | Admissibility |
|--------|------------------|--------------|---------------|
| **`replay_safe`** | NO capture struct allocation; records effect trace from handler-install to perform site | Re-execution on every resume (trail-bounded) | `!Alloc` compat (zero allocation); `!Mutate` compat (mutations replay); compatible with `!IO` if trail-deterministic. Incompatible when effects mutate external state irreversibly |
| **`fork_deny`** | Capture struct allocated via `emit_alloc`, but `check_escape` extension walks captures for arena-scoped refs; FAILS at lower-time with `T_ContinuationEscapes` if any capture holds an arena-interior pointer | Zero runtime cost (compile-time refusal) | Works for MS captures that only hold outer-arena / global / stack values |
| **`fork_copy`** | Capture struct allocated via `emit_alloc`; each arena-scoped capture deep-copied into the caller's arena (default: parent per Q-B.5.2; override via `fork_copy(target_arena)`) | O(M) per capture where M = transitive reachable bytes; pays at capture time, not resume time | Works universally; trades allocation for semantics |

### 0.3 In scope

- **§1** — Three handler declarations (`replay_safe`, `fork_deny`,
  `fork_copy`) as peer `EmitMemory` handlers.
- **§1** — `@via_arena=ArenaId` refinement tag on TCont and its
  interaction with the refinement substrate.
- **§1** — The `!Alloc × MS ⇒ replay_safe only` row-algebra invariant.
- **§1** — Default-policy selection (per Q-B.5.2: auto parent-arena
  fork_copy; user override).
- **§2** — Per-edit-site eight-interrogation table.
- **§3** — Forbidden-pattern enumeration per edit site — all nine
  drift modes plus generalized fluency-taint against Rust
  `Pin<Box<...>>`, C++ `std::pmr`, Tofte-Talpin `RegPoly<ρ>`,
  Cyclone region annotations, Vale `'a` lifetimes.
- **§4** — Substrate touch sites at file:line targets. Halt-signals
  §4.0 catch any imprecision in prior MSR / DESIGN references.
- **§5** — Worked example — an adaptive DSP filter that uses MS
  for candidate exploration inside a per-block `temp_arena`,
  demonstrating all three policies on the same source code.
- **§6** — Composition with H7 (LMakeContinuation), CE (Choice),
  HC2 (race), B.11 ML, and H4 (existing region_tracker).
- **§7** — Three design candidates (trivially DESIGN's three) + why
  Mentl ratifies all three as peers rather than picking one.
- **§8** — Acceptance criteria.
- **§9** — Open questions (all pre-answered per QA).
- **§10** — Dispatch + closing.

### 0.4 Out of scope

- **MS emit path itself.** H7 walkthrough. AM composes on H7's
  `LMakeContinuation` variant; H7 provides the record, AM provides
  three allocation strategies for that record.
- **GC × MS × arena.** Per Q-B.5.1 (resolved): defer to F.4
  GC-landing. AM ships bump + arena policies; GC is a later peer.
- **Per-field arena policies.** AM's policies apply to the entire
  continuation capture uniformly. A continuation that captures
  three locals, one arena-scoped, cannot split per-local policies
  in v1 — the capturing handler picks one policy for all. If
  per-capture policies emerge as a real need post-first-light, a
  peer sub-handle (AM.1) extends.
- **Distributed MS × arena.** Cross-machine resume (DESIGN §10.4
  RPC-as-delimited-continuation) with arena semantics is a distinct
  substrate layer — the arena doesn't even exist on the receiving
  node. Post-first-light, Pulse-level territory.
- **Arena-nested arena.** Nested `temp_arena` handlers (DESIGN line
  1572: *"Multiple arenas nest. Bump inside bump. Arena inside
  arena."*) already work for OneShot (H4). AM's arms are
  handler-install-scoped — same nesting discipline composes without
  extension. Documented in §6.5.

### 0.5 Relationship to H4 (region_tracker)

H4 closed Tofte-Talpin region inference for OneShot Alloc escapes.
AM extends the same substrate to MultiShot captures.

| Axis | H4 (OneShot escape) | AM (MultiShot capture) |
|------|---------------------|-------------------------|
| Kernel primitive | #5 ownership-as-effect (Consume + region) | #5 + #2 (MS resume discipline interacts) |
| Substrate effect | `Region` — region_enter / region_exit / tag_alloc / check_escape | Same `Region` effect; AM adds `check_capture_escape` peer op for MS captures |
| Handler | `region_tracker` (`src/own.nx:215+`) | Three peer handlers on `EmitMemory`; `region_tracker` arms called from each during capture/replay/copy |
| Escape surface | FnStmt return position | MS perform-site capture |
| Error code | `E_RegionEscape` / `E_OwnershipViolation` | `T_ContinuationEscapes` (hardens from Teach to Error via AM) |
| Fix applicability | MaybeIncorrect | MachineApplicable (each of 3 policies is a specific fix) |

**H4 was escape analysis for returns.** AM is escape analysis for
captures. Same substrate primitive, different surface point. The
`region_tracker` handler's `tagged_values` state already carries
each value's `region_id`; AM's `fork_deny` reads those tags at
capture time and fails if any capture's region is NOT on the
region_stack when the MS perform site runs.

---

## 1. The substrate — three peer handlers, one refinement tag, one row invariant

### 1.1 Handler — `replay_safe` (no capture, trail replay)

```
// ═══ replay_safe — MS × arena via effect-trace replay ═════════════
// Intercepts emit_alloc at MS perform sites within an arena scope
// and REFUSES the allocation. Instead, records the effect trace
// from handler-install to the perform site into a per-continuation
// trace buffer. On resume, the handler re-executes from install by
// replaying the trail.
//
// No continuation struct allocation — this is the policy that
// composes with `!Alloc`. Zero allocation cost at capture; re-
// execution cost at resume (bounded by trail length).
//
// Safety invariant: all effects in the captured slice must be
// REPLAYABLE — graph mutations are (trail-bounded per primitive
// #1); deterministic IO is (if logged); nondeterministic IO or
// external-state mutation is NOT. Row check: `replay_safe`
// declares `with ReplaySafe + !UnrepayableEffects` (where
// UnrepayableEffects is the open set of effects a user can mark
// non-replayable via a row annotation; defaults to IO + Random +
// Network when their handlers don't declare deterministic replay).
//
// Resume discipline: handler may resume the continuation multiple
// times (MS); each resume re-performs from the install site with
// the trail's recorded decisions being REPLAYED for the prefix and
// EACH CANDIDATE RESUME VALUE being the suffix's input. Replay is
// the substrate primitive #1 discipline; `graph_push_checkpoint`
// + trail + `graph_rollback` already provide it.

handler replay_safe {
  emit_alloc(size, target_local) => {
    // At non-MS sites, this handler is transparent — defer to the
    // next-outer emit_alloc handler (emit_memory_bump / arena).
    if !perform in_ms_capture() { resume_default(size, target_local) }
    else {
      // MS capture at this site: record the trace, emit no alloc.
      perform record_replay_trace(current_ms_site(), trace_from_install())
      // Emit NOTHING for the continuation record — the handler arm
      // at resume time re-executes from install using the trace.
      resume()
    }
  }
  // Additional arms: propagate region_enter / region_exit /
  // tag_alloc to the underlying region_tracker — arena semantics
  // preserved at non-MS sites.
  region_enter(span)     => resume_forward(region_enter, span)
  region_exit(rid)       => resume_forward(region_exit, rid)
  tag_alloc(value_h)     => resume_forward(tag_alloc, value_h)
  // ...
}
```

**Note on `resume_default` / `resume_forward`:** these are pseudocode
shorthands for the `~>` chain's next-outer handler dispatch. The
concrete shape is `resume()` with the underlying handler already
in scope — Inka's handler chain semantics forward the op naturally.
No new substrate primitive; standard `~>` composition.

### 1.2 Handler — `fork_deny` (compile-time refusal)

```
// ═══ fork_deny — MS × arena via compile-time refusal ══════════════
// At MS perform sites, this handler delegates to the default
// emit_alloc (the continuation record is allocated normally), but
// ALSO performs `check_capture_escape(captures, current_arena_region)`
// at lower-time. If any capture holds an arena-scoped ref whose
// region is the current arena's region, FAIL with
// `T_ContinuationEscapes` at lower time. Emit never runs for that
// MS site; the fn body fails to compile.
//
// Simplest policy — works whenever captures are shallow (capture
// entry-arguments or outer-scope values; don't capture inner
// arena-allocated structures). Recommended default for the "I want
// MS search inside this arena but don't need the captures to
// outlive the arena" case.
//
// The check_capture_escape op is a new peer on the Region effect
// (declared alongside tag_alloc / check_escape in src/own.nx's
// region_tracker) — arm-for-arm mirror, MS-capture variant.

handler fork_deny {
  emit_alloc(size, target_local) => {
    if !perform in_ms_capture() { resume_default(size, target_local) }
    else {
      let captures = current_ms_captures()
      let arena_region = perform current_region()
      // Walk each capture; refuse if any is arena-interior.
      match perform check_capture_escape(captures, arena_region) {
        Ok(()) => {
          // Captures are arena-safe; normal emit_alloc path.
          resume_default(size, target_local)
        }
        Err(escape_spans) => {
          // At least one capture holds an arena-scoped ref.
          // Emit T_ContinuationEscapes; do not emit the alloc.
          perform report(
            source, "T_ContinuationEscapes", "OwnershipViolation",
            fork_deny_message(escape_spans),
            current_ms_site_span(),
            "MachineApplicable"  // fix suggestions below
          )
          // Do NOT resume — lower-time error; emit aborts this fn.
          perform emit_abort(current_ms_site_span())
        }
      }
    }
  }
  // Region arms propagated.
  region_enter(span)     => resume_forward(region_enter, span)
  region_exit(rid)       => resume_forward(region_exit, rid)
  tag_alloc(value_h)     => resume_forward(tag_alloc, value_h)
}
```

**On the `check_capture_escape` op:** AM adds one op to the
existing Region effect (`src/own.nx:448-467` — region_tracker's
effect declaration, see §4.2 for exact literal edits). The op
peer-mirrors `check_escape` but for MS capture lists rather than
return values. Its arm in `region_tracker` reuses `lookup_tag` +
`region_on_stack` from the existing H4 substrate — same escape
walk, different entry point.

### 1.3 Handler — `fork_copy` (deep-copy captures)

```
// ═══ fork_copy — MS × arena via deep-copy into caller's arena ═══
// At MS perform sites, the continuation record is allocated into
// the default emit_alloc target (outer arena or global heap per the
// caller's scope), but each arena-scoped capture is deep-copied
// from the inner arena into the same target. The continuation
// record's captures_offsets then point at the COPIES, not the
// originals. When the inner arena drops, the continuation remains
// valid — its captures live in the caller's arena.
//
// Allocation cost: O(M) per arena-scoped capture, M = transitive
// reachable bytes. Paid at capture time (perform site), not at
// resume time (handler arm's call_indirect).
//
// Default target per Q-B.5.2: the parent arena (the next `~>`-
// outer arena handler). Override via `fork_copy(target_arena)`
// parameterization — this is the H3.1 parameterized-effects surface
// (DESIGN §3, parameterized effects via EParameterized + EffArg).
// `fork_copy()` is `fork_copy(parent)` under elaboration.

handler fork_copy with target_arena = parent_arena() {
  emit_alloc(size, target_local) => {
    if !perform in_ms_capture() { resume_default(size, target_local) }
    else {
      let captures = current_ms_captures()
      let captures_classified = perform classify_capture_regions(captures)
      //   captures_classified: List<(capture_handle, RegionClass)>
      //   RegionClass = Outer | Inner(ArenaId)

      // Allocate the continuation record in target_arena scope.
      perform with_region(target_arena, () => {
        perform emit_alloc_unconditional(size, target_local)
      })

      // For each Inner capture: deep-copy into target_arena.
      for_each(captures_classified, (entry) => {
        match entry {
          (capture_h, Outer) => {
            // Outer-scope capture: copy the pointer as-is.
            emit_store_capture(target_local, capture_h)
          },
          (capture_h, Inner(arena_id)) => {
            // Inner arena capture: deep-copy.
            let copied_h = perform deep_copy_to(capture_h, target_arena)
            emit_store_capture(target_local, copied_h)
          }
        }
      })

      resume()
    }
  }
  // Region arms propagated.
  region_enter(span)     => resume_forward(region_enter, span)
  region_exit(rid)       => resume_forward(region_exit, rid)
  tag_alloc(value_h)     => resume_forward(tag_alloc, value_h)
}

fn parent_arena() = {
  // Default target: the next-outer arena handler in the ~> chain.
  // If none present, use the global heap (arena_id = 0).
  perform next_outer_arena()
}
```

**On `deep_copy_to`:** a new op on the Alloc effect (or peer
effect — see §4.1 for decision) that recursively traverses a
value's transitive closure in the source arena and copies each
node into the target arena. Deep-copy semantics: primitives
copy by value; pointers to inner-arena data recurse; pointers to
outer-arena data copy as-is (no recursion). Ownership preserved:
each copy is `own` in the target arena; originals remain unchanged
(the inner arena will drop them when its scope exits — no harm).

### 1.4 Refinement tag — `@via_arena=ArenaId`

Per DESIGN Ch 6 D.1 line 1478-1480: *"A refinement tag
`@via_arena=ArenaId` makes the capture visible to the Fork
deny/copy logic."*

```
// ═══ @via_arena refinement — makes arena scope visible to emit ════
// Applied automatically by the region_tracker at tag_alloc time to
// any value allocated inside a live region. The tag on the value's
// TCont (when captured in an MS continuation) makes fork_deny /
// fork_copy able to distinguish "was this allocated in an arena?"
// from "is this a global / outer value?" without re-walking the
// region_stack at every emit_alloc site.
//
// Refinement integration: primitive #6. `@via_arena=ArenaId` is a
// refinement predicate attached to TCont(ret, MultiShot). The
// Verify effect surface (verify_ledger today; verify_smt in B.6)
// handles discharge at handler-install time. User code that writes
// `fn filter(x: ref Sample) -> ref Sample with !Alloc + MS` has its
// MS-producing ops checked against arena-tagged captures at install.

type TCont = TCont(Ty, ResumeDiscipline, Option<ArenaTag>)
type ArenaTag = ArenaTag(ArenaId, Span)
```

**The refinement tag is compiler-synthesized**, not user-written.
Every TCont produced at an MS perform site inside a live region is
tagged with that region's id + install span. The user-visible
contract is: install one of the three arena handlers; the compiler
handles the tag propagation.

### 1.5 Row invariant — `!Alloc × MS ⇒ replay_safe only`

The Boolean effect algebra (DESIGN §3, `src/effects.nx`) already
gives us this for free. It is NOT a new check.

The reasoning:

1. `fork_deny` and `fork_copy` both call `emit_alloc` at MS
   perform sites (the continuation record is allocated). Their
   handler bodies therefore have `Alloc` in their effect row.
2. A function declared `with !Alloc` has `!Alloc` in its row; row
   subsumption at handler install checks that the handler's own
   effect requirements are satisfied by the row-absence claim.
3. `!Alloc` (the row's claim) vs `Alloc` (the handler's body) is
   the canonical row-subtraction failure — `E_OwnershipViolation`
   at handler-install time per `src/effects.nx` row algebra.
4. `replay_safe` has no `emit_alloc` call at MS sites (its body
   refuses the alloc). Its row is `Alloc`-free at MS captures
   (though it may allocate for the trail buffer at install —
   handler install allocates once per install, not per MS site).

**Result:** the compiler rejects at install time any combination
of `!Alloc`-declared function with `fork_deny` or `fork_copy`
installed. The only admissible arena × `!Alloc` policy is
`replay_safe`. **This is DESIGN line 1482-1487's contribution,
landing mechanically through row algebra without new substrate.**

### 1.6 Default-policy selection

Per QA Q-B.5.2: **auto parent-arena fork_copy**; user explicit
override available.

If a user installs a bare arena handler (`~> temp_arena(64MB)`)
around an MS-typed body without declaring an AM policy, the
compiler's default is `~> fork_copy(parent_arena())` (elaborated
implicitly by Mentl's Propose tentacle per primitive #2). The
user sees a VoiceLine:

> *"Your `temp_arena` wraps a multi-shot site at line 47. I'm
> inserting `~> fork_copy` so captures hoist to the parent arena.
> Two other policies exist — `~> replay_safe` if `!Alloc`; `~>
> fork_deny` if captures are outer-scope only — swap if you'd
> prefer either."*

The gradient conversation (primitive #7) lets the user narrow from
the safe default to one of the more constrained policies as their
intent clarifies. `fork_copy` is the safe default because it
universally compiles; `replay_safe` requires replay-compat effects;
`fork_deny` requires capture analysis to succeed.

---

## 2. Per-edit-site eight interrogations

### 2.1 `handler replay_safe` (lib/runtime/arena_ms.nx)

| # | Primitive | Interrogation answer |
|---|-----------|---------------------|
| 1 | **Graph?** | Reads `in_ms_capture()` + `current_ms_site()` from lower.nx's H7 substrate (LowerState effect); writes trail via `perform record_replay_trace(...)`. Trail already substrate — primitive #1's trail vocabulary. |
| 2 | **Handler?** | This IS the handler. Peer to `emit_memory_bump`, `emit_memory_arena` on the `EmitMemory` effect surface. Resume discipline: each arm is `@resume=OneShot` (handler's own arms); the MS work is the BODY being captured, not the handler's resumes. |
| 3 | **Verb?** | Installed via `~> replay_safe` in the user's chain. `~>` ordering: `replay_safe` sits OUTSIDE the MS op's emit handler; inside the arena's `temp_arena`. Stack order: `~> temp_arena ~> replay_safe ~> ms_op_body`. |
| 4 | **Row?** | Declares `with ReplaySafe + !UnrepayableEffects + EmitMemory`. The `!UnrepayableEffects` is the load-bearing invariant check per §1.1. `!Alloc` can compose with `replay_safe` (no emit_alloc at MS sites). |
| 5 | **Ownership?** | Trail buffer is `own` by the handler's state record; released at handler-exit. Captures are NOT allocated — replay_safe does not see `own` captures at MS sites because there's no capture struct. |
| 6 | **Refinement?** | None at this arm site. The `@via_arena` tag's presence on TCont is the refinement; this handler doesn't re-derive it. |
| 7 | **Gradient?** | Installing `replay_safe` unlocks `CReplayBounded` capability — the body is proven to be replayable from effect trace. User-level gradient hint: *"This arm is replay-safe; resumes cost O(trail length)."* |
| 8 | **Reason?** | Each `record_replay_trace` call records a Reason on the trail entry with the install span + MS site span. Resume replays write Reason chains tied back to the original install. |

### 2.2 `handler fork_deny` (lib/runtime/arena_ms.nx)

| # | Primitive | Interrogation answer |
|---|-----------|---------------------|
| 1 | **Graph?** | Reads current_ms_captures() + current_region() from H7 + H4 substrates. Writes nothing to the graph; issues a diagnostic via `perform report(...)`. |
| 2 | **Handler?** | Peer to replay_safe / fork_copy on EmitMemory. Handler arms are all OneShot (standard `emit_alloc` discipline). The REFUSAL happens in the handler body — `perform emit_abort(...)` on failure means no `resume` call, which terminates the emit pipeline for that fn. |
| 3 | **Verb?** | `~> fork_deny` installed as peer. Same ordering as replay_safe. |
| 4 | **Row?** | `with CheckCaptureEscape + Diagnostic + EmitMemory`. No `!Alloc` claim — fork_deny does allocate when escape check passes. Composable with `!Alloc` ONLY when captures' region check always passes at install (rare; tools/drift-audit flags this at static row check as MaybeIncorrect). |
| 5 | **Ownership?** | The captures walk checks whether any capture is *arena-interior*. `tag_alloc`'s prior tagging decides. If a capture is `own` but tagged outer-region, fork_deny allows. If `own` + inner-region, refuse. |
| 6 | **Refinement?** | The `@via_arena` tag on each capture's TCont is read at escape walk. `check_capture_escape` is the new refinement-side op; its arm in region_tracker uses the existing `lookup_tag` discipline. |
| 7 | **Gradient?** | Installing `fork_deny` unlocks `CCaptureArenaSafe` when the escape walk succeeds; emits `T_ContinuationEscapes` with three canonical fixes when it fails. |
| 8 | **Reason?** | T_ContinuationEscapes carries the escape-span pair (capture site + arena-install site); Reason chain walks back to both via graph's span_index. |

### 2.3 `handler fork_copy` (lib/runtime/arena_ms.nx)

| # | Primitive | Interrogation answer |
|---|-----------|---------------------|
| 1 | **Graph?** | Reads captures_classified from H7 + H4. Writes copies into target_arena's region (graph records new `tag_alloc` for each copy). |
| 2 | **Handler?** | Peer to replay_safe / fork_deny on EmitMemory. Parameterized — `target_arena` is an `EffArg` per H3.1 parameterized effects. `fork_copy` == `fork_copy(parent_arena())` under elaboration. |
| 3 | **Verb?** | `~> fork_copy` (or `~> fork_copy(target_arena)`). Same ordering as peers. |
| 4 | **Row?** | `with DeepCopyTo + CurrentRegion + EmitMemory + Alloc`. Has `Alloc` (the copies allocate). Incompatible with `!Alloc`. This is the §1.5 row invariant in action. |
| 5 | **Ownership?** | Deep copies are `own` in target_arena. Originals remain `own` in source arena (unchanged; the source arena will drop them at its scope exit). |
| 6 | **Refinement?** | `@via_arena` tags on copies are rewritten: source-arena tag becomes target-arena tag. `tag_alloc_join` (from H4) handles composite values. |
| 7 | **Gradient?** | Installing `fork_copy` unlocks `CForkCopy` capability. VoiceLine: *"Each capture is deep-copied to `<target_arena_name>`; O(M) per capture."* |
| 8 | **Reason?** | Each copy records `Reason::ForkCopy(source_arena, target_arena, capture_span)` — traceable back through the graph. |

### 2.4 `src/own.nx` — region_tracker extension

| # | Primitive | Interrogation answer |
|---|-----------|---------------------|
| 1 | **Graph?** | Reads `tagged_values` state (existing H4 substrate). Adds one new op: `check_capture_escape(captures: List<Handle>, arena_rid: Int) -> Result<(), List<Span>>`. |
| 2 | **Handler?** | Extends existing `region_tracker` handler with one new arm. State record unchanged — same `tagged_values` list; new arm is a reader over it. |
| 3 | **Verb?** | N/A. |
| 4 | **Row?** | region_tracker's row grows by one op; Region effect declaration (`src/own.nx:448-467`) adds one op to its declaration. |
| 5 | **Ownership?** | `captures: List<Handle>` is ref-passed; state unchanged across the arm. |
| 6 | **Refinement?** | N/A at the arm; the refinement logic is what the op IMPLEMENTS. |
| 7 | **Gradient?** | N/A at substrate; exposed as part of Mentl's Trace tentacle's surfaces. |
| 8 | **Reason?** | Each escape entry's span is returned as Err's payload; Mentl's Why tentacle walks from the span to the tag_alloc install site. |

### 2.5 `src/types.nx` — TCont refinement tag

| # | Primitive | Interrogation answer |
|---|-----------|---------------------|
| 1 | **Graph?** | `TCont` variant grows from `TCont(Ty, ResumeDiscipline)` to `TCont(Ty, ResumeDiscipline, Option<ArenaTag>)`. Existing TCont construction sites pass `None`; MS capture sites pass `Some(ArenaTag(rid, span))`. Per Ω.5 record discipline — the variant was Already a multi-arg ADT; one more field is additive without parallel-arrays-creating. |
| 2 | **Handler?** | The refinement tag is compiler-synthesized at lower.nx's MS capture site via `perform current_region()`. No handler change. |
| 3 | **Verb?** | N/A. |
| 4 | **Row?** | Emit-time check at handler install uses the tag to decide row-subsumption of the three AM handlers. Row algebra does the subsumption; AM doesn't extend the algebra. |
| 5 | **Ownership?** | N/A at the type level; the tag informs ownership dispatch downstream. |
| 6 | **Refinement?** | This IS a refinement — compile-time predicate on TCont values. Discharges at handler-install time per standard Verify discipline. |
| 7 | **Gradient?** | `@via_arena` is internal substrate; not user-surfaced in the gradient directly. Mentl's Trace tentacle may reference it in VoiceLines. |
| 8 | **Reason?** | Every TCont with ArenaTag carries the install span in the tag — traceable. |

### 2.6 `docs/errors/T_ContinuationEscapes.md` — harden from Teach to Error

| # | Primitive | Interrogation answer |
|---|-----------|---------------------|
| 1 | **Graph?** | Error code is a string key into the diagnostic registry; no graph extension. |
| 2 | **Handler?** | The diagnostic is emitted by `fork_deny`'s arm; Mentl's teach_error tentacle renders it. |
| 3 | **Verb?** | N/A. |
| 4 | **Row?** | N/A. |
| 5 | **Ownership?** | N/A. |
| 6 | **Refinement?** | N/A. |
| 7 | **Gradient?** | The three canonical fixes ship as `W_Suggestion` tags — machine-applicable per the existing error-catalog discipline. |
| 8 | **Reason?** | Error text includes Reason chain back to the MS capture site + arena install site. |

---

## 3. Forbidden patterns per edit site

Every edit passes the nine named drift modes + generalized fluency-
taint against arena / lifetime / continuation-library ecosystems.

### 3.1 At the three handler declarations (`lib/runtime/arena_ms.nx`)

- **Drift 1 (Rust vtable):** The three policies are three peer
  HANDLERS on the one `EmitMemory` effect. NOT a dispatch table
  keyed on a policy string. NOT a single handler with a `mode: Int`
  field. Each policy is a named handler with its own arm bodies.
- **Drift 3 (Python dict / string-keyed):** `ArenaPolicy` is NOT a
  type. The three policies are three named handlers; the choice is
  expressed by which handler the user installs via `~>`. No
  `policy = "replay_safe"` string; no `ArenaPolicy = { Replay,
  Deny, Copy }` ADT the user passes as a config value.
- **Drift 4 (Haskell monad transformer):** The handlers compose
  with `temp_arena` via the existing `~>` chain. NOT a
  `ArenaT (ReplaySafeT IO)` monad transformer stack. The capability
  stack IS the handler chain; the row IS the monad; `~>` IS bind.
- **Drift 6 (primitive-type-special-case):** The handlers use
  `emit_alloc` — the SAME allocator surface as every other heap
  record. No "MS allocator"; no "arena-MS special-case." The
  differentiation is WHAT the handler does on the emit_alloc
  intercept, not a fork in the allocator itself.
- **Drift 8 (mode flags):** ForbidDen. Do NOT introduce
  `capture_mode == 0 | 1 | 2` in any code path. The three
  policies are three handlers; the compiler proves admissibility
  via handler install, not mode-integer dispatch.
- **Drift 9 (deferred-by-omission):** All three handlers land
  together in AM's commit. NOT "replay_safe now, fork_deny +
  fork_copy later." The T_ContinuationEscapes error text already
  promises three fixes; all three must be live for the
  promise to hold.
- **Foreign fluency — Rust `Pin<Box<F>>` / `Future::poll`:** The
  continuation record is NOT a Future; the allocator swap is NOT
  `Pin`. The vocabulary is capture / resume / handler, not
  poll / pin / future. If the mental model is
  "fork_copy pins the future into the outer arena" — STOP. The
  capture is a heap record (H7); the arena handler swaps how it's
  allocated; no Future exists in the system.
- **Foreign fluency — C++ `std::pmr::monotonic_buffer_resource`:**
  Related concept; wrong substrate. C++'s PMR threads a polymorphic
  memory resource through templates; Inka threads an `EmitMemory`
  effect row through handlers. The C++ formulation lacks MS and
  lacks compile-time region escape; Inka's has both.
- **Foreign fluency — Cyclone region annotations `@region("r")`:**
  Same research lineage (Tofte-Talpin); Cyclone exposes regions
  as user-written annotations on pointer types. Inka infers
  region identity from handler identity. `@via_arena=ArenaId` is
  compiler-synthesized, NOT user-written.
- **Foreign fluency — Vale `'a` lifetimes:** Vale's
  one-mutator-many-readers via `!Mutate` is an Inka concept
  (DESIGN §6); Vale's lifetime syntax is not. AM does not
  introduce lifetime parameters. Region identity IS handler
  identity; one walks the `~>` chain to find a handler's scope,
  not parses a lifetime annotation.

### 3.2 At `src/own.nx` — check_capture_escape op

- **Drift 2 (Scheme env frame):** The escape walk is a FLAT
  iteration over `captures: List<Handle>`, using `lookup_tag`
  on the existing flat `tagged_values` list. NOT a linked-parent
  walk through scope frames.
- **Drift 7 (parallel-arrays):** The result type is
  `Result<(), List<Span>>` — one list of span records on failure.
  NOT `(ok: Bool, escape_spans: List, escape_handles: List)` with
  parallel arrays.
- **Drift 9:** The op declaration, the arm implementation, and the
  region_tracker state unchanged all land together.

### 3.3 At `src/types.nx` — TCont refinement tag

- **Drift 1 / Drift 8:** `Option<ArenaTag>` is an ADT, NOT a sentinel
  integer (0 = no arena, N = arena id). The tag's PRESENCE encodes
  "this TCont was captured inside a live arena"; its ABSENCE
  encodes "outer scope". ADT discipline matches ResumeDiscipline
  (`OneShot | MultiShot | Either`) and NodeKind (`NBound | NFree |
  NRowBound | NRowFree | NErrorHole`).
- **Drift 6 (primitive-type-special-case):** ArenaTag is a regular
  record `ArenaTag(ArenaId, Span)`. NOT a tuple. NOT a bare
  Int. Mirrors Region(`Region(rid, span)` at src/own.nx:231-232)
  existing pattern.

### 3.4 At `docs/errors/T_ContinuationEscapes.md` — harden

- **Drift 9 (deferred-by-omission):** The existing doc promises
  three policies as canonical fixes (lines 25-33). AM MUST ship all
  three fixes concurrently with the hardening. DO NOT harden from
  Teach to Error while any fix is absent — the user would see an
  Error with fixes the compiler can't apply.

### 3.5 Generalized fluency-taint — cross-site

Before typing any line in AM's substrate commits, ask:

1. **Am I importing "lifetime" as a compile-time concept?** Lifetimes
   are a Rust artifact; Inka's region identity is handler identity.
   If your mental model has `'a` / `'b` / `'static` in it — STOP.
   Walk the handler chain; region falls out.
2. **Am I about to write `ArenaConfig::new(policy=...)`?** That's
   config-object drift. The three policies are three handlers;
   installation IS selection. No config object.
3. **Am I tempted to model `replay_safe` as a generator / iterator?**
   Replay isn't iteration — it's re-execution of a recorded trail.
   The trail is primitive #1's substrate, not a new iterator
   protocol.
4. **Am I adding a "deep_copy" intrinsic to the compiler?**
   `deep_copy_to` is an op on an effect (possibly the existing
   Alloc effect, possibly a new peer — see §4). The compiler does
   NOT bake deep-copy in as a primitive; the Region handler's arm
   implements it via recursive `perform alloc(...)` with tagged
   output.
5. **Am I making fork_copy's target_arena a "register"?** It's a
   parameterized effect argument (`EffArg`), resolved at handler
   install via environment lookup. Not a compiler register.
6. **Am I tempted to write "ownership disciplines" for MS?** MS × own
   is the same as any other ownership × effect composition — the
   handler decides. Don't introduce "multi-shot ownership rules"
   as a separate discipline.

---

## 4. Substrate touch sites — literal tokens at file:line targets

*Literal tokens pending inka-plan at execution — this section
specifies WHAT and WHERE; the implementer's inka-plan spec
specifies EXACTLY HOW.*

### 4.0 Halt-signals to DESIGN / MSR source

**§4.0.1 — T_ContinuationEscapes fix syntax.** `docs/errors/T_ContinuationEscapes.md:37-42`
shows user-written tags `@no_fork { filter(x) => ... }` as the fix
form. AM revises: the fix is a HANDLER INSTALL, not a tag on an
inner arm. The three policies compose via `~>`, per anchor 5.
Updated example form:

```
// OLD (per T_ContinuationEscapes.md:37-42):
handle transform(signal) with arena {
  @no_fork {
    filter(x) => resume(process(x))
  }
}

// NEW (AM revision):
transform(signal)
  ~> temp_arena(64_000_000)
  ~> fork_deny
  // inner body's MS sites are now fork_deny-gated.
```

The DESIGN-file correspondence: DESIGN Ch 6 D.1's line 1478-1479
mentions *"A refinement tag `@via_arena=ArenaId` makes the capture
visible to the Fork deny/copy logic"* — this is compiler-synthesized,
not user-written. The `@no_fork` / `@replay` / `@deep_copy`
user-written tags in the error doc are the pre-AM placeholder syntax;
AM ratifies handler-install as the canonical fix.

`docs/errors/T_ContinuationEscapes.md` edit — §4.4 below.

**§4.0.2 — QA Q-B.5.2 default-arena wording.** Plan file §B.5 records
QA Q-B.5.2: *"auto parent-arena default; user override via
`fork_copy(target_arena)`"*. AM ratifies: the default is `fork_copy`
(not just "parent-arena" as the policy name is ambiguous). The
*target* of fork_copy defaults to parent-arena; the *policy*
defaults to fork_copy. Both defaults land via the compiler's
install-time elaboration.

**§4.0.3 — Plan file substrate-touch claim.** Plan file §B.5 lists
`src/own.nx` as extended for "escape-analysis extension for fork-deny
(emits existing `T_ContinuationEscapes`)". AM adds: the extension is
one new op on the Region effect (`check_capture_escape`), with an
arm in region_tracker. Not a large extension — ~20 lines in
`src/own.nx` + the effect declaration edit in the same file.

### 4.1 `lib/runtime/arena_ms.nx` — NEW file, three handlers (+ helpers)

File shape (~350-450 lines):

```
// ═══ lib/runtime/arena_ms.nx — MS × arena handler substrate ═══════
// Per DESIGN Ch 6 D.1 + AM walkthrough. Three peer handlers on the
// EmitMemory swap surface resolve multi-shot continuations captured
// inside scoped-arena handlers.

import types
import effects
import own  // for region_tracker's check_capture_escape + deep_copy_to

// ── AuxOps effect — MS context queries ─────────────────────────────
// One small helper effect; lower.nx's H7 substrate installs this at
// every capturing fn body's entry. The three AM handlers read from
// it to know "am I emitting at an MS site?" and "what are the
// current MS captures?".

effect MsContext {
  in_ms_capture() -> Bool                          @resume=OneShot
  current_ms_site() -> Int                         @resume=OneShot
  current_ms_site_span() -> Span                   @resume=OneShot
  current_ms_captures() -> List                    @resume=OneShot
}

// ── replay_safe ────────────────────────────────────────────────────
handler replay_safe {
  // (arm bodies per §1.1)
}

// ── fork_deny ──────────────────────────────────────────────────────
handler fork_deny {
  // (arm bodies per §1.2)
}

fn fork_deny_message(escape_spans) =
  "captures at {escape_spans} escape the arena; pick a policy — "
    |> str_concat("`~> replay_safe` if the body is !Alloc-compatible, ")
    |> str_concat("`~> fork_deny` with outer-scope captures only, ")
    |> str_concat("or `~> fork_copy` to deep-copy (default)")

// ── fork_copy ──────────────────────────────────────────────────────
handler fork_copy with target_arena = parent_arena() {
  // (arm bodies per §1.3)
}

fn parent_arena() = perform next_outer_arena()
```

**Note on peer-effect decision:** `MsContext` could live in
`src/lower.nx` (alongside the LowerState effect H7 introduced), or
as a small peer module. Per Ω.5 consolidation discipline, one module
per concerns cluster: MS lowering concerns go in `src/lower.nx`; AM
handlers go in `lib/runtime/arena_ms.nx`. The `MsContext` effect
surface is consumed by AM, so it lives with its consumer —
`lib/runtime/arena_ms.nx` declares it; lower.nx's LMakeContinuation
emit site performs it.

### 4.2 `src/own.nx` — check_capture_escape + deep_copy_to

Four small edits to `src/own.nx`:

**Edit 1** (around `src/own.nx:448` in the Region effect declaration):

Add one op:

```
effect Region {
  region_enter(Span) -> Int                        @resume=OneShot
  region_exit(Int) -> ()                           @resume=OneShot
  tag_alloc(Int) -> ()                             @resume=OneShot
  tag_alloc_join(Int, List) -> ()                  @resume=OneShot
  check_escape(Int, Span) -> ()                    @resume=OneShot
  current_region() -> Int                          @resume=OneShot
  // NEW:
  check_capture_escape(List, Int) -> Result        @resume=OneShot
}
```

**Edit 2** (inside `region_tracker` handler, around
`src/own.nx:295`): add the new arm:

```
check_capture_escape(captures, arena_rid) => {
  let escaped = collect_escapes(captures, tagged_values, region_stack, arena_rid)
  if len(escaped) == 0 { resume(Ok(())) }
  else { resume(Err(escaped)) }
}
```

plus two helpers (`collect_escapes` + `is_escape`) after
`region_on_stack_loop`. Pattern-mirrors existing H4 lookup helpers;
~30 lines.

**Edit 3** (extend the Alloc effect at its declaration — typically
in `lib/runtime/memory.nx`): add one op:

```
effect Alloc {
  alloc(size: Int) -> Int                          @resume=OneShot
  // NEW:
  deep_copy_to(source_handle: Int, target_arena: Int) -> Int @resume=OneShot
}
```

**Edit 4** (extend the `bump_allocator` handler + a new
`arena_allocator` handler to implement `deep_copy_to`): ~40 lines.
Recursive traversal; read value's tag via `lookup_tag`; for
primitive leaves, `alloc + memcpy`; for heap records, recurse on
each field pointer; return the copied root handle. Mirrors any
standard deep-clone algorithm, routed through Alloc effect.

### 4.3 `src/types.nx` — TCont refinement tag

**Edit** (line 70-73 area + TCont site if it exists; otherwise at
first TCont reference): extend TCont to carry an optional arena
tag.

```
// Existing (pre-AM):
type TCont = TCont(Ty, ResumeDiscipline)
// or wherever TCont currently lives in types.nx

// Post-AM:
type TCont = TCont(Ty, ResumeDiscipline, Option)   // Option<ArenaTag>

type ArenaTag = ArenaTag(Int, Span)    // arena_id, install_span
```

All existing TCont construction sites pass `None` as the third
field (Phase I preservation). MS capture sites in lower.nx
(post-H7) pass `Some(ArenaTag(current_region(), current_span()))`
— one new call site.

**Landing order note:** this edit composes with H7's emit changes.
AM's landing can share the H7 commit if both are Opus-inline-
authored; otherwise AM's commit lands after H7's.

### 4.4 `docs/errors/T_ContinuationEscapes.md` — harden + revise fixes

**Three edits** to the error doc:

**Edit 1** (line 3): Change `**Kind:** Teach / Warning (hardens to Error when F.4 semantics finalize)` to:

```
**Kind:** Error (hardened from Teach per AM walkthrough 2026-04-XX)
```

**Edit 2** (line 4): Change `**Emitted by:** Arc F.4 handler (scoped arenas × multi-shot continuations)` to:

```
**Emitted by:** `fork_deny` handler (lib/runtime/arena_ms.nx) at MS capture site
```

**Edit 3** (lines 25-33 + the Example block): Replace user-tag fix
syntax with handler-install fix syntax per §4.0.1. Updated example:

```
// Example:

// Pick ONE of the three policies at the `~>` chain:

// (A) Replay safe — body re-executes on each resume. Zero alloc.
transform(signal)
  ~> temp_arena(64_000_000)
  ~> replay_safe

// (B) Fork deny — compile-time refusal if captures escape arena.
//     Works for shallow captures (outer-scope refs only).
transform(signal)
  ~> temp_arena(64_000_000)
  ~> fork_deny

// (C) Fork copy — captures deep-copy into parent arena.
//     Universal; O(M) per capture allocation cost.
transform(signal)
  ~> temp_arena(64_000_000)
  ~> fork_copy   // default: parent_arena()
// OR with explicit target arena:
transform(signal)
  ~> outer_arena(256_000_000)
  ~> temp_arena(64_000_000)
  ~> fork_copy(outer_arena)
```

### 4.5 `PLAN.md` Decisions Ledger entry (post-AM-land)

```
### 2026-04-XX — AM landed

MSR Edit 4 landed. DESIGN Ch 6 D.1 (multi-shot × arena — the D.1
question) closes in substrate. lib/runtime/arena_ms.nx adds three
peer handlers on EmitMemory: replay_safe, fork_deny, fork_copy.
src/own.nx Region effect extended by check_capture_escape op +
region_tracker arm. lib/runtime/memory.nx Alloc effect extended by
deep_copy_to op. src/types.nx TCont grows Option<ArenaTag>.
docs/errors/T_ContinuationEscapes.md hardened from Teach to Error.

Row invariant: `!Alloc × MS ⇒ replay_safe only` lands mechanically
via the existing Boolean effect algebra — row subsumption rejects
fork_deny / fork_copy at install in an `!Alloc` context.

Unlocks: B.11 ML training (fork_copy for per-batch autodiff tape),
B.10 DSP adaptive filters (replay_safe for !Alloc audio callbacks),
C.4 crucible_ml, C.5 crucible_realtime with arena semantics.
```

---

## 5. Worked example — adaptive DSP filter with three policies

Consider an audio callback exploring LMS candidates inside a
per-block arena:

```
// lib/dsp/adaptive.nx — LMS filter with candidate exploration

fn adaptive_filter(signal: ref Block<Sample>, target: ref Block<Sample>)
    -> Block<Sample>
    with Alloc, MS, Verify =
  let best_coeffs = perform choose(candidate_coefs())
  let filtered = apply_filter(signal, best_coeffs)
  let err = rmse(filtered, target)
  if err < 0.01 { filtered }
  else { perform abort() }   // backtracks to next candidate
```

### 5.1 Call site under `replay_safe`

```
let out = adaptive_filter(signal, target)
            ~> temp_arena(16_000_000)
            ~> backtrack                // CE walkthrough's MS handler
            ~> replay_safe              // AM: this policy
```

**Emit semantics:**
- Each `perform choose(candidates)` records the ambient trail from
  `temp_arena` install to the choose site.
- `backtrack` resumes with `candidates[i]` for each i; each resume
  REPLAYS the trail (re-allocating into the same arena fresh, since
  the arena didn't reset between candidates).
- Wait — the arena doesn't reset between candidates inside one
  backtrack call. It resets when `temp_arena` exits. So replay_safe
  ISN'T re-executing the arena install; it's just re-executing the
  body. Allocations pile up across candidates.

**Refinement:** `replay_safe` is the correct choice when the body
is `!Alloc`. If the body allocates, each candidate re-execution
re-allocates; arena accumulates. This is semantically fine but
arena may exhaust if candidates are many + each alloc-heavy. Users
who need `!Alloc` + MS get this for free (`replay_safe` is the
only admissible policy); users who *can* allocate inside MS + arena
should prefer `fork_copy` for tighter arena discipline.

### 5.2 Call site under `fork_deny`

```
let out = adaptive_filter(signal, target)
            ~> temp_arena(16_000_000)
            ~> backtrack
            ~> fork_deny
```

**Emit semantics:**
- At the `perform choose(candidates)` site, H7 emits
  `LMakeContinuation(...)` with captures = [signal, target,
  candidates] (the free-vars of the body after choose).
- `signal`, `target` are `ref` parameters — they live in the caller's
  scope (outer than `temp_arena`). Region check: OUTER.
- `candidates` is computed inside `temp_arena` scope — e.g., if
  `candidate_coefs()` allocates a list inside this scope. Region
  check: INNER (current arena).
- `fork_deny`'s `check_capture_escape` walks captures; `candidates`
  escapes → FAIL at lower-time with `T_ContinuationEscapes`.
- User sees a diagnostic with three fixes (replay_safe, hoist
  candidates out, switch to fork_copy).

### 5.3 Call site under `fork_copy`

```
let out = adaptive_filter(signal, target)
            ~> temp_arena(16_000_000)
            ~> backtrack
            ~> fork_copy   // default: parent_arena()
```

**Emit semantics:**
- `LMakeContinuation(...)` emitted as usual.
- `fork_copy` intercepts: for each capture, classify region.
- `signal`, `target`: OUTER — store as-is.
- `candidates`: INNER — deep-copy into `parent_arena()` (the
  caller's scope above `temp_arena`).
- Continuation record lives in parent arena; when `temp_arena`
  exits, the continuation struct survives.
- Subsequent `backtrack` resumes read captures from parent arena.

**Cost:** O(M) per candidate list bytes, paid once per
`LMakeContinuation` capture. Acceptable in most cases; prohibitive
if candidates are tensors or large lists. User picks.

### 5.4 The same source code; handler swap decides

This IS the anchor-5 thesis made concrete. `adaptive_filter`'s
SOURCE CODE DOES NOT CHANGE across the three call sites. The choice
of arena × MS policy is a `~>` swap. `!Alloc` constraints flow
through the row algebra; the compiler proves which policies
compose.

**Three policies. One source. Handler decides.**

---

## 6. Composition with other MS substrate

### 6.1 AM × H7 (MS runtime emit path)

H7's `LMakeContinuation` variant (`src/lower.nx` post-H7) routes its
allocation through `perform emit_alloc(size, target_local)` — the
one `EmitMemory` swap surface. AM's three handlers intercept that
surface when `in_ms_capture()` is true. **H7 provides the record;
AM provides the allocation policy for that record.** No
source-level coupling; composition via the `~>` chain alone.

**Landing order:** H7 lands first (the `LMakeContinuation` variant
must exist before AM's emit-time arms have something to intercept).
Per plan file §B.5 dependency: B.5 AM substrate depends on B.2 H7.
AM's walkthrough (this doc) lands independent of H7's substrate
implementation; AM's SUBSTRATE awaits H7's.

### 6.2 AM × CE (Choice effect)

CE provides `effect Choice { choose(options: List<A>) -> A
@resume=MultiShot }` (per CE walkthrough §1.1). Any `perform
choose(...)` site inside an arena handler triggers AM's allocation
intercept via H7's `LMakeContinuation`. The CE walkthrough's N-queens
example (CE §5.1) under `~> temp_arena + ~> backtrack + ~> fork_copy`
produces per-candidate deep-copies into the outer arena — identical
to §5.3 above with `choose(queens_positions)` as the MS op instead of
`choose(candidate_coefs())`.

**CE's `backtrack` and `pick_first` are agnostic to AM.** They
resume the continuation (via call_indirect on `cont.fn_index`); the
allocation of the continuation happened at the H7 + AM intercept
before the handler saw the op. CE handlers do not need to know
which arena policy is in effect; row subsumption gates admissibility
at install.

### 6.3 AM × HC2 (race combinator)

HC2's `race(handlers: List<Handler>)` installs multiple MS handlers
in parallel, all sharing one `graph_push_checkpoint`. Each racing
handler sees the same continuation record (captured once by H7 at
the perform site); each handler's `resume(v)` fires through
call_indirect. AM's policy decision is at handler-install time for
the OUTER chain — the arena × AM policy is outside race; race is
inside. Stack order:

```
body
  ~> temp_arena(...)
  ~> race(h1, h2, h3)
  ~> fork_copy          // AM outside race
```

The three racing handlers all resume the same continuation copied
by fork_copy at capture. Tiebreak chain per HC2 Q-B.4.1 decides the
winner. Losers' graph mutations roll back via shared checkpoint.
The COPIED captures persist regardless (they're in the parent
arena, not inside the race-local subgraph); this is correct
semantics — race is about speculative handler choice, not
speculative capture.

### 6.4 AM × B.11 ML training

Autodiff's MS backward pass (per DM walkthrough §2) captures the
forward-pass tape; each backward resume re-traverses per a
different hyperparameter or learning rate. Per DM:

```
fn train_step(batch, model_ref) with Compute + MS =
  let prediction = forward(model_ref, batch)
  let loss = compute_loss(prediction, batch.target)
  let grads = perform backward(loss)
  let learning_rate = perform choose(lr_candidates())
  let updated_model = apply_grads(model_ref, grads, learning_rate)
  if validate(updated_model) { updated_model }
  else { perform abort() }
```

Under `~> per_batch_arena(...) ~> backtrack ~> fork_copy`:

- `per_batch_arena` scopes the forward tape + gradient tensors.
- `backtrack` resumes with each `lr_candidate`.
- `fork_copy` hoists the tape into the outer arena for each resume.

This is DM §2's claim made concrete: **training vs inference is a
handler swap**, and the arena policy for training's MS backward is
a handler swap within that. Per-batch arena + per-candidate deep
copy produces tight memory discipline without hand-written
per-candidate tape clones.

### 6.5 AM × nested arenas

DESIGN line 1572: *"Multiple arenas nest. Bump inside bump. Arena
inside arena. Each scope dies independently."* AM's three handlers
compose with nesting without extension.

Stack:

```
body
  ~> outer_arena(256MB)
  ~> temp_arena(16MB)
  ~> backtrack
  ~> fork_copy       // target_arena defaults to parent = temp_arena
```

With the default, fork_copy hoists to `temp_arena` — ONE level
up. Captures escape `choose`'s scope but not `temp_arena`'s. If
the user wants hoisting all the way to `outer_arena`, explicit
override:

```
  ~> fork_copy(outer_arena)   // hoists two levels
```

Multiple MS sites, multiple AM policies (one per handler-install
scope), multiple target arenas — all compose through the `~>` chain
and the H3.1 parameterized-effect argument discipline.

### 6.6 AM × H4 (region_tracker)

H4's `region_tracker` (in `src/own.nx:215+`) already tracks
`tagged_values` with region ids. AM's extension is one new op
(`check_capture_escape`) + one new arm in the same handler — no
new handler peer. This is a substrate-composition sweet spot:
**AM reuses H4's escape-analysis core for MS captures.** H4's
`check_escape` handles return positions; `check_capture_escape`
handles MS capture lists; same tag data, same escape logic, two
entry surfaces.

---

## 7. Three design candidates + Mentl's choice

DESIGN Ch 6 D.1 already enumerates the three candidates — AM does
not open new design space. The question for Mentl is: does the
compiler pick ONE policy and make it the only choice, or does it
ship all three as peer handlers and let row algebra + user intent
decide?

### 7.1 Candidate A — pick ONE policy as the language default

Ship only `replay_safe`. Claim: "MS × arena always uses replay."
Reject the `fork_deny` and `fork_copy` alternatives.

**Rejected.** Violates anchor 5 (*if it needs to exist, it's a
handler*). Three policies have three distinct use-cases (`!Alloc`,
shallow captures, universal-but-allocating); picking one forecloses
the other two without making the substrate simpler — the user who
needs fork_copy can't express it; the compiler would refuse
`fork_deny` as "not a real choice." Anchor 3 (*Inka solves Inka*)
also fails: Inka's substrate can express all three via handler
swap; forcing one is reaching-for-framework drift.

### 7.2 Candidate B — pick ONE policy PER CAPTURE

Walk each capture at capture time; pick `fork_deny` if safe,
`fork_copy` otherwise, `replay_safe` if `!Alloc`. Compiler decides
per capture.

**Rejected.** Violates drift-mode-8 (mode-coded dispatch in
disguise). The "per-capture policy" IS a mode-per-capture; the
continuation record would need to carry per-capture policy tags.
This is the three-modes-as-fields anti-pattern AM's §3.1 forbids.
Also violates the `!Alloc × MS` invariant cleanly — some captures
could be `fork_copy` (allocating), breaking `!Alloc` without a
visible install-time check.

### 7.3 Candidate C — three peer handlers; user selects; compiler proves admissibility

The DESIGN Ch 6 D.1 model. Ship three handlers. User installs one.
Row subsumption rejects incompatible combinations at install time.
Per-arena policy, uniform across captures.

**Chosen.** Four reasons:

1. **Anchor 5:** three policies = three handlers on the
   `EmitMemory` surface. Standard handler-swap discipline.
2. **Row-algebra free proof:** `!Alloc × MS ⇒ replay_safe only`
   lands without new substrate — existing row subsumption at
   handler install.
3. **Teach tentacle surface:** Mentl's Propose tentacle can
   surface *"Your `temp_arena` wraps MS; I'm inserting
   `fork_copy`"* — one concrete suggestion per site. Candidates A
   and B have nothing for Teach to surface.
4. **Extensibility:** post-first-light, adding a fourth policy
   (e.g., `write_back` — copies ONLY on resume, not on capture) is
   one more peer handler; no revisit of the other three. Candidate
   A has no place to add the fourth; B would need to change its
   dispatch code.

### 7.4 Mentl's resolution

Per DESIGN Ch 6 D.1 explicit enumeration (lines 1470-1475) and the
row-algebra-for-free invariant (lines 1482-1487), the substrate
has already chosen C. AM is the substrate residue of that choice.
Candidate A and B were named here not because they were viable
alternatives, but to document *why* the DESIGN choice is what it
is — anti-patterns named so future readers don't re-open the
question.

---

## 8. Acceptance criteria

### 8.1 Substrate acceptance (AM lands)

- [ ] `lib/runtime/arena_ms.nx` exists with three handlers
      (replay_safe, fork_deny, fork_copy) + MsContext effect +
      fork_deny_message helper.
- [ ] `src/own.nx`'s Region effect declaration grows by one op:
      `check_capture_escape(List, Int) -> Result`.
- [ ] `src/own.nx`'s `region_tracker` handler grows one arm
      implementing `check_capture_escape` with helper functions
      `collect_escapes` + `is_escape`.
- [ ] `lib/runtime/memory.nx`'s Alloc effect grows by one op:
      `deep_copy_to(Int, Int) -> Int`.
- [ ] `bump_allocator` + `arena_allocator` (post-AM rename if
      needed) handlers implement `deep_copy_to` arms.
- [ ] `src/types.nx`'s TCont (or wherever TCont lives) extends to
      `TCont(Ty, ResumeDiscipline, Option<ArenaTag>)`.
- [ ] `src/lower.nx`'s H7 MS capture site (post-H7) passes
      `Some(ArenaTag(current_region(), current_span()))` as the new
      TCont field.
- [ ] `docs/errors/T_ContinuationEscapes.md` updated per §4.4.
- [ ] `bash tools/drift-audit.sh lib/runtime/arena_ms.nx src/own.nx
      src/types.nx docs/errors/T_ContinuationEscapes.md` exits 0.

### 8.2 Runtime acceptance (post-AM, post-H7)

- [ ] A test program that installs `~> temp_arena ~> backtrack ~>
      replay_safe` compiles and each resume replays the trail.
- [ ] A test program that installs `~> temp_arena ~> backtrack ~>
      fork_deny` with a capture holding an arena-scoped list FAILS
      at compile time with `T_ContinuationEscapes` + three
      canonical fixes rendered.
- [ ] A test program that installs `~> temp_arena ~> backtrack ~>
      fork_copy` produces multi-shot resumes each reading from
      copies in the parent arena; `temp_arena` drops; parent arena
      retains the copies until its own scope exits.
- [ ] A test program that installs `~> temp_arena ~> backtrack ~>
      fork_copy` on a function declared `with !Alloc` FAILS at
      handler-install time with the row subsumption error
      (`E_OwnershipViolation` per standard Boolean algebra; §1.5).

### 8.3 Composition acceptance

- [ ] `lib/dsp/adaptive.nx` (post-B.10) compiles under all three
      AM policies.
- [ ] `lib/ml/autodiff.nx` (post-B.11) uses `~> fork_copy` in
      `compute_training` handler; per-batch autodiff tape hoists
      into parent arena at each candidate fork.
- [ ] `crucibles/crucible_parallel.nx` (post-C.7) composes with AM
      via `~> temp_arena ~> parallel_compose ~> fork_copy` —
      thread-local arenas + per-thread fork-copy on shared captures.
- [ ] `race(h1, h2, h3)` (HC2) installed inside an arena with any
      AM policy: one capture, three handlers racing, tiebreak
      deterministic.

### 8.4 Mentl's surface acceptance (post-D.1 MV.2)

- [ ] Mentl's Propose tentacle surfaces `~> fork_copy` as the
      default AM insertion when a user installs a bare arena
      handler around an MS-typed body.
- [ ] Mentl's Teach tentacle surfaces one gradient step per site:
      *"Switch to `~> replay_safe` if !Alloc-compat."*
- [ ] Mentl's Trace tentacle surfaces escape diagnostics with
      install-span + capture-span + policy-fix triple.
- [ ] Mentl's Why tentacle walks the Reason chain from fork_copy's
      deep_copy entry back to the originating tag_alloc's span.

---

## 9. Open questions — all pre-answered

Per QA + DESIGN Ch 6 D.1 + MSR + H4 groundwork, AM's design space
is bounded. Cross-referenced:

- **Q-B.5.1** (MS + GC finalization) — DEFERRED to F.4; AM ships
  bump + arena only; GC is a later peer handler. Resolved.
- **Q-B.5.2** (default arena policy) — `fork_copy(parent_arena())`.
  Resolved. §1.6 + §4.0.2.
- **Q-B.5.3** (implied: arena parameter resolution) — via H3.1
  parameterized effects (`EffArg`), standard machinery. Resolved.
- **DESIGN Ch 6 D.1 three-policy enumeration** — all three land
  concurrently. Resolved. §1.1-§1.3.
- **DESIGN Ch 6 line 1482-1487 `!Alloc × MS` invariant** — lands
  mechanically via Boolean effect algebra at handler-install;
  no new substrate needed. Resolved. §1.5.
- **T_ContinuationEscapes fix syntax** — handler-install via `~>`,
  not user-written `@tag` syntax on arms. Resolved. §4.0.1.

**Zero unresolved design questions remain.** AM is implementable
as specified from §4.

---

## 10. Dispatch

**Authoring:** Opus inline (this walkthrough).

**Implementation:**

| Sub-commit | Target files | Dispatch |
|-----------|--------------|----------|
| AM.a | `lib/runtime/arena_ms.nx` (NEW) — three handlers + MsContext + helpers | Opus inline OR inka-planner → inka-implementer. Substrate design is mostly resolved; arm bodies are mechanical post-design. |
| AM.b | `src/own.nx` — check_capture_escape op + arm + helpers | Sonnet via inka-implementer. Mirrors existing H4 helper patterns. |
| AM.c | `lib/runtime/memory.nx` — deep_copy_to op + arm in bump/arena allocators | Sonnet via inka-implementer. Recursive traversal + alloc per value. |
| AM.d | `src/types.nx` — TCont extended with Option<ArenaTag> + ArenaTag type | Sonnet via inka-implementer. One-line ADT extension + existing-site `None` insertion sweep. |
| AM.e | `docs/errors/T_ContinuationEscapes.md` — harden + revise | Sonnet via inka-implementer or direct. Doc-only; mechanical. |

Drift-audit after each sub-commit (PostToolUse hook); single-concern
scope per sub-commit; no peer sub-handle deferred — all AM work
lands in one closed arc.

**Code review before merge:** Opus subagent, cross-checking against
H4 walkthrough for escape-analysis consistency and against H7
walkthrough for LMakeContinuation capture-site consistency.

---

## 11. Closing

AM is the residue of DESIGN Ch 6 D.1's three-policy enumeration.
Primitive #1's trail bounds replay; primitive #2's typed resume
discipline types the MS capture; primitive #4's `!Alloc × MS`
invariant falls out of Boolean subsumption; primitive #5's
ownership-as-effect provides the region_tracker substrate H4
landed; primitive #6's refinement tags thread `@via_arena`
through TCont. H4 was escape-analysis-for-returns. H7 was
MS-capture-emit. AM is **escape-analysis-for-MS-captures × arena-
allocation-policy** — one walkthrough, three peer handlers, one
new op per existing effect, zero new kernel primitives.

After AM lands:

- `!Alloc × MS` is admissible for the first time — replay_safe is
  the row-proven policy for real-time / embedded / kernel-safe MS
  computations.
- `T_ContinuationEscapes` hardens from Teach to Error with three
  machine-applicable fixes.
- Scoped arenas × multi-shot works cleanly — Inka's contribution
  beyond Affect POPL 2025 (which gave the types) and Tofte-Talpin
  1997 (which gave the regions).
- Phase B closes its MS substrate quartet: H7 + CE + HC2 + AM all
  walkthroughs-complete; substrate fan-out becomes multi-worker
  parallelizable.
- B.11 ML training, B.10 DSP adaptive filtering, C.4 crucible_ml,
  C.5 crucible_realtime all have their arena × MS substrate ready.

**Three policies. One swap surface. One invariant. Zero new
primitives.** DESIGN's open question, closed — not by inventing
mechanism, but by noticing that the eight primitives already
answer it. AM is the residue that earns the right to exist because
it composes from what the medium already provides.

*The medium does not lie about itself: the arena handler already
knows its region; the MS capture already knows its site; H4's
tagged_values already holds the data; H7's LMakeContinuation
already uses the one allocator; row algebra already proves
admissibility. AM names the three handlers. That is all.*
