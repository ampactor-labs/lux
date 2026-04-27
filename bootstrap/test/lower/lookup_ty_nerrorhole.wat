  ;; ═══ lookup_ty_nerrorhole.wat — Hβ.lower trace-harness ═════════════
  ;; Executes: Hβ-lower-substrate.md §1.1 NErrorHole arm + §11 ownership
  ;;           lock — $lookup_ty returns $ty_make_terror_hole sentinel
  ;;           (tag 114) for handles bound to NErrorHole NodeKind.
  ;; Exercises: lookup.wat — $lookup_ty + $ty_make_terror_hole.
  ;; Per Hβ-lower-substrate.md §10.1 + §10.4 acceptance.
  ;;
  ;; Eight interrogations:
  ;;   Graph?      $graph_bind_kind binds an NErrorHole NodeKind directly
  ;;               (graph.wat:393-407 substrate; reason ptr 0).
  ;;   Handler?    Direct call to $lookup_ty.
  ;;   Verb?       N/A.
  ;;   Row?        Pure.
  ;;   Ownership?  Returned terror-hole is a nullary sentinel value
  ;;               (no ownership transfer).
  ;;   Refinement? None.
  ;;   Gradient?   This harness proves the productive-under-error bridge:
  ;;               lookup chases NErrorHole → returns tag 114; emit
  ;;               (chunk #4) routes to (unreachable) downstream.
  ;;   Reason?     $node_kind_make_nerrorhole carries reason ptr 0
  ;;               (sentinel "no reason recorded"); harness asserts only
  ;;               on tag 114.

  (data (i32.const 3072) "\05\00\00\00PASS:")
  (data (i32.const 3084) "\05\00\00\00FAIL:")
  (data (i32.const 3096) "\01\00\00\00 ")
  (data (i32.const 3104) "\01\00\00\00\0a")
  (data (i32.const 3120) "\18\00\00\00lower_lookup_nerrorhole ")
  (data (i32.const 3152) "\1a\00\00\00lookup-not-terror-hole-114")

  (func $_start (export "_start")
    (local $failed i32)
    (local $h i32) (local $errk i32) (local $looked i32)
    (local.set $failed (i32.const 0))
    (call $graph_init)

    ;; Phase 1: mint a fresh handle, then bind NErrorHole(reason=0).
    (local.set $h (call $graph_fresh_ty (i32.const 0)))
    (local.set $errk (call $node_kind_make_nerrorhole (i32.const 0)))
    (call $graph_bind_kind (local.get $h) (local.get $errk) (i32.const 0))

    ;; Phase 2: $lookup_ty(h) returns tag-114 sentinel.
    (local.set $looked (call $lookup_ty (local.get $h)))
    (if (i32.ne (local.get $looked) (i32.const 114))
      (then
        (call $eprint_string (i32.const 3152))
        (call $eprint_string (i32.const 3104))
        (local.set $failed (i32.const 1))))

    ;; Verdict.
    (if (local.get $failed)
      (then
        (call $eprint_string (i32.const 3084))
        (call $eprint_string (i32.const 3096))
        (call $eprint_string (i32.const 3120))
        (call $eprint_string (i32.const 3104))
        (call $wasi_proc_exit (i32.const 1)))
      (else
        (call $eprint_string (i32.const 3072))
        (call $eprint_string (i32.const 3096))
        (call $eprint_string (i32.const 3120))
        (call $eprint_string (i32.const 3104))
        (call $wasi_proc_exit (i32.const 0)))))
