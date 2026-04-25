#!/usr/bin/env bash
# determinism-gate.sh — fails if compilation is non-deterministic.
#
# Per DET walkthrough §2.6 (commit 'docs/specs/simulations/DET-determinism-audit.md'):
# the compiler must produce byte-identical WAT on double-compile of the
# same input. Any difference is a first-light blocker (PLAN.md item 24).
#
# Usage:
#   tools/determinism-gate.sh                  # full src/ + lib/ tree
#   tools/determinism-gate.sh path/to/file.nx  # single file
#
# Exit codes:
#   0 — byte-identical (determinism holds)
#   1 — diff non-empty (non-determinism found; investigate the diff)
#   2 — invocation error (missing inka binary, unreadable input, etc.)
#
# Per drift mode 9 — non-determinism is NEVER acceptable as "for now."
# Every non-deterministic site is a first-light blocker; fix in-place.

set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"

# Resolve the inka binary. Pre-bootstrap (today): no inka binary yet
# exists, so this script's full functional form arrives with hand-WAT
# (item 27). Until then, the script's PRESENCE is substrate — it
# defines the contract; pre-commit hook installation is straight-line.
INKA_BIN="${INKA_BIN:-./bootstrap/inka.wasm}"

if [[ ! -f "$INKA_BIN" ]]; then
  echo "determinism-gate: inka binary not found at $INKA_BIN" >&2
  echo "  (pre-bootstrap: this gate is contract-only until item 27 lands hand-WAT)" >&2
  echo "  set INKA_BIN env var to override; otherwise this is a no-op exit-2" >&2
  exit 2
fi

# Determine inputs: arg-given file, or full tree (src/*.nx + lib/**/*.nx).
if [[ $# -ge 1 ]]; then
  INPUTS=( "$@" )
else
  # Sorted globs for determinism of the input list itself (the gate
  # itself must be deterministic in its input ordering).
  mapfile -t SRC_FILES < <(find src -name '*.nx' -type f | sort)
  mapfile -t LIB_FILES < <(find lib -name '*.nx' -type f | sort)
  INPUTS=( "${SRC_FILES[@]}" "${LIB_FILES[@]}" )
fi

if [[ ${#INPUTS[@]} -eq 0 ]]; then
  echo "determinism-gate: no input files" >&2
  exit 2
fi

# Concat in a stable order; pipe to inka twice; diff outputs.
FIRST="$(mktemp -t det_first.XXXXXX.wat)"
SECOND="$(mktemp -t det_second.XXXXXX.wat)"
trap 'rm -f "$FIRST" "$SECOND"' EXIT

# Compile run #1. If wasmtime fails, treat as pre-bootstrap (the
# binary exists but doesn't yet self-host); the gate's CONTRACT
# stands but the runtime check can't fire.
if ! cat "${INPUTS[@]}" | wasmtime run "$INKA_BIN" > "$FIRST" 2>/dev/null; then
  echo "determinism-gate: $INKA_BIN exists but doesn't compile Inka yet" >&2
  echo "  (pre-bootstrap: this gate is contract-only until item 27 lands hand-WAT)" >&2
  exit 2
fi

# Compile run #2 (separate process; cache state may differ).
cat "${INPUTS[@]}" | wasmtime run "$INKA_BIN" > "$SECOND"

if diff -q "$FIRST" "$SECOND" > /dev/null; then
  echo "✓ determinism: byte-identical on double-compile (${#INPUTS[@]} files)"
  exit 0
fi

# Non-empty diff. Surface the first ~50 lines for triage.
echo "✗ determinism FAILED: WAT output differs between runs" >&2
echo "  first  : $FIRST" >&2
echo "  second : $SECOND" >&2
echo "  diff (first 50 lines):" >&2
diff "$FIRST" "$SECOND" | head -50 >&2
echo "" >&2
echo "  Per DET walkthrough §3: every diffing region is a non-determinism source." >&2
echo "  Common causes (sorted by frequency):" >&2
echo "    - unsorted iteration over hash-keyed sets" >&2
echo "    - timestamp / wall-clock read in emit path" >&2
echo "    - random seed not derived deterministically from input" >&2
echo "    - memory-layout-dependent output (use structural IDs)" >&2
echo "    - env-variable read in emit path" >&2
exit 1
