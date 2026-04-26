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
  # Future Wave 2.C+ runtime additions (env.wat / row.wat /
  # verify.wat / wasi_fs.wat) append here per INDEX.tsv tier order.

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

  # ── Layer 4: Emitter ──
  "bootstrap/src/emit_data.wat"
  "bootstrap/src/emit_infra.wat"
  "bootstrap/src/emit_expr.wat"
  "bootstrap/src/emit_compound.wat"
  "bootstrap/src/emit_stmt.wat"
  "bootstrap/src/emit_module.wat"
)

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

# ─── Layer 5: Entry point (inline) ──────────────────────────────────
# `_start` per WASI. Pipeline: stdin → lex → parse → emit → stdout.
# Closes the (module ...) wrapper.

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
