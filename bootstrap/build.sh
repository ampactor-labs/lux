#!/bin/bash
# ═══ Mentl Bootstrap Build Script ═══════════════════════════════════
# Assembles the modular WAT source chunks into the monolith mentl.wat
# and compiles to mentl.wasm.
#
# Source of truth:
#   bootstrap/build.sh           — Layer 0 module shell (inline, this file)
#                                  + Layer 5 entry point (inline, this file)
#                                  + assembly orchestration
#   bootstrap/src/runtime/*.wat  — Layer 1 runtime substrate (Wave 2.A factoring;
#                                  per bootstrap/src/runtime/INDEX.tsv dep graph)
#   bootstrap/src/lexer*.wat     — Layer 2 lexer
#   bootstrap/src/parser_*.wat   — Layer 3 parser
#   bootstrap/src/emit_*.wat     — Layer 4 emitter
#
# Build artifact:
#   bootstrap/mentl.wat           — assembled monolith (auditable as one file)
#   bootstrap/mentl.wasm          — compiled binary
#
# Wave 2.A factoring notes (2026-04-25):
#   The earlier build.sh extracted "shell" + "entry" from a prior
#   mentl.wat using marker-based python; Layer 1 lived inline in the
#   shell. Wave 2.A throws that pattern out: Layer 0 + Layer 5 are
#   defined inline here as heredocs; Layer 1 lives in modular runtime
#   chunks per Hβ §2.1; the build is pure concatenation in dependency
#   order. Per Onramp's stages-and-tools pattern + Hβ §2.1 modular
#   discipline.
#
# Usage:
#   ./bootstrap/build.sh         # build mentl.wasm
#   ./bootstrap/build.sh test    # build + run first-light tests

set -euo pipefail
cd "$(dirname "$0")/.."

OUT="bootstrap/mentl.wat"
WASM="bootstrap/mentl.wasm"

# Chunk list lives in bootstrap/CHUNKS.sh so bootstrap/test.sh can source
# the same manifest. Per ROADMAP §5 + drift-mode-7 audit: ONE source of
# truth for chunk assembly order.
source "$(dirname "$0")/CHUNKS.sh"

echo "═══ Mentl Bootstrap Build ═══"
echo "Assembling ${#CHUNKS[@]} source chunks..."

# ─── Layer 0: Module shell (inline) ─────────────────────────────────
# Module wrapper + WASI preview1 imports + linear memory + Layer 0
# globals ($heap_base / $heap_ptr per Hβ §1.1). All Layer 1 runtime
# substrate composes on these globals.

cat > "$OUT" <<'EOF'
;; mentl.wat — The Reference Seed Compiler (Tier 1 Runtime)
;;
;; ASSEMBLED FROM bootstrap/src/* by bootstrap/build.sh. Do not edit
;; this file directly; edit the chunk files in bootstrap/src/ and
;; rerun build.sh. Per Hβ §2.1 modular pivot (plan §136 2026-04-23).
;;
;; HEAP_BASE = 4096 (0x1000)
;; Nullary sentinel values: [0, HEAP_BASE)
;; Allocated records: >= HEAP_BASE
;; Bump allocator starts at 1_048_576 (1 MiB)
;; String layout: [len:i32][bytes...]
;; List layout:   [count:i32][tag:i32][payload...]
;;   tag 0 = flat, tag 1 = snoc, tag 3 = concat, tag 4 = slice

(module
  ;; ─── WASI Imports (preview1) ──────────────────────────────────────
  (import "wasi_snapshot_preview1" "fd_read"
    (func $wasi_fd_read (param i32 i32 i32 i32) (result i32)))
  (import "wasi_snapshot_preview1" "fd_write"
    (func $wasi_fd_write (param i32 i32 i32 i32) (result i32)))
  (import "wasi_snapshot_preview1" "fd_close"
    (func $wasi_fd_close (param i32) (result i32)))
  (import "wasi_snapshot_preview1" "path_open"
    (func $wasi_path_open (param i32 i32 i32 i32 i32 i64 i64 i32 i32) (result i32)))
  (import "wasi_snapshot_preview1" "proc_exit"
    (func $wasi_proc_exit (param i32)))
  ;; Filesystem extensions per FX walkthrough — composed with by wasi_fs.wat.
  ;; Required preopen: caller invokes wasmtime with --dir=.  so fd 3 = "."
  (import "wasi_snapshot_preview1" "path_create_directory"
    (func $wasi_path_create_directory (param i32 i32 i32) (result i32)))
  (import "wasi_snapshot_preview1" "path_filestat_get"
    (func $wasi_path_filestat_get (param i32 i32 i32 i32 i32) (result i32)))
  (import "wasi_snapshot_preview1" "path_unlink_file"
    (func $wasi_path_unlink_file (param i32 i32 i32) (result i32)))
  (import "wasi_snapshot_preview1" "path_rename"
    (func $wasi_path_rename (param i32 i32 i32 i32 i32 i32) (result i32)))
  (import "wasi_snapshot_preview1" "fd_readdir"
    (func $wasi_fd_readdir (param i32 i32 i32 i64 i32) (result i32)))

  ;; ─── Memory & Globals (Layer 0) ───────────────────────────────────
  ;; 2 GiB total. Wheel size at Phase μ closure (962 KB source ×
  ;; ~1265 top-level fns × ~188 reason_make_* sites in walk_expr.wat
  ;; × ~50 expression positions per fn) demands substantial perm
  ;; headroom — running the seed against the full wheel surfaced
  ;; perm exhaustion at 384 MiB before lower started. The pre-Phase-μ 32 MiB layout was
  ;; sized when src/+lib/ totaled ~10 KLOC; the wheel grew through
  ;; the Phase μ commits (Mentl + cursor + multishot + threading +
  ;; verify-smt + tutorials). New partition gives perm 1.5 GiB
  ;; (1 MiB-1537 MiB), stage 384 MiB (1537 MiB-1921 MiB), fn 127 MiB
  ;; (1921 MiB-2048 MiB). Peer follow-ups address the bump shape
  ;; structurally:
  ;;   - Hβ.first-light.lexer-stage-alloc-retrofit (lift lex tokens
  ;;     to $stage_alloc — parse-consumed, discardable)
  ;;   - Hβ.first-light.infer-perm-pressure-substrate (route
  ;;     transient reasons through stage_alloc; promote-on-bind
  ;;     for graph-stored reasons; eliminate quadratic shape in
  ;;     unification reason chains)
  (memory (export "memory") 32768)  ;; 2 GiB

  (global $heap_base i32 (i32.const 4096))
  (global $heap_ptr (mut i32) (i32.const 1048576))

EOF

# ─── Layer 1-4: Chunked substrate ───────────────────────────────────
# Concatenate each chunk in CHUNKS[] order. Each chunk's content is
# function declarations + data segments (no module wrapper); they
# compose inside the (module ...) shell defined above.

for chunk in "${CHUNKS[@]}"; do
  if [[ ! -f "$chunk" ]]; then
    echo "ERROR: chunk not found: $chunk" >&2
    exit 1
  fi
  cat "$chunk" >> "$OUT"
  echo "" >> "$OUT"
done

# ─── Layer 6: Entry point (inline) ──────────────────────────────────
# Pipeline-wire status: Phase G — all four substrate gates CLEARED:
#   - Hβ.emit.module-wrap       ✓ (Phase F, commit 3cf4861 + fix 6ab695e)
#   - Hβ.lower.lowfn-substrate  ✓ (Phase C.1)
#   - Hβ.infer.bump-allocator-pressure-substrate ✓ (Phase A, commit d57e20c)
#   - Hβ.infer.parser-ast-shape-substrate        ✓ (Phase B)
#   - $graph_chase transitive TVar follow         ✓ (Phase G.1, commit aa6e7ab)
#
# Pipeline: stdin → lex → parse → infer → lower → emit → flush → exit
# Per ROADMAP §Phase G + Hβ-infer-substrate.md §10.3 clean handoff.

cat >> "$OUT" <<'EOF'

  ;; ─── Entry Point ──────────────────────────────────────────────────
  ;; Pipeline: stdin → lex → parse → infer → lower → emit → stdout
  ;; Per Phase G — Hβ.infer.pipeline-wire. The canonical form:
  ;;   $parse_program |> $inka_infer |> $inka_lower |> $inka_emit
  ;; with $stage_reset between transitions per Hβ-arena §7.4.
  (func $sys_main (export "_start")
    (local $input i32) (local $lex_result i32) (local $tokens i32)
    (local $count i32) (local $ast i32) (local $lowered i32)
    (local.set $input (call $read_all_stdin))
    (local.set $lex_result (call $lex (local.get $input)))
    (local.set $tokens (call $list_index (local.get $lex_result) (i32.const 0)))
    (local.set $count (call $list_index (local.get $lex_result) (i32.const 1)))
    (local.set $ast (call $parse_program (local.get $tokens)))
    ;; ── infer stage ──
    (call $stage_reset)
    (call $inka_infer (local.get $ast))
    ;; ── lower stage ──
    (call $stage_reset)
    (local.set $lowered (call $inka_lower (local.get $ast)))
    ;; ── emit stage ──
    (call $stage_reset)
    (call $emit_init)
    (call $inka_emit (local.get $lowered))
    (call $emit_flush)
    (call $wasi_proc_exit (i32.const 0)))
)
EOF

# Count lines
LINES=$(wc -l < "$OUT")
echo "Assembled: $LINES lines"

# ─── Compile ─────────────────────────────────────────────────────────
echo "Compiling WAT → WASM..."
wat2wasm "$OUT" -o "$WASM" --debug-names
echo "Built: $WASM ($(wc -c < "$WASM") bytes)"

# ─── Optional: run tests ─────────────────────────────────────────────
if [ "${1:-}" = "test" ]; then
  echo ""
  echo "═══ Running first-light tests ═══"
  bash bootstrap/first-light.sh
fi

echo "Done."
