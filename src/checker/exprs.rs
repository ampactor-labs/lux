/// Expression type inference: the main infer_expr dispatch and binary/unary ops.
use crate::ast::{BinOp, Expr, Stmt, StringPart, UnaryOp};
use crate::error::{TypeError, TypeErrorKind};
use crate::token::Span;
use crate::types::{EffectRow, Type};

use super::{levenshtein, TypeEnv};

#[allow(clippy::result_large_err)]
impl TypeEnv {
    pub(crate) fn infer_expr(&mut self, expr: &Expr) -> Result<(Type, EffectRow), TypeError> {
        match expr {
            Expr::IntLit(_, _) => Ok((Type::Int, EffectRow::pure())),
            Expr::FloatLit(_, _) => Ok((Type::Float, EffectRow::pure())),
            Expr::StringLit(_, _) => Ok((Type::String, EffectRow::pure())),
            Expr::BoolLit(_, _) => Ok((Type::Bool, EffectRow::pure())),

            Expr::Var(name, span) => {
                // Check if it's an effect operation — treat as Perform with 0 args
                if let Some(op_info) = self.lookup_op(name) {
                    if self.should_dispatch_as_op(name, &op_info) {
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
                        let param_types: Vec<Type> =
                            variant.fields.iter().map(|(_, ty)| ty.clone()).collect();
                        return Ok((
                            Type::Function {
                                params: param_types,
                                return_type: Box::new(ret_ty),
                                effects: EffectRow::pure(),
                            },
                            EffectRow::pure(),
                        ));
                    }
                }

                match self.lookup(name) {
                    Some(ty) => {
                        // If this variable is a function with concrete named effects,
                        // record them in effect_routing so the compiler can emit
                        // BundleEvidence when the function is passed as a value to
                        // higher-order functions. Skip open rows with only row
                        // variables (from pre-registered mutual recursion) — these
                        // have no concrete evidence to bundle.
                        if let Type::Function { effects, .. } = &ty {
                            if !effects.effects().is_empty() {
                                self.effect_routing
                                    .insert(span.clone(), effects.clone());
                            }
                        }
                        Ok((ty, EffectRow::pure()))
                    }
                    None => {
                        // Find the closest match for "did you mean?" suggestions
                        let suggestion = self.find_similar_name(name);
                        Err(TypeError {
                            kind: TypeErrorKind::UnboundVariable { name: name.clone(), suggestion },
                            span: span.clone(),
                        })
                    }
                }
            }

            Expr::List(elems, span) => {
                let elem_ty = self.fresh_var();
                // List literals allocate — emit Alloc effect
                let mut effs = EffectRow::single("Alloc");
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
                span,
            } => {
                let (obj_ty, effs) = self.infer_expr(object)?;
                let obj_ty = self.apply_subst(&obj_ty);

                // Structural record field access — the Lux way
                if let Type::Record { fields, rest: _ } = &obj_ty {
                    if let Some((_, field_ty)) = fields.iter().find(|(n, _)| n == field) {
                        return Ok((field_ty.clone(), effs));
                    }
                    return Err(TypeError {
                        kind: TypeErrorKind::UnboundVariable {
                            name: format!(".{field}"),
                            suggestion: fields.iter().min_by_key(|(n, _)| {
                                let d = levenshtein(field, n);
                                if d <= 2 { d } else { usize::MAX }
                            }).map(|(n, _)| n.clone()),
                        },
                        span: span.clone(),
                    }.into());
                }

                // Tuple element by index (legacy)
                if let Type::Tuple(elems) = &obj_ty {
                    if let Ok(idx) = field.parse::<usize>() {
                        if idx < elems.len() {
                            return Ok((elems[idx].clone(), effs));
                        }
                    }
                }

                // Unknown field access — fresh var (fallback for ADT field access)
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
                pattern,
                type_ann,
                value,
                span,
            } => {
                let (val_ty, effs) = self.infer_expr(value)?;
                if let Some(ann) = type_ann {
                    let ann_ty = self.resolve_type_expr(ann)?;
                    self.unify(&val_ty, &ann_ty, span)?;
                }
                self.bind_pattern_types(pattern, &self.apply_subst(&val_ty), span)?;
                Ok((Type::Unit, effs))
            }

            Expr::Pipe { left, right, span } => {
                // a |> f(b, c) desugars to f(a, b, c) — pipe value inserted as first arg
                // a |> f desugars to f(a)
                if let Expr::Call { func, args, .. } = right.as_ref() {
                    let mut combined_args = vec![left.as_ref().clone()];
                    combined_args.extend(args.iter().cloned());
                    self.infer_call(func, &combined_args, span)
                } else {
                    self.infer_call(right, std::slice::from_ref(left.as_ref()), span)
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
                state_bindings,
                span,
            } => self.infer_handle(expr, handlers, state_bindings, span),

            Expr::Resume {
                value,
                state_updates,
                span,
            } => {
                if !self.is_in_handler() {
                    return Err(TypeError {
                        kind: TypeErrorKind::UnboundVariable { name: "resume".into(), suggestion: None },
                        span: span.clone(),
                    });
                }
                let (val_ty, mut effs) = self.infer_expr(value)?;
                if let Some(expected) = self.get_resume_type() {
                    self.unify(&val_ty, &expected, span)?;
                }
                // Type-check state updates
                for su in state_updates {
                    let declared_ty =
                        self.handler_state_types
                            .get(&su.name)
                            .cloned()
                            .ok_or_else(|| TypeError {
                                kind: TypeErrorKind::UnboundStateVar(su.name.clone()),
                                span: su.span.clone(),
                            })?;
                    let (update_ty, update_effs) = self.infer_expr(&su.value)?;
                    self.unify(&update_ty, &declared_ty, &su.span)?;
                    effs = effs.union(&update_effs);
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

            Expr::Assert {
                condition,
                message,
                span,
            } => {
                let (cond_ty, effs1) = self.infer_expr(condition)?;
                self.unify(&cond_ty, &Type::Bool, span)?;
                let (msg_ty, effs2) = self.infer_expr(message)?;
                self.unify(&msg_ty, &Type::String, span)?;
                Ok((Type::Unit, effs1.union(&effs2)))
            }

            // ── Anonymous record literal ──────────────────────────
            Expr::RecordLit { fields, span: _ } => {
                let mut field_types: Vec<(String, Type)> = Vec::new();
                let mut effs = EffectRow::pure();
                for (name, expr) in fields {
                    let (ty, eff) = self.infer_expr(expr)?;
                    field_types.push((name.clone(), ty));
                    effs = effs.union(&eff);
                }
                // Sort fields by name — canonical order for structural equality
                // { y: Int, x: Int } and { x: Int, y: Int } are the same type
                field_types.sort_by(|(a, _), (b, _)| a.cmp(b));
                Ok((Type::Record { fields: field_types, rest: None }, effs))
            }

            Expr::RecordConstruct {
                name,
                fields: named_fields,
                span,
            } => {
                // Look up the variant constructor
                let (adt_name, idx) = self.lookup_constructor(name).ok_or_else(|| TypeError {
                    kind: TypeErrorKind::UnboundVariable { name: name.clone(), suggestion: None },
                    span: span.clone(),
                })?;
                let adt_def = self
                    .lookup_adt(&adt_name)
                    .cloned()
                    .ok_or_else(|| TypeError {
                        kind: TypeErrorKind::UnboundType(adt_name.clone()),
                        span: span.clone(),
                    })?;
                let variant = &adt_def.variants[idx];
                let type_args: Vec<Type> = adt_def
                    .type_params
                    .iter()
                    .map(|_| self.fresh_var())
                    .collect();

                let mut effs = EffectRow::pure();
                // Type check each named field
                for (field_name, field_expr) in named_fields {
                    let field_ty = variant
                        .fields
                        .iter()
                        .find(|(n, _)| n == field_name)
                        .map(|(_, ty)| ty.clone())
                        .ok_or_else(|| TypeError {
                            kind: TypeErrorKind::UnboundVariable {
                                name: format!("{}.{}", name, field_name),
                                suggestion: None,
                            },
                            span: span.clone(),
                        })?;
                    let (arg_ty, eff) = self.infer_expr(field_expr)?;
                    self.unify(&field_ty, &arg_ty, span)?;
                    effs = effs.union(&eff);
                }

                Ok((
                    Type::Adt {
                        name: adt_name,
                        type_args,
                    },
                    effs,
                ))
            }
        }
    }

    // ── Binary operations ─────────────────────────────────────

    pub(crate) fn infer_binop(
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
                        // Don't default — let context determine the numeric type
                        Ok((resolved, effs))
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

            // Concat: String or List — allocates new heap object
            BinOp::Concat => {
                self.unify(&l_ty, &r_ty, span)?;
                let resolved = self.apply_subst(&l_ty);
                // Concat allocates: new string or new list
                let effs = effs.union(&EffectRow::single("Alloc"));
                match &resolved {
                    Type::String | Type::List(_) => Ok((resolved, effs)),
                    Type::Var(_) => {
                        // Keep as type variable — will be resolved when more
                        // context is available (e.g. multi-shot resume returns List)
                        Ok((resolved, effs))
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

    pub(crate) fn infer_unaryop(
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
                    Type::Var(_) => Ok((resolved, effs)),
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

    // ── Block ─────────────────────────────────────────────────

    pub(crate) fn infer_block(
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
                    child.bind_pattern_types(&ld.pattern, &child.apply_subst(&val_ty), &ld.span)?;
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
}
