/// Interactive REPL for the Lux language.
///
/// Provides a read-eval-print loop with persistent interpreter and type-checker
/// state: bindings, function declarations, effect declarations, and ADT
/// definitions all survive across lines.
///
/// Features:
/// - Multi-line input: bracket depth tracking prompts `...> ` for continuations.
/// - `:type <expr>` — show the inferred type of an expression.
/// - `:effects <name>` — show the type (including effect annotation) of a binding.
/// - `:help` — list available commands.
/// - `:quit` / `:q` — exit.
use rustyline::DefaultEditor;

use crate::checker::ReplChecker;
use crate::error::LuxError;
use crate::interpreter::Interpreter;

/// Start the interactive REPL.
pub fn run() -> Result<(), LuxError> {
    let mut rl = DefaultEditor::new().map_err(|e| {
        LuxError::Runtime(crate::error::RuntimeError {
            kind: crate::error::RuntimeErrorKind::Internal(format!("readline init: {e}")),
            span: crate::token::Span::dummy(),
        })
    })?;

    let mut interpreter = Interpreter::new();
    let mut checker = ReplChecker::new();

    // Load prelude into REPL state so prelude functions are available.
    // Freeze the checker after prelude to keep user-code type-checking fast.
    let prelude_src = crate::load_prelude();
    if !prelude_src.is_empty() {
        if let Ok(tokens) = crate::lexer::lex(&prelude_src) {
            if let Ok(program) = crate::parser::parse(tokens) {
                let _ = checker.check_line(&program);
                checker.freeze();
                let _ = interpreter.eval_line(&program);
            }
        }
    }

    println!("Lux REPL — type :help for commands, :quit to exit\n");

    let mut pending = String::new();

    loop {
        let prompt = if pending.is_empty() { "lux> " } else { "...> " };

        let line = match rl.readline(prompt) {
            Ok(line) => line,
            Err(rustyline::error::ReadlineError::Eof) => break,
            Err(rustyline::error::ReadlineError::Interrupted) => {
                // Ctrl-C clears any pending multi-line input
                pending.clear();
                continue;
            }
            Err(e) => {
                return Err(LuxError::Runtime(crate::error::RuntimeError {
                    kind: crate::error::RuntimeErrorKind::Internal(format!("readline: {e}")),
                    span: crate::token::Span::dummy(),
                }));
            }
        };

        // Handle commands only when not in a multi-line continuation
        if pending.is_empty() {
            let trimmed = line.trim();

            if trimmed == ":quit" || trimmed == ":q" {
                break;
            }

            if trimmed == ":help" {
                print_help();
                continue;
            }

            if let Some(rest) = trimmed.strip_prefix(":type ") {
                let _ = rl.add_history_entry(trimmed);
                handle_type_cmd(rest.trim(), &mut checker);
                continue;
            }

            if let Some(rest) = trimmed.strip_prefix(":effects ") {
                let _ = rl.add_history_entry(trimmed);
                handle_effects_cmd(rest.trim(), &checker);
                continue;
            }
        }

        // Accumulate multi-line input
        if pending.is_empty() {
            pending = line.clone();
        } else {
            pending.push('\n');
            pending.push_str(&line);
        }

        // Check bracket depth to decide whether to keep accumulating
        if bracket_depth(&pending) > 0 {
            continue;
        }

        let source = std::mem::take(&mut pending);
        let _ = rl.add_history_entry(source.trim());

        match eval_line(&mut interpreter, &mut checker, &source) {
            Ok(Some(value)) => println!("{value}"),
            Ok(None) => {}
            Err(e) => eprintln!("error: {e}"),
        }
    }

    Ok(())
}

fn print_help() {
    println!("Commands:");
    println!("  :type <expr>     — show the inferred type of an expression");
    println!("  :effects <name>  — show the type of a binding (includes effects)");
    println!("  :help            — show this help");
    println!("  :quit / :q       — exit the REPL");
}

fn handle_type_cmd(expr_src: &str, checker: &mut ReplChecker) {
    if expr_src.is_empty() {
        eprintln!("usage: :type <expr>");
        return;
    }
    let result = (|| -> Result<String, LuxError> {
        let tokens = crate::lexer::lex(expr_src)?;
        let program = crate::parser::parse(tokens)?;
        // Expect exactly one expression item
        if let Some(crate::ast::Item::Expr(expr)) = program.items.first() {
            checker.type_of_expr(expr)
        } else {
            Ok("<not an expression>".to_string())
        }
    })();
    match result {
        Ok(ty) => println!("{ty}"),
        Err(e) => eprintln!("error: {e}"),
    }
}

fn handle_effects_cmd(name: &str, checker: &ReplChecker) {
    if name.is_empty() {
        eprintln!("usage: :effects <name>");
        return;
    }
    match checker.effects_of(name) {
        Some(ty) => println!("{ty}"),
        None => eprintln!("error: '{name}' is not bound"),
    }
}

fn eval_line(
    interpreter: &mut Interpreter,
    checker: &mut ReplChecker,
    source: &str,
) -> Result<Option<crate::interpreter::Value>, LuxError> {
    let tokens = crate::lexer::lex(source)?;
    let program = crate::parser::parse(tokens)?;
    // Best-effort type check — don't block eval on type errors in the REPL
    let _ = checker.check_line(&program);
    interpreter.eval_line(&program)
}

/// Count net open brackets/braces/parens to detect incomplete multi-line input.
fn bracket_depth(s: &str) -> i32 {
    let mut depth = 0i32;
    let mut in_string = false;
    let mut chars = s.chars().peekable();
    while let Some(ch) = chars.next() {
        match ch {
            '"' if !in_string => in_string = true,
            '"' if in_string => in_string = false,
            '\\' if in_string => {
                chars.next(); // skip escaped char
            }
            '{' | '(' | '[' if !in_string => depth += 1,
            '}' | ')' | ']' if !in_string => depth -= 1,
            _ => {}
        }
    }
    depth
}
