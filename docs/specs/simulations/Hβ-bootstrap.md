# Hβ — Bootstrap: hand-WAT seed compiler walkthrough

> **Status:** `[REWRITTEN 2026-04-25]` per ultimate-form discipline +
> bootstrap-rewrite recontextualization. Earlier Hβ (2026-04-19 +
> §12 addendum 2026-04-23) framed the seed as a half-written
> in-flight artifact extending in tiers; correct per its time but
> stale to the corrected discipline. This rewrite specifies the
> bootstrap's **ultimate form** per Anchor 0 dream-code:
> what the seed compiler IS when complete, assuming `src/*.mn` (the
> substantively-real VFINAL — Anchor 0 + plan §16) is the wheel to
> compile. The rewrite IS the work the bootstrap arc lands.
>
> **Authority:** `CLAUDE.md` Mentl's anchor + Anchor 0 (dream code)
> + Anchor 4 (build the wheel) + Anchor 7 (walkthroughs first);
> `docs/DESIGN.md` §0 (closing fixed point) + §0.5 (eight-primitive
> kernel) + §11 (closing fixed point); `docs/SUBSTRATE.md` §I "Self-
> Hosting IS the Proof"; `docs/DESIGN.md` (self-compilation as the
> bootstrap moment of self-trust);
> `ROADMAP.md` (hand-WAT not
> translator) + 2026-04-23 (modular `bootstrap/src/*.wat` pivot) +
> 2026-04-25 (bootstrap rewrite recontextualization);
> `ROADMAP.md` bootstrap critical path.
> **Walkthrough peers:** `BT-bootstrap-triage.md` (per-module
> compile inventory; tracks gaps), `H1-evidence-reification.md`
> (closure record + handler dispatch — load-bearing for §1.3),
> `HB-bool-transition.md` (HEAP_BASE invariant — load-bearing for
> §1.1+§1.5), `H2-record-construction.md` + `H2.3-nominal-records.md`
> (record layout — §1.9), `H3-adt-instantiation.md` (variant
> construction — §1.5), `H7-multishot-runtime.md` (MS continuation
> emit — §1.13; substrate per the walkthrough; Tier 3 path
> §12.1), `IC-incremental-compilation.md` (cache substrate — §1.14),
> per-spec contracts at `docs/specs/00-11`.

---

## §0 Framing — what the bootstrap IS

The bootstrap is **the seed compiler's binary image, hand-written
in WAT, that compiles `src/*.mn` + `lib/**/*.mn` (10,629 lines of
substantively-real VFINAL Mentl per plan §16) into validating WASM
the first time, and is kept forever as the reference soundness
artifact.**

Not a translator. Not a transpiler. Not a meta-program. **Hand-
written WAT, transcribed from the cascade walkthroughs (DESIGN +
INSIGHTS + SYNTAX + per-spec contracts + per-handle simulations)
into the modular form `bootstrap/src/*.wat` + concatenated by
`bootstrap/build.sh` into `bootstrap/mentl.wat` + assembled by
`wat2wasm` into `bootstrap/mentl.wasm`.** Per CLAUDE.md anchors +
DESIGN §0:

1. **Hand-written WAT, not translator.** A Rust/C/Python translator
   would be ~4k lines of foreign-fluency drift (vtable / dict /
   list-comprehension idioms leaking into the seed's emit shape).
   The cascade walkthroughs already did the semantic work; writing
   WAT IS transcribing those specs. No third language in the loop.
2. **Modular source, monolithic output.** Source-of-truth is 15+
   `bootstrap/src/*.wat` chunks per layer (runtime / lexer /
   parser / emit). `build.sh` concatenates in dependency order
   (runtime → lexer → parser → emitter → entry-point) into one
   `bootstrap/mentl.wat`. The output IS auditable as a single
   artifact; the input IS maintainable as separated concerns.
   This pivots the 2026-04-21 monolithic-source decision per plan
   §136 (2026-04-23 entry).
3. **Compiles the wheel.** The seed exists to compile the
   substantively-real `src/*.mn` (the wheel per Anchor 4). Its
   surface coverage IS the surface src/*.mn uses + the surface
   lib/**/*.mn uses. **Every shape src/*.mn exercises, the seed
   handles or it isn't done.** Currently the seed handles
   verify.mn (1 import; 63 lines) cleanly and produces degenerate
   output for graph.mn + the rest (per BT walkthrough §1 + my
   2026-04-25 finding — see §11). The work IS extending the seed
   to handle the full src/*.mn surface.
4. **Kept forever.** Unlike a disposable translator that dissolves
   post-first-light, hand-WAT IS the reference. Any future target
   (native x86-64 / GPU / alternate Wasm engine) validates against
   it via the first-light test. The seed's bytes are the
   substrate's binary self-portrait; preserving it preserves the
   substrate's own self-description.
5. **Tier 3 self-host growth post-L1.** Once `first-light-L1`
   closes (byte-identical self-compile via current bootstrap +
   linker pass), every subsequent substrate landing in `src/*.mn`
   compiles via VFINAL-on-partial-WAT, diffs into hand-WAT, audits
   per walkthrough paragraph. **Mentl bootstraps through Mentl.** No
   foreign-language shortcut at any stage.

**Scope when complete:** ~50-150k lines of WAT across the modular
chunks + ~200 line linker pass + ~150 line first-light harness +
canonical build + WABT-toolchain validation. The medium's binary
self-portrait, kept as long as Mentl exists.

---

## §1 The lowering conventions — every `.mn` shape's WAT form

Every shape `src/*.mn` produces compiles to one canonical WAT form
per this section. Hand-WAT transcribers read this section + the
relevant per-handle walkthrough + emit WAT directly. **No design
left at the WAT layer** — the design lives in the walkthroughs +
specs; transcription is mechanical.

### §1.1 Type encoding — i32 primary; HEAP_BASE invariant

Per `HB-bool-transition.md` + CLAUDE.md memory-model section:

- **`HEAP_BASE = 4096`** is the substrate invariant. Sentinel
  values for nullary ADT variants live in `[0, HEAP_BASE)`. Every
  heap allocation lives at `>= HEAP_BASE`. Mixed-variant match
  dispatch uses `(scrut < heap_base())` as discriminator.
- **Bump allocator's `$heap_ptr` initializes at 1 MiB (1048576).**
  Heap region: `[1MB, end_of_linear_memory)`. Sentinel region:
  `[0, 4096)`. Scratch region for WASI iov + path packing:
  `[80, 1024)` (per `lib/runtime/io.mn` scratch layout — preserved
  in seed's hand-WAT).

**WAT emission:**
```wat
(global $heap_base i32 (i32.const 4096))
(global $heap_ptr (mut i32) (i32.const 1048576))

(func $alloc (param $size i32) (result i32)
  (local $old i32)
  (local.set $old (global.get $heap_ptr))
  (global.set $heap_ptr
    (i32.and
      (i32.add (i32.add (local.get $old) (local.get $size)) (i32.const 7))
      (i32.const 0xFFFFFFF8)))
  (local.get $old))
```

8-byte-aligned bump. Monotonic. Never frees (per CLAUDE.md memory
model — `bump_allocator` IS the seed's allocator handler;
post-first-light `temp_arena` / `diagnostic_arena` are peer
handlers swappable via `~>`).

### §1.2 Graph substrate — flat array with epoch + trail + overlays

Per spec 00 (graph.md) + γ cascade closure (plan §16 + §1721):

- **Graph nodes:** flat array of `GNode(NodeKind, Reason)` entries.
  Handle IS the index. `chase` walks `NBound` / `NRowBound` links
  to terminal — amortized O(1) per spec 00.
- **Trail:** parallel flat array + `trail_len` counter. Append O(1)
  amortized via doubling. Rollback reads backward from `trail_len`
  down to checkpoint, applies inverses, resets `trail_len`.
- **Per-module overlays:** three parallel flat arrays
  (`overlay_names`, `overlay_bufs`, `overlay_lens`) +
  `overlay_count` + `current_overlay_idx`. Each `graph_fresh_ty`
  reads current overlay's handles-buffer + extends + writes new
  handle + updates counter. O(1) amortized; no string-scan per
  register.

**WAT layout (heap-allocated regions, pointed by globals):**
```wat
(global $graph_nodes_ptr (mut i32) (i32.const 0))   ; set by $graph_init
(global $graph_next_handle (mut i32) (i32.const 0))
(global $trail_ptr (mut i32) (i32.const 0))
(global $trail_len (mut i32) (i32.const 0))
(global $overlay_names_ptr (mut i32) (i32.const 0))
(global $overlay_bufs_ptr (mut i32) (i32.const 0))
(global $overlay_lens_ptr (mut i32) (i32.const 0))
(global $overlay_count (mut i32) (i32.const 0))
(global $current_overlay_idx (mut i32) (i32.const 0))
```

`$graph_init` allocates initial buffers via `$alloc`; the substrate
shape per spec 00 holds.

### §1.3 Handler dispatch — closure records, NO vtable

Per CLAUDE.md Mentl's anchor's vtable-drift guard + `H1-evidence-reification.md`:

**Closure record layout** (heap-uniform; γ crystallization #8 per
INSIGHTS):
```
offset  0:  tag            (i32 — heap discriminator + nullary-sentinel disambig)
offset  4:  fn_index       (i32 — index into WAT function table for call_indirect)
offset  8:  capture_0      (i32 — first lexical capture)
offset 12:  capture_1
 ...
offset +N:  evidence_slot_0 (i32 — function-pointer for polymorphic effect dispatch)
offset +M:  evidence_slot_1
 ...
```

**Same `$alloc(size)` protocol for closures, ADT variants, nominal
records, closures-with-evidence.** Four shapes, one memory model,
one allocation path. Per γ crystallization #8 (INSIGHTS).

**Handler dispatch at a `perform op_name(args)` site** (per H1):

1. **Ground site (>95% per H1 evidence reification):** the graph
   proves the handler chain monomorphic. Emit direct `(call $op_<name> <args>)`. Zero indirection. Per Koka JFP 2022 evidence-passing
   compilation.
2. **Polymorphic minority:** `(call_indirect (type $op_sig) <args>
   (i32.load offset=<ev_offset> (local.get $closure)))`. Reads
   function-pointer FIELD on the closure record's evidence slot;
   `call_indirect` dispatches.

**No vtable. No dispatch table.** The evidence IS a field on the
closure record per H1; indirect call reads that field. Per CLAUDE.md
Anchor "There is no vtable in Mentl."

### §1.4 Tail calls — OneShot handler arms → `return_call`

Per spec 05 (`lower.md`):
- OneShot-typed effect ops at the perform site → direct `(return_call $op_<name> <args>)` when graph proves ground.
- MultiShot ops → heap-allocated continuation struct + per §1.13.

WAT tail-call opcode: `return_call $func_name`. Wasmtime supports
since Wasm 3.0 (standardized September 2025; wasmtime v44+).

### §1.5 Match lowering — mixed-variant via heap-base threshold

Per HB-bool-transition.md + H6-wildcard-audit.md + H3-adt-instantiation.md:

- **Nullary-sentinel variants** (no fields): `(i32.const tag_id)` —
  no allocation. Lives in `[0, HEAP_BASE)`.
- **Fielded variants:** allocated via `$alloc`; tag at offset 0,
  fields following. Lives at `>= HEAP_BASE`.
- **Mixed match (both kinds):** dispatcher branches on
  `(i32.lt_u (local.get $scrut) (global.get $heap_base))`.
  True → sentinel dispatch via `br_table`; false → load tag at
  offset 0, dispatch via `br_table`.

WAT shape (per HB's `emit_match_arms_mixed`):
```wat
(block $match_done
  (block $heap_path
    (br_if $heap_path
      (i32.ge_u (local.get $scrut) (global.get $heap_base)))
    ;; sentinel dispatch
    (block $arm_n ... (block $arm_0
      (br_table $arm_0 ... $arm_n (local.get $scrut)))
      ... (br $match_done))
  )
  ;; heap dispatch
  (local.set $tag (i32.load (local.get $scrut)))
  (block $h_arm_n ... (block $h_arm_0
    (br_table $h_arm_0 ... $h_arm_n (local.get $tag)))
    ... (br $match_done))
)
```

H6 wildcard discipline: every load-bearing ADT match is exhaustive;
no `_ => fabricated_default` arms. Per CLAUDE.md drift mode 1+6.

### §1.6 String layout — flat

Per CLAUDE.md memory model:
```
offset 0:  length (i32)
offset 4:  bytes...
```

`$str_concat` allocates new string, copies both. `$str_eq` compares
length-then-bytes. `$str_slice` allocates new string from substring.
All in `lib/runtime/strings.mn` substrate; seed mirrors them in
hand-WAT.

### §1.7 List layout — tagged (flat or snoc tree)

Per CLAUDE.md representations + `lib/runtime/lists.mn`:
```
offset 0:  tag (0=flat, 1=snoc, 3=concat, 4=slice)
offset 4:  variant-specific payload
```

- **Tag 0 (flat):** `[count:i32][bytes/elements...]`
- **Tag 1 (snoc):** `[count:i32][tail:ptr][head:i32]`
- **Tag 3 (concat):** `[count:i32][left:ptr][right:ptr]`
- **Tag 4 (slice):** `[count:i32][tag:i32][base:ptr][start:i32]`

`$list_index` exhaustive on all four tags — O(1) for tag 0, O(log N)
for snoc, O(depth) for concat/slice. `$list_to_flat` materializes
to tag 0 at hot-path entrances per CLAUDE.md bug classes.
`$list_extend_to` grow-on-demand for the buffer-counter substrate
(Ω.3) — load-bearing primitive across graph/trail/overlay arrays
per spec 00.

### §1.8 Tuple layout — fixed-offset

Per H2-record-construction.md tuple substrate:
```
offset 0:  arity (i32)
offset 4:  field_0
offset 8:  field_1
 ...
```

`$make_tuple(n)` allocates; `$tuple_get(t, i)` loads at
`offset = 4 + 4*i`. Per spec 03 typed AST + H2.

### §1.9 Record layout — sorted-field fixed-offset

Per H2 + H2.3-nominal-records.md:
```
offset 0:  type_tag (i32 — 0 for structural, >0 for nominal type index)
offset 4:  arity (i32)
offset 8:  field_0
 ...
```

Fields sorted alphabetically by name at construction; offset
computed from the type's sorted field list at compile time. Per
Insight #9 (records-as-handler-state-shape) + H2.

### §1.10 Effect row layout — `EfPure | EfClosed | EfOpen`

Per spec 01 (effrow.md):
- **EfPure:** sentinel nullary variant (id 0).
- **EfClosed(sorted_name_list):** allocated record with type_tag
  = 1, pointer to name-sorted list at offset 8.
- **EfOpen(sorted_name_list, row_handle):** type_tag = 2, list at
  offset 8, handle at offset 12.

Row algebra operations (`$row_union`, `$row_diff`, `$row_inter`,
`$row_subsumes`) emit as runtime functions in the seed's runtime
section. Per Flix Boolean unification + spec 01.

### §1.11 Refinement types — emit-erased; obligations through Verify

Per spec 02 (ty.md) + spec 06 (effects-surface.md) + plan FV.3
landings:

- `TRefined(base, predicate)` emits as the underlying `base` type.
  The predicate is type-level only; runtime carries the unrefined
  representation.
- `Verify` effect operations performed at construction sites
  accumulate obligations in `verify_ledger` state; SMT-handler
  swap (`verify_smt`) per Arc F.1 discharges them.

The seed's emit treats `TRefined(base, _)` identically to `base`.
Per `verify_ledger` substrate already in `src/verify.mn`: ledger
entries are heap-allocated records; `verify_smt` handler swap
post-first-light.

### §1.12 Feedback state slot — per-handler-state offset

Per `LF-feedback-lowering.md`:

`<~ delay(N)` becomes a slot in the enclosing handler's state
record. Slot allocated at lower time; emit uses `(i32.load
offset=<slot> (local.get $handler_state))` and `(i32.store
offset=<slot> ...)` around the body's invocation.

For `delay(1)`, single-slot ring buffer:
```wat
;; load prior
(i32.load offset=$fb_slot (local.get $handler_state))
(local.set $fb_prior_<h>)
;; emit body (uses $fb_prior_<h>)
... body lowering ...
;; tee current → store + reload
(local.tee $fb_current_<h>)
(i32.store offset=$fb_slot (local.get $handler_state))
(local.get $fb_current_<h>)
```

For `delay(N>1)`: ring-buffer of N i32 slots; index modulo N. Per
LF.1 sub-handle.

### §1.13 MultiShot continuation emit — heap-captured struct

Per `H7-multishot-runtime.md` (walkthrough landed `f463b46`):

`@resume=MultiShot` op at perform site emits:
```wat
;; allocate continuation struct
(call $alloc (i32.const <cont_struct_size>))
(local.set $cont)
;; populate struct: state_index + saved locals + handler reference
(i32.store offset=0  (local.get $cont) (i32.const <state_index>))
(i32.store offset=4  (local.get $cont) (local.get <captured_local_0>))
(i32.store offset=8  (local.get $cont) (local.get <captured_local_1>))
... (per-MS-arm state machine) ...
;; invoke handler with continuation
(call_indirect (type $ms_handler_sig) (local.get $cont)
               (i32.load offset=$ms_handler_field (local.get $closure)))
```

Resume re-enters at the saved `state_index`; locals restored from
the struct. Multiple resumes fork the continuation; each fork's
arena-handler interaction (replay_safe / fork_deny / fork_copy per
AM walkthrough) determines capture semantics.

`LMakeContinuation(captures, ev_list, ret_slot)` is the LowExpr
peer variant that drives this emit per H7. The seed's emit handles
this when H7 substrate lands per plan §587 (substrate pending; Tier
3 self-host path per §12.1 below).

### §1.14 Cache binary format — Pack/Unpack

Per `IC-incremental-compilation.md` + plan §76 (2026-04-22 Phase B
cache dissolution):

The IC `.kai` cache files use binary `Pack`/`Unpack` substrate per
`lib/runtime/binary.mn`. Each Ty / Scheme / SchemeKind / EffRow /
Ownership / ResumeDiscipline variant gets an exhaustive tag byte;
Pack writes; Unpack reads. The seed handles cache writes if the
seed itself runs IC; today that's deferred to post-first-light
(seed's primary job is one-shot self-compile).

For self-compile: cache files aren't load-bearing; the seed reads
source directly + compiles. Cache files become load-bearing when
post-L1 Tier 3 growth uses VFINAL-on-partial-WAT — at that stage
the seed needs IC handler-chain support, which it inherits via
self-hosted compile of `src/cache.mn` + `src/driver.mn`.

### §1.15 Entry-handler installation — `mentl --with <name>`

Per `EH-entry-handlers.md`:

`mentl --with <handler_name>` resolves `<handler_name>` through env;
wraps `main()`'s body in the resolved handler before emit; the
outermost handler IS the entry-handler. Subcommand aliases per
EH walkthrough table:
- `mentl compile` ≡ `--with compile_run`
- `mentl check` ≡ `--with check_run`
- `mentl teach` ≡ `--with teach_run`
- `mentl audit` ≡ `--with audit_run`
- `mentl query <q>` ≡ `--with query_run <q>`
- `mentl run` ≡ `--with compile_run && wasmtime output`
- `mentl edit` ≡ `--with edit_run` (per IE walkthrough §9 IE.cli)
- `mentl doc` ≡ `--with doc_run` (per F.1 walkthrough §3.8)
- `mentl lsp` ≡ `--with lsp_run` (per MV-LSP walkthrough)
- `mentl new <name>` ≡ `--with new_project(name)`
- `mentl test` ≡ `--with test_run`
- `mentl chaos` ≡ `--with chaos_run`
- `mentl repl` ≡ `--with repl_run`

The seed's `_start` reads `argv` (via WASI), dispatches per
subcommand alias OR `--with <name>` resolution, wraps `main()`,
emits.

### §1.16 Eight-tentacle Mentl voice substrate — IDE/doc surface

Per `MV-mentl-voice.md` + `IE-mentl-edit.md` + `F1-mentl-doc.md`:

The seed compiles the substrate that powers Mentl's voice — the
Interact effect (22 ops), the 8 tentacle render arms, the
silence_predicate, the `voice_lines_for(situation)` projection.
The seed itself doesn't INVOKE Mentl during self-compile (the
voice surfaces are surfaces, not compile-path); it just emits
correct WAT for the Mentl-voice modules in `src/mentl_voice.mn`
+ `src/mentl_oracle.mn` + `src/mentl_lsp.mn` + `src/mentl.mn`.

---

## §2 The bootstrap's modular shape

Per plan §136 (2026-04-23 modular pivot). Source lives in 15+
modular WAT chunks; `bootstrap/build.sh` concatenates per layer
order; output is `bootstrap/mentl.wat` (auditable as monolith).

### §2.1 Layer structure

```
Layer 0: Module shell                  (inline in build.sh)
         ├─ (module ...)
         ├─ (import "wasi_snapshot_preview1" ...)
         ├─ (memory (export "memory") 512)
         └─ (global $heap_ptr ...) etc.

Layer 1: Runtime primitives             (inline in build.sh OR bootstrap/src/runtime/*.wat)
         ├─ $alloc + $heap_base + $heap_ptr
         ├─ $tag_of + $is_sentinel
         ├─ $str_* (concat / eq / slice / len / to_list)
         ├─ $list_* (alloc_flat / alloc_snoc / to_flat / index / set / len / extend_to)
         ├─ $tuple_* + $record_*
         ├─ $row_* (union / diff / inter / subsumes)
         ├─ $graph_* substrate (init / fresh_ty / chase / bind / push_checkpoint / rollback)
         ├─ $env_* substrate (lookup / extend / scope_enter / scope_exit)
         ├─ $verify_* substrate (ledger init / record / discharge_ground)
         └─ WASI helpers (fd_read / fd_write / path_open / proc_exit / fd_close / etc.)

Layer 2: Lexer                          (bootstrap/src/lexer.wat + lex_main.wat)
         └─ Token ADT emit + scan loops + identifier/number/string handlers

Layer 3: Parser                         (bootstrap/src/parser_*.wat — 7 chunks)
         ├─ parser_infra.wat (token consumption + helpers)
         ├─ parser_pat.wat (pattern parsing)
         ├─ parser_fn.wat (fn declaration + lambda)
         ├─ parser_decl.wat (type/effect/handler declarations)
         ├─ parser_expr.wat (expression parsing — all five verbs)
         ├─ parser_compound.wat (records/tuples/lists/match)
         └─ parser_toplevel.wat (file-level dispatch)

Layer 4: Inference + Lower              (bootstrap/src/infer_*.wat + lower_*.wat)
         └─ HM inference + LowIR construction + handler elimination per spec 04+05

Layer 5: Emitter                        (bootstrap/src/emit_*.wat — 6 chunks)
         ├─ emit_data.wat (data section + globals)
         ├─ emit_infra.wat (helpers + alloc invocation)
         ├─ emit_expr.wat (expression emit per LowIR)
         ├─ emit_compound.wat (record/tuple/list/match emit)
         ├─ emit_stmt.wat (statement emit)
         └─ emit_module.wat (module assembly + entry point + WASI imports)

Layer 6: Entry point                    (inline in build.sh OR bootstrap/src/start.wat)
         └─ $_start_fn — read argv + stdin, dispatch subcommand, write WAT to stdout
```

### §2.2 The build.sh assembler

`bootstrap/build.sh` concatenates layers in order. ~150 lines.
Pure shell + Python embedding for the chunk-merge. No `wat2wasm`-
flag drift; standard `--debug-names --enable-tail-call` flags. Per
plan §136: monolithic-output preserves auditability; modular-input
preserves editability.

### §2.3 The cross-module linker pass — bootstrap/src/link.py

Per `BT-bootstrap-triage.md` §3:

The seed compiles each `src/*.mn` + `lib/**/*.mn` independently
(via `wasmtime run bootstrap/mentl.wasm < module.mn > module.wat`).
Per-file outputs reference cross-module symbols (e.g., `(call
$list_index ...)` referencing `lib/runtime/lists.mn`'s definition).
A pre-assembly link pass collects per-file outputs, renames
collisions, deduplicates WASI imports, wires `_start` to
`main.mn`'s `main()`, produces one validated `mentl.wat`.

Scope: ~200 lines Python (bash + awk equivalent acceptable). NOT
Mentl semantics — the linker only resolves symbols + concatenates;
no type-checking, no inference, no emit decisions. Per Anchor 4 +
BT §6 forbidden patterns: no vtable; structured `ModuleId` ADT for
collisions (none expected; structural uniqueness suffices);
exhaustive symbol resolution (every reference resolves OR
compile-fails with named diagnostic).

Per the discipline of "Mentl solves Mentl": `link.py` is the LAST
non-Mentl substrate. Post-first-light, `link_handler` is the
canonical Mentl handler that supersedes `link.py`; per F-retire,
`tools/` dissolves into handlers on the graph.

### §2.4 The first-light harness — bootstrap/first-light.sh

Per §12 First-Light Triangle below. The harness:

```bash
#!/bin/bash
set -euo pipefail

# Assemble bootstrap
bash bootstrap/build.sh

# Validate
wasm-validate bootstrap/mentl.wasm

# Round-trip check (assembler discipline)
wasm2wat bootstrap/mentl.wasm -o /tmp/roundtrip.wat
wat-desugar bootstrap/mentl.wat --stdout > /tmp/canon-original.wat
wat-desugar /tmp/roundtrip.wat --stdout > /tmp/canon-roundtrip.wat
diff /tmp/canon-original.wat /tmp/canon-roundtrip.wat

# Self-compile each src/*.mn + lib/**/*.mn via the seed
for f in src/*.mn lib/**/*.mn; do
  cat "$f" | wasmtime run bootstrap/mentl.wasm > "/tmp/$(basename $f .mn).wat"
done

# Link
python3 bootstrap/src/link.py /tmp/*.wat -o /tmp/inka2.wat

# Assemble + validate seed-of-seed
wat2wasm /tmp/inka2.wat -o /tmp/inka2.wasm --debug-names --enable-tail-call
wasm-validate /tmp/inka2.wasm

# Self-compile via seed-of-seed
for f in src/*.mn lib/**/*.mn; do
  cat "$f" | wasmtime run /tmp/inka2.wasm > "/tmp/inka3-$(basename $f .mn).wat"
done

# Link inka3
python3 bootstrap/src/link.py /tmp/inka3-*.wat -o /tmp/inka3.wat

# The diff — Leg 1 of First-Light Triangle
wat-desugar /tmp/inka2.wat --stdout > /tmp/canon-inka2.wat
wat-desugar /tmp/inka3.wat --stdout > /tmp/canon-inka3.wat
diff /tmp/canon-inka2.wat /tmp/canon-inka3.wat
# Empty = first-light-L1
```

---

## §3 The eight interrogations applied to bootstrap design

Per CLAUDE.md / DESIGN.md §0.5. Eight per kernel primitive;
exhaustive coverage; no skips.

| # | Primitive | What the bootstrap exercises |
|---|-----------|-----------------------------|
| 1 | **Graph + Env** (Query) | The seed implements the graph substrate per spec 00 in WAT (§1.2). Every ADT / Scheme / Reason flows through hand-WAT representations of the graph + env. The seed's own compilation reads source AS substrate; emits WAT AS handler projection. **The Graph IS the seed's substrate too.** |
| 2 | **Handlers + resume discipline** (Propose) | Handler dispatch per §1.3 (closure-record + direct-call OR call_indirect-via-evidence-field; NO vtable). MultiShot continuation per §1.13 (heap-captured struct). The seed encodes handler dispatch in WAT exactly per Mentl semantics; emit-time dispatch resolution per H1. |
| 3 | **Five verbs** (Topology) | Each verb (`\|>` `<\|` `><` `~>` `<~`) has a lowering per spec 05 + spec 10; the seed emits each per its canonical WAT shape. `<~` per §1.12 (state-slot lowering). |
| 4 | **Effect row algebra** (Unlock) | Row primitives per §1.10 + spec 01. Boolean algebra (`+ - & ! Pure`) emit as runtime functions; row subsumption checked at compile time per spec 04. |
| 5 | **Ownership as effect** (Trace) | `own` parameters compile to move semantics (consumed at use); `ref` to pointer-pass-through; `affine_ledger` enforces linearity per spec 07 + H4. The seed's own emit handles ownership-as-effect transparently; no special pass. |
| 6 | **Refinement types** (Verify) | `TRefined(base, _)` emits as `base` per §1.11; `Verify` obligations accumulate in ledger; SMT discharge post-first-light handler swap. The seed handles refinement annotations cleanly today via verify_ledger; verify_smt is a peer handler swap (Arc F.1). |
| 7 | **Annotation gradient** (Teach) | The seed respects every annotation: `with !Alloc` forbids emit of `$alloc` calls in the marked function (detection at inference time via row subsumption); `with Pure` enables memoization paths post-first-light. The annotation gradient IS the seed's optimization signal. |
| 8 | **HM inference + Reasons** (Why) | The seed implements HM per spec 04 in WAT. Every binding records a Reason. Reason chains are graph-resident; the Why Engine walks them per spec 08. The seed itself produces Reason-rich output; `mentl query` reads them; Mentl renders them per IE / F.1 surfaces. |

All eight clear. Bootstrap composes from the eight; per insight #13
(kernel closure 2026-04-24): composition not invention. The
bootstrap doesn't extend the kernel; it implements it in WAT.

---

## §4 Forbidden patterns

Per CLAUDE.md drift modes + Anchor 0 dream-code discipline:

- **Drift 1 (Rust vtable):** no dispatch tables anywhere in the
  seed. Handler dispatch is direct `call` (ground) or
  `call_indirect`-through-closure-evidence-field (polymorphic) per
  §1.3. Any "emit a dispatch_table" pattern is drift; restructure.
- **Drift 5 (C calling convention):** no separate `$closure` +
  `$env` + `$state` parameters. ONE closure-pointer parameter;
  offsets into it for captures + state + evidence. Per H1.
- **Drift 6 (primitive-type-special-case):** Bool compiles like any
  nullary ADT (sentinel path per §1.5). No Bool-specific opcodes,
  no `i32.const 0`-vs-`i32.const 1` shortcuts that bypass the
  variant-dispatch substrate. Per HB.
- **Drift 8 (string-keyed-when-structured):** `EffName` is an ADT
  per spec 01; effect names compile to structured tags; no
  `if str_eq(name, "Alloc") { ... }` runtime dispatch. Per H3.1.
- **Drift 9 (deferred-by-omission):** no `// TODO: implement later`
  comments in seed WAT. Either the surface is implemented OR it's
  out-of-scope for the seed (and named as a follow-up handle in
  this walkthrough's §11 + tracked in plan tracker). Per the LF
  walkthrough §11 riffle-back precedent.
- **Drift 24 (async/await keyword drift):** the seed has no
  `async` / `await` / `Promise` analog. MultiShot continuations
  per §1.13 are the substrate; no keyword vocabulary leaks in.
- **Foreign-language drift in the linker (`bootstrap/src/link.py`):**
  Python is allowed for the LAST non-Mentl substrate per §2.3 +
  Anchor 0 dream-code minimization. Drift discipline: no Python
  list-comprehensions over compiler logic; no dict-as-symbol-table;
  no class-based handlers. The linker IS string-rename + concat;
  any "but should I do X if Y?" moment is the linker drifting into
  semantics — refuse and handle in Mentl substrate post-L1.
- **Generalized fluency-taint check:** any pattern that feels
  "obviously correct" because it's well-established in some
  foreign ecosystem (LLVM IR / Rust MIR / GHC Core / OCaml's
  closure conversion) is candidate drift until proven Mentl-native
  (composes from the eight primitives alone). Per CLAUDE.md
  Mentl's anchor.

---

## §5 WABT tooling — every tool and its bootstrap role

WABT (WebAssembly Binary Toolkit) IS the primary toolchain for
assembling, validating, inspecting, and verifying the seed compiler.
Available via `apt install wabt` or `github.com/WebAssembly/wabt`.

### §5.1 Core pipeline (every commit)

| Tool | Role | When |
|------|------|------|
| `wat2wasm` | WAT text → WASM binary | Every commit touching `bootstrap/**` |
| `wasm-validate` | Validates WASM against spec | Immediately after `wat2wasm`; proves type/structural correctness |

**`wat2wasm` flags:**
```bash
wat2wasm bootstrap/mentl.wat -o bootstrap/mentl.wasm \
  --debug-names         # Preserve $func_name in name section
  --enable-tail-call    # return_call for OneShot handler dispatch
  --enable-exceptions   # try/catch (if structured EH used post-first-light)
  -v                    # Verbose; surface parsing issues early
```

`--enable-all` is forbidden — accepts invalid WAT a stricter flag
set would reject. Use explicit flags matching only what Mentl
requires.

### §5.2 Verification (first-light harness)

| Tool | Role |
|------|------|
| `wasm2wat` | WASM → WAT (round-trip verification) |
| `wat-desugar` | Canonicalizes WAT format (eliminates whitespace/indentation false positives in diff) |
| `wasm-interp` | Stack-based WASM interpreter (no JIT — determinism cross-check vs `wasmtime` JIT) |

Round-trip verification prevents assembler misunderstandings.
Determinism cross-check prevents JIT-dependent behavior.

### §5.3 Inspection (debugging + audit)

| Tool | Role |
|------|------|
| `wasm-objdump` | Section layout, function list, imports/exports, disassembly |
| `wasm-decompile` | WASM → C-like pseudocode (verify behavior without tracing WAT) |
| `wasm-stats` | Module statistics — function count, code size, section sizes |

### §5.4 Production (post-first-light)

| Tool | Role |
|------|------|
| `wasm-strip` | Remove custom/debug sections (production builds) |
| `wasm2c` | WASM → C source (escape hatch for platforms without WASM runtime; distant future) |

### §5.5 WebAssembly 3.0 features Mentl uses

WASM 3.0 standard September 2025; wasmtime v44+ supports stable.

| Feature | Status | Mentl usage | Flag |
|---------|--------|------------|------|
| **Tail calls** | Standard | `return_call` for OneShot handler dispatch | `--enable-tail-call` |
| **128-bit SIMD** | Standard | Future: `v128.*` for DSP/ML (post-first-light item 41) | `--enable-simd` |
| **Multiple memories** | Standard | Not currently used | `--enable-multi-memory` |
| **Exception handling** | Standard | Potential structured-EH post-first-light | `--enable-exceptions` |
| **64-bit memory** | Standard | Not needed pre-first-light | `--enable-memory64` |

**Features Mentl does NOT use:**
- **WasmGC** — Mentl has bump allocator + region-based ownership; no managed GC.
- **Component Model** — Mentl's module system is env-based; components are for language-agnostic composition.
- **WASI 0.2/0.3** — Mentl uses WASI preview1 (`fd_read` / `fd_write` / `path_open` / `proc_exit` / `fd_close` / `path_create_directory` / `path_filestat_get` / `path_unlink_file` / `path_rename` / `fd_readdir`). Preview1 stable; sufficient.

### §5.6 Determinism cross-check (per item 24)

```bash
# wasmtime JIT vs wasm-interp stack interpreter
cat src/*.mn | wasmtime run bootstrap/mentl.wasm > /tmp/out-jit.wat
cat src/*.mn | wasm-interp --run-all-exports bootstrap/mentl.wasm > /tmp/out-interp.wat
diff /tmp/out-jit.wat /tmp/out-interp.wat
# Empty = deterministic (JIT not introducing nondeterminism)
```

Per `tools/determinism-gate.sh` (commit `8c079e7`): full functional
form fires once seed self-hosts; pre-bootstrap exit 2 (gate
contract-only).

---

## §6 Post-edit audit commands

### §6.1 After any bootstrap chunk edit

```bash
bash bootstrap/build.sh
wasm-validate bootstrap/mentl.wasm
wasm-stats bootstrap/mentl.wasm    # verify size matches expectations
wasm-objdump -x bootstrap/mentl.wasm | head -40   # imports/exports sanity
```

### §6.2 After linker (link.py) edit

```bash
# Test against verify.mn (currently the only standalone-validating module)
cat src/verify.mn | wasmtime run bootstrap/mentl.wasm > /tmp/verify.wat
python3 bootstrap/src/link.py /tmp/verify.wat -o /tmp/verify-linked.wat
wat2wasm /tmp/verify-linked.wat -o /tmp/verify-linked.wasm \
  --debug-names --enable-tail-call
wasm-validate /tmp/verify-linked.wasm
```

### §6.3 After any seed-extension that should let a new module compile

Per `BT-bootstrap-triage.md` per-module inventory + plan tracker
A.1 progress:

```bash
# Test against the next-target module (e.g., types.mn after types support added)
cat src/types.mn | wasmtime run bootstrap/mentl.wasm > /tmp/types.wat
python3 bootstrap/src/link.py /tmp/types.wat /tmp/verify.wat -o /tmp/2mod.wat
wat2wasm /tmp/2mod.wat -o /tmp/2mod.wasm --debug-names --enable-tail-call
wasm-validate /tmp/2mod.wasm
```

### §6.4 first-light harness (full Triangle Leg 1)

```bash
bash bootstrap/first-light.sh
# Exit 0 + "Empty = first-light-L1" message = Leg 1 closed
git tag first-light-L1
```

### §6.5 first-light Tier 3 growth (per H7 substrate landing, etc.)

```bash
# Compile H7-extended src/lower.mn via current bootstrap
cat src/lower.mn | wasmtime run bootstrap/mentl.wasm > /tmp/lower-extended.wat
# Diff against current bootstrap's lower section; integrate diff into bootstrap/src/lower_*.wat
# Re-run §6.4 to verify Triangle Leg 1 holds with extension
```

---

## §7 Landing discipline

The bootstrap rewrite (= this walkthrough's substrate work) lands
INCREMENTALLY per Anchor 7 cascade discipline. Each commit:

1. **Cites this walkthrough's relevant §** — every chunk addition
   traces to a §1.x convention paragraph; every linker addition
   traces to §2.3.
2. **Drift-audit clean per `tools/drift-audit.sh`** — runs on `.mn`
   files (the seed's source isn't `.mn`, but any `.mn` substrate
   touched alongside is audited).
3. **Each module-extension commit verifies via §6.3** — when
   extending the seed to handle a new module's surface, the
   per-module compile-and-validate test runs; the commit is what
   makes that module cleanly compile through the seed.
4. **Per Anchor 7 cascade discipline:** sub-handles named
   explicitly (§9); no "deferred-by-omission" tag inside a
   "complete" commit. If a piece of seed work needs its own
   walkthrough, write it first (§13 names known sub-walkthroughs).

**No "big bang" hand-WAT commit.** Per the modular pivot, work
proceeds chunk-by-chunk per layer, validating each addition.

---

## §8 Dispatch

**Bootstrap work is NOT suitable for Sonnet via mentl-implementer.**
Requires deep Mentl-semantic understanding + WAT fluency + per-handle
walkthrough reading — Opus-level judgment throughout.

**Opus inline OR Opus subagent via mentl-planner + mentl-implementer
where the planner is Opus.** The implementer's mechanical-transcription
discipline doesn't match the bootstrap's substrate-design depth.

The linker pass (`bootstrap/src/link.py`) is the one piece small
enough for mentl-implementer dispatch IF given a prescriptive plan;
~200 lines mechanical Python.

---

## §9 Sub-handles — the bootstrap arc decomposition

Per Anchor 7. Each lands in its own commit; walkthrough specifies
the contract; tracker carries gates.

| Handle | Scope |
|--------|-------|
| **Hβ.0** | This walkthrough (revised 2026-04-25 per ultimate-form) |
| **Hβ.runtime** | Layer 1 hand-WAT — bump allocator + str/list/tuple/record primitives + row algebra + graph substrate + WASI helpers. Per §2.1 + §1 conventions. |
| **Hβ.lex** | Layer 2 — Token ADT emit + scan loops + lexer chunks. |
| **Hβ.parse** | Layer 3 — parser_*.wat 7 chunks. |
| **Hβ.infer** | Layer 4 — HM inference per spec 04. |
| **Hβ.lower** | Layer 4 — LowIR construction + handler elimination per spec 05 + H7 MS substrate. |
| **Hβ.emit** | Layer 5 — emit_*.wat 6 chunks. |
| **Hβ.start** | Layer 6 — `_start_fn` argv dispatch + WASI scaffolding. |
| **Hβ.link** | bootstrap/src/link.py cross-module linker pass per §2.3 + BT walkthrough. |
| **Hβ.harness** | bootstrap/first-light.sh per §2.4. |
| **Hβ.module-extensions** | Per-module substrate gaps per BT walkthrough §2 + §11 of this walkthrough. Each module that the seed currently fails on (per BT inventory + my §11 finding) gets its own sub-handle. |
| **Hβ.tier3** | Post-L1 incremental self-host growth pattern per §12.1. Each substrate landing in `src/*.mn` (H7 / B.3 Choice / B.5 AM / B.7 threading / etc.) follows the Tier 3 grow + diff + audit cycle. |

Each sub-handle lands as its own peer commit per Anchor 7.

---

## §10 Riffle-back protocol

Per `LF-feedback-lowering.md` §11 precedent (commit `5681202`):
every walkthrough that lands substrate gets a riffle-back addendum
naming what landed exactly, what landed differently and why, and
what didn't land (named as peer sub-handles).

For Hβ: as each Hβ.* sub-handle lands substrate, the relevant §
gets a riffle-back annotation stating:
- What this section's design intended (the ultimate-form spec)
- What landed exactly
- What landed differently (with reasoning)
- What didn't land (named follow-up sub-handle)

Per insight #12 (Realization Loop): each substrate landing earns a
discipline-lock-in commit citing the substrate commit SHA. The
walkthrough stays the contract; the addendum records the residue
between intent and substrate.

---

## §11 Per-file compile diagnosis (NEW 2026-04-25)

**The substrate gap explicitly named.**

**Finding (2026-04-25):** the current seed (`bootstrap/mentl.wasm`)
produces degenerate WAT for `src/graph.mn` and presumably the
other 13/15 modules per BT walkthrough §2. Test:

```bash
$ cat src/graph.mn | wasmtime run bootstrap/mentl.wasm > /tmp/graph.wat
$ wc -l /tmp/graph.wat
34 lines
$ wat2wasm /tmp/graph.wat ...
error: undefined local variable "$runtime"
error: undefined local variable "$strings"
```

The seed parses graph.mn's imports (`import types`, `import effects`,
`import runtime/strings`) and emits a stub `_start_fn` referencing
the import names as undefined locals. **This is NOT the cross-module-
ref failure BT walkthrough §1 describes** (where seed-emitted
`(call $list_index)` references a sibling module's function); it's
SEED-side parsing/emit incompleteness for the .mn surface that
src/graph.mn uses.

**The bootstrap rewrite IS the corrective work.** Per the
recontextualization 2026-04-25: the current seed is half-written,
pre-real-decisions; the rewrite proceeds per this walkthrough's
ultimate-form contract. The path:

1. **Hβ.runtime + Hβ.lex** — Layer 1 + Layer 2 substrate per §1
   conventions. Verify against verify.mn (currently the only
   standalone-validating module per BT §1).
2. **Hβ.parse extensions** — extend parser chunks to handle the
   full surface src/*.mn uses (every node-kind every src/*.mn file
   produces). Per-module test cycle per §6.3.
3. **Hβ.infer + Hβ.lower** — Layer 4 substrate per spec 04 + spec
   05 + H7 walkthrough.
4. **Hβ.emit** — Layer 5 substrate per §1 + per-spec contracts.
5. **Hβ.link** — link.py per §2.3.
6. **Hβ.module-extensions** — per-module substrate gaps surface as
   the seed extends; each gap closed in its own commit; BT
   walkthrough's per-module inventory tracks progress.

When all 15 src/*.mn + lib/**/*.mn modules compile cleanly + link
into one validated `mentl.wasm`, **first-light-L1 is achievable.**
Tier 3 growth follows post-L1 per §12.1.

**Riffle-back to BT walkthrough §1:** BT's "14/15 compile through
pipeline; fail to validate due to cross-module refs" framing is
partially aspirational. Reality: 1/15 produces validating WAT;
14/15 produce degenerate WAT (likely past the parser layer). BT
walkthrough's per-module inventory needs riffle-back addendum
naming this finding.

---

## §12 First-Light Triangle — three legs, not one diff

*Per §12 of prior Hβ + plan §1721. Three independent fitness tests;
all three must pass for the substrate to claim completeness.*

```
                   ▲
                  / \
                 /   \
                /     \
              L1       L2
    (byte-identical)  (self-verifying)
              /         \
             /           \
            ───── L3 ─────
          (cross-domain capability)
```

### §12.1 Leg 1 — Byte-identical self-compilation

**Test:** `bash bootstrap/first-light.sh` exits 0 with `diff
inka2.wat inka3.wat` empty.

**Proves:** the compiler's output, compiled by itself, produces
identical compiler. The ouroboros topology closes. **Self-
consistency.**

**Path to L1:** Hβ.runtime through Hβ.harness per §9; per-module
extension cycle per §6.3 + §11; full src/*.mn + lib/**/*.mn
compiles cleanly; linker output validates; self-compile diff empty.

**No H7 dependency for L1.** Per plan §21 + §1721 structural insight:
self-compile exercises `@resume=OneShot` only; MultiShot ops in
src/mentl.mn + src/mentl_oracle.mn are DECLARED but not invoked
during self-compile (Mentl's voice surfaces don't fire during
compile-time; they're surface concerns). L1 closes without H7
substrate.

### §12.2 Leg 2 — Self-verifying refinement witness

**Test:** the compiler's own substrate uses a refinement annotation
that `verify_ledger` discharges at compile time; swapping to
`verify_smt` (handler swap per Arc F.1) produces identical output
for statically-decidable obligations.

**Witness candidates (per FV.3 landings):**
- `Handle = Int where 0 <= self` (FV.3 commit `f7c6774`)
- `TagId` per FV.3.1
- `ValidOffset` per FV.3.2 (lexer byte positions)
- `ValidSpan` per FV.3.4 (parser/infer span construction sites)

**Fitness:**
- `mentl check src/graph.mn` accumulates V_Pending obligations.
- `mentl check --with verify_smt src/graph.mn` discharges
  ground-handle obligations (>95% per H1); residue is polymorphic
  minority.
- Output byte-identical for discharged obligations.

**Proves:** the compiler's own substrate hosts non-trivial
refinement claims AND swaps the proof handler without source
change. **The handler-swap thesis runs on the compiler itself.**

**Path to L2:** Arc F.1 substrate (`verify_smt` handler + theory
classifier per `VK-verify-kernel.md` walkthrough — pending). NOT
blocked by L1; can progress in parallel.

### §12.3 Leg 3 — Cross-domain crucible pass

**Test:** the six crucibles per `CRU-crucibles.md` (`crucible_dsp`
+ `crucible_ml` + `crucible_realtime` + `crucible_web` +
`crucible_oracle` + `crucible_parallel`) all compile through the
bootstrapped compiler and each meets its documented fitness
criterion.

**Proves:** the thesis — "every domain is a handler stack on one
substrate" — holds across all six named domains. The medium
actually reaches.

**Path to L3:**
- Crucible seeds land per CRU walkthrough.
- Each crucible's substrate gap closes (H7 unblocks crucible_oracle;
  Choice unblocks crucibles needing search; arena_ms unblocks
  speculative MS; threading unblocks crucible_parallel; LFeedback
  unblocks crucible_realtime; Ultimate DSP/ML unblock crucible_dsp
  + crucible_ml).
- Each crucible compiles + runs + meets fitness.

**Substrate dependencies:** B.2 H7 + B.3 CE + B.4 race + B.5 AM +
B.7 threading + B.9 LFeedback + B.10 Ultimate DSP + B.11 Ultimate
ML. Each per its own walkthrough.

### §12.4 The combined fitness claim

**First-light is `L1 ∧ L2 ∧ L3`.** All three legs pass.

**Tagging discipline:**
- `first-light-L1` tag when Leg 1 passes.
- `first-light-L2` tag when Leg 2 joins.
- `first-light` tag ONLY when all three pass.

Partial victory gets partial credit; the full tag waits for the
triangle.

### §12.5 Tier 3 growth — Mentl bootstraps through Mentl

**Per Morgan's 2026-04-20 decision + plan §1727:** hand-WAT is the
reference soundness artifact, kept forever. Growth past L1 is via
Tier 3 incremental self-hosting — never via a foreign-language
translator.

**The pattern:**
1. New substrate lands in `src/*.mn` per its walkthrough (H7 / CE
   / AM / verify_smt / threading / Ultimate DSP/ML / etc.).
2. The L1-level seed compiles the extended `src/*.mn` via
   VFINAL-on-partial-WAT: each module per dependency order
   (§2.1 layers).
3. Output WAT diffed against current `bootstrap/mentl.wat`.
4. New regions (e.g., MS-emit patterns for `LMakeContinuation`
   per H7) integrated into hand-WAT chunks; each addition traces
   to a §1 convention entry (extend §1 first if needed).
5. Audit: per-walkthrough-paragraph trace; commit when clean.

**Mentl bootstraps through Mentl.** Per insight #13 (kernel closure)
+ Anchor 0 (dream code) + Anchor 4 (build the wheel).

**Continue Tier 3 growth when:**
- Each new line traces to a walkthrough paragraph.
- Every pattern in hand-WAT appears in §1 conventions list (extend
  §1 FIRST, then transcribe).
- VFINAL-on-partial-WAT compiles at least one additional module
  each growth cycle (Tier 3 closing monotonically).
- Morgan + Opus can audit the growth patch paragraph-by-paragraph
  in one sitting.

**Stop and reshape (NOT pivot to a foreign tool) when:**
- Hand-WAT duplicates Mentl substrate logic (walkthrough
  underspecified; extend walkthrough; re-derive shape).
- Walkthrough paragraph → hand-WAT line mapping no longer
  traceable (re-audit + restructure).
- Required extension has no walkthrough paragraph (write
  walkthrough first; resume emission only when contract on the
  page).

**No temporal criteria.** Scope is consequence of substrate
necessity, not input to pivot decision.

---

## §13 The bootstrap rewrite path — what proceeds from this walkthrough

Per the 2026-04-25 recontextualization + ultimate-form discipline:

**The current seed at `bootstrap/mentl.wat` (4733 lines, modular
chunks at `bootstrap/src/`) is half-written pre-real-decisions.**
Per Anchor 0: it's the lathe, not the wheel. The walkthroughs ARE
the wheel. The rewrite IS the work.

**Sequencing per Anchor 7 cascade discipline:**

1. **Hβ.0 walkthrough** — this rewrite (commits with this file).
2. **BT walkthrough §11 riffle-back addendum** — name the per-file
   compile diagnosis finding from my 2026-04-25 session; corrects
   BT's per-module inventory framing.
3. **Hβ.runtime sub-handle** — Layer 1 substrate per §2.1 + §1
   conventions; the foundation every other layer composes on.
   Verify against verify.mn + a minimal hello-world program.
4. **Hβ.lex + Hβ.parse + Hβ.infer + Hβ.lower + Hβ.emit** — per
   layer order; each chunk extends the seed's surface coverage.
   Per-module compile-and-validate test cycle per §6.3.
5. **Hβ.link sub-handle** — link.py per §2.3 + BT.
6. **Hβ.module-extensions** — per BT inventory; each src/*.mn
   module that fails compilation gets a substrate-gap-closing
   commit. Per Anchor 7: each in its own commit.
7. **Hβ.harness sub-handle** — first-light.sh per §2.4.
8. **first-light-L1 tag** when §6.4 succeeds.
9. **Tier 3 growth per §12.5** — every subsequent substrate
   landing extends hand-WAT via the diff-into-bootstrap pattern.
10. **first-light-L2 tag** when verify_smt witness discharges (Arc
    F.1 substrate).
11. **first-light tag** when all six crucibles pass.

**Estimated scope:** ~50-150k lines WAT total across all chunks +
~200 lines link.py + ~200 lines first-light.sh. The work is
substantive but mechanical per the walkthroughs — design lives in
the cascade walkthroughs (DESIGN + INSIGHTS + SYNTAX + per-spec +
per-handle); this walkthrough + per-handle walkthroughs specify
the WAT shape; transcription proceeds per Anchor 0 register.

**Sub-walkthroughs the bootstrap rewrite may need (named
peer-sub-handles per Anchor 7):**

- `Hβ-runtime-conventions.md` — granular substrate per §1.1-1.7
  if §1 proves underspecified during emission; extension if needed.
- `Hβ-link-protocol.md` — granular linker substrate per §2.3 if
  link.py's symbol-resolution discipline needs deeper specification.
- `Hβ-tier3-growth.md` — granular Tier 3 growth pattern per §12.5
  if each substrate landing's diff-into-bootstrap needs its own
  contract.

Each sub-walkthrough is its own peer commit per Anchor 7; only
written when proven necessary by emission experience.

---

## §14 What closes when Hβ + sub-handles close

- `bootstrap/mentl.wat` exists as the seed compiler's binary image,
  modularly assembled, fully covering the src/*.mn + lib/**/*.mn
  surface.
- `bootstrap/first-light.sh` runs and produces empty diff
  → `first-light-L1`.
- Tier 3 growth path active per §12.5; every subsequent substrate
  landing extends hand-WAT.
- `first-light-L2` tag joins when verify_smt witness discharges.
- `first-light` tag joins when all six crucibles pass.
- Hand-WAT preserved forever as reference soundness artifact per
  Anchor + DESIGN §11.
- `mentl edit` substrate ships on a self-compiling foundation per
  IE walkthrough §12 dependencies.
- F.1 substrate ships per F.1 walkthrough §13 dependencies; web
  IDE / playground / tutorial-space all compose on `mentl.wasm`
  running in-browser.
- `mentl doc` + `mentl teach` + `mentl audit` + `mentl query` + `mentl
  test` + `mentl chaos` + every `mentl --with <handler>` entry-handler
  invocation works.
- The realization loop closes per insight #11 + #12: substrate
  → bootstrap → self-host → substrate landings → Tier 3 growth
  → audit → next substrate. Compound interest of self-reference
  per insight #12 raises future-session altitude.

---

## §15 Connection to the kernel

Per CLAUDE.md / DESIGN.md §0.5 — the bootstrap composes from the
eight primitives; nothing extends the kernel; per insight #13
(kernel closure 2026-04-24): composition not invention. The
bootstrap implements the kernel in WAT; it doesn't extend it.

| # | Primitive | Bootstrap exercise |
|---|-----------|--------------------|
| 1 | **Graph + Env** | §1.2 implementation |
| 2 | **Handlers + resume discipline** | §1.3 + §1.13 implementation |
| 3 | **Five verbs** | §1.12 (`<~`) + spec 05 + spec 10 lowering |
| 4 | **Effect row algebra** | §1.10 implementation |
| 5 | **Ownership as effect** | §1 ownership erasure (move/borrow → emit semantics) |
| 6 | **Refinement types** | §1.11 (TRefined → base type emit; Verify obligations) |
| 7 | **Annotation gradient** | §1 emit respects every annotation; row-subsumption gates |
| 8 | **HM inference + Reasons** | §1 spec 04 implementation; Reasons graph-resident |

**Mentl tentacle mapping.** The bootstrap doesn't directly invoke
Mentl — Mentl's voice surfaces at user-cursor / batch-doc time, not
at compile time. But the seed must EMIT correct WAT for the
Mentl-voice substrate (`src/mentl_voice.mn` + `src/mentl_oracle.mn`
+ `src/mentl_lsp.mn` + `src/mentl.mn` + `lib/edit/*.mn` per IE +
`lib/doc/*.mn` per F.1) so those surfaces work post-first-light.

---

*Mentl solves Mentl. The bootstrap is hand-WAT, transcribed from the
walkthroughs, kept forever. Mentl's voice doesn't fire during
self-compile, but Mentl's substrate IS what self-compile proves
correct — by emitting it identically to the seed's prior pass. The
fixed point IS the soundness proof; the soundness proof IS the
medium's binary self-portrait.*

*Per Anchor 0 dream-code discipline: this walkthrough specifies the
bootstrap's ultimate form assuming src/*.mn is the substantively-
real wheel (per plan §16). Plan tracker carries gates; walkthrough
carries the contract. The architecture rises to meet what's
specified. Mentl bootstraps through Mentl.*
