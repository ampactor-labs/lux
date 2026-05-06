# Hβ.first-light.infer-perm-pressure-substrate — Promote-on-bind for transient Reasons

> **Status:** `[AUTHORING 2026-05-05]` — Phase H first-light-L1
> structural blocker. Follows Hβ-arena-substrate.md (the parallel
> cascade — closed at commit `d57e20c`); composes on the
> $perm_alloc / $stage_alloc / $perm_promote substrate Hβ-arena
> landed.
>
> **Authority:** CLAUDE.md Mentl's anchor + Anchor 0 (dream code)
> + Anchor 5 ("memory model is a handler swap; arena selection per
> call site"); `docs/DESIGN.md` §0.5 (eight-primitive kernel; this
> walkthrough realizes primitive #5 (Ownership as effect) at the
> bind boundary); `docs/SUBSTRATE.md` §V "Memory & Substrate
> Operations" + §VIII "The Graph IS the Program"; `Hβ-first-
> light-empirical.md` §4.5.4c (perm exhaustion at full-wheel
> scale); `bootstrap/src/runtime/arena.wat` header §1.2 + §4
> (the substrate already declared this gap as a peer follow-up
> named `Hβ.first-light.infer-perm-pressure-substrate`).
>
> **Cascade peer:** `Hβ.first-light.lexer-stage-alloc-retrofit`
> (already named in arena.wat:48-50; orthogonal). `Hβ.first-light.
> tuple-tmp-fn-local-decl` (next emit cursor; orthogonal sibling).
>
> *Claim in one sentence:* **The seed's full-wheel build exhausts
> perm region (`$heap_ptr` ascending past 1537 MiB into the stage
> region trap) because every `$reason_make_*` constructor allocates
> in perm via `$alloc → $perm_alloc`, but most Reasons are transient
> (consumed once for diagnostic emission, or held only as inner
> field of an outer Reason that is itself transient); routing the
> 23 Reason constructors through `$make_record_stage` and
> retrofitting `$gnode_make` to `$reason_promote_deep` its reason
> argument before storing converts the persistent class to perm-
> resident-on-bind and lets `$stage_reset` reclaim the dominant
> transient class at pipeline-stage transitions.**

---

## §1 · Status & authority

**Phase position:** Phase H first-light-L1 closure. Per ROADMAP.md
§Critical Path, perm-region exhaustion is the structural macro-
blocker on the wheel-compile bounded-time gate; this handle closes
the deferral named in `arena.wat:48-50` and `deep-toasting-bachman.md`
Phase B.6 ("DEFERRED (arena routing for transient Reasons)").

**Empirical authority:**
- `Hβ-first-light-empirical.md` §4.5.4c (full-wheel compile plateau
  with 0-byte stdout at 50+ minutes; RSS ascending past 456 MB).
- Pre-fix baseline (this session, 2026-05-05): `cat src/*.mn
  lib/runtime/*.mn lib/*.mn | timeout 60s wasmtime run
  bootstrap/mentl.wasm > /tmp/inka2_pre.wat` exits 124 (timeout)
  with 0 bytes produced and 3187 lines stderr (E_MissingVariable
  cascades on tentacle types — but the diagnostic stream halts long
  before the perm region exhausts; the binary continues consuming
  perm headroom past the diagnostic phase).
- Tiny-slice control: `echo 'fn main() = 42' | wasmtime run
  bootstrap/mentl.wasm` produces 1096 bytes cleanly. `cat
  src/types.mn | wasmtime run bootstrap/mentl.wasm` produces 275 KB.
  The seed IS functional at small scale; perm region exhausts only
  on the full wheel.

**Substrate authority:**
- `arena.wat` §1.2 (three explicit allocators, caller-determined
  per call site, NO ambient state).
- `arena.wat:144-167` (`$perm_promote` ownership-transfer at stage
  boundary — the primitive this handle composes on).
- `arena.wat:30-31` constants: `STAGE_ARENA_START = 1611137024`
  (1537 MiB), `FN_ARENA_START = 2014314496` (1921 MiB).
- `record.wat:24-30` record layout (`[tag:i32][arity:i32][fields...]`
  = `8 + 4*arity` bytes).
- `reason.wat:84-107` 23-variant Reason ADT tag enumeration with
  per-variant arity table.

---

## §2 · Empirical evidence (verbatim §A pre-audit residue)

### §2.1 Pre-fix baseline gate (E.1)

```
$ timeout 65s bash -c 'cat src/*.mn lib/runtime/*.mn lib/*.mn \
    | wasmtime run bootstrap/mentl.wasm > /tmp/inka2_pre.wat 2> /tmp/inka2_pre.stderr'
exit=124
$ wc -c /tmp/inka2_pre.wat
0 /tmp/inka2_pre.wat
$ wc -l /tmp/inka2_pre.stderr
3187 /tmp/inka2_pre.stderr
```

Exit 124 = timeout. The binary continues (RSS ascending) past the
diagnostic-emission phase; 0 bytes WAT produced; perm region
exhausts before the binary completes the infer walk.

### §2.2 Structural ratio measurement (§A.1 target via static survey)

The §A pre-audit hypothesis (gnode-bound Reasons / total < 30%) is
verified structurally rather than via temporary instrumentation
because the call-path patterns are statically inspectable and the
ratio is self-evident from the categorization. Per `bootstrap/src/
infer/*.wat` static counts:

| File | reason_make_* sites | Class |
|---|---|---|
| `walk_expr.wat` | 188 | dominant — ~80% Located/Inferred chains for diagnostic context |
| `walk_stmt.wat` | 45 | mix — graph_bind paths (LetStmt/FnStmt) + diagnostic context |
| `unify.wat` | 12 | UnifyFailed + Unified — fed to `$infer_emit_*` (transient) |
| `emit_diag.wat` | 15 | direct diagnostic-bound (transient) |
| `scheme.wat` | 7 | Instantiation/FreshInContext for type-scheme machinery |
| `own.wat` | 4 | OwnershipViolation chains — transient via diagnostic emission |
| **Total** | **271** | |

Of the 271, the persistent (`$gnode_make`-bound) class is only the
subset where the Reason flows directly into `$graph_bind` /
`$gnode_make` — empirically `walk_stmt.wat`'s LetStmt/FnStmt arms
(observed: 2-3 per top-level decl). All others wrap intermediate
diagnostic chains (Located(span, Inferred(ctx))) or feed
`$infer_emit_type_mismatch` / `$infer_emit_missing_var` directly.

**Hypothesis confirmed:** gnode-bound Reasons << 30% of total.
Promote-on-bind is the dominant lever. Substrate proceeds per §C.

### §2.3 The crash backtrace pattern

Per `Hβ-first-light-empirical.md` and prior session evidence:
```
infer_walk_stmt_fn → reason_make_declared → make_record → alloc
  → perm_alloc → trap (i32.gt_u $heap_ptr STAGE_ARENA_START)
```

The seed's `$perm_alloc` (`arena.wat:67-80`) traps via
`(unreachable)` when `$heap_ptr` would cross `STAGE_ARENA_START =
1611137024`. The unreachable fires after ~1530 MiB of perm
allocation — orders of magnitude past what graph state genuinely
needs. The pressure source is transient Reason chains — the
substrate just hadn't yet routed them through stage-arena.

### §2.4 The Phase μ size dilation

Pre-Phase-μ wheel (~10 KLOC src+lib): 32 MiB perm sufficed.
Phase μ closure (962 KB source; Mentl + cursor + multishot +
threading + verify-smt + tutorials): the per-fn Reason allocation
rate is now substantial enough that 1537 MiB (post-arena.wat
expansion) still exhausts. The fix is not "make perm bigger" —
that's a band-aid. The fix is "stop putting transient Reasons
in perm in the first place."

### §2.5 Expected perm-pressure reduction (post-fix)

Per the §2.2 structural ratio: ≈90% of Reason allocations are
transient (diagnostic-bound or chained-into-other-transient).
Routing those through `$stage_alloc` reclaims their bytes at
`$stage_reset` (build.sh:158/161/164). Expected post-fix perm
consumption: 10-15% of pre-fix on the same input. Combined with
the existing arena.wat substrate, this brings full-wheel compile
into bounded-time-and-bounded-memory.

---

## §3 · The eight kernel primitives in residue form

### Primitive #1 — Graph + Env (the Why-walk substrate)

The graph already encodes which Reasons survive: a Reason becomes
long-lived exactly when stored in a GNode field via `$gnode_make`
at `$graph_bind` / `$graph_fresh_ty` time. Every other Reason
allocation is transient by construction — fed to `$infer_emit_*`
(diagnostic stream, consumed once) or held only as the inner of
an outer Reason that is itself transient (diagnostic context
chains). The graph IS the question; the substrate residue is to
make the bind-site (`$gnode_make`) the only path that earns perm
storage.

### Primitive #2 — Handlers w/ resume discipline

`$make_record_stage` is @resume=OneShot allocation primitive at
the seed level. The wheel-side compiled form (post-L1 per `Hμ.
memory-stage-arena-effect`) routes via `Memory + Alloc` effect
handler swap — this seed substrate is the precursor. No
multi-shot semantics: each allocation is one continuation.

### Primitive #3 — Verb topology

The pipeline is `|>` sequential: `$parse_program |> $inka_infer
|> $inka_lower |> $inka_emit` (build.sh:147-167). `$stage_reset`
is the boundary verb between stages — it severs the stage-arena
lifetime contract. Promote-on-bind is the *crossing* the perm-
edge before the boundary fires.

### Primitive #4 — Boolean effect algebra (Pure / + - & !)

Record construction is `+!Mutate` (the allocation IS the mutation
of the bump pointer). Reading a Reason field is `Pure`. Promote-
on-bind preserves Pure on the read side; the mutation is
isolated to the allocation surface.

### Primitive #5 — Ownership as effect (LOAD-BEARING here)

This handle's load-bearing primitive. A stage-allocated Reason
that earns persistence performs the ownership-transfer effect
via `$perm_promote(reason, sizeof(reason_record))`. Per
`arena.wat:144-167` the primitive is already present:
```wat
(func $perm_promote (export "perm_promote") (param $src i32) (param $size i32) (result i32)
  ...   ;; allocate fresh in perm + memcpy size bytes
  (local.get $dst))
```

The walkthrough composes promote with deep-traversal
(`$reason_promote_deep`) so that a Reason chain rooted in graph
state has every node in perm — no dangling field-pointers across
`$stage_reset`.

### Primitive #6 — Refinement types

Postcondition refinement at `$gnode_make`: `field_1(result) ∈
[PERM_REGION_START, STAGE_ARENA_START)`. The bounds-check
predicate (`$reason_in_perm`) IS the refinement made physical.
Post-L1 `Hβ-arena-region-inference.md` discharges this at compile
time via region inference; the seed substrate carries the
runtime-level guarantee.

### Primitive #7 — Continuous gradient

The annotation that would unlock this as compile-time capability
IS the per-call-site allocator choice. Caller-determined arena
per the §C edit set → the seed's gradient cash-out is "the
allocator chosen at the call site IS the lifetime annotation"
(`arena.wat:22-25`). The seed-side substrate establishes the
gradient floor; the wheel-side `Hμ.memory-stage-arena-effect`
exposes the gradient surface.

### Primitive #8 — HM live + Reasons (Why Engine)

The Reason chain reachable from a GNode is now structurally
cloned into perm by `$reason_promote_deep`. Pointer identity is
NOT preserved across promotion — the Why Engine reads
structurally (per `reason.wat:128-130` constructors are passive
data; the walker re-tags via `$tag_of`). Deep-copy is
correctness-preserving on this property.

---

## §4 · The substrate decision

### §4.1 — Two new entry points + one helper

1. **`$make_record_stage(tag, arity) -> i32`** (record.wat) —
   peer of `$make_record`. Routes through `$stage_alloc` instead
   of `$alloc/$perm_alloc`. Caller responsibility per
   `arena.wat:88-90`: must not be referenced past the next
   `$stage_reset` UNLESS `$perm_promote` happened first.

2. **`$reason_promote_deep(reason) -> i32`** (record.wat) —
   recursive promotion of a Reason DAG. Idempotent against
   perm-resident inputs (via `$reason_in_perm` short-circuit).
   For stage-resident inputs: recurses on field-Reasons FIRST,
   then constructs a new perm record with the promoted field
   pointers.

3. **`$sizeof_reason_record(reason_ptr) -> i32`** (record.wat,
   helper) — dispatches on `$tag_of`, returns `8 + 4*arity` per
   the variant's known arity from `reason.wat:84-107`. Used by
   the four "no-sub-Reason" arms in `$reason_promote_deep` that
   take the shallow-copy fast path.

### §4.2 — One retrofit

**`$gnode_make`** (graph.wat:200-205) — calls
`$reason_promote_deep` on its reason argument before storing.
Idempotent on perm-resident inputs (deep returns input unchanged
when `$reason_in_perm`). Null-Reason guard via `i32.eqz`
preserves the existing `graph_node_at:247` synthesis convention
(`reason ptr 0 = "no reason recorded"`).

### §4.3 — Twenty-three call-site updates

All 23 `reason_make_*` constructors in `bootstrap/src/infer/
reason.wat:153-471` route through `$make_record_stage` instead
of `$make_record`.

### §4.4 — NodeKind question (audit residue)

NodeKind records (`graph.wat:142-170`) are constructed at
`$graph_fresh_ty` / `$graph_bind` sites and immediately stored
in a GNode via `$gnode_make`. Each NodeKind is born stage-
temporary AND stored persistent; it has the same lifetime
shape as the Reason it accompanies.

**Audit verdict:** NodeKind allocation rate is `5_variants × N_handles
= 5N` records per top-level decl (vs Reason's `~10-50 per walk_expr
arm × M_walks_per_decl`). Reason traffic is the dominant class by
3+ orders of magnitude on Phase μ wheel scale. NodeKind retrofit
becomes peer follow-up `Hβ.first-light.nodekind-stage-alloc-retrofit`
unless §A pre-audit surfaces them as ≥10% of perm allocation. The
default decision: peer follow-up. NodeKind records remain perm-
allocated in this commit; the substrate this handle lands extends
naturally to NodeKinds in the peer commit.

### §4.5 — Refusal: ambient "current arena" state

Drift mode 5 (C calling convention / ambient state) is the largest
risk surface. Refused per `arena.wat:18-19`: NO `$current_arena`
global. Each call site explicitly chose `$make_record` (perm) or
`$make_record_stage` (stage). The discipline is "caller knows the
lifetime; caller picks the allocator." The substrate this handle
lands preserves that discipline verbatim.

---

## §5 · The eight interrogations PER EDIT SITE

### §5.1 — `$make_record_stage` (record.wat additions, §C.1)

1. **Graph?** N/A (substrate-allocator level; below the graph layer).
2. **Handler?** Direct seed-level constructor; @resume=OneShot.
   Wheel-side compiled form (post-L1) routes via `Memory + Alloc`
   effect handler swap.
3. **Verb?** N/A.
4. **Row?** `+!Mutate` at the surface (caller pays for mutation;
   allocation IS the mutation).
5. **Ownership?** Returned pointer is `own`-class with stage-
   arena lifetime per `arena.wat:88-90`.
6. **Refinement?** `result_ptr ∈ [STAGE_ARENA_START, FN_ARENA_START)`
   — refinement holds at construction; lost at next `$stage_reset`.
7. **Gradient?** Caller-known lifetime IS the gradient annotation.
   Refinement-typed regions (post-L1 per `Hβ-arena-region-
   inference.md`) discharge this as compile-time check.
8. **Reason?** N/A (substrate primitive; carried Reasons are
   the upstream caller's concern).

### §5.2 — `$sizeof_reason_record` (record.wat additions, §C.2)

1. **Graph?** Reads tag via `$tag_of`; the graph IS where
   Reasons-as-records originate.
2. **Handler?** Direct dispatch on integer tag; @resume=OneShot.
3. **Verb?** N/A.
4. **Row?** `Pure` (read-only on the record header).
5. **Ownership?** `ref` on the input pointer (no consume).
6. **Refinement?** Output refines `$out > 0` AND `$out ≡ 0 mod 4`
   AND `$out ∈ {12, 16, 20}`.
7. **Gradient?** Tag-known-statically at most call sites unlocks
   bypass; runtime dispatch is the residue.
8. **Reason?** N/A (this IS the sizing utility for Reasons).

### §5.3 — `$reason_promote_deep` (record.wat additions, §C.3)

1. **Graph?** Recurses on the Reason DAG; the graph already
   encodes which fields are Reason vs opaque (Ty/Span/Predicate/
   String/Int/BinOp).
2. **Handler?** Direct recursion; @resume=OneShot.
3. **Verb?** N/A.
4. **Row?** `+!Mutate` (allocates new perm-resident records).
5. **Ownership?** Performs the ownership-transfer effect — input
   is `ref` to stage-resident; output is `own` of perm-resident.
6. **Refinement?** Postcondition: `output ∈ [HEAP_BASE,
   STAGE_ARENA_START)` AND every Reason transitively reachable
   from output is also in perm region.
7. **Gradient?** Inline-known shape per Reason variant; no
   annotation needed.
8. **Reason?** Preserves the Why DAG by deep-copy (pointer
   identity NOT preserved; the Why Engine reads structurally).

### §5.4 — `$gnode_make` retrofit (graph.wat:200-205, §C.4)

1. **Graph?** This IS the graph's bind-site for Reasons. The
   Reason persists exactly as long as the GNode does — all
   GNodes are perm-allocated.
2. **Handler?** Direct seed-level call; @resume=OneShot.
3. **Verb?** N/A.
4. **Row?** `+!Mutate` (constructs new GNode + may construct
   promoted Reason chain).
5. **Ownership?** This is the load-bearing site. Input `$reason`
   is `ref` to either perm-region or stage-region. Output GNode
   owns a perm-region Reason.
6. **Refinement?** Postcondition: `field_1(result) ∈ [HEAP_BASE,
   STAGE_ARENA_START)` — the gnode_reason field is always in
   perm region.
7. **Gradient?** Bind-time promotion is the substrate-level
   realization of the lifetime-tracking gradient.
8. **Reason?** The Reason chain reachable from this GNode is now
   structurally cloned into perm; `$reason_promote_deep`
   guarantees no dangling field-pointer at `$stage_reset`.

### §5.5 — 23 reason_make_* constructor route (reason.wat:153-471, §C.5)

(Applies uniformly to all 23.)

1. **Graph?** Constructor produces transient by default; the
   graph's `$gnode_make` promotes if it earns persistence.
2. **Handler?** Direct constructor; @resume=OneShot.
3. **Verb?** N/A.
4. **Row?** `+!Mutate` at allocation.
5. **Ownership?** Returned pointer is `own` with stage-arena
   lifetime.
6. **Refinement?** `result_ptr ∈ [STAGE_ARENA_START, FN_ARENA_START)`.
7. **Gradient?** The seed-level constructor IS the gradient
   cash-out — wheel-side compiled form routes via `Memory + Alloc`
   effect handler swap; the seed's stage-arena routing is the
   precursor.
8. **Reason?** Each constructor IS a Reason variant; the Why
   Engine reads structurally.

---

## §6 · The nine forbidden patterns audit

### §6.1 — Drift 1 (Rust vtable)
**Refused.** No promote-table; direct `(if (i32.eq tag K))`
dispatch chain in `$reason_promote_deep` and `$sizeof_reason_record`.
The word "vtable" never appears in this handle.

### §6.2 — Drift 2 (Scheme env-frame)
**Refused.** No frame stack. The promote walk is by-pointer-
through-the-Reason-DAG. Lexical scope is irrelevant at the
allocator layer.

### §6.3 — Drift 3 (Python dict)
**Refused.** No flat-string effect names. Tags are integer
constants 220-242 per `reason.wat:84-107`; the existing tag
map is preserved.

### §6.4 — Drift 4 (Haskell MTL)
**Refused.** No nested `handle(handle(...))` stacking. The
substrate is direct allocator dispatch + structural recursion;
no monad-transformer shape.

### §6.5 — Drift 5 (C calling convention / ambient state) — **largest risk surface**
**Refused.** NO `$current_arena` global. NO threaded allocator
parameter. Each call site explicitly chose `$make_record` or
`$make_record_stage`. Per `arena.wat:18-19` the discipline is
caller-determined per call site; this handle preserves that
verbatim across the 23 reason constructor sites + the one
$gnode_make retrofit. The walkthrough names this refusal because
it is the trap most likely to drift in: "let me add a thread-
local to track which arena is active" would be the C/Rust
fluent answer; the Mentl answer is "the call site already knows
the lifetime; let the call site say so."

### §6.6 — Drift 6 (primitive type special-case)
**Refused.** Every Reason variant gets explicit arm. NO "Bool
is special — treat 222 specially." The 23 variants are
enumerated uniformly in `$sizeof_reason_record` and
`$reason_promote_deep` per their per-variant recursion shape.

### §6.7 — Drift 7 (parallel arrays)
**Refused.** No parallel arrays of (tag, sizeof) or (tag,
arity). The sizing helper dispatches on `$tag_of`; the existing
record layout (one `[tag][arity][fields...]` per Reason)
remains the substrate-native encoding.

### §6.8 — Drift 8 (string-keyed / flag-as-int)
**Refused.** NO `(table_lookup tag - 220)` flat array — that
would be drift 8 at the integer level. NO `mode == 0/1/2`. The
direct `(if (i32.eq tag K))` dispatch chain is substrate-honest
per `walk_expr.wat:150-156` precedent ("Arms dispatch via
direct (if (i32.eq tag …)) chain").

### §6.9 — Drift 9 (deferred-by-omission)
**Refused.** All four edit categories (record.wat additions,
graph.wat retrofit, 23 reason.wat constructor routes, walk-
through authoring) land in the §C single substrate commit.
NodeKind retrofit is named as positive-form peer follow-up
`Hβ.first-light.nodekind-stage-alloc-retrofit` per §B.4 audit
verdict. The walkthrough commit precedes the substrate commit
by one commit boundary (§B before §C, per Anchor 7 #1).

---

## §7 · The promote-on-bind protocol

### §7.1 — The contract at `$gnode_make`

Pseudo-code:
```
$gnode_make(nk, reason):
  if reason == 0:                         ;; null-guard for graph_node_at synthesis
    promoted = 0
  elif $reason_in_perm(reason):           ;; idempotent: already perm → no-op
    promoted = reason
  else:                                    ;; stage-resident → promote deep
    promoted = $reason_promote_deep(reason)
  g = $make_record(80, 2)                 ;; GNode IS perm
  $record_set(g, 0, nk)                   ;; NodeKind stays as caller passed
  $record_set(g, 1, promoted)             ;; Reason is now perm-resident
  return g
```

The bound check `$reason_in_perm` is integer comparison against
`STAGE_ARENA_START` per arena.wat constants. Substrate-honest:
the caller KNOWS where the pointer came from (they just called
`$make_record_stage` or `$make_record`); the runtime predicate
is the safety net for paths that don't yet route correctly +
the idempotency precondition for re-entry.

### §7.2 — The recursion

`$reason_promote_deep(r)`:
1. If `$reason_in_perm(r)`: return `r` (idempotency).
2. Else: dispatch on `$tag_of(r)`:
   - For each variant: extract its fields; recurse on field-
     Reasons; allocate a fresh perm record via `$make_record`
     (the perm allocator); store the promoted-or-passthrough
     fields in their original positions; return new pointer.

### §7.3 — Why deep, not shallow

If `$gnode_make` shallow-promoted only the outer Reason (i.e.,
just `$perm_promote(reason, sizeof_reason(reason))`), then a
chain like `Located(span, Inferred(ctx))` would land an outer
perm-Reason holding a stage-Reason inner pointer. At next
`$stage_reset`, the outer's `inner` field becomes garbage. Deep
recursion is correctness-required.

---

## §8 · Reason-chain pointer-identity preservation

### §8.1 — The opaque-field audit

Per `reason.wat:84-107` Reason variants take payloads of these
classes:
- **String** (variants: 220, 221, 224-226, 230, 232, 236, 239-242).
  Two sub-cases: data-segment-resident (literals; e.g.,
  `i32.const 3568` "right" in `walk_expr.wat`); or
  `$str_alloc`-allocated (parser/lexer dynamic strings). Both
  paths route through `$alloc → $perm_alloc`. Stable.
- **Int** (variants: 222, 226, 241). i32 sentinel value;
  not a heap pointer. Stable.
- **BinOp** (variant: 235). i32 sentinel (parser_infra.wat tags
  140-153). Stable.
- **Span** (variants: 234, 238, 242). Parser allocates Span via
  `$alloc → $perm_alloc`. Stable. (Audit confirmed: `parser_*.wat`
  uses `$alloc` exclusively; no `$stage_alloc` paths for Span.)
- **Ty** (variants: 233 UnifyFailed). `ty.wat`'s `$ty_make_*`
  routes through `$make_record → $alloc → $perm_alloc`. Stable.
  (Future work: if Ty allocation becomes a separate pressure,
  `Hβ.first-light.ty-stage-alloc-retrofit` peer handle handles it.)
- **Predicate** (variant: 237 Refinement). Parser allocates via
  `$alloc → $perm_alloc`. Stable.
- **Reason** (variants: 223, 224-227, 230-232, 238-240; field 0
  or 1 or both). RECURSE (the §7.2 protocol).

### §8.2 — Per-variant recursion shape

Per `reason.wat:84-107` arity table:
| Tag | Variant | Arity | Sub-Reason fields | Promote shape |
|---|---|---|---|---|
| 220 | Declared(String) | 1 | none | shallow $perm_promote (12 bytes) |
| 221 | Inferred(String) | 1 | none | shallow $perm_promote (12 bytes) |
| 222 | Fresh(Int) | 1 | none | shallow $perm_promote (12 bytes) |
| 223 | OpConstraint(String, Reason, Reason) | 3 | f1, f2 | recurse f1, f2; rebuild |
| 224 | VarLookup(String, Reason) | 2 | f1 | recurse f1; rebuild |
| 225 | FnReturn(String, Reason) | 2 | f1 | recurse f1; rebuild |
| 226 | FnParam(String, Int, Reason) | 3 | f2 | recurse f2; rebuild |
| 227 | MatchBranch(Reason, Reason) | 2 | f0, f1 | recurse f0, f1; rebuild |
| 228 | ListElement(Reason) | 1 | f0 | recurse f0; rebuild |
| 229 | IfBranch(Reason) | 1 | f0 | recurse f0; rebuild |
| 230 | LetBinding(String, Reason) | 2 | f1 | recurse f1; rebuild |
| 231 | Unified(Reason, Reason) | 2 | f0, f1 | recurse f0, f1; rebuild |
| 232 | Instantiation(String, Reason) | 2 | f1 | recurse f1; rebuild |
| 233 | UnifyFailed(Ty, Ty) | 2 | none | shallow $perm_promote (16 bytes) |
| 234 | Placeholder(Span) | 1 | none | shallow $perm_promote (12 bytes) |
| 235 | BinOpPlaceholder(BinOp) | 1 | none | shallow $perm_promote (12 bytes) |
| 236 | MissingVar(String) | 1 | none | shallow $perm_promote (12 bytes) |
| 237 | Refinement(Predicate, Predicate) | 2 | none | shallow $perm_promote (16 bytes) |
| 238 | Located(Span, Reason) | 2 | f1 | recurse f1; rebuild |
| 239 | InferredCallReturn(String, Reason) | 2 | f1 | recurse f1; rebuild |
| 240 | InferredPipeResult(String, Reason) | 2 | f1 | recurse f1; rebuild |
| 241 | FreshInContext(Int, String) | 2 | none | shallow $perm_promote (16 bytes) |
| 242 | DocstringReason(String, Span) | 2 | none | shallow $perm_promote (16 bytes) |

§C.3 lays each arm out explicitly per drift mode 6 (no
fast-path-for-simple).

### §8.3 — Recursion depth bound

Reason chains in the seed are bounded by AST nesting depth
(LetBinding → VarLookup → ... ). Pathological depth would mean
a deeply-nested expression (e.g., `let a = let b = let c = ...`)
with the inferer building a corresponding Reason chain. Empirical
seed traces show depths of 3-8 typically; the substrate
recursion is bounded by `wasmtime`'s default stack limit
(~1 MB default; >10K frames). If §G surface 2 fires (>100-deep
chains), the surface to escalate is the Reason chain shape, not
the promote-deep shape.

---

## §9 · Sizing table

`$sizeof_reason_record(ptr)` dispatches on `$tag_of`; per
`record.wat:24-30` every record is `8 + 4*arity` bytes. Per
`reason.wat:84-107`:

| Arity | Bytes | Variants |
|---|---|---|
| 1 | 12 | 220, 221, 222, 228, 229, 234, 235, 236 |
| 2 | 16 | 224, 225, 227, 230, 231, 232, 233, 237, 238, 239, 240, 241, 242 |
| 3 | 20 | 223, 226 |

The dispatch is one-arm-per-tag direct `(if (i32.eq tag K))`
chain (per §6.8 drift 8 refusal). Trap on unknown via
`(unreachable)` per H6 wildcard discipline. The helper is
referenced ONLY by the four "no-sub-Reason" arms of
`$reason_promote_deep` — variants where the entire record can
be `$perm_promote`-d as one shallow copy without rebuilding
field-by-field.

---

## §10 · Verification gates

Per §E in the prescriptive plan; recorded in commit message.

1. **Drift-audit clean:** `bash tools/drift-audit.sh
   bootstrap/src/runtime/record.wat
   bootstrap/src/runtime/graph.wat
   bootstrap/src/infer/reason.wat` — exit 0.
2. **Bootstrap re-assembly:** `bash bootstrap/build.sh` — exit
   0; `bootstrap/mentl.wasm` produced; `wasm-validate` passes.
3. **Trace-harness non-regression:** `bash bootstrap/test.sh`
   — 80/80 PASS.
4. **First-light Tier 1 non-regression:** `bash bootstrap/
   first-light.sh` — exit 0.
5. **Empirical full-wheel test (the headline gate):**
   ```
   timeout 60 bash -c 'cat src/*.mn lib/runtime/*.mn lib/*.mn \
     | wasmtime run bootstrap/mentl.wasm > /tmp/inka2.wat'
   ```
   Expected: exit 0 within 60s; non-empty WAT output. Pre-fix:
   exit 124, 0 bytes, 50+ minute plateau.
6. **Determinism gate:** `cat ... | wasmtime run inka2.wasm >
   /tmp/inka3.wat; diff /tmp/inka2.wat /tmp/inka3.wat` — same
   output (deterministic byte-identical). Pre-existing
   determinism contract is preserved (allocation-order is the
   same across runs; promote-on-bind is deterministic).
7. **Reason-promote smoke harness** (`bootstrap/test/runtime/
   reason_promote_smoke.wat`):
   - `$make_record_stage(220, 1)` returns ptr ∈ stage region.
   - `$reason_in_perm(stage_ptr)` returns 0; `$reason_in_perm
     (perm_ptr)` returns 1.
   - `$reason_promote_deep` on stage-allocated `$reason_make_
     located(span, $reason_make_inferred(ctx))` — outer + inner
     both end up in perm region.
   - `$reason_promote_deep` is idempotent on perm-resident inputs.
   - `$gnode_make(nk, stage_reason)` returns a GNode whose
     reason field is in perm region.
   - After `$stage_reset`, the GNode's reason field is still
     readable (the field points at the promoted copy).

---

## §11 · The PATH branches (§G escalation surfaces)

### §11.1 — Hypothesis fails (§A.4)
If gnode-bound Reasons > 60% of total: STOP. Substrate proceeds
differently — region inference per `Hβ-arena-region-inference.md`
becomes the lever. This branch did NOT fire in the §A.1
structural pre-audit (gnode-bound class is empirically <<10%).

### §11.2 — fn-arena Reason pressure
If `$reason_promote_deep` recursion encounters a Reason variant
whose field-Reason is in fn-arena (not stage-arena): the
predicate `$reason_in_perm < STAGE_ARENA_START` would
incorrectly route fn-arena pointers to `$perm_promote` (they'd
be invalidated at `$fn_reset`, not `$stage_reset`). Audit:
`bootstrap/src/infer/own.wat` is the only seed file that calls
`$fn_alloc`; its Reason allocations route through `$reason_make_*`
(post-fix: `$make_record_stage`). Branch did NOT fire — Reasons
are not stored in fn-arena currently.

### §11.3 — Opaque-field allocation discipline
If `ty.wat` / parser allocates Span/Ty/Predicate via
`$stage_alloc` (the §B.8 audit assumed they all use `$alloc →
$perm_alloc`): promote-deep would need extension to traverse
opaque fields too. Audit: `parser_*.wat` and `ty.wat` use
`$alloc` exclusively (greppable: zero `$stage_alloc` calls
outside this handle's additions). Branch did NOT fire.

### §11.4 — Cross-stage state in $state.wat / emit/state.wat
If `$stage_reset` invalidates non-Reason transient state the
seed depends on cross-stage: trace harnesses regress. The
existing arena.wat substrate has been live since commit
`d57e20c`; build.sh's $stage_reset placement is settled.
Substrate not in scope of this handle.

### §11.5 — Instrumentation cleanup
This handle's substrate commit MUST NOT contain any
$reason_count_* instrumentation. §A residue is recorded in this
walkthrough §2.2 as static-survey evidence; no instrumentation
was added to the seed.

### §11.6 — `$perm_promote` existence
Confirmed: `arena.wat:154-167`. Exported. No surface needed.

---

## §12 · Named peer follow-ups (positive form, drift 9 closure)

These compose ON the substrate landed in this handle but
require their own walkthroughs:

- **`Hβ.first-light.lexer-stage-alloc-retrofit`** — token stream
  is parse-consumed; should route through `$stage_alloc`. Already
  named in `arena.wat:48-50`. Orthogonal.

- **`Hβ.first-light.nodekind-stage-alloc-retrofit`** — IF NodeKind
  records surface as ≥10% perm contribution post-this-handle, the
  parallel routing for the 5 NodeKind constructors lands here.
  Walkthrough mirrors §B with NodeKind vocab. Default verdict:
  pending §C empirical post-fix measurement; may be unnecessary.

- **`Hβ.first-light.unify-reason-chain-locality`** — `unify.wat`
  builds Reason chains via `$reason_make_unified(left, right)`
  during type unification. Routing through stage-arena is
  automatic via §C.5; if unify allocations dominate the post-fix
  pressure profile, this handle audits unify-internal Reason
  flows for additional locality (early stage-promote, scratch-
  reset between unify rounds).

- **`Hβ.first-light.scheme-forall-stage-alloc`** — `$scheme_make_
  forall` (scheme.wat:335-340) allocates Forall records that get
  stored in env entries. If Forall records benefit from
  promote-on-extend at `$env_extend`, this handle lands the
  parallel substrate.

- **`Hβ.first-light.stage-reset-non-reason-substrate-audit`** —
  full audit of EVERY pointer that survives a `$stage_reset` to
  verify no other transient classes need promote-on-bind
  discipline.

- **`Hβ-arena-region-inference.md`** (already cataloged in
  ROADMAP post-L1) — Tofte/Talpin region inference unifies all
  this discipline at compile time via refinement types. The
  seed-side stage-arena routing IS the precursor; the wheel-
  side region inference IS the long-term form.

- **`Hμ.memory-stage-arena-effect`** — wheel-side parity
  authoring per Anchor 4. The seed-side substrate gets the seed
  to L1; post-L1 self-compile produces the wheel-side .wat from
  `lib/runtime/memory.mn` + `src/graph.mn` automatically. NOT
  in this commit's scope.

The plan-residue ends here. The implementer types the residue.
