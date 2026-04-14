# Lux Documentation

*One pipeline. Many handlers. Each doc below is a handler that observes
the same underlying work and renders it for a different audience.*

---

## Reading order

If you've never seen Lux before:

1. [`../README.md`](../README.md) — the 2-minute "what is this" pitch.
2. [`DESIGN.md`](DESIGN.md) — the full manifesto. What Lux IS. Long,
   but every section is self-contained.
3. [`INSIGHTS.md`](INSIGHTS.md) — the consequences of getting the
   foundations right. Deep truths. Read after DESIGN.md.

If you want to contribute or pick up the codebase:

1. [`ROADMAP.md`](ROADMAP.md) — current state + where Lux is going.
2. [`ARCS.md`](ARCS.md) — narrated development history.
3. [`ARC3_ROADMAP.md`](ARC3_ROADMAP.md) — the current active arc.
4. [`../AGENTS.md`](../AGENTS.md) — agent handoff. What's in progress,
   what's broken, how to rebuild.
5. [`../bootstrap/README.md`](../bootstrap/README.md) — stage 0 → 1 → 2
   build recipe.

If you're designing a new feature:

1. [`specs/`](specs/) — existing design specs. Read ones adjacent to
   yours for the style.
2. [`EXAMPLES_NOT_TESTS.md`](EXAMPLES_NOT_TESTS.md) — the testing
   philosophy. No frameworks; `.lux` files are proofs.
3. [`SYNTHESIS_CROSSWALK.md`](SYNTHESIS_CROSSWALK.md) — external
   manifesto vs. Lux. Source of potential future directions.

---

## Layout

```
docs/
├── README.md                 this file — index + writing procedures
├── DESIGN.md                 manifesto — what Lux IS and WILL BE
├── INSIGHTS.md               deep truths — consequences of the foundations
├── ROADMAP.md                where we are, where we're going
├── ARCS.md                   canonical development history
├── ARC3_ROADMAP.md           active arc (native superpowers)
├── EXAMPLES_NOT_TESTS.md     testing philosophy — `.lux` files are proofs
├── SYNTHESIS_CROSSWALK.md    external manifesto → Lux mapping
└── specs/                    feature design specs
    ├── codegen-effect-design.md
    ├── dsp-pain-points.md
    ├── incremental-compilation.md
    ├── lux-ml-design.md
    ├── ml-pain-points.md
    ├── multi-shot-continuations.md
    ├── ownership-design.md
    ├── packaging-design.md
    └── scoped-memory.md
```

---

## Documentation procedures

These rules are not bureaucracy — they're how docs stay useful after
the person who wrote them forgets the context.

### 1. One source of truth per concept

If *what Lux is* lives in `DESIGN.md`, don't restate it in `ROADMAP.md`.
Link instead. Every doc should declare its scope in the opening line.

| Doc | Scope |
|---|---|
| `DESIGN.md` | What Lux IS — vision, mechanisms, emergent capabilities |
| `INSIGHTS.md` | Consequences of the design — deep truths, patterns |
| `ROADMAP.md` | Where Lux is now and where it's going — short |
| `ARCS.md` | Where Lux has been — narrated history, phase table |
| `ARC*_ROADMAP.md` | One active arc's plan — work in progress |
| `specs/*.md` | One feature's design — closed-ended proposal |

### 2. Phases vs. arcs

- **Phases** (numbered in `DESIGN.md`) are *language-feature stages* —
  effects, ownership, refinements, native backend, etc. They describe
  what Lux IS.
- **Arcs** (narrated in `ARCS.md`) are *bootstrap-history eras* — Rust
  foundation, self-hosting, Ouroboros, native superpowers. They
  describe what Lux HAS DONE.

They are **orthogonal**. A single arc may ship several phases;
a single phase may complete across several arcs. Use the appropriate
framing for the story you're telling.

### 3. Write specs as closed-ended proposals

Specs in `specs/` have a lifecycle: **proposed → implemented → absorbed**.
When implemented, leave the spec in place; add an `## Outcome` section
linking to the commits. When the feature becomes part of the language
identity, absorb the conceptual content into `DESIGN.md` or
`INSIGHTS.md`. The spec stays as a historical record.

### 4. Absolute dates, not relative ones

Write `2026-04-13`, not "today" or "yesterday" or "last week." Docs
outlive the conversations that produced them.

### 5. Link targets, not text

`See [`DESIGN.md`](DESIGN.md) → *Custom Native Backend*` instead of
copy-pasting the content. Links rot less than duplicated paragraphs.

### 6. Plain tables for status, not prose

`✅ Shipped | 🔄 In progress | 🔲 Planned | ⬜ Open` — these render
everywhere and skim instantly. Prose status claims rot silently.

### 7. Every doc starts with *what it is*

The first non-title line must answer "why would I read this?" One
sentence, italicized. Everything else is earnt attention.

### 8. No changelog files

Git is the changelog. `ARCS.md` is the narrated summary. Never add
`CHANGELOG.md`.

### 9. No TODO lists in docs

Issues, tasks, and in-progress work don't belong in documentation.
They belong in git branches, issue trackers, and conversations. Docs
describe what IS; tasks describe what SHOULD BE. Don't mix them.

### 10. The structural question

Before writing any doc, ask the first question from `INSIGHTS.md`:

> **"What answer already lives in my own structure, that I'm asking
> something else for?"**

If the answer is in `DESIGN.md`, link there. If it's in `ARCS.md`, link
there. A new doc is justified only when the answer lives nowhere yet.

---

## Status glyphs (convention)

| Glyph | Meaning |
|---|---|
| ✅ | Shipped — tested, in the default pipeline |
| 🔄 | In progress — PR open or active branch |
| 🔲 | Planned — agreed direction, not started |
| ⬜ | Open — surfaced but not decided |
| ❌ | Rejected — kept for the record |
