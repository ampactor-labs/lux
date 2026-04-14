# The Lux Memory Superpower: Ownership + Scoped Allocators

**Date:** 2026-04-12
**Status:** Arc 3 Crystalization

## The Problem

Traditional memory management forces languages into a strict binary:
1. **Manual Memory Management (C/C++, Rust):** Highly performant, requires manual `malloc`/`free`. Rust makes this safe via borrow checking, but it still requires cognitive overhead, lifetimes, and struct typing.
2. **Garbage Collection (Java, Go, JS):** Easy to write. But introduces "Stop the World" pauses, heavy runtime footprints, and background threading non-determinism.

For WebAssembly workloads, neither is ideal. Native WASM environments shouldn't need a heavy GC runtime shipped inside them, and developers building the web shouldn't have to fight the borrow checker just to return a string.

## The Bootstrap Insight

During the Arc 2 bootstrap of `lux4.wasm` (Ouroboros), we encountered O(N³) memory explosions in diagnostic generation (specifically, Levenshtein distance on typo suggestions). With a simple bump allocator, this exhausted WASM's 2 GiB memory limit.

Our initial instinct was traditional: *"We need a Garbage Collector for Arc 3 to clean up these dead diagnostic strings."*

But we realized we **don't**. We already have everything we need built into Lux's core philosophy.

## The Superpower: `Alloc` as an Effect + Ownership

In Lux, `Alloc` is not a magic compiler keyword—**it is an Effect.**

```lux
fn split(s, sep) with Alloc = ...
```

In Arc 2, our bump allocator is simply the top-level, unbreakable handler for `Alloc`. Every byte allocated lives forever. But because `Alloc` is an effect, we can shadow it with scoped handlers.

### 1. Scoped Memory Arenas

Instead of relying on a sweeping GC, we can wrap complex, memory-heavy operations in temporary arenas:

```lux
let similar = handle { 
  find_similar_name(e, name) // Allocates 50MB of dead string fragments
} with temp_arena
```

`temp_arena` intercepts all `alloc(size)` calls within its block. When `find_similar_name` finishes, the `temp_arena` scope drops, instantly "freeing" all 50MB by simply resetting its internal pointer to zero. 

It is instantaneous, deterministic garbage collection without a collector.

### 2. Eliminating Use-After-Free via Ownership

Scoped allocators exist in C/C++ (Arena allocators), but they are notoriously dangerous. If `find_similar_name` returns a pointer to a string that lives *inside* the `temp_arena`, the moment the scope drops, that pointer becomes a dangling reference (Use-After-Free).

**This is where Lux's Ownership system takes over.**

Lux maintains a borrow graph (via the `report_ownership` compiler pass). If `find_similar_name` returns `similar`, the compiler statically knows that `similar` points to memory "owned" by `temp_arena`. 

When we try to use `similar` outside the block, the compiler forces our hand:
> *error: 'similar' escapes the lifetime of 'temp_arena'. Must copy or consume before scope exits.*

We are safely forced to formally `copy` the *one* final string into the parent's `Alloc` scope, leaving the 50MB of intermediate garbage safely in the collapsing arena.

## Implications for the Language

This paradigm creates massive downstream superpowers for Arc 3 and beyond:

### 1. Zero-Cost Mentorship
Diagnostics like `find_similar_name` can be written as sloppily and functionally as possible (O(N³) recursive string concatenation!) without any optimization. By isolating them in a `DiagnosticArena`, the memory footprint is theoretically boundless but practically nonexistent. Mentorship code doesn't need to be fast, it just needs to be isolated.

### 2. Lock-Free Concurrency
WASM threads usually require a global allocator protected by an atomic mutex—meaning threads bottleneck each other every time they allocate. In Lux, if `Alloc` is handled via thread-local memory effects by default, concurrency scales infinitely with zero locking out of the box.

### 3. User-Space Memory Engineering
Lux doesn't need to ship a GC inside its WASM binaries. There is no heavy runtime. Developers have complete native control over memory strategies—building their own pool allocators, ring buffers, generational arenas, or WebGL shared memory handlers—by simply writing new handlers for the `Alloc` effect, all statically verified by the ownership system. 

**Result**: The performance and native control of Rust with the ergonomics of a functional language.
