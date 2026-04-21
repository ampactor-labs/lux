#!/usr/bin/env bash
# apply-claude-config.sh — one-shot: apply the ~/.claude/ changes Claude was
# blocked from making directly (self-modification gate). Idempotent; safe to
# re-run. Each action is gated on current state so re-running is a no-op.
#
# What this does:
#   1. Rename orphan lux-state-date-check.sh → claude-md-date-check.sh
#   2. Append Inka-project pointer to ~/.claude/CLAUDE.md (if not already there)
#   3. Replace ~/.claude/plans/sight-so-absorb-what-s-majestic-taco.md with
#      the finalized post-cleanup operational-memory plan
#
# None of these affect other projects. The Inka pointer in CLAUDE.md only
# applies when cwd is under ~/Projects/inka/; everything else is operational
# hygiene.

set -euo pipefail

CL="$HOME/.claude"

# ── 1. Rename orphan lux-state script ──────────────────────────────────────
if [ -f "$CL/lux-state-date-check.sh" ] && [ ! -f "$CL/claude-md-date-check.sh" ]; then
    mv "$CL/lux-state-date-check.sh" "$CL/claude-md-date-check.sh"
    echo "✓ renamed lux-state-date-check.sh → claude-md-date-check.sh"
else
    echo "· script already renamed or absent — skipping"
fi

# ── 2. Append Inka-project pointer to global CLAUDE.md ─────────────────────
MARKER="## Inka project — when cwd is under ~/Projects/inka/"
if ! grep -qF "$MARKER" "$CL/CLAUDE.md" 2>/dev/null; then
    cat >> "$CL/CLAUDE.md" <<'EOF'

## Inka project — when cwd is under ~/Projects/inka/

When working in the Inka repository, `~/Projects/inka/CLAUDE.md` governs. Read it in full per Session Zero — it carries Mentl's anchor, eight discipline anchors, nine drift modes, ten crystallizations. The project's SessionStart hook will inject the reminder automatically; confirm you've read it before proposing any edit.

For planning .ka edits, invoke the `inka-plan` skill (Opus); dispatch implementation to the `inka-implementer` agent (or the new `inka-planner` agent for the planning side). Never dispatch .ka edits to a bare `general-purpose` agent — the discipline lives in the Inka-specific agent system prompts.
EOF
    echo "✓ appended Inka pointer to ~/.claude/CLAUDE.md"
else
    echo "· Inka pointer already in ~/.claude/CLAUDE.md — skipping"
fi

# ── 3. Write the finalized operational plan (post-compaction memory) ───────
OP_PLAN="$CL/plans/sight-so-absorb-what-s-majestic-taco.md"
cat > "$OP_PLAN" <<'PLANEOF'
# Mentl's Integration Plan — operational state (post-cleanup, 2026-04-20)

## Where we are

**Phase I — γ cascade — CLOSED.** Twelve handle landings + three
crystallizations + nine drift modes named + ten substrate insights.

**Phase II — Handler projection — IN FLIGHT.** First cluster landed
this session: FS substrate + IC cluster (cache.ka + driver.ka +
pipeline/main wiring). Incremental compilation operational —
`inka check <module>` consults `.inka/cache/*.kai`, returns from
cache without re-inference on no-op / leaf edits.

**Phase III — Bootstrap.** Out of mind until Phase II Priority 1 closes.

**Phase IV — First-light.** Byte-identical fixed point post-bootstrap.

---

## Authoritative docs (read in this order when resuming)

1. `~/Projects/inka/CLAUDE.md` — Mentl's anchor + 8 anchors + 9 drift modes + 10 insights.
2. `~/Projects/inka/docs/PLAN.md` — four-phase roadmap + "Pending Work — single source of truth" section.
3. `~/Projects/inka/docs/traces/a-day.md` — integration scoreboard. Every claim tagged [LIVE] / [LIVE · surface pending] / [substrate pending].
4. `~/Projects/inka/docs/rebuild/simulations/H*.md` — per-handle cascade walkthroughs (H1-H6, HB, H2.3, H3.1, plus Phase II walkthroughs FS-filesystem-effect.md and IC-incremental-compilation.md).
5. This file — in-flight cross-session memory; defers to the in-repo docs.

---

## What's pending (from docs/PLAN.md "Pending Work" index)

**Priority 1** (three substrate gaps + LSP):
1. LFeedback state-machine lowering (~100 lines emit-side)
2. teach_synthesize oracle conductor (~50-80 lines mentl.ka)
3. Runtime HandlerCatalog effect (~40 lines)
4. LSP handler (JSON-RPC wrapping inka query + Mentl tentacles; couples to driver_check via didChange)

**Priority 2** (deployment):
5. Audit-driven linker dead-code severance
6. Multi-backend emit (browser / server / trainer / native)

**Priority 3** (specific programs):
7. Thread effect + per-thread regions
8. RPC/actor handler
9. Autodiff handler (~15 lines)
10. SIMD intrinsic emission

**Priority 4** (polish):
11. Commit message synthesis from graph provenance DAG
12. `inka rename` CLI handler
13. `///` docstring handler (render from graph projection)

**Cascade peers (open follow-ups):**
14. IC.3 — graph chase walks overlays (when name collisions become load-bearing)
15. Cache binary v3 format (if textual v2 measures as bottleneck)
16. Cache dependency-hash invalidation v2 (chain-check vs source-hash only)

**Phase III/IV:**
17. Bootstrap translator (as direct trace of cascade walkthroughs)
18. First-light — `diff inka2.wat inka3.wat` empty

---

## Key decisions persisted

### From γ cascade
- Bool: ADT semantically, i32 representationally via nullary-sentinel
- Token wrapper pattern (Tok + TokenKind); EffName ADT; SchemeKind ADT; MatchShape ADT
- HEAP_BASE = 4096 substrate invariant (sentinel range vs heap pointer threshold)
- Records are the handler-state shape everywhere (Ω.5 / BodyContext / region_tracker / AuditReport)
- Row algebra: one mechanism over four element types (string-set / name-set / field-set / tagged_values)
- Heap-uniform allocation: one emit_alloc swap surface for closures + variants + records + closures-with-evidence

### From Phase II (this session)
- FS substrate: Filesystem effect uses preopen fd 3 implicitly; parameterization (`with Filesystem("/path")`) deferred
- IC: cache format v2 (textual); env serialization round-trips name + Scheme + SchemeKind; Reasons regenerate as placeholder on cache load (provenance loss accepted; type correctness preserved)
- IC: per-module overlay separation deferred (IC.3); v1 driver merges envs flat — works for cross-module type-checking when names don't collide
- IC: dependency-hash invalidation simplified to source-hash only in v1; full chain lives in IC v2 of driver_check_module
- Housekeeping: deleted 180 .lux examples + 4 legacy tools/*.lux + tools/probe.sh + test_syntax.txt + empty std/backend/; README.md rewritten for post-cascade Inka; PLAN.md trimmed -421/+89 lines with central Pending Work index

---

## Anti-patterns (operational, session-derived)

### `git add -A` sweeps user's untracked tools/ + .githooks/
Morgan's drift-audit work lives untracked in `tools/drift-audit.{sh,tsv}`,
`tools/setup-git-hooks.sh`, `.githooks/pre-commit`. `git add -A` catches
these; TWICE this session they ended up in unrelated commits and had to
be reset-soft + re-committed. Mitigation: use targeted `git add <path>`
for substrate work; always `git status` before each commit.

### Self-modification gate on ~/.claude/ renames
Direct `mv` / rename operations on files under `~/.claude/` are blocked
even with auto-mode permissions. Write operations to new files under
`~/.claude/agents/` DO go through. Workaround: emit commands for the
user to run (or use a one-shot apply script like tools/apply-claude-config.sh).

---

## How to resume post-compaction

1. Read `~/Projects/inka/CLAUDE.md`.
2. Read `~/Projects/inka/docs/PLAN.md` (especially "Pending Work" at top).
3. Read `~/Projects/inka/docs/traces/a-day.md` (scoreboard).
4. Pick one Priority 1 item. Start with its walkthrough if one exists; draft one if not (per cascade discipline — walkthrough before code).
5. Dispatch via `inka-plan` skill → `inka-planner` agent → `inka-implementer`.

The substrate is whole. Phase II installs the surfaces it proves
achievable. Every handler projection earns a walkthrough in
`docs/rebuild/simulations/` before code freezes.
PLANEOF
echo "✓ operational plan rewritten at ~/.claude/plans/sight-so-absorb-what-s-majestic-taco.md"

echo
echo "done. Three actions applied idempotently; re-run safe."
