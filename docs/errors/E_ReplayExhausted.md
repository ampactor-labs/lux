# E_ReplayExhausted

**Kind:** Error
**Emitted by:** `clock.ka` (replay handlers — `clock_replay`, `tick_replay`)
**Applicability:** MaybeIncorrect

## Summary

A replay handler was asked for the next recorded value but its trace
had no more entries. The program under replay ran longer than the
recording covers.

## Why it matters

Record + replay is how Inka delivers deterministic time-travel
debugging: `clock_record` captures every `clock_now()` value into a
trace; `clock_replay(trace)` feeds those values back in order. When
replay outruns the trace, the handler has nothing to feed — which
means either the recording is incomplete, or the program's control
flow diverges between record and replay runs.

## Canonical fix

- **Extend the recording.** Run the original program further and
  re-capture. The trace should cover every clock read the replay
  performs.
- **Check for nondeterminism.** If record and replay take different
  paths, some other effect (Random, Input, Network) is unhandled —
  install a matching record/replay pair for it. Once every source
  of nondeterminism is replayed, the traces align.
- **Fail loud instead of resuming.** If this error surfaces at all,
  the replay is already untrustworthy; prefer to abort rather than
  keep going with a fabricated value.

## Example

```
E_ReplayExhausted: clock replay trace exhausted
  recorded entries: 42
  requested entry:  43
  likely:           the replay program ran one iteration longer
                    than the recorded run
  fix:              extend the recording, or install matching
                    record/replay for every nondeterministic effect
```
