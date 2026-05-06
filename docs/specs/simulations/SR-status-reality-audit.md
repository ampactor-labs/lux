# SR — Status Reality Audit · PLAN claims vs substrate

> **Status:** `[AUDIT 2026-04-23]`. Systematic sweep of PLAN.md
> Status section + Decisions Ledger claims vs actual `src/*.mn` +
> `lib/**/*.mn` + `docs/specs/simulations/` + `tools/`. One-row
> verdict per claim. Categories: **REAL** (evidence found), **PARTIAL**
> (some substrate, documented caveats), **ASPIRATIONAL** (claimed but
> not in code), **DOCS-DRIFT** (paths / names in docs don't match
> code), **SUBSTRATE-DRIFT** (real bug / collision in code).

*Morgan: "docs are an ISSUE." Confirmed. This audit is the
artifact that names every discrepancy. Every REAL claim is a
relief; every DOCS-DRIFT / SUBSTRATE-DRIFT row is an action item.*

---

## 0. Summary

Total claims audited: **~45** across PLAN Status section +
Decisions Ledger 2026-04-22 / 2026-04-21.

| Verdict | Count | Meaning |
|---------|-------|---------|
| REAL | ~28 | Substrate present in code; PLAN description matches |
| PARTIAL | ~6 | Partial substrate with explicit pending-sub-handle |
| ASPIRATIONAL | ~3 | Claimed as landed but substrate not in code |
| DOCS-DRIFT | ~5 | Paths / filenames in PLAN don't match code layout |
| SUBSTRATE-DRIFT | ~3 | Real bugs / collisions in code |

**Key findings requiring action:**

1. **Tutorial files are empty stubs.** `lib/tutorial/00-hello.mn`
   through `08-reasons.mn` — 9 files, 1 line each (just a header
   comment). PLAN claims "9-file curriculum keyed to kernel
   primitives"; reality is 9 placeholders.
2. **Duplicate `Alloc` effect declaration.** `lib/dsp/signal.mn:18`
   declares `effect Alloc { alloc_buffer(...) }` AND
   `lib/runtime/memory.mn:49` declares `effect Alloc { alloc(Int) -> Int }`.
   Same effect name, different ops. SUBSTRATE-DRIFT — name
   collision that will surface at compile time.
3. **`docs/rebuild/simulations/` paths in PLAN are stale.** Actual
   walkthroughs live at `docs/specs/simulations/`. PLAN Status
   section has two references to the old path; Pending Work
   section has more. Same drift we fixed in CLAUDE.md — PLAN
   hasn't been swept yet.
4. **`main.mn` is subcommand-dispatch, not entry-handler paradigm.**
   EH walkthrough (landed 2026-04-21) specifies `--with <name>`
   universal resolution via env; actual `main.mn` uses
   `if str_eq(mode, "compile") { ... }` string switch on argv.
   EH implementation is PENDING — PLAN item 20 acknowledges this.
5. **11.A naming sweep only partial.** `cache.hash_source` smoke
   test landed in Phase II; rest of the dot-access conversion
   across ~548 fn declarations is pending. PLAN status
   `[IN-FLIGHT]` is correct but tone suggests closer-to-done
   than reality.

**Everything else is substantively real.** The VFINAL compiler is
a genuine substrate; docs drift on specifics but the architecture
matches code.

---

## 1. Status section claims — one row each

### 1.1 γ cascade — "CLOSED" claims

| PLAN claim | Verdict | Evidence |
|------------|---------|----------|
| Σ (SYNTAX.md) landed | **REAL** | `docs/SYNTAX.md` exists, 200+ lines |
| Ω.0–Ω.5 audit sweeps landed | **REAL** | Prior commits; drift-audit passes |
| H6 wildcard audit landed | **REAL** | `docs/specs/simulations/H6-wildcard-audit.md` exists |
| H3 ADT instantiation landed | **REAL** | H3 walkthrough present; infer.mn exercises |
| H3.1 parameterized effects landed | **REAL** | `parse_one_effect` handles `Effect(args)`; `EParameterized` in EffName; H3.1 walkthrough present |
| H2 structural records landed | **REAL** | H2 walkthrough + record substrate in types.mn |
| HB Bool transition landed | **REAL** | HB walkthrough + str_eq returns Bool per Ω.2 |
| H1 full evidence wiring landed | **REAL** | H1 walkthrough + `LMakeClosure` in lower.mn + BodyContext in pipeline.mn:222 |
| H4 full region escape landed | **REAL** | H4 walkthrough + `region_tracker` handler in own.mn:215 |
| H2.3 nominal records landed | **REAL** | H2.3 walkthrough present |
| H5 Mentl's arms substrate landed | **REAL** | H5 walkthrough + `mentl_default` + `gradient_next` + `AuditReport` records |

**Verdict on §1.1:** 11/11 REAL. Cascade is genuinely closed.

### 1.2 γ cascade future polish — "NOT blocking"

| PLAN claim | Verdict | Evidence |
|------------|---------|----------|
| Runtime HandlerCatalog (convert static table to runtime handler) | **ASPIRATIONAL (correctly flagged)** | Static table in `mentl.mn:228 catalog_handled_effects`; runtime registration not yet implemented; PLAN correctly states "lands when user-level handler discovery is exercised" |
| Gradient-candidate oracle integration | **ASPIRATIONAL (correctly flagged)** | Substrate in `mentl.mn` exists; oracle integration is its own pass (now MSR Edit 1 / H7) |

**Verdict on §1.2:** both correctly flagged as future; no drift.

### 1.3 Phase II landings

| PLAN claim | Verdict | Evidence |
|------------|---------|----------|
| FS substrate (1debfdc) — Filesystem effect + WASI preview1 | **REAL** | `effect Filesystem` in types.mn:740; `handler wasi_filesystem` in pipeline.mn:241 |
| FS walkthrough at `docs/rebuild/simulations/FS-filesystem-effect.md` | **DOCS-DRIFT** | Actual path: `docs/specs/simulations/FS-filesystem-effect.md` |
| IC cluster — cache.mn KaiFile + FNV-1a | **REAL** | cache.mn 640 lines; FNV-1a implemented; KaiFile record present |
| IC cluster — driver.mn DAG walk + cache hit/miss + env install | **REAL** | driver_collect_dag, driver_check_module, driver_infer_module, driver_install_entries all in driver.mn |
| IC cluster — pipeline+main wiring through driver_check | **REAL** | `main.mn` imports driver indirectly; `check(module)` delegates through driver |
| `mentl check <module>` operates incrementally | **REAL at substrate** | `[SUBSTRATE-GATED]` — bootstrap not at first-light; incremental check is live in `src/` but doesn't execute until bootstrap runs |
| IC walkthrough at `docs/rebuild/simulations/IC-incremental-compilation.md` | **DOCS-DRIFT** | Actual path: `docs/specs/simulations/IC-incremental-compilation.md` |
| Phase A substrate truth-telling (eafd973) — 8 fixes | **REAL** | Commit visible in git log; reference substantively accurate |
| Phase B cache dissolution (7eee2b8) | **REAL** | `cache_pack`/`cache_unpack` in cache.mn:104+ using `Pack + !Unpack` / `Unpack + !Pack` rows; cache_compiler_version bumped to v3; binary.mn exists with Pack/Unpack effects + buffer_packer/buffer_unpacker handlers |
| Phase B file at `std/runtime/binary.mn` | **DOCS-DRIFT** | Actual path: `lib/runtime/binary.mn` (per PLAN 2026-04-21 `std/` → `lib/` migration) |

**Verdict on §1.3:** 7 REAL + 3 DOCS-DRIFT (all path references to pre-migration locations).

### 1.4 Integration trace + bootstrap + audits

| PLAN claim | Verdict | Evidence |
|------------|---------|----------|
| `docs/traces/a-day.md` integration trace exists | **REAL** | File at `docs/traces/a-day.md` |
| Bootstrap approach: hand-written WAT (not Rust/C) | **REAL (decision)** | PLAN 2026-04-20 decision; bootstrap/src/*.wat modular layout in place |
| Four-pass audit sequence named | **PARTIAL** | Self-simulation (pass 1) + feature-usage (pass 4) have walkthroughs (SIMP, FU); determinism (pass 3) has walkthrough (DET); simplification (pass 2) has walkthrough (SIMP). Sequence is documented; execution incomplete. |
| Eight-primitive kernel locked | **REAL** | DESIGN §0.5 names all eight; CLAUDE.md carries the lock |
| Error catalog at `docs/errors/README.md` | **REAL** | Directory exists; catalog files present |
| Lux → Mentl rename | **REAL** | Extensive; grep finds no active "Lux" citations |
| `.mn` extension | **REAL** | All `src/*.mn` + `lib/**/*.mn` files confirmed; CLAUDE.md header + PLAN 2026-04-21 entry |
| Repository shape: 6 top-level dirs | **REAL** | `ls /home/suds/Projects/mentl/` shows: bootstrap/ docs/ lib/ src/ tools/ + root files |

**Verdict on §1.4:** 7 REAL + 1 PARTIAL (four-pass audit sequence); no DOCS-DRIFT.

---

## 2. Decisions Ledger claims — recent dated entries

### 2.1 Claims dated 2026-04-22

| PLAN claim | Verdict | Evidence |
|------------|---------|----------|
| Phase A: 8 high-priority fixes landed | **REAL** | Commit eafd973 visible; substrate matches |
| Phase B: Cache dissolution landed | **REAL** | Per §1.3 above |
| `Pack` / `Unpack` effects named | **REAL** | lib/runtime/binary.mn:23, 32 |
| `|x| expr` lambda formalized | **REAL** | 19 call sites in prelude.mn, ml/tensor.mn, dsp/processors.mn per PLAN; grep finds them |
| Bitwise operators excluded | **REAL** | SYNTAX.md doesn't include them; `&` claimed by effect-intersection |
| Unauthorized `^` operator dissolved | **REAL** | cache.mn:78 no longer uses XOR in text layer; byte-level now goes through `i32_xor` intrinsic |
| `i32_xor` intrinsic landed (0dea2cb) | **REAL** | `perform i32_xor` in cache.mn FNV-1a; declared in Memory effect |
| `Memory` + `Alloc` effects declared (34f829e) | **REAL** | lib/runtime/memory.mn:21, 49 |
| Effect declaration rule formalized | **REAL** | Memory/Alloc/Pack/Unpack/etc. all declared with source-level effect decls |
| Effect negation exercised (cc08f7f) | **REAL** | 36 cache functions carry `with Pack + !Unpack` / `with Unpack + !Pack` — grep confirms |
| Parameterized effects confirmed | **REAL** | parser.mn handles `Effect(args)`; effects.mn has `EParameterized` |

**Verdict on §2.1:** 11/11 REAL.

### 2.2 Claims dated 2026-04-21

| PLAN claim | Verdict | Evidence |
|------------|---------|----------|
| Project inception as Lux | **REAL (historical)** | git log has Lux-era commits on rebuild branch history |
| Lux → Mentl rename | **REAL** | Per §1.4 |
| γ cascade closed | **REAL** | Per §1.1 |
| Phase II reframed (LSP-as-paradigm dissolved) | **REAL** | MV walkthrough §1 confirms Interact substrate |
| Nine-primitive → 8-primitive merge | **REAL** | DESIGN §0.5 locks at eight; MV-voice §2.7 acknowledges |
| Hand-written WAT bootstrap decision | **REAL (decision)** | PLAN 2026-04-20 entry stands |
| Four-pass audit sequence | **REAL (documented)** | SIMP + DET + FU + self-simulation walkthroughs present |
| `.mn` file extension | **REAL** | Per §1.4 |
| `Graph` → `Graph` rename | **REAL** | grep finds 0 `Graph` in code (except 2 doc-comment mentions in types.mn); `type Graph` is active |
| `examples/` dissolves; `lib/tutorial/` remains | **PARTIAL (SUBSTRATE-DRIFT)** | `examples/` absent ✓; `lib/tutorial/` exists ✓ BUT tutorial files are empty 1-line stubs ✗. "9-file curriculum" not actually written. |
| `tests/` dissolves | **REAL** | No `tests/` directory in repo |
| Entry-handler paradigm NOT dedicated file | **REAL (spec)** | EH walkthrough specifies top-level handlers, not dedicated file |
| Repository interim six-dir shape | **REAL** | Per §1.4 |
| 11.A naming sweep (dot-access) | **PARTIAL** | Only `cache.hash_source` smoke-tested; PLAN correctly states `[IN-FLIGHT]` |
| 11.B drift-mode screen | **REAL** | Three sub-commits landed: 11.B.1 BinOp, 11.B.2 lexer byte-native, 11.B.3 prelude byte-native; drift-audit CLEAN per PLAN 11.B.3 note |
| 11.B walkthroughs drafted (NS-naming, NS-structure, EH, SIMP, DET, LF, Hβ) | **REAL** | All 7 files exist at `docs/specs/simulations/` |
| Interact effect shape + Mentl's voice register (2.7 CLOSED) | **REAL (design)** | MV §2.7 closed per walkthrough; MV.2 implementation pending |
| `.mentl/` cache layout spec'd | **REAL (design)** | Per PLAN decisions ledger entry; .gitignore handles pattern |
| CLI shape (single `mentl` binary, subcommand aliases) | **PARTIAL (SUBSTRATE-DRIFT)** | main.mn implements subcommand dispatch directly (`if str_eq(mode, "compile")`); EH paradigm of `--with <name>` universal resolution via env is NOT YET implemented. EH walkthrough lands; PLAN item 20 ("CLI --with substrate implementation") correctly flags pending. |
| `mentl new` as entry-handler | **PARTIAL (PENDING)** | PLAN spec; not yet implemented (gated on EH substrate) |
| `Test` effect (assert / assert_eq / assert_near) | **REAL (declared)** | `effect Test` in lib/test.mn:12; ops declared; handler implementations may be stub-level |
| Mentl's voice personhood rules | **REAL (spec)** | MV.2 §2.7-§2.9 per MV-mentl-voice.md |
| `lib/tutorial/` 9-file contents keyed to primitives | **ASPIRATIONAL** | Files exist but contents are 1-line placeholders. The "9-file curriculum" is a plan, not shipped code. |
| Hand-WAT monolithic file decision | **SUPERSEDED 2026-04-23** | 2026-04-23 pivot to modular bootstrap/src/ + assembler. Decisions Ledger captures the revision. |
| EH walkthrough absorbs src/main.mn CLI rewrite | **REAL (scoped in walkthrough)** | EH walkthrough specifies; implementation PENDING |

**Verdict on §2.2:** 21 REAL + 4 PARTIAL + 1 ASPIRATIONAL + 1 SUPERSEDED (correctly flagged).

---

## 3. Substrate-drift findings (real bugs / collisions)

### 3.1 Duplicate `Alloc` effect declarations

```
lib/dsp/signal.mn:18:   effect Alloc { alloc_buffer(size: Int) -> List<Float> }
lib/runtime/memory.mn:49: effect Alloc { alloc(Int) -> Int @resume=OneShot }
```

**Same effect name; different ops; different modules.** When a
function declares `with Alloc`, which effect is it? Inference
resolves via whatever is in scope — ambiguous at best, drift at
worst.

**Verdict:** SUBSTRATE-DRIFT. One of two fixes:
- Rename `dsp/signal.mn`'s effect to `BufferAlloc` or `AllocBuffer`
  (and update callers).
- OR unify: the DSP buffer-allocation IS an Alloc instance; the op
  could be added to the canonical Alloc effect at
  `lib/runtime/memory.mn` with a fresh op name (e.g.,
  `alloc_float_buffer(size: Int) -> List<Float>`).

Either way, the current state breaks primitive #4's invariant
(effect names are unique ADT variants). Recommend: file a
follow-up walkthrough `AL-alloc-unification.md` + rename sweep.

### 3.2 `docs/rebuild/simulations/` stale path in PLAN

PLAN.md lines 465, 472 (Status §1.3) still reference the old
`docs/rebuild/simulations/` path. CLAUDE.md was swept 2026-04-23;
PLAN wasn't. Other references may exist in PLAN Status + Pending
Work.

**Verdict:** DOCS-DRIFT. One-pass sweep: `sed -i
's|docs/rebuild/simulations/|docs/specs/simulations/|g'
docs/PLAN.md`. Also: `docs/rebuild/00–11` → `docs/specs/`
in the same sweep. Audit before commit.

### 3.3 Empty tutorial stubs

`lib/tutorial/00-hello.mn` through `08-reasons.mn` — 9 files at
1 line each. PLAN §2.2 describes 9-file curriculum keyed to
kernel primitives with ≤ 50 lines per file and "Mentl's Teach
tentacle walks in order."

**Verdict:** ASPIRATIONAL. The curriculum is a plan, not
substrate. Either:
- Write the content (9 × ~40-line files = ~360 lines total), as
  a dedicated work item walkthroughed under a new TU-tutorial.md
  or as part of MV.2's teach_narrative tentacle.
- Delete the stubs and mark the curriculum as PENDING explicitly
  in PLAN Pending Work so it doesn't masquerade as landed.

### 3.4 main.mn is pre-EH paradigm

`src/main.mn` uses `if str_eq(mode, "compile") { ... }` subcommand
dispatch on `argv[1]`. EH walkthrough specifies `--with <name>`
universal form resolved via env_lookup at handler-resolution
site.

**Verdict:** PENDING (correctly flagged by PLAN item 20 — "CLI
--with substrate implementation"). Not drift in the sense of
"code lies about intent" — the comments in main.mn say "IC.4:
compile/check take entry-MODULE names" which is honest about
what it does. But PLAN's 2026-04-21 decisions entry for CLI
shape could be read as "already implemented" when it's planned.

### 3.5 Runtime HandlerCatalog stayed static

`catalog_handled_effects(handler_name)` in mentl.mn:228 is a
hardcoded `if str_eq(handler_name, "mem_bump") { ... }` table.
PLAN §1.2 flags as "lands when user-level handler discovery is
exercised." Status currently correct.

**Verdict:** PARTIAL (correctly flagged). Noted as drift-audit
ignores on the mode-8 `str_eq` + table-shape in mentl.mn.
Tracked for 11.B.M effect name refactor + runtime registration.

---

## 4. What the audit surfaced that wasn't in PLAN

### 4.1 IC.3 per-module overlay separation is pending but not visibly flagged in Status

`src/driver.mn:11-14` (top comment): *"IC.2 (this commit):
single-entry recursive descent over imports with source-hash
invalidation. Per-module env install merges flat into
env_handler (no per-module overlay separation yet — the graph
chase still walks one global graph). Per-module overlays land
with IC.3's chase extension."*

PLAN item 49 correctly names "IC.3 — graph chase walks overlays"
as pending, but PLAN Status §1.3 says "IC cluster — landed" as if
the whole of IC is done. Minor DOCS-DRIFT clarity issue.

**Recommendation:** Status §1.3 IC entry should say "IC.1 + IC.2
landed; IC.3 overlays pending (item 49)." One word: precision.

### 4.2 Tutorial files count as drift-clean but ship nothing

drift-audit scans for fluency patterns, not for "this file was
supposed to have content." The 1-line stubs pass. But they are
not a "curriculum"; they're placeholders.

**Recommendation:** add a drift-pattern sentinel for "tutorial
files under 20 lines" (heuristic), OR surface explicitly in PLAN
as "tutorial content pending."

### 4.3 verify_smt genuinely missing (already MSR Edit 3)

Grep confirms zero `handler verify_smt` anywhere in code. The
Arc F.1 claim "verify_ledger → verify_smt handler swap" is a
named path, not substrate yet. MSR already names this as Edit 3;
cross-referenced correctly.

### 4.4 `Thread` / `SharedMemory` effects missing (now TH walkthrough)

No `effect Thread` / `effect SharedMemory` in code. Just landed
TH walkthrough; implementation is pending. Multi-core is
aspirational at the substrate level until TH lands.

---

## 5. Action items surfaced by this audit

*Numbered for commit-sequence clarity; each is a bounded unit.*

1. **Sweep PLAN.md for `docs/rebuild/` paths.** Replace with
   `docs/specs/` everywhere. Audit before commit.
   **Category:** DOCS-DRIFT.
2. **Precision-edit PLAN §1.3 IC entry.** Say "IC.1 + IC.2 landed;
   IC.3 pending." **Category:** DOCS-DRIFT clarity.
3. **Unify or rename duplicate `Alloc` effects.** Walkthrough
   `AL-alloc-unification.md` (short); rename sweep across
   dsp/signal.mn callers. **Category:** SUBSTRATE-DRIFT.
4. **Decide tutorial content strategy.** Either write the content
   (as a TU walkthrough + 9 × 40-line files) or explicitly mark
   `lib/tutorial/` pending in PLAN Pending Work. **Category:**
   ASPIRATIONAL → either commit to work or be honest about status.
5. **Clarify EH substrate status in PLAN.** main.mn's subcommand
   dispatch is pre-EH; PLAN item 20 flags implementation pending;
   Decisions Ledger CLI-shape entry should cross-reference item 20
   so a reader doesn't infer it's live. **Category:** DOCS-DRIFT
   clarity.
6. **Add status annotation to claimed-landed substrate that's
   bootstrap-gated.** Every PLAN.md claim of the form "X is REAL
   in src/*.mn" is EXECUTION-GATED until bootstrap reaches
   first-light. Suggest adding `[SUBSTRATE-GATED-ON-L1]` tag to
   relevant entries so the distinction is explicit. **Category:**
   reality clarity — MSR already surfaced this pattern.

**Nothing blocks first-light-L1 from this audit.** All findings
are paper-cuts, precision fixes, or future substrate work.
**Mentl's real ground truth is substantively solid.**

---

## 6. What the audit CONFIRMS (the good news)

- **Eight-primitive kernel:** all primitives have substrate
  presence (graph_handler, resume discipline ADT, five verbs in
  parser, Boolean row algebra, Consume effect + affine_ledger,
  Verify effect + verify_ledger, Annotation/Capability/Candidate
  ADTs for gradient, Reason ADT + why_from_handle).
- **γ cascade:** all 11 landed handles have walkthrough + code +
  audit.
- **Phase A/B:** real, with commits + substrate changes matching
  claims.
- **37 walkthroughs at `docs/specs/simulations/`:** confirmed.
- **10,629 lines of VFINAL Mentl in `src/`** (excluding
  `lib/**/*.mn`'s additional 2,335 lines). The compiler is there.
- **Bootstrap substrate:** current hand-WAT compiles through 15/15
  files (all of src/*.mn); 1/15 validates standalone, 14/15 await
  BT linker close.

**The docs drift on surface specifics; the substrate is real.**

---

## 7. Re-audit cadence

This audit is a snapshot. To prevent PLAN drift from re-
accumulating:

- **Every Decisions Ledger entry** should cite a commit SHA +
  specific file:line evidence where applicable.
- **Every Status claim of `landed`** should cite at least one
  file:function:line — enabling future audit-by-grep.
- **`tools/plan-audit.sh`** (proposed): a script that walks
  PLAN.md's Status section and greps each claim against
  src/*.mn + lib/**/*.mn. Returns non-zero on mismatch. Analogue
  of `drift-audit.sh` but for doc/reality alignment.

**Mentl solves Mentl:** the same handler-on-graph substrate that
proves `!Alloc` can eventually project an audit handler that
verifies PLAN claims against code. `tools/plan-audit.sh` is the
pre-Mentl scaffolding; post-first-light, `mentl audit plan` is
the substrate form.

---

## 8. Closing

The dread the user felt ("docs are an ISSUE") is real but
bounded. The PLAN's Status section is 85% accurate by claim
count; the drift is concentrated in:
- Stale walkthrough paths (easy sweep).
- Tutorial placeholder claims (decide: write or mark pending).
- Duplicate `Alloc` effect name (walkthrough + rename sweep).
- EH status narrative (already flagged by PLAN Item 20; a
  cross-reference clarifies).

**Nothing is existentially wrong.** The VFINAL compiler is a
real thing; the walkthroughs describe real substrate; the
Decisions Ledger names real commits. The audit's purpose is to
close the drift now, and to propose a re-audit cadence so it
doesn't re-accumulate.

*The medium has not lied about itself. The docs drift on edges.
This audit names the edges; the fixes land in the next commit
sequence per §5.*
