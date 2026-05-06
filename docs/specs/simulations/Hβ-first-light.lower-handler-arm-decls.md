# Hβ-first-light.lower-handler-arm-decls

> **Status:** `[LIVE 2026-05-06]` — empirically-real Phase H first-light
> handle. Bug reproduces verbatim against HEAD seed; `wat2wasm`
> hard-rejects the seed's output for any program whose lowered LowExpr
> stream contains an `LDeclareFn` (313) — i.e. every program with at
> least one effect op invocation that survives infer ground-row
> resolution.
>
> **Authority:** `Hβ-first-light-empirical.md` §2.3 (cascade rebase
> 2026-05-05 — handler-arm fns named alongside the parser closure +
> match-arm-pat-binding-local-decl + nullary-ctor-call-context handles
> already CLOSED); `Hβ-first-light-residue.md` (cascade context);
> `bootstrap/src/lower/walk_handle.wat:260-297` (the
> `$lower_handler_arms_as_decls` substrate that produces the
> LDeclareFn list for every handler decl);
> `PLAN-to-first-light.md` (live first-light tracker).
>
> **Claim in one sentence:** **`$lower_handler_arms_as_decls`
> (walk_handle.wat:263-297) already builds a real `LDeclareFn(LowFn(
> "op_" + op_name, len(args), args, [lo_body], Pure))` per handler
> arm and `$lower_handle` (walk_handle.wat:340-385) already prepends
> that list onto the `LBlock` it returns — but the four emit-side
> walks (`$cfn_walk` for table-name collection, `$emit_functions_walk`
> for module-level `(func ...)` emission, `$max_arity_expr` for the
> type-section ceiling, `$emit_let_locals` for the local-decl
> boundary) lack tag-313 arms; the residue is to add LDeclareFn arms
> structurally symmetric to the existing LMakeClosure (311) /
> LMakeContinuation (312) arms in the first three walks (third
> caller earns the abstraction per Anchor 7 + ULTIMATE_MEDIUM §6
> "composition not invention"), plus pass-through LHandle (332) /
> LHandleWith (329) recursion arms in the same three walks so nested
> closures / nested LDeclareFn entries inside handler bodies get
> found, plus a comment-only extension to `$emit_let_locals`
> documenting the LDeclareFn fn-boundary symmetry.**

---

## §0 Status header + evidence

### 0.1 Substrate landings since walkthrough authoring

This walkthrough is authored at the empirical-pre-audit gate after
`$lower_handler_arms_as_decls` was made real (commit ancestral to
HEAD; walk_handle.wat:263-297 now constructs LDeclareFn entries for
every arm) and after `$lower_handle` was made to prepend them
(walk_handle.wat:340-385). The four emit-side walks were authored
BEFORE LDeclareFn became substrate-bearing; they handle LMakeClosure
+ LMakeContinuation (the previous two callers) but not LDeclareFn
(the third). The riffle-back is therefore: lower-side substrate
moved forward; emit-side has not yet caught up — exactly the shape
ULTIMATE_MEDIUM §6 names as "composition not invention" residue.

### 0.2 Empirical reproduction (verbatim §A.4 evidence)

Per the mentl-implementer §A pre-audit gate, the bug reproduces
against HEAD seed (`bootstrap/mentl.wasm`, 125671 bytes, built clean
2026-05-06 03:41).

Input program (effect-only minimal repro — handler decl deferred
since handler-decl infer-stage hits NFre10 upstream, so the cleanest
single-axis demonstration is the perform-without-handler form that
still emits a `(call $op_<name>)` LDeclareFn-target):

```
effect Counter {
  next() -> Int @resume=OneShot
}

fn main() = perform next()
```

Stage-1 `wasmtime run bootstrap/mentl.wasm` exits 0, empty stderr.
Output `$main` body emitted by the seed:

```
  (func $main (param $__state i32) (result i32) ...
(call $op_next)  )
```

The body emits `(call $op_next)` from `$emit_lperform`
(`bootstrap/src/emit/emit_handler.wat`) — but `$op_next` is NOT
declared anywhere in the module, because `$emit_functions_walk`
(main.wat:1241-1319) has no LDeclareFn (313) arm: it only emits
fn bodies for LMakeClosure (311) and LMakeContinuation (312).

`wat2wasm /tmp/h2.wat -o /tmp/h2.wasm` rejects with:

```
/tmp/h2.wat:15:7: error: undefined function variable "$op_next"
(call $op_next)  )
      ^^^^^^^^
```

§A.1 acceptance gate clears: stage-1 exits 0 with empty stderr;
`(call $op_next)` appears with `$op_next` NOT in any `(func
$op_next ...)` declaration; `wat2wasm` emits exactly the expected
`undefined function variable "$op_next"` error.

Acceptance for §A.2 (substrate-side LDeclareFn list construction):
`bootstrap/src/lower/walk_handle.wat:263-297` is fully implemented.
Each loop iteration calls `$lower_handler_arm_body` to lower the
arm body under a scoped arg-bind; constructs `$fn_name` =
`str_concat("op_", op_name)` (line 283; `i32.const 504` is the
"op_" string-data); wraps in a single-element body list and a
`$lowfn_make` record (line 287-292) with `$row_make_pure`; then
appends `$lexpr_make_ldeclarefn(fn_ir)` to the buffer at line 294.
The substrate IS already there.

Acceptance for §A.3 (emit-side absence): `bootstrap/src/emit/main.wat`
lines 1241-1319 (`$emit_functions_walk`) has tag-311 arm at line
1247-1253 and tag-312 arm at line 1255-1261; NO tag-313 arm exists
between them or below them. `$cfn_walk` lines 485-575 — same shape;
LMakeClosure at 491, LMakeContinuation at 503, no LDeclareFn.
`$max_arity_expr` lines 644-726 — LMakeClosure at 689,
LMakeContinuation at 696, no LDeclareFn. `$emit_let_locals` lines
958-1014 — LMakeClosure / LMakeContinuation noted at line 1010 as
fn-boundary terminals; LDeclareFn unmentioned.

### 0.3 Scenario classification

**Scenario W (walk-omission)** confirmed: the LDeclareFn LowExpr
node IS produced by lower; it IS reachable by the four walks via
the LBlock-of-stmts shape `$lower_handle` returns (arm_decls list
prepended to body, then LBlock-wrapped at walk_handle.wat:380-385);
but each of the four walks short-circuits at unrecognized tags
because their tag-eq-int chain has no 313 arm. The fix is purely
structural arm-addition; no new tags, no new accessors, no new
records.

Scenarios L (lower bug) and S (state.wat ledger gap) DO NOT
apply: lower-side substrate is correct
(`$lower_handler_arms_as_decls` produces structurally-valid
LDeclareFn records); the seed has no separate state.wat ledger for
function-table or function-emission decisions — both derive
streaming through the same four walks at emit time.

---

## §1 Claim

`$lower_handler_arms_as_decls` (walk_handle.wat:263-297) projects
each handler arm to `LDeclareFn(LowFn("op_" + op_name, len(args),
args, [lo_body], Pure))` per src/lower.mn:745-755 wheel canonical;
`$lower_handle` (walk_handle.wat:340-385) returns
`LBlock(h, arm_decls ++ [LHandle(h, body, arm_records)])` so the
LDeclareFn list flows through `$inka_emit`'s top-level LowExpr
stream. The four emit walks (`$cfn_walk` for fn-name table
collection; `$emit_functions_walk` for `(func ...)` body emission;
`$max_arity_expr` for the (`$ftN`) type-section arity ceiling;
`$emit_let_locals` for fn-preamble local-decl boundary) MUST gain
LDeclareFn (313) tag arms structurally symmetric to LMakeClosure
(311) and LMakeContinuation (312), AND gain LHandle (332) /
LHandleWith (329) body-recurse arms so nested closures and nested
LDeclareFn entries inside handler bodies get found — mirroring how
the existing LBlock / LIf / LCall / LBinOp arms recurse.

---

## §2 Eight interrogations

| # | Interrogation | Resolution |
|---|---|---|
| 1 | **Graph?** | LDeclareFn's `fn` field at record offset 0 (`$lexpr_ldeclarefn_fn` at lexpr.wat:452); LowFn's `name` at record offset 0 (`$lowfn_name`); LowFn's `body` at offset 4 (`$lowfn_body`); LowFn's `arity` at offset 2 (`$lowfn_arity`). LHandle's `body` at offset 1 (`$lexpr_lhandle_body` at lexpr.wat:722); LHandleWith's `body` at offset 1 + `handler` at offset 2 (`$lexpr_lhandlewith_body` / `$lexpr_lhandlewith_handler` at lexpr.wat:668-672). The graph already carries every handler-arm fn's name string-pointer + body LowExpr at the LowFn record level. The residue is one structural arm per walk + one body-recurse arm per walk; no parallel ledger. |
| 2 | **Handler?** | Direct emit projection. `$emit_functions_walk` IS the handler over LowExpr containers that produces `(func $name ...)` declarations; `$cfn_walk` IS the handler that collects names for `(table $fns N funcref)` + `(elem $fns ...)` + `(global $name_idx i32 ...)`; `$max_arity_expr` IS the handler that derives `($ftN)` type-section ceiling. `@resume=OneShot` (no continuation capture; structural walk). The residue extends each handler's tag-eq-int chain with one new arm per missing case — same shape as the existing arms. |
| 3 | **Verb?** | N/A — structural recursive walk. The five verbs apply at composition boundaries; this is intra-handler descent. |
| 4 | **Row?** | `EmitMemory` effect for `$emit_functions_walk` (writes to `$out_base` via `$emit_fn_body`); `Pure` for `$cfn_walk` and `$max_arity_expr` (data-flow projections only — return values, no I/O). Same row as the LMakeClosure / LMakeContinuation arms; the LDeclareFn arm inherits. |
| 5 | **Ownership?** | LowExpr / LowFn records `ref`-borrowed throughout each walk; no consume; the `$names` list in `$cfn_walk` is mutated via `$list_extend_to` + `$list_set` per Ω.3 buffer-counter discipline (already-used by the LMakeClosure / LMakeContinuation arms). |
| 6 | **Refinement?** | `$lexpr_ldeclarefn_fn(r)` returns a non-zero LowFn pointer per the arity-1 LDeclareFn contract (`$lexpr_make_ldeclarefn` at lexpr.wat:446-450). `$lowfn_name(fn_r)` returns a non-zero string-pointer per `$lower_handler_arms_as_decls` line 283 (`str_concat` of "op_" + op_name where op_name is itself the parser-emitted string from the handler arm). `$lowfn_body(fn_r)` returns a non-zero list-pointer per walk_handle.wat:284-286 (single-element body list). The walk relies on these contracts; `(i32.lt_u $expr $heap_base)` guard at the walk entrance handles sentinel inputs. |
| 7 | **Gradient?** | The arm walks derive the answer from the LowExpr substrate at emit-time; this is the runtime fallback. The compile-time capability that would unlock dropping the walks is "lower carries an explicit fn-emission set on the LowProgram record" — peer follow-up `Hβ.emit.lowprogram-carries-fn-emission-set`, NOT in scope here (gradient-7 cash-out for compile speed; pure refactor, no semantic change). |
| 8 | **Reason?** | LDeclareFn's record-level handle is 0 per `lexpr_handle(LDeclareFn(_)) => 0` lock at lexpr.wat:170 (the LowFn carries its own handle via `$lowfn_handle` at the per-statement level if a caller needs one). LowFn's name string-pointer preserves the source-level "op_" + op_name binding chain; the Why Engine walks back to the handler arm via the parent LHandle's handle field (offset 0). This walk does not write Reasons (emit-time, not infer-time). |

---

## §3 Forbidden patterns

| Drift mode | Refusal at this site |
|---|---|
| **1** (Rust vtable) | NO `$emit_walk_table`, NO closure-as-vtable, NO function-pointer array dispatch on LowExpr tag. Tag-int comparison via `(i32.eq (local.get $tag) (i32.const N))` chain — same shape as the existing LMakeClosure / LMakeContinuation arms in each of the four walks. The word "vtable" does not appear in this commit. |
| **6** (Bool special-case) | LDeclareFn (313) is structurally symmetric to LMakeClosure (311) and LMakeContinuation (312) — all three wrap a LowFn that becomes a module-level `(func ...)`. The LDeclareFn arm uses the SAME field accessors (`$lowfn_name`, `$lowfn_body`, `$lowfn_arity`), the SAME buffer-counter discipline (Ω.3), the SAME recursion shape. NO "module-level fn declarations are special because they have no runtime slot" carve-out in the walks; the substrate-level handle=0 anomaly is already absorbed at lexpr.wat:170-180. |
| **7** (parallel arrays) | NO `fn_emission_names` accumulator separate from the `$names` buffer the LMakeClosure / LMakeContinuation arms already write into. The LDeclareFn arm writes into the SAME buffer. NO parallel `(name, body)` lists; the LowFn record is the unified record. |
| **8** (string-keyed-when-structured) | Tag-int dispatch via `$tag_of`; LowFn name is a string-pointer because WAT's `$<name>` token surface IS string-shaped, not because we are flag-as-int-ing structure. Each LowExpr variant is its own ADT tag. |
| **9** (deferred-by-omission) | All four walks gain their LDeclareFn arms in **this commit**. All three walks that recurse (cfn_walk, emit_functions_walk, max_arity_expr) gain LHandle (332) AND LHandleWith (329) body-recurse arms in **this commit** — Lock #2. NO "LDeclareFn arm in cfn_walk now, the emit arm next session." NO "LHandle body recurse next time." Land whole, OR name peer handles in §B.12. |

Peer follow-ups (Drift-9 named, NOT deferred-by-omission):

- `Hβ.first-light.handler-arm-fn-idx-globals` — IF §E.2 still
  shows `(global $<name>_idx i32 (i32.const N))` undefined-global
  errors post-fix (i.e. the `$op_<name>_idx` globals are missing
  from the LDeclareFn-fed globals emission), the peer handle
  fixes `$emit_fn_table_and_globals` to emit a `<name>_idx`
  global per LDeclareFn fn name. NOT in scope here per Lock #3
  expectation that fn_idx globals fall out automatically once
  `$cfn_walk` collects the LDeclareFn names — the names list
  feeds `$emit_fn_table_and_globals` (main.wat:760-820) which
  already emits `(global $<name>_idx i32 (i32.const N))` per name
  it receives.
- `Hβ.emit.lowprogram-carries-fn-emission-set` — gradient-7
  cash-out: lower carries an explicit fn-emission name+body set
  on the LowProgram record so emit reads instead of re-walking;
  pure refactor for compile speed, no semantic change.
- `Hβ.first-light.handler-decl-infer-scoping` — §A.1 minimal
  repro with handler decl bottoms out at infer-stage NFre10
  (the handler decl's effect-row resolution; separate from this
  handle's emit-side). Not in scope here.

---

## §4 Edit sites

All in `bootstrap/src/emit/main.wat` (HEAD line numbers; planner
notes the file may have shifted slightly):

| Edit | Site | Action |
|---|---|---|
| **C.1** | Inside `$cfn_walk` at lines 482-575, BEFORE the `;; LLet (304) — recurse into value` comment (line 514) | NEW LDeclareFn (313) arm — extracts `$fn_r` via `$lexpr_ldeclarefn_fn`; appends `$lowfn_name(fn_r)` to `$names` via `$list_extend_to` + `$list_set` + counter store; recurses into `$lowfn_body(fn_r)` via `$cfn_walk_list`. Symmetric to the existing LMakeClosure (311) arm at lines 491-501. |
| **C.2** | Inside `$cfn_walk` at lines 482-575, BEFORE the `;; All other tags: no LowExpr children to recurse into` comment (line 574) | NEW LHandle (332) + LHandleWith (329) body-recurse arms. LHandle: recurse into `$lexpr_lhandle_body`. LHandleWith: recurse into both `$lexpr_lhandlewith_body` AND `$lexpr_lhandlewith_handler`. Per Lock #2: handler-arm bodies are a peer site for nested LMakeClosure / LDeclareFn discovery alongside the top-level LBlocks. |
| **C.3** | Inside `$max_arity_expr` at lines 644-726, BEFORE the `;; Common containers used by current lower output` comment (line 703) | NEW LDeclareFn (313) + LHandle (332) + LHandleWith (329) arms. LDeclareFn: contributes `max($lowfn_arity(fn_r) + 1, max_arity_in($lowfn_body(fn_r)))` — the +1 is the implicit `__state` parameter every fn carries per W7 calling convention. LHandle: recurses into body. LHandleWith: takes max of body and handler. |
| **C.4** | Inside `$emit_functions_walk` at lines 1241-1319, BEFORE the `;; LLet (304) — recurse into value` comment (line 1262) | NEW LDeclareFn (313) arm — extracts `$fn_r` via `$lexpr_ldeclarefn_fn`; calls `$emit_fn_body(fn_r)` to emit the module-level `(func $op_<name> ...)` declaration; recurses into `$lowfn_body(fn_r)` via `$emit_functions` to find nested closures. Symmetric to the existing LMakeClosure (311) arm at lines 1247-1253. |
| **C.5** | Inside `$emit_functions_walk` at lines 1241-1319, BEFORE the `;; All other tags: no LowExpr children to recurse into (literals, locals, globals, etc.). Drop through.` comment (line 1317) | NEW LHandle (332) + LHandleWith (329) body-recurse arms. Symmetric with the LBlock / LIf arms in the same function. |
| **C.6** | Inside `$emit_let_locals` at lines 958-1014, replacing the comment at lines 1010-1012 | EXTEND comment to document the LDeclareFn (313) fn-boundary symmetry alongside LMakeClosure / LMakeContinuation. Document LHandle (332) / LHandleWith (329) body NOT being a fn-boundary (control structures, not fn boundaries — emit_handler.wat sub-emits LHandle bodies inline; locals from those bodies live in the parent fn's local-decl scope). NO code change at this edit — comment-only extension. |

Insertion order (per plan §D, dependency order — **Edit 1** = C.1
of $cfn_walk LDeclareFn, **Edit 4** = C.4 of $emit_functions_walk
LDeclareFn, **Edit 3** = C.3 of $max_arity_expr LDeclareFn +
LHandle + LHandleWith, **Edit 2** = C.2 of $cfn_walk LHandle +
LHandleWith body-recurse, **Edit 5** = C.5 of $emit_functions_walk
LHandle + LHandleWith body-recurse, **Edit 6** = C.6 comment-only
in $emit_let_locals).

The dispatch order (Edit 1 → Edit 4 → Edit 3 → Edit 2 → Edit 5 →
Edit 6) lands LDeclareFn arms first across all four walks (the
critical path closing the §A.1 minimal repro), then LHandle /
LHandleWith body-recurse arms (Lock #2 handling nested closure
discovery), then the comment-only documentation edit.

---

## §5 Locks

1. **Lock #1 — LDeclareFn structurally symmetric to LMakeClosure.**
   The four walks treat LDeclareFn (313) the same as LMakeClosure
   (311) and LMakeContinuation (312) — all three wrap a LowFn that
   becomes a module-level `(func ...)`. Same accessors
   (`$lowfn_name`, `$lowfn_body`, `$lowfn_arity`); same buffer-
   counter discipline; same recursion shape. ULTIMATE_MEDIUM §6
   "composition not invention" — third caller earns the abstraction
   shape, NOT a new invention.

2. **Lock #2 — LHandle (332) + LHandleWith (329) body recursion
   lands in THIS commit.** Three of the four walks (`$cfn_walk`,
   `$emit_functions_walk`, `$max_arity_expr`) gain LHandle +
   LHandleWith body-recurse arms in the SAME commit as the
   LDeclareFn arms. Without these, nested closures + nested
   LDeclareFn entries inside handler arm bodies (e.g. a lambda
   inside an arm body) would not be found. NOT split into a peer
   handle (Drift-9 refusal); land whole.

3. **Lock #3 — `$op_<name>_idx` globals fall out automatically.**
   `$emit_fn_table_and_globals` (main.wat:760-820) emits one
   `(global $<name>_idx i32 (i32.const N))` per name in the names
   list it receives. Once `$cfn_walk`'s LDeclareFn arm appends
   "op_<name>" strings to the names list, `$emit_fn_table_and_globals`
   automatically emits `$op_<name>_idx` globals; no separate
   substrate is needed at this layer. If §E.2 reveals this is NOT
   the case (i.e. the globals are still missing post-fix), the
   peer follow-up `Hβ.first-light.handler-arm-fn-idx-globals`
   lands separately. The implementer verifies by running the
   §A.1 repro through the post-fix seed; if `$op_next_idx` global
   appears, this lock holds.

4. **Lock #4 — NO classify_handler invocation.** `chunk #5` lower
   classify substrate (`bootstrap/src/lower/classify.wat`)
   contains `classify_handler` for the OneShot / Linear / MultiShot
   strategy split. Per walk_handle.wat Lock #4, that classification
   path remains uninvoked at handler-arm decl emission — every
   handler arm gets the same LDeclareFn projection regardless of
   resume strategy at this layer. The strategy split lands at the
   subsequent `$emit_handler.wat` arms, NOT here.

5. **Lock #5 — Wheel parity preserved.**
   `src/lower.mn:789-797` (wheel-side `lower_handler_arms_as_decls`)
   produces the same LDeclareFn list shape as
   `bootstrap/src/lower/walk_handle.wat:263-297`; `src/backends/
   wasm.mn`'s `emit_fns_expr` projection walks LDeclareFn
   structurally symmetric to LMakeClosure (the wheel canonical
   shape). The seed-side fix in this commit brings the four
   bootstrap walks to wheel parity.

6. **Lock #6 — NO change to walk_handle.wat or walk_stmt.wat.**
   This is an emit-only commit. `$lower_handler_arms_as_decls`
   substrate is already correct (walk_handle.wat:263-297);
   `$lower_handle`'s LBlock-prepend is already correct
   (walk_handle.wat:340-385). The `git diff --stat
   bootstrap/src/lower/` MUST be empty at the substrate commit.
   Verification: §E.7 gate.

---

## §6 Forbidden patterns audited per edit site

- **C.1 (LDeclareFn arm in $cfn_walk)** — Drift 1 refused (no
  table; tag-eq-int chain). Drift 6 refused (LDeclareFn = LMakeClosure
  = LMakeContinuation, all three same shape). Drift 7 refused (same
  buffer; no parallel arrays). Drift 8 refused (tag-int dispatch).
  Drift 9 refused (LDeclareFn arm lands this commit).
- **C.2 (LHandle + LHandleWith body-recurse arms in $cfn_walk)** —
  Same shape as the existing LBlock / LIf / LCall arms in the
  same function. Drift 1 refused (tag-int compare). Drift 6 refused
  (no Bool-special). Drift 9 refused (both arms land this commit;
  LHandleWith handles BOTH body AND handler recursion).
- **C.3 (LDeclareFn + LHandle + LHandleWith arms in $max_arity_expr)**
  — Same shape as LMakeClosure arity-contribution at line 689.
  Drift 1 refused. Drift 6 refused. Drift 9 refused (all three arms
  land this commit).
- **C.4 (LDeclareFn arm in $emit_functions_walk)** — Same shape
  as LMakeClosure body-emission at line 1247. Drift 1 refused.
  Drift 6 refused. Drift 7 refused. Drift 9 refused.
- **C.5 (LHandle + LHandleWith body-recurse arms in $emit_functions_walk)**
  — Same shape as the LBlock / LIf / LCall arms in the same
  function. Drift 1 refused. Drift 6 refused. Drift 9 refused.
- **C.6 (comment-only extension in $emit_let_locals)** — NO code
  change; documentation-only. The comment makes the LDeclareFn
  fn-boundary symmetry explicit (matches LMakeClosure +
  LMakeContinuation) and documents the LHandle / LHandleWith
  body-NOT-fn-boundary distinction (control structures, not fn
  boundaries — emit_handler.wat sub-emits inline).

The drift-audit (`tools/drift-audit.sh bootstrap/src/emit/main.wat`)
runs as §E.5.

---

## §7 Tag region

`bootstrap/src/lower/lexpr.wat:87` — LDeclareFn tag 313 unchanged.
`bootstrap/src/lower/lexpr.wat:100` — LHandleWith tag 329 unchanged.
`bootstrap/src/lower/lexpr.wat:103` — LHandle tag 332 unchanged.
NO tag additions; the substrate is purely emit-side projection of
the existing tag region.

---

## §8 Test harness path

`bootstrap/test/lower/handler_arm_decls_smoke.wat` — see §F.
Constructs a hand-authored LowProgram whose top-level LowExpr list
contains a single `LBlock` entry whose stmts are
`[LDeclareFn(LowFn("op_test", 1, [arg], [LLocal($arg)], Pure))]`
(no surrounding LHandle — minimal LDeclareFn-only repro to verify
the four walks pick it up). Calls `$inka_emit`. Scans output for
the substrings `(func $op_test` AND `$op_test_idx` AND
`(elem $fns ... $op_test ...)` exactly once each; verifies
`(call_indirect (type $ft2))` resolves cleanly via the harness's
chunk-list inheritance. Exits 0 on PASS, 1 on FAIL.

The simpler "structural empty harness; verification by sibling
shell-grep on emitted WAT" form per planner §C Edit 7 keeps the
harness compact: it constructs the LDeclareFn record directly via
the lexpr accessors, runs `$inka_emit`, and asserts substring
presence. No need for full pipeline traversal — the test isolates
the four walks at the LowExpr-input boundary.

Registered in `bootstrap/test/INDEX.tsv` per the existing harness
manifest convention (Phase E + Phase F + Hβ.first-light family
precedent rows including
`emit/match_arm_pat_binding_local_decl.wat`).

---

## §9 Drift-9 named follow-ups

Sub-handles NOT landing this commit but explicitly named so they
are tracked, not deferred-by-omission:

- `Hβ.first-light.handler-arm-fn-idx-globals` — only if Lock #3
  fails (§E.2 surfaces residual `(global $op_*_idx ...)` undefined
  globals); not expected per `$emit_fn_table_and_globals` behavior.
- `Hβ.emit.lowprogram-carries-fn-emission-set` — gradient-7
  cash-out: carry the fn-emission name+body set on the LowProgram
  record itself, populated at lower-time, so emit reads instead of
  re-walking. Pure refactor for compile speed; no semantic change.
- `Hβ.first-light.handler-decl-infer-scoping` — the §A.1 minimal
  repro with full handler decl form (`handler h with E { op(x) =>
  ... }`) bottoms out earlier at infer-stage NFre10 (handler decl
  effect-row resolution). Separate from emit-side; named for
  empirical residue tracking.
- `Hβ.emit.handler-arm-classify-strategy-split` — Lock #4
  classify_handler invocation site (lower-time strategy split
  between OneShot / Linear / MultiShot). Lands at the subsequent
  `$emit_handler.wat` strategy-arm split, NOT here.

LDeclareFn arms in cfn_walk + emit_functions_walk + max_arity_expr;
LHandle + LHandleWith body-recurse arms in the same three walks;
$emit_let_locals comment-only extension — ALL included in C.1-C.6;
NOT named as follow-ups (they land this commit).

---

## §10 Verification gates

| Gate | Action |
|---|---|
| **E.1** (primary single-handler smoke) | `echo 'effect Counter { next() -> Int @resume=OneShot } fn main() = perform next()' \| wasmtime run bootstrap/mentl.wasm > /tmp/h2.wat`; verify `/tmp/h2.wat` contains `(func $op_next` AND `(global $op_next_idx i32` AND `$op_next` appears in `(elem $fns ...)`; `wat2wasm /tmp/h2.wat -o /tmp/h2.wasm` exits 0 with NO undefined-function-variable errors. |
| **E.2** (partial-wheel undefined-fn baseline) | `cat src/*.mn lib/**/*.mn \| wasmtime run bootstrap/mentl.wasm 2>&1 \| wat2wasm - 2>&1 \| grep "undefined function variable" \| grep -c '\\$op_'` drops from baseline (~126 per planner §E.2) to 0 post-fix. |
| **E.3** (existing trace harnesses) | `bash bootstrap/test.sh` — 82/82 currently-passing harnesses STILL PASS post-fix; the new `handler_arm_decls_smoke.wat` brings count to 83/83 PASS. |
| **E.4** (determinism gate) | `bootstrap/build.sh` then a second `bootstrap/build.sh`; `diff bootstrap/mentl.wat bootstrap/mentl.wat.{run1,run2}` empty. |
| **E.5** (drift) | `bash tools/drift-audit.sh bootstrap/src/emit/main.wat` clean (zero matches). |
| **E.6** (wasm-validate) | `wasm-validate bootstrap/mentl.wasm` exits 0 on the rebuilt seed binary. |
| **E.7** (Lock #6 substrate-side untouched) | `git diff --stat bootstrap/src/lower/` empty between HEAD and the substrate commit (only `bootstrap/src/emit/main.wat` + `bootstrap/test/lower/handler_arm_decls_smoke.wat` + `bootstrap/test/INDEX.tsv` are changed). |

---

## §11 Per CLAUDE.md anchors

- **Anchor 0** (dream code; lux3.wasm not the arbiter) — substrate
  authored against the canonical seed shape, not against any
  specific binary's parser tolerance. Verification by simulation
  + walkthrough + audit + harness.
- **Anchor 1** (graph already knows it) — LowFn substrate already
  encodes every handler-arm fn's name string-pointer + body
  LowExpr at the LowFn record. We do not invent a parallel
  emission ledger; we read what the graph already carries via the
  same accessors LMakeClosure already uses.
- **Anchor 2** (don't patch; restructure or stop) — the four walks
  ALREADY have an LMakeClosure / LMakeContinuation arm shape;
  LDeclareFn fits the same shape verbatim. NOT a patch; structural
  symmetry preserved.
- **Anchor 4** (build the wheel; never wrap) — substrate writes
  the canonical form per `src/lower.mn:789-797` + `src/backends/
  wasm.mn` `emit_fns_expr`; no V1 to bridge.
- **Anchor 7** (cascade discipline; walkthrough first; land whole)
  — this walkthrough lands FIRST, in its own commit, then the six
  edits + harness + INDEX in a second commit per `mentl-implementer`
  dispatch §D order.

ULTIMATE_MEDIUM §6 "composition not invention" — third caller
(LDeclareFn after LMakeClosure + LMakeContinuation) earns the
abstraction shape. The substrate-honest residue is the four arm
additions + three body-recurse arms; not a new tag, not a new
accessor, not a new record shape.

---

## §12 Closure

This handle closes when:

1. The walkthrough commit lands (this document).
2. The substrate commit lands (six edits in
   `bootstrap/src/emit/main.wat` + harness at
   `bootstrap/test/lower/handler_arm_decls_smoke.wat` + INDEX.tsv
   row).
3. `Hβ-first-light-empirical.md` §2.3 receives a closure addendum
   citing both commits and listing the empirical artifact (the
   §A.1 minimal repro now passing `wat2wasm`).

Two-commit citation: this walkthrough + substrate. The empirical
closure addendum is named as a follow-up for the next planner
cycle. Per the `mentl-implementer` contract, this dispatch lands
two commits (walkthrough alone, substrate + harness + INDEX).
