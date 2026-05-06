  ;; ═══ wasi_fs.wat — WASI filesystem extensions (Tier 4) ════════════
  ;; Implements: FX walkthrough (FX.A.basics + FX.A.dirent + FX.1) at
  ;;             the WAT layer. Provides path-level filesystem
  ;;             primitives the compiled wheel's `wasi_filesystem`
  ;;             handler arms call into. The seed itself does NOT use
  ;;             these (it reads source via stdin); they exist as
  ;;             substrate for the wheel post-L1.
  ;; Exports:    $fs_set_cwd_fd, $fs_get_cwd_fd,
  ;;             $fs_create_directory, $fs_unlink, $fs_rename,
  ;;             $fs_filestat_is_dir,
  ;;             $fs_list_dir
  ;; Uses:       Layer 0 imports: $wasi_path_create_directory,
  ;;               $wasi_path_filestat_get, $wasi_path_unlink_file,
  ;;               $wasi_path_rename, $wasi_fd_readdir
  ;;             $alloc (alloc.wat), $str_alloc/len/byte_at (str.wat),
  ;;             $make_list/$list_set/$list_extend_to/$len (list.wat)
  ;; Test:       runtime_test/wasi_fs.wat
  ;;
  ;; ═══ DESIGN ═══════════════════════════════════════════════════════
  ;; Per FX walkthrough commit `61b2b60` + FX.A.basics (`d801511`) +
  ;; FX.B (`afc4b0c`) substrate already in lib/runtime/io.mn +
  ;; src/mentl_voice.mn mentl_voice_filesystem handler.
  ;;
  ;; This is the WAT-level transcription of the FX substrate. It
  ;; provides path-relative-to-fd primitives that wrap WASI preview1
  ;; calls; the compiled wheel's wasi_filesystem handler arms call
  ;; these directly via H1 evidence-passing dispatch.
  ;;
  ;; ═══ CWD CONVENTION ═══════════════════════════════════════════════
  ;; WASI preview1 requires path operations to be relative to a
  ;; preopened directory file descriptor. Wasmtime convention: when
  ;; invoked with `--dir=.`, fd 3 is preopened as the current
  ;; directory. wasi_fs.wat defaults $wasi_fs_cwd_fd to 3; callers can
  ;; override via $fs_set_cwd_fd if running under a different invocation.
  ;;
  ;; If the runtime is invoked WITHOUT --dir, all $fs_* operations
  ;; will return non-zero errno (typically EBADF). Callers handle the
  ;; errno per the existing FX.A.basics pattern.
  ;;
  ;; ═══ ERRNO CONVENTION ═════════════════════════════════════════════
  ;; All $fs_* operations that touch the filesystem return WASI errno
  ;; (i32, 0 = success). Callers test the return value; non-zero is
  ;; surfaced via the wasi_filesystem handler arm's diagnostic chain
  ;; per the FX walkthrough.

  ;; ─── CWD fd configuration ─────────────────────────────────────────
  (global $wasi_fs_cwd_fd_g (mut i32) (i32.const 3))

  (func $fs_set_cwd_fd (param $fd i32)
    (global.set $wasi_fs_cwd_fd_g (local.get $fd)))

  (func $fs_get_cwd_fd (result i32)
    (global.get $wasi_fs_cwd_fd_g))

  ;; ─── path_create_directory wrapper ───────────────────────────────
  ;; $fs_create_directory(path) — creates directory relative to cwd_fd.
  ;; Returns WASI errno. Path must not already exist (caller checks
  ;; via $fs_filestat_is_dir before).
  (func $fs_create_directory (param $path i32) (result i32)
    (local $path_bytes i32) (local $path_len i32)
    (local.set $path_bytes (i32.add (local.get $path) (i32.const 4)))   ;; past length prefix
    (local.set $path_len   (call $str_len (local.get $path)))
    (call $wasi_path_create_directory
      (global.get $wasi_fs_cwd_fd_g)
      (local.get $path_bytes)
      (local.get $path_len)))

  ;; ─── path_unlink_file wrapper ────────────────────────────────────
  ;; $fs_unlink(path) — removes a file (NOT a directory) relative to cwd_fd.
  (func $fs_unlink (param $path i32) (result i32)
    (local $path_bytes i32) (local $path_len i32)
    (local.set $path_bytes (i32.add (local.get $path) (i32.const 4)))
    (local.set $path_len   (call $str_len (local.get $path)))
    (call $wasi_path_unlink_file
      (global.get $wasi_fs_cwd_fd_g)
      (local.get $path_bytes)
      (local.get $path_len)))

  ;; ─── path_rename wrapper ─────────────────────────────────────────
  ;; $fs_rename(old_path, new_path) — atomic rename. Both paths
  ;; relative to cwd_fd. Same destination dir parameter for both.
  (func $fs_rename (param $old i32) (param $new i32) (result i32)
    (local $old_bytes i32) (local $old_len i32)
    (local $new_bytes i32) (local $new_len i32)
    (local.set $old_bytes (i32.add (local.get $old) (i32.const 4)))
    (local.set $old_len   (call $str_len (local.get $old)))
    (local.set $new_bytes (i32.add (local.get $new) (i32.const 4)))
    (local.set $new_len   (call $str_len (local.get $new)))
    (call $wasi_path_rename
      (global.get $wasi_fs_cwd_fd_g)
      (local.get $old_bytes) (local.get $old_len)
      (global.get $wasi_fs_cwd_fd_g)
      (local.get $new_bytes) (local.get $new_len)))

  ;; ─── path_filestat_get wrapper — is_dir test ─────────────────────
  ;; $fs_filestat_is_dir(path) — returns 1 if path is a directory
  ;; (existing + filetype = WASI_FILETYPE_DIRECTORY = 3); else 0
  ;; (including non-existing or other types).
  ;;
  ;; WASI filestat layout (per preview1):
  ;;   offset  0: dev          (u64)
  ;;   offset  8: ino          (u64)
  ;;   offset 16: filetype     (u8 — see WASI filetype constants)
  ;;   offset 17: pad
  ;;   offset 24: nlink        (u64)
  ;;   offset 32: size         (u64)
  ;;   offset 40: atim         (u64)
  ;;   offset 48: mtim         (u64)
  ;;   offset 56: ctim         (u64)
  ;;
  ;; WASI_FILETYPE_DIRECTORY = 3 (per preview1 ABI).
  ;; WASI_LOOKUPFLAGS_SYMLINK_FOLLOW = 1 (follow symlinks during stat).
  (func $fs_filestat_is_dir (param $path i32) (result i32)
    (local $path_bytes i32) (local $path_len i32)
    (local $stat_buf i32) (local $errno i32) (local $filetype i32)
    (local.set $path_bytes (i32.add (local.get $path) (i32.const 4)))
    (local.set $path_len   (call $str_len (local.get $path)))
    (local.set $stat_buf   (call $alloc (i32.const 64)))   ;; filestat is 64 bytes
    (local.set $errno
      (call $wasi_path_filestat_get
        (global.get $wasi_fs_cwd_fd_g)
        (i32.const 1)                  ;; lookup flags = SYMLINK_FOLLOW
        (local.get $path_bytes)
        (local.get $path_len)
        (local.get $stat_buf)))
    (if (i32.ne (local.get $errno) (i32.const 0))
      (then (return (i32.const 0))))   ;; non-existing or error → not a dir
    ;; Read filetype byte at offset 16.
    (local.set $filetype (i32.load8_u offset=16 (local.get $stat_buf)))
    (i32.eq (local.get $filetype) (i32.const 3)))    ;; WASI_FILETYPE_DIRECTORY = 3

  ;; ─── fd_readdir wrapper — directory listing ──────────────────────
  ;; $fs_list_dir(path) — opens path as a directory, reads entries,
  ;; returns a flat list of name strings (parsed dirents). Returns
  ;; empty list on error (non-existing dir / not-a-dir / permission).
  ;;
  ;; WASI dirent layout (per preview1):
  ;;   offset  0: d_next       (u64 — cookie for next call)
  ;;   offset  8: d_ino        (u64)
  ;;   offset 16: d_namlen     (u32 — name length)
  ;;   offset 20: d_type       (u8)
  ;;   offset 21..23: pad
  ;;   offset 24: name_bytes... (UTF-8, no null terminator)
  ;; Header total = 24 bytes; entry size = 24 + d_namlen, then padded
  ;; to 8-byte alignment for the next dirent.
  ;;
  ;; This wrapper opens the directory via $wasi_path_open (fd_flags=0,
  ;; oflags=O_DIRECTORY=2, rights including DIRECTORY_READ +
  ;; FD_READDIR), calls $wasi_fd_readdir into a 4096-byte buffer,
  ;; parses dirents from the buffer, and returns the list of name
  ;; strings.
  ;;
  ;; Limitation (Tier-4 base): single-pass; if the directory has more
  ;; entries than fit in 4096 bytes, only the first batch is returned.
  ;; The cookie-driven multi-call pattern is the named follow-up.
  (func $fs_list_dir (param $path i32) (result i32)
    (local $path_bytes i32) (local $path_len i32)
    (local $fd_out_ptr i32) (local $errno i32) (local $dir_fd i32)
    (local $buf i32) (local $bufused_ptr i32) (local $bufused i32)
    (local $offset i32) (local $namelen i32) (local $name_str i32)
    (local $entry_size i32) (local $entry_padded i32) (local $padding i32)
    (local $names i32) (local $count i32)
    (local.set $path_bytes (i32.add (local.get $path) (i32.const 4)))
    (local.set $path_len   (call $str_len (local.get $path)))
    ;; Open the directory: caller_fd = cwd, dirflags = SYMLINK_FOLLOW (1),
    ;; oflags = O_DIRECTORY (2), rights_base = ... (broad — let WASI
    ;; runtime narrow per its policy), rights_inheriting = same,
    ;; fdflags = 0.
    (local.set $fd_out_ptr (call $alloc (i32.const 4)))
    (local.set $errno
      (call $wasi_path_open
        (global.get $wasi_fs_cwd_fd_g)
        (i32.const 1)                  ;; dirflags = SYMLINK_FOLLOW
        (local.get $path_bytes) (local.get $path_len)
        (i32.const 2)                  ;; oflags = O_DIRECTORY
        (i64.const 0xffffffff)         ;; rights_base — broad
        (i64.const 0xffffffff)         ;; rights_inheriting — broad
        (i32.const 0)                  ;; fdflags = 0
        (local.get $fd_out_ptr)))
    (if (i32.ne (local.get $errno) (i32.const 0))
      (then (return (call $make_list (i32.const 0)))))
    (local.set $dir_fd (i32.load (local.get $fd_out_ptr)))
    ;; Read entries into a 4096-byte buffer.
    (local.set $buf (call $alloc (i32.const 4096)))
    (local.set $bufused_ptr (call $alloc (i32.const 4)))
    (local.set $errno
      (call $wasi_fd_readdir
        (local.get $dir_fd)
        (local.get $buf)
        (i32.const 4096)
        (i64.const 0)                  ;; cookie 0 = start
        (local.get $bufused_ptr)))
    (drop (call $wasi_fd_close (local.get $dir_fd)))
    (if (i32.ne (local.get $errno) (i32.const 0))
      (then (return (call $make_list (i32.const 0)))))
    (local.set $bufused (i32.load (local.get $bufused_ptr)))
    ;; Parse dirents into a name list.
    (local.set $names (call $make_list (i32.const 16)))
    (local.set $count (i32.const 0))
    (local.set $offset (i32.const 0))
    (block $done
      (loop $parse
        ;; Need at least 24 bytes for header; otherwise stop.
        (br_if $done
          (i32.gt_u (i32.add (local.get $offset) (i32.const 24))
                    (local.get $bufused)))
        ;; Read d_namlen at offset+16 (u32).
        (local.set $namelen
          (i32.load
            (i32.add (local.get $buf) (i32.add (local.get $offset) (i32.const 16)))))
        (local.set $entry_size (i32.add (i32.const 24) (local.get $namelen)))
        ;; Need full entry to fit in buffer.
        (br_if $done
          (i32.gt_u (i32.add (local.get $offset) (local.get $entry_size))
                    (local.get $bufused)))
        ;; Allocate name string + memcopy from buf.
        (local.set $name_str (call $str_alloc (local.get $namelen)))
        (memory.copy
          (i32.add (local.get $name_str) (i32.const 4))
          (i32.add (local.get $buf) (i32.add (local.get $offset) (i32.const 24)))
          (local.get $namelen))
        ;; Append name to names list.
        (local.set $names
          (call $list_set
            (call $list_extend_to (local.get $names)
                                  (i32.add (local.get $count) (i32.const 1)))
            (local.get $count)
            (local.get $name_str)))
        (local.set $count (i32.add (local.get $count) (i32.const 1)))
        ;; Advance offset by entry_size, padded to 8-byte boundary.
        (local.set $padding
          (i32.and (i32.sub (i32.const 0) (local.get $entry_size)) (i32.const 7)))
        (local.set $entry_padded (i32.add (local.get $entry_size) (local.get $padding)))
        (local.set $offset (i32.add (local.get $offset) (local.get $entry_padded)))
        (br $parse)))
    ;; Truncate names to actual count via slice.
    (call $slice (local.get $names) (i32.const 0) (local.get $count)))
