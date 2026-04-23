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
// fields is additive — old caches with mi;; bootstrap/templates/match_dispatch.wat
;; 
;; The Inka ADT Match Dispatch Template
;; Resolves the tag of any scrutinee by checking it against HEAP_BASE.
;; If < HEAP_BASE, it is a nullary sentinel (the value IS the tag).
;; If >= HEAP_BASE, it is a pointer (the tag is loaded from offset 0).

(local $scrutinee i32)
(local $tag i32)

;; Expects scrutinee on the stack.
(local.set $scrutinee)

(if (i32.lt_u (local.get $scrutinee) (global.get $heap_base))
  (then 
    ;; Nullary variant: the value itself is the tag ID.
    (local.set $tag (local.get $scrutinee))
  )
  (else 
    ;; Fielded variant: the value is a pointer. Tag is at offset 0.
    (local.set $tag (i32.load (local.get $scrutinee)))
  )
)

;; The macro expander injects the nested blocks and br_table here
;; based on the number of arms.
;;
;; Example expansion:
;; (block $match_end
;;   (block $arm1
;;     (block $arm0
;;       (br_table $arm0 $arm1 (local.get $tag))
;;     )
;;     ;; ... arm 0 logic ...
;;     (br $match_end)
;;   )
;;   ;; ... arm 1 logic ...
;; )
;; bootstrap/templates/handler_dispatch.wat
;; 
;; The Inka Handler Dispatch Template (No VTables)
;; Performs polymorphic dispatch via Koka-style evidence passing.
;; The closure record contains the function index at offset 4.

;; Example usage:
;; (local.set $closure)
;; ;; ... push args ...
;; ;; push closure as the last argument (the __state param)
;; (local.get $closure)
;; ;; load the function index
;; (i32.load offset=4 (local.get $closure))
;; (call_indirect (type $expected_sig))

;; The expander injects this pattern for every polymorphic `perform` or closure invocation.
;;
;; MACRO_TEMPLATE_START
(local.get $closure_ptr)
(i32.load offset=4 (local.get $closure_ptr))
(call_indirect (type $##SIG_INDEX##))
;; MACRO_TEMPLATE_END
;; bootstrap/templates/topology_pipes.wat
;; 
;; The Inka Topology Pipes Template
;; Defines the WAT structure for the 5 verbs: |> <| >< ~> <~
;;
;; Since verbs define topology, they compile down to block structures
;; and call chains.

;; MACRO_TEMPLATE_START(PIPE_FORWARD)
;; `a |> b` becomes a direct argument pass.
;; ... push a ...
(call $##B_FUNC##)
;; MACRO_TEMPLATE_END

;; MACRO_TEMPLATE_START(PIPE_FEEDBACK)
;; `a <~ b` becomes a looping state handler.
(block $feedback_exit
  (loop $feedback_loop
    ;; The ambient handler provides the back-edge value on the stack.
    ;; If the ambient handler halts, we break.
    ;; (br $feedback_exit)
    ;; Otherwise, we loop.
    ;; (br $feedback_loop)
  )
)
;; MACRO_TEMPLATE_END
;; bootstrap/templates/heap_alloc.wat
;; 
;; The Inka Heap Allocation Template
;; "The Heap Has One Story"
;; Used for all ADT variants, closures, records, and evidence records.

;; MACRO_TEMPLATE_START(HEAP_ALLOC)
;; Evaluates to a pointer to a newly allocated block of memory.
;; Expects no arguments.
;; Emits:
;; (local $ptr)
(local.set $ptr (call $alloc (i32.const ##SIZE##)))
;;
;; Then, the compiler will emit successive stores:
;; (i32.store (local.get $ptr) (local.get $field_0))
;; (i32.store offset=4 (local.get $ptr) (local.get $field_1))
;; ...
;; (local.get $ptr)
;; MACRO_TEMPLATE_END
