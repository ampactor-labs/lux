# Hβ.arena — Build-time arena substrate for the seed's runtime

> **Status:** `[DRAFT 2026-04-28]`. Sibling cascade to `Hβ-emit-
> substrate.md`. Authored alongside it per the post-cascade-closure
> riffle-back audit (commit `4c876bc`) which surfaced the
> bump-allocator-pressure dual-gate from `ba327c9`.
>
> **Authority:** `CLAUDE.md` Mentl's anchor + Anchor 0 (dream code)
> + Anchor 5 ("if it needs to exist, it's a handler"); `docs/DESIGN.md`
> §0.5 (eight-primitive kernel; this walkthrough realizes primitive
> #5 (Ownership as effect) at the seed's BUILD-TIME runtime layer);
> `docs/SUBSTRATE.md` §V "Memory & Substrate Operations";
> `docs/specs/simulations/H7-multishot-runtime.md` (continuation
> heap-discipline precedent); `docs/specs/simulations/B5-AM-arena-
> multishot-substrate.md` (W5 region arenas; arena × MultiShot
> composition); `bootstrap/src/runtime/alloc.wat` (the seed's current
> bump allocator — what this cascade extends).
>
> *Claim in one sentence:* **The seed's BUILD-TIME memory model is
> a bump allocator (alloc.wat:9-16) that traps when infer/lower walk
> real-world ASTs (per the ba327c9 substrate-honesty audit). This
> walkthrough designs a per-cascade-stage arena substrate where each
> pipeline stage (`$inka_infer`, `$inka_lower`, `$inka_emit`)
> allocates from its own region; cascade transitions reset the
> region to free all stage-local allocations in O(1); long-lived
> graph nodes promote to a global heap. NO GC. NO reference counting.
> Pure scoped-arena discipline matching the wheel's W5 substrate +
> Anchor 5's "memory model is a handler swap" — but at the SEED's
> build-time runtime, NOT the emitted program's runtime (that's
> Hβ-emit's `EmitMemory` effect concern).**

---

## §0 Framing — the bump-pressure problem

### 0.1 The discovery

Per commit `ba327c9` substrate-honesty audit (post-Hβ.lower-cascade-
closure pipeline-wire attempt): chaining `$inka_infer` between
`$parse_program` and `$emit_program` in `$sys_main` trapped
first-light Tier 1 with **out-of-bounds memory fault at
0x2213838 in linear memory of size 0x2000000** (32 MiB).

Root cause: the seed's `bootstrap/src/runtime/alloc.wat` is a
monotonic bump allocator (`$heap_ptr` starts at 1 MiB; bumps
forever; never frees). When `$inka_infer` walks a real `lexer.nx`-
shape AST (~thousands of nodes), it allocates per-handle Ty records,
per-binding Reason records, evidence-row records per call site, env
extension records per scope — and exhausts the 32 MiB heap before
the walk completes.

The 25/25 infer trace-harnesses pass because they construct
synthetic minimal ASTs (~10s of nodes). They don't exercise
bump-pressure at scale.

### 0.2 What this is NOT

This is **NOT** the same problem as the wheel's `EmitMemory` effect
(Hβ-emit-substrate.md §3.5). That handler swap controls what the
EMITTED program does at runtime — bump vs arena vs GC for
user-program allocations. This walkthrough is about the SEED's OWN
runtime — the bootstrap/inka.wasm's bump allocator that holds the
graph + LowExpr + closure records DURING build.

Two arenas, two substrates:

| Arena | What it controls | Walkthrough |
|---|---|---|
| **Build-time arena** | The seed's runtime heap during `wasmtime run bootstrap/inka.wasm` | `Hβ-arena-substrate.md` (this) |
| **Emit-time arena** | The emitted program's runtime heap (output WAT) | `Hβ-emit-substrate.md` §3.5 (EmitMemory effect swap) |

Same ANCHOR 5 discipline ("memory model is a handler swap") at two
different layers. Inka eats its own dogfood — but the dogfood at
each layer is its own substrate.

### 0.3 What Hβ.arena resolves

Three concrete pressures per the substrate audit:

1. **Per-cascade-stage isolation**: `$inka_infer` allocates per-walk
   records that can be freed AFTER `$inka_lower` consumes the graph.
   Currently they leak forever in the bump heap.
2. **Per-fn isolation within a stage**: walking each user-fn in
   walk_stmt produces local allocations (locals ledger, captures
   list, arm-records, ev_slots) that can be freed after the fn's
   LowExpr is built.
3. **Long-lived graph promotion**: the graph itself (NBound/NFree
   GNodes + chase trail) outlives any single stage. Promoting these
   to a separate "permanent" heap keeps stage-local arenas small.

### 0.4 What Hβ.arena composes on

| Substrate | Provides | Used by Hβ.arena for |
|---|---|---|
| `bootstrap/src/runtime/alloc.wat` (current bump) | `$alloc(size)`; `$heap_ptr` global | the V1 default handler — bump-allocation when no arena is installed |
| **W5 region-arena substrate (wheel src/runtime/* TBD per B5-AM walkthrough)** | region-enter / region-exit primitives; per-region pointer + size tracking | the seed transcribes per-region pointer + reset discipline at the WAT layer |
| **B.5 AM-arena-multishot composition** | replay_safe / fork_deny / fork_copy semantics | the seed's V1 doesn't need MultiShot composition; pure single-shot region discipline suffices for cascade-stage arenas; B.5 lands post-L1 for Mentl's speculation-rollback substrate |

### 0.5 What Hβ.arena does NOT design

- **GC.** Per CLAUDE.md memory model: GC is a handler (Arc F.4).
  Post-first-light substrate. This walkthrough is pure-arena
  discipline — no headers, no marking, no sweeping.
- **Reference counting.** Same — handler swap concern post-L1.
- **MultiShot rollback.** B.5 AM-arena-multishot composes arenas
  with MultiShot continuations (replay_safe / fork_deny / fork_copy).
  Not needed for the seed's V1 build-time arenas — pipeline stages
  are single-shot. Lands when Mentl's speculation needs it.
- **Emit-time memory strategy.** Per §0.2 — that's `EmitMemory`
  effect (Hβ-emit §3.5).

---

## §1 The arena shape — per-stage region with reset

### 1.1 Region layout

```
Linear memory (the seed's heap):

[0, HEAP_BASE=4096)          sentinel + data segments (lexer keywords,
                              tag values < 4096; per CLAUDE.md memory
                              model)
[HEAP_BASE, BUILD_HEAP_BASE)  reserved (currently empty)
[BUILD_HEAP_BASE,             permanent heap — graph nodes, env entries,
   PERMANENT_HEAP_END)        long-lived records that outlive any one
                              stage. $perm_ptr global.
[PERMANENT_HEAP_END,          per-stage arena — current pipeline stage's
   STAGE_ARENA_END)           allocations. $stage_arena_ptr global.
                              Reset on stage transition.
[STAGE_ARENA_END,             per-fn arena — current user-fn's local
   FN_ARENA_END)              allocations within a stage. $fn_arena_ptr
                              global. Reset on fn-walk-exit.
```

### 1.2 The three allocators

```wat
;; $perm_alloc(size) — long-lived; promotes a record to permanent heap.
;; Used for: graph GNodes, env entries, Ty records that outlive stage.
(func $perm_alloc (param $size i32) (result i32) ...)

;; $stage_alloc(size) — pipeline-stage-local; reset between stages.
;; Used for: infer's intermediate Reason chains, walk_stmt's transient
;; arm-records, lower's LowExpr trees.
(func $stage_alloc (param $size i32) (result i32) ...)

;; $fn_alloc(size) — user-fn-local within a stage; reset between fns.
;; Used for: state.wat locals/captures ledger entries; ev_slot lists;
;; per-fn closure synthesis intermediates.
(func $fn_alloc (param $size i32) (result i32) ...)
```

### 1.3 The reset primitives

```wat
;; $stage_reset() — bumps $stage_arena_ptr back to start; frees ALL
;; stage-local allocations in O(1). Called between $inka_infer →
;; $inka_lower → $inka_emit transitions.
(func $stage_reset ...)

;; $fn_reset() — bumps $fn_arena_ptr back to start; frees ALL
;; fn-local allocations in O(1). Called at $ls_reset_function
;; (state.wat) — the seed's existing per-fn boundary.
(func $fn_reset ...)
```

### 1.4 The handler-swap framing per Anchor 5

The substrate is structured so future `EmitMemory`-style handler
swaps compose: V1 installs `bump_handler` (current alloc.wat
behavior); future installs `arena_handler` (this walkthrough);
post-L1 installs `gc_handler` (Arc F.4). All routed through ONE
allocation surface — the existing `$alloc(size)` symbol — with
internal dispatch on a stage-tag global.

Per DESIGN.md §7.3 "the handler IS the backend": the seed's
build-time memory model is the SAME shape as the emit-time memory
model (§3.5 of Hβ-emit). Both are handler swaps; both compose on
Anchor 5; both are physical at their respective layers.

---

## §2 Stage transitions — per-cascade reset discipline

### 2.1 The three pipeline stages

Per Hβ-bootstrap §1.15 + the cascade-closure landings:

```
parse  →  $inka_infer  →  $inka_lower  →  $inka_emit  →  proc_exit
            │              │              │
            ▼              ▼              ▼
         $stage_reset   $stage_reset    $stage_reset
         called BEFORE called BEFORE   called BEFORE
         this stage    this stage      this stage
```

Each stage owns its own arena; resetting at stage entry frees ALL
the previous stage's transient allocations. Graph GNodes (in
permanent heap) survive across resets because they live in
`$perm_alloc`'s region.

### 2.2 What survives across stages

- **Graph + Env**: populated by infer; read by lower + emit. Lives
  in `$perm_alloc`'s region. Never reset until process exit.
- **The input AST**: parsed by `$parse_program`, consumed by all
  three stages. Lives in `$perm_alloc` (the parser is currently
  alloc.wat-based; promotes to perm at parser-output boundary).
- **The lowered LowExpr program**: produced by `$inka_lower`, read
  by `$inka_emit`. Could live in either stage-arena (if emit
  copies during traversal) or perm (if shared between stages).
  **Decision per §10**: lives in stage-arena owned by lower; emit
  reads it before $stage_reset fires for emit's stage.

### 2.3 What gets reset

Per stage:
- **Infer**: env scope frames, transient Reason chains, ResumeDiscipline
  records that aren't bound to a graph handle, free-vars buffer-counter
  intermediates, generalize/instantiate substitution maps.
- **Lower**: state.wat's transient lookups (most are reset per-fn
  already via $ls_reset_function), arm-records lists, ev_slots
  lists, closure synthesis intermediates.
- **Emit**: WAT-text output buffer (continuously flushed to stdout
  per emit_infra discipline; not arena-resident anyway), per-fn
  local-var-name maps.

---

## §3 Per-fn arenas within a stage

### 3.1 The state.wat boundary

`bootstrap/src/lower/state.wat:240-249` (`$ls_reset_function`)
already establishes the per-fn boundary for locals/captures ledger.
Hβ.arena composes: `$fn_reset()` is called from `$ls_reset_function`
to additionally free ALL fn-local arena allocations in O(1).

The infer side has a similar boundary at FnStmt's two-pass discipline
(infer/walk_stmt.wat:432-535). Hβ.arena adds an analogous
`$infer_fn_reset()` call there.

### 3.2 What survives per-fn reset

- **Bound names in env** (FnStmt's pre-bind from Lock #3 of chunk #10):
  these survive because they're stored in the (perm-allocated) env
  list, not the fn-arena.
- **The fn's LowExpr/AST** itself — owned by the calling stage's
  stage-arena, not the fn-arena.

### 3.3 What gets reset per-fn

- LOCAL_ENTRY records (state.wat tag 280)
- CAPTURE_ENTRY records (state.wat tag 281)
- Transient ev_slot lists during $derive_ev_slots
- Per-fn closure synthesis intermediates (params buffer, body LowExpr
  before LMakeClosure construction)

---

## §4 Eight interrogations

| # | Primitive | Answer |
|---|-----------|--------|
| 1 | **Graph?** | Graph nodes promote to `$perm_alloc` region; survive every reset. The graph IS the universal representation per SUBSTRATE.md §VIII; arena discipline preserves that invariant by perm-promoting graph state. |
| 2 | **Handler?** | THIS IS THE LOAD-BEARING ANSWER. Per Anchor 5 + DESIGN.md §7.3: memory strategy is a handler swap. V1 installs `bump_handler`; W5 lands `arena_handler` (this walkthrough); post-L1 lands `gc_handler`. The substrate's discipline composes with the emit-time `EmitMemory` effect (Hβ-emit §3.5) — same shape, two layers. |
| 3 | **Verb?** | N/A at substrate level; allocations don't draw verb topology. |
| 4 | **Row?** | N/A — arena discipline is row-silent. |
| 5 | **Ownership?** | THIS IS THE LOAD-BEARING ANSWER. Each arena owns its records; `$stage_reset` is the OWN-by-stage-frame discipline made physical. Per-fn arena owns fn-local records. Promotion to perm IS an ownership transfer (stage-arena `own` → perm `own`). Mirrors the seed's `$ls_bind_local` / `$ls_reset_function` discipline at the memory-allocator layer. |
| 6 | **Refinement?** | N/A — refinement obligations live in verify ledger; promotion of TRefined records to perm is a substrate concern, not a refinement concern. |
| 7 | **Gradient?** | Each per-stage reset cashes out the substrate-honest claim "this stage's intermediates are no longer needed." The gradient is: more reset-points → tighter memory; fewer reset-points → simpler discipline. V1 picks 4 reset points (3 stages + 1 per-fn) per the cascade boundaries; future enrichment can refine. |
| 8 | **Reason?** | N/A — Reasons are graph-resident (perm-allocated GNodes); arena reset doesn't touch them. |

---

## §5 Forbidden patterns audit

- **Drift 1 (vtable):** Allocator dispatch is direct fn calls
  (`$perm_alloc` / `$stage_alloc` / `$fn_alloc`). NO `$alloc_table`
  data segment. NO `_lookup_allocator` function.
- **Drift 4 (monad transformer):** No `MemM`. Each allocator is
  `(param $size i32) (result i32)` direct.
- **Drift 5 (C calling convention):** No threaded `__heap_ptr`
  parameter. Allocators read globals directly.
- **Drift 8 (string-keyed):** Stage tags are integer constants if
  needed (e.g., STAGE_INFER=0, STAGE_LOWER=1, STAGE_EMIT=2). NEVER
  `if str_eq(stage_name, "infer")`.
- **Drift 9 (deferred-by-omission):** All three allocators bodied;
  reset primitives bodied; B.5 MultiShot composition deferred as
  named follow-up `Hβ.arena.multishot-composition` (post-L1; lands
  when Mentl's speculation needs it).
- **Foreign fluency — generational GC:** NEVER "young generation" /
  "old generation" / "promote" (in the GC sense). The vocabulary is
  arena / region / stage / perm-promote per Inka's memory discipline.
- **Foreign fluency — manual malloc/free:** NEVER `free()` /
  `dealloc()`. The arena reset IS the free; per-allocation free
  doesn't exist in the seed.
- **Foreign fluency — Rust ownership tracking:** Ownership is per
  arena/stage/fn — substrate-level, not type-level. Inka's
  ownership-as-effect is a separate substrate (own.wat); this
  arena substrate is the runtime layer underneath.

---

## §6 Substrate touch sites — chunk decomposition

### 6.1 Proposed file layout

```
bootstrap/src/runtime/arena.wat   # NEW — replaces some of alloc.wat
                                  #       OR extends alloc.wat with the
                                  #       3 allocators + 2 reset primitives
                                  #       + $perm_promote helper
```

**Single-chunk landing.** The arena substrate is small enough
(~250-350 lines) and tightly coupled enough that decomposition
into per-allocator chunks adds noise without adding clarity. Mirror
of `bootstrap/src/runtime/alloc.wat`'s single-chunk pattern.

Optional second chunk if substrate grows:

```
bootstrap/src/runtime/arena_diag.wat  # OPTIONAL — debug/diagnostic
                                      # helpers for arena pressure
                                      # ($arena_high_water_mark, etc.)
                                      # — named follow-up
                                      # Hβ.arena.diagnostics
```

### 6.2 Layer placement

Layer 1 (Wave 2.A factored runtime substrate) per CHUNKS.sh.
arena.wat lives alongside alloc.wat; new chunks downstream of
alloc.wat consume `$alloc(size)` per the existing public surface,
but `$alloc` internally dispatches to one of the three arenas
based on a stage-tag global.

### 6.3 Existing alloc.wat retrofit

`$alloc(size)` becomes a thin dispatcher:

```wat
(func $alloc (param $size i32) (result i32)
  (local $stage i32)
  (local.set $stage (global.get $current_arena_stage))
  (if (i32.eq (local.get $stage) (i32.const 0))   ;; STAGE_PERM
    (then (return (call $perm_alloc (local.get $size)))))
  (if (i32.eq (local.get $stage) (i32.const 1))   ;; STAGE_STAGE
    (then (return (call $stage_alloc (local.get $size)))))
  (if (i32.eq (local.get $stage) (i32.const 2))   ;; STAGE_FN
    (then (return (call $fn_alloc (local.get $size)))))
  (unreachable))
```

The default global `$current_arena_stage = 0` (STAGE_PERM) preserves
V1 behavior — every existing `$alloc` call promotes to perm. As
infer/lower retrofits to set `$current_arena_stage` at boundaries,
allocations route to the right arena.

### 6.4 Per-cascade boundary retrofits

- `$inka_infer` (bootstrap/src/infer/main.wat:154) — set
  `$current_arena_stage = STAGE_STAGE` at entry; reset at exit.
- `$inka_lower` (bootstrap/src/lower/main.wat) — same pattern.
- `$inka_emit` (TBD when Hβ.emit cascade lands main.wat) — same.
- `$ls_reset_function` (state.wat:240) + infer's `$infer_fn_reset`
  — call `$fn_reset()` to additionally free fn-arena.

These are tiny per-chunk retrofits — one `(global.set)` + reset call
each. Per-cascade-closure peer-handle commits, mirroring the
Hβ.lower.lower-expr-dispatch-extension cumulative-retrofit pattern.

---

## §7 Acceptance criteria

### 7.1 Type-level acceptance (substrate lands)

- [ ] `bootstrap/src/runtime/arena.wat` exists with $perm_alloc /
      $stage_alloc / $fn_alloc / $stage_reset / $fn_reset / $perm_promote.
- [ ] `bootstrap/src/runtime/alloc.wat` retrofits `$alloc(size)` to
      dispatch through the stage-tag global.
- [ ] All existing trace-harnesses continue to PASS with `$current_arena_stage = 0` (STAGE_PERM) default.
- [ ] `wat2wasm` succeeds; `wasm-validate` passes.
- [ ] `wasm-objdump -x` lists the new exports.

### 7.2 Per-cascade boundary retrofits

- [ ] `$inka_infer` sets STAGE_STAGE on entry + resets on exit.
- [ ] `$inka_lower` same.
- [ ] `$inka_emit` same.
- [ ] `$ls_reset_function` + `$infer_fn_reset` call `$fn_reset()`.

### 7.3 Functional acceptance — pipeline-wire unblocks

- [ ] After arena substrate lands + boundary retrofits + Hβ.emit
      cascade closes: chaining
      `$inka_infer + $inka_lower + $inka_emit` in `$sys_main` does
      NOT trap on real-input ASTs.
- [ ] `cat src/runtime/alloc.nx | wasmtime run bootstrap/inka.wasm`
      produces VALID WAT output (not a trap, not garbage).

### 7.4 Drift-clean

- [ ] `bash tools/drift-audit.sh bootstrap/src/runtime/arena.wat
      bootstrap/src/runtime/alloc.wat` exits 0.

---

## §8 Open questions + named follow-ups

| Question | Resolution |
|----------|-----------|
| Single arena.wat chunk OR multi-chunk decomposition? | LOCKED 2026-04-28: single chunk per §6.1 — substrate is tightly coupled; ~300 lines; not worth decomposing. Mirror of alloc.wat's single-chunk pattern. |
| Stage-tag global vs handler-swap dispatch? | DEFERRED to Anchor 7 "three callers earn the abstraction": V1 uses stage-tag global (simpler; one mutable global; direct dispatch in $alloc). When the third memory-strategy variant lands (e.g., post-L1 GC handler per Arc F.4), promote to handler-swap surface mirroring the wheel's `EmitMemory` shape. Named follow-up `Hβ.arena.handler-swap-promotion`. |
| Where does the parsed AST live — perm or stage-arena? | DECISION pending: parser currently allocates from the SAME bump heap that infer uses; promoting to perm requires a parser-output boundary. **Current call**: parser allocates as STAGE_PERM (default) until the parser-output boundary lands as a separate retrofit. This is conservative — keeps V1 behavior — but means the parser arena doesn't reset. Named follow-up `Hβ.arena.parser-output-promotion`. |
| LowExpr trees — stage-arena or perm? | LOCKED per §2.2: stage-arena, owned by lower. Emit consumes before lower's stage-arena resets at emit-stage entry. Trade-off: emit must NOT cache LowExpr across stages; if it does, promote to perm. |

### Named follow-ups (Hβ.arena-introduced)

- **Hβ.arena.handler-swap-promotion** — when third memory-strategy
  variant lands, promote stage-tag global to handler-swap surface.
- **Hβ.arena.parser-output-promotion** — promote parser AST output
  to STAGE_PERM at a parser-output boundary, allowing parser arena
  to reset.
- **Hβ.arena.multishot-composition** — B.5 AM-arena-multishot composition
  for Mentl's speculation rollback (post-L1).
- **Hβ.arena.diagnostics** — high-water-mark tracking + pressure
  warnings for build-time substrate audit (debug-only).
- **Hβ.arena.gc-handler** — full collector substrate per Arc F.4
  (post-first-light).

---

## §9 Composition with Hβ.emit + pipeline-wire

After Hβ.arena substrate lands AND Hβ.emit cascade closes:

```
$sys_main:
  $current_arena_stage := STAGE_PERM  ;; default
  $input := $read_all_stdin()         ;; perm
  $tokens := $lex($input)             ;; perm

  $current_arena_stage := STAGE_STAGE
  $ast := $parse_program($tokens)     ;; (currently perm — see follow-up)

  $current_arena_stage := STAGE_STAGE
  $stage_reset()
  $inka_infer($ast)                   ;; stage-local arena
  $stage_reset()                      ;; clears infer transients

  $current_arena_stage := STAGE_STAGE
  $lowered := $inka_lower($ast)       ;; stage-local arena (LowExpr resident)
  ;; NO reset before emit — emit needs LowExpr

  $current_arena_stage := STAGE_STAGE
  $inka_emit($lowered)                ;; stage-local arena
  $stage_reset()                      ;; final cleanup

  $wasi_proc_exit(0)
```

The arena discipline + EmitMemory swap (Hβ-emit §3.5) compose:
the seed's BUILD-TIME runtime uses arena per-stage; the EMITTED
program's runtime uses bump per emit_memory_bump default. Two
layers; same Anchor 5 discipline.

---

## §10 Closing

Hβ.arena is the substrate that closes the second gate on
`Hβ.infer.pipeline-wire`. Without it, real-input self-compile
traps (per ba327c9 audit). With it + Hβ.emit cascade closure,
pipeline-wire becomes a trivial commit.

**Per Anchor 5**: memory strategy is a handler swap. V1 installs
the bump-via-arena-handler (this walkthrough); future installs
arena-with-rollback (B.5 MultiShot composition); post-L1 installs
GC (Arc F.4). The shape stays the same.

**Per DESIGN.md §7.3 + SUBSTRATE.md §VIII**: handlers all the way
down. The seed's build-time memory IS one handler; the emitted
program's memory IS another (EmitMemory effect, Hβ-emit §3.5);
both compose on the same kernel discipline.

The form is right. The path is named. The next residue:
- Hβ-emit cascade chunks (~9 chunks)
- This Hβ-arena substrate (single chunk)
- Pipeline-wire `$sys_main` retrofit
- first-light-L1 self-compile fixed point

After first-light-L1: refinement substrate (verify_smt) → first-light-L2.
After first-light-L2: Mentl substrate composition (oracle = IC + cached
value per insight #11) → Mentl V1.
After Mentl V1: `inka edit` web playground (Mentl's surface) → the
medium becomes itself.

**Each cascade composes on substrate already in place.** The
ultimate Inka isn't far in chunks; it's far in cascades — and each
cascade now lands faster because the discipline is crystallized.
