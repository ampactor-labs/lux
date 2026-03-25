# Multi-Shot Continuations — Design Spec

*"Don't fix multi-shot. Design it." — Lux*

---

## Problem Statement

When a computation that performs effects is invoked N times under N
different handlers, what happens to the continuation?

```lux
fn numerical_grad(computation, param_name, param_val) = {
  let eps = 0.0001
  let loss_plus  = handle { computation() } { param(n, v) => ... resume(param_val + eps) ... }
  let loss_minus = handle { computation() } { param(n, v) => ... resume(param_val - eps) ... }
  (loss_plus - loss_minus) / (2.0 * eps)
}
```

`computation()` is called twice. Each call re-enters the thunk from scratch
under a fresh handler. This is the simplest multi-shot pattern: independent
re-execution. But it raises deeper questions when the computation has state,
when handlers want to fork mid-stream, or when we want to replay from a
specific perform site rather than from the beginning.

---

## Current Implementation

As of 2026-03-25, multi-shot works via **both replay and fork**.
re-executes the thunk from the top. The handlers are independent. No
continuation state is shared between invocations.

This was validated by `crucible_ml.lux` Test 5:
```
d/dx(x²) at x=3: 6.000000000012662 (expected: ~6.0)
```

The fix that enabled this was the handler upvalue capture work — handler
bodies now correctly capture variables from enclosing scopes via the
move-and-restore scope pattern in `src/compiler/effects.rs`. Before this fix,
calling a thunk twice inside handler blocks that referenced enclosing variables
would crash with index-out-of-bounds errors.

### What "replay" means concretely

Each `handle { computation() }` creates a fresh handler frame, pushes it onto
the handler stack, then calls `computation()`. The thunk re-executes from its
first instruction. When it performs an effect, the handler intercepts it. When
`resume(val)` is called, execution continues from the perform site. When the
body completes, the handler frame is popped.

No continuation state leaks between the two `handle` blocks. They are as
independent as two separate function calls. This is correct for the replay
model.

---

## Three Semantic Models

### Model 1: Replay (current)

Re-execute the computation from the beginning each time.

```lux
// Each handle block runs computation() from scratch
let r1 = handle { computation() } { op(x) => resume(x + 1) }
let r2 = handle { computation() } { op(x) => resume(x - 1) }
```

**Semantics**: `computation` restarts at instruction 0 each time. Side effects
inside the computation (prints, mutations via handler state) happen again.
Each run is fully independent.

**Cost model**: O(work) per invocation. No allocation beyond normal execution.

**Good for**: Numerical gradients, hyperparameter sweeps, Monte Carlo
sampling, any pattern where you want N independent runs of the same
computation with different handler policies.

**Bad for**: Resuming from a specific choice point (backtracking), forking
a computation mid-stream (speculative execution).

### Model 2: Fork

Make the continuation a first-class value that can be cloned.

```lux
// WORKING TODAY — see crucible_search.lux
handle { computation() } {
  choose(options) => {
    fold(options, [], |acc, opt| {
      if len(acc) > 0 { acc }           // short-circuit on first success
      else { resume(opt) }              // re-enter continuation with this value
    })
  }
}
```

**Semantics**: At the perform site, the continuation — the "rest of the
computation" after `choose(options)` — is captured as a value. Calling
`resume(opt)` invokes that continuation. Calling it multiple times requires
cloning the saved state (locals, stack frames, handler chain above the
current handler).

**Cost model**: O(captured_state) allocation per fork. The continuation struct
holds `{ state_index, saved_locals, handler_chain }`.

**Good for**: Backtracking search (SAT solvers, puzzle solvers, Prolog-style
logic programming), nondeterministic computation, amb/choose semantics.
`crucible_search.lux` validates this with 4-Queens, Pythagorean triples,
and constrained choice — all working today.

### Model 3: State Machine Transform

Compile the handled body into an explicit state machine at compile time.

```
// Conceptual compilation
fn computation_sm() -> StateMachine {
  state 0: let x = perform(op1, args)  -> goto state 1
  state 1: let y = perform(op2, args)  -> goto state 2
  state 2: return x + y
}
```

**Semantics**: The compiler identifies every perform site as a suspension
point. The body becomes a state machine where each state holds the locals
alive across that suspension. Resuming means jumping to state N and restoring
locals. Forking means cloning the `{ state_index, saved_locals }` struct.

**Cost model**: One struct allocation for the state machine. Clone cost is
O(struct_size) — typically small (just the live locals at the suspend point).

**Good for**: Everything. This is the most general model. It subsumes
replay (restart = jump to state 0) and fork (clone = copy struct).

**Bad for**: Simple cases where replay suffices — the state machine transform
adds compilation complexity for no runtime benefit.

---

## Use Cases Mapped to Models

| Use case | Pattern | Best model | Why |
|----------|---------|------------|-----|
| Numerical gradient | N independent runs, different params | Replay | No state to share; re-execution is simplest |
| Hyperparameter sweep | N independent runs, different configs | Replay | Same reasoning; `choose_lr()` maps to N replays |
| Monte Carlo sampling | N independent runs, different randomness | Replay | Each run has its own Random handler |
| Backtracking search | Resume from choice point with next option | Fork | Must return to the *same* point in computation |
| SAT solving | Explore → fail → backtrack → try next | Fork | Classic amb pattern; continuation is the "rest" |
| Speculative execution | Try two strategies in parallel, keep winner | Fork | Two forks of the same continuation, race them |
| Coroutines / generators | Yield values, resume to produce next | State machine | Already works via linear handlers |
| Async/await | Suspend at I/O, resume when ready | State machine | Standard CPS transform |

---

## Proposed Design

### Default: Replay

Replay is the default because it has the lowest cost and highest simplicity.
When you write:

```lux
let r1 = handle { f() } { ... }
let r2 = handle { f() } { ... }
```

Each `handle` block calls `f()` fresh. This is what happens today. No change
needed.

### Opt-in: Delimited Continuations via `fork`

For true multi-shot (backtracking, search), introduce `fork` as a way to
invoke a continuation multiple times within a single handler:

```lux
handle solve(puzzle) {
  choose(options) => {
    // resume is called once per option
    // each resume clones the continuation from this point
    let results = options |> filter_map(|opt| {
      try { resume(opt) }
    })
    first(results)
  }
}
```

The key semantic question: **what does calling `resume` multiple times do?**

**Proposed answer**: Each call to `resume` within a single handler arm forks
the continuation. The handler body sees all the forks' results. The first
`resume` runs normally. Subsequent `resume` calls clone the continuation state
from the perform site.

This means:
- **Replay** = default, no special syntax, thunk called again at top level
- **Fork** = multiple `resume` calls in one handler arm, continuation cloned

### Effect Row Annotation

The compiler marks handlers that call `resume` multiple times:

```lux
// Compiler infers: this handler is multi-shot
handle computation() {
  choose(options) => map(|o| resume(o), options)  // resume called N times
}
```

The three-tier classification (from INSIGHTS.md) already covers this:

| Tier | `resume` calls | Cost | Annotation |
|------|---------------|------|------------|
| Tail-resumptive | Exactly 1, in tail position | Zero | `evidence_eligible: true` |
| Linear (single-shot) | Exactly 1, not tail | One alloc | default |
| Multi-shot | 0 or 2+ | Clone per extra resume | detected by compiler |

The compiler **already classifies** handlers as tail-resumptive or not.
Extending this to detect multi-shot (resume called in a loop or called more
than once) is a natural extension of the existing analysis.

### Interaction with Handler-Local State

When a continuation is forked, what happens to handler-local state?

```lux
handle computation() with count = 0 {
  inc() => resume(()) with count = count + 1,
  choose(options) => map(|o| resume(o), options)  // fork here
}
```

**Proposed**: Each fork gets a **snapshot** of the handler state at the
perform site. Mutations in one fork don't affect others. This is consistent
with how `with count = count + 1` already works — it's a functional update,
not mutation.

### Compilation Strategy

For the VM (current): Multiple `resume` calls in one handler arm re-enter
the body with the resume value injected. The perform site's frame must be
preserved (not torn down) until all resumes complete. This requires saving
the frame on first resume and restoring it on subsequent resumes.

For native (future Phase 7): The state machine transform from INSIGHTS.md
directly applies. Each perform site is a numbered state. The continuation is
`{ state_index, saved_locals }`. Cloning it is a struct copy. The effect
rows tell the compiler exactly which perform sites exist — no conservative
analysis needed.

---

## What This Spec Does NOT Cover

1. **First-class continuations as values** — Continuations are not
   user-manipulable values. They exist only within the handler body
   via `resume`. This avoids the complexity of `call/cc` while preserving
   the power of delimited continuations.

2. **Parallel fork execution** — `resume` calls are sequential. Parallel
   execution of forks would require interaction with a concurrency system
   (async effects, work-stealing). That's a separate design question.

3. **Continuation serialization** — Saving a continuation to disk and
   resuming later. Out of scope for now.

4. **Algebraic effect interactions** — What happens when a forked
   continuation performs effects that are handled by a different, outer
   handler? The forked continuation inherits the full handler chain from
   the fork point. This should work correctly with the current handler
   stack model but needs testing.

---

## Open Questions

1. **Should replay be explicit?** Currently replay is implicit — two
   `handle { f() }` blocks just call `f` twice. Should there be syntax
   like `replay(computation, handlers_list)` that makes the pattern visible?

2. **Fork depth limits?** Backtracking search can explore exponentially
   many branches. Should the compiler/runtime enforce a configurable depth
   limit? Or is this the programmer's responsibility?

3. **Interaction with ownership?** If the continuation captures `own` values,
   forking requires cloning or copy-on-write semantics. How does `!Alloc`
   interact with fork (answer: it can't — forking allocates, so `!Alloc`
   computations cannot be forked, only replayed)?

4. **Evidence passing for multi-shot?** The evidence-passing optimization
   (tail-resumptive handlers compiled to direct calls) cannot apply to
   multi-shot handlers. The compiler already gates this — `evidence_eligible`
   is only set for tail-resumptive handlers. But should the compiler emit
   a teaching hint when a handler *would* be evidence-eligible except for
   multi-shot usage?

---

## Summary

| Model | When | Cost | Status |
|-------|------|------|--------|
| **Replay** | Independent re-execution | O(work) per run | ✅ Working (`crucible_ml.lux` Test 5) |
| **Fork** | Resume from same point with different values | O(state) per clone | ✅ Working (`crucible_search.lux` — 4-Queens, Pythagorean triples) |
| **State machine** | Native compilation of fork | O(struct) per clone | 🔲 Phase 7 |

Replay and fork both work today. The state machine transform is the native
compilation strategy for Phase 7.

---

## Validation: `crucible_search.lux`

`resume()` called N times inside one handler arm via `fold` — confirmed working.

| Test | Result |
|------|--------|
| 4-Queens | ✅ (1,2) (2,4) (3,1) (4,3) — correct |
| Simple choice (x+y ≤ 22) | ✅ First: 11 |
| First Pythagorean triple | ✅ (3, 4, 5) |
| All Pythagorean triples 1..20 | ✅ All 6 found |

Test 4 (all triples) uses `acc ++ resume(opt)` — collect-all semantics from
the same computation, different handler strategy than first-solution.
