  ;; ═══ env.wat — env substrate (Tier 3) ═════════════════════════════
  ;; Implements: Hβ §1.2 — name-resolution substrate. Scope stack with
  ;;             $env_lookup walking inner-to-outer; $env_extend
  ;;             pushing to current scope; $env_scope_enter / exit
  ;;             managing the stack.
  ;; Exports:    $env_init,
  ;;             $env_lookup, $env_lookup_or, $env_contains,
  ;;             $env_extend,
  ;;             $env_scope_enter, $env_scope_exit,
  ;;             $env_scope_depth,
  ;;             $env_binding_make, $env_binding_name, $env_binding_handle
  ;; Uses:       $alloc (alloc.wat), $make_record/$record_get/$record_set
  ;;             (record.wat), $make_list/$list_index/$list_set/
  ;;             $list_extend_to/$len (list.wat),
  ;;             $str_eq (str.wat)
  ;; Test:       runtime_test/env.wat
  ;;
  ;; ═══ DESIGN ═══════════════════════════════════════════════════════
  ;; Per Hβ §1.2 + src/types.nx Env discipline:
  ;;
  ;; State lives in module-level globals — a stack of scope frames.
  ;; Each scope frame is a flat list of (name, handle) binding records.
  ;; $env_lookup walks the stack from innermost (top) to outermost
  ;; (bottom) and returns the first matching handle. $env_extend
  ;; pushes a new binding onto the topmost frame.
  ;;
  ;; The seed's HM inference (Hβ.infer — Wave 2.E) calls these
  ;; primitives during compilation to track let-bindings, function
  ;; parameters, type constructors, effect declarations. The COMPILED
  ;; output of src/types.nx + src/effects.nx + src/infer.nx (post-L1
  ;; wheel) builds its own effect-handler-shaped env_handler — same
  ;; algorithm, different storage mechanism.
  ;;
  ;; This implementation is the SEED's internal env. It does NOT yet
  ;; support per-module overlays (which compose with graph.wat's
  ;; overlay primitives — deferred per the graph.wat follow-up).
  ;; Single global scope stack is sufficient for self-compile of
  ;; current src/*.nx surface; cross-module env composition lands
  ;; alongside graph.wat overlays.
  ;;
  ;; ═══ HEAP RECORD LAYOUTS ═══════════════════════════════════════════
  ;;
  ;; Binding (name, handle):
  ;;   $make_record(ENV_BINDING_TAG=130, arity=2)
  ;;     offset 8:  field_0 = name (heap-allocated string ptr; str.wat layout)
  ;;     offset 12: field_1 = handle (i32 — graph handle)
  ;;
  ;; Scope frame: flat list of binding pointers.
  ;;
  ;; Tag allocation: env.wat private region 130-149 (avoids graph.wat
  ;; range 50-99 and TokenKind sentinels 0-44).
  ;;   130   ENV_BINDING_TAG  — (name, handle) binding
  ;;   131-149 reserved for future env-substrate records
  ;;
  ;; ═══ NOT-FOUND CONVENTION ═════════════════════════════════════════
  ;; $env_lookup returns 0 when the name is not bound (handle 0 is the
  ;; first fresh allocation if any; callers must distinguish via
  ;; $env_contains or $env_lookup_or which takes a sentinel default).
  ;; Per src/graph.nx overlay_find precedent (returns count = past-
  ;; valid-index sentinel); the seed's idiom is "lookup returns 0;
  ;; callers wrap with $env_contains for presence tests."
  ;;
  ;; Future Hβ.infer may want a richer return (e.g., (handle, scope_idx)
  ;; tuple) — that's a substrate extension under env.wat's follow-up.

  ;; ─── Module-level globals ─────────────────────────────────────────
  ;; $env_scopes_ptr — flat list of scope-frame pointers (each frame
  ;;                   itself a flat list of binding pointers).
  ;;                   Position 0 = outermost; position $env_scope_count_g - 1 = current.
  ;; $env_scope_count_g — logical depth of the scope stack.
  ;; $env_initialized — 1 once $env_init has run.

  (global $env_scopes_ptr      (mut i32) (i32.const 0))
  (global $env_scope_count_g   (mut i32) (i32.const 0))
  (global $env_initialized     (mut i32) (i32.const 0))

  ;; ─── Initialization ──────────────────────────────────────────────
  ;; $env_init: idempotent. Allocates initial scope-stack with one
  ;; outermost scope (for top-level / global bindings).
  (func $env_init
    (if (global.get $env_initialized) (then (return)))
    (global.set $env_scopes_ptr (call $make_list (i32.const 8)))
    (global.set $env_scope_count_g (i32.const 0))
    (global.set $env_initialized (i32.const 1))
    ;; Push the outermost (global) scope.
    (call $env_scope_enter))

  ;; ─── Binding constructors + accessors ────────────────────────────

  (func $env_binding_make (param $name i32) (param $handle i32) (result i32)
    (local $b i32)
    (local.set $b (call $make_record (i32.const 130) (i32.const 2)))
    (call $record_set (local.get $b) (i32.const 0) (local.get $name))
    (call $record_set (local.get $b) (i32.const 1) (local.get $handle))
    (local.get $b))

  (func $env_binding_name (param $b i32) (result i32)
    (call $record_get (local.get $b) (i32.const 0)))

  (func $env_binding_handle (param $b i32) (result i32)
    (call $record_get (local.get $b) (i32.const 1)))

  ;; ─── Scope management ────────────────────────────────────────────

  (func $env_scope_depth (result i32)
    (call $env_init)
    (global.get $env_scope_count_g))

  ;; $env_scope_enter — push a new empty scope frame onto the stack.
  ;; New scope is now the "current" scope; subsequent $env_extend
  ;; pushes to it.
  (func $env_scope_enter
    (local $count i32) (local $fresh_frame i32)
    (if (i32.eqz (global.get $env_initialized))
      (then
        ;; Bootstrap-init path during $env_init: don't recurse.
        (global.set $env_scopes_ptr (call $make_list (i32.const 8)))
        (global.set $env_scope_count_g (i32.const 0))
        (global.set $env_initialized (i32.const 1))))
    (local.set $count (global.get $env_scope_count_g))
    (local.set $fresh_frame (call $make_list (i32.const 4)))   ;; small initial; grows on demand
    (global.set $env_scopes_ptr
      (call $list_set
        (call $list_extend_to (global.get $env_scopes_ptr)
                              (i32.add (local.get $count) (i32.const 1)))
        (local.get $count)
        (local.get $fresh_frame)))
    (global.set $env_scope_count_g
      (i32.add (local.get $count) (i32.const 1))))

  ;; $env_scope_exit — pop the current scope frame.
  ;; No bound check at the WAT level — caller responsibility (matched
  ;; enter/exit per the substrate-honest discipline; mismatched calls
  ;; trap on subsequent operations via underflow).
  ;; If only one scope remains, this leaves the stack at depth 0 —
  ;; subsequent $env_lookup returns 0 (not-found) until $env_scope_enter
  ;; restores at least one scope.
  (func $env_scope_exit
    (call $env_init)
    (if (i32.gt_u (global.get $env_scope_count_g) (i32.const 0))
      (then
        (global.set $env_scope_count_g
          (i32.sub (global.get $env_scope_count_g) (i32.const 1))))))

  ;; ─── Extend (push binding to current scope) ──────────────────────
  ;; $env_extend(name, handle) — append (name, handle) binding to the
  ;; current (topmost) scope frame. No shadowing check at the WAT
  ;; level — Hβ.infer's lexical-scoping discipline handles shadowing
  ;; semantics; later bindings shadow earlier ones via $env_lookup's
  ;; reverse-walk semantics.
  (func $env_extend (param $name i32) (param $handle i32)
    (local $current_idx i32) (local $frame i32) (local $frame_len i32) (local $binding i32)
    (call $env_init)
    (if (i32.eqz (global.get $env_scope_count_g))
      (then (return)))   ;; no current scope — silent no-op (defensive)
    (local.set $current_idx
      (i32.sub (global.get $env_scope_count_g) (i32.const 1)))
    (local.set $frame (call $list_index (global.get $env_scopes_ptr)
                                        (local.get $current_idx)))
    (local.set $frame_len (call $len (local.get $frame)))
    (local.set $binding (call $env_binding_make (local.get $name) (local.get $handle)))
    ;; Append to frame: extend + set + replace in scopes list.
    (local.set $frame
      (call $list_set
        (call $list_extend_to (local.get $frame)
                              (i32.add (local.get $frame_len) (i32.const 1)))
        (local.get $frame_len)
        (local.get $binding)))
    (global.set $env_scopes_ptr
      (call $list_set (global.get $env_scopes_ptr)
                      (local.get $current_idx)
                      (local.get $frame))))

  ;; ─── Lookup ──────────────────────────────────────────────────────
  ;; $env_lookup(name) — walks scopes from innermost (top) to
  ;; outermost (bottom), and within each scope walks bindings from
  ;; last-pushed to first (so later bindings shadow earlier ones at
  ;; the same scope). Returns the matching handle on first hit, or 0
  ;; if not bound anywhere.
  (func $env_lookup (param $name i32) (result i32)
    (call $env_lookup_or (local.get $name) (i32.const 0)))

  ;; $env_lookup_or(name, default) — returns default when name is
  ;; not bound. Useful when 0 is a valid handle and the caller wants
  ;; a different sentinel.
  (func $env_lookup_or (param $name i32) (param $default i32) (result i32)
    (local $scope_idx i32) (local $frame i32)
    (local $binding_idx i32) (local $binding i32)
    (call $env_init)
    (local.set $scope_idx (global.get $env_scope_count_g))
    ;; Outer loop: scopes from current down to 0.
    (block $outer_done
      (loop $scope_loop
        (br_if $outer_done (i32.eqz (local.get $scope_idx)))
        (local.set $scope_idx (i32.sub (local.get $scope_idx) (i32.const 1)))
        (local.set $frame
          (call $list_index (global.get $env_scopes_ptr) (local.get $scope_idx)))
        ;; Inner loop: bindings within the frame from last to first.
        (local.set $binding_idx (call $len (local.get $frame)))
        (block $inner_done
          (loop $binding_loop
            (br_if $inner_done (i32.eqz (local.get $binding_idx)))
            (local.set $binding_idx (i32.sub (local.get $binding_idx) (i32.const 1)))
            (local.set $binding
              (call $list_index (local.get $frame) (local.get $binding_idx)))
            (if (call $str_eq (call $env_binding_name (local.get $binding))
                              (local.get $name))
              (then (return (call $env_binding_handle (local.get $binding)))))
            (br $binding_loop)))
        (br $scope_loop)))
    (local.get $default))

  ;; $env_contains(name) — presence test. Returns 1 if name is bound
  ;; in any scope, else 0. Cleaner than checking $env_lookup result
  ;; for handle == 0 when 0 might be a legitimate fresh-allocated
  ;; handle.
  (func $env_contains (param $name i32) (result i32)
    (local $scope_idx i32) (local $frame i32)
    (local $binding_idx i32) (local $binding i32)
    (call $env_init)
    (local.set $scope_idx (global.get $env_scope_count_g))
    (block $outer_done
      (loop $scope_loop
        (br_if $outer_done (i32.eqz (local.get $scope_idx)))
        (local.set $scope_idx (i32.sub (local.get $scope_idx) (i32.const 1)))
        (local.set $frame
          (call $list_index (global.get $env_scopes_ptr) (local.get $scope_idx)))
        (local.set $binding_idx (call $len (local.get $frame)))
        (block $inner_done
          (loop $binding_loop
            (br_if $inner_done (i32.eqz (local.get $binding_idx)))
            (local.set $binding_idx (i32.sub (local.get $binding_idx) (i32.const 1)))
            (local.set $binding
              (call $list_index (local.get $frame) (local.get $binding_idx)))
            (if (call $str_eq (call $env_binding_name (local.get $binding))
                              (local.get $name))
              (then (return (i32.const 1))))
            (br $binding_loop)))
        (br $scope_loop)))
    (i32.const 0))
