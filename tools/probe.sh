#!/usr/bin/env bash
# probe.sh — fast compiler introspection without bootstrap rebuilds.
#
# Usage:
#   tools/probe.sh lower <file>       — show LowIR for all top-level fns
#   tools/probe.sh fn <file> <name>   — show WAT for a single function
#   tools/probe.sh diff <file>        — show diff between Rust-VM and bootstrap WAT
#                                       (requires /tmp/bs.cwasm to exist)
#
# The point: skip the 5-minute bootstrap rebuild loop. `lux lower` takes
# under a second, shows you the IR structure immediately, and is the
# right tool for 90% of "what does the compiler do with this source" questions.
#
# How this tool was born: finding the PLit(e) -> LPLit(LUnit) bug took hours
# of rebuild cycles. `lux lower` showed `match op { () => ... }` in one run.
# One run. That's the fast path.

set -euo pipefail

cmd="${1:-}"
shift || true

case "$cmd" in
  lower)
    file="${1:?usage: probe.sh lower <file>}"
    lux lower "$file" 2>&1 | sed -n '/^ *let /,$p'
    ;;
  fn)
    file="${1:?usage: probe.sh fn <file> <name>}"
    name="${2:?missing function name}"
    tmp=$(mktemp /tmp/probe_XXXXX.wat)
    lux wasm "$file" > "$tmp" 2>/dev/null
    awk -v name="\$$name" '
      $0 ~ "func "name"[^_]" { on=1; depth=0 }
      on { print; for (i=1;i<=length($0);i++) { c=substr($0,i,1); if(c=="(") depth++; else if(c==")") { depth--; if(depth==0 && NR>1) { exit } } } }
    ' "$tmp"
    rm -f "$tmp"
    ;;
  diff)
    file="${1:?usage: probe.sh diff <file>}"
    bs="${2:-/tmp/bs.cwasm}"
    if [[ ! -f "$bs" ]]; then
      echo "error: bootstrap binary not found at $bs" >&2
      echo "       rebuild with: lux wasm examples/wasm_bootstrap.lux > /tmp/bs.wat && wasmtime compile /tmp/bs.wat -o /tmp/bs.cwasm" >&2
      exit 1
    fi
    rust_wat=$(mktemp /tmp/probe_rust_XXXXX.wat)
    bs_wat=$(mktemp /tmp/probe_bs_XXXXX.wat)
    lux wasm "$file" > "$rust_wat" 2>/dev/null
    cat "$file" | wasmtime run --allow-precompiled --dir . -W max-wasm-stack=16777216 "$bs" > "$bs_wat" 2>/dev/null
    echo "# Rust VM → $rust_wat ($(wc -l <"$rust_wat") lines)"
    echo "# Bootstrap → $bs_wat ($(wc -l <"$bs_wat") lines)"
    echo "# Functions differing between Rust VM and bootstrap:"
    diff <(grep '^  (func \$' "$rust_wat" | sed 's/(param.*//') \
         <(grep '^  (func \$' "$bs_wat" | sed 's/(param.*//') | head -40
    echo ""
    echo "# Data section diff:"
    diff <(grep '^  (data ' "$rust_wat") <(grep '^  (data ' "$bs_wat") | head -20
    ;;
  *)
    sed -n '3,20p' "$0"
    exit 1
    ;;
esac
