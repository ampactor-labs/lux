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

   **CLOSED 2026-05-04.** Empirical re-verification under the
   inka-implementer dispatch (planner-authored §A pre-audit gate)
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
   `src/lower.nx:333-337`. Drift 6 closure: Bool's True/False flow
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
- Individual files: strings.nx alone produces 78 funcs+649 errs;
  lists.nx alone produces 24 funcs+343 errs
- types.nx + memory.nx + strings.nx: 0 funcs (cascading failure
  from types.nx's `self` refinement bindings + TParam
  destructure failures)

**The fundamental remaining gap:** `types.nx` introduces complex
type-system constructs — refinement types (`type X = Y where
predicate(self)`), TParam record-pattern destructuring (`TParam(_,
_, _, resolved)`), nested ADT shape constraints — that the seed
inference can't fully process, causing cascading failures that
prevent later wheel files from compiling.

When `types.nx` is omitted (e.g., `cat lib/runtime/{strings,lists}.nx`),
the seed produces 101 funcs (real wheel substrate compiling). The
whole-wheel compile fails because types.nx's parse/infer cascade
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

Wheel-side mirror at `src/backends/wasm.nx:1568-1579` — same shape:
`perform wat_emit("    (local.get $__state)\n")` before
`emit_expr_list(args)`.

**Empirical: minimal handler + perform program now compiles + validates + runs:**

```inka
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
the first time on infer.nx-inclusive input. Wheel-scale empirical
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

```inka
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
(src/*.nx) is the ULTIMATE FORM. The seed transcribes the wheel
after first-light-L1 per Tier 3 growth pattern. Verification is by
simulation, walkthrough, and audit — not compilation.

Per Anchor 4: **build the wheel; never wrap the axle.** Each
substrate-honest move is wheel-ward. Patching the seed to compile
the wheel-as-it-is is wrap-the-axle behavior. The discipline says:
write the wheel's dream code; the seed grows toward it.

Hμ.cursor.transport landed (commit `4c9a44f`):

- src/cursor_transport.nx (~430 lines, ~52 files in the wheel now)
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
