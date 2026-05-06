# 03 — TypedAST: AST with live type handles and real spans

**Purpose.** The AST data structure the frontend produces and the
backend consumes. Every node carries a `TypeHandle` (Int index into
the Graph from spec 00) and a full `Span`, not a point. Type
resolution is always a live chase via `LookupTy` — never a cached Ty
field.

**Kernel primitives implemented:** #1 (every AST node handle is a
Graph handle), #8 (productive-under-error — `NErrorHole`
placeholders let the walk continue). Also carries the surface for
#3 (the five verbs as `PipeKind`).

**Research anchors.**
- Hazel POPL 2024 — Total Type Error Localization: ill-typed
  expressions become marked holes; downstream services keep working.
- Tree-sitter and rust-analyzer — full spans (start/end), not points,
  for all tooling.

---

## Node wrapper

```lux
type Span
  = Span(Int, Int, Int, Int)    // start_line, start_col, end_line, end_col

type Node
  = N(NodeBody, Span, Int)      // body, span, TypeHandle into Graph

type NodeBody
  = NExpr(Expr)
  | NStmt(Stmt)
  | NPat(Pat)
  | NHole(Int)                  // marked hole id (Hazel)
```

**Invariant.** Every expression site is an `N(...)`. The handle is
allocated at parse time via `perform graph_fresh_ty(Placeholder(span))`
and populated during inference. There is no code path that produces
an N without a handle.

---

## Expr

```lux
type Expr
  = LitInt(Int)
  | LitFloat(Float)
  | LitString(String)
  | LitBool(Bool)
  | LitUnit
  | VarRef(String)
  | BinOpExpr(String, Node, Node)
  | UnaryOpExpr(String, Node)
  | CallExpr(Node, List)              // fn, args (each Node)
  | LambdaExpr(List, Node)            // params (TParam), body
  | IfExpr(Node, Node, Node)
  | BlockExpr(List, Node)             // stmts, final
  | MatchExpr(Node, List)             // scrutinee, arms
  | HandleExpr(Node, List)            // body, handler arms
  | PerformExpr(String, List)         // op name, args
  | ResumeExpr(Node, List)            // value, state updates
  | MakeListExpr(List)
  | MakeTupleExpr(List)
  | FieldExpr(Node, String)
  | PipeExpr(PipeKind, Node, Node)    // |>, <|, ><, ~>, <~ (spec 10)
  | Placeholder                       // `?` → spawns NHole
```

```lux
// ~> splits by layout per DESIGN Ch 2 / spec I11 — newline-before-~>
// binds outside the prior chain (PTeeBlock), no-newline tightens
// around the preceding stage (PTeeInline). Inference and lowering
// treat both identically; only the parser distinguishes.
type PipeKind = PForward | PDiverge | PCompose | PTeeBlock | PTeeInline | PFeedback
```

---

## Stmt

```lux
type Stmt
  = LetStmt(Pat, Node)
  | FnStmt(String, List, Node, List, Node)
                       // name, params (TParam), retty annotation, effects, body
  | TypeDefStmt(String, List, List)
                       // name, type args, variants
  | EffectDeclStmt(String, List)
                       // effect name, ops (each with resume-discipline)
  | HandlerDeclStmt(String, String, List)
                       // handler name, effect name, arms
  | ExprStmt(Node)
  | ImportStmt(String)
  | RefineStmt(String, Ty, Predicate)
                       // nominal refinement: type Port = Int where ...
```

---

## Pat

```lux
type Pat
  = PVar(String)
  | PWild
  | PLit(LitValue)
  | PCon(String, List)
  | PTuple(List)
  | PList(List)
  | PRecord(List)               // (fieldname, Pat)
```

---

## TypeHandle: the only route to a type

```lux
let ty = perform lookup_ty(node.handle)
```

`LookupTy` (spec 05) delegates to `graph_chase`. This is the ONLY way
to read a type from a node. There is no direct field access. There
is no Ty cache.

**Why.** The graph is live and the epoch evolves. A cached Ty is
stale the moment inference binds a handle transitively reachable from
here. By always going through `lookup_ty`, downstream passes are
automatically correct against the latest graph state — and the
live-chase discipline makes the "does my graph already know" anchor
structurally true.

---

## Spans, non-negotiable

Every node has a 4-tuple span. Every lexer token produces a span. The
parser composes child spans into parent spans:

```lux
// parser.mn sketch (parse_binop):
let span = Span.join(left.span, right.span)
let h = perform graph_fresh_ty(BinOpPlaceholder(op))
N(NExpr(BinOpExpr(op, left, right)), span, h)
```

Retrofitting spans later = full AST walk. Landing day-one = trivial
parser change. Non-negotiable.

---

## Marked holes (Hazel integration)

A source-level `?` produces `NHole(hole_id)`. Inference does NOT fail
on a hole — it allocates a TVar handle and continues with rich
context available to downstream handlers (Suggest, Synth, LSP
completion).

```lux
// Phase 1 wires the ADT variant; Arc F.1 installs the Synth handler:
perform synth(hole_id, expected_ty, typed_context) -> Candidate
```

Unresolved errors on NON-hole expressions still produce Diagnostic
reports (via inference in spec 04). Holes are first-class; genuine
errors are not.

---

## Parser contract

The parser is recursive descent with Pratt expression parsing. It
produces three top-level ADTs (Expr, Stmt, Pat) wrapped in `N(body,
span, handle)`. Every construction point performs
`perform graph_fresh_ty(Placeholder(span))` to mint a handle at parse
time; never a null handle field; never a sentinel zero. Error
recovery is the Hazel pattern — emit a Diagnostic, plant an `NHole`,
continue parsing.

Surface forms:
- `?` tokens → `NHole(next_id)`.
- `type X = T where P` → `RefineStmt(X, T, P)`.

---

## Lexer / Parser details

Spec 03 owns the AST contract; the lexer and parser implement it.

**Lexer:**
- Every token carries `Span(sl, sc, el, ec)` — the end position is
  the lexer's output, not derived by the parser.
- `?` becomes `TK_QUESTION`, a single-character token producing
  `Placeholder` in expression position.
- `where` becomes a contextual keyword after `type X = T` (only
  there; elsewhere still a free identifier).
- `@resume` is a `@` punctuation + identifier pair, parsed as an
  effect-op-decl annotation (see `06-effects-surface.md`).

**Parser:**
- Every node construction calls `perform graph_fresh_ty(Placeholder(span))`
  to mint a handle at parse time. Never a null handle field; never
  a sentinel zero.
- Parent spans compose from child spans via
  `Span.join(a, b) = Span(a.sl, a.sc, b.el, b.ec)`.
- `type X = T where P` produces `RefineStmt(X, T, P)` (parser arm
  ships when Arc F.1 needs it; the ADT variant lands from day one).
- Effect op declarations accept a trailing
  `@resume=OneShot|MultiShot|Either` annotation, parsed into the op
  signature's `ResumeDiscipline` field (spec 02's TCont discipline).

**Synthetic spans.** Nodes produced by codegen or future macro
expansion with no source origin use the sentinel `Span(0, 0, 0, 0)`.
`QTypeAt(Span(0, 0, 0, 0))` returns `QRError("synthetic node — no
source position")`. LSP hover over a synthetic span returns no
content.

---

## Consumed by

- `04-inference.md` — walks these nodes, binds their handles.
- `05-lower.md` — consumes the typed AST, produces LowIR with the
  same handles.
- `07-ownership.md` — walks for Consume performs and ref-escape
  structural checks.
- `08-query.md` — span-indexed lookup: `mentl query FILE "type at L:C"`
  finds a node by span, reads its handle.

---

## Rejected alternatives

- **Immediate Ty caching on nodes.** Graph is live; a cached Ty is
  stale the moment inference binds a handle transitively reachable
  from it. Live chase is the only discipline that stays correct.
- **ANF / CPS at parse.** Premature. Structural AST stays structural;
  spec 05 does the CPS transform for handler elimination.
- **Projectional editor tokens.** Text is canonical; structure is
  what the parser extracts.
- **Fully generic NodeBody across Expr/Stmt/Pat.** Separate ADTs
  under a single wrapper read better in pattern matches without
  sacrificing the uniform span/handle discipline.
