# DM — DSP + ML libraries · Ultimate-Mentl rewrite

> **Status:** `[DRAFT 2026-04-23]`. The current `lib/dsp/` (445
> lines) + `lib/ml/` (115 lines) were written BEFORE the γ cascade
> closed. They predate H3.1 parameterized effects, `!Alloc` exercise,
> ownership-as-effect, real refinement types, the MO oracle loop,
> and the MS2 full-territory understanding. **Morgan's call
> 2026-04-23:** erase and re-write at Ultimate Mentl level — don't
> let short-sighted initial code hold back the thesis.
>
> *This walkthrough specifies the re-imagined DSP + ML libs that
> actually exercise all eight kernel primitives. Substrate after
> the walkthrough is the demonstration that DSP and ML are
> handler stacks on the one kernel, not separate domains.*

---

## 0. The drift the current code carries

**`lib/dsp/signal.mn:17-20`:**
```
// Capability effects — exist primarily to be NEGATED
effect Alloc { alloc_buffer(size: Int) -> List<Float> }
effect Network { fetch_param(url: String) -> String }
effect Feedback { delay_tap(samples: Int, x: Float) -> Float }
```

Three shadow effects. `Alloc` shadows runtime's substrate Alloc (Q-B.1 revised to option γ: DELETE). `Network` is a placeholder with one op and no handler. `Feedback` is a placeholder that would be redundant once `<~` lands (LF walkthrough).

**`lib/dsp/clock.mn` declares six effects** — Clock, Tick, Sample, Deadline, IterativeContext, HostClock — mostly unexercised. `IterativeContext` per NS-naming should be a row constraint, not an effect (already noted in NS-naming walkthrough but not yet swept).

**`lib/dsp/processors.mn`:** four handlers (passthrough / peak_tracker / warm_filter / bright_filter) without `!Alloc` annotations. `warm_filter` and `bright_filter` carry `state = 0.0` — OneShot state; no MS; no refinement on sample range.

**`lib/dsp/spectral.mn`:** `effect Distort` with one op. Mostly placeholder.

**`lib/ml/autodiff.mn`:** `effect Compute` declaration with matmul / relu / softmax ops. No tape handler. No inference handler. No autodiff actually implemented.

**`lib/ml/tensor.mn`:** `Tensor` type as alias. No shape refinement. No operations.

**The libs are skeletons.** They declare some effect signatures; few real handlers; no refinement; no ownership discipline; no MS exercise; no integration with the oracle loop.

**Delete, don't refactor.** Refactoring preserves the initial shape's assumptions. Re-writing from the eight primitives upward produces code that IS the substrate claim.

---

## 1. Ultimate-Mentl DSP — what the library becomes

### 1.1 Refinement-typed sample + frequency + gain

```
// lib/dsp/signal.mn (Ultimate)

/// A single audio sample. Normalized to [-1.0, 1.0]; clipping is
/// refinement-checked at each primitive boundary.
type Sample = Float where 0.0 - 1.0 <= self && self <= 1.0

/// Audio frequency in Hz. Constrained to Nyquist-safe range
/// (44.1kHz / 2 = 22050 Hz ceiling). Refinement discharged at
/// primitive install time per the ambient Sample rate.
type Hz = Float where 0.0 < self && self < 22050.0

/// Linear gain factor. Unity = 1.0. Attenuation in [0, 1); unity;
/// or amplification with clip-safety obligation on the output.
type Gain = Float where 0.0 <= self

/// dB value. Real-valued; sign indicates direction.
type Db = Float
```

**Primitive #6 exercised:** each refinement discharges at call
sites via the installed Verify handler (B.6 verify_smt lands
this). Out-of-range samples are compile-errors when provably
violating; runtime asserts otherwise (verify_ledger residue).

### 1.2 DSP effect + row discipline

```
/// The DSP process effect. Single op; handlers interpret as
/// audio-rate, control-rate, or spectral-rate per install.
effect DSP {
    process(x: Sample) -> Sample                     @resume=OneShot
}
```

**Primitive #4 exercised:** every pure DSP primitive declared
`with Pure + !Alloc + !SharedMemory + !IO`. Transitive row proof
across a chain:

```
/// Soft-clip: non-linear saturation. Pure; allocation-free.
fn soft_clip(own x: Sample) -> own Sample with Pure + !Alloc =
    if x >= 0.0 { x / (1.0 + x) } else { x / (1.0 - x) }
```

No shadow Alloc effect. No `with Pure` on something that allocates. Every DSP primitive either allocates and declares it, or proves `!Alloc` transitively.

### 1.3 Ownership through the chain

```
/// Apply a gain factor to a sample. `own` input consumed, `own`
/// output returned. `!Alloc` via the no-alloc discipline.
fn gain(own x: Sample, ref factor: Gain) -> own Sample with Pure + !Alloc =
    x * factor
```

**Primitive #5 exercised:** `own` for the signal (consumed — the
pipeline is linear, not fork-amenable); `ref` for the gain factor
(borrowed, may be reused). `with Pure + !Alloc` proves the unit.

This ownership discipline matters because `<|` (fanout) sharing a
single `own Sample` is a compile-error — as it should be — because
duplicating a consumed sample breaks affine linearity. `><` with
independent samples is fine. The DSP library teaches this
distinction by its signatures.

### 1.4 Feedback as `<~` (not a shadow effect)

```
/// IIR filter: first-order low-pass. Feedback via <~ + delay
/// under the ambient Sample handler. No Feedback shadow effect
/// needed — the verb IS the substrate.
fn lowpass(own x: Sample, ref cutoff: Hz) -> own Sample
    with IterativeContext + Pure + !Alloc =
    let a = compute_alpha(cutoff)
    let feedback = x |> mix(_, previous) |> scale(a)
                       <~ delay(1, init = 0.0)
    feedback
```

**Primitive #3 exercised:** `<~` (B.9 LFeedback lowering lands)
draws the back-edge on the page. No `Feedback` effect-declaration
placeholder. The verb is the substrate; the LF walkthrough's
state-slot-in-handler-state-record pattern makes it real.

### 1.5 Multi-shot for adaptive filters

```
/// Adaptive LMS filter: multi-shot variant. Each sample, the
/// filter forks N hypotheses about the optimal tap weight; the
/// best-proven survives per sample.
fn adaptive_lms(own x: Sample, ref target: Sample)
    -> own Sample
    with Choice + IterativeContext + !Alloc =
    let tap_hypothesis = perform choose([0.01, 0.02, 0.05, 0.1])
    let prediction = x |> scale(tap_hypothesis)
    let error = target - prediction
    if error < threshold { prediction }
    else { perform fail() }
```

**Primitive #2 × Primitive #4 exercised:** `Choice` multi-shot
forks per-sample; handler (`backtrack` or `best_survival`)
selects; `!Alloc` remains provable because MS under replay_safe
re-performs upstream without allocation (AM walkthrough substrate
+ Hβ §12 MS runtime).

MS2 §1.3.5 particle-filter topology made concrete.

### 1.6 Parameterized Clock — H3.1 exercise

```
/// Audio-rate context. Parameterized by sample rate; different
/// rates are different effects at the row level.
effect Sample(rate: Int) {
    tick() -> ()                                     @resume=OneShot
    current_sample() -> Int                          @resume=OneShot
}
```

**Primitive #4 × H3.1 exercised:** `with Sample(44100)` and
`with Sample(48000)` are different rows. Mixing them without
explicit resampling is a compile error. User resamples via a
dedicated `resample(from: Sample(A), to: Sample(B))` handler.

`IterativeContext` effect in the current code is DELETED —
replaced by row-constraint `with Sample(_) | Tick | Clock(_)`
where `_` is the parameterization. Per NS-naming note.

### 1.7 The handler stack — real-time audio callback

```
fn audio_callback(own frame: StereoFrame) -> own StereoFrame
    with Sample(48000) + Pure + !Alloc + !SharedMemory + !Network =
    let (l, r) = unpack_stereo(frame)

    (l |> highpass(80.0) |> compress(ratio=4.0, threshold=-12.0) |> soft_clip)
        ><
    (r |> highpass(80.0) |> compress(ratio=4.0, threshold=-12.0) |> soft_clip)
        |> pack_stereo
```

**All eight primitives in one signature:**
- Graph: env resolves every DSP primitive call.
- Handler: Sample(48000) installed outer; pure primitives interior.
- Verb: `><` for independent channels; `|>` for per-channel chain.
- Row: `Pure + !Alloc + !SharedMemory + !Network` — real-time proven.
- Ownership: `own frame` consumed, fresh `own StereoFrame` returned.
- Refinement: `Sample` bounds discharged at each primitive boundary.
- Gradient: annotation stack is the user's explicit declaration; Mentl's Teach tentacle could have suggested each annotation per the gradient step.
- Reason: every `graph_bind` records why — walkable for "why is this safe for audio callback?".

**~20 lines of real-time audio with a complete type-level safety proof.** This is Ultimate Mentl.

### 1.8 Spectral primitives — domain operations not DSP shadows

```
/// Fast Fourier Transform. Allocates a complex-spectrum buffer;
/// caller must install arena if using inside !Alloc context.
fn fft(own samples: List<Sample>) -> own Spectrum with Alloc =
    // ... DIT radix-2 implementation via runtime/memory's alloc

/// Short-time Fourier transform. Window + FFT + stride.
fn stft(own samples: List<Sample>, ref window: Window, ref stride: Int)
    -> own List<Spectrum> with Alloc + !SharedMemory =
    // ...
```

**No shadow Distort effect.** Distortion is a regular fn over DSP.
Spectral ops are allocating by nature (complex buffers) and
declare it honestly.

---

## 2. Ultimate-Mentl ML — what the library becomes

### 2.1 Tensor with shape refinement

```
/// A tensor with element type T and shape S. The shape IS a
/// value-level list of dimensions; the refinement ensures the
/// flat-buffer length matches the shape product.
type Tensor<T, S: List<Int>> where
    self.len == product(S) &&
    self.shape == S

/// 1D tensor of a known length.
type Vector<T, N: Int> = Tensor<T, [N]>

/// 2D tensor (matrix).
type Matrix<T, M: Int, N: Int> = Tensor<T, [M, N]>
```

**Primitive #6 exercised:** shape-checking at compile time. A
function `fn matmul(a: Matrix<f32, M, K>, b: Matrix<f32, K, N>) ->
Matrix<f32, M, N>` is type-safe by construction; mismatched shapes
are compile errors, not runtime crashes.

This is stronger than PyTorch/JAX/Stan — shape errors surface at
compile time with no runtime dispatch cost.

### 2.2 Compute effect — the ML operational vocabulary

```
/// The Compute effect — ML's operational substrate. Handlers
/// decide whether each op is computed directly, recorded on a
/// tape for autodiff, or accumulated into a graph for fused
/// execution.
effect Compute {
    matmul(ref a: Matrix<f32, M, K>, ref b: Matrix<f32, K, N>)
        -> Tensor<f32, [M, N]>                       @resume=OneShot

    relu(ref x: Tensor<f32, S>)
        -> Tensor<f32, S>                            @resume=OneShot

    softmax(ref x: Vector<f32, N>)
        -> Vector<f32, N>                            @resume=OneShot

    add(ref a: Tensor<f32, S>, ref b: Tensor<f32, S>)
        -> Tensor<f32, S>                            @resume=OneShot

    // ... (conv, batchnorm, etc., as needed by crucibles)
}
```

**Primitive #2 exercised:** single effect, many ops, OneShot
discipline. Handler decides implementation.

### 2.3 Three peer Compute handlers — thesis on display

```
/// Direct compute: run each op natively, discard intermediate
/// state, ready for inference. Allocation-free provable when
/// intermediate tensors use caller's arena.
handler compute_direct with !Alloc + Memory {
    matmul(a, b) => resume(native_matmul(a, b)),
    relu(x) => resume(native_relu(x)),
    softmax(x) => resume(native_softmax(x)),
    add(a, b) => resume(native_add(a, b))
}

/// Training tape: record each op's inputs + output; the tape
/// enables backward pass for gradient computation.
handler compute_training with tape = [] {
    matmul(a, b) => {
        let out = native_matmul(a, b)
        resume(out) with tape = [TMatMul(a, b, out)] ++ tape
    },
    relu(x) => {
        let out = native_relu(x)
        resume(out) with tape = [TRelu(x, out)] ++ tape
    },
    softmax(x) => {
        let out = native_softmax(x)
        resume(out) with tape = [TSoftmax(x, out)] ++ tape
    },
    add(a, b) => {
        let out = native_add(a, b)
        resume(out) with tape = [TAdd(a, b, out)] ++ tape
    }
}

/// Graph-build handler: don't compute; build a dataflow graph
/// for fused execution (XLA-style). The handler's state IS the
/// computation graph accumulated from performs.
handler compute_graph_build with nodes = [], edges = [] {
    matmul(a, b) => {
        let handle = fresh_handle()
        resume(materialized_tensor(handle))
            with nodes = [NMatMul(a, b, handle)] ++ nodes
    },
    // ... similar for relu, softmax, add
}
```

**Primitive #2 × Primitive #4:** one `forward` fn; three peer
handlers; three different execution strategies. No framework. No
mode-switch. Handler swap.

### 2.4 Autodiff as backward-pass handler composition

```
/// Gradient computation: reverse-mode autodiff over the tape.
/// Each op's gradient is defined once; the backward pass is a
/// straight-line traversal of the tape in reverse.
fn backward(ref tape: List<TapeEntry>, ref loss_grad: Tensor) ->
    List<(TensorId, Tensor)> with Compute + Alloc =
    // walk tape in reverse, accumulate gradients per input tensor
    tape |> reverse |> fold_with_grads(loss_grad)

/// Training step: forward + compute_training handler + backward +
/// parameter update. Composes at the Compute effect boundary.
fn train_step(ref model: Model, ref batch: Batch) ->
    Model with Compute + Alloc =
    let tape_result = forward(model, batch) ~> compute_training
    let loss_grad = compute_loss(tape_result.output, batch.target)
    let grads = backward(tape_result.tape, loss_grad)
    update_params(model, grads, learning_rate)
```

**Primitive #8 exercised:** the tape is a Reason chain of sorts —
each op's record preserves the input-output relationship, which
the backward pass walks deterministically.

### 2.5 Multi-shot for meta-learning + hyperparameter search

```
/// Hyperparameter search: fork over candidate configurations;
/// each configuration trains; best-validating survives.
fn search_hyperparams(ref train_set, ref val_set) ->
    Model with Compute + Choice + Alloc =
    let lr = perform choose([0.001, 0.003, 0.01, 0.03])
    let depth = perform choose([2, 3, 4])
    let model = init_model(depth)
    let trained = train(model, train_set, lr) ~> compute_training
    let val_loss = eval(trained, val_set) ~> compute_direct
    if val_loss < threshold { trained }
    else { perform fail() }
```

**Primitive #2 × MS × Primitive #4 × Primitive #6:** MS enumerates
hyperparams; Verify discharges `val_loss < threshold` (refinement
obligation on the trained model); failing hyperparams dead-end;
best survives. 12 lines of hyperparameter search.

### 2.6 Federated learning via `><`

```
/// N clients train independently; posteriors aggregate at
/// convergence. `><` preserves client isolation; Pack/Unpack
/// crosses the wire with no shared memory.
fn federated_train(ref clients: List<Client>) ->
    Model with Compute + Thread + Pack + Alloc =
    clients
        |> map(client_train_branch)                  // each client's branch
        ~> parallel_compose                            // cores used
        |> aggregate_posteriors                        // consensus step

fn client_train_branch(ref client: Client) -> PosteriorBytes
    with Compute + Pack + !SharedMemory =
    let local_model = train(client.model, client.data, client.lr)
    pack(local_model.posterior)
```

**Primitive #3 (`><` via map + parallel_compose) × Primitive #5
(own isolation) × Primitive #4 (!SharedMemory):** federated
training as a handler stack. No framework.

### 2.7 Tensor operations — domain primitives not placeholders

```
/// Element-wise addition. Shape-preserving; compile-time shape
/// check enforces operand compatibility.
fn elem_add<S>(own a: Tensor<f32, S>, own b: Tensor<f32, S>)
    -> own Tensor<f32, S> with Compute = ...

/// Matrix transpose. Shape transposition reflected in the type.
fn transpose<M, N>(own a: Matrix<f32, M, N>)
    -> own Matrix<f32, N, M> with Compute = ...

/// Tensor reshape. Shape product must match (refinement-checked
/// at call site).
fn reshape<S1: List<Int>, S2: List<Int>>(
    own a: Tensor<f32, S1>, ref new_shape: S2
) -> own Tensor<f32, S2>
    with Compute where product(S1) == product(S2) = ...
```

**Primitive #6:** every shape is in the type. Shape errors are
compile errors. Runtime dispatch cost: zero.

---

## 3. Integration — DSP meets ML meets crucibles

### 3.1 The composition — Pulse foreshadowing

A Pulse audio-effect that uses an ML model to predict optimal
gain compression:

```
fn ml_guided_compress(
    own x: Sample,
    ref model: Model,
    ref context: List<Sample>
) -> own Sample
    with Sample(48000) + Compute + !Alloc + !SharedMemory =
    // Model inference (lightweight; allocates in caller's arena)
    let gain_factor = run_model(model, context) ~> compute_direct
    x |> scale(gain_factor)
```

**Both libs compose:** DSP's Sample bounds, ML's Compute effect,
all under a real-time-safe row. The thesis (domain unification
via handler stacks) proven in one line.

### 3.2 Crucible alignment

- **crucible_dsp.mn** (CRU §1a) becomes non-trivial — exercises
  Ultimate DSP's refinement + ownership + `!Alloc` propagation.
  No shadow effects. Real substrate claims.
- **crucible_ml.mn** (CRU §1b) exercises three peer compute
  handlers; autodiff tape via MS; hyperparameter search via
  `Choice`; federated via `><`. ML framework dissolves into the
  handler stack.
- **crucible_parallel.mn** (CRU §1f via TH) can extend beyond
  Mandelbrot — use actual ML parallel training to prove multi-core
  × Compute handler composition.

### 3.3 Pulse composition

Per DP-F.5 Pulse enhancement: Pulse's DSP + ML modules are
Ultimate-Mentl DSP + ML as specified here. Morgan's "enhance now
that we know so much more" means Pulse is DP-F.5's
demonstration that both libs WORK at scale.

---

## 4. What's deleted, what's kept

### Files DELETED

- `lib/dsp/signal.mn` (40 lines) — shadow Alloc/Network/Feedback;
  stub pure processors.
- `lib/dsp/processors.mn` (83 lines) — peak_tracker/warm_filter/
  bright_filter without !Alloc.
- `lib/dsp/clock.mn` (231 lines) — six effects, mostly unexercised.
- `lib/dsp/spectral.mn` (91 lines) — Distort placeholder.
- `lib/ml/autodiff.mn` (59 lines) — Compute declaration, no
  handlers.
- `lib/ml/tensor.mn` (56 lines) — Tensor alias, no operations.

**Total: 560 lines erased.**

### Files RE-WRITTEN (new versions at Ultimate Mentl level)

- `lib/dsp/signal.mn` — refinement types + pure primitives with
  proper rows. Target: ~200 lines.
- `lib/dsp/processors.mn` — filters + compressors with feedback
  via `<~`. Target: ~300 lines.
- `lib/dsp/clock.mn` — parameterized Sample(rate) effect + Tick +
  Clock(wall_ms). Target: ~100 lines.
- `lib/dsp/spectral.mn` — fft / stft / istft with allocating row.
  Target: ~200 lines.
- `lib/ml/autodiff.mn` — Compute effect + three peer handlers
  (direct / training / graph_build) + backward. Target: ~300
  lines.
- `lib/ml/tensor.mn` — shape-refined Tensor + element-wise +
  matmul + reshape + transpose. Target: ~400 lines.

**Total: ~1500 lines of Ultimate-Mentl substrate** replacing 560
lines of pre-γ-cascade code. **2.7× more substrate expressing 8
primitives properly** instead of stub signatures.

### NEW files (that old lib didn't have)

- `lib/dsp/feedback.mn` — IIR / LMS / state-space filters using
  `<~`. Target: ~200 lines.
- `lib/dsp/adaptive.mn` — MS-based adaptive filtering (particle,
  Kalman). Target: ~250 lines.
- `lib/ml/optim.mn` — SGD / Adam / LBFGS as peer handlers on a
  common `Optimizer` effect. Target: ~200 lines.
- `lib/ml/federated.mn` — federated training via `><` +
  Pack/Unpack. Target: ~150 lines.

---

## 5. Eight-interrogations applied to the whole rewrite

- **Graph?** Every DSP/ML primitive gets a proper env entry with
  scheme including ownership + row + refinement obligations.
  Today's placeholder effects had no substance; now the graph
  holds real structure.
- **Handler?** Handlers per substrate contract: compute_direct,
  compute_training, compute_graph_build (ML); bump_allocator,
  temp_arena (DSP scratch). Every handler composable via `~>`.
- **Verb?** `|>` for chains, `><` for stereo + federated, `<~`
  for feedback filters, `~>` for handler install, `<|` for
  diverge (e.g., multi-band analysis).
- **Row?** Every fn has a row; `!Alloc + !SharedMemory + !IO +
  !Network` for real-time DSP; `Compute + Alloc` for training
  ML; `Compute + !Alloc` for inference ML.
- **Ownership?** `own Sample` consumed through chains; `ref
  model` borrowed across calls; no silent copies.
- **Refinement?** `type Sample = Float where ...` + `type Tensor<T,
  S> where len == product(S)`. Verify discharges.
- **Gradient?** Each fn demonstrates the gradient — start with
  inferred, add annotations progressively, unlock capabilities.
  Tutorial for these primitives.
- **Reason?** Every tape entry (ML) / feedback state slot (DSP)
  carries provenance. Why Engine walks both.

---

## 6. Forbidden patterns scoped to the rewrite

- **Drift 1 (vtable):** compute_direct / compute_training /
  compute_graph_build are handler declarations, NOT a
  `compute_backend: ComputeBackend` record-of-functions.
- **Drift 3 (string-keyed effect):** ML ops like `matmul` are
  effect-op declarations, not `"matmul"` strings dispatched via
  a framework lookup.
- **Drift 6 (primitive-type-special-case):** Sample / Hz / Db are
  refined over Float; not new primitive types.
- **Drift 8 (int-coded mode):** training vs inference is
  handler-swap, NOT `mode == TRAINING | INFERENCE`.
- **Drift 9 (deferred-by-omission):** no stub ops. If an op is
  declared, its handler implementations land in the same commit.
- **Drift 21 (Python class):** no `class Model { forward(...) }`;
  `Model` is an ADT; `forward` is a fn over Model.
- **Drift 25 (OOP):** no `self.forward(x)`; `forward(self, x)` if
  method-like style is desired.
- **Drift 30 (for/while):** loops are `<~` or `|> fold` or MS
  `Choice`; explicit for/while only when tail-recursion pattern
  doesn't fit (rare).

---

## 7. Sequencing — where this lands

**Phase B.10 DSP rewrite** — after B.1 (AL option γ delete) is
subsumed; B.10 replaces B.1 in the plan.

**Phase B.11 ML rewrite** — after B.2 (H7 MS runtime) since
ML's Compute-training handler uses MS via `[X] ++ acc` tape
prepend semantics + needs H7 emit for eventual fork-for-autodiff-
second-order scenarios.

**Phase C crucibles** — C.3 + C.4 become substantive (not just
minimal signature tests); depend on B.10 + B.11 respectively.

**Phase F.5 Pulse enhancement** — composes on Ultimate DSP + ML.

### The plan update

In `alright-let-s-put-together-silly-nova.md`:
- Replace **B.1** AL unification with **B.1 DM walkthrough landing
  + DSP/ML erasure preparation**.
- Add **B.10 DSP rewrite** (substantial; ~7-10 file landings).
- Add **B.11 ML rewrite** (substantial; ~5-7 file landings).
- Update C.3 + C.4 acceptance to reflect Ultimate DSP/ML.
- Update F.5 Pulse framing to compose on new libs.

---

## 8. Landing discipline

**Delete + re-write as separate commits:**

1. **Commit 1 — DM walkthrough lands.** Design contract for both
   rewrites.
2. **Commit 2 — Erase old libs.** `git rm lib/dsp/* lib/ml/*`.
   Tree breaks (nothing imports these; only crucibles reference,
   and crucibles haven't landed yet per C.1). Short-lived broken
   state acceptable between commits 2 and 3.
3. **Commit 3+ — Ultimate DSP re-writes** (per B.10 sub-landings).
   Each file lands with its walkthrough paragraph citations + full
   row discipline + refinement annotations.
4. **Commit N+ — Ultimate ML re-writes** (per B.11 sub-landings).
   Same discipline.

**Drift audit clean at each commit.**

**Each new file's substrate lands WHOLE:**
- All declared ops have handlers.
- All refinements have obligations (tracked in verify_ledger;
  discharged by verify_smt post-B.6).
- All ownership markers trace to actual consume/borrow sites.
- All rows propagate transitively.

No "signal.mn today, processors.mn next commit with partial
integration." Each file is a handle; the handle lands whole.

---

## 9. What this walkthrough is NOT

- Not a complete API spec for DSP or ML. That lands in the
  per-file substrate commits. This is the design contract.
- Not an endorsement of every primitive listed here. The
  re-write authors may choose different primitive sets based on
  crucible needs. This walkthrough names the SHAPE of the
  substrate; the primitive list is illustrative.
- Not a deprecation of Pulse. Pulse enhancement per DP-F.5 is
  post-first-light; this walkthrough is the foundation it
  composes on.
- Not a ban on the OLD code's patterns if they re-surface
  naturally. If after writing Ultimate ML we realize "the 2026-
  04-16 version of `Compute` effect was actually fine," we
  re-declare it and note the convergence. Walkthrough names the
  intent, not the rigid implementation.

---

## 10. The thesis restated through the rewrite

**DSP dissolves into handler stacks on one substrate.** Real-time
audio is a handler installed with `!Alloc + !SharedMemory` over
the Sample(rate) parameterized effect. Every stage traces to
primitives. No framework.

**ML dissolves similarly.** Training is `~> compute_training`;
inference is `~> compute_direct`; graph-build is `~> compute_graph_build`.
Same source. Three handlers. No PyTorch. No TensorFlow. No JAX.

**Pulse composes them.** Audio callback uses DSP; ML-guided
compression calls into Compute effect; federated training uses
`><` + Pack/Unpack. One medium; every domain; handler swap is
the extensibility mechanism.

**The old code was a skeleton** — declarations pretending to be
substrate. **The new code IS the substrate.** Every line
composes from the eight primitives; every claim the thesis
makes about DSP + ML unification is mechanically provable.

---

## 11. Open questions (few; most resolve during B.10/B.11 landings)

- **(DM-Q1) `Hz` ceiling parameterization.** Hard-coded 22050 assumes 44.1kHz. Should the ceiling be a function of the ambient Sample(rate)? If yes, refinement becomes dependent type — significant. Recommend: keep 22050 as v1; dependent refinement is post-first-light if needed.
- **(DM-Q2) Tensor shape as List<Int> vs type-level numbers.** List<Int> works for refinement; type-level Nat would be cleaner but requires dependent types. Recommend: List<Int> for v1.
- **(DM-Q3) Compute effect op list.** matmul / relu / softmax / add is minimum viable. conv / pool / batchnorm etc. ride on the same substrate; land when crucibles demand.
- **(DM-Q4) Autodiff second-order.** Not v1. MS + tape-over-tape substrate; lands post-first-light as MS2 §2.3 meta-learning domain crucible.
- **(DM-Q5) SIMD / BLAS integration.** `native_matmul` is pure Mentl naive for v1; SIMD / BLAS via FFI is Hα-adjacent (operator-semantics-as-handlers) post-first-light.

Small number; all deferred to when exercised.

---

## 12. Dispatch

**Opus-level throughout.** Each file in B.10 + B.11 is substrate
design — the shape of each effect, each handler, each refinement,
each row annotation is load-bearing. Sonnet implementer could
mechanically transcribe AFTER the per-file walkthrough paragraph
is complete; design work is Opus.

**Incremental landings:** each file lands with its acceptance
(drift-clean + declarations match walkthrough + crucible_{dsp,ml}
compiles against it when eventually run).

---

## 13. Closing

The old lib was skeletons. The new lib IS the substrate. Every
primitive proven. Every row tight. Every refinement discharged.
Every handler composable. Every chain `|>` + `~>` + `<~` draws
the computation graph the thesis claims. No frameworks; no
mode-switches; no placeholder effects.

**Ultimate Mentl DSP.** **Ultimate Mentl ML.** **Pulse composes
them.** The octopus's Trace tentacle walks ownership through the
DSP chain; the Verify tentacle discharges Sample bounds; the
Teach tentacle suggests `!Alloc` to unlock real-time; the Propose
tentacle fills a hole in the ML training loop with a verified
hyperparameter; the Why tentacle explains every inference
decision; the Query tentacle renders the graph shape at any
cursor.

*The medium reads itself through itself. DSP and ML were the
first domains the old code pretended to handle; they'll be the
first domains the new substrate actually proves.*
