# Hβ-emit-js.md — Browser-runnable JavaScript backend

**Status:** Named cascade. Per PLAN-to-first-light.md §3 post-Tier-3.
Plan-doc.

## Context

Mentl targets WASM today. WASM runs in browsers via the JS WASM API.
This cascade adds a DIRECT JS backend — same kernel, JS source as
the projection. Use cases: zero-bundle web playgrounds; embedding
Mentl in JS-only environments (Cloudflare Workers, Deno, browser
extensions); mentl-edit-in-browser without WASM-startup overhead.

Replacement target: peer to `src/backends/wasm.mn` →
`src/backends/javascript.mn`. LowIR consumed; JS source emitted.

## Handles (positive form)

1. **Hβ.emit-js.value-encoding** — JS values for Mentl primitives:
   integers as JS Number (or BigInt for i64); strings as JS String;
   ADT variants as `{ tag, fields }` objects; closures as JS
   functions with `[[State]]` carried as a closed-over object.
2. **Hβ.emit-js.lowir-to-js** — each LowExpr tag → JS expression /
   statement. LMakeClosure → JS arrow function; LMatch → switch /
   nested ternary; LMakeVariant → object literal.
3. **Hβ.emit-js.runtime-prelude** — JS runtime helpers: `str_concat`,
   `list_alloc_*`, `record_set`, etc. Mirrors `runtime/*.wat` but in
   JS.
4. **Hβ.emit-js.module-system** — emit ES modules with `export`
   per top-level fn; consumer code imports and calls directly.
5. **Hβ.emit-js.handler-effect** — `EmitJs` handler peer to
   `EmitWasm` / `EmitBinary` / `EmitNative`.
6. **Hβ.emit-js.browser-playground** — `mentl edit` browser variant:
   wheel-compiled-to-JS runs in browser; user types `??`; Mentl
   proposes via the same gradient.
7. **Hβ.emit-js.fixpoint-validation** — wheel compiles to JS; the
   JS-compiled compiler compiles the wheel; output matches the
   WASM-path output (same logical program).

## Acceptance

- `mentl --target=js <input.mn>` produces `.js` source.
- Output JS runs in node + modern browsers without polyfills.
- The browser playground (Stage E `mentl edit` variant) ships with
  the JS-compiled wheel.
- Self-compile fixpoint holds.

## Dep ordering

1 (value encoding) → 2 (LowIR translation) and 3 (runtime prelude)
in parallel → 4 (module system) → 5 (handler) → 6 (browser
playground) → 7 (fixpoint validation).

## Cross-cascade dependencies

- **Gates on:** Phase H + Tier 3 + Stage E (`mentl edit`).
- **Composes with:** `Hβ-emit-binary-direct.md`,
  `Hβ-emit-native-target.md` (peer handlers on the Emit
  interface).
- **Unlocks:** browser-runnable Mentl — every developer can try Mentl
  without installing tooling.
