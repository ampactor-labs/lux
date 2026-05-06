# RX — Reason-Intent Audit

*Primitive #8 round-trip. Audits every Reason construction site in
the compiler, grades each for intent vs mechanism, and upgrades
low-intent Reasons to carry authored vocabulary.*

**Part of: IR cluster ([IR-intent-round-trip.md](IR-intent-round-trip.md)).**
**Status: 2026-04-22 · seeded.**

---

## §1 Frame

Mentl's primitive #8 is HM inference with Reasons. Every graph node
and every unification step records a Reason (types.mn:231-251). The
Why Engine walks this DAG: hover asks "why is this Int?" and gets
back the full chain — `Inferred("int literal") → VarLookup("x", ...)
→ LetBinding("result", ...) → FnReturn("process", ...)`.

The Reason DAG IS the intent substrate for the Why tentacle. When
Reasons are high-intent, the chain reads like a narrative the
developer can follow. When Reasons are low-intent (mechanism-speak),
the chain reads like compiler internals.

**Gap.** The current Reason vocabulary (types.mn:231-251) has 18
variants. Some are high-intent:

- `Declared("process")` — "the developer declared this as 'process'"
- `VarLookup("card", ...)` — "you referenced 'card' here"
- `FnReturn("charge", ...)` — "this is the return type of 'charge'"

Some are low-intent (mechanism):

- `Fresh(42)` — "a fresh type variable was allocated with handle 42"
- `Inferred("call return")` — "this was inferred as the return of
  a call" (which call? to what function? the string is generic)
- `Inferred("fn effects")` — "effects were inferred" (no fn name)
- `Inferred("expected fn")` — mechanism-speak for unification
- `Placeholder(span)` — "a placeholder was here" (no context)

The low-intent Reasons produce Why chains that read like:
`"Fresh(42) → Inferred('call return') → Unified(...)"` —
indecipherable to a developer who asked "why is this an Int?"

A high-intent chain reads:
`"Declared('process') → the return type of 'process' → variable
lookup of 'result' in 'charge' → the int literal 42"` — a narrative.

---

## §2 Inventory — every Reason construction site

The audit walks every `Reason(...)` construction in the compiler.
Each site is graded:

### Grade A (high-intent — no change needed)

These Reasons already speak the developer's vocabulary:

| Site | Reason | Why it's high-intent |
|---|---|---|
| infer.mn env_extend for FnStmt | `Declared(name)` | Names the function |
| infer.mn env_extend for RefineStmt | `Declared(name)` | Names the refinement alias |
| infer.mn VarRef | `VarLookup(name, reason)` | Names the variable |
| infer.mn FnReturn | `FnReturn(name, reason)` | Names the function |
| infer.mn FnParam | `FnParam(name, idx, reason)` | Names the param |
| infer.mn LetBinding | `LetBinding(name, reason)` | Names the binding |
| infer.mn MatchBranch | `MatchBranch(scrutinee, arm)` | Links both sides |
| infer.mn UnifyFailed | `UnifyFailed(a, b)` | Carries the types |
| effects.mn Located | `Located(span, reason)` | Site-annotated |
| infer.mn Refinement | `Refinement(pred, pred)` | Carries predicates |

### Grade B (partial-intent — could be improved)

| Site | Current Reason | Missing intent |
|---|---|---|
| infer.mn:204 | `FnReturn(name, Fresh(0))` | The `Fresh(0)` says nothing; should be `Inferred("return of " ++ name)` |
| infer.mn:205 | `Inferred("fn effects")` | Should be `Inferred("effects of '" ++ name ++ "'")` |
| infer.mn:394-398 | `Inferred("int literal")` etc. | Could carry the literal value: `Inferred("int literal 42")` |
| infer.mn:437 | `Inferred("if condition")` | Could name the enclosing fn |
| infer.mn:447 | `Inferred("block result")` | Could name the enclosing fn |

### Grade C (low-intent — mechanism-speak)

| Site | Current Reason | What should it say |
|---|---|---|
| infer.mn:790-799 | `Inferred("|> return")` etc. | Should name the pipe verb: `Inferred("forward pipe (|>) at line N")` |
| infer.mn:718-719 | `Inferred("call return")`, `Inferred("call effects")` | Should name the callee: `Inferred("return of call to '" ++ callee_name ++ "'")` |
| infer.mn:726-727 | `Inferred("expected fn")`, `Inferred("expected fn type")` | Should name the call site: `Inferred("expected type of '" ++ callee_name ++ "'")` |
| infer.mn:460-461 | `Inferred("empty list element")`, `Inferred("empty list")` | Acceptable, but could carry span |
| graph.mn (fresh alloc) | `Fresh(handle)` | Should carry the allocation context: `FreshInContext(handle, fn_name)` |

---

## §3 Design candidates + Mentl's choice

### §3.1 Upgrading Grade B/C Reasons

**Candidate A: Enrich existing Reason strings.**
Replace `Inferred("fn effects")` with `Inferred("effects of 'process'")`.
No new Reason variants; just better strings.

**Candidate B: New structured Reason variants.**
Add `InferredCallReturn(callee_name, Reason)`,
`InferredPipeResult(PipeKind, Reason)`, etc. Structured data
instead of format strings.

**Candidate C: Contextual Reason builder.**
A helper function `fn reason_in_context(base_reason, fn_name, span)`
that wraps any Reason with its enclosing context via `Located`.

**Mentl's choice: A for Grade B sites, B for Grade C sites.**
Grade B sites are minor string enrichments — the Reason variant is
already correct, the string just needs the function name threaded
in. Grade C sites need structural changes because the current
variant (`Inferred(String)`) can't carry the callee name or pipe
kind in a machine-readable way for the Why Engine to walk.

**New Reason variants for Grade C:**

```
| InferredCallReturn(String, Reason)    // callee_name, inner
| InferredPipeResult(PipeKind, Reason)  // verb, inner
| FreshInContext(Int, String)           // handle, context_name
```

**Load.** Moderate across many files, but each site is a 1-2 line
edit. The audit sweep is the work; each fix is mechanical.

---

## §4 Layer touch-points

### types.mn
Add new Reason variants: `InferredCallReturn(String, Reason)`,
`InferredPipeResult(PipeKind, Reason)`, `FreshInContext(Int, String)`.
Update `show_reason` for each.

### infer.mn (~15 sites)
Thread the enclosing function name into Grade B Reason strings.
Replace Grade C `Inferred(...)` with structured variants at call
sites and pipe sites.

### graph.mn
Thread context name into `Fresh` allocations where the fn context
is available.

### effects.mn
No change — effects.mn Reasons are already `Located`.

### Mentl / Why Engine
`show_reason` gains arms for the new variants. The Why Engine's
walk produces chains that read as developer-facing narratives.

---

## §5 Acceptance

**AT-RX1.** Hover "why is this Int?" on a variable bound to a call
result traces through `InferredCallReturn("process", FnReturn("process", Declared("process")))` — the chain names the function at
every step.

**AT-RX2.** Hover "why?" on a pipe result traces through
`InferredPipeResult(PForward, ...)` — the verb identity appears in
the Why chain.

**AT-RX3.** `show_reason` renders Grade B/C Reasons in authored
vocabulary: `"inferred as the return of 'process'"`, not
`"call return"`.

**AT-RX4.** No Reason construction site in the compiler uses a
bare generic string ("call return", "expected fn") without the
callee/fn name where it's available.

**AT-RX5.** The Why Engine's chain for any type mismatch names the
function, the parameter, and the specific constraint at every node
in the chain.

---

## §6 Scope + peer split

| Peer | Surface | Load |
|---|---|---|
| RX.1 | Audit sweep — grade every Reason site | Light (analysis, no code change) |
| RX.2 | New Reason variants in types.mn + show_reason | Moderate (~20L types.mn) |
| RX.3 | Grade B string enrichment (~15 sites in infer.mn) | Moderate (~30L infer.mn, 1-2L each) |
| RX.4 | Grade C structured variant replacement (~8 sites) | Moderate (~25L infer.mn + graph.mn) |

Total: ~75 lines of changes across ~23 sites. RX.1 is analysis
(this walkthrough IS RX.1); RX.2-RX.4 are mechanical.

---

## §7 Dependencies

- **Upstream:** VK (for PipeKind in `InferredPipeResult`). Without
  VK, the Reason carries a PipeKind that no downstream surface
  renders.
- **Downstream:** EVERY handler projection surface benefits. RX
  is the rising-tide walkthrough: upgrading Reasons improves every
  diagnostic, every hover, every Why chain, every Mentl voice line.
  IR §3 recommends RX at position 3 for exactly this reason.

---

## §8 What RX refuses

- **Inventing new Reason architecture.** The current Reason DAG
  (types.mn:231-251) is sound. The structure works. The problem is
  content, not shape. RX upgrades content within the existing
  architecture.
- **Adding Reasons where none belong.** Not every intermediate
  inference step deserves a Reason — the DAG should capture
  DECISIONS, not every micro-step. The audit grades for "does a
  developer reading this chain learn something?" — if not, the
  Reason is noise.
- **Runtime Reasons.** Reasons are compile-time only. They exist
  in the graph during compilation; they're read by hover/Mentl/audit
  during compilation; they're erased at emit. No runtime cost.

---

## §9 Connection to the kernel

- **Primitive #8** IS this walkthrough. RX completes the Reason
  substrate so every graph node's justification speaks intent.
- **Every other primitive** benefits: Reasons anchor the Why chains
  for effect mismatches (#4), ownership violations (#5), refinement
  failures (#6), gradient suggestions (#7), handler installations
  (#2), and verb topology (#3).
- **Mentl tentacle Why** IS the consumer. The Why Engine walks the
  Reason DAG. When Reasons speak intent, Why speaks intent. When
  Reasons speak mechanism, Why speaks mechanism. RX ensures Why
  always speaks intent.
