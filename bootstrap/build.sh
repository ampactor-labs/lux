#!/bin/bash
# ═══ Inka Bootstrap Build Script ═══════════════════════════════════
# Assembles the modular WAT source chunks into the monolith inka.wat
# and compiles to inka.wasm.
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
#   bootstrap/inka.wat           — assembled monolith (auditable as one file)
#   bootstrap/inka.wasm          — compiled binary
#
# Wave 2.A factoring notes (2026-04-25):
#   The earlier build.sh extracted "shell" + "entry" from a prior
#   inka.wat using marker-based python; Layer 1 lived inline in the
#   shell. Wave 2.A throws that pattern out: Layer 0 + Layer 5 are
#   defined inline here as heredocs; Layer 1 lives in modular runtime
#   chunks per Hβ §2.1; the build is pure concatenation in dependency
#   order. Per Onramp's stages-and-tools pattern + Hβ §2.1 modular
#   discipline.
#
# Usage:
#   ./bootstrap/build.sh         # build inka.wasm
#   ./bootstrap/build.sh test    # build + run first-light tests

set -euo pipefail
cd "$(dirname "$0")/.."

OUT="bootstrap/inka.wat"
WASM="bootstrap/inka.wasm"

# Chunk list lives in bootstrap/CHUNKS.sh so bootstrap/test.sh can source
# the same manifest. Per ROADMAP §5 + drift-mode-7 audit: ONE source of
# truth for chunk assembly order.
source "$(dirname "$0")/CHUNKS.sh"

echo "═══ Inka Bootstrap Build ═══"
echo "Assembling ${#CHUNKS[@]} source chunks..."

# ─── Layer 0: Module shell (inline) ─────────────────────────────────
# Module wrapper + WASI preview1 imports + linear memory + Layer 0
# globals ($heap_base / $heap_ptr per Hβ §1.1). All Layer 1 runtime
# substrate composes on these globals.

cat > "$OUT" <<'EOF'
;; inka.wat — The Reference Seed Compiler (Tier 1 Runtime)
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
  (memory (export "memory") 512)  ;; 32 MiB — room for heap + output buffer

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
# `_start` per WASI. Pipeline: stdin → lex → parse → emit → stdout.
# Closes the (module ...) wrapper.
#
# Pipeline-wire status: Hβ.infer.pipeline-wire follow-up depends on
# four substrate landings to ship cleanly:
#   - Hβ.emit.module-wrap                       — $inka_emit produces
#                                                 complete WAT modules
#   - Hβ.lower.lowfn-substrate                  — module-wrap's fn
#                                                 emission needs LowFn
#                                                 record
#   - Hβ.infer.bump-allocator-pressure-substrate — real parse_program
#                                                 AST consumes the
#                                                 bump heap during
#                                                 $inka_infer's walk
#                                                 on production inputs
#   - Hβ.infer.parser-ast-shape-substrate       — synthetic-AST
#                                                 harnesses pass but
#                                                 real parser-output
#                                                 AST traps in
#                                                 $infer_program (out-
#                                                 of-bounds memory
#                                                 fault at first-light
#                                                 — diagnosed 2026-04-29)
#
# All four are post-L1 substrate growth; first-light Tier 1 stays
# clean by leaving emit consuming raw AST without any infer/lower
# pre-pass.

cat >> "$OUT" <<'EOF'

  ;; ─── Entry Point ──────────────────────────────────────────────────
  ;; Pipeline: stdin → lex → parse → emit → stdout (WAT)
  (func $sys_main (export "_start")
    (local $input i32) (local $lex_result i32) (local $tokens i32)
    (local $count i32) (local $ast i32)
    (local.set $input (call $read_all_stdin))
    (local.set $lex_result (call $lex (local.get $input)))
    (local.set $tokens (call $list_index (local.get $lex_result) (i32.const 0)))
    (local.set $count (call $list_index (local.get $lex_result) (i32.const 1)))
    (local.set $ast (call $parse_program (local.get $tokens)))
    (call $emit_program (local.get $ast))
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
