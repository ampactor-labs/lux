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

Every op decl carries `@resume=OneShot | MultiShot | Either` (Affect
POPL 2025; landed in spec 02's `TCont`). Parser delta in spec 03.
`Diagnostic.report`'s `code` and `applicability` become refined
Strings in Arc F.1; Phase 1 treat them as free Strings.

---

## Compiler-internal effects

### Infer

```lux
effect Infer {
  fresh_ty(Reason) -> Int          @resume=OneShot
  fresh_row(Reason) -> Int         @resume=OneShot
  bind(Int, Ty, Reason) -> ()      @resume=OneShot
  unify(Int, Int, Reason) -> ()    @resume=OneShot
}
```

The `infer.ka` module hosts the handler for these ops; underneath,
the handler performs SubstGraph ops.

### Diagnostic

```lux
effect Diagnostic {
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

**The `!Diagnostic` constraint lives on the HANDLER, not on the
effect.** Handlers declare `with !Diagnostic` (e.g., `handler
stderr_diagnostics with !Diagnostic { … }`); any `perform report`
inside fails subsumption via spec 01. Policy lives where policy lives.

Reserved codes — canonical explanations at `docs/errors/<CODE>.md`
(Elm/Roc/Dafny catalog pattern; see `docs/errors/README.md` for the
full table and conventions). Every `report(...)` names a code whose
file exists. Rule: new codes land in the catalog BEFORE their first
call site.

### ParseError

Op returns a `Node` (holding `NHole`) so parsing continues past the
error — Hazel pattern per spec 03/04.

```lux
effect ParseError {
  unexpected(expected: String, got: String, span: Span) -> Node  @resume=OneShot
}
```

### LowerCtx

```lux
effect LowerCtx {
  is_ctor(String) -> Bool       @resume=OneShot
  is_global(String) -> Bool     @resume=OneShot
  is_state_var(String) -> Bool  @resume=OneShot
  fresh_id() -> Int             @resume=OneShot
}
```

### LowVisit

```lux
effect LowVisit {
  visit_node(Int) -> ()         @resume=MultiShot
  visit_pat(Int) -> ()          @resume=MultiShot
  get_collected() -> List       @resume=OneShot
}
```

### Iterate

```lux
effect Iterate {
  yield(element: T) -> ()       @resume=OneShot
  result() -> ()                @resume=OneShot
}
```

`result()` is the generator-terminator handshake.

### Alloc

```lux
effect Alloc { alloc(size: Int) -> Int       @resume=OneShot }
```

Subsumed by `!Alloc` in spec 01.

### Memory

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

WASM-primitive.

### WasmOut

```lux
effect WasmOut { out(String) -> ()             @resume=OneShot }
```

### Clock family (detail in spec 11)

Four peers: `Clock` (wall), `Tick` (logical), `Sample` (DSP),
`Deadline` (real-time). Capability negations participate in the row
algebra. `<~` (spec 10) requires one as iterative context.

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

### EnvRead (spec 04)

```lux
effect EnvRead {
  env_lookup(String) -> Option((Scheme, Reason))   @resume=OneShot
  env_snapshot() -> Env                            @resume=OneShot
}
```

### EnvWrite (spec 04)

```lux
effect EnvWrite {
  env_extend(String, Scheme, Reason) -> ()         @resume=OneShot
  env_scope_enter() -> ()                          @resume=OneShot
  env_scope_exit() -> ()                           @resume=OneShot
}
```

Peer of SubstGraph: Read/Write split, effect-mediated, one writer.
Inference declares both; lowering and query declare `with EnvRead`
only.

### Verify (detail in spec 02)

```lux
effect Verify {
  verify(Span, Predicate, Reason) -> ()            @resume=OneShot
  verify_debt() -> List                            @resume=OneShot
}
```

Handler swap: **Phase 1** default `verify_ledger` accrues
obligations (emits `V001`); **Arc F.1** `verify_smt` discharges via
Z3/cvc5/Bitwuzla (emits `E200` on reject). No stub. See spec 02.

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

Span flows as op payload; `affine_ledger` reads for diagnostics.

### Query (spec 08)

```lux
effect Query {
  ask(Question) -> QueryResult               @resume=OneShot
}
```

### Teach (Mentl — detail in spec 09)

```lux
effect Teach {
  teach_here(String, Span, Ty) -> ()              @resume=OneShot
  teach_gradient(Int) -> Option(Annotation)        @resume=OneShot
  teach_why(Int) -> Reason                         @resume=OneShot
  teach_error(String, Span, Reason) -> Explanation @resume=OneShot
  teach_unlock(Annotation) -> Capability           @resume=OneShot
}
```

Five tentacles on the inference substrate. `Annotation`, `Capability`,
`Explanation` ADTs defined in spec 09.

### Synth (Arc F.1 wires real handlers)

```lux
effect Synth {
  synth(Int, Ty, Context) -> Candidate       @resume=OneShot
}
```

Phase 1 default returns `NoCandidate`; Arc F.1 plugs in Canonical /
Synquid / LLM proposers as peer handlers verified by the compiler.

### FreshHandle (spec 04)

```lux
effect FreshHandle {
  mint(Reason) -> Int                        @resume=OneShot
}
```

Parameterizes `instantiate`: inference mints via `graph_fresh_ty`;
query mints display ids. One function, two handlers.

---

## Handler rules (structurally gated — no preflight)

- `Diagnostic` default `stderr_diagnostics`; LSP overrides `json_diagnostics`. One active.
- `LookupTy` has one handler (`lookup_ty_graph`, spec 05).
- `SubstGraph` / `Env` compose via fork (spec 00 / spec 04).
- `Consume` `affine_ledger` installs per-FnStmt.
- `perform report` inside a `with !Diagnostic` handler → type error.
- Any Write from a Read-only handler → type error.
- Duplicate handler name / undeclared op / `_` wildcard arm → all type errors.

---

## Consumed by

- Every std/compiler/*.ka — this is the linker interface; checker enforces
  every `perform op` matches a declared op.
- Arc F.2 LSP handler — serializes Diagnostic and Query as JSON-RPC.
