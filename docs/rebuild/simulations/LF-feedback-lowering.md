# LF — `<~` feedback state-machine lowering walkthrough

> **Status:** `[PENDING]`. Closes the last Priority 1 substrate gap. Gates Pending Work item 1 (`LFeedback` lowering implementation; ~100 lines emit-side in `src/backends/wasm.nx`). After this walkthrough closes, item 1 is prescriptive — no design left, transcription only.

*`<~` is Inka's genuine novelty — the only mainstream feedback operator with typed context and compile-time optimization. The verb, row, and type inference fire; emit is stubbed. This walkthrough specifies the LIR-to-WAT lowering.*

---

## 0. Framing — what `<~` is and why it's load-bearing

From DESIGN §2.5: `<~` is the feedback operator. `a <~ spec(N)` says "a's output flows back to a's input, delayed by spec(N)." The `spec` is one of `delay(N)`, `accumulate(init)`, or `filter_spec(N, coeffs)`.

**Semantics under different handlers:**
- Under `Sample(rate)` handler: `<~ delay(N)` means N-sample delay at `rate` Hz. Classic DSP IIR filter shape.
- Under `Tick` handler: `<~ delay(N)` means N-iteration delay. RNN hidden-state shape.
- Under `Clock(wall_ms)` handler: `<~ delay(N)` means N-ms delay. Control-loop shape.

**Same verb. Handler decides the unit.** An IIR filter and an RNN are the SAME TOPOLOGY (per DESIGN §10.2).

**Current state of `<~` in the compiler:**
- Parser recognizes `TLtTilde` token (§`parser.nx`).
- AST: `PipeExpr(PFeedback, body, spec)` constructed correctly.
- Inference: H3.1 landed `Sample(44100)` parameterized effects; `<~` correctly requires iterative ctx (`Sample | Tick | Clock` in effect row).
- Lower: `LFeedback(handle, body, spec)` LIR node constructed.
- **Emit: STUBBED.** `src/backends/wasm.nx` at the `LFeedback` arm currently emits `;; <~ feedback (iterative ctx)` as a WAT comment. The body is emitted but the feedback edge is not realized.

**What this walkthrough resolves:**
- The LIR-to-WAT lowering for `LFeedback`.
- The handler-local state slot allocation pattern.
- The integration with iterative-context handlers (Sample, Tick, Clock).
- Multi-shot vs one-shot resume discipline when `<~` interacts with multi-shot handlers (e.g., training via autodiff_tape).

**What this walkthrough does NOT cover:**
- Non-`<~` verb emission (already live).
- Iterative-context handler implementations (live in `src/clock.nx`; already substrate).
- Multi-shot × arena policy (tracked separately; default Replay-safe per Decisions Ledger).

---

## 1. The lowering method

### 1.1 The LFeedback LIR shape

Current form (already in `src/lower.nx` and `src/types.nx`):

```
type LowExpr
  = ...
  | LFeedback(Int, LowExpr, LowExpr)        // handle, body, spec
```

- `handle` — the graph handle for the feedback expression's type (the result type).
- `body` — the LIR of the pipeline being fed back (e.g., `gain(alpha) |> tanh |> saturate`).
- `spec` — the LIR of the feedback-spec value (e.g., `delay(1)` compiled).

### 1.2 The lowering strategy — state-machine per iteration

**The thesis:** each `<~` becomes a **state slot in the enclosing handler's state record**, plus a load-then-store protocol around the body's invocation.

**At iteration N:**
1. Load the previous iteration's output from state slot.
2. Feed it into body as the "feedback value" (accessible via the spec's get semantics).
3. Body computes the current iteration's output.
4. Store the current output into state slot (for iteration N+1).
5. Return current output.

**Pseudo-WAT shape** (per-call, inside a handler arm):

```wat
;; <~ feedback: load prior, invoke body, store current
(block $fb_block
  (local.set $fb_prior (i32.load offset=FB_SLOT (local.get $handler_state)))
  ;; body uses $fb_prior as its feedback-value input
  (call $body_fn ... (local.get $fb_prior))
  (local.tee $fb_current)
  (i32.store offset=FB_SLOT (local.get $handler_state) (local.get $fb_current))
  ;; result on the stack
)
```

**Where `FB_SLOT` is:** an offset into the enclosing handler's state record allocated at the time of `<~`'s graph registration.

### 1.3 Spec encoding

Three feedback-spec forms:

- `delay(N)` — N-step delay. State is an N-slot ring buffer. For N=1 (the overwhelmingly common case), it's a single slot.
- `accumulate(init)` — running accumulator. State is the accumulator value; body receives prior accumulator as feedback input; body produces new accumulator.
- `filter_spec(N, coeffs)` — N-tap filter. State is an N-slot ring buffer. Coeffs are compile-time-known; feedback value is the filter's prior output.

**v1 scope: `delay(1)` only.** The overwhelmingly common case (DSP IIR filters with 1-sample feedback; RNN hidden state with 1-step feedback). Longer delays + accumulator + filter_spec land post-first-light when specific domains need them.

Rationale: first-light's compiler doesn't use `<~` at all (no feedback in the compiler's own source); DSP and ML stdlib (`lib/dsp/`, `lib/ml/`) use `<~ delay(1)` predominantly. v1 covers 95% of use; the rest is post-first-light extension.

### 1.4 State-slot allocation

At `LFeedback`'s lower step, the compiler allocates a slot in the enclosing handler's state record:

```
// In src/lower.nx, during LFeedback lowering:
fn lower_feedback(handle, body, spec) with LowerCtx = {
  // Allocate a slot in the current handler's state.
  let slot_offset = perform alloc_handler_state_slot("__fb_" ++ show(handle), i32_type)
  // Emit as LFeedback with the slot offset attached.
  LFeedbackEmit(handle, body, spec, slot_offset)
}
```

This requires:
- `alloc_handler_state_slot(name, ty) -> Int` op on LowerCtx (adds a field to the current handler's state record, returns offset). ~10 lines of new LowerCtx op + 5 lines for the arm.
- A new LIR variant `LFeedbackEmit(handle, body, spec, offset)` OR reuse `LFeedback` with the offset stored in spec's compiled form (cleaner; recommended).

**Chosen form:** reuse `LFeedback(handle, body, spec)` with `spec` at lower-time being a `FeedbackSpecCompiled(Delay(1, slot_offset))` or similar. The spec's compiled form carries the slot offset.

### 1.5 WAT emission

At emit, the `LFeedback` arm in `src/backends/wasm.nx` replaces the current stub with:

```
LFeedback(_h, body, spec_compiled) => {
  // Read slot offset from compiled spec
  let offset = extract_slot_offset(spec_compiled)
  // Emit load of prior feedback value
  perform wat_emit("    (local.set $fb_prior (i32.load offset=")
  perform wat_emit(show(offset))
  perform wat_emit(" (local.get $handler_state)))\n")
  // Emit body (body is lowered WITH the expectation that $fb_prior is in scope)
  emit_expr(body)
  // Store current value into slot
  perform wat_emit("    (local.tee $fb_current)\n")
  perform wat_emit("    (i32.store offset=")
  perform wat_emit(show(offset))
  perform wat_emit(" (local.get $handler_state) (local.get $fb_current))\n")
}
```

~20 lines of emit code replacing the current 2-line stub.

### 1.6 Body inference — body needs `$fb_prior` in scope

**Open sub-question:** the body's inner expression needs access to the feedback-value (the prior output). How does the body reference it?

Current design from DESIGN §2.5 and H3.1:
- `<~` introduces a local binding for the feedback value automatically at the body's entry.
- The binding's name is implicit (accessed as the body's first parameter, OR via a pre-declared `feedback` identifier).

**v1 choice:** the feedback value is implicit as `$fb_prior` in the emitted WAT scope. The body is lowered with the expectation that one additional local is present. No source-level `feedback` identifier; the user doesn't name it because they don't need to — it's the body's implicit input.

**Example compilation:**

Source:
```
fn iir(input, alpha) with Sample(44100) =
  input
    |> gain(alpha)
    <~ delay(1)
```

Expected WAT (simplified):
```wat
(func $iir (param $input f32) (param $alpha f32) (param $handler_state i32) (result f32)
  (local $fb_prior f32)
  (local $fb_current f32)
  (local.set $fb_prior (f32.load offset=0 (local.get $handler_state)))
  (local.set $input_plus (f32.add (local.get $input) (f32.mul (local.get $alpha) (local.get $fb_prior))))
  ;; (body computed; $input_plus is body's result)
  (local.tee $fb_current (local.get $input_plus))
  (f32.store offset=0 (local.get $handler_state) (local.get $fb_current))
  (local.get $fb_current)
)
```

The body uses `$fb_prior` to read the prior feedback value, produces `$fb_current`, which is stored and returned.

### 1.7 Iterative-context gate

`<~` REQUIRES an iterative context: one of `Sample`, `Tick`, `Clock` must be in the effect row at the site. Inference enforces this with `E_FeedbackNoContext` if absent.

This walkthrough doesn't change the gate; it's already live. It just names it: LFeedback emit runs under an assumed iterative-context handler; that handler owns the state record where `$handler_state` points.

---

## 2. The eight interrogations

### 2.1 Graph?

The graph already holds the feedback expression's type + the iterative-context row. LFeedback emit reads from the graph; no re-derivation.

### 2.2 Handler?

The iterative-context handler (`sample_real`, `tick_real`, `clock_real`, etc.) OWNS the state record with the feedback slot. Emit reads/writes the slot; handler arms can also manipulate it (e.g., a `tick_record` handler that captures the feedback values for replay).

### 2.3 Verb?

`<~` IS the verb being emitted. The emit arm IS the verb's realization.

### 2.4 Row?

`<~` is in a row containing `Sample(rate) | Tick | Clock` — the iterative-context constraint.

### 2.5 Ownership?

Feedback value is copied each iteration (f32 in DSP, i32 RNN hidden state, etc.). If it were `own`, the slot's load-store would be a consume-replace pattern. v1 scope is primitive/value types; `own` feedback is post-first-light extension.

### 2.6 Refinement?

`delay(N)` has `N: Int where N >= 1`. Refinement discharge at spec construction.

### 2.7 Gradient?

Adding `with Sample(44100)` declares the iterative context; unlocks real-time DSP interpretation of `<~`. Declaring `<~ delay(1)` unlocks the one-slot WAT pattern.

### 2.8 Reason?

Each LFeedback emission leaves a Reason: `Located(span, Inferred("feedback slot allocation in handler state"))`.

---

## 3. Forbidden-pattern list

- **Drift 1 (Rust vtable):** feedback is NOT a "method on a feedback object." It's a state slot + load-store protocol. Forbidden: introducing an `IFeedback` interface or virtual call.
- **Drift 5 (C calling convention):** `$handler_state` is NOT a separate threading parameter; it's part of the uniformly-allocated handler state record (γ crystallization #8). Forbidden: thread `$fb_state` separately.
- **Drift 6 (primitive-type-special-case):** `f32` feedback + `i32` feedback + record feedback all use the same protocol. Forbidden: separate paths for "simple" vs "compound" feedback.
- **Drift 9 (deferred-by-omission):** v1 delay(1) scope is explicit and named. `accumulate`/`filter_spec`/`delay(N>1)` get their own follow-up walkthroughs (LF.1, LF.2, LF.3) named in PLAN.md.

---

## 4. Edits as literal tokens

### 4.1 Extend `src/lower.nx`

Add to the LFeedback lowering arm:

```
LFeedback(h, body, spec) => {
  let slot = perform alloc_handler_state_slot("__fb_" ++ show(h), ty_of_spec(spec))
  let compiled_spec = compile_spec(spec, slot)
  LFeedback(h, lower_expr(body), compiled_spec)
}
```

~10 lines.

### 4.2 Extend `LowerCtx` effect

Add `alloc_handler_state_slot(name: String, ty: Ty) -> Int` op to LowerCtx. ~5 lines.

### 4.3 Compile `spec` to `FeedbackSpecCompiled`

```
type FeedbackSpecCompiled
  = DelayCompiled(Int, Int)            // N, slot_offset
  // post-v1: AccumulateCompiled, FilterCompiled

fn compile_spec(spec, slot_offset) = match spec {
  LCall("delay", [n]) => DelayCompiled(extract_int(n), slot_offset),
  _ => fail("v1 supports only delay(N); see LF.1 / LF.2 for accumulate / filter")
}
```

~15 lines.

### 4.4 Rewrite `LFeedback` arm in `src/backends/wasm.nx`

Replace current stub with the emission pattern from §1.5:

```
LFeedback(_h, body, compiled_spec) => match compiled_spec {
  DelayCompiled(1, slot) => {
    perform wat_emit("    (local.set $fb_prior (f32.load offset=")
    perform wat_emit(show(slot))
    perform wat_emit(" (local.get $handler_state)))\n")
    emit_expr(body)
    perform wat_emit("    (local.tee $fb_current)\n")
    perform wat_emit("    (f32.store offset=")
    perform wat_emit(show(slot))
    perform wat_emit(" (local.get $handler_state) (local.get $fb_current))\n")
  },
  DelayCompiled(n, _) where n > 1 => {
    perform report("E_FeedbackDelayGreaterThanOne", current_span(),
      "v1 supports only delay(1); N=" ++ show(n) ++ " pending LF.1")
  }
}
```

~25 lines.

### 4.5 Add f32/i32 type variants

If the feedback value is a non-primitive type (record, variant), the slot stores a pointer instead of a value. Dispatch on `ty_of_spec` at compile time.

~10 lines for the type-dispatch on load/store.

### 4.6 Error catalog

New entry: `docs/errors/E_FeedbackDelayGreaterThanOne.md` (or better name). Documents v1 scope. Points to LF.1 follow-up when N>1 support lands.

---

## 5. Post-edit audit command

```
bash tools/drift-audit.sh src/lower.nx src/backends/wasm.nx
```

Verifies:
- No remaining stub-comment `;; <~ feedback (iterative ctx)` in emit output.
- Every `<~` in `lib/dsp/` + `lib/ml/` sources compiles without error.

**Determinism gate** (per DET walkthrough): the compiled WAT must be byte-identical on double-compile. `tools/determinism-gate.sh` enforces.

---

## 6. Landing discipline

LF lands as ONE commit (item 1 execution), after NS-naming + NS-structure + EH + SIMP close. Rationale: the feedback emit reads current-source state that's shaped by simplification; if LF lands first, simplification may rewrite it.

Actually — revision: LF is **independent of naming/structure/simplification** at the semantic level. It only touches `src/lower.nx` + `src/backends/wasm.nx`. BUT: those files will be renamed / moved during the restructure sweep. LF's edits would be churned by item 17' restructure.

**Decision:** LF lands AFTER item 17' restructure (so file paths are stable). LF rides through the existing structure at that point.

---

## 7. Dispatch

**Option A (dual-tier Sonnet):** for the implementation edits in src/lower.nx + src/backends/wasm.nx. Sonnet can follow the prescriptive rewrite patterns from §4.

**Option B (Opus-on-Opus):** if a subtle interaction surfaces during implementation — e.g., feedback-value type dispatch turns out more complex than §4.5 anticipates.

**Option C (Opus inline):** current session. Feasible for ~100 lines.

**Recommendation:** Option C — since it's ~100 lines of prescriptive transcription, Opus inline is fastest.

---

## 8. What closes when LF lands

- Item 1 (LFeedback state-machine lowering) complete.
- `<~ delay(1)` works end-to-end: parse → infer → lower → emit → WAT.
- `lib/dsp/signal.nx` + `lib/dsp/processors.nx` + `lib/ml/autodiff.nx` compile successfully.
- The DSP thesis scenario (DESIGN 10.2, a-day.md "1000 DSP + RT") fires in WAT, not just in paper simulation.
- The scoreboard `docs/traces/a-day.md` flips the `[substrate pending]` tag for `<~` to `[LIVE]`.

**Sub-handles split off** (named in PLAN.md for future work):

- **LF.1** — `delay(N)` for N > 1. Ring-buffer state allocation + rotating index + modular load. Post-first-light.
- **LF.2** — `accumulate(init)` feedback. Single-slot state + accumulator update pattern. Post-first-light.
- **LF.3** — `filter_spec(N, coeffs)` feedback. N-tap filter state + coeff inlining. Post-first-light.

---

## 9. Riffle-back

1. Verify `lib/dsp/signal.nx` tests pass after LF. Deterministic output, proper frequency response for test signals.
2. Verify compile time hasn't regressed materially (~100 lines of emit code shouldn't slow things down).
3. Check that non-`<~` emit paths unchanged by the LF edits (no regression in existing compile outputs).

---

## 10. Closing

LF closes the last Priority 1 substrate gap. The `<~` verb — Inka's genuine novelty — compiles to WAT correctly for the v1 scope of `delay(1)`. DSP and ML stdlib modules work end-to-end. The `[substrate pending]` tag on feedback in `a-day.md` flips to `[LIVE]`.

**One walkthrough, one commit, feedback fully realized.**
