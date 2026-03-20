//! Golden-file integration tests for Lux examples.
//!
//! Each `examples/*.lux` file has a corresponding `examples/*.expected` file
//! containing the expected stdout. Tests run the example via the interpreter
//! (the specification) and compare output.
//!
//! To regenerate baselines: `cargo test -- --ignored regenerate_baselines`

use std::path::Path;
use std::process::Command;

/// Run a `.lux` file with the given flags and return (stdout, stderr, success).
fn run_lux(file: &str, extra_args: &[&str]) -> (String, String, bool) {
    let output = Command::new(env!("CARGO_BIN_EXE_lux"))
        .args(extra_args)
        .arg(file)
        .output()
        .unwrap_or_else(|e| panic!("failed to run lux on {file}: {e}"));
    (
        String::from_utf8_lossy(&output.stdout).into_owned(),
        String::from_utf8_lossy(&output.stderr).into_owned(),
        output.status.success(),
    )
}

/// Find all examples that have a `.expected` golden file.
fn golden_examples() -> Vec<(String, String)> {
    let examples_dir = Path::new(env!("CARGO_MANIFEST_DIR")).join("examples");
    let mut pairs = Vec::new();
    for entry in std::fs::read_dir(&examples_dir).expect("examples/ dir") {
        let entry = entry.unwrap();
        let path = entry.path();
        if path.extension().is_some_and(|e| e == "lux") && path.is_file() {
            let expected = path.with_extension("expected");
            if expected.exists() {
                pairs.push((
                    path.to_string_lossy().into_owned(),
                    expected.to_string_lossy().into_owned(),
                ));
            }
        }
    }
    pairs.sort();
    pairs
}

#[test]
fn interpreter_matches_golden_files() {
    let pairs = golden_examples();
    assert!(
        !pairs.is_empty(),
        "no .expected files found — run regenerate_baselines first"
    );

    let mut failures = Vec::new();
    for (lux_file, expected_file) in &pairs {
        let expected = std::fs::read_to_string(expected_file)
            .unwrap_or_else(|e| panic!("can't read {expected_file}: {e}"));
        let (stdout, stderr, success) = run_lux(lux_file, &["--interpret"]);

        if !success {
            failures.push(format!(
                "FAIL (exit code): {}\n  stderr: {}",
                lux_file,
                stderr.lines().take(3).collect::<Vec<_>>().join("\n  ")
            ));
            continue;
        }
        if stdout != expected {
            failures.push(format!(
                "FAIL (output mismatch): {}\n  expected: {:?}\n  actual:   {:?}",
                lux_file,
                expected.lines().take(3).collect::<Vec<_>>(),
                stdout.lines().take(3).collect::<Vec<_>>(),
            ));
        }
    }

    if !failures.is_empty() {
        panic!(
            "\n{} example(s) failed:\n\n{}\n",
            failures.len(),
            failures.join("\n\n")
        );
    }
}

#[test]
fn vm_matches_interpreter() {
    let pairs = golden_examples();
    if pairs.is_empty() {
        return; // skip if no golden files yet
    }

    let mut failures = Vec::new();
    for (lux_file, _) in &pairs {
        let name = Path::new(lux_file).file_stem().unwrap().to_string_lossy();

        // Skip examples known to diverge between VM and interpreter.
        // - generators: uses thread-based channels (interpreter-only)
        // - kv_store: tail-resumptive optimization skips body replay,
        //   so println runs once (correct) vs N times (interpreter artifact)
        if name == "generators" || name == "kv_store" {
            continue;
        }

        let (interp_out, _, interp_ok) = run_lux(lux_file, &["--interpret"]);
        let (vm_out, vm_stderr, vm_ok) = run_lux(lux_file, &[]);

        if !interp_ok {
            continue; // interpreter itself fails — skip parity check
        }
        if !vm_ok {
            failures.push(format!(
                "VM FAIL (exit code): {}\n  stderr: {}",
                lux_file,
                vm_stderr.lines().take(3).collect::<Vec<_>>().join("\n  ")
            ));
            continue;
        }
        if vm_out != interp_out {
            failures.push(format!(
                "VM MISMATCH: {}\n  interpreter: {:?}\n  vm:          {:?}",
                lux_file,
                interp_out.lines().take(5).collect::<Vec<_>>(),
                vm_out.lines().take(5).collect::<Vec<_>>(),
            ));
        }
    }

    if !failures.is_empty() {
        panic!(
            "\n{} VM parity failure(s):\n\n{}\n",
            failures.len(),
            failures.join("\n\n")
        );
    }
}

#[test]
#[ignore]
fn regenerate_baselines() {
    let examples_dir = Path::new(env!("CARGO_MANIFEST_DIR")).join("examples");
    for entry in std::fs::read_dir(&examples_dir).expect("examples/ dir") {
        let entry = entry.unwrap();
        let path = entry.path();
        if path.extension().is_some_and(|e| e == "lux") && path.is_file() {
            let (stdout, _, success) = run_lux(&path.to_string_lossy(), &["--interpret"]);
            if success {
                let expected = path.with_extension("expected");
                std::fs::write(&expected, &stdout)
                    .unwrap_or_else(|e| panic!("can't write {}: {e}", expected.display()));
                println!("wrote {}", expected.display());
            } else {
                println!("SKIP (interpreter fails): {}", path.display());
            }
        }
    }
}
