# Hβ.link — bootstrap cross-module linker protocol

> **Status:** `[DRAFT 2026-04-25]`. Sub-walkthrough peer to
> `Hβ-bootstrap.md` (commit `95fdc3c`) + `Hβ-infer-substrate.md`
> (commit `729ee59`) + `Hβ-lower-substrate.md` (commit `973c123`).
> Names the design contract for `bootstrap/src/link.py` per Hβ §2.3
> + BT-bootstrap-triage.md §3 + §5 + §6.
>
> **Authority:** `CLAUDE.md` Mentl's anchor + Anchor 0 (dream code) +
> Anchor 7 (cascade discipline); `docs/specs/simulations/Hβ-bootstrap.md`
> §2.3 (link.py named as the LAST non-Inka substrate; ~200 lines
> Python; post-first-light dissolves into `link_handler` on the
> graph per F-retire); `docs/specs/simulations/BT-bootstrap-triage.md`
> §3 (the linking work — what closing the gap actually requires) +
> §5 (recommended path: leaves-first, sequential close-out) + §6
> (forbidden patterns); `docs/PLAN.md` Decisions Ledger entry
> 2026-04-23 (modular bootstrap pivot — link.py composes on the 15+
> `bootstrap/src/*.wat` chunks + the seed-emitted per-module
> partial WATs).
>
> *Claim in one sentence:* **link.py is the LAST non-Inka substrate
> in the bootstrap path: a ~200-line Python pre-assembly pass that
> reads per-module WAT outputs from the seed (and the modular
> `bootstrap/src/*.wat` chunks themselves), renames cross-module
> symbol collisions per `<module>__<symbol>` discipline, deduplicates
> WASI imports, wires `_start` to `main.nx`'s compiled `main()`,
> and emits one assembled `inka.wat` that wat2wasm compiles. Per
> Anchor 4 + Hβ §0: this is the residue between modular substrate
> and monolithic-binary self-portrait. Post-first-light, link.py
> dissolves into `link_handler` on the graph per F-retire.**

---

## §0 Framing — what Hβ.link resolves

### 0.1 What Hβ.link does

The seed compiler (post-Hβ.lex/parse/infer/lower/emit per their
respective walkthroughs) is invoked per-module:

```bash
cat src/types.nx    | wasmtime run bootstrap/inka.wasm > /tmp/types.wat
cat src/effects.nx  | wasmtime run bootstrap/inka.wasm > /tmp/effects.wat
cat src/graph.nx    | wasmtime run bootstrap/inka.wasm > /tmp/graph.wat
... (one invocation per .nx file)
```

Each per-module WAT carries:
- The module's compiled functions (handler bodies, helper fns,
  type/effect/handler scheme registrations).
- Module-local symbol references (e.g., `(call $list_index ...)`
  referencing lib/runtime/lists.nx's definition).
- WASI imports it requires.

**Hβ.link's job:** consume the per-module WATs + the modular
`bootstrap/src/*.wat` runtime chunks (which the seed itself
already assembled per Wave 2.A factoring) + emit one validated
`inka.wat` with all cross-module references resolved.

Per BT §3:
1. Collect every .wat file's exports (top-level fn, effect,
   handler, type declarations + their symbols).
2. Collect every .wat file's imports (external symbols referenced).
3. Rename to avoid collision (`<module>__<symbol>` discipline per
   Q-A.1.1 — single-namespace emit; structural uniqueness sufficient).
4. Deduplicate WASI imports (each preview1 import declared once).
5. Wire `_start` to `main.nx`'s `main()`.
6. Emit assembled `inka.wat`.

Per BT §3 alternative scope: ~200 lines Python.

### 0.2 Why Python (not Inka) for this LAST non-Inka substrate

Per Hβ §2.3 + §4 forbidden patterns:

> Python is allowed for the LAST non-Inka substrate per §2.3 +
> Anchor 0 dream-code minimization. Drift discipline: no Python
> list-comprehensions over compiler logic; no dict-as-symbol-table;
> no class-based handlers. The linker IS string-rename + concat;
> any "but should I do X if Y?" moment is the linker drifting into
> semantics — refuse and handle in Inka substrate post-L1.

The linker is symbol-renaming + WAT-text-concatenation + WASI-
import-dedup. Pure string + token operations; no inference, no
type-checking, no emit decisions. Python is sufficient because
the work is literally text manipulation.

Bash + awk would also suffice; Python wins by clarity for the
~200-line scope. Per Hβ §2.3:

> NOT Inka semantics — the linker only resolves symbols + concatenates;
> no type-checking, no inference, no emit decisions.

Per F-retire (residue tracker §F-retire): post-first-light,
`link_handler` is a canonical Inka handler that supersedes link.py;
`tools/` and `bootstrap/src/link.py` dissolve into handlers on the
graph. Until then, link.py is the substrate-honest interim.

### 0.3 What Hβ.link does NOT do

- **Type-checking.** Hβ.infer (sibling walkthrough). The seed
  type-checks per-module before emit; link.py never re-checks.
- **Inference.** Hβ.infer.
- **Lowering.** Hβ.lower.
- **WAT emission.** Existing emit_*.wat chunks + seed.
- **Handler dispatch resolution.** Hβ.lower's $monomorphic_at +
  $classify_handler decided this; emit produced direct-call vs
  call_indirect; link doesn't touch dispatch.
- **Effect-row inference.** Done at infer time; link sees compiled
  WAT only.
- **WASM validation.** wat2wasm + wasm-validate are post-link
  steps in `bootstrap/build.sh` / `bootstrap/first-light.sh`.

---

## §1 Inputs

### 1.1 The `bootstrap/src/*.wat` runtime chunks

Per Wave 2.A factoring + INDEX.tsv:
```
bootstrap/src/runtime/{alloc,wasi,str,int,list,record,closure,cont,
                       graph,env,row,verify,wasi_fs}.wat
bootstrap/src/lexer_data.wat
bootstrap/src/lexer.wat
bootstrap/src/lex_main.wat
bootstrap/src/parser_*.wat                  ;; 7 chunks
bootstrap/src/emit_*.wat                    ;; 6 chunks
bootstrap/src/infer/*.wat                   ;; 10 chunks per Hβ-infer-substrate.md
bootstrap/src/lower/*.wat                   ;; 11 chunks per Hβ-lower-substrate.md
```

These chunks share a single-namespace function-symbol convention
(prefixes like `$str_`, `$list_`, `$graph_`, etc.); no rename
needed at link time. They're already pre-rename per the per-chunk
convention.

### 1.2 The per-module compiled WATs

Each invocation of the seed against one `.nx` source file produces
one `.wat` file. Per BT §3 + the seed's emit chunk discipline (per
Hβ-bootstrap.md §1.15 entry-handler installation):

Each per-module WAT contains:
- Function definitions for every top-level `fn` + handler arms.
- Type/effect/handler scheme metadata (compiled into init-time
  functions + data segments).
- References to Layer 1 runtime primitives ($alloc, $str_eq, etc.).
- References to other modules' exports (e.g., src/graph.nx's
  compiled output references types declared in src/types.nx).

Per the seed's emit discipline: **module-local symbols are NOT yet
prefixed with `<module>__` at seed-emit time.** link.py performs
the rename (this avoids the seed needing to know the full module
graph at emit time; emit produces unprefixed names; link prefixes).

### 1.3 The dependency graph

link.py reads the dependency graph from a manifest file
`bootstrap/link-manifest.tsv` (or derives from the seed's emit
metadata; manifest is simpler):

```tsv
# Per-module import declarations (one row per module → import edge)
module          imports
types.nx        runtime/strings, runtime/lists
effects.nx      types, runtime/strings
graph.nx        types, effects, runtime/strings
... (one row per src/*.nx + lib/**/*.nx)
```

Manifest is generated by a one-shot `bootstrap/scripts/manifest.sh`
script that scans `import` lines from each `.nx` file. Trivial
shell + awk; not part of link.py itself.

---

## §2 The protocol — symbol rename + concat + dedup

### 2.1 Phase 1 — collect exports

Walk each input WAT. Parse top-level `(func $name ...)` + `(global
$name ...)` + `(memory ...)` + `(data ...)` declarations. Build:

```python
exports: dict[str, list[(module, sym, decl_text)]]  # symbol → [(module, sym, decl)]
```

Per Q-A.1.1 (per BT §6 forbidden patterns): structurally unique
names are the COMMON case; `<module>__<symbol>` rename is a
defensive collision-resolver, not the primary mechanism.

For Wave 2.A runtime chunks: chunk-level `$str_eq`, `$graph_chase`,
etc. have unique names by convention. Per-module compiled WATs may
collide (e.g., two modules each defining a top-level `$main` —
which is normal at the seed-emit level).

### 2.2 Phase 2 — rename collisions

Per Hβ §2.3 + BT §3 + Q-A.1.1 single-namespace emit:

```python
def rename(symbol: str, module: str) -> str:
    """If symbol collides across modules, prefix with <module>__.
    Per BT §6 drift mode 3: structured ModuleId; not flat hash."""
    if collision_count(symbol) > 1:
        return f"{module}__{symbol}"
    return symbol  # No collision — keep original name
```

Renames are applied to:
- The function/global declaration itself.
- Every reference to the renamed symbol within ANY module's WAT.

Reference rewriting is text-substitution per `(call $<original>)`
→ `(call $<renamed>)`. Same for globals (`(global.get $<...>)`
→ `(global.get $<renamed>)`).

Module name derivation: `src/graph.nx` → `graph`; `lib/runtime/lists.nx`
→ `runtime__lists`. The `<module>` part of `<module>__<symbol>`
preserves directory structure via `__` separator (e.g.,
`graph__make_node` for src/graph.nx's $make_node OR
`runtime__lists__list_index` for lib/runtime/lists.nx's $list_index
when collision-resolved).

### 2.3 Phase 3 — deduplicate WASI imports

Each per-module WAT may declare WASI imports (`(import
"wasi_snapshot_preview1" "fd_write" ...)`). The assembled inka.wat
needs each WASI import declared exactly once.

```python
def dedup_imports(all_wats: list[str]) -> list[str]:
    """Collect (namespace, name, type_sig) tuples; emit each once."""
    seen = set()
    deduped = []
    for wat in all_wats:
        for imp in extract_imports(wat):
            key = (imp.namespace, imp.name, imp.type_sig)
            if key not in seen:
                seen.add(key)
                deduped.append(imp.text)
    return deduped
```

Per Hβ-bootstrap.md §2.1 Layer 0 + Wave 2.A build.sh: the inline
Layer 0 shell already declares 10 WASI imports (`fd_read`,
`fd_write`, `fd_close`, `path_open`, `proc_exit`,
`path_create_directory`, `path_filestat_get`, `path_unlink_file`,
`path_rename`, `fd_readdir`). Per-module WATs requesting any of
these are deduplicated against the shell's declarations (the
shell's count as canonical; per-module duplicates dropped).

### 2.4 Phase 4 — wire `_start`

The assembled inka.wat needs ONE `(func $sys_main (export "_start") ...)`.
This comes from `main.nx`'s compiled `main()`:

```wat
(func $sys_main (export "_start")
  (call $main__main)        ;; or whatever the renamed main symbol is
  (call $wasi_proc_exit (i32.const 0)))
```

The seed's emit produces an unwired `$main_module__main` (or whatever
main.nx's compiled function name is); link.py wraps it in `_start`
+ adds proc_exit. Per Hβ-bootstrap.md §1.15 entry-handler convention:
`inka <verb>` resolves to `<verb>_run` handler installation; the
seed's emit places that resolution at compile-time, link.py just
wires the resulting `main()` invocation.

For self-compile: the seed's `$sys_main` per Hβ-bootstrap.md
build.sh Layer 5 inline already does this. link.py extends the
pattern when assembling per-module WATs from a more complex
program (the wheel itself).

### 2.5 Phase 5 — concatenate + emit

Per Hβ-bootstrap.md §2.1 Layer structure:

```
Layer 0: Module shell             (inline, from build.sh template)
Layer 1: Runtime chunks           (concatenated in dep order)
Layer 2-5: Lex / Parse / Infer / Lower / Emit chunks  (concat)
Per-module compiled WATs          (with renames applied; concat)
Layer 6: Entry point               (inline _start with main wiring)
Module close                      (closing `)`)
```

Output: one inka.wat written to stdout (or `-o` flag-specified path).

### 2.6 Validation hooks

Optional: link.py runs `wat2wasm --no-debug-names <output>.wat -o
/dev/null` as a quick sanity check before exiting. If the assembled
WAT doesn't even pass wat2wasm's parser, link.py's bug — not the
seed's. Surfaces structural errors immediately.

---

## §3 The Python skeleton — ~200 lines

```python
#!/usr/bin/env python3
"""bootstrap/src/link.py — pre-assembly cross-module linker per Hβ.link.

Per Hβ-link-protocol.md + BT-bootstrap-triage.md §3 + Hβ §2.3.
Symbol rename + WASI import dedup + _start wiring. Pure text
manipulation; no compiler semantics.

Per CLAUDE.md anchor: this is the LAST non-Inka substrate. Post-
first-light, link_handler on the graph supersedes per F-retire.
"""

import sys
import re
from pathlib import Path
from typing import NamedTuple


class WatModule(NamedTuple):
    module_name: str
    text: str
    funcs: list[str]      # function names declared (without leading $)
    globals: list[str]    # global names declared
    imports: list[str]    # full import declaration texts


# ─── Phase 1: parse module exports + imports ────────────────────────

FUNC_DECL_RE = re.compile(r'\(func\s+\$([\w]+)')
GLOBAL_DECL_RE = re.compile(r'\(global\s+\$([\w]+)')
IMPORT_DECL_RE = re.compile(r'\(import\s+"[^"]+"\s+"[^"]+"\s*\([^)]+\)\s*\)', re.DOTALL)


def parse_module(path: Path) -> WatModule:
    text = path.read_text()
    funcs = FUNC_DECL_RE.findall(text)
    globals_ = GLOBAL_DECL_RE.findall(text)
    imports = IMPORT_DECL_RE.findall(text)
    module_name = path.stem
    return WatModule(module_name, text, funcs, globals_, imports)


# ─── Phase 2: collision detection + rename map ──────────────────────

def build_rename_map(modules: list[WatModule]) -> dict[tuple[str, str], str]:
    """Returns (module_name, original_symbol) → renamed_symbol.
    Renames only when a symbol collides across modules per Q-A.1.1."""
    counts: dict[str, int] = {}
    for m in modules:
        for sym in m.funcs + m.globals:
            counts[sym] = counts.get(sym, 0) + 1
    renames: dict[tuple[str, str], str] = {}
    for m in modules:
        for sym in m.funcs + m.globals:
            if counts[sym] > 1:
                renames[(m.module_name, sym)] = f"{m.module_name}__{sym}"
            else:
                renames[(m.module_name, sym)] = sym
    return renames


def apply_renames(module: WatModule, renames: dict[tuple[str, str], str]) -> str:
    """Substitute every $sym occurrence in the module's text with its
    renamed form. References to symbols defined in OTHER modules
    rename per the global map (each $sym anywhere in the WAT text
    gets the latest rename)."""
    text = module.text
    # Sort by length descending so longer names rename first (avoids
    # partial matches on shorter prefixes).
    all_syms = sorted({(m_name, s) for (m_name, s) in renames.keys()
                       if renames[(m_name, s)] != s},
                      key=lambda t: -len(t[1]))
    for (_m, sym) in all_syms:
        new = renames[(_m, sym)]
        text = re.sub(rf'\$\b{re.escape(sym)}\b', f'${new}', text)
    return text


# ─── Phase 3: WASI import dedup ─────────────────────────────────────

def dedup_imports(modules: list[WatModule]) -> list[str]:
    seen: set[str] = set()
    deduped: list[str] = []
    for m in modules:
        for imp in m.imports:
            key = imp.strip()
            if key not in seen:
                seen.add(key)
                deduped.append(imp)
    return deduped


# ─── Phase 4: assemble + emit ───────────────────────────────────────

MODULE_SHELL_HEADER = """;; inka.wat — Reference Seed Compiler (assembled by link.py)
;; Per Hβ-link-protocol.md.

(module
"""

MODULE_SHELL_FOOTER = """  ;; ─── Entry Point (link.py wired) ───
  (func $sys_main (export "_start")
    (call ${main_call})
    (call $wasi_proc_exit (i32.const 0)))
)
"""


def emit_assembled(modules: list[WatModule], renames, main_call: str) -> str:
    parts = [MODULE_SHELL_HEADER]
    parts.append("\n".join(dedup_imports(modules)))
    parts.append("\n  (memory (export \"memory\") 512)\n  (global $heap_base i32 (i32.const 4096))\n  (global $heap_ptr (mut i32) (i32.const 1048576))\n")
    for m in modules:
        # Strip imports + module shell from per-module WATs (they were
        # produced as standalone modules; we extract just the body).
        body = strip_module_shell(apply_renames(m, renames))
        parts.append(body)
    parts.append(MODULE_SHELL_FOOTER.format(main_call=main_call))
    return "\n".join(parts)


def strip_module_shell(text: str) -> str:
    """Remove the leading `(module` + WASI imports + memory + globals +
    trailing `)`. Each per-module WAT produced by the seed wraps its
    body in a module shell; link.py concatenates bodies into one shell."""
    text = re.sub(r'^\s*\(module[^\n]*\n', '', text)  # leading (module
    text = re.sub(r'\(import[^)]+\)[^)]*\)\n', '', text)  # imports
    text = re.sub(r'\(memory[^)]+\)\n', '', text)  # memory
    text = re.sub(r'\(global\s+\$heap_(base|ptr)[^)]+\)\n', '', text)
    text = re.sub(r'\)\s*$', '', text)  # trailing )
    return text


# ─── Main ───────────────────────────────────────────────────────────

def main(argv: list[str]) -> int:
    if "-o" not in argv or len(argv) < 4:
        print("usage: link.py <module1.wat> [<module2.wat> ...] -o <output.wat>",
              file=sys.stderr)
        return 1
    out_idx = argv.index("-o")
    inputs = [Path(a) for a in argv[1:out_idx]]
    output = Path(argv[out_idx + 1])
    modules = [parse_module(p) for p in inputs]
    renames = build_rename_map(modules)
    # Identify main: the symbol from main.nx's module that's labeled "main".
    main_module = next((m for m in modules if m.module_name == "main"), None)
    if main_module is None:
        print("error: no main.nx in input modules", file=sys.stderr)
        return 1
    main_call = renames.get(("main", "main"), "main__main")
    output.write_text(emit_assembled(modules, renames, main_call))
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv))
```

~200 lines. No semantics — pure text manipulation per Hβ §2.3.

---

## §4 Per-edit-site eight interrogations

Hβ.link is the LAST non-Inka substrate; the eight interrogations
apply at the architectural-discipline altitude (does this work
match Inka's substrate-honest discipline?), not at the per-line-of-
Python altitude (Python isn't a kernel-primitive substrate).

| # | Primitive | Answer |
|---|-----------|--------|
| 1 | **Graph?** | link.py reads NO graph. The graph IS the seed's compile-time substrate; link.py operates on POST-emit WAT text. |
| 2 | **Handler?** | link.py is invoked by `bootstrap/build.sh` (or first-light.sh) as a shell sub-process. Pure stateless text manipulation; no handler abstraction needed. |
| 3 | **Verb?** | N/A — Python script. |
| 4 | **Row?** | N/A — text manipulation. |
| 5 | **Ownership?** | Each per-module WAT file is `ref` (read-only); output WAT is `own` (link.py writes). |
| 6 | **Refinement?** | Optional: refinement on `<module>__<symbol>` — must contain `__` separator + valid WAT-symbol-name characters. |
| 7 | **Gradient?** | N/A. |
| 8 | **Reason?** | Each rename / dedup operation is in line with BT §3 contract; logged to stderr in verbose mode for debugging. |

---

## §5 Forbidden patterns

Per Hβ §2.3 + BT §6 + the discipline of "this is Python so be
EXTRA careful about substrate drift."

### 5.1 No semantics in link.py

- **NO type-checking.** Hβ.infer's job. link.py never parses Ty
  variants or EffRow representations.
- **NO inference.** link.py never reasons about whether two
  function signatures unify.
- **NO emit decisions.** link.py never chooses direct-call vs
  call_indirect; that decision is in Hβ.lower's emitted WAT.
- **NO handler resolution.** link.py never decides which handler
  arm to invoke at a perform site; that's resolved at compile time
  + present in the emitted WAT as either direct call or call_indirect.

If link.py's logic ever needs to "understand" Ty / EffRow / Handler /
Scheme — STOP. That's substrate drift. The work belongs in Hβ.infer
or Hβ.lower; extend those walkthroughs.

### 5.2 No Python idiomatic drift into compiler concepts

- **NO list-comprehensions over compiler logic.** Acceptable for
  text manipulation: `[parse_module(p) for p in inputs]`. NOT
  acceptable: `[unify_types(t1, t2) for ...]` — that's compiler
  semantics in Python.
- **NO dict-as-symbol-table in compiler sense.** Acceptable:
  `dict[str, int]` for rename collision counting. NOT acceptable:
  `env: dict[str, Scheme]` for environment management — env IS a
  compiler concept; belongs in Hβ.infer's env.wat.
- **NO class-based handlers.** No `class TypeChecker: ...`. link.py
  is functional Python — pure functions over text.

### 5.3 Drift modes from CLAUDE.md applied at the linker

- **Drift 1 (vtable):** link.py is NOT building a dispatch table.
  Per BT §6: each `perform op_name(args)` site is already known-ground
  (direct `call`) or polymorphic (call_indirect through closure
  field) BEFORE linking. link.py resolves NAMES, not DISPATCH.
- **Drift 8 (string-keyed-when-structured):** symbol resolution
  uses a structured `(module_name, symbol)` tuple key, not a flat
  `f"{module}.{symbol}"` string. (The Python tuple is the
  Inka-spec ModuleId equivalent; converted to `<module>__<symbol>`
  string only at output.)
- **Drift 9 (deferred-by-omission):** every input symbol either
  resolves OR link.py errors out with a named diagnostic.

### 5.4 Foreign fluency — linker libraries

| Foreign vocabulary | What link.py actually does |
|--------------------|---------------------------|
| LLVM `lld` link stages | text concat + rename (not section merge) |
| GNU `ld` symbol relocation | `<module>__<symbol>` rename only |
| Webpack module bundling | not bundling — assembling per Hβ §2 modular pivot |
| Go internal/vendor imports | not relevant; Inka modules are flat |
| C preprocessor `#include` | not preprocessing — concatenating already-emitted WAT |

If any of those vocabulary items appears in link.py's comments,
that's drift; restructure.

---

## §6 Composition with Hβ.{lex,parse,infer,lower,emit} + build.sh

### 6.1 Hβ.link × Hβ.{lex,parse,infer,lower,emit}

The seed's compile pipeline:
```
.nx source → Hβ.lex → tokens → Hβ.parse → AST →
  Hβ.infer → typed AST + populated graph →
  Hβ.lower → LowIR →
  Hβ.emit → per-module WAT
```

link.py runs ONCE per build, AFTER all per-module WATs have been
emitted. It composes them into one inka.wat for wat2wasm.

### 6.2 Hβ.link × build.sh

`bootstrap/build.sh` is the orchestrator. Per Wave 2.A factoring +
Hβ-link-protocol.md, the new build.sh flow:

```bash
# Single-source mode (current — assembling the seed itself):
#   bash bootstrap/build.sh
#   → concatenates bootstrap/src/*.wat chunks per CHUNKS[]
#   → wraps in inline Layer 0 shell + Layer 5 entry
#   → wat2wasm bootstrap/inka.wat -o bootstrap/inka.wasm
#
# Multi-module mode (post-Hβ.{infer,lower,emit} substrate landing):
#   bash bootstrap/build.sh --multi-module
#   → for each src/*.nx + lib/**/*.nx:
#       cat $f | wasmtime run bootstrap/inka.wasm > /tmp/$(basename $f .nx).wat
#   → python3 bootstrap/src/link.py /tmp/*.wat -o /tmp/inka2.wat
#   → wat2wasm /tmp/inka2.wat -o /tmp/inka2.wasm
#   → wasm-validate /tmp/inka2.wasm
```

The single-source mode is what currently exists (Wave 2.A factoring).
The multi-module mode is the Hβ.link addition — gated on Hβ.infer +
Hβ.lower + Hβ.emit substrate landing such that the seed produces
non-degenerate per-module WAT.

### 6.3 Hβ.link × first-light-L1

Per Hβ-bootstrap.md §2.4 first-light.sh + §12.1 Leg 1:

The first-light harness invokes link.py twice:
1. Compile src/*.nx via current bootstrap → per-module WAT → link.py → inka2.wat → wat2wasm → inka2.wasm
2. Compile src/*.nx via inka2.wasm → per-module WAT → link.py → inka3.wat → wat2wasm → inka3.wasm
3. `diff <canonicalized inka2.wat> <canonicalized inka3.wat>` empty → first-light-L1 ✓

link.py is the substrate that makes this multi-module assembly
possible; without it, the per-module WATs can't be combined into
one validating module.

---

## §7 Acceptance criteria

### 7.1 Type-level

- [ ] `bootstrap/src/link.py` exists; ~200 lines Python; passes
      `python3 -m py_compile`.
- [ ] Per-edit-site eight interrogations + forbidden patterns audit
      clean.

### 7.2 Functional

- [ ] `python3 bootstrap/src/link.py <foo.wat> <bar.wat> -o /tmp/out.wat`
      runs without error on any pair of standalone WAT files.
- [ ] Symbol collision: two modules each declaring `$main` produces
      `main_a__main` + `main_b__main` in output.
- [ ] WASI import dedup: a module declaring `(import
      "wasi_snapshot_preview1" "fd_write" ...)` already declared
      in the shell is silently dropped (canonical declaration kept).
- [ ] No-collision case: two modules with no overlapping symbols
      produce output where neither symbol gets renamed.

### 7.3 Self-compile (post-Hβ.infer/lower/emit landing)

- [ ] `bash bootstrap/first-light.sh` runs end-to-end; produces empty
      diff between inka2.wat and inka3.wat. → `git tag first-light-L1`.

---

## §8 Open questions + named follow-ups

| Question | Resolution |
|----------|-----------|
| Should link.py validate the assembled WAT before exiting? | Optional: invoke wat2wasm in dry-run mode for a quick sanity check. Reduces debugging cycles. Per §2.6. |
| Should link.py preserve source-module info for debug builds? | Yes — name section comments per `<module>__<symbol>` already preserve provenance. Future: add a `--debug-symbols` flag emitting `(custom "name" ...)` sections per module. |
| What if a per-module WAT has internal symbol collisions (two `$foo` defined within the same module)? | Compile-time error in the seed; link.py never sees this case. If it does, link.py errors out with `E_LinkInternalCollision` named diagnostic. |
| Cross-module type-scheme resolution? | Out of link.py's scope — the seed's emit produces the type info per-module; cross-module type-checking happens at Hβ.infer's env-overlay layer (named follow-up). |

### Named follow-ups (Hβ.link extensions)

- **Hβ.link.debug-symbols** — `--debug-symbols` flag emitting WASM
  custom name sections per module for stack-trace clarity.
- **Hβ.link.incremental** — only re-link modules that changed since
  last build; keep cached per-module compiled WAT in `.inka/cache/`
  per E.4 cache layout.
- **Hβ.link.parallel** — invoke per-module seed compilation in
  parallel; link.py reads each module's WAT as it lands. Speeds
  up first-light-L1 cycle for large `src/*.nx` trees.
- **F-retire link** — post-first-light, `link_handler` is a canonical
  Inka handler implementing the same protocol; link.py dissolves
  per F-retire of `tools/`. Per Hβ §2.3.

---

## §9 Dispatch + landing discipline

### 9.1 Authoring

This walkthrough: Opus inline (this commit).

### 9.2 link.py implementation

Per Hβ §8 dispatch column + the small scope (~200 lines Python):
**Sonnet via inka-implementer is APPROPRIATE for link.py**. The
implementation is mechanical text manipulation per this walkthrough's
§3 skeleton; the design judgment is locked in this walkthrough.

The inka-implementer's brief includes:
- This walkthrough's §1 (inputs), §2 (protocol), §3 (skeleton)
- Forbidden patterns per §5
- Acceptance criteria per §7

### 9.3 Landing discipline

- link.py lands in its own commit per Anchor 7.
- Commit message cites this walkthrough's §s + scope estimate
  + acceptance test outcomes.
- Drift-audit (extended to scan `.py` for foreign-language drift
  signals — named follow-up of `tools/drift-audit.sh`) clean.
- Per §5.4: comment audit for linker-library vocabulary; refuse.

---

## §10 Closing

Hβ.link is the LAST non-Inka substrate in the bootstrap path. Per
Hβ §0 + Hβ §2.3 + Anchor 4 + Anchor 0:

- **Hand-WAT is the reference.** The seed's per-module compiled
  WATs are hand-WAT plus seed-emission. link.py assembles them.
- **No foreign-language semantic substrate.** link.py is text
  manipulation — symbol rename + concat + dedup. No Inka concepts
  (Ty / EffRow / Handler / Scheme) appear in Python code.
- **Disposable as soon as Inka can replace it.** Post-first-light,
  `link_handler` on the graph supersedes per F-retire.

Per the Hβ family of design contracts now landed:
- `Hβ-bootstrap.md` (commit `95fdc3c`) — parent walkthrough
- `Hβ-infer-substrate.md` (commit `729ee59`) — HM inference layer
- `Hβ-lower-substrate.md` (commit `973c123`) — LowIR construction +
  handler elimination layer
- **`Hβ-link-protocol.md` (this commit)** — bootstrap linker

Plus existing extension points (Hβ.lex / Hβ.parse / Hβ.emit
walkthroughs unwritten — see §9 of Hβ-bootstrap.md sub-handle table
for status).

**Combined Wave 2.E + Hβ.link contracted scope:**
- Hβ.infer: ~3380 WAT lines
- Hβ.lower: ~3050 WAT lines
- Hβ.link: ~200 Python lines
- Hβ.lex extension: ~200-300 WAT lines (named follow-up)
- Hβ.parse extension: ~500-1000 WAT lines (named follow-up)
- Hβ.emit extension: ~500-1500 WAT lines (named follow-up)
- **Total: ~7800-9300 WAT lines + ~200 Python lines**
  across ~25-30 chunks + 1 Python script.

Per Hβ §13 estimate (50-150k lines total): the Hβ family of
design-contract walkthroughs has landed. **The cliff is mapped.**
Per insight #12 compound interest: any future-Opus session can
transcribe substrate from these contracts; per insight #14 corpus
discipline: no future-session re-derives the design from spec
04 / spec 05 / src/infer.nx / src/lower.nx — the projection onto
the Wave 2.A–D substrate is locked.

*Per Mentl's anchor: write only the residue. The walkthroughs
already say what the medium IS. This walkthrough is the residue
between Hβ-bootstrap.md's §2.3 link.py named + BT §3's protocol
+ the Wave 2.A–D modular substrate. The next residue is link.py
substrate itself; its implementer cites this walkthrough's §3.*

---

**The Hβ family is complete enough.** First-light-L1 path is
contracted. Per Anchor 0 dream-code + Anchor 4 build-the-wheel +
Anchor 7 cascade discipline + insight #12 compound interest + Hβ §0
Inka-bootstraps-through-Inka — the seed's substrate is ready to
transcribe + the linker's text manipulation is ready to write +
when the cliff is climbed first-light-L1 closes.
