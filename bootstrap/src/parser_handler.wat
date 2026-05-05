  ;; ═══ parser_handler.wat — full HandlerDeclStmt parser ════════════════
  ;; Per Hβ-first-light §"19-box handler-decl-emit cascade" + plan tracker
  ;; entry "parser-handler-arms": closes the broken stub at
  ;; bootstrap/src/parser_toplevel.wat:43-54 ($skip_to_rbrace mis-counts
  ;; brace depth — depth-mismatch consumed wheel content per handler-decl,
  ;; exhausting the 16 MB bump allocator on 7+ wheel files; full surface
  ;; deferral was logged as a positive-form named follow-up per drift
  ;; mode 9). This chunk is the substrate-honest closure.
  ;;
  ;; Surface (SYNTAX.md handler-decl + src/parser.nx wheel-canonical):
  ;;
  ;;   handler NAME [with FIELD = INIT [, FIELD = INIT]*] {
  ;;     OP_NAME(arg, ...) => BODY,
  ;;     ...
  ;;   }
  ;;
  ;; HandlerDeclStmt layout (extends prior 4-field shell with state at
  ;; offset 16 — additive, infer/walk_stmt.wat:1015-1041 + lower/walk_stmt.wat:577-602
  ;; only read offsets 0/4/8/12 so older readers stay correct):
  ;;
  ;;   [tag=124][name][effect_name=""][arms][state_fields]
  ;;   offsets   0     4     8           12     16
  ;;
  ;; effect_name resolved by infer's per-arm cascade (Hβ-infer-handler-decls-full
  ;; named follow-up — the seed leaves "" here; infer's seed stub today reads
  ;; offset 8 verbatim).
  ;;
  ;; Each arm is a record (make_record tag=0, arity=3) with fields
  ;; {args, body, op_name} at indices 0/1/2 — ALPHABETICAL per Lock #8.
  ;; Read in lower/walk_handle.wat:317-319 via $record_get; parser
  ;; writes via $record_set under matching ordering.
  ;;
  ;; Reuse:
  ;;   - $parse_pat (parser_pat.wat) for arm args
  ;;   - $parse_expr (parser_expr.wat) for arm bodies + state init
  ;;   - $skip_ws_p / $expect / $at / $kind_at / $ident_at_p (parser_infra.wat)
  ;;   - $make_record / $record_set (runtime/record.wat)
  ;;   - $make_list / $list_set / $list_extend_to / $slice (runtime/list.wat)
  ;;
  ;; Drift modes refused at edit sites:
  ;;   - Drift 9 (deferred-by-omission): $skip_to_rbrace was the canonical
  ;;     instance. This chunk lands the parser whole. Resume-with-update
  ;;     post-body (`resume() with debt = ...`) is robustly absorbed by
  ;;     $skip_to_arm_terminator below — the seed does not lift it into
  ;;     AST yet (named follow-up Hβ.handler-arm-resume-with-update-substrate),
  ;;     but consumption is correct and total.
  ;;   - Drift 8 (string-keyed-when-structured): arm record uses positional
  ;;     i32 indices (record_set on tag-0 chunk-private record), NOT a
  ;;     string-keyed field-name map.
  ;;   - Drift 7 (parallel-arrays-instead-of-record): one record per arm
  ;;     with all three fields, NOT (op_names_list, args_list, bodies_list).
  ;;   - Drift 1 (rust vtable): arms_list IS a list of arm-records; downstream
  ;;     dispatch is by lower/walk_handle.wat's $lower_handler_arm_body, NOT
  ;;     a closure-as-vtable.

  ;; ─── $skip_to_arm_terminator ─────────────────────────────────────
  ;; Walks tokens at brace/paren/bracket-depth 0 until hitting `,` `}`
  ;; or EOF. Used after $parse_expr returns the arm body — if the wheel
  ;; produced a `resume() with debt = ...` clause that the seed's
  ;; $parse_expr does not yet absorb (TWith is not an operator), this
  ;; function steps past the trailing `with FIELD = EXPR ...` chunk
  ;; without descending into its sub-expressions. Per the named
  ;; follow-up Hβ.handler-arm-resume-with-update-substrate the seed
  ;; does not lift the update into AST yet; consumption is what matters
  ;; for first-light.
  (func $skip_to_arm_terminator (param $tokens i32) (param $pos i32) (result i32)
    (local $p i32) (local $depth i32) (local $k i32)
    (local.set $p     (local.get $pos))
    (local.set $depth (i32.const 0))
    (block $done
      (loop $skip
        (local.set $k (call $kind_at (local.get $tokens) (local.get $p)))
        ;; EOF → done
        (br_if $done (i32.eq (local.get $k) (i32.const 69)))
        ;; At depth 0, comma or `}` ends
        (if (i32.eqz (local.get $depth))
          (then
            (br_if $done (i32.eq (local.get $k) (i32.const 51)))   ;; TComma
            (br_if $done (i32.eq (local.get $k) (i32.const 48))))) ;; TRBrace
        ;; Track opens
        (if (i32.or
              (i32.or (i32.eq (local.get $k) (i32.const 47))   ;; TLBrace
                      (i32.eq (local.get $k) (i32.const 45)))  ;; TLParen
              (i32.eq (local.get $k) (i32.const 49)))          ;; TLBracket
          (then (local.set $depth (i32.add (local.get $depth) (i32.const 1)))))
        ;; Track closes
        (if (i32.or
              (i32.or (i32.eq (local.get $k) (i32.const 48))   ;; TRBrace
                      (i32.eq (local.get $k) (i32.const 46)))  ;; TRParen
              (i32.eq (local.get $k) (i32.const 50)))          ;; TRBracket
          (then (local.set $depth (i32.sub (local.get $depth) (i32.const 1)))))
        (local.set $p (i32.add (local.get $p) (i32.const 1)))
        (br $skip)))
    (local.get $p))

  ;; ─── $parse_handler_arm_args ─────────────────────────────────────
  ;; Comma-separated patterns inside `( )`. Empty `()` returns empty
  ;; list; otherwise loops $parse_pat / TComma / TRParen. Buffer-counter
  ;; substrate (Ω.3 — per CLAUDE.md "Bug classes that cost hours" —
  ;; refusal of `acc ++ [X]` O(N²) drift).
  (func $parse_handler_arm_args (param $tokens i32) (param $pos i32) (result i32)
    (local $p i32) (local $buf i32) (local $count i32)
    (local $pat_r i32) (local $pat i32) (local $p2 i32) (local $tup i32)
    ;; Expect TLParen
    (local.set $p (call $expect (local.get $tokens)
      (call $skip_ws_p (local.get $tokens) (local.get $pos))
      (i32.const 45)))  ;; TLParen
    (local.set $p (call $skip_ws_p (local.get $tokens) (local.get $p)))
    ;; Empty `()` → return empty list and advance past TRParen
    (if (call $at (local.get $tokens) (local.get $p) (i32.const 46))  ;; TRParen
      (then
        (local.set $tup (call $make_list (i32.const 2)))
        (drop (call $list_set (local.get $tup) (i32.const 0)
          (call $make_list (i32.const 0))))
        (drop (call $list_set (local.get $tup) (i32.const 1)
          (i32.add (local.get $p) (i32.const 1))))
        (return (local.get $tup))))
    (local.set $buf (call $make_list (i32.const 4)))
    (local.set $count (i32.const 0))
    (block $done
      (loop $args_loop
        ;; Parse one pattern
        (local.set $pat_r (call $parse_pat (local.get $tokens) (local.get $p)))
        (local.set $pat (call $list_index (local.get $pat_r) (i32.const 0)))
        (local.set $p2 (call $skip_ws_p (local.get $tokens)
          (call $list_index (local.get $pat_r) (i32.const 1))))
        ;; Append
        (local.set $buf (call $list_extend_to (local.get $buf)
          (i32.add (local.get $count) (i32.const 1))))
        (drop (call $list_set (local.get $buf) (local.get $count) (local.get $pat)))
        (local.set $count (i32.add (local.get $count) (i32.const 1)))
        ;; TComma → next; otherwise terminator (expect TRParen below)
        (if (call $at (local.get $tokens) (local.get $p2) (i32.const 51))  ;; TComma
          (then
            (local.set $p (call $skip_ws_p (local.get $tokens)
              (i32.add (local.get $p2) (i32.const 1))))
            (br $args_loop))
          (else
            (local.set $p (local.get $p2))
            (br $done)))))
    ;; Expect TRParen
    (local.set $p (call $expect (local.get $tokens) (local.get $p) (i32.const 46)))
    (local.set $tup (call $make_list (i32.const 2)))
    (drop (call $list_set (local.get $tup) (i32.const 0)
      (call $slice (local.get $buf) (i32.const 0) (local.get $count))))
    (drop (call $list_set (local.get $tup) (i32.const 1) (local.get $p)))
    (local.get $tup))

  ;; ─── $parse_handler_arm ──────────────────────────────────────────
  ;; OP_NAME(arg, ...) => BODY. Returns [arm_record, next_pos] where
  ;; arm_record = make_record(tag=0, arity=3) with {args, body, op_name}
  ;; at field indices 0/1/2. Body absorbed via $parse_expr; trailing
  ;; resume-with-update absorbed via $skip_to_arm_terminator.
  (func $parse_handler_arm (param $tokens i32) (param $pos i32) (result i32)
    (local $p i32) (local $op_name i32) (local $p2 i32)
    (local $args_r i32) (local $args i32) (local $p3 i32) (local $p4 i32)
    (local $body_r i32) (local $body i32) (local $p5 i32) (local $p6 i32)
    (local $arm i32) (local $tup i32)
    (local.set $p (call $skip_ws_p (local.get $tokens) (local.get $pos)))
    ;; Op name (TIdent)
    (local.set $op_name (call $ident_at_p (local.get $tokens) (local.get $p)))
    (local.set $p2 (i32.add (local.get $p) (i32.const 1)))
    ;; Args list inside parens
    (local.set $args_r (call $parse_handler_arm_args (local.get $tokens)
      (call $skip_ws_p (local.get $tokens) (local.get $p2))))
    (local.set $args (call $list_index (local.get $args_r) (i32.const 0)))
    (local.set $p3 (call $list_index (local.get $args_r) (i32.const 1)))
    ;; Expect TFatArrow
    (local.set $p4 (call $expect (local.get $tokens)
      (call $skip_ws_p (local.get $tokens) (local.get $p3))
      (i32.const 35)))  ;; TFatArrow
    ;; Parse body expression
    (local.set $body_r (call $parse_expr (local.get $tokens)
      (call $skip_ws_p (local.get $tokens) (local.get $p4))))
    (local.set $body (call $list_index (local.get $body_r) (i32.const 0)))
    (local.set $p5 (call $list_index (local.get $body_r) (i32.const 1)))
    ;; Absorb any trailing tokens before the arm terminator (e.g. the
    ;; resume-with-update form not yet lifted into parse_expr).
    (local.set $p6 (call $skip_to_arm_terminator (local.get $tokens) (local.get $p5)))
    ;; Build arm record (tag=0, arity=3, alphabetical {args, body, op_name})
    (local.set $arm (call $make_record (i32.const 0) (i32.const 3)))
    (call $record_set (local.get $arm) (i32.const 0) (local.get $args))
    (call $record_set (local.get $arm) (i32.const 1) (local.get $body))
    (call $record_set (local.get $arm) (i32.const 2) (local.get $op_name))
    ;; Return [arm_record, p6]
    (local.set $tup (call $make_list (i32.const 2)))
    (drop (call $list_set (local.get $tup) (i32.const 0) (local.get $arm)))
    (drop (call $list_set (local.get $tup) (i32.const 1) (local.get $p6)))
    (local.get $tup))

  ;; ─── $parse_handler_arms ─────────────────────────────────────────
  ;; Loops over arms until TRBrace (or TEof). Returns [arms_list,
  ;; pos_after_rbrace]. Mirror of parser_pat.wat $parse_match_arms_full
  ;; — same buffer-counter discipline.
  (func $parse_handler_arms (param $tokens i32) (param $pos i32) (result i32)
    (local $p i32) (local $buf i32) (local $count i32)
    (local $arm_r i32) (local $arm i32) (local $p2 i32) (local $p3 i32)
    (local $tup i32)
    (local.set $buf (call $make_list (i32.const 4)))
    (local.set $count (i32.const 0))
    (local.set $p (call $skip_ws_p (local.get $tokens) (local.get $pos)))
    (block $done
      (loop $arms_loop
        ;; Terminator: TRBrace consumes itself; TEof breaks without consume
        (if (call $at (local.get $tokens) (local.get $p) (i32.const 48))  ;; TRBrace
          (then
            (local.set $p (i32.add (local.get $p) (i32.const 1)))
            (br $done)))
        (if (call $at (local.get $tokens) (local.get $p) (i32.const 69))  ;; TEof
          (then (br $done)))
        ;; Parse one arm
        (local.set $arm_r (call $parse_handler_arm (local.get $tokens) (local.get $p)))
        (local.set $arm (call $list_index (local.get $arm_r) (i32.const 0)))
        (local.set $p2 (call $list_index (local.get $arm_r) (i32.const 1)))
        ;; Append
        (local.set $buf (call $list_extend_to (local.get $buf)
          (i32.add (local.get $count) (i32.const 1))))
        (drop (call $list_set (local.get $buf) (local.get $count) (local.get $arm)))
        (local.set $count (i32.add (local.get $count) (i32.const 1)))
        ;; Skip optional comma + whitespace before next arm
        (local.set $p3 (call $skip_ws_p (local.get $tokens) (local.get $p2)))
        (if (call $at (local.get $tokens) (local.get $p3) (i32.const 51))  ;; TComma
          (then (local.set $p3 (i32.add (local.get $p3) (i32.const 1)))))
        (local.set $p (call $skip_ws_p (local.get $tokens) (local.get $p3)))
        (br $arms_loop)))
    (local.set $tup (call $make_list (i32.const 2)))
    (drop (call $list_set (local.get $tup) (i32.const 0)
      (call $slice (local.get $buf) (i32.const 0) (local.get $count))))
    (drop (call $list_set (local.get $tup) (i32.const 1) (local.get $p)))
    (local.get $tup))

  ;; ─── $parse_handler_state ────────────────────────────────────────
  ;; Optional `with FIELD = EXPR [, FIELD = EXPR]*` clause. Returns
  ;; [state_fields_list, next_pos]. Each field is a 2-tuple
  ;; (name, init_expr). If no TWith, returns empty list with pos
  ;; unchanged. Loop terminates on the first non-comma token after
  ;; an init expr — `{` is the natural terminator and is checked by
  ;; the caller via $expect after this returns.
  (func $parse_handler_state (param $tokens i32) (param $pos i32) (result i32)
    (local $p i32) (local $buf i32) (local $count i32)
    (local $field_name i32) (local $p2 i32) (local $p3 i32)
    (local $init_r i32) (local $init_expr i32) (local $p4 i32)
    (local $field i32) (local $tup i32)
    (local.set $p (call $skip_ws_p (local.get $tokens) (local.get $pos)))
    ;; No TWith → empty state, pos unchanged
    (if (i32.eqz (call $at (local.get $tokens) (local.get $p) (i32.const 9)))  ;; TWith
      (then
        (local.set $tup (call $make_list (i32.const 2)))
        (drop (call $list_set (local.get $tup) (i32.const 0)
          (call $make_list (i32.const 0))))
        (drop (call $list_set (local.get $tup) (i32.const 1) (local.get $p)))
        (return (local.get $tup))))
    ;; Past TWith
    (local.set $p (call $skip_ws_p (local.get $tokens)
      (i32.add (local.get $p) (i32.const 1))))
    (local.set $buf (call $make_list (i32.const 4)))
    (local.set $count (i32.const 0))
    (block $done
      (loop $fields
        ;; Field name (TIdent)
        (local.set $field_name (call $ident_at_p (local.get $tokens) (local.get $p)))
        (local.set $p2 (i32.add (local.get $p) (i32.const 1)))
        ;; Expect TEq
        (local.set $p3 (call $expect (local.get $tokens)
          (call $skip_ws_p (local.get $tokens) (local.get $p2))
          (i32.const 60)))  ;; TEq
        ;; Init expression
        (local.set $init_r (call $parse_expr (local.get $tokens)
          (call $skip_ws_p (local.get $tokens) (local.get $p3))))
        (local.set $init_expr (call $list_index (local.get $init_r) (i32.const 0)))
        (local.set $p4 (call $skip_ws_p (local.get $tokens)
          (call $list_index (local.get $init_r) (i32.const 1))))
        ;; field 2-tuple (name, init_expr)
        (local.set $field (call $make_list (i32.const 2)))
        (drop (call $list_set (local.get $field) (i32.const 0) (local.get $field_name)))
        (drop (call $list_set (local.get $field) (i32.const 1) (local.get $init_expr)))
        ;; Append
        (local.set $buf (call $list_extend_to (local.get $buf)
          (i32.add (local.get $count) (i32.const 1))))
        (drop (call $list_set (local.get $buf) (local.get $count) (local.get $field)))
        (local.set $count (i32.add (local.get $count) (i32.const 1)))
        ;; Comma → another field; otherwise done (caller expects `{`)
        (if (call $at (local.get $tokens) (local.get $p4) (i32.const 51))  ;; TComma
          (then
            (local.set $p (call $skip_ws_p (local.get $tokens)
              (i32.add (local.get $p4) (i32.const 1))))
            (br $fields))
          (else
            (local.set $p (local.get $p4))
            (br $done)))))
    (local.set $tup (call $make_list (i32.const 2)))
    (drop (call $list_set (local.get $tup) (i32.const 0)
      (call $slice (local.get $buf) (i32.const 0) (local.get $count))))
    (drop (call $list_set (local.get $tup) (i32.const 1) (local.get $p)))
    (local.get $tup))

  ;; ─── $parse_handler_decl_full ────────────────────────────────────
  ;; Entry point invoked from parser_toplevel.wat $parse_stmt_p when
  ;; the leading token is THandler (kind 8). Returns the canonical
  ;; 2-tuple [stmt_node, next_pos] — same shape as the existing
  ;; let/fn/type/effect/import statement parsers in this layer.
  ;;
  ;; Position contract: $pos points AT THandler. pos+1 is the handler
  ;; name TIdent. pos+2 is past the name (matches $skip_to_rbrace
  ;; predecessor's offset assumption).
  (func $parse_handler_decl_full (param $tokens i32) (param $pos i32) (param $span i32) (result i32)
    (local $name i32) (local $p i32)
    (local $state_r i32) (local $state_fields i32) (local $p2 i32)
    (local $p3 i32) (local $arms_r i32) (local $arms i32) (local $p4 i32)
    (local $stmt i32) (local $tup i32)
    ;; Read handler name
    (local.set $name (call $ident_at_p (local.get $tokens)
      (i32.add (local.get $pos) (i32.const 1))))
    ;; Skip past name + ws
    (local.set $p (call $skip_ws_p (local.get $tokens)
      (i32.add (local.get $pos) (i32.const 2))))
    ;; Optional state
    (local.set $state_r (call $parse_handler_state (local.get $tokens) (local.get $p)))
    (local.set $state_fields (call $list_index (local.get $state_r) (i32.const 0)))
    (local.set $p2 (call $list_index (local.get $state_r) (i32.const 1)))
    ;; Expect TLBrace
    (local.set $p3 (call $expect (local.get $tokens)
      (call $skip_ws_p (local.get $tokens) (local.get $p2))
      (i32.const 47)))  ;; TLBrace
    ;; Arms until TRBrace
    (local.set $arms_r (call $parse_handler_arms (local.get $tokens)
      (call $skip_ws_p (local.get $tokens) (local.get $p3))))
    (local.set $arms (call $list_index (local.get $arms_r) (i32.const 0)))
    (local.set $p4 (call $list_index (local.get $arms_r) (i32.const 1)))
    ;; Build HandlerDeclStmt
    (local.set $stmt (call $mk_handler_decl_full
      (local.get $name)
      (call $str_alloc (i32.const 0))
      (local.get $state_fields)
      (local.get $arms)))
    ;; Return [nstmt, next_pos]
    (local.set $tup (call $make_list (i32.const 2)))
    (drop (call $list_set (local.get $tup) (i32.const 0)
      (call $nstmt (local.get $stmt) (local.get $span))))
    (drop (call $list_set (local.get $tup) (i32.const 1) (local.get $p4)))
    (local.get $tup))

  ;; ─── $mk_handler_decl_full ────────────────────────────────────────
  ;; HandlerDeclStmt: [tag=124][name][effect_name][arms][state_fields]
  ;; offsets 0/4/8/12/16. effect_name is the empty string at parse time;
  ;; infer's per-arm cascade fills in once the named follow-up
  ;; Hβ-infer-handler-decls-full lands. state_fields is a list of
  ;; (field_name, init_expr) 2-tuples; current infer/lower seed do not
  ;; consult offset 16 (named follow-up Hβ.handler-state-substrate).
  ;; Replaces the 1-arg $mk_handler_decl previously inlined at
  ;; parser_toplevel.wat:106-112; the new entry point lives here and the
  ;; old shell is deleted to refuse drift mode 9 (deferred-by-omission).
  (func $mk_handler_decl_full
        (param $name i32) (param $effect_name i32)
        (param $state_fields i32) (param $arms i32) (result i32)
    (local $p i32)
    (local.set $p (call $alloc (i32.const 20)))
    (i32.store         (local.get $p) (i32.const 124))
    (i32.store offset=4  (local.get $p) (local.get $name))
    (i32.store offset=8  (local.get $p) (local.get $effect_name))
    (i32.store offset=12 (local.get $p) (local.get $arms))
    (i32.store offset=16 (local.get $p) (local.get $state_fields))
    (local.get $p))
