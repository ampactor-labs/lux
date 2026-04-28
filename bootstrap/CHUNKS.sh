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

  # ── Layer 5: Lowering (per Hβ-lower-substrate.md) ──
  # Per Hβ-lower-substrate.md §7.1 the eventual full layer holds 11
  # chunks (state / lookup / lexpr / classify / walk_const / walk_call /
  # walk_handle / walk_compound / walk_stmt / emit_diag / main); chunks
  # land per §12.3 dep order:
  #   1. state.wat — per-fn locals/captures ledger (deps: alloc + list +
  #      record + str + env from runtime/Layer-1 + env.wat).
  #   2. lookup.wat — live $lookup_ty graph read + $monomorphic_at row-
  #      ground gate + $resume_discipline_of TCont accessor + $ty_make_terror_hole
  #      lookup-private nullary sentinel at tag 114 (deps: graph + row +
  #      ty + wasi; forward-decl $lower_emit_unresolved_type per chunk #4).
  #   3. lexpr.wat — 35 LowExpr variant constructors + accessors over
  #      tag region 300-334 (per Hβ-lower-substrate.md §2; src/lower.nx:97-150
  #      canonical) + universal $lexpr_handle accessor with LDeclareFn
  #      tag-313 anomaly arm (deps: record).
  # Subsequent: classify.wat, walk_*.wat, emit_diag.wat, main.wat.
  "bootstrap/src/lower/state.wat"        # Tier 4 (uses $alloc + list + record + str_eq + env_contains; Hβ.lower §1.2)
  "bootstrap/src/lower/lookup.wat"       # Tier 5 (uses graph + row + ty + wasi; Hβ.lower §1.1 + §3.1 + §3.2 + §11; 5 exports — live $lookup_ty + $ty_make_terror_hole nullary sentinel + $row_is_ground monomorphism gate + $monomorphic_at + $resume_discipline_of; forward-decl $lower_emit_unresolved_type per §12.3 dep order chunk #4)
  "bootstrap/src/lower/lexpr.wat"        # Tier 6 (uses $make_record + $record_get + $record_set + $tag_of from record.wat; Hβ.lower §2; 35 LowExpr variant constructors + 67 non-handle accessors + universal $lexpr_handle over tag region 300-334; LDeclareFn tag-313 anomaly per §11 — handle returns 0; 335-349 reserved for future LowExpr variants)

  # ── Layer 6: Emitter ──
  "bootstrap/src/emit_data.wat"
  "bootstrap/src/emit_infra.wat"
  "bootstrap/src/emit_expr.wat"
  "bootstrap/src/emit_compound.wat"
  "bootstrap/src/emit_stmt.wat"
  "bootstrap/src/emit_module.wat"
)
