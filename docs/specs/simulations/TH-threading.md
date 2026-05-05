# TH — Threading · multi-core as handler topology

> **Status:** `[DRAFT 2026-04-23]`. Morgan's prompt: *"imagine how
> embarrassing it would be if Inka only used one core."* Right.
> The substrate is SKETCHED in DESIGN Ch 6-7 + Ch 2 — but no
> walkthrough names the threading substrate, no effect is
> declared, no crucible tests scaling, no hand-WAT emits
> atomics or shared memory. TH closes the gap: names the
> substrate, specifies the runtime, prescribes the emit shape,
> commits a crucible.

*Inka's multi-core story is NOT "add threads" — threads are the
industry's primitive. Inka's primitive is `><` (primitive #3),
whose semantics are "independent parallel tracks." A handler
decides whether tracks run sequentially on one core, concurrently
via fibers, or genuinely parallel across OS threads. One source;
handler chooses dispatch. Multi-core is a handler, not a
language feature.*

---

## 0. Framing — what threading is in Inka vs what it isn't

### 0.1 What threading is NOT in Inka

- **Not a keyword.** No `thread { ... }` block, no `go func()`.
  Rust `spawn`, Go `go`, JavaScript `worker` — all would be
  drift-24 (async/await vocabulary) or drift-21 (class-per-thread
  vocabulary). Inka has no thread keyword.
- **Not a first-class value the user constructs.** No
  `let t = Thread::new(...)`. Threads are handler-state; the user
  writes `><` and an installed handler interprets.
- **Not Send/Sync bounds on types.** No `fn foo<T: Send>(x: T)`.
  Cross-thread transfer is a row constraint (`with SharedMemory`
  or handler-scoped memory regions), not a type-level marker.

### 0.2 What threading IS in Inka

**Threading is a handler installation on `><` + ambient Alloc.**
Concretely:

1. **`><` produces independent tracks** (spec 10 / DESIGN Ch 2) —
   each track has its own `own` inputs, its own effect row, its
   own Alloc handler scope.
2. **`parallel_compose` handler** (named here for the first
   time) intercepts the tracks' effects and schedules them on
   distinct OS threads via the `Thread` effect (declared below).
3. **Thread-local Alloc** (DESIGN Ch 7.Thread-local): each thread
   installs its own `bump_allocator` — no shared allocator state,
   no lock-per-allocation.
4. **Cross-track data via Pack/Unpack bytes** (PLAN 2026-04-22
   primitive) — the only handler-cross-wire primitive; bytes are
   thread-safe by construction (no pointers).
5. **Send/Sync proven by row subsumption** (DESIGN Ch 6) —
   handlers installed per-thread have scoped capabilities; a
   value that flows across a handler boundary must satisfy the
   target handler's row. The compiler proves data-race freedom
   by walking effect rows, not by T: Send bounds.

**One sentence:** Inka scales to N cores by installing
`~> parallel_compose` at the top of a `><` chain. No other source
change.

---

## 1. The substrate — effects and handlers

### 1.1 `Thread` effect

```
effect Thread {
    spawn(task: () -> A) -> Handle      @resume=OneShot
    await(handle: Handle) -> A          @resume=OneShot
    current_id() -> Int                 @resume=OneShot
    num_cores() -> Int                  @resume=OneShot
}

type Handle = Handle(Int)    // opaque; handler-held thread/task identity
```

**Primitive #2 (handler + resume discipline):** both `spawn` and
`await` are OneShot because resuming means continuing the caller
after thread launch/join. Multi-shot would imply forking the
continuation across multiple resumes — a different topology
(pool of candidate plans racing), handled by the separate `race`
combinator (MSR Edit 5), not `Thread`.

### 1.2 `SharedMemory` effect — atomics + wait/notify

```
effect SharedMemory {
    atomic_load_i32(addr: Int) -> Int         @resume=OneShot
    atomic_store_i32(addr: Int, val: Int) -> ()  @resume=OneShot
    atomic_rmw(addr: Int, op: RmwOp, val: Int) -> Int  @resume=OneShot
    wait_i32(addr: Int, expected: Int, timeout_ns: Int) -> WaitResult  @resume=OneShot
    notify(addr: Int, count: Int) -> Int      @resume=OneShot
    fence() -> ()                              @resume=OneShot
}

type RmwOp = RmwAdd | RmwSub | RmwAnd | RmwOr | RmwXor | RmwXchg | RmwCmpxchg

type WaitResult
    = WOk               // notified before timeout
    | WTimedOut         // timeout fired
    | WNotEqual         // expected value mismatch at wait time
```

**Why a separate effect:** `SharedMemory` is primitive-#4-gated.
A function `with !SharedMemory` is provably single-threaded-memory
(can still call `spawn` via `Thread` — tracks' local memory is
unshared). `Pure + !SharedMemory` is the strictest
parallelizable-no-sync contract.

**Drift mode 3 (string-keyed effect):** `RmwOp` is an ADT, NOT
a string. WASM's `atomic.rmw.<op>.<type>` opcodes map from this
ADT in emission.

### 1.3 `parallel_compose` handler — the `><` multi-core semantics

```
handler parallel_compose with threads = [] {
    // spawn a thread per branch of a `><` compose; each thread
    // installs its own bump_allocator; await at the join point.
    //
    // Body is the lowered `><`; under this handler, each branch
    // runs on a distinct OS thread. Return is the tuple of
    // branch outputs in the order of the source `><`.

    spawn(task) => {
        let handle = ffi_spawn(task)
        resume(handle) with threads = [handle] ++ threads
    },

    await(handle) => resume(ffi_join(handle))
}
```

**Per-thread bump_allocator:** installed at thread entry by the
`ffi_spawn` wrapper (runtime detail). Each thread has
`(global $heap_ptr (mut i32))` in a thread-local, no shared
allocator, no mutex.

**Drift mode 7 (parallel arrays / record-begging):** `threads`
is `List<Handle>`, NOT `(List<Int>, List<ThreadState>)` pair.

---

## 2. `><` × threading — the user-level shape

Before TH (today): `><` desugars to sequential evaluation of each
branch, tuple-packing the results. Single-threaded.

After TH (this walkthrough): `><` desugars identically at the
AST level. The `parallel_compose` handler, when installed,
intercepts the branches' effects and dispatches them to threads.

```
// Source
(input_a |> process_a)
    ><
(input_b |> process_b)
|> join

// With parallel_compose installed:
((input_a |> process_a) >< (input_b |> process_b) |> join)
    ~> parallel_compose

// Without parallel_compose, same source runs sequentially:
((input_a |> process_a) >< (input_b |> process_b) |> join)
// Runs process_a, then process_b, then join.
```

**The user changes NOTHING except the handler chain.** The `><`
shape is unchanged; multi-core is a capability the handler grants
at the ~> site.

**Primitive #4 (row algebra):** `parallel_compose` handler's
declared row is `Thread + !SharedMemory`. Branches declaring
`!SharedMemory` compose cleanly (no shared state). Branches
requiring `SharedMemory` must install their own per-branch
`SharedMemory` handler or be rejected at install.

---

## 3. Thread-local Alloc — per-thread bump_allocator

Per DESIGN Ch 7 "Thread-local `Alloc` — lock-free concurrency":

```
handler thread_local_bump with heap_ptr_offset = 0 {
    // Runtime detail: each thread has its own heap_ptr global
    // (thread-local storage in WASM; one memory page reserved
    // per thread for scratch). alloc() updates the thread-local
    // pointer; no atomics, no mutex.

    alloc(size) => {
        let aligned = align(heap_ptr_offset, 8)
        resume(aligned + thread_base_addr()) with heap_ptr_offset = aligned + size
    }
}
```

**Per-thread memory region:** the runtime allocates a fixed-size
arena per thread at thread launch (default 256MB, configurable
via `parallel_compose(arena_size = ...)`). `thread_base_addr()`
is a runtime primitive returning the current thread's arena
origin.

**Why lock-free:** bumps are thread-local writes. Cross-thread
data transfer goes through `Pack`/`Unpack` (bytes), never
through raw pointers. Pointers are not Send.

**Drift mode 5 (C calling convention):** no `__thread_id` hidden
parameter. The `current_id()` op on `Thread` is the only way to
read thread identity; internal to handler state otherwise.

---

## 4. Cross-thread data — Pack/Unpack as the only wire

Raw pointers don't cross thread boundaries safely. Inka's answer:
**all cross-thread data goes through `Pack` → bytes → `Unpack`**.

```
// Producer thread
let msg = pack_my_data(data)           // Bytes
let handle = perform spawn(() => consumer(msg))

// Consumer thread
fn consumer(bytes: Bytes) = {
    let data = unpack_my_data(bytes)
    // process
}
```

**Primitive #4 (row algebra):** `Pack + Unpack` is declared in
`lib/runtime/binary.nx` already (PLAN 2026-04-22). Cross-thread
is one consumer of that substrate; network/disk are others.
**One mechanism; multiple transports.**

**For shared-memory-concurrent data (counters, queues):** use
`SharedMemory` atomics directly. `atomic_rmw` for counters;
`wait_i32` + `notify` for blocking synchronization.

---

## 5. Send/Sync via row — the compiler's proof

**No `T: Send` bounds.** Instead, row subsumption at handler
install:

- A handler installed outside `parallel_compose` has full row
  access (single-threaded).
- A handler installed INSIDE `parallel_compose`'s branch context
  must satisfy `Branch's declared row ⊆ parallel_compose's
  permitted row`. Per-branch handlers see only
  `!SharedMemory` + `Pack` + `Unpack` + local Alloc by default.

**Drift-avoidant:** this uses primitive #4 (Boolean effect
algebra) as the existing subsumption engine. NO new type-class
system, NO `Send`/`Sync` traits, NO `unsafe` escape hatch. The
compiler proves thread-safety by walking rows, same mechanism
that proves `!Alloc` transitively.

---

## 6. Runtime target — WASM threads + wasi-threads

### 6.1 What's available

- **WASM threads proposal (Wasm 3.0 standardized):** shared
  linear memory, atomics opcodes (`i32.atomic.load`,
  `i32.atomic.rmw.add`, etc.), `memory.atomic.wait32`,
  `memory.atomic.notify`.
- **wasmtime:** WASM threads stable since v7+ (April 2026
  baseline is v44); flag `--wasm-features=threads`.
- **wasi-threads (WASI preview 2):** `thread_spawn` imports for
  creating OS-backed threads.
- **wasi preview 1 only:** no thread primitives; parallel
  compose degrades to sequential.

### 6.2 Runtime dispatch

```
parallel_compose
    └── ffi_spawn (WASI import)
        └── wasi-threads::thread_spawn (if available)
        └── pthread_create (native target, future backend)
        └── sequential fallback (WASI preview 1 / browser
            without SharedArrayBuffer: spawn returns a
            thunk, await evaluates it inline — semantics
            preserved, no parallelism)
```

**Graceful degradation:** `parallel_compose` on a single-threaded
runtime still executes correctly — just without wall-clock
speedup. The user sees no error; the row claims are still
satisfied. This is the substrate-is-portable claim made real.

---

## 7. Hand-WAT / bootstrap implications

**TH substrate lives in user space, NOT in the seed compiler.**
The bootstrap compiler (`bootstrap/inka.wat` / `bootstrap/src/`)
is single-threaded; it compiles one module at a time sequentially.
This is intentional — the compile path is I/O-bound and
parallel compilation is a Phase II incremental-compilation
concern (IC walkthrough has already landed).

**What hand-WAT MUST add (for TH user code to emit correctly):**

1. **Emit path for `Thread` + `SharedMemory` effect ops.** Each
   op compiles to a WASM import (`wasi-threads` functions) or
   atomics opcode (`i32.atomic.rmw.add` etc.). Follows the
   existing "handler IS the backend" pattern (INSIGHTS).
2. **`parallel_compose` recognized as a runtime-provided
   handler.** Similar to `bump_allocator` today — the handler's
   arms map to runtime imports.
3. **Thread-local globals emitted correctly.** WASM 3.0
   `(global $heap_ptr (mut i32) (i32.const 0) (shared))` —
   shared globals initialized per-thread by runtime.

**None of this blocks L1.** Self-compilation doesn't exercise
`Thread` or `SharedMemory`. L1 closes on current hand-WAT + BT
linker.

**For L3 (crucible pass) including `crucible_parallel.nx`:** hand-WAT
needs TH emit path. Per Hβ §12.4: grows via Tier 3 incremental
self-hosting. VFINAL-on-partial-WAT compiles `src/backends/wasm.nx`
extended with Thread/SharedMemory emit; diff into hand-WAT;
audit paragraph-by-paragraph.

---

## 8. The eight interrogations applied

### 8.1 Graph?

`Thread` + `SharedMemory` effects join the existing effect
registry. Handler composition through `~>` is unchanged. The
graph gains two effect-name entries and their associated op
schemes; no new graph vocabulary.

### 8.2 Handler?

`parallel_compose` handler intercepts the branches of a `><`
compose. Per-thread handlers (bump_allocator, per-task state)
install inside each branch. The capability stack is the trust
hierarchy: outer handlers define thread boundaries; inner
handlers operate within them.

### 8.3 Verb?

`><` AND `<|` are the parallelism verbs (SUBSTRATE.md §"`<|`
vs `><`: Ownership Is the Structural Difference" — both are
parallelism; the structural distinction is input ownership,
not serial-vs-parallel). TH doesn't add a verb; TH adds the
handler that gives BOTH verbs multi-core semantics. One source
shape per verb; handler decides dispatch. Per Hβ.lower.diverge-
via-thread, PDiverge lowers as per-branch thunk closures over
a shared captured input + spawn/join, symmetric to PCompose's
per-branch thunks over independent inputs.

### 8.4 Row?

`Thread`, `SharedMemory`, `!SharedMemory` are row elements
composable with existing `+ - & !` algebra. Primitive #4's
subsumption is the Send/Sync substitute.

### 8.5 Ownership?

Cross-thread values are either `Bytes` (Pack/Unpack, thread-safe
by construction) or accessed via `SharedMemory` ops (atomic
discipline). `own` values cannot cross threads without
serialization — the compiler proves this at handler install via
row subsumption on the branch's declared ownership effects.

### 8.6 Refinement?

`type ThreadId = Int where self >= 0 && self < num_cores()` as
optional refinement. `type SharedAddr = Int where aligned(self, 4)`
for atomics. Verify discharges at SMT time.

### 8.7 Gradient?

Adding `~> parallel_compose` to a pipeline UNLOCKS `CParallelize`
(existing Capability variant in `src/mentl.nx:48`). Mentl's
Unlock tentacle can surface this as a voice line ("adding
`~> parallel_compose` unlocks multi-core for this pipeline —
proven safe by `!SharedMemory` in all branches").

### 8.8 Reason?

Each `spawn` / `await` records a Reason per existing discipline.
Thread identity (via `current_id`) is traceable through the
Reason chain; "why did this value arrive on thread 3?" becomes
a Why Engine query.

---

## 9. Forbidden patterns per TH site

- **Drift 1 (vtable):** NO dispatch table for Thread/SharedMemory
  ops. Same evidence-passing discipline as OneShot effects.
- **Drift 3 (string-keyed effect):** `RmwOp`, `WaitResult` are
  ADTs. No `"add"`/`"sub"` strings.
- **Drift 6 (primitive-type-special-case):** `Thread` is a
  regular effect. No compiler-intrinsic threading knowledge.
- **Drift 7 (parallel arrays):** `threads` is `List<Handle>`,
  not `(List<Int>, List<State>)`.
- **Drift 9 (deferred):** either land `spawn` + `await` +
  per-thread-Alloc together, or reject as "thread substrate
  partial." No "spawn today, await next walkthrough."
- **Drift 21 (Python class):** no `class Thread { ... }`. The
  handler IS the thread substrate.
- **Drift 24 (async/await keywords):** NOT `async fn task()`;
  NOT `await handle`. These are `perform spawn(fn)` and
  `perform await(handle)`. Effects, not keywords.

---

## 10. The crucible — `crucibles/crucible_parallel.nx`

*Added to the CRU set as the sixth crucible.*

**Claim:** a compute-bound task parallelizes across N cores when
`~> parallel_compose` is installed; single-threaded when it
isn't. Same source, different handler, different wall-clock.

**Fitness:**
- File compiles.
- Under `parallel_compose` handler: wall-clock scales sub-
  linearly with `num_cores()` (target: ≥ 2x speedup on 4-core
  laptop for embarrassingly-parallel workloads).
- Without `parallel_compose`: wall-clock is single-threaded
  baseline.
- Semantic equivalence: both runs produce bit-identical
  outputs (determinism preserved).

**Expected failure (pre-TH substrate):** `E_UndeclaredEffect` at
`spawn` / `await` perform sites. Closes when Thread effect lands
in `lib/runtime/threading.nx` + parallel_compose handler.

**Shape:**

```
// crucibles/crucible_parallel.nx
import runtime/threading
import runtime/binary

fn mandel_pixel(ref x: Float, ref y: Float) -> Int with !Alloc + !SharedMemory =
  // 256-iteration Mandelbrot escape test; embarrassingly parallel
  mandel_iter(x, y, 0.0, 0.0, 0, 256)

fn mandel_tile(ref x0: Float, ref y0: Float, ref w: Int, ref h: Int) -> Bytes
    with Thread + !SharedMemory =
  pack_mandel_tile(map_tile_pixels(x0, y0, w, h, (x, y) => mandel_pixel(x, y)))

fn render_parallel(ref w: Int, ref h: Int) -> Bytes with Thread =
  (mandel_tile(-2.0,  0.0, w, h / 2))
      ><
  (mandel_tile(-2.0, -1.0, w, h / 2))
    |> concat_bytes
    ~> parallel_compose

fn render_sequential(ref w: Int, ref h: Int) -> Bytes =
  (mandel_tile(-2.0,  0.0, w, h / 2))
      ><
  (mandel_tile(-2.0, -1.0, w, h / 2))
    |> concat_bytes
  // no handler install; `><` sequential
```

---

## 11. Landing discipline

**TH substrate is a peer to existing Phase II landings (FS, IC,
Phase A/B, Memory/Alloc declarations).** Not blocking for L1.
Lands pre-L3 (when `crucible_parallel.nx` is expected to pass).

**Priority:** add as PLAN Pending Work item 3 (after current 1
= LFeedback, 2 = Mentl voice) or 1.6 (after 1.5 = H7 MS runtime).

**Dispatch:** Opus inline for the walkthrough; inka-implementer
for the `lib/runtime/threading.nx` substrate + wasm.nx emit path;
Opus for the cross-wire / determinism audit.

---

## 12. Risk surface

| Risk | Mitigation |
|------|------------|
| WASM threads proposal differs across engines | Use `wasmtime` v44+ as baseline; document minimum engine version in Hβ §5.2 |
| wasi-threads not in WASI preview 1 | Graceful degradation to sequential; document in Hβ §5.2; preview 2 migration is a future walkthrough |
| Non-determinism from thread scheduling | `parallel_compose` preserves branch order in output tuple regardless of completion order (by design) |
| Thread-local bump_allocator arena exhaustion | Configurable `arena_size`; per-branch `~> temp_arena` inside branch for bounded scratch |
| Browser support (no SharedArrayBuffer in some contexts) | Sequential fallback; crucible flags browser environment and skips the scaling assertion |
| Cross-thread Send/Sync proof surfaces bugs | That's a win — the compiler catches data races at handler install, not at runtime |

---

## 13. What this walkthrough is NOT

- NOT a thread-pool implementation. `parallel_compose` uses OS
  threads; pool/executor strategies are sibling handlers.
- NOT a fiber / green-thread system. Those are separate handlers
  (user-level scheduling) on the same `Thread` effect signature.
- NOT a distributed-systems substrate. Cross-machine concurrency
  is handled by `~> cluster` handlers (DESIGN 9.1 federation) on
  top of Thread + Pack/Unpack.
- NOT a replacement for `~> race` (MSR Edit 5). `race` is
  MultiShot speculation over candidates; `parallel_compose` is
  OneShot dispatch over `><` branches. Different topology, different
  primitive.

---

## 14. Closing

The substrate already exists in DESIGN — thread-local Alloc is
specified Ch 7, Send/Sync as row is specified Ch 6, `><` is the
parallel-compose verb Ch 2. TH names what's needed to make it
run: one `Thread` effect, one `SharedMemory` effect, one
`parallel_compose` handler, one runtime import pathway, one
crucible.

**Multi-core is a handler installation.** `~> parallel_compose`
on an existing `><` pipeline turns it into a multi-threaded
program. No other source change. No `T: Send` bounds. No `unsafe`.
The Boolean effect algebra proves safety; the handler provides
dispatch; the runtime provides threads; the user writes `><`.

*Inka scales to N cores the same way Inka does anything else: a
handler on the substrate. The embarrassing universe is the one
where we forgot to install the handler; the real universe is the
one where adding one `~>` line lights up the rest of the CPU.*


---

## Addendum 2026-05-05 — `<|` is parallelism too

When TH was authored (2026-04-23) §3 + §8.3 named `><` as the
parallel-compose verb. SUBSTRATE.md §"`<|` vs `><`: Ownership
Is the Structural Difference" (commit during Hμ.cursor cascade)
established that BOTH `<|` and `><` are parallelism verbs; the
structural distinction is INPUT OWNERSHIP, not serial-vs-parallel.

Hβ.lower.diverge-via-thread (this addendum's referent) closes
the asymmetry at the lowering layer. After this commit:

- `<|` branches lower as per-branch thunk closures sharing one
  captured input by handle; spawn/join per thunk; tuple results.
- `><` branches lower as per-branch thunk closures with
  independent captures (existing path, unchanged).
- `parallel_compose` intercepts spawn/join uniformly across both
  verbs.

Sections §0.2, §3, §8.3, §10 of this walkthrough now read
"both `<|` and `><`" wherever they previously read "`><`."
The crucible (`crucible_parallel.nx`) gains a `<|`-shaped sibling
(`crucible_diverge_parallel.nx`) named as peer follow-up.

This addendum is the riffle-back closure (Anchor 7 step 4) for
TH against the Hβ.lower.diverge-via-thread landing.
