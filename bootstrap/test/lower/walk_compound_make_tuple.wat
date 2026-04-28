  ;; ═══ walk_compound_make_tuple.wat — Hβ.lower trace-harness ═════════
  ;; Executes: §4.2 — MakeTupleExpr([LitInt(7), LitInt(8)])
  ;;           lowers to LMakeTuple(h, lo_elems) tag 317; elems length 2.

  (data (i32.const 3072) "\05\00\00\00PASS:")
  (data (i32.const 3084) "\05\00\00\00FAIL:")
  (data (i32.const 3096) "\01\00\00\00 ")
  (data (i32.const 3104) "\01\00\00\00\0a")
  (data (i32.const 3120) "\1b\00\00\00walk_compound_make_tuple  ")
  (data (i32.const 3160) "\15\00\00\00not-LMAKETUPLE-317  ")
  (data (i32.const 3192) "\14\00\00\00elems-len-not-2     ")

  (func $_start (export "_start")
    (local $failed i32)
    (local $e1 i32) (local $e2 i32)
    (local $elems i32) (local $tup_struct i32) (local $tup_node i32)
    (local $r i32) (local $lo_elems i32)
    (local.set $failed (i32.const 0))
    (call $graph_init)
    (call $env_init)
    (call $lower_init)

    ;; Two element nodes.
    (local.set $e1 (call $nexpr (call $mk_LitInt (i32.const 7)) (i32.const 0)))
    (local.set $e2 (call $nexpr (call $mk_LitInt (i32.const 8)) (i32.const 0)))

    ;; Build elems list via buffer-counter (Ω.3).
    (local.set $elems (call $make_list (i32.const 0)))
    (local.set $elems (call $list_extend_to (local.get $elems) (i32.const 2)))
    (drop (call $list_set (local.get $elems) (i32.const 0) (local.get $e1)))
    (drop (call $list_set (local.get $elems) (i32.const 1) (local.get $e2)))

    ;; MakeTupleExpr via mk_MakeTupleExpr (parser_compound.wat:70).
    (local.set $tup_struct (call $mk_MakeTupleExpr (local.get $elems)))
    (local.set $tup_node   (call $nexpr (local.get $tup_struct) (i32.const 0)))

    (local.set $r (call $lower_make_tuple (local.get $tup_node)))

    ;; Outer must be LMakeTuple (tag 317).
    (if (i32.ne (call $tag_of (local.get $r)) (i32.const 317))
      (then
        (call $eprint_string (i32.const 3160))
        (call $eprint_string (i32.const 3104))
        (local.set $failed (i32.const 1))))

    ;; elems list length must be 2.
    (local.set $lo_elems (call $lexpr_lmaketuple_elems (local.get $r)))
    (if (i32.ne (call $len (local.get $lo_elems)) (i32.const 2))
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
