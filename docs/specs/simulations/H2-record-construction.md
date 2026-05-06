# Handle 2 — Record Construction

*Role-play as Mentl, tracing record literal `{name: "Morgan",
age: 30}` through parser, inference, lowering, emission. Resolves
whether records are structural (anonymous, row-polymorphic) or
nominal (declared like ADTs), and whether they reuse H3's ADT
machinery or take their own layout.*

---

## The scenario

Morgan writes:

```
let user = {name: "Morgan", age: 30}
let display_name = user.name
let older = {name: user.name, age: user.age + 1}

fn greet(u: {name: String, age: Int}) -> String =
  "Hello, " ++ u.name

greet(user)
```

Four record construction sites. Four field accesses. One
parameter type declared structurally. Row polymorphism is LATENT
in `TRecordOpen` — does the user ever write it?

What has to work? Trace each layer.

---

## Layer 0 — structural vs nominal

**Mentl chooses STRUCTURAL records.** Two facts support this:

1. `TRecordOpen(fields, row_var)` already exists in the substrate
   — that's row polymorphism, which is structural.
2. DESIGN Ch 4 "the graph IS the program" implies records are
   a SHAPE the graph recognizes, not a name the graph must be
   told about.

Consequence: `{name: String, age: Int}` is a COMPLETE TYPE by
itself. No `type User = {...}` declaration needed. Two records
with the same field names and types unify directly. Row
polymorphism lets a function accept `{name: String, …}` (anything
with at least `name`).

**Records and ADTs are different kinds of SHAPES.** An ADT is
tagged — its layout is `[tag:i32, field_0:i32, ...]`. A record
is untagged — `[field_0:i32, field_1:i32, ...]`. LFieldLoad
(Phase E) already assumes the latter (`4 * sorted_index`, no
tag). Keeping records untagged preserves that design.

---

## Layer 1 — Parser (today: absent)

### Record type syntax

```
{name: String, age: Int}
```

Tokens: `LBrace Identifier("name") Colon Identifier("String") Comma Identifier("age") Colon Identifier("Int") RBrace`.

parse_type_ty needs a new arm: when a `{` appears in a type
position, parse `field: Ty` pairs separated by commas until `}`.
Produce `TRecord(sorted_fields)`. Sort by name at parse time so
the smart-constructor invariant holds from the get-go.

Row-polymorphic form: `{name: String, ...R}` — open record, row
variable `R`. Produces `TRecordOpen(sorted_fields, fresh_row_h)`.
Slightly more complex grammar; defer this to a sub-handle
(H2.1) if out of scope.

### Record literal syntax (expression position)

```
{name: "Morgan", age: 30}
```

Same token shape but value position. Parser adds a new Expr
variant:

```
// Add to Expr in types.mn:
| MakeRecordExpr(List)            // [(String, Node)] — field bindings
```

parse_primary needs a new arm: when `{` appears in expression
position AND the next token is `Identifier Colon ...`, parse as
record literal. Produce `MakeRecordExpr([(name, expr), ...])`
sorted by name at parse time.

**Subtle:** `{` in expression position already means "block"
(if/else bodies, function bodies). Disambiguation: look ahead
past the first `{`. If the next non-whitespace token is an
Identifier followed by `:`, it's a record literal. Otherwise,
it's a block. This is a parse-level local choice — no effect on
the grammar's ambiguity class (LL(2) with limited lookahead).

### Pattern syntax (record pattern)

```
let {name, age} = user
```

Parser needs PRecord(fields) — already in types.mn at
`| PRecord(List)  // [(fieldname, Pat)]`. Parse arm:
`{ field_name[ : sub_pat] [,] ... }` → PRecord with each entry
being either `(name, PVar(name))` if no sub-pat or `(name, sub_pat)`.

### Shorthand — field punning

`{name, age: 30}` where `name` stands for `name: name` (the
variable `name` from current scope). A convenience. Add it as a
PARSER concern; the AST node is still MakeRecordExpr with
`(name, VarRef(name))`.

---

## Layer 2 — Inference

### Record literal inference

`MakeRecordExpr([(String, Node)])` — the fields. Parse sorts them.

```
NExpr(MakeRecordExpr(fields)) => {
  infer_expr_list(map_snd(fields))   // infer each field expression
  let field_types = build_record_field_types(fields)
  perform graph_bind(handle, TRecord(field_types),
    Located(span, Inferred("record literal")))
}
```

`field_types` is `[(name, TVar(expr_handle))]`, sorted by name.

### Row-polymorphic record parameter

For `greet(u: {name: String, ...R}) -> ...`, the parameter's type
is `TRecordOpen([(name, TString)], row_h)`. At call site, the
argument's type is unified with this expectation. Unification of
TRecord vs TRecordOpen:
- `TRecord(fields)` unifies with `TRecordOpen(expected, v)` when
  every field in `expected` appears in `fields` with the same
  (unifiable) type. The residual fields (`fields \ expected`)
  bind `v` to `TRecordClosed(residual)` — the remainder.
- This is the standard row-polymorphism unification rule.

**The substrate already has TRecordOpen; the unification rule is
partially implemented in effects.mn's row-unification for EffRow.
H2 needs the Ty-level analog.**

### Field access inference (already works via lookup_ty)

`user.name` at FieldExpr:
- infer_expr(user) → bind user's handle to its TRecord/TRecordOpen type
- infer_expr(FieldExpr(user, "name")) constructs an expected
  `mk_record_open([("name", TVar(fresh))], fresh_row)` and unifies
  with user's type. The unification forces user's type to contain
  at least the field `name`. fresh's handle binds to the field's
  type.

Already works today (modulo TRecord/TRecordOpen unification). H2
makes the construction side exist so the inference is end-to-end.

### Subtle: sorted-field invariant

TRecord(fields) and TRecordOpen(fields, v) rely on fields being
sorted by name. Smart constructor `mk_record_open` (landed in
Phase A) enforces this on construction. Parser produces sorted
fields. Inference's `build_record_field_types` produces sorted
fields. Every construction site ensures the invariant. No
canonicalize-at-boundary tax.

---

## Layer 3 — Lowering

### LMakeRecord LIR variant

New LIR:

```
| LMakeRecord(Int, List)    // handle, [LowExpr] — fields in sorted order
```

Field order at the LIR level is SORTED-BY-NAME, same as TRecord.
The field names are erased (layout is positional at runtime); the
Ty-level information is what inference carried.

**Lowering:** `MakeRecordExpr(fields)` → `LMakeRecord(handle,
lower_expr_list(map_snd(fields)))`. Because fields were parsed
sorted, their lowered exprs are in the correct layout order.

### LFieldLoad (already landed in Phase E)

Current:

```
LFieldLoad(handle, lo_rec, offset)
```

Where offset is `4 * field_index`. With records laid out as
`[f_0:i32, f_1:i32, ...]`, the first field is at offset 0, second
at 4, etc. This is consistent with the new LMakeRecord's
allocation.

### Pattern lowering (PRecord)

```
PRecord(field_pats) → 
  Expand into a sequence of LFieldLoad + local binds, one per
  field the pattern names. Fields not in the pattern are ignored.
```

Today PRecord is in types.mn but never lowered. H2 adds the
lowering.

---

## Layer 4 — Emission

### LMakeRecord emit

```
LMakeRecord(_h, fields) => {
  let n = len(fields)
  let size = n * 4   // no tag; just N*4 bytes
  perform emit_alloc(size, "record_tmp")
  emit_record_field_stores(fields, 0, "record_tmp")
  perform wat_emit("    (local.get $record_tmp)\n")
}

fn emit_record_field_stores(fields, i, local_name) =
  if len(fields) == 0 { () }
  else {
    perform wat_emit("    (local.get $")
    perform wat_emit(local_name)
    perform wat_emit(")\n")
    emit_expr(list_head(fields))
    perform wat_emit("    (i32.store offset=")
    perform wat_emit(int_to_str(i * 4))
    perform wat_emit(")\n")
    emit_record_field_stores(list_tail(fields), i + 1, local_name)
  }
```

Mirrors emit_capture_stores (Phase A). Uses EmitMemory swap.

### Every backend match site

Five backend match sites need LMakeRecord:
- collect_fn_names_expr: `LMakeRecord(_, fs) => collect_fn_names_list(fs, acc)`
- collect_strings_expr: recurse into fields
- emit_fns_expr: recurse into fields
- emit_let_locals_expr: recurse into fields
- emit_expr: the actual emission above

Plus lexpr_handle + max_arity_expr. Seven sites total, same
pattern as W4/E2 substrate prep.

---

## Layer 5 — what closes when H2 lands

- Record construction works end-to-end.
- Record field access (already in Phase E) has a source to read
  from.
- Structural record types unify with row polymorphism.
- Pattern `let {name, age} = user` binds locals.
- `greet(user)` with row-polymorphic parameter types works.
- Mentl has first-class structural records without a declaration
  ceremony.

---

## What H2 reveals (expected surprise)

- **Field access-during-construction (`{x, y}` where x and y are
  in scope).** The shorthand punning means `{x, y}` desugars to
  `{x: x, y: y}`. This is STRUCTURAL punning — different from
  ADT constructors. No surprise beyond parser-local work.

- **Records vs ADT variants share NOTHING at the LIR level.**
  Records are `LMakeRecord` (untagged); variants are
  `LMakeVariant` (tagged). Initially I considered reusing
  LMakeVariant with tag_id=0 for records, but the layout
  divergence (tag:i32 prefix vs no prefix) means LFieldLoad's
  offset math would need a runtime flag or a compile-time mode.
  Two distinct LIR variants is cleaner.

- **Row polymorphism unification on TRecord/TRecordOpen.** This
  is ACTUAL WORK — the effects.mn row-unification pattern applied
  to Ty's TRecord variants. The algorithm is straightforward (the
  same merge pattern we use for effect rows) but the code isn't
  written yet. Could surface as H2.1 if out of scope.

- **Updating records.** DESIGN mentions `user with {age: 31}` —
  the functional update expression. Not in this walkthrough's
  scope — add as H2.2 if needed. Today's H2 covers LITERAL
  construction only.

- **Records in closures.** Captures can be record values. Each
  captured record is a pointer (i32) — no special handling
  required beyond the standard capture mechanism. No surprise.

---

## Design synthesis (for approval)

**Structural records.** No declaration syntax needed; types are
`TRecord` / `TRecordOpen` directly. Field-punning in parser for
convenience.

**LMakeRecord(Int, List)** distinct from LMakeVariant. Untagged
layout: `[f_0:i32, f_1:i32, ...]`. Field order: sorted by name
at parse time; preserved at lowering.

**Parser additions.** Record type in type position; record
literal in expr position (disambiguated by lookahead past `{`);
record pattern. Field-punning shorthand.

**Inference additions.** TRecord/TRecordOpen unification rule
(row-polymorphism analog of EffRow). `build_record_field_types`
for literal expressions. PRecord pattern binding (via H6's
explicit Pat enumeration + LFieldLoad generation).

**Lowering additions.** MakeRecordExpr → LMakeRecord.
PRecord → field-by-field LFieldLoad + local bind (during match
arm lowering). Five backend match-site extensions.

**Emission additions.** LMakeRecord mirrors LMakeClosure's emit
shape with EmitMemory swap. PRecord matches load each named field.

---

## Dependencies

- H6: FIRST. infer_pat's `_ => ()` becomes explicit; PRecord
  gets a real arm.
- H3: BEFORE. ADT machinery establishes SchemeKind,
  LMakeVariant signature refinement, and the CallExpr dispatch
  pattern. H2 mirrors this for records without sharing LIR.
- H2 IS A SIBLING OF H3 — they're the two ADT-shape flavors
  (tagged vs untagged).

---

## Post-H3 / H3.1 implications (riffle-back)

This walkthrough was drafted before H3 + H3.1 landed. The substrate
H2 lands ON has shifted; the layered moves above are still right,
but their JUSTIFICATION crystallizes when read against what's in
place. Capturing the riffles before implementation prevents the
wheel of fluent code from spinning the design back into a previous
shape.

### What's now load-bearing in place

- **Heap-uniform allocation pattern.** H3's LMakeVariant uses
  `emit_alloc(size, "variant_tmp")` with field stores at offsets
  4 + 4*i. LMakeClosure (Phase A) uses the same shape with offset
  8 + 4*i. LMakeRecord becomes the third instance — same dispatch,
  offsets at 0 + 4*i. **Three call sites, one emit_alloc swap
  surface**. The EmitMemory handler routes bytes for all three;
  arena / GC swaps land at one site.

- **LMatch cascade with field binding.** H3's emit_match_arms +
  emit_pat_field_binds is the template. LPRecord becomes a new
  always-match arm that calls a record-field-bind variant
  (offsets are field-positional, no tag check). The cascade
  structure is unchanged.

- **W6 LFieldLoad already wired.** `p.name` already lowers and
  emits — the missing piece was the construction site. H2 closes
  the loop the prior W6 work opened. **`p.name` is dead code today
  in the sense that nothing has ever produced a `p` for it to read.
  H2 produces the `p`.**

- **SchemeKind dispatch (H3) extends.** lower's CallExpr already
  inspects env-entry SchemeKind. Adding `RecordSchemeKind(fields)`
  for nominal-record names follows the same shape — one new arm in
  the dispatch. Same pattern, no new mechanism.

  *Decision:* this walkthrough's design says **structural-only
  records** (no declaration syntax). RecordSchemeKind would only be
  needed if Mentl adds nominal records (`type Person = {...}`). For
  H2 v1, skip it. If the showcase needs nominal forms, the SchemeKind
  arm lands as a follow-up — H2.3.

### Crystallization: EffName algebra ⇔ field row algebra

H3.1 introduced `name_set_*` operations on List<EffName>: sorted
insert, union, intersect, diff, subset, disjoint, eq, contains.
H2's TRecord/TRecordOpen unification needs the SAME shape over
List<(field_name, ty)> with the field_name as the sort key.

Today there are TWO instances of this algebra:
- `set_*` (runtime/strings.mn) on List<String>
- `name_set_*` (effects.mn) on List<EffName>

H2 makes it THREE — `field_set_*` on List<(String, Ty)> sorted by
String. Three is the minimum sample size where the abstraction
earns its weight. **The natural follow-up after H2 lands is to
factor a generic ordered-set algebra parametric over (element,
key-extractor, key-comparator).** Rosie's Rule of Three: name two
parallel implementations, factor at the third.

For H2 itself: KEEP three parallel implementations (faster to land
without disrupting two prior modules). The factoring is its own
follow-up, post-H5 once Mentl's audit has had a chance to surface
which uses share enough structure.

### Frame consolidation (Ω.5) becomes mechanical

Ω.5 turns `lower_scope`'s parallel arrays
`(locals_names, locals_handles, captures_names, captures_handles)`
into one record. After H2:

```
type LowerFrame = {
  locals: List, local_handles: List, local_order: List,
  captures: List, capture_handles: List, capture_order: List
}

handler lower_scope with frames = [], globals = [] {
  ls_bind_local(name, h) =>
    let frame = list_head(frames)
    let updated = frame with {
      locals: set_insert(frame.locals, name),
      local_handles: frame.local_handles ++ [h],
      local_order: frame.local_order ++ [name]
    }
    resume() with frames = [updated] ++ list_tail(frames)
}
```

The `frame with {field: new}` syntax is the FUNCTIONAL UPDATE form
mentioned in DESIGN. **H2.2 (functional update) becomes the
predicate for Ω.5's clean landing.** Without functional update,
Ω.5 reverts to "rebuild the record from scratch each
mutation" — verbose. With it, Ω.5 is a one-page sweep.

*Decision:* keep H2 v1 as record CONSTRUCTION + access + pattern
(no update). H2.2 (with-update) lands as a follow-up before Ω.5.
The full chain is H2 → H2.2 → Ω.5 — three small commits, each
verified by walking the next one's prerequisite shape.

### Single-variant ADTs are records (Mentl audit gradient)

After H2, Mentl can prove a structural equivalence:
```
type Wrapper = Wrap(Int, String)        // single-variant ADT
                  ↕
type Wrapper = {a: Int, b: String}      // record (with named fields)
```

Both occupy the same slot in the type-system's ABSTRACTION space.
The record version drops the runtime tag (4 bytes per instance) and
gains named field access (`.a` vs `match w { Wrap(a, _) => a }`).

**Implication for H5:** Mentl's catalog gains a new candidate —
"this single-variant ADT could be a record" with a precise refactor
(name → field) and a precise win (4 bytes/instance saved + readable
access). **The substrate makes this Mentl-discoverable BECAUSE H2
lands**. No special audit code needed; the catalog enumerates
shapes that have a structural equivalent.

### Records in handler state (post-cascade enhancement)

Today handler state is multiple `with x = ..., y = ...` slots.
After H2 + H2.2, handler state could be ONE record per handler:

```
handler counter with state = {count: 0, max: 100} {
  tick() =>
    let s = state
    if s.count < s.max {
      resume()
        with state = state with {count: s.count + 1}
    } else { resume() }
}
```

Cleaner than parallel state slots. **Not in H2's scope** — but the
SUBSTRATE for it lands here. Worth surfacing because once Mentl's
audit notices "this handler has 3+ state slots" it can suggest
record consolidation. The Ω.5 lower_scope refactor is the canonical
example.

### Records as the Mentl AuditReport substrate (H5)

H5 needs an `AuditReport` shape — a record of `{score: Int,
evidence: List, candidates: List, summary: String}`. After H2, this
is a literal record. Mentl's editor surfaces (Proof Lens, Gradient
ghost text) introspect the report by FIELD NAME — `report.score`,
`report.candidates`. **Without H2, AuditReport would be a tuple or
parallel arrays. After H2, it's a record — the editor's
field-by-field projection becomes natural.**

### Recap: what each prior handle gave H2

| From | What H2 inherits |
|---|---|
| W6 (Phase E) | LFieldLoad + offset resolution — no change needed |
| H3 | LMakeVariant heap-alloc template; emit_match cascade + LP* dispatch shape; SchemeKind extension pattern |
| H3.1 | Row algebra over a structured-key list — third instance follows the second's shape |
| H6 | infer_pat exhaustive enumeration; PRecord arm gets a real implementation, not a wildcard absorb |
| Phase A | EmitMemory swap surface; field-canonicalize sort invariant |

H2 is not new mechanism — it's the **third heap-allocated
fixed-layout shape** the substrate already supports. The work is
in proving the symmetry holds and in the ~80 lines of glue that
make the symmetry visible.

---

## Estimated scope

- ~5 files touched: types.mn (MakeRecordExpr variant), parser.mn
  (type/expr/pattern parse arms + disambiguation), infer.mn
  (MakeRecordExpr + PRecord arms + TRecord/TRecordOpen
  unification), lower.mn (MakeRecordExpr lowering + PRecord
  match lowering), backends/wasm.mn (LMakeRecord emission +
  5 match sites).
- **One integrated commit** during cascade.
- **Sub-handles possible:** H2.1 (row-polymorphic record
  unification, if it's big), H2.2 (functional update `with`).
  Named; landed with H2 if trivial, broken out if large.
