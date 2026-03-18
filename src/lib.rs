#![allow(clippy::result_large_err, clippy::collapsible_if)]

pub mod ast;
pub mod builtins;
pub mod checker;
pub mod compiler;
pub mod env;
pub mod error;
pub mod interpreter;
pub mod lexer;
pub mod loader;
pub mod parser;
pub mod patterns;
pub mod repl;
pub mod token;
pub mod types;
pub mod vm;

/// Load the standard library prelude source.
///
/// Searches for `std/prelude.lux` relative to the executable directory and the
/// current working directory. Returns an empty string (silent fail) if not found.
pub fn load_prelude() -> String {
    let exe_dir = std::env::current_exe()
        .ok()
        .and_then(|p| p.parent().map(|d| d.to_path_buf()));

    let candidates: Vec<std::path::PathBuf> = [
        exe_dir.as_ref().map(|d| d.join("../std/prelude.lux")),
        exe_dir.as_ref().map(|d| d.join("std/prelude.lux")),
        Some(std::path::PathBuf::from("std/prelude.lux")),
    ]
    .into_iter()
    .flatten()
    .collect();

    for candidate in &candidates {
        if let Ok(content) = std::fs::read_to_string(candidate) {
            return content;
        }
    }

    String::new()
}
