  ;; ─── Parser Infrastructure ──────────────────────────────────────────
  ;; Graph stub: fresh handle = incrementing counter
  ;; (Real graph comes later; parser just needs unique IDs)

  (global $next_handle (mut i32) (i32.const 1))

  (func $fresh_handle (result i32)
    (local $h i32)
    (local.set $h (global.get $next_handle))
    (global.set $next_handle (i32.add (global.get $next_handle) (i32.const 1)))
    (local.get $h))

  ;; ─── AST Node Sentinel IDs ────────────────────────────────────────
  ;; Expr variants: LitInt=80 LitFloat=81 LitString=82 LitBool=83
  ;;   LitUnit=84 VarRef=85 BinOpExpr=86 UnaryOpExpr=87
  ;;   CallExpr=88 LambdaExpr=89 IfExpr=90 BlockExpr=91
  ;;   MatchExpr=92 HandleExpr=93 PerformExpr=94 ResumeExpr=95
  ;;   MakeListExpr=96 MakeTupleExpr=97 MakeRecordExpr=98
  ;;   NamedRecordExpr=99 FieldExpr=100 PipeExpr=101
  ;; NodeBody: NExpr=110 NStmt=111 NPat=112 NHole=113
  ;; Stmt: LetStmt=120 FnStmt=121 TypeDefStmt=122
  ;;   EffectDeclStmt=123 HandlerDeclStmt=124 ExprStmt=125
  ;;   ImportStmt=126 RefineStmt=127 Documented=128
  ;; Pat: PVar=130 PWild=131 PLit=132 PCon=133
  ;;   PTuple=134 PList=135 PRecord=136
  ;; BinOp: BAdd=140..BConcat=153
  ;; PipeKind: PForward=160 PDiverge=161 PCompose=162
  ;;   PTeeBlock=163 PTeeInline=164 PFeedback=165
  ;; Ownership: Inferred=170 Own=171 Ref=172

  ;; N(body, span, handle) → [tag=0][body][span][handle]
  (func $mk_node (param $body i32) (param $span i32) (param $handle i32) (result i32)
    (local $ptr i32)
    (local.set $ptr (call $alloc (i32.const 16)))
    (i32.store (local.get $ptr) (i32.const 0))
    (i32.store offset=4 (local.get $ptr) (local.get $body))
    (i32.store offset=8 (local.get $ptr) (local.get $span))
    (i32.store offset=12 (local.get $ptr) (local.get $handle))
    (local.get $ptr))

  ;; NExpr(e) → [tag=110][e]
  (func $mk_NExpr (param $e i32) (result i32)
    (local $ptr i32)
    (local.set $ptr (call $alloc (i32.const 8)))
    (i32.store (local.get $ptr) (i32.const 110))
    (i32.store offset=4 (local.get $ptr) (local.get $e))
    (local.get $ptr))

  ;; NStmt(s) → [tag=111][s]
  (func $mk_NStmt (param $s i32) (result i32)
    (local $ptr i32)
    (local.set $ptr (call $alloc (i32.const 8)))
    (i32.store (local.get $ptr) (i32.const 111))
    (i32.store offset=4 (local.get $ptr) (local.get $s))
    (local.get $ptr))

  ;; nexpr(e, span) = N(NExpr(e), span, fresh_handle())
  (func $nexpr (param $e i32) (param $span i32) (result i32)
    (call $mk_node
      (call $mk_NExpr (local.get $e))
      (local.get $span)
      (call $fresh_handle)))

  ;; nstmt(s, span) = N(NStmt(s), span, fresh_handle())
  (func $nstmt (param $s i32) (param $span i32) (result i32)
    (call $mk_node
      (call $mk_NStmt (local.get $s))
      (local.get $span)
      (call $fresh_handle)))

  ;; ─── Expr constructors ────────────────────────────────────────────

  ;; LitInt(n) → [tag=80][n]
  (func $mk_LitInt (param $n i32) (result i32)
    (local $p i32) (local.set $p (call $alloc (i32.const 8)))
    (i32.store (local.get $p) (i32.const 80))
    (i32.store offset=4 (local.get $p) (local.get $n))
    (local.get $p))

  ;; LitString(s) → [tag=82][s]
  (func $mk_LitString (param $s i32) (result i32)
    (local $p i32) (local.set $p (call $alloc (i32.const 8)))
    (i32.store (local.get $p) (i32.const 82))
    (i32.store offset=4 (local.get $p) (local.get $s))
    (local.get $p))

  ;; LitBool(b) → [tag=83][b]  (b: 0=false, 1=true)
  (func $mk_LitBool (param $b i32) (result i32)
    (local $p i32) (local.set $p (call $alloc (i32.const 8)))
    (i32.store (local.get $p) (i32.const 83))
    (i32.store offset=4 (local.get $p) (local.get $b))
    (local.get $p))

  ;; VarRef(name) → [tag=85][name_ptr]
  (func $mk_VarRef (param $name i32) (result i32)
    (local $p i32) (local.set $p (call $alloc (i32.const 8)))
    (i32.store (local.get $p) (i32.const 85))
    (i32.store offset=4 (local.get $p) (local.get $name))
    (local.get $p))

  ;; BinOpExpr(op, left, right) → [tag=86][op][left][right]
  (func $mk_BinOpExpr (param $op i32) (param $l i32) (param $r i32) (result i32)
    (local $p i32) (local.set $p (call $alloc (i32.const 16)))
    (i32.store (local.get $p) (i32.const 86))
    (i32.store offset=4 (local.get $p) (local.get $op))
    (i32.store offset=8 (local.get $p) (local.get $l))
    (i32.store offset=12 (local.get $p) (local.get $r))
    (local.get $p))

  ;; CallExpr(callee, args) → [tag=88][callee][args]
  (func $mk_CallExpr (param $callee i32) (param $args i32) (result i32)
    (local $p i32) (local.set $p (call $alloc (i32.const 12)))
    (i32.store (local.get $p) (i32.const 88))
    (i32.store offset=4 (local.get $p) (local.get $callee))
    (i32.store offset=8 (local.get $p) (local.get $args))
    (local.get $p))

  ;; IfExpr(cond, then, else) → [tag=90][cond][then][else]
  (func $mk_IfExpr (param $c i32) (param $t i32) (param $e i32) (result i32)
    (local $p i32) (local.set $p (call $alloc (i32.const 16)))
    (i32.store (local.get $p) (i32.const 90))
    (i32.store offset=4 (local.get $p) (local.get $c))
    (i32.store offset=8 (local.get $p) (local.get $t))
    (i32.store offset=12 (local.get $p) (local.get $e))
    (local.get $p))

  ;; BlockExpr(stmts, final_expr) → [tag=91][stmts][expr]
  (func $mk_BlockExpr (param $stmts i32) (param $expr i32) (result i32)
    (local $p i32) (local.set $p (call $alloc (i32.const 12)))
    (i32.store (local.get $p) (i32.const 91))
    (i32.store offset=4 (local.get $p) (local.get $stmts))
    (i32.store offset=8 (local.get $p) (local.get $expr))
    (local.get $p))

  ;; MatchExpr(scrut, arms) → [tag=92][scrut][arms]
  (func $mk_MatchExpr (param $scrut i32) (param $arms i32) (result i32)
    (local $p i32) (local.set $p (call $alloc (i32.const 12)))
    (i32.store (local.get $p) (i32.const 92))
    (i32.store offset=4 (local.get $p) (local.get $scrut))
    (i32.store offset=8 (local.get $p) (local.get $arms))
    (local.get $p))

  ;; PerformExpr(op_name, args) → [tag=94][name][args]
  (func $mk_PerformExpr (param $name i32) (param $args i32) (result i32)
    (local $p i32) (local.set $p (call $alloc (i32.const 12)))
    (i32.store (local.get $p) (i32.const 94))
    (i32.store offset=4 (local.get $p) (local.get $name))
    (i32.store offset=8 (local.get $p) (local.get $args))
    (local.get $p))

  ;; PipeExpr(kind, left, right) → [tag=101][kind][left][right]
  (func $mk_PipeExpr (param $kind i32) (param $l i32) (param $r i32) (result i32)
    (local $p i32) (local.set $p (call $alloc (i32.const 16)))
    (i32.store (local.get $p) (i32.const 101))
    (i32.store offset=4 (local.get $p) (local.get $kind))
    (i32.store offset=8 (local.get $p) (local.get $l))
    (i32.store offset=12 (local.get $p) (local.get $r))
    (local.get $p))

  ;; ─── Stmt constructors ────────────────────────────────────────────

  ;; LetStmt(pat, val) → [tag=120][pat][val]
  (func $mk_LetStmt (param $pat i32) (param $val i32) (result i32)
    (local $p i32) (local.set $p (call $alloc (i32.const 12)))
    (i32.store (local.get $p) (i32.const 120))
    (i32.store offset=4 (local.get $p) (local.get $pat))
    (i32.store offset=8 (local.get $p) (local.get $val))
    (local.get $p))

  ;; FnStmt(name, params, ret, effs, body)
  (func $mk_FnStmt (param $name i32) (param $params i32) (param $ret i32) (param $effs i32) (param $body i32) (result i32)
    (local $p i32) (local.set $p (call $alloc (i32.const 24)))
    (i32.store (local.get $p) (i32.const 121))
    (i32.store offset=4 (local.get $p) (local.get $name))
    (i32.store offset=8 (local.get $p) (local.get $params))
    (i32.store offset=12 (local.get $p) (local.get $ret))
    (i32.store offset=16 (local.get $p) (local.get $effs))
    (i32.store offset=20 (local.get $p) (local.get $body))
    (local.get $p))

  ;; ExprStmt(node) → [tag=125][node]
  (func $mk_ExprStmt (param $node i32) (result i32)
    (local $p i32) (local.set $p (call $alloc (i32.const 8)))
    (i32.store (local.get $p) (i32.const 125))
    (i32.store offset=4 (local.get $p) (local.get $node))
    (local.get $p))

  ;; ImportStmt(path) → [tag=126][path]
  (func $mk_ImportStmt (param $path i32) (result i32)
    (local $p i32) (local.set $p (call $alloc (i32.const 8)))
    (i32.store (local.get $p) (i32.const 126))
    (i32.store offset=4 (local.get $p) (local.get $path))
    (local.get $p))

  ;; TypeDefStmt(name, targs, variants)
  (func $mk_TypeDefStmt (param $name i32) (param $targs i32) (param $variants i32) (result i32)
    (local $p i32) (local.set $p (call $alloc (i32.const 16)))
    (i32.store (local.get $p) (i32.const 122))
    (i32.store offset=4 (local.get $p) (local.get $name))
    (i32.store offset=8 (local.get $p) (local.get $targs))
    (i32.store offset=12 (local.get $p) (local.get $variants))
    (local.get $p))

  ;; EffectDeclStmt(name, ops)
  (func $mk_EffectDeclStmt (param $name i32) (param $ops i32) (result i32)
    (local $p i32) (local.set $p (call $alloc (i32.const 12)))
    (i32.store (local.get $p) (i32.const 123))
    (i32.store offset=4 (local.get $p) (local.get $name))
    (i32.store offset=8 (local.get $p) (local.get $ops))
    (local.get $p))

  ;; ─── Token navigation (parser helpers) ────────────────────────────

  ;; kind_at: get TokenKind at pos. Token = [tag][kind][span]
  (func $kind_at (param $tokens i32) (param $pos i32) (result i32)
    (local $tok i32)
    (if (result i32) (i32.ge_u (local.get $pos) (call $len (local.get $tokens)))
      (then (i32.const 69))  ;; TEof
      (else
        (local.set $tok (call $list_index (local.get $tokens) (local.get $pos)))
        (i32.load offset=4 (local.get $tok)))))

  ;; span_at: get Span at pos
  (func $span_at_p (param $tokens i32) (param $pos i32) (result i32)
    (local $tok i32)
    (if (result i32) (i32.ge_u (local.get $pos) (call $len (local.get $tokens)))
      (then (call $mk_span (i32.const 0) (i32.const 0) (i32.const 0) (i32.const 0)))
      (else
        (local.set $tok (call $list_index (local.get $tokens) (local.get $pos)))
        (i32.load offset=8 (local.get $tok)))))

  ;; kind_eq_sentinel: compare two TokenKinds. For sentinels (<4096),
  ;; direct i32 compare. For fielded, compare tags at offset 0.
  (func $kind_eq_s (param $a i32) (param $b i32) (result i32)
    (if (result i32) (i32.and
          (call $is_sentinel (local.get $a))
          (call $is_sentinel (local.get $b)))
      (then (i32.eq (local.get $a) (local.get $b)))
      (else
        (if (result i32) (i32.and
              (i32.eqz (call $is_sentinel (local.get $a)))
              (i32.eqz (call $is_sentinel (local.get $b))))
          (then (i32.eq (call $tag_of (local.get $a))
                        (call $tag_of (local.get $b))))
          (else (i32.const 0))))))

  ;; at: check if token at pos has given kind
  (func $at (param $tokens i32) (param $pos i32) (param $kind i32) (result i32)
    (call $kind_eq_s
      (call $kind_at (local.get $tokens) (local.get $pos))
      (local.get $kind)))

  ;; skip_ws: skip TNewline tokens
  (func $skip_ws_p (param $tokens i32) (param $pos i32) (result i32)
    (block $done
      (loop $skip
        (br_if $done (i32.ne (call $kind_at (local.get $tokens) (local.get $pos)) (i32.const 68)))
        (local.set $pos (i32.add (local.get $pos) (i32.const 1)))
        (br $skip)))
    (local.get $pos))

  ;; skip_sep: skip TNewline and TSemicolon
  (func $skip_sep (param $tokens i32) (param $pos i32) (result i32)
    (local $k i32)
    (block $done
      (loop $skip
        (local.set $k (call $kind_at (local.get $tokens) (local.get $pos)))
        (br_if $done (i32.and
          (i32.ne (local.get $k) (i32.const 68))   ;; TNewline
          (i32.ne (local.get $k) (i32.const 54))))  ;; TSemicolon
        (local.set $pos (i32.add (local.get $pos) (i32.const 1)))
        (br $skip)))
    (local.get $pos))

  ;; expect: consume kind or skip
  (func $expect (param $tokens i32) (param $pos i32) (param $kind i32) (result i32)
    (if (result i32) (call $at (local.get $tokens) (local.get $pos) (local.get $kind))
      (then (i32.add (local.get $pos) (i32.const 1)))
      (else (local.get $pos))))

  ;; ident_at: extract string from TIdent at pos
  (func $ident_at_p (param $tokens i32) (param $pos i32) (result i32)
    (local $k i32)
    (local.set $k (call $kind_at (local.get $tokens) (local.get $pos)))
    (if (result i32) (i32.and
          (i32.eqz (call $is_sentinel (local.get $k)))
          (i32.eq (call $tag_of (local.get $k)) (i32.const 25)))
      (then (i32.load offset=4 (local.get $k)))
      (else (call $str_alloc (i32.const 0)))))

  ;; int_payload: extract int from TInt at pos
  (func $int_at_p (param $tokens i32) (param $pos i32) (result i32)
    (local $k i32)
    (local.set $k (call $kind_at (local.get $tokens) (local.get $pos)))
    (if (result i32) (i32.and
          (i32.eqz (call $is_sentinel (local.get $k)))
          (i32.eq (call $tag_of (local.get $k)) (i32.const 26)))
      (then (i32.load offset=4 (local.get $k)))
      (else (i32.const 0))))

  ;; ─── Operator precedence ──────────────────────────────────────────
  (func $op_prec (param $k i32) (result i32)
    ;; Only sentinels can be operators
    (if (i32.eqz (call $is_sentinel (local.get $k)))
      (then (return (i32.const 0))))
    (if (i32.eq (local.get $k) (i32.const 43)) (then (return (i32.const 1))))  ;; TOrOr
    (if (i32.eq (local.get $k) (i32.const 42)) (then (return (i32.const 2))))  ;; TAndAnd
    (if (i32.eq (local.get $k) (i32.const 30)) (then (return (i32.const 3))))  ;; TEqEq
    (if (i32.eq (local.get $k) (i32.const 31)) (then (return (i32.const 3))))  ;; TBangEq
    (if (i32.eq (local.get $k) (i32.const 61)) (then (return (i32.const 4))))  ;; TLt
    (if (i32.eq (local.get $k) (i32.const 62)) (then (return (i32.const 4))))  ;; TGt
    (if (i32.eq (local.get $k) (i32.const 32)) (then (return (i32.const 4))))  ;; TLtEq
    (if (i32.eq (local.get $k) (i32.const 33)) (then (return (i32.const 4))))  ;; TGtEq
    (if (i32.eq (local.get $k) (i32.const 36)) (then (return (i32.const 5))))  ;; TPlusPlus
    (if (i32.eq (local.get $k) (i32.const 39)) (then (return (i32.const 6))))  ;; TGtLt
    (if (i32.eq (local.get $k) (i32.const 37)) (then (return (i32.const 7))))  ;; TPipeGt
    (if (i32.eq (local.get $k) (i32.const 38)) (then (return (i32.const 8))))  ;; TLtPipe
    (if (i32.eq (local.get $k) (i32.const 41)) (then (return (i32.const 9))))  ;; TLtTilde
    (if (i32.eq (local.get $k) (i32.const 40)) (then (return (i32.const 10)))) ;; TTildeGt
    (if (i32.eq (local.get $k) (i32.const 55)) (then (return (i32.const 11)))) ;; TPlus
    (if (i32.eq (local.get $k) (i32.const 56)) (then (return (i32.const 11)))) ;; TMinus
    (if (i32.eq (local.get $k) (i32.const 57)) (then (return (i32.const 12)))) ;; TStar
    (if (i32.eq (local.get $k) (i32.const 58)) (then (return (i32.const 12)))) ;; TSlash
    (if (i32.eq (local.get $k) (i32.const 59)) (then (return (i32.const 12)))) ;; TPercent
    (i32.const 0))

  ;; op_to_binop: map token kind → BinOp sentinel
  (func $op_to_binop (param $k i32) (result i32)
    (if (i32.eq (local.get $k) (i32.const 55)) (then (return (i32.const 140)))) ;; TPlus→BAdd
    (if (i32.eq (local.get $k) (i32.const 56)) (then (return (i32.const 141)))) ;; TMinus→BSub
    (if (i32.eq (local.get $k) (i32.const 57)) (then (return (i32.const 142)))) ;; TStar→BMul
    (if (i32.eq (local.get $k) (i32.const 58)) (then (return (i32.const 143)))) ;; TSlash→BDiv
    (if (i32.eq (local.get $k) (i32.const 59)) (then (return (i32.const 144)))) ;; TPercent→BMod
    (if (i32.eq (local.get $k) (i32.const 30)) (then (return (i32.const 145)))) ;; TEqEq→BEq
    (if (i32.eq (local.get $k) (i32.const 31)) (then (return (i32.const 146)))) ;; TBangEq→BNe
    (if (i32.eq (local.get $k) (i32.const 61)) (then (return (i32.const 147)))) ;; TLt→BLt
    (if (i32.eq (local.get $k) (i32.const 62)) (then (return (i32.const 148)))) ;; TGt→BGt
    (if (i32.eq (local.get $k) (i32.const 32)) (then (return (i32.const 149)))) ;; TLtEq→BLe
    (if (i32.eq (local.get $k) (i32.const 33)) (then (return (i32.const 150)))) ;; TGtEq→BGe
    (if (i32.eq (local.get $k) (i32.const 42)) (then (return (i32.const 151)))) ;; TAndAnd→BAnd
    (if (i32.eq (local.get $k) (i32.const 43)) (then (return (i32.const 152)))) ;; TOrOr→BOr
    (if (i32.eq (local.get $k) (i32.const 36)) (then (return (i32.const 153)))) ;; TPlusPlus→BConcat
    (i32.const 0))

  ;; is_pipe_op: check if a token is a pipe operator
  (func $is_pipe_op (param $k i32) (result i32)
    (i32.or (i32.or
      (i32.or (i32.eq (local.get $k) (i32.const 37))   ;; TPipeGt
              (i32.eq (local.get $k) (i32.const 38)))   ;; TLtPipe
      (i32.or (i32.eq (local.get $k) (i32.const 39))   ;; TGtLt
              (i32.eq (local.get $k) (i32.const 40))))  ;; TTildeGt
      (i32.eq (local.get $k) (i32.const 41))))          ;; TLtTilde

  ;; pipe_kind: map token → PipeKind sentinel
  (func $pipe_kind (param $k i32) (result i32)
    (if (i32.eq (local.get $k) (i32.const 37)) (then (return (i32.const 160)))) ;; PForward
    (if (i32.eq (local.get $k) (i32.const 38)) (then (return (i32.const 161)))) ;; PDiverge
    (if (i32.eq (local.get $k) (i32.const 39)) (then (return (i32.const 162)))) ;; PCompose
    (if (i32.eq (local.get $k) (i32.const 40)) (then (return (i32.const 164)))) ;; PTeeInline
    (if (i32.eq (local.get $k) (i32.const 41)) (then (return (i32.const 165)))) ;; PFeedback
    (i32.const 160))
