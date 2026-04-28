  ;; ═══ walk_compound_field.wat — Hβ.lower trace-harness ══════════════
  ;; Executes: §4.2 + Lock #4 — FieldExpr(LitInt(0), "x")
  ;;           lowers to LFieldLoad(h, lo_rec, 0) tag 334;
  ;;           offset_bytes returns 0 per Lock #4 sentinel.

  (data (i32.const 3072) "\05\00\00\00PASS:")
  (data (i32.const 3084) "\05\00\00\00FAIL:")
  (data (i32.const 3096) "\01\00\00\00 ")
  (data (i32.const 3104) "\01\00\00\00\0a")
  (data (i32.const 3120) "\18\00\00\00walk_compound_field     ")
  (data (i32.const 3152) "\15\00\00\00not-LFIELDLOAD-334  ")
  (data (i32.const 3184) "\14\00\00\00offset-not-0-seed   ")
  ;; field name "x" — placeholder; threaded-not-compared per Lock #4.
  (data (i32.const 3216) "\01\00\00\00x")

  (func $_start (export "_start")
    (local $failed i32)
    (local $rec_lit i32) (local $rec_node i32)
    (local $field_name i32) (local $field_struct i32) (local $field_node i32)
    (local $r i32)
    (local.set $failed (i32.const 0))
    (call $graph_init)
    (call $env_init)
    (call $lower_init)

    ;; rec: LitInt(0) — placeholder record node.
    (local.set $rec_lit  (call $mk_LitInt (i32.const 0)))
    (local.set $rec_node (call $nexpr (local.get $rec_lit) (i32.const 0)))

    ;; field_name: "x" string at data segment 3216.
    (local.set $field_name (i32.const 3216))

    ;; FieldExpr [tag=100][rec_node][field_name_str] — Lock #9 direct alloc.
    (local.set $field_struct (call $alloc (i32.const 12)))
    (i32.store          (local.get $field_struct) (i32.const 100))
    (i32.store offset=4 (local.get $field_struct) (local.get $rec_node))
    (i32.store offset=8 (local.get $field_struct) (local.get $field_name))
    (local.set $field_node (call $nexpr (local.get $field_struct) (i32.const 0)))

    (local.set $r (call $lower_field (local.get $field_node)))

    ;; Outer must be LFieldLoad (tag 334).
    (if (i32.ne (call $tag_of (local.get $r)) (i32.const 334))
      (then
        (call $eprint_string (i32.const 3152))
        (call $eprint_string (i32.const 3104))
        (local.set $failed (i32.const 1))))

    ;; offset_bytes must be 0 per Lock #4 sentinel.
    (if (i32.ne (call $lexpr_lfieldload_offset_bytes (local.get $r)) (i32.const 0))
      (then
        (call $eprint_string (i32.const 3184))
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
