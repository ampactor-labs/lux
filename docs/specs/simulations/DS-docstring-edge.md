# DS — Docstring-as-Intent-Edge

*Cross-cutting round-trip. Preserves `///` docstrings as graph edges
so Mentl and every handler projection surface can read them — not
just the lexer.*

**Part of: IR cluster ([IR-intent-round-trip.md](IR-intent-round-trip.md)).**
**Status: 2026-04-22 · seeded.**

---

## §1 Frame

The developer writes:

```
/// Charges the card. Idempotent across retries.
fn charge(own card: Card) with IO = ...
```

The `///` docstring is the developer's highest-intent annotation —
it's free-form natural language describing WHAT the function does
and WHY. It sits above the declaration. It is the authored intent
at its most direct.

**Gap.** The lexer (lexer.mn:167-173) emits `TDocComment(content)`
tokens. The parser (parser.mn:75, 147) recognizes them. But the
parser does NOT attach the docstring to the following declaration.
The `FnStmt` (types.mn:503-504) has no docstring field. The typed
AST has no docstring edge. The Graph has no docstring Reason.

The docstring is born in the token stream and dies before it reaches
the graph. Mentl's Teach tentacle cannot read "Idempotent across
retries" when explaining why `charge` should not allocate. Hover
cannot display the docstring alongside the type. Audit cannot
surface docstrings in per-fn reports.

---

## §2 Trace — where the docstring lives and where it stops

### Lexer (lexer.mn:165-173)

The lexer detects `///` (three consecutive `/` bytes), captures the
rest of the line as `TDocComment(doc_text)`, and emits it as a
token with span. This IS the correct first step — the docstring is
a first-class token, not discarded whitespace.

```
if pos + 2 < n && byte_at(source, pos + 2) == 47 {
  // Doc comment: capture rest of line as TDocComment payload.
  let after = scan_to_eol(source, n, pos + 3)
  let doc_text = str_slice(source, pos + 3, after)
  ...
  push_tok(buf, count, mk_tok(TDocComment(doc_text), line, col, line, end_col))
}
```

### Parser (parser.mn)

`TDocComment(_)` appears in the token classification (parser.mn:75)
and the token display function (parser.mn:147). But the parser's
statement parsing — `parse_fn_stmt`, `parse_type_def`, etc. — does
NOT look for a preceding `TDocComment` token. The token is in the
stream; no parser rule consumes it and attaches it to the next
declaration.

When the parser encounters `TDocComment` at statement position, it
is either silently skipped (if the parser advances past unrecognized
tokens) or causes a parse error. The token exists but has no consumer.

### Inference / Graph

No docstring reaches inference. No graph node carries a docstring
Reason. No env entry carries docstring metadata.

### Hover / Mentl / Audit

No downstream surface can read a docstring from the graph.

---

## §3 Design candidates + Mentl's choice

### §3.1 Docstring attachment at parse time

**Candidate A: Parser attaches docstring to the following statement.**
The parser tracks the most recent `TDocComment` token. When parsing
a FnStmt, TypeDefStmt, EffectDeclStmt, HandlerDeclStmt, or
RefineStmt, it checks for a pending docstring and attaches it to the
statement node. `FnStmt` gains a `docstring: Option<String>` field.

**Candidate B: Docstring as a separate statement.**
Parser emits `DocstringStmt(content, span)` as a standalone
statement. Inference pairs it with the following declaration by
position.

**Candidate C: Docstring as a Reason edge on the env entry.**
No AST change. Instead of storing the docstring on the statement,
store it as a `DocstringReason(content, span)` on the env entry
that the following declaration creates. The parser collects the
docstring token and passes it through to inference, which threads
it into `env_extend`.

**Mentl's choice: A + C — parser attaches, Reason carries.**
The docstring belongs to the DECLARATION (A) and also needs to
reach the graph as a Reason (C). A without C means the docstring
is on the AST but not in the graph; Mentl can't query it. C without
A means the docstring floats in the token stream until inference,
coupling the parser's token position to inference's env extend.
A first (parser attaches); then C (inference threads it as a Reason).

### §3.2 Docstring storage shape

**Candidate A: Optional String field on each statement type.**
`FnStmt(name, params, ret, effs, body, docstring: Option<String>)`.
Each declaration type gains a field.

**Candidate B: Wrapper node `Documented(String, Stmt)`.**
A new `Stmt` variant that wraps any statement with its docstring.
Generic across all statement types.

**Candidate C: Metadata record on the N() node.**
`N(body, span, handle, metadata)` where `metadata` is
`{docstring: Option<String>, ...}`. Extensible.

**Mentl's choice: B — wrapper node.** `Documented(String, Stmt)` is
generic — it wraps FnStmt, TypeDefStmt, EffectDeclStmt, etc.
without modifying each variant's field list. Candidate A requires
changing every declaration variant (6 variants × 1 field each).
Candidate C changes the N() node shape, which touches every
pattern match on N() in the compiler (~100 sites).

---

## §4 Layer touch-points

### types.mn
Add `Documented(String, Stmt)` variant to the `Stmt` type. One line.

Add `DocstringReason(String, Span)` variant to `Reason`. One line.

### parser.mn
Track the most recent `TDocComment` in parser state. When a
`TDocComment` token is encountered at statement position, store
its content. When the next statement is parsed, wrap it in
`Documented(content, stmt)` if a docstring is pending.

### infer.mn
`infer_stmt` gains an arm for `Documented(doc, inner_stmt)`:
unwrap, set the docstring as context, then infer `inner_stmt`.
At `env_extend` time for the inner declaration, thread the
docstring as a `DocstringReason(doc, span)` Reason.

### Mentl / hover
`show_reason` gains a `DocstringReason` arm that renders the
docstring content. Hover on a function name displays the docstring
above the type signature. Mentl's Teach tentacle reads the
docstring when explaining the function's purpose.

### cache.mn
Docstrings are compile-time metadata. For incremental compilation,
they serialize alongside the env entry. Cache serialization gains
a `DocstringReason` case.

---

## §5 Acceptance

**AT-DS1.** `/// Charges the card.` above `fn charge(own card: Card)`
— hover on `charge` displays "Charges the card." above the type
signature.

**AT-DS2.** `DocstringReason("Charges the card.", span)` appears in
the env entry's Reason for `charge`. The Why Engine can trace from
any type question on `charge` to the docstring.

**AT-DS3.** Multi-line docstrings (consecutive `///` lines) are
concatenated into a single docstring string.

**AT-DS4.** A declaration without a `///` docstring — no
`Documented` wrapper; no `DocstringReason`. No noise.

**AT-DS5.** Mentl's Teach tentacle reads the docstring when
surfacing function explanations: "charge — 'Charges the card.
Idempotent across retries.' — declared own on card, with IO."

---

## §6 Scope + peer split

| Peer | Surface | Load |
|---|---|---|
| DS.1 | `Documented(String, Stmt)` variant + `DocstringReason` | Light (~5L types.mn) |
| DS.2 | Parser docstring attachment | Moderate (~30L parser.mn) |
| DS.3 | Inference docstring threading to Reason | Moderate (~20L infer.mn) |
| DS.4 | Hover/Mentl docstring display | Light (~15L hover/mentl handler) |

Total: ~70 lines. Four commits; DS.1 → DS.2 → DS.3 → DS.4.

---

## §7 Dependencies

- **Upstream:** none. Standalone cross-cutting work.
- **Downstream:** EVERY handler projection surface gains docstring
  access. MV.2's Teach tentacle reads docstrings. Hover displays
  them. Audit per-fn reports include them. NS-naming's docstring
  template (FV.9) builds on DS's parser attachment.

---

## §8 What DS refuses

- **Docstrings as comments.** `//` comments are discarded. `///`
  docstrings are TOKEN-level, GRAPH-level, REASON-level. They are
  intent, not annotation. The lexer already makes this distinction
  (lexer.mn:166-173). DS completes the pipeline.
- **Docstrings as metadata sidecar.** The docstring lives in the
  graph as a Reason, not in a parallel metadata store. One graph,
  one substrate. Mentl reads the same graph everyone reads.
- **Markdown/HTML parsing of docstring content.** DS stores raw
  content. Rendering is the handler projection's job (hover renders
  differently from audit differently from Mentl). The substrate
  stores; the handler interprets. One mechanism.
- **Mandatory docstrings.** The gradient (primitive #7) suggests
  "add a docstring to charge" when one is missing. The compiler
  does not force it. The annotation is the developer's choice;
  the gradient surfaces the opportunity.

---

## §9 Connection to the kernel

- **Cross-cutting** — docstrings attach to any primitive's
  declaration site. Every tentacle reads DS-edges when present.
- **Primitive #1** (graph) — docstrings enter the graph as Reason
  edges. They are queryable alongside types, effects, and ownership.
- **Primitive #7** (gradient) — missing docstrings are gradient
  opportunities. GR can suggest "add /// docstring to charge" when
  the function lacks one and it's the highest-leverage missing
  annotation.
- **Primitive #8** (reasons) — `DocstringReason` IS a Reason. The
  Why Engine traces through it. A developer asking "why does Mentl
  say this function is idempotent?" gets back the docstring they
  wrote.
- **Mentl** — all eight tentacles read docstrings when present.
  Teach quotes them. Verify references them in refinement
  explanations. Why traces through them. The docstring IS the
  developer's voice in the graph.
