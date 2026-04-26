  ;; ═══ emit_diag.wat — diagnostic emission helpers (Tier 6) ═════════
  ;; Implements: Hβ-infer-substrate.md §8.1 emit_diag.wat row +
  ;;             §8.4 ~200-line estimate + spec 04 §Error handling
  ;;             (Hazel productive-under-error pattern). Realizes the
  ;;             diagnostic-side projection of primitive #8 (HM
  ;;             inference, productive-under-error, with Reasons) at
  ;;             the seed substrate: every unification mismatch /
  ;;             missing var / occurs-check / handler-install / match-
  ;;             exhaustiveness / feedback-context / over-declared
  ;;             diagnostic the walk arms detect emits ONE message to
  ;;             stderr + binds the offending handle to NErrorHole(reason)
  ;;             via $graph_bind, then returns; the walk continues per
  ;;             Hazel POPL 2024 pattern.
  ;;
  ;; Exports:    $render_ty,
  ;;             $infer_emit_type_mismatch,
  ;;             $infer_emit_missing_var,
  ;;             $infer_emit_occurs_check,
  ;;             $infer_emit_feedback_no_context,
  ;;             $infer_emit_handler_uninstallable,
  ;;             $infer_emit_pattern_inexhaustive,
  ;;             $infer_emit_over_declared,
  ;;             $infer_emit_not_a_record_type,
  ;;             $infer_emit_record_field_extra,
  ;;             $infer_emit_record_field_missing,
  ;;             $infer_emit_cannot_negate_capability
  ;; Uses:       $alloc (alloc.wat),
  ;;             $str_alloc / $str_concat / $str_len /
  ;;               $str_from_mem (str.wat + int.wat),
  ;;             $int_to_str (int.wat),
  ;;             $eprint_string (wasi.wat — fd 2 / stderr),
  ;;             $make_list / $list_index / $len (list.wat — for
  ;;               TTuple/TName arg-list rendering),
  ;;             $graph_bind_kind (graph.wat — handle binding given a
  ;;               pre-constructed NodeKind; emit_diag.wat passes
  ;;               $node_kind_make_nerrorhole(reason)),
  ;;             $node_kind_make_nerrorhole (graph.wat — wraps Reason),
  ;;             $ty_tag (ty.wat — render dispatch),
  ;;             $ty_tvar_handle / $ty_tlist_elem / $ty_ttuple_elems /
  ;;               $ty_tfun_return / $ty_tname_name / $ty_tname_args /
  ;;               $ty_trefined_base / $ty_tcont_return /
  ;;               $ty_talias_name (ty.wat — payload accessors per
  ;;               14-variant Ty ADT),
  ;;             $reason_make_unifyfailed / $reason_make_missingvar /
  ;;               $reason_make_inferred (reason.wat — the three
  ;;               canonical Reason payloads NErrorHole wraps for the
  ;;               three core diagnostics; the eight additional helpers
  ;;               compose on $reason_make_inferred per the seed's
  ;;               descriptive-context discipline)
  ;; Test:       runtime_test/infer_emit_diag.wat (pending — first
  ;;             acceptance is $infer_emit_*-grep + $render_ty-grep +
  ;;             wasm-validate per Hβ-infer-substrate.md §11)
  ;;
  ;; ═══ DESIGN ═══════════════════════════════════════════════════════
  ;;
  ;; Per spec 04 §Error handling (04-inference.md L208-223) +
  ;; Hβ-infer-substrate.md §8.1 + docs/errors/ catalog (per-code .md
  ;; files for E_TypeMismatch, E_MissingVariable, E_OccursCheck,
  ;; E_FeedbackNoContext, E_HandlerUninstallable, E_PatternInexhaustive,
  ;; T_OverDeclared) + src/infer.nx canonical `report` calls (lines
  ;; 597, 680, 791, 856, 964, 1073, 1529, 1538, 1712 + 330).
  ;;
  ;; What diagnostic emission IS in the seed:
  ;;   The wheel routes diagnostics through the `report` effect handler
  ;;   chain (spec 06): `perform report(category, code, kind, summary,
  ;;   span, applicability)`. The default handler the seed installs at
  ;;   compile-entry projects this onto stderr write + graph mutation.
  ;;
  ;;   The seed's emit_diag chunk IS that projection — direct functions
  ;;   that:
  ;;     (1) construct the diagnostic message via $str_concat / $int_to_str
  ;;         / $str_from_mem,
  ;;     (2) write to stderr via $eprint_string (wasi.wat fd 2),
  ;;     (3) bind the offending handle to NErrorHole(reason) via
  ;;         $graph_bind + $node_kind_make_nerrorhole,
  ;;     (4) return; caller's walk continues per spec 04's Hazel
  ;;         pattern (NEVER halt; ten mismatches produce ten error
  ;;         holes, not one-and-halt; downstream sees an error-typed
  ;;         node, not an unbound TVar).
  ;;
  ;;   No exception machinery; no `throw` / `panic` / `unwind`
  ;;   vocabulary. The graph's NErrorHole IS the productive-under-error
  ;;   substrate.
  ;;
  ;; What this chunk produces (helpers wired by walk_*.wat arms when
  ;; they land — peer chunks per Hβ-infer §8.1):
  ;;
  ;;   Core trio (named in §8.1 verbatim):
  ;;     $infer_emit_type_mismatch(handle, ty_a, ty_b, reason)
  ;;       — emitted by $unify_shapes when no Ty-pair arm matches per
  ;;         spec 04 §Unification + §Error handling. Reason payload:
  ;;         UnifyFailed(ty_a, ty_b) per src/types.nx Reason ADT line
  ;;         247 (reason.wat tag 233).
  ;;     $infer_emit_missing_var(handle, name_str, reason)
  ;;       — emitted by VarRef / ConsCall / pattern arms on env_lookup
  ;;         miss per spec 04 §Instantiations L113-116. Reason payload:
  ;;         MissingVar(name) per reason.wat tag 236.
  ;;     $infer_emit_occurs_check(handle, ty, reason)
  ;;       — emitted by graph_bind's pre-condition check (spec 04
  ;;         §Occurs check); when occurs_in proves the bind would close
  ;;         a cycle, this surfaces. Reason payload: Inferred("occurs
  ;;         check") per reason.wat tag 221 (Inferred String). The
  ;;         wheel's reason chain wraps the offending span via Located
  ;;         at the call site; the seed's helper passes the Located-
  ;;         wrapped reason verbatim through the `reason` parameter.
  ;;
  ;;   Additional infer-emitted catalog codes (per docs/errors/ +
  ;;   src/infer.nx report call inventory):
  ;;     $infer_emit_feedback_no_context(handle, reason)
  ;;       — emitted by `<~` arm in walk_expr.wat when no iterative
  ;;         context handler (Clock/Tick/Sample) is in scope per
  ;;         spec 04 + docs/errors/E_FeedbackNoContext. Reason payload:
  ;;         Inferred("feedback no context").
  ;;     $infer_emit_handler_uninstallable(handle, reason)
  ;;       — emitted by HandleExpr arm when handler arms require
  ;;         effects the enclosing fn's row cannot admit (spec I14/I16
  ;;         + docs/errors/E_HandlerUninstallable). Reason payload:
  ;;         Inferred("handler uninstallable").
  ;;     $infer_emit_pattern_inexhaustive(handle, reason)
  ;;       — emitted by MatchExpr arm when the scrutinee's ADT has
  ;;         variants the pattern doesn't cover (spec 04 + docs/errors/
  ;;         E_PatternInexhaustive). Reason payload:
  ;;         Inferred("pattern inexhaustive").
  ;;     $infer_emit_over_declared(handle, reason)
  ;;       — emitted by FnStmt's declared-effects check when the
  ;;         declared row is strictly wider than the inferred body row
  ;;         (spec I19 + docs/errors/T_OverDeclared). Warning kind, NOT
  ;;         Error — does NOT bind to NErrorHole (the program is well-
  ;;         typed; T_OverDeclared just teaches a tighter signature).
  ;;         Per the catalog file's "MachineApplicable" applicability —
  ;;         the suggested narrower row IS the canonical fix. Per H6
  ;;         wildcard discipline + drift mode 9: this helper exists in
  ;;         the chunk so walk_stmt's FnStmt arm can call it without
  ;;         routing the warning through the same NErrorHole-binding
  ;;         path as Errors.
  ;;     $infer_emit_not_a_record_type(handle, type_name, reason)
  ;;       — emitted by NamedRecordExpr arm when env_lookup resolves
  ;;         the type-name to a non-RecordSchemeKind Scheme (per
  ;;         src/infer.nx:609). Message: "E_NotARecordType: at
  ;;         handle <h> — '<type_name>' is not a record type\n".
  ;;         Reason payload: Inferred("not a record type"). Per
  ;;         docs/errors/E_NotARecordType.md.
  ;;     $infer_emit_record_field_extra(handle, field_name, type_name, reason)
  ;;       — emitted by check_nominal_record_fields when provided
  ;;         record literal has a field name no declared field
  ;;         matches (per src/infer.nx:1406, 1442). Message:
  ;;         "E_RecordFieldExtra: at handle <h> — record literal has
  ;;         unknown field '<field_name>' for type <type_name>\n".
  ;;         Reason payload: Inferred("record field extra"). Per
  ;;         docs/errors/E_RecordFieldExtra.md.
  ;;     $infer_emit_record_field_missing(handle, field_name, type_name, reason)
  ;;       — emitted by check_nominal_record_fields when declared
  ;;         record type has a field the literal omits (per
  ;;         src/infer.nx:1415, 1434). Message: "E_RecordFieldMissing:
  ;;         at handle <h> — record literal missing field '<field_name>'
  ;;         for type <type_name>\n". Reason payload: Inferred("record
  ;;         field missing"). Per docs/errors/E_RecordFieldMissing.md.
  ;;     $infer_emit_cannot_negate_capability(handle, capability_name, reason)
  ;;       — emitted by expand_capabilities when an ENamed(s) resolves
  ;;         to CapabilityScheme(_) AND `negated == true` (per
  ;;         src/infer.nx:433). Per ROADMAP item 2 (commit 63b25ce):
  ;;         CapabilityScheme is the fifth canonical SchemeKind variant
  ;;         (FnScheme, ConstructorScheme, EffectOpScheme,
  ;;         RecordSchemeKind, CapabilityScheme); this helper is the
  ;;         diagnostic peer of that variant landing. Message:
  ;;         "E_CannotNegateCapability: at handle <h> — cannot negate
  ;;         capability bundle '<capability_name>'\n". Reason payload:
  ;;         Inferred("cannot negate capability"). Per
  ;;         docs/errors/E_CannotNegateCapability.md.
  ;;
  ;;   Helper:
  ;;     $render_ty(ty) -> String
  ;;       — recursive walker over the 14 Ty variants per ty.wat tag
  ;;         conventions. Renders to human-readable text for diagnostic
  ;;         message construction. Cycle bound at depth 10 (diagnostic
  ;;         messages should be readable, not exhaustive); on overflow
  ;;         renders "..." per common type-printer convention. Per H6
  ;;         wildcard discipline: every Ty variant has its arm explicit;
  ;;         trap on unknown via (unreachable).
  ;;
  ;; Diagnostics NOT emitted by Hβ.infer (deferred to peer chunks per
  ;; their respective walkthroughs):
  ;;
  ;;   docs/errors/E_PurityViolated      — emitted by row-side (spec 01
  ;;                                       effects.nx unify_row); the
  ;;                                       seed's row.wat sibling-emit
  ;;                                       chunk lands these when row-
  ;;                                       diagnostic substrate emerges.
  ;;   docs/errors/E_EffectMismatch      — same (row-side).
  ;;   docs/errors/E_OwnershipViolation  — emitted by own.wat affine
  ;;                                       ledger handler (Tier 7 chunk
  ;;                                       per Hβ-infer §8.1 own.wat
  ;;                                       row); composes via the same
  ;;                                       $eprint_string + $graph_bind
  ;;                                       discipline.
  ;;   docs/errors/E_RefinementRejected  — emitted by verify.wat SMT
  ;;                                       swap (Arc F.1, B.6); ledger
  ;;                                       in seed accumulates.
  ;;   docs/errors/E_ReplayExhausted     — emitted by clock.nx replay
  ;;                                       handlers (post-L1 substrate).
  ;;   docs/errors/E_UnresolvedType      — emitted by Hβ.lower's
  ;;                                       lookup_ty_graph handler (Layer
  ;;                                       5 chunk per Hβ-lower-substrate
  ;;                                       walkthrough — pending); not
  ;;                                       an inference diagnostic.
  ;;   docs/errors/V_Pending             — emitted by verify_ledger
  ;;                                       handler in verify.wat (already
  ;;                                       landed Tier 4 per runtime/
  ;;                                       INDEX.tsv); informational
  ;;                                       per V_Pending.md.
  ;;   docs/errors/W_Suggestion +
  ;;     T_Gradient + T_ContinuationEscapes — emitted by Mentl tentacles
  ;;                                       (spec 09; post-L1 substrate
  ;;                                       per H5 walkthrough — pending).
  ;;   docs/errors/P_ExpectedToken +
  ;;     P_UnexpectedToken               — emitted by parser.wat (Layer
  ;;                                       3 chunks already landed per
  ;;                                       parser_*.wat); not infer.
  ;;
  ;;   ROADMAP item 4 — Diagnostic Boundary Canonicalization (closed
  ;;   this commit): The four codes E_NotARecordType /
  ;;   E_RecordFieldExtra / E_RecordFieldMissing /
  ;;   E_CannotNegateCapability previously sat as deferred-without-
  ;;   catalog-files; canonical src/infer.nx (lines 609, 1406+1442,
  ;;   1415+1434, 433) DOES emit them. Per drift mode 9 + ROADMAP §4
  ;;   acceptance ("no bootstrap header or walkthrough text says 'not
  ;;   emitted by Hβ.infer' when canonical src/infer.nx does emit
  ;;   it"): catalog files landed + helpers landed in this commit.
  ;;   E_CannotNegateCapability's earlier deferral cited "wait for
  ;;   SchemeKind to grow CapabilityScheme"; ROADMAP item 2 (commit
  ;;   63b25ce) made CapabilityScheme canonical, so the deferral is
  ;;   structurally closed.
  ;;
  ;; No new tag region required:
  ;;   This chunk doesn't introduce its own ADT records — it composes
  ;;   on str.wat (messages), reason.wat (Reason constructors per the
  ;;   23-variant ADT), graph.wat (NErrorHole NodeKind + $graph_bind).
  ;;   No tag allocation in this chunk.
  ;;
  ;; ═══ EIGHT INTERROGATIONS (per Hβ-infer-substrate.md §6 applied
  ;;                            to emit_diag) ════════════════════════
  ;;
  ;; 1. Graph?      emit_diag MUTATES the graph by binding offending
  ;;                handles to NErrorHole(reason) via $graph_bind +
  ;;                $node_kind_make_nerrorhole. The graph IS the
  ;;                productive-under-error substrate; downstream
  ;;                ($lookup_ty / $chase_deep) sees the NErrorHole +
  ;;                renders the wrapped Reason as the diagnostic context
  ;;                rather than encountering an unbound TVar. Per spec
  ;;                04 §Error handling L210-216.
  ;;
  ;; 2. Handler?    Direct functions at the seed level. The wheel's
  ;;                compiled form routes $infer_emit_* through the
  ;;                `report` effect handler chain (spec 06 +
  ;;                src/diagnostic.nx canonical default handler). One
  ;;                function, two handler paths — seed writes directly
  ;;                to stderr; wheel routes the same payload through
  ;;                the report effect's @resume=OneShot arm. The
  ;;                default `report` handler the seed installs at
  ;;                compile-entry IS this chunk's discipline.
  ;;
  ;; 3. Verb?       N/A at substrate level — emit_diag helpers are
  ;;                direct calls from walk arm sites, not pipeline
  ;;                stages. Diagnostic messages flow `walk arm |>
  ;;                $infer_emit_<code>` at the call site — single-
  ;;                stage; no chain.
  ;;
  ;; 4. Row?        emit_diag's helpers themselves are EnvWrite +
  ;;                GraphWrite + Diagnostic effectful in the wheel's
  ;;                compiled form (the wheel declares `with EnvWrite +
  ;;                GraphWrite + Diagnostic`); seed projects as direct
  ;;                $eprint_string (Diagnostic) + $graph_bind
  ;;                (GraphWrite). EnvWrite is unused here (no env
  ;;                mutation; binding is graph-side).
  ;;
  ;; 5. Ownership?  Message strings constructed via $str_concat are
  ;;                `own` by the bump allocator; ty/reason refs are
  ;;                `ref` (not consumed). The bump allocator is monotonic
  ;;                (CLAUDE.md memory model) so messages persist for
  ;;                the program's lifetime — that's fine; diagnostics
  ;;                are at-most-tens per compile.
  ;;
  ;; 6. Refinement? N/A at the diagnostic level. (TRefined Ty payloads
  ;;                pass through $render_ty's TRefined arm verbatim;
  ;;                rendering preserves the predicate's existence
  ;;                marker but doesn't structurally render it — the
  ;;                Predicate ADT lives in verify.wat substrate.)
  ;;
  ;; 7. Gradient?   Each diagnostic IS a gradient signal — Mentl's
  ;;                voice surfaces here per spec 04 §Error handling +
  ;;                spec 09 + the "every diagnostic IS a gradient
  ;;                signal" voice substrate. The seed's stderr write
  ;;                is the Tier-6 base; the wheel's Mentl tentacle
  ;;                composes ON this chunk's $infer_emit_* boundary +
  ;;                surfaces richer voice (canonical fix proposals,
  ;;                Levenshtein W_Suggestion arms, Why Engine walks).
  ;;
  ;; 8. Reason?     Diagnostic emission CARRIES a Reason — every helper
  ;;                takes a `reason` parameter the caller constructed
  ;;                at the walk site (typically Located(span,
  ;;                inner_reason)); the NErrorHole NodeKind wraps a
  ;;                separate diagnostic-payload Reason
  ;;                (UnifyFailed(a,b) / MissingVar(name) /
  ;;                Inferred("occurs check")) so downstream Why Engine
  ;;                walks see BOTH the cause-chain Reason AND the
  ;;                diagnostic-class Reason. Per spec 00 GNode =
  ;;                (NodeKind, Reason) — both fields populated.
  ;;
  ;; ═══ FORBIDDEN PATTERNS AUDIT (per Hβ-infer-substrate.md §7
  ;;                               applied to emit_diag) ════════════
  ;;
  ;; - Drift 1 (Rust vtable):           $render_ty is recursive direct
  ;;                                    dispatch on $ty_tag; the
  ;;                                    $infer_emit_<code> family is
  ;;                                    seven peer functions, not a
  ;;                                    table of "diagnostic emitters"
  ;;                                    indexed by code-id. No vtable.
  ;; - Drift 2 (Scheme env frame):      No `current_diagnostic_context`
  ;;                                    parameter threaded through every
  ;;                                    helper; each call carries its
  ;;                                    own (handle, ty/name, reason)
  ;;                                    args.
  ;; - Drift 3 (Python dict / string):  Error codes are string constants
  ;;                                    emitted directly via $str_from_mem
  ;;                                    from data-segment offsets — NOT
  ;;                                    looked up via `if str_eq(code,
  ;;                                    "E_TypeMismatch")` enum dispatch.
  ;;                                    Per Anchor 1: the catalog's
  ;;                                    code IS the name; the substrate
  ;;                                    matches with NO further encoding.
  ;; - Drift 4 (Haskell monad transformer): Each helper is a direct
  ;;                                    function call from walk-arm
  ;;                                    site; no `EmitM` / `DiagM`
  ;;                                    monad wrapping.
  ;; - Drift 5 (C calling convention):  Helpers take direct i32 params
  ;;                                    (handle, payload(s), reason);
  ;;                                    no bundled "diagnostic context
  ;;                                    struct + state ptr" pseudo-state.
  ;; - Drift 6 (primitive-type-special-case): $render_ty handles all
  ;;                                    14 Ty variants uniformly via
  ;;                                    explicit arms — TInt has no
  ;;                                    special-case rendering beyond
  ;;                                    its sentinel-string lookup.
  ;; - Drift 7 (parallel-arrays):       Diagnostic message construction
  ;;                                    uses sequential $str_concat
  ;;                                    chains, NOT parallel
  ;;                                    `(message_parts[], part_lens[])`
  ;;                                    arrays. Reason DAGs are
  ;;                                    constructed via record-shape
  ;;                                    Reason ADT (reason.wat tags),
  ;;                                    NOT parallel
  ;;                                    `(diag_codes[], diag_payloads[])`.
  ;; - Drift 8 (mode flag):             $infer_emit_<code> family is
  ;;                                    seven peer functions per code
  ;;                                    (not one $infer_emit(handle,
  ;;                                    code: Int, payload: i32, reason:
  ;;                                    i32) with int-coded dispatch).
  ;;                                    Per drift-pattern 8: every flag
  ;;                                    OR enum-as-int is an ADT begging
  ;;                                    to exist; here, the ADT IS the
  ;;                                    code-name + per-code helper
  ;;                                    function pair, peer with the
  ;;                                    Reason ADT.
  ;; - Drift 9 (deferred-by-omission):  EVERY helper named in §8.1
  ;;                                    (3 core) PLUS every additional
  ;;                                    catalog code Hβ.infer can emit
  ;;                                    (E_FeedbackNoContext,
  ;;                                    E_HandlerUninstallable,
  ;;                                    E_PatternInexhaustive,
  ;;                                    T_OverDeclared, E_NotARecordType,
  ;;                                    E_RecordFieldExtra,
  ;;                                    E_RecordFieldMissing,
  ;;                                    E_CannotNegateCapability) gets
  ;;                                    its $infer_emit_<code> function in
  ;;                                    THIS chunk. Diagnostics deferred
  ;;                                    to peer chunks (own.wat
  ;;                                    OwnershipViolation; row.wat
  ;;                                    PurityViolated/EffectMismatch;
  ;;                                    lower.wat UnresolvedType) are
  ;;                                    NAMED in the design header
  ;;                                    above as their substrate
  ;;                                    location, not buried as TODOs.
  ;;
  ;; - Foreign fluency — exception machinery: NO "throw" / "panic" /
  ;;                                    "unwind" / "exception" / "catch"
  ;;                                    vocabulary. The graph's
  ;;                                    NErrorHole IS the productive-
  ;;                                    under-error substrate per spec
  ;;                                    04 §Error handling Hazel
  ;;                                    pattern. Every $infer_emit_*
  ;;                                    returns void; control returns
  ;;                                    to the walk arm; the walk
  ;;                                    continues per Hazel POPL 2024.
  ;;
  ;; - Foreign fluency — log levels:    NO "info" / "debug" / "warn" /
  ;;                                    "error" enum dispatch. The
  ;;                                    diagnostic kind is the catalog
  ;;                                    code's prefix (E_/V_/W_/T_/P_)
  ;;                                    per docs/errors/README.md L24-31;
  ;;                                    helpers don't take a log-level
  ;;                                    parameter.

  ;; ─── Data segment — diagnostic message fragments ──────────────────
  ;;
  ;; All diagnostic message strings live in the data segment per the
  ;; ty.wat / scheme.wat precedent. Length-prefixed flat-string layout
  ;; ([len:i32][bytes...]). Offsets sit above scheme.wat's "inst"
  ;; constant at 1620 (8 bytes consumed; next 8-byte-aligned offset =
  ;; 1632) and well below HEAP_BASE = 4096 per CLAUDE.md memory model.
  ;;
  ;; Layout (each entry padded to 8-byte boundary for alignment):

  ;; ── Code-prefix strings (per docs/errors/ catalog naming) ─────────
  (data (i32.const 1632) "\10\00\00\00E_TypeMismatch: ")              ;; 16 bytes payload
  (data (i32.const 1656) "\13\00\00\00E_MissingVariable: ")            ;; 19 bytes payload
  (data (i32.const 1680) "\0f\00\00\00E_OccursCheck: ")                ;; 15 bytes payload
  (data (i32.const 1704) "\15\00\00\00E_FeedbackNoContext: ")          ;; 21 bytes payload
  (data (i32.const 1736) "\18\00\00\00E_HandlerUninstallable: ")       ;; 24 bytes payload
  (data (i32.const 1768) "\17\00\00\00E_PatternInexhaustive: ")        ;; 23 bytes payload
  (data (i32.const 1800) "\10\00\00\00T_OverDeclared: ")               ;; 16 bytes payload

  ;; ── Connector phrases ─────────────────────────────────────────────
  (data (i32.const 1824) "\0b\00\00\00 at handle ")                    ;; 11 bytes payload
  (data (i32.const 1840) "\0e\00\00\00 — expected ")                   ;; 14 bytes payload (em-dash 3 bytes; " — expected " is 14 bytes UTF-8)
  ;; Note: ", found " (offset 1856 in earlier draft) overlapped with
  ;; preceding " — expected " (UTF-8 14 bytes ending 1858). Relocated
  ;; to safe offset 2864 below.
  (data (i32.const 1872) "\10\00\00\00 (infinite type)")               ;; 16 bytes payload
  (data (i32.const 1896) "\0c\00\00\00occurs check")                   ;; 12 bytes payload
  (data (i32.const 1912) "\01\00\00\00\0a")                            ;; "\n" — 1 byte payload
  (data (i32.const 1920) "\14\00\00\00 occurs in type tree")           ;; 20 bytes payload

  ;; ── E_FeedbackNoContext message body ──────────────────────────────
  (data (i32.const 1944) "\30\00\00\00<~ requires an ambient iterative-context handler")  ;; 48 bytes payload

  ;; ── E_HandlerUninstallable message body ───────────────────────────
  (data (i32.const 2000) "\3a\00\00\00handler arms require effects not admitted by enclosing row")  ;; 58 bytes payload

  ;; ── E_PatternInexhaustive message body ────────────────────────────
  (data (i32.const 2072) "\2f\00\00\00match does not cover every variant of scrutinee")  ;; 47 bytes payload

  ;; ── T_OverDeclared message body ───────────────────────────────────
  (data (i32.const 2128) "\32\00\00\00declared row strictly wider than inferred body row")  ;; 50 bytes payload

  ;; ── Reason payload context strings (passed to $reason_make_inferred
  ;;    for the four additional helpers) ─────────────────────────────
  (data (i32.const 2192) "\13\00\00\00feedback no context")            ;; 19 bytes payload — for E_FeedbackNoContext
  (data (i32.const 2216) "\15\00\00\00handler uninstallable")          ;; 21 bytes payload
  ;; Note: "pattern inexhaustive" (offset 2240 in earlier draft) overlapped
  ;; with preceding "handler uninstallable" (21 bytes ending 2241).
  ;; Relocated to safe offset 2880 below.
  (data (i32.const 2264) "\0d\00\00\00over-declared")                  ;; 13 bytes payload

  ;; ── Ty rendering — variant name strings ───────────────────────────
  (data (i32.const 2288) "\03\00\00\00Int")                            ;; 3 bytes
  (data (i32.const 2296) "\05\00\00\00Float")                          ;; 5 bytes
  (data (i32.const 2312) "\06\00\00\00String")                         ;; 6 bytes
  (data (i32.const 2328) "\02\00\00\00()")                             ;; 2 bytes (TUnit)
  (data (i32.const 2336) "\01\00\00\00?")                              ;; 1 byte (TVar prefix)
  (data (i32.const 2344) "\05\00\00\00List<")                          ;; 5 bytes
  (data (i32.const 2360) "\01\00\00\00>")                              ;; 1 byte
  (data (i32.const 2368) "\01\00\00\00(")                              ;; 1 byte (TTuple open)
  (data (i32.const 2376) "\01\00\00\00)")                              ;; 1 byte (TTuple close)
  (data (i32.const 2384) "\02\00\00\00, ")                             ;; 2 bytes (separator)
  (data (i32.const 2392) "\0b\00\00\00fn(...) -> ")                    ;; 11 bytes (TFun prefix; full row rendering deferred)
  (data (i32.const 2408) "\05\00\00\00{...}")                          ;; 5 bytes (TRecord/TRecordOpen)
  ;; Note: " where ..." (offset 2416 in earlier draft) overlapped with
  ;; preceding "{...}" (9 bytes ending 2417). Relocated to safe offset
  ;; 2896 below.
  (data (i32.const 2432) "\05\00\00\00Cont<")                          ;; 5 bytes (TCont prefix)
  ;; Note: "<" (offset 2440 in earlier draft) overlapped with preceding
  ;; "Cont<" (9 bytes ending 2441). Relocated to safe offset 2912 below.
  (data (i32.const 2448) "\03\00\00\00...")                            ;; 3 bytes (cycle-bound overflow)

  ;; ── Code-prefix strings for canonicalization-lane additions ──────
  (data (i32.const 2456) "\12\00\00\00E_NotARecordType: ")               ;; 18 bytes payload
  (data (i32.const 2480) "\14\00\00\00E_RecordFieldExtra: ")             ;; 20 bytes payload
  (data (i32.const 2504) "\16\00\00\00E_RecordFieldMissing: ")           ;; 22 bytes payload
  (data (i32.const 2536) "\1a\00\00\00E_CannotNegateCapability: ")       ;; 26 bytes payload

  ;; ── Message-body fragments (concatenated with dynamic values) ────
  (data (i32.const 2568) "\15\00\00\00 is not a record type")            ;; 21 bytes (E_NotARecordType tail)
  (data (i32.const 2600) "\22\00\00\00record literal has unknown field '") ;; 34 bytes (E_RecordFieldExtra head)
  (data (i32.const 2640) "\0b\00\00\00' for type ")                      ;; 11 bytes (shared field tail)
  (data (i32.const 2656) "\1e\00\00\00record literal missing field '")   ;; 30 bytes (E_RecordFieldMissing head)
  (data (i32.const 2696) "\21\00\00\00cannot negate capability bundle '") ;; 33 bytes (E_CannotNegateCapability head)
  (data (i32.const 2736) "\01\00\00\00'")                                 ;; 1 byte (closing quote)

  ;; ── Reason-context strings (for $reason_make_inferred) ───────────
  (data (i32.const 2744) "\11\00\00\00not a record type")                ;; 17 bytes
  (data (i32.const 2768) "\12\00\00\00record field extra")               ;; 18 bytes
  (data (i32.const 2792) "\14\00\00\00record field missing")             ;; 20 bytes
  (data (i32.const 2824) "\18\00\00\00cannot negate capability")         ;; 24 bytes

  ;; ── Relocated overlap-conflict segments (safe slots above 2853) ──
  (data (i32.const 2864) "\08\00\00\00, found ")                          ;; 8 bytes (was 1856)
  (data (i32.const 2880) "\14\00\00\00pattern inexhaustive")              ;; 20 bytes (was 2240)
  (data (i32.const 2912) "\0a\00\00\00 where ...")                        ;; 10 bytes (was 2416)
  (data (i32.const 2928) "\01\00\00\00<")                                 ;; 1 byte (was 2440)

  ;; ─── $render_ty — Ty walker producing human-readable string ──────
  ;;
  ;; Per the 14 Ty variants in ty.wat (tag conventions §2.3). Cycle
  ;; bound at depth 10 — diagnostic messages should be readable, not
  ;; exhaustive; on overflow renders "..." per common type-printer
  ;; convention.
  ;;
  ;; Per H6 wildcard discipline + drift mode 9: every Ty variant has
  ;; its arm explicit; trap on unknown via (unreachable). The 14
  ;; variants are 100/101/102/103/104/105/106/107/108/109/110/111/112/113
  ;; per ty.wat tag conventions.
  ;;
  ;; Coverage discipline:
  ;;   - Nullary sentinels (TInt/TFloat/TString/TUnit): static name string.
  ;;   - TVar(h): "?<int_to_str(h)>".
  ;;   - TList(elem): "List<" + render(elem) + ">".
  ;;   - TTuple(elems): "(" + comma-joined render of each element + ")".
  ;;   - TFun(params, ret, row): "fn(...) -> " + render(ret).
  ;;     Full params + row rendering deferred — TParam substrate +
  ;;     row.wat render not yet landed; render the return type as the
  ;;     load-bearing diagnostic surface (the wheel src/types.nx:815
  ;;     show_type does fuller rendering; the seed's diagnostic surface
  ;;     reads the return type for unify mismatch context).
  ;;   - TName(name, args): name + (if args: "<" + comma-joined render
  ;;     of each arg + ">"; else: just name).
  ;;   - TRecord, TRecordOpen: "{...}" — fields opaque per same
  ;;     substrate-pending discipline as ty.wat $chase_deep.
  ;;   - TRefined(base, _): render(base) + " where ..." — predicate
  ;;     opaque per verify.wat:39 precedent (Predicate ADT lives in
  ;;     verify.wat substrate).
  ;;   - TCont(ret, _): "Cont<" + render(ret) + ">" — discipline
  ;;     sentinel rendering deferred (3 sentinels at 250/251/252;
  ;;     per ty.wat $is_resume_* predicates available; rendering
  ;;     would be additive when needed).
  ;;   - TAlias(name, _): name verbatim — preserves authored alias
  ;;     per RN.1 substrate (intent-aware; $chase_deep also preserves
  ;;     TAlias per ty.wat:551-552 + src/types.nx:48).

  (func $render_ty (param $ty i32) (result i32)
    (call $render_ty_loop (local.get $ty) (i32.const 0)))

  (func $render_ty_loop (param $ty i32) (param $depth i32) (result i32)
    (local $tag i32) (local $h i32) (local $hs i32)
    ;; Cycle bound — diagnostic readability over exhaustive rendering
    (if (i32.gt_u (local.get $depth) (i32.const 10))
      (then (return (i32.const 2448))))            ;; "..."
    (local.set $tag (call $ty_tag (local.get $ty)))
    ;; ── Nullary Ty sentinels ──────────────────────────────────────
    (if (i32.eq (local.get $tag) (i32.const 100))   ;; TInt
      (then (return (i32.const 2288))))
    (if (i32.eq (local.get $tag) (i32.const 101))   ;; TFloat
      (then (return (i32.const 2296))))
    (if (i32.eq (local.get $tag) (i32.const 102))   ;; TString
      (then (return (i32.const 2312))))
    (if (i32.eq (local.get $tag) (i32.const 103))   ;; TUnit
      (then (return (i32.const 2328))))
    ;; ── TVar(h) — "?" + int_to_str(h) ─────────────────────────────
    (if (i32.eq (local.get $tag) (i32.const 104))
      (then
        (local.set $h (call $ty_tvar_handle (local.get $ty)))
        (local.set $hs (call $int_to_str (local.get $h)))
        (return (call $str_concat (i32.const 2336) (local.get $hs)))))
    ;; ── TList(elem) — "List<" + render(elem) + ">" ────────────────
    (if (i32.eq (local.get $tag) (i32.const 105))
      (then (return
        (call $str_concat
          (call $str_concat
            (i32.const 2344)                                ;; "List<"
            (call $render_ty_loop
              (call $ty_tlist_elem (local.get $ty))
              (i32.add (local.get $depth) (i32.const 1))))
          (i32.const 2360)))))                              ;; ">"
    ;; ── TTuple(elems) — "(" + comma-joined renders + ")" ──────────
    (if (i32.eq (local.get $tag) (i32.const 106))
      (then (return
        (call $str_concat
          (call $str_concat
            (i32.const 2368)                                ;; "("
            (call $render_ty_list
              (call $ty_ttuple_elems (local.get $ty))
              (i32.add (local.get $depth) (i32.const 1))))
          (i32.const 2376)))))                              ;; ")"
    ;; ── TFun(params, ret, row) — "fn(...) -> " + render(ret) ──────
    (if (i32.eq (local.get $tag) (i32.const 107))
      (then (return
        (call $str_concat
          (i32.const 2392)                                  ;; "fn(...) -> "
          (call $render_ty_loop
            (call $ty_tfun_return (local.get $ty))
            (i32.add (local.get $depth) (i32.const 1)))))))
    ;; ── TName(name, args) — name + ("<" + arg-list + ">" if args) ─
    (if (i32.eq (local.get $tag) (i32.const 108))
      (then (return
        (call $render_tname
          (call $ty_tname_name (local.get $ty))
          (call $ty_tname_args (local.get $ty))
          (i32.add (local.get $depth) (i32.const 1))))))
    ;; ── TRecord(fields) — "{...}" (fields opaque) ─────────────────
    (if (i32.eq (local.get $tag) (i32.const 109))
      (then (return (i32.const 2408))))
    ;; ── TRecordOpen(fields, rowvar) — "{...}" (same opaque) ───────
    (if (i32.eq (local.get $tag) (i32.const 110))
      (then (return (i32.const 2408))))
    ;; ── TRefined(base, pred) — render(base) + " where ..." ────────
    (if (i32.eq (local.get $tag) (i32.const 111))
      (then (return
        (call $str_concat
          (call $render_ty_loop
            (call $ty_trefined_base (local.get $ty))
            (i32.add (local.get $depth) (i32.const 1)))
          (i32.const 2912)))))                              ;; " where ..." (relocated from 2416)
    ;; ── TCont(ret, disc) — "Cont<" + render(ret) + ">" ────────────
    (if (i32.eq (local.get $tag) (i32.const 112))
      (then (return
        (call $str_concat
          (call $str_concat
            (i32.const 2432)                                ;; "Cont<"
            (call $render_ty_loop
              (call $ty_tcont_return (local.get $ty))
              (i32.add (local.get $depth) (i32.const 1))))
          (i32.const 2360)))))                              ;; ">"
    ;; ── TAlias(name, resolved) — name verbatim (intent-aware) ─────
    (if (i32.eq (local.get $tag) (i32.const 113))
      (then (return (call $ty_talias_name (local.get $ty)))))
    ;; ── Unknown tag — well-formed Ty cannot get here. Trap. ───────
    (unreachable))

  ;; $render_tname(name, args, depth) — TName helper. If args list is
  ;; non-empty, renders "name<arg1, arg2, ...>"; else just "name".
  (func $render_tname (param $name i32) (param $args i32) (param $depth i32)
                       (result i32)
    (if (i32.eqz (call $len (local.get $args)))
      (then (return (local.get $name))))
    (call $str_concat
      (call $str_concat
        (call $str_concat (local.get $name) (i32.const 2928))   ;; name + "<" (relocated from 2440)
        (call $render_ty_list (local.get $args) (local.get $depth)))
      (i32.const 2360)))                                         ;; ">"

  ;; $render_ty_list(tys, depth) — renders a flat list of Ty pointers
  ;; as comma-separated text. Returns "" for empty list (callers wrap
  ;; with delimiters).
  (func $render_ty_list (param $tys i32) (param $depth i32) (result i32)
    (local $n i32) (local $i i32) (local $out i32)
    (local.set $n (call $len (local.get $tys)))
    (local.set $out (call $str_alloc (i32.const 0)))
    (local.set $i (i32.const 0))
    (block $done
      (loop $iter
        (br_if $done (i32.ge_u (local.get $i) (local.get $n)))
        ;; Append separator before non-first element
        (if (i32.gt_u (local.get $i) (i32.const 0))
          (then
            (local.set $out (call $str_concat (local.get $out) (i32.const 2384)))))  ;; ", "
        (local.set $out (call $str_concat (local.get $out)
          (call $render_ty_loop
            (call $list_index (local.get $tys) (local.get $i))
            (local.get $depth))))
        (local.set $i (i32.add (local.get $i) (i32.const 1)))
        (br $iter)))
    (local.get $out))

  ;; ─── $infer_emit_type_mismatch — E_TypeMismatch helper ──────────
  ;;
  ;; Per spec 04 §Unification + §Error handling + docs/errors/
  ;; E_TypeMismatch.md. Emitted by $unify_shapes when no Ty-pair arm
  ;; matches. Message: "E_TypeMismatch: at handle <h> — expected
  ;; <render(ty_a)>, found <render(ty_b)>\n". Reason payload:
  ;; UnifyFailed(ty_a, ty_b) per reason.wat tag 233.
  (func $infer_emit_type_mismatch (param $handle i32) (param $ty_a i32)
                                    (param $ty_b i32) (param $reason i32)
    (local $msg i32)
    ;; Construct message: "E_TypeMismatch: at handle <h> — expected
    ;; <render(a)>, found <render(b)>\n"
    (local.set $msg (i32.const 1632))                          ;; "E_TypeMismatch: "
    (local.set $msg (call $str_concat (local.get $msg) (i32.const 1824)))   ;; "at handle "
    (local.set $msg (call $str_concat (local.get $msg) (call $int_to_str (local.get $handle))))
    (local.set $msg (call $str_concat (local.get $msg) (i32.const 1840)))   ;; " — expected "
    (local.set $msg (call $str_concat (local.get $msg) (call $render_ty (local.get $ty_a))))
    (local.set $msg (call $str_concat (local.get $msg) (i32.const 2864)))   ;; ", found " (relocated from 1856)
    (local.set $msg (call $str_concat (local.get $msg) (call $render_ty (local.get $ty_b))))
    (local.set $msg (call $str_concat (local.get $msg) (i32.const 1912)))   ;; "\n"
    ;; Write to stderr (fd 2)
    (call $eprint_string (local.get $msg))
    ;; Bind handle to NErrorHole(UnifyFailed(ty_a, ty_b))
    (call $graph_bind_kind
      (local.get $handle)
      (call $node_kind_make_nerrorhole
        (call $reason_make_unifyfailed (local.get $ty_a) (local.get $ty_b)))
      (local.get $reason)))

  ;; ─── $infer_emit_missing_var — E_MissingVariable helper ─────────
  ;;
  ;; Per spec 04 §Instantiations L113-116 + docs/errors/
  ;; E_MissingVariable.md. Emitted by VarRef arm on env_lookup miss.
  ;; Message: "E_MissingVariable: '<name>' at handle <h>\n". Reason
  ;; payload: MissingVar(name) per reason.wat tag 236.
  (func $infer_emit_missing_var (param $handle i32) (param $name i32)
                                  (param $reason i32)
    (local $msg i32)
    ;; Construct message: "E_MissingVariable: <name> at handle <h>\n"
    (local.set $msg (i32.const 1656))                          ;; "E_MissingVariable: "
    (local.set $msg (call $str_concat (local.get $msg) (local.get $name)))
    (local.set $msg (call $str_concat (local.get $msg) (i32.const 1824)))   ;; " at handle "
    (local.set $msg (call $str_concat (local.get $msg) (call $int_to_str (local.get $handle))))
    (local.set $msg (call $str_concat (local.get $msg) (i32.const 1912)))   ;; "\n"
    (call $eprint_string (local.get $msg))
    ;; Bind handle to NErrorHole(MissingVar(name))
    (call $graph_bind_kind
      (local.get $handle)
      (call $node_kind_make_nerrorhole
        (call $reason_make_missingvar (local.get $name)))
      (local.get $reason)))

  ;; ─── $infer_emit_occurs_check — E_OccursCheck helper ────────────
  ;;
  ;; Per spec 04 §Occurs check + docs/errors/E_OccursCheck.md. Emitted
  ;; by $unify when a bind would close a TVar→Ty cycle. Message:
  ;; "E_OccursCheck: at handle <h> occurs in type tree (infinite type)
  ;; — <render(ty)>\n". Reason payload: Inferred("occurs check") per
  ;; reason.wat tag 221.
  (func $infer_emit_occurs_check (param $handle i32) (param $ty i32)
                                   (param $reason i32)
    (local $msg i32)
    ;; Construct message: "E_OccursCheck: at handle <h> occurs in
    ;; type tree (infinite type) — <render(ty)>\n"
    (local.set $msg (i32.const 1680))                          ;; "E_OccursCheck: "
    (local.set $msg (call $str_concat (local.get $msg) (i32.const 1824)))   ;; "at handle "
    (local.set $msg (call $str_concat (local.get $msg) (call $int_to_str (local.get $handle))))
    (local.set $msg (call $str_concat (local.get $msg) (i32.const 1920)))   ;; " occurs in type tree"
    (local.set $msg (call $str_concat (local.get $msg) (i32.const 1872)))   ;; " (infinite type)"
    (local.set $msg (call $str_concat (local.get $msg) (i32.const 1840)))   ;; " — expected "
    (local.set $msg (call $str_concat (local.get $msg) (call $render_ty (local.get $ty))))
    (local.set $msg (call $str_concat (local.get $msg) (i32.const 1912)))   ;; "\n"
    (call $eprint_string (local.get $msg))
    ;; Bind handle to NErrorHole(Inferred("occurs check"))
    (call $graph_bind_kind
      (local.get $handle)
      (call $node_kind_make_nerrorhole
        (call $reason_make_inferred (i32.const 1896)))         ;; "occurs check"
      (local.get $reason)))

  ;; ─── $infer_emit_feedback_no_context — E_FeedbackNoContext ──────
  ;;
  ;; Per spec 04 + docs/errors/E_FeedbackNoContext.md. Emitted by `<~`
  ;; arm in walk_expr when no iterative-context handler (Clock/Tick/
  ;; Sample) is in scope. Message: "E_FeedbackNoContext: at handle <h>
  ;; — <~ requires an ambient iterative-context handler\n". Reason
  ;; payload: Inferred("feedback no context").
  (func $infer_emit_feedback_no_context (param $handle i32) (param $reason i32)
    (local $msg i32)
    (local.set $msg (i32.const 1704))                          ;; "E_FeedbackNoContext: "
    (local.set $msg (call $str_concat (local.get $msg) (i32.const 1824)))   ;; "at handle "
    (local.set $msg (call $str_concat (local.get $msg) (call $int_to_str (local.get $handle))))
    (local.set $msg (call $str_concat (local.get $msg) (i32.const 1840)))   ;; " — "
    (local.set $msg (call $str_concat (local.get $msg) (i32.const 1944)))   ;; "<~ requires …"
    (local.set $msg (call $str_concat (local.get $msg) (i32.const 1912)))   ;; "\n"
    (call $eprint_string (local.get $msg))
    (call $graph_bind_kind
      (local.get $handle)
      (call $node_kind_make_nerrorhole
        (call $reason_make_inferred (i32.const 2192)))         ;; "feedback no context"
      (local.get $reason)))

  ;; ─── $infer_emit_handler_uninstallable — E_HandlerUninstallable ─
  ;;
  ;; Per spec I14/I16 + docs/errors/E_HandlerUninstallable.md +
  ;; src/infer.nx:680. Emitted by HandleExpr arm when handler arm
  ;; effects exceed the enclosing fn's declared row. Message:
  ;; "E_HandlerUninstallable: at handle <h> — handler arms require
  ;; effects not admitted by enclosing row\n". Reason payload:
  ;; Inferred("handler uninstallable").
  (func $infer_emit_handler_uninstallable (param $handle i32) (param $reason i32)
    (local $msg i32)
    (local.set $msg (i32.const 1736))                          ;; "E_HandlerUninstallable: "
    (local.set $msg (call $str_concat (local.get $msg) (i32.const 1824)))   ;; "at handle "
    (local.set $msg (call $str_concat (local.get $msg) (call $int_to_str (local.get $handle))))
    (local.set $msg (call $str_concat (local.get $msg) (i32.const 1840)))   ;; " — "
    (local.set $msg (call $str_concat (local.get $msg) (i32.const 2000)))   ;; "handler arms require…"
    (local.set $msg (call $str_concat (local.get $msg) (i32.const 1912)))   ;; "\n"
    (call $eprint_string (local.get $msg))
    (call $graph_bind_kind
      (local.get $handle)
      (call $node_kind_make_nerrorhole
        (call $reason_make_inferred (i32.const 2216)))         ;; "handler uninstallable"
      (local.get $reason)))

  ;; ─── $infer_emit_pattern_inexhaustive — E_PatternInexhaustive ───
  ;;
  ;; Per spec 04 + docs/errors/E_PatternInexhaustive.md +
  ;; src/infer.nx:1712. Emitted by MatchExpr arm when match's arms
  ;; don't cover every variant of scrutinee's ADT. Message:
  ;; "E_PatternInexhaustive: at handle <h> — match does not cover
  ;; every variant of scrutinee\n". Reason payload:
  ;; Inferred("pattern inexhaustive").
  (func $infer_emit_pattern_inexhaustive (param $handle i32) (param $reason i32)
    (local $msg i32)
    (local.set $msg (i32.const 1768))                          ;; "E_PatternInexhaustive: "
    (local.set $msg (call $str_concat (local.get $msg) (i32.const 1824)))   ;; "at handle "
    (local.set $msg (call $str_concat (local.get $msg) (call $int_to_str (local.get $handle))))
    (local.set $msg (call $str_concat (local.get $msg) (i32.const 1840)))   ;; " — "
    (local.set $msg (call $str_concat (local.get $msg) (i32.const 2072)))   ;; "match does not cover…"
    (local.set $msg (call $str_concat (local.get $msg) (i32.const 1912)))   ;; "\n"
    (call $eprint_string (local.get $msg))
    (call $graph_bind_kind
      (local.get $handle)
      (call $node_kind_make_nerrorhole
        (call $reason_make_inferred (i32.const 2880)))         ;; "pattern inexhaustive" (relocated from 2240)
      (local.get $reason)))

  ;; ─── $infer_emit_over_declared — T_OverDeclared (Warning kind) ──
  ;;
  ;; Per spec I19 + docs/errors/T_OverDeclared.md + src/infer.nx:330.
  ;; Emitted by FnStmt declared-effects check when the declared row is
  ;; strictly wider than the inferred body row. Warning kind, NOT
  ;; Error — does NOT bind to NErrorHole; the program is well-typed,
  ;; T_OverDeclared just teaches a tighter signature is possible.
  ;; Message: "T_OverDeclared: at handle <h> — declared row strictly
  ;; wider than inferred body row\n".
  ;;
  ;; Per the catalog file's "Warning (teaching)" classification: this
  ;; helper is the T_-prefix peer of the E_-prefix helpers above.
  ;; Discipline differs at the binding step — the FnStmt remains
  ;; well-typed; only stderr surfaces the teaching nudge.
  (func $infer_emit_over_declared (param $handle i32) (param $reason i32)
    (local $msg i32)
    (local.set $msg (i32.const 1800))                          ;; "T_OverDeclared: "
    (local.set $msg (call $str_concat (local.get $msg) (i32.const 1824)))   ;; "at handle "
    (local.set $msg (call $str_concat (local.get $msg) (call $int_to_str (local.get $handle))))
    (local.set $msg (call $str_concat (local.get $msg) (i32.const 1840)))   ;; " — "
    (local.set $msg (call $str_concat (local.get $msg) (i32.const 2128)))   ;; "declared row strictly…"
    (local.set $msg (call $str_concat (local.get $msg) (i32.const 1912)))   ;; "\n"
    (call $eprint_string (local.get $msg))
    ;; Drop unused parameter to satisfy WAT (reason carried by caller's
    ;; chain; T_OverDeclared does not bind to NErrorHole — the FnStmt
    ;; remains well-typed per the Warning classification).
    (drop (local.get $reason)))

  ;; ─── $infer_emit_not_a_record_type — E_NotARecordType ───────────
  ;;
  ;; Per spec 04 + docs/errors/E_NotARecordType.md + src/infer.nx:609.
  ;; Emitted by NamedRecordExpr arm when env_lookup resolves the
  ;; type-name to a non-RecordSchemeKind Scheme. Message:
  ;; "E_NotARecordType: at handle <h> — '<type_name>' is not a record
  ;; type\n". Reason payload: Inferred("not a record type").
  (func $infer_emit_not_a_record_type (param $handle i32) (param $type_name i32)
                                        (param $reason i32)
    (local $msg i32)
    (local.set $msg (i32.const 2456))                          ;; "E_NotARecordType: "
    (local.set $msg (call $str_concat (local.get $msg) (i32.const 1824)))   ;; "at handle "
    (local.set $msg (call $str_concat (local.get $msg) (call $int_to_str (local.get $handle))))
    (local.set $msg (call $str_concat (local.get $msg) (i32.const 1840)))   ;; " — "
    (local.set $msg (call $str_concat (local.get $msg) (i32.const 2736)))   ;; "'"
    (local.set $msg (call $str_concat (local.get $msg) (local.get $type_name)))
    (local.set $msg (call $str_concat (local.get $msg) (i32.const 2736)))   ;; "'"
    (local.set $msg (call $str_concat (local.get $msg) (i32.const 2568)))   ;; " is not a record type"
    (local.set $msg (call $str_concat (local.get $msg) (i32.const 1912)))   ;; "\n"
    (call $eprint_string (local.get $msg))
    (call $graph_bind_kind
      (local.get $handle)
      (call $node_kind_make_nerrorhole
        (call $reason_make_inferred (i32.const 2744)))         ;; "not a record type"
      (local.get $reason)))

  ;; ─── $infer_emit_record_field_extra — E_RecordFieldExtra ────────
  (func $infer_emit_record_field_extra (param $handle i32) (param $field_name i32)
                                         (param $type_name i32) (param $reason i32)
    (local $msg i32)
    (local.set $msg (i32.const 2480))
    (local.set $msg (call $str_concat (local.get $msg) (i32.const 1824)))
    (local.set $msg (call $str_concat (local.get $msg) (call $int_to_str (local.get $handle))))
    (local.set $msg (call $str_concat (local.get $msg) (i32.const 1840)))
    (local.set $msg (call $str_concat (local.get $msg) (i32.const 2600)))
    (local.set $msg (call $str_concat (local.get $msg) (local.get $field_name)))
    (local.set $msg (call $str_concat (local.get $msg) (i32.const 2640)))
    (local.set $msg (call $str_concat (local.get $msg) (local.get $type_name)))
    (local.set $msg (call $str_concat (local.get $msg) (i32.const 1912)))
    (call $eprint_string (local.get $msg))
    (call $graph_bind_kind
      (local.get $handle)
      (call $node_kind_make_nerrorhole
        (call $reason_make_inferred (i32.const 2768)))
      (local.get $reason)))

  ;; ─── $infer_emit_record_field_missing — E_RecordFieldMissing ────
  (func $infer_emit_record_field_missing (param $handle i32) (param $field_name i32)
                                           (param $type_name i32) (param $reason i32)
    (local $msg i32)
    (local.set $msg (i32.const 2504))
    (local.set $msg (call $str_concat (local.get $msg) (i32.const 1824)))
    (local.set $msg (call $str_concat (local.get $msg) (call $int_to_str (local.get $handle))))
    (local.set $msg (call $str_concat (local.get $msg) (i32.const 1840)))
    (local.set $msg (call $str_concat (local.get $msg) (i32.const 2656)))
    (local.set $msg (call $str_concat (local.get $msg) (local.get $field_name)))
    (local.set $msg (call $str_concat (local.get $msg) (i32.const 2640)))
    (local.set $msg (call $str_concat (local.get $msg) (local.get $type_name)))
    (local.set $msg (call $str_concat (local.get $msg) (i32.const 1912)))
    (call $eprint_string (local.get $msg))
    (call $graph_bind_kind
      (local.get $handle)
      (call $node_kind_make_nerrorhole
        (call $reason_make_inferred (i32.const 2792)))
      (local.get $reason)))

  ;; ─── $infer_emit_cannot_negate_capability — E_CannotNegateCapability
  (func $infer_emit_cannot_negate_capability (param $handle i32)
                                               (param $capability_name i32)
                                               (param $reason i32)
    (local $msg i32)
    (local.set $msg (i32.const 2536))
    (local.set $msg (call $str_concat (local.get $msg) (i32.const 1824)))
    (local.set $msg (call $str_concat (local.get $msg) (call $int_to_str (local.get $handle))))
    (local.set $msg (call $str_concat (local.get $msg) (i32.const 1840)))
    (local.set $msg (call $str_concat (local.get $msg) (i32.const 2696)))
    (local.set $msg (call $str_concat (local.get $msg) (local.get $capability_name)))
    (local.set $msg (call $str_concat (local.get $msg) (i32.const 2736)))
    (local.set $msg (call $str_concat (local.get $msg) (i32.const 1912)))
    (call $eprint_string (local.get $msg))
    (call $graph_bind_kind
      (local.get $handle)
      (call $node_kind_make_nerrorhole
        (call $reason_make_inferred (i32.const 2824)))
      (local.get $reason)))
