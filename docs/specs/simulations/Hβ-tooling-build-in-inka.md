# Hβ-tooling-build-in-inka.md — build.sh in Inka

**Status:** Named cascade. Per PLAN-to-first-light.md §3 post-Tier-3.
Plan-doc.

## Context

Today: `bootstrap/build.sh` is a bash script that concatenates WAT
chunks per CHUNKS.sh, runs wat2wasm, and produces `inka.wasm`. It's
~3K lines of shell. Inka is supposed to absorb its tooling
(Anchor 3 — Inka solves Inka). This cascade rewrites build.sh
in `.nx`: a tiny Inka program that orchestrates the build via
handlers.

Replacement target: `bootstrap/build.sh` → `tools/build.nx`.

## Handles (positive form)

1. **Hβ.tooling-build.fs-effect** — `FileSystem` effect with `read`,
   `write`, `list`, `glob`. Default handler maps to WASI fs preview.
2. **Hβ.tooling-build.process-effect** — `Process` effect with
   `spawn`, `wait`. Default handler uses WASI's process imports
   (or libc shim for native target).
3. **Hβ.tooling-build.cargo-style-config** — `tools/build.toml` (or
   `.nx`) describes the build graph: source dirs, output target,
   chunk dependencies.
4. **Hβ.tooling-build.incremental-cache** — content-hash per chunk;
   only rebuild if source changed (composes with `IC-incremental-
   compilation.md`).
5. **Hβ.tooling-build.parallel-tasks** — independent chunks
   compile concurrently via the topology of the dep graph.
6. **Hβ.tooling-build.shellscript-disposal** — remove
   `bootstrap/build.sh`, `bootstrap/CHUNKS.sh`, `bootstrap/test.sh`,
   `bootstrap/first-light.sh`. Contributors run `inka build` /
   `inka test` / `inka first-light`.

## Acceptance

- `tools/build.nx` compiles to `tools/build.wasm` via the wheel.
- `wasmtime tools/build.wasm` produces the same `inka.wasm` output
  as the prior `bootstrap/build.sh`.
- Test + first-light harnesses convert similarly.
- Bash dependency removed from the repo (or relegated to
  `legacy/`).

## Dep ordering

1 (fs) and 2 (process) in parallel → 3 (config) → 4 (caching) and
5 (parallel) in parallel → 6 (disposal).

## Cross-cascade dependencies

- **Gates on:** `Hβ-bootstrap-no-seed.md` complete (so the build
  process composes with self-hosted Inka).
- **Composes with:** `Hβ-tooling-assemble-in-inka.md`,
  `Hβ-tooling-runtime-in-inka.md` (the rest of the toolchain in
  Inka). Together: zero non-Inka dependencies.
- **Closes:** Anchor 3 fully — Inka solves its build, its
  assembly, its runtime; nothing Inka depends on remains in another
  language.
