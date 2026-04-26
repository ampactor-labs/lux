  ;; ═══ scheme_subst_map.wat — trace-harness ═════════════════════════
  ;; Executes: scheme.wat:351-415 substitution-map trio +
  ;;           src/infer.nx:1993-1998 find_mapping -1-absent sentinel
  ;; Exercises: scheme.wat — $subst_map_make $subst_map_extend
  ;;            $subst_map_lookup $subst_pair_make $subst_pair_old
  ;;            $subst_pair_fresh
  ;; Per ROADMAP §5 + Hβ-infer-substrate.md §11.
  ;;
  ;; ─── Eight interrogations ─────────────────────────────────────────
  ;;   Graph?      No graph touch — substitution map is private to
  ;;               $instantiate's per-call walk.
  ;;   Handler?    Direct calls; no handler routing.
  ;;   Verb?       N/A.
  ;;   Row?        Pure.
  ;;   Ownership?  Map own; entries record-shape (drift-mode-7 audit).
  ;;   Refinement? -1 sentinel for absent IS the refinement of the
  ;;               linear-scan lookup.
  ;;   Gradient?   None at this level.
  ;;   Reason?     N/A.

  (data (i32.const 3072) "\05\00\00\00PASS:")
  (data (i32.const 3084) "\05\00\00\00FAIL:")
  (data (i32.const 3096) "\01\00\00\00 ")
  (data (i32.const 3104) "\01\00\00\00\0a")

  (data (i32.const 3120) "\14\00\00\00scheme_subst_map    ")

  (data (i32.const 3144) "\14\00\00\00empty-not-absent    ")
  (data (i32.const 3168) "\14\00\00\00single-lookup-7     ")
  (data (i32.const 3192) "\14\00\00\00single-absent-8     ")
  (data (i32.const 3216) "\14\00\00\00double-lookup-7     ")
  (data (i32.const 3240) "\14\00\00\00double-lookup-8     ")
  (data (i32.const 3264) "\10\00\00\00pair-old-wrong  ")
  (data (i32.const 3288) "\11\00\00\00pair-fresh-wrong ")

  (func $_start (export "_start")
    (local $failed i32) (local $map i32) (local $p i32)
    (local.set $failed (i32.const 0))
    (call $graph_init)

    (local.set $map (call $subst_map_make))

    ;; Empty map — lookup 7 returns -1 (signed)
    (if (i32.ge_s (call $subst_map_lookup (local.get $map) (i32.const 0) (i32.const 7))
                  (i32.const 0))
      (then
        (call $eprint_string (i32.const 3144))
        (call $eprint_string (i32.const 3104))
        (local.set $failed (i32.const 1))))

    ;; Extend (7 → 100); lookup 7 returns 100; lookup 8 returns -1
    (local.set $map (call $subst_map_extend (local.get $map) (i32.const 0)
                                            (i32.const 7) (i32.const 100)))
    (if (i32.ne (call $subst_map_lookup (local.get $map) (i32.const 1) (i32.const 7))
                (i32.const 100))
      (then
        (call $eprint_string (i32.const 3168))
        (call $eprint_string (i32.const 3104))
        (local.set $failed (i32.const 1))))
    (if (i32.ge_s (call $subst_map_lookup (local.get $map) (i32.const 1) (i32.const 8))
                  (i32.const 0))
      (then
        (call $eprint_string (i32.const 3192))
        (call $eprint_string (i32.const 3104))
        (local.set $failed (i32.const 1))))

    ;; Extend (8 → 200); both lookups distinct
    (local.set $map (call $subst_map_extend (local.get $map) (i32.const 1)
                                            (i32.const 8) (i32.const 200)))
    (if (i32.ne (call $subst_map_lookup (local.get $map) (i32.const 2) (i32.const 7))
                (i32.const 100))
      (then
        (call $eprint_string (i32.const 3216))
        (call $eprint_string (i32.const 3104))
        (local.set $failed (i32.const 1))))
    (if (i32.ne (call $subst_map_lookup (local.get $map) (i32.const 2) (i32.const 8))
                (i32.const 200))
      (then
        (call $eprint_string (i32.const 3240))
        (call $eprint_string (i32.const 3104))
        (local.set $failed (i32.const 1))))

    ;; Pair accessors round-trip
    (local.set $p (call $subst_pair_make (i32.const 5) (i32.const 50)))
    (if (i32.ne (call $subst_pair_old (local.get $p)) (i32.const 5))
      (then
        (call $eprint_string (i32.const 3264))
        (call $eprint_string (i32.const 3104))
        (local.set $failed (i32.const 1))))
    (if (i32.ne (call $subst_pair_fresh (local.get $p)) (i32.const 50))
      (then
        (call $eprint_string (i32.const 3288))
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
