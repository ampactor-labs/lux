;; bootstrap/templates/match_dispatch.wat
;; 
;; The Inka ADT Match Dispatch Template
;; Resolves the tag of any scrutinee by checking it against HEAP_BASE.
;; If < HEAP_BASE, it is a nullary sentinel (the value IS the tag).
;; If >= HEAP_BASE, it is a pointer (the tag is loaded from offset 0).

(local $scrutinee i32)
(local $tag i32)

;; Expects scrutinee on the stack.
(local.set $scrutinee)

(if (i32.lt_u (local.get $scrutinee) (global.get $heap_base))
  (then 
    ;; Nullary variant: the value itself is the tag ID.
    (local.set $tag (local.get $scrutinee))
  )
  (else 
    ;; Fielded variant: the value is a pointer. Tag is at offset 0.
    (local.set $tag (i32.load (local.get $scrutinee)))
  )
)

;; The macro expander injects the nested blocks and br_table here
;; based on the number of arms.
;;
;; Example expansion:
;; (block $match_end
;;   (block $arm1
;;     (block $arm0
;;       (br_table $arm0 $arm1 (local.get $tag))
;;     )
;;     ;; ... arm 0 logic ...
;;     (br $match_end)
;;   )
;;   ;; ... arm 1 logic ...
;; )
