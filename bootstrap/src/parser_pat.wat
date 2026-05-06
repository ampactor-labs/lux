  ;; ═══ Pattern Parsing ═══════════════════════════════════════════════
  ;; Hand-transcribed from src/parser.mn lines 1196-1294.
  ;;
  ;; Pattern ADT (from src/types.mn):
  ;;   PVar(name)          → [tag=130][name_ptr]
  ;;   PWild               → sentinel 131
  ;;   PLit(lit_val)       → [tag=132][lit_val]
  ;;   PCon(ctor, sub)     → [tag=133][ctor_name][sub_pats_list]
  ;;   PTuple(sub)         → [tag=134][sub_pats_list]
  ;;   PList(sub)          → [tag=135][sub_pats_list]
  ;;   PRecord(fields)     → [tag=136][fields_list]
  ;;
  ;; LitVal ADT:
  ;;   LVInt(n)            → [tag=180][n]
  ;;   LVFloat(f)          → [tag=181][f]
  ;;   LVString(s)         → [tag=182][s]
  ;;   LVBool(b)           → [tag=183][0|1]
  ;;
  ;; Returns (pat, new_pos) as 2-tuple.
  ;;
  ;; Dispatch per src/parser.mn parse_pat:
  ;;   TIdent("_")         → PWild
  ;;   TIdent(v) caps      → PCon(v, sub_pats) if followed by (
  ;;                        → PCon(v, [])       if not
  ;;   TIdent(v) lower     → PVar(v)
  ;;   TInt(n)             → PLit(LVInt(n))
  ;;   TString(s)          → PLit(LVString(s))
  ;;   TTrue               → PLit(LVBool(true))
  ;;   TFalse              → PLit(LVBool(false))
  ;;   TLParen             → PTuple(sub_pats)
  ;;   TLBracket           → PList(sub_pats)
  ;;   TLBrace             → PRecord(fields)
  ;;   _                   → PWild (error recovery)

  ;; LitVal constructors
  (func $mk_LVInt (param $n i32) (result i32)
    (local $p i32) (local.set $p (call $alloc (i32.const 8)))
    (i32.store (local.get $p) (i32.const 180))
    (i32.store offset=4 (local.get $p) (local.get $n))
    (local.get $p))

  (func $mk_LVFloat (param $s i32) (result i32)
    (local $p i32) (local.set $p (call $alloc (i32.const 8)))
    (i32.store (local.get $p) (i32.const 181))
    (i32.store offset=4 (local.get $p) (local.get $s))
    (local.get $p))

  (func $mk_LVString (param $s i32) (result i32)
    (local $p i32) (local.set $p (call $alloc (i32.const 8)))
    (i32.store (local.get $p) (i32.const 182))
    (i32.store offset=4 (local.get $p) (local.get $s))
    (local.get $p))

  (func $mk_LVBool (param $b i32) (result i32)
    (local $p i32) (local.set $p (call $alloc (i32.const 8)))
    (i32.store (local.get $p) (i32.const 183))
    (i32.store offset=4 (local.get $p) (local.get $b))
    (local.get $p))

  ;; Pattern constructors
  (func $mk_PVar (param $name i32) (result i32)
    (local $p i32) (local.set $p (call $alloc (i32.const 8)))
    (i32.store (local.get $p) (i32.const 130))
    (i32.store offset=4 (local.get $p) (local.get $name))
    (local.get $p))

  (func $mk_PLit (param $lit i32) (result i32)
    (local $p i32) (local.set $p (call $alloc (i32.const 8)))
    (i32.store (local.get $p) (i32.const 132))
    (i32.store offset=4 (local.get $p) (local.get $lit))
    (local.get $p))

  (func $mk_PCon (param $name i32) (param $subs i32) (result i32)
    (local $p i32) (local.set $p (call $alloc (i32.const 12)))
    (i32.store (local.get $p) (i32.const 133))
    (i32.store offset=4 (local.get $p) (local.get $name))
    (i32.store offset=8 (local.get $p) (local.get $subs))
    (local.get $p))

  (func $mk_PTuple (param $subs i32) (result i32)
    (local $p i32) (local.set $p (call $alloc (i32.const 8)))
    (i32.store (local.get $p) (i32.const 134))
    (i32.store offset=4 (local.get $p) (local.get $subs))
    (local.get $p))

  (func $mk_PList (param $subs i32) (result i32)
    (local $p i32) (local.set $p (call $alloc (i32.const 8)))
    (i32.store (local.get $p) (i32.const 135))
    (i32.store offset=4 (local.get $p) (local.get $subs))
    (local.get $p))

  ;; first_char_code: get first byte of a string (0 if empty)
  ;; Used to distinguish Capitalized (constructor) vs lowercase (variable)
  (func $first_char_code (param $s i32) (result i32)
    (if (result i32) (i32.eqz (call $str_len (local.get $s)))
      (then (i32.const 0))
      (else (call $byte_at (local.get $s) (i32.const 0)))))

  ;; is_uppercase: 65 <= c <= 90
  (func $is_uppercase (param $c i32) (result i32)
    (i32.and (i32.ge_u (local.get $c) (i32.const 65))
             (i32.le_u (local.get $c) (i32.const 90))))

  ;; ─── parse_pat ────────────────────────────────────────────────────
  ;; Returns (pat, new_pos) as 2-tuple

  (func $parse_pat (param $tokens i32) (param $pos i32) (result i32)
    (local $k i32) (local $tup i32) (local $name i32) (local $fc i32)
    (local $subs_r i32) (local $subs i32) (local $p i32)
    (local.set $k (call $kind_at (local.get $tokens) (local.get $pos)))

    ;; ── Sentinel kinds ──
    (if (call $is_sentinel (local.get $k))
      (then
        ;; TTrue (23) → PLit(LVBool(true))
        (if (i32.eq (local.get $k) (i32.const 23))
          (then
            (local.set $tup (call $make_list (i32.const 2)))
            (drop (call $list_set (local.get $tup) (i32.const 0)
              (call $mk_PLit (call $mk_LVBool (i32.const 1)))))
            (drop (call $list_set (local.get $tup) (i32.const 1)
              (i32.add (local.get $pos) (i32.const 1))))
            (return (local.get $tup))))

        ;; TFalse (24) → PLit(LVBool(false))
        (if (i32.eq (local.get $k) (i32.const 24))
          (then
            (local.set $tup (call $make_list (i32.const 2)))
            (drop (call $list_set (local.get $tup) (i32.const 0)
              (call $mk_PLit (call $mk_LVBool (i32.const 0)))))
            (drop (call $list_set (local.get $tup) (i32.const 1)
              (i32.add (local.get $pos) (i32.const 1))))
            (return (local.get $tup))))

        ;; TLParen (45) → PTuple(sub_pats)
        (if (i32.eq (local.get $k) (i32.const 45))
          (then
            (local.set $subs_r (call $parse_pat_args
              (local.get $tokens)
              (call $skip_ws_p (local.get $tokens) (i32.add (local.get $pos) (i32.const 1)))))
            (local.set $tup (call $make_list (i32.const 2)))
            (drop (call $list_set (local.get $tup) (i32.const 0)
              (call $mk_PTuple (call $list_index (local.get $subs_r) (i32.const 0)))))
            (drop (call $list_set (local.get $tup) (i32.const 1)
              (call $list_index (local.get $subs_r) (i32.const 1))))
            (return (local.get $tup))))

        ;; TLBracket (49) → PList(sub_pats)
        (if (i32.eq (local.get $k) (i32.const 49))
          (then
            (local.set $subs_r (call $parse_pat_list_args
              (local.get $tokens)
              (call $skip_ws_p (local.get $tokens) (i32.add (local.get $pos) (i32.const 1)))))
            (local.set $tup (call $make_list (i32.const 2)))
            (drop (call $list_set (local.get $tup) (i32.const 0)
              (call $mk_PList (call $list_index (local.get $subs_r) (i32.const 0)))))
            (drop (call $list_set (local.get $tup) (i32.const 1)
              (call $list_index (local.get $subs_r) (i32.const 1))))
            (return (local.get $tup))))

        ;; Default sentinel → PWild (skip token)
        (local.set $tup (call $make_list (i32.const 2)))
        (drop (call $list_set (local.get $tup) (i32.const 0) (i32.const 131)))
        (drop (call $list_set (local.get $tup) (i32.const 1)
          (i32.add (local.get $pos) (i32.const 1))))
        (return (local.get $tup))))

    ;; ── Fielded kinds ──
    ;; TIdent (tag=25)
    (if (i32.eq (call $tag_of (local.get $k)) (i32.const 25))
      (then
        (local.set $name (i32.load offset=4 (local.get $k)))
        ;; Check for "_" → PWild
        (if (i32.and
              (i32.eq (call $str_len (local.get $name)) (i32.const 1))
              (i32.eq (call $byte_at (local.get $name) (i32.const 0)) (i32.const 95)))
          (then
            (local.set $tup (call $make_list (i32.const 2)))
            (drop (call $list_set (local.get $tup) (i32.const 0) (i32.const 131)))
            (drop (call $list_set (local.get $tup) (i32.const 1)
              (i32.add (local.get $pos) (i32.const 1))))
            (return (local.get $tup))))
        ;; Check capitalized → constructor pattern
        (local.set $fc (call $first_char_code (local.get $name)))
        (if (call $is_uppercase (local.get $fc))
          (then
            (local.set $p (i32.add (local.get $pos) (i32.const 1)))
            ;; Check for ( → PCon with sub-patterns
            (if (call $at (local.get $tokens) (local.get $p) (i32.const 45))
              (then
                (local.set $subs_r (call $parse_pat_args
                  (local.get $tokens)
                  (call $skip_ws_p (local.get $tokens) (i32.add (local.get $p) (i32.const 1)))))
                (local.set $tup (call $make_list (i32.const 2)))
                (drop (call $list_set (local.get $tup) (i32.const 0)
                  (call $mk_PCon (local.get $name)
                    (call $list_index (local.get $subs_r) (i32.const 0)))))
                (drop (call $list_set (local.get $tup) (i32.const 1)
                  (call $list_index (local.get $subs_r) (i32.const 1))))
                (return (local.get $tup)))
              (else
                ;; Nullary constructor: PCon(name, [])
                (local.set $tup (call $make_list (i32.const 2)))
                (drop (call $list_set (local.get $tup) (i32.const 0)
                  (call $mk_PCon (local.get $name) (call $make_list (i32.const 0)))))
                (drop (call $list_set (local.get $tup) (i32.const 1) (local.get $p)))
                (return (local.get $tup)))))
          (else
            ;; Lowercase → PVar(name)
            (local.set $tup (call $make_list (i32.const 2)))
            (drop (call $list_set (local.get $tup) (i32.const 0)
              (call $mk_PVar (local.get $name))))
            (drop (call $list_set (local.get $tup) (i32.const 1)
              (i32.add (local.get $pos) (i32.const 1))))
            (return (local.get $tup))))))

    ;; TInt (tag=26) → PLit(LVInt(n))
    (if (i32.eq (call $tag_of (local.get $k)) (i32.const 26))
      (then
        (local.set $tup (call $make_list (i32.const 2)))
        (drop (call $list_set (local.get $tup) (i32.const 0)
          (call $mk_PLit (call $mk_LVInt (i32.load offset=4 (local.get $k))))))
        (drop (call $list_set (local.get $tup) (i32.const 1)
          (i32.add (local.get $pos) (i32.const 1))))
        (return (local.get $tup))))

    ;; TFloat (tag=27) → PLit(LVFloat(s)) — payload is raw decimal text.
    (if (i32.eq (call $tag_of (local.get $k)) (i32.const 27))
      (then
        (local.set $tup (call $make_list (i32.const 2)))
        (drop (call $list_set (local.get $tup) (i32.const 0)
          (call $mk_PLit (call $mk_LVFloat (i32.load offset=4 (local.get $k))))))
        (drop (call $list_set (local.get $tup) (i32.const 1)
          (i32.add (local.get $pos) (i32.const 1))))
        (return (local.get $tup))))

    ;; TString (tag=28) → PLit(LVString(s))
    (if (i32.eq (call $tag_of (local.get $k)) (i32.const 28))
      (then
        (local.set $tup (call $make_list (i32.const 2)))
        (drop (call $list_set (local.get $tup) (i32.const 0)
          (call $mk_PLit (call $mk_LVString (i32.load offset=4 (local.get $k))))))
        (drop (call $list_set (local.get $tup) (i32.const 1)
          (i32.add (local.get $pos) (i32.const 1))))
        (return (local.get $tup))))

    ;; Fallback → PWild
    (local.set $tup (call $make_list (i32.const 2)))
    (drop (call $list_set (local.get $tup) (i32.const 0) (i32.const 131)))
    (drop (call $list_set (local.get $tup) (i32.const 1)
      (i32.add (local.get $pos) (i32.const 1))))
    (local.get $tup))

  ;; ─── parse_pat_args: comma-separated patterns until RParen ────────
  ;; Returns (pat_list, new_pos) as 2-tuple.
  ;; Mirrors src/parser.mn parse_pat_args (lines 1266-1278).

  (func $parse_pat_args (param $tokens i32) (param $pos i32) (result i32)
    (local $p i32) (local $buf i32) (local $count i32)
    (local $result i32) (local $pat i32) (local $p2 i32) (local $p3 i32)
    (local $tup i32)
    (local.set $p (call $skip_ws_p (local.get $tokens) (local.get $pos)))
    ;; Empty: )
    (if (call $at (local.get $tokens) (local.get $p) (i32.const 46)) ;; TRParen
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
      (loop $args
        (local.set $result (call $parse_pat (local.get $tokens) (local.get $p)))
        (local.set $pat (call $list_index (local.get $result) (i32.const 0)))
        (local.set $p2 (call $list_index (local.get $result) (i32.const 1)))
        (local.set $buf (call $list_extend_to (local.get $buf)
          (i32.add (local.get $count) (i32.const 1))))
        (drop (call $list_set (local.get $buf) (local.get $count) (local.get $pat)))
        (local.set $count (i32.add (local.get $count) (i32.const 1)))
        (local.set $p3 (call $skip_ws_p (local.get $tokens) (local.get $p2)))
        (if (call $at (local.get $tokens) (local.get $p3) (i32.const 51)) ;; TComma
          (then
            (local.set $p (call $skip_ws_p (local.get $tokens)
              (i32.add (local.get $p3) (i32.const 1))))
            (br $args))
          (else
            (local.set $p (call $expect (local.get $tokens) (local.get $p3) (i32.const 46)))
            (br $done)))))
    (local.set $tup (call $make_list (i32.const 2)))
    (drop (call $list_set (local.get $tup) (i32.const 0)
      (call $slice (local.get $buf) (i32.const 0) (local.get $count))))
    (drop (call $list_set (local.get $tup) (i32.const 1) (local.get $p)))
    (local.get $tup))

  ;; ─── parse_pat_list_args: patterns until RBracket ─────────────────

  (func $parse_pat_list_args (param $tokens i32) (param $pos i32) (result i32)
    (local $p i32) (local $buf i32) (local $count i32)
    (local $result i32) (local $pat i32) (local $p2 i32) (local $p3 i32)
    (local $tup i32)
    (local.set $p (call $skip_ws_p (local.get $tokens) (local.get $pos)))
    (if (call $at (local.get $tokens) (local.get $p) (i32.const 50)) ;; TRBracket
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
      (loop $args
        (local.set $result (call $parse_pat (local.get $tokens) (local.get $p)))
        (local.set $pat (call $list_index (local.get $result) (i32.const 0)))
        (local.set $p2 (call $list_index (local.get $result) (i32.const 1)))
        (local.set $buf (call $list_extend_to (local.get $buf)
          (i32.add (local.get $count) (i32.const 1))))
        (drop (call $list_set (local.get $buf) (local.get $count) (local.get $pat)))
        (local.set $count (i32.add (local.get $count) (i32.const 1)))
        (local.set $p3 (call $skip_ws_p (local.get $tokens) (local.get $p2)))
        (if (call $at (local.get $tokens) (local.get $p3) (i32.const 51)) ;; TComma
          (then
            (local.set $p (call $skip_ws_p (local.get $tokens)
              (i32.add (local.get $p3) (i32.const 1))))
            (br $args))
          (else
            (local.set $p (call $expect (local.get $tokens) (local.get $p3) (i32.const 50)))
            (br $done)))))
    (local.set $tup (call $make_list (i32.const 2)))
    (drop (call $list_set (local.get $tup) (i32.const 0)
      (call $slice (local.get $buf) (i32.const 0) (local.get $count))))
    (drop (call $list_set (local.get $tup) (i32.const 1) (local.get $p)))
    (local.get $tup))

  ;; ─── parse_match_arms: pat => expr, ... until RBrace ──────────────
  ;; Each arm is a 2-tuple (pat, body_expr).
  ;; Mirrors src/parser.mn parse_match_arms (lines 1106-1117).

  (func $parse_match_arms_full (param $tokens i32) (param $pos i32) (result i32)
    (local $p i32) (local $buf i32) (local $count i32)
    (local $pat_r i32) (local $pat i32) (local $p2 i32) (local $p3 i32)
    (local $body_r i32) (local $body i32) (local $p4 i32) (local $p5 i32)
    (local $arm i32) (local $tup i32) (local $k i32)
    (local.set $buf (call $make_list (i32.const 4)))
    (local.set $count (i32.const 0))
    (local.set $p (call $skip_ws_p (local.get $tokens) (local.get $pos)))
    (block $done
      (loop $arms
        ;; Check for } or EOF
        (if (i32.or
              (call $at (local.get $tokens) (local.get $p) (i32.const 48))  ;; TRBrace
              (call $at (local.get $tokens) (local.get $p) (i32.const 69))) ;; TEof
          (then
            (local.set $p (i32.add (local.get $p) (i32.const 1)))
            (br $done)))
        ;; Parse pattern
        (local.set $pat_r (call $parse_pat (local.get $tokens) (local.get $p)))
        (local.set $pat (call $list_index (local.get $pat_r) (i32.const 0)))
        (local.set $p2 (call $list_index (local.get $pat_r) (i32.const 1)))
        ;; Expect =>
        (local.set $p3 (call $expect (local.get $tokens)
          (call $skip_ws_p (local.get $tokens) (local.get $p2))
          (i32.const 35)))  ;; TFatArrow
        ;; Parse body expression
        (local.set $body_r (call $parse_expr (local.get $tokens)
          (call $skip_ws_p (local.get $tokens) (local.get $p3))))
        (local.set $body (call $list_index (local.get $body_r) (i32.const 0)))
        (local.set $p4 (call $list_index (local.get $body_r) (i32.const 1)))
        ;; Build arm as 2-tuple (pat, body)
        (local.set $arm (call $make_list (i32.const 2)))
        (drop (call $list_set (local.get $arm) (i32.const 0) (local.get $pat)))
        (drop (call $list_set (local.get $arm) (i32.const 1) (local.get $body)))
        ;; Append to buffer
        (local.set $buf (call $list_extend_to (local.get $buf)
          (i32.add (local.get $count) (i32.const 1))))
        (drop (call $list_set (local.get $buf) (local.get $count) (local.get $arm)))
        (local.set $count (i32.add (local.get $count) (i32.const 1)))
        ;; Skip optional comma + whitespace
        (local.set $p5 (call $skip_ws_p (local.get $tokens) (local.get $p4)))
        (if (call $at (local.get $tokens) (local.get $p5) (i32.const 51)) ;; TComma
          (then (local.set $p5 (i32.add (local.get $p5) (i32.const 1)))))
        (local.set $p (call $skip_ws_p (local.get $tokens) (local.get $p5)))
        (br $arms)))
    ;; Return (arms_list, pos)
    (local.set $tup (call $make_list (i32.const 2)))
    (drop (call $list_set (local.get $tup) (i32.const 0)
      (call $slice (local.get $buf) (i32.const 0) (local.get $count))))
    (drop (call $list_set (local.get $tup) (i32.const 1) (local.get $p)))
    (local.get $tup))
