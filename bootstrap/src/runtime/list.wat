  ;; ═══ list.wat — tagged list primitives (Tier 1) ═══════════════════
  ;; Implements: Hβ §1.7 — tagged list layout + full tag dispatch.
  ;; Exports:    $make_list, $len, $list_index, $list_set,
  ;;             $list_extend_to, $slice,
  ;;             $list_alloc_snoc, $list_alloc_concat, $list_alloc_slice,
  ;;             $list_to_flat, $list_tag
  ;; Uses:       $alloc (alloc.wat)
  ;; Test:       runtime_test/list.wat
  ;;
  ;; Layout per CLAUDE.md representations + Hβ §1.7:
  ;;   tag 0 = flat   [count:i32][tag:i32][elements i32 each]
  ;;   tag 1 = snoc   [count:i32][tag:i32][tail:ptr][head:i32]
  ;;   tag 3 = concat [count:i32][tag:i32][left:ptr][right:ptr]
  ;;   tag 4 = slice  [count:i32][tag:i32][base:ptr][start:i32]
  ;;
  ;; $list_index is exhaustive across all four tags. Per CLAUDE.md
  ;; bug classes: bare `list[i]` in a hot loop on a non-flat list is
  ;; O(N²) — call $list_to_flat once at hot-path entrances; then
  ;; $list_index runs O(1).
  ;;
  ;; $list_set + $list_extend_to + $make_list operate on FLAT lists
  ;; only (writes invalidate sharing in snoc/concat/slice trees).
  ;; Callers wanting to "modify" a non-flat list call $list_to_flat
  ;; first. $list_set's tag-check is hard-coded to flat per the
  ;; buffer-counter substrate (Ω.3) — load-bearing across graph /
  ;; trail / overlay arrays in graph.wat.

  ;; ─── List Primitives ──────────────────────────────────────────────
  ;; Layout: [count:i32][tag:i32][payload...]

  ;; make_list: allocate flat tag=0 list with count slots
  (func $make_list (param $count i32) (result i32)
    (local $ptr i32)
    (local.set $ptr (call $alloc
      (i32.add (i32.const 8) (i32.mul (local.get $count) (i32.const 4)))))
    (i32.store (local.get $ptr) (local.get $count))
    (i32.store offset=4 (local.get $ptr) (i32.const 0))  ;; tag=0 flat
    (local.get $ptr))

  ;; len: read count field
  (func $len (param $list i32) (result i32)
    (i32.load (local.get $list)))

  ;; list_tag: read tag field (offset 4)
  (func $list_tag (param $list i32) (result i32)
    (i32.load offset=4 (local.get $list)))

  ;; list_index: exhaustive on all four tags.
  ;;   tag 0: O(1) load at offset 8 + 4*i
  ;;   tag 1: snoc. payload = [tail:ptr@8][head:i32@12]. count-1 → head; else recurse on tail
  ;;   tag 3: concat. payload = [left:ptr@8][right:ptr@12]. recurse left if i < $len(left); else right with i - $len(left)
  ;;   tag 4: slice.  payload = [base:ptr@8][start:i32@12]. recurse base with start + i
  ;; Recursion depth bounded by snoc-tree height; $list_to_flat
  ;; materializes hot inputs.
  (func $list_index (param $list i32) (param $i i32) (result i32)
    (local $tag i32) (local $left i32) (local $left_count i32) (local $base i32) (local $start i32)
    (local.set $tag (call $list_tag (local.get $list)))
    ;; tag 0 — flat
    (if (i32.eq (local.get $tag) (i32.const 0))
      (then
        (return
          (i32.load
            (i32.add
              (i32.add (local.get $list) (i32.const 8))
              (i32.mul (local.get $i) (i32.const 4)))))))
    ;; tag 1 — snoc. count-1 → head field; else recurse on tail
    (if (i32.eq (local.get $tag) (i32.const 1))
      (then
        (if (i32.eq (local.get $i)
                    (i32.sub (call $len (local.get $list)) (i32.const 1)))
          (then (return (i32.load offset=12 (local.get $list)))))
        (return
          (call $list_index
            (i32.load offset=8 (local.get $list))   ;; tail
            (local.get $i)))))
    ;; tag 3 — concat. left = field@8, right = field@12. dispatch on left's $len
    (if (i32.eq (local.get $tag) (i32.const 3))
      (then
        (local.set $left (i32.load offset=8 (local.get $list)))
        (local.set $left_count (call $len (local.get $left)))
        (if (i32.lt_u (local.get $i) (local.get $left_count))
          (then (return (call $list_index (local.get $left) (local.get $i)))))
        (return
          (call $list_index
            (i32.load offset=12 (local.get $list))  ;; right
            (i32.sub (local.get $i) (local.get $left_count))))))
    ;; tag 4 — slice. base@8, start@12. recurse base with start + i
    (if (i32.eq (local.get $tag) (i32.const 4))
      (then
        (local.set $base (i32.load offset=8 (local.get $list)))
        (local.set $start (i32.load offset=12 (local.get $list)))
        (return
          (call $list_index (local.get $base)
                            (i32.add (local.get $start) (local.get $i))))))
    ;; Unknown tag — productive-under-error per
    ;; `Hβ.first-light.list-index-productive-degrade`. Pre-substrate
    ;; the unreachable trap killed the seed any time upstream
    ;; lower/emit handed list_index a non-list pointer (typically a
    ;; LowExpr-shaped record where a list was expected, surfaced when
    ;; infer leaves unresolved Tys that lower's PUE-path can't ground).
    ;; Returning 0 lets the recursive emit walk continue, surfacing
    ;; the upstream diagnostic chain (E_UnresolvedType, etc.) instead
    ;; of trapping. The 0 propagates through emit_functions_walk's
    ;; HEAP_BASE check (line 1300) which short-circuits — sentinel
    ;; symmetry per row.wat:48 (sentinels < HEAP_BASE).
    ;;
    ;; Named peer `Hβ.first-light.emit-functions-malformed-list-source`
    ;; remains: identify which lower accessor produces the non-list
    ;; and fix at the source. This is the productive-under-error
    ;; safety net, not the structural fix.
    (i32.const 0))

  ;; list_set: write val at index, return list ptr.
  ;; FLAT lists ONLY. Per Ω.3 buffer-counter substrate; non-flat
  ;; callers materialize via $list_to_flat first.
  (func $list_set (param $list i32) (param $idx i32) (param $val i32) (result i32)
    (i32.store
      (i32.add
        (i32.add (local.get $list) (i32.const 8))
        (i32.mul (local.get $idx) (i32.const 4)))
      (local.get $val))
    (local.get $list))

  ;; list_extend_to: ensure capacity >= min_size. FLAT lists only.
  ;;
  ;; Two paths:
  ;; (1) In-place extend at heap-top — when align(list_end) ==
  ;;     heap_ptr (no allocations since this list was made), grow it
  ;;     in-place via $perm_alloc. Canonical bump-allocator zone-
  ;;     realloc trick (GMP / glibc / V8). Amortized O(1) for buffer-
  ;;     counter callers that haven't yet migrated to Buffer<A>.
  ;; (2) Reallocate with doubling when not at heap-top — fresh
  ;;     make_list, copy elements, return new list.
  ;;
  ;; Buffer<A> (`bootstrap/src/runtime/buffer.wat`) supersedes the
  ;; buffer-counter abuse pattern at the type level — new code uses
  ;; Buffer<A> with proper count/capacity separation. The heap-top
  ;; trick keeps existing infer/lower buffer-counter callers correct
  ;; until the migration completes.
  ;;
  ;; Named peer `Hβ.runtime.buffer-substrate-adoption`: migrate
  ;; remaining buffer-counter sites (infer's reason-chain builders,
  ;; lower's per-fn captures collection, emit's fn-table-globals
  ;; iteration) to Buffer<A>. Once complete, the heap-top trick
  ;; becomes a defensive optimization rather than load-bearing.
  (func $list_extend_to (param $list i32) (param $min_size i32) (result i32)
    (local $cur i32) (local $new_cap i32) (local $fresh i32) (local $i i32)
    (local $list_end i32) (local $list_end_aligned i32) (local $extra i32)
    (local.set $cur (call $len (local.get $list)))
    (if (result i32) (i32.ge_u (local.get $cur) (local.get $min_size))
      (then (local.get $list))
      (else
        ;; In-place extend if list is at heap-top.
        (local.set $list_end
          (i32.add
            (i32.add (local.get $list) (i32.const 8))
            (i32.mul (local.get $cur) (i32.const 4))))
        (local.set $list_end_aligned
          (i32.and
            (i32.add (local.get $list_end) (i32.const 7))
            (i32.const -8)))
        (if (i32.eq (local.get $list_end_aligned) (global.get $heap_ptr))
          (then
            (local.set $extra (i32.sub (local.get $min_size) (local.get $cur)))
            (drop (call $perm_alloc (i32.mul (local.get $extra) (i32.const 4))))
            (i32.store (local.get $list) (local.get $min_size))
            (return (local.get $list))))
        ;; Not at heap-top — reallocate with doubling.
        (local.set $new_cap (i32.mul (local.get $cur) (i32.const 2)))
        (if (i32.gt_u (local.get $min_size) (local.get $new_cap))
          (then (local.set $new_cap (local.get $min_size))))
        (local.set $fresh (call $make_list (local.get $new_cap)))
        (local.set $i (i32.const 0))
        (block $done
          (loop $copy
            (br_if $done (i32.ge_u (local.get $i) (local.get $cur)))
            (drop (call $list_set (local.get $fresh) (local.get $i)
              (call $list_index (local.get $list) (local.get $i))))
            (local.set $i (i32.add (local.get $i) (i32.const 1)))
            (br $copy)))
        (local.get $fresh))))

  ;; slice: flat-copy variant. allocates a new tag=0 list with the
  ;; sliced elements copied. Compatible with all input tags via
  ;; $list_index. For zero-copy view-semantics use $list_alloc_slice.
  (func $slice (param $list i32) (param $start i32) (param $end i32) (result i32)
    (local $total i32) (local $new_len i32) (local $result i32) (local $i i32)
    (local.set $total (call $len (local.get $list)))
    ;; clamp
    (if (i32.lt_s (local.get $start) (i32.const 0))
      (then (local.set $start (i32.const 0))))
    (if (i32.gt_s (local.get $start) (local.get $total))
      (then (local.set $start (local.get $total))))
    (if (i32.lt_s (local.get $end) (local.get $start))
      (then (local.set $end (local.get $start))))
    (if (i32.gt_s (local.get $end) (local.get $total))
      (then (local.set $end (local.get $total))))
    (local.set $new_len (i32.sub (local.get $end) (local.get $start)))
    (if (result i32) (i32.le_s (local.get $new_len) (i32.const 0))
      (then (call $make_list (i32.const 0)))
      (else
        ;; Flat copy: allocate new list and copy elements one by one
        (local.set $result (call $make_list (local.get $new_len)))
        (local.set $i (i32.const 0))
        (block $done (loop $cp
          (br_if $done (i32.ge_u (local.get $i) (local.get $new_len)))
          (drop (call $list_set (local.get $result) (local.get $i)
            (call $list_index (local.get $list)
              (i32.add (local.get $start) (local.get $i)))))
          (local.set $i (i32.add (local.get $i) (i32.const 1)))
          (br $cp)))
        (local.get $result))))

  ;; ─── Tag-1 / Tag-3 / Tag-4 Constructors ──────────────────────────
  ;; Allocate non-flat shapes when sharing/streaming wins over flat
  ;; copy. $list_index handles them at O(depth); $list_to_flat
  ;; materializes when hot.

  ;; list_alloc_snoc: allocate [count, tag=1, tail:ptr, head:i32]
  (func $list_alloc_snoc (param $tail i32) (param $head i32) (result i32)
    (local $ptr i32)
    (local.set $ptr (call $alloc (i32.const 16)))
    (i32.store (local.get $ptr)
      (i32.add (call $len (local.get $tail)) (i32.const 1)))   ;; count
    (i32.store offset=4  (local.get $ptr) (i32.const 1))        ;; tag=1
    (i32.store offset=8  (local.get $ptr) (local.get $tail))    ;; tail
    (i32.store offset=12 (local.get $ptr) (local.get $head))    ;; head
    (local.get $ptr))

  ;; list_alloc_concat: allocate [count, tag=3, left:ptr, right:ptr]
  (func $list_alloc_concat (param $left i32) (param $right i32) (result i32)
    (local $ptr i32)
    (local.set $ptr (call $alloc (i32.const 16)))
    (i32.store (local.get $ptr)
      (i32.add (call $len (local.get $left)) (call $len (local.get $right)))) ;; count
    (i32.store offset=4  (local.get $ptr) (i32.const 3))        ;; tag=3
    (i32.store offset=8  (local.get $ptr) (local.get $left))    ;; left
    (i32.store offset=12 (local.get $ptr) (local.get $right))   ;; right
    (local.get $ptr))

  ;; list_alloc_slice: zero-copy view into base[start..start+count).
  ;; Allocates [count, tag=4, base:ptr, start:i32]. Caller is
  ;; responsible for bounds (count + start <= $len(base)).
  (func $list_alloc_slice (param $base i32) (param $start i32) (param $count i32) (result i32)
    (local $ptr i32)
    (local.set $ptr (call $alloc (i32.const 16)))
    (i32.store (local.get $ptr) (local.get $count))             ;; count
    (i32.store offset=4  (local.get $ptr) (i32.const 4))        ;; tag=4
    (i32.store offset=8  (local.get $ptr) (local.get $base))    ;; base
    (i32.store offset=12 (local.get $ptr) (local.get $start))   ;; start
    (local.get $ptr))

  ;; ─── Materialization ─────────────────────────────────────────────
  ;; $list_to_flat: ensure $list_index runs O(1). Idempotent —
  ;; returns the input unchanged when already flat. Allocates a new
  ;; flat list with copied elements otherwise.
  (func $list_to_flat (param $list i32) (result i32)
    (local $tag i32) (local $n i32) (local $out i32) (local $i i32)
    (local.set $tag (call $list_tag (local.get $list)))
    (if (i32.eq (local.get $tag) (i32.const 0))
      (then (return (local.get $list))))                        ;; already flat
    (local.set $n (call $len (local.get $list)))
    (local.set $out (call $make_list (local.get $n)))
    (local.set $i (i32.const 0))
    (block $done (loop $cp
      (br_if $done (i32.ge_u (local.get $i) (local.get $n)))
      (drop (call $list_set (local.get $out) (local.get $i)
        (call $list_index (local.get $list) (local.get $i))))
      (local.set $i (i32.add (local.get $i) (i32.const 1)))
      (br $cp)))
    (local.get $out))
