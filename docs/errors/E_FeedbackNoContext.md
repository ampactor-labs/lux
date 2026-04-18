# E_FeedbackNoContext

**Kind:** Error
**Emitted by:** inference (spec 04, `<~` feedback handling)
**Applicability:** MachineApplicable

## Summary

A `<~` feedback operator appears without an ambient iterative
context handler (`Clock`, `Tick`, or `Sample`). The back-edge is
well-defined only under a handler that decides what "one step of
delay" means; without one, the cycle has no time.

## Why it matters

`<~` is the one pipe verb that closes a cycle (DESIGN.md Ch 2).
The `delay(1)` on the right of `<~` is a count of *time units*,
but the unit is the ambient handler's choice — under `Sample(44100)`
it's one audio sample (an IIR filter); under `Tick` it's one logical
step (an iterative algorithm); under `Clock(wall_ms=10)` it's 10 ms
(a control loop). Without an iterative context installed, the
operator is semantically incomplete — not a hang, a type error.

## Canonical fix

Install one of the three iterative-context handlers around the
expression:

- `~> sample_handler(44100)` for DSP / audio
- `~> tick_real` for iterative algorithms / RNN training
- `~> clock_real` for control loops / sensors

Or lift the `<~` out of its current scope to a location where an
iterative context is already installed.

## Example

```lux
fn iir(input) = input |> biquad <~ delay(1)
// E_FeedbackNoContext at line 1: <~ requires an iterative context
//   fix: wrap the call site with ~> sample_handler(44100)
```
