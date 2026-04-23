  ;; ═══ Module Emission (Top-Level Orchestrator) ════════════════════════
  ;; Emits a complete WAT module from a parsed AST program.
  ;;
  ;; Two-pass emission strategy:
  ;;   Pass 1: FnStmt, TypeDefStmt, EffectDeclStmt → module-level funcs
  ;;   Pass 2: LetStmt, ExprStmt → collected into _start function
  ;;   ImportStmt, HandlerDeclStmt → skipped entirely
  ;;
  ;; The output WAT module includes:
  ;; 1. Module header + WASI imports
  ;; 2. Memory + globals
  ;; 3. Runtime primitives (allocator, tag_of)
  ;; 4. Constructor functions (from type declarations)
  ;; 5. User-defined functions
  ;; 6. _start entry point (top-level lets + expr stmts)

  ;; ─── Statement classification ─────────────────────────────────────
  ;; Returns 1 for module-level declarations (fn, type, effect)
  ;; Returns 0 for imperative statements (let, expr, import, handler)

  (func $is_decl_stmt (param $node i32) (result i32)
    (local $body i32) (local $stmt i32) (local $tag i32)
    (if (i32.lt_u (local.get $node) (i32.const 4096))
      (then (return (i32.const 0))))
    (local.set $body (i32.load offset=4 (local.get $node)))
    ;; Check if NStmt
    (if (i32.ne (i32.load (local.get $body)) (i32.const 111))
      (then (return (i32.const 0))))
    (local.set $stmt (i32.load offset=4 (local.get $body)))
    (local.set $tag (i32.load (local.get $stmt)))
    ;; FnStmt=121, TypeDefStmt=122, EffectDeclStmt=123
    (i32.or (i32.or
      (i32.eq (local.get $tag) (i32.const 121))
      (i32.eq (local.get $tag) (i32.const 122)))
      (i32.eq (local.get $tag) (i32.const 123))))

  ;; Returns 1 for statements that should be skipped entirely
  (func $is_skip_stmt (param $node i32) (result i32)
    (local $body i32) (local $stmt i32) (local $tag i32)
    (local $inner_node i32) (local $inner_body i32) (local $inner_expr i32)
    (if (i32.lt_u (local.get $node) (i32.const 4096))
      (then (return (i32.const 0))))
    (local.set $body (i32.load offset=4 (local.get $node)))
    (if (i32.ne (i32.load (local.get $body)) (i32.const 111))
      (then (return (i32.const 0))))
    (local.set $stmt (i32.load offset=4 (local.get $body)))
    (local.set $tag (i32.load (local.get $stmt)))
    ;; ImportStmt=126, HandlerDeclStmt=124 → always skip
    (if (i32.or
          (i32.eq (local.get $tag) (i32.const 126))
          (i32.eq (local.get $tag) (i32.const 124)))
      (then (return (i32.const 1))))
    ;; ExprStmt=125 wrapping bare VarRef → skip (no-op statement)
    (if (i32.eq (local.get $tag) (i32.const 125))
      (then
        ;; ExprStmt layout: [125][inner_node]
        (local.set $inner_node (i32.load offset=4 (local.get $stmt)))
        (if (i32.ge_u (local.get $inner_node) (i32.const 4096))
          (then
            (local.set $inner_body (i32.load offset=4 (local.get $inner_node)))
            (if (i32.ge_u (local.get $inner_body) (i32.const 4096))
              (then
                ;; Check NExpr tag
                (if (i32.eq (i32.load (local.get $inner_body)) (i32.const 110))
                  (then
                    (local.set $inner_expr (i32.load offset=4 (local.get $inner_body)))
                    ;; VarRef=85 → bare identifier, skip it
                    (if (i32.ge_u (local.get $inner_expr) (i32.const 4096))
                      (then
                        (return (i32.eq (i32.load (local.get $inner_expr)) (i32.const 85)))))))))))))
    (i32.const 0))

  ;; ─── emit_program: main entry point for code generation ───────────

  (func $emit_program (param $stmts i32)
    (local $n i32) (local $i i32) (local $stmt_node i32)
    (local $has_imperative i32)
    (local.set $n (call $len (local.get $stmts)))

    ;; ── Module header ──
    (call $emit_module_header)
    (call $indent_inc)

    ;; ── Pass 1: module-level declarations ──
    (local.set $i (i32.const 0))
    (block $done1 (loop $decl_loop
      (br_if $done1 (i32.ge_u (local.get $i) (local.get $n)))
      (local.set $stmt_node (call $list_index (local.get $stmts) (local.get $i)))
      (if (call $is_decl_stmt (local.get $stmt_node))
        (then
          (call $emit_node (local.get $stmt_node))
          (call $emit_nl)))
      (local.set $i (i32.add (local.get $i) (i32.const 1)))
      (br $decl_loop)))

    ;; ── Pass 2: check if any imperative statements exist ──
    (local.set $has_imperative (i32.const 0))
    (local.set $i (i32.const 0))
    (block $done2 (loop $check_loop
      (br_if $done2 (i32.ge_u (local.get $i) (local.get $n)))
      (local.set $stmt_node (call $list_index (local.get $stmts) (local.get $i)))
      (if (i32.and
            (i32.eqz (call $is_decl_stmt (local.get $stmt_node)))
            (i32.eqz (call $is_skip_stmt (local.get $stmt_node))))
        (then (local.set $has_imperative (i32.const 1))))
      (local.set $i (i32.add (local.get $i) (i32.const 1)))
      (br $check_loop)))

    ;; ── Emit _start if there are imperative statements ──
    (if (local.get $has_imperative)
      (then
        (call $emit_nl)
        (call $emit_indent)
        (call $emit_cstr (i32.const 584) (i32.const 6))   ;; "(func "
        (call $emit_byte (i32.const 36))
        (call $emit_cstr (i32.const 1491) (i32.const 9))   ;; "_start_fn"
        (call $emit_cstr (i32.const 1500) (i32.const 18))  ;; " (export \"_start\")"
        (call $emit_nl)
        (call $indent_inc)
        ;; Declare locals for all top-level let bindings
        (call $emit_toplevel_locals (local.get $stmts))
        ;; Emit imperative statements
        (local.set $i (i32.const 0))
        (block $done3 (loop $imp_loop
          (br_if $done3 (i32.ge_u (local.get $i) (local.get $n)))
          (local.set $stmt_node (call $list_index (local.get $stmts) (local.get $i)))
          (if (i32.and
                (i32.eqz (call $is_decl_stmt (local.get $stmt_node)))
                (i32.eqz (call $is_skip_stmt (local.get $stmt_node))))
            (then
              (call $emit_indent)
              (call $emit_node (local.get $stmt_node))
              (call $emit_nl)))
          (local.set $i (i32.add (local.get $i) (i32.const 1)))
          (br $imp_loop)))
        (call $indent_dec)
        (call $emit_indent)
        (call $emit_close)   ;; close func
        (call $emit_nl)))

    (call $indent_dec)
    ;; ── Close module ──
    (call $emit_close)
    (call $emit_nl)

    ;; ── Flush output ──
    (call $emit_flush))

  ;; ─── Emit local declarations for top-level let bindings ───────────
  ;; Scans stmts for LetStmt with PVar patterns and emits (local $name i32)

  (func $emit_toplevel_locals (param $stmts i32)
    (local $n i32) (local $i i32) (local $node i32)
    (local $body i32) (local $stmt i32) (local $tag i32)
    (local $pat i32) (local $pat_tag i32)
    (local.set $n (call $len (local.get $stmts)))
    (local.set $i (i32.const 0))
    (block $done (loop $scan
      (br_if $done (i32.ge_u (local.get $i) (local.get $n)))
      (local.set $node (call $list_index (local.get $stmts) (local.get $i)))
      (if (i32.ge_u (local.get $node) (i32.const 4096))
        (then
          (local.set $body (i32.load offset=4 (local.get $node)))
          (if (i32.eq (i32.load (local.get $body)) (i32.const 111))
            (then
              (local.set $stmt (i32.load offset=4 (local.get $body)))
              (local.set $tag (i32.load (local.get $stmt)))
              ;; LetStmt = 120
              (if (i32.eq (local.get $tag) (i32.const 120))
                (then
                  (local.set $pat (i32.load offset=4 (local.get $stmt)))
                  (local.set $pat_tag (call $pat_tag_of (local.get $pat)))
                  ;; PVar → emit local declaration
                  (if (i32.eq (local.get $pat_tag) (i32.const 130))
                    (then
                      (call $emit_indent)
                      (call $emit_cstr (i32.const 610) (i32.const 7)) ;; "(local "
                      (call $emit_dollar_name (call $pat_var_name (local.get $pat)))
                      (call $emit_cstr (i32.const 908) (i32.const 4)) ;; " i32"
                      (call $emit_close)
                      (call $emit_nl)))))))))
      (local.set $i (i32.add (local.get $i) (i32.const 1)))
      (br $scan)))
    ;; Also declare match temps
    (call $emit_match_locals))

  ;; ─── Module header emission ───────────────────────────────────────

  (func $emit_module_header
    (call $emit_cstr (i32.const 831) (i32.const 7))  ;; "(module"
    (call $emit_nl)
    (call $indent_inc)

    ;; ── WASI imports ──
    (call $emit_indent)
    (call $emit_wasi_imports)
    (call $emit_nl)

    ;; ── Memory ──
    (call $emit_indent)
    (call $emit_cstr (i32.const 838) (i32.const 8))  ;; "(memory "
    (call $emit_cstr (i32.const 846) (i32.const 8))  ;; "(export "
    (call $emit_byte (i32.const 34))
    (call $emit_cstr (i32.const 1096) (i32.const 6))  ;; memory
    (call $emit_byte (i32.const 34))
    (call $emit_close)
    (call $emit_space)
    (call $emit_int (i32.const 512))
    (call $emit_close)
    (call $emit_nl)

    ;; ── Globals ──
    (call $emit_indent)
    (call $emit_cstr (i32.const 862) (i32.const 8))  ;; "(global "
    (call $emit_byte (i32.const 36))
    (call $emit_cstr (i32.const 1102) (i32.const 8))  ;; heap_ptr
    (call $emit_cstr (i32.const 1110) (i32.const 11)) ;; " (mut i32) "
    (call $emit_i32_const (i32.const 1048576))
    (call $emit_close)
    (call $emit_nl)

    ;; ── Runtime ──
    (call $emit_runtime_core)
    (call $indent_dec))

  ;; ─── WASI import emission ─────────────────────────────────────────
  (func $emit_wasi_imports
    ;; fd_write
    (call $emit_cstr (i32.const 854) (i32.const 8))
    (call $emit_byte (i32.const 34))
    (call $emit_cstr (i32.const 1121) (i32.const 22))
    (call $emit_byte (i32.const 34))
    (call $emit_space)
    (call $emit_byte (i32.const 34))
    (call $emit_cstr (i32.const 1143) (i32.const 8))
    (call $emit_byte (i32.const 34))
    (call $emit_space)
    (call $emit_cstr (i32.const 924) (i32.const 5))
    (call $emit_space)
    (call $emit_byte (i32.const 36))
    (call $emit_cstr (i32.const 1151) (i32.const 13))
    (call $emit_cstr (i32.const 1164) (i32.const 37))
    (call $emit_close)
    (call $emit_close)
    (call $emit_nl)
    ;; fd_read
    (call $emit_indent)
    (call $emit_cstr (i32.const 854) (i32.const 8))
    (call $emit_byte (i32.const 34))
    (call $emit_cstr (i32.const 1121) (i32.const 22))
    (call $emit_byte (i32.const 34))
    (call $emit_space)
    (call $emit_byte (i32.const 34))
    (call $emit_cstr (i32.const 1202) (i32.const 7))
    (call $emit_byte (i32.const 34))
    (call $emit_space)
    (call $emit_cstr (i32.const 924) (i32.const 5))
    (call $emit_space)
    (call $emit_byte (i32.const 36))
    (call $emit_cstr (i32.const 1209) (i32.const 12))
    (call $emit_cstr (i32.const 1164) (i32.const 37))
    (call $emit_close)
    (call $emit_close)
    (call $emit_nl)
    ;; proc_exit
    (call $emit_indent)
    (call $emit_cstr (i32.const 854) (i32.const 8))
    (call $emit_byte (i32.const 34))
    (call $emit_cstr (i32.const 1121) (i32.const 22))
    (call $emit_byte (i32.const 34))
    (call $emit_space)
    (call $emit_byte (i32.const 34))
    (call $emit_cstr (i32.const 1221) (i32.const 9))
    (call $emit_byte (i32.const 34))
    (call $emit_space)
    (call $emit_cstr (i32.const 924) (i32.const 5))
    (call $emit_space)
    (call $emit_byte (i32.const 36))
    (call $emit_cstr (i32.const 1230) (i32.const 14))
    (call $emit_cstr (i32.const 1244) (i32.const 12))
    (call $emit_close)
    (call $emit_close))

  ;; ─── Runtime core emission ────────────────────────────────────────
  (func $emit_runtime_core
    (call $emit_nl)
    (call $emit_indent)
    (call $emit_runtime_alloc)
    (call $emit_nl)
    (call $emit_indent)
    (call $emit_runtime_tag_of)
    (call $emit_nl))

  ;; ── Allocator ──
  (func $emit_runtime_alloc
    (call $emit_cstr (i32.const 584) (i32.const 6))
    (call $emit_byte (i32.const 36))
    (call $emit_cstr (i32.const 1055) (i32.const 5))  ;; alloc
    (call $emit_cstr (i32.const 1256) (i32.const 18))
    (call $emit_cstr (i32.const 597) (i32.const 13))
    (call $emit_nl)
    (call $emit_indent)
    (call $emit_cstr (i32.const 1275) (i32.const 200))
    (call $emit_close))

  ;; ── tag_of ──
  (func $emit_runtime_tag_of
    (call $emit_cstr (i32.const 584) (i32.const 6))
    (call $emit_byte (i32.const 36))
    (call $emit_cstr (i32.const 1037) (i32.const 6))  ;; tag_of
    (call $emit_cstr (i32.const 1475) (i32.const 15))
    (call $emit_cstr (i32.const 597) (i32.const 13))
    (call $emit_nl)
    (call $emit_indent)
    (call $emit_cstr (i32.const 617) (i32.const 17))
    (call $emit_cstr (i32.const 744) (i32.const 10))
    (call $emit_cstr (i32.const 536) (i32.const 11))
    (call $emit_byte (i32.const 36))
    (call $emit_byte (i32.const 118))
    (call $emit_close)
    (call $emit_space)
    (call $emit_i32_const (i32.const 4096))
    (call $emit_close)
    (call $emit_nl)
    (call $emit_indent)
    (call $emit_cstr (i32.const 635) (i32.const 6))
    (call $emit_cstr (i32.const 536) (i32.const 11))
    (call $emit_byte (i32.const 36))
    (call $emit_byte (i32.const 118))
    (call $emit_close)
    (call $emit_close)
    (call $emit_nl)
    (call $emit_indent)
    (call $emit_cstr (i32.const 641) (i32.const 6))
    (call $emit_cstr (i32.const 821) (i32.const 10))
    (call $emit_cstr (i32.const 536) (i32.const 11))
    (call $emit_byte (i32.const 36))
    (call $emit_byte (i32.const 118))
    (call $emit_close)
    (call $emit_close)
    (call $emit_close)
    (call $emit_close)
    (call $emit_close))
