# Hβ-bootstrap-no-seed.md — Delete the bootstrap entirely

**Status:** Named cascade. Opens after `Hβ-bootstrap-seed-in-mentl.md`
lands. Plan-doc in positive form per Stage F.

## Context

After `Hβ-bootstrap-seed-in-mentl.md`, the seed compiler is `.mn`
authored. But the disposable-bootstrap thesis (CLAUDE.md operational
essentials lines 165-167) says: "A disposable bootstrap translator
(~3-5K lines) compiles it once; after that, Mentl compiles itself;
the translator is deleted." The seed-in-mentl is itself disposable —
once the wheel can self-host, the seed is no longer needed.

Replacement target: `bootstrap/seed/**/*.mn` (post-seed-in-mentl) →
deleted. `bootstrap/mentl.wasm` (the canonical compiler) is produced
directly from the wheel's own self-compile.

## Handles (positive form)

1. **Hβ.no-seed.canonical-self-compile** — `mentl.wasm` produced from
   `cat src/*.mn lib/**/*.mn | wasmtime <prior-mentl.wasm> >
   self.wat ; wat2wasm self.wat -o mentl.wasm`. Canonical compile
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
  self-compiled `mentl.wasm`.

## Dep ordering

1 → 2 → 3 → 4. Tooling updates last so existing contributors aren't
broken mid-cascade.

## Cross-cascade dependencies

- **Gates on:** `Hβ-bootstrap-seed-in-mentl.md` complete.
- **Composes with:** `Hβ-tooling-build-in-mentl.md` (build.sh in
  Mentl) — the build tool itself becomes Mentl substrate.
- **Disposes:** the `.wat`-hand-author + .mn-bootstrap-author paths.
  After this cascade, only the wheel itself remains.
