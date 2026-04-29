  ;; ═══ alloc.wat — stable public allocator name (Tier 0) ═════════════
  ;; Implements: Hβ §1.1 — HEAP_BASE invariant + 8-byte-aligned bump
  ;;             routed through arena.wat's $perm_alloc.
  ;; Exports:    $alloc
  ;; Uses:       $perm_alloc (arena.wat)
  ;;
  ;; Per Anchor 0 + Anchor 5: `$alloc` is the stable public name that
  ;; means "long-lived allocation" — a thin alias for $perm_alloc.
  ;; Existing call sites that don't know about arena discipline route
  ;; here; the lifetime contract is "survives all stage/fn boundaries"
  ;; (the safe default).
  ;;
  ;; New code that knows its allocation is transient or fn-local calls
  ;; $stage_alloc or $fn_alloc DIRECTLY — there is no "current arena"
  ;; ambient state, no dispatcher, no global tag. Each call site is
  ;; explicit about lifetime.
  ;;
  ;; Per CLAUDE.md memory model + γ crystallization #8 (the heap has
  ;; one story): closures (closure.wat), continuations (cont.wat —
  ;; H7), ADT variants (record.wat), records, tuples, strings (str.wat),
  ;; lists (list.wat) ALL allocate through this surface. The arena
  ;; substrate (arena.wat) provides the per-arena allocators that
  ;; specific call sites elect when the lifetime is shorter.

  (func $alloc (param $size i32) (result i32)
    (call $perm_alloc (local.get $size)))
