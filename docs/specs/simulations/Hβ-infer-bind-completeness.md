# Hβ-infer-bind-completeness — bind-form audit + diagnostic localization

> **Status:** walkthrough first (Anchor 7); §5 residue specifies the
> Plan A.2 edits but does NOT execute them. Plan A.2 is a separate
> dispatch.
> **Phase tag:** `Hβ.infer.bind-completeness` — peer to Phase B
> closures (B.2 typedef / B.3 effect / B.4 handler / B.5 match-pattern).
> **Cascade-state context:** ROADMAP claims Phase G is closed (commit
> `fe5e944`); empirical 1068-line `/tmp/inka2-attempt.err` proves the
> closure is contingent. `$inka_infer` runs end-to-end on
> `fn main(x) = x`, but does NOT run end-to-end on real wheel source —
> it produces 100 distinct `E_MissingVariable` names across `src/*.mn`
> + `lib/runtime/*.mn`. Phase G's gate harness used a single-stmt
> minimal AST that did not exercise multi-stmt sibling visibility,
> typedef-then-fn-body composition, or cross-file constructor
> resolution. This walkthrough is that gate's substrate-honesty audit.

---

## §0 Framing — Session Zero stub

The seed's `bootstrap/src/infer/walk_expr.wat` + `walk_stmt.wat` realize
HM inference's one-walk projection (kernel primitive #8) over the
parser's Expr+Stmt ADT. Each bind-form arm (LetStmt, FnStmt, TypedefStmt,
EffectDeclStmt, HandlerDeclStmt, LambdaExpr, MatchExpr per-arm,
HandleExpr per-arm, BlockExpr stmt-list) is responsible for **extending
env (kernel primitive #1) such that every subsequent reference within
the form's scope resolves**. Productive-under-error fires on env miss
via `$infer_emit_missing_var` + `NErrorHole` (correct for genuine
misses; wrong when the binding *should* have been there).

The empirical 1068-line err on real-wheel input enumerates **100
distinct unresolved names**. The names partition into three families
that each implicate a different substrate gap:

- **Family A — ADT constructors** (~38 names): `EfPure`, `EfNeg`,
  `EfClosed`, `EfOpen`, `EfInter`, `EfSub`, `Forall`, `Located`,
  `Inferred`, `MultiShot`, `OneShot`, `None`, `Some`, `PTrue`, `Either`,
  `TFun`, `TInt`, `TString`, `TVar`, `TName`, `TParam`, `TList`,
  `TTuple`, `TFloat`, `TUnit`, `TRecord`, `TRecordOpen`, `TRefined`,
  `TCont`, `Ref`, `Own`, `EAInt`, `EAString`, `ENamed`,
  `EParameterized`, `FnScheme`, `ConstructorScheme`,
  `CapabilityScheme`, `RecordSchemeKind`, `EffectOpScheme`. These are
  variant constructors of typedefs in `src/effects.mn`, `src/types.mn`,
  `src/own.mn`, `src/cache.mn`. Their absence means `$infer_walk_stmt_typedef`
  either is not running on real input, or runs but the constructor names
  it env-extends are not visible by the time downstream fn bodies walk.

- **Family B — top-level fn names** (~36 names): `make_list`,
  `list_index`, `list_set`, `list_extend_to`, `list_copy_into`,
  `list_head`, `list_tail`, `slice`, `str_concat`, `str_eq`, `str_lt`,
  `str_slice`, `str_of_single_byte`, `pack_byte`, `pack_i32`,
  `pack_str`, `pack_finalize`, `unpack_byte`, `unpack_i32`,
  `unpack_str`, `byte_at`, `byte_len`, `bytes`, `set_contains`,
  `set_insert`, `span_zero`, `report`, `show_effrow`, `parse_program`,
  `infer_program`, `lex`, `fs_exists`, `fs_mkdir`, `fs_read_file`,
  `fs_write_file`, `graph_bind_row`, `env_extend`, `env_snapshot`,
  `buffer_packer`, `buffer_unpacker`. These are FnStmts in
  `lib/runtime/*.mn` and `src/*.mn`. `$infer_pre_register_fn_sigs` runs
  per `infer_program`:1098-1104, so by the time any fn body walks every
  fn name in the concatenated stream should be in env. That a body still
  emits `E_MissingVariable: make_list` says either pre-register isn't
  reaching the FnStmt (e.g., wrapped in a parser-shape the recursion
  doesn't unwrap), or the env_extend lands but the binding is in a
  scope that subsequently scope-exits before the body walks.

- **Family C — local bind-form names** (~26 names + multi-occurrence
  tail): `n` (26 occurrences), `name` (9), `path`, `merged`, `kai`,
  `ty`, `v`, `na`, `nb`, `short`, `sorted` (14), `residual`, `entries`,
  `exported_entries`, `imports`, `fields`, `current_source`,
  `module_name`, `compiler_version`, `cache`. These are let-bindings,
  fn-params, and match-arm-pattern-bindings inside fn bodies that
  nonetheless miss. Either env-extend isn't firing at the bind site,
  or scope-enter/exit is over-aggressive (clobbering siblings), or the
  buffer-counter substrate at `runtime/env.wat:300-332` mis-counts
  under repeated extend within a single scope.

Drift mode 9 forbids declaring any arm "fine for now"; either each arm
is verified against the canonical or it is named as a peer follow-up
with its own walkthrough. The three families demand three sub-residues
in §5; this walkthrough scopes them in one document because they share
the same audit machinery (the same trace harnesses), the same
canonical citations, and they compose at the same pipeline-stage
boundary (`$infer_program`).

The eight kernel primitives surface in this walkthrough as: graph + env
(primitive #1, the env binding-stack is the failing register), HM
inference live-productive-under-error with Reasons (#8, the
`E_MissingVariable` IS productive-under-error firing where it should
not), handler discipline (#2, the `infer_program` handler-on-graph
projects this), the five verbs (#3, irrelevant at the stmt arm; pipe
topology is the surface that consumes typed bindings), Boolean effect
algebra (#4, `EfPure`/`EfOpen`/`EfClosed`/`EfNeg`/`EfInter`/`EfSub`
are themselves Family A — the effect-algebra constructors that fail
to resolve when typedef arm doesn't project), ownership-as-effect (#5,
not implicated here directly), refinement types (#6, `Verify` not
implicated), continuous gradient (#7, every `Forall([], _)` is the
monomorphic pin chosen at bind sites; the gradient's annotation form
isn't the failing surface here).

Mentl is an octopus because the kernel has eight primitives. The trap
this walkthrough closes is the fluency-trap of "the harness passes,
therefore the substrate is correct" — which is harness-coverage drift.
The harness coverage was a single-stmt minimal AST; the substrate
breaks under multi-file concatenated wheel-source load.

---

## §1 Bind-form inventory (audit table)

Every Stmt/Expr arm that env-extends. Absence from this table means
that arm doesn't bind names; presence means it MUST be verified against
the canonical (drift mode 9). All "wheel canonical" lines cite
`src/infer.mn`.

| # | Arm                                  | Seed file:line                                     | Extends env? | scope_enter? | scope_exit? | Wheel canonical          | Status |
|---|--------------------------------------|----------------------------------------------------|--------------|--------------|-------------|--------------------------|--------|
| 1 | `$infer_walk_stmt_let` (LetStmt)     | `walk_stmt.wat:472-490`                            | via `$infer_walk_pat` PVar | no | no | `infer.mn:200-204 + 1588-1591` | landed B.5 |
| 2 | `$infer_walk_stmt_fn` (FnStmt)       | `walk_stmt.wat:513-656`                            | params + name post-generalize | yes (544) | yes (648) | `infer.mn:206-210 + 262-369` | landed Phase B |
| 3 | `$infer_walk_stmt_typedef`           | `walk_stmt.wat:794-854`                            | each variant ctor → ConstructorScheme | no | no | `infer.mn:212-213 + 2028-2066` | landed B.2 |
| 4 | `$infer_walk_stmt_effect_decl`       | `walk_stmt.wat:870-915`                            | each op → EffectOpScheme | no | no | `infer.mn:215-216 + 2081-2098` | landed B.3 |
| 5 | `$infer_walk_stmt_handler_decl`      | `walk_stmt.wat:933-955`                            | handler name → TVar(fresh) | no | no | `infer.mn:222-223 + 2100-2109` | stub B.4 |
| 6 | `$infer_walk_expr_lambda`            | `walk_expr.wat:744-768`                            | NO (Hβ.infer.lambda-params) | yes (753) | yes (767) | `infer.mn:724-740` | **stub** — params dropped at line 751 |
| 7 | `$infer_walk_expr_match_arms` (per arm) | `walk_expr.wat:1088-1130`                       | via `$infer_walk_pat` PVar/PCon | yes (1102) | yes (1128) | `infer.mn:1701-1733` | landed B.5 |
| 8 | `$walk_expr_handle_arm_iter` (per arm) | `walk_expr.wat:449-470` (declared); arm-walking peer | seed-stub per Hβ.infer.handler-stack | seed-stub | seed-stub | `infer.mn:1795-1805` | stub |
| 9 | `$infer_walk_expr_block` (BlockExpr) | `walk_expr.wat:813-832`                            | calls `$infer_stmt_list` | yes (821) | yes (831) | `infer.mn:541-548` | landed §13.3 #9 |
| 10 | `$infer_walk_pat` (PVar/PCon/PTuple/PList) | `walk_expr.wat:853-1065`                       | PVar binds, PCon recurses | no | no | `infer.mn:1588-1591 + register_type_constructors:2028-2066` | landed B.5 |
| 11 | `$infer_pre_register_fn_sigs` (toplevel) | `walk_stmt.wat:343-457`                        | fn name → polymorphic placeholder | no | no | `infer.mn:96-149` | landed |
| 12 | `$infer_program` (toplevel entry)    | `walk_stmt.wat:1098-1104`                          | initializes graph+env+state, pre-register, walk | no | no | `infer.mn:182-186` | landed |

### Gap analysis per arm — keyed to the three families

| Family | Implicated arms                          | Gap shape                                                  |
|--------|------------------------------------------|------------------------------------------------------------|
| A (ADT ctors)         | #3 typedef, #11 toplevel pre-register   | Pre-register only handles **FnStmt (tag 121)** and recurses Documented. **TypedefStmt (122) is NEVER pre-registered.** Constructor visibility is order-dependent: a fn body in `src/effects.mn` referencing `EfPure` only resolves if `effects.mn`'s typedef textually precedes it within the same file AND the pre-register pass doesn't disturb scope. |
| A (ADT ctors)         | #3 typedef                              | Cross-file: `src/cache.mn` references `EfPure` (defined in `src/effects.mn`). Concatenation order under `cat src/*.mn lib/**/*.mn` is alphabetical → `cache.mn` comes BEFORE `effects.mn`. So even a correct typedef arm cannot project the ctor in time. |
| B (top-level fns)     | #11 pre-register, #2 FnStmt             | Pre-register reaches every FnStmt by recursion; the test for tag 121 is correct. Suspect: same alphabetical-order issue is NOT present for fns because pre-register runs whole-list before walking; or — substrate-honest — the fns reaching `E_MissingVariable` are referenced by pat/match arms inside `lib/runtime/*.mn` whose enclosing file is processed AFTER pre-register runs but the names looked up don't match because `$str_eq` in `$env_lookup` uses heap-ptr equality on a different allocation than the one pre-register stored. |
| B (top-level fns)     | #2 FnStmt re-extend                     | After body walk, FnStmt re-extends env at `walk_stmt.wat:650-653` — but **after `$env_scope_exit` at line 648**. The exit pops the fn-body scope; the re-extend lands at parent scope. Correct. Not the bug. |
| C (local names)       | #1 LetStmt, #6 lambda, #7 match-arms     | Lambda arm at `walk_expr.wat:744-768` **drops `params` at line 751** with explicit comment "Hβ.infer.lambda-params". A wheel-source lambda `(x) => x + 1` produces no env-extend for `x`; body's VarRef misses. **This is the dominant Family C cause** since every closure-style local in wheel source flows through lambda. |
| C (local names)       | #1 LetStmt                              | Let arm delegates to `$infer_walk_pat`. PVar arm at `walk_expr.wat:874-888` env-extends correctly. Suspect: scope-exit-clobbering during multi-stmt block walks — verify via diagnostic harness in §2. |

---

## §2 Localizing the bug (proof, not hypothesis)

### §2.1 Diagnostic harness — `bind_completeness_diag.wat`

A new trace harness MUST be authored at
`bootstrap/test/infer/bind_completeness_diag.wat` and added to
`bootstrap/CHUNKS.sh` per the harness convention of
`walk_stmt_block_with_stmts.wat`. The harness drives lex+parse+
`$inka_infer` on each shape and asserts no `E_MissingVariable` fires
on the bound names (chase the AST handle through `$graph_chase`;
`$gnode_kind` MUST not be `NErrorHole`):

| Phase | Synthetic source                                                           | What it isolates                              |
|-------|----------------------------------------------------------------------------|-----------------------------------------------|
| C.1   | `{ let n = 5; n + 1 }`                                                      | BlockExpr two-stmt sibling visibility (LetStmt → next-stmt VarRef) |
| C.2   | `{ let n = 5; let m = n; m }`                                               | let-let chain; counter-substrate correctness  |
| C.3   | `fn f(name) = { let path = name; path }`                                    | fn-param visible inside nested let-block      |
| C.4   | `match x { Some(v) => v, None => 0 }`                                       | match-arm-pattern PVar visible in arm body    |
| C.5   | `(x) => { let merged = x; merged }`                                          | **lambda-param visibility** (predicted to FAIL — the lambda arm drops params) |
| A.1   | `type T = A \| B(int); fn k(x) = A`                                          | nullary ctor visibility within same file      |
| A.2   | `type T = A; fn k() = A` then second concatenated stmt list `type U = ...`   | typedef-then-fn ordering check                |
| A.3   | `fn k() = EfPure` (single-stmt, no preceding typedef)                       | UNRESOLVED — confirms typedef-not-pre-registered |
| B.1   | `fn a() = 0` then `fn b() = a()` (both at toplevel)                          | Pre-register correctness for forward-reference |

Each phase MUST PASS before the walkthrough's §5 ships as its
authoritative diagnosis. **A shape that fails IS the residue
location for that family.**

### §2.2 Existing harness audit

The Phase B existing harnesses (`walk_stmt_let_simple.wat`,
`walk_stmt_fn_monomorphic.wat`, `walk_stmt_block_with_stmts.wat` per
`walk_stmt.wat:58-61`) test:

- `walk_stmt_let_simple.wat` — single-stmt `let x = 5;` outside a block;
  asserts let-stmt arm completes. Does NOT test sibling visibility.
- `walk_stmt_fn_monomorphic.wat` — `fn id(x) = x`; asserts fn arm
  + param env-extend + body resolves param. Tests one fn-param visibility,
  but only inside an immediate body-expr, NOT inside a nested let or
  block.
- `walk_stmt_block_with_stmts.wat` — `{ let x = 5; x }`. Tests Phase C.1
  exactly. Asserts block handle is NBOUND not NErrorHole. **This
  harness already passes per Hβ.infer cascade closure.**

The existing coverage proves Family C.1, C.3 (param-only) work in
isolation. It does NOT cover C.5 (lambda), A.* (typedef-cross-stmt),
nor B.* (forward-reference fn). The empirical err shape confirms the
gap.

### §2.3 Real-source bisection

The probe `cat lib/runtime/strings.mn | wasmtime run bootstrap/mentl.wasm
2> /tmp/strings.err` would scope the bug to a single file. Predicted
output: Family A names (`EfPure` etc.) drop out (no effect typedefs in
`strings.mn`), Family B names (`make_list`, `list_index` if they're
defined elsewhere) drop out, Family C names (`n`, `i`, `acc`) likely
appear if multi-stmt sibling visibility or lambda-param drift fires
inside `strings.mn`. **This bisection is the empirical narrowing
between "ordering bug" and "bind-form bug."**

The probe is named as a Plan A.2 verification step. It IS executable
today against the existing seed image; its output composes with §2.1's
synthetic harnesses to isolate each family.

---

## §3 Eight interrogations per failing arm

### §3.1 Lambda arm (Family C dominant cause)

| # | Interrogation | Answer |
|---|---|---|
| 1 | Graph?       | The lambda's AST handle binds to `TFun(params, TVar(body_h), row_h)`. The `params` slot is currently `make_list 0` per `walk_expr.wat:759` — so **the graph carries an empty parameter type list when the parser emitted N params**. Per kernel primitive #1, this is a wrong graph projection: the parser's params shape is being discarded. |
| 2 | Handler?     | `$infer_walk_expr_lambda` is the projection. Resume discipline: OneShot (single recursive descent into body). Mentl's MultiShot oracle would replay this arm with each candidate param-type; that's a downstream consumer, not the arm's own discipline. |
| 3 | Verb?        | Lambdas appear as RHS of `\|>` chains; not relevant at the bind site. |
| 4 | Row?         | `row_h` is fresh (line 754); body walks under `walk_expr_inf_enter_fn(row_h)`. Correct. Row is not the bug surface. |
| 5 | Ownership?   | Each param is a fresh binding-introduction. No `Consume` at the bind site. |
| 6 | Refinement?  | Each param scheme is `Forall([], TVar(param_h))` — monomorphic. Generalization at lambdas is forbidden (`infer.mn` only generalizes at FnStmt exit). |
| 7 | Gradient?    | Param annotations (when present) would compile-time-pin the param TVar; absent, it's runtime-inferred. Not the failing surface. |
| 8 | Reason?      | Each param env-extend MUST carry `Located(span, Declared(param_name))` — the same shape as FnStmt at `walk_stmt.wat:600-603`. |

### §3.2 Toplevel pre-register (Family A cause)

| # | Interrogation | Answer |
|---|---|---|
| 1 | Graph?       | Pre-register projects each toplevel-bindable name into env BEFORE walking any body. Currently it projects only FnStmt names. **TypedefStmt's variants are NOT projected** — they wait for the typedef arm's mid-walk env_extend, which means a body stmt earlier in the stream than the typedef cannot resolve the ctor. |
| 2 | Handler?     | `$infer_pre_register_stmt` dispatches on tag. OneShot recursion through Documented (128). Adding tag 122 (typedef), 123 (effect-decl), 124 (handler-decl) is the residue. |
| 3 | Verb?        | N/A at toplevel. |
| 4 | Row?         | Each ctor's TFun row_h is fresh per typedef arm (`walk_stmt.wat:834`). Pre-register would build placeholder row_h identically. |
| 5 | Ownership?   | Constructors don't consume; binding-introduction only. |
| 6 | Refinement?  | ConstructorScheme carries `(tag_id, total)` — refinement bound `0 <= tag_id < total` is satisfiable by construction. |
| 7 | Gradient?    | Ctors are nominal; no annotation needed. |
| 8 | Reason?      | `Located(span, Declared(vname))` per `walk_stmt.wat:844-846`. Pre-register replicates this. |

### §3.3 Handle arm (Family C tail; also gates handler-effect tracking)

The seed handle arm at `walk_expr.wat:1136-1168` does NOT walk
arm-pattern PVars into env via `$infer_walk_pat`. The handler arms in
`src/main.mn` and `src/pipeline.mn` carry effect-op pattern bindings
(`PerformEffect(name, args)` syntax in handler arms) whose payload
PVars must env-extend into the arm body's scope. The seed-stub at line
1158 (`$walk_expr_handle_arm_iter`) is a closed substrate-stub per
Hβ.infer.handler-stack — its body does not walk arm patterns. This is
a Family C tail contributor (any handler-arm-bound name like
`resume`, `payload`, `result` will miss) and is named as peer
walkthrough `Hβ.infer.handler-arm-bindings`.

---

## §4 Forbidden patterns per drift mode

The eight Mentl drift modes, named with the specific forbidden form for
each arm-residue. Each drift named below WILL surface in §5 if the
implementer reaches for the foreign-fluent shape; refuse it.

- **Drift 1 (Rust vtable, closure-as-vtable):** REFUSE writing the
  pre-register-stmt dispatch as a function-pointer table indexed by
  tag. Mentl dispatch is structural (graph-resident ADT tag); the
  walk-stmt arms branch on tag with `if (i32.eq tag 122) ...`. The word
  "vtable" never appears in any correct description of this dispatch.

- **Drift 2 (Scheme env frame):** REFUSE adding a "parent env pointer"
  to the binding record to thread parent scope; the env's flat
  scope-stack with explicit `$env_scope_enter`/`_exit` IS the substrate.
  Each scope is a flat record-list, not a parent-linked frame.

- **Drift 3 (Python dict):** REFUSE keying any new env-substrate
  table by string-name in a hashmap; `$env_lookup` does linear scan
  of frame-buf with `$str_eq`. Adding a side-index of "names already
  pre-registered" to optimize is forbidden — the linear scan IS the
  substrate.

- **Drift 4 (Haskell MTL):** REFUSE composing the pre-register pass
  as a separate handler chained ahead of `$infer_program` (the
  fluent move would be `~> pre_register_handler ~> infer_handler`).
  Pre-register IS one stage of `$infer_program`, not a peer handler;
  it's a phase-internal projection.

- **Drift 5 (C calling convention):** REFUSE adding an `__env`
  parameter alongside `__handle` and `__span` to the bind-form arms
  to thread "current env." The scope stack is global state in
  `env.wat` (per `runtime/env.wat:105-107` `$env_scopes_ptr`) — that
  is the unified `__state`. Threading env explicitly is foreign-fluent
  C-shape.

- **Drift 6 (primitive-type special-case):** REFUSE giving lambda's
  param env-extend a different shape than FnStmt's param env-extend.
  Both produce `Forall([], TVar(param_h))` with `schemekind_make_fn`.
  The lambda arm's residue copies the FnStmt arm's param-loop verbatim
  with the same Reason form.

- **Drift 7 (parallel-arrays-instead-of-record):** REFUSE storing
  pre-registered typedef names in a parallel `$pre_registered_ctors`
  list separate from env. Env IS the storage; pre-register's only
  effect is `$env_extend` — same as the typedef arm itself. The
  pre-register pass and the mid-walk typedef arm produce the SAME env
  records.

- **Drift 8 (string-keyed-when-structured):** REFUSE branching
  pre-register on `tag == 122` literal; tag dispatch must use the
  named sentinel (introduce `STMT_TAG_TYPEDEF` if not already present
  in the parser_infra constants). Mode-as-int is the named drift mode
  8.

- **Drift 9 (deferred-by-omission):** REFUSE landing a fix for
  Family A while leaving Family C lambda-params commented "until
  Hβ.infer.lambda-params lands." Either the lambda arm's param
  env-extend lands in §5 alongside Family A pre-register expansion,
  or the lambda arm is named as peer cascade
  `Hβ.infer.lambda-params-now` and ROADMAP's Phase G closure is
  formally re-opened as **partial**. Land whole or split honestly.

---

## §5 The residue (specified, NOT executed)

Per the contract: §5 specifies the lines that should EXIST. Plan A.2
is a separate dispatch that authors them. The residue is keyed by
family.

### §5.1 Family A — pre-register typedef ctors and effect ops

Edit `bootstrap/src/infer/walk_stmt.wat:428-447` (`$infer_pre_register_stmt`):
extend the tag dispatch to handle typedef (122), effect-decl (123),
and handler-decl (124). The added arms call the SAME registration logic
as the in-walk arms — refactor `$infer_walk_stmt_typedef`'s body
(currently `walk_stmt.wat:794-854`) into a callable
`$infer_register_typedef_ctors` that both pre-register and the in-walk
arm invoke. Same shape for effect-decl (`$infer_register_effect_ops`)
and handler-decl. The in-walk arms become thin wrappers:

```
(func $infer_walk_stmt_typedef ... (call $infer_register_typedef_ctors ...))
```

This preserves drift-7 (no parallel state), drift-9 (one source of
truth for the env_extend per ctor), and drift-1 (tag-dispatch
unchanged).

Wheel canonical: `src/infer.mn:96-149` (`pre_register_fn_sigs`) +
`src/infer.mn:2028-2066` (`register_type_constructors`) — the wheel's
pre-register pass walks all toplevel decls (fns AND typedefs AND
effects AND handlers) before any body walks. The seed currently walks
only FnStmts; the residue extends to all four.

### §5.2 Family B — toplevel fn name allocation hygiene

Hypothesis: pre-register stores names with one heap allocation;
subsequent body lookups receive a different heap allocation of the
same string from the parser's lex stream (each lex of "make_list"
produces a fresh `$str_alloc`). `$str_eq` IS canonical post-Ω.2,
returns `Bool`, compares bytewise — so heap-ptr inequality is fine if
str_eq is correct. **The bisection in §2.3 must confirm whether
Family B names appear in single-file probes; if they do, the bug is
NOT pre-register but `$str_eq` — and we re-open `protocol_str_eq` per
the bug-classes ledger.** No residue lands for Family B until §2.3
runs. Plan A.2 includes the bisection probe as its first step.

### §5.3 Family C — lambda-param env-extend

Edit `bootstrap/src/infer/walk_expr.wat:744-768`
(`$infer_walk_expr_lambda`). Currently line 751 reads:

```
(drop (i32.load offset=4 (local.get $expr)))   ;; params (Hβ.infer.lambda-params)
```

The residue replaces this with the param-loop pattern from FnStmt
`walk_stmt.wat:585-605` (the "mint fresh" branch), since lambda has no
pre-register and always mints. The loop:

1. Loads `params` (offset 4).
2. For each param: load `param_name` at offset 4 of the param record;
   `$graph_fresh_ty` for the param handle; `$env_extend` with
   `scheme_make_forall([], ty_make_tvar(param_h))`,
   `reason_make_located(span, reason_make_declared(param_name))`,
   `schemekind_make_fn`.
3. Build `tparam_list` via `$walk_stmt_build_inferred_params`.
4. Replace line 759's `make_list 0` with `tparam_list`.

Drift-6 closure: lambda's residue IS the FnStmt residue; same Reason
shape, same SchemeKind, same Forall pin. No special-casing.

Drift-9 closure: this lands AS THE SAME COMMIT as Family A pre-register.
ROADMAP Phase G is re-stamped as **closed-with-Hβ.infer.bind-completeness**
in the same commit.

### §5.4 Family C tail — handle arm pattern bindings

Named as peer cascade `Hβ.infer.handler-arm-bindings` requiring its
own walkthrough. Plan A.2 does NOT include this. The empirical err
contributions from this arm (`resume`, `payload`-style names) are
documented in §3.3 but don't ship a residue here.

---

## §6 Composition with prior closures

- **Phase B (B.5 match-pattern):** verified in §1 row 7 — `$infer_walk_pat`
  PVar at `walk_expr.wat:874-888` env-extends correctly. Phase B's
  closure stands. The B.5 walkthrough `Hβ-infer-substrate.md §13.3 #5`
  did not test sibling-visibility under a multi-arm match; the
  diagnostic phase C.4 in §2.1 closes that gap.

- **Phase G (`$sys_main` retrofit, `fe5e944`):** the gate harness
  `main_mentl_infer_smoke.wat` exercises `$inka_infer` with a single
  LetStmt PVar. The substrate-honesty audit declares Phase G's
  closure **harness-coverage-incomplete** — it passes its own bar
  but does not characterize wheel-source viability. ROADMAP entry
  for Phase G must be amended in the Plan A.2 commit:
  `closed (gate harness PASS) — pending Hβ.infer.bind-completeness`.

- **Hβ-arena-substrate (`d57e20c`):** verified that env_extend
  allocations route to `$perm_alloc` per arena handler-swap-promotion.
  Not implicated in this walkthrough.

- **Hβ.infer cascade closure (commit `b6e1f23` 2026-04-27, 11/11
  chunks):** the cascade closure was **structurally complete** (all
  walked Stmt/Expr arms exist; all 25 trace harnesses PASS). It was
  NOT **bind-completeness-complete** for wheel-source — the harness
  diet covered single-arm cases. This walkthrough is the
  bind-completeness audit the cascade closure deferred.

- **Hβ.infer cascade closure (commit `c53904d` 2026-04-28,
  Hβ.lower):** unaffected — lower walks LowExpr post-infer, doesn't
  re-enter env.

---

## §7 Acceptance criteria

The Plan A.2 fix is gated on:

1. All 76/76 existing harnesses PASS post-fix (non-regression).
2. New `bind_completeness_diag.wat` PASS — all 9 phases (C.1-C.5,
   A.1-A.3, B.1) green.
3. Real-source probe:

   ```
   cat lib/runtime/strings.mn | wasmtime run bootstrap/mentl.wasm 2> /tmp/strings.err
   grep -c E_MissingVariable /tmp/strings.err   # MUST be 0 for every name
                                                # bound by let/fn/lambda/match/handle
                                                # in strings.mn
   ```

4. Full-wheel probe:

   ```
   cat src/*.mn lib/**/*.mn | wasmtime run bootstrap/mentl.wasm 2> /tmp/wheel.err
   awk '/E_MissingVariable:/ {print $2}' /tmp/wheel.err | sort -u | wc -l
   ```

   MUST drop from 100 to 0 for Families A, B, C.1-C.4. C.5 (lambda)
   names disappear iff §5.3 lands. Family C tail (handler-arm
   bindings) MAY remain non-zero pending peer cascade
   `Hβ.infer.handler-arm-bindings`; their absence-count is documented.

5. `bash bootstrap/first-light.sh` Tier 1 PASS (non-regression).

6. `bash tools/drift-audit.sh
       bootstrap/src/infer/walk_stmt.wat
       bootstrap/src/infer/walk_expr.wat
       bootstrap/test/infer/bind_completeness_diag.wat`

   exits 0.

---

## §8 Surpass-or-don't-borrow

- **Borrowed:** env-as-scope-frame-list (every functional language
  with HM has this).

- **Surpass — Reason-resident:** every binding's Reason edge is
  graph-resident (4-tuple field per `runtime/env.wat:60-70`); the Why
  Engine walks back from any binding to its declaration site.
  OCaml/Haskell env entries are anonymous — they bind name→type, not
  name→(type, why). Mentl's env IS the Why-substrate.

- **Surpass — buffer-counter substrate:** `frame_len` at offset 1 of
  the frame record is the single source of truth for logical length;
  `$len(buf)` is forbidden for logical-length purposes (per
  `runtime/env.wat:114-120`). The bug class "list_extend_to
  count-vs-capacity conflation" cannot fire. Other languages either
  conflate (Lisp's `length`) or hide behind iterators.

- **Surpass — productive-under-error:** env_lookup miss binds
  `NErrorHole` and continues; the walk doesn't abort. The empirical
  err's 1068 lines ARE the productive-under-error projection — every
  miss is a continued walk, not a halt. OCaml's type-checker halts at
  first error. Mentl's IS Hazel-compatible.

- **Surpass — gradient-pinnable:** `Forall([], TVar(h))` IS the
  monomorphic gradient pin. Adding a `: T` annotation to a let-binding
  promotes `Forall([h], TVar(h))` → compile-time TVar substitution.
  No other language conflates "monomorphic let" with "annotated let"
  via the same Forall machinery.

- **Surpass — handler-swappable:** the env scope-stack IS a handler
  on graph + env; arena handler-swap-promotion (per
  `Hβ-arena-substrate.md`) lets the same env API run under different
  allocation discipline (perm/scoped/copy) by handler-swap. Other
  languages bake the allocator into the env type.

---

## §9 Four-axis pre-audit

1. **Eight interrogations answered:** §3 covers lambda arm and
   pre-register pass; handle-arm deferred to peer cascade per drift-9.

2. **SYNTAX.md alignment:** verified `let x = E` is statement-form
   (not expression `let x = E in F`). Per the parser tag 120 LetStmt
   layout `[tag][pat][val]`: a let-stmt's binding extends through
   the rest of the enclosing block-body (no explicit `in`-scope).
   The walk_stmt_let arm at `walk_stmt.wat:472-490` matches.

3. **SUBSTRATE.md §I (Graph + Env) alignment:** flat-record-list per
   scope; bindings are 4-tuples (name, scheme, reason, kind);
   `scope_enter`/`scope_exit` manage the stack. Verified against
   `runtime/env.wat:62-70 + 105-107 + 264-288`. The substrate is
   correct; the bug is in the consumers (typedef pre-register,
   lambda-param).

4. **Wheel canonical alignment:** `src/infer.mn:1588-1591` (let-PVar
   shape — Forall-empty mono pin), `:262-369` (infer_fn — two-pass
   with pre-register-extended placeholder, body walk, generalize,
   re-extend), `:1701-1733` (match arms — scope_enter, walk pat,
   walk body, unify, scope_exit), `:96-149` (pre_register_fn_sigs —
   the wheel walks fns AND typedefs in toplevel pre-register, which
   the seed truncates), `:2028-2066` (register_type_constructors —
   the wheel's typedef projection). Verified.

---

## §10 Riffle-back audit (mandatory per Anchor 7)

- **Phase B (B.5 match-pattern, 2026-04-29):** the closure DID
  include PVar env_extend (verified `walk_expr.wat:874-888`). The
  closure DID NOT test multi-arm sibling visibility or
  handler-arm-pattern bindings — both deferred (the latter to peer
  cascade `Hβ.infer.handler-arm-bindings`).

- **Phase G (`fe5e944`):** gate-harness shape was single-stmt
  `fn main(x) = x`. The harness coverage gap is the audit subject of
  this walkthrough. Phase G remains structurally closed; its
  bind-completeness gate is this walkthrough + Plan A.2.

- **Hβ-arena (`d57e20c`):** env_extend allocations route to
  `$perm_alloc` per arena handler-swap-promotion. Verified at
  `runtime/env.wat:127-132` (`$env_frame_make` uses `$make_record`
  which routes through arena). Not implicated in this walkthrough.

- **Convergence audit (Anchor 7 #4):** three instances earn the
  abstraction. The `register_typedef_ctors` callable extracted from
  `$infer_walk_stmt_typedef` (proposed in §5.1) becomes:
  - Instance 1: in-walk typedef arm (existing).
  - Instance 2: pre-register typedef arm (new in §5.1).
  - Instance 3: future cache-rehydrate typedef arm (named at
    `Hβ-link-protocol.md` rehydrate-from-cache pass — the cache
    stores typedef constructors per `cache.mn:175-179` and the
    rehydrate path will re-`$env_extend` from the unpacked
    ConstructorScheme).

  Three instances earn the abstraction. The refactor lands now per
  the plan; the third call site lights up at cache-rehydrate.

---

## §11 What Plan A.2 will edit

Plan A.2's separate dispatch will:

1. Author `bootstrap/test/infer/bind_completeness_diag.wat` (the §2.1
   harness, all 9 phases). Run the bisection probe per §2.3 to
   isolate Family B's contribution.

2. Refactor `walk_stmt.wat:794-854` typedef arm body into callable
   `$infer_register_typedef_ctors`; add same-shape callable for
   effect-decl. Make in-walk arms thin wrappers.

3. Extend `$infer_pre_register_stmt` (`walk_stmt.wat:428-447`) to
   dispatch tags 122 (call `$infer_register_typedef_ctors`), 123 (call
   `$infer_register_effect_ops`), 124 (call existing handler-decl
   stub).

4. Add lambda-param env-extend loop to `$infer_walk_expr_lambda`
   (`walk_expr.wat:744-768`) per §5.3 residue.

5. Re-run drift-audit; re-run all 76 harnesses; re-run wheel probe;
   verify the 100-name list collapses.

6. ROADMAP entry for Phase G amended:
   `closed (gate + Hβ.infer.bind-completeness)`.

---

## §12 Named peer follow-ups

- **`Hβ.infer.handler-arm-bindings`** — handler-arm pattern PVars
  (`resume`, payload bindings, op-arg bindings) MUST env-extend into
  arm body's scope. Currently `$walk_expr_handle_arm_iter` is a
  seed-stub. Walkthrough deferred; named here per drift-9 honesty.

- **`Hβ.infer.toplevel-pre-register-cross-file`** — if §2.3
  bisection shows Family B fails for forward-references across files,
  this peer cascade addresses cross-file visibility (composes with
  `Hβ-link-protocol.md` cache-rehydrate boundary).

- **`Hβ.infer.lambda-params-annotated`** — when parser surfaces
  lambda-param annotations (currently parser drops them), the lambda
  arm's residue extends to honor the annotation as a gradient pin
  (Forall-quantifier promotion).

- **`Hβ.infer.match-exhaustive`** — exhaustiveness check for match
  arms; named by `walk_expr.wat:1067-1069`. Independent of
  bind-completeness.
