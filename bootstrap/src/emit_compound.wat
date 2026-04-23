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
