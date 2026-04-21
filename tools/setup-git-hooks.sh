#!/usr/bin/env bash
# One-time setup: point git at the versioned .githooks directory.
# Idempotent — safe to re-run.
set -euo pipefail

REPO_ROOT="$(git -C "$(dirname "$0")/.." rev-parse --show-toplevel)"
cd "$REPO_ROOT"

git config core.hooksPath .githooks
chmod +x .githooks/*

echo "git hooks path → .githooks"
echo "enabled hooks:"
ls -1 .githooks/ | sed 's/^/  • /'
