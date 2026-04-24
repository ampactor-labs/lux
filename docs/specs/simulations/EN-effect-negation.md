# EN — Effect Negation Substrate

*Walkthrough for primitive #4's intent round-trip. Reframes FV.1 from
"apply `!E` decorations" to "close the gap between what the developer
writes about effect absence and what the substrate understands."*

**Status: 2026-04-22 · seeded post-FV.1 substrate finding.** The original
FV.1 framing (declare `!E` on hot-path fns) proved decorative on
monomorphic closed-row sites because `Closed(A) & !Closed(B)` normalizes
to `Closed(A - B) = Closed(A)` when `B ⊄ A` (effects.nx:150-154). The
real FV.1 is a three-peer substrate cluster closing the intent
round-trip. This walkthrough names the substrate decisions.

---

## §1 Frame

Inka's primitive #4 is the full Boolean effect algebra: `+ - & ! Pure`.
The manifesto claim: `!E` proves ABSENCE, strictly more expressive
than Rust + Haskell + Koka + Austral combined. The README example
case: `!Alloc` proves real-time.

The claim delivers **at the proof level** — a function with a closed
declared row that doesn't list `Alloc` cannot allocate; `row_subsumes`
rejects any body that tries. The DSP real-time guarantee holds.

The claim leaks **at the intent round-trip**. Three specific places
the substrate forgets what the developer meant:

1. **Explicit `!E` is lost at normalization.** The developer writes
   `with Memory + !Alloc` to declare real-time intent; `build_declared_row`
   computes `EfClosed([Memory])` and discards the `!Alloc`. Audit,
   hover, teach, Mentl's capability surfacer read the normalized row;
   they cannot recover the author's intent.
2. **Lone `!E` collapses to `Pure`.** `fn sandboxed(x) with !Network`
   ought to mean "any effects except Network" (universe-minus-Network
   — the capability-security DENY list). Current algebra normalizes
   to `EfPure ∩ !Closed([Network]) = EfPure`, forcing the body to be
   absolutely pure. The security-by-negation stance is unexpressible
   without exhaustive positive enumeration of every allowed effect.
3. **No named capability bundles.** "Real-time" = `!Alloc & !IO & !Network`.
   "Sandboxed" = `!Filesystem & !Network & !Process`. "Compile-time-
   evaluable" = `!IO & !Clock`. These recur; they ARE the capability
   stances developers think in. The language has no way to name them,
   forcing every site to re-list the primitives.

Each gap is a place where the developer's mental model (capability
stance: "real-time," "sandboxed") diverges from the textual form
(positive listing of specific effects). Closing those gaps IS primitive
#7 (continuous annotation gradient) at the effect-row level.

---

## §2 The three gaps, specified

### §2.1 Explicit `!E` lost at normalization

**Trace.** `std/compiler/parser.nx:418-447` builds `effs : List<(EffName, negated: Bool)>` per fn signature. `std/compiler/infer.nx:376-387` (`build_declared_from`) iterates the list and builds an `EffRow` via `union_row` / `inter_row(_, neg_row(_))`. `std/compiler/effects.nx:134-156` (`normalize_inter`) reduces `Closed(A) & !Closed(B)` to `Closed(A - B)` — algebraically correct, but after this reduction the pair `(Name, negated=true)` is no longer recoverable from the normalized row.

**Consequence.** `row_subsumes(body_row, declared_row)` correctly catches violations; that's not the issue. The issue is that downstream consumers — `mentl_voice_default`, `inka audit`, hover-info handlers, capability-report generators — reading the function's effect type get only the normalized row. The `!Alloc` the author typed is gone. The author wrote intent; the substrate kept only effect.

**What's preserved today.** The `FnStmt(name, params, ret_ann, effs, body_node)` AST node at `types.nx` holds `effs` in authored form. It's reachable by traversing the AST. Nothing in the compiler currently threads it through to Mentl / audit / hover handlers.

**What's missing.** An access path. A new query-style effect that reads authored negations by handle: `perform capability_intent(handle) -> List<(EffName, negated: Bool)>`. Or — simpler — the existing `Query` effect surfaces authored `declared_effs` alongside the normalized row.

### §2.2 Lone `!E` collapses to `Pure`

**Trace.** `build_declared_from` starts with `acc = EfPure`. For each entry `(name, negated)`:
- positive: `union_row(acc, Closed([name]))` → grows the set.
- negated: `inter_row(acc, neg_row(Closed([name])))` → intersects with negation.

With no positive entries, `acc` never leaves `EfPure`. Each negated entry does `inter_row(EfPure, _)`; `normalize_inter`'s first rule (`EfPure => EfPure`) short-circuits. Result: `EfPure` regardless of how many negations.

**Intent.** `fn sandboxed(x) with !Network` — "this function forbids Network; anything else is fine." Universe-minus-Network. The row algebra has an explicit form for this: `EfNeg(Closed([Network]))`.

**Consequence.** Capability-security use cases (plugins, untrusted callbacks, sandboxed subprocesses) cannot be expressed as DENY lists. Every such declaration must exhaustively enumerate the ALLOW list — fighting the security philosophy.

**What's missing.** A base-case change: when the declared entries contain negations and no positives (or when the first processed entry is negated), the accumulator should start from an "open universe" rather than `EfPure`.

### §2.3 No named capability bundles

**Trace.** The grammar accepts `with <EffectName> [+ <EffectName> ...]` (parser.nx:418). Each `EffectName` is either `ENamed(String)` or `EParameterized(String, args)`. The parser has no path for "alias that expands to a row expression."

**Intent.** `RealTime = !Alloc & !IO & !Network` — a one-word capability stance that composes the primitive effects into a named capability. `fn process(block) with Memory + RealTime = ...` reads as "this is the real-time process callback," matching the DSP engineer's mental stance.

**Consequence.** Every site that means "real-time" re-types `!Alloc & !IO & !Network`. The mental handle ("real-time") never appears in code; the primitive decomposition does. This is the effect-row analog to writing `[Int, Int, Int]` everywhere instead of declaring `type RGB = (Int, Int, Int)`.

**What's missing.** A new top-level declaration `effect-row <Name> = <row-expr>`, a new `SchemeKind` variant `EffectRowAliasScheme(EffRow)`, parser support, resolution at `build_declared_from` use sites.

---

## §3 Design candidates + Mentl's choice per peer

### §3.1 FV.1.α — Intent preservation

**Candidate A: Query handler reads authored form.** Keep `build_declared_from` unchanged. Expose authored `effs` via a new effect op `perform intent_of(handle) -> List<(EffName, Negated)>` handled by a new `capability_intent_reader` handler that reads from the AST-side store. Downstream consumers (audit, hover, Mentl teach) perform the op.

**Candidate B: Dual-field on the row itself.** Extend `EffRow` with an optional `authored: Option<List<(EffName, Negated)>>` attachment. `build_declared_from` populates it; `row_subsumes` ignores it; consumers read it directly off the row.

**Candidate C: No separate path; require consumers to traverse the AST themselves.** Mentl / audit / hover look at the FnStmt node for `effs` directly.

**Mentl's choice: A.** Handler-effect access matches primitive #2's discipline ("every consumer is a handler"). Candidate B embeds metadata in the row's structural form, fighting normalize_* passes; candidate C scatters traversal code across every consumer. A is one handler, one op, one composable read.

**Load.** Light. New op on the existing `Query` effect (or a new `CapabilityIntent` effect if namespace hygiene matters). One handler arm that reads the AST. No changes to normalize_*, row_subsumes, or inference.

### §3.2 FV.1.γ — Lone `!E` semantics

**Candidate A: Partition entries; adjust base case.** `build_declared_row` splits `effs` into positive and negative lists. Base case:
- positive empty + negative empty → `EfPure`
- positive non-empty + negative any → `Closed(positives)` intersected with each negation in turn (current semantics for this case are correct).
- **positive empty + negative non-empty** → `EfNeg(Closed(negatives))` directly (universe-minus-negatives). This is the new path.

**Candidate B: Peek at first entry.** If first parsed entry is negated, start accumulator with `EfOpen([], fresh_v)` instead of `EfPure`. Subsequent entries compose.

**Candidate C: New explicit syntax.** `with any - Network` or `with *(Network)` or similar — an explicit "universe-minus" form distinct from `!Network`. Keep current `!E` semantics unchanged.

**Mentl's choice: A.** Partition is clean; it separates the "only these" semantics (positives listed) from the "anything except" semantics (negatives only). Candidate B is order-dependent and brittle if someone writes `with !Alloc + Memory`. Candidate C introduces new syntax when `!E` alone is the natural capability-security form — it should just work.

**Load.** Moderate. One function split (`build_declared_row` → `partition_declared` + `build_from_partition`). Verify every `normalize_*` path (`normalize_neg`, `normalize_inter`, `normalize_row`) handles top-level `EfNeg` correctly for subsumption (probably does — `row_subsumes` with `EfNeg` on the right side is well-defined). Verify `show_effrow` renders top-level negation readably.

### §3.3 FV.1.δ — Named capability bundles

**Syntax decision.**

**Candidate A: `effect-row <Name> = <row-expr>`.** New keyword; distinct from `type` and `effect`.
**Candidate B: `type-row <Name> = ...`.** Reuses `type` keyword prefix.
**Candidate C: `capability <Name> = ...`.** Names the concept directly. "Capability" is the noun for what a row stance represents.

**Mentl's choice: C — `capability <Name> = <row-expr>`.** The noun matches the mental model. `effect-row` is technical plumbing; `capability` is what the developer thinks. This aligns primitive #4's surface vocabulary with how the developer speaks about effects ("this function is real-time," "this plugin is sandboxed").

Example declarations:
```
capability Pure       = !IO & !Alloc & !Mutate & !Network & !Filesystem & !Clock & !Diagnostic
capability RealTime   = !Alloc & !IO & !Network
capability Sandboxed  = !Filesystem & !Network & !Process
capability Offline    = !IO & !Clock
```

Example use:
```
fn process(block) with Memory + RealTime  = ...
fn plugin(input)  with Sandboxed          = ...
```

**Env + resolution.**

**Candidate A: New SchemeKind variant `CapabilityScheme(EffRow)`.** env_extend installs; `parse_one_effect` resolves at parse time (looks up by name; if capability, returns its row expression; if effect, current path).

**Candidate B: New SchemeKind but late-resolution at infer time.** Keep parser pure; resolve when `build_declared_from` encounters the name.

**Mentl's choice: B.** Parser stays pure (syntactic only); semantic resolution at infer time matches the rest of the compiler's separation. `build_declared_from` becomes: for each entry, look up name → effect (single), capability (splice in), or unknown (emit `E_UnknownEffect`).

**Load.** Moderate-heavy. New top-level decl syntax (parser.nx). New SchemeKind variant (types.nx). New resolution branch in `build_declared_from` (infer.nx). `cache.nx` serialization of `CapabilityScheme`. `show_scheme` support.

**Interaction with FV.1.γ.** A `capability` declaration whose body is pure-negation (e.g. `capability RealTime = !Alloc & !IO & !Network`) resolves to an `EfNeg` or `EfInter(EfNeg, EfNeg, ...)` form. When spliced into a call site's declared row via `build_declared_from`, it composes the same way authored negations do. FV.1.γ must land before FV.1.δ — if lone `!E` still collapses to `Pure`, `capability Sandboxed = !Network & !Filesystem` would resolve to `EfPure` before splicing, breaking the capability.

### §3.4 FV.1.β — Polymorphic applied exemplar

**Candidate sites** (after α + γ + δ land):

- **`fn realtime_map(f: fn(A) -> B with E + !Alloc, xs)`** in a new `std/realtime.nx` module — explicit DSP combinator that restricts callbacks. Doesn't touch prelude.
- **`fn map(f, xs)` in prelude.nx** — adding `!Diagnostic` to callback rows would restrict what callers can pass. High risk, high value: maps that never propagate reporting.
- **Handler-constraint on installed handlers.** `fn pipeline(source, handlers: List<Handler with !Mutate + v>)` — handler chains that provably don't mutate declared state.

**Mentl's choice: new `std/realtime.nx` module.** Lowest-risk, highest-exemplar-clarity. Prelude stays general-purpose; realtime ops are a focused capability-typed library. The exemplar lives in a module whose existence proves primitive #4's polymorphic expressive power.

**Load.** Light-moderate, post-α+γ+δ. One module (~50-80 lines). Shows named capabilities + lone `!E` + polymorphic narrowing composing end-to-end.

---

## §4 Layer-by-layer trace

### §4.1 Parser (parser.nx)

**α:** No change. Parser already emits `effs` in authored form.

**γ:** No change. Parser already distinguishes positive/negative entries.

**δ:** Add `parse_capability_decl`. New top-level statement kind `CapabilityDeclStmt(name: String, row: RowExpr)`. Grammar: `capability <Ident> = <row-expr>` where `<row-expr>` parses with the existing `parse_effect_list` (extended to accept `&` in addition to `+`).

Wait — current syntax is `+` for effect composition in fn declarations. For capability declarations, the body is a row expression with all Boolean operators. Decision: reuse `parse_effect_list` but allow the body to use `&` as intersection. Simplest: desugar at capability-decl parse time — `A & B` becomes `A + B` (union for positive, intersection-with-negation for negated entries is already the form).

Actually — `RealTime = !Alloc & !IO & !Network` — this is `!Alloc ∩ !IO ∩ !Network`, which per De Morgan = `!(Alloc + IO + Network)`. So it's the negation of a union. Grammar: accept `!A & !B & !C` as syntactic sugar for `!(A + B + C)`. Parser flattens.

### §4.2 Types / Schemes (types.nx)

**α:** No change to `EffRow`. Authored `effs` lives on the FnStmt AST node as today.

**γ:** No change.

**δ:** Add SchemeKind variant `CapabilityScheme(EffRow)`. `show_scheme` arm added.

### §4.3 Inference (infer.nx)

**α:** Add a query handler op `capability_intent(handle) -> List<(EffName, Negated)>`. Wire to the AST via an existing AST-side handler (TBD — may already exist as part of `Query`).

**γ:** Refactor `build_declared_from` into `partition_declared` + `build_from_partition`. The new `build_from_partition` handles the three cases explicitly:
```
build_from_partition(pos, neg) =
  if len(pos) == 0 && len(neg) == 0 { EfPure }
  else if len(pos) == 0             { neg_row(Closed(neg)) }      // universe-minus-negs
  else {
    let base = Closed(pos)
    fold(neg, base, (acc, n) => inter_row(acc, neg_row(Closed([n]))))
  }
```
(Pseudocode; real implementation uses Inka verbs.)

**δ:** `build_declared_from` gains a resolution step per entry:
```
resolve_entry(name) = match env_lookup(name) {
  Some(Forall(_, _), _, EffectScheme)        => Effect([name])
  Some(Forall(_, _), _, CapabilityScheme(r)) => Capability(r)
  None                                       => emit E_UnknownEffect; Effect([name])
}
```
Entry handling splices capabilities into the partition. Negation of a capability: De Morgan via `neg_row`.

### §4.4 Backends / emit (wasm.nx)

No change. Effect rows are compile-time only; emitter works from the lowered IR.

### §4.5 Mentl / audit / hover handlers (mentl.nx, future audit.nx)

**α:** New handler `capability_intent_reader` reads authored `effs`. Mentl's `teach` arm queries it when surfacing capability stances.

**δ:** Mentl's capability surfacer matches resolved `declared_row` against known `CapabilityScheme` bundles in env; when the row equals a capability's row, Mentl surfaces the capability name (`"real-time"`) rather than the raw negation list. This is the round-trip closed: author writes `with RealTime` → substrate knows the row → Mentl says "real-time" in hover.

### §4.6 Cache (cache.nx)

**δ:** `cache_show_kind` + `cache_parse_kind` gain a `CapabilityScheme` case. Serialized form: `"CAP:" ++ show_effrow(row)`. Deserialization parses the row string.

---

## §5 Dependencies + ordering

```
FV.1.α  (intent preservation)    — standalone; light; Mentl-facing.
FV.1.γ  (lone !E semantics)      — standalone; moderate; substrate.
FV.1.δ  (named capability decl)  — depends on γ. Moderate-heavy; substrate.
FV.1.β  (polymorphic exemplar)   — depends on γ+δ. Light; applied.
MV.2.capability-surfacing        — depends on α+δ. Voice-layer.
```

**Landing order:**
1. α (light; land first; unblocks Mentl / audit immediate consumers).
2. γ (must precede δ; substrate-level base-case fix).
3. δ (biggest lift; requires γ for capabilities with pure-negation bodies).
4. β (applied exemplar; lands in a new module).
5. MV.2.capability-surfacing (post-MV.2 main landing; uses α+δ).

Each of α, γ, δ is its own commit with its own `H*.*` or `FV.1.*` handle per PLAN.md's peer sub-handle discipline.

---

## §6 Acceptance tests (per peer)

### FV.1.α acceptance

**AT1.** Given `fn f(x) with Memory + !Alloc = ...`, `perform capability_intent(handle_of_f)` returns `[("Memory", false), ("Alloc", true)]`.

**AT2.** After inference normalizes the row to `Closed([Memory])`, AT1 still returns the authored form. Normalization is not read through this handler.

**AT3.** Hover on `f` (future LSP handler) displays both the normalized row ("Memory") and the authored intent ("!Alloc").

### FV.1.γ acceptance

**AT4.** `fn f(x) with !Network = x` type-checks iff `f`'s body truly does not perform `Network`. Body `let _ = perform network_op(...); x` fails with E_EffectMismatch.

**AT5.** `show_effrow(declared_row_of_f)` renders as `!Network` (or `any - Network`), not as `Pure`.

**AT6.** `with !A + !B` parses and normalizes to `!(A + B)` per De Morgan.

### FV.1.δ acceptance

**AT7.** Top-level `capability RealTime = !Alloc & !IO & !Network` is accepted by the parser and installed in the env as `CapabilityScheme`.

**AT8.** `fn process(block) with Memory + RealTime = ...` resolves at infer time; body must satisfy the expanded row (Memory, no Alloc, no IO, no Network).

**AT9.** A body that allocates is rejected with E_EffectMismatch pointing at both the violated negation and the capability name (e.g., `"body allocates, but 'RealTime' forbids Alloc"`).

**AT10.** Caching round-trips a `CapabilityScheme` through `cache_show_kind` / `cache_parse_kind` preserving row structure.

### FV.1.β acceptance

**AT11.** `fn realtime_map(f: fn(A) -> B with E + !Alloc, xs)` accepts an `f` with row `Memory` but rejects an `f` with row `Memory + Alloc`.

**AT12.** The rejection's error message names the `!Alloc` constraint and the offending effect.

### MV.2.capability-surfacing acceptance

**AT13.** Hover on `fn process(block) with Memory + RealTime` shows Mentl's voice line: `"real-time process — allowed: Memory; forbidden: Alloc, IO, Network."`

**AT14.** Audit on a binary reachable from `fn process` includes the capability stance in the per-fn audit row.

---

## §7 Scope estimation

| Peer | Parser | Types | Infer | Emit | Mentl | Cache | Tests |
|---|---|---|---|---|---|---|---|
| α | — | — | ~20L | — | ~30L | — | AT1-3 |
| γ | — | — | ~40L | — | — | — | AT4-6 |
| δ | ~50L | ~15L | ~60L | — | — | ~20L | AT7-10 |
| β | — | — | — | — | — | — | AT11-12 + new std/realtime.nx ~80L |
| MV.2.cap | — | — | — | — | ~60L | — | AT13-14 |

Total: ~375 lines compiler-side. Spread across 4 peer commits. Each
peer lands with its own walkthrough addendum if substrate assumptions
shift between commits.

---

## §8 What this walkthrough refuses

- **Decorative `!E` on closed-row monomorphic sites.** The original FV.1
  framing. Absorbed into "closed-row-ness IS the negation" — documented
  in the FV.1 substrate finding in PLAN.md Pending Work item 25.
- **Per-site `!E` sweeps without first closing the intent round-trip.**
  If authored `!E` is lost at normalization, sweeping it across the
  compiler doesn't land substrate; it lands artifacts.
- **Capability declarations without the lone-`!E` fix (γ).** A
  `capability Sandboxed = !Network & !Filesystem` collapses to Pure if
  γ isn't in. δ without γ is broken.
- **Silencing the substrate tension.** The gap between intent and
  machine is real; current substrate partly closes it. The honest
  move is naming the close as substrate work, not as "apply the
  annotation and trust the notation sugar."

---

## §9 Connection to the eight-primitive kernel

- **Primitive #4 (Boolean effect algebra).** EN completes primitive #4's
  intent round-trip. Current: algebraic proof delivered, intent dropped.
  Post-EN: algebra + intent + named capability + polymorphic narrowing,
  all first-class.
- **Primitive #7 (continuous annotation gradient).** Named capabilities
  (δ) ARE gradient steps — one annotation unlocks the corresponding
  capability claim in hover, audit, and downstream handlers.
- **Primitive #8 (HM inference with Reasons).** Capability mismatches
  (AT9) emit a Reason edge naming the violated capability and the
  specific `!E` constraint — inference's error surface gains the
  capability vocabulary developers think in.
- **Mentl tentacles.** Tentacle Teach reads resolved rows and surfaces
  capability stances (MV.2.cap). Tentacle Verify discharges the
  polymorphic narrowing proofs (FV.1.β). Tentacle Why walks capability-
  mismatch reason edges (primitive #8 integration).

---

## §10 Residue

The developer writes "real-time"; the substrate understands "real-time";
the voice says "real-time." One word, one meaning, one capability,
one round-trip. **This is the gap between intent and machine, closed
at primitive #4's surface.**

*The medium Inka speaks of must be the medium Inka is.*
