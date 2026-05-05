  ;; ═══ arena.wat — Build-time arena substrate (Tier 0 peer to alloc.wat) ═
  ;; Implements: Hβ-arena-substrate.md §1 (region layout) + §1.2 (three
  ;;             allocators) + §1.3 (reset primitives) + §4 (ownership-
  ;;             transfer at stage boundaries via $perm_promote).
  ;; Exports:    $perm_alloc $stage_alloc $fn_alloc
  ;;             $stage_reset $fn_reset $perm_promote
  ;; Uses:       $heap_ptr (Layer 0 shell — perm pointer)
  ;; Test:       bootstrap/test/runtime/arena_smoke.wat
  ;;
  ;; ─── The ultimate form per Anchor 0 + Anchor 5 ──────────────────────
  ;; Three EXPLICIT allocators. Caller-determined arena per site. NO
  ;; ambient state, NO dispatch global, NO if-chain — Anchor 5 ("memory
  ;; model is a handler swap") made physical at the CALL SITE, not at a
  ;; dispatcher. Each call site chooses its arena based on the lifetime
  ;; the caller knows about.
  ;;
  ;; This surpasses every borrowed pattern simultaneously:
  ;;   - No "current allocator" ambient state (refuses C/Rust drift mode 5
  ;;     where allocator is threaded through globals).
  ;;   - No dispatch indirection (refuses drift 1 vtable-shape; refuses
  ;;     drift 8 string-or-int-keyed routing).
  ;;   - Every allocation site is explicit about its lifetime — the type
  ;;     of allocator IS the lifetime annotation. Mirrors what refinement
  ;;     types over regions (post-L1 substrate) will discharge at compile
  ;;     time.
  ;;
  ;; ─── Linear memory partition (512 MiB total per Layer 0 shell line 93) ─
  ;;   [0, HEAP_BASE=4096)              sentinels + data segments
  ;;   [HEAP_BASE, 1 MiB)                reserved (Layer 0 globals)
  ;;   [1 MiB, 385 MiB)                  permanent heap ($heap_ptr from
  ;;                                     Layer 0 shell; long-lived: graph
  ;;                                     nodes, env entries, Ty/Reason
  ;;                                     records bound to graph state)
  ;;   [385 MiB, 481 MiB)                per-stage arena ($stage_arena_ptr;
  ;;                                     $stage_reset frees in O(1) at
  ;;                                     pipeline-stage transitions)
  ;;   [481 MiB, 512 MiB)                per-fn arena ($fn_arena_ptr;
  ;;                                     $fn_reset frees in O(1) at user-
  ;;                                     fn boundaries)
  ;;
  ;; Wheel Phase μ size (962 KB source; ~1646 top-level decls × per-fn
  ;; graph_fresh_ty cascades) demands substantial perm headroom. The
  ;; pre-Phase-μ 32 MiB layout was sized when src/+lib/ totaled
  ;; ~10 KLOC; the wheel grew through the Phase μ commits (Mentl +
  ;; cursor + multishot + threading + verify-smt + tutorials). Peer
  ;; follow-ups address the bump shape structurally:
  ;;   - Hβ.first-light.lexer-stage-alloc-retrofit (token stream
  ;;     parse-consumed; lift to $stage_alloc)
  ;;   - Hβ.first-light.infer-perm-pressure-substrate (audit
  ;;     graph_fresh_ty per-fn allocation rate)
  ;;
  ;; ─── Vocabulary lock ─────────────────────────────────────────────────
  ;; arena/region/stage/perm-promote. NEVER malloc/free/young-gen/old-gen
  ;; (C/Java drift refused per Hβ-arena §5).

  (global $stage_arena_ptr (mut i32) (i32.const 403701760))  ;; 385 MiB
  (global $fn_arena_ptr    (mut i32) (i32.const 504365056))  ;; 481 MiB

  ;; ─── $perm_alloc — long-lived; survives all stage/fn boundaries ────
  ;; Used for: graph GNodes, env entries, Ty/Reason records bound into
  ;; the graph, the parsed AST. Anything that must outlive the next
  ;; $stage_reset or $fn_reset.
  ;;
  ;; This is the V1 default — when in doubt, allocate perm. Existing
  ;; $alloc callers (graph.wat, env.wat, list.wat, etc.) reach this via
  ;; alloc.wat's stable $alloc alias.
  (func $perm_alloc (export "perm_alloc") (param $size i32) (result i32)
    (local $old i32)
    (local $next i32)
    (local.set $old (global.get $heap_ptr))
    (local.set $next
      (i32.and
        (i32.add
          (i32.add (local.get $old) (local.get $size))
          (i32.const 7))
        (i32.const -8)))                  ;; 8-byte alignment
    (if (i32.gt_u (local.get $next) (i32.const 403701760))  ;; 385 MiB
      (then (unreachable)))               ;; perm crosses into stage region
    (global.set $heap_ptr (local.get $next))
    (local.get $old))

  ;; ─── $stage_alloc — pipeline-stage-local; reset between stages ─────
  ;; Used for: infer's transient Reason chains, ResumeDiscipline records
  ;; not bound to a graph handle, generalize/instantiate substitution
  ;; maps, lower's LowExpr trees (consumed by emit before reset),
  ;; emit's per-fn local-var-name maps.
  ;;
  ;; Caller responsibility: anything allocated here must NOT be
  ;; referenced past the next $stage_reset(). Records that earn long-
  ;; lived status promote to perm via $perm_promote BEFORE the reset.
  (func $stage_alloc (export "stage_alloc") (param $size i32) (result i32)
    (local $old i32)
    (local $next i32)
    (local.set $old (global.get $stage_arena_ptr))
    (local.set $next
      (i32.and
        (i32.add
          (i32.add (local.get $old) (local.get $size))
          (i32.const 7))
        (i32.const -8)))
    (if (i32.gt_u (local.get $next) (i32.const 504365056))  ;; 481 MiB
      (then (unreachable)))               ;; stage crosses into fn region
    (global.set $stage_arena_ptr (local.get $next))
    (local.get $old))

  ;; ─── $fn_alloc — user-fn-local within a stage; reset between fns ───
  ;; Used for: state.wat's LOCAL_ENTRY/CAPTURE_ENTRY records, ev_slot
  ;; lists during $derive_ev_slots, per-fn closure synthesis intermediates
  ;; (params buffer, body LowExpr before LMakeClosure construction).
  ;;
  ;; Caller responsibility: anything allocated here must NOT be referenced
  ;; past the next $fn_reset(). Per-fn records typically have shorter
  ;; lifetime than per-stage records by definition.
  (func $fn_alloc (export "fn_alloc") (param $size i32) (result i32)
    (local $old i32)
    (local $next i32)
    (local.set $old (global.get $fn_arena_ptr))
    (local.set $next
      (i32.and
        (i32.add
          (i32.add (local.get $old) (local.get $size))
          (i32.const 7))
        (i32.const -8)))
    (if (i32.gt_u (local.get $next) (i32.const 536870912))  ;; 512 MiB
      (then (unreachable)))               ;; fn crosses linear-memory cap
    (global.set $fn_arena_ptr (local.get $next))
    (local.get $old))

  ;; ─── $stage_reset — frees ALL stage-local allocations in O(1) ──────
  ;; Called at cascade-stage transitions: $inka_infer → $inka_lower →
  ;; $inka_emit. Bumps $stage_arena_ptr back to STAGE_ARENA_START. Any
  ;; record allocated through $stage_alloc since the last reset is now
  ;; gone; its memory will be re-used by the next stage.
  (func $stage_reset (export "stage_reset")
    (global.set $stage_arena_ptr (i32.const 403701760)))  ;; 385 MiB

  ;; ─── $fn_reset — frees ALL fn-local allocations in O(1) ───────────
  ;; Called from $ls_reset_function (lower/state.wat) at the per-fn
  ;; boundary, and from infer's FnStmt walk-exit. Bumps $fn_arena_ptr
  ;; back to FN_ARENA_START.
  (func $fn_reset (export "fn_reset")
    (global.set $fn_arena_ptr (i32.const 504365056)))  ;; 481 MiB

  ;; ─── $perm_promote — ownership-transfer at stage boundary ─────────
  ;; Per Hβ-arena §4 ownership interrogation: stage-arena `own` →
  ;; perm `own` is the ownership-transfer made physical at the
  ;; allocator layer. Allocates fresh in perm; copies $size bytes
  ;; from $src; returns the new perm pointer.
  ;;
  ;; Used when a stage-allocated record has earned long-lived status
  ;; (e.g., a Ty about to be bound to a graph handle that survives
  ;; across stages). The original stage-allocated copy will be freed
  ;; at next $stage_reset(); the perm copy survives.
  (func $perm_promote (export "perm_promote") (param $src i32) (param $size i32) (result i32)
    (local $dst i32)
    (local $i i32)
    (local.set $dst (call $perm_alloc (local.get $size)))
    (local.set $i (i32.const 0))
    (block $done
      (loop $copy
        (br_if $done (i32.ge_u (local.get $i) (local.get $size)))
        (i32.store8
          (i32.add (local.get $dst) (local.get $i))
          (i32.load8_u (i32.add (local.get $src) (local.get $i))))
        (local.set $i (i32.add (local.get $i) (i32.const 1)))
        (br $copy)))
    (local.get $dst))
