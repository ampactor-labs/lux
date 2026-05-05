# Hβ-pipeline-streaming.md — Token / AST streaming pipeline

**Status:** Named cascade. Per PLAN-to-first-light.md §3 post-Tier-3.
Plan-doc.

## Context

Today's pipeline is BATCHED: lexer reads ALL stdin → produces ALL
tokens → parser produces ALL AST → infer walks all → lower → emit.
For incremental editing (`inka edit`), batched is wrong: a one-line
edit shouldn't re-process the whole file.

This cascade introduces STREAMING: tokens emit as the lexer reads;
parser consumes one stmt at a time; infer/lower/emit pipeline each
stmt incrementally. The IC (incremental compilation) substrate
(`Hβ-incremental-compilation.md`) gates on this — IC requires per-
stmt deltas, not whole-file recompiles.

Replacement target: `src/lexer.nx` + `src/parser.nx` +
`src/main.nx` pipeline → handler-based streaming where each stage
is a generator handler, downstream handlers consume one item at a
time.

## Handles (positive form)

1. **Hβ.streaming.token-generator** — `Lexer` effect: `next_token() ->
   Option<Token>`. Default handler reads stdin lazily.
2. **Hβ.streaming.ast-generator** — `Parser` effect: `next_stmt() ->
   Option<Node>`. Default handler consumes tokens via `Lexer`,
   produces one stmt at a time.
3. **Hβ.streaming.infer-stage-streaming** — infer becomes
   per-stmt; env state persists across calls.
4. **Hβ.streaming.lower-stage-streaming** — same; per-stmt LowExpr
   produced.
5. **Hβ.streaming.emit-stage-streaming** — emit per-LowExpr; the
   funcref table + globals accumulate; finalize emits closing
   sections at EOF.
6. **Hβ.streaming.error-recovery** — per-stmt error doesn't halt;
   downstream gets `NErrorHole` per Hazel productive-under-error;
   pipeline continues.
7. **Hβ.streaming.large-file-bounded-memory** — multi-MB files
   compile in O(largest_stmt) memory, not O(file).

## Acceptance

- Compiling a 10MB Inka file uses bounded memory regardless of
  file size.
- Pipeline pauses at parse boundaries when stdin is slow (no busy
  spin).
- Per-stmt errors emit immediately; subsequent stmts compile.
- The IC substrate composes — re-edits invalidate per-stmt cache
  entries, not the whole pipeline.

## Dep ordering

1 → 2 → 3 → 4 → 5. Pipeline order. 6 (error recovery) is
cross-cutting; composes throughout. 7 is a benchmark / acceptance
test.

## Cross-cascade dependencies

- **Gates on:** Phase H + Tier 3.
- **Enables:** `Hβ-incremental-compilation.md` (existing IC
  walkthrough at `IC-incremental-compilation.md`); `inka edit`
  responsiveness on large files.
- **Composes with:** `Hβ-tooling-build-in-inka.md` (build.sh
  uses streaming for fast incremental builds).
