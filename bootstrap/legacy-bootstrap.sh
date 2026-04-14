#!/bin/bash
set -e

echo "=== Lux Ouroboros Bootstrap ==="
echo "Started: $(date)"
echo ""

echo "Step 1: Building lux3.wasm via Rust VM..."
time cargo run --release -- wasm examples/wasm_bootstrap.lux > lux3.wasm
echo "lux3.wasm size: $(wc -c < lux3.wasm) bytes"
echo ""

echo "Step 2: Extracting clean WAT..."
sed -n '/^(module/,$p' lux3.wasm > lux3.wat
echo "lux3.wat lines: $(wc -l < lux3.wat)"
echo ""

echo "Step 3: Self-hosting — lux3 compiles itself (THE OUROBOROS)..."
time cat examples/wasm_bootstrap.lux | ~/.wasmtime/bin/wasmtime run --dir . -W max-wasm-stack=33554432 lux3.wat > lux4.wasm
echo "lux4.wasm size: $(wc -c < lux4.wasm) bytes"
echo ""

echo "Step 4: Comparing structural equivalence..."
sed -n '/^(module/,$p' lux4.wasm > lux4.wat
echo "lux3.wat lines: $(wc -l < lux3.wat)"
echo "lux4.wat lines: $(wc -l < lux4.wat)"
echo ""

echo "Completed: $(date)"
echo "=== BOOTSTRAP COMPLETE ==="
