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

  # ── Layer 5: Emitter ──
  "bootstrap/src/emit_data.wat"
  "bootstrap/src/emit_infra.wat"
  "bootstrap/src/emit_expr.wat"
  "bootstrap/src/emit_compound.wat"
  "bootstrap/src/emit_stmt.wat"
  "bootstrap/src/emit_module.wat"
)
