# Hβ-first-light.match-arm-pat-binding-local-decl

> **Status:** `[LIVE 2026-05-04]` — empirically-real Phase H first-light
> handle. Bug reproduces verbatim against HEAD seed; wat2wasm
> hard-rejects the seed's output for any program containing a
> match-arm sub-pattern binding (e.g. `Just(x) => x`).
>
> **Authority:** `Hβ-first-light-empirical.md` §2.3 item 3 (the
> handle was named there 2026-05-04 once the test program isolating
> it surfaced); `Hβ-first-light-residue.md` (cascade context);
> `PLAN-to-first-light.md` (live first-light tracker).
>
> **Claim in one sentence:** **`$emit_let_locals` already descends
> into LLet (304) / LBlock (315) / LIf (314) to register every
> nested LLet-binding's name as `(local $<name> i32)` in the
> emitted fn preamble — but it does not descend into LMatch (321)
> arms whose patterns can introduce LPVar bindings (potentially
> nested at any depth inside LPCon / LPTuple / LPRecord / LPList /
> LPAs); the residue is to extend `$emit_let_locals` and its
> single-expr companion `$emit_let_locals_walk` with one LMatch
> arm that walks the scrutinee plus iterates each `LPArm`,
> calling a new `$emit_pat_locals` helper that recurses through
> the LowPat tree emitting one `(local $<name> i32)` declaration
> per binding-introducing variant — mirroring the same descent
> shape the LBlock / LIf cases already use, with NO new tags, NO
> Drift-1 dispatch table, and NO Drift-7 parallel-arrays
> name-accumulator.**

---

## §0 Status header + evidence

### 0.1 Substrate landings since walkthrough authoring

This walkthrough is authored at the empirical-pre-audit gate; no
substrate has shifted since `Hβ-first-light-empirical.md` §2.3 item 3
named the handle 2026-05-04. The riffle-back is therefore a no-op:
walkthrough freezes the substrate decision against HEAD as observed
by §A.1 reproduction below.

### 0.2 Empirical reproduction (verbatim §A.4 evidence)

Per the mentl-implementer §A pre-audit gate, the bug reproduces
against HEAD seed (`bootstrap/mentl.wasm`, 123038 bytes, built clean
with empty stderr):

Input program:
```
type Maybe = Just(Int) | Nothing
fn unwrap(m, d) = match m { Just(x) => x, Nothing => d }
fn main() = unwrap(Nothing, 5)
```

Stage-1 exits 0, empty stderr. Output `$unwrap` body emitted by the
seed:

```
  (func $unwrap (param $__state i32) (param $m i32) (param $d i32) (result i32) (local $state_tmp i32) (local $variant_tmp i32) (local $record_tmp i32) (local $scrut_tmp i32) (local $callee_closure i32) (local $alloc_size i32) (local $loop_i i32)
(local.get $m)(local.set $scrut_tmp)(local.get $scrut_tmp)(i32.const 4096)(i32.lt_u)(if (result i32)(then(local.get $scrut_tmp)(i32.const 1)(i32.eq)(if (result i32)(then(local.get $d))(else(unreachable))))(else(local.get $scrut_tmp)(i32.load offset=0)(i32.const 0)(i32.eq)(if (result i32)(then(local.get $scrut_tmp)(i32.load offset=4)(local.set $x)(local.get $x))(else(local.get $scrut_tmp)(i32.load offset=0)(i32.const 1)(i32.eq)(if (result i32)(then(local.get $d))(else(unreachable)))))))  )
```

The `$unwrap` preamble declares `$state_tmp / $variant_tmp /
$record_tmp / $scrut_tmp / $callee_closure / $alloc_size / $loop_i`
(via `$emit_standard_locals`, lines 881-888 of
`bootstrap/src/emit/main.wat`) — but NOT `$x`, even though the body
emits `(local.set $x)(local.get $x)` from the
`Just(x) => x` arm.

`wat2wasm /tmp/repro.wat -o /tmp/repro.wasm` rejects with:
```
/tmp/repro.wat:20:346: error: undefined local variable "$x"
...t_tmp)(i32.load offset=4)(local.set $x)(local.get $x))(else(local.get $scr...
                                       ^^
/tmp/repro.wat:20:360: error: undefined local variable "$x"
...d offset=4)(local.set $x)(local.get $x))(else(local.get $scrut_tmp)(i32.lo...
                                       ^^
```

§A.2 acceptance gate clears: stage-1 exits 0 with empty stderr;
`(local.set $x)` AND `(local.get $x)` appear with `$x` NOT in
`(local ...)` preamble; wat2wasm emits exactly the expected
`error: undefined local variable "$x"` (twice — once per
get/set occurrence).

### 0.3 Scenario classification

**Scenario E** confirmed (per planner's §A.4 enumeration):
`emit_control.wat`'s LPCon arm-emission helper
(`$ec5_emit_pat_field_binds` at lines 391-407 + 489-509, called
from `$ec_emit_match_pcon_arm` at line 380+ and
`$ec_emit_match_mixed` at line 459+) DOES emit the
`(local.set $<name>)(local.get $<name>)` token sequence for sub-
pattern bindings — but `$emit_let_locals` (lines 958-992 of
`bootstrap/src/emit/main.wat`) has NO LMatch (tag 321) arm and
its single-expr companion `$emit_let_locals_walk`
(lines 996-1010) likewise has no LMatch arm. The local-decl
ledger is therefore blind to all match-arm pattern bindings
regardless of nesting depth.

Scenarios L and S DO NOT apply: `$lowpat_make_lpvar(handle, name)`
populates `name` correctly (`bootstrap/src/lower/lowpat.wat:87-93`,
field offset 1); the seed has no separate state.wat ledger for
local declarations — declaration is one-shot streaming through
`$emit_let_locals` at fn-preamble emit time.

---

## §1 Claim

Match-arm LPCon sub-pattern bindings (and every other binding-
introducing LowPat variant — LPVar at top, LPTuple elems, LPRecord
fields, LPList elems + rest_var, LPAs name + inner pat, recursively
through nested LPCon args) emit `(local.set $<name>)(local.get
$<name>)` tokens at arm-body emit time, but `$emit_let_locals`
does not recurse into LMatch arms — substrate populates
`$emit_let_locals`'s LMatch (tag 321) descent so every LPVar in
every arm's pattern (including nested LPCon-sub-LPVar at any
depth) registers a `(local $<name> i32)` declaration before body
emission, mirroring how the existing LLet (304) / LBlock (315) /
LIf (314) cases descend.

---

## §2 Eight interrogations

| # | Interrogation | Resolution |
|---|---|---|
| 1 | **Graph?** | LPVar's `name` field at record offset 1; LPCon's `args` list at offset 2; LMatch's `arms` list at lexpr offset 2; LPArm's `pat` at offset 0, `body` at offset 1; tag-int dispatch via `$tag_of`. The graph already carries every binding's name string-pointer at the LPVar record level — the residue is one structural walk, not a separate ledger. |
| 2 | **Handler?** | Direct emit projection; `@resume=OneShot` (no continuation capture; structural walk). The `$emit_let_locals` family IS the handler over LowExpr containers; the residue extends one arm + adds two helpers in the same shape as the existing LBlock / LIf arms. |
| 3 | **Verb?** | N/A — structural recursive walk. (The five verbs apply at composition boundaries; this is intra-handler descent.) |
| 4 | **Row?** | `EmitMemory` effect — writes to `$out_base` via `$emit_str` and `$emit_cstr`. No allocation, no consumes; same effect row as the LLet arm. |
| 5 | **Ownership?** | LowPat record `ref`-borrowed throughout the walk; LowExpr arms list `ref`-borrowed; no consume. |
| 6 | **Refinement?** | `LPVar.name` is a non-zero string-pointer per the arity-2 LPVar contract (`$lowpat_make_lpvar(handle, name)` at `bootstrap/src/lower/lowpat.wat:87`). LPRecord/LPList `rest_var` is 0 OR a non-zero string-pointer per the lowpat.wat contract (lines 159 + 178). The walk `i32.ne $rest 0` guard is the substrate-honored refinement check. |
| 7 | **Gradient?** | The local-decl ledger derives from LowPat substrate at emit-time; this is the runtime fallback. The compile-time capability that would unlock dropping the walk is "fn-body local-decl synthesized at lower-time as part of LowFn" — peer follow-up `Hβ.emit.lowfn-carries-local-decl-set`, NOT in scope here. |
| 8 | **Reason?** | LPVar's handle (record offset 0) preserves the source-level Reason chain; this walk does not write Reasons (emit-time, not infer-time). The Why Engine walks back to the binding via the handle on the LPVar record — already populated by lower per `$lowpat_make_lpvar`. |

---

## §3 Forbidden patterns

| Drift mode | Refusal at this site |
|---|---|
| **1** (Rust vtable) | NO `$emit_pat_locals_table`, NO closure-as-vtable, NO function-pointer array. Tag-int comparison via `(i32.eq (local.get $tag) (i32.const N))` chain — same shape as the existing LLet/LBlock/LIf arms in `$emit_let_locals`. The word "vtable" does not appear in this walk. |
| **6** (Bool special-case) | Every binding-introducing LowPat variant goes through the same `$emit_pat_locals` recurse. LPCon (363) — including the LPCon-Bool case from HB drift-6 closure where Bool true/false are `LPCon(LBool sentinel, [])` — uses the same args-list iteration as user-defined N-ary constructors. NO special-case for Bool / Unit / nullary-arity patterns. |
| **7** (parallel arrays) | NO `body_local_names` accumulator list, NO sorted-set of seen names, NO `(name, type)` parallel arrays. The local-decl ledger is the LowPat substrate itself; `$emit_pat_locals` streams declarations directly to `$out_base` as it walks. One record-tree + one walker, NOT N parallel lists. |
| **8** (string-keyed-when-structured) | Tag-int dispatch via `$tag_of`; LPVar's name is a string-pointer because the LANGUAGE's local-name surface IS string-shaped (WAT's `$x` token), not because we are flag-as-int-ing structure. Each LowPat variant is its own ADT tag. |
| **9** (deferred-by-omission) | LPVar (top-level direct binding) AND LPCon-sub-LPVar AND LPTuple-elem-LPVar AND LPRecord-field-LPVar AND LPList-elem-LPVar AND LPAs-name AND LPAs-inner-pat-LPVar all walked **in this commit**. LPRecord/LPList `rest_var` (string-pointer, zero or name) handled in same arms. LPWild (361) / LPLit (362) / LPAlt (367) bind nothing per `bootstrap/src/lower/lowpat.wat:99-122 + 195-208` — terminal arms in the walk, not deferred. |

Peer follow-ups (Drift-9 named, NOT deferred-by-omission):

- `Hβ.first-light.match-arm-binding-name-uniqueness` — IF E.2 surfaces `wat2wasm` rejecting with `redefinition of local "$x"` when two arms bind the same source-level name, the lower-side rename pass is named as a peer; not in scope here. (See §G.3.)
- `Hβ.emit.lowfn-carries-local-decl-set` — gradient-7 cash-out: lower carries an explicit local-decl set on the LowFn record so emit reads the set instead of re-walking; not in scope.

---

## §4 Edit sites

All in `bootstrap/src/emit/main.wat` (HEAD line numbers; planner
notes the file may have shifted slightly):

| Edit | Site | Action |
|---|---|---|
| **C.1** | After `$emit_let_locals_walk`'s closing `(return))` (line 1010) and the C.3 `$emit_match_arm_locals` block, BEFORE the chunk-header comment for `$emit_functions` (line 1012) | NEW `$emit_pat_locals` helper — recursive LowPat walker emitting one `(local $<name> i32)` per binding-introducing variant. |
| **C.2** | Inside `$emit_let_locals` at lines 958-992, BEFORE the `;; LMakeClosure (311) / LMakeContinuation (312) — fn boundary,` comment (line 988) | NEW LMatch (321) arm — recurses scrut via `$emit_let_locals_walk`, iterates arms via `$emit_match_arm_locals`. |
| **C.3** | After `$emit_let_locals_walk`'s closing `(return))` (line 1010), BEFORE the C.1 `$emit_pat_locals` helper | NEW `$emit_match_arm_locals` helper — iterates an arms list, walking each LPArm's pat via `$emit_pat_locals` and each LPArm's body via `$emit_let_locals_walk`. |
| **C.4** | Inside `$emit_let_locals_walk` at lines 996-1010, AFTER the LIf (314) arm's closing `(return)))` and BEFORE the final outer `(return))` | NEW LMatch (321) arm — single-expr LMatch encountered via LLet's value descent. Symmetric with the existing LBlock + LIf arms. |

Insertion order (per plan §D): C.3 first (forward-declared by C.4
and C.2; WAT supports forward refs within the same module), then
C.1, then C.4, then C.2.

---

## §5 Locks

1. **Lock #1 — LMatch scrut + arms BOTH walked.** `$emit_let_locals`'s LMatch arm must recurse the scrutinee (the scrut may contain nested LLet bindings via LBlock destructure of complex values) AND iterate the arms. Symmetric with the LIf arm which walks `then` AND `else`.
2. **Lock #2 — `$emit_pat_locals` walks every binding-introducing LowPat.** Direct LPVar (360); LPCon (363) — recurse into args list; LPTuple (364) — recurse into elems list; LPRecord (366) — recurse into each (name, pat) field's pat AND emit `rest_var` if non-zero; LPList (365) — recurse into elems list AND emit `rest_var` if non-zero; LPAs (368) — emit the as-name AND recurse the inner pat. LPWild (361) / LPLit (362) / LPAlt (367) — bind nothing, terminate the walk for that node.
3. **Lock #3 — NO de-duplication across arms.** WAT requires unique local names within a (func ...). If two arms bind the same source-level name (e.g. `Just(x) => ... ; Nothing => let x = ... ;`), the seed already collides. The fix at THIS layer is the structurally-correct walk; the uniqueness obligation is enforced at lower-time (substrate gap if collisions surface). If §E.2 reveals such collisions in the wheel, the peer follow-up `Hβ.first-light.match-arm-binding-name-uniqueness` lands separately. The planner verifies by running the wheel through the post-fix seed; if no collisions surface, this lock holds without amendment.
4. **Lock #4 — NO new LowPat / LowExpr tags.** This walk is purely emit-side; LowPat/LowExpr tag region 300-369 unchanged. Tags 360-369 in `bootstrap/src/lower/lowpat.wat:34-43` remain authoritative.
5. **Lock #5 — Helpers live adjacent to `$emit_let_locals`.** `$emit_pat_locals` and `$emit_match_arm_locals` are inserted IMMEDIATELY AFTER `$emit_let_locals_walk` in `bootstrap/src/emit/main.wat`, BEFORE `$emit_functions`. This places the four-function family — `$emit_let_locals`, `$emit_let_locals_walk`, `$emit_match_arm_locals`, `$emit_pat_locals` — in one contiguous block; the chunk reader's eye sees the local-decl-projection family in one place.

---

## §6 Forbidden patterns audited per edit site

- **C.1 ($emit_pat_locals)** — Drift 1 refused (no table; if/eq chain). Drift 6 refused (LPCon's args walked uniformly, Bool-LPCon walks the same path). Drift 7 refused (no name-accumulator). Drift 8 refused (tag-int dispatch). Drift 9 refused (LPVar/LPCon/LPTuple/LPRecord/LPList/LPAs all walked; LPWild/LPLit/LPAlt explicitly terminal — bind nothing). Sub-handle scope clean per §3.
- **C.2 (LMatch arm in $emit_let_locals)** — Same shape as the existing LLet/LBlock/LIf arms. Drift 1 refused (tag-int compare). Drift 6 refused (no Bool-special). Drift 9 refused (scrut + arms both walked).
- **C.3 ($emit_match_arm_locals)** — Drift 1 refused (linear iteration). Drift 6 refused (every arm gets the same walk). Drift 7 refused (no per-arm accumulator; structural walk per arm). Drift 9 refused (loop terminates on len; no skipped arms).
- **C.4 (LMatch arm in $emit_let_locals_walk)** — Symmetric with the LBlock / LIf arms in the same function. Drift 1 refused. Drift 6 refused. Drift 9 refused.

The drift-audit (`tools/drift-audit.sh bootstrap/src/emit/main.wat`)
runs as §E.3.

---

## §7 Tag region

`bootstrap/src/lower/lowpat.wat:34-43` — tags 360-369 unchanged.
`bootstrap/src/lower/lexpr.wat:95` — LMatch tag 321 unchanged.
NO tag additions; the substrate is purely emit-side projection of
the existing tag region.

---

## §8 Test harness path

`bootstrap/test/emit/match_arm_pat_binding_local_decl.wat` — see
§F. Constructs a hand-authored LowFn whose body is:

```
LMatch(scrut=LLocal($m), arms=[
  LPArm(LPCon(handle, Just_tag, [LPVar(handle, $x)]), LLocal($x)),
  LPArm(LPCon(handle, Nothing_tag, []),               LLocal($d)),
])
```

Calls `$emit_fn_body`. Scans output for the substring
`(local $x i32)` exactly once in the function preamble. Exits 0
on PASS, 1 on FAIL.

Registered in `bootstrap/test/INDEX.tsv` per the existing harness
manifest convention (Phase E + Phase F precedent rows).

---

## §9 Drift-9 named follow-ups

Sub-handles NOT landing this commit but explicitly named so they
are tracked, not deferred-by-omission:

- `Hβ.first-light.match-arm-binding-name-uniqueness` — only if
  collisions surface in the wheel post-fix; lower-time rename
  pass for shadowed sub-pattern bindings.
- `Hβ.emit.lowfn-carries-local-decl-set` — gradient-7 cash-out:
  carry the local-decl name set on the LowFn record itself,
  populated at lower-time, so emit reads instead of re-walking.
  Pure refactor for compile speed; no semantic change.

LPTuple elem-LPVar bindings, LPRecord field-LPVar + rest_var,
LPList elem-LPVar + rest_var, LPAs name + inner-pat-LPVar — ALL
included in C.1; NOT named as follow-ups (they land this commit).

---

## §10 Verification gates

| Gate | Action |
|---|---|
| **E.1** (primary) | The §A.1 reproduction program emits a `$unwrap` body whose preamble contains `(local $x i32)` exactly once; `wat2wasm /tmp/match_local.wat -o /tmp/match_local.wasm` succeeds with NO `undefined local variable` errors for `$x`. |
| **E.2** (L1 regression) | HEAD self-bootstrap (`cat src/main.mn \| wasmtime run bootstrap/mentl.wasm \| wat2wasm -`) candidate-diagnostic count BEFORE fix recorded; post-fix count must NOT increase. Expected: undefined-local-variable count strictly decreases. |
| **E.3** (drift) | `bash tools/drift-audit.sh bootstrap/src/emit/main.wat` clean (zero matches). |
| **E.4** (existing) | `bash bootstrap/test.sh` — all currently-passing harnesses pass post-fix; specifically `bootstrap/test/emit/main_inka_emit_smoke.wat` + `bootstrap/test/emit/emit_lmatch.wat` still PASS. |
| **E.5** (self-bootstrap delta) | `wat2wasm` undefined-local-variable count on `/tmp/inka2.wat` strictly decreases relative to HEAD baseline. |

---

## §11 Per CLAUDE.md anchors

- **Anchor 0** (dream code; lux3.wasm not the arbiter) — substrate
  authored against the canonical seed shape, not against any
  specific binary's parser tolerance. Verification by simulation
  + walkthrough + audit + harness.
- **Anchor 1** (graph already knows it) — LowPat substrate
  already encodes every binding's name string-pointer at the
  LPVar record. We do not invent a parallel name ledger; we
  read what the graph already carries.
- **Anchor 2** (don't patch; restructure or stop) — `$emit_let_locals`
  has THREE container arms (LLet / LBlock / LIf); the LMatch arm
  is the same shape, NOT a patch. The two new helpers
  (`$emit_pat_locals` + `$emit_match_arm_locals`) factor the
  pattern-side and arm-side descents so the structural symmetry
  is preserved across all four arms.
- **Anchor 4** (build the wheel; never wrap) — substrate writes
  the canonical form; no V1 to bridge.
- **Anchor 7** (cascade discipline; walkthrough first; land whole)
  — this walkthrough lands FIRST, in its own commit, then
  substrate + harness in a second commit per `mentl-implementer`
  dispatch §D order.

---

## §12 Closure

This handle closes when:

1. The walkthrough commit lands (this document).
2. The substrate commit lands (`$emit_pat_locals` + `$emit_match_arm_locals` in `bootstrap/src/emit/main.wat`; LMatch arms in `$emit_let_locals` + `$emit_let_locals_walk`; harness at `bootstrap/test/emit/match_arm_pat_binding_local_decl.wat`).
3. `Hβ-first-light-empirical.md` §2.3 item 3 receives a closure addendum citing both commits.

Three-commit citation: this walkthrough + substrate + the
`Hβ-first-light-empirical.md` closure addendum (third commit
not authored under THIS dispatch — separate planner-issued
follow-up after substrate lands and the wheel is verified
under the new seed). Per the `mentl-implementer` contract, this
dispatch lands two commits (walkthrough, substrate); the
empirical closure addendum is named as the named follow-up
for the next planner cycle.
