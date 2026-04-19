# Handle 3 — ADT Instantiation

*Role-play as Mentl, tracing what happens when a user writes
`FbDelay(1)` in an Inka source file — from token stream through
inference, lowering, emission, and pattern match. Names the handles
that don't yet bind cleanly. Resolves the design decisions ADT
instantiation has been deferring.*

---

## The scenario

Morgan writes this file:

```
type FeedbackSpec
  = FbState(Int)
  | FbDelay(Int)
  | FbFilter(Int, List)

type Option
  = Some(Int)
  | None

fn decay_mask(spec: FeedbackSpec) -> Int = match spec {
  FbState(carrier) => carrier,
  FbDelay(n)       => n,
  FbFilter(taps, _) => taps
}

fn main() = {
  let spec = FbDelay(3)
  let m = decay_mask(spec)
  let opt = Some(m)
  match opt {
    Some(v) => v,
    None    => 0
  }
}
```

Three ADTs. Three construction sites. Three match arms. This is
the minimal example that exercises every ADT mechanism.

What has to work for this to compile correctly? Trace each layer.

---

## Layer 1 — Parser (today: already works)

`FbDelay(3)` tokenizes to `Identifier("FbDelay") LParen Int("3") RParen`.

`parse_expr` recognizes the call shape: `FbDelay` is a primary,
`(3)` is a call suffix. The AST node is:

```
CallExpr(VarRef("FbDelay"), [LitInt(3)])
```

This is INDISTINGUISHABLE from a plain function call. The parser
has no reason to distinguish — the generic constructor-form IS
call syntax.

`match spec { FbDelay(n) => n, … }` — `FbDelay(n)` is parsed as
`PCon("FbDelay", [PVar("n")])`. The pattern side HAS a distinct
form; the value side reuses call syntax.

Verdict: **parser is complete**. No changes needed for H3.

---

## Layer 2 — Inference (today: partial)

### Type declaration registration (today: works)

`TypeDefStmt("FeedbackSpec", [], variants)` fires
`register_type_constructors`. Each variant becomes an env entry:

```
FbState(Int)  → env: "FbState" ↦ Forall([], TFun([TParam("_0", TInt, _)],
                                                   TName("FeedbackSpec", []),
                                                   EfPure))
FbDelay(Int)  → env: "FbDelay" ↦ same shape, TName return
FbFilter(Int, List) → env: "FbFilter" ↦ TFun of two params
```

Zero-field variant (`None`):

```
None → env: "None" ↦ Forall([], TName("Option", []))
```

Every constructor is in env. Call sites resolve.

### Call-site inference (today: partial)

`infer_expr(CallExpr(VarRef("FbDelay"), [LitInt(3)]))`:

1. `infer_var_ref("FbDelay", …)` — looks up env, finds the Scheme.
   Instantiate: `TFun([TParam("_0", TInt, _)], TName("FeedbackSpec", []), EfPure)`.
2. `infer_call(...)` — unifies each arg with each param; binds call's
   handle to the fn's return type. Handle binds to
   `TName("FeedbackSpec", [])`. **Correct.**

Same for `Some(m)` → handle binds to `TName("Option", [])`. Correct.

For nullary `None`: the VarRef's handle binds to `Forall([], TName("Option", []))`. The scheme instantiates to `TName("Option", [])`. Correct.

**But**: at this point, inference has no distinction between "this
is a constructor call" and "this is a regular fn call." The env
entry for `FbDelay` is a Forall(TFun(...)); identical shape to any
user-defined fn whose body happens to return a TName value.

**This distinction is load-bearing at layers 3 and 4.** Without it,
lowering cannot emit the right LIR; backend cannot emit a tagged
record. The substrate cannot distinguish construction from call.

### Design decision — how to distinguish

*Three candidates, tracing each as Mentl:*

**Candidate α — Extend env entry with IsConstructor tag.**
`env_extend(name, Scheme, Reason, IsConstructor: Bool)`.
Constructor registration sets true; fn registration sets false.
Lower reads the tag at CallExpr to decide LCall vs LMakeVariant.

*Trace:* a 4th field in every env entry. Every env_extend site
(scattered across infer.ka) updates. Every env_lookup consumer
that cares reads the new field. Mostly clean; minor cross-file
churn; no new ADT.

**Candidate β — Separate SchemeKind ADT.**
`type SchemeKind = FnScheme | ConstructorScheme(Int, Int) | EffectOpScheme(String)`.
`env_extend(name, Scheme, Reason, SchemeKind)`.
Constructor scheme carries its tag_id AND the total variant count
for the declaring type (needed by exhaustiveness checks later).
EffectOpScheme names the effect.

*Trace:* richer type. Tag_id is accessible to lower without a
second lookup; total_variants makes pattern-exhaustiveness a
graph read. Richer metadata accessible at every env lookup.
Slightly more churn than α at env-touching sites.

**Candidate γ — Inference discovers constructor-ness from type shape.**
No env-level tagging. At lower time, CallExpr's callee is
inspected: if its type is `TFun(_, TName(name, _), _)` AND the
name is in a "declared type names" set, emit LMakeVariant.

*Trace:* lower needs access to a "declared type names" set —
itself passed via a new effect or a parameter. Constructor-ness
is HEURISTIC (a user fn that returns a `TName` looks like a
constructor). The substrate's "is this a constructor" question
has no single source of truth — it's DERIVED from two
correlated facts (return type + declared-type set). This is
drift — the graph should know directly, not derive.

**Mentl's choice: β.** SchemeKind is the explicit story. The
graph stores "this name is a constructor with tag X of type Y"
not "this name has a type that SUGGESTS it might be a constructor."
Handler's contract is clean: env lookup returns a Scheme AND a
SchemeKind. Consumers dispatch on SchemeKind, not on shape
inspection.

**Side-effect of β:** every existing `env_extend` call updates to
pass the SchemeKind. Fn declarations pass `FnScheme`; constructor
registrations pass `ConstructorScheme(tag_id, total_variants)`;
effect op registrations pass `EffectOpScheme(effect_name)`. This
is a known cross-file sweep but well-bounded.

### Pattern-match inference (today: basic)

`match spec { FbDelay(n) => n, … }` — `PCon("FbDelay", [PVar("n")])`.

`infer_pat` needs to:
1. Look up "FbDelay" in env → SchemeKind is ConstructorScheme
2. Instantiate the scheme: `TFun([TParam("_0", TInt, _)], TName("FeedbackSpec", []), EfPure)`
3. Unify scrutinee's type with the return TName
4. Bind each sub-pat to the corresponding param type

Today's `infer_pat` doesn't fully do this; the current wildcard
on Pat (`_ => ()`) may silently skip PCon. H6 surfaces this.

### Exhaustiveness check (today: missing)

`match spec { … }` should require ALL variants of FeedbackSpec be
covered OR a wildcard arm. Today this check doesn't exist — a
match missing `FbFilter` case would compile and fail at runtime.

H3 extends: SchemeKind's total_variants field enables
exhaustiveness check at inference time. If a match on FeedbackSpec
covers 2 of 3 variants without a wildcard → `E_PatternInexhaustive`
(the code already exists in mentl.ka's catalog_summary).

---

## Layer 3 — Lowering (today: BROKEN)

### The problem

`lower_expr_body(CallExpr(f, args))`:

```
CallExpr(f, args) => {
  let lo_f = lower_expr(f)
  let lo_args = lower_expr_list(args)
  if monomorphic_at(handle) {
    LCall(handle, lo_f, lo_args)
  } else {
    let N(_, _, fh) = f
    LSuspend(handle, fh, lo_f, lo_args)
  }
}
```

`FbDelay(3)` lowers to `LCall(handle, LGlobal(_, "FbDelay"),
[LConst(_, LInt(3))])`. Backend emits `call_indirect` through the
fn table. But **FbDelay has no entry in the fn table** — it's not
a function; it has no body. The fn table index lookup fails at
module load OR the call_indirect dispatches to the wrong index,
producing undefined behavior.

### The fix

With β's SchemeKind in place, `lower_expr` at CallExpr consults
it:

```
CallExpr(f, args) => {
  let lo_args = lower_expr_list(args)
  match f {
    N(NExpr(VarRef(name)), _, _) => {
      match env_kind_of(name) {
        ConstructorScheme(tag, _) =>
          LMakeVariant(handle, tag_name(name, tag), lo_args),
        _ =>
          // usual fn-call path
          <existing LCall / LSuspend logic>
      }
    },
    _ => <existing LCall / LSuspend logic>
  }
}
```

Nullary constructors (`None`) also need a direct lowering:
`VarRef(name)` when `name` is a nullary ConstructorScheme →
`LMakeVariant(handle, tag_name, [])`.

### LMakeVariant's tag representation

`LMakeVariant(Int, String, List)` today takes a String tag. The
emit currently stubs this. The real emission:

```
LMakeVariant(handle, ctor_name, field_exprs):
  1. allocate 4 + 4*len(field_exprs) bytes
  2. store TAG (an integer derived from ctor_name) at offset 0
  3. store each field at offset 4 + 4*i
  4. result: pointer on stack
```

The TAG is an integer, not a string. It must be DETERMINISTIC
per (type, variant) pair. Choice:

**Design: per-type variant id.**
At `register_type_constructors`, each variant gets its tag_id
starting from 0: `FbState` → 0, `FbDelay` → 1, `FbFilter` → 2.
SchemeKind's ConstructorScheme(tag_id, total_variants) carries
this.

*Subtle:* two DIFFERENT types with variants named the same get
different tag_ids because they're registered under different type
names. `Some(Int)` of Option has its own tag_id (0). `Some(Int)`
in a hypothetical different ADT would get a different tag_id.
The fully-qualified discriminator is the pair (type_name,
tag_id).

At LMakeVariant emit, we need the INT tag. LMakeVariant's String
argument today carries the constructor name; we extend to pass
the tag_id as an Int. Variant becomes
`LMakeVariant(Int, Int, List)` — (handle, tag_id, fields).

### Pattern-match lowering

`match scrutinee { FbDelay(n) => expr, … }` lowers via LMatch.
LMatch's arms need to check scrutinee's tag vs the pattern's
tag_id and bind the field subpatterns on match.

Today's LMatch is mostly stubbed in the emit. H3 fills this in:
per-arm, emit a comparison `(i32.load offset=0)` on the scrutinee
against the constant tag_id; if equal, bind locals from fields at
offsets 4, 8, 12, …; if unequal, fall through to the next arm.

---

## Layer 4 — Emission (today: stub)

### LMakeVariant emission

Current emit at backends/wasm.ka:874:

```
LMakeVariant(_h, tag, fields) => {
  perform wat_emit("    (i32.const 0) ;; variant ")
  ...
}
```

Stub. The real emit:

```
LMakeVariant(_h, tag_id, fields) => {
  let size = 4 + 4 * len(fields)
  perform emit_alloc(size, "variant_tmp")
  // Store tag at offset 0
  perform wat_emit("    (local.get $variant_tmp)\n")
  perform wat_emit("    (i32.const ")
  perform wat_emit(int_to_str(tag_id))
  perform wat_emit(")\n")
  perform wat_emit("    (i32.store offset=0)\n")
  // Store each field at offset 4 + 4*i
  emit_variant_field_stores(fields, 0)
  // Result: pointer on stack
  perform wat_emit("    (local.get $variant_tmp)\n")
}
```

Mirrors LMakeClosure's emit shape. Uses EmitMemory's swap surface.

### Pattern match emission

Today LMatch emit at backends/wasm.ka is a stub. H3 fills:

```
LMatch(_h, scrutinee, arms) => {
  emit_expr(scrutinee)
  perform wat_emit("    (local.set $scrutinee_tmp)\n")
  emit_match_arms(arms, "scrutinee_tmp")
}

fn emit_match_arms(arms, scrut_local) = {
  // Generate a cascading if-else over arm tag comparisons.
  // Each arm:
  //   if (i32.load offset=0 (local.get $scrut)) == tag_i:
  //     bind fields; emit body
  //   else: next arm
  // Final arm: wildcard or E_PatternInexhaustive trap.
}
```

Subtle: pattern match needs to be a block with a break target so
the first matching arm's body "returns" as the match's value.
WASM has `(block (br_if …))` for exactly this. Implementation
detail.

---

## Layer 5 — what closes when H3 lands

After H3:

1. `FbDelay(1)` is parseable (already true), inference-correct
   (binds to TName), lowering-correct (LMakeVariant), and
   emit-correct (produces a tagged record).
2. `match spec { FbDelay(n) => … }` binds `n` to the field value
   at runtime.
3. Exhaustiveness is checkable: a match missing a variant →
   `E_PatternInexhaustive` at inference time with
   coordinates.
4. C5's FeedbackSpec recognition becomes trivial: `<~ spec` reads
   `spec`'s type, checks it's `TName("FeedbackSpec", _)`, dispatches
   on the variant's tag_id to desugar into the right handler
   shape.
5. Option, Result, List, any other user-declared ADT works the
   same way. Inka gains true discriminated unions.

---

## What H3 reveals (expected surprise)

- **Effect ops vs constructors: same shape, different semantics.**
  Effect ops are also `env_extend`'d with `Forall([], TFun(...))`.
  Today both look identical to lower. β's SchemeKind separates
  them (`EffectOpScheme` vs `ConstructorScheme`). This prompts:
  should effect op registration also pass SchemeKind? YES —
  without it, `perform op_name(args)` vs `op_name(args)` can't be
  distinguished at lower time. H3 naturally extends to cover
  effect ops' dispatch tagging. **This may be a sub-handle that
  closes with H3.**

- **Nullary constructors occupy a sentinel slot.** `None` is a
  zero-field variant. It's inefficient to allocate 4 bytes (just
  the tag). A canonical sentinel approach: allocate ONE `None`
  instance statically at module init (or at compile time as a data
  segment), and every `None` reference is a `(i32.const <that>)`.
  Matches the static-closure pattern we established in Phase A.
  Subtle optimization but worth designing in.

  **Bool is the canonical example.** Once H3 lands, `True` and
  `False` formally become nullary constructors of `type Bool = True
  | False`. Without nullary-sentinel optimization they'd allocate
  4 bytes per `==` / `if` / `&&` / `||` — catastrophic. With it,
  `True` compiles to `(i32.const 1)` and `False` to `(i32.const 0)`
  — same runtime as today's TBool i32 representation, but with full
  ADT semantics at the type level. Bool == ADT semantically, i32
  representationally, indistinguishable in performance from C's
  int-bool. The optimization MUST land alongside H3's general
  constructor machinery. Apply it to every nullary variant
  uniformly: small fixed-tag sentinels are free; only fielded
  variants pay the heap.

  **Implication for Ω.2 (Bool sweep) which lands BEFORE H3:**
  Ω.2 changes str_eq/str_lt to return Bool at the TYPE level. The
  runtime is i32 (already what TBool is per ty_to_wasm). When H3
  lands, True/False become formal constructors WITHOUT changing
  runtime — the nullary-sentinel optimization preserves the i32
  representation. Ω.2 is forward-compatible by construction.

- **Tag-id collisions across types.** As noted: `Some(Int)` of
  Option has tag_id 0. `Some(Int)` of a different ADT (if someone
  declares it) also gets tag_id 0. The type_name discriminates
  at COMPILE TIME via the scrutinee's type. At runtime, the
  tag_id alone doesn't distinguish — but the scrutinee's type
  narrows the alternatives so tag_id is sufficient WITHIN the
  scope of one match. If runtime polymorphism over variants
  ever emerges, this needs revisiting.

- **Pattern exhaustiveness checks depend on the graph knowing
  total_variants.** ConstructorScheme(tag, total_variants) in β
  carries this. Each match's arm set checks against the count.
  Missing variants → E_PatternInexhaustive. **Wildcard in a match
  arm SUPPRESSES exhaustiveness — which is the OPPOSITE of H6's
  anti-wildcard discipline.** User match-wildcards on user ADTs
  are a user choice, distinct from compiler-internal wildcards in
  the substrate. Document this distinction: H6 is about the
  COMPILER's matches; user-level match expressions are free to
  use `_`.

---

## Design synthesis (for approval)

**SchemeKind ADT.** New ADT in types.ka:

```
type SchemeKind
  = FnScheme
  | ConstructorScheme(Int, Int)   // tag_id, total_variants
  | EffectOpScheme(String)        // declaring effect's name
```

**Env extension.** Env entries become 4-tuples:
`(name, Scheme, Reason, SchemeKind)`. env_extend signature adds
a SchemeKind arg.

**LMakeVariant signature refinement.** `LMakeVariant(Int, Int, List)`
— handle, tag_id (Int), field exprs. String → Int.

**Lower's CallExpr dispatch.** When callee is a VarRef to a
ConstructorScheme, emit LMakeVariant; otherwise, existing LCall/
LSuspend path. When VarRef is a nullary ConstructorScheme, emit
LMakeVariant with empty field list (or a static sentinel, per the
surprise).

**Emit's LMakeVariant and LMatch.** Real emission replacing
stubs.

**Exhaustiveness check.** At infer_match_arms, count unique
ConstructorScheme tag_ids among the arms; if < total_variants AND
no wildcard arm, emit E_PatternInexhaustive.

**Test case to verify end-to-end.** The `FeedbackSpec` + `Option`
example above, compiled, WAT inspected manually: each variant
produces a 4+N*4 byte record with correct tag, each match
dispatches on tag load. Verification by walkthrough, not by
wasmtime — consistent with dream-code discipline.

---

## Ordering in the cascade

H3 is the **second** walkthrough to implement after H6. Its
dependencies:
- H6 (wildcard audit) should land FIRST so infer_pat's `_ => ()`
  is already replaced with explicit Pat enumeration — H3 relies
  on PCon being routed correctly.
- Every other handle (H2, H1, H4, H5) depends on H3:
  - H2 (records) is an ADT shape without explicit variants — same
    machinery.
  - H1 (evidence) uses ConstructorScheme-adjacent tagging for
    evidence-record shape.
  - H4 (region) doesn't directly depend but interacts with alloc
    sites that H3 introduces.
  - H5 (Mentl's arms) uses ADT instantiation to construct
    Annotation values at candidate synthesis time.

**H3 is the keystone.** After H3, Inka has real discriminated
unions — the single most thesis-critical substrate piece, because
"the graph IS the program" requires that the graph knows variant
shapes end-to-end.

---

## Estimated scope

- ~6 files touched: types.ka (SchemeKind), infer.ka (env_extend
  sweep, register_type_constructors, infer_match_arms
  exhaustiveness, infer_pat PCon), lower.ka (CallExpr dispatch,
  LMakeVariant signature, lower_pat for PCon), backends/wasm.ka
  (LMakeVariant emission, LMatch emission, tag-id resolution).
- **One integrated commit** during cascade — H3's pieces are
  tightly coupled (SchemeKind flows through every layer).
- **Handler-arm exhaustiveness (possibly surfaces as H6.1).**
  Effect handlers (affine_ledger, infer_ctx, etc.) have arm lists
  per op. Adding a new op to an effect requires every handler
  implementing that effect to extend. Not a `match` wildcard but
  the same structural principle. H3 brushes up against this via
  effect-op SchemeKind.
