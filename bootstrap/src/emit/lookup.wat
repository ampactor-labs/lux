  ;; ═══ lookup.wat — Hβ.emit type-driven dispatch primitives (Tier 5) ═══
  ;; Implements: Hβ-emit-substrate.md §2.1 (LConst dispatch on Ty —
  ;;             TInt/TBool/TUnit/TError-hole arms reading $lookup_ty) +
  ;;             §2.4 (LCall reads TFun arity for $ftN signature; LSuspend
  ;;             same shape) + §3 (H1.4 single-handler-per-op naming —
  ;;             $emit_op_symbol concatenates "op_<name>") + §5.1 row
  ;;             (Type-driven dispatch IS the gradient cash-out site —
  ;;             this chunk provides the per-Ty primitives chunks #3-#7
  ;;             call before emitting WAT) + §11.3 dep order (this
  ;;             chunk follows #1 state.wat).
  ;; Exports:    $emit_wat_type_for, $emit_arity_of_tfun,
  ;;             $emit_is_terror_hole, $emit_op_symbol.
  ;; Uses:       $ty_tag + $ty_tfun_params (infer/ty.wat),
  ;;             $len (runtime/list.wat), $str_concat (runtime/str.wat).
  ;;
  ;; What this chunk IS (per Hβ-emit-substrate.md §2.1 + §2.4 + §3 +
  ;; wheel canonical src/backends/wasm.mn:773-789 emit_type_decls +
  ;; lines 444-475 collect_fn_names + per-Ty-tag dispatch shape per
  ;; emit_diag.wat:540-655 render_ty):
  ;;
  ;;   1. $emit_wat_type_for(ty) — UNIFORM i32 representation per
  ;;      DESIGN.md §0.5 "the heap has one story" + γ §IX. Closures,
  ;;      ADT variants, nominal records, strings, lists, tuples,
  ;;      refined types — ALL emit as i32 (pointers OR sentinels).
  ;;      The 14 Ty tags collapse to ONE WAT type at the seed layer.
  ;;      Future TFloat substrate gets per-tag-arm via the named
  ;;      follow-up Hβ.emit.float-substrate; not V1.
  ;;
  ;;   2. $emit_arity_of_tfun(ty) — read TFun's params list length via
  ;;      $ty_tfun_params + $len. Returns -1 if not TFun (caller
  ;;      treats as polymorphic / call_indirect $ftN unknown — the
  ;;      LSuspend H1.6 polymorphic-minority path). Used by chunk #6
  ;;      emit_call.wat to pick $ftN signature for direct call vs
  ;;      LSuspend's call_indirect.
  ;;
  ;;   3. $emit_is_terror_hole(ty) — i32.eq($ty_tag, 114) — the
  ;;      sentinel ty.wat reserves for unresolved/error types per
  ;;      Hβ-lower-substrate.md §1.1 + lower/lookup.wat:177-180. Used
  ;;      by every emit arm to short-circuit emission to (unreachable)
  ;;      preserving Hazel productive-under-error: the LowExpr lowered
  ;;      fine but its type is unresolved — emit a trap so downstream
  ;;      tools can flag, instead of silently emitting wrong WAT.
  ;;
  ;;   4. $emit_op_symbol(op_name) — concatenate "op_" + name per H1.4
  ;;      single-handler-per-op naming (Hβ-emit §3 + wheel
  ;;      src/backends/wasm.mn:583-619 emit_fn_table). Each handler arm
  ;;      becomes (func $op_<op_name> ...) at module level; this
  ;;      symbol IS the WAT identifier. Caller passes it to
  ;;      $emit_funcref_register (state.wat) for the funcref-table.
  ;;
  ;; Eight interrogations (per Hβ-emit-substrate.md §5.1 second pass):
  ;;
  ;;   1. Graph?       $emit_arity_of_tfun + $emit_is_terror_hole read
  ;;                   the Ty record/sentinel directly via $ty_tag —
  ;;                   the live-graph result of $lookup_ty (lower/
  ;;                   lookup.wat) the caller already chased. Per
  ;;                   Anchor 1 "ask the graph": these helpers ARE
  ;;                   that ask, projected onto Ty's record shape.
  ;;                   $emit_op_symbol does not touch graph; pure
  ;;                   string concatenation.
  ;;   2. Handler?     At wheel: $emit_wat_type_for is one arm of
  ;;                   render_ty-like dispatch; the wheel's
  ;;                   emit_type_decls (src/backends/wasm.mn:773-789)
  ;;                   composes via WasmOut effect (perform wat_emit).
  ;;                   At seed: direct fns; dispatch on $ty_tag.
  ;;                   @resume=OneShot at the wheel (read-only lookup).
  ;;   3. Verb?        N/A — type-driven dispatch is verb-silent; the
  ;;                   verb topology emerges in chunks #6 (emit_call)
  ;;                   + #7 (emit_handler) where these helpers are
  ;;                   composed into per-verb WAT-shape decisions.
  ;;   4. Row?         TFun's row is RETURNED via $ty_tfun_row but
  ;;                   THIS chunk doesn't read it — chunk #6
  ;;                   emit_call.wat reads it for the monomorphic-vs-
  ;;                   polymorphic gate. lookup.wat is row-traversal-
  ;;                   silent.
  ;;   5. Ownership?   $emit_op_symbol allocates new string via
  ;;                   $str_concat (bump heap); caller OWNs the result.
  ;;                   $emit_wat_type_for returns static data-segment
  ;;                   string ptr (no allocation). Other helpers
  ;;                   return raw i32 (no ownership transfer).
  ;;   6. Refinement?  TRefined transparent — chunk #6's monomorphic
  ;;                   gate would unwrap if needed. lookup currently
  ;;                   treats TRefined opaque (returns "i32" which is
  ;;                   correct for both base and refined, and -1 for
  ;;                   $emit_arity_of_tfun unless explicitly TFun).
  ;;   7. Gradient?    THIS IS THE TYPE-DRIVEN DISPATCH SUBSTRATE.
  ;;                   $emit_arity_of_tfun's TFun→arity gate IS the
  ;;                   gradient site: TFun → direct-call $ftN
  ;;                   (compile-time-known arity); non-TFun → -1 →
  ;;                   call_indirect (runtime-resolved). Per row
  ;;                   inference's >95% monomorphic claim — the
  ;;                   gradient cashes out at chunk #6 emit_call.wat
  ;;                   reading these helpers.
  ;;   8. Reason?      Read-only — caller's $lookup_ty preserves
  ;;                   Reason chain on the handle. lookup.wat does
  ;;                   not write Reasons; downstream Mentl-Why
  ;;                   (Arc F.6) walks back via $gnode_reason on the
  ;;                   handle the LowExpr carries.
  ;;
  ;; Forbidden patterns audited (per Hβ-emit-substrate.md §6 + project
  ;; drift modes):
  ;;
  ;;   - Drift 1 (Rust vtable):     $emit_arity_of_tfun is direct ty-
  ;;                                tag dispatch (i32.eq + return); NO
  ;;                                $arity_table data segment / NO
  ;;                                _lookup_arity_handler function.
  ;;                                Word "vtable" appears nowhere.
  ;;   - Drift 5 (C calling conv):  No threaded __closure or __ev
  ;;                                params; helpers take Ty/handle/
  ;;                                str_ptr directly.
  ;;   - Drift 8 (string-keyed):    Tag dispatch via i32.eq on integer
  ;;                                tag constants (107 = TFun, 114 =
  ;;                                TError-hole). NEVER `str_eq(name,
  ;;                                "TFun")` ADT-as-string fluency.
  ;;   - Drift 9 (deferred-by-     Every export bodied; no stubs.
  ;;                  omission):    Max-arity-precise-walk is the
  ;;                                NAMED follow-up Hβ.emit.max-arity-
  ;;                                precise-walk (lands with chunk #9
  ;;                                main.wat or as separate helper) —
  ;;                                NAMED, not silently omitted from
  ;;                                this chunk.
  ;;   - Foreign fluency:           Vocabulary stays Mentl — "type",
  ;;                                "arity", "symbol", "tag dispatch".
  ;;                                NEVER "type-of" / "lookup-table" /
  ;;                                "name-mangle."
  ;;
  ;; Named follow-ups (per Drift 9 + Hβ-emit-substrate.md §10):
  ;;   - Hβ.emit.float-substrate: $emit_wat_type_for grows per-tag arm
  ;;                              for TFloat (101) → "f64" string ptr;
  ;;                              gates DSP / ML / numerical crucibles.
  ;;   - Hβ.emit.max-arity-precise-walk: max_arity_in(stmts) + 35-arm
  ;;                              max_arity_expr per wheel src/backends/
  ;;                              wasm.mn:730-769; lands with chunk #9
  ;;                              main.wat or separate helper.
  ;;
  ;; Static data — WAT type tokens (offsets 488-503; emit-private
  ;; region within [481, 512) free zone after lexer_data.wat keywords;
  ;; HEAP_BASE=4096 keeps these <HEAP_BASE; pointers stay disambiguable
  ;; from sentinels [0, HEAP_BASE)):
  ;;   488 — "i32" (3 bytes; the uniform WAT type for the seed)
  ;;   496 — "op_" (3 bytes; H1.4 prefix per wheel emit_fn_table)

  (data (i32.const 488) "\03\00\00\00i32")
  (data (i32.const 496) "\03\00\00\00op_")

  ;; ─── $emit_wat_type_for — UNIFORM i32 for any Ty (seed default) ───
  ;; Per DESIGN.md §0.5 "the heap has one story" + γ §IX. The 14 Ty
  ;; tags (100-113) all return "i32" string ptr (offset 488). Future
  ;; TFloat substrate gets per-tag-arm via Hβ.emit.float-substrate
  ;; follow-up; not V1.
  (func $emit_wat_type_for (param $ty i32) (result i32)
    (i32.const 488))

  ;; ─── $emit_arity_of_tfun — TFun's params list length, or -1 ──────
  ;; Per Hβ-emit-substrate.md §2.4 + wheel src/backends/wasm.mn:773-789.
  ;; Used by chunk #6 emit_call.wat to pick $ftN signature for LCall
  ;; (monomorphic) vs LSuspend's call_indirect (polymorphic).
  (func $emit_arity_of_tfun (param $ty i32) (result i32)
    (if (i32.ne (call $ty_tag (local.get $ty)) (i32.const 107))
      (then (return (i32.const -1))))
    (call $len (call $ty_tfun_params (local.get $ty))))

  ;; ─── $emit_is_terror_hole — sentinel for unresolved type ──────────
  ;; Per Hβ-lower-substrate.md §1.1 + lower/lookup.wat:177-180. Used
  ;; by every emit arm to short-circuit emission to (unreachable) per
  ;; Hazel productive-under-error.
  (func $emit_is_terror_hole (param $ty i32) (result i32)
    (i32.eq (call $ty_tag (local.get $ty)) (i32.const 114)))

  ;; ─── $emit_op_symbol — "op_" + name per H1.4 single-handler-per-op ─
  ;; Per Hβ-emit-substrate.md §3 + wheel src/backends/wasm.mn:583-619.
  ;; Caller passes result to $emit_funcref_register (state.wat) for the
  ;; funcref-table.
  (func $emit_op_symbol (param $op_name i32) (result i32)
    (call $str_concat (i32.const 496) (local.get $op_name)))
