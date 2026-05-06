  ;; ═══ main_mentl_infer_smoke.wat — pipeline-stage boundary harness ════════
  ;;
  ;; Per Hβ-infer-substrate.md §11 acceptance + main.wat §10.3 clean handoff.
  ;;
  ;; Asserts:
  ;;   1. $inka_infer is callable with empty stmts list — returns without
  ;;      trap; $infer_ref_escape_len = 0 (no refs pushed by empty walk).
  ;;   2. $inka_infer with single LetStmt (PVar "x" = LitInt 42) delegates
  ;;      to $infer_program — verifiable via $env_lookup("x") returning
  ;;      nonzero (binding was env_extended by infer_walk_stmt_let).
  ;;
  ;; AST layout note: all nodes use raw $alloc + direct i32.store, matching
  ;; the parser's layout (tag-only 4-byte header). NOT $make_record which
  ;; has a 2-word (tag + arity) header incompatible with the inference walk's
  ;; $tag_of / direct offset-based field access (walk_stmt_let_simple.wat
  ;; pattern).

  ;; ─── "x" name string in static data ─────────────────────────────────
  (data (i32.const 4928) "\01\00\00\00x")

  ;; ─── Result/FAIL strings ─────────────────────────────────────────────
  (data (i32.const 4192) "\14\00\00\00PASS main_inka_infer\0a")
  (data (i32.const 4224) "\1f\00\00\00FAIL main_inka_infer empty path\0a")
  (data (i32.const 4272) "\21\00\00\00FAIL main_inka_infer letstmt path\0a")

  ;; ─── Path 1: empty stmts — $inka_infer returns; $infer_ref_escape_len=0
  (func $main_smoke_empty (result i32)
    (local $empty_stmts i32)
    (call $graph_init)
    (call $env_init)
    (call $infer_init)
    (local.set $empty_stmts (call $make_list (i32.const 0)))
    (call $inka_infer (local.get $empty_stmts))
    (call $infer_ref_escape_len))

  ;; ─── Path 2: LetStmt(PVar "x", LitInt 42) — env_lookup("x") nonzero
  ;;
  ;; Per walk_stmt_let_simple.wat AST build pattern (lines 62-108):
  ;;   N-node: [tag=0][body_ptr][span_ptr][handle_i32]  (16 bytes raw alloc)
  ;;   body  = NStmt: [tag=111][stmt_ptr]               (8 bytes raw alloc)
  ;;   stmt  = LetStmt: [tag=120][pat_ptr][val_node_ptr] (12 bytes raw alloc)
  ;;   pat   = PVar: [tag=130][name_ptr]                 (8 bytes raw alloc)
  ;;   val   = NExpr N-node: [tag=0][body_ptr][span][h]  (16 bytes raw alloc)
  ;;   body  = NExpr: [tag=110][litint_ptr]              (8 bytes raw alloc)
  ;;   litint = LitInt: [tag=80][value=42]               (8 bytes raw alloc)
  (func $main_smoke_letstmt (result i32)
    (local $span i32)
    (local $litint i32) (local $val_body i32) (local $val_h i32) (local $val_node i32)
    (local $pat i32)
    (local $stmt i32) (local $stmt_body i32) (local $stmt_h i32) (local $stmt_node i32)
    (local $stmts i32)
    (local $lookup i32)

    ;; Span (dummy: line=1 col=1 to line=1 col=5)
    (local.set $span (call $alloc (i32.const 16)))
    (i32.store           (local.get $span) (i32.const 1))
    (i32.store offset=4  (local.get $span) (i32.const 1))
    (i32.store offset=8  (local.get $span) (i32.const 1))
    (i32.store offset=12 (local.get $span) (i32.const 5))

    ;; LitInt(42): [tag=80][value=42]
    (local.set $litint (call $alloc (i32.const 8)))
    (i32.store           (local.get $litint) (i32.const 80))
    (i32.store offset=4  (local.get $litint) (i32.const 42))

    ;; NExpr body: [tag=110][litint]
    (local.set $val_body (call $alloc (i32.const 8)))
    (i32.store           (local.get $val_body) (i32.const 110))
    (i32.store offset=4  (local.get $val_body) (local.get $litint))

    ;; NExpr N-node: [tag=0][val_body][span][fresh_handle]
    (local.set $val_h (call $graph_fresh_ty (i32.const 0)))
    (local.set $val_node (call $alloc (i32.const 16)))
    (i32.store           (local.get $val_node) (i32.const 0))
    (i32.store offset=4  (local.get $val_node) (local.get $val_body))
    (i32.store offset=8  (local.get $val_node) (local.get $span))
    (i32.store offset=12 (local.get $val_node) (local.get $val_h))

    ;; PVar("x"): [tag=130][name_ptr=4928]
    (local.set $pat (call $alloc (i32.const 8)))
    (i32.store           (local.get $pat) (i32.const 130))
    (i32.store offset=4  (local.get $pat) (i32.const 4928))

    ;; LetStmt: [tag=120][pat][val_node]
    (local.set $stmt (call $alloc (i32.const 12)))
    (i32.store           (local.get $stmt) (i32.const 120))
    (i32.store offset=4  (local.get $stmt) (local.get $pat))
    (i32.store offset=8  (local.get $stmt) (local.get $val_node))

    ;; NStmt body: [tag=111][stmt]
    (local.set $stmt_body (call $alloc (i32.const 8)))
    (i32.store           (local.get $stmt_body) (i32.const 111))
    (i32.store offset=4  (local.get $stmt_body) (local.get $stmt))

    ;; N-node for stmt: [tag=0][stmt_body][span][fresh_handle]
    (local.set $stmt_h (call $graph_fresh_ty (i32.const 0)))
    (local.set $stmt_node (call $alloc (i32.const 16)))
    (i32.store           (local.get $stmt_node) (i32.const 0))
    (i32.store offset=4  (local.get $stmt_node) (local.get $stmt_body))
    (i32.store offset=8  (local.get $stmt_node) (local.get $span))
    (i32.store offset=12 (local.get $stmt_node) (local.get $stmt_h))

    ;; stmts list: [stmt_node]
    (local.set $stmts (call $make_list (i32.const 1)))
    (drop (call $list_set (local.get $stmts) (i32.const 0) (local.get $stmt_node)))

    ;; Run inference
    (call $inka_infer (local.get $stmts))

    ;; Post-call: env_lookup("x") should return nonzero binding
    (local.set $lookup (call $env_lookup (i32.const 4928)))
    (local.get $lookup))

  (func (export "_start")
    (local $empty_ok i32) (local $letstmt_ok i32)
    ;; Path 1: empty stmts
    (local.set $empty_ok (i32.eqz (call $main_smoke_empty)))
    (if (i32.eqz (local.get $empty_ok))
      (then
        (call $eprint_string (i32.const 4224))
        (call $wasi_proc_exit (i32.const 1))))
    ;; Path 2: LetStmt
    (call $graph_init)
    (call $env_init)
    (call $infer_init)
    (local.set $letstmt_ok (call $main_smoke_letstmt))
    (if (i32.eqz (local.get $letstmt_ok))
      (then
        (call $eprint_string (i32.const 4272))
        (call $wasi_proc_exit (i32.const 1))))
    (call $eprint_string (i32.const 4192))
    (call $wasi_proc_exit (i32.const 0)))
