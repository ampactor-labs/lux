# Handle FS — Filesystem Effect + WASI Handler

*Role-play as Mentl, tracing what happens when `cache.mn` calls
`perform fs_write_file("synth/core.mn.kai", bytes)`. Today the
substrate has no Filesystem effect — stdin / stdout / stderr are
the only I/O surfaces. The cascade built the ability to declare
new effects cleanly (H3.1's EffName makes parameterized effects
structural; H1's evidence machinery handles poly dispatch); FS is
the first post-cascade effect to land using that discipline.*

---

## The scenario

`cache.mn` (IC work) needs to:

1. Check whether `.mentl/cache/infer.mn.kai` exists.
2. Read its bytes if present.
3. Write fresh bytes after recompilation.
4. Create the `.mentl/cache/` directory on first run.

Four Filesystem operations. All map to WASI preview1 syscalls
already available to any WASI runtime (wasmtime, node-wasi,
browser-wasi). The substrate needs:

- A `Filesystem` effect with the operations.
- A `wasi_filesystem` handler implementing them via WASI imports.
- Emit-side recognition of the WASI imports.
- runtime/io.mn primitives that pack arguments into the iov
  scratch space (same pattern as print_string).

---

## Layer 1 — Effect declaration

In `types.mn`:

```
// Filesystem — per-file byte I/O via WASI preview1 semantics.
// File paths are relative to a preopen directory (wasmtime grants
// access via --dir=.). The handler routes each op through WASI's
// path_open / fd_read / fd_write / fd_close / path_create_directory.
//
// Parameterization: the fs_preopen effect argument distinguishes
// different directory grants (`with Filesystem("/workspace")` vs
// `with Filesystem("/tmp")`). v1 uses bare Filesystem; the
// parameterized form lands when audit-driven severance needs to
// distinguish permissions.

effect Filesystem {
  fs_exists(String) -> Bool                              @resume=OneShot
  fs_read_file(String) -> List                           @resume=OneShot
                                                    // returns bytes as List<Int>
  fs_write_file(String, List) -> ()                      @resume=OneShot
                                                    // path, bytes
  fs_mkdir(String) -> ()                                 @resume=OneShot
}
```

Four operations — enough for IC's cache layer. Future-forward
additions (fs_list_dir, fs_delete, fs_rename, fs_stat) arrive
with the surfaces that need them.

---

## Layer 2 — WASI imports

The emit-side module header imports the required WASI functions:

```wat
(import "wasi_snapshot_preview1" "path_open"
  (func $path_open (param i32 i32 i32 i32 i32 i64 i64 i32 i32) (result i32)))
(import "wasi_snapshot_preview1" "fd_close"
  (func $fd_close (param i32) (result i32)))
(import "wasi_snapshot_preview1" "path_create_directory"
  (func $path_create_directory (param i32 i32 i32) (result i32)))
(import "wasi_snapshot_preview1" "path_filestat_get"
  (func $path_filestat_get (param i32 i32 i32 i32 i32) (result i32)))
```

`fd_write` and `fd_read` are already imported (stdio). They work
on any fd, not just 0/1/2 — `path_open` returns a fresh fd that
these accept.

**Preopen fd.** WASI grants access to the host filesystem via
preopen fds. At wasmtime startup, the runtime is given `--dir=.`
(or similar); the wasmtime loader assigns preopen fd 3 by
convention. All `path_open` calls take a base fd (the preopen)
and a relative path. The Filesystem handler uses preopen fd 3
as its base; future work parameterizes this.

---

## Layer 3 — runtime/io.mn primitives

Each effect op becomes a runtime helper that packs arguments
into the iov scratch region (same pattern as print_string's
`perform fd_write(1, 80, 1, 88)` call where 80 is the iov pointer
and 88 is the bytes-written-output pointer):

```
// fs_exists — path_filestat_get returns 0 on success, error otherwise.
fn fs_exists_impl(path_str) with Memory + WASI = {
  let path_bytes = str_bytes(path_str)
  let path_ptr = 256                   // scratch region for path
  let path_len = list_len(path_bytes)
  write_bytes_to_mem(path_ptr, path_bytes)
  let statbuf_ptr = 512                // scratch for filestat_t
  let errno = perform path_filestat_get(3, 0, path_ptr, path_len, statbuf_ptr)
  errno == 0
}

// fs_read_file — path_open + read loop + fd_close.
fn fs_read_file_impl(path_str) with Memory + Alloc + WASI = { ... }

// fs_write_file — path_open with create flag + write loop + fd_close.
fn fs_write_file_impl(path_str, bytes) with Memory + Alloc + WASI = { ... }

// fs_mkdir — path_create_directory.
fn fs_mkdir_impl(path_str) with Memory + WASI = {
  let path_bytes = str_bytes(path_str)
  let path_ptr = 256
  let path_len = list_len(path_bytes)
  write_bytes_to_mem(path_ptr, path_bytes)
  perform path_create_directory(3, path_ptr, path_len)
  ()
}
```

The full implementations involve iov scratch layout details that
mirror existing print_string's structure. Bounded mechanical work;
walkthrough doesn't need each line, just the shape.

---

## Layer 4 — wasi_filesystem handler

In `pipeline.mn` (or a new `std/compiler/filesystem.mn` if it grows):

```
handler wasi_filesystem {
  fs_exists(path)                    => resume(fs_exists_impl(path)),
  fs_read_file(path)                 => resume(fs_read_file_impl(path)),
  fs_write_file(path, bytes)         => resume(fs_write_file_impl(path, bytes)),
  fs_mkdir(path)                     => resume(fs_mkdir_impl(path))
}
```

Four arms. Stateless. Each delegates to the runtime primitive.

The handler installs in the `compile` pipeline's `~>` chain:

```
fn compile(source) =
  source
    |> frontend
    |> infer_program
    |> lower_program
    |> emit_module
    ~> wat_stdout
    ~> wasi_filesystem                // NEW — grants FS access to driver
    ~> string_table
    ~> emit_memory_bump
    ~> body_context
    ...
```

`~>` position matters: fs lands OUTSIDE the compiler-internal
handlers (so the compiler's code itself doesn't accidentally use
fs) but INSIDE the top-level wat_stdout (so driver code can write
to disk).

---

## Layer 5 — what closes when FS lands

- `.kai` cache files become writable/readable (IC.1 unblocked).
- `mentl check <path>` / `mentl build <path>` can read `.mn` source
  files from disk (today main.mn reads stdin only — requires FS
  to take a path argument).
- DESIGN.md Ch 9.1 (package manager dissolution) gains a concrete
  Filesystem surface for the `Package` effect's `fetch(path)` op.
- Audit-driven linker severance (Priority 2) can write the output
  binary. Today emit writes to stdout only.
- Tests-as-handlers (DESIGN Ch 9.2) becomes practical — test
  handler writes result reports to a file.

---

## What FS reveals (expected surprise)

- **The `with !Filesystem` row constraint becomes meaningful.** A
  function declared `with !Filesystem` is PROVEN not to touch the
  filesystem. Audit can severe the WASI filesystem imports from
  binaries that prove `!Filesystem`. This is DESIGN.md 10.3's
  "capability severance" realized for one of its load-bearing
  capabilities.
- **Preopen fd is a handler-state parameter.** v1 hardcodes 3.
  Parameterizing via `with Filesystem("/workspace")` (H3.1's
  parameterized effects) lets different scopes grant different
  access. The substrate is ready; the handler-state refactor is
  additive.
- **Bytes-as-List<Int> is the v1 shape.** Lists are the substrate's
  universal collection. Reading a 1MB cache as List<Int> is O(N)
  memory but each Int is 4 bytes — 4x overhead. Post-IC-lands-
  and-measures, a byte-buffer primitive (packed i8 array) is worth
  considering. v1 pays the overhead; optimization is its own
  follow-up.

---

## Design synthesis

**Filesystem effect** — 4 ops (exists, read_file, write_file, mkdir).
Row entries use ENamed("Filesystem"); parameterized form deferred.

**WASI imports** — path_open, fd_close, path_create_directory,
path_filestat_get added to emit's import preamble. fd_write /
fd_read work on opened fds already.

**runtime primitives** — 4 impl functions in runtime/io.mn using
the existing iov scratch pattern.

**wasi_filesystem handler** — 4-arm stateless handler installed in
the compile pipeline.

**Audit integration** — Filesystem becomes a canonical severance
candidate alongside Alloc / IO / Network. `capabilities_for_severance`
gains an entry (already anticipated in H5 landing).

---

## Dependencies

- Substrate fully closed (cascade). Nothing pends for FS to land.
- IC.1 (cache.mn) is the immediate consumer; FS lands just before IC.1.

---

## Estimated scope

- ~150 lines across 3 files:
  - `types.mn` — Filesystem effect decl (~20 lines)
  - `runtime/io.mn` — 4 impl fns + scratch layout (~100 lines)
  - `pipeline.mn` — wasi_filesystem handler + install (~30 lines)
- `backends/wasm.mn` emit header gains 4 import lines.

Single commit. Mechanical extension using established patterns
(mirror print_string's iov structure).

---

## Verification

Walkthrough: trace `fs_write_file("hello.txt", [72, 105])` through
the pipeline.

1. `perform fs_write_file(...)` at call site.
2. wasi_filesystem's arm fires, delegates to fs_write_file_impl.
3. fs_write_file_impl: str_bytes(path) → bytes in memory;
   path_open syscall returns new fd; fd_write writes the bytes;
   fd_close releases fd.
4. Resume with ().

Confirm no handle leakage (fd always closed), no ambient
authority (all access through preopen fd 3).

---

## Ordering

FS lands FIRST in the IC commit cluster. Order:
  FS (enables cache I/O)
  → IC.1 cache.mn
  → IC.2 driver.mn
  → IC.3 graph.mn chase extension
  → IC.4 pipeline/main wiring
