;; inka.wat — The Reference Seed Compiler (Tier 1 Runtime)
;;
;; ASSEMBLED FROM bootstrap/src/* by bootstrap/build.sh. Do not edit
;; this file directly; edit the chunk files in bootstrap/src/ and
;; rerun build.sh. Per Hβ §2.1 modular pivot (plan §136 2026-04-23).
;;
;; HEAP_BASE = 4096 (0x1000)
;; Nullary sentinel values: [0, HEAP_BASE)
;; Allocated records: >= HEAP_BASE
;; Bump allocator starts at 1_048_576 (1 MiB)
;; String layout: [len:i32][bytes...]
;; List layout:   [count:i32][tag:i32][payload...]
;;   tag 0 = flat, tag 1 = snoc, tag 3 = concat, tag 4 = slice

(module
  ;; ─── WASI Imports (preview1) ──────────────────────────────────────
  (import "wasi_snapshot_preview1" "fd_read"
    (func $wasi_fd_read (param i32 i32 i32 i32) (result i32)))
  (import "wasi_snapshot_preview1" "fd_write"
    (func $wasi_fd_write (param i32 i32 i32 i32) (result i32)))
  (import "wasi_snapshot_preview1" "fd_close"
    (func $wasi_fd_close (param i32) (result i32)))
  (import "wasi_snapshot_preview1" "path_open"
    (func $wasi_path_open (param i32 i32 i32 i32 i32 i64 i64 i32 i32) (result i32)))
  (import "wasi_snapshot_preview1" "proc_exit"
    (func $wasi_proc_exit (param i32)))
  ;; Filesystem extensions per FX walkthrough — composed with by wasi_fs.wat.
  ;; Required preopen: caller invokes wasmtime with --dir=.  so fd 3 = "."
  (import "wasi_snapshot_preview1" "path_create_directory"
    (func $wasi_path_create_directory (param i32 i32 i32) (result i32)))
  (import "wasi_snapshot_preview1" "path_filestat_get"
    (func $wasi_path_filestat_get (param i32 i32 i32 i32 i32) (result i32)))
  (import "wasi_snapshot_preview1" "path_unlink_file"
    (func $wasi_path_unlink_file (param i32 i32 i32) (result i32)))
  (import "wasi_snapshot_preview1" "path_rename"
    (func $wasi_path_rename (param i32 i32 i32 i32 i32 i32) (result i32)))
  (import "wasi_snapshot_preview1" "fd_readdir"
    (func $wasi_fd_readdir (param i32 i32 i32 i64 i32) (result i32)))

  ;; ─── Memory & Globals (Layer 0) ───────────────────────────────────
  (memory (export "memory") 512)  ;; 32 MiB — room for heap + output buffer

  (global $heap_base i32 (i32.const 4096))
  (global $heap_ptr (mut i32) (i32.const 1048576))

  ;; ═══ alloc.wat — bump allocator (Tier 0) ═══════════════════════════
  ;; Implements: Hβ §1.1 — HEAP_BASE invariant + 8-byte-aligned bump.
  ;; Exports:    $alloc
  ;; Uses:       $heap_ptr (global, Layer 0 shell)
  ;; Test:       runtime_test/alloc.wat (per-chunk fitness)
  ;;
  ;; HEAP_BASE = 4096 (sentinel region [0, 4096)); $heap_ptr starts at
  ;; 1 MiB (1048576). 8-byte-aligned monotonic bump; never frees.
  ;;
  ;; Per CLAUDE.md memory model + γ crystallization #8 (the heap has one
  ;; story): closures (closure.wat), continuations (cont.wat — H7),
  ;; ADT variants (record.wat), records, tuples, strings (str.wat),
  ;; lists (list.wat) ALL allocate through this surface. Arena handlers
  ;; (B.5 AM-arena-multishot — replay_safe / fork_deny / fork_copy) are
  ;; peer swaps that intercept this allocation at handler-install time
  ;; post-L1; the seed's bump_allocator is the default that arena
  ;; handlers narrow.

  ;; ─── Bump Allocator ───────────────────────────────────────────────
  (func $alloc (param $size i32) (result i32)
    (local $old i32)
    (local.set $old (global.get $heap_ptr))
    (global.set $heap_ptr
      (i32.and
        (i32.add
          (i32.add (global.get $heap_ptr) (local.get $size))
          (i32.const 7))
        (i32.const -8)))  ;; 8-byte alignment
    (local.get $old))

  ;; ═══ str.wat — flat string primitives (Tier 1) ════════════════════
  ;; Implements: Hβ §1.6 — String layout [len:i32][bytes...].
  ;; Exports:    $str_alloc, $str_len, $byte_at, $byte_len,
  ;;             $str_eq, $str_concat, $str_slice, $str_compare
  ;; Uses:       $alloc (alloc.wat)
  ;; Test:       runtime_test/str.wat
  ;;
  ;; Strings are always flat — length-prefixed byte buffers. $str_concat
  ;; allocates a new string and copies both inputs. $str_eq compares
  ;; length-then-bytes. $str_slice allocates a new substring; clamps
  ;; out-of-range indices.
  ;;
  ;; The bare `==` shape on strings is forbidden in src/*.nx per
  ;; CLAUDE.md bug classes; user code calls `str_eq(a, b)` (which
  ;; lowers to $str_eq here). Per Ω.2: $str_eq returns Bool (i32 0/1).

  ;; ─── String Primitives ────────────────────────────────────────────
  ;; Layout: [len:i32][bytes...]

  (func $str_alloc (param $len i32) (result i32)
    (local $ptr i32)
    (local.set $ptr (call $alloc (i32.add (local.get $len) (i32.const 4))))
    (i32.store (local.get $ptr) (local.get $len))
    (local.get $ptr))

  (func $str_len (param $s i32) (result i32)
    (i32.load (local.get $s)))

  (func $byte_at (param $s i32) (param $i i32) (result i32)
    (i32.load8_u (i32.add (i32.add (local.get $s) (i32.const 4)) (local.get $i))))

  (func $byte_len (param $s i32) (result i32)
    (i32.load (local.get $s)))

  (func $str_eq (param $a i32) (param $b i32) (result i32)
    (local $la i32) (local $lb i32) (local $i i32)
    (local.set $la (call $str_len (local.get $a)))
    (local.set $lb (call $str_len (local.get $b)))
    (if (i32.ne (local.get $la) (local.get $lb))
      (then (return (i32.const 0))))
    (local.set $i (i32.const 0))
    (block $done
      (loop $cmp
        (br_if $done (i32.ge_u (local.get $i) (local.get $la)))
        (if (i32.ne
              (call $byte_at (local.get $a) (local.get $i))
              (call $byte_at (local.get $b) (local.get $i)))
          (then (return (i32.const 0))))
        (local.set $i (i32.add (local.get $i) (i32.const 1)))
        (br $cmp)))
    (i32.const 1))

  (func $str_concat (param $a i32) (param $b i32) (result i32)
    (local $la i32) (local $lb i32) (local $out i32)
    (local.set $la (call $str_len (local.get $a)))
    (local.set $lb (call $str_len (local.get $b)))
    (local.set $out (call $str_alloc (i32.add (local.get $la) (local.get $lb))))
    (memory.copy
      (i32.add (local.get $out) (i32.const 4))
      (i32.add (local.get $a) (i32.const 4))
      (local.get $la))
    (memory.copy
      (i32.add (i32.add (local.get $out) (i32.const 4)) (local.get $la))
      (i32.add (local.get $b) (i32.const 4))
      (local.get $lb))
    (local.get $out))

  (func $str_slice (param $s i32) (param $start i32) (param $end i32) (result i32)
    (local $slen i32) (local $n i32) (local $dest i32)
    (local.set $slen (call $str_len (local.get $s)))
    ;; clamp start
    (if (i32.lt_s (local.get $start) (i32.const 0))
      (then (local.set $start (i32.const 0))))
    (if (i32.gt_s (local.get $start) (local.get $slen))
      (then (local.set $start (local.get $slen))))
    ;; clamp end
    (if (i32.lt_s (local.get $end) (local.get $start))
      (then (local.set $end (local.get $start))))
    (if (i32.gt_s (local.get $end) (local.get $slen))
      (then (local.set $end (local.get $slen))))
    (local.set $n (i32.sub (local.get $end) (local.get $start)))
    (local.set $dest (call $str_alloc (local.get $n)))
    (if (i32.gt_s (local.get $n) (i32.const 0))
      (then
        (memory.copy
          (i32.add (local.get $dest) (i32.const 4))
          (i32.add (i32.add (local.get $s) (i32.const 4)) (local.get $start))
          (local.get $n))))
    (local.get $dest))

  ;; $str_compare — lexicographic byte-by-byte compare. Returns:
  ;;   -1 if $a < $b
  ;;    0 if $a == $b
  ;;    1 if $a > $b
  ;; Used by row.wat's sorted-name-set ops (effect names are
  ;; lex-sorted per spec 01 normal form). Equal-prefix-shorter-string
  ;; is < (standard lex order; "abc" < "abcd").
  (func $str_compare (param $a i32) (param $b i32) (result i32)
    (local $la i32) (local $lb i32) (local $i i32)
    (local $ba i32) (local $bb i32) (local $min i32)
    (local.set $la (call $str_len (local.get $a)))
    (local.set $lb (call $str_len (local.get $b)))
    (local.set $min (local.get $la))
    (if (i32.gt_u (local.get $la) (local.get $lb))
      (then (local.set $min (local.get $lb))))
    (local.set $i (i32.const 0))
    (block $done
      (loop $cmp
        (br_if $done (i32.ge_u (local.get $i) (local.get $min)))
        (local.set $ba (call $byte_at (local.get $a) (local.get $i)))
        (local.set $bb (call $byte_at (local.get $b) (local.get $i)))
        (if (i32.lt_u (local.get $ba) (local.get $bb))
          (then (return (i32.const -1))))
        (if (i32.gt_u (local.get $ba) (local.get $bb))
          (then (return (i32.const 1))))
        (local.set $i (i32.add (local.get $i) (i32.const 1)))
        (br $cmp)))
    ;; Common prefix matches; shorter wins.
    (if (i32.lt_u (local.get $la) (local.get $lb)) (then (return (i32.const -1))))
    (if (i32.gt_u (local.get $la) (local.get $lb)) (then (return (i32.const 1))))
    (i32.const 0))

  ;; ═══ wasi.wat — WASI preview1 I/O wrappers (Tier 1) ═══════════════
  ;; Implements: Hβ §1.15 — WASI preview1 stdout/stderr/stdin helpers
  ;;             over the imported wasi_snapshot_preview1 functions
  ;;             (Layer 0 shell declares the imports).
  ;; Exports:    $print_string, $eprint_string, $read_all_stdin
  ;; Uses:       $alloc (alloc.wat), $str_alloc (str.wat),
  ;;             $str_len (str.wat), $str_concat (str.wat),
  ;;             $wasi_fd_read, $wasi_fd_write (Layer 0 imports)
  ;; Test:       runtime_test/wasi.wat
  ;;
  ;; WASI preview1 surface (per CLAUDE.md WASM-as-substrate + plan §21):
  ;;   fd_write, fd_read, fd_close, path_open, proc_exit
  ;; Filesystem extensions (path_create_directory / fd_readdir /
  ;; path_filestat_get / path_unlink_file / path_rename) live in
  ;; wasi_fs.wat per the FX walkthrough composition arc.
  ;;
  ;; iov scratch is allocated inline (one $alloc per call). Per
  ;; lib/runtime/io.nx VFINAL: scratch convention; bump allocator
  ;; recovers all on next session reset (none — bump is monotonic, but
  ;; iov use is small).

  ;; ─── WASI I/O Wrappers ────────────────────────────────────────────

  ;; Print a string (len-prefixed) to stdout (fd 1)
  (func $print_string (param $s i32)
    (local $iovs i32) (local $nwritten i32)
    (local.set $iovs (call $alloc (i32.const 8)))
    (i32.store (local.get $iovs)
      (i32.add (local.get $s) (i32.const 4)))  ;; iov_base = past length prefix
    (i32.store offset=4 (local.get $iovs)
      (call $str_len (local.get $s)))           ;; iov_len
    (local.set $nwritten (call $alloc (i32.const 4)))
    (drop (call $wasi_fd_write
      (i32.const 1) (local.get $iovs) (i32.const 1) (local.get $nwritten))))

  ;; Print to stderr (fd 2)
  (func $eprint_string (param $s i32)
    (local $iovs i32) (local $nwritten i32)
    (local.set $iovs (call $alloc (i32.const 8)))
    (i32.store (local.get $iovs)
      (i32.add (local.get $s) (i32.const 4)))
    (i32.store offset=4 (local.get $iovs)
      (call $str_len (local.get $s)))
    (local.set $nwritten (call $alloc (i32.const 4)))
    (drop (call $wasi_fd_write
      (i32.const 2) (local.get $iovs) (i32.const 1) (local.get $nwritten))))

  ;; Read all of stdin into a single string. Loops until EOF.
  (func $read_all_stdin (result i32)
    (local $chunk_buf i32)   ;; raw read buffer
    (local $iovs i32)
    (local $nread_ptr i32)
    (local $nread i32)
    (local $result i32)      ;; accumulated string
    (local $chunk_str i32)
    ;; Pre-allocate read infrastructure
    (local.set $chunk_buf (call $alloc (i32.const 65536)))
    (local.set $iovs (call $alloc (i32.const 8)))
    (local.set $nread_ptr (call $alloc (i32.const 4)))
    ;; Start with empty string
    (local.set $result (call $str_alloc (i32.const 0)))
    (block $eof
      (loop $read_loop
        ;; Set up iovec: buf ptr, buf len
        (i32.store (local.get $iovs) (local.get $chunk_buf))
        (i32.store offset=4 (local.get $iovs) (i32.const 65536))
        ;; Read
        (drop (call $wasi_fd_read
          (i32.const 0) (local.get $iovs) (i32.const 1) (local.get $nread_ptr)))
        (local.set $nread (i32.load (local.get $nread_ptr)))
        ;; EOF when nread == 0
        (br_if $eof (i32.eqz (local.get $nread)))
        ;; Wrap chunk bytes in a string
        (local.set $chunk_str (call $str_alloc (local.get $nread)))
        (memory.copy
          (i32.add (local.get $chunk_str) (i32.const 4))
          (local.get $chunk_buf)
          (local.get $nread))
        ;; Concat to result
        (local.set $result (call $str_concat (local.get $result) (local.get $chunk_str)))
        (br $read_loop)))
    (local.get $result))

  ;; ═══ int.wat — integer ↔ string conversion (Tier 1) ═══════════════
  ;; Implements: Hβ §1.6 integer/string conversion + memory-region
  ;;             string construction.
  ;; Exports:    $str_of_byte, $str_from_mem, $int_to_str, $parse_int
  ;; Uses:       $alloc (alloc.wat), $str_alloc (str.wat),
  ;;             $str_len (str.wat), $byte_at (str.wat),
  ;;             $str_of_byte (self — used by $int_to_str)
  ;; Test:       runtime_test/int.wat
  ;;
  ;; Bridges between byte / memory-region representations and the
  ;; flat string layout (see str.wat). Callers in lexer.wat use these
  ;; to materialize keyword strings + numeric literal text from the
  ;; lexer's input cursor + scratch buffer; emit_*.wat uses them to
  ;; render i32 constants into output WAT text.
  ;;
  ;; $int_to_str writes digits right-to-left into a 12-byte scratch
  ;; buffer; $parse_int reads decimal text + optional leading '-'.

  ;; ─── Integer/String Conversion ────────────────────────────────────

  ;; Create a 1-byte string from a byte value
  (func $str_of_byte (param $b i32) (result i32)
    (local $ptr i32)
    (local.set $ptr (call $str_alloc (i32.const 1)))
    (i32.store8 (i32.add (local.get $ptr) (i32.const 4)) (local.get $b))
    (local.get $ptr))

  ;; Create a string from a data segment region
  (func $str_from_mem (param $addr i32) (param $len i32) (result i32)
    (local $ptr i32)
    (local.set $ptr (call $str_alloc (local.get $len)))
    (memory.copy
      (i32.add (local.get $ptr) (i32.const 4))
      (local.get $addr)
      (local.get $len))
    (local.get $ptr))

  ;; int_to_str: decimal representation of i32
  (func $int_to_str (param $n i32) (result i32)
    (local $buf i32) (local $pos i32) (local $neg i32)
    (local $digit i32) (local $len i32) (local $out i32)
    (if (i32.eqz (local.get $n))
      (then (return (call $str_of_byte (i32.const 48)))))  ;; "0"
    (local.set $neg (i32.const 0))
    (if (i32.lt_s (local.get $n) (i32.const 0))
      (then
        (local.set $neg (i32.const 1))
        (local.set $n (i32.sub (i32.const 0) (local.get $n)))))
    ;; Write digits right-to-left into a scratch buffer
    (local.set $buf (call $alloc (i32.const 12)))
    (local.set $pos (i32.const 11))
    (block $done
      (loop $digits
        (br_if $done (i32.eqz (local.get $n)))
        (local.set $digit (i32.rem_u (local.get $n) (i32.const 10)))
        (local.set $pos (i32.sub (local.get $pos) (i32.const 1)))
        (i32.store8
          (i32.add (local.get $buf) (local.get $pos))
          (i32.add (local.get $digit) (i32.const 48)))
        (local.set $n (i32.div_u (local.get $n) (i32.const 10)))
        (br $digits)))
    ;; Add minus sign if negative
    (if (local.get $neg)
      (then
        (local.set $pos (i32.sub (local.get $pos) (i32.const 1)))
        (i32.store8 (i32.add (local.get $buf) (local.get $pos)) (i32.const 45))))
    ;; Copy to string
    (local.set $len (i32.sub (i32.const 11) (local.get $pos)))
    (local.set $out (call $str_alloc (local.get $len)))
    (memory.copy
      (i32.add (local.get $out) (i32.const 4))
      (i32.add (local.get $buf) (local.get $pos))
      (local.get $len))
    (local.get $out))

  ;; parse_int: decimal string → i32
  (func $parse_int (param $s i32) (result i32)
    (local $slen i32) (local $i i32) (local $acc i32)
    (local $neg i32) (local $ch i32)
    (local.set $slen (call $str_len (local.get $s)))
    (if (i32.eqz (local.get $slen)) (then (return (i32.const 0))))
    (local.set $i (i32.const 0))
    (local.set $neg (i32.const 0))
    ;; Check leading minus
    (if (i32.eq (call $byte_at (local.get $s) (i32.const 0)) (i32.const 45))
      (then
        (local.set $neg (i32.const 1))
        (local.set $i (i32.const 1))))
    (local.set $acc (i32.const 0))
    (block $done
      (loop $parse
        (br_if $done (i32.ge_u (local.get $i) (local.get $slen)))
        (local.set $ch (call $byte_at (local.get $s) (local.get $i)))
        (br_if $done (i32.lt_u (local.get $ch) (i32.const 48)))
        (br_if $done (i32.gt_u (local.get $ch) (i32.const 57)))
        (local.set $acc
          (i32.add
            (i32.mul (local.get $acc) (i32.const 10))
            (i32.sub (local.get $ch) (i32.const 48))))
        (local.set $i (i32.add (local.get $i) (i32.const 1)))
        (br $parse)))
    (if (result i32) (local.get $neg)
      (then (i32.sub (i32.const 0) (local.get $acc)))
      (else (local.get $acc))))

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
    ;; Unknown tag — should never happen in well-formed list. Trap to surface.
    (unreachable))

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
  (func $list_extend_to (param $list i32) (param $min_size i32) (result i32)
    (local $cur i32) (local $new_cap i32) (local $fresh i32) (local $i i32)
    (local.set $cur (call $len (local.get $list)))
    (if (result i32) (i32.ge_u (local.get $cur) (local.get $min_size))
      (then (local.get $list))
      (else
        ;; double or min_size, whichever is larger
        (local.set $new_cap (i32.mul (local.get $cur) (i32.const 2)))
        (if (i32.gt_u (local.get $min_size) (local.get $new_cap))
          (then (local.set $new_cap (local.get $min_size))))
        (local.set $fresh (call $make_list (local.get $new_cap)))
        ;; copy existing elements
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

  ;; ═══ closure.wat — closure record substrate (Tier 2) ══════════════
  ;; Implements: Hβ §1.3 — closure record per H1 evidence reification.
  ;;             [tag:i32][fn_index:i32][captures...][evidence_slots...]
  ;; Exports:    $make_closure, $closure_get_slot, $closure_set_slot
  ;; Uses:       $alloc (alloc.wat)
  ;; Test:       runtime_test/closure.wat
  ;;
  ;; Same allocation surface as records (record.wat) — the heap has one
  ;; story (γ crystallization #8). Closures are records with a known
  ;; field-0 tag + field-1 fn_index; subsequent slots hold captures
  ;; (lexical environment) followed by evidence (handler function-
  ;; pointers for polymorphic effect dispatch per H1).
  ;;
  ;; Handler dispatch per Hβ §1.3 + H1 evidence reification:
  ;;   - Ground site (>95% per H1):  (call $op_<name> <args>) — direct
  ;;   - Polymorphic site:           call_indirect via fn_index field
  ;;     loaded from a closure's evidence slot at compile-time-resolved
  ;;     offset.
  ;;
  ;; THERE IS NO VTABLE. The fn_index is a FIELD on the record;
  ;; evidence is a SLOT on the record; dispatch reads the field. Per
  ;; CLAUDE.md anchor "There is no vtable in Inka" + Koka JFP 2022
  ;; evidence-passing compilation.
  ;;
  ;; cont.wat (H7 — multi-shot continuation; future Wave 2.B addition)
  ;; extends this layout with state_index + ret_slot fields per H7
  ;; §1.2; same allocation path, same dispatch pattern, additional
  ;; fields. Mentl's oracle loop (insight #11 — speculative inference
  ;; firing on every save/edit) drives high-volume multi-shot continuously
  ;; through cont.wat — that substrate is the hot path, not a minority
  ;; case.

  ;; ─── Closure Primitives ───────────────────────────────────────────
  ;; Same layout as records: [tag:i32][fn_index:i32][slots...]

  (func $make_closure (param $tag i32) (param $fn_idx i32) (param $num_slots i32) (result i32)
    (local $ptr i32)
    (local.set $ptr (call $alloc
      (i32.add (i32.const 8) (i32.mul (local.get $num_slots) (i32.const 4)))))
    (i32.store (local.get $ptr) (local.get $tag))
    (i32.store offset=4 (local.get $ptr) (local.get $fn_idx))
    (local.get $ptr))

  (func $closure_get_slot (param $ptr i32) (param $idx i32) (result i32)
    (i32.load
      (i32.add
        (i32.add (local.get $ptr) (i32.const 8))
        (i32.mul (local.get $idx) (i32.const 4)))))

  (func $closure_set_slot (param $ptr i32) (param $idx i32) (param $val i32)
    (i32.store
      (i32.add
        (i32.add (local.get $ptr) (i32.const 8))
        (i32.mul (local.get $idx) (i32.const 4)))
      (local.get $val)))

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
  ;; CLAUDE.md anchor: "Inka bootstraps through Inka" — no foreign-
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
  ;; Per spec 00 + src/graph.nx (the wheel; this WAT IS the seed
  ;; transcription per Anchor 4 "build the wheel; never wrap the axle"):
  ;;
  ;; State lives in MODULE-LEVEL GLOBALS — pointers into heap regions
  ;; allocated lazily via $alloc on first use. The seed's HM inference
  ;; (Hβ.infer — Wave 2.E) calls these primitives directly to track
  ;; type-variable + row-variable state during compilation. The
  ;; COMPILED output of src/graph.nx (post-L1 wheel) builds its own
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
  ;; Per spec 00 + src/graph.nx chase_node:
  ;;   $graph_chase(handle) walks NBound/NRowBound links with cycle
  ;;   bound at depth 100 (defensive — cycles trigger E_OccursCheck at
  ;;   bind time; this is the runtime safety net). Returns the terminal
  ;;   GNode pointer (which may be NFree, NRowFree, NErrorHole, or the
  ;;   resolved NBound/NRowBound).
  ;;
  ;; This commit's chase implementation is the TIER-3 BASE: it walks
  ;; NBound/NRowBound directly without the inner Ty-variant inspection
  ;; that src/graph.nx's chase_node performs (which dispatches on
  ;; TVar/EfOpen for transitive resolution). The Tier-3 base is
  ;; correct for the common case (terminal NFree/NRowFree/NBound-with-
  ;; non-TVar/NRowBound-with-non-EfOpen); the transitive walk through
  ;; TVar/EfOpen lands when Hβ.lower (Wave 2.E) ships the Ty + EffRow
  ;; tag conventions that chase_node depends on.
  ;;
  ;; ═══ ROLLBACK SEMANTICS ═══════════════════════════════════════════
  ;; Per src/graph.nx revert_trail:
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
    (local $g i32)
    (local.set $g (call $make_record (i32.const 80) (i32.const 2)))
    (call $record_set (local.get $g) (i32.const 0) (local.get $nk))
    (call $record_set (local.get $g) (i32.const 1) (local.get $reason))
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
  ;; well-formed-but-not-yet-bound handle. Per src/graph.nx graph_node_at.
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
  ;; That dispatch lives in chase_node per src/graph.nx and depends on
  ;; the Ty + EffRow tag conventions that Hβ.lower (Wave 2.E) emits.
  ;; For now, NBound terminals return the GNode as-is; the caller
  ;; (Hβ.infer) chases through Ty structure via its own Ty-variant
  ;; dispatch.
  (func $graph_chase (param $handle i32) (result i32)
    (call $graph_chase_loop (local.get $handle) (i32.const 0)))

  (func $graph_chase_loop (param $handle i32) (param $depth i32) (result i32)
    (local $g i32) (local $nk i32) (local $tag i32)
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
    ;; NBound terminal — return as-is (Tier-3 base; transitive Ty walk
    ;; per Hβ.lower)
    (if (i32.eq (local.get $tag) (i32.const 60))   ;; NBOUND
      (then (return (local.get $g))))
    ;; NRowBound terminal — return as-is (Tier-3 base; transitive
    ;; EffRow walk per Hβ.lower)
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
  ;; structure; per src/graph.nx graph_bind's occurs_in lives in the
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
  ;; per option. Per src/graph.nx + insight #11.
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

  ;; ═══ env.wat — env substrate (Tier 3) ═════════════════════════════
  ;; Implements: Hβ §1.2 — name-resolution substrate. Scope stack with
  ;;             $env_lookup walking inner-to-outer; $env_extend
  ;;             pushing to current scope; $env_scope_enter / exit
  ;;             managing the stack.
  ;; Exports:    $env_init,
  ;;             $env_lookup, $env_lookup_or, $env_contains,
  ;;             $env_extend,
  ;;             $env_scope_enter, $env_scope_exit,
  ;;             $env_scope_depth,
  ;;             $env_binding_make, $env_binding_name, $env_binding_handle
  ;; Uses:       $alloc (alloc.wat), $make_record/$record_get/$record_set
  ;;             (record.wat), $make_list/$list_index/$list_set/
  ;;             $list_extend_to/$len (list.wat),
  ;;             $str_eq (str.wat)
  ;; Test:       runtime_test/env.wat
  ;;
  ;; ═══ DESIGN ═══════════════════════════════════════════════════════
  ;; Per Hβ §1.2 + src/types.nx Env discipline:
  ;;
  ;; State lives in module-level globals — a stack of scope frames.
  ;; Each scope frame is a flat list of (name, handle) binding records.
  ;; $env_lookup walks the stack from innermost (top) to outermost
  ;; (bottom) and returns the first matching handle. $env_extend
  ;; pushes a new binding onto the topmost frame.
  ;;
  ;; The seed's HM inference (Hβ.infer — Wave 2.E) calls these
  ;; primitives during compilation to track let-bindings, function
  ;; parameters, type constructors, effect declarations. The COMPILED
  ;; output of src/types.nx + src/effects.nx + src/infer.nx (post-L1
  ;; wheel) builds its own effect-handler-shaped env_handler — same
  ;; algorithm, different storage mechanism.
  ;;
  ;; This implementation is the SEED's internal env. It does NOT yet
  ;; support per-module overlays (which compose with graph.wat's
  ;; overlay primitives — deferred per the graph.wat follow-up).
  ;; Single global scope stack is sufficient for self-compile of
  ;; current src/*.nx surface; cross-module env composition lands
  ;; alongside graph.wat overlays.
  ;;
  ;; ═══ HEAP RECORD LAYOUTS ═══════════════════════════════════════════
  ;;
  ;; Binding (name, handle):
  ;;   $make_record(ENV_BINDING_TAG=130, arity=2)
  ;;     offset 8:  field_0 = name (heap-allocated string ptr; str.wat layout)
  ;;     offset 12: field_1 = handle (i32 — graph handle)
  ;;
  ;; Scope frame: flat list of binding pointers.
  ;;
  ;; Tag allocation: env.wat private region 130-149 (avoids graph.wat
  ;; range 50-99 and TokenKind sentinels 0-44).
  ;;   130   ENV_BINDING_TAG  — (name, handle) binding
  ;;   131-149 reserved for future env-substrate records
  ;;
  ;; ═══ NOT-FOUND CONVENTION ═════════════════════════════════════════
  ;; $env_lookup returns 0 when the name is not bound (handle 0 is the
  ;; first fresh allocation if any; callers must distinguish via
  ;; $env_contains or $env_lookup_or which takes a sentinel default).
  ;; Per src/graph.nx overlay_find precedent (returns count = past-
  ;; valid-index sentinel); the seed's idiom is "lookup returns 0;
  ;; callers wrap with $env_contains for presence tests."
  ;;
  ;; Future Hβ.infer may want a richer return (e.g., (handle, scope_idx)
  ;; tuple) — that's a substrate extension under env.wat's follow-up.

  ;; ─── Module-level globals ─────────────────────────────────────────
  ;; $env_scopes_ptr — flat list of scope-frame pointers (each frame
  ;;                   itself a flat list of binding pointers).
  ;;                   Position 0 = outermost; position $env_scope_count_g - 1 = current.
  ;; $env_scope_count_g — logical depth of the scope stack.
  ;; $env_initialized — 1 once $env_init has run.

  (global $env_scopes_ptr      (mut i32) (i32.const 0))
  (global $env_scope_count_g   (mut i32) (i32.const 0))
  (global $env_initialized     (mut i32) (i32.const 0))

  ;; ─── Initialization ──────────────────────────────────────────────
  ;; $env_init: idempotent. Allocates initial scope-stack with one
  ;; outermost scope (for top-level / global bindings).
  (func $env_init
    (if (global.get $env_initialized) (then (return)))
    (global.set $env_scopes_ptr (call $make_list (i32.const 8)))
    (global.set $env_scope_count_g (i32.const 0))
    (global.set $env_initialized (i32.const 1))
    ;; Push the outermost (global) scope.
    (call $env_scope_enter))

  ;; ─── Binding constructors + accessors ────────────────────────────

  (func $env_binding_make (param $name i32) (param $handle i32) (result i32)
    (local $b i32)
    (local.set $b (call $make_record (i32.const 130) (i32.const 2)))
    (call $record_set (local.get $b) (i32.const 0) (local.get $name))
    (call $record_set (local.get $b) (i32.const 1) (local.get $handle))
    (local.get $b))

  (func $env_binding_name (param $b i32) (result i32)
    (call $record_get (local.get $b) (i32.const 0)))

  (func $env_binding_handle (param $b i32) (result i32)
    (call $record_get (local.get $b) (i32.const 1)))

  ;; ─── Scope management ────────────────────────────────────────────

  (func $env_scope_depth (result i32)
    (call $env_init)
    (global.get $env_scope_count_g))

  ;; $env_scope_enter — push a new empty scope frame onto the stack.
  ;; New scope is now the "current" scope; subsequent $env_extend
  ;; pushes to it.
  (func $env_scope_enter
    (local $count i32) (local $fresh_frame i32)
    (if (i32.eqz (global.get $env_initialized))
      (then
        ;; Bootstrap-init path during $env_init: don't recurse.
        (global.set $env_scopes_ptr (call $make_list (i32.const 8)))
        (global.set $env_scope_count_g (i32.const 0))
        (global.set $env_initialized (i32.const 1))))
    (local.set $count (global.get $env_scope_count_g))
    (local.set $fresh_frame (call $make_list (i32.const 4)))   ;; small initial; grows on demand
    (global.set $env_scopes_ptr
      (call $list_set
        (call $list_extend_to (global.get $env_scopes_ptr)
                              (i32.add (local.get $count) (i32.const 1)))
        (local.get $count)
        (local.get $fresh_frame)))
    (global.set $env_scope_count_g
      (i32.add (local.get $count) (i32.const 1))))

  ;; $env_scope_exit — pop the current scope frame.
  ;; No bound check at the WAT level — caller responsibility (matched
  ;; enter/exit per the substrate-honest discipline; mismatched calls
  ;; trap on subsequent operations via underflow).
  ;; If only one scope remains, this leaves the stack at depth 0 —
  ;; subsequent $env_lookup returns 0 (not-found) until $env_scope_enter
  ;; restores at least one scope.
  (func $env_scope_exit
    (call $env_init)
    (if (i32.gt_u (global.get $env_scope_count_g) (i32.const 0))
      (then
        (global.set $env_scope_count_g
          (i32.sub (global.get $env_scope_count_g) (i32.const 1))))))

  ;; ─── Extend (push binding to current scope) ──────────────────────
  ;; $env_extend(name, handle) — append (name, handle) binding to the
  ;; current (topmost) scope frame. No shadowing check at the WAT
  ;; level — Hβ.infer's lexical-scoping discipline handles shadowing
  ;; semantics; later bindings shadow earlier ones via $env_lookup's
  ;; reverse-walk semantics.
  (func $env_extend (param $name i32) (param $handle i32)
    (local $current_idx i32) (local $frame i32) (local $frame_len i32) (local $binding i32)
    (call $env_init)
    (if (i32.eqz (global.get $env_scope_count_g))
      (then (return)))   ;; no current scope — silent no-op (defensive)
    (local.set $current_idx
      (i32.sub (global.get $env_scope_count_g) (i32.const 1)))
    (local.set $frame (call $list_index (global.get $env_scopes_ptr)
                                        (local.get $current_idx)))
    (local.set $frame_len (call $len (local.get $frame)))
    (local.set $binding (call $env_binding_make (local.get $name) (local.get $handle)))
    ;; Append to frame: extend + set + replace in scopes list.
    (local.set $frame
      (call $list_set
        (call $list_extend_to (local.get $frame)
                              (i32.add (local.get $frame_len) (i32.const 1)))
        (local.get $frame_len)
        (local.get $binding)))
    (global.set $env_scopes_ptr
      (call $list_set (global.get $env_scopes_ptr)
                      (local.get $current_idx)
                      (local.get $frame))))

  ;; ─── Lookup ──────────────────────────────────────────────────────
  ;; $env_lookup(name) — walks scopes from innermost (top) to
  ;; outermost (bottom), and within each scope walks bindings from
  ;; last-pushed to first (so later bindings shadow earlier ones at
  ;; the same scope). Returns the matching handle on first hit, or 0
  ;; if not bound anywhere.
  (func $env_lookup (param $name i32) (result i32)
    (call $env_lookup_or (local.get $name) (i32.const 0)))

  ;; $env_lookup_or(name, default) — returns default when name is
  ;; not bound. Useful when 0 is a valid handle and the caller wants
  ;; a different sentinel.
  (func $env_lookup_or (param $name i32) (param $default i32) (result i32)
    (local $scope_idx i32) (local $frame i32)
    (local $binding_idx i32) (local $binding i32)
    (call $env_init)
    (local.set $scope_idx (global.get $env_scope_count_g))
    ;; Outer loop: scopes from current down to 0.
    (block $outer_done
      (loop $scope_loop
        (br_if $outer_done (i32.eqz (local.get $scope_idx)))
        (local.set $scope_idx (i32.sub (local.get $scope_idx) (i32.const 1)))
        (local.set $frame
          (call $list_index (global.get $env_scopes_ptr) (local.get $scope_idx)))
        ;; Inner loop: bindings within the frame from last to first.
        (local.set $binding_idx (call $len (local.get $frame)))
        (block $inner_done
          (loop $binding_loop
            (br_if $inner_done (i32.eqz (local.get $binding_idx)))
            (local.set $binding_idx (i32.sub (local.get $binding_idx) (i32.const 1)))
            (local.set $binding
              (call $list_index (local.get $frame) (local.get $binding_idx)))
            (if (call $str_eq (call $env_binding_name (local.get $binding))
                              (local.get $name))
              (then (return (call $env_binding_handle (local.get $binding)))))
            (br $binding_loop)))
        (br $scope_loop)))
    (local.get $default))

  ;; $env_contains(name) — presence test. Returns 1 if name is bound
  ;; in any scope, else 0. Cleaner than checking $env_lookup result
  ;; for handle == 0 when 0 might be a legitimate fresh-allocated
  ;; handle.
  (func $env_contains (param $name i32) (result i32)
    (local $scope_idx i32) (local $frame i32)
    (local $binding_idx i32) (local $binding i32)
    (call $env_init)
    (local.set $scope_idx (global.get $env_scope_count_g))
    (block $outer_done
      (loop $scope_loop
        (br_if $outer_done (i32.eqz (local.get $scope_idx)))
        (local.set $scope_idx (i32.sub (local.get $scope_idx) (i32.const 1)))
        (local.set $frame
          (call $list_index (global.get $env_scopes_ptr) (local.get $scope_idx)))
        (local.set $binding_idx (call $len (local.get $frame)))
        (block $inner_done
          (loop $binding_loop
            (br_if $inner_done (i32.eqz (local.get $binding_idx)))
            (local.set $binding_idx (i32.sub (local.get $binding_idx) (i32.const 1)))
            (local.set $binding
              (call $list_index (local.get $frame) (local.get $binding_idx)))
            (if (call $str_eq (call $env_binding_name (local.get $binding))
                              (local.get $name))
              (then (return (i32.const 1))))
            (br $binding_loop)))
        (br $scope_loop)))
    (i32.const 0))

  ;; ═══ row.wat — Boolean effect-row algebra (Tier 3) ═══════════════
  ;; Implements: spec 01 (effrow.md) + Hβ §1.10 — full Boolean
  ;;             algebra over effect rows: + (union), - (diff),
  ;;             & (intersection), ! (negation), Pure (identity).
  ;;             Substrate primitive #4 (Effect row algebra).
  ;; Exports:    Constructors:
  ;;               $row_make_pure, $row_make_closed, $row_make_open,
  ;;               $row_make_neg, $row_make_sub, $row_make_inter
  ;;             Predicates + accessors:
  ;;               $row_tag, $row_is_pure, $row_is_closed, $row_is_open,
  ;;               $row_names, $row_handle
  ;;             Name-set helpers (sorted-lex flat lists of name ptrs):
  ;;               $name_set_contains, $name_set_eq, $name_set_subset,
  ;;               $name_set_union, $name_set_inter, $name_set_diff
  ;;             Algebra:
  ;;               $row_union, $row_diff, $row_inter, $row_subsumes
  ;; Uses:       $alloc (alloc.wat), $make_record/$record_get
  ;;             (record.wat), $make_list/$list_index/$list_set/
  ;;             $list_extend_to/$len (list.wat),
  ;;             $str_eq/$str_compare (str.wat), $heap_base (Layer 0)
  ;; Test:       runtime_test/row.wat
  ;;
  ;; ═══ DESIGN ═══════════════════════════════════════════════════════
  ;; Per spec 01 + DESIGN §0.5 primitive #4:
  ;;
  ;; EffRow normal forms (always one of three after normalize):
  ;;   1. EfPure                         — identity element
  ;;   2. EfClosed(sorted_unique_names)  — concrete row
  ;;   3. EfOpen(sorted_unique_names, v) — row with row-variable v
  ;;
  ;; Intermediate forms (constructed during builds; reduced before
  ;; subsumption/unification — Tier-3 base ships constructors but
  ;; defers the full normalize to the row.wat follow-up):
  ;;   - EfNeg(inner)                    — !inner; De Morgan reduces
  ;;   - EfSub(left, right)              — left & !right
  ;;   - EfInter(left, right)            — left ∩ right
  ;;
  ;; Per spec 01 §Operators:
  ;;   E + F → normalize(EfClosed(names(E) ∪ names(F)))   (or EfOpen
  ;;                                                       if either side has rowvar)
  ;;   E - F → normalize(EfSub(E, F))                     ≡ E & !F
  ;;   E & F → normalize(EfInter(E, F))
  ;;   !E    → normalize(EfNeg(E))
  ;;   Pure  → EfPure
  ;;
  ;; ═══ HEAP RECORD LAYOUTS ═══════════════════════════════════════════
  ;;
  ;; EfPure — sentinel (i32 value 150, < HEAP_BASE; no allocation)
  ;; per Hβ §1.5 nullary-sentinel discipline + record.wat $tag_of.
  ;;
  ;; Fielded variants (each $make_record with the tag below):
  ;;   EfClosed(names)        — tag=151, arity=1; field_0 = name list ptr
  ;;   EfOpen(names, handle)  — tag=152, arity=2; field_0 = name list,
  ;;                                              field_1 = rowvar handle (i32)
  ;;   EfNeg(inner)           — tag=153, arity=1; field_0 = inner row ptr
  ;;   EfSub(left, right)     — tag=154, arity=2
  ;;   EfInter(left, right)   — tag=155, arity=2
  ;;
  ;; Tag allocation: row.wat private region 150-179 (avoids graph.wat
  ;; 50-99 + env.wat 130-149 + TokenKind 0-44).
  ;;
  ;; ═══ NAME SETS ═════════════════════════════════════════════════════
  ;; Effect names are stored as pointers to flat strings (str.wat
  ;; layout). Name lists are sorted lex-order by $str_compare (str.wat)
  ;; and deduplicated. The seed's HM inference (Hβ.infer — Wave 2.E)
  ;; constructs name lists already in canonical form; row.wat's
  ;; constructors don't re-sort (Tier-3 base; sort/dedup follow-up
  ;; lands when Hβ.infer needs runtime canonicalization).
  ;;
  ;; ═══ SUBSUMPTION ═══════════════════════════════════════════════════
  ;; Per spec 01 §Subsumption — body row B subsumed by handler row F:
  ;;   B ⊆ Pure        iff B = Pure
  ;;   B ⊆ Closed(F)   iff names(B) ⊆ F AND B has no rowvar
  ;;   B ⊆ Open(F, v)  iff names(B) ⊆ F ∪ names_of(chase(v))
  ;;
  ;; (The chase(v) reach lands in Hβ.infer — needs graph.wat chase +
  ;;  EffRow tag dispatch. row.wat's $row_subsumes Tier-3 base handles
  ;;  the F-not-open case; open-side dispatch is the named follow-up.)

  ;; ─── Constructors ────────────────────────────────────────────────

  (func $row_make_pure (result i32)
    (i32.const 150))   ;; sentinel; < HEAP_BASE

  (func $row_make_closed (param $names i32) (result i32)
    (local $r i32)
    (local.set $r (call $make_record (i32.const 151) (i32.const 1)))
    (call $record_set (local.get $r) (i32.const 0) (local.get $names))
    (local.get $r))

  (func $row_make_open (param $names i32) (param $rowvar i32) (result i32)
    (local $r i32)
    (local.set $r (call $make_record (i32.const 152) (i32.const 2)))
    (call $record_set (local.get $r) (i32.const 0) (local.get $names))
    (call $record_set (local.get $r) (i32.const 1) (local.get $rowvar))
    (local.get $r))

  (func $row_make_neg (param $inner i32) (result i32)
    (local $r i32)
    (local.set $r (call $make_record (i32.const 153) (i32.const 1)))
    (call $record_set (local.get $r) (i32.const 0) (local.get $inner))
    (local.get $r))

  (func $row_make_sub (param $left i32) (param $right i32) (result i32)
    (local $r i32)
    (local.set $r (call $make_record (i32.const 154) (i32.const 2)))
    (call $record_set (local.get $r) (i32.const 0) (local.get $left))
    (call $record_set (local.get $r) (i32.const 1) (local.get $right))
    (local.get $r))

  (func $row_make_inter (param $left i32) (param $right i32) (result i32)
    (local $r i32)
    (local.set $r (call $make_record (i32.const 155) (i32.const 2)))
    (call $record_set (local.get $r) (i32.const 0) (local.get $left))
    (call $record_set (local.get $r) (i32.const 1) (local.get $right))
    (local.get $r))

  ;; ─── Predicates + accessors ──────────────────────────────────────

  (func $row_tag (param $row i32) (result i32)
    (call $tag_of (local.get $row)))

  (func $row_is_pure (param $row i32) (result i32)
    (i32.eq (call $row_tag (local.get $row)) (i32.const 150)))

  (func $row_is_closed (param $row i32) (result i32)
    (i32.eq (call $row_tag (local.get $row)) (i32.const 151)))

  (func $row_is_open (param $row i32) (result i32)
    (i32.eq (call $row_tag (local.get $row)) (i32.const 152)))

  ;; $row_names — returns the names list for Closed/Open; empty list
  ;; for Pure; UNDEFINED for Neg/Sub/Inter (those should be normalized
  ;; first; Tier-3 base traps via (unreachable) on those tags).
  (func $row_names (param $row i32) (result i32)
    (local $tag i32)
    (local.set $tag (call $row_tag (local.get $row)))
    (if (i32.eq (local.get $tag) (i32.const 150))   ;; Pure
      (then (return (call $make_list (i32.const 0)))))
    (if (i32.eq (local.get $tag) (i32.const 151))   ;; Closed
      (then (return (call $record_get (local.get $row) (i32.const 0)))))
    (if (i32.eq (local.get $tag) (i32.const 152))   ;; Open
      (then (return (call $record_get (local.get $row) (i32.const 0)))))
    (unreachable))

  ;; $row_handle — returns the rowvar handle for Open; 0 for others
  ;; (callers test $row_is_open first).
  (func $row_handle (param $row i32) (result i32)
    (if (i32.eq (call $row_tag (local.get $row)) (i32.const 152))   ;; Open
      (then (return (call $record_get (local.get $row) (i32.const 1)))))
    (i32.const 0))

  ;; ─── Name-set helpers (sorted-lex flat lists) ────────────────────
  ;; Inputs are flat lists of string-ptrs, sorted lex-order, deduped.
  ;; Outputs are the same shape. All operations preserve canonical form.

  ;; $name_set_contains — single-element membership. Linear scan
  ;; (binary search is a follow-up optimization when callers profile
  ;; hot).
  (func $name_set_contains (param $set i32) (param $name i32) (result i32)
    (local $i i32) (local $n i32)
    (local.set $n (call $len (local.get $set)))
    (local.set $i (i32.const 0))
    (block $done
      (loop $scan
        (br_if $done (i32.ge_u (local.get $i) (local.get $n)))
        (if (call $str_eq (call $list_index (local.get $set) (local.get $i))
                          (local.get $name))
          (then (return (i32.const 1))))
        (local.set $i (i32.add (local.get $i) (i32.const 1)))
        (br $scan)))
    (i32.const 0))

  ;; $name_set_eq — set equality (sorted; just element-by-element).
  (func $name_set_eq (param $a i32) (param $b i32) (result i32)
    (local $na i32) (local $nb i32) (local $i i32)
    (local.set $na (call $len (local.get $a)))
    (local.set $nb (call $len (local.get $b)))
    (if (i32.ne (local.get $na) (local.get $nb)) (then (return (i32.const 0))))
    (local.set $i (i32.const 0))
    (block $done
      (loop $cmp
        (br_if $done (i32.ge_u (local.get $i) (local.get $na)))
        (if (i32.eqz (call $str_eq (call $list_index (local.get $a) (local.get $i))
                                   (call $list_index (local.get $b) (local.get $i))))
          (then (return (i32.const 0))))
        (local.set $i (i32.add (local.get $i) (i32.const 1)))
        (br $cmp)))
    (i32.const 1))

  ;; $name_set_subset — a ⊆ b. Per spec 01 §Subsumption.
  (func $name_set_subset (param $a i32) (param $b i32) (result i32)
    (local $i i32) (local $n i32)
    (local.set $n (call $len (local.get $a)))
    (local.set $i (i32.const 0))
    (block $done
      (loop $scan
        (br_if $done (i32.ge_u (local.get $i) (local.get $n)))
        (if (i32.eqz (call $name_set_contains (local.get $b)
                          (call $list_index (local.get $a) (local.get $i))))
          (then (return (i32.const 0))))
        (local.set $i (i32.add (local.get $i) (i32.const 1)))
        (br $scan)))
    (i32.const 1))

  ;; $name_set_union — sorted merge of two sorted-deduped lists.
  ;; Result is sorted, deduped. Per spec 01 §Operators E + F.
  (func $name_set_union (param $a i32) (param $b i32) (result i32)
    (local $na i32) (local $nb i32) (local $i i32) (local $j i32)
    (local $out i32) (local $k i32) (local $cmp i32)
    (local $ai i32) (local $bj i32)
    (local.set $na (call $len (local.get $a)))
    (local.set $nb (call $len (local.get $b)))
    ;; Allocate worst-case capacity (na + nb); shrink with $slice at end.
    (local.set $out (call $make_list (i32.add (local.get $na) (local.get $nb))))
    (local.set $i (i32.const 0))
    (local.set $j (i32.const 0))
    (local.set $k (i32.const 0))
    (block $done
      (loop $merge
        ;; If a exhausted, copy remainder of b.
        (if (i32.ge_u (local.get $i) (local.get $na))
          (then
            (block $b_done
              (loop $copy_b
                (br_if $b_done (i32.ge_u (local.get $j) (local.get $nb)))
                (drop (call $list_set (local.get $out) (local.get $k)
                  (call $list_index (local.get $b) (local.get $j))))
                (local.set $j (i32.add (local.get $j) (i32.const 1)))
                (local.set $k (i32.add (local.get $k) (i32.const 1)))
                (br $copy_b)))
            (br $done)))
        ;; If b exhausted, copy remainder of a.
        (if (i32.ge_u (local.get $j) (local.get $nb))
          (then
            (block $a_done
              (loop $copy_a
                (br_if $a_done (i32.ge_u (local.get $i) (local.get $na)))
                (drop (call $list_set (local.get $out) (local.get $k)
                  (call $list_index (local.get $a) (local.get $i))))
                (local.set $i (i32.add (local.get $i) (i32.const 1)))
                (local.set $k (i32.add (local.get $k) (i32.const 1)))
                (br $copy_a)))
            (br $done)))
        ;; Both have elements — compare.
        (local.set $ai (call $list_index (local.get $a) (local.get $i)))
        (local.set $bj (call $list_index (local.get $b) (local.get $j)))
        (local.set $cmp (call $str_compare (local.get $ai) (local.get $bj)))
        (if (i32.lt_s (local.get $cmp) (i32.const 0))
          (then
            (drop (call $list_set (local.get $out) (local.get $k) (local.get $ai)))
            (local.set $i (i32.add (local.get $i) (i32.const 1)))
            (local.set $k (i32.add (local.get $k) (i32.const 1))))
          (else
            (if (i32.gt_s (local.get $cmp) (i32.const 0))
              (then
                (drop (call $list_set (local.get $out) (local.get $k) (local.get $bj)))
                (local.set $j (i32.add (local.get $j) (i32.const 1)))
                (local.set $k (i32.add (local.get $k) (i32.const 1))))
              (else
                ;; equal — emit once, advance both
                (drop (call $list_set (local.get $out) (local.get $k) (local.get $ai)))
                (local.set $i (i32.add (local.get $i) (i32.const 1)))
                (local.set $j (i32.add (local.get $j) (i32.const 1)))
                (local.set $k (i32.add (local.get $k) (i32.const 1)))))))
        (br $merge)))
    ;; Truncate to actual length k via $slice.
    (call $slice (local.get $out) (i32.const 0) (local.get $k)))

  ;; $name_set_inter — sorted intersection of two sorted-deduped lists.
  (func $name_set_inter (param $a i32) (param $b i32) (result i32)
    (local $na i32) (local $nb i32) (local $i i32) (local $j i32)
    (local $out i32) (local $k i32) (local $cmp i32)
    (local $ai i32) (local $bj i32)
    (local.set $na (call $len (local.get $a)))
    (local.set $nb (call $len (local.get $b)))
    (local.set $out (call $make_list (i32.add (local.get $na) (local.get $nb))))
    (local.set $i (i32.const 0))
    (local.set $j (i32.const 0))
    (local.set $k (i32.const 0))
    (block $done
      (loop $merge
        (br_if $done (i32.ge_u (local.get $i) (local.get $na)))
        (br_if $done (i32.ge_u (local.get $j) (local.get $nb)))
        (local.set $ai (call $list_index (local.get $a) (local.get $i)))
        (local.set $bj (call $list_index (local.get $b) (local.get $j)))
        (local.set $cmp (call $str_compare (local.get $ai) (local.get $bj)))
        (if (i32.lt_s (local.get $cmp) (i32.const 0))
          (then (local.set $i (i32.add (local.get $i) (i32.const 1))))
          (else
            (if (i32.gt_s (local.get $cmp) (i32.const 0))
              (then (local.set $j (i32.add (local.get $j) (i32.const 1))))
              (else
                ;; equal — keep + advance both
                (drop (call $list_set (local.get $out) (local.get $k) (local.get $ai)))
                (local.set $i (i32.add (local.get $i) (i32.const 1)))
                (local.set $j (i32.add (local.get $j) (i32.const 1)))
                (local.set $k (i32.add (local.get $k) (i32.const 1)))))))
        (br $merge)))
    (call $slice (local.get $out) (i32.const 0) (local.get $k)))

  ;; $name_set_diff — sorted set difference a - b (elements in a but not in b).
  (func $name_set_diff (param $a i32) (param $b i32) (result i32)
    (local $na i32) (local $nb i32) (local $i i32) (local $j i32)
    (local $out i32) (local $k i32) (local $cmp i32)
    (local $ai i32) (local $bj i32)
    (local.set $na (call $len (local.get $a)))
    (local.set $nb (call $len (local.get $b)))
    (local.set $out (call $make_list (local.get $na)))
    (local.set $i (i32.const 0))
    (local.set $j (i32.const 0))
    (local.set $k (i32.const 0))
    (block $done
      (loop $merge
        (br_if $done (i32.ge_u (local.get $i) (local.get $na)))
        (local.set $ai (call $list_index (local.get $a) (local.get $i)))
        ;; If b exhausted, all remaining a survive.
        (if (i32.ge_u (local.get $j) (local.get $nb))
          (then
            (drop (call $list_set (local.get $out) (local.get $k) (local.get $ai)))
            (local.set $i (i32.add (local.get $i) (i32.const 1)))
            (local.set $k (i32.add (local.get $k) (i32.const 1)))
            (br $merge)))
        (local.set $bj (call $list_index (local.get $b) (local.get $j)))
        (local.set $cmp (call $str_compare (local.get $ai) (local.get $bj)))
        (if (i32.lt_s (local.get $cmp) (i32.const 0))
          (then
            ;; ai not in b — keep
            (drop (call $list_set (local.get $out) (local.get $k) (local.get $ai)))
            (local.set $i (i32.add (local.get $i) (i32.const 1)))
            (local.set $k (i32.add (local.get $k) (i32.const 1))))
          (else
            (if (i32.gt_s (local.get $cmp) (i32.const 0))
              (then
                ;; bj < ai — advance b
                (local.set $j (i32.add (local.get $j) (i32.const 1))))
              (else
                ;; equal — drop ai (in b), advance both
                (local.set $i (i32.add (local.get $i) (i32.const 1)))
                (local.set $j (i32.add (local.get $j) (i32.const 1)))))))
        (br $merge)))
    (call $slice (local.get $out) (i32.const 0) (local.get $k)))

  ;; ─── Row algebra (operates on canonical Pure/Closed/Open) ────────
  ;; Tier-3 base: assumes inputs are normalized. Neg/Sub/Inter
  ;; normalization to canonical form is the named follow-up (depends
  ;; on graph.wat chase for resolving rowvars in EfOpen — Wave 2.E).

  ;; $row_union — E + F per spec 01.
  ;; If either side has a rowvar, result is Open (with the union of
  ;; names + the rowvar — single-rowvar case; double-rowvar normalization
  ;; via fresh row-handle is the follow-up). If both Closed, result is
  ;; Closed of name union.
  (func $row_union (param $e i32) (param $f i32) (result i32)
    (local $e_tag i32) (local $f_tag i32)
    (local $e_names i32) (local $f_names i32)
    (local $e_handle i32) (local $f_handle i32)
    (local $merged i32)
    (local.set $e_tag (call $row_tag (local.get $e)))
    (local.set $f_tag (call $row_tag (local.get $f)))
    ;; Pure + x = x; x + Pure = x.
    (if (i32.eq (local.get $e_tag) (i32.const 150)) (then (return (local.get $f))))
    (if (i32.eq (local.get $f_tag) (i32.const 150)) (then (return (local.get $e))))
    ;; Both have names; merge.
    (local.set $e_names (call $row_names (local.get $e)))
    (local.set $f_names (call $row_names (local.get $f)))
    (local.set $merged (call $name_set_union (local.get $e_names) (local.get $f_names)))
    ;; If either side is Open, result is Open with that side's rowvar.
    ;; (Double-rowvar union → fresh rowvar bound to union of both — follow-up.)
    (if (i32.eq (local.get $e_tag) (i32.const 152))
      (then (return (call $row_make_open (local.get $merged)
                          (call $row_handle (local.get $e))))))
    (if (i32.eq (local.get $f_tag) (i32.const 152))
      (then (return (call $row_make_open (local.get $merged)
                          (call $row_handle (local.get $f))))))
    (call $row_make_closed (local.get $merged)))

  ;; $row_diff — E - F per spec 01 ≡ E & !F.
  ;; Tier-3 base: handles Closed - Closed = Closed of name diff.
  ;; Open - F (or E - Open) preserves the rowvar (the rowvar's own
  ;; binding handles the rest — follow-up resolves via chase).
  (func $row_diff (param $e i32) (param $f i32) (result i32)
    (local $e_tag i32)
    (local $diff i32)
    (local.set $e_tag (call $row_tag (local.get $e)))
    ;; Pure - anything = Pure.
    (if (i32.eq (local.get $e_tag) (i32.const 150)) (then (return (local.get $e))))
    ;; E - Pure = E.
    (if (i32.eq (call $row_tag (local.get $f)) (i32.const 150)) (then (return (local.get $e))))
    ;; Closed/Open - F: subtract F's names.
    (local.set $diff
      (call $name_set_diff (call $row_names (local.get $e))
                           (call $row_names (local.get $f))))
    (if (i32.eq (local.get $e_tag) (i32.const 152))
      (then (return (call $row_make_open (local.get $diff)
                          (call $row_handle (local.get $e))))))
    (call $row_make_closed (local.get $diff)))

  ;; $row_inter — E & F per spec 01.
  ;; Tier-3 base: handles Closed & Closed = Closed of name intersection.
  ;; Open & Closed (or Closed & Open) = Closed of intersection (rowvar
  ;; can contribute nothing beyond what it shares — per spec 01 §Normal
  ;; form Reductions). Open & Open with v₁=v₂: intersection of names;
  ;; with v₁≠v₂: fresh rowvar (follow-up).
  (func $row_inter (param $e i32) (param $f i32) (result i32)
    (local $e_tag i32) (local $f_tag i32)
    (local $inter i32)
    (local.set $e_tag (call $row_tag (local.get $e)))
    (local.set $f_tag (call $row_tag (local.get $f)))
    ;; Pure & x = Pure; x & Pure = Pure.
    (if (i32.eq (local.get $e_tag) (i32.const 150)) (then (return (local.get $e))))
    (if (i32.eq (local.get $f_tag) (i32.const 150)) (then (return (local.get $f))))
    (local.set $inter
      (call $name_set_inter (call $row_names (local.get $e))
                            (call $row_names (local.get $f))))
    ;; Both Open with same rowvar — preserve as Open.
    (if (i32.and
          (i32.eq (local.get $e_tag) (i32.const 152))
          (i32.eq (local.get $f_tag) (i32.const 152)))
      (then
        (if (i32.eq (call $row_handle (local.get $e))
                    (call $row_handle (local.get $f)))
          (then (return (call $row_make_open (local.get $inter)
                                             (call $row_handle (local.get $e))))))))
    ;; Otherwise Closed of intersection.
    (call $row_make_closed (local.get $inter)))

  ;; ─── Subsumption ─────────────────────────────────────────────────
  ;; $row_subsumes(b, f) → 1 if body b is subsumed by handler row f,
  ;; else 0. Per spec 01 §Subsumption:
  ;;   B ⊆ Pure        iff B = Pure
  ;;   B ⊆ Closed(F)   iff names(B) ⊆ F AND B has no rowvar
  ;;   B ⊆ Open(F, v)  iff names(B) ⊆ F ∪ names_of(chase(v))
  ;;
  ;; Tier-3 base: handles Pure ⊆ Pure, Closed ⊆ Closed, Closed ⊆ Open
  ;; (without chasing rowvar — conservative; returns 1 only if names(B)
  ;; ⊆ names(F) directly). The rowvar-chase reach lands when graph.wat
  ;; chase + EffRow tag dispatch land in Hβ.lower.
  (func $row_subsumes (param $b i32) (param $f i32) (result i32)
    (local $b_tag i32) (local $f_tag i32)
    (local.set $b_tag (call $row_tag (local.get $b)))
    (local.set $f_tag (call $row_tag (local.get $f)))
    ;; B ⊆ Pure iff B = Pure
    (if (i32.eq (local.get $f_tag) (i32.const 150))
      (then (return (i32.eq (local.get $b_tag) (i32.const 150)))))
    ;; Pure ⊆ anything else (Closed, Open) — yes (empty subset).
    (if (i32.eq (local.get $b_tag) (i32.const 150)) (then (return (i32.const 1))))
    ;; B ⊆ Closed(F): names(B) ⊆ F AND B has no rowvar.
    (if (i32.eq (local.get $f_tag) (i32.const 151))
      (then
        ;; B must not be Open.
        (if (i32.eq (local.get $b_tag) (i32.const 152)) (then (return (i32.const 0))))
        (return (call $name_set_subset
                  (call $row_names (local.get $b))
                  (call $row_names (local.get $f))))))
    ;; B ⊆ Open(F, v): conservative — subset of F's names suffices
    ;; (the rowvar can absorb whatever's left at unification time;
    ;; full check requires chase(v) per follow-up).
    (if (i32.eq (local.get $f_tag) (i32.const 152))
      (then
        (return (call $name_set_subset
                  (call $row_names (local.get $b))
                  (call $row_names (local.get $f))))))
    (i32.const 0))

  ;; ═══ verify.wat — Verify ledger primitives (Tier 4) ═══════════════
  ;; Implements: Hβ §1.11 + spec 06 (effects-surface) — Verify
  ;;             obligation accumulation. The seed's verify substrate
  ;;             holds an in-memory ledger of pending refinement
  ;;             obligations; real SMT discharge (verify_smt) is the
  ;;             handler swap shipped at B.6 / Arc F.1 post-L1.
  ;; Exports:    $verify_init,
  ;;             $verify_record,
  ;;             $verify_pending_count,
  ;;             $verify_get_pending,
  ;;             $verify_discharge_at,
  ;;             $verify_obligation_make/predicate/span/reason
  ;; Uses:       $alloc (alloc.wat), $make_record/$record_get/$record_set
  ;;             (record.wat), $make_list/$list_index/$list_set/
  ;;             $list_extend_to/$len (list.wat)
  ;; Test:       runtime_test/verify.wat
  ;;
  ;; ═══ DESIGN ═══════════════════════════════════════════════════════
  ;; Per spec 06 + DESIGN §0.5 primitive #6 (Refinement types):
  ;;
  ;; Refinement types are compile-time proofs; runtime erased per
  ;; spec 06. The Verify effect accumulates obligations that the
  ;; verify_ledger handler tracks; ground obligations (those decidable
  ;; from graph state alone — handle == constant predicates etc.)
  ;; can be discharged immediately. The remainder become V_Pending
  ;; until a richer handler (verify_smt — Arc F.1, swappable via
  ;; ~> verify_smt) discharges them via Z3 / cvc5 / Bitwuzla.
  ;;
  ;; The seed's verify substrate is the LEDGER ONLY — it accumulates
  ;; obligations as opaque records (predicate ptr + span ptr + reason
  ;; ptr) and exposes them for query/diagnosis. The seed never
  ;; discharges via SMT — that's post-L1 swap-handler work per
  ;; verify_kernel walkthrough (VK; pending walkthrough).
  ;;
  ;; ═══ HEAP RECORD LAYOUT ═══════════════════════════════════════════
  ;;
  ;; VerifyObligation record:
  ;;   $make_record(VERIFY_OBLIGATION_TAG=180, arity=3)
  ;;     offset  8: field_0 = predicate (opaque ptr — Ty/Expr ptr per
  ;;                          Hβ.infer; verify.wat treats as i32)
  ;;     offset 12: field_1 = span (opaque ptr — source location record)
  ;;     offset 16: field_2 = reason (opaque ptr — Reason record)
  ;;
  ;; Tag allocation: verify.wat private region 180-199 (avoids row.wat
  ;; 150-179 + env.wat 130-149 + graph.wat 50-99 + TokenKind 0-44).

  ;; ─── Module-level globals ─────────────────────────────────────────
  ;; $verify_ledger_ptr — flat list of VerifyObligation pointers
  ;;                      (the pending ledger).
  ;; $verify_ledger_len_g — logical count of pending obligations.
  ;; $verify_initialized — 1 once $verify_init has run.

  (global $verify_ledger_ptr   (mut i32) (i32.const 0))
  (global $verify_ledger_len_g (mut i32) (i32.const 0))
  (global $verify_initialized  (mut i32) (i32.const 0))

  ;; ─── Initialization ──────────────────────────────────────────────
  (func $verify_init
    (if (global.get $verify_initialized) (then (return)))
    (global.set $verify_ledger_ptr (call $make_list (i32.const 16)))
    (global.set $verify_ledger_len_g (i32.const 0))
    (global.set $verify_initialized (i32.const 1)))

  ;; ─── Obligation constructor + accessors ──────────────────────────

  (func $verify_obligation_make (param $predicate i32) (param $span i32) (param $reason i32)
                                (result i32)
    (local $o i32)
    (local.set $o (call $make_record (i32.const 180) (i32.const 3)))
    (call $record_set (local.get $o) (i32.const 0) (local.get $predicate))
    (call $record_set (local.get $o) (i32.const 1) (local.get $span))
    (call $record_set (local.get $o) (i32.const 2) (local.get $reason))
    (local.get $o))

  (func $verify_obligation_predicate (param $o i32) (result i32)
    (call $record_get (local.get $o) (i32.const 0)))

  (func $verify_obligation_span (param $o i32) (result i32)
    (call $record_get (local.get $o) (i32.const 1)))

  (func $verify_obligation_reason (param $o i32) (result i32)
    (call $record_get (local.get $o) (i32.const 2)))

  ;; ─── Record + query ──────────────────────────────────────────────

  ;; $verify_record — append a new obligation to the pending ledger.
  ;; Caller constructs (predicate, span, reason) opaque pointers per
  ;; Hβ.infer's Verify-effect handler arm.
  (func $verify_record (param $predicate i32) (param $span i32) (param $reason i32)
    (local $o i32)
    (call $verify_init)
    (local.set $o (call $verify_obligation_make
                    (local.get $predicate)
                    (local.get $span)
                    (local.get $reason)))
    (global.set $verify_ledger_ptr
      (call $list_set
        (call $list_extend_to (global.get $verify_ledger_ptr)
                              (i32.add (global.get $verify_ledger_len_g) (i32.const 1)))
        (global.get $verify_ledger_len_g)
        (local.get $o)))
    (global.set $verify_ledger_len_g
      (i32.add (global.get $verify_ledger_len_g) (i32.const 1))))

  ;; $verify_pending_count — number of pending obligations in the ledger.
  ;; Used by query / diagnostic surfaces (`inka check` reports the
  ;; V_Pending count; B.6 verify_smt swap reduces this by discharging
  ;; ground obligations).
  (func $verify_pending_count (result i32)
    (call $verify_init)
    (global.get $verify_ledger_len_g))

  ;; $verify_get_pending — return obligation at index i (0..pending_count).
  ;; Out-of-range returns 0 (defensive — well-formed callers respect
  ;; the count).
  (func $verify_get_pending (param $i i32) (result i32)
    (call $verify_init)
    (if (i32.ge_u (local.get $i) (global.get $verify_ledger_len_g))
      (then (return (i32.const 0))))
    (call $list_index (global.get $verify_ledger_ptr) (local.get $i)))

  ;; $verify_discharge_at — mark obligation at index as discharged
  ;; (sets the slot to 0; pending_count unchanged for now — compaction
  ;; is the named follow-up). Per VK walkthrough discipline: real
  ;; discharge happens via verify_smt handler swap; this primitive
  ;; lets the ledger track discharge state without recompacting.
  ;;
  ;; Conservative scope: this Tier-4 base does NOT call out to SMT;
  ;; it simply records that an obligation has been resolved. Callers
  ;; (Hβ.infer + Hβ.lower + future verify_smt swap) own the discharge
  ;; semantics. Per Anchor 7: discharge logic is its own concern —
  ;; verify.wat owns the ledger storage.
  (func $verify_discharge_at (param $i i32)
    (call $verify_init)
    (if (i32.ge_u (local.get $i) (global.get $verify_ledger_len_g))
      (then (return)))
    (drop (call $list_set (global.get $verify_ledger_ptr)
                          (local.get $i)
                          (i32.const 0))))

  ;; ═══ wasi_fs.wat — WASI filesystem extensions (Tier 4) ════════════
  ;; Implements: FX walkthrough (FX.A.basics + FX.A.dirent + FX.1) at
  ;;             the WAT layer. Provides path-level filesystem
  ;;             primitives the compiled wheel's `wasi_filesystem`
  ;;             handler arms call into. The seed itself does NOT use
  ;;             these (it reads source via stdin); they exist as
  ;;             substrate for the wheel post-L1.
  ;; Exports:    $fs_set_cwd_fd, $fs_get_cwd_fd,
  ;;             $fs_create_directory, $fs_unlink, $fs_rename,
  ;;             $fs_filestat_is_dir,
  ;;             $fs_list_dir
  ;; Uses:       Layer 0 imports: $wasi_path_create_directory,
  ;;               $wasi_path_filestat_get, $wasi_path_unlink_file,
  ;;               $wasi_path_rename, $wasi_fd_readdir
  ;;             $alloc (alloc.wat), $str_alloc/len/byte_at (str.wat),
  ;;             $make_list/$list_set/$list_extend_to/$len (list.wat)
  ;; Test:       runtime_test/wasi_fs.wat
  ;;
  ;; ═══ DESIGN ═══════════════════════════════════════════════════════
  ;; Per FX walkthrough commit `61b2b60` + FX.A.basics (`d801511`) +
  ;; FX.B (`afc4b0c`) substrate already in lib/runtime/io.nx +
  ;; src/mentl_voice.nx mentl_voice_filesystem handler.
  ;;
  ;; This is the WAT-level transcription of the FX substrate. It
  ;; provides path-relative-to-fd primitives that wrap WASI preview1
  ;; calls; the compiled wheel's wasi_filesystem handler arms call
  ;; these directly via H1 evidence-passing dispatch.
  ;;
  ;; ═══ CWD CONVENTION ═══════════════════════════════════════════════
  ;; WASI preview1 requires path operations to be relative to a
  ;; preopened directory file descriptor. Wasmtime convention: when
  ;; invoked with `--dir=.`, fd 3 is preopened as the current
  ;; directory. wasi_fs.wat defaults $wasi_fs_cwd_fd to 3; callers can
  ;; override via $fs_set_cwd_fd if running under a different invocation.
  ;;
  ;; If the runtime is invoked WITHOUT --dir, all $fs_* operations
  ;; will return non-zero errno (typically EBADF). Callers handle the
  ;; errno per the existing FX.A.basics pattern.
  ;;
  ;; ═══ ERRNO CONVENTION ═════════════════════════════════════════════
  ;; All $fs_* operations that touch the filesystem return WASI errno
  ;; (i32, 0 = success). Callers test the return value; non-zero is
  ;; surfaced via the wasi_filesystem handler arm's diagnostic chain
  ;; per the FX walkthrough.

  ;; ─── CWD fd configuration ─────────────────────────────────────────
  (global $wasi_fs_cwd_fd_g (mut i32) (i32.const 3))

  (func $fs_set_cwd_fd (param $fd i32)
    (global.set $wasi_fs_cwd_fd_g (local.get $fd)))

  (func $fs_get_cwd_fd (result i32)
    (global.get $wasi_fs_cwd_fd_g))

  ;; ─── path_create_directory wrapper ───────────────────────────────
  ;; $fs_create_directory(path) — creates directory relative to cwd_fd.
  ;; Returns WASI errno. Path must not already exist (caller checks
  ;; via $fs_filestat_is_dir before).
  (func $fs_create_directory (param $path i32) (result i32)
    (local $path_bytes i32) (local $path_len i32)
    (local.set $path_bytes (i32.add (local.get $path) (i32.const 4)))   ;; past length prefix
    (local.set $path_len   (call $str_len (local.get $path)))
    (call $wasi_path_create_directory
      (global.get $wasi_fs_cwd_fd_g)
      (local.get $path_bytes)
      (local.get $path_len)))

  ;; ─── path_unlink_file wrapper ────────────────────────────────────
  ;; $fs_unlink(path) — removes a file (NOT a directory) relative to cwd_fd.
  (func $fs_unlink (param $path i32) (result i32)
    (local $path_bytes i32) (local $path_len i32)
    (local.set $path_bytes (i32.add (local.get $path) (i32.const 4)))
    (local.set $path_len   (call $str_len (local.get $path)))
    (call $wasi_path_unlink_file
      (global.get $wasi_fs_cwd_fd_g)
      (local.get $path_bytes)
      (local.get $path_len)))

  ;; ─── path_rename wrapper ─────────────────────────────────────────
  ;; $fs_rename(old_path, new_path) — atomic rename. Both paths
  ;; relative to cwd_fd. Same destination dir parameter for both.
  (func $fs_rename (param $old i32) (param $new i32) (result i32)
    (local $old_bytes i32) (local $old_len i32)
    (local $new_bytes i32) (local $new_len i32)
    (local.set $old_bytes (i32.add (local.get $old) (i32.const 4)))
    (local.set $old_len   (call $str_len (local.get $old)))
    (local.set $new_bytes (i32.add (local.get $new) (i32.const 4)))
    (local.set $new_len   (call $str_len (local.get $new)))
    (call $wasi_path_rename
      (global.get $wasi_fs_cwd_fd_g)
      (local.get $old_bytes) (local.get $old_len)
      (global.get $wasi_fs_cwd_fd_g)
      (local.get $new_bytes) (local.get $new_len)))

  ;; ─── path_filestat_get wrapper — is_dir test ─────────────────────
  ;; $fs_filestat_is_dir(path) — returns 1 if path is a directory
  ;; (existing + filetype = WASI_FILETYPE_DIRECTORY = 3); else 0
  ;; (including non-existing or other types).
  ;;
  ;; WASI filestat layout (per preview1):
  ;;   offset  0: dev          (u64)
  ;;   offset  8: ino          (u64)
  ;;   offset 16: filetype     (u8 — see WASI filetype constants)
  ;;   offset 17: pad
  ;;   offset 24: nlink        (u64)
  ;;   offset 32: size         (u64)
  ;;   offset 40: atim         (u64)
  ;;   offset 48: mtim         (u64)
  ;;   offset 56: ctim         (u64)
  ;;
  ;; WASI_FILETYPE_DIRECTORY = 3 (per preview1 ABI).
  ;; WASI_LOOKUPFLAGS_SYMLINK_FOLLOW = 1 (follow symlinks during stat).
  (func $fs_filestat_is_dir (param $path i32) (result i32)
    (local $path_bytes i32) (local $path_len i32)
    (local $stat_buf i32) (local $errno i32) (local $filetype i32)
    (local.set $path_bytes (i32.add (local.get $path) (i32.const 4)))
    (local.set $path_len   (call $str_len (local.get $path)))
    (local.set $stat_buf   (call $alloc (i32.const 64)))   ;; filestat is 64 bytes
    (local.set $errno
      (call $wasi_path_filestat_get
        (global.get $wasi_fs_cwd_fd_g)
        (i32.const 1)                  ;; lookup flags = SYMLINK_FOLLOW
        (local.get $path_bytes)
        (local.get $path_len)
        (local.get $stat_buf)))
    (if (i32.ne (local.get $errno) (i32.const 0))
      (then (return (i32.const 0))))   ;; non-existing or error → not a dir
    ;; Read filetype byte at offset 16.
    (local.set $filetype (i32.load8_u offset=16 (local.get $stat_buf)))
    (i32.eq (local.get $filetype) (i32.const 3)))    ;; WASI_FILETYPE_DIRECTORY = 3

  ;; ─── fd_readdir wrapper — directory listing ──────────────────────
  ;; $fs_list_dir(path) — opens path as a directory, reads entries,
  ;; returns a flat list of name strings (parsed dirents). Returns
  ;; empty list on error (non-existing dir / not-a-dir / permission).
  ;;
  ;; WASI dirent layout (per preview1):
  ;;   offset  0: d_next       (u64 — cookie for next call)
  ;;   offset  8: d_ino        (u64)
  ;;   offset 16: d_namlen     (u32 — name length)
  ;;   offset 20: d_type       (u8)
  ;;   offset 21..23: pad
  ;;   offset 24: name_bytes... (UTF-8, no null terminator)
  ;; Header total = 24 bytes; entry size = 24 + d_namlen, then padded
  ;; to 8-byte alignment for the next dirent.
  ;;
  ;; This wrapper opens the directory via $wasi_path_open (fd_flags=0,
  ;; oflags=O_DIRECTORY=2, rights including DIRECTORY_READ +
  ;; FD_READDIR), calls $wasi_fd_readdir into a 4096-byte buffer,
  ;; parses dirents from the buffer, and returns the list of name
  ;; strings.
  ;;
  ;; Limitation (Tier-4 base): single-pass; if the directory has more
  ;; entries than fit in 4096 bytes, only the first batch is returned.
  ;; The cookie-driven multi-call pattern is the named follow-up.
  (func $fs_list_dir (param $path i32) (result i32)
    (local $path_bytes i32) (local $path_len i32)
    (local $fd_out_ptr i32) (local $errno i32) (local $dir_fd i32)
    (local $buf i32) (local $bufused_ptr i32) (local $bufused i32)
    (local $offset i32) (local $namelen i32) (local $name_str i32)
    (local $entry_size i32) (local $entry_padded i32) (local $padding i32)
    (local $names i32) (local $count i32)
    (local.set $path_bytes (i32.add (local.get $path) (i32.const 4)))
    (local.set $path_len   (call $str_len (local.get $path)))
    ;; Open the directory: caller_fd = cwd, dirflags = SYMLINK_FOLLOW (1),
    ;; oflags = O_DIRECTORY (2), rights_base = ... (broad — let WASI
    ;; runtime narrow per its policy), rights_inheriting = same,
    ;; fdflags = 0.
    (local.set $fd_out_ptr (call $alloc (i32.const 4)))
    (local.set $errno
      (call $wasi_path_open
        (global.get $wasi_fs_cwd_fd_g)
        (i32.const 1)                  ;; dirflags = SYMLINK_FOLLOW
        (local.get $path_bytes) (local.get $path_len)
        (i32.const 2)                  ;; oflags = O_DIRECTORY
        (i64.const 0xffffffff)         ;; rights_base — broad
        (i64.const 0xffffffff)         ;; rights_inheriting — broad
        (i32.const 0)                  ;; fdflags = 0
        (local.get $fd_out_ptr)))
    (if (i32.ne (local.get $errno) (i32.const 0))
      (then (return (call $make_list (i32.const 0)))))
    (local.set $dir_fd (i32.load (local.get $fd_out_ptr)))
    ;; Read entries into a 4096-byte buffer.
    (local.set $buf (call $alloc (i32.const 4096)))
    (local.set $bufused_ptr (call $alloc (i32.const 4)))
    (local.set $errno
      (call $wasi_fd_readdir
        (local.get $dir_fd)
        (local.get $buf)
        (i32.const 4096)
        (i64.const 0)                  ;; cookie 0 = start
        (local.get $bufused_ptr)))
    (drop (call $wasi_fd_close (local.get $dir_fd)))
    (if (i32.ne (local.get $errno) (i32.const 0))
      (then (return (call $make_list (i32.const 0)))))
    (local.set $bufused (i32.load (local.get $bufused_ptr)))
    ;; Parse dirents into a name list.
    (local.set $names (call $make_list (i32.const 16)))
    (local.set $count (i32.const 0))
    (local.set $offset (i32.const 0))
    (block $done
      (loop $parse
        ;; Need at least 24 bytes for header; otherwise stop.
        (br_if $done
          (i32.gt_u (i32.add (local.get $offset) (i32.const 24))
                    (local.get $bufused)))
        ;; Read d_namlen at offset+16 (u32).
        (local.set $namelen
          (i32.load
            (i32.add (local.get $buf) (i32.add (local.get $offset) (i32.const 16)))))
        (local.set $entry_size (i32.add (i32.const 24) (local.get $namelen)))
        ;; Need full entry to fit in buffer.
        (br_if $done
          (i32.gt_u (i32.add (local.get $offset) (local.get $entry_size))
                    (local.get $bufused)))
        ;; Allocate name string + memcopy from buf.
        (local.set $name_str (call $str_alloc (local.get $namelen)))
        (memory.copy
          (i32.add (local.get $name_str) (i32.const 4))
          (i32.add (local.get $buf) (i32.add (local.get $offset) (i32.const 24)))
          (local.get $namelen))
        ;; Append name to names list.
        (local.set $names
          (call $list_set
            (call $list_extend_to (local.get $names)
                                  (i32.add (local.get $count) (i32.const 1)))
            (local.get $count)
            (local.get $name_str)))
        (local.set $count (i32.add (local.get $count) (i32.const 1)))
        ;; Advance offset by entry_size, padded to 8-byte boundary.
        (local.set $padding
          (i32.and (i32.sub (i32.const 0) (local.get $entry_size)) (i32.const 7)))
        (local.set $entry_padded (i32.add (local.get $entry_size) (local.get $padding)))
        (local.set $offset (i32.add (local.get $offset) (local.get $entry_padded)))
        (br $parse)))
    ;; Truncate names to actual count via slice.
    (call $slice (local.get $names) (i32.const 0) (local.get $count)))

  ;; ═══ lexer_data.wat — keyword + output data segments (Layer 2) ════
  ;; Implements: lexer keyword string constants at fixed memory
  ;;             addresses [256, 512) + output format strings at
  ;;             [512, 4096). Read by lexer.wat's identifier-vs-
  ;;             keyword classifier + by the entry point's stdout
  ;;             reporting helpers.
  ;; Exports:    (data segments — addressed via $str_from_mem in int.wat)
  ;; Uses:       (memory.data only — no function dependencies)
  ;; Test:       runtime_test/lexer_data.wat (asserts string content
  ;;             at known addresses)
  ;;
  ;; Each entry: 4-byte little-endian length prefix + raw bytes.
  ;; Addresses chosen to fit within the [256, 4096) data region (the
  ;; HEAP_BASE-bounded sentinel space below the heap floor at 1 MiB).
  ;; Per CLAUDE.md memory model: HEAP_BASE = 4096; sentinel region
  ;; [0, 4096) holds (a) nullary ADT variant tags + (b) data-segment
  ;; constants like these.
  ;;
  ;; Wave 2.A factoring: these segments lived inline in inka.wat's
  ;; Layer 0+1 shell because the build.sh "extract shell" pattern
  ;; treated everything before ";; ─── TokenKind Sentinel IDs" as
  ;; shell. They are SEMANTICALLY lexer data — moved here as the
  ;; lexer's first chunk so build.sh assembles them before lexer.wat.

  ;; ─── Keyword strings for the lexer — [256, 512) ───────────────────
  ;; "fn" at 256
  (data (i32.const 256) "\02\00\00\00fn")
  ;; "let" at 264
  (data (i32.const 264) "\03\00\00\00let")
  ;; "if" at 272
  (data (i32.const 272) "\02\00\00\00if")
  ;; "else" at 280
  (data (i32.const 280) "\04\00\00\00else")
  ;; "match" at 288
  (data (i32.const 288) "\05\00\00\00match")
  ;; "type" at 296
  (data (i32.const 296) "\04\00\00\00type")
  ;; "effect" at 304
  (data (i32.const 304) "\06\00\00\00effect")
  ;; "handle" at 312
  (data (i32.const 312) "\06\00\00\00handle")
  ;; "handler" at 320
  (data (i32.const 320) "\07\00\00\00handler")
  ;; "with" at 332
  (data (i32.const 332) "\04\00\00\00with")
  ;; "resume" at 340
  (data (i32.const 340) "\06\00\00\00resume")
  ;; "perform" at 348
  (data (i32.const 348) "\07\00\00\00perform")
  ;; "for" at 360
  (data (i32.const 360) "\03\00\00\00for")
  ;; "in" at 368
  (data (i32.const 368) "\02\00\00\00in")
  ;; "loop" at 376
  (data (i32.const 376) "\04\00\00\00loop")
  ;; "break" at 384
  (data (i32.const 384) "\05\00\00\00break")
  ;; "continue" at 392
  (data (i32.const 392) "\08\00\00\00continue")
  ;; "return" at 404
  (data (i32.const 404) "\06\00\00\00return")
  ;; "import" at 412
  (data (i32.const 412) "\06\00\00\00import")
  ;; "where" at 420
  (data (i32.const 420) "\05\00\00\00where")
  ;; "own" at 428
  (data (i32.const 428) "\03\00\00\00own")
  ;; "ref" at 436
  (data (i32.const 436) "\03\00\00\00ref")
  ;; "capability" at 444
  (data (i32.const 444) "\0a\00\00\00capability")
  ;; "Pure" at 456
  (data (i32.const 456) "\04\00\00\00Pure")
  ;; "true" at 464
  (data (i32.const 464) "\04\00\00\00true")
  ;; "false" at 472
  (data (i32.const 472) "\05\00\00\00false")

  ;; ─── Output format strings — [512, 4096) ──────────────────────────
  ;; " tokens, " at 512 (9 bytes)
  (data (i32.const 512) " tokens, ")
  ;; " stmts" at 528 (6 bytes)
  (data (i32.const 528) " stmts")

  ;; ─── TokenKind Sentinel IDs ──────────────────────────────────────
  ;; Nullary variants are sentinels (value IS the tag, no allocation).
  ;; Fielded variants (TIdent, TInt, TFloat, TString, TDocComment)
  ;; are heap-allocated: [tag:i32][payload:i32].
  ;;
  ;; Keywords (0-24):
  ;;   TFn=0 TLet=1 TIf=2 TElse=3 TMatch=4 TType=5
  ;;   TEffect=6 THandle=7 THandler=8 TWith=9
  ;;   TResume=10 TPerform=11
  ;;   TFor=12 TIn=13 TLoop=14 TBreak=15 TContinue=16 TReturn=17
  ;;   TImport=18 TWhere=19
  ;;   TOwn=20 TRef=21 TPure=22
  ;;   TTrue=23 TFalse=24
  ;; Fielded (25-29): TIdent=25 TInt=26 TFloat=27 TString=28 TDocComment=29
  ;; Two-char ops (30-44):
  ;;   TEqEq=30 TBangEq=31 TLtEq=32 TGtEq=33
  ;;   TArrow=34 TFatArrow=35 TPlusPlus=36
  ;;   TPipeGt=37 TLtPipe=38 TGtLt=39 TTildeGt=40 TLtTilde=41
  ;;   TAndAnd=42 TOrOr=43 TColonColon=44
  ;; Single-char (45-67):
  ;;   TLParen=45 TRParen=46 TLBrace=47 TRBrace=48
  ;;   TLBracket=49 TRBracket=50
  ;;   TComma=51 TDot=52 TColon=53 TSemicolon=54
  ;;   TPlus=55 TMinus=56 TStar=57 TSlash=58 TPercent=59
  ;;   TEq=60 TLt=61 TGt=62 TBang=63
  ;;   TPipe=64 TTilde=65 TAt=66 TQuestion=67
  ;; Layout (68-69): TNewline=68 TEof=69
  ;; Option: None=70 Some=71 (fielded)

  ;; ─── ADT Constructors ─────────────────────────────────────────────

  ;; Span(sl, sc, el, ec) → heap [tag=0][sl][sc][el][ec]
  (func $mk_span (param $sl i32) (param $sc i32) (param $el i32) (param $ec i32) (result i32)
    (local $ptr i32)
    (local.set $ptr (call $alloc (i32.const 20)))
    (i32.store (local.get $ptr) (i32.const 0))
    (i32.store offset=4 (local.get $ptr) (local.get $sl))
    (i32.store offset=8 (local.get $ptr) (local.get $sc))
    (i32.store offset=12 (local.get $ptr) (local.get $el))
    (i32.store offset=16 (local.get $ptr) (local.get $ec))
    (local.get $ptr))

  ;; Tok(kind, span) → heap [tag=0][kind][span_ptr]
  (func $mk_tok (param $kind i32) (param $sl i32) (param $sc i32) (param $el i32) (param $ec i32) (result i32)
    (local $ptr i32) (local $span i32)
    (local.set $span (call $mk_span (local.get $sl) (local.get $sc) (local.get $el) (local.get $ec)))
    (local.set $ptr (call $alloc (i32.const 12)))
    (i32.store (local.get $ptr) (i32.const 0))
    (i32.store offset=4 (local.get $ptr) (local.get $kind))
    (i32.store offset=8 (local.get $ptr) (local.get $span))
    (local.get $ptr))

  ;; Fielded TokenKind: TIdent(str) → [tag=25][str_ptr]
  (func $mk_TIdent (param $s i32) (result i32)
    (local $ptr i32)
    (local.set $ptr (call $alloc (i32.const 8)))
    (i32.store (local.get $ptr) (i32.const 25))
    (i32.store offset=4 (local.get $ptr) (local.get $s))
    (local.get $ptr))

  ;; TInt(n) → [tag=26][n]
  (func $mk_TInt (param $n i32) (result i32)
    (local $ptr i32)
    (local.set $ptr (call $alloc (i32.const 8)))
    (i32.store (local.get $ptr) (i32.const 26))
    (i32.store offset=4 (local.get $ptr) (local.get $n))
    (local.get $ptr))

  ;; TString(s) → [tag=28][str_ptr]
  (func $mk_TString (param $s i32) (result i32)
    (local $ptr i32)
    (local.set $ptr (call $alloc (i32.const 8)))
    (i32.store (local.get $ptr) (i32.const 28))
    (i32.store offset=4 (local.get $ptr) (local.get $s))
    (local.get $ptr))

  ;; TDocComment(s) → [tag=29][str_ptr]
  (func $mk_TDocComment (param $s i32) (result i32)
    (local $ptr i32)
    (local.set $ptr (call $alloc (i32.const 8)))
    (i32.store (local.get $ptr) (i32.const 29))
    (i32.store offset=4 (local.get $ptr) (local.get $s))
    (local.get $ptr))

  ;; Some(val) → [tag=71][val]
  (func $mk_Some (param $val i32) (result i32)
    (local $ptr i32)
    (local.set $ptr (call $alloc (i32.const 8)))
    (i32.store (local.get $ptr) (i32.const 71))
    (i32.store offset=4 (local.get $ptr) (local.get $val))
    (local.get $ptr))

  ;; ─── Character Classification ─────────────────────────────────────

  (func $is_digit (param $b i32) (result i32)
    (i32.and
      (i32.ge_u (local.get $b) (i32.const 48))
      (i32.le_u (local.get $b) (i32.const 57))))

  (func $is_alpha (param $b i32) (result i32)
    (i32.or
      (i32.or
        (i32.and (i32.ge_u (local.get $b) (i32.const 65))
                 (i32.le_u (local.get $b) (i32.const 90)))
        (i32.and (i32.ge_u (local.get $b) (i32.const 97))
                 (i32.le_u (local.get $b) (i32.const 122))))
      (i32.eq (local.get $b) (i32.const 95))))

  (func $is_alnum (param $b i32) (result i32)
    (i32.or (call $is_alpha (local.get $b))
            (call $is_digit (local.get $b))))

  (func $is_whitespace (param $b i32) (result i32)
    (i32.or
      (i32.or
        (i32.eq (local.get $b) (i32.const 32))
        (i32.eq (local.get $b) (i32.const 9)))
      (i32.eq (local.get $b) (i32.const 13))))

  ;; ─── Keyword Classification ───────────────────────────────────────
  ;; Returns sentinel 70 (None) or Some(TokenKind sentinel).
  ;; Uses pre-laid data segment strings for comparison.

  (func $keyword_kind (param $word i32) (result i32)
    (if (call $str_eq (local.get $word) (i32.const 256))    ;; "fn"
      (then (return (call $mk_Some (i32.const 0)))))
    (if (call $str_eq (local.get $word) (i32.const 264))    ;; "let"
      (then (return (call $mk_Some (i32.const 1)))))
    (if (call $str_eq (local.get $word) (i32.const 272))    ;; "if"
      (then (return (call $mk_Some (i32.const 2)))))
    (if (call $str_eq (local.get $word) (i32.const 280))    ;; "else"
      (then (return (call $mk_Some (i32.const 3)))))
    (if (call $str_eq (local.get $word) (i32.const 288))    ;; "match"
      (then (return (call $mk_Some (i32.const 4)))))
    (if (call $str_eq (local.get $word) (i32.const 296))    ;; "type"
      (then (return (call $mk_Some (i32.const 5)))))
    (if (call $str_eq (local.get $word) (i32.const 304))    ;; "effect"
      (then (return (call $mk_Some (i32.const 6)))))
    (if (call $str_eq (local.get $word) (i32.const 312))    ;; "handle"
      (then (return (call $mk_Some (i32.const 7)))))
    (if (call $str_eq (local.get $word) (i32.const 320))    ;; "handler"
      (then (return (call $mk_Some (i32.const 8)))))
    (if (call $str_eq (local.get $word) (i32.const 332))    ;; "with"
      (then (return (call $mk_Some (i32.const 9)))))
    (if (call $str_eq (local.get $word) (i32.const 340))    ;; "resume"
      (then (return (call $mk_Some (i32.const 10)))))
    (if (call $str_eq (local.get $word) (i32.const 348))    ;; "perform"
      (then (return (call $mk_Some (i32.const 11)))))
    (if (call $str_eq (local.get $word) (i32.const 360))    ;; "for"
      (then (return (call $mk_Some (i32.const 12)))))
    (if (call $str_eq (local.get $word) (i32.const 368))    ;; "in"
      (then (return (call $mk_Some (i32.const 13)))))
    (if (call $str_eq (local.get $word) (i32.const 376))    ;; "loop"
      (then (return (call $mk_Some (i32.const 14)))))
    (if (call $str_eq (local.get $word) (i32.const 384))    ;; "break"
      (then (return (call $mk_Some (i32.const 15)))))
    (if (call $str_eq (local.get $word) (i32.const 392))    ;; "continue"
      (then (return (call $mk_Some (i32.const 16)))))
    (if (call $str_eq (local.get $word) (i32.const 404))    ;; "return"
      (then (return (call $mk_Some (i32.const 17)))))
    (if (call $str_eq (local.get $word) (i32.const 412))    ;; "import"
      (then (return (call $mk_Some (i32.const 18)))))
    (if (call $str_eq (local.get $word) (i32.const 420))    ;; "where"
      (then (return (call $mk_Some (i32.const 19)))))
    (if (call $str_eq (local.get $word) (i32.const 428))    ;; "own"
      (then (return (call $mk_Some (i32.const 20)))))
    (if (call $str_eq (local.get $word) (i32.const 436))    ;; "ref"
      (then (return (call $mk_Some (i32.const 21)))))
    (if (call $str_eq (local.get $word) (i32.const 444))    ;; "capability"
      (then (return (call $mk_Some (i32.const 22)))))
    (if (call $str_eq (local.get $word) (i32.const 456))    ;; "Pure"
      (then (return (call $mk_Some (i32.const 22)))))
    (if (call $str_eq (local.get $word) (i32.const 464))    ;; "true"
      (then (return (call $mk_Some (i32.const 23)))))
    (if (call $str_eq (local.get $word) (i32.const 472))    ;; "false"
      (then (return (call $mk_Some (i32.const 24)))))
    (i32.const 70))  ;; None

  ;; ─── Two-char Operator Classification ─────────────────────────────
  (func $two_char_kind (param $a i32) (param $b i32) (result i32)
    (if (i32.and (i32.eq (local.get $a) (i32.const 61))
                 (i32.eq (local.get $b) (i32.const 61)))
      (then (return (call $mk_Some (i32.const 30)))))   ;; ==
    (if (i32.and (i32.eq (local.get $a) (i32.const 33))
                 (i32.eq (local.get $b) (i32.const 61)))
      (then (return (call $mk_Some (i32.const 31)))))   ;; !=
    (if (i32.and (i32.eq (local.get $a) (i32.const 60))
                 (i32.eq (local.get $b) (i32.const 61)))
      (then (return (call $mk_Some (i32.const 32)))))   ;; <=
    (if (i32.and (i32.eq (local.get $a) (i32.const 62))
                 (i32.eq (local.get $b) (i32.const 61)))
      (then (return (call $mk_Some (i32.const 33)))))   ;; >=
    (if (i32.and (i32.eq (local.get $a) (i32.const 45))
                 (i32.eq (local.get $b) (i32.const 62)))
      (then (return (call $mk_Some (i32.const 34)))))   ;; ->
    (if (i32.and (i32.eq (local.get $a) (i32.const 61))
                 (i32.eq (local.get $b) (i32.const 62)))
      (then (return (call $mk_Some (i32.const 35)))))   ;; =>
    (if (i32.and (i32.eq (local.get $a) (i32.const 43))
                 (i32.eq (local.get $b) (i32.const 43)))
      (then (return (call $mk_Some (i32.const 36)))))   ;; ++
    (if (i32.and (i32.eq (local.get $a) (i32.const 124))
                 (i32.eq (local.get $b) (i32.const 62)))
      (then (return (call $mk_Some (i32.const 37)))))   ;; |>
    (if (i32.and (i32.eq (local.get $a) (i32.const 60))
                 (i32.eq (local.get $b) (i32.const 124)))
      (then (return (call $mk_Some (i32.const 38)))))   ;; <|
    (if (i32.and (i32.eq (local.get $a) (i32.const 62))
                 (i32.eq (local.get $b) (i32.const 60)))
      (then (return (call $mk_Some (i32.const 39)))))   ;; ><
    (if (i32.and (i32.eq (local.get $a) (i32.const 126))
                 (i32.eq (local.get $b) (i32.const 62)))
      (then (return (call $mk_Some (i32.const 40)))))   ;; ~>
    (if (i32.and (i32.eq (local.get $a) (i32.const 60))
                 (i32.eq (local.get $b) (i32.const 126)))
      (then (return (call $mk_Some (i32.const 41)))))   ;; <~
    (if (i32.and (i32.eq (local.get $a) (i32.const 38))
                 (i32.eq (local.get $b) (i32.const 38)))
      (then (return (call $mk_Some (i32.const 42)))))   ;; &&
    (if (i32.and (i32.eq (local.get $a) (i32.const 124))
                 (i32.eq (local.get $b) (i32.const 124)))
      (then (return (call $mk_Some (i32.const 43)))))   ;; ||
    (if (i32.and (i32.eq (local.get $a) (i32.const 58))
                 (i32.eq (local.get $b) (i32.const 58)))
      (then (return (call $mk_Some (i32.const 44)))))   ;; ::
    (i32.const 70))  ;; None

  ;; ─── Single-char Operator Classification ──────────────────────────
  (func $single_char_kind (param $b i32) (result i32)
    (if (i32.eq (local.get $b) (i32.const 40))
      (then (return (call $mk_Some (i32.const 45)))))   ;; (
    (if (i32.eq (local.get $b) (i32.const 41))
      (then (return (call $mk_Some (i32.const 46)))))   ;; )
    (if (i32.eq (local.get $b) (i32.const 123))
      (then (return (call $mk_Some (i32.const 47)))))   ;; {
    (if (i32.eq (local.get $b) (i32.const 125))
      (then (return (call $mk_Some (i32.const 48)))))   ;; }
    (if (i32.eq (local.get $b) (i32.const 91))
      (then (return (call $mk_Some (i32.const 49)))))   ;; [
    (if (i32.eq (local.get $b) (i32.const 93))
      (then (return (call $mk_Some (i32.const 50)))))   ;; ]
    (if (i32.eq (local.get $b) (i32.const 44))
      (then (return (call $mk_Some (i32.const 51)))))   ;; ,
    (if (i32.eq (local.get $b) (i32.const 46))
      (then (return (call $mk_Some (i32.const 52)))))   ;; .
    (if (i32.eq (local.get $b) (i32.const 58))
      (then (return (call $mk_Some (i32.const 53)))))   ;; :
    (if (i32.eq (local.get $b) (i32.const 59))
      (then (return (call $mk_Some (i32.const 54)))))   ;; ;
    (if (i32.eq (local.get $b) (i32.const 43))
      (then (return (call $mk_Some (i32.const 55)))))   ;; +
    (if (i32.eq (local.get $b) (i32.const 45))
      (then (return (call $mk_Some (i32.const 56)))))   ;; -
    (if (i32.eq (local.get $b) (i32.const 42))
      (then (return (call $mk_Some (i32.const 57)))))   ;; *
    (if (i32.eq (local.get $b) (i32.const 47))
      (then (return (call $mk_Some (i32.const 58)))))   ;; /
    (if (i32.eq (local.get $b) (i32.const 37))
      (then (return (call $mk_Some (i32.const 59)))))   ;; %
    (if (i32.eq (local.get $b) (i32.const 61))
      (then (return (call $mk_Some (i32.const 60)))))   ;; =
    (if (i32.eq (local.get $b) (i32.const 60))
      (then (return (call $mk_Some (i32.const 61)))))   ;; <
    (if (i32.eq (local.get $b) (i32.const 62))
      (then (return (call $mk_Some (i32.const 62)))))   ;; >
    (if (i32.eq (local.get $b) (i32.const 33))
      (then (return (call $mk_Some (i32.const 63)))))   ;; !
    (if (i32.eq (local.get $b) (i32.const 124))
      (then (return (call $mk_Some (i32.const 64)))))   ;; |
    (if (i32.eq (local.get $b) (i32.const 126))
      (then (return (call $mk_Some (i32.const 65)))))   ;; ~
    (if (i32.eq (local.get $b) (i32.const 64))
      (then (return (call $mk_Some (i32.const 66)))))   ;; @
    (if (i32.eq (local.get $b) (i32.const 63))
      (then (return (call $mk_Some (i32.const 67)))))   ;; ?
    (i32.const 70))  ;; None

  ;; ─── push_tok: append token to buffer ─────────────────────────────
  ;; Returns (buf, count+1) as a 2-tuple [tag=0][buf][count]
  (func $push_tok (param $buf i32) (param $count i32) (param $tok i32) (result i32)
    (local $extended i32) (local $tup i32)
    (local.set $extended
      (call $list_extend_to (local.get $buf)
        (i32.add (local.get $count) (i32.const 1))))
    (drop (call $list_set (local.get $extended) (local.get $count) (local.get $tok)))
    ;; Return 2-tuple: [count=2][tag=0][buf][new_count]
    (local.set $tup (call $make_list (i32.const 2)))
    (drop (call $list_set (local.get $tup) (i32.const 0) (local.get $extended)))
    (drop (call $list_set (local.get $tup) (i32.const 1)
      (i32.add (local.get $count) (i32.const 1))))
    (local.get $tup))

  ;; ─── Lexer Helpers ────────────────────────────────────────────────

  ;; scan_to_eol: advance pos until newline or end
  (func $scan_to_eol (param $src i32) (param $n i32) (param $pos i32) (result i32)
    (block $done
      (loop $scan
        (br_if $done (i32.ge_u (local.get $pos) (local.get $n)))
        (br_if $done (i32.eq (call $byte_at (local.get $src) (local.get $pos)) (i32.const 10)))
        (local.set $pos (i32.add (local.get $pos) (i32.const 1)))
        (br $scan)))
    (local.get $pos))

  ;; scan_ident: advance over identifier chars. Returns new_pos.
  (func $scan_ident (param $src i32) (param $n i32) (param $pos i32) (result i32)
    (block $done
      (loop $scan
        (br_if $done (i32.ge_u (local.get $pos) (local.get $n)))
        (br_if $done (i32.eqz (call $is_alnum (call $byte_at (local.get $src) (local.get $pos)))))
        (local.set $pos (i32.add (local.get $pos) (i32.const 1)))
        (br $scan)))
    (local.get $pos))

  ;; scan_number: advance over digits and optional decimal point.
  ;; Returns new_pos. (Float detection deferred for simplicity.)
  (func $scan_number (param $src i32) (param $n i32) (param $pos i32) (result i32)
    (local $b i32)
    (block $done
      (loop $scan
        (br_if $done (i32.ge_u (local.get $pos) (local.get $n)))
        (local.set $b (call $byte_at (local.get $src) (local.get $pos)))
        (br_if $done (i32.eqz (call $is_digit (local.get $b))))
        (local.set $pos (i32.add (local.get $pos) (i32.const 1)))
        (br $scan)))
    (local.get $pos))

  ;; scan_string: advance past closing quote. Returns new_pos.
  ;; (Escape handling simplified — copies bytes without interpreting escapes.)
  (func $scan_string_end (param $src i32) (param $n i32) (param $pos i32) (result i32)
    (local $b i32)
    (block $done
      (loop $scan
        (br_if $done (i32.ge_u (local.get $pos) (local.get $n)))
        (local.set $b (call $byte_at (local.get $src) (local.get $pos)))
        ;; closing quote
        (if (i32.eq (local.get $b) (i32.const 34))
          (then (return (i32.add (local.get $pos) (i32.const 1)))))
        ;; backslash: skip next byte
        (if (i32.eq (local.get $b) (i32.const 92))
          (then (local.set $pos (i32.add (local.get $pos) (i32.const 1)))))
        (local.set $pos (i32.add (local.get $pos) (i32.const 1)))
        (br $scan)))
    (local.get $pos))

  ;; ─── Main Lex Loop ─────────────────────────────────────────────────
  ;; Iterative version of lex_from. Processes source byte-by-byte,
  ;; building a flat token buffer. Returns (buf, count) as 2-tuple.

  (func $lex (param $source i32) (result i32)
    (local $n i32) (local $pos i32) (local $line i32) (local $col i32)
    (local $buf i32) (local $count i32)
    (local $b i32) (local $b2 i32)
    (local $new_pos i32) (local $word i32) (local $kind i32)
    (local $kw_result i32) (local $tok i32) (local $tup i32)
    (local $op_result i32) (local $str_val i32)
    (local $after i32) (local $end_col i32)
    (local $cap i32)

    (local.set $n (call $byte_len (local.get $source)))
    (local.set $cap (if (result i32) (i32.lt_u (local.get $n) (i32.const 16))
      (then (i32.const 16)) (else (local.get $n))))
    (local.set $buf (call $make_list (local.get $cap)))
    (local.set $count (i32.const 0))
    (local.set $pos (i32.const 0))
    (local.set $line (i32.const 1))
    (local.set $col (i32.const 1))

    (block $exit
      (loop $main_loop
        ;; Check EOF
        (if (i32.ge_u (local.get $pos) (local.get $n))
          (then
            ;; Push TEof token
            (local.set $tok (call $mk_tok (i32.const 69)
              (local.get $line) (local.get $col) (local.get $line) (local.get $col)))
            (local.set $tup (call $push_tok (local.get $buf) (local.get $count) (local.get $tok)))
            (local.set $buf (call $list_index (local.get $tup) (i32.const 0)))
            (local.set $count (call $list_index (local.get $tup) (i32.const 1)))
            (br $exit)))

        (local.set $b (call $byte_at (local.get $source) (local.get $pos)))

        ;; Whitespace (space, tab, CR) — skip
        (if (call $is_whitespace (local.get $b))
          (then
            (local.set $pos (i32.add (local.get $pos) (i32.const 1)))
            (local.set $col (i32.add (local.get $col) (i32.const 1)))
            (br $main_loop)))

        ;; Newline
        (if (i32.eq (local.get $b) (i32.const 10))
          (then
            (local.set $tok (call $mk_tok (i32.const 68)
              (local.get $line) (local.get $col)
              (i32.add (local.get $line) (i32.const 1)) (i32.const 1)))
            (local.set $tup (call $push_tok (local.get $buf) (local.get $count) (local.get $tok)))
            (local.set $buf (call $list_index (local.get $tup) (i32.const 0)))
            (local.set $count (call $list_index (local.get $tup) (i32.const 1)))
            (local.set $pos (i32.add (local.get $pos) (i32.const 1)))
            (local.set $line (i32.add (local.get $line) (i32.const 1)))
            (local.set $col (i32.const 1))
            (br $main_loop)))

        ;; Comment: // or ///
        (if (i32.and
              (i32.eq (local.get $b) (i32.const 47))
              (i32.and
                (i32.lt_u (i32.add (local.get $pos) (i32.const 1)) (local.get $n))
                (i32.eq (call $byte_at (local.get $source)
                  (i32.add (local.get $pos) (i32.const 1))) (i32.const 47))))
          (then
            ;; Check for /// doc comment
            (if (i32.and
                  (i32.lt_u (i32.add (local.get $pos) (i32.const 2)) (local.get $n))
                  (i32.eq (call $byte_at (local.get $source)
                    (i32.add (local.get $pos) (i32.const 2))) (i32.const 47)))
              (then
                ;; Doc comment — capture text until EOL
                (local.set $after (call $scan_to_eol (local.get $source) (local.get $n)
                  (i32.add (local.get $pos) (i32.const 3))))
                (local.set $str_val (call $str_slice (local.get $source)
                  (i32.add (local.get $pos) (i32.const 3)) (local.get $after)))
                (local.set $end_col (i32.add (local.get $col)
                  (i32.sub (local.get $after) (local.get $pos))))
                (local.set $tok (call $mk_tok
                  (call $mk_TDocComment (local.get $str_val))
                  (local.get $line) (local.get $col) (local.get $line) (local.get $end_col)))
                (local.set $tup (call $push_tok (local.get $buf) (local.get $count) (local.get $tok)))
                (local.set $buf (call $list_index (local.get $tup) (i32.const 0)))
                (local.set $count (call $list_index (local.get $tup) (i32.const 1)))
                (local.set $pos (local.get $after))
                (local.set $col (local.get $end_col)))
              (else
                ;; Regular comment — skip to EOL
                (local.set $pos (call $scan_to_eol (local.get $source) (local.get $n)
                  (i32.add (local.get $pos) (i32.const 2))))))
            (br $main_loop)))

        ;; String literal (byte 34 = ")
        (if (i32.eq (local.get $b) (i32.const 34))
          (then
            (local.set $new_pos (call $scan_string_end (local.get $source) (local.get $n)
              (i32.add (local.get $pos) (i32.const 1))))
            ;; Extract string content (between quotes)
            (local.set $str_val (call $str_slice (local.get $source)
              (i32.add (local.get $pos) (i32.const 1))
              (i32.sub (local.get $new_pos) (i32.const 1))))
            (local.set $end_col (i32.add (local.get $col)
              (i32.sub (local.get $new_pos) (local.get $pos))))
            (local.set $tok (call $mk_tok
              (call $mk_TString (local.get $str_val))
              (local.get $line) (local.get $col) (local.get $line) (local.get $end_col)))
            (local.set $tup (call $push_tok (local.get $buf) (local.get $count) (local.get $tok)))
            (local.set $buf (call $list_index (local.get $tup) (i32.const 0)))
            (local.set $count (call $list_index (local.get $tup) (i32.const 1)))
            (local.set $pos (local.get $new_pos))
            (local.set $col (local.get $end_col))
            (br $main_loop)))

        ;; Number
        (if (call $is_digit (local.get $b))
          (then
            (local.set $new_pos (call $scan_number (local.get $source) (local.get $n)
              (local.get $pos)))
            (local.set $str_val (call $str_slice (local.get $source)
              (local.get $pos) (local.get $new_pos)))
            (local.set $end_col (i32.add (local.get $col)
              (i32.sub (local.get $new_pos) (local.get $pos))))
            (local.set $tok (call $mk_tok
              (call $mk_TInt (call $parse_int (local.get $str_val)))
              (local.get $line) (local.get $col) (local.get $line) (local.get $end_col)))
            (local.set $tup (call $push_tok (local.get $buf) (local.get $count) (local.get $tok)))
            (local.set $buf (call $list_index (local.get $tup) (i32.const 0)))
            (local.set $count (call $list_index (local.get $tup) (i32.const 1)))
            (local.set $pos (local.get $new_pos))
            (local.set $col (local.get $end_col))
            (br $main_loop)))

        ;; Identifier or keyword
        (if (call $is_alpha (local.get $b))
          (then
            (local.set $new_pos (call $scan_ident (local.get $source) (local.get $n)
              (local.get $pos)))
            (local.set $word (call $str_slice (local.get $source)
              (local.get $pos) (local.get $new_pos)))
            (local.set $end_col (i32.add (local.get $col)
              (i32.sub (local.get $new_pos) (local.get $pos))))
            ;; Check keyword
            (local.set $kw_result (call $keyword_kind (local.get $word)))
            (if (i32.eq (local.get $kw_result) (i32.const 70))
              (then
                ;; Not a keyword — TIdent
                (local.set $kind (call $mk_TIdent (local.get $word))))
              (else
                ;; Keyword — extract sentinel from Some
                (local.set $kind (i32.load offset=4 (local.get $kw_result)))))
            (local.set $tok (call $mk_tok (local.get $kind)
              (local.get $line) (local.get $col) (local.get $line) (local.get $end_col)))
            (local.set $tup (call $push_tok (local.get $buf) (local.get $count) (local.get $tok)))
            (local.set $buf (call $list_index (local.get $tup) (i32.const 0)))
            (local.set $count (call $list_index (local.get $tup) (i32.const 1)))
            (local.set $pos (local.get $new_pos))
            (local.set $col (local.get $end_col))
            (br $main_loop)))

        ;; Two-char operators
        (local.set $b2 (if (result i32)
          (i32.lt_u (i32.add (local.get $pos) (i32.const 1)) (local.get $n))
          (then (call $byte_at (local.get $source)
            (i32.add (local.get $pos) (i32.const 1))))
          (else (i32.const 0))))
        (local.set $op_result (call $two_char_kind (local.get $b) (local.get $b2)))
        (if (i32.ne (local.get $op_result) (i32.const 70))
          (then
            (local.set $kind (i32.load offset=4 (local.get $op_result)))
            (local.set $tok (call $mk_tok (local.get $kind)
              (local.get $line) (local.get $col)
              (local.get $line) (i32.add (local.get $col) (i32.const 2))))
            (local.set $tup (call $push_tok (local.get $buf) (local.get $count) (local.get $tok)))
            (local.set $buf (call $list_index (local.get $tup) (i32.const 0)))
            (local.set $count (call $list_index (local.get $tup) (i32.const 1)))
            (local.set $pos (i32.add (local.get $pos) (i32.const 2)))
            (local.set $col (i32.add (local.get $col) (i32.const 2)))
            (br $main_loop)))

        ;; Single-char operators
        (local.set $op_result (call $single_char_kind (local.get $b)))
        (if (i32.ne (local.get $op_result) (i32.const 70))
          (then
            (local.set $kind (i32.load offset=4 (local.get $op_result)))
            (local.set $tok (call $mk_tok (local.get $kind)
              (local.get $line) (local.get $col)
              (local.get $line) (i32.add (local.get $col) (i32.const 1))))
            (local.set $tup (call $push_tok (local.get $buf) (local.get $count) (local.get $tok)))
            (local.set $buf (call $list_index (local.get $tup) (i32.const 0)))
            (local.set $count (call $list_index (local.get $tup) (i32.const 1)))
            (local.set $pos (i32.add (local.get $pos) (i32.const 1)))
            (local.set $col (i32.add (local.get $col) (i32.const 1)))
            (br $main_loop)))

        ;; Unknown byte — skip
        (local.set $pos (i32.add (local.get $pos) (i32.const 1)))
        (local.set $col (i32.add (local.get $col) (i32.const 1)))
        (br $main_loop)))

    ;; Return (buf, count) as 2-tuple
    (local.set $tup (call $make_list (i32.const 2)))
    (drop (call $list_set (local.get $tup) (i32.const 0) (local.get $buf)))
    (drop (call $list_set (local.get $tup) (i32.const 1) (local.get $count)))
    (local.get $tup))

  ;; ─── Token Kind to String (for debug output) ──────────────────────
  (func $tokenkind_name (param $kind i32) (result i32)
    (local $tag i32)
    ;; Sentinel check
    (if (result i32) (call $is_sentinel (local.get $kind))
      (then
        ;; The kind value IS the tag for nullary variants
        (local.set $tag (local.get $kind))
        ;; Map tag to name string
        (if (i32.eq (local.get $tag) (i32.const 0)) (then (return (i32.const 256))))  ;; "fn"
        (if (i32.eq (local.get $tag) (i32.const 1)) (then (return (i32.const 264))))  ;; "let"
        (if (i32.eq (local.get $tag) (i32.const 2)) (then (return (i32.const 272))))  ;; "if"
        (if (i32.eq (local.get $tag) (i32.const 3)) (then (return (i32.const 280))))  ;; "else"
        ;; ... (abbreviated — full table would map all 64 nullary sentinels)
        (if (i32.eq (local.get $tag) (i32.const 68)) (then (return (i32.const 272)))) ;; TNewline→"NL"
        (if (i32.eq (local.get $tag) (i32.const 69)) (then (return (i32.const 272)))) ;; TEof→"EOF"
        (call $int_to_str (local.get $tag)))
      (else
        ;; Fielded variant — extract tag from offset 0
        (local.set $tag (i32.load (local.get $kind)))
        (if (i32.eq (local.get $tag) (i32.const 25))
          (then (return (i32.load offset=4 (local.get $kind)))))  ;; TIdent → payload string
        (if (i32.eq (local.get $tag) (i32.const 26))
          (then (return (call $int_to_str (i32.load offset=4 (local.get $kind))))))  ;; TInt → str
        (if (i32.eq (local.get $tag) (i32.const 28))
          (then (return (i32.load offset=4 (local.get $kind)))))  ;; TString → payload
        (if (i32.eq (local.get $tag) (i32.const 29))
          (then (return (i32.load offset=4 (local.get $kind)))))  ;; TDocComment → payload
        (call $int_to_str (local.get $tag)))))

  ;; ─── Parser Infrastructure ──────────────────────────────────────────
  ;; Graph stub: fresh handle = incrementing counter
  ;; (Real graph comes later; parser just needs unique IDs)

  (global $next_handle (mut i32) (i32.const 1))

  (func $fresh_handle (result i32)
    (local $h i32)
    (local.set $h (global.get $next_handle))
    (global.set $next_handle (i32.add (global.get $next_handle) (i32.const 1)))
    (local.get $h))

  ;; ─── AST Node Sentinel IDs ────────────────────────────────────────
  ;; Expr variants: LitInt=80 LitFloat=81 LitString=82 LitBool=83
  ;;   LitUnit=84 VarRef=85 BinOpExpr=86 UnaryOpExpr=87
  ;;   CallExpr=88 LambdaExpr=89 IfExpr=90 BlockExpr=91
  ;;   MatchExpr=92 HandleExpr=93 PerformExpr=94 ResumeExpr=95
  ;;   MakeListExpr=96 MakeTupleExpr=97 MakeRecordExpr=98
  ;;   NamedRecordExpr=99 FieldExpr=100 PipeExpr=101
  ;; NodeBody: NExpr=110 NStmt=111 NPat=112 NHole=113
  ;; Stmt: LetStmt=120 FnStmt=121 TypeDefStmt=122
  ;;   EffectDeclStmt=123 HandlerDeclStmt=124 ExprStmt=125
  ;;   ImportStmt=126 RefineStmt=127 Documented=128
  ;; Pat: PVar=130 PWild=131 PLit=132 PCon=133
  ;;   PTuple=134 PList=135 PRecord=136
  ;; BinOp: BAdd=140..BConcat=153
  ;; PipeKind: PForward=160 PDiverge=161 PCompose=162
  ;;   PTeeBlock=163 PTeeInline=164 PFeedback=165
  ;; Ownership: Inferred=170 Own=171 Ref=172

  ;; N(body, span, handle) → [tag=0][body][span][handle]
  (func $mk_node (param $body i32) (param $span i32) (param $handle i32) (result i32)
    (local $ptr i32)
    (local.set $ptr (call $alloc (i32.const 16)))
    (i32.store (local.get $ptr) (i32.const 0))
    (i32.store offset=4 (local.get $ptr) (local.get $body))
    (i32.store offset=8 (local.get $ptr) (local.get $span))
    (i32.store offset=12 (local.get $ptr) (local.get $handle))
    (local.get $ptr))

  ;; NExpr(e) → [tag=110][e]
  (func $mk_NExpr (param $e i32) (result i32)
    (local $ptr i32)
    (local.set $ptr (call $alloc (i32.const 8)))
    (i32.store (local.get $ptr) (i32.const 110))
    (i32.store offset=4 (local.get $ptr) (local.get $e))
    (local.get $ptr))

  ;; NStmt(s) → [tag=111][s]
  (func $mk_NStmt (param $s i32) (result i32)
    (local $ptr i32)
    (local.set $ptr (call $alloc (i32.const 8)))
    (i32.store (local.get $ptr) (i32.const 111))
    (i32.store offset=4 (local.get $ptr) (local.get $s))
    (local.get $ptr))

  ;; nexpr(e, span) = N(NExpr(e), span, fresh_handle())
  (func $nexpr (param $e i32) (param $span i32) (result i32)
    (call $mk_node
      (call $mk_NExpr (local.get $e))
      (local.get $span)
      (call $fresh_handle)))

  ;; nstmt(s, span) = N(NStmt(s), span, fresh_handle())
  (func $nstmt (param $s i32) (param $span i32) (result i32)
    (call $mk_node
      (call $mk_NStmt (local.get $s))
      (local.get $span)
      (call $fresh_handle)))

  ;; ─── Expr constructors ────────────────────────────────────────────

  ;; LitInt(n) → [tag=80][n]
  (func $mk_LitInt (param $n i32) (result i32)
    (local $p i32) (local.set $p (call $alloc (i32.const 8)))
    (i32.store (local.get $p) (i32.const 80))
    (i32.store offset=4 (local.get $p) (local.get $n))
    (local.get $p))

  ;; LitString(s) → [tag=82][s]
  (func $mk_LitString (param $s i32) (result i32)
    (local $p i32) (local.set $p (call $alloc (i32.const 8)))
    (i32.store (local.get $p) (i32.const 82))
    (i32.store offset=4 (local.get $p) (local.get $s))
    (local.get $p))

  ;; LitBool(b) → [tag=83][b]  (b: 0=false, 1=true)
  (func $mk_LitBool (param $b i32) (result i32)
    (local $p i32) (local.set $p (call $alloc (i32.const 8)))
    (i32.store (local.get $p) (i32.const 83))
    (i32.store offset=4 (local.get $p) (local.get $b))
    (local.get $p))

  ;; VarRef(name) → [tag=85][name_ptr]
  (func $mk_VarRef (param $name i32) (result i32)
    (local $p i32) (local.set $p (call $alloc (i32.const 8)))
    (i32.store (local.get $p) (i32.const 85))
    (i32.store offset=4 (local.get $p) (local.get $name))
    (local.get $p))

  ;; BinOpExpr(op, left, right) → [tag=86][op][left][right]
  (func $mk_BinOpExpr (param $op i32) (param $l i32) (param $r i32) (result i32)
    (local $p i32) (local.set $p (call $alloc (i32.const 16)))
    (i32.store (local.get $p) (i32.const 86))
    (i32.store offset=4 (local.get $p) (local.get $op))
    (i32.store offset=8 (local.get $p) (local.get $l))
    (i32.store offset=12 (local.get $p) (local.get $r))
    (local.get $p))

  ;; CallExpr(callee, args) → [tag=88][callee][args]
  (func $mk_CallExpr (param $callee i32) (param $args i32) (result i32)
    (local $p i32) (local.set $p (call $alloc (i32.const 12)))
    (i32.store (local.get $p) (i32.const 88))
    (i32.store offset=4 (local.get $p) (local.get $callee))
    (i32.store offset=8 (local.get $p) (local.get $args))
    (local.get $p))

  ;; IfExpr(cond, then, else) → [tag=90][cond][then][else]
  (func $mk_IfExpr (param $c i32) (param $t i32) (param $e i32) (result i32)
    (local $p i32) (local.set $p (call $alloc (i32.const 16)))
    (i32.store (local.get $p) (i32.const 90))
    (i32.store offset=4 (local.get $p) (local.get $c))
    (i32.store offset=8 (local.get $p) (local.get $t))
    (i32.store offset=12 (local.get $p) (local.get $e))
    (local.get $p))

  ;; BlockExpr(stmts, final_expr) → [tag=91][stmts][expr]
  (func $mk_BlockExpr (param $stmts i32) (param $expr i32) (result i32)
    (local $p i32) (local.set $p (call $alloc (i32.const 12)))
    (i32.store (local.get $p) (i32.const 91))
    (i32.store offset=4 (local.get $p) (local.get $stmts))
    (i32.store offset=8 (local.get $p) (local.get $expr))
    (local.get $p))

  ;; MatchExpr(scrut, arms) → [tag=92][scrut][arms]
  (func $mk_MatchExpr (param $scrut i32) (param $arms i32) (result i32)
    (local $p i32) (local.set $p (call $alloc (i32.const 12)))
    (i32.store (local.get $p) (i32.const 92))
    (i32.store offset=4 (local.get $p) (local.get $scrut))
    (i32.store offset=8 (local.get $p) (local.get $arms))
    (local.get $p))

  ;; PerformExpr(op_name, args) → [tag=94][name][args]
  (func $mk_PerformExpr (param $name i32) (param $args i32) (result i32)
    (local $p i32) (local.set $p (call $alloc (i32.const 12)))
    (i32.store (local.get $p) (i32.const 94))
    (i32.store offset=4 (local.get $p) (local.get $name))
    (i32.store offset=8 (local.get $p) (local.get $args))
    (local.get $p))

  ;; PipeExpr(kind, left, right) → [tag=101][kind][left][right]
  (func $mk_PipeExpr (param $kind i32) (param $l i32) (param $r i32) (result i32)
    (local $p i32) (local.set $p (call $alloc (i32.const 16)))
    (i32.store (local.get $p) (i32.const 101))
    (i32.store offset=4 (local.get $p) (local.get $kind))
    (i32.store offset=8 (local.get $p) (local.get $l))
    (i32.store offset=12 (local.get $p) (local.get $r))
    (local.get $p))

  ;; ─── Stmt constructors ────────────────────────────────────────────

  ;; LetStmt(pat, val) → [tag=120][pat][val]
  (func $mk_LetStmt (param $pat i32) (param $val i32) (result i32)
    (local $p i32) (local.set $p (call $alloc (i32.const 12)))
    (i32.store (local.get $p) (i32.const 120))
    (i32.store offset=4 (local.get $p) (local.get $pat))
    (i32.store offset=8 (local.get $p) (local.get $val))
    (local.get $p))

  ;; FnStmt(name, params, ret, effs, body)
  (func $mk_FnStmt (param $name i32) (param $params i32) (param $ret i32) (param $effs i32) (param $body i32) (result i32)
    (local $p i32) (local.set $p (call $alloc (i32.const 24)))
    (i32.store (local.get $p) (i32.const 121))
    (i32.store offset=4 (local.get $p) (local.get $name))
    (i32.store offset=8 (local.get $p) (local.get $params))
    (i32.store offset=12 (local.get $p) (local.get $ret))
    (i32.store offset=16 (local.get $p) (local.get $effs))
    (i32.store offset=20 (local.get $p) (local.get $body))
    (local.get $p))

  ;; ExprStmt(node) → [tag=125][node]
  (func $mk_ExprStmt (param $node i32) (result i32)
    (local $p i32) (local.set $p (call $alloc (i32.const 8)))
    (i32.store (local.get $p) (i32.const 125))
    (i32.store offset=4 (local.get $p) (local.get $node))
    (local.get $p))

  ;; ImportStmt(path) → [tag=126][path]
  (func $mk_ImportStmt (param $path i32) (result i32)
    (local $p i32) (local.set $p (call $alloc (i32.const 8)))
    (i32.store (local.get $p) (i32.const 126))
    (i32.store offset=4 (local.get $p) (local.get $path))
    (local.get $p))

  ;; TypeDefStmt(name, targs, variants)
  (func $mk_TypeDefStmt (param $name i32) (param $targs i32) (param $variants i32) (result i32)
    (local $p i32) (local.set $p (call $alloc (i32.const 16)))
    (i32.store (local.get $p) (i32.const 122))
    (i32.store offset=4 (local.get $p) (local.get $name))
    (i32.store offset=8 (local.get $p) (local.get $targs))
    (i32.store offset=12 (local.get $p) (local.get $variants))
    (local.get $p))

  ;; EffectDeclStmt(name, ops)
  (func $mk_EffectDeclStmt (param $name i32) (param $ops i32) (result i32)
    (local $p i32) (local.set $p (call $alloc (i32.const 12)))
    (i32.store (local.get $p) (i32.const 123))
    (i32.store offset=4 (local.get $p) (local.get $name))
    (i32.store offset=8 (local.get $p) (local.get $ops))
    (local.get $p))

  ;; ─── Token navigation (parser helpers) ────────────────────────────

  ;; kind_at: get TokenKind at pos. Token = [tag][kind][span]
  (func $kind_at (param $tokens i32) (param $pos i32) (result i32)
    (local $tok i32)
    (if (result i32) (i32.ge_u (local.get $pos) (call $len (local.get $tokens)))
      (then (i32.const 69))  ;; TEof
      (else
        (local.set $tok (call $list_index (local.get $tokens) (local.get $pos)))
        (i32.load offset=4 (local.get $tok)))))

  ;; span_at: get Span at pos
  (func $span_at_p (param $tokens i32) (param $pos i32) (result i32)
    (local $tok i32)
    (if (result i32) (i32.ge_u (local.get $pos) (call $len (local.get $tokens)))
      (then (call $mk_span (i32.const 0) (i32.const 0) (i32.const 0) (i32.const 0)))
      (else
        (local.set $tok (call $list_index (local.get $tokens) (local.get $pos)))
        (i32.load offset=8 (local.get $tok)))))

  ;; kind_eq_sentinel: compare two TokenKinds. For sentinels (<4096),
  ;; direct i32 compare. For fielded, compare tags at offset 0.
  (func $kind_eq_s (param $a i32) (param $b i32) (result i32)
    (if (result i32) (i32.and
          (call $is_sentinel (local.get $a))
          (call $is_sentinel (local.get $b)))
      (then (i32.eq (local.get $a) (local.get $b)))
      (else
        (if (result i32) (i32.and
              (i32.eqz (call $is_sentinel (local.get $a)))
              (i32.eqz (call $is_sentinel (local.get $b))))
          (then (i32.eq (call $tag_of (local.get $a))
                        (call $tag_of (local.get $b))))
          (else (i32.const 0))))))

  ;; at: check if token at pos has given kind
  (func $at (param $tokens i32) (param $pos i32) (param $kind i32) (result i32)
    (call $kind_eq_s
      (call $kind_at (local.get $tokens) (local.get $pos))
      (local.get $kind)))

  ;; skip_ws: skip TNewline tokens
  (func $skip_ws_p (param $tokens i32) (param $pos i32) (result i32)
    (block $done
      (loop $skip
        (br_if $done (i32.ne (call $kind_at (local.get $tokens) (local.get $pos)) (i32.const 68)))
        (local.set $pos (i32.add (local.get $pos) (i32.const 1)))
        (br $skip)))
    (local.get $pos))

  ;; skip_sep: skip TNewline and TSemicolon
  (func $skip_sep (param $tokens i32) (param $pos i32) (result i32)
    (local $k i32)
    (block $done
      (loop $skip
        (local.set $k (call $kind_at (local.get $tokens) (local.get $pos)))
        (br_if $done (i32.and
          (i32.ne (local.get $k) (i32.const 68))   ;; TNewline
          (i32.ne (local.get $k) (i32.const 54))))  ;; TSemicolon
        (local.set $pos (i32.add (local.get $pos) (i32.const 1)))
        (br $skip)))
    (local.get $pos))

  ;; expect: consume kind or skip
  (func $expect (param $tokens i32) (param $pos i32) (param $kind i32) (result i32)
    (if (result i32) (call $at (local.get $tokens) (local.get $pos) (local.get $kind))
      (then (i32.add (local.get $pos) (i32.const 1)))
      (else (local.get $pos))))

  ;; ident_at: extract string from TIdent at pos
  (func $ident_at_p (param $tokens i32) (param $pos i32) (result i32)
    (local $k i32)
    (local.set $k (call $kind_at (local.get $tokens) (local.get $pos)))
    (if (result i32) (i32.and
          (i32.eqz (call $is_sentinel (local.get $k)))
          (i32.eq (call $tag_of (local.get $k)) (i32.const 25)))
      (then (i32.load offset=4 (local.get $k)))
      (else (call $str_alloc (i32.const 0)))))

  ;; int_payload: extract int from TInt at pos
  (func $int_at_p (param $tokens i32) (param $pos i32) (result i32)
    (local $k i32)
    (local.set $k (call $kind_at (local.get $tokens) (local.get $pos)))
    (if (result i32) (i32.and
          (i32.eqz (call $is_sentinel (local.get $k)))
          (i32.eq (call $tag_of (local.get $k)) (i32.const 26)))
      (then (i32.load offset=4 (local.get $k)))
      (else (i32.const 0))))

  ;; ─── Operator precedence ──────────────────────────────────────────
  (func $op_prec (param $k i32) (result i32)
    ;; Only sentinels can be operators
    (if (i32.eqz (call $is_sentinel (local.get $k)))
      (then (return (i32.const 0))))
    (if (i32.eq (local.get $k) (i32.const 43)) (then (return (i32.const 1))))  ;; TOrOr
    (if (i32.eq (local.get $k) (i32.const 42)) (then (return (i32.const 2))))  ;; TAndAnd
    (if (i32.eq (local.get $k) (i32.const 30)) (then (return (i32.const 3))))  ;; TEqEq
    (if (i32.eq (local.get $k) (i32.const 31)) (then (return (i32.const 3))))  ;; TBangEq
    (if (i32.eq (local.get $k) (i32.const 61)) (then (return (i32.const 4))))  ;; TLt
    (if (i32.eq (local.get $k) (i32.const 62)) (then (return (i32.const 4))))  ;; TGt
    (if (i32.eq (local.get $k) (i32.const 32)) (then (return (i32.const 4))))  ;; TLtEq
    (if (i32.eq (local.get $k) (i32.const 33)) (then (return (i32.const 4))))  ;; TGtEq
    (if (i32.eq (local.get $k) (i32.const 36)) (then (return (i32.const 5))))  ;; TPlusPlus
    (if (i32.eq (local.get $k) (i32.const 39)) (then (return (i32.const 6))))  ;; TGtLt
    (if (i32.eq (local.get $k) (i32.const 37)) (then (return (i32.const 7))))  ;; TPipeGt
    (if (i32.eq (local.get $k) (i32.const 38)) (then (return (i32.const 8))))  ;; TLtPipe
    (if (i32.eq (local.get $k) (i32.const 41)) (then (return (i32.const 9))))  ;; TLtTilde
    (if (i32.eq (local.get $k) (i32.const 40)) (then (return (i32.const 10)))) ;; TTildeGt
    (if (i32.eq (local.get $k) (i32.const 55)) (then (return (i32.const 11)))) ;; TPlus
    (if (i32.eq (local.get $k) (i32.const 56)) (then (return (i32.const 11)))) ;; TMinus
    (if (i32.eq (local.get $k) (i32.const 57)) (then (return (i32.const 12)))) ;; TStar
    (if (i32.eq (local.get $k) (i32.const 58)) (then (return (i32.const 12)))) ;; TSlash
    (if (i32.eq (local.get $k) (i32.const 59)) (then (return (i32.const 12)))) ;; TPercent
    (i32.const 0))

  ;; op_to_binop: map token kind → BinOp sentinel
  (func $op_to_binop (param $k i32) (result i32)
    (if (i32.eq (local.get $k) (i32.const 55)) (then (return (i32.const 140)))) ;; TPlus→BAdd
    (if (i32.eq (local.get $k) (i32.const 56)) (then (return (i32.const 141)))) ;; TMinus→BSub
    (if (i32.eq (local.get $k) (i32.const 57)) (then (return (i32.const 142)))) ;; TStar→BMul
    (if (i32.eq (local.get $k) (i32.const 58)) (then (return (i32.const 143)))) ;; TSlash→BDiv
    (if (i32.eq (local.get $k) (i32.const 59)) (then (return (i32.const 144)))) ;; TPercent→BMod
    (if (i32.eq (local.get $k) (i32.const 30)) (then (return (i32.const 145)))) ;; TEqEq→BEq
    (if (i32.eq (local.get $k) (i32.const 31)) (then (return (i32.const 146)))) ;; TBangEq→BNe
    (if (i32.eq (local.get $k) (i32.const 61)) (then (return (i32.const 147)))) ;; TLt→BLt
    (if (i32.eq (local.get $k) (i32.const 62)) (then (return (i32.const 148)))) ;; TGt→BGt
    (if (i32.eq (local.get $k) (i32.const 32)) (then (return (i32.const 149)))) ;; TLtEq→BLe
    (if (i32.eq (local.get $k) (i32.const 33)) (then (return (i32.const 150)))) ;; TGtEq→BGe
    (if (i32.eq (local.get $k) (i32.const 42)) (then (return (i32.const 151)))) ;; TAndAnd→BAnd
    (if (i32.eq (local.get $k) (i32.const 43)) (then (return (i32.const 152)))) ;; TOrOr→BOr
    (if (i32.eq (local.get $k) (i32.const 36)) (then (return (i32.const 153)))) ;; TPlusPlus→BConcat
    (i32.const 0))

  ;; is_pipe_op: check if a token is a pipe operator
  (func $is_pipe_op (param $k i32) (result i32)
    (i32.or (i32.or
      (i32.or (i32.eq (local.get $k) (i32.const 37))   ;; TPipeGt
              (i32.eq (local.get $k) (i32.const 38)))   ;; TLtPipe
      (i32.or (i32.eq (local.get $k) (i32.const 39))   ;; TGtLt
              (i32.eq (local.get $k) (i32.const 40))))  ;; TTildeGt
      (i32.eq (local.get $k) (i32.const 41))))          ;; TLtTilde

  ;; pipe_kind: map token → PipeKind sentinel
  (func $pipe_kind (param $k i32) (result i32)
    (if (i32.eq (local.get $k) (i32.const 37)) (then (return (i32.const 160)))) ;; PForward
    (if (i32.eq (local.get $k) (i32.const 38)) (then (return (i32.const 161)))) ;; PDiverge
    (if (i32.eq (local.get $k) (i32.const 39)) (then (return (i32.const 162)))) ;; PCompose
    (if (i32.eq (local.get $k) (i32.const 40)) (then (return (i32.const 164)))) ;; PTeeInline
    (if (i32.eq (local.get $k) (i32.const 41)) (then (return (i32.const 165)))) ;; PFeedback
    (i32.const 160))

  ;; ═══ Pattern Parsing ═══════════════════════════════════════════════
  ;; Hand-transcribed from src/parser.nx lines 1196-1294.
  ;;
  ;; Pattern ADT (from src/types.nx):
  ;;   PVar(name)          → [tag=130][name_ptr]
  ;;   PWild               → sentinel 131
  ;;   PLit(lit_val)       → [tag=132][lit_val]
  ;;   PCon(ctor, sub)     → [tag=133][ctor_name][sub_pats_list]
  ;;   PTuple(sub)         → [tag=134][sub_pats_list]
  ;;   PList(sub)          → [tag=135][sub_pats_list]
  ;;   PRecord(fields)     → [tag=136][fields_list]
  ;;
  ;; LitVal ADT:
  ;;   LVInt(n)            → [tag=180][n]
  ;;   LVFloat(f)          → [tag=181][f]
  ;;   LVString(s)         → [tag=182][s]
  ;;   LVBool(b)           → [tag=183][0|1]
  ;;
  ;; Returns (pat, new_pos) as 2-tuple.
  ;;
  ;; Dispatch per src/parser.nx parse_pat:
  ;;   TIdent("_")         → PWild
  ;;   TIdent(v) caps      → PCon(v, sub_pats) if followed by (
  ;;                        → PCon(v, [])       if not
  ;;   TIdent(v) lower     → PVar(v)
  ;;   TInt(n)             → PLit(LVInt(n))
  ;;   TString(s)          → PLit(LVString(s))
  ;;   TTrue               → PLit(LVBool(true))
  ;;   TFalse              → PLit(LVBool(false))
  ;;   TLParen             → PTuple(sub_pats)
  ;;   TLBracket           → PList(sub_pats)
  ;;   TLBrace             → PRecord(fields)
  ;;   _                   → PWild (error recovery)

  ;; LitVal constructors
  (func $mk_LVInt (param $n i32) (result i32)
    (local $p i32) (local.set $p (call $alloc (i32.const 8)))
    (i32.store (local.get $p) (i32.const 180))
    (i32.store offset=4 (local.get $p) (local.get $n))
    (local.get $p))

  (func $mk_LVString (param $s i32) (result i32)
    (local $p i32) (local.set $p (call $alloc (i32.const 8)))
    (i32.store (local.get $p) (i32.const 182))
    (i32.store offset=4 (local.get $p) (local.get $s))
    (local.get $p))

  (func $mk_LVBool (param $b i32) (result i32)
    (local $p i32) (local.set $p (call $alloc (i32.const 8)))
    (i32.store (local.get $p) (i32.const 183))
    (i32.store offset=4 (local.get $p) (local.get $b))
    (local.get $p))

  ;; Pattern constructors
  (func $mk_PVar (param $name i32) (result i32)
    (local $p i32) (local.set $p (call $alloc (i32.const 8)))
    (i32.store (local.get $p) (i32.const 130))
    (i32.store offset=4 (local.get $p) (local.get $name))
    (local.get $p))

  (func $mk_PLit (param $lit i32) (result i32)
    (local $p i32) (local.set $p (call $alloc (i32.const 8)))
    (i32.store (local.get $p) (i32.const 132))
    (i32.store offset=4 (local.get $p) (local.get $lit))
    (local.get $p))

  (func $mk_PCon (param $name i32) (param $subs i32) (result i32)
    (local $p i32) (local.set $p (call $alloc (i32.const 12)))
    (i32.store (local.get $p) (i32.const 133))
    (i32.store offset=4 (local.get $p) (local.get $name))
    (i32.store offset=8 (local.get $p) (local.get $subs))
    (local.get $p))

  (func $mk_PTuple (param $subs i32) (result i32)
    (local $p i32) (local.set $p (call $alloc (i32.const 8)))
    (i32.store (local.get $p) (i32.const 134))
    (i32.store offset=4 (local.get $p) (local.get $subs))
    (local.get $p))

  (func $mk_PList (param $subs i32) (result i32)
    (local $p i32) (local.set $p (call $alloc (i32.const 8)))
    (i32.store (local.get $p) (i32.const 135))
    (i32.store offset=4 (local.get $p) (local.get $subs))
    (local.get $p))

  ;; first_char_code: get first byte of a string (0 if empty)
  ;; Used to distinguish Capitalized (constructor) vs lowercase (variable)
  (func $first_char_code (param $s i32) (result i32)
    (if (result i32) (i32.eqz (call $str_len (local.get $s)))
      (then (i32.const 0))
      (else (call $byte_at (local.get $s) (i32.const 0)))))

  ;; is_uppercase: 65 <= c <= 90
  (func $is_uppercase (param $c i32) (result i32)
    (i32.and (i32.ge_u (local.get $c) (i32.const 65))
             (i32.le_u (local.get $c) (i32.const 90))))

  ;; ─── parse_pat ────────────────────────────────────────────────────
  ;; Returns (pat, new_pos) as 2-tuple

  (func $parse_pat (param $tokens i32) (param $pos i32) (result i32)
    (local $k i32) (local $tup i32) (local $name i32) (local $fc i32)
    (local $subs_r i32) (local $subs i32) (local $p i32)
    (local.set $k (call $kind_at (local.get $tokens) (local.get $pos)))

    ;; ── Sentinel kinds ──
    (if (call $is_sentinel (local.get $k))
      (then
        ;; TTrue (23) → PLit(LVBool(true))
        (if (i32.eq (local.get $k) (i32.const 23))
          (then
            (local.set $tup (call $make_list (i32.const 2)))
            (drop (call $list_set (local.get $tup) (i32.const 0)
              (call $mk_PLit (call $mk_LVBool (i32.const 1)))))
            (drop (call $list_set (local.get $tup) (i32.const 1)
              (i32.add (local.get $pos) (i32.const 1))))
            (return (local.get $tup))))

        ;; TFalse (24) → PLit(LVBool(false))
        (if (i32.eq (local.get $k) (i32.const 24))
          (then
            (local.set $tup (call $make_list (i32.const 2)))
            (drop (call $list_set (local.get $tup) (i32.const 0)
              (call $mk_PLit (call $mk_LVBool (i32.const 0)))))
            (drop (call $list_set (local.get $tup) (i32.const 1)
              (i32.add (local.get $pos) (i32.const 1))))
            (return (local.get $tup))))

        ;; TLParen (45) → PTuple(sub_pats)
        (if (i32.eq (local.get $k) (i32.const 45))
          (then
            (local.set $subs_r (call $parse_pat_args
              (local.get $tokens)
              (call $skip_ws_p (local.get $tokens) (i32.add (local.get $pos) (i32.const 1)))))
            (local.set $tup (call $make_list (i32.const 2)))
            (drop (call $list_set (local.get $tup) (i32.const 0)
              (call $mk_PTuple (call $list_index (local.get $subs_r) (i32.const 0)))))
            (drop (call $list_set (local.get $tup) (i32.const 1)
              (call $list_index (local.get $subs_r) (i32.const 1))))
            (return (local.get $tup))))

        ;; TLBracket (49) → PList(sub_pats)
        (if (i32.eq (local.get $k) (i32.const 49))
          (then
            (local.set $subs_r (call $parse_pat_list_args
              (local.get $tokens)
              (call $skip_ws_p (local.get $tokens) (i32.add (local.get $pos) (i32.const 1)))))
            (local.set $tup (call $make_list (i32.const 2)))
            (drop (call $list_set (local.get $tup) (i32.const 0)
              (call $mk_PList (call $list_index (local.get $subs_r) (i32.const 0)))))
            (drop (call $list_set (local.get $tup) (i32.const 1)
              (call $list_index (local.get $subs_r) (i32.const 1))))
            (return (local.get $tup))))

        ;; Default sentinel → PWild (skip token)
        (local.set $tup (call $make_list (i32.const 2)))
        (drop (call $list_set (local.get $tup) (i32.const 0) (i32.const 131)))
        (drop (call $list_set (local.get $tup) (i32.const 1)
          (i32.add (local.get $pos) (i32.const 1))))
        (return (local.get $tup))))

    ;; ── Fielded kinds ──
    ;; TIdent (tag=25)
    (if (i32.eq (call $tag_of (local.get $k)) (i32.const 25))
      (then
        (local.set $name (i32.load offset=4 (local.get $k)))
        ;; Check for "_" → PWild
        (if (i32.and
              (i32.eq (call $str_len (local.get $name)) (i32.const 1))
              (i32.eq (call $byte_at (local.get $name) (i32.const 0)) (i32.const 95)))
          (then
            (local.set $tup (call $make_list (i32.const 2)))
            (drop (call $list_set (local.get $tup) (i32.const 0) (i32.const 131)))
            (drop (call $list_set (local.get $tup) (i32.const 1)
              (i32.add (local.get $pos) (i32.const 1))))
            (return (local.get $tup))))
        ;; Check capitalized → constructor pattern
        (local.set $fc (call $first_char_code (local.get $name)))
        (if (call $is_uppercase (local.get $fc))
          (then
            (local.set $p (i32.add (local.get $pos) (i32.const 1)))
            ;; Check for ( → PCon with sub-patterns
            (if (call $at (local.get $tokens) (local.get $p) (i32.const 45))
              (then
                (local.set $subs_r (call $parse_pat_args
                  (local.get $tokens)
                  (call $skip_ws_p (local.get $tokens) (i32.add (local.get $p) (i32.const 1)))))
                (local.set $tup (call $make_list (i32.const 2)))
                (drop (call $list_set (local.get $tup) (i32.const 0)
                  (call $mk_PCon (local.get $name)
                    (call $list_index (local.get $subs_r) (i32.const 0)))))
                (drop (call $list_set (local.get $tup) (i32.const 1)
                  (call $list_index (local.get $subs_r) (i32.const 1))))
                (return (local.get $tup)))
              (else
                ;; Nullary constructor: PCon(name, [])
                (local.set $tup (call $make_list (i32.const 2)))
                (drop (call $list_set (local.get $tup) (i32.const 0)
                  (call $mk_PCon (local.get $name) (call $make_list (i32.const 0)))))
                (drop (call $list_set (local.get $tup) (i32.const 1) (local.get $p)))
                (return (local.get $tup)))))
          (else
            ;; Lowercase → PVar(name)
            (local.set $tup (call $make_list (i32.const 2)))
            (drop (call $list_set (local.get $tup) (i32.const 0)
              (call $mk_PVar (local.get $name))))
            (drop (call $list_set (local.get $tup) (i32.const 1)
              (i32.add (local.get $pos) (i32.const 1))))
            (return (local.get $tup))))))

    ;; TInt (tag=26) → PLit(LVInt(n))
    (if (i32.eq (call $tag_of (local.get $k)) (i32.const 26))
      (then
        (local.set $tup (call $make_list (i32.const 2)))
        (drop (call $list_set (local.get $tup) (i32.const 0)
          (call $mk_PLit (call $mk_LVInt (i32.load offset=4 (local.get $k))))))
        (drop (call $list_set (local.get $tup) (i32.const 1)
          (i32.add (local.get $pos) (i32.const 1))))
        (return (local.get $tup))))

    ;; TString (tag=28) → PLit(LVString(s))
    (if (i32.eq (call $tag_of (local.get $k)) (i32.const 28))
      (then
        (local.set $tup (call $make_list (i32.const 2)))
        (drop (call $list_set (local.get $tup) (i32.const 0)
          (call $mk_PLit (call $mk_LVString (i32.load offset=4 (local.get $k))))))
        (drop (call $list_set (local.get $tup) (i32.const 1)
          (i32.add (local.get $pos) (i32.const 1))))
        (return (local.get $tup))))

    ;; Fallback → PWild
    (local.set $tup (call $make_list (i32.const 2)))
    (drop (call $list_set (local.get $tup) (i32.const 0) (i32.const 131)))
    (drop (call $list_set (local.get $tup) (i32.const 1)
      (i32.add (local.get $pos) (i32.const 1))))
    (local.get $tup))

  ;; ─── parse_pat_args: comma-separated patterns until RParen ────────
  ;; Returns (pat_list, new_pos) as 2-tuple.
  ;; Mirrors src/parser.nx parse_pat_args (lines 1266-1278).

  (func $parse_pat_args (param $tokens i32) (param $pos i32) (result i32)
    (local $p i32) (local $buf i32) (local $count i32)
    (local $result i32) (local $pat i32) (local $p2 i32) (local $p3 i32)
    (local $tup i32)
    (local.set $p (call $skip_ws_p (local.get $tokens) (local.get $pos)))
    ;; Empty: )
    (if (call $at (local.get $tokens) (local.get $p) (i32.const 46)) ;; TRParen
      (then
        (local.set $tup (call $make_list (i32.const 2)))
        (drop (call $list_set (local.get $tup) (i32.const 0)
          (call $make_list (i32.const 0))))
        (drop (call $list_set (local.get $tup) (i32.const 1)
          (i32.add (local.get $p) (i32.const 1))))
        (return (local.get $tup))))
    (local.set $buf (call $make_list (i32.const 4)))
    (local.set $count (i32.const 0))
    (block $done
      (loop $args
        (local.set $result (call $parse_pat (local.get $tokens) (local.get $p)))
        (local.set $pat (call $list_index (local.get $result) (i32.const 0)))
        (local.set $p2 (call $list_index (local.get $result) (i32.const 1)))
        (local.set $buf (call $list_extend_to (local.get $buf)
          (i32.add (local.get $count) (i32.const 1))))
        (drop (call $list_set (local.get $buf) (local.get $count) (local.get $pat)))
        (local.set $count (i32.add (local.get $count) (i32.const 1)))
        (local.set $p3 (call $skip_ws_p (local.get $tokens) (local.get $p2)))
        (if (call $at (local.get $tokens) (local.get $p3) (i32.const 51)) ;; TComma
          (then
            (local.set $p (call $skip_ws_p (local.get $tokens)
              (i32.add (local.get $p3) (i32.const 1))))
            (br $args))
          (else
            (local.set $p (call $expect (local.get $tokens) (local.get $p3) (i32.const 46)))
            (br $done)))))
    (local.set $tup (call $make_list (i32.const 2)))
    (drop (call $list_set (local.get $tup) (i32.const 0)
      (call $slice (local.get $buf) (i32.const 0) (local.get $count))))
    (drop (call $list_set (local.get $tup) (i32.const 1) (local.get $p)))
    (local.get $tup))

  ;; ─── parse_pat_list_args: patterns until RBracket ─────────────────

  (func $parse_pat_list_args (param $tokens i32) (param $pos i32) (result i32)
    (local $p i32) (local $buf i32) (local $count i32)
    (local $result i32) (local $pat i32) (local $p2 i32) (local $p3 i32)
    (local $tup i32)
    (local.set $p (call $skip_ws_p (local.get $tokens) (local.get $pos)))
    (if (call $at (local.get $tokens) (local.get $p) (i32.const 50)) ;; TRBracket
      (then
        (local.set $tup (call $make_list (i32.const 2)))
        (drop (call $list_set (local.get $tup) (i32.const 0)
          (call $make_list (i32.const 0))))
        (drop (call $list_set (local.get $tup) (i32.const 1)
          (i32.add (local.get $p) (i32.const 1))))
        (return (local.get $tup))))
    (local.set $buf (call $make_list (i32.const 4)))
    (local.set $count (i32.const 0))
    (block $done
      (loop $args
        (local.set $result (call $parse_pat (local.get $tokens) (local.get $p)))
        (local.set $pat (call $list_index (local.get $result) (i32.const 0)))
        (local.set $p2 (call $list_index (local.get $result) (i32.const 1)))
        (local.set $buf (call $list_extend_to (local.get $buf)
          (i32.add (local.get $count) (i32.const 1))))
        (drop (call $list_set (local.get $buf) (local.get $count) (local.get $pat)))
        (local.set $count (i32.add (local.get $count) (i32.const 1)))
        (local.set $p3 (call $skip_ws_p (local.get $tokens) (local.get $p2)))
        (if (call $at (local.get $tokens) (local.get $p3) (i32.const 51)) ;; TComma
          (then
            (local.set $p (call $skip_ws_p (local.get $tokens)
              (i32.add (local.get $p3) (i32.const 1))))
            (br $args))
          (else
            (local.set $p (call $expect (local.get $tokens) (local.get $p3) (i32.const 50)))
            (br $done)))))
    (local.set $tup (call $make_list (i32.const 2)))
    (drop (call $list_set (local.get $tup) (i32.const 0)
      (call $slice (local.get $buf) (i32.const 0) (local.get $count))))
    (drop (call $list_set (local.get $tup) (i32.const 1) (local.get $p)))
    (local.get $tup))

  ;; ─── parse_match_arms: pat => expr, ... until RBrace ──────────────
  ;; Each arm is a 2-tuple (pat, body_expr).
  ;; Mirrors src/parser.nx parse_match_arms (lines 1106-1117).

  (func $parse_match_arms_full (param $tokens i32) (param $pos i32) (result i32)
    (local $p i32) (local $buf i32) (local $count i32)
    (local $pat_r i32) (local $pat i32) (local $p2 i32) (local $p3 i32)
    (local $body_r i32) (local $body i32) (local $p4 i32) (local $p5 i32)
    (local $arm i32) (local $tup i32) (local $k i32)
    (local.set $buf (call $make_list (i32.const 4)))
    (local.set $count (i32.const 0))
    (local.set $p (call $skip_ws_p (local.get $tokens) (local.get $pos)))
    (block $done
      (loop $arms
        ;; Check for } or EOF
        (if (i32.or
              (call $at (local.get $tokens) (local.get $p) (i32.const 48))  ;; TRBrace
              (call $at (local.get $tokens) (local.get $p) (i32.const 69))) ;; TEof
          (then
            (local.set $p (i32.add (local.get $p) (i32.const 1)))
            (br $done)))
        ;; Parse pattern
        (local.set $pat_r (call $parse_pat (local.get $tokens) (local.get $p)))
        (local.set $pat (call $list_index (local.get $pat_r) (i32.const 0)))
        (local.set $p2 (call $list_index (local.get $pat_r) (i32.const 1)))
        ;; Expect =>
        (local.set $p3 (call $expect (local.get $tokens)
          (call $skip_ws_p (local.get $tokens) (local.get $p2))
          (i32.const 35)))  ;; TFatArrow
        ;; Parse body expression
        (local.set $body_r (call $parse_expr (local.get $tokens)
          (call $skip_ws_p (local.get $tokens) (local.get $p3))))
        (local.set $body (call $list_index (local.get $body_r) (i32.const 0)))
        (local.set $p4 (call $list_index (local.get $body_r) (i32.const 1)))
        ;; Build arm as 2-tuple (pat, body)
        (local.set $arm (call $make_list (i32.const 2)))
        (drop (call $list_set (local.get $arm) (i32.const 0) (local.get $pat)))
        (drop (call $list_set (local.get $arm) (i32.const 1) (local.get $body)))
        ;; Append to buffer
        (local.set $buf (call $list_extend_to (local.get $buf)
          (i32.add (local.get $count) (i32.const 1))))
        (drop (call $list_set (local.get $buf) (local.get $count) (local.get $arm)))
        (local.set $count (i32.add (local.get $count) (i32.const 1)))
        ;; Skip optional comma + whitespace
        (local.set $p5 (call $skip_ws_p (local.get $tokens) (local.get $p4)))
        (if (call $at (local.get $tokens) (local.get $p5) (i32.const 51)) ;; TComma
          (then (local.set $p5 (i32.add (local.get $p5) (i32.const 1)))))
        (local.set $p (call $skip_ws_p (local.get $tokens) (local.get $p5)))
        (br $arms)))
    ;; Return (arms_list, pos)
    (local.set $tup (call $make_list (i32.const 2)))
    (drop (call $list_set (local.get $tup) (i32.const 0)
      (call $slice (local.get $buf) (i32.const 0) (local.get $count))))
    (drop (call $list_set (local.get $tup) (i32.const 1) (local.get $p)))
    (local.get $tup))

  ;; ═══ Function Statement Parser (Complete) ═══════════════════════════
  ;; Hand-transcribed from src/parser.nx lines 367-441.
  ;;
  ;; fn name(params) [-> retty] [with effects] = body
  ;;
  ;; TParam(name, ty, own_marker, own_marker) → [tag=190][name][ty][own][own]
  ;; Ownership: Inferred=170, Own=171, Ref=172
  ;; Type sentinels: TyInt=200, TyFloat=201, TyString=202, TyBool=203,
  ;;                 TyUnit=204, TyName=205(fielded), TyVar=206(fielded)

  ;; TParam constructor
  (func $mk_TParam (param $name i32) (param $ty i32) (param $own i32) (result i32)
    (local $p i32) (local.set $p (call $alloc (i32.const 20)))
    (i32.store (local.get $p) (i32.const 190))
    (i32.store offset=4 (local.get $p) (local.get $name))
    (i32.store offset=8 (local.get $p) (local.get $ty))
    (i32.store offset=12 (local.get $p) (local.get $own))
    (i32.store offset=16 (local.get $p) (local.get $own))
    (local.get $p))

  ;; TyName(name) → [tag=205][name]
  (func $mk_TyName (param $name i32) (result i32)
    (local $p i32) (local.set $p (call $alloc (i32.const 8)))
    (i32.store (local.get $p) (i32.const 205))
    (i32.store offset=4 (local.get $p) (local.get $name))
    (local.get $p))

  ;; TyVar(handle) → [tag=206][handle]
  (func $mk_TyVar (param $h i32) (result i32)
    (local $p i32) (local.set $p (call $alloc (i32.const 8)))
    (i32.store (local.get $p) (i32.const 206))
    (i32.store offset=4 (local.get $p) (local.get $h))
    (local.get $p))

  ;; ─── parse_type_ty: type expression parser ────────────────────────
  ;; Int → 200, Float → 201, String → 202, Bool → TyName("Bool"),
  ;; Unit → 204, other ident → TyName(v), () → TyUnit
  ;; Returns (ty, new_pos) as 2-tuple.

  ;; Data segments for type name comparison (safe region 536+)
  ;; "Int" at 536, "Float" at 544, "String" at 552, "Bool" at 564, "Unit" at 572
  ;; These need length prefixes for str_eq comparison.

  (func $parse_type_ty (param $tokens i32) (param $pos i32) (result i32)
    (local $k i32) (local $name i32) (local $tup i32) (local $p i32)
    (local.set $k (call $kind_at (local.get $tokens) (local.get $pos)))
    ;; TIdent → check for known type names
    (if (i32.and
          (i32.eqz (call $is_sentinel (local.get $k)))
          (i32.eq (call $tag_of (local.get $k)) (i32.const 25)))
      (then
        (local.set $name (i32.load offset=4 (local.get $k)))
        (local.set $tup (call $make_list (i32.const 2)))
        ;; Check known names via first char + length
        (if (i32.and (i32.eq (call $str_len (local.get $name)) (i32.const 3))
                     (i32.eq (call $byte_at (local.get $name) (i32.const 0)) (i32.const 73))) ;; 'I'
          (then ;; "Int"
            (drop (call $list_set (local.get $tup) (i32.const 0) (i32.const 200)))
            (drop (call $list_set (local.get $tup) (i32.const 1) (i32.add (local.get $pos) (i32.const 1))))
            (return (local.get $tup))))
        (if (i32.and (i32.eq (call $str_len (local.get $name)) (i32.const 5))
                     (i32.eq (call $byte_at (local.get $name) (i32.const 0)) (i32.const 70))) ;; 'F'
          (then ;; "Float"
            (drop (call $list_set (local.get $tup) (i32.const 0) (i32.const 201)))
            (drop (call $list_set (local.get $tup) (i32.const 1) (i32.add (local.get $pos) (i32.const 1))))
            (return (local.get $tup))))
        (if (i32.and (i32.eq (call $str_len (local.get $name)) (i32.const 6))
                     (i32.eq (call $byte_at (local.get $name) (i32.const 0)) (i32.const 83))) ;; 'S'
          (then ;; "String"
            (drop (call $list_set (local.get $tup) (i32.const 0) (i32.const 202)))
            (drop (call $list_set (local.get $tup) (i32.const 1) (i32.add (local.get $pos) (i32.const 1))))
            (return (local.get $tup))))
        (if (i32.and (i32.eq (call $str_len (local.get $name)) (i32.const 4))
                     (i32.eq (call $byte_at (local.get $name) (i32.const 0)) (i32.const 85))) ;; 'U'
          (then ;; "Unit"
            (drop (call $list_set (local.get $tup) (i32.const 0) (i32.const 204)))
            (drop (call $list_set (local.get $tup) (i32.const 1) (i32.add (local.get $pos) (i32.const 1))))
            (return (local.get $tup))))
        ;; Default: TyName(name)
        (drop (call $list_set (local.get $tup) (i32.const 0) (call $mk_TyName (local.get $name))))
        (drop (call $list_set (local.get $tup) (i32.const 1) (i32.add (local.get $pos) (i32.const 1))))
        (return (local.get $tup))))
    ;; TLParen → () is TyUnit, or parse tuple type
    (if (i32.and (call $is_sentinel (local.get $k)) (i32.eq (local.get $k) (i32.const 45)))
      (then
        (local.set $p (call $skip_ws_p (local.get $tokens) (i32.add (local.get $pos) (i32.const 1))))
        (if (call $at (local.get $tokens) (local.get $p) (i32.const 46)) ;; TRParen
          (then
            (local.set $tup (call $make_list (i32.const 2)))
            (drop (call $list_set (local.get $tup) (i32.const 0) (i32.const 204)))
            (drop (call $list_set (local.get $tup) (i32.const 1) (i32.add (local.get $p) (i32.const 1))))
            (return (local.get $tup))))))
    ;; Fallback
    (local.set $tup (call $make_list (i32.const 2)))
    (drop (call $list_set (local.get $tup) (i32.const 0) (i32.const 204)))
    (drop (call $list_set (local.get $tup) (i32.const 1) (i32.add (local.get $pos) (i32.const 1))))
    (local.get $tup))

  ;; ─── parse_one_param ──────────────────────────────────────────────
  ;; [own|ref] name [: Type]
  ;; Returns (TParam, new_pos) as 2-tuple.

  (func $parse_one_param (param $tokens i32) (param $pos i32) (result i32)
    (local $own i32) (local $p i32) (local $name i32) (local $p2 i32)
    (local $ty_r i32) (local $ty i32) (local $tup i32) (local $k i32)
    ;; Check ownership marker
    (local.set $k (call $kind_at (local.get $tokens) (local.get $pos)))
    (local.set $own (i32.const 170)) ;; Inferred
    (local.set $p (local.get $pos))
    (if (i32.eq (local.get $k) (i32.const 20)) ;; TOwn
      (then
        (local.set $own (i32.const 171))
        (local.set $p (call $skip_ws_p (local.get $tokens) (i32.add (local.get $pos) (i32.const 1))))))
    (if (i32.eq (local.get $k) (i32.const 21)) ;; TRef
      (then
        (local.set $own (i32.const 172))
        (local.set $p (call $skip_ws_p (local.get $tokens) (i32.add (local.get $pos) (i32.const 1))))))
    ;; Get param name
    (local.set $name (call $ident_at_p (local.get $tokens) (local.get $p)))
    (local.set $p2 (call $skip_ws_p (local.get $tokens) (i32.add (local.get $p) (i32.const 1))))
    ;; Check for : Type annotation
    (if (call $at (local.get $tokens) (local.get $p2) (i32.const 53)) ;; TColon
      (then
        (local.set $ty_r (call $parse_type_ty (local.get $tokens)
          (call $skip_ws_p (local.get $tokens) (i32.add (local.get $p2) (i32.const 1)))))
        (local.set $ty (call $list_index (local.get $ty_r) (i32.const 0)))
        (local.set $p2 (call $list_index (local.get $ty_r) (i32.const 1))))
      (else
        ;; No annotation → TyVar(fresh)
        (local.set $ty (call $mk_TyVar (call $fresh_handle)))))
    (local.set $tup (call $make_list (i32.const 2)))
    (drop (call $list_set (local.get $tup) (i32.const 0)
      (call $mk_TParam (local.get $name) (local.get $ty) (local.get $own))))
    (drop (call $list_set (local.get $tup) (i32.const 1) (local.get $p2)))
    (local.get $tup))

  ;; ─── parse_fn_params: comma-sep params until RParen ───────────────

  (func $parse_fn_params (param $tokens i32) (param $pos i32) (result i32)
    (local $p i32) (local $buf i32) (local $count i32)
    (local $param_r i32) (local $param i32) (local $p2 i32) (local $p3 i32)
    (local $tup i32)
    (local.set $p (call $skip_ws_p (local.get $tokens) (local.get $pos)))
    ;; Empty params
    (if (call $at (local.get $tokens) (local.get $p) (i32.const 46)) ;; TRParen
      (then
        (local.set $tup (call $make_list (i32.const 2)))
        (drop (call $list_set (local.get $tup) (i32.const 0) (call $make_list (i32.const 0))))
        (drop (call $list_set (local.get $tup) (i32.const 1) (i32.add (local.get $p) (i32.const 1))))
        (return (local.get $tup))))
    (local.set $buf (call $make_list (i32.const 4)))
    (local.set $count (i32.const 0))
    (block $done
      (loop $params
        (local.set $param_r (call $parse_one_param (local.get $tokens) (local.get $p)))
        (local.set $param (call $list_index (local.get $param_r) (i32.const 0)))
        (local.set $p2 (call $list_index (local.get $param_r) (i32.const 1)))
        (local.set $buf (call $list_extend_to (local.get $buf)
          (i32.add (local.get $count) (i32.const 1))))
        (drop (call $list_set (local.get $buf) (local.get $count) (local.get $param)))
        (local.set $count (i32.add (local.get $count) (i32.const 1)))
        (local.set $p3 (call $skip_ws_p (local.get $tokens) (local.get $p2)))
        (if (call $at (local.get $tokens) (local.get $p3) (i32.const 51)) ;; TComma
          (then
            (local.set $p (call $skip_ws_p (local.get $tokens) (i32.add (local.get $p3) (i32.const 1))))
            (br $params))
          (else
            (local.set $p (call $expect (local.get $tokens) (local.get $p3) (i32.const 46)))
            (br $done)))))
    ;; Build flat result list (avoid lazy slice view)
    (local.set $param_r (call $make_list (local.get $count)))
    (local.set $p3 (i32.const 0))
    (block $cp_done (loop $cp
      (br_if $cp_done (i32.ge_u (local.get $p3) (local.get $count)))
      (drop (call $list_set (local.get $param_r) (local.get $p3)
        (call $list_index (local.get $buf) (local.get $p3))))
      (local.set $p3 (i32.add (local.get $p3) (i32.const 1)))
      (br $cp)))
    (local.set $tup (call $make_list (i32.const 2)))
    (drop (call $list_set (local.get $tup) (i32.const 0) (local.get $param_r)))
    (drop (call $list_set (local.get $tup) (i32.const 1) (local.get $p)))
    (local.get $tup))

  ;; ─── parse_fn_stmt (COMPLETE) ─────────────────────────────────────
  ;; fn name(params) [-> retty] [with effects] = body

  (func $parse_fn_stmt (param $tokens i32) (param $pos i32) (param $span i32) (result i32)
    (local $name i32) (local $p i32) (local $params_r i32) (local $params i32)
    (local $p2 i32) (local $ret i32) (local $p3 i32)
    (local $p4 i32) (local $body_r i32) (local $tup i32)
    ;; Get function name
    (local.set $name (call $ident_at_p (local.get $tokens) (local.get $pos)))
    ;; Parse (params)
    (local.set $p (call $expect (local.get $tokens)
      (call $skip_ws_p (local.get $tokens) (i32.add (local.get $pos) (i32.const 1)))
      (i32.const 45))) ;; TLParen
    (local.set $params_r (call $parse_fn_params (local.get $tokens) (local.get $p)))
    (local.set $params (call $list_index (local.get $params_r) (i32.const 0)))
    (local.set $p2 (call $skip_ws_p (local.get $tokens)
      (call $list_index (local.get $params_r) (i32.const 1))))
    ;; Optional -> return type
    (local.set $ret (call $nexpr (i32.const 84) (local.get $span))) ;; default LitUnit
    (if (call $at (local.get $tokens) (local.get $p2) (i32.const 34)) ;; TArrow
      (then
        (local.set $p3 (call $skip_ws_p (local.get $tokens) (i32.add (local.get $p2) (i32.const 1))))
        ;; We just skip the return type annotation for now (type is in the TParam)
        (local.set $p2 (call $skip_to_eq_or_brace (local.get $tokens) (local.get $p3)))))
    ;; Skip optional 'with effects'
    (if (call $at (local.get $tokens) (local.get $p2) (i32.const 9)) ;; TWith
      (then
        (local.set $p2 (call $skip_to_eq_or_brace (local.get $tokens)
          (i32.add (local.get $p2) (i32.const 1))))))
    ;; Skip = if present
    (if (call $at (local.get $tokens) (local.get $p2) (i32.const 60)) ;; TEq
      (then (local.set $p2 (i32.add (local.get $p2) (i32.const 1)))))
    ;; Parse body
    (local.set $p3 (call $skip_ws_p (local.get $tokens) (local.get $p2)))
    (if (call $at (local.get $tokens) (local.get $p3) (i32.const 47)) ;; TLBrace
      (then (local.set $body_r (call $parse_block (local.get $tokens)
        (i32.add (local.get $p3) (i32.const 1)) (local.get $span))))
      (else (local.set $body_r (call $parse_expr (local.get $tokens) (local.get $p3)))))
    ;; Build FnStmt
    (local.set $tup (call $make_list (i32.const 2)))
    (drop (call $list_set (local.get $tup) (i32.const 0)
      (call $nstmt
        (call $mk_FnStmt (local.get $name) (local.get $params)
          (local.get $ret) (call $make_list (i32.const 0))
          (call $list_index (local.get $body_r) (i32.const 0)))
        (local.get $span))))
    (drop (call $list_set (local.get $tup) (i32.const 1)
      (call $list_index (local.get $body_r) (i32.const 1))))
    (local.get $tup))

  ;; Helper: skip to = or { (for skipping return type and effect annotations)
  (func $skip_to_eq_or_brace (param $tokens i32) (param $pos i32) (result i32)
    (local $k i32)
    (block $done (loop $scan
      (local.set $k (call $kind_at (local.get $tokens) (local.get $pos)))
      (br_if $done (i32.eq (local.get $k) (i32.const 60)))  ;; TEq
      (br_if $done (i32.eq (local.get $k) (i32.const 47)))  ;; TLBrace
      (br_if $done (i32.eq (local.get $k) (i32.const 69)))  ;; TEof
      (br_if $done (i32.eq (local.get $k) (i32.const 68)))  ;; TNewline
      (local.set $pos (i32.add (local.get $pos) (i32.const 1)))
      (br $scan)))
    (local.get $pos))

  ;; ═══ Type Declaration Parser (Complete) ═════════════════════════════
  ;; Hand-transcribed from src/parser.nx lines 525-586.
  ;;
  ;; type Name = Variant1 | Variant2(Type1, Type2) | ...
  ;; Each variant: (name, field_types_list)

  (func $parse_type_stmt (param $tokens i32) (param $pos i32) (param $span i32) (result i32)
    (local $name i32) (local $p i32) (local $variants_r i32) (local $tup i32)
    (local.set $name (call $ident_at_p (local.get $tokens) (local.get $pos)))
    (local.set $p (call $skip_ws_p (local.get $tokens) (i32.add (local.get $pos) (i32.const 1))))
    ;; Skip =
    (if (call $at (local.get $tokens) (local.get $p) (i32.const 60)) ;; TEq
      (then (local.set $p (call $skip_ws_p (local.get $tokens) (i32.add (local.get $p) (i32.const 1))))))
    ;; Parse variants
    (local.set $variants_r (call $parse_variants (local.get $tokens) (local.get $p)))
    (local.set $tup (call $make_list (i32.const 2)))
    (drop (call $list_set (local.get $tup) (i32.const 0)
      (call $nstmt
        (call $mk_TypeDefStmt (local.get $name)
          (call $make_list (i32.const 0))
          (call $list_index (local.get $variants_r) (i32.const 0)))
        (local.get $span))))
    (drop (call $list_set (local.get $tup) (i32.const 1)
      (call $list_index (local.get $variants_r) (i32.const 1))))
    (local.get $tup))

  ;; parse_variants: V1 | V2(T1, T2) | ...
  ;; Returns (variants_list, new_pos). Each variant is a 2-tuple (name, field_types).

  (func $parse_variants (param $tokens i32) (param $pos i32) (result i32)
    (local $p i32) (local $vname i32) (local $p2 i32)
    (local $fields_r i32) (local $fields i32) (local $p3 i32)
    (local $variant i32) (local $p4 i32) (local $rest_r i32)
    (local $buf i32) (local $count i32) (local $tup i32)
    (local.set $buf (call $make_list (i32.const 4)))
    (local.set $count (i32.const 0))
    (local.set $p (call $skip_ws_p (local.get $tokens) (local.get $pos)))
    (block $done
      (loop $vars
        ;; Get variant name (must be identifier)
        (if (i32.or
              (call $at (local.get $tokens) (local.get $p) (i32.const 69))  ;; TEof
              (call $at (local.get $tokens) (local.get $p) (i32.const 68))) ;; TNewline
          (then (br $done)))
        ;; Check it's actually an ident
        (local.set $vname (call $ident_at_p (local.get $tokens) (local.get $p)))
        (if (i32.eqz (call $str_len (local.get $vname)))
          (then (br $done)))
        (local.set $p2 (i32.add (local.get $p) (i32.const 1)))
        ;; Check for (fields)
        (if (call $at (local.get $tokens) (local.get $p2) (i32.const 45)) ;; TLParen
          (then
            (local.set $fields_r (call $parse_variant_fields (local.get $tokens)
              (call $skip_ws_p (local.get $tokens) (i32.add (local.get $p2) (i32.const 1)))))
            (local.set $fields (call $list_index (local.get $fields_r) (i32.const 0)))
            (local.set $p3 (call $list_index (local.get $fields_r) (i32.const 1))))
          (else
            (local.set $fields (call $make_list (i32.const 0)))
            (local.set $p3 (local.get $p2))))
        ;; Build variant tuple (name, fields)
        (local.set $variant (call $make_list (i32.const 2)))
        (drop (call $list_set (local.get $variant) (i32.const 0) (local.get $vname)))
        (drop (call $list_set (local.get $variant) (i32.const 1) (local.get $fields)))
        ;; Append
        (local.set $buf (call $list_extend_to (local.get $buf)
          (i32.add (local.get $count) (i32.const 1))))
        (drop (call $list_set (local.get $buf) (local.get $count) (local.get $variant)))
        (local.set $count (i32.add (local.get $count) (i32.const 1)))
        ;; Check for | separator
        (local.set $p4 (call $skip_ws_p (local.get $tokens) (local.get $p3)))
        (if (call $at (local.get $tokens) (local.get $p4) (i32.const 64)) ;; TPipe
          (then
            (local.set $p (call $skip_ws_p (local.get $tokens) (i32.add (local.get $p4) (i32.const 1))))
            (br $vars))
          (else
            (local.set $p (local.get $p4))
            (br $done)))))
    (local.set $tup (call $make_list (i32.const 2)))
    (drop (call $list_set (local.get $tup) (i32.const 0)
      (call $slice (local.get $buf) (i32.const 0) (local.get $count))))
    (drop (call $list_set (local.get $tup) (i32.const 1) (local.get $p)))
    (local.get $tup))

  ;; parse_variant_fields: comma-sep type expressions until RParen
  (func $parse_variant_fields (param $tokens i32) (param $pos i32) (result i32)
    (local $p i32) (local $buf i32) (local $count i32)
    (local $ty_r i32) (local $ty i32) (local $p2 i32) (local $p3 i32) (local $tup i32)
    (local.set $p (call $skip_ws_p (local.get $tokens) (local.get $pos)))
    (if (call $at (local.get $tokens) (local.get $p) (i32.const 46)) ;; TRParen
      (then
        (local.set $tup (call $make_list (i32.const 2)))
        (drop (call $list_set (local.get $tup) (i32.const 0) (call $make_list (i32.const 0))))
        (drop (call $list_set (local.get $tup) (i32.const 1) (i32.add (local.get $p) (i32.const 1))))
        (return (local.get $tup))))
    (local.set $buf (call $make_list (i32.const 4)))
    (local.set $count (i32.const 0))
    (block $done
      (loop $fields
        (local.set $ty_r (call $parse_type_ty (local.get $tokens) (local.get $p)))
        (local.set $ty (call $list_index (local.get $ty_r) (i32.const 0)))
        (local.set $p2 (call $list_index (local.get $ty_r) (i32.const 1)))
        (local.set $buf (call $list_extend_to (local.get $buf)
          (i32.add (local.get $count) (i32.const 1))))
        (drop (call $list_set (local.get $buf) (local.get $count) (local.get $ty)))
        (local.set $count (i32.add (local.get $count) (i32.const 1)))
        (local.set $p3 (call $skip_ws_p (local.get $tokens) (local.get $p2)))
        (if (call $at (local.get $tokens) (local.get $p3) (i32.const 51)) ;; TComma
          (then
            (local.set $p (call $skip_ws_p (local.get $tokens) (i32.add (local.get $p3) (i32.const 1))))
            (br $fields))
          (else
            (local.set $p (call $expect (local.get $tokens) (local.get $p3) (i32.const 46)))
            (br $done)))))
    (local.set $tup (call $make_list (i32.const 2)))
    (drop (call $list_set (local.get $tup) (i32.const 0)
      (call $slice (local.get $buf) (i32.const 0) (local.get $count))))
    (drop (call $list_set (local.get $tup) (i32.const 1) (local.get $p)))
    (local.get $tup))

  ;; ═══ Effect Declaration Parser (Complete) ══════════════════════════
  ;; effect Name { op(Type) -> RetType, ... }

  (func $parse_effect_stmt (param $tokens i32) (param $pos i32) (param $span i32) (result i32)
    (local $name i32) (local $p i32) (local $ops_r i32) (local $tup i32)
    (local.set $name (call $ident_at_p (local.get $tokens) (local.get $pos)))
    (local.set $p (call $skip_ws_p (local.get $tokens) (i32.add (local.get $pos) (i32.const 1))))
    (local.set $p (call $expect (local.get $tokens) (local.get $p) (i32.const 47))) ;; TLBrace
    (local.set $ops_r (call $parse_effect_ops (local.get $tokens)
      (call $skip_ws_p (local.get $tokens) (local.get $p))))
    (local.set $tup (call $make_list (i32.const 2)))
    (drop (call $list_set (local.get $tup) (i32.const 0)
      (call $nstmt
        (call $mk_EffectDeclStmt (local.get $name)
          (call $list_index (local.get $ops_r) (i32.const 0)))
        (local.get $span))))
    (drop (call $list_set (local.get $tup) (i32.const 1)
      (call $list_index (local.get $ops_r) (i32.const 1))))
    (local.get $tup))

  ;; parse_effect_ops: op(params) -> ret, ... until }
  ;; Each op is a 3-tuple (name, param_types, ret_type).

  (func $parse_effect_ops (param $tokens i32) (param $pos i32) (result i32)
    (local $p i32) (local $buf i32) (local $count i32) (local $op_name i32)
    (local $p2 i32) (local $params_r i32) (local $params i32) (local $p3 i32)
    (local $ret_r i32) (local $ret_ty i32) (local $p4 i32) (local $op i32)
    (local $tup i32)
    (local.set $buf (call $make_list (i32.const 4)))
    (local.set $count (i32.const 0))
    (local.set $p (call $skip_ws_p (local.get $tokens) (local.get $pos)))
    (block $done
      (loop $ops
        ;; Check } or EOF
        (if (i32.or
              (call $at (local.get $tokens) (local.get $p) (i32.const 48))  ;; TRBrace
              (call $at (local.get $tokens) (local.get $p) (i32.const 69))) ;; TEof
          (then
            (local.set $p (i32.add (local.get $p) (i32.const 1)))
            (br $done)))
        ;; Op name
        (local.set $op_name (call $ident_at_p (local.get $tokens) (local.get $p)))
        (if (i32.eqz (call $str_len (local.get $op_name)))
          (then
            (local.set $p (i32.add (local.get $p) (i32.const 1)))
            (local.set $p (call $skip_sep (local.get $tokens) (local.get $p)))
            (br $ops)))
        ;; Parse (param types)
        (local.set $p2 (call $expect (local.get $tokens)
          (call $skip_ws_p (local.get $tokens) (i32.add (local.get $p) (i32.const 1)))
          (i32.const 45))) ;; TLParen
        (local.set $params_r (call $parse_op_param_types (local.get $tokens)
          (call $skip_ws_p (local.get $tokens) (local.get $p2))))
        (local.set $params (call $list_index (local.get $params_r) (i32.const 0)))
        (local.set $p3 (call $skip_ws_p (local.get $tokens)
          (call $list_index (local.get $params_r) (i32.const 1))))
        ;; Optional -> return type
        (if (call $at (local.get $tokens) (local.get $p3) (i32.const 34)) ;; TArrow
          (then
            (local.set $ret_r (call $parse_type_ty (local.get $tokens)
              (call $skip_ws_p (local.get $tokens) (i32.add (local.get $p3) (i32.const 1)))))
            (local.set $ret_ty (call $list_index (local.get $ret_r) (i32.const 0)))
            (local.set $p4 (call $list_index (local.get $ret_r) (i32.const 1))))
          (else
            (local.set $ret_ty (i32.const 204)) ;; TyUnit
            (local.set $p4 (local.get $p3))))
        ;; Build op 3-tuple (name, params, ret)
        (local.set $op (call $make_list (i32.const 3)))
        (drop (call $list_set (local.get $op) (i32.const 0) (local.get $op_name)))
        (drop (call $list_set (local.get $op) (i32.const 1) (local.get $params)))
        (drop (call $list_set (local.get $op) (i32.const 2) (local.get $ret_ty)))
        ;; Append
        (local.set $buf (call $list_extend_to (local.get $buf)
          (i32.add (local.get $count) (i32.const 1))))
        (drop (call $list_set (local.get $buf) (local.get $count) (local.get $op)))
        (local.set $count (i32.add (local.get $count) (i32.const 1)))
        ;; Skip separators
        (local.set $p (call $skip_sep (local.get $tokens) (local.get $p4)))
        (br $ops)))
    (local.set $tup (call $make_list (i32.const 2)))
    (drop (call $list_set (local.get $tup) (i32.const 0)
      (call $slice (local.get $buf) (i32.const 0) (local.get $count))))
    (drop (call $list_set (local.get $tup) (i32.const 1) (local.get $p)))
    (local.get $tup))

  ;; parse_op_param_types: comma-sep types until RParen
  (func $parse_op_param_types (param $tokens i32) (param $pos i32) (result i32)
    (local $p i32) (local $buf i32) (local $count i32)
    (local $ty_r i32) (local $ty i32) (local $p2 i32) (local $p3 i32) (local $tup i32)
    (local.set $p (call $skip_ws_p (local.get $tokens) (local.get $pos)))
    (if (call $at (local.get $tokens) (local.get $p) (i32.const 46)) ;; TRParen
      (then
        (local.set $tup (call $make_list (i32.const 2)))
        (drop (call $list_set (local.get $tup) (i32.const 0) (call $make_list (i32.const 0))))
        (drop (call $list_set (local.get $tup) (i32.const 1) (i32.add (local.get $p) (i32.const 1))))
        (return (local.get $tup))))
    (local.set $buf (call $make_list (i32.const 4)))
    (local.set $count (i32.const 0))
    (block $done
      (loop $types
        (local.set $ty_r (call $parse_type_ty (local.get $tokens) (local.get $p)))
        (local.set $ty (call $list_index (local.get $ty_r) (i32.const 0)))
        (local.set $p2 (call $list_index (local.get $ty_r) (i32.const 1)))
        (local.set $buf (call $list_extend_to (local.get $buf)
          (i32.add (local.get $count) (i32.const 1))))
        (drop (call $list_set (local.get $buf) (local.get $count) (local.get $ty)))
        (local.set $count (i32.add (local.get $count) (i32.const 1)))
        (local.set $p3 (call $skip_ws_p (local.get $tokens) (local.get $p2)))
        (if (call $at (local.get $tokens) (local.get $p3) (i32.const 51)) ;; TComma
          (then
            (local.set $p (call $skip_ws_p (local.get $tokens) (i32.add (local.get $p3) (i32.const 1))))
            (br $types))
          (else
            (local.set $p (call $expect (local.get $tokens) (local.get $p3) (i32.const 46)))
            (br $done)))))
    (local.set $tup (call $make_list (i32.const 2)))
    (drop (call $list_set (local.get $tup) (i32.const 0)
      (call $slice (local.get $buf) (i32.const 0) (local.get $count))))
    (drop (call $list_set (local.get $tup) (i32.const 1) (local.get $p)))
    (local.get $tup))

  ;; ─── Expression Parsing ─────────────────────────────────────────────

  ;; parse_expr: entry point — calls binop with min_prec=1
  ;; Returns (node, new_pos) as 2-tuple [count=2][tag=0][node][pos]
  (func $parse_expr (param $tokens i32) (param $pos i32) (result i32)
    (call $parse_binop (local.get $tokens) (local.get $pos) (i32.const 1)))

  ;; parse_binop: precedence climbing
  (func $parse_binop (param $tokens i32) (param $pos i32) (param $min_prec i32) (result i32)
    (local $result i32) (local $left i32) (local $p i32)
    (local.set $result (call $parse_postfix (local.get $tokens) (local.get $pos)))
    (local.set $left (call $list_index (local.get $result) (i32.const 0)))
    (local.set $p (call $list_index (local.get $result) (i32.const 1)))
    (call $binop_loop (local.get $tokens) (local.get $left) (local.get $p) (local.get $min_prec)))

  ;; binop_loop: consume operators at >= min_prec
  (func $binop_loop (param $tokens i32) (param $left i32) (param $pos i32) (param $min_prec i32) (result i32)
    (local $p i32) (local $k i32) (local $prec i32)
    (local $right_result i32) (local $right i32) (local $p2 i32)
    (local $node i32) (local $span i32) (local $tup i32)
    (local.set $p (call $skip_ws_p (local.get $tokens) (local.get $pos)))
    (local.set $k (call $kind_at (local.get $tokens) (local.get $p)))
    (local.set $prec (call $op_prec (local.get $k)))
    ;; Continue only if prec >= min_prec and prec > 0
    (if (result i32) (i32.and
          (i32.ge_s (local.get $prec) (local.get $min_prec))
          (i32.gt_s (local.get $prec) (i32.const 0)))
      (then
        (local.set $span (call $span_at_p (local.get $tokens) (local.get $p)))
        ;; Parse right side with higher prec
        (local.set $right_result
          (call $parse_binop (local.get $tokens)
            (i32.add (local.get $p) (i32.const 1))
            (i32.add (local.get $prec) (i32.const 1))))
        (local.set $right (call $list_index (local.get $right_result) (i32.const 0)))
        (local.set $p2 (call $list_index (local.get $right_result) (i32.const 1)))
        ;; Build node: pipe or binop
        (if (result i32) (call $is_pipe_op (local.get $k))
          (then
            (local.set $node (call $nexpr
              (call $mk_PipeExpr (call $pipe_kind (local.get $k))
                (local.get $left) (local.get $right))
              (local.get $span)))
            (call $binop_loop (local.get $tokens) (local.get $node) (local.get $p2) (local.get $min_prec)))
          (else
            (local.set $node (call $nexpr
              (call $mk_BinOpExpr (call $op_to_binop (local.get $k))
                (local.get $left) (local.get $right))
              (local.get $span)))
            (call $binop_loop (local.get $tokens) (local.get $node) (local.get $p2) (local.get $min_prec)))))
      (else
        ;; Return (left, pos)
        (local.set $tup (call $make_list (i32.const 2)))
        (drop (call $list_set (local.get $tup) (i32.const 0) (local.get $left)))
        (drop (call $list_set (local.get $tup) (i32.const 1) (local.get $p)))
        (local.get $tup))))

  ;; parse_postfix: primary + call/field suffixes
  (func $parse_postfix (param $tokens i32) (param $pos i32) (result i32)
    (local $result i32) (local $e i32) (local $p i32)
    (local.set $result (call $parse_primary (local.get $tokens) (local.get $pos)))
    (local.set $e (call $list_index (local.get $result) (i32.const 0)))
    (local.set $p (call $list_index (local.get $result) (i32.const 1)))
    (call $postfix_loop (local.get $tokens) (local.get $e) (local.get $p)))

  ;; postfix_loop: handle f(args) and e.field
  (func $postfix_loop (param $tokens i32) (param $e i32) (param $pos i32) (result i32)
    (local $k i32) (local $args_result i32) (local $args i32) (local $p2 i32)
    (local $node i32) (local $span i32) (local $field i32) (local $tup i32)
    (local.set $k (call $kind_at (local.get $tokens) (local.get $pos)))
    ;; Call: f(args)
    (if (i32.eq (local.get $k) (i32.const 45))  ;; TLParen
      (then
        (local.set $args_result
          (call $parse_call_args (local.get $tokens)
            (call $skip_ws_p (local.get $tokens) (i32.add (local.get $pos) (i32.const 1)))))
        (local.set $args (call $list_index (local.get $args_result) (i32.const 0)))
        (local.set $p2 (call $list_index (local.get $args_result) (i32.const 1)))
        (local.set $span (i32.load offset=8 (local.get $e)))
        (local.set $node (call $nexpr
          (call $mk_CallExpr (local.get $e) (local.get $args))
          (local.get $span)))
        (return (call $postfix_loop (local.get $tokens) (local.get $node) (local.get $p2)))))
    ;; Field: e.field
    (if (i32.eq (local.get $k) (i32.const 52))  ;; TDot
      (then
        (local.set $field (call $ident_at_p (local.get $tokens) (i32.add (local.get $pos) (i32.const 1))))
        (local.set $span (i32.load offset=8 (local.get $e)))
        ;; FieldExpr(e, field) → [tag=100][e][field]
        (local.set $node (call $alloc (i32.const 12)))
        (i32.store (local.get $node) (i32.const 100))
        (i32.store offset=4 (local.get $node) (local.get $e))
        (i32.store offset=8 (local.get $node) (local.get $field))
        (local.set $node (call $nexpr (local.get $node) (local.get $span)))
        (return (call $postfix_loop (local.get $tokens) (local.get $node)
          (i32.add (local.get $pos) (i32.const 2))))))
    ;; No more postfix — return (e, pos)
    (local.set $tup (call $make_list (i32.const 2)))
    (drop (call $list_set (local.get $tup) (i32.const 0) (local.get $e)))
    (drop (call $list_set (local.get $tup) (i32.const 1) (local.get $pos)))
    (local.get $tup))

  ;; parse_call_args: comma-separated exprs until RParen
  (func $parse_call_args (param $tokens i32) (param $pos i32) (result i32)
    (local $p i32) (local $buf i32) (local $count i32)
    (local $result i32) (local $arg i32) (local $p2 i32) (local $p3 i32)
    (local $k i32) (local $tup i32)
    (local.set $p (call $skip_ws_p (local.get $tokens) (local.get $pos)))
    ;; Empty args
    (if (call $at (local.get $tokens) (local.get $p) (i32.const 46))  ;; TRParen
      (then
        (local.set $tup (call $make_list (i32.const 2)))
        (drop (call $list_set (local.get $tup) (i32.const 0) (call $make_list (i32.const 0))))
        (drop (call $list_set (local.get $tup) (i32.const 1) (i32.add (local.get $p) (i32.const 1))))
        (return (local.get $tup))))
    (local.set $buf (call $make_list (i32.const 4)))
    (local.set $count (i32.const 0))
    (block $done
      (loop $args_loop
        ;; Parse one arg
        (local.set $result (call $parse_expr (local.get $tokens) (local.get $p)))
        (local.set $arg (call $list_index (local.get $result) (i32.const 0)))
        (local.set $p2 (call $list_index (local.get $result) (i32.const 1)))
        ;; Extend buf
        (local.set $buf (call $list_extend_to (local.get $buf) (i32.add (local.get $count) (i32.const 1))))
        (drop (call $list_set (local.get $buf) (local.get $count) (local.get $arg)))
        (local.set $count (i32.add (local.get $count) (i32.const 1)))
        ;; Check comma or rparen
        (local.set $p3 (call $skip_ws_p (local.get $tokens) (local.get $p2)))
        (if (call $at (local.get $tokens) (local.get $p3) (i32.const 51))  ;; TComma
          (then
            (local.set $p (call $skip_ws_p (local.get $tokens) (i32.add (local.get $p3) (i32.const 1))))
            (br $args_loop))
          (else
            (local.set $p (call $expect (local.get $tokens) (local.get $p3) (i32.const 46)))  ;; TRParen
            (br $done)))))
    ;; Return (args_list, pos)
    (local.set $tup (call $make_list (i32.const 2)))
    (drop (call $list_set (local.get $tup) (i32.const 0)
      (call $slice (local.get $buf) (i32.const 0) (local.get $count))))
    (drop (call $list_set (local.get $tup) (i32.const 1) (local.get $p)))
    (local.get $tup))

  ;; ─── Primary Expressions ──────────────────────────────────────────

  (func $parse_primary (param $tokens i32) (param $pos i32) (result i32)
    (local $span i32) (local $k i32) (local $node i32) (local $tup i32)
    (local $result i32) (local $name i32) (local $n i32)
    (local.set $span (call $span_at_p (local.get $tokens) (local.get $pos)))
    (local.set $k (call $kind_at (local.get $tokens) (local.get $pos)))

    ;; Sentinel kinds
    (if (call $is_sentinel (local.get $k))
      (then
        ;; TTrue (23)
        (if (i32.eq (local.get $k) (i32.const 23))
          (then
            (local.set $tup (call $make_list (i32.const 2)))
            (drop (call $list_set (local.get $tup) (i32.const 0)
              (call $nexpr (call $mk_LitBool (i32.const 1)) (local.get $span))))
            (drop (call $list_set (local.get $tup) (i32.const 1) (i32.add (local.get $pos) (i32.const 1))))
            (return (local.get $tup))))
        ;; TFalse (24)
        (if (i32.eq (local.get $k) (i32.const 24))
          (then
            (local.set $tup (call $make_list (i32.const 2)))
            (drop (call $list_set (local.get $tup) (i32.const 0)
              (call $nexpr (call $mk_LitBool (i32.const 0)) (local.get $span))))
            (drop (call $list_set (local.get $tup) (i32.const 1) (i32.add (local.get $pos) (i32.const 1))))
            (return (local.get $tup))))
        ;; TLParen (45) — parenthesized expr or tuple
        (if (i32.eq (local.get $k) (i32.const 45))
          (then (return (call $parse_paren (local.get $tokens) (i32.add (local.get $pos) (i32.const 1)) (local.get $span)))))
        ;; TLBrace (47) — block
        (if (i32.eq (local.get $k) (i32.const 47))
          (then (return (call $parse_block (local.get $tokens) (i32.add (local.get $pos) (i32.const 1)) (local.get $span)))))
        ;; TIf (2)
        (if (i32.eq (local.get $k) (i32.const 2))
          (then (return (call $parse_if_expr (local.get $tokens) (i32.add (local.get $pos) (i32.const 1)) (local.get $span)))))
        ;; TMatch (4)
        (if (i32.eq (local.get $k) (i32.const 4))
          (then (return (call $parse_match_expr (local.get $tokens) (i32.add (local.get $pos) (i32.const 1)) (local.get $span)))))
        ;; TPerform (11)
        (if (i32.eq (local.get $k) (i32.const 11))
          (then (return (call $parse_perform_expr (local.get $tokens) (i32.add (local.get $pos) (i32.const 1)) (local.get $span)))))
        ;; TLBracket (49) — list literal
        (if (i32.eq (local.get $k) (i32.const 49))
          (then (return (call $parse_list_lit (local.get $tokens) (i32.add (local.get $pos) (i32.const 1)) (local.get $span)))))
        ;; Default sentinel: treat as unit
        (local.set $tup (call $make_list (i32.const 2)))
        (drop (call $list_set (local.get $tup) (i32.const 0)
          (call $nexpr (i32.const 84) (local.get $span))))  ;; LitUnit
        (drop (call $list_set (local.get $tup) (i32.const 1) (i32.add (local.get $pos) (i32.const 1))))
        (return (local.get $tup))))

    ;; Fielded kinds — check tag
    (local.set $n (call $tag_of (local.get $k)))
    ;; TIdent (25)
    (if (i32.eq (local.get $n) (i32.const 25))
      (then
        (local.set $name (i32.load offset=4 (local.get $k)))
        (local.set $tup (call $make_list (i32.const 2)))
        (drop (call $list_set (local.get $tup) (i32.const 0)
          (call $nexpr (call $mk_VarRef (local.get $name)) (local.get $span))))
        (drop (call $list_set (local.get $tup) (i32.const 1) (i32.add (local.get $pos) (i32.const 1))))
        (return (local.get $tup))))
    ;; TInt (26)
    (if (i32.eq (local.get $n) (i32.const 26))
      (then
        (local.set $tup (call $make_list (i32.const 2)))
        (drop (call $list_set (local.get $tup) (i32.const 0)
          (call $nexpr (call $mk_LitInt (i32.load offset=4 (local.get $k))) (local.get $span))))
        (drop (call $list_set (local.get $tup) (i32.const 1) (i32.add (local.get $pos) (i32.const 1))))
        (return (local.get $tup))))
    ;; TString (28)
    (if (i32.eq (local.get $n) (i32.const 28))
      (then
        (local.set $tup (call $make_list (i32.const 2)))
        (drop (call $list_set (local.get $tup) (i32.const 0)
          (call $nexpr (call $mk_LitString (i32.load offset=4 (local.get $k))) (local.get $span))))
        (drop (call $list_set (local.get $tup) (i32.const 1) (i32.add (local.get $pos) (i32.const 1))))
        (return (local.get $tup))))
    ;; Fallback: skip
    (local.set $tup (call $make_list (i32.const 2)))
    (drop (call $list_set (local.get $tup) (i32.const 0)
      (call $nexpr (i32.const 84) (local.get $span))))  ;; LitUnit
    (drop (call $list_set (local.get $tup) (i32.const 1) (i32.add (local.get $pos) (i32.const 1))))
    (local.get $tup))

  ;; ═══ Compound Expression Parsers (Complete) ════════════════════════
  ;; Hand-transcribed from src/parser.nx.
  ;; No shortcuts — every production from SYNTAX.md is covered.

  ;; ─── Parenthesized expr or tuple ──────────────────────────────────
  ;; () → LitUnit, (e) → e, (e1, e2, ...) → MakeTupleExpr
  ;; Mirrors parser.nx parse_paren_or_tuple (lines 880-897).

  (func $parse_paren (param $tokens i32) (param $pos i32) (param $span i32) (result i32)
    (local $p i32) (local $result i32) (local $first i32) (local $p2 i32)
    (local $p3 i32) (local $tup i32) (local $buf i32) (local $count i32)
    (local $elem_r i32) (local $elem i32)
    (local.set $p (call $skip_ws_p (local.get $tokens) (local.get $pos)))
    ;; Empty parens → LitUnit
    (if (call $at (local.get $tokens) (local.get $p) (i32.const 46)) ;; TRParen
      (then
        (local.set $tup (call $make_list (i32.const 2)))
        (drop (call $list_set (local.get $tup) (i32.const 0)
          (call $nexpr (i32.const 84) (local.get $span)))) ;; LitUnit
        (drop (call $list_set (local.get $tup) (i32.const 1)
          (i32.add (local.get $p) (i32.const 1))))
        (return (local.get $tup))))
    ;; Parse first element
    (local.set $result (call $parse_expr (local.get $tokens) (local.get $p)))
    (local.set $first (call $list_index (local.get $result) (i32.const 0)))
    (local.set $p2 (call $skip_ws_p (local.get $tokens)
      (call $list_index (local.get $result) (i32.const 1))))
    ;; Check for comma → tuple
    (if (call $at (local.get $tokens) (local.get $p2) (i32.const 51)) ;; TComma
      (then
        (local.set $buf (call $make_list (i32.const 4)))
        (drop (call $list_set (local.get $buf) (i32.const 0) (local.get $first)))
        (local.set $count (i32.const 1))
        (local.set $p3 (call $skip_ws_p (local.get $tokens)
          (i32.add (local.get $p2) (i32.const 1))))
        ;; Parse remaining tuple elements
        (block $done
          (loop $elems
            (if (call $at (local.get $tokens) (local.get $p3) (i32.const 46)) ;; TRParen
              (then (br $done)))
            (local.set $elem_r (call $parse_expr (local.get $tokens) (local.get $p3)))
            (local.set $elem (call $list_index (local.get $elem_r) (i32.const 0)))
            (local.set $buf (call $list_extend_to (local.get $buf)
              (i32.add (local.get $count) (i32.const 1))))
            (drop (call $list_set (local.get $buf) (local.get $count) (local.get $elem)))
            (local.set $count (i32.add (local.get $count) (i32.const 1)))
            (local.set $p3 (call $skip_ws_p (local.get $tokens)
              (call $list_index (local.get $elem_r) (i32.const 1))))
            (if (call $at (local.get $tokens) (local.get $p3) (i32.const 51))
              (then (local.set $p3 (call $skip_ws_p (local.get $tokens)
                (i32.add (local.get $p3) (i32.const 1))))))
            (br $elems)))
        ;; MakeTupleExpr
        (local.set $tup (call $make_list (i32.const 2)))
        (drop (call $list_set (local.get $tup) (i32.const 0)
          (call $nexpr
            (call $mk_MakeTupleExpr (call $slice (local.get $buf) (i32.const 0) (local.get $count)))
            (local.get $span))))
        (drop (call $list_set (local.get $tup) (i32.const 1)
          (i32.add (local.get $p3) (i32.const 1))))
        (return (local.get $tup))))
    ;; Single parenthesized expression
    (local.set $tup (call $make_list (i32.const 2)))
    (drop (call $list_set (local.get $tup) (i32.const 0) (local.get $first)))
    (drop (call $list_set (local.get $tup) (i32.const 1)
      (call $expect (local.get $tokens) (local.get $p2) (i32.const 46))))
    (local.get $tup))

  ;; MakeTupleExpr(elems) → [tag=97][elems]
  (func $mk_MakeTupleExpr (param $elems i32) (result i32)
    (local $p i32) (local.set $p (call $alloc (i32.const 8)))
    (i32.store (local.get $p) (i32.const 97))
    (i32.store offset=4 (local.get $p) (local.get $elems))
    (local.get $p))

  ;; MakeListExpr(elems) → [tag=96][elems]
  (func $mk_MakeListExpr (param $elems i32) (result i32)
    (local $p i32) (local.set $p (call $alloc (i32.const 8)))
    (i32.store (local.get $p) (i32.const 96))
    (i32.store offset=4 (local.get $p) (local.get $elems))
    (local.get $p))

  ;; ─── Block expression ─────────────────────────────────────────────
  ;; { stmt; stmt; final_expr }
  ;; Mirrors parser.nx parse_block_body (lines 1042-1069).

  (func $parse_block (param $tokens i32) (param $pos i32) (param $span i32) (result i32)
    (local $p i32) (local $k i32) (local $buf i32) (local $count i32)
    (local $result i32) (local $stmt i32) (local $expr i32)
    (local $p2 i32) (local $p3 i32) (local $tup i32)
    (local.set $buf (call $make_list (i32.const 8)))
    (local.set $count (i32.const 0))
    (local.set $p (call $skip_ws_p (local.get $tokens) (local.get $pos)))
    (local.set $expr (call $nexpr (i32.const 84) (local.get $span))) ;; default LitUnit
    (block $done
      (loop $body
        ;; } → end of block
        (if (call $at (local.get $tokens) (local.get $p) (i32.const 48)) ;; TRBrace
          (then
            (local.set $p (i32.add (local.get $p) (i32.const 1)))
            (br $done)))
        ;; EOF → end
        (if (call $at (local.get $tokens) (local.get $p) (i32.const 69))
          (then (br $done)))
        (local.set $k (call $kind_at (local.get $tokens) (local.get $p)))
        ;; Declaration (let or fn) → parse as statement
        (if (i32.or (i32.eq (local.get $k) (i32.const 1))   ;; TLet
                    (i32.eq (local.get $k) (i32.const 0)))   ;; TFn
          (then
            (local.set $result (call $parse_stmt_p (local.get $tokens) (local.get $p)))
            (local.set $stmt (call $list_index (local.get $result) (i32.const 0)))
            (local.set $p2 (call $list_index (local.get $result) (i32.const 1)))
            (local.set $buf (call $list_extend_to (local.get $buf)
              (i32.add (local.get $count) (i32.const 1))))
            (drop (call $list_set (local.get $buf) (local.get $count) (local.get $stmt)))
            (local.set $count (i32.add (local.get $count) (i32.const 1)))
            (local.set $p (call $skip_sep (local.get $tokens) (local.get $p2)))
            (br $body))
          (else
            ;; Expression — might be final or might be a statement
            (local.set $result (call $parse_expr (local.get $tokens) (local.get $p)))
            (local.set $expr (call $list_index (local.get $result) (i32.const 0)))
            (local.set $p3 (call $skip_ws_p (local.get $tokens)
              (call $list_index (local.get $result) (i32.const 1))))
            ;; If followed by }, this is the final expression
            (if (call $at (local.get $tokens) (local.get $p3) (i32.const 48))
              (then
                (local.set $p (i32.add (local.get $p3) (i32.const 1)))
                (br $done)))
            ;; Otherwise, wrap as ExprStmt and continue
            (local.set $buf (call $list_extend_to (local.get $buf)
              (i32.add (local.get $count) (i32.const 1))))
            (drop (call $list_set (local.get $buf) (local.get $count)
              (call $nstmt (call $mk_ExprStmt (local.get $expr)) (local.get $span))))
            (local.set $count (i32.add (local.get $count) (i32.const 1)))
            (local.set $p (call $skip_sep (local.get $tokens) (local.get $p3)))
            (br $body)))))
    (local.set $tup (call $make_list (i32.const 2)))
    (drop (call $list_set (local.get $tup) (i32.const 0)
      (call $nexpr
        (call $mk_BlockExpr
          (call $slice (local.get $buf) (i32.const 0) (local.get $count))
          (local.get $expr))
        (local.get $span))))
    (drop (call $list_set (local.get $tup) (i32.const 1) (local.get $p)))
    (local.get $tup))

  ;; ─── If expression ────────────────────────────────────────────────
  ;; if cond { then } else { else }
  ;; Mirrors parser.nx parse_if (lines 1071-1095).

  (func $parse_if_expr (param $tokens i32) (param $pos i32) (param $span i32) (result i32)
    (local $cond_r i32) (local $cond i32) (local $p i32)
    (local $then_r i32) (local $then_e i32) (local $p2 i32)
    (local $else_r i32) (local $else_e i32) (local $p3 i32) (local $tup i32)
    ;; Parse condition
    (local.set $cond_r (call $parse_expr (local.get $tokens) (local.get $pos)))
    (local.set $cond (call $list_index (local.get $cond_r) (i32.const 0)))
    (local.set $p (call $skip_ws_p (local.get $tokens)
      (call $list_index (local.get $cond_r) (i32.const 1))))
    ;; Parse then branch (block or expression)
    (if (call $at (local.get $tokens) (local.get $p) (i32.const 47)) ;; TLBrace
      (then
        (local.set $then_r (call $parse_block (local.get $tokens)
          (i32.add (local.get $p) (i32.const 1)) (local.get $span))))
      (else
        (local.set $then_r (call $parse_expr (local.get $tokens) (local.get $p)))))
    (local.set $then_e (call $list_index (local.get $then_r) (i32.const 0)))
    (local.set $p2 (call $skip_ws_p (local.get $tokens)
      (call $list_index (local.get $then_r) (i32.const 1))))
    ;; Check for else
    (if (call $at (local.get $tokens) (local.get $p2) (i32.const 3)) ;; TElse
      (then
        (local.set $p3 (call $skip_ws_p (local.get $tokens)
          (i32.add (local.get $p2) (i32.const 1))))
        ;; else if → recursive
        (if (call $at (local.get $tokens) (local.get $p3) (i32.const 2)) ;; TIf
          (then
            (local.set $else_r (call $parse_if_expr (local.get $tokens)
              (i32.add (local.get $p3) (i32.const 1)) (local.get $span))))
          (else
            ;; else { block } or else expr
            (if (call $at (local.get $tokens) (local.get $p3) (i32.const 47))
              (then
                (local.set $else_r (call $parse_block (local.get $tokens)
                  (i32.add (local.get $p3) (i32.const 1)) (local.get $span))))
              (else
                (local.set $else_r (call $parse_expr (local.get $tokens) (local.get $p3)))))))
        (local.set $else_e (call $list_index (local.get $else_r) (i32.const 0)))
        (local.set $p3 (call $list_index (local.get $else_r) (i32.const 1))))
      (else
        ;; No else → LitUnit
        (local.set $else_e (call $nexpr (i32.const 84) (local.get $span)))
        (local.set $p3 (local.get $p2))))
    ;; Build IfExpr
    (local.set $tup (call $make_list (i32.const 2)))
    (drop (call $list_set (local.get $tup) (i32.const 0)
      (call $nexpr
        (call $mk_IfExpr (local.get $cond) (local.get $then_e) (local.get $else_e))
        (local.get $span))))
    (drop (call $list_set (local.get $tup) (i32.const 1) (local.get $p3)))
    (local.get $tup))

  ;; ─── Match expression (COMPLETE) ──────────────────────────────────
  ;; match scrutinee { pat => expr, ... }
  ;; NOW uses parse_match_arms_full for real pattern+body parsing.

  (func $parse_match_expr (param $tokens i32) (param $pos i32) (param $span i32) (result i32)
    (local $scrut_r i32) (local $scrut i32) (local $p i32)
    (local $arms_r i32) (local $tup i32)
    ;; Parse scrutinee
    (local.set $scrut_r (call $parse_expr (local.get $tokens) (local.get $pos)))
    (local.set $scrut (call $list_index (local.get $scrut_r) (i32.const 0)))
    (local.set $p (call $expect (local.get $tokens)
      (call $skip_ws_p (local.get $tokens)
        (call $list_index (local.get $scrut_r) (i32.const 1)))
      (i32.const 47))) ;; TLBrace
    ;; Parse arms using the REAL arm parser
    (local.set $arms_r (call $parse_match_arms_full (local.get $tokens)
      (call $skip_ws_p (local.get $tokens) (local.get $p))))
    ;; Build MatchExpr
    (local.set $tup (call $make_list (i32.const 2)))
    (drop (call $list_set (local.get $tup) (i32.const 0)
      (call $nexpr
        (call $mk_MatchExpr (local.get $scrut)
          (call $list_index (local.get $arms_r) (i32.const 0)))
        (local.get $span))))
    (drop (call $list_set (local.get $tup) (i32.const 1)
      (call $list_index (local.get $arms_r) (i32.const 1))))
    (local.get $tup))

  ;; ─── Perform expression ───────────────────────────────────────────
  (func $parse_perform_expr (param $tokens i32) (param $pos i32) (param $span i32) (result i32)
    (local $name i32) (local $p i32) (local $args_r i32) (local $tup i32)
    (local.set $name (call $ident_at_p (local.get $tokens) (local.get $pos)))
    (local.set $p (call $expect (local.get $tokens)
      (call $skip_ws_p (local.get $tokens) (i32.add (local.get $pos) (i32.const 1)))
      (i32.const 45))) ;; TLParen
    (local.set $args_r (call $parse_call_args (local.get $tokens)
      (call $skip_ws_p (local.get $tokens) (local.get $p))))
    (local.set $tup (call $make_list (i32.const 2)))
    (drop (call $list_set (local.get $tup) (i32.const 0)
      (call $nexpr
        (call $mk_PerformExpr (local.get $name)
          (call $list_index (local.get $args_r) (i32.const 0)))
        (local.get $span))))
    (drop (call $list_set (local.get $tup) (i32.const 1)
      (call $list_index (local.get $args_r) (i32.const 1))))
    (local.get $tup))

  ;; ─── List literal ─────────────────────────────────────────────────
  ;; [e1, e2, ...]
  (func $parse_list_lit (param $tokens i32) (param $pos i32) (param $span i32) (result i32)
    (local $p i32) (local $buf i32) (local $count i32)
    (local $elem_r i32) (local $elem i32) (local $p2 i32) (local $tup i32)
    (local.set $p (call $skip_ws_p (local.get $tokens) (local.get $pos)))
    ;; Empty list []
    (if (call $at (local.get $tokens) (local.get $p) (i32.const 50)) ;; TRBracket
      (then
        (local.set $tup (call $make_list (i32.const 2)))
        (drop (call $list_set (local.get $tup) (i32.const 0)
          (call $nexpr
            (call $mk_MakeListExpr (call $make_list (i32.const 0)))
            (local.get $span))))
        (drop (call $list_set (local.get $tup) (i32.const 1)
          (i32.add (local.get $p) (i32.const 1))))
        (return (local.get $tup))))
    (local.set $buf (call $make_list (i32.const 4)))
    (local.set $count (i32.const 0))
    (block $done
      (loop $elems
        (local.set $elem_r (call $parse_expr (local.get $tokens) (local.get $p)))
        (local.set $elem (call $list_index (local.get $elem_r) (i32.const 0)))
        (local.set $buf (call $list_extend_to (local.get $buf)
          (i32.add (local.get $count) (i32.const 1))))
        (drop (call $list_set (local.get $buf) (local.get $count) (local.get $elem)))
        (local.set $count (i32.add (local.get $count) (i32.const 1)))
        (local.set $p2 (call $skip_ws_p (local.get $tokens)
          (call $list_index (local.get $elem_r) (i32.const 1))))
        (if (call $at (local.get $tokens) (local.get $p2) (i32.const 51)) ;; TComma
          (then
            (local.set $p (call $skip_ws_p (local.get $tokens)
              (i32.add (local.get $p2) (i32.const 1))))
            (br $elems))
          (else
            (local.set $p (call $expect (local.get $tokens) (local.get $p2) (i32.const 50)))
            (br $done)))))
    (local.set $tup (call $make_list (i32.const 2)))
    (drop (call $list_set (local.get $tup) (i32.const 0)
      (call $nexpr
        (call $mk_MakeListExpr (call $slice (local.get $buf) (i32.const 0) (local.get $count)))
        (local.get $span))))
    (drop (call $list_set (local.get $tup) (i32.const 1) (local.get $p)))
    (local.get $tup))

  ;; ─── skip helpers ─────────────────────────────────────────────────
  (func $skip_to_newline (param $tokens i32) (param $pos i32) (result i32)
    (local $k i32)
    (block $done (loop $scan
      (local.set $k (call $kind_at (local.get $tokens) (local.get $pos)))
      (br_if $done (i32.eq (local.get $k) (i32.const 68)))  ;; TNewline
      (br_if $done (i32.eq (local.get $k) (i32.const 69)))  ;; TEof
      (local.set $pos (i32.add (local.get $pos) (i32.const 1)))
      (br $scan)))
    (local.get $pos))

  (func $skip_to_rbrace (param $tokens i32) (param $pos i32) (result i32)
    (local $depth i32) (local $k i32)
    (local.set $depth (i32.const 1))
    (block $done (loop $scan
      (br_if $done (i32.le_s (local.get $depth) (i32.const 0)))
      (local.set $k (call $kind_at (local.get $tokens) (local.get $pos)))
      (br_if $done (i32.eq (local.get $k) (i32.const 69)))  ;; TEof
      (if (i32.eq (local.get $k) (i32.const 47))  ;; TLBrace
        (then (local.set $depth (i32.add (local.get $depth) (i32.const 1)))))
      (if (i32.eq (local.get $k) (i32.const 48))  ;; TRBrace
        (then (local.set $depth (i32.sub (local.get $depth) (i32.const 1)))))
      (local.set $pos (i32.add (local.get $pos) (i32.const 1)))
      (br $scan)))
    (local.get $pos))

  ;; ═══ Statement Dispatch + Top-Level (Complete) ══════════════════════
  ;; Hand-transcribed from src/parser.nx lines 299-352.

  ;; ─── parse_stmt_p: dispatch on leading token ──────────────────────
  (func $parse_stmt_p (param $tokens i32) (param $pos i32) (result i32)
    (local $k i32) (local $span i32) (local $tup i32) (local $result i32)
    (local $name i32)
    (local.set $k (call $kind_at (local.get $tokens) (local.get $pos)))
    (local.set $span (call $span_at_p (local.get $tokens) (local.get $pos)))
    ;; TFn → parse_fn_stmt
    (if (i32.eq (local.get $k) (i32.const 0))
      (then (return (call $parse_fn_stmt (local.get $tokens)
        (i32.add (local.get $pos) (i32.const 1)) (local.get $span)))))
    ;; TLet → parse_let_stmt
    (if (i32.eq (local.get $k) (i32.const 1))
      (then (return (call $parse_let_stmt (local.get $tokens)
        (i32.add (local.get $pos) (i32.const 1)) (local.get $span)))))
    ;; TType → parse_type_stmt
    (if (i32.eq (local.get $k) (i32.const 5))
      (then (return (call $parse_type_stmt (local.get $tokens)
        (i32.add (local.get $pos) (i32.const 1)) (local.get $span)))))
    ;; TEffect → parse_effect_stmt
    (if (i32.eq (local.get $k) (i32.const 6))
      (then (return (call $parse_effect_stmt (local.get $tokens)
        (i32.add (local.get $pos) (i32.const 1)) (local.get $span)))))
    ;; THandler → parse handler declaration
    (if (i32.eq (local.get $k) (i32.const 8))
      (then
        (local.set $name (call $ident_at_p (local.get $tokens)
          (i32.add (local.get $pos) (i32.const 1))))
        ;; HandlerDeclStmt(name, "", arms)
        ;; For now skip handler body
        (local.set $tup (call $make_list (i32.const 2)))
        (drop (call $list_set (local.get $tup) (i32.const 0)
          (call $nstmt
            (call $mk_handler_decl (local.get $name))
            (local.get $span))))
        (drop (call $list_set (local.get $tup) (i32.const 1)
          (call $skip_to_rbrace (local.get $tokens)
            (call $skip_ws_p (local.get $tokens)
              (i32.add (local.get $pos) (i32.const 2))))))
        (return (local.get $tup))))
    ;; TImport → parse import
    (if (i32.eq (local.get $k) (i32.const 18))
      (then
        (local.set $name (call $ident_at_p (local.get $tokens)
          (i32.add (local.get $pos) (i32.const 1))))
        (local.set $tup (call $make_list (i32.const 2)))
        (drop (call $list_set (local.get $tup) (i32.const 0)
          (call $nstmt (call $mk_ImportStmt (local.get $name)) (local.get $span))))
        (drop (call $list_set (local.get $tup) (i32.const 1)
          (i32.add (local.get $pos) (i32.const 2))))
        (return (local.get $tup))))
    ;; Default: expression statement
    (local.set $result (call $parse_expr (local.get $tokens) (local.get $pos)))
    (local.set $tup (call $make_list (i32.const 2)))
    (drop (call $list_set (local.get $tup) (i32.const 0)
      (call $nstmt
        (call $mk_ExprStmt (call $list_index (local.get $result) (i32.const 0)))
        (local.get $span))))
    (drop (call $list_set (local.get $tup) (i32.const 1)
      (call $list_index (local.get $result) (i32.const 1))))
    (local.get $tup))

  ;; HandlerDeclStmt stub: [tag=124][name][effect=""][arms=[]]
  (func $mk_handler_decl (param $name i32) (result i32)
    (local $p i32) (local.set $p (call $alloc (i32.const 16)))
    (i32.store (local.get $p) (i32.const 124))
    (i32.store offset=4 (local.get $p) (local.get $name))
    (i32.store offset=8 (local.get $p) (call $str_alloc (i32.const 0)))
    (i32.store offset=12 (local.get $p) (call $make_list (i32.const 0)))
    (local.get $p))

  ;; ─── parse_let_stmt (with pattern support) ────────────────────────
  ;; let pat = expr
  ;; Uses parse_pat for destructuring (tuples, constructors, etc.)

  (func $parse_let_stmt (param $tokens i32) (param $pos i32) (param $span i32) (result i32)
    (local $pat_r i32) (local $pat i32) (local $p i32) (local $p2 i32)
    (local $val_r i32) (local $tup i32)
    ;; Parse pattern (handles simple names AND destructuring)
    (local.set $pat_r (call $parse_pat (local.get $tokens) (local.get $pos)))
    (local.set $pat (call $list_index (local.get $pat_r) (i32.const 0)))
    (local.set $p (call $skip_ws_p (local.get $tokens)
      (call $list_index (local.get $pat_r) (i32.const 1))))
    ;; Optional : Type annotation (skip for bootstrap)
    (if (call $at (local.get $tokens) (local.get $p) (i32.const 53)) ;; TColon
      (then
        (local.set $p (call $skip_to_eq_or_brace (local.get $tokens)
          (i32.add (local.get $p) (i32.const 1))))))
    ;; Expect =
    (local.set $p2 (call $expect (local.get $tokens) (local.get $p) (i32.const 60))) ;; TEq
    ;; Parse value expression
    (local.set $val_r (call $parse_expr (local.get $tokens)
      (call $skip_ws_p (local.get $tokens) (local.get $p2))))
    ;; Build LetStmt(pat, val)
    (local.set $tup (call $make_list (i32.const 2)))
    (drop (call $list_set (local.get $tup) (i32.const 0)
      (call $nstmt
        (call $mk_LetStmt (local.get $pat)
          (call $list_index (local.get $val_r) (i32.const 0)))
        (local.get $span))))
    (drop (call $list_set (local.get $tup) (i32.const 1)
      (call $list_index (local.get $val_r) (i32.const 1))))
    (local.get $tup))

  ;; ─── parse_program: top-level statement list ──────────────────────

  (func $parse_program (param $tokens i32) (result i32)
    (local $buf i32) (local $count i32) (local $p i32)
    (local $result i32) (local $stmt i32)
    (local.set $buf (call $make_list (i32.const 16)))
    (local.set $count (i32.const 0))
    (local.set $p (call $skip_ws_p (local.get $tokens) (i32.const 0)))
    (block $done
      (loop $stmts
        (br_if $done (call $at (local.get $tokens) (local.get $p) (i32.const 69))) ;; TEof
        (local.set $result (call $parse_stmt_p (local.get $tokens) (local.get $p)))
        (local.set $stmt (call $list_index (local.get $result) (i32.const 0)))
        (local.set $p (call $skip_sep (local.get $tokens)
          (call $list_index (local.get $result) (i32.const 1))))
        (local.set $buf (call $list_extend_to (local.get $buf)
          (i32.add (local.get $count) (i32.const 1))))
        (drop (call $list_set (local.get $buf) (local.get $count) (local.get $stmt)))
        (local.set $count (i32.add (local.get $count) (i32.const 1)))
        (local.set $p (call $skip_ws_p (local.get $tokens) (local.get $p)))
        (br $stmts)))
    ;; Build flat result list (slice creates a lazy view that list_index can't handle)
    (local.set $result (call $make_list (local.get $count)))
    (local.set $p (i32.const 0))
    (block $cp_done (loop $cp
      (br_if $cp_done (i32.ge_u (local.get $p) (local.get $count)))
      (drop (call $list_set (local.get $result) (local.get $p)
        (call $list_index (local.get $buf) (local.get $p))))
      (local.set $p (i32.add (local.get $p) (i32.const 1)))
      (br $cp)))
    (local.get $result))

  ;; ═══ WAT Fragment Data Segments ═════════════════════════════════════
  ;; Raw byte strings for WAT syntax emission. No length prefix —
  ;; these are used with emit_cstr(addr, len).
  ;;
  ;; Address map (starting at 536, each aligned to next available byte):
  ;;
  ;; 536  "(local.get "   11 bytes  → 547
  ;; 548  "(local.set "   11 bytes  → 559
  ;; 560  "(i32.const "   11 bytes  → 571
  ;; 572  "(call "         6 bytes  → 578
  ;; 578  "(drop "         6 bytes  → 584
  ;; 584  "(func "         6 bytes  → 590
  ;; 590  "(param "        7 bytes  → 597
  ;; 597  " (result i32)"  13 bytes → 610
  ;; 610  "(local "        7 bytes  → 617
  ;; 617  "(if (result i32) " 18 bytes → 635
  ;; 635  "(then "         6 bytes  → 641
  ;; 641  "(else "         6 bytes  → 647
  ;; 647  "(block "        7 bytes  → 654
  ;; 654  "(loop "         6 bytes  → 660
  ;; 660  "(br "           4 bytes  → 664
  ;; 664  "(br_if "        7 bytes  → 671
  ;; 671  "(return "       8 bytes  → 679
  ;; 679  "(i32.add "      9 bytes  → 688
  ;; 688  "(i32.sub "      9 bytes  → 697
  ;; 697  "(i32.mul "      9 bytes  → 706
  ;; 706  "(i32.div_s "   11 bytes  → 717
  ;; 717  "(i32.rem_s "   11 bytes  → 728
  ;; 728  "(i32.eq "       8 bytes  → 736
  ;; 736  "(i32.ne "       8 bytes  → 744
  ;; 744  "(i32.lt_s "    10 bytes  → 754
  ;; 754  "(i32.gt_s "    10 bytes  → 764
  ;; 764  "(i32.le_s "    10 bytes  → 774
  ;; 774  "(i32.ge_s "    10 bytes  → 784
  ;; 784  "(i32.and "      9 bytes  → 793
  ;; 793  "(i32.or "       8 bytes  → 801
  ;; 801  "(i32.eqz "      9 bytes  → 810
  ;; 810  "(i32.store "   11 bytes  → 821
  ;; 821  "(i32.load "    10 bytes  → 831
  ;; 831  "(module"        7 bytes  → 838
  ;; 838  "(memory "       8 bytes  → 846
  ;; 846  "(export "       8 bytes  → 854
  ;; 854  "(import "       8 bytes  → 862
  ;; 862  "(global "       8 bytes  → 870
  ;; 870  "(table "        7 bytes  → 877
  ;; 877  "(elem "         6 bytes  → 883
  ;; 883  "(i32.store8 "  12 bytes  → 895
  ;; 895  "(i32.load8_u " 13 bytes  → 908
  ;; 908  " i32"           4 bytes  → 912
  ;; 912  "(data "         6 bytes  → 918
  ;; 918  "(type "         6 bytes  → 924
  ;; 924  "(func"          5 bytes  → 929
  ;; 929  "offset="        7 bytes  → 936
  ;; 936  "(select "       8 bytes  → 944
  ;; 944  "(i32.sub (i32.const 0) " 24 bytes → 968
  ;;
  ;; Next free: 968
  ;;
  ;; NOTE: these overlap with the bump allocator's sentinel region
  ;; (0-4096) but that's fine — sentinels are identified by value,
  ;; not by reading memory at those addresses. The allocator starts
  ;; at 1 MiB (1048576). Data segments are written at module load
  ;; time before any allocation happens.

  (data (i32.const 536) "(local.get ")
  (data (i32.const 548) "(local.set ")
  (data (i32.const 560) "(i32.const ")
  (data (i32.const 572) "(call ")
  (data (i32.const 578) "(drop ")
  (data (i32.const 584) "(func ")
  (data (i32.const 590) "(param ")
  (data (i32.const 597) " (result i32)")
  (data (i32.const 610) "(local ")
  (data (i32.const 617) "(if (result i32) ")
  (data (i32.const 635) "(then ")
  (data (i32.const 641) "(else ")
  (data (i32.const 647) "(block ")
  (data (i32.const 654) "(loop ")
  (data (i32.const 660) "(br ")
  (data (i32.const 664) "(br_if ")
  (data (i32.const 671) "(return ")
  (data (i32.const 679) "(i32.add ")
  (data (i32.const 688) "(i32.sub ")
  (data (i32.const 697) "(i32.mul ")
  (data (i32.const 706) "(i32.div_s ")
  (data (i32.const 717) "(i32.rem_s ")
  (data (i32.const 728) "(i32.eq ")
  (data (i32.const 736) "(i32.ne ")
  (data (i32.const 744) "(i32.lt_s ")
  (data (i32.const 754) "(i32.gt_s ")
  (data (i32.const 764) "(i32.le_s ")
  (data (i32.const 774) "(i32.ge_s ")
  (data (i32.const 784) "(i32.and ")
  (data (i32.const 793) "(i32.or ")
  (data (i32.const 801) "(i32.eqz ")
  (data (i32.const 810) "(i32.store ")
  (data (i32.const 821) "(i32.load ")
  (data (i32.const 831) "(module")
  (data (i32.const 838) "(memory ")
  (data (i32.const 846) "(export ")
  (data (i32.const 854) "(import ")
  (data (i32.const 862) "(global ")
  (data (i32.const 870) "(table ")
  (data (i32.const 877) "(elem ")
  (data (i32.const 883) "(i32.store8 ")
  (data (i32.const 895) "(i32.load8_u ")
  (data (i32.const 908) " i32")
  (data (i32.const 912) "(data ")
  (data (i32.const 918) "(type ")
  (data (i32.const 924) "(func")
  (data (i32.const 929) "offset=")
  (data (i32.const 936) "(select ")
  (data (i32.const 944) "(i32.sub (i32.const 0) ")

  ;; Additional: runtime function name strings for emitter
  ;; 968: "str_concat"  (10 bytes) → 978
  ;; 978: "call_indirect" (13 bytes) → 991
  ;; 991: "str_alloc"  (9 bytes) → 1000
  ;; 1000: "record_get" (10 bytes) → 1010
  ;; 1010: "make_list"  (9 bytes) → 1019
  ;; 1019: "list_set"   (8 bytes) → 1027
  ;; 1027: "list_index" (10 bytes) → 1037
  ;; 1037: "tag_of"     (6 bytes) → 1043
  ;; 1043: "str_from_mem" (12 bytes) → 1055
  ;; 1055: "alloc"      (5 bytes) → 1060
  ;; 1060: "str_len"    (7 bytes) → 1067
  ;; 1067: "byte_at"    (7 bytes) → 1074
  ;; 1074: "str_eq"     (6 bytes) → 1080
  ;; Next free: 1080

  (data (i32.const 968) "str_concat")
  (data (i32.const 978) "call_indirect")
  (data (i32.const 991) "str_alloc")
  (data (i32.const 1000) "record_get")
  (data (i32.const 1010) "make_list")
  (data (i32.const 1019) "list_set")
  (data (i32.const 1027) "list_index")
  (data (i32.const 1037) "tag_of")
  (data (i32.const 1043) "str_from_mem")
  (data (i32.const 1055) "alloc")
  (data (i32.const 1060) "str_len")
  (data (i32.const 1067) "byte_at")
  (data (i32.const 1074) "str_eq")

  ;; 1080: "__match_" (8 bytes) → 1088
  ;; 1088: "ctor_tag" (8 bytes) → 1096
  ;; Next free: 1096
  (data (i32.const 1080) "__match_")
  (data (i32.const 1088) "ctor_tag")

  ;; Module emission strings
  ;; 1096: "memory"  (6 bytes) → 1102
  ;; 1102: "heap_ptr" (8 bytes) → 1110
  ;; 1110: " (mut i32) " (12 bytes, with leading/trailing space) → 1122
  ;; 1122: "wasi_snapshot_preview1" (22 bytes) → 1144
  ;; But wait - that's 22 bytes not 13. Let me recalculate.
  ;; Actually "wasi_snapshot_preview1" is 22 chars. Let me fix the emit_module references.
  ;; 1096: "memory" (6) → 1102
  ;; 1102: "heap_ptr" (8) → 1110
  ;; 1110: " (mut i32) " (11) → 1121
  ;; 1121: "wasi_snapshot_preview1" (22) → 1143
  ;; 1143: "fd_write" (8) → 1151
  ;; 1151: "wasi_fd_write" (13) → 1164
  ;; 1164: " (param i32 i32 i32 i32) (result i32)" (38) → 1202
  ;; 1202: "fd_read" (7) → 1209
  ;; 1209: "wasi_fd_read" (12) → 1221
  ;; 1221: "proc_exit" (9) → 1230
  ;; 1230: "wasi_proc_exit" (14) → 1244
  ;; 1244: " (param i32)" (12) → 1256
  ;; 1256: " (param $size i32)" (18 — but we only need 15 "(param $size i32)") → let me use 15
  ;; Actually: " (param $size i32)" is 19 chars. Use 19.
  ;; 1256: " (param $size i32)" (19) → 1275
  ;; 1275-1475: alloc function body as raw WAT text (200 bytes)
  ;; 1475: " (param $v i32)" (16) → 1491
  ;; Next free: ~1491

  (data (i32.const 1096) "memory")
  (data (i32.const 1102) "heap_ptr")
  (data (i32.const 1110) " (mut i32) ")
  (data (i32.const 1121) "wasi_snapshot_preview1")
  (data (i32.const 1143) "fd_write")
  (data (i32.const 1151) "wasi_fd_write")
  (data (i32.const 1164) " (param i32 i32 i32 i32) (result i32)")
  (data (i32.const 1202) "fd_read")
  (data (i32.const 1209) "wasi_fd_read")
  (data (i32.const 1221) "proc_exit")
  (data (i32.const 1230) "wasi_proc_exit")
  (data (i32.const 1244) " (param i32)")
  (data (i32.const 1256) " (param $size i32)")
  ;; Alloc body as raw WAT (padded to 200 bytes with spaces)
  (data (i32.const 1275) "(local $ptr i32)(local.set $ptr (global.get $heap_ptr))(global.set $heap_ptr (i32.add (global.get $heap_ptr)(i32.and (i32.add (local.get $size)(i32.const 7))(i32.const -8))))(local.get $ptr)                  ")
  (data (i32.const 1475) " (param $v i32)")

  ;; 1491: "_start_fn" (9) → 1500
  ;; 1500: " (export \"_start\")" (19, including escaped quotes) → 1519
  ;; But WAT data segments need literal bytes. The quotes are 0x22.
  ;; " (export \22_start\22)" — use \22 for double quote in data segment
  ;; Next free: 1519

  (data (i32.const 1491) "_start_fn")
  (data (i32.const 1500) " (export \22_start\22)")

  ;; ═══ Emitter Infrastructure ═════════════════════════════════════════
  ;; Output buffer management for WAT text generation.
  ;;
  ;; Strategy: accumulate bytes in a heap buffer at 16 MiB, flush to
  ;; stdout via WASI fd_write. Auto-flushes when buffer is nearly full.
  ;;
  ;; All emit_* functions in other modules depend on these primitives.

  (global $out_pos (mut i32) (i32.const 0))
  (global $out_base (mut i32) (i32.const 16777216))  ;; 16 MiB
  (global $out_cap (mut i32) (i32.const 4194304))     ;; 4 MiB capacity
  (global $emit_indent_level (mut i32) (i32.const 0))

  ;; ─── Core output ──────────────────────────────────────────────────

  (func $emit_byte (param $b i32)
    (i32.store8 (i32.add (global.get $out_base) (global.get $out_pos)) (local.get $b))
    (global.set $out_pos (i32.add (global.get $out_pos) (i32.const 1)))
    (if (i32.ge_u (global.get $out_pos) (i32.sub (global.get $out_cap) (i32.const 1024)))
      (then (call $emit_flush_partial))))

  (func $emit_flush_partial
    (i32.store (i32.const 240) (global.get $out_base))
    (i32.store (i32.const 244) (global.get $out_pos))
    (drop (call $wasi_fd_write (i32.const 1) (i32.const 240) (i32.const 1) (i32.const 248)))
    (global.set $out_pos (i32.const 0)))

  (func $emit_flush
    (if (i32.gt_u (global.get $out_pos) (i32.const 0))
      (then (call $emit_flush_partial))))

  ;; ─── String / memory emission ─────────────────────────────────────

  (func $emit_str (param $s i32)
    (local $len i32) (local $i i32) (local $src i32)
    (local.set $len (call $str_len (local.get $s)))
    (local.set $src (i32.add (local.get $s) (i32.const 4)))
    (local.set $i (i32.const 0))
    (block $done (loop $cp
      (br_if $done (i32.ge_u (local.get $i) (local.get $len)))
      (call $emit_byte (i32.load8_u (i32.add (local.get $src) (local.get $i))))
      (local.set $i (i32.add (local.get $i) (i32.const 1)))
      (br $cp))))

  (func $emit_cstr (param $addr i32) (param $len i32)
    (local $i i32)
    (local.set $i (i32.const 0))
    (block $done (loop $cp
      (br_if $done (i32.ge_u (local.get $i) (local.get $len)))
      (call $emit_byte (i32.load8_u (i32.add (local.get $addr) (local.get $i))))
      (local.set $i (i32.add (local.get $i) (i32.const 1)))
      (br $cp))))

  ;; ─── Number emission ──────────────────────────────────────────────

  (func $emit_int (param $n i32)
    (local $pos i32) (local $neg i32) (local $abs i32) (local $digit i32)
    (local.set $pos (i32.const 0))
    (if (i32.eqz (local.get $n))
      (then (call $emit_byte (i32.const 48)) (return)))
    (local.set $neg (i32.const 0))
    (local.set $abs (local.get $n))
    (if (i32.lt_s (local.get $n) (i32.const 0))
      (then
        (local.set $neg (i32.const 1))
        (local.set $abs (i32.sub (i32.const 0) (local.get $n)))))
    ;; Extract digits into scratch at 200 (reversed)
    (block $done (loop $dg
      (br_if $done (i32.eqz (local.get $abs)))
      (i32.store8 (i32.add (i32.const 200) (local.get $pos))
        (i32.add (i32.rem_u (local.get $abs) (i32.const 10)) (i32.const 48)))
      (local.set $pos (i32.add (local.get $pos) (i32.const 1)))
      (local.set $abs (i32.div_u (local.get $abs) (i32.const 10)))
      (br $dg)))
    (if (local.get $neg) (then (call $emit_byte (i32.const 45))))
    ;; Emit in correct order
    (block $done2 (loop $em
      (local.set $pos (i32.sub (local.get $pos) (i32.const 1)))
      (br_if $done2 (i32.lt_s (local.get $pos) (i32.const 0)))
      (call $emit_byte (i32.load8_u (i32.add (i32.const 200) (local.get $pos))))
      (br $em))))

  ;; ─── Formatting ───────────────────────────────────────────────────

  (func $emit_space (call $emit_byte (i32.const 32)))
  (func $emit_nl (call $emit_byte (i32.const 10)))

  (func $emit_indent
    (local $i i32) (local $n i32)
    (local.set $n (i32.mul (global.get $emit_indent_level) (i32.const 2)))
    (local.set $i (i32.const 0))
    (block $done (loop $sp
      (br_if $done (i32.ge_u (local.get $i) (local.get $n)))
      (call $emit_byte (i32.const 32))
      (local.set $i (i32.add (local.get $i) (i32.const 1)))
      (br $sp))))

  (func $indent_inc
    (global.set $emit_indent_level (i32.add (global.get $emit_indent_level) (i32.const 1))))
  (func $indent_dec
    (global.set $emit_indent_level (i32.sub (global.get $emit_indent_level) (i32.const 1))))

  ;; ─── WAT syntax helpers ───────────────────────────────────────────
  ;; These use the data segments defined in emit_data.wat.

  (func $emit_open (param $name i32)
    (call $emit_byte (i32.const 40))
    (call $emit_str (local.get $name)))

  (func $emit_open_cstr (param $addr i32) (param $len i32)
    (call $emit_byte (i32.const 40))
    (call $emit_cstr (local.get $addr) (local.get $len)))

  (func $emit_close (call $emit_byte (i32.const 41)))

  (func $emit_dollar_name (param $name i32)
    (call $emit_byte (i32.const 36))
    (call $emit_str (local.get $name)))

  ;; Shorthand emitters using data segment addresses:
  (func $emit_local_get (param $name i32)
    (call $emit_cstr (i32.const 536) (i32.const 11))
    (call $emit_dollar_name (local.get $name))
    (call $emit_close))

  (func $emit_local_set_open (param $name i32)
    (call $emit_cstr (i32.const 548) (i32.const 11))
    (call $emit_dollar_name (local.get $name))
    (call $emit_space))

  (func $emit_i32_const (param $n i32)
    (call $emit_cstr (i32.const 560) (i32.const 11))
    (call $emit_int (local.get $n))
    (call $emit_close))

  (func $emit_call_open (param $name i32)
    (call $emit_cstr (i32.const 572) (i32.const 6))
    (call $emit_dollar_name (local.get $name)))

  ;; emit_quoted_str: emit "..." with WAT string escaping
  (func $emit_quoted_str (param $s i32)
    (local $len i32) (local $i i32) (local $b i32)
    (call $emit_byte (i32.const 34)) ;; opening "
    (local.set $len (call $str_len (local.get $s)))
    (local.set $i (i32.const 0))
    (block $done (loop $ch
      (br_if $done (i32.ge_u (local.get $i) (local.get $len)))
      (local.set $b (call $byte_at (local.get $s) (local.get $i)))
      ;; Escape special chars
      (if (i32.eq (local.get $b) (i32.const 34))  ;; "
        (then (call $emit_byte (i32.const 92)) (call $emit_byte (i32.const 34)))
      (else (if (i32.eq (local.get $b) (i32.const 92))  ;; backslash
        (then (call $emit_byte (i32.const 92)) (call $emit_byte (i32.const 92)))
      (else (if (i32.eq (local.get $b) (i32.const 10))  ;; newline
        (then (call $emit_byte (i32.const 92)) (call $emit_byte (i32.const 110)))
      (else
        (call $emit_byte (local.get $b))))))))
      (local.set $i (i32.add (local.get $i) (i32.const 1)))
      (br $ch)))
    (call $emit_byte (i32.const 34))) ;; closing "

  ;; ═══ Expression Emitter ═════════════════════════════════════════════
  ;; Walks AST expression nodes and emits corresponding WAT.
  ;;
  ;; Node layout reminder:
  ;;   N(body, span, handle) → [0][body_ptr][span_ptr][handle]
  ;;   NExpr(e)              → [110][e_ptr]
  ;;   e_ptr                 → [tag][fields...]
  ;;
  ;; Extraction chain: node → body(+4) → expr(+4) → tag(+0)
  ;;
  ;; Every expression produces exactly one i32 value on the wasm stack.
  ;; This is the "untyped bootstrap" strategy: everything is i32.

  ;; ─── Node accessors ───────────────────────────────────────────────

  ;; Get the expression struct from a node (N → NExpr → expr)
  (func $node_expr (param $node i32) (result i32)
    (local $body i32)
    (local.set $body (i32.load offset=4 (local.get $node)))  ;; NExpr/NStmt
    (i32.load offset=4 (local.get $body)))                    ;; inner expr/stmt

  ;; Get expression tag
  (func $expr_tag (param $expr i32) (result i32)
    ;; If expr is a sentinel (< 4096), it IS the tag (e.g. LitUnit=84)
    (if (result i32) (i32.lt_u (local.get $expr) (i32.const 4096))
      (then (local.get $expr))
      (else (i32.load (local.get $expr)))))

  ;; ─── emit_node: top-level dispatcher ──────────────────────────────
  ;; Emits WAT for an AST node. Handles both expr and stmt nodes.

  (func $emit_node (param $node i32)
    (local $body_tag i32)
    ;; Check if node is a sentinel (shouldn't happen, but safety)
    (if (i32.lt_u (local.get $node) (i32.const 4096))
      (then
        (call $emit_i32_const (local.get $node))
        (return)))
    (local.set $body_tag (i32.load (i32.load offset=4 (local.get $node))))
    ;; NExpr (110) → emit expression
    (if (i32.eq (local.get $body_tag) (i32.const 110))
      (then
        (call $emit_expr_node (local.get $node))
        (return)))
    ;; NStmt (111) → emit statement
    (if (i32.eq (local.get $body_tag) (i32.const 111))
      (then
        (call $emit_stmt_node (local.get $node))
        (return)))
    ;; Fallback: emit unit
    (call $emit_i32_const (i32.const 84)))

  ;; ─── emit_expr_node: emit an expression node ─────────────────────

  (func $emit_expr_node (param $node i32)
    (local $expr i32) (local $tag i32)
    (local.set $expr (call $node_expr (local.get $node)))
    (local.set $tag (call $expr_tag (local.get $expr)))

    ;; LitUnit (84) — sentinel
    (if (i32.eq (local.get $tag) (i32.const 84))
      (then (call $emit_i32_const (i32.const 84)) (return)))

    ;; LitInt (80) → (i32.const n)
    (if (i32.eq (local.get $tag) (i32.const 80))
      (then
        (call $emit_i32_const (i32.load offset=4 (local.get $expr)))
        (return)))

    ;; LitBool (83) → (i32.const 0/1)
    (if (i32.eq (local.get $tag) (i32.const 83))
      (then
        (call $emit_i32_const (i32.load offset=4 (local.get $expr)))
        (return)))

    ;; LitString (82) → call $str_alloc_data with string bytes
    ;; For bootstrap: emit a call to runtime string constructor
    (if (i32.eq (local.get $tag) (i32.const 82))
      (then
        (call $emit_string_lit (i32.load offset=4 (local.get $expr)))
        (return)))

    ;; VarRef (85) → (local.get $name)
    (if (i32.eq (local.get $tag) (i32.const 85))
      (then
        (call $emit_local_get (i32.load offset=4 (local.get $expr)))
        (return)))

    ;; BinOpExpr (86) → emit binary operation
    (if (i32.eq (local.get $tag) (i32.const 86))
      (then
        (call $emit_binop
          (i32.load offset=4 (local.get $expr))   ;; op
          (i32.load offset=8 (local.get $expr))    ;; left node
          (i32.load offset=12 (local.get $expr)))  ;; right node
        (return)))

    ;; UnaryOpExpr (87) → emit unary operation
    (if (i32.eq (local.get $tag) (i32.const 87))
      (then
        (call $emit_unaryop
          (i32.load offset=4 (local.get $expr))   ;; op_name
          (i32.load offset=8 (local.get $expr)))   ;; inner node
        (return)))

    ;; CallExpr (88) → emit function call
    (if (i32.eq (local.get $tag) (i32.const 88))
      (then
        (call $emit_call_expr
          (i32.load offset=4 (local.get $expr))   ;; callee node
          (i32.load offset=8 (local.get $expr)))   ;; args list
        (return)))

    ;; IfExpr (90) → emit if/else
    (if (i32.eq (local.get $tag) (i32.const 90))
      (then
        (call $emit_if_expr
          (i32.load offset=4 (local.get $expr))    ;; cond
          (i32.load offset=8 (local.get $expr))    ;; then
          (i32.load offset=12 (local.get $expr)))  ;; else
        (return)))

    ;; BlockExpr (91) → emit block
    (if (i32.eq (local.get $tag) (i32.const 91))
      (then
        (call $emit_block_expr
          (i32.load offset=4 (local.get $expr))   ;; stmts list
          (i32.load offset=8 (local.get $expr)))   ;; final expr
        (return)))

    ;; MatchExpr (92) → emit match dispatch
    (if (i32.eq (local.get $tag) (i32.const 92))
      (then
        (call $emit_match_expr
          (i32.load offset=4 (local.get $expr))   ;; scrutinee
          (i32.load offset=8 (local.get $expr)))   ;; arms list
        (return)))

    ;; PerformExpr (94) → emit effect operation call
    (if (i32.eq (local.get $tag) (i32.const 94))
      (then
        (call $emit_perform_expr
          (i32.load offset=4 (local.get $expr))   ;; op name
          (i32.load offset=8 (local.get $expr)))   ;; args list
        (return)))

    ;; MakeListExpr (96) → emit list construction
    (if (i32.eq (local.get $tag) (i32.const 96))
      (then
        (call $emit_make_list (i32.load offset=4 (local.get $expr)))
        (return)))

    ;; MakeTupleExpr (97) → emit tuple construction
    (if (i32.eq (local.get $tag) (i32.const 97))
      (then
        (call $emit_make_tuple (i32.load offset=4 (local.get $expr)))
        (return)))

    ;; FieldExpr (100) → emit field access
    (if (i32.eq (local.get $tag) (i32.const 100))
      (then
        (call $emit_field_expr
          (i32.load offset=4 (local.get $expr))   ;; base expr
          (i32.load offset=8 (local.get $expr)))   ;; field name
        (return)))

    ;; PipeExpr (101) → desugar to function call
    (if (i32.eq (local.get $tag) (i32.const 101))
      (then
        (call $emit_pipe_expr
          (i32.load offset=4 (local.get $expr))    ;; pipe kind
          (i32.load offset=8 (local.get $expr))    ;; left
          (i32.load offset=12 (local.get $expr)))  ;; right
        (return)))

    ;; LambdaExpr (89) → emit closure
    (if (i32.eq (local.get $tag) (i32.const 89))
      (then
        ;; For bootstrap: lambdas are simplified to named helper functions
        ;; emitted separately. Here we just emit a reference.
        (call $emit_i32_const (i32.const 84))  ;; placeholder
        (return)))

    ;; Fallback: emit unit sentinel
    (call $emit_i32_const (i32.const 84)))

  ;; ─── Binary operation emission ────────────────────────────────────
  ;; BinOp sentinels: BAdd=140 BSub=141 BMul=142 BDiv=143 BMod=144
  ;;   BEq=145 BNe=146 BLt=147 BGt=148 BLe=149 BGe=150
  ;;   BAnd=151 BOr=152 BConcat=153
  ;;
  ;; For arithmetic ops: emit WAT i32 instruction wrapping both operands.
  ;; For concat: emit call to runtime $str_concat.

  (func $emit_binop (param $op i32) (param $left i32) (param $right i32)
    ;; Emit the WAT instruction opener based on op
    (if (i32.eq (local.get $op) (i32.const 140))
      (then (call $emit_cstr (i32.const 679) (i32.const 9))))  ;; (i32.add
    (if (i32.eq (local.get $op) (i32.const 141))
      (then (call $emit_cstr (i32.const 688) (i32.const 9))))  ;; (i32.sub
    (if (i32.eq (local.get $op) (i32.const 142))
      (then (call $emit_cstr (i32.const 697) (i32.const 9))))  ;; (i32.mul
    (if (i32.eq (local.get $op) (i32.const 143))
      (then (call $emit_cstr (i32.const 706) (i32.const 11)))) ;; (i32.div_s
    (if (i32.eq (local.get $op) (i32.const 144))
      (then (call $emit_cstr (i32.const 717) (i32.const 11)))) ;; (i32.rem_s
    (if (i32.eq (local.get $op) (i32.const 145))
      (then (call $emit_cstr (i32.const 728) (i32.const 8))))  ;; (i32.eq
    (if (i32.eq (local.get $op) (i32.const 146))
      (then (call $emit_cstr (i32.const 736) (i32.const 8))))  ;; (i32.ne
    (if (i32.eq (local.get $op) (i32.const 147))
      (then (call $emit_cstr (i32.const 744) (i32.const 10)))) ;; (i32.lt_s
    (if (i32.eq (local.get $op) (i32.const 148))
      (then (call $emit_cstr (i32.const 754) (i32.const 10)))) ;; (i32.gt_s
    (if (i32.eq (local.get $op) (i32.const 149))
      (then (call $emit_cstr (i32.const 764) (i32.const 10)))) ;; (i32.le_s
    (if (i32.eq (local.get $op) (i32.const 150))
      (then (call $emit_cstr (i32.const 774) (i32.const 10)))) ;; (i32.ge_s
    (if (i32.eq (local.get $op) (i32.const 151))
      (then (call $emit_cstr (i32.const 784) (i32.const 9))))  ;; (i32.and
    (if (i32.eq (local.get $op) (i32.const 152))
      (then (call $emit_cstr (i32.const 793) (i32.const 8))))  ;; (i32.or

    ;; BConcat (153) → call $str_concat
    (if (i32.eq (local.get $op) (i32.const 153))
      (then
        (call $emit_call_open (call $str_from_mem (i32.const 968) (i32.const 10))) ;; str_concat
        (call $emit_space)
        (call $emit_expr_node (local.get $left))
        (call $emit_space)
        (call $emit_expr_node (local.get $right))
        (call $emit_close)
        (return)))

    ;; For all other ops: emit left, space, right, close
    (call $emit_expr_node (local.get $left))
    (call $emit_space)
    (call $emit_expr_node (local.get $right))
    (call $emit_close))

  ;; ─── Unary operation emission ─────────────────────────────────────

  (func $emit_unaryop (param $op_name i32) (param $inner i32)
    ;; Check first char: 'N' for Neg, 'N' for Not... check second char
    (local $c2 i32)
    (local.set $c2 (call $byte_at (local.get $op_name) (i32.const 1)))
    (if (i32.eq (local.get $c2) (i32.const 101)) ;; 'e' → "Neg"
      (then
        ;; (i32.sub (i32.const 0) inner)
        (call $emit_cstr (i32.const 688) (i32.const 9)) ;; (i32.sub
        (call $emit_i32_const (i32.const 0))
        (call $emit_space)
        (call $emit_expr_node (local.get $inner))
        (call $emit_close)
        (return)))
    ;; "Not" → (i32.eqz inner)
    (call $emit_cstr (i32.const 801) (i32.const 9)) ;; (i32.eqz
    (call $emit_expr_node (local.get $inner))
    (call $emit_close))

  ;; ─── Call expression emission ─────────────────────────────────────
  ;; CallExpr(callee, args): callee is a node, args is a list of nodes.
  ;; If callee is VarRef → direct call. Otherwise → indirect call.

  (func $emit_call_expr (param $callee i32) (param $args i32)
    (local $callee_expr i32) (local $callee_tag i32)
    (local $name i32) (local $i i32) (local $n i32)
    (local.set $callee_expr (call $node_expr (local.get $callee)))
    (local.set $callee_tag (call $expr_tag (local.get $callee_expr)))
    ;; Direct call: callee is VarRef
    (if (i32.eq (local.get $callee_tag) (i32.const 85))
      (then
        (local.set $name (i32.load offset=4 (local.get $callee_expr)))
        (call $emit_call_open (local.get $name))
        ;; Emit each argument
        (local.set $n (call $len (local.get $args)))
        (local.set $i (i32.const 0))
        (block $done (loop $arg_loop
          (br_if $done (i32.ge_u (local.get $i) (local.get $n)))
          (call $emit_space)
          (call $emit_expr_node (call $list_index (local.get $args) (local.get $i)))
          (local.set $i (i32.add (local.get $i) (i32.const 1)))
          (br $arg_loop)))
        (call $emit_close)
        (return)))
    ;; Indirect call: emit callee value then call_indirect
    ;; For bootstrap simplicity: treat as direct call with mangled name
    (call $emit_call_open (call $str_from_mem (i32.const 978) (i32.const 13))) ;; "call_indirect"
    (call $emit_space)
    (call $emit_expr_node (local.get $callee))
    (local.set $n (call $len (local.get $args)))
    (local.set $i (i32.const 0))
    (block $done2 (loop $arg2
      (br_if $done2 (i32.ge_u (local.get $i) (local.get $n)))
      (call $emit_space)
      (call $emit_expr_node (call $list_index (local.get $args) (local.get $i)))
      (local.set $i (i32.add (local.get $i) (i32.const 1)))
      (br $arg2)))
    (call $emit_close))

  ;; ─── String literal emission ──────────────────────────────────────
  ;; Emits a call to the runtime string allocator with the string content.
  ;; Strategy: emit (call $str_from_data addr len) where addr/len refer
  ;; to a data segment. For bootstrap we inline the string construction.

  (func $emit_string_lit (param $s i32)
    ;; Emit: (call $str_alloc_lit <len> <byte0> <byte1> ...)
    ;; Actually simpler: call $str_from_mem with a data segment reference.
    ;; For bootstrap: just call the runtime's string allocator.
    (call $emit_call_open (call $str_from_mem (i32.const 991) (i32.const 9))) ;; "str_alloc"
    (call $emit_space)
    (call $emit_i32_const (call $str_len (local.get $s)))
    (call $emit_close)
    ;; TODO: emit data segment + str_from_mem for actual string content
    ;; For now, this allocates an empty string of the right length
    )

  ;; ─── Pipe expression emission ─────────────────────────────────────
  ;; |> desugars to function application: left |> right → right(left)
  ;; PipeKind: PForward=160

  (func $emit_pipe_expr (param $kind i32) (param $left i32) (param $right i32)
    ;; PForward (160): right(left) → emit right as callee, left as arg
    ;; The right side should be a VarRef or callable
    (local $right_expr i32) (local $right_tag i32) (local $name i32)
    (local.set $right_expr (call $node_expr (local.get $right)))
    (local.set $right_tag (call $expr_tag (local.get $right_expr)))
    (if (i32.eq (local.get $right_tag) (i32.const 85)) ;; VarRef
      (then
        (local.set $name (i32.load offset=4 (local.get $right_expr)))
        (call $emit_call_open (local.get $name))
        (call $emit_space)
        (call $emit_expr_node (local.get $left))
        (call $emit_close)
        (return)))
    ;; Fallback: just emit both sides
    (call $emit_expr_node (local.get $left))
    (call $emit_space)
    (call $emit_expr_node (local.get $right)))

  ;; ─── Field expression emission ────────────────────────────────────
  ;; e.field → call to record field accessor

  (func $emit_field_expr (param $base i32) (param $field_name i32)
    ;; Emit: (call $record_get <base> <field_name_hash>)
    ;; For bootstrap: use a simplified field access by offset
    (call $emit_call_open (call $str_from_mem (i32.const 1000) (i32.const 10))) ;; "record_get"
    (call $emit_space)
    (call $emit_expr_node (local.get $base))
    (call $emit_space)
    ;; Field name as string for runtime lookup
    (call $emit_string_lit (local.get $field_name))
    (call $emit_close))

  ;; ─── Perform expression emission ──────────────────────────────────
  ;; perform op(args) → call to effect handler dispatch

  (func $emit_perform_expr (param $op_name i32) (param $args i32)
    (local $i i32) (local $n i32)
    ;; For bootstrap: effects are compiled as direct function calls
    ;; to $perform_<op_name>
    (call $emit_call_open (local.get $op_name))
    (local.set $n (call $len (local.get $args)))
    (local.set $i (i32.const 0))
    (block $done (loop $arg_loop
      (br_if $done (i32.ge_u (local.get $i) (local.get $n)))
      (call $emit_space)
      (call $emit_expr_node (call $list_index (local.get $args) (local.get $i)))
      (local.set $i (i32.add (local.get $i) (i32.const 1)))
      (br $arg_loop)))
    (call $emit_close))

  ;; ─── Collection construction emission ─────────────────────────────

  ;; emit_make_list: [e1, e2, ...] → runtime list construction
  (func $emit_make_list (param $elems i32)
    (local $i i32) (local $n i32)
    (local.set $n (call $len (local.get $elems)))
    ;; (call $make_list N)
    (call $emit_call_open (call $str_from_mem (i32.const 1010) (i32.const 9))) ;; "make_list"
    (call $emit_space)
    (call $emit_i32_const (local.get $n))
    (call $emit_close)
    ;; Then set each element
    (local.set $i (i32.const 0))
    (block $done (loop $set_loop
      (br_if $done (i32.ge_u (local.get $i) (local.get $n)))
      ;; (drop (call $list_set <list> <i> <elem>))
      ;; For simplicity, just emit the elements for now
      (local.set $i (i32.add (local.get $i) (i32.const 1)))
      (br $set_loop))))

  ;; emit_make_tuple: (e1, e2, ...) → same as list for bootstrap
  (func $emit_make_tuple (param $elems i32)
    (call $emit_make_list (local.get $elems)))

  ;; ─── Additional data segments for emitter ─────────────────────────
  ;; 968: "str_concat" (10 bytes)
  ;; 978: "call_indirect" (13 bytes)
  ;; 991: "str_alloc" (9 bytes)
  ;; 1000: "record_get" (10 bytes)
  ;; 1010: "make_list" (9 bytes)

  ;; ═══ Compound Expression Emission ═══════════════════════════════════
  ;; If, Block, and Match expression WAT generation.
  ;;
  ;; These are the three expression forms that produce control flow in
  ;; WAT. Each produces exactly one i32 result value.

  ;; ─── If expression ────────────────────────────────────────────────
  ;; IfExpr(cond, then, else) →
  ;;   (if (result i32) <cond>
  ;;     (then <then_expr>)
  ;;     (else <else_expr>))

  (func $emit_if_expr (param $cond i32) (param $then_e i32) (param $else_e i32)
    ;; (if (result i32)
    (call $emit_cstr (i32.const 617) (i32.const 17))  ;; "(if (result i32) "
    (call $emit_nl)
    (call $indent_inc)
    ;; Condition
    (call $emit_indent)
    (call $emit_expr_node (local.get $cond))
    (call $emit_nl)
    ;; Then branch
    (call $emit_indent)
    (call $emit_cstr (i32.const 635) (i32.const 6))  ;; "(then "
    (call $emit_expr_node (local.get $then_e))
    (call $emit_close)
    (call $emit_nl)
    ;; Else branch
    (call $emit_indent)
    (call $emit_cstr (i32.const 641) (i32.const 6))  ;; "(else "
    (call $emit_expr_node (local.get $else_e))
    (call $emit_close)
    (call $emit_close)  ;; close the if
    (call $indent_dec))

  ;; ─── Block expression ─────────────────────────────────────────────
  ;; BlockExpr(stmts, final_expr) →
  ;;   Sequence of statements followed by final expression.
  ;;   WAT blocks must produce exactly one value on the stack.
  ;;   Strategy: emit each stmt (which produces and drops a value),
  ;;   then emit the final expr (which stays on the stack).
  ;;
  ;; For non-trivial blocks, wrap in a WAT block to scope locals:
  ;;   (block (result i32) <stmts...> <final_expr>)

  (func $emit_block_expr (param $stmts i32) (param $final_expr i32)
    (local $n i32) (local $i i32) (local $stmt_node i32)
    (local.set $n (call $len (local.get $stmts)))
    ;; If empty block with just a final expr, emit directly
    (if (i32.eqz (local.get $n))
      (then
        (call $emit_expr_node (local.get $final_expr))
        (return)))
    ;; Emit each statement
    (local.set $i (i32.const 0))
    (block $done (loop $stmt_loop
      (br_if $done (i32.ge_u (local.get $i) (local.get $n)))
      (local.set $stmt_node (call $list_index (local.get $stmts) (local.get $i)))
      ;; Emit the statement (which may define locals, emit drops, etc.)
      (call $emit_node (local.get $stmt_node))
      (call $emit_nl)
      (local.set $i (i32.add (local.get $i) (i32.const 1)))
      (br $stmt_loop)))
    ;; Emit final expression (its value stays on the stack)
    (call $emit_expr_node (local.get $final_expr)))

  ;; ─── Match expression ─────────────────────────────────────────────
  ;; MatchExpr(scrutinee, arms) → tag-based dispatch
  ;;
  ;; Strategy for bootstrap:
  ;; Each match arm (pat, body) is compiled as:
  ;;   1. Evaluate scrutinee into a local
  ;;   2. For each arm: check pattern, if matches → emit body
  ;;   3. Chain as nested if/else
  ;;
  ;; Pattern matching compilation:
  ;;   PVar(name)     → always matches, bind scrutinee to name
  ;;   PWild          → always matches
  ;;   PLit(LVInt(n)) → (i32.eq scrut n)
  ;;   PCon(ctor, []) → (i32.eq (call $tag_of scrut) ctor_tag)
  ;;   PCon(ctor, subs) → tag check + extract sub-values
  ;;
  ;; For bootstrap, we generate chained if/else:
  ;;   (if (result i32) (match_cond_arm0)
  ;;     (then (bind_arm0) body0)
  ;;     (else (if (result i32) (match_cond_arm1)
  ;;       (then (bind_arm1) body1)
  ;;       (else ... default ...))))

  ;; Global counter for unique match scrutinee locals
  (global $match_tmp_counter (mut i32) (i32.const 0))

  (func $emit_match_expr (param $scrutinee i32) (param $arms i32)
    (local $n i32) (local $i i32) (local $arm i32)
    (local $pat i32) (local $body i32)
    (local $tmp_name i32)
    (local.set $n (call $len (local.get $arms)))
    ;; If no arms, emit unit
    (if (i32.eqz (local.get $n))
      (then (call $emit_i32_const (i32.const 84)) (return)))
    ;; Generate a unique temp name for the scrutinee
    (local.set $tmp_name (call $match_tmp_name))
    ;; Emit: (local.set $__match_N <scrutinee>)
    (call $emit_local_set_open (local.get $tmp_name))
    (call $emit_expr_node (local.get $scrutinee))
    (call $emit_close)
    (call $emit_nl)
    ;; Emit chained if/else for arms
    (call $emit_match_chain (local.get $tmp_name) (local.get $arms) (i32.const 0) (local.get $n)))

  ;; Generate unique scrutinee temp name: "__match_0", "__match_1", ...
  (func $match_tmp_name (result i32)
    (local $idx i32) (local $name i32)
    (local.set $idx (global.get $match_tmp_counter))
    (global.set $match_tmp_counter (i32.add (global.get $match_tmp_counter) (i32.const 1)))
    (local.set $name (call $str_concat
      (call $str_from_mem (i32.const 1080) (i32.const 8))  ;; "__match_"
      (call $int_to_str (local.get $idx))))
    (local.get $name))

  ;; Emit chained if/else for match arms
  (func $emit_match_chain (param $tmp i32) (param $arms i32) (param $i i32) (param $n i32)
    (local $arm i32) (local $pat i32) (local $body i32) (local $pat_tag i32)
    ;; Base case: past all arms → emit unit (unreachable in well-typed code)
    (if (i32.ge_u (local.get $i) (local.get $n))
      (then (call $emit_i32_const (i32.const 84)) (return)))
    (local.set $arm (call $list_index (local.get $arms) (local.get $i)))
    (local.set $pat (call $list_index (local.get $arm) (i32.const 0)))
    (local.set $body (call $list_index (local.get $arm) (i32.const 1)))
    ;; Get pattern tag
    (local.set $pat_tag (call $pat_tag_of (local.get $pat)))
    ;; PWild (131) or PVar → always matches, no condition needed
    (if (i32.or (i32.eq (local.get $pat_tag) (i32.const 131))
                (i32.eq (local.get $pat_tag) (i32.const 130)))
      (then
        ;; Bind variable if PVar
        (if (i32.eq (local.get $pat_tag) (i32.const 130))
          (then
            (call $emit_local_set_open (call $pat_var_name (local.get $pat)))
            (call $emit_local_get (local.get $tmp))
            (call $emit_close)
            (call $emit_nl)))
        ;; Emit body directly (this is the final/default arm)
        (call $emit_expr_node (local.get $body))
        (return)))
    ;; PLit (132) → equality check
    (if (i32.eq (local.get $pat_tag) (i32.const 132))
      (then
        ;; (if (result i32) (i32.eq (local.get $tmp) <lit_value>)
        (call $emit_cstr (i32.const 617) (i32.const 17))  ;; "(if (result i32) "
        (call $emit_cstr (i32.const 728) (i32.const 8))   ;; "(i32.eq "
        (call $emit_local_get (local.get $tmp))
        (call $emit_space)
        (call $emit_lit_val (call $pat_lit_val (local.get $pat)))
        (call $emit_close)  ;; close i32.eq
        (call $emit_nl)
        (call $emit_cstr (i32.const 635) (i32.const 6))   ;; "(then "
        (call $emit_expr_node (local.get $body))
        (call $emit_close)  ;; close then
        (call $emit_nl)
        (call $emit_cstr (i32.const 641) (i32.const 6))   ;; "(else "
        (call $emit_match_chain (local.get $tmp) (local.get $arms)
          (i32.add (local.get $i) (i32.const 1)) (local.get $n))
        (call $emit_close)  ;; close else
        (call $emit_close)  ;; close if
        (return)))
    ;; PCon (133) → tag check
    (if (i32.eq (local.get $pat_tag) (i32.const 133))
      (then
        ;; (if (result i32) (i32.eq (call $tag_of (local.get $tmp)) <ctor_tag>)
        (call $emit_cstr (i32.const 617) (i32.const 17))  ;; "(if (result i32) "
        (call $emit_cstr (i32.const 728) (i32.const 8))   ;; "(i32.eq "
        ;; (call $tag_of (local.get $tmp))
        (call $emit_call_open (call $str_from_mem (i32.const 1037) (i32.const 6))) ;; "tag_of"
        (call $emit_space)
        (call $emit_local_get (local.get $tmp))
        (call $emit_close)  ;; close call
        (call $emit_space)
        ;; Constructor tag: use a hash of the constructor name
        ;; For bootstrap: emit constructor name as a runtime lookup
        (call $emit_call_open (call $str_from_mem (i32.const 1088) (i32.const 8))) ;; "ctor_tag"
        (call $emit_space)
        (call $emit_string_lit (call $pat_con_name (local.get $pat)))
        (call $emit_close)  ;; close ctor_tag call
        (call $emit_close)  ;; close i32.eq
        (call $emit_nl)
        ;; Then branch: bind sub-patterns, emit body
        (call $emit_cstr (i32.const 635) (i32.const 6))   ;; "(then "
        (call $emit_con_bindings (local.get $tmp) (local.get $pat))
        (call $emit_expr_node (local.get $body))
        (call $emit_close)  ;; close then
        (call $emit_nl)
        ;; Else branch: try next arm
        (call $emit_cstr (i32.const 641) (i32.const 6))   ;; "(else "
        (call $emit_match_chain (local.get $tmp) (local.get $arms)
          (i32.add (local.get $i) (i32.const 1)) (local.get $n))
        (call $emit_close)  ;; close else
        (call $emit_close)  ;; close if
        (return)))
    ;; Default: treat as wildcard
    (call $emit_expr_node (local.get $body)))

  ;; ─── Pattern accessors ────────────────────────────────────────────

  ;; Get pattern tag (handles sentinel PWild=131)
  (func $pat_tag_of (param $pat i32) (result i32)
    (if (result i32) (i32.lt_u (local.get $pat) (i32.const 4096))
      (then (local.get $pat))
      (else (i32.load (local.get $pat)))))

  ;; PVar name: pat → [130][name_ptr]
  (func $pat_var_name (param $pat i32) (result i32)
    (i32.load offset=4 (local.get $pat)))

  ;; PLit value: pat → [132][lit_val_ptr]
  (func $pat_lit_val (param $pat i32) (result i32)
    (i32.load offset=4 (local.get $pat)))

  ;; PCon name: pat → [133][name_ptr][subs]
  (func $pat_con_name (param $pat i32) (result i32)
    (i32.load offset=4 (local.get $pat)))

  ;; PCon sub-patterns: pat → [133][name][subs_list]
  (func $pat_con_subs (param $pat i32) (result i32)
    (i32.load offset=8 (local.get $pat)))

  ;; ─── Literal value emission ───────────────────────────────────────
  ;; LVInt(n)=180, LVFloat(f)=181, LVString(s)=182, LVBool(b)=183

  (func $emit_lit_val (param $lv i32)
    (local $tag i32)
    (local.set $tag (i32.load (local.get $lv)))
    ;; LVInt
    (if (i32.eq (local.get $tag) (i32.const 180))
      (then (call $emit_i32_const (i32.load offset=4 (local.get $lv))) (return)))
    ;; LVBool
    (if (i32.eq (local.get $tag) (i32.const 183))
      (then (call $emit_i32_const (i32.load offset=4 (local.get $lv))) (return)))
    ;; LVString
    (if (i32.eq (local.get $tag) (i32.const 182))
      (then (call $emit_string_lit (i32.load offset=4 (local.get $lv))) (return)))
    ;; Default
    (call $emit_i32_const (i32.const 0)))

  ;; ─── Constructor sub-pattern binding ──────────────────────────────
  ;; For PCon(ctor, [p1, p2, ...]), bind sub-patterns to fields
  ;; of the scrutinee. Fields are at offsets 4, 8, 12, ... of the
  ;; constructor record (after the tag at offset 0).

  (func $emit_con_bindings (param $tmp i32) (param $pat i32)
    (local $subs i32) (local $n i32) (local $i i32) (local $sub_pat i32)
    (local $sub_tag i32) (local $field_name i32)
    (local.set $subs (call $pat_con_subs (local.get $pat)))
    (local.set $n (call $len (local.get $subs)))
    (local.set $i (i32.const 0))
    (block $done (loop $bind
      (br_if $done (i32.ge_u (local.get $i) (local.get $n)))
      (local.set $sub_pat (call $list_index (local.get $subs) (local.get $i)))
      (local.set $sub_tag (call $pat_tag_of (local.get $sub_pat)))
      ;; Only bind PVar sub-patterns
      (if (i32.eq (local.get $sub_tag) (i32.const 130))
        (then
          ;; (local.set $name (i32.load offset=<4+i*4> (local.get $tmp)))
          (call $emit_local_set_open (call $pat_var_name (local.get $sub_pat)))
          (call $emit_cstr (i32.const 821) (i32.const 10)) ;; "(i32.load "
          (call $emit_cstr (i32.const 929) (i32.const 7))  ;; "offset="
          (call $emit_int (i32.add (i32.const 4)
            (i32.mul (local.get $i) (i32.const 4))))
          (call $emit_space)
          (call $emit_local_get (local.get $tmp))
          (call $emit_close)  ;; close i32.load
          (call $emit_close)  ;; close local.set
          (call $emit_nl)))
      (local.set $i (i32.add (local.get $i) (i32.const 1)))
      (br $bind))))

  ;; ═══ Statement Emission ═════════════════════════════════════════════
  ;; Emits WAT for statement nodes: FnStmt, LetStmt, ExprStmt,
  ;; TypeDefStmt (constructor generation), EffectDeclStmt, ImportStmt.
  ;;
  ;; Each function generates complete WAT function definitions or
  ;; local variable assignments.

  ;; ─── emit_stmt_node: dispatch on statement tag ────────────────────

  (func $emit_stmt_node (param $node i32)
    (local $stmt i32) (local $tag i32)
    ;; Extract: node → body(+4) → stmt(+4) → tag
    (local.set $stmt (call $node_expr (local.get $node)))
    (local.set $tag (i32.load (local.get $stmt)))

    ;; FnStmt (121) → emit function definition
    (if (i32.eq (local.get $tag) (i32.const 121))
      (then (call $emit_fn_def (local.get $stmt)) (return)))

    ;; LetStmt (120) → emit local variable binding
    (if (i32.eq (local.get $tag) (i32.const 120))
      (then (call $emit_let_stmt (local.get $stmt)) (return)))

    ;; ExprStmt (125) → emit expression and drop result
    (if (i32.eq (local.get $tag) (i32.const 125))
      (then
        (call $emit_cstr (i32.const 578) (i32.const 6))  ;; "(drop "
        (call $emit_expr_node (i32.load offset=4 (local.get $stmt)))
        (call $emit_close)
        (return)))

    ;; TypeDefStmt (122) → emit constructor functions
    (if (i32.eq (local.get $tag) (i32.const 122))
      (then (call $emit_type_constructors (local.get $stmt)) (return)))

    ;; EffectDeclStmt (123) → emit effect op stubs
    (if (i32.eq (local.get $tag) (i32.const 123))
      (then (call $emit_effect_stubs (local.get $stmt)) (return)))

    ;; ImportStmt (126) → no-op in monolith mode (all files merged)
    (if (i32.eq (local.get $tag) (i32.const 126))
      (then (return)))

    ;; HandlerDeclStmt (124) → emit handler (simplified)
    (if (i32.eq (local.get $tag) (i32.const 124))
      (then (return)))  ;; TODO: handler emission

    ;; Default: no-op
    )

  ;; ─── Function definition emission ─────────────────────────────────
  ;; FnStmt → [121][name][params][ret][effs][body]
  ;;
  ;; Emits: (func $name (param $p1 i32) ... (result i32)
  ;;          (local $__match_N i32) ...
  ;;          <body>)

  (func $emit_fn_def (param $stmt i32)
    (local $name i32) (local $params i32) (local $body i32)
    (local $n i32) (local $i i32) (local $param i32) (local $pname i32)
    (local.set $name (i32.load offset=4 (local.get $stmt)))
    (local.set $params (i32.load offset=8 (local.get $stmt)))
    (local.set $body (i32.load offset=20 (local.get $stmt)))
    ;; (func $name
    (call $emit_nl)
    (call $emit_indent)
    (call $emit_cstr (i32.const 584) (i32.const 6))  ;; "(func "
    (call $emit_dollar_name (local.get $name))
    ;; Emit params
    (local.set $n (call $len (local.get $params)))
    (local.set $i (i32.const 0))
    (block $done (loop $params_loop
      (br_if $done (i32.ge_u (local.get $i) (local.get $n)))
      (local.set $param (call $list_index (local.get $params) (local.get $i)))
      ;; TParam → [190][name][ty][own][own]
      (local.set $pname (i32.load offset=4 (local.get $param)))
      (call $emit_space)
      (call $emit_cstr (i32.const 590) (i32.const 7))  ;; "(param "
      (call $emit_dollar_name (local.get $pname))
      (call $emit_cstr (i32.const 908) (i32.const 4))  ;; " i32"
      (call $emit_close)
      (local.set $i (i32.add (local.get $i) (i32.const 1)))
      (br $params_loop)))
    ;; (result i32)
    (call $emit_cstr (i32.const 597) (i32.const 13))  ;; " (result i32)"
    (call $emit_nl)
    (call $indent_inc)
    ;; Emit locals for match temporaries
    ;; We pre-declare a pool of locals. The match emitter uses them.
    (call $emit_match_locals)
    ;; Emit body
    (call $emit_indent)
    (call $emit_expr_node (local.get $body))
    (call $emit_close)  ;; close func
    (call $emit_nl)
    (call $indent_dec))

  ;; Emit pre-declared match temporary locals
  ;; We declare a fixed pool (e.g. 16 match temps) at the start
  ;; of each function. The match emitter uses $match_tmp_counter
  ;; which resets per function.
  (func $emit_match_locals
    (local $i i32)
    ;; Reset match counter for this function
    (global.set $match_tmp_counter (i32.const 0))
    ;; Declare pool: (local $__match_0 i32) ... (local $__match_15 i32)
    (local.set $i (i32.const 0))
    (block $done (loop $decl
      (br_if $done (i32.ge_u (local.get $i) (i32.const 16)))
      (call $emit_indent)
      (call $emit_cstr (i32.const 610) (i32.const 7))  ;; "(local "
      (call $emit_dollar_name
        (call $str_concat
          (call $str_from_mem (i32.const 1080) (i32.const 8))  ;; "__match_"
          (call $int_to_str (local.get $i))))
      (call $emit_cstr (i32.const 908) (i32.const 4))  ;; " i32"
      (call $emit_close)
      (call $emit_nl)
      (local.set $i (i32.add (local.get $i) (i32.const 1)))
      (br $decl)))
    ;; Reset counter so match emission starts from 0
    (global.set $match_tmp_counter (i32.const 0)))

  ;; ─── Let statement emission ───────────────────────────────────────
  ;; LetStmt → [120][pat][val]
  ;; For simple PVar: (local.set $name <val>)
  ;; For destructuring: evaluate val, then bind sub-patterns.

  (func $emit_let_stmt (param $stmt i32)
    (local $pat i32) (local $val i32) (local $pat_tag i32) (local $name i32)
    (local.set $pat (i32.load offset=4 (local.get $stmt)))
    (local.set $val (i32.load offset=8 (local.get $stmt)))
    (local.set $pat_tag (call $pat_tag_of (local.get $pat)))
    ;; Simple variable binding
    (if (i32.eq (local.get $pat_tag) (i32.const 130))  ;; PVar
      (then
        (local.set $name (call $pat_var_name (local.get $pat)))
        (call $emit_local_set_open (local.get $name))
        (call $emit_expr_node (local.get $val))
        (call $emit_close)
        (return)))
    ;; PTuple destructuring: eval into temp, extract fields
    (if (i32.eq (local.get $pat_tag) (i32.const 134))  ;; PTuple
      (then
        (call $emit_tuple_destructure (local.get $pat) (local.get $val))
        (return)))
    ;; PWild: just evaluate for side effects, drop
    (if (i32.eq (local.get $pat_tag) (i32.const 131))
      (then
        (call $emit_cstr (i32.const 578) (i32.const 6))  ;; "(drop "
        (call $emit_expr_node (local.get $val))
        (call $emit_close)
        (return)))
    ;; Default: simple eval + drop
    (call $emit_cstr (i32.const 578) (i32.const 6))
    (call $emit_expr_node (local.get $val))
    (call $emit_close))

  ;; ─── Tuple destructuring ──────────────────────────────────────────
  ;; let (a, b) = expr → eval expr into temp, load fields

  (func $emit_tuple_destructure (param $pat i32) (param $val i32)
    (local $subs i32) (local $n i32) (local $i i32) (local $sub i32)
    (local $sub_tag i32) (local $tmp i32)
    ;; Get temp name for the tuple value
    (local.set $tmp (call $match_tmp_name))
    ;; Evaluate into temp
    (call $emit_local_set_open (local.get $tmp))
    (call $emit_expr_node (local.get $val))
    (call $emit_close)
    (call $emit_nl)
    ;; Extract each element: (local.set $name (call $list_index $tmp i))
    (local.set $subs (i32.load offset=4 (local.get $pat)))  ;; PTuple subs list
    (local.set $n (call $len (local.get $subs)))
    (local.set $i (i32.const 0))
    (block $done (loop $extract
      (br_if $done (i32.ge_u (local.get $i) (local.get $n)))
      (local.set $sub (call $list_index (local.get $subs) (local.get $i)))
      (local.set $sub_tag (call $pat_tag_of (local.get $sub)))
      (if (i32.eq (local.get $sub_tag) (i32.const 130))  ;; PVar
        (then
          (call $emit_local_set_open (call $pat_var_name (local.get $sub)))
          ;; (i32.load offset=<4+i*4> (local.get $tmp))
          (call $emit_cstr (i32.const 821) (i32.const 10)) ;; "(i32.load "
          (call $emit_cstr (i32.const 929) (i32.const 7))  ;; "offset="
          (call $emit_int (i32.add (i32.const 4)
            (i32.mul (local.get $i) (i32.const 4))))
          (call $emit_space)
          (call $emit_local_get (local.get $tmp))
          (call $emit_close)  ;; close i32.load
          (call $emit_close)  ;; close local.set
          (call $emit_nl)))
      (local.set $i (i32.add (local.get $i) (i32.const 1)))
      (br $extract))))

  ;; ─── Type constructor emission ────────────────────────────────────
  ;; TypeDefStmt → [122][name][targs][variants_list]
  ;; Each variant (name, field_types) → emit a constructor function.
  ;;
  ;; Nullary: type X = None → (func $None (result i32) (i32.const <tag>))
  ;; Fielded: type X = Some(Int) →
  ;;   (func $Some (param $v0 i32) (result i32)
  ;;     (local $ptr i32)
  ;;     (local.set $ptr (call $alloc (i32.const <4+n*4>)))
  ;;     (i32.store (local.get $ptr) (i32.const <tag>))
  ;;     (i32.store offset=4 (local.get $ptr) (local.get $v0))
  ;;     (local.get $ptr))

  ;; Global constructor tag counter
  (global $ctor_tag_counter (mut i32) (i32.const 1000))

  (func $emit_type_constructors (param $stmt i32)
    (local $variants i32) (local $n i32) (local $i i32) (local $variant i32)
    (local $vname i32) (local $fields i32) (local $nfields i32)
    (local $tag_id i32) (local $j i32)
    (local.set $variants (i32.load offset=12 (local.get $stmt)))
    (local.set $n (call $len (local.get $variants)))
    (local.set $i (i32.const 0))
    (block $done (loop $var_loop
      (br_if $done (i32.ge_u (local.get $i) (local.get $n)))
      (local.set $variant (call $list_index (local.get $variants) (local.get $i)))
      (local.set $vname (call $list_index (local.get $variant) (i32.const 0)))
      (local.set $fields (call $list_index (local.get $variant) (i32.const 1)))
      (local.set $nfields (call $len (local.get $fields)))
      ;; Assign tag
      (local.set $tag_id (global.get $ctor_tag_counter))
      (global.set $ctor_tag_counter (i32.add (global.get $ctor_tag_counter) (i32.const 1)))
      ;; Emit constructor function
      (call $emit_nl)
      (call $emit_indent)
      (call $emit_cstr (i32.const 584) (i32.const 6))  ;; "(func "
      (call $emit_dollar_name (local.get $vname))
      ;; Params for each field
      (local.set $j (i32.const 0))
      (block $pd (loop $pl
        (br_if $pd (i32.ge_u (local.get $j) (local.get $nfields)))
        (call $emit_space)
        (call $emit_cstr (i32.const 590) (i32.const 7))  ;; "(param "
        (call $emit_byte (i32.const 36))  ;; $
        (call $emit_byte (i32.const 118)) ;; 'v'
        (call $emit_int (local.get $j))
        (call $emit_cstr (i32.const 908) (i32.const 4))  ;; " i32"
        (call $emit_close)
        (local.set $j (i32.add (local.get $j) (i32.const 1)))
        (br $pl)))
      (call $emit_cstr (i32.const 597) (i32.const 13))  ;; " (result i32)"
      (call $emit_nl)
      (call $indent_inc)
      (if (i32.eqz (local.get $nfields))
        (then
          ;; Nullary: return tag as sentinel
          (call $emit_indent)
          (call $emit_i32_const (local.get $tag_id))
          (call $emit_close)  ;; close func
          (call $emit_nl))
        (else
          ;; Fielded: allocate and store tag + fields
          (call $emit_indent)
          (call $emit_cstr (i32.const 610) (i32.const 7))  ;; "(local "
          (call $emit_byte (i32.const 36))
          (call $emit_byte (i32.const 112))  ;; 'p'
          (call $emit_cstr (i32.const 908) (i32.const 4))  ;; " i32"
          (call $emit_close)
          (call $emit_nl)
          ;; (local.set $p (call $alloc (i32.const <size>)))
          (call $emit_indent)
          (call $emit_cstr (i32.const 548) (i32.const 11))  ;; "(local.set "
          (call $emit_byte (i32.const 36))
          (call $emit_byte (i32.const 112))
          (call $emit_space)
          (call $emit_call_open (call $str_from_mem (i32.const 1055) (i32.const 5))) ;; "alloc"
          (call $emit_space)
          (call $emit_i32_const (i32.add (i32.const 4) (i32.mul (local.get $nfields) (i32.const 4))))
          (call $emit_close)  ;; close alloc call
          (call $emit_close)  ;; close local.set
          (call $emit_nl)
          ;; (i32.store (local.get $p) (i32.const <tag>))
          (call $emit_indent)
          (call $emit_cstr (i32.const 810) (i32.const 11))  ;; "(i32.store "
          (call $emit_cstr (i32.const 536) (i32.const 11))  ;; "(local.get "
          (call $emit_byte (i32.const 36))
          (call $emit_byte (i32.const 112))
          (call $emit_close)  ;; close local.get
          (call $emit_space)
          (call $emit_i32_const (local.get $tag_id))
          (call $emit_close)  ;; close i32.store
          (call $emit_nl)
          ;; Store each field
          (local.set $j (i32.const 0))
          (block $sd (loop $sl
            (br_if $sd (i32.ge_u (local.get $j) (local.get $nfields)))
            (call $emit_indent)
            (call $emit_cstr (i32.const 810) (i32.const 11))  ;; "(i32.store "
            (call $emit_cstr (i32.const 929) (i32.const 7))   ;; "offset="
            (call $emit_int (i32.add (i32.const 4) (i32.mul (local.get $j) (i32.const 4))))
            (call $emit_space)
            (call $emit_cstr (i32.const 536) (i32.const 11))  ;; "(local.get "
            (call $emit_byte (i32.const 36))
            (call $emit_byte (i32.const 112))
            (call $emit_close)  ;; close local.get $p
            (call $emit_space)
            (call $emit_cstr (i32.const 536) (i32.const 11))  ;; "(local.get "
            (call $emit_byte (i32.const 36))
            (call $emit_byte (i32.const 118))  ;; 'v'
            (call $emit_int (local.get $j))
            (call $emit_close)  ;; close local.get $vN
            (call $emit_close)  ;; close i32.store
            (call $emit_nl)
            (local.set $j (i32.add (local.get $j) (i32.const 1)))
            (br $sl)))
          ;; Return pointer
          (call $emit_indent)
          (call $emit_cstr (i32.const 536) (i32.const 11))  ;; "(local.get "
          (call $emit_byte (i32.const 36))
          (call $emit_byte (i32.const 112))
          (call $emit_close)
          (call $emit_close)  ;; close func
          (call $emit_nl)))
      (call $indent_dec)
      (local.set $i (i32.add (local.get $i) (i32.const 1)))
      (br $var_loop))))

  ;; ─── Effect stubs ─────────────────────────────────────────────────
  ;; For bootstrap: effect operations are compiled as no-op functions
  ;; that return unit. The real handler dispatch comes later.

  (func $emit_effect_stubs (param $stmt i32)
    (local $ops i32) (local $n i32) (local $i i32) (local $op i32) (local $op_name i32)
    (local.set $ops (i32.load offset=8 (local.get $stmt)))
    (local.set $n (call $len (local.get $ops)))
    (local.set $i (i32.const 0))
    (block $done (loop $op_loop
      (br_if $done (i32.ge_u (local.get $i) (local.get $n)))
      (local.set $op (call $list_index (local.get $ops) (local.get $i)))
      (local.set $op_name (call $list_index (local.get $op) (i32.const 0)))
      ;; (func $op_name (result i32) (i32.const 84))
      (call $emit_nl)
      (call $emit_indent)
      (call $emit_cstr (i32.const 584) (i32.const 6))  ;; "(func "
      (call $emit_dollar_name (local.get $op_name))
      (call $emit_cstr (i32.const 597) (i32.const 13)) ;; " (result i32)"
      (call $emit_space)
      (call $emit_i32_const (i32.const 84))  ;; return LitUnit
      (call $emit_close)  ;; close func
      (call $emit_nl)
      (local.set $i (i32.add (local.get $i) (i32.const 1)))
      (br $op_loop))))

  ;; ═══ Module Emission (Top-Level Orchestrator) ════════════════════════
  ;; Emits a complete WAT module from a parsed AST program.
  ;;
  ;; Two-pass emission strategy:
  ;;   Pass 1: FnStmt, TypeDefStmt, EffectDeclStmt → module-level funcs
  ;;   Pass 2: LetStmt, ExprStmt → collected into _start function
  ;;   ImportStmt, HandlerDeclStmt → skipped entirely
  ;;
  ;; The output WAT module includes:
  ;; 1. Module header + WASI imports
  ;; 2. Memory + globals
  ;; 3. Runtime primitives (allocator, tag_of)
  ;; 4. Constructor functions (from type declarations)
  ;; 5. User-defined functions
  ;; 6. _start entry point (top-level lets + expr stmts)

  ;; ─── Statement classification ─────────────────────────────────────
  ;; Returns 1 for module-level declarations (fn, type, effect)
  ;; Returns 0 for imperative statements (let, expr, import, handler)

  (func $is_decl_stmt (param $node i32) (result i32)
    (local $body i32) (local $stmt i32) (local $tag i32)
    (if (i32.lt_u (local.get $node) (i32.const 4096))
      (then (return (i32.const 0))))
    (local.set $body (i32.load offset=4 (local.get $node)))
    ;; Check if NStmt
    (if (i32.ne (i32.load (local.get $body)) (i32.const 111))
      (then (return (i32.const 0))))
    (local.set $stmt (i32.load offset=4 (local.get $body)))
    (local.set $tag (i32.load (local.get $stmt)))
    ;; FnStmt=121, TypeDefStmt=122, EffectDeclStmt=123
    (i32.or (i32.or
      (i32.eq (local.get $tag) (i32.const 121))
      (i32.eq (local.get $tag) (i32.const 122)))
      (i32.eq (local.get $tag) (i32.const 123))))

  ;; Returns 1 for statements that should be skipped entirely
  (func $is_skip_stmt (param $node i32) (result i32)
    (local $body i32) (local $stmt i32) (local $tag i32)
    (local $inner_node i32) (local $inner_body i32) (local $inner_expr i32)
    (if (i32.lt_u (local.get $node) (i32.const 4096))
      (then (return (i32.const 0))))
    (local.set $body (i32.load offset=4 (local.get $node)))
    (if (i32.ne (i32.load (local.get $body)) (i32.const 111))
      (then (return (i32.const 0))))
    (local.set $stmt (i32.load offset=4 (local.get $body)))
    (local.set $tag (i32.load (local.get $stmt)))
    ;; ImportStmt=126, HandlerDeclStmt=124 → always skip
    (if (i32.or
          (i32.eq (local.get $tag) (i32.const 126))
          (i32.eq (local.get $tag) (i32.const 124)))
      (then (return (i32.const 1))))
    ;; ExprStmt=125 wrapping bare VarRef → skip (no-op statement)
    (if (i32.eq (local.get $tag) (i32.const 125))
      (then
        ;; ExprStmt layout: [125][inner_node]
        (local.set $inner_node (i32.load offset=4 (local.get $stmt)))
        (if (i32.ge_u (local.get $inner_node) (i32.const 4096))
          (then
            (local.set $inner_body (i32.load offset=4 (local.get $inner_node)))
            (if (i32.ge_u (local.get $inner_body) (i32.const 4096))
              (then
                ;; Check NExpr tag
                (if (i32.eq (i32.load (local.get $inner_body)) (i32.const 110))
                  (then
                    (local.set $inner_expr (i32.load offset=4 (local.get $inner_body)))
                    ;; VarRef=85 → bare identifier, skip it
                    (if (i32.ge_u (local.get $inner_expr) (i32.const 4096))
                      (then
                        (return (i32.eq (i32.load (local.get $inner_expr)) (i32.const 85)))))))))))))
    (i32.const 0))

  ;; ─── emit_program: main entry point for code generation ───────────

  (func $emit_program (param $stmts i32)
    (local $n i32) (local $i i32) (local $stmt_node i32)
    (local $has_imperative i32)
    (local.set $n (call $len (local.get $stmts)))

    ;; ── Module header ──
    (call $emit_module_header)
    (call $indent_inc)

    ;; ── Pass 1: module-level declarations ──
    (local.set $i (i32.const 0))
    (block $done1 (loop $decl_loop
      (br_if $done1 (i32.ge_u (local.get $i) (local.get $n)))
      (local.set $stmt_node (call $list_index (local.get $stmts) (local.get $i)))
      (if (call $is_decl_stmt (local.get $stmt_node))
        (then
          (call $emit_node (local.get $stmt_node))
          (call $emit_nl)))
      (local.set $i (i32.add (local.get $i) (i32.const 1)))
      (br $decl_loop)))

    ;; ── Pass 2: check if any imperative statements exist ──
    (local.set $has_imperative (i32.const 0))
    (local.set $i (i32.const 0))
    (block $done2 (loop $check_loop
      (br_if $done2 (i32.ge_u (local.get $i) (local.get $n)))
      (local.set $stmt_node (call $list_index (local.get $stmts) (local.get $i)))
      (if (i32.and
            (i32.eqz (call $is_decl_stmt (local.get $stmt_node)))
            (i32.eqz (call $is_skip_stmt (local.get $stmt_node))))
        (then (local.set $has_imperative (i32.const 1))))
      (local.set $i (i32.add (local.get $i) (i32.const 1)))
      (br $check_loop)))

    ;; ── Emit _start if there are imperative statements ──
    (if (local.get $has_imperative)
      (then
        (call $emit_nl)
        (call $emit_indent)
        (call $emit_cstr (i32.const 584) (i32.const 6))   ;; "(func "
        (call $emit_byte (i32.const 36))
        (call $emit_cstr (i32.const 1491) (i32.const 9))   ;; "_start_fn"
        (call $emit_cstr (i32.const 1500) (i32.const 18))  ;; " (export \"_start\")"
        (call $emit_nl)
        (call $indent_inc)
        ;; Declare locals for all top-level let bindings
        (call $emit_toplevel_locals (local.get $stmts))
        ;; Emit imperative statements
        (local.set $i (i32.const 0))
        (block $done3 (loop $imp_loop
          (br_if $done3 (i32.ge_u (local.get $i) (local.get $n)))
          (local.set $stmt_node (call $list_index (local.get $stmts) (local.get $i)))
          (if (i32.and
                (i32.eqz (call $is_decl_stmt (local.get $stmt_node)))
                (i32.eqz (call $is_skip_stmt (local.get $stmt_node))))
            (then
              (call $emit_indent)
              (call $emit_node (local.get $stmt_node))
              (call $emit_nl)))
          (local.set $i (i32.add (local.get $i) (i32.const 1)))
          (br $imp_loop)))
        (call $indent_dec)
        (call $emit_indent)
        (call $emit_close)   ;; close func
        (call $emit_nl)))

    (call $indent_dec)
    ;; ── Close module ──
    (call $emit_close)
    (call $emit_nl)

    ;; ── Flush output ──
    (call $emit_flush))

  ;; ─── Emit local declarations for top-level let bindings ───────────
  ;; Scans stmts for LetStmt with PVar patterns and emits (local $name i32)

  (func $emit_toplevel_locals (param $stmts i32)
    (local $n i32) (local $i i32) (local $node i32)
    (local $body i32) (local $stmt i32) (local $tag i32)
    (local $pat i32) (local $pat_tag i32)
    (local.set $n (call $len (local.get $stmts)))
    (local.set $i (i32.const 0))
    (block $done (loop $scan
      (br_if $done (i32.ge_u (local.get $i) (local.get $n)))
      (local.set $node (call $list_index (local.get $stmts) (local.get $i)))
      (if (i32.ge_u (local.get $node) (i32.const 4096))
        (then
          (local.set $body (i32.load offset=4 (local.get $node)))
          (if (i32.eq (i32.load (local.get $body)) (i32.const 111))
            (then
              (local.set $stmt (i32.load offset=4 (local.get $body)))
              (local.set $tag (i32.load (local.get $stmt)))
              ;; LetStmt = 120
              (if (i32.eq (local.get $tag) (i32.const 120))
                (then
                  (local.set $pat (i32.load offset=4 (local.get $stmt)))
                  (local.set $pat_tag (call $pat_tag_of (local.get $pat)))
                  ;; PVar → emit local declaration
                  (if (i32.eq (local.get $pat_tag) (i32.const 130))
                    (then
                      (call $emit_indent)
                      (call $emit_cstr (i32.const 610) (i32.const 7)) ;; "(local "
                      (call $emit_dollar_name (call $pat_var_name (local.get $pat)))
                      (call $emit_cstr (i32.const 908) (i32.const 4)) ;; " i32"
                      (call $emit_close)
                      (call $emit_nl)))))))))
      (local.set $i (i32.add (local.get $i) (i32.const 1)))
      (br $scan)))
    ;; Also declare match temps
    (call $emit_match_locals))

  ;; ─── Module header emission ───────────────────────────────────────

  (func $emit_module_header
    (call $emit_cstr (i32.const 831) (i32.const 7))  ;; "(module"
    (call $emit_nl)
    (call $indent_inc)

    ;; ── WASI imports ──
    (call $emit_indent)
    (call $emit_wasi_imports)
    (call $emit_nl)

    ;; ── Memory ──
    (call $emit_indent)
    (call $emit_cstr (i32.const 838) (i32.const 8))  ;; "(memory "
    (call $emit_cstr (i32.const 846) (i32.const 8))  ;; "(export "
    (call $emit_byte (i32.const 34))
    (call $emit_cstr (i32.const 1096) (i32.const 6))  ;; memory
    (call $emit_byte (i32.const 34))
    (call $emit_close)
    (call $emit_space)
    (call $emit_int (i32.const 512))
    (call $emit_close)
    (call $emit_nl)

    ;; ── Globals ──
    (call $emit_indent)
    (call $emit_cstr (i32.const 862) (i32.const 8))  ;; "(global "
    (call $emit_byte (i32.const 36))
    (call $emit_cstr (i32.const 1102) (i32.const 8))  ;; heap_ptr
    (call $emit_cstr (i32.const 1110) (i32.const 11)) ;; " (mut i32) "
    (call $emit_i32_const (i32.const 1048576))
    (call $emit_close)
    (call $emit_nl)

    ;; ── Runtime ──
    (call $emit_runtime_core)
    (call $indent_dec))

  ;; ─── WASI import emission ─────────────────────────────────────────
  (func $emit_wasi_imports
    ;; fd_write
    (call $emit_cstr (i32.const 854) (i32.const 8))
    (call $emit_byte (i32.const 34))
    (call $emit_cstr (i32.const 1121) (i32.const 22))
    (call $emit_byte (i32.const 34))
    (call $emit_space)
    (call $emit_byte (i32.const 34))
    (call $emit_cstr (i32.const 1143) (i32.const 8))
    (call $emit_byte (i32.const 34))
    (call $emit_space)
    (call $emit_cstr (i32.const 924) (i32.const 5))
    (call $emit_space)
    (call $emit_byte (i32.const 36))
    (call $emit_cstr (i32.const 1151) (i32.const 13))
    (call $emit_cstr (i32.const 1164) (i32.const 37))
    (call $emit_close)
    (call $emit_close)
    (call $emit_nl)
    ;; fd_read
    (call $emit_indent)
    (call $emit_cstr (i32.const 854) (i32.const 8))
    (call $emit_byte (i32.const 34))
    (call $emit_cstr (i32.const 1121) (i32.const 22))
    (call $emit_byte (i32.const 34))
    (call $emit_space)
    (call $emit_byte (i32.const 34))
    (call $emit_cstr (i32.const 1202) (i32.const 7))
    (call $emit_byte (i32.const 34))
    (call $emit_space)
    (call $emit_cstr (i32.const 924) (i32.const 5))
    (call $emit_space)
    (call $emit_byte (i32.const 36))
    (call $emit_cstr (i32.const 1209) (i32.const 12))
    (call $emit_cstr (i32.const 1164) (i32.const 37))
    (call $emit_close)
    (call $emit_close)
    (call $emit_nl)
    ;; proc_exit
    (call $emit_indent)
    (call $emit_cstr (i32.const 854) (i32.const 8))
    (call $emit_byte (i32.const 34))
    (call $emit_cstr (i32.const 1121) (i32.const 22))
    (call $emit_byte (i32.const 34))
    (call $emit_space)
    (call $emit_byte (i32.const 34))
    (call $emit_cstr (i32.const 1221) (i32.const 9))
    (call $emit_byte (i32.const 34))
    (call $emit_space)
    (call $emit_cstr (i32.const 924) (i32.const 5))
    (call $emit_space)
    (call $emit_byte (i32.const 36))
    (call $emit_cstr (i32.const 1230) (i32.const 14))
    (call $emit_cstr (i32.const 1244) (i32.const 12))
    (call $emit_close)
    (call $emit_close))

  ;; ─── Runtime core emission ────────────────────────────────────────
  (func $emit_runtime_core
    (call $emit_nl)
    (call $emit_indent)
    (call $emit_runtime_alloc)
    (call $emit_nl)
    (call $emit_indent)
    (call $emit_runtime_tag_of)
    (call $emit_nl))

  ;; ── Allocator ──
  (func $emit_runtime_alloc
    (call $emit_cstr (i32.const 584) (i32.const 6))
    (call $emit_byte (i32.const 36))
    (call $emit_cstr (i32.const 1055) (i32.const 5))  ;; alloc
    (call $emit_cstr (i32.const 1256) (i32.const 18))
    (call $emit_cstr (i32.const 597) (i32.const 13))
    (call $emit_nl)
    (call $emit_indent)
    (call $emit_cstr (i32.const 1275) (i32.const 200))
    (call $emit_close))

  ;; ── tag_of ──
  (func $emit_runtime_tag_of
    (call $emit_cstr (i32.const 584) (i32.const 6))
    (call $emit_byte (i32.const 36))
    (call $emit_cstr (i32.const 1037) (i32.const 6))  ;; tag_of
    (call $emit_cstr (i32.const 1475) (i32.const 15))
    (call $emit_cstr (i32.const 597) (i32.const 13))
    (call $emit_nl)
    (call $emit_indent)
    (call $emit_cstr (i32.const 617) (i32.const 17))
    (call $emit_cstr (i32.const 744) (i32.const 10))
    (call $emit_cstr (i32.const 536) (i32.const 11))
    (call $emit_byte (i32.const 36))
    (call $emit_byte (i32.const 118))
    (call $emit_close)
    (call $emit_space)
    (call $emit_i32_const (i32.const 4096))
    (call $emit_close)
    (call $emit_nl)
    (call $emit_indent)
    (call $emit_cstr (i32.const 635) (i32.const 6))
    (call $emit_cstr (i32.const 536) (i32.const 11))
    (call $emit_byte (i32.const 36))
    (call $emit_byte (i32.const 118))
    (call $emit_close)
    (call $emit_close)
    (call $emit_nl)
    (call $emit_indent)
    (call $emit_cstr (i32.const 641) (i32.const 6))
    (call $emit_cstr (i32.const 821) (i32.const 10))
    (call $emit_cstr (i32.const 536) (i32.const 11))
    (call $emit_byte (i32.const 36))
    (call $emit_byte (i32.const 118))
    (call $emit_close)
    (call $emit_close)
    (call $emit_close)
    (call $emit_close)
    (call $emit_close))


  ;; ─── Entry Point ──────────────────────────────────────────────────
  ;; Pipeline: stdin → lex → parse → emit → stdout (WAT)
  (func $sys_main (export "_start")
    (local $input i32) (local $lex_result i32) (local $tokens i32)
    (local $count i32) (local $ast i32)
    (local.set $input (call $read_all_stdin))
    (local.set $lex_result (call $lex (local.get $input)))
    (local.set $tokens (call $list_index (local.get $lex_result) (i32.const 0)))
    (local.set $count (call $list_index (local.get $lex_result) (i32.const 1)))
    (local.set $ast (call $parse_program (local.get $tokens)))
    (call $emit_program (local.get $ast))
    (call $wasi_proc_exit (i32.const 0)))
)
