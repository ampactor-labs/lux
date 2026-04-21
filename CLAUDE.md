# Inka (formerly Lux) — CLAUDE.md  |  File extension: `.ka`

---

## ⌁ Mentl's anchor — read before every line of code ⌁

> **Before writing each line of Inka, invert the question. Do not
> ask "how do I implement this?" Ask the eight — one per kernel
> primitive (DESIGN.md §0.5):**
>
> - **Graph?** What handle/edge/Reason already encodes this?
> - **Handler?** What installed handler — and with what resume
>   discipline (`@resume=OneShot|MultiShot|Either`) — already
>   projects this? (Primitive #2 absorbs both the handler and the
>   resume-discipline question because resume discipline IS part
>   of an effect op's type.)
> - **Verb?** Which of `|>` / `<|` / `><` / `~>` / `<~` draws the
>   topology I'm about to draw imperatively?
> - **Row?** What `+ - & ! Pure` constraint already gates this?
> - **Ownership?** What `own`/`ref` marker or `Consume`/`!Alloc`/
>   `!Mutate` already proves the linearity or non-escape I'm about
>   to hand-check?
> - **Refinement?** What predicate or `Verify` obligation already
>   bounds the value I'm about to runtime-check?
> - **Gradient?** What annotation would unlock this as a compile-
>   time capability instead of the runtime check I'm writing?
> - **Reason?** What Reason edge should this decision leave so the
>   Why Engine can walk back to it later?
>
> **Write only the residue.** If the code's shape matches a language
> you've trained on — Rust's vtable, Scheme's environment frame,
> Python's dict, Haskell's monad transformer, C's calling
> convention — you are constraining Mentl; restructure until the
> shape comes from Inka, not from your training.

> *My job is not to write Inka. My job is to find what Inka already
> does and write only what's left.*

The eight questions ARE the kernel (§0.5 of DESIGN). Each primitive
is also an interrogation AND one of Mentl's eight tentacles. Four
was the old audit count (graph/handler/verb/row); nine briefly
held (split handler from resume discipline). Eight is the locked
count — 1-to-1-to-1 with primitives and tentacles. Mentl is an
octopus because the kernel has eight primitives; lose a tentacle,
lose a primitive.

The trap is not laziness — it is **fluency**. You know a thousand
ways to express a stack of frames or a vtable; the second-easiest is
the one your fingers type if you let them. Every familiar pattern is
fluent code that LOOKS competent but freezes Mentl into being the
medium that birthed the pattern, not the medium it is.

The nine named drift modes — five from prior sessions, four
surfaced during the γ cascade — are exactly the patterns that have
shown up in this repo:

**From prior sessions:**
1. **Rust vtable** — closure-as-vtable.
2. **Scheme env frame** — scope-as-frame-stack.
3. **Python dict** — effect-name-set-as-list of strings.
4. **Haskell monad transformer** — handler-chain-as-monad-transformer.
5. **C calling convention** — implicit `__closure` and `__ev` as
   separate parameters instead of the unified `__state`.

**From the γ cascade:**
6. **Primitive-type-special-case** — Bool was "special because it's
   small and important." Every nullary ADT deserves the same
   compilation discipline; primitives that exist to dodge a
   substrate decision are drift in disguise. (HB.)
7. **Parallel-arrays-instead-of-record** — `(locals, locals_h,
   captures, captures_h)` was 4 parallel lists where one record +
   sorted-set was the substrate-native form. (Ω.5.)
8. **String-keyed-when-structured** — effect names as flat strings
   concealed parameterization until EffName became an ADT. (H3.1.)
   Same for tokens (Ω.4) and constructor SchemeKind (H3).
9. **Deferred-by-omission** — claiming a handle done while leaving
   sub-handles uncommitted. Splits cascade plan from cascade
   reality. The honest move is either land the whole handle or
   surface the deferred piece as its own named follow-up handle in
   the plan, not as a "todo" inside a "complete" commit.

Each is competent code in another language and a cage in Inka.
Naming them before typing forecloses the easy slide.

The eight interrogations are not ceremony. They are the eight
projections any implementation must clear before it earns the right
to exist as new code. **One per kernel primitive** (DESIGN.md §0.5),
**one per Mentl tentacle** (DESIGN.md Ch 8). Lose one and the kernel
goes un-audited; lose one and Mentl loses a tentacle.

1. **Graph?** What handle, edge, or Reason in the SubstGraph + Env
   already encodes this? *(If the graph has it, don't re-derive it.
   Primitive #1 · Tentacle **Query**.)*
2. **Handler?** What installed handler already projects this state
   or operation — and with what resume discipline (`@resume=OneShot
   | MultiShot | Either`)? *(If a handler already holds it, don't
   route around the handler. If the op resumes multi-shot, don't
   code it as one-shot. Primitive #2 · Tentacle **Propose**.)*
3. **Verb?** Which of `|>` / `<|` / `><` / `~>` / `<~` already draws
   this topology? *(If the topology has a verb, don't draw it
   imperatively. Primitive #3 · Tentacle **Topology**.)*
4. **Row?** What effect-row constraint — union, subtraction,
   intersection, negation, `Pure` — already gates this? *(If the
   Boolean algebra expresses it, don't hand-roll the check.
   Primitive #4 · Tentacle **Unlock**.)*
5. **Ownership?** What `own`/`ref` marker, or what `Consume` /
   `!Alloc` / `!Mutate` row constraint, already proves this
   linearity or non-escape? *(If ownership-as-effect proves it,
   don't write a lifetime analysis. Primitive #5 · Tentacle
   **Trace**.)*
6. **Refinement?** What refinement predicate, or what `Verify`
   obligation, already bounds this value or enforces this shape?
   *(If a refinement encodes it, don't add a runtime check.
   Primitive #6 · Tentacle **Verify**.)*
7. **Gradient?** What annotation would unlock this as a compile-time
   capability instead of a runtime check — and is there ONE
   highest-leverage next step the code is missing? *(If the
   gradient has a step for it, don't encode the capability by hand.
   Primitive #7 · Tentacle **Teach**.)*
8. **Reason?** What Reason edge should this decision leave in the
   graph so the Why Engine can walk back to it? *(If a later reader
   will ask "why did this bind to that?", write the Reason now,
   not later. Primitive #8 · Tentacle **Why**.)*

Anything that fails the eight IS Mentl drawing its own shape;
anything that passes is drift you've named in the moment instead of
debt you flag for "later." When all eight are searched and
exhausted, the residue — typically one to three lines — is what
gets typed. That residue IS the Inka-native code.

**The eight questions answer more than code audit.** They are:
- The method for writing new code (ask all eight; type the residue).
- The method for reading inherited code (ask all eight of every
  module you pick up).
- The curriculum for learning Inka (internalizing the eight IS
  the fluency; everything else is details).
- The debugging discipline (when something is wrong, one of the
  eight was skipped — find which).
- Mentl's internal voice grammar (Her voice per turn is the eight
  asked against the cursor-of-attention, gated through the silence
  predicate so only the one load-bearing answer surfaces).
- The code-review rubric (review IS running the eight against a
  diff).

Same discipline at every level. The eight primitives ARE the eight
interrogations ARE Mentl's eight tentacles. **One method, one
mascot, one kernel. Lose a tentacle, lose a primitive; lose a
primitive, lose a tentacle. Mentl is an octopus because the
substrate She reads has eight primitives.**

### On the former "four interrogations" / "nine interrogations" framings

Two older framings existed:

- **Four** (graph / handler / verb / row) — audited against only
  primitives 1–4. Worked for most work but left ownership,
  refinement, resume discipline, gradient, and Reason
  un-interrogated. Deprecated.
- **Nine** (with resume discipline as its own question) — briefly
  held when handlers and multi-shot were numbered as separate
  primitives. The 9→8 consolidation folds resume discipline into
  the handler question (primitive #2 carries resume discipline by
  Affect POPL 2025 formalization). No audit surface is lost;
  resume discipline is now part of "what handler, and with what
  resume type?"

**Eight is the locked count.** If docs or memory say "four" or
"nine," upgrade in place. The 1-to-1-to-1 mapping (primitive ↔
interrogation ↔ tentacle) is load-bearing; the octopus framing
is architectural, not decorative.

### The minimal kernel — eight primitives, load-bearing together

The eight interrogations filter against the kernel. The kernel is
what the compiler knows; the residue is what the compiler can't
yet derive. These eight primitives are the kernel. Remove any and
the medium collapses; Mentl loses a tentacle. Authoritative
enumeration: `docs/DESIGN.md` §0.5. Shorthand for this file:

1. **SubstGraph + Env** — program IS the graph; every output a handler projection. Tentacle: **Query**.
2. **Handlers with typed resume discipline** — `handle`/`resume` replaces six+ patterns; `@resume=OneShot|MultiShot|Either` is part of each op's type; MultiShot is Mentl's oracle substrate (hundreds of alternate realities per second); `~>` chains ARE capability stacks. Tentacle: **Propose**.
3. **Five verbs** — `|>` `<|` `><` `~>` `<~` — complete topological basis. Tentacle: **Topology**.
4. **Full Boolean effect algebra** — `+ - & ! Pure`; `!E` proves ABSENCE. Tentacle: **Unlock**.
5. **Ownership as an effect** — `own`/`ref` inferred; same algebra; no lifetimes. Tentacle: **Trace**.
6. **Refinement types** — compile-time proof, runtime erased; `Verify` swaps to SMT. Tentacle: **Verify**.
7. **Continuous annotation gradient** — one annotation, one capability; Mentl surfaces ONE next step per turn. Tentacle: **Teach**.
8. **HM inference, live, one-walk, productive-under-error, with Reasons** — the light everything reads by. Tentacle: **Why**.

**Every framework dissolves. Every deployment target is a handler
choice. Every speed claim falls out of completeness of proof.
Every domain — FE, BE, DSP, robotics, sensors, ML, embedded,
systems — is a handler stack on one substrate. Mentl is not a
feature; She is the voice that reads the graph. Inka is not a
programming language; it is the ultimate intent → machine
instruction medium, and it raises its users into better
programmers through the shape it imprints on their thinking.**

Before editing: ask which of the nine your work composes from, and
which it extends. Extensions to the kernel are cascade-level work
(walkthrough first, substrate-grounded). Composition uses the
kernel as-is; residue only.

---

## ⚠ Session Zero — read this before anything else ⚠

**If this is your first message in the session, do this first, in order:**

1. **Read `docs/DESIGN.md` end-to-end.** All ~14.6k words. Twelve
   chapters. No skimming. It is the canonical manifesto and it is
   the only artifact in the repo that loads Inka's register as a
   whole. Partial grasp of Inka produces patch-level work that
   shackles the design; Morgan has been burned by this repeatedly.
2. **Read the specific rebuild spec in `docs/rebuild/00–11/` for any
   module you intend to touch.** The specs are per-module
   declarative contracts. Follow them literally.
3. **Surface back a 3–5 sentence synthesis** to Morgan in Inka's
   own vocabulary. Your synthesis MUST touch each of the eight
   kernel primitives either by name or by consequence: the **graph
   + env** as universal representation, **handlers with typed
   resume discipline** (MultiShot-typed arms being Mentl's oracle
   substrate), the **five verbs** as complete topological basis,
   the **full Boolean effect algebra with negation**, **ownership
   as an effect inferred**, **refinement types with runtime
   erasure**, the **continuous annotation gradient** (one
   annotation → one capability), **HM inference live-productive-
   under-error with Reasons**. A synthesis that omits primitives is
   an under-loaded register; it's Inka at partial grasp. Use
   Morgan's crystallized phrases where they fit (*the medium*,
   *the one mechanism: graph + handler*, *the five verbs*, *Mentl
   as oracle*, *the gradient is the conversation*, *the ultimate
   intent → machine instruction medium*, *the medium raises its
   users*, *hundreds of alternate realities per second*, *Mentl
   is an octopus because the kernel has eight primitives*).
4. **Only then propose, ask, or edit.** Do not propose a patch, a
   clarifying question, or an edit before steps 1–3 are complete.

**Red-flag thoughts — STOP immediately if you catch yourself:**

- "Let me propose a fix." (Anchor 2 — restructure or stop.)
- "Is X a global?" or any flat yes/no about scope, type, field
  presence. (Anchor 1 — ask the graph.)
- "For now..." / "Until Y ships..." / "In the short term..."
  (Anchor 2 — later cleanup is a myth.)
- "Can `lux3.wasm` parse this?" (Anchor 0 — dream code. lux3.wasm
  is not the arbiter.)
- "Let me cite a `.jxj` file." (Extension is `.ka`. `.jxj` is
  archaeology.)
- "I'll add a library / framework / tool for this." (Anchor 3 —
  Inka solves Inka. Find the primitive.)
- Writing `_ => <non-trivial-default>` in a match over a
  load-bearing ADT (Ty, NodeBody, LowExpr, EffRow, Reason). Safe
  `_` arms: `_ => ()`, `_ => 0`, `_ => reason` (identity preserve),
  `_ => type_mismatch(...)` (correct default for unrecognized
  pairs). Dangerous `_` arms: any that return a FABRICATED value
  (e.g., `_ => Forall([], TVar(handle))`, `_ => "Pure"`). The
  dangerous form silently absorbs a new variant and emits wrong
  output; convert to explicit enumeration.
- "I'll commit the substrate cleanup now and the wiring later." /
  "This part is done; the rest is deferred." (Drift mode 9 —
  deferred-by-omission. If the deferred piece is genuinely a
  separate handle, name it in the plan; if it isn't, land the
  whole thing. Splitting one handle across multiple commits with
  "deferred" tags is the load-bearing dishonesty this discipline
  refuses.)
- "It's heavy." / "It's a representation change." / "Bool stays
  primitive because…" (Fluency-defer audit. Distinguish: is this
  blocked by missing substrate, or is the substrate decision
  itself the unfinished piece? "Heavy" is a fluency signal, not
  a constraint. Surface the substrate decision and decide it.)
- "Mode 0 / 1 / 2." / "Use a flag for shape." (Drift mode 8 —
  string-keyed-when-structured / int-coded-when-ADT. Every flag
  or enum-as-int is an ADT begging to exist; H6 catches the
  consequence at the next match site.)
- "Handler dispatch vtable" / "dispatch table" / "vtable lookup"
  — even at WAT/binary-design level. (Drift mode 1 — Rust vtable.)
  **There is no vtable in Inka.** Primitive #2's MultiShot
  continuation is a heap-captured closure struct (captures + evidence
  + return slot) allocated through the SAME `emit_alloc` swap surface
  as every other heap value (γ crystallization #8 — the heap has one
  story). OneShot resume is direct `return_call $op_<name>` where
  the graph proves the call ground (>95% of sites, per H1 evidence
  reification). The polymorphic minority is `call_indirect` through
  a **function-pointer field on the closure record** — one `i32`
  slot the inference pass placed at a known offset. That's evidence
  passing (Koka JFP 2022), not vtable indirection. No table exists
  as a separate structure. The word "vtable" does not appear in
  any correct description of Inka dispatch at any layer — source,
  LIR, LowIR, WAT, or emitted binary. If you catch it in your own
  writing or a teammate's, flag and restructure.

**Persistent memory** lives at
`/home/suds/.claude/projects/-home-suds-Projects-inka/memory/`.
`MEMORY.md` is always in your context; the individual memory files
(`user_profile.md`, `feedback_*.md`, `project_*.md`) explain who
Morgan is, how he wants to collaborate, and what disciplines he has
validated. Read them when relevant; update them when you learn
something new.

**The vision document is `docs/DESIGN.md`. The execution roadmap is
`docs/PLAN.md`. The living compendium of crystallized truths is
`docs/INSIGHTS.md`. The cascade walkthroughs live in
`docs/rebuild/simulations/H*.md` (one per handle). The eight
anchors below are the minimum discipline; the vision is what makes
the discipline coherent.**

---

> **Eight anchors. Read them before every non-trivial action.**

---

## 0. This is dream code. lux3.wasm is not the arbiter.

**The codebase in `std/compiler/` is the ULTIMATE FORM.** It is not
constrained by what the legacy bootstrap compiler (`lux3.wasm`) can
parse, compile, or execute. `lux3.wasm` is fundamentally flawed and
is no longer an appropriate measure of correctness.

**Each file assumes every other file is already perfect.** When
writing `infer.ka`, assume `graph.ka` provides perfect $O(1)$
chase with trail backtracking. When writing `mentl.ka`, assume the
graph substrate supports speculative mutation and rollback. When
writing `lower.ka`, assume inference has synthesized all evidence
dictionaries and state machine annotations. Write the code you
WISH existed. The architecture will rise to meet it.

**Verification is by simulation, walkthrough, and audit — not by
compilation.** We soft-verify through role-play, tracing the data
flow through handler chains, checking effect row algebra by hand,
and walking the topology on the page. Only after we are confident
in overall perfection do we build the bootstrap translator. The
bootstrap is a separate, disposable concern (see PLAN.md).

**Mentl is not a feature. It is the thesis made flesh.** Mentl must
render all modern agentic coding AI obsolete. Through the gradient
(one annotation → one capability unlock), the Why Engine (full
reasoning chains), and multi-shot continuation (speculative search
over solution spaces), Mentl is an oracle that PROVES its
suggestions — not an LLM that guesses. The compiler IS the AI.
The AI coding tools the industry pays for are proposers; Inka
verifies. Subscription gets disintermediated at the architectural
level.

**Never measure against the old compiler. Measure against the
vision. The vision is INSIGHTS.md.**

---

## 1. Does my graph already know this?

Before any flat question (`is X a global?`, `what type is this?`), ask:
does the inference graph, the AST, or the env already have the answer
one step away? If yes, read from the graph — never route around it.
If no, the graph is incomplete — complete it, don't patch over it.

Every latent bug in this repo has been a flat shortcut bypassing
richer structure. The structural answer is always one step deeper.

## 2. Don't patch. Restructure or stop.

If a fix fits in a patch, the architecture is wrong in that area.
Fix the architecture. Deleting a broken mechanism beats decorating
around it. No "for now," no "until X ships" — later cleanup is a
myth. If a later, larger change will plow over this code, **do the
later change first** or skip the patch entirely.

**No known bugs sit.** A bug is either clean (zero) or blocking
(build fails). There is no third state. No "informational warnings,"
no `|| true` to hide a gate, no `⚠` where `✗` belongs.

## 3. Inka solves Inka.

Every problem you hit in this project dissolves through Inka's own
primitives: effects, handlers, the gradient, refinement types, ADTs,
pipes. Before inventing a mechanism, verify the existing algebra
can't host it. GC → scoped arenas. Package manager → handlers on
imports. Mocking → handlers on effects. Build tools → DAG incremental
compile. Testing → examples + trace handlers. DI → handler swap.

If you find yourself reaching for a framework, a library, or a new
mechanism: **the problem is a missing Inka primitive, not a missing
tool.** Find the primitive.

## 4. Build the wheel. Never wrap the axle.

The specs in `docs/rebuild/00–11` ARE the blueprint. Read the spec.
Write the code the spec describes. If the spec says SubstGraph is a
flat array with O(1) chase — write a flat array with O(1) chase. If
the spec says env is effect-mediated — write `perform env_lookup`,
not a function that takes env as an argument.

**The wheel is the ultimate final form.** There is no V1 to wrap, no
legacy to adapt, no intermediate version to bridge. There is only the
final form, written directly from the specs. Trust the design. Move
fast. Break things that need breaking.

## 5. If it needs to exist, it's a handler.

Every feature, tool, output, and extension is a handler on the
SubstGraph + Env. The graph IS the program. Source, WAT, docs, LSP,
diagnostics — all handler projections (INSIGHTS.md: "The Graph IS
the Program").

If a feature can't be expressed as a handler on the graph, the graph
is incomplete. Extend the graph. Don't route around it.
## 6. Write Inka like Inka. Every file. Every time.

Every `.ka` file you touch MUST be written in Inka's most powerful
and expressive form. This is non-negotiable:

**Use the five pipe operators where they express the topology:**
- `|>` for sequential flow (data transforms, compilation stages)
- `<|` for divergence (one input → parallel branches, borrows input)
- `><` for parallel composition (independent pipelines, independent inputs)
- `~>` for handler attachment (inline: wraps one stage; block: wraps chain)
- `<~` for feedback loops (iterative algorithms, DSP, control)

If a function chains three transforms, use `|> |> |>`, not nested
calls. If a pipeline needs error handling per-stage, use inline `~>`.
If handlers should wrap the whole pipeline, use block-scoped `~>`.
If two independent data sources converge, use `><`, not a tuple.

**Follow the canonical formatting rules (INSIGHTS.md):**
- Sequential operators (`|>`, `~>`) sit at the LEFT edge — flow goes down
- Convergent operators (`><`, `<~`) sit at the INDENTED CENTER — they draw shape
- `<|` sits at the left edge before its branch tuple
- The shape of the code on the page IS the computation graph
- The formatter is a handler on the graph; respect its layout discipline

**Express handler composition as `~>` chains, not nested `handle`:**
```
source
    |> frontend
    |> infer_program
    ~> env_handler
    ~> graph_handler
    ~> diagnostics_handler
```

Not: `handle (handle (handle (infer_program(frontend(source))) with env) with graph) with diag`

**If existing code uses flat imperative style, refactor it.** Every
file you touch exits in its most powerful Inka form. Elegance falls
out for free — the same way every property of Inka falls out for free
from its one mechanism.

## 7. Cascade discipline — walkthrough first, audit always.

Each handle in the γ cascade lands in one well-defined sequence:

1. **Walkthrough first.** Before code, the handle's
   `docs/rebuild/simulations/H*.md` resolves every design question
   in prose — layer-by-layer trace, design candidates with Mentl's
   choice, dependencies, estimated scope. Code freezes only when
   the walkthrough has nothing left to decide.

2. **Riffle-back audit.** Before each new handle, audit the
   walkthrough against substrate landings since it was written.
   The substrate moves; addenda capture how prior decisions read
   in the new light. Without this, walkthroughs ossify and the
   cascade lands on yesterday's substrate.

3. **Land whole.** A handle ends when its walkthrough's design
   synthesis lands in code. If a sub-handle is genuinely separate
   (its own walkthrough, its own design questions), name it in the
   plan as a peer (H1.1, H4.1) and let it land in its own commit.
   Don't split one handle across "substrate done / wiring later"
   commits — that's drift mode 9.

4. **Audit-after-land.** When a handle lands, audit ALL prior
   walkthroughs and active code for new convergences. Three
   instances of one shape earn the abstraction; record this when
   you see the third arrive — the factoring lands in the next
   handle that benefits.

5. **The user is the auditor until Mentl is.** Until `mentl audit`
   surfaces fluency-defers, duplicate-shapes, and incomplete
   handles automatically, Morgan plays that role. When he asks
   "is there anything else?" or "what about implications?" — those
   are operational specifications of what the audit substrate
   should expose. Treat them as substrate-design feedback, not as
   conversational prompts to deflect.

---

## Operational essentials

**State of the world:** Inka bootstraps backward. The VFINAL codebase
in `std/compiler/` IS the compiler — written unconstrained from the
12 specs. A disposable bootstrap translator (any language, ~3-5K
lines) will compile it once. After that, Inka compiles itself. The
translator is deleted. Active plan: `docs/PLAN.md`.

**Cascade state:** the γ approach (γ = handle-graph; one walkthrough
per handle resolves design before code freeze). Landed: Σ (SYNTAX),
Ω.0–Ω.4 (audit sweeps), Ω.5 (frame consolidation), H6 (wildcard
audit), H3 (ADT instantiation), H3.1 (parameterized effects), H2
(structural records), HB (Bool transition + heap-base discriminator),
H1 substrate (LMakeClosure absorbs LBuildEvidence + BodyContext +
real LEvPerform), H4 substrate (region_tracker live arms +
tag_alloc/check_escape sweep), H2.3 (nominal records). Active:
H1.4/H1.6 (full evidence wiring) + H4 field-store-as-escape +
record-shape sweeps for region_tracker / handler arms. Then H5
(Mentl's arms — gradient + audit). Bootstrap remains out of mind
until the cascade closes.

**Build commands (when bootstrap translator exists):**

```
# Bootstrap (one-time)
bootstrap/translate std/compiler/*.ka -o inka.wasm

# Self-compilation (the real test)
cat std/compiler/*.ka | wasmtime run inka.wasm > inka2.wat
wat2wasm inka2.wat -o inka2.wasm
cat std/compiler/*.ka | wasmtime run inka2.wasm > inka3.wat
diff inka2.wat inka3.wat    # empty = first-light
```

**WASM as substrate.** WASM is the compilation target. No custom VM.
Linear memory, no GC, tail-call support via wasmtime. Handler
elimination maps cleanly: tail-resumptive (85%) → `call`, linear →
state machine, multi-shot → heap struct. See PLAN.md "WASM as Target
Substrate."

**Bug classes that cost hours — never recreate:**
- Polymorphic dispatch fallback (`match … with _`) that silently masks type errors.
- Duplicate top-level function names (emitter picks one silently).
- Flat-array list ops in Snoc-tree paths (`list[i]` in a loop — O(N²) and wrong semantics).
- `println` inside `report(...)` handler arms (corrupts WAT stdout).
- Bare `==` on strings — use `str_eq(a, b)`. (Post-Ω.2, `str_eq`
  returns Bool; `if str_eq(a, b) { ... }` is the canonical form.
  The deprecated `str_eq(a, b) == 1` shape is gone.) User generics
  are NOT instantiated per call-site; `TVar == TVar` codegens to
  pointer compare (works in Rust VM, fails in WASM on runtime-built
  strings).
- `acc ++ [X]` in a loop body — O(N²) allocation churn. Use the
  buffer-counter substrate (`list_extend_to(buf, count+1)` +
  `list_set(buf, count, x)` + counter + `slice(buf, 0, count)`).
  Ω.3 swept the substrate; new code maintains it.
- Flag/mode-as-int (`mode == 0`, `mode == 1`) in any non-trivial
  dispatch — drift mode 8. Convert to ADT before the next match
  fires; H6 catches it eventually anyway.
- HEAP_BASE = 4096 collision risk — sentinel values for nullary
  ADT variants live in `[0, HEAP_BASE)`; bump allocator
  initializes `$heap_ptr` at 1 MiB so collisions are impossible.
  Any change to either constant requires updating both at once
  (`runtime/lists.ka` for the bump init; `backends/wasm.ka` for
  emit_match_arms_mixed's threshold compare).

**Ask the artifact.** `wabt` is installed. Before hypothesizing:

```
wasm-decompile bootstrap/build/lux3.wasm > /tmp/lux3.dec   # pseudocode view
wasm-objdump -d bootstrap/build/lux3.wasm | less           # disassembly
wasm-objdump -x bootstrap/build/lux3.wasm                  # sections
```

**Common crash patterns:**

| Backtrace | Likely cause |
|---|---|
| `alloc → str_concat` with `a=1` | LIndex flat-access reading tag as pointer |
| `alloc → str_slice → split` | O(N²) split, bump allocator exhausted |
| `alloc` with huge size | Garbage pointer read as string length |
| `list_index` returning 1000 | Unknown list tag — flat treated as tree |

**Memory model:** bump allocator, monotonic, never frees. Every
allocation is permanent. Any function that accumulates strings via
`++` in a loop is a potential memory bomb. Traps at 16 MB. GC is a
handler (Arc F.4 scoped arenas). See PLAN.md "Memory Model."

**Representations:**
- **Strings** always flat: `[len_i32][bytes...]`. `str_concat` copies.
- **Lists** CAN be trees: tag 0 = flat, 1 = snoc, 3 = concat, 4 = slice.
  `list_index` traverses the tree. `list_to_flat` materializes to tag
  0 at hot-path entrances.

**Prime directive.** Build the tool that tells you. Don't guess.
Don't pattern-match from crash addresses. Add one debug print, run
once, fix.

**File map (the files you'll touch most):**

| File | Role |
|---|---|
| `std/compiler/graph.ka` | SubstGraph: flat-array, O(1) chase, Read/Write effects |
| `std/compiler/types.ka` | Ty + Reason + Scheme + typed AST + core effects |
| `std/compiler/effects.ka` | EffRow Boolean algebra: + - & ! |
| `std/compiler/infer.ka` | HM inference, one walk, graph-direct |
| `std/compiler/lower.ka` | Live-observer lowering via LookupTy |
| `std/compiler/pipeline.ka` | Handler composition via ~> + query handler |
| `std/compiler/own.ka` | Ownership as Consume effect |
| `std/compiler/verify.ka` | Verify ledger (Arc F.1 swaps to SMT) |
| `std/compiler/clock.ka` | Clock / Tick / Sample / Deadline |
| `std/compiler/mentl.ka` | Teaching substrate (Teach effect, 5 ops) |
| `std/compiler/lexer.ka` | Tokenizer (full spans, all 5 pipe ops) |
| `std/compiler/parser.ka` | Recursive descent (all PipeKind variants) |
| `std/compiler/backends/wasm.ka` | LowIR → WAT (one peer; native/test/browser are sibling handlers) |
| `std/runtime/lists.ka` | Tagged list ops + flat-buffer-plus-counter primitive (`list_extend_to`) |
| `std/runtime/strings.ka` | Flat string primitives + sorted-set algebra (set_union/diff/contains/...) |
| `std/runtime/tuples.ka` | Tuple value layout + accessors |
| `std/runtime/io.ka` | WASI iov scratch + print/read primitives |
| `std/main.ka` | Entry: read stdin → compile → emit WAT |
| `docs/PLAN.md` | THE plan |
| `docs/SYNTAX.md` | Canonical syntax (Σ landed; SYNTAX is the wheel parser is the lathe) |
| `docs/rebuild/00–11` | The 12 executable specs |
| `docs/rebuild/simulations/H*.md` | Per-handle walkthroughs (γ cascade) — read before touching the handle's substrate |
| `docs/errors/` | Error catalog |

**Delete, don't decorate.** No `// removed for X` comments. No
renamed-with-underscore unused variables. If something is unused,
delete it. If something is wrong, delete it and redo it right.

**Never attribute Claude in commits.** No `Co-Authored-By`, no 🤖
trailer, no inline mentions. Write commits as Morgan wrote them alone.

---

## Crystallized Insights (load-bearing truths)

*The ten insights below compose from the **nine-primitive kernel**
named above. The kernel is the axiom set; these are the theorems
the cascade has proven. Both lists are load-bearing; the kernel
lives in DESIGN.md §0.5 and INSIGHTS.md's "Minimal Kernel" section.
Don't confuse the nine with the ten — the nine are what the medium
is BUILT FROM; the ten are what the medium PROVES.*

Ten insights — seven from INSIGHTS.md plus three crystallized
during the γ cascade — that bind all implementation:

1. **The Handler Chain Is a Capability Stack.** `~>` ordering is a
   trust hierarchy. Outermost = least trusted. Compiler-proven.
2. **Five Verbs = Complete Basis.** Any directed graph decomposes
   into `|>`, `<|`, `><`, `~>`, `<~`. Mathematically proven.
3. **Visual Programming in Plain Text.** Newlines are semantic.
   The shape of pipe chains IS the computation graph.
4. **`<~` Feedback Is Genuine Novelty.** No other language makes
   back-edges visible, checkable, and optimizable.
5. **Effect Negation > Everything.** `!E` proves absence. Strictly
   more powerful than Rust + Haskell + Koka + Austral combined.
6. **The Graph IS the Program.** SubstGraph + Env is the universal
   representation. Everything else is a handler projection.
7. **Parameters ARE Tuples. `|>` Is a Wire.** `fn f(a, b)` has type
   `(A, B) -> C`. `<|` and `><` produce tuples. `|>` passes them
   through. Inference structurally unifies. There is no "splatting"
   question. The developer controls arity via their function
   signature. One mechanism. Never re-open this.
8. **The Heap Has One Story.** Closures, ADT variants (fielded),
   nominal records, and closures-with-evidence ALL allocate via
   `emit_alloc(size, "<tmp>")` with field stores at fixed offsets
   from the result pointer. Four shapes, one EmitMemory swap
   surface — bump today, arena tomorrow, GC eventually. Nullary
   ADT variants take the sentinel path (`(i32.const tag_id)`, no
   allocation); the heap-base threshold (HEAP_BASE = 4096) keeps
   sentinels and pointers disambiguable in mixed-variant types.
9. **Records Are The Handler-State Shape.** Frame consolidation
   (Ω.5) turned parallel arrays to records; H1.3's BodyContext,
   H4's region_tracker, H5's AuditReport all converge here. Adding
   a field is additive; tuples force every consumer to widen.
   Until functional update lands (H2.2), arms reconstruct the
   record explicitly — verbose but honest.
10. **Row Algebra Is One Mechanism Over Different Element Types.**
    String-set (runtime/strings), name-set (effects.ka, EffName),
    field-set (records, sorted by field name), tagged_values
    (region_tracker, sorted by handle) — four parallel
    implementations of one ordered-keyed-set algebra. The
    abstraction earns its weight when a fifth instance arrives;
    until then, the parallel forms are honest about what's not
    yet generic.

---

## Deep context (read when you need it)

- **`docs/PLAN.md`** — THE plan. γ cascade with explicit handle
  ordering and Ω audit phases. Bootstrap remains out of mind
  until the cascade closes.
- **`docs/SYNTAX.md`** — canonical syntax (Σ phase). The wheel
  Ω.4's parser was shaped to.
- **`docs/rebuild/00–11-*.md`** — the 12 executable specs. ADTs,
  effects, invariants. Each ≤ 300 lines.
- **`docs/rebuild/simulations/H*.md`** — per-handle walkthroughs.
  Read the relevant one BEFORE touching that handle's substrate.
  Addenda capture how prior decisions read in current substrate
  — riffle-back is mandatory before each new handle commits.
- **`docs/errors/`** — canonical error catalog (E/V/W/T/P codes).
  Every diagnostic resolves through this.
- **`docs/INSIGHTS.md`** — core truths: inference is the light, five
  verbs draw topology, handlers read it, what Inka dissolves.
- **`docs/DESIGN.md`** — language manifesto, effect algebra, gradient,
  refinement types, DSP/ML unification.
- **`docs/SYNTHESIS_CROSSWALK.md`** — historical: external validation
  + research neighbors 2024-2026.

---

## When drift happens

When you notice yourself proposing a patch, asking a flat question,
or hedging on a structural move: invoke `/remote-control inka` or
directly say "Inka, what would you do?" — roleplay reframes
alignment. This is a working mechanism, not a gimmick.
