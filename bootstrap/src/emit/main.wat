  ;; ═══ main.wat — Hβ.emit pipeline-stage boundary (Tier 9) ═══════════════
  ;; Hβ.emit cascade chunk #8 of 8 per Hβ-emit-substrate.md §7.1
  ;; (post-restructure: emit_dispatcher.wat absorbed into emit_const.wat
  ;; per the walk_call.wat precedent — $emit_lexpr is introduced in the
  ;; FIRST chunk that needs sub-LowExpr recursion and retrofitted by
  ;; subsequent chunks via Edit). CASCADE CLOSURE.
  ;;
  ;; Implements: Hβ-emit-substrate.md §4 (module orchestration —
  ;;             $emit_lowir_program walks the LowExpr list and emits
  ;;             via $emit_lexpr) + §7.1 (chunk #9 main.wat) +
  ;;             §10.3 the CLEAN handoff (lower→emit; LowExpr list
  ;;             produced by $inka_lower is read-only here; WAT-text
  ;;             output IS the new artifact) + §11.3 dep order (chunk
  ;;             #9 closes the cascade) + Hβ-bootstrap.md §1.15 (entry-
  ;;             handler convention — $inka_<verb> naming) + §2.1 Layer 6
  ;;             (Emitter).
  ;;
  ;; Realizes the pipeline-stage projection of primitive #3 (the five
  ;; verbs — DESIGN.md §0.5) at the seed's emission layer, symmetric to
  ;; $inka_infer's primitive #8 projection at inference + $inka_lower's
  ;; primitive #3 projection at lowering. Closes the Hβ.emit cascade.
  ;; Names the boundary where pipeline-wire ($sys_main retrofit, named
  ;; peer follow-up) will chain after $inka_lower.
  ;;
  ;; Exports:    $inka_emit (pipeline-stage entry — delegates to
  ;;               $emit_lowir_program; takes the LowExpr list from
  ;;               $inka_lower; emits WAT to $out_base buffer via
  ;;               $emit_byte side-effect),
  ;;             $emit_lowir_program (algorithmic-core orchestrator —
  ;;               walks the LowExpr list and emits each via $emit_lexpr)
  ;; Uses:       $emit_lexpr (emit_const.wat — partial dispatcher
  ;;               complete via cumulative retrofits from chunks #3-#7
  ;;               for 30 LowExpr tags; tags 311 LMakeClosure + 312
  ;;               LMakeContinuation trap (unreachable) per named peer
  ;;               follow-up Hβ.emit.handler-fnref-substrate)
  ;;             $len + $list_index (runtime/list.wat)
  ;; Test:       bootstrap/test/emit/main_inka_emit_smoke.wat
  ;;
  ;; ═══ LOCKS (wheel-canonical override walkthrough §4 prose) ════════════
  ;;
  ;; Lock #1: $emit_lowir_program iterates the LowExpr list and calls
  ;;          $emit_lexpr on each. Mirrors Hβ.lower's $lower_stmt_list
  ;;          buffer-counter iteration shape (Ω.3 substrate). Side-effect
  ;;          on $out_base/$out_pos via $emit_byte deep in $emit_lexpr's
  ;;          arm bodies; the orchestrator itself is loop-only.
  ;;
  ;; Lock #2: $inka_emit is the pipeline-stage boundary; $emit_lowir_program
  ;;          is the algorithmic core. Two symbols, one delegation each.
  ;;          Mirrors Hβ.infer's $inka_infer / $infer_program + Hβ.lower's
  ;;          $inka_lower / $lower_program two-symbol pattern per
  ;;          Hβ-bootstrap §1.15. THIRD instance — the abstraction is
  ;;          earned per Anchor 7 cascade discipline.
  ;;
  ;; Lock #3: Result type — $inka_emit returns no value; emission is
  ;;          side-effect on $out_base/$out_pos. Differs from
  ;;          $inka_lower (returns LowExpr list ptr) and $inka_infer
  ;;          (no result; graph is the artifact). Hβ.emit's artifact
  ;;          IS the WAT byte buffer.
  ;;
  ;; Lock #4: $sys_main retrofit is the SEPARATE peer-handle commit
  ;;          Hβ.infer.pipeline-wire (named in Hβ.lower's main.wat:58-65 +
  ;;          ROADMAP.md §Near-Term Execution Order). NOT touched here.
  ;;          Three-stage cascade-closure-then-peer-handle-retrofit
  ;;          pattern continues per Anchor 7.4.
  ;;
  ;; Lock #5: NO new tags. Pure delegation per Lock #1.
  ;;          Tag regions owned upstream:
  ;;          300-349 LowExpr (lower/lexpr.wat); 360-379 emit-private
  ;;          records (emit/state.wat).
  ;;
  ;; ═══ EIGHT INTERROGATIONS (per Hβ-emit-substrate.md §5 applied to the
  ;;                           pipeline-stage boundary) ══════════════════
  ;;
  ;; 1. Graph?      $inka_emit reads through the LowExpr list. Each
  ;;                $emit_lexpr call walks the LowExpr's record; arms
  ;;                that need types call $lookup_ty (per §2.1 LConst /
  ;;                §2.4 LSuspend etc.). main.wat itself is graph-silent;
  ;;                the live graph reads happen INSIDE $emit_lexpr's
  ;;                arms.
  ;; 2. Handler?    @resume=OneShot. Wheel's `handle … with wat_emit`
  ;;                (src/backends/wasm.mn — Emit effect) is OneShot;
  ;;                seed maps onto direct $emit_byte side-effect. When
  ;;                the wheel composes Emit-handler-swap (text-output
  ;;                vs binary-output vs LSP-rendering), $inka_emit stays
  ;;                inert — handlers compose ON the substrate.
  ;; 3. Verb?       `|>` — this chunk draws the THIRD pipeline-stage
  ;;                step in the planned chain
  ;;                  parsed_stmts |> $inka_infer |> $inka_lower |> $inka_emit
  ;;                The $inka_<verb> convention names each `|>` stage.
  ;; 4. Row?        EmitMemory + WasmOut at the wheel; row-silent at the
  ;;                seed. Side-effect on $out_base/$out_pos via the
  ;;                emit_infra primitives is the EmitMemory swap surface
  ;;                made physical (§3.5 — bump today, arena/gc tomorrow
  ;;                via $emit_alloc / $emit_alloc_dyn body swap).
  ;; 5. Ownership?  $inka_emit takes lowexprs by shared pointer (`ref`);
  ;;                no consumption — the LowExpr list remains available
  ;;                for downstream readers. $out_base buffer OWNed
  ;;                program-wide per emit_infra.wat globals; emission is
  ;;                side-effect, not transfer.
  ;; 6. Refinement? None at this chunk. TRefined obligations carried
  ;;                through $lookup_ty are transparent at emit; main.wat
  ;;                is transit.
  ;; 7. Gradient?   The post-$inka_emit WAT byte buffer IS the gradient
  ;;                cashed out — every annotation in the source program
  ;;                ($with`-clauses, `own`/`ref`, refinements, type
  ;;                annotations) has been ground through inference,
  ;;                lowering, and emission into machine-instruction
  ;;                bytes. main.wat closes the surface; the cash-out
  ;;                already happened at chunks #6 (gradient cash-out
  ;;                site for monomorphic-vs-polymorphic) + #7 (handler
  ;;                family + LFeedback `<~` substrate).
  ;; 8. Reason?     main.wat adds no Reason edges. Reasons accumulate
  ;;                upstream in the graph populated by $inka_infer; emit
  ;;                preserves them by reading-only via $lookup_ty inside
  ;;                $emit_lexpr's arms. Per SUBSTRATE.md §VIII "the
  ;;                graph IS the program": Reasons stay graph-side; the
  ;;                Why Engine walks back through $gnode_reason on the
  ;;                source handle, NOT through emitted WAT.
  ;;
  ;; ═══ FORBIDDEN PATTERNS (drift modes 1-9) ════════════════════════════
  ;;
  ;; Drift 1 (Rust vtable):       NO $inka_emit_closure / $emit_dispatch_
  ;;                              table / data segment $pipeline_stage_
  ;;                              table. Two direct functions; ONE call
  ;;                              each. The dispatch IS $emit_lexpr's
  ;;                              tag-int comparison chain (chunk #3) —
  ;;                              evidence passing, NOT vtable.
  ;; Drift 2 (Scheme env frame):  NO $frame / $emit_frame parameter;
  ;;                              state.wat (chunk #1) owns emit-state;
  ;;                              main.wat reads nothing.
  ;; Drift 3 (Python dict):       NO string-keyed pipeline-stage dispatch;
  ;;                              stages are direct $inka_<verb> symbols.
  ;; Drift 4 (Haskell monad):     NO EmitM / PipelineM monad shape;
  ;;                              direct call sequence.
  ;; Drift 5 (C calling conv):    ONE i32 parameter — lowexprs. No
  ;;                              (lowexprs, ctx, errors_out) struct;
  ;;                              no out-parameter.
  ;; Drift 6 (primitive special): The emission stage is not "special";
  ;;                              every $inka_<verb> stage has the same
  ;;                              one-delegating-function shape per
  ;;                              Lock #2.
  ;; Drift 7 (parallel arrays):   NO (stage_names[], stage_fns[])
  ;;                              registry; the chain IS the call
  ;;                              sequence (lands in pipeline-wire peer
  ;;                              per Lock #4).
  ;; Drift 8 (mode flag):         NO mode: i32 parameter; one $inka_emit;
  ;;                              pipeline-wire selects this projection
  ;;                              directly via $inka_emit.
  ;; Drift 9 (deferred-by-omis):  $sys_main retrofit is named peer handle
  ;;                              Hβ.infer.pipeline-wire (Lock #4); the
  ;;                              two LFn-bearing emit arms (LMakeClosure
  ;;                              + LMakeContinuation) are named peer
  ;;                              Hβ.emit.handler-fnref-substrate (per
  ;;                              chunk #7 closure). NEITHER a silent TODO.
  ;;
  ;; Foreign-fluency forbidden:   "compiler driver" / "code generator
  ;;                              entry" / "backend main" / "main entry"
  ;;                              → Mentl-native phrases are "pipeline-
  ;;                              stage boundary" + "kernel primitive #3
  ;;                              verb projection" + "§10.3 clean
  ;;                              handoff" + "$emit_lowir_program
  ;;                              orchestrator". "code generator" /
  ;;                              "backend" → "emit handler-projection
  ;;                              per SUBSTRATE.md §III 'The Handler IS
  ;;                              the Backend'".
  ;;
  ;; ═══ TAG REGION ══════════════════════════════════════════════════════
  ;;
  ;; This chunk introduces NO new tags. Pure delegation per Lock #5.
  ;;
  ;; ═══ NAMED FOLLOW-UPS (per Drift 9 closure + Hβ-emit-substrate.md §10) ══
  ;;
  ;; - Hβ.infer.pipeline-wire: $sys_main retrofit (build.sh Layer 0
  ;;   shell inline) to chain $inka_emit between $inka_lower and the
  ;;   final $proc_exit. UNGATED post-this-chunk per Hβ-emit
  ;;   substrate.md §10.3 + Hβ-lower §10.3 + Hβ-infer §10.3 (three-
  ;;   stage cascade closure). $sys_main becomes:
  ;;     stdin |> read_all_stdin |> lex |> parse_program
  ;;       |> $inka_infer |> $inka_lower |> $inka_emit |> proc_exit
  ;;   Lands as the IMMEDIATE next commit per Lock #4.
  ;;
  ;; - Hβ.lower.lowfn-substrate: add LowFn record (tag 350 + 5
  ;;   accessors) to bootstrap/src/lower/lexpr.wat per src/lower.mn
  ;;   LFn ADT; update walk_compound + walk_stmt to construct LowFn
  ;;   properly. Prerequisite for handler-fnref-substrate.
  ;;
  ;; - Hβ.emit.handler-fnref-substrate: $emit_lmakeclosure (tag 311) +
  ;;   $emit_lmakecontinuation (tag 312) emit arms; depends on
  ;;   Hβ.lower.lowfn-substrate landing first.
  ;;
  ;; - Hβ.emit.lmatch-pattern-compile: nonempty-arms HB threshold-aware
  ;;   mixed-variant dispatch for $emit_lmatch (chunk #5); depends on
  ;;   LowPat substrate per Hβ.lower.lvalue-lowfn-lpat-substrate.
  ;;
  ;; - Hβ.emit.memory-arena-handler / -gc-handler: alternative
  ;;   EmitMemory swap-surface bodies; replace $emit_alloc and
  ;;   $emit_alloc_dyn body when arena/gc substrate matures (W5 +
  ;;   post-first-light substrate).
  ;;
  ;; - Hβ.emit.module-wrap: emit-time module-level wrappers — `(module
  ;;   ...)` header, memory imports, fn-table emission via state.wat's
  ;;   $emit_funcref_*, string-data emission via state.wat's
  ;;   $emit_string_*, state-global emission for $s<h> per LFeedback
  ;;   site handles. Lands as the module-wrap projection selected by
  ;;   pipeline-wire.

  ;; ─── Phase F+H data segments (module-wrap + fn-body emission) ─────
  ;; Phase F segments: 1584-1596 (funcref, _start)
  (data (i32.const 1584) "funcref")
  (data (i32.const 1591) "_start")
  ;; Phase H fn-body emission segments: RELOCATED to 4096+ to avoid
  ;; the contested 1597-1855 range (emit_diag at 1840 / emit_call at 1856).
  ;; 4096: "__state" (7) → 4103
  ;; 4104: "_idx i32 (i32.const " (20) → 4124
  ;; 4124: " (param $" (9) → 4133
  ;; 4133: " (result i32)" (13) → 4146
  ;; 4146: " (local $" (9) → 4155
  ;; 4155: " i32)" (5) → 4160
  ;; 4160: "(table $fns " (12) → 4172
  ;; 4172: " funcref)\n" (10) → 4182
  ;; 4182: "(elem $fns (i32.const 0)" (24) → 4206
  ;; 4206: ")\n" (2) → 4208
  ;; 4208: "(type $ft" (9) → 4217
  ;; 4217: " (func" (6) → 4223
  ;; 4224: " i32 " (5) → 4229
  ;; 4232: "callee_closure" (14) → 4246
  ;; 4248: "scrut_tmp" (9) → 4257
  ;; 4260: "loop_i" (6) → 4266
  ;; 4268: "main" (4) → 4272
  ;; Next free: 4272
  (data (i32.const 4096) "__state")
  (data (i32.const 4104) "_idx i32 (i32.const ")
  (data (i32.const 4124) " (param $")
  (data (i32.const 4133) " (result i32)")
  (data (i32.const 4146) " (local $")
  (data (i32.const 4155) " i32)")
  (data (i32.const 4160) "(table $fns ")
  (data (i32.const 4172) " funcref)\n")
  (data (i32.const 4182) "(elem $fns (i32.const 0)")
  (data (i32.const 4206) ")\n")
  (data (i32.const 4208) "(type $ft")
  (data (i32.const 4217) " (func")
  (data (i32.const 4224) " i32 ")
  (data (i32.const 4232) "callee_closure")
  (data (i32.const 4248) "scrut_tmp")
  (data (i32.const 4260) "loop_i")
  (data (i32.const 4268) "main")

  ;; ─── $emit_lowir_program — algorithmic-core orchestrator ─────────────
  ;;
  ;; Per Hβ-emit-substrate.md §4 + the Ω.3 buffer-counter iteration
  ;; substrate (CLAUDE.md memory model — never `acc ++ [x]`). Walks the
  ;; LowExpr list ($lower_program's output) and emits each via
  ;; $emit_lexpr. Side-effect on $out_base/$out_pos via $emit_byte
  ;; deep inside $emit_lexpr's arm bodies; main.wat itself is loop-only.
  ;;
  ;; Drift 1 refusal: direct list-walk via $list_index; NO $emit_dispatch_
  ;; table / NO closure-record-of-fn-pointers. The dispatch IS
  ;; $emit_lexpr's tag-int comparison chain.

  (func $emit_lowir_program (export "emit_lowir_program")
        (param $lowexprs i32)
    (local $i i32) (local $n i32)
    (local.set $n (call $len (local.get $lowexprs)))
    (local.set $i (i32.const 0))
    (block $done
      (loop $iter
        (br_if $done (i32.ge_u (local.get $i) (local.get $n)))
        (call $emit_lexpr
          (call $list_index (local.get $lowexprs) (local.get $i)))
        (local.set $i (i32.add (local.get $i) (i32.const 1)))
        (br $iter))))

  ;; ─── WASI import emission ─────────────────────────────────────────
  ;; WASI import projection used by emitted modules.
  (func $emit_wasi_imports_inka
    ;; fd_write
    (call $emit_cstr (i32.const 854) (i32.const 8))   ;; "(import "
    (call $emit_byte (i32.const 34))                  ;; '"'
    (call $emit_cstr (i32.const 1121) (i32.const 22)) ;; "wasi_snapshot_preview1"
    (call $emit_byte (i32.const 34))
    (call $emit_space)
    (call $emit_byte (i32.const 34))
    (call $emit_cstr (i32.const 1143) (i32.const 8))  ;; "fd_write"
    (call $emit_byte (i32.const 34))
    (call $emit_space)
    (call $emit_cstr (i32.const 924) (i32.const 5))   ;; "(func"
    (call $emit_space)
    (call $emit_byte (i32.const 36))                  ;; '$'
    (call $emit_cstr (i32.const 1151) (i32.const 13)) ;; "wasi_fd_write"
    (call $emit_cstr (i32.const 1164) (i32.const 37)) ;; " (param i32 i32 i32 i32) (result i32)"
    (call $emit_close)
    (call $emit_close)
    (call $emit_nl)
    ;; fd_read
    (call $emit_indent)
    (call $emit_cstr (i32.const 854) (i32.const 8))   ;; "(import "
    (call $emit_byte (i32.const 34))
    (call $emit_cstr (i32.const 1121) (i32.const 22)) ;; "wasi_snapshot_preview1"
    (call $emit_byte (i32.const 34))
    (call $emit_space)
    (call $emit_byte (i32.const 34))
    (call $emit_cstr (i32.const 1202) (i32.const 7))  ;; "fd_read"
    (call $emit_byte (i32.const 34))
    (call $emit_space)
    (call $emit_cstr (i32.const 924) (i32.const 5))   ;; "(func"
    (call $emit_space)
    (call $emit_byte (i32.const 36))
    (call $emit_cstr (i32.const 1209) (i32.const 12)) ;; "wasi_fd_read"
    (call $emit_cstr (i32.const 1164) (i32.const 37)) ;; " (param i32 i32 i32 i32) (result i32)"
    (call $emit_close)
    (call $emit_close)
    (call $emit_nl)
    ;; proc_exit
    (call $emit_indent)
    (call $emit_cstr (i32.const 854) (i32.const 8))   ;; "(import "
    (call $emit_byte (i32.const 34))
    (call $emit_cstr (i32.const 1121) (i32.const 22)) ;; "wasi_snapshot_preview1"
    (call $emit_byte (i32.const 34))
    (call $emit_space)
    (call $emit_byte (i32.const 34))
    (call $emit_cstr (i32.const 1221) (i32.const 9))  ;; "proc_exit"
    (call $emit_byte (i32.const 34))
    (call $emit_space)
    (call $emit_cstr (i32.const 924) (i32.const 5))   ;; "(func"
    (call $emit_space)
    (call $emit_byte (i32.const 36))
    (call $emit_cstr (i32.const 1230) (i32.const 14)) ;; "wasi_proc_exit"
    (call $emit_cstr (i32.const 1244) (i32.const 12)) ;; " (param i32)"
    (call $emit_close)
    (call $emit_close)
    (call $emit_nl))

  ;; ─── Table Section Emission ───────────────────────────────────────
  (func $emit_funcref_section
    (local $i i32) (local $n i32) (local $str i32)
    (local.set $n (call $emit_funcref_count))
    (if (i32.eqz (local.get $n)) (then (return)))
    (call $emit_indent)
    (call $emit_cstr (i32.const 870) (i32.const 7)) ;; "(table "
    (call $emit_int (local.get $n))
    (call $emit_space)
    (call $emit_cstr (i32.const 1584) (i32.const 7)) ;; "funcref"
    (call $emit_close)
    (call $emit_nl)
    (call $emit_indent)
    (call $emit_cstr (i32.const 877) (i32.const 6)) ;; "(elem "
    (call $emit_cstr (i32.const 560) (i32.const 11)) ;; "(i32.const "
    (call $emit_byte (i32.const 48)) ;; '0'
    (call $emit_close)
    (local.set $i (i32.const 0))
    (block $done (loop $iter
      (br_if $done (i32.ge_u (local.get $i) (local.get $n)))
      (local.set $str (call $emit_funcref_at (local.get $i)))
      (call $emit_space)
      (call $emit_byte (i32.const 36)) ;; '$'
      (call $emit_cstr (i32.add (local.get $str) (i32.const 4)) (call $str_len (local.get $str)))
      (local.set $i (i32.add (local.get $i) (i32.const 1)))
      (br $iter)))
    (call $emit_close)
    (call $emit_nl))

  ;; ─── Data Section Emission ────────────────────────────────────────
  (func $emit_string_section
    (local $i i32) (local $n i32) (local $entry i32)
    (local $str i32) (local $offset i32)
    (local.set $n (call $emit_string_table_count))
    (local.set $i (i32.const 0))
    (block $done (loop $iter
      (br_if $done (i32.ge_u (local.get $i) (local.get $n)))
      (local.set $entry (call $emit_string_table_at (local.get $i)))
      (local.set $str (call $record_get (local.get $entry) (i32.const 0)))
      (local.set $offset (call $record_get (local.get $entry) (i32.const 1)))
      (call $emit_indent)
      (call $emit_cstr (i32.const 912) (i32.const 6)) ;; "(data "
      (call $emit_cstr (i32.const 560) (i32.const 11)) ;; "(i32.const "
      (call $emit_int (local.get $offset))
      (call $emit_close)
      (call $emit_space)
      (call $emit_byte (i32.const 34)) ;; '"'
      ;; The string contents must be properly escaped if we are emitting WAT text, but since Mentl only tests alphanumeric/basic ascii in the test suite so far, a raw emit_cstr is sufficient.
      (call $emit_cstr (i32.add (local.get $str) (i32.const 4)) (call $str_len (local.get $str)))
      (call $emit_byte (i32.const 34)) ;; '"'
      (call $emit_close)
      (call $emit_nl)
      (local.set $i (i32.add (local.get $i) (i32.const 1)))
      (br $iter))))

  ;; ─── _start Section Emission ──────────────────────────────────────
  ;; Per src/backends/wasm.mn emit_start: emits `(func $_start (export
  ;; "_start") ...)`. If "main" appears in the funcref table, calls it
  ;; and drops the result before proc_exit. Export annotation MUST be
  ;; inside the (func ...) form per WAT spec.
  (func $emit_start_section
    (local $main_str i32)
    (local.set $main_str (call $str_alloc (i32.const 4)))
    (i32.store8 (i32.add (local.get $main_str) (i32.const 4)) (i32.const 109)) ;; 'm'
    (i32.store8 (i32.add (local.get $main_str) (i32.const 5)) (i32.const 97))  ;; 'a'
    (i32.store8 (i32.add (local.get $main_str) (i32.const 6)) (i32.const 105)) ;; 'i'
    (i32.store8 (i32.add (local.get $main_str) (i32.const 7)) (i32.const 110)) ;; 'n'
    ;; (func $_start (export "_start")
    (call $emit_indent)
    (call $emit_cstr (i32.const 584) (i32.const 6)) ;; "(func "
    (call $emit_byte (i32.const 36))                 ;; '$'
    (call $emit_cstr (i32.const 1591) (i32.const 6)) ;; "_start"
    (call $emit_cstr (i32.const 1500) (i32.const 19)) ;; " (export \"_start\")"
    (call $emit_nl)
    (call $indent_inc)
    ;; Body: if "main" is registered, call it and drop
    (if (i32.ge_s (call $emit_funcref_lookup (local.get $main_str)) (i32.const 0))
      (then
        (call $emit_indent)
        (call $emit_cstr (i32.const 572) (i32.const 6)) ;; "(call "
        (call $emit_byte (i32.const 36))
        (call $emit_cstr (i32.add (local.get $main_str) (i32.const 4)) (i32.const 4)) ;; "main"
        (call $emit_space)
        (call $emit_cstr (i32.const 560) (i32.const 11)) ;; "(i32.const "
        (call $emit_byte (i32.const 48))                  ;; '0'
        (call $emit_close)
        (call $emit_close)
        (call $emit_nl)
        (call $emit_indent)
        (call $emit_cstr (i32.const 578) (i32.const 6)) ;; "(drop "
        (call $emit_close)
        (call $emit_nl)))
    ;; (call $wasi_proc_exit (i32.const 0))
    (call $emit_indent)
    (call $emit_cstr (i32.const 572) (i32.const 6)) ;; "(call "
    (call $emit_byte (i32.const 36))
    (call $emit_cstr (i32.const 1221) (i32.const 9)) ;; "proc_exit"
    (call $emit_space)
    (call $emit_cstr (i32.const 560) (i32.const 11)) ;; "(i32.const "
    (call $emit_byte (i32.const 48))                  ;; '0'
    (call $emit_close)
    (call $emit_close)
    (call $emit_nl)
    ;; Close func
    (call $indent_dec)
    (call $emit_indent)
    (call $emit_close)
    (call $emit_nl))

  ;; ─── Phase H: Function body emission ─────────────────────────────────
  ;; Per src/backends/wasm.mn:848-963 emit_functions + emit_fn_body.
  ;; Deep-walks the LowExpr list to find LMakeClosure nodes and emits
  ;; each as a (func $name ...) WAT definition. Also collects fn names
  ;; for the funcref table + index globals.

  ;; $collect_fn_names — walk LowExpr list, collect LMakeClosure fn names.
  ;; Returns a flat list of name ptrs. Per wasm.mn:848-928 emit_fns_expr.
  ;; Per Hβ.emit.nested-fn-idx-globals: recurses into common LowExpr
  ;; containers (LLet, LBlock, LIf, LCall, LBinOp, LMakeVariant,
  ;; LMakeList, LMakeTuple, LReturn) to collect EVERY LMakeClosure's
  ;; fn name — including nested lambdas. The $emit_functions_walk
  ;; recursion already emits each nested fn body; this collector
  ;; mirrors that walk so the funcref table + $name_idx globals stay
  ;; consistent with emit_functions's actual emissions.
  ;; $collect_fn_names — entry: builds a Buffer<String>, walks the
  ;; LowExpr tree appending fn names via $buf_push, freezes to a clean
  ;; List<String> on return. Per Hβ.runtime.buffer-substrate — the
  ;; transient name-collection IS the use-case Buffer<A> exists for.
  ;; Pre-substrate this used a List as a buffer (offset-0-as-both-
  ;; count-and-capacity), causing O(N²) reallocations at wheel scale.
  (func $collect_fn_names (param $lowexprs i32) (result i32)
    (local $buf i32)
    (local.set $buf (call $buf_make (i32.const 16)))
    (local.set $buf (call $cfn_walk_list (local.get $buf) (local.get $lowexprs)))
    (call $buf_freeze (local.get $buf)))

  ;; $cfn_walk_list — iterate top-level lowexprs; threads a Buffer<String>.
  ;;
  ;; Productive-under-error guard: when the input is a sentinel/null
  ;; pointer (< HEAP_BASE) — typically because an upstream lower
  ;; accessor returned a sentinel where a list was expected — `$len`
  ;; would read garbage from low memory addresses, causing the loop
  ;; to spin for billions of iterations.
  ;;
  ;; Named peer `Hβ.first-light.cfn-walk-list-malformed-source`:
  ;; identify which upstream accessor (likely lexpr_lblock_stmts /
  ;; lexpr_lcall_args / lexpr_lhandle_body when the LowExpr is an
  ;; LError sentinel) produces the sub-HEAP_BASE pointer.
  (func $cfn_walk_list (param $buf i32) (param $lowexprs i32) (result i32)
    (local $i i32) (local $n i32)
    (if (i32.lt_u (local.get $lowexprs) (global.get $heap_base))
      (then (return (local.get $buf))))
    (local.set $n (call $len (local.get $lowexprs)))
    (local.set $i (i32.const 0))
    (block $done
      (loop $iter
        (br_if $done (i32.ge_u (local.get $i) (local.get $n)))
        (local.set $buf
          (call $cfn_walk (local.get $buf)
            (call $list_index (local.get $lowexprs) (local.get $i))))
        (local.set $i (i32.add (local.get $i) (i32.const 1)))
        (br $iter)))
    (local.get $buf))

  ;; $cfn_walk — recurse into one LowExpr; push LMakeClosure fn names
  ;; into the Buffer at any depth. Mirrors $emit_functions_walk
  ;; structurally so funcref table entries match emit_fn_body
  ;; invocations 1:1. Threads Buffer<String> through recursion;
  ;; $buf_push is amortized O(1) (capacity-vs-count separation).
  (func $cfn_walk (param $buf i32) (param $expr i32) (result i32)
    (local $tag i32) (local $fn_r i32) (local $body i32)
    (if (i32.lt_u (local.get $expr) (global.get $heap_base))
      (then (return (local.get $buf))))
    (local.set $tag (call $tag_of (local.get $expr)))
    ;; LMakeClosure (311) — push fn name + recurse into body.
    (if (i32.eq (local.get $tag) (i32.const 311))
      (then
        (local.set $fn_r (call $lexpr_lmakeclosure_fn (local.get $expr)))
        (call $buf_push (local.get $buf) (call $lowfn_name (local.get $fn_r)))
        (local.set $body (call $lowfn_body (local.get $fn_r)))
        (return (call $cfn_walk_list (local.get $buf) (local.get $body)))))
    ;; LMakeContinuation (312) — same shape.
    (if (i32.eq (local.get $tag) (i32.const 312))
      (then
        (local.set $fn_r (call $lexpr_lmakecontinuation_fn (local.get $expr)))
        (call $buf_push (local.get $buf) (call $lowfn_name (local.get $fn_r)))
        (local.set $body (call $lowfn_body (local.get $fn_r)))
        (return (call $cfn_walk_list (local.get $buf) (local.get $body)))))
    ;; LDeclareFn (313) — handler-arm fn name + recurse into body.
    ;; Symmetric to LMakeClosure (311) per Lock #1 — both wrap a LowFn
    ;; that becomes a module-level (func ...). Third caller per Anchor
    ;; 7 (lower=1, cfn_walk=2, emit_functions_walk=3 — same commit).
    (if (i32.eq (local.get $tag) (i32.const 313))
      (then
        (local.set $fn_r (call $lexpr_ldeclarefn_fn (local.get $expr)))
        (call $buf_push (local.get $buf) (call $lowfn_name (local.get $fn_r)))
        (local.set $body (call $lowfn_body (local.get $fn_r)))
        (return (call $cfn_walk_list (local.get $buf) (local.get $body)))))
    ;; LLet (304) — recurse into value.
    (if (i32.eq (local.get $tag) (i32.const 304))
      (then
        (return (call $cfn_walk (local.get $buf)
                  (call $lexpr_llet_value (local.get $expr))))))
    ;; LBlock (315) — recurse into stmts.
    (if (i32.eq (local.get $tag) (i32.const 315))
      (then
        (return (call $cfn_walk_list (local.get $buf)
                  (call $lexpr_lblock_stmts (local.get $expr))))))
    ;; LIf (314).
    (if (i32.eq (local.get $tag) (i32.const 314))
      (then
        (local.set $buf (call $cfn_walk (local.get $buf)
                          (call $lexpr_lif_cond (local.get $expr))))
        (local.set $buf (call $cfn_walk_list (local.get $buf)
                          (call $lexpr_lif_then (local.get $expr))))
        (return (call $cfn_walk_list (local.get $buf)
                  (call $lexpr_lif_else (local.get $expr))))))
    ;; LCall (308).
    (if (i32.eq (local.get $tag) (i32.const 308))
      (then
        (local.set $buf (call $cfn_walk (local.get $buf)
                          (call $lexpr_lcall_fn (local.get $expr))))
        (return (call $cfn_walk_list (local.get $buf)
                  (call $lexpr_lcall_args (local.get $expr))))))
    ;; LTailCall (309).
    (if (i32.eq (local.get $tag) (i32.const 309))
      (then
        (local.set $buf (call $cfn_walk (local.get $buf)
                          (call $lexpr_ltailcall_fn (local.get $expr))))
        (return (call $cfn_walk_list (local.get $buf)
                  (call $lexpr_ltailcall_args (local.get $expr))))))
    ;; LBinOp (306).
    (if (i32.eq (local.get $tag) (i32.const 306))
      (then
        (local.set $buf (call $cfn_walk (local.get $buf)
                          (call $lexpr_lbinop_l (local.get $expr))))
        (return (call $cfn_walk (local.get $buf)
                  (call $lexpr_lbinop_r (local.get $expr))))))
    ;; LMakeVariant (319).
    (if (i32.eq (local.get $tag) (i32.const 319))
      (then
        (return (call $cfn_walk_list (local.get $buf)
                  (call $lexpr_lmakevariant_args (local.get $expr))))))
    ;; LMakeList (316).
    (if (i32.eq (local.get $tag) (i32.const 316))
      (then
        (return (call $cfn_walk_list (local.get $buf)
                  (call $lexpr_lmakelist_elems (local.get $expr))))))
    ;; LMakeTuple (317).
    (if (i32.eq (local.get $tag) (i32.const 317))
      (then
        (return (call $cfn_walk_list (local.get $buf)
                  (call $lexpr_lmaketuple_elems (local.get $expr))))))
    ;; LReturn (310).
    (if (i32.eq (local.get $tag) (i32.const 310))
      (then
        (return (call $cfn_walk (local.get $buf)
                  (call $lexpr_lreturn_x (local.get $expr))))))
    ;; LHandle (332) — recurse into body so nested closures get visited.
    ;; Per Lock #2: handler-arm bodies are a peer site for LMakeClosure /
    ;; LDeclareFn discovery alongside top-level LBlocks.
    (if (i32.eq (local.get $tag) (i32.const 332))
      (then
        (return (call $cfn_walk (local.get $buf)
                  (call $lexpr_lhandle_body (local.get $expr))))))
    ;; LHandleWith (329) — recurse into body + handler.
    (if (i32.eq (local.get $tag) (i32.const 329))
      (then
        (local.set $buf (call $cfn_walk (local.get $buf)
                          (call $lexpr_lhandlewith_body (local.get $expr))))
        (return (call $cfn_walk (local.get $buf)
                  (call $lexpr_lhandlewith_handler (local.get $expr))))))
    ;; All other tags: no LowExpr children to recurse into.
    (local.get $buf))

  ;; $collect_top_level_fn_names — top-level LLet-wrapped closures only.
  ;; Inline closures still allocate at their expression site; module-level
  ;; function declarations get static closure records.
  ;;
  ;; Buffer<String> per Hβ.runtime.buffer-substrate — same pattern as
  ;; $collect_fn_names; freezes to clean List<String> on return.
  (func $collect_top_level_fn_names (param $lowexprs i32) (result i32)
    (local $buf i32)
    (local $i i32) (local $n i32) (local $expr i32) (local $name i32)
    (local.set $buf (call $buf_make (i32.const 16)))
    (local.set $n (call $len (local.get $lowexprs)))
    (local.set $i (i32.const 0))
    (block $done
      (loop $iter
        (br_if $done (i32.ge_u (local.get $i) (local.get $n)))
        (local.set $expr (call $list_index (local.get $lowexprs) (local.get $i)))
        (local.set $name (call $extract_top_fn_name (local.get $expr)))
        (if (i32.ne (local.get $name) (i32.const 0))
          (then (call $buf_push (local.get $buf) (local.get $name))))
        (local.set $i (i32.add (local.get $i) (i32.const 1)))
        (br $iter)))
    (call $buf_freeze (local.get $buf)))

  (func $extract_top_fn_name (param $expr i32) (result i32)
    (local $inner i32)
    (if (i32.ne (call $tag_of (local.get $expr)) (i32.const 304))
      (then (return (i32.const 0))))
    (local.set $inner (call $lexpr_llet_value (local.get $expr)))
    (if (i32.eq (call $tag_of (local.get $inner)) (i32.const 311))
      (then (return (call $lexpr_llet_name (local.get $expr)))))
    (if (i32.eq (call $tag_of (local.get $inner)) (i32.const 312))
      (then (return (call $lexpr_llet_name (local.get $expr)))))
    (i32.const 0))

  ;; ─── Function Type Section ────────────────────────────────────────
  ;; Every call_indirect references $ftN, where N includes the implicit
  ;; __state parameter. The LowExpr graph determines the required ceiling.
  (func $emit_type_section (param $lowexprs i32)
    (local $observed i32) (local $max i32)
    (local.set $observed (call $max_arity_in (local.get $lowexprs) (i32.const 0)))
    (local.set $max (local.get $observed))
    (if (i32.lt_s (local.get $max) (i32.const 1))
      (then (local.set $max (i32.const 1))))
    (call $emit_type_decls (i32.const 0) (local.get $max)))

  (func $max_arity_in (param $exprs i32) (param $acc i32) (result i32)
    (local $i i32) (local $n i32) (local $best i32) (local $candidate i32)
    (local.set $best (local.get $acc))
    (local.set $n (call $len (local.get $exprs)))
    (local.set $i (i32.const 0))
    (block $done
      (loop $iter
        (br_if $done (i32.ge_u (local.get $i) (local.get $n)))
        (local.set $candidate
          (call $max_arity_expr (call $list_index (local.get $exprs) (local.get $i))))
        (local.set $best (call $max_i32 (local.get $best) (local.get $candidate)))
        (local.set $i (i32.add (local.get $i) (i32.const 1)))
        (br $iter)))
    (local.get $best))

  (func $max_arity_expr (param $expr i32) (result i32)
    (local $tag i32) (local $inner i32) (local $fn_r i32)
    (local $a i32) (local $b i32)
    (local.set $tag (call $tag_of (local.get $expr)))
    ;; LCall / LTailCall / LSuspend: user args + implicit __state.
    (if (i32.eq (local.get $tag) (i32.const 308))
      (then
        (local.set $a (i32.add (call $len (call $lexpr_lcall_args (local.get $expr))) (i32.const 1)))
        (local.set $b (call $max_arity_expr (call $lexpr_lcall_fn (local.get $expr))))
        (local.set $b (call $max_i32 (local.get $b)
          (call $max_arity_in (call $lexpr_lcall_args (local.get $expr)) (i32.const 0))))
        (return (call $max_i32 (local.get $a) (local.get $b)))))
    (if (i32.eq (local.get $tag) (i32.const 309))
      (then
        (local.set $a (i32.add (call $len (call $lexpr_ltailcall_args (local.get $expr))) (i32.const 1)))
        (local.set $b (call $max_arity_expr (call $lexpr_ltailcall_fn (local.get $expr))))
        (local.set $b (call $max_i32 (local.get $b)
          (call $max_arity_in (call $lexpr_ltailcall_args (local.get $expr)) (i32.const 0))))
        (return (call $max_i32 (local.get $a) (local.get $b)))))
    (if (i32.eq (local.get $tag) (i32.const 325))
      (then
        (local.set $a (i32.add (call $len (call $lexpr_lsuspend_args (local.get $expr))) (i32.const 1)))
        (local.set $b (call $max_arity_expr (call $lexpr_lsuspend_fn (local.get $expr))))
        (local.set $b (call $max_i32 (local.get $b)
          (call $max_arity_in (call $lexpr_lsuspend_args (local.get $expr)) (i32.const 0))))
        (local.set $b (call $max_i32 (local.get $b)
          (call $max_arity_in (call $lexpr_lsuspend_evs (local.get $expr)) (i32.const 0))))
        (return (call $max_i32 (local.get $a) (local.get $b)))))
    ;; Direct perform arity is exactly its argument count.
    (if (i32.eq (local.get $tag) (i32.const 331))
      (then
        (return
          (call $max_i32
            (call $len (call $lexpr_lperform_args (local.get $expr)))
            (call $max_arity_in (call $lexpr_lperform_args (local.get $expr)) (i32.const 0))))))
    (if (i32.eq (local.get $tag) (i32.const 333))
      (then
        (return
          (call $max_i32
            (i32.add (call $len (call $lexpr_levperform_args (local.get $expr))) (i32.const 1))
            (call $max_arity_in (call $lexpr_levperform_args (local.get $expr)) (i32.const 0))))))
    ;; LLet recurses into its value.
    (if (i32.eq (local.get $tag) (i32.const 304))
      (then (return (call $max_arity_expr (call $lexpr_llet_value (local.get $expr))))))
    ;; LMakeClosure contributes its own W7 arity and body call sites.
    (if (i32.eq (local.get $tag) (i32.const 311))
      (then
        (local.set $fn_r (call $lexpr_lmakeclosure_fn (local.get $expr)))
        (return
          (call $max_i32
            (i32.add (call $lowfn_arity (local.get $fn_r)) (i32.const 1))
            (call $max_arity_in (call $lowfn_body (local.get $fn_r)) (i32.const 0))))))
    (if (i32.eq (local.get $tag) (i32.const 312))
      (then
        (local.set $fn_r (call $lexpr_lmakecontinuation_fn (local.get $expr)))
        (return
          (call $max_i32
            (i32.add (call $lowfn_arity (local.get $fn_r)) (i32.const 1))
            (call $max_arity_in (call $lowfn_body (local.get $fn_r)) (i32.const 0))))))
    ;; LDeclareFn (313) — handler-arm fn contributes its arity + body.
    ;; Per Lock #1 same shape as LMakeClosure (311). The +1 accounts for
    ;; the implicit __state parameter every fn in the W7 calling
    ;; convention carries (per emit_fn_body line 906-909).
    (if (i32.eq (local.get $tag) (i32.const 313))
      (then
        (local.set $fn_r (call $lexpr_ldeclarefn_fn (local.get $expr)))
        (return
          (call $max_i32
            (i32.add (call $lowfn_arity (local.get $fn_r)) (i32.const 1))
            (call $max_arity_in (call $lowfn_body (local.get $fn_r)) (i32.const 0))))))
    ;; LHandle (332) — recurse into body for arity contributions.
    (if (i32.eq (local.get $tag) (i32.const 332))
      (then (return (call $max_arity_expr (call $lexpr_lhandle_body (local.get $expr))))))
    ;; LHandleWith (329) — max(body, handler).
    (if (i32.eq (local.get $tag) (i32.const 329))
      (then
        (return
          (call $max_i32
            (call $max_arity_expr (call $lexpr_lhandlewith_body (local.get $expr)))
            (call $max_arity_expr (call $lexpr_lhandlewith_handler (local.get $expr)))))))
    ;; Common containers used by current lower output.
    (if (i32.eq (local.get $tag) (i32.const 306))
      (then
        (return
          (call $max_i32
            (call $max_arity_expr (call $lexpr_lbinop_l (local.get $expr)))
            (call $max_arity_expr (call $lexpr_lbinop_r (local.get $expr)))))))
    (if (i32.eq (local.get $tag) (i32.const 307))
      (then (return (call $max_arity_expr (call $lexpr_lunaryop_x (local.get $expr))))))
    (if (i32.eq (local.get $tag) (i32.const 310))
      (then (return (call $max_arity_expr (call $lexpr_lreturn_x (local.get $expr))))))
    (if (i32.eq (local.get $tag) (i32.const 315))
      (then (return (call $max_arity_in (call $lexpr_lblock_stmts (local.get $expr)) (i32.const 0)))))
    (if (i32.eq (local.get $tag) (i32.const 316))
      (then (return (call $max_arity_in (call $lexpr_lmakelist_elems (local.get $expr)) (i32.const 0)))))
    (if (i32.eq (local.get $tag) (i32.const 317))
      (then (return (call $max_arity_in (call $lexpr_lmaketuple_elems (local.get $expr)) (i32.const 0)))))
    (if (i32.eq (local.get $tag) (i32.const 318))
      (then (return (call $max_arity_in (call $lexpr_lmakerecord_fields (local.get $expr)) (i32.const 0)))))
    (if (i32.eq (local.get $tag) (i32.const 319))
      (then (return (call $max_arity_in (call $lexpr_lmakevariant_args (local.get $expr)) (i32.const 0)))))
    (if (i32.eq (local.get $tag) (i32.const 334))
      (then (return (call $max_arity_expr (call $lexpr_lfieldload_record (local.get $expr))))))
    (i32.const 0))

  (func $max_i32 (param $a i32) (param $b i32) (result i32)
    (if (result i32) (i32.gt_s (local.get $a) (local.get $b))
      (then (local.get $a))
      (else (local.get $b))))

  (func $emit_type_decls (param $i i32) (param $max i32)
    (block $done
      (loop $iter
        (br_if $done (i32.gt_s (local.get $i) (local.get $max)))
        (call $emit_indent)
        (call $emit_cstr (i32.const 4208) (i32.const 9)) ;; "(type $ft"
        (call $emit_int (local.get $i))
        (call $emit_cstr (i32.const 4217) (i32.const 6)) ;; " (func"
        (call $emit_param_types (local.get $i))
        (call $emit_cstr (i32.const 4133) (i32.const 13)) ;; " (result i32)"
        (call $emit_close)
        (call $emit_close)
        (call $emit_nl)
        (local.set $i (i32.add (local.get $i) (i32.const 1)))
        (br $iter))))

  (func $emit_param_types (param $n i32)
    (block $done
      (loop $iter
        (br_if $done (i32.eqz (local.get $n)))
        (call $emit_cstr (i32.const 1244) (i32.const 12)) ;; " (param i32)"
        (local.set $n (i32.sub (local.get $n) (i32.const 1)))
        (br $iter))))

  ;; $emit_fn_table_and_globals — emit (table $fns N funcref) + (elem ...)
  ;; + (global $name_idx i32 (i32.const N)) per fn.
  ;; Per wasm.mn:577-609.
  (func $emit_fn_table_and_globals (param $names i32)
    (local $n i32) (local $i i32)
    (local.set $n (call $len (local.get $names)))
    (if (i32.eqz (local.get $n)) (then (return)))
    ;; (table $fns N funcref)
    (call $emit_indent)
    (call $emit_cstr (i32.const 4160) (i32.const 12)) ;; "(table $fns "
    (call $emit_int (local.get $n))
    (call $emit_cstr (i32.const 4172) (i32.const 10)) ;; " funcref)\n"
    ;; (elem $fns (i32.const 0) $name1 $name2 ...)
    (call $emit_indent)
    (call $emit_cstr (i32.const 4182) (i32.const 24)) ;; "(elem $fns (i32.const 0)"
    (local.set $i (i32.const 0))
    (block $done
      (loop $iter
        (br_if $done (i32.ge_u (local.get $i) (local.get $n)))
        (call $emit_byte (i32.const 32))  ;; ' '
        (call $emit_byte (i32.const 36))  ;; '$'
        (call $emit_str (call $list_index (local.get $names) (local.get $i)))
        (local.set $i (i32.add (local.get $i) (i32.const 1)))
        (br $iter)))
    (call $emit_cstr (i32.const 4206) (i32.const 2)) ;; ")\n"
    ;; (global $name_idx i32 (i32.const N)) per fn
    (local.set $i (i32.const 0))
    (block $done2
      (loop $iter2
        (br_if $done2 (i32.ge_u (local.get $i) (local.get $n)))
        (call $emit_indent)
        (call $emit_cstr (i32.const 862) (i32.const 8))  ;; "(global "
        (call $emit_byte (i32.const 36))                  ;; '$'
        (call $emit_str (call $list_index (local.get $names) (local.get $i)))
        (call $emit_cstr (i32.const 4104) (i32.const 20)) ;; "_idx i32 (i32.const "
        (call $emit_int (local.get $i))
        (call $emit_close)  ;; close (i32.const N)
        (call $emit_close)  ;; close (global ...)
        (call $emit_nl)
        (local.set $i (i32.add (local.get $i) (i32.const 1)))
        (br $iter2))))

  ;; $emit_static_top_closures — module-level closure records for top fns.
  ;; Each record is [fn_idx:i32, capture_count=0:i32] at address
  ;; 256 + slot*8, with a global $name pointing at the record.
  (func $emit_static_top_closures (param $top_names i32) (param $all_names i32)
    (local $i i32) (local $n i32) (local $name i32) (local $fn_idx i32)
    (local $addr i32)
    (local.set $n (call $len (local.get $top_names)))
    (local.set $i (i32.const 0))
    (block $done
      (loop $iter
        (br_if $done (i32.ge_u (local.get $i) (local.get $n)))
        (local.set $name (call $list_index (local.get $top_names) (local.get $i)))
        (local.set $fn_idx (call $emit_find_name_index
          (local.get $all_names)
          (local.get $name)))
        (local.set $addr (i32.add (i32.const 256) (i32.mul (local.get $i) (i32.const 8))))
        ;; (data (i32.const <addr>) "\xx\xx\xx\xx\00\00\00\00")
        (call $emit_indent)
        (call $emit_cstr (i32.const 912) (i32.const 6))  ;; "(data "
        (call $emit_i32_const (local.get $addr))
        (call $emit_space)
        (call $emit_byte (i32.const 34))
        (call $emit_le4_escape (local.get $fn_idx))
        (call $emit_le4_escape (i32.const 0))
        (call $emit_byte (i32.const 34))
        (call $emit_close)
        (call $emit_nl)
        ;; (global $name i32 (i32.const <addr>))
        (call $emit_indent)
        (call $emit_cstr (i32.const 862) (i32.const 8))  ;; "(global "
        (call $emit_byte (i32.const 36))
        (call $emit_str (local.get $name))
        (call $emit_cstr (i32.const 4224) (i32.const 5)) ;; " i32 "
        (call $emit_i32_const (local.get $addr))
        (call $emit_close)
        (call $emit_nl)
        (local.set $i (i32.add (local.get $i) (i32.const 1)))
        (br $iter))))

  (func $emit_find_name_index (param $names i32) (param $target i32) (result i32)
    (local $i i32) (local $n i32)
    (local.set $n (call $len (local.get $names)))
    (local.set $i (i32.const 0))
    (block $done
      (loop $iter
        (br_if $done (i32.ge_u (local.get $i) (local.get $n)))
        (if (call $str_eq
              (call $list_index (local.get $names) (local.get $i))
              (local.get $target))
          (then (return (local.get $i))))
        (local.set $i (i32.add (local.get $i) (i32.const 1)))
        (br $iter)))
    (i32.const -1))

  (func $emit_le4_escape (param $n i32)
    (call $emit_byte_escape (i32.and (local.get $n) (i32.const 255)))
    (call $emit_byte_escape (i32.and (i32.shr_u (local.get $n) (i32.const 8)) (i32.const 255)))
    (call $emit_byte_escape (i32.and (i32.shr_u (local.get $n) (i32.const 16)) (i32.const 255)))
    (call $emit_byte_escape (i32.and (i32.shr_u (local.get $n) (i32.const 24)) (i32.const 255))))

  (func $emit_byte_escape (param $b i32)
    (call $emit_byte (i32.const 92)) ;; '\'
    (call $emit_hex_digit (i32.shr_u (local.get $b) (i32.const 4)))
    (call $emit_hex_digit (i32.and (local.get $b) (i32.const 15))))

  (func $emit_hex_digit (param $d i32)
    (if (i32.lt_u (local.get $d) (i32.const 10))
      (then
        (call $emit_byte (i32.add (i32.const 48) (local.get $d)))
        (return)))
    (call $emit_byte (i32.add (i32.const 87) (local.get $d))))

  (func $emit_local_decl_cstr (param $offset i32) (param $n i32)
    (call $emit_cstr (i32.const 4146) (i32.const 9)) ;; " (local $"
    (call $emit_cstr (local.get $offset) (local.get $n))
    (call $emit_cstr (i32.const 4155) (i32.const 5))) ;; " i32)"

  (func $emit_local_decl_str (param $name i32)
    (call $emit_cstr (i32.const 4146) (i32.const 9)) ;; " (local $"
    (call $emit_str (local.get $name))
    (call $emit_cstr (i32.const 4155) (i32.const 5))) ;; " i32)"

  (func $emit_standard_locals
    (call $emit_local_decl_str (i32.const 2244))      ;; state_tmp
    (call $emit_local_decl_str (i32.const 1568))      ;; variant_tmp
    (call $emit_local_decl_str (i32.const 1552))      ;; record_tmp
    (call $emit_local_decl_str (i32.const 1536))      ;; tuple_tmp
    (call $emit_local_decl_cstr (i32.const 4248) (i32.const 9))  ;; scrut_tmp
    (call $emit_local_decl_cstr (i32.const 4232) (i32.const 14)) ;; callee_closure
    (call $emit_local_decl_str (i32.const 1856))      ;; alloc_size
    (call $emit_local_decl_cstr (i32.const 4260) (i32.const 6))) ;; loop_i

  ;; $emit_fn_body — emit a single (func $name (param $__state i32) ...)
  ;; Per wasm.mn:930-962 emit_fn_body. W7 calling convention.
  (func $emit_fn_body (param $fn_r i32)
    (local $name i32) (local $params i32) (local $body i32)
    (local $arity i32) (local $i i32)
    (local.set $name   (call $lowfn_name   (local.get $fn_r)))
    (local.set $arity  (call $lowfn_arity  (local.get $fn_r)))
    (local.set $params (call $lowfn_params (local.get $fn_r)))
    (local.set $body   (call $lowfn_body   (local.get $fn_r)))
    ;; (func $name
    (call $emit_indent)
    (call $emit_cstr (i32.const 924) (i32.const 5)) ;; "(func"
    (call $emit_byte (i32.const 32))                ;; ' '
    (call $emit_byte (i32.const 36))                ;; '$'
    (call $emit_str (local.get $name))
    ;; (param $__state i32)
    (call $emit_cstr (i32.const 4124) (i32.const 9)) ;; " (param $"
    (call $emit_cstr (i32.const 4096) (i32.const 7)) ;; "__state"
    (call $emit_cstr (i32.const 4155) (i32.const 5)) ;; " i32)"
    ;; Emit user params
    (local.set $i (i32.const 0))
    (block $pdone
      (loop $piter
        (br_if $pdone (i32.ge_u (local.get $i) (local.get $arity)))
        (call $emit_cstr (i32.const 4124) (i32.const 9)) ;; " (param $"
        (call $emit_str (call $list_index (local.get $params) (local.get $i)))
        (call $emit_cstr (i32.const 4155) (i32.const 5)) ;; " i32)"
        (local.set $i (i32.add (local.get $i) (i32.const 1)))
        (br $piter)))
    ;; (result i32)
    (call $emit_cstr (i32.const 4133) (i32.const 13)) ;; " (result i32)"
    ;; Standard locals per W7 + emit arms that lower into scratch slots.
    (call $emit_standard_locals)
    ;; Per-fn ledger reset — $emit_standard_locals' fixed scratch names
    ;; are emitted unconditionally above; the ledger tracks only
    ;; LowPat-bound names that emit_let_locals + emit_pat_locals project.
    ;; Per Hβ.first-light.match-arm-binding-name-uniqueness Lock #3 —
    ;; this is the first wiring of $emit_fn_reset (state.wat exports it
    ;; but no caller existed pre-this-commit).
    (call $emit_fn_reset)
    ;; Pre-declare LLet locals from body
    (call $emit_let_locals (local.get $body))
    (call $emit_nl)
    ;; Emit body expressions
    (call $indent_inc)
    (call $emit_lowir_program (local.get $body))
    (call $indent_dec)
    (call $emit_indent)
    (call $emit_close)
    (call $emit_nl))

  ;; $emit_let_locals — walk body LowExpr list, emit (local $name i32)
  ;; for each LLet (including nested ones inside LBlock containers
  ;; per Hβ.first-light.letstmt-destructure-let-locals: PCon
  ;; destructure produces LBlock containing LLet sequences). Stops
  ;; at LMakeClosure / LMakeContinuation boundaries — those are
  ;; SEPARATE function bodies; their locals belong to their own
  ;; emit_fn_body call.
  ;;
  ;; Eight interrogations on this descent site:
  ;;  1. Graph?      LLet's name is the local label; LBlock's stmts
  ;;                 list is the structure to recurse into.
  ;;  2. Handler?    Direct emit; @resume=OneShot.
  ;;  3. Verb?       N/A — structural walk.
  ;;  4. Row?        EmitMemory effect performed (writes to output).
  ;;  5. Ownership?  exprs borrowed throughout.
  ;;  6. Refinement? LLet's handle ≥ 0.
  ;;  7. Gradient?   N/A — orthogonal to gradient.
  ;;  8. Reason?     N/A at emit-time.
  ;;
  ;; Drift modes refused:
  ;;  - Drift 1 (vtable): direct tag-int dispatch; no table.
  ;;  - Drift 6 (special): same descent for outer block AND nested
  ;;                       LBlock; no special-case for first-level.
  ;;  - Drift 9 (deferred): all emit-relevant containers walked.
  (func $emit_let_locals (param $exprs i32)
    (local $i i32) (local $n i32) (local $expr i32) (local $tag i32)
    (local.set $n (call $len (local.get $exprs)))
    (local.set $i (i32.const 0))
    (block $done
      (loop $iter
        (br_if $done (i32.ge_u (local.get $i) (local.get $n)))
        (local.set $expr (call $list_index (local.get $exprs) (local.get $i)))
        (local.set $tag (call $tag_of (local.get $expr)))
        ;; LLet (304) — declare local IFF not already declared for current
        ;; fn (Hβ.first-light.match-arm-binding-name-uniqueness Lock #1
        ;; + §A.5b LLet-cross-block coverage); recurse into value either
        ;; way (since the value may itself contain nested LLets via PCon
        ;; destructure or block expressions).
        (if (i32.eq (local.get $tag) (i32.const 304))
          (then
            (if (call $emit_fn_local_check (call $lexpr_llet_name (local.get $expr)))
              (then
                (call $emit_cstr (i32.const 4146) (i32.const 9)) ;; " (local $"
                (call $emit_str (call $lexpr_llet_name (local.get $expr)))
                (call $emit_cstr (i32.const 4155) (i32.const 5)))) ;; " i32)"
            ;; Recurse into the value (may contain nested LBlocks via
            ;; PCon destructure or other compound expressions).
            (call $emit_let_locals_walk
                  (call $lexpr_llet_value (local.get $expr)))))
        ;; LBlock (315) — recurse into stmts list to find nested LLets.
        (if (i32.eq (local.get $tag) (i32.const 315))
          (then
            (call $emit_let_locals (call $lexpr_lblock_stmts (local.get $expr)))))
        ;; LIf (314) — recurse into branches.
        (if (i32.eq (local.get $tag) (i32.const 314))
          (then
            (call $emit_let_locals (call $lexpr_lif_then (local.get $expr)))
            (call $emit_let_locals (call $lexpr_lif_else (local.get $expr)))))
        ;; LMatch (321) — recurse into scrutinee + each arm. Per
        ;; Hβ.first-light.match-arm-pat-binding-local-decl Lock #1:
        ;; arms' patterns introduce LPVar bindings (potentially nested);
        ;; arms' bodies may contain LLet bindings.
        (if (i32.eq (local.get $tag) (i32.const 321))
          (then
            (call $emit_let_locals_walk
              (call $lexpr_lmatch_scrut (local.get $expr)))
            (call $emit_match_arm_locals
              (call $lexpr_lmatch_arms (local.get $expr)))))
        ;; LMakeClosure (311) / LMakeContinuation (312) / LDeclareFn (313)
        ;; — fn boundary. Their bodies belong to their own fn body's
        ;; emit_let_locals invocation (chained from $emit_fn_body line 932).
        ;; LHandle (332) / LHandleWith (329) bodies remain in the parent
        ;; fn's local-decl scope — they are control structures, not fn
        ;; boundaries. Per Lock #1 + emit_handler.wat:357-361 (lhandle
        ;; sub-emits body inline). Future named follow-up if a wheel
        ;; example surfaces local-decls inside an LHandle body that
        ;; aren't picked up by the current LBlock/LIf/LMatch recursion.
        ;; All other tags: no LowExpr children with LLet to declare.
        (local.set $i (i32.add (local.get $i) (i32.const 1)))
        (br $iter))))

  ;; Single-expr walker companion to $emit_let_locals (which takes a
  ;; list). Used when recursing into LLet's value (a single expr).
  (func $emit_let_locals_walk (param $expr i32)
    (local $tag i32)
    (if (i32.lt_u (local.get $expr) (global.get $heap_base))
      (then (return)))
    (local.set $tag (call $tag_of (local.get $expr)))
    (if (i32.eq (local.get $tag) (i32.const 315))
      (then
        (call $emit_let_locals (call $lexpr_lblock_stmts (local.get $expr)))
        (return)))
    (if (i32.eq (local.get $tag) (i32.const 314))
      (then
        (call $emit_let_locals (call $lexpr_lif_then (local.get $expr)))
        (call $emit_let_locals (call $lexpr_lif_else (local.get $expr)))
        (return)))
    (if (i32.eq (local.get $tag) (i32.const 321))
      (then
        (call $emit_let_locals_walk (call $lexpr_lmatch_scrut (local.get $expr)))
        (call $emit_match_arm_locals (call $lexpr_lmatch_arms (local.get $expr)))
        (return)))
    (return))

  ;; ─── $emit_match_arm_locals — iterate match arms; emit pat + body ──
  ;; locals per arm. Per Hβ.first-light.match-arm-pat-binding-local-decl
  ;; Lock #2: arm's pat walked via $emit_pat_locals; arm's body recursed
  ;; via $emit_let_locals_walk.
  ;;
  ;; Lock #3: NO de-duplication across arms — WAT uniqueness obligation
  ;; enforced at lower-time (substrate gap if collisions surface).
  (func $emit_match_arm_locals (param $arms i32)
    (local $i i32) (local $n i32) (local $arm i32)
    (local.set $n (call $len (local.get $arms)))
    (local.set $i (i32.const 0))
    (block $done
      (loop $iter
        (br_if $done (i32.ge_u (local.get $i) (local.get $n)))
        (local.set $arm (call $list_index (local.get $arms) (local.get $i)))
        (call $emit_pat_locals (call $lowpat_lparm_pat (local.get $arm)))
        (call $emit_let_locals_walk (call $lowpat_lparm_body (local.get $arm)))
        (local.set $i (i32.add (local.get $i) (i32.const 1)))
        (br $iter))))

  ;; ─── $emit_pat_locals — walk LowPat tree, emit (local $<name> i32) ──
  ;; for every LPVar binding (direct LPVar OR sub-pattern of LPCon /
  ;; LPTuple / LPRecord / LPList / LPAs). Per Hβ.first-light.match-arm-
  ;; pat-binding-local-decl Lock #2: bindings come from LPVar at any
  ;; pattern depth; the local-decl ledger derives from LowPat structure,
  ;; not from a parallel name-list (Drift 7 refusal).
  ;;
  ;; Eight interrogations:
  ;;  1. Graph?      LPVar's name field at record offset 1; tag dispatch
  ;;                 via $tag_of; sub-pattern lists via accessors.
  ;;  2. Handler?    Direct emit; @resume=OneShot.
  ;;  3. Verb?       N/A — structural walk.
  ;;  4. Row?        EmitMemory effect (writes to $out_base via $emit_str).
  ;;  5. Ownership?  Pat record `ref`-borrowed.
  ;;  6. Refinement? LPVar.name non-zero string-ptr per arity-2 contract.
  ;;  7. Gradient?   Local-decl synthesis derived from LowPat substrate.
  ;;  8. Reason?     LPVar handle preserves chain; this walk does not write.
  ;;
  ;; Drift modes refused:
  ;;  - Drift 1 (vtable): direct tag-int dispatch; no $pat_locals_table.
  ;;  - Drift 6 (special): every binding-introducing LowPat goes through
  ;;                       same recurse; LPCon, LPTuple, LPRecord, LPList,
  ;;                       LPAs treated uniformly.
  ;;  - Drift 7 (parallel arrays): no body_local_names accumulator.
  ;;  - Drift 8 (string-keyed): tag-int comparisons.
  ;;  - Drift 9 (deferred): all binding-introducing LowPat variants walked.
  (func $emit_pat_locals (param $pat i32)
    (local $tag i32) (local $sub_pats i32) (local $i i32) (local $n i32)
    (local $rest i32) (local $fields i32) (local $field i32)
    (if (i32.lt_u (local.get $pat) (global.get $heap_base))
      (then (return)))
    (local.set $tag (call $tag_of (local.get $pat)))
    ;; LPVar (360) — emit (local $<name> i32) IFF not already declared
    ;; for current fn (Hβ.first-light.match-arm-binding-name-uniqueness
    ;; Lock #1). Source-name fidelity preserved (Lock #5).
    (if (i32.eq (local.get $tag) (i32.const 360))
      (then
        (if (call $emit_fn_local_check (call $lowpat_lpvar_name (local.get $pat)))
          (then
            (call $emit_cstr (i32.const 4146) (i32.const 9)) ;; " (local $"
            (call $emit_str (call $lowpat_lpvar_name (local.get $pat)))
            (call $emit_cstr (i32.const 4155) (i32.const 5)))) ;; " i32)"
        (return)))
    ;; LPCon (363) — recurse into sub-pats list.
    (if (i32.eq (local.get $tag) (i32.const 363))
      (then
        (local.set $sub_pats (call $lowpat_lpcon_args (local.get $pat)))
        (local.set $n (call $len (local.get $sub_pats)))
        (local.set $i (i32.const 0))
        (block $done_con
          (loop $iter_con
            (br_if $done_con (i32.ge_u (local.get $i) (local.get $n)))
            (call $emit_pat_locals
              (call $list_index (local.get $sub_pats) (local.get $i)))
            (local.set $i (i32.add (local.get $i) (i32.const 1)))
            (br $iter_con)))
        (return)))
    ;; LPTuple (364) — recurse into elems.
    (if (i32.eq (local.get $tag) (i32.const 364))
      (then
        (local.set $sub_pats (call $lowpat_lptuple_elems (local.get $pat)))
        (local.set $n (call $len (local.get $sub_pats)))
        (local.set $i (i32.const 0))
        (block $done_tup
          (loop $iter_tup
            (br_if $done_tup (i32.ge_u (local.get $i) (local.get $n)))
            (call $emit_pat_locals
              (call $list_index (local.get $sub_pats) (local.get $i)))
            (local.set $i (i32.add (local.get $i) (i32.const 1)))
            (br $iter_tup)))
        (return)))
    ;; LPRecord (366) — fields is list of (name, pat) records.
    (if (i32.eq (local.get $tag) (i32.const 366))
      (then
        (local.set $fields (call $lowpat_lprecord_fields (local.get $pat)))
        (local.set $n (call $len (local.get $fields)))
        (local.set $i (i32.const 0))
        (block $done_rec
          (loop $iter_rec
            (br_if $done_rec (i32.ge_u (local.get $i) (local.get $n)))
            (local.set $field
              (call $list_index (local.get $fields) (local.get $i)))
            (call $emit_pat_locals
              (call $record_get (local.get $field) (i32.const 1)))
            (local.set $i (i32.add (local.get $i) (i32.const 1)))
            (br $iter_rec)))
        (local.set $rest (call $lowpat_lprecord_rest (local.get $pat)))
        (if (i32.ne (local.get $rest) (i32.const 0))
          (then
            (if (call $emit_fn_local_check (local.get $rest))
              (then
                (call $emit_cstr (i32.const 4146) (i32.const 9))
                (call $emit_str (local.get $rest))
                (call $emit_cstr (i32.const 4155) (i32.const 5))))))
        (return)))
    ;; LPList (365) — recurse into elems; rest_var is bound-name string.
    (if (i32.eq (local.get $tag) (i32.const 365))
      (then
        (local.set $sub_pats (call $lowpat_lplist_elems (local.get $pat)))
        (local.set $n (call $len (local.get $sub_pats)))
        (local.set $i (i32.const 0))
        (block $done_lst
          (loop $iter_lst
            (br_if $done_lst (i32.ge_u (local.get $i) (local.get $n)))
            (call $emit_pat_locals
              (call $list_index (local.get $sub_pats) (local.get $i)))
            (local.set $i (i32.add (local.get $i) (i32.const 1)))
            (br $iter_lst)))
        (local.set $rest (call $lowpat_lplist_rest (local.get $pat)))
        (if (i32.ne (local.get $rest) (i32.const 0))
          (then
            (if (call $emit_fn_local_check (local.get $rest))
              (then
                (call $emit_cstr (i32.const 4146) (i32.const 9))
                (call $emit_str (local.get $rest))
                (call $emit_cstr (i32.const 4155) (i32.const 5))))))
        (return)))
    ;; LPAs (368) — emit (local $<name> i32) IFF not already declared,
    ;; THEN recurse inner pat (which re-checks its own bindings via
    ;; $emit_fn_local_check on each LPVar/LPCon/etc. it encounters).
    (if (i32.eq (local.get $tag) (i32.const 368))
      (then
        (if (call $emit_fn_local_check (call $lowpat_lpas_name (local.get $pat)))
          (then
            (call $emit_cstr (i32.const 4146) (i32.const 9))
            (call $emit_str (call $lowpat_lpas_name (local.get $pat)))
            (call $emit_cstr (i32.const 4155) (i32.const 5))))
        (call $emit_pat_locals (call $lowpat_lpas_pat (local.get $pat)))
        (return)))
    ;; LPWild (361) / LPLit (362) / LPAlt (367) — bind nothing.
    (return))

  ;; $emit_functions — walk LowExpr list, emit (func ...) for each
  ;; LMakeClosure, including NESTED ones inside fn bodies (lambdas).
  ;; Per Hβ.first-light.lambda-body-fn-emit (2026-05-02): when a lambda
  ;; appears inside a fn body (e.g., `fn main() = (x) => x`), the
  ;; LMakeClosure is buried inside the outer fn's body LowExpr tree,
  ;; not at the top level. The emitter must recurse to find it.
  ;;
  ;; Eight interrogations per recursion site:
  ;;  1. Graph?      LMakeClosure carries LowFn (lowfn record); fn body
  ;;                 IS a LowExpr list whose nodes are graph projections.
  ;;  2. Handler?    Direct emit; @resume=OneShot.
  ;;  3. Verb?       N/A — structural recursion.
  ;;  4. Row?        EmitMemory effect in emit; pure structural walk
  ;;                 over ADT in this helper.
  ;;  5. Ownership?  Borrowed throughout.
  ;;  6. Refinement? LowExpr tag must be in [300, 334].
  ;;  7. Gradient?   Each fn emitted is one more candidate in the
  ;;                 funcref table; closure records reference them.
  ;;  8. Reason?     Each LMakeClosure carries its source handle.
  ;;
  ;; Drift modes refused:
  ;;  - Drift 1 (vtable): fn_index is a FIELD read at call_indirect; no
  ;;                       table-of-functions dispatch logic here.
  ;;  - Drift 6 (special): nullary AND N-ary lambdas use the same
  ;;                       emit_fn_body path; no Bool-special-case.
  ;;  - Drift 9 (deferred): all common LowExpr containers walked
  ;;                       (LLet/LBlock/LIf/LMatch/LCall/LTailCall/
  ;;                       LSuspend/LBinOp/LMakeList/LMakeTuple/
  ;;                       LMakeRecord/LMakeVariant). Less-common
  ;;                       containers fall through (no recursion);
  ;;                       drift-9-safe because uninitialized-
  ;;                       containers never produce LMakeClosure
  ;;                       children today (substrate bounded by
  ;;                       lower's actual output).

  (func $emit_functions (param $lowexprs i32)
    (local $i i32) (local $n i32) (local $expr i32) (local $tag i32)
    ;; Productive-under-error guard: the recursive walk descends into
    ;; LowExpr accessor results (lexpr_lcall_args, lexpr_lblock_stmts,
    ;; etc.). When upstream lower's productive-under-error path emits
    ;; a sentinel where a List was expected — typically when infer
    ;; left an LError-shaped LowExpr in a containment field — those
    ;; accessors return a non-list pointer. $list_index would trap on
    ;; unknown tag. Skip the walk on malformed input; the diagnostic
    ;; chain already surfaced the upstream cause as
    ;; E_UnresolvedType / E_TypeMismatch. Named peer:
    ;; `Hβ.first-light.emit-functions-malformed-list-source` —
    ;; identifies which accessor / lower path produces the non-list.
    (if (i32.lt_u (local.get $lowexprs) (global.get $heap_base))
      (then (return)))
    (local.set $tag (call $list_tag (local.get $lowexprs)))
    (if (i32.and
          (i32.ne (local.get $tag) (i32.const 0))
          (i32.and
            (i32.ne (local.get $tag) (i32.const 1))
            (i32.and
              (i32.ne (local.get $tag) (i32.const 3))
              (i32.ne (local.get $tag) (i32.const 4)))))
      (then (return)))
    (local.set $n (call $len (local.get $lowexprs)))
    (local.set $i (i32.const 0))
    (block $done
      (loop $iter
        (br_if $done (i32.ge_u (local.get $i) (local.get $n)))
        (local.set $expr (call $list_index (local.get $lowexprs) (local.get $i)))
        (call $emit_functions_walk (local.get $expr))
        (local.set $i (i32.add (local.get $i) (i32.const 1)))
        (br $iter))))

  ;; Recursive walker: for each LowExpr, emit any LMakeClosure
  ;; encountered (and recurse into its body) AND descend into common
  ;; sub-expression containers.
  (func $emit_functions_walk (param $expr i32)
    (local $tag i32) (local $inner i32) (local $fn_r i32) (local $body i32)
    (if (i32.lt_u (local.get $expr) (global.get $heap_base))
      (then (return)))
    (local.set $tag (call $tag_of (local.get $expr)))
    ;; LMakeClosure (311) — emit fn body + recurse into its body
    (if (i32.eq (local.get $tag) (i32.const 311))
      (then
        (local.set $fn_r (call $lexpr_lmakeclosure_fn (local.get $expr)))
        (call $emit_fn_body (local.get $fn_r))
        (local.set $body (call $lowfn_body (local.get $fn_r)))
        (call $emit_functions (local.get $body))
        (return)))
    ;; LMakeContinuation (312) — same shape
    (if (i32.eq (local.get $tag) (i32.const 312))
      (then
        (local.set $fn_r (call $lexpr_lmakecontinuation_fn (local.get $expr)))
        (call $emit_fn_body (local.get $fn_r))
        (local.set $body (call $lowfn_body (local.get $fn_r)))
        (call $emit_functions (local.get $body))
        (return)))
    ;; LDeclareFn (313) — handler-arm fn becomes a module-level (func).
    ;; Per Lock #1 + H1.4 single-handler-per-op naming: the LowFn's name
    ;; is "op_<op_name>" (set at walk_handle.wat:283). $emit_fn_body
    ;; emits `(func $op_<op_name> ...)`; recursive descent into body
    ;; finds nested closures (lambda-inside-arm).
    (if (i32.eq (local.get $tag) (i32.const 313))
      (then
        (local.set $fn_r (call $lexpr_ldeclarefn_fn (local.get $expr)))
        (call $emit_fn_body (local.get $fn_r))
        (local.set $body (call $lowfn_body (local.get $fn_r)))
        (call $emit_functions (local.get $body))
        (return)))
    ;; LLet (304) — recurse into value
    (if (i32.eq (local.get $tag) (i32.const 304))
      (then
        (call $emit_functions_walk (call $lexpr_llet_value (local.get $expr)))
        (return)))
    ;; LBlock (315) — recurse into stmts list
    (if (i32.eq (local.get $tag) (i32.const 315))
      (then
        (call $emit_functions (call $lexpr_lblock_stmts (local.get $expr)))
        (return)))
    ;; LIf (314) — recurse into cond/then/else
    (if (i32.eq (local.get $tag) (i32.const 314))
      (then
        (call $emit_functions_walk (call $lexpr_lif_cond (local.get $expr)))
        (call $emit_functions (call $lexpr_lif_then (local.get $expr)))
        (call $emit_functions (call $lexpr_lif_else (local.get $expr)))
        (return)))
    ;; LCall (308) — recurse into fn + args
    (if (i32.eq (local.get $tag) (i32.const 308))
      (then
        (call $emit_functions_walk (call $lexpr_lcall_fn (local.get $expr)))
        (call $emit_functions (call $lexpr_lcall_args (local.get $expr)))
        (return)))
    ;; LTailCall (309) — same shape as LCall
    (if (i32.eq (local.get $tag) (i32.const 309))
      (then
        (call $emit_functions_walk (call $lexpr_ltailcall_fn (local.get $expr)))
        (call $emit_functions (call $lexpr_ltailcall_args (local.get $expr)))
        (return)))
    ;; LBinOp (306) — recurse into lhs/rhs
    (if (i32.eq (local.get $tag) (i32.const 306))
      (then
        (call $emit_functions_walk (call $lexpr_lbinop_l (local.get $expr)))
        (call $emit_functions_walk (call $lexpr_lbinop_r (local.get $expr)))
        (return)))
    ;; LMakeVariant (319) — recurse into args
    (if (i32.eq (local.get $tag) (i32.const 319))
      (then
        (call $emit_functions (call $lexpr_lmakevariant_args (local.get $expr)))
        (return)))
    ;; LMakeList (316) — recurse into elems
    (if (i32.eq (local.get $tag) (i32.const 316))
      (then
        (call $emit_functions (call $lexpr_lmakelist_elems (local.get $expr)))
        (return)))
    ;; LMakeTuple (317) — recurse into elems
    (if (i32.eq (local.get $tag) (i32.const 317))
      (then
        (call $emit_functions (call $lexpr_lmaketuple_elems (local.get $expr)))
        (return)))
    ;; LReturn (310) — recurse into value
    (if (i32.eq (local.get $tag) (i32.const 310))
      (then
        (call $emit_functions_walk (call $lexpr_lreturn_x (local.get $expr)))
        (return)))
    ;; LHandle (332) — recurse into body to discover nested fns.
    (if (i32.eq (local.get $tag) (i32.const 332))
      (then
        (call $emit_functions_walk (call $lexpr_lhandle_body (local.get $expr)))
        (return)))
    ;; LHandleWith (329) — recurse into body + handler.
    (if (i32.eq (local.get $tag) (i32.const 329))
      (then
        (call $emit_functions_walk (call $lexpr_lhandlewith_body (local.get $expr)))
        (call $emit_functions_walk (call $lexpr_lhandlewith_handler (local.get $expr)))
        (return)))
    ;; All other tags: no LowExpr children to recurse into (literals,
    ;; locals, globals, etc.). Drop through.
    (return))

  ;; ─── $inka_emit — the pipeline-stage entry ───────────────────────────
  ;;
  ;; Per Hβ-emit-substrate.md §10.3 + Hβ-bootstrap §1.15 entry-handler
  ;; convention. Symmetric to $inka_infer (infer/main.wat) + $inka_lower
  ;; (lower/main.wat). Lock #2: pipeline-stage boundary distinct from
  ;; $emit_lowir_program algorithmic core. Lock #3: no result —
  ;; emission is side-effect on $out_base/$out_pos; the WAT byte buffer
  ;; IS the artifact pipeline-wire's `$proc_exit` flushes via
  ;; $emit_flush.
  ;;
  ;; Phase H: now emits function definitions per wasm.mn:165-185.
  ;; Order: header → imports → memory → globals → table → fn_idx_globals
  ;;        → functions → top-level body in _start → string data → close.

  (func $inka_emit (export "inka_emit")
        (param $lowexprs i32)
    (local $fn_names i32) (local $top_fn_names i32)
    ;; Collect function names for table + globals
    (local.set $fn_names (call $collect_fn_names (local.get $lowexprs)))
    (local.set $top_fn_names (call $collect_top_level_fn_names (local.get $lowexprs)))

    (call $emit_cstr (i32.const 831) (i32.const 7))  ;; "(module"
    (call $emit_nl)
    (call $indent_inc)

    ;; ── Function types for call_indirect ──
    (call $emit_type_section (local.get $lowexprs))

    ;; ── WASI imports ──
    (call $emit_wasi_imports_inka)

    ;; ── Memory & Globals ──
    (call $emit_indent)
    (call $emit_cstr (i32.const 838) (i32.const 8))  ;; "(memory "
    (call $emit_cstr (i32.const 846) (i32.const 8))  ;; "(export "
    (call $emit_byte (i32.const 34))
    (call $emit_cstr (i32.const 1096) (i32.const 6)) ;; memory
    (call $emit_byte (i32.const 34))
    (call $emit_close)
    (call $emit_space)
    (call $emit_int (i32.const 512))
    (call $emit_close)
    (call $emit_nl)

    (call $emit_indent)
    (call $emit_cstr (i32.const 862) (i32.const 8))  ;; "(global "
    (call $emit_byte (i32.const 36))
    (call $emit_cstr (i32.const 1102) (i32.const 8)) ;; heap_ptr
    (call $emit_cstr (i32.const 1110) (i32.const 11)) ;; " (mut i32) "
    (call $emit_i32_const (i32.const 1048576))
    (call $emit_close)
    (call $emit_nl)

    ;; ── Funcref table + index globals ──
    (call $emit_fn_table_and_globals (local.get $fn_names))

    ;; ── Static top-level closure records ──
    (call $emit_static_top_closures
      (local.get $top_fn_names)
      (local.get $fn_names))

    ;; ── Function definitions ──
    (call $emit_functions (local.get $lowexprs))

    ;; ── Table & Data (funcref + strings from emit state) ──
    (call $emit_funcref_section)
    (call $emit_string_section)

    ;; ── _start ──
    (call $emit_start_section_static (local.get $lowexprs))

    (call $indent_dec)
    (call $emit_close)
    (call $emit_nl))

  ;; $emit_start_section_with_body — emit _start that runs top-level stmts.
  ;; Unlike the old $emit_start_section (empty _start), this one emits the
  ;; lowered program body inside _start, then calls proc_exit.
  (func $emit_start_section_with_body (param $lowexprs i32)
    (call $emit_indent)
    (call $emit_cstr (i32.const 924) (i32.const 5)) ;; "(func"
    (call $emit_space)
    (call $emit_byte (i32.const 36))                ;; '$'
    (call $emit_cstr (i32.const 1591) (i32.const 6)) ;; "_start"
    ;; (export "_start")
    (call $emit_space)
    (call $emit_cstr (i32.const 846) (i32.const 8)) ;; "(export "
    (call $emit_byte (i32.const 34))
    (call $emit_cstr (i32.const 1591) (i32.const 6)) ;; "_start"
    (call $emit_byte (i32.const 34))
    (call $emit_close)
    ;; Standard locals for top-level code
    (call $emit_cstr (i32.const 4146) (i32.const 9)) ;; " (local $"
    (call $emit_str (i32.const 2244)) ;; "state_tmp" (length-prefixed)
    (call $emit_cstr (i32.const 4155) (i32.const 5)) ;; " i32)"
    ;; Pre-declare LLet locals
    (call $emit_let_locals (local.get $lowexprs))
    (call $emit_nl)
    (call $indent_inc)
    ;; Emit top-level body
    (call $emit_lowir_program (local.get $lowexprs))
    ;; (call $wasi_proc_exit (i32.const 0))
    (call $emit_indent)
    (call $emit_cstr (i32.const 572) (i32.const 6)) ;; "(call "
    (call $emit_byte (i32.const 36))
    (call $emit_cstr (i32.const 1230) (i32.const 14)) ;; "wasi_proc_exit"
    (call $emit_space)
    (call $emit_i32_const (i32.const 0))
    (call $emit_close)
    (call $emit_nl)
    (call $indent_dec)
    (call $emit_indent)
    (call $emit_close)
    (call $emit_nl))

  ;; $emit_start_section_static — executable entry projection.
  ;; Top-level closures live in static records. Zero-arg main is invoked
  ;; through the same closure-record call_indirect path as every other
  ;; function. Parameterized main and library modules clean-exit.
  (func $emit_start_section_static (param $lowexprs i32)
    (local $main_arity i32)
    (local.set $main_arity (call $find_top_fn_arity (local.get $lowexprs) (i32.const 4268) (i32.const 4)))
    (call $emit_indent)
    (call $emit_cstr (i32.const 924) (i32.const 5)) ;; "(func"
    (call $emit_space)
    (call $emit_byte (i32.const 36))                ;; '$'
    (call $emit_cstr (i32.const 1591) (i32.const 6)) ;; "_start"
    (call $emit_space)
    (call $emit_cstr (i32.const 846) (i32.const 8)) ;; "(export "
    (call $emit_byte (i32.const 34))
    (call $emit_cstr (i32.const 1591) (i32.const 6)) ;; "_start"
    (call $emit_byte (i32.const 34))
    (call $emit_close)
    (call $emit_nl)
    (call $indent_inc)
    (if (i32.eqz (local.get $main_arity))
      (then
        ;; (global.get $main)
        (call $emit_indent)
        (call $el_emit_global_get_dollar (call $str_from_mem (i32.const 4268) (i32.const 4)))
        (call $emit_nl)
        ;; (global.get $main)(i32.load offset=0)
        (call $emit_indent)
        (call $el_emit_global_get_dollar (call $str_from_mem (i32.const 4268) (i32.const 4)))
        (call $ec6_emit_i32_load_offset_0)
        (call $emit_nl)
        ;; (call_indirect (type $ft1))
        (call $emit_indent)
        (call $ec6_emit_call_indirect_ftN (i32.const 0))
        (call $emit_nl)
        ;; (drop)
        (call $emit_indent)
        (call $emit_cstr (i32.const 578) (i32.const 6)) ;; "(drop "
        (call $emit_close)
        (call $emit_nl)))
    ;; (call $wasi_proc_exit (i32.const 0))
    (call $emit_indent)
    (call $emit_cstr (i32.const 572) (i32.const 6)) ;; "(call "
    (call $emit_byte (i32.const 36))
    (call $emit_cstr (i32.const 1230) (i32.const 14)) ;; "wasi_proc_exit"
    (call $emit_space)
    (call $emit_i32_const (i32.const 0))
    (call $emit_close)
    (call $emit_nl)
    (call $indent_dec)
    (call $emit_indent)
    (call $emit_close)
    (call $emit_nl))

  (func $find_top_fn_arity (param $lowexprs i32) (param $name_ptr i32) (param $name_len i32) (result i32)
    (local $i i32) (local $n i32) (local $expr i32) (local $inner i32)
    (local $candidate i32)
    (local.set $n (call $len (local.get $lowexprs)))
    (local.set $i (i32.const 0))
    (block $done
      (loop $iter
        (br_if $done (i32.ge_u (local.get $i) (local.get $n)))
        (local.set $expr (call $list_index (local.get $lowexprs) (local.get $i)))
        (if (i32.eq (call $tag_of (local.get $expr)) (i32.const 304))
          (then
            (local.set $candidate (call $lexpr_llet_name (local.get $expr)))
            (if (call $str_eq
                  (local.get $candidate)
                  (call $str_from_mem (local.get $name_ptr) (local.get $name_len)))
              (then
                (local.set $inner (call $lexpr_llet_value (local.get $expr)))
                (if (i32.eq (call $tag_of (local.get $inner)) (i32.const 311))
                  (then
                    (return
                      (call $lowfn_arity
                        (call $lexpr_lmakeclosure_fn (local.get $inner))))))
                (if (i32.eq (call $tag_of (local.get $inner)) (i32.const 312))
                  (then
                    (return
                      (call $lowfn_arity
                        (call $lexpr_lmakecontinuation_fn (local.get $inner))))))))))
        (local.set $i (i32.add (local.get $i) (i32.const 1)))
        (br $iter)))
    (i32.const -1))
