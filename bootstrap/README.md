# Lux Bootstrap

> *"The compiler that fights its own type system cannot compile itself.
> The compiler that trusts its own type system already has."*

This directory holds the recipe that takes Lux from Rust-hosted to
self-hosted. Every file here is either a **source** input (hand-written,
versioned) or a **build** output (generated, gitignored).

## What's in here

```
bootstrap/
├── Makefile              recipe — stage 0 → 1 → 2 → check
├── wasi_shim.c           hand-written WASI bridge for the wasm2c native path
├── legacy-bootstrap.sh   the original shell script (preserved for reference)
├── scripts/              one-off migration scripts (historical)
└── build/                gitignored — all generated artifacts
```

## Philosophy: a handler chain, not a pipeline

From `docs/INSIGHTS.md`: *"The handler IS the backend."* The WASM
emitter is a handler for the Memory effect. `wasm2c` is another handler
(WASM ops → C statements). `gcc` is another (C → x86). When Lux has its
own native emitter (Phase 7+), this entire chain becomes redundant —
replaced by `x86_emit.lux`. Until then, the chain composes through
effect-compatible interfaces and is a legitimate stepping stone.

## Stages

### Stage 0 — Rust VM → WAT *(~9 min)*

The Rust VM (`src/vm/`) runs the self-hosted Lux compiler
(`std/compiler/*.lux`) against the bootstrap entry point
(`examples/wasm_bootstrap.lux`) and emits WAT. The Rust VM is the
"patient parent" — lenient runtime dispatch covers over cheap-flat
questions that the WASM runtime will later expose (see INSIGHTS.md /
*The Structural Question*).

```bash
make stage0
# → build/lux3.wat   ≈ 2.5 MB of WAT
```

### Stage 1 — WAT → binary WASM *(seconds)*

`wat2wasm --debug-names` preserves the `$name` symbolic identifiers the
Lux emitter already produces. The resulting binary is ~415 KB with
names, ~246 KB without. **We want names.** They flow through to:

- `wasmtime` stack traces (readable crash reports)
- `wasm-decompile` output (scannable pseudocode for debugging)
- `wasm2c` output (human-named C functions instead of `f4, f5, f1013`)

The info already exists — this just lets it flow.

```bash
make stage1
# → build/lux3.wasm   binary, validated, with name section
```

### Stage 1-native — binary → C → native ELF *(~30 sec)*

`wasm2c` compiles the WASM module to portable C. `gcc -O2` compiles the
C (plus `wasi_shim.c`) to a native ELF. Output is a standalone
executable — no wasmtime, no JIT, no runtime interpreter.

```bash
make stage1-native
# → build/lux3_native.c  ≈ 4.6 MB of C
# → build/lux3-native    ≈ 780 KB ELF
```

### Stage 2 — Ouroboros *(time TBD after O(N²) fix)*

`lux3` compiles itself. If the output `lux4` is bit-for-bit identical
to `lux3`, the compiler has reached a fixed point — the self-hosted
pipeline produces itself without the Rust VM.

```bash
make stage2            # via wasmtime
make stage2-native     # via native ELF
```

> **Current status:** stage 2 is CPU-bound on O(N²) `list[i]` traversals
> in the compiler source. See `AGENTS.md` → *Known Remaining Issue* for
> the hot-path file list. Fixes are algorithmic (convert `list[i]` loops
> to `list_pop` tail recursion), not mechanical.

### Check — fixed-point verdict

```bash
make check
# → "FIXED POINT REACHED — Arc 2 complete" or a diff
```

## The handler chain, illustrated

```
examples/wasm_bootstrap.lux
  │
  ├── std/compiler/*.lux      ← handlers that transform the AST
  │   ~> lexer
  │   ~> parser
  │   ~> checker
  │   ~> lower (AST → LowIR)
  │
  └── std/backend/wasm_emit.lux  ← Memory effect handler #1 (LowIR → WAT)
       │
       ▼                           [ Stage 0 ends ]
    lux3.wat
       │
       ├── wat2wasm --debug-names ← format handler
       │     ▼
       ▼   lux3.wasm               [ Stage 1 ends ]
       │
       ├── wasm2c                  ← Memory effect handler #2 (WASM → C)
       │     ▼
       ▼   lux3_native.c
       │
       ├── gcc -O2 + wasi_shim.c   ← Memory effect handler #3 (C → x86)
       │     ▼
       ▼   lux3-native             [ Stage 1-native ends ]
       │
       └── < wasm_bootstrap.lux    ← Stage 2: the Ouroboros
             ▼
          lux4.wat
             │
             └── diff lux3.wat lux4.wat → fixed-point verdict
```

Every `~>` is an effect handler — no pipeline, no passes, just
observers on the same computation.

## See also

- `docs/INSIGHTS.md` / *The Handler IS the Backend*
- `docs/INSIGHTS.md` / *The Structural Question*
- `docs/ARC3_ROADMAP.md` — what comes after fixed-point
- `AGENTS.md` → *Known Remaining Issue* — O(N²) fix targets
