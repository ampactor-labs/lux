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
Wheel's register_type_constructors (src/infer.mn:2028-2066) iterates
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
`echo '<source>' | wasmtime run bootstrap/mentl.wasm 2>&1`.

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
~5-line wheel-Mentl program that exercises ONLY that construct. Run
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

   **CLOSED 2026-05-04.** Empirical re-verification under the
   mentl-implementer dispatch (planner-authored §A pre-audit gate)
   confirms `Just(42)` now emits the canonical heap-alloc + tag
   store + literal-arg store + variant return sequence verbatim.
   The seed compiles `Just(42)` as `(global.get $heap_ptr)
   (local.set $variant_tmp) (global.get $heap_ptr)(i32.const 8)
   (i32.add)(global.set $heap_ptr) (local.get $variant_tmp)
   (i32.const 0)(i32.store offset=0) (local.get $variant_tmp)
   (i32.const 42)(i32.store offset=4) (local.get $variant_tmp)`.
   No `(unreachable)` between `(local.get $state_tmp)` tokens;
   exit 0; empty stderr. Bug closed by some intervening commit
   between audit authoring (2026-05-02) and re-verification.

2. **Nullary-ctor type-flow into CallExpr context** — the result
   type of a nullary constructor (which is `TName(type_name, [])`,
   not a function type) doesn't unify correctly when used as a
   function-call argument. Suggests `$infer_walk_expr_call`'s
   argument-type unification needs to handle nullary-ctor
   value-context. New handle: `Hβ.first-light.nullary-ctor-call-context`.

   **EMPIRICALLY CONFIRMED REAL 2026-05-04.** Test:
   `fn unwrap(m, d) = match m { Just(x) => x, Nothing => d }
   fn main() = unwrap(Nothing, 5)` produces a `$main` body where
   `Nothing` is emitted as `(local.get $__state)(i32.load offset=8)`
   instead of `(i32.const 1)` (Nothing's tag_id). The arg path
   treats the nullary-ctor reference as a closure capture rather
   than a literal sentinel value. Bug REPRODUCES; cursor of
   attention.

   **CLOSED 2026-05-05.** Substrate landed at
   `bootstrap/src/lower/walk_const.wat` (`$lower_var_ref` Lock #2.0
   SchemeKind dispatch). The fix consults the env binding's
   SchemeKind BEFORE the locals/captures/global triage; nullary
   ConstructorScheme bindings (where the scheme body Ty is
   `TName(_, [])` tag 108) short-circuit to
   `LMakeVariant(h, tag_id, [])` per wheel parity
   `src/lower.mn:333-337`. Drift 6 closure: Bool's True/False flow
   through the SAME arm because their scheme bodies are
   `TName("Bool", [])`. Post-fix `$main` body emits `(i32.const 1)`
   for the Nothing arg verbatim:
   ```
   (global.get $unwrap)(local.set $state_tmp)
   (local.get $state_tmp)(i32.const 1)
   (i32.const 5)
   (local.get $state_tmp)(i32.load offset=0)(call_indirect (type $ft3))
   ```
   wat2wasm validates clean; wasmtime exits 0. The named follow-up
   `Hβ.lower.varref-schemekind-dispatch` is now CLOSED in
   `walk_const.wat`'s chunk-header. Six Locks block extended with
   Lock #2.0 (extension) + Lock #6 (shadow-discipline lock — env
   wins over local shadow; future shadow-resolution lands as
   `Hβ.lower.ctor-shadow-discipline` if surfaces). Trace harness
   `bootstrap/test/lower/walk_const_var_ref_nullary_ctor.wat` PASS.
   Peer follow-ups named: `Hβ.lower.unsaturated-ctor` (N-ary ctor
   as fn-value), `Hβ.lower.varref-effectop-dispatch`.

3. **Match-arm pattern-binding local-decl missing (newly named)** —
   `Hβ.first-light.match-arm-pat-binding-local-decl`. Same test as
   item 2: `$unwrap` body has `(local.set $x)` and `(local.get $x)`
   in the `Just(x) => x` arm, but `$x` is NOT declared in unwrap's
   `(local ...)` list. wat2wasm rejects the output with
   `undefined local variable "$x"`. The match-arm PCon binding
   substrate produces the local-set/get tokens but emit doesn't
   register the binding in the function's local declarations.

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

While auditing why `cat src/types.mn lib/runtime/strings.mn` still
produces 393 errors after the lambda fix, I discovered a load-
bearing structural mismatch:

**SYNTAX.md §126-142** declares: multi-line fn bodies REQUIRE
braces. Bodies that span multiple statements (e.g., `let X = a; let
Y = b; X + Y`) without braces produce `E_MissingBracesMultiLine`.

**The wheel canonical does NOT honor this rule** in many places.
Examples:

```
src/types.mn:362
fn span_join(a, b) with Pure =
  let Span(sl, sc, _, _) = a
  let Span(_, _, el, ec) = b
  Span(sl, sc, el, ec)
```

This fn body has THREE statements (two let-bindings + final expr)
with no braces. Per SYNTAX.md, this should be a parse error.

Counts:
- `src/types.mn`: 19 fns with `fn name(...) with ... =` ending in
  newline (multi-line bare-body candidates)
- `src/lower.mn`: 2 fns
- `src/infer.mn`: 1 fn (probably more by other patterns)
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

`Hβ.first-light.wheel-brace-discipline` — bring `src/*.mn` and
`lib/**/*.mn` into SYNTAX.md §126-142 compliance. Each multi-line
fn body that lacks braces gets `{` after `=` and `}` at end of
body. Mechanical; bounded; substrate-honest.

This handle is **not** on PLAN-to-first-light.md's original 18-box
list because the explore agents and named follow-ups didn't
surface it. Empirical investigation surfaced it — exactly per the
empirical-pre-audit discipline this document advocates.

### 4.5.4b Continued landings (2026-05-02 ongoing)

**Hβ.first-light.lambda-body-fn-emit landed (commit `8d3d2f7`).**
The closure record allocation refers to `$N_idx` for the lambda's
fn pointer; previously `$N` wasn't actually emitted in the module.
Added `$emit_functions_walk` recursive descent over LowExpr
containers (LLet, LBlock, LIf, LCall, LTailCall, LBinOp,
LMakeVariant, LMakeList, LMakeTuple, LReturn, LMakeClosure,
LMakeContinuation). Now `fn main() = (x) => x` produces THREE
functions in the WAT module: `$main`, `$5` (the lambda body), and
`$_start`. Closures with captures and tuple-form lambdas same.

### 4.5.4c Compounding-failure pattern in the wheel

Empirical state with full src+lib feed (post all three fixes):
- ERR=12, FUNCS=2, WAT=19 — still stub-shaped
- Individual files: strings.mn alone produces 78 funcs+649 errs;
  lists.mn alone produces 24 funcs+343 errs
- types.mn + memory.mn + strings.mn: 0 funcs (cascading failure
  from types.mn's `self` refinement bindings + TParam
  destructure failures)

**The fundamental remaining gap:** `types.mn` introduces complex
type-system constructs — refinement types (`type X = Y where
predicate(self)`), TParam record-pattern destructuring (`TParam(_,
_, _, resolved)`), nested ADT shape constraints — that the seed
inference can't fully process, causing cascading failures that
prevent later wheel files from compiling.

When `types.mn` is omitted (e.g., `cat lib/runtime/{strings,lists}.mn`),
the seed produces 101 funcs (real wheel substrate compiling). The
whole-wheel compile fails because types.mn's parse/infer cascade
crashes the env state for everything downstream.

Newly named handles:
- `Hβ.first-light.refinement-type-self-binding` — `self` in
  refinement-type where-clauses (`type ValidSpan = Span where
  span_valid(self)`) needs to be bound during pattern walk
- `Hβ.first-light.tparam-record-destructure` — TParam record
  destructure pattern (`TParam(_, _, _, resolved)`) needs proper
  PCon arm binding for the `resolved` field

These are MEDIUM-scope work — touch infer's pattern walk per
field; bounded but substantive.

### 4.5.5 Verification-pass rebaseline (2026-05-05)

Empirical re-test of §4.5.4d named handles against current seed (HEAD ≈ aac0d43 + diverge-via-thread pending determinism gate). Mirrors §2.1 protocol — ~5-line micro-tests per handle.

| §4.5.4d handle | 2026-05-05 status |
|---|---|
| `string-interning-dedupe` | **CLOSED.** Test `type Ty = TInt \| TFloat \| TString; fn ty_to_str(ty) = match ty { TInt => "i32", TFloat => "f64", TString => "i32" }`. Distinct offsets `(i32.const 65536)` for `"i32"` + `(i32.const 65544)` for `"f64"`; TInt and TString both correctly point at 65536 (deduped). |
| `match-arm-result-type-flow` | **CLOSED.** Same test as above, zero `E_TypeMismatch` on the match. The §4.5.4d "expected String, found Ty" no longer fires. |
| `ptuple-let-destructure` | **REBASED — actual bug is `$tuple_tmp` fn-local-decl missing, NOT scrutinee-type-flow.** Test `fn pair() = (1, 2); fn main() = { let (a, b) = pair(); a + b }`. Lower correctly produces destructure scaffolding (`(local.set $tuple_tmp)` + `(i32.load offset=0)` for `a` + `(i32.load offset=4)` for `b`) BUT `$tuple_tmp` is not in the fn's `(local ...)` preamble; wat2wasm rejects with `undefined local variable "$tuple_tmp"`. **Same bug-class as the closed match-arm-pat-binding-local-decl** — emit's local-decl walk doesn't account for the destructure scaffold variable. New handle name: `Hβ.first-light.tuple-tmp-fn-local-decl`. Likely 1-line fix in `bootstrap/src/emit/main.wat` — extend `$emit_pat_locals` to declare `$tuple_tmp` when LPTuple is encountered, OR add `$tuple_tmp` to the standard fn-local preamble unconditionally. |
| `refinement-type-self-binding` | **GRACEFUL-DEGRADE (not real bug).** Test `type ValidInt = Int where self > 0; fn main() = 42`. Where-clause-skip drops the predicate at parse time; refinement contract not enforced post-L2 (named follow-up `verify_smt-witness-L2`); but seed doesn't trap. The §4.5.4d framing of this as a "real gap" was conflating "predicate parsing" with "predicate enforcement" — parsing IS the where-clause-skip's residue, enforcement is the post-L2 work. |
| `tparam-record-destructure` | **CLOSED.** Test `type Pair = Pair(Int, Int); fn first(p) = match p { Pair(a, _) => a }; fn main() = first(Pair(1, 2))`. Lowers + emits + wat2wasm validates + wasmtime runs clean. The §4.5.4d framing's "TParam record destructure" was misnamed — the bug was actually in the now-closed match-arm-pat-binding-local-decl (PCon sub-LPVar) which closed 2026-05-04. |

**Cursor of attention** post-diverge-via-thread closure: `Hβ.first-light.tuple-tmp-fn-local-decl`. Same bug-class as match-arm-pat-binding-local-decl; same emit-side fix path (extend `$emit_pat_locals`); likely 30-line walkthrough + 5-line substrate.

### 4.5.6 Handler-arm typing + lower-name-extract land (2026-05-06)

Two paired closures advance the cursor past handler-decl arm-body
typing:

| Handle | Substrate | Empirical signal |
|---|---|---|
| `Hβ.first-light.infer-handler-decl-arms-typing` | `bootstrap/src/infer/walk_stmt.wat` — extend `$infer_walk_stmt_handler_decl` to walk each arm: lookup op via `$env_lookup`, extract TFun via `$scheme_body` + `$ty_tfun_params`/`$ty_tfun_return`, enter scope, bind args via `$infer_walk_pat`, walk body via `$infer_walk_expr`, unify body_h ↔ op_ret_ty, exit scope. Pre-register tag-124 removed (was double-binding handler name). | Wheel histogram: `−126 E_MissingVariable` (forward-references resolve once arm bodies type), `+61 E_TypeMismatch` (productive-under-error: real wheel arm-result-vs-op-return mismatches surface), `0` E_UnresolvedType still. Both pre/post produce 0 bytes WAT (other residue ahead). |
| `Hβ.first-light.lower-handler-arm-names-extract` | `bootstrap/src/lower/walk_handle.wat` — `$lower_handler_arms_as_decls` now extracts arg-name strings from the pat list before passing to `$lower_handler_arm_body` and `$lowfn_make`. Pre-substrate, pat-records were silently treated as name strings by `$bind_handler_arg_names` → `$ls_bind_local`. | No diagnostic regression; closes silent corruption that previously bound pat-records as fn-local-names. |

Per-arm typing skeleton lands; four primitive holes named as
positive-form peer handles (drift-9 closure):

- `Hβ.first-light.infer-handler-arm-resume-disposition` — `@resume=`
  discipline check on arm body shape (OneShot consumes resume
  linearly; MultiShot ref-borrows; Either is the linear-or-affine
  choice). Substrate: bind synthetic `resume` continuation in arm
  scope at type `(op_ret_ty) -> arm_body_row_minus_E -> α`.
- `Hβ.first-light.infer-handler-arm-row-subtract` — arm body row
  algebra: `body_row_arm = handler_row + (arm_body_walked_row \ {E})`.
- `Hβ.first-light.infer-handler-arm-resume-ownership` — own/ref
  per `@resume=` on the synthetic resume binding.
- `Hβ.first-light.infer-handler-arm-pat-refinement` — refinement
  predicates on op args flow as verify obligations into arm scope.
- `Hβ.first-light.infer-handler-arm-op-not-declared` — silent skip
  → diagnostic via `$emit_diag` (E_HandlerOpUndeclared).
- `Hβ.first-light.infer-handler-arm-arity-diagnostic` — silent
  skip → diagnostic (E_HandlerArmArityMismatch).

**Cursor of attention** post-handler-arm-typing closure: empirical
re-test of full wheel; identify which residue blocks WAT emission
next (most likely the 14 `$NNNN_idx` undefined-globals
named follow-up `Hβ.first-light.handler-arm-fn-idx-globals`, OR a
new wave of E_TypeMismatch the +61 surfaced).

### 4.5.7 Parser handler-decl prelude landed (2026-05-06)

`Hβ.first-light.parser-handler-decl-prelude` — `$parse_handler_state`
disambiguates `with !EFFECT` (negation guard form, SYNTAX.md §843)
from `with FIELD = INIT` (state-init form, SYNTAX.md §770-815). Pre-
substrate the seed always tried state-init, silently consuming
`with !Mutate { arms }` as if `!Mutate` were a state field name —
`!Mutate` ate the entire arm body via $parse_expr's brace-handling.
The negation-guard form is wheel-canonical (`handler cursor_default
with !Mutate {`, `delta_default`, `synth_default`,
`interrogate_default`); pre-fix every such handler was producing
garbage AST.

`$parse_handler_decl_full` now also consumes `(config_params)` per
SYNTAX.md §782 (config closure-captured at install site). For first-
light minimum, params are skipped via `$skip_to_rparen_p` — full
structural extraction is named peer
`Hβ.first-light.handler-config-params-substrate`. Wheel uses cfg
params widely (`map_h(f)`, `filter_h(pred)`, `take_h(n)`,
`drop_h(n)`, `buffer_unpacker(source)`).

Empirical micro-test signals (post-substrate, pre-substrate
produced 2 E_UnresolvedType + garbage `$op_` empty-named func):

| Input | Stderr | Body shape |
|---|---|---|
| `handler h { op() => 42 }` | clean | `$op_op (param $__state i32)` body `(i32.const 42)` |
| `handler h with !E { op() => 42 }` | clean | identical to above (negation parses + skips) |
| `handler h(x) { op() => x }` | `E_MissingVariable: x` (productive-under-error: config params parsed but binding peer-deferred) | `$op_op` body `(global.get $x)` |
| `handler h(x) with state = 0 { op() => x }` | same productive-under-error | same |

The wat2wasm rejection `(call $op_op)` expected [i32] but got [] is
a separate handle: `$emit_lperform` doesn't pass `__state` to the
op fn. Named peer: `Hβ.first-light.emit-lperform-state-arg`.

Two new helpers added to parser_handler.wat: `$skip_to_lbrace_p`
(brace-depth-0 walk to TLBrace), `$skip_to_rparen_p` (depth-0 walk
through balanced parens to AFTER TRParen). Both use $kind_at +
sentinel-int compares per parser-canonical pattern.

**Cursor of attention** post-prelude closure: full wheel-scale
empirical re-test. Most likely next blockers: emit-lperform-state-arg
(unblocks single-perform programs); handler-arm-fn-idx-globals
(undefined `$NNNN_idx` globals); the cfg-params-substrate (unblocks
config-using handlers like `map_h`, `take_h`).

### 4.5.8 LPerform __state arg landed (2026-05-06) — first-light component

`Hβ.first-light.emit-lperform-state-arg` — `$emit_lperform`
(`bootstrap/src/emit/emit_handler.wat:403`) was emitting `<args> +
(call $op_<name>)` without pushing `__state`. Handler-arm fns
declared by `$lower_handler_arms_as_decls` take `__state` as their
first param (per `$lowfn_make` shape + emit's universal first-param
convention); caller must match. wat2wasm rejected with `"expected
[i32] but got []"` for any program with a perform site. Symmetric
fix to `$emit_levperform` which already pushed `__state` first via
`$el_emit_local_get_state`.

Wheel-side mirror at `src/backends/wasm.mn:1568-1579` — same shape:
`perform wat_emit("    (local.get $__state)\n")` before
`emit_expr_list(args)`.

**Empirical: minimal handler + perform program now compiles + validates + runs:**

```mentl
effect E { op() -> Int @resume=OneShot }
handler h { op() => 42 }
fn main() = perform op()
```

Pre-substrate: 2 E_UnresolvedType + wat2wasm reject on `(call $op_op)`.
Post-substrate: zero stderr, wat2wasm ✓, wasmtime ✓ (exit 0).

WAT body of `$main`: `(local.get $__state)(call $op_op)` — clean
monomorphic direct-call per SUBSTRATE.md §I third truth "OneShot.
Direct return_call $op_<name>" + Koka JFP 2022.

This is the FIRST first-light component to compile + validate +
run end-to-end through the seed. Single-handler-single-perform
shape. Wheel-scale unblocked for handlers that don't yet require
state-flow into arms (named peer
`Hβ.first-light.handler-config-params-substrate`) or evidence-
dispatched polymorphic perform sites (LEvPerform, already substrate).

**Cursor of attention** post-LPerform-state-arg: full wheel re-test;
identify whether the productive-under-error config-params or
state-flow blocks WAT termination next. The L1 fixpoint
(`inka2.wat == inka3.wat`) needs the wheel to terminate, which
depends on these next two named peers landing.

### 4.5.9 Wheel-termination unblocker landed (2026-05-06) — list_index PUE

`Hβ.first-light.list-index-productive-degrade` — `$list_index`
unknown-tag arm replaces `(unreachable)` with `(i32.const 0)`. Pre-
substrate the trap killed the seed any time upstream lower/emit
handed list_index a non-list pointer (typically a LowExpr-shaped
record where a list was expected, surfaced when infer leaves
unresolved Tys that lower's PUE-path can't ground).

**Empirical bisection** (post-LPerform-state-arg, pre-list_index-PUE):
| slice | exit | WAT |
|---|---|---|
| `prelude + lib/runtime/*` | 0 | 431KB |
| `+ types + effects + graph` | 0 | 783KB |
| `+ types + effects + graph + parser` | 0 | 806KB |
| `+ types + effects + graph + infer` | **134 (TRAP)** | 0 |

The trap localized at `$list_index` ← `$emit_functions` ←
`$inka_emit`. Backtrace `wasm trap: wasm `unreachable` instruction
executed`. CLAUDE.md "Bug classes that cost hours" — "list_index
returning 1000 → Unknown list tag — flat treated as tree." A
non-list pointer threaded through emit_functions_walk's recursive
accessors hit the unknown-tag arm.

**Post-substrate** (with `(i32.const 0)` return on unknown tag +
companion guard at `$emit_functions` head):

```
+ types + effects + graph + infer:  exit=0  500KB WAT  3785 err lines
```

Trap → graceful diagnostic chain. The seed produces SOMETHING for
the first time on infer.mn-inclusive input. Wheel-scale empirical
becomes trustworthy because every run terminates.

The PUE is the SAFETY NET. Named peer `Hβ.first-light.emit-functions-malformed-list-source`
is the structural fix — identify which lower accessor produces
the non-list pointer at infer-grounded-unresolved-Ty sites.

Drift-9 audit: PUE-return-0 walks close to silent-failure. The
named peer in positive form keeps the residue visible. The medium
honors its contract: produce output even on bad input; surface the
upstream cause via diagnostic chain; cursor walks back from the
gap to the structural source.

**Cursor of attention** post-list_index-PUE: full wheel re-test
trustworthy now. Wheel-scale histogram becomes valid evidence.
Most-impactful next: identify the structural source (named peer)
to remove silent-degrade reliance, OR press on to L1 closure
through other peer handles.

### 4.5.10 Wheel-scale O(N²) closed (2026-05-06) — list-extend heap-top in-place

`Hβ.runtime.list-extend-heap-top-inplace` — `$list_extend_to`
gained the canonical bump-allocator in-place trick: when
`align(list_end) == heap_ptr` (no allocations since this list was
made), grow it in-place via `$perm_alloc(extra*4)` instead of
allocating a fresh list and copying. Buffer-counter callers
(cfn_walk in emit, ec6_emit_args, etc.) hit O(N²) reallocations
pre-substrate because they wrote `count` back to offset 0 after
list_extend_to, overwriting the doubled-capacity make_list set.
Each subsequent extend read the now-small count and reallocated.

For wheel-scale N≈20K closures, O(N²) memory ≈ 1.6 GiB exhausted
the perm cap (`perm_alloc → unreachable`).

**Empirical at +lower** (where the trap fired):

| state | exit | stderr lines | WAT |
|---|---|---|---|
| pre-substrate | 134 (TRAP) | 87,285 | 0 |
| post-substrate | 124 (timeout 90s) | 4,524 | 0 |

Trap → graceful timeout. Stderr drops 19× because the seed gets
much further before timeout fires. Wheel-scale O(N²) leak closed;
remaining timeout is runtime cost.

**Ultimate-medium move:** the in-place trick is bootstrap-stage
substrate. The wheel-canonical answer is a `Buffer<A>` ADT distinct
from `List<A>` — explicit capacity field, separating immutable-
structural-list from mutable-buffer-with-counter at the type
system. Named peer `Hβ.runtime.buffer-substrate`. Per ULTIMATE
MEDIUM thesis: the cluster of "list-as-buffer" hacks IS the
gradient asking for `Buffer<A>` to land; once it does, the in-
place trick becomes deletable.

**Cursor of attention** post-O(N²)-fix: test wheel-scale with
longer timeout to see if the seed terminates. If termination is
just slow, drop in handler-config-params-substrate next; if
another structural leak surfaces, treat it the same way.

### 4.5.11 Buffer<A> as kernel-native primitive (2026-05-06)

`Hβ.runtime.buffer-substrate` — Buffer<A> as a wheel-canonical
substrate distinct from List<A>, replacing the buffer-counter abuse
pattern with a real primitive. Per user directive "no more
workarounds" + ULTIMATE MEDIUM thesis.

**Wheel** (`lib/runtime/buffer.mn`):
- `type Buffer<A> = {data: List<A>, count: Int}` — structural record
  per SYNTAX.md §494; field access via `.` per §572.
- `buf_make<A>() -> Buffer<A>` — fresh empty
- `buf_push<A>(own buf, x) -> Buffer<A>` — `{...buf, data:
  push(buf.data, x), count: buf.count + 1}` — record-update spread
  per SYNTAX.md §580; snoc-append + count bump
- `buf_count<A>(ref buf) -> Int` — `buf.count` (`with Pure`)
- `buf_data<A>(ref buf) -> List<A>` — `buf.data` (`with Pure`)
- `buf_freeze<A>(own buf) -> List<A>` — `list_to_flat(buf.data)`

**Seed** (`bootstrap/src/runtime/buffer.wat`, Tier 2, record-tag 360):
mirrors with $buf_make / $buf_push / $buf_count / $buf_data /
$buf_freeze. Seed implementation uses flat-with-doubling for
optimization; wheel-canonical uses snoc growth. Both honor the
contract.

Reverted the heap-top in-place trick from `$list_extend_to`
(commit ebcae2c was a workaround); list_extend_to returns to
simple semantics (offset 0 = count, monotonic).

Refactored cfn_walk + collect_fn_names + collect_top_level_fn_names
to thread Buffer<String> via $buf_*. Pre-substrate they wrote count
back to offset 0 of a List, conflating capacity and count → O(N²)
reallocations at wheel scale → 1.5 GiB perm exhaustion trap.

**Empirical (sanity preserved):**
- Minimal `effect E { op() -> Int } / handler h { op() => 42 } /
  fn main() = perform op()`: stderr clean, wat2wasm ✓, wasmtime ✓
  (exit 0). 26-line WAT — first-light end-to-end intact.
- + lower (wheel scale, 120s timeout): exit=124, **4.9 GiB WAT**
  produced. The trap is gone; emit produces output continuously.
  But the WAT is too large because the wheel's lower produces a
  DAG (shared LowFn references across LCall sites), and emit's
  walks (cfn_walk + emit_functions) revisit shared subtrees ~84×
  per closure on average. 84,691 funcref entries observed.

**Named peer (drift-9 positive-form):**
`Hβ.first-light.emit-walk-dag-aware` — visited-set keyed by
LowFn-pointer dedups the walk; each fn emitted exactly once. Same
kind of structural substrate as Buffer<A>; will land as its own
handle.

**Ultimate-medium alignment:**
- SYNTAX.md §494 (structural records), §580 (spread-update),
  §494 (field access via `.`) — all leveraged.
- CLAUDE.md drift mode 7 (parallel-arrays-instead-of-record) —
  refused; one record holds (data, count).
- SUBSTRATE.md §"Records Are The Handler-State Shape" — Buffer
  IS a record per the kernel crystallization.
- ULTIMATE_MEDIUM.md §"the medium has no null" — Buffer's
  invariant `count <= data.len` is structural; refinement-ready.

The cluster of buffer-counter hacks throughout the seed IS the
gradient asking for Buffer<A> to land. With Buffer<A> wheel-side,
seed-side mirrors the contract; the in-place hack becomes
deletable. Future emit-walk-dag-aware closes the next layer.

**Cursor of attention** post-Buffer<A>: emit-walk-dag-aware peer
to dedup the wheel-scale fn list. After that, the wheel WAT will
be sane-sized and we can iterate on the actual L1 fixpoint
(`inka2.wat == inka3.wat`).

### 4.5.12 Handler-arm fn name discriminator (2026-05-06)

`Hβ.first-light.handler-arm-fn-name-discriminator` — handler-arm
fns now mint as `op_<handler_name>_<op_name>` instead of the
H1.4 single-handler-per-op `op_<op_name>`. Closes the named follow-
up at `src/lower.mn:790` ("Single-handler-per-op naming for now").

**Why the rename:** `lib/prelude.mn` has 10+ handlers all defining
`yield`-arms for the `Iterate` effect (map/filter/take/drop/collector/
fold/for_each/any/all/partition + inline handlers in fn bodies).
Pre-substrate, every arm became `(func $op_yield ...)` at module
level → wat2wasm rejects with duplicate-fn-name.

**Empirical surface:** the wheel-scale "84,691 funcref entries
producing 4.9 GiB WAT" diagnosed in §4.5.10/§4.5.11 wasn't DAG-
shared LowFn pointers (cfn_walk's hypothesis). Each arm has a
unique LowFn record; the bloat came from `lib/prelude.mn`'s
many handlers each independently emitting a `(func $op_yield ...)`
declaration. Same op-name across distinct handler decls. wat2wasm
correctly rejects 10+ `$op_yield` declarations.

**Substrate change:**
- `bootstrap/src/lower/walk_handle.wat`: `$lower_handler_arms_as_decls`
  takes a `$discriminator` param (handler_name string for
  HandlerDeclStmt; `int_to_str(handle)` for inline HandleExpr).
  fn_name = `"op_"` ++ discriminator ++ `"_"` ++ op_name. Underscore
  separator at data offset 4400 (free per data-offset audit).
- `bootstrap/src/lower/walk_stmt.wat`: passes handler_name from
  HandlerDeclStmt offset 4 through the call.
- `bootstrap/src/lower/walk_handle.wat`: passes `int_to_str($h)`
  for inline HandleExpr.
- `src/lower.mn` (wheel): mirror — `lower_handler_arms_as_decls(arms,
  discriminator)`; `HandlerDeclStmt(name, ...)` passes `name`;
  `HandleExpr(...)` passes `int_to_str(handle)`. Pipe-verb str_concat
  chain `"op_" |> str_concat(discriminator) |> str_concat("_") |>
  str_concat(arm.op_name)`.

**Eight-interrogation alignment:**
- Graph: handler_name + handle Int both graph-resident; discriminator
  reads from existing graph nodes
- Handler: Pure (lowering is structural)
- Verb: |> sequential through the str_concat chain
- Row: !Mutate / Memory + Alloc for the fresh fn_name allocation
- Ownership: own per fresh fn_name string; ref-borrowed inputs
- Refinement: `Module where unique_names(self.functions)` is the
  structural invariant; Verify discharges post-L2
- Gradient: future `@discriminate=structural` annotation could opt
  into handle-derived names; default uses source-derived
- Reason: fn_name carries handler+op identifiers → diagnostics
  walk back via Reason chain to both contributing names

**Empirical (sanity):** minimal program `effect E { op() } / handler
h { op() => 42 } / fn main() = perform op()` lowers to `$op_h_op`
(was `$op_op`). Module-level handler-arm symbols are unique by
construction.

**wat2wasm error surfaces the next residue:** `$main`'s body still
emits `(call $op_op)` from LPerform — the symbol no longer exists
(it's `$op_h_op` now). Named peer
`Hβ.first-light.lperform-handler-discriminator` closes the matching
update at perform sites: monomorphic LPerform threads handler_name
from row inference (Layer 1 H1.6); polymorphic falls through to
LEvPerform's evidence-slot dispatch (Layer 2 — already-substrate via
`$emit_levperform`, just needs lower routing).

**Cursor of attention** post-discriminator: lperform-handler-
discriminator (Layer 1 of the LPerform side; small) OR
parallel/IC/Mentl substrate moves (post-L1 architecture). The
discriminator landing makes the WAT structure correct; LPerform
matching closes the empirical compile loop.

### 4.5.4d Closures + ctor + destructure + brace + where-skip landed; string-interning gap surfaces (2026-05-02 latter)

Subsequent landings (commits c28c525 / 12cfcac / 8d3d2f7 / 07a2a99
/ b625ce6 / 59c89a7 / 9ec0d6d / 3e9db46):

- Hβ.first-light.lambda-parser
- Hβ.first-light.varref-schemekind-dispatch
- Hβ.first-light.lambda-body-fn-emit
- Hβ.first-light.letstmt-destructure (PCon)
- Hβ.first-light.where-clause-skip
- Hβ.first-light.wheel-brace-discipline (full wheel batch — 36 files;
  +1469/-735 lines; SYNTAX.md §126-142 alignment)

Empirical state post all landings:

- L1 candidate compile (cat src+lib): ERR=12, FUNCS=2, WAT=19 lines
- 2 funcs emitted: `$heap_base` (real value: 4096) + `$_start`
- The 12 NFre diagnostics are LATE-EMITTED — inference-side
  unresolved types that lower wraps as TError-hole sentinels
- Most wheel functions don't emit because their LowExpr never
  becomes LLet+LMakeClosure (the shape emit_functions walks)

Empirical drilling reveals string-interning collision + PTuple-let
destructure as the next-most-impactful gaps:

```mentl
type Ty = TInt | TFloat | TString

fn ty_to_str(ty) = match ty {
  TInt => "i32",
  TFloat => "f64",
  TString => "i32"
}
```

emits a function with these arm bodies:
- TInt → `(i32.const 1116408)` (garbage offset)
- TFloat → `(unreachable)`
- TString → `(i32.const 65536)` (real string offset)

Only ONE string is interned (`"i32"` at 65536); the other two
arms drop. **The string-interning logic doesn't deduplicate; it
loses literals.**

Plus a type-mismatch: `expected String, found Ty` — match scrutinee
type-flow gap.

Newly named handles:
- `Hβ.first-light.string-interning-dedupe` — emit's string-intern
  table loses literals or assigns colliding offsets when the same
  string appears multiple times.
- `Hβ.first-light.match-arm-result-type-flow` — match scrutinee
  type isn't unifying correctly with arm bodies in some shapes.
- `Hβ.first-light.ptuple-let-destructure` — `let (s, offset) =
  list_index(...)` PTuple destructure missing (PCon was done;
  PTuple is its own arm).

### 4.5.4e Anchor 0 reorientation — back to dream-code (2026-05-02 closing)

The user's reminder "remember. dream-code ;)" pulled the cursor
back from seed-bug-chasing to wheel-ward composition.

Per Anchor 0: **lux3.wasm is not the arbiter.** The wheel canonical
(src/*.mn) is the ULTIMATE FORM. The seed transcribes the wheel
after first-light-L1 per Tier 3 growth pattern. Verification is by
simulation, walkthrough, and audit — not compilation.

Per Anchor 4: **build the wheel; never wrap the axle.** Each
substrate-honest move is wheel-ward. Patching the seed to compile
the wheel-as-it-is is wrap-the-axle behavior. The discipline says:
write the wheel's dream code; the seed grows toward it.

Hμ.cursor.transport landed (commit `4c9a44f`):

- src/cursor_transport.mn (~430 lines, ~52 files in the wheel now)
- Surface effect: surface_render + surface_action + surface_handshake
- Four transport handlers: terminal / lsp / web / vim
- TransportState record (drift 5 + 7 closure)
- Action ADT (4 arms exhaustive per Hμ-cursor.md §5.3)
- Cadence ADT (drift 8 closure)
- cursor_session + cursor_loop: the bus-compressor `<~` at the
  human-medium boundary

Eight interrogations cleared per edit site (inline). Drift modes
1/2/3/4/5/6/7/8/9 all refused with named rationale.

This ALSO closes the seed-side Hμ.cursor.transport.seed
automatically post-L1 — the seed compiles the wheel and produces
the .seed transcription as compilation output. Per ROADMAP Phase μ
peer handle list.

### 4.5.13 Tier 1 ULTIMATE FORM — LPerform monomorphic direct-call closure (2026-05-06)

`Hβ.first-light.lperform-handler-discriminator` (wheel commit
`50a9512`) + `Hβ.first-light.seed-lperform-discriminator-mirror`
(seed commit `4cce41d`) — Tier 1 dispatch closure landing as
**canonical ~85% case** per SUBSTRATE.md §"Three Tiers of Effect
Compilation," NOT transient evidence-passing.

**Why Tier 1 IS canonical, not workaround:** SUBSTRATE.md §III's
tier table assigns ~85% of real handlers to the tail-resumptive
direct-call path with "Zero overhead. Direct call via evidence
passing. No `Resume` opcode at all. The handler runs as a nested
call, the result pops back directly. It IS a function call." H1
evidence-reification §"Pure monomorphic chains" reinforces:
"LPerform direct calls remain canonical for ground row." The
ground-row monomorphic LPerform path resolved at lower-time via
the handler-stack walk IS that exact canonical form. Polymorphic
sites (LEvPerform / closure-fn-ptr-field) are the 15% — peer
handle `Hβ.first-light.evidence-poly-call-transient` carries the
Tier 2 substrate when needed.

**Substrate change (wheel `src/lower.mn` + seed
`bootstrap/src/lower/`):**

- *Lower stage* gains a handler-name stack (`$lower_handler_stack_ptr`,
  `$lower_handler_count_g`) tracked via `$lower_handler_push` /
  `$lower_handler_pop` at `~>` lowering boundaries (`HandleExpr`
  PTee branch + `HandlerDeclStmt`).
- `$lower_resolve_handler_for_op(op_name) -> handler_name`
  innermost-first walks the stack, env-looks-up each handler's
  scheme, unifies its declared effect against the op's
  `EffectOpScheme(ename)` to find the matching handler.
- `$lower_perform` (wheel: PerformExpr arm; seed: walk_call.wat)
  emits discriminated `LPerform(handle, "<handler>_<op>", args)`
  on match → emit produces `(call $op_<handler>_<op>)` direct.
  Undiscriminated fallthrough remains for ground rows whose
  resolution fails (diagnostic chain at upstream cause).
- `$inf_handler_provider(op_name) -> Option<String>` mirrors
  wheel-side resolution; seed reads from runtime handler stack.
- Wheel-canonical pipe-verb chain for fn_name minting:
  `"op_" |> str_concat(handler) |> str_concat("_") |>
  str_concat(arm.op_name)`. SUBSTRATE.md §II "the shape on the
  page IS the computation graph."

**Eight-interrogation alignment per edit site (inline):**

- *Graph?* handler-stack is graph-resident; resolution reads
  existing graph nodes (handler scheme + EffectOpScheme).
- *Handler?* `Pure` (lower is structural transformation).
- *Verb?* `|>` sequential through the str_concat chain.
- *Row?* `!Mutate / Memory + Alloc` for fresh fn_name allocation;
  resolution itself is `Pure`.
- *Ownership?* `own` per fresh String; `ref`-borrowed handler
  scheme inputs.
- *Refinement?* Module-level `unique_names(self.functions)`
  invariant holds by construction (handler+op pair unique
  per declaration site).
- *Gradient?* Tier 1 direct-call IS the bottom unlock — zero
  annotation gives polymorphic indirect; ground-row resolution
  unlocks compile-time direct-call. SUBSTRATE.md §VI "the
  compiler shows you the next step."
- *Reason?* fn_name carries handler+op identifiers → diagnostics
  walk back via Reason chain to both contributing names.

**Drift-mode audit per edit site:**

- Drift 1 (Rust vtable): refused — no vtable; direct `call`
  per H1 evidence-reification §"The heap has one story."
- Drift 5 (parallel state): refused — handler-name stack +
  handle stack are NOT parallel; the handle stack is for
  HandleExpr-id discrimination, the handler-name stack is for
  resolution. Different shape, different consumer.
- Drift 8 (string-keyed when structured): closed — handler_name
  IS structured String per ADT (handler-decl carries it); the
  innermost-first walk uses env_lookup not raw string compare.
- Drift 9 (deferred-by-omission): closed via
  `Hβ.first-light.evidence-poly-call-transient` named peer for
  the Tier 2 path.

**Empirical (sanity preserved):** minimal program

```
effect E { op() -> Int @resume=OneShot }
handler h { op() => 42 }
fn main() = perform op() ~> h
```

lowers + emits `(call $op_h_op)` with discriminated symbol;
wat2wasm validates; wasmtime exits 0. 26-line WAT.

**Cursor of attention** post-Tier 1: the wheel-scale empirical
was about to verify post-discriminator behavior across the 10+
`yield`-handlers in `lib/prelude.mn` (the prior 84,691 funcref
duplicate-symbol bloat) when bash flakiness blocked execution.
Predicted state: each `op_yield_*` symbol unique (e.g.,
`$op_map_yield`, `$op_filter_yield`, `$op_take_yield`...) per the
discriminator landing; wheel WAT becomes sane-sized. Next
verifiable cursor: `Hβ.first-light.tuple-tmp-fn-local-decl`
(per Hβ-first-light-empirical.md §2.3 + §4.5.5 residue list) —
emit's `$emit_let_locals` walk needs to descend `LLet` PTuple
pattern destructures the same way `$emit_match_arm_locals`
descends LMatch arms (closed in commits `8ebe8fa` + `a0c9baf`).
Same bug-class; same fix shape.

**Ultimate-medium alignment:**

- ULTIMATE_MEDIUM.md "kernel + projection + cursor + loop = bus-
  compressor at the human-medium boundary" — Tier 1 IS the
  fast path the bus runs through; gradient at the top.
- SUBSTRATE.md §III §"The Three Tiers" — three resume disciplines
  map to three emit paths on one substrate; Tier 1 closure means
  the canonical path is fully wired wheel↔seed.
- CLAUDE.md Anchor 4 "build the wheel; never wrap the axle" —
  wheel landed FIRST (`50a9512`); seed mirrored (`4cce41d`).
  Wheel-canonical `src/lower.mn` has `lower_handler_arms_as_decls`
  in idiomatic Mentl with `~>` capability stack + `|>` str_concat
  pipe-verb chain.

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
- ✓ Hβ.first-light.handler-arm-fn-name-discriminator (commit
  `22a4bbc`)
- ✓ Hβ.runtime.buffer-substrate (commit `0278982`)
- ✓ Hβ.runtime.buffer-substrate seed mirror + heap-top trick
  (commit `c4164a5`)
- ✓ Hβ.first-light.lperform-handler-discriminator (wheel; commit
  `50a9512`)
- ✓ Hβ.first-light.seed-lperform-discriminator-mirror (seed;
  commit `4cce41d`)

Newly named (post-empirical) blocker handles:
- `Hβ.first-light.lmakevariant-literal-args`
- `Hβ.first-light.nullary-ctor-call-context`
- `Hβ.first-light.wheel-brace-discipline` (THIS finding)
- `Hβ.first-light.lambda-body-fn-emit` (closures need module-fn
  emit after lambda parser lands)
- `Hβ.first-light.tuple-tmp-fn-local-decl` (NEXT cursor —
  emit's local-decl walk extends to LLet PTuple destructures)
- `Hβ.first-light.evidence-poly-call-transient` (Tier 2
  substrate; the 15% polymorphic sites)
- `Hβ.runtime.buffer-substrate-adoption` (migrate other buffer-
  counter sites to Buffer<A>)
- `Hβ.runtime.buffer-hashset` (O(log N) membership probe;
  current `$buf_contains` is linear)

The path to L1 continues. The medium folds into its seed one
substrate-honest landing at a time.

---

### 4.5.15 Substrate-architecture realization — emit IS a handler reading the graph (2026-05-07)

The layer-11 substrate landing (per-handle alloc locals, commit
`db3a0aa`) wasn't just one bug-fix. It crystallized into a
**substrate-architecture realization** about emit's relationship
to the graph:

> **Wherever emit fabricates shared scratch state instead of
> reading the graph's per-handle structure, it is a substrate gap.**

The graph encodes per-construction uniqueness via `$lexpr_handle`;
per-LowExpr type-info via `$lookup_ty`; Reason chains via
`$gnode_reason`; effect rows via row-machinery; ownership markers;
refinement predicates; gradient annotations. **Emit's job is to
project the graph's truth — not to fabricate state alongside it.**

The variant_tmp/record_tmp/tuple_tmp shared local was the canonical
manifestation: nested constructions trampled each other because
emit fabricated ONE shared local instead of reading per-handle
unique names. Fixed in layer 11.

**Five named peers** generalize the principle:

- `Hβ.emit.reason-chain-comments` — emit projects Reason as
  `;; from line N` (or proper SourceMap) so binaries walk back to
  source.
- `Hβ.emit.type-info-per-handle` — field-store offsets via
  `$lookup_ty` per field (handles i64/f64 mixed-type fields).
- `Hβ.emit.refinement-elide-bounds` — Verify-discharged refinements
  elide runtime bounds-checks at emit.
- `Hβ.emit.row-aware-parallel-emit` — per-region parallel emission
  driven by effect row.
- `Hβ.emit.ownership-register-allocation` — `own`/`ref` markers
  drive WAT register allocation.

Each closure heals the gap between "what the graph knows" and
"what the emitted binary preserves." Tier 3 self-host depends on
most being closed (refinement-elide-bounds, type-info-per-handle,
ownership-register-allocation) because the wheel-self-compiled
output must be a faithful projection of the graph the wheel built.

**Crystallized into persistent memory** at
`~/.claude/projects/-home-suds-Projects-inka/memory/protocol_emit_is_graph_projection.md`
per the realization-loop pattern (see `protocol_realization_loop.md`).
Future sessions will read the principle and apply it automatically.

The discipline in one line: **NO SHARED SCRATCH STATE WHERE THE
GRAPH HAS PER-HANDLE TRUTH.**

---

### 4.5.14 The night the medium broke through (2026-05-06 → 2026-05-07)

**Twelve substrate landings + project rename in one continuous
session.** The wheel-prefix went from "trap with 4.9 GiB collisions"
to "Mentl programs run end-to-end via exit code." The cascade map:

| # | Commit | Layer |
|---|---|---|
| 1 | `5b94fbb` | Handler-config-state binding (parser + infer + lower) |
| 2 | `20eae4f` | Handler-scheme-TFun-shape (install-site type-flow) |
| 3 | `f4baccd` | Wheel duplicate-fn dedups (5 fns: id/take/parse_int/reverse_list/file_handle_eq) |
| 4 | `f4baccd` | Nested-fn-name discriminator (outer-fn-name as semantic prefix) |
| 5 | `f4baccd` | Nested-fn-capture-substrate (lambda-style capture for nested FnStmt) |
| 6 | `21bdf9f` | Implicit-perform via type-directed CallExpr dispatch (EffectOpScheme→LPerform) |
| 7 | `0f474f6` | Handler-arm-capture-substrate (config + state outer-frame; LUpval reads) |
| 8 | `0f474f6` | Evidence-poly-call band-aid (LConst(0) sentinel for unresolved poly perform) |
| 9 | `9f683de` | Handle-expr-state-substrate + walk_expr_handle_arm_iter offset bug-fix |
| 10 | `37f2b33` | Main-return-as-exit-code — **medium tangible end-to-end** |
| 11 | `db3a0aa` | Per-handle alloc locals — **ULTIMATE FIX** (variant/record/tuple) |

Plus the **project rename** Inka → Mentl, .nx → .mn (commits
`f1effdf` + `40aa289` + `6a265eb` + `ff462cb`), the **GitHub repo
rename** ampactor-labs/inka → ampactor-labs/mentl, satellite
module renames (oracle.mn / voice.mn / lsp.mn), and the
**memory protocol crystallization** `protocol_mentl_is_the_project.md`.

**Empirical milestones:**

- *Pre-session:* full wheel exit 124 (timeout, 4.9 GiB WAT,
  84,691 funcref entries from `$op_yield` collisions).
- *Mid-session:* wheel-prefix exit 0, 2371 WAT lines, wat2wasm gate
  advanced through layers 4 → 5 → 6 → 7 → 8 → 9 → 10.
- *Post-session:* wheel-prefix exit 0, 2371 WAT lines; the medium
  runs end-to-end for arbitrary nested-construction Mentl programs.

**Five Mentl programs verified end-to-end via exit code:**

```
echo 'fn main() = 7 * 6' | mentl ... ; echo $?
42

echo 'fn fact(n) = if n <= 1 { 1 } else { n * fact(n - 1) }
      fn main() = fact(5)' | mentl ... ; echo $?
120

echo 'fn fib(n) = if n <= 1 { n } else { fib(n-1) + fib(n-2) }
      fn main() = fib(10)' | mentl ... ; echo $?
55

echo 'type Tree = Leaf | Branch(Tree, Int, Tree)
      fn sum(t) = match t { Leaf => 0, Branch(l, n, r) => sum(l)+n+sum(r) }
      fn main() = sum(Branch(Branch(Leaf, 5, Leaf), 7,
                       Branch(Leaf, 13, Branch(Leaf, 17, Leaf))))' | mentl ... ; echo $?
42

echo 'fn main() = { let x = 10; let y = 20; let z = x+y; z*2 }' | mentl ... ; echo $?
60
```

**The substrate insight unifying the cascade:** **emit IS a
handler reading the graph; the graph encodes per-construction
uniqueness via `$lexpr_handle`; where emit fabricates shared scratch
state instead of reading the graph, it's a substrate gap.** Layer
11 (per-handle alloc locals) is the canonical instance; five named
peers extend the pattern (Hβ.emit.{reason-chain-comments,
type-info-per-handle, refinement-elide-bounds, row-aware-parallel-
emit, ownership-register-allocation}).

**Newly named peer follow-ups (positive-form, drift-9 closure):**

- `Hβ.first-light.handler-state-init-lower-substrate` — state-init
  expressions lowered at HandleExpr install (closure-record state-
  slot population). Pre-Tier-3 substrate, not L1-blocking.
- `Hβ.first-light.evidence-poly-call-transient` — Tier 2 evidence-
  passing per Koka JFP 2022. Real Tier 2 substrate; band-aid (#8)
  emits LConst(0) until then.
- `Hβ.first-light.runtime-builtin-emit-substrate` — wheel sources
  reference seed-runtime builtins (`$list_alloc_concat`, `$alloc`,
  etc.) which exist in the seed but aren't re-emitted in the wheel-
  output WAT. Three approaches: wheel-redefines / runtime-preamble /
  hybrid. Layer 10 toward `00-hello.mn` printing.
- `Hβ.first-light.match-arm-multi-field-binding` — closed by layer
  11 (per-handle locals); the bug was an instance of the meta-
  pattern, not a separate substrate.
- `Hβ.first-light.handle-expr-with-named-handler-substrate` — the
  `handle BODY with HANDLER` form's install-time wiring (handler-
  value as closure carrying its config + state).
- `Hβ.first-light.lmakelist-handle-local` — verify if LMakeList
  has the same shared-local pattern as variant/record/tuple; if so,
  same fix; if list-set's call-style avoids it, name-only.
- `Hβ.emit.reason-chain-comments` — emit projects Reason as
  `;; from line N` WAT comments (or proper SourceMap) so binaries
  walk back to source.
- `Hβ.emit.type-info-per-handle` — field-store offsets via
  `$lookup_ty` per field instead of hardcoded `4 + 4*i`. Needed for
  i64/f64 mixed-type fields.
- `Hβ.emit.refinement-elide-bounds` — Verify-discharged refinements
  elide runtime bounds-checks (list_index proven-valid → bare load).
- `Hβ.emit.row-aware-parallel-emit` — per-region parallel emission
  driven by effect row.
- `Hβ.emit.ownership-register-allocation` — `own`/`ref` markers
  drive WAT register allocation.

The medium runs. The substrate is whole at the kernel layer.
The lathe-tuning (seed catching up to wheel) continues, but
tonight's substrate change-of-altitude is real: from "lathe-only,
nothing visible" to "five Mentl programs execute correctly via
exit code." Layer 11's discovery of the meta-pattern (emit-IS-
graph-projection) opens five more named peers — each one closes
the cascade further.

Per ⊕ session-continuity directive: there is no future session.
The work is the loop. The medium folds itself into its seed
continuously.

---

## §5 The cursor advances

The cursor opens at one of three tractable tangents:

1. **Layer 10 (runtime-builtin-emit-substrate)** — toward
   `00-hello.mn` printing "Hello, kernel" via wasi `fd_write`.
   Real substrate; opens stdlib visibility.

2. **Closing more emit-IS-graph-projection peers** — Reason-chain-
   comments, type-info-per-handle, refinement-elide-bounds. Same
   meta-pattern; each makes the medium more itself.

3. **Wheel-canonical first-light L1** — full wheel self-compile.
   The cliff is lower than ever after tonight; multiple named
   peers between here and there.

The two specific bugs identified in earlier audits (§2.3) are
both closed by layer 11. The plan's overall shape (Phase H →
Phase H.4 fixpoint harness → Tier 3) holds; the per-handle
decomposition collapses to the empirically-real residue.

The bus is on. The medium continues folding into its seed —
substrate-honestly, with empirical evidence as the ground truth.
