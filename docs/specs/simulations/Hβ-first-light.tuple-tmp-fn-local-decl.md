# Hβ-first-light.tuple-tmp-fn-local-decl

> **Status:** `[LIVE 2026-05-05]` — empirically-real Phase H first-light
> handle. Bug reproduces verbatim against HEAD seed; wat2wasm
> hard-rejects the seed's output for any program containing an
> LMakeTuple expression (e.g. `(1, 2)`).
>
> **Authority:** `Hβ-first-light-empirical.md` §4.5.5 (the handle was
> named there 2026-05-05 once the rebased ptuple-let-destructure test
> isolated the actual bug to fn-local-decl, NOT scrutinee-type-flow);
> `Hβ-first-light-residue.md` (cascade context); `PLAN-to-first-light.md`
> (live first-light tracker); `Hβ-first-light.match-arm-pat-binding-local-decl.md`
> (sibling bug-class precedent — closed 2026-05-04 commits `8ebe8fa` +
> `a0c9baf`).
>
> **Claim in one sentence:** **`$emit_lmaketuple` (`bootstrap/src/emit/emit_const.wat:437-453`)
> emits `(local.set $tuple_tmp)` and `(local.get $tuple_tmp)` tokens for
> every LMakeTuple expression via `$emit_alloc(N*4, 1536)` — but
> `$emit_standard_locals` (`bootstrap/src/emit/main.wat:881-888`) does
> not declare `$tuple_tmp` in the fn-local preamble; siblings
> `$variant_tmp` (1568) and `$record_tmp` (1552) ARE pre-declared
> there, used identically by `$emit_lmakevariant` and `$emit_lmakerecord`
> respectively; the residue is one line — add
> `(call $emit_local_decl_str (i32.const 1536))` to
> `$emit_standard_locals` between the existing `record_tmp` and
> `scrut_tmp` declarations, restoring the three-way symmetry.**

---

## §0 Status header + evidence

### 0.1 Substrate landings since walkthrough authoring

Walkthrough authored at the empirical-pre-audit gate; no substrate has
shifted since `Hβ-first-light-empirical.md` §4.5.5 (rebased 2026-05-05)
named the handle. Match-arm-pat-binding-local-decl closure (commits
`8ebe8fa` + `a0c9baf`, 2026-05-04) introduced `$emit_pat_locals` /
`$emit_match_arm_locals` adjacent to `$emit_let_locals`/`_walk` — those
helpers handle LowPat-position binding names (e.g. `$a`, `$b` from
`Just(x)` or `(a, b)` patterns); they do NOT touch the preamble-side
scratch locals declared by `$emit_standard_locals`. Riffle-back is a
no-op.

`Hβ.lower.diverge-via-thread` (pending determinism gate as of
2026-05-05) is wheel-side `<|` parallelism; orthogonal to emit-side
fn-local-decl. `Hβ.first-light.nullary-ctor-call-context` (closed
2026-05-05) touched `bootstrap/src/lower/walk_const.wat`'s
`$lower_var_ref` for `SchemeKind` dispatch — completely orthogonal.

### 0.2 Empirical reproduction (verbatim §A.1 evidence)

Per the mentl-implementer §A pre-audit gate, the bug reproduces against
HEAD seed (`bootstrap/mentl.wasm`):

Input program:
```
fn pair() = (1, 2)
fn main() = {
  let (a, b) = pair()
  a + b
}
```

Stage-1 exits 0, empty stderr. The `$pair` body is emitted by the seed
with the canonical LMakeTuple sequence (heap-alloc + per-elem store +
final pointer):

```
(global.get $heap_ptr)(local.set $tuple_tmp)(global.get $heap_ptr)(i32.const 8)(i32.add)(global.set $heap_ptr)
(local.get $tuple_tmp)(i32.const 1)(i32.store offset=0)
(local.get $tuple_tmp)(i32.const 2)(i32.store offset=4)
(local.get $tuple_tmp)
```

The `$pair` preamble declares `$state_tmp / $variant_tmp / $record_tmp
/ $scrut_tmp / $callee_closure / $alloc_size / $loop_i` (via
`$emit_standard_locals`, lines 881-888 of `bootstrap/src/emit/main.wat`)
— but NOT `$tuple_tmp`, even though the body emits `(local.set
$tuple_tmp)` and `(local.get $tuple_tmp)` from `$emit_lmaketuple`'s
`$emit_alloc(N*4, 1536)` call.

`wat2wasm /tmp/v_pt.wat -o /tmp/v_pt.wasm` rejects with two-or-more
occurrences of:
```
error: undefined local variable "$tuple_tmp"
```

§A.2 acceptance gate clears: stage-1 exits 0 with empty stderr;
`(local.set $tuple_tmp)` AND `(local.get $tuple_tmp)` appear with
`$tuple_tmp` NOT in `(local ...)` preamble; wat2wasm emits exactly the
expected `error: undefined local variable "$tuple_tmp"`.

### 0.3 Scenario classification

**Scenario A** confirmed (per planner's §A.5 enumeration): the
fix-shape is preamble-extend in `$emit_standard_locals`. Sibling
`record_tmp` (1552) and `variant_tmp` (1568) are already declared
there, used identically by `$emit_lmakerecord` (line 461) and
`$emit_lmakevariant` (line 496). The omission of `tuple_tmp` (1536)
when `$emit_lmaketuple` was authored is the entire bug.

Scenarios B and S DO NOT apply: `$tuple_tmp` is a SCRATCH local needed
universally by every fn that contains an LMakeTuple, NOT a
pattern-binding name; LPTuple-in-pattern (e.g. `let (a, b) = ...`) is
handled by the existing `$emit_pat_locals` LPTuple arm
(`main.wat:1101`), which declares the elem binding names (`$a`, `$b`)
— those declarations work correctly.

Scenario C (LowExpr-walk extension) does not fit: `$tuple_tmp` is the
SAME name across every LMakeTuple in a fn body (always string-pointer
1536); walking the body once to discover it would produce one
declaration regardless of position — exactly what `$emit_standard_locals`
does for free, simpler.

The substrate-honest fix earns Anchor 7's "three instances" abstraction:
`$emit_standard_locals` is the canonical scratch-locals projection;
`tuple_tmp` is the third instance after `record_tmp` and `variant_tmp`.

---

## §1 Claim

LMakeTuple expressions emit `(local.set $tuple_tmp)` and `(local.get
$tuple_tmp)` tokens at fn-body emit time via `$emit_lmaketuple`'s
`$emit_alloc(N*4, 1536)` + `$ec_emit_local_get_dollar(1536)` calls, but
`$emit_standard_locals` does not declare `$tuple_tmp` in the fn-local
preamble. Substrate adds one call to `$emit_standard_locals` so every
emitted fn declares `$tuple_tmp` alongside the existing `state_tmp /
variant_tmp / record_tmp / scrut_tmp / callee_closure / alloc_size /
loop_i`, restoring the three-way symmetry with `record_tmp` and
`variant_tmp`.

---

## §2 Eight interrogations

| # | Interrogation | Resolution |
|---|---|---|
| 1 | **Graph?** | LMakeTuple's elems list at lexpr offset 4 (`$lexpr_lmaketuple_elems`); no per-fn graph reads needed for the fix — the symmetry is graph-side already (every LowFn record is structurally identical at emit-time; each can contain LMakeTuple). The fix lives entirely in the fn-preamble emit handler; the graph already knows every LowFn might contain LMakeTuple. |
| 2 | **Handler?** | Direct emit projection; `@resume=OneShot` (no continuation capture; one-shot streaming preamble emission). `$emit_standard_locals` IS the canonical "every fn might need these scratch locals" handler; the fix adds one more decl call symmetric with `variant_tmp` and `record_tmp`. |
| 3 | **Verb?** | N/A — direct streaming emission (no pipe topology at the preamble layer). |
| 4 | **Row?** | `EmitMemory` effect — writes to `$out_base` via `$emit_str` and `$emit_cstr` (transitively through `$emit_local_decl_str`). No allocation, no consumes; same effect row as the existing `record_tmp` and `variant_tmp` declarations in `$emit_standard_locals`. |
| 5 | **Ownership?** | Length-prefixed string at offset 1536 is statically-allocated emit-private data (`emit_const.wat:329`); read-only borrow during emission; no consume. |
| 6 | **Refinement?** | The string-pointer 1536 is the SAME constant used by `$emit_lmaketuple` at `emit_const.wat:441` + `:448` + `:453`; reading the value through `$emit_local_decl_str` produces an identical token sequence to the body's `(local.get $tuple_tmp)` calls. The refinement is the constant-equality between the preamble-side declaration site and the body-side use sites — three callsites, one string-pointer, structural. |
| 7 | **Gradient?** | Compile-time known: every fn might contain LMakeTuple, so unconditional preamble declaration is correct. The compile-time capability that would unlock dropping the unconditional declaration is "fn-body local-decl synthesized at lower-time as part of LowFn" — peer follow-up `Hβ.emit.lowfn-carries-local-decl-set`, NOT in scope here (already named in `Hβ-first-light.match-arm-pat-binding-local-decl.md` §3 and §9). |
| 8 | **Reason?** | `$emit_standard_locals` does not write Reasons (emit-time, not infer-time). The Why Engine walks back through the LowExpr tree's source handles to the LMakeTuple expression and from there to the AST's MakeTupleExpr; the fn-local declaration is structural infrastructure, not a Reason-generating site. |

---

## §3 Forbidden patterns

| Drift mode | Refusal at this site |
|---|---|
| **1** (Rust vtable) | NO `$emit_standard_locals_table`, NO closure-as-vtable, NO function-pointer indirection. The fix is one direct call to `$emit_local_decl_str` — same call shape used by the existing `state_tmp`, `variant_tmp`, `record_tmp` declarations. The word "vtable" does not appear. |
| **6** (Bool special-case) | The fix treats `tuple_tmp` exactly like `variant_tmp` and `record_tmp` — same call (`$emit_local_decl_str`), same constant-arg shape (i32 string-pointer to length-prefixed name). NO special-case for tuple-arity. NO "tuples are special because pair." Every aggregate that uses `$emit_alloc` deserves the same scratch-local discipline. |
| **7** (parallel arrays) | NO `$standard_local_names` accumulator list, NO sorted-set, NO `(name, type)` parallel arrays. The standard locals are emitted by direct sequential calls — substrate-honest declarative form. |
| **8** (string-keyed-when-structured) | The string-pointer 1536 is an i32 sentinel pointing at length-prefixed static data (`emit_const.wat:329`); the fix uses the integer pointer, NOT a runtime string comparison. WAT's `$<name>` token surface IS string-shaped because the language's local-name is string-shaped — the i32-pointer-to-static-data form preserves the structural representation. |
| **9** (deferred-by-omission) | The fix lands in ONE commit alongside the harness — preamble-extend + harness verifying the new declaration appears in the emitted preamble for any fn containing LMakeTuple. NO "substrate now, harness later" split. |

Peer follow-ups (Drift-9 named, NOT deferred-by-omission):

- `Hβ.emit.lowfn-carries-local-decl-set` — gradient-7 cash-out: lower carries an explicit local-decl set on the LowFn record so emit reads the set instead of relying on a fixed-shape preamble; not in scope here. (Same follow-up named in match-arm-pat-binding-local-decl §3 + §9; this handle DOES NOT change its scope or status.)

---

## §4 Edit sites

All in `bootstrap/src/emit/main.wat` (HEAD line numbers; planner notes
the file may have shifted slightly):

| Edit | Site | Action |
|---|---|---|
| **C.1** | Inside `$emit_standard_locals` at line 884 (the `record_tmp` declaration line), AFTER the existing `(call $emit_local_decl_str (i32.const 1552))      ;; record_tmp` line and BEFORE the `(call $emit_local_decl_cstr (i32.const 4248) (i32.const 9))  ;; scrut_tmp` line | NEW `(call $emit_local_decl_str (i32.const 1536))      ;; tuple_tmp` line. |

Insertion order: ONE edit, ONE commit.

The placement after `record_tmp` and before `scrut_tmp` is deliberate.
Lexically the three scratch locals from `$emit_alloc`-using arms cluster
together: `variant_tmp` (1568) → `record_tmp` (1552) → `tuple_tmp`
(1536). The current ordering goes high-pointer-to-low-pointer (1568,
1552); placing `tuple_tmp` (1536) directly after `record_tmp` (1552)
continues the descending-pointer ordering AND clusters all three
`$emit_alloc`-targets contiguously. Symmetric with the
`emit_const.wat:329-331` data-segment declarations which are also
listed in tuple/record/variant order.

---

## §5 Locks

1. **Lock #1 — Single edit; no helper restructuring.** The fix is one
   line added to the existing `$emit_standard_locals` body. No new
   helpers, no new data segments (string at 1536 already declared by
   `emit_const.wat:329`), no new constants. The minimal-scope nature
   IS the substrate-honest correctness — the symmetry was always
   intended; the omission was an authoring oversight.

2. **Lock #2 — Constant 1536 is the canonical `$tuple_tmp` pointer.**
   The same i32 constant 1536 is used at `emit_const.wat:441` (size +
   target args to `$emit_alloc`) + `:448` (`$ec_emit_local_get_dollar`
   inside the elem-store loop) + `:453` (final `$ec_emit_local_get_dollar`
   pushing the tuple ptr as the result on stack). The preamble-side
   declaration MUST use the same constant; any future rename of the
   string offset must update all four sites. (Peer follow-up
   `Hβ.emit.scratch-local-pointer-symbolic-constants` if a third
   round of rename pressure surfaces — not in scope; named here in
   case the substrate landing makes the constant proliferation
   visible.)

3. **Lock #3 — `$emit_local_decl_str` not `$emit_local_decl_cstr`.**
   The existing peer calls for `record_tmp` / `variant_tmp` / `state_tmp`
   / `alloc_size` use `$emit_local_decl_str` (one i32 arg — the
   length-prefixed-string pointer). The other three calls (`scrut_tmp`,
   `callee_closure`, `loop_i`) use `$emit_local_decl_cstr` (two i32
   args — raw-byte pointer + length). The new edit MUST use
   `$emit_local_decl_str` because the static data at 1536 is
   length-prefixed (`"\09\00\00\00tuple_tmp"` per `emit_const.wat:329`).

4. **Lock #4 — NO new lexpr/lowpat tags.** This is purely emit-side
   preamble synthesis; no LowExpr / LowPat tags touched. Tag regions
   300-349 (LowExpr) and 360-369 (LowPat) unchanged.

5. **Lock #5 — Three-way symmetry restored exactly.** Post-fix,
   `$emit_standard_locals` declares all three `$emit_alloc`-target
   scratch locals (`tuple_tmp` / `record_tmp` / `variant_tmp`) AND the
   four other shared locals (`state_tmp` / `scrut_tmp` /
   `callee_closure` / `alloc_size` / `loop_i`). The three-way symmetry
   for `$emit_alloc`-targets is the lock invariant.

---

## §6 Forbidden patterns audited per edit site

- **C.1 (`$emit_standard_locals` preamble extension)** — Drift 1
  refused (direct call, not table). Drift 6 refused (every
  `$emit_alloc`-target gets the same call shape; tuple is not special).
  Drift 7 refused (no name-list accumulator; sequential declarative
  calls). Drift 8 refused (i32 constant pointer, not string compare).
  Drift 9 refused (preamble-extend lands ALONGSIDE harness in one
  commit; no deferral).

The drift-audit (`tools/drift-audit.sh bootstrap/src/emit/main.wat`)
runs as §10 E.3 below.

---

## §7 Tag region

`bootstrap/src/lower/lexpr.wat:114` — LMakeTuple tag 317 unchanged.
`bootstrap/src/lower/lowpat.wat:34-43` — LowPat tags 360-369 unchanged.
NO tag additions; the substrate is purely emit-side preamble extension.

---

## §8 Test harness path

`bootstrap/test/emit/tuple_tmp_fn_local_decl.wat` — see §F. Constructs a
hand-authored LowFn whose body is:

```
LMakeTuple(handle, [LConst(handle, 1), LConst(handle, 2)])
```

Calls `$emit_fn_body`. Scans output for the substring `(local
$tuple_tmp i32)` exactly once in the function preamble. Exits 0 on
PASS, 1 on FAIL.

Registered in `bootstrap/test/INDEX.tsv` per the existing harness
manifest convention (last column `✓`, status indicating
trace-harness-LIVE).

---

## §9 Drift-9 named follow-ups

Sub-handles NOT landing this commit but explicitly named so they are
tracked, not deferred-by-omission:

- `Hβ.emit.lowfn-carries-local-decl-set` — gradient-7 cash-out: carry
  the local-decl name set on the LowFn record itself, populated at
  lower-time, so emit reads instead of relying on a fixed-shape
  preamble. Pure refactor for compile speed; no semantic change.
  (Same follow-up named in `Hβ-first-light.match-arm-pat-binding-local-decl.md`
  §3 + §9 — three sites would cite this same future cash-out;
  abstraction earned at the third instance per Anchor 7. NOT closed
  by this handle; named for the planner cycle that closes it.)

- `Hβ.emit.scratch-local-pointer-symbolic-constants` — IF the
  string-pointer-constant proliferation (1536 / 1552 / 1568 used at
  multiple sites) becomes a maintenance hazard, lift them to named
  constants in `emit_const.wat`'s data section. Not in scope here;
  named for the future planner cycle that hits the third proliferation
  symptom.

---

## §10 Verification gates

| Gate | Action |
|---|---|
| **E.1** (primary) | Run §A.1's reproduction: emit a `$pair` body whose preamble contains `(local $tuple_tmp i32)` exactly once; `wat2wasm /tmp/v_pt.wat -o /tmp/v_pt.wasm` succeeds with NO `undefined local variable "$tuple_tmp"` errors. |
| **E.2** (L1 regression baseline) | HEAD self-bootstrap candidate-diagnostic count (`undefined local variable "$tuple_tmp"`) BEFORE fix recorded. Post-fix count must be ZERO. Other `undefined local variable` instances (other names) must NOT increase. Specifically `cat $(find /home/suds/Projects/mentl/src -name '*.mn' \| sort) $(find /home/suds/Projects/mentl/lib -name '*.mn' \| sort) \| wasmtime run /home/suds/Projects/mentl/bootstrap/mentl.wasm > /tmp/inka2.wat 2>/tmp/inka2.err; wat2wasm /tmp/inka2.wat -o /tmp/inka2.wasm 2>&1 \| grep -c 'undefined local variable "\$tuple_tmp"'` returns 0. |
| **E.3** (drift) | `bash /home/suds/Projects/mentl/tools/drift-audit.sh /home/suds/Projects/mentl/bootstrap/src/emit/main.wat` clean (zero matches for any of the named drift modes 1-9). |
| **E.4** (existing harnesses) | `bash /home/suds/Projects/mentl/bootstrap/test.sh` — all currently-passing harnesses pass post-fix; specifically `bootstrap/test/emit/main_mentl_emit_smoke.wat` + `bootstrap/test/emit/emit_const_make_arms.wat` + `bootstrap/test/emit/match_arm_pat_binding_local_decl.wat` still PASS. The new harness `bootstrap/test/emit/tuple_tmp_fn_local_decl.wat` PASSes. |
| **E.5** (self-bootstrap delta) | Post-fix: `wat2wasm /tmp/inka2.wat -o /tmp/inka2.wasm 2>&1 \| grep -c 'undefined local variable "\$tuple_tmp"'` returns 0 (was ≥ 1 pre-fix for any wheel file that uses tuples). |

---

## §11 Per CLAUDE.md anchors

- **Anchor 0** (dream code; lux3.wasm not the arbiter) — substrate
  authored against the canonical seed shape, not against a specific
  binary's parser tolerance. Verification by simulation + walkthrough
  + audit + harness.
- **Anchor 1** (graph already knows it) — `$emit_lmaketuple` already
  encodes that every LMakeTuple expression needs `$tuple_tmp` as
  scratch via the constant 1536 used three times in
  `emit_const.wat:441-453`. We do not invent new ledgers; we read
  what the emit-side substrate already commits to.
- **Anchor 2** (don't patch; restructure or stop) — the fix restores a
  symmetry that was always intended. `record_tmp` and `variant_tmp`
  are pre-declared exactly because their `$emit_alloc`-using arms
  emit `(local.set $<name>)`. `tuple_tmp` belongs there for the same
  reason. The fix is structural completion, NOT a patch. (One line of
  code IS substrate-honest when the line is the third instance
  earning Anchor 7's abstraction symmetry.)
- **Anchor 4** (build the wheel; never wrap) — substrate writes the
  canonical preamble form; no V1 to bridge.
- **Anchor 7** (cascade discipline; walkthrough first; land whole) —
  this walkthrough lands FIRST, in its own commit, then substrate +
  harness in a second commit per `mentl-implementer` dispatch §D order.
  Three instances (`tuple_tmp` + `record_tmp` + `variant_tmp` all in
  `$emit_standard_locals`) earn the symmetry pattern.

---

## §12 Closure

This handle closes when:

1. The walkthrough commit lands (this document).
2. The substrate commit lands (`(call $emit_local_decl_str (i32.const
   1536))      ;; tuple_tmp` added to `$emit_standard_locals` in
   `bootstrap/src/emit/main.wat`; harness at
   `bootstrap/test/emit/tuple_tmp_fn_local_decl.wat`; INDEX.tsv row
   added).
3. `Hβ-first-light-empirical.md` §4.5.5 receives a closure addendum
   citing both commits (named follow-up for next planner cycle, NOT
   authored under THIS dispatch).

Per the `mentl-implementer` contract, this dispatch lands two commits
(walkthrough, substrate); the empirical closure addendum is the named
follow-up for the next planner cycle.
