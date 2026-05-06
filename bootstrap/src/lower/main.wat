  ;; ═══ main.wat — Hβ.lower pipeline-stage boundary (Tier 9) ═════════════
  ;; Hβ.lower cascade chunk #11 of 11 per Hβ-lower-substrate.md §12.3 dep order.
  ;; CASCADE CLOSURE.
  ;;
  ;; Implements: Hβ-lower-substrate.md §4.3 lines 521-554
  ;;             ($lower_program orchestrator iterating top-level stmts) +
  ;;             §7.1 line 686 ("main.wat ;; Tier 9 — $lower_program orchestrator") +
  ;;             §7.4 ~100-line estimate +
  ;;             §10 composition with Hβ.infer / Hβ.emit / cont.wat / LFeedback +
  ;;             §10.3 the CLEAN handoff (infer→lower→emit; graph populated by
  ;;             $inka_infer is read-only here; LowExpr list IS the new artifact) +
  ;;             §11 acceptance + §12.3 #11 dep order (closes the cascade) +
  ;;             §13 closing (the seed becomes a full Mentl compiler) +
  ;;             Hβ-bootstrap.md §1.15 (entry-handler convention —
  ;;             $inka_<verb> naming) + §2.1 Layer 5 (Lowering) +
  ;;             docs/specs/05-lower.md §The LookupTy effect / §LowIR /
  ;;             §No subst threading +
  ;;             canonical wheel src/lower.mn:1106-1110 lower_program.
  ;;
  ;; Realizes the pipeline-stage projection of primitive #3 (the five verbs
  ;; — DESIGN.md §0.5) at the seed's lowering layer, symmetric to
  ;; $inka_infer's primitive #8 projection at the inference layer. Closes
  ;; the Hβ.lower cascade (11/11 chunks per §12.3). Names the boundary
  ;; where Hβ.emit will read the LowExpr list.
  ;;
  ;; Exports:    $inka_lower (pipeline-stage entry — delegates to
  ;;               $lower_program; takes typed-AST stmts list; returns the
  ;;               flat LowExpr list ready for $emit_program consumption),
  ;;             $lower_program (algorithmic-core orchestrator —
  ;;               delegates to $lower_stmt_list per Lock #1)
  ;; Uses:       $lower_stmt_list (walk_stmt.wat:426-442 — the buffer-counter
  ;;               iteration this stage drives)
  ;; Test:       bootstrap/test/lower/main_inka_lower_smoke.wat
  ;;
  ;; ═══ LOCKS (wheel-canonical override walkthrough §4.3 prose) ═════════
  ;;
  ;; Lock #1: $lower_program body is ONE call to $lower_stmt_list.
  ;;          Wheel src/lower.mn:1106-1110 does collect_top_level_names +
  ;;          ls_register_globals + lower_stmt_list. Seed elides the first
  ;;          two — state.wat (chunk #1) does not yet expose
  ;;          $ls_register_globals; adding inline drift-9s. Named follow-up
  ;;          Hβ.lower.toplevel-pre-register covers wheel parity (peer-cascade
  ;;          with Hβ.infer.toplevel-pre-register named in walk_stmt.wat:
  ;;          236-239 chunk header).
  ;;
  ;; Lock #2: $inka_lower is the pipeline-stage boundary; $lower_program is
  ;;          the algorithmic core. Two symbols, one delegation each. Mirrors
  ;;          Hβ.infer's $inka_infer / $infer_program two-symbol pattern per
  ;;          Hβ-bootstrap §1.15.
  ;;
  ;; Lock #3: Result type (result i32) — returns the flat LowExpr list
  ;;          pointer. $lower_stmt_list returns i32 per walk_stmt.wat:426-427
  ;;          + Lock #11 buffer-counter Ω.3. The LowExpr list IS the artifact
  ;;          $emit_program will consume post-pipeline-wire. Differs from
  ;;          $inka_infer (no result — graph is the artifact); Hβ.lower has
  ;;          TWO artifacts (graph stays from infer; LowExpr list is fresh).
  ;;
  ;; Lock #4: $sys_main retrofit is the SEPARATE peer-handle commit
  ;;          Hβ.infer.pipeline-wire (named in Hβ.infer's main.wat:110-119 +
  ;;          ROADMAP.md §Near-Term Execution Order #2). NOT touched here.
  ;;          Two-stage cascade-closure-then-peer-handle-retrofit pattern —
  ;;          third instance per Anchor 7.4 (chunk #4 emit_diag.wat closed
  ;;          unresolved-emit-retrofit; chunk #9.5 closed binop-arm; this
  ;;          chunk closes the cascade, pipeline-wire closes next).
  ;;
  ;; Lock #5: NO new tags. Pure delegation per Lock #5.
  ;;          Tag regions owned upstream:
  ;;          300-349 LowExpr (lexpr.wat); 250-252 ResumeDiscipline (infer/
  ;;          ty.wat); 60-64 NodeKind (graph.wat); 110-113 NBody (parser_
  ;;          infra.wat); 120-128 Stmt (parser_decl.wat).
  ;;
  ;; ═══ EIGHT INTERROGATIONS (per Hβ-lower-substrate.md §5 applied to the
  ;;                           pipeline-stage boundary) ══════════════════
  ;;
  ;; 1. Graph?      $inka_lower does not touch the graph directly. Every
  ;;                $graph_chase happens INSIDE the delegated $lower_program
  ;;                → $lower_stmt_list → $lower_stmt → $lower_expr →
  ;;                $lookup_ty (lookup.wat:148-173) call chain. main.wat
  ;;                names the stage; the stage runs through chunks #2-#10.
  ;;                Per §10.3: post-call the LowExpr list IS the new
  ;;                artifact; graph remains live for emit's $lookup_ty calls.
  ;; 2. Handler?    @resume=OneShot. Wheel's `handle … with lowering_ctx`
  ;;                (src/lower.mn + spec 05 §LowerCtx) is a OneShot row-
  ;;                accumulation handler; at the seed it maps onto direct
  ;;                WAT call flow (no resume machinery). When the wheel
  ;;                lands the post-L1 lower-side Synth chain, it composes
  ;;                ON this substrate; main.wat stays inert.
  ;; 3. Verb?       `|>` — this chunk draws the SECOND pipeline-stage step
  ;;                in the planned chain
  ;;                  parsed_stmts |> $inka_infer |> $inka_lower
  ;;                              |> $emit_program
  ;;                The $inka_<verb> convention (Hβ-bootstrap §1.15) names
  ;;                each `|>` stage; the verb is implicit in the call sequence.
  ;; 4. Row?        EfPure at this chunk. main.wat performs no effect ops;
  ;;                the wheel's lower_program toplevel is also pure-modulo-
  ;;                graph-read per src/lower.mn:1106-1110 (graph IS the
  ;;                constraint store per §0.5; $lookup_ty is a read).
  ;; 5. Ownership?  $inka_lower takes stmts by shared pointer (`ref`); no
  ;;                consumption — the stmts list remains available; graph
  ;;                stays shared with $inka_infer's upstream. Returned
  ;;                LowExpr list is FRESH (bump-allocated by lexpr.wat
  ;;                constructors); OWN by caller. No own/ref annotation
  ;;                at WAT layer; pointer-pass-through.
  ;; 6. Refinement? None at this chunk. TRefined obligations land inside
  ;;                walk_expr arms via $verify_record at infer time; lower's
  ;;                $lookup_ty returns TRefined transparent (§5.3); main.wat
  ;;                is transit.
  ;; 7. Gradient?   The post-$inka_lower LowExpr list IS the gradient
  ;;                surface for Hβ.emit. The continuous gradient becomes
  ;;                machine code at the layer this chunk closes. main.wat
  ;;                makes that surface AVAILABLE by closing the lowering
  ;;                pipeline stage; gradient cash-out happens at chunk #7
  ;;                $monomorphic_at (LCall vs LSuspend) and chunk #5
  ;;                $classify_handler (TailResumptive/Linear/MultiShot).
  ;; 8. Reason?     main.wat adds no Reason edges. Reasons accumulate inside
  ;;                walk arms; every LowExpr carries the source AST handle
  ;;                (field 0 per chunk #3 lexpr.wat $lexpr_handle). The Why
  ;;                Engine (when the wheel composes on this layer per Mentl
  ;;                tentacle #8) walks back: "LowExpr produced by $inka_lower
  ;;                stage → $lower_program → $lower_stmt_list →
  ;;                src/lower.mn:1106-1110 + spec 05 §LowIR".
  ;;
  ;; ═══ FORBIDDEN PATTERNS (drift modes 1-9) ════════════════════════════
  ;;
  ;; Drift 1 (Rust vtable):       NO $inka_lower_closure / $lower_dispatch_
  ;;                              table / data segment $pipeline_stage_table.
  ;;                              Two direct functions; ONE call each.
  ;; Drift 2 (Scheme env frame):  NO $frame / $lower_frame parameter; state.wat
  ;;                              owns lower-state; main.wat reads nothing.
  ;; Drift 3 (Python dict):       NO string-keyed pipeline-stage dispatch;
  ;;                              stages are direct $inka_<verb> symbols.
  ;; Drift 4 (Haskell monad):     NO LowerM / PipelineM monad shape; direct
  ;;                              call sequence.
  ;; Drift 5 (C calling conv):    ONE i32 parameter — stmts. No (stmts, ctx,
  ;;                              errors_out) struct; no out-parameter.
  ;; Drift 6 (primitive special): The lowering stage is not "special"; every
  ;;                              $inka_<verb> stage has the same one-
  ;;                              delegating-function shape per Lock #2.
  ;; Drift 7 (parallel arrays):   NO (stage_names[], stage_fns[]) registry;
  ;;                              the chain IS the call sequence (lands in
  ;;                              Hβ.infer.pipeline-wire per Lock #4).
  ;; Drift 8 (mode flag):         NO mode: i32 parameter ("strict" / "wheel-
  ;;                              parity"); one $inka_lower; the wheel-vs-
  ;;                              seed difference is the named follow-up
  ;;                              Hβ.lower.toplevel-pre-register per Lock #1.
  ;; Drift 9 (deferred-by-omis):  The $sys_main retrofit is named peer handle
  ;;                              Hβ.infer.pipeline-wire (Lock #4); the two-
  ;;                              pass globals is Hβ.lower.toplevel-pre-
  ;;                              register (Lock #1). NEITHER a silent TODO.
  ;;
  ;; Foreign-fluency forbidden:  "compiler driver" / "frontend pipeline" /
  ;;                              "backend driver" / "main entry" / "main
  ;;                              function" / "orchestration" → Mentl-native
  ;;                              phrases are "pipeline-stage boundary" +
  ;;                              "kernel primitive #3 verb projection" +
  ;;                              "§10.3 clean handoff" + "lower_program
  ;;                              orchestrator". "LLVM IR" / "GHC Core" /
  ;;                              "OCaml closure conversion" → "LowExpr per
  ;;                              spec 05".
  ;;
  ;; ═══ TAG REGION ══════════════════════════════════════════════════════
  ;;
  ;; This chunk introduces NO new tags. Pure delegation per Lock #5.
  ;;
  ;; ═══ NAMED FOLLOW-UPS (per Drift 9 closure + Hβ-lower §11 + §12) ═════
  ;;
  ;; - Hβ.infer.pipeline-wire: $sys_main retrofit (build.sh Layer 6 inline)
  ;;   to chain $inka_infer + $inka_lower between $parse_program and
  ;;   $emit_program. UNGATED post-this-chunk (the cascade closure ungates
  ;;   it per Hβ-infer-substrate.md §10.3 + Hβ-lower §10.3). $sys_main
  ;;   becomes:
  ;;     stdin |> read_all_stdin |> lex |> parse_program
  ;;       |> $inka_infer |> $inka_lower |> $emit_program |> proc_exit
  ;;   Lands as the IMMEDIATE next commit per Lock #4.
  ;;
  ;; - Hβ.lower.toplevel-pre-register: $lower_program two-pass
  ;;   collect_top_level_names + ls_register_globals per src/lower.mn:
  ;;   1106-1110 + walk_stmt.wat:236-239 chunk header peer-cascade with
  ;;   Hβ.infer.toplevel-pre-register. Lands when forward-reference
  ;;   resolution at the seed actually needs it (currently chunks #6/#7/#10
  ;;   harnesses pass without it).
  ;;
  ;; - Hβ.lower.emit-extension: extend Layer 6 emit_*.wat to consume
  ;;   LowExpr per Hβ-lower-substrate.md §9.2. Currently emit chunks
  ;;   template WAT directly from AST; post-pipeline-wire they read the
  ;;   $inka_lower output. Walkthrough Hβ-emit-substrate.md TBD per
  ;;   Hβ-lower-substrate.md §13 sibling list.
  ;;
  ;; - Hβ.lower.synth: Synth-handler composition on top of $inka_lower
  ;;   per insight #11 (Mentl IS speculative inference firing on every
  ;;   save) + H7 §2.5. The wheel runs this; the seed's main.wat stays
  ;;   inert.

  ;; ─── $lower_program — algorithmic-core orchestrator ──────────────────
  ;;
  ;; Per Hβ-lower-substrate.md §4.3 lines 532-554 + canonical wheel
  ;; src/lower.mn:1106-1110:
  ;;
  ;;   fn lower_program(stmts) = {
  ;;     let globals = collect_top_level_names(stmts)
  ;;     perform ls_register_globals(globals)
  ;;     lower_stmt_list(stmts)
  ;;   }
  ;;
  (func $lower_program (export "lower_program")
        (param $stmts i32) (result i32)
    (local $globals i32)
    (call $lower_init)
    (call $ls_reset_function)
    (local.set $globals (call $lower_collect_top_level_names (local.get $stmts)))
    (call $ls_register_globals (local.get $globals))
    (call $lower_stmt_list (local.get $stmts)))

  ;; ─── Top-level name collection ────────────────────────────────────
  ;; Mirrors src/lower.mn collect_top_level_names. FnStmt and PVar
  ;; LetStmt names become module globals before the statement walk, so
  ;; function bodies lower cross-function references as LGlobal.
  (func $lower_collect_top_level_names (param $stmts i32) (result i32)
    (local $n i32) (local $i i32) (local $buf i32) (local $count i32)
    (local $node i32) (local $name i32)
    (local.set $n (call $len (local.get $stmts)))
    (local.set $buf (call $make_list (local.get $n)))
    (local.set $i (i32.const 0))
    (local.set $count (i32.const 0))
    (block $done
      (loop $iter
        (br_if $done (i32.ge_u (local.get $i) (local.get $n)))
        (local.set $node (call $list_index (local.get $stmts) (local.get $i)))
        (local.set $name (call $lower_top_level_name_from_node (local.get $node)))
        (if (i32.ne (local.get $name) (i32.const 0))
          (then
            (local.set $buf
              (call $list_extend_to
                (local.get $buf)
                (i32.add (local.get $count) (i32.const 1))))
            (drop (call $list_set
              (local.get $buf)
              (local.get $count)
              (local.get $name)))
            (local.set $count (i32.add (local.get $count) (i32.const 1)))))
        (local.set $i (i32.add (local.get $i) (i32.const 1)))
        (br $iter)))
    (i32.store (local.get $buf) (local.get $count))
    (local.get $buf))

  (func $lower_top_level_name_from_node (param $node i32) (result i32)
    (local $body i32) (local $body_tag i32) (local $stmt i32)
    (local.set $body (i32.load offset=4 (local.get $node)))
    (local.set $body_tag (i32.load offset=0 (local.get $body)))
    (if (i32.ne (local.get $body_tag) (i32.const 111))
      (then (return (i32.const 0))))
    (local.set $stmt (i32.load offset=4 (local.get $body)))
    (call $lower_top_level_name_from_stmt (local.get $stmt)))

  (func $lower_top_level_name_from_stmt (param $stmt i32) (result i32)
    (local $tag i32) (local $pat i32)
    (local.set $tag (call $tag_of (local.get $stmt)))
    ;; FnStmt(name, ...)
    (if (i32.eq (local.get $tag) (i32.const 121))
      (then (return (i32.load offset=4 (local.get $stmt)))))
    ;; LetStmt(PVar(name), ...)
    (if (i32.eq (local.get $tag) (i32.const 120))
      (then
        (local.set $pat (i32.load offset=4 (local.get $stmt)))
        (if (i32.eq (call $tag_of (local.get $pat)) (i32.const 130))
          (then (return (i32.load offset=4 (local.get $pat)))))))
    ;; Documented(_, inner_node)
    (if (i32.eq (local.get $tag) (i32.const 128))
      (then
        (return
          (call $lower_top_level_name_from_node
            (i32.load offset=8 (local.get $stmt))))))
    (i32.const 0))

  ;; ─── $inka_lower — the pipeline-stage entry ──────────────────────────
  ;;
  ;; Per Hβ-lower-substrate.md §10.3 + Hβ-bootstrap §1.15 entry-handler
  ;; convention. Symmetric to $inka_infer (infer/main.wat:154-156). Lock #2:
  ;; pipeline-stage boundary distinct from $lower_program algorithmic core.
  ;; Lock #3: returns the LowExpr list pointer (the new artifact $emit_program
  ;; will consume post-Hβ.infer.pipeline-wire).

  (func $inka_lower (export "inka_lower")
        (param $stmts i32) (result i32)
    (call $lower_program (local.get $stmts)))
