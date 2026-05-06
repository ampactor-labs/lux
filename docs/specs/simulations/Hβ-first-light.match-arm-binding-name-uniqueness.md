# Hβ-first-light.match-arm-binding-name-uniqueness

> **Status:** `[LIVE 2026-05-04]` — empirically-real Phase H first-light
> handle. Bug reproduces verbatim against HEAD seed; wat2wasm
> hard-rejects the seed's output for any fn with two match arms
> binding the same source-level name (e.g.
> `match t { A(fields) => fields, B(fields) => fields }`).
>
> **Authority:** `Hβ-first-light.match-arm-pat-binding-local-decl.md`
> §9 + Lock #3 (verbatim quote: "If two arms both bind `$x`, the
> seed produces two `(local $x i32)` decls — wat2wasm WILL reject
> as duplicate. Verify empirically in §A.5 whether this case
> arises in the wheel. If it does, a peer handle
> `Hβ.first-light.match-arm-binding-name-uniqueness` is named for
> shadow-resolution"); `Hβ-first-light-empirical.md` §4.5.5
> (post-perm-pressure-fix observation 2026-05-04 commit `ec86804`
> where partial-wheel slice produced 563 KB validating WAT but
> wat2wasm rejected with `redefinition of local "$fields"`);
> `PLAN-to-first-light.md` (live first-light tracker).
>
> **Claim in one sentence:** **`$emit_pat_locals` and the
> LPRecord-rest / LPList-rest / LPAs-name string-direct-emit
> sites inside it currently emit `(local $<name> i32)` for every
> binding-introducing LowPat without checking whether `<name>`
> already declared in the current fn — the residue is to add a
> per-fn `$emit_fn_locals` flat-list ledger to
> `bootstrap/src/emit/state.wat` mirroring the existing
> `$emit_funcref_table_ptr` shape (`$str_eq` de-dup scan,
> `$list_extend_to` append, length-only-reset at
> `$emit_fn_reset`), expose `$emit_fn_local_check(name) →
> is_new_i32` per the `$emit_funcref_register` precedent, and
> guard each `(local $<name> i32)` emission in
> `$emit_pat_locals` (and the `$emit_let_locals` LLet arm) with
> a `(call $emit_fn_local_check (name))` predicate so duplicate
> names short-circuit to no-op while first occurrences emit +
> register — with NO new tags, NO Drift-1 dispatch table, NO
> Drift-7 parallel arrays, and NO source-name mangling.**

---

## §0 Status header + evidence

### 0.1 Substrate landings since walkthrough authoring

This walkthrough is authored at the empirical-pre-audit gate;
no substrate has shifted since `Hβ-first-light-empirical.md`
§4.5.5 named the post-perm-pressure-fix observation 2026-05-04.
The riffle-back is a no-op: walkthrough freezes the substrate
decision against HEAD as observed by §A.1 + §A.3 reproduction
below.

### 0.2 §A.1 minimal-repro evidence (verbatim)

Per the mentl-implementer §A pre-audit gate, the bug reproduces
against HEAD seed (`bootstrap/mentl.wasm`, 125322 bytes, built
clean with empty stderr).

Input program (`/tmp/repro_uniq.mn`):

```
type T = A(Int) | B(Int)
fn f(t) = match t { A(fields) => fields, B(fields) => fields }
fn main() = f(A(42))
```

Stage-1 exits 0, empty stderr. Output `$f` body's preamble
(extracted via `grep -oE`):

```
(local $state_tmp i32) (local $variant_tmp i32) (local $record_tmp i32)
(local $tuple_tmp i32) (local $scrut_tmp i32) (local $callee_closure i32)
(local $alloc_size i32) (local $loop_i i32)
(local $fields i32) (local $fields i32)
```

`(local $fields i32)` appears TWICE; `wat2wasm /tmp/repro_uniq.wat
-o /tmp/repro_uniq.wasm` rejects with:

```
/tmp/repro_uniq.wat:18:278: error: redefinition of local "$fields"
... $alloc_size i32) (local $loop_i i32) (local $fields i32) (local $fields i32)
                                                                    ^^^^^^^
```

§A.2 acceptance gate clears: stage-1 exits 0 with empty stderr;
`(local $fields i32)` occurs exactly twice; wat2wasm exits
non-zero with `redefinition of local "$fields"` substring.

### 0.3 §A.3 partial-wheel slice evidence (the empirical motivator)

Per `Hβ-first-light-empirical.md` §4.5.5: post-perm-pressure-fix
the partial wheel slice should produce ≥ 563 KB validating WAT.
Actual:

```
$ cat src/types.mn src/effects.mn lib/runtime/strings.mn \
        lib/runtime/lists.mn \
    | wasmtime run bootstrap/mentl.wasm > /tmp/partial.wat
$ wc -c < /tmp/partial.wat
563125
$ wat2wasm /tmp/partial.wat -o /tmp/partial.wasm 2>&1 | head -4
/tmp/partial.wat:598:430: error: redefinition of local "$fields"
...s i32) (local $fields i32) (local $fields i32) (local $v i32) (local $base...
                                     ^^^^^^^
/tmp/partial.wat:598:501: error: redefinition of local "$ret"
```

Distinct redefined names across the partial wheel (28 unique;
79 total redefinition errors):

```
$a $an $b $bn $body_names $buf $copied $ctx $dot $epoch
$fields $gate_names $id $inner $left $left_len $list_diff_str
$n $na $name $names $nb $neg_names $op $residual $ret $span $v
```

The bug is widespread; first match-arm fn `$show_type`
(`src/types.mn:874-921`) has multiple arms each binding
overlapping name sets (e.g., `TName(name, args)`, `TAlias(name,
_)`, `TRecord(fields)`, `TRefined(base, pred)` → `(local $name
i32) (local $fields i32) (local $base i32)` repeated).

### 0.4 Scenario classification

**Scope A.2** decided per planner §A.5: per-fn dedupe ledger in
state.wat extending the existing `$emit_fn_reset` boundary;
`$emit_pat_locals` (and `$emit_let_locals` LLet arm) consults
the ledger before emit. Refused:

- **Scope A.1** (thread seen-set as parameter through
  `$emit_let_locals` + `$emit_let_locals_walk` +
  `$emit_match_arm_locals` + `$emit_pat_locals`) — heavy
  signature churn vs composing existing precedent.
- **Scope A.3** (post-emit dedupe via temp buffer + sort+uniq)
  — drift mode 7 (parallel-array materialization).
- **Path B** for naming (gensym `$fields_arm0_arm1`) — refused;
  obscures source-level names. WAT locals are fn-scoped; one
  `(local $fields i32)` slot reused safely across arms because
  only one arm body executes per dispatch. Path A (de-dup,
  preserve source name) is the substrate-correct shape.

§A.5b LLet collision check: empirical evidence shows match-arm
path dominates (all 79 errors come from match-arm fns:
`$show_type` / `$show_handle` / etc.). LLet path may have its
own latent collisions; the same `$emit_fn_local_check` ledger
handles both structurally — the LLet guard (§B.4 C.11) lands
in this commit per drift-9 refusal of "deferred-by-omission."

§A.6 isomorphism: `$emit_funcref_register` (state.wat:211-225)
IS literally the "register-or-lookup" shape — input name
str_ptr; if found via `$str_eq` scan return existing idx; else
`$list_extend_to` + `$list_set` + bump len. The new
`$emit_fn_local_check` mirrors this with a returned-bool
contract instead of an idx (Option α from planner §A.6).

---

## §1 Claim

`$emit_pat_locals` (`bootstrap/src/emit/main.wat:1074-1166`)
and its sibling `$emit_let_locals` LLet arm (lines 971-979)
emit `(local $<name> i32)` declarations directly to
`$out_base` for every binding-introducing variant — but neither
checks whether `<name>` is already declared in the current fn.
For any fn with two match arms binding the same source-level
name (or two LLet bindings sharing a name across LBlock /
LIf / nested-match contexts), the seed emits a duplicate
`(local $<name> i32)` in the fn preamble; wat2wasm rejects as
`redefinition of local "$<name>"`.

The fix is to extend `bootstrap/src/emit/state.wat`'s ledger
family (already three: funcref-table / body-context /
string-intern) with a fourth: a per-fn `$emit_fn_locals_ptr`
flat-list of name str_ptrs, mirroring `$emit_funcref_table_ptr`
shape — with `$emit_fn_local_check (name) → is_new_i32`
exposing the register-or-no-op contract. `$emit_pat_locals`
guards each `(local $<name> i32)` emission with the
`$emit_fn_local_check` predicate; duplicates short-circuit to
no-op while first occurrences emit + register. The ledger
length-only-resets at `$emit_fn_reset`, which is wired into
`$emit_fn_body` between `$emit_standard_locals` and
`$emit_let_locals` (per Lock #3 — `$emit_fn_reset` currently
has no caller; this commit IS the wiring).

---

## §2 Eight interrogations (per kernel primitive)

| # | Interrogation | Resolution |
|---|---|---|
| 1 | **Graph?** | LPVar's `name` field at record offset 1 already carries the binding's source-level name string-pointer (per `bootstrap/src/lower/lowpat.wat:87-93`). The fn-local-set IS a structural projection of the LowPat tree's LPVar leaves under the current fn body. We add ONE ledger reading these names; we do NOT invent a parallel name source. |
| 2 | **Handler?** | The existing emit-state ledger family (`$emit_funcref_table_ptr` / `$emit_string_table_ptr`) IS the wheel's handler-with-state shape projected; this is the fourth ledger entry. `@resume=OneShot` (no continuation; pure scan-or-append). The wheel projection IS `body_context` per `src/backends/wasm.mn:117-128 + 960-961`, augmented with a per-fn local-name set. |
| 3 | **Verb?** | N/A at substrate level (intra-handler ledger). |
| 4 | **Row?** | `EmitMemory` effect — writes via `$list_extend_to` + `$list_set` to the heap-allocated ledger; reads via `$list_index` + `$str_eq`. No row change vs the existing state.wat ledgers. |
| 5 | **Ownership?** | Ledger OWNS by emit pass; `$emit_fn_reset` length-only-resets at fn boundary (mirrors `$emit_body_evidence_len_g`); name str_ptrs are `ref`-stored (caller retains primary ownership). |
| 6 | **Refinement?** | LPVar.name ≥ HEAP_BASE per arity-2 contract `$lowpat_make_lpvar` (`bootstrap/src/lower/lowpat.wat:87-93`). LPRecord/LPList rest_var is 0 OR ≥ HEAP_BASE per the `i32.ne $rest 0` guard already in `$emit_pat_locals` (lines 1131, 1151). LPAs name ≥ HEAP_BASE. The dedupe predicate `$emit_fn_local_check` returns 1 (new) iff the str_ptr is not already in the ledger via `$str_eq` scan. |
| 7 | **Gradient?** | The runtime per-fn ledger is the seed's runtime-scan projection. Compile-time cashout: `Hβ.emit.lowfn-carries-local-decl-set` (NAMED follow-up, NOT in scope) — lower computes the dedupe at lower-time, populates `LowFn.local_decl_set`, emit reads instead of scanning. Pure refactor for compile-speed; this commit lands the runtime-correct shape FIRST. |
| 8 | **Reason?** | LPVar's handle (record offset 0) preserves the source-level Reason chain already; the dedupe ledger does not write Reasons (emit-time). The Why Engine walks back to the FIRST occurrence; subsequent same-name LPVars at different arms still resolve to the source-level Reason via their handles. The dedupe is name-string-level; it does NOT collapse Reason chains. |

---

## §3 Forbidden patterns (drift modes refused per edit site)

| Drift mode | Refusal at this site |
|---|---|
| **1** (Rust vtable) | NO closure-record-of-functions; NO `$emit_fn_local_table` of operations. `$emit_fn_local_check` is one direct fn calling `$emit_fn_local_lookup` (str_eq scan) + `$list_extend_to` append. The word "vtable" appears nowhere. |
| **2** (Scheme env frame) | NO frame-stack scoping; the ledger is a single flat list per fn. WASM locals are fn-scoped, not block-scoped — modeling the dedupe as a frame-stack would invent structure WAT itself doesn't have. |
| **3** (Python dict) | NO string-keyed hash map. Flat list + linear `$str_eq` scan, mirroring the three existing ledgers in state.wat. |
| **5** (C calling convention) | NO separate name-list + sentinel-list parallel arrays; one list of str_ptrs (single-field; no record wrap ceremony per the funcref-table precedent at state.wat lines 105-110). |
| **6** (Bool special-case) | LPCon-Bool (HB drift-6 closure) walks the same `$emit_pat_locals` LPCon arm as user-defined N-ary constructors; Bool's True/False — being nullary LPCon with empty args list — produce no LPVars at all and contribute no entries to the ledger. No special-case. |
| **7** (parallel arrays) | NO `name_array + seen_array` parallel arrays. NO `(name, depth)` or `(name, arm_idx)` per-entry records. ONE list of name str_ptrs; the ledger IS the dedupe state. |
| **8** (string-keyed-when-structured) | LPVar.name is a string-pointer because WAT's local-name token IS string-shaped (`$x` literal); not because we are flag-as-int-ing a structural distinction. Each binding-introducing LowPat is its own ADT tag (360, 363, 364, 365, 366, 368). |
| **9** (deferred-by-omission) | LPVar (top), LPCon-sub-LPVar (any depth), LPTuple-elem-LPVar, LPRecord-field-LPVar, LPRecord-rest_var, LPList-elem-LPVar, LPList-rest_var, LPAs-name, LPAs-inner-LPVar, AND LLet-name — ALL guarded in this commit. NO arm of `$emit_pat_locals` or `$emit_let_locals` lacks the dedupe check. |

---

## §4 Edit sites enumerated

All in three files (state.wat + main.wat + harness):

| Edit | File | Site | Action |
|---|---|---|---|
| **C.1** | `bootstrap/src/emit/state.wat` | After `$emit_strings_next_offset_g` global (line 182), BEFORE `$emit_init` (line 191) — adjacent to other global declarations | NEW globals `$emit_fn_locals_ptr` + `$emit_fn_locals_len_g` mirroring `$emit_funcref_table_ptr` + `$emit_funcref_table_len_g` shape. |
| **C.2** | `bootstrap/src/emit/state.wat` | Inside `$emit_init` (lines 191-202), before `$emit_initialized` set | NEW initialization `$emit_fn_locals_ptr ← $make_list 8`; `$emit_fn_locals_len_g ← 0`. |
| **C.3** | `bootstrap/src/emit/state.wat` | After `$emit_funcref_at` (line 257), BEFORE `$emit_set_body_context` (line 265) | NEW `$emit_fn_local_check (name) → is_new_i32` (single-call check-or-register) + `$emit_fn_local_lookup (name) → idx_or_neg1` (str_eq scan; mirrors `$emit_funcref_lookup`). |
| **C.4** | `bootstrap/src/emit/state.wat` | Inside `$emit_fn_reset` (lines 365-368), AFTER existing `$emit_body_evidence_len_g ← 0` | NEW length-only reset `$emit_fn_locals_len_g ← 0`. |
| **C.5** | `bootstrap/src/emit/main.wat` | LPVar arm in `$emit_pat_locals` (lines 1081-1086) | GUARD `(local $<name> i32)` emit with `(if (call $emit_fn_local_check (name)) (then ...))`. |
| **C.6** | `bootstrap/src/emit/main.wat` | LPRecord rest_var emit (lines 1131-1135) | GUARD same shape. |
| **C.7** | `bootstrap/src/emit/main.wat` | LPList rest_var emit (lines 1151-1155) | GUARD same shape. |
| **C.8** | `bootstrap/src/emit/main.wat` | LPAs name emit (lines 1158-1163) | GUARD the as-name emit only (the inner-pat recurse re-enters `$emit_pat_locals` and re-checks). |
| **C.9** | `bootstrap/src/emit/main.wat` | Inside `$emit_fn_body` (lines 893-933), AFTER `$emit_standard_locals` (line 923), BEFORE `$emit_let_locals (body)` (line 925) | INSERT `(call $emit_fn_reset)` to clear per-fn ledgers BEFORE locals walk. Empirically: `grep -n 'call \$emit_fn_reset' bootstrap/src/emit/*.wat` returns ZERO callers — C.9 IS the first wiring. |
| **C.10** | `bootstrap/src/emit/main.wat` | LPCon arm verification (lines 1088-1100) | NO EDIT. Existing `$len = 0` short-circuit handles nullary LPCon cleanly. Verified (Drift 9 refusal of deferred-by-omission via verification). |
| **C.11** | `bootstrap/src/emit/main.wat` | LLet arm in `$emit_let_locals` (lines 971-979) | GUARD `(local $<name> i32)` emit with `$emit_fn_local_check`. Per §A.5b: same bug class structurally; same ledger handles it; landing both arms uniformly per drift-9 refusal. |

Insertion order (per §D below): C.1 → C.2 → C.3 → C.4 (state.wat ledger lands first) → C.5 → C.6 → C.7 → C.8 → C.9 → C.11 → C.10 (verification).

---

## §5 Locks

1. **Lock #1 — `$emit_fn_local_check` returns "is new" boolean.** Spec: `(param $name i32) (result i32)`. Returns 1 IFF the name was NOT in the ledger and has been freshly appended. Returns 0 IFF the name was already present (no append performed). The guard sites read this i32 directly into an `(if (call ...) (then ...))`. No two-call protocol.

2. **Lock #2 — `$emit_fn_local_check` is idempotent on repeat-call.** Calling `$emit_fn_local_check (X)` twice in succession returns 1 then 0; the ledger contains exactly one entry for X. Mirrors `$emit_funcref_register`'s idx-stable shape.

3. **Lock #3 — Per-fn boundary at `$emit_fn_reset` wired in C.9.** The ledger MUST length-only-reset at every fn-emit-body boundary. Empirical verification: `grep -n 'call \$emit_fn_reset' bootstrap/src/emit/*.wat` returns ZERO callers in HEAD. C.9 IS the first wiring — between `$emit_standard_locals` (line 923) and `$emit_let_locals (body)` (line 925) inside `$emit_fn_body`.

4. **Lock #4 — `$emit_fn_locals_ptr` is FN-scoped, NOT program-scoped.** Differs from funcref-table + string-intern (program-wide). Mirrors `$emit_body_evidence_len_g` length-reset semantics.

5. **Lock #5 — Source-name fidelity preserved.** NO gensym, NO synthetic names like `$fields_arm0`, NO renaming. The ledger is dedupe-only; the emitted `(local $<name> i32)` uses the exact source-level name string from LPVar.name. Refines the §0.4 Path A decision.

6. **Lock #6 — NO new LowPat / LowExpr tags.** Tag region 300-369 unchanged. Tag region 360-379 emit-private (state.wat) unchanged — the new globals are not records.

7. **Lock #7 — Helpers live in state.wat, NOT main.wat.** `$emit_fn_local_check` + `$emit_fn_local_lookup` live in state.wat between `$emit_funcref_at` (line 257) and `$emit_set_body_context` (line 265). This places the four ledgers (funcref / body-context / string-intern / fn-locals) contiguously by their idiom.

8. **Lock #8 — Capacity 8 default.** `$make_list 8` per the existing three ledgers' `$emit_init` precedent. `$list_extend_to` grows on demand.

9. **Lock #9 — Path β default for standard-locals shadowing.** Standard names (`$state_tmp` / `$variant_tmp` / `$record_tmp` / `$tuple_tmp` / `$scrut_tmp` / `$callee_closure` / `$alloc_size` / `$loop_i`) emit BEFORE `$emit_fn_reset`; they are NOT in the ledger when the LowPat walk begins. A user LPVar binding name colliding with a standard name would erroneously emit a duplicate. Empirical post-fix verification protocol: scan wheel for LPVar names in `{state_tmp, variant_tmp, record_tmp, tuple_tmp, scrut_tmp, callee_closure, alloc_size, loop_i}`. If any surface, peer follow-up `Hβ.first-light.standard-locals-shadowing` lands separately. Path α (pre-register all eight with `$str_eq`-comparable str_ptrs) is refused for this commit — `_cstr` standard-locals at offsets 4248 / 4232 / 4260 are raw data-segment offsets WITHOUT length prefix, not `$str_eq`-comparable to heap-allocated LPVar.name str_ptrs. Path α requires a separate substrate decision (see §G.1).

---

## §6 Forbidden patterns audited per edit site (drift-mode refusals)

- **C.1 (globals):** Drift 7 refused — flat list of str_ptrs, NOT parallel name+sentinel arrays. Drift 8 refused — names are str_ptrs because WAT-token surface is string-shaped.
- **C.2 ($emit_init init):** Drift 9 refused — append to existing init block; NO new init function.
- **C.3 ($emit_fn_local_check + $emit_fn_local_lookup):** Drift 1 refused (no table). Drift 3 refused (linear scan, not hash map). Drift 7 refused (one list, not parallel). Mirrors `$emit_funcref_register` + `$emit_funcref_lookup` shape verbatim.
- **C.4 ($emit_fn_reset extension):** Drift 9 refused — length-only-reset like `$emit_body_evidence_len_g`; one-line addition to existing reset block.
- **C.5–C.8 (guards in $emit_pat_locals):** Drift 6 refused — every binding-introducing variant gets the same guard shape. Drift 9 refused — no arm omits the guard.
- **C.9 (per-fn boundary):** Drift 9 refused — boundary wired explicitly, not "we'll add it later."
- **C.10 (LPCon nullary verification):** Drift 9 refused — verified-not-deferred.
- **C.11 (LLet guard):** Drift 6 refused — LLet shares the same guard shape as `$emit_pat_locals` arms; Drift 9 refused — landing alongside the match-arm guards uniformly.

---

## §7 Tag region

`bootstrap/src/lower/lowpat.wat:34-43` — tags 360-369 unchanged.
`bootstrap/src/emit/state.wat` tag region 360-379 emit-private — unchanged (new entries are globals, not records).
NO tag additions; substrate is purely emit-side ledger projection.

---

## §8 Test harness path

`bootstrap/test/emit/match_arm_binding_uniqueness.wat` — clones
the `bootstrap/test/emit/match_arm_pat_binding_local_decl.wat`
precedent. Constructs a hand-authored LowFn whose body is:

```
LMatch(scrut=LLocal($t), arms=[
  LPArm(LPCon(handle, A_tag, [LPVar(handle, "fields")]), LLocal("fields")),
  LPArm(LPCon(handle, B_tag, [LPVar(handle, "fields")]), LLocal("fields")),
])
```

Calls `$emit_fn_body`. Counts `(local $fields i32)` occurrences
in emitted output; expects exactly ONE. Exits 0 on PASS, 1 on
FAIL.

Registered in `bootstrap/test/INDEX.tsv`:

```
emit/match_arm_binding_uniqueness.wat	main.wat + state.wat	Hβ-first-light.match-arm-binding-name-uniqueness §B.8 + Lock #1+#3 acceptance — two arms binding $fields produce ONE (local $fields i32) preamble decl + wat2wasm validates	$emit_fn_body $emit_pat_locals $emit_fn_local_check $emit_fn_local_lookup $emit_fn_reset	~
```

Status `~` (in-flight) updated to `✓` after E.5 passes.

---

## §9 Drift-9 named follow-ups

Sub-handles NOT landing this commit but explicitly named:

- `Hβ.emit.lowfn-carries-local-decl-set` — gradient-7 cash-out: lower computes the dedupe at lower-time; LowFn record carries `local_decl_set` field; emit reads instead of scanning. Pure refactor for compile speed; no semantic change. NOT in scope.
- `Hβ.first-light.match-arm-binding-name-uniqueness.shadow-resolution` — IF post-fix wheel surfaces a case where source-level shadowing INTENDS distinct slots (e.g., `match outer { Some(x) => match inner { Some(x) => ... } }` where inner `x` should be a fresh slot, NOT a ref to the outer), the lower-side rename pass lands here. Empirically: WAT locals are flat fn-scoped storage; one `$x` slot reused safely across arms where only one arm body executes. Nested matches would write/read through the same slot — semantically incorrect IFF the outer binding is referenced from inside the inner match's body. Verify post-fix via wheel re-run. NOT pre-judged in scope.
- `Hβ.first-light.standard-locals-shadowing` — IF a wheel LPVar binding name collides with `{state_tmp, variant_tmp, record_tmp, tuple_tmp, scrut_tmp, callee_closure, alloc_size, loop_i}`. Path β default per Lock #9; resolution depends on whether collisions surface. Verification: post-fix wheel grep for these eight names as user bindings.

LPTuple elem-LPVar, LPRecord field-LPVar + rest_var, LPList elem-LPVar + rest_var, LPAs name + inner-pat-LPVar, LLet — ALL guarded in C.5–C.8 + C.11; NOT named as follow-ups (they land this commit).

---

## §10 Verification gates

| Gate | Action |
|---|---|
| **E.1** (primary repro) | `cat /tmp/repro_uniq.mn \| wasmtime run bootstrap/mentl.wasm > /tmp/repro_uniq.wat; wat2wasm /tmp/repro_uniq.wat -o /tmp/repro_uniq.wasm` — stage-1 exits 0 + empty stderr; `(local $fields i32)` occurs exactly ONCE; wat2wasm exits 0. |
| **E.2** (partial-wheel slice) | `cat src/types.mn src/effects.mn lib/runtime/strings.mn lib/runtime/lists.mn \| wasmtime run bootstrap/mentl.wasm > /tmp/partial.wat; wat2wasm /tmp/partial.wat -o /tmp/partial.wasm` — wat2wasm `redefinition` count = 0 (was 79 pre-fix). |
| **E.3** (drift) | `bash tools/drift-audit.sh bootstrap/src/emit/state.wat bootstrap/src/emit/main.wat bootstrap/test/emit/match_arm_binding_uniqueness.wat` — zero matches. |
| **E.4** (existing harnesses) | `bash bootstrap/test.sh` — all currently-passing harnesses pass post-fix. Specifically `match_arm_pat_binding_local_decl.wat`, `main_mentl_emit_smoke.wat`, `emit_lmatch.wat` still PASS. The 81/81 baseline holds. |
| **E.5** (new harness) | `bootstrap/test/emit/match_arm_binding_uniqueness.wat` exits 0; assertion: exactly one `(local $fields i32)` substring in `$f`'s preamble. |
| **E.6** (broader L1 regression) | HEAD self-bootstrap: `cat src/*.mn lib/runtime/*.mn \| wasmtime run bootstrap/mentl.wasm > /tmp/inka2.wat; wat2wasm /tmp/inka2.wat -o /tmp/inka2.wasm 2>&1 \| grep -c 'redefinition'` — strictly less than pre-fix baseline. |
| **E.7** (artifact validation) | `wasm-validate bootstrap/mentl.wasm` (post-rebuild) exits 0. |

---

## §11 Per CLAUDE.md anchors

- **Anchor 0** (dream code; lux3.wasm not the arbiter) — substrate authored against the canonical seed shape. Verification by simulation + walkthrough + audit + harness.
- **Anchor 1** (graph already knows it) — LPVar.name field IS the binding's source name; we add ONE ledger reading it; no parallel name source.
- **Anchor 2** (don't patch; restructure or stop) — the existing emit-state ledger family (funcref / body-context / string-intern) IS the structural shape; this commit lands the fourth ledger entry composing with the existing pattern. NOT a patch to `$emit_pat_locals`; STRUCTURE extension.
- **Anchor 4** (build the wheel; never wrap) — wheel-side `body_context` handler + `set_body_captures` / `set_body_evidence` discipline at `src/backends/wasm.mn:117-128 + 960-961` is the canonical shape; seed's state.wat IS the projection; this extension matches wheel pattern.
- **Anchor 7** (cascade discipline; walkthrough first; land whole) — walkthrough + substrate + harness in disciplined sequence per §D order.

---

## §12 Closure

This handle closes when:

1. The walkthrough commit lands (this document).
2. The substrate commit lands: state.wat ledger (C.1–C.4) + main.wat guards (C.5–C.8 + C.11) + main.wat fn-body reset wiring (C.9) + `bootstrap/test/emit/match_arm_binding_uniqueness.wat` harness + INDEX.tsv row.
3. `Hβ-first-light-empirical.md` §4.5.5 receives a closure addendum citing both commits + the wheel-slice partial-build evidence becoming validating.
4. `Hβ-first-light.match-arm-pat-binding-local-decl.md` §9 receives a closure addendum noting the predicted Lock #3 escape was verified and resolved by this handle.

Three-commit citation: this walkthrough (commit 1) + substrate + harness (commit 2) + the empirical / cross-walkthrough closure addenda (commit 3, separate planner-issued follow-up after substrate lands and the wheel is verified). Per the mentl-implementer contract, this dispatch lands two commits (walkthrough; substrate+harness); the addenda are named as the follow-up for the next planner cycle.
