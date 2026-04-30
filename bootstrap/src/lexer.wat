  ;; ─── TokenKind Sentinel IDs ──────────────────────────────────────
  ;; Nullary variants are sentinels (value IS the tag, no allocation).
  ;; Fielded variants (TIdent, TInt, TFloat, TString, TDocComment)
  ;; are heap-allocated: [tag:i32][payload:i32].
  ;;
  ;; Keywords (0-24):
  ;;   TFn=0 TLet=1 TIf=2 TElse=3 TMatch=4 TType=5
  ;;   TEffect=6 THandle=7 THandler=8 TWith=9
  ;;   TResume=10 TPerform=11
  ;;   TFor=12 TIn=13 TLoop=14 TBreak=15 TContinue=16 TReturn=17
  ;;   TImport=18 TWhere=19
  ;;   TOwn=20 TRef=21 TPure=22
  ;;   TTrue=23 TFalse=24
  ;; Fielded (25-29): TIdent=25 TInt=26 TFloat=27 TString=28 TDocComment=29
  ;; Two-char ops (30-44):
  ;;   TEqEq=30 TBangEq=31 TLtEq=32 TGtEq=33
  ;;   TArrow=34 TFatArrow=35 TPlusPlus=36
  ;;   TPipeGt=37 TLtPipe=38 TGtLt=39 TTildeGt=40 TLtTilde=41
  ;;   TAndAnd=42 TOrOr=43 TColonColon=44
  ;; Single-char (45-67):
  ;;   TLParen=45 TRParen=46 TLBrace=47 TRBrace=48
  ;;   TLBracket=49 TRBracket=50
  ;;   TComma=51 TDot=52 TColon=53 TSemicolon=54
  ;;   TPlus=55 TMinus=56 TStar=57 TSlash=58 TPercent=59
  ;;   TEq=60 TLt=61 TGt=62 TBang=63
  ;;   TPipe=64 TTilde=65 TAt=66 TQuestion=67
  ;; Layout (68-69): TNewline=68 TEof=69
  ;; Option: None=70 Some=71 (fielded)

  ;; ─── ADT Constructors ─────────────────────────────────────────────

  ;; Span(sl, sc, el, ec) → heap [tag=0][sl][sc][el][ec]
  (func $mk_span (param $sl i32) (param $sc i32) (param $el i32) (param $ec i32) (result i32)
    (local $ptr i32)
    (local.set $ptr (call $alloc (i32.const 20)))
    (i32.store (local.get $ptr) (i32.const 0))
    (i32.store offset=4 (local.get $ptr) (local.get $sl))
    (i32.store offset=8 (local.get $ptr) (local.get $sc))
    (i32.store offset=12 (local.get $ptr) (local.get $el))
    (i32.store offset=16 (local.get $ptr) (local.get $ec))
    (local.get $ptr))

  ;; Tok(kind, span) → heap [tag=0][kind][span_ptr]
  (func $mk_tok (param $kind i32) (param $sl i32) (param $sc i32) (param $el i32) (param $ec i32) (result i32)
    (local $ptr i32) (local $span i32)
    (local.set $span (call $mk_span (local.get $sl) (local.get $sc) (local.get $el) (local.get $ec)))
    (local.set $ptr (call $alloc (i32.const 12)))
    (i32.store (local.get $ptr) (i32.const 0))
    (i32.store offset=4 (local.get $ptr) (local.get $kind))
    (i32.store offset=8 (local.get $ptr) (local.get $span))
    (local.get $ptr))

  ;; Fielded TokenKind: TIdent(str) → [tag=25][str_ptr]
  (func $mk_TIdent (param $s i32) (result i32)
    (local $ptr i32)
    (local.set $ptr (call $alloc (i32.const 8)))
    (i32.store (local.get $ptr) (i32.const 25))
    (i32.store offset=4 (local.get $ptr) (local.get $s))
    (local.get $ptr))

  ;; TInt(n) → [tag=26][n]
  (func $mk_TInt (param $n i32) (result i32)
    (local $ptr i32)
    (local.set $ptr (call $alloc (i32.const 8)))
    (i32.store (local.get $ptr) (i32.const 26))
    (i32.store offset=4 (local.get $ptr) (local.get $n))
    (local.get $ptr))

  ;; TString(s) → [tag=28][str_ptr]
  (func $mk_TString (param $s i32) (result i32)
    (local $ptr i32)
    (local.set $ptr (call $alloc (i32.const 8)))
    (i32.store (local.get $ptr) (i32.const 28))
    (i32.store offset=4 (local.get $ptr) (local.get $s))
    (local.get $ptr))

  ;; TDocComment(s) → [tag=29][str_ptr]
  (func $mk_TDocComment (param $s i32) (result i32)
    (local $ptr i32)
    (local.set $ptr (call $alloc (i32.const 8)))
    (i32.store (local.get $ptr) (i32.const 29))
    (i32.store offset=4 (local.get $ptr) (local.get $s))
    (local.get $ptr))

  ;; Some(val) → [tag=71][val]
  (func $mk_Some (param $val i32) (result i32)
    (local $ptr i32)
    (local.set $ptr (call $alloc (i32.const 8)))
    (i32.store (local.get $ptr) (i32.const 71))
    (i32.store offset=4 (local.get $ptr) (local.get $val))
    (local.get $ptr))

  ;; ─── Character Classification ─────────────────────────────────────

  (func $is_digit (param $b i32) (result i32)
    (i32.and
      (i32.ge_u (local.get $b) (i32.const 48))
      (i32.le_u (local.get $b) (i32.const 57))))

  (func $is_alpha (param $b i32) (result i32)
    (i32.or
      (i32.or
        (i32.and (i32.ge_u (local.get $b) (i32.const 65))
                 (i32.le_u (local.get $b) (i32.const 90)))
        (i32.and (i32.ge_u (local.get $b) (i32.const 97))
                 (i32.le_u (local.get $b) (i32.const 122))))
      (i32.eq (local.get $b) (i32.const 95))))

  (func $is_alnum (param $b i32) (result i32)
    (i32.or (call $is_alpha (local.get $b))
            (call $is_digit (local.get $b))))

  (func $is_whitespace (param $b i32) (result i32)
    (i32.or
      (i32.or
        (i32.eq (local.get $b) (i32.const 32))
        (i32.eq (local.get $b) (i32.const 9)))
      (i32.eq (local.get $b) (i32.const 13))))

  ;; ─── Keyword Classification ───────────────────────────────────────
  ;; Returns sentinel 70 (None) or Some(TokenKind sentinel).
  ;; Uses pre-laid data segment strings for comparison.

  (func $keyword_kind (param $word i32) (result i32)
    (if (call $str_eq (local.get $word) (i32.const 256))    ;; "fn"
      (then (return (call $mk_Some (i32.const 0)))))
    (if (call $str_eq (local.get $word) (i32.const 262))    ;; "let"
      (then (return (call $mk_Some (i32.const 1)))))
    (if (call $str_eq (local.get $word) (i32.const 269))    ;; "if"
      (then (return (call $mk_Some (i32.const 2)))))
    (if (call $str_eq (local.get $word) (i32.const 275))    ;; "else"
      (then (return (call $mk_Some (i32.const 3)))))
    (if (call $str_eq (local.get $word) (i32.const 283))    ;; "match"
      (then (return (call $mk_Some (i32.const 4)))))
    (if (call $str_eq (local.get $word) (i32.const 292))    ;; "type"
      (then (return (call $mk_Some (i32.const 5)))))
    (if (call $str_eq (local.get $word) (i32.const 300))    ;; "effect"
      (then (return (call $mk_Some (i32.const 6)))))
    (if (call $str_eq (local.get $word) (i32.const 310))    ;; "handle"
      (then (return (call $mk_Some (i32.const 7)))))
    (if (call $str_eq (local.get $word) (i32.const 320))    ;; "handler"
      (then (return (call $mk_Some (i32.const 8)))))
    (if (call $str_eq (local.get $word) (i32.const 331))    ;; "with"
      (then (return (call $mk_Some (i32.const 9)))))
    (if (call $str_eq (local.get $word) (i32.const 339))    ;; "resume"
      (then (return (call $mk_Some (i32.const 10)))))
    (if (call $str_eq (local.get $word) (i32.const 349))    ;; "perform"
      (then (return (call $mk_Some (i32.const 11)))))
    (if (call $str_eq (local.get $word) (i32.const 360))    ;; "for"
      (then (return (call $mk_Some (i32.const 12)))))
    (if (call $str_eq (local.get $word) (i32.const 367))    ;; "in"
      (then (return (call $mk_Some (i32.const 13)))))
    (if (call $str_eq (local.get $word) (i32.const 373))    ;; "loop"
      (then (return (call $mk_Some (i32.const 14)))))
    (if (call $str_eq (local.get $word) (i32.const 381))    ;; "break"
      (then (return (call $mk_Some (i32.const 15)))))
    (if (call $str_eq (local.get $word) (i32.const 390))    ;; "continue"
      (then (return (call $mk_Some (i32.const 16)))))
    (if (call $str_eq (local.get $word) (i32.const 402))    ;; "return"
      (then (return (call $mk_Some (i32.const 17)))))
    (if (call $str_eq (local.get $word) (i32.const 412))    ;; "import"
      (then (return (call $mk_Some (i32.const 18)))))
    (if (call $str_eq (local.get $word) (i32.const 422))    ;; "where"
      (then (return (call $mk_Some (i32.const 19)))))
    (if (call $str_eq (local.get $word) (i32.const 431))    ;; "own"
      (then (return (call $mk_Some (i32.const 20)))))
    (if (call $str_eq (local.get $word) (i32.const 438))    ;; "ref"
      (then (return (call $mk_Some (i32.const 21)))))
    (if (call $str_eq (local.get $word) (i32.const 445))    ;; "capability"
      (then (return (call $mk_Some (i32.const 22)))))
    (if (call $str_eq (local.get $word) (i32.const 459))    ;; "Pure"
      (then (return (call $mk_Some (i32.const 22)))))
    (if (call $str_eq (local.get $word) (i32.const 467))    ;; "true"
      (then (return (call $mk_Some (i32.const 23)))))
    (if (call $str_eq (local.get $word) (i32.const 475))    ;; "false"
      (then (return (call $mk_Some (i32.const 24)))))
    (i32.const 70))  ;; None

  ;; ─── Two-char Operator Classification ─────────────────────────────
  (func $two_char_kind (param $a i32) (param $b i32) (result i32)
    (if (i32.and (i32.eq (local.get $a) (i32.const 61))
                 (i32.eq (local.get $b) (i32.const 61)))
      (then (return (call $mk_Some (i32.const 30)))))   ;; ==
    (if (i32.and (i32.eq (local.get $a) (i32.const 33))
                 (i32.eq (local.get $b) (i32.const 61)))
      (then (return (call $mk_Some (i32.const 31)))))   ;; !=
    (if (i32.and (i32.eq (local.get $a) (i32.const 60))
                 (i32.eq (local.get $b) (i32.const 61)))
      (then (return (call $mk_Some (i32.const 32)))))   ;; <=
    (if (i32.and (i32.eq (local.get $a) (i32.const 62))
                 (i32.eq (local.get $b) (i32.const 61)))
      (then (return (call $mk_Some (i32.const 33)))))   ;; >=
    (if (i32.and (i32.eq (local.get $a) (i32.const 45))
                 (i32.eq (local.get $b) (i32.const 62)))
      (then (return (call $mk_Some (i32.const 34)))))   ;; ->
    (if (i32.and (i32.eq (local.get $a) (i32.const 61))
                 (i32.eq (local.get $b) (i32.const 62)))
      (then (return (call $mk_Some (i32.const 35)))))   ;; =>
    (if (i32.and (i32.eq (local.get $a) (i32.const 43))
                 (i32.eq (local.get $b) (i32.const 43)))
      (then (return (call $mk_Some (i32.const 36)))))   ;; ++
    (if (i32.and (i32.eq (local.get $a) (i32.const 124))
                 (i32.eq (local.get $b) (i32.const 62)))
      (then (return (call $mk_Some (i32.const 37)))))   ;; |>
    (if (i32.and (i32.eq (local.get $a) (i32.const 60))
                 (i32.eq (local.get $b) (i32.const 124)))
      (then (return (call $mk_Some (i32.const 38)))))   ;; <|
    (if (i32.and (i32.eq (local.get $a) (i32.const 62))
                 (i32.eq (local.get $b) (i32.const 60)))
      (then (return (call $mk_Some (i32.const 39)))))   ;; ><
    (if (i32.and (i32.eq (local.get $a) (i32.const 126))
                 (i32.eq (local.get $b) (i32.const 62)))
      (then (return (call $mk_Some (i32.const 40)))))   ;; ~>
    (if (i32.and (i32.eq (local.get $a) (i32.const 60))
                 (i32.eq (local.get $b) (i32.const 126)))
      (then (return (call $mk_Some (i32.const 41)))))   ;; <~
    (if (i32.and (i32.eq (local.get $a) (i32.const 38))
                 (i32.eq (local.get $b) (i32.const 38)))
      (then (return (call $mk_Some (i32.const 42)))))   ;; &&
    (if (i32.and (i32.eq (local.get $a) (i32.const 124))
                 (i32.eq (local.get $b) (i32.const 124)))
      (then (return (call $mk_Some (i32.const 43)))))   ;; ||
    (if (i32.and (i32.eq (local.get $a) (i32.const 58))
                 (i32.eq (local.get $b) (i32.const 58)))
      (then (return (call $mk_Some (i32.const 44)))))   ;; ::
    (i32.const 70))  ;; None

  ;; ─── Single-char Operator Classification ──────────────────────────
  (func $single_char_kind (param $b i32) (result i32)
    (if (i32.eq (local.get $b) (i32.const 40))
      (then (return (call $mk_Some (i32.const 45)))))   ;; (
    (if (i32.eq (local.get $b) (i32.const 41))
      (then (return (call $mk_Some (i32.const 46)))))   ;; )
    (if (i32.eq (local.get $b) (i32.const 123))
      (then (return (call $mk_Some (i32.const 47)))))   ;; {
    (if (i32.eq (local.get $b) (i32.const 125))
      (then (return (call $mk_Some (i32.const 48)))))   ;; }
    (if (i32.eq (local.get $b) (i32.const 91))
      (then (return (call $mk_Some (i32.const 49)))))   ;; [
    (if (i32.eq (local.get $b) (i32.const 93))
      (then (return (call $mk_Some (i32.const 50)))))   ;; ]
    (if (i32.eq (local.get $b) (i32.const 44))
      (then (return (call $mk_Some (i32.const 51)))))   ;; ,
    (if (i32.eq (local.get $b) (i32.const 46))
      (then (return (call $mk_Some (i32.const 52)))))   ;; .
    (if (i32.eq (local.get $b) (i32.const 58))
      (then (return (call $mk_Some (i32.const 53)))))   ;; :
    (if (i32.eq (local.get $b) (i32.const 59))
      (then (return (call $mk_Some (i32.const 54)))))   ;; ;
    (if (i32.eq (local.get $b) (i32.const 43))
      (then (return (call $mk_Some (i32.const 55)))))   ;; +
    (if (i32.eq (local.get $b) (i32.const 45))
      (then (return (call $mk_Some (i32.const 56)))))   ;; -
    (if (i32.eq (local.get $b) (i32.const 42))
      (then (return (call $mk_Some (i32.const 57)))))   ;; *
    (if (i32.eq (local.get $b) (i32.const 47))
      (then (return (call $mk_Some (i32.const 58)))))   ;; /
    (if (i32.eq (local.get $b) (i32.const 37))
      (then (return (call $mk_Some (i32.const 59)))))   ;; %
    (if (i32.eq (local.get $b) (i32.const 61))
      (then (return (call $mk_Some (i32.const 60)))))   ;; =
    (if (i32.eq (local.get $b) (i32.const 60))
      (then (return (call $mk_Some (i32.const 61)))))   ;; <
    (if (i32.eq (local.get $b) (i32.const 62))
      (then (return (call $mk_Some (i32.const 62)))))   ;; >
    (if (i32.eq (local.get $b) (i32.const 33))
      (then (return (call $mk_Some (i32.const 63)))))   ;; !
    (if (i32.eq (local.get $b) (i32.const 124))
      (then (return (call $mk_Some (i32.const 64)))))   ;; |
    (if (i32.eq (local.get $b) (i32.const 126))
      (then (return (call $mk_Some (i32.const 65)))))   ;; ~
    (if (i32.eq (local.get $b) (i32.const 64))
      (then (return (call $mk_Some (i32.const 66)))))   ;; @
    (if (i32.eq (local.get $b) (i32.const 63))
      (then (return (call $mk_Some (i32.const 67)))))   ;; ?
    (i32.const 70))  ;; None

  ;; ─── push_tok: append token to buffer ─────────────────────────────
  ;; Returns (buf, count+1) as a 2-tuple [tag=0][buf][count]
  (func $push_tok (param $buf i32) (param $count i32) (param $tok i32) (result i32)
    (local $extended i32) (local $tup i32)
    (local.set $extended
      (call $list_extend_to (local.get $buf)
        (i32.add (local.get $count) (i32.const 1))))
    (drop (call $list_set (local.get $extended) (local.get $count) (local.get $tok)))
    ;; Return 2-tuple: [count=2][tag=0][buf][new_count]
    (local.set $tup (call $make_list (i32.const 2)))
    (drop (call $list_set (local.get $tup) (i32.const 0) (local.get $extended)))
    (drop (call $list_set (local.get $tup) (i32.const 1)
      (i32.add (local.get $count) (i32.const 1))))
    (local.get $tup))

  ;; ─── Lexer Helpers ────────────────────────────────────────────────

  ;; scan_to_eol: advance pos until newline or end
  (func $scan_to_eol (param $src i32) (param $n i32) (param $pos i32) (result i32)
    (block $done
      (loop $scan
        (br_if $done (i32.ge_u (local.get $pos) (local.get $n)))
        (br_if $done (i32.eq (call $byte_at (local.get $src) (local.get $pos)) (i32.const 10)))
        (local.set $pos (i32.add (local.get $pos) (i32.const 1)))
        (br $scan)))
    (local.get $pos))

  ;; scan_ident: advance over identifier chars. Returns new_pos.
  (func $scan_ident (param $src i32) (param $n i32) (param $pos i32) (result i32)
    (block $done
      (loop $scan
        (br_if $done (i32.ge_u (local.get $pos) (local.get $n)))
        (br_if $done (i32.eqz (call $is_alnum (call $byte_at (local.get $src) (local.get $pos)))))
        (local.set $pos (i32.add (local.get $pos) (i32.const 1)))
        (br $scan)))
    (local.get $pos))

  ;; scan_number: advance over digits and optional decimal point.
  ;; Returns new_pos. (Float detection deferred for simplicity.)
  (func $scan_number (param $src i32) (param $n i32) (param $pos i32) (result i32)
    (local $b i32)
    (block $done
      (loop $scan
        (br_if $done (i32.ge_u (local.get $pos) (local.get $n)))
        (local.set $b (call $byte_at (local.get $src) (local.get $pos)))
        (br_if $done (i32.eqz (call $is_digit (local.get $b))))
        (local.set $pos (i32.add (local.get $pos) (i32.const 1)))
        (br $scan)))
    (local.get $pos))

  ;; scan_string: advance past closing quote. Returns new_pos.
  ;; (Escape handling simplified — copies bytes without interpreting escapes.)
  (func $scan_string_end (param $src i32) (param $n i32) (param $pos i32) (result i32)
    (local $b i32)
    (block $done
      (loop $scan
        (br_if $done (i32.ge_u (local.get $pos) (local.get $n)))
        (local.set $b (call $byte_at (local.get $src) (local.get $pos)))
        ;; closing quote
        (if (i32.eq (local.get $b) (i32.const 34))
          (then (return (i32.add (local.get $pos) (i32.const 1)))))
        ;; backslash: skip next byte
        (if (i32.eq (local.get $b) (i32.const 92))
          (then (local.set $pos (i32.add (local.get $pos) (i32.const 1)))))
        (local.set $pos (i32.add (local.get $pos) (i32.const 1)))
        (br $scan)))
    (local.get $pos))
