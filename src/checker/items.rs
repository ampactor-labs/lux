/// Item registration (first pass) and checking (second pass).
use crate::ast::{EffectDecl, FnDecl, ImplBlock, Item, LetDecl, TraitDecl, TypeDecl};
use crate::error::{TypeError, TypeErrorKind};
use crate::types::{AdtDef, EffectDef, EffectOpDef, EffectRow, Type, VariantDef};

use super::{OpInfo, TypeEnv, type_expr_to_name};

#[allow(clippy::result_large_err)]
impl TypeEnv {
    // ── Registration (first pass) ─────────────────────────────

    pub(crate) fn register_type_decl(&mut self, td: &TypeDecl) -> Result<(), TypeError> {
        let mut variants = Vec::new();
        for (i, v) in td.variants.iter().enumerate() {
            let fields: Vec<(String, Type)> = v
                .fields
                .iter()
                .enumerate()
                .map(|(idx, f)| {
                    let name = f.name.clone().unwrap_or_else(|| format!("_{idx}"));
                    let ty = self.resolve_type_expr(&f.ty).unwrap_or(Type::Error);
                    (name, ty)
                })
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

    pub(crate) fn register_effect_decl(&mut self, ed: &EffectDecl) -> Result<(), TypeError> {
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

    pub(crate) fn register_trait_decl(&mut self, td: &TraitDecl) -> Result<(), TypeError> {
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

    pub(crate) fn register_impl_block(&mut self, ib: &ImplBlock) -> Result<(), TypeError> {
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

    pub(crate) fn check_item(&mut self, item: &Item) -> Result<(), TypeError> {
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

    pub(crate) fn check_fn_decl(&mut self, fd: &FnDecl) -> Result<(), TypeError> {
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

    pub(crate) fn check_let_decl(&mut self, ld: &LetDecl) -> Result<(), TypeError> {
        let (val_ty, _effects) = self.infer_expr(&ld.value)?;

        if let Some(ann) = &ld.type_ann {
            let ann_ty = self.resolve_type_expr(ann)?;
            self.unify(&val_ty, &ann_ty, &ld.span)?;
        }

        self.bind(&ld.name, self.apply_subst(&val_ty));
        Ok(())
    }
}
