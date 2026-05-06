  ;; ═══ buffer.wat — Buffer<A> mutable-with-counter substrate (Tier 2) ══
  ;; Implements: Hβ.runtime.buffer-substrate — Buffer<A> as a kernel-
  ;;             native primitive distinct from List<A>; eliminates the
  ;;             buffer-counter abuse pattern that conflated capacity
  ;;             and count via List's offset-0 field.
  ;; Exports:    $buf_make, $buf_push, $buf_count, $buf_data, $buf_freeze
  ;; Uses:       $alloc (alloc.wat), $make_list / $list_set /
  ;;             $list_extend_to / $slice (list.wat),
  ;;             $make_record / $record_get / $record_set (record.wat)
  ;;
  ;; Layout: Buffer<A> is a 2-field record (tag-private; not exposed
  ;; to user pattern-match — accessors below are the only interface):
  ;;   field 0 = data:  List<A> ptr (capacity = $len(data))
  ;;   field 1 = count: Int (logical fill, count <= $len(data))
  ;;
  ;; Per kernel crystallization #9 (Records-Are-Handler-State-Shape +
  ;; CLAUDE.md drift mode 7): ONE record holds (data, count); never
  ;; passed as parallel-arrays (List, Int).
  ;;
  ;; Symmetric to lib/runtime/buffer.nx (the wheel-canonical Buffer<A>);
  ;; this WAT is the seed binding that lets the seed compile against
  ;; the wheel's Buffer<A> contract.

  ;; ─── $buf_make — fresh Buffer<A> with `cap` pre-allocated slots ────
  ;; Allocates a List<A> of size cap, builds the 2-field record with
  ;; count = 0. cap = 0 is allowed (subsequent push will allocate at
  ;; first overflow per the canonical doubling pattern).
  (func $buf_make (export "buf_make") (param $cap i32) (result i32)
    (local $buf i32) (local $data i32)
    (local.set $data (call $make_list (local.get $cap)))
    (local.set $buf (call $make_record (i32.const 360) (i32.const 2)))
    (call $record_set (local.get $buf) (i32.const 0) (local.get $data))
    (call $record_set (local.get $buf) (i32.const 1) (i32.const 0))
    (local.get $buf))

  ;; ─── $buf_count — read logical fill (offset 1) ────────────────────
  (func $buf_count (export "buf_count") (param $buf i32) (result i32)
    (call $record_get (local.get $buf) (i32.const 1)))

  ;; ─── $buf_data — read underlying List<A> (offset 0) ────────────────
  ;; The List has $len(data) slots; the first $buf_count(buf) are
  ;; valid. Use $buf_freeze for a clean prefix-only List.
  (func $buf_data (export "buf_data") (param $buf i32) (result i32)
    (call $record_get (local.get $buf) (i32.const 0)))

  ;; ─── $buf_push — append `x` at index count; bump count ────────────
  ;; If count >= data.len, doubles capacity via $list_extend_to (which
  ;; reallocates with copy — the cur < min_size path). Otherwise the
  ;; existing data is in-place written. Amortized O(1) push.
  ;;
  ;; Mutates buf in place (record_set on offset 0/1). The buf record
  ;; itself stays at the same address; the data List MAY change
  ;; address on capacity overflow.
  (func $buf_push (export "buf_push") (param $buf i32) (param $x i32)
    (local $data i32) (local $count i32) (local $cap i32) (local $new_cap i32)
    (local.set $data  (call $record_get (local.get $buf) (i32.const 0)))
    (local.set $count (call $record_get (local.get $buf) (i32.const 1)))
    (local.set $cap   (call $len (local.get $data)))
    ;; Capacity check: extend (with copy) when count would overflow.
    (if (i32.ge_u (local.get $count) (local.get $cap))
      (then
        (local.set $new_cap (i32.const 4))
        (if (i32.gt_u (local.get $cap) (i32.const 0))
          (then (local.set $new_cap (i32.mul (local.get $cap) (i32.const 2)))))
        (local.set $data (call $list_extend_to
                           (local.get $data) (local.get $new_cap)))
        (call $record_set (local.get $buf) (i32.const 0) (local.get $data))))
    ;; Write the new element at slot $count; bump count.
    (drop (call $list_set (local.get $data) (local.get $count) (local.get $x)))
    (call $record_set (local.get $buf) (i32.const 1)
      (i32.add (local.get $count) (i32.const 1))))

  ;; ─── $buf_freeze — slice data to count, return clean List<A> ──────
  ;; The buffer is consumed (callers should not reference it after
  ;; freeze; ownership-transfer per primitive #5). The returned List
  ;; is a fresh tag-0 flat list of exactly $buf_count(buf) elements.
  (func $buf_freeze (export "buf_freeze") (param $buf i32) (result i32)
    (local $data i32) (local $count i32)
    (local.set $data  (call $record_get (local.get $buf) (i32.const 0)))
    (local.set $count (call $record_get (local.get $buf) (i32.const 1)))
    (call $slice (local.get $data) (i32.const 0) (local.get $count)))

  ;; ─── $buf_contains — linear-search membership test (Hβ.emit-walk-dag-aware) ──
  ;; Returns 1 if `$x` appears in the buffer's logical fill, else 0.
  ;; Used as a visited-set primitive for DAG-aware walks (emit's
  ;; cfn_walk + emit_functions_walk dedup shared LowFn references).
  ;; O(N) per query — acceptable for wheel-scale fn counts (~1000),
  ;; constant-factor for first-light.
  ;;
  ;; Named peer `Hβ.runtime.buffer-hashset`: when wheel-scale fn count
  ;; grows enough that O(N²) total dedup work matters, replace with a
  ;; hash-keyed Buffer<(K, V)> primitive. Until then linear is honest:
  ;; total ≈ N²/2; at N=1000 that's 500K comparisons, microseconds.
  (func $buf_contains (export "buf_contains") (param $buf i32) (param $x i32) (result i32)
    (local $data i32) (local $count i32) (local $i i32)
    (local.set $data  (call $record_get (local.get $buf) (i32.const 0)))
    (local.set $count (call $record_get (local.get $buf) (i32.const 1)))
    (local.set $i (i32.const 0))
    (block $done
      (loop $iter
        (br_if $done (i32.ge_u (local.get $i) (local.get $count)))
        (if (i32.eq (call $list_index (local.get $data) (local.get $i)) (local.get $x))
          (then (return (i32.const 1))))
        (local.set $i (i32.add (local.get $i) (i32.const 1)))
        (br $iter)))
    (i32.const 0))
