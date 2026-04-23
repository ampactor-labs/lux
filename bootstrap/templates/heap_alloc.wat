;; bootstrap/templates/heap_alloc.wat
;; 
;; The Inka Heap Allocation Template
;; "The Heap Has One Story"
;; Used for all ADT variants, closures, records, and evidence records.

;; MACRO_TEMPLATE_START(HEAP_ALLOC)
;; Evaluates to a pointer to a newly allocated block of memory.
;; Expects no arguments.
;; Emits:
;; (local $ptr)
(local.set $ptr (call $alloc (i32.const ##SIZE##)))
;;
;; Then, the compiler will emit successive stores:
;; (i32.store (local.get $ptr) (local.get $field_0))
;; (i32.store offset=4 (local.get $ptr) (local.get $field_1))
;; ...
;; (local.get $ptr)
;; MACRO_TEMPLATE_END
