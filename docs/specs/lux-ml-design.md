# Lux ML — Machine Learning as Proof of Thesis

*Programs are typed effect graphs. Data shapes the effect graph; the effect graph
shapes how data flows. A neural network is a typed effect graph. Training reshapes
it; the reshaped graph reshapes how data flows through it. This is the versor
architecture — and it's why Lux is the right language for ML.*

*Lux ML proves that algebraic effects + refinement types + ownership inference
compose into ML capabilities that no combination of existing tools can replicate.
Not because any single feature is impossible elsewhere, but because the unification
of all ten mechanisms into a single coherent system produces emergent capabilities
that disappear when you separate the parts.*

---

## What This Is

Lux ML is a machine learning framework written entirely in Lux. It is not PyTorch
in a new language. It is a demonstration that Lux's ten foundational mechanisms —
when applied to ML — produce emergent capabilities that existing frameworks cannot
replicate.

The framework is a **library**. No language extensions, no compiler plugins.
Everything is built from user-defined effects, handlers, refinement types, pipes,
and ADTs. If the framework needs a language feature that doesn't exist, that's a
signal to Lux's design, not a reason to bolt something on.

### Effect Algebra Primer

Lux has a complete Boolean algebra over effects. The key operator for this spec
is **negation**: `!E` means "provably does not perform effect E." This is a
compile-time guarantee that propagates through the entire transitive call chain.
If any function in the chain performs the negated effect, compilation fails.

| Operator | Meaning | Example |
|----------|---------|---------|
| `!Alloc` | Provably does not allocate | Embedded deployment |
| `!Random` | Provably deterministic | Inference without dropout |
| `!IO` | Provably no I/O | Compile-time evaluation, GPU offload |
| `Pure` | No declared effects | Auto-parallelization |

### Why ML

ML is the ideal stress test for Lux because it demands all ten mechanisms
simultaneously: compile-time shape checking (refinement types), automatic
differentiation (effects), hardware dispatch (effect handlers), deterministic
inference (effect algebra), memory control (ownership), composition (pipes),
hyperparameter search (multi-shot continuations), optimizer state (handler-local
state), generic model combinators (row polymorphism), and progressive learning
(language levels).

No other single workload exercises the full language this thoroughly.

### The Throughline

The ML framework follows the same structural pattern as the rest of Lux:
**convergence → pinch point → divergence.** Data flows through layers →
loss at the pinch → gradients radiate back.

The `handle` block IS the pinch point. Effects converge into it. `resume`
radiates new state. The training loop embodies this directly: forward pass
converges to loss, backward pass radiates gradients, optimizer updates
reshape the graph for the next cycle. Data tells the model how to reshape;
the reshaped model tells data how to flow.

This isn't metaphor. It's the same typed effect graph, projected into ML.

### Target Hardware

- **Training:** Desktop CPU. Models must be small enough to train without GPU.
  When GPU compilation gates are available (Phase 12), the same code scales up
  automatically.
- **Inference:** ARM Cortex-M7 (Daisy Seed, 64MB SDRAM). `!Alloc` proven at
  compile time. Same model code that trained on desktop deploys to embedded.

### Demo Target

Keyword recognition for an escape room, running on a Daisy Seed. Audio in →
MFCC spectral features (DSP) → tiny convnet (ML) → recognized keyword.
Trained on desktop, deployed to microcontroller. Written entirely in Lux.

---

## The Ten Mechanisms

Every Lux mechanism maps to an ML capability. The framework uses all ten.

| # | Lux Mechanism | ML Capability | What's Novel |
|---|---|---|---|
| 1 | Effects | Autodiff as a user-defined effect | Same model code trains or infers based on handler |
| 2 | Handler-local state | Optimizer state (Adam momentum, variance) | Optimizer is a handler, not a class hierarchy |
| 3 | Effect algebra | `!Random` deterministic inference, `!Alloc` embedded deployment | Compile-time proof of inference determinism (type-level, not by convention) |
| 4 | Refinement types | Shape checking, parameter constraints | `LearningRate`, `Probability`, `BatchSize` as types — categories of bugs eliminated at compile time |
| 5 | Ownership inference | Zero-copy data pipelines, deterministic memory | No GC pauses during training |
| 6 | Pipe operator | Model = signal chain = computation graph | DSP and ML compose identically |
| 7 | Multi-shot continuations | Hyperparameter search as an effect | Genuinely novel — no framework has language-level multi-shot search |
| 8 | Row polymorphism | Effect-generic model combinators | `sequential`, `residual` work with any effect set |
| 9 | Evidence-passing | Zero-overhead effects at compile time | Autodiff handler compiles to a register |
| 10 | Progressive levels | ML education path from L1 to L5 | Gradual complexity, never rewrite |

**On novelty claims:** Some capabilities (compile-time shape checking) exist in
research languages like Dex and Futhark, or via libraries like jaxtyping. Lux's
contribution is unifying ALL ten into a single coherent system. The genuinely
unprecedented capabilities are: hyperparameter search via multi-shot continuations,
`!Alloc` embedded deployment with compile-time proof, and the effect algebra
producing compilation gates (GPU offload, auto-parallelization) as emergent
consequences rather than designed features.

---

## Core Design

### Tensors

Tensors are refinement-typed values. Shape mismatches are compile errors.

```lux
type Tensor<T, Shape> = Buffer<T> where self.len() == product(Shape)

type Scalar = Tensor<f32, []>
type Vector<N> = Tensor<f32, [N]>
type Matrix<M, N> = Tensor<f32, [M, N]>

fn matmul<M, N, K>(a: Matrix<M, K>, b: Matrix<K, N>) -> Matrix<M, N>
```

The `K` dimensions must match. Z3 proves it at compile time or the program
doesn't compile. No runtime shape error is possible.

#### ML-Specific Refinement Types

```lux
type LearningRate = Float where 0.0 < self && self < 1.0
type Probability = Float where 0.0 <= self && self <= 1.0
type BatchSize = Int where self > 0 && is_power_of_two(self)
type Normalized<N> = Vector<N> where abs(norm(self) - 1.0) < 1e-6
```

Learning rate accidentally set to 10.0 is a compile error. Probability outside
[0,1] is a compile error. These eliminate entire categories of ML bugs.

### Autodiff as an Effect

Model code performs `Compute` effects. It does not know about gradients.
The training handler intercepts Compute operations, executes the forward
computation, and records the tape in handler-local state. The inference
handler just computes. This is reverse-mode automatic differentiation
(backpropagation) implemented as effect handling.

```lux
effect Compute {
    matmul<M, N, K>(a: Matrix<M, K>, b: Matrix<K, N>) -> Matrix<M, N>
    conv1d<C_in, C_out, L, K>(input: Tensor<f32, [C_in, L]>,
                                kernel: Tensor<f32, [C_out, C_in, K]>)
                                -> Tensor<f32, [C_out, L - K + 1]>
    elementwise<S>(a: Tensor<f32, S>, b: Tensor<f32, S>,
                   op: (f32, f32) -> f32) -> Tensor<f32, S>
    relu<S>(x: Tensor<f32, S>) -> Tensor<f32, S>
    softmax<N>(x: Vector<N>) -> Vector<N>
}
```

#### The Tape: Recording Forward, Replaying Backward

Each Compute operation has a known gradient rule. The training handler
records a `TapeEntry` for each operation — storing the inputs needed to
compute the gradient during the backward pass.

```lux
type TapeEntry =
    MatMul { a: Matrix, b: Matrix, out: Matrix }
  | Conv1d { input: Tensor, kernel: Tensor, out: Tensor }
  | Relu { input: Tensor, out: Tensor }
  | Softmax { input: Vector, out: Vector }
  | Elementwise { a: Tensor, b: Tensor, op_tag: OpTag, out: Tensor }
```

The backward pass walks the tape in reverse, applying the chain rule.
Each `TapeEntry` variant has an associated gradient function:

```lux
fn grad_entry(entry: TapeEntry, upstream: Tensor) -> List<Tensor> =
    match entry {
        MatMul { a, b, out } => [
            matmul(upstream, transpose(b)),    // gradient w.r.t. a
            matmul(transpose(a), upstream),    // gradient w.r.t. b
        ],
        Relu { input, out } => [
            elementwise(upstream, input, |g, x| if x > 0.0 { g } else { 0.0 }),
        ],
        Softmax { input, out } => [
            let s = out
            let ds = elementwise(s, upstream, |si, gi| si * (gi - dot(s, upstream)))
            [ds]
        ],
        // ... each variant knows its own gradient rule
    }

fn backward(tape: List<TapeEntry>, initial_grad: Tensor) -> Gradients {
    fold(reverse(tape), Gradients.empty(), |grads, entry|
        let upstream = grads.get_or(entry.out, initial_grad)
        let input_grads = grad_entry(entry, upstream)
        grads.accumulate(entry.inputs(), input_grads)
    )
}
```

The `Gradients` type maps tensor identities to accumulated gradients.
The `accumulate` method adds gradients for parameters that appear in
multiple operations (weight sharing, residual connections).

#### Training: Compute + Record

```lux
fn train_forward(model, input) -> (output, tape) {
    handle model.forward(input) with tape = [] {
        matmul(a, b) => {
            let out = native_matmul(a, b)
            resume(out) with tape = push(tape, MatMul { a: a, b: b, out: out })
        },
        relu(x) => {
            let out = native_relu(x)
            resume(out) with tape = push(tape, Relu { input: x, out: out })
        },
        // ... each op records its inputs for backward pass
    }
}
```

> **Handler state as return value** is implemented. The `(output, tape)`
> destructuring works via `let` pattern binding on handle expressions —
> handler-local state flows out as part of the result tuple.

#### Inference: Compute Only

```lux
fn infer(model, input) -> output with !Alloc, !Random {
    handle model.forward(input) {
        matmul(a, b) => resume(native_matmul(a, b)),
        relu(x) => resume(native_relu(x)),
        // ... no tape, no allocation, no randomness
    }
}
```

The type signature `with !Alloc, !Random` is a compile-time proof: the entire
transitive call chain neither allocates nor introduces stochastic behavior.
After evidence-passing (Phase 7), the inference handler is tail-resumptive
and compiles to zero overhead.

### The Model Type

A model is a record of typed parameters. For the keyword spotter:

```lux
type KeywordModel = KeywordModel {
    conv1_kernel: Tensor<f32, [32, 40, 3]>,     // C_out, C_in, K
    conv2_kernel: Tensor<f32, [16, 32, 3]>,
    dense_weights: Matrix<256, 12>,               // flattened conv output → 12 classes
    dense_bias: Vector<12>,
}

fn forward(model: KeywordModel, audio: Vector<16000>) -> Vector<12> with Compute, Random {
    audio
        |> mfcc(n_mels: 40, hop: 160)
        |> conv1d(model.conv1_kernel)
        |> relu
        |> pool1d(4)
        |> conv1d(model.conv2_kernel)
        |> relu
        |> dropout(rate: 0.3)
        |> flatten
        |> dense(model.dense_weights, model.dense_bias)
        |> softmax
}
```

#### Parameter Update

`update_params` walks the model's parameter structure, matching each
parameter with its gradient and applying the optimizer step:

```lux
fn update_params(model: KeywordModel, grads: Gradients) -> KeywordModel with Optimize {
    KeywordModel {
        conv1_kernel: step(model.conv1_kernel, grads.get(model.conv1_kernel)),
        conv2_kernel: step(model.conv2_kernel, grads.get(model.conv2_kernel)),
        dense_weights: step(model.dense_weights, grads.get(model.dense_weights)),
        dense_bias: step(model.dense_bias, grads.get(model.dense_bias)),
    }
}
```

Each `step` performs the `Optimize` effect — the handler decides the
update rule (SGD, Adam, etc.).

> **Open question:** For models with many parameters, manually destructuring
> every field is verbose. A trait-based approach (`impl Trainable for Model`)
> or a derive mechanism could automate this. This should emerge from usage
> rather than be designed in advance.

### Model Composition via Pipes

```lux
fn keyword_model(audio: Vector<16000>) -> Vector<12> with Compute, Random {
    audio
        |> mfcc(n_mels: 40, hop: 160)       // DSP: spectral features
        |> conv1d(40, 32, kernel: 3)          // ML: temporal convolution
        |> relu
        |> pool1d(4)                          // ML: downsample
        |> conv1d(32, 16, kernel: 3)
        |> relu
        |> dropout(rate: 0.3)                 // ML: regularization (Random effect)
        |> flatten
        |> dense(12)                          // ML: 12 keyword classes
        |> softmax
}
```

DSP and ML are the same pipeline. `mfcc` is a DSP function, `conv1d` is
an ML function. They compose identically through `|>`. No boundary.

### Optimizer as Handler

```lux
effect Optimize {
    step(param: Tensor, grad: Tensor) -> Tensor
}

// SGD — stateless handler
handle update(model, grads) {
    step(param, grad) => resume(param - lr * grad),
}

// Adam — momentum and variance as handler-local state
handle update(model, grads) with m = zeros(), v = zeros(), t = 0 {
    step(param, grad) => {
        let t_next = t + 1
        let m_new = 0.9 * m + 0.1 * grad
        let v_new = 0.999 * v + 0.001 * (grad * grad)
        let m_hat = m_new / (1.0 - pow(0.9, t_next))
        let v_hat = v_new / (1.0 - pow(0.999, t_next))
        resume(param - lr * m_hat / (sqrt(v_hat) + 1e-8))
            with m = m_new, v = v_new, t = t_next
    },
}
```

Same training loop, different optimizer — swap the handler.

### Randomness as an Effect

```lux
effect Random {
    sample() -> Float
}

fn dropout<S>(x: Tensor<f32, S>, rate: Probability) -> Tensor<f32, S> with Random {
    elementwise(x, |v| if sample() < rate { 0.0 } else { v / (1.0 - rate) })
}

fn xavier_init<M, N>(shape: (M, N)) -> Matrix<M, N> with Random {
    let scale = sqrt(6.0 / (to_float(M) + to_float(N)))
    generate_matrix(shape, || sample() * 2.0 * scale - scale)
}
```

Training handler provides real randomness. Inference has `!Random` in its
type — compile-time guarantee that no stochastic behavior occurs.

### Hyperparameter Search via Multi-Shot

```lux
effect Hyperparam {
    choose_lr() -> LearningRate
    choose_hidden() -> Int
    choose_dropout() -> Probability
}

let results = handle {
    let lr = choose_lr()
    let hidden = choose_hidden()
    let dropout = choose_dropout()
    let model = train(config(lr, hidden, dropout), data)
    [(lr, hidden, dropout, evaluate(model))]
} {
    choose_lr() => flatten(map(|lr| resume(lr), [0.001, 0.01, 0.1])),
    choose_hidden() => flatten(map(|h| resume(h), [64, 128, 256])),
    choose_dropout() => flatten(map(|d| resume(d), [0.1, 0.3, 0.5])),
}
// => all 27 combinations with evaluation scores
```

Grid search, random search, Bayesian optimization — all handler strategies
over the same training code. Multi-shot continuations resume the computation
with each candidate value and collect results. This is genuinely novel —
no existing ML framework has hyperparameter search as a language-level
mechanism with algebraic effect semantics.

### Effect-Polymorphic Combinators

```lux
fn sequential<E>(layers: List<(Tensor) -> Tensor with E>) -> (Tensor) -> Tensor with E {
    |input| fold(layers, input, |x, layer| layer(x))
}

fn residual<E>(block: (Tensor) -> Tensor with E) -> (Tensor) -> Tensor with E {
    |input| input + block(input)
}

fn repeat<E>(n: Int, layer: (Tensor) -> Tensor with E) -> (Tensor) -> Tensor with E {
    sequential(replicate(n, layer))
}
```

The `with E` is an open effect row. Combinators work regardless of what effects
layers perform — Compute, Random, or anything else.

> **Open question: shape flow through combinators.** These combinators use
> unparameterized `Tensor` — losing compile-time shape guarantees. A fully
> shape-preserving `sequential` requires dependent typing through a chain
> (each layer's output shape must match the next layer's input shape). This
> may require a `ShapeChain` type-level list or similar mechanism. Flagged
> as a Phase 10 design question — the combinator API may evolve once
> refinement types reveal what's expressible.

---

## Training Step

The complete training step is a sequential pipeline, not a nested handler
stack. Each phase has its own handler.

```lux
fn train_step(model: KeywordModel, batch: Batch) -> KeywordModel
    with Compute, Random, Optimize {
    // Phase 1: Forward pass — handler records tape
    let (output, tape) = handle forward(model, batch.input) with tape = [] {
        matmul(a, b) => {
            let out = native_matmul(a, b)
            resume(out) with tape = push(tape, MatMul { a: a, b: b, out: out })
        },
        relu(x) => {
            let out = native_relu(x)
            resume(out) with tape = push(tape, Relu { input: x, out: out })
        },
    }

    // Phase 2: Loss + backward — pure functions over the tape
    let loss_val = cross_entropy(output, batch.target)
    let grads = backward(tape, grad_cross_entropy(output, batch.target))

    // Phase 3: Optimizer update — each step performs Optimize effect
    update_params(model, grads)
}

fn train(model: KeywordModel, data: Dataset, epochs: Int) -> KeywordModel
    with Compute, Random, Optimize {
    fold(range(0, epochs), model, |model, epoch|
        fold(data.batches(), model, |model, batch|
            train_step(model, batch)
        )
    )
}
```

The outer call site composes the handlers:

```lux
let trained = handle
    handle
        handle
            train(model, data, epochs: 10)
        { matmul(a,b) => resume(cpu_matmul(a,b)), ... }  // Compute: CPU
    { sample() => resume(random_float(seed)) }             // Random: seeded
{ step(p,g) => /* Adam */ with m=..., v=... }              // Optimize: Adam
```

---

## Compilation Gates

The effect algebra produces four compilation gates. Gates 1, 2, and 4 are
achievable by Phase 9-10. Gate 3 (GPU) requires the full LLVM backend
(Phase 12) and GPU codegen — it is a long-term consequence of the algebra,
not a near-term deliverable.

### Gate 1: `!IO` → Compile-Time Evaluation

Pure model definitions with constant inputs can be evaluated at compile time.
Weight initialization with a fixed seed, model architecture construction,
loss function selection — all cacheable across builds.

### Gate 2: `Pure` → Multi-Core Parallelization

```lux
let results = data
    |> chunk(batch_size)
    |> parallel_map(|batch| infer(model, batch))
    |> flatten()
```

The compiler proves `infer` is pure (no mutable state, no I/O). Safe to
parallelize across CPU cores without annotation.

> **Scope:** This is multi-core data parallelism on a single machine,
> not distributed computing across machines. Distributed training requires
> communication primitives and gradient aggregation beyond what purity
> proofs alone provide.

### Gate 3: `!IO, !Alloc` → GPU Offload (Phase 12)

The pure, non-allocating forward pass can be automatically compiled to GPU
kernels. No CUDA. No `.to(device)`. The type system proved it's safe.

This requires the LLVM backend (Phase 12) plus GPU codegen infrastructure.
The effect algebra provides the *proof* that offloading is safe; the
backend provides the *mechanism*. Until Phase 12, Gate 3 is a design
target, not a working capability.

### Gate 4: `!Alloc` → Embedded Deployment

The inference path, proven allocation-free at compile time, deploys directly
to ARM Cortex-M7 (Daisy Seed). Same model code that trained on desktop
runs on a microcontroller. The compiler proves no heap allocation occurs
in the entire transitive call chain.

This is achievable at Phase 9 (ownership) and is the primary near-term
deployment target.

---

## Performance

With LLVM backend and evidence-passing:

- **Evidence-passing** makes tail-resumptive handlers (autodiff tape recording,
  state threading, deterministic inference) compile to extra function arguments
  passed in registers. Zero overhead versus hand-written code.

- **Purity proofs** enable optimizations C/Rust compilers must conservatively
  skip: guaranteed-safe parallelization, memoization, dead code elimination,
  compile-time evaluation.

- **Refinement types** eliminate runtime bounds checks entirely. No shape
  validation at runtime. No range clamping. The compiler proved it.

- **Multi-core parallelization** from effect algebra proofs means data-parallel
  operations without manual thread management. The type system guarantees safety.

---

## DSP–ML Unification

The framework treats DSP and ML as the same discipline. Both are
transformations on signals expressed as pipes:

```lux
// DSP preprocessing
// Note: output frame count depends on input length and hop size.
// The exact dependent type (e.g., Matrix<n_mels, N / hop>) requires
// Phase 10 refinement arithmetic. Until then, the shape relationship
// is documented but not compiler-verified.
fn mfcc<N>(n_mels: Int, hop: Int) -> (Vector<N>) -> Matrix with Compute {
    |audio| audio
        |> frame(hop)
        |> window(hann)
        |> fft
        |> mel_filterbank(n_mels)
        |> log
        |> dct
}

// ML model
fn classifier(n_classes: Int) -> (Matrix) -> Vector with Compute, Random {
    |features| features
        |> conv1d(40, 32, kernel: 3)
        |> relu
        |> pool1d(4)
        |> flatten
        |> dropout(rate: 0.3)
        |> dense(n_classes)
        |> softmax
}

// End-to-end: DSP → ML in one pipe
fn keyword_recognizer(audio: Vector<16000>) -> Vector<12> with Compute, Random {
    audio |> mfcc(n_mels: 40, hop: 160) |> classifier(n_classes: 12)
}
```

`mfcc` and `classifier` compose through `|>` with no adapter, no format
conversion, no framework boundary. The effect system tracks what each
piece needs. The handler stack provides it.

### The Deeper Insight: DSP and ML Are Interchangeable

The unification isn't just syntactic. DSP operations and ML operations are
*interchangeable* — a learned `conv1d` can replace a hand-designed
`mel_filterbank`. The boundary doesn't dissolve only in syntax; it dissolves
in meaning:

```lux
// Traditional: hand-designed mel filterbank
fn traditional_features(audio: Vector<16000>) -> Matrix with Compute {
    audio |> frame(160) |> window(hann) |> fft |> mel_filterbank(40) |> log
}

// Learned: trainable conv1d replaces the entire filterbank
fn learned_features(audio: Vector<16000>) -> Matrix with Compute {
    audio |> frame(160) |> conv1d(1, 40, kernel: 400)
}
```

Both have the same type signature. Both compose identically with downstream
classifiers. The `conv1d` learns a better representation than the mel scale
if given enough data — this is how modern audio ML works (SincNet, LEAF).
In Lux, the swap is a one-line change because DSP and ML are the same
abstraction.

This means **every DSP pipeline is a candidate for partial or full
replacement by learned components.** And every ML model's intermediate
representations are interpretable as signal processing stages. The pipe
operator doesn't just compose them — it makes the substitution obvious.

---

## Progressive ML Levels

The framework is usable at every Lux level. Each level unlocks more power.

### Level 1: Pure Functional ML

Define models as pure functions. Train with explicit gradient computation.
No effects, no ownership, no refinements. Like teaching ML in Elm.

```lux
fn forward(x: Vector, w: Matrix) -> Vector =
    x |> matmul(w) |> relu

fn train(model, data) -> Model =
    fold(data, model, |model, (input, target)|
        let output = forward(input, model.weights)
        let loss = mse(output, target)
        // Numerical gradients: O(N) forward passes per parameter.
        // Pedagogically intentional — demonstrates that gradients are a
        // mathematical concept, not a language feature. Does not scale;
        // Level 2 introduces effect-based autodiff for real training.
        let grads = numerical_gradient(|w| mse(forward(input, w), target), model.weights)
        Model { weights: model.weights - 0.01 * grads }
    )
```

### Level 2: + Effects

Autodiff as effect, compute dispatch, random for dropout/init.

```lux
fn forward(x: Vector) -> Vector with Compute, Random {
    x |> dense(256) |> relu |> dropout(0.3) |> dense(10) |> softmax
}
```

### Level 3: + Ownership

Zero-copy data pipelines. `own Buffer` moves through preprocessing.
Deterministic cleanup. No GC pauses during training.

```lux
fn load_batch(path: Path) -> own Batch with IO {
    let raw = own read_file(path)     // owned, moved through pipeline
    let processed = preprocess(raw)    // auto-move: last use of raw
    batch(processed)                   // deterministic cleanup
}
```

### Level 4: + Refinements

Compile-time shape checking. Bounded parameters. The compiler catches
mismatched dimensions before any code runs.

```lux
fn forward(x: Vector<784>) -> Vector<10> with Compute {
    x |> dense<784, 256>() |> relu |> dense<256, 10>() |> softmax
}
// dense<256, 10>() connected to dense<784, 128>() → COMPILE ERROR
```

### Level 5: Full Lux

Effect algebra gates, multi-shot hyperparameter search, multi-core
parallelization, `!Alloc` embedded deployment. Everything in this spec.

---

## XOR: Complete End-to-End Example

The first milestone. Proves the entire pipeline works: tensor ops, forward
pass, autodiff via effect handling, training loop, convergence.

```lux
// xor.lux — The "hello world" of Lux ML
//
// Trains a 2-layer network to learn XOR using effect-based autodiff.
// Uses: Compute effect, handler-local state (tape), Optimize effect.

import std/ml/tensor
import std/ml/compute
import std/ml/autodiff
import std/ml/optimize
import std/ml/loss

// ── Model ─────────────────────────────────────────────────────────

type XorModel = XorModel {
    w1: Matrix<2, 4>,      // input → hidden (4 neurons)
    b1: Vector<4>,
    w2: Matrix<4, 1>,      // hidden → output
    b2: Vector<1>,
}

fn forward(model: XorModel, x: Vector<2>) -> Vector<1> with Compute {
    x
        |> dense(model.w1, model.b1)
        |> relu
        |> dense(model.w2, model.b2)
        |> sigmoid
}

// ── Data ──────────────────────────────────────────────────────────

let xor_data = [
    (vector([0.0, 0.0]), vector([0.0])),
    (vector([0.0, 1.0]), vector([1.0])),
    (vector([1.0, 0.0]), vector([1.0])),
    (vector([1.0, 1.0]), vector([0.0])),
]

// ── Training ──────────────────────────────────────────────────────

fn train_step(model: XorModel, data: List<(Vector<2>, Vector<1>)>) -> XorModel
    with Compute, Optimize {
    fold(data, model, |model, (input, target)|
        // Forward with tape recording
        let (output, tape) = handle forward(model, input) with tape = [] {
            matmul(a, b) => {
                let out = native_matmul(a, b)
                resume(out) with tape = push(tape, MatMul { a: a, b: b, out: out })
            },
            relu(x) => {
                let out = native_relu(x)
                resume(out) with tape = push(tape, Relu { input: x, out: out })
            },
            sigmoid(x) => {
                let out = native_sigmoid(x)
                resume(out) with tape = push(tape, Sigmoid { input: x, out: out })
            },
            add(a, b) => {
                let out = native_add(a, b)
                resume(out) with tape = push(tape, Add { a: a, b: b, out: out })
            },
        }

        // Backward
        let grads = backward(tape, grad_mse(output, target))

        // Update parameters
        XorModel {
            w1: step(model.w1, grads.get(model.w1)),
            b1: step(model.b1, grads.get(model.b1)),
            w2: step(model.w2, grads.get(model.w2)),
            b2: step(model.b2, grads.get(model.b2)),
        }
    )
}

// ── Run ───────────────────────────────────────────────────────────

let model = XorModel {
    w1: xavier_init((2, 4)),
    b1: zeros(4),
    w2: xavier_init((4, 1)),
    b2: zeros(1),
}

// Train: 1000 epochs, SGD, CPU backend
let trained = handle
    handle {
        fold(range(0, 1000), model, |model, epoch|
            train_step(model, xor_data)
        )
    }
    { matmul(a,b) => resume(cpu_matmul(a,b)),
      relu(x) => resume(cpu_relu(x)),
      sigmoid(x) => resume(cpu_sigmoid(x)),
      add(a,b) => resume(cpu_add(a,b)) }
{ step(p, g) => resume(p - 0.1 * g) }    // SGD, lr=0.1

// Verify
print("XOR results:")
print("0,0 -> " ++ to_string(handle forward(trained, vector([0.0, 0.0]))
    { matmul(a,b) => resume(cpu_matmul(a,b)),
      relu(x) => resume(cpu_relu(x)),
      sigmoid(x) => resume(cpu_sigmoid(x)),
      add(a,b) => resume(cpu_add(a,b)) }))
print("0,1 -> " ++ to_string(handle forward(trained, vector([0.0, 1.0]))
    { matmul(a,b) => resume(cpu_matmul(a,b)),
      relu(x) => resume(cpu_relu(x)),
      sigmoid(x) => resume(cpu_sigmoid(x)),
      add(a,b) => resume(cpu_add(a,b)) }))
print("1,0 -> " ++ to_string(handle forward(trained, vector([1.0, 0.0]))
    { matmul(a,b) => resume(cpu_matmul(a,b)),
      relu(x) => resume(cpu_relu(x)),
      sigmoid(x) => resume(cpu_sigmoid(x)),
      add(a,b) => resume(cpu_add(a,b)) }))
print("1,1 -> " ++ to_string(handle forward(trained, vector([1.0, 1.0]))
    { matmul(a,b) => resume(cpu_matmul(a,b)),
      relu(x) => resume(cpu_relu(x)),
      sigmoid(x) => resume(cpu_sigmoid(x)),
      add(a,b) => resume(cpu_add(a,b)) }))
```

> **Note:** This example makes the handler composition problem viscerally
> obvious. The Compute handler is repeated identically for training and
> inference. This is exactly why handler composition syntax (Design Input #1)
> matters — with named handlers, the repeated block becomes `{ use CpuBackend }`.

---

## Lux Design Inputs

The ML framework surfaces three design questions for Lux itself. The first
two converge on **Phase 7** (evidence-passing compilation). The third is
an effect system scaling question.

### 1. Handler Composition Syntax

Six nested `handle` blocks for a training configuration is unreadable.
Evidence-passing compiles the handler stack to function parameters. The
question: what is the cleanest source-level syntax for composing handlers?

Candidates to explore during Phase 7:

```lux
// Option A: Pipe-style handler application
train(model, data)
    |> with CpuBackend()
    |> with TapeAutodiff()
    |> with Adam(lr: 0.01)

// Option B: Named handler composition
handler TrainingConfig = CpuBackend + TapeAutodiff + Adam(lr: 0.01)
handle train(model, data) { use TrainingConfig }

// Option C: Handler-list syntax
handle train(model, data) with [
    CpuBackend(),
    TapeAutodiff(),
    Adam(lr: 0.01),
]
```

The ML training stack (6 handlers) is the stress test. Phase 7's evidence-
passing implementation determines which syntax compiles most naturally.

### 2. Handler State as Return Value — **Resolved**

Handler-local state now flows out as part of the result tuple via `let`
destructuring on handle expressions. The tape naturally flows out of the
forward pass handler:

```lux
let (output, tape) = handle forward(model, input) with tape = [] {
    matmul(a, b) => {
        let out = native_matmul(a, b)
        resume(out) with tape = push(tape, MatMul { a: a, b: b, out: out })
    },
}
// tape is now available for backward pass
```

### 3. Compute Effect Scaling

The `Compute` effect currently lists individual operations (`matmul`,
`conv1d`, `relu`, `softmax`, `elementwise`). A real framework needs 50+
operations. The effect declaration and every handler grow linearly.

Possible solutions:

```lux
// Option A: Operation families (multiple effects)
effect LinearAlgebra { matmul(...), transpose(...), dot(...) }
effect Convolution { conv1d(...), conv2d(...), pool1d(...), pool2d(...) }
effect Activation { relu(...), sigmoid(...), softmax(...), tanh(...) }

// Option B: Single parametric dispatch
type Op = MatMul(a, b) | Conv1d(input, kernel) | Relu(x) | ...
effect Compute { dispatch(op: Op) -> Tensor }

// Option C: Trait-based operation registration
trait ComputableOp { fn compute(self) -> Tensor }
```

Option A preserves type safety but requires multiple effects in signatures.
Option B is maximally flexible but loses shape information in the dispatch.
Option C leverages Lux's trait system but requires deeper design work.

This should be explored during Phase 7-8 when real training workloads
reveal which operations are needed and how they compose. The XOR example
uses 4 operations; the keyword spotter needs ~15; the framework should
handle 50+ without handler bloat.

---

## Framework Structure

```
lux-ml/
├── std/ml/
│   ├── tensor.lux          # Tensor types, shape refinements
│   ├── autodiff.lux         # TapeEntry ADT, backward pass, gradient rules
│   ├── compute.lux          # Compute effect declaration
│   ├── optimize.lux         # Optimize effect, SGD/Adam/AdaGrad handlers
│   ├── random.lux           # Random effect, seeded/system handlers
│   ├── layers.lux           # dense, conv1d, conv2d, pool, dropout, relu, softmax
│   ├── loss.lux             # MSE, cross-entropy, and their gradients
│   ├── data.lux             # Dataset, Batch, data loading
│   ├── hyperparam.lux       # Hyperparam effect, search strategies
│   ├── combinators.lux      # sequential, residual, repeat
│   └── train.lux            # Training loop, train_step, evaluation
├── std/dsp/
│   ├── spectral.lux         # FFT, MFCC, mel filterbank
│   ├── window.lux           # Hann, Hamming, Blackman windows
│   └── features.lux         # Audio feature extraction pipelines
└── examples/
    ├── xor.lux              # Hello world: XOR with backprop
    ├── audio_classify.lux   # Tiny audio classifier (clap/snap/whistle)
    └── keyword_spotter.lux  # Escape room keyword recognition
```

---

## Relationship to Lux Roadmap

The ML framework is not a separate project. It is a Phase 7+ deliverable
within Lux itself — the proof that the language works.

| Lux Phase | What ML Unlocks |
|---|---|
| 7 (Evidence-passing) | Zero-overhead autodiff handler. Handler composition syntax. Handler state as return value. Training becomes practical. |
| 8 (Cranelift) | Native-speed tensor operations. Training on real data. |
| 9 (Ownership) | `!Alloc` inference. Zero-copy data pipelines. Daisy Seed deployment. |
| 10 (Refinements) | Compile-time shape checking. Parameter constraint types. Z3-verified dimensions. |
| 11 (Self-hosting) | ML framework written in Lux, compiled by Lux. No Rust anywhere. |
| 12 (LLVM) | GPU compilation gate. Multi-core parallelization. Full performance story. |

Each Lux phase completion should ask: **what new ML capability did this unlock?**
The ML framework is the throughline that connects every phase to a concrete,
demanding workload.
