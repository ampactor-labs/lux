#!/bin/bash
# first-light.sh — The soundness proof harness
#
# Phase 1 (current): Assemble + validate + lexer proof-of-life
# Phase 2 (future):  Self-compilation + byte-identical diff
set -euo pipefail

echo "=== Inka Bootstrap: first-light harness ==="

# Step 1: Assemble
echo "[1/5] Assembling bootstrap/inka.wat..."
wat2wasm bootstrap/inka.wat -o bootstrap/inka.wasm --debug-names 2>&1
echo "       ✓ Assembly succeeded"

# Step 2: Validate
echo "[2/5] Validating bootstrap/inka.wasm..."
wasm-validate bootstrap/inka.wasm
echo "       ✓ Validation passed"

# Step 3: Function inventory
FUNCS=$(wasm-objdump -x bootstrap/inka.wasm | grep -c 'func\[')
echo "[3/5] Function inventory: $FUNCS functions"

# Step 4: Lexer proof — lex a known input, verify token count
echo "[4/5] Lexer proof-of-life..."
TOKENS=$(echo 'fn f(x) = x + 1' | wasmtime run bootstrap/inka.wasm | wc -l)
if [ "$TOKENS" -ge 8 ]; then
  echo "       ✓ Lexer produced $TOKENS tokens from 'fn f(x) = x + 1'"
else
  echo "       ✗ Lexer produced only $TOKENS tokens"
  exit 1
fi

# Step 5: Full source lex — verify no crashes on all .nx files
echo "[5/5] Full source lex..."
TOTAL=0
for f in src/*.nx src/backends/*.nx; do
  COUNT=$(cat "$f" | wasmtime run bootstrap/inka.wasm | wc -l)
  TOTAL=$((TOTAL + COUNT))
  echo "       $(basename $f): $COUNT tokens"
done
echo "       ✓ Total: $TOTAL tokens across all source files"

echo ""
echo "=== Tier 1 Runtime + Lexer: LIVE ==="
echo "    WASM size: $(wc -c < bootstrap/inka.wasm) bytes"
echo "    WAT lines: $(wc -l < bootstrap/inka.wat)"
echo ""
echo "Next: hand-transcribe parser → infer → lower → emit"
