  ;; ═══ lexer_data.wat — keyword + output data segments (Layer 2) ════
  ;; Implements: lexer keyword string constants at fixed memory
  ;;             addresses [256, 512) + output format strings at
  ;;             [512, 4096). Read by lexer.wat's identifier-vs-
  ;;             keyword classifier + by the entry point's stdout
  ;;             reporting helpers.
  ;; Exports:    (data segments — addressed via $str_from_mem in int.wat)
  ;; Uses:       (memory.data only — no function dependencies)
  ;; Test:       runtime_test/lexer_data.wat (asserts string content
  ;;             at known addresses)
  ;;
  ;; Each entry: 4-byte little-endian length prefix + raw bytes.
  ;; Addresses chosen to fit within the [256, 4096) data region (the
  ;; HEAP_BASE-bounded sentinel space below the heap floor at 1 MiB).
  ;; Per CLAUDE.md memory model: HEAP_BASE = 4096; sentinel region
  ;; [0, 4096) holds (a) nullary ADT variant tags + (b) data-segment
  ;; constants like these.
  ;;
  ;; Wave 2.A factoring: these segments lived inline in mentl.wat's
  ;; Layer 0+1 shell because the build.sh "extract shell" pattern
  ;; treated everything before ";; ─── TokenKind Sentinel IDs" as
  ;; shell. They are SEMANTICALLY lexer data — moved here as the
  ;; lexer's first chunk so build.sh assembles them before lexer.wat.

  ;; ─── Keyword strings for the lexer — [256, 512) ───────────────────
  ;; "fn" at 256
  (data (i32.const 256) "\02\00\00\00fn")
  ;; "let" at 262
  (data (i32.const 262) "\03\00\00\00let")
  ;; "if" at 269
  (data (i32.const 269) "\02\00\00\00if")
  ;; "else" at 275
  (data (i32.const 275) "\04\00\00\00else")
  ;; "match" at 283
  (data (i32.const 283) "\05\00\00\00match")
  ;; "type" at 292
  (data (i32.const 292) "\04\00\00\00type")
  ;; "effect" at 300
  (data (i32.const 300) "\06\00\00\00effect")
  ;; "handle" at 310
  (data (i32.const 310) "\06\00\00\00handle")
  ;; "handler" at 320
  (data (i32.const 320) "\07\00\00\00handler")
  ;; "with" at 331
  (data (i32.const 331) "\04\00\00\00with")
  ;; "resume" at 339
  (data (i32.const 339) "\06\00\00\00resume")
  ;; "perform" at 349
  (data (i32.const 349) "\07\00\00\00perform")
  ;; "for" at 360 (display only; not a keyword per SYNTAX.md)
  (data (i32.const 360) "\03\00\00\00for")
  ;; "in" at 367 (display only; not a keyword per SYNTAX.md)
  (data (i32.const 367) "\02\00\00\00in")
  ;; "loop" at 373 (display only; not a keyword per SYNTAX.md)
  (data (i32.const 373) "\04\00\00\00loop")
  ;; "break" at 381 (display only; not a keyword per SYNTAX.md)
  (data (i32.const 381) "\05\00\00\00break")
  ;; "continue" at 390 (display only; not a keyword per SYNTAX.md)
  (data (i32.const 390) "\08\00\00\00continue")
  ;; "return" at 402 (display only; not a keyword per SYNTAX.md)
  (data (i32.const 402) "\06\00\00\00return")
  ;; "import" at 412
  (data (i32.const 412) "\06\00\00\00import")
  ;; "where" at 422
  (data (i32.const 422) "\05\00\00\00where")
  ;; "own" at 431
  (data (i32.const 431) "\03\00\00\00own")
  ;; "ref" at 438
  (data (i32.const 438) "\03\00\00\00ref")
  ;; "capability" at 445 (display only; not a TokenKind in SYNTAX.md)
  (data (i32.const 445) "\0a\00\00\00capability")
  ;; "Pure" at 459
  (data (i32.const 459) "\04\00\00\00Pure")
  ;; "true" at 467
  (data (i32.const 467) "\04\00\00\00true")
  ;; "false" at 475
  (data (i32.const 475) "\05\00\00\00false")

  ;; ─── Output format strings — [512, 4096) ──────────────────────────
  ;; " tokens, " at 512 (9 bytes)
  (data (i32.const 512) " tokens, ")
  ;; " stmts" at 528 (6 bytes)
  (data (i32.const 528) " stmts")
