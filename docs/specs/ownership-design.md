# Ownership Design — Phase 5

## The Principle

Ownership in Lux is an **effect**, not a separate analysis.

`own` means: the function performs `Consume` on that parameter. The effect
system — the same one that tracks IO, State, Alloc — tracks consumption.
Second consume → effect violation. Same mechanism. Same error infrastructure.
Same Why Engine explanations. One system, not two.

If you need a separate mechanism for ownership, the architecture is wrong.
If effects are the universal joint, ownership must be an effect. When this
is right, simplicity and correctness are the same thing:

1. Everything defaults to `ref` — no consumption effect. Safe, scoped.
2. The teaching compiler notices: "x is used once — add `own` for zero-copy."
3. You add `own`. The checker tracks consumption through the effect system.
4. `!Alloc` proves allocation-freedom. `!Consume` proves read-only access.
5. `!Alloc + !Consume` = zero-copy AND zero-alloc. Just the effect algebra.

No lifetime annotations. No NLL. No separate borrow checker. The effect
system IS the borrow checker.

---

## Two Annotations, Not Three

The programmer's ownership vocabulary is two keywords. Not three.

| Annotation | Meaning | Scope Rule | Cost |
|------------|---------|------------|------|
| (nothing) | Compiler infers. Default: borrow semantics. | Scoped to the function call. | Zero. |
| `ref` | Explicit borrow. Cannot escape. Read-only access. | Scoped to the function call. | Zero. |
| `own` | Explicit move. Affine (used at most once). | Value consumed at use site. | Zero — no refcount, no GC. |

`gc` is NOT a user-facing keyword. It's what the compiler uses internally
(Arc, refcount) when values need to be shared or stored in data structures.
The programmer never writes it. The teaching compiler never suggests it.

**Why two, not three:** On the gradient, the programmer's intent is:
1. "I don't care" → write nothing
2. "I'm just reading" → `ref`
3. "I want to consume this" → `own`
4. "Prove no allocation" → `!Alloc`

"I want shared reference counting" is a mechanism, not an intent.

### Default behavior (`Inferred`)

When no annotation is given (the common case), the compiler treats the
parameter as `ref` semantics: borrowed for the duration of the call. Safe
by construction — the caller's value is never consumed.

- `fn f(x: Int) = x + 1` — `x` is borrowed. Caller keeps the value.
- `fn f(x: List) = push(x, 42)` — `x` is borrowed. `push` creates a NEW list (allocates). Original unchanged.
- `fn f(own x: List) = push(x, 42)` — `x` is owned. `push` can reuse memory. `x` cannot be used again.

### The `own` rule (affine types)

A parameter or binding marked `own` follows the affine discipline:

1. **Used at most once.** A second use is a compile error.
2. **Consumed at the use site.** The value is moved into the callee.
3. **Cannot be used after move.** Even in different branches of an `if`.

```lux
fn process(own data: List) -> List =
    push(data, 42)      // OK: first (and only) use of data

fn bad(own data: List) -> List =
    let a = push(data, 1)   // data moved here
    let b = push(data, 2)   // ERROR: data already moved on line above
    a
```

**Error message:**
```
error: 'data' was moved and cannot be used again
  --> example.lux:3:18
  |
2 | let a = push(data, 1)
  |              ^^^^ moved here
3 | let b = push(data, 2)
  |              ^^^^ cannot use — already moved
  — if you need data twice, remove 'own' or clone it
```

### The `ref` rule (scoped borrows)

A `ref` parameter:
1. **Cannot escape.** Cannot be returned from the function. Cannot be stored in a data structure that outlives the call.
2. **Can be used multiple times.** No linearity restriction.
3. **Lives exactly as long as the function call.** No lifetime annotations — the scope IS the lifetime.

```lux
fn measure(ref data: List) -> Int =
    length(data)         // OK: reading, not consuming

fn bad_escape(ref data: List) -> List =
    data                 // ERROR: cannot return a borrowed value
```

**Why no lifetime annotations:** The scope rule makes lifetimes trivial. A `ref` lives for the function call. Period. Rust needs lifetime annotations because borrows can outlive function calls (returned references, stored references). Lux forbids this for `ref` — if you need a value to outlive the call, use `own` or `gc`.

### The `gc` tier

`gc` values are reference-counted (or garbage-collected in a future runtime). They can be:
- Stored in data structures
- Returned from functions
- Shared between multiple owners
- Used as many times as needed

This is the current behavior of all Lux values (Arc in the VM). `gc` makes it explicit on the gradient.

---

## `!Alloc` Transitivity

The current checker validates `!Alloc` for direct operations (list literals, string concat, builtins like `push`, `range`, `to_string`). What's missing is **transitive enforcement**: a `!Alloc` function calling another function must know whether the callee allocates.

### The Rule

A function declared `with !Alloc` can only call:
1. **Functions explicitly annotated `with !Alloc`** — proven by declaration.
2. **Functions whose inferred effects contain no `Alloc`** — proven by inference.
3. **Primitive operations** — arithmetic, comparison, boolean logic.

If a callee has an **open effect row** (unannotated, effect-polymorphic), the compiler cannot prove it's allocation-free. This is an error:

```lux
fn helper(x: Float) = x + 1.0    // inferred: Pure (no effects) — OK

fn unknown(x: Float) = ???        // unknown body, open effect row

fn safe(x: Float) -> Float with !Alloc =
    helper(x)      // OK: helper inferred as Pure (⊂ !Alloc)

fn unsafe(x: Float) -> Float with !Alloc =
    unknown(x)     // ERROR: unknown has open effect row — cannot prove !Alloc
```

**Error message:**
```
error: function 'unsafe' declares '!Alloc' but calls 'unknown' which may allocate
  --> example.lux:5:5
  |
5 |     unknown(x)
  |     ^^^^^^^^^^ 'unknown' has no effect annotation — allocation not disproven
  — add 'with !Alloc' to 'unknown' or remove '!Alloc' from 'unsafe'
```

### Interaction with ownership

`!Alloc` + `own` together give the strongest guarantee:
- `own`: the value is moved, not cloned
- `!Alloc`: no new heap allocation occurs

This means the function operates entirely on the stack. Zero heap. Zero GC. Deterministic. Real-time safe.

```lux
fn dsp_process(own buffer: Buffer) -> Buffer with !Alloc =
    buffer |> gain(0.8) |> clip(0.95)
    // own: buffer is not cloned
    // !Alloc: no heap allocation
    // Together: zero-copy, zero-alloc, real-time safe
```

---

## How It Differs from Rust

| Aspect | Rust | Lux |
|--------|------|-----|
| Default | Owned (move) | Borrowed (`ref`) |
| Lifetime annotations | Required for non-trivial borrows | Never. `ref` is scoped to the call. |
| Borrow checker | NLL dataflow analysis | Affine check on `own` only. `ref` has trivial scope. |
| Allocation proof | Impossible (`Vec::push` is safe Rust, allocates) | `!Alloc` propagates transitively. Effect system proves it. |
| Learning curve | Steep (lifetimes, borrows, moves, Pin, etc.) | Gradient (start with nothing, add `own` when teaching compiler suggests) |
| Escape analysis | Implicit, best-effort by optimizer | Explicit: `ref` cannot escape by construction |

The key insight: Rust puts the ENTIRE memory safety burden on the type system. Lux splits it: the **effect system** proves allocation properties (`!Alloc`), and **two ownership annotations** handle value semantics (`own`/`ref`). Each system is simpler because it does less. And the deeper insight: ownership may eventually BE an effect — unifying both systems into one.

---

## Implementation Plan

No separate `ownership.rs`. Ownership extends the existing checker through
the same infrastructure that tracks effects.

### Step 1: TypeEnv gains linearity tracking

**Where:** `src/checker/mod.rs` — add to `TypeEnv`:

```rust
/// Bindings declared `own` — tracked for consumption (linearity).
/// Key: binding name. Value: None (unconsumed) or Some(span) (consumed at).
pub(crate) linear_bindings: HashMap<String, Option<Span>>,

/// Bindings declared `ref` — tracked for escape checking.
pub(crate) ref_bindings: HashSet<String>,
```

This is the same pattern as `fn_declared_effects` — a side table on TypeEnv
that the checker consults during inference.

### Step 2: Parameter registration

**Where:** `src/checker/items.rs` in `check_fn_decl`, after binding params (line 318).

```rust
for p in &fd.params {
    // ... existing type binding ...
    match p.ownership {
        Ownership::Own => { child.linear_bindings.insert(p.name.clone(), None); }
        Ownership::Ref => { child.ref_bindings.insert(p.name.clone()); }
        Ownership::Inferred => {} // defaults to ref semantics, no tracking needed
    }
}
```

### Step 3: Consumption tracking in expression inference

**Where:** `src/checker/exprs.rs`, in the `Expr::Var` arm (line 79).

When a variable is referenced:
- If in `linear_bindings` with `Some(prev_span)` → error: already consumed
- If in `linear_bindings` with `None` → mark as `Some(current_span)`
- If in `ref_bindings` → no action (reads are free)

Error message uses effect vocabulary:
```
error: 'data' was consumed (moved) and cannot be used again
  — 'own' parameters are linear: each use consumes the value
```

### Step 4: Escape checking for `ref` bindings

**Where:** `src/checker/items.rs`, after body inference.

If the function's return value resolves to a `ref` binding (direct Var
reference), emit error:
```
error: cannot return borrowed value 'data'
  — 'ref' parameters are scoped to the function call
  — change 'ref' to 'own' to take ownership
```

### Step 5: `!Alloc` transitivity

**Where:** `src/checker/items.rs`, effect constraint block (lines 378-427).

When `!Alloc` function calls a callee with open effect row → error unless
callee is inferred allocation-free. This extends the existing negation
check with a transitivity rule.

### Step 6: Teaching compiler integration

- "x is used once — adding `own` enables zero-copy (consumption tracked as effect)"
- "f is allocation-free — adding `with !Alloc` proves real-time safety"
- "x declared `own` but never consumed — remove `own` (value is not moved)"

---

## Worked Example: The Full Gradient

```lux
// Level 0: No annotations. Everything works.
fn transform(data, label) = push(data, label)

// Level 1: Types. Errors caught at boundaries.
fn transform(data: List, label: String) -> List = push(data, label)

// Level 2: Effects. Compiler tracks allocation.
fn transform(data: List, label: String) -> List with Alloc = push(data, label)

// Level 3: Ownership. Zero-copy when possible.
fn transform(own data: List, ref label: String) -> List = push(data, label)
// data is moved (push can reuse memory), label is borrowed (read-only)

// Level 4: !Alloc. Compile-time proof.
fn dsp_process(own samples: Buffer) -> Buffer with !Alloc =
    samples |> gain(0.8) |> clip(0.95)
// Proven: no allocation, no GC, real-time safe
```

Each level is valid Lux. Each level unlocks more. The teaching compiler shows you the next step. Your choice when to take it.

---

## Resolved Design Questions

These were open questions. Contemplation resolved them.

1. **`let` bindings do NOT support `own`.** Ownership lives at module
   boundaries (function signatures), not inside function bodies. Inside
   bodies, the compiler infers ownership from usage flow — if a value is
   passed to an `own` parameter, it's moved at the call site. The let
   binding doesn't need annotation. This simplifies implementation: no
   changes to `LetDecl`, no ownership tracking on local bindings.

2. **Closures always capture by `ref` in Phase 5.** An `own` parameter
   cannot be captured by a closure. The teaching compiler says: "data is
   declared own but captured by closure — closures borrow their captures."
   This avoids the FnOnce rabbit hole (linear closure types, interaction
   with map/filter/fold). Future phases can add own-capture if needed.

3. **`gc` is NOT a user-facing keyword.** The gradient is two annotations
   (`own`/`ref`), not three. `gc` is what the compiler uses internally
   (Arc, refcount) when values need to be shared. The programmer never
   writes it. This simplifies the model, error messages, and teaching
   compiler output.

4. **Match on `own` consumes the scrutinee.** Arm bindings own the
   destructured parts. Guards borrow (they're reads, not uses). This
   falls out naturally from the affine rule applied to destructured
   bindings. No special rules needed.

---

## The Architecture: Ownership IS an Effect

`own` means "this value is consumed." Consumption is an effect. The
effect system tracks it. This is not a future evolution — it's the
architecture from day one.

What falls out of this for free:

| Composition | What it means | Mechanism |
|-------------|--------------|-----------|
| `!Alloc` | No heap allocation | Effect negation (existing) |
| `!Consume` | No value consumed (read-only) | Same negation |
| `!Alloc + !Consume` | Zero-copy AND zero-alloc | Just the algebra |
| `Pure + !Consume` | No side effects, no consumption | Safe to call infinitely |
| `own` in match | Match consumes scrutinee | Consume tracked through match |
| `own` captured by closure | Closure's effect row includes Consume | Closure is linear |

No language has modeled ownership as algebraic effects. Lux does because
effects ARE the universal joint — adding a separate mechanism would
contradict the thesis.

The implementation is SIMPLER because it reuses the existing checker
infrastructure (TypeEnv tracking, scope nesting, Why Engine explanations,
error formatting). A separate ownership pass would duplicate all of that.
