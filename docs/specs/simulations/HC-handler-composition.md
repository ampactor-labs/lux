# HC — Handler composition · transform emits, materialize captures

*The rosetta stone for every handler-composition question in the
current queue. Seed instance: prelude.nx's Iterate family (map /
filter / take / skip currently accumulate internally — drift mode
11). Generalizes to frame-record (11.C.2), Diagnostic module
parameterization (11.B.M), operator-as-handler (Hα), and Mentl's
voice (MV.2 mentl_voice_default's 8 tentacles).*

*Status: walkthrough for item 11.C.3 of PLAN.md. Establishes the
substrate pattern; closes prelude's 4 remaining drift-11 hits.*

---

## 0. Framing — why this is the rosetta

The γ cascade + Phase II refactors exposed a repeated shape across
the compiler: **a handler accumulates state that doesn't belong to
its concern.** map_h accumulates while also transforming. frame-
record paired-lists accumulate handle slots while also providing
lookup. Diagnostic reports accumulate messages while also carrying
module identity.

Running the eight on each instance surfaces the same residue:

- **Graph?** The graph already separates the concerns; the code
  fuses them.
- **Handler?** The TWO concerns want TWO handlers. Composing them
  via `~>` is the substrate form.
- **Verb?** `~>` chain draws the separation on the page.
- **Row?** Each handler's effect row carries its own concern; the
  chain's row is the union minus what each handler absorbs.

**The pattern:**

> **Transform handlers emit. Materialize handlers capture. Compose
> via `~>`. The accumulator lives in the materializer's state, not
> in the transformers'.**

11.C.3 is the first concrete instance. The pattern then ripples.

---

## 1. The seed instance — prelude.nx's Iterate family

### 1.1 Current state (drift-11)

```
effect Iterate {
  yield(element) -> ()
  result() -> ()
}

fn iterate(xs) with Iterate = {
  fn go(i) = if i < len(xs) { yield(xs[i]); go(i + 1) } else { () }
  go(0)
}

handler map_h(f) with acc = [] {
  yield(elem) => resume() with acc = acc ++ [f(elem)],  // drift-11
  result()    => resume() with acc = acc
}

handler filter_h(pred) with acc = [] {
  yield(elem) => if pred(elem) { resume() with acc = acc ++ [elem] }  // drift-11
                 else { resume() },
  result()    => resume() with acc = acc
}

handler take_h(n) with acc = [], remaining = n {
  yield(elem) =>
    if remaining > 0 { resume() with acc = acc ++ [elem],           // drift-11
                                      remaining = remaining - 1 }
    else { resume() }
}

handler skip_h(n) with acc = [], skipped = 0 {
  yield(elem) =>
    if skipped < n { resume() with skipped = skipped + 1 }
    else { resume() with acc = acc ++ [elem] }                       // drift-11
}
```

**Each handler is doing TWO things:** transforming the yielded value
(drop it / pass it through modified / pass if count) AND
accumulating the result into a list. The accumulation is drift-11
in each of four arms.

### 1.2 Post-refactor — each handler does ONE thing

**Transform handlers RE-YIELD:**

```
handler map_h(f) {
  yield(elem) => { perform yield(f(elem)); resume() }
}

handler filter_h(pred) {
  yield(elem) => { if pred(elem) { perform yield(elem) }; resume() }
}

handler take_h(n) with remaining = n {
  yield(elem) =>
    if remaining > 0 {
      perform yield(elem)
      resume() with remaining = remaining - 1
    } else {
      resume()
    }
}

handler skip_h(n) with skipped = 0 {
  yield(elem) =>
    if skipped < n {
      resume() with skipped = skipped + 1
    } else {
      perform yield(elem)
      resume()
    }
}
```

**One materialize handler captures:**

```
// collector: captures every yielded element into a buffer+counter
// substrate (the Ω.3 primitive). Returns the materialized list when
// the enclosing handle block completes. No `++ [x]` — pure
// buffer-counter.

handler collector with buf = make_list(16), count = 0 {
  yield(elem) => {
    let extended = list_extend_to(buf, count + 1)
    let written  = list_set(extended, count, elem)
    resume() with buf = written, count = count + 1
  }
  // No `result()` arm needed — the handle block's return value IS
  // slice(buf, 0, count) via INSIGHTS.md "Handler State
  // Internalization": the body value IS the handle value.
}
```

### 1.3 Composition shape

```
fn map(f, xs)        = iterate(xs) ~> map_h(f)     ~> collector
fn filter(pred, xs)  = iterate(xs) ~> filter_h(pred) ~> collector
fn take(n, xs)       = iterate(xs) ~> take_h(n)    ~> collector
fn skip(n, xs)       = iterate(xs) ~> skip_h(n)    ~> collector

// Chained transforms — composition falls out:
fn first_three_positives_doubled(xs) =
  iterate(xs)
    ~> filter_h(positive)
    ~> take_h(3)
    ~> map_h(double)
    ~> collector
```

**Each `~>` is one concern.** The shape on the page IS the
transform chain. The five verbs (primitive #3) draw the topology.

---

## 2. Design questions — resolved inline

### Q1 — Does `perform yield` inside a yield-arm re-enter the same handler?

**No.** Per Inka's handler-stack semantics (DESIGN Ch 1), a `perform`
inside an arm dispatches to the NEAREST handler of that op
EXCLUDING the one whose arm is currently running. So `perform
yield(f(elem))` inside map_h's `yield` arm routes to the NEXT outer
handler (collector in the chain above). This is Frank-style
delimited-continuation semantics; it's what makes `~>` chains
compose.

**Decision:** lean on standard handler-stack semantics. If the
current VM implementation is ambiguous on this point, that's a
substrate bug to fix (not an HC-walkthrough blocker).

### Q2 — Is `collector` parameterized (initial-capacity arg)?

For V1: **no.** Fixed initial capacity of 16; `list_extend_to`
grows it. Parameterization is a V2 concern once real-world profiles
show benefit.

If adopted later: `collector(initial_cap: Int)` — primitive #2
parameterized-effect exercise. Row algebra would distinguish
`collector(16)` and `collector(4096)` by name + arg value.

### Q3 — What about `result()` op?

Currently the `result()` op existed on Iterate. Post-refactor it's
**deleted.** The handle block's return value IS the accumulated
list (INSIGHTS.md "Handler State Internalization"). No explicit
result call needed.

### Q4 — Do the transform handlers share the Iterate effect with the source?

Yes. `iterate(xs)` performs `yield(x)` for each x; map_h's arm
handles yield, performs yield(f(x)) which routes to collector. All
three handlers are on the SAME Iterate effect. The chain's
algebraic shape: each `~>` installs one handler on the Iterate
effect; standard layered-handler semantics.

### Q5 — What about fold-style consumption (sum, count, max)?

These are DIFFERENT materializers — not collector. Each is its own
materialize-handler with different state:

```
handler sum_h with total = 0 {
  yield(elem) => resume() with total = total + elem
}

handler count_h with n = 0 {
  yield(elem) => resume() with n = n + 1
}
```

Compose: `iterate(xs) ~> map_h(f) ~> sum_h` — "sum of mapped values".
The pattern generalizes: **any materializer is a handler on yield
with its own state shape.** collector materializes into a list;
sum_h into an Int; count_h into an Int; max_h into an Option; etc.

### Q6 — Does this break stream fusion?

No — improves it. Post-refactor, map_h's `yield(elem) => perform
yield(f(elem)); resume()` is a tail-resumptive handler (85% case
per INSIGHTS.md "Three Tiers"). Compiles to zero-overhead direct
call. `filter_h` is linear (single-shot resume). collector is
linear. Chain compiles to a tight loop with no intermediate list
allocations.

Current form allocates `acc ++ [x]` O(N²) per stage. Post-refactor
form allocates once in collector's buffer-counter substrate —
O(N) total across chain.

---

## 3. Substrate additions — minimal

### 3.1 Code changes

**std/prelude.nx:**
- Remove `result()` op from Iterate effect
- Rewrite map_h, filter_h, take_h, skip_h to re-yield (no acc)
- Add `handler collector` with buf+count state
- Add `handler sum_h`, `handler count_h` (seed instances of
  alternative materializers; additional fold-materializers are
  deferred to usage-driven demand)
- Rewrite `map`, `filter`, `take`, `skip` wrappers to use
  `~>` chain composition

**No new runtime primitive.** `list_extend_to` + `list_set` +
`slice` + `make_list` are already the Ω.3 substrate.

**No types.nx change.** Effect signatures stay; just handler body
rewrites.

### 3.2 Diff estimate

~100 lines removed (the old acc accumulators, `result()` op,
wrapper-function internals).
~60 lines added (new collector + sum_h + count_h handlers,
re-yielding arms, rewrapped compositions).
Net: -40 lines in prelude.nx. Cleaner.

---

## 4. The rosetta — how this ripples

### 4.1 11.C.2 frame-record restructure

Current: `local_handles + local_order` paired lists with `++ [x]`
on every `ls_push_local`.

Post-HC pattern: `OrderedMap` effect + materialize-handler state.
`ls_push_local` performs `ordered_map_insert(name, h)` which the
materializer captures into (buf_keys, buf_handles, count). Lookups
perform `ordered_map_get(name)` which reads the materializer's
state.

Same shape as collector: transform-side emits, materialize-side
captures.

### 4.2 11.B.M Diagnostic module parameterization

Current: every `perform report("parser", code, ...)` passes module
as a String. Drift-8-adjacent.

Post-HC pattern: `Diagnostic(module: ModuleName)` parameterized
effect. Each module installs `~> diagnostic_handler(ModParser)` at
entry. The transform-side is the module's own code (performs
report without module arg); the materialize-side is the
diagnostic_handler, which captures + attributes + emits.

Same shape: transform (any module code) + materialize
(diagnostic_handler with module-parameterized state).

### 4.3 Hα operator-semantics-as-handler

Current: `+` lowers to LBinOp + direct WAT emit. Fixed semantics.

Post-HC pattern: `Arithmetic(mode: ArithMode)` parameterized
effect. `+` lowers to `perform add(l, r)`. Transform-side is the
user code (performs add); materialize-side is
`arithmetic_handler(mode)` which decides wrapping/checked/
saturating and emits appropriate WAT.

Same shape: transform emits the intent; materialize picks the
semantics.

### 4.4 MV.2 mentl_voice_default's 8 tentacles

Current MV.2 design: each of 8 tentacles is a handler arm on
Interact's op set.

Post-HC pattern: each tentacle is a transform-handler that EMITS a
structured observation; each LSP surface (hover / inlayHint /
diagnostic / codeAction) is a materialize-handler that captures +
renders. `Interact(surface: Surface)` parameterized by the
materialization target.

```
interact_session
  ~> query_tentacle          // emits TentObservation
  ~> propose_tentacle        // emits TentObservation
  ~> teach_tentacle          // emits TentObservation
  ...
  ~> lsp_hover_materializer  // captures; renders hover response
```

HC's pattern maps 1:1. The 8 tentacles transform; the LSP surfaces
materialize. Clean composition.

**HC lands before MV.2 so MV.2's implementation uses the proven
pattern rather than re-deriving it.**

---

## 5. Acceptance tests (inline)

### HC-AT1 — map via composition

```
map(double, [1, 2, 3])
```
Expected: `[2, 4, 6]`.
Composition: `iterate([1,2,3]) ~> map_h(double) ~> collector`
Each of the 3 elements: iterate yields → map_h transforms →
re-yields → collector captures. Final: slice of buf.

### HC-AT2 — chained transforms

```
first_three_positives_doubled([-1, 2, -3, 4, 5, -6, 7])
```
Expected: `[4, 8, 10]`.
Chain: `iterate ~> filter_h(positive) ~> take_h(3) ~> map_h(double)
~> collector`.
filter drops -1, -3, -6; take stops after 3 positives (2, 4, 5);
map doubles each; collector captures.

### HC-AT3 — fold materializers

```
sum(map(double, [1, 2, 3]))
```
Expected: `12`.
Chain: `iterate([1,2,3]) ~> map_h(double) ~> sum_h`. sum_h captures
(2, 4, 6) into total: 0 → 2 → 6 → 12.

### HC-AT4 — drift-audit post-refactor

After landing this walkthrough's code changes:
```
bash tools/drift-audit.sh std/prelude.nx
```
Expected: `CLEAN — 1 file(s) scanned, 0 drift modes fired`.

4 pre-refactor drift-11 hits (lines 35, 41, 83, 93) eliminated by
structural rewrite; collector's buffer-counter form passes the
`++ [x]` regex because it doesn't use `++ [x]` anywhere.

### HC-AT5 — stream fusion preserved

Post-refactor, `first_three_positives_doubled(xs)` compiles to a
tight single loop with ZERO intermediate list allocations (only
collector's buf grows once). This is the performance claim
INSIGHTS.md "Three Tiers of Effect Compilation" makes for
tail-resumptive handler chains.

Verification via `inka audit` once MV.2 lands: the chain's
computed row IS `EfClosed([Iterate, Alloc])` (collector's buf
allocates; transforms are Pure). If `sum_h` replaces collector,
the row drops Alloc — chain becomes `EfPure`-minus-Iterate.

---

## 6. Landing sequence

1. **HC-walkthrough closes** (this file). Contract locked.
2. **Code refactor** lands as commit 11.C.3:
   - std/prelude.nx rewrites (map_h, filter_h, take_h, skip_h,
     collector, sum_h, count_h).
   - Pre-commit drift-audit: CLEAN expected.
3. **11.C.2 writes** using HC pattern (frame-record OrderedMap).
4. **11.B.M writes** using HC pattern (Diagnostic parameterized).
5. **MV.2 writes** using HC pattern (tentacles transform; surfaces
   materialize).

HC is load-bearing for 4 downstream commits. Land it first.

---

## 7. Sub-handles surfaced

- **HC.1 — additional materializers** (min_h, max_h, find_h, fold_h).
  Lands when a caller needs them; no pre-landing.
- **HC.2 — handler re-entrancy semantics verification.** Q1
  asserted Frank-style delimited dispatch. If the current Inka VM
  or self-hosted checker violates this, walkthrough-side issue:
  file as peer cascade handle.
- **HC.3 — parameterized collector** (`collector(initial_cap)`).
  Deferred until real-world profiling demands it.

---

## 8. Closing

Handler composition is the substrate under every remaining queue
item. HC lands it in the smallest concrete instance (prelude's
Iterate family), proves the pattern, and names the four downstream
applications that will reuse it without re-deriving.

**Transform emits. Materialize captures. `~>` composes. The
accumulator lives in the materializer, not in the transformers.**

This is how handlers stop fighting and start composing.
