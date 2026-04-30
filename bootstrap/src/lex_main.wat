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
        (if (i32.eq (local.get $tag) (i32.const 1)) (then (return (i32.const 262))))  ;; "let"
        (if (i32.eq (local.get $tag) (i32.const 2)) (then (return (i32.const 269))))  ;; "if"
        (if (i32.eq (local.get $tag) (i32.const 3)) (then (return (i32.const 275))))  ;; "else"
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
