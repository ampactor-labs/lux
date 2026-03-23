/// Internal type representation for the Lux type checker.
///
/// These are the types the checker works with — distinct from `ast::TypeExpr`
/// which represents what the programmer wrote.
use std::collections::{BTreeSet, HashMap};
use std::fmt;

/// A unique identifier for type variables during inference.
#[derive(Debug, Clone, Copy, PartialEq, Eq, Hash)]
pub struct TypeVar(pub u32);

/// The internal representation of Lux types.
#[derive(Debug, Clone, PartialEq)]
pub enum Type {
    /// Primitive types
    Int,
    Float,
    String,
    Bool,
    Unit,
    /// The bottom type — `Never` (return type of `fail`)
    Never,

    /// A type variable (for inference)
    Var(TypeVar),

    /// Function type with effect annotation
    Function {
        params: Vec<Type>,
        return_type: Box<Type>,
        effects: EffectRow,
    },

    /// An algebraic data type (after resolution)
    Adt {
        name: String,
        type_args: Vec<Type>,
    },

    /// List type
    List(Box<Type>),

    /// Tuple type
    Tuple(Vec<Type>),

    /// Structural record type with optional row variable.
    ///
    /// `{ name: String, age: Int }` — closed record
    /// `{ name: String, ..r }` — open record (row polymorphic): accepts any
    /// record with at least a `name: String` field.
    ///
    /// Fields are stored sorted by name (BTreeMap order) so that two records
    /// with the same fields in different order are the same type.
    Record {
        fields: Vec<(String, Type)>, // sorted by field name
        rest: Option<TypeVar>,       // row variable; None = closed record
    },

    /// An error placeholder (allows type checking to continue after errors)
    Error,
}

impl Type {
    /// Check if this type is a concrete (non-variable, non-error) type.
    pub fn is_concrete(&self) -> bool {
        match self {
            Type::Var(_) | Type::Error => false,
            Type::Function {
                params,
                return_type,
                ..
            } => params.iter().all(|p| p.is_concrete()) && return_type.is_concrete(),
            Type::List(inner) => inner.is_concrete(),
            Type::Tuple(elems) => elems.iter().all(|e| e.is_concrete()),
            Type::Adt { type_args, .. } => type_args.iter().all(|a| a.is_concrete()),
            Type::Record { fields, rest } => {
                rest.is_none() && fields.iter().all(|(_, t)| t.is_concrete())
            }
            _ => true,
        }
    }

    /// Substitute type variables using a mapping.
    pub fn substitute(&self, subst: &HashMap<TypeVar, Type>) -> Type {
        match self {
            Type::Var(v) => subst.get(v).cloned().unwrap_or_else(|| self.clone()),
            Type::Function {
                params,
                return_type,
                effects,
            } => Type::Function {
                params: params.iter().map(|p| p.substitute(subst)).collect(),
                return_type: Box::new(return_type.substitute(subst)),
                effects: effects.clone(),
            },
            Type::List(inner) => Type::List(Box::new(inner.substitute(subst))),
            Type::Tuple(elems) => Type::Tuple(elems.iter().map(|e| e.substitute(subst)).collect()),
            Type::Adt { name, type_args } => Type::Adt {
                name: name.clone(),
                type_args: type_args.iter().map(|a| a.substitute(subst)).collect(),
            },
            Type::Record { fields, rest } => Type::Record {
                fields: fields
                    .iter()
                    .map(|(n, t)| (n.clone(), t.substitute(subst)))
                    .collect(),
                rest: rest.and_then(|v| {
                    // If the row variable is mapped to another type var, use that; otherwise keep
                    match subst.get(&v) {
                        Some(Type::Var(new_v)) => Some(*new_v),
                        _ => Some(v),
                    }
                }),
            },
            _ => self.clone(),
        }
    }
}

impl fmt::Display for Type {
    fn fmt(&self, f: &mut fmt::Formatter<'_>) -> fmt::Result {
        match self {
            Type::Int => write!(f, "Int"),
            Type::Float => write!(f, "Float"),
            Type::String => write!(f, "String"),
            Type::Bool => write!(f, "Bool"),
            Type::Unit => write!(f, "()"),
            Type::Never => write!(f, "Never"),
            Type::Var(TypeVar(id)) => write!(f, "?{id}"),
            Type::Function {
                params,
                return_type,
                effects,
            } => {
                write!(f, "(")?;
                for (i, p) in params.iter().enumerate() {
                    if i > 0 {
                        write!(f, ", ")?;
                    }
                    write!(f, "{p}")?;
                }
                write!(f, ") -> {return_type}")?;
                if !effects.is_pure() {
                    write!(f, " with {effects}")?;
                }
                Ok(())
            }
            Type::Adt { name, type_args } => {
                write!(f, "{name}")?;
                if !type_args.is_empty() {
                    write!(f, "<")?;
                    for (i, a) in type_args.iter().enumerate() {
                        if i > 0 {
                            write!(f, ", ")?;
                        }
                        write!(f, "{a}")?;
                    }
                    write!(f, ">")?;
                }
                Ok(())
            }
            Type::List(inner) => write!(f, "List<{inner}>"),
            Type::Tuple(elems) => {
                write!(f, "(")?;
                for (i, e) in elems.iter().enumerate() {
                    if i > 0 {
                        write!(f, ", ")?;
                    }
                    write!(f, "{e}")?;
                }
                write!(f, ")")
            }
            Type::Record { fields, rest } => {
                write!(f, "{{ ")?;
                for (i, (name, ty)) in fields.iter().enumerate() {
                    if i > 0 {
                        write!(f, ", ")?;
                    }
                    write!(f, "{name}: {ty}")?;
                }
                if let Some(TypeVar(v)) = rest {
                    if !fields.is_empty() {
                        write!(f, ", ")?;
                    }
                    write!(f, "..r{v}")?;
                }
                write!(f, " }}")
            }
            Type::Error => write!(f, "<error>"),
        }
    }
}

// ── Effects ───────────────────────────────────────────────────

/// A unique identifier for effect row variables during inference.
#[derive(Debug, Clone, Copy, PartialEq, Eq, Hash)]
pub struct EffectVar(pub u32);

/// A named effect, possibly with type arguments.
#[derive(Debug, Clone, PartialEq, Eq, PartialOrd, Ord, Hash)]
pub struct EffectName {
    pub name: String,
    // Type args omitted for MVP — effects are identified by name only
}

impl EffectName {
    /// Ambient effects are inferred but hidden from display unless negated.
    /// Allocation is gravity — you annotate zero-G, not gravity.
    pub fn is_ambient(&self) -> bool {
        self.name == "Alloc"
    }
}

/// A row-polymorphic effect row.
///
/// `Closed(effects)` — exactly these effects, no more (like the old EffectSet).
/// `Open { known, var }` — at least `known` effects, plus whatever `var` resolves to.
#[derive(Debug, Clone, PartialEq)]
pub enum EffectRow {
    /// A closed set of effects — no polymorphism.
    Closed(BTreeSet<EffectName>),
    /// An open row: known effects + a row variable that may unify with more.
    Open {
        known: BTreeSet<EffectName>,
        var: EffectVar,
    },
}

impl EffectRow {
    /// The pure (empty, closed) effect row.
    pub fn pure() -> Self {
        EffectRow::Closed(BTreeSet::new())
    }

    /// A closed row with a single effect.
    pub fn single(name: impl Into<String>) -> Self {
        let mut effects = BTreeSet::new();
        effects.insert(EffectName { name: name.into() });
        EffectRow::Closed(effects)
    }

    /// True if this row is definitely pure (closed and empty).
    pub fn is_pure(&self) -> bool {
        matches!(self, EffectRow::Closed(s) if s.is_empty())
    }

    /// Union two rows. Result is Open if either input is Open.
    pub fn union(&self, other: &EffectRow) -> EffectRow {
        match (self, other) {
            (EffectRow::Closed(a), EffectRow::Closed(b)) => {
                EffectRow::Closed(a.union(b).cloned().collect())
            }
            (EffectRow::Open { known, var }, EffectRow::Closed(b))
            | (EffectRow::Closed(b), EffectRow::Open { known, var }) => EffectRow::Open {
                known: known.union(b).cloned().collect(),
                var: *var,
            },
            (EffectRow::Open { known: a, var }, EffectRow::Open { known: b, .. }) => {
                // Keep the first var — the second will be unified separately
                EffectRow::Open {
                    known: a.union(b).cloned().collect(),
                    var: *var,
                }
            }
        }
    }

    /// Check if a named effect is definitely in this row.
    pub fn contains(&self, name: &str) -> bool {
        match self {
            EffectRow::Closed(s) | EffectRow::Open { known: s, .. } => {
                s.iter().any(|e| e.name == name)
            }
        }
    }

    /// Insert an effect name into the known set.
    pub fn insert(&mut self, name: impl Into<String>) {
        let eff = EffectName { name: name.into() };
        match self {
            EffectRow::Closed(s) | EffectRow::Open { known: s, .. } => {
                s.insert(eff);
            }
        }
    }

    /// Get the known effects (for iteration/display).
    pub fn effects(&self) -> &BTreeSet<EffectName> {
        match self {
            EffectRow::Closed(s) | EffectRow::Open { known: s, .. } => s,
        }
    }

    /// Remove effects by name (used in handle — removes handled effects).
    pub fn without(&self, name: &str) -> EffectRow {
        match self {
            EffectRow::Closed(s) => {
                let filtered: BTreeSet<_> = s.iter().filter(|e| e.name != name).cloned().collect();
                EffectRow::Closed(filtered)
            }
            EffectRow::Open { known, var } => {
                let filtered: BTreeSet<_> =
                    known.iter().filter(|e| e.name != name).cloned().collect();
                EffectRow::Open {
                    known: filtered,
                    var: *var,
                }
            }
        }
    }
}

impl fmt::Display for EffectRow {
    fn fmt(&self, f: &mut fmt::Formatter<'_>) -> fmt::Result {
        match self {
            EffectRow::Closed(s) if s.is_empty() => write!(f, "Pure"),
            EffectRow::Closed(s) => {
                let names: Vec<&str> = s.iter().map(|e| e.name.as_str()).collect();
                write!(f, "{}", names.join(", "))
            }
            EffectRow::Open { known, var } => {
                if known.is_empty() {
                    write!(f, "E{}", var.0)
                } else {
                    let names: Vec<&str> = known.iter().map(|e| e.name.as_str()).collect();
                    write!(f, "{}, E{}", names.join(", "), var.0)
                }
            }
        }
    }
}

// ── Effect Declaration (resolved) ─────────────────────────────

/// A resolved effect declaration stored in the type environment.
#[derive(Debug, Clone)]
pub struct EffectDef {
    pub name: String,
    pub operations: Vec<EffectOpDef>,
}

/// A resolved effect operation.
#[derive(Debug, Clone)]
pub struct EffectOpDef {
    pub name: String,
    pub param_types: Vec<Type>,
    pub return_type: Type,
}

// ── ADT Definition (resolved) ─────────────────────────────────

/// A resolved algebraic data type definition.
#[derive(Debug, Clone)]
pub struct AdtDef {
    pub name: String,
    pub type_params: Vec<String>,
    pub variants: Vec<VariantDef>,
}

/// A resolved ADT variant.
///
/// Fields are stored as `(name, type)` pairs. For positional variants,
/// names are synthetic: `"_0"`, `"_1"`, etc. Named fields keep their
/// declared names. The positional order in the Vec is canonical —
/// runtime `Value::AdtVariant.fields` uses the same indices.
#[derive(Debug, Clone)]
pub struct VariantDef {
    pub name: String,
    pub fields: Vec<(String, Type)>,
}
