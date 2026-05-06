# Hβ-first-light.nullary-ctor-call-context

> **Status:** `[LIVE 2026-05-04]` — empirically-real Phase H first-light
> handle. Bug reproduces verbatim against HEAD seed; nullary-ctor
> VarRef positions (`Nothing`, `True`, `False`) emit a closure-capture
> load `(local.get $__state)(i32.load offset=8)` instead of the
> ConstructorScheme tag-id sentinel `(i32.const 1)`.
>
> **Authority:** `Hβ-first-light-empirical.md` §2.3 item 2 (the handle
> was named there 2026-05-04 once the empirical pre-audit isolated
> it); `Hβ-first-light-residue.md` (cascade context);
> `PLAN-to-first-light.md` (live first-light tracker);
> `Hβ-lower-substrate.md` §4.2 (parent walkthrough — VarRef arm
> Lock #2 chain extended here by Lock #2.0 + new Lock #6); `src/lower.mn:333-337`
> (wheel canonical reference for ConstructorScheme RGlobal short-circuit).
>
> **Claim in one sentence:** **`$lower_var_ref` already projects
> `$walk_expr_node_handle` and runs the `$ls_lookup_local` →
> `$ls_lookup_or_capture` → `$lexpr_make_lglobal` triage; the residue
> is to add a SchemeKind dispatch step (Lock #2.0) BEFORE the existing
> triage that calls `$env_lookup($name)`, projects
> `$env_binding_kind`, recognizes ConstructorScheme via
> `$schemekind_tag == 132`, restricts to nullary by checking
> `$ty_tag($scheme_body) == TName_tag (108)`, and short-circuits to
> `$lexpr_make_lmakevariant(h, $schemekind_ctor_tag_id, $make_list(0))`
> — mirroring the wheel's RGlobal `match env_kind_of(name)` branch
> at src/lower.mn:333-337 with the seed-side topology adjustment that
> SchemeKind dispatch wins over local shadow (Lock #6; future shadow
> discipline lands as named follow-up
> `Hβ.lower.ctor-shadow-discipline`), with NO new tags, NO Drift-1
> dispatch table, and NO Drift-6 Bool special-case (Bool's True/False
> ConstructorScheme(1,2) / (0,2) flow through the SAME arm as every
> other nullary ADT per HB).**

---

## §0 Status header + evidence

### 0.1 Substrate landings since walkthrough authoring

This walkthrough is authored at the empirical-pre-audit gate; no
substrate has shifted since `Hβ-first-light-empirical.md` §2.3 item 2
named the handle 2026-05-04. The riffle-back is therefore a no-op:
walkthrough freezes the substrate decision against HEAD as observed
by §A.1 reproduction below.

### 0.2 Empirical reproduction (verbatim §A trace)

Per the mentl-implementer §A pre-audit gate, the bug reproduces
against HEAD seed (`bootstrap/mentl.wasm`, 123674 bytes, built clean
with empty stderr).

**Reproducer** (`/tmp/mentl-nullary-ctor-call.mn`):

```mentl
type Maybe = Just(Int) | Nothing
fn unwrap(m, d) = match m { Just(x) => x, Nothing => d }
fn main() = unwrap(Nothing, 5)
```

Stage-1 exits 0, empty stderr. Output `$main` body emitted by the
seed:

```
  (func $main (param $__state i32) (result i32) (local $state_tmp i32) (local $variant_tmp i32) (local $record_tmp i32) (local $scrut_tmp i32) (local $callee_closure i32) (local $alloc_size i32) (local $loop_i i32)
(global.get $unwrap)(local.set $state_tmp)(local.get $state_tmp)(local.get $__state)(i32.load offset=8)(i32.const 5)(local.get $state_tmp)(i32.load offset=0)(call_indirect (type $ft3))  )
```

The ARGUMENT slot for `Nothing` between `(local.get $state_tmp)` and
`(i32.const 5)` is `(local.get $__state)(i32.load offset=8)` — a
closure-capture load reading slot index 0 from the caller's `$__state`
record. The CORRECT emission is `(i32.const 1)` — Nothing's tag_id
sentinel (Nothing is variant index 1 in the
`Just(Int) | Nothing` declaration, registered as
`ConstructorScheme(1, 2)` per `walk_stmt.wat:867-872`).

### 0.3 Standalone discrimination

To discriminate Scenario L (`$lower_var_ref` doesn't project the
SchemeKind) from Scenario I (CallExpr-only inference flow gap) from
Scenario E (out-of-scope), the standalone test:

```mentl
type Maybe = Just(Int) | Nothing
fn main() = Nothing
```

emits:

```
  (func $main (param $__state i32) (result i32) (local $state_tmp i32) ...
(local.get $__state)(i32.load offset=8)  )
```

The same closure-capture load form appears in standalone position —
NOT `(i32.const 1)`. This refutes the stricter Scenario L hypothesis
("standalone clean / call-arg broken") but confirms the BROADER
Scenario L: the bug lives at `$lower_var_ref` itself, manifesting
identically in both standalone and call-arg positions because both
sites share the lowering function. The fix at the unified site
(SchemeKind dispatch in `$lower_var_ref`) addresses both
manifestations through one substrate edit.

### 0.4 Why $ls_lookup_or_capture finds Nothing

`$infer_register_typedef_ctors` at `walk_stmt.wat:818-874`
`$env_extend`s every variant — including nullary ones — into the
infer-side env. When `$lower_var_ref` runs:

1. `$ls_lookup_local("Nothing")` → -1 (lower's locals ledger never
   bound it; only infer's env did).
2. `$ls_lookup_or_capture("Nothing")` → enters the env_contains
   fallback at state.wat:318: `$env_contains("Nothing")` returns 1
   because `$env_extend` registered it; `$ls_lookup_or_capture`
   records a CAPTURE_ENTRY and returns the capture index (0 for
   first capture in `$main`/`$unwrap` body).
3. `$lower_var_ref` emits `LUpval($h, 0)`, which emit lowers to
   `(local.get $__state)(i32.load offset=8)` (offset 8 = first
   capture slot in the closure record per Hβ.emit closure layout).

This is the closure-capture path triggered by an env hit that should
have been recognized as a ConstructorScheme value-position reference,
not a captured upvalue.

---

## §1 Substrate read

### 1.1 What the env binding already encodes

`$env_extend(name, scheme, reason, kind)` at `env.wat:300-332` writes
a 4-field binding record (tag 130) where:
- field 0 = name
- field 1 = scheme (`scheme_make_forall(qs, body_ty)`, tag 200)
- field 2 = reason
- field 3 = kind (`SchemeKind` — FnScheme | ConstructorScheme |
  EffectOpScheme | RecordSchemeKind | CapabilityScheme)

For nullary `Nothing` per `$infer_register_typedef_ctors`:
- scheme = `Forall([], TName("Maybe", []))` — body Ty IS the result
  type because nullary ctors return the type directly without TFun
  wrapping (lines 848-849).
- kind = `ConstructorScheme(tag_id=1, total=2)` per `schemekind_make_ctor`.

For N-ary `Just(Int)`:
- scheme = `Forall([], TFun([Int], TName("Maybe", []), Pure_row))`.
- kind = `ConstructorScheme(tag_id=0, total=2)` per same.

The kind discriminator + scheme body's tag (TName=108 vs TFun=107) is
ALL the information needed for nullary detection. **The graph already
knows.** No new substrate, no parser change, no inference change is
required — the residue is JUST the projection.

### 1.2 What the wheel does at this site

`src/lower.mn:319-340` runs `perform ls_resolve(name)` returning a
`Resolution` ADT, then matches:
- `RLocal` → `LLocal(local_h, name)`
- `RUpval(slot)` → `LUpval(local_h, slot)`
- `RGlobal` → `match env_kind_of(name) { Some(ConstructorScheme(tag_id, _)) => LMakeVariant(handle, tag_id, []), _ => LGlobal(handle, name) }`

The wheel runs SchemeKind dispatch only in the RGlobal branch, AFTER
RLocal and RUpval have been ruled out — meaning lexical shadows
(`let Nothing = 5`) win over the ConstructorScheme.

### 1.3 Why the seed must reverse the order (Lock #6 rationale)

The seed's `$ls_lookup_or_capture` consults `$env_contains` to decide
between LUpval (yes) and LGlobal (no). Because
`$infer_register_typedef_ctors` extends ConstructorScheme bindings
into the SAME env scope as locals, `$env_contains("Nothing")` ALWAYS
returns 1 — there is no ResolutionKind ADT in the seed to distinguish
"resolved to a local in an outer frame" from "resolved to a top-level
ConstructorScheme". Without that distinction, the env_contains check
falsely treats every ConstructorScheme name as a captured upvalue.

The seed-side topology fix: dispatch SchemeKind FIRST, before the
local/capture triage runs. ConstructorScheme bindings get recognized
as value-position constructor references regardless of whether
`$env_contains` thinks they're "in scope as a captureable name".

This DIVERGES from the wheel's exact order, but the divergence is
intentional and bounded: a future ResolutionKind-aware seed
(`Hβ.lower.ctor-shadow-discipline` named follow-up) can re-establish
the wheel's exact order once the seed grows local-vs-global
discrimination. Until then, ConstructorScheme dispatch wins. The
practical impact is restricted to programs that DELIBERATELY shadow a
constructor name with a local binding (e.g., `let Nothing = 5`) —
those programs will see the constructor's emit pattern, not the
local. This is an edge case the wheel itself does not test and which
the seed need not support to reach first-light-L1.

---

## §2 Eight interrogations cleared

Cleared per the new edit-site (the SchemeKind dispatch block inserted
at `walk_const.wat` $lower_var_ref body).

1. **Graph?** The env binding's SchemeKind + scheme body Ty are the
   answer. `$env_lookup($name)` returns the binding record (tag 130)
   already in the env. `$env_binding_kind` reads field 3.
   `$env_binding_scheme` reads field 1; `$scheme_body` reads its body
   Ty. `$ty_tag` discriminates TName (108) from TFun (107). NO new
   graph reads beyond the four already-landed accessors.

2. **Handler?** `$lower_var_ref` is the single Tier-7 lowering
   function — direct call, OneShot dispatch per chunk #6 spec.
   SchemeKind dispatch lives WITHIN that one func; it does not become
   a separate handler. (Drift 1 refusal: NO dispatch_table for the
   SchemeKind dispatch — direct `(if (call $schemekind_tag ...) ...)`
   form.)

3. **Verb?** N/A — VarRef is a leaf position. The handle's downstream
   consumers (call-arg, match-scrutinee, return-value) are where
   verbs would surface. `$lower_var_ref` itself draws no topology.

4. **Row?** N/A — VarRef carries no effect row. The ConstructorScheme
   short-circuit emits `LMakeVariant` (tag 319) which carries no row
   per Hβ-lower-substrate.md §4.2.

5. **Ownership?** Inputs (`$node`) are `ref` (caller retains).
   `$env_lookup` returns a heap pointer the caller borrows `ref`.
   `$lexpr_make_lmakevariant` produces fresh `own` from bump alloc;
   `$make_list(0)` produces fresh `own` empty list. NO ownership
   ledger writes.

6. **Refinement?** The ConstructorScheme binding's `tag_id` field is
   bounded `[0, total)` by construction in
   `$infer_register_typedef_ctors` (lines 833 + 873 — `tag_id`
   monotonic increment per variant within `[0, total)`). The seed
   does not predicate-check at use site; future
   `Hβ.lower.tagid-refinement` could promote this to a
   compile-time-verified `Ix(total)` refinement. Out of scope here.

7. **Gradient?** This edit is itself a gradient cash-out. Pre-fix:
   nullary ConstructorScheme references at value position ran the
   closure-capture machinery at runtime (4-step LUpval → emit_lupval
   → `(local.get $__state)(i32.load offset=N)`). Post-fix:
   compile-time recognition emits the tag_id sentinel directly
   `(i32.const tag_id)`. The runtime check is replaced by a
   compile-time gradient step — exactly the
   "annotation-unlocks-capability" pattern the gradient encodes.

8. **Reason?** The env binding's reason field (set in
   `$infer_register_typedef_ctors:864-866` to
   `reason_make_located(span, reason_make_declared(vname))`) carries
   the `type Maybe = Nothing` decl's span. The SchemeKind short-circuit
   doesn't write any new Reason; the LMakeVariant's handle field
   carries the VarRef's own GNode-handle whose Reason chain
   `$gnode_reason` walks back to the binding's declared-at site
   through the inference-substrate's handle propagation. NO Reason
   edge written at this dispatch step; the existing edges suffice.

---

## §3 Forbidden patterns

Drift-mode refusals, named:

- **Drift 1 (Rust vtable):** No dispatch_table for the SchemeKind
  arms. Direct `(if (call $schemekind_tag $kind) (i32.const 132) ...)`
  comparison; `(if (i32.eq (call $ty_tag $body) (i32.const 108)) ...)`
  comparison. Tag-int compare against scalar constant. The word
  "vtable" never appears in the substrate. (See SUBSTRATE.md §IX.)

- **Drift 2 (Scheme env-frame stack):** `$env_lookup` already walks
  the scope stack flat-end-to-start; `$lower_var_ref` does not
  iterate frames here. The dispatch is one binding read + projections.

- **Drift 3 (Python dict):** SchemeKind is an ADT (tag 132). NO
  string-keyed lookup ("ConstructorScheme") in the dispatch logic.

- **Drift 4 (Haskell MTL):** No LowerM. `$lower_var_ref` remains a
  direct (func) with single $node param + single i32 result. No
  monad-transformer composition.

- **Drift 5 (C calling convention):** Single $node parameter
  preserved; SchemeKind dispatch reads through the existing
  globals-and-direct-calls topology. NO `__closure`/`__ev` split.

- **Drift 6 (primitive special-case):** Bool's True/False MUST flow
  through this same arm. `type Bool = False | True` registers
  `False` as ConstructorScheme(0, 2) and `True` as
  ConstructorScheme(1, 2) per `walk_stmt.wat:813-817`'s drift-6
  closure note. The nullary check (`$ty_tag scheme_body == TName_tag
  (108)`) succeeds for both because `Bool`'s ctor result types are
  `TName("Bool", [])`. NO special-case carveout for Bool. (HB
  substrate.)

- **Drift 7 (parallel-arrays-instead-of-record):** `$env_binding_*`
  accessors are field-of-record reads, not parallel-array indices.

- **Drift 8 (string-keyed-when-structured):** Tag 132 is the
  ConstructorScheme tag (record-arity-2 with `tag_id`+`total`
  fields). NO `name == "Constructor..."` comparisons. The
  `$schemekind_tag` projection yields an int tag for direct
  comparison.

- **Drift 9 (deferred-by-omission):** This handle lands WHOLE in one
  commit (substrate edit + harness + chunk-header CLOSED block).
  N-ary ConstructorScheme dispatch is OUT OF SCOPE here and named as
  PEER follow-up `Hβ.lower.unsaturated-ctor`. EffectOpScheme dispatch
  in non-perform position is OUT OF SCOPE here and named as PEER
  follow-up `Hβ.lower.varref-effectop-dispatch`. Shadow discipline is
  OUT OF SCOPE and named as PEER follow-up
  `Hβ.lower.ctor-shadow-discipline`. NO "stub" arms; NO
  substrate-now-wiring-later. The nullary arm IS bodied complete.

- **Foreign fluency — LLVM/GHC:** NO "constant folding"; NO "literal
  pool"; NO "SSA value". Vocabulary stays Mentl.

---

## §4 Scenario decision

Per the mentl-implementer §A.5 trace decision:

- §A.1 reproduce: bug REPRODUCES with `(local.get $__state)(i32.load offset=8)` between args.
- §A.3 standalone Nothing: ALSO emits the closure-capture form, NOT `(i32.const 1)`.

The strict §A.2/§A.4 dichotomy ("standalone clean / call-arg broken
→ Scenario L confirmed") is refuted in its narrow form, but the
underlying root cause is BROADER Scenario L: the bug lives at the
unified `$lower_var_ref` site, manifesting identically in both
positions. This is the primary Scenario L hypothesis, just with
broader manifestation than the pre-audit predicted.

**Decision:** Proceed with Scenario L plan. The single substrate edit
at `$lower_var_ref` (SchemeKind dispatch BEFORE local triage)
addresses both standalone and call-arg manifestations identically,
because both share the same lowering function. Per §G.1, the bug
is NOT closed by intervening commit (still reproduces); per §G.2/G.3
no additional peer surface is needed; per §G.4 helper-API divergences
are bounded and the §C.L plan handles them inline.

---

## §5 Substrate edit (Scenario L primary)

Three chunk-header updates + one body extension in
`bootstrap/src/lower/walk_const.wat`:

### 5.1 Edit 1c — Locks section (lines 22-29): "Five Locks" → "Six Locks"

Add Lock #6 (env SchemeKind dispatch wins over local shadow), extend
Lock #2 with Lock #2.0 (the SchemeKind dispatch step). See plan §C
Edit 1c verbatim text — locked.

### 5.2 Edit 1d — Uses block (lines 37-44): four cross-layer additions

Append: `$env_lookup`, `$env_binding_kind`, `$env_binding_scheme`
(env.wat); `$schemekind_tag` (env.wat — note the §C.L pre-check
showed `$schemekind_is_ctor` does NOT exist; the actual canonical name
is `$schemekind_tag` returning the scheme-kind's tag, compared
against the ConstructorScheme tag value 132); `$schemekind_ctor_tag_id`
(env.wat); `$scheme_body` (scheme.wat — note the §C.L pre-check
showed `$scheme_forall_ty` does NOT exist; canonical is `$scheme_body`
reading scheme record field 1, identical semantics); `$ty_tag` (ty.wat
— TName tag is 108 NOT 105 in this seed; the §C.L pre-check
confirmed TList=105, TFun=107, TName=108).

### 5.3 Edit 1a — Named-follow-up CLOSED block (lines 151-155)

Update from "Lands when scheme.wat/kind substrate grows..." to "LANDED
(Hβ.first-light.nullary-ctor-call-context)..." with peer follow-up
forward references. See plan §C Edit 1a — locked.

### 5.4 Edit 1b — `$lower_var_ref` body extension (lines 273-304)

Insert SchemeKind dispatch as Lock #2.0 BEFORE the existing
`$ls_lookup_local` triage:

```wat
(local.set $binding (call $env_lookup (local.get $name)))
(if (i32.ne (local.get $binding) (i32.const 0))
  (then
    (local.set $kind (call $env_binding_kind (local.get $binding)))
    (if (i32.eq (call $schemekind_tag (local.get $kind)) (i32.const 132))
      (then
        (local.set $scheme (call $env_binding_scheme (local.get $binding)))
        (local.set $ctor_ty (call $scheme_body (local.get $scheme)))
        (local.set $ctor_ty_tag (call $ty_tag (local.get $ctor_ty)))
        (if (i32.eq (local.get $ctor_ty_tag) (i32.const 108))
          (then
            (local.set $tag_id (call $schemekind_ctor_tag_id (local.get $kind)))
            (return (call $lexpr_make_lmakevariant
              (local.get $h)
              (local.get $tag_id)
              (call $make_list (i32.const 0))))))))))
```

The existing `$ls_lookup_local` + `$ls_lookup_or_capture` + LGlobal
triage is preserved verbatim BELOW this new block. No removal; only
additive insertion.

**Helper-API divergences from plan §C (§C.L pre-check resolution):**

| Plan name | Actual canonical | Action |
|---|---|---|
| `$schemekind_is_ctor` | `$schemekind_tag` (compare against 132) | Use canonical |
| `$scheme_forall_ty` | `$scheme_body` | Use canonical |
| `$ty_tag` returns 105 for TName | `$ty_tag` returns 108 for TName (105 is TList in this seed) | Use 108 |

These resolutions are mechanical name/value substitutions; the
substrate semantics match the plan exactly. No `Hβ.lower.varref-schemekind-dispatch.helper-API`
peer needed (plan §G.4 trigger NOT fired).

---

## §6 Verification gates (per plan §E)

1. `wat2wasm` exit 0 on assembled `bootstrap/mentl.wat`.
2. L1 candidate diagnostic count must NOT regress (record HEAD pre-fix).
3. `tools/drift-audit.sh` clean on `walk_const.wat`.
4. Existing `walk_const_*.wat` harnesses PASS (lit_int, var_ref_local, var_ref_global).
5. Self-bootstrap delta forward-only.

**Primary acceptance:** `$main` body of the §0.2 reproducer shows
`(i32.const 1)` for the Nothing argument AND `wat2wasm` validates the
output AND `wasmtime run` exits 0 against the validated module.

Expected post-fix `$main` argument-list pattern:
```
(global.get $unwrap)(local.set $state_tmp)
(local.get $state_tmp)
(i32.const 1)              ;; Nothing's tag_id sentinel — was (local.get $__state)(i32.load offset=8)
(i32.const 5)
(local.get $state_tmp)(i32.load offset=0)
(call_indirect (type $ft3))
```

---

## §7 Composes-with audit

Per Anchor 7 ("Three instances earn the abstraction"):

1. **env_binding_kind ↔ schemekind_tag pair:** Already used in
   `walk_call.wat`'s perform/handler dispatch (chunk #7) reading
   binding kind for EffectOpScheme; this is the SECOND consumer.

2. **scheme_body ↔ ty_tag chain:** Used by `$infer_walk_expr_call` in
   `walk_expr.wat:600-700` to discriminate TFun vs TName for the
   instantiate path; this is the SECOND consumer.

3. **lexpr_make_lmakevariant with empty args:** Used at
   `walk_const.wat:237-240` (LitBool arm) for HB drift-6 closure;
   this is the SECOND consumer.

Three instances NOT YET earned for abstraction; the pattern remains
inline at each site. If a third consumer surfaces (e.g.,
`Hβ.lower.unsaturated-ctor` for N-ary; see §10) the abstraction
candidate `$lower_var_ref_constructor_short_circuit` may be factored
out per Anchor 7 step 4. Until then, inline is correct.

The pat-side ConstructorScheme dispatch precedent at
`walk_expr.wat:952-1000` (LowPat construction during match-arm
walking) IS structurally similar — both project SchemeKind for an
identifier in an "is this a constructor?" decision. They differ in
that pat-side runs at infer time + writes LowPat; this edit runs at
lower time + writes LowExpr. The shapes are dual. No factoring is
required because the projection occurs through different output
constructors (LPCon vs LMakeVariant).

---

## §8 Tag region

NO new tags. ConstructorScheme tag 132 already exists; LMakeVariant
tag 319 already exists; TName tag 108 already exists; SchemeKind
record tag 130 already exists. The edit only USES landed tags for
discrimination.

---

## §9 Open questions

### 9.1 Cache double-lookup

`$env_lookup` runs twice in the worst case: once at the SchemeKind
dispatch step (this edit) and once if the dispatch falls through to
the existing local/capture triage (which itself eventually calls
`$env_contains` at state.wat:318). **Decision: NO cache.** The double
lookup is bounded — the inner triage's `$env_contains` is a
binding-presence-only test (returns 0 or 1), not a binding-record
fetch; it cannot reuse this edit's record. The cost is one extra
flat-list scan per VarRef per lowering, which is O(N) where N is the
current scope's binding count (typically O(1) at top-level). Cache
introduces parallel state (Drift 7 risk) for a microscopic perf gain.

### 9.2 Shadow discipline

Lock #6 LOCKED: SchemeKind wins over local shadow. The wheel's
RGlobal-only short-circuit topology requires a ResolutionKind-aware
seed which would be `Hβ.lower.ctor-shadow-discipline` (named PEER
follow-up). Until that lands, programs like `let Nothing = 5; Nothing`
will see the ConstructorScheme dispatch (emit `(i32.const 1)`)
instead of the local. This is acceptable for first-light-L1 because
the wheel's tests do not exercise constructor-shadow.

### 9.3 EffectOpScheme dispatch deferred

`$lower_var_ref` running on a name bound as
EffectOpScheme(effect_name) (e.g., `let f = log; f("x")`) is OUT OF
SCOPE here. Named PEER follow-up `Hβ.lower.varref-effectop-dispatch`.

### 9.4 RecordSchemeKind / CapabilityScheme dispatch

OUT OF SCOPE; no named follow-up surfaces yet because the wheel
canonical's value-position uses of these are unverified. If a
post-L1 wheel test exercises one, a named follow-up will surface
then.

---

## §10 Acceptance

The handle lands when:
- `bootstrap/src/lower/walk_const.wat` Edits 1a–1d applied per §5.
- `bootstrap/test/lower/walk_const_var_ref_nullary_ctor.wat` harness
  PASSES (per plan §F): registers a synthetic `Nothing`
  ConstructorScheme(1,2) binding with `TName("Maybe",[])` body,
  constructs VarRef("Nothing"), calls `$lower_var_ref`, asserts result
  tag == 319 (LMakeVariant) AND `tag_id == 1` AND `args.len == 0`.
- Sibling assertion in same harness (or peer): N-ary `Just` with
  ConstructorScheme(0,2) + TFun ctor type STILL falls through to
  `$lexpr_make_lglobal` (NOT short-circuited) — proves the nullary
  discriminator works.
- Plan §E gates 1-5 + primary acceptance pass.
- `Hβ-first-light-empirical.md` §2.3 item 2 receives a CLOSED block
  per `Hβ-first-light-residue.md` shape.
- `walk_const.wat:151-155` named-follow-up CLOSED.
- N-ary peer named: `Hβ.lower.unsaturated-ctor`.
- Shadow peer named: `Hβ.lower.ctor-shadow-discipline`.
- EffectOp peer named: `Hβ.lower.varref-effectop-dispatch`.

The cursor advances to the NEXT first-light-empirical §2.3 / §4.5.4d
gap (e.g., string-interning-dedupe or ptuple-let-destructure) — this
handle does NOT close other peer follow-ups.
