//! Type checker with effect inference for Lux.
//!
//! Validates types using simplified Hindley-Milner inference and tracks
//! which algebraic effects each expression may perform.
//!
//! Split into submodules:
//! - `unify` — substitution, unification, type resolution
//! - `builtins` — built-in type registrations
//! - `items` — item registration and checking (fn, type, effect, trait, impl)
//! - `exprs` — expression type inference
//! - `calls` — call inference, pattern checking, handle/perform
mod builtins;
mod calls;
mod exprs;
mod items;
mod unify;

use std::collections::HashMap;

use crate::ast::{Expr, Item, Program, TypeExpr};
use crate::error::LuxError;
use crate::types::{AdtDef, EffectDef, EffectRow, EffectVar, Type, TypeVar};
use std::collections::BTreeSet;

// ── Helpers ───────────────────────────────────────────────────

/// Convert a TypeExpr to a canonical type name string for impl dispatch.
pub(crate) fn type_expr_to_name(te: &TypeExpr) -> String {
    match te {
        TypeExpr::Named { name, .. } => name.clone(),
        TypeExpr::List(_, _) => "List".to_string(),
        TypeExpr::Tuple(_, _) => "Tuple".to_string(),
        TypeExpr::Function { .. } => "Function".to_string(),
        TypeExpr::Inferred(_) => "_".to_string(),
    }
}

/// Convert a resolved Type to a canonical type name string for impl dispatch.
pub(crate) fn type_name_from_type(ty: &Type) -> String {
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
pub(crate) struct OpInfo {
    pub(crate) effect_name: String,
    pub(crate) param_types: Vec<Type>,
    pub(crate) return_type: Type,
}

pub(crate) struct TypeEnv {
    /// Variable name -> Type
    pub(crate) bindings: HashMap<String, Type>,
    /// Effect name -> EffectDef
    pub(crate) effects: HashMap<String, EffectDef>,
    /// ADT name -> AdtDef
    pub(crate) adts: HashMap<String, AdtDef>,
    /// Variant name -> (ADT name, variant index)
    pub(crate) constructors: HashMap<String, (String, usize)>,
    /// Effect operation name -> info
    pub(crate) op_index: HashMap<String, OpInfo>,
    /// Substitution map for type variables
    pub(crate) subst: HashMap<TypeVar, Type>,
    /// Type variable counter
    pub(crate) next_var: u32,
    /// Substitution map for effect row variables
    pub(crate) eff_subst: HashMap<EffectVar, EffectRow>,
    /// Effect row variable counter
    pub(crate) next_eff_var: u32,
    /// Whether we're currently inside a handler body (for Resume checking)
    pub(crate) in_handler: bool,
    /// Expected resume type when inside a handler
    pub(crate) resume_type: Option<Type>,
    /// Types of handler state bindings (for Resume state update checking)
    pub(crate) handler_state_types: HashMap<String, Type>,
    /// Parent scope (for scoped bindings)
    pub(crate) parent: Option<Box<TypeEnv>>,
    /// Registered traits: trait_name -> list of (method_name, param_types, return_type)
    pub(crate) traits: HashMap<String, Vec<(String, Vec<Type>, Type)>>,
    /// Impl methods: (type_name, method_name) -> function type
    pub(crate) impl_methods: HashMap<(String, String), Type>,
    /// Type parameters in scope (name -> Type::Var)
    pub(crate) type_params: HashMap<String, Type>,
}

#[allow(clippy::result_large_err)]
impl TypeEnv {
    pub(crate) fn new() -> Self {
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
            handler_state_types: HashMap::new(),
            parent: None,
            traits: HashMap::new(),
            impl_methods: HashMap::new(),
        }
    }

    /// Create a child scope that inherits all registries from the parent.
    pub(crate) fn child(&self) -> Self {
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
            handler_state_types: self.handler_state_types.clone(),
            parent: None,
            traits: self.traits.clone(),
            impl_methods: self.impl_methods.clone(),
            type_params: self.type_params.clone(),
        }
    }

    /// Merge child scope state back (substitutions, next_var).
    pub(crate) fn merge_child(&mut self, child: &TypeEnv) {
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

    pub(crate) fn fresh_var(&mut self) -> Type {
        let v = TypeVar(self.next_var);
        self.next_var += 1;
        Type::Var(v)
    }

    pub(crate) fn fresh_eff_var(&mut self) -> EffectRow {
        let var = EffectVar(self.next_eff_var);
        self.next_eff_var += 1;
        EffectRow::Open {
            known: BTreeSet::new(),
            var,
        }
    }

    /// Create a fresh instantiation of a type — replaces all unresolved Type::Var with new fresh vars.
    /// Used to instantiate polymorphic function types at each call site.
    pub(crate) fn instantiate(&mut self, ty: &Type) -> Type {
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

    pub(crate) fn bind(&mut self, name: impl Into<String>, ty: Type) {
        self.bindings.insert(name.into(), ty);
    }

    pub(crate) fn lookup(&self, name: &str) -> Option<Type> {
        if let Some(ty) = self.bindings.get(name) {
            return Some(self.apply_subst(ty));
        }
        if let Some(parent) = &self.parent {
            return parent.lookup(name);
        }
        None
    }

    #[allow(dead_code)]
    pub(crate) fn lookup_effect(&self, name: &str) -> Option<&EffectDef> {
        if let Some(def) = self.effects.get(name) {
            return Some(def);
        }
        if let Some(parent) = &self.parent {
            return parent.lookup_effect(name);
        }
        None
    }

    pub(crate) fn lookup_adt(&self, name: &str) -> Option<&AdtDef> {
        if let Some(def) = self.adts.get(name) {
            return Some(def);
        }
        if let Some(parent) = &self.parent {
            return parent.lookup_adt(name);
        }
        None
    }

    pub(crate) fn lookup_constructor(&self, name: &str) -> Option<(String, usize)> {
        if let Some(info) = self.constructors.get(name) {
            return Some(info.clone());
        }
        if let Some(parent) = &self.parent {
            return parent.lookup_constructor(name);
        }
        None
    }

    pub(crate) fn lookup_op(&self, name: &str) -> Option<OpInfo> {
        if let Some(info) = self.op_index.get(name) {
            return Some(info.clone());
        }
        if let Some(parent) = &self.parent {
            return parent.lookup_op(name);
        }
        None
    }

    pub(crate) fn is_in_handler(&self) -> bool {
        if self.in_handler {
            return true;
        }
        if let Some(parent) = &self.parent {
            return parent.is_in_handler();
        }
        false
    }

    pub(crate) fn get_resume_type(&self) -> Option<Type> {
        if let Some(ty) = &self.resume_type {
            return Some(ty.clone());
        }
        if let Some(parent) = &self.parent {
            return parent.get_resume_type();
        }
        None
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

    /// Apply all pending substitutions to every binding, then clear the
    /// substitution maps. This "freezes" the current type state so that
    /// subsequent `check_line` calls don't need to walk accumulated
    /// substitution chains from prior checks.
    ///
    /// Call this after loading trusted prelude code to prevent the prelude's
    /// type variables from slowing down user code type-checking.
    pub fn freeze(&mut self) {
        let resolved_bindings: Vec<(String, Type)> = self
            .env
            .bindings
            .iter()
            .map(|(name, ty)| (name.clone(), self.env.apply_subst(ty)))
            .collect();
        for (name, ty) in resolved_bindings {
            self.env.bindings.insert(name, ty);
        }
        self.env.subst.clear();
        self.env.eff_subst.clear();
    }
}

impl Default for ReplChecker {
    fn default() -> Self {
        Self::new()
    }
}
