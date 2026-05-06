  ;; ═══ record.wat — record/tuple + ADT match helpers (Tier 1) ═══════
  ;; Implements: Hβ §1.8 (tuple) + §1.9 (record) + §1.5 (ADT match
  ;;             discriminator via heap-base threshold).
  ;; Exports:    $make_record, $record_get, $record_set,
  ;;             $tag_of, $is_sentinel
  ;; Uses:       $alloc (alloc.wat), $heap_base (Layer 0 shell)
  ;; Test:       runtime_test/record.wat
  ;;
  ;; Layout per H2-record-construction.md + H2.3-nominal-records.md +
  ;; H3-adt-instantiation.md:
  ;;   [tag:i32][arity:i32][field_0:i32]...[field_N:i32]
  ;;
  ;; The heap-base discriminator (HEAP_BASE = 4096) lets nullary-
  ;; sentinel ADT variants live in the [0, 4096) region and fielded
  ;; variants live at >= 4096; $tag_of dispatches on this threshold.
  ;; Per HB-bool-transition.md + γ crystallization #8.
  ;;
  ;; H6 wildcard discipline: every load-bearing ADT match is
  ;; exhaustive; no `_ => fabricated_default` arms.

  ;; ─── Record/Tuple Primitives ──────────────────────────────────────
  ;; Layout: [tag:i32][arity:i32][fields...]

  (func $make_record (param $tag i32) (param $arity i32) (result i32)
    (local $ptr i32)
    (local.set $ptr (call $alloc
      (i32.add (i32.const 8) (i32.mul (local.get $arity) (i32.const 4)))))
    (i32.store (local.get $ptr) (local.get $tag))
    (i32.store offset=4 (local.get $ptr) (local.get $arity))
    (local.get $ptr))

  ;; ─── $make_record_stage — record allocated in stage arena ─────────
  ;; Peer of $make_record. Routes through $stage_alloc instead of
  ;; $alloc/$perm_alloc. Caller responsibility per arena.wat §1.2:
  ;; the returned record's lifetime is bounded by the next
  ;; $stage_reset() call. If the record earns persistence (e.g., bound
  ;; to a graph node via $gnode_make), the caller MUST $perm_promote
  ;; before the reset — see arena.wat:144-167 + $reason_promote_deep
  ;; below + $gnode_make in graph.wat for the canonical promote-on-
  ;; bind pattern.
  ;;
  ;; Hβ.first-light.infer-perm-pressure-substrate primary substrate.
  ;; Per the §A pre-audit ratio: most Reasons are transient (consumed
  ;; once for diagnostics or wrapped into another Reason that itself
  ;; becomes transient); routing them through this function reclaims
  ;; perm headroom for graph-bound Reasons + Ty + env entries that
  ;; genuinely need long-lived storage.
  (func $make_record_stage (param $tag i32) (param $arity i32) (result i32)
    (local $ptr i32)
    (local.set $ptr (call $stage_alloc
      (i32.add (i32.const 8) (i32.mul (local.get $arity) (i32.const 4)))))
    (i32.store (local.get $ptr) (local.get $tag))
    (i32.store offset=4 (local.get $ptr) (local.get $arity))
    (local.get $ptr))

  ;; ─── $sizeof_reason_record — bytes for a Reason record ────────────
  ;; Used by $reason_promote_deep below (the "no-sub-Reason" arms that
  ;; take the shallow $perm_promote fast path). Per reason.wat:84-107
  ;; each Reason variant has a fixed arity (1, 2, or 3); record layout
  ;; per the lines above is [tag:i32][arity:i32][field_0:i32]...
  ;; [field_{arity-1}:i32] = 8 + 4*arity bytes.
  ;;
  ;; Per H6 wildcard discipline + drift mode 9: every variant arm
  ;; explicit; trap on unknown tag via (unreachable). Per drift mode 8
  ;; refusal: no table-indexed-by-(tag - 220); direct (if i32.eq) chain
  ;; (substrate-honest per walk_expr.wat:150-156 dispatch precedent).
  (func $sizeof_reason_record (param $r i32) (result i32)
    (local $tag i32)
    (local.set $tag (call $tag_of (local.get $r)))
    ;; arity-1 variants — 12 bytes
    (if (i32.eq (local.get $tag) (i32.const 220)) (then (return (i32.const 12))))   ;; Declared
    (if (i32.eq (local.get $tag) (i32.const 221)) (then (return (i32.const 12))))   ;; Inferred
    (if (i32.eq (local.get $tag) (i32.const 222)) (then (return (i32.const 12))))   ;; Fresh
    (if (i32.eq (local.get $tag) (i32.const 228)) (then (return (i32.const 12))))   ;; ListElement
    (if (i32.eq (local.get $tag) (i32.const 229)) (then (return (i32.const 12))))   ;; IfBranch
    (if (i32.eq (local.get $tag) (i32.const 234)) (then (return (i32.const 12))))   ;; Placeholder
    (if (i32.eq (local.get $tag) (i32.const 235)) (then (return (i32.const 12))))   ;; BinOpPlaceholder
    (if (i32.eq (local.get $tag) (i32.const 236)) (then (return (i32.const 12))))   ;; MissingVar
    ;; arity-2 variants — 16 bytes
    (if (i32.eq (local.get $tag) (i32.const 224)) (then (return (i32.const 16))))   ;; VarLookup
    (if (i32.eq (local.get $tag) (i32.const 225)) (then (return (i32.const 16))))   ;; FnReturn
    (if (i32.eq (local.get $tag) (i32.const 227)) (then (return (i32.const 16))))   ;; MatchBranch
    (if (i32.eq (local.get $tag) (i32.const 230)) (then (return (i32.const 16))))   ;; LetBinding
    (if (i32.eq (local.get $tag) (i32.const 231)) (then (return (i32.const 16))))   ;; Unified
    (if (i32.eq (local.get $tag) (i32.const 232)) (then (return (i32.const 16))))   ;; Instantiation
    (if (i32.eq (local.get $tag) (i32.const 233)) (then (return (i32.const 16))))   ;; UnifyFailed
    (if (i32.eq (local.get $tag) (i32.const 237)) (then (return (i32.const 16))))   ;; Refinement
    (if (i32.eq (local.get $tag) (i32.const 238)) (then (return (i32.const 16))))   ;; Located
    (if (i32.eq (local.get $tag) (i32.const 239)) (then (return (i32.const 16))))   ;; InferredCallReturn
    (if (i32.eq (local.get $tag) (i32.const 240)) (then (return (i32.const 16))))   ;; InferredPipeResult
    (if (i32.eq (local.get $tag) (i32.const 241)) (then (return (i32.const 16))))   ;; FreshInContext
    (if (i32.eq (local.get $tag) (i32.const 242)) (then (return (i32.const 16))))   ;; DocstringReason
    ;; arity-3 variants — 20 bytes
    (if (i32.eq (local.get $tag) (i32.const 223)) (then (return (i32.const 20))))   ;; OpConstraint
    (if (i32.eq (local.get $tag) (i32.const 226)) (then (return (i32.const 20))))   ;; FnParam
    ;; ── Unknown tag — well-formed Reason cannot get here. Trap. ─────
    (unreachable))

  ;; ─── $reason_in_perm — predicate: pointer is in perm region ──────
  ;; Per arena.wat:30-32 perm region is [HEAP_BASE, STAGE_ARENA_START).
  ;; Inputs from data-segment ([0, HEAP_BASE)) are also "stable" (live
  ;; for module lifetime) so they count as perm-equivalent for
  ;; promote purposes (the $stage_reset will not invalidate them).
  (func $reason_in_perm (param $r i32) (result i32)
    ;; data-segment + perm-region both stable; return true.
    (i32.lt_u (local.get $r) (i32.const 1611137024)))   ;; STAGE_ARENA_START

  ;; ─── $reason_promote_deep — recursive promote of a Reason DAG ─────
  ;; Idempotent against perm-resident inputs. For stage-resident inputs:
  ;; recursively promote any field Reasons FIRST, then construct a fresh
  ;; perm record (via $make_record → $alloc → $perm_alloc) holding the
  ;; promoted field pointers. For variants with no sub-Reasons, the
  ;; shallow $perm_promote fast path copies the bytes directly.
  ;;
  ;; Per Hβ-first-light.infer-perm-pressure-substrate.md §8 (chain
  ;; pointer-identity preservation): the Why Engine reads structurally,
  ;; not by pointer-identity, so the deep-copy is correctness-preserving.
  ;;
  ;; Opaque fields (Ty / Span / Predicate / String / Int / BinOp): these
  ;; have their own allocation discipline owned by ty.wat / parser /
  ;; verify.wat / data-segment / sentinel-int / parser_infra. Per §B.8
  ;; walkthrough audit:
  ;;   - String at data-segment offset: stable.
  ;;   - String allocated via $str_alloc: routes through $alloc → perm.
  ;;   - Int / BinOp: i32 sentinel; not a heap pointer. Stable.
  ;;   - Span: parser allocates via $alloc → perm. Stable.
  ;;   - Ty: ty.wat allocates via $make_record → $alloc → perm. Stable.
  ;;   - Predicate: parser allocates via $alloc → perm. Stable.
  ;; So opaque fields pass through verbatim; only sub-Reasons recurse.
  (func $reason_promote_deep (param $r i32) (result i32)
    (local $tag i32)
    (local $f0 i32) (local $f1 i32) (local $f2 i32)
    (local $f0p i32) (local $f1p i32) (local $f2p i32)
    (local $new i32)
    ;; Idempotency: already perm-resident → identity.
    (if (call $reason_in_perm (local.get $r))
      (then (return (local.get $r))))
    (local.set $tag (call $tag_of (local.get $r)))
    ;; ── arity-1 variants without sub-Reasons — shallow promote ──────
    ;; 220 Declared(String), 221 Inferred(String), 222 Fresh(Int),
    ;; 234 Placeholder(Span), 235 BinOpPlaceholder(BinOp),
    ;; 236 MissingVar(String).
    (if (i32.eq (local.get $tag) (i32.const 220))
      (then (return (call $perm_promote (local.get $r) (i32.const 12)))))
    (if (i32.eq (local.get $tag) (i32.const 221))
      (then (return (call $perm_promote (local.get $r) (i32.const 12)))))
    (if (i32.eq (local.get $tag) (i32.const 222))
      (then (return (call $perm_promote (local.get $r) (i32.const 12)))))
    (if (i32.eq (local.get $tag) (i32.const 234))
      (then (return (call $perm_promote (local.get $r) (i32.const 12)))))
    (if (i32.eq (local.get $tag) (i32.const 235))
      (then (return (call $perm_promote (local.get $r) (i32.const 12)))))
    (if (i32.eq (local.get $tag) (i32.const 236))
      (then (return (call $perm_promote (local.get $r) (i32.const 12)))))
    ;; ── arity-1 variants WITH a sub-Reason at field 0 ───────────────
    ;; 228 ListElement(Reason), 229 IfBranch(Reason).
    (if (i32.eq (local.get $tag) (i32.const 228))
      (then
        (local.set $f0 (call $record_get (local.get $r) (i32.const 0)))
        (local.set $f0p (call $reason_promote_deep (local.get $f0)))
        (local.set $new (call $make_record (i32.const 228) (i32.const 1)))
        (call $record_set (local.get $new) (i32.const 0) (local.get $f0p))
        (return (local.get $new))))
    (if (i32.eq (local.get $tag) (i32.const 229))
      (then
        (local.set $f0 (call $record_get (local.get $r) (i32.const 0)))
        (local.set $f0p (call $reason_promote_deep (local.get $f0)))
        (local.set $new (call $make_record (i32.const 229) (i32.const 1)))
        (call $record_set (local.get $new) (i32.const 0) (local.get $f0p))
        (return (local.get $new))))
    ;; ── arity-2 variants WITH a sub-Reason at field 1 only ──────────
    ;; 224 VarLookup(String, Reason), 225 FnReturn(String, Reason),
    ;; 230 LetBinding(String, Reason), 232 Instantiation(String, Reason),
    ;; 238 Located(Span, Reason),
    ;; 239 InferredCallReturn(String, Reason),
    ;; 240 InferredPipeResult(String, Reason).
    (if (i32.eq (local.get $tag) (i32.const 224))
      (then
        (local.set $f0 (call $record_get (local.get $r) (i32.const 0)))
        (local.set $f1 (call $record_get (local.get $r) (i32.const 1)))
        (local.set $f1p (call $reason_promote_deep (local.get $f1)))
        (local.set $new (call $make_record (i32.const 224) (i32.const 2)))
        (call $record_set (local.get $new) (i32.const 0) (local.get $f0))
        (call $record_set (local.get $new) (i32.const 1) (local.get $f1p))
        (return (local.get $new))))
    (if (i32.eq (local.get $tag) (i32.const 225))
      (then
        (local.set $f0 (call $record_get (local.get $r) (i32.const 0)))
        (local.set $f1 (call $record_get (local.get $r) (i32.const 1)))
        (local.set $f1p (call $reason_promote_deep (local.get $f1)))
        (local.set $new (call $make_record (i32.const 225) (i32.const 2)))
        (call $record_set (local.get $new) (i32.const 0) (local.get $f0))
        (call $record_set (local.get $new) (i32.const 1) (local.get $f1p))
        (return (local.get $new))))
    (if (i32.eq (local.get $tag) (i32.const 230))
      (then
        (local.set $f0 (call $record_get (local.get $r) (i32.const 0)))
        (local.set $f1 (call $record_get (local.get $r) (i32.const 1)))
        (local.set $f1p (call $reason_promote_deep (local.get $f1)))
        (local.set $new (call $make_record (i32.const 230) (i32.const 2)))
        (call $record_set (local.get $new) (i32.const 0) (local.get $f0))
        (call $record_set (local.get $new) (i32.const 1) (local.get $f1p))
        (return (local.get $new))))
    (if (i32.eq (local.get $tag) (i32.const 232))
      (then
        (local.set $f0 (call $record_get (local.get $r) (i32.const 0)))
        (local.set $f1 (call $record_get (local.get $r) (i32.const 1)))
        (local.set $f1p (call $reason_promote_deep (local.get $f1)))
        (local.set $new (call $make_record (i32.const 232) (i32.const 2)))
        (call $record_set (local.get $new) (i32.const 0) (local.get $f0))
        (call $record_set (local.get $new) (i32.const 1) (local.get $f1p))
        (return (local.get $new))))
    (if (i32.eq (local.get $tag) (i32.const 238))
      (then
        (local.set $f0 (call $record_get (local.get $r) (i32.const 0)))
        (local.set $f1 (call $record_get (local.get $r) (i32.const 1)))
        (local.set $f1p (call $reason_promote_deep (local.get $f1)))
        (local.set $new (call $make_record (i32.const 238) (i32.const 2)))
        (call $record_set (local.get $new) (i32.const 0) (local.get $f0))
        (call $record_set (local.get $new) (i32.const 1) (local.get $f1p))
        (return (local.get $new))))
    (if (i32.eq (local.get $tag) (i32.const 239))
      (then
        (local.set $f0 (call $record_get (local.get $r) (i32.const 0)))
        (local.set $f1 (call $record_get (local.get $r) (i32.const 1)))
        (local.set $f1p (call $reason_promote_deep (local.get $f1)))
        (local.set $new (call $make_record (i32.const 239) (i32.const 2)))
        (call $record_set (local.get $new) (i32.const 0) (local.get $f0))
        (call $record_set (local.get $new) (i32.const 1) (local.get $f1p))
        (return (local.get $new))))
    (if (i32.eq (local.get $tag) (i32.const 240))
      (then
        (local.set $f0 (call $record_get (local.get $r) (i32.const 0)))
        (local.set $f1 (call $record_get (local.get $r) (i32.const 1)))
        (local.set $f1p (call $reason_promote_deep (local.get $f1)))
        (local.set $new (call $make_record (i32.const 240) (i32.const 2)))
        (call $record_set (local.get $new) (i32.const 0) (local.get $f0))
        (call $record_set (local.get $new) (i32.const 1) (local.get $f1p))
        (return (local.get $new))))
    ;; ── arity-2 variants WITH sub-Reasons at field 0 + field 1 ──────
    ;; 227 MatchBranch(Reason, Reason), 231 Unified(Reason, Reason).
    (if (i32.eq (local.get $tag) (i32.const 227))
      (then
        (local.set $f0 (call $record_get (local.get $r) (i32.const 0)))
        (local.set $f1 (call $record_get (local.get $r) (i32.const 1)))
        (local.set $f0p (call $reason_promote_deep (local.get $f0)))
        (local.set $f1p (call $reason_promote_deep (local.get $f1)))
        (local.set $new (call $make_record (i32.const 227) (i32.const 2)))
        (call $record_set (local.get $new) (i32.const 0) (local.get $f0p))
        (call $record_set (local.get $new) (i32.const 1) (local.get $f1p))
        (return (local.get $new))))
    (if (i32.eq (local.get $tag) (i32.const 231))
      (then
        (local.set $f0 (call $record_get (local.get $r) (i32.const 0)))
        (local.set $f1 (call $record_get (local.get $r) (i32.const 1)))
        (local.set $f0p (call $reason_promote_deep (local.get $f0)))
        (local.set $f1p (call $reason_promote_deep (local.get $f1)))
        (local.set $new (call $make_record (i32.const 231) (i32.const 2)))
        (call $record_set (local.get $new) (i32.const 0) (local.get $f0p))
        (call $record_set (local.get $new) (i32.const 1) (local.get $f1p))
        (return (local.get $new))))
    ;; ── arity-2 variants with NO sub-Reasons (all opaque payloads) ──
    ;; 233 UnifyFailed(Ty, Ty), 237 Refinement(Predicate, Predicate),
    ;; 241 FreshInContext(Int, String), 242 DocstringReason(String, Span).
    (if (i32.eq (local.get $tag) (i32.const 233))
      (then (return (call $perm_promote (local.get $r) (i32.const 16)))))
    (if (i32.eq (local.get $tag) (i32.const 237))
      (then (return (call $perm_promote (local.get $r) (i32.const 16)))))
    (if (i32.eq (local.get $tag) (i32.const 241))
      (then (return (call $perm_promote (local.get $r) (i32.const 16)))))
    (if (i32.eq (local.get $tag) (i32.const 242))
      (then (return (call $perm_promote (local.get $r) (i32.const 16)))))
    ;; ── arity-3 variants ────────────────────────────────────────────
    ;; 223 OpConstraint(String, Reason, Reason): sub-Reasons at 1 + 2.
    ;; 226 FnParam(String, Int, Reason): sub-Reason at 2.
    (if (i32.eq (local.get $tag) (i32.const 223))
      (then
        (local.set $f0 (call $record_get (local.get $r) (i32.const 0)))
        (local.set $f1 (call $record_get (local.get $r) (i32.const 1)))
        (local.set $f2 (call $record_get (local.get $r) (i32.const 2)))
        (local.set $f1p (call $reason_promote_deep (local.get $f1)))
        (local.set $f2p (call $reason_promote_deep (local.get $f2)))
        (local.set $new (call $make_record (i32.const 223) (i32.const 3)))
        (call $record_set (local.get $new) (i32.const 0) (local.get $f0))
        (call $record_set (local.get $new) (i32.const 1) (local.get $f1p))
        (call $record_set (local.get $new) (i32.const 2) (local.get $f2p))
        (return (local.get $new))))
    (if (i32.eq (local.get $tag) (i32.const 226))
      (then
        (local.set $f0 (call $record_get (local.get $r) (i32.const 0)))
        (local.set $f1 (call $record_get (local.get $r) (i32.const 1)))
        (local.set $f2 (call $record_get (local.get $r) (i32.const 2)))
        (local.set $f2p (call $reason_promote_deep (local.get $f2)))
        (local.set $new (call $make_record (i32.const 226) (i32.const 3)))
        (call $record_set (local.get $new) (i32.const 0) (local.get $f0))
        (call $record_set (local.get $new) (i32.const 1) (local.get $f1))
        (call $record_set (local.get $new) (i32.const 2) (local.get $f2p))
        (return (local.get $new))))
    ;; ── Unknown tag — well-formed Reason cannot get here. Trap. ─────
    (unreachable))

  (func $record_get (param $ptr i32) (param $idx i32) (result i32)
    (i32.load
      (i32.add
        (i32.add (local.get $ptr) (i32.const 8))
        (i32.mul (local.get $idx) (i32.const 4)))))

  (func $record_set (param $ptr i32) (param $idx i32) (param $val i32)
    (i32.store
      (i32.add
        (i32.add (local.get $ptr) (i32.const 8))
        (i32.mul (local.get $idx) (i32.const 4)))
      (local.get $val)))

  ;; ─── ADT Match Helpers ────────────────────────────────────────────

  ;; tag_of: if ptr < HEAP_BASE, it IS the tag (sentinel).
  ;; Otherwise load tag from offset 0.
  (func $tag_of (param $ptr i32) (result i32)
    (if (result i32) (i32.lt_u (local.get $ptr) (global.get $heap_base))
      (then (local.get $ptr))
      (else (i32.load (local.get $ptr)))))

  (func $is_sentinel (param $ptr i32) (result i32)
    (i32.lt_u (local.get $ptr) (global.get $heap_base)))
