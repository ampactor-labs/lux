  ;; ═══ Type Declaration Parser (Complete) ═════════════════════════════
  ;; Hand-transcribed from src/parser.nx lines 525-586.
  ;;
  ;; type Name = Variant1 | Variant2(Type1, Type2) | ...
  ;; Each variant: (name, field_types_list)

  (func $parse_type_stmt (param $tokens i32) (param $pos i32) (param $span i32) (result i32)
    (local $name i32) (local $p i32) (local $variants_r i32) (local $tup i32)
    (local $fields_r i32) (local $ty_record i32) (local $variant i32)
    (local $variants i32) (local $field_tys i32)
    (local.set $name (call $ident_at_p (local.get $tokens) (local.get $pos)))
    (local.set $p (call $skip_ws_p (local.get $tokens) (i32.add (local.get $pos) (i32.const 1))))
    ;; Skip =
    (if (call $at (local.get $tokens) (local.get $p) (i32.const 60)) ;; TEq
      (then (local.set $p (call $skip_ws_p (local.get $tokens) (i32.add (local.get $p) (i32.const 1))))))
    ;; Nominal record: type Name = {field: Ty, ...}
    (if (call $at (local.get $tokens) (local.get $p) (i32.const 47)) ;; TLBrace
      (then
        (local.set $fields_r (call $parse_record_type_fields
          (local.get $tokens)
          (call $skip_ws_p (local.get $tokens) (i32.add (local.get $p) (i32.const 1)))))
        (local.set $ty_record
          (call $mk_TyRecord (call $list_index (local.get $fields_r) (i32.const 0))))
        (local.set $field_tys (call $make_list (i32.const 1)))
        (drop (call $list_set (local.get $field_tys) (i32.const 0) (local.get $ty_record)))
        (local.set $variant (call $make_list (i32.const 2)))
        (drop (call $list_set (local.get $variant) (i32.const 0) (local.get $name)))
        (drop (call $list_set (local.get $variant) (i32.const 1) (local.get $field_tys)))
        (local.set $variants (call $make_list (i32.const 1)))
        (drop (call $list_set (local.get $variants) (i32.const 0) (local.get $variant)))
        (local.set $tup (call $make_list (i32.const 2)))
        (drop (call $list_set (local.get $tup) (i32.const 0)
          (call $nstmt
            (call $mk_TypeDefStmt (local.get $name)
              (call $make_list (i32.const 0))
              (local.get $variants))
            (local.get $span))))
        (drop (call $list_set (local.get $tup) (i32.const 1)
          (call $list_index (local.get $fields_r) (i32.const 1))))
        (return (local.get $tup))))
    ;; Parse variants
    (local.set $variants_r (call $parse_variants (local.get $tokens) (local.get $p)))
    ;; Skip optional `where <predicate>` per SYNTAX.md §1216-1233.
    ;; Per Hβ.first-light.refine-predicate-parser (named follow-up):
    ;; the predicate ADT + verify-emit substrate is the substrate-
    ;; honest landing. Until that handle lands, the seed pragmatically
    ;; consumes the where-clause tokens so they don't bleed into the
    ;; next-statement parser (where they'd surface as
    ;; E_MissingVariable: self). The refinement predicate is dropped
    ;; at the parser layer; downstream compilation proceeds.
    ;;
    ;; Eight interrogations per edit site:
    ;;  1. Graph?   Refinement predicate is metadata at graph layer
    ;;              — the type alias is what's bound (without the
    ;;              where clause).
    ;;  2. Handler? @resume=OneShot direct parse.
    ;;  3. Verb?    N/A.
    ;;  4. Row?     Pure parse.
    ;;  5. Ownership? Tokens borrowed.
    ;;  6. Refinement? PRAGMATICALLY DEFERRED to the named follow-up.
    ;;              Substrate-honest tag: this is drift-9-safe because
    ;;              the named handle Hβ.first-light.refine-predicate-
    ;;              parser will replace this skip with full predicate
    ;;              parsing + Verify-emit obligation per src/infer.nx
    ;;              wheel canonical (RefineStmt arm at line 261-266).
    ;;  7. Gradient? Skipping the predicate doesn't unlock capability
    ;;              today; the named follow-up wires Verify so adding
    ;;              `where p` becomes a gradient annotation.
    ;;  8. Reason?  Predicate-source span available at the where token's
    ;;              position; named follow-up threads it as DeclaredAt.
    (local.set $p (call $list_index (local.get $variants_r) (i32.const 1)))
    (local.set $p (call $skip_ws_p (local.get $tokens) (local.get $p)))
    (if (call $at (local.get $tokens) (local.get $p) (i32.const 19)) ;; TWhere
      (then
        (local.set $p (call $skip_predicate_to_stmt_end
                            (local.get $tokens)
                            (i32.add (local.get $p) (i32.const 1))))))
    (local.set $tup (call $make_list (i32.const 2)))
    (drop (call $list_set (local.get $tup) (i32.const 0)
      (call $nstmt
        (call $mk_TypeDefStmt (local.get $name)
          (call $make_list (i32.const 0))
          (call $list_index (local.get $variants_r) (i32.const 0)))
        (local.get $span))))
    (drop (call $list_set (local.get $tup) (i32.const 1) (local.get $p)))
    (local.get $tup))

  ;; Skip tokens until the next statement boundary — newline, EOF, or
  ;; a top-level declaration keyword (TFn, TLet, TType, TEffect,
  ;; THandler, TImport). Used by the where-clause parser
  ;; until the named follow-up Hβ.first-light.refine-predicate-parser
  ;; lands the full predicate ADT.
  (func $skip_predicate_to_stmt_end (param $tokens i32) (param $pos i32) (result i32)
    (local $k i32)
    (block $done (loop $scan
      (local.set $k (call $kind_at (local.get $tokens) (local.get $pos)))
      (br_if $done (i32.eq (local.get $k) (i32.const 68)))   ;; TNewline
      (br_if $done (i32.eq (local.get $k) (i32.const 69)))   ;; TEof
      (br_if $done (i32.eq (local.get $k) (i32.const 0)))    ;; TFn
      (br_if $done (i32.eq (local.get $k) (i32.const 1)))    ;; TLet
      (br_if $done (i32.eq (local.get $k) (i32.const 5)))    ;; TType
      (br_if $done (i32.eq (local.get $k) (i32.const 6)))    ;; TEffect
      (br_if $done (i32.eq (local.get $k) (i32.const 8)))    ;; THandler
      (br_if $done (i32.eq (local.get $k) (i32.const 18)))   ;; TImport
      (local.set $pos (i32.add (local.get $pos) (i32.const 1)))
      (br $scan)))
    (local.get $pos))

  ;; parse_record_type_fields: field-name/type pairs until RBrace.
  ;; Returns (fields_list, new_pos). Each field is a 2-tuple (name, Ty).
  (func $parse_record_type_fields (param $tokens i32) (param $pos i32) (result i32)
    (local $p i32) (local $buf i32) (local $count i32)
    (local $name i32) (local $p2 i32) (local $ty_r i32)
    (local $ty i32) (local $p3 i32) (local $field i32) (local $tup i32)
    (local.set $p (call $skip_ws_p (local.get $tokens) (local.get $pos)))
    (if (call $at (local.get $tokens) (local.get $p) (i32.const 48)) ;; TRBrace
      (then
        (local.set $tup (call $make_list (i32.const 2)))
        (drop (call $list_set (local.get $tup) (i32.const 0) (call $make_list (i32.const 0))))
        (drop (call $list_set (local.get $tup) (i32.const 1) (i32.add (local.get $p) (i32.const 1))))
        (return (local.get $tup))))
    (local.set $buf (call $make_list (i32.const 4)))
    (local.set $count (i32.const 0))
    (block $done
      (loop $fields
        (local.set $name (call $ident_at_p (local.get $tokens) (local.get $p)))
        (local.set $p2 (call $expect
          (local.get $tokens)
          (call $skip_ws_p (local.get $tokens) (i32.add (local.get $p) (i32.const 1)))
          (i32.const 53))) ;; TColon
        (local.set $ty_r (call $parse_type_ty
          (local.get $tokens)
          (call $skip_ws_p (local.get $tokens) (local.get $p2))))
        (local.set $ty (call $list_index (local.get $ty_r) (i32.const 0)))
        (local.set $p3 (call $skip_ws_p (local.get $tokens)
          (call $list_index (local.get $ty_r) (i32.const 1))))
        (local.set $field (call $make_list (i32.const 2)))
        (drop (call $list_set (local.get $field) (i32.const 0) (local.get $name)))
        (drop (call $list_set (local.get $field) (i32.const 1) (local.get $ty)))
        (local.set $buf (call $list_extend_to (local.get $buf)
          (i32.add (local.get $count) (i32.const 1))))
        (drop (call $list_set (local.get $buf) (local.get $count) (local.get $field)))
        (local.set $count (i32.add (local.get $count) (i32.const 1)))
        (if (call $at (local.get $tokens) (local.get $p3) (i32.const 51)) ;; TComma
          (then
            (local.set $p (call $skip_ws_p
              (local.get $tokens) (i32.add (local.get $p3) (i32.const 1))))
            (if (call $at (local.get $tokens) (local.get $p) (i32.const 48))
              (then
                (local.set $p (i32.add (local.get $p) (i32.const 1)))
                (br $done)))
            (br $fields))
          (else
            (local.set $p (call $expect (local.get $tokens) (local.get $p3) (i32.const 48)))
            (br $done)))))
    (local.set $tup (call $make_list (i32.const 2)))
    (drop (call $list_set (local.get $tup) (i32.const 0)
      (call $slice (local.get $buf) (i32.const 0) (local.get $count))))
    (drop (call $list_set (local.get $tup) (i32.const 1) (local.get $p)))
    (local.get $tup))

  ;; parse_variants: V1 | V2(T1, T2) | ...
  ;; Returns (variants_list, new_pos). Each variant is a 2-tuple (name, field_types).

  (func $parse_variants (param $tokens i32) (param $pos i32) (result i32)
    (local $p i32) (local $vname i32) (local $p2 i32)
    (local $fields_r i32) (local $fields i32) (local $p3 i32)
    (local $variant i32) (local $p4 i32) (local $rest_r i32)
    (local $buf i32) (local $count i32) (local $tup i32)
    (local.set $buf (call $make_list (i32.const 4)))
    (local.set $count (i32.const 0))
    (local.set $p (call $skip_ws_p (local.get $tokens) (local.get $pos)))
    (block $done
      (loop $vars
        ;; Get variant name (must be identifier)
        (if (i32.or
              (call $at (local.get $tokens) (local.get $p) (i32.const 69))  ;; TEof
              (call $at (local.get $tokens) (local.get $p) (i32.const 68))) ;; TNewline
          (then (br $done)))
        ;; Check it's actually an ident
        (local.set $vname (call $ident_at_p (local.get $tokens) (local.get $p)))
        (if (i32.eqz (call $str_len (local.get $vname)))
          (then (br $done)))
        (local.set $p2 (i32.add (local.get $p) (i32.const 1)))
        ;; Check for (fields)
        (if (call $at (local.get $tokens) (local.get $p2) (i32.const 45)) ;; TLParen
          (then
            (local.set $fields_r (call $parse_variant_fields (local.get $tokens)
              (call $skip_ws_p (local.get $tokens) (i32.add (local.get $p2) (i32.const 1)))))
            (local.set $fields (call $list_index (local.get $fields_r) (i32.const 0)))
            (local.set $p3 (call $list_index (local.get $fields_r) (i32.const 1))))
          (else
            (local.set $fields (call $make_list (i32.const 0)))
            (local.set $p3 (local.get $p2))))
        ;; Build variant tuple (name, fields)
        (local.set $variant (call $make_list (i32.const 2)))
        (drop (call $list_set (local.get $variant) (i32.const 0) (local.get $vname)))
        (drop (call $list_set (local.get $variant) (i32.const 1) (local.get $fields)))
        ;; Append
        (local.set $buf (call $list_extend_to (local.get $buf)
          (i32.add (local.get $count) (i32.const 1))))
        (drop (call $list_set (local.get $buf) (local.get $count) (local.get $variant)))
        (local.set $count (i32.add (local.get $count) (i32.const 1)))
        ;; Check for | separator
        (local.set $p4 (call $skip_ws_p (local.get $tokens) (local.get $p3)))
        (if (call $at (local.get $tokens) (local.get $p4) (i32.const 64)) ;; TPipe
          (then
            (local.set $p (call $skip_ws_p (local.get $tokens) (i32.add (local.get $p4) (i32.const 1))))
            (br $vars))
          (else
            (local.set $p (local.get $p4))
            (br $done)))))
    (local.set $tup (call $make_list (i32.const 2)))
    (drop (call $list_set (local.get $tup) (i32.const 0)
      (call $slice (local.get $buf) (i32.const 0) (local.get $count))))
    (drop (call $list_set (local.get $tup) (i32.const 1) (local.get $p)))
    (local.get $tup))

  ;; parse_variant_fields: comma-sep type expressions until RParen
  (func $parse_variant_fields (param $tokens i32) (param $pos i32) (result i32)
    (local $p i32) (local $buf i32) (local $count i32)
    (local $ty_r i32) (local $ty i32) (local $p2 i32) (local $p3 i32) (local $tup i32)
    (local.set $p (call $skip_ws_p (local.get $tokens) (local.get $pos)))
    (if (call $at (local.get $tokens) (local.get $p) (i32.const 46)) ;; TRParen
      (then
        (local.set $tup (call $make_list (i32.const 2)))
        (drop (call $list_set (local.get $tup) (i32.const 0) (call $make_list (i32.const 0))))
        (drop (call $list_set (local.get $tup) (i32.const 1) (i32.add (local.get $p) (i32.const 1))))
        (return (local.get $tup))))
    (local.set $buf (call $make_list (i32.const 4)))
    (local.set $count (i32.const 0))
    (block $done
      (loop $fields
        (local.set $ty_r (call $parse_type_ty (local.get $tokens) (local.get $p)))
        (local.set $ty (call $list_index (local.get $ty_r) (i32.const 0)))
        (local.set $p2 (call $list_index (local.get $ty_r) (i32.const 1)))
        (local.set $buf (call $list_extend_to (local.get $buf)
          (i32.add (local.get $count) (i32.const 1))))
        (drop (call $list_set (local.get $buf) (local.get $count) (local.get $ty)))
        (local.set $count (i32.add (local.get $count) (i32.const 1)))
        (local.set $p3 (call $skip_ws_p (local.get $tokens) (local.get $p2)))
        (if (call $at (local.get $tokens) (local.get $p3) (i32.const 51)) ;; TComma
          (then
            (local.set $p (call $skip_ws_p (local.get $tokens) (i32.add (local.get $p3) (i32.const 1))))
            (br $fields))
          (else
            (local.set $p (call $expect (local.get $tokens) (local.get $p3) (i32.const 46)))
            (br $done)))))
    (local.set $tup (call $make_list (i32.const 2)))
    (drop (call $list_set (local.get $tup) (i32.const 0)
      (call $slice (local.get $buf) (i32.const 0) (local.get $count))))
    (drop (call $list_set (local.get $tup) (i32.const 1) (local.get $p)))
    (local.get $tup))

  ;; ═══ Effect Declaration Parser (Complete) ══════════════════════════
  ;; effect Name { op(Type) -> RetType, ... }

  (func $parse_effect_stmt (param $tokens i32) (param $pos i32) (param $span i32) (result i32)
    (local $name i32) (local $p i32) (local $ops_r i32) (local $tup i32)
    (local.set $name (call $ident_at_p (local.get $tokens) (local.get $pos)))
    (local.set $p (call $skip_ws_p (local.get $tokens) (i32.add (local.get $pos) (i32.const 1))))
    (local.set $p (call $expect (local.get $tokens) (local.get $p) (i32.const 47))) ;; TLBrace
    (local.set $ops_r (call $parse_effect_ops (local.get $tokens)
      (call $skip_ws_p (local.get $tokens) (local.get $p))))
    (local.set $tup (call $make_list (i32.const 2)))
    (drop (call $list_set (local.get $tup) (i32.const 0)
      (call $nstmt
        (call $mk_EffectDeclStmt (local.get $name)
          (call $list_index (local.get $ops_r) (i32.const 0)))
        (local.get $span))))
    (drop (call $list_set (local.get $tup) (i32.const 1)
      (call $list_index (local.get $ops_r) (i32.const 1))))
    (local.get $tup))

  ;; parse_effect_ops: op(params) -> ret, ... until }
  ;; Each op is a 3-tuple (name, param_types, ret_type).

  (func $parse_effect_ops (param $tokens i32) (param $pos i32) (result i32)
    (local $p i32) (local $buf i32) (local $count i32) (local $op_name i32)
    (local $p2 i32) (local $params_r i32) (local $params i32) (local $p3 i32)
    (local $ret_r i32) (local $ret_ty i32) (local $p4 i32) (local $op i32)
    (local $tup i32)
    (local.set $buf (call $make_list (i32.const 4)))
    (local.set $count (i32.const 0))
    (local.set $p (call $skip_ws_p (local.get $tokens) (local.get $pos)))
    (block $done
      (loop $ops
        ;; Check } or EOF
        (if (i32.or
              (call $at (local.get $tokens) (local.get $p) (i32.const 48))  ;; TRBrace
              (call $at (local.get $tokens) (local.get $p) (i32.const 69))) ;; TEof
          (then
            (local.set $p (i32.add (local.get $p) (i32.const 1)))
            (br $done)))
        ;; Op name
        (local.set $op_name (call $ident_at_p (local.get $tokens) (local.get $p)))
        (if (i32.eqz (call $str_len (local.get $op_name)))
          (then
            (local.set $p (i32.add (local.get $p) (i32.const 1)))
            (local.set $p (call $skip_sep (local.get $tokens) (local.get $p)))
            (br $ops)))
        ;; Parse (param types)
        (local.set $p2 (call $expect (local.get $tokens)
          (call $skip_ws_p (local.get $tokens) (i32.add (local.get $p) (i32.const 1)))
          (i32.const 45))) ;; TLParen
        (local.set $params_r (call $parse_op_param_types (local.get $tokens)
          (call $skip_ws_p (local.get $tokens) (local.get $p2))))
        (local.set $params (call $list_index (local.get $params_r) (i32.const 0)))
        (local.set $p3 (call $skip_ws_p (local.get $tokens)
          (call $list_index (local.get $params_r) (i32.const 1))))
        ;; Optional -> return type
        (if (call $at (local.get $tokens) (local.get $p3) (i32.const 34)) ;; TArrow
          (then
            (local.set $ret_r (call $parse_type_ty (local.get $tokens)
              (call $skip_ws_p (local.get $tokens) (i32.add (local.get $p3) (i32.const 1)))))
            (local.set $ret_ty (call $list_index (local.get $ret_r) (i32.const 0)))
            (local.set $p4 (call $list_index (local.get $ret_r) (i32.const 1))))
          (else
            (local.set $ret_ty (i32.const 204)) ;; TyUnit
            (local.set $p4 (local.get $p3))))
        ;; Build op 3-tuple (name, params, ret)
        (local.set $op (call $make_list (i32.const 3)))
        (drop (call $list_set (local.get $op) (i32.const 0) (local.get $op_name)))
        (drop (call $list_set (local.get $op) (i32.const 1) (local.get $params)))
        (drop (call $list_set (local.get $op) (i32.const 2) (local.get $ret_ty)))
        ;; Append
        (local.set $buf (call $list_extend_to (local.get $buf)
          (i32.add (local.get $count) (i32.const 1))))
        (drop (call $list_set (local.get $buf) (local.get $count) (local.get $op)))
        (local.set $count (i32.add (local.get $count) (i32.const 1)))
        ;; Optional @resume=<discipline> annotation per SUBSTRATE.md §IV
        ;; (one of OneShot / MultiShot / Either). Skipped at parse time;
        ;; the ResumeDiscipline is encoded into the op's TFun row at the
        ;; named follow-up Hβ.first-light.effect-op-resume-discipline-substrate
        ;; — for the seed's first-light surface, the row is computed from
        ;; the body, not the annotation.
        (local.set $p4 (call $skip_annotation_to_eol
                         (local.get $tokens)
                         (call $skip_ws_p (local.get $tokens) (local.get $p4))))
        ;; Skip separators
        (local.set $p (call $skip_sep (local.get $tokens) (local.get $p4)))
        (br $ops)))
    (local.set $tup (call $make_list (i32.const 2)))
    (drop (call $list_set (local.get $tup) (i32.const 0)
      (call $slice (local.get $buf) (i32.const 0) (local.get $count))))
    (drop (call $list_set (local.get $tup) (i32.const 1) (local.get $p)))
    (local.get $tup))

  ;; skip_annotation_to_eol: if pos is at TAt, advance past every token
  ;; up to and including the next newline. The wheel's `@resume=<value>`
  ;; annotation on effect ops sits on the same source line as the op's
  ;; signature; the seed first-light surface skips the annotation
  ;; entirely. If pos is not at TAt, returns pos unchanged.
  (func $skip_annotation_to_eol (param $tokens i32) (param $pos i32) (result i32)
    (local $p i32) (local $k i32)
    (local.set $p (local.get $pos))
    (if (i32.eqz (call $at (local.get $tokens) (local.get $p) (i32.const 66)))  ;; TAt
      (then (return (local.get $p))))
    (block $done
      (loop $scan
        (local.set $k (call $kind_at (local.get $tokens) (local.get $p)))
        (br_if $done (i32.eq (local.get $k) (i32.const 68)))   ;; TNewline → leave for skip_sep
        (br_if $done (i32.eq (local.get $k) (i32.const 69)))   ;; TEof
        (br_if $done (i32.eq (local.get $k) (i32.const 48)))   ;; TRBrace → end of effect body
        (local.set $p (i32.add (local.get $p) (i32.const 1)))
        (br $scan)))
    (local.get $p))

  ;; parse_op_param_types: comma-sep types until RParen
  (func $parse_op_param_types (param $tokens i32) (param $pos i32) (result i32)
    (local $p i32) (local $buf i32) (local $count i32)
    (local $ty_r i32) (local $ty i32) (local $p2 i32) (local $p3 i32) (local $tup i32)
    (local.set $p (call $skip_ws_p (local.get $tokens) (local.get $pos)))
    (if (call $at (local.get $tokens) (local.get $p) (i32.const 46)) ;; TRParen
      (then
        (local.set $tup (call $make_list (i32.const 2)))
        (drop (call $list_set (local.get $tup) (i32.const 0) (call $make_list (i32.const 0))))
        (drop (call $list_set (local.get $tup) (i32.const 1) (i32.add (local.get $p) (i32.const 1))))
        (return (local.get $tup))))
    (local.set $buf (call $make_list (i32.const 4)))
    (local.set $count (i32.const 0))
    (block $done
      (loop $types
        ;; Optional `name : ` prefix per SYNTAX.md: effect-op params take
        ;; `name: Type` form (`load_i32(addr: Int) -> Int`). The seed
        ;; scans past TIdent + TColon when both present so $parse_type_ty
        ;; lands on the type position; otherwise the bare-type form
        ;; `load_i32(Int) -> Int` still parses unchanged. Refuses
        ;; drift mode 9 (deferred-by-omission) on the named-param surface
        ;; that the wheel's Memory + Alloc effects rely on.
        (if (i32.and
              (i32.eq (call $kind_at (local.get $tokens) (local.get $p))
                      (i32.const 25))   ;; TIdent
              (i32.eq (call $kind_at (local.get $tokens)
                        (i32.add (local.get $p) (i32.const 1)))
                      (i32.const 53)))  ;; TColon
          (then
            (local.set $p (call $skip_ws_p (local.get $tokens)
              (i32.add (local.get $p) (i32.const 2))))))
        (local.set $ty_r (call $parse_type_ty (local.get $tokens) (local.get $p)))
        (local.set $ty (call $list_index (local.get $ty_r) (i32.const 0)))
        (local.set $p2 (call $list_index (local.get $ty_r) (i32.const 1)))
        (local.set $buf (call $list_extend_to (local.get $buf)
          (i32.add (local.get $count) (i32.const 1))))
        (drop (call $list_set (local.get $buf) (local.get $count) (local.get $ty)))
        (local.set $count (i32.add (local.get $count) (i32.const 1)))
        (local.set $p3 (call $skip_ws_p (local.get $tokens) (local.get $p2)))
        (if (call $at (local.get $tokens) (local.get $p3) (i32.const 51)) ;; TComma
          (then
            (local.set $p (call $skip_ws_p (local.get $tokens) (i32.add (local.get $p3) (i32.const 1))))
            (br $types))
          (else
            (local.set $p (call $expect (local.get $tokens) (local.get $p3) (i32.const 46)))
            (br $done)))))
    (local.set $tup (call $make_list (i32.const 2)))
    (drop (call $list_set (local.get $tup) (i32.const 0)
      (call $slice (local.get $buf) (i32.const 0) (local.get $count))))
    (drop (call $list_set (local.get $tup) (i32.const 1) (local.get $p)))
    (local.get $tup))
