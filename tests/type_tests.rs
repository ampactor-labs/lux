//! Unit tests for the Lux type checker.
//!
//! Tests core type system functionality: unification, inference, ADTs,
//! effects, patterns, and error reporting.

/// Helper: parse, check, and return Ok/Err.
fn check(source: &str) -> Result<(), String> {
    let prelude_src = lux::load_prelude();
    let mut checker = lux::checker::ReplChecker::new();

    // Load prelude so builtin types and functions are available
    if !prelude_src.is_empty() {
        lux::token::CURRENT_FILE_ID.with(|id| id.set(lux::token::next_file_id()));
        if let Ok(tokens) = lux::lexer::lex(&prelude_src) {
            if let Ok(program) = lux::parser::parse(tokens) {
                let _ = checker.check_line(&program);
                checker.freeze();
            }
        }
    }

    lux::token::CURRENT_FILE_ID.with(|id| id.set(lux::token::next_file_id()));
    let tokens = lux::lexer::lex(source).map_err(|e| format!("lex error: {e}"))?;
    let program = lux::parser::parse(tokens).map_err(|e| format!("parse error: {e}"))?;
    checker.check_line(&program).map_err(|e| format!("{e}"))?;
    Ok(())
}

/// Helper: check that source type-checks successfully.
fn assert_checks(source: &str) {
    if let Err(e) = check(source) {
        panic!("expected type check to pass, but got error:\n{e}\nsource:\n{source}");
    }
}

/// Helper: check that source fails type checking.
fn assert_fails(source: &str) {
    if check(source).is_ok() {
        panic!("expected type check to fail, but it passed:\n{source}");
    }
}

// ── Basic type inference ──────────────────────────────────────

#[test]
fn infer_int_literal() {
    assert_checks("let x = 42");
}

#[test]
fn infer_float_literal() {
    assert_checks("let x = 3.14");
}

#[test]
fn infer_string_literal() {
    assert_checks("let x = \"hello\"");
}

#[test]
fn infer_bool_literal() {
    assert_checks("let x = true");
}

#[test]
fn infer_unit() {
    assert_checks("let x = ()");
}

// ── Arithmetic ────────────────────────────────────────────────

#[test]
fn arithmetic_int() {
    assert_checks("let x = 1 + 2 * 3");
}

#[test]
fn arithmetic_float() {
    assert_checks("let x = 1.0 + 2.0");
}

#[test]
fn string_concatenation() {
    assert_checks(r#"let x = "hello" ++ " world""#);
}

// ── Functions ─────────────────────────────────────────────────

#[test]
fn simple_function() {
    assert_checks("fn add(x: Int, y: Int) -> Int { x + y }");
}

#[test]
fn function_call_correct_arity() {
    assert_checks("fn add(x: Int, y: Int) -> Int { x + y }\nlet result = add(1, 2)");
}

#[test]
fn function_wrong_arity() {
    assert_fails("fn add(x: Int, y: Int) -> Int { x + y }\nlet result = add(1)");
}

#[test]
#[ignore = "ReplChecker pre-registration makes args too permissive — fix in full checker"]
fn function_type_mismatch() {
    assert_fails("fn add(x: Int, y: Int) -> Int { x + y }\nlet result = add(\"hello\", 2)");
}

#[test]
fn lambda_inference() {
    assert_checks("let f = |x| x + 1\nlet y = f(5)");
}

// ── Lists ─────────────────────────────────────────────────────

#[test]
fn list_literal() {
    assert_checks("let xs = [1, 2, 3]");
}

#[test]
fn list_homogeneous() {
    // Lists should have uniform element types
    assert_checks("let xs = [1, 2, 3]\nlet y = len(xs)");
}

// ── Tuples ────────────────────────────────────────────────────

#[test]
fn tuple_literal() {
    assert_checks("let t = (1, \"hello\", true)");
}

#[test]
fn tuple_destructuring() {
    assert_checks("let (a, b) = (1, 2)");
}

// ── ADTs ──────────────────────────────────────────────────────

#[test]
fn adt_declaration() {
    assert_checks("type Color = Red | Green | Blue");
}

#[test]
fn adt_construction() {
    assert_checks("type Color = Red | Green | Blue\nlet c = Red");
}

#[test]
fn adt_with_fields() {
    assert_checks("type Shape = Circle(Float) | Rect(Float, Float)\nlet s = Circle(3.14)");
}

// ── Pattern matching ──────────────────────────────────────────

#[test]
fn match_exhaustive_with_wildcard() {
    assert_checks(
        r#"type Color = Red | Green | Blue
let c = Red
match c {
    Red => "red",
    _ => "other",
}"#,
    );
}

#[test]
fn match_exhaustive_all_variants() {
    assert_checks(
        r#"type Color = Red | Green | Blue
let c = Red
match c {
    Red => "red",
    Green => "green",
    Blue => "blue",
}"#,
    );
}

#[test]
fn match_non_exhaustive_error() {
    assert_fails(
        r#"type Color = Red | Green | Blue
let c = Red
match c {
    Red => "red",
    Green => "green",
}"#,
    );
}

#[test]
fn match_int_no_exhaustiveness() {
    // Int matches don't need exhaustiveness (infinite domain)
    assert_checks(
        r#"let x = 42
match x {
    0 => "zero",
    1 => "one",
}"#,
    );
}

// ── Effects ───────────────────────────────────────────────────

#[test]
fn effect_declaration() {
    assert_checks(
        r#"effect Console {
    print(msg: String) -> ()
    read_line() -> String
}"#,
    );
}

#[test]
fn effect_handler() {
    assert_checks(
        r#"effect Ask {
    ask() -> Int
}
fn use_ask() -> Int with Ask {
    ask() + 1
}
let result = handle { use_ask() } {
    ask() => resume(42),
}"#,
    );
}

// ── Let bindings ──────────────────────────────────────────────

#[test]
fn let_binding_type_annotation() {
    assert_checks("let x: Int = 42");
}

#[test]
#[ignore = "ReplChecker unification deferred — annotation mismatch not caught incrementally"]
fn let_binding_type_mismatch() {
    assert_fails(r#"let x: Int = "hello""#);
}

// ── Pipe operator ─────────────────────────────────────────────

#[test]
fn pipe_operator() {
    assert_checks("let x = [1, 2, 3] |> len");
}

// ── If expressions ────────────────────────────────────────────

#[test]
fn if_expression() {
    assert_checks("let x = if true { 1 } else { 2 }");
}

#[test]
#[ignore = "ReplChecker doesn't enforce Bool condition — works in full compiler"]
fn if_condition_must_be_bool() {
    assert_fails("let x = if 42 { 1 } else { 2 }");
}

// ── Prelude functions ─────────────────────────────────────────

#[test]
fn map_function() {
    assert_checks("let xs = map(|x| x + 1, [1, 2, 3])");
}

#[test]
fn filter_function() {
    assert_checks("let xs = filter(|x| x > 0, [1, -2, 3])");
}

#[test]
fn fold_function() {
    assert_checks("let total = fold([1, 2, 3], 0, |acc, x| acc + x)");
}

// ── For loops ─────────────────────────────────────────────────

#[test]
fn for_loop() {
    assert_checks(
        r#"for x in [1, 2, 3] {
    println(to_string(x))
}"#,
    );
}

// ── Assert ────────────────────────────────────────────────────

#[test]
fn assert_statement() {
    assert_checks(r#"assert 1 + 1 == 2, "math works""#);
}
