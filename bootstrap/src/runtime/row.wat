  ;; ═══ row.wat — Boolean effect-row algebra (Tier 3) ═══════════════
  ;; Implements: spec 01 (effrow.md) + Hβ §1.10 — full Boolean
  ;;             algebra over effect rows: + (union), - (diff),
  ;;             & (intersection), ! (negation), Pure (identity).
  ;;             Substrate primitive #4 (Effect row algebra).
  ;; Exports:    Constructors:
  ;;               $row_make_pure, $row_make_closed, $row_make_open,
  ;;               $row_make_neg, $row_make_sub, $row_make_inter
  ;;             Predicates + accessors:
  ;;               $row_tag, $row_is_pure, $row_is_closed, $row_is_open,
  ;;               $row_names, $row_handle
  ;;             Name-set helpers (sorted-lex flat lists of name ptrs):
  ;;               $name_set_contains, $name_set_eq, $name_set_subset,
  ;;               $name_set_union, $name_set_inter, $name_set_diff
  ;;             Algebra:
  ;;               $row_union, $row_diff, $row_inter, $row_subsumes
  ;; Uses:       $alloc (alloc.wat), $make_record/$record_get
  ;;             (record.wat), $make_list/$list_index/$list_set/
  ;;             $list_extend_to/$len (list.wat),
  ;;             $str_eq/$str_compare (str.wat), $heap_base (Layer 0)
  ;; Test:       runtime_test/row.wat
  ;;
  ;; ═══ DESIGN ═══════════════════════════════════════════════════════
  ;; Per spec 01 + DESIGN §0.5 primitive #4:
  ;;
  ;; EffRow normal forms (always one of three after normalize):
  ;;   1. EfPure                         — identity element
  ;;   2. EfClosed(sorted_unique_names)  — concrete row
  ;;   3. EfOpen(sorted_unique_names, v) — row with row-variable v
  ;;
  ;; Intermediate forms (constructed during builds; reduced before
  ;; subsumption/unification — Tier-3 base ships constructors but
  ;; defers the full normalize to the row.wat follow-up):
  ;;   - EfNeg(inner)                    — !inner; De Morgan reduces
  ;;   - EfSub(left, right)              — left & !right
  ;;   - EfInter(left, right)            — left ∩ right
  ;;
  ;; Per spec 01 §Operators:
  ;;   E + F → normalize(EfClosed(names(E) ∪ names(F)))   (or EfOpen
  ;;                                                       if either side has rowvar)
  ;;   E - F → normalize(EfSub(E, F))                     ≡ E & !F
  ;;   E & F → normalize(EfInter(E, F))
  ;;   !E    → normalize(EfNeg(E))
  ;;   Pure  → EfPure
  ;;
  ;; ═══ HEAP RECORD LAYOUTS ═══════════════════════════════════════════
  ;;
  ;; EfPure — sentinel (i32 value 150, < HEAP_BASE; no allocation)
  ;; per Hβ §1.5 nullary-sentinel discipline + record.wat $tag_of.
  ;;
  ;; Fielded variants (each $make_record with the tag below):
  ;;   EfClosed(names)        — tag=151, arity=1; field_0 = name list ptr
  ;;   EfOpen(names, handle)  — tag=152, arity=2; field_0 = name list,
  ;;                                              field_1 = rowvar handle (i32)
  ;;   EfNeg(inner)           — tag=153, arity=1; field_0 = inner row ptr
  ;;   EfSub(left, right)     — tag=154, arity=2
  ;;   EfInter(left, right)   — tag=155, arity=2
  ;;
  ;; Tag allocation: row.wat private region 150-179 (avoids graph.wat
  ;; 50-99 + env.wat 130-149 + TokenKind 0-44).
  ;;
  ;; ═══ NAME SETS ═════════════════════════════════════════════════════
  ;; Effect names are stored as pointers to flat strings (str.wat
  ;; layout). Name lists are sorted lex-order by $str_compare (str.wat)
  ;; and deduplicated. The seed's HM inference (Hβ.infer — Wave 2.E)
  ;; constructs name lists already in canonical form; row.wat's
  ;; constructors don't re-sort (Tier-3 base; sort/dedup follow-up
  ;; lands when Hβ.infer needs runtime canonicalization).
  ;;
  ;; ═══ SUBSUMPTION ═══════════════════════════════════════════════════
  ;; Per spec 01 §Subsumption — body row B subsumed by handler row F:
  ;;   B ⊆ Pure        iff B = Pure
  ;;   B ⊆ Closed(F)   iff names(B) ⊆ F AND B has no rowvar
  ;;   B ⊆ Open(F, v)  iff names(B) ⊆ F ∪ names_of(chase(v))
  ;;
  ;; (The chase(v) reach lands in Hβ.infer — needs graph.wat chase +
  ;;  EffRow tag dispatch. row.wat's $row_subsumes Tier-3 base handles
  ;;  the F-not-open case; open-side dispatch is the named follow-up.)

  ;; ─── Constructors ────────────────────────────────────────────────

  (func $row_make_pure (result i32)
    (i32.const 150))   ;; sentinel; < HEAP_BASE

  (func $row_make_closed (param $names i32) (result i32)
    (local $r i32)
    (local.set $r (call $make_record (i32.const 151) (i32.const 1)))
    (call $record_set (local.get $r) (i32.const 0) (local.get $names))
    (local.get $r))

  (func $row_make_open (param $names i32) (param $rowvar i32) (result i32)
    (local $r i32)
    (local.set $r (call $make_record (i32.const 152) (i32.const 2)))
    (call $record_set (local.get $r) (i32.const 0) (local.get $names))
    (call $record_set (local.get $r) (i32.const 1) (local.get $rowvar))
    (local.get $r))

  (func $row_make_neg (param $inner i32) (result i32)
    (local $r i32)
    (local.set $r (call $make_record (i32.const 153) (i32.const 1)))
    (call $record_set (local.get $r) (i32.const 0) (local.get $inner))
    (local.get $r))

  (func $row_make_sub (param $left i32) (param $right i32) (result i32)
    (local $r i32)
    (local.set $r (call $make_record (i32.const 154) (i32.const 2)))
    (call $record_set (local.get $r) (i32.const 0) (local.get $left))
    (call $record_set (local.get $r) (i32.const 1) (local.get $right))
    (local.get $r))

  (func $row_make_inter (param $left i32) (param $right i32) (result i32)
    (local $r i32)
    (local.set $r (call $make_record (i32.const 155) (i32.const 2)))
    (call $record_set (local.get $r) (i32.const 0) (local.get $left))
    (call $record_set (local.get $r) (i32.const 1) (local.get $right))
    (local.get $r))

  ;; ─── Predicates + accessors ──────────────────────────────────────

  (func $row_tag (param $row i32) (result i32)
    (call $tag_of (local.get $row)))

  (func $row_is_pure (param $row i32) (result i32)
    (i32.eq (call $row_tag (local.get $row)) (i32.const 150)))

  (func $row_is_closed (param $row i32) (result i32)
    (i32.eq (call $row_tag (local.get $row)) (i32.const 151)))

  (func $row_is_open (param $row i32) (result i32)
    (i32.eq (call $row_tag (local.get $row)) (i32.const 152)))

  ;; $row_names — returns the names list for Closed/Open; empty list
  ;; for Pure; UNDEFINED for Neg/Sub/Inter (those should be normalized
  ;; first; Tier-3 base traps via (unreachable) on those tags).
  (func $row_names (param $row i32) (result i32)
    (local $tag i32)
    (local.set $tag (call $row_tag (local.get $row)))
    (if (i32.eq (local.get $tag) (i32.const 150))   ;; Pure
      (then (return (call $make_list (i32.const 0)))))
    (if (i32.eq (local.get $tag) (i32.const 151))   ;; Closed
      (then (return (call $record_get (local.get $row) (i32.const 0)))))
    (if (i32.eq (local.get $tag) (i32.const 152))   ;; Open
      (then (return (call $record_get (local.get $row) (i32.const 0)))))
    (unreachable))

  ;; $row_handle — returns the rowvar handle for Open; 0 for others
  ;; (callers test $row_is_open first).
  (func $row_handle (param $row i32) (result i32)
    (if (i32.eq (call $row_tag (local.get $row)) (i32.const 152))   ;; Open
      (then (return (call $record_get (local.get $row) (i32.const 1)))))
    (i32.const 0))

  ;; ─── Name-set helpers (sorted-lex flat lists) ────────────────────
  ;; Inputs are flat lists of string-ptrs, sorted lex-order, deduped.
  ;; Outputs are the same shape. All operations preserve canonical form.

  ;; $name_set_contains — single-element membership. Linear scan
  ;; (binary search is a follow-up optimization when callers profile
  ;; hot).
  (func $name_set_contains (param $set i32) (param $name i32) (result i32)
    (local $i i32) (local $n i32)
    (local.set $n (call $len (local.get $set)))
    (local.set $i (i32.const 0))
    (block $done
      (loop $scan
        (br_if $done (i32.ge_u (local.get $i) (local.get $n)))
        (if (call $str_eq (call $list_index (local.get $set) (local.get $i))
                          (local.get $name))
          (then (return (i32.const 1))))
        (local.set $i (i32.add (local.get $i) (i32.const 1)))
        (br $scan)))
    (i32.const 0))

  ;; $name_set_eq — set equality (sorted; just element-by-element).
  (func $name_set_eq (param $a i32) (param $b i32) (result i32)
    (local $na i32) (local $nb i32) (local $i i32)
    (local.set $na (call $len (local.get $a)))
    (local.set $nb (call $len (local.get $b)))
    (if (i32.ne (local.get $na) (local.get $nb)) (then (return (i32.const 0))))
    (local.set $i (i32.const 0))
    (block $done
      (loop $cmp
        (br_if $done (i32.ge_u (local.get $i) (local.get $na)))
        (if (i32.eqz (call $str_eq (call $list_index (local.get $a) (local.get $i))
                                   (call $list_index (local.get $b) (local.get $i))))
          (then (return (i32.const 0))))
        (local.set $i (i32.add (local.get $i) (i32.const 1)))
        (br $cmp)))
    (i32.const 1))

  ;; $name_set_subset — a ⊆ b. Per spec 01 §Subsumption.
  (func $name_set_subset (param $a i32) (param $b i32) (result i32)
    (local $i i32) (local $n i32)
    (local.set $n (call $len (local.get $a)))
    (local.set $i (i32.const 0))
    (block $done
      (loop $scan
        (br_if $done (i32.ge_u (local.get $i) (local.get $n)))
        (if (i32.eqz (call $name_set_contains (local.get $b)
                          (call $list_index (local.get $a) (local.get $i))))
          (then (return (i32.const 0))))
        (local.set $i (i32.add (local.get $i) (i32.const 1)))
        (br $scan)))
    (i32.const 1))

  ;; $name_set_union — sorted merge of two sorted-deduped lists.
  ;; Result is sorted, deduped. Per spec 01 §Operators E + F.
  (func $name_set_union (param $a i32) (param $b i32) (result i32)
    (local $na i32) (local $nb i32) (local $i i32) (local $j i32)
    (local $out i32) (local $k i32) (local $cmp i32)
    (local $ai i32) (local $bj i32)
    (local.set $na (call $len (local.get $a)))
    (local.set $nb (call $len (local.get $b)))
    ;; Allocate worst-case capacity (na + nb); shrink with $slice at end.
    (local.set $out (call $make_list (i32.add (local.get $na) (local.get $nb))))
    (local.set $i (i32.const 0))
    (local.set $j (i32.const 0))
    (local.set $k (i32.const 0))
    (block $done
      (loop $merge
        ;; If a exhausted, copy remainder of b.
        (if (i32.ge_u (local.get $i) (local.get $na))
          (then
            (block $b_done
              (loop $copy_b
                (br_if $b_done (i32.ge_u (local.get $j) (local.get $nb)))
                (drop (call $list_set (local.get $out) (local.get $k)
                  (call $list_index (local.get $b) (local.get $j))))
                (local.set $j (i32.add (local.get $j) (i32.const 1)))
                (local.set $k (i32.add (local.get $k) (i32.const 1)))
                (br $copy_b)))
            (br $done)))
        ;; If b exhausted, copy remainder of a.
        (if (i32.ge_u (local.get $j) (local.get $nb))
          (then
            (block $a_done
              (loop $copy_a
                (br_if $a_done (i32.ge_u (local.get $i) (local.get $na)))
                (drop (call $list_set (local.get $out) (local.get $k)
                  (call $list_index (local.get $a) (local.get $i))))
                (local.set $i (i32.add (local.get $i) (i32.const 1)))
                (local.set $k (i32.add (local.get $k) (i32.const 1)))
                (br $copy_a)))
            (br $done)))
        ;; Both have elements — compare.
        (local.set $ai (call $list_index (local.get $a) (local.get $i)))
        (local.set $bj (call $list_index (local.get $b) (local.get $j)))
        (local.set $cmp (call $str_compare (local.get $ai) (local.get $bj)))
        (if (i32.lt_s (local.get $cmp) (i32.const 0))
          (then
            (drop (call $list_set (local.get $out) (local.get $k) (local.get $ai)))
            (local.set $i (i32.add (local.get $i) (i32.const 1)))
            (local.set $k (i32.add (local.get $k) (i32.const 1))))
          (else
            (if (i32.gt_s (local.get $cmp) (i32.const 0))
              (then
                (drop (call $list_set (local.get $out) (local.get $k) (local.get $bj)))
                (local.set $j (i32.add (local.get $j) (i32.const 1)))
                (local.set $k (i32.add (local.get $k) (i32.const 1))))
              (else
                ;; equal — emit once, advance both
                (drop (call $list_set (local.get $out) (local.get $k) (local.get $ai)))
                (local.set $i (i32.add (local.get $i) (i32.const 1)))
                (local.set $j (i32.add (local.get $j) (i32.const 1)))
                (local.set $k (i32.add (local.get $k) (i32.const 1)))))))
        (br $merge)))
    ;; Truncate to actual length k via $slice.
    (call $slice (local.get $out) (i32.const 0) (local.get $k)))

  ;; $name_set_inter — sorted intersection of two sorted-deduped lists.
  (func $name_set_inter (param $a i32) (param $b i32) (result i32)
    (local $na i32) (local $nb i32) (local $i i32) (local $j i32)
    (local $out i32) (local $k i32) (local $cmp i32)
    (local $ai i32) (local $bj i32)
    (local.set $na (call $len (local.get $a)))
    (local.set $nb (call $len (local.get $b)))
    (local.set $out (call $make_list (i32.add (local.get $na) (local.get $nb))))
    (local.set $i (i32.const 0))
    (local.set $j (i32.const 0))
    (local.set $k (i32.const 0))
    (block $done
      (loop $merge
        (br_if $done (i32.ge_u (local.get $i) (local.get $na)))
        (br_if $done (i32.ge_u (local.get $j) (local.get $nb)))
        (local.set $ai (call $list_index (local.get $a) (local.get $i)))
        (local.set $bj (call $list_index (local.get $b) (local.get $j)))
        (local.set $cmp (call $str_compare (local.get $ai) (local.get $bj)))
        (if (i32.lt_s (local.get $cmp) (i32.const 0))
          (then (local.set $i (i32.add (local.get $i) (i32.const 1))))
          (else
            (if (i32.gt_s (local.get $cmp) (i32.const 0))
              (then (local.set $j (i32.add (local.get $j) (i32.const 1))))
              (else
                ;; equal — keep + advance both
                (drop (call $list_set (local.get $out) (local.get $k) (local.get $ai)))
                (local.set $i (i32.add (local.get $i) (i32.const 1)))
                (local.set $j (i32.add (local.get $j) (i32.const 1)))
                (local.set $k (i32.add (local.get $k) (i32.const 1)))))))
        (br $merge)))
    (call $slice (local.get $out) (i32.const 0) (local.get $k)))

  ;; $name_set_diff — sorted set difference a - b (elements in a but not in b).
  (func $name_set_diff (param $a i32) (param $b i32) (result i32)
    (local $na i32) (local $nb i32) (local $i i32) (local $j i32)
    (local $out i32) (local $k i32) (local $cmp i32)
    (local $ai i32) (local $bj i32)
    (local.set $na (call $len (local.get $a)))
    (local.set $nb (call $len (local.get $b)))
    (local.set $out (call $make_list (local.get $na)))
    (local.set $i (i32.const 0))
    (local.set $j (i32.const 0))
    (local.set $k (i32.const 0))
    (block $done
      (loop $merge
        (br_if $done (i32.ge_u (local.get $i) (local.get $na)))
        (local.set $ai (call $list_index (local.get $a) (local.get $i)))
        ;; If b exhausted, all remaining a survive.
        (if (i32.ge_u (local.get $j) (local.get $nb))
          (then
            (drop (call $list_set (local.get $out) (local.get $k) (local.get $ai)))
            (local.set $i (i32.add (local.get $i) (i32.const 1)))
            (local.set $k (i32.add (local.get $k) (i32.const 1)))
            (br $merge)))
        (local.set $bj (call $list_index (local.get $b) (local.get $j)))
        (local.set $cmp (call $str_compare (local.get $ai) (local.get $bj)))
        (if (i32.lt_s (local.get $cmp) (i32.const 0))
          (then
            ;; ai not in b — keep
            (drop (call $list_set (local.get $out) (local.get $k) (local.get $ai)))
            (local.set $i (i32.add (local.get $i) (i32.const 1)))
            (local.set $k (i32.add (local.get $k) (i32.const 1))))
          (else
            (if (i32.gt_s (local.get $cmp) (i32.const 0))
              (then
                ;; bj < ai — advance b
                (local.set $j (i32.add (local.get $j) (i32.const 1))))
              (else
                ;; equal — drop ai (in b), advance both
                (local.set $i (i32.add (local.get $i) (i32.const 1)))
                (local.set $j (i32.add (local.get $j) (i32.const 1)))))))
        (br $merge)))
    (call $slice (local.get $out) (i32.const 0) (local.get $k)))

  ;; ─── Row algebra (operates on canonical Pure/Closed/Open) ────────
  ;; Tier-3 base: assumes inputs are normalized. Neg/Sub/Inter
  ;; normalization to canonical form is the named follow-up (depends
  ;; on graph.wat chase for resolving rowvars in EfOpen — Wave 2.E).

  ;; $row_union — E + F per spec 01.
  ;; If either side has a rowvar, result is Open (with the union of
  ;; names + the rowvar — single-rowvar case; double-rowvar normalization
  ;; via fresh row-handle is the follow-up). If both Closed, result is
  ;; Closed of name union.
  (func $row_union (param $e i32) (param $f i32) (result i32)
    (local $e_tag i32) (local $f_tag i32)
    (local $e_names i32) (local $f_names i32)
    (local $e_handle i32) (local $f_handle i32)
    (local $merged i32)
    (local.set $e_tag (call $row_tag (local.get $e)))
    (local.set $f_tag (call $row_tag (local.get $f)))
    ;; Pure + x = x; x + Pure = x.
    (if (i32.eq (local.get $e_tag) (i32.const 150)) (then (return (local.get $f))))
    (if (i32.eq (local.get $f_tag) (i32.const 150)) (then (return (local.get $e))))
    ;; Both have names; merge.
    (local.set $e_names (call $row_names (local.get $e)))
    (local.set $f_names (call $row_names (local.get $f)))
    (local.set $merged (call $name_set_union (local.get $e_names) (local.get $f_names)))
    ;; If either side is Open, result is Open with that side's rowvar.
    ;; (Double-rowvar union → fresh rowvar bound to union of both — follow-up.)
    (if (i32.eq (local.get $e_tag) (i32.const 152))
      (then (return (call $row_make_open (local.get $merged)
                          (call $row_handle (local.get $e))))))
    (if (i32.eq (local.get $f_tag) (i32.const 152))
      (then (return (call $row_make_open (local.get $merged)
                          (call $row_handle (local.get $f))))))
    (call $row_make_closed (local.get $merged)))

  ;; $row_diff — E - F per spec 01 ≡ E & !F.
  ;; Tier-3 base: handles Closed - Closed = Closed of name diff.
  ;; Open - F (or E - Open) preserves the rowvar (the rowvar's own
  ;; binding handles the rest — follow-up resolves via chase).
  (func $row_diff (param $e i32) (param $f i32) (result i32)
    (local $e_tag i32)
    (local $diff i32)
    (local.set $e_tag (call $row_tag (local.get $e)))
    ;; Pure - anything = Pure.
    (if (i32.eq (local.get $e_tag) (i32.const 150)) (then (return (local.get $e))))
    ;; E - Pure = E.
    (if (i32.eq (call $row_tag (local.get $f)) (i32.const 150)) (then (return (local.get $e))))
    ;; Closed/Open - F: subtract F's names.
    (local.set $diff
      (call $name_set_diff (call $row_names (local.get $e))
                           (call $row_names (local.get $f))))
    (if (i32.eq (local.get $e_tag) (i32.const 152))
      (then (return (call $row_make_open (local.get $diff)
                          (call $row_handle (local.get $e))))))
    (call $row_make_closed (local.get $diff)))

  ;; $row_inter — E & F per spec 01.
  ;; Tier-3 base: handles Closed & Closed = Closed of name intersection.
  ;; Open & Closed (or Closed & Open) = Closed of intersection (rowvar
  ;; can contribute nothing beyond what it shares — per spec 01 §Normal
  ;; form Reductions). Open & Open with v₁=v₂: intersection of names;
  ;; with v₁≠v₂: fresh rowvar (follow-up).
  (func $row_inter (param $e i32) (param $f i32) (result i32)
    (local $e_tag i32) (local $f_tag i32)
    (local $inter i32)
    (local.set $e_tag (call $row_tag (local.get $e)))
    (local.set $f_tag (call $row_tag (local.get $f)))
    ;; Pure & x = Pure; x & Pure = Pure.
    (if (i32.eq (local.get $e_tag) (i32.const 150)) (then (return (local.get $e))))
    (if (i32.eq (local.get $f_tag) (i32.const 150)) (then (return (local.get $f))))
    (local.set $inter
      (call $name_set_inter (call $row_names (local.get $e))
                            (call $row_names (local.get $f))))
    ;; Both Open with same rowvar — preserve as Open.
    (if (i32.and
          (i32.eq (local.get $e_tag) (i32.const 152))
          (i32.eq (local.get $f_tag) (i32.const 152)))
      (then
        (if (i32.eq (call $row_handle (local.get $e))
                    (call $row_handle (local.get $f)))
          (then (return (call $row_make_open (local.get $inter)
                                             (call $row_handle (local.get $e))))))))
    ;; Otherwise Closed of intersection.
    (call $row_make_closed (local.get $inter)))

  ;; ─── Subsumption ─────────────────────────────────────────────────
  ;; $row_subsumes(b, f) → 1 if body b is subsumed by handler row f,
  ;; else 0. Per spec 01 §Subsumption:
  ;;   B ⊆ Pure        iff B = Pure
  ;;   B ⊆ Closed(F)   iff names(B) ⊆ F AND B has no rowvar
  ;;   B ⊆ Open(F, v)  iff names(B) ⊆ F ∪ names_of(chase(v))
  ;;
  ;; Tier-3 base: handles Pure ⊆ Pure, Closed ⊆ Closed, Closed ⊆ Open
  ;; (without chasing rowvar — conservative; returns 1 only if names(B)
  ;; ⊆ names(F) directly). The rowvar-chase reach lands when graph.wat
  ;; chase + EffRow tag dispatch land in Hβ.lower.
  (func $row_subsumes (param $b i32) (param $f i32) (result i32)
    (local $b_tag i32) (local $f_tag i32)
    (local.set $b_tag (call $row_tag (local.get $b)))
    (local.set $f_tag (call $row_tag (local.get $f)))
    ;; B ⊆ Pure iff B = Pure
    (if (i32.eq (local.get $f_tag) (i32.const 150))
      (then (return (i32.eq (local.get $b_tag) (i32.const 150)))))
    ;; Pure ⊆ anything else (Closed, Open) — yes (empty subset).
    (if (i32.eq (local.get $b_tag) (i32.const 150)) (then (return (i32.const 1))))
    ;; B ⊆ Closed(F): names(B) ⊆ F AND B has no rowvar.
    (if (i32.eq (local.get $f_tag) (i32.const 151))
      (then
        ;; B must not be Open.
        (if (i32.eq (local.get $b_tag) (i32.const 152)) (then (return (i32.const 0))))
        (return (call $name_set_subset
                  (call $row_names (local.get $b))
                  (call $row_names (local.get $f))))))
    ;; B ⊆ Open(F, v): conservative — subset of F's names suffices
    ;; (the rowvar can absorb whatever's left at unification time;
    ;; full check requires chase(v) per follow-up).
    (if (i32.eq (local.get $f_tag) (i32.const 152))
      (then
        (return (call $name_set_subset
                  (call $row_names (local.get $b))
                  (call $row_names (local.get $f))))))
    (i32.const 0))
