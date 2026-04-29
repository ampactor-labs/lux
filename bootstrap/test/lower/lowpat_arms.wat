  ;; ═══ lowpat_arms.wat — Hβ.lower Phase C.2 trace-harness ══════════════
  ;; Exercises: lowpat.wat — all 9 LowPat variants + LPArm constructor
  ;; and accessor roundtrip. Verifies tag values, $lowpat_handle
  ;; universal extractor, and per-variant field extraction.

  (data (i32.const 3072) "\05\00\00\00PASS:")
  (data (i32.const 3084) "\05\00\00\00FAIL:")
  (data (i32.const 3096) "\01\00\00\00 ")
  (data (i32.const 3104) "\01\00\00\00\0a")
  (data (i32.const 3120) "\0c\00\00\00lowpat_arms ")

  (func $_start (export "_start")
    (local $failed i32)
    (local $r i32)
    (local.set $failed (i32.const 0))

    ;; ── LPVar(h=10, name=20) ─────────────────────────────────────────
    (local.set $r (call $lowpat_make_lpvar (i32.const 10) (i32.const 20)))
    (if (i32.ne (call $tag_of (local.get $r)) (i32.const 360))
      (then (local.set $failed (i32.const 1))))
    (if (i32.ne (call $lowpat_handle (local.get $r)) (i32.const 10))
      (then (local.set $failed (i32.const 1))))
    (if (i32.ne (call $lowpat_lpvar_name (local.get $r)) (i32.const 20))
      (then (local.set $failed (i32.const 1))))

    ;; ── LPWild(h=11) ─────────────────────────────────────────────────
    (local.set $r (call $lowpat_make_lpwild (i32.const 11)))
    (if (i32.ne (call $tag_of (local.get $r)) (i32.const 361))
      (then (local.set $failed (i32.const 1))))
    (if (i32.ne (call $lowpat_handle (local.get $r)) (i32.const 11))
      (then (local.set $failed (i32.const 1))))

    ;; ── LPLit(h=12, value=30) ────────────────────────────────────────
    (local.set $r (call $lowpat_make_lplit (i32.const 12) (i32.const 30)))
    (if (i32.ne (call $tag_of (local.get $r)) (i32.const 362))
      (then (local.set $failed (i32.const 1))))
    (if (i32.ne (call $lowpat_lplit_value (local.get $r)) (i32.const 30))
      (then (local.set $failed (i32.const 1))))

    ;; ── LPCon(h=13, tag_id=5, args=40) ──────────────────────────────
    (local.set $r (call $lowpat_make_lpcon (i32.const 13) (i32.const 5) (i32.const 40)))
    (if (i32.ne (call $tag_of (local.get $r)) (i32.const 363))
      (then (local.set $failed (i32.const 1))))
    (if (i32.ne (call $lowpat_lpcon_tag_id (local.get $r)) (i32.const 5))
      (then (local.set $failed (i32.const 1))))
    (if (i32.ne (call $lowpat_lpcon_args (local.get $r)) (i32.const 40))
      (then (local.set $failed (i32.const 1))))

    ;; ── LPTuple(h=14, elems=50) ──────────────────────────────────────
    (local.set $r (call $lowpat_make_lptuple (i32.const 14) (i32.const 50)))
    (if (i32.ne (call $tag_of (local.get $r)) (i32.const 364))
      (then (local.set $failed (i32.const 1))))
    (if (i32.ne (call $lowpat_lptuple_elems (local.get $r)) (i32.const 50))
      (then (local.set $failed (i32.const 1))))

    ;; ── LPList(h=15, elems=60, rest=70) ──────────────────────────────
    (local.set $r (call $lowpat_make_lplist (i32.const 15) (i32.const 60) (i32.const 70)))
    (if (i32.ne (call $tag_of (local.get $r)) (i32.const 365))
      (then (local.set $failed (i32.const 1))))
    (if (i32.ne (call $lowpat_lplist_elems (local.get $r)) (i32.const 60))
      (then (local.set $failed (i32.const 1))))
    (if (i32.ne (call $lowpat_lplist_rest (local.get $r)) (i32.const 70))
      (then (local.set $failed (i32.const 1))))

    ;; ── LPRecord(h=16, fields=80, rest=0) ────────────────────────────
    (local.set $r (call $lowpat_make_lprecord (i32.const 16) (i32.const 80) (i32.const 0)))
    (if (i32.ne (call $tag_of (local.get $r)) (i32.const 366))
      (then (local.set $failed (i32.const 1))))
    (if (i32.ne (call $lowpat_lprecord_fields (local.get $r)) (i32.const 80))
      (then (local.set $failed (i32.const 1))))
    (if (i32.ne (call $lowpat_lprecord_rest (local.get $r)) (i32.const 0))
      (then (local.set $failed (i32.const 1))))

    ;; ── LPAlt(h=17, branches=90) ────────────────────────────────────
    (local.set $r (call $lowpat_make_lpalt (i32.const 17) (i32.const 90)))
    (if (i32.ne (call $tag_of (local.get $r)) (i32.const 367))
      (then (local.set $failed (i32.const 1))))
    (if (i32.ne (call $lowpat_lpalt_branches (local.get $r)) (i32.const 90))
      (then (local.set $failed (i32.const 1))))

    ;; ── LPAs(h=18, name=100, pat=110) ───────────────────────────────
    (local.set $r (call $lowpat_make_lpas (i32.const 18) (i32.const 100) (i32.const 110)))
    (if (i32.ne (call $tag_of (local.get $r)) (i32.const 368))
      (then (local.set $failed (i32.const 1))))
    (if (i32.ne (call $lowpat_lpas_name (local.get $r)) (i32.const 100))
      (then (local.set $failed (i32.const 1))))
    (if (i32.ne (call $lowpat_lpas_pat (local.get $r)) (i32.const 110))
      (then (local.set $failed (i32.const 1))))

    ;; ── LPArm(pat=200, body=300) ────────────────────────────────────
    (local.set $r (call $lowpat_make_lparm (i32.const 200) (i32.const 300)))
    (if (i32.ne (call $tag_of (local.get $r)) (i32.const 369))
      (then (local.set $failed (i32.const 1))))
    ;; LPArm has NO handle — $lowpat_handle returns 0.
    (if (i32.ne (call $lowpat_handle (local.get $r)) (i32.const 0))
      (then (local.set $failed (i32.const 1))))
    (if (i32.ne (call $lowpat_lparm_pat (local.get $r)) (i32.const 200))
      (then (local.set $failed (i32.const 1))))
    (if (i32.ne (call $lowpat_lparm_body (local.get $r)) (i32.const 300))
      (then (local.set $failed (i32.const 1))))

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
