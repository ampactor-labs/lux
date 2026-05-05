# Hβ-bootstrap-seed-in-inka.md — Seed compiler authored in Inka, not WAT

**Status:** Named cascade. Opens after Phase H + Tier 3 land. Per
PLAN-to-first-light.md §3 post-Tier-3 lines 488. Plan-doc at
positive form per Stage F closure criterion.

## Context

The current bootstrap is hand-written WAT (`bootstrap/inka.wat`,
~26K lines assembled from `bootstrap/src/**/*.wat`). It compiles
the wheel canonical (`src/*.nx` + `lib/**/*.nx`) into WAT. After
Phase H + Tier 3, the wheel compiles itself — but the SEED is still
hand-WAT. This cascade moves the seed implementation INTO Inka:
write the bootstrap compiler in `.nx`, compile via the wheel, the
output WASM IS the seed. The seed ceases to be hand-WAT; it becomes
Inka projecting itself.

Replacement target: `bootstrap/src/**/*.wat` →
`bootstrap/seed/**/*.nx` + a single self-compile step.

## Handles (positive form)

1. **Hβ.seed-in-inka.lexer-projection** — `bootstrap/seed/lexer.nx`
   mirrors `bootstrap/src/lexer.wat`.
2. **Hβ.seed-in-inka.parser-projection** — `bootstrap/seed/parser/*.nx`
   mirrors `parser_*.wat` chunks.
3. **Hβ.seed-in-inka.runtime-projection** — `bootstrap/seed/runtime/*.nx`
   mirrors `runtime/*.wat`.
4. **Hβ.seed-in-inka.infer-projection** — `bootstrap/seed/infer/*.nx`.
5. **Hβ.seed-in-inka.lower-projection** — `bootstrap/seed/lower/*.nx`.
6. **Hβ.seed-in-inka.emit-projection** — `bootstrap/seed/emit/*.nx`.
7. **Hβ.seed-in-inka.main-projection** — `bootstrap/seed/main.nx`
   pipeline orchestrator.
8. **Hβ.seed-in-inka.fixpoint-validation** — `cat src/*.nx
   lib/**/*.nx | wasmtime <wheel.wasm> > seed.wat ; wat2wasm seed.wat
   -o seed.wasm ; cat src/*.nx lib/**/*.nx | wasmtime seed.wasm >
   seed2.wat ; diff seed.wat seed2.wat` empty.
9. **Hβ.seed-in-inka.disposal** — delete `bootstrap/src/**/*.wat`;
   `bootstrap/inka.wat` becomes generated artifact only.

## Acceptance

- `bootstrap/seed/**/*.nx` files compile through the wheel to produce
  a working seed compiler.
- The seed compiler compiles the wheel byte-identically to the
  prior hand-WAT seed.
- All 77+ trace harnesses still pass (or replaced by `.nx`-native
  harnesses).
- `bootstrap/src/**/*.wat` removed; CHUNKS.sh + build.sh updated to
  the new pipeline.

## Dep ordering

Pipeline-stage order: 1 → 2 → 3 → 4 → 5 → 6 → 7. Then 8 (fixpoint
validation), then 9 (disposal). Each pipeline-stage projection can
land independently as long as its layer's contract is preserved.

## Cross-cascade dependencies

- **Gates on:** Phase H 12/12 closed (✓ this session); Tier 3 6/6
  closed (Stage D); `inka edit` end-to-end (Stage E).
- **Composes with:** `Hβ-bootstrap-no-seed.md` (delete the bootstrap
  entirely) — the natural successor once seed-in-inka ships.
- **Conflicts with:** none; this is a structural simplification.
