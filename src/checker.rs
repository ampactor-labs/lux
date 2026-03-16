//! Type checker with effect inference for Lux.
//!
//! Validates types using simplified Hindley-Milner inference and tracks
//! which algebraic effects each expression may perform.

use std::collections::HashMap;

use crate::ast::{
    self, BinOp, EffectDecl, Expr, FnDecl, HandlerOp, ImplBlock, Item, LetDecl, LitPattern,
    MatchArm, Pattern, Program, Stmt, StringPart, TraitDecl, TypeDecl, TypeExpr, UnaryOp,
};
use crate::error::{LuxError, TypeError, TypeErrorKind};
use crate::token::Span;
use crate::types::{
    AdtDef, EffectDef, EffectOpDef, EffectRow, EffectVar, Type, TypeVar, VariantDef,
};
use std::collections::BTreeSet;

// ── Helpers ───────────────────────────────────────────────────

/// Convert a TypeExpr to a canonical type name string for impl dispatch.
fn type_expr_to_name(te: &TypeExpr) -> String {
    match te {
        TypeExpr::Named { name, .. } => name.clone(),
        TypeExpr::List(_, _) => "List".to_string(),
        TypeExpr::Tuple(_, _) => "Tuple".to_string(),
        TypeExpr::Function { .. } => "Function".to_string(),
        TypeExpr::Inferred(_) => "_".to_string(),
    }
}

/// Convert a resolved Type to a canonical type name string for impl dispatch.
fn type_name_from_type(ty: &crate::types::Type) -> String {
    use crate::types::Type;
    match ty {
        Type::Int => "Int".to_string(),
        Type::Float => "Float".to_string(),
        Type::String => "String".to_string(),
        Type::Bool => "Bool".to_string(),
        Type::Unit => "Unit".to_string(),
        Type::List(_) => "List".to_string(),
        Type::Tuple(_) => "Tuple".to_string(),
        Type::Function { .. } => "Function".to_string(),
        Type::Adt { name, .. } => name.clone(),
        _ => "_".to_string(),
    }
}

// ── Public API ────────────────────────────────────────────────

/// Type-check a program, returning it unchanged on success (MVP: no AST rewriting).
#[allow(clippy::result_large_err)]
pub fn check(program: &Program) -> Result<Program, LuxError> {
    let mut env = TypeEnv::new();
    env.populate_builtins();

    // First pass: register all type, effect, and trait declarations so they're
    // visible to all top-level items regardless of order.
    for item in &program.items {
        match item {
            Item::TypeDecl(td) => env.register_type_decl(td)?,
            Item::EffectDecl(ed) => env.register_effect_decl(ed)?,
            Item::TraitDecl(td) => env.register_trait_decl(td)?,
            Item::ImplBlock(ib) => env.register_impl_block(ib)?,
            _ => {}
        }
    }

    // Second pass: check everything.
    for item in &program.items {
        env.check_item(item)?;
    }

    Ok(program.clone())
}

// ── Type environment ──────────────────────────────────────────

/// Mapping from effect operation name to its parent effect and signature.
#[derive(Debug, Clone)]
struct OpInfo {
    effect_name: String,
    param_types: Vec<Type>,
    return_type: Type,
}

struct TypeEnv {
    /// Variable name -> Type
    bindings: HashMap<String, Type>,
    /// Effect name -> EffectDef
    effects: HashMap<String, EffectDef>,
    /// ADT name -> AdtDef
    adts: HashMap<String, AdtDef>,
    /// Variant name -> (ADT name, variant index)
    constructors: HashMap<String, (String, usize)>,
    /// Effect operation name -> info
    op_index: HashMap<String, OpInfo>,
    /// Substitution map for type variables
    subst: HashMap<TypeVar, Type>,
    /// Type variable counter
    next_var: u32,
    /// Substitution map for effect row variables
    eff_subst: HashMap<EffectVar, EffectRow>,
    /// Effect row variable counter
    next_eff_var: u32,
    /// Whether we're currently inside a handler body (for Resume checking)
    in_handler: bool,
    /// Expected resume type when inside a handler
    resume_type: Option<Type>,
    /// Parent scope (for scoped bindings)
    parent: Option<Box<TypeEnv>>,
    /// Registered traits: trait_name -> list of (method_name, param_types, return_type)
    traits: HashMap<String, Vec<(String, Vec<Type>, Type)>>,
    /// Impl methods: (type_name, method_name) -> function type
    impl_methods: HashMap<(String, String), Type>,
    /// Type parameters in scope (name -> Type::Var)
    type_params: HashMap<String, Type>,
}

#[allow(clippy::result_large_err)]
impl TypeEnv {
    fn new() -> Self {
        Self {
            bindings: HashMap::new(),
            effects: HashMap::new(),
            adts: HashMap::new(),
            constructors: HashMap::new(),
            op_index: HashMap::new(),
            subst: HashMap::new(),
            next_var: 0,
            eff_subst: HashMap::new(),
            type_params: HashMap::new(),
            next_eff_var: 0,
            in_handler: false,
            resume_type: None,
            parent: None,
            traits: HashMap::new(),
            impl_methods: HashMap::new(),
        }
    }

    /// Create a child scope that inherits all registries from the parent.
    fn child(&self) -> Self {
        Self {
            bindings: self.bindings.clone(),
            effects: self.effects.clone(),
            adts: self.adts.clone(),
            constructors: self.constructors.clone(),
            op_index: self.op_index.clone(),
            subst: self.subst.clone(),
            next_var: self.next_var,
            eff_subst: self.eff_subst.clone(),
            next_eff_var: self.next_eff_var,
            in_handler: self.in_handler,
            resume_type: self.resume_type.clone(),
            parent: None,
            traits: self.traits.clone(),
            impl_methods: self.impl_methods.clone(),
            type_params: self.type_params.clone(),
        }
    }

    /// Merge child scope state back (substitutions, next_var).
    fn merge_child(&mut self, child: &TypeEnv) {
        self.next_var = child.next_var;
        for (k, v) in &child.subst {
            self.subst.insert(*k, v.clone());
        }
        self.next_eff_var = child.next_eff_var;
        for (k, v) in &child.eff_subst {
            self.eff_subst.insert(*k, v.clone());
        }
        for (k, v) in &child.traits {
            self.traits.insert(k.clone(), v.clone());
        }
        for (k, v) in &child.impl_methods {
            self.impl_methods.insert(k.clone(), v.clone());
        }
    }

    fn fresh_var(&mut self) -> Type {
        let v = TypeVar(self.next_var);
        self.next_var += 1;
        Type::Var(v)
    }

    fn fresh_eff_var(&mut self) -> EffectRow {
        let var = EffectVar(self.next_eff_var);
        self.next_eff_var += 1;
        EffectRow::Open {
            known: BTreeSet::new(),
            var,
        }
    }

    /// Create a fresh instantiation of a type — replaces all unresolved Type::Var with new fresh vars.
    /// Used to instantiate polymorphic function types at each call site.
    fn instantiate(&mut self, ty: &Type) -> Type {
        let mut mapping: HashMap<TypeVar, Type> = HashMap::new();
        self.collect_vars(ty, &mut mapping);
        if mapping.is_empty() {
            return ty.clone();
        }
        // Replace old vars with fresh ones
        for v in mapping.values_mut() {
            *v = self.fresh_var();
        }
        ty.substitute(&mapping)
    }

    fn collect_vars(&self, ty: &Type, vars: &mut HashMap<TypeVar, Type>) {
        match ty {
            Type::Var(v) => {
                // Only instantiate unresolved vars (not already substituted)
                let resolved = self.apply_subst(ty);
                if matches!(resolved, Type::Var(_)) {
                    vars.entry(*v).or_insert(Type::Var(*v));
                }
            }
            Type::Function {
                params,
                return_type,
                ..
            } => {
                for p in params {
                    self.collect_vars(p, vars);
                }
                self.collect_vars(return_type, vars);
            }
            Type::List(inner) => self.collect_vars(inner, vars),
            Type::Tuple(elems) => {
                for e in elems {
                    self.collect_vars(e, vars);
                }
            }
            Type::Adt { type_args, .. } => {
                for a in type_args {
                    self.collect_vars(a, vars);
                }
            }
            _ => {}
        }
    }

    #[allow(dead_code)]
    fn apply_eff_subst(&self, row: &EffectRow) -> EffectRow {
        match row {
            EffectRow::Closed(_) => row.clone(),
            EffectRow::Open { known, var } => {
                if let Some(resolved) = self.eff_subst.get(var) {
                    let resolved = self.apply_eff_subst(resolved);
                    match resolved {
                        EffectRow::Closed(mut s) => {
                            s.extend(known.iter().cloned());
                            EffectRow::Closed(s)
                        }
                        EffectRow::Open {
                            known: mut rk,
                            var: rv,
                        } => {
                            rk.extend(known.iter().cloned());
                            EffectRow::Open { known: rk, var: rv }
                        }
                    }
                } else {
                    row.clone()
                }
            }
        }
    }

    #[allow(dead_code)]
    fn unify_effects(
        &mut self,
        a: &EffectRow,
        b: &EffectRow,
        _span: &Span,
    ) -> Result<(), TypeError> {
        let a = self.apply_eff_subst(a);
        let b = self.apply_eff_subst(b);
        match (&a, &b) {
            (EffectRow::Closed(_), EffectRow::Closed(_)) => Ok(()),
            (EffectRow::Open { known: ka, var: va }, EffectRow::Closed(sb)) => {
                if ka.is_subset(sb) {
                    let remaining: BTreeSet<_> = sb.difference(ka).cloned().collect();
                    self.eff_subst.insert(*va, EffectRow::Closed(remaining));
                }
                Ok(())
            }
            (EffectRow::Closed(sa), EffectRow::Open { known: kb, var: vb }) => {
                if kb.is_subset(sa) {
                    let remaining: BTreeSet<_> = sa.difference(kb).cloned().collect();
                    self.eff_subst.insert(*vb, EffectRow::Closed(remaining));
                }
                Ok(())
            }
            (EffectRow::Open { known: ka, var: va }, EffectRow::Open { known: kb, var: vb }) => {
                if va == vb {
                    return Ok(());
                }
                let fresh = EffectVar(self.next_eff_var);
                self.next_eff_var += 1;
                let b_minus_a: BTreeSet<_> = kb.difference(ka).cloned().collect();
                let a_minus_b: BTreeSet<_> = ka.difference(kb).cloned().collect();
                self.eff_subst.insert(
                    *va,
                    EffectRow::Open {
                        known: b_minus_a,
                        var: fresh,
                    },
                );
                self.eff_subst.insert(
                    *vb,
                    EffectRow::Open {
                        known: a_minus_b,
                        var: fresh,
                    },
                );
                Ok(())
            }
        }
    }

    fn bind(&mut self, name: impl Into<String>, ty: Type) {
        self.bindings.insert(name.into(), ty);
    }

    fn lookup(&self, name: &str) -> Option<Type> {
        if let Some(ty) = self.bindings.get(name) {
            return Some(self.apply_subst(ty));
        }
        if let Some(parent) = &self.parent {
            return parent.lookup(name);
        }
        None
    }

    #[allow(dead_code)]
    fn lookup_effect(&self, name: &str) -> Option<&EffectDef> {
        if let Some(def) = self.effects.get(name) {
            return Some(def);
        }
        if let Some(parent) = &self.parent {
            return parent.lookup_effect(name);
        }
        None
    }

    fn lookup_adt(&self, name: &str) -> Option<&AdtDef> {
        if let Some(def) = self.adts.get(name) {
            return Some(def);
        }
        if let Some(parent) = &self.parent {
            return parent.lookup_adt(name);
        }
        None
    }

    fn lookup_constructor(&self, name: &str) -> Option<(String, usize)> {
        if let Some(info) = self.constructors.get(name) {
            return Some(info.clone());
        }
        if let Some(parent) = &self.parent {
            return parent.lookup_constructor(name);
        }
        None
    }

    fn lookup_op(&self, name: &str) -> Option<OpInfo> {
        if let Some(info) = self.op_index.get(name) {
            return Some(info.clone());
        }
        if let Some(parent) = &self.parent {
            return parent.lookup_op(name);
        }
        None
    }

    fn is_in_handler(&self) -> bool {
        if self.in_handler {
            return true;
        }
        if let Some(parent) = &self.parent {
            return parent.is_in_handler();
        }
        false
    }

    fn get_resume_type(&self) -> Option<Type> {
        if let Some(ty) = &self.resume_type {
            return Some(ty.clone());
        }
        if let Some(parent) = &self.parent {
            return parent.get_resume_type();
        }
        None
    }

    // ── Substitution ──────────────────────────────────────────

    fn apply_subst(&self, ty: &Type) -> Type {
        match ty {
            Type::Var(v) => {
                if let Some(resolved) = self.subst.get(v) {
                    // Chase the chain
                    self.apply_subst(resolved)
                } else if let Some(parent) = &self.parent {
                    parent.apply_subst(ty)
                } else {
                    ty.clone()
                }
            }
            Type::Function {
                params,
                return_type,
                effects,
            } => Type::Function {
                params: params.iter().map(|p| self.apply_subst(p)).collect(),
                return_type: Box::new(self.apply_subst(return_type)),
                effects: effects.clone(),
            },
            Type::List(inner) => Type::List(Box::new(self.apply_subst(inner))),
            Type::Tuple(elems) => Type::Tuple(elems.iter().map(|e| self.apply_subst(e)).collect()),
            Type::Adt { name, type_args } => Type::Adt {
                name: name.clone(),
                type_args: type_args.iter().map(|a| self.apply_subst(a)).collect(),
            },
            _ => ty.clone(),
        }
    }

    fn occurs_in(&self, var: TypeVar, ty: &Type) -> bool {
        let ty = self.apply_subst(ty);
        match &ty {
            Type::Var(v) => *v == var,
            Type::Function {
                params,
                return_type,
                ..
            } => params.iter().any(|p| self.occurs_in(var, p)) || self.occurs_in(var, return_type),
            Type::List(inner) => self.occurs_in(var, inner),
            Type::Tuple(elems) => elems.iter().any(|e| self.occurs_in(var, e)),
            Type::Adt { type_args, .. } => type_args.iter().any(|a| self.occurs_in(var, a)),
            _ => false,
        }
    }

    fn unify(&mut self, a: &Type, b: &Type, span: &Span) -> Result<(), TypeError> {
        let a = self.apply_subst(a);
        let b = self.apply_subst(b);

        match (&a, &b) {
            _ if a == b => Ok(()),

            // Error type unifies with anything (error recovery)
            (Type::Error, _) | (_, Type::Error) => Ok(()),

            // Never type unifies with anything (it's the bottom type)
            (Type::Never, _) | (_, Type::Never) => Ok(()),

            // Type variable binding
            (Type::Var(v), _) => {
                if self.occurs_in(*v, &b) {
                    return Err(TypeError {
                        kind: TypeErrorKind::InfiniteType,
                        span: span.clone(),
                    });
                }
                self.subst.insert(*v, b);
                Ok(())
            }
            (_, Type::Var(v)) => {
                if self.occurs_in(*v, &a) {
                    return Err(TypeError {
                        kind: TypeErrorKind::InfiniteType,
                        span: span.clone(),
                    });
                }
                self.subst.insert(*v, a);
                Ok(())
            }

            // Structural unification
            (
                Type::Function {
                    params: p1,
                    return_type: r1,
                    ..
                },
                Type::Function {
                    params: p2,
                    return_type: r2,
                    ..
                },
            ) => {
                if p1.len() != p2.len() {
                    return Err(TypeError {
                        kind: TypeErrorKind::WrongArity {
                            expected: p1.len(),
                            found: p2.len(),
                        },
                        span: span.clone(),
                    });
                }
                for (a, b) in p1.iter().zip(p2.iter()) {
                    self.unify(a, b, span)?;
                }
                self.unify(r1, r2, span)
            }

            (Type::List(a), Type::List(b)) => self.unify(a, b, span),

            (Type::Tuple(a), Type::Tuple(b)) => {
                if a.len() != b.len() {
                    return Err(TypeError {
                        kind: TypeErrorKind::Mismatch {
                            expected: Type::Tuple(a.clone()),
                            found: Type::Tuple(b.clone()),
                        },
                        span: span.clone(),
                    });
                }
                for (x, y) in a.iter().zip(b.iter()) {
                    self.unify(x, y, span)?;
                }
                Ok(())
            }

            (
                Type::Adt {
                    name: n1,
                    type_args: a1,
                },
                Type::Adt {
                    name: n2,
                    type_args: a2,
                },
            ) => {
                if n1 != n2 {
                    return Err(TypeError {
                        kind: TypeErrorKind::Mismatch {
                            expected: a.clone(),
                            found: b.clone(),
                        },
                        span: span.clone(),
                    });
                }
                for (x, y) in a1.iter().zip(a2.iter()) {
                    self.unify(x, y, span)?;
                }
                Ok(())
            }

            _ => Err(TypeError {
                kind: TypeErrorKind::Mismatch {
                    expected: a,
                    found: b,
                },
                span: span.clone(),
            }),
        }
    }

    // ── TypeExpr -> Type resolution ───────────────────────────

    fn resolve_type_expr(&mut self, te: &TypeExpr) -> Result<Type, TypeError> {
        match te {
            TypeExpr::Named { name, args, span } => {
                match name.as_str() {
                    "Int" => return Ok(Type::Int),
                    "Float" => return Ok(Type::Float),
                    "String" => return Ok(Type::String),
                    "Bool" => return Ok(Type::Bool),
                    "Unit" | "()" => return Ok(Type::Unit),
                    "Never" => return Ok(Type::Never),
                    _ => {}
                }
                // Check if it's a type parameter in scope
                if let Some(ty) = self.type_params.get(name) {
                    return Ok(ty.clone());
                }
                // Check if it's a known ADT
                if self.lookup_adt(name).is_some() {
                    let type_args: Vec<Type> = args
                        .iter()
                        .map(|a| self.resolve_type_expr(a))
                        .collect::<Result<_, _>>()?;
                    return Ok(Type::Adt {
                        name: name.clone(),
                        type_args,
                    });
                }
                Err(TypeError {
                    kind: TypeErrorKind::UnboundType(name.clone()),
                    span: span.clone(),
                })
            }
            TypeExpr::Function {
                params,
                return_type,
                effects,
                span: _,
            } => {
                let param_types: Vec<Type> = params
                    .iter()
                    .map(|p| self.resolve_type_expr(p))
                    .collect::<Result<_, _>>()?;
                let ret = self.resolve_type_expr(return_type)?;
                let mut eff_set = EffectRow::pure();
                for eff_ref in effects {
                    eff_set.insert(&eff_ref.name);
                }
                Ok(Type::Function {
                    params: param_types,
                    return_type: Box::new(ret),
                    effects: eff_set,
                })
            }
            TypeExpr::Tuple(elems, _) => {
                if elems.is_empty() {
                    return Ok(Type::Unit);
                }
                let types: Vec<Type> = elems
                    .iter()
                    .map(|e| self.resolve_type_expr(e))
                    .collect::<Result<_, _>>()?;
                Ok(Type::Tuple(types))
            }
            TypeExpr::List(inner, _) => {
                let inner_ty = self.resolve_type_expr(inner)?;
                Ok(Type::List(Box::new(inner_ty)))
            }
            TypeExpr::Inferred(_) => Ok(self.fresh_var()),
        }
    }

    // ── Built-ins ─────────────────────────────────────────────

    fn populate_builtins(&mut self) {
        // print: (String) -> () with Console
        self.bind(
            "print",
            Type::Function {
                params: vec![Type::String],
                return_type: Box::new(Type::Unit),
                effects: EffectRow::single("Console"),
            },
        );

        // read_line: () -> String with Console
        self.bind(
            "read_line",
            Type::Function {
                params: vec![],
                return_type: Box::new(Type::String),
                effects: EffectRow::single("Console"),
            },
        );

        // to_string: (T) -> String (polymorphic via fresh var)
        let t = self.fresh_var();
        self.bind(
            "to_string",
            Type::Function {
                params: vec![t],
                return_type: Box::new(Type::String),
                effects: EffectRow::pure(),
            },
        );

        // len: (List<T>) -> Int
        let t = self.fresh_var();
        self.bind(
            "len",
            Type::Function {
                params: vec![Type::List(Box::new(t))],
                return_type: Box::new(Type::Int),
                effects: EffectRow::pure(),
            },
        );

        // is_empty: (List<T>) -> Bool
        let t = self.fresh_var();
        self.bind(
            "is_empty",
            Type::Function {
                params: vec![Type::List(Box::new(t))],
                return_type: Box::new(Type::Bool),
                effects: EffectRow::pure(),
            },
        );

        // push: (List<T>, T) -> List<T>
        let t = self.fresh_var();
        self.bind(
            "push",
            Type::Function {
                params: vec![Type::List(Box::new(t.clone())), t.clone()],
                return_type: Box::new(Type::List(Box::new(t))),
                effects: EffectRow::pure(),
            },
        );

        // println: (T) -> () with Console
        let t = self.fresh_var();
        self.bind(
            "println",
            Type::Function {
                params: vec![t],
                return_type: Box::new(Type::Unit),
                effects: EffectRow::single("Console"),
            },
        );

        // parse_int: (String) -> Int
        self.bind(
            "parse_int",
            Type::Function {
                params: vec![Type::String],
                return_type: Box::new(Type::Int),
                effects: EffectRow::pure(),
            },
        );

        // range: (Int, Int) -> List<Int>
        self.bind(
            "range",
            Type::Function {
                params: vec![Type::Int, Type::Int],
                return_type: Box::new(Type::List(Box::new(Type::Int))),
                effects: EffectRow::pure(),
            },
        );

        // generate: (() -> ()) -> Generator
        // Generator is an opaque ADT with no type parameters.
        self.bind(
            "generate",
            Type::Function {
                params: vec![Type::Function {
                    params: vec![],
                    return_type: Box::new(Type::Unit),
                    effects: EffectRow::single("Yield"),
                }],
                return_type: Box::new(Type::Adt {
                    name: "Generator".into(),
                    type_args: vec![],
                }),
                effects: EffectRow::pure(),
            },
        );

        // next: (Generator) -> T  (return type is a fresh var — unconstrained for now)
        let t = self.fresh_var();
        self.bind(
            "next",
            Type::Function {
                params: vec![Type::Adt {
                    name: "Generator".into(),
                    type_args: vec![],
                }],
                return_type: Box::new(t),
                effects: EffectRow::pure(),
            },
        );

        // Builtin Yield effect: yield(T) -> ()
        // Registered so that `yield(val)` inside generator functions type-checks.
        let t = self.fresh_var();
        let yield_op = EffectOpDef {
            name: "yield".into(),
            param_types: vec![t],
            return_type: Type::Unit,
        };
        self.op_index.insert(
            "yield".into(),
            OpInfo {
                effect_name: "Yield".into(),
                param_types: yield_op.param_types.clone(),
                return_type: yield_op.return_type.clone(),
            },
        );
        self.effects.insert(
            "Yield".into(),
            EffectDef {
                name: "Yield".into(),
                operations: vec![yield_op],
            },
        );
    }

    // ── Registration (first pass) ─────────────────────────────

    fn register_type_decl(&mut self, td: &TypeDecl) -> Result<(), TypeError> {
        let mut variants = Vec::new();
        for (i, v) in td.variants.iter().enumerate() {
            // For MVP, variant field types that reference type params become fresh vars
            let fields: Vec<Type> = v
                .fields
                .iter()
                .map(|f| self.resolve_type_expr(f).unwrap_or(Type::Error))
                .collect();
            variants.push(VariantDef {
                name: v.name.clone(),
                fields,
            });
            self.constructors
                .insert(v.name.clone(), (td.name.clone(), i));
        }
        self.adts.insert(
            td.name.clone(),
            AdtDef {
                name: td.name.clone(),
                type_params: td.type_params.clone(),
                variants,
            },
        );
        Ok(())
    }

    fn register_effect_decl(&mut self, ed: &EffectDecl) -> Result<(), TypeError> {
        let mut ops = Vec::new();
        for op in &ed.operations {
            let param_types: Vec<Type> = op
                .params
                .iter()
                .map(|p| {
                    p.type_ann
                        .as_ref()
                        .map(|t| self.resolve_type_expr(t).unwrap_or(Type::Error))
                        .unwrap_or_else(|| self.fresh_var())
                })
                .collect();
            let return_type = self
                .resolve_type_expr(&op.return_type)
                .unwrap_or(Type::Error);

            self.op_index.insert(
                op.name.clone(),
                OpInfo {
                    effect_name: ed.name.clone(),
                    param_types: param_types.clone(),
                    return_type: return_type.clone(),
                },
            );

            ops.push(EffectOpDef {
                name: op.name.clone(),
                param_types,
                return_type,
            });
        }
        self.effects.insert(
            ed.name.clone(),
            EffectDef {
                name: ed.name.clone(),
                operations: ops,
            },
        );
        Ok(())
    }

    fn register_trait_decl(&mut self, td: &TraitDecl) -> Result<(), TypeError> {
        let mut methods = Vec::new();
        for m in &td.methods {
            let param_types: Vec<Type> = m
                .params
                .iter()
                .map(|p| {
                    p.type_ann
                        .as_ref()
                        .map(|t| self.resolve_type_expr(t).unwrap_or(Type::Error))
                        .unwrap_or_else(|| self.fresh_var())
                })
                .collect();
            let return_type = m
                .return_type
                .as_ref()
                .map(|t| self.resolve_type_expr(t).unwrap_or(Type::Error))
                .unwrap_or(Type::Unit);
            methods.push((m.name.clone(), param_types, return_type));
        }
        self.traits.insert(td.name.clone(), methods);
        Ok(())
    }

    fn register_impl_block(&mut self, ib: &ImplBlock) -> Result<(), TypeError> {
        let type_name = type_expr_to_name(&ib.target_type);
        for method in &ib.methods {
            let mut param_types = Vec::new();
            for p in &method.params {
                let ty = p
                    .type_ann
                    .as_ref()
                    .map(|t| self.resolve_type_expr(t).unwrap_or(Type::Error))
                    .unwrap_or_else(|| self.fresh_var());
                param_types.push(ty);
            }
            let return_type = method
                .return_type
                .as_ref()
                .map(|t| self.resolve_type_expr(t).unwrap_or(Type::Error))
                .unwrap_or(Type::Unit);
            let fn_type = Type::Function {
                params: param_types,
                return_type: Box::new(return_type),
                effects: EffectRow::pure(),
            };
            self.impl_methods
                .insert((type_name.clone(), method.name.clone()), fn_type);
        }
        Ok(())
    }

    // ── Item checking (second pass) ───────────────────────────

    fn check_item(&mut self, item: &Item) -> Result<(), TypeError> {
        match item {
            Item::FnDecl(fd) => self.check_fn_decl(fd),
            Item::LetDecl(ld) => self.check_let_decl(ld),
            Item::TypeDecl(_) | Item::EffectDecl(_) => Ok(()), // already registered
            Item::TraitDecl(_) | Item::ImplBlock(_) => Ok(()), // already registered in first pass
            Item::Expr(e) => {
                self.infer_expr(e)?;
                Ok(())
            }
        }
    }

    fn check_fn_decl(&mut self, fd: &FnDecl) -> Result<(), TypeError> {
        let mut child = self.child();

        // Bind type parameters as fresh type variables
        for tp in &fd.type_params {
            let var = child.fresh_var();
            child.type_params.insert(tp.clone(), var);
        }

        let mut param_types = Vec::new();
        for p in &fd.params {
            let ty = if let Some(ann) = &p.type_ann {
                child.resolve_type_expr(ann)?
            } else {
                child.fresh_var()
            };
            child.bind(&p.name, ty.clone());
            param_types.push(ty);
        }

        // Pre-bind function name for recursion (with fresh return type var)
        let ret_var = child.fresh_var();
        // If effects are declared, use a closed row; otherwise open (polymorphic)
        let prelim_effects = if fd.effects.is_empty() {
            child.fresh_eff_var()
        } else {
            let mut closed = EffectRow::pure();
            for eff_ref in &fd.effects {
                closed.insert(&eff_ref.name);
            }
            closed
        };
        let preliminary_fn_type = Type::Function {
            params: param_types.clone(),
            return_type: Box::new(ret_var.clone()),
            effects: prelim_effects,
        };
        child.bind(&fd.name, preliminary_fn_type);

        let (body_ty, body_effects) = child.infer_expr(&fd.body)?;
        child.unify(&ret_var, &body_ty, &fd.span)?;

        // Check return type annotation inside child scope (so type params are in scope)
        if let Some(ret_ann) = &fd.return_type {
            let ret_ty = child.resolve_type_expr(ret_ann)?;
            child.unify(&body_ty, &ret_ty, &fd.span)?;
        }

        self.merge_child(&child);

        // Check effect annotations: inferred effects must be a subset of declared
        if !fd.effects.is_empty() {
            let mut declared = EffectRow::pure();
            for eff_ref in &fd.effects {
                declared.insert(&eff_ref.name);
            }
            for eff in body_effects.effects() {
                if !declared.contains(&eff.name) {
                    return Err(TypeError {
                        kind: TypeErrorKind::UnhandledEffect(eff.name.clone()),
                        span: fd.span.clone(),
                    });
                }
            }
        }

        let fn_type = Type::Function {
            params: param_types,
            return_type: Box::new(self.apply_subst(&body_ty)),
            effects: body_effects,
        };
        self.bind(&fd.name, fn_type);
        Ok(())
    }

    fn check_let_decl(&mut self, ld: &LetDecl) -> Result<(), TypeError> {
        let (val_ty, _effects) = self.infer_expr(&ld.value)?;

        if let Some(ann) = &ld.type_ann {
            let ann_ty = self.resolve_type_expr(ann)?;
            self.unify(&val_ty, &ann_ty, &ld.span)?;
        }

        self.bind(&ld.name, self.apply_subst(&val_ty));
        Ok(())
    }

    // ── Expression inference ──────────────────────────────────

    fn infer_expr(&mut self, expr: &Expr) -> Result<(Type, EffectRow), TypeError> {
        match expr {
            Expr::IntLit(_, _) => Ok((Type::Int, EffectRow::pure())),
            Expr::FloatLit(_, _) => Ok((Type::Float, EffectRow::pure())),
            Expr::StringLit(_, _) => Ok((Type::String, EffectRow::pure())),
            Expr::BoolLit(_, _) => Ok((Type::Bool, EffectRow::pure())),

            Expr::Var(name, span) => {
                // Check if it's an effect operation — treat as Perform with 0 args
                if let Some(op_info) = self.lookup_op(name) {
                    if op_info.param_types.is_empty() {
                        let mut effs = EffectRow::pure();
                        effs.insert(&op_info.effect_name);
                        return Ok((op_info.return_type.clone(), effs));
                    }
                    // If it takes params, return it as a function type
                    let fn_ty = Type::Function {
                        params: op_info.param_types.clone(),
                        return_type: Box::new(op_info.return_type.clone()),
                        effects: EffectRow::single(&op_info.effect_name),
                    };
                    return Ok((fn_ty, EffectRow::pure()));
                }

                // Check if it's an ADT constructor
                if let Some((adt_name, idx)) = self.lookup_constructor(name) {
                    let adt = self.lookup_adt(&adt_name).cloned();
                    if let Some(adt_def) = adt {
                        let variant = &adt_def.variants[idx];
                        if variant.fields.is_empty() {
                            // Nullary constructor — return the ADT type directly
                            return Ok((
                                Type::Adt {
                                    name: adt_name,
                                    type_args: adt_def
                                        .type_params
                                        .iter()
                                        .map(|_| self.fresh_var())
                                        .collect(),
                                },
                                EffectRow::pure(),
                            ));
                        }
                        // Constructor with fields — return as function
                        let type_args: Vec<Type> = adt_def
                            .type_params
                            .iter()
                            .map(|_| self.fresh_var())
                            .collect();
                        let ret_ty = Type::Adt {
                            name: adt_name,
                            type_args,
                        };
                        return Ok((
                            Type::Function {
                                params: variant.fields.clone(),
                                return_type: Box::new(ret_ty),
                                effects: EffectRow::pure(),
                            },
                            EffectRow::pure(),
                        ));
                    }
                }

                match self.lookup(name) {
                    Some(ty) => Ok((ty, EffectRow::pure())),
                    None => Err(TypeError {
                        kind: TypeErrorKind::UnboundVariable(name.clone()),
                        span: span.clone(),
                    }),
                }
            }

            Expr::List(elems, span) => {
                let elem_ty = self.fresh_var();
                let mut effs = EffectRow::pure();
                for e in elems {
                    let (ty, eff) = self.infer_expr(e)?;
                    self.unify(&ty, &elem_ty, span)?;
                    effs = effs.union(&eff);
                }
                Ok((Type::List(Box::new(self.apply_subst(&elem_ty))), effs))
            }

            Expr::BinOp {
                op,
                left,
                right,
                span,
            } => self.infer_binop(op, left, right, span),

            Expr::UnaryOp { op, operand, span } => self.infer_unaryop(op, operand, span),

            Expr::Call { func, args, span } => self.infer_call(func, args, span),

            Expr::FieldAccess {
                object,
                field,
                span: _,
            } => {
                let (obj_ty, effs) = self.infer_expr(object)?;
                let obj_ty = self.apply_subst(&obj_ty);
                // MVP: field access on tuples by index
                if let Type::Tuple(elems) = &obj_ty {
                    if let Ok(idx) = field.parse::<usize>() {
                        if idx < elems.len() {
                            return Ok((elems[idx].clone(), effs));
                        }
                    }
                }
                // For MVP, treat unknown field access as returning a fresh var
                let result_ty = self.fresh_var();
                Ok((result_ty, effs))
            }

            Expr::Index {
                object,
                index,
                span,
            } => {
                let (obj_ty, effs1) = self.infer_expr(object)?;
                let (idx_ty, effs2) = self.infer_expr(index)?;
                self.unify(&idx_ty, &Type::Int, span)?;
                let obj_ty = self.apply_subst(&obj_ty);
                let elem_ty = match &obj_ty {
                    Type::List(inner) => *inner.clone(),
                    _ => self.fresh_var(),
                };
                Ok((elem_ty, effs1.union(&effs2)))
            }

            Expr::Lambda {
                params,
                body,
                span: _,
            } => {
                let mut child = self.child();
                let mut param_types = Vec::new();
                for p in params {
                    let ty = if let Some(ann) = &p.type_ann {
                        child.resolve_type_expr(ann)?
                    } else {
                        child.fresh_var()
                    };
                    child.bind(&p.name, ty.clone());
                    param_types.push(ty);
                }
                let (body_ty, body_effs) = child.infer_expr(body)?;
                self.merge_child(&child);
                Ok((
                    Type::Function {
                        params: param_types,
                        return_type: Box::new(self.apply_subst(&body_ty)),
                        effects: body_effs,
                    },
                    EffectRow::pure(), // Lambda itself is pure; effects happen when called
                ))
            }

            Expr::Block { stmts, expr, span } => self.infer_block(stmts, expr, span),

            Expr::If {
                condition,
                then_branch,
                else_branch,
                span,
            } => {
                let (cond_ty, effs1) = self.infer_expr(condition)?;
                self.unify(&cond_ty, &Type::Bool, span)?;
                let (then_ty, effs2) = self.infer_expr(then_branch)?;
                let mut effs = effs1.union(&effs2);
                if let Some(else_br) = else_branch {
                    let (else_ty, effs3) = self.infer_expr(else_br)?;
                    self.unify(&then_ty, &else_ty, span)?;
                    effs = effs.union(&effs3);
                } else {
                    // No else branch — then must be Unit
                    self.unify(&then_ty, &Type::Unit, span)?;
                }
                Ok((self.apply_subst(&then_ty), effs))
            }

            Expr::Match {
                scrutinee,
                arms,
                span,
            } => self.infer_match(scrutinee, arms, span),

            Expr::Let {
                name,
                type_ann,
                value,
                span,
            } => {
                let (val_ty, effs) = self.infer_expr(value)?;
                if let Some(ann) = type_ann {
                    let ann_ty = self.resolve_type_expr(ann)?;
                    self.unify(&val_ty, &ann_ty, span)?;
                }
                self.bind(name, self.apply_subst(&val_ty));
                Ok((Type::Unit, effs))
            }

            Expr::Pipe { left, right, span } => {
                // a |> f  desugars to f(a)
                let (left_ty, effs1) = self.infer_expr(left)?;
                let (func_ty, effs2) = self.infer_expr(right)?;
                let func_ty = self.apply_subst(&func_ty);
                let ret_ty = self.fresh_var();

                match &func_ty {
                    Type::Function {
                        params,
                        return_type,
                        effects,
                    } => {
                        if params.len() != 1 {
                            return Err(TypeError {
                                kind: TypeErrorKind::WrongArity {
                                    expected: 1,
                                    found: params.len(),
                                },
                                span: span.clone(),
                            });
                        }
                        self.unify(&left_ty, &params[0], span)?;
                        Ok((
                            self.apply_subst(return_type),
                            effs1.union(&effs2).union(effects),
                        ))
                    }
                    Type::Var(_) => {
                        // Unify with a function type
                        let fn_ty = Type::Function {
                            params: vec![left_ty],
                            return_type: Box::new(ret_ty.clone()),
                            effects: EffectRow::pure(),
                        };
                        self.unify(&func_ty, &fn_ty, span)?;
                        Ok((self.apply_subst(&ret_ty), effs1.union(&effs2)))
                    }
                    _ => Err(TypeError {
                        kind: TypeErrorKind::NotAFunction(func_ty),
                        span: span.clone(),
                    }),
                }
            }

            Expr::StringInterp { parts, span: _ } => {
                let mut effs = EffectRow::pure();
                for part in parts {
                    if let StringPart::Expr(e) = part {
                        let (_, eff) = self.infer_expr(e)?;
                        effs = effs.union(&eff);
                    }
                }
                Ok((Type::String, effs))
            }

            Expr::Handle {
                expr,
                handlers,
                span,
            } => self.infer_handle(expr, handlers, span),

            Expr::Resume { value, span } => {
                if !self.is_in_handler() {
                    return Err(TypeError {
                        kind: TypeErrorKind::UnboundVariable("resume".into()),
                        span: span.clone(),
                    });
                }
                let (val_ty, effs) = self.infer_expr(value)?;
                if let Some(expected) = self.get_resume_type() {
                    self.unify(&val_ty, &expected, span)?;
                }
                // Resume returns the body type of the handler (for MVP, use fresh var)
                let ret = self.fresh_var();
                Ok((ret, effs))
            }

            Expr::Perform {
                effect,
                operation,
                args,
                span,
            } => self.infer_perform(effect, operation, args, span),

            Expr::Return { value, span: _ } => {
                let (val_ty, effs) = self.infer_expr(value)?;
                Ok((val_ty, effs))
            }

            Expr::Tuple(elements, _span) => {
                let mut types = Vec::new();
                let mut effs = EffectRow::pure();
                for elem in elements {
                    let (t, e) = self.infer_expr(elem)?;
                    types.push(t);
                    effs = effs.union(&e);
                }
                Ok((Type::Tuple(types), effs))
            }

            Expr::While {
                condition,
                body,
                span,
            } => {
                let (cond_ty, mut effs) = self.infer_expr(condition)?;
                self.unify(&cond_ty, &Type::Bool, span)?;
                let (_, body_effs) = self.infer_expr(body)?;
                effs = effs.union(&body_effs);
                Ok((Type::Unit, effs))
            }

            Expr::Loop { body, .. } => {
                let (_, effs) = self.infer_expr(body)?;
                Ok((Type::Unit, effs))
            }

            Expr::For {
                binding,
                iterable,
                body,
                span,
            } => {
                let (iter_ty, mut effs) = self.infer_expr(iterable)?;
                let elem_ty = self.fresh_var();
                // Accept either List<T> or Generator (opaque) as the iterable.
                let is_generator = matches!(
                    self.apply_subst(&iter_ty),
                    Type::Adt { ref name, .. } if name == "Generator"
                );
                if !is_generator {
                    self.unify(&iter_ty, &Type::List(Box::new(elem_ty.clone())), span)?;
                }
                let mut child = self.child();
                child.bind(binding.clone(), elem_ty);
                let (_, body_effs) = child.infer_expr(body)?;
                self.merge_child(&child);
                effs = effs.union(&body_effs);
                Ok((Type::Unit, effs))
            }

            Expr::Break { value, .. } => {
                if let Some(expr) = value {
                    let (_, effs) = self.infer_expr(expr)?;
                    Ok((Type::Unit, effs))
                } else {
                    Ok((Type::Unit, EffectRow::pure()))
                }
            }

            Expr::Continue { .. } => Ok((Type::Unit, EffectRow::pure())),
        }
    }

    // ── Binary operations ─────────────────────────────────────

    fn infer_binop(
        &mut self,
        op: &BinOp,
        left: &Expr,
        right: &Expr,
        span: &Span,
    ) -> Result<(Type, EffectRow), TypeError> {
        let (l_ty, effs1) = self.infer_expr(left)?;
        let (r_ty, effs2) = self.infer_expr(right)?;
        let effs = effs1.union(&effs2);

        match op {
            // Arithmetic: Int or Float
            BinOp::Add | BinOp::Sub | BinOp::Mul | BinOp::Div | BinOp::Mod => {
                self.unify(&l_ty, &r_ty, span)?;
                let resolved = self.apply_subst(&l_ty);
                match &resolved {
                    Type::Int | Type::Float => Ok((resolved, effs)),
                    Type::Var(_) => {
                        // Default to Int for unresolved arithmetic
                        self.unify(&resolved, &Type::Int, span)?;
                        Ok((Type::Int, effs))
                    }
                    _ => Err(TypeError {
                        kind: TypeErrorKind::Mismatch {
                            expected: Type::Int,
                            found: resolved,
                        },
                        span: span.clone(),
                    }),
                }
            }

            // Comparison: same types -> Bool
            BinOp::Eq | BinOp::Neq | BinOp::Lt | BinOp::LtEq | BinOp::Gt | BinOp::GtEq => {
                self.unify(&l_ty, &r_ty, span)?;
                Ok((Type::Bool, effs))
            }

            // Boolean: Bool -> Bool
            BinOp::And | BinOp::Or => {
                self.unify(&l_ty, &Type::Bool, span)?;
                self.unify(&r_ty, &Type::Bool, span)?;
                Ok((Type::Bool, effs))
            }

            // Concat: String or List
            BinOp::Concat => {
                self.unify(&l_ty, &r_ty, span)?;
                let resolved = self.apply_subst(&l_ty);
                match &resolved {
                    Type::String | Type::List(_) => Ok((resolved, effs)),
                    Type::Var(_) => {
                        // Default to String
                        self.unify(&resolved, &Type::String, span)?;
                        Ok((Type::String, effs))
                    }
                    _ => Err(TypeError {
                        kind: TypeErrorKind::Mismatch {
                            expected: Type::String,
                            found: resolved,
                        },
                        span: span.clone(),
                    }),
                }
            }
        }
    }

    // ── Unary operations ──────────────────────────────────────

    fn infer_unaryop(
        &mut self,
        op: &UnaryOp,
        operand: &Expr,
        span: &Span,
    ) -> Result<(Type, EffectRow), TypeError> {
        let (ty, effs) = self.infer_expr(operand)?;
        match op {
            UnaryOp::Neg => {
                let resolved = self.apply_subst(&ty);
                match &resolved {
                    Type::Int | Type::Float => Ok((resolved, effs)),
                    Type::Var(_) => {
                        self.unify(&resolved, &Type::Int, span)?;
                        Ok((Type::Int, effs))
                    }
                    _ => Err(TypeError {
                        kind: TypeErrorKind::Mismatch {
                            expected: Type::Int,
                            found: resolved,
                        },
                        span: span.clone(),
                    }),
                }
            }
            UnaryOp::Not => {
                self.unify(&ty, &Type::Bool, span)?;
                Ok((Type::Bool, effs))
            }
        }
    }

    // ── Function calls ────────────────────────────────────────

    fn infer_call(
        &mut self,
        func: &Expr,
        args: &[Expr],
        span: &Span,
    ) -> Result<(Type, EffectRow), TypeError> {
        // Special case: if func is a Var naming an effect operation
        if let Expr::Var(name, _) = func {
            if let Some(op_info) = self.lookup_op(name) {
                return self.infer_perform(&op_info.effect_name, name, args, span);
            }
            // Special case: ADT constructor
            if let Some((adt_name, idx)) = self.lookup_constructor(name) {
                return self.infer_constructor_call(&adt_name, idx, args, span);
            }
        }

        // Special case: method call `obj.method(args)` dispatched via impl table
        if let Expr::FieldAccess { object, field, .. } = func {
            let (obj_ty, obj_effs) = self.infer_expr(object)?;
            let obj_ty = self.apply_subst(&obj_ty);
            let type_name = type_name_from_type(&obj_ty);
            if let Some(method_ty) = self.impl_methods.get(&(type_name, field.clone())).cloned() {
                let method_ty = self.apply_subst(&method_ty);
                if let Type::Function {
                    params,
                    return_type,
                    effects,
                } = &method_ty
                {
                    // args to checker don't include self — self is the object
                    let mut arg_effs = obj_effs;
                    let mut arg_types = vec![obj_ty]; // self is first param
                    for arg in args {
                        let (ty, eff) = self.infer_expr(arg)?;
                        arg_types.push(ty);
                        arg_effs = arg_effs.union(&eff);
                    }
                    if params.len() != arg_types.len() {
                        return Err(TypeError {
                            kind: TypeErrorKind::WrongArity {
                                expected: params.len(),
                                found: arg_types.len(),
                            },
                            span: span.clone(),
                        });
                    }
                    for (param, arg) in params.iter().zip(arg_types.iter()) {
                        self.unify(param, arg, span)?;
                    }
                    let ret = self.apply_subst(return_type);
                    return Ok((ret, arg_effs.union(effects)));
                }
            }
        }

        let (func_ty, effs1) = self.infer_expr(func)?;
        let func_ty = self.apply_subst(&func_ty);
        let func_ty = self.instantiate(&func_ty);

        let mut arg_types = Vec::new();
        let mut arg_effs = EffectRow::pure();
        for arg in args {
            let (ty, eff) = self.infer_expr(arg)?;
            arg_types.push(ty);
            arg_effs = arg_effs.union(&eff);
        }

        match &func_ty {
            Type::Function {
                params,
                return_type,
                effects,
            } => {
                if params.len() != arg_types.len() {
                    return Err(TypeError {
                        kind: TypeErrorKind::WrongArity {
                            expected: params.len(),
                            found: arg_types.len(),
                        },
                        span: span.clone(),
                    });
                }
                for (param, arg) in params.iter().zip(arg_types.iter()) {
                    self.unify(param, arg, span)?;
                }
                let ret = self.apply_subst(return_type);
                Ok((ret, effs1.union(&arg_effs).union(effects)))
            }
            Type::Var(_) => {
                // Unify with a fresh function type
                let ret = self.fresh_var();
                let fn_ty = Type::Function {
                    params: arg_types,
                    return_type: Box::new(ret.clone()),
                    effects: EffectRow::pure(),
                };
                self.unify(&func_ty, &fn_ty, span)?;
                Ok((self.apply_subst(&ret), effs1.union(&arg_effs)))
            }
            _ => Err(TypeError {
                kind: TypeErrorKind::NotAFunction(func_ty),
                span: span.clone(),
            }),
        }
    }

    fn infer_constructor_call(
        &mut self,
        adt_name: &str,
        variant_idx: usize,
        args: &[Expr],
        span: &Span,
    ) -> Result<(Type, EffectRow), TypeError> {
        let adt_def = self
            .lookup_adt(adt_name)
            .cloned()
            .ok_or_else(|| TypeError {
                kind: TypeErrorKind::UnboundType(adt_name.to_string()),
                span: span.clone(),
            })?;

        let variant = &adt_def.variants[variant_idx];
        if variant.fields.len() != args.len() {
            return Err(TypeError {
                kind: TypeErrorKind::WrongArity {
                    expected: variant.fields.len(),
                    found: args.len(),
                },
                span: span.clone(),
            });
        }

        let mut effs = EffectRow::pure();
        // Create a mapping from type params to fresh vars for this instantiation
        let type_args: Vec<Type> = adt_def
            .type_params
            .iter()
            .map(|_| self.fresh_var())
            .collect();

        for (field_ty, arg) in variant.fields.iter().zip(args) {
            let (arg_ty, eff) = self.infer_expr(arg)?;
            self.unify(field_ty, &arg_ty, span)?;
            effs = effs.union(&eff);
        }

        Ok((
            Type::Adt {
                name: adt_name.to_string(),
                type_args,
            },
            effs,
        ))
    }

    // ── Block ─────────────────────────────────────────────────

    fn infer_block(
        &mut self,
        stmts: &[Stmt],
        final_expr: &Option<Box<Expr>>,
        _span: &Span,
    ) -> Result<(Type, EffectRow), TypeError> {
        let mut child = self.child();
        let mut effs = EffectRow::pure();

        for stmt in stmts {
            match stmt {
                Stmt::Let(ld) => {
                    let (val_ty, eff) = child.infer_expr(&ld.value)?;
                    if let Some(ann) = &ld.type_ann {
                        let ann_ty = child.resolve_type_expr(ann)?;
                        child.unify(&val_ty, &ann_ty, &ld.span)?;
                    }
                    child.bind(&ld.name, child.apply_subst(&val_ty));
                    effs = effs.union(&eff);
                }
                Stmt::Expr(e) => {
                    let (_, eff) = child.infer_expr(e)?;
                    effs = effs.union(&eff);
                }
                Stmt::FnDecl(fd) => {
                    child.check_fn_decl(fd)?;
                }
            }
        }

        let result_ty = if let Some(e) = final_expr {
            let (ty, eff) = child.infer_expr(e)?;
            effs = effs.union(&eff);
            ty
        } else {
            Type::Unit
        };

        self.merge_child(&child);
        Ok((self.apply_subst(&result_ty), effs))
    }

    // ── Match ─────────────────────────────────────────────────

    fn infer_match(
        &mut self,
        scrutinee: &Expr,
        arms: &[MatchArm],
        span: &Span,
    ) -> Result<(Type, EffectRow), TypeError> {
        let (scrut_ty, mut effs) = self.infer_expr(scrutinee)?;
        let scrut_ty = self.apply_subst(&scrut_ty);

        let result_ty = self.fresh_var();

        for arm in arms {
            let mut child = self.child();
            child.check_pattern(&arm.pattern, &scrut_ty, span)?;
            self.merge_child(&child);

            if let Some(guard) = &arm.guard {
                let (guard_ty, guard_effs) = child.infer_expr(guard)?;
                child.unify(&guard_ty, &Type::Bool, span)?;
                self.merge_child(&child);
                effs = effs.union(&guard_effs);
            }

            let (body_ty, body_effs) = child.infer_expr(&arm.body)?;
            self.merge_child(&child);
            self.unify(&result_ty, &body_ty, span)?;
            effs = effs.union(&body_effs);
        }

        Ok((self.apply_subst(&result_ty), effs))
    }

    fn check_pattern(
        &mut self,
        pattern: &Pattern,
        expected_ty: &Type,
        _span: &Span,
    ) -> Result<(), TypeError> {
        match pattern {
            Pattern::Wildcard(_) => Ok(()),
            Pattern::Binding(name, _) => {
                self.bind(name, expected_ty.clone());
                Ok(())
            }
            Pattern::Literal(lit, pat_span) => {
                let lit_ty = match lit {
                    LitPattern::Int(_) => Type::Int,
                    LitPattern::Float(_) => Type::Float,
                    LitPattern::String(_) => Type::String,
                    LitPattern::Bool(_) => Type::Bool,
                };
                self.unify(&lit_ty, expected_ty, pat_span)?;
                Ok(())
            }
            Pattern::Variant {
                name,
                fields,
                span: pat_span,
            } => {
                let (adt_name, idx) = self.lookup_constructor(name).ok_or_else(|| TypeError {
                    kind: TypeErrorKind::UnboundVariable(name.clone()),
                    span: pat_span.clone(),
                })?;
                let adt_def = self
                    .lookup_adt(&adt_name)
                    .cloned()
                    .ok_or_else(|| TypeError {
                        kind: TypeErrorKind::UnboundType(adt_name.clone()),
                        span: pat_span.clone(),
                    })?;
                let variant = &adt_def.variants[idx];
                if variant.fields.len() != fields.len() {
                    return Err(TypeError {
                        kind: TypeErrorKind::WrongArity {
                            expected: variant.fields.len(),
                            found: fields.len(),
                        },
                        span: pat_span.clone(),
                    });
                }
                // Unify scrutinee type with the ADT type
                let type_args: Vec<Type> = adt_def
                    .type_params
                    .iter()
                    .map(|_| self.fresh_var())
                    .collect();
                let adt_ty = Type::Adt {
                    name: adt_name,
                    type_args,
                };
                self.unify(expected_ty, &adt_ty, pat_span)?;

                for (field_pat, field_ty) in fields.iter().zip(variant.fields.iter()) {
                    self.check_pattern(field_pat, field_ty, pat_span)?;
                }
                Ok(())
            }
            Pattern::Tuple(pats, pat_span) => {
                let elem_types: Vec<Type> = pats.iter().map(|_| self.fresh_var()).collect();
                let tuple_ty = Type::Tuple(elem_types.clone());
                self.unify(expected_ty, &tuple_ty, pat_span)?;
                for (pat, ty) in pats.iter().zip(elem_types.iter()) {
                    self.check_pattern(pat, ty, pat_span)?;
                }
                Ok(())
            }
        }
    }

    // ── Handle / Perform ──────────────────────────────────────

    fn infer_handle(
        &mut self,
        expr: &Expr,
        handlers: &[ast::HandlerClause],
        span: &Span,
    ) -> Result<(Type, EffectRow), TypeError> {
        let (expr_ty, mut expr_effs) = self.infer_expr(expr)?;
        let result_ty = self.fresh_var();
        self.unify(&result_ty, &expr_ty, span)?;

        let mut effs = EffectRow::pure();

        for handler in handlers {
            match &handler.operation {
                HandlerOp::OpHandler {
                    effect_name,
                    op_name,
                    params,
                    body,
                } => {
                    // Look up the effect operation
                    let op_info = self.lookup_op(op_name).ok_or_else(|| TypeError {
                        kind: TypeErrorKind::UnboundEffectOp(op_name.clone()),
                        span: handler.span.clone(),
                    })?;

                    // Determine which effect is being handled
                    let eff_name = effect_name.as_ref().unwrap_or(&op_info.effect_name).clone();

                    // Remove this effect from the expression's effect set
                    expr_effs = expr_effs.without(&eff_name);

                    // Type-check the handler body in a child scope
                    let mut child = self.child();
                    child.in_handler = true;
                    child.resume_type = Some(op_info.return_type.clone());

                    // Bind handler parameters
                    for (i, param_name) in params.iter().enumerate() {
                        let param_ty = op_info
                            .param_types
                            .get(i)
                            .cloned()
                            .unwrap_or_else(|| child.fresh_var());
                        child.bind(param_name, param_ty);
                    }

                    let (body_ty, body_effs) = child.infer_expr(body)?;
                    self.merge_child(&child);
                    self.unify(&result_ty, &body_ty, span)?;
                    effs = effs.union(&body_effs);
                }
                HandlerOp::UseHandler { name } => {
                    // For MVP, `use HandlerName` just removes the named effect
                    expr_effs = expr_effs.without(name);
                }
            }
        }

        // The remaining effects from expr propagate, plus handler body effects
        Ok((self.apply_subst(&result_ty), effs.union(&expr_effs)))
    }

    fn infer_perform(
        &mut self,
        _effect: &str,
        operation: &str,
        args: &[Expr],
        span: &Span,
    ) -> Result<(Type, EffectRow), TypeError> {
        let op_info = self.lookup_op(operation).ok_or_else(|| TypeError {
            kind: TypeErrorKind::UnboundEffectOp(operation.to_string()),
            span: span.clone(),
        })?;

        if op_info.param_types.len() != args.len() {
            return Err(TypeError {
                kind: TypeErrorKind::WrongArity {
                    expected: op_info.param_types.len(),
                    found: args.len(),
                },
                span: span.clone(),
            });
        }

        let mut effs = EffectRow::single(&op_info.effect_name);
        for (param_ty, arg) in op_info.param_types.iter().zip(args) {
            let (arg_ty, eff) = self.infer_expr(arg)?;
            self.unify(param_ty, &arg_ty, span)?;
            effs = effs.union(&eff);
        }

        Ok((op_info.return_type.clone(), effs))
    }
}

// ── ReplChecker ───────────────────────────────────────────────

/// A persistent type-checker for the REPL.
///
/// Maintains type environment across lines so that bindings introduced
/// in one line are visible in subsequent lines.
pub struct ReplChecker {
    env: TypeEnv,
}

impl ReplChecker {
    /// Create a new ReplChecker with builtins pre-populated.
    pub fn new() -> Self {
        let mut env = TypeEnv::new();
        env.populate_builtins();
        Self { env }
    }

    /// Type-check all items in a parsed program, updating the persistent env.
    pub fn check_line(&mut self, program: &crate::ast::Program) -> Result<(), LuxError> {
        // Register type/effect decls first
        for item in &program.items {
            match item {
                crate::ast::Item::TypeDecl(td) => {
                    self.env.register_type_decl(td).map_err(LuxError::Type)?
                }
                crate::ast::Item::EffectDecl(ed) => {
                    self.env.register_effect_decl(ed).map_err(LuxError::Type)?
                }
                _ => {}
            }
        }
        for item in &program.items {
            self.env.check_item(item).map_err(LuxError::Type)?;
        }
        Ok(())
    }

    /// Infer the type of a single expression and return it as a string.
    pub fn type_of_expr(&mut self, expr: &Expr) -> Result<String, LuxError> {
        let (ty, _effs) = self.env.infer_expr(expr).map_err(LuxError::Type)?;
        let resolved = self.env.apply_subst(&ty);
        Ok(format!("{resolved}"))
    }

    /// Look up the type of a named binding and return it as a string.
    pub fn effects_of(&self, name: &str) -> Option<String> {
        self.env.lookup(name).map(|ty| {
            let resolved = self.env.apply_subst(&ty);
            format!("{resolved}")
        })
    }
}

impl Default for ReplChecker {
    fn default() -> Self {
        Self::new()
    }
}
