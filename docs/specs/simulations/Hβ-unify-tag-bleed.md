# Hβ-unify-tag-bleed — chase-loop trap on real-source self-compile

> **Status:** walkthrough first (Anchor 7); §5 residue is **CONDITIONAL on §2.1
> harness outcome** and Plan D.2 selects the residue branch after running the
> harness. Plan D.2 is a separate dispatch.
> **Phase tag:** `Hβ.unify-tag-bleed` — peer to Hβ-infer-bind-completeness
> closure (commit `73fc5f9`); Family-A/B/C bind-completeness landed but
> exposed a deeper-env-reach trap that the harness diet did not cover.
> **Cascade-state context:** `cat src/*.mn lib/**/*.mn | wasmtime run
> bootstrap/mentl.wasm` exits 134 (SIGABRT) with backtrace
> `tag_of ← ty_tag ← graph_chase_loop ← graph_chase ← unify ←
> infer_walk_expr_binop ← ...`. Trap address `0x2820706f` (672 MiB) sits
> two orders of magnitude above the 32 MiB linear-memory ceiling
> (`0x2000000`); the bytes `\x6f\x70\x82\x28` decode to `op·(` —
> the ASCII fragment "op" is suggestive of string-content being read as
> a heap pointer. The companion 100+ `E_MissingVariable` lines + two
> `E_TypeMismatch: expected Int, found fn(...) -> ?N` lines are the
> productive-under-error projection that *immediately precedes* the trap.
> Plan A's lambda-param env-extend (commit `73fc5f9` §5.3) and pre-register-
> typedef expansion (Plan A §5.1) caused real-source AST to reach call/
> instantiate/chase paths the harness diet (77 PASS) never exercised.

---

## §0 Framing — Session Zero stub

The seed's `bootstrap/src/infer/unify.wat` realizes the unification core of
HM inference's productive-under-error projection (kernel primitive #8; see
SUBSTRATE.md §I "The First Truth"). Each call to `$unify(h_a, h_b, span,
reason)` chases both handles through `graph_chase_loop` (graph + env;
primitive #1) until a terminal NodeKind dispatches to a Ty-tag arm in
`$unify_types` — which then composes with $graph_bind / $graph_bind_kind
mutations the trail records (multi-shot rollback substrate per insight
#11; primitive #2 with `@resume=OneShot` at the seed since rollback is a
peer concern). The five verbs (#3) are upstream of this surface; row
algebra (#4 — TFun's row field) is preserved verbatim until row.wat ships;
ownership (#5) and refinement (#6) flow through TFun's params and
TRefined's predicate fields opaquely; the gradient (#7) cashes out as
`Forall([], _)` monomorphic-pin discipline at every fresh-handle bind.
The eighth — Reason chains — wraps every $graph_bind via $reason_make_located,
which the Why Engine walks. **The trap interrupts the chase BEFORE
productive-under-error fires** — meaning a Ty record with structurally-
invalid payload reached `tag_of`'s `i32.load` at a non-existent address.
Whichever ADT carries the invalid field IS the bleed surface; Plan A's
deeper bind-form coverage now drives instantiate/chase paths whose
allocation hygiene the seed never proved. Mentl is an octopus because the
kernel has eight primitives; this trap is a primitive #1 (graph) failure
mid-chase that primitive #8 (productive-under-error) cannot catch because
the chase HARDWARE-FAULTS before the diagnostic emit fires.

---

## §1 Trap inventory — proof, not hypothesis

### §1.1 Backtrace

```
0:   0x1ad0 - tag_of                           record.wat:49-52
1:   0x603f - ty_tag                           ty.wat:248-249
2:   0x1e1b - graph_chase_loop                 graph.wat:264-296
3:   0x1de1 - graph_chase                      graph.wat:261-262
4:   0x725f - unify                            unify.wat:204-272
5:   0x87ca - infer_walk_expr_binop            walk_expr.wat:576-660
6:   0x969a - infer_walk_expr                  walk_expr.wat:1706-1794
7:   0x8a74 - infer_walk_expr_if               walk_expr.wat:803-831
8:   0x96e6 - infer_walk_expr                  walk_expr.wat:1706-1794
9:   0x9bbf - infer_walk_stmt_fn               walk_stmt.wat:540+ (mint branch)
...
14:  0x10a85 - sys_main
```

The trap address is read at `tag_of`'s line 52 `(else (i32.load (local.get
$ptr)))` — the `$ptr` argument is the offending value. Because `tag_of`'s
caller `ty_tag` calls `tag_of($ty)` directly, **the offending pointer is
the `$ty` value at line 284 of graph.wat** — captured from
`node_kind_payload($nk)` at line 283.

### §1.2 Address decode

`0x2820706f` = 672_440_431 dec. Linear-memory size at trap is `0x2000000` =
32 MiB; the address is **20× the heap ceiling**. Bytes (LE):

```
byte 0 = 0x6f = 'o'
byte 1 = 0x70 = 'p'
byte 2 = 0x82
byte 3 = 0x28 = '('
```

The fragment `op·(` is highly suggestive of string content being read as
a heap pointer. Plausible string sources by data-segment audit
(walk_expr.wat:265-300; reason.wat strings; emit_diag.wat strings):
- `walk_expr.wat:285` segment `"<call>"` — fragment "call(" possible.
- `walk_expr.wat:300` segment `"<expr>"` — no "op".
- `reason.wat`'s `OpConstraint` Reason carries `op_str` — converted from
  BinOp tag int via `$int_to_str` at `walk_expr.wat:589`. `"144"`/`"145"`
  produced — no "op" prefix.
- `emit_diag.wat`'s `$render_ty` walker emits `"fn ("` for TFun — fragment
  `"n ("` possible if mid-render, but render_ty doesn't run on this path.

The most likely substrate: `op_<name>` strings produced by emit_handler
fn-pointer naming OR variable names like `op_str`, `operand_*`. The exact
string source is named as a Plan D.2 §1 first-step (`wasm-objdump -d
bootstrap/mentl.wasm | grep -A2 'tag_of'` + memory-region map at trap; the
binary's data segments project onto specific addresses post-mass-allocation).

### §1.3 Heap-region map (Tier 1 substrate)

Per `bootstrap/mentl.wat:7-13` + `bootstrap/src/runtime/memory.wat` (or the
inline globals in mentl.wat if memory.wat absent):

| Region | Range (bytes) | Contents |
|---|---|---|
| Sentinel zone | `[0, 4096)` = `[0, 0x1000)` | nullary ADT sentinels, static data segments |
| Pre-allocator gap | `[0x1000, 0x100000)` | reserved; 1 MiB |
| Bump heap | `[0x100000, 0x2000000)` | dynamic records (Ty, Scheme, Env, GNode...) |
| Post-heap | `[0x2000000, ∞)` | OUT OF BOUNDS — trap region |

Trap address `0x2820706f` is `0x820706f` past the heap ceiling. The bump
allocator init is at `bootstrap/mentl.wat` (search `$heap_ptr` global init);
HEAP_BASE = 4096 per CLAUDE.md "memory model" + `bootstrap/mentl.wat:7`.
Bytes "op·(" in a pointer position confirm a Ty-shaped record contained
8-bit string data where a heap-ptr-or-sentinel was expected.

### §1.4 Companion diagnostics

```
E_MissingVariable: list_index at handle 558
E_MissingVariable: list_index at handle 585
E_MissingVariable: pack_str at handle 591
E_TypeMismatch: at handle 967 — expected Int, found fn(...) -> ?964
E_TypeMismatch: at handle 985 — expected Int, found fn(...) -> ?982
```

Two structural facts:

1. The 100+ `E_MissingVariable: list_index/pack_str/...` lines are
   Family D (genuine $-prefixed runtime intrinsics) per Plan A's
   §11 follow-up — productive-under-error binding NErrorHole at the
   VarRef handle. **Those bindings DON'T trap; they're the CORRECT
   productive-under-error projection.**

2. The two `E_TypeMismatch` lines fire from `$type_mismatch` in unify.wat
   (lines 649-657) — which means $unify_types reached a TInt-vs-TFun
   shape pair and emitted the diagnostic + bound the diag handle to
   NErrorHole. **These two TypeMismatch lines complete and the walk
   continues** — the trap does NOT fire on these handles. The trap fires
   later, on a DIFFERENT handle's chase, AFTER productive-under-error
   accepted the TInt/TFun mismatches and continued.

The composition of (1) + (2) localizes the trap to: a chase-loop reaching
an NBound payload that is structurally-invalid AS A Ty pointer — i.e.,
the value stored as `node_kind_payload` at some prior `$graph_bind` was
NOT a valid Ty record.

### §1.5 Suspect arms (where could `$graph_bind(handle, X, reason)` write
a non-Ty `X`?)

Audit of every `$graph_bind` call site in bootstrap/src/:

| File:line | Caller | $ty_ptr value | Verified Ty? |
|---|---|---|---|
| unify.wat:227 (NFree arm) | `$unify` | `ty_make_tvar($h_b)` | YES — Ty record tag 104 |
| unify.wat:238 (NFree-on-right) | `$unify` | `ty_make_tvar($h_a)` | YES |
| unify.wat:342 (TVar arm) | `$unify_types` | `$b` (right operand) | UPSTREAM-VERIFIED — §1.6 |
| unify.wat:600 ($expect_same TVar-on-right) | `$expect_same` | `$a` (left operand) | UPSTREAM-VERIFIED — §1.6 |
| unify.wat:655 ($type_mismatch) | binds via $infer_emit_type_mismatch (NErrorHole) | not direct $graph_bind | N/A |
| graph.wat:360-376 ($graph_bind) | direct API | caller's $ty_ptr | depends on caller |
| graph.wat:395-405 ($graph_bind_kind) | binds NodeKind directly | NodeKind, not Ty | N/A |
| walk_expr.wat: many sites | per-arm | ty_make_t* constructors | YES per arm |
| walk_stmt.wat: ditto | per-arm | ty_make_t* constructors | YES per arm |
| emit_diag.wat: NErrorHole binds | productive-under-error | bind_kind, not bind | N/A |

The only paths writing TY pointers to NBound that aren't direct
ty_make_t* calls go through `$unify` line 342 + `$expect_same` line 600
— both pass through Ty values originating from `node_kind_payload`. So
the corruption either originates upstream in `node_kind_make_nbound`'s
`$ty_ptr` argument at the FIRST bind on the offending handle, OR through
`$instantiate`'s rebuild of a TFun when its substituted parts traverse
a corrupt sub-record.

### §1.6 Upstream-verification: the $instantiate substitution map

`scheme.wat:876-890` $instantiate calls `build_inst_mapping(qs, qs_n)` then
`ty_substitute(body, map, qs_n)`. `build_inst_mapping` (lines 900-920)
mints a fresh handle per quantified slot via `$graph_fresh_ty(reason)`.
**Critical observation:** the quantified list constructed by
`$infer_pre_register_quantifier` (walk_stmt.wat:406-426) contains
**`[param_handles..., ret_h, row_h]`** — `row_h` is a ROW handle (allocated
via `$graph_fresh_row`, kind NRowFree, tag 63), but it's stored alongside
type handles in the same flat `qs` list.

When `build_inst_mapping` reaches `row_h`:
- `$graph_fresh_ty($reason)` mints a NEW handle whose NodeKind is NFree
  (tag 61), not NRowFree.
- `$subst_map_extend(map, i, row_h, fresh_ty_h)` — the map now contains
  `(row_h_int, fresh_ty_h_int)`.

Then `ty_substitute(body, map, len)` walks the TFun body:
- TFun arm (line 717-726): `ty_make_tfun(ty_substitute_params(params),
  ty_substitute(ret), ty_tfun_row(ty))`. **The `row` field is preserved
  verbatim — `ty_substitute` is NEVER called on the row** (line 726
  passes `ty_tfun_row($ty)` straight through). So `row_h` is preserved as
  the original row handle in the rebuilt TFun. The map entry `(row_h,
  fresh_ty_h)` is unused for the row position.

Equivalently: TVar(handle) arm at line 690-698 looks up the handle in
the map. If a `TVar(row_h)` appears INSIDE the body Ty (e.g., embedded
in TParam.ty for a row-polymorphic param), `ty_substitute` would rewrite
it to `TVar(fresh_ty_h)` — substituting a row handle's slot with a
type-fresh handle. **This IS a potential corruption surface.**

### §1.7 Hypotheses (each falsifiable by §2.1 phase outcome)

**H-A (LEAD) — Plan A pre-register quantifies row_h, instantiate corrupts
on recursive call paths.**
- The pre-register quantifier list `[param_handles, ret_h, row_h]` puts
  `row_h` in qs. When a polymorphic fn (FnScheme) is instantiated and
  the body's TFun row position is preserved verbatim, the row position
  carries the *original* `row_h`. Cross-category handle reuse is the
  corruption surface.

**H-B — `$ty_make_tfun` field initialization stale-bytes leak.**
- `$make_record(107, 3)` allocates 8+12=20 bytes via `$alloc`. The bump
  allocator is monotonic; `$alloc` returns a fresh region but does NOT
  zero-initialize. `record_set` writes all three fields. **Fully-
  initialized**; no stale bytes. REJECTED at static audit. Confirm via U.1.

**H-C — `graph_chase_loop` cycle bound silently absorbs malformed chain.**
- Line 268-273: at depth > 100 returns NErrorHole GNode. Not a corruption
  surface; rather a performance wart. REJECTED for trap.

**H-D — BinOp BKArith arm unifies LH/RH children where one is fn-typed.**
- The TWO E_TypeMismatch lines prove this exact path fired twice cleanly.
  Diagnostic-emit precondition, not the trap surface.

**H-E — NErrorHole-bound handle: subsequent chase reads payload as Ty.**
- unify line 255-256 NErrorHole arm returns. No trap on this path. Phase
  U.5 closes this surface.

**H-J — TParam field-swap (string in Ty position).**
- TParam layout `[tag=202][arity=4][name][ty][authored][resolved]`. If
  field 1 was written with a STRING pointer instead of a Ty pointer
  (field-swap drift), `ty_tag` reads bytes from the string's UTF-8
  region — exactly what the trap shows. Phase U.7 + §2.4 wasm-objdump
  bisect this.

---

## §2 Localizing the bug — diagnostic harness FIRST

Per Anchor 7: §2.1 harness MUST be authored AND RUN before §5 ships its
authoritative residue. The harness lives at
`bootstrap/test/infer/unify_tag_bleed_diag.wat` and is added to
`bootstrap/test/INDEX.tsv` per the harness convention.

### §2.1 Harness specification — `unify_tag_bleed_diag.wat`

Drives `$unify` and `$graph_chase` against constructed-from-substrate-
primitives input shapes simulating real-source self-compile call paths.

| Phase | Tests | If FAIL → residue location |
|-------|-------|----------------------------|
| U.1 | `$ty_make_tfun` field hygiene; build TFun([], TInt, 999_row) and read each field; verify tag is 107 and each field reads the value written | ty.wat:308-315 ty_make_tfun field-write order |
| U.2 | `$unify` identity short-circuit; unify(h, h) doesn't recurse on bound h_a == h_b | unify.wat:211-213 |
| U.3 | basic graph_bind + chase to TInt; bind TVar to TInt; chase terminates at TInt sentinel | graph.wat:264-296 chase loop |
| U.4 | TFun-vs-TInt productive-under-error; the EXACT failing shape from /tmp/inka2-now.err — must emit TypeMismatch + bind NErrorHole, MUST NOT TRAP | unify.wat:394-423 TFun arm + emit_diag.wat type_mismatch |
| U.5 | NErrorHole-bound handle: bind to NErrorHole productive-under-error, then unify against TInt; line 255 NErrorHole arm should no-op | unify.wat:255 NErrorHole arm |
| U.6 | TVar(row_h) chase termination; construct TVar wrapping row_h, bind a fresh ty handle, chase. graph_chase_loop sees NBound payload tag = 104 (TVar), recurses with row_h. row_h's GNode is NRowFree (63); chase falls through line 296 — returns NRowFree GNode. **MUST NOT TRAP. If U.6 traps, H-A is THE residue.** | graph.wat:281-289 chase NBound→TVar→handle recursion |
| U.7 | pre-register + instantiate + unify; mint pre-registered fn handle with `[param_handles..., ret_h, row_h]` quantifier list, instantiate, simulate BinOp arith arm against TInt. **If U.7 traps OR U.7b (row substitution leak) FAILs, the residue is in pre-register-quantifier composition AND/OR ty_substitute's row preservation.** | walk_stmt.wat:406-426 quantifier construction; scheme.wat:876-920 instantiate |

Each phase asserts via `wasi_proc_exit(1)` on failure; never `unreachable`
nor `out of bounds`.

### §2.3 Real-source bisection (Plan D.2 step 1)

After §2.1 phases run, Plan D.2's first step is the bisection probe:
```
cat lib/runtime/strings.mn | wasmtime run bootstrap/mentl.wasm > /tmp/strings.wat 2> /tmp/strings.err
echo "exit: $?"
grep -c E_MissingVariable /tmp/strings.err
grep -c E_TypeMismatch /tmp/strings.err
grep "wasm trap" /tmp/strings.err
```
**Expected outcomes:**
- If `strings.mn` alone exits cleanly (productive-under-error only, no
  trap), the trap is composition-dependent (multi-file deeper-env).
- If `strings.mn` alone traps at the same address, the trap is
  single-file-reachable; bisect further by halving file content.

### §2.4 wasm-objdump localization (Plan D.2 step 2)

```
wasm-objdump -d bootstrap/mentl.wasm | grep -B1 -A8 'tag_of' > /tmp/tag_of.dec
wasm-objdump -x bootstrap/mentl.wasm > /tmp/sections.txt
# Identify which data segment contains the bytes "op" + offset, AND
# which Ty constructor is most-likely to have stored that string-as-pointer.
```

---

## §3 Eight interrogations per fixed arm

The §5 residue branches by §2.1 outcome. Below interrogations cover the
two LEAD residue surfaces; selection by Plan D.2.

### §3.1 If H-A confirmed (U.6 trap or U.7b leak): pre-register quantifier
should NOT include row_h.

| # | Interrogation | Answer |
|---|---|---|
| 1 | Graph?       | The graph already separates ty handles (NFree/NBound) from row handles (NRowFree/NRowBound) at the NodeKind tag layer. Mixing them in a quantifier list erases that distinction; the residue keeps row_h OUT of the quantifier list. |
| 2 | Handler?     | `$infer_pre_register_quantifier` is the projection. `@resume=OneShot` (single recursive copy). The wheel `src/infer.mn:96-149` `pre_register_fn_sigs` quantifies over ty handles only — row generalization awaits row.wat substrate. |
| 3 | Verb?        | N/A — substrate-internal. |
| 4 | Row?         | This IS the row interrogation: row generalization at FnStmt SHOULD quantify row vars per spec 04 §Generalizations, but ONLY when row.wat's `$row_substitute` is the projection that handles them. Until row.wat ships, row vars are NOT polymorphic; the seed conservatively monomorphizes row positions per Hβ.infer.row-normalize follow-up. |
| 5 | Ownership?   | Quantifiers are reference-counted-once into the Forall record. No Consume. |
| 6 | Refinement?  | Each quantifier is monomorphic-pin via Forall machinery. |
| 7 | Gradient?    | Removing row_h from qs IS a gradient step — it pins row to its current handle rather than re-instantiating fresh per call site. |
| 8 | Reason?      | Each quantifier carries `Located(span, Declared(name))` per pre_register_fn_sig; the residue preserves this for ty handles only. |

### §3.2 If H-J confirmed (string-in-Ty-field): TParam construction emits
the wrong field at offset 4.

| # | Interrogation | Answer |
|---|---|---|
| 1 | Graph?       | TParam's record layout (tparam.wat:26-36): `[tag=202][arity=4][name][ty][authored][resolved]`. Reading field 1 (`tparam_ty`) gets the Ty pointer. If field 1 was written with a STRING pointer instead of a Ty pointer (field-swap drift), `ty_tag` reads bytes from the string's UTF-8 region — exactly what the trap shows. |
| 2 | Handler?     | TParam construction sites: `walk_expr_build_inferred_params` (walk_expr.wat:366-386), `walk_stmt_build_inferred_params`, `pre_register_fn_sig`'s param iteration (walk_stmt.wat:355-378), and the lambda arm Plan A landed (walk_expr.wat:758-783). |
| 3 | Verb?        | N/A. |
| 4 | Row?         | N/A. |
| 5 | Ownership?   | Fields are positional; ownership invariant is "every record_set writes the right field." |
| 6 | Refinement?  | The residue MUST be the literal `tparam_make(name, ty, authored, resolved)` shape — no field-swap drift. |
| 7 | Gradient?    | N/A. |
| 8 | Reason?      | TParam's authored/resolved Ownership ARE the Why-edge for the param's ownership decision; preserved verbatim. |

---

## §4 Forbidden patterns per drift mode

- **Drift 1 (Rust vtable):** REFUSE introducing a "kind table" indexed
  by handle — graph_chase_loop dispatches on NodeKind tag via i32.eq.
- **Drift 2 (Scheme env frame):** REFUSE adding a "type-vs-row scope
  stack" — the graph already distinguishes via NodeKind tag.
- **Drift 3 (Python dict):** REFUSE keying any quantifier-segregation
  table by string-name. Discrimination is by NodeKind tag (61 vs 63).
- **Drift 4 (Haskell MTL):** REFUSE wrapping `instantiate` in a separate
  pre-pass handler. Instantiate IS the pre-call projection of $env_lookup.
- **Drift 5 (C calling convention):** REFUSE adding an `__is_row` bit
  alongside each handle integer. NodeKind tag IS the discrimination.
- **Drift 6 (primitive-type-special-case):** REFUSE giving row handles
  a different code path than ty handles in instantiate's per-quantifier
  loop. The fix is to PARTITION the quantifier list (ty handles only)
  at construction time, not to special-case at instantiate time.
- **Drift 7 (parallel-arrays-instead-of-record):** REFUSE storing
  `qs_ty[]` and `qs_row[]` as separate parallel lists. If row
  generalization needs to ship later, the Forall record gets a NEW
  field `row_quantifiers` (single list of row-handles), not parallel
  arrays sharing structure with `quantifiers`.
- **Drift 8 (string-keyed-when-structured):** REFUSE branching the
  quantifier-construction on `tag == 61 || tag == 63` literal. Use
  graph.wat's existing `$is_nfree` / `$is_nrowfree` predicates.
- **Drift 9 (deferred-by-omission):** REFUSE landing a fix that "monkeys
  the symptom" by clamping graph_chase_loop's depth lower or adding
  defensive `(if (out_of_bound) (then (return errorhole)))` guards.
  The trap is a CORRUPT POINTER, not a depth issue. Guarded chase that
  silently absorbs corrupt pointers IS drift mode 9.
- **Bug class — `_ => fabricated TInt fallback`:** REFUSE adding a
  default TInt arm in graph_chase_loop or unify_types that absorbs
  unknown tags. Unknown tag must trap via `(unreachable)`, surfacing
  the bug rather than masking.

---

## §5 Residue (CONDITIONAL on §2 outcome)

§5 specifies the lines that should EXIST. **The choice between §5.1,
§5.2, §5.3 is gated on §2.1 harness phases' outcomes** AND on §2.3
bisection. Plan D.2's first step is to RUN the harness; the residue
branch becomes authoritative only after §2.1 + §2.3.

### §5.1 If H-A confirmed (U.6 PASS but U.7b FAIL or U.7 traps):
**partition the pre-register quantifier list — row_h stays OUT.**

Edit `bootstrap/src/infer/walk_stmt.wat:406-426`
(`$infer_pre_register_quantifier`). The residue removes the row_h slot —
quantifier list is `[param_handles..., ret_h]`, NOT `[param_handles...,
ret_h, row_h]`. The signature drops `$row_h`:

```
(func $infer_pre_register_quantifier
      (param $param_handles i32) (param $ret_h i32)
      (result i32)
  (local $n i32) (local $out i32) (local $i i32)
  (local.set $n (call $len (local.get $param_handles)))
  (local.set $out
    (call $list_extend_to (call $make_list (i32.const 0))
                          (i32.add (local.get $n) (i32.const 1))))   ;; +1 for ret_h, NOT +2
  (local.set $i (i32.const 0))
  (block $copy_done
    (loop $copy
      (br_if $copy_done (i32.ge_u (local.get $i) (local.get $n)))
      (drop (call $list_set (local.get $out) (local.get $i)
        (call $list_index (local.get $param_handles) (local.get $i))))
      (local.set $i (i32.add (local.get $i) (i32.const 1)))
      (br $copy)))
  (drop (call $list_set (local.get $out) (local.get $n) (local.get $ret_h)))
  (local.get $out))
```

Update caller at `walk_stmt.wat:393-400` to drop the row_h argument.

**Wheel canonical:** `src/infer.mn:96-149` (`pre_register_fn_sigs`) +
`src/infer.mn:1818-1834` (`generalize`). The wheel quantifies type-side
free handles only; row generalization is the named follow-up
`Hβ.infer.row-normalize`.

**Why this fixes the trap:**
1. `build_inst_mapping` no longer mints a TY-fresh handle for a ROW slot.
2. `ty_substitute` walking the TFun body never finds a TVar wrapping
   row_h, so no Ty-position substitution rewrites the row position.
3. The corrupt-pointer surface where a string fragment ends up in a
   Ty-pointer field disappears because the only way string fragments
   reached a Ty position was through the cross-category handle reuse.

**Drift-9 closure:** row generalization is named as peer cascade
`Hβ.infer.row-normalize` — that handle's plan extends `Forall` with
an explicit `row_quantifiers` field (drift-7-clean) and extends
`ty_substitute` to invoke `$row_substitute` on the row position.

### §5.2 If H-J confirmed (U.7 traps OR §2.4 wasm-objdump shows the
trap address resolves to a TParam.ty field that holds a string):
**audit and fix the field-swap site.**

Plan D.2 must localize the swap site by §2.4 wasm-objdump + a follow-up
phase U.8 grepping for every `$tparam_make` invocation and verifying
the second arg is always a Ty record (not a string pointer). The
residue is the swap-fix at the offending site.

### §5.3 If U.4 traps cleanly (TFun-vs-TInt productive-under-error fails):
**emit_diag.wat's `$infer_emit_type_mismatch` mishandles a TFun argument.**

The residue is in emit_diag.wat's `$render_ty` walker (TFun arm) — the
walker may attempt to render TFun's row position as a Ty (calling
`$render_ty` on the row handle integer cast as a Ty pointer).

### §5.0 Default (none of §5.1/5.2/5.3 fits): expand harness.

If §2.1 phases all PASS but real-source still traps, Plan D.2's residue
is to expand `unify_tag_bleed_diag.wat` with phases U.8–U.N narrowing
the bisection until ONE phase reproduces the trap. **No code residue
ships until a synthetic harness reproduces the trap** — drift mode 9
forbids fixing a trap whose substrate location isn't proven.

---

## §6 Composition with prior closures

- **Hβ.infer-bind-completeness (commit `73fc5f9` 2026-04-30):** Plan A
  closed Family A pre-register typedef + Family C lambda-param env-extend.
  The lambda-param fix (walk_expr.wat:758-781) is structurally correct.
  This walkthrough's trap is downstream — Plan A drove real-source AST
  to call/instantiate paths the harness diet (77 PASS) didn't exercise.
  **Plan A's closure stands;** this is its substrate-honesty audit at
  the next-deeper layer.

- **Hβ.infer cascade closure (commit `b6e1f23` 2026-04-27, 11/11 chunks):**
  All `unify_*` harnesses (4 in INDEX.tsv) PASS — but they tested in
  isolation with synthetic ASTs. The new harness (§2.1) tests
  **composition**: pre-register + instantiate + unify with cross-category
  handles. Cascade structurally complete; bind-completeness-PLUS-
  composition is the new gate.

- **Hβ.lower cascade closure (commit `c53904d` 2026-04-28):** unaffected.
  Lower walks LowExpr post-infer; if infer traps, lower never runs.

- **Hβ-arena-substrate (`d57e20c`):** the bump allocator at $heap_ptr
  is in-frame at the trap. The trap address is past the heap ceiling
  but well below the absolute 16 MiB allocator cap; not an arena
  exhaustion. Arena substrate stands.

---

## §7 Acceptance criteria

The Plan D.2 fix is gated on:

1. All 77 existing harnesses PASS post-fix (non-regression — drift-9 audit).
2. New `bootstrap/test/infer/unify_tag_bleed_diag.wat` PASS — all 7
   phases (U.1–U.7) green.
3. Real-source full-wheel probe:
   ```
   cat src/*.mn lib/**/*.mn | wasmtime run bootstrap/mentl.wasm > /tmp/inka2-postfix.wat 2> /tmp/inka2-postfix.err
   echo "exit: $?"
   grep "wasm trap" /tmp/inka2-postfix.err   # MUST be empty
   grep "out of bounds" /tmp/inka2-postfix.err   # MUST be empty
   ```
   Exit MUST be 0 OR a nonzero diagnostic-only output (productive-under-error
   surface only, no trap, no SIGABRT).
4. Real-source single-file probe:
   ```
   cat lib/runtime/strings.mn | wasmtime run bootstrap/mentl.wasm 2> /tmp/strings.err
   ```
   Exit MUST be 0 OR diagnostic-only (no trap).
5. `bash bootstrap/first-light.sh` Tier 1 PASS (non-regression).
6. `bash tools/drift-audit.sh
       bootstrap/src/infer/walk_stmt.wat
       bootstrap/src/infer/scheme.wat
       bootstrap/src/runtime/graph.wat
       bootstrap/test/infer/unify_tag_bleed_diag.wat
       bootstrap/test/INDEX.tsv` exits 0.

---

## §8 Surpass-or-don't-borrow

- **Borrowed:** algorithm-W instantiate-via-substitution.

- **Surpass — graph-IS-the-substitution:** `$instantiate` doesn't return
  `(Subst, Ty)` — it returns just Ty; the substitution lives in the
  graph as fresh NFree nodes the freshly-minted handles point at. No
  sidecar; no thread-through-monad.

- **Surpass — productive-under-error productive-PAST-the-chase:** Even
  on a corrupt pointer dereference, the residue ensures the productive-
  under-error pattern fires BEFORE chase reaches the corrupt position.
  The post-fix substrate guarantee is: **NO chase ever reads i32 from
  an out-of-bounds address**, because every binding's payload was
  type-shape-validated at construction time.

- **Surpass — NodeKind partition IS the type/row distinction:** ty
  handles and row handles share an integer namespace but partition by
  NodeKind tag. Mentl's NodeKind tag is the explicit partition, made
  structural via $is_nfree / $is_nrowfree.

- **Surpass — Reason-resident chase:** every chase step records the
  visited handles in trail mutations; if a chase ever does trap on a
  corrupt pointer, the Why Engine can replay the trail to localize the
  binding that wrote the corrupt payload.

- **Surpass — handler-swappable runtime sanity:** the residue is in
  pre_register_quantifier (or whichever §5 branch lights up). Swapping
  to a more-aggressive arena allocator or to a different generalization
  strategy changes neither the trap-immunity nor the diagnostic shape —
  the eight interrogations hold across allocator choice.

---

## §9 Four-axis pre-audit

1. **Eight interrogations answered:** §3 covers the two LEAD residue
   surfaces (H-A, H-J).

2. **SYNTAX.md alignment:** N/A — this walkthrough touches WAT-substrate
   only; no surface-syntax decisions.

3. **SUBSTRATE.md §I + §VII alignment:**
   - §I (Graph + Env): NodeKind tag IS the type/row partition.
   - §VII (Inference live): productive-under-error binds NErrorHole +
     continues. The residue restores the runtime-soundness invariant
     that every Ty record ever read must be structurally valid.

4. **Wheel canonical alignment:**
   - `src/infer.mn:1818-1834` (generalize): wheel quantifies free type
     handles only.
   - `src/infer.mn:1931-1998` (instantiate): row preserved verbatim.
   - `src/infer.mn:96-149` (pre_register_fn_sigs): wheel pre-registers
     fns + typedefs at toplevel pre-pass.

---

## §10 Riffle-back audit (mandatory per Anchor 7)

- **Hβ.infer-bind-completeness (`73fc5f9`):** Plan A landed Family A
  typedef pre-register + Family C lambda-param env-extend. Both ARE
  the deeper-env-reach the new harness diet (§2.1) tests.

- **Hβ.infer cascade (`b6e1f23`):** structurally complete; harness-
  coverage completeness is what THIS walkthrough adds.

- **Hβ-arena (`d57e20c`):** unaffected.

- **Convergence audit (Anchor 7 #4):** this is the **second** instance
  of "harness diet passed structurally; real-source exposed deeper
  composition surface." The first was Hβ.infer-bind-completeness's
  100-name `E_MissingVariable` count. **harness-coverage-by-shape ≠
  harness-coverage-by-composition**; every cascade closure must include
  at least one composition-level harness before claiming bind-completeness.

---

## §11 What Plan D.2 will edit

Plan D.2's separate dispatch will:

1. Author `bootstrap/test/infer/unify_tag_bleed_diag.wat` per §2.1
   (all 7 phases U.1–U.7). Run the harness; record outcomes.
2. Run §2.3 single-file bisection; record exit code and trap presence.
3. Run §2.4 wasm-objdump; localize the trap-address byte source.
4. Select §5 residue branch (§5.1, §5.2, or §5.3) per outcomes.
5. Apply the selected residue; re-run all 77 existing harnesses + the
   new harness; re-run real-source full-wheel probe.
6. Add a row to `bootstrap/test/INDEX.tsv` for `unify_tag_bleed_diag.wat`.
7. Drift-audit clean per §7 #6.
8. ROADMAP entry for Hβ-infer cascade amended:
   `closed (cascade + bind-completeness + unify-tag-bleed)`.

---

## §12 Named peer follow-ups

- **`Hβ.infer.row-normalize`** — substrate-honest row generalization +
  $row_substitute. The §5.1 residue removes row_h from the quantifier
  list as a tactical fix; row.wat's substrate eventually re-introduces
  row generalization via its OWN partition (Forall record gets a
  `row_quantifiers` field; instantiate dispatches via row.wat's
  substitution).

- **`Hβ.infer.per-callsite-generalize`** — every call site freshens
  via instantiate; per-call-site generalization is a different surface
  (lazy generalization).

- **`Hβ.infer.harness-composition-coverage`** — discipline crystallization:
  every cascade closure ships at least one composition harness (not
  just per-arm shape harness).

- **`Hβ.runtime-soundness-trail-replay`** — the Why Engine's first
  synthetic replay handle. Connect the trail to a "replay this trap"
  surface that lets diagnostic emit walk back from a corrupt-pointer
  trap to the originating $graph_bind.
