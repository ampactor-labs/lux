# Handle MV-LSP — `lsp_adapter` Handler: LSP JSON-RPC ↔ Interact Transport

> **Status:** `[DRAFT]` 2026-04-25. Closes the substrate gap between
> the MV.2.e Interact handler arms (17 of 22 substrate-live as of
> commit `afc4b0c`) and developer-facing surfaces. The `lsp_adapter`
> handler is the FIRST transport that surfaces Mentl's voice to a
> real editor (VS Code via the LSP plugin path).
>
> Per MV walkthrough §1.5: `Interact` is the stable API boundary;
> LSP is one transport over it. Per Insight #11 (Continuous Oracle IS
> IC + cached value): lsp_adapter is the first real subscriber that
> closes the realization loop in editor-time. Per Insight #1 (handler
> chain IS capability stack): lsp_adapter sits OUTERMOST in the
> chain — least trusted, sandbox boundary.

*Role-play as Mentl. The user has just opened VS Code, the Inka
extension activated, and the LSP server (this handler chain) is
spinning up. The first stdin bytes arrive: an `initialize` JSON-RPC
request. Mentl needs to: (a) negotiate capabilities, (b) record the
project root, (c) reply with her own capability declaration, (d)
hand control to the per-method dispatch loop. From this moment on,
every keystroke fires LSP requests; every response is one or more
Interact ops composed through the existing handler chain.*

---

## 0. Framing — what lsp_adapter IS and ISN'T

### 0.1 What it IS

A single handler that:

1. **Reads stdin** as a stream of JSON-RPC messages framed by
   `Content-Length: N\r\n\r\n<N bytes>` headers.
2. **Parses** each message into an `LspMessage` ADT (Request /
   Notification / Response).
3. **Dispatches** by method string to one or more `Interact` ops.
4. **Composes the result** (Interact return value or VoiceLine) into
   an LSP response shape.
5. **Writes stdout** the JSON-RPC framed response.

The handler IS one entry point: `inka_lsp_session(stdin, stdout)`.
The CLI wrapper invokes it: `inka --with lsp_run` (entry-handler per
EH walkthrough convention).

### 0.2 What it ISN'T

- **Not a JSON parser/serializer per se.** Pack/Unpack effects already
  exist (`lib/runtime/binary.nx`); JSON is structured byte layer
  composed on those. JSON encode/decode lands as a separate substrate
  (MV-LSP.json sub-handle) — small, focused, reusable for any JSON
  surface (web playground, etc.).
- **Not the VS Code extension.** That's TypeScript glue (~300 lines)
  that spawns the Inka LSP server binary and registers Inka language
  features with VS Code. Lands in a separate `extensions/vscode/`
  directory, not in `src/` or `lib/`.
- **Not a capability negotiator beyond the bare minimum.** v1
  declares fixed capabilities (text-sync = full; hover; completion;
  codeAction; diagnostic; definition; references). Refined
  capability advertisement (per-language, per-feature flags) lands as
  MV-LSP.caps peer sub-handle.
- **Not a full LSP method coverage.** v1 ships 12 methods covering the
  10 acceptance tests AT1-AT10 from MV §2.8. The remaining ~30 LSP
  methods land per-method as their tentacles need them.

### 0.3 Why this is load-bearing

Per CLAUDE.md anchor + DESIGN.md: Mentl is the voice that reads the
graph. 17 Interact arms exist but no transport surfaces them. The
realization loop (insight #12) closes when the gradient becomes
visible to the developer-in-the-editor — and that requires a transport.

VS Code is where developers live. Per MV walkthrough §1.5: "LSP is how
developers' editors already speak." Not abandoning the editor IS the
adoption strategy. The lsp_adapter is the bridge.

**Compounds with insight #11:** the oracle IS IC + cached value;
graph_mutated fires on commit; Mentl re-explores. lsp_adapter is the
first SUBSCRIBER that matters — every textDocument/didChange triggers
re-inference → oracle re-exploration → next-turn Mentl voice. Without
lsp_adapter the oracle is contract-only; WITH it, the loop closes.

---

## 1. JSON-RPC transport substrate

### 1.1 The wire format

LSP uses JSON-RPC 2.0 with `Content-Length: N\r\n\r\n` framing.
Substrate split into two layers:

**Layer A — framing (byte → frame):**
```
LspFrame = LspFrame(String)              // raw JSON body, length-prefix already stripped
```

`fn read_lsp_frame() -> LspFrame with Memory + WASI` — read
"Content-Length:" header line, parse N, read N bytes of body, return
LspFrame(body). EOF → returns empty Frame; caller terminates loop.

`fn write_lsp_frame(body: String) with Memory + WASI` — write
"Content-Length: <len>\r\n\r\n<body>" to fd_write(1).

**Layer B — JSON parse/serialize (frame → message):**
```
type JsonValue
  = JNull
  | JBool(Bool)
  | JNum(Float)
  | JStr(String)
  | JArr(List)        // List<JsonValue>
  | JObj(List)        // List<(String, JsonValue)>
```

`fn json_parse(s: String) -> JsonValue with Pure` — recursive descent
parser. ~150 lines. Honest scope (no streaming; LSP messages are
small).

`fn json_serialize(v: JsonValue) -> String with Memory` — value →
canonical JSON text. ~80 lines.

**This JSON substrate lands as MV-LSP.json peer sub-handle, NOT in
lsp_adapter itself.** Reusable for any future JSON surface (web
playground, debug adapter protocol, MCP, etc.).

### 1.2 LSP message ADT

```
type LspMessage
  = LspRequest(Int, String, JsonValue)        // id, method, params
  | LspNotification(String, JsonValue)        // method, params (no id)
  | LspResponse(Int, JsonValue, Option)       // id, result, Option<LspError>

type LspError
  = LspError(Int, String)                     // code, message
```

`fn parse_lsp_message(frame: LspFrame) -> LspMessage with Pure` —
extract id / method / params from JsonValue. H6 exhaustive over the
3-shape distinction (request has id+method+params; notification has
method+params no id; response has id+result+optional error).

### 1.3 LSP response shapes

Per LSP spec, each method has a typed response. Substrate encodes
the common ones as ADTs:

```
type LspResponseBody
  = LspHoverResp(Option)                      // Option<HoverContent>
  | LspCompletionResp(List)                   // List<CompletionItem>
  | LspCodeActionResp(List)                   // List<CodeAction>
  | LspDiagnosticResp(List)                   // List<Diagnostic>
  | LspDefinitionResp(Option)                 // Option<Location>
  | LspReferencesResp(List)                   // List<Location>
  | LspInitializeResp(InitializeResult)
  | LspNullResp                               // for notifications + nullable hover

type HoverContent = HoverContent(String)      // markdown
type CompletionItem = CompletionItem({...})
type CodeAction = CodeAction({...})
type Diagnostic = Diagnostic({...})
type Location = Location({...})               // uri, range
type Range = Range(Position, Position)
type Position = Position(Int, Int)            // line, character
type InitializeResult = InitializeResult({...})
```

Each LSP response wraps its body in JSON for transport. The wrap is
mechanical (per-shape `to_json` fns).

---

## 2. Method dispatch — the routing table

### 2.1 The 12 v1 methods

Each LSP method maps to one or more Interact ops. The routing IS
the substrate decision; per drift mode 8 prevention, it's an explicit
ADT match, NOT a string-keyed dispatch table.

```
type LspMethodKind
  = LspInitialize                             // server lifecycle
  | LspInitialized
  | LspShutdown
  | LspExit
  | LspTextDocDidOpen                         // text sync
  | LspTextDocDidChange
  | LspTextDocDidSave
  | LspTextDocDidClose
  | LspTextDocHover                           // queries
  | LspTextDocCompletion
  | LspTextDocCodeAction
  | LspTextDocDiagnostic
  | LspTextDocDefinition
  | LspTextDocReferences
  | LspUnknown(String)                        // graceful unknown-method

fn classify_method(method: String) -> LspMethodKind with Pure =
  if str_eq(method, "initialize")               { LspInitialize }
  else if str_eq(method, "initialized")         { LspInitialized }
  else if str_eq(method, "shutdown")            { LspShutdown }
  else if str_eq(method, "exit")                { LspExit }
  else if str_eq(method, "textDocument/didOpen") { LspTextDocDidOpen }
  else if str_eq(method, "textDocument/didChange") { LspTextDocDidChange }
  ...
  else { LspUnknown(method) }
```

This is the ONE place where a string IS the input shape (LSP method
strings come from the protocol). Per drift mode 8: the string is
IMMEDIATELY projected to the ADT; downstream dispatch matches on
LspMethodKind, never on the raw string.

### 2.2 Dispatch arms (LSP method → Interact ops)

Per kernel-closure (insight #13): the dispatch is COMPOSITION on the
landed Interact arms. No new substrate per dispatch — just the
mapping.

| LSP Method | Interact Op(s) | Response shape |
|---|---|---|
| `initialize` | `project_root()` | `LspInitializeResp` (caps + project_root) |
| `initialized` | (no-op) | `LspNullResp` |
| `shutdown` | (state cleanup) | `LspNullResp` |
| `exit` | (terminate session loop) | (no response) |
| `textDocument/didOpen` | `open_file(Path)` | `LspNullResp` (notification) |
| `textDocument/didChange` | `edit(FileHandle, Patch)` | `LspNullResp` (notification) |
| `textDocument/didSave` | `save_file(FileHandle)` | `LspNullResp` (notification) |
| `textDocument/didClose` | `close_file(FileHandle)` (FX.5) | `LspNullResp` (notification) |
| `textDocument/hover` | `focus(TargetSpan(s))` + `ask(QTypeAt(s))` | `LspHoverResp(Some(...))` from Answer |
| `textDocument/completion` | `propose(TargetSpan(s))` | `LspCompletionResp` from VoiceLine |
| `textDocument/codeAction` | `propose(TargetSpan(s))` | `LspCodeActionResp` from VoiceLine |
| `textDocument/diagnostic` | `run_check(fh)` | `LspDiagnosticResp` from CheckOutcome |
| `textDocument/definition` | `focus + ask(QWhy(name))` | `LspDefinitionResp` from Answer |
| `textDocument/references` | `focus + ask(QRefsOf(name))` | `LspReferencesResp` from Answer |

12 method classifications, 14 LSP method strings (some classifications
fire multiple Interact ops; some Interact ops handle multiple LSP
methods). Per drift mode 9: each named explicitly; no silent absorb.

### 2.3 What's NOT in v1 (named peer sub-handles)

- **`textDocument/formatting`** — gates on `format_handler` substrate
  (post-first-light per Arc J). MV-LSP.format peer.
- **`textDocument/rename`** — gates on `inka rename` CLI handler
  (PLAN item 44). MV-LSP.rename peer.
- **`workspace/symbol`** — gates on cross-module symbol index. MV-LSP.symbol peer.
- **`workspace/executeCommand`** — gates on entry-handler reflection
  (per EH walkthrough). MV-LSP.cmd peer.
- **`textDocument/inlayHint`** — gates on Teach tentacle's gradient
  surfacing per AT1/AT5. **Recommend including in v1** (small;
  Mentl's Teach tentacle already renders via render_teach_arm).
  MV-LSP.inlayhint peer; flag for inclusion in v1 if scope permits.

The named-peer discipline keeps v1 honest about scope without
silently absorbing the gaps.

---

## 3. The lsp_adapter handler shape

```
handler lsp_adapter
  with msg_id_counter   = 0,                  // for outgoing requests/notifications
       doc_table        = [],                 // List<(String, FileHandle)>  uri ↔ handle
       initialized      = false,              // capability negotiation gate
       shutdown_received = false {             // shutdown-then-exit lifecycle

  // The handler doesn't intercept Interact ops directly — it composes
  // OUTSIDE them. The session loop is its own driver fn that performs
  // Interact ops and writes responses.

  // Handler arms here are for the rare ops lsp_adapter actually
  // intercepts: graph_mutated (subscribes to oracle re-exploration
  // for push-diagnostic surfacing) and outgoing notifications
  // (for window/showMessage etc.).

  graph_mutated(epoch, mutation) => {
    // Push refreshed diagnostics for affected modules per insight #11.
    // For v1, just resume; refined push lands as MV-LSP.push peer.
    resume()
  }
}

/// inka_lsp_session — the entry fn. Reads stdin loop until shutdown
/// + exit; dispatches each message; writes responses. Composes
/// through the full Mentl handler chain at install. Per Insight #1
/// (capability stack): the chain reads outer→inner as least-trusted
/// → most-trusted.

fn inka_lsp_session() with Memory + WASI + Filesystem + OracleQuery + ... =
  loop_lsp_messages()    // tail-recursive

fn loop_lsp_messages() with ... =
  let frame = read_lsp_frame()
  let LspFrame(body) = frame
  if len_str(body) == 0 { () }                // EOF; clean exit
  else {
    let msg = parse_lsp_message(frame)
    let resp = dispatch_lsp_message(msg)
    write_lsp_response(msg, resp)
    if shutdown_seen_and_exit_received() { () }
    else { loop_lsp_messages() }
  }

fn dispatch_lsp_message(msg) with ... =
  match msg {
    LspRequest(id, method, params)        => dispatch_request(id, classify_method(method), params),
    LspNotification(method, params)       => dispatch_notification(classify_method(method), params),
    LspResponse(_, _, _)                  => LspNullResp                   // we don't initiate requests in v1
  }

fn dispatch_request(id, kind, params) with ... =
  match kind {
    LspInitialize           => handle_initialize(params),
    LspShutdown             => handle_shutdown(),
    LspTextDocHover         => handle_hover(params),
    LspTextDocCompletion    => handle_completion(params),
    LspTextDocCodeAction    => handle_code_action(params),
    LspTextDocDiagnostic    => handle_diagnostic(params),
    LspTextDocDefinition    => handle_definition(params),
    LspTextDocReferences    => handle_references(params),
    LspUnknown(m)           => LspNullResp,                                // graceful no-op for unknown methods
    LspInitialized          => LspNullResp,                                // notification path; should not arrive as request
    LspExit                 => LspNullResp,
    LspTextDocDidOpen       => LspNullResp,                                // notification path
    LspTextDocDidChange     => LspNullResp,
    LspTextDocDidSave       => LspNullResp,
    LspTextDocDidClose      => LspNullResp
  }

fn dispatch_notification(kind, params) with ... =
  match kind {
    LspInitialized          => (),                                         // capability negotiation done
    LspExit                 => terminate_session(),
    LspTextDocDidOpen       => handle_did_open(params),
    LspTextDocDidChange     => handle_did_change(params),
    LspTextDocDidSave       => handle_did_save(params),
    LspTextDocDidClose      => handle_did_close(params),
    LspInitialize           => (),                                         // request path; should not arrive as notification
    LspShutdown             => (),
    LspTextDocHover         => (),
    LspTextDocCompletion    => (),
    LspTextDocCodeAction    => (),
    LspTextDocDiagnostic    => (),
    LspTextDocDefinition    => (),
    LspTextDocReferences    => (),
    LspUnknown(_)           => ()
  }
```

Each `handle_*` fn performs the Interact ops + projects to LspResponseBody.

### 3.1 Example: handle_hover

```
/// handle_hover — LSP textDocument/hover → focus + ask(QTypeAt) →
/// project Answer to HoverContent. Per AT1: returns ``process` runs
/// `List<A> -> Int`. Pure.``
///
/// Composes 4 Interact ops:
///   open_file (if not yet open) — uri ↔ FileHandle plumbing
///   focus(TargetSpan(span))
///   ask(QTypeAt(span))
///   (post-MVP: also fire ask(QWhy) for the deep-hover RExplain shape)

fn handle_hover(params) with ... =
  let uri        = lsp_extract_uri(params)
  let position   = lsp_extract_position(params)
  let span       = position_to_span(position)
  let fh         = ensure_doc_open(uri)           // lookup or open_file
  perform focus(TargetSpan(span))
  let answer     = perform ask(QTypeAt(span))
  match answer {
    AnsSilence              => LspHoverResp(None),
    AnsType(ty, reason)     => LspHoverResp(Some(hover_from_type(ty, reason))),
    AnsRow(row, reason)     => LspHoverResp(Some(hover_from_row(row, reason))),
    AnsReason(reason)       => LspHoverResp(Some(hover_from_reason(reason))),
    AnsRefs(_, _)           => LspHoverResp(None)                          // refs not a hover-shape
  }
```

`hover_from_*` fns project an Answer slot to markdown:

```
fn hover_from_type(ty, reason) with Pure =
  let type_text = show_type(ty)
  HoverContent(
    "`"
      |> str_concat(type_text)
      |> str_concat("`\n\n*"
      |> str_concat(show_reason_compressed(reason))
      |> str_concat("*"))
  )
```

### 3.2 Example: handle_completion

```
fn handle_completion(params) with ... =
  let uri      = lsp_extract_uri(params)
  let position = lsp_extract_position(params)
  let span     = position_to_span(position)
  let _fh      = ensure_doc_open(uri)
  perform focus(TargetSpan(span))
  let voiceline = perform propose(TargetSpan(span))
  match voiceline {
    Silence                       => LspCompletionResp([]),
    VoiceLine(_tent, _form, slots, _mod) =>
      LspCompletionResp(completion_items_from_slots(slots))
  }
```

---

## 4. Eight interrogations

| # | Interrogation | Answer |
|---|---|---|
| 1 | Graph? | doc_table maps URIs ↔ FileHandles; FileHandles index the mentl_voice_filesystem table; FileHandles trace back to graph nodes via the IC cache. The graph already encodes the URI↔graph relationship transitively. lsp_adapter just maintains the URI plumbing. |
| 2 | Handler? | NEW handler `lsp_adapter` + entry fn `inka_lsp_session`. Composes OUTERMOST in chain. The handler's only intercepted op is `graph_mutated` (oracle subscriber). The session loop performs Interact ops; the lower handlers project them to substrate. |
| 3 | Verb? | Composition via `~>` chain at install: `inka_lsp_session() ~> lsp_adapter ~> mentl_voice_filesystem ~> mentl_voice_default ~> wasi_filesystem ~> graph_handler ~> oracle handlers`. Per Insight #1: outermost = least trusted = sandbox boundary. |
| 4 | Row? | `with Memory + WASI + Filesystem + OracleQuery + Mutate + ...` — full surface row. The LSP server is the user-facing surface; it reaches every capability. Per Anchor 5 (capability stack): this is the SANDBOX BOUNDARY — VS Code never sees raw effects, only LSP shapes. |
| 5 | Ownership? | doc_table entries `own`-to-handler-state. URIs as String borrowed (immutable). FileHandles as opaque Int values. JSON parse trees are own-to-arm-body (constructed and consumed within one method dispatch). |
| 6 | Refinement? | Position fields could be `Line = Int where 0 <= self`, `Col = Int where 0 <= self`. URI could be `Uri = String where starts_with(self, "file://")`. Defer to MV-LSP.refine peer sub-handle (small; aligned with FX.4 Path refinement). |
| 7 | Gradient? | Each handler arm + dispatch case = one gradient step. lsp_adapter unblocks 14 LSP methods → 17 Interact arms become USER-VISIBLE. Massive compound unlock per Insight #12. |
| 8 | Reason? | Every LSP-driven Interact op leaves a Reason chain that traces back to the LSP gesture (e.g., `Inferred("via textDocument/hover at line 42")`). The Why tentacle, when later asked, walks back through the Reason to the LSP request. |

---

## 5. Drift modes audited

- **Mode 1 (Rust vtable):** ✗ — handler is a typed effect handler; dispatch is ADT match, not vtable lookup.
- **Mode 4 (handler-chain-as-monad-transformer):** ✗ — `~>` chain is composition; each handler's row independent.
- **Mode 6 (primitive-special-case):** ✗ — LspMethodKind is structural; no Bool-cased / int-cased dispatch.
- **Mode 7 (parallel-arrays-instead-of-record):** ✗ — handler state is named record per Insight #9; doc_table is List<(String, FileHandle)> tuples.
- **Mode 8 (string-keyed-when-structured):** ✓ ATTENTION — LSP method strings come from the protocol (unavoidable). Mitigation: classify_method projects to LspMethodKind ADT IMMEDIATELY at the dispatch boundary; downstream code never matches on the raw string. The string is INPUT, not internal dispatch shape.
- **Mode 9 (deferred-by-omission):** ✓ — peer sub-handles named explicitly (MV-LSP.json / .caps / .format / .rename / .symbol / .cmd / .inlayhint / .push / .refine).

---

## 6. Sub-handle decomposition

| Handle | Scope | Gate |
|---|---|---|
| **MV-LSP.0** | This walkthrough drafted | (this commit) |
| **MV-LSP.json** | JSON parse + serialize substrate (Pack/Unpack composition) | walkthrough |
| **MV-LSP.frame** | Content-Length framing on Memory + WASI | MV-LSP.json |
| **MV-LSP.scaffold** | lsp_adapter handler decl + session loop entry fn | MV-LSP.frame |
| **MV-LSP.dispatch** | classify_method + dispatch_request + dispatch_notification | MV-LSP.scaffold |
| **MV-LSP.handlers** | 14 handle_* fns (one per LSP method) | MV-LSP.dispatch |
| **MV-LSP.responses** | LspResponseBody projection from VoiceLine / Answer / Outcomes | MV-LSP.handlers |
| **MV-LSP.cli** | `inka --with lsp_run` entry-handler integration | MV-LSP.handlers |
| **MV-LSP.inlayhint** | textDocument/inlayHint support (Teach tentacle surface) | MV-LSP.handlers |
| **MV-LSP.push** | window/showMessage + diagnostic push from graph_mutated | MV-LSP.handlers |
| **MV-LSP.caps** | refined capability negotiation | post-v1 |
| **MV-LSP.refine** | Uri / Line / Col refinement types | post-v1 (cosmetic) |
| **MV-LSP.format** / .rename / .symbol / .cmd | LSP methods deferred to v2 | post-v1 |

After MV-LSP.json + .frame + .scaffold + .dispatch + .handlers +
.responses + .cli land: **12 LSP methods route through to 14
Interact ops; AT1, AT2, AT3, AT4, AT5, AT6, AT9, AT10 from MV §2.8
become user-visible in VS Code.**

AT7 (silence on empty graph) and AT8 (hole completion) require
additional work — AT7 needs the silence_predicate to return correct
nullable hover (already substrate-live); AT8 needs hole syntax in
parser (per "The Hole IS the Gradient's Absence Marker" insight).

---

## 7. Sequencing

Recommended landing order (each commit per Anchor 7):

1. **MV-LSP.0** — this walkthrough (this commit).
2. **MV-LSP.json** — JsonValue ADT + json_parse + json_serialize.
   ~250 lines `.nx`. Pure substrate; reusable beyond LSP.
3. **MV-LSP.frame** — read_lsp_frame + write_lsp_frame on Memory + WASI.
   ~50 lines.
4. **MV-LSP.scaffold** — lsp_adapter handler decl (state + graph_mutated arm) + inka_lsp_session loop fn. ~80 lines.
5. **MV-LSP.dispatch** — LspMethodKind ADT + classify_method + dispatch_request + dispatch_notification. ~80 lines.
6. **MV-LSP.responses** — LspResponseBody ADT + response projection helpers (HoverContent / CompletionItem / etc.) + their JSON serialization. ~100 lines.
7. **MV-LSP.handlers** — 12-14 handle_* fns + ensure_doc_open + URI plumbing. ~250 lines.
8. **MV-LSP.cli** — `lsp_run` entry-handler in src/main.nx. ~20 lines.
9. **MV-LSP.inlayhint** — added to handle_completion's tentacle path. ~30 lines.

**Total scope:** ~860 lines `.nx`. Multi-commit arc; each piece is
honest. After this arc closes, Mentl SPEAKS — first developer-facing
deployment of the kernel.

VS Code TypeScript extension is separate work in `extensions/vscode/`
— ~300 lines TS that spawns the Inka LSP binary and registers
language features. Lands when the .nx side is stable.

---

## 8. What this walkthrough does NOT cover

- **The VS Code TypeScript extension** itself — separate concern;
  the extension is a thin spawner + protocol registrant, not Inka
  substrate.
- **Multi-root workspace handling** — v1 assumes single project root.
- **Workspace edit transactions** (multi-file edits) — ties to MV.2.e.P.edit substrate.
- **textDocument/semanticTokens** — syntax highlighting via LSP. Per
  PLAN.md "Do NOT touch": defer until SYNTAX.md is fully stable.
- **Cancellation** — LSP $/cancelRequest support. Defer to MV-LSP.cancel peer when long-running ops surface.

---

## 9. What closes when this lands

After the full MV-LSP arc ships:

1. **Mentl speaks in VS Code.** Developers hover types, see
   diagnostics, accept code actions — every interaction is
   graph-derived, proof-backed, deterministic.
2. **The realization loop closes for editor-time.** Insight #11's
   continuous oracle is realized in the daily-development experience:
   keystroke → didChange → re-infer → oracle re-explores → next-turn
   Mentl voice surfaces.
3. **The AI obsolescence thesis becomes demonstrable.** Per PLAN.md
   "AI obsolescence argument" + DESIGN.md Ch 8: Mentl's voice
   replaces what Cursor/Copilot/Claude-Code-as-helper are subscribed
   for. Not in marketing rhetoric — in the user's actual editor,
   answering hover/completion/codeAction with proven suggestions.
4. **The kernel-closure milestone (insight #13) reaches its first
   user surface.** The medium reads itself through itself, in
   VS Code, in real time.

This walkthrough designs the bridge from kernel to keyboard.
Per CLAUDE.md anchor: Mentl is octopus because the kernel has
eight primitives; lsp_adapter is the surface where she first
extends a tentacle into the developer's editor.

---

## 10. Authority

This walkthrough supersedes the `Interact` walkthrough's brief
mention of LSP at MV §1.5; this is the focused design for that
transport. Composes on FX walkthrough (FX.A + FX.B for file ops)
and on the closed kernel (insight #13). Does not extend the kernel.
