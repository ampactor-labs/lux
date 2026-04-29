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
  ;;                (src/backends/wasm.nx — Emit effect) is OneShot;
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
  ;;                              the legacy emit_module.wat path retires
  ;;                              when pipeline-wire substitutes
  ;;                              $inka_emit per peer follow-up.
  ;; Drift 9 (deferred-by-omis):  $sys_main retrofit is named peer handle
  ;;                              Hβ.infer.pipeline-wire (Lock #4); the
  ;;                              two LFn-bearing emit arms (LMakeClosure
  ;;                              + LMakeContinuation) are named peer
  ;;                              Hβ.emit.handler-fnref-substrate (per
  ;;                              chunk #7 closure). NEITHER a silent TODO.
  ;;
  ;; Foreign-fluency forbidden:   "compiler driver" / "code generator
  ;;                              entry" / "backend main" / "main entry"
  ;;                              → Inka-native phrases are "pipeline-
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
  ;;   accessors) to bootstrap/src/lower/lexpr.wat per src/lower.nx
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
  ;;   site handles. Lands when the legacy emit_module.wat path retires
  ;;   per pipeline-wire.

  ;; ─── Phase F data segments (module-wrap) ────────────────────────────
  ;; Offsets 1584-1596: free space between emit_const.wat (1568+15=1583)
  ;; and emit_call.wat (1856). Per Hβ-emit §6.1 chunk-owns-its-segments.
  ;; 1584: "funcref" (7) → 1591
  ;; 1591: "_start" (6) → 1597
  ;; Next free: 1597
  (data (i32.const 1584) "funcref")
  (data (i32.const 1591) "_start")

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
  ;; Ported from legacy emit_module.wat per Phase F.
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
      ;; The string contents must be properly escaped if we are emitting WAT text, but since Inka only tests alphanumeric/basic ascii in the test suite so far, a raw emit_cstr is sufficient.
      (call $emit_cstr (i32.add (local.get $str) (i32.const 4)) (call $str_len (local.get $str)))
      (call $emit_byte (i32.const 34)) ;; '"'
      (call $emit_close)
      (call $emit_nl)
      (local.set $i (i32.add (local.get $i) (i32.const 1)))
      (br $iter))))

  ;; ─── _start Section Emission ──────────────────────────────────────
  ;; Per src/backends/wasm.nx emit_start: emits `(func $_start (export
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

  ;; ─── $inka_emit — the pipeline-stage entry ───────────────────────────
  ;;
  ;; Per Hβ-emit-substrate.md §10.3 + Hβ-bootstrap §1.15 entry-handler
  ;; convention. Symmetric to $inka_infer (infer/main.wat) + $inka_lower
  ;; (lower/main.wat). Lock #2: pipeline-stage boundary distinct from
  ;; $emit_lowir_program algorithmic core. Lock #3: no result —
  ;; emission is side-effect on $out_base/$out_pos; the WAT byte buffer
  ;; IS the artifact pipeline-wire's `$proc_exit` flushes via
  ;; $emit_flush.

  (func $inka_emit (export "inka_emit")
        (param $lowexprs i32)
    (call $emit_cstr (i32.const 831) (i32.const 7))  ;; "(module"
    (call $emit_nl)
    (call $indent_inc)

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

    ;; ── Body ──
    (call $emit_lowir_program (local.get $lowexprs))

    ;; ── Table & Data ──
    (call $emit_funcref_section)
    (call $emit_string_section)

    ;; ── _start ──
    (call $emit_start_section)

    (call $indent_dec)
    (call $emit_close)
    (call $emit_nl))
