;; EXPANDED TEMPLATE START
{{BODY}}
;; EXPANDED TEMPLATE END
// cache.nx — incremental compilation cache (IC.1b — graph-native)
//
// Per-module .kai files in <project>/.inka/cache/. Each file records
// the source hash that produced this cache entry plus the module's
// public env (the "envelope"); the driver compares hashes to decide
// cache hit vs miss, and on hit loads the env to skip re-inference.
//
// IC.1b: Binary persistence through Pack / Unpack effects. The graph
// projects itself — no text parsing, no split(), no string assembly.
// Every Ty variant gets a tag byte; the handler accumulates the bytes.
// Inka solving Inka: the substrate persists itself.
//
// Walkthrough: docs/rebuild/simulations/IC-incremental-compilation.md.

import types
import runtime/strings
import runtime/binary
import runtime/io

// ═══ KaiFile — per-module cache record ═════════════════════════════
// Field-sorted alphabetically per parser invariant (post-H2). Adding
// fields is additive — old caches with mi