#!/bin/bash
# bootstrap/test.sh — Trace-harness runner for the bootstrap WAT layer
#
# Per ROADMAP §5: focused executable substrate trace-harnesses for
# scheme.wat + emit_diag.wat. Per Morgan's framing: harnesses ARE the
# prose-made-executable; this runner is the verifier.
#
# For each harness in bootstrap/test/INDEX.tsv (in declared order):
#   1. Assemble the harness into a standalone .wasm by composing
#      the same Layer 0 shell + CHUNKS[] (sourced from bootstrap/CHUNKS.sh)
#      with the harness body in place of the production _start.
#   2. Validate via wasm-validate.
#   3. Verify _start export via wasm-objdump -x.
#   4. Execute via wasmtime; capture stderr.
#   5. Grep stderr for ^FAIL; tally.
#
# Exit: 0 iff every harness PASSed; 1 if any FAILed.

set -euo pipefail
cd "$(dirname "$0")/.."

source bootstrap/CHUNKS.sh

INDEX=bootstrap/test/INDEX.tsv
ASSEMBLED_DIR=bootstrap/test/.assembled
mkdir -p "$ASSEMBLED_DIR"

echo "═══ Mentl Bootstrap: trace-harness runner ═══"

# ─── Layer 0 shell: copied verbatim from bootstrap/build.sh ──────────
# The same (module + WASI imports + memory + globals) heredoc that
# bootstrap/build.sh writes at the head of bootstrap/mentl.wat. Per
# ROADMAP §5: harness assembly mirrors production assembly so chunk
# semantics under test are identical to chunk semantics in mentl.wasm.
write_shell() {
  cat > "$1" <<'EOF'
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
  ;; 2 GiB — must match bootstrap/build.sh:110 verbatim. arena.wat's
  ;; partition constants ($stage_arena_ptr at 1537 MiB / $fn_arena_ptr
  ;; at 1921 MiB) live in the runtime chunk — harness inherits them
  ;; via the assembled chunk-list. If memory is smaller than the
  ;; partition, $stage_alloc / $fn_alloc range checks read into
  ;; out-of-bounds linear memory — exactly what runtime/arena_smoke.wat
  ;; surfaced when this declaration drifted from build.sh's bump.
  (memory (export "memory") 32768)  ;; 2 GiB

  (global $heap_base i32 (i32.const 4096))
  (global $heap_ptr (mut i32) (i32.const 1048576))

EOF
}

assemble_harness() {
  local harness_rel="$1"
  local harness_path="bootstrap/test/$harness_rel"
  local base="$(echo "$harness_rel" | tr '/' '_' | sed 's/\.wat$//')"
  local out_wat="$ASSEMBLED_DIR/$base.assembled.wat"
  local out_wasm="$ASSEMBLED_DIR/$base.wasm"

  if [[ ! -f "$harness_path" ]]; then
    echo "  ✗ harness file missing: $harness_path" >&2
    return 1
  fi

  write_shell "$out_wat"
  for chunk in "${CHUNKS[@]}"; do
    if [[ ! -f "$chunk" ]]; then
      echo "  ✗ chunk missing: $chunk" >&2
      return 1
    fi
    cat "$chunk" >> "$out_wat"
    echo "" >> "$out_wat"
  done
  cat "$harness_path" >> "$out_wat"
  echo "" >> "$out_wat"
  echo ")" >> "$out_wat"

  wat2wasm "$out_wat" -o "$out_wasm" --debug-names
  wasm-validate "$out_wasm"
  local objdump_output
  objdump_output=$(wasm-objdump -x "$out_wasm")
  if ! grep -q '"_start"' <<< "$objdump_output"; then
    echo "  ✗ harness $harness_rel does not export _start" >&2
    return 1
  fi

  echo "$out_wasm"
}

execute_harness() {
  local wasm="$1"
  local stderr_file="$2"
  wasmtime run "$wasm" 2> "$stderr_file" || true
}

TOTAL=0
PASSED=0
FAILED=0
FAIL_LIST=()

while IFS=$'\t' read -r harness chunk paragraph exercises status; do
  [[ -z "$harness" || "$harness" == \#* || "$harness" == "harness" ]] && continue

  TOTAL=$((TOTAL + 1))
  echo "[$TOTAL] $harness"
  echo "    paragraph: $paragraph"

  wasm_path=$(assemble_harness "$harness")

  stderr_file="$ASSEMBLED_DIR/$(echo "$harness" | tr '/' '_' | sed 's/\.wat$//').stderr"
  execute_harness "$wasm_path" "$stderr_file"

  if grep -q "^FAIL" "$stderr_file"; then
    FAILED=$((FAILED + 1))
    FAIL_LIST+=("$harness")
    echo "    ✗ FAIL"
    grep "^FAIL" "$stderr_file" | sed 's/^/      /'
  elif grep -q "^PASS" "$stderr_file"; then
    PASSED=$((PASSED + 1))
    echo "    ✓ PASS"
  else
    FAILED=$((FAILED + 1))
    FAIL_LIST+=("$harness (no verdict)")
    echo "    ✗ FAIL (no verdict on stderr)"
    cat "$stderr_file" | sed 's/^/      /'
  fi
done < "$INDEX"

echo ""
echo "═══ Summary ═══"
echo "    Total:  $TOTAL"
echo "    Passed: $PASSED"
echo "    Failed: $FAILED"

if [[ $FAILED -gt 0 ]]; then
  echo ""
  echo "Failed harnesses:"
  for h in "${FAIL_LIST[@]}"; do
    echo "  - $h"
  done
  exit 1
fi

echo ""
echo "All trace-harnesses PASSed."
exit 0
