  ;; ═══ emit_handler.wat — Hβ.emit handler family (Tier 6, chunk #7) ═══
  ;; The chunk where `~>` and `<~` become physical at WAT.
  ;;
  ;; Per Hβ-emit-substrate.md §2.5: 7 arms land here — LLet (tag 304) +
  ;; LDeclareFn (tag 313) + LHandleWith (tag 329) + LFeedback (tag 330) +
  ;; LPerform (tag 331) + LHandle (tag 332) + LEvPerform (tag 333).
  ;;
  ;; The two LFn-bearing arms — LMakeClosure (tag 311) + LMakeContinuation
  ;; (tag 312) — require LowFn record substrate (tag 350 + 5 accessors)
  ;; that the seed has not yet materialized. Per Anchor 7 cascade
  ;; discipline, those arms land in named peer Hβ.emit.handler-fnref-
  ;; substrate which depends on Hβ.lower.lowfn-substrate (the LowFn
  ;; record substrate addition to bootstrap/src/lower/lexpr.wat plus
  ;; walk_compound + walk_stmt updates to construct LowFn properly).
  ;; Drift 9 closure via explicit naming, NOT silent absorption.
  ;;
  ;; Implements: Hβ-emit-substrate.md §2.5 (7 of 9 arms — handler family
  ;;             excluding LMakeClosure / LMakeContinuation per dependency
  ;;             on LowFn substrate) + §3 (H1.4 single-handler-per-op
  ;;             naming via $emit_op_symbol composition for LPerform) +
  ;;             §5.1 (eight interrogations) + §7.1 (chunk #7) + §11.3
  ;;             dep order (chunk #7 follows emit_call.wat).
  ;; Exports:    $emit_llet, $emit_ldeclarefn, $emit_lhandlewith,
  ;;             $emit_lhandle, $emit_lfeedback, $emit_lperform,
  ;;             $emit_levperform.
  ;; Uses:       lower/lexpr.wat accessors —
  ;;               $lexpr_llet_name + $lexpr_llet_value
  ;;               $lexpr_lhandlewith_body + $lexpr_lhandlewith_handler
  ;;               $lexpr_lhandle_body + $lexpr_lhandle_arms
  ;;               $lexpr_lfeedback_body + $lexpr_lfeedback_spec
  ;;               $lexpr_lperform_op_name + $lexpr_lperform_args
  ;;               $lexpr_levperform_op_name + $lexpr_levperform_slot_idx
  ;;               + $lexpr_levperform_args
  ;;               $lexpr_handle (universal — for LFeedback's site handle)
  ;;             emit/state.wat —
  ;;               $emit_body_captures_count (H1 evidence-slot offset
  ;;               base resolution at LEvPerform)
  ;;             emit_infra.wat —
  ;;               $emit_byte + $emit_int + $emit_str + $emit_i32_const
  ;;             emit_const.wat —
  ;;               $emit_lexpr (partial dispatcher; this chunk RETROFITS
  ;;               its arm table for tags 304/313/329/330/331/332/333
  ;;               per Hβ.emit.lexpr-dispatch-extension)
  ;;               $ec_emit_local_set_dollar (LLet's local.set $<name>)
  ;;             emit_local.wat —
  ;;               $el_emit_local_get_state (LEvPerform's __state load)
  ;;               $el_emit_i32_load_offset (LEvPerform's evidence-slot
  ;;               offset load)
  ;;             emit_call.wat —
  ;;               $ec6_emit_args (sequential arg emission)
  ;;               $ec6_emit_call_indirect_ftN (LEvPerform's polymorphic
  ;;               dispatch through the callee's evidence-slot fn-ptr)
  ;;
  ;; What this chunk IS (per Hβ-emit-substrate.md §2.5):
  ;;
  ;;   1. $emit_llet(r) — LLet tag 304 (handle, name, value).
  ;;      Per src/backends/wasm.mn:1147-1152: emit val + (local.set
  ;;      $<name>). Lock #6 of Hβ.lower walk_call: ResumeExpr lowers to
  ;;      LReturn (not LLet); LLet is parser-LetStmt's lowering form.
  ;;
  ;;   2. $emit_ldeclarefn(r) — LDeclareFn tag 313 (lowfn).
  ;;      Per src/backends/wasm.mn:1601-1608 + H1.4: at expression
  ;;      position this arm emits "(i32.const 0) ;; LDeclareFn marker".
  ;;      The actual `(func $op_<name> ...)` body emission happens at
  ;;      module-emit time via emit_fns_expr deep walk (chunk #9
  ;;      main.wat orchestrator). LDeclareFn at expression position is
  ;;      a no-op marker that the LBlock placeholder Lock makes valid.
  ;;
  ;;   3. $emit_lhandlewith(r) — LHandleWith tag 329 (handle, body, handler).
  ;;      Per src/backends/wasm.mn:1486-1489: emit body + comment
  ;;      "~> handler attached (tail-resumptive inlined)". The handler-
  ;;      attach is INERT at the seed because tail-resumptive (the ~85%
  ;;      case per SUBSTRATE.md §III "Three Tiers") inlines the handler
  ;;      arm body at the perform site through evidence passing — no
  ;;      runtime handler-stack push.
  ;;
  ;;   4. $emit_lhandle(r) — LHandle tag 332 (handle, body, arms).
  ;;      Per src/backends/wasm.mn:1549-1552: emit body + comment.
  ;;      Same inert-substrate as LHandleWith; arms are emitted
  ;;      separately at module-emit time as `(func $op_<name> ...)`.
  ;;
  ;;   5. $emit_lfeedback(r) — LFeedback tag 330 (handle, body, spec).
  ;;      Per src/backends/wasm.mn:1491-1534 + LF walkthrough §1.5
  ;;      state-machine lowering. THE `<~` SUBSTRATE made physical:
  ;;      load-prior → emit body → tee-current → store-current →
  ;;      reload-current. The handle `h` (from $lexpr_handle) names
  ;;      the per-site state global $s<h> + the per-site locals
  ;;      $__fb_prev_<h> + $__fb_<h>.
  ;;
  ;;      Per SUBSTRATE.md §II "Feedback IS Mentl's Genuine Novelty":
  ;;      `<~` is sugar for a stateful handler capturing output and
  ;;      re-injecting it. State-global substrate reuses LStateGet/
  ;;      LStateSet's `$s<slot>` convention; module-init declares each
  ;;      $s<n> as `(global $s<n> (mut i32) (i32.const 0))`.
  ;;
  ;;   6. $emit_lperform(r) — LPerform tag 331 (handle, op_name, args).
  ;;      Per src/backends/wasm.mn:1536-1547: emit args + (call $op_
  ;;      <op_name>) per H1.4 single-handler-per-op naming. The
  ;;      monomorphic direct-call form — row inference's >95% claim
  ;;      cashes out HERE (per SUBSTRATE.md §I third truth "OneShot.
  ;;      Direct return_call $op_<name>").
  ;;
  ;;   7. $emit_levperform(r) — LEvPerform tag 333 (handle, op_name,
  ;;      slot_idx, args). Per src/backends/wasm.mn:1554-1587 + H1
  ;;      evidence reification: load fn_idx from __state at offset
  ;;      8 + 4*body_capture_count + 4*slot_idx, push __state + args,
  ;;      call_indirect via $ft<argc+1>. The polymorphic call site
  ;;      where evidence passing makes the handler dispatch a single
  ;;      i32 read from the closure record's evidence-slot field.
  ;;      DRIFT 1 REFUSAL — fn_idx is a FIELD on the closure record,
  ;;      NOT a vtable lookup.
  ;;
  ;; Eight interrogations (per Hβ-emit-substrate.md §5.1 second pass):
  ;;
  ;;   1. Graph?       Each arm reads its LowExpr's record fields via
  ;;                   $lexpr_l*_* accessors. LFeedback reads the source
  ;;                   handle via $lexpr_handle (universal) for state-
  ;;                   global naming. LEvPerform reads $emit_body_
  ;;                   captures_count from emit-time graph-equivalent
  ;;                   state. Per Anchor 1: ask the graph; never re-
  ;;                   derive shape.
  ;;   2. Handler?     At wheel: each arm is one branch of emit_expr
  ;;                   match. At seed: direct fn dispatch via $emit_
  ;;                   lexpr's tag table. @resume=OneShot at the wheel.
  ;;                   LEvPerform's runtime call_indirect IS the
  ;;                   handler dispatch substrate per SUBSTRATE.md §I.
  ;;   3. Verb?        LFeedback IS the `<~` verb made physical —
  ;;                   SUBSTRATE.md §II "Feedback IS Mentl's Genuine
  ;;                   Novelty". LHandleWith / LHandle ARE the `~>`
  ;;                   verb made physical (inert seed; tail-resumptive
  ;;                   inline). LPerform / LEvPerform are NOT verbs —
  ;;                   they're effect operations (kernel primitive #2).
  ;;   4. Row?         WasmOut at wheel; row-silent at seed. LEvPerform
  ;;                   is the polymorphic-row dispatch site.
  ;;   5. Ownership?   LowExpr `r` is `ref` (read-only structural
  ;;                   traversal). $out_base buffer OWNed program-wide.
  ;;   6. Refinement?  N/A for these arms.
  ;;   7. Gradient?    LEvPerform IS the H1 evidence reification
  ;;                   gradient cash-out — when row inference fails to
  ;;                   ground a handler chain at compile time, the call
  ;;                   site routes through this arm; otherwise LPerform
  ;;                   (direct $op_<name> call) is emitted by lower.
  ;;                   The annotation that unlocks the LPerform path is
  ;;                   row purification (any `with E1 + E2` declaration
  ;;                   that grounds the handler stack).
  ;;   8. Reason?      Read-only — caller's $lookup_ty preserves Reason
  ;;                   chain.
  ;;
  ;; Forbidden patterns audited (per Hβ-emit-substrate.md §6 + project
  ;; drift modes):
  ;;
  ;;   - Drift 1 (Rust vtable):     LEvPerform IS THE LOAD-BEARING ARM.
  ;;                                fn_idx is a FIELD on __state at
  ;;                                offset (8 + 4*nc + 4*slot); call_
  ;;                                indirect reads that field via the
  ;;                                $ft<N+1> type. NO $op_table; NO
  ;;                                vtable; word "vtable" appears
  ;;                                nowhere.
  ;;   - Drift 5 (C calling conv):  LEvPerform's __state IS the unified
  ;;                                closure record (no separate
  ;;                                __closure / __ev split).
  ;;   - Drift 8 (string-keyed):    LPerform's op_name is emitted AS
  ;;                                a string identifier "op_<name>" —
  ;;                                that's the WAT identifier itself
  ;;                                (the H1.4 single-handler-per-op
  ;;                                naming convention — appropriate use,
  ;;                                NOT flag-as-string drift). The
  ;;                                dispatch is via WAT's $-name
  ;;                                resolution, not runtime $str_eq.
  ;;   - Drift 9 (deferred-by-      LMakeClosure (tag 311) +
  ;;                  omission):    LMakeContinuation (tag 312) require
  ;;                                LowFn record substrate which the
  ;;                                seed has not yet materialized. Drift
  ;;                                9 closure via NAMED peer follow-up
  ;;                                Hβ.emit.handler-fnref-substrate that
  ;;                                lands AFTER Hβ.lower.lowfn-substrate
  ;;                                materializes the LowFn record (tag
  ;;                                350 + 5 accessors per src/lower.mn
  ;;                                LFn ADT). The 7 arms in this chunk
  ;;                                are FULLY bodied; no stubs.
  ;;   - Foreign fluency:           Vocabulary stays Mentl — "perform",
  ;;                                "handle", "feedback", "evidence
  ;;                                slot", "tail-resumptive". NEVER
  ;;                                "callback" / "method-table" /
  ;;                                "exception-handler".
  ;;
  ;; Named follow-ups (per Drift 9 + Hβ-emit-substrate.md §10):
  ;;   - Hβ.emit.lexpr-dispatch-extension: chunk #7 retrofits $emit_lexpr
  ;;                                       (this chunk).
  ;;   - Hβ.lower.lowfn-substrate:         add LowFn record (tag 350) +
  ;;                                       5 accessors to lower/lexpr.wat;
  ;;                                       update walk_compound + walk_stmt
  ;;                                       to construct LowFn properly per
  ;;                                       src/lower.mn LFn ADT.
  ;;   - Hβ.emit.handler-fnref-substrate:  $emit_lmakeclosure (tag 311) +
  ;;                                       $emit_lmakecontinuation (tag
  ;;                                       312) emit arms; depends on
  ;;                                       Hβ.lower.lowfn-substrate
  ;;                                       landing first.

  ;; ─── Chunk-private byte-emission helpers ──────────────────────────

  (func $ec7_emit_call_op_dollar (param $op_name i32)
    ;; emits: (call $op_<op_name>)
    ;; Per H1.4 single-handler-per-op naming — the WAT identifier
    ;; "$op_<name>" IS the symbol the LPerform's effect op resolves to.
    (call $emit_byte (i32.const 40)) (call $emit_byte (i32.const 99))
    (call $emit_byte (i32.const 97)) (call $emit_byte (i32.const 108))
    (call $emit_byte (i32.const 108)) (call $emit_byte (i32.const 32))
    (call $emit_byte (i32.const 36)) (call $emit_byte (i32.const 111))
    (call $emit_byte (i32.const 112)) (call $emit_byte (i32.const 95))
    (call $emit_str (local.get $op_name))
    (call $emit_byte (i32.const 41)))

  (func $ec7_emit_global_get_s_h (param $h i32)
    ;; emits: (global.get $s<h>)
    (call $emit_byte (i32.const 40)) (call $emit_byte (i32.const 103))
    (call $emit_byte (i32.const 108)) (call $emit_byte (i32.const 111))
    (call $emit_byte (i32.const 98)) (call $emit_byte (i32.const 97))
    (call $emit_byte (i32.const 108)) (call $emit_byte (i32.const 46))
    (call $emit_byte (i32.const 103)) (call $emit_byte (i32.const 101))
    (call $emit_byte (i32.const 116)) (call $emit_byte (i32.const 32))
    (call $emit_byte (i32.const 36)) (call $emit_byte (i32.const 115))
    (call $emit_int  (local.get $h))
    (call $emit_byte (i32.const 41)))

  (func $ec7_emit_global_set_s_h (param $h i32)
    ;; emits: (global.set $s<h>)
    (call $emit_byte (i32.const 40)) (call $emit_byte (i32.const 103))
    (call $emit_byte (i32.const 108)) (call $emit_byte (i32.const 111))
    (call $emit_byte (i32.const 98)) (call $emit_byte (i32.const 97))
    (call $emit_byte (i32.const 108)) (call $emit_byte (i32.const 46))
    (call $emit_byte (i32.const 115)) (call $emit_byte (i32.const 101))
    (call $emit_byte (i32.const 116)) (call $emit_byte (i32.const 32))
    (call $emit_byte (i32.const 36)) (call $emit_byte (i32.const 115))
    (call $emit_int  (local.get $h))
    (call $emit_byte (i32.const 41)))

  (func $ec7_emit_local_set_fb_prev_h (param $h i32)
    ;; emits: (local.set $__fb_prev_<h>)
    (call $emit_byte (i32.const 40)) (call $emit_byte (i32.const 108))
    (call $emit_byte (i32.const 111)) (call $emit_byte (i32.const 99))
    (call $emit_byte (i32.const 97)) (call $emit_byte (i32.const 108))
    (call $emit_byte (i32.const 46)) (call $emit_byte (i32.const 115))
    (call $emit_byte (i32.const 101)) (call $emit_byte (i32.const 116))
    (call $emit_byte (i32.const 32)) (call $emit_byte (i32.const 36))
    (call $emit_byte (i32.const 95)) (call $emit_byte (i32.const 95))
    (call $emit_byte (i32.const 102)) (call $emit_byte (i32.const 98))
    (call $emit_byte (i32.const 95)) (call $emit_byte (i32.const 112))
    (call $emit_byte (i32.const 114)) (call $emit_byte (i32.const 101))
    (call $emit_byte (i32.const 118)) (call $emit_byte (i32.const 95))
    (call $emit_int  (local.get $h))
    (call $emit_byte (i32.const 41)))

  (func $ec7_emit_local_tee_fb_h (param $h i32)
    ;; emits: (local.tee $__fb_<h>)
    (call $emit_byte (i32.const 40)) (call $emit_byte (i32.const 108))
    (call $emit_byte (i32.const 111)) (call $emit_byte (i32.const 99))
    (call $emit_byte (i32.const 97)) (call $emit_byte (i32.const 108))
    (call $emit_byte (i32.const 46)) (call $emit_byte (i32.const 116))
    (call $emit_byte (i32.const 101)) (call $emit_byte (i32.const 101))
    (call $emit_byte (i32.const 32)) (call $emit_byte (i32.const 36))
    (call $emit_byte (i32.const 95)) (call $emit_byte (i32.const 95))
    (call $emit_byte (i32.const 102)) (call $emit_byte (i32.const 98))
    (call $emit_byte (i32.const 95))
    (call $emit_int  (local.get $h))
    (call $emit_byte (i32.const 41)))

  (func $ec7_emit_local_get_fb_h (param $h i32)
    ;; emits: (local.get $__fb_<h>)
    (call $emit_byte (i32.const 40)) (call $emit_byte (i32.const 108))
    (call $emit_byte (i32.const 111)) (call $emit_byte (i32.const 99))
    (call $emit_byte (i32.const 97)) (call $emit_byte (i32.const 108))
    (call $emit_byte (i32.const 46)) (call $emit_byte (i32.const 103))
    (call $emit_byte (i32.const 101)) (call $emit_byte (i32.const 116))
    (call $emit_byte (i32.const 32)) (call $emit_byte (i32.const 36))
    (call $emit_byte (i32.const 95)) (call $emit_byte (i32.const 95))
    (call $emit_byte (i32.const 102)) (call $emit_byte (i32.const 98))
    (call $emit_byte (i32.const 95))
    (call $emit_int  (local.get $h))
    (call $emit_byte (i32.const 41)))

  ;; ─── ec8: helpers for LMakeClosure / LMakeContinuation ─────────────
  ;; These helpers materialize because Phase D lands here — the two
  ;; LFn-bearing arms (tags 311-312) now have a truthful LowFn substrate
  ;; to read from (Hβ.lower.lowfn-substrate, Phase C). Drift-1-safe:
  ;; fn_ptr is an i32 field in the closure record at offset 0, emitted
  ;; as (global.get $<name>_idx). NO vtable; NO op_table.

  (func $ec8_emit_global_get_name_idx (param $name i32)
    ;; emits: (global.get $<name>_idx)
    ;; The i32 table-index slot for the closure's target fn.
    (call $emit_byte (i32.const 40)) (call $emit_byte (i32.const 103))
    (call $emit_byte (i32.const 108)) (call $emit_byte (i32.const 111))
    (call $emit_byte (i32.const 98))  (call $emit_byte (i32.const 97))
    (call $emit_byte (i32.const 108)) (call $emit_byte (i32.const 46))
    (call $emit_byte (i32.const 103)) (call $emit_byte (i32.const 101))
    (call $emit_byte (i32.const 116)) (call $emit_byte (i32.const 32))
    (call $emit_byte (i32.const 36))
    (call $emit_str (local.get $name))
    (call $emit_byte (i32.const 95))  (call $emit_byte (i32.const 105))
    (call $emit_byte (i32.const 100)) (call $emit_byte (i32.const 120))
    (call $emit_byte (i32.const 41)))

  (func $ec8_emit_local_get_state_tmp
    ;; emits: (local.get $state_tmp)
    ;; Reuses emit_call.wat's data segment at 2244 (length-prefix "state_tmp").
    (call $ec_emit_local_get_dollar (i32.const 2244)))

  (func $ec8_emit_cap_stores (param $caps i32) (param $base_off i32)
    ;; Emit one (local.get $state_tmp) + <elem> + (i32.store offset=N)
    ;; triple per element, at consecutive offsets from base_off.
    ;; Each elem is a LowExpr — emitted via $emit_lexpr.
    (local $n i32) (local $i i32)
    (local.set $n (call $len (local.get $caps)))
    (local.set $i (i32.const 0))
    (block $done (loop $loop
      (br_if $done (i32.ge_u (local.get $i) (local.get $n)))
      (call $ec8_emit_local_get_state_tmp)
      (call $emit_lexpr (call $list_index (local.get $caps) (local.get $i)))
      (call $ec_emit_i32_store_offset
        (i32.add (local.get $base_off)
                 (i32.mul (local.get $i) (i32.const 4))))
      (local.set $i (i32.add (local.get $i) (i32.const 1)))
      (br $loop))))

  ;; ─── $emit_llet — LLet tag 304 emit arm per §2.5 ───────────────────
  ;; Per src/backends/wasm.mn:1147-1152: sub-emit value + "(local.set
  ;; $<name>)". Lock #6 separation: ResumeExpr→LReturn (not LLet);
  ;; parser-LetStmt→LLet.
  (func $emit_llet (param $r i32)
    (call $emit_lexpr (call $lexpr_llet_value (local.get $r)))
    (call $ec_emit_local_set_dollar (call $lexpr_llet_name (local.get $r))))

  ;; ─── $emit_ldeclarefn — LDeclareFn tag 313 emit arm per §2.5 ───────
  ;; Per src/backends/wasm.mn:1601-1608 + H1.4: at expression-position
  ;; this arm is a NO-OP marker. The actual `(func $op_<name> ...)`
  ;; body emission happens at module-emit time via emit_fns_expr deep
  ;; walk (chunk #9 main.wat). LDeclareFn lands inside LBlock per
  ;; Hβ.lower walk_stmt's HandlerDeclStmt arm; the LBlock placeholder
  ;; convention requires this arm to push some i32 (here: 0) for the
  ;; block's value-position slot.
  (func $emit_ldeclarefn (param $r i32)
    (call $emit_i32_const (i32.const 0)))

  ;; ─── $emit_lhandlewith — LHandleWith tag 329 emit arm per §2.5 ─────
  ;; Per src/backends/wasm.mn:1486-1489: sub-emit body. The handler-
  ;; attach is INERT at the seed because tail-resumptive (~85% per
  ;; SUBSTRATE.md §III) inlines the handler arm body at the perform
  ;; site through evidence passing — no runtime handler-stack push.
  ;; The handler list is emitted separately at module-emit time as
  ;; `(func $op_<name> ...)` declarations.
  (func $emit_lhandlewith (param $r i32)
    (call $emit_lexpr (call $lexpr_lhandlewith_body (local.get $r))))

  ;; ─── $emit_lhandle — LHandle tag 332 emit arm per §2.5 ─────────────
  ;; Per src/backends/wasm.mn:1549-1552: sub-emit body. Same inert-
  ;; substrate as LHandleWith; arms are emitted separately at module-
  ;; emit time.
  (func $emit_lhandle (param $r i32)
    (call $emit_lexpr (call $lexpr_lhandle_body (local.get $r))))

  ;; ─── $emit_lfeedback — LFeedback tag 330 emit arm per §2.5 ─────────
  ;; Per src/backends/wasm.mn:1491-1534 + LF walkthrough §1.5 — THE
  ;; `<~` SUBSTRATE made physical at WAT. State-machine lowering:
  ;;
  ;;   (global.get $s<h>)              ;; load prior iteration's output
  ;;   (local.set $__fb_prev_<h>)      ;; bind to per-site local
  ;;   <body>                          ;; emit body (may reference $__fb_prev_<h>)
  ;;   (local.tee $__fb_<h>)           ;; current-iteration output
  ;;   (global.set $s<h>)              ;; store back to state global
  ;;   (local.get $__fb_<h>)           ;; reload as the construct's value
  ;;
  ;; The handle `h` (from $lexpr_handle) names the per-site state
  ;; global $s<h> + the per-site locals $__fb_prev_<h> + $__fb_<h>.
  ;; State globals declared at module init by emit_state_globals
  ;; (chunk #9 main.wat).
  ;;
  ;; Per SUBSTRATE.md §II "Feedback IS Mentl's Genuine Novelty":
  ;; `<~` is sugar for a stateful handler capturing output and re-
  ;; injecting it. Under `Sample(44100)` it's a sample delay (DSP);
  ;; under `Tick` it's logical-step iteration; under `Clock(wall_ms=10)`
  ;; it's a control-loop delay. One operator; topology-only semantics;
  ;; ambient handler decides interpretation.
  (func $emit_lfeedback (param $r i32)
    (local $h i32)
    (local.set $h (call $lexpr_handle (local.get $r)))
    (call $ec7_emit_global_get_s_h (local.get $h))
    (call $ec7_emit_local_set_fb_prev_h (local.get $h))
    (call $emit_lexpr (call $lexpr_lfeedback_body (local.get $r)))
    (call $ec7_emit_local_tee_fb_h (local.get $h))
    (call $ec7_emit_global_set_s_h (local.get $h))
    (call $ec7_emit_local_get_fb_h (local.get $h)))

  ;; ─── $emit_lperform — LPerform tag 331 emit arm per §2.5 ───────────
  ;; Per src/backends/wasm.mn:1568-1579 + H1.4 single-handler-per-op:
  ;;   (local.get $__state)              ;; __state IS first param of $op_<name>
  ;;   <args>                             ;; user-visible args follow
  ;;   (call $op_<op_name>)
  ;; The monomorphic direct-call form — row inference's >95% claim
  ;; cashes out HERE per SUBSTRATE.md §I third truth "OneShot. Direct
  ;; return_call $op_<name>". The polymorphic minority routes through
  ;; LEvPerform (chunk #6) which threads ev_slot evidence instead.
  ;;
  ;; Per `Hβ.first-light.emit-lperform-state-arg` — handler-arm fns
  ;; declared by $lower_handler_arms_as_decls take __state as their
  ;; first param ($lowfn_make signature: name/arity/param_names/body/row;
  ;; emit_functions_walk prepends __state as the universal first param
  ;; per emit_handler.wat:$emit_ldeclarefn convention). Caller must push
  ;; __state to match. Pre-substrate the seed emitted only args, so
  ;; wat2wasm rejected `(call $op_<name>)` with "expected [i32] but got
  ;; []" for any program with a perform site. Symmetric to LEvPerform's
  ;; first $el_emit_local_get_state per §I third-truth + Koka JFP 2022.
  (func $emit_lperform (param $r i32)
    (local $op_name i32)
    (local.set $op_name (call $lexpr_lperform_op_name (local.get $r)))
    ;; Per Hβ.emit.wasi-effect-op-direct-emit (2026-05-07): if target
    ;; starts with "wasi_", emit `(call $<name>)` direct — bypassing
    ;; the `op_` discriminator prefix used for handler-arm dispatch.
    ;; WASI ops are foreign-fn imports, not handler arms. Drift
    ;; refused: 1 (structural prefix-check); 8 (no mode flag).
    (if (call $starts_with_wasi (local.get $op_name))
      (then
        (call $ec6_emit_args (call $lexpr_lperform_args (local.get $r)))
        (call $ec7_emit_call_dollar (local.get $op_name))
        (return)))
    ;; Per Hβ.emit.memory-effect-op-direct-emit (2026-05-07): if
    ;; target starts with "memory_", emit RAW WASM instruction —
    ;; (i32.load offset=0) / (i32.store offset=0) / (i32.load8_u
    ;; offset=0) / (i32.store8 offset=0). The graph encodes
    ;; "this is a Memory op"; emit projects to native WASM, not
    ;; an indirect call.
    (if (call $starts_with_memory (local.get $op_name))
      (then
        (call $ec6_emit_args (call $lexpr_lperform_args (local.get $r)))
        (call $emit_memory_op_wasm (local.get $op_name))
        (return)))
    (call $el_emit_local_get_state)
    (call $ec6_emit_args (call $lexpr_lperform_args (local.get $r)))
    (call $ec7_emit_call_op_dollar (local.get $op_name)))

  ;; $starts_with_memory — checks `memory_` prefix (7 bytes).
  (func $starts_with_memory (param $s i32) (result i32)
    (local $slen i32)
    (local.set $slen (call $str_len (local.get $s)))
    (if (i32.lt_u (local.get $slen) (i32.const 7))
      (then (return (i32.const 0))))
    (if (i32.ne (call $byte_at (local.get $s) (i32.const 0)) (i32.const 109))   ;; 'm'
      (then (return (i32.const 0))))
    (if (i32.ne (call $byte_at (local.get $s) (i32.const 1)) (i32.const 101))   ;; 'e'
      (then (return (i32.const 0))))
    (if (i32.ne (call $byte_at (local.get $s) (i32.const 2)) (i32.const 109))   ;; 'm'
      (then (return (i32.const 0))))
    (if (i32.ne (call $byte_at (local.get $s) (i32.const 3)) (i32.const 111))   ;; 'o'
      (then (return (i32.const 0))))
    (if (i32.ne (call $byte_at (local.get $s) (i32.const 4)) (i32.const 114))   ;; 'r'
      (then (return (i32.const 0))))
    (if (i32.ne (call $byte_at (local.get $s) (i32.const 5)) (i32.const 121))   ;; 'y'
      (then (return (i32.const 0))))
    (if (i32.ne (call $byte_at (local.get $s) (i32.const 6)) (i32.const 95))    ;; '_'
      (then (return (i32.const 0))))
    (i32.const 1))

  ;; $emit_memory_op_wasm — given op_name "memory_<op>", emit the
  ;; corresponding raw WASM instruction. Args already on stack from
  ;; $ec6_emit_args. Drift refused: 1 (no vtable; sequential byte-
  ;; comparison); 6 (uniform struct-size dispatch on op suffix).
  (func $emit_memory_op_wasm (param $op_name i32)
    (local $slen i32) (local $b7 i32) (local $b8 i32)
    (local.set $slen (call $str_len (local.get $op_name)))
    ;; "memory_" is 7 bytes; suffix starts at byte 7.
    ;; load_i32 (4 bytes after prefix) → suffix "load_i32" (8 bytes total).
    ;; load_i8  (3 bytes after prefix) → suffix "load_i8"  (7 bytes total).
    ;; store_i32 → suffix "store_i32" (9 bytes total).
    ;; store_i8  → suffix "store_i8"  (8 bytes total).
    ;; Discriminate via byte 7 ('l' or 's') and total length.
    (local.set $b7 (call $byte_at (local.get $op_name) (i32.const 7)))
    (if (i32.eq (local.get $b7) (i32.const 108))   ;; 'l' — load_*
      (then
        ;; suffix length: slen - 7. 8 = load_i32, 7 = load_i8.
        (if (i32.eq (local.get $slen) (i32.const 15))   ;; memory_load_i32
          (then
            (call $emit_str_lit_i32_load_offset_0)
            (return)))
        (if (i32.eq (local.get $slen) (i32.const 14))   ;; memory_load_i8
          (then
            (call $emit_str_lit_i32_load8_u_offset_0)
            (return)))))
    (if (i32.eq (local.get $b7) (i32.const 115))   ;; 's' — store_*
      (then
        (if (i32.eq (local.get $slen) (i32.const 16))   ;; memory_store_i32
          (then
            (call $emit_str_lit_i32_store_offset_0)
            (return)))
        (if (i32.eq (local.get $slen) (i32.const 15))   ;; memory_store_i8
          (then
            (call $emit_str_lit_i32_store8_offset_0)
            (return))))))

  ;; Raw WAT instruction emitters — each emits one canonical instr.
  (func $emit_str_lit_i32_load_offset_0
    (call $emit_byte (i32.const 40))                    ;; '('
    (call $emit_byte (i32.const 105)) (call $emit_byte (i32.const 51))    ;; 'i' '3'
    (call $emit_byte (i32.const 50)) (call $emit_byte (i32.const 46))    ;; '2' '.'
    (call $emit_byte (i32.const 108)) (call $emit_byte (i32.const 111))   ;; 'l' 'o'
    (call $emit_byte (i32.const 97)) (call $emit_byte (i32.const 100))    ;; 'a' 'd'
    (call $emit_byte (i32.const 41)))                    ;; ')'

  (func $emit_str_lit_i32_load8_u_offset_0
    (call $emit_byte (i32.const 40))
    (call $emit_byte (i32.const 105)) (call $emit_byte (i32.const 51))
    (call $emit_byte (i32.const 50)) (call $emit_byte (i32.const 46))
    (call $emit_byte (i32.const 108)) (call $emit_byte (i32.const 111))
    (call $emit_byte (i32.const 97)) (call $emit_byte (i32.const 100))
    (call $emit_byte (i32.const 56)) (call $emit_byte (i32.const 95))     ;; '8' '_'
    (call $emit_byte (i32.const 117))                                     ;; 'u'
    (call $emit_byte (i32.const 41)))

  ;; Stores follow up with (i32.const 0) — Mentl's store ops return ()
  ;; semantically but WASM i32.store returns nothing. The unit-sentinel
  ;; gives downstream local.set / let-bind a value to consume.
  (func $emit_str_lit_i32_store_offset_0
    (call $emit_byte (i32.const 40))
    (call $emit_byte (i32.const 105)) (call $emit_byte (i32.const 51))
    (call $emit_byte (i32.const 50)) (call $emit_byte (i32.const 46))
    (call $emit_byte (i32.const 115)) (call $emit_byte (i32.const 116))   ;; 's' 't'
    (call $emit_byte (i32.const 111)) (call $emit_byte (i32.const 114))   ;; 'o' 'r'
    (call $emit_byte (i32.const 101))                                     ;; 'e'
    (call $emit_byte (i32.const 41))
    (call $emit_i32_const (i32.const 0)))

  (func $emit_str_lit_i32_store8_offset_0
    (call $emit_byte (i32.const 40))
    (call $emit_byte (i32.const 105)) (call $emit_byte (i32.const 51))
    (call $emit_byte (i32.const 50)) (call $emit_byte (i32.const 46))
    (call $emit_byte (i32.const 115)) (call $emit_byte (i32.const 116))
    (call $emit_byte (i32.const 111)) (call $emit_byte (i32.const 114))
    (call $emit_byte (i32.const 101)) (call $emit_byte (i32.const 56))    ;; 'e' '8'
    (call $emit_byte (i32.const 41))
    (call $emit_i32_const (i32.const 0)))

  ;; $starts_with_wasi — checks if a length-prefixed Mentl string
  ;; starts with bytes "wasi_" (5 bytes).
  (func $starts_with_wasi (param $s i32) (result i32)
    (local $slen i32)
    (local.set $slen (call $str_len (local.get $s)))
    (if (i32.lt_u (local.get $slen) (i32.const 5))
      (then (return (i32.const 0))))
    (if (i32.ne (call $byte_at (local.get $s) (i32.const 0)) (i32.const 119))   ;; 'w'
      (then (return (i32.const 0))))
    (if (i32.ne (call $byte_at (local.get $s) (i32.const 1)) (i32.const 97))    ;; 'a'
      (then (return (i32.const 0))))
    (if (i32.ne (call $byte_at (local.get $s) (i32.const 2)) (i32.const 115))   ;; 's'
      (then (return (i32.const 0))))
    (if (i32.ne (call $byte_at (local.get $s) (i32.const 3)) (i32.const 105))   ;; 'i'
      (then (return (i32.const 0))))
    (if (i32.ne (call $byte_at (local.get $s) (i32.const 4)) (i32.const 95))    ;; '_'
      (then (return (i32.const 0))))
    (i32.const 1))

  ;; $ec7_emit_call_dollar — emits `(call $<name>)` direct, NO `op_` prefix.
  (func $ec7_emit_call_dollar (param $name i32)
    (call $emit_byte (i32.const 40)) (call $emit_byte (i32.const 99))
    (call $emit_byte (i32.const 97)) (call $emit_byte (i32.const 108))
    (call $emit_byte (i32.const 108)) (call $emit_byte (i32.const 32))
    (call $emit_byte (i32.const 36))
    (call $emit_str (local.get $name))
    (call $emit_byte (i32.const 41)))

  ;; ─── $emit_levperform — LEvPerform tag 333 emit arm per §2.5 ───────
  ;; Per src/backends/wasm.mn:1554-1587 + H1 evidence reification:
  ;;   (local.get $__state)          ;; implicit __state arg for callee
  ;;   <args>                        ;; user args
  ;;   (local.get $__state)          ;; load state again for fn_idx read
  ;;   (i32.load offset=N)           ;; N = 8 + 4*body_capture_count + 4*slot
  ;;   (call_indirect (type $ft<argc+1>))
  ;;
  ;; THE LOAD-BEARING DRIFT 1 REFUSAL ARM. The fn_idx for the handler
  ;; arm sits at runtime in a FIELD on the closure record at offset
  ;; (8 + 4*body_capture_count + 4*slot) — evidence passing per Koka
  ;; JFP 2022, NOT vtable indirection.
  ;;
  ;; body_capture_count is read from emit-time state via
  ;; $emit_body_captures_count (set per-fn at fn-emit boundary by
  ;; $emit_set_body_context per chunk #1 emit/state.wat). Per
  ;; SUBSTRATE.md §I third truth "polymorphic minority" — evidence-
  ;; dispatched perform when row inference cannot ground the handler
  ;; stack at compile time.
  (func $emit_levperform (param $r i32)
    (local $args i32) (local $offset i32)
    (local.set $args (call $lexpr_levperform_args (local.get $r)))
    (local.set $offset
      (i32.add (i32.const 8)
        (i32.add
          (i32.mul (i32.const 4) (call $emit_body_captures_count))
          (i32.mul (i32.const 4) (call $lexpr_levperform_slot_idx (local.get $r))))))
    (call $el_emit_local_get_state)
    (call $ec6_emit_args (local.get $args))
    (call $el_emit_local_get_state)
    (call $el_emit_i32_load_offset (local.get $offset))
    (call $ec6_emit_call_indirect_ftN (call $len (local.get $args))))

  ;; ─── $emit_lmakeclosure — LMakeClosure tag 311 emit arm ─────────────
  ;; Hβ.emit.handler-fnref-substrate — Phase D closed here.
  ;; Per src/backends/wasm.mn:1207-1244 + H1 evidence reification.
  ;;
  ;; LMakeClosure(_h, LFn(fn_name,...), captures, ev_slots):
  ;;   closure record — __state IS this record:
  ;;     offset 0:           fn_ptr (i32) — $<fn_name>_idx table entry
  ;;     offset 4:           capture_count (i32) — nc, the evidence fence
  ;;     offset 8+4*i:       capture_i
  ;;     offset 8+4*nc+4*j:  ev_slot_j (handler arm fn table index)
  ;;
  ;; Handler IS state. Evidence slots ARE fields. One record, one story.
  ;; Drift 1 refusal: fn_ptr is an i32 field — NOT a vtable entry.
  (func $emit_lmakeclosure (param $r i32)
    (local $fn_r i32) (local $fn_name i32)
    (local $caps i32) (local $evs i32)
    (local $nc i32)   (local $ne i32)
    (local.set $fn_r    (call $lexpr_lmakeclosure_fn   (local.get $r)))
    (local.set $fn_name (call $lowfn_name (local.get $fn_r)))
    (local.set $caps    (call $lexpr_lmakeclosure_caps (local.get $r)))
    (local.set $evs     (call $lexpr_lmakeclosure_evs  (local.get $r)))
    (local.set $nc (call $len (local.get $caps)))
    (local.set $ne (call $len (local.get $evs)))
    ;; Alloc 8 + 4*(nc+ne) bytes → $state_tmp.
    (call $emit_alloc
      (i32.add (i32.const 8)
               (i32.mul (i32.const 4) (i32.add (local.get $nc) (local.get $ne))))
      (i32.const 2244))
    ;; Store fn_ptr at offset 0.
    (call $ec8_emit_local_get_state_tmp)
    (call $ec8_emit_global_get_name_idx (local.get $fn_name))
    (call $ec_emit_i32_store_offset (i32.const 0))
    ;; Store capture_count at offset 4 — the evidence fence.
    (call $ec8_emit_local_get_state_tmp)
    (call $emit_i32_const (local.get $nc))
    (call $ec_emit_i32_store_offset (i32.const 4))
    ;; Store captures at offsets 8, 12, 16, ...
    (call $ec8_emit_cap_stores (local.get $caps) (i32.const 8))
    ;; Store ev_slots at offsets 8+4*nc, 8+4*nc+4, ...
    (call $ec8_emit_cap_stores (local.get $evs)
      (i32.add (i32.const 8) (i32.mul (local.get $nc) (i32.const 4))))
    ;; Result: closure pointer on stack.
    (call $ec8_emit_local_get_state_tmp))

  ;; ─── $emit_lmakecontinuation — LMakeContinuation tag 312 emit arm ───
  ;; Per src/backends/wasm.mn:1247-1308 + H7 §4.2 multi-shot layout.
  ;;
  ;; LMakeContinuation(_h, LFn(resume_name,...), caps, evs, state_idx, ret_slot):
  ;;   continuation record — THE MENTL ORACLE SUBSTRATE at WAT:
  ;;     offset 0:             fn_ptr — resume_fn table index
  ;;     offset 4:             state_index — perform-site discriminator
  ;;     offset 8:             capture_count — nc, evidence fence
  ;;     offset 12+4*i:        capture_i
  ;;     offset 12+4*nc+4*j:   ev_slot_j
  ;;     offset 12+4*(nc+ne):  ret_slot — landing slot for resumed value
  ;;
  ;; Multi-shot: same record resumed multiple times. Mentl's exploration
  ;; forks here. Evidence-safe: ev_slots are fields, read at call_indirect.
  (func $emit_lmakecontinuation (param $r i32)
    (local $fn_r i32) (local $fn_name i32)
    (local $caps i32) (local $evs i32)
    (local $nc i32)   (local $ne i32)
    (local $state_idx i32) (local $ret_slot i32)
    (local.set $fn_r      (call $lexpr_lmakecontinuation_fn        (local.get $r)))
    (local.set $fn_name   (call $lowfn_name (local.get $fn_r)))
    (local.set $caps      (call $lexpr_lmakecontinuation_caps      (local.get $r)))
    (local.set $evs       (call $lexpr_lmakecontinuation_evs       (local.get $r)))
    (local.set $state_idx (call $lexpr_lmakecontinuation_state_idx (local.get $r)))
    (local.set $ret_slot  (call $lexpr_lmakecontinuation_ret_slot  (local.get $r)))
    (local.set $nc (call $len (local.get $caps)))
    (local.set $ne (call $len (local.get $evs)))
    ;; Alloc 16 + 4*(nc+ne) bytes (12 header + ret_slot = 16 base).
    (call $emit_alloc
      (i32.add (i32.const 16)
               (i32.mul (i32.const 4) (i32.add (local.get $nc) (local.get $ne))))
      (i32.const 2244))
    ;; Store fn_ptr at offset 0.
    (call $ec8_emit_local_get_state_tmp)
    (call $ec8_emit_global_get_name_idx (local.get $fn_name))
    (call $ec_emit_i32_store_offset (i32.const 0))
    ;; Store state_index at offset 4 (perform-site discriminator per H7 §4.2).
    (call $ec8_emit_local_get_state_tmp)
    (call $emit_i32_const (local.get $state_idx))
    (call $ec_emit_i32_store_offset (i32.const 4))
    ;; Store capture_count at offset 8.
    (call $ec8_emit_local_get_state_tmp)
    (call $emit_i32_const (local.get $nc))
    (call $ec_emit_i32_store_offset (i32.const 8))
    ;; Store captures at offsets 12, 16, 20, ...
    (call $ec8_emit_cap_stores (local.get $caps) (i32.const 12))
    ;; Store ev_slots at offsets 12+4*nc, ...
    (call $ec8_emit_cap_stores (local.get $evs)
      (i32.add (i32.const 12) (i32.mul (local.get $nc) (i32.const 4))))
    ;; Store ret_slot at offset 12+4*(nc+ne).
    (call $ec8_emit_local_get_state_tmp)
    (call $emit_i32_const (local.get $ret_slot))
    (call $ec_emit_i32_store_offset
      (i32.add (i32.const 12)
               (i32.mul (i32.const 4) (i32.add (local.get $nc) (local.get $ne)))))
    ;; Result: continuation pointer on stack.
    (call $ec8_emit_local_get_state_tmp))
