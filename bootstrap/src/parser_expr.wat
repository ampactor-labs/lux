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
    ;; Subscript: e[idx] → Call(VarRef("list_index"), [e, idx])
    (if (i32.eq (local.get $k) (i32.const 49))  ;; TLBracket
      (then
        (local.set $args_result
          (call $parse_expr (local.get $tokens)
            (call $skip_ws_p (local.get $tokens) (i32.add (local.get $pos) (i32.const 1)))))
        (local.set $field (call $list_index (local.get $args_result) (i32.const 0)))
        (local.set $p2    (call $list_index (local.get $args_result) (i32.const 1)))
        (local.set $p2 (call $expect (local.get $tokens)
          (call $skip_ws_p (local.get $tokens) (local.get $p2)) (i32.const 50)))
        (local.set $span (i32.load offset=8 (local.get $e)))
        (local.set $args (call $make_list (i32.const 2)))
        (drop (call $list_set (local.get $args) (i32.const 0) (local.get $e)))
        (drop (call $list_set (local.get $args) (i32.const 1) (local.get $field)))
        (local.set $node (call $nexpr
          (call $mk_CallExpr
            (call $nexpr (call $mk_VarRef (i32.const 4288)) (local.get $span))
            (local.get $args))
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
    ;; TFloat (27) — payload is the raw decimal text per H.3.b.
    (if (i32.eq (local.get $n) (i32.const 27))
      (then
        (local.set $tup (call $make_list (i32.const 2)))
        (drop (call $list_set (local.get $tup) (i32.const 0)
          (call $nexpr (call $mk_LitFloat (i32.load offset=4 (local.get $k))) (local.get $span))))
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
