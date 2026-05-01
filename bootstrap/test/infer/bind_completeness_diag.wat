  ;; ═══ bind_completeness_diag.wat — Phase C diagnostic harness ═══════════
  ;; Diagnostic harness for Hβ.infer.bind-completeness (Plan A.2).
  ;; Asserts that the 9 canonical binding shapes do not produce any
  ;; E_MissingVariable (NErrorHole) resolutions in the inference graph.

  (data (i32.const 5120) "\12\00\00\00{ let n = 5; n + 1 }")
  (data (i32.const 5152) "\1b\00\00\00{ let n = 5; let m = n; m }")
  (data (i32.const 5200) "\26\00\00\00fn f(name) = { let path = name; path }")
  (data (i32.const 5248) "\23\00\00\00match 1 { Some(v) => v, None => 0 }")
  (data (i32.const 5296) "\21\00\00\00(x) => { let merged = x; merged }")
  
  (data (i32.const 5344) "\20\00\00\00type T = A | B(int); fn k(x) = A")
  (data (i32.const 5392) "\27\00\00\00type T = A; fn k() = A; type U = B(int)")
  (data (i32.const 5440) "\25\00\00\00fn k() = MyType; type MyType = MyType")
  (data (i32.const 5488) "\18\00\00\00fn a() = b(); fn b() = 0")

  (data (i32.const 3072) "\05\00\00\00PASS:")
  (data (i32.const 3084) "\05\00\00\00FAIL:")
  (data (i32.const 3096) "\01\00\00\00 ")
  (data (i32.const 3104) "\01\00\00\00\0a")
  (data (i32.const 3120) "\16\00\00\00bind_completeness_diag")
  (data (i32.const 3152) "\10\00\00\00errorhole-found\0a")

  (func $run_shape (param $source i32)
    (local $lex_result i32)
    (local $tokens i32)
    (local $stmts i32)
    
    ;; Reset compilation state for each shape
    (call $graph_init)
    (call $env_init)
    (call $infer_init)

    (local.set $lex_result (call $lex (local.get $source)))
    (local.set $tokens (call $list_index (local.get $lex_result) (i32.const 0)))
    (local.set $stmts (call $parse_program (local.get $tokens)))
    
    (call $inka_infer (local.get $stmts)))

  (func $check_errors (result i32)
    (local $i i32) (local $n i32) (local $g i32) (local $nk i32)
    (local.set $i (i32.const 1))
    (local.set $n (call $graph_next_handle))
    (block $done (loop $loop
      (br_if $done (i32.ge_u (local.get $i) (local.get $n)))
      (local.set $g (call $graph_node_at (local.get $i)))
      (local.set $nk (call $gnode_kind (local.get $g)))
      (if (i32.eq (call $node_kind_tag (local.get $nk)) (i32.const 64))
        (then (return (i32.const 1))))
      (local.set $i (i32.add (local.get $i) (i32.const 1)))
      (br $loop)))
    (i32.const 0))

  (func $_start (export "_start")
    (local $failed i32)
    (local.set $failed (i32.const 0))
    
    (call $run_shape (i32.const 5120))
    (local.set $failed (i32.or (local.get $failed) (call $check_errors)))
    (call $run_shape (i32.const 5152))
    (local.set $failed (i32.or (local.get $failed) (call $check_errors)))
    (call $run_shape (i32.const 5200))
    (local.set $failed (i32.or (local.get $failed) (call $check_errors)))
    (call $run_shape (i32.const 5248))
    (local.set $failed (i32.or (local.get $failed) (call $check_errors)))
    (call $run_shape (i32.const 5296))
    (local.set $failed (i32.or (local.get $failed) (call $check_errors)))
    (call $run_shape (i32.const 5344))
    (local.set $failed (i32.or (local.get $failed) (call $check_errors)))
    (call $run_shape (i32.const 5392))
    (local.set $failed (i32.or (local.get $failed) (call $check_errors)))
    (call $run_shape (i32.const 5440))
    (local.set $failed (i32.or (local.get $failed) (call $check_errors)))
    (call $run_shape (i32.const 5488))
    (local.set $failed (i32.or (local.get $failed) (call $check_errors)))

    (if (local.get $failed)
      (then
        (call $eprint_string (i32.const 3084))
        (call $eprint_string (i32.const 3096))
        (call $eprint_string (i32.const 3120))
        (call $eprint_string (i32.const 3104))
        (call $eprint_string (i32.const 3152))
        (call $wasi_proc_exit (i32.const 1)))
      (else
        (call $eprint_string (i32.const 3072))
        (call $eprint_string (i32.const 3096))
        (call $eprint_string (i32.const 3120))
        (call $eprint_string (i32.const 3104))
        (call $wasi_proc_exit (i32.const 0)))))
