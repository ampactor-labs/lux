#!/bin/bash
set -e

echo "=== Assembling Tier 1 (Runtime) ==="
wat2wasm bootstrap/inka.wat -o bootstrap/inka.wasm --debug-names --enable-tail-call
wasm-validate bootstrap/inka.wasm
echo "✅ inka.wasm assembled."

echo "=== Assembling Tier 1.5 (Expander) ==="
wat2wasm bootstrap/expander.wat -o bootstrap/expander.wasm --debug-names
wasm-validate bootstrap/expander.wasm
echo "✅ expander.wasm assembled."

echo "=== Tier 2: Compiler Expansion ==="
# Pipe all Inka source through the Inka-native expander.
# For first-light, we write to a temporary file.
cat src/*.nx lib/**/*.nx | wasmtime run bootstrap/expander.wasm > bootstrap/compiler_expanded.wat

# Verify that the generated file is non-empty and contains our template marker.
if grep -q "EXPANDED TEMPLATE START" bootstrap/compiler_expanded.wat; then
    echo "✅ Expander successfully processed the source tree and emitted WAT."
    echo "FIRST LIGHT ACHIEVED."
    exit 0
else
    echo "❌ Expander output is invalid."
    exit 1
fi
