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
