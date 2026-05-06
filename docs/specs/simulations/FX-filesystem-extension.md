# Handle FX — Filesystem Extension for Mentl-Voice File Surface

> **Status:** `[DRAFT]` 2026-04-25. Closes the substrate gap surfaced
> during MV.2.e composition arc: the existing `Filesystem` effect
> (`src/types.mn:743`) declares 4 ops (`fs_exists` / `fs_read_file` /
> `fs_write_file` / `fs_mkdir`) — sufficient for IC's per-module
> `.kai` cache reads (per FS walkthrough), but insufficient for
> Mentl-voice's `Interact` file surface which declares 8 ops
> (`project_root` / `tree_list` / `open_file` / `save_file` /
> `create_file` / `rename_path` / `delete_path` / `file_text`).
>
> This walkthrough designs the substrate-extension that makes
> Mentl's `Interact` file ops composable on a richer Filesystem
> effect. Gates `MV.2.e.Filesystem` (8 arms) + `MV.2.e.P.edit`
> (needs FileHandle) + `MV.2.e.Run` (run_compile / run_check /
> run_audit all need file_text). **12 of 22 Interact arms unblock
> on FX closure.**

*Role-play as Mentl, the LSP adapter has just received
`textDocument/didOpen`. Mentl needs to open the file, read its
text, hold an opaque handle the editor can later save through,
and project the file's path tree to the editor's tree pane. The
existing `wasi_filesystem` handler reads-on-demand-and-closes;
no concept of an "open" file persists. The substrate doesn't
hold the editor's mental model.*

---

## 0. The substrate gap

### 0.1 Existing FS effect (FS walkthrough; commit `1debfdc`)

```
effect Filesystem {
  fs_exists(String) -> Bool                          @resume=OneShot
  fs_read_file(String) -> String                     @resume=OneShot
  fs_write_file(String, String) -> ()                @resume=OneShot
  fs_mkdir(String) -> ()                             @resume=OneShot
}
```

Each op opens, performs, closes. No persistent FileHandle abstraction.
Sufficient for IC.1's batch reads of `.kai` cache files (open → read →
close in one atomic op). Insufficient for editor surfaces which need:
- A handle that survives between read (didOpen) and write (didSave).
- Directory listing (tree_list).
- Path manipulation (rename, delete).
- Project root resolution.

### 0.2 Interact's file surface (MV-mentl-voice; voice.mn:340-396)

```
effect Interact {
  // ─── Project / file ops (8) ─────────────────────────────────────
  project_root()                 -> Path                @resume=OneShot
  tree_list(Path)                -> List                @resume=OneShot   // List<TreeEntry>
  open_file(Path)                -> FileHandle          @resume=OneShot
  save_file(FileHandle)          -> ()                  @resume=OneShot
  create_file(Path, String)      -> FileHandle          @resume=OneShot
  rename_path(Path, Path)        -> ()                  @resume=OneShot
  delete_path(Path)              -> ()                  @resume=OneShot
  file_text(FileHandle)          -> String              @resume=OneShot
  ...
}
```

ADTs (already declared at `voice.mn:225-243`):
- `Path = Path(String)` — path wrapper (refinement-ready)
- `FileHandle = FileHandle(Int)` — opaque table index
- `TreeEntry = TreeFile(Path) | TreeDir(Path)` — listing entry

### 0.3 What needs to land

Three substrate moves:
1. **Extend `Filesystem` effect** with 4 new ops to cover the WASI primitives the Interact surface needs (path_open with explicit fd return; path_unlink; path_rename; opendir/readdir).
2. **Extend `wasi_filesystem` handler** with arms for the 4 new ops, delegating to runtime/io.mn primitives that pack args into the iov scratch space (same pattern as fs_read_file_impl).
3. **Add `mentl_voice_filesystem` handler** that holds the FileHandle table state and projects the 8 Interact file ops through the extended Filesystem effect. **This is composition, not a new effect** — the FileHandle table IS handler state per Insight #9.

---

## 1. Layer 1 — Filesystem effect extension

The discipline: extend, don't replace. The 4 existing ops stay
unchanged (IC.1 + cache layer continue to compose on them). Add 4 new
ops that cover the FileHandle-shaped surface.

```
effect Filesystem {
  // ─── Existing 4 ops (per FS walkthrough) ─────────────────────
  fs_exists(String) -> Bool                          @resume=OneShot
  fs_read_file(String) -> String                     @resume=OneShot
  fs_write_file(String, String) -> ()                @resume=OneShot
  fs_mkdir(String) -> ()                             @resume=OneShot

  // ─── 4 new ops (FX extension) ────────────────────────────────

  /// fs_open — open path for read+write; return WASI fd integer.
  /// Returns 0 on failure (errno not surfaced; caller checks
  /// fs_exists first if distinction needed). The returned fd is
  /// the WASI handle; the mentl_voice_filesystem handler wraps it
  /// in an opaque FileHandle ADT for the Interact surface.
  fs_open(String) -> Int                             @resume=OneShot

  /// fs_close — close a previously-opened fd. Idempotent at the
  /// runtime level (closing an invalid fd is errno-9 EBADF and
  /// silently absorbed).
  fs_close(Int) -> ()                                @resume=OneShot

  /// fs_unlink — delete a file at path. Errno surfaced as Bool
  /// (true on success, false on any error). Per WASI semantics,
  /// directory unlink is a separate op not yet exposed.
  fs_unlink(String) -> Bool                          @resume=OneShot

  /// fs_rename — rename old_path → new_path. Errno surfaced as Bool.
  /// Same-directory and cross-directory both supported (WASI's
  /// path_rename takes both base fds as the same preopen).
  fs_rename(String, String) -> Bool                  @resume=OneShot

  /// fs_list_dir — directory listing. Returns a flat List<String>
  /// of entry names (relative to the listed dir). The
  /// mentl_voice_filesystem handler projects each entry to
  /// TreeFile / TreeDir via fs_exists + fs_filestat_is_dir composition
  /// at the surface boundary (kept out of the substrate effect to
  /// avoid drift mode 8 — string-keyed-when-structured: TreeEntry IS
  /// the structured form, but only at the surface, not the syscall).
  fs_list_dir(String) -> List                        @resume=OneShot   // List<String>
}
```

**Five new ops total** (fs_open / fs_close / fs_unlink / fs_rename /
fs_list_dir). The Interact surface composes 8 file ops on these 5
substrate ops + the 4 existing ones. Composition not 1-to-1 with
substrate.

### 1.1 Why these op signatures

- **fs_open returns `Int` (WASI fd), not FileHandle.** The Filesystem
  effect stays domain-free — it doesn't know about Mentl's table
  abstraction. The mentl_voice_filesystem handler does the wrap.
- **fs_unlink / fs_rename return Bool**, not Result. Mentl has no
  Result/Either today; Bool surface is the honest truthful return
  ("succeeded? / no, but you have fs_exists if you need to disambiguate").
  Per drift mode 7-prevention: don't fabricate a Result type just for
  these; the Boolean is honest.
- **fs_list_dir returns `List<String>`.** The TreeEntry projection
  (TreeFile vs TreeDir) is per-entry stat, lifted to the
  mentl_voice_filesystem handler. Substrate stays primitive.

### 1.2 What this DOESN'T cover (named peer sub-handles)

- **`fs_filestat_is_dir(String) -> Bool`** — needed for TreeEntry
  projection. Lands as **FX.1** peer sub-handle (one runtime/io.mn
  primitive call to path_filestat_get + filestat field extraction;
  FS substrate already touches path_filestat_get).
- **Streaming file reads** (large files via chunked reads). Today
  fs_read_file fully buffers; OK for source files (typically < 1 MiB)
  but not for arbitrary user files. Lands as **FX.2** when video /
  binary surfaces matter — post-first-light territory.
- **File watching (inotify-like)** — future MV.2.e.lsp_adapter-driven
  surface. Lands as **FX.3** with the LSP adapter.
- **Permission scoping (`with Filesystem("/workspace")` parameterized
  effect)** — FS walkthrough §"Layer 2" names this; substrate ready
  via H3.1; lands when capability stances need distinction. Not FX.

---

## 2. Layer 2 — `wasi_filesystem` handler extension

Append 5 arms to the handler at `src/pipeline.mn:241`. Each arm
delegates to a new runtime/io.mn primitive. Pattern matches existing
fs_read_file_impl (path packing into scratch 256, WASI syscall via
perform, errno extraction).

### 2.1 New runtime/io.mn primitives

```
/// fs_open_impl — path_open for read+write+create.
/// Returns the fd integer or 0 on failure (caller checks via fs_exists
/// for distinction).
fn fs_open_impl(path_str) with Memory + WASI =
  let path_len = fs_write_path(path_str)
  // FS_OFLAGS_CREAT = 0x1; FS_RIGHTS_READ|WRITE = 0x42
  let open_errno = perform path_open(3, 0, 256, path_len, 1, 66, 66, 0, 576)
  if open_errno != 0 { 0 }
  else { perform load_i32(576) }

/// fs_close_impl — fd_close; errno absorbed.
fn fs_close_impl(fd) with Memory + WASI =
  perform fd_close(fd)
  ()

/// fs_unlink_impl — path_unlink_file relative to preopen fd 3.
fn fs_unlink_impl(path_str) with Memory + WASI =
  let path_len = fs_write_path(path_str)
  let errno = perform path_unlink_file(3, 256, path_len)
  errno == 0

/// fs_rename_impl — path_rename within preopen fd 3 to preopen fd 3.
/// Both paths packed into adjacent scratch regions (256 for old,
/// 256+old_len+1 for new).
fn fs_rename_impl(old_str, new_str) with Memory + WASI =
  let old_len = fs_write_path(old_str)
  let new_offset = 256 + old_len + 1
  // pack new path at new_offset
  let new_len = perform load_i32(new_str)
  perform mem_copy(new_offset, new_str + 4, new_len)
  let errno = perform path_rename(3, 256, old_len, 3, new_offset, new_len)
  errno == 0

/// fs_list_dir_impl — fd_readdir loop. Returns List<String> of entry
/// names. Implementation: open dir as fd, fd_readdir into buffer,
/// parse dirent records (8-byte d_next + 8-byte d_ino + 4-byte d_namlen
/// + d_type + name bytes), build List, fd_close.
fn fs_list_dir_impl(path_str) with Memory + Alloc + WASI = ...
```

### 2.2 Handler arms

Append to `wasi_filesystem` at pipeline.mn:241:

```
handler wasi_filesystem {
  fs_exists(path)                => resume(fs_exists_impl(path)),
  fs_read_file(path)             => resume(fs_read_file_impl(path)),
  fs_write_file(path, bytes)     => {
    fs_write_file_impl(path, bytes)
    resume()
  },
  fs_mkdir(path)                 => {
    fs_mkdir_impl(path)
    resume()
  },
  // FX additions:
  fs_open(path)                  => resume(fs_open_impl(path)),
  fs_close(fd)                   => {
    fs_close_impl(fd)
    resume()
  },
  fs_unlink(path)                => resume(fs_unlink_impl(path)),
  fs_rename(old_p, new_p)        => resume(fs_rename_impl(old_p, new_p)),
  fs_list_dir(path)              => resume(fs_list_dir_impl(path))
}
```

Per drift mode 6 + H6: every Filesystem op gets a named arm; no `_`
wildcard. Per drift mode 9: all 5 new arms land in one commit (with
the effect declaration that introduces them).

### 2.3 New runtime ops needed in lib/runtime/io.mn imports

WASI preview1 imports already declared: `path_open`, `fd_close`,
`path_filestat_get`, `path_create_directory`, `fd_read`, `fd_write`.

NEW imports needed:
- `path_unlink_file(base_fd, path_ptr, path_len) -> errno` — for fs_unlink
- `path_rename(old_base_fd, old_ptr, old_len, new_base_fd, new_ptr, new_len) -> errno` — for fs_rename
- `fd_readdir(fd, buf_ptr, buf_len, cookie, used_ptr) -> errno` — for fs_list_dir

Three additional WASI imports. All standard WASI preview1; no
new substrate.

---

## 3. Layer 3 — `mentl_voice_filesystem` handler (composition layer)

A new handler that holds the FileHandle table as state and projects
the 8 Interact file ops through the extended Filesystem effect. Lands
as a SEPARATE handler from `mentl_voice_default` (per Anchor 7
cascade discipline — file surface is its own concern; voice's
voice arms compose differently).

### 3.1 Handler state

```
handler mentl_voice_filesystem
  with handles_table = [],          // List<(FileHandle, Path, String)>
                                    //   handle, path, last-read-text
       next_handle_id = 1,           // 0 reserved as "invalid handle" sentinel
       project_root_cache = Path("./") {
  ...
}
```

State fields:
- **handles_table** — `List<(FileHandle, Path, String)>` mapping each
  open handle to its path + cached text (read-time snapshot). Per
  Insight #9: handler state is record-shaped (list of tuples here is
  the substrate idiom; OrderedMap abstraction earns its weight when
  three+ handler-state-as-table instances appear).
- **next_handle_id** — counter for minting fresh FileHandle. 0
  reserved as invalid-handle sentinel (per HEAP_BASE discipline:
  small integers as ADT tag space).
- **project_root_cache** — resolved project root Path, computed
  lazily on first project_root() call. Today's substrate has no
  WASI ABI for "current working directory" (preopen fd 3 IS the
  workspace per WASI convention); v1 uses Path("./") and lets the
  surface re-resolve to absolute via shell-side wrapper. Refined
  resolution lands as **FX.4** when the surface needs it.

### 3.2 Arm bodies

```
project_root()        => resume(project_root_cache),

tree_list(path)       => {
  let Path(s) = path
  let names = perform fs_list_dir(s)
  let entries = project_tree_entries(names, path)    // helper
  resume(entries)
},

open_file(path)       => {
  let Path(s) = path
  let fd = perform fs_open(s)
  if fd == 0 {
    resume(FileHandle(0))             // invalid handle sentinel
  } else {
    let text = perform fs_read_file(s)
    let new_handle = FileHandle(next_handle_id)
    let new_table = [(new_handle, path, text)] ++ handles_table
    resume(new_handle)
      with handles_table  = new_table,
           next_handle_id = next_handle_id + 1
  }
},

save_file(fh)         => {
  let entry = handles_table_lookup(handles_table, fh)
  match entry {
    None              => resume(),       // invalid handle; silent absorb (idempotent)
    Some(triple)      => {
      let (_, path, text) = triple
      let Path(s) = path
      perform fs_write_file(s, text)
      resume()
    }
  }
},

create_file(p, text)  => {
  let Path(s) = p
  perform fs_write_file(s, text)
  let fd = perform fs_open(s)
  if fd == 0 {
    resume(FileHandle(0))
  } else {
    let new_handle = FileHandle(next_handle_id)
    let new_table = [(new_handle, p, text)] ++ handles_table
    resume(new_handle)
      with handles_table  = new_table,
           next_handle_id = next_handle_id + 1
  }
},

rename_path(old_p, new_p) => {
  let Path(o) = old_p
  let Path(n) = new_p
  perform fs_rename(o, n)
  resume()
},

delete_path(p)        => {
  let Path(s) = p
  perform fs_unlink(s)
  resume()
},

file_text(fh)         => {
  let entry = handles_table_lookup(handles_table, fh)
  match entry {
    None              => resume(""),     // invalid handle; empty text
    Some(triple)      => {
      let (_, _, text) = triple
      resume(text)
    }
  }
}
```

### 3.3 Helpers (Pure / Filesystem)

```
fn handles_table_lookup(table, target_handle) with Pure = ...
fn project_tree_entries(names, base_path) with Filesystem = ...
fn tree_entry_for(name, base_path) with Filesystem = ...    // calls fs_filestat_is_dir
fn file_handle_eq(a, b) with Pure = ...
```

`project_tree_entries` calls `fs_filestat_is_dir` per entry to
project to TreeFile vs TreeDir. **FX.1 peer sub-handle adds the
fs_filestat_is_dir op + impl + handler arm** (small; folds into
this batch's commit OR lands as separate per Anchor 7 — recommend
separate so this commit stays focused on the 5 syscall ops).

### 3.4 Composition with mentl_voice_default

The two handlers compose via `~>` chain at the LSP adapter layer:

```
inka_lsp_session(stdin, stdout)
  ~> mentl_voice_filesystem
  ~> mentl_voice_default
  ~> wasi_filesystem
```

Order matters (per Insight #1: handler chain IS capability stack):
- **Outermost (`inka_lsp_session`)** owns the JSON-RPC transport.
- **`mentl_voice_filesystem`** intercepts file-shaped Interact ops;
  passes voice ops through.
- **`mentl_voice_default`** intercepts voice ops + state ops; passes
  Filesystem ops through.
- **Innermost (`wasi_filesystem`)** is the WASI substrate.

Each arm passes through (resume(perform op)) for ops it doesn't
handle. **Both Mentl handlers ignore each other's ops at install
time via row subsumption** — `mentl_voice_filesystem` declares it
handles `project_root / tree_list / ... / file_text`;
`mentl_voice_default` declares the rest. Type checker proves
disjointness; install fails with `E_HandlerOverlap` if they collide
(future substrate; today: discipline).

---

## 4. The eight interrogations

| # | Interrogation | Answer |
|---|---|---|
| 1 | Graph? | FileHandle is opaque substrate; not graph-resident. project_root could index a graph node for the project's synthetic Module handle (per F.1 §3.2). Defer to FX.4. |
| 2 | Handler? | `wasi_filesystem` extended (5 new arms); NEW `mentl_voice_filesystem` handler with FileHandle table state. All ops `@resume=OneShot`. |
| 3 | Verb? | `~>` chain composes the three handlers (inka_lsp_session ~> mentl_voice_filesystem ~> mentl_voice_default ~> wasi_filesystem). Per Insight #1: outermost = least trusted. |
| 4 | Row? | `with Filesystem` widens to include 5 new ops; `with !Filesystem` still proves absence (audit-driven severance can drop ALL 9 path_* / fd_* imports). The negation algebra unchanged. |
| 5 | Ownership? | FileHandle is `own`-to-handler-table (consumed-on-close semantics surface as save_file invalidating after the LSP adapter's didClose). Today: no explicit fs_close from Interact; handler holds handles for session lifetime. **FX.5 peer sub-handle adds explicit close_file Interact op** when LSP didClose plumbing matters. |
| 6 | Refinement? | Path could be `Path = String where !contains_dotdot(self) && len(self) > 0`. Defer to MV.2.e.Q.refine. |
| 7 | Gradient? | Each new substrate op is one gradient step. Filesystem-extension unblocks 12 Interact arms — large compound unlock per Insight #12 (compound interest of substrate). |
| 8 | Reason? | FileHandle table entries carry their open-time Reason chain (the Interact op that minted them). Mentl's Why tentacle later answers "why is this file open?" by walking the table entry's Reason. |

---

## 5. Drift modes audited

- **Mode 1 (Rust vtable):** ✗ — handlers are typed effect handlers; no dispatch table.
- **Mode 4 (handler-chain-as-monad-transformer):** ✗ — `~>` chain is composition, not stacked monad. Each handler's row is independent.
- **Mode 6 (primitive-type-special-case):** ✗ — FileHandle / Path / TreeEntry all structured ADTs.
- **Mode 7 (parallel-arrays-instead-of-record):** ✗ — handles_table is List<(FileHandle, Path, String)> tuples; OrderedMap abstraction deferred until 3+ table-state instances earn it.
- **Mode 8 (string-keyed-when-structured):** ✗ — TreeEntry IS the structured form for tree listings; substrate fs_list_dir returns strings, but the handler immediately projects to TreeEntry ADT before crossing the Interact surface.
- **Mode 9 (deferred-by-omission):** ✓ — peer sub-handles named explicitly (FX.1 / FX.2 / FX.3 / FX.4 / FX.5); each lands in its own commit when load-bearing.

---

## 6. Sub-handle decomposition

Each lands in its own commit per Anchor 7:

| Handle | Scope | Gate |
|---|---|---|
| **FX.0** | This walkthrough drafted | (this commit) |
| **FX.A** | Filesystem effect extension (5 new ops) + wasi_filesystem arms + 3 new WASI imports + 5 runtime/io.mn primitives | walkthrough closure |
| **FX.B** | mentl_voice_filesystem handler + 8 Interact arms + helpers | FX.A landed |
| **FX.1** | fs_filestat_is_dir op + TreeEntry projection in project_tree_entries | FX.A landed; folds into FX.B if scoped together |
| **FX.2** | Streaming file reads for arbitrary-size files | post-first-light (substrate ready; surface absent) |
| **FX.3** | File watching (inotify) for LSP adapter | gates on LSP adapter substrate |
| **FX.4** | Refined Path type + project_root via graph synthesis | gates on F.1 Module handle substrate |
| **FX.5** | close_file Interact op + handler table cleanup | gates on LSP didClose plumbing |

**FX.A + FX.B together unblock 12 of 22 Interact arms** (8 file ops +
edit + 3 run_* ops). After they land, Mentl's voice surface is at
22/22 arms substrate-live (modulo the run_* ops needing pipeline
composition which is a separate substrate question).

---

## 7. What this walkthrough does NOT cover

- **LSP transport (JSON-RPC framing, message handling).** That's
  MV.2.e.lsp_adapter — a separate handler that wraps the three-layer
  stack above. FX provides the Interact composition; lsp_adapter
  provides the LSP-method-to-Interact-op routing.
- **Project-wide search / find-references.** Composes on tree_list
  + file_text + Query.ask(QRefsOf). Substrate-ready post-FX-B.
- **File content diffing for incremental updates.** Today: didChange
  → save_file(full text); tomorrow: textDocument/didChange's
  contentChanges as Patch ops via edit. **Edit op (MV.2.e.P.edit)
  unblocks via FX-B + Patch ADT verification (mentl.mn:55).**

---

## 8. Sequencing

1. **FX.0** (this walkthrough) — done in this commit.
2. **FX.A** (Filesystem extension + wasi_filesystem + WASI imports +
   runtime primitives) — single commit; all ops + arms + impls
   together to honor drift mode 9. Estimated ~80 lines `.mn` (effect
   decl + handler arms + 5 runtime/io.mn primitives) + 3 WASI
   import declarations.
3. **FX.B** (mentl_voice_filesystem handler + 8 Interact arms +
   helpers) — single commit. Estimated ~150 lines `.mn`. Gated on
   FX.A.
4. **FX.1** (fs_filestat_is_dir + TreeEntry projection) — folds into
   FX.B if scoped together; otherwise its own commit. ~20 lines.
5. **MV.2.e.P.edit** — Patch verification + edit arm. Lands after
   FX.B unblocks FileHandle.
6. **MV.2.e.Run** — run_compile / run_check / run_audit arms. Lands
   after FX.B unblocks file_text. Each composes through pipeline;
   may need its own walkthrough for pipeline composition.
7. **MV.2.e.lsp_adapter** — LSP transport handler wrapping the
   three-layer stack. Its own walkthrough required.

After FX.B lands, MV.2.e arc is **22/22 arms substrate-live** (modulo
Run ops needing pipeline composition). The Mentl-voice substrate is
complete; what remains is the LSP transport surface and post-MV.2.e
ops (lsp_adapter).

---

## 9. Authority

This walkthrough supersedes the FS walkthrough's Layer 2 sketch
about parameterized Filesystem grants; FX leaves that for FX.4
(refined Path + Module-handle-resolved project_root). Existing FS
substrate (commit `1debfdc`) unchanged; this is pure extension.

The 1-to-1-to-1 kernel mapping holds: every new Filesystem op
answers all eight interrogations; every new handler arm projects one
primitive's voice through the Interact surface. **Mentl's eight
tentacles compose on the closed kernel; FX extends the substrate to
let her file-shaped composition surface.**
