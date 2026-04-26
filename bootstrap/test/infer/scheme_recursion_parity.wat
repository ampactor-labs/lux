  ;; ═══ scheme_recursion_parity.wat — trace-harness ══════════════════
  ;; Executes: ROADMAP §3 acceptance ($free_in_params / $free_in_fields
  ;;           / $ty_substitute_params / $ty_substitute_fields parity
  ;;           with src/infer.nx:1898-1990) + scheme.wat:587-651
  ;; Exercises: scheme.wat — $free_in_params $free_in_fields
  ;;            $ty_substitute_params $ty_substitute_fields
  ;; Per ROADMAP §5 + Hβ-infer-substrate.md §11.
  ;;
  ;; ─── Eight interrogations ─────────────────────────────────────────
  ;;   Graph?      Operates on TParam + field-pair record lists; no graph touch.
  ;;   Handler?    Direct walker calls.
  ;;   Verb?       N/A.
  ;;   Row?        Pure.
  ;;   Ownership?  $ty_substitute_params preserves authored + resolved
  ;;               Ownership sentinels verbatim per scheme.wat:822-828.
  ;;   Refinement? Authored / resolved Ownership ARE the per-param
  ;;               refinement; we assert preservation across substitution.
  ;;   Gradient?   ROADMAP §3 closure — earlier opaque-param treatment
  ;;               replaced with canonical recursion.
  ;;   Reason?     N/A.

  (data (i32.const 3072) "\05\00\00\00PASS:")
  (data (i32.const 3084) "\05\00\00\00FAIL:")
  (data (i32.const 3096) "\01\00\00\00 ")
  (data (i32.const 3104) "\01\00\00\00\0a")

  (data (i32.const 3120) "\14\00\00\00scheme_recursion_par")

  (data (i32.const 3144) "\10\00\00\00params-len-2    ")
  (data (i32.const 3168) "\14\00\00\00params-elem0-handle ")
  (data (i32.const 3192) "\14\00\00\00params-elem1-handle ")
  (data (i32.const 3216) "\10\00\00\00fields-len-2    ")
  (data (i32.const 3240) "\14\00\00\00fields-elem0-handle ")
  (data (i32.const 3264) "\14\00\00\00fields-elem1-handle ")
  (data (i32.const 3288) "\18\00\00\00params-subst-elem0-name ")
  (data (i32.const 3320) "\18\00\00\00params-subst-elem0-ty   ")
  (data (i32.const 3352) "\1b\00\00\00params-subst-elem0-author  ")
  (data (i32.const 3384) "\1b\00\00\00params-subst-elem0-resolve ")
  (data (i32.const 3416) "\18\00\00\00params-subst-elem1-name ")
  (data (i32.const 3448) "\18\00\00\00params-subst-elem1-ty   ")
  (data (i32.const 3480) "\1b\00\00\00params-subst-elem1-author  ")
  (data (i32.const 3512) "\1b\00\00\00params-subst-elem1-resolve ")
  (data (i32.const 3544) "\18\00\00\00fields-subst-elem0-name ")
  (data (i32.const 3576) "\18\00\00\00fields-subst-elem0-ty   ")
  (data (i32.const 3608) "\18\00\00\00fields-subst-elem1-name ")
  (data (i32.const 3640) "\18\00\00\00fields-subst-elem1-ty   ")

  ;; Static name strings
  (data (i32.const 3680) "\01\00\00\00a")
  (data (i32.const 3688) "\01\00\00\00b")
  (data (i32.const 3696) "\01\00\00\00x")
  (data (i32.const 3704) "\01\00\00\00y")

  (func $_start (export "_start")
    (local $failed i32)
    (local $tv5 i32) (local $tv11 i32)
    (local $params i32) (local $fields i32) (local $free i32)
    (local $own_inf i32) (local $own_own i32)
    (local $map i32)
    (local $params_out i32) (local $fields_out i32)
    (local $p i32) (local $f i32)
    (local.set $failed (i32.const 0))
    (call $graph_init)

    (local.set $tv5 (call $ty_make_tvar (i32.const 5)))
    (local.set $tv11 (call $ty_make_tvar (i32.const 11)))
    (local.set $own_inf (call $ownership_make_inferred))
    (local.set $own_own (call $ownership_make_own))

    ;; Build params [TParam("a", TVar(5), Inferred, Inferred),
    ;;               TParam("b", TVar(11), Own, Own)]
    (local.set $params (call $make_list (i32.const 2)))
    (drop (call $list_set (local.get $params) (i32.const 0)
            (call $tparam_make (i32.const 3680) (local.get $tv5)
                               (local.get $own_inf) (local.get $own_inf))))
    (drop (call $list_set (local.get $params) (i32.const 1)
            (call $tparam_make (i32.const 3688) (local.get $tv11)
                               (local.get $own_own) (local.get $own_own))))

    ;; ── $free_in_params(params) length 2, [5, 11] ──
    (local.set $free (call $free_in_params (local.get $params)))
    (if (i32.ne (call $len (local.get $free)) (i32.const 2))
      (then
        (call $eprint_string (i32.const 3144))
        (call $eprint_string (i32.const 3104))
        (local.set $failed (i32.const 1))))
    (if (i32.ne (call $list_index (local.get $free) (i32.const 0)) (i32.const 5))
      (then
        (call $eprint_string (i32.const 3168))
        (call $eprint_string (i32.const 3104))
        (local.set $failed (i32.const 1))))
    (if (i32.ne (call $list_index (local.get $free) (i32.const 1)) (i32.const 11))
      (then
        (call $eprint_string (i32.const 3192))
        (call $eprint_string (i32.const 3104))
        (local.set $failed (i32.const 1))))

    ;; Build fields [("x", TVar(5)), ("y", TVar(11))]
    (local.set $fields (call $make_list (i32.const 2)))
    (drop (call $list_set (local.get $fields) (i32.const 0)
            (call $field_pair_make (i32.const 3696) (local.get $tv5))))
    (drop (call $list_set (local.get $fields) (i32.const 1)
            (call $field_pair_make (i32.const 3704) (local.get $tv11))))

    ;; ── $free_in_fields(fields) length 2, [5, 11] ──
    (local.set $free (call $free_in_fields (local.get $fields)))
    (if (i32.ne (call $len (local.get $free)) (i32.const 2))
      (then
        (call $eprint_string (i32.const 3216))
        (call $eprint_string (i32.const 3104))
        (local.set $failed (i32.const 1))))
    (if (i32.ne (call $list_index (local.get $free) (i32.const 0)) (i32.const 5))
      (then
        (call $eprint_string (i32.const 3240))
        (call $eprint_string (i32.const 3104))
        (local.set $failed (i32.const 1))))
    (if (i32.ne (call $list_index (local.get $free) (i32.const 1)) (i32.const 11))
      (then
        (call $eprint_string (i32.const 3264))
        (call $eprint_string (i32.const 3104))
        (local.set $failed (i32.const 1))))

    ;; Build map [(5 → 555), (11 → 1111)]
    (local.set $map (call $subst_map_make))
    (local.set $map (call $subst_map_extend (local.get $map) (i32.const 0)
                                            (i32.const 5) (i32.const 555)))
    (local.set $map (call $subst_map_extend (local.get $map) (i32.const 1)
                                            (i32.const 11) (i32.const 1111)))

    ;; ── $ty_substitute_params: name preserved, ty handle replaced,
    ;;    both ownerships preserved verbatim per element ──
    (local.set $params_out (call $ty_substitute_params (local.get $params)
                                                       (local.get $map) (i32.const 2)))
    (local.set $p (call $list_index (local.get $params_out) (i32.const 0)))
    (if (i32.ne (call $tparam_name (local.get $p)) (i32.const 3680))
      (then
        (call $eprint_string (i32.const 3288))
        (call $eprint_string (i32.const 3104))
        (local.set $failed (i32.const 1))))
    (if (i32.ne (call $ty_tvar_handle (call $tparam_ty (local.get $p))) (i32.const 555))
      (then
        (call $eprint_string (i32.const 3320))
        (call $eprint_string (i32.const 3104))
        (local.set $failed (i32.const 1))))
    (if (i32.eqz (call $is_ownership_inferred (call $tparam_authored (local.get $p))))
      (then
        (call $eprint_string (i32.const 3352))
        (call $eprint_string (i32.const 3104))
        (local.set $failed (i32.const 1))))
    (if (i32.eqz (call $is_ownership_inferred (call $tparam_resolved (local.get $p))))
      (then
        (call $eprint_string (i32.const 3384))
        (call $eprint_string (i32.const 3104))
        (local.set $failed (i32.const 1))))

    (local.set $p (call $list_index (local.get $params_out) (i32.const 1)))
    (if (i32.ne (call $tparam_name (local.get $p)) (i32.const 3688))
      (then
        (call $eprint_string (i32.const 3416))
        (call $eprint_string (i32.const 3104))
        (local.set $failed (i32.const 1))))
    (if (i32.ne (call $ty_tvar_handle (call $tparam_ty (local.get $p))) (i32.const 1111))
      (then
        (call $eprint_string (i32.const 3448))
        (call $eprint_string (i32.const 3104))
        (local.set $failed (i32.const 1))))
    (if (i32.eqz (call $is_ownership_own (call $tparam_authored (local.get $p))))
      (then
        (call $eprint_string (i32.const 3480))
        (call $eprint_string (i32.const 3104))
        (local.set $failed (i32.const 1))))
    (if (i32.eqz (call $is_ownership_own (call $tparam_resolved (local.get $p))))
      (then
        (call $eprint_string (i32.const 3512))
        (call $eprint_string (i32.const 3104))
        (local.set $failed (i32.const 1))))

    ;; ── $ty_substitute_fields: name preserved, ty handle replaced ──
    (local.set $fields_out (call $ty_substitute_fields (local.get $fields)
                                                       (local.get $map) (i32.const 2)))
    (local.set $f (call $list_index (local.get $fields_out) (i32.const 0)))
    (if (i32.ne (call $field_pair_name (local.get $f)) (i32.const 3696))
      (then
        (call $eprint_string (i32.const 3544))
        (call $eprint_string (i32.const 3104))
        (local.set $failed (i32.const 1))))
    (if (i32.ne (call $ty_tvar_handle (call $field_pair_ty (local.get $f))) (i32.const 555))
      (then
        (call $eprint_string (i32.const 3576))
        (call $eprint_string (i32.const 3104))
        (local.set $failed (i32.const 1))))

    (local.set $f (call $list_index (local.get $fields_out) (i32.const 1)))
    (if (i32.ne (call $field_pair_name (local.get $f)) (i32.const 3704))
      (then
        (call $eprint_string (i32.const 3608))
        (call $eprint_string (i32.const 3104))
        (local.set $failed (i32.const 1))))
    (if (i32.ne (call $ty_tvar_handle (call $field_pair_ty (local.get $f))) (i32.const 1111))
      (then
        (call $eprint_string (i32.const 3640))
        (call $eprint_string (i32.const 3104))
        (local.set $failed (i32.const 1))))

    ;; ── Verdict ──
    (if (local.get $failed)
      (then
        (call $eprint_string (i32.const 3084))
        (call $eprint_string (i32.const 3096))
        (call $eprint_string (i32.const 3120)))
      (else
        (call $eprint_string (i32.const 3072))
        (call $eprint_string (i32.const 3096))
        (call $eprint_string (i32.const 3120))))
    (call $eprint_string (i32.const 3104))
    (call $wasi_proc_exit (i32.const 0)))
