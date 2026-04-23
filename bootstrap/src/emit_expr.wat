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
