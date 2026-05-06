  ;; ═══ main.wat — Hβ.infer pipeline-stage boundary (Tier 8) ════════════
  ;; Implements: Hβ-infer-substrate.md §8.1 main.wat row
  ;;             ("Tier 8 — top-level orchestrator $infer_program") +
  ;;             §8.4 ~150-line estimate +
  ;;             §10 composition with Hβ.lex / Hβ.parse / Hβ.lower / Hβ.emit +
  ;;             §10.3 the CLEAN handoff (inference produces typed AST +
  ;;             populated graph; lower reads via $graph_chase) +
  ;;             §11 acceptance + §13.3 #10 dep order (closes the cascade) +
  ;;             Hβ-bootstrap.md §1.15 (entry-handler convention —
  ;;             $inka_<verb> naming) + §2.1 Layer 4 (Inference) +
  ;;             docs/specs/04-inference.md §What the walk produces +
  ;;             canonical wheel src/infer.mn:182-186 infer_program.
  ;;
  ;; Realizes the pipeline-stage projection of primitive #8 (HM inference
  ;; live + productive-under-error + with Reasons — DESIGN.md §0.5) at the
  ;; seed. Closes the Hβ.infer cascade (10/10 chunks per §13.3). Names
  ;; the boundary where Hβ.lower will read the graph via $graph_chase.
  ;;
  ;; Exports:    $inka_infer (pipeline-stage entry — delegates to
  ;;               $infer_program from walk_stmt.wat; takes parsed
  ;;               toplevel stmts list; returns after the inference walk
  ;;               populates the graph + env)
  ;; Uses:       $infer_program (walk_stmt.wat — the inference walk this
  ;;               stage drives)
  ;; Test:       bootstrap/test/infer/main_inka_infer_smoke.wat
  ;;
  ;; ═══ EIGHT INTERROGATIONS (per Hβ-infer-substrate.md §6 applied to the
  ;;                           pipeline-stage boundary) ══════════════════
  ;;
  ;; 1. Graph?      $inka_infer does not touch the graph directly. Every
  ;;                $graph_bind / $graph_fresh_ty / $graph_chase happens
  ;;                inside the delegated $infer_program call (walk_stmt.wat:
  ;;                708-713) and downstream walk_expr / unify / own arms.
  ;;                main.wat names the stage; the stage runs through prior
  ;;                chunks. Per §10.3: post-call the graph IS the artifact
  ;;                Hβ.lower will read via $graph_chase.
  ;; 2. Handler?    @resume=OneShot. Wheel's `handle … with infer_ctx`
  ;;                (src/infer.mn:184) is a OneShot row-accumulation
  ;;                handler; at the seed it maps onto direct WAT call
  ;;                flow (no resume machinery). When the wheel lands the
  ;;                Synth handler chain (Hβ.infer.synth follow-up per
  ;;                §10.5 + §12), it composes ON this substrate via
  ;;                cont.wat $graph_push_checkpoint / rollback; main.wat
  ;;                stays inert.
  ;; 3. Verb?       `|>` — this chunk draws ONE pipeline-stage step in
  ;;                the planned chain
  ;;                  parsed_stmts |> $inka_infer |> $inka_lower
  ;;                              |> $emit_program
  ;;                The verb is implicit in the future call sequence;
  ;;                the symbol convention `$inka_<verb>` (per
  ;;                Hβ-bootstrap §1.15) names each `|>` stage.
  ;; 4. Row?        EfPure at this chunk. main.wat performs no effect ops;
  ;;                the wheel's infer_program toplevel is also pure-
  ;;                modulo-graph-mutation per src/infer.mn:182-186 (the
  ;;                graph IS the constraint store per §0.5).
  ;; 5. Ownership?  $inka_infer takes stmts by shared pointer (`ref` in
  ;;                the wheel); no consumption — the stmts list remains
  ;;                available to the future $inka_lower stage. No own/ref
  ;;                annotation at the WAT layer; pointer-pass-through.
  ;; 6. Refinement? None at this chunk. TRefined obligations land inside
  ;;                walk_expr arms via $verify_record; main.wat is transit.
  ;; 7. Gradient?   The post-$inka_infer graph state IS the gradient
  ;;                surface for Hβ.lower. Per §10.3: monomorphism is a
  ;;                graph read (not an inference-side flag); main.wat
  ;;                makes that read AVAILABLE by closing the inference
  ;;                pipeline stage.
  ;; 8. Reason?     main.wat adds no Reason edges. The Reasons accumulate
  ;;                inside walk arms via reason.wat constructors. main.wat
  ;;                cites §10.3 in commentary so the Why Engine (when it
  ;;                composes on this layer per the wheel's Mentl tentacle
  ;;                #8) can walk back: "graph state produced by inka_infer
  ;;                stage → $infer_program → $infer_stmt_list →
  ;;                src/infer.mn:182-186".
  ;;
  ;; ═══ FORBIDDEN PATTERNS (drift modes 1-9) ════════════════════════════
  ;;
  ;; Drift 1 (Rust vtable):       NO $inka_infer_closure / dispatch table.
  ;;                              One direct function.
  ;; Drift 2 (Scheme env frame):  NO env_frame parameter; env.wat owns env
  ;;                              state.
  ;; Drift 3 (Python dict):       NO string-keyed pipeline-stage dispatch;
  ;;                              stages are direct symbols.
  ;; Drift 4 (Haskell monad):     NO InferM / PipelineM monad shape;
  ;;                              direct call to $infer_program.
  ;; Drift 5 (C calling conv):    ONE i32 parameter — stmts. No (stmts,
  ;;                              ctx, errors_out) struct.
  ;; Drift 6 (primitive special): The inference stage is not "special";
  ;;                              every $inka_<verb> stage has the same
  ;;                              one-delegating-function shape.
  ;; Drift 7 (parallel arrays):   NO (stage_names[], stage_fns[]) registry;
  ;;                              the chain is the call sequence.
  ;; Drift 8 (mode flag):         NO mode: i32 parameter ("strict" /
  ;;                              "incremental"); one $inka_infer.
  ;; Drift 9 (deferred-by-omis):  The $sys_main retrofit is the named peer
  ;;                              handle Hβ.infer.pipeline-wire below —
  ;;                              NOT a silent TODO inline.
  ;;
  ;; Foreign-fluency forbidden:  "compiler driver" / "frontend pipeline" /
  ;;                              "Algorithm W" / "constraint set" — Mentl-
  ;;                              native phrase is "pipeline stage" +
  ;;                              "kernel primitive #8" + "§10.3 clean
  ;;                              handoff".
  ;;
  ;; ═══ TAG REGION ══════════════════════════════════════════════════════
  ;;
  ;; This chunk introduces NO new tags. Pure delegation.
  ;;
  ;; ═══ NAMED FOLLOW-UPS (per Drift 9 + Hβ-infer §12) ═══════════════════
  ;;
  ;; - Hβ.infer.pipeline-wire: $sys_main retrofit (build.sh Layer 6
  ;;   inline) to chain $inka_infer between $parse_program and
  ;;   $emit_program. GATED on Hβ.lower arrival per §10.3 + §10.4 — the
  ;;   clean handoff is infer→lower; emit_program does not consume graph
  ;;   state, so wiring infer alone inserts compute that produces an
  ;;   unread artifact AND would trap walk_expr's (unreachable) fallback
  ;;   on parser surface that lower would otherwise consume transparently.
  ;;   When Hβ.lower's $inka_lower lands, $sys_main becomes:
  ;;     stdin |> read_all_stdin |> lex |> parse_program
  ;;       |> $inka_infer |> $inka_lower |> $emit_program |> proc_exit
  ;;
  ;; - Hβ.infer.synth: Synth-handler composition on top of $inka_infer
  ;;   per §10.5 + H7 §2.5. Speculative inference at `??` holes via
  ;;   cont.wat $graph_push_checkpoint / rollback. The wheel runs this;
  ;;   the seed's main.wat stays inert.
  ;;
  ;; - Hβ.infer.overlay: cross-module $inka_infer per §10.5 + §12 (Hβ.infer
  ;;   single-module Tier-3 base). Overlay-aware $env_lookup +
  ;;   cross-module scheme resolution. Lands alongside graph.wat overlay
  ;;   primitives.

  ;; ─── $inka_infer — the pipeline-stage entry ──────────────────────────
  ;;
  ;; Per Hβ-infer-substrate.md §8.1 main.wat row + §10 composition + the
  ;; canonical wheel src/infer.mn:182-186:
  ;;
  ;;   fn infer_program(stmts) =
  ;;     handle {
  ;;       infer_stmt_list(stmts)
  ;;     } with infer_ctx
  ;;
  ;; At the seed `infer_ctx` is inert (row composition pending
  ;; Hβ.infer.row-normalize per §12 + reason #4 of the eight); the WAT
  ;; projection is one delegating call to $infer_program, which
  ;; walk_stmt.wat:708-713 already implements as
  ;;   $graph_init + $env_init + $infer_init + $infer_stmt_list(stmts).
  ;;
  ;; Why a separate symbol from $infer_program: pipeline-stage boundary
  ;; vs. inference-walk-over-stmts boundary. Hβ.lower's symmetric
  ;; counterpart will be $inka_lower per §10.3; emit's existing
  ;; $emit_program is the third stage. The $inka_<verb> convention from
  ;; Hβ-bootstrap §1.15 marks pipeline stages; $infer_program (per
  ;; src/infer.mn:182-186) is the algorithmic core.

  (func $inka_infer (export "inka_infer")
        (param $stmts i32)
    (call $infer_program (local.get $stmts)))
