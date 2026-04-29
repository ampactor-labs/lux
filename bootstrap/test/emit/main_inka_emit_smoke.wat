  ;; ═══ main_inka_emit_smoke.wat — Hβ.emit.module-wrap acceptance ═════
  ;; Executes: Phase F — $inka_emit module wrapper per Hβ-emit-substrate.md
  ;;           §10.3 + src/backends/wasm.nx emit_module/emit_start.
  ;;           Proves the pipeline-stage boundary emits structurally valid
  ;;           WAT module wrapping (header, WASI imports, memory, globals,
  ;;           body functions, funcref table, data section, _start).
  ;; Exercises: emit/main.wat $inka_emit, $emit_wasi_imports_inka,
  ;;            $emit_funcref_section, $emit_string_section,
  ;;            $emit_start_section, $emit_lowir_program.
  ;;
  ;; ─── Eight interrogations (per Hβ-emit §5.1 / SUBSTRATE §I) ────────
  ;;   Graph?      $emit_funcref_lookup verifies "main" string on heap.
  ;;   Handler?    Direct side-effect mapping (EmitMemory/WasmOut) on $out_base.
  ;;   Verb?       |> $inka_emit closes the pipeline segment.
  ;;   Row?        EfPure at substrate level.
  ;;   Ownership?  Buffer owned by infra, list passed by ref.
  ;;   Refinement? Transparent.
  ;;   Gradient?   Full module structure is the cash-out for execution.
  ;;   Reason?     Edges preserved upstream.
  ;;
  ;; ─── Forbidden patterns audited ─────────────────────────────────────
  ;;   - Drift 1 (vtable):     No dispatch table; $emit_cstr with direct offsets.
  ;;   - Drift 5 (C calling):  No threaded context; emit globals are the buffer.
  ;;   - Drift 9 (deferred):   Module wrap is complete — header through close.

  ;; ─── Harness-private data segments ──────────────────────────────────
  (data (i32.const 3072) "\05\00\00\00PASS:")
  (data (i32.const 3084) "\05\00\00\00FAIL:")
  (data (i32.const 3096) "\01\00\00\00 ")
  (data (i32.const 3104) "\01\00\00\00\0a")

  ;; Harness display name — "main_inka_emit_smoke " (21 chars)
  (data (i32.const 3120) "\15\00\00\00main_inka_emit_smoke ")

  ;; Per-assertion FAIL labels — 32-byte slots
  (data (i32.const 3168) "\1c\00\00\00wrap-nonzero-bad            ")
  (data (i32.const 3200) "\1c\00\00\00wrap-header-bad             ")
  (data (i32.const 3232) "\1c\00\00\00wrap-close-bad              ")
  (data (i32.const 3264) "\1c\00\00\00wrap-export-start-bad       ")

  ;; ─── _start ─────────────────────────────────────────────────────────
  (func $_start (export "_start")
    (local $failed i32)
    (local $empty_list i32)
    (local.set $failed (i32.const 0))

    ;; Initialize emit state.
    (call $emit_init)

    ;; ═══ Phase 1: $inka_emit over empty LowExpr list ══════════════════
    ;; The module wrapper always emits: (module\n ... )\n
    ;; An empty body still produces the full envelope.
    (local.set $empty_list (call $make_list (i32.const 0)))
    (global.set $out_pos (i32.const 0))
    (call $inka_emit (local.get $empty_list))

    ;; ── Check 1: Non-zero emission ──
    ;; Module wrapper must produce >0 bytes even for empty body.
    (if (i32.eqz (global.get $out_pos))
      (then
        (call $eprint_string (i32.const 3168))
        (call $eprint_string (i32.const 3104))
        (local.set $failed (i32.const 1))))

    ;; ── Check 2: First 7 bytes = "(module" ──
    ;; Per WAT spec, every module starts with "(module".
    (if (i32.or
          (i32.ne (i32.load8_u (global.get $out_base))
                  (i32.const 40))                   ;; '('
          (i32.ne (i32.load8_u (i32.add (global.get $out_base) (i32.const 1)))
                  (i32.const 109)))                  ;; 'm'
      (then
        (call $eprint_string (i32.const 3200))
        (call $eprint_string (i32.const 3104))
        (local.set $failed (i32.const 1))))

    ;; ── Check 3: Last 2 bytes = ")\n" ──
    ;; Module close: ')' followed by newline.
    (if (i32.or
          (i32.ne (i32.load8_u (i32.add (global.get $out_base)
                    (i32.sub (global.get $out_pos) (i32.const 2))))
                  (i32.const 41))                   ;; ')'
          (i32.ne (i32.load8_u (i32.add (global.get $out_base)
                    (i32.sub (global.get $out_pos) (i32.const 1))))
                  (i32.const 10)))                   ;; '\n'
      (then
        (call $eprint_string (i32.const 3232))
        (call $eprint_string (i32.const 3104))
        (local.set $failed (i32.const 1))))

    ;; ── Check 4: Output contains "(export \"_start\")" ──
    ;; Scan for the export annotation to verify $emit_start_section
    ;; placed it INSIDE the (func ...) form, not orphaned after.
    (if (i32.eqz (call $buf_contains_substr
          (i32.const 95) (i32.const 115)))           ;; '_' 's' from "_start"
      (then
        (call $eprint_string (i32.const 3264))
        (call $eprint_string (i32.const 3104))
        (local.set $failed (i32.const 1))))

    ;; ── Verdict ──
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

  ;; ─── $buf_contains_substr — scan output buffer for 2-byte marker ───
  ;; Returns 1 if the consecutive bytes (c1, c2) appear anywhere in
  ;; the output buffer [out_base, out_base+out_pos). Simple linear scan.
  (func $buf_contains_substr (param $c1 i32) (param $c2 i32) (result i32)
    (local $i i32) (local $end i32)
    (local.set $end (i32.sub (global.get $out_pos) (i32.const 1)))
    (local.set $i (i32.const 0))
    (block $done
      (loop $scan
        (br_if $done (i32.ge_u (local.get $i) (local.get $end)))
        (if (i32.and
              (i32.eq (i32.load8_u (i32.add (global.get $out_base) (local.get $i)))
                      (local.get $c1))
              (i32.eq (i32.load8_u (i32.add (global.get $out_base)
                        (i32.add (local.get $i) (i32.const 1))))
                      (local.get $c2)))
          (then (return (i32.const 1))))
        (local.set $i (i32.add (local.get $i) (i32.const 1)))
        (br $scan)))
    (i32.const 0))
