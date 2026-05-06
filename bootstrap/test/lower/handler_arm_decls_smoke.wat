  ;; ═══ handler_arm_decls_smoke.wat — Hβ.first-light trace harness ════
  ;; Per Hβ-first-light.lower-handler-arm-decls.md §B.9 + §B.10 (E.1).
  ;;
  ;; Verifies the four emit-side walks pick up LDeclareFn (313) entries
  ;; produced by $lower_handler_arms_as_decls (walk_handle.wat:263-297).
  ;;
  ;; Construction: hand-built single-element list containing one
  ;; LDeclareFn(LowFn("op_test", 1, ["arg"], [LConst(h, 7)], Pure)).
  ;; Then exercise each walk in turn:
  ;;
  ;;   Phase 1: $collect_fn_names — name list contains "op_test"
  ;;            (proves $cfn_walk's tag-313 arm fires + appends per
  ;;             Lock #1 LDeclareFn-symmetric-to-LMakeClosure).
  ;;   Phase 2: $emit_functions — output buffer contains "(func $op_test"
  ;;            (proves $emit_functions_walk's tag-313 arm calls
  ;;             $emit_fn_body per Lock #1).
  ;;   Phase 3: $max_arity_expr — returns >= 2 (proves the arity
  ;;            ceiling walk descends LDeclareFn; arity=1 + 1 implicit
  ;;            __state per W7 calling convention).

  (data (i32.const 3072) "\05\00\00\00PASS:")
  (data (i32.const 3084) "\05\00\00\00FAIL:")
  (data (i32.const 3096) "\01\00\00\00 ")
  (data (i32.const 3104) "\01\00\00\00\0a")
  (data (i32.const 3120) "\1a\00\00\00handler_arm_decls_smoke   ")

  (data (i32.const 3168) "\1a\00\00\00phase1-name-count-bad     ")
  (data (i32.const 3196) "\1a\00\00\00phase1-name-string-bad    ")
  (data (i32.const 3224) "\1a\00\00\00phase2-out-pos-zero       ")
  (data (i32.const 3252) "\1a\00\00\00phase2-func-substring-bad ")
  (data (i32.const 3280) "\1a\00\00\00phase3-max-arity-bad      ")

  ;; Strings consumed by lowfn_make + str_eq.
  (data (i32.const 3616) "\03\00\00\00arg")
  (data (i32.const 3624) "\07\00\00\00op_test")

  ;; Phase 2 needle: "(func $op_test" — 14 ASCII bytes (no trailing
  ;; nul). Stored length-prefixed for $contains_substring.
  (data (i32.const 4096) "\0e\00\00\00(func $op_test")

  (func $_start (export "_start")
    (local $failed i32)
    (local $h i32) (local $body_lc i32) (local $body_list i32)
    (local $params i32) (local $fn_ir i32) (local $decl i32)
    (local $top i32) (local $names i32) (local $name_str i32)
    (local $max_arity i32)

    (local.set $failed (i32.const 0))

    (call $emit_init)
    (call $graph_init)

    ;; Fresh handle for the LowFn body's LConst.
    (local.set $h (call $graph_fresh_ty (call $reason_make_fresh (i32.const 0))))
    (call $graph_bind (local.get $h)
                      (call $ty_make_tint)
                      (call $reason_make_fresh (i32.const 0)))

    ;; LowFn body: [LConst(h, 7)]
    (local.set $body_lc (call $lexpr_make_lconst (local.get $h) (i32.const 7)))
    (local.set $body_list (call $make_list (i32.const 0)))
    (local.set $body_list (call $list_extend_to (local.get $body_list) (i32.const 1)))
    (drop (call $list_set (local.get $body_list) (i32.const 0) (local.get $body_lc)))

    ;; params = ["arg"]
    (local.set $params (call $make_list (i32.const 0)))
    (local.set $params (call $list_extend_to (local.get $params) (i32.const 1)))
    (drop (call $list_set (local.get $params) (i32.const 0) (i32.const 3616)))

    ;; LowFn(name="op_test", arity=1, params, body, row=Pure)
    (local.set $fn_ir
      (call $lowfn_make
        (i32.const 3624)
        (i32.const 1)
        (local.get $params)
        (local.get $body_list)
        (call $row_make_pure)))

    ;; LDeclareFn(fn_ir)
    (local.set $decl (call $lexpr_make_ldeclarefn (local.get $fn_ir)))

    ;; Top-level lowexprs = [LDeclareFn(...)]
    (local.set $top (call $make_list (i32.const 0)))
    (local.set $top (call $list_extend_to (local.get $top) (i32.const 1)))
    (drop (call $list_set (local.get $top) (i32.const 0) (local.get $decl)))

    ;; ── Phase 1: $collect_fn_names — exercises $cfn_walk LDeclareFn arm ──
    (local.set $names (call $collect_fn_names (local.get $top)))
    (if (i32.ne (i32.load (local.get $names)) (i32.const 1))
      (then (call $eprint_string (i32.const 3168))
            (call $eprint_string (i32.const 3104))
            (local.set $failed (i32.const 1))))
    (if (i32.eq (i32.load (local.get $names)) (i32.const 1))
      (then
        (local.set $name_str (call $list_index (local.get $names) (i32.const 0)))
        (if (i32.eqz (call $str_eq (local.get $name_str) (i32.const 3624)))
          (then (call $eprint_string (i32.const 3196))
                (call $eprint_string (i32.const 3104))
                (local.set $failed (i32.const 1))))))

    ;; ── Phase 2: $emit_functions — exercises $emit_functions_walk LDeclareFn arm ──
    (global.set $out_pos (i32.const 0))
    (call $emit_functions (local.get $top))
    (if (i32.eqz (global.get $out_pos))
      (then (call $eprint_string (i32.const 3224))
            (call $eprint_string (i32.const 3104))
            (local.set $failed (i32.const 1))))
    (if (i32.eqz (call $contains_substring_at_outbase (i32.const 4096)))
      (then (call $eprint_string (i32.const 3252))
            (call $eprint_string (i32.const 3104))
            (local.set $failed (i32.const 1))))

    ;; ── Phase 3: $max_arity_expr — exercises arity ceiling walk ──
    (local.set $max_arity (call $max_arity_expr (local.get $decl)))
    (if (i32.lt_s (local.get $max_arity) (i32.const 2))
      (then (call $eprint_string (i32.const 3280))
            (call $eprint_string (i32.const 3104))
            (local.set $failed (i32.const 1))))

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

  ;; ─── $contains_substring_at_outbase ──────────────────────────────────
  ;; Length-prefixed needle scan over the [out_base, out_base+out_pos)
  ;; window. Returns 1 iff the needle bytes appear at any offset in the
  ;; window. Substring search (not bytes_eq): $emit_functions emits a
  ;; full (func $op_test (param ...) (result ...) ...) declaration; we
  ;; verify the prefix appears, not that the full output matches.
  (func $contains_substring_at_outbase (param $needle i32) (result i32)
    (local $needle_len i32) (local $i i32) (local $j i32)
    (local $hay_byte i32) (local $needle_byte i32) (local $matched i32)
    (local.set $needle_len (i32.load (local.get $needle)))
    (if (i32.gt_u (local.get $needle_len) (global.get $out_pos))
      (then (return (i32.const 0))))
    (local.set $i (i32.const 0))
    (block $outer_done
      (loop $outer
        (br_if $outer_done
          (i32.gt_u (i32.add (local.get $i) (local.get $needle_len))
                    (global.get $out_pos)))
        (local.set $j (i32.const 0))
        (local.set $matched (i32.const 1))
        (block $inner_done
          (loop $inner
            (br_if $inner_done (i32.ge_u (local.get $j) (local.get $needle_len)))
            (local.set $hay_byte
              (i32.load8_u
                (i32.add (i32.add (global.get $out_base) (local.get $i))
                         (local.get $j))))
            (local.set $needle_byte
              (i32.load8_u
                (i32.add (i32.add (local.get $needle) (i32.const 4))
                         (local.get $j))))
            (if (i32.ne (local.get $hay_byte) (local.get $needle_byte))
              (then (local.set $matched (i32.const 0)) (br $inner_done)))
            (local.set $j (i32.add (local.get $j) (i32.const 1)))
            (br $inner)))
        (if (local.get $matched) (then (return (i32.const 1))))
        (local.set $i (i32.add (local.get $i) (i32.const 1)))
        (br $outer)))
    (i32.const 0))

