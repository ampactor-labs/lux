# Handle 4 — Region Escape (Full Wiring)

*Role-play as Mentl, tracing a value allocated inside an arena
scope and returned past the scope's boundary. Names what fires
at each site, what the region_tracker handler's tagged_values
state contains, and where the check_escape diagnostic surfaces
with coordinate-aware reporting.*

---

## The scenario

```
fn get_buf() -> Ptr = {
  handle {
    let buf = alloc(100)
    buf
  } with arena_mem
}

fn safe_usage() = {
  handle {
    let buf = alloc(100)
    use_and_discard(buf)
  } with arena_mem
}
```

`get_buf` is a LEAK: it returns `buf` past the arena scope. The
arena reclaims on scope exit, leaving the returned pointer
dangling. **H4's job: this compiles to E_OwnershipViolation with
region-trace at the return site.**

`safe_usage` is correct: `buf`'s use ends inside the scope. No
escape. Should compile cleanly.

---

## Layer 0 — what counts as a region

**Every HandleExpr on the Alloc effect creates a region.** This
is the structural, Inka-native answer. No naming convention; no
attribute markup. A handler that handles Alloc → its scope is a
memory region → its bounds delimit value lifetime.

Today's handlers on Alloc include `emit_memory_bump` and
`emit_memory_arena` — but those are EMIT-TIME handlers; the
runtime user-facing handler shapes aren't yet named. For H4
we care about RUNTIME Alloc handlers — user code writes
`handle { ... } with arena_mem` where arena_mem is a user-
declared handler implementing `alloc(size) => ...`.

Inference detects this structurally: at each HandleExpr, examine
the handler's arms. If any arm's op is named `alloc`, it's an
Alloc handler. Treat its scope as a region.

**Non-scoped Alloc handlers** (e.g., a top-level GC) would be
installed at the program boundary — the outermost scope.
Their "region" is program-lifetime. Values tagged with this
region never escape anything meaningful. This case degrades
gracefully; check_escape of a program-lifetime region is always
safe.

---

## Layer 1 — Inference: when does each op fire?

### region_enter

At every HandleExpr whose arms include `alloc`:

```
NExpr(HandleExpr(body, arms)) => {
  ...
  let alloc_handled = list_contains_op(arms, "alloc")
  let region_id =
    if alloc_handled { perform region_enter(span) } else { 0 }
  ...
  infer_expr(body)
  ...
  if alloc_handled { perform region_exit(region_id) }
  ...
}
```

region_enter returns a fresh region_id; the HandleExpr's
inference holds it through the body walk. At scope exit,
region_exit pops.

**region_id is per-scope.** Every HandleExpr on Alloc gets its
own. Nested scopes produce nested regions; the stack structure
in region_tracker's state captures the nesting.

### tag_alloc

At every value-constructing expression whose effect row
includes Alloc:

- `LMakeClosure` site (lambda values)
- `LMakeList` / `MakeListExpr`
- `LMakeTuple` / `MakeTupleExpr`
- `LMakeRecord` / `MakeRecordExpr` (H2)
- `LMakeVariant` / CallExpr→constructor (H3)
- Explicit `perform alloc(n)` return handle

At each such site, inference performs `tag_alloc(handle)` where
handle is the expression's AST handle. region_tracker's state
records (handle, current_region_id).

**Subtle:** inference has to know "which region am I in right
now?" at arbitrary points in the walk. This requires a
current_region accessor on region_tracker:

```
effect RegionTrack {
  region_enter(Span) -> Int                        @resume=OneShot
  region_exit(Int) -> ()                           @resume=OneShot
  tag_alloc(Int) -> ()                             @resume=OneShot
  check_escape(Int, Span) -> ()                    @resume=OneShot
  current_region() -> Int                          @resume=OneShot
}
```

`current_region()` reads the top of region_stack (or 0 if none).
When tag_alloc fires, it uses current_region internally.
Actually — tag_alloc DOES this implicitly. It stamps "the
current top" onto the given handle. No extra op needed.

### check_escape

At every expression that propagates a value to an OUTER scope:

1. **Function return**: the FnStmt's body value escapes to
   callers. check_escape at the body's handle.
2. **Let-binding that outlives its RHS's scope**: if RHS is
   inside a region scope and LHS is bound in an outer scope, the
   value escapes.
3. **If-branch / match-arm results**: if a conditional's arm
   returns a value from a narrower region, the conditional's
   result escapes that region.
4. **Tuple/record/list construction**: the container lives in
   the outer region; its elements' regions must outlive or equal
   the container's.

For H4's first landing, focus on case 1 (function return) —
the most common and most diagnosable. Cases 2-4 are structural
extensions that follow the same pattern; add incrementally.

### The check_escape logic

`check_escape(value_handle, site_span)`:

1. Look up value_handle in tagged_values. If not tagged →
   program-lifetime / statically-allocated. SAFE. Return.
2. value's region_id is found. Check region_stack: is region_id
   still on the stack?
3. If YES → the region is still alive in the current scope.
   SAFE. Return.
4. If NO → region was popped; the value's backing memory is
   gone. **E_OwnershipViolation.** Emit:

```
'<value expression>' escapes region installed at <region's span>
(region ended before this return site)
```

---

## Layer 2 — Tracking tagged values

### The state

region_tracker's state:

```
handler region_tracker with
  region_stack = [],         // [(region_id, install_span)]
  next_region  = 1,          // next fresh id (0 = program lifetime)
  tagged_values = []         // [(value_handle, region_id)]
{ ... }
```

- region_stack grows/shrinks on enter/exit. Sorted by
  insertion order (stack semantics, not the sort-invariant
  we use elsewhere).
- next_region monotonically increments.
- tagged_values grows append-only. Lookups by value_handle are
  O(len) today; could become a sorted set if profiling shows
  it matters.

### The arms

```
region_enter(span) => {
  let rid = next_region
  resume(rid)
    with region_stack = [(rid, span)] ++ region_stack,
         next_region = next_region + 1
},

region_exit(rid) => {
  // pop the TOP region; validate it matches rid (sanity check)
  if len(region_stack) == 0 {
    resume()   // stack underflow — should not happen
  } else {
    let (top_rid, _) = list_head(region_stack)
    if top_rid == rid {
      resume() with region_stack = list_tail(region_stack)
    } else {
      // mismatched exit — region sequencing bug; report
      perform report("", "E_RegionSequencingBug", ...)
      resume()
    }
  }
},

tag_alloc(handle) => {
  if len(region_stack) == 0 {
    resume()   // no active region — value is program-lifetime
  } else {
    let (rid, _) = list_head(region_stack)
    resume()
      with tagged_values = [(handle, rid)] ++ tagged_values
  }
},

check_escape(handle, span) => {
  let tagged = find_tagged(tagged_values, handle)
  match tagged {
    None => resume()    // untagged = program-lifetime, SAFE
    Some(rid) => {
      if region_still_alive(region_stack, rid) {
        resume()   // SAFE
      } else {
        let install_span = find_region_install(region_stack, rid)
        // find_region_install: since region is popped, we need
        // to cache install_spans elsewhere. Add another state
        // field OR include install_span in tagged_values entry.
        perform report("", "E_OwnershipViolation", "OwnershipViolation",
          "value escapes region installed at "
            |> str_concat(show_span(install_span)),
          span, "MachineApplicable")
        resume()
      }
    }
  }
}
```

### Install-span retention

When a region is EXITED, we still need its install_span for
future check_escape diagnostics. Options:

**Option 1.** Tag the value with the region's install_span
directly: `tagged_values = [(handle, rid, install_span)]`. At
tag_alloc, copy the install_span from the top region_stack
entry. check_escape reads it directly. No separate lookup.

**Option 2.** Retain a `dead_regions = [(rid, install_span)]`
list. At region_exit, move the popped entry here. At
check_escape, look up rid in region_stack first, then
dead_regions. Two-lookup.

**Mentl's choice: Option 1.** Tag the value with its region's
install-span at the moment of tag_alloc. Zero additional state.
No two-lookup. Slightly more storage per tagged value but
exhibits the same "handler IS state" pattern — the tag carries
enough context to diagnose itself.

---

## Layer 3 — FnStmt's return check

At each FnStmt's exit (existing code at infer.nx ~line 210):

```
// After body inference, before declared-effects check:
let N(_, _, body_handle) = body_node
perform check_escape(body_handle, span)
```

body_handle is the value returned by the function. `span` is
the fn's declaration span (for the diagnostic's "site" field).
If body_handle is tagged with a region that's been popped by
the time we get here, the escape is reported.

**For `if` / `match` / `block` return values**: each branch's
result handle is checked against the region at the branch's
resolution point. The existing CONTROL-FLOW awareness (branch_enter /
branch_divider / branch_exit from C1) parallels this — region
checks can follow the same pattern.

For H4's first landing: FnStmt-level check is sufficient to
catch the common case (get_buf style leaks). Branch/let-level
escape checks are analogous refinements that can follow
incrementally.

---

## Layer 4 — Backend (today: no impact)

Region tracking is entirely INFERENCE-level. No backend changes
for H4.

The runtime arena's ACTUAL memory reclamation (resetting
$arena_ptr on scope exit) is a separate feature — it's already
in place per Phase E's emit_memory_arena handler. H4 adds the
STATIC check that values can't outlive their regions; the
runtime arena is what enforces reclamation. The two are
complementary.

---

## Layer 5 — what closes when H4 lands

- `get_buf` fails to compile: E_OwnershipViolation at the return
  site naming the arena's install span.
- `safe_usage` compiles cleanly (no escape).
- Every alloc-site in every source file carries its region tag.
- The region_tracker handler has live consumers — its stubs from
  Phase E are replaced with real arms.
- Inka gains static region-escape analysis without nominal
  region annotations. Structural, handler-mediated, inference-
  time.

---

## What H4 reveals (expected surprise)

### Revelation A — tag_alloc fires at many sites

Every value-constructing expression is an alloc site. That's
LMakeClosure, LMakeList, LMakeTuple, LMakeRecord (H2),
LMakeVariant (H3), and direct `perform alloc(n)`. At inference
time, each of these has a node that produces a handle. The
tag_alloc perform is inserted at every such site. This is
substantial but mechanical — a sweep across infer.nx.

### Revelation B — branch structure mirrors C1's branching ledger

Region tracking inside `><` and `<|` parallels the branching
affine ledger (H C1). The branching verbs create sub-scopes that
may each allocate. Region tracking through branches needs
analogous enter/divider/exit discipline. **Possible sub-handle
H4.1: region-branch support.** Deferred from H4's first landing
if too large; named for the cascade.

### Revelation C — closure captures and region lifetime

A closure captures a value. The captured value's region must
outlive the closure's lifetime. If a lambda captures a
region-tagged value AND the lambda value escapes its region
scope, the capture escapes too. This is transitive and more
complex than the FnStmt-return case. Consider scope for a
second-pass H4 landing.

### Revelation D — the Alloc effect's name

Today "alloc" is the conventional op name. H4 dispatches on the
STRING "alloc" to detect Alloc handlers. This works today but
couples naming to semantics. A future refinement: an explicit
`@region` attribute on effects or handlers. For H4 landing,
stick with naming convention; flag the refinement as a
post-six discussion item.

### Revelation E — interaction with H3 / H1

H3 introduces ConstructorScheme — constructor calls become
LMakeVariant, which IS an alloc site. H3's lowering adds new
tag_alloc sites. Similarly H2's records. Order in the cascade:
H2, H3 before H4 → H4's tag_alloc insertion sweep covers the
new construction sites naturally.

H1's transient evidence records are ALLOC SITES. They're arena-
scoped by design (Phase E). H1 + H4 are consistent: transient
evidence records are tagged with the arena region; they can't
escape the handler scope (and naturally don't — they're only
used during the call).

---

## Design synthesis (for approval)

**Region = every HandleExpr on Alloc.** Structural detection by
scanning arms for `alloc` op. Nested handlers produce nested
regions.

**Tag at alloc sites.** tag_alloc fires at every
value-constructing expression (LMakeClosure, LMakeList,
LMakeTuple, LMakeRecord, LMakeVariant, `perform alloc`). The
tag stores (handle, region_id, install_span) — install_span
carried on the tag for future diagnostic.

**Check at escape sites.** For H4's first landing: FnStmt-level
check_escape on body_handle. Branch-level / let-level checks
follow incrementally (sub-handles).

**RegionTrack effect gains current_region() / cleanup logic.**
region_tracker's state tracks region_stack + tagged_values.
Install_span carried on tags avoids dead_regions cache.

**No backend changes.** Region tracking is inference-level;
runtime arena reclamation is separate (already in place
Phase E).

---

## Dependencies

- H6 FIRST (wildcard audit — ensures check_escape's match over
  return-expression NodeBody is explicit).
- H3 BEFORE (alloc sites from constructor calls).
- H2 BEFORE (alloc sites from record construction).
- H1 BEFORE (evidence record alloc sites; tag_alloc on them
  naturally).
- H4 consumes all three's new alloc sites.

---

## Estimated scope

- ~4 files touched: types.nx (effect extension — current_region
  if we choose that route), own.nx (region_tracker real arms +
  helpers), infer.nx (tag_alloc insertion sweep, check_escape
  at FnStmt exit, current_region lookups at construction sites),
  docs/errors/ (E_RegionSequencingBug if we surface that),
  possibly pipeline.nx (region_tracker install).
- **One commit** with the sweep.
- **Sub-handles:** H4.1 branch-level region checks (if not
  included), H4.2 closure capture region propagation (if not
  included). Named; landed if trivial.

---

## Post-H3 / H3.1 / H2 / Ω.5 implications (riffle-back)

H4 was drafted with awareness of H2/H3 alloc sites but not their
runtime semantics. The substrate has shifted; H4's escape-tracking
needs sharpening at three points.

### Field-store as escape vector (H2)

A pointer captured in scope α can ESCAPE by being stored into a
record field that outlives α. Today H4 names construction sites as
"alloc points to track" — but the record's field-store at
construction time is precisely the escape EDGE.

Concrete: `let r = {child: alloc_inner_ptr}` where `alloc_inner_ptr`
came from a tighter scope. The record `r` outlives that scope
(returned, stored elsewhere, captured by a longer-lived closure).
Region escape: the field load reaches `alloc_inner_ptr` after its
arena reclaimed; classic dangling read.

H4 needs to detect: when LMakeRecord (or LMakeVariant with fields)
captures pointers from inner-region values, the record's region
inherits the WIDEST inner region. A record's region is the JOIN
(outer-most/longest-lived) of (its allocation site, every pointer
field's source region). If any field outlives the record's
allocation site, escape: E_RegionEscape.

This is a NEW invariant H4 needs to track: **per-handle region is
NOT just the alloc site's region; it's the join of the alloc and
any embedded pointer's region.** Implementation: when tag_alloc
fires for an LMakeRecord/LMakeVariant with pointer-typed fields,
walk each field's handle, look up its tagged region, take the max
(outermost = longest-lived).

### Parameterized effects share regions (H3.1)

`with Sample(44100)` and `with Sample(48000)` are distinct row
entries but their HANDLER ARMS are still arms of the `Sample`
effect. If both install handlers that call `alloc`, do their
regions interact?

Decision: **regions are per-handler-INSTALLATION, not per-effect**.
Two `handle ... with Sample(44100)` scopes nested produce two
separate regions, each their own arena. Two scopes side-by-side
(sequential) produce two separate regions that don't overlap in
time. Parameterization doesn't change region identity — the
HandleExpr scope does.

This is what the walkthrough already implies; making it explicit
prevents a future drift where someone treats `Sample(44100) ==
Sample(48000)` as same-region.

### Variant-tag's region (H3)

LMakeVariant stores tag at offset 0 + fields at offsets 4+4i. The
TAG isn't a pointer (it's a literal int) — no region tracking.
Fields ARE pointers (i32-erased) — same record-field rule as above.

Nullary variants (post-Bool transition) become sentinel values, no
allocation. Sentinels have no region — they're values, not heap
addresses. The escape rule trivially holds: sentinels can flow
anywhere.

### Frame records (Ω.5) are scope-local

infer_ctx and lower_scope's frame records are records in the
inference's HOST language (the compiler), not user-program records
needing escape tracking. They don't reach H4's check_escape sweep
because they're never passed back through user code. Note:
diagnostic-only.

### What H4 inherits

- LMakeRecord / LMakeVariant in lower (H2 / H3) — alloc sites
  ready to receive tag_alloc.
- emit_alloc swap surface (Phase A + H3 + H2) — region-aware
  EmitMemory variant lands without changing call sites.
- Frame-record discipline (Ω.5) — region_tracker's state IS a
  record literal with named fields.
- EffectOpScheme dispatch (H3) — `perform alloc(N)` already routes
  to LPerform; H4 reads the call's row to confirm Alloc and tags
  the resulting handle.

### Updated estimated scope

- Add a **region-join helper** to the tag_alloc path: for
  LMakeRecord/LMakeVariant, compute the field-pointer-regions join
  and tag the constructing handle with the outermost region.
- One additional helper file (or in-place in own.nx): ~30 lines.
- The escape-check at FnStmt exit gains a "field-walk" pass for
  records — recursive but bounded by record depth (~5 lines deeper).

H4 still single-commit. H4.1 (branch-level) and H4.2 (closure
captures across scopes) remain as named sub-handles if scope grows.
