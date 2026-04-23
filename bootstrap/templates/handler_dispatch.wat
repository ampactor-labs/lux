;; bootstrap/templates/handler_dispatch.wat
;; 
;; The Inka Handler Dispatch Template (No VTables)
;; Performs polymorphic dispatch via Koka-style evidence passing.
;; The closure record contains the function index at offset 4.

;; Example usage:
;; (local.set $closure)
;; ;; ... push args ...
;; ;; push closure as the last argument (the __state param)
;; (local.get $closure)
;; ;; load the function index
;; (i32.load offset=4 (local.get $closure))
;; (call_indirect (type $expected_sig))

;; The expander injects this pattern for every polymorphic `perform` or closure invocation.
;;
;; MACRO_TEMPLATE_START
(local.get $closure_ptr)
(i32.load offset=4 (local.get $closure_ptr))
(call_indirect (type $##SIG_INDEX##))
;; MACRO_TEMPLATE_END
