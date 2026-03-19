//! Built-in function registration for the Lux interpreter.
//!
//! Contains `register_builtins` and all `BuiltinFn` implementations.
//! These are pure registration code with no coupling to the eval loop.

use crate::error::{RuntimeError, RuntimeErrorKind};
use crate::interpreter::Value;
use crate::token::Span;

/// Register all built-in functions into the interpreter.
pub fn register_builtins(
    register: &mut impl FnMut(&str, fn(Vec<Value>) -> Result<Value, RuntimeError>),
) {
    register("print", |args| {
        if let Some(v) = args.first() {
            print!("{}", v.display_print());
        }
        Ok(Value::Unit)
    });
    register("println", |args| {
        if let Some(v) = args.first() {
            println!("{}", v.display_print());
        } else {
            println!();
        }
        Ok(Value::Unit)
    });
    register("len", |args| match args.first() {
        Some(Value::List(vs)) => Ok(Value::Int(vs.len() as i64)),
        Some(Value::String(s)) => Ok(Value::Int(s.len() as i64)),
        _ => Err(RuntimeError {
            kind: RuntimeErrorKind::TypeError("len expects a list or string".into()),
            span: Span::dummy(),
        }),
    });
    register("is_empty", |args| match args.first() {
        Some(Value::List(vs)) => Ok(Value::Bool(vs.is_empty())),
        Some(Value::String(s)) => Ok(Value::Bool(s.is_empty())),
        _ => Err(RuntimeError {
            kind: RuntimeErrorKind::TypeError("is_empty expects a list or string".into()),
            span: Span::dummy(),
        }),
    });
    register("push", |args| {
        if args.len() != 2 {
            return Err(RuntimeError {
                kind: RuntimeErrorKind::TypeError("push expects 2 arguments".into()),
                span: Span::dummy(),
            });
        }
        let mut args = args;
        let val = args.remove(1);
        match args.into_iter().next() {
            Some(Value::List(mut vs)) => {
                vs.push(val);
                Ok(Value::List(vs))
            }
            _ => Err(RuntimeError {
                kind: RuntimeErrorKind::TypeError("push expects a list as first argument".into()),
                span: Span::dummy(),
            }),
        }
    });
    register("to_string", |args| match args.first() {
        Some(v) => Ok(Value::String(v.display_print())),
        None => Ok(Value::String(String::new())),
    });
    register("parse_int", |args| match args.first() {
        Some(Value::String(s)) => match s.parse::<i64>() {
            Ok(n) => Ok(Value::Int(n)),
            Err(_) => Err(RuntimeError {
                kind: RuntimeErrorKind::TypeError(format!("cannot parse '{s}' as Int")),
                span: Span::dummy(),
            }),
        },
        _ => Err(RuntimeError {
            kind: RuntimeErrorKind::TypeError("parse_int expects a string".into()),
            span: Span::dummy(),
        }),
    });
    register("range", |args| match (args.first(), args.get(1)) {
        (Some(Value::Int(start)), Some(Value::Int(end))) => {
            let start = *start;
            let end = *end;
            let items = (start..end).map(Value::Int).collect();
            Ok(Value::List(items))
        }
        _ => Err(RuntimeError {
            kind: RuntimeErrorKind::TypeError(
                "range expects two Int arguments: range(start, end)".into(),
            ),
            span: Span::dummy(),
        }),
    });
    // String builtins
    register("split", |args| match (args.first(), args.get(1)) {
        (Some(Value::String(s)), Some(Value::String(sep))) => {
            let parts: Vec<Value> = s
                .split(sep.as_str())
                .map(|p| Value::String(p.to_string()))
                .collect();
            Ok(Value::List(parts))
        }
        _ => Err(RuntimeError {
            kind: RuntimeErrorKind::TypeError("split expects two strings".into()),
            span: Span::dummy(),
        }),
    });
    register("trim", |args| match args.first() {
        Some(Value::String(s)) => Ok(Value::String(s.trim().to_string())),
        _ => Err(RuntimeError {
            kind: RuntimeErrorKind::TypeError("trim expects a string".into()),
            span: Span::dummy(),
        }),
    });
    register("contains", |args| match (args.first(), args.get(1)) {
        (Some(Value::String(s)), Some(Value::String(sub))) => {
            Ok(Value::Bool(s.contains(sub.as_str())))
        }
        (Some(Value::List(items)), Some(val)) => Ok(Value::Bool(items.contains(val))),
        _ => Err(RuntimeError {
            kind: RuntimeErrorKind::TypeError(
                "contains expects (String, String) or (List, value)".into(),
            ),
            span: Span::dummy(),
        }),
    });
    register("starts_with", |args| match (args.first(), args.get(1)) {
        (Some(Value::String(s)), Some(Value::String(prefix))) => {
            Ok(Value::Bool(s.starts_with(prefix.as_str())))
        }
        _ => Err(RuntimeError {
            kind: RuntimeErrorKind::TypeError("starts_with expects two strings".into()),
            span: Span::dummy(),
        }),
    });
    register("replace", |args| {
        match (args.first(), args.get(1), args.get(2)) {
            (Some(Value::String(s)), Some(Value::String(from)), Some(Value::String(to))) => {
                Ok(Value::String(s.replace(from.as_str(), to.as_str())))
            }
            _ => Err(RuntimeError {
                kind: RuntimeErrorKind::TypeError("replace expects three strings".into()),
                span: Span::dummy(),
            }),
        }
    });
    register("chars", |args| match args.first() {
        Some(Value::String(s)) => {
            let chars: Vec<Value> = s.chars().map(|c| Value::String(c.to_string())).collect();
            Ok(Value::List(chars))
        }
        _ => Err(RuntimeError {
            kind: RuntimeErrorKind::TypeError("chars expects a string".into()),
            span: Span::dummy(),
        }),
    });
    register("join", |args| match (args.first(), args.get(1)) {
        (Some(Value::List(items)), Some(Value::String(sep))) => {
            let strings: Vec<String> = items
                .iter()
                .map(|v| match v {
                    Value::String(s) => s.clone(),
                    other => other.display_print(),
                })
                .collect();
            Ok(Value::String(strings.join(sep.as_str())))
        }
        _ => Err(RuntimeError {
            kind: RuntimeErrorKind::TypeError("join expects a list and string".into()),
            span: Span::dummy(),
        }),
    });
    register("slice", |args| {
        match (args.first(), args.get(1), args.get(2)) {
            (Some(Value::List(items)), Some(Value::Int(start)), Some(Value::Int(end))) => {
                let len = items.len() as i64;
                let s = (*start).max(0).min(len) as usize;
                let e = (*end).max(0).min(len) as usize;
                let slice = items[s..e].to_vec();
                Ok(Value::List(slice))
            }
            _ => Err(RuntimeError {
                kind: RuntimeErrorKind::TypeError("slice expects (List, Int, Int)".into()),
                span: Span::dummy(),
            }),
        }
    });

    // Numeric builtins
    register("abs", |args| match args.first() {
        Some(Value::Int(n)) => Ok(Value::Int(n.abs())),
        Some(Value::Float(f)) => Ok(Value::Float(f.abs())),
        _ => Err(RuntimeError {
            kind: RuntimeErrorKind::TypeError("abs expects a number".into()),
            span: Span::dummy(),
        }),
    });
    register("floor", |args| match args.first() {
        Some(Value::Float(f)) => Ok(Value::Int(f.floor() as i64)),
        Some(Value::Int(n)) => Ok(Value::Int(*n)),
        _ => Err(RuntimeError {
            kind: RuntimeErrorKind::TypeError("floor expects a number".into()),
            span: Span::dummy(),
        }),
    });
    register("ceil", |args| match args.first() {
        Some(Value::Float(f)) => Ok(Value::Int(f.ceil() as i64)),
        Some(Value::Int(n)) => Ok(Value::Int(*n)),
        _ => Err(RuntimeError {
            kind: RuntimeErrorKind::TypeError("ceil expects a number".into()),
            span: Span::dummy(),
        }),
    });
    register("sqrt", |args| match args.first() {
        Some(Value::Float(f)) => Ok(Value::Float(f.sqrt())),
        Some(Value::Int(n)) => Ok(Value::Float((*n as f64).sqrt())),
        _ => Err(RuntimeError {
            kind: RuntimeErrorKind::TypeError("sqrt expects a number".into()),
            span: Span::dummy(),
        }),
    });
    register("exp", |args| match args.first() {
        Some(Value::Float(f)) => Ok(Value::Float(f.exp())),
        Some(Value::Int(n)) => Ok(Value::Float((*n as f64).exp())),
        _ => Err(RuntimeError {
            kind: RuntimeErrorKind::TypeError("exp expects a number".into()),
            span: Span::dummy(),
        }),
    });
    register("log", |args| match args.first() {
        Some(Value::Float(f)) => Ok(Value::Float(f.ln())),
        Some(Value::Int(n)) => Ok(Value::Float((*n as f64).ln())),
        _ => Err(RuntimeError {
            kind: RuntimeErrorKind::TypeError("log expects a number".into()),
            span: Span::dummy(),
        }),
    });
    register("pow", |args| match (args.first(), args.get(1)) {
        (Some(Value::Float(b)), Some(Value::Float(e))) => Ok(Value::Float(b.powf(*e))),
        (Some(Value::Float(b)), Some(Value::Int(e))) => Ok(Value::Float(b.powf(*e as f64))),
        (Some(Value::Int(b)), Some(Value::Float(e))) => Ok(Value::Float((*b as f64).powf(*e))),
        (Some(Value::Int(b)), Some(Value::Int(e))) => Ok(Value::Float((*b as f64).powf(*e as f64))),
        _ => Err(RuntimeError {
            kind: RuntimeErrorKind::TypeError("pow expects two numbers".into()),
            span: Span::dummy(),
        }),
    });
    register("to_float", |args| match args.first() {
        Some(Value::Int(n)) => Ok(Value::Float(*n as f64)),
        Some(Value::Float(f)) => Ok(Value::Float(*f)),
        _ => Err(RuntimeError {
            kind: RuntimeErrorKind::TypeError("to_float expects a number".into()),
            span: Span::dummy(),
        }),
    });

    // `next` is registered as a placeholder; the real logic lives in
    // `call_value` which can pattern-match on Value::Generator.
    register("next", |_args| {
        Err(RuntimeError {
            kind: RuntimeErrorKind::TypeError("next: argument is not a generator".into()),
            span: Span::dummy(),
        })
    });
    // `generate` is registered as a placeholder; the real logic lives in
    // `call_value` which can clone the interpreter and spawn a thread.
    register("generate", |_args| {
        Err(RuntimeError {
            kind: RuntimeErrorKind::TypeError("generate: argument must be a function".into()),
            span: Span::dummy(),
        })
    });

    register("__assert_fail", |args| {
        let msg = match args.first() {
            Some(Value::String(s)) => s.clone(),
            Some(v) => format!("{v}"),
            None => "assertion failed".to_string(),
        };
        Err(RuntimeError {
            kind: RuntimeErrorKind::AssertionFailed(msg),
            span: Span::dummy(),
        })
    });
}
