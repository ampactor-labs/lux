# HI — Handler-Identity Intent Preservation

*Primitive #2 round-trip. Preserves handler identity through
inference so diagnostics, hover, and Mentl's Propose tentacle can
name WHICH handler provides a given effect op.*

**Part of: IR cluster ([IR-intent-round-trip.md](IR-intent-round-trip.md)).**
**Status: 2026-04-22 · seeded.**

---

## §1 Frame

Mentl's primitive #2 is handlers with typed resume discipline. The
developer installs a handler chain:

```
source
    |> infer_program
    ~> env_handler
    ~> graph_handler
    ~> diagnostics_handler
```

When `perform report(...)` fires inside `infer_program`, WHICH
handler provided the `report` op? The answer is `diagnostics_handler`
— the developer installed it at position 3 in the `~>` chain.

**Gap.** The handler identity is known at INSTALL time (the `~>` or
`handle` expression names the handler or its arms). But at PERFORM
time, the connection is lost. When an `E_EffectMismatch` diagnostic
fires, the error message says "effect mismatch" — not "emitted by
diagnostics_handler installed at pipeline.mn:42."

When hover inspects a `perform env_lookup(name)` call, it shows the
return type `Option` — but not "provided by env_handler installed
at pipeline.mn:38." The handler identity — which IS the capability
stack's layer naming — doesn't reach the downstream surface.

The `handler_stack` in `infer_ctx` (infer.mn:45-47, 56-60) already
tracks handler names during inference: `inf_push_handler(name)` at
HandleExpr entry, `inf_pop_handler()` at exit. The stack is
populated but no downstream consumer reads it for handler-identity
attribution.

---

## §2 Trace — where identity is and isn't

### Handler installation (infer.mn:524-596)

At `HandleExpr` inference, the handler's arms are collected and
the handled effect names extracted. The handler_stack is pushed
with `inf_push_handler(handler_stack_tag(handled_names))`. The
tag is currently the handled names concatenated — not the handler's
authored name.

For `~>` tee sites (infer.mn:821-837):
```
perform inf_push_handler("pipe_tee")
```
The string `"pipe_tee"` is a generic tag, not the handler's name.
If the developer wrote `source ~> env_handler`, the tag should be
`"env_handler"`, not `"pipe_tee"`.

### Handler declaration (infer.mn:179-180)

`HandlerDeclStmt(hname, ename, arms)` registers the handler name
`hname` in the env. The env entry carries `hname`. But when the
handler is installed via `handle { ... } with handler_name`, the
HandleExpr's arms carry the arm bodies, not the handler's authored
name.

### PerformExpr (infer.mn:519-522, 744-768)

`infer_perform` looks up the op name in env, finds the
`EffectOpScheme(effect_name)`, infers the args, and adds the effect
row. At no point does it record WHICH handler in the current stack
provides this op. The `handler_stack` is readable via
`inf_handler_stack()` but never queried at perform sites.

### Diagnostics (effects.mn:373-389, own.mn:35-41)

Diagnostic `perform report(...)` calls carry source, code, kind,
msg, span, applicability. No handler-identity field. The diagnostic
doesn't say "emitted by diagnostics_handler."

---

## §3 Design candidates + Mentl's choice

### §3.1 Handler identity at perform sites

**Candidate A: Query handler reads handler_stack at hover time.**
No inference change. When hover inspects a `perform` site, it
queries `inf_handler_stack()` to see which handlers are installed
at that inference point. The first handler in the stack whose
handled effects include the performed op's effect is the provider.

**Candidate B: Annotate each perform with its resolved handler.**
At `infer_perform`, after looking up the op, also resolve which
handler_stack entry provides this op. Store the handler name as a
Reason edge on the perform site.

**Candidate C: Handler names flow through the ~> syntax.**
Parser extracts the handler name from the RHS of `~>`. InferCtx
stores the name (not a generic "pipe_tee" tag). The handler_stack
then carries real names.

**Mentl's choice: C first (fix the handler_stack tags), then A
(query at hover time).** The handler_stack already exists and is
already pushed/popped at every handler install site. The problem is
that the tags are generic strings instead of authored names. Fixing
the tags at the source (C) means the stack carries real names;
querying it at hover time (A) uses it. Candidate B duplicates
the stack information onto every perform site, which is wasteful —
the stack IS the information.

### §3.2 Fixing handler_stack tags

At `HandleExpr` (infer.mn:539):
```
perform inf_push_handler(handler_stack_tag(handled_names))
```
Replace `handler_stack_tag(handled_names)` with the handler's
authored name. For inline `handle { ... } { arms }` expressions
(no name), use a descriptive tag from the handled effects.

At `~>` tee sites (infer.mn:827, 833):
```
perform inf_push_handler("pipe_tee")
```
Replace `"pipe_tee"` with the RHS handler's name. The parser
would need to thread the handler name through the PipeExpr's
right-hand node. When the RHS is a `VarRef` naming a handler, the
name IS the handler identity. When the RHS is an inline handler
expression, use the handled effect names as the tag.

---

## §4 Layer touch-points

### parser.mn
No structural change. The RHS of `~>` is already an expression
node. When it's a VarRef, the name is available. The handler name
resolution happens at inference, not parse time.

### infer.mn
- **HandleExpr** (infer.mn:524-596): Extract handler name from the
  handler declaration (if the arms come from a named handler) or
  from the handled effect names (for inline handlers).
- **PipeExpr ~> sites** (infer.mn:821-837): Thread the RHS
  expression's name into the `inf_push_handler` call.
- **New query op**: `handler_provider(op_name) -> Option<String>`
  — reads handler_stack, finds the first entry whose handled
  effects include the named op, returns the handler name.

### types.mn
No change. Handler_stack is already `List<String>` in InferCtx
state.

### hover / Mentl
Hover on `perform op(args)` displays "provided by handler_name
(installed at span)". Mentl's Propose tentacle reads
`handler_provider` when suggesting handler alternatives.

---

## §5 Acceptance

**AT-HI1.** `source ~> env_handler` — `inf_handler_stack()` at the
body's inference point includes `"env_handler"`, not `"pipe_tee"`.

**AT-HI2.** `perform env_lookup("x")` inside the body — hover shows
"provided by env_handler" alongside the return type.

**AT-HI3.** Inline `handle { body } { effect_name(args) => ... }` —
handler_stack includes `"effect_name_handler"` (derived from the
handled effect), not a generic tag.

**AT-HI4.** `handler_provider("env_lookup")` returns
`Some("env_handler")` when env_handler is in the stack.

**AT-HI5.** Nested handlers: inner handler shadows outer for the same
effect. `handler_provider` returns the innermost (top-of-stack)
provider.

---

## §6 Scope + peer split

| Peer | Surface | Load |
|---|---|---|
| HI.1 | Fix handler_stack tags (authored names) | Moderate (~20L infer.mn) |
| HI.2 | `handler_provider` query op | Light (~15L query.mn or infer.mn) |
| HI.3 | Hover handler-identity display | Light (~15L hover handler) |

Total: ~50 lines. Three commits; HI.1 first (fixes the data),
HI.2 (exposes the query), HI.3 (renders it).

---

## §7 Dependencies

- **Upstream:** none. Standalone primitive #2 work. The
  handler_stack infrastructure already exists.
- **Downstream:** MV.2's Propose tentacle reads handler identity
  when suggesting alternative handler installations. LSP hover's
  handler-naming depends on HI. Error messages gain handler context
  (e.g., "E_EffectMismatch — the declaring handler 'env_handler'
  does not handle this op").

---

## §8 What HI refuses

- **Per-perform-site handler annotation.** Handler identity is a
  property of the STACK at a point in the program, not of each
  individual perform. Storing the handler name on every perform node
  duplicates the stack and drifts when the stack changes.
- **Handler identity at runtime.** Handler identity is compile-time.
  WAT has no notion of "which handler provided this." The identity
  is for diagnostics, hover, and Mentl — all compile-time surfaces.
- **Generic handler names.** `"pipe_tee"`, `"handle_body"`, etc.
  These are mechanism-speak. The handler's authored name is the
  intent; use it.

---

## §9 Connection to the kernel

- **Primitive #2** substrate gains an intent layer. Every handler
  the developer names is traceable to every perform site it
  provides.
- **Primitive #1** (graph) — the handler_stack IS a graph structure
  (a stack of handler names indexed by installation position).
  Querying it IS a graph read.
- **Primitive #8** (reasons) — handler identity flows into Reasons:
  `InferredCallReturn("env_lookup via env_handler", ...)` names
  both the op and its provider in the Why chain.
- **Mentl tentacle Propose** reads handler identity when suggesting
  handler alternatives. "You have env_handler installed; consider
  caching_env_handler for incremental compilation."
