# Hβ-bootstrap-no-seed.md — Delete the bootstrap entirely

**Status:** Named cascade. Opens after `Hβ-bootstrap-seed-in-inka.md`
lands. Plan-doc in positive form per Stage F.

## Context

After `Hβ-bootstrap-seed-in-inka.md`, the seed compiler is `.nx`
authored. But the disposable-bootstrap thesis (CLAUDE.md operational
essentials lines 165-167) says: "A disposable bootstrap translator
(~3-5K lines) compiles it once; after that, Inka compiles itself;
the translator is deleted." The seed-in-inka is itself disposable —
once the wheel can self-host, the seed is no longer needed.

Replacement target: `bootstrap/seed/**/*.nx` (post-seed-in-inka) →
deleted. `bootstrap/inka.wasm` (the canonical compiler) is produced
directly from the wheel's own self-compile.

## Handles (positive form)

1. **Hβ.no-seed.canonical-self-compile** — `inka.wasm` produced from
   `cat src/*.nx lib/**/*.nx | wasmtime <prior-inka.wasm> >
   self.wat ; wat2wasm self.wat -o inka.wasm`. Canonical compile
   discipline.
2. **Hβ.no-seed.delete-bootstrap-seed** — remove `bootstrap/seed/`
   tree. Compiler distribution becomes wheel + one prior `.wasm`.
3. **Hβ.no-seed.update-build-tooling** — `bootstrap/build.sh`
   becomes `tools/self-compile.sh` (or similar); new contributors
   download a prior `.wasm` once and self-compile from there.
4. **Hβ.no-seed.first-time-bootstrap-doc** — README + protocol-doc
   for the "very first time" bootstrap (clean checkout): download a
   pinned `.wasm` from a release tag, self-compile current source.

## Acceptance

- `bootstrap/seed/` tree no longer exists.
- New checkout can self-compile from a pinned `.wasm` artifact.
- All trace harnesses + first-light fixpoint pass against the
  self-compiled `inka.wasm`.

## Dep ordering

1 → 2 → 3 → 4. Tooling updates last so existing contributors aren't
broken mid-cascade.

## Cross-cascade dependencies

- **Gates on:** `Hβ-bootstrap-seed-in-inka.md` complete.
- **Composes with:** `Hβ-tooling-build-in-inka.md` (build.sh in
  Inka) — the build tool itself becomes Inka substrate.
- **Disposes:** the `.wat`-hand-author + .nx-bootstrap-author paths.
  After this cascade, only the wheel itself remains.
