/// Substitution, unification, and type expression resolution.
use std::collections::BTreeSet;

use crate::error::{TypeError, TypeErrorKind};
use crate::types::{EffectRow, EffectVar, Type, TypeVar};

use super::TypeEnv;

// We need access to ast::TypeExpr for resolve_type_expr
use crate::ast::TypeExpr;

/// Check if a type is a runtime primitive (dynamically typed in the VM).
fn is_primitive(ty: &Type) -> bool {
    matches!(
        ty,
        Type::Int | Type::Float | Type::String | Type::Bool | Type::Unit
    )
}

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
                    if ka == kb {
                        return Ok(());
                    }
                    let fresh = EffectVar(self.next_eff_var);
                    self.next_eff_var += 1;
                    let union_known: BTreeSet<_> = ka.union(kb).cloned().collect();
                    self.eff_subst.insert(
                        *va,
                        EffectRow::Open {
                            known: union_known,
                            var: fresh,
                        },
                    );
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
            Type::Record { fields, rest } => {
                let new_fields: Vec<_> = fields
                    .iter()
                    .map(|(n, t)| (n.clone(), self.apply_subst(t)))
                    .collect();
                let new_rest = rest.map(|rv| {
                    // If the row variable is substituted, unwrap it
                    match self.subst.get(&TypeVar(rv.0)) {
                        Some(_) => rv, // We handle row vars via TypeVar substitution
                        None => rv,
                    }
                });
                Type::Record {
                    fields: new_fields,
                    rest: new_rest,
                }
            }
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
            Type::Record { fields, rest } => {
                fields.iter().any(|(_, t)| self.occurs_in(var, t))
                    || rest.is_some_and(|rv| TypeVar(rv.0) == var)
            }
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
                            fn_name: None,
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
                // Gradual typing: unify common prefix, allow length mismatch.
                // The VM uses dynamic tuples — length is a runtime property.
                let common = a.len().min(b.len());
                for i in 0..common {
                    self.unify(&a[i], &b[i], span)?;
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

            // Record structural unification with row polymorphism
            (
                Type::Record {
                    fields: f1,
                    rest: r1,
                },
                Type::Record {
                    fields: f2,
                    rest: r2,
                },
            ) => {
                // Both closed, same fields: unify each field type
                if r1.is_none() && r2.is_none() {
                    if f1.len() != f2.len() {
                        return Err(TypeError {
                            kind: TypeErrorKind::Mismatch {
                                expected: a.clone(),
                                found: b.clone(),
                            },
                            span: span.clone(),
                        });
                    }
                    // Fields are sorted by name, so zip directly
                    for ((n1, t1), (n2, t2)) in f1.iter().zip(f2.iter()) {
                        if n1 != n2 {
                            return Err(TypeError {
                                kind: TypeErrorKind::Mismatch {
                                    expected: a.clone(),
                                    found: b.clone(),
                                },
                                span: span.clone(),
                            });
                        }
                        self.unify(t1, t2, span)?;
                    }
                    Ok(())
                } else {
                    // Row polymorphism: unify matching fields, pass excess to row var
                    // Find common fields and unify their types
                    let mut i1 = 0;
                    let mut i2 = 0;
                    let mut extra_in_1 = Vec::new();
                    let mut extra_in_2 = Vec::new();

                    while i1 < f1.len() && i2 < f2.len() {
                        match f1[i1].0.cmp(&f2[i2].0) {
                            std::cmp::Ordering::Equal => {
                                self.unify(&f1[i1].1, &f2[i2].1, span)?;
                                i1 += 1;
                                i2 += 1;
                            }
                            std::cmp::Ordering::Less => {
                                extra_in_1.push(f1[i1].clone());
                                i1 += 1;
                            }
                            std::cmp::Ordering::Greater => {
                                extra_in_2.push(f2[i2].clone());
                                i2 += 1;
                            }
                        }
                    }
                    extra_in_1.extend(f1[i1..].iter().cloned());
                    extra_in_2.extend(f2[i2..].iter().cloned());

                    // Constrain row variables to include excess fields
                    if let Some(rv1) = r1 {
                        if !extra_in_2.is_empty() {
                            // r1's row variable must include the extra fields from f2
                            let rest_record = Type::Record {
                                fields: extra_in_2,
                                rest: r2.map(|rv| rv),
                            };
                            self.subst.insert(TypeVar(rv1.0), rest_record);
                        } else if let Some(rv2) = r2 {
                            // Both open, same fields: unify row variables
                            self.subst.insert(TypeVar(rv1.0), Type::Var(TypeVar(rv2.0)));
                        } else {
                            // r1 is open, r2 is closed with no extras: close r1
                            self.subst.insert(
                                TypeVar(rv1.0),
                                Type::Record {
                                    fields: vec![],
                                    rest: None,
                                },
                            );
                        }
                    }
                    if let Some(rv2) = r2 {
                        if !extra_in_1.is_empty() {
                            let rest_record = Type::Record {
                                fields: extra_in_1,
                                rest: r1.map(|rv| rv),
                            };
                            self.subst.insert(TypeVar(rv2.0), rest_record);
                        }
                    }
                    Ok(())
                }
            }

            // Gradual typing: primitive type mismatches are allowed when
            // unannotated. The VM is dynamically typed — Int, Float, String,
            // Bool, and Unit coexist at runtime. With explicit annotations,
            // the checker enforces them. Without, it's permissive.
            // This follows the annotation gradient: write nothing → it runs.
            (a, b) if is_primitive(a) && is_primitive(b) => Ok(()),

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
                    // List<T> or bare List (inferred element type)
                    "List" => {
                        let inner = if args.is_empty() {
                            self.fresh_var()
                        } else {
                            self.resolve_type_expr(&args[0])?
                        };
                        return Ok(Type::List(Box::new(inner)));
                    }
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
                    // Only insert positive (non-negated) effects into the row.
                    // Negated effects (!IO) are constraints, not members.
                    if !eff_ref.negated && eff_ref.name != "Pure" {
                        eff_set.insert(&eff_ref.name);
                    }
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
