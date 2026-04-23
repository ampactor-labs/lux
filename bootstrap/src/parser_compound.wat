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
