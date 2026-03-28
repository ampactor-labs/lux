#![allow(clippy::result_large_err)]

use std::env;
use std::fs;
use std::path::Path;
use std::process;
use std::sync::Arc;

fn main() {
    let args: Vec<String> = env::args().collect();

    // --quiet suppresses teaching output. Teaching is on by default.
    let quiet_mode = args.iter().any(|a| a == "--quiet");
    let teach_mode = !quiet_mode;
    let file_args: Vec<&str> = args
        .iter()
        .skip(1)
        .filter(|a| !a.starts_with("--"))
        .map(|s| s.as_str())
        .collect();

    match file_args.as_slice() {
        [] | ["repl"] => {
            // Self-hosted effect-pipeline REPL
            let repl_path = find_std_file("repl.lux");
            if let Some(path) = repl_path {
                let source = read_file(&path);
                let result = run_source(&source, &path, false); // quiet
                if let Err(e) = result {
                    eprintln!("REPL error: {}", e);
                    process::exit(1);
                }
            } else {
                eprintln!("error: std/repl.lux not found");
                process::exit(1);
            }
        }
        ["test", path] => {
            // `lux test <file>` — run a test file (auto-imports std/test)
            let source = read_file(path);
            let source = if source.contains("import test") {
                source
            } else {
                format!("import test\n{source}")
            };
            let result = run_source(&source, path, teach_mode);
            if let Err(e) = result {
                eprintln!(
                    "{}",
                    lux::error::format_error_with_source(&e, &source, Some(path))
                );
                process::exit(1);
            }
        }
        ["check", path] => {
            // `lux check <file>` — self-hosted type-check via pipeline
            run_pipeline_mode(path, "check");
        }
        ["why", path] => {
            // `lux why <file>` — run through Why Engine (self-hosted pipeline)
            run_pipeline_mode(path, "why");
        }
        ["doc", path] => {
            // `lux doc <file>` — extract documentation (self-hosted pipeline)
            run_pipeline_mode(path, "doc");
        }
        ["illuminate", path] => {
            // `lux illuminate <file>` — the gradient as refraction
            run_pipeline_mode(path, "illuminate");
        }
        ["lower", path] => {
            // `lux lower <file>` — show LowIR output
            run_pipeline_mode(path, "lower");
        }
        [path] => {
            // Single argument — run file
            let source = read_file(path);
            let result = run_source(&source, path, teach_mode);
            if let Err(e) = result {
                eprintln!(
                    "{}",
                    lux::error::format_error_with_source(&e, &source, Some(path))
                );
                process::exit(1);
            }
        }
        _ => {
            eprintln!(
                "Usage: lux [--quiet] [file.lux | test | check | why | doc | illuminate | repl]"
            );
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

fn run_source(source: &str, file_path: &str, _teach: bool) -> Result<(), lux::error::LuxError> {
    // Load and compile prelude.
    let prelude = lux::load_prelude();
    let mut prelude_program = None;
    if !prelude.is_empty() {
        lux::token::CURRENT_FILE_ID.with(|id| id.set(lux::token::next_file_id()));
        let tokens = lux::lexer::lex(&prelude)?;
        let program = lux::parser::parse(tokens)?;
        prelude_program = Some(program);
    }

    lux::token::CURRENT_FILE_ID.with(|id| id.set(lux::token::next_file_id()));
    let tokens = lux::lexer::lex(source)?;
    let program = lux::parser::parse(tokens)?;

    // Resolve imports.
    let (base_dir, std_dir) = resolve_dirs(file_path);
    let (program, _import_count) = lux::loader::resolve_imports(&program, &base_dir, &std_dir)?;

    // Compile: prepend prelude items to the user program.
    let mut combined = lux::ast::Program { items: Vec::new() };
    if let Some(prelude) = prelude_program {
        combined.items.extend(prelude.items);
    }
    combined.items.extend(program.items);

    let proto = lux::compiler::compile(&combined, Default::default())?;
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

    let _ = result;
    Ok(())
}

/// Derive the base directory (for relative imports) and std directory from the source file path.
fn resolve_dirs(file_path: &str) -> (std::path::PathBuf, std::path::PathBuf) {
    let path = Path::new(file_path);
    let base_dir = path.parent().unwrap_or(Path::new(".")).to_path_buf();

    let std_dir = std::env::current_exe()
        .ok()
        .and_then(|p| p.parent().map(|d| d.join("../std")))
        .filter(|d| d.exists())
        .unwrap_or_else(|| std::path::PathBuf::from("std"));

    (base_dir, std_dir)
}

/// Find a file in the std directory.
fn find_std_file(name: &str) -> Option<String> {
    if let Ok(exe) = std::env::current_exe()
        && let Some(dir) = exe.parent()
    {
        let path = dir.join("../std").join(name);
        if path.exists() {
            return Some(path.to_string_lossy().to_string());
        }
    }
    let path = Path::new("std").join(name);
    if path.exists() {
        return Some(path.to_string_lossy().to_string());
    }
    None
}

/// Run a file through the self-hosted effect pipeline with a specific handler.
fn run_pipeline_mode(file_path: &str, mode: &str) {
    let handler_fn = match mode {
        "why" => "compile_explaining",
        "doc" => "compile_documenting",
        "illuminate" => "compile_illuminate",
        "check" => "compile_checking",
        "lower" => "compile_lowering",
        _ => "compile_standard",
    };

    let wrapper = format!(
        "import compiler/pipeline\n\
         let source = read_file(\"{file_path}\")\n\
         let chunk = {}(source)\n\
         let program = load_chunk(chunk)\n\
         program()\n",
        handler_fn
    );

    let result = run_source(&wrapper, file_path, false);
    if let Err(e) = result {
        eprintln!("{}", e);
        process::exit(1);
    }
}
