  ;; ═══ cont.wat — multi-shot continuation substrate (Tier 2) ════════
  ;; Implements: Hβ §1.13 + H7 walkthrough — heap-captured continuation
  ;;             record for primitive #2's MultiShot resume discipline.
  ;; Exports:    $alloc_continuation,
  ;;             $cont_get_fn_index,    $cont_set_fn_index,
  ;;             $cont_get_state,       $cont_set_state,
  ;;             $cont_get_n_captures,
  ;;             $cont_get_capture,     $cont_set_capture,
  ;;             $cont_get_n_evidence,
  ;;             $cont_get_ev_slot,     $cont_set_ev_slot,
  ;;             $cont_get_ret_slot,    $cont_set_ret_slot
  ;; Uses:       $alloc (alloc.wat)
  ;; Test:       runtime_test/cont.wat
  ;;
  ;; ═══ HOT PATH — NOT MINORITY ═══════════════════════════════════════
  ;; Per insight #11 (continuous oracle = IC + one cached value):
  ;; Mentl IS speculative inference. She fires on every graph
  ;; mutation — every save (ultimate: every keystroke). Each fire
  ;; walks the Synth chain enumerating alternate realities through
  ;; enumerate_inhabitants @resume=MultiShot. Every Choice +
  ;; backtrack + race + arena_ms (replay_safe / fork_deny /
  ;; fork_copy) handler at runtime allocates + dispatches through
  ;; this substrate. Choice + backtrack composes to the search
  ;; substrate every domain crucible exercises (SAT / CSP / Prolog /
  ;; miniKanren / probabilistic sampling / MCMC / MCTS / N-queens).
  ;; This is the substrate that drives Mentl's continuous oracle
  ;; operation; it is the canonical multi-shot substrate.
  ;;
  ;; WasmFX (cont.new / suspend / resume in WebAssembly's stack-
  ;; switching proposal) is single-shot only in v1; multi-shot is
  ;; open issue WebAssembly/stack-switching#110 with no timeline.
  ;; Hand-WAT cont.wat IS the canonical multi-shot substrate, kept
  ;; forever per Hβ §0 reference-soundness-artifact discipline. Per
  ;; CLAUDE.md anchor: "Mentl bootstraps through Mentl" — no foreign-
  ;; runtime dependency on the substrate that drives Mentl.
  ;;
  ;; ═══ LAYOUT ════════════════════════════════════════════════════════
  ;; Per H7 §1.2 + §1.3:
  ;;
  ;;   offset  0:  fn_index       (i32 — funcref table index for resume_fn;
  ;;                                set at capture; dispatched via
  ;;                                call_indirect at resume; NOT a vtable
  ;;                                lookup — it is a FIELD on the record)
  ;;   offset  4:  state_index    (i32 — numbered state to enter when
  ;;                                resumed; the per-perform-site state
  ;;                                ordinal assigned at lower-time)
  ;;   offset  8:  n_captures     (i32 — header for the captures region)
  ;;   offset 12:  capture[0]     (i32)
  ;;   offset 16:  capture[1]     (i32)
  ;;    ...        ...
  ;;   off 12+4k:  n_evidence     (i32 — header for the evidence region;
  ;;                                k = n_captures)
  ;;    ...        evidence[i]    (i32 — function indices for polymorphic
  ;;                                effect dispatch; H1 evidence reification)
  ;;    ...        ret_slot       (i32 — where resume(v) writes v before
  ;;                                tail-calling fn_index via call_indirect;
  ;;                                read by resume_fn at the start of the
  ;;                                state's body, supplies the resumed value)
  ;;
  ;; Total size (bytes):
  ;;   12 (header: fn_index + state + n_captures)
  ;;   + 4*n_captures
  ;;   + 4 (n_evidence header)
  ;;   + 4*n_evidence
  ;;   + 4 (ret_slot)
  ;;
  ;; Per γ crystallization #8 (the heap has one story): allocated
  ;; through $alloc — same surface as closures (closure.wat), records
  ;; (record.wat), ADT variants, tuples, strings (str.wat), lists
  ;; (list.wat). Arena handlers (B.5 AM-arena-multishot) intercept
  ;; this $alloc at handler-install time post-L1 — replay_safe
  ;; allocates degenerate continuations + replays trail; fork_deny
  ;; rejects via T_ContinuationEscapes; fork_copy deep-copies
  ;; arena-scoped captures. cont.wat is policy-neutral; the policy
  ;; lives in the arena handler that wraps the allocation.
  ;;
  ;; ═══ DISPATCH ══════════════════════════════════════════════════════
  ;; Per Hβ §1.13 + H7 §1.5:
  ;;
  ;;   resume(v):
  ;;     1. (call $cont_set_ret_slot (cont) (v))
  ;;     2. (return_call_indirect (type $resume_sig)
  ;;          (cont) (call $cont_get_fn_index (cont)))
  ;;
  ;;   resume() (unit variant):
  ;;     1. (return_call_indirect (type $resume_sig)
  ;;          (cont) (call $cont_get_fn_index (cont)))
  ;;
  ;; Multi-shot loop (e.g. backtrack):
  ;;     for each option_i:
  ;;       checkpoint = $graph_push_checkpoint()
  ;;       attempt = call_indirect via cont.fn_index   ;; one resume
  ;;       if accepted: commit
  ;;       else: $graph_rollback(checkpoint); next
  ;;
  ;; Trail-based rollback (primitive #1's $graph_push_checkpoint /
  ;; $graph_rollback in graph.wat — Wave 2.C) bounds each
  ;; speculative resume; per-option captures are read-only in the
  ;; cont record, so multiple resumes are safe.

  ;; ─── Allocation ───────────────────────────────────────────────────

  ;; alloc_continuation: allocate a continuation struct sized for
  ;; n_captures + n_evidence. Caller fills fn_index, state_index,
  ;; captures[], evidences[], ret_slot via the accessors below.
  ;; Returns the cont pointer.
  (func $alloc_continuation (param $n_captures i32) (param $n_evidence i32) (result i32)
    (local $size i32) (local $ptr i32)
    ;; size = 12 (header) + 4*n_captures + 4 (n_evidence header) + 4*n_evidence + 4 (ret_slot)
    (local.set $size
      (i32.add
        (i32.add
          (i32.const 20)                                   ;; 12 + 4 + 4 = headers + ret_slot
          (i32.mul (local.get $n_captures) (i32.const 4)))
        (i32.mul (local.get $n_evidence) (i32.const 4))))
    (local.set $ptr (call $alloc (local.get $size)))
    ;; write n_captures header at offset 8
    (i32.store offset=8 (local.get $ptr) (local.get $n_captures))
    ;; write n_evidence header at offset 12 + 4*n_captures
    (i32.store
      (i32.add (local.get $ptr)
        (i32.add (i32.const 12) (i32.mul (local.get $n_captures) (i32.const 4))))
      (local.get $n_evidence))
    (local.get $ptr))

  ;; ─── Header Accessors ─────────────────────────────────────────────

  (func $cont_get_fn_index (param $cont i32) (result i32)
    (i32.load offset=0 (local.get $cont)))

  (func $cont_set_fn_index (param $cont i32) (param $fn_idx i32)
    (i32.store offset=0 (local.get $cont) (local.get $fn_idx)))

  (func $cont_get_state (param $cont i32) (result i32)
    (i32.load offset=4 (local.get $cont)))

  (func $cont_set_state (param $cont i32) (param $state i32)
    (i32.store offset=4 (local.get $cont) (local.get $state)))

  (func $cont_get_n_captures (param $cont i32) (result i32)
    (i32.load offset=8 (local.get $cont)))

  (func $cont_get_n_evidence (param $cont i32) (result i32)
    (i32.load
      (i32.add (local.get $cont)
        (i32.add (i32.const 12)
          (i32.mul (call $cont_get_n_captures (local.get $cont)) (i32.const 4))))))

  ;; ─── Capture Slot Accessors ───────────────────────────────────────
  ;; Captures live in [offset 12, offset 12+4*n_captures). Index i
  ;; lands at offset 12 + 4*i. No bounds check at this level —
  ;; emit-time discipline guarantees i < n_captures.

  (func $cont_get_capture (param $cont i32) (param $i i32) (result i32)
    (i32.load
      (i32.add (local.get $cont)
        (i32.add (i32.const 12) (i32.mul (local.get $i) (i32.const 4))))))

  (func $cont_set_capture (param $cont i32) (param $i i32) (param $val i32)
    (i32.store
      (i32.add (local.get $cont)
        (i32.add (i32.const 12) (i32.mul (local.get $i) (i32.const 4))))
      (local.get $val)))

  ;; ─── Evidence Slot Accessors ──────────────────────────────────────
  ;; Evidence slots live at offset 12 + 4*n_captures + 4 + 4*i for the
  ;; i-th evidence (the +4 skips past the n_evidence header at
  ;; 12 + 4*n_captures). Per H1 evidence reification: each evidence
  ;; slot is a function-pointer (funcref table index) for polymorphic
  ;; effect dispatch.

  (func $cont_get_ev_slot (param $cont i32) (param $i i32) (result i32)
    (local $base i32) (local $n_caps i32)
    (local.set $n_caps (call $cont_get_n_captures (local.get $cont)))
    ;; base = cont + 12 + 4*n_captures + 4 + 4*i
    (local.set $base
      (i32.add (local.get $cont)
        (i32.add (i32.const 16)
          (i32.add (i32.mul (local.get $n_caps) (i32.const 4))
                   (i32.mul (local.get $i)      (i32.const 4))))))
    (i32.load (local.get $base)))

  (func $cont_set_ev_slot (param $cont i32) (param $i i32) (param $fn_idx i32)
    (local $base i32) (local $n_caps i32)
    (local.set $n_caps (call $cont_get_n_captures (local.get $cont)))
    (local.set $base
      (i32.add (local.get $cont)
        (i32.add (i32.const 16)
          (i32.add (i32.mul (local.get $n_caps) (i32.const 4))
                   (i32.mul (local.get $i)      (i32.const 4))))))
    (i32.store (local.get $base) (local.get $fn_idx)))

  ;; ─── Ret-Slot Accessors ───────────────────────────────────────────
  ;; ret_slot lives at the END of the struct: offset
  ;; 12 + 4*n_captures + 4 + 4*n_evidence + 0.
  ;; resume(v) writes v here before dispatching; resume_fn reads here
  ;; to obtain the resumed value at state-entry time.

  (func $cont_get_ret_slot (param $cont i32) (result i32)
    (local $base i32) (local $n_caps i32) (local $n_ev i32)
    (local.set $n_caps (call $cont_get_n_captures (local.get $cont)))
    (local.set $n_ev   (call $cont_get_n_evidence (local.get $cont)))
    (local.set $base
      (i32.add (local.get $cont)
        (i32.add (i32.const 16)
          (i32.add (i32.mul (local.get $n_caps) (i32.const 4))
                   (i32.mul (local.get $n_ev)   (i32.const 4))))))
    (i32.load (local.get $base)))

  (func $cont_set_ret_slot (param $cont i32) (param $val i32)
    (local $base i32) (local $n_caps i32) (local $n_ev i32)
    (local.set $n_caps (call $cont_get_n_captures (local.get $cont)))
    (local.set $n_ev   (call $cont_get_n_evidence (local.get $cont)))
    (local.set $base
      (i32.add (local.get $cont)
        (i32.add (i32.const 16)
          (i32.add (i32.mul (local.get $n_caps) (i32.const 4))
                   (i32.mul (local.get $n_ev)   (i32.const 4))))))
    (i32.store (local.get $base) (local.get $val)))
