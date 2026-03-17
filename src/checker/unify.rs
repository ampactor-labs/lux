/// Substitution, unification, and type expression resolution.
use std::collections::BTreeSet;

use crate::error::{TypeError, TypeErrorKind};
use crate::types::{EffectRow, EffectVar, Type, TypeVar};

use super::TypeEnv;

// We need access to ast::TypeExpr for resolve_type_expr
use crate::ast::TypeExpr;

#[allow(clippy::result_large_err)]
impl TypeEnv {
    // ── Effect substitution ──────────────────────────────────

    #[allow(dead_code)]
    pub(crate) fn apply_eff_subst(&self, row: &EffectRow) -> EffectRow {
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
    pub(crate) fn unify_effects(
        &mut self,
        a: &EffectRow,
        b: &EffectRow,
        _span: &crate::token::Span,
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

    // ── Type substitution ────────────────────────────────────

    pub(crate) fn apply_subst(&self, ty: &Type) -> Type {
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

    pub(crate) fn occurs_in(&self, var: TypeVar, ty: &Type) -> bool {
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

    pub(crate) fn unify(
        &mut self,
        a: &Type,
        b: &Type,
        span: &crate::token::Span,
    ) -> Result<(), TypeError> {
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

    pub(crate) fn resolve_type_expr(&mut self, te: &TypeExpr) -> Result<Type, TypeError> {
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
}
