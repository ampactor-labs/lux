#!/bin/bash
# first-light.sh -- WABT-backed seed compiler proof harness.
#
# Current gate: the hand-WAT seed assembles and validates, then projects
# tiny Inka programs into WAT that also assemble, validate, inspect, and run.

set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"

WAT="bootstrap/inka.wat"
WASM="bootstrap/inka.wasm"
TMP_ROOT="${TMPDIR:-/tmp}"
WORKDIR="$(mktemp -d "$TMP_ROOT/inka-first-light.XXXXXX")"
trap 'rm -rf "$WORKDIR"' EXIT

require_tool() {
  if ! command -v "$1" >/dev/null 2>&1; then
    echo "missing required tool: $1" >&2
    exit 1
  fi
}

assert_contains() {
  local file="$1"
  local needle="$2"
  local label="$3"

  if grep -Fq -- "$needle" "$file"; then
    echo "       ok: $label"
    return
  fi

  echo "       missing: $label" >&2
  echo "       expected substring: $needle" >&2
  echo "       in: $file" >&2
  echo "------- tail($file) -------" >&2
  tail -40 "$file" >&2 || true
  echo "---------------------------" >&2
  exit 1
}

compile_sample() {
  local name="$1"
  local source="$2"
  local out_wat="$WORKDIR/$name.wat"
  local out_wasm="$WORKDIR/$name.wasm"
  local sections="$WORKDIR/$name.sections"
  local disasm="$WORKDIR/$name.disasm"

  printf "%s" "$source" | wasmtime run "$WASM" > "$out_wat"
  wat2wasm "$out_wat" -o "$out_wasm" --debug-names
  wasm-validate "$out_wasm"
  wasm-objdump -x "$out_wasm" > "$sections"
  wasm-objdump -d "$out_wasm" > "$disasm"
  wasmtime run "$out_wasm" >/dev/null

  printf "%s|%s|%s|%s\n" "$out_wat" "$out_wasm" "$sections" "$disasm"
}

echo "=== Inka Bootstrap: first-light WABT gate ==="

echo "[0/7] Checking toolchain..."
require_tool wat2wasm
require_tool wasm-validate
require_tool wasm-objdump
require_tool wasmtime
echo "       ok: WABT + wasmtime available"

echo "[1/7] Assembling seed WAT with wat2wasm..."
wat2wasm "$WAT" -o "$WASM" --debug-names
echo "       ok: built $WASM ($(wc -c < "$WASM") bytes)"

echo "[2/7] Validating seed WASM..."
wasm-validate "$WASM"
echo "       ok: wasm-validate accepted seed"

echo "[3/7] Inspecting seed sections with wasm-objdump..."
SEED_SECTIONS="$WORKDIR/seed.sections"
wasm-objdump -x "$WASM" > "$SEED_SECTIONS"
assert_contains "$SEED_SECTIONS" '<inka_emit>' "seed exports/keeps inka_emit"
assert_contains "$SEED_SECTIONS" '-> "_start"' "seed exports _start"
assert_contains "$SEED_SECTIONS" '<emit_start_section_static>' "static start projection present"

echo "[4/7] Projecting executable zero-arg main..."
IFS='|' read -r ZERO_WAT ZERO_WASM ZERO_SECTIONS ZERO_DISASM \
  < <(compile_sample "zero" $'fn main() = 42\n')
assert_contains "$ZERO_WAT" '(global.get $main)' "generated _start loads static main closure"
assert_contains "$ZERO_WAT" '(call_indirect (type $ft1))' "generated _start invokes zero-arg main through W7"
assert_contains "$ZERO_DISASM" 'call_indirect 0 <fns> (type 1 <ft1>)' "compiled _start keeps typed closure invocation"

echo "[5/7] Projecting one-arg main module..."
IFS='|' read -r ONE_WAT ONE_WASM ONE_SECTIONS ONE_DISASM \
  < <(compile_sample "one" $'fn main(x) = x\n')
assert_contains "$ONE_WAT" '(type $ft2 (func (param i32) (param i32) (result i32)))' "generated type ladder reaches arity 1 user fn"
assert_contains "$ONE_WAT" '(global $main i32 (i32.const 256))' "main has a static closure global"
assert_contains "$ONE_SECTIONS" 'Table[1]:' "generated module has function table"
assert_contains "$ONE_SECTIONS" '<main>' "generated module names main"

echo "[6/7] Projecting two-function call program..."
IFS='|' read -r TWO_WAT TWO_WASM TWO_SECTIONS TWO_DISASM \
  < <(compile_sample "two" $'fn id(x) = x\nfn main(y) = id(y)\n')
assert_contains "$TWO_WAT" '(global.get $id)' "top-level function reference lowers to global closure"
assert_contains "$TWO_WAT" '(call_indirect (type $ft2))' "call lowers through typed call_indirect"
assert_contains "$TWO_SECTIONS" 'table[0] type=funcref initial=2 <fns>' "function table contains both functions"
assert_contains "$TWO_SECTIONS" 'Data[2]:' "static closure records are materialized"
assert_contains "$TWO_DISASM" 'global.get 3 <id>' "compiled body loads id closure global"
assert_contains "$TWO_DISASM" 'call_indirect 0 <fns> (type 2 <ft2>)' "compiled body keeps typed indirect call"

echo "[7/7] Summary..."
echo "       seed: $(wc -l < "$WAT") WAT lines, $(wc -c < "$WASM") WASM bytes"
echo "       zero: $(wc -l < "$ZERO_WAT") generated WAT lines"
echo "       one:  $(wc -l < "$ONE_WAT") generated WAT lines"
echo "       two:  $(wc -l < "$TWO_WAT") generated WAT lines"
echo ""
echo "=== WABT gate: PASS ==="
