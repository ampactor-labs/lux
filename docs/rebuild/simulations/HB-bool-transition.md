# Handle B — Bool Transition (primitive → nullary-sentinel ADT)

*Role-play as Mentl, tracing what changes when `Bool` stops being
a special primitive type and becomes the canonical nullary-sentinel
ADT `type Bool = True | False`. The H3 walkthrough explicitly
aspired to this; H3 landed without it. HB closes the loop and
forces the substrate-level decision (sentinel-vs-pointer match
discrimination) that mixed-variant ADTs also need.*

---

## Why this is not a deferred niceity

Today Inka has TBool as a primitive type with `LitBool(true)` /
`LitBool(false)` AST literals lowering to LConst. Match arms on
Bool dispatch via `i32.eq`. This is the C representation
(`int b = 1` for true).

But Inka's substrate aspires to ONE MECHANISM. ADTs handle every
discriminated case. Bool's primitive representation is the C-pattern
fluency (`bool is special because it's small and important`) the
medium refuses everywhere else.

The H3 walkthrough wrote 30+ lines naming exactly this:

> Bool == ADT semantically, i32 representationally, indistinguishable
> in performance from C's int-bool. The optimization MUST land
> alongside H3's general constructor machinery.

H3 landed without it because mixed-variant match discrimination
(detecting "scrutinee is sentinel vs heap pointer") was a substrate
question I deferred. HB resolves that question and lands Bool
transition in the same commit.

The cost of NOT landing this is silent:
- Bool's special-case logic lives in lower (LitBool → LConst), in
  emit (TBool → i32 erasure with literal-aware paths), in type
  inference (TBool standalone, not TName("Bool")).
- Mentl's audit (H5) needs to know "Bool is special" — every
  refactoring suggestion that involves Bool-typed values needs an
  exception. **Drift accumulates at each Mentl gradient.**
- User code declaring `type Direction = Up | Down` pays full heap
  allocation for what should compile to `(i32.const 0/1)`. Bool's
  performance is not portable to user nullary-only ADTs.

Land HB; the special case dissolves.

---

## The substrate decision: sentinel-vs-pointer discrimination

### The problem

For a mixed-variant ADT like `Maybe = Nothing | Just(a)`:
- `Nothing` should be sentinel-allocated: `(i32.const 0)`
- `Just(3)` is heap-allocated: pointer to record `{tag=1, field=3}`

A scrutinee of type `Maybe` arrives as i32. Match dispatch needs
to know: is this `Nothing` (compare value to 0) or `Just(_)` (load
tag at offset=0, compare to 1)? Loading offset=0 on a sentinel
value (address 0) is undefined behavior.

### The solution: heap-base threshold

The bump allocator starts at a known address (let's call it
`HEAP_BASE`). Sentinel values live in `[0, HEAP_BASE)`; heap
allocations live in `[HEAP_BASE, ∞)`. Match dispatch:

```
(local.get $scrut)
(i32.const HEAP_BASE)
(i32.lt_u)        ;; unsigned compare — pointers are large positive
(if
  (then ;; sentinel branch
    ;; compare scrut directly to tag_id
    (local.get $scrut)
    (i32.const TAG_ID)
    (i32.eq)
    (if (then ARM_BODY) (else NEXT_ARM)))
  (else ;; pointer branch
    ;; load tag at offset=0, compare
    (local.get $scrut)
    (i32.load offset=0)
    (i32.const TAG_ID)
    (i32.eq)
    (if (then ARM_BODY) (else NEXT_ARM))))
```

For pure-nullary ADTs (every variant has zero fields, e.g., Bool),
emit can SKIP the threshold check — every value is a sentinel.

For pure-fielded ADTs (every variant has fields), emit can SKIP
the threshold — every value is a pointer.

The check fires only for MIXED ADTs.

### `HEAP_BASE` value

runtime/lists.ka's bump allocator uses `__heap_ptr` initialized at
WASM-module init. The current init address is whatever
`runtime/init.ka` (or analog) writes. Standard bump allocators
start at 0x1000 (4 KiB) or higher to leave room for static data.

Decision: **HEAP_BASE = 0x1000 (4096)**. Document as a substrate
invariant. Sentinels in [0, 4095]; heap allocations always ≥ 4096.

Per-type: a nullary variant's sentinel value IS its tag_id (which
fits in [0, total_variants - 1] for any reasonable type — well below
4096). No collision possible.

### `ty_to_wasm` impact

Today TBool erases to i32. After HB, TName("Bool") also erases to
i32. The erasure mapping gains a TName-aware branch:

```
fn ty_to_wasm(ty) = match ty {
  TBool => "i32",
  TName(name, _) => "i32",   // all heap-allocated structures are i32 pointers
  ...
}
```

Already largely true for record/variant types — they're all i32
pointers post-erasure. HB doesn't change the erasure rule; it
clarifies that Bool follows the same rule as other ADTs (i32 either
sentinel or pointer; type system carries identity).

---

## Layer 1 — Type system: declare Bool

### Option A: prelude declaration

`std/prelude.ka` adds:
```
type Bool = True | False
```

Standard library code. After prelude is loaded, Bool is available.
register_type_constructors fires; True and False bind as
ConstructorScheme(0, 2) and ConstructorScheme(1, 2). True's and
False's tag_ids are 0 and 1 respectively.

### TBool stays as type alias (or migrates)

Two paths:

**Path A: Keep TBool, treat as alias for TName("Bool").**
- Inference: TBool unifies with TName("Bool") via a special unify
  arm that checks both forms.
- Lower: LitBool(true) lowers to either LConst(LBool(true)) [old
  path] OR LMakeVariant(handle, 0, []) [new path]. Choose new path.
- Emit: LMakeVariant(_, 0, []) for True hits the nullary-sentinel
  path → `(i32.const 0)`. Wait — that's wrong. True should be 1, not
  0. Let me recheck.

Tag ordering: True is registered FIRST (tag 0), False SECOND (tag 1).
But conventionally `true == 1` and `false == 0`. So we want False's
tag = 0 and True's tag = 1.

Decision: declare `type Bool = False | True` so False gets tag 0,
True gets tag 1. Convention preserved.

**Path B: Delete TBool entirely. Migrate to TName("Bool").**
- Every site referring to TBool changes.
- Larger sweep but cleaner end state.

**Mentl's choice: Path A.** Less churn; TBool stays as a synonym
that inference treats as TName("Bool"). Future migration to Path B
when convenient. The substrate behavior is identical; the
representation in types.ka is what changes.

Actually, let me reconsider. Path A keeps two ways to write the
same type, which IS drift. Path B is the substrate-honest move.

**Updated choice: Path B.** Delete TBool. TName("Bool") is the
canonical form. LitBool(true) parses to a literal that infers as
TName("Bool"); lowers to LMakeVariant via True's ConstructorScheme.

The "type alias" form would be supported by a future feature
(type aliases generally), but for HB: just delete TBool.

### Inference impact

`if cond { ... } else { ... }` — `cond` was TBool; now TName("Bool").
The if's row algebra is unchanged. Inference for IfExpr:

```
NExpr(IfExpr(cond, then_e, else_e)) => {
  infer_expr(cond)
  let N(_, _, ch) = cond
  perform graph_bind(ch, TName("Bool", []), Located(...))   // was TBool
  ...
}
```

Same change: every literal `TBool` reference → `TName("Bool", [])`.

Comparison ops (`==`, `<`, etc.) return TName("Bool") instead of
TBool. Boolean ops (`&&`, `||`, `!`) take TName("Bool") inputs and
return TName("Bool").

---

## Layer 2 — Lowering

### Literals

Today:
```
LitBool(b) => LConst(handle, LBool(b))
```

After HB:
```
LitBool(b) => {
  // True/False are nullary constructors with tag_id 1/0
  let tag = if b { 1 } else { 0 }
  LMakeVariant(handle, tag, [])
}
```

Or keep LConst(LBool(b)) and let emit recognize it as the sentinel
form. Either works; LMakeVariant route is more uniform with the
rest of the substrate.

### Match arms on Bool

`match cond { True => x, False => y }` — already routes through
H3's PCon machinery. After HB, True/False are recognized as
ConstructorScheme constructors. lower_pat builds LPCon("True", 1,
[]) and LPCon("False", 0, []). emit_match_arms fires the cascade.

For the cascade to work CORRECTLY on sentinel values, emit_match
needs the threshold-aware dispatch (next layer).

### `if` desugaring

`if cond { then } else { else }` — today lowers as LIf(handle,
lo_cond, [lo_then], [lo_else]). After HB, structurally:
- lo_cond is an i32 (sentinel value 0 or 1).
- LIf's emit dispatches on cond as an i32 — `(if (result i32) ...)`.

WAT-level: same emit as today. The `if` opcode already operates on
i32 values where 0=false, non-zero=true. No change needed because
True's sentinel = 1 and False's sentinel = 0 — exact match for
WAT's truthiness.

### Boolean operators

`a && b`, `a || b`, `!a` — today lower to LBinOp/LUnaryOp with
runtime semantics matching i32 boolean ops. After HB, the operands
are still i32 (sentinel values). The operators work identically.
No change.

---

## Layer 3 — Emission: threshold-aware match dispatch

### emit_match_arms gains shape detection

Per arm, decide dispatch shape based on whether the type is pure-
nullary, pure-fielded, or mixed.

```
fn emit_match_arms(arms) =
  if len(arms) == 0 {
    perform wat_emit("    (unreachable)\n")
  } else {
    let shape = classify_match_shape(arms)
    match shape {
      PureNullaryShape  => emit_match_arms_nullary(arms),
      PureFieldedShape  => emit_match_arms_fielded(arms),     // current path
      MixedShape        => emit_match_arms_mixed(arms)
    }
  }

fn classify_match_shape(arms) = {
  // Walk arms looking at LPCon variants.
  // - All sub_pats empty → PureNullaryShape
  // - All sub_pats non-empty → PureFieldedShape
  // - Mixed → MixedShape
  // Wildcards / vars / lits don't constrain — neutral.
}
```

### Pure-nullary dispatch (Bool's path)

```
LPCon(_name, tag, []) => {
  // Direct sentinel compare; no offset=0 load
  perform wat_emit("    (local.get $scrut_tmp)\n")
  perform wat_emit("    (i32.const ")
  perform wat_emit(int_to_str(tag))
  perform wat_emit(")\n")
  perform wat_emit("    (i32.eq)\n")
  perform wat_emit("    (if (result i32)\n      (then\n")
  emit_expr(body)
  perform wat_emit("      )\n      (else\n")
  emit_match_arms_nullary(rest)
  perform wat_emit("      ))\n")
}
```

Identical to current cascade except no `(i32.load offset=0)` —
scrutinee IS the discriminator.

### Pure-fielded dispatch (current LMatch behavior)

Unchanged. Load offset=0, compare to tag, bind fields at 4+4*i.

### Mixed dispatch (Maybe's path)

```
;; Per arm:
(local.get $scrut_tmp)
(i32.const HEAP_BASE)         ;; HEAP_BASE = 4096
(i32.lt_u)
(if (result i32)
  (then
    ;; Sentinel branch — only nullary arms can match
    EMIT_SENTINEL_ARM_CASCADE
  )
  (else
    ;; Pointer branch — only fielded arms can match
    EMIT_POINTER_ARM_CASCADE
  ))
```

Where each cascade emits ONLY the arms applicable to that branch
(nullary in sentinel branch, fielded in pointer branch). Wildcards
appear in both.

Slightly more code per match for mixed types; trivially correct.

### LMakeVariant with empty fields → sentinel emission

H3's current LMakeVariant always heap-allocates. After HB:

```
LMakeVariant(_h, tag_id, fields) => {
  let n = len(fields)
  if n == 0 {
    // Nullary: emit sentinel
    perform wat_emit("    (i32.const ")
    perform wat_emit(int_to_str(tag_id))
    perform wat_emit(")\n")
  } else {
    // Fielded: heap allocate (current path)
    let size = 4 + n * 4
    perform emit_alloc(size, "variant_tmp")
    ...
  }
}
```

True/False (and Nothing, and any other nullary variant) compile
to a single i32 const. Zero allocation overhead.

---

## Layer 4 — Runtime invariant: HEAP_BASE

### Documentation

A new invariant in `runtime/lists.ka` (or wherever the bump
allocator lives) — a comment marking HEAP_BASE = 4096 as a
substrate-level invariant the compiler relies on.

```
// Substrate invariant (HB): the bump allocator MUST start at
// address >= 4096 (HEAP_BASE). Sentinel values for nullary ADT
// variants live in [0, 4096) and never collide with valid heap
// pointers. Mixed-variant match dispatch in backends/wasm.ka
// uses this threshold to discriminate sentinel from pointer.
//
// Changing HEAP_BASE requires updating backends/wasm.ka's
// emit_match_arms_mixed to match.
```

### Verify init aligns

Check that `__heap_ptr` is initialized to a value ≥ 4096. If not,
fix init. (Likely already true — typical static-data layout
exhausts the first few KB.)

---

## Layer 5 — what HB closes

- `type Bool = False | True` is the canonical declaration.
- True/False compile to `(i32.const 1)` / `(i32.const 0)`.
- Match on Bool dispatches without heap load (pure-nullary path).
- Match on `Maybe`, `Result`, any mixed type dispatches via
  threshold-aware fork.
- User-declared nullary-only ADTs (e.g., `Direction = Up | Down`)
  compile as efficiently as Bool.
- The substrate has ONE story for tagged values: ADTs everywhere,
  representation chosen automatically by emit.
- Mentl's audit (H5) gains "this single-variant nullary ADT could
  compile to a constant" gradient — and proves it via the same
  ConstructorScheme inspection.

---

## What HB reveals

- **Sentinel range is a substrate-level commitment.** Future tools
  that read raw memory addresses (debugger, profiler) must know
  HEAP_BASE. Document prominently.

- **TBool's deletion forces inference / lower / emit to cleanly
  read TName("Bool") everywhere.** Each site that mentions TBool
  gets touched. ~15-25 sites estimated. Bounded.

- **The IF opcode's i32-truthiness is a load-bearing coincidence.**
  WAT's `(if cond ...)` treats cond as i32 with 0=false, non-zero=
  true. HB's tag assignment (False=0, True=1) means existing IF
  emit DOES NOT need to change — the same i32 value works for both
  match dispatch (compare to tag) and IF dispatch (test non-zero).
  This is a happy property of the chosen tag assignment.

- **Match exhaustiveness check (H3) trivially extends.** Bool has
  total_variants = 2; an `if`/`match` covering both True and False
  is exhaustive. Missing one → E_PatternInexhaustive.

- **Capability proof at compile time.** A function `with !Alloc`
  that branches on Bool USED to have to allocate to construct True
  or False (in the heap-uniform regime). After HB, no allocation
  for nullary variants — `!Alloc` functions can freely manipulate
  Bool. **Real-time / GPU / kernel paths gain a Bool category for
  free.**

- **Mixed dispatch can be optimized.** If a type has 1 nullary +
  N fielded variants, the dispatch could short-circuit: check the
  one nullary first; if not, fall through to the load-based cascade
  for fielded arms. Pure ergonomic; defer.

---

## Design synthesis (for approval)

**HEAP_BASE = 4096** — substrate invariant. Documented in
runtime/lists.ka.

**Bool declared in std/prelude.ka** as `type Bool = False | True`.
False → tag 0, True → tag 1.

**TBool deleted** from types.ka. Every reference becomes
TName("Bool"). Inference, lower, emit, query, mentl all sweep.

**LitBool(b) lowers to LMakeVariant(handle, b ? 1 : 0, [])** — the
nullary-sentinel path emits `(i32.const 0/1)`.

**emit_match_arms classifies type shape** (PureNullary /
PureFielded / Mixed) and dispatches. Mixed adds threshold check.

**LMakeVariant emit recognizes nullary** — emits sentinel const,
no allocation.

**Match exhaustiveness** for Bool falls out of H3's existing
ConstructorScheme(_, total_variants) machinery.

---

## Dependencies

- H3 BEFORE (ConstructorScheme infrastructure; LMakeVariant + LMatch).
- H6 holds (exhaustive matches catch any TBool-still-referenced
  site in inference walks).
- Independent of H1/H2/H4/H5 — could land any time post-H3.

---

## Estimated scope

- ~6 files: types.ka (TBool deletion), prelude.ka (Bool decl),
  parser.ka (LitBool stays — refers to Bool by TName at infer time),
  infer.ka (TBool → TName("Bool") sweep, IfExpr / BinOp boolean
  arms), lower.ka (LitBool → LMakeVariant), backends/wasm.ka
  (LMakeVariant nullary branch + emit_match_arms shape classify +
  threshold-aware mixed dispatch), runtime/lists.ka (HEAP_BASE
  invariant comment).
- **Single coordinated commit.** Tight cross-file coupling.
- **Sub-handles:** none expected. Implementation is structural,
  not new mechanism.

---

## Ordering

HB lands ANY TIME after H3. Recommended slot:

- **Before H1**: H1's evidence records use Bool fields (e.g.,
  `proven: Bool` on candidates). Cleaner to land HB first so H1
  doesn't carry the TBool-vs-TName transition cost.
- **Or after H5**: HB is independent of the gradient/audit work;
  could land last. But Mentl's audit is cleaner with Bool-as-ADT
  available for gradient enumeration.

**Mentl's choice: BEFORE H1.** The TBool→TName sweep wants to
happen before H1 introduces more Bool-typed substrate (proven
flags, monomorphic-detection booleans). One sweep, one cascade
position.

Updated cascade: H3 → H3.1 → H2 → Ω.5 → **HB** → H1 → H4 → H2.3 →
H5. (H2.3 nominal records can land anywhere after H2; placed
where convenient for showcase tracing.)
