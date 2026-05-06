# Hβ-tooling-assemble-in-mentl.md — wat2wasm in Mentl

**Status:** Named cascade. Per PLAN-to-first-light.md §3 post-Tier-3.
Plan-doc.

## Context

Today: `wat2wasm` (from WABT) converts `.wat` text to `.wasm` binary.
Mentl uses it as an external tool. Per Anchor 3 — Mentl solves Mentl.
This cascade implements wat2wasm in Mentl: parse WAT text, encode to
binary per the WASM spec, output `.wasm`.

Replacement target: WABT's `wat2wasm` → `tools/wat2wasm.mn`.

This cascade becomes OPTIONAL if `Hβ-emit-binary-direct.md` lands
first (compiler emits binary directly, no WAT intermediate). But
it's still useful: WAT text is the canonical inspection format
documented widely; tools that produce WAT (other compilers,
hand-authored tests) need a parser.

## Handles (positive form)

1. **Hβ.assemble.wat-lexer** — tokenize WAT s-expressions: parens,
   identifiers, literals, comments.
2. **Hβ.assemble.wat-parser** — build a tree of WAT s-expressions.
   Reuse Mentl's parser substrate (it's a compiler — parsing
   s-expressions is trivial).
3. **Hβ.assemble.wat-to-wasm-translator** — walk the s-expr tree,
   emit binary per the WASM spec. Reuse `runtime/binary.mn` LEB128
   helpers.
4. **Hβ.assemble.section-encoders** — type, function, table, memory,
   global, export, element, code, data sections each get a
   per-section encoder.
5. **Hβ.assemble.symbolic-references** — `$name`-style references
   resolve to numeric indices via a symbol table built during the
   first pass.
6. **Hβ.assemble.validation** — implement `wasm-validate` (also from
   WABT) in Mentl. Same parser; checks types, control-flow, memory
   constraints.

## Acceptance

- `wasmtime tools/wat2wasm.wasm <input.wat> -o <output.wasm>`
  produces byte-identical output to WABT's wat2wasm for ALL WAT
  files in the wheel.
- Validation diagnostics match WABT's where applicable.
- WABT toolchain dependency removed from the repo.

## Dep ordering

1 → 2 (lexer + parser foundation) → (3, 4) parallel → 5 (symbolic
resolution) → 6 (validation; can be standalone or integrated).

## Cross-cascade dependencies

- **Gates on:** `Hβ-bootstrap-no-seed.md` complete (so the
  toolchain composes).
- **Made optional by:** `Hβ-emit-binary-direct.md` (compiler skips
  WAT).
- **Composes with:** `Hβ-tooling-build-in-mentl.md`,
  `Hβ-tooling-runtime-in-mentl.md`.
