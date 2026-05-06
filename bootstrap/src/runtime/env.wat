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
  ;;             $env_binding_make,
  ;;             $env_binding_name, $env_binding_scheme,
  ;;             $env_binding_reason, $env_binding_kind,
  ;;             $schemekind_make_fn, $schemekind_make_ctor,
  ;;             $schemekind_make_effectop, $schemekind_make_record,
  ;;             $schemekind_make_capability,
  ;;             $schemekind_ctor_tag_id, $schemekind_ctor_total,
  ;;             $schemekind_effectop_name,
  ;;             $schemekind_record_fields,
  ;;             $schemekind_capability_pairs,
  ;;             $schemekind_tag, $schemekind_wire_byte
  ;; Uses:       $alloc (alloc.wat), $make_record/$record_get/$record_set/
  ;;             $tag_of (record.wat), $make_list/$list_index/$list_set/
  ;;             $list_extend_to/$len (list.wat),
  ;;             $str_eq (str.wat), $heap_base (Layer 0 shell)
  ;; Test:       runtime_test/env.wat
  ;;
  ;; ═══ DESIGN ═══════════════════════════════════════════════════════
  ;; Per Hβ §1.2 + src/types.mn Env discipline:
  ;;
  ;; State lives in module-level globals — a stack of scope frames.
  ;; Each scope frame is a flat list of 4-field binding records
  ;; (name, scheme, reason, kind) per the canonical Env entry shape
  ;; (src/types.mn:78-110 + src/cache.mn:145-183, 416-456). $env_lookup
  ;; walks the stack from innermost to outermost and returns the first
  ;; matching binding record (caller projects via the four accessors).
  ;; $env_extend pushes a new 4-tuple binding onto the topmost frame.
  ;;
  ;; The seed's HM inference (Hβ.infer — Wave 2.E) calls these
  ;; primitives during compilation to track let-bindings, function
  ;; parameters, type constructors, effect declarations. The COMPILED
  ;; output of src/types.mn + src/effects.mn + src/infer.mn (post-L1
  ;; wheel) builds its own effect-handler-shaped env_handler — same
  ;; algorithm, different storage mechanism.
  ;;
  ;; This implementation is the SEED's internal env. It does NOT yet
  ;; support per-module overlays (which compose with graph.wat's
  ;; overlay primitives — deferred per the graph.wat follow-up).
  ;; Single global scope stack is sufficient for self-compile of
  ;; current src/*.mn surface; cross-module env composition lands
  ;; alongside graph.wat overlays.
  ;;
  ;; ═══ HEAP RECORD LAYOUTS ═══════════════════════════════════════════
  ;;
  ;; Per src/types.mn (post-item-2: SchemeKind has 5 variants) +
  ;; src/cache.mn:145-183, 416-456 (canonical wire format) +
  ;; src/infer.mn:219, 233, 279, 368, 380-389, 600-614, 794, 861,
  ;; 1589-1591, 2009, 2051-2058, 2094-2097, 2104-2108 (call sites
  ;; that read the four-tuple). The env entry shape is canonical:
  ;;   Env entry = (name, Scheme, Reason, SchemeKind).
  ;;
  ;; Binding (4-field record):
  ;;   $make_record(ENV_BINDING_TAG=130, arity=4)
  ;;     offset  8: field_0 = name        (heap-allocated string ptr)
  ;;     offset 12: field_1 = scheme_ptr  (Scheme record from
  ;;                                       infer/scheme.wat — SCHEME_TAG=200)
  ;;     offset 16: field_2 = reason_ptr  (Reason record; tagged 220-242
  ;;                                       per infer/reason.wat)
  ;;     offset 20: field_3 = kind_ptr    (SchemeKind record; tagged
  ;;                                       131-135 per the SchemeKind block)
  ;;
  ;; Scope frame: flat list of binding pointers (unchanged shape).
  ;;
  ;; Tag allocation: env.wat private region 130-149.
  ;;   130   ENV_BINDING_TAG               — 4-field binding
  ;;   131   SCHEMEKIND_FN_TAG             — FnScheme (nullary sentinel)
  ;;   132   SCHEMEKIND_CTOR_TAG           — ConstructorScheme(tag_id, total)
  ;;   133   SCHEMEKIND_EFFECTOP_TAG       — EffectOpScheme(name)
  ;;   134   SCHEMEKIND_RECORD_TAG         — RecordSchemeKind(fields)
  ;;   135   SCHEMEKIND_CAPABILITY_TAG     — CapabilityScheme(eff_pairs)
  ;;   136-149 reserved for future env-substrate records
  ;;
  ;; SchemeKind tag-byte invariant: runtime_tag - 131 == cache_wire_byte.
  ;;   FnScheme              → byte 0  (cache.mn:165)
  ;;   ConstructorScheme     → byte 1  (cache.mn:166-170)
  ;;   EffectOpScheme        → byte 2  (cache.mn:171-174)
  ;;   RecordSchemeKind      → byte 3  (cache.mn:175-179)
  ;;   CapabilityScheme      → byte 4  (cache.mn:180-184)
  ;; Drift-mode-8 closed by ADT dispatch on the runtime tag — NEVER
  ;; by `mode == 0/1/2/3/4` int.
  ;;
  ;; ═══ NOT-FOUND CONVENTION ═════════════════════════════════════════
  ;; $env_lookup returns 0 (null) when name not bound. Bound bindings
  ;; are >= HEAP_BASE (4096); collision-free. Returned pointer (when
  ;; found) IS the binding record; callers project via the four
  ;; $env_binding_* accessors.

  ;; ─── Module-level globals ─────────────────────────────────────────
  ;; $env_scopes_ptr — flat list of scope-frame pointers (each frame
  ;;                   itself a flat list of binding pointers).
  ;;                   Position 0 = outermost; position $env_scope_count_g - 1 = current.
  ;; $env_scope_count_g — logical depth of the scope stack.
  ;; $env_initialized — 1 once $env_init has run.

  (global $env_scopes_ptr      (mut i32) (i32.const 0))
  (global $env_scope_count_g   (mut i32) (i32.const 0))
  (global $env_initialized     (mut i32) (i32.const 0))

  ;; ─── Frame discipline (substrate-honest buffer-counter pattern) ─
  ;; Each scope-frame is a 2-element record (tag=137):
  ;;   field 0 = buf      (List of bindings; count field treated as cap)
  ;;   field 1 = len      (logical count of bindings — i32 sentinel)
  ;;
  ;; Per CLAUDE.md feedback_antidrift Ω.3 buffer-counter substrate:
  ;; the underlying list maintains capacity (via list_extend_to's
  ;; doubling); the SEPARATE len field is the source of truth for
  ;; logical length. env_extend uses len (not $len(buf)) to compute
  ;; the next slot. The bug class "list_extend_to count-vs-capacity
  ;; conflation" cannot fire because env never reads $len(buf) for
  ;; logical-length purposes.
  ;;
  ;; Why a record (not a pair): records have a stable shape under
  ;; future schema evolution (e.g., adding a frame-id, lifetime tag,
  ;; or arena pointer per Hβ.arena handler-swap-promotion). Tag 137
  ;; is the next free slot in env's tag space ([130, 140) ENV).

  (func $env_frame_make (param $buf i32) (param $len i32) (result i32)
    (local $r i32)
    (local.set $r (call $make_record (i32.const 137) (i32.const 2)))
    (call $record_set (local.get $r) (i32.const 0) (local.get $buf))
    (call $record_set (local.get $r) (i32.const 1) (local.get $len))
    (local.get $r))

  (func $env_frame_buf (param $f i32) (result i32)
    (call $record_get (local.get $f) (i32.const 0)))

  (func $env_frame_len (param $f i32) (result i32)
    (call $record_get (local.get $f) (i32.const 1)))

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

  ;; ─── SchemeKind constructors + accessors ─────────────────────────
  ;; Five canonical variants per src/types.mn:105-110 + cache.mn:162-184.

  ;; FnScheme — nullary; sentinel-encoded as the tag itself (no record).
  (func $schemekind_make_fn (result i32)
    (i32.const 131))

  ;; ConstructorScheme(tag_id: Int, total: Int)
  (func $schemekind_make_ctor (param $tag_id i32) (param $total i32) (result i32)
    (local $r i32)
    (local.set $r (call $make_record (i32.const 132) (i32.const 2)))
    (call $record_set (local.get $r) (i32.const 0) (local.get $tag_id))
    (call $record_set (local.get $r) (i32.const 1) (local.get $total))
    (local.get $r))

  (func $schemekind_ctor_tag_id (param $k i32) (result i32)
    (call $record_get (local.get $k) (i32.const 0)))

  (func $schemekind_ctor_total (param $k i32) (result i32)
    (call $record_get (local.get $k) (i32.const 1)))

  ;; EffectOpScheme(effect_name: String)
  (func $schemekind_make_effectop (param $effect_name i32) (result i32)
    (local $r i32)
    (local.set $r (call $make_record (i32.const 133) (i32.const 1)))
    (call $record_set (local.get $r) (i32.const 0) (local.get $effect_name))
    (local.get $r))

  (func $schemekind_effectop_name (param $k i32) (result i32)
    (call $record_get (local.get $k) (i32.const 0)))

  ;; RecordSchemeKind(fields: List of (name, ty) pairs)
  (func $schemekind_make_record (param $fields i32) (result i32)
    (local $r i32)
    (local.set $r (call $make_record (i32.const 134) (i32.const 1)))
    (call $record_set (local.get $r) (i32.const 0) (local.get $fields))
    (local.get $r))

  (func $schemekind_record_fields (param $k i32) (result i32)
    (call $record_get (local.get $k) (i32.const 0)))

  ;; CapabilityScheme(eff_pairs: List of (EffName, Bool) pairs)
  (func $schemekind_make_capability (param $eff_pairs i32) (result i32)
    (local $r i32)
    (local.set $r (call $make_record (i32.const 135) (i32.const 1)))
    (call $record_set (local.get $r) (i32.const 0) (local.get $eff_pairs))
    (local.get $r))

  (func $schemekind_capability_pairs (param $k i32) (result i32)
    (call $record_get (local.get $k) (i32.const 0)))

  ;; SchemeKind tag dispatch — sentinel-collapse for FnScheme.
  (func $schemekind_tag (param $k i32) (result i32)
    (if (i32.lt_u (local.get $k) (global.get $heap_base))
      (then (return (local.get $k))))
    (call $tag_of (local.get $k)))

  ;; SchemeKind wire-byte projection — round-trip with cache.mn pack_byte.
  (func $schemekind_wire_byte (param $k i32) (result i32)
    (i32.sub (call $schemekind_tag (local.get $k)) (i32.const 131)))

  ;; ─── Binding constructors + accessors ────────────────────────────
  ;; 4-field record: (name, scheme, reason, kind). Tag 130.

  (func $env_binding_make
        (param $name i32) (param $scheme i32)
        (param $reason i32) (param $kind i32)
        (result i32)
    (local $b i32)
    (local.set $b (call $make_record (i32.const 130) (i32.const 4)))
    (call $record_set (local.get $b) (i32.const 0) (local.get $name))
    (call $record_set (local.get $b) (i32.const 1) (local.get $scheme))
    (call $record_set (local.get $b) (i32.const 2) (local.get $reason))
    (call $record_set (local.get $b) (i32.const 3) (local.get $kind))
    (local.get $b))

  (func $env_binding_name (param $b i32) (result i32)
    (call $record_get (local.get $b) (i32.const 0)))

  (func $env_binding_scheme (param $b i32) (result i32)
    (call $record_get (local.get $b) (i32.const 1)))

  (func $env_binding_reason (param $b i32) (result i32)
    (call $record_get (local.get $b) (i32.const 2)))

  (func $env_binding_kind (param $b i32) (result i32)
    (call $record_get (local.get $b) (i32.const 3)))

  ;; ─── Scope management ────────────────────────────────────────────

  (func $env_scope_depth (result i32)
    (call $env_init)
    (global.get $env_scope_count_g))

  ;; $env_scope_enter — push a new empty scope frame onto the stack.
  ;; New scope is now the "current" scope; subsequent $env_extend
  ;; pushes to it.
  ;;
  ;; The fresh frame is an $env_frame_make wrapping an empty buf
  ;; (logical len = 0; underlying list cap = 4 for initial growth).
  ;; env_extend grows the buf via list_extend_to and updates the
  ;; frame's len field — the count-vs-capacity conflation in
  ;; list.wat does NOT propagate because env_extend never reads
  ;; $len(buf) for logical-length purposes.
  (func $env_scope_enter
    (local $count i32) (local $fresh_buf i32) (local $fresh_frame i32)
    (if (i32.eqz (global.get $env_initialized))
      (then
        ;; Bootstrap-init path during $env_init: don't recurse.
        (global.set $env_scopes_ptr (call $make_list (i32.const 8)))
        (global.set $env_scope_count_g (i32.const 0))
        (global.set $env_initialized (i32.const 1))))
    (local.set $count (global.get $env_scope_count_g))
    (local.set $fresh_buf (call $make_list (i32.const 4)))
    (local.set $fresh_frame (call $env_frame_make
      (local.get $fresh_buf) (i32.const 0)))
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
  ;; $env_extend(name, scheme, reason, kind) — append a 4-field
  ;; binding to the current (topmost) scope frame. Mirrors canonical
  ;; src/infer.mn perform env_extend at lines 219, 233, 251, 279, 368,
  ;; 1589-1591, 2009, 2051, 2057, 2061, 2094, 2105.
  ;;
  ;; Substrate-honest discipline (Anchor 0 + Ω.3 buffer-counter): the
  ;; current frame's logical length lives in $env_frame_len, NOT
  ;; $len(buf). list_extend_to grows capacity; env_extend builds a
  ;; new $env_frame_make wrapping the grown buf + (old_len + 1).
  (func $env_extend
        (param $name i32) (param $scheme i32)
        (param $reason i32) (param $kind i32)
    (local $current_idx i32) (local $frame i32)
    (local $buf i32) (local $frame_len i32)
    (local $binding i32) (local $new_buf i32) (local $new_frame i32)
    (call $env_init)
    (if (i32.eqz (global.get $env_scope_count_g))
      (then (return)))
    (local.set $current_idx
      (i32.sub (global.get $env_scope_count_g) (i32.const 1)))
    (local.set $frame (call $list_index (global.get $env_scopes_ptr)
                                        (local.get $current_idx)))
    (local.set $buf (call $env_frame_buf (local.get $frame)))
    (local.set $frame_len (call $env_frame_len (local.get $frame)))
    (local.set $binding
      (call $env_binding_make
        (local.get $name) (local.get $scheme)
        (local.get $reason) (local.get $kind)))
    (local.set $new_buf
      (call $list_set
        (call $list_extend_to (local.get $buf)
                              (i32.add (local.get $frame_len) (i32.const 1)))
        (local.get $frame_len)
        (local.get $binding)))
    (local.set $new_frame
      (call $env_frame_make
        (local.get $new_buf)
        (i32.add (local.get $frame_len) (i32.const 1))))
    (global.set $env_scopes_ptr
      (call $list_set (global.get $env_scopes_ptr)
                      (local.get $current_idx)
                      (local.get $new_frame))))

  ;; ─── Lookup ──────────────────────────────────────────────────────
  ;; $env_lookup(name) — returns matching BINDING RECORD (4-field
  ;; (name, scheme, reason, kind) per ENV_BINDING_TAG=130) on first
  ;; hit, or 0 if not bound. Callers project via $env_binding_scheme
  ;; / $env_binding_reason / $env_binding_kind.
  (func $env_lookup (param $name i32) (result i32)
    (call $env_lookup_or (local.get $name) (i32.const 0)))

  (func $env_lookup_or (param $name i32) (param $default i32) (result i32)
    (local $scope_idx i32) (local $frame i32) (local $buf i32)
    (local $binding_idx i32) (local $binding i32)
    (call $env_init)
    (local.set $scope_idx (global.get $env_scope_count_g))
    (block $outer_done
      (loop $scope_loop
        (br_if $outer_done (i32.eqz (local.get $scope_idx)))
        (local.set $scope_idx (i32.sub (local.get $scope_idx) (i32.const 1)))
        (local.set $frame
          (call $list_index (global.get $env_scopes_ptr) (local.get $scope_idx)))
        (local.set $buf (call $env_frame_buf (local.get $frame)))
        (local.set $binding_idx (call $env_frame_len (local.get $frame)))
        (block $inner_done
          (loop $binding_loop
            (br_if $inner_done (i32.eqz (local.get $binding_idx)))
            (local.set $binding_idx (i32.sub (local.get $binding_idx) (i32.const 1)))
            (local.set $binding
              (call $list_index (local.get $buf) (local.get $binding_idx)))
            (if (call $str_eq (call $env_binding_name (local.get $binding))
                              (local.get $name))
              (then (return (local.get $binding))))
            (br $binding_loop)))
        (br $scope_loop)))
    (local.get $default))

  ;; $env_contains(name) — presence test. Returns 1 if name is bound
  ;; in any scope, else 0. Cleaner than checking $env_lookup result
  ;; for handle == 0 when 0 might be a legitimate fresh-allocated
  ;; handle.
  (func $env_contains (param $name i32) (result i32)
    (local $scope_idx i32) (local $frame i32) (local $buf i32)
    (local $binding_idx i32) (local $binding i32)
    (call $env_init)
    (local.set $scope_idx (global.get $env_scope_count_g))
    (block $outer_done
      (loop $scope_loop
        (br_if $outer_done (i32.eqz (local.get $scope_idx)))
        (local.set $scope_idx (i32.sub (local.get $scope_idx) (i32.const 1)))
        (local.set $frame
          (call $list_index (global.get $env_scopes_ptr) (local.get $scope_idx)))
        (local.set $buf (call $env_frame_buf (local.get $frame)))
        (local.set $binding_idx (call $env_frame_len (local.get $frame)))
        (block $inner_done
          (loop $binding_loop
            (br_if $inner_done (i32.eqz (local.get $binding_idx)))
            (local.set $binding_idx (i32.sub (local.get $binding_idx) (i32.const 1)))
            (local.set $binding
              (call $list_index (local.get $buf) (local.get $binding_idx)))
            (if (call $str_eq (call $env_binding_name (local.get $binding))
                              (local.get $name))
              (then (return (i32.const 1))))
            (br $binding_loop)))
        (br $scope_loop)))
    (i32.const 0))
