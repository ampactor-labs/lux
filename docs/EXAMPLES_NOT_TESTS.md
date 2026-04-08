# Examples, Not Tests

*Lux doesn't have tests. It has examples. An example that runs is a proof.
An example that crashes is a bug report. There is no third thing.*

---

## The Insight

A test framework gives you four things: setup, mock, assert, teardown.

In Lux, `handle` is all four:

```lux
handle { computation } with state = initial {
  operation(args) => { resume(result) with state = updated }
}
```

- **Setup** — handler-local state (`with state = initial`)
- **Mock** — the handler body (decides what every operation means)
- **Assert** — the return value (if it's wrong, you see it)
- **Teardown** — `resume` (the handler controls what happens next)

There is nothing to add. A test framework would be a second mechanism
for something the language already does. In Lux, that's wrong by
construction.

---

## Examples ARE Proofs

An example file is a program. If it runs and produces the right output,
the mechanism it exercises works. If it doesn't, the mechanism is broken.

```
examples/
  graph.lux          — effects + handlers + structures work
  kv_store.lux       — handler swapping works
  diamond.lux        — |> <| >< compose correctly
  wasm_check.lux     — the checker compiles to WASM
  wasm_mutual.lux    — mutual recursion works in WASM
```

Each file IS its own specification. The name says what it proves. The
output says whether it passes. `lux examples/graph.lux` is the test
runner. The shell is the harness.

To verify everything:

```bash
for f in examples/*.lux; do
  lux --quiet "$f" && echo "OK: $f" || echo "FAIL: $f"
done
```

No test discovery. No annotations. No configuration. The filesystem IS
the test suite.

---

## Why No Package Manager

A package in most languages is: code + metadata + dependency resolution +
version management + a registry + a build system integration + trust on
download.

In Lux, a package is:

```lux
import path/to/module
```

A handler is a module. A module is a file. A file is importable by path.
Dependencies are explicit in the import — you can see them. Capabilities
are explicit in the effects — you can audit them.

```
  json_parser
    effects: (pure)                    ✓ expected for a parser

  sketchy_logger
    effects: Log, Http, FileSystem     ⚠ a logger that needs Http?
```

The effect signature IS the dependency audit. `!Network` means provably
no network access — enforced by the type system, not a sandbox, not a
policy file, not trust. A module with `with Compute, Log` literally
cannot perform IO. The compiler proves it.

What a package manager solves:
- **Discovery** — the effect signature tells you what a module does
- **Trust** — `!IO` is a proof, not a promise
- **Versioning** — if the types match, it works; if they don't, it fails at compile time
- **Resolution** — `import` is a path; paths compose; no solver needed

The remaining problem is distribution — getting code from elsewhere onto
your machine. That's `git clone` or `curl`. Not a language feature.

---

## The Pattern

Lux doesn't add mechanisms for things that already exist in the
language:

| Other languages have | Lux has |
|---------------------|---------|
| Test framework | Examples that run |
| Mock library | Handler swap |
| Dependency injection | Effect + handler |
| Package manager | Import + effect audit |
| Sandbox | `!IO`, `!Network`, `!Alloc` |
| Runtime assertions | Refinement types |
| Documentation tests | Examples |

One mechanism. Many consequences. Nothing to add.
