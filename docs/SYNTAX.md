# SYNTAX.md — Canonical syntax specification

> *The form that best translates intent into computation.*

This document is **the authoritative syntactic spec for Inka**. It binds the parser; the parser implements exactly this. It is written under dream-code discipline: every decision below is the IDEAL form, not a description of the current parser. Where the current parser deviates, the parser is wrong; SYNTAX.md is the wheel, the parser is the lathe being adjusted to it.

DESIGN.md articulates the medium's vision. The 12 specs in `docs/rebuild/` describe per-module behavior. INSIGHTS.md crystallizes load-bearing truths. **SYNTAX.md is the layer between vision and implementation: the surface form by which intent reaches the substrate.**

---

## Syntax ↔ the eight-primitive kernel

Every form below exists to make one primitive of the kernel (DESIGN.md §0.5) reachable as text. No form exists without a kernel correspondence. This is not decoration — it is a load-bearing constraint: a syntactic feature with no kernel primitive behind it has no semantic home, and every such feature in peer languages has been regretted. The kernel has eight primitives; Mentl has eight tentacles; the surface forms below have eight corresponding surfacing groups.

| # | Kernel primitive                                    | Tentacle   | Surface form                                                    |
|---|-----------------------------------------------------|------------|-----------------------------------------------------------------|
| 1 | SubstGraph + Env                                    | Query      | AST nodes implicit; `import` brings module envs together         |
| 2 | Handlers with typed resume discipline               | Propose    | `effect`, `handler`, `handle`/`~>`, `perform`, `resume`; `@resume=OneShot \| MultiShot \| Either` on effect ops |
| 3 | Five verbs                                          | Topology   | `\|>`  `<\|`  `><`  `~>`  `<~` with canonical layout             |
| 4 | Full Boolean effect algebra (`+ - & ! Pure`)        | Unlock     | `with E1 + !E2 + Pure` in fn sigs, handler sigs, types           |
| 5 | Ownership as an effect                              | Trace      | `own` / `ref` parameter markers; inferred by default             |
| 6 | Refinement types                                    | Verify     | `type Name = Base where predicate`                               |
| 7 | Continuous annotation gradient                      | Teach      | Every `with`-clause, every ownership marker, every refinement is one point on the gradient; zero annotations is the default (code runs) |
| 8 | HM inference with Reasons                           | Why        | No turbofish; generic params declared, inferred at call; wildcard `_` holes admit productive-under-error continuation |

**Rule:** before adding a syntactic form, ask: which kernel primitive does it surface (and therefore which tentacle speaks for it)? If none, the form doesn't belong. If multiple, they were missing a shared form — consolidate.

Each section below labels which primitive(s) its forms surface.

---

## Governing principles

Five rules every syntactic decision below honors:

1. **Layout IS contract.** The shape of the code on the page IS the computation graph. The parser enforces layout — code with the wrong layout is a parse error, not a stylistic preference.

2. **No redundant form.** If two syntactic forms produce the same graph, one is rejected. The medium refuses ceremony the substrate doesn't require.

3. **No syntactic ambiguity.** Every token sequence parses to exactly one AST under the rules below. Ambiguity in a language is debt the user pays; Inka pays its own debt at design time.

4. **Every construct has graph correspondence.** No syntax exists without a substrate operation it produces. If a form has no graph meaning, it doesn't exist.

5. **Diagnostics carry coordinates and Quick Fixes.** Every rejection produces a Located reason chain and (where mechanically apparent) a MachineApplicable patch. Errors are teaching surfaces, not punishment.

---

## Function declarations

### Canonical form — single expression

```
fn name(p1: T1, p2: T2) -> RetTy with E1 + E2 =
  expr
```

The body is a SINGLE EXPRESSION. The expression's value IS the function's return value. No braces. The expression may span multiple lines (indented continuation), but it is one syntactic expression.

Common case — pipeline body:
```
fn parse(path: Path) -> Config with IO + Fail<ParseError> =
  path
    |> read_file
    |> decode
```

### Canonical form — block body

When the function needs intermediate `let` bindings or multiple statements before its final expression:

```
fn process(input: List<Float>) -> Result with !Alloc = {
  let validated = input |> validate
  let normalized = validated |> normalize
  normalized |> fft |> extract
}
```

Braces ARE required when there are statements. The braces enclose a `BlockExpr(stmts, final_expr)`.

### Rejected form — braces around single expression

```
// REJECTED:
fn parse(path: Path) -> Config = {
  path |> read_file |> decode
}
```

Diagnostic: **`E_RedundantBraces`** at the opening `{`.
> "this body is a single expression; remove the braces. Pipelines and other compound expressions are themselves single expressions and do not require braces."

Quick Fix: remove the `{` and `}`.

### Generic type parameters

```
fn map<A, B>(f: A -> B, xs: List<A>) -> List<B> =
  ...
```

Angle brackets at declaration. Inferred at call sites. **No turbofish.** Call:
```
map(double, [1, 2, 3])   // correct — A=Int, B=Int inferred
```

```
// REJECTED:
map<Int, Int>(double, [1, 2, 3])
```
Diagnostic: **`E_ExplicitTypeParams`**: "type parameters are inferred at call sites; remove the explicit annotation."

### With-clauses for effects

```
fn fetch(url: String) with IO + Network =
  ...
```

Multiple effects join with `+`. Negation: `!E`. Parameterized: `E(arg)`. Combinations:
```
fn audio_stage(samples) with Sample(44100) + !Alloc + IO =
  ...
```

`Pure` is the identity element of `+`. Writing `with Pure` is allowed (and an explicit purity declaration); `with Pure + IO` simplifies to `with IO`.

### Return type omission

```
fn id(x: A) = x   // return type inferred
```

The `-> RetTy` clause is optional; absent = inferred. Most user code does NOT annotate return types. Mentl's gradient may suggest annotating when capabilities depend on the return type being explicit.

---

## Anonymous functions (lambdas)

### Canonical form

```
fn (params) => expr
```

`=>` separates params from body. Body is a single expression — same discipline as named fns.

```
fn (x) => x + 1
fn (a, b) => a * b
fn (point) => point.x + point.y
```

### Block body lambda — rare, allowed

```
fn (input) => {
  let cleaned = input |> clean
  cleaned |> transform
}
```

Same brace discipline: braces ONLY when statements precede the final expression.

### Tuple destructure in params

```
(audio, ctrl) |> fn ((a, c)) => process(a, c)   // explicit tuple unpack
(audio, ctrl) |> fn (a, c) => process(a, c)     // shorthand: positional unpack
```

The shorthand form unpacks a tuple ARGUMENT into positional params. This is the canonical form for receiving tuples produced by `<|` or `><`.

---

## Pipe verbs — the five-verb topology

Inka has FIVE pipe verbs. Each draws a specific shape on the page; the layout IS the topology.

### `|>` — converge

Sequential data flow. Right-applied to left.

```
input
  |> stage_a
  |> stage_b
  |> output
```

**Layout:** `|>` sits at the LEFT EDGE. Each stage on its own indented line.

Single line acceptable for short chains:
```
x |> double |> square
```

**Type rule:** if `left: A` and `right: A -> B with E`, then `left |> right: B with E`. The chain's row unions all stage rows.

### `<|` — diverge (fanout)

One input, multiple branches, output is a tuple of branch outputs. **Input is BORROWED into each branch** — a value cannot escape the branch tuple.

```
input
  <| (
    branch_a,
    branch_b,
    branch_c,
  )
```

Or equivalently with stage chains in branches:
```
input
  <| (
    fn (x) => x |> stage_a1 |> stage_a2,
    fn (x) => x |> stage_b1,
    extract_c,
  )
```

**Layout:** `<|` sits at the LEFT EDGE before the branch tuple. The branch tuple's `(` opens on the same line as `<|`; branches are on indented lines; the closing `)` returns to the indent of the opening branch.

**Type rule:** if `input: T` and branches are `(T -> A, T -> B, T -> C)`, the result is `(A, B, C)`. Row is union of all branch rows + upstream row.

**Ownership:** input is shared (borrowed). `own` values cannot flow through `<|` — `E_OwnershipViolation`.

### `><` — parallel compose (structural N-ary)

**Two or more INDEPENDENT pipelines run in parallel.** Each branch has its own input. Outputs are tupled.

**`><` is NOT a binary operator.** It is a structural N-ary construct with REQUIRED layout:

```
(pipeline_a)
    ><
(pipeline_b)
```

Three or more branches stack:
```
(pipeline_a)
    ><
(pipeline_b)
    ><
(pipeline_c)
```

**Layout requirements (parser-enforced):**
- Each branch must be parenthesized — `(...)`.
- Each branch is on its own line (or its own indented multi-line block).
- `><` sits ALONE on its own line at INDENTED CENTER (4-space indent typical).
- The construct as a whole reads top-to-bottom: branch, `><`, branch, `><`, branch.

After `><`, the chain returns to LEFT EDGE for whatever consumes the tupled result:
```
(audio_left  |> compress |> limit)
    ><
(audio_right |> compress |> limit)
|> stereo_mix
```

### Rejected `><` forms

```
// REJECTED — not parenthesized:
audio_left >< audio_right
```
Diagnostic: **`E_LayoutViolation`** at `><`: "`><` requires parenthesized pipelines on each side. Wrap each branch in `(...)`."
Quick Fix: insert parentheses around each operand.

```
// REJECTED — same line, no indent center:
(left) >< (right)
```
Diagnostic: **`E_LayoutViolation`**: "`><` must sit alone on its own line at indented center, between parenthesized branches on adjacent lines."
Quick Fix: reformat to canonical layout.

```
// REJECTED — values, not pipelines:
(audio, ctrl) >< (analyze, smooth)
```
Diagnostic: **`E_LayoutViolation`** at `><`: "`><` branches must be pipelines (sequences of stages), not value expressions. Did you mean `(audio |> analyze) >< (ctrl |> smooth)`?"
Quick Fix: rewrite each branch as a pipeline.

### `~>` — tee (handler-attach)

`expr ~> h` ≡ `handle expr with h`. The handler intercepts effects expr performs.

**Two layout-disambiguated forms:**

**Form A — block-scoped (newline-before).** Handler wraps the WHOLE prior chain.
```
source
  |> lex
  |> parse
  |> infer
  ~> env_handler          // wraps (lex |> parse |> infer)
  ~> graph_handler        // wraps env_handler(...)
  ~> diagnostics_handler  // outermost — sandbox boundary
```

**Form B — inline (no newline).** Handler scoped to the IMMEDIATELY PRECEDING stage only.
```
raw_string
  |> parse_json ~> catch_parse_error(default = "{}")
  |> validate ~> log_warnings
  |> save_to_db
```

A `Newline` token directly before `~>` means Form A. No newline means Form B. **This is the only place in Inka where whitespace is semantically load-bearing.** It is load-bearing because the visual layout IS the computation graph.

**Type rule:** `row(expr ~> h) = row(expr) - handled(h) + row(h)`. The handler subtracts what it absorbs; anything its arms perform is added.

### `<~` — feedback (cycle closure)

Closes a cycle back into the pipeline; the value computed flows back as input on the next iteration.

```
signal <~ delay(3)        // 3-sample feedback delay
state  <~ accumulate(0)   // running accumulator
filter <~ filter_spec(N, coeffs)
```

**Layout:** `<~` may appear INLINE (one line) or at INDENTED CENTER for clarity:
```
signal
    <~ delay(3)
```

**Type rule:** `<~` requires an iterative context (`Sample`, `Tick`, `Clock` handler installed somewhere in the enclosing handler stack). RHS must be a `FeedbackSpec` value (constructed via `delay(N)`, `accumulate(init)`, `filter_spec(N, coeffs)`, etc.). Without iterative context: `E_FeedbackNoContext` at the `<~` site.

---

## Records

Inka records are **structural**: a record TYPE is `{name: T1, age: T2}` — no nominal declaration ceremony required. Two records with the same fields and types unify. Row polymorphism is supported.

### Canonical literal form

```
{name: "Morgan", age: 30}
```

Fields separated by commas. Each field is `name: value`. Trailing comma allowed (recommended for multi-line):
```
{
  name: "Morgan",
  age: 30,
  email: "morgan@example.com",
}
```

**Field punning** — when the value's expression IS a variable of the same name as the field:
```
let name = "Morgan"
let age = 30
{name, age}              // sugar for {name: name, age: age}
```

Mixed punning:
```
{name, age, email: derive_email(name)}
```

**Sorting at parse time.** Fields are sorted alphabetically by name when the AST is constructed. Source order is irrelevant; the canonical AST has fields in alphabetical order. This makes record-equality and field-offset computation deterministic.

### Canonical type form

```
{name: String, age: Int}
```

Inline structural. Used in fn parameter types, return types, let-bindings. No declaration ceremony.

### Row polymorphism

Open record type — accepts any record with AT LEAST these fields:
```
fn greet(u: {name: String, ...}) -> String =
  "Hello, " ++ u.name
```

`...` is anonymous rest; `...R` binds the rest to a row variable `R` for further use:
```
fn extend(base: {name: String, ...R}, age: Int) -> {name: String, age: Int, ...R} =
  ...
```

### Nominal record types

When a brand is wanted (distinct identity, not just shape):
```
type Person = {name: String, age: Int}
type Customer = {name: String, age: Int}    // DIFFERENT type from Person despite same shape
```

Nominal records are constructed using their type name:
```
let p = Person{name: "Morgan", age: 30}
let c = Customer{name: "Morgan", age: 30}
// p and c have different types; cannot be unified
```

### Pattern syntax for records

```
let {name, age} = morgan       // both fields bound to locals
let {name, ...rest} = morgan   // bind name; rest is a record of remaining fields
let {name: n, age: a} = morgan // bind to renamed locals
```

### Field access

```
morgan.name
nested.outer.inner
```

Field access lowers to `LFieldLoad` with offset resolved at compile time from the record's type. O(1) load.

---

## Algebraic data types

### Type declaration

```
type Option<A>
  = Some(A)
  | None

type Tree<A>
  = Leaf
  | Branch(Tree<A>, A, Tree<A>)
```

Each variant is a constructor with zero or more fields. Type parameters in angle brackets.

### Constructor calls (value construction)

```
let some_value = Some(42)
let nothing = None
let tree = Branch(Leaf, 1, Branch(Leaf, 2, Leaf))
```

Same syntax as function calls. Inference disambiguates by looking up the name in env: if it's a `ConstructorScheme`, it lowers to `LMakeVariant` with the constructor's tag_id; if a `FnScheme`, to `LCall`.

### Pattern matching

```
match opt {
  Some(v) => v,
  None    => 0,
}
```

Arms separated by commas. Trailing comma allowed.

### Exhaustiveness

The match must cover every variant of the scrutinee's type, OR include a wildcard arm `_ => default`. Missing variants without wildcard:

Diagnostic: **`E_PatternInexhaustive`** at the `match` keyword:
> "match on Option does not cover variant: None. Add `None => ...` arm or `_ => ...` wildcard."

Quick Fix: insert stubs for missing variants.

### Refinement types

```
type Sample = Float where -1.0 <= self <= 1.0
type NonEmpty<A> = List<A> where len(self) > 0
type Even = Int where self % 2 == 0
```

`self` refers to the value being refined. The refinement is a `Predicate` discharged by the `Verify` effect at construction sites and elsewhere as needed.

---

## Effect declarations

### Unparameterized effect

```
effect IO {
  print(msg: String) -> ()       @resume=OneShot
  read() -> String                @resume=OneShot
}

effect State<S> {
  get() -> S                      @resume=OneShot
  set(v: S) -> ()                 @resume=OneShot
}
```

Each operation declares its parameter types, return type, and **resume discipline** (`@resume=OneShot | MultiShot | Either`). The resume discipline is part of the operation's identity; it's checked at every handler arm and call site.

### Parameterized effect (first-class)

```
effect Sample(rate: Int) {
  tick() -> ()                    @resume=OneShot
  current_sample() -> Float       @resume=OneShot
}

effect Budget(limit: Int) {
  spend(amount: Int) -> Bool      @resume=OneShot
}
```

The effect name itself carries arguments. **Row algebra treats `Sample(44100)` and `Sample(48000)` as distinct effects.** Equality requires name AND argument value match (scalar literal equality for Int / Bool / String args; structural equality for compound types).

### Installation in `with` clauses

```
fn audio_loop() with Sample(44100) + IO + !Alloc =
  ...
```

The argument is evaluated at install time and frozen. Two functions declared with `Sample(44100)` and `Sample(48000)` cannot interoperate without an explicit handler bridge.

### Resume discipline meaning

- **`@resume=OneShot`** — the handler arm calls `resume(...)` AT MOST once per invocation. Continuation lives on the stack; no heap capture; performance is direct-call equivalent. Compile error if an arm calls resume twice.
- **`@resume=MultiShot`** — the arm calls `resume(...)` zero or more times. Continuation captured to the heap as a closure. Enables backtracking, non-determinism, generators.
- **`@resume=Either`** — discipline not pinned at declaration time. Handler arms may use either; loses some optimization headroom.

This annotation is **load-bearing** — see DESIGN Ch 1 and the discussion in this codebase's conversation history. It's why Inka can express real-time DSP and constraint-search backtracking under one effect algebra.

### Negation in `with` clauses

```
fn pure_op(x: Int) -> Int with !Alloc + !IO =
  ...
```

`!E` proves ABSENCE of effect E. Stronger than not-mentioning E because it propagates transitively through the call graph: any callee that performs E causes the whole declaration to fail with `E_EffectMismatch`.

`Pure` is shorthand for "the body's row must be EfPure (literally empty)":
```
fn pure_op(x) with Pure = x + 1
```

---

## Handler declarations

### Canonical form

```
handler name(cfg_p1: T1, cfg_p2: T2) with state_a = init_a, state_b = init_b {
  op_arm_1(args) => body,
  op_arm_2(args) => body,
}
```

Three parts:
1. **Config parameters** in `(...)` — closure-captured at install site.
2. **State** after `with` — internal state evolving across arms.
3. **Op arms** in `{...}` — one arm per effect operation handled.

### Examples

```
// No config, no state — pure handler
handler log_to_stderr {
  log(msg) => perform write_stderr(msg); resume(()),
}

// Config (URL captured at install) + no state
handler websocket_sink(url: String) {
  emit(ev) => perform ws_send(url, encode(ev)); resume(()),
}

// State (counter that evolves)
handler counter with n = 0 {
  inc() => resume(()) with n = n + 1,
  get() => resume(n),
}

// Both config + state
handler bounded_log(prefix: String) with count = 0, max = 100 {
  log(msg) => {
    if count >= max { resume(()) }
    else {
      perform write_stderr(prefix ++ ": " ++ msg)
      resume(()) with count = count + 1
    }
  },
}
```

### State updates via `with` on resume

When an arm wants to evolve state, it uses a `with` clause on `resume`:

```
inc() => resume(()) with n = n + 1
```

The `with` clause lists state updates by field name. Unlisted state stays unchanged.

### Installation

Two equivalent forms:

```
// Block form
handle {
  body_expr
} with handler_name(cfg_args)

// Pipe form
body_expr ~> handler_name(cfg_args)
```

Pipe form is preferred for chains; block form for embedded sub-scopes.

### Negation guards on handlers

```
handler affine_ledger with !Consume {
  consume(name, span) => ...,
}
```

`with !Consume` on the handler itself means: the arms cannot recurse through `consume`. Boolean effect algebra gates this at compile time.

---

## Pipeline + handler installation in code

### Block handle

```
let result = handle {
  computation()
} with state_handler with s = 0 {
  ...
}
```

### Inline pipe handle

```
let result = computation() ~> state_handler
```

For handlers with config:
```
let log = handle { work() } with bounded_log("INFO")
```

### Multi-handler chain (capability stack)

```
source
  |> stages
  ~> mentl_default
  ~> affine_ledger
  ~> verify_ledger
  ~> diagnostics_handler   // outermost = least trusted = sandbox boundary
```

Reading top-to-bottom = inner-to-outer trust hierarchy.

---

## Pattern syntax

Patterns appear in `let`, `match`, function parameters, and lambda parameters.

### Variants

| Pattern             | Form                              | Binds              |
|---------------------|-----------------------------------|--------------------|
| `PVar`              | `name`                            | binds `name`       |
| `PWild`             | `_`                               | binds nothing      |
| `PLit`              | `42`, `"hello"`, `true`, `()`     | matches literal    |
| `PCon`              | `Some(v)`, `Branch(l, x, r)`      | binds inner pats   |
| `PTuple`            | `(a, b, c)`                       | positional binds   |
| `PList`             | `[a, b, c]`, `[head, ...rest]`    | positional + rest  |
| `PRecord`           | `{name, age}`, `{name: n, ...r}`  | field punning + rest |

### Examples

```
match value {
  Some(0)            => "zero",
  Some(n)            => "got " ++ int_to_str(n),
  None               => "nothing",
}

match list {
  []                 => "empty",
  [single]           => "one element: " ++ show(single),
  [head, ...rest]    => "head + " ++ int_to_str(len(rest)),
}

match user {
  {name: "Morgan", ...} => "found Morgan",
  {name: n}             => "user " ++ n,
}

let (x, y) = point
let {name, age} = user
let [first, second, ...rest] = items
```

### Exhaustiveness

Match arms must cover all variants OR include a wildcard. Missing-variant errors include the missing variants by name (per H3's exhaustiveness machinery).

---

## Imports

### Canonical form

```
import path/to/module
```

The path is a slash-separated module name. The `ModuleResolver` handler maps it to a file in `std/` or the project's source tree.

### Selective import

```
import path/to/module {name_a, name_b, name_c}
```

Only the listed names are brought into scope.

### No rename / alias

There is no `import X as Y`. Full paths in source are clearer than aliases. If a name conflict arises, use the full qualified name at the call site:

```
import dsp/spectral
import lin/spectral

// At usage:
dsp.spectral.fft(samples)
lin.spectral.fft(matrix)
```

---

## Comments

### Line comments

```
// This is a line comment
let x = 1   // trailing comment
```

### Doc comments

```
/// Computes the FFT of a sample frame.
///
/// The frame's length should be a power of 2; non-powers are zero-padded.
fn fft(frame: List<Float>) -> List<Complex> with Alloc =
  ...
```

`///` doc comments attach to the immediately following declaration (fn, type, effect, handler, let). They render through the docs-backend handler. Markdown is supported in the body.

### No block comments

Inka does not have `/* ... */` block comments. Composability of the substrate means there's no need to disable large code regions; if code is unwanted, delete it. Version control preserves history.

---

## Strings

### Basic literal

```
"hello"
"with newline\n"
"escaped quote: \""
```

Escape codes: `\n`, `\r`, `\t`, `\\`, `\"`, `\0`, `\xHH` (hex byte).

### Interpolation

```
let name = "Morgan"
let greeting = "hello, ${name}!"
let calc = "result is ${a + b}"
```

`${expr}` is replaced with the expression's value. The expression's type must implement `Show` (or be a String already).

### Multi-line

```
let block = """
  This is a multi-line string.
  It preserves newlines.
"""
```

Triple-quoted strings span multiple lines. Leading whitespace common to all lines is stripped (indentation-aware).

---

## Operator precedence

One canonical table. Higher number = tighter binding.

| Prec | Operators                                | Associativity   | Notes                          |
|------|------------------------------------------|-----------------|--------------------------------|
| 13   | `.` (field access), call `f(args)`       | left            | postfix                        |
| 12   | unary `-`, unary `!`                     | right (prefix)  |                                |
| 11   | `*`, `/`, `%`                            | left            |                                |
| 10   | `+`, `-` (binary)                        | left            |                                |
| 9    | `++`                                     | right           | string + list concat           |
| 8    | `==`, `!=`, `<`, `>`, `<=`, `>=`         | non-associative |                                |
| 7    | `&&`                                     | left            |                                |
| 6    | `\|\|`                                   | left            |                                |
| 5    | `\|>`                                    | left            | sequential pipe                |
| 4    | `<\|`, `><`, `<~`, `~>` (inline)         | left            | convergent / inline tee        |
| 3    | `~>` (block — newline before)            | left (lowest)   | wraps whole prior chain        |
| 2    | `=` in let-binding, `=>` in lambda       | non-associative |                                |
| 1    | (reserved)                               |                 |                                |

The block-form `~>` deliberately has the LOWEST precedence so it captures the whole preceding chain as its body.

---

## Layout enforcement

The parser enforces layout rules. Code that violates layout produces `E_LayoutViolation` with a Quick Fix that reformats to canonical form.

### Sequential verbs at LEFT EDGE

`|>` and `~>` (both forms) sit at the left edge of the code's enclosing indent. Each stage on its own indented line:

```
input
  |> stage_a
  |> stage_b
  ~> handler
```

### Convergent verbs at INDENTED CENTER

`<|`, `><`, `<~` sit at indented center (typically 4-space indent from the enclosing left-edge):

```
(branch_a)
    ><
(branch_b)
```

```
input
  <| (
    branch_a,
    branch_b,
  )
```

### Return to LEFT EDGE for continuing chain

After a convergent construct, the chain returns to the left edge:

```
(audio |> compress)
    ><
(ctrl  |> scale)
|> mix          // returns to left edge
~> sink
```

### Indentation discipline

Inka uses 2-space indentation. The parser is INDENT-AWARE for layout enforcement (similar to F# and OCaml's indent-sensitive modes). Mixed tabs and spaces: rejected.

---

## Generic type parameters

### Declaration

```
fn map<A, B>(f: A -> B, xs: List<A>) -> List<B> = ...
type Pair<A, B> = {first: A, second: B}
effect State<S> { get() -> S; set(v: S) -> () }
```

Angle brackets at declaration. Type parameters scoped to the declaration's body.

### Inferred at call sites

```
let doubled = map(double, [1, 2, 3])   // A=Int, B=Int — inferred from arg types
```

No turbofish (`map<Int, Int>(...)`) is allowed. Inference must succeed; if it can't, it's a type error indicating the user needs to provide more context (typically by annotating an intermediate let-binding).

### Higher-rank parameters

For polymorphism that crosses scopes (rare; usually inferred):
```
fn run_with<E>(f: fn() -> () with E) = ...
```

---

## Refinement types

```
type Sample = Float where -1.0 <= self <= 1.0
type NonEmpty<A> = List<A> where len(self) > 0
type ValidPort = Int where self >= 1024 && self <= 65535
```

`self` refers to the value being refined. The refinement is a `Predicate`; the `Verify` effect discharges the obligation at construction sites.

Construction:
```
let s: Sample = 0.5    // verify discharges -1.0 <= 0.5 <= 1.0 statically
let p: ValidPort = 8080 // statically discharged
```

Refinement violations:
```
let bad: Sample = 1.5   // E_RefinementRejected: 1.5 violates -1.0 <= self <= 1.0
```

---

## Top-level program structure

A `.ka` file is a sequence of top-level statements. Each is one of:

- `import path/to/module` — module imports
- `type Name<P> = ...` — type declarations
- `effect Name { ... }` — effect declarations
- `handler name(...) with ... { ... }` — handler declarations
- `fn name(...) = ...` — function declarations
- `let name = ...` — top-level value bindings (constants)

A `.ka` file with no `main` function is a LIBRARY module — its declarations are imported by other modules. Compilation produces a WAT module whose `_start` is a clean exit.

A `.ka` file with `fn main()` is an EXECUTABLE — `_start` invokes `main`.

---

## Token enumeration

The lexer emits a stream of `Token` values. The parser consumes them via exhaustive match. Both the wrapper shape and the variant enumeration are canonical here; Ω.4's parser refactor implements them exactly.

### Token wrapper — substrate-native pattern

```
type Token = Tok(TokenKind, Span)
```

This mirrors the `N(NodeBody, Span, Int)` wrapper for AST nodes: a structured-value with positional metadata. Every token carries its source span for parser diagnostics and downstream Located reasons.

Accessors:
```
fn token_kind(t) = let Tok(k, _) = t; k
fn token_span(t) = let Tok(_, s) = t; s
```

### TokenKind variants — exhaustive

```
type TokenKind
  // ─── Keywords ─────────────────────────────────────────────────────
  = TFn | TLet | TIf | TElse | TMatch | TType
  | TEffect | THandle | THandler | TWith
  | TResume | TPerform
  | TFor | TIn | TLoop | TBreak | TContinue | TReturn
  | TImport | TWhere
  | TOwn | TRef | TPure
  | TTrue | TFalse

  // ─── Identifiers and literals (carry payload) ─────────────────────
  | TIdent(String)
  | TInt(Int)
  | TFloat(Float)
  | TString(String)
  | TDocComment(String)             // /// — emitted ONLY when triple-slash
                                    //   detected; attaches to next decl

  // ─── Two-character operators ──────────────────────────────────────
  | TEqEq | TBangEq | TLtEq | TGtEq          // comparison
  | TArrow | TFatArrow                       // -> and =>
  | TPlusPlus                                // ++ concat
  | TPipeGt | TLtPipe | TGtLt | TTildeGt | TLtTilde   // five verbs
  | TAndAnd | TOrOr                          // logical
  | TColonColon                              // :: (path separator, future)

  // ─── Single-character operators and punctuation ───────────────────
  | TLParen | TRParen | TLBrace | TRBrace | TLBracket | TRBracket
  | TComma | TDot | TColon | TSemicolon
  | TPlus | TMinus | TStar | TSlash | TPercent
  | TEq | TLt | TGt | TBang
  | TPipe | TTilde | TAt | TQuestion

  // ─── Layout / structural ──────────────────────────────────────────
  | TNewline                        // semantic per DESIGN Ch 2 / `~>` form
  | TEof                            // end of input — always last
```

### Variant catalog (canonical lexical form, payload, expected parse contexts)

| Variant         | Lexical form     | Payload   | Where parser expects it                       |
|-----------------|------------------|-----------|------------------------------------------------|
| **Keywords (24)** |                |           |                                                |
| `TFn`           | `fn`             | —         | start of function declaration / lambda         |
| `TLet`          | `let`            | —         | start of let-binding                           |
| `TIf`           | `if`             | —         | start of if-expression                         |
| `TElse`         | `else`           | —         | between if branches                            |
| `TMatch`        | `match`          | —         | start of match-expression                      |
| `TType`         | `type`           | —         | start of type declaration                      |
| `TEffect`       | `effect`         | —         | start of effect declaration                    |
| `THandle`       | `handle`         | —         | start of handle-expression                     |
| `THandler`      | `handler`        | —         | start of handler declaration                   |
| `TWith`         | `with`           | —         | effect clauses, handler state, handle-with     |
| `TResume`       | `resume`         | —         | inside handler arm body                        |
| `TPerform`      | `perform`        | —         | invoking an effect operation                   |
| `TFor`          | `for`            | —         | reserved (for-comprehension future)            |
| `TIn`           | `in`             | —         | reserved (let-in future)                       |
| `TLoop`         | `loop`           | —         | start of loop expression                       |
| `TBreak`        | `break`          | —         | inside loop body                               |
| `TContinue`     | `continue`       | —         | inside loop body                               |
| `TReturn`       | `return`         | —         | early return from fn body                      |
| `TImport`       | `import`         | —         | top-level import statement                     |
| `TWhere`        | `where`          | —         | refinement type clause                         |
| `TOwn`          | `own`            | —         | parameter ownership marker                     |
| `TRef`          | `ref`            | —         | parameter borrow marker                        |
| `TPure`         | `Pure`           | —         | `with Pure` declaration                        |
| `TTrue`         | `true`           | —         | Bool literal                                   |
| `TFalse`        | `false`          | —         | Bool literal                                   |
| **Identifiers and literals (5)** |  |           |                                                |
| `TIdent(s)`     | `[A-Za-z_][...]` | name      | variable refs, fn names, type names, etc.      |
| `TInt(n)`       | `[0-9]+`         | i32 value | integer literal                                |
| `TFloat(f)`     | `[0-9]+.[0-9]+`  | f64 value | floating-point literal                         |
| `TString(s)`    | `"..."` or `"""..."""` | string content (escape-resolved, interp markers preserved) | string literal |
| `TDocComment(s)`| `/// ...`        | comment text (one line, leading `///` stripped) | attaches to next declaration |
| **Two-character operators (15)** |  |           |                                                |
| `TEqEq`         | `==`             | —         | equality comparison                            |
| `TBangEq`       | `!=`             | —         | inequality comparison                          |
| `TLtEq`         | `<=`             | —         | less-than-or-equal                             |
| `TGtEq`         | `>=`             | —         | greater-than-or-equal                          |
| `TArrow`        | `->`             | —         | function return type, fn-type form             |
| `TFatArrow`     | `=>`             | —         | match arm separator, lambda body separator     |
| `TPlusPlus`     | `++`             | —         | string/list concat                             |
| `TPipeGt`       | `\|>`            | —         | sequential pipe                                |
| `TLtPipe`       | `<\|`            | —         | divergent pipe (fanout)                        |
| `TGtLt`         | `><`             | —         | parallel compose (structural N-ary)            |
| `TTildeGt`      | `~>`             | —         | handler-attach (block / inline by newline)     |
| `TLtTilde`      | `<~`             | —         | feedback                                       |
| `TAndAnd`       | `&&`             | —         | logical and                                    |
| `TOrOr`         | `\|\|`           | —         | logical or                                     |
| `TColonColon`   | `::`             | —         | reserved (path separator, namespace future)    |
| **Single-character operators and punctuation (23)** |  |           |                              |
| `TLParen`       | `(`              | —         | grouping, params, tuples, calls                |
| `TRParen`       | `)`              | —         | close grouping                                 |
| `TLBrace`       | `{`              | —         | blocks, records, handler arms, type variants   |
| `TRBrace`       | `}`              | —         | close LBrace                                   |
| `TLBracket`     | `[`              | —         | list literals, list patterns                   |
| `TRBracket`     | `]`              | —         | close LBracket                                 |
| `TComma`        | `,`              | —         | separator in tuples, params, fields, lists     |
| `TDot`          | `.`              | —         | field access                                   |
| `TColon`        | `:`              | —         | type annotation, record field binding          |
| `TSemicolon`    | `;`              | —         | statement separator (when explicit)            |
| `TPlus`         | `+`              | —         | addition; effect union                         |
| `TMinus`        | `-`              | —         | subtraction; unary negate                      |
| `TStar`         | `*`              | —         | multiplication                                 |
| `TSlash`        | `/`              | —         | division; module-path separator                |
| `TPercent`      | `%`              | —         | modulo                                         |
| `TEq`           | `=`              | —         | binding (let / fn / type)                      |
| `TLt`           | `<`              | —         | less-than; generic-param open                  |
| `TGt`           | `>`              | —         | greater-than; generic-param close              |
| `TBang`         | `!`              | —         | logical not; effect negation                   |
| `TPipe`         | `\|`             | —         | type variant separator; lambda param fence (future) |
| `TTilde`        | `~`              | —         | reserved                                       |
| `TAt`           | `@`              | —         | annotation marker (`@resume=OneShot`)          |
| `TQuestion`     | `?`              | —         | hole / placeholder                             |
| **Layout / structural (2)** |     |           |                                                |
| `TNewline`      | `\n`             | —         | semantic per DESIGN Ch 2 (block-form `~>`)     |
| `TEof`          | (end of input)   | —         | always last token; parser uses to terminate    |

**Total: 69 variants.**

### Lexer obligations

- **Every emitted Token MUST be one of the 69 enumerated variants.** Adding a new token kind requires updating SYNTAX.md first, then the lexer, then the parser's match (which fails to compile until the new variant is handled — H6's discipline applied at the lexical layer).
- **Whitespace (other than `\n`) is silently consumed.** The lexer skips spaces and tabs without emitting a token. Only newlines are semantic.
- **Line comments `// ...` are silently consumed.** No token emitted.
- **Doc comments `/// ...` emit `TDocComment(text)`** with the leading `///` stripped. The parser attaches each `TDocComment` to the next declaration it sees.
- **Block comments do not exist.** Per the Comments section of this spec.

### Parser obligations

- **Match on `Token` must be exhaustive.** No wildcard arms over `TokenKind` without explicit per-variant enumeration. H6's discipline: `_ => …` on a load-bearing ADT is rejected by code review and substrate convention.
- **Span propagation.** Every parsed AST node is constructed with the joined span of its constituent tokens. Use `span_join(token_span(first), token_span(last))`.
- **Generic-type angle brackets disambiguated by context.** `<` and `>` are TLt/TGt at expression position; in type position (after `:`, `->`, in fn-decl angle params), they open/close generic parameter lists. This is parser-internal context tracking, not a separate token kind.
- **Pipe-vs-or disambiguation.** `|` is TPipe (alone); `||` is TOrOr (two-char). Type-variant `|` separators use TPipe.

---

## Diagnostic catalog (syntax-level errors introduced by SYNTAX.md)

| Code                  | Trigger                                       | Quick Fix                                      |
|-----------------------|-----------------------------------------------|------------------------------------------------|
| `E_RedundantBraces`   | braces around single-expression body          | remove `{` and `}`                             |
| `E_LayoutViolation`   | wrong indent / wrong line / wrong wrapping    | reformat to canonical layout                   |
| `E_ExplicitTypeParams`| turbofish `f<T>(...)` at call site            | remove `<T>`; let inference fill it            |
| `E_PatternInexhaustive` | match missing variants, no wildcard         | insert stubs for missing variants              |
| `E_RefinementRejected`  | value violates refinement predicate         | adjust value or widen refinement               |
| `E_EffectMismatch`    | declared row doesn't subsume body row         | widen declaration OR install absorbing handler |
| `E_PurityViolated`    | `with Pure` body performs non-empty effects   | remove `with Pure` or absorb the effect        |
| `E_FeedbackNoContext` | `<~` used without iterative context           | install `Sample`/`Tick`/`Clock` handler        |
| `E_OwnershipViolation` | `own` consumed twice / escapes ref scope     | restructure to single-consume or use `ref`     |
| `E_HandlerUninstallable` | handler arms need effects context disallows | widen ambient row or restructure handler       |
| `E_MissingVariable`   | name not in scope                             | check spelling; check imports                  |
| `E_TypeMismatch`      | unification failed                            | adjust types; widen / narrow                   |
| `E_OccursCheck`       | infinite type                                 | restructure to break cycle                     |
| `T_OverDeclared`      | declared row wider than body uses             | tighten the signature to unlock capabilities   |
| `T_Gradient`          | annotation would unlock a capability          | accept the suggestion to unlock                |
| `W_Suggestion`        | probable Quick Fix available                  | (Mentl-proposed)                               |

Every diagnostic carries a Located reason chain, source span, applicability tag (`MachineApplicable`, `MaybeIncorrect`, `HasPlaceholders`, `Unspecified`), and (where mechanical) a Patch.

---

## Cross-references

- DESIGN.md Ch 2 — the five verbs, with worked examples
- DESIGN.md Ch 4 — the substrate (graph + handler)
- INSIGHTS.md — Visual Programming in Plain Text; Five Verbs = Complete Basis
- spec 03 — Typed AST (NodeBody, Expr, Stmt, Pat)
- spec 10 — Pipes (PipeKind, layout enforcement)
- spec 11 — Clock (iterative context for `<~`)
- protocol_pattern_completion_check.md — output-boundary discipline

---

## What this document is NOT

- NOT a tutorial. See `examples/` for tutorials.
- NOT a reference for stdlib functions. See `std/` source + generated docs.
- NOT a description of the current parser. The parser implements this; where they disagree, the parser is wrong.
- NOT an aspirational wishlist. Every form here is required to land in the parser by Phase Ω.4.

---

## Authority

This document supersedes any syntactic decisions implicit in DESIGN.md, INSIGHTS.md, the 12 specs, or current parser behavior. Where another document conflicts with SYNTAX.md, SYNTAX.md is correct and the other document gets a corrective revision.

Mentl's discipline applies to syntax: every form below was decided by asking the eight interrogations — one per kernel primitive (DESIGN.md §0.5), one per Mentl tentacle. Graph (what AST does it produce?), handler + resume discipline (what installed handler reads it, with what resume type?), verb (which topology?), row (what `+ - & !` constraint?), ownership (what `own`/`ref` does it carry?), refinement (what predicate does it admit?), gradient (what annotation would it unlock?), Reason (what edge does it leave for the Why Engine?). Forms that failed any of the eight were rejected.

When questions arise about syntax not yet covered here: open a γ-style walkthrough in `docs/rebuild/simulations/syntax/<topic>.md`, resolve the design question, then update this document.
