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
  ;; The bare `==` shape on strings is forbidden in src/*.mn per
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

  ;; ─── $str_unescape — Mentl string-literal escape resolver ─────────
  ;; Per Hβ.first-light.lexer-string-escape-substrate (2026-05-07) +
  ;; protocol_emit_is_graph_projection.md: the source bytes carry the
  ;; ESCAPED form (`\n`, `\t`, etc.); the graph stores the RESOLVED
  ;; bytes. The lexer projects source → graph bytes via this fn. Per
  ;; SYNTAX.md §1077 escape codes: \n \r \t \\ \" \0 (\xHH future).
  ;;
  ;; Two-pass: first computes decoded length, then allocates + decodes.
  ;; Lone `\` at end of input is preserved as literal backslash byte.
  ;;
  ;; Drift refused: 1 (no vtable; structural byte-class dispatch);
  ;; 6 (uniform single-byte path for printable + escape; no
  ;; printable-special-case); 8 (sentinel-int byte comparisons).
  (func $str_unescape (param $src i32) (param $start i32) (param $end i32)
        (result i32)
    (local $i i32) (local $b i32) (local $next i32)
    (local $count i32) (local $dest i32) (local $write_pos i32)
    ;; Pass 1: count decoded bytes.
    (local.set $count (i32.const 0))
    (local.set $i (local.get $start))
    (block $count_done
      (loop $count_iter
        (br_if $count_done (i32.ge_u (local.get $i) (local.get $end)))
        (local.set $b (call $byte_at (local.get $src) (local.get $i)))
        (if (i32.and
              (i32.eq (local.get $b) (i32.const 92))                   ;; '\'
              (i32.lt_u (i32.add (local.get $i) (i32.const 1)) (local.get $end)))
          (then
            ;; Escape sequence consumes 2 source bytes → 1 decoded byte.
            (local.set $i (i32.add (local.get $i) (i32.const 2))))
          (else
            (local.set $i (i32.add (local.get $i) (i32.const 1)))))
        (local.set $count (i32.add (local.get $count) (i32.const 1)))
        (br $count_iter)))
    ;; Allocate destination string.
    (local.set $dest (call $str_alloc (local.get $count)))
    ;; Pass 2: decode bytes into dest payload (offset 4).
    (local.set $i (local.get $start))
    (local.set $write_pos (i32.const 0))
    (block $write_done
      (loop $write_iter
        (br_if $write_done (i32.ge_u (local.get $i) (local.get $end)))
        (local.set $b (call $byte_at (local.get $src) (local.get $i)))
        (if (i32.and
              (i32.eq (local.get $b) (i32.const 92))                   ;; '\'
              (i32.lt_u (i32.add (local.get $i) (i32.const 1)) (local.get $end)))
          (then
            ;; Read the escape character.
            (local.set $next
              (call $byte_at (local.get $src) (i32.add (local.get $i) (i32.const 1))))
            ;; Decode per SYNTAX.md §1077.
            (if (i32.eq (local.get $next) (i32.const 110))             ;; 'n'
              (then (local.set $b (i32.const 10)))                     ;; LF
              (else
                (if (i32.eq (local.get $next) (i32.const 114))         ;; 'r'
                  (then (local.set $b (i32.const 13)))                 ;; CR
                  (else
                    (if (i32.eq (local.get $next) (i32.const 116))     ;; 't'
                      (then (local.set $b (i32.const 9)))              ;; TAB
                      (else
                        (if (i32.eq (local.get $next) (i32.const 48))  ;; '0'
                          (then (local.set $b (i32.const 0)))          ;; NUL
                          (else
                            ;; Other escape (\, ", and any unknown):
                            ;; the second byte IS the literal byte.
                            ;; This catches \\ → \, \" → ", \X → X.
                            (local.set $b (local.get $next))))))))))
            (local.set $i (i32.add (local.get $i) (i32.const 2))))
          (else
            (local.set $i (i32.add (local.get $i) (i32.const 1)))))
        (i32.store8
          (i32.add
            (i32.add (local.get $dest) (i32.const 4))
            (local.get $write_pos))
          (local.get $b))
        (local.set $write_pos (i32.add (local.get $write_pos) (i32.const 1)))
        (br $write_iter)))
    (local.get $dest))

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
