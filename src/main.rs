#![allow(clippy::result_large_err)]

use std::env;
use std::fs;
use std::path::Path;
use std::process;
use std::sync::Arc;

fn main() {
    let args: Vec<String> = env::args().collect();

    // Flags: --teach is the default (Lux teaches by design)
    // Use --quiet to suppress teaching output.
    let quiet_mode = args.iter().any(|a| a == "--quiet");
    let no_check = args.iter().any(|a| a == "--no-check");
    let teach_mode = !quiet_mode;
    let file_args: Vec<&str> = args
        .iter()
        .skip(1)
        .filter(|a| !a.starts_with("--"))
        .map(|s| s.as_str())
        .collect();

    match file_args.as_slice() {
        [] | ["repl"] => {
            // Try self-hosted effect-pipeline REPL first
            let repl_path = find_std_file("repl.lux");
            if let Some(path) = repl_path {
                let source = read_file(&path);
                let result = run_source(&source, &path, false, true); // quiet + no-check
                if let Err(e) = result {
                    eprintln!("REPL error: {}", e);
                    process::exit(1);
                }
            } else {
                // Fallback: old Rust REPL
                println!("Lux 0.1.0 — A language of light\n");
                if let Err(e) = lux::repl::run() {
                    eprintln!("REPL error: {e}");
                    process::exit(1);
                }
            }
        }
        ["test", path] => {
            // `lux test <file>` — run a test file (auto-imports std/test)
            let source = read_file(path);
            // Prepend test import if not already present
            let source = if source.contains("import test") {
                source
            } else {
                format!("import test\n{source}")
            };
            let result = run_source(&source, path, teach_mode, no_check);
            if let Err(e) = result {
                eprintln!(
                    "{}",
                    lux::error::format_error_with_source(&e, &source, Some(path))
                );
                process::exit(1);
            }
        }
        ["check", path] => {
            // `lux check <file>` — type-check only, no execution
            let source = read_file(path);
            match check_source(&source, path) {
                Ok(()) => {
                    eprintln!("✓ {path}: type check passed");
                }
                Err(e) => {
                    eprintln!(
                        "{}",
                        lux::error::format_error_with_source(&e, &source, Some(path))
                    );
                    process::exit(1);
                }
            }
        }
        ["why", path] => {
            // `lux why <file>` — run through Why Engine (self-hosted pipeline)
            run_pipeline_mode(path, "why");
        }
        ["doc", path] => {
            // `lux doc <file>` — extract documentation (self-hosted pipeline)
            run_pipeline_mode(path, "doc");
        }
        [path] => {
            // Single argument — run file
            let source = read_file(path);
            let result = run_source(&source, path, teach_mode, no_check);
            if let Err(e) = result {
                eprintln!(
                    "{}",
                    lux::error::format_error_with_source(&e, &source, Some(path))
                );
                process::exit(1);
            }
        }
        _ => {
            eprintln!("Usage: lux [--quiet] [file.lux | test | check | why | doc | repl]");
            process::exit(1);
        }
    }
}

fn read_file(path: &str) -> String {
    match fs::read_to_string(path) {
        Ok(s) => s,
        Err(e) => {
            eprintln!("error: could not read '{path}': {e}");
            process::exit(1);
        }
    }
}

fn run_source(
    source: &str,
    file_path: &str,
    teach: bool,
    no_check: bool,
) -> Result<(), lux::error::LuxError> {
    let mut checker = lux::checker::ReplChecker::new();

    // Load and check prelude.
    let prelude = lux::load_prelude();
    let mut prelude_program = None;
    if !prelude.is_empty() {
        lux::token::CURRENT_FILE_ID.with(|id| id.set(lux::token::next_file_id()));
        let tokens = lux::lexer::lex(&prelude)?;
        let program = lux::parser::parse(tokens)?;
        let _ = checker.check_line(&program);
        checker.freeze();
        prelude_program = Some(program);
    }

    lux::token::CURRENT_FILE_ID.with(|id| id.set(lux::token::next_file_id()));
    let tokens = lux::lexer::lex(source)?;
    let program = lux::parser::parse(tokens)?;

    // Resolve imports before checking/compiling.
    let (base_dir, std_dir) = resolve_dirs(file_path);
    let (program, import_count) = lux::loader::resolve_imports(&program, &base_dir, &std_dir)?;

    if !no_check {
        checker.set_import_count(import_count);
        checker.check_line(&program)?;
        for (msg, span) in checker.take_warnings() {
            eprintln!(
                "warning: {msg}\n  --> {file_path}:{}:{}",
                span.line, span.column
            );
        }
        if teach {
            let hints = checker.take_hints();
            if !hints.is_empty() {
                eprintln!("=== lux teach ===\n");
                for hint in &hints {
                    eprint!("{}", lux::error::format_hint(hint, Some(file_path)));
                }
                eprintln!("{}\n", lux::error::format_hint_summary(&hints));
            }
        }
    }

    // Compile: prepend prelude items to the user program.
    let mut combined = lux::ast::Program { items: Vec::new() };
    if let Some(prelude) = prelude_program {
        combined.items.extend(prelude.items);
    }
    combined.items.extend(program.items);

    let effect_routing = checker.take_effect_routing();
    let proto = lux::compiler::compile(&combined, effect_routing)?;
    let mut vm = lux::vm::vm::Vm::new();
    let result = vm.run(Arc::new(proto)).map_err(|e| {
        lux::error::LuxError::Runtime(lux::error::RuntimeError {
            kind: lux::error::RuntimeErrorKind::TypeError(e.message),
            span: lux::token::Span {
                file_id: 0,
                line: e.line as usize,
                column: 0,
                start: 0,
                end: 0,
            },
        })
    })?;

    // Don't print the final value — file execution uses println for output.
    let _ = result;
    Ok(())
}

/// Type-check a source file without executing it.
fn check_source(source: &str, file_path: &str) -> Result<(), lux::error::LuxError> {
    let mut checker = lux::checker::ReplChecker::new();

    let prelude = lux::load_prelude();
    if !prelude.is_empty() {
        lux::token::CURRENT_FILE_ID.with(|id| id.set(lux::token::next_file_id()));
        let tokens = lux::lexer::lex(&prelude)?;
        let program = lux::parser::parse(tokens)?;
        let _ = checker.check_line(&program);
        checker.freeze();
    }

    lux::token::CURRENT_FILE_ID.with(|id| id.set(lux::token::next_file_id()));
    let tokens = lux::lexer::lex(source)?;
    let program = lux::parser::parse(tokens)?;

    let (base_dir, std_dir) = resolve_dirs(file_path);
    let (program, import_count) = lux::loader::resolve_imports(&program, &base_dir, &std_dir)?;

    checker.set_import_count(import_count);
    checker.check_line(&program)?;
    Ok(())
}

/// Derive the base directory (for relative imports) and std directory from the source file path.
fn resolve_dirs(file_path: &str) -> (std::path::PathBuf, std::path::PathBuf) {
    let path = Path::new(file_path);
    let base_dir = path.parent().unwrap_or(Path::new(".")).to_path_buf();

    // std dir: try relative to executable, then cwd
    let std_dir = std::env::current_exe()
        .ok()
        .and_then(|p| p.parent().map(|d| d.join("../std")))
        .filter(|d| d.exists())
        .unwrap_or_else(|| std::path::PathBuf::from("std"));

    (base_dir, std_dir)
}

/// Find a file in the std directory.
fn find_std_file(name: &str) -> Option<String> {
    // Try relative to executable first
    if let Ok(exe) = std::env::current_exe()
        && let Some(dir) = exe.parent()
    {
        let path = dir.join("../std").join(name);
        if path.exists() {
            return Some(path.to_string_lossy().to_string());
        }
    }
    // Try relative to CWD
    let path = Path::new("std").join(name);
    if path.exists() {
        return Some(path.to_string_lossy().to_string());
    }
    None
}

/// Run a file through the self-hosted effect pipeline with a specific handler.
/// mode: "why" → compile_explaining, "doc" → compile_documenting
fn run_pipeline_mode(file_path: &str, mode: &str) {
    let source = read_file(file_path);
    // Escape the source for embedding in a Lux string literal
    let escaped = source
        .replace('\\', "\\\\")
        .replace('"', "\\\"")
        .replace('\n', "\\n");

    let handler_fn = match mode {
        "why" => "compile_explaining",
        "doc" => "compile_documenting",
        _ => "compile_standard",
    };

    let wrapper = format!(
        "import compiler/pipeline\n\
         let source = \"{escaped}\"\n\
         let chunk = {}(source)\n\
         let program = load_chunk(chunk)\n\
         program()\n",
        handler_fn
    );

    let result = run_source(&wrapper, file_path, false, true); // quiet + no-check
    if let Err(e) = result {
        eprintln!("{}", e);
        process::exit(1);
    }
}
