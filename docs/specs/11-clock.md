# 11 — Clock: time as a first-class effect family

**Purpose.** Time is the effect the industry cannot get right.
Mentl makes it first-class: Clock / Tick / Sample / Deadline as peer
effects, each with its own capability negation (`!Clock`, `!Tick`,
`!Deadline`), each with a default handler and a test/record/replay
handler family. Every compilation gate that depends on determinism,
real-time, or causal ordering falls out of this substrate.

**Kernel primitives implemented:** #2 (handlers with typed resume
discipline — time is a handler, not a runtime service), #4
(Boolean algebra — `!Clock`, `!Tick`, `!Deadline` are the usual
negation mechanism). The `<~` feedback verb (primitive #3)
requires an iterative context established by one of these
handlers; Clock's `Sample(rate)` handler is what makes a
`<~ delay(N)` mean "N samples at 44100Hz" vs. "N ticks" vs. "N
ms of wall time." The handler decides the unit.

**Research anchors.**
- Google Spanner / TrueTime — bounded-uncertainty time as the
  foundation for global consistency.
- Erlang/OTP telemetry — handlers for wall, monotonic, and logical
  clocks.
- Haskell reactive-banana / Elm signals — time-indexed streams.
- Control theory — sampled systems, deadline guarantees.
- DSP — sample-rate as the universal iteration clock.

---

## The four effects

```lux
effect Clock {
  now() -> Instant                          @resume=OneShot
  sleep(Duration) -> ()                     @resume=OneShot
  deadline_remaining() -> Option(Duration)  @resume=OneShot
}

effect Tick {
  tick() -> ()                              @resume=OneShot
  current_tick() -> Int                     @resume=OneShot
}

effect Sample {
  sample_rate() -> Int                      @resume=OneShot
  advance_sample() -> ()                    @resume=OneShot
  current_sample() -> Int                   @resume=OneShot
}

effect Deadline {
  deadline() -> Instant                     @resume=OneShot
  remaining() -> Duration                   @resume=OneShot
}
```

**Why four, not one.** Different domains need different timing
concepts:
- **Clock**: wall time. Used by any code that sleeps, logs
  timestamps, enforces wall-clock deadlines.
- **Tick**: logical time. Monotonic counter with no wall-clock
  relationship. Used by iterative algorithms, fixpoint loops,
  causal/vector clocks, distributed systems.
- **Sample**: DSP sample rate. Integer sample counter tied to a
  known rate. Used by audio, sensors, fixed-rate simulation.
- **Deadline**: real-time deadlines. Separate from Clock because the
  *capability* is different — a `Deadline` handler guarantees the
  computation completes within a budget, independent of whether it
  reads wall time.

They're peers, not hierarchical. A DSP handler uses `Sample`. A
compile-time-safe function declares `!Clock` (no wall reads) while
possibly using `Tick` internally. A real-time handler declares
`Deadline` (must meet budget) without necessarily using `Clock`.

---

## Supporting ADTs

```lux
type Instant   = Instant(Int)        // nanoseconds since epoch (monotonic)
type Duration  = Duration(Int)       // nanoseconds
type SampleRate = Int                // samples per second (e.g., 44100)
```

Simple; refined in Arc F.1 to carry refinements (`Instant where self >= 0`).

---

## Handler tiers (per effect)

Each effect has four standard handlers, installed by compile context:

| Tier | Use | Semantics |
|---|---|---|
| **Real** | production / bootstrap | reads system clock, sleeps, etc. |
| **Test** | unit tests, property tests | fake clock; tests advance manually |
| **Record** | time-travel debugging | real handler + captures every event |
| **Replay** | test replay, deterministic reproduction | injects pre-recorded events; deterministic |

**The handler-swap thesis lands hardest here.** Source code reads
the clock via `perform now()`; the handler decides whether that's
syscall, test fixture, recording, or replay. Same code; four
capabilities.

### Example: the test clock

```lux
handler test_clock with state = Instant(0) {
  now()     => resume(state),
  sleep(d)  => resume(()) with state = state + d,
  deadline_remaining() => resume(None)
}

// test body calls `now()` / `sleep()` normally
handle test_body() with test_clock
```

No conditional code. No `#ifdef DEBUG`. No dependency-injection
framework. Handler swap.

---

## Capability negations

Spec 01's Boolean row algebra gives these for free:

- **`!Clock`** — function performs no `Clock` ops. Memoization-safe,
  compile-time-eval-safe, caching-safe for the `Clock` axis.
- **`!Tick`** — function advances no logical clock. Safe for parallel
  composition of iteration pipelines.
- **`!Sample`** — no DSP-rate dependency. A function declared
  `!Sample + !Alloc + !Clock` is safe for any DSP chain regardless
  of sample rate.
- **`!Deadline`** — function has no deadline obligation. Does NOT
  mean "no deadline" — it means the function is not part of a
  real-time-budgeted context and doesn't need to reason about budget.

### The real-time capability

A real-time-safe function declares:
```lux
fn audio_process(x: Sample) -> Sample with Sample, !Alloc, Deadline
```

The four constraints together prove:
- `Sample` — operates at a known sample rate.
- `!Alloc` — never allocates (no GC pauses).
- `Deadline` — budgeted; compile-time check if the compiler can bound
  operation count.

This is what DSP has been trying to express for decades. Mentl does it
as a consequence of the existing effect algebra.

---

## Integration with feedback (`<~`, spec 10)

`<~` requires an iterative context. Clock, Tick, and Sample all
satisfy that requirement. The specifier on the right of `<~`
interprets timing via the ambient handler:

```lux
// under Sample(44100): one-sample delay (IIR filter)
audio_input |> iir(a) <~ delay(1)

// under Tick: one logical step delay (iterative algorithm)
state |> step <~ delay(1)

// under Clock(wall_ms=10): 10 ms delay (control loop)
sensor_read |> pid <~ delay(1)
```

**One `<~` operator; four ambient interpretations.** The pipe draws
the topology; the handler supplies the clock. This is the DSP/ML/
control unification that the pipe algebra promised.

---

## Integration with Verify (spec 02, spec 06)

Deadline obligations interact with refinement types:

```lux
fn decode(input: Buffer) -> Message
  with !Alloc, Deadline
  where deadline_remaining() > Duration(1_000_000)   // 1ms budget
```

The refinement predicate references the `Deadline` effect's op.
`verify_ledger` in Phase 1 records the obligation; `verify_smt` in
Arc F.1 checks it against the call context's deadline. If the caller
doesn't provide at least 1ms, `E_RefinementRejected`.

---

## Integration with ownership (spec 07)

- **Clock events** (`Instant`, `Duration`): pure value types. No
  ownership concerns.
- **Timer handles** (implementation detail of the real handler):
  `own` — must be explicitly released to avoid OS resource leak.
  Never exposed at the surface; handled inside the real Clock handler.
- **Recording buffers** (Record handler): `own` — the handler owns
  its capture log and releases on handle-close.

---

## Canonical handlers landing

**Phase 1 ships:**
- `clock_real` — syscall-backed.
- `clock_test` — state-based fake, for testing.
- `tick_default` — monotonic counter.
- `sample_default(rate)` — fixed-rate sample counter.

**Arc F (when the supporting machinery arrives):**
- `clock_record` / `clock_replay` — time-travel debugging.
- `tick_vector` — vector clock for distributed handlers (F.x future).
- `deadline_realtime` — budget enforcement paired with F.5 native
  backend.

---

## Consumed by

- `06-effects-surface.md` — Clock / Tick / Sample / Deadline listed
  in the inventory with pointer here.
- `10-pipes.md` — `<~` iterative-context check accepts any of these.
- `02-ty.md` — refinements can reference these effects' ops.
- `07-ownership.md` — timer-handle ownership rules documented here.
- Arc F.4 (scoped arenas × real-time), Arc F.5 (native backend) —
  Deadline + !Alloc capability combination is their load-bearing
  claim.

---

## Rejected alternatives

- **One unified `Time` effect.** Forces DSP to read wall-clock, logic
  loops to think about sampling — conceptual leakage. Four peers;
  compose as needed.
- **Time as a primitive, not an effect.** Hardcodes it; no test
  clock, no record/replay, no deadline handler swap. Every valuable
  timing capability in Mentl comes FROM the effect status.
- **Deadline as a refinement on Clock rather than its own effect.**
  Real-time guarantees aren't about reading time; they're about
  completion budgets. Orthogonal capability.
- **Built-in sample-rate as a language constant.** Different DSP
  chains run at different rates (audio 48k, sensors 1k, video 60).
  Handler carries rate; source code portable.
