---
description: how to run and test lux code
---
// turbo-all

## Run a Lux program
1. `cargo run --quiet -- <file.lux>` — run with teaching output
2. `cargo run --quiet -- --quiet <file.lux>` — run without teaching output
3. `cargo run --quiet -- --no-check <file.lux>` — skip type checker (needed for self-hosted compiler tests that import std/compiler/)

## Run all golden tests
1. `cargo test --test examples`

## Run all type checker unit tests
1. `cargo test --test type_tests`

## Run full test suite
1. `cargo test`

## Quick smoke test (all examples)
1. `for f in examples/*.lux; do echo "--- $f ---"; cargo run --quiet -- --quiet "$f" 2>&1 | head -3; done`

## Add a new golden test
1. Create `examples/<name>.lux` with your test code
2. Run it: `cargo run --quiet -- --quiet examples/<name>.lux > examples/<name>.expected 2>/dev/null`
3. If it imports self-hosted compiler modules, add the name to `needs_no_check` in `tests/examples.rs`
4. Verify: `cargo test --test examples`

## Self-hosted compiler tests
Self-hosted compiler tests (lexer_test, parser_test, checker_test, codegen_test) must use `--no-check` because they import `std/compiler/` modules which use ADTs not yet recognized by the Rust type checker. The Lux-in-Lux compiler handles these natively.
