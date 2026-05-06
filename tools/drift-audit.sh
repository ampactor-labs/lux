#!/usr/bin/env bash
# drift-audit.sh — fluency-trap sentinel for Mentl.
#
# Scans given files (or all staged .mn files if none given) against the
# patterns in tools/drift-patterns.tsv. Each pattern is labeled with the
# drift-mode number it flags (1–9 from CLAUDE.md). Zero matches = clean.
# Any match = named drift mode, cited at file:line.
#
# Stand-in for `mentl audit` until Mentl's own audit handler lands.
# Patterns evolve: append rows to tools/drift-patterns.tsv. No script
# changes needed. The script is substrate-agnostic; it will outlive the
# bootstrap translator and any particular backend.
#
# Dependencies: bash, GNU grep. No ripgrep, no cargo, no bootstrap.
#
# Usage:
#   tools/drift-audit.sh [file1 file2 ...]
#   tools/drift-audit.sh                 # audits all staged .mn files
#
# Exit: 0 clean, 1 drift detected, 2 misuse.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
PATTERNS="$SCRIPT_DIR/drift-patterns.tsv"

if [[ ! -f "$PATTERNS" ]]; then
    echo "drift-audit: patterns file not found at $PATTERNS" >&2
    exit 2
fi

# Collect files.
files=()
if [[ $# -gt 0 ]]; then
    for f in "$@"; do
        if [[ -f "$f" ]]; then
            files+=("$f")
        else
            echo "drift-audit: skipping missing file: $f" >&2
        fi
    done
else
    # Default: staged .mn files.
    if command -v git >/dev/null 2>&1 && git -C "$REPO_ROOT" rev-parse --is-inside-work-tree >/dev/null 2>&1; then
        while IFS= read -r f; do
            [[ -n "$f" && -f "$REPO_ROOT/$f" ]] && files+=("$REPO_ROOT/$f")
        done < <(git -C "$REPO_ROOT" diff --cached --name-only --diff-filter=ACMR 2>/dev/null | grep -E '\.mn$' || true)
    fi
fi

if [[ ${#files[@]} -eq 0 ]]; then
    echo "drift-audit: no files to scan"
    exit 0
fi

total_hits=0
declare -A mode_hits
declare -A mode_names

# Read patterns: columns (tab-separated) = mode_num, mode_name, regex, scope, notes
while IFS=$'\t' read -r mode_num mode_name regex scope notes; do
    [[ -z "${mode_num:-}" || "${mode_num:0:1}" == "#" ]] && continue
    [[ -z "${regex:-}" ]] && continue
    mode_names[$mode_num]="$mode_name"

    scan_files=()
    case "$scope" in
        ka)
            for f in "${files[@]}"; do [[ "$f" == *.mn ]] && scan_files+=("$f"); done
            ;;
        all|"")
            scan_files=("${files[@]}")
            ;;
        *)
            IFS=',' read -ra exts <<< "$scope"
            for f in "${files[@]}"; do
                for ext in "${exts[@]}"; do
                    [[ "$f" == *".${ext}" ]] && { scan_files+=("$f"); break; }
                done
            done
            ;;
    esac
    [[ ${#scan_files[@]} -eq 0 ]] && continue

    # GNU grep -E with line numbers. Suppressions: drop lines that contain
    # `drift-audit: ignore` on the same line.
    matches=$(grep -nE --color=never "$regex" "${scan_files[@]}" 2>/dev/null || true)
    [[ -z "$matches" ]] && continue

    filtered=$(printf '%s\n' "$matches" | grep -vE 'drift-audit:\s*ignore' || true)
    [[ -z "$filtered" ]] && continue

    count=$(printf '%s\n' "$filtered" | grep -c . || true)
    total_hits=$((total_hits + count))
    mode_hits[$mode_num]=$(( ${mode_hits[$mode_num]:-0} + count ))

    plural=""; [[ "$count" -ne 1 ]] && plural="s"
    echo "━━━ DRIFT MODE $mode_num — $mode_name ($count hit$plural)"
    [[ -n "${notes:-}" ]] && echo "    $notes"
    printf '%s\n' "$filtered" | sed 's/^/    /'
    echo
done < "$PATTERNS"

echo "════════════════════════════════════════════════════════════"
if [[ $total_hits -eq 0 ]]; then
    echo "drift-audit: CLEAN — ${#files[@]} file(s) scanned, 0 drift modes fired"
    exit 0
else
    echo "drift-audit: $total_hits match(es) across modes: ${!mode_hits[*]}"
    echo "Every flag is a drift mode firing. Do not rationalize — rewrite in residue form."
    echo "Suppress a single false positive with a trailing '# drift-audit: ignore' comment."
    exit 1
fi
