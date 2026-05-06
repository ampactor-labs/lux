# Hβ-bootstrap-seed-in-mentl.md — Seed compiler authored in Mentl, not WAT

**Status:** Named cascade. Opens after Phase H + Tier 3 land. Per
PLAN-to-first-light.md §3 post-Tier-3 lines 488. Plan-doc at
positive form per Stage F closure criterion.

## Context

The current bootstrap is hand-written WAT (`bootstrap/mentl.wat`,
~26K lines assembled from `bootstrap/src/**/*.wat`). It compiles
the wheel canonical (`src/*.mn` + `lib/**/*.mn`) into WAT. After
Phase H + Tier 3, the wheel compiles itself — but the SEED is still
hand-WAT. This cascade moves the seed implementation INTO Mentl:
write the bootstrap compiler in `.mn`, compile via the wheel, the
output WASM IS the seed. The seed ceases to be hand-WAT; it becomes
Mentl projecting itself.

Replacement target: `bootstrap/src/**/*.wat` →
`bootstrap/seed/**/*.mn` + a single self-compile step.

## Handles (positive form)

1. **Hβ.seed-in-mentl.lexer-projection** — `bootstrap/seed/lexer.mn`
   mirrors `bootstrap/src/lexer.wat`.
2. **Hβ.seed-in-mentl.parser-projection** — `bootstrap/seed/parser/*.mn`
   mirrors `parser_*.wat` chunks.
3. **Hβ.seed-in-mentl.runtime-projection** — `bootstrap/seed/runtime/*.mn`
   mirrors `runtime/*.wat`.
4. **Hβ.seed-in-mentl.infer-projection** — `bootstrap/seed/infer/*.mn`.
5. **Hβ.seed-in-mentl.lower-projection** — `bootstrap/seed/lower/*.mn`.
6. **Hβ.seed-in-mentl.emit-projection** — `bootstrap/seed/emit/*.mn`.
7. **Hβ.seed-in-mentl.main-projection** — `bootstrap/seed/main.mn`
   pipeline orchestrator.
8. **Hβ.seed-in-mentl.fixpoint-validation** — `cat src/*.mn
   lib/**/*.mn | wasmtime <wheel.wasm> > seed.wat ; wat2wasm seed.wat
   -o seed.wasm ; cat src/*.mn lib/**/*.mn | wasmtime seed.wasm >
   seed2.wat ; diff seed.wat seed2.wat` empty.
9. **Hβ.seed-in-mentl.disposal** — delete `bootstrap/src/**/*.wat`;
   `bootstrap/mentl.wat` becomes generated artifact only.

## Acceptance

- `bootstrap/seed/**/*.mn` files compile through the wheel to produce
  a working seed compiler.
- The seed compiler compiles the wheel byte-identically to the
  prior hand-WAT seed.
- All 77+ trace harnesses still pass (or replaced by `.mn`-native
  harnesses).
- `bootstrap/src/**/*.wat` removed; CHUNKS.sh + build.sh updated to
  the new pipeline.

## Dep ordering

Pipeline-stage order: 1 → 2 → 3 → 4 → 5 → 6 → 7. Then 8 (fixpoint
validation), then 9 (disposal). Each pipeline-stage projection can
land independently as long as its layer's contract is preserved.

## Cross-cascade dependencies

- **Gates on:** Phase H 12/12 closed (✓ this session); Tier 3 6/6
  closed (Stage D); `mentl edit` end-to-end (Stage E).
- **Composes with:** `Hβ-bootstrap-no-seed.md` (delete the bootstrap
  entirely) — the natural successor once seed-in-mentl ships.
- **Conflicts with:** none; this is a structural simplification.
