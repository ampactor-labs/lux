  ;; ═══ Function Statement Parser (Complete) ═══════════════════════════
  ;; Hand-transcribed from src/parser.nx lines 367-441.
  ;;
  ;; fn name(params) [-> retty] [with effects] = body
  ;;
  ;; TParam(name, ty, own_marker, own_marker) → [tag=190][name][ty][own][own]
  ;; Ownership: Inferred=170, Own=171, Ref=172
  ;; Type sentinels: TyInt=200, TyFloat=201, TyString=202, TyBool=203,
  ;;                 TyUnit=204, TyName=205(fielded), TyVar=206(fielded)

  ;; TParam constructor
  (func $mk_TParam (param $name i32) (param $ty i32) (param $own i32) (result i32)
    (local $p i32) (local.set $p (call $alloc (i32.const 20)))
    (i32.store (local.get $p) (i32.const 190))
    (i32.store offset=4 (local.get $p) (local.get $name))
    (i32.store offset=8 (local.get $p) (local.get $ty))
    (i32.store offset=12 (local.get $p) (local.get $own))
    (i32.store offset=16 (local.get $p) (local.get $own))
    (local.get $p))

  ;; TyName(name) → [tag=205][name]
  (func $mk_TyName (param $name i32) (result i32)
    (local $p i32) (local.set $p (call $alloc (i32.const 8)))
    (i32.store (local.get $p) (i32.const 205))
    (i32.store offset=4 (local.get $p) (local.get $name))
    (local.get $p))

  ;; TyVar(handle) → [tag=206][handle]
  (func $mk_TyVar (param $h i32) (result i32)
    (local $p i32) (local.set $p (call $alloc (i32.const 8)))
    (i32.store (local.get $p) (i32.const 206))
    (i32.store offset=4 (local.get $p) (local.get $h))
    (local.get $p))

  ;; TyRecord(fields) → [tag=207][fields]
  ;; Fields are a list of 2-tuples (name, parser-Ty).
  (func $mk_TyRecord (param $fields i32) (result i32)
    (local $p i32) (local.set $p (call $alloc (i32.const 8)))
    (i32.store (local.get $p) (i32.const 207))
    (i32.store offset=4 (local.get $p) (local.get $fields))
    (local.get $p))

  ;; ─── parse_type_ty: type expression parser ────────────────────────
  ;; Int → 200, Float → 201, String → 202, Bool → TyName("Bool"),
  ;; Unit → 204, other ident → TyName(v), () → TyUnit
  ;; Returns (ty, new_pos) as 2-tuple.

  ;; Data segments for type name comparison (safe region 536+)
  ;; "Int" at 536, "Float" at 544, "String" at 552, "Bool" at 564, "Unit" at 572
  ;; These need length prefixes for str_eq comparison.

  (func $parse_type_ty (param $tokens i32) (param $pos i32) (result i32)
    (local $k i32) (local $name i32) (local $tup i32) (local $p i32)
    (local.set $k (call $kind_at (local.get $tokens) (local.get $pos)))
    ;; TIdent → check for known type names
    (if (i32.and
          (i32.eqz (call $is_sentinel (local.get $k)))
          (i32.eq (call $tag_of (local.get $k)) (i32.const 25)))
      (then
        (local.set $name (i32.load offset=4 (local.get $k)))
        (local.set $tup (call $make_list (i32.const 2)))
        ;; Check known names via first char + length
        (if (i32.and (i32.eq (call $str_len (local.get $name)) (i32.const 3))
                     (i32.eq (call $byte_at (local.get $name) (i32.const 0)) (i32.const 73))) ;; 'I'
          (then ;; "Int"
            (drop (call $list_set (local.get $tup) (i32.const 0) (i32.const 200)))
            (drop (call $list_set (local.get $tup) (i32.const 1) (i32.add (local.get $pos) (i32.const 1))))
            (return (local.get $tup))))
        (if (i32.and (i32.eq (call $str_len (local.get $name)) (i32.const 5))
                     (i32.eq (call $byte_at (local.get $name) (i32.const 0)) (i32.const 70))) ;; 'F'
          (then ;; "Float"
            (drop (call $list_set (local.get $tup) (i32.const 0) (i32.const 201)))
            (drop (call $list_set (local.get $tup) (i32.const 1) (i32.add (local.get $pos) (i32.const 1))))
            (return (local.get $tup))))
        (if (i32.and (i32.eq (call $str_len (local.get $name)) (i32.const 6))
                     (i32.eq (call $byte_at (local.get $name) (i32.const 0)) (i32.const 83))) ;; 'S'
          (then ;; "String"
            (drop (call $list_set (local.get $tup) (i32.const 0) (i32.const 202)))
            (drop (call $list_set (local.get $tup) (i32.const 1) (i32.add (local.get $pos) (i32.const 1))))
            (return (local.get $tup))))
        (if (i32.and (i32.eq (call $str_len (local.get $name)) (i32.const 4))
                     (i32.eq (call $byte_at (local.get $name) (i32.const 0)) (i32.const 85))) ;; 'U'
          (then ;; "Unit"
            (drop (call $list_set (local.get $tup) (i32.const 0) (i32.const 204)))
            (drop (call $list_set (local.get $tup) (i32.const 1) (i32.add (local.get $pos) (i32.const 1))))
            (return (local.get $tup))))
        ;; Default: TyName(name)
        (drop (call $list_set (local.get $tup) (i32.const 0) (call $mk_TyName (local.get $name))))
        (drop (call $list_set (local.get $tup) (i32.const 1) (i32.add (local.get $pos) (i32.const 1))))
        (return (local.get $tup))))
    ;; TLParen → () is TyUnit, or parse tuple type
    (if (i32.and (call $is_sentinel (local.get $k)) (i32.eq (local.get $k) (i32.const 45)))
      (then
        (local.set $p (call $skip_ws_p (local.get $tokens) (i32.add (local.get $pos) (i32.const 1))))
        (if (call $at (local.get $tokens) (local.get $p) (i32.const 46)) ;; TRParen
          (then
            (local.set $tup (call $make_list (i32.const 2)))
            (drop (call $list_set (local.get $tup) (i32.const 0) (i32.const 204)))
            (drop (call $list_set (local.get $tup) (i32.const 1) (i32.add (local.get $p) (i32.const 1))))
            (return (local.get $tup))))))
    ;; Fallback
    (local.set $tup (call $make_list (i32.const 2)))
    (drop (call $list_set (local.get $tup) (i32.const 0) (i32.const 204)))
    (drop (call $list_set (local.get $tup) (i32.const 1) (i32.add (local.get $pos) (i32.const 1))))
    (local.get $tup))

  ;; ─── parse_one_param ──────────────────────────────────────────────
  ;; [own|ref] name [: Type]
  ;; Returns (TParam, new_pos) as 2-tuple.

  (func $parse_one_param (param $tokens i32) (param $pos i32) (result i32)
    (local $own i32) (local $p i32) (local $name i32) (local $p2 i32)
    (local $ty_r i32) (local $ty i32) (local $tup i32) (local $k i32)
    ;; Check ownership marker
    (local.set $k (call $kind_at (local.get $tokens) (local.get $pos)))
    (local.set $own (i32.const 170)) ;; Inferred
    (local.set $p (local.get $pos))
    (if (i32.eq (local.get $k) (i32.const 20)) ;; TOwn
      (then
        (local.set $own (i32.const 171))
        (local.set $p (call $skip_ws_p (local.get $tokens) (i32.add (local.get $pos) (i32.const 1))))))
    (if (i32.eq (local.get $k) (i32.const 21)) ;; TRef
      (then
        (local.set $own (i32.const 172))
        (local.set $p (call $skip_ws_p (local.get $tokens) (i32.add (local.get $pos) (i32.const 1))))))
    ;; Get param name
    (local.set $name (call $ident_at_p (local.get $tokens) (local.get $p)))
    (local.set $p2 (call $skip_ws_p (local.get $tokens) (i32.add (local.get $p) (i32.const 1))))
    ;; Check for : Type annotation
    (if (call $at (local.get $tokens) (local.get $p2) (i32.const 53)) ;; TColon
      (then
        (local.set $ty_r (call $parse_type_ty (local.get $tokens)
          (call $skip_ws_p (local.get $tokens) (i32.add (local.get $p2) (i32.const 1)))))
        (local.set $ty (call $list_index (local.get $ty_r) (i32.const 0)))
        (local.set $p2 (call $list_index (local.get $ty_r) (i32.const 1))))
      (else
        ;; No annotation → TyVar(fresh)
        (local.set $ty (call $mk_TyVar (call $fresh_handle)))))
    (local.set $tup (call $make_list (i32.const 2)))
    (drop (call $list_set (local.get $tup) (i32.const 0)
      (call $mk_TParam (local.get $name) (local.get $ty) (local.get $own))))
    (drop (call $list_set (local.get $tup) (i32.const 1) (local.get $p2)))
    (local.get $tup))

  ;; ─── parse_fn_params: comma-sep params until RParen ───────────────

  (func $parse_fn_params (param $tokens i32) (param $pos i32) (result i32)
    (local $p i32) (local $buf i32) (local $count i32)
    (local $param_r i32) (local $param i32) (local $p2 i32) (local $p3 i32)
    (local $tup i32)
    (local.set $p (call $skip_ws_p (local.get $tokens) (local.get $pos)))
    ;; Empty params
    (if (call $at (local.get $tokens) (local.get $p) (i32.const 46)) ;; TRParen
      (then
        (local.set $tup (call $make_list (i32.const 2)))
        (drop (call $list_set (local.get $tup) (i32.const 0) (call $make_list (i32.const 0))))
        (drop (call $list_set (local.get $tup) (i32.const 1) (i32.add (local.get $p) (i32.const 1))))
        (return (local.get $tup))))
    (local.set $buf (call $make_list (i32.const 4)))
    (local.set $count (i32.const 0))
    (block $done
      (loop $params
        (local.set $param_r (call $parse_one_param (local.get $tokens) (local.get $p)))
        (local.set $param (call $list_index (local.get $param_r) (i32.const 0)))
        (local.set $p2 (call $list_index (local.get $param_r) (i32.const 1)))
        (local.set $buf (call $list_extend_to (local.get $buf)
          (i32.add (local.get $count) (i32.const 1))))
        (drop (call $list_set (local.get $buf) (local.get $count) (local.get $param)))
        (local.set $count (i32.add (local.get $count) (i32.const 1)))
        (local.set $p3 (call $skip_ws_p (local.get $tokens) (local.get $p2)))
        (if (call $at (local.get $tokens) (local.get $p3) (i32.const 51)) ;; TComma
          (then
            (local.set $p (call $skip_ws_p (local.get $tokens) (i32.add (local.get $p3) (i32.const 1))))
            (br $params))
          (else
            (local.set $p (call $expect (local.get $tokens) (local.get $p3) (i32.const 46)))
            (br $done)))))
    ;; Build flat result list (avoid lazy slice view)
    (local.set $param_r (call $make_list (local.get $count)))
    (local.set $p3 (i32.const 0))
    (block $cp_done (loop $cp
      (br_if $cp_done (i32.ge_u (local.get $p3) (local.get $count)))
      (drop (call $list_set (local.get $param_r) (local.get $p3)
        (call $list_index (local.get $buf) (local.get $p3))))
      (local.set $p3 (i32.add (local.get $p3) (i32.const 1)))
      (br $cp)))
    (local.set $tup (call $make_list (i32.const 2)))
    (drop (call $list_set (local.get $tup) (i32.const 0) (local.get $param_r)))
    (drop (call $list_set (local.get $tup) (i32.const 1) (local.get $p)))
    (local.get $tup))

  ;; ─── parse_fn_stmt (COMPLETE) ─────────────────────────────────────
  ;; fn name(params) [-> retty] [with effects] = body

  (func $parse_fn_stmt (param $tokens i32) (param $pos i32) (param $span i32) (result i32)
    (local $name i32) (local $p i32) (local $params_r i32) (local $params i32)
    (local $p2 i32) (local $ret i32) (local $p3 i32)
    (local $p4 i32) (local $body_r i32) (local $tup i32)
    ;; Get function name
    (local.set $name (call $ident_at_p (local.get $tokens) (local.get $pos)))
    ;; Parse (params)
    (local.set $p (call $expect (local.get $tokens)
      (call $skip_ws_p (local.get $tokens) (i32.add (local.get $pos) (i32.const 1)))
      (i32.const 45))) ;; TLParen
    (local.set $params_r (call $parse_fn_params (local.get $tokens) (local.get $p)))
    (local.set $params (call $list_index (local.get $params_r) (i32.const 0)))
    (local.set $p2 (call $skip_ws_p (local.get $tokens)
      (call $list_index (local.get $params_r) (i32.const 1))))
    ;; Optional -> return type
    (local.set $ret (call $nexpr (i32.const 84) (local.get $span))) ;; default LitUnit
    (if (call $at (local.get $tokens) (local.get $p2) (i32.const 34)) ;; TArrow
      (then
        (local.set $p3 (call $skip_ws_p (local.get $tokens) (i32.add (local.get $p2) (i32.const 1))))
        ;; We just skip the return type annotation for now (type is in the TParam)
        (local.set $p2 (call $skip_to_eq_or_brace (local.get $tokens) (local.get $p3)))))
    ;; Skip optional 'with effects'
    (if (call $at (local.get $tokens) (local.get $p2) (i32.const 9)) ;; TWith
      (then
        (local.set $p2 (call $skip_to_eq_or_brace (local.get $tokens)
          (i32.add (local.get $p2) (i32.const 1))))))
    ;; Skip = if present
    (if (call $at (local.get $tokens) (local.get $p2) (i32.const 60)) ;; TEq
      (then (local.set $p2 (i32.add (local.get $p2) (i32.const 1)))))
    ;; Parse body
    (local.set $p3 (call $skip_ws_p (local.get $tokens) (local.get $p2)))
    (if (call $at (local.get $tokens) (local.get $p3) (i32.const 47)) ;; TLBrace
      (then (local.set $body_r (call $parse_block (local.get $tokens)
        (i32.add (local.get $p3) (i32.const 1)) (local.get $span))))
      (else (local.set $body_r (call $parse_expr (local.get $tokens) (local.get $p3)))))
    ;; Build FnStmt
    (local.set $tup (call $make_list (i32.const 2)))
    (drop (call $list_set (local.get $tup) (i32.const 0)
      (call $nstmt
        (call $mk_FnStmt (local.get $name) (local.get $params)
          (local.get $ret) (call $make_list (i32.const 0))
          (call $list_index (local.get $body_r) (i32.const 0)))
        (local.get $span))))
    (drop (call $list_set (local.get $tup) (i32.const 1)
      (call $list_index (local.get $body_r) (i32.const 1))))
    (local.get $tup))

  ;; Helper: skip to = or { (for skipping return type and effect annotations)
  (func $skip_to_eq_or_brace (param $tokens i32) (param $pos i32) (result i32)
    (local $k i32)
    (block $done (loop $scan
      (local.set $k (call $kind_at (local.get $tokens) (local.get $pos)))
      (br_if $done (i32.eq (local.get $k) (i32.const 60)))  ;; TEq
      (br_if $done (i32.eq (local.get $k) (i32.const 47)))  ;; TLBrace
      (br_if $done (i32.eq (local.get $k) (i32.const 69)))  ;; TEof
      (br_if $done (i32.eq (local.get $k) (i32.const 68)))  ;; TNewline
      (local.set $pos (i32.add (local.get $pos) (i32.const 1)))
      (br $scan)))
    (local.get $pos))
