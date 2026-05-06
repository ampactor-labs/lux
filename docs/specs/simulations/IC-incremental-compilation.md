# Handle IC — Incremental Compilation

*Role-play as Mentl, tracing what happens when Morgan saves a one-
character edit to `std/compiler/infer.mn` and the LSP re-checks the
project. Today: full recompile, ~seconds. After IC: only the edited
module re-infers, downstream modules with valid `.kai` caches load
their envs from disk, the response returns in conversational
latency. The substrate has been built for this since day one — the
Salsa 3.0 + overlay pattern in `graph.mn`. What pends is the driver.*

---

## The scenario

Morgan opens `std/compiler/infer.mn`. The whole project is checked
once at session start (cold compile; ~1.5s on a modern laptop with
the current substrate). Morgan edits one line: `let x = 1` becomes
`let x = 2`. He saves.

What happens with TODAY's driver:

```
$ mentl check std/compiler/
... full recompile of all 16 .mn files ...
Done in 1.4s.
```

Every module re-lexed, re-parsed, re-inferred, re-lowered. Every
handle re-allocated. Every Reason re-recorded. The graph is built
from scratch even though only ONE module's content changed and
that change doesn't even alter the module's public type signatures.

What SHOULD happen:

```
[infer.mn:42 saved]
incremental check:
  cache/.kai hashes:
    types.mn         — hash unchanged, env loaded from cache (3ms)
    graph.mn         — hash unchanged, env loaded from cache (4ms)
    effects.mn       — hash unchanged, env loaded from cache (3ms)
    infer.mn         — hash CHANGED, re-infer (62ms)
    lower.mn         — public env unchanged in deps, env loaded (5ms)
    [10 more files, all cached, total 28ms]
Done in 105ms.
```

105ms vs 1400ms. The difference is whether the graph is asked the
question it already answered.

---

## What the substrate already provides

The cascade closed having BUILT for this. Specifically:

- **`graph.mn`'s shape is Salsa 3.0.** Flat array + epoch +
  per-module overlays. The `Graph(nodes, epoch, next, overlays)`
  ADT carries `overlays: [(module_name, [handle])]` — one slot per
  module, ready for fork.
- **`graph_fork(name)` is in spec 00.** Not yet plumbed by a driver,
  but the substrate accepts module-scoped handle minting today.
- **Every node carries `Located(span, reason)`.** When a node's
  source doesn't change, its reason doesn't change. Cache validity
  is graph-readable, not heuristic.
- **`env_handler` already supports per-module envs.** The
  `entries: List<(String, Scheme, Reason, SchemeKind)>` shape is
  serializable as-is. `.kai` is just env entries on disk.
- **Module DAG resolution** — parser produces `ImportStmt(name)`
  nodes. The dependency graph extracts trivially.
- **Content-hash keying** — `runtime/strings.mn` has the byte-level
  primitives needed for SHA-256 or simpler digests.

What pends is purely DRIVER orchestration. No new substrate primitive.

---

## Layer 1 — `.kai` file format

A serialized per-module env. One file per `.mn` source.

### Structure

```
type KaiFile = {
  source_hash: Int,           // 64-bit content hash of source
  module_name: String,
  exported_entries: List,     // List<(name, Scheme, Reason, SchemeKind)>
  imports: List,              // List<String> — modules this depends on
  imports_hashes: List,       // List<Int> — hashes of dep .kai at write time
  handle_count: Int           // for handle re-basing on load
}
```

Sorted alphabetically per parser invariant (post-H2). Adding a field
later is additive.

### Serialization discipline

Records (post-H2) write as binary payloads with field-positional
layout. The Reason DAG serializes via topological flattening — each
Reason node gets a sequential index; references encode as ints.
Located spans serialize as four ints. SchemeKind variants tag-encode
(post-H3).

### File location

`<project>/.mentl/cache/<module-path>.kai`. Excluded from git via
project gitignore. Hash-keyed lookup means renaming a module
invalidates the cache (correct: a renamed module is a different
module).

---

## Layer 2 — Driver orchestration

### Cold path (no caches exist)

1. Resolve module DAG from `ImportStmt` nodes (parse all files;
   build adjacency from imports).
2. Topological order modules.
3. For each module in order:
   a. Lex + parse + infer with `graph_fork(module_name)`.
   b. After infer, snapshot env via `env_snapshot()`.
   c. Filter env to exported entries (public surface).
   d. Hash source + serialize KaiFile.
   e. Write `.kai` cache.
4. Continue to lower + emit as today.

### Warm path (caches exist)

1. Resolve module DAG.
2. Hash each source file.
3. For each module:
   a. If `.kai` exists AND `.kai.source_hash == current_source_hash`
      AND every dependency's `.kai.source_hash` matches what THIS
      module recorded in `imports_hashes` at write time → CACHE HIT.
      Load env, install into env_handler under module_name overlay,
      mint handles into the per-module overlay slot.
   b. Else CACHE MISS. Re-infer (cold path step 3a-e for this
      module).

The recursion: a cache hit on module M requires all M's
dependencies' caches to be hits. A cache miss anywhere upstream
cascades: every downstream module recomputes its own cache freshness
check; the new dep hash will differ from the old recorded hash;
they invalidate transitively.

### Cross-module handle resolution

When module A imports module B:
- Module B's `.kai` exports entries with handles minted in B's
  overlay (e.g., handle 47 in B's overlay).
- Module A's inference references those entries — the env_handler
  resolves `env_lookup("B_function")` to B's exported scheme.
- The Scheme's TVar handles refer to B's overlay handles. When A's
  inference reads the type, it chases through B's overlay slot in
  the Graph. The overlay segregation means B's handle 47 and
  A's handle 47 are different nodes; chase resolves correctly via
  the overlay name embedded in the handle (or via the
  `current_overlay_idx` discipline already in graph.mn).

This is the load-bearing question: how does a handle in A's typed
AST refer to B's handle without overlay mixup?

**Decision:** handles include their overlay index. A handle is
not just `Int`; it's `(overlay_idx, slot_idx)` packed into one i32
(say, top 8 bits for overlay, bottom 24 for slot — 256 modules max,
16M handles per module — enough for any realistic project). This
is a SMALL substrate change but well-bounded.

ALTERNATIVE: handles stay as Int; the overlay is RESOLVED at
chase time by walking overlays and finding which one owns the handle.
O(M) per chase where M is overlay count. Adequate for ~100 modules.

**Mentl's choice:** the alternative. Overlay-walk-on-chase is one
extra list scan per chase, bounded by module count. The packed-handle
approach changes the substrate; the walk-on-chase approach changes
only the chase function. Smaller blast radius.

### Cache invalidation policy

A module M's cache is valid iff:
1. M's source hash hasn't changed.
2. Every module M imports — its `.kai` source_hash matches what M
   recorded for it at write time.

If M imports B and B's source changed (so B's `.kai` rewrote with a
new source_hash), then M's recorded `imports_hashes` for B is stale
even if M's own source didn't change. M re-infers.

**Subtle:** if B's source changed but B's PUBLIC API didn't change
(say, B added a private helper fn), should M re-infer? Strictly: yes
(M's recorded imports_hashes mismatches). Optimally: no. The optimal
case requires comparing PUBLIC SURFACE (exported_entries) instead
of raw source hash.

**Decision:** v1 invalidates by source_hash mismatch. The
optimization (compare exported_entries hash separately) lands as
v2 if measured to matter.

---

## Layer 3 — LSP integration

Same operation, driven by `didChange` instead of a batch build.

When the LSP receives `textDocument/didChange` for `infer.mn`:

1. Hash the new buffer content.
2. If hash unchanged from last check → no-op (typo/whitespace fix).
3. Else: invalidate `infer.mn.kai`. Walk import-graph downstream:
   any module that imports `infer.mn` invalidates too (their
   recorded imports_hashes now stale).
4. Re-check the invalidated set in dep order.
5. Stream diagnostics back via `textDocument/publishDiagnostics`.

The latency target: a one-line edit to a leaf module returns in
<50ms. A core-module edit (touching `types.mn`) cascades but the
cascade is bounded by the import DAG, not by file count.

The shared infrastructure: same `cache/` and `driver/` modules
serve both `mentl check`/`mentl build` and the LSP's `didChange`
handler. One implementation; two surfaces.

---

## Layer 4 — what closes when IC lands

- **Conversational latency.** Edit-save-feedback in <100ms for
  typical edits. Mentl's gradient becomes an oracle (interactive),
  not a batch (overnight). The thesis is testable.
- **Drift mode 10 closed at the driver.** The graph is no longer
  treated as stateless cache.
- **LSP becomes deployable.** F.2 (Priority 1) lands cleanly on
  IC's caching foundation.
- **CI/build pipelines collapse.** A "build system" with caching
  has nothing left to do — the compiler IS the cache. DESIGN.md
  Ch 9.4's dissolution becomes operational.
- **Tests as handlers feasible.** Test-running with handler swaps
  becomes interactive when each test's compile is cached; the
  separate test framework (DESIGN Ch 9.2) collapses into the
  compiler.

---

## What IC reveals (expected surprise)

- **Public-surface vs source diff.** Source-hash invalidation is
  conservative. Many edits don't change the public API. Optimizing
  this would let M skip re-infer when B's helpers changed but B's
  exports didn't. The substrate has the data (exported_entries
  hash); v1 doesn't use it. Worth measuring.
- **Reason DAG serialization is the binary-format question.** The
  Reason ADT has many recursive variants (`OpConstraint`, `Unified`,
  `MatchBranch`); serializing them requires a stable encoding that
  survives across compiler versions. The simplest encoding is
  topological-index-then-payload; a more sophisticated content-
  addressed scheme would let identical Reasons share storage across
  modules. v1 uses the simple encoding.
- **Multi-version compatibility.** A `.kai` written by compiler
  vN and read by vN+1 should either work or be rejected with a
  clean error. The KaiFile record gains a `compiler_version`
  field; mismatch invalidates the cache. Cheap, future-proof.
- **Concurrent editing.** Two LSP `didChange` events arriving in
  flight need ordering. The driver serializes by file + sequence
  number; the cache write is atomic (write to temp, rename). This
  is a correctness invariant the LSP layer must respect; not new
  substrate, just driver discipline.
- **Overlay limit.** Walk-on-chase is O(modules) per chase. At
  ~100 modules, chase becomes a measurable fraction of inference
  cost. The packed-handle alternative becomes worth re-examining
  if the project grows past that. Named here so future work knows
  where the ceiling is.

---

## Design synthesis

**KaiFile record** (new) — `{source_hash, module_name,
exported_entries, imports, imports_hashes, handle_count}` — H2
record discipline applies (sorted fields, additive).

**Cache module** — serialize/deserialize KaiFile. Hash function on
source bytes. File I/O via existing `runtime/io.mn` primitives.

**Driver module** — module DAG resolution from ImportStmt; topo
sort; per-module graph_fork; cache lookup with downstream-reach
invalidation.

**Chase function extension** — chase walks overlays to find the
owning module's slot for each handle. O(M) per chase, M bounded
by module count.

**LSP didChange handler** — couples to driver; same operation
dispatched by file event.

**`mentl check` and `mentl build` use the same driver** — the only
difference is whether lowering/emit fires after check.

---

## Dependencies

- H2 (records — KaiFile shape) ✓
- H3 (SchemeKind — env entries serialize with construction-origin)  ✓
- Ω.5 (frame records — env entries are records) ✓
- F.2 LSP arc (couples to IC's driver — Priority 1)
- **FS substrate** — Filesystem effect + WASI handler for
  path_open / fd_read / fd_write / fd_close / path_create_directory.
  Today `runtime/io.mn` has only stdin/stdout/stderr via fd_write
  + fd_read. IC needs per-module `.kai` files on disk; that's an
  FS capability the current substrate doesn't expose. See
  `docs/specs/simulations/FS-filesystem-effect.md` for the
  prerequisite walkthrough.

IC is handler-projection on the graph substrate. FS is a small
new effect + WASI handler — named as a prerequisite, not a
substrate gap (the substrate knows how to be extended with new
effects; this is just one more).

---

## Estimated scope

- ~400-600 lines across 3 new modules:
  - `std/compiler/cache.mn` — KaiFile, hash, serialize, deserialize
  - `std/compiler/driver.mn` — module DAG, topo sort, per-module
    invocation, cache invalidation walk
  - LSP handler arms wiring to driver

- Modifications to existing modules:
  - `graph.mn` — chase function walks overlays for handle resolution
  - `pipeline.mn` — `compile` and `check` route through driver
  - `main.mn` — CLI entry to `mentl check --watch` and similar

- One coordinated commit-cluster (~3-5 commits): cache.mn first
  (data type + serialization, no driver), driver.mn second (uses
  cache, no LSP), LSP wiring third.

---

## Verification

Walkthrough discipline. The simulation traces:

1. **Cold compile.** Empty cache. Every module re-infers; KaiFile
   written for each. Verify the trace produces correct output
   (matches today's `mentl check` output) AND writes complete
   `.kai` files.

2. **No-op edit.** Save a file unchanged. Driver hashes; matches
   cached `.kai`; loads env from cache for every module; produces
   identical diagnostics in <50ms.

3. **Leaf-module edit.** Change a one-line in a leaf (e.g., `main.mn`
   that no other module imports). Only that module re-infers;
   everything else loads from cache. Diagnostic in <100ms.

4. **Core-module edit.** Change `types.mn`. Every module that
   imports it (most of them) invalidates and re-infers in dep
   order. Diagnostic in ~500ms (not 100ms, but not 1500ms either).

5. **Public-surface unchanged after dep change.** Edit a private
   helper in `effects.mn`. v1: `infer.mn` still re-infers
   (conservative). v2 (future): `infer.mn` cache stays valid
   because `effects.mn`'s exported_entries hash didn't change.

6. **Chase across overlay.** Module A reads a Scheme from module B's
   `.kai`. The Scheme's TVars carry B's overlay handles. Chase from
   A's context resolves to B's nodes correctly via overlay walk.

Each verifies as a substrate trace, not a wasmtime run.

---

## Ordering

IC lands as Phase II Priority 1 work, coupled with LSP (F.2).
Recommended: land `cache.mn` first (data + serialization, no
driver), then `driver.mn` (uses cache, no LSP), then LSP
integration third. Each commit is independently useful: cache.mn
alone enables `mentl check` to write caches even without
invalidation logic; driver.mn enables warm-path checks; LSP wires
the editor.
