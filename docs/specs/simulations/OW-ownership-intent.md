# OW — Ownership-Intent Preservation

*Primitive #5 round-trip. Preserves `own`/`ref` annotations through
inference and the Consume effect so diagnostics, hover, and Mentl's
Trace tentacle speak in authored ownership vocabulary.*

**Part of: IR cluster ([IR-intent-round-trip.md](IR-intent-round-trip.md)).**
**Status: 2026-04-22 · seeded.**

---

## §1 Frame

Mentl's primitive #5 dissolves ownership into the existing effect
algebra. The developer writes `fn charge(own card: Card)` — meaning
"this function consumes card; it cannot be used again after this
call." Inference sees the `Own` marker on `TParam(name, ty, Own)`,
and at every `VarRef("card")` site, `check_consume_at_use` performs
`consume(name, span)`. The `affine_ledger` handler (own.mn:30-93)
tracks consumed names; a double-consume emits `E_OwnershipViolation`.

**Gap.** The diagnostic at own.mn:35-41 reads:

```
"'card' consumed twice (first at 3:12)"
```

This IS correct — it names the variable and the first-use site. But
the diagnostic never surfaces the authored stance: "card was declared
`own` — consumed here, first consumed at 3:12." The word `own` that
the developer typed doesn't appear. The Consume effect is mechanism;
`own` is intent.

Similarly, `ref` escape diagnostics at own.mn:351-355 read:

```
"ref binding 'card' escapes its scope (returned)"
```

This is better — `ref` appears in the message. But it's a static
string "ref binding", not a reference to the authored annotation.
The same message would fire for an inferred-Ref parameter that the
developer never explicitly annotated.

The intent gap has two aspects:

1. **No ownership provenance on Consume ops.** When `affine_ledger`
   catches a violation, it knows the name and span of the double-use,
   but not WHETHER the parameter was declared `own` by the developer
   or INFERRED as `Own` by `infer_ownership` (own.mn:417-434). The
   authoring distinction matters: a declared `own` violation means
   the developer intended consumption; an inferred `Own` violation
   means the developer didn't annotate and the system classified.
   Mentl's Teach tentacle should surface this difference.

2. **Ownership stance absent from hover/audit.** When a downstream
   surface (hover, audit, Mentl) reads a function's parameters, it
   sees `TParam("card", Card, Own)` — but `Own` is the RESOLVED
   ownership, not necessarily the AUTHORED one. `Inferred` → `Own`
   and explicit `Own` are indistinguishable after `infer_ownership`
   runs. The authored form is on the FnStmt AST node's param list
   (parser preserves it), but nothing threads it to the hover/audit
   handlers.

---

## §2 Trace — where intent drops today

### Parsing (parser.mn)

The parser reads `own` / `ref` keywords and builds
`TParam(name, ty, Own)` or `TParam(name, ty, Ref)`. Unmarked
parameters get `Inferred`. The AST preserves the authored form.

### Inference (infer.mn:200-304)

`infer_fn` mints param handles and extends env with the fn's
scheme. `check_consume_at_use` (infer.mn:705-711) performs
`consume(name, span)` at every VarRef. The `own` marker on the
TParam is not threaded into the Consume op — `consume(name, span)`
carries only the variable name and use-site span, not the ownership
origin.

### Affine ledger (own.mn:30-93)

The handler's state is `used` (consumed names set) and `used_sites`
(name-span pairs). When `consume` fires for an already-consumed
name, it emits `E_OwnershipViolation` with the name and first-use
span. The handler does NOT know whether the original parameter was
declared `own` or inferred `Own`.

### Ownership inference (own.mn:417-434)

`infer_ownership` classifies unmarked (`Inferred`) parameters by
counting uses: 0 → `Inferred`, 1 → `Own`, ≥2 → `Ref`. After this
runs, the TParam's Ownership variant is resolved — the authored
`Inferred` is overwritten. The distinction between "developer wrote
`own`" and "system classified as `Own`" is lost.

---

## §3 Design candidates + Mentl's choice

### §3.1 Ownership provenance on Consume ops

**Candidate A: Extend Consume effect with origin.**
```
consume(name, span, origin: OwnershipOrigin) -> ()
```
Where `OwnershipOrigin = Authored(Ownership) | InferredOwnership(Ownership)`.
The caller (check_consume_at_use) looks up the param's TParam and
constructs the origin. The affine_ledger reads it in diagnostics.

**Candidate B: Handler-side env lookup.**
Keep `consume(name, span)` unchanged. When the affine_ledger fires
a violation diagnostic, it performs `env_lookup(name)` to recover
the TParam and its Ownership marker, then formats the message
accordingly.

**Candidate C: Reason-edge provenance.**
Attach a `OwnershipDeclared(name, Ownership)` Reason to the env
entry at `env_extend` time. Diagnostics read the Reason rather
than the Ownership field directly.

**Mentl's choice: C — Reason-edge provenance.** This is the pattern
already established by primitive #8: Reasons carry provenance.
`Declared("card")` is already the Reason on env entries; extending
to `OwnershipDeclared("card", Own)` threads the authored stance
through the graph without changing the Consume effect signature.
Candidate A forces every Consume caller to look up ownership origin
(scattering concern); Candidate B requires the handler to perform
env reads during its own arm execution (handler arms should be pure
over their state).

**Interaction with primitive #8.** This IS a Reason upgrade —
RX (reason-intent audit) will inventory this site and grade it.
OW.1 seeds the Reason; RX sweeps it.

### §3.2 Authored-vs-inferred distinction

**Candidate A: Never overwrite Inferred.**
`infer_ownership` writes its result to a SEPARATE field
(`resolved_ownership`) alongside the original `Ownership` marker
on TParam. Downstream consumers read `resolved_ownership` for
semantics; hover/audit/Mentl read the original `Ownership` for
intent.

**Candidate B: New TParam field.**
`TParam(name, ty, authored_ownership, resolved_ownership)` — four
fields. `authored_ownership` is always the parser's output;
`resolved_ownership` is infer_ownership's output for Inferred
params, identity for Own/Ref.

**Candidate C: Query handler reads AST.**
Like EN.α: expose the authored param list through a query handler
op. No TParam change; consumers that need the authored form
`perform param_ownership_authored(fn_handle)`.

**Mentl's choice: B — dual-field TParam.** TParam already carries
three fields. Adding a fourth (resolved) is additive and localized.
Candidate A changes the semantics of `Ownership` itself (risky —
every match site would need audit). Candidate C scatters the query
across every consumer. B is explicit: `authored` is what they typed;
`resolved` is what the system determined. When they match, the
developer was explicit. When they differ, the gradient has
something to teach.

**Load.** Moderate. TParam gains a field (types.mn). Every TParam
construction site adds the fourth field. `infer_ownership` writes
to `resolved` only. Display/hover reads `authored` for intent,
`resolved` for semantics.

---

## §4 Layer touch-points

### types.mn
Extend TParam to carry both authored and resolved ownership.
Add `OwnershipDeclared(String, Ownership)` Reason variant (or
use the existing Reason + Located pattern with an Ownership-aware
sub-Reason).

### parser.mn
No change to parsing. TParam construction sets
`resolved = authored` initially (identity default).

### infer.mn
`check_consume_at_use` — no change to Consume op; provenance
flows through the Reason on the env entry's binding.

### own.mn
`affine_ledger`'s violation diagnostic reads the env entry's
Reason to determine authored vs inferred ownership. Messages
upgrade to:
- Declared `own`: `"'card' consumed twice — declared own at 1:15;
  first consumed at 3:12"`
- Inferred `Own`: `"'card' consumed twice — inferred as single-use;
  first consumed at 3:12"`

`infer_ownership` writes to the resolved field, preserving the
authored field.

### Mentl / hover
`show_tparam` (types.mn:793-798) gains authored/resolved display.
Hover on a parameter shows `"card: Card (own — declared)"` or
`"card: Card (own — inferred)"`. Mentl's Trace tentacle reads this
distinction when surfacing ownership explanations.

---

## §5 Acceptance

**AT-OW1.** `fn charge(own card: Card)` — violation diagnostic names
"declared own" and quotes the annotation span.

**AT-OW2.** `fn f(card: Card) = { use(card); use(card) }` — violation
diagnostic names "inferred as single-use" (not "own", since the
developer didn't write it).

**AT-OW3.** Hover on `own card` displays the authored ownership. Hover
on an un-annotated parameter that was inferred `Own` displays
"(own — inferred)".

**AT-OW4.** `ref` escape diagnostic at own.mn:351 distinguishes
authored `ref` ("declared ref — cannot escape") from inferred `Ref`
("inferred as borrowed — cannot escape").

**AT-OW5.** `infer_ownership` preserves the authored Ownership when
writing resolved; the two fields are independently readable.

---

## §6 Scope + peer split

| Peer | Surface | Load |
|---|---|---|
| OW.1 | Reason-edge provenance for ownership on env entries | Light (~10L types.mn + ~5L infer.mn) |
| OW.2 | Dual-field TParam (authored + resolved) | Moderate (~20L types.mn + ~30L own.mn) |
| OW.3 | Diagnostic message upgrade (authored vs inferred) | Moderate (~25L own.mn) |
| OW.4 | Hover/Mentl authored ownership surfacing | Light (~15L types.mn) |

Total: ~105 lines. Four commits, OW.1 → OW.2 → OW.3/OW.4.

---

## §7 Dependencies

- **Upstream:** none. Standalone primitive #5 work.
- **Downstream:** RX (reason-intent audit) inventories the OW Reason
  sites. MV.2's Trace tentacle reads the authored/resolved distinction
  when surfacing ownership explanations. FV.4 (ownership marker
  sweep) gains authored vocabulary automatically post-OW.

---

## §8 What OW refuses

- **Extending the Consume effect signature.** Ownership provenance
  flows through Reasons, not effect ops. Adding fields to
  `consume(name, span)` scatters concern across every consumer and
  breaks the current handler's arm signature.
- **Treating inferred ownership as equivalent to declared.** The
  gradient (primitive #7) depends on the distinction — Mentl can
  teach "annotate `own` here to make the consumption explicit" only
  if she can tell the developer hasn't already done so.
- **Ownership as a runtime concept.** `own`/`ref` are compile-time
  only. No runtime overhead. The affine ledger is a compile-time
  handler; region tracking is compile-time. Post-OW, the intent
  substrate is also compile-time.

---

## §9 Connection to the kernel

- **Primitive #5** substrate gains an intent layer matching what the
  author typed. Diagnostics speak "your `own` parameter" vs "this
  parameter was inferred as single-use."
- **Primitive #7** gradient depends on the authored/resolved
  distinction — Mentl's Teach says "annotate `own` on `card` to
  make consumption explicit" only when the developer hasn't yet.
- **Primitive #8** Reasons at Consume sites gain ownership-stance
  provenance. The Why Engine can walk from a violation diagnostic
  back to the authored annotation (or its absence).
- **Mentl tentacle Trace** reads OW-preserved markers when surfacing
  ownership explanations per turn.
