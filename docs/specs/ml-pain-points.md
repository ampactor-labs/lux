# ML Build Pain Points — Phase 7 Design Input

*From the XOR milestone (Phases 0–3). Each pain point maps to a Phase 7+
mechanism that resolves it, with concrete code from the XOR demo.*

---

## What Worked

**The effect system IS sufficient for autodiff.** `forward()` performs Compute
effects. The training handler intercepts them, records the tape. The inference
handler just computes. Same model code, different semantics. Thesis proven.

**Handler-local state IS sufficient for the tape.** `with tape = []` and
`resume(r) with tape = push(tape, entry)` naturally accumulates the forward
trace. No mutable state, no side effects.

**Pure Lux IS sufficient for tensor math.** 58 lines of tensor.lux using only
prelude functions (`map`, `fold`, `zip_with`, `reverse`, `push`). No Rust
builtins needed for linear algebra — only for transcendentals (`exp`, `sqrt`).

---

## Pain Points

### 1. Handler state can't return (Phase 7: evidence-passing)

**Symptom:** `get_tape()` anti-pattern in xor.lux.

```lux
// Current: must use a Compute effect op just to extract handler state
let result = handle {
  let out = forward(model, x)
  (out, get_tape())             // get_tape() is a Compute effect op
} with tape = [] {
  get_tape() => resume(tape),   // leaks internal state as effect operation
  // ...
}
```

**Why it's wrong:** The tape is handler-internal state. Exposing it as an effect
operation pollutes the Compute interface — the model shouldn't know tapes exist.

**Phase 7 fix:** Evidence-passing makes handler state flow out as a return value.

```lux
// Phase 7: handler state returns naturally
let (out, tape) = handle {
  forward(model, x)
} with tape = [] {
  // tape flows out as second return value — no get_tape() needed
}
```

### 2. Handler duplication (Phase 7: handler composition)

**Symptom:** The inference handler repeats every clause from the training handler
minus the tape recording.

```lux
// Training handler
handle { forward(model, x) } with tape = [] {
  forward_mat_vec_mul(w, xv) => {
    let r = mat_vec_mul(w, xv)
    resume(r) with tape = push(tape, TapeMatVecMul { w: w, x: xv, out: r })
  },
  forward_vec_add(a, b) => { let r = vec_add(a, b); resume(r) with tape = push(tape, ...) },
  // ... 4 more clauses
}

// Inference handler — same clauses, minus tape
handle { forward(model, x) } with tape = [] {
  forward_mat_vec_mul(w, xv) => resume(mat_vec_mul(w, xv)),
  forward_vec_add(a, b) => resume(vec_add(a, b)),
  // ... 4 more clauses, all duplicated
}
```

**Why it's wrong:** Violates DRY. Adding a new layer type requires updating both
handlers identically.

**Phase 7 fix:** Handler composition lets inference be defined as "training minus
tape" or as a base handler that training extends.

### 3. Numeric inference defaulted to Int (Fixed)

**Symptom:** Every arithmetic lambda needed `: Float` annotations.

```lux
// Before fix — checker defaulted Type::Var to Int
fn vec_add(a, b) = zip_with(|x: Float, y: Float| x + y, a, b)  // needed
fn sumf(xs) = fold(xs, 0.0, |acc: Float, x: Float| acc + x)     // needed

// After fix — context propagates Float from call sites and literals
fn vec_add(a, b) = zip_with(|x, y| x + y, a, b)                 // inferred
fn sumf(xs) = fold(xs, 0.0, |acc, x| acc + x)                   // inferred
```

**Root cause:** `src/checker/exprs.rs` defaulted unconstrained arithmetic vars
to Int. Fixed by letting the type variable remain unconstrained.

**Long-term (Phase 7+):** Num typeclass for true numeric polymorphism. `sum`
and `sumf` become one function.

### 4. Tuple-after-let parsed as function call (Fixed)

**Symptom:** `(x, y)` on a new line after `let` was parsed as calling the
previous expression with args `x, y`.

```lux
// Before fix — needed workaround
fn pair(a, b) = (a, b)
let result = handle { ... }
pair(out, get_tape())      // can't write (out, get_tape())

// After fix — natural syntax works
let result = handle { ... }
(out, get_tape())          // parsed correctly as tuple
```

**Root cause:** `parse_postfix()` greedily consumed `(` as a call suffix.
Fixed by checking if `(` or `[` is on a different line than the previous
expression.

### 5. No numeric polymorphism

**Symptom:** Separate `sum` (Int) and `sumf` (Float) functions.

```lux
fn sum(xs) = fold(xs, 0, |acc, x| acc + x)     // Int only (0 literal)
fn sumf(xs) = fold(xs, 0.0, |acc, x| acc + x)  // Float only (0.0 literal)
```

**Phase 7+ fix:** Num trait with constraint solving. One `sum` for all numeric
types.

### 6. No unary minus on unconstrained vars

**Symptom:** `-x` works syntactically but on unconstrained vars would have
defaulted to Int (same root cause as #3). Led to defensive `0.0 - x` patterns.

```lux
// Defensive pattern (unnecessary after checker fix)
fn sigmoid_scalar(x) = 1.0 / (1.0 + exp(0.0 - x))
```

**Status:** Fixed separately from #3 (same root cause in `infer_unary` — removed
`Type::Var → Int` default). `-x` now works on unconstrained vars; `0.0 - x`
workarounds removed from `tensor.lux` and `xor.lux`.

---

## Phase 7 Priority Map

| Pain point | Mechanism | Impact |
|-----------|-----------|--------|
| Handler state can't return | Evidence-passing | Eliminates `get_tape()` anti-pattern |
| Handler duplication | Handler composition | Eliminates inference/training duplication |
| No numeric polymorphism | Trait constraints | Eliminates `sum`/`sumf` split |

Evidence-passing is the critical unlock. It's not just cleaner — it enables
handler state to flow into downstream computations, which is required for
optimizer state (Adam needs running means), learning rate schedules, and
any handler whose accumulated state IS the result.
