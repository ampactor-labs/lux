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
    ;; THandler → parse handler declaration via parser_handler.wat
    ;; Closes the 19-box per Hβ.first-light.handler-decl-emit-cascade —
    ;; the full arm parser lives in parser_handler.wat; this dispatch
    ;; site just delegates and returns the canonical 2-tuple shape.
    (if (i32.eq (local.get $k) (i32.const 8))
      (then (return (call $parse_handler_decl_full (local.get $tokens)
        (local.get $pos) (local.get $span)))))
    ;; TImport → parse import
    (if (i32.eq (local.get $k) (i32.const 18))
      (then
        (local.set $result (call $parse_import_path (local.get $tokens)
          (i32.add (local.get $pos) (i32.const 1))))
        (local.set $tup (call $make_list (i32.const 2)))
        (drop (call $list_set (local.get $tup) (i32.const 0)
          (call $nstmt
            (call $mk_ImportStmt
              (call $list_index (local.get $result) (i32.const 0)))
            (local.get $span))))
        (drop (call $list_set (local.get $tup) (i32.const 1)
          (call $list_index (local.get $result) (i32.const 1))))
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

  ;; HandlerDeclStmt construction lives in parser_handler.wat
  ;; ($mk_handler_decl_full) per the 19-box closure. The 1-arg shell
  ;; that previously sat at this site is deleted to refuse drift 9
  ;; (deferred-by-omission); both effect_name and arms are now
  ;; populated at parse time.
  ;;
  ;; parse_import_path: slash-separated module name per SYNTAX.md
  ;; `import path/to/module`. Returns [path, next_pos].
  (func $parse_import_path (param $tokens i32) (param $pos i32) (result i32)
    (local $acc i32) (local $p i32) (local $name i32)
    (local $slash i32) (local $tup i32)
    (local.set $acc (call $str_alloc (i32.const 0)))
    (local.set $p (local.get $pos))
    (block $done
      (loop $parts
        (local.set $name (call $ident_at_p (local.get $tokens) (local.get $p)))
        (local.set $acc (call $str_concat (local.get $acc) (local.get $name)))
        (local.set $p (i32.add (local.get $p) (i32.const 1)))
        (if (call $at (local.get $tokens) (local.get $p) (i32.const 58))
          (then
            (local.set $slash (call $str_alloc (i32.const 1)))
            (i32.store8 (i32.add (local.get $slash) (i32.const 4)) (i32.const 47))
            (local.set $acc (call $str_concat (local.get $acc) (local.get $slash)))
            (local.set $p (i32.add (local.get $p) (i32.const 1)))
            (br $parts)))
        (br $done)))
    (local.set $tup (call $make_list (i32.const 2)))
    (drop (call $list_set (local.get $tup) (i32.const 0) (local.get $acc)))
    (drop (call $list_set (local.get $tup) (i32.const 1) (local.get $p)))
    (local.get $tup))

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
