#!/usr/bin/env bash
# check_wat.sh — creative verification layer for Lux WAT output.
#
# Uses wabt to catch classes of bugs that silently pass wasm-validate:
#   1. UNRESOLVED markers left by the emitter when a reference can't be
#      resolved (the emitter falls back to `i32.const 0`, which traps only
#      when the stored slot is later called via call_indirect).
#   2. New UNRESOLVED sites vs a known-good baseline (regression gate).
#   3. Null-function-pointer call patterns (i32.const 0 immediately before
#      call_indirect) — count relative to baseline.
#   4. wat2wasm + wasm-validate round-trip.
#
# Usage:
#   check_wat.sh <wat-file> [baseline-wat]
#
# Exit: 0 = all checks passed, 1 = at least one failed.

set -eu

TARGET="${1:-}"
BASELINE="${2:-}"

if [ -z "$TARGET" ] || [ ! -f "$TARGET" ]; then
  echo "usage: check_wat.sh <wat-file> [baseline-wat]" >&2
  exit 2
fi

FAIL=0
pass() { echo "  ok   $1"; }
fail() { echo "  FAIL $1" >&2; FAIL=1; }

BASENAME=$(basename "$TARGET")
echo "── check_wat: $BASENAME ──"

# ─── Check 1: UNRESOLVED markers ──────────────────────────────────────
# The emitter at std/backend/wasm_emit.lux writes `;; UNRESOLVED: NAME`
# followed by `i32.const 0` when it cannot resolve a reference. These
# sites compile and validate but trap at runtime if the slot is invoked.
#
# Policy:
#   * With a baseline: only NEW sites fail (allows a known-latent bug in
#     the baseline while still gating regressions).
#   * Without a baseline: any site fails.
UNR_COUNT=$(grep -c 'UNRESOLVED:' "$TARGET" 2>/dev/null || echo 0)

if [ -n "$BASELINE" ] && [ -f "$BASELINE" ]; then
  BASE_COUNT=$(grep -c 'UNRESOLVED:' "$BASELINE" 2>/dev/null || echo 0)

  TMP_BASE=$(mktemp)
  TMP_TARG=$(mktemp)

  awk '/^  \(func /{fn=$2} /UNRESOLVED:/{print fn "|" $0}' "$BASELINE" | sort -u > "$TMP_BASE"
  awk '/^  \(func /{fn=$2} /UNRESOLVED:/{print fn "|" $0}' "$TARGET"   | sort -u > "$TMP_TARG"

  NEW=$(comm -13 "$TMP_BASE" "$TMP_TARG")
  echo "  info UNRESOLVED markers: $UNR_COUNT (baseline $BASE_COUNT)"
  if [ -z "$NEW" ]; then
    pass "no new UNRESOLVED sites vs $(basename "$BASELINE")"
  else
    fail "NEW UNRESOLVED sites vs $(basename "$BASELINE"):"
    echo "$NEW" | sed 's/|/  /;s/^/       /' >&2
  fi

  rm -f "$TMP_BASE" "$TMP_TARG"
else
  if [ "$UNR_COUNT" -eq 0 ]; then
    pass "UNRESOLVED markers: 0"
  else
    fail "UNRESOLVED markers: $UNR_COUNT"
    awk '/^  \(func /{fn=$2} /UNRESOLVED:/{print "       " fn ": " $0}' "$TARGET" >&2
  fi
fi

# ─── Check 3: null function-pointer call sites ───────────────────────
# Pattern: `i32.const 0` within ≤4 lines before `call_indirect`. These
# are slots where UNRESOLVED references or zero-initialised globals flow
# into an indirect call. Benchmark count against baseline — an increase
# usually means the emitter lost track of a symbol.
count_null_calls() {
  awk '/^ *i32\.const 0/{prev=NR; next}
       /^ *call_indirect/ && prev > 0 && NR - prev <= 4 {c++}
       END {print c+0}' "$1"
}
NULL_T=$(count_null_calls "$TARGET")
if [ -n "$BASELINE" ] && [ -f "$BASELINE" ]; then
  NULL_B=$(count_null_calls "$BASELINE")
  if [ "$NULL_T" -le "$NULL_B" ]; then
    pass "null-fn-ptr call sites: $NULL_T (baseline $NULL_B)"
  else
    fail "null-fn-ptr call sites grew: $NULL_B -> $NULL_T"
  fi
else
  pass "null-fn-ptr call sites: $NULL_T (no baseline)"
fi

# ─── Check 5: polymorphic-fallback dispatch sites ─────────────────────
# val_concat / val_eq / val_lt / list_index-as-tuple-access are the
# RUNTIME polymorphic fallbacks that fire when type inference at lower
# time produces TVar instead of a concrete type. The fallback dispatches
# heuristically (e.g. val_concat checks first 4 bytes for ASCII to guess
# string-vs-list) and silently corrupts data when the heuristic is wrong.
#
# Every appearance of `call $val_concat`, `call $val_eq`, etc. in
# emitter output is a SIGNAL of inference loss — sometimes legitimate
# (truly polymorphic call sites), but a baseline diff catches regressions.
#
# When the count grows vs baseline, type inference has regressed in some
# function that previously typed cleanly.
count_poly_fallbacks() {
  local f="$1"
  local pat="$2"
  grep -c "call \$$pat" "$f" 2>/dev/null || echo 0
}

for fn in val_concat val_eq; do
  T=$(count_poly_fallbacks "$TARGET" "$fn")
  if [ -n "$BASELINE" ] && [ -f "$BASELINE" ]; then
    B=$(count_poly_fallbacks "$BASELINE" "$fn")
    if [ "$T" -le "$B" ]; then
      pass "$fn fallback sites: $T (baseline $B)"
    else
      fail "$fn fallback sites grew: $B -> $T (type inference regressed)"
      # Surface which functions have new fallback emissions.
      awk -v fn="$fn" '/^  \(func /{f=$2} index($0, "call $" fn) > 0 {print "       " f}' "$TARGET" | sort -u | head -10 >&2
    fi
  else
    if [ "$T" -eq 0 ]; then
      pass "$fn fallback sites: 0"
    else
      echo "  info $fn fallback sites: $T (no baseline)"
    fi
  fi
done

# ─── Check 4: wat2wasm + wasm-validate round-trip ─────────────────────
TMP_WASM=$(mktemp --suffix=.wasm)
trap 'rm -f "$TMP_WASM"' EXIT

if wat2wasm --debug-names --enable-tail-call "$TARGET" -o "$TMP_WASM" 2>/tmp/check_wat.err; then
  if wasm-validate --enable-tail-call "$TMP_WASM" 2>/tmp/check_wat.err; then
    pass "wat2wasm + wasm-validate clean"
  else
    fail "wasm-validate failed"
    sed 's/^/       /' /tmp/check_wat.err >&2 || true
  fi
else
  fail "wat2wasm failed"
  sed 's/^/       /' /tmp/check_wat.err >&2 || true
fi

echo ""
if [ "$FAIL" -eq 0 ]; then
  echo "  check_wat: $BASENAME clean"
  exit 0
else
  echo "  check_wat: $BASENAME FAILED" >&2
  exit 1
fi
