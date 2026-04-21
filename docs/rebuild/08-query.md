# 08 — Query: forensic substrate for the live graph

**Purpose.** One subcommand, `inka query <file> <question>`, that runs
lex + parse + infer on a single file and answers forensic questions
against the resulting SubstGraph. Sub-second per query. Substrate for
Arc F.2 (the Mentl-voice surface and its LSP projection — every LSP
method decomposes to a Query variant).

**Kernel primitives implemented:** #1 (Query IS a handler projection
of the graph) and #8 (Reasons — the Why Engine is one Query
variant). This is the purest demonstration of "the graph IS the
program": no new machinery, no cache, just read the live substrate.
Mentl tentacles served: **Query** (primary) and **Why** (secondary).

**Research anchors.**
- ChatLSP OOPSLA 2024 — typed context for LLM completion. The same
  context Query produces for forensic answers serves LLM editors.
- Rust applicability-tagged diagnostics — Query output is structured
  with confidence markers.

---

## The Question / QueryResult ADTs

```lux
type Question
  = QTypeOf(String)                     // "type of NAME"
  | QTypeAt(Span)                       // "type at L:C"
  | QUnresolved                         // "unresolved"
  | QSubstChain(Int)                    // "subst trace for TVar(N)"
  | QEffects(String)                    // "effects of NAME"
  | QOwnership(String)                  // "ownership of NAME"
  | QWhy(String)                        // "why NAME"
  | QVerifyDebt                         // "verification debt"
  | QUnknown(String)

type QueryResult
  = QRType(Ty, Reason)
  | QRUnresolved(List)                  // [(name, Ty, List[Int])]
  | QRChain(List)                       // [(handle, Node)] — chase hops
  | QREffects(EffRow)
  | QROwnership(List)                   // [(name, Ownership)]
  | QRWhy(Reason)
  | QRVerifyDebt(List)                  // [(Span, Predicate, Reason)] pending obligations
  | QRError(String)
```

---

## The Query effect

```lux
effect Query {
  ask(Question) -> QueryResult          @resume=OneShot
}
```

Installed at `inka query` entry point. The handler declares
`with SubstGraphRead + EnvRead + FreshHandle`. Read-only by
construction: no `SubstGraphWrite` / `EnvWrite` in scope means
`perform graph_bind` or `perform env_extend` fails type-check at
handler install. No preflight rule — effect-row subsumption (spec 00
/ spec 01) is the gate.

**Env is not a closure argument.** Same discipline as the graph. Peer
ambient knowledge read through effects. Query reads, never writes.

---

## The parser

Regex-lite tokenization over the question string:

```lux
fn parse_query(q: String) -> Question =
  match split_whitespace(q) {
    ["type", "of", name]             => QTypeOf(name),
    ["type", "at", pos]              => QTypeAt(parse_pos(pos)),
    ["unresolved"]                   => QUnresolved,
    ["subst", "trace", "for", tvar]  => QSubstChain(parse_tvar(tvar)),
    ["effects", "of", name]          => QEffects(name),
    ["ownership", "of", name]        => QOwnership(name),
    ["why", name]                    => QWhy(name),
    _                                => QUnknown(q)
  }

fn parse_pos(s) = {
  // "10:27" -> Span(10, 27, 10, 27)
  let (line_s, col_s) = split(s, ":")
  let line = parse_int(line_s)
  let col = parse_int(col_s)
  Span(line, col, line, col)
}

fn parse_tvar(s) = {
  // "TVar(42)" -> 42
  let inner = strip_prefix(strip_suffix(s, ")"), "TVar(")
  parse_int(inner)
}
```

No syntax extensions needed. Every query is a String literal in the
shell.

---

## The executor

```lux
handler query_default with SubstGraphRead + EnvRead + FreshHandle {
  ask(q) => match q {
    QTypeOf(name) => match perform env_lookup(name) {
      None => resume(QRError("not found: " ++ name)),
      Some((sch, reason)) => {
        let ty = instantiate(sch)   // FreshHandle handler mints display ids
        resume(QRType(ty, reason))
      }
    },
    QTypeAt(span) => match find_node_at(ast, span) {
      None => resume(QRError("no node at " ++ show_span(span))),
      Some(node) => {
        let ty = perform lookup_ty(node.handle)
        let GNode(_, reason) = perform graph_chase(node.handle)
        resume(QRType(ty, reason))
      }
    },
    QUnresolved => resume(QRUnresolved(walk_env_for_unresolved())),
    QSubstChain(handle) => resume(QRChain(walk_chain(handle))),
    QEffects(name) => match perform env_lookup(name) {
      None => resume(QRError("not found: " ++ name)),
      Some((sch, _)) => match instantiate(sch) {
        TFun(_, _, row) => resume(QREffects(row)),
        _ => resume(QRError(name ++ " is not a function"))
      }
    },
    QOwnership(name) => match perform env_lookup(name) {
      None => resume(QRError("not found: " ++ name)),
      Some((sch, _)) => match instantiate(sch) {
        TFun(params, _, _) => resume(QROwnership(map(param_ownership, params))),
        _ => resume(QRError(name ++ " is not a function"))
      }
    },
    QWhy(name) => match perform env_lookup(name) {
      None => resume(QRError("not found: " ++ name)),
      Some((_, reason)) => resume(QRWhy(reason))
    },
    QUnknown(q) => resume(QRError("unknown query: " ++ q))
  }
}
```

`walk_env_for_unresolved` performs `env_snapshot()` and walks the
result; same for any other op needing the whole env. No closure
capture; the effect is the interface.

`instantiate` is the shared function from spec 04. The query handler
installs a `placeholder_mint` handler for `FreshHandle`:
`mint(r) => resume(next_placeholder_id(r))` — returns `'a, 'b, ...`
display ids instead of allocating real graph handles. Inference's
handler mints via `graph_fresh_ty`. Same function; two handlers.

For `QTypeAt`, the Reason comes from the node's own `GNode` (chased
from the graph), not a synthesized `Reason.FromSpan` variant. The
graph already knows why the handle was bound; query just reads it.

---

## CLI integration

```lux
// std/main.ka
match argv[0] {
  "check"   => lux_check(argv[1]),
  "wasm"    => lux_wasm(argv[1]),
  "query"   => lux_query(argv[1], argv[2]),
  _         => print_usage()
}

fn lux_query(file, question) = {
  let source = read_file(file)
  let ast = source |> lex |> parse
  perform compile_check(ast)         // runs infer, populates graph, builds env
  let q = parse_query(question)
  let result = perform ask(q)
  println(render_query_result(result))
}
```

---

## Output format (stable; grep-friendly)

```
type of NAME
→ NAME : TYPE   (confidence: applicable | maybe)
  Reason chain:
    - step 1
    - step 2
```

```
unresolved
→ 3 entries:
  - NAME1 : TYPE containing TVar(142) @epoch=5 at line 47
  - NAME2 : ...
```

```
subst trace for TVar(42)
→ TVar(42) @epoch=5 (NBound)
    via Unified(VarLookup("xs"), FnParam("map", 1)) at line 12
  → TList(TVar(43)) @epoch=7
    via Literal("int") at line 14
  → TList(TInt) @terminal
```

Lines prefixed `→` are machine-readable state; indented lines are
Reason trails. Arc F.2 LSP serializes the same `QueryResult` values
as JSON-RPC responses.

---

## Performance target

`inka query std/compiler/own.ka "type of check_return_pos"` returns in
< 1s on a mid-tier laptop.

Bottleneck: lex + parse + infer of one file (not the whole program).
For the 200-line own.ka, a single-file inference pass is well under
1s; stage2's ~75s cost is the full pipeline including lowering +
wasm emit, none of which query needs.

Non-goal: cross-file queries. If module A imports an identifier
defined in B, the query falls back to the full bootstrap path. Fix in
Arc F.2 with incremental caching (Salsa 3 per-module overlay ready
via spec 00).

---

## Consumed by

- Arc F.2 — LSP handler wraps Query + JSON-RPC.
- Every future forensic session — `inka query` is the default first-
  line tool after preflight. Commitment #10: "after every rebuild
  commit, inka query on at least one of the changed modules."

---

## Rejected alternatives

- **Interactive REPL.** A REPL depends on execution; Query is
  strictly observation. Execution is the REPL arc's concern (spec
  F.3), not this spec.
- **Cross-file global query.** Module-local queries first; global
  cross-module queries later. Keeps the substrate minimal.
- **Parsed-once Query object threaded through the pipeline.** Over-
  engineered. Parse on demand; handlers cache if they care.
- **Query writes constraints and observes resolution.** Tempting for
  "what if" exploration. Kept read-only in Phase 1 to preserve the
  invariant that query cannot corrupt a compilation. Arc F.2 can add
  a scoped-snapshot write mode.
