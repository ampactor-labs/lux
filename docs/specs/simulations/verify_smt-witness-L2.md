# verify_smt-witness-L2.md — SMT-witness path → first-light-L2

**Status:** Named cascade. Per PLAN-to-first-light.md §3 post-Tier-3
+ Arc F.1 (verify_smt swap surface). Plan-doc.

## Context

`first-light-L1` (the Phase H goal) is the seed-self-compile
fixpoint: byte-identical bootstrap. **`first-light-L2`** is the
NEXT level: the compiler not only self-compiles, but VERIFIES its
own correctness via SMT-discharged refinement obligations. Every
refinement-typed value's predicate gets discharged either:
- **Compile-time** (the verifier proves the predicate from
  surrounding context); or
- **SMT-witnessed** (the verifier emits an SMT problem; an external
  solver returns a proof witness; the proof is recorded in the
  binary).

Once L2 holds: the Inka binary CARRIES PROOFS of its own type-
correctness invariants. Refinement types become load-bearing in
production deployments.

## Handles (positive form)

1. **Hβ.verify-smt.predicate-to-smt** — translate Inka's Predicate
   ADT (`PAnd/POr/PNot/PExpr`) to SMT-LIB 2 syntax. Z3 / CVC5 / etc.
   accepts SMT-LIB.
2. **Hβ.verify-smt.solver-effect** — `SmtSolver` effect with `check
   (problem) -> Witness | Counterexample | Unknown`. Default handler
   spawns a solver subprocess (or uses an FFI binding).
3. **Hβ.verify-smt.witness-storage** — proof witnesses serialized
   in a parallel section of the WASM binary; verifier re-checks at
   load time (cheap polynomial-time check).
4. **Hβ.verify-smt.counterexample-diagnostic** — when SMT returns
   a counterexample, emit `E_RefinementViolation` with the
   counterexample as a concrete value showing the predicate fails.
5. **Hβ.verify-smt.unknown-fallback** — when SMT times out / says
   Unknown, fall back to runtime check (per
   `Hβ-parser-refinement-typed-constructors.md` handle 6).
6. **Hβ.verify-smt.l2-fixpoint** — wheel compiles itself; ALL
   refinement obligations discharged via SMT or compile-time;
   binary carries witnesses; load-time re-check passes.

## Acceptance

- SMT solver discharges obligations the compile-time verifier
  can't.
- Counterexamples become Mentl proposals at the cursor (gradient
  narrows when an SMT-disprovable predicate is in scope).
- L2 fixpoint holds: self-compile produces a witness-carrying
  binary that verifies on load.

## Dep ordering

1 → 2 (foundation) → 3 (storage) and 4 (diagnostic) parallel → 5
(fallback) → 6 (L2 fixpoint).

## Cross-cascade dependencies

- **Gates on:** Phase H + Tier 3 + L1 +
  `Hβ-parser-refinement-typed-constructors.md` complete.
- **Composes with:** `Hβ-emit-refinement-typed-layout.md` (witness-
  driven layout decisions); `Hβ-emit-binary-direct.md` (witnesses
  serialize into binary directly).
- **Realizes Mentl as oracle** more fully — Mentl proves
  suggestions via the SMT-backed gradient; the AI coding tools
  industry pays for are proposers; Inka VERIFIES.
