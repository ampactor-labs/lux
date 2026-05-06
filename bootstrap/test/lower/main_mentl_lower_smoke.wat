  ;; ═══ main_mentl_lower_smoke.wat — pipeline-stage boundary harness ════════
  ;;
  ;; Per Hβ-lower-substrate.md §11 acceptance + main.wat §10.3 clean handoff.
  ;;
  ;; Asserts:
  ;;   1. $inka_lower is callable with empty stmts list — returns a list
  ;;      pointer with length 0 (empty input → empty LowExpr output).
  ;;   2. $inka_lower with single ExprStmt(LitInt(42)) delegates to
  ;;      $lower_program → $lower_stmt_list → $lower_stmt → $lower_expr →
  ;;      $lower_lit_int — verifiable via result list length 1 +
  ;;      $tag_of(first element) == 300 (LConst) + $lexpr_lconst_value == 42.
  ;;
  ;; AST layout note: uses $mk_LitInt / $mk_ExprStmt / $nexpr / $nstmt
  ;; helpers from walk_stmt_expr.wat pattern — raw alloc + direct i32.store
  ;; matching the parser's layout (tag-only 4-byte header). NOT $make_record.

  ;; ─── Result/FAIL strings in static data ─────────────────────────────
  (data (i32.const 4192) "\14\00\00\00PASS main_inka_lower\0a")
  (data (i32.const 4224) "\1f\00\00\00FAIL main_inka_lower empty path\0a")
  (data (i32.const 4272) "\22\00\00\00FAIL main_inka_lower exprstmt path\0a")

  ;; ─── Path 1: empty stmts — $inka_lower returns empty list (len 0)
  (func $main_smoke_empty (result i32)
    (local $empty_stmts i32)
    (local $result i32)
    (call $graph_init)
    (call $env_init)
    (call $lower_init)
    (local.set $empty_stmts (call $make_list (i32.const 0)))
    (local.set $result (call $inka_lower (local.get $empty_stmts)))
    (call $len (local.get $result)))

  ;; ─── Path 2: ExprStmt(LitInt(42)) — result list len 1, tag 300, value 42
  ;;
  ;; Per walk_stmt_expr.wat AST build pattern + walk_stmt_program.wat helper:
  ;;   LitInt(42)   : $mk_LitInt(42)
  ;;   NExpr        : $nexpr(litint, 0)   — tag=0 N-node wrapping NExpr body
  ;;   ExprStmt     : $mk_ExprStmt(val_node)
  ;;   NStmt        : $nstmt(stmt_struct, 0)
  ;;   stmts list   : make_list(1) + list_set(stmts, 0, stmt_node)
  (func $main_smoke_exprstmt (result i32)
    (local $val_lit i32) (local $val_node i32)
    (local $stmt_struct i32) (local $stmt_node i32)
    (local $stmts i32)
    (local $result i32)
    (local $first i32)
    (call $graph_init)
    (call $env_init)
    (call $lower_init)

    (local.set $val_lit    (call $mk_LitInt (i32.const 42)))
    (local.set $val_node   (call $nexpr (local.get $val_lit) (i32.const 0)))
    (local.set $stmt_struct (call $mk_ExprStmt (local.get $val_node)))
    (local.set $stmt_node  (call $nstmt (local.get $stmt_struct) (i32.const 0)))

    (local.set $stmts (call $make_list (i32.const 1)))
    (drop (call $list_set (local.get $stmts) (i32.const 0) (local.get $stmt_node)))

    (local.set $result (call $inka_lower (local.get $stmts)))

    ;; Verify length 1
    (if (i32.ne (call $len (local.get $result)) (i32.const 1))
      (then (return (i32.const 0))))

    ;; Verify first element tag == 300 (LConst)
    (local.set $first (call $list_index (local.get $result) (i32.const 0)))
    (if (i32.ne (call $tag_of (local.get $first)) (i32.const 300))
      (then (return (i32.const 0))))

    ;; Verify value == 42
    (if (i32.ne (call $lexpr_lconst_value (local.get $first)) (i32.const 42))
      (then (return (i32.const 0))))

    (i32.const 1))

  (func (export "_start")
    (local $empty_len i32) (local $exprstmt_ok i32)
    ;; Path 1: empty stmts — result list length must be 0
    (local.set $empty_len (call $main_smoke_empty))
    (if (i32.ne (local.get $empty_len) (i32.const 0))
      (then
        (call $eprint_string (i32.const 4224))
        (call $wasi_proc_exit (i32.const 1))))
    ;; Path 2: ExprStmt(LitInt(42))
    (local.set $exprstmt_ok (call $main_smoke_exprstmt))
    (if (i32.eqz (local.get $exprstmt_ok))
      (then
        (call $eprint_string (i32.const 4272))
        (call $wasi_proc_exit (i32.const 1))))
    (call $eprint_string (i32.const 4192))
    (call $wasi_proc_exit (i32.const 0)))
