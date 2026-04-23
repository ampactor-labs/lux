;; bootstrap/templates/topology_pipes.wat
;; 
;; The Inka Topology Pipes Template
;; Defines the WAT structure for the 5 verbs: |> <| >< ~> <~
;;
;; Since verbs define topology, they compile down to block structures
;; and call chains.

;; MACRO_TEMPLATE_START(PIPE_FORWARD)
;; `a |> b` becomes a direct argument pass.
;; ... push a ...
(call $##B_FUNC##)
;; MACRO_TEMPLATE_END

;; MACRO_TEMPLATE_START(PIPE_FEEDBACK)
;; `a <~ b` becomes a looping state handler.
(block $feedback_exit
  (loop $feedback_loop
    ;; The ambient handler provides the back-edge value on the stack.
    ;; If the ambient handler halts, we break.
    ;; (br $feedback_exit)
    ;; Otherwise, we loop.
    ;; (br $feedback_loop)
  )
)
;; MACRO_TEMPLATE_END
