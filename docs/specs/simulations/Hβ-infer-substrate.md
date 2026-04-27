# Hβ.infer — HM inference substrate at the WAT layer

> **Status:** `[DRAFT 2026-04-25]`. Sub-walkthrough peer to
> `Hβ-bootstrap.md` (commit `95fdc3c`). Names the design contract for
> the seed's HM inference layer projected onto the Wave 2.A–D
> Layer-1 runtime substrate (`bootstrap/src/runtime/{alloc,str,int,
> list,record,closure,cont,graph,env,row,verify}.wat`). This
> walkthrough freezes the WAT-level shape; substrate transcription
> follows per Anchor 4 ("build the wheel; never wrap the axle") +
> Anchor 7 ("walkthrough first, audit always").
>
> **Authority:** `CLAUDE.md` Mentl's anchor + Anchor 0 (dream code) +
> Anchor 7 (cascade discipline); `docs/DESIGN.md` §0.5 (eight-
> primitive kernel; this walkthrough realizes primitive #8 — HM
> inference live + productive-under-error + with Reasons);
> `docs/specs/04-inference.md` (the canonical algorithm contract);
> `docs/specs/00-graph.md` (graph substrate the writes target);
> `docs/specs/01-effrow.md` (Boolean effect-row algebra);
> `docs/specs/02-ty.md` + `03-typed-ast.md` + `06-effects-surface.md`
> + `07-ownership.md` (the surface the walk infers over);
> `docs/specs/simulations/Hβ-bootstrap.md` §1.2 + §13 (parent
> walkthrough; Layer 4 sub-handle); `src/infer.nx` (2193 lines, the
> wheel — this WAT IS its seed transcription).
>
> *Claim in one sentence:* **The seed's HM inference is one walk
> over the AST that calls `$graph_*` to bind handles, `$env_*` to
> resolve names, `$row_*` to compose effect rows, `$verify_record`
> to accumulate refinement obligations, and produces a typed AST
> + populated env that Hβ.lower (sibling sub-walkthrough) reads via
> `$graph_chase` to construct LowIR. Per spec 04: no separate check
> vs infer phase; no subst sidecar; no constraint batch; the graph
> IS the constraint store.**

---

## §0 Framing — what Hβ.infer resolves

### 0.1 What's missing from the current seed

Per `Hβ-bootstrap.md` §11 + BT.A.0 sweep (commit `d6117f5`): the
current seed does **lex → parse → direct-emit** (no inference, no
lowering). That's why 35/50 .nx files produce degenerate WAT
(graph.nx → 34 lines, undefined locals from import-as-identifier-
expression handling). The path to first-light-L1 requires the seed
to be a **full** Inka compiler — lex → parse → INFER → LOWER → emit.

This walkthrough names the inference layer. Sibling
`Hβ-lower-substrate.md` (pending) names the lowering layer.

### 0.2 What Hβ.infer composes on

The Wave 2.A–D Layer-1 runtime substrate that just landed (commits
`e78c988` through `94a331f`) is the foundation:

| Substrate | Provides | Used by Hβ.infer for |
|-----------|----------|----------------------|
| `alloc.wat` | `$alloc` bump + `$heap_base` | every heap allocation |
| `str.wat` | flat strings + `$str_eq` + `$str_compare` | name/keyword comparisons |
| `int.wat` | `$parse_int`, `$int_to_str` | numeric literal handling |
| `list.wat` | tagged lists with full tag dispatch | param lists / arg lists / typed-AST children |
| `record.wat` | `$make_record` + `$tag_of` + `$is_sentinel` | every typed AST node + every Ty/EffRow record |
| `closure.wat` | closure record layout | `Forall(qs, body)` Schemes (closure-shaped) |
| `cont.wat` | H7 multi-shot continuation | future `infer_or` candidates (post-MS handler swap) |
| **`graph.wat`** | `$graph_init/fresh_ty/fresh_row/chase/bind/bind_row/push_checkpoint/rollback`, NodeKind constructors + accessors | **THE substrate inference writes to** — every binding goes through `$graph_bind`; every fresh handle through `$graph_fresh_*` |
| **`env.wat`** | `$env_init/lookup/extend/scope_enter/scope_exit/contains` | name resolution at every `VarRef`; let-binding extends; scope at FnStmt |
| **`row.wat`** | `$row_make_*/union/diff/inter/subsumes`, name-set algebra | every effect-row composition; subsumption at handler install |
| `verify.wat` | `$verify_record/pending_count/discharge_at` | refinement obligations from `TRefined(_, pred)` |

### 0.3 What Hβ.infer designs (this walkthrough)

- **§1** — Module-level state for the inference pass (per-walk
  scratchpads: ref-escape tracker, current FnStmt's quantification
  context, span/intent indices for the query layer).
- **§2** — The Scheme substrate ($scheme_make + accessors;
  $instantiate; $generalize).
- **§3** — The unify primitive at the WAT layer + unify_shapes
  dispatch table.
- **§4** — The walk: `$infer_expr` + `$infer_stmt` arms per AST
  shape.
- **§5** — Ownership inference inline in the walk (consume/escape
  tracking).
- **§6** — Per-edit-site eight interrogations.
- **§7** — Forbidden patterns per edit site.
- **§8** — Substrate touch sites — chunk decomposition with
  literal-token guidance per chunk.
- **§9** — Worked example: inferring `fn double(x) = x + x`.
- **§10** — Composition with Hβ.lex / Hβ.parse / Hβ.lower / Hβ.emit.
- **§11** — Acceptance criteria.
- **§12** — Open questions.
- **§13** — Dispatch + sub-handle decomposition.
- **§14** — Closing.

### 0.4 What Hβ.infer does NOT design

- **AST representation.** Spec 03 + the wheel's `src/parser.nx`
  output. Hβ.infer assumes the AST is a heap-record graph keyed by
  the parser's TypeHandle allocations.
- **Lowering to LowIR.** Sibling walkthrough Hβ-lower-substrate.md
  (pending). Hβ.infer produces typed AST + populated graph; lower
  reads that via `$graph_chase`.
- **Emit.** Hβ.emit chunk per Hβ-bootstrap.md §9. Lowers LowIR to
  WAT text per per-LowExpr-variant arms.
- **Multi-module type/handler resolution.** Cross-module env
  composition gates on `graph.wat` overlay primitives (named
  follow-up; this walkthrough's Tier-3 base assumes single-module
  scope — sufficient for self-compile + crucibles per BT.A.0).
- **SMT discharge of refinement obligations.** verify.wat's ledger
  accumulates them; the verify_smt swap-handler (B.6, Arc F.1)
  discharges. Hβ.infer just calls `$verify_record`.
- **The Synth/oracle chain.** Mentl's speculative inference per
  insight #11 composes ON the inference substrate (cont.wat +
  graph.wat checkpoint/rollback). The seed runs inference; the
  wheel runs Mentl's oracle on top. Hβ.infer is the substrate the
  oracle uses, not the oracle itself.

### 0.5 Relationship to spec 04 + src/infer.nx

Spec 04 names the algorithm in three operations + Env + unification +
the four production patterns (structural constraints, unifications,
generalizations, instantiations). `src/infer.nx` (2193 lines) is the
wheel's HM implementation in Inka; it's the canonical algorithmic
contract.

This walkthrough projects spec 04 + src/infer.nx onto the Wave 2.A–D
WAT substrate. The PROJECTION is the work: where src/infer.nx's
`graph_bind(h, ty, reason)` call is one Inka line, the WAT
projection is `(call $graph_bind (local.get $h) (local.get $ty)
(local.get $reason))` and the surrounding control-flow logic.

Per Anchor 4: src/infer.nx IS the wheel; this WAT IS the seed
transcription. Per Anchor 0: the WAT assumes graph.wat / env.wat /
row.wat / verify.wat are perfect (they are — Wave 2.C/D landed).

---

## §1 Module-level state — the inference pass scratchpads

Beyond what graph.wat / env.wat hold (the global graph + scope
stack), the inference pass itself maintains per-walk scratchpads.
These are **NOT** ambient state for downstream passes (lower /
emit / query); they are scoped to the walk's duration and
materialized into graph entries at appropriate boundaries.

Per Hβ §2.1 module-shell discipline: these scratchpads live as
module-level globals in a new `bootstrap/src/infer/state.wat`
chunk per the §8 sub-decomposition.

```wat
;; ─── Per-walk scratchpads ────────────────────────────────────────
(global $infer_initialized        (mut i32) (i32.const 0))

;; Ref-escape tracker (per spec 04 §Ownership inference). Flat list
;; of (name_str_ptr, span_ptr) entries. Names referenced via `ref`
;; that haven't been consumed yet; FnStmt exits check against
;; return position. Cleared at scope_enter/exit alongside env scope.
(global $infer_ref_escape_ptr     (mut i32) (i32.const 0))
(global $infer_ref_escape_len_g   (mut i32) (i32.const 0))

;; Current FnStmt quantification context. The handle of the FnStmt
;; node currently being walked; used by $generalize at FnStmt exit
;; to know which env entries are part of THIS function's body.
;; Stack-shaped (for nested fns); simple list of i32 handles.
(global $infer_fn_stack_ptr       (mut i32) (i32.const 0))
(global $infer_fn_stack_len_g     (mut i32) (i32.const 0))

;; Span index (per src/graph.nx graph_index_span). Each AST node's
;; (span, handle) pair; used by query layer post-inference for
;; cursor-position lookups. Inference appends; downstream reads.
(global $infer_span_index_ptr     (mut i32) (i32.const 0))
(global $infer_span_index_len_g   (mut i32) (i32.const 0))

;; Intent index (per src/graph.nx graph_index_intent). Each FnStmt's
;; (handle, declared_effects) pair; used by query for "what handlers
;; would this fn need?" surfaces.
(global $infer_intent_index_ptr   (mut i32) (i32.const 0))
(global $infer_intent_index_len_g (mut i32) (i32.const 0))
```

`$infer_init` is idempotent; allocates initial buffers; called
from every public-entry chunk (`infer_expr`, `infer_stmt`,
`generalize`) so the seed can drive inference from any entry point.

---

## §2 The Scheme substrate

Per spec 04: `Scheme = Forall(List, Ty)` — quantified handles +
body type. Schemes hold env entries; instantiation mints fresh
handles per quantified position; generalization quantifies free
handles in the inferred type.

### 2.1 Heap layout

```
Scheme record:
  $make_record(SCHEME_TAG=200, arity=2)
    offset  8: field_0 = quantified handles (flat list of i32)
    offset 12: field_1 = body Ty (heap pointer)
```

Tag regions reserved for Hβ.infer private records (extended
2026-04-26 per Wave 2.E.infer.reason substrate-gap finding —
agent found 23 canonical Reason variants in src/types.nx vs
9-named subset in this walkthrough's earlier draft + only 17
free slots in the original 200-219 region; per Anchor 7 cascade
discipline + drift mode 9 / drift mode 8: the canonical ADT must
be honored, not under-named):

  - **200-219** — non-Reason infer-private records (state.wat
    consumed 210/211/212 for REF_ESCAPE_ENTRY / SPAN_INDEX_ENTRY /
    INTENT_INDEX_ENTRY; 17 slots remain for ty.wat / scheme.wat /
    walk_*.wat / etc. peer records)
  - **220-249** — Reason variants (30 slots for current 23
    canonical variants + 7 future-headroom). Per §8.1 reason.wat
    row: 220=Declared, 221=Inferred, 222=Fresh, 223=OpConstraint,
    224=VarLookup, 225=FnReturn, 226=FnParam, 227=MatchBranch,
    228=ListElement, 229=IfBranch, 230=LetBinding, 231=Unified,
    232=Instantiation, 233=UnifyFailed, 234=Placeholder,
    235=BinOpPlaceholder, 236=MissingVar, 237=Refinement,
    238=Located, 239=InferredCallReturn, 240=InferredPipeResult,
    241=FreshInContext, 242=DocstringReason. (242-249 reserved for
    future Reason variants per src/types.nx evolution.)

### 2.2 Constructors + accessors

```wat
(func $scheme_make_forall (param $qs i32) (param $body i32) (result i32)
  (local $s i32)
  (local.set $s (call $make_record (i32.const 200) (i32.const 2)))
  (call $record_set (local.get $s) (i32.const 0) (local.get $qs))
  (call $record_set (local.get $s) (i32.const 1) (local.get $body))
  (local.get $s))

(func $scheme_quantified (param $s i32) (result i32)
  (call $record_get (local.get $s) (i32.const 0)))

(func $scheme_body (param $s i32) (result i32)
  (call $record_get (local.get $s) (i32.const 1)))
```

### 2.3 `$instantiate(scheme) -> Ty`

Walks scheme.body, substituting each quantified handle with one
freshly minted via `$graph_fresh_ty`. Per spec 04 §Instantiations:

```
For each q in scheme.quantified:
  fresh = $graph_fresh_ty(reason_instantiation)
  bind: q → fresh   (in a local substitution map for this walk)
walk scheme.body, replacing every TVar(q) with TVar(fresh) per the map
return rewritten body
```

Implementation: $instantiate calls `$ty_substitute` (a sibling helper)
which dispatches on Ty tags. Tag conventions for Ty variants land
alongside Hβ.lower (as the same conventions drive both inference and
lowering). The locked allocation per spec 02 ordering + RN.1
substrate (TAlias added 2026-04-26 per Wave 2.E.infer.ty substrate-
gap finding — agent caught 14 canonical variants vs 13-named earlier
draft):

```
TINT_TAG       = 100   ;; nullary sentinel
TFLOAT_TAG     = 101   ;; nullary sentinel
TSTRING_TAG    = 102   ;; nullary sentinel
TUNIT_TAG      = 103   ;; nullary sentinel
TVAR_TAG       = 104   ;; arity 1 — graph handle (Int)
TLIST_TAG      = 105   ;; arity 1 — element Ty ptr
TTUPLE_TAG     = 106   ;; arity 1 — list of element Ty ptrs
TFUN_TAG       = 107   ;; arity 3 — params list (TParam records), return Ty, eff row ptr
TNAME_TAG      = 108   ;; arity 2 — name str, args list (Bool/Option/etc. live here)
TRECORD_TAG    = 109   ;; arity 1 — list of (name, Ty) pairs
TRECORDOPEN_TAG= 110   ;; arity 2 — fields list, rowvar handle
TREFINED_TAG   = 111   ;; arity 2 — base Ty, predicate (opaque ptr — verify.wat precedent)
TCONT_TAG      = 112   ;; arity 2 — return Ty, ResumeDiscipline sentinel (250-252)
TALIAS_TAG     = 113   ;; arity 2 — alias name str, resolved Ty (RN.1 substrate;
                       ;;          per src/types.nx:48; preserves authored name
                       ;;          for intent-aware rendering — show_type at
                       ;;          src/types.nx:815 returns the alias name verbatim)

;; Reserved 114-119 for future Ty variants per src/types.nx evolution.
```

ResumeDiscipline is its own ADT (`src/types.nx:70-73`) referenced
from TCont's discipline field. Per the same nullary-sentinel
discipline (Hβ §1.5), ResumeDiscipline values are sentinel ints.
**Tag region 250-259 reserved (added 2026-04-26 per Wave 2.E.infer.ty
gap finding — earlier Hβ-lower §3.1 named 220/221/222 which now
collide with reason.wat's 220-242 Reason variants; relocated to
250-259 to preserve $tag_of uniqueness):**

```
RESUME_ONESHOT_TAG   = 250
RESUME_MULTISHOT_TAG = 251
RESUME_EITHER_TAG    = 252

;; Reserved 253-259 for future ResumeDiscipline variants if any.
```

`$ty_substitute` walks each variant; when it sees `TVar(q)` and `q`
is in the substitution map, returns `TVar(fresh)`. Other variants
recurse on sub-types. Pure WAT; no graph mutations during walk
(substitution is local to the call).

### 2.4 `$generalize(fn_handle) -> Scheme`

At FnStmt exit. Per spec 04 §Generalizations:

```
body_ty   = $chase_deep(perform $graph_chase(fn_handle))
body_free = $free_handles(body_ty)        ;; handles of NFree NodeKind reachable from body_ty
env_free  = $free_in_env()                ;; handles still NFree referenced from outer-scope env entries
quantified = $set_diff(body_free, env_free)
return $scheme_make_forall(quantified, body_ty)
```

Helpers:
- `$chase_deep(g)` — recursively chases NBound through Ty structure
  (the transitive walk Tier-3 graph.wat deferred; lands here as the
  caller-side helper since Hβ.infer needs it). Returns a fully-
  resolved Ty (no TVar(_) handles pointing at NBound chains).
- `$free_handles(ty)` — walks ty, collects handles whose chase
  terminates at NFree/NRowFree. Returns flat list of i32 handles.
- `$free_in_env()` — walks the current env scope chain, collects
  handles still NFree across all bindings. (Performance-sensitive
  in the seed; future optimization is per-binding-cached free-set.)
- `$set_diff(a, b)` — flat-list set difference; preserved-order
  output (use $name_set_diff substrate from row.wat with handle-
  list specialization, or write a peer for i32 sets in this chunk).

---

## §3 Unification — the primitive

Per spec 04 §Unification:

```wat
(func $unify (param $h_a i32) (param $h_b i32) (param $reason i32)
  (local $na i32) (local $nb i32)
  (local $ka i32) (local $kb i32)
  (local.set $na (call $graph_chase (local.get $h_a)))
  (local.set $nb (call $graph_chase (local.get $h_b)))
  (local.set $ka (call $node_kind_tag (call $gnode_kind (local.get $na))))
  (local.set $kb (call $node_kind_tag (call $gnode_kind (local.get $nb))))
  ;; NFree(_) on either side → bind it to the other's reified type
  (if (i32.eq (local.get $ka) (i32.const 61))     ;; NFREE
    (then (call $graph_bind (local.get $h_a)
                            (call $reify_node (local.get $nb))
                            (local.get $reason))
          (return)))
  (if (i32.eq (local.get $kb) (i32.const 61))
    (then (call $graph_bind (local.get $h_b)
                            (call $reify_node (local.get $na))
                            (local.get $reason))
          (return)))
  ;; Both NBound → unify_shapes
  (if (i32.and (i32.eq (local.get $ka) (i32.const 60))    ;; NBOUND
               (i32.eq (local.get $kb) (i32.const 60)))
    (then (call $unify_shapes
            (call $node_kind_payload (call $gnode_kind (local.get $na)))
            (call $node_kind_payload (call $gnode_kind (local.get $nb)))
            (local.get $reason))
          (return)))
  ;; NRowBound / NRowFree → delegate to $unify_row
  ;; (rows have peer dispatch per spec 01)
  (call $unify_row_dispatch (local.get $h_a) (local.get $h_b) (local.get $reason)))
```

`$reify_node` extracts the Ty pointer from an NBound node (or
synthesizes TVar(handle) for NFree — the reification handle).
`$unify_shapes` matches on Ty variant pairs:

```wat
(func $unify_shapes (param $a i32) (param $b i32) (param $reason i32)
  (local $ta i32) (local $tb i32)
  (local.set $ta (call $tag_of (local.get $a)))
  (local.set $tb (call $tag_of (local.get $b)))
  ;; (TInt, TInt), (TFloat, TFloat), (TString, TString), (TUnit, TUnit) — ok
  (if (i32.and (i32.eq (local.get $ta) (i32.const 100))    ;; TINT
               (i32.eq (local.get $tb) (i32.const 100)))
    (then (return)))
  ;; ... arms for TFloat / TString / TUnit (lines per primitive variant)
  ;; (TList(x), TList(y)) → unify x y
  (if (i32.and (i32.eq (local.get $ta) (i32.const 105))    ;; TLIST
               (i32.eq (local.get $tb) (i32.const 105)))
    (then (call $unify_sub
            (call $record_get (local.get $a) (i32.const 0))
            (call $record_get (local.get $b) (i32.const 0))
            (local.get $reason))
          (return)))
  ;; (TFun(...), TFun(...)) → unify params + return + row
  ;; ... arms for TTuple, TName, TRecord, TRecordOpen, TRefined, TCont
  ;; Mismatch — emit diagnostic + bind to NErrorHole
  (call $infer_emit_type_mismatch (local.get $a) (local.get $b) (local.get $reason)))
```

Per spec 04 §Error handling (Hazel pattern): mismatch emits
`E_TypeMismatch` via the report effect (whose handler the seed's
diagnostic chain installs) + binds to `NErrorHole(UnifyFailed)`.
Inference continues. Seed's `$infer_emit_type_mismatch` synthesizes
the NodeKind via `$node_kind_make_nerrorhole` from graph.wat.

`$unify_sub(h_or_ty_a, h_or_ty_b, reason)` is the dispatcher that
handles both pure-Ty inputs (recursive sub-unification) and
handle inputs (route through $unify). Provides the polymorphism
src/infer.nx's `unify_sub` provides at the Inka level.

---

## §4 The walk — `$infer_expr` + `$infer_stmt`

Per spec 04 §What the walk produces. The walk dispatches on AST
variant tag; arms call $unify, $graph_bind, $env_lookup, etc.

### 4.1 `$infer_expr(node) -> ()`

```wat
(func $infer_expr (param $node i32)
  (local $tag i32) (local $h i32)
  (local.set $tag (call $tag_of (local.get $node)))
  (local.set $h (call $ast_handle (local.get $node)))   ;; helper per spec 03 layout
  ;; ConstExpr — bind to literal type
  (if (i32.eq (local.get $tag) (i32.const <CONST_TAG>))
    (then (call $infer_const (local.get $node))
          (return)))
  ;; VarRef — env lookup + instantiate scheme
  (if (i32.eq (local.get $tag) (i32.const <VARREF_TAG>))
    (then (call $infer_var_ref (local.get $node))
          (return)))
  ;; BinOpExpr — type-class-driven (TInt for arith, TBool for compare, etc.)
  (if (i32.eq (local.get $tag) (i32.const <BINOP_TAG>))
    (then (call $infer_binop (local.get $node))
          (return)))
  ;; CallExpr — fresh return + row, build TFun, unify against callee
  (if (i32.eq (local.get $tag) (i32.const <CALL_TAG>))
    (then (call $infer_call (local.get $node))
          (return)))
  ;; LambdaExpr — fresh handles per param, walk body, build TFun
  (if (i32.eq (local.get $tag) (i32.const <LAMBDA_TAG>))
    (then (call $infer_lambda (local.get $node))
          (return)))
  ;; LetExpr — walk value, generalize if non-effectful, extend env
  ;; IfExpr — infer cond/then/else, unify branches
  ;; MatchExpr — infer scrut, walk arms, unify arm bodies
  ;; ListExpr / TupleExpr / RecordExpr — element walks + tuple/record build
  ;; HandleExpr — install handler, infer body under installed handlers
  ;; PerformExpr — lookup op, instantiate, unify arg types
  ;; PipeExpr — dispatch on PipeKind, lower per spec 10 + spec 04
  ;;
  ;; ... one arm per AST variant per spec 03
  ;;
  ;; Unknown tag — should never happen in well-formed AST. Trap to surface.
  (unreachable))
```

Each `$infer_<variant>` helper implements one production from spec 04.
Per H6 wildcard-audit discipline: every load-bearing AST variant has
its own arm; no `_ =>` fallback that silently absorbs a new variant.

### 4.2 `$infer_stmt(stmt) -> ()`

Similar dispatch on stmt tag — FnStmt / LetStmt / TypeStmt /
EffectStmt / HandlerStmt / ImportStmt / ExprStmt. FnStmt is the
generalize-and-extend-env arm:

```wat
(func $infer_fn_stmt (param $stmt i32)
  (local $h i32) (local $name i32) (local $body i32) (local $scheme i32)
  (local.set $h (call $ast_handle (local.get $stmt)))
  (local.set $name (call $fn_stmt_name (local.get $stmt)))   ;; spec 03 accessor
  (local.set $body (call $fn_stmt_body (local.get $stmt)))
  ;; Push fn onto inference stack so $generalize knows current quantification scope
  (call $infer_fn_stack_push (local.get $h))
  ;; Walk body — populates the typed AST + env
  (call $infer_expr (local.get $body))
  ;; Generalize at exit
  (local.set $scheme (call $generalize (local.get $h)))
  ;; Pop fn from inference stack
  (call $infer_fn_stack_pop)
  ;; Extend env with the named binding (Forall scheme + Reason)
  (call $env_extend (local.get $name)
                    (call $scheme_to_env_value (local.get $scheme))))
```

`$scheme_to_env_value(scheme)` is no longer needed at the WAT layer:
env.wat's `$env_extend` takes the four-tuple (name, scheme, reason,
kind) directly per ROADMAP item 1's canonicalization. Callers compose
the kind via `$schemekind_make_*` constructors; the binding record
stores all four fields per `ENV_BINDING_TAG=130, arity=4`. Mirrors
canonical src/infer.nx's `perform env_extend(name, scheme, reason,
kind)` at lines 219, 233, 279, 368, 1589-1591, 2009, 2051, 2057,
2061, 2094, 2105.

### 4.3 Worked patterns by spec 04 production

Per spec 04 §What the walk produces — four production patterns:

**1. Structural constraints** (e.g., `+` is `TInt → TInt → TInt`):
```wat
(call $graph_bind (local.get $l_h) (call $ty_make_int)
                  (call $reason_op_constraint (... "+" ...)))
(call $graph_bind (local.get $r_h) (call $ty_make_int) (...))
(call $graph_bind (local.get $h)   (call $ty_make_int) (...))
```

**2. Unifications** (e.g., CallExpr unifies callee with built TFun):
```wat
(local.set $ret_h    (call $graph_fresh_ty (...)))
(local.set $row_h    (call $graph_fresh_row (...)))
(local.set $fn_built (call $ty_make_fun
                       (call $build_arg_params (local.get $args))
                       (call $ty_make_var (local.get $ret_h))
                       (call $row_make_open (call $make_list (i32.const 0))
                                            (local.get $row_h))))
(call $unify (local.get $f_h) (call $handle_for_ty (local.get $fn_built))
             (local.get $reason))
(call $graph_bind (local.get $h) (call $ty_make_var (local.get $ret_h))
                  (...))
```

**3. Generalizations** (FnStmt exit):
```wat
(local.set $scheme (call $generalize (local.get $fn_h)))
;; ... extend env with scheme
```

**4. Instantiations** (VarRef):
```wat
(local.set $lookup_result (call $env_lookup (local.get $name)))
(if (i32.eqz (local.get $lookup_result))
  (then
    (call $infer_emit_missing_var (local.get $name) (local.get $span))
    (call $graph_bind (local.get $h)
                      (call $node_kind_make_nerrorhole (...))
                      (...))
    (return)))
;; Instantiate the scheme
(local.set $instantiated (call $instantiate (local.get $lookup_result)))
(call $graph_bind (local.get $h) (local.get $instantiated)
                  (call $reason_var_lookup (...)))
```

---

## §5 Ownership inference (inline in walk)

Per spec 04 §Ownership inference + spec 07. Every VarRef:

```wat
;; If the binding is `own`-annotated:
(if (call $binding_is_own (local.get $binding))
  (then
    ;; Add Consume to the inferred row
    (call $row_add_to_current_walk (call $row_make_closed
                                          (call $list_singleton
                                            (call $name_intern (... "Consume" ...)))))))
;; If `ref`:
(if (call $binding_is_ref (local.get $binding))
  (then
    ;; Push to ref-escape tracker
    (call $infer_ref_escape_push (local.get $name) (local.get $span))))
```

FnStmt exit walks `$infer_ref_escape_*` against return positions per
spec 07 escape analysis. Affine linearity is the Consume effect's
handler concern (`affine_ledger`); inference just notes the row
contribution.

---

## §6 Per-edit-site eight interrogations

Each chunk's edit sites pass all eight per CLAUDE.md / DESIGN.md §0.5.

### 6.1 At the Scheme substrate

| # | Primitive | Answer |
|---|-----------|--------|
| 1 | **Graph?** | Schemes are stored in env.wat; their body Ty references graph handles. `$instantiate` calls `$graph_fresh_ty` for each quantified slot. |
| 2 | **Handler?** | The seed's inference is module-level globals + direct calls (no handler machinery — handler-shape is the wheel's compiled form). `$instantiate / $generalize` are direct functions. |
| 3 | **Verb?** | N/A at substrate level. |
| 4 | **Row?** | $generalize quantifies over BOTH type AND row free handles (spec 04 §Generalizations + spec 01 row substrate). Schemes carry a single quantified-list — row-handle / type-handle disambiguation is via NFree-vs-NRowFree at chase time. |
| 5 | **Ownership?** | Schemes are reference-counted-once (never deep-copied; instantiation walks but doesn't clone). |
| 6 | **Refinement?** | TRefined(_, pred) inside scheme.body propagates verbatim through instantiate; the predicate's handle is also fresh-rewritten (refinement composition with fresh quantification). |
| 7 | **Gradient?** | Each `Forall(qs, body)` with empty qs is a monomorphic binding (the gradient signal that lower can direct-call vs evidence-pass). |
| 8 | **Reason?** | Generalize records `Generalized(fn_name, span)`; instantiate records `Instantiated(scheme_origin)`. Reason chains preserved. |

### 6.2 At the unify primitive

| # | Primitive | Answer |
|---|-----------|--------|
| 1 | **Graph?** | $graph_chase + $graph_bind are the ONLY mutations; no side-channel. |
| 2 | **Handler?** | Unify dispatches on NodeKind tags via $node_kind_tag (graph.wat). |
| 3 | **Verb?** | N/A at primitive level. |
| 4 | **Row?** | NRowBound / NRowFree route through $unify_row_dispatch which composes $row_union/diff/inter from row.wat per spec 01 unification rules. |
| 5 | **Ownership?** | Unify reads node payloads; ownership flows transparent (Ty pointers are `ref`). |
| 6 | **Refinement?** | (TRefined(a, p), TRefined(b, q)) arm calls $verify_record with PAnd(p, q) per spec 04 §Unification table. |
| 7 | **Gradient?** | Successful unify against a ground concrete type narrows the gradient (NFree → NBound is a gradient step). |
| 8 | **Reason?** | Every $graph_bind in unify carries the propagated Reason; mismatches carry UnifyFailed(a, b). |

### 6.3 At the walk arms

| # | Primitive | Answer |
|---|-----------|--------|
| 1 | **Graph?** | Every AST node's handle is a graph entry; binds via $graph_bind. |
| 2 | **Handler?** | The walk doesn't install handlers; it INFERS the row that downstream handle-install will check via $row_subsumes. |
| 3 | **Verb?** | PipeExpr arms dispatch per PipeKind (per spec 10): \|> bare apply; <\| divergent; >< parallel; ~> handler attach; <~ feedback. Each arm builds the typed AST + populates the row. |
| 4 | **Row?** | Every effect-causing op (perform, $env_lookup of a `with` declaration) adds to the row. Compositions via $row_union. |
| 5 | **Ownership?** | Per §5 — VarRef adds Consume / pushes ref-escape. FnStmt exit checks. |
| 6 | **Refinement?** | TRefined inputs flow through $verify_record at construction sites. |
| 7 | **Gradient?** | Each `??` hole (per the recent SYNTAX update — commit `f911df1`) is a NodeKind NFree at parse time + INFER does the speculative search via Synth chain (post-MS handler swap). Tier-3 base just synthesizes NErrorHole on `??`; the gradient surfaces from there. |
| 8 | **Reason?** | Every operation records (e.g., ListElement(r), FnReturn("fn", r), Inferred("walked op")). |

---

## §7 Forbidden patterns per edit site

Every drift mode 1-9 named explicitly. Inference is where MOST drift
historically sneaks in (compiler-inference is the substrate where
type-inference-library familiarity from any other ecosystem leaks
in), so the discipline is strict.

### 7.1 At unify

- **Drift 1 (Rust vtable):** No type-class dispatch table. Unify
  branches on NodeKind tag + Ty tag via direct comparisons; no
  table lookup.
- **Drift 2 (Scheme env frame):** No `current_substitution` parameter
  threaded through unify calls. Subst IS the graph; no sidecar.
- **Drift 3 (Python dict / string-keyed):** Ty variants dispatch via
  ADT tags (integer constants), NOT via `if str_eq(ty_name, "TInt")`.
  Per the Tier-3 tag conventions in §2.3 — the seed's tag values are
  hardcoded constants; the wheel allocates its own tag space at
  Hβ.lower-time.
- **Drift 4 (Haskell monad transformer):** Unify is a direct
  function; no `UnifyM` monad. Unify mutates the graph via
  $graph_bind directly.
- **Drift 5 (C calling convention):** Unify takes `(h_a, h_b, reason)`
  — three i32 parameters. No bundled "context struct + state ptr"
  pseudo-handler-state.
- **Drift 6 (primitive-type-special-case):** TInt is NOT a special
  intrinsic. It's a Ty variant with tag 100, treated identically to
  every other variant. Per HB-bool-transition lessons applied to
  numerics + TUnit.
- **Drift 7 (parallel-arrays-instead-of-record):** Schemes are 2-field
  records (qs, body); no parallel `(scheme_qs[], scheme_bodies[])`
  arrays.
- **Drift 8 (mode flag):** Unify doesn't take a `mode: Int` parameter
  for "strict" vs "subtype" vs "lax" mode. ONE unify; mismatches
  emit + bind to NErrorHole + continue.
- **Drift 9 (deferred-by-omission):** Every Ty variant in unify_shapes
  has its arm OR the arm explicitly emits "not yet implemented"
  diagnostic. No silent fallback that absorbs new variants.

**Foreign fluency — type inference libraries:**

| Foreign vocabulary | Inka substrate |
|--------------------|----------------|
| Algorithm W's `(subst, type)` return | $unify mutates graph; returns `()` |
| Algorithm M's bidirectional check vs infer | One walk; spec 04 §Three operations |
| Constraint sets (Pottier's CHKL) | Graph IS the constraint store |
| `instantiate(scheme, mode=...)` | One $instantiate; one mechanism |
| Type families / GADTs | Out of Inka scope (spec 02); refinements substitute |
| Higher-rank polymorphism | Out of Inka scope (Damas-Milner only) |
| Effect inference as a separate pass | Effects in TFun; one walk per spec 04 closing |

If any of those vocabulary items appears in the seed's chunk
comments or function names, it's drift; restructure.

### 7.2 At the walk

- **Drift 4 (transformer):** Walk arms call $infer_<variant> directly;
  no `>>=` / monad combinator.
- **Drift 9:** Every AST variant has its arm; no `_ =>` silent
  fallback. Trap on unknown via `(unreachable)`.

### 7.3 At ownership inference

- **Drift 6:** Consume is a regular row entry; no compiler intrinsic.
- **Foreign fluency — Rust borrow checker:** ref/own tracking is via
  the row + escape-tracker — not a separate borrow-checker pass.
  Vocabulary: "Consume effect", "ref-escape tracker", "FnStmt exit
  check" — NOT "borrow", "lifetime", "region ID".

---

## §8 Substrate touch sites — chunk decomposition

`bootstrap/src/infer/` directory holds the inference layer chunks
per the Wave 2 modular pattern. Each chunk has a header per the
INDEX.tsv discipline; each chunk independently testable via WABT.

### 8.1 Proposed file layout

```
bootstrap/src/infer/
  INDEX.tsv              ;; dep graph + Hβ §infer_substrate cite per chunk
  state.wat              ;; Tier 4 — module-level scratchpads + $infer_init
  scheme.wat             ;; Tier 5 — Scheme record + instantiate + generalize
  ty.wat                 ;; Tier 5 — Ty constructors + tag conventions + chase_deep
                         ;;          (shared with Hβ.lower; lands here as the
                         ;;          earlier consumer)
  reason.wat             ;; Tier 5 — Reason record constructors per src/types.nx
                         ;;          canonical ADT (23 variants, tags 220-242):
                         ;;          Declared, Inferred, Fresh, OpConstraint,
                         ;;          VarLookup, FnReturn, FnParam, MatchBranch,
                         ;;          ListElement, IfBranch, LetBinding, Unified,
                         ;;          Instantiation, UnifyFailed, Placeholder,
                         ;;          BinOpPlaceholder, MissingVar, Refinement,
                         ;;          Located, InferredCallReturn,
                         ;;          InferredPipeResult, FreshInContext,
                         ;;          DocstringReason.
                         ;;          Payloads carrying Ty/Span/Predicate/BinOp
                         ;;          are stored as opaque i32 pointers per the
                         ;;          verify.wat precedent (verify.wat:39 stores
                         ;;          predicate as opaque ptr); ty.wat /
                         ;;          parser substrate fill them in later.
  unify.wat              ;; Tier 6 — $unify + $unify_shapes + $unify_row_dispatch +
                         ;;          $reify_node + $unify_sub
  walk_expr.wat          ;; Tier 7 — $infer_expr + per-variant arms
  walk_stmt.wat          ;; Tier 7 — $infer_stmt + FnStmt + LetStmt + ImportStmt
                         ;;          arms
  own.wat                ;; Tier 7 — ownership inline helpers
                         ;;          ($infer_ref_escape_push/pop/check)
  emit_diag.wat          ;; Tier 6 — diagnostic emission helpers
                         ;;          ($render_ty + 11 $infer_emit_*
                         ;;          helpers covering every E_/T_ code
                         ;;          canonical src/infer.nx emits per
                         ;;          ROADMAP §4 closure: type_mismatch,
                         ;;          missing_var, occurs_check,
                         ;;          feedback_no_context,
                         ;;          handler_uninstallable,
                         ;;          pattern_inexhaustive, over_declared,
                         ;;          not_a_record_type, record_field_extra,
                         ;;          record_field_missing,
                         ;;          cannot_negate_capability)
  main.wat               ;; Tier 8 — top-level orchestrator $infer_program
                         ;;          (called from seed's pipeline between parse
                         ;;          + lower)
```

10 chunks. Total ~3000-5000 WAT lines (estimate per spec 04 + src/infer.nx
2193 lines projected to WAT — typical 1.5-2.5× line ratio for WAT
vs Inka source).

### 8.2 Layer extension

Update `bootstrap/build.sh` CHUNKS[] to add a Layer 4 between
existing Layer 3 (parser_*) and the as-yet-nonexistent Layer 4
emitter (which will move to Layer 5):

```bash
  # ── Layer 3: Parser ──
  ...

  # ── Layer 4: Inference (NEW per Hβ.infer-substrate.md) ──
  "bootstrap/src/infer/state.wat"
  "bootstrap/src/infer/reason.wat"
  "bootstrap/src/infer/ty.wat"
  "bootstrap/src/infer/scheme.wat"
  "bootstrap/src/infer/emit_diag.wat"
  "bootstrap/src/infer/unify.wat"
  "bootstrap/src/infer/own.wat"
  "bootstrap/src/infer/walk_expr.wat"
  "bootstrap/src/infer/walk_stmt.wat"
  "bootstrap/src/infer/main.wat"

  # ── Layer 5: Lower (NEW per Hβ-lower-substrate.md — pending) ──
  ;; (intentionally empty until Hβ.lower walkthrough lands)

  # ── Layer 6: Emitter (existing emit_*.wat) ──
  ...
```

### 8.3 Per-chunk cross-cutting WABT verification

Per Morgan: WABT tools welcome along the way.

After each chunk lands:
```bash
bash bootstrap/build.sh                     # assemble + wat2wasm
wasm-validate bootstrap/inka.wasm           # structural validation
bash bootstrap/first-light.sh                # lexer proof-of-life unchanged
wasm-objdump -x bootstrap/inka.wasm | grep '<infer_'   # confirm new fns present
wasm-decompile bootstrap/inka.wasm | sed -n '/function infer_<...>/,/^}/p'
                                              # spot-check decompiled body matches design
```

After unify.wat:
```bash
;; Build a tiny test harness in Inka (or hand-WAT temp_test.wat)
;; that calls $unify with known inputs and inspects $graph_chase
;; afterward. Run via wasmtime --invoke.
```

### 8.4 Estimated scope per chunk

| Chunk | Lines (target) | Spec source |
|-------|---------------|-------------|
| state.wat | ~80 | this walkthrough §1 |
| reason.wat | ~280-320 | spec 02 + spec 08 + src/types.nx canonical 23-variant Reason ADT (constructor + accessors per variant ≈ 12-14 WAT lines × 23 variants; revised 2026-04-26 per Wave 2.E.infer.reason substrate-gap finding — earlier 9-named undercount yielded ~150 estimate; canonical reality is 23 variants) |
| ty.wat | ~430 | spec 02 + this walkthrough §2.3 (revised 2026-04-26 from ~400 per 14th variant TAlias + 3 ResumeDiscipline sentinel constructors) |
| scheme.wat | ~250 | spec 04 §Env+Scheme + this §2 |
| emit_diag.wat | ~960 | spec 04 §Error handling + docs/errors (revised 2026-04-26 ROADMAP §4 — extended from earlier ~200 estimate per Wave 2.E.infer.emit_diag canonicalization: 11 helpers covering every E_/T_ code canonical src/infer.nx emits, including newly-cataloged E_NotARecordType / E_RecordFieldExtra / E_RecordFieldMissing / E_CannotNegateCapability) |
| unify.wat | ~700 | spec 04 §Unification + spec 01 §Unification rules |
| own.wat | ~280-340 | spec 04 §Ownership + spec 07 + emit_diag.wat:189-195 contract (OwnershipViolation diagnostic helper lands here per ROADMAP §4 closure pattern; revised 2026-04-26 from ~150 per affine ledger + branch protocol + 3 emit helpers + ledger substrate landing in one commit) |
| walk_expr.wat | ~1500 | spec 03 + spec 04 §What the walk produces (revised 2026-04-26 per Wave 2.E.infer.walk_expr landing — header+forbidden-patterns block + 22 per-Expr-variant arms + 5 PipeKind sub-arms + 12 private helpers + 29 data-segment Reason-inner strings; landed 1523 lines vs. earlier ~900 estimate; the ~600-line overshoot is per-arm verbosity around Reason composition and TFun construction at CallExpr / LambdaExpr / FieldExpr / PForward, plus the explicit dispatch-by-tag chain in $infer_walk_expr) |
| walk_stmt.wat | ~400 (landed 713 incl. ~280-line header per Wave 2.E.infer.walk_stmt commit; 12 public exports — Stmt-tag dispatch over parser tags 120-128 + LetStmt/FnStmt fully wired + 5 inert seed-stubs per named follow-ups + closure of walk_expr.wat:824 BlockExpr §13.3 #9 forward-decl) | spec 03 + spec 04 |
| main.wat | ~150 | this walkthrough §10 + Hβ-bootstrap §1.16 |
| **TOTAL** | **~4900** | (revised 2026-04-26 from ~4300 per walk_expr.wat overshoot) |

Per Hβ §13 estimate (50-150k lines total): ~3380 is the inference
contribution; comparable order to lowering (Hβ.lower) and emit
(Hβ.emit) per their respective walkthroughs.

---

## §9 Worked example — `fn double(x) = x + x`

Per spec 04 §What the walk produces, step-by-step trace through
the inference pass.

### 9.1 Input AST

After parser produces:
```
FnStmt {
  handle: 1,
  name: "double",
  params: [ Param { name: "x", handle: 2 } ],
  body: BinOpExpr {
    handle: 3,
    op: "+",
    left:  VarRef { name: "x", handle: 4 },
    right: VarRef { name: "x", handle: 5 }
  }
}
```

5 graph handles allocated by parser as NFree.

### 9.2 Inference trace

```
$infer_fn_stmt(FnStmt):
  $infer_fn_stack_push(handle=1)
  $env_scope_enter()
  ;; declare "x" in scope at handle 2 (param binding, monomorphic)
  $env_extend("x", $scheme_make_forall([], $ty_make_var(2)))
  ;; walk body
  $infer_expr(BinOpExpr):
    $infer_binop(BinOpExpr):
      $infer_expr(VarRef "x" handle=4):
        $env_lookup("x") → Forall([], TVar(2))
        instantiate → TVar(2) (no quantified handles to fresh-rewrite)
        $graph_bind(4, TVar(2), VarLookup("x", ...))
      $infer_expr(VarRef "x" handle=5):
        ;; same as above
        $graph_bind(5, TVar(2), VarLookup("x", ...))
      ;; "+" requires both sides TInt and produces TInt
      $graph_bind(4, TInt, OpConstraint("+", ..., Declared("int")))
        ;; chase 4 → currently TVar(2); unify TVar(2) with TInt
        ;; unify(2, fresh_h_for_int=null, ...) → graph_bind(2, TInt, ...)
        ;; (substrate detail: $graph_bind on already-bound 4 calls
        ;;  unify_shapes(TVar(2), TInt) → unify(2, ..., TInt))
      $graph_bind(5, TInt, OpConstraint("+", ...))
        ;; same — 5 chases to TVar(2); already TInt now; trivial unify
      $graph_bind(3, TInt, OpConstraint("+", ...))
  ;; generalize fn body
  $generalize(handle=1):
    body_ty = chase_deep($graph_chase(1))  ;; TFun([TParam("x", TInt, _)], TInt, EfPure)
                                            ;; wait — handle 1 is the fn; need to build
                                            ;; the TFun shape from params + body inference
    ;; (spec 04 walks the params + return + row to assemble TFun)
    body_free = []  ;; everything is TInt now; no free handles
    Forall([], TFun([TParam("x", TInt, _)], TInt, EfPure))
  $infer_fn_stack_pop()
  $env_scope_exit()  ;; "x" goes out of scope
  $env_extend("double", scheme)  ;; outer scope picks up the FnStmt name
```

### 9.3 Resulting graph state

| Handle | NodeKind | Reason |
|--------|----------|--------|
| 1 | NBound(TFun([TParam("x", TInt, ...)], TInt, EfPure)) | Generalized |
| 2 | NBound(TInt) | OpConstraint("+", ...) propagated via unify |
| 3 | NBound(TInt) | OpConstraint("+", ...) |
| 4 | NBound(TVar(2)) → chases to TInt | VarLookup |
| 5 | NBound(TVar(2)) → chases to TInt | VarLookup |

Trail length = 5 binds + occasional fresh handle entries for the
internal unification's reify intermediate handles.

`$graph_chase(1)` returns the TFun NBound — the fully-inferred
type for `double`. Hβ.lower (sibling walkthrough) reads this via
$graph_chase to construct LowIR.

### 9.4 What this trace exercises

- Every primitive in §6 (graph + handler — implicit via chase
  dispatch + verb — implicit via `+` lowering + row — EfPure
  stays Pure + ownership — params are inferred without `own/ref`
  here + refinement — N/A + gradient — Forall([], ...) is
  monomorphic + Reason — every bind carries it)
- Every chunk in §8 (state init, reason construction, ty + scheme
  manipulation, unify dispatch, walk arms)
- The Hazel productive-under-error pattern — even if `+` had
  failed (e.g., x bound to TString), would emit + bind NErrorHole
  + continue

---

## §10 Composition with Hβ.lex / Hβ.parse / Hβ.lower / Hβ.emit

### 10.1 Hβ.infer × Hβ.lex

Independent. Lexer produces tokens → parser produces AST → inference
walks AST. The lexer/parser interface is the AST type tags; inference
reads them.

### 10.2 Hβ.infer × Hβ.parse

Coordinated tag conventions. Parser allocates handles via
`$graph_fresh_ty` per AST node; inference walks those handles. AST
variant tags (CONST_TAG, VARREF_TAG, etc.) are SHARED — defined once
in a shared header chunk OR in `bootstrap/src/infer/ty.wat` since
inference is the first consumer.

Per Anchor 7 cascade discipline: when Hβ.parse extension lands per
BT.A.0 finding, the AST tag conventions get locked in coordination
with this walkthrough's expectations.

### 10.3 Hβ.infer × Hβ.lower

The CLEAN handoff. Inference produces typed AST + populated graph;
lower reads via $graph_chase. Per spec 05 (lower) + sibling
Hβ-lower-substrate.md (pending):

- Lower's `$lookup_ty(h)` is exactly `$graph_chase(h)` (Tier-3 base
  + the transitive walk through TVar/EfOpen that lands here).
- Lower's `$row_is_ground(row)` calls $row_is_pure or $row_is_closed
  from row.wat.
- Lower's monomorphic-vs-polymorphic dispatch reads inferred row
  via $graph_chase + $row_is_ground; no infer-side flag set.

Per spec 04 §Monomorphism: "monomorphism is a graph read, not a
sidecar" — inference doesn't tag call sites; lower derives.

### 10.4 Hβ.infer × Hβ.emit

Indirect (via Hβ.lower). Emit reads LowIR; LowIR was lowered from
the post-infer graph; infer never directly produces emit input.

### 10.5 Hβ.infer × cont.wat (H7)

When the wheel ships sibling Synth handlers (post-L1, per H7 §2.5),
those handlers compose ON inference's graph + chase — they speculate
via $graph_push_checkpoint, run inference per candidate, accept on
success, rollback on failure. The seed's inference is the substrate
the oracle uses; infer doesn't fork itself.

---

## §11 Acceptance criteria

### 11.1 Type-level acceptance (Hβ.infer substrate lands)

- [ ] `bootstrap/src/infer/` directory exists with 10 chunks per §8.1.
- [ ] `bootstrap/src/infer/INDEX.tsv` declares each chunk's tier +
      Hβ.infer-substrate.md cite + exports + uses.
- [ ] `bootstrap/build.sh` CHUNKS[] includes the infer chunks in
      Layer 4 position (between Layer 3 parser + Layer 5 lower).
- [ ] `wat2wasm bootstrap/inka.wat` succeeds.
- [ ] `wasm-validate bootstrap/inka.wasm` passes.
- [ ] `wasm-objdump -x bootstrap/inka.wasm | grep '<infer_'` lists
      $infer_init, $unify, $infer_expr, $infer_stmt, $generalize,
      $instantiate (at minimum).

### 11.2 Functional acceptance (per-program tests)

- [ ] Inferring `fn double(x) = x + x` produces the graph state in
      §9.3 (verifiable via test harness invoking $infer_fn_stmt +
      reading $graph_chase on each handle).
- [ ] Inferring `fn id(x) = x` produces `Forall([qid], TFun([qid], qid, EfPure))`
      where qid is one quantified handle.
- [ ] Inferring a deliberately-mistyped program (`fn bad() = "s" + 1`)
      emits `E_TypeMismatch` AND continues (NErrorHole on the
      offending node; FnStmt body continues).

### 11.3 Self-compile acceptance (Hβ.infer in service of L1)

- [ ] `cat src/verify.nx | wasmtime run bootstrap/inka.wasm` produces
      WAT that wasm-validates after linking (currently src/verify.nx
      is the single VALIDATES file per BT.A.0 — this is the regression
      test that infer doesn't break it).
- [ ] `cat src/graph.nx | wasmtime run bootstrap/inka.wasm` produces
      non-degenerate WAT (tracking improvement against BT.A.0 baseline
      of 34 lines / undefined locals).

### 11.4 Drift-clean

- [ ] `bash tools/drift-audit.sh bootstrap/src/infer/*.wat` exits 0.
      (Note: drift-audit currently scans `.nx`; an extension to scan
      `.wat` for foreign-language drift markers is a named follow-up
      of this walkthrough.)

### 11.5 Trace-harnesses landed (ROADMAP §5 closure addendum, 2026-04-26)

The aspirational §11.2 functional-acceptance test "harness invoking
$infer_fn_stmt + reading $graph_chase on each handle" depends on
walk_stmt.wat which is pending. The closer projection of §11.2 onto
helpers that DO exist landed per ROADMAP §5 as eight standalone WAT
trace-harnesses under `bootstrap/test/infer/`:

  - `scheme_monomorphic.wat` — §2.4 empty-quantification short-circuit
  - `scheme_polymorphic.wat` — §2.3 algorithm box (Forall([qid], _))
  - `scheme_free_in_ty.wat` — 14-arm $free_in_ty walker
  - `scheme_ty_substitute.wat` — 14-arm $ty_substitute walker
  - `scheme_subst_map.wat` — substitution-map trio
  - `scheme_recursion_parity.wat` — ROADMAP §3 closure proof
  - `emit_diag_render_ty.wat` — 14-arm $render_ty walker
  - `emit_diag_emit_helpers.wat` — all 11 $infer_emit_* helpers

Per the user's framing locked in the dispatch plan: harnesses ARE the
prose-made-executable, NOT a test framework. Each harness is one
walkthrough paragraph turned into a runnable WAT program with PASS/FAIL
on stderr; `bootstrap/test.sh` is the runner; WABT toolchain at full
leverage (wat2wasm + wasm-validate + wasm-objdump + wasmtime).

Functional acceptance §11.2 #1 (`fn double(x) = x + x` end-to-end) and
§11.2 #3 (deliberately-mistyped program continues per Hazel pattern)
both depend on walk_stmt.wat + walk_expr.wat which remain pending. They
are named follow-ups of this trace-harness commit, NOT silently
deferred substrate.

In the course of executing the harnesses three substrate concerns
surfaced and were closed in the same commit per Anchor 2 (don't patch;
restructure):

  1. emit_diag.wat data segments had 16 length-prefix mismatches
     (declared length ≠ actual payload bytes). Fixed by correcting
     each declared `\xx` byte to match the literal payload length.
  2. emit_diag.wat data segments had 4 byte-region overlaps where a
     later segment's start offset fell inside the previous segment's
     declared payload range. Fixed by relocating the four conflicting
     segments to safe offsets above 2853 (`, found ` → 2864,
     `pattern inexhaustive` → 2880, ` where ...` → 2912, `<` → 2928)
     and updating the four call-site `i32.const` references.
  3. emit_diag.wat helpers were calling `$graph_bind(handle,
     $node_kind_make_nerrorhole(reason), reason_chain)`, but
     `$graph_bind` wraps its second arg in `NBound` regardless — so
     handles ended up bound to `NBound(NErrorHole(...))` instead of
     `NErrorHole(...)`. Closed by adding `$graph_bind_kind` to
     graph.wat (which takes a pre-constructed NodeKind and stores it
     directly without wrapping) and updating all 10 emit-helper call
     sites in emit_diag.wat to use the new primitive.

These three closures are named here so future readers see the
trace-harness substrate value in surfacing real misuses rather than
just symbol-presence checks (the ROADMAP §5 acceptance language —
"validation covers behavior, not just symbol presence" — at work).

---

## §12 Open questions — pre-resolved + named follow-ups

| Question | Resolution |
|----------|-----------|
| Tag values for Ty variants — coordinate with Hβ.lower? | Yes — §2.3 names provisional values; lock in coordination with Hβ.lower walkthrough. |
| Does scheme.body's TVar quantification get fresh-handles via $graph_fresh_ty per instantiation? | Yes — per spec 04 §Instantiations + this §2.3. Rapid graph growth at instantiation sites is per-design. |
| Monomorphic restriction or generalization at `let`? | Per spec 04 §What the walk produces + Damas-Milner: generalize at FnStmt; let-bound is monomorphic unless explicitly annotated. |
| Cross-module instantiation? | Per spec 00 overlay semantics — graph chase walks the overlay graph; infer composes naturally. (Single-module Tier-3 base in this walkthrough; overlay-aware infer is the named follow-up alongside graph.wat overlay primitives.) |
| AST variant tag conventions — where defined? | In `bootstrap/src/infer/ty.wat` + a shared comment block per Hβ.parse coordination. |
| Performance — is $env_lookup's linear scan fast enough? | Tier-3 base. Hash-map env is the named follow-up if profiling shows hot. |

### Named follow-ups (Hβ.infer extensions)

- **Hβ.infer.overlay** — overlay-aware $env_lookup + cross-module
  scheme resolution. Lands alongside graph.wat overlay primitives.
- **Hβ.infer.synth** — Synth handler composition (per H7 §5.1)
  using cont.wat + graph_push_checkpoint/rollback; speculative
  inference at `??` holes.
- **Hβ.infer.row-normalize** — $row_normalize per spec 01 §Normal
  form (Neg via De Morgan + Sub expansion + Inter normal form).
- **Hβ.infer.refinement-compose** — `$verify_record` integration
  with $unify_shapes' TRefined arm calling PAnd(p, q) per spec 04.

- **Hβ.infer.region-tracker** — H4.1 Tofte-Talpin region_tracker
  handler substrate (src/own.nx:199-295). Lands when Hβ.lower's
  Alloc surface matures (the helpers tag allocations; allocation-
  handle stamping is the gating substrate). NOT a drift-mode-9
  deferral: walk arms calling the affine_ledger projects HAVE full
  coverage when own.wat commits; region_tracker is parallel concern.

- **Hβ.infer.used-binary-search** — own.wat's $infer_consume_seen
  uses linear scan over the sorted name list; profiling-driven
  upgrade to binary search lands when seed compile-of-self profile
  shows ownership-set membership hot.

- **Hβ.infer.used-sites-deque** — own.wat's $own_used_sites_push
  uses shift-right insert at index 0 (O(N) per push). For realistic
  function bodies (~tens of own params) this is fine; deque
  substrate is the named upgrade.

- **Hβ.infer.handler-stack** — walk_expr.wat's $walk_expr_inf_push_handler
  / _pop_handler are inert seed-stubs. Wheel's inf_push_handler /
  inf_pop_handler (src/infer.nx:127-138) tag the handler-stack frame
  with handled-effect identity for W4 monomorphic-dispatch. Lands when
  W4 evidence-reification surface matures.

- **Hβ.infer.walk_pat** — Pat dispatch (PVar / PCon / PTuple / PList /
  PRecord / PWild / PLit per spec 03 + src/infer.nx:1587-1655) called
  from walk_expr.wat's MatchExpr arm. Lands as peer Tier 7 chunk before
  walk_stmt.wat (let-stmts also use patterns).

- **Hβ.infer.match-exhaustive** — exhaustiveness check
  (src/infer.nx:1709-1718) omitted at the seed; uses the already-
  landed $infer_emit_pattern_inexhaustive helper from emit_diag.wat.
  Requires ConstructorScheme(_, total_variants) reads from env, which
  in turn requires the walk_pat chunk.

- **Hβ.infer.named-record-validate** — check_nominal_record_fields
  (src/infer.nx:1397-1450) omitted at the seed's NamedRecordExpr arm;
  uses already-landed $infer_emit_record_field_extra / _missing
  helpers. Requires RecordSchemeKind reads from env-binding.kind.

- **Hβ.infer.iterative-context** — walk_expr.wat's PFeedback arm
  pessimistically emits feedback-no-context unconditionally; lands
  when Clock/Tick/Sample handler-stack-walk substrate matures
  (depends on Hβ.infer.handler-stack).

- **Hβ.infer.qualified-name** — FieldExpr's dotted-name fallback
  (src/infer.nx:710-722). Seed's walk_expr.wat treats every FieldExpr
  as record field access; the qualified-name path lands when driver
  composition surfaces dotted module-export names in env.

- **Hβ.infer.lambda-params** — walk_expr.wat's LambdaExpr arm builds
  TFun([], TVar(body_h), row_h) at the seed. Wheel's mint_params
  (src/infer.nx:724-740) walks each parser-emitted Param record and
  extends env via env_extend. Lands once parser surfaces the Param
  record's offset convention.

- **Hβ.infer.unaryop-class** — walk_expr.wat's UnaryOpExpr arm treats
  every op as default (TVar transparent). Wheel's infer_unaryop
  (src/infer.nx:1574-1583) special-cases "Neg" / "Not" via str_eq.
  Lands when the seed has data-segment-resident "Neg" / "Not"
  constants (or, preferably, when parser surfaces UnaryOp as ADT
  sentinels per drift-mode-8 closure).

- **Hβ.infer.docstring-reason** — Documented Stmt arm absent (parser
  doesn't emit Documented today; lands pre-DS.3). Affects walk_stmt.wat
  more than walk_expr.wat, but $reason_make_docstringreason from
  reason.wat is already landed for caller use.

---

## §13 Dispatch + sub-handle decomposition

### 13.1 Authoring

This walkthrough: Opus inline (this commit).

### 13.2 Substrate transcription

Per Hβ §8 dispatch: bootstrap work needs Opus-level judgment + WAT
fluency + per-handle walkthrough reading.

**Per-chunk dispatch:**

| Chunk | Dispatch | Rationale |
|-------|----------|-----------|
| state.wat | Opus inline OR Sonnet via inka-implementer w/ this §1 as plan | small; mechanical |
| reason.wat | Opus inline OR Sonnet | constructors per spec 08; mechanical |
| ty.wat | Opus inline | tag conventions need design judgment + Hβ.lower coordination |
| scheme.wat | Opus inline | instantiate / generalize semantics non-trivial |
| emit_diag.wat | Opus inline OR Sonnet | report-effect arms; mostly mechanical |
| unify.wat | **Opus inline only** | unify_shapes dispatch table is the load-bearing center; subtle correctness |
| own.wat | Opus inline | ownership semantics need spec 07 reading |
| walk_expr.wat | Opus inline | per-AST-variant walk; large but each arm is direct |
| walk_stmt.wat | Opus inline | similar |
| main.wat | Opus inline OR Sonnet | orchestrator; calls infer_stmt over toplevel list |

### 13.3 Sub-handle order

Per dependency:

1. **state.wat** (no deps)
2. **reason.wat** (no deps beyond record.wat)
3. **ty.wat** (deps: record.wat + this §2.3 tag conventions)
4. **scheme.wat** (deps: ty.wat + record.wat + list.wat)
5. **emit_diag.wat** (deps: ty.wat + reason.wat + str.wat)
6. **unify.wat** (deps: graph.wat + ty.wat + emit_diag.wat + verify.wat)
7. **own.wat** (deps: state.wat + row.wat + env.wat)
8. **walk_expr.wat** (deps: all above + env.wat)
9. **walk_stmt.wat** (deps: walk_expr.wat + scheme.wat + env.wat)
10. **main.wat** (deps: walk_stmt.wat)

### 13.4 Per-handle landing discipline

Each chunk lands per Anchor 7:
- Walkthrough cite (this file's §) in chunk header
- Dependencies declared in INDEX.tsv
- WABT verification post-commit (wat2wasm + wasm-validate +
  $infer_*-grep + first-light.sh non-regression)
- Drift-audit clean
- Eight interrogations clear (per §6)
- Forbidden patterns audited (per §7)

---

## §14 Closing

Hβ.infer is the layer that doesn't exist in the current seed. Per
BT.A.0 sweep: 35/50 src/*.nx files PARSE-INCOMPLETE because the
seed handles imports as identifier-expressions; per Hβ §11
finding: graph.nx → 34 lines degenerate WAT. The path past this
state is implementing HM inference at the WAT layer.

This walkthrough projects spec 04 + src/infer.nx onto the Wave
2.A–D Layer-1 substrate. **The substrate exists; the contract is
written; what remains is transcription per the §8 chunk
decomposition.**

Per insight #11 (oracle = IC + cached value): once Hβ.infer
substrate lands, the seed becomes capable of HM-inferring src/*.nx;
the wheel compiled from that substrate hosts Mentl's oracle on top.
**Hβ.infer is the substrate that makes the wheel possible; the
wheel is the substrate that makes Mentl's continuous oracle real.**

Per Anchor 4 + Anchor 7 + Hβ §0: the wheel is `src/*.nx` (10,629
lines of substantively-real Inka per plan §16); this walkthrough's
substrate is its seed transcription; both kept forever (the seed
as reference soundness artifact per Hβ §0; the wheel as the
canonical implementation).

**One walk. Three operations. Four production patterns. Ten
chunks.** The HM inference layer of the seed, named in writing,
ready to transcribe.

*Per Mentl's anchor: write only the residue. The walkthroughs
already say what the medium IS. This walkthrough is the residue
between Hβ-bootstrap.md's `§1.2 Graph substrate` named-as-
foundation + spec 04's HM-inference-as-algorithm + the Wave 2.A–D
substrate-just-landed. The next residue is per-chunk WAT
transcription; transcribers cite this walkthrough's §s.*
