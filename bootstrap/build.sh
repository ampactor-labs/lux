#!/bin/bash
# ═══ Inka Bootstrap Build Script ═══════════════════════════════════
# Assembles the modular WAT source files into the monolith inka.wat
# and compiles to inka.wasm.
#
# Source of truth: bootstrap/src/*.wat (modular chunks)
# Build artifact:  bootstrap/inka.wat (assembled monolith)
#                  bootstrap/inka.wasm (compiled binary)
#
# The WAT module is assembled by concatenation in dependency order.
# Each src/*.wat file contains ONLY the function/data bodies (no
# module wrapper). The wrapper is provided by this script.
#
# Usage:
#   ./bootstrap/build.sh         # build inka.wasm
#   ./bootstrap/build.sh test    # build + run first-light tests

set -euo pipefail
cd "$(dirname "$0")/.."

OUT="bootstrap/inka.wat"
WASM="bootstrap/inka.wasm"

# ─── Module structure ────────────────────────────────────────────────
# The assembly order matters: dependencies must come before dependents.
#
# Layer 0: Module shell (imports, memory, globals)
# Layer 1: Runtime primitives (alloc, strings, lists)
# Layer 2: Lexer (tokenization)
# Layer 3: Parser (AST construction)
# Layer 4: Emitter (WAT code generation)
# Layer 5: Entry point (_start)

CHUNKS=(
  # ── Layer 0: Module shell ──
  # (generated inline below)

  # ── Layer 1: Runtime ──
  # (already in the module shell — alloc, str_*, list_*, etc.)

  # ── Layer 2: Lexer ──
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

# ─── Extract module shell ────────────────────────────────────────────
# The module shell is everything in the current inka.wat BEFORE the
# first chunk marker. This includes: (module, imports, memory, globals,
# runtime functions (alloc, str_*, list_*, etc.), and helper utilities.
#
# We find this boundary by looking for the lexer's start comment.

MARKER=";; ─── TokenKind Sentinel IDs"

# Read current monolith and extract the shell
python3 -c "
import sys
with open('$OUT') as f:
    content = f.read()
marker = '$MARKER'
idx = content.find(marker)
if idx < 0:
    print('ERROR: Could not find chunk marker in monolith', file=sys.stderr)
    sys.exit(1)

# Shell = everything before the first chunk
shell = content[:idx].rstrip()

# Entry point = everything after the last chunk ends
# Find the entry point marker
entry_marker = '  ;; ─── Entry Point'
entry_idx = content.find(entry_marker)
if entry_idx < 0:
    print('ERROR: Could not find entry point marker', file=sys.stderr)
    sys.exit(1)
entry = content[entry_idx:]

# Rebuild: shell + chunks + entry
with open('$OUT', 'w') as f:
    f.write(shell)
    f.write('\n\n')
    for chunk_path in sys.argv[1:]:
        with open(chunk_path) as cf:
            f.write(cf.read())
        f.write('\n\n')
    f.write(entry)

# Count lines
with open('$OUT') as f:
    lines = sum(1 for _ in f)
print(f'Assembled: {lines} lines')
" "${CHUNKS[@]}"

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
