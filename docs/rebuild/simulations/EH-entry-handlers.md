# EH-entry-handlers — Entry-handler substrate walkthrough

> **Status:** `[PENDING]`. Resolves the CLI + entry-handler substrate. Dissolves the categories "build profile," "test suite," "deploy target," "chaos config" into normal handler composition. Gates Pending Work item 20 (CLI `--with` substrate implementation) + item 34 (batch CLI unification with Mentl's voice).

*Tests are handler swap. Build profiles are handler swap. Deploy targets are handler swap. Chaos runs are handler swap. All of it is just naming a handler stack and installing it at invocation time. No config files. No YAML. No TOML. Handlers are handlers.*

---

## 0. Framing — what dissolves

Peer languages have:
- `package.json` / `Cargo.toml` — manifest files for build profiles + scripts.
- `jest.config.js` / `pytest.ini` — test runner configuration.
- `docker-compose.yml` / `Procfile` — deploy target configuration.
- `chaos.yaml` — chaos engineering configuration.

**Every one of these is a list of named handler stacks expressed as untyped configuration.** In Inka, each dissolves into a named handler declared as normal Inka code; the CLI's `--with <name>` resolves the handler by symbol through ordinary import.

This walkthrough:
- Names the entry-handler convention (no new file; top-level handler declarations in `main.nx` or any imported module).
- Specifies CLI `--with <name>` resolution.
- Maps the subcommand aliases (`inka compile`, `inka check`, etc.) to entry-handler invocations.
- Resolves the `Test` effect's lifting semantics (`assert` becomes compile-time proof where decidable).
- Rewrites `src/main.nx`'s current subcommand dispatch into entry-handler resolution.

**What this walkthrough gates:**
- Item 20 — CLI `--with <name>` substrate implementation in `src/main.nx`.
- Item 34 (post-first-light) — batch CLI unification; all subcommands share Mentl's voice via the `Interact` effect.
- Implicitly, every user project's `main.nx` adopts the declare-entry-handlers-inline convention.

**What this walkthrough does NOT cover:**
- The `Interact` effect's full op set + Mentl-voice semantics (that's MV-mentl-voice.md, in-flight with open §2 questions).
- The LSP adapter + VS Code extension (post-first-light item 32).
- Specific entry-handler implementations like `chaos_run(seed)` (those are per-domain handler composition; walkthrough just defines the substrate).

---

## 1. The four substrate decisions

### 1.1 Entry-handlers are normal top-level handler declarations (NOT a dedicated file)

**Rejected earlier framing.** An earlier design round proposed `run.nx` as a dedicated per-project file containing entry-handler declarations. That was Makefile/package.json-shaped drift — introducing a special filename for something that's just normal code.

**Correct form.** Entry-handlers are **normal `handler` declarations at top level** in `src/main.nx` (or any imported module). They ARE handlers. They have no special status, no special file, no special category.

**Example — the compiler's own `src/main.nx` after the rewrite:**

```
// src/main.nx — Inka compiler entry point

import graph
import effects
import infer
import lower
import pipeline
import backends/wasm
import mentl
import query
import cache
import driver

// ═══ main — the default pipeline ═══════════════════════════════════

fn main(args) with IO + Filesystem + Alloc =
  args
    |> parse_cli
    |> dispatch_to_entry_handler

// ═══ Entry-handlers — named handler stacks invoked via --with ═════

handler compile_run {
  ~> real_filesystem
  ~> bump_allocator
  ~> mentl_default
  ~> diagnostics_stdout
}

handler check_run {
  ~> real_filesystem
  ~> bump_allocator
  ~> mentl_default
  ~> diagnostics_stdout
  // elides emit step; check-only pipeline
}

handler audit_run {
  ~> real_filesystem
  ~> bump_allocator
  ~> audit_walk_handler
  ~> mentl_default
  ~> diagnostics_stdout
}

handler query_run {
  ~> real_filesystem
  ~> bump_allocator
  ~> mentl_default
  ~> query_handler
}

handler teach_run {
  ~> real_filesystem
  ~> bump_allocator
  ~> mentl_voice        // Mentl talks; default when bare inka
}

handler test_run {
  ~> memory_filesystem
  ~> bump_allocator
  ~> mentl_default
  ~> assert_reporter    // Test effect's reporter captures pass/fail
  ~> verify_assert      // statically-decidable asserts lift to compile-time proofs
  ~> diagnostics_stdout
}

handler repl_run {
  ~> real_filesystem
  ~> bump_allocator
  ~> mentl_voice
  ~> line_repl          // line-at-a-time eval over current env
}

handler deterministic_run {
  ~> real_filesystem
  ~> bump_allocator_deterministic   // sorted allocation for first-light
  ~> mentl_default
  ~> diagnostics_stdout
}

handler new_project(name: String) {
  ~> real_filesystem
  ~> project_scaffold(name)         // clones lib/tutorial/00-hello.nx + sets up .inka/
}
```

**The handlers are normal Inka code.** They type-check. They can compose (entry-handler can include other entry-handlers via `~>`). They can take arguments (`new_project(name)`, `chaos_run(seed)`). They can be moved to separate modules and imported (`import handlers/test_variants {chaos_run}`) for organization, but there's no required file.

**For user projects:** the same convention. A developer's `src/main.nx` declares `prod_run`, `staging_run`, `test_run`, etc. inline. For larger projects, they can be extracted to `src/handlers.nx` and imported. **No manifest file. No convention file. Just handlers.**

**Drift modes foreclosed:**
- **Drift 4 (Haskell monad transformer):** entry-handlers are NOT monad-transformer stacks at the type level; they're `~>` chains, which are capability stacks (not monad composition).
- **Drift 6 (primitive-type-special-case):** an "entry-handler" is NOT a special kind of handler; it's a normal handler that happens to be the outermost wrap for a `main()` invocation.
- **Drift 9 (deferred-by-omission):** no `run.nx` convention file that would defer "manifest structure" questions.

### 1.2 CLI `--with <name>` is the universal invocation form

**Rejected earlier framing.** The current `src/main.nx` parses subcommands (`inka compile`, `inka check`, `inka audit`, `inka query`) with hard-coded dispatch. That's a `mode == 0 / mode == 1 / mode == 2` drift (mode 8).

**Correct form.** ONE flag: `--with <handler_name>`. The handler is resolved by symbol through the module graph (same resolution as any other identifier). Subcommands are ALIASES for `--with` + specific names.

**Invocation shapes:**

```
inka                                 # bare; defaults to --with teach_run
inka compile                          # alias for --with compile_run
inka compile my_file.nx               # --with compile_run, target = my_file.nx
inka --with compile_run my_file.nx    # explicit form, same effect
inka --with test_run                  # installs test_run entry-handler
inka --with chaos_run(seed=42)        # with argument
inka --with new_project(name="foo")   # with argument; creates new project
inka --with my_custom_run             # user-defined entry-handler
inka query my_file.nx "type of main"  # alias for --with query_run + args
inka audit my_file.nx                 # alias for --with audit_run
inka teach                            # alias for --with teach_run
inka run                              # alias for --with compile_run && wasmtime output.wasm
inka repl                             # alias for --with repl_run
inka test                             # alias for --with test_run
inka new foo                          # alias for --with new_project(name="foo")
```

**Alias resolution table** (canonical, fold into `src/main.nx`):

| CLI form | Resolves to |
|---|---|
| `inka` (bare) | `--with teach_run` against current project |
| `inka compile <target>` | `--with compile_run <target>` |
| `inka check <target>` | `--with check_run <target>` |
| `inka audit <target>` | `--with audit_run <target>` |
| `inka query <target> <question>` | `--with query_run <target> <question>` |
| `inka teach` | `--with teach_run` |
| `inka run <target>` | `--with compile_run <target> && wasmtime <output>` |
| `inka repl` | `--with repl_run` |
| `inka test` | `--with test_run` |
| `inka new <name>` | `--with new_project(name=<name>)` |

**Aliases are defined IN `src/main.nx`'s argument parser**, not in a separate alias table. The parser matches the subcommand keyword and constructs the equivalent `--with` form, then dispatches.

**Resolution rule for `--with <name>`:**

1. Parse `<name>` into `symbol_name` + optional `argument_list` (e.g., `chaos_run(seed=42)` → `chaos_run` + `[seed=42]`).
2. Resolve `symbol_name` against the current project's module graph (same as any identifier resolution: project-local first, then `lib/`, then imports).
3. If resolved symbol is NOT a handler, error: `E_EntryHandlerNotAHandler`.
4. If argument count / types don't match handler's signature, error: `E_EntryHandlerArgsMismatch`.
5. Install the handler via `~>` wrapping `main()`; invoke.

**If `<name>` doesn't resolve:** error `E_EntryHandlerNotFound` — with a Mentl-voice suggestion listing every handler declared in the module graph whose type could serve as an entry-handler. (Mentl's Propose tentacle fires on resolution failure.)

**Drift modes foreclosed:**
- **Drift 8 (string-keyed-when-structured / int-coded-when-ADT):** `--with <name>` is structured — `name` resolves through the graph, not a stringly-typed mode dispatch.
- **Drift 5 (C calling convention):** no `int argc, char **argv` style mode parsing; arguments parse into structured `EntryHandlerInvocation` ADT.

### 1.3 The `Test` effect — assert lifts to proof where decidable

The `Test` effect is declared in `lib/test.nx` (post-restructure):

```
// lib/test.nx — Test effect declarations + reporter handler

effect Test {
  assert(cond: Bool, msg: String) -> ()                @resume=OneShot
  assert_eq<A>(actual: A, expected: A, msg: String) -> () @resume=OneShot
  assert_near(actual: Float, expected: Float, eps: Float, msg: String) -> () @resume=OneShot
}
```

**Three operations. Each has a canonical `Test` handler AND a compile-time-proof lifting path.**

#### 1.3.1 `assert(cond, msg)` semantics

**Runtime handler (default when `Test` is present but not lifted):**

```
handler assert_reporter with pass_count = 0, fail_count = 0, fails = [] {
  assert(cond, msg) =>
    if cond {
      resume(()) with pass_count = pass_count + 1
    } else {
      resume(()) with fail_count = fail_count + 1,
                      fails = push(fails, msg)
    },
  assert_eq(a, b, msg) =>
    if structural_eq(a, b) {
      resume(()) with pass_count = pass_count + 1
    } else {
      resume(()) with fail_count = fail_count + 1,
                      fails = push(fails, msg ++ " (got=" ++ show(a) ++ ", expected=" ++ show(b) ++ ")")
    },
  assert_near(a, b, eps, msg) =>
    if abs_float(a - b) <= eps {
      resume(()) with pass_count = pass_count + 1
    } else {
      resume(()) with fail_count = fail_count + 1,
                      fails = push(fails, msg ++ " (|got-expected|=" ++ show(abs_float(a - b)) ++ ")")
    }
}
```

**Compile-time lifting handler (`verify_assert`, installed in `test_run`):**

```
// verify_assert lifts static asserts to refinement obligations at compile time.
// cond must be a pure, statically-decidable expression (no effects, no free vars).
//
// If cond is decidable:
//   - evaluate at compile time
//   - if true: silently absorb (no runtime cost)
//   - if false: emit E_AssertFailedAtCompileTime
// If cond is NOT decidable: fall through to assert_reporter.

handler verify_assert {
  assert(cond, msg) =>
    if is_statically_decidable(cond) {
      if evaluate_statically(cond) {
        resume(())    // proven; zero runtime cost
      } else {
        perform report("E_AssertFailedAtCompileTime", current_span(), msg)
        resume(())
      }
    } else {
      perform assert(cond, msg)    // re-perform; next handler in chain handles
    }
}
```

**Chain order in `test_run`:**
```
~> mentl_default
~> verify_assert           // lifts static asserts FIRST
~> assert_reporter         // runtime fallback for dynamic asserts
~> diagnostics_stdout
```

`verify_assert` is installed INSIDE `assert_reporter` (more-trusted, higher in chain). Static asserts are absorbed at compile time; dynamic ones fall through to runtime reporter.

**Drift modes foreclosed:**
- **Drift 6 (primitive-type-special-case):** `assert` isn't special syntax; it's an `effect Test` op handled by normal handler arms.
- **Drift 8 (string-keyed-when-structured):** `assert_eq` uses structural equality (records by sorted fields, variants by tag), not string comparison.

#### 1.3.2 `assert_eq` — structural equality, closure rejection

**Structural equality rules:**

- **Primitives (Int, Float, Bool, String):** direct value equality.
- **Records:** compare field-by-field after sorting (field sort per H2 substrate is canonical; record equality IS field-set equality).
- **Variants:** compare tag first, then sub-eq on fields.
- **Tuples:** position-wise recursive eq.
- **Lists:** length-first, then element-wise recursive eq.
- **Closures / functions:** REJECTED at compile time with `E_ComparesClosures` error. Closures have identity, not structural equality; any attempt to compare is caught at the `assert_eq<A>` instantiation site when `A` unifies with a function type.

**Compile-time rejection example:**

```
let f = fn (x) => x + 1
let g = fn (x) => x + 1
assert_eq(f, g, "two fn eq")
// E_ComparesClosures at assert_eq — closures cannot be compared
```

#### 1.3.3 `assert_near` — explicit epsilon required

No default epsilon. Call sites must specify:

```
assert_near(audio_level, -0.1, 0.001, "audio limit respected")
```

Missing epsilon is a compile-time error:

```
assert_near(a, b)    // E_AssertNearMissingEps at compile time
```

**Rationale:** floating-point comparison is domain-specific; `1e-9` might be right for physics but wrong for audio (±0.001 dB) or financial calculations (±0.001 = $0.001 matters). Forcing explicit epsilon keeps the developer's intent visible.

### 1.4 `src/main.nx` rewrite — from subcommand dispatch to entry-handler resolution

**Current shape of `src/main.nx` (approximate, pre-rewrite):**

```
// Reads args, dispatches to mode (compile / check / query / audit)
// Hard-coded match on argv[1].

fn main() =
  let args = perform read_args()
  match args {
    ["compile", target] => compile_file(target),
    ["check", target] => check_file(target),
    ["audit", target] => audit_file(target),
    ["query", target, question] => query_file(target, question),
    _ => print_usage()
  }
```

**Post-rewrite shape:**

```
import graph
import infer
// ... (all compiler modules)

// ═══ main — parse args into an EntryHandlerInvocation ════════════

fn main(argv) with IO + Filesystem + Alloc =
  argv
    |> parse_cli_args          // produces EntryHandlerInvocation
    |> install_entry_handler   // wraps the body in the named handler
    |> run_project_body        // runs against the current-dir project

// ═══ EntryHandlerInvocation ADT ══════════════════════════════════

type EntryHandlerInvocation
  = Invocation(String, List, Option)   // name, positional-args, target-file
  | ParseError(String)                  // unparseable argv

// ═══ CLI parsing — maps subcommand aliases to --with invocations ══

fn parse_cli_args(argv) = match argv {
  []                            => Invocation("teach_run", [], None),
  ["teach"]                     => Invocation("teach_run", [], None),
  ["teach", target]             => Invocation("teach_run", [], Some(target)),
  ["compile", target]           => Invocation("compile_run", [], Some(target)),
  ["check", target]             => Invocation("check_run", [], Some(target)),
  ["audit", target]             => Invocation("audit_run", [], Some(target)),
  ["query", target, question]   => Invocation("query_run", [question], Some(target)),
  ["run", target]               => Invocation("compile_run", [], Some(target)),
    // compile_run post-hook runs wasmtime on the emitted output
  ["repl"]                      => Invocation("repl_run", [], None),
  ["test"]                      => Invocation("test_run", [], None),
  ["test", target]              => Invocation("test_run", [], Some(target)),
  ["new", name]                 => Invocation("new_project", [name], None),
  ["--with", full_spec, ...rest] => parse_with_spec(full_spec, rest),
  _                              => ParseError("unrecognized command; try 'inka --with <handler>' or 'inka help'")
}

fn parse_with_spec(spec, rest) = {
  // spec is like "compile_run" or "chaos_run(seed=42)"
  let (name, args) = split_name_and_args(spec)
  let target = match rest { [t, ..._] => Some(t), [] => None }
  Invocation(name, args, target)
}

// ═══ install_entry_handler — resolves the named handler + wraps ══

fn install_entry_handler(invocation) with GraphRead + EnvRead = match invocation {
  Invocation(name, args, target) => {
    let handler_sym = perform env_lookup(name)
    match handler_sym {
      Some(HandlerScheme(arity, types)) =>
        if check_args(arity, args, types) {
          WrappedBody(name, args, target)
        } else {
          perform report("E_EntryHandlerArgsMismatch", current_span(),
            name ++ " expects " ++ show(arity) ++ " args, got " ++ show(len(args)))
          FailedInvocation
        },
      Some(_) => {
        perform report("E_EntryHandlerNotAHandler", current_span(),
          name ++ " is not a handler")
        FailedInvocation
      },
      None => {
        // Mentl's Propose tentacle fires: list candidate entry-handlers
        let candidates = perform env_find_handlers_matching_entry_shape()
        perform report("E_EntryHandlerNotFound", current_span(),
          name ++ " not found; did you mean: " ++ show_candidates(candidates))
        FailedInvocation
      }
    }
  },
  ParseError(msg) => {
    perform report("E_CliParseError", current_span(), msg)
    FailedInvocation
  }
}

// ═══ run_project_body — drives the project's main() through the handler

fn run_project_body(wrapped) with IO + Filesystem + Alloc = match wrapped {
  WrappedBody(handler_name, args, target_opt) => {
    let target = match target_opt { Some(t) => t, None => cwd_project() }
    let body_fn = load_project_main(target)
    // install the entry-handler as the outermost ~> wrap of body_fn's invocation
    perform install_handler_by_name_and_run(handler_name, args, body_fn)
  },
  FailedInvocation => ()
}
```

**The rewrite:**
- `src/main.nx` shrinks to ~100 lines (from current ~200+).
- All subcommand-specific logic moves into entry-handler declarations (each subcommand's pipeline is the handler stack in `compile_run`, `check_run`, etc.).
- Adding a new subcommand = adding a new entry-handler (+ optional alias in `parse_cli_args`). No other code changes.

**New errors added to the catalog** (files in `docs/errors/` per NS-structure.md restructure):
- `E_EntryHandlerNotFound.md`
- `E_EntryHandlerNotAHandler.md`
- `E_EntryHandlerArgsMismatch.md`
- `E_CliParseError.md`
- `E_AssertFailedAtCompileTime.md`
- `E_ComparesClosures.md`
- `E_AssertNearMissingEps.md`

Each file written as part of item 17' restructure (NS-structure §4.8 absorbs error-catalog additions).

---

## 2. The eight interrogations, applied

### 2.1 Graph?

What does the graph already know about entry-handlers? After the `main.nx` rewrite, the graph knows:
- Every `handler <name>_run { ~> ... }` declaration: a handler binding in env.
- Every handler's declared effect row (what it absorbs + requires).
- Every handler's type signature (what arguments it takes).

**Resolution at `--with <name>` IS graph query.** The CLI doesn't maintain a parallel registry; it queries env like any other identifier resolution.

### 2.2 Handler?

What handler installs the entry-handler on `main()`'s body? The `install_handler_by_name_and_run` function performs an effect that's absorbed by the runtime driver. This IS a handler. **Entry-handler installation is itself handled by a meta-handler** that reads the name-to-handler binding from env and invokes the resolved handler.

### 2.3 Verb?

The `~>` verb IS the entry-handler's composition mechanism. Each entry-handler's body is a chain of `~>` installations. No new verb needed.

### 2.4 Row?

Each entry-handler's effect row declares what capabilities its body can use:

```
handler compile_run with Filesystem + Alloc + IO { ... }
handler test_run    with Filesystem + Alloc + IO + Test { ... }
```

The row IS the capability profile. Declared rows let the compiler prove (via row subsumption) whether an entry-handler is compatible with the body it wraps. Mismatches surface as `E_HandlerUninstallable`.

### 2.5 Ownership?

Entry-handlers can carry `own` state for per-run data (test counters, chaos random seeds). The `affine_ledger` handler audits linearity of `own` captures. No new ownership substrate.

### 2.6 Refinement?

Entry-handler arguments can carry refinement types: `chaos_run(seed: Int where seed >= 0)`, `new_project(name: String where valid_project_name(self))`. Refinements propagate; `verify_ledger` discharges obligations.

### 2.7 Gradient?

Each entry-handler demonstrates the gradient: adding annotations tightens what the handler CAN'T do. `test_run with !Network` proves "no test hits the network." `deterministic_run with !Random` proves "reproducible." **Entry-handlers are gradient demonstrations at the handler level.**

### 2.8 Reason?

Every entry-handler installation leaves a Reason in the graph: `Located(invocation_span, EntryHandlerInstall(name))`. Why Engine walks back to "why did this code run under this handler stack?" — answer: the CLI invocation + alias resolution.

---

## 3. Forbidden-pattern list, per decision

### Decision 1.1 — entry-handlers as normal handlers

- **Drift 1 (Rust vtable):** forbidden to treat entry-handlers as "dispatched through a table." They're normal handlers resolved at compile time via env.
- **Drift 6 (primitive-type-special-case):** forbidden to make "entry-handler" a special kind of handler with tagged semantics. They're handlers that happen to wrap `main()`.
- **Drift 9 (deferred-by-omission):** forbidden to split `main.nx`'s rewrite across multiple commits. One rewrite; test-run + compile-run + all aliases land together.

### Decision 1.2 — CLI `--with` form

- **Drift 8 (string-keyed-when-structured):** forbidden to parse `--with` arg as a magic string and dispatch via string-switch. Parse into `EntryHandlerInvocation` ADT; every match is structural.
- **Drift 5 (C calling convention):** forbidden to thread `argc/argv` style raw state; parsing produces structured invocation, not `int main(int argc, char** argv)`-shaped handoff.

### Decision 1.3 — Test effect + lifting

- **Drift 4 (Haskell monad transformer):** forbidden to treat `verify_assert ~> assert_reporter` as monad-transformer stacking. It's `~>` capability composition.
- **Drift 8 (string-keyed):** forbidden to have `assert` that stringly-matches "I think this is decidable" — the `is_statically_decidable` predicate is structural (traverses the expression's AST for purity + free-var-freedom).

### Decision 1.4 — main.nx rewrite

- **Drift 5 (C calling convention):** no `argc`/`argv`-style raw parsing.
- **Drift 9 (deferred-by-omission):** the rewrite lands whole; no "subcommand dispatch moves in phase 1, entry-handler install in phase 2" split.

### Applicable bug classes

- **`_ => <fabricated>` match arms:** `parse_cli_args` match must enumerate every subcommand explicitly; the `_` arm returns `ParseError`, which is the honest default — NOT a fabricated `Invocation(...)`.
- **`acc ++ [x]` loops:** `env_find_handlers_matching_entry_shape` must use buffer-counter substrate if it collects candidates.
- **Flag/mode-as-int:** no `mode = 0/1/2` dispatch anywhere in CLI parsing.

---

## 4. Edits as literal tokens

Item 20 implements this:

### 4.1 Rewrite `src/main.nx`

Replace current subcommand-dispatch body with the rewrite specified in §1.4 above. Approximate ~100 lines.

### 4.2 Write entry-handler declarations in `src/main.nx`

After `fn main`, declare the canonical 9 entry-handlers per §1.1 (compile_run, check_run, audit_run, query_run, teach_run, test_run, repl_run, deterministic_run, new_project).

Each handler declaration is ~5-15 lines.

### 4.3 Write `lib/test.nx`

```
// lib/test.nx — Test effect + assert_reporter + verify_assert handlers
//
// Kernel primitive served: #2 (Handlers with typed resume discipline)
// Mentl tentacle projected: Verify (secondary; assert_reporter handles runtime)
//
// ─── The Test effect ───────────────────────────────────────────

effect Test {
  assert(cond: Bool, msg: String) -> ()                  @resume=OneShot
  assert_eq<A>(actual: A, expected: A, msg: String) -> () @resume=OneShot
  assert_near(actual: Float, expected: Float, eps: Float, msg: String) -> () @resume=OneShot
}

// ─── assert_reporter — runtime fallback ──────────────────────

handler assert_reporter with pass_count = 0, fail_count = 0, fails = [] {
  assert(cond, msg) => ...  (per §1.3.1 above)
  assert_eq(a, b, msg) => ...
  assert_near(a, b, eps, msg) => ...
}

fn assert_summary(state) = {
  let { pass_count, fail_count, fails } = state
  "assertions: " ++ show(pass_count) ++ " pass, " ++ show(fail_count) ++ " fail"
}

// ─── verify_assert — compile-time lifting ────────────────────

handler verify_assert {
  assert(cond, msg) =>
    if is_statically_decidable(cond) {
      if evaluate_statically(cond) { resume(()) }
      else {
        perform report("E_AssertFailedAtCompileTime", current_span(), msg)
        resume(())
      }
    } else {
      perform assert(cond, msg)    // fall through
    }
  // assert_eq and assert_near similar; lift when both sides statically known
}

// ─── Supporting helpers ──────────────────────────────────────

fn structural_eq(a, b) = ...
fn is_statically_decidable(expr) = ...
fn evaluate_statically(expr) = ...
```

Estimated ~150-200 lines; scope-complete for Test effect + both handlers + lifting helpers.

### 4.4 Error catalog entries

Write seven new error files in `docs/errors/` per §1.4:

- `E_EntryHandlerNotFound.md`
- `E_EntryHandlerNotAHandler.md`
- `E_EntryHandlerArgsMismatch.md`
- `E_CliParseError.md`
- `E_AssertFailedAtCompileTime.md`
- `E_ComparesClosures.md`
- `E_AssertNearMissingEps.md`

Each ~40-60 lines, matching the canonical catalog format (kind / emitted-by / applicability / summary / why-it-matters / canonical-fix / example).

### 4.5 SYNTAX.md addition — Entry-handler section

Add a new section to `SYNTAX.md` defining:
- `handler <name>_run { ~> stack }` as canonical entry-handler form.
- CLI `--with <name>` syntax.
- Alias table.
- Naming convention: `*_run` suffix on entry-handlers (conventional; the CLI's resolution doesn't require the suffix, but the convention signals intent).

---

## 5. Post-edit audit command

```
bash ~/Projects/inka/tools/drift-audit.sh src/main.nx lib/test.nx docs/errors/E_*.md docs/SYNTAX.md
```

Checks:
- No residual hardcoded-subcommand `match argv` pattern in `src/main.nx`.
- Every entry-handler's row declaration parses.
- Every error file matches the catalog template.
- `--with` alias table in SYNTAX.md matches `parse_cli_args` in main.nx.
- No `run.nx` file exists anywhere (the rejected convention).

**New drift patterns in `tools/drift-patterns.tsv`:**
- `match argv \{\s*\["compile"` → flags the old hardcoded dispatch pattern.
- `\brun\.nx\b` → flags any reintroduction of the rejected convention.

---

## 6. Landing discipline

EH lands as **one focused commit** (item 20), after NS-structure (item 17') closes.

Sequence within the commit:
1. Rewrite `src/main.nx` with new `main` + `parse_cli_args` + `install_entry_handler`.
2. Write the 9 entry-handler declarations at top level of `main.nx`.
3. Write `lib/test.nx` with Test effect + handlers.
4. Write 7 new error files.
5. Update SYNTAX.md with entry-handler section + alias table.
6. Run drift-audit; confirm exit 0.
7. Smoke-test by running `inka --with teach_run` (should launch Mentl-voice default).
8. Smoke-test `inka compile <sample>` (should route through compile_run, produce WAT).
9. Smoke-test `inka test <sample>` (should route through test_run, report pass/fail).

**This walkthrough does NOT split into sub-handles.**

---

## 7. Dispatch

Same three options. Recommendation: **Option C (Opus inline)** for this one — the `main.nx` rewrite has enough subtlety (CLI parsing, handler resolution, smooth alias handling) that keeping Opus's reasoning in one session is preferable. The `lib/test.nx` write could be dual-tier (Option A).

---

## 8. What closes when EH lands

- Item 20 (CLI `--with` substrate) complete.
- `Test` effect + `assert_reporter` + `verify_assert` handlers LIVE; `inka test` works.
- `inka` bare invocation launches Mentl-voice (`teach_run`).
- `inka new <project>` scaffolds new projects from `lib/tutorial/00-hello.nx`.
- Every post-first-light handler addition adds ONE entry-handler; never touches CLI parser.
- Build profiles / test suites / deploy targets / chaos runs all express as normal handler compositions from this point on.

**Sub-handles split off:**

None. Every decision is complete.

---

## 9. Riffle-back items

1. **User-project entry-handler convention.** After EH lands for the compiler, verify that a user project following the `src/main.nx` template declares entry-handlers inline without friction. If users end up duplicating boilerplate across projects, that's a signal to extract common entry-handlers into a `lib/entry/` module.
2. **Reaffirm `*_run` suffix isn't mandated.** The CLI resolves any handler name; the `*_run` suffix is convention. Users can name entry-handlers whatever they want (`production`, `ci_test`, `demo`). Document this in SYNTAX.md and README.md so users don't feel coerced.
3. **Entry-handler composition examples.** Post-EH, write 2-3 example user-project `main.nx` files showing different handler compositions. These go in `lib/tutorial/` as content for tutorial files `02-handlers.nx` + `07-gradient.nx` (where entry-handler composition is the gradient's natural demonstration).
4. **CLI argument parsing edge cases.** `inka --with "chaos_run(seed=42, rate=0.01)"` — does the parser handle complex argument syntax? If not, either restrict (`--with chaos_run --seed=42 --rate=0.01` CLI form) or extend the parser. Resolve at implementation time.

---

## 10. Closing

EH dissolves "build profile," "test suite," "deploy target," "chaos config," "CI variant" into **named handler declarations + CLI resolution**. No config files. No manifests. No YAML. Every runtime variation a developer needs is a handler named in `main.nx`; every invocation is `inka --with <name>`. The CLI parser is ~50 lines; the error catalog is 7 small files; `lib/test.nx` is one effect + two handlers. Post-EH, "installing a new CI variant" is "write a new handler in `main.nx`" — nothing else to configure, nothing else to wire up.

**One walkthrough, one commit, build profiles / test suites / deploy targets all dissolved into normal Inka.**
