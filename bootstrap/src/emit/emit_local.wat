  ;; ═══ emit_local.wat — Hβ.emit local-scope family (Tier 6, chunk #4) ═══
  ;; Implements: Hβ-emit-substrate.md §2.2 (local-scope family) +
  ;;             §3.5 (EmitMemory swap surface — read-only here; no
  ;;             allocation in this chunk) + §5.1 (eight interrogations)
  ;;             + §7.1 (chunk #4 emit_local.wat) + §11.3 dep order
  ;;             (chunk #4 follows emit_const.wat which introduced
  ;;             $emit_lexpr partial dispatcher per Hβ.lower walk_call.wat
  ;;             precedent).
  ;; Exports:    $emit_llocal, $emit_lglobal, $emit_lstore, $emit_lupval,
  ;;             $emit_lstateget, $emit_lstateset, $emit_lfieldload.
  ;; Uses:       $lexpr_llocal_name + $lexpr_lglobal_name +
  ;;             $lexpr_lstore_slot + $lexpr_lstore_value +
  ;;             $lexpr_lupval_slot + $lexpr_lstateget_slot +
  ;;             $lexpr_lstateset_slot + $lexpr_lstateset_value +
  ;;             $lexpr_lfieldload_record + $lexpr_lfieldload_offset_bytes
  ;;             (lower/lexpr.wat),
  ;;             $emit_byte + $emit_str + $emit_int + $emit_close
  ;;             (emit_infra.wat),
  ;;             $emit_lexpr (emit_const.wat — partial dispatcher;
  ;;             this chunk RETROFITS its arm table for tags 301/302/303/
  ;;             305/326/327/334 per Hβ.emit.lexpr-dispatch-extension).
  ;;
  ;; What this chunk IS (per Hβ-emit-substrate.md §2.2 + wheel canonical
  ;; src/backends/wasm.nx:1146-1180 + 1501-1512 + 1628-1633):
  ;;
  ;;   1. $emit_llocal(r) — LLocal tag 301 (handle, name).
  ;;      Emits "(local.get $<name>)". Lock #1 from chunk #6 walk_const:
  ;;      LLocal carries (local_h, name) NOT (handle, slot); slot
  ;;      mapping happens per-fn at LFn LowerCtx layer (chunk #7
  ;;      emit_handler.wat).
  ;;
  ;;   2. $emit_lglobal(r) — LGlobal tag 302 (handle, name).
  ;;      Emits "(global.get $<name>)" per src/backends/wasm.nx:1152-1156.
  ;;
  ;;   3. $emit_lstore(r) — LStore tag 303 (handle, slot, value).
  ;;      Emits sub-LowExpr(value) via $emit_lexpr, then
  ;;      "(local.set $l<slot>)" — wheel uses $l<slot> naming for
  ;;      slot-keyed locals (different from LLet's $<name>).
  ;;
  ;;   4. $emit_lupval(r) — LUpval tag 305 (handle, slot).
  ;;      Emits "(local.get $__state) (i32.load offset=<8 + 4*slot>)"
  ;;      per W7 closure record layout (offset 0 fn_ptr, offset 4
  ;;      capture_count, offset 8+4*i capture_i). Per H1.6 evidence
  ;;      reification: closure record IS the unified __state.
  ;;
  ;;   5. $emit_lstateget(r) — LStateGet tag 326 (handle, slot).
  ;;      Emits "(global.get $s<slot>)" — state-machine globals.
  ;;
  ;;   6. $emit_lstateset(r) — LStateSet tag 327 (handle, slot, value).
  ;;      Emits sub-LowExpr(value) via $emit_lexpr, then
  ;;      "(global.set $s<slot>)".
  ;;
  ;;   7. $emit_lfieldload(r) — LFieldLoad tag 334 (handle, record,
  ;;      offset_bytes). Emits sub-LowExpr(record) via $emit_lexpr,
  ;;      then "(i32.load offset=<offset_bytes>)". Per H2 record
  ;;      substrate: field at byte 4*i; offset comes from
  ;;      $lexpr_lfieldload_offset_bytes(r).
  ;;
  ;; Eight interrogations (per Hβ-emit-substrate.md §5.1 second pass):
  ;;
  ;;   1. Graph?       Each arm reads its LowExpr's record fields via
  ;;                   $lexpr_l*_* accessors. LStore + LStateSet +
  ;;                   LFieldLoad recurse into sub-LowExprs via
  ;;                   $emit_lexpr — the dispatcher introduced in
  ;;                   chunk #3. Per Anchor 1: ask the LowExpr graph;
  ;;                   never re-derive shape from primitive vocabulary.
  ;;   2. Handler?     At wheel: each arm is one branch of emit_expr
  ;;                   match per src/backends/wasm.nx:1143-1633. At seed:
  ;;                   direct fn dispatch via $emit_lexpr's tag table.
  ;;                   @resume=OneShot at the wheel (single-pass
  ;;                   emission per LowExpr tree).
  ;;   3. Verb?        |> — each arm's body is forward flow:
  ;;                   read fields → recurse-emit sub-expr (if any) →
  ;;                   emit instruction tokens. No verb-topology
  ;;                   here — verbs emerge in chunks #6 (LCall) + #7
  ;;                   (LHandleWith) per LowExpr semantics.
  ;;   4. Row?         WasmOut at wheel; row-silent at seed. Side-effect
  ;;                   on $out_base/$out_pos via $emit_byte. EmitMemory
  ;;                   row NOT present here — local-scope arms are
  ;;                   read-only / no allocation.
  ;;   5. Ownership?   LowExpr `r` is `ref` (read-only structural
  ;;                   traversal). $out_base buffer OWNed program-wide
  ;;                   per emit_infra.wat globals.
  ;;   6. Refinement?  N/A — local-scope arms have no refinement
  ;;                   obligations. LFieldLoad's offset is structurally
  ;;                   determined at lower time per H2 substrate.
  ;;   7. Gradient?    LUpval IS the H1.6 evidence reification cash-out
  ;;                   site — "the closure record IS the unified
  ;;                   __state" made physical at WAT. The `(local.get
  ;;                   $__state) (i32.load offset=...)` pattern IS the
  ;;                   compile-time-known evidence access; no runtime
  ;;                   evidence-table lookup.
  ;;   8. Reason?      Read-only — caller's $lookup_ty preserves Reason
  ;;                   chain on LowExpr's source handle. Local-scope
  ;;                   arms do not write Reasons.
  ;;
  ;; Forbidden patterns audited (per Hβ-emit-substrate.md §6 + project
  ;; drift modes):
  ;;
  ;;   - Drift 1 (Rust vtable):      Direct arm dispatch via $emit_lexpr's
  ;;                                 (i32.eq tag N) chain; NO $emit_local_table
  ;;                                 data segment / NO _lookup_local_emit_for_tag
  ;;                                 helper. Word "vtable" appears nowhere.
  ;;   - Drift 5 (C calling conv):   Each arm takes ONE LowExpr ref param;
  ;;                                 no __closure/__ev split. The wheel's
  ;;                                 emit_expr match is parameterized by ONE
  ;;                                 expr; mirror at the seed.
  ;;   - Drift 7 (parallel arrays):  LowExpr fields accessed via record-
  ;;                                 shaped $lexpr_l*_* accessors (single
  ;;                                 record ptr field per LowExpr), not
  ;;                                 parallel slot-arrays + names-arrays.
  ;;   - Drift 8 (string-keyed):     Tag dispatch in $emit_lexpr via
  ;;                                 integer constants (301/302/303/305/
  ;;                                 326/327/334); NEVER `str_eq($render
  ;;                                 _lowexpr, "LLocal")`. LLocal/LGlobal
  ;;                                 emit names AS strings via $emit_str
  ;;                                 because the WAT identifier IS the
  ;;                                 user-facing token — appropriate use,
  ;;                                 not flag-as-string drift.
  ;;   - Drift 9 (deferred-by-      All 7 arms bodied. Sub-LowExpr
  ;;                  omission):    recursion via $emit_lexpr — at this
  ;;                                 chunk's land, dispatcher knows tags
  ;;                                 300, 301, 302, 303, 305, 316-319,
  ;;                                 326, 327, 334. Other tags trap until
  ;;                                 chunks #5-#7 retrofit per
  ;;                                 Hβ.emit.lexpr-dispatch-extension
  ;;                                 named follow-up.
  ;;   - Foreign fluency:           Vocabulary stays Inka — "local",
  ;;                                "global", "slot", "upval", "state",
  ;;                                "field-load". NEVER "stack-frame" /
  ;;                                "lookup-table" / "register-window".
  ;;
  ;; Named follow-ups (per Drift 9 + Hβ-emit-substrate.md §10):
  ;;   - Hβ.emit.lexpr-dispatch-extension: chunks #5-#7 retrofit
  ;;                                       $emit_lexpr's arm table.
  ;;   - Hβ.emit.upval-state-substrate: LUpval's $__state local-name
  ;;                                    convention may evolve when chunk
  ;;                                    #7 emit_handler.wat lands the
  ;;                                    body-context boundary; for now
  ;;                                    seed mirrors wheel canonical.

  ;; ─── Chunk-private byte-emission helpers ──────────────────────────
  ;; Inline-byte design per emit_const.wat precedent — the [0, 4096)
  ;; data region is densely packed; inline $emit_byte sequences are
  ;; substrate-honest at the seed layer.

  (func $el_emit_local_get_dollar (param $name i32)
    ;; emits: (local.get $<name>)  — name is length-prefixed str_ptr
    (call $emit_byte (i32.const 40)) (call $emit_byte (i32.const 108))
    (call $emit_byte (i32.const 111)) (call $emit_byte (i32.const 99))
    (call $emit_byte (i32.const 97)) (call $emit_byte (i32.const 108))
    (call $emit_byte (i32.const 46)) (call $emit_byte (i32.const 103))
    (call $emit_byte (i32.const 101)) (call $emit_byte (i32.const 116))
    (call $emit_byte (i32.const 32)) (call $emit_byte (i32.const 36))
    (call $emit_str (local.get $name))
    (call $emit_byte (i32.const 41)))

  (func $el_emit_global_get_dollar (param $name i32)
    ;; emits: (global.get $<name>)
    (call $emit_byte (i32.const 40)) (call $emit_byte (i32.const 103))
    (call $emit_byte (i32.const 108)) (call $emit_byte (i32.const 111))
    (call $emit_byte (i32.const 98)) (call $emit_byte (i32.const 97))
    (call $emit_byte (i32.const 108)) (call $emit_byte (i32.const 46))
    (call $emit_byte (i32.const 103)) (call $emit_byte (i32.const 101))
    (call $emit_byte (i32.const 116)) (call $emit_byte (i32.const 32))
    (call $emit_byte (i32.const 36))
    (call $emit_str (local.get $name))
    (call $emit_byte (i32.const 41)))

  (func $el_emit_local_set_l_slot (param $slot i32)
    ;; emits: (local.set $l<slot>)  — wheel's slot-keyed local naming
    (call $emit_byte (i32.const 40)) (call $emit_byte (i32.const 108))
    (call $emit_byte (i32.const 111)) (call $emit_byte (i32.const 99))
    (call $emit_byte (i32.const 97)) (call $emit_byte (i32.const 108))
    (call $emit_byte (i32.const 46)) (call $emit_byte (i32.const 115))
    (call $emit_byte (i32.const 101)) (call $emit_byte (i32.const 116))
    (call $emit_byte (i32.const 32)) (call $emit_byte (i32.const 36))
    (call $emit_byte (i32.const 108))
    (call $emit_int (local.get $slot))
    (call $emit_byte (i32.const 41)))

  (func $el_emit_global_get_s_slot (param $slot i32)
    ;; emits: (global.get $s<slot>)  — state-machine globals
    (call $emit_byte (i32.const 40)) (call $emit_byte (i32.const 103))
    (call $emit_byte (i32.const 108)) (call $emit_byte (i32.const 111))
    (call $emit_byte (i32.const 98)) (call $emit_byte (i32.const 97))
    (call $emit_byte (i32.const 108)) (call $emit_byte (i32.const 46))
    (call $emit_byte (i32.const 103)) (call $emit_byte (i32.const 101))
    (call $emit_byte (i32.const 116)) (call $emit_byte (i32.const 32))
    (call $emit_byte (i32.const 36)) (call $emit_byte (i32.const 115))
    (call $emit_int (local.get $slot))
    (call $emit_byte (i32.const 41)))

  (func $el_emit_global_set_s_slot (param $slot i32)
    ;; emits: (global.set $s<slot>)
    (call $emit_byte (i32.const 40)) (call $emit_byte (i32.const 103))
    (call $emit_byte (i32.const 108)) (call $emit_byte (i32.const 111))
    (call $emit_byte (i32.const 98)) (call $emit_byte (i32.const 97))
    (call $emit_byte (i32.const 108)) (call $emit_byte (i32.const 46))
    (call $emit_byte (i32.const 115)) (call $emit_byte (i32.const 101))
    (call $emit_byte (i32.const 116)) (call $emit_byte (i32.const 32))
    (call $emit_byte (i32.const 36)) (call $emit_byte (i32.const 115))
    (call $emit_int (local.get $slot))
    (call $emit_byte (i32.const 41)))

  (func $el_emit_local_get_state
    ;; emits: (local.get $__state)  — W7 closure record's __state local
    (call $emit_byte (i32.const 40)) (call $emit_byte (i32.const 108))
    (call $emit_byte (i32.const 111)) (call $emit_byte (i32.const 99))
    (call $emit_byte (i32.const 97)) (call $emit_byte (i32.const 108))
    (call $emit_byte (i32.const 46)) (call $emit_byte (i32.const 103))
    (call $emit_byte (i32.const 101)) (call $emit_byte (i32.const 116))
    (call $emit_byte (i32.const 32)) (call $emit_byte (i32.const 36))
    (call $emit_byte (i32.const 95)) (call $emit_byte (i32.const 95))
    (call $emit_byte (i32.const 115)) (call $emit_byte (i32.const 116))
    (call $emit_byte (i32.const 97)) (call $emit_byte (i32.const 116))
    (call $emit_byte (i32.const 101)) (call $emit_byte (i32.const 41)))

  (func $el_emit_i32_load_offset (param $off i32)
    ;; emits: (i32.load offset=<off>)
    (call $emit_byte (i32.const 40)) (call $emit_byte (i32.const 105))
    (call $emit_byte (i32.const 51)) (call $emit_byte (i32.const 50))
    (call $emit_byte (i32.const 46)) (call $emit_byte (i32.const 108))
    (call $emit_byte (i32.const 111)) (call $emit_byte (i32.const 97))
    (call $emit_byte (i32.const 100)) (call $emit_byte (i32.const 32))
    (call $emit_byte (i32.const 111)) (call $emit_byte (i32.const 102))
    (call $emit_byte (i32.const 102)) (call $emit_byte (i32.const 115))
    (call $emit_byte (i32.const 101)) (call $emit_byte (i32.const 116))
    (call $emit_byte (i32.const 61))
    (call $emit_int (local.get $off))
    (call $emit_byte (i32.const 41)))

  ;; ─── $emit_llocal — LLocal tag 301 emit arm per §2.2 ───────────────
  ;; Per src/backends/wasm.nx:1146-1150. Reads name string via
  ;; $lexpr_llocal_name; emits "(local.get $<name>)".
  (func $emit_llocal (param $r i32)
    (call $el_emit_local_get_dollar
      (call $lexpr_llocal_name (local.get $r))))

  ;; ─── $emit_lglobal — LGlobal tag 302 emit arm per §2.2 ─────────────
  ;; Per src/backends/wasm.nx:1152-1156. Reads name via $lexpr_lglobal_name;
  ;; emits "(global.get $<name>)".
  (func $emit_lglobal (param $r i32)
    (call $el_emit_global_get_dollar
      (call $lexpr_lglobal_name (local.get $r))))

  ;; ─── $emit_lstore — LStore tag 303 emit arm per §2.2 ───────────────
  ;; Per src/backends/wasm.nx:1158-1163. Recurses on value via $emit_lexpr,
  ;; then emits "(local.set $l<slot>)".
  (func $emit_lstore (param $r i32)
    (call $emit_lexpr (call $lexpr_lstore_value (local.get $r)))
    (call $el_emit_local_set_l_slot (call $lexpr_lstore_slot (local.get $r))))

  ;; ─── $emit_lupval — LUpval tag 305 emit arm per §2.2 ───────────────
  ;; Per src/backends/wasm.nx:1172-1179. W7 closure record layout —
  ;; reads slot index via $lexpr_lupval_slot; emits
  ;;   (local.get $__state)
  ;;   (i32.load offset=<8 + 4*slot>)
  ;; H1.6 evidence reification cash-out: closure record IS the unified
  ;; __state; capture/upval access is offset arithmetic on the record.
  (func $emit_lupval (param $r i32)
    (call $el_emit_local_get_state)
    (call $el_emit_i32_load_offset
      (i32.add (i32.const 8)
        (i32.mul (i32.const 4)
                 (call $lexpr_lupval_slot (local.get $r))))))

  ;; ─── $emit_lstateget — LStateGet tag 326 emit arm per §2.2 ─────────
  ;; Per src/backends/wasm.nx:1501-1505. Reads slot via $lexpr_lstateget_slot;
  ;; emits "(global.get $s<slot>)".
  (func $emit_lstateget (param $r i32)
    (call $el_emit_global_get_s_slot
      (call $lexpr_lstateget_slot (local.get $r))))

  ;; ─── $emit_lstateset — LStateSet tag 327 emit arm per §2.2 ─────────
  ;; Per src/backends/wasm.nx:1507-1512. Recurses on value via $emit_lexpr,
  ;; then emits "(global.set $s<slot>)".
  (func $emit_lstateset (param $r i32)
    (call $emit_lexpr (call $lexpr_lstateset_value (local.get $r)))
    (call $el_emit_global_set_s_slot
      (call $lexpr_lstateset_slot (local.get $r))))

  ;; ─── $emit_lfieldload — LFieldLoad tag 334 emit arm per §2.2 ───────
  ;; Per src/backends/wasm.nx:1628-1633. Recurses on record-ptr via
  ;; $emit_lexpr, then emits "(i32.load offset=<offset_bytes>)".
  ;; H2 record substrate: field i lands at byte 4*i; offset_bytes is
  ;; pre-computed by Hβ.lower walk_compound's $lower_field arm.
  (func $emit_lfieldload (param $r i32)
    (call $emit_lexpr (call $lexpr_lfieldload_record (local.get $r)))
    (call $el_emit_i32_load_offset
      (call $lexpr_lfieldload_offset_bytes (local.get $r))))
