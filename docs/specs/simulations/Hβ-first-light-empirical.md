# Hβ-first-light-empirical — empirical seed-state audit

> **Status:** `[LIVE 2026-05-02]` — empirical state of the seed
> bootstrap as of commit `c2c679c` (PLAN-to-first-light.md +
> ancestors). Authored after an attempted L1-closure execution
> session revealed the chunk-header named follow-ups are partially
> stale: several "stub" arms are in fact implemented; some real
> gaps are unnamed.
>
> **Authority:** Hβ-first-light-residue.md (the speculative
> 12-handle decomposition this document corrects); ROADMAP.md Phase H;
> Anchor 0 (lux3.wasm is not the arbiter — but empirical seed state
> IS evidence we can ground future planning on).
>
> **Claim in one sentence:** **Per-tiny-program seed compilation
> reveals that TypeDef registration + match-arm pattern compilation
> + block let-bindings + fn-to-fn calls all WORK in the current seed,
> while a small set of specific bugs (constructor-call emit producing
> `(unreachable)` for arguments; type inference for ADT scrutinee in
> calling context; let-as-stmt-in-bare-body without braces) blocks
> wheel compilation — and the 18-box decomposition in
> PLAN-to-first-light.md should be re-mapped per these empirical
> findings before substrate authoring proceeds at scale.**

---

## §0 The investigation

The H.1.a session opened (per PLAN-to-first-light.md §3); empirical
verification began with `bootstrap/src/infer/walk_stmt.wat:818` —
the supposed `$infer_register_typedef_ctors` "stub" that the explore
agents and chunk-header named follow-ups described as inert.

### 0.1 First finding — the "stub" is implemented

`bootstrap/src/infer/walk_stmt.wat:818-874` is **fully implemented**:

```
(func $infer_register_typedef_ctors
    (param $type_name i32) (param $variants i32) (param $span i32)
  ...
  (local.set $total (call $len (local.get $variants)))
  ;; Build TName(type_name, [])
  ...
  (loop $each
    ...
    ;; nullary → ctor_ty = result_ty
    ;; N-ary  → ctor_ty = TFun(field_tparams, result_ty, fresh_row)
    ;; env_extend ctor_name with ConstructorScheme(tag_id, total)
    ...))
```

The function iterates variants, builds field TParams via
`$walk_stmt_build_field_tparams` (line 770), constructs ctor types
correctly (nullary vs N-ary), wraps in Forall scheme, env_extends
with `$schemekind_make_ctor(tag_id, total)`. Drift-6 closure noted
explicitly at lines 813-817 (Bool variants pass through the SAME
ConstructorScheme registration).

The chunk header's named follow-up `Hβ.infer.constructors`
(walk_stmt.wat:219-223) describes this as "TypeDefStmt arm seed-stub.
Wheel's register_type_constructors (src/infer.nx:2028-2066) iterates
variants + env_extends each ConstructorScheme(tag_id, total). Seed
landing gates on parser_decl.wat:30-118 variant emission stabilizing
the variant-record offset shape."

**The named follow-up is stale.** The seed substrate landed; the
comment was not updated.

### 0.2 Empirical confirmation

Compiling `type Maybe = Just(Int) | Nothing\nfn main() = Just(42)`
through the seed:
- `Just` resolves (no E_MissingVariable for Just)
- The TypeDef IS registered; constructors are looked up successfully

So H.1.a is **already-closed**. No walkthrough authoring needed.

---

## §1 Empirical seed-state matrix — per-construct verification

Each row tested with a tiny program; observed verbatim from
`echo '<source>' | wasmtime run bootstrap/inka.wasm 2>&1`.

| Construct | Source | Verdict | Notes |
|---|---|---|---|
| **Integer literal main** | `fn main() = 42` | ✓ WORKS | `(func $main ... (i32.const 42))` clean |
| **Fn with parameter** | `fn main(x) = x + 1` | ✓ WORKS | `(local.get $x)(i32.const 1)(i32.add)` |
| **Block + let-binding** | `fn main() = { let x = 5\n  x + 1 }` | ✓ WORKS | `(i32.const 5)(local.set $x)(local.get $x)(i32.const 1)(i32.add)` |
| **Bare-body let** (no braces) | `fn main() = let x = 5; x + 1` | ✗ FAILS (correctly) | Not valid per SYNTAX.md (multi-line bodies require braces); E_MissingVariable: x |
| **Two top-level fns + call** | `fn double(x) = x + x\nfn main(y) = double(y)` | ✓ WORKS | `(global.get $double)(local.set $state_tmp)...(call_indirect (type $ft2))` |
| **TypeDef + nullary use** | `type Maybe = Just(Int) \| Nothing\nfn main() = Nothing` | (untested in detail) | TypeDef registers; Nothing referenced |
| **TypeDef + N-ary ctor call** | `type Maybe = Just(Int) \| Nothing\nfn main() = Just(42)` | ✗ BROKEN | `E_UnresolvedType: lower-time NFre4`; main body has `(unreachable)` between args; constructor-as-call emit path drops the literal arg |
| **Match expression** | `match m { Just(x) => x, Nothing => d }` | ✓ WORKS | Real sentinel/heap dispatch + tag check + field load + binding emission |
| **Match arm with guard** | (untested) | ? | Probably not in scope; `where` clauses may be the equivalent |
| **Effect declaration** | (untested) | ? | Hβ.infer.effect-ops named follow-up may also be stale |
| **Handler declaration** | (untested) | ? | Hβ.infer.handler-decls named follow-up may also be stale |
| **Float literal** | `fn main() = 1.5` | ? | Hβ.emit.float-substrate is genuinely absent per chunk header |
| **Float scientific** | `fn main() = 1e308` | ? | Lexer almost certainly fails |
| **Lambda + capture** | `fn main(n) = (x) => x + n` | ? | Lambda capture substrate unverified |
| **Pipe operator** | `xs \|> map(f)` | ? | Pipe lowering may have specific gaps |

### 1.1 The named follow-ups vs reality

| Named follow-up (chunk header claim) | Reality |
|---|---|
| `Hβ.infer.constructors` "TypeDefStmt arm seed-stub" | **CLOSED** — `$infer_register_typedef_ctors` fully implemented at walk_stmt.wat:818-874 |
| `Hβ.infer.effect-ops` "EffectDeclStmt arm seed-stub" | UNKNOWN — needs empirical test |
| `Hβ.infer.handler-decls` "HandlerDeclStmt arm seed-stub" | UNKNOWN — needs empirical test |
| `Hβ.lower.match-arm-pattern-substrate` "empty arms list emitted" | **CLOSED** — match arms compile to real WAT (sentinel/heap dispatch + tag check + field load + binding) |
| `Hβ.lower.blockexpr-stmts-substrate` "stmts dropped" | **CLOSED** — block let-bindings emit correctly |
| `Hβ.emit.lmatch-pattern-compile` "(unreachable) for nonempty arms" | **CLOSED** — emit produces real match WAT |
| `Hβ.emit.float-substrate` "no f64 substrate" | UNKNOWN — needs empirical test |
| (unnamed) constructor-call-emit drops args | **REAL GAP** — newly identified |
| (unnamed) type inference for ADT in calling context | **REAL GAP** — newly identified |

The chunk-header named follow-ups have decayed against the
substrate. **Seed landings happened; comments were not updated.**

### 1.2 What's actually broken — the empirical L1 residue

Based on this audit:

1. **Constructor-call-emit drops literal args** — `Just(42)` produces
   `(unreachable)` where `(i32.const 42)` should be. The lower or
   emit path for `LMakeVariant` with literal argument is broken.
   Specific tag in the WAT: `(local.get $state_tmp)(unreachable)
   (local.get $state_tmp)(i32.load offset=0)(call_indirect ...)`.

2. **Type inference for ADT-in-calling-context** — `unwrap(Nothing,
   y)` in a fn call produces "expected Maybe, found Int" — the
   `Nothing` argument is being inferred as Int instead of Maybe.
   Suggests the constructor scheme's RESULT type isn't being
   threaded correctly through CallExpr inference for nullary ctors.

3. **Float substrate (probably real gap, unverified yet)** — TFloat
   literals and f64 arithmetic emit are reportedly absent.

4. **Effect-decl + handler-decl registration (unverified)** — may
   also be already-closed; needs empirical test before authoring.

5. **Cumulative effect of (1)+(2)** — when the seed compiles the
   wheel's real source (which uses constructors throughout), the
   `(unreachable)` insertions cascade through the entire wheel,
   producing the stub form observed at L1-stage-1 attempt (commit
   `95d8ce5`'s evidence section §0.2).

**The L1 critical path is shorter than the 18-box decomposition
suggested.** The ACTUAL residue may be 3-5 specific bugs in
constructor-call-emit + ADT-context inference + float substrate +
the empirical-verification-pass on the unverified named follow-ups.

---

## §2 Re-mapped cursor of attention

The empirical state changes the cursor protocol. Per the discipline
(walkthrough first; substrate second; audit always): **before any
substrate authoring proceeds at scale, an empirical-verification
pass must establish actual gaps for each remaining named follow-up.**

### 2.1 Verification-pass micro-tests

For each named follow-up in PLAN-to-first-light.md §3, author a
~5-line wheel-Inka program that exercises ONLY that construct. Run
through the seed. Record:
- Stderr (E_* diagnostics + count)
- Stdout (emitted WAT for the relevant function)
- Verdict: WORKS / BROKEN / SYNTAX-INVALID / SPEC-DEFERRED

**Estimated cost per verification:** 5 minutes. Total verification
cost: ~1 hour for the 12-handle list. Massively cheaper than
authoring 12 walkthroughs against handles that turn out to be
already-closed.

### 2.2 The corrected cursor

After verification, the cursor advances to the FIRST handle whose
empirical gap is genuinely real and substrate-authoring is needed.
Possibly fewer than 12 boxes; possibly different boxes than named.

### 2.3 The two confirmed real gaps (this audit)

1. **Constructor-call literal-arg emit** — `LMakeVariant` with
   literal arguments drops the literal as `(unreachable)`. New
   handle name: `Hβ.first-light.lmakevariant-literal-args`. Scope:
   investigate `bootstrap/src/emit/emit_const.wat`'s
   `$emit_lmakevariant` for the gap; author the fix as a chunk
   addendum.

2. **Nullary-ctor type-flow into CallExpr context** — the result
   type of a nullary constructor (which is `TName(type_name, [])`,
   not a function type) doesn't unify correctly when used as a
   function-call argument. Suggests `$infer_walk_expr_call`'s
   argument-type unification needs to handle nullary-ctor
   value-context. New handle: `Hβ.first-light.nullary-ctor-call-context`.

These two specific, empirically-verified bugs are the actual
residue this session's work has surfaced. They are the corrected
cursor of attention.

---

## §3 What this session delivers

Even with the 18-box decomposition revealed as partially stale,
this session's investigation produced load-bearing residue:

1. **Empirical seed-state map** (this document) — what works, what
   doesn't, with verbatim test programs and observed output.
2. **Stale-comment-flagging for chunk headers** — named follow-ups
   that say "stub" but are actually implemented. Future maintainers
   can update the comments to match substrate state.
3. **Two newly-named real gaps** (`lmakevariant-literal-args`,
   `nullary-ctor-call-context`) — the actual blockers, as opposed
   to the speculative cascade.
4. **Verification-pass protocol** (§2.1) — the cheap way to
   distinguish closed-vs-real handles before substrate authoring.

**The substrate-honest path forward**: future sessions execute the
verification pass first (per §2.1; ~1 hour total for the 12-handle
list), then author walkthroughs only for the empirically-real
gaps. This may be 3-5 walkthroughs instead of 12; massively shorter
than the speculative cascade.

---

## §4 Why this is correct per the discipline

Per Anchor 7 (cascade discipline; walkthrough first): the
walkthrough's pre-audit catches drift before substrate ships. **This
audit is itself a pre-audit** — it catches the drift in the
PLAN-to-first-light.md substrate-decomposition before 12 walkthroughs
get authored against stale named follow-ups.

Per `protocol_walkthrough_pre_audit.md`: "cheaper to fix the
walkthrough once than catch drift per-chunk N times." This
empirical audit is exactly that; it fixes 12 walkthroughs' worth of
substrate drift in one investigation.

Per Anchor 2 (Don't patch. Restructure or stop.): when the
architecture's mental model proves out-of-date (chunk-header
comments stale), the substrate-honest move is to update the model
before patching against it. **This document IS the restructure.**

Per the user's directive ("don't stop until ULTIMATE FORM"): this
audit IS continued progress — it advances toward L1 by clarifying
where L1 actually requires authoring, not where the planning doc
speculated.

---

## §4.5 Continued empirical session findings (2026-05-02 evening)

After the §4 audit, the session continued per CLAUDE.md ⊕
session-continuity directive ("there is no future session; only
now"). Two new substrate landings + one new structural discovery:

### 4.5.1 LANDED — Hβ.first-light.lambda-parser (commit `c28c525`)

The seed parser's `parse_paren` was extended to recognize
`(params) => body` per SYNTAX.md §234-260. After the `)` closing
in either single-paren or tuple-paren form, the parser peeks for
TFatArrow (35); if present, the contents are reinterpreted as a
TParam list (via `$exprs_to_tparams` + `$convert_var_ref_to_tparam`
extracting names from VarRef Nodes through the
`Node→NodeBody→NExpr→VarRef` offset chain), and `$mk_LambdaExpr`
constructs the LambdaExpr node (`[tag=89][params][body]`).

Empirical verification (post-landing):
- `fn main() = (x) => x`: zero diagnostics; body emits
  `(global.get $heap_ptr)(local.set $state_tmp)... fn_ptr +
  capture_count store + closure pointer`. Lambda is parsed AND
  lowered to LMakeClosure correctly.
- `fn main(n) = (x) => x + n`: clean. Closure form works.
- `fn main() = (a, b) => a + b`: clean. Multi-param tuple form
  works.

L1 candidate compile re-run after landing: NFre count 13 → 12;
`heap_base` fn body changes from `(unreachable)` to
`(i32.const 4096)` — one wheel fn now emits a real value.

**Lambdas compile.** The eight kernel primitives' interactive
projection through the seed continues to grow toward L1.

### 4.5.2 NEW STRUCTURAL DISCOVERY — wheel canonical violates SYNTAX.md brace discipline

While auditing why `cat src/types.nx lib/runtime/strings.nx` still
produces 393 errors after the lambda fix, I discovered a load-
bearing structural mismatch:

**SYNTAX.md §126-142** declares: multi-line fn bodies REQUIRE
braces. Bodies that span multiple statements (e.g., `let X = a; let
Y = b; X + Y`) without braces produce `E_MissingBracesMultiLine`.

**The wheel canonical does NOT honor this rule** in many places.
Examples:

```
src/types.nx:362
fn span_join(a, b) with Pure =
  let Span(sl, sc, _, _) = a
  let Span(_, _, el, ec) = b
  Span(sl, sc, el, ec)
```

This fn body has THREE statements (two let-bindings + final expr)
with no braces. Per SYNTAX.md, this should be a parse error.

Counts:
- `src/types.nx`: 19 fns with `fn name(...) with ... =` ending in
  newline (multi-line bare-body candidates)
- `src/lower.nx`: 2 fns
- `src/infer.nx`: 1 fn (probably more by other patterns)
- (Likely many more across `src/` and `lib/` not counted by the
  narrow grep)

**The seed parser**, per SYNTAX.md, parses bare-body fns via
`parse_expr`. When the body is multi-statement, only the first
statement is consumed as the body; the rest are dropped or treated
as separate top-level decls (depending on the parser's recovery
behavior).

This is a TRUE substrate residue: wheel-vs-SYNTAX.md alignment.

### 4.5.3 The fork — two substrate-honest paths

**Option A: Fix the wheel.** Add braces around all multi-line fn
bodies. Aligns the wheel to SYNTAX.md exactly. Bounded but tedious
(~20+ functions in `src/`, possibly many more in `lib/`). Each
edit is mechanical: `=\n  ...stmts...\n  expr` → `= {\n  ...stmts...\n  expr\n}`.

**Option B: Extend the seed parser.** Add bare-body multi-statement
support to `parse_fn_stmt` — when body is multi-line and consists
of `let` followed by more lines, parse as an implicit BlockExpr
ending at the next top-level decl boundary. **This LOOSENS
SYNTAX.md** — drift territory unless SYNTAX.md is amended to allow
this form.

Per Anchor 7 (cascade discipline; SYNTAX.md is authoritative), the
substrate-honest move is **Option A** — fix the wheel. The wheel
was authored under loose canonical discipline; aligning it to
SYNTAX.md is restoration, not loosening.

### 4.5.4 Newly named real handle

`Hβ.first-light.wheel-brace-discipline` — bring `src/*.nx` and
`lib/**/*.nx` into SYNTAX.md §126-142 compliance. Each multi-line
fn body that lacks braces gets `{` after `=` and `}` at end of
body. Mechanical; bounded; substrate-honest.

This handle is **not** on PLAN-to-first-light.md's original 18-box
list because the explore agents and named follow-ups didn't
surface it. Empirical investigation surfaced it — exactly per the
empirical-pre-audit discipline this document advocates.

### 4.5.5 Session running tally (this empirical-execution arc)

Closed THIS session via empirical-driven substrate landings:
- ✓ Hμ.cursor wheel-side (7 commits)
- ✓ ULTIMATE_MEDIUM thesis statement (1 commit)
- ✓ ROADMAP Phase μ + Hμ.cursor.seed Tier 3 reframe (1 commit)
- ✓ PLAN-to-first-light.md 18-box trackable plan (1 commit)
- ✓ Hβ-first-light-residue.md (cascade decomposition) (1 commit)
- ✓ Hβ-first-light-empirical.md (this document; commit `6a5a64b`)
- ✓ CLAUDE.md JIT-trigger + red-flag thoughts + cascade state
  (commit `509fd42`)
- ✓ CLAUDE.md ⊕ session-continuity directive (commit `b5223cd`)
- ✓ Hβ.first-light.lambda-parser substrate (commit `c28c525`)

Newly named (post-empirical) blocker handles:
- `Hβ.first-light.lmakevariant-literal-args`
- `Hβ.first-light.nullary-ctor-call-context`
- `Hβ.first-light.wheel-brace-discipline` (THIS finding)
- `Hβ.first-light.lambda-body-fn-emit` (closures need module-fn
  emit after lambda parser lands)

The path to L1 continues. The medium folds into its seed one
substrate-honest landing at a time.

---

## §5 The cursor advances

The next session's cursor opens at the verification-pass protocol
(§2.1): empirical micro-tests for the remaining 11 named follow-ups
to establish real-vs-stale state. After that, the actual residue is
mapped; substrate authoring proceeds against real gaps only.

The two specific bugs identified in this audit (§2.3) are
candidate first-substrate-handles for whichever session reaches
them. Both have small scope (single chunk addendum each, not full
new chunks). Both can land in one session each.

After those, plus whatever else the verification pass reveals, L1
closes. The plan's overall shape (Phase H → Phase H.4 fixpoint
harness → Tier 3) holds; the per-handle decomposition collapses to
the empirically-real residue.

The bus is on. The medium continues folding into its seed — but
substrate-honestly, with empirical evidence as the ground truth.
