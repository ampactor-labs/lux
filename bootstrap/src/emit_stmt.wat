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
