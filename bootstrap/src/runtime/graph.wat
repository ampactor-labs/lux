  ;; ═══ graph.wat — Graph substrate (Tier 3) ═════════════════════════
  ;; Implements: Hβ §1.2 + spec 00 (graph.md) — flat-array graph with
  ;;             O(1) chase + epoch-monotonic + trail-backed rollback +
  ;;             per-module overlays. Substrate primitive #1 (Graph + Env).
  ;; Exports:    $graph_init,
  ;;             $graph_fresh_ty, $graph_fresh_row,
  ;;             $graph_chase, $graph_node_at,
  ;;             $graph_bind, $graph_bind_row,
  ;;             $graph_push_checkpoint, $graph_rollback,
  ;;             $graph_epoch, $graph_next_handle,
  ;;             $gnode_kind, $gnode_reason, $gnode_make,
  ;;             $node_kind_tag, $is_nbound, $is_nfree,
  ;;             $is_nrowbound, $is_nrowfree, $is_nerrorhole,
  ;;             $node_kind_payload
  ;; Uses:       $alloc (alloc.wat), $make_record/$record_get/$record_set
  ;;             (record.wat), $make_list/$list_index/$list_set/
  ;;             $list_extend_to (list.wat), $heap_base (Layer 0 shell)
  ;; Test:       runtime_test/graph.wat
  ;;
  ;; ═══ DESIGN ═══════════════════════════════════════════════════════
  ;; Per spec 00 + src/graph.mn (the wheel; this WAT IS the seed
  ;; transcription per Anchor 4 "build the wheel; never wrap the axle"):
  ;;
  ;; State lives in MODULE-LEVEL GLOBALS — pointers into heap regions
  ;; allocated lazily via $alloc on first use. The seed's HM inference
  ;; (Hβ.infer — Wave 2.E) calls these primitives directly to track
  ;; type-variable + row-variable state during compilation. The
  ;; COMPILED output of src/graph.mn (post-L1 wheel) builds its own
  ;; effect-handler-shaped graph_handler with state held in heap
  ;; closure records — different storage mechanism, identical algorithm,
  ;; never shares state with the seed's globals.
  ;;
  ;; Salsa 3.0 pattern (per spec 00 + DESIGN Ch 4):
  ;;   - Flat array of GNode entries; handle IS the index.
  ;;   - Trail = parallel flat buffer + length counter; append O(1)
  ;;     amortized via doubling; rollback walks backward applying
  ;;     inverses, resets trail_len.
  ;;   - Epoch monotonic — bumps on every bind; never rolled back so
  ;;     query observers keyed on (handle, epoch) correctly invalidate.
  ;;   - Per-module overlays — three parallel flat buffers
  ;;     (overlay_names / overlay_bufs / overlay_lens) per Hβ §1.2.
  ;;     (Overlay primitives deferred to Wave 2.C follow-up; this
  ;;     commit lands the core graph + trail substrate.)
  ;;
  ;; ═══ HEAP RECORD LAYOUTS ═══════════════════════════════════════════
  ;;
  ;; GNode (per spec 00 type GNode = GNode(NodeKind, Reason)):
  ;;   $make_record(GNODE_TAG=80, arity=2)
  ;;     offset 0:  tag = 80
  ;;     offset 4:  arity = 2
  ;;     offset 8:  field_0 = NodeKind (heap pointer)
  ;;     offset 12: field_1 = Reason (heap pointer; opaque to graph.wat)
  ;;
  ;; NodeKind variants (each uses $make_record(tag, arity)):
  ;;   NBound(Ty)         — tag=NBOUND_TAG=60       arity=1; field_0 = Ty ptr
  ;;   NFree(epoch)       — tag=NFREE_TAG=61        arity=1; field_0 = epoch i32
  ;;   NRowBound(EffRow)  — tag=NROWBOUND_TAG=62    arity=1; field_0 = EffRow ptr
  ;;   NRowFree(epoch)    — tag=NROWFREE_TAG=63     arity=1; field_0 = epoch i32
  ;;   NErrorHole(Reason) — tag=NERRORHOLE_TAG=64   arity=1; field_0 = Reason ptr
  ;;
  ;; Mutation variants (for trail entries):
  ;;   MFreshNode(handle)        — tag=MFRESHNODE_TAG=70  arity=1; field_0 = handle i32
  ;;   MSetNode(handle, oldnode) — tag=MSETNODE_TAG=71    arity=2; field_0 = handle, field_1 = old GNode ptr
  ;;   MSetRow(handle, oldnode)  — tag=MSETROW_TAG=72     arity=2; field_0 = handle, field_1 = old GNode ptr
  ;;
  ;; Tag allocation discipline (graph.wat private; reserved range 50-99
  ;; — chosen to avoid collision with TokenKind sentinels at 0-44 and
  ;; with closure tags allocated by Hβ.lower's emit pass):
  ;;   50-59  reserved for future graph-substrate variants (Reason
  ;;          tags, etc. — added when Hβ.infer needs them)
  ;;   60-69  NodeKind variants
  ;;   70-79  Mutation variants
  ;;   80-89  GNode + future graph-record wrappers
  ;;   90-99  reserved for future overlay-substrate records
  ;;
  ;; ═══ CHASE SEMANTICS ═══════════════════════════════════════════════
  ;; Per spec 00 + src/graph.mn chase_node:
  ;;   $graph_chase(handle) walks NBound/NRowBound links with cycle
  ;;   bound at depth 100 (defensive — cycles trigger E_OccursCheck at
  ;;   bind time; this is the runtime safety net). Returns the terminal
  ;;   GNode pointer (which may be NFree, NRowFree, NErrorHole, or the
  ;;   resolved NBound/NRowBound).
  ;;
  ;; This commit's chase implementation is the TIER-3 BASE: it walks
  ;; NBound/NRowBound directly without the inner Ty-variant inspection
  ;; that src/graph.mn's chase_node performs (which dispatches on
  ;; TVar/EfOpen for transitive resolution). The Tier-3 base is
  ;; correct for the common case (terminal NFree/NRowFree/NBound-with-
  ;; non-TVar/NRowBound-with-non-EfOpen); the transitive walk through
  ;; TVar/EfOpen lands when Hβ.lower (Wave 2.E) ships the Ty + EffRow
  ;; tag conventions that chase_node depends on.
  ;;
  ;; ═══ ROLLBACK SEMANTICS ═══════════════════════════════════════════
  ;; Per src/graph.mn revert_trail:
  ;;   Walk trail backwards from trail_len down to target_idx. Each
  ;;   mutation has a precise inverse:
  ;;     MSetNode(h, old) → restore nodes[h] to old
  ;;     MSetRow(h, old)  → restore nodes[h] to old
  ;;     MFreshNode(h)    → decrement next (un-allocate)
  ;;   Reset trail_len = target_idx; entries above are stale and get
  ;;   overwritten on next append. Epoch is NOT rolled back.
  ;;
  ;; The rollback supports Mentl's oracle (insight #11 — speculative
  ;; inference firing on every save). Per Mentl's discipline:
  ;; checkpoint → speculative writes → either commit (no rollback) or
  ;; rollback to checkpoint. Multi-shot resume cycles do this per
  ;; option. This is THE substrate the oracle's "hundreds of alternate
  ;; realities per second" runs on.

  ;; ─── Module-level globals (the seed's internal graph state) ──────
  ;; Allocated lazily on first call to $graph_init.
  (global $graph_nodes_ptr     (mut i32) (i32.const 0))   ;; pointer to flat list of GNode pointers
  (global $graph_next_handle_g (mut i32) (i32.const 0))   ;; next fresh handle to allocate
  (global $graph_epoch_g       (mut i32) (i32.const 0))   ;; epoch counter (bumps on every bind)
  (global $graph_trail_ptr     (mut i32) (i32.const 0))   ;; pointer to flat list of Mutation pointers
  (global $graph_trail_len_g   (mut i32) (i32.const 0))   ;; logical length of trail
  (global $graph_initialized   (mut i32) (i32.const 0))   ;; 1 once $graph_init has run

  ;; Initial node-buffer + trail-buffer capacities.
  ;; (Doubled on demand via $list_extend_to.)
  ;; 64 nodes + 256 trail entries gives a no-realloc start for small
  ;; modules; growth is amortized O(1) afterward.

  ;; ─── Initialization ─────────────────────────────────────────────────

  ;; $graph_init — lazy: idempotent. Allocates initial flat-list
  ;; buffers for nodes + trail; sets epoch = 0, next_handle = 0,
  ;; trail_len = 0. Subsequent calls are no-ops.
  (func $graph_init
    (if (global.get $graph_initialized) (then (return)))
    (global.set $graph_nodes_ptr   (call $make_list (i32.const 64)))
    (global.set $graph_trail_ptr   (call $make_list (i32.const 256)))
    (global.set $graph_next_handle_g (i32.const 0))
    (global.set $graph_epoch_g       (i32.const 0))
    (global.set $graph_trail_len_g   (i32.const 0))
    (global.set $graph_initialized   (i32.const 1)))

  ;; ─── NodeKind constructors ────────────────────────────────────────
  ;; Each allocates a record [tag][arity=1][payload]. payload is i32
  ;; (heap-pointer or epoch-int depending on variant).

  (func $node_kind_make_nbound (param $ty_ptr i32) (result i32)
    (local $r i32)
    (local.set $r (call $make_record (i32.const 60) (i32.const 1)))
    (call $record_set (local.get $r) (i32.const 0) (local.get $ty_ptr))
    (local.get $r))

  (func $node_kind_make_nfree (param $epoch i32) (result i32)
    (local $r i32)
    (local.set $r (call $make_record (i32.const 61) (i32.const 1)))
    (call $record_set (local.get $r) (i32.const 0) (local.get $epoch))
    (local.get $r))

  (func $node_kind_make_nrowbound (param $row_ptr i32) (result i32)
    (local $r i32)
    (local.set $r (call $make_record (i32.const 62) (i32.const 1)))
    (call $record_set (local.get $r) (i32.const 0) (local.get $row_ptr))
    (local.get $r))

  (func $node_kind_make_nrowfree (param $epoch i32) (result i32)
    (local $r i32)
    (local.set $r (call $make_record (i32.const 63) (i32.const 1)))
    (call $record_set (local.get $r) (i32.const 0) (local.get $epoch))
    (local.get $r))

  (func $node_kind_make_nerrorhole (param $reason_ptr i32) (result i32)
    (local $r i32)
    (local.set $r (call $make_record (i32.const 64) (i32.const 1)))
    (call $record_set (local.get $r) (i32.const 0) (local.get $reason_ptr))
    (local.get $r))

  ;; NodeKind tag accessor + predicates.
  (func $node_kind_tag (param $nk i32) (result i32)
    (call $tag_of (local.get $nk)))

  (func $is_nbound (param $nk i32) (result i32)
    (i32.eq (call $node_kind_tag (local.get $nk)) (i32.const 60)))

  (func $is_nfree (param $nk i32) (result i32)
    (i32.eq (call $node_kind_tag (local.get $nk)) (i32.const 61)))

  (func $is_nrowbound (param $nk i32) (result i32)
    (i32.eq (call $node_kind_tag (local.get $nk)) (i32.const 62)))

  (func $is_nrowfree (param $nk i32) (result i32)
    (i32.eq (call $node_kind_tag (local.get $nk)) (i32.const 63)))

  (func $is_nerrorhole (param $nk i32) (result i32)
    (i32.eq (call $node_kind_tag (local.get $nk)) (i32.const 64)))

  ;; NodeKind payload extractor — returns the single i32 payload field.
  ;; (For NBound: Ty ptr; NRowBound: EffRow ptr; NFree/NRowFree: epoch
  ;; int; NErrorHole: Reason ptr.) Caller dispatches on $node_kind_tag.
  (func $node_kind_payload (param $nk i32) (result i32)
    (call $record_get (local.get $nk) (i32.const 0)))

  ;; ─── GNode constructors + accessors ──────────────────────────────
  ;; GNode is a 2-field record wrapping (NodeKind, Reason).

  (func $gnode_make (param $nk i32) (param $reason i32) (result i32)
    (local $g i32) (local $promoted_reason i32)
    ;; Promote-on-bind: if the reason is stage-resident, deep-clone it
    ;; into perm so the next $stage_reset doesn't strand the GNode's
    ;; reason-field pointing at recycled memory. Idempotent on perm-
    ;; resident inputs ($reason_promote_deep returns the input
    ;; unchanged via the $reason_in_perm short-circuit).
    ;;
    ;; Per Hβ-first-light.infer-perm-pressure-substrate.md §7
    ;; (promote-on-bind protocol) + arena.wat §4 (ownership-transfer
    ;; at stage boundary). The GNode itself is allocated perm (via
    ;; $make_record → $alloc → $perm_alloc) since GNodes survive across
    ;; stages by definition (graph state is the perm-bound substrate).
    ;;
    ;; Null-Reason guard: $graph_node_at:247 synthesizes GNodes with
    ;; reason=0 when the handle is out-of-range. $reason_promote_deep
    ;; would trap on $tag_of(0) (reading from address 0). The i32.eqz
    ;; guard preserves the existing "reason ptr 0 = no reason recorded"
    ;; convention.
    (local.set $promoted_reason
      (if (result i32) (i32.eqz (local.get $reason))
        (then (i32.const 0))
        (else (call $reason_promote_deep (local.get $reason)))))
    (local.set $g (call $make_record (i32.const 80) (i32.const 2)))
    (call $record_set (local.get $g) (i32.const 0) (local.get $nk))
    (call $record_set (local.get $g) (i32.const 1) (local.get $promoted_reason))
    (local.get $g))

  (func $gnode_kind (param $g i32) (result i32)
    (call $record_get (local.get $g) (i32.const 0)))

  (func $gnode_reason (param $g i32) (result i32)
    (call $record_get (local.get $g) (i32.const 1)))

  ;; ─── Mutation constructors (trail entries) ───────────────────────

  (func $mutation_make_fresh (param $handle i32) (result i32)
    (local $m i32)
    (local.set $m (call $make_record (i32.const 70) (i32.const 1)))
    (call $record_set (local.get $m) (i32.const 0) (local.get $handle))
    (local.get $m))

  (func $mutation_make_set_node (param $handle i32) (param $old_gnode i32) (result i32)
    (local $m i32)
    (local.set $m (call $make_record (i32.const 71) (i32.const 2)))
    (call $record_set (local.get $m) (i32.const 0) (local.get $handle))
    (call $record_set (local.get $m) (i32.const 1) (local.get $old_gnode))
    (local.get $m))

  (func $mutation_make_set_row (param $handle i32) (param $old_gnode i32) (result i32)
    (local $m i32)
    (local.set $m (call $make_record (i32.const 72) (i32.const 2)))
    (call $record_set (local.get $m) (i32.const 0) (local.get $handle))
    (call $record_set (local.get $m) (i32.const 1) (local.get $old_gnode))
    (local.get $m))

  ;; ─── Read primitives ─────────────────────────────────────────────

  ;; $graph_node_at — direct read of GNode at handle. Defensive: out-of-
  ;; range handles synthesize NFree(0) so the seed never traps on a
  ;; well-formed-but-not-yet-bound handle. Per src/graph.mn graph_node_at.
  (func $graph_node_at (param $handle i32) (result i32)
    (call $graph_init)  ;; idempotent
    (if (i32.ge_u (local.get $handle) (call $len (global.get $graph_nodes_ptr)))
      (then
        (return
          (call $gnode_make
            (call $node_kind_make_nfree (i32.const 0))
            (i32.const 0)))))   ;; reason ptr 0 = "no reason recorded"
    (call $list_index (global.get $graph_nodes_ptr) (local.get $handle)))

  ;; $graph_chase — Tier-3 BASE: walks NBound/NRowBound links until
  ;; terminal. Cycle bound at depth 100. Returns the terminal GNode
  ;; pointer.
  ;;
  ;; This base implementation does NOT yet decompose Ty/EffRow inner
  ;; structure to follow TVar(handle) / EfOpen(_, handle) transitively.
  ;; That dispatch lives in chase_node per src/graph.mn and depends on
  ;; the Ty + EffRow tag conventions that Hβ.lower (Wave 2.E) emits.
  ;; For now, NBound terminals return the GNode as-is; the caller
  ;; (Hβ.infer) chases through Ty structure via its own Ty-variant
  ;; dispatch.
  (func $graph_chase (param $handle i32) (result i32)
    (call $graph_chase_loop (local.get $handle) (i32.const 0)))

  (func $graph_chase_loop (param $handle i32) (param $depth i32) (result i32)
    (local $g i32) (local $nk i32) (local $tag i32)
    (local $ty i32) (local $ty_tag i32)
    ;; depth bound — cycle safety net
    (if (i32.gt_u (local.get $depth) (i32.const 100))
      (then
        (return
          (call $gnode_make
            (call $node_kind_make_nerrorhole (i32.const 0))
            (i32.const 0)))))
    (local.set $g (call $graph_node_at (local.get $handle)))
    (local.set $nk (call $gnode_kind (local.get $g)))
    (local.set $tag (call $node_kind_tag (local.get $nk)))
    ;; NBound — per src/graph.mn:269-272 chase_node: if the payload is
    ;; TVar(next), follow transitively. Otherwise return the GNode.
    ;; This is the load-bearing fix: without it, two handles bound to
    ;; TVar(each_other) create an infinite unify→unify_types→unify cycle.
    (if (i32.eq (local.get $tag) (i32.const 60))   ;; NBOUND
      (then
        (local.set $ty (call $node_kind_payload (local.get $nk)))
        (local.set $ty_tag (call $ty_tag (local.get $ty)))
        (if (i32.eq (local.get $ty_tag) (i32.const 104))  ;; TVar
          (then
            (return (call $graph_chase_loop
              (call $ty_tvar_handle (local.get $ty))
              (i32.add (local.get $depth) (i32.const 1))))))
        (return (local.get $g))))
    ;; NRowBound terminal — return as-is (row transitive walk is the
    ;; named Hβ.infer.row-normalize follow-up)
    (if (i32.eq (local.get $tag) (i32.const 62))   ;; NROWBOUND
      (then (return (local.get $g))))
    ;; NFree / NRowFree / NErrorHole all terminal
    (local.get $g))

  ;; $graph_epoch — read current epoch. Query observers key on (handle, epoch).
  (func $graph_epoch (result i32)
    (call $graph_init)
    (global.get $graph_epoch_g))

  ;; $graph_next_handle — read next-fresh-handle counter (for query/diagnostics).
  (func $graph_next_handle (result i32)
    (call $graph_init)
    (global.get $graph_next_handle_g))

  ;; ─── Write primitives ────────────────────────────────────────────

  ;; $graph_fresh_ty — allocate fresh type-variable handle.
  ;; Returns the new handle. Records MFreshNode in trail. Tagged
  ;; NFree(epoch).
  (func $graph_fresh_ty (param $reason i32) (result i32)
    (local $handle i32) (local $nk i32) (local $g i32)
    (call $graph_init)
    (local.set $handle (global.get $graph_next_handle_g))
    (local.set $nk (call $node_kind_make_nfree (global.get $graph_epoch_g)))
    (local.set $g  (call $gnode_make (local.get $nk) (local.get $reason)))
    ;; Extend nodes buffer + write the new GNode at index = handle.
    (global.set $graph_nodes_ptr
      (call $list_set
        (call $list_extend_to (global.get $graph_nodes_ptr)
                              (i32.add (local.get $handle) (i32.const 1)))
        (local.get $handle)
        (local.get $g)))
    ;; Append MFreshNode to trail.
    (call $trail_append (call $mutation_make_fresh (local.get $handle)))
    ;; Bump next.
    (global.set $graph_next_handle_g
      (i32.add (local.get $handle) (i32.const 1)))
    (local.get $handle))

  ;; $graph_fresh_row — allocate fresh row-variable handle.
  ;; Same shape as $graph_fresh_ty but tagged NRowFree(epoch).
  (func $graph_fresh_row (param $reason i32) (result i32)
    (local $handle i32) (local $nk i32) (local $g i32)
    (call $graph_init)
    (local.set $handle (global.get $graph_next_handle_g))
    (local.set $nk (call $node_kind_make_nrowfree (global.get $graph_epoch_g)))
    (local.set $g  (call $gnode_make (local.get $nk) (local.get $reason)))
    (global.set $graph_nodes_ptr
      (call $list_set
        (call $list_extend_to (global.get $graph_nodes_ptr)
                              (i32.add (local.get $handle) (i32.const 1)))
        (local.get $handle)
        (local.get $g)))
    (call $trail_append (call $mutation_make_fresh (local.get $handle)))
    (global.set $graph_next_handle_g
      (i32.add (local.get $handle) (i32.const 1)))
    (local.get $handle))

  ;; $graph_bind — bind handle to type. Records MSetNode(handle, old_gnode)
  ;; in trail. Bumps epoch.
  ;;
  ;; PRE-CONDITION: caller has run occurs check via $occurs_in (in
  ;; future Hβ.infer Ty-substrate chunk) before invoking. graph.wat
  ;; doesn't perform occurs check here because it doesn't know Ty
  ;; structure; per src/graph.mn graph_bind's occurs_in lives in the
  ;; same compilation unit.
  (func $graph_bind (param $handle i32) (param $ty_ptr i32) (param $reason i32)
    (local $old_gnode i32) (local $new_nk i32) (local $new_g i32)
    (call $graph_init)
    (local.set $old_gnode (call $graph_node_at (local.get $handle)))
    (local.set $new_nk (call $node_kind_make_nbound (local.get $ty_ptr)))
    (local.set $new_g  (call $gnode_make (local.get $new_nk) (local.get $reason)))
    (global.set $graph_nodes_ptr
      (call $list_set
        (call $list_extend_to (global.get $graph_nodes_ptr)
                              (i32.add (local.get $handle) (i32.const 1)))
        (local.get $handle)
        (local.get $new_g)))
    (call $trail_append
      (call $mutation_make_set_node (local.get $handle) (local.get $old_gnode)))
    (global.set $graph_epoch_g
      (i32.add (global.get $graph_epoch_g) (i32.const 1))))

  ;; $graph_bind_row — bind handle to row.
  (func $graph_bind_row (param $handle i32) (param $row_ptr i32) (param $reason i32)
    (local $old_gnode i32) (local $new_nk i32) (local $new_g i32)
    (call $graph_init)
    (local.set $old_gnode (call $graph_node_at (local.get $handle)))
    (local.set $new_nk (call $node_kind_make_nrowbound (local.get $row_ptr)))
    (local.set $new_g  (call $gnode_make (local.get $new_nk) (local.get $reason)))
    (global.set $graph_nodes_ptr
      (call $list_set
        (call $list_extend_to (global.get $graph_nodes_ptr)
                              (i32.add (local.get $handle) (i32.const 1)))
        (local.get $handle)
        (local.get $new_g)))
    (call $trail_append
      (call $mutation_make_set_row (local.get $handle) (local.get $old_gnode)))
    (global.set $graph_epoch_g
      (i32.add (global.get $graph_epoch_g) (i32.const 1))))

  ;; $graph_bind_kind — bind handle to an already-constructed NodeKind
  ;; record (NErrorHole / NBound / etc). Used by emit_diag.wat's helpers
  ;; that need to bind a handle to NErrorHole(reason) directly per spec
  ;; 04 §Error handling Hazel productive-under-error pattern.
  ;;
  ;; Records MSetNode(handle, old_gnode) in trail; bumps epoch. Per the
  ;; same trail discipline as $graph_bind, but does NOT wrap the second
  ;; arg in NBound — caller has already constructed the desired NodeKind
  ;; via $node_kind_make_nerrorhole / etc.
  (func $graph_bind_kind (param $handle i32) (param $kind i32) (param $reason i32)
    (local $old_gnode i32) (local $new_g i32)
    (call $graph_init)
    (local.set $old_gnode (call $graph_node_at (local.get $handle)))
    (local.set $new_g (call $gnode_make (local.get $kind) (local.get $reason)))
    (global.set $graph_nodes_ptr
      (call $list_set
        (call $list_extend_to (global.get $graph_nodes_ptr)
                              (i32.add (local.get $handle) (i32.const 1)))
        (local.get $handle)
        (local.get $new_g)))
    (call $trail_append
      (call $mutation_make_set_node (local.get $handle) (local.get $old_gnode)))
    (global.set $graph_epoch_g
      (i32.add (global.get $graph_epoch_g) (i32.const 1))))

  ;; ─── Trail buffer ─────────────────────────────────────────────────
  ;; Append O(1) amortized via $list_extend_to + $list_set. trail_len
  ;; counter; entries above counter are stale (overwritten on next append).

  (func $trail_append (param $mutation i32)
    (global.set $graph_trail_ptr
      (call $list_set
        (call $list_extend_to (global.get $graph_trail_ptr)
                              (i32.add (global.get $graph_trail_len_g) (i32.const 1)))
        (global.get $graph_trail_len_g)
        (local.get $mutation)))
    (global.set $graph_trail_len_g
      (i32.add (global.get $graph_trail_len_g) (i32.const 1))))

  ;; ─── Checkpoint + rollback ────────────────────────────────────────
  ;; $graph_push_checkpoint returns current trail_len; caller stores
  ;; this as the rollback target. Multi-shot oracle loops call this
  ;; per option. Per src/graph.mn + insight #11.
  (func $graph_push_checkpoint (result i32)
    (call $graph_init)
    (global.get $graph_trail_len_g))

  ;; $graph_rollback — walks trail backwards from trail_len down to
  ;; target_idx, applying inverse of each mutation. Resets trail_len.
  ;; Epoch is NOT rolled back (per spec 00 invariant 2).
  (func $graph_rollback (param $target_idx i32)
    (local $cur i32) (local $idx i32) (local $mutation i32) (local $tag i32)
    (local $handle i32) (local $old_gnode i32)
    (call $graph_init)
    (local.set $cur (global.get $graph_trail_len_g))
    (block $done
      (loop $back
        (br_if $done (i32.le_u (local.get $cur) (local.get $target_idx)))
        (local.set $idx (i32.sub (local.get $cur) (i32.const 1)))
        (local.set $mutation
          (call $list_index (global.get $graph_trail_ptr) (local.get $idx)))
        (local.set $tag (call $tag_of (local.get $mutation)))
        ;; MSetNode (71) — restore nodes[h] to old
        (if (i32.eq (local.get $tag) (i32.const 71))
          (then
            (local.set $handle (call $record_get (local.get $mutation) (i32.const 0)))
            (local.set $old_gnode (call $record_get (local.get $mutation) (i32.const 1)))
            (drop (call $list_set (global.get $graph_nodes_ptr)
                                  (local.get $handle)
                                  (local.get $old_gnode)))))
        ;; MSetRow (72) — same shape, restore nodes[h] to old
        (if (i32.eq (local.get $tag) (i32.const 72))
          (then
            (local.set $handle (call $record_get (local.get $mutation) (i32.const 0)))
            (local.set $old_gnode (call $record_get (local.get $mutation) (i32.const 1)))
            (drop (call $list_set (global.get $graph_nodes_ptr)
                                  (local.get $handle)
                                  (local.get $old_gnode)))))
        ;; MFreshNode (70) — decrement next (un-allocate)
        (if (i32.eq (local.get $tag) (i32.const 70))
          (then
            (global.set $graph_next_handle_g
              (i32.sub (global.get $graph_next_handle_g) (i32.const 1)))))
        (local.set $cur (local.get $idx))
        (br $back)))
    (global.set $graph_trail_len_g (local.get $target_idx)))
