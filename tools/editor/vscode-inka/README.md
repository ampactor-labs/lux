# Inka — Language Support for VS Code

> *The visual identity of the ultimate intent → machine instruction medium.*

Syntax highlighting, color theme, and **Mentl-via-LSP** for the [Inka](https://github.com/ampactor-labs/inka) programming language (`.nx` files).

This package is one peer transport per CLAUDE.md anchor: *every transport is a handler.* `inka edit` (the canonical browser-holographic-live IDE per the IE walkthrough) is the canonical projection. This extension is the LSP-peer-transport bridge for developers who use VS Code or VS Code-derivative editors (Cursor, Windsurf, etc.). Both compose on the same kernel through different handler chains.

## Features

- **Full syntax highlighting** for all 69 token types defined in SYNTAX.md
- **Inka Obsidian** — a dark color theme designed for resonance with Inka's eight-primitive kernel
- **Colorblind-safe** — Wong/Okabe-Ito palette, WCAG AA compliant, with bold/italic secondary cues
- **Ligature-aware** — designed to work beautifully with JetBrains Mono
- **Mentl as LSP** — hovers, completions, diagnostics, and code actions surface Mentl's voice through her installed handler chain (graph + Interact + mentl_voice_filesystem + mentl_voice_default). Requires the `inka` wheel binary on PATH; activates automatically when you open any `.nx` file.

## The Color Language

Every color maps to a kernel primitive. The visual identity IS a handler projection of the architecture:

| Color | Hex | Kernel Primitive | What It Highlights |
|---|---|---|---|
| **Deep Blue** | `#0072B2` | Graph + Env (P1) | Keywords — the sovereign structure |
| **Sky Blue** | `#56B4E9` | Five Verbs (P3) | `\|>` `<\|` `><` `~>` `<~` — the topology |
| **Orange-Gold** | `#E69F00` | HM Inference (P8) | Types, constructors, operators — golden contracts |
| **Bluish Green** | `#009E73` | Handlers (P2) | Function & handler names — living computation |
| **Golden Wheat** | `#F0C674` | Annotation Gradient (P7) | Strings — organic content |
| **Vermillion** | `#D55E00` | Refinement Types (P6) | Numbers, booleans, `!` negation, `self` — assertions |
| **Reddish Purple** | `#CC79A7` | Ownership (P5) + Effects (P4) | `own`, `ref`, `Pure`, `@resume`, effect names — capabilities |
| **Warm White** | `#E8DCC8` | Why Engine (P8) | Variables, parameters — the reasons flow through |

Eight primitives. Eight color roles. Eight tentacles.

## Recommended Font Setup

For the full experience, use [JetBrains Mono](https://www.jetbrains.com/lp/mono/) with ligatures enabled:

```json
{
  "editor.fontFamily": "'JetBrains Mono', 'Fira Code', monospace",
  "editor.fontLigatures": true,
  "editor.fontSize": 14,
  "editor.lineHeight": 1.6
}
```

This gives you beautiful ligatures for Inka's pipe verbs: `|>` → ▷, `->` → →, `=>` → ⇒, `~>` → ⤳

## Installation

### Prerequisites

- **VS Code** ≥ 1.75.0 (or any compatible derivative — Cursor, Windsurf, etc.)
- **Node.js + npm** for building from source
- **Inka wheel binary** on PATH (`inka`) — required for LSP. The wheel ships post-first-light-L1 (see the Inka project's plan tracker). Until then, only syntax highlighting + the color theme activate; the LSP client surfaces a non-fatal error noting the binary isn't yet built.

### Build from source

```bash
cd tools/editor/vscode-inka
npm install
npm run compile
npx vsce package
code --install-extension inka-0.2.0.vsix
```

### Development (Extension Development Host)

1. Open `tools/editor/vscode-inka/` in VS Code
2. Run `npm install` (one-time)
3. Press `F5` — launches the Extension Development Host with the LSP client active
4. Open any `.nx` file — syntax + theme activate immediately; LSP connects to `inka lsp` if the wheel is on PATH

### Configuration

| Setting | Default | Purpose |
|---|---|---|
| `inka.serverPath` | `"inka"` | Path to the Inka wheel binary. Override if `inka` is not on PATH. |
| `inka.serverArgs` | `["lsp"]` | Arguments passed to the wheel to start the LSP transport. |
| `inka.trace.server` | `"off"` | LSP trace verbosity. Set to `"messages"` or `"verbose"` to inspect the JSON-RPC stream in the **Inka Language Server** output channel. |

The LSP wiring composes on the substrate landed in the wheel itself: `lib/runtime/json.nx` (JSON parse + serialize), `lib/runtime/lsp_frame.nx` (Content-Length JSON-RPC framing), `src/mentl_lsp.nx` (LSP transport handler — `inka_lsp_session` + dispatch + 12 method handlers), and the `inka lsp` subcommand at `src/main.nx`. VS Code spawns the wheel; the wheel runs Mentl's full handler chain; every LSP request reaches her, every response is her voice projected through the LSP transport.

## Syntax Coverage

The grammar covers every syntactic construct from SYNTAX.md:

- **Functions**: `fn name<T>(params) -> Ret with Effects = body`
- **Lambdas**: `(x) => x + 1`, `(params) => { stmts; expr }`
- **Five pipe verbs**: `|>`, `<|`, `><`, `~>`, `<~` with distinct scoping
- **Records**: `{name: val}`, field punning, spread `{...r, f: v}`, row polymorphism
- **ADTs**: `type Option<A> = Some(A) | None`
- **Effects**: `effect IO { read() -> String @resume=OneShot }`
- **Handlers**: `handler name(cfg) with state = init { arms }`
- **Patterns**: PVar, PWild, PLit, PCon, PTuple, PList, PRecord, PAlt, PAs
- **Strings**: `"interpolating {expr}"`, `'literal'`, `"""triple"""`, `'''triple'''`
- **Numbers**: `42`, `0xFF_AA`, `0b1010`, `0o77`, `3.14`, `1_000_000`
- **Refinements**: `type Sample = Float where -1.0 <= self <= 1.0`
- **Doc comments**: `///` (brighter, substrate-visible) vs `//` (dim, human-only)

## Accessibility

- Built on the **Wong/Okabe-Ito** palette — proven discriminable across deuteranopia, protanopia, and tritanopia
- **Luminance tiers** ensure categories are distinguishable even in grayscale
- **Font style as secondary cue**: keywords **bold**, comments *italic*, annotations *italic*, effect negation **bold**
- All text colors ≥ **4.5:1 contrast ratio** against `#0D0B0E` background (WCAG AA)

## License

Dual-licensed under MIT or Apache-2.0, matching the Inka project.
