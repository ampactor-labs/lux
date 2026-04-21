# DET — Determinism-audit discipline walkthrough

> **Status:** `[PENDING]`. Defines the determinism-audit methodology. Gates Pending Work item 24 (determinism audit execution). After this walkthrough closes, item 24 is prescriptive mechanical verification.

*First-light demands byte-identical self-compilation. The hand-WAT reference image is static; what VFINAL's compiler emits through its hand-WAT MUST match. Every source of non-determinism in emit IS a first-light blocker. This walkthrough specifies what non-determinism looks like, how to find it, and how to eliminate it.*

---

## 0. Framing — why determinism is substrate

Determinism is the property that the same compiler compiling the same source produces byte-identical output. **This is load-bearing for first-light** because:

1. **Hand-WAT is the reference.** First-light's fixed-point test diffs `bootstrap/inka.wat` against `inka2.wat` (the compiler's self-compilation output). A single non-deterministic byte in emit = diff non-empty = first-light fails.
2. **Non-determinism is latent.** It might pass on one run, fail on another; a determinism bug can ship and hide until a first-light attempt.
3. **Post-first-light, determinism enables caching.** IC's `(source_hash, handler_chain_hash)` key assumes same inputs → same output. Non-determinism breaks cache correctness.

Sources of non-determinism:
- Unsorted iteration over collections (hash-ordered dicts, HashMap iteration).
- Timestamps / wall clock in output.
- Random seeds not fixed.
- Parallel execution with observable ordering effects.
- Memory-address-dependent behavior (printing a pointer).
- Environment-variable reads.
- Filesystem-iteration-order dependencies.

**Inka is mostly immune by construction:** the substrate is sorted-by-construction (field sort in H2, effect-name sort in H3.1, region-sort in H4, everything-sorted-by-handle), but the emit path + any diagnostic output + any opaque collection iteration could still leak.

This walkthrough gates:
- Item 24 — determinism audit execution.

What this walkthrough does NOT cover:
- Correctness (that's self-simulation, item 23).
- Simplification (SIMP, item 7).
- Feature-usage scope (item 25).

**Dependency:** item 24 runs AFTER simplification (item 11) closes. Rationale: simplification rewrites the exact emit paths determinism measures; doing them in reverse order would re-audit paths already modified.

---

## 1. The audit methodology

### 1.1 The determinism invariant

For every compilation of the same input:

```
forall source, handler_chain:
  compile(source, handler_chain) = compile(source, handler_chain)
```

**The LHS is the first compilation. The RHS is an arbitrary subsequent compilation.** If they differ, the compiler is non-deterministic.

### 1.2 The test form — single-process double-compile

**Primary test:**

```
inka compile src/main.nx > /tmp/first.wat
inka compile src/main.nx > /tmp/second.wat
diff /tmp/first.wat /tmp/second.wat
# must be empty
```

Single-process: rules out env-variable or filesystem-state differences between runs.

**Secondary test:**

```
inka compile src/*.nx lib/**/*.nx > /tmp/full_first.wat
inka compile src/*.nx lib/**/*.nx > /tmp/full_second.wat
diff /tmp/full_first.wat /tmp/full_second.wat
# must be empty
```

Full-tree self-compilation (the compiler compiles itself).

**Tertiary test (multi-process, cross-session):**

```
# session 1
inka compile src/*.nx > /tmp/session_1.wat

# session 2 (fresh shell, different PID, potentially different memory layout)
inka compile src/*.nx > /tmp/session_2.wat

diff /tmp/session_1.wat /tmp/session_2.wat
# must be empty
```

Verifies no memory-address leakage, no session-state dependency.

### 1.3 What gets audited

Every emit path. Specifically:

1. **`src/backends/wasm.nx`** — the WAT emission handler. Every `emit_*` function's output must be deterministic given its input. All iteration over collections must be sorted by a canonical key.
2. **`src/lower.nx`** — LowIR construction. Handle allocation order, ADT tag assignment, closure record layout.
3. **`src/infer.nx`** — type inference. Handle assignment order (must follow source order), Reason attachment order.
4. **`src/cache.nx`** — `.kai` cache serialization. Sorted fields, canonical string formatting.
5. **`src/mentl.nx`** — diagnostic output, voice line formatting (relevant for test runs where diagnostics appear in output).
6. **`src/pipeline.nx`** — handler composition order.
7. **`lib/runtime/*.nx`** — any runtime function whose behavior could be order-dependent.

### 1.4 Determinism rules (prescriptive)

Every site in the emit path must obey these rules:

**Rule 1: Iterate collections in canonical order.**
- Lists: source order (the order the list was constructed in — list_to_flat produces this).
- Records: field-name sorted order (H2's canonical form; already enforced at construction).
- Effect rows: effect-name sorted (EffName ADT compared canonically).
- Handle-indexed collections: iterate by increasing handle value (source-order assignment).
- Maps / dicts (if any): replace with sorted association list + binary search, OR use a canonical-key-ordered iteration.

**Rule 2: No timestamps, dates, or wall-clock values in output.** Every comment in emitted WAT that currently includes a timestamp (`;; generated at 2026-04-21T12:34:56`) must be removed or replaced with a static string.

**Rule 3: No random seeds, no RNG calls, no PID, no env-variable reads in emit.** If a random decision is needed (e.g., a unique name), derive it deterministically from input (hash of input, counter seeded from context).

**Rule 4: No pointer printing.** `show(p)` where `p` is a pointer value can leak memory addresses; never format raw pointer in output.

**Rule 5: Canonical number formatting.** Floats must use a canonical decimal form (e.g., `0.1` not `0.10000000001` — round to a canonical representation). Integers straightforward.

**Rule 6: Handle assignment is source-order.** Every graph handle minted during inference gets the next integer; order is strictly the order of `graph_fresh_ty` calls; those calls are made in source-walk order (infer.nx's single-walk discipline).

**Rule 7: Emit-loop over graph content iterates by handle.** Never iterate over graph nodes by some hash ordering; use `for h in 0 .. graph_next_handle() { emit_node(h) }`.

**Rule 8: Record field emission is sorted-by-name at construction** (already enforced by H2), not re-sorted at emit time.

**Rule 9: Effect row emission is canonical** — EffPure / EffClosed(sorted_names) / EffOpen(sorted_names, handle). Already canonical by H3.1 + row algebra; verify.

**Rule 10: Diagnostic output order follows source position.** When multiple errors are reported for one compilation, they're emitted in source-span order (sorted by `(start_line, start_col, end_line, end_col)`).

### 1.5 Non-determinism detection patterns

**Static detection** — grep-friendly patterns that indicate potential non-determinism:

- `now()`, `current_time`, `timestamp`, `wall_clock` — if invoked in emit path.
- `random()`, `rand_seed`, `rng` — if invoked in emit path.
- `getpid`, `pid()` — if invoked anywhere in emit.
- `getenv`, `env_var_read` — if invoked anywhere in emit.
- `format_pointer`, `addr_of` — if invoked in emit output.
- `hash_map_iter`, `dict_keys` without a subsequent `sort()` — unsorted iteration.
- Iteration over a raw-list of pairs `[(k, v), ...]` without sorting — unsorted iteration.

**Dynamic detection** — runtime testing:

- The single-process double-compile test (§1.2) run on every commit touching emit paths.
- CI gate: determinism test must pass before any emit-path change merges.

### 1.6 Tolerable non-determinism

**None.** Within emit. Every byte of WAT output must be reproducible.

**Exception:** diagnostics NOT in WAT — human-facing error messages printed to stderr — can carry a timestamp for human reading. But stderr diagnostics don't affect the first-light diff (which only compares the WAT output).

---

## 2. The execution method

### 2.1 Pass 1 — Static pattern scan

Run pattern scan across `src/*.nx` + `lib/**/*.nx`:
- Every pattern from §1.5.
- Every hit investigated + classified (false-positive, true positive, acceptable).
- Every true positive fixed in-place.

### 2.2 Pass 2 — Iteration-order audit

For every `fn emit_*` in `src/backends/wasm.nx`:
- Identify every iteration over a collection.
- Verify the iteration is over a sorted or source-ordered collection.
- Fix any unsorted iteration.

### 2.3 Pass 3 — Single-process double-compile test

Run the primary test from §1.2:

```
inka compile src/main.nx > /tmp/first.wat
inka compile src/main.nx > /tmp/second.wat
diff /tmp/first.wat /tmp/second.wat
```

If diff empty: proceed to Pass 4.
If diff non-empty: investigate the diff. Each differing region is a non-determinism source; fix and retest.

### 2.4 Pass 4 — Full-tree double-compile

Run on the whole `src/` + `lib/` tree. Same diff check. Fix until empty.

### 2.5 Pass 5 — Cross-session test

Run the tertiary test (separate shells, separate processes). Diff must be empty.

### 2.6 Pass 6 — Regression gate

Add the determinism test to `tools/` as `tools/determinism-gate.sh`:

```bash
#!/usr/bin/env bash
# Fails if the compiler is non-deterministic on a canonical input.

set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"

inka compile src/*.nx lib/**/*.nx > /tmp/det_first.wat
inka compile src/*.nx lib/**/*.nx > /tmp/det_second.wat

if diff -q /tmp/det_first.wat /tmp/det_second.wat > /dev/null; then
  echo "✓ determinism: byte-identical on double-compile"
  exit 0
else
  echo "✗ determinism FAILED: diff non-empty"
  diff /tmp/det_first.wat /tmp/det_second.wat | head -50 >&2
  exit 1
fi
```

Pre-commit hook runs this on any commit touching `src/*.nx` or `lib/**/*.nx`.

---

## 3. What happens when non-determinism is found

**Always fix in-place.** Non-determinism is never acceptable as "for now." Every non-deterministic site is a first-light blocker.

Classification of fixes:

- **Unsorted iteration** → add sorted iteration. O(N log N) cost; acceptable given emit is batch.
- **Timestamp in output** → remove (prefer) or replace with static placeholder.
- **Random seed** → derive deterministically from input.
- **Memory-layout-dependent output** → refactor to use structural ID (handle, name), not address.
- **Env-variable read** → remove from emit path; move to CLI arg or fail compile with error if the env-var is semantically required.

---

## 4. The eight interrogations applied

### 4.1 Graph?

The graph's substrate is sorted-by-construction (H2 H3.1 H4). Most determinism comes for free from the substrate; only the emit path (which reads the graph) can introduce non-determinism.

### 4.2 Handler?

The `wat_emit` handler produces the WAT output. Its arms must all be deterministic. Any handler installed in the compile-run entry-handler chain that could leak non-determinism (timestamp, random, etc.) is a bug.

### 4.3 Verb?

Emit is a `|>` pipeline: `infer_done |> lower |> collect_strings |> emit_preamble |> emit_functions |> emit_data |> emit_postamble`. Each stage must preserve determinism of its input.

### 4.4 Row?

The emit row is `wat_emit + Filesystem + Alloc`. `Clock` MUST NOT be in the emit row. `Random` MUST NOT be in the emit row. Adding `!Clock + !Random` to emit entry-handler's row constraint PROVES this at compile time. Gradient realizing: each `!E` added to emit-run constrains determinism.

### 4.5 Ownership?

Regardless. Ownership doesn't affect determinism.

### 4.6 Refinement?

Post-first-light, add a refinement `type Deterministic<A> = A where is_deterministic(self)` that the emit pipeline's return type refines. Not gating first-light; lands in Arc F.1 SMT work.

### 4.7 Gradient?

Per §4.4 above: `!Clock + !Random` on compile_run handler's row is a gradient unlock that compile-time-proves determinism of every call in its body.

### 4.8 Reason?

Every determinism fix leaves a Reason: "removed non-deterministic timestamp per DET audit."

---

## 5. Forbidden-pattern list

- **Drift 9 (deferred-by-omission):** no `// TODO: fix determinism here`. Fix now.
- **Drift 6 (primitive-type-special-case):** no emit path is exempt; every module audited.
- **`acc ++ [x]` loops** in emit — O(N²) AND their output order may depend on how much GC pressure was applied; doubly bad. Replace with buffer-counter.

---

## 6. Sequencing within item 24

**Commit 24.A — Pass 1 pattern scan + fixes**: mechanical.

**Commit 24.B — Pass 2 iteration-order audit + fixes**: semantic.

**Commit 24.C — Tests added**: `tools/determinism-gate.sh` + pre-commit hook integration.

**Commit 24.D — Gate enforced**: drift-audit integrated with determinism gate.

Each commit gated by running the appropriate test.

---

## 7. Dispatch

**Option A (dual-tier Sonnet):** for 24.A (mechanical pattern scan).

**Option B (Opus-on-Opus):** for 24.B (semantic iteration-order audit — judgment about what's "source order" at each site).

**Option C (Opus inline):** for 24.C + 24.D (gate setup + integration).

---

## 8. What closes when DET lands

- Item 24 (determinism audit) complete.
- `tools/determinism-gate.sh` permanent regression gate.
- First-light can be attempted without determinism risk.
- Post-first-light, `(source_hash, handler_chain_hash)` cache keying is safe.

**Sub-handles split off:** none.

---

## 9. Riffle-back

1. Verify the gate script performs sub-second (if not, IC-cache the double-compile).
2. Run the cross-session test on a separate machine to verify no host-specific leakage.
3. Audit any Mentl voice output for timestamps — VoiceLines should be static text + graph data only, no wall clock.

---

## 10. Closing

DET is how Inka proves its own byte-identity to itself. Every emit path audited, every unsorted iteration sorted, every timestamp removed, every random-dependency eliminated. Post-DET, the single-process double-compile diff is empty; first-light's fixed-point test has a deterministic compiler to diff against the hand-WAT.

**One walkthrough, 4 commits, byte-identical compilation guaranteed.**
