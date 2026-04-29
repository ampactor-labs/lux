  ;; ═══ parser_ast_shape_diag.wat — Hβ.infer parser-AST-shape diagnostic ═
  ;; Phase B (per deep-toasting-bachman plan): substrate-honest diagnostic
  ;; for the 0x2213838 OOB-load trap in $infer_program on real parser
  ;; output (per ba327c9 + 219f215 audits).
  ;;
  ;; The harness DRIVES the real lex+parse+infer pipeline on a minimal
  ;; real source `fn f(x) = x` (11 bytes; smallest possible function).
  ;; If this passes, the trap is shape-specific or pressure-specific —
  ;; grow the input. If it traps, the address localizes the bug.
  ;;
  ;; Per CLAUDE.md "Build the tool that tells you" — the harness IS
  ;; the diagnostic. We don't audit constructors by checklist (C/Java
  ;; pattern); we exercise the parser and walk what it produces,
  ;; asserting the sentinel-or-pointer invariant on every field.
  ;;
  ;; ─── Phase 1 — lex+parse round-trip ──────────────────────────────
  ;;   Source: `fn f(x) = x` at offset 5120. $lex returns (buf, count);
  ;;   $parse_program returns List<N>. Expect 1 N (the FnStmt).
  ;; ─── Phase 2 — N node shape ──────────────────────────────────────
  ;;   N is [tag=0][body][span][handle] — 16 bytes. body is at offset
  ;;   4. Verify it's a heap pointer (≥ 4096 AND < 32 MiB).
  ;; ─── Phase 3 — NStmt wrapper shape ──────────────────────────────
  ;;   body should be an NStmt: [tag=111][s]. s is at offset 4.
  ;; ─── Phase 4 — FnStmt body field-shape audit ────────────────────
  ;;   s should be a FnStmt: [tag=121][name][params][ret][effs][body].
  ;;   For each of the 5 payload fields, assert it's sentinel-or-
  ;;   heap-pointer (NEVER ≥ 32 MiB; that's the trap class).
  ;; ─── Phase 5 — drive $inka_infer ──────────────────────────────
  ;;   Call $inka_infer on the parsed list. If it returns without
  ;;   trap, the diagnostic confirms the AST is shape-valid for this
  ;;   minimal source.

  ;; Source string at offset 5120: len=11 + "fn f(x) = x"
  (data (i32.const 5120) "\0b\00\00\00fn f(x) = x")

  ;; Diagnostic labels.
  (data (i32.const 3072) "\05\00\00\00PASS:")
  (data (i32.const 3084) "\05\00\00\00FAIL:")
  (data (i32.const 3096) "\01\00\00\00 ")
  (data (i32.const 3104) "\01\00\00\00\0a")
  (data (i32.const 3120) "\17\00\00\00parser_ast_shape_diag  ")

  (data (i32.const 3168) "\1b\00\00\00phase1-stmts-count-not-1   ")
  (data (i32.const 3200) "\1b\00\00\00phase2-N-tag-bad           ")
  (data (i32.const 3232) "\1b\00\00\00phase2-N-body-range-bad    ")
  (data (i32.const 3264) "\1b\00\00\00phase3-NStmt-tag-bad       ")
  (data (i32.const 3296) "\1b\00\00\00phase3-NStmt-s-range-bad   ")
  (data (i32.const 3328) "\1b\00\00\00phase4-FnStmt-tag-bad      ")
  (data (i32.const 3360) "\1b\00\00\00phase4-FnStmt-name-bad     ")
  (data (i32.const 3392) "\1b\00\00\00phase4-FnStmt-params-bad   ")
  (data (i32.const 3424) "\1b\00\00\00phase4-FnStmt-ret-bad      ")
  (data (i32.const 3456) "\1b\00\00\00phase4-FnStmt-effs-bad     ")
  (data (i32.const 3488) "\1b\00\00\00phase4-FnStmt-body-bad     ")

  (func $field_is_invalid (param $v i32) (result i32)
    ;; Valid: $v < 4096 (sentinel) OR ($v >= 4096 AND $v < 33554432).
    ;; Invalid: $v >= 33554432 (out of linear-memory bounds — the
    ;; trap class). We allow zero (sentinel for "absent") since some
    ;; fields legitimately use it.
    (i32.ge_u (local.get $v) (i32.const 33554432)))

  (func $_start (export "_start")
    (local $failed i32)
    (local $source i32)
    (local $lex_result i32)
    (local $tokens i32)
    (local $stmts i32)
    (local $n_node i32)
    (local $nstmt_body i32)
    (local $fnstmt i32)
    (local $field i32)

    (local.set $failed (i32.const 0))
    (local.set $source (i32.const 5120))

    ;; ─── Phase 1: lex + parse_program ────────────────────────────
    (local.set $lex_result (call $lex (local.get $source)))
    (local.set $tokens
      (call $list_index (local.get $lex_result) (i32.const 0)))
    (local.set $stmts (call $parse_program (local.get $tokens)))

    (if (i32.ne (call $len (local.get $stmts)) (i32.const 1))
      (then (call $eprint_string (i32.const 3168))
            (call $eprint_string (i32.const 3104))
            (local.set $failed (i32.const 1))))

    ;; If we couldn't parse, skip the rest — there's nothing to walk.
    (if (i32.eqz (local.get $failed))
      (then
        ;; ─── Phase 2: N node shape ──────────────────────────────
        (local.set $n_node
          (call $list_index (local.get $stmts) (i32.const 0)))

        ;; N's tag is 0.
        (if (i32.ne (i32.load (local.get $n_node)) (i32.const 0))
          (then (call $eprint_string (i32.const 3200))
                (call $eprint_string (i32.const 3104))
                (local.set $failed (i32.const 1))))

        ;; N's body field at offset 4.
        (local.set $field (i32.load offset=4 (local.get $n_node)))
        (if (call $field_is_invalid (local.get $field))
          (then (call $eprint_string (i32.const 3232))
                (call $eprint_string (i32.const 3104))
                (local.set $failed (i32.const 1))))

        (if (i32.eqz (local.get $failed))
          (then
            ;; ─── Phase 3: NStmt wrapper shape ──────────────────
            (local.set $nstmt_body
              (i32.load offset=4 (local.get $n_node)))
            (if (i32.ne (i32.load (local.get $nstmt_body))
                        (i32.const 111))
              (then (call $eprint_string (i32.const 3264))
                    (call $eprint_string (i32.const 3104))
                    (local.set $failed (i32.const 1))))

            (local.set $field
              (i32.load offset=4 (local.get $nstmt_body)))
            (if (call $field_is_invalid (local.get $field))
              (then (call $eprint_string (i32.const 3296))
                    (call $eprint_string (i32.const 3104))
                    (local.set $failed (i32.const 1))))

            (if (i32.eqz (local.get $failed))
              (then
                ;; ─── Phase 4: FnStmt fields ───────────────────
                (local.set $fnstmt
                  (i32.load offset=4 (local.get $nstmt_body)))

                (if (i32.ne (i32.load (local.get $fnstmt))
                            (i32.const 121))
                  (then (call $eprint_string (i32.const 3328))
                        (call $eprint_string (i32.const 3104))
                        (local.set $failed (i32.const 1))))

                ;; name (offset 4)
                (local.set $field
                  (i32.load offset=4 (local.get $fnstmt)))
                (if (call $field_is_invalid (local.get $field))
                  (then (call $eprint_string (i32.const 3360))
                        (call $eprint_string (i32.const 3104))
                        (local.set $failed (i32.const 1))))

                ;; params (offset 8)
                (local.set $field
                  (i32.load offset=8 (local.get $fnstmt)))
                (if (call $field_is_invalid (local.get $field))
                  (then (call $eprint_string (i32.const 3392))
                        (call $eprint_string (i32.const 3104))
                        (local.set $failed (i32.const 1))))

                ;; ret (offset 12)
                (local.set $field
                  (i32.load offset=12 (local.get $fnstmt)))
                (if (call $field_is_invalid (local.get $field))
                  (then (call $eprint_string (i32.const 3424))
                        (call $eprint_string (i32.const 3104))
                        (local.set $failed (i32.const 1))))

                ;; effs (offset 16)
                (local.set $field
                  (i32.load offset=16 (local.get $fnstmt)))
                (if (call $field_is_invalid (local.get $field))
                  (then (call $eprint_string (i32.const 3456))
                        (call $eprint_string (i32.const 3104))
                        (local.set $failed (i32.const 1))))

                ;; body (offset 20)
                (local.set $field
                  (i32.load offset=20 (local.get $fnstmt)))
                (if (call $field_is_invalid (local.get $field))
                  (then (call $eprint_string (i32.const 3488))
                        (call $eprint_string (i32.const 3104))
                        (local.set $failed (i32.const 1))))))))))

    ;; ─── Phase 5: drive $inka_infer ─────────────────────────────
    ;; If everything above passed, the AST is shape-valid; running
    ;; $inka_infer either returns cleanly OR traps. A trap here on
    ;; a shape-valid AST means infer's walk has its own fault that
    ;; isn't about parser-shape — that gets captured in a separate
    ;; named follow-up.
    (if (i32.eqz (local.get $failed))
      (then (call $inka_infer (local.get $stmts))))

    ;; ─── Verdict ──────────────────────────────────────────────
    (if (local.get $failed)
      (then (call $eprint_string (i32.const 3084))
            (call $eprint_string (i32.const 3096))
            (call $eprint_string (i32.const 3120))
            (call $eprint_string (i32.const 3104))
            (call $wasi_proc_exit (i32.const 1)))
      (else (call $eprint_string (i32.const 3072))
            (call $eprint_string (i32.const 3096))
            (call $eprint_string (i32.const 3120))
            (call $eprint_string (i32.const 3104))
            (call $wasi_proc_exit (i32.const 0)))))
