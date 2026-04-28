  ;; ═══ emit_diag.wat — Hβ.lower private diagnostic emission (Tier 6) ═══
  ;; Hβ.lower cascade chunk #4 of 11 — closes named follow-up
  ;; Hβ.lower.unresolved-emit-retrofit from lookup.wat:163-174
  ;; (commit e1209cc).
  ;;
  ;; What this chunk IS (per Hβ-lower-substrate.md §11 boundary lock
  ;; 2026-04-27 + §12.3 dep order chunk #4):
  ;;   The seed projection of spec 05 L43-50's lookup_ty_graph default
  ;;   handler NFree arm — the ONE lower-private diagnostic class:
  ;;   E_UnresolvedType. Inventory of src/lower.nx (full 1284 lines):
  ;;   zero `report(` / `eprint(` / `panic(` calls; lower itself never
  ;;   emits except through LookupTy's NFree handler arm. Therefore
  ;;   this chunk owns exactly ONE emit helper.
  ;;
  ;;   Per Hβ-lower-substrate.md §11 boundary lock: "All Hazel
  ;;   productive-under-error user diagnostics remain in
  ;;   bootstrap/src/infer/emit_diag.wat (infer-owned per 88992bc
  ;;   boundary canonicalization). Lower's emit_diag.wat chunk is
  ;;   purely for lower-private classes (e.g., NFree at lookup time
  ;;   means inference didn't bind a handle that lower expects bound;
  ;;   it's a lowering-stage compiler bug, not an inference user
  ;;   error)."
  ;;
  ;;   The chunk also lands $lower_render_ty — a wrapper around
  ;;   infer's $render_ty that adds one arm for the lookup-private
  ;;   TError-hole sentinel (tag 114, lookup.wat-owned per §11 audit
  ;;   lock). Composition direction: lower wraps infer; infer's
  ;;   14-arm canonical Ty walker stays untouched. The ONLY current
  ;;   caller of $lower_render_ty is reserved (no walk arm yet uses
  ;;   it for lower-private diagnostic message construction); the
  ;;   helper lands now to satisfy the lookup.wat:73-75 forward
  ;;   declaration ("Downstream emit_diag.wat dispatches tag 114
  ;;   in $render_ty: prints '<error-hole>'") and to close Drift 9
  ;;   on the lookup-private sentinel's downstream rendering path.
  ;;
  ;; Exports:    $lower_emit_unresolved_type,
  ;;             $lower_render_ty
  ;; Uses:       $alloc (alloc.wat),
  ;;             $str_concat (str.wat),
  ;;             $int_to_str (int.wat),
  ;;             $eprint_string (wasi.wat — fd 2 / stderr),
  ;;             $ty_tag (infer/ty.wat — render dispatch precondition),
  ;;             $render_ty (infer/emit_diag.wat — composition
  ;;               surface; preserves the canonical 14-arm Ty walker
  ;;               at the infer layer per Anchor 4 + §11 boundary lock)
  ;; Test:       bootstrap/test/lower/emit_diag_unresolved_type.wat
  ;;
  ;; ═══ EIGHT INTERROGATIONS (per Hβ-lower-substrate.md §5.1
  ;;                            projected onto emit_diag) ════════════
  ;;
  ;; 1. Graph?      $lower_emit_unresolved_type takes the handle integer
  ;;                only. Does NOT chase — at the call site (lookup.wat
  ;;                NFree arm) the GNode is already proven NFree; chasing
  ;;                here would re-traverse for no information gain. The
  ;;                Reason walk is named follow-up
  ;;                Hβ.lower.unresolved-emit-reason-walk — lands when the
  ;;                IDE projection needs Why-Engine context. $lower_render_ty
  ;;                operates on Ty pointers (not graph) and delegates the
  ;;                14 ground arms to infer's $render_ty.
  ;;
  ;; 2. Handler?    Wheel form: spec 05's lookup_ty_graph handler at the
  ;;                NFree arm performs `report("", "E_UnresolvedType",
  ;;                "UnresolvedType", ...)` + halts the build via
  ;;                resume(TName("UNRESOLVED", [])) sentinel. Seed form:
  ;;                direct $eprint_string + caller-side $wasi_proc_exit
  ;;                + (unreachable). The proc_exit is in the CALLER per
  ;;                spec 05 invariant 2 ("NFree is a compiler-internal
  ;;                error and halts"); this helper is emit-only so the
  ;;                trace harness can exercise the message construction
  ;;                without forcing a wasmtime non-zero exit per harness
  ;;                run. @resume=OneShot at the wheel (matches all spec
  ;;                05 default handler arms).
  ;;
  ;; 3. Verb?       N/A — direct call site from lookup.wat's NFree arm.
  ;;
  ;; 4. Row?        Wheel: GraphRead + Diagnostic (no GraphWrite —
  ;;                lower's row stays read-only on graph per spec 05
  ;;                invariant 1; the Boolean effect algebra gates the
  ;;                "no graph_bind" property structurally — an accidental
  ;;                bind here would fail handler-install type-check).
  ;;                Seed: direct $eprint_string call (Diagnostic
  ;;                projection); no graph mutation. $lower_render_ty
  ;;                is EfPure at the seed (no effects performed; pure
  ;;                tag-dispatch + delegate).
  ;;
  ;; 5. Ownership?  Message string `own` of the bump allocator
  ;;                (CLAUDE.md memory model: monotonic; never freed; one
  ;;                allocation per build halt — bounded). Handle is a
  ;;                value (i32); no transfer. The static "<error-hole>"
  ;;                string lives in the data segment (`ref`; data
  ;;                segments are never deallocated — they're part of
  ;;                the wasm image).
  ;;
  ;; 6. Refinement? N/A at $lower_emit_unresolved_type. At
  ;;                $lower_render_ty: TRefined (tag 111) transparent —
  ;;                delegates to infer's $render_ty which renders
  ;;                "render(base) + ' where ...'" per the canonical
  ;;                walker; lower never inspects the predicate (verify
  ;;                ledger holds it).
  ;;
  ;; 7. Gradient?   $lower_emit_unresolved_type IS the diagnostic-class
  ;;                enumeration that closes Drift 9 on lookup.wat's
  ;;                NFree arm. Each diagnostic IS one gradient signal
  ;;                in reverse — the developer (compiler-internal-bug
  ;;                surface; not user-facing) sees what the inference
  ;;                layer COULDN'T prove rather than encountering an
  ;;                opaque (unreachable). $lower_render_ty's tag-114 arm
  ;;                IS one gradient step that makes the lookup-private
  ;;                sentinel legible at the diagnostic surface without
  ;;                infer learning lookup's tag.
  ;;
  ;; 8. Reason?     The offending GNode at the handle has its Reason
  ;;                chain populated by inference at every $graph_bind
  ;;                site. This chunk does NOT walk it for V1 — the
  ;;                handle integer + the message form
  ;;                "E_UnresolvedType: handle <h> is NFree at lower-time"
  ;;                is sufficient compiler-internal-bug surface. The
  ;;                Reason walk is named follow-up
  ;;                Hβ.lower.unresolved-emit-reason-walk; lands when the
  ;;                IDE projection of compiler-internal-bug surfaces
  ;;                needs the Why-Engine context.
  ;;
  ;; ═══ FORBIDDEN PATTERNS AUDIT (per Hβ-lower-substrate.md §6
  ;;                               projected onto emit_diag) ═════════
  ;;
  ;; - Drift 1 (Rust vtable):              No diagnostic dispatch table.
  ;;                                       $lower_emit_unresolved_type is
  ;;                                       a direct named function. NO
  ;;                                       data segment named
  ;;                                       $lower_diag_table. The word
  ;;                                       "vtable" appears nowhere in
  ;;                                       this chunk.
  ;; - Drift 4 (Haskell monad transformer): No DiagM monad. Single i32
  ;;                                       parameter (handle); void return.
  ;; - Drift 5 (C calling convention):     One i32 param; no threaded
  ;;                                       diagnostic-context-struct +
  ;;                                       state ptr.
  ;; - Drift 8 (string-keyed):             Diagnostic class IS a function
  ;;                                       name ($lower_emit_unresolved_type),
  ;;                                       NOT a string-tag dispatch. NO
  ;;                                       $lower_emit(handle, code: i32, ...)
  ;;                                       int-coded entry point. Mirrors
  ;;                                       infer/emit_diag.wat's
  ;;                                       per-class-direct-fn discipline
  ;;                                       (12 peer functions; not one
  ;;                                       table). Per drift mode 8 +
  ;;                                       infer/emit_diag.wat:354-363:
  ;;                                       every flag OR enum-as-int is
  ;;                                       an ADT begging to exist; the
  ;;                                       ADT IS the code-name + per-code
  ;;                                       helper function pair. With
  ;;                                       exactly one helper, the family
  ;;                                       is degenerate but the discipline
  ;;                                       holds.
  ;; - Drift 9 (deferred-by-omission):     $lower_emit_unresolved_type
  ;;                                       lands FULLY BODIED this commit;
  ;;                                       NO stub. The lookup.wat NFree
  ;;                                       arm retrofit lands in the SAME
  ;;                                       commit (TWO-FILE landing); NO
  ;;                                       "substrate now / wiring later"
  ;;                                       split. Hβ.lower.unresolved-emit-retrofit
  ;;                                       follow-up CLOSED this commit.
  ;;                                       $lower_render_ty bodied this
  ;;                                       commit per the lookup.wat:73-75
  ;;                                       forward declaration ("Downstream
  ;;                                       emit_diag.wat (chunk #4)
  ;;                                       dispatches tag 114 in $render_ty
  ;;                                       — prints '<error-hole>'");
  ;;                                       NOT half-built.
  ;;
  ;; - Foreign fluency — exception machinery: NO "throw" / "panic" /
  ;;                                       "unwind" / "exception" / "catch"
  ;;                                       vocabulary. The seed's surface
  ;;                                       is one $eprint_string + the
  ;;                                       caller's (call $wasi_proc_exit)
  ;;                                       + (unreachable). Per spec 05
  ;;                                       invariant 2: "NFree is a
  ;;                                       compiler-internal error and
  ;;                                       halts" — direct halt, no
  ;;                                       unwinding. Hazel productive-
  ;;                                       under-error pattern (per spec
  ;;                                       04) applies to USER
  ;;                                       diagnostics — emit + bind
  ;;                                       NErrorHole + walk continues;
  ;;                                       compiler-internal bugs (NFree
  ;;                                       at lower) DO halt because
  ;;                                       they're upstream-pass failures,
  ;;                                       not user errors. This chunk is
  ;;                                       the latter category exclusively.
  ;;
  ;; - Foreign fluency — log levels:       NO "info" / "debug" / "warn" /
  ;;                                       "error" enum dispatch. The
  ;;                                       diagnostic kind is the catalog
  ;;                                       code's prefix (E_) per
  ;;                                       docs/errors/README.md L24-31;
  ;;                                       this helper has no log-level
  ;;                                       parameter.
  ;;
  ;; Tag region: no new tags claimed.
  ;;   This chunk doesn't introduce its own ADT records — it composes on
  ;;   str.wat (message construction), int.wat ($int_to_str), wasi.wat
  ;;   ($eprint_string), infer/ty.wat ($ty_tag), infer/emit_diag.wat
  ;;   ($render_ty delegation). No tag allocation.
  ;;
  ;; Named follow-ups (per Drift 9 + Hβ-lower-substrate.md §11):
  ;;   - Hβ.lower.unresolved-emit-reason-walk:
  ;;                              $lower_emit_unresolved_type currently
  ;;                              emits handle integer only. Future
  ;;                              enrichment reads $gnode_reason(graph_chase
  ;;                              (handle)) + walks the Reason chain to
  ;;                              surface "inference left handle <h> NFree
  ;;                              because <reason chain>" per Why-Engine
  ;;                              discipline. Lands when IDE projection
  ;;                              of compiler-internal bugs needs richer
  ;;                              context. Lower-private follow-up;
  ;;                              composes on infer's reason.wat chain-
  ;;                              walking primitives (post-Wave-2.E
  ;;                              substrate per Mentl tentacle-Why
  ;;                              landing).
  ;;
  ;; ─── Data segment — diagnostic message fragments ──────────────────
  ;;
  ;; All diagnostic message strings live in the data segment per the
  ;; infer/emit_diag.wat precedent. Length-prefixed flat-string layout
  ;; ([len:i32][bytes...]). Offsets sit above infer/emit_diag.wat's last
  ;; data segment (2928 + 4 + 1 = 2933; next 8-byte-aligned offset = 2944)
  ;; and well below HEAP_BASE = 4096 per CLAUDE.md memory model.
  ;; Available: 2944 .. 4095 = 1152 bytes. Used: ~80 bytes. Headroom: ample.

  (data (i32.const 2944) "\21\00\00\00E_UnresolvedType: lower-time NFree at handle ")  ;; 33 bytes payload (header)
  (data (i32.const 2992) "\01\00\00\00\0a")                                              ;; "\n" — 1 byte payload
  (data (i32.const 3000) "\0c\00\00\00<error-hole>")                                     ;; 12 bytes payload (tag-114 render)

  ;; ─── $lower_emit_unresolved_type — E_UnresolvedType helper ────────
  ;;
  ;; Per spec 05 L43-50 + Hβ-lower-substrate.md §1.1 lines 165-172 +
  ;; §11 boundary lock 2026-04-27. Closes Hβ.lower.unresolved-emit-retrofit
  ;; named follow-up from lookup.wat:163-174. Emit-only — caller
  ;; (lookup.wat NFree arm) chains $wasi_proc_exit + (unreachable) per
  ;; spec 05 invariant 2.
  ;;
  ;; Message form: "E_UnresolvedType: lower-time NFree at handle <h>\n"
  ;; (simplified from spec 05 L46's wheel form
  ;; '"handle " ++ show(h) ++ " @epoch=" ++ show(epoch)' — the @epoch
  ;; suffix is wheel-time graph metadata not yet exposed by graph.wat;
  ;; the seed surfaces handle integer only. Future enrichment under
  ;; named follow-up Hβ.lower.unresolved-emit-reason-walk).
  (func $lower_emit_unresolved_type (export "lower_emit_unresolved_type")
                                      (param $handle i32)
    (local $msg i32)
    (local.set $msg (i32.const 2944))                                  ;; "E_UnresolvedType: lower-time NFree at handle "
    (local.set $msg (call $str_concat (local.get $msg) (call $int_to_str (local.get $handle))))
    (local.set $msg (call $str_concat (local.get $msg) (i32.const 2992)))   ;; "\n"
    (call $eprint_string (local.get $msg)))

  ;; ─── $lower_render_ty — Ty walker with TError-hole sentinel arm ───
  ;;
  ;; Per Hβ-lower-substrate.md §11 boundary lock 2026-04-27 +
  ;; lookup.wat:73-75 forward declaration. Wraps infer's $render_ty
  ;; (bootstrap/src/infer/emit_diag.wat:539-626 — the canonical 14-arm
  ;; walker over Ty tags 100-113). Adds one arm for the lookup-private
  ;; TError-hole sentinel (tag 114, owned by lookup.wat per §11 audit
  ;; lock — NOT a 15th canonical Ty variant).
  ;;
  ;; Composition direction: lower COMPOSES on infer's render walker;
  ;; infer's chunk stays UNTOUCHED (preserves Anchor 4 — build the
  ;; wheel; never wrap the axle; infer's 14-arm walker IS the canonical
  ;; render contract). The wrapper preserves the contract by
  ;; SHORT-CIRCUITING tag 114 to a static data-segment string before
  ;; delegating; tags 100-113 fall through to infer.
  (func $lower_render_ty (export "lower_render_ty") (param $ty i32) (result i32)
    ;; Tag-114 short-circuit — lookup-private TError-hole sentinel.
    (if (i32.eq (call $ty_tag (local.get $ty)) (i32.const 114))
      (then (return (i32.const 3000))))                                 ;; "<error-hole>"
    ;; Tags 100-113 — delegate to infer's canonical 14-arm walker.
    (call $render_ty (local.get $ty)))
