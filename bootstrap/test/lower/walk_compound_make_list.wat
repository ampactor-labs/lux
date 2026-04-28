  ;; ═══ walk_compound_make_list.wat — Hβ.lower trace-harness ══════════
  ;; Executes: §4.2 — MakeListExpr([LitInt(1), LitInt(2), LitInt(3)])
  ;;           lowers to LMakeList(h, lo_elems) tag 316; elems length 3.

  (data (i32.const 3072) "\05\00\00\00PASS:")
  (data (i32.const 3084) "\05\00\00\00FAIL:")
  (data (i32.const 3096) "\01\00\00\00 ")
  (data (i32.const 3104) "\01\00\00\00\0a")
  (data (i32.const 3120) "\1a\00\00\00walk_compound_make_list   ")
  (data (i32.const 3160) "\14\00\00\00not-LMAKELIST-316   ")
  (data (i32.const 3192) "\14\00\00\00elems-len-not-3     ")

  (func $_start (export "_start")
    (local $failed i32)
    (local $e1 i32) (local $e2 i32) (local $e3 i32)
    (local $elems i32) (local $list_struct i32) (local $list_node i32)
    (local $r i32) (local $lo_elems i32)
    (local.set $failed (i32.const 0))
    (call $graph_init)
    (call $env_init)
    (call $lower_init)

    ;; Three element nodes.
    (local.set $e1 (call $nexpr (call $mk_LitInt (i32.const 1)) (i32.const 0)))
    (local.set $e2 (call $nexpr (call $mk_LitInt (i32.const 2)) (i32.const 0)))
    (local.set $e3 (call $nexpr (call $mk_LitInt (i32.const 3)) (i32.const 0)))

    ;; Build elems list via buffer-counter (Ω.3).
    (local.set $elems (call $make_list (i32.const 0)))
    (local.set $elems (call $list_extend_to (local.get $elems) (i32.const 3)))
    (drop (call $list_set (local.get $elems) (i32.const 0) (local.get $e1)))
    (drop (call $list_set (local.get $elems) (i32.const 1) (local.get $e2)))
    (drop (call $list_set (local.get $elems) (i32.const 2) (local.get $e3)))

    ;; MakeListExpr via mk_MakeListExpr (parser_compound.wat:77).
    (local.set $list_struct (call $mk_MakeListExpr (local.get $elems)))
    (local.set $list_node   (call $nexpr (local.get $list_struct) (i32.const 0)))

    (local.set $r (call $lower_make_list (local.get $list_node)))

    ;; Outer must be LMakeList (tag 316).
    (if (i32.ne (call $tag_of (local.get $r)) (i32.const 316))
      (then
        (call $eprint_string (i32.const 3160))
        (call $eprint_string (i32.const 3104))
        (local.set $failed (i32.const 1))))

    ;; elems list length must be 3.
    (local.set $lo_elems (call $lexpr_lmakelist_elems (local.get $r)))
    (if (i32.ne (call $len (local.get $lo_elems)) (i32.const 3))
      (then
        (call $eprint_string (i32.const 3192))
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
