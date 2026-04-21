# 07 — Ownership: Consume as an effect, linearity via handler

**Purpose.** An effect-based ownership model. `own` parameters perform
`Consume` on use; a handler (`affine_ledger`) enforces affine
linearity. `!Consume` proves read-only. `!Alloc` proves no
allocation. All derived from the Boolean effect algebra (spec 01) —
no separate ownership analysis.

**Kernel primitive implemented:** #5 — Ownership as an effect
(DESIGN.md §0.5). Load-bearing because removing it collapses
Inka's ability to prove real-time safety without lifetime
annotation ceremony. The `!Mutate` region-freeze and Tofte-Talpin
region inference both ride the same Boolean algebra — no new
analysis pass, no new ADT family. Mentl tentacle served: **Trace**
(ownership violations diagnose + proven-fix surface).

**Research anchors.**
- DESIGN.md (`own` affine / `ref` scoped as annotation ladder).
- Perceus / FBIP (PLDI'21, PLDI'24) — precise RC + in-place reuse.
- Vale — immutable region borrowing via `!Mutate`.
- Polonius 2026 alpha — location-sensitive reachability; pattern for
  ref-escape checking.

---

## The Consume effect

```lux
effect Consume {
  consume(name: String, span: Span) -> ()        @resume=OneShot
  // Branching ops (W2) — `><` and `<|` run their branches under the
  // same outer scope; these ops carve a scope into parallel
  // sub-frames so cross-branch consumes can be pairwise-checked.
  branch_enter() -> ()                           @resume=OneShot
  branch_divider(span: Span) -> ()               @resume=OneShot
  branch_exit(span: Span) -> ()                  @resume=OneShot
}
```

Every `own`-annotated parameter's use performs
`perform consume(name, node.span)`. Inference's walk carries the
node; the span flows as op payload — no `current_span` handler state,
no separate dynamic-scope effect. The handler records the event in
a per-fn linearity ledger and retains the span for diagnostic
emission.

**Branching protocol.** For `a >< b` and `a <| (b, c, …)`,
inference brackets sub-branch inference with `branch_enter` /
`branch_divider` / `branch_exit`. The handler snapshots `used` at
`branch_enter`, captures each branch's delta at `branch_divider` (and
resets `used` to the snapshot so the next branch sees the original
scope), and at `branch_exit` pairwise-checks deltas — any name in
two branches' intersection emits E_OwnershipViolation at the branching
verb's span. The stack shape supports nested branching naturally.

---

## Default handler: affine_ledger

```lux
handler affine_ledger with !Consume {
  consume(name, span) => {
    if list_contains(self.used, name) {
      let first_span = find_first_use(self.used_sites, name)
      perform report(self.source, "E_OwnershipViolation", "OwnershipError",
        "'" ++ name ++ "' consumed twice (first at "
          ++ show_span(first_span) ++ ")",
        span, "MachineApplicable")
      resume(())
    } else {
      resume((), {
        used: push(self.used, name),
        used_sites: push(self.used_sites, (name, span)),
        source: self.source
      })
    }
  }
}
```

State: `{ used: List[String], used_sites: List[(String, Span)],
source: String }`. Span flows as op payload (dynamic); `source` is
closure-captured at handler install (static per compilation). The
`with !Consume` on the handler means `consume` cannot recurse through
its own arm — Boolean effect algebra (spec 01) gates it.

Installed at every FnStmt entry. At FnStmt exit, any `own` parameter
NOT in `self.used` emits `T_Gradient` with code `OwnNeverConsumed` —
a teaching hint, not an error.

---

## `ref` as structural escape check

`ref` parameters cannot appear in return position. Structural walk
over Node/Span:

```lux
fn check_ref_escape(body, ref_params) =
  if len(ref_params) == 0 { [] }
  else { check_return_pos(body, ref_params) }

fn check_return_pos(node, ref_params) = match node.body {
  NExpr(VarRef(name)) =>
    if is_ref_param(name, ref_params) {
      [RefEscaped(name, node.span)]
    } else { [] },
  NExpr(BlockExpr(_, final_expr)) =>
    check_return_pos(final_expr, ref_params),
  NExpr(IfExpr(_, t, e)) =>
    check_return_pos(t, ref_params) ++ check_return_pos(e, ref_params),
  NExpr(MatchExpr(_, arms)) => check_return_arms(arms, ref_params),
  _ => []
}
```

Violations emit `perform report(..., code="E_OwnershipViolation",
kind="OwnershipError", applicability="MaybeIncorrect", ...)`. The
fix might be to change `ref` to `own`, or to refactor to not return
the borrow — hence MaybeIncorrect rather than MachineApplicable.

---

## `!Alloc` as row subtraction

`!Alloc` is not a separate analysis — it's a row claim: "fn body has
effects E where `Alloc ∉ names_of(E)`". Row subtraction from spec 01
discharges it.

When a function is declared `with !Alloc`:
1. Inference walks the body, accumulating its row.
2. Normalized body row is tested against `!Alloc` via subsumption
   (spec 01).
3. Any `Alloc` effect in the body without a handler that absorbs it
   emits `E_OwnershipViolation` with `applicability=MachineApplicable` (the fix is
   deterministic: add a handler, or promote to caller, or drop the
   claim).

---

## `!Consume` — read-only proof

`fn f(x: ref Int) with !Consume -> Int` asserts `f` consumes no
binding. The inferred body row has no `Consume` effect name. This is
weaker than `!Alloc` but useful to combine with scoped arenas (Arc
F.4): `!Alloc + !Consume` = zero-copy AND zero-alloc.

---

## `own` × `ref` matrix

| Param     | On use                 | Return as-is     | Return stored    | Escape check        |
|-----------|------------------------|------------------|------------------|---------------------|
| `own`     | `perform consume(n)`   | OK (moves out)   | OK (new owner)   | N/A                 |
| `ref`     | read                   | ERROR (`E_OwnershipViolation`)     | ERROR (`E_OwnershipViolation`)     | structural walk     |
| Inferred  | compiler decides       | depends          | depends          | default: no-escape  |

---

## Multi-shot × arena (sketch; full in Arc F.4)

A multi-shot continuation captured inside a scoped-arena handler
raises the D.1 question: what happens when the continuation is
resumed after the arena has been reset? Three policies documented
here; implementation lands in Arc F.4:

1. **Replay safe.** Continuation is re-derived by replaying the
   effect trace. Resume re-executes from the perform site. Valid only
   if body effects satisfy Affect's safe shape.

2. **Fork deny.** Forking a continuation that captured arena memory
   is an error at capture time (not resume time). Emits
   `T_ContinuationEscapes`.

3. **Fork copy.** Capture deep-copies arena-owned data into the
   caller's arena. Allocation cost; no semantic surprise.

The type of a multi-shot continuation captured in a `temp_arena`
handler is `TCont(ret, MultiShot)` (spec 02). Arc F.4 adds a
refinement tag `@via_arena=ArenaId` that makes the capture visible to
the Fork deny/copy logic.

---

## Interaction with SubstGraph

The graph tracks type + row variables; it does NOT track ownership.
Ownership is a static structural property of the Ty ADT
(`TParam(_, _, Own|Ref|Inferred)`) plus the effect-based Consume
tracking.

**Inference only.** Once a function's body is inferred, its TParam
Ownership markers are fixed in the graph via the TFun handle.
Subsequent passes observe ownership by chasing `lookup_ty(fn_handle)`
and inspecting the resulting TFun's params.

---

## Violation ADT

```lux
type OwnershipViolation
  = ConsumedTwice(String, Span, Span)
  | RefEscaped(String, Span)
  | OwnNeverConsumed(String)
```

Used as payload for `Diagnostic.report`. Not accumulated in a sidecar
collection — violations flow through the `Diagnostic` effect directly.

## No separate ownership pass

There is no standalone `check_ownership(params, body)` entry point.
Consume tracking lives in the `affine_ledger` handler's state; escape
checks run as part of inference's one walk (spec 04). Used-tracking,
violation emission, and teaching-hint surfacing all compose through
the effect system rather than a dedicated pass that returns
`(used, violations)` pairs.

---

## Consumed by

- `04-inference.md` — infers ownership alongside types in one walk.
- `05-lower.md` — reads TParam ownership to choose move vs copy at
  codegen.
- `06-effects-surface.md` — Consume is registered; `E_OwnershipViolation`
  is the emit code.
- `08-query.md` — `ownership of NAME` walks TFun params.

---

## Rejected alternatives

- **Fractional permissions / Chalice.** Contracts, not inference.
  Wrong direction for Inka's gradient philosophy.
- **Vale-style generational references (runtime tag).** Defeats the
  real-time goal. The static path via `!Mutate` subsumption covers
  the useful cases.
- **Rust-style lifetime annotations in the surface.** Contradicts
  "code the compiler would write for itself." Inference fills the
  gaps; the user annotates only at capability boundaries.
- **Two-pass ownership.** v1 ran ownership after typing as a separate
  walk. One walk wins — inference already visits every binding; it
  can record Consume performs cheaply.
