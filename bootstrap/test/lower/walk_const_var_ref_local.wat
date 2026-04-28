  ;; ═══ walk_const_var_ref_local.wat — Hβ.lower trace-harness ═════════════
  ;; Executes: Hβ-lower-substrate.md §4.2 VarRef-RLocal arm + Lock #1 proof —
  ;;           LLocal carries the binding-time ty_handle (from $ls_bind_local),
  ;;           NOT the VarRef's own AST handle.
  ;; Exercises: walk_const.wat — $lower_var_ref (RLocal branch).
  ;;
  ;; Eight interrogations:
  ;;   Graph?      $graph_fresh_ty allocates the binding-site TypeHandle stored
  ;;               in LOCAL_ENTRY field 2; $walk_expr_node_handle reads the VarRef
  ;;               AST handle (different from ty_h). Lock #1 verifies the distinction.
  ;;   Handler?    Direct call to $lower_var_ref (seed Tier-7 base).
  ;;   Verb?       N/A — sequential.
  ;;   Row?        N/A — VarRef carries no row at this chunk.
  ;;   Ownership?  $ls_bind_local writes LOCAL_ENTRY `own` into the ledger;
  ;;               $lower_var_ref reads it `ref`; LLocal is new `own` from alloc.
  ;;   Refinement? None.
  ;;   Gradient?   Lock #1 proof: LLocal field 0 == ty_h (binding-site handle),
  ;;               not the VarRef's fresh AST handle. This IS the gradient cash-out
  ;;               of inference's scope-resolution win.
  ;;   Reason?     $graph_fresh_ty records reason 0 sentinel; not surfaced here.

  (data (i32.const 3072) "\05\00\00\00PASS:")
  (data (i32.const 3084) "\05\00\00\00FAIL:")
  (data (i32.const 3096) "\01\00\00\00 ")
  (data (i32.const 3104) "\01\00\00\00\0a")
  (data (i32.const 3120) "\20\00\00\00lower_walk_const_var_ref_local ")

  ;; "x" as a length-prefixed flat string: len=1, byte='x'=0x78
  (data (i32.const 3160) "\01\00\00\00x")

  (data (i32.const 3172) "\1b\00\00\00varref-local-tag-not-301")
  (data (i32.const 3204) "\21\00\00\00varref-local-name-not-x")
  (data (i32.const 3236) "\24\00\00\00varref-local-handle-not-ty_h")

  (func $_start (export "_start")
    (local $failed i32)
    (local $ty_h i32)
    (local $node i32)
    (local $r i32)
    (local $llocal_name i32)
    (local.set $failed (i32.const 0))
    (call $lower_init)
    (call $graph_init)

    ;; Phase 1: allocate a fresh TypeHandle (the binding-site handle).
    (local.set $ty_h (call $graph_fresh_ty (i32.const 0)))

    ;; Phase 2: bind "x" as a local with ty_h as its TypeHandle.
    ;; $ls_bind_local(name_str_ptr, ty_handle) → slot (0).
    (drop (call $ls_bind_local (i32.const 3160) (local.get $ty_h)))

    ;; Phase 3: build VarRef("x") AST → wrap in nexpr → N-wrapper.
    (local.set $node
      (call $nexpr
        (call $mk_VarRef (i32.const 3160))
        (i32.const 0)))

    ;; Phase 4: lower the VarRef node — should take the RLocal branch.
    (local.set $r (call $lower_var_ref (local.get $node)))

    ;; Verify tag == 301 (LLOCAL_TAG).
    (if (i32.ne (call $tag_of (local.get $r)) (i32.const 301))
      (then
        (call $eprint_string (i32.const 3172))
        (call $eprint_string (i32.const 3104))
        (local.set $failed (i32.const 1))))

    ;; Verify name field string-equals "x".
    (local.set $llocal_name (call $lexpr_llocal_name (local.get $r)))
    (if (i32.eqz (call $str_eq (local.get $llocal_name) (i32.const 3160)))
      (then
        (call $eprint_string (i32.const 3204))
        (call $eprint_string (i32.const 3104))
        (local.set $failed (i32.const 1))))

    ;; Verify handle field == ty_h — proves Lock #1.
    ;; LLocal field 0 must be the BINDING-SITE handle (ty_h from $ls_bind_local),
    ;; NOT the VarRef's own fresh AST handle.
    (if (i32.ne (call $lexpr_handle (local.get $r)) (local.get $ty_h))
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
