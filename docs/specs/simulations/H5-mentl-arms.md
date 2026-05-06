# Handle 5 — Mentl's Arms

*Role-play as Mentl, this time not tracing substrate — ACTING as
the oracle. Two arms, each a user-visible output of the thesis
made flesh. I15 `AWrapHandler` proposes wrap-candidates that
unlock tighter signatures. I17 `mentl audit` walks the capability
stack transitively and names what could be tightened.*

---

## The scenarios

### I15 scenario

```
fn pure_op(items: List) with Pure = {
  List.sort(items)
}
```

`List.sort` allocates. Its row is `EfClosed(["Alloc"])`. `pure_op`
declares `with Pure` which collapses to `EfPure`. Row algebra
fires at FnStmt: body_row `["Alloc"]` is NOT ⊆ declared_row
`EfPure`. Today this is E_PurityViolated.

**Mentl's I15 proposition:** wrap the `List.sort(items)` call in
a `temp_arena` handler that absorbs Alloc. Body row becomes
EfPure. Signature satisfied. Quick Fix offered.

The user sees:

```
E_PurityViolated at line 2: body performs Alloc; Pure is declared.
  Proposed fix (MachineApplicable): wrap List.sort(items) in
  `handle { ... } with temp_arena`. After wrap, body is proven
  Pure. This unlocks CMemoize + CCompileTimeEval.
```

### I17 scenario

```
fn pipeline(source) =
  source
    |> parse_program
    |> lower_to_lir
    ~> graph_handler
    ~> diagnostics_handler
    ~> env_handler
```

The pipeline attaches three handlers. `diagnostics_handler`
reports to stderr. `graph_handler` mutates the Graph.
`env_handler` scopes env. What's the cumulative capability set?

**Mentl's I17 audit:**

```
$ mentl audit pipeline.mn
pipeline(source):
  REACHED capabilities (effects actually performed by the body):
    - Graph (via graph_handler)
    - Diagnostics (via diagnostics_handler)
    - EnvScope (via env_handler)
  UNREACHED handlers (installed but never needed):
    - (none)
  SEVERANCE CANDIDATES (effects not in body — could add !E):
    - !Alloc — body performs no allocation
    - !IO — body performs no IO
    - !Network — body performs no network
  Adding `with !Alloc + !IO + !Network` to pipeline would unlock:
    - CRealTime, CCompileTimeEval, CSandbox
```

The user sees a capability gradient. Each `!E` they add unlocks a
compile-time capability.

---

## Layer 1 — I15 AWrapHandler

### Annotation extension

`Annotation` gains a new variant:

```
// In mentl.mn:
type Annotation
  = APure(Option)
  | ANotAlloc(Option)
  | ANotIO(Option)
  | ANotNetwork(Option)
  | ARefined(String, Predicate, Option)
  | AOwn(String, Option)
  | ARef(String, Option)
  | AWrapHandler(String, Int, Option)   // handler_name, target_handle, source_span
```

`target_handle` is the expression to wrap. `handler_name` is
the candidate handler (e.g., "temp_arena"). `Option(Span)`
threads source site as with all Annotation variants.

### apply_annotation_tentatively

New arm:

```
AWrapHandler(hname, target, sp) => {
  // 1. Look up the handler's declared arm list (handled_op_names)
  let handled_ops = perform get_handler_ops(hname)
  
  // 2. Read target's effect row (its ambient row at target's site)
  let target_row = perform row_at_handle(target)
  
  // 3. Compute wrapped_row = absorb_row(target_row, EfClosed(handled_ops), arm_row)
  let arm_row = perform handler_arm_row(hname)
  let wrapped = absorb_row(target_row, mk_ef_closed(handled_ops), arm_row)
  
  // 4. Narrow the target handle to have the wrapped row
  let target_node = perform graph_chase(target)
  match target_node {
    GNode(NBound(TFun(params, ret, _)), _) => {
      let narrowed = TFun(params, ret, wrapped)
      perform graph_bind(target, narrowed,
        Located(unwrap_source_span(sp),
                Inferred("mentl wrap-candidate: "
                  |> str_concat(hname))))
    },
    _ => ()
  }
}
```

### Candidate enumeration

At each FnStmt that fails declared-effects subsumption:

1. Read body's actual row (from row_handle).
2. Read declared row.
3. Compute `surplus = body_row \ declared_row` — the effects that
   overshoot the declaration.
4. For each op in surplus, enumerate handlers that handle it:
   `perform handlers_absorbing(op_name) -> List[String]`.
5. For each candidate handler, build AWrapHandler(handler,
   body_handle, Some(body_span)) and add to oracle's candidate
   list.
6. Oracle's try_each_annotation walks the list with
   checkpoint/rollback; passes become PROVEN candidates.
7. pick_highest_leverage returns the best — unlocks the most
   capabilities per wrap.

### Handler catalog

A new effect: `HandlerCatalog`. Its arms return the currently-
declared handlers:

```
effect HandlerCatalog {
  handlers_absorbing(String) -> List    // op_name -> [handler_name]
  handler_arm_row(String) -> EffRow     // handler_name -> arms' row
  get_handler_ops(String) -> List       // handler_name -> [op_name]
}
```

Populated by inference's `register_handler` sweeps over the
source. Every handler declaration registers (name, handled_ops,
arm_row) into this catalog handler's state.

### Quick Fix emission

When a PROVEN AWrapHandler candidate exists, teach_error produces
an `Explanation` with a Patch:

```
Explanation(
  "E_PurityViolated",
  "docs/errors/E_PurityViolated.md",
  "function '<name>' declares Pure but body performs Alloc",
  Some(Patch(body_span, "handle { " ++ body_text ++ " } with temp_arena")),
  reason_chain
)
```

The Patch's source text is a constructed wrap around the body.
Render uses span coordinates. IDE shows Quick Fix. User clicks
— compiler applies Patch — file rewrites — code compiles.

---

## Layer 2 — I17 mentl audit

### New Question variant

In query.mn:

```
type Question = ... | QCapabilitySet(String)   // fn_name to audit
```

### The walk

`QCapabilitySet(fn_name)` looks up the fn's FnStmt, reads:

1. **Body row** = effects actually performed by the body (from
   the fn's row_handle).
2. **Handler stack along the body** = handlers installed via
   `~>` chain + inner `handle ... with`s. From handler_stack
   state at inference time.
3. **Installed-but-unused** = handlers whose arms handle effects
   NOT in body row. These are overhead; flag as "unreached."
4. **Severance candidates** = effects NOT in body row that could
   be explicitly negated via `!E`. For each, compute the
   capability unlock via `unlock_capability(ANot<E>)`.

### The diagnostic

`audit` builds a structured report:

```
type AuditReport
  = Audit(
      String,          // fn name
      EffRow,          // body row (what's performed)
      List,            // reached handlers [(handler, [ops-reached])]
      List,            // unreached handlers (installed, not needed)
      List,            // severance candidates [(eff_name, capability)]
      Reason           // why chain
    )
```

Rendered via a new `render_audit(AuditReport) -> String` in
mentl.mn (or a new audit.mn). The rendered output is the
coordinate-rich audit the user sees.

### Pipeline route

```
fn audit(source) =
  source
    |> frontend
    |> infer_program
    |> inka_audit_walk
    ~> mentl_default
    ...
```

inka_audit_walk iterates every FnStmt, builds AuditReport,
renders. Output to stdout or a JSON stream (the IDE consumes).

---

## Layer 3 — what closes when H5 lands

**I15:**
- `AWrapHandler` annotations reach users as Quick Fixes.
- Mentl's oracle becomes PROPOSITIONAL — it doesn't just check;
  it suggests PROVEN alternatives.
- E_PurityViolated, E_EffectMismatch, E_HandlerUninstallable all
  gain Patch suggestions where a wrap would solve the problem.
- The gradient becomes a conversation: user sees the proposal,
  sees the capability unlock, chooses.

**I17:**
- `mentl audit <file>` surfaces every fn's capability set with
  severance candidates.
- Users can tighten signatures deliberately; each tightening
  unlocks real compile-time capabilities.
- CI pipelines integrate `mentl audit` checks; declaration-
  tightness becomes a reviewable property.

**Both together:**
- Mentl is complete. The thesis is operational. "The compiler
  IS the AI" is observable behavior, not just architectural
  claim.

---

## What H5 reveals (expected surprise)

### Revelation A — HandlerCatalog needs population

Handler declarations today are parsed but the oracle doesn't
have a queryable catalog. H5 adds a catalog effect + population
pass during inference. **Sub-handle possibly: H5.1 catalog
population sweep.**

### Revelation B — Patch text synthesis

Patches include source-text replacements. Rendering
`handle { <body_text> } with temp_arena` requires reading the
ORIGINAL source text at body_span. The source string is
available at frontend time but may not be threaded to
mentl.mn's oracle. A new effect `source_slice(Span) -> String`
or similar. **Sub-handle: H5.2 patch text synthesis.**

### Revelation C — "temp_arena" is a concrete handler name — but which concrete?

The candidate `temp_arena` in my examples is a specific
handler name. In a real project, the handler LIBRARY would
register available handlers at program startup. For first
landing, Mentl's std lib declares canonical handlers:
`temp_arena` (Alloc absorber), `log_to_stderr` (IO absorber),
`dry_run_network` (Network absorber). HandlerCatalog knows
these.

### Revelation D — I15 candidate enumeration interacts with H1's evidence

When Mentl tentatively wraps a call in a handler, the wrapped
call's evidence shape changes. The graph needs to re-infer
ev_shape for the wrapped body. This is automatic if apply_
annotation_tentatively triggers a re-inference (it does, via
checkpoint/rollback). But the re-inference must recompute
ev_shape consistently with H1's derivable-from-row approach.
**H1 and H5 are consistent here — γ-style ev_shape derivation
handles this cleanly.**

### Revelation E — The audit's reach

`mentl audit` could walk more than one fn. It could report for a
whole MODULE or even a whole PROJECT. For first landing, fn-
scoped audit. Project-scoped audit is a trivial extension
(iterate over fns) but produces voluminous output; defer UI
polish.

### Revelation F — What Mentl renders in the terminal vs. IDE

Terminal: plain-text with ANSI colors (optional). IDE: JSON
stream that the LSP server consumes. Both renderers exist;
shared AuditReport → render_terminal / render_json.

---

## Design synthesis (for approval)

**I15:**
- Extend Annotation with AWrapHandler(String, Int, Option).
- Add HandlerCatalog effect — arm-list registration during
  inference.
- apply_annotation_tentatively arm for AWrapHandler uses
  checkpoint/rollback + absorb_row.
- Gradient candidate enumeration at failing FnStmts.
- Patch synthesis via source_slice effect + constructed wrap
  template.

**I17:**
- Add QCapabilitySet(String) to Question.
- audit pipeline route.
- AuditReport ADT.
- render_audit terminal + JSON renderers.
- inka_audit_walk iterator over FnStmts.

**Both depend on H1 (evidence) being complete** for the
re-inference-through-oracle path to consistently produce
ev_shapes. H5 lands AFTER H1.

---

## Dependencies

- H6 FIRST (substrate hygiene — exhaustive ADT matches in
  oracle walks).
- H3 BEFORE (ConstructorScheme machinery — for Annotation
  constructors, for AuditReport construction).
- H2 BEFORE (record construction — for AuditReport struct).
- H1 BEFORE (evidence reification — for oracle's re-inference
  to produce consistent ev_shapes post-wrap).
- H4 BEFORE (region escape — the oracle considers escape
  implications when proposing wraps).
- H5 is the LAST handle. Closes the cycle.

---

## Estimated scope

- ~5 files touched: mentl.mn (Annotation extension,
  apply_annotation_tentatively arm, gradient enumeration,
  HandlerCatalog effect + handler), query.mn (QCapabilitySet),
  pipeline.mn (audit route), a new audit.mn (AuditReport +
  renderers) or extension of mentl.mn, docs/ (example usage +
  audit output format).
- **One commit.** Tight internal coupling; AWrapHandler and
  audit share the HandlerCatalog substrate.
- **Sub-handles possibly:** H5.1 catalog population, H5.2
  patch text synthesis. Named; absorbed into H5 if trivial.

---

## Post-H3 / H3.1 / H2 / Ω.5 implications (riffle-back)

H5 was drafted before the substrate landings. Its propositions
remain right; its substrate becomes friendlier. Three places need
sharpening before H5 lands.

### Effect names everywhere become EffName, not String

The walkthrough writes `["Alloc"]`, `"Pure"`, `"IO"` as bare
strings. Post-H3.1, every row entry is an `EffName` — `ENamed("Alloc")`
or `EParameterized("Sample", [EAInt(44100)])`. Every place H5
reads or writes a row needs to use the EffName shape.

Concrete patches:

```
// before
let alloc_row = mk_ef_closed(["Alloc"])
// after
let alloc_row = mk_ef_closed([ENamed("Alloc")])
```

```
// AuditReport's severance candidates
type AuditReport = {
  ...
  severable: List      // List<EffName> not List<String>
  unlocks: List        // List<Capability>  — Capability is a String
}
```

The render side (terminal / JSON) calls `show_eff_name(name)` —
already exists in types.mn. `Sample(44100)` renders correctly.

**Mentl gains a parameterized-effect audit category for free.** A
function declaring `with Sample(44100)` could be tightened to
`with Sample(44100) + !Alloc + !IO + ...` — same severance logic,
EffName-aware. The gradient walkthrough's I17 example with
`Sample(44100)` becomes substrate-native.

### AuditReport, gradient candidates, ANY Mentl output IS a record

H2 makes records a first-class shape. AuditReport's structure:

```
type AuditReport = {
  fn_name: String,
  reached: List,           // List<EffName>
  unreached: List,         // List<HandlerName> — handlers installed but unused
  severable: List,         // List<EffName> — not in body, could add !E
  unlocks: List,           // List<Capability> — what severance enables
  proposed_signature: String
}
```

The terminal renderer reads fields by name; JSON renderer
introspects each field. The Proof Lens (post-cascade enhancement)
introspects the same record on hover. **One record, three
projections** — exactly the substrate-handler discipline H5
operationalizes.

Gradient candidates are records too:

```
type WrapCandidate = {
  handler_name: String,
  span: Span,
  unlocks_capabilities: List,
  text_patch: String,        // the diff fragment
  proven: Bool               // checkpoint/inference/Verify all passed
}
```

Mentl's "PROVEN before suggestion" discipline (per the post-cascade
plan) IS a Bool field on the record. The IDE filters by it.

### HandlerCatalog state is a record

Following Ω.5's frame-record pattern:

```
handler handler_catalog with state = {
  registered: [],            // List<{handler_name, handles_effect, op_arms}>
  install_sites: []          // [(handler_name, span)]
} {
  catalog_register(name, eff, arms) =>
    ...
}
```

Each `registered` entry is itself a record. Mentl's enumeration
walks the list of records by field name. Adding new metadata
(`memory_safety: Bool`, `purity_witness: Bool`) is additive.

### Mentl uses ConstructorScheme to enumerate AnnotationKind candidates

H3's ConstructorScheme(tag_id, total_variants) means: when Mentl
considers all possible annotations to apply, it can read
`Annotation`'s declared variants from env (their tag_ids and total
count) instead of hard-coding the variant list. **Future-proof: a
new Annotation variant added to types.mn automatically becomes a
candidate Mentl considers.**

```
// Walking annotation candidates
fn enumerate_annotation_candidates() =
  match perform env_lookup("Annotation") {
    Some(entry) => {
      let (_, _, kind) = entry
      match kind {
        ConstructorScheme(_, total) => /* enumerate 0..total */,
        _ => []
      }
    },
    None => []
  }
```

Today this would be a hardcoded match over Annotation variants.
After H3, it's a graph read.

### Frame records (Ω.5) carry forward into H5's apply/rollback walks

Mentl's oracle walks: tentatively bind handle → apply annotation →
re-infer → check verify → either commit or rollback. The "store
rollback state" was tuple-based per the walkthrough. Post-Ω.5,
each tentative state IS a record:

```
type OracleState = {
  trail_checkpoint: Int,
  applied_annotation: Annotation,
  before_verify_count: Int
}
```

Adding a "before_diagnostic_count" field (so rollback erases
emitted diagnostics) is additive. The discipline keeps Mentl's
exploration honest — every speculative state is fully captured;
rollback restores every field.

### What H5 inherits

- Records (H2) for every Mentl output structure.
- ConstructorScheme (H3) for variant enumeration without hardcoding.
- EffName (H3.1) for parameterized effects in audits.
- Frame records (Ω.5) for oracle exploration state.
- Heap-uniform alloc + EmitMemory swap surface — Mentl's tentative
  records are as cheap as any other; arena reclamation gives them
  natural lifetime.

### The thesis crystallizes

Mentl IS the projection. Every Mentl output is a record. Every
candidate is a record. Every audit step reads from and writes to
records. The substrate H5 lands ON is records-all-the-way-down —
no string-keyed dictionaries pretending to be structured data.

Post-cascade, Mentl's Proof Lens / Gradient ghost text / Structure-
edit mode become record introspection. The IDE doesn't need to know
about Mentl's output shapes — it just walks the record's fields and
renders. **H5 is what makes the post-cascade enhancements
projectable.** The walkthrough's "Mentl is the thesis made flesh"
gains a substrate corollary: "the flesh IS the record."

### Updated estimated scope

Unchanged: ~5 files. Internal coupling stays. The substrate
landings simplify the implementation rather than expand it — every
record is a literal; every annotation enumeration is a graph read;
every effect comparison is structural.
