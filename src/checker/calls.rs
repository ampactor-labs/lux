/// Function call inference, pattern checking, match, handle, and perform.
use std::collections::HashMap;

use crate::ast::{self, Expr, HandlerOp, LitPattern, MatchArm, Pattern};
use crate::error::{TypeError, TypeErrorKind};
use crate::token::Span;
use crate::types::{EffectRow, Type};

use super::{TypeEnv, type_name_from_type};

#[allow(clippy::result_large_err)]
impl TypeEnv {
    // ── Function calls ────────────────────────────────────────

    pub(crate) fn infer_call(
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

    pub(crate) fn infer_constructor_call(
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

        for ((_, field_ty), arg) in variant.fields.iter().zip(args) {
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

    // ── Match ─────────────────────────────────────────────────

    pub(crate) fn infer_match(
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

    // ── Pattern checking ──────────────────────────────────────

    pub(crate) fn check_pattern(
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

                for (field_pat, (_, field_ty)) in fields.iter().zip(variant.fields.iter()) {
                    self.check_pattern(field_pat, field_ty, pat_span)?;
                }
                Ok(())
            }
            Pattern::Record {
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

                // Resolve field names to types
                for (field_name, field_pat) in fields {
                    let field_ty = variant
                        .fields
                        .iter()
                        .find(|(n, _)| n == field_name)
                        .map(|(_, ty)| ty.clone())
                        .ok_or_else(|| TypeError {
                            kind: TypeErrorKind::UnboundVariable(format!(
                                "{}.{}",
                                name, field_name
                            )),
                            span: pat_span.clone(),
                        })?;
                    self.check_pattern(field_pat, &field_ty, pat_span)?;
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
            Pattern::List {
                elements,
                rest,
                span: pat_span,
            } => {
                let elem_ty = self.fresh_var();
                let list_ty = Type::List(Box::new(elem_ty.clone()));
                self.unify(expected_ty, &list_ty, pat_span)?;
                for elem_pat in elements {
                    self.check_pattern(elem_pat, &elem_ty, pat_span)?;
                }
                if let Some(rest_pat) = rest {
                    let rest_ty = Type::List(Box::new(elem_ty));
                    self.check_pattern(rest_pat, &rest_ty, pat_span)?;
                }
                Ok(())
            }
            Pattern::Or(alternatives, pat_span) => {
                for alt in alternatives {
                    self.check_pattern(alt, expected_ty, pat_span)?;
                }
                Ok(())
            }
        }
    }

    // ── Handle / Perform ──────────────────────────────────────

    pub(crate) fn infer_handle(
        &mut self,
        expr: &Expr,
        handlers: &[ast::HandlerClause],
        state_bindings: &[ast::StateBinding],
        span: &Span,
    ) -> Result<(Type, EffectRow), TypeError> {
        let (expr_ty, mut expr_effs) = self.infer_expr(expr)?;
        let result_ty = self.fresh_var();
        self.unify(&result_ty, &expr_ty, span)?;

        // Infer types for state bindings
        let mut state_types = HashMap::new();
        for binding in state_bindings {
            let (init_ty, _) = self.infer_expr(&binding.init)?;
            state_types.insert(binding.name.clone(), init_ty);
        }

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
                    child.handler_state_types = state_types.clone();

                    // Bind handler parameters
                    for (i, param_name) in params.iter().enumerate() {
                        let param_ty = op_info
                            .param_types
                            .get(i)
                            .cloned()
                            .unwrap_or_else(|| child.fresh_var());
                        child.bind(param_name, param_ty);
                    }

                    // Bind state variables in handler scope
                    for (name, ty) in &state_types {
                        child.bind(name, ty.clone());
                    }

                    // Bind `resume` as a callable function: (ReturnType) -> T
                    let resume_ret = child.fresh_var();
                    child.bind(
                        "resume",
                        Type::Function {
                            params: vec![op_info.return_type.clone()],
                            return_type: Box::new(resume_ret),
                            effects: EffectRow::pure(),
                        },
                    );

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

    pub(crate) fn infer_perform(
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
