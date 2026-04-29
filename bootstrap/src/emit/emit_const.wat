  ;; ═══ emit_const.wat — Hβ.emit const-family literal arm (Tier 6) ═══
  ;; Implements: Hβ-emit-substrate.md §2.1 (LConst tag 300 — Ty-tag
  ;;             dispatch on $lookup_ty($lexpr_handle(r))) + §3.5
  ;;             (EmitMemory swap surface — emission routes through
  ;;             emit_infra; substrate-level reference) + §5.1 (eight
  ;;             interrogations at dispatcher) + §7.1 (chunk file
  ;;             layout — chunk #3) + §11.3 dep order (chunk #3
  ;;             follows lookup.wat).
  ;; Exports:    $emit_lconst.
  ;; Uses:       $lexpr_handle + $lexpr_lconst_value (lower/lexpr.wat),
  ;;             $lookup_ty (lower/lookup.wat),
  ;;             $emit_is_terror_hole (emit/lookup.wat),
  ;;             $emit_string_intern (emit/state.wat),
  ;;             $ty_tag (infer/ty.wat),
  ;;             $emit_byte + $emit_str + $emit_i32_const +
  ;;             $emit_open + $emit_close (emit_infra.wat).
  ;;
  ;; What this chunk IS (per Hβ-emit-substrate.md §2.1 + wheel canonical
  ;; src/backends/wasm.nx LConst arm shape):
  ;;
  ;;   $emit_lconst(r) reads:
  ;;     - value via $lexpr_lconst_value(r)              [opaque i32]
  ;;     - handle via $lexpr_handle(r)                   [graph node]
  ;;     - ty via $lookup_ty(handle)                     [live read]
  ;;
  ;;   then dispatches on $ty_tag(ty):
  ;;     - 100 (TInt)            → "(i32.const <value>)"
  ;;     - 102 (TString)         → "(i32.const <intern_offset>)"
  ;;                               where intern_offset =
  ;;                               $emit_string_intern(value_as_str_ptr)
  ;;     - 103 (TUnit)           → "(i32.const 0)" (sentinel)
  ;;     - 114 (TError-hole)     → "(unreachable)"  (Hazel productive-
  ;;                               under-error: type unresolved → trap)
  ;;     - other tags            → "(i32.const <value>)" (uniform i32
  ;;                               fall-through; works for TBool ADT
  ;;                               variant tag_id 0/1 + nullary variant
  ;;                               sentinels per HB drift-6 closure;
  ;;                               TFloat handled per Hβ.emit.float-
  ;;                               substrate follow-up — value is opaque
  ;;                               i32 currently per LowValue pass-
  ;;                               through chunk #6 walk_const Lock #4)
  ;;
  ;; This chunk's first commit lands $emit_lconst ONLY. The LMake*
  ;; arms ($emit_lmakevariant / $emit_lmaketuple / $emit_lmakelist /
  ;; $emit_lmakerecord) + the introduction of $emit_lexpr partial
  ;; dispatcher land in named peer commit Hβ.emit.const-make-arms,
  ;; mirroring Hβ.lower's walk_call.wat (chunk #7) precedent where
  ;; the dispatcher arrives with the FIRST chunk that needs to recurse.
  ;; LConst has no sub-LowExprs (just opaque-value + handle), so it
  ;; lands cleanly without the dispatcher.
  ;;
  ;; Eight interrogations (per Hβ-emit-substrate.md §5.1 second pass):
  ;;
  ;;   1. Graph?       $lookup_ty(handle) IS the live graph read per
  ;;                   Anchor 1 — chunk #2 lookup.wat's primitives
  ;;                   compose here. The graph populated by $inka_infer
  ;;                   carries the Ty bindings; emit-time chunk reads
  ;;                   them at-emission to drive dispatch.
  ;;   2. Handler?     At wheel: emit_lconst is one arm of an Emit
  ;;                   effect-projection (perform wat_emit) per
  ;;                   src/backends/wasm.nx. At seed: direct call to
  ;;                   emit_infra primitives. @resume=OneShot at the
  ;;                   wheel (single-pass emission).
  ;;   3. Verb?        N/A at expression level — LConst draws no verb
  ;;                   topology; verbs emerge in the LCall (`|>`) /
  ;;                   LMakeTuple-of-LCalls (`<|`) / LHandleWith (`~>`)
  ;;                   chunks #6-#7.
  ;;   4. Row?         EfPure for the type read via $lookup_ty (it
  ;;                   reads-only; row not consulted). Side-effect on
  ;;                   the emit output buffer through $emit_byte's
  ;;                   global $out_pos/$out_base.
  ;;   5. Ownership?   $emit_string_intern allocates STRING_INTERN_ENTRY
  ;;                   per first-occurrence per state.wat:295-323; OWN
  ;;                   by emit pass program-wide. Buffer bytes OWNed by
  ;;                   the emit pass; flushed at end of emit_program.
  ;;   6. Refinement?  TRefined transparent — $ty_tag would return
  ;;                   refined-ty's tag (113 in seed); fall-through arm
  ;;                   emits uniform "(i32.const value)" which is
  ;;                   correct for any pointer/sentinel value.
  ;;   7. Gradient?    Compile-time-known type → compile-time-known
  ;;                   emission shape. The gradient cashes out HERE per
  ;;                   row inference's monomorphic claim: every LConst
  ;;                   handle has a resolved type at emit time (inferer
  ;;                   bound it), so $ty_tag dispatch is direct, no
  ;;                   runtime branching.
  ;;   8. Reason?      $lookup_ty preserves Reason via $graph_chase;
  ;;                   downstream Mentl-Why walks back via
  ;;                   $gnode_reason on the LowExpr's handle. This
  ;;                   chunk does not write Reasons.
  ;;
  ;; Forbidden patterns audited (per Hβ-emit-substrate.md §6 + project
  ;; drift modes):
  ;;
  ;;   - Drift 1 (Rust vtable):     Direct ty-tag dispatch via i32.eq
  ;;                                + per-arm body. NO $ty_emit_table
  ;;                                data segment / NO _lookup_emit_for_ty
  ;;                                fn. Word "vtable" appears nowhere.
  ;;   - Drift 5 (C calling conv):  $emit_lconst takes a single LowExpr
  ;;                                ref (i32 ptr); no separate __closure
  ;;                                /__ev params.
  ;;   - Drift 6 (Bool special):    No special-case for TBool — Bool is
  ;;                                an ADT variant per HB substrate
  ;;                                (drift-6 closure); LMakeVariant
  ;;                                handles its emission. Fall-through
  ;;                                here covers nullary-variant tag_id
  ;;                                values (0/1 for true/false) via the
  ;;                                uniform-i32 path.
  ;;   - Drift 8 (string-keyed):    Tag dispatch via i32.eq on integer
  ;;                                tag constants (100/102/103/114).
  ;;                                NEVER `str_eq($render_ty(ty), "TInt")`
  ;;                                fluency.
  ;;   - Drift 9 (deferred-by-     LConst arm fully bodied. LMake* arms
  ;;                  omission):    NAMED in peer follow-up Hβ.emit.
  ;;                                const-make-arms (drift-9 closure
  ;;                                via explicit naming, not silent
  ;;                                omission).
  ;;   - Foreign fluency:           Vocabulary stays Inka — "tag",
  ;;                                "dispatch", "intern", "sentinel".
  ;;                                NEVER "switch-statement" / "lookup-
  ;;                                table" / "emit-strategy."
  ;;
  ;; Named follow-ups (per Drift 9):
  ;;   - Hβ.emit.const-make-arms: $emit_lmakevariant / $emit_lmaketuple
  ;;                              / $emit_lmakelist / $emit_lmakerecord
  ;;                              + introduction of $emit_lexpr partial
  ;;                              dispatcher (Hβ.lower walk_call.wat
  ;;                              precedent — dispatcher arrives with
  ;;                              first recursion-needing chunk).
  ;;                              Subsequent emit chunks #4-#7 RETROFIT
  ;;                              the dispatcher via Edit.
  ;;   - Hβ.emit.float-substrate: TFloat→"(f64.const ...)" per-tag arm;
  ;;                              gates DSP/ML/numerical crucibles.
  ;;
  ;; Static data — emitted-WAT tokens (offset 1520; in [1518, 1600) free
  ;; gap surfaced by data-offset audit — sits after emit_data.wat's
  ;; " (export \"_start\")" at 1500-1517 + before infer/emit_diag's
  ;; "ERROR_DEEP_CHASE" at 1600). Length-prefixed for $emit_open via
  ;; $emit_str; emit-private to this chunk:
  ;;   1520 — "unreachable" (4-byte length prefix + 11-byte body = 15
  ;;          bytes; emitted with parens via $emit_open + $emit_close
  ;;          for TError-hole arm)

  (data (i32.const 1520) "\0b\00\00\00unreachable")

  ;; ─── $ec_emit_unreachable — chunk-private helper ──────────────────
  ;; Emits "(unreachable)" via $emit_open on the static string +
  ;; $emit_close per H1.4 emission discipline. Used by $emit_lconst's
  ;; TError-hole arm.
  (func $ec_emit_unreachable
    (call $emit_open (i32.const 1520))
    (call $emit_close))

  ;; ─── $emit_lconst — LConst tag 300 emit arm per Hβ-emit §2.1 ─────
  ;; Reads value + handle from LowExpr; reads ty via $lookup_ty;
  ;; dispatches per ty tag → emits canonical WAT literal expression
  ;; via emit_infra primitives.
  (func $emit_lconst (param $r i32)
    (local $value i32) (local $h i32) (local $ty i32) (local $ty_tag_v i32)
    (local.set $value (call $lexpr_lconst_value (local.get $r)))
    (local.set $h     (call $lexpr_handle      (local.get $r)))
    (local.set $ty    (call $lookup_ty         (local.get $h)))

    ;; TError-hole (114) → "(unreachable)" — Hazel productive-under-error.
    (if (call $emit_is_terror_hole (local.get $ty))
      (then (call $ec_emit_unreachable) (return)))

    (local.set $ty_tag_v (call $ty_tag (local.get $ty)))

    ;; TString (102) → intern + emit "(i32.const <offset>)".
    (if (i32.eq (local.get $ty_tag_v) (i32.const 102))
      (then
        (call $emit_i32_const
          (call $emit_string_intern (local.get $value)))
        (return)))

    ;; TUnit (103) → "(i32.const 0)" sentinel per uniform-i32 discipline.
    (if (i32.eq (local.get $ty_tag_v) (i32.const 103))
      (then (call $emit_i32_const (i32.const 0)) (return)))

    ;; TInt (100) AND fall-through (TBool variant tag_id, nullary
    ;; variants, TFloat-as-int per follow-up, etc.) → "(i32.const <value>)".
    ;; The uniform-i32 emission per DESIGN.md §0.5 "the heap has one
    ;; story" + γ §IX: every value at the seed layer IS an i32, so
    ;; emitting (i32.const N) round-trips for any ground value.
    (call $emit_i32_const (local.get $value)))

  ;; ════════════════════════════════════════════════════════════════════
  ;; ═══ Hβ.emit.const-make-arms (peer landing) ═════════════════════════
  ;; ════════════════════════════════════════════════════════════════════
  ;; Per Hβ-emit-substrate.md §2.1 closure of the 5-arm Const family:
  ;; LMakeList tag 316 + LMakeTuple tag 317 + LMakeRecord tag 318 +
  ;; LMakeVariant tag 319 emit arms + $emit_lexpr partial dispatcher
  ;; (forward-decl bridge per Hβ.lower walk_call.wat:254-358 precedent;
  ;; chunks #4-#7 retrofit via Edit per named follow-up
  ;; Hβ.emit.lexpr-dispatch-extension) + $emit_alloc EmitMemory swap
  ;; surface entry (§3.5 substrate-level handler reference; future
  ;; arena/gc swaps replace fn body via Hβ.emit.memory-arena-handler /
  ;; Hβ.emit.memory-gc-handler).
  ;;
  ;; HB drift-6 closure: LMakeVariant nullary path emits (i32.const tag_id)
  ;; sentinel — Bool/Nothing/Up/Down/etc. ALL nullary ADTs compile to
  ;; their tag_id. Fielded variants heap-allocate via $emit_alloc.

  ;; ─── Chunk-private byte-emission helpers (no static data) ─────────
  ;; Inline-byte design decision (data-offset audit re-check, 2026-04-29):
  ;; the [0, 4096) sentinel/data region is densely packed by lexer/
  ;; parser/runtime/infer/lower/emit_data static segments; the largest
  ;; verified-free contiguous gap below HEAP_BASE is [1535, 1599) =
  ;; 65 bytes — insufficient for the ~180 bytes of length-prefixed
  ;; emit-tokens needed by $emit_alloc + LMake* arms. Inline byte
  ;; emission via $emit_byte sequences is the substrate-honest path:
  ;; the function body IS the swap surface (§3.5.1), so encoding the
  ;; bump pattern as direct byte calls preserves the EmitMemory handler
  ;; abstraction without requiring static-data infrastructure.

  (func $ec_emit_global_get_heap_ptr
    ;; emits: (global.get $heap_ptr)
    (call $emit_byte (i32.const 40)) (call $emit_byte (i32.const 103))
    (call $emit_byte (i32.const 108)) (call $emit_byte (i32.const 111))
    (call $emit_byte (i32.const 98))  (call $emit_byte (i32.const 97))
    (call $emit_byte (i32.const 108)) (call $emit_byte (i32.const 46))
    (call $emit_byte (i32.const 103)) (call $emit_byte (i32.const 101))
    (call $emit_byte (i32.const 116)) (call $emit_byte (i32.const 32))
    (call $emit_byte (i32.const 36))  (call $emit_byte (i32.const 104))
    (call $emit_byte (i32.const 101)) (call $emit_byte (i32.const 97))
    (call $emit_byte (i32.const 112)) (call $emit_byte (i32.const 95))
    (call $emit_byte (i32.const 112)) (call $emit_byte (i32.const 116))
    (call $emit_byte (i32.const 114)) (call $emit_byte (i32.const 41)))

  (func $ec_emit_global_set_heap_ptr
    ;; emits: (global.set $heap_ptr)
    (call $emit_byte (i32.const 40)) (call $emit_byte (i32.const 103))
    (call $emit_byte (i32.const 108)) (call $emit_byte (i32.const 111))
    (call $emit_byte (i32.const 98))  (call $emit_byte (i32.const 97))
    (call $emit_byte (i32.const 108)) (call $emit_byte (i32.const 46))
    (call $emit_byte (i32.const 115)) (call $emit_byte (i32.const 101))
    (call $emit_byte (i32.const 116)) (call $emit_byte (i32.const 32))
    (call $emit_byte (i32.const 36))  (call $emit_byte (i32.const 104))
    (call $emit_byte (i32.const 101)) (call $emit_byte (i32.const 97))
    (call $emit_byte (i32.const 112)) (call $emit_byte (i32.const 95))
    (call $emit_byte (i32.const 112)) (call $emit_byte (i32.const 116))
    (call $emit_byte (i32.const 114)) (call $emit_byte (i32.const 41)))

  (func $ec_emit_local_set_dollar (param $name i32)
    ;; emits: (local.set $<name>)  — name is length-prefixed str_ptr
    (call $emit_byte (i32.const 40)) (call $emit_byte (i32.const 108))
    (call $emit_byte (i32.const 111)) (call $emit_byte (i32.const 99))
    (call $emit_byte (i32.const 97)) (call $emit_byte (i32.const 108))
    (call $emit_byte (i32.const 46)) (call $emit_byte (i32.const 115))
    (call $emit_byte (i32.const 101)) (call $emit_byte (i32.const 116))
    (call $emit_byte (i32.const 32)) (call $emit_byte (i32.const 36))
    (call $emit_str (local.get $name))
    (call $emit_byte (i32.const 41)))

  (func $ec_emit_local_get_dollar (param $name i32)
    ;; emits: (local.get $<name>)
    (call $emit_byte (i32.const 40)) (call $emit_byte (i32.const 108))
    (call $emit_byte (i32.const 111)) (call $emit_byte (i32.const 99))
    (call $emit_byte (i32.const 97)) (call $emit_byte (i32.const 108))
    (call $emit_byte (i32.const 46)) (call $emit_byte (i32.const 103))
    (call $emit_byte (i32.const 101)) (call $emit_byte (i32.const 116))
    (call $emit_byte (i32.const 32)) (call $emit_byte (i32.const 36))
    (call $emit_str (local.get $name))
    (call $emit_byte (i32.const 41)))

  (func $ec_emit_i32_add
    ;; emits: (i32.add)
    (call $emit_byte (i32.const 40)) (call $emit_byte (i32.const 105))
    (call $emit_byte (i32.const 51)) (call $emit_byte (i32.const 50))
    (call $emit_byte (i32.const 46)) (call $emit_byte (i32.const 97))
    (call $emit_byte (i32.const 100)) (call $emit_byte (i32.const 100))
    (call $emit_byte (i32.const 41)))

  (func $ec_emit_i32_store_offset (param $off i32)
    ;; emits: (i32.store offset=<off>)
    (call $emit_byte (i32.const 40)) (call $emit_byte (i32.const 105))
    (call $emit_byte (i32.const 51)) (call $emit_byte (i32.const 50))
    (call $emit_byte (i32.const 46)) (call $emit_byte (i32.const 115))
    (call $emit_byte (i32.const 116)) (call $emit_byte (i32.const 111))
    (call $emit_byte (i32.const 114)) (call $emit_byte (i32.const 101))
    (call $emit_byte (i32.const 32)) (call $emit_byte (i32.const 111))
    (call $emit_byte (i32.const 102)) (call $emit_byte (i32.const 102))
    (call $emit_byte (i32.const 115)) (call $emit_byte (i32.const 101))
    (call $emit_byte (i32.const 116)) (call $emit_byte (i32.const 61))
    (call $emit_int (local.get $off))
    (call $emit_byte (i32.const 41)))

  (func $ec_emit_call_make_list
    ;; emits: (call $make_list)
    (call $emit_byte (i32.const 40)) (call $emit_byte (i32.const 99))
    (call $emit_byte (i32.const 97)) (call $emit_byte (i32.const 108))
    (call $emit_byte (i32.const 108)) (call $emit_byte (i32.const 32))
    (call $emit_byte (i32.const 36)) (call $emit_byte (i32.const 109))
    (call $emit_byte (i32.const 97)) (call $emit_byte (i32.const 107))
    (call $emit_byte (i32.const 101)) (call $emit_byte (i32.const 95))
    (call $emit_byte (i32.const 108)) (call $emit_byte (i32.const 105))
    (call $emit_byte (i32.const 115)) (call $emit_byte (i32.const 116))
    (call $emit_byte (i32.const 41)))

  (func $ec_emit_call_list_set
    ;; emits: (call $list_set)
    (call $emit_byte (i32.const 40)) (call $emit_byte (i32.const 99))
    (call $emit_byte (i32.const 97)) (call $emit_byte (i32.const 108))
    (call $emit_byte (i32.const 108)) (call $emit_byte (i32.const 32))
    (call $emit_byte (i32.const 36)) (call $emit_byte (i32.const 108))
    (call $emit_byte (i32.const 105)) (call $emit_byte (i32.const 115))
    (call $emit_byte (i32.const 116)) (call $emit_byte (i32.const 95))
    (call $emit_byte (i32.const 115)) (call $emit_byte (i32.const 101))
    (call $emit_byte (i32.const 116)) (call $emit_byte (i32.const 41)))

  ;; ─── Tmp-name length-prefixed strings (variable interpolation) ────
  ;; Three local-name strings used as $emit_alloc's $target arg; live
  ;; in [1535, 1599) verified-free zone. 4-byte aligned where possible.
  ;;   1536 — "tuple_tmp"   (9 chars; 4+9=13 bytes; 1536-1548)
  ;;   1552 — "record_tmp"  (10 chars; 4+10=14 bytes; 1552-1565)
  ;;   1568 — "variant_tmp" (11 chars; 4+11=15 bytes; 1568-1582)

  (data (i32.const 1536) "\09\00\00\00tuple_tmp")
  (data (i32.const 1552) "\0a\00\00\00record_tmp")
  (data (i32.const 1568) "\0b\00\00\00variant_tmp")

  ;; ─── $emit_alloc — bump-pattern emitter (EmitMemory swap surface) ─
  ;; Per Hβ-emit-substrate.md §3.5 + wheel canonical src/backends/wasm.nx:
  ;; 71-84 emit_memory_bump body. Emits the 5-piece WAT sequence that
  ;; allocates `$size` bytes at $heap_ptr and binds the resulting ptr to
  ;; local `$<target>`. THIS IS the substrate-level handler reference
  ;; per §3.5.1 — future arena/gc handlers swap this body without
  ;; disturbing call sites (Anchor 5: every feature is a handler).
  ;;
  ;; Eight interrogations:
  ;;   Graph?      Reads $size + $target str_ptr (no graph mutation).
  ;;   Handler?    @resume=OneShot at wheel; direct call at seed.
  ;;   Verb?       |> — emit globals-read |> emit-add |> emit-store.
  ;;   Row?        EmitMemory at wheel; row-silent at seed.
  ;;   Ownership?  $out_base buffer OWNed program-wide.
  ;;   Refinement? N/A.
  ;;   Gradient?   The handler-swap surface IS the gradient (post-L1
  ;;               arena/gc).
  ;;   Reason?     N/A — emission preserves source-handle Reason chain
  ;;               via $lookup_ty reads upstream.
  ;;
  ;; Drift refusals:
  ;;   - Drift 1 (vtable): NO global $emit_alloc_handler closure record;
  ;;     direct fn body. Future swap is one fn-body Edit, not a vtable.
  ;;   - Drift 5 (C calling conv): single (size, target) i32 pair; no
  ;;     __closure/__ev split.
  ;;   - Drift 9 (deferred-by-omission): full bump pattern bodied;
  ;;     arena/gc swap NAMED follow-up Hβ.emit.memory-arena-handler /
  ;;     Hβ.emit.memory-gc-handler.
  (func $emit_alloc (param $size i32) (param $target i32)
    (call $ec_emit_global_get_heap_ptr)
    (call $ec_emit_local_set_dollar (local.get $target))
    (call $ec_emit_global_get_heap_ptr)
    (call $emit_i32_const (local.get $size))
    (call $ec_emit_i32_add)
    (call $ec_emit_global_set_heap_ptr))

  ;; ─── $emit_alloc_dyn — bump-pattern with runtime-computed size ────
  ;; Per Hβ-emit-substrate.md §3.5 + wheel canonical "emit_alloc with
  ;; dynamic size: route through emit_alloc_dyn (variant of emit_alloc
  ;; taking i32 from local.get $<size_local>)" (src/backends/wasm.nx:
  ;; 1423-1424). Emits the 5-piece bump-pattern reading $size from a
  ;; named local instead of a static-int constant. Used at LSuspend
  ;; (chunk #6 emit_call.wat) where the transient closure record's
  ;; size is `8 + 4*nc + 4*ne` and `nc` (callee_closure capture count)
  ;; is only knowable at runtime via i32.load offset=4 of the callee
  ;; closure ptr.
  ;;
  ;; Same EmitMemory swap surface — future arena/gc handlers swap this
  ;; fn body alongside $emit_alloc.
  ;;
  ;; Drift 1 refusal: NO global $emit_alloc_dyn_handler closure record;
  ;; direct fn body. Drift 9 refusal: bump pattern fully bodied; arena/
  ;; gc swap is named follow-up Hβ.emit.memory-arena-handler /
  ;; Hβ.emit.memory-gc-handler at the same swap surface.
  (func $emit_alloc_dyn (param $size_local i32) (param $target i32)
    (call $ec_emit_global_get_heap_ptr)
    (call $ec_emit_local_set_dollar (local.get $target))
    (call $ec_emit_global_get_heap_ptr)
    (call $ec_emit_local_get_dollar (local.get $size_local))
    (call $ec_emit_i32_add)
    (call $ec_emit_global_set_heap_ptr))

  ;; ─── $emit_lmakelist — LMakeList tag 316 emit arm per §2.1 ─────────
  ;; Per src/backends/wasm.nx:2068-2098 emit_list_literal. Emits:
  ;;   (i32.const N) (call $make_list) (i32.const 0) <elem 0> (call $list_set)
  ;;   (i32.const 1) <elem 1> (call $list_set) ... etc.
  ;; list_set returns the list ptr per runtime/list.wat — pointer threads
  ;; on stack through successive stores; result is the list ptr (O(1)
  ;; indexable via list_index@tag=0).
  ;;
  ;; Recursion via $emit_lexpr — at this peer landing, dispatcher knows
  ;; LConst (300) + LMake* (316-319). Other elem-tags trap until
  ;; chunks #4-#7 retrofit per Hβ.emit.lexpr-dispatch-extension.
  ;;
  ;; Drift 7 refusal: elems is ONE list ptr field (record-shaped); not
  ;; parallel keys-ptr + counts-ptr arrays.
  (func $emit_lmakelist (param $r i32)
    (local $elems i32) (local $n i32) (local $i i32) (local $elem i32)
    (local.set $elems (call $lexpr_lmakelist_elems (local.get $r)))
    (local.set $n     (call $len (local.get $elems)))
    (call $emit_i32_const (local.get $n))
    (call $ec_emit_call_make_list)
    (local.set $i (i32.const 0))
    (block $done
      (loop $store_loop
        (br_if $done (i32.ge_u (local.get $i) (local.get $n)))
        (local.set $elem (call $list_index (local.get $elems) (local.get $i)))
        (call $emit_i32_const (local.get $i))
        (call $emit_lexpr (local.get $elem))
        (call $ec_emit_call_list_set)
        (local.set $i (i32.add (local.get $i) (i32.const 1)))
        (br $store_loop))))

  ;; ─── $emit_lmaketuple — LMakeTuple tag 317 emit arm per §2.1 ───────
  ;; Mirrors LMakeRecord shape (no tag word, fields at 4*i offset) per
  ;; wheel emit_record_field_stores (src/backends/wasm.nx:1810-1823).
  ;; Wheel's emit_tuple_literal uses $alloc_tuple call-style — seed
  ;; transcription unifies with LMakeRecord pattern; named follow-up
  ;; Hβ.emit.tuple-alloc-helper resolves wheel-vs-seed alignment if a
  ;; downstream consumer needs the call-style.
  ;;
  ;; Emits: $emit_alloc(N*4, "tuple_tmp")
  ;;        per i: (local.get $tuple_tmp) <elem_i> (i32.store offset=4*i)
  ;;        (local.get $tuple_tmp)  ;; result on stack
  (func $emit_lmaketuple (param $r i32)
    (local $elems i32) (local $n i32) (local $i i32) (local $elem i32)
    (local.set $elems (call $lexpr_lmaketuple_elems (local.get $r)))
    (local.set $n     (call $len (local.get $elems)))
    (call $emit_alloc (i32.mul (local.get $n) (i32.const 4))
                      (i32.const 1536))                   ;; "tuple_tmp"
    (local.set $i (i32.const 0))
    (block $done
      (loop $store_loop
        (br_if $done (i32.ge_u (local.get $i) (local.get $n)))
        (local.set $elem (call $list_index (local.get $elems) (local.get $i)))
        (call $ec_emit_local_get_dollar (i32.const 1536))
        (call $emit_lexpr (local.get $elem))
        (call $ec_emit_i32_store_offset (i32.mul (local.get $i) (i32.const 4)))
        (local.set $i (i32.add (local.get $i) (i32.const 1)))
        (br $store_loop)))
    (call $ec_emit_local_get_dollar (i32.const 1536)))

  ;; ─── $emit_lmakerecord — LMakeRecord tag 318 emit arm per §2.1 ─────
  ;; Per src/backends/wasm.nx:1343-1354 + 1810-1823 emit_record_field_stores.
  ;; Mirror of $emit_lmaketuple; only delta is the local name. H2
  ;; substrate: records carry identity in the type system, no runtime
  ;; tag. Field i lands at byte 4*i — matches LFieldLoad's offset
  ;; arithmetic in lower.nx.
  (func $emit_lmakerecord (param $r i32)
    (local $fields i32) (local $n i32) (local $i i32) (local $field i32)
    (local.set $fields (call $lexpr_lmakerecord_fields (local.get $r)))
    (local.set $n      (call $len (local.get $fields)))
    (call $emit_alloc (i32.mul (local.get $n) (i32.const 4))
                      (i32.const 1552))                   ;; "record_tmp"
    (local.set $i (i32.const 0))
    (block $done
      (loop $store_loop
        (br_if $done (i32.ge_u (local.get $i) (local.get $n)))
        (local.set $field (call $list_index (local.get $fields) (local.get $i)))
        (call $ec_emit_local_get_dollar (i32.const 1552))
        (call $emit_lexpr (local.get $field))
        (call $ec_emit_i32_store_offset (i32.mul (local.get $i) (i32.const 4)))
        (local.set $i (i32.add (local.get $i) (i32.const 1)))
        (br $store_loop)))
    (call $ec_emit_local_get_dollar (i32.const 1552)))

  ;; ─── $emit_lmakevariant — LMakeVariant tag 319 emit arm per §2.1 ───
  ;; Per src/backends/wasm.nx:1356-1388 + HB drift-6 closure:
  ;; - n == 0 → (i32.const tag_id) sentinel  (Bool/Nothing/Up/Down/etc.)
  ;; - n >  0 → $emit_alloc(4 + 4*n, "variant_tmp")
  ;;            (local.get $variant_tmp) (i32.const tag_id) (i32.store offset=0)
  ;;            per i: (local.get $variant_tmp) <field_i> (i32.store offset=4+4*i)
  ;;            (local.get $variant_tmp)   ;; result on stack
  ;;
  ;; THE GRADIENT CASH-OUT — Bool is not special. Every nullary ADT
  ;; variant compiles to its tag_id sentinel; fielded variants heap-
  ;; allocate via the EmitMemory swap surface. Drift 6 refusal: NO
  ;; `if str_eq(name, "Bool")` Bool-narrow branch.
  ;;
  ;; HEAP_BASE invariant: nullary tag_ids ∈ [0, 4096) sit in sentinel
  ;; region; fielded variants heap-allocate at $heap_ptr ≥ 1 MiB. The
  ;; threshold check `(scrut < HEAP_BASE)` at LMatch (post-L1) cleanly
  ;; discriminates without ambiguity per HB substrate.
  (func $emit_lmakevariant (param $r i32)
    (local $tag_id i32) (local $args i32) (local $n i32) (local $i i32)
    (local $arg i32)
    (local.set $tag_id (call $lexpr_lmakevariant_tag_id (local.get $r)))
    (local.set $args   (call $lexpr_lmakevariant_args   (local.get $r)))
    (local.set $n      (call $len (local.get $args)))
    (if (i32.eqz (local.get $n))
      (then (call $emit_i32_const (local.get $tag_id)) (return)))
    (call $emit_alloc
      (i32.add (i32.const 4) (i32.mul (local.get $n) (i32.const 4)))
      (i32.const 1568))                                   ;; "variant_tmp"
    (call $ec_emit_local_get_dollar (i32.const 1568))
    (call $emit_i32_const (local.get $tag_id))
    (call $ec_emit_i32_store_offset (i32.const 0))
    (local.set $i (i32.const 0))
    (block $done
      (loop $store_loop
        (br_if $done (i32.ge_u (local.get $i) (local.get $n)))
        (local.set $arg (call $list_index (local.get $args) (local.get $i)))
        (call $ec_emit_local_get_dollar (i32.const 1568))
        (call $emit_lexpr (local.get $arg))
        (call $ec_emit_i32_store_offset
          (i32.add (i32.const 4) (i32.mul (local.get $i) (i32.const 4))))
        (local.set $i (i32.add (local.get $i) (i32.const 1)))
        (br $store_loop)))
    (call $ec_emit_local_get_dollar (i32.const 1568)))

  ;; ─── $emit_lexpr — partial dispatcher (Hβ.emit cascade forward-decl) ─
  ;; Per Hβ-emit-substrate.md §1 + §11.3 — $emit_lexpr is the canonical
  ;; top-level dispatcher landing at chunk #8 emit_dispatcher.wat. But
  ;; this peer landing introduces sub-LowExpr recursion (LMake* arms
  ;; recurse on elems/fields/args). Mirror of Hβ.lower walk_call.wat:
  ;; 254-358 — partial dispatcher in the FIRST chunk that needs
  ;; recursion; subsequent chunks retrofit via Edit per named follow-up
  ;; Hβ.emit.lexpr-dispatch-extension. Chunk #8 emit_dispatcher.wat owns
  ;; the orchestrator $emit_program but DOES NOT redefine $emit_lexpr —
  ;; by then this dispatcher is complete via cumulative retrofits.
  ;;
  ;; Drift-9-safe: every tag this dispatcher claims to know IS bodied;
  ;; unknown tags trap via (unreachable) — the trap surfaces when a
  ;; future emit chunk forgets to retrofit. Named follow-up makes the
  ;; expansion visible.
  ;;
  ;; Currently dispatches (post chunk #6 emit_call.wat retrofit):
  ;;   300 LConst        → $emit_lconst         (chunk #3 first commit)
  ;;   301 LLocal        → $emit_llocal         (chunk #4 retrofit)
  ;;   302 LGlobal       → $emit_lglobal        (chunk #4 retrofit)
  ;;   303 LStore        → $emit_lstore         (chunk #4 retrofit)
  ;;   305 LUpval        → $emit_lupval         (chunk #4 retrofit)
  ;;   306 LBinOp        → $emit_lbinop         (chunk #6 retrofit)
  ;;   307 LUnaryOp      → $emit_lunaryop       (chunk #6 retrofit)
  ;;   308 LCall         → $emit_lcall          (chunk #6 retrofit)
  ;;   309 LTailCall     → $emit_ltailcall      (chunk #6 retrofit)
  ;;   310 LReturn       → $emit_lreturn        (chunk #5 retrofit)
  ;;   314 LIf           → $emit_lif            (chunk #5 retrofit)
  ;;   315 LBlock        → $emit_lblock         (chunk #5 retrofit)
  ;;   316 LMakeList     → $emit_lmakelist      (chunk #3 peer)
  ;;   317 LMakeTuple    → $emit_lmaketuple     (chunk #3 peer)
  ;;   318 LMakeRecord   → $emit_lmakerecord    (chunk #3 peer)
  ;;   319 LMakeVariant  → $emit_lmakevariant   (chunk #3 peer)
  ;;   320 LIndex        → $emit_lindex         (chunk #6 retrofit)
  ;;   321 LMatch        → $emit_lmatch         (chunk #5 retrofit)
  ;;   325 LSuspend      → $emit_lsuspend       (chunk #6 retrofit)
  ;;   326 LStateGet     → $emit_lstateget      (chunk #4 retrofit)
  ;;   327 LStateSet     → $emit_lstateset      (chunk #4 retrofit)
  ;;   328 LRegion       → $emit_lregion        (chunk #5 retrofit)
  ;;   334 LFieldLoad    → $emit_lfieldload     (chunk #4 retrofit)
  ;;
  ;; All other LowExpr tags trap (unreachable) until chunk #7
  ;; retrofits per Hβ.emit.lexpr-dispatch-extension.
  ;;
  ;; Drift 1 refusal: direct (i32.eq $tag N) dispatch; NO $emit_arm_table
  ;; data segment, NO closure-record-of-fn-pointers. The word "vtable"
  ;; appears nowhere.
  ;; Drift 8 refusal: tag dispatch via integer constants;
  ;; NEVER `$str_eq($render_lowexpr, "LMakeList")`.
  (func $emit_lexpr (export "emit_lexpr") (param $r i32)
    (local $tag i32)
    (local.set $tag (call $tag_of (local.get $r)))
    (if (i32.eq (local.get $tag) (i32.const 300))
      (then (call $emit_lconst       (local.get $r)) (return)))
    (if (i32.eq (local.get $tag) (i32.const 301))
      (then (call $emit_llocal       (local.get $r)) (return)))
    (if (i32.eq (local.get $tag) (i32.const 302))
      (then (call $emit_lglobal      (local.get $r)) (return)))
    (if (i32.eq (local.get $tag) (i32.const 303))
      (then (call $emit_lstore       (local.get $r)) (return)))
    (if (i32.eq (local.get $tag) (i32.const 305))
      (then (call $emit_lupval       (local.get $r)) (return)))
    (if (i32.eq (local.get $tag) (i32.const 306))
      (then (call $emit_lbinop       (local.get $r)) (return)))
    (if (i32.eq (local.get $tag) (i32.const 307))
      (then (call $emit_lunaryop     (local.get $r)) (return)))
    (if (i32.eq (local.get $tag) (i32.const 308))
      (then (call $emit_lcall        (local.get $r)) (return)))
    (if (i32.eq (local.get $tag) (i32.const 309))
      (then (call $emit_ltailcall    (local.get $r)) (return)))
    (if (i32.eq (local.get $tag) (i32.const 310))
      (then (call $emit_lreturn      (local.get $r)) (return)))
    (if (i32.eq (local.get $tag) (i32.const 314))
      (then (call $emit_lif          (local.get $r)) (return)))
    (if (i32.eq (local.get $tag) (i32.const 315))
      (then (call $emit_lblock       (local.get $r)) (return)))
    (if (i32.eq (local.get $tag) (i32.const 316))
      (then (call $emit_lmakelist    (local.get $r)) (return)))
    (if (i32.eq (local.get $tag) (i32.const 317))
      (then (call $emit_lmaketuple   (local.get $r)) (return)))
    (if (i32.eq (local.get $tag) (i32.const 318))
      (then (call $emit_lmakerecord  (local.get $r)) (return)))
    (if (i32.eq (local.get $tag) (i32.const 319))
      (then (call $emit_lmakevariant (local.get $r)) (return)))
    (if (i32.eq (local.get $tag) (i32.const 320))
      (then (call $emit_lindex       (local.get $r)) (return)))
    (if (i32.eq (local.get $tag) (i32.const 321))
      (then (call $emit_lmatch       (local.get $r)) (return)))
    (if (i32.eq (local.get $tag) (i32.const 325))
      (then (call $emit_lsuspend     (local.get $r)) (return)))
    (if (i32.eq (local.get $tag) (i32.const 326))
      (then (call $emit_lstateget    (local.get $r)) (return)))
    (if (i32.eq (local.get $tag) (i32.const 327))
      (then (call $emit_lstateset    (local.get $r)) (return)))
    (if (i32.eq (local.get $tag) (i32.const 328))
      (then (call $emit_lregion      (local.get $r)) (return)))
    (if (i32.eq (local.get $tag) (i32.const 334))
      (then (call $emit_lfieldload   (local.get $r)) (return)))
    (unreachable))
