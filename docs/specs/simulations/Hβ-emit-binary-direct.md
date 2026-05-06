# Hβ-emit-binary-direct.md — Skip WAT-text; emit WASM binary directly

**Status:** Named cascade. Per PLAN-to-first-light.md §3 post-Tier-3.
Plan-doc.

## Context

Today's emit produces `.wat` text → `wat2wasm` (external tool) →
`.wasm` binary. The WAT-text intermediate is convenient for
inspection but adds a tooling dependency and parsing roundtrip.
This cascade replaces emit's text output with direct binary
encoding per the WASM spec (LEB128, section headers, type indexes,
function bodies).

Replacement target: `bootstrap/src/emit/*.wat` (text emit) →
`src/backends/wasm_binary.mn` (direct binary emit).

## Handles (positive form)

1. **Hβ.emit-binary.leb128-encoder** — runtime/binary.mn already
   has LEB128 helpers; extend for WASM-spec varuint + varint.
2. **Hβ.emit-binary.section-headers** — type, import, function,
   table, memory, global, export, start, element, code, data
   sections. Each emits a length-prefixed payload.
3. **Hβ.emit-binary.type-section** — function type signatures with
   param + result vector encoding.
4. **Hβ.emit-binary.function-bodies** — local declarations + opcode
   stream; instruction encoding per spec (i32.const → 0x41 + LEB128;
   call → 0x10 + funcidx; etc.).
5. **Hβ.emit-binary.relocation-resolution** — fn-idx and global-idx
   forward references resolved during emit (currently text-emit
   sidesteps via name-based deferred resolution).
6. **Hβ.emit-binary.handler-projection** — `EmitBinary` effect peer
   to existing `EmitText` (or `Emit` swap). Each backend is a
   handler on the same Emit interface.
7. **Hβ.emit-binary.fixpoint-validation** — wheel compiles itself
   via binary emit; `wasm-validate` accepts the output; running it
   produces byte-identical output again.

## Acceptance

- `mentl <input.mn>` produces `.wasm` directly without `wat2wasm` in
  the pipeline.
- All trace harnesses still pass via binary path.
- Compile time drops (no text serialize / re-parse roundtrip).
- `Hβ-tooling-assemble-in-mentl.md` becomes obsolete (no separate
  wat2wasm needed).

## Dep ordering

1 (LEB128) → 2 (sections) → 3 (types) → 4 (bodies) → 5 (relocs) →
6 (handler projection) → 7 (fixpoint). Sections + bodies are the
load-bearing center.

## Cross-cascade dependencies

- **Gates on:** Phase H + Tier 3 + L1 stable.
- **Composes with:** `Hβ-emit-native-target.md` (Cranelift/LLVM as
  alternative backend); both register as `Emit` handlers.
- **Closes:** `Hβ-tooling-assemble-in-mentl.md` (wat2wasm in Mentl)
  becomes optional / obsolete.
