# 06 — Effects surface: every effect, with discipline and codes

**Purpose.** Inventory every effect signature the rebuild uses, with
op-level metadata: signature, resume discipline (one-shot /
multi-shot), and diagnostic codes for any op that reports errors. The
rule: if an effect isn't in this file, it doesn't exist.

**Research anchors.**
- Affect POPL 2025 — one-shot / multi-shot at the type level.
- Rust rustc-dev-guide — every diagnostic hint carries a structured
  applicability tag.
- Elm / Roc / Dafny error catalogs — stable codes + canonical
  explanations + fix templates.
- Austral — linear capabilities at module boundaries.

---

## Shared op metadata

Every op decl carries `@resume=OneShot | MultiShot | Either`. Phase
C's parser delta (spec 03) reads it into the op signature's
`ResumeDiscipline` field (spec 02's `TCont`). Research anchor: Affect
POPL 2025 puts the distinction at the type level.

`Diagnostic.report`'s `code` and `applicability` arguments become
refined-String values in Arc F.1 (`code: String where code in {"E001",
...}`). Phase A–E treat them as free Strings.

---

## Preserved from v1 (with metadata added)

### Infer

```lux
effect Infer {
  fresh_ty(Reason) -> Int          @resume=OneShot
  fresh_row(Reason) -> Int         @resume=OneShot
  bind(Int, Ty, Reason) -> ()      @resume=OneShot
  unify(Int, Int, Reason) -> ()    @resume=OneShot
}
```

v1 `infer.lux` is deleted; its logic moves into the handler for this
effect in `v2/infer.lux`. Underneath, handlers perform SubstGraph ops.

### Diagnostic (extended from `ty.lux:20-22`)

v1 was `report(source, kind, msg, line, col) -> ()`. The rebuild
extends to 6-arg with `code`, full `span`, and `applicability`:

```lux
effect Diagnostic with !Diagnostic {
  report(
    source: String,
    code: String,                // stable error code (E001, W017, ...)
    kind: String,
    msg: String,
    span: Span,
    applicability: String        // MachineApplicable | MaybeIncorrect
  ) -> ()                        @resume=OneShot
}
```

**`with !Diagnostic` is load-bearing.** Handler arms for `report`
cannot themselves perform `Diagnostic.report` — the Boolean effect
algebra (spec 01) gates the recursion at type-check time. No
preflight, no stdout corruption, no handler-observer drift.

Reserved codes (expanded from
`docs/specs/diagnostic-effect-signature.md`):

| Code | Kind                        | Emitted by                   |
|------|-----------------------------|------------------------------|
| E001 | MissingVariable             | inference                    |
| E002 | TypeMismatch                | inference                    |
| E003 | PatternInexhaustive         | inference                    |
| E004 | OwnershipError              | v2/own.lux, v2/infer.lux     |
| E010 | OccursCheck                 | SubstGraph bind              |
| E100 | UnresolvedType              | v2/lower.lux                 |
| E200 | Refinement                  | Arc F.1 solver handler       |
| W017 | Suggestion                  | suggest.lux                  |
| T001 | Teach                       | gradient.lux                 |
| T002 | ContinuationEscapesArena    | Arc F.4                      |
| P001 | ParseError                  | lexer + parser               |

**Rule.** New codes are documented in this table BEFORE their first
call site. No `kind = "<unclassified>"` patterns.

### ParseError (from `parser.lux:14-16`)

v1: `unexpected(expected, got, line, col) -> Expr` — the op RETURNS
an Expr for error-recovery continuation. Rebuild preserves that
pattern, returning a `Node` holding an `NHole`:

```lux
effect ParseError {
  unexpected(expected: String, got: String, span: Span) -> Node
                                    @resume=OneShot
}
```

Inference continues with the hole per spec 04's Hazel pattern.

### LowerCtx (from `lower_ir.lux:15-21`)

```lux
effect LowerCtx {
  is_ctor(String) -> Bool       @resume=OneShot
  is_global(String) -> Bool     @resume=OneShot
  is_state_var(String) -> Bool  @resume=OneShot
  fresh_id() -> Int             @resume=OneShot
}
```

### LowVisit (from `lower_ir.lux:27-31`)

```lux
effect LowVisit {
  visit_node(Int) -> ()         @resume=MultiShot
  visit_pat(Int) -> ()          @resume=MultiShot
  get_collected() -> List       @resume=OneShot
}
```

### Iterate (from `std/prelude.lux:10-13`)

```lux
effect Iterate {
  yield(element: T) -> ()       @resume=OneShot
  result() -> ()                @resume=OneShot
}
```

Preserved verbatim; `result()` is the generator-terminator handshake.

### Alloc (from `std/runtime/memory.lux:31-33`)

```lux
effect Alloc {
  alloc(size: Int) -> Int       @resume=OneShot
}
```

Preserved verbatim; subsumed by `!Alloc` in spec 01.

### Memory (from `std/runtime/memory.lux:21-29`)

```lux
effect Memory {
  load_i32(addr: Int) -> Int                      @resume=OneShot
  store_i32(addr: Int, val: Int) -> ()            @resume=OneShot
  load_i8(addr: Int) -> Int                       @resume=OneShot
  store_i8(addr: Int, val: Int) -> ()             @resume=OneShot
  mem_copy(dst: Int, src: Int, size: Int) -> ()   @resume=OneShot
  byte_at(s: Int, i: Int) -> Int                  @resume=OneShot
  byte_len(s: Int) -> Int                         @resume=OneShot
}
```

Preserved verbatim; WASM-primitive.

### WasmOut (from `std/backend/wasm_collect.lux:36`)

```lux
effect WasmOut {
  out(String) -> ()             @resume=OneShot
}
```

Preserved verbatim.

---

## New effects

### SubstGraphRead (spec 00)

```lux
effect SubstGraphRead {
  graph_chase(Int) -> GNode                  @resume=OneShot
  graph_epoch() -> Int                       @resume=OneShot
  graph_reason_edge(Int, Int) -> Reason      @resume=OneShot
  graph_snapshot() -> SubstGraph             @resume=OneShot
}
```

### SubstGraphWrite (spec 00)

```lux
effect SubstGraphWrite {
  graph_fresh_ty(Reason) -> Int              @resume=OneShot
  graph_fresh_row(Reason) -> Int             @resume=OneShot
  graph_bind(Int, Ty, Reason) -> ()          @resume=OneShot
  graph_bind_row(Int, EffRow, Reason) -> ()  @resume=OneShot
  graph_fork(String) -> ()                   @resume=OneShot
}
```

The Read/Write split IS the "one writer" invariant. Inference
declares both; lowering and query declare Read only. See spec 00.

### LookupTy (spec 05)

```lux
effect LookupTy {
  lookup_ty(Int) -> Ty                       @resume=OneShot
}
```

### Consume (spec 07)

```lux
effect Consume {
  consume(name: String, span: Span) -> ()    @resume=OneShot
}
```

Span flows as op payload; the `affine_ledger` handler reads it
directly for diagnostic emission. No `current_span` in handler state;
no separate dynamic-scope effect (spec 07 defers SourceContext to F).

### Query (spec 08)

```lux
effect Query {
  ask(Question) -> QueryResult               @resume=OneShot
}
```

### Teach

```lux
effect Teach {
  teach_here(String, String, Ty) -> ()       @resume=OneShot
                                             // binding name, span-ref, type
}
```

### Synth (stub in Phase C, real handler Arc F.1)

```lux
effect Synth {
  synth(Int, Ty, Context) -> Candidate       @resume=OneShot
                                             // hole id, expected ty, typed context
}
```

Stub returns `NoCandidate` until Arc F.1 wires Canonical / Synquid
synthesis.

### FreshHandle (spec 04)

```lux
effect FreshHandle {
  mint(Reason) -> Int                        @resume=OneShot
}
```

Parameterizes `instantiate`. Inference handler mints via
`graph_fresh_ty`; query handler returns `'a, 'b, ...` display ids.
One function, two handlers — no `instantiate_for_display`.

---

## Handler rules & forbidden patterns (structurally gated)

- **Diagnostic** default: `stderr_diagnostics`. LSP overrides with
  `json_diagnostics`. Exactly one active.
- **LookupTy** has exactly one handler (`lookup_ty_graph`, spec 05).
- **SubstGraph** composes via fork (spec 00).
- **Consume** `affine_ledger` installs per-FnStmt.
- **`Diagnostic.report` inside `report` arm** → type error via
  `!Diagnostic`.
- **SubstGraph write from lowering / query** → type error via
  Read/Write split.
- **Duplicate handler name / handler for undeclared op / `_` wildcard
  arm** → all type errors; no preflight.

---

## Consumed by

- Every v2/*.lux — this is the linker interface; checker enforces
  every `perform op` matches a declared op.
- Arc F.2 LSP handler — serializes Diagnostic and Query as JSON-RPC.
