#!/bin/bash
# bootstrap/CHUNKS.sh — shared chunk-assembly manifest
#
# Sourced by bootstrap/build.sh (assembles bootstrap/inka.wat) and
# bootstrap/test.sh (assembles each bootstrap/test/**/*.wat harness).
# Per ROADMAP §5: harness assembly mirrors production assembly; chunk
# list lives in one place to keep them in lock-step.
#
# This file is sourced, not executed. Defines the CHUNKS array.

# ─── Chunk assembly order ───────────────────────────────────────────
# Strict dependency order per bootstrap/src/runtime/INDEX.tsv +
# Hβ §2.1 layer structure. Tier N must come after all chunks at
# Tier <N+1.

CHUNKS=(
  # ── Layer 1: Runtime substrate (Wave 2.A factored) ──
  "bootstrap/src/runtime/alloc.wat"      # Tier 0
  "bootstrap/src/runtime/str.wat"        # Tier 1 (uses $alloc)
  "bootstrap/src/runtime/wasi.wat"       # Tier 1 (uses $alloc + $str_*)
  "bootstrap/src/runtime/int.wat"        # Tier 1 (uses $alloc + $str_*)
  "bootstrap/src/runtime/list.wat"       # Tier 1 (uses $alloc)
  "bootstrap/src/runtime/record.wat"     # Tier 1 (uses $alloc + $heap_base)
  "bootstrap/src/runtime/closure.wat"    # Tier 2 (uses $alloc; same shape as record)
  "bootstrap/src/runtime/cont.wat"       # Tier 2 (uses $alloc; H7 multi-shot continuation)
  "bootstrap/src/runtime/graph.wat"      # Tier 3 (uses $alloc + record + list; spec 00 + Hβ §1.2)
  "bootstrap/src/runtime/env.wat"        # Tier 3 (uses $alloc + record + list + str_eq; Hβ §1.2)
  "bootstrap/src/runtime/row.wat"        # Tier 3 (uses $alloc + record + list + str_compare; spec 01 + Hβ §1.10)
  "bootstrap/src/runtime/verify.wat"     # Tier 4 (uses $alloc + record + list; Hβ §1.11 ledger only)
  "bootstrap/src/runtime/wasi_fs.wat"    # Tier 4 (uses Layer 0 wasi_fs imports + str + list; FX walkthrough)
  # Wave 2.C/D Layer 1 substrate complete. Next: Wave 2.E
  # Hβ.lex/parse/infer/lower/emit per Hβ §13 staging.

  # ── Layer 2: Lexer ──
  "bootstrap/src/lexer_data.wat"         # keyword + output data segments
  "bootstrap/src/lexer.wat"
  "bootstrap/src/lex_main.wat"

  # ── Layer 3: Parser ──
  "bootstrap/src/parser_infra.wat"
  "bootstrap/src/parser_pat.wat"
  "bootstrap/src/parser_fn.wat"
  "bootstrap/src/parser_decl.wat"
  "bootstrap/src/parser_expr.wat"
  "bootstrap/src/parser_compound.wat"
  "bootstrap/src/parser_toplevel.wat"

  # ── Layer 4: Inference (per Hβ-infer-substrate.md) ──
  # Per Hβ-infer-substrate.md §8.2 the eventual full layer holds 10
  # chunks (state / reason / ty / scheme / emit_diag / unify / own /
  # walk_expr / walk_stmt / main); chunks land per §13.3 dep order:
  #   1. state.wat — per-walk scratchpads (no deps beyond runtime).
  #   2. reason.wat — 23 canonical Reason constructors (deps: record).
  #   3. ty.wat — 14 Ty constructors + 3 ResumeDiscipline sentinels +
  #      $chase_deep (deps: record + graph; SHARED with Hβ.lower per
  #      Hβ-lower-substrate.md §7.1 — lower lands as the second consumer).
  #   4. scheme.wat — Forall record + $instantiate + $generalize +
  #      $free_in_ty + $ty_substitute (deps: record + list + graph + ty +
  #      reason; canonical algorithms src/infer.nx:1818-1998 + spec 04
  #      §Env+Scheme/§Generalizations/§Instantiations).
  #   5. emit_diag.wat — diagnostic emission helpers (deps: alloc + str
  #      + int + list + wasi + graph + ty + reason; canonical spec 04
  #      §Error handling Hazel pattern + docs/errors catalog;
  #      $infer_emit_type_mismatch / missing_var / occurs_check +
  #      additional catalog-emitted helpers + $render_ty walker over
  #      14 Ty variants).
  # Subsequent: unify.wat, own.wat, walk_expr.wat, walk_stmt.wat,
  # main.wat.
  "bootstrap/src/infer/state.wat"        # Tier 4 (uses $alloc + list + record; Hβ.infer §1)
  "bootstrap/src/infer/reason.wat"       # Tier 5 (uses record; Hβ.infer §1 + §8.1 + 23-variant ADT)
  "bootstrap/src/infer/ty.wat"           # Tier 5 (uses record + graph + list; Hβ.infer §2.3 + Hβ.lower §3.1; 14 Ty + 3 ResumeDiscipline + $chase_deep)
  "bootstrap/src/infer/tparam.wat"       # Tier 5 (uses record; Hβ.infer §2.3 substrate-gap closure 2026-04-26; TParam + field-pair + Ownership; ROADMAP §3 prerequisite)
  "bootstrap/src/infer/scheme.wat"       # Tier 5 (uses record + list + graph + ty + reason; Hβ.infer §2 + §2.4; Forall + instantiate + generalize)
  "bootstrap/src/infer/emit_diag.wat"    # Tier 6 (uses str + int + wasi + graph + ty + reason; Hβ.infer §8.1 + spec 04 §Error handling; 7 emit helpers + $render_ty)
  "bootstrap/src/infer/unify.wat"        # Tier 6 (uses graph + ty + tparam + scheme + reason + emit_diag; Hβ.infer §3 + §6.2 + §7.1 + §8.1 + §8.4 + §11; 25 exports — type unification engine)
  "bootstrap/src/infer/own.wat"          # Tier 7 (uses alloc + str + int + list + record + wasi + graph + state + reason; Hβ.infer §5 + §6.2 + §7.3 + §8.1 + §11; 11 exports — affine ledger + branch protocol + ref-escape + 3 OwnershipViolation diagnostic helpers per emit_diag.wat:189-195 delegation)
  "bootstrap/src/infer/walk_expr.wat"    # Tier 7 (uses alloc + str + int + list + record + wasi + graph + env + state + reason + ty + tparam + scheme + emit_diag + unify + own; Hβ.infer §3 + §4.1 + §4.3 + §5 + §6.3 + §7.2 + §8.1 + §8.4 + §9 + §11; 29 public exports — Expr-tag dispatch + per-variant arms over parser tags 80-101; inert seed-stubs for row + handler-stack + region tracking per named follow-ups)
  "bootstrap/src/infer/walk_stmt.wat"    # Tier 7 (uses walk_expr + scheme + env + graph + ty + tparam + reason + state + runtime; Hβ.infer §3 + §4.2 + §6.3 + §7.2 + §8.1 + §8.4 + §11.2 + §13.3 #9; 12 public exports — Stmt-tag dispatch over parser tags 120-128 + LetStmt/FnStmt fully wired + 5 inert seed-stubs per named follow-ups in chunk header; closes BlockExpr §13.3 #9 forward-decl)
  "bootstrap/src/infer/main.wat"         # Tier 8 (uses walk_stmt.infer_program; Hβ.infer §8.1 + §10.3 + §13.3 #10 — closes the cascade; pipeline-stage boundary $inka_infer; $sys_main retrofit deferred to peer handle Hβ.infer.pipeline-wire pending Hβ.lower)

  # ── Layer 5: Lowering (per Hβ-lower-substrate.md) — CASCADE CLOSED 11/11 ──
  # Per Hβ-lower-substrate.md §7.1 the eventual full layer holds 11
  # chunks (state / lookup / lexpr / classify / walk_const / walk_call /
  # walk_handle / walk_compound / walk_stmt / emit_diag / main); chunks
  # land per §12.3 dep order:
  #   1. state.wat — per-fn locals/captures ledger (deps: alloc + list +
  #      record + str + env from runtime/Layer-1 + env.wat).
  #   2. lookup.wat — live $lookup_ty graph read + $monomorphic_at row-
  #      ground gate + $resume_discipline_of TCont accessor + $ty_make_terror_hole
  #      lookup-private nullary sentinel at tag 114 (deps: graph + row +
  #      ty + wasi; forward-decl $lower_emit_unresolved_type per chunk #4
  #      — RETROFITTED alongside chunk #4's landing).
  #   3. lexpr.wat — 35 LowExpr variant constructors + accessors over
  #      tag region 300-334 (per Hβ-lower-substrate.md §2; src/lower.nx:97-150
  #      canonical) + universal $lexpr_handle accessor with LDeclareFn
  #      tag-313 anomaly arm (deps: record).
  #   4. emit_diag.wat — $lower_emit_unresolved_type + $lower_render_ty
  #      wrapper (deps: str + int + wasi + infer/ty + infer/emit_diag;
  #      Hβ.lower §1.1 + §11 boundary lock; closes the
  #      Hβ.lower.unresolved-emit-retrofit named follow-up).
  #   5. classify.wat — handler-elimination strategy classifier (deps:
  #      lookup; reads TCont.discipline via $resume_discipline_of, returns
  #      0/1/2 strategy code per Hβ-lower-substrate.md §3.1 + §11;
  #      $is_tail_resumptive conservative-Linear seed default per named
  #      follow-up Hβ.lower.tail-resumptive-discrimination — wheel parity
  #      per Anchor 4).
  #   6. walk_const.wat — literal + var-ref arm bodies (deps: lower/state +
  #      lower/lexpr + cross-layer infer/walk_expr.wat for $walk_expr_node_handle;
  #      Hβ.lower §4.2 + §6.3 + §11 + §12.3 #6; 7 exports — 5 literal arms
  #      ($lower_lit_int/float/string/bool/unit) + $lower_var_ref triage
  #      (LLocal/LUpval/LGlobal per Locks #1+#2 wheel-canonical) +
  #      $walk_const_payload_i32 helper; Lock #3 LitBool→LMakeVariant per
  #      HB drift-6 closure; named follow-ups: lvalue-lowfn-lpat-substrate,
  #      upval-handle-resolution, varref-schemekind-dispatch,
  #      state-entry-accessor, litfloat-litunit-harness,
  #      walk_const-lupval-harness).
  # CASCADE CLOSED: 11/11 chunks live; $inka_lower pipeline-stage boundary
  # named at chunk #11 main.wat. Cursor advances to Hβ.infer.pipeline-wire
  # (peer-handle commit retrofitting $sys_main to chain
  # parsed |> $inka_infer |> $inka_lower |> $emit_program) + Hβ.emit
  # substrate growth.
  "bootstrap/src/lower/state.wat"        # Tier 4 (uses $alloc + list + record + str_eq + env_contains; Hβ.lower §1.2)
  "bootstrap/src/lower/lookup.wat"       # Tier 5 (uses graph + row + ty + wasi; Hβ.lower §1.1 + §3.1 + §3.2 + §11; 5 exports — live $lookup_ty + $ty_make_terror_hole nullary sentinel + $row_is_ground monomorphism gate + $monomorphic_at + $resume_discipline_of; forward-decl $lower_emit_unresolved_type per §12.3 dep order chunk #4)
  "bootstrap/src/lower/lexpr.wat"        # Tier 6 (uses $make_record + $record_get + $record_set + $tag_of from record.wat; Hβ.lower §2; 35 LowExpr variant constructors + 67 non-handle accessors + universal $lexpr_handle over tag region 300-334; LDeclareFn tag-313 anomaly per §11 — handle returns 0; 335-349 reserved for future LowExpr variants)
  "bootstrap/src/lower/emit_diag.wat"     # Tier 6 (uses str + int + wasi + ty + infer/emit_diag; Hβ.lower §1.1 + §11 + §12.3 #4; 2 exports — $lower_emit_unresolved_type closes Hβ.lower.unresolved-emit-retrofit named follow-up from lookup.wat + $lower_render_ty wraps infer's $render_ty with tag-114 TError-hole sentinel arm per §11 boundary lock)
  "bootstrap/src/lower/classify.wat"     # Tier 7 (uses lower/lookup + infer/ty; Hβ.lower §3.1 + §11 + §12.3 #5; 3 exports — $classify_handler 3-arm dispatch on TCont.discipline (250/251/252) returning strategy 0/1/2 + $is_tail_resumptive conservative-Linear seed default per named follow-up Hβ.lower.tail-resumptive-discrimination + $either_strategy returns Linear per §11 lock; named follow-ups: tail-resumptive-discrimination, either-install-negotiation, classify-trap-testing)
  "bootstrap/src/lower/walk_const.wat"   # Tier 7 (uses lower/state + lower/lexpr + cross-layer infer/walk_expr.wat for $walk_expr_node_handle; Hβ.lower §4.2 + §6.3 + §11 + §12.3 #6; 7 exports — 5 literal arms + $lower_var_ref triage (LLocal/LUpval/LGlobal per Locks #1+#2 wheel-canonical) + $walk_const_payload_i32 helper; Lock #3 LitBool→LMakeVariant per HB drift-6 closure; named follow-ups: lvalue-lowfn-lpat-substrate, upval-handle-resolution, varref-schemekind-dispatch, state-entry-accessor, litfloat-litunit-harness, walk_const-lupval-harness)
  "bootstrap/src/lower/walk_call.wat"    # Tier 7 (uses lookup + lexpr + state + cross-layer infer/walk_expr.wat + runtime/list; Hβ.lower §3.2 + §4.2 + §6.2 + §11 + §12.3 #7; 6 exports — $lower_call (CallExpr) + $lower_call_default (mono/poly gate) + $lower_perform (PerformExpr — wheel-parity LPerform per Lock #2) + $lower_resume (ResumeExpr → LReturn per Lock #6) + $derive_ev_slots (Lock #7 empty-list seed default per Hβ.lower.derive-ev-slots-naming follow-up) + $lower_args (chunk-private buffer-counter helper); Lock #1 polymorphic→LSuspend tag 325 NOT LMakeClosure; partial $lower_expr dispatcher retrofitted by chunk #8 to add tag 93/101 arms; named follow-ups: perform-multishot-dispatch, derive-ev-slots-naming, resume-harness, lower-call-default-signature-alignment, varref-schemekind-dispatch, op-type-resolution, resume-state-updates-threading, lower-expr-dispatch-extension)
  "bootstrap/src/lower/walk_handle.wat"  # Tier 7 (uses lookup + lexpr + cross-layer infer/walk_expr.wat + cross-chunk lower/walk_call.wat $lower_expr; Hβ.lower §4.2 + §6.2 + §11 + §12.3 #8; 8 exports — $lower_handle (HandleExpr → LBlock+LHandle per Lock #1) + $lower_pipe (5-PipeKind dispatch) + 5 per-verb arms ($lower_pipe_forward/diverge/compose/handle/feedback) + $lower_handler_arms_as_decls (Lock #7 third caller — empty-list seed pending Hβ.lower.handler-arm-decls-substrate); Lock #2 PTeeBlock+PTeeInline collapse; Lock #4 classify_handler NOT INVOKED (deferred to emit per wheel); Lock #6 LMakeContinuation NOT constructed here; RETROFITS walk_call.wat $lower_expr with tag-93 + tag-101 arms; named follow-ups: classify-at-handle-site, handle-pipe-harness-builders, handler-arm-decls-substrate, feedback-state-slot-allocation, diverge-irregular-fallback-harness, handle-expr-arm-row-passthrough)
  "bootstrap/src/lower/walk_compound.wat" # Tier 7 (uses lookup + lexpr + cross-layer infer/walk_expr.wat + cross-chunk lower/walk_call.wat $lower_expr; Hβ.lower §4.2 + §6.3 + §11 + §12.3 #9; 11 exports — $lower_binop (closes Hβ.lower.binop-arm at ab76cc9) + $lower_unary_op + $lower_lambda + $lower_if + $lower_block + $lower_match + $lower_make_list / $lower_make_tuple + $lower_make_record + $lower_named_record + $lower_field; RETROFITS walk_call.wat $lower_expr with tag-86/87/89/90/91/92/96/97/98/99/100 arms; named follow-ups: lambda-capture-substrate, blockexpr-stmts-substrate, match-arm-pattern-substrate, field-offset-resolution)
  "bootstrap/src/lower/walk_stmt.wat"     # Tier 8 (uses lower/state + lower/lexpr + lower/walk_call $lower_expr + lower/walk_handle $lower_handler_arms_as_decls + cross-layer infer/walk_expr.wat + runtime/list + record; Hβ.lower §4.3 + §6.3 + §11 + §12.3 #10; 11 exports — $lower_stmt (NodeBody+Stmt-tag dispatcher per Lock #12) + $lower_stmt_list (Ω.3 buffer-counter per Lock #11) + 9 per-Stmt arms over parser tags 120-128; FnStmt Lock #1 LLet+LMakeClosure NOT bare LDeclareFn + LetStmt PVar-only Lock #5 + 4 inert LConst-sentinel arms Lock #9 + HandlerDeclStmt invokes chunk #8 helper Lock #7 third caller + ExprStmt $lower_expr passthrough Lock #8 + Documented inner-recurse Lock #10; named follow-ups: fn-stmt-closure-substrate, fn-stmt-frame-discipline, letstmt-destructure, handler-arm-decls-substrate, documented-arm-substrate, toplevel-pre-register)
  "bootstrap/src/lower/main.wat"          # Tier 9 (uses lower/walk_stmt $lower_stmt_list; Hβ.lower §4.3 + §10.3 + §13 + §12.3 #11 — closes the cascade; pipeline-stage boundary $inka_lower per Hβ-bootstrap §1.15 + §10.3 — symmetric to $inka_infer; $sys_main retrofit deferred to peer handle Hβ.infer.pipeline-wire per Lock #4 two-stage cascade-closure-then-peer-handle pattern)

  # ── Layer 6: Emitter ──
  "bootstrap/src/emit_data.wat"
  "bootstrap/src/emit_infra.wat"
  "bootstrap/src/emit_expr.wat"
  "bootstrap/src/emit_compound.wat"
  "bootstrap/src/emit_stmt.wat"
  "bootstrap/src/emit_module.wat"
)
