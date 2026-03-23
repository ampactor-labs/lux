---
description: how to develop and add new features to lux
---
// turbo-all

## Before Any Change

1. Read `CLAUDE.md` — it has the architecture, key files, phase history, and design principles
2. Read `docs/DESIGN.md` if proposing new language features — it's the thesis document
3. Read `docs/ROADMAP.md` to understand where we are in the 10-phase plan

## Design Principles

Every decision serves the thesis: **if you build the right foundations, most annotations become inferable.**

- **No band-aids.** If something needs a workaround, fix the design.
- **Gradient over levels.** Every annotation unlocks guarantees. No discrete switches.
- **Effects are THE mechanism.** Exceptions, state, generators, async, DI, backtracking — all handle/resume.
- **The pipe operator IS the idiom.** Data flows left-to-right; effects accumulate visibly.
- **Rust is transient.** Every .rs file is scaffolding. Don't optimize Rust code that will be deleted.
- **Lux is permanent.** `std/` and `examples/` persist through self-hosting. Make them exemplary.

## File Categories

| Category | Where | Survives self-hosting? |
|----------|-------|----------------------|
| Rust prototype | `src/` | **No** — replaced by Lux |
| Self-hosted compiler | `std/compiler/` | **Yes** — Lux forever |
| Standard library | `std/prelude.lux`, `std/types.lux`, `std/test.lux` | **Yes** |
| Domain libraries | `std/dsp/`, `std/ml/` | **Yes** |
| Examples & tests | `examples/` | **Yes** |

## Commit Discipline

- Commit at meaningful boundaries: a working feature, a fixed bug, a doc update
- Message format: `type: description` where type is `feat`, `fix`, `docs`, `test`, `refactor`
- Run `cargo test` before committing
- If changing Lux syntax or semantics, update CLAUDE.md and DESIGN.md

## Doc-to-Code Mapping

When editing these source files, update the corresponding docs:

| Source | Update |
|--------|--------|
| `src/ast.rs` | CLAUDE.md (Architecture) |
| `src/checker/` | CLAUDE.md, docs/DESIGN.md |
| `std/compiler/*.lux` | CLAUDE.md (Architecture, Key Files) |
| `std/prelude.lux` | CLAUDE.md (Key Files) |
| New examples | CLAUDE.md (examples count), add .expected file |
