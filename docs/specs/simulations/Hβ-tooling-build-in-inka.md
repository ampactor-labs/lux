# Hβ-tooling-build-in-mentl.md — build.sh in Mentl

**Status:** Named cascade. Per PLAN-to-first-light.md §3 post-Tier-3.
Plan-doc.

## Context

Today: `bootstrap/build.sh` is a bash script that concatenates WAT
chunks per CHUNKS.sh, runs wat2wasm, and produces `mentl.wasm`. It's
~3K lines of shell. Mentl is supposed to absorb its tooling
(Anchor 3 — Mentl solves Mentl). This cascade rewrites build.sh
in `.mn`: a tiny Mentl program that orchestrates the build via
handlers.

Replacement target: `bootstrap/build.sh` → `tools/build.mn`.

## Handles (positive form)

1. **Hβ.tooling-build.fs-effect** — `FileSystem` effect with `read`,
   `write`, `list`, `glob`. Default handler maps to WASI fs preview.
2. **Hβ.tooling-build.process-effect** — `Process` effect with
   `spawn`, `wait`. Default handler uses WASI's process imports
   (or libc shim for native target).
3. **Hβ.tooling-build.cargo-style-config** — `tools/build.toml` (or
   `.mn`) describes the build graph: source dirs, output target,
   chunk dependencies.
4. **Hβ.tooling-build.incremental-cache** — content-hash per chunk;
   only rebuild if source changed (composes with `IC-incremental-
   compilation.md`).
5. **Hβ.tooling-build.parallel-tasks** — independent chunks
   compile concurrently via the topology of the dep graph.
6. **Hβ.tooling-build.shellscript-disposal** — remove
   `bootstrap/build.sh`, `bootstrap/CHUNKS.sh`, `bootstrap/test.sh`,
   `bootstrap/first-light.sh`. Contributors run `mentl build` /
   `mentl test` / `mentl first-light`.

## Acceptance

- `tools/build.mn` compiles to `tools/build.wasm` via the wheel.
- `wasmtime tools/build.wasm` produces the same `mentl.wasm` output
  as the prior `bootstrap/build.sh`.
- Test + first-light harnesses convert similarly.
- Bash dependency removed from the repo (or relegated to
  `legacy/`).

## Dep ordering

1 (fs) and 2 (process) in parallel → 3 (config) → 4 (caching) and
5 (parallel) in parallel → 6 (disposal).

## Cross-cascade dependencies

- **Gates on:** `Hβ-bootstrap-no-seed.md` complete (so the build
  process composes with self-hosted Mentl).
- **Composes with:** `Hβ-tooling-assemble-in-mentl.md`,
  `Hβ-tooling-runtime-in-mentl.md` (the rest of the toolchain in
  Mentl). Together: zero non-Mentl dependencies.
- **Closes:** Anchor 3 fully — Mentl solves its build, its
  assembly, its runtime; nothing Mentl depends on remains in another
  language.
