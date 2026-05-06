# RN — Refinement-Alias Intent Preservation

*Primitive #6 round-trip. Preserves refinement alias names through
inference and normalization so diagnostics / hover / Verify ledger
speak in authored vocabulary.*

**Part of: IR cluster ([IR-intent-round-trip.md](IR-intent-round-trip.md)).**
**Status: 2026-04-22 · seeded.**

---

## §1 Frame

Mentl's primitive #6 is refinement types — compile-time proof, runtime
erasure. `type Port = Int where 1 <= self && self <= 65535`. Verify
handler discharges predicate obligations at construction sites.

**Gap.** The alias name `Port` is the developer's capability
vocabulary. After inference normalizes / unifies a `Port` value with
its underlying `TRefined(TInt, pred)`, the alias name is not
guaranteed to travel on the type node. Error messages and hover
then speak the raw predicate (`1 <= self && self <= 65535`) instead
of the capability ("Port").

Diagnostic quality delta: *"refinement discharge failed for `1 <= self && self <= 65535`"* vs *"70000 is not a valid Port: the upper bound (65535) fails."*

---

## §2 Trace — where intent drops today

In `std/compiler/infer.mn:187-189` (`RefineStmt` handling):

```
perform env_extend(name, Forall([], TRefined(base_ty, pred)), Declared(name), FnScheme)
```

The name (`Port`) is stored as the env key and in the `Declared(name)`
Reason. The TYPE itself is `TRefined(TInt, pred)` — no alias name
attached. When a value of type `Port` flows through inference,
unification may operate on the refinement, and the alias name is
unreachable from the type alone (must walk the env to find a
matching scheme).

At diagnostic construction (Verify-failure sites), the predicate is
rendered. The env-walk to recover an alias name is possible but not
done. Surface speaks the mechanism (predicate) not the intent (alias).

---

## §3 Design candidates + Mentl's choice

**Candidate A: Extend `TRefined` to carry optional alias name.**
```
TRefined(base: Ty, pred: Predicate, alias: Option<String>)
```
Set at refinement-alias construction (RefineStmt); flows through
unification (alias copies to result when both sides agree, drops
to `None` on inconsistent unification).

**Candidate B: New Ty variant `TAlias(String, Ty)`.**
Wraps any type with its authored name. `Port` is represented as
`TAlias("Port", TRefined(TInt, pred))`. Unification unwraps but
diagnostic rendering peeks the outer layer.

**Candidate C: Env-walk at diagnostic time.**
Keep types unchanged; at Verify failure, walk env looking for a
RefinementScheme matching the predicate. When found, include the
name.

**Mentl's choice: B — `TAlias(String, Ty)`.** Cleanest separation:
the alias is a TYPE-level node (not a field squashed into TRefined).
Composes with future aliases (type aliases, capability-typed aliases).
Unification strips the alias layer for semantic work but preserves it
on the outer type-node handle. Candidate A is narrower (only refinements);
Candidate C scatters intent-lookup across every diagnostic site.

**Unification semantics.** `unify(TAlias(n, a), b)` → `unify(a, b)`
for semantic correctness, but the RESULT handle retains the alias if
both sides used the same alias, drops it otherwise. `show_type(TAlias(n, _))` renders `n`; `show_type(chase(handle))` renders the resolved
form.

---

## §4 Layer touch-points

### parser.mn
No change. `RefineStmt` already captures alias name.

### types.mn
Add `TAlias(String, Ty)` variant to `Ty`. Add `show_type` arm.

### infer.mn
`RefineStmt` handler extends env with `TAlias(name, TRefined(base, pred))`.
Unification handles `TAlias` by unwrapping (semantic) while preserving
on result handle (intent).

### Verify handler (verify.mn)
At discharge-failure site, walk the failing type's outer TAlias
layer. Emit diagnostic naming the alias, the specific sub-predicate
that failed, and the offending value.

### emit / lower
No change. Aliases are compile-time-only.

### Mentl / hover
`perform show_type_authored(handle)` returns the alias-preserved form.
Existing `show_type` could be replaced with this, or coexist.

### cache.mn
Serialize/deserialize `TAlias(n, inner)` preserving the name.

---

## §5 Acceptance

**AT-RN1.** `type Port = Int where 1 <= self && self <= 65535` registered;
`show_type(env_lookup("Port").ty)` renders `"Port"`, not the inner
`Int where ...`.

**AT-RN2.** `fn bind(p: Port) = ...`; a value of inferred type `Port`
renders as `"Port"` in hover. The underlying `TRefined` is reachable
via `chase`.

**AT-RN3.** `bind(70000)` fails with a diagnostic naming "Port" and
the specific failed clause ("`self <= 65535` not satisfied for 70000").

**AT-RN4.** `bind(port_value)` where `port_value: Port` type-checks
without any error — alias preservation doesn't break unification.

**AT-RN5.** Unification of two differently-aliased refinements over the
same base type and predicate preserves one or neither alias (policy
decision: prefer the authored-declaration site's alias; drop on
ambiguous unification).

---

## §6 Scope + peer split

| Peer | Surface | Load |
|---|---|---|
| RN.1 | `TAlias` variant + infer `RefineStmt` wrapping | Light (~15L types.mn + ~5L infer.mn) |
| RN.2 | Unification alias preservation + `show_type` rendering | Moderate (~30L infer.mn + ~10L types.mn) |
| RN.3 | Verify diagnostic upgrade (alias + sub-predicate) | Moderate (~40L verify.mn) |
| RN.4 | Cache serialization round-trip | Light (~15L cache.mn) |

Total: ~115 lines. Four commits, landable in parallel after RN.1
lands first.

Peer consumer (out of RN scope): **FV.3.1-FV.3.4** (refinement-alias
applied sites) gain alias-named diagnostics automatically post-RN.

---

## §7 Dependencies

- **Upstream:** none. Standalone primitive #6 work.
- **Downstream:** FV.3 applied-site peers (FV.3.1/.2/.3/.4) consume RN
  for diagnostic quality. MV.2 capability surfacer reads RN-preserved
  aliases when the alias-named refinement appears in a function's
  type.

No hard gate on order; RN.1 can land before any FV.3.x consumer.

---

## §8 What RN refuses

- **Embedding aliases inside `TRefined`.** That collapses two concerns
  (refinement structure + authored name) into one variant. `TAlias`
  layers them.
- **Alias dispatch at use.** Code that depends on "is this exactly
  `Port` or just some `Int where` refinement" would be coupling to
  intent rather than semantics. RN preserves intent for diagnostic
  and audit surfaces; inference decisions remain semantic.
- **Over-ambitious unification rules.** The alias preservation rules
  above are deliberately simple (same-alias preserves; differing-alias
  drops). More elaborate merge logic can land later if needed.

---

## §9 Connection to the kernel

- **Primitive #6** substrate gains an intent layer matching what the
  author typed.
- **Primitive #8** Reasons at Verify discharge sites gain alias-named
  provenance.
- **Mentl tentacle Verify** reads RN-preserved names when surfacing
  refinement-violation explanations.
