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
