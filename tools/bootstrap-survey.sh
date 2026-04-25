#!/usr/bin/env bash
# bootstrap-survey.sh — per-file failure-shape categorization for BT.A.0.
#
# Per docs/specs/simulations/BT-bootstrap-triage.md §11.4 BT.A.0 +
# Hβ-bootstrap.md §13 step 3 (commit 95fdc3c).
#
# Runs the seed compiler (bootstrap/inka.wasm) against each src/*.nx
# + lib/**/*.nx file. Categorizes each file's failure shape:
#
#   VALIDATES        — output passes wat2wasm + wasm-validate cleanly;
#                       module compiles standalone (1/15 per BT §1; verify.nx)
#   PARSE-INCOMPLETE — output references undefined locals from import-as-
#                       identifier handling (per BT §11.1 finding for graph.nx)
#   WAT-MALFORMED    — wat2wasm rejects on syntactic grounds beyond imports
#   CROSS-MODULE-REF — wat2wasm accepts; wasm-validate rejects on missing
#                       function/symbol references to sibling modules (BT §1
#                       stated failure shape; verify when reached)
#   STDIN-EMPTY-OUT  — seed produced no output (stdin issue or seed crash)
#   SEED-CRASH       — wasmtime exited non-zero (seed itself trapped)
#
# Output: TSV summary on stdout — file<TAB>line_count<TAB>category<TAB>note
#
# Per BT §11.6: this script's output drives BT.A.1 substrate-extension
# work — failure category by failure category.

set -uo pipefail
cd "$(dirname "$0")/.."

SEED="bootstrap/inka.wasm"
if [[ ! -f "$SEED" ]]; then
  echo "ERROR: seed compiler not found at $SEED" >&2
  echo "  run: bash bootstrap/build.sh" >&2
  exit 2
fi

TMPDIR="$(mktemp -d -t bootstrap-survey.XXXXXX)"
trap "rm -rf $TMPDIR" EXIT

categorize_file() {
  local nx_file="$1"
  local out_wat="$TMPDIR/$(basename "$nx_file" .nx).wat"
  local out_wasm="$TMPDIR/$(basename "$nx_file" .nx).wasm"
  local stderr_log="$TMPDIR/$(basename "$nx_file" .nx).stderr"

  # Run seed; capture stdout to .wat + stderr separately
  if ! cat "$nx_file" | wasmtime run "$SEED" > "$out_wat" 2> "$stderr_log"; then
    echo "SEED-CRASH:exited non-zero ($(head -1 "$stderr_log" | head -c 80))"
    return
  fi

  if [[ ! -s "$out_wat" ]]; then
    echo "STDIN-EMPTY-OUT:no output produced"
    return
  fi

  local line_count
  line_count="$(wc -l < "$out_wat")"

  # Try to assemble; categorize per failure shape
  local wat2wasm_log="$TMPDIR/$(basename "$nx_file" .nx).wat2wasm.log"
  if wat2wasm "$out_wat" -o "$out_wasm" --debug-names --enable-tail-call \
       2> "$wat2wasm_log"; then
    # wat2wasm succeeded; try wasm-validate
    local validate_log="$TMPDIR/$(basename "$nx_file" .nx).validate.log"
    if wasm-validate "$out_wasm" 2> "$validate_log"; then
      echo "VALIDATES:$line_count lines"
    else
      local first_err
      first_err="$(head -1 "$validate_log" | head -c 100)"
      echo "CROSS-MODULE-REF:$line_count lines; $first_err"
    fi
  else
    # wat2wasm failed; categorize the error
    local first_err
    first_err="$(head -1 "$wat2wasm_log" | head -c 100)"
    if grep -qE 'undefined local variable|undefined variable' "$wat2wasm_log"; then
      echo "PARSE-INCOMPLETE:$line_count lines; $first_err"
    else
      echo "WAT-MALFORMED:$line_count lines; $first_err"
    fi
  fi
}

# Find all .nx files in src/ + lib/ (sorted for determinism)
nx_files=()
while IFS= read -r f; do
  nx_files+=("$f")
done < <(find src lib -name '*.nx' -type f 2>/dev/null | sort)

if [[ ${#nx_files[@]} -eq 0 ]]; then
  echo "ERROR: no .nx files found under src/ or lib/" >&2
  exit 2
fi

# Header
printf 'file\tlines\tcategory\tnote\n'

# Categorize each
declare -A category_counts
for nx_file in "${nx_files[@]}"; do
  result="$(categorize_file "$nx_file")"
  category="${result%%:*}"
  note="${result#*:}"

  # Source line count (the input)
  src_lines="$(wc -l < "$nx_file")"

  printf '%s\t%s\t%s\t%s\n' "$nx_file" "$src_lines" "$category" "$note"

  category_counts[$category]=$((${category_counts[$category]:-0} + 1))
done

# Summary on stderr (so stdout stays TSV-clean)
{
  echo ""
  echo "═══ Summary ══════════════════════════════════════════════════"
  for category in VALIDATES PARSE-INCOMPLETE WAT-MALFORMED CROSS-MODULE-REF STDIN-EMPTY-OUT SEED-CRASH; do
    count="${category_counts[$category]:-0}"
    if [[ $count -gt 0 ]]; then
      printf '%-20s %d files\n' "$category" "$count"
    fi
  done
  echo ""
  echo "Per BT §11.4: each non-VALIDATES category drives a BT.A.1"
  echo "substrate-extension sub-handle. PARSE-INCOMPLETE files block on"
  echo "Hβ §1 parser conventions; CROSS-MODULE-REF files block on"
  echo "BT.A.2 link.py; WAT-MALFORMED + SEED-CRASH need per-file"
  echo "investigation."
} >&2
