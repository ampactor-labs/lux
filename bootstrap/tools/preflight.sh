#!/usr/bin/env bash
# preflight.sh — static checks that run in SECONDS, before any compilation.
#
# Catches the bug classes that have cost us 25-min stage2 cycles to surface:
#   1. Duplicate top-level fn names across std/ (the emitter picks one
#      silently; the other's callers get its semantics — see the
#      list_contains / head / tail incident, 2026-04-15).
#   2. Flat-array memory access patterns in fns that operate on lists
#      (load_i32(list + 4 + i * 4) is correct for Rust VM Vec but
#      WRONG for WASM Snoc trees).
#   3. Lux-level lint: known-bad patterns we've burned bootstraps on.
#
# Usage:
#   preflight.sh [--strict]
#     --strict: fail on hygiene-only issues (string-op dups etc.)
#
# Exit: 0 = clean, 1 = at least one HARD failure detected.

set -eu
PROJECT_ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
STRICT="${1:-}"

FAIL=0
WARN=0
pass() { echo "  ok   $1"; }
fail() { echo "  FAIL $1" >&2; FAIL=1; }
warn() { echo "  warn $1" >&2; WARN=1; }

echo "── preflight: static checks before compile ──"

# ─── Check 1: duplicate top-level fn names ────────────────────────────
# The Lux emitter keys functions by unqualified name. Duplicates mean
# only one definition reaches the WAT, and which one wins depends on
# AST processing order. This is the specific pattern that hid the
# memory.lux flat-array list_contains / head / tail behind the
# Snoc-safe versions in eff.lux / prelude.lux for who knows how long.
echo ""
echo "── duplicate top-level fn names ──"

DUPS=$(cd "$PROJECT_ROOT" && \
  for f in $(find std -name '*.lux' 2>/dev/null | grep -v 'std/vm.lux'); do
    grep -nE "^fn [a-z_]+\b" "$f" | sed "s|:|	|" | awk -F'\t' -v file="$f" '{
      name = $2; sub(/^fn /, "", name); sub(/[ (].*/, "", name);
      print name "\t" file ":" $1
    }'
  done | sort | awk -F'\t' '
    {
      if (last_name == $1) { rows[++count] = $2 }
      else {
        if (count > 1) { print last_name; for (i=1;i<=count;i++) print "    " rows[i] }
        last_name = $1; count = 1; delete rows; rows[1] = $2
      }
    }
    END { if (count > 1) { print last_name; for (i=1;i<=count;i++) print "    " rows[i] } }'
)

if [ -z "$DUPS" ]; then
  pass "no duplicate top-level fn names"
else
  fail "duplicate top-level fn names — emitter will silently pick one:"
  echo "$DUPS" | sed 's/^/       /' >&2
fi

# ─── Check 2: flat-array memory access in fns named like list ops ─────
# Pattern: a function whose name suggests list/collection operation
# (head, tail, list_*, contains) but whose body uses literal byte-offset
# arithmetic (load_i32(x + 4 + i * 4)) — indicating it expects flat arrays
# and will silently mis-traverse Snoc trees.
#
# This is heuristic; it's tuned to the actual bugs we shipped.
echo ""
echo "── flat-array list ops (Snoc-tree breakers) ──"

FLAT_LIST_OPS=$(cd "$PROJECT_ROOT" && \
  awk '
    /^fn (head|tail|last|list_[a-z_]+|contains|ends_with|starts_with)\b/ {
      fn=$0; sub(/^fn /, "", fn); sub(/[ (].*/, "", fn)
      in_fn = 1; depth = 0; flat_hit = 0; start_nr = NR; next
    }
    in_fn {
      # Track brace depth (very simple, fine for this audit)
      for (i=1; i<=length($0); i++) {
        c = substr($0, i, 1)
        if (c == "{") depth++
        if (c == "}") { depth--; if (depth == 0 && NR > start_nr + 1) { in_fn = 0; if (flat_hit) print FILENAME ":" start_nr ": " fn; next } }
      }
      # Detect the flat-array index pattern
      if ($0 ~ /load_i32\(.*\+ *4 *\+ *.*\* *4\)/) flat_hit = 1
      # Or `list + 4 + i * 4` style
      if ($0 ~ /\+ *4 *\+ *[a-z_]+ *\* *4/) flat_hit = 1
    }
  ' std/runtime/*.lux 2>/dev/null
)

if [ -z "$FLAT_LIST_OPS" ]; then
  pass "no flat-array patterns in collection-op fns"
else
  fail "flat-array memory access in fns that look like collection ops:"
  echo "$FLAT_LIST_OPS" | sed 's/^/       /' >&2
fi

# ─── Check 3: emit_eff_annotation / fn_eff regression markers ────────
# If lower_lambda_named has reverted to "EfPure as fallback" without
# detecting it, log a note. This is a softer check.
echo ""
echo "── lower_lambda_named fallback safety ──"

if grep -qE "_ => TFun\(\[\], lexpr_ty\(.*\), EfPure\)" "$PROJECT_ROOT/std/compiler/lower_closure.lux" 2>/dev/null; then
  if [ "$STRICT" = "--strict" ]; then
    fail "lower_lambda_named has TFun(_, _, EfPure) fallback for non-TFun env_lookup — silently drops effects when checker types are TVar"
  else
    warn "lower_lambda_named has TFun(_, _, EfPure) fallback (silent effect drop on TVar lookups)"
  fi
fi

# ─── Check 4: known-bad polymorphic dispatch fallbacks not gated ────
# If lower.lux's BinOp Concat still has `_ => ("val_concat", TUnit)` it
# means we still accept TVar at lower time. Same for Eq/Neq → val_eq.
echo ""
echo "── polymorphic fallback gates ──"

CONCAT_FALLBACK=$(grep -n '_ => ("val_concat", TUnit)' "$PROJECT_ROOT/std/compiler/lower.lux" 2>/dev/null || true)
EQ_FALLBACK=$(grep -n '"val_eq")' "$PROJECT_ROOT/std/compiler/lower.lux" 2>/dev/null || true)

if [ -n "$CONCAT_FALLBACK" ] && [ "$STRICT" = "--strict" ]; then
  fail "lower.lux still accepts TVar for Concat (val_concat fallback): $CONCAT_FALLBACK"
elif [ -n "$CONCAT_FALLBACK" ]; then
  warn "lower.lux falls back to val_concat for TVar Concat — every regression in inference grows val_concat sites in lux4.wat"
fi

# ─── Check 5: duplicate effect-op names across effect declarations ────
# `effect Foo { bar(...) -> X }` and `effect Bar { bar(...) -> Y }` make
# `bar` a single global op. The emitter sets `__ev_op_bar` once — second
# handler install overwrites first. Detect by `name(...) -> Type` lines.
echo ""
echo "── duplicate effect op names ──"

EFFECT_OPS=$(cd "$PROJECT_ROOT" && \
  for f in $(find std -name '*.lux' 2>/dev/null | grep -v 'std/vm.lux'); do
    awk -v file="$f" '
      /^effect [A-Z][a-zA-Z_]+ \{/ { in_eff = 1; eff_name = $2; next }
      in_eff && /^}/ { in_eff = 0; next }
      in_eff && /[ \t]*[a-z_][a-z_0-9]*\(.*\)[ \t]*->/ {
        line = $0; sub(/^[ \t]*/, "", line); op = line; sub(/\(.*/, "", op)
        print op "\t" eff_name "\t" file ":" NR
      }
    ' "$f"
  done | sort -k1,1 -t$'\t' | \
  awk -F'\t' '
    {
      if (last == $1) {
        rows[++n] = $2 " (" $3 ")"
      } else {
        if (n > 1) {
          print last
          for (i=1;i<=n;i++) print "    " rows[i]
        }
        last = $1; n = 1; delete rows; rows[1] = $2 " (" $3 ")"
      }
    }
    END { if (n > 1) { print last; for (i=1;i<=n;i++) print "    " rows[i] } }')

if [ -z "$EFFECT_OPS" ]; then
  pass "no duplicate effect op names"
else
  fail "duplicate effect op names — handler installation collides on __ev_op_NAME:"
  echo "$EFFECT_OPS" | sed 's/^/       /' >&2
fi

# ─── Check 6: signature mismatch between same-name fns ───────────────
# After dedup we should have no same-name fns at all, but defensive check:
# if a fn is defined twice (somehow) and the `with` clauses or arity
# differ, that's worse than identical dups — type unification at callers
# becomes nondeterministic.
echo ""
echo "── signature mismatches between same-name fns ──"

SIG_MISMATCH=$(cd "$PROJECT_ROOT" && \
  for f in $(find std -name '*.lux' 2>/dev/null | grep -v 'std/vm.lux'); do
    awk -v file="$f" '/^fn [a-z_][a-z_0-9]*\(/ {
      name=$0; sub(/^fn /, "", name); sub(/\(.*/, "", name)
      sig=$0
      # normalize: strip the body opener
      sub(/ *= *\{?[ \t]*$/, "", sig); sub(/ *= *.*$/, "", sig)
      print name "\t" sig "\t" file ":" NR
    }' "$f"
  done | sort -k1,1 -t$'\t' | \
  awk -F'\t' '
    {
      if (last == $1) { sigs[++n] = $2 "  @  " $3 }
      else {
        if (n > 1) {
          # Are all sigs identical? If yes, dup is hygiene; if no, mismatch
          uniq=1; first=sigs[1]; for (i=2;i<=n;i++) if (sigs[i] != first) uniq=0
          if (!uniq) { print last; for (i=1;i<=n;i++) print "    " sigs[i] }
        }
        last=$1; n=1; delete sigs; sigs[1]=$2 "  @  " $3
      }
    }
    END {
      if (n > 1) {
        uniq=1; first=sigs[1]; for (i=2;i<=n;i++) if (sigs[i] != first) uniq=0
        if (!uniq) { print last; for (i=1;i<=n;i++) print "    " sigs[i] }
      }
    }')

if [ -z "$SIG_MISMATCH" ]; then
  pass "no signature mismatches"
else
  fail "fns with same name but DIFFERENT signatures — caller types collide:"
  echo "$SIG_MISMATCH" | sed 's/^/       /' >&2
fi

# ─── Check 7: undeclared effect ops ──────────────────────────────────
# A "with X" annotation that names an effect declared nowhere. These
# silently lower to no-ops, or worse, get mistreated by inference.
echo ""
echo "── undeclared effects in with-clauses ──"

DECLARED_EFFECTS=$(cd "$PROJECT_ROOT" && \
  grep -hE '^effect [A-Z][a-zA-Z_]+ \{' std/**/*.lux std/*.lux 2>/dev/null | \
  awk '{print $2}' | sort -u)

# Restrict to lines that look like fn signatures (skip comments/prose).
USED_EFFECTS=$(cd "$PROJECT_ROOT" && \
  grep -rhE '^[[:space:]]*fn [a-z_][a-z_0-9]*\(.*\)[[:space:]]+(->[^=]+)?with [A-Z]' std/ 2>/dev/null | \
  grep -oE 'with [A-Z][a-zA-Z_]+([ \t]*[,+][ \t]*[A-Z][a-zA-Z_]+)*' | \
  sed -E 's/^with //; s/[,+]/ /g' | tr -s ' \t' '\n' | grep -E '^[A-Z]' | sort -u)

# Built-ins that don't need explicit declaration (via runtime / Rust VM)
BUILTINS="Pure
Memory
Alloc
IO
WASI
Diagnostic"

ALLOWED=$(printf '%s\n%s\n' "$DECLARED_EFFECTS" "$BUILTINS" | sort -u)
UNDECLARED=$(comm -23 <(echo "$USED_EFFECTS" | sort -u) <(echo "$ALLOWED" | sort -u))

if [ -z "$UNDECLARED" ]; then
  pass "all with-clause effects are declared"
else
  if [ "$STRICT" = "--strict" ]; then
    fail "effects used in with-clauses but not declared anywhere:"
  else
    warn "effects used in with-clauses but not declared anywhere (may be false positives):"
  fi
  echo "$UNDECLARED" | sed 's/^/       /' >&2
fi

# ─── Check 8: println / print as VALUE (not call) ────────────────────
# `println(x)` and `print(x)` are call-site specialized in lower.lux.
# Used as VALUES (e.g., `let f = println` or `map(println, xs)`),
# they slip through specialization and end up in capture lists,
# failing the emitter's resolution and triggering an UNRESOLVED.
echo ""
echo "── println / print used as a value ──"

PRINTLN_VAL=$(cd "$PROJECT_ROOT" && \
  grep -rnE '(\=|,|\(|\|\>|<\|)[ \t]*(println|print)\b[ \t]*[^(]' std/ examples/ 2>/dev/null | \
  grep -vE '^[^:]*:[0-9]+:\s*//' | \
  grep -vE 'println\b\s*\(|print\b\s*\(' || true)

if [ -z "$PRINTLN_VAL" ]; then
  pass "println / print only used as direct calls (call-site specialization is safe)"
else
  fail "println / print appears as a value (not a call) — will be captured + UNRESOLVED:"
  echo "$PRINTLN_VAL" | head -10 | sed 's/^/       /' >&2
fi

# ─── Summary ──────────────────────────────────────────────────────────
echo ""
if [ "$FAIL" -eq 0 ]; then
  if [ "$WARN" -gt 0 ]; then
    echo "  preflight: clean (with $WARN warnings; pass --strict to enforce)"
  else
    echo "  preflight: clean"
  fi
  exit 0
else
  echo "  preflight: $FAIL HARD FAILURES — fix before stage0" >&2
  exit 1
fi
