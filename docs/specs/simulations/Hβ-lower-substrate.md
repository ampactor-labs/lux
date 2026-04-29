# Hβ.lower — LowIR construction + handler elimination at the WAT layer

> **Status:** `[CASCADE CLOSED 2026-04-28]`. 11/11 chunks structurally
> live under `bootstrap/src/lower/`; `$inka_lower` pipeline-stage
> boundary named at commit `c53904d`. With Hβ.infer (commit `b6e1f23`)
> the full kernel-projected compiler pipeline is live in the seed.
> 59/59 trace-harnesses PASS; first-light Tier 1 LIVE non-regression;
> drift-audit clean. Closure crystallization at memory file
> `protocol_hbeta_lower_closure.md`. Pipeline-wire (`$sys_main`
> retrofit) GATED on TWO substrate growths per ba327c9 audit:
> Hβ.lower.emit-extension + Hβ.infer bump-allocator-pressure substrate.
>
> Prior audit history: `[DRAFT 2026-04-25; riffle-back-audited 2026-04-27]`.
> 2026-04-27 audit applied 6 mechanical fixes against landed Hβ.infer
> substrate (commit `b6e1f23`, 11/11 chunks live): MULTISHOT 221→251
> (§4.2), `$ast_handle` → `$walk_expr_node_handle` (§4.1+§4.2),
> `$program_stmts` removed (§4.3), `$ty_make_terror_hole` ownership
> + tag pinned (§11), lower-vs-infer diagnostic boundary pinned
> (§11), line estimates revised (§7.4 + §13). Audit residue at
> `/tmp/inka-plans/Hβ-lower-audit-2026-04-27.md`. Walkthrough is now
> transcription-ready per §12.3 dep order.
>
> Sub-walkthrough peer to
> `Hβ-bootstrap.md` (commit `95fdc3c`) + `Hβ-infer-substrate.md`
> (commit `729ee59`). Names the design contract for the seed's
> LowIR construction layer + handler elimination dispatch, projected
> onto the Wave 2.A–D Layer-1 substrate + Hβ.infer's typed-AST +
> populated-graph output.
>
> **Authority:** `CLAUDE.md` Mentl's anchor + Anchor 0 (dream code) +
> Anchor 7 (cascade discipline); `docs/DESIGN.md` §0.5 (eight-
> primitive kernel; this walkthrough realizes primitive #2 dispatch +
> primitive #3 verb lowering); `docs/specs/05-lower.md` (the
> canonical algorithm contract); `docs/specs/00-graph.md` (graph
> substrate read live via $graph_chase); `docs/specs/01-effrow.md`
> (row substrate for $row_is_ground monomorphism gate);
> `docs/specs/10-pipes.md` (five-verb lowering shapes);
> `docs/specs/simulations/Hβ-bootstrap.md` §1.3 + §1.4 + §1.13 +
> §13 (parent walkthrough; Layer 4 sub-handle);
> `docs/specs/simulations/Hβ-infer-substrate.md` (sibling — produces
> the typed AST + graph state Hβ.lower reads);
> `docs/specs/simulations/H7-multishot-runtime.md` (LMakeContinuation
> emit substrate already in src/lower.nx + src/backends/wasm.nx);
> `docs/specs/simulations/LF-feedback-lowering.md` (LFeedback emit
> per <~ verb, landed `7f8ff5f`); `src/lower.nx` (1284 lines, the
> wheel — this WAT IS its seed transcription).
>
> *Claim in one sentence:* **The seed's lowering walks the typed AST
> + reads types LIVE via `$graph_chase`, classifies each handler
> body via `classify_handler` reading `TCont.discipline` from
> graph, picks direct-call / state-machine / heap-captured-
> continuation per the discipline, lowers each AST node to a peer
> LowExpr + writes a flat list of LowStmts the emitter consumes;
> no subst threading; no cached types in LowExpr; per spec 05:
> "the LookupTy handler IS the check, every emit that passes
> through lookup_ty is validated in the same step."**

---

## §0 Framing — what Hβ.lower resolves

### 0.1 What's missing from the current seed

Per `Hβ-bootstrap.md` §11 + BT.A.0 sweep + Hβ-infer-substrate.md §0.1:
the current seed does **lex → parse → direct-emit** with no inference
or lowering pass. The seed's parser hands AST nodes to emit chunks
(emit_*.wat) which template WAT directly from AST shape — losing
type information, losing handler-chain info, producing degenerate
output for graph.nx + 34 other src/*.nx files.

Hβ.infer (sibling walkthrough) lands the inference layer. **Hβ.lower
lands the lowering layer that bridges inferred types → WAT-shaped
LowIR the emit chunks consume.** Without this layer, Hβ.infer's
output has no consumer; emit chunks can't see types or handler
choices.

### 0.2 What Hβ.lower composes on

| Substrate | Provides | Used by Hβ.lower for |
|-----------|----------|----------------------|
| Wave 2.A–D Layer 1 | alloc / str / int / list / record / closure / cont / graph / env / row / verify | every heap allocation; reading types via $graph_chase; row classification via $row_is_pure/closed/open; LMakeContinuation field layout via cont.wat |
| Hβ.infer | typed AST + populated graph (every node's handle in NBound or NErrorHole) | $graph_chase + $env_lookup return ground answers |
| **H7 substrate (already landed in src/*.nx)** | LMakeContinuation variant + emit arm + capture/ev-store helpers + LowerState effect at src/lower.nx:45-92 | the seed transcribes the SAME variant into bootstrap/src/lower/cont.wat (sub-chunk) so the seed's lowering and the wheel's lowering share LMakeContinuation shape |
| **LF substrate (landed `7f8ff5f`)** | LFeedback state-machine lowering at src/backends/wasm.nx | seed's lowering uses the same LFeedback shape per spec 10 + LF walkthrough |

### 0.3 What Hβ.lower designs (this walkthrough)

- **§1** — LookupTy + LowerCtx as direct functions in the seed
  (handler-shape is the wheel's compiled form; seed uses module-level
  globals + direct call dispatch).
- **§2** — LowExpr ADT shape at the WAT layer — tag conventions
  shared with Hβ.emit (the emit chunks are downstream consumers).
- **§3** — Handler elimination: `$classify_handler` + the
  monomorphic-vs-polymorphic gate via $graph_chase + $row_is_ground.
- **§4** — The lowering walk: `$lower_expr` + `$lower_stmt` arms
  per typed AST shape.
- **§5** — Per-edit-site eight interrogations.
- **§6** — Forbidden patterns per edit site.
- **§7** — Substrate touch sites — chunk decomposition with
  literal-token guidance per chunk.
- **§8** — Worked example — lowering `fn double(x) = x + x` to LowIR.
- **§9** — Composition with Hβ.infer / Hβ.emit / cont.wat (H7) /
  LFeedback / Synth chain.
- **§10** — Acceptance criteria.
- **§11** — Open questions + named follow-ups.
- **§12** — Dispatch + sub-handle decomposition.
- **§13** — Closing.

### 0.4 What Hβ.lower does NOT design

- **WAT text emission.** Hβ.emit (existing emit_*.wat — to be
  extended per Hβ.emit-substrate.md if needed). Lower produces
  LowIR; emit consumes LowIR + writes WAT text.
- **Handler runtime allocation strategy.** B.5 AM-arena-multishot
  arena handlers (`replay_safe` / `fork_deny` / `fork_copy`)
  intercept `emit_alloc` at the wheel's handler-install time;
  Hβ.lower in the seed uses the default bump allocator from
  alloc.wat. Arena handlers ship as wheel substrate post-L1.
- **The Synth chain.** Hβ.lower handles MultiShot ops via
  $alloc_continuation + state-machine emit; the actual Synth
  handler implementations (enumerative_synth / smt_synth /
  llm_synth) ship as user-level handlers post-H7 / post-L1.
- **Cross-module function symbol resolution.** BT.A.2 Hβ.link
  (link.py per Hβ §2.3 + BT walkthrough) handles cross-module
  rename. Hβ.lower emits LowIR with module-local references;
  link.py renames at assembly time.

### 0.5 Relationship to spec 05 + src/lower.nx + H7 + LF

Spec 05 names the algorithm. `src/lower.nx` (1284 lines) is the
wheel's lowering implementation in Inka — already extended per H7
(LMakeContinuation variant + lower_perform MS dispatch + LowerState
effect) + per LF (LFeedback emit completion). This walkthrough
projects spec 05 + src/lower.nx onto the WAT substrate.

Per Anchor 4: src/lower.nx IS the wheel; this WAT IS its seed
transcription. Per H7 §6: H7's substrate already composes on
graph.wat / cont.wat / closure.wat — Hβ.lower's seed transcription
uses the same. Per LF: <~ feedback verb lowers to state-slot
load/store on enclosing handler state.

---

## §1 LookupTy + LowerCtx — the lowering primitives

Per spec 05 §The LookupTy effect: `lookup_ty(handle) -> Ty` reads
types live from the graph. In the wheel this is an effect handler
(`lookup_ty_graph`); in the seed it's a direct function calling
$graph_chase.

### 1.1 `$lookup_ty(handle) -> i32` (Ty pointer)

```wat
;; Per spec 05 §The LookupTy effect default handler `lookup_ty_graph`.
;; Seed's projection: direct function. Reads via $graph_chase; returns
;; the resolved Ty pointer for NBound; sentinel for NErrorHole; halts
;; build for NFree (compiler-internal bug per spec 05 invariant 2).
(func $lookup_ty (param $handle i32) (result i32)
  (local $g i32) (local $nk i32) (local $tag i32)
  (local.set $g (call $graph_chase (local.get $handle)))
  (local.set $nk (call $gnode_kind (local.get $g)))
  (local.set $tag (call $node_kind_tag (local.get $nk)))
  ;; NBound — return the bound Ty pointer.
  (if (i32.eq (local.get $tag) (i32.const 60))      ;; NBOUND
    (then (return (call $node_kind_payload (local.get $nk)))))
  ;; NErrorHole — return $ty_make_terror_hole sentinel (lookup.wat-private,
  ;; tag 114; lookup-time-only; the type system never produces it — NErrorHole
  ;; lives at the GNode layer, not the Ty layer; this sentinel is the bridge
  ;; into Hβ.lower's ERROR_HOLE → (unreachable) emit path per §11 audit
  ;; resolution 2026-04-27).
  (if (i32.eq (local.get $tag) (i32.const 64))      ;; NERRORHOLE
    (then (return (call $ty_make_terror_hole))))
  ;; NFree — compiler-internal bug per spec 05 invariant 2.
  ;; Emit E_UnresolvedType + halt build (the seed itself emits to
  ;; stderr + exits non-zero; full diagnostic threading per Hβ.emit).
  (if (i32.eq (local.get $tag) (i32.const 61))      ;; NFREE
    (then
      (call $lower_emit_unresolved_type (local.get $handle))
      (call $wasi_proc_exit (i32.const 1))))
  ;; NRowFree / NRowBound — should never reach $lookup_ty (rows are
  ;; queried via $lookup_row_for or $row_for_handle). Trap.
  (unreachable))
```

### 1.2 LowerCtx — slot assignments + closure upvalue indices

Per spec 05 §No subst threading: the only context lowering needs
is local-slot assignments + closure upvalue indices. Per spec 06
LowerCtx effect; in the seed, module-level globals + direct
helpers.

```wat
;; ─── LowerCtx state — per-function locals/captures table ─────────
;; $lower_locals_ptr: flat list of (name_str, slot_idx, ty_handle)
;;                    triples for the CURRENT function being lowered.
(global $lower_locals_ptr     (mut i32) (i32.const 0))
(global $lower_locals_len_g   (mut i32) (i32.const 0))
(global $lower_next_slot_g    (mut i32) (i32.const 0))

;; $lower_captures_ptr: flat list of (upvalue_name, src_slot_idx)
;;                      pairs — captures from enclosing fn's locals
;;                      that THIS fn's closure must hold.
(global $lower_captures_ptr   (mut i32) (i32.const 0))
(global $lower_captures_len_g (mut i32) (i32.const 0))

;; $lower_initialized — idempotent init flag.
(global $lower_initialized    (mut i32) (i32.const 0))
```

Helpers per spec 05 + src/lower.nx ls_bind_local / ls_lookup_local /
ls_bind_capture:

```wat
(func $ls_bind_local (param $name i32) (param $ty_handle i32) (result i32)
  ;; Returns the assigned slot index. Appends to $lower_locals_ptr;
  ;; bumps $lower_next_slot_g.
  ...)

(func $ls_lookup_local (param $name i32) (result i32)
  ;; Returns slot_idx if name is a local; -1 if not (capture or unknown).
  ...)

(func $ls_lookup_or_capture (param $name i32) (result i32)
  ;; Returns slot_idx if local; if not local but resolvable via
  ;; outer-scope walk (env.wat), records as capture + returns the
  ;; capture's index in $lower_captures_ptr.
  ...)

(func $ls_reset_function ()
  ;; Clears locals + captures + resets next_slot. Called at FnStmt
  ;; entry per src/lower.nx ms_reset_function precedent (LowerState
  ;; effect's reset op).
  ...)
```

LowerState (the H7 substrate at src/lower.nx:45-92) is already
declared in graph.wat's tag region; the seed transcribes its
behavior here as direct calls.

---

## §2 LowExpr — ADT shape at the WAT layer

Per spec 05 + src/lower.nx LowExpr ADT (already extended per H7
+ LF):

```
LConst(handle, value)               tag=300  arity=2
LLocal(handle, name)                tag=301  arity=2
LGlobal(handle, name)               tag=302  arity=2
LStore(handle, slot, value)         tag=303  arity=3
LLet(handle, name, value)           tag=304  arity=3
LUpval(handle, slot)                tag=305  arity=2
LBinOp(handle, op, l, r)            tag=306  arity=4
LUnaryOp(handle, op, x)             tag=307  arity=3
LCall(handle, fn, args)             tag=308  arity=3
LTailCall(handle, fn, args)         tag=309  arity=3
LReturn(handle, x)                  tag=310  arity=2
LMakeClosure(handle, fn, caps, evs) tag=311  arity=4   (H1 evidence reification)
LMakeContinuation(handle, fn,
  caps, evs, state_idx, ret_slot)   tag=312  arity=6   (H7 multi-shot)
LDeclareFn(fn)                      tag=313  arity=1
LIf(handle, cond, then, else)       tag=314  arity=4
LBlock(handle, stmts)               tag=315  arity=2
LMakeList(handle, elems)            tag=316  arity=2
LMakeTuple(handle, elems)           tag=317  arity=2
LMakeRecord(handle, fields)         tag=318  arity=2
LMakeVariant(handle, tag_id, args)  tag=319  arity=3
LIndex(handle, base, idx, is_str)   tag=320  arity=4
LMatch(handle, scrut, arms)         tag=321  arity=3
LSuspend(handle, op, fn, args, evs) tag=325  arity=5
LStateGet(handle, slot)             tag=326  arity=2
LStateSet(handle, slot, value)      tag=327  arity=3
LRegion(handle, body)               tag=328  arity=2
LHandleWith(handle, body, handler)  tag=329  arity=3   (~> verb desugaring)
LFeedback(handle, body, spec)       tag=330  arity=3   (<~ verb; LF substrate)
LPerform(handle, op_name, args)     tag=331  arity=3
LHandle(handle, body, arms)         tag=332  arity=3
LEvPerform(handle, op_name,
  slot_idx, args)                   tag=333  arity=4
LFieldLoad(handle, record, offset)  tag=334  arity=3
```

Tag region 300-349 reserved for Hβ.lower's LowExpr private records.

Constructors + accessors per the standard $make_record / $record_get
shape from record.wat. Each LowExpr variant gets a constructor
$lexpr_make_<variant> + accessors.

`$lexpr_handle(lexpr)` returns the source handle (field 0 in every
variant; uniform extraction):

```wat
(func $lexpr_handle (param $lexpr i32) (result i32)
  (call $record_get (local.get $lexpr) (i32.const 0)))
```

`$lexpr_ty(lexpr) = $lookup_ty($lexpr_handle(lexpr))` per spec 05
§LowIR — live query, no cached field. Per spec 05 forbidden:
"`_ => TUnit` wildcard fallback in `lexpr_ty`"; `$lexpr_ty`
delegates to $lookup_ty which dispatches via $graph_chase.

---

## §3 Handler elimination

Per spec 05 §Handler elimination + src/lower.nx classify_handler.
Three strategies:

| Strategy | When | Lowering |
|----------|------|----------|
| **TailResumptive** | Handler arm calls `resume(v)` exactly once in tail position; OneShot-typed | Direct `(call $h_op ...)` — zero indirection per H1 evidence reification |
| **Linear** | Handler arm calls `resume` exactly once but not in tail position (e.g., wraps result) | State machine — per-perform-site state ordinal + saved locals; same shape as MultiShot but with at-most-one-resume invariant |
| **MultiShot** | Handler arm declared `@resume=MultiShot`; can resume zero or many times | Heap-captured continuation per H7 — $alloc_continuation + cont.wat |

### 3.1 `$classify_handler(handler_handle) -> i32`

Returns 0=TailResumptive, 1=Linear, 2=MultiShot. Reads via
$lookup_ty + extracts TCont.discipline (the resume-discipline tag
on the continuation type — per spec 02 + spec 02 ResumeDiscipline
ADT at src/types.nx:70-73).

```wat
(func $classify_handler (param $handler_handle i32) (result i32)
  (local $ty i32) (local $cont i32) (local $disc i32)
  (local.set $ty (call $lookup_ty (local.get $handler_handle)))
  ;; Extract TCont(_, discipline) per Ty tag layout.
  (if (i32.ne (call $tag_of (local.get $ty)) (i32.const 112))    ;; TCONT_TAG
    (then (unreachable)))   ;; classify on non-TCont is a bug
  (local.set $disc (call $record_get (local.get $ty) (i32.const 1)))
  ;; ResumeDiscipline tags (per src/types.nx:70-73 conventions; tag
  ;; region relocated 2026-04-26 from 220/221/222 → 250/251/252 to
  ;; resolve collision with reason.wat's 220-242 Reason variants;
  ;; canonical layout now in Hβ-infer-substrate.md §2.3):
  ;;   OneShot   = sentinel 250
  ;;   MultiShot = sentinel 251
  ;;   Either    = sentinel 252
  (if (i32.eq (local.get $disc) (i32.const 250))
    (then (return (call $is_tail_resumptive (local.get $handler_handle)))))
                                ;; OneShot — discriminate TailResumptive (0)
                                ;; vs Linear (1) by structural body check
  (if (i32.eq (local.get $disc) (i32.const 251))
    (then (return (i32.const 2))))    ;; MultiShot
  (if (i32.eq (local.get $disc) (i32.const 252))
    (then (return (call $either_strategy (local.get $handler_handle)))))
                                ;; Either — install-time negotiation;
                                ;; for seed, default to Linear (1)
  (unreachable))
```

`$is_tail_resumptive(handler_handle)` walks the handler arm body
checking if every `resume` is in tail position. Returns 0 for
TailResumptive; 1 for Linear. Implementation per src/lower.nx
classify_handler — structural walk over the handler's body
LowExpr.

### 3.2 Monomorphic dispatch gate

Per spec 05 §Handler elimination §Monomorphic dispatch + spec 04
§Monomorphism:

```wat
(func $monomorphic_at (param $node_handle i32) (result i32)
  (local $ty i32) (local $row i32)
  (local.set $ty (call $lookup_ty (local.get $node_handle)))
  ;; If the type isn't a TFun, there's no row to check — treat as
  ;; trivially monomorphic (e.g., literal binds).
  (if (i32.ne (call $tag_of (local.get $ty)) (i32.const 107))    ;; TFUN_TAG
    (then (return (i32.const 1))))
  ;; Extract effect row from TFun(params, ret, row).
  (local.set $row (call $record_get (local.get $ty) (i32.const 2)))
  ;; Row is ground iff EfPure or EfClosed (no row variable).
  (call $row_is_ground (local.get $row)))

(func $row_is_ground (param $row i32) (result i32)
  ;; Pure or Closed; not Open (rowvar-bearing) — per row.wat predicates.
  (if (call $row_is_pure (local.get $row)) (then (return (i32.const 1))))
  (if (call $row_is_closed (local.get $row)) (then (return (i32.const 1))))
  (i32.const 0))
```

At each CallExpr lowering: if `$monomorphic_at(call_handle)` returns
1, emit `LCall` (direct call); else emit `LCall` with evidence
slot threading (the closure record's evidence field gets read +
$call_indirect at emit time).

Per spec 05 + H1 evidence reification: >95% of call sites prove
monomorphic. The 5% polymorphic minority routes through evidence
passing — function-pointer field on closure record per H1; no
vtable per CLAUDE.md anchor.

(Per the Mentl-runtime-characteristic correction in this session:
the 95/5 split is about MONOMORPHIC vs POLYMORPHIC dispatch, NOT
about OneShot vs MultiShot resume discipline. Multi-shot is on
Mentl's hot path per insight #11; cont.wat lands as substrate-live
hot-path handling.)

---

## §4 The lowering walk — `$lower_expr` + `$lower_stmt`

Per spec 05 + src/lower.nx lower_expr.

### 4.1 `$lower_expr(node) -> i32` (LowExpr pointer)

```wat
(func $lower_expr (param $node i32) (result i32)
  (local $tag i32) (local $h i32)
  (local.set $tag (call $tag_of (local.get $node)))
  (local.set $h (call $walk_expr_node_handle (local.get $node)))
                                              ;; landed in walk_expr.wat:306-307
                                              ;; (i32.load offset=12 — N-wrapper
                                              ;; handle field per parser_infra.wat:32-39)
  ;; Walk per AST variant; one arm per variant; trap on unknown.
  (if (i32.eq (local.get $tag) (i32.const <CONST_TAG>))
    (then (return (call $lower_const (local.get $node)))))
  (if (i32.eq (local.get $tag) (i32.const <VARREF_TAG>))
    (then (return (call $lower_var_ref (local.get $node)))))
  (if (i32.eq (local.get $tag) (i32.const <BINOP_TAG>))
    (then (return (call $lower_binop (local.get $node)))))
  (if (i32.eq (local.get $tag) (i32.const <CALL_TAG>))
    (then (return (call $lower_call (local.get $node)))))
  (if (i32.eq (local.get $tag) (i32.const <PERFORM_TAG>))
    (then (return (call $lower_perform (local.get $node)))))
  (if (i32.eq (local.get $tag) (i32.const <HANDLE_TAG>))
    (then (return (call $lower_handle (local.get $node)))))
  ;; ... arms for Lambda / Let / If / Match / List / Tuple / Record /
  ;;     Variant / Pipe (5 variants per spec 10) / Field / Block / etc.
  (unreachable))
```

### 4.2 Per-variant arms (spec 05 §No subst threading worked example)

**`$lower_const(node)`** — produces `LConst(h, $eval_literal(node))`.

**`$lower_var_ref(node)`**:
```wat
(local.set $name (call $var_ref_name (local.get $node)))
(local.set $h (call $walk_expr_node_handle (local.get $node)))
;; Look up in current function's locals first (LowerCtx).
(local.set $slot (call $ls_lookup_or_capture (local.get $name)))
(if (i32.lt_s (local.get $slot) (i32.const 0))
  (then
    ;; Global / outer-scope name; emit LGlobal.
    (return (call $lexpr_make_lglobal (local.get $h) (local.get $name)))))
;; Local or capture; emit LLocal.
(return (call $lexpr_make_llocal (local.get $h) (local.get $slot)))
```

**`$lower_binop(node)`**:
```wat
(local.set $h  (call $walk_expr_node_handle (local.get $node)))
(local.set $op (call $binop_op (local.get $node)))
(local.set $l  (call $lower_expr (call $binop_left (local.get $node))))
(local.set $r  (call $lower_expr (call $binop_right (local.get $node))))
(call $lexpr_make_lbinop (local.get $h) (local.get $op) (local.get $l) (local.get $r))
```

**`$lower_call(node)`** — the monomorphic-vs-polymorphic gate:
```wat
(local.set $h    (call $walk_expr_node_handle (local.get $node)))
(local.set $f    (call $lower_expr (call $call_fn (local.get $node))))
(local.set $args (call $lower_args (call $call_args (local.get $node))))
(if (call $monomorphic_at (local.get $h))
  (then (return (call $lexpr_make_lcall (local.get $h) (local.get $f) (local.get $args)))))
;; Polymorphic — evidence-passing thunk (LMakeClosure with evidence slots
;; populated; H1 substrate).
(return (call $emit_evidence_thunk (local.get $h) (local.get $f) (local.get $args)))
```

**`$lower_perform(node)`** — dispatches on the perform's op type's
resume discipline. Per H7 §4.1 Change 3:
```wat
(local.set $op_name (call $perform_op_name (local.get $node)))
(local.set $op_ty   (call $env_lookup_op_type (local.get $op_name)))
;; Extract ResumeDiscipline from op_ty (which is TCont(_, discipline) ish).
(local.set $disc (call $resume_discipline_of (local.get $op_ty)))
(if (i32.eq (local.get $disc) (i32.const 251))   ;; MULTISHOT (per ty.wat:128 lock)
  (then
    ;; Allocate continuation + emit suspend per H7.
    (local.set $state_idx (call $ms_alloc_state
                            (call $current_fn_handle) (local.get $h)))
    (local.set $ret_slot  (call $ms_alloc_ret_slot
                            (call $current_fn_handle) (local.get $state_idx)))
    (local.set $caps      (call $collect_free_vars_at (local.get $node)))
    (local.set $evs       (call $collect_evidence_slots (local.get $allowed_row)))
    (return
      (call $lexpr_make_lblock (local.get $h)
        (call $list_two
          (call $lexpr_make_lmakecontinuation
            (local.get $h_cont) (call $resume_fn_for_current_fn)
            (local.get $caps) (local.get $evs)
            (local.get $state_idx) (local.get $ret_slot))
          (call $lexpr_make_lperform (local.get $h)
            (local.get $op_name)
            (call $args_with_cont_ptr_last (local.get $args))))))))
;; OneShot — direct LPerform per H1.
(call $lexpr_make_lperform (local.get $h) (local.get $op_name)
                            (call $lower_args (local.get $args))))
```

**`$lower_handle(node)`** — the `~>` verb's lowering. Calls
$classify_handler on each arm; emits LHandleWith with the arm
strategies tagged.

**`$lower_pipe(node)`** — dispatches per PipeKind (spec 10):
```wat
(local.set $kind (call $pipe_kind (local.get $node)))
(if (i32.eq (local.get $kind) (i32.const <PIPE_BARE>))     ;; |>
  (then (return (call $lower_pipe_bare (local.get $node)))))
(if (i32.eq (local.get $kind) (i32.const <PIPE_DIVERGENT>)) ;; <|
  (then (return (call $lower_pipe_divergent (local.get $node)))))
(if (i32.eq (local.get $kind) (i32.const <PIPE_PARALLEL>))  ;; ><
  (then (return (call $lower_pipe_parallel (local.get $node)))))
(if (i32.eq (local.get $kind) (i32.const <PIPE_HANDLE>))    ;; ~>
  (then (return (call $lower_pipe_handle (local.get $node)))))
(if (i32.eq (local.get $kind) (i32.const <PIPE_FEEDBACK>))  ;; <~
  (then (return (call $lower_pipe_feedback (local.get $node)))))
                                                            ;; LFeedback per LF
(unreachable))
```

LFeedback's lowering allocates a state slot in the enclosing
handler's state record; subsequent loads/stores per spec 10 + LF
walkthrough §1.12 of Hβ-bootstrap.md.

### 4.3 `$lower_stmt(stmt)` and `$lower_program(stmts)`

`$lower_stmt(stmt)` dispatches on stmt tag (FnStmt / LetStmt /
TypeStmt / EffectStmt / HandlerStmt / ImportStmt / ExprStmt). Most
arms produce a top-level LDeclareFn or LLet; ExprStmt produces a
LowExpr.

`$lower_program(typed_ast)` is the entry: iterates over statements,
maintains a flat list of LowStmts, returns the lowered program for
emit consumption.

```wat
(func $lower_program (param $stmts i32) (result i32)
  (local $n i32) (local $i i32)
  (local $out i32) (local $lowered i32)
  (call $lower_init)
  ;; $stmts is the SAME flat list parsed_stmts that was passed to
  ;; $inka_infer; the graph carries the inferred type info per handle.
  ;; No "typed_ast" wrapper exists — pipeline shape per main.wat:154-156:
  ;;   parsed_stmts |> $inka_infer |> $inka_lower |> $emit_program
  ;; (every stage takes the same `stmts` pointer; graph IS the constraint
  ;; store per DESIGN.md §0.5).
  (local.set $n (call $len (local.get $stmts)))
  (local.set $out (call $make_list (local.get $n)))
  (local.set $i (i32.const 0))
  (block $done
    (loop $iter
      (br_if $done (i32.ge_u (local.get $i) (local.get $n)))
      (local.set $lowered (call $lower_stmt
                            (call $list_index (local.get $stmts) (local.get $i))))
      (drop (call $list_set (local.get $out) (local.get $i) (local.get $lowered)))
      (local.set $i (i32.add (local.get $i) (i32.const 1)))
      (br $iter)))
  (local.get $out))
```

---

## §5 Per-edit-site eight interrogations

Each chunk's edit sites pass all eight per CLAUDE.md / DESIGN.md §0.5.

### 5.1 At LookupTy + LowerCtx primitives

| # | Primitive | Answer |
|---|-----------|--------|
| 1 | **Graph?** | $lookup_ty IS the live graph read; never caches. |
| 2 | **Handler?** | Seed's primitives are direct functions; the wheel's compiled form is the LookupTy effect handler. |
| 3 | **Verb?** | N/A. |
| 4 | **Row?** | $row_is_ground reads via $lookup_ty + dispatches on row.wat predicates. |
| 5 | **Ownership?** | Locals ledger is OWN by current fn; cleared at $ls_reset_function. |
| 6 | **Refinement?** | TRefined types pass through transparent; refinement obligations were recorded at infer time. |
| 7 | **Gradient?** | Locals + captures are gradient signals — every captured outer-scope name appears in the closure's evidence slots if polymorphic, captures slots if monomorphic. |
| 8 | **Reason?** | $lookup_ty preserves the GNode's Reason via the wrapping — caller can access via $gnode_reason on the chase result. |

### 5.2 At handler elimination

| # | Primitive | Answer |
|---|-----------|--------|
| 1 | **Graph?** | $monomorphic_at reads the type via $lookup_ty + chases the row. |
| 2 | **Handler?** | $classify_handler dispatches on TCont.discipline per H1 + H7 substrate. NO vtable per CLAUDE.md anchor. |
| 3 | **Verb?** | N/A at primitive level; ~> verb's lowering uses this. |
| 4 | **Row?** | Monomorphism gate IS row.wat's $row_is_ground. |
| 5 | **Ownership?** | Captured closure record's ownership flows per H1 evidence reification. |
| 6 | **Refinement?** | N/A. |
| 7 | **Gradient?** | Monomorphic-handler-chain IS the gradient signal for direct call (the gain from rich row inference). |
| 8 | **Reason?** | Each LCall vs LMakeClosure choice records a Reason per src/lower.nx convention. |

### 5.3 At the lowering walk

| # | Primitive | Answer |
|---|-----------|--------|
| 1 | **Graph?** | Every $lower_<variant> reads types via $lookup_ty (which is $graph_chase). |
| 2 | **Handler?** | $lower_handle classifies via $classify_handler; $lower_perform dispatches per ResumeDiscipline. |
| 3 | **Verb?** | $lower_pipe dispatches on PipeKind for all 5 verbs per spec 10. |
| 4 | **Row?** | $lower_call reads row to choose direct-vs-evidence; $lower_handle adjusts row at install time. |
| 5 | **Ownership?** | Captures vs locals discriminated via LowerCtx; affine_ledger is the wheel's runtime-handler concern; lower just ships the closure record shape. |
| 6 | **Refinement?** | TRefined transparent; lower never emits a refinement check (verify ledger handles at infer time + post-emit verify_smt swap). |
| 7 | **Gradient?** | LCall vs LMakeClosure with evidence — each choice IS a gradient step the row inference earned. |
| 8 | **Reason?** | Every LowExpr carries the source TypeHandle; the GNode at that handle holds the Reason; lower is read-only on Reason. |

---

## §6 Forbidden patterns per edit site

Strict per CLAUDE.md drift modes + foreign fluency in compiler-
backend land.

### 6.1 At LookupTy + LowerCtx

- **Drift 1 (Rust vtable):** No dispatch table at LookupTy. It's
  $graph_chase + tag-dispatch. NO vtable. NO mode flag.
- **Drift 2 (Scheme env frame):** LowerCtx is module-level globals;
  no recursive frame walk for slot lookup.
- **Drift 9 (deferred-by-omission):** Every LowExpr variant has a
  $lexpr_make_<variant> + accessor; no "TODO emit later" silent
  fallback.

### 6.2 At handler elimination

- **Drift 1 (vtable):** CRITICAL. The seed's emit must NOT
  generate a dispatch_table for handler ops. Per H1 evidence
  reification: closure record's fn_index FIELD + call_indirect
  at emit time. Three named drift signals to refuse:
  - "dispatch_table" / "dispatch table" in any chunk comment
  - any data segment named "$op_table" or "$handler_dispatch"
  - any function returning `i32` named `_lookup_handler_for_op`
- **Drift 5 (C calling convention):** ONE `$cont_ptr` parameter on
  the resume_fn (per H7 §1.2). NOT separate `$closure + $ev +
  $ret_slot`.
- **Foreign fluency — JS async/await:** $classify_handler MUST
  NOT name strategies "promise-like" / "async" / "future". The
  vocabulary is TailResumptive / Linear / MultiShot per spec 05.
- **Foreign fluency — Scheme call/cc:** Continuations here are
  DELIMITED (scoped to handler install boundary), not undelimited.
  Per H7 §3.2 forbidden patterns.

### 6.3 At the lowering walk

- **Drift 4 (Haskell monad transformer):** No `LowerM` monad. The
  walk is a direct function returning LowExpr pointers.
- **Drift 5 (C calling convention):** No threaded `(subst,
  lowered_ast, accum)` tuple. LowerCtx via globals; no parameters
  carry inference state.
- **Drift 9:** Every AST variant has a $lower_<variant> arm. No
  `_ =>` silent fallback. Trap via `(unreachable)` on unknown.
- **Foreign fluency — LLVM IR / GHC Core / OCaml closure conversion:**
  LowExpr is an Inka-internal IR shaped per spec 05 + the kernel's
  five verbs + handler-elimination trio. NOT a generic SSA / CPS /
  closure-conversion IR. Vocabulary stays Inka: LowExpr / LowerCtx /
  classify_handler / monomorphic_at / row_is_ground.

---

## §7 Substrate touch sites — chunk decomposition

`bootstrap/src/lower/` directory holds the lowering layer chunks.

### 7.1 Proposed file layout

```
bootstrap/src/lower/
  INDEX.tsv              ;; dep graph + Hβ.lower-substrate.md cite per chunk
  state.wat              ;; Tier 5 — module-level scratchpads ($lower_locals_ptr,
                         ;;          $lower_captures_ptr, $lower_next_slot_g)
                         ;;          + $lower_init + $ls_* helpers
  lookup.wat             ;; Tier 5 — $lookup_ty + $row_is_ground + $monomorphic_at +
                         ;;          $resume_discipline_of (the seed's bridge between
                         ;;          spec 04's typed AST + spec 05's lowering)
  lexpr.wat              ;; Tier 6 — LowExpr constructors + $lexpr_handle accessor +
                         ;;          tag conventions per §2 (shared with Hβ.emit chunk
                         ;;          — emit reads these tags to dispatch)
  classify.wat           ;; Tier 7 — $classify_handler + $is_tail_resumptive +
                         ;;          $either_strategy
  walk_const.wat         ;; Tier 7 — $lower_const + $lower_var_ref + literals
  walk_call.wat          ;; Tier 7 — $lower_call + $lower_perform + $emit_evidence_thunk
                         ;;          (the load-bearing dispatch arm)
  walk_handle.wat        ;; Tier 7 — $lower_handle + $lower_pipe + LMakeContinuation
                         ;;          construction per H7 + LFeedback per LF
  walk_compound.wat      ;; Tier 7 — $lower_lambda + $lower_let + $lower_if +
                         ;;          $lower_match + $lower_list + $lower_tuple +
                         ;;          $lower_record + $lower_variant
  walk_stmt.wat          ;; Tier 8 — $lower_stmt + $lower_fn_stmt + $lower_let_stmt +
                         ;;          $lower_import_stmt + $lower_type_stmt +
                         ;;          $lower_effect_stmt + $lower_handler_stmt
  emit_diag.wat          ;; Tier 6 — $lower_emit_unresolved_type + diagnostic helpers
  main.wat               ;; Tier 9 — $lower_program orchestrator
```

11 chunks. Total ~2500-4000 WAT lines (estimate per spec 05 +
src/lower.nx 1284 lines projected at 1.5-2.5×).

### 7.2 Layer extension

Add Layer 5 (lower) between Layer 4 (infer per Hβ-infer-substrate.md)
and Layer 6 (existing emitter — to be renumbered):

```bash
  # ── Layer 4: Inference (per Hβ-infer-substrate.md) ──
  ...

  # ── Layer 5: Lowering (NEW per Hβ-lower-substrate.md) ──
  "bootstrap/src/lower/state.wat"
  "bootstrap/src/lower/lookup.wat"
  "bootstrap/src/lower/lexpr.wat"
  "bootstrap/src/lower/classify.wat"
  "bootstrap/src/lower/walk_const.wat"
  "bootstrap/src/lower/walk_call.wat"
  "bootstrap/src/lower/walk_handle.wat"
  "bootstrap/src/lower/walk_compound.wat"
  "bootstrap/src/lower/walk_stmt.wat"
  "bootstrap/src/lower/emit_diag.wat"
  "bootstrap/src/lower/main.wat"

  # ── Layer 6: Emitter (existing — possibly extended per Hβ.emit
  #              substrate walkthrough if needed) ──
  ...
```

### 7.3 Per-chunk WABT verification

Per Morgan: WABT tools welcome along the way.

After each chunk lands:
```bash
bash bootstrap/build.sh                     # assemble + wat2wasm
wasm-validate bootstrap/inka.wasm           # structural validation
bash bootstrap/first-light.sh                # lexer proof-of-life unchanged
wasm-objdump -x bootstrap/inka.wasm | grep '<lower_'   # confirm new fns
wasm-decompile bootstrap/inka.wasm | sed -n '/function lookup_ty/,/^}/p'
                                              # spot-check decompiled body
```

After classify.wat:
```bash
;; Build a tiny test harness invoking $classify_handler with a
;; known TailResumptive handler (single tail-position resume) + a
;; known MultiShot handler (perform choose with backtrack).
;; Verify return values are 0 and 2 respectively.
```

After walk_call.wat:
```bash
;; Critical: monomorphic-vs-polymorphic gate. Test harness lowers
;; a known monomorphic call (Pure-row callee) — verify LCall.
;; Test harness lowers a known polymorphic call (Open-row callee)
;; — verify LMakeClosure with evidence slots.
```

### 7.4 Estimated scope per chunk

| Chunk | Lines (target) | Spec source |
|-------|---------------|-------------|
| state.wat | ~150 | this §1.2 + spec 06 LowerCtx |
| lookup.wat | ~200 | this §1.1 + §3.2 + spec 05 §LookupTy |
| lexpr.wat | ~600 | spec 05 §LowIR + this §2 — 35 variants × ~17 lines/variant |
| classify.wat | ~250 | this §3 + src/lower.nx classify_handler |
| walk_const.wat | ~150 | spec 05 + src/lower.nx |
| walk_call.wat | ~400 | spec 05 §No subst threading + H1 + H7 |
| walk_handle.wat | ~350 | spec 05 + spec 10 + H7 + LF |
| walk_compound.wat | ~500 | spec 05 + spec 10 |
| walk_stmt.wat | ~250 | spec 03 + spec 05 |
| emit_diag.wat | ~100 | spec 05 invariant 2 + spec 06 report |
| main.wat | ~100 | this §4.3 |
| **TOTAL** | **~3050** | |

Combined Hβ.infer + Hβ.lower (revised 2026-04-27 audit): Hβ.infer
landed at **7,712 WAT lines** across 11 chunks (1.2× the original
~6430 estimate per the eight-interrogations + named-follow-up
discipline expanding chunk headers); applying the same factor to
the §7.4 ~3050-line lower estimate gives ~3700 lines for Hβ.lower.
Combined ≈ **11,400 WAT lines** + existing emitter ~1728 + emitter
extension ~500 ≈ **13,600+ WAT lines** total seed substrate
post-Wave-2.E. (Hβ.infer baseline: bootstrap/src/infer/ totals
7,712 lines as of commit `b6e1f23`; build assembles to 14,645
lines / 71,095 bytes.)

---

## §8 Worked example — lowering `fn double(x) = x + x`

Per the Hβ-infer §9 worked example continuation. Inference left:
| Handle | NodeKind | Reason |
|--------|----------|--------|
| 1 | NBound(TFun([TParam("x", TInt, _)], TInt, EfPure)) | Generalized |
| 2 | NBound(TInt) | OpConstraint("+", ...) |
| 3 | NBound(TInt) | OpConstraint("+", ...) |
| 4 | NBound(TVar(2)) → TInt | VarLookup |
| 5 | NBound(TVar(2)) → TInt | VarLookup |

### 8.1 Lowering trace

```
$lower_program(typed_ast):
  $lower_init()
  $lower_stmt(FnStmt handle=1 name="double"):
    $ls_reset_function()
    ;; Bind param "x" as local slot 0; ty TInt.
    $ls_bind_local("x", $ty_make_int())   ;; slot 0
    ;; Lower body — $lower_expr(BinOpExpr handle=3):
    $lower_binop(BinOpExpr handle=3 op="+"):
      $lower_var_ref(VarRef "x" handle=4):
        $ls_lookup_or_capture("x") → 0 (local)
        return LLocal(handle=4, slot=0)
      $lower_var_ref(VarRef "x" handle=5):
        $ls_lookup_or_capture("x") → 0
        return LLocal(handle=5, slot=0)
      return LBinOp(handle=3, op="+", LLocal(4, 0), LLocal(5, 0))
    ;; FnStmt → LDeclareFn(LFn("double", arity=1, ["x"],
    ;;                          [LReturn(handle=1, body)],
    ;;                          row=EfPure))
    return LDeclareFn(...)
```

### 8.2 Resulting LowIR

```
LDeclareFn(LFn("double", 1, ["x"], [
  LReturn(1, LBinOp(3, "+",
    LLocal(4, 0),
    LLocal(5, 0)))
], EfPure))
```

### 8.3 What this trace exercises

- LookupTy via $graph_chase on every handle
- LowerCtx slot assignment + lookup ($ls_bind_local + $ls_lookup_or_capture)
- $lower_binop arm (composition with $lower_expr recursion)
- $lower_var_ref arm (LLocal vs LGlobal discriminator)
- FnStmt arm (LDeclareFn synthesis with EfPure row)
- Direct-call gate would fire if anyone called `double` (TFun row
  is EfPure → ground → monomorphic at call site → LCall not
  LMakeClosure)

What this trace does NOT exercise (because the program is too
simple): handler installation (~>), perform (with $classify_handler
+ $lower_perform's MS dispatch), pipe verbs other than implicit
function call, refinement obligations, ownership consume, MS
continuation alloc. Those are exercised by larger programs (e.g.,
src/graph.nx itself).

---

## §9 Composition with Hβ.infer / Hβ.emit / cont.wat / LFeedback / Synth

### 9.1 Hβ.lower × Hβ.infer

The clean handoff per spec 04 + spec 05. Inference produces typed
AST + populated graph; lower reads via $lookup_ty (= $graph_chase).
Per spec 04 §Monomorphism: "monomorphism is a graph read, not a
sidecar" — lower's $monomorphic_at proves this at the WAT layer.

Inference's typed AST stays UNCHANGED through lowering — lower
produces a parallel LowExpr tree with handles cross-referencing.
The graph is shared state.

### 9.2 Hβ.lower × Hβ.emit

The seed's existing emit_*.wat chunks (~1728 lines) currently
template WAT directly from AST shape. Post-Wave-2.E.lower they
must be EXTENDED to consume LowExpr instead of AST:

- Emit reads LowExpr via $lexpr_handle + $tag_of dispatch.
- $lexpr_ty (= $lookup_ty($lexpr_handle(_))) gives the type when
  emit needs `ty_to_wasm` per spec 05 §Emitter handoff.
- LMakeContinuation emit arm at src/backends/wasm.nx (already
  there per H7) gets transcribed into bootstrap/src/lower or
  stays in emit chunks per existing convention.

Per Hβ §9 sub-handle decomposition: Hβ.emit may need its own
walkthrough (Hβ-emit-substrate.md) for the existing emit chunks'
extension. Currently named follow-up.

### 9.3 Hβ.lower × cont.wat (H7)

Per H7 §1.2 + §1.13 + this §4.2 $lower_perform: when ResumeDiscipline
is MultiShot, $lower_perform allocates a state ordinal via
$ms_alloc_state + emits LMakeContinuation. cont.wat (Wave 2.B.2)
is the runtime substrate; Hβ.lower is the compile-time substrate
that produces LMakeContinuation LowExpr nodes that Hβ.emit lowers
to runtime calls into cont.wat.

### 9.4 Hβ.lower × LFeedback (LF)

Per spec 10 + LF walkthrough (substrate at src/backends/wasm.nx
commit `7f8ff5f`). $lower_pipe_feedback emits LFeedback LowExpr.
The state-slot allocation per LF §1.12 of Hβ-bootstrap.md: lower
records the feedback slot index in the enclosing handler's state
record. Emit translates LFeedback to load/tee/store sequence per
LF.

### 9.5 Hβ.lower × Synth chain

Per insight #11 (oracle = IC + cached value). Mentl's Synth
handlers compose ON the H7 substrate post-L1; Hβ.lower's job is
to emit LMakeContinuation + LPerform for the Synth ops in
src/mentl.nx. The seed never INVOKES Synth (Mentl is a wheel-time
+ post-compile concern); the seed COMPILES src/mentl.nx + friends
correctly so the wheel can run the oracle.

---

## §10 Acceptance criteria

### 10.1 Type-level acceptance (Hβ.lower substrate lands)

- [ ] `bootstrap/src/lower/` directory exists with 11 chunks per §7.1.
- [ ] `bootstrap/src/lower/INDEX.tsv` declares each chunk.
- [ ] `bootstrap/build.sh` CHUNKS[] includes lower chunks at Layer 5.
- [ ] `wat2wasm bootstrap/inka.wat` succeeds.
- [ ] `wasm-validate bootstrap/inka.wasm` passes.
- [ ] `wasm-objdump -x bootstrap/inka.wasm | grep '<lower_'` lists
      $lookup_ty, $lower_expr, $lower_stmt, $classify_handler,
      $monomorphic_at, $lower_program (at minimum).

### 10.2 Functional acceptance (per-program tests)

- [ ] Lowering the §8 worked example produces the LowIR in §8.2
      (verifiable via test harness invoking $lower_program +
      $tag_of dispatch on the result).
- [ ] Lowering a known monomorphic call site emits LCall (not
      LMakeClosure).
- [ ] Lowering a known polymorphic call site emits LMakeClosure
      with evidence slots populated.
- [ ] Lowering a `perform choose([...])` site (post-CE/B.3 in
      lib/runtime/search.nx) emits LMakeContinuation + LPerform.
- [ ] Lowering a `<~ delay(1)` site emits LFeedback per LF.

### 10.3 Self-compile acceptance (Hβ.lower in service of L1)

- [ ] `cat src/verify.nx | wasmtime run bootstrap/inka.wasm` produces
      WAT that wasm-validates after linking.
- [ ] `cat src/graph.nx | wasmtime run bootstrap/inka.wasm` produces
      non-degenerate WAT (improvement against BT.A.0 baseline).
- [ ] `cat src/types.nx | wasmtime run bootstrap/inka.wasm` produces
      validating WAT.

### 10.4 Drift-clean

- [ ] `bash tools/drift-audit.sh bootstrap/src/lower/*.wat` exits 0.

---

## §11 Open questions + named follow-ups

| Question | Resolution |
|----------|-----------|
| Tag values for LowExpr — coordinate with Hβ.emit? | Yes — §2 names the 300-349 range; lock in coordination with Hβ.emit chunk extensions. |
| Resume-discipline tag values for ResumeDiscipline ADT? | LOCKED 2026-04-26: OneShot=250 / MultiShot=251 / Either=252 (region 250-259). Earlier draft used 220/221/222 but Wave 2.E.infer.reason landed Reason variants at 220-242 (commit `2609c82`); per Wave 2.E.infer.ty agent gap-finding, ResumeDiscipline relocated to 250-259 to preserve $tag_of uniqueness across the heap. Canonical layout in Hβ-infer-substrate.md §2.3. |
| Either-discipline strategy — what's the seed's default? | Linear (1) when handler body's static check can't classify TailResumptive. Per src/lower.nx classify_handler precedent. |
| Cross-module function symbol resolution? | Hβ.link (BT.A.2) via link.py + symbol-rename. Hβ.lower emits module-local references; link resolves at assembly time. |
| Does the seed lower MultiShot ops at all in Tier-3 base? | Yes — per H7 §2.5 substrate already in src/lower.nx; the seed transcribes the same. |
| `$ty_make_terror_hole` ownership + tag value? | LOCKED 2026-04-27 audit (riffle-back against landed Hβ.infer): lookup.wat-private constructor; tag value 114 (next free after ty.wat 100-113); lookup-time-only sentinel (the type system never produces NErrorHole at the Ty layer; NErrorHole is at the GNode layer per graph.wat:55-59). Lower's `$lookup_ty` returns this for NERRORHOLE NodeKinds; emit dispatches it to (unreachable). NOT a 15th Ty variant — staying lower-private preserves ty.wat's 14-variant ADT discipline. |
| `$walk_expr_node_handle` cross-layer reuse vs. lower-private re-derive? | LOCKED 2026-04-27: lower's lookup.wat + walk_const/var_ref/binop/call USE `$walk_expr_node_handle` directly (Hβ.infer landed it at walk_expr.wat:306-307; cross-layer convergence per Anchor 4). Optional cleanup follow-up `Hβ.shared.node_handle` — rename to `$node_handle` and move to `parser_infra.wat` as a runtime-shared helper. Three sites earn the abstraction (parser builds, infer reads, lower reads); ready when Hβ.lower's walk arms land + create the third. |
| Lower-private vs. infer-owned diagnostics — boundary? | Per §D.3 audit: `$lower_emit_unresolved_type` IS lower-owned (NFree at lookup time means inference didn't bind a handle that lower expects bound; it's a lowering-stage compiler bug, not an inference user error). All Hazel productive-under-error user diagnostics remain in `bootstrap/src/infer/emit_diag.wat` (infer-owned per `88992bc` boundary canonicalization). Lower's `emit_diag.wat` chunk is purely for lower-private classes (e.g., unsupported pipe verb at lower target, monomorphic gate logic-bug). |

### Named follow-ups (Hβ.lower extensions)

- **Hβ.lower.evidence-thunk** — full $emit_evidence_thunk per H1
  evidence reification with closure-record evidence-slot population.
- **Hβ.lower.either** — Either dispatch with install-time
  negotiation between TailResumptive and MultiShot.
- **Hβ.lower.refinement-erasure** — TRefined → base type erasure
  per spec 05 §1.11 (currently transparent; explicit erasure pass
  needed if refinement carries runtime-relevant data).
- **Hβ.lower.cross-module** — cross-module reference resolution +
  module-qualified symbol generation per BT.A.2.

---

## §12 Dispatch + sub-handle decomposition

### 12.1 Authoring

This walkthrough: Opus inline (this commit).

### 12.2 Substrate transcription

Per Hβ §8 dispatch: bootstrap work needs Opus-level judgment + WAT
fluency + per-handle walkthrough reading.

**Per-chunk dispatch:**

| Chunk | Dispatch | Rationale |
|-------|----------|-----------|
| state.wat | Opus inline OR Sonnet via inka-implementer | small; mechanical |
| lookup.wat | Opus inline | $lookup_ty correctness load-bearing for everything downstream |
| lexpr.wat | Opus inline OR Sonnet | constructors per §2 tag conventions; mechanical |
| classify.wat | **Opus inline only** | $classify_handler + $is_tail_resumptive subtle; structural body check |
| walk_const.wat | Opus inline OR Sonnet | small + direct |
| walk_call.wat | **Opus inline only** | monomorphic gate + H7 dispatch — load-bearing center |
| walk_handle.wat | Opus inline | LMakeContinuation construction + LFeedback per LF — non-trivial |
| walk_compound.wat | Opus inline OR Sonnet | per-variant arms; bulk transcription |
| walk_stmt.wat | Opus inline | FnStmt with closure synthesis; non-trivial |
| emit_diag.wat | Opus inline OR Sonnet | report-effect arm; mechanical |
| main.wat | Opus inline OR Sonnet | orchestrator |

### 12.3 Sub-handle dependency order (revised 2026-04-27 audit)

1. **state.wat** (deps: alloc, list, record)
2. **lookup.wat** (deps: state, graph, row, ty.wat from infer,
   walk_expr.wat for `$walk_expr_node_handle` access; OWNS
   `$ty_make_terror_hole` per §11 lock)
3. **lexpr.wat** (deps: record, list)
4. **emit_diag.wat** (deps: lookup, infer's reason.wat,
   infer's emit_diag.wat for delegation surface per §11 boundary)
5. **classify.wat** (deps: lookup, lexpr)
6. **walk_const.wat** (deps: lexpr, state, walk_expr.wat)
7. **walk_call.wat** (deps: classify, lookup, lexpr, cont.wat,
   walk_expr.wat) — **gets the 251 fix per §4.2**
8. **walk_handle.wat** (deps: classify, walk_call, cont.wat)
9. **walk_compound.wat** (deps: lexpr, walk_const, walk_call)
10. **walk_stmt.wat** (deps: walk_compound, walk_handle, env)
11. **main.wat** (deps: walk_stmt) — pipeline-stage boundary
    `$inka_lower` (symmetric with `$inka_infer` per Hβ-bootstrap §1.15)

### 12.4 Per-handle landing discipline

Each chunk lands per Anchor 7:
- Walkthrough cite (this file's §) in chunk header.
- Dependencies declared in INDEX.tsv.
- WABT verification post-commit.
- Drift-audit clean.
- Eight interrogations clear (per §5).
- Forbidden patterns audited (per §6).

---

## §13 Closing

Hβ.lower is the layer that bridges Hβ.infer's typed AST output to
Hβ.emit's WAT text input. Per spec 05: "Lower the typed AST to LowIR
by reading types LIVE from the Graph. No cached types in LowExpr.
No per-module subst snapshot."

This walkthrough projects spec 05 + src/lower.nx + H7 + LF onto
the Wave 2.A–D Layer-1 substrate (alloc + str + int + list +
record + closure + cont + graph + env + row + verify) + Hβ.infer's
output (typed AST + populated graph). **The substrate exists; the
upstream pass is contracted (Hβ-infer-substrate.md); what remains
is transcription per the §7 chunk decomposition.**

Per Anchor 0 dream-code discipline: walkthrough specifies what
Hβ.lower IS in ultimate form, assuming Wave 2.A–D substrate +
Hβ.infer are perfect. The architecture rises to meet it.

Per Anchor 4 + Hβ §0: the wheel is src/lower.nx (1284 lines of
substantively-real Inka per plan §16); this walkthrough's substrate
is its seed transcription; both kept forever.

**Eleven chunks. Three handler-elimination strategies. One
monomorphism gate. Five verb arms.** The lowering layer of the
seed, named in writing, ready to transcribe.

Combined with Hβ-infer-substrate.md, the FULL CONTRACT for the
seed's missing layers (inference + lowering) is now locked. Per
insight #12 compound interest: any future-Opus session can
transcribe substrate from these two walkthroughs without re-
deriving from spec 04 / spec 05 / src/infer.nx / src/lower.nx /
src/types.nx / src/effects.nx — the corpus already projected onto
the Wave 2.A–D substrate.

Sibling walkthroughs to write next (per Hβ §13 named follow-ups):
  - Hβ-link-protocol.md — bootstrap/src/link.py linker per BT §3 +
                          Hβ §2.3 (~200 lines link.py)
  - Hβ-emit-substrate.md — emit chunks extension if existing emit_*.wat
                           need refactoring to consume LowExpr (likely
                           yes for LMakeContinuation + LFeedback)

*Per Mentl's anchor: write only the residue. The walkthroughs already
say what the medium IS. This walkthrough is the residue between
Hβ-infer-substrate.md's typed-AST output + spec 05's lowering-
algorithm + the Wave 2.A–D substrate + H7's LMakeContinuation +
LF's LFeedback. The next residue is per-chunk WAT transcription;
transcribers cite this walkthrough's §s.*

---

**Hβ.infer + Hβ.lower together = the cliff named, mapped, ready to
climb.** Per insight #11 (Mentl IS speculative inference firing on
every save), per Hβ §0 (Inka bootstraps through Inka), per Anchor 0
(dream code), per Anchor 4 (build the wheel; never wrap the axle).
The two walkthroughs locked together unblock the full Wave 2.E
substrate transcription. Estimated combined scope:
~6430 WAT lines across 21 chunks. Plus existing Hβ.lex/parse/emit
extensions per their named follow-ups. The seed becomes a full
Inka compiler when these chunks land.

**The wheel awaits its seed.** The seed's substrate awaits its
transcription. The transcription awaits its ratification — but the
contract is on the page; the path is named; the next session
proceeds from contract to substrate per Anchor 7's cascade
discipline.
