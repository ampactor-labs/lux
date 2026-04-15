#!/usr/bin/env bash
# baseline.sh — drift detection for lux3.wat (and lux4.wat) emissions.
#
# Saves an artifact's structural fingerprint and diffs against it on
# subsequent builds. Detects regressions WITHOUT requiring the artifact
# to be byte-perfect — we track aggregate signals that matter:
#   * function count
#   * line count
#   * UNRESOLVED count
#   * val_concat / val_eq fallback site counts
#   * effect annotation distribution (PURE vs effects: Foo)
#   * function names present (set diff)
#
# IMPORTANT: a baseline is NOT an assertion of correctness. It's a
# checkpoint that says "this is the state I knew about." Any deviation
# is *suspicious* and worth investigating, even if the saved state had
# known bugs. Promote a baseline to "golden" by manual flag once a full
# Arc 2 closure has been verified.
#
# Usage:
#   baseline.sh capture <wat-file> [out-name]
#       Save fingerprint of <wat-file> to bootstrap/baselines/<out-name>.fp
#   baseline.sh diff <wat-file> [baseline-name]
#       Compare <wat-file> against the saved fingerprint; report drift.
#       Exit 0 if within tolerance, 1 if any tracked metric regressed.
#   baseline.sh promote <name>
#       Mark a captured baseline as golden (immutable reference).

set -eu
PROJECT_ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
BASELINE_DIR="$PROJECT_ROOT/bootstrap/baselines"
mkdir -p "$BASELINE_DIR"

CMD="${1:-}"
WAT="${2:-}"
NAME="${3:-$(basename "${WAT:-unknown}" .wat)}"

case "$CMD" in
  capture)
    [ -f "$WAT" ] || { echo "no such file: $WAT" >&2; exit 2; }
    OUT="$BASELINE_DIR/$NAME.fp"
    {
      echo "# fingerprint: $WAT"
      echo "# captured: $(date '+%Y-%m-%d %H:%M:%S')"
      echo "lines=$(wc -l < "$WAT")"
      echo "size=$(wc -c < "$WAT")"
      echo "fns=$(grep -c '^  (func ' "$WAT" || echo 0)"
      echo "globals=$(grep -c '^  (global ' "$WAT" || echo 0)"
      echo "unresolved=$(grep -c 'UNRESOLVED:' "$WAT" || echo 0)"
      echo "val_concat=$(grep -c 'call \$val_concat' "$WAT" || echo 0)"
      echo "val_eq=$(grep -c 'call \$val_eq' "$WAT" || echo 0)"
      echo "list_concat=$(grep -c 'call \$list_concat' "$WAT" || echo 0)"
      echo "str_concat=$(grep -c 'call \$str_concat' "$WAT" || echo 0)"
      echo "fns_pure=$(grep -c ';; PURE' "$WAT" || echo 0)"
      echo "fns_effects=$(grep -c ';; effects:' "$WAT" || echo 0)"
      echo "regions=$(grep -c '__region_mark' "$WAT" || echo 0)"
      echo "tail_calls=$(grep -c 'return_call ' "$WAT" || echo 0)"
      # Function name set (sorted, one per line, prefixed `:fn:`)
      grep -oE '^  \(func \$[a-zA-Z_0-9]+' "$WAT" | sed 's|^  (func \$|:fn:|' | sort -u
    } > "$OUT"
    echo "captured fingerprint: $OUT"
    ;;

  diff)
    [ -f "$WAT" ] || { echo "no such file: $WAT" >&2; exit 2; }
    FP="$BASELINE_DIR/$NAME.fp"
    [ -f "$FP" ] || { echo "no baseline at $FP — run 'baseline.sh capture $WAT $NAME' first" >&2; exit 2; }

    echo "── drift check: $WAT vs baseline $NAME ──"

    NEW_FP=$(mktemp)
    "$0" capture "$WAT" "${NAME}.tmp" > /dev/null
    mv "$BASELINE_DIR/${NAME}.tmp.fp" "$NEW_FP"

    DRIFT=0
    for metric in lines fns globals unresolved val_concat val_eq list_concat str_concat fns_pure fns_effects regions tail_calls; do
      OLD=$(grep "^${metric}=" "$FP" | cut -d= -f2)
      NEW=$(grep "^${metric}=" "$NEW_FP" | cut -d= -f2)
      if [ "$OLD" = "$NEW" ]; then
        echo "  ok   $metric: $NEW"
      else
        SIGN=""
        if [ "${NEW:-0}" -gt "${OLD:-0}" ] 2>/dev/null; then SIGN="↑"; else SIGN="↓"; fi
        # Some metrics: growth is bad (unresolved, val_concat, val_eq)
        case "$metric" in
          unresolved|val_concat|val_eq)
            if [ "${NEW:-0}" -gt "${OLD:-0}" ] 2>/dev/null; then
              echo "  DRIFT $metric: $OLD → $NEW $SIGN (regression)" >&2
              DRIFT=1
            else
              echo "  info $metric: $OLD → $NEW $SIGN (improvement)"
            fi
            ;;
          *)
            echo "  info $metric: $OLD → $NEW $SIGN"
            ;;
        esac
      fi
    done

    # Function name set drift
    OLD_FNS=$(grep '^:fn:' "$FP" | sort -u)
    NEW_FNS=$(grep '^:fn:' "$NEW_FP" | sort -u)
    LOST=$(comm -23 <(echo "$OLD_FNS") <(echo "$NEW_FNS"))
    GAINED=$(comm -13 <(echo "$OLD_FNS") <(echo "$NEW_FNS"))
    if [ -z "$LOST" ] && [ -z "$GAINED" ]; then
      echo "  ok   function name set unchanged"
    else
      [ -n "$LOST" ] && { echo "  info functions LOST since baseline:" ; echo "$LOST" | sed 's|:fn:|       -|'; }
      [ -n "$GAINED" ] && { echo "  info functions GAINED since baseline:" ; echo "$GAINED" | sed 's|:fn:|       +|'; }
    fi

    rm -f "$NEW_FP"

    if [ "$DRIFT" -eq 0 ]; then
      echo ""
      echo "  baseline drift: clean"
      exit 0
    else
      echo ""
      echo "  baseline drift: REGRESSION DETECTED" >&2
      exit 1
    fi
    ;;

  promote)
    NAME="${2:-}"
    [ -n "$NAME" ] || { echo "usage: baseline.sh promote <name>" >&2; exit 2; }
    SRC="$BASELINE_DIR/$NAME.fp"
    DST="$BASELINE_DIR/$NAME.golden.fp"
    [ -f "$SRC" ] || { echo "no baseline: $SRC" >&2; exit 2; }
    cp "$SRC" "$DST"
    echo "promoted: $DST (golden — Arc-verified)"
    ;;

  *)
    cat >&2 <<EOF
usage:
  baseline.sh capture <wat-file> [name]
  baseline.sh diff <wat-file> [name]
  baseline.sh promote <name>
EOF
    exit 2
    ;;
esac
