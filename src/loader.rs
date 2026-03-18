//! Module loader: resolves `import` declarations into a combined program.
//!
//! Resolution order per import:
//! 1. Relative path (to the importing file's directory)
//! 2. `std/` directory (relative to executable or project root)
//! 3. Error: module not found

use std::collections::HashSet;
use std::path::{Path, PathBuf};

use crate::ast::{Item, Program};
use crate::error::{LuxError, RuntimeError, RuntimeErrorKind};
use crate::token::Span;

/// Resolve all `import` declarations in a program, returning a combined
/// program with imported items prepended (dependency order) and `Import`
/// nodes removed.
pub fn resolve_imports(
    program: &Program,
    base_dir: &Path,
    std_dir: &Path,
) -> Result<Program, LuxError> {
    let mut visited = HashSet::new();
    let mut imported_items = Vec::new();

    for item in &program.items {
        if let Item::Import(decl) = item {
            let file_path = resolve_path(&decl.path, base_dir, std_dir, &decl.span)?;
            load_module(&file_path, std_dir, &mut visited, &mut imported_items)?;
        }
    }

    // Build combined: imported items first, then original items minus Import nodes.
    let own_items: Vec<Item> = program
        .items
        .iter()
        .filter(|item| !matches!(item, Item::Import(_)))
        .cloned()
        .collect();

    let mut combined = imported_items;
    combined.extend(own_items);
    Ok(Program { items: combined })
}

/// Recursively load a module file and all its transitive imports.
fn load_module(
    file_path: &Path,
    std_dir: &Path,
    visited: &mut HashSet<PathBuf>,
    out: &mut Vec<Item>,
) -> Result<(), LuxError> {
    let canonical = file_path
        .canonicalize()
        .unwrap_or_else(|_| file_path.to_path_buf());
    if !visited.insert(canonical.clone()) {
        return Ok(()); // already loaded — cycle prevention
    }

    let source = std::fs::read_to_string(file_path)
        .map_err(|e| module_error(format!("could not read '{}': {e}", file_path.display())))?;

    let tokens = crate::lexer::lex(&source)?;
    let program = crate::parser::parse(tokens)?;

    let module_dir = file_path.parent().unwrap_or(Path::new("."));

    // Recursively resolve this module's imports first.
    for item in &program.items {
        if let Item::Import(decl) = item {
            let dep_path = resolve_path(&decl.path, module_dir, std_dir, &decl.span)?;
            load_module(&dep_path, std_dir, visited, out)?;
        }
    }

    // Add this module's non-import items.
    for item in program.items {
        if !matches!(&item, Item::Import(_)) {
            out.push(item);
        }
    }
    Ok(())
}

/// Resolve an import path to a filesystem path.
fn resolve_path(
    path: &[String],
    base_dir: &Path,
    std_dir: &Path,
    _span: &Span,
) -> Result<PathBuf, LuxError> {
    let (is_relative, segments) = if path.first().map(|s| s.as_str()) == Some(".") {
        (true, &path[1..])
    } else {
        (false, path)
    };

    let relative: PathBuf = segments.iter().collect();
    let with_ext = relative.with_extension("lux");

    if is_relative {
        let candidate = base_dir.join(&with_ext);
        if candidate.exists() {
            return Ok(candidate);
        }
    } else {
        // Try relative to current file first, then std dir.
        let candidate = base_dir.join(&with_ext);
        if candidate.exists() {
            return Ok(candidate);
        }
        let candidate = std_dir.join(&with_ext);
        if candidate.exists() {
            return Ok(candidate);
        }
    }

    Err(module_error(format!(
        "module not found: '{}' (searched {} and {})",
        path.join("/"),
        base_dir.display(),
        std_dir.display(),
    )))
}

fn module_error(msg: String) -> LuxError {
    LuxError::Runtime(RuntimeError {
        kind: RuntimeErrorKind::TypeError(msg),
        span: Span::dummy(),
    })
}
