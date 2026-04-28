# Hβ.emit — LowIR → WAT-text emission at the bootstrap layer

> **Status:** `[DRAFT 2026-04-28]`. The next cascade after Hβ.lower
> closure (commit `c53904d`). Sub-walkthrough peer to
> `Hβ-bootstrap.md` (commit `95fdc3c`) +
> `Hβ-infer-substrate.md` (`b6e1f23` cascade closure) +
> `Hβ-lower-substrate.md` (`c53904d` cascade closure).
>
> **Authority:** `CLAUDE.md` Mentl's anchor + Anchor 0 (dream code)
> + Anchor 7 (cascade discipline); `docs/DESIGN.md` §0.5 (eight-
> primitive kernel; this walkthrough realizes primitive #2 (Handlers)
> emit-time projection — H1.4 single-handler-per-op naming +
> evidence reification at call_indirect — and primitive #3 (Verbs)
> WAT-shape emission); `docs/specs/05-lower.md` §Emitter handoff;
> `docs/specs/simulations/Hβ-lower-substrate.md` §2 (LowExpr ADT —
> tag region 300-334) + §9.2 (Hβ.lower × Hβ.emit composition);
> `src/backends/wasm.nx` (the wheel — 87 functions; this is the
> seed transcription target).
>
> *Claim in one sentence:* **The seed's Hβ.emit cascade extends the
> existing `bootstrap/src/emit_*.wat` chunks (~1728 lines, currently
> templating WAT directly from raw AST) to consume LowExpr trees
> (35 variants tag region 300-334 per lexpr.wat) — emit reads
> `$lexpr_handle + $tag_of` to dispatch, calls `$lookup_ty` (lower's
> chunk #2) for type info, threads handler-arm-as-LDeclareFn through
> module-level funcref table per H1.4 evidence reification, with NO
> `$op_table` data segment / NO vtable / NO `_lookup_handler_for_op`
> function — the closure record's `fn_index` FIELD + `call_indirect`
> at emit time IS the dispatch.**

---

## §0 Framing — what Hβ.emit resolves

### 0.1 What's missing post-Hβ.lower-closure

Per `Hβ-lower-substrate.md` §0.1 + the cascade-closure substrate-
honesty audit (commit `ba327c9`): the seed's existing emit chunks
template WAT directly from raw AST — they don't consume LowExpr.
Pipeline-wire (`$sys_main` retrofit) is gated on this AND on
bump-allocator-pressure substrate. After Hβ.emit cascade closes,
both gates lift and first-light-L1 unblocks.

The 35 LowExpr variants (lexpr.wat tag region 300-334) need their
emit arms. Some compose on existing emit chunks (LCall reuses
`$emit_call_expr` shape); some are net-new (LMakeContinuation per
H7; LFeedback per LF; LSuspend per H1.6).

### 0.2 What Hβ.emit composes on

| Substrate | Provides | Used by Hβ.emit for |
|---|---|---|
| Existing `bootstrap/src/emit_*.wat` (6 chunks, 1728 lines) | WAT-text generation primitives + module orchestration ($emit_program / $emit_fn / $emit_expr / $is_decl_stmt) | the WAT-text generation layer; extended (NOT replaced) per Anchor 4 wheel-parity |
| Hβ.lower closure | LowExpr trees (35 variants, tag 300-334); $lookup_ty for live type reads; classify_handler for strategy codes; $lower_handler_arms_as_decls for module-level handler arms | dispatching emission per LowExpr tag; reading types via $lookup_ty($lexpr_handle(r)); routing handler arms to module-level fns per H1.4 |
| **H7 substrate (already landed in src/*.nx)** | LMakeContinuation variant + emit arm + capture/ev-store helpers + LowerState effect at src/lower.nx:45-92 | the seed transcribes the SAME variant emit shape into bootstrap/src/emit_*.wat extensions so the seed's emit and the wheel's emit share LMakeContinuation runtime layout |
| **LF substrate (commit `7f8ff5f`)** | LFeedback emit shape at src/backends/wasm.nx | seed's emit uses the same LFeedback shape per spec 10 + LF walkthrough §1.12 |

### 0.3 What Hβ.emit designs (this walkthrough)

- **§1** — The emit-dispatcher shape: `$emit_lexpr` over LowExpr tag
  300-334 dispatch.
- **§2** — Per-variant emit arms, grouped:
  - §2.1 Const family (LConst / LMakeVariant / LMakeTuple / LMakeList /
    LMakeRecord)
  - §2.2 Local-scope family (LLocal / LGlobal / LUpval / LStore /
    LStateGet / LStateSet / LField)
  - §2.3 Control family (LIf / LBlock / LMatch / LSwitch / LLoop /
    LBreak / LReturn / LRegion)
  - §2.4 Call family (LCall / LTailCall / LBinOp / LUnaryOp / LSuspend
    / LIndex / LFieldLoad)
  - §2.5 Handler family (LHandleWith / LHandle / LPerform /
    LEvPerform / LMakeClosure / LMakeContinuation / LFeedback /
    LDeclareFn / LLet)
- **§3** — H1.4 single-handler-per-op naming + funcref-table layout.
- **§4** — Module orchestration: emit_program retrofit to take
  LowExpr program (the result of `$inka_lower(parsed_stmts)`).
- **§5** — Per-edit-site eight interrogations.
- **§6** — Forbidden patterns per edit site.
- **§7** — Chunk decomposition (~6-8 chunks).
- **§8** — Acceptance criteria.
- **§9** — Composition with Hβ.infer / Hβ.lower / pipeline-wire.
- **§10** — Open questions + named follow-ups.
- **§11** — Dispatch + sub-handle decomposition.
- **§12** — Closing.

### 0.4 What Hβ.emit does NOT design

- **Bump-allocator-pressure substrate.** The arena handler (B.5
  AM-arena-multishot) OR per-fn scoped-arena-reset is the SECOND gate
  on pipeline-wire. Hβ.emit's cascade closes the FIRST gate. The
  second is its own concern — likely a peer cascade or single
  substrate-growth commit.
- **Pipeline-wire `$sys_main` retrofit.** Trivial commit AFTER both
  gates lift. Per Hβ.infer.pipeline-wire follow-up.
- **`verify_smt` witness path.** First-light-L2 concern, post-L1.
- **Cross-module function symbol resolution.** Hβ.link's concern
  (Hβ-link-protocol.md follow-up TBD per Hβ §13).

### 0.5 Relationship to spec 05 + src/backends/wasm.nx

Spec 05 §Emitter handoff names the algorithm. `src/backends/wasm.nx`
(87 functions) is the wheel's emit implementation. This walkthrough
projects spec 05 + src/backends/wasm.nx onto the WAT substrate
(bootstrap/src/emit_*.wat extensions).

Per Anchor 4: src/backends/wasm.nx IS the wheel; this WAT IS its
seed transcription. The existing 1728 lines of emit code stay
canonical — extended, not replaced.

### 0.6 The deeper framing — emit IS one handler-on-graph

Per `docs/SUBSTRATE.md` §VIII "The Graph IS the Program" + Anchor 5
("if it needs to exist, it's a handler"): emit is **ONE handler**
in a family of graph-projection handlers. The same Graph + Env
populated by Hβ.infer + projected into LowExpr by Hβ.lower hosts
multiple peer-projections:

```
                   Graph + Env + LowExpr
                   (the universal representation)
                          │
          ┌───────┬───────┼───────┬───────┬───────┐
          │       │       │       │       │       │
       emit    format   doc    query   teach    LSP
       handler  handler handler handler handler handler
          │       │       │       │       │       │
        WAT    source  markdown  answer  hint   JSON-RPC
```

Hβ.emit's `$inka_emit` is the WAT-shadow. The cascade's
`$emit_lexpr` 35-arm dispatcher (§1) is the **template** every
sister-handler will reuse: `$format_lexpr` (Arc F.x — formatter as
graph→canonical-source handler), `$doc_lexpr` (Arc F.x — doc as
graph→markdown), `$lsp_lexpr` (Arc F.2 — LSP as graph→JSON-RPC),
`$mentl_lexpr` (Arc F.6 — Mentl as graph→mentorship per insight #11).
Each is a graph-shadow; the Graph IS the source of truth.

**This reframes the cascade discipline**: the 9 chunks below aren't
a one-off implementation — they're the **canonical shape** every
future graph-shadow handler inherits. The dispatcher's tag-300-334
arm structure, the `$lookup_ty` integration, the H1.4 funcref-table
substrate — all are reusable substrate. Arc F.2 (LSP) / Arc F.6
(Mentl) compose post-L1 without re-architecture; they are NOT new
features but new shadow-handlers reading the same graph.

The chunk #11's `$inka_emit` symbol is one of an eventual N peer
`$inka_<verb>` symbols. Per Hβ-bootstrap §1.15: pipeline-stage
boundaries name handler-projection sites. emit is one site; the
others compose later.

**Per SUBSTRATE.md §VIII**: every "output" is a handler. If it
can't be expressed as a handler on the graph, the graph is
incomplete. This walkthrough's discipline IS that anchor made
physical at the WAT layer.

---

## §1 The emit-dispatcher — `$emit_lexpr`

### 1.1 Top-level dispatch

```wat
;; Per Hβ-emit-substrate.md §1.1. Reads LowExpr's tag via $tag_of;
;; dispatches to per-variant emit arm. Arms emit WAT text to stdout
;; via $emit_string (existing emit_infra.wat helper).
(func $emit_lexpr (param $r i32)
  (local $tag i32)
  (local.set $tag (call $tag_of (local.get $r)))
  ;; LConst (300) — emit literal value
  (if (i32.eq (local.get $tag) (i32.const 300))
    (then (call $emit_lconst (local.get $r)) (return)))
  ;; LLocal (301) — emit local.get <slot>
  (if (i32.eq (local.get $tag) (i32.const 301))
    (then (call $emit_llocal (local.get $r)) (return)))
  ;; ... arms for all 35 variants ...
  ;; Unknown tag — compiler-internal bug.
  (unreachable))
```

### 1.2 The dispatcher composes existing emit infrastructure

The seed's `emit_infra.wat` already has:
- `$emit_string(s)` — write WAT text to stdout
- `$emit_int(n)` — write decimal integer
- `$emit_indent(n)` — indentation
- `$emit_module_open / _close` — module wrapper

Hβ.emit's per-variant arms call these primitives. NOT recreated.

---

## §2 Per-variant emit arms

### 2.1 Const family (LConst / LMakeVariant / LMakeTuple / LMakeList / LMakeRecord)

**`$emit_lconst(r)`** — LConst tag 300 (handle, value).
Per the LowValue opaque pass-through (chunk #6 walk_const Lock #4):
the value is currently passed as raw i32 from AST literal payload.
Emit reads value via `$lexpr_lconst_value(r)`, looks up the
handle's type via `$lookup_ty($lexpr_handle(r))`, and dispatches:
- TInt → emit `(i32.const N)`
- TString → emit a string literal + offset reference
- TBool → emit `(i32.const 0|1)`
- TUnit → emit `(i32.const 0)` (sentinel)
- TError-hole (tag 114) → emit `(unreachable)`

**`$emit_lmakevariant(r)`** — LMakeVariant tag 319. Per HB
substrate: nullary variants emit as direct sentinel tag value
(matches the Bool tag 0/1 discipline); variants with args emit
`$make_record(tag, arity)` + per-field `$record_set` calls.

**`$emit_lmaketuple(r)`** + **`$emit_lmakelist(r)`** + **`$emit_lmakerecord(r)`**
— record-shaped tuples/lists/records. Each emits `$make_record`
+ `$make_list` + element-wise stores. The wheel's
`emit_make_tuple_expr` / `emit_make_list_expr` shapes exist in
the seed's existing emit_compound.wat — extend to consume
LowExpr instead of raw AST.

### 2.2 Local-scope family

**`$emit_llocal(r)`** — `local.get $<slot>` per the slot index.
But Lock #1 from chunk #6 says LLocal carries (local_h, name)
NOT (handle, slot). Emit reads the name string from
`$lexpr_llocal_name(r)`; the slot mapping happens per-fn at the
LFn LowerCtx layer (the wheel's emit_fn body emits `(local $name i32)`
declarations + maps name → slot index for the fn's frame).

**`$emit_lglobal(r)`** — `global.get $<name>` per
`$lexpr_lglobal_name(r)`. Emit threads through the
existing `$emit_var_ref` shape per Anchor 4 wheel parity.

**`$emit_lupval(r)`** — closure upvalue access; `$cont_ptr` field
load per H1.6 evidence reification.

**`$emit_lstore(r)`** + **`$emit_lstateget(r)`** + **`$emit_lstateset(r)`**
— state-machine state access for Linear-strategy handlers per
chunk #5 classify discipline.

**`$emit_lfieldload(r)`** — `i32.load offset=<offset>` for record
field access. Offset comes from `$lexpr_lfieldload_offset_bytes(r)`.

### 2.3 Control family

**`$emit_lif(r)`** — `(if (then ...) (else ...))` per the wheel.

**`$emit_lblock(r)`** — sequential emit of stmts list. `$lexpr_lblock_stmts(r)`
returns the list; iterate + emit each LowExpr.

**`$emit_lmatch(r)` / `$emit_lswitch(r)`** — pattern dispatch per
tag-int comparison chain (no vtable; Drift 1 refusal). LSwitch is
the int-key form; LMatch is the structured form.

**`$emit_lloop(r)` + `$emit_lbreak(r)`** — `(block ...) (loop ...) (br_if ...)`
per WASM control flow.

**`$emit_lreturn(r)`** — `return` of the inner LowExpr's value.

**`$emit_lregion(r)`** — region scoping for arena / scoped state.
Currently inert seed; arena handler substrate (B.5) lands later.

### 2.4 Call family

**`$emit_lcall(r)`** — direct `call $<fn_name>` per spec 05 + H1
evidence reification. fn comes from `$lexpr_lcall_fn(r)`; args from
`$lexpr_lcall_args(r)` iterated + emitted as stack pushes.

**`$emit_ltailcall(r)`** — `return_call` per WASM tail-call proposal.

**`$emit_lbinop(r)`** — emit per BinOp tag (140-153 from
parser_infra.wat:26 — BAdd → `i32.add`, BSub → `i32.sub`, etc.).
Existing emit_expr.wat has the BinOp dispatch; extend to consume
LBinOp instead of BinOpExpr.

**`$emit_lunaryop(r)`** — UnaryOp dispatch.

**`$emit_lsuspend(r)`** — H1.6 polymorphic call. Reads
`$lexpr_lsuspend_op_h(r)` for the op handle + threads `evs` list
into closure record's evidence-slot fields. Emits
`call_indirect (table $funcref_table) (...args...) ($cont_ptr_or_fn_idx)`.
**THE LOAD-BEARING ARM** for Drift 1 refusal: fn_index is a FIELD
on the closure record; emit loads it + uses `call_indirect`. NO
`$op_table` data segment.

**`$emit_lindex(r)`** — list/string indexing per `$list_index` /
`$str_index_byte`.

### 2.5 Handler family

**`$emit_ldeclarefn(r)`** — module-level fn declaration. Per H1.4:
emits `(func $op_<op_name> (param ...) (result ...) ...body...)`
+ `(elem ... $op_<op_name>)` for funcref table registration. Reads
the LFn from `$lexpr_ldeclarefn_fn(r)` (LowFn ADT pending per
chunk #3 follow-up `Hβ.lower.lvalue-lowfn-lpat-substrate`).

**`$emit_lmakeclosure(r)`** — closure record allocation per H1
evidence reification: `(call $alloc <size>)` + per-field stores
(fn_index, captures, evs).

**`$emit_lmakecontinuation(r)`** — H7 substrate. Heap-captured
continuation per H7 §1.2: calls `$alloc_continuation(fn_index,
caps, evs, state_idx, ret_slot)`. Composes with cont.wat at runtime.

**`$emit_lfeedback(r)`** — LF substrate per spec 10 + LF
walkthrough §1.12. State-slot allocation in enclosing handler's
state record at emit time; load/tee/store sequence.

**`$emit_lhandlewith(r)`** + **`$emit_lhandle(r)`** — `~>` verb
emission. Body is the inner expr; handler is the LDeclareFn list
(or arm-records for inline handle blocks). Emit threads the
handler-install through funcref-table registration.

**`$emit_lperform(r)`** + **`$emit_levperform(r)`** — direct LPerform
emits `call $op_<name>` (H1.4 single-handler-per-op naming);
LEvPerform threads through evidence-slot dispatch (polymorphic
case).

**`$emit_llet(r)`** — local binding. Emits `(local.set $<name> ...)`
+ inner value. The wheel's existing emit_stmt.wat shape extends.

---

## §3 H1.4 single-handler-per-op naming + funcref-table

Per H1.4 + spec 05 §Handler elimination:
- Each handler arm becomes `(func $op_<op_name> ...)` at module level.
- `(table $funcref_table funcref)` entries register each by index.
- Polymorphic call sites use `call_indirect` with the funcref index
  read from the closure record's evidence slot.
- Monomorphic call sites use direct `call $op_<op_name>` per chunk
  #7's monomorphic gate.

**This IS the kernel's primitive #2 (Handlers) made physical at
the WAT layer.** No vtable; the funcref table IS the dispatch
substrate; the closure record's fn_index field IS the evidence.

---

## §4 Module orchestration — `$emit_program` retrofit

The existing `$emit_program(stmts)` (emit_module.wat:75) takes raw
AST stmts. Hβ.emit retrofits to ALSO accept LowExpr program (a list
of lowered LowExprs). The retrofit shape:

```wat
;; Original signature unchanged; new behavior: dispatch on input
;; first element's tag — if LowExpr (300-334), iterate emit_lexpr;
;; if AST N-stmt (tag 0), legacy AST-emit path. Two-mode operation
;; during the cascade transition; legacy path retires post-pipeline-wire.
(func $emit_program (param $stmts i32) ...)
```

Surface in §10: should the retrofit branch on tag-detection at
runtime, OR should `$emit_program` be replaced by a new
`$emit_lowir_program` that's called only after `$inka_lower`?
The latter is cleaner; `$emit_program` legacy path retires when
pipeline-wire lands.

---

## §5 Per-edit-site eight interrogations

Per CLAUDE.md / DESIGN.md §0.5. Each chunk's edit sites pass all
eight.

### 5.1 At the dispatcher (`$emit_lexpr`)

| # | Primitive | Answer |
|---|-----------|--------|
| 1 | **Graph?** | Each variant arm reads `$lookup_ty($lexpr_handle(r))` for type info — the live graph read. |
| 2 | **Handler?** | At wheel: `Emit` effect with WAT-text-output row. At seed: direct calls to emit_infra primitives. |
| 3 | **Verb?** | The 5 verbs become physical at the WAT layer per SUBSTRATE.md §II + SYNTAX.md "Pipe verbs" line 333. Each LowExpr tag resolves to one canonical WAT-shape: `\|>` (LCall tag 308) → direct `call $<fn>`; `<\|` (LMakeTuple of LCalls per Hβ.lower Lock #3) → record-build with per-branch calls; `><` (LMakeTuple pair) → 2-element record-build; `~>` (LHandleWith tag 329 / LHandle tag 332) → handler-install setup + body emission within installed-handler-row scope; `<~` (LFeedback tag 330 per LF) → state-slot load/tee/store sequence on enclosing handler's state record; LSuspend (tag 325, polymorphic call) → `call_indirect (table $funcref_table)` reading fn_index from closure record's evidence-slot field. The verbs ARE the runtime topology made physical at WAT. |
| 4 | **Row?** | Three row-read sites (per spec 01 + Hβ-lower §3.2): (1) **LSuspend emit** — read callee's TFun row via `$lookup_ty + $ty_tfun_row`; row's effect-name list sizes the evs allocation per H1.6. (2) **LHandleWith emit** — read handler's TCont row to determine which ops the handler-install intercepts; one funcref-table slot per intercepted op per H1.4. (3) **LDeclareFn emit** — read fn's effect signature for the WAT signature decoration (compile-time effects don't appear in WAT but DO determine the per-arm fn naming `$op_<name>` per H1.4 + H7 §1.2). |
| 5 | **Ownership?** | Emit produces WAT text (output bytes); consumes LowExpr `ref`. No allocation of new LowExprs. |
| 6 | **Refinement?** | TRefined transparent — emit reads the underlying type via `$lookup_ty`. Refinement obligations in verify ledger surface as `verify_smt` calls post-L2. |
| 7 | **Gradient?** | Each LCall vs LSuspend choice CASHES OUT here — direct `call` vs `call_indirect`. The row inference's >95% monomorphic claim IS the gradient. |
| 8 | **Reason?** | LOCKED per SUBSTRATE.md §VIII "The Graph IS the Program": Reasons are read-only via the graph by **sister-handlers** (Mentl-Why per Arc F.6, doc-handler, error-handler) WITHOUT going through emit's WAT text. Emit IS one shadow per §0.6 framing; reason-annotation in WAT would be decoration, NOT load-bearing — sister-handlers compose on the same Reason chain via `$gnode_reason($graph_chase($lexpr_handle(r)))`. V1 emit produces unannotated WAT; the Why-Engine surface remains graph-side. Named follow-up `Hβ.emit.reason-annotation` covers OPTIONAL debug-name section enrichment for `wabt`-readable trace; it is purely additive (decoration), never load-bearing for Mentl's projection. |

### 5.2 At handler-arm emission (LDeclareFn + LMakeContinuation)

| # | Primitive | Answer |
|---|-----------|--------|
| 1 | **Graph?** | Read fn type via `$lookup_ty(handle)`; param/return types determine WAT signature. |
| 2 | **Handler?** | THIS IS THE HANDLER PROJECTION. Each arm becomes a module-level fn; funcref table registers it. |
| 3 | **Verb?** | `~>` desugaring's runtime — handler-install sets up the funcref-slot bindings. |
| 4 | **Row?** | Handler row = effect ops it intercepts; each op gets its `$op_<name>` fn. |
| 5 | **Ownership?** | Continuation records `own` per H7; closure records `own` per H1 reification. |
| 6 | **Refinement?** | N/A — refinements at expression level. |
| 7 | **Gradient?** | TailResumptive (chunk #5 strategy 0) → direct call zero-indirection; Linear (1) → state machine; MultiShot (2) → continuation alloc. |
| 8 | **Reason?** | Handler-uninstallable diagnostics surface from emit's verify pass; reads GNode's Reason chain. |

---

## §6 Forbidden patterns per edit site

- **Drift 1 (Rust vtable) — CRITICAL.** Per Hβ-lower §6.2 + every
  Hβ.lower chunk audit. Closure record's fn_index FIELD + funcref
  table + `call_indirect`. NO `$op_table` data segment / NO
  `_lookup_handler_for_op` function / NO `dispatch_table` comment.
  Word "vtable" appears NOWHERE except in audit blocks.
- **Drift 5 (C calling convention).** Per H7 §1.2: ONE `$cont_ptr`
  parameter on resume_fn. NOT separate `$closure + $ev + $ret_slot`.
- **Drift 8 (string-keyed).** Tag-int dispatch over LowExpr tags
  300-334. NEVER `if str_eq(variant_name, "LCall")`. The op-name
  in LPerform IS a string but it's THREADED to fn_name `$op_<name>`,
  never STRUCTURALLY COMPARED.
- **Drift 9 (deferred-by-omission).** Every variant arm bodied OR
  named follow-up. No silent stubs.
- **Foreign fluency — LLVM/GHC IR.** Vocabulary stays Inka. NEVER
  "calling convention enum" / "core IR" / "SSA value". The substrate
  is LowExpr / WAT / Inka-native.

---

## §7 Substrate touch sites — chunk decomposition

### 7.1 Proposed file layout

The existing `bootstrap/src/emit_*.wat` chunks stay; new chunks
under `bootstrap/src/emit/` mirror Hβ.lower's layout. Decision:
**create `bootstrap/src/emit/` directory** for the LowExpr-consuming
emit chunks; legacy emit_*.wat stays for the AST-emit path until
pipeline-wire retires it.

```
bootstrap/src/emit/
  INDEX.tsv              ;; dep graph
  state.wat              ;; emit-time state (output buffer, current fn name,
                         ;;   funcref table accumulator, slot-to-name map)
  lookup.wat             ;; $emit_ty (Ty → WAT type) + $emit_value
                         ;;   (LowValue → WAT literal) + $emit_op_name
                         ;;   (op_name → "op_<name>" symbol per H1.4)
  emit_const.wat         ;; LConst / LMakeVariant / LMakeTuple / LMakeList /
                         ;;   LMakeRecord per §2.1
  emit_local.wat         ;; LLocal / LGlobal / LUpval / LStore / LStateGet /
                         ;;   LStateSet / LFieldLoad per §2.2
  emit_control.wat       ;; LIf / LBlock / LMatch / LSwitch / LLoop / LBreak /
                         ;;   LReturn / LRegion per §2.3
  emit_call.wat          ;; LCall / LTailCall / LBinOp / LUnaryOp / LSuspend /
                         ;;   LIndex per §2.4 — THE GRADIENT CASH-OUT SITE
  emit_handler.wat       ;; LHandleWith / LHandle / LPerform / LEvPerform /
                         ;;   LMakeClosure / LMakeContinuation / LFeedback /
                         ;;   LDeclareFn / LLet per §2.5
  emit_dispatcher.wat    ;; $emit_lexpr 35-arm dispatch
  main.wat               ;; $emit_lowir_program orchestrator + $inka_emit
                         ;;   pipeline-stage boundary
```

**~9 chunks** total. ~3000-4500 lines projected (similar scope to
Hβ.lower per the 1.2× cascade-discipline factor).

### 7.2 Layer extension

Layer 6 (existing Emitter) becomes Layer 7 conceptually; new Layer
6 (Hβ.emit LowExpr-consuming substrate) lands BEFORE the existing
emit chunks. Or — single Layer 6 with new chunks alongside legacy.
Decide in plan §10.

---

## §8 Acceptance criteria

### 8.1 Type-level acceptance (Hβ.emit substrate lands)

- [ ] `bootstrap/src/emit/` directory exists with 9 chunks per §7.1.
- [ ] `bootstrap/src/emit/INDEX.tsv` declares each chunk.
- [ ] `bootstrap/build.sh` CHUNKS[] includes emit chunks.
- [ ] `wat2wasm bootstrap/inka.wat` succeeds.
- [ ] `wasm-validate bootstrap/inka.wasm` passes.
- [ ] `wasm-objdump -x` lists `$emit_lexpr`, `$inka_emit`, all 35
      `$emit_l<variant>` arms (at minimum).

### 8.2 Functional acceptance (per-program tests)

- [ ] Emitting a known LConst (LowExpr from chunk #6 walk_const trace
      harness fixtures) produces the expected WAT text.
- [ ] Emitting a LCall site emits `call $<fn>`.
- [ ] Emitting an LSuspend site emits `call_indirect` with funcref
      index from closure record's evidence slot.
- [ ] Emitting an LDeclareFn produces `(func $op_<name> ...)` +
      funcref table entry.

### 8.3 Self-compile acceptance (Hβ.emit unblocks pipeline-wire)

- [ ] Pipeline-wire commit retrofits `$sys_main` to chain
      `$inka_infer + $inka_lower + $inka_emit`.
- [ ] `cat src/runtime/alloc.nx | wasmtime run bootstrap/inka.wasm`
      produces VALID WAT (not a trap, not garbage).
- [ ] `cat src/types.nx | wasmtime run bootstrap/inka.wasm` produces
      validating WAT.

### 8.4 Drift-clean

- [ ] `bash tools/drift-audit.sh bootstrap/src/emit/*.wat` exits 0.

---

## §9 Composition with sibling cascades

### 9.1 Hβ.emit × Hβ.lower

Hβ.lower's `$inka_lower` produces a list of LowExprs (the lowered
program). Hβ.emit's `$inka_emit` consumes that list and emits WAT
text. Clean handoff: lower mutates graph + builds LowExpr; emit
reads LowExpr + reads graph via `$lookup_ty`; both compose on the
populated graph from Hβ.infer.

### 9.2 Hβ.emit × Hβ.infer

Indirect — emit doesn't touch infer's substrate directly. Type
reads route through `$lookup_ty` (lower's chunk #2) which is
`$graph_chase` (graph.wat). The graph IS the shared state per
DESIGN.md §0.5.

### 9.3 Hβ.emit × pipeline-wire

After emit cascade closes, pipeline-wire `$sys_main` retrofit
becomes:
```
stdin |> read_all_stdin |> lex |> parse_program
      |> $inka_infer    ;; mutates graph
      |> $inka_lower    ;; produces LowExpr list
      |> $inka_emit     ;; emits WAT text
      |> proc_exit
```

The bump-allocator-pressure substrate gate STILL stands —
real-input AST traversal blew the bump allocator at infer time
(commit `ba327c9`). Pipeline-wire needs BOTH gates lifted:
emit-extension (this cascade) + bump-allocator substrate (separate).

### 9.4 Hβ.emit × Hβ.link

Cross-module fn symbol resolution stays `Hβ.link`'s concern. Emit
emits module-local references; link resolves at assembly time per
`Hβ-link-protocol.md` follow-up.

---

## §10 Open questions + named follow-ups

| Question | Resolution |
|----------|-----------|
| `$emit_program` retrofit branch on input tag, OR new `$inka_emit` symbol? | LOCKED 2026-04-28: new `$inka_emit` symbol. `$emit_program` legacy path retires post-pipeline-wire per Hβ-bootstrap §1.15 `$inka_<verb>` convention. Two-mode emit during cascade; clean cut at pipeline-wire commit. |
| Layer 6 placement — before legacy emit OR alongside? | LOCKED: alongside. Both layers compile to same module; legacy unused once pipeline-wire flips to LowExpr path. |
| LowValue ADT structuring — LInt / LFloat / LString wrappers? | DEFERRED to `Hβ.lower.lvalue-lowfn-lpat-substrate` follow-up (chunk #3 lexpr.wat:160). Currently LowValue is opaque i32 pass-through; emit reads via `$lookup_ty` for type-driven dispatch. |
| LFn ADT shape for LDeclareFn? | DEFERRED to same follow-up. Emit currently treats LDeclareFn's field 0 as opaque LowFn ptr; structural access surfaces when LFn lands. |

### Named follow-ups (Hβ.emit-introduced)

- **Hβ.emit.evidence-slot-naming** — full `op_<name>_idx` naming
  convention per H1.4; ties chunk #7's `$derive_ev_slots` Lock #7
  closure (currently empty list) to emit's funcref-table layout.
- **Hβ.emit.continuation-runtime-bridge** — LMakeContinuation emit
  composes with cont.wat at runtime; bump-allocator pressure
  substrate likely surfaces here.
- **Hβ.emit.match-pattern-compile** — LMatch arms' pattern compile
  to tag-int dispatch chain (Drift 1 refusal); chunk #9's
  `Hβ.lower.match-arm-pattern-substrate` follow-up converges here.
- **Hβ.emit.refinement-witness** — TRefined emit at first-light-L2;
  `verify_smt` substrate composition.
- **Hβ.emit.cross-module** — Hβ.link composition for cross-module
  symbol references.

---

## §11 Dispatch + sub-handle decomposition

### 11.1 Authoring

This walkthrough: Opus inline (this commit).

### 11.2 Substrate transcription

Per Hβ §8 dispatch: bootstrap work needs Opus-level judgment + WAT
fluency + per-handle walkthrough reading.

**Per-chunk dispatch:**

| Chunk | Dispatch | Rationale |
|-------|----------|-----------|
| state.wat | Opus inline OR Sonnet | small; mechanical |
| lookup.wat | Opus inline | type-driven dispatch; load-bearing for LConst/LCall |
| emit_const.wat | Opus inline OR Sonnet | per-variant arms; mostly mechanical |
| emit_local.wat | Sonnet | mechanical record-field reads |
| emit_control.wat | Opus inline | LMatch/LSwitch pattern compile is subtle |
| emit_call.wat | **Opus inline only** | LSuspend's H1.6 evidence dispatch is the gradient cash-out site |
| emit_handler.wat | **Opus inline only** | LMakeContinuation + LDeclareFn + funcref table is H7 + H1.4 substrate composition |
| emit_dispatcher.wat | Opus inline OR Sonnet | 35-arm if-chain; mechanical |
| main.wat | Opus inline OR Sonnet | orchestrator |

### 11.3 Sub-handle dependency order

1. **state.wat** (deps: alloc, list, record, output buffer)
2. **lookup.wat** (deps: state, lower/lookup, lower/lexpr, infer/ty)
3. **emit_const.wat** (deps: lookup, lower/lexpr)
4. **emit_local.wat** (deps: lookup, lower/lexpr, lower/state)
5. **emit_control.wat** (deps: lookup, lower/lexpr, emit_dispatcher
   forward-decl)
6. **emit_call.wat** (deps: lookup, lower/lexpr, lower/classify,
   emit_handler forward-decl for funcref-table)
7. **emit_handler.wat** (deps: emit_call, runtime/cont, runtime/closure)
8. **emit_dispatcher.wat** (deps: all per-variant chunks)
9. **main.wat** (deps: emit_dispatcher; names `$inka_emit`)

### 11.4 Per-handle landing discipline

Each chunk lands per Anchor 7 + Hβ.lower cascade precedent:
- Walkthrough cite (this file's §) in chunk header.
- Eight interrogations clear (per §5).
- Forbidden patterns audited (per §6).
- Drift-audit clean.
- Per-chunk trace harness.
- Wheel canonical cited at file:line for each design decision.
- Walkthrough-vs-wheel divergences captured as Locks per chunk.

---

## §12 Closing

Hβ.emit is the cascade that converts LowExpr trees to WAT text.
Per spec 05 + src/backends/wasm.nx: extend the existing 1728 lines
of emit substrate to consume LowExpr (35 variants tag region 300-334)
instead of templating WAT directly from raw AST.

**This cascade unlocks first-light-L1.** After Hβ.emit closes:
- `Hβ.lower.emit-extension` follow-up closes
- `Hβ.infer.pipeline-wire` second gate (bump-allocator-pressure
  substrate) becomes the next block
- Self-compile fixed point becomes reachable

**Nine chunks. Five per-variant families. One funcref-table
substrate.** The emit layer of the seed, named in writing, ready
to transcribe.

Combined with Hβ.infer + Hβ.lower (commits `b6e1f23` + `c53904d`),
the FULL CONTRACT for the seed's bootstrap pipeline is now locked.
The form is right. The path is named. The next residue is per-chunk
WAT transcription.

Sibling walkthroughs to write next (per Hβ §13 named follow-ups):
- `Hβ-link-protocol.md` — bootstrap/src/link.py linker per BT §3
  (~200 lines link.py)
- `Hβ-arena-substrate.md` — bump-allocator-pressure resolution
  (B.5 AM-arena-multishot OR per-fn scoped-arena-reset)

*Per Mentl's anchor: write only the residue. The walkthroughs already
say what the medium IS. This walkthrough is the residue between
Hβ-lower-substrate.md's LowExpr output + spec 05's emit-algorithm +
src/backends/wasm.nx's wheel canonical + the existing emit_*.wat
substrate. The next residue is per-chunk WAT transcription;
transcribers cite this walkthrough's §s.*

---

**Hβ.infer + Hβ.lower + Hβ.emit together = the seed's full classical
compiler pipeline, projected onto the kernel's eight primitives.**
After this cascade closes, the seed compiles itself (first-light-L1).
After first-light-L2 (verify_smt), the refinement layer becomes
physical. After Mentl substrate composition, the speculative-inference
oracle reads the gradient surface this cascade just made physical.
After `inka edit` web playground lands, Mentl's V1 surface is the
medium becoming itself.

The form is right. The path is named. The next residue awaits
transcription.
