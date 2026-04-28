  ;; ═══ walk_const_var_ref_global.wat — Hβ.lower trace-harness ════════════
  ;; Executes: Hβ-lower-substrate.md §4.2 VarRef-RGlobal arm — unbound name
  ;;           lowers to LGlobal(h, name) (tag 302) when no local binding
  ;;           exists and $env_contains returns 0.
  ;; Exercises: walk_const.wat — $lower_var_ref (RGlobal branch).
  ;;
  ;; Eight interrogations:
  ;;   Graph?      $lower_init (empty env) ensures no binding for "y"; the VarRef
  ;;               node's own handle ($walk_expr_node_handle) is what LGlobal field 0
  ;;               carries. Graph is consulted indirectly by $ls_lookup_local (which
  ;;               finds nothing) and $ls_lookup_or_capture (env_contains("y") == 0).
  ;;   Handler?    Direct call to $lower_var_ref (seed Tier-7 base).
  ;;   Verb?       N/A — sequential.
  ;;   Row?        N/A.
  ;;   Ownership?  No LOCAL_ENTRY or CAPTURE_ENTRY allocated (early -1 return);
  ;;               LGlobal is fresh `own` from bump allocator.
  ;;   Refinement? None.
  ;;   Gradient?   VarRef → LGlobal when no binding exists — the "global reference"
  ;;               gradient step. Future Hβ.lower.varref-schemekind-dispatch will
  ;;               short-circuit constructor globals to LMakeVariant instead.
  ;;   Reason?     VarRef's AST handle carries the GNode Reason chain; LGlobal
  ;;               preserves it at field 0 for downstream $lexpr_handle consumers.

  (data (i32.const 3072) "\05\00\00\00PASS:")
  (data (i32.const 3084) "\05\00\00\00FAIL:")
  (data (i32.const 3096) "\01\00\00\00 ")
  (data (i32.const 3104) "\01\00\00\00\0a")
  (data (i32.const 3120) "\21\00\00\00lower_walk_const_var_ref_global ")

  ;; "y" as a length-prefixed flat string: len=1, byte='y'=0x79
  (data (i32.const 3160) "\01\00\00\00y")

  (data (i32.const 3172) "\1c\00\00\00varref-global-tag-not-302")
  (data (i32.const 3204) "\22\00\00\00varref-global-name-not-y")
  (data (i32.const 3236) "\26\00\00\00varref-global-handle-mismatch")

  (func $_start (export "_start")
    (local $failed i32)
    (local $node i32)
    (local $r i32)
    (local $expected_h i32)
    (local $lglobal_name i32)
    (local.set $failed (i32.const 0))

    ;; Phase 1: init with empty state (no bindings — "y" is unbound).
    (call $lower_init)
    (call $graph_init)

    ;; Phase 2: build VarRef("y") AST → nexpr → N-wrapper.
    (local.set $node
      (call $nexpr
        (call $mk_VarRef (i32.const 3160))
        (i32.const 0)))

    ;; Capture the VarRef node's own AST handle (offset 12 of N-wrapper).
    (local.set $expected_h (i32.load offset=12 (local.get $node)))

    ;; Phase 3: lower — should take the RGlobal branch since "y" is not bound.
    (local.set $r (call $lower_var_ref (local.get $node)))

    ;; Verify tag == 302 (LGLOBAL_TAG).
    (if (i32.ne (call $tag_of (local.get $r)) (i32.const 302))
      (then
        (call $eprint_string (i32.const 3172))
        (call $eprint_string (i32.const 3104))
        (local.set $failed (i32.const 1))))

    ;; Verify name field string-equals "y".
    (local.set $lglobal_name (call $lexpr_lglobal_name (local.get $r)))
    (if (i32.eqz (call $str_eq (local.get $lglobal_name) (i32.const 3160)))
      (then
        (call $eprint_string (i32.const 3204))
        (call $eprint_string (i32.const 3104))
        (local.set $failed (i32.const 1))))

    ;; Verify handle field == expected_h (the VarRef's own AST handle from nexpr).
    (if (i32.ne (call $lexpr_handle (local.get $r)) (local.get $expected_h))
      (then
        (call $eprint_string (i32.const 3236))
        (call $eprint_string (i32.const 3104))
        (local.set $failed (i32.const 1))))

    ;; Verdict.
    (if (local.get $failed)
      (then
        (call $eprint_string (i32.const 3084))
        (call $eprint_string (i32.const 3096))
        (call $eprint_string (i32.const 3120))
        (call $eprint_string (i32.const 3104))
        (call $wasi_proc_exit (i32.const 1)))
      (else
        (call $eprint_string (i32.const 3072))
        (call $eprint_string (i32.const 3096))
        (call $eprint_string (i32.const 3120))
        (call $eprint_string (i32.const 3104))
        (call $wasi_proc_exit (i32.const 0)))))
