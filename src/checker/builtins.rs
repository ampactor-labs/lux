/// Built-in type registrations for the Lux type checker.
use crate::types::{EffectDef, EffectOpDef, EffectRow, Type};

use super::{OpInfo, TypeEnv};

#[allow(clippy::result_large_err)]
impl TypeEnv {
    pub(crate) fn populate_builtins(&mut self) {
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

        // next: (Generator) -> T
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

        // String builtins
        self.bind(
            "split",
            Type::Function {
                params: vec![Type::String, Type::String],
                return_type: Box::new(Type::List(Box::new(Type::String))),
                effects: EffectRow::pure(),
            },
        );
        self.bind(
            "trim",
            Type::Function {
                params: vec![Type::String],
                return_type: Box::new(Type::String),
                effects: EffectRow::pure(),
            },
        );
        // contains: polymorphic — works on strings and lists
        let t_contains = self.fresh_var();
        self.bind(
            "contains",
            Type::Function {
                params: vec![t_contains.clone(), t_contains],
                return_type: Box::new(Type::Bool),
                effects: EffectRow::pure(),
            },
        );
        self.bind(
            "starts_with",
            Type::Function {
                params: vec![Type::String, Type::String],
                return_type: Box::new(Type::Bool),
                effects: EffectRow::pure(),
            },
        );
        self.bind(
            "replace",
            Type::Function {
                params: vec![Type::String, Type::String, Type::String],
                return_type: Box::new(Type::String),
                effects: EffectRow::pure(),
            },
        );
        self.bind(
            "chars",
            Type::Function {
                params: vec![Type::String],
                return_type: Box::new(Type::List(Box::new(Type::String))),
                effects: EffectRow::pure(),
            },
        );
        self.bind(
            "join",
            Type::Function {
                params: vec![Type::List(Box::new(Type::String)), Type::String],
                return_type: Box::new(Type::String),
                effects: EffectRow::pure(),
            },
        );
        // slice: (List<T>, Int, Int) -> List<T>
        let t_slice = self.fresh_var();
        self.bind(
            "slice",
            Type::Function {
                params: vec![Type::List(Box::new(t_slice.clone())), Type::Int, Type::Int],
                return_type: Box::new(Type::List(Box::new(t_slice))),
                effects: EffectRow::pure(),
            },
        );
        // Numeric builtins
        let t_num = self.fresh_var();
        self.bind(
            "abs",
            Type::Function {
                params: vec![t_num],
                return_type: Box::new(Type::Int),
                effects: EffectRow::pure(),
            },
        );
        self.bind(
            "min",
            Type::Function {
                params: vec![Type::Int, Type::Int],
                return_type: Box::new(Type::Int),
                effects: EffectRow::pure(),
            },
        );
        self.bind(
            "max",
            Type::Function {
                params: vec![Type::Int, Type::Int],
                return_type: Box::new(Type::Int),
                effects: EffectRow::pure(),
            },
        );
        let t_num2 = self.fresh_var();
        self.bind(
            "floor",
            Type::Function {
                params: vec![t_num2],
                return_type: Box::new(Type::Int),
                effects: EffectRow::pure(),
            },
        );
        let t_num3 = self.fresh_var();
        self.bind(
            "ceil",
            Type::Function {
                params: vec![t_num3],
                return_type: Box::new(Type::Int),
                effects: EffectRow::pure(),
            },
        );

        // sqrt: (Num) -> Float
        let t_sqrt = self.fresh_var();
        self.bind(
            "sqrt",
            Type::Function {
                params: vec![t_sqrt],
                return_type: Box::new(Type::Float),
                effects: EffectRow::pure(),
            },
        );
        // exp: (Num) -> Float
        let t_exp = self.fresh_var();
        self.bind(
            "exp",
            Type::Function {
                params: vec![t_exp],
                return_type: Box::new(Type::Float),
                effects: EffectRow::pure(),
            },
        );
        // log: (Num) -> Float
        let t_log = self.fresh_var();
        self.bind(
            "log",
            Type::Function {
                params: vec![t_log],
                return_type: Box::new(Type::Float),
                effects: EffectRow::pure(),
            },
        );
        // pow: (Num, Num) -> Float
        let t_pow1 = self.fresh_var();
        let t_pow2 = self.fresh_var();
        self.bind(
            "pow",
            Type::Function {
                params: vec![t_pow1, t_pow2],
                return_type: Box::new(Type::Float),
                effects: EffectRow::pure(),
            },
        );
        // to_float: (Num) -> Float
        let t_tf = self.fresh_var();
        self.bind(
            "to_float",
            Type::Function {
                params: vec![t_tf],
                return_type: Box::new(Type::Float),
                effects: EffectRow::pure(),
            },
        );

        // sort: (List<T>) -> List<T>
        let t_sort = self.fresh_var();
        self.bind(
            "sort",
            Type::Function {
                params: vec![Type::List(Box::new(t_sort.clone()))],
                return_type: Box::new(Type::List(Box::new(t_sort))),
                effects: EffectRow::pure(),
            },
        );
        // zip: (List<A>, List<B>) -> List<(A, B)>
        let t_a = self.fresh_var();
        let t_b = self.fresh_var();
        self.bind(
            "zip",
            Type::Function {
                params: vec![
                    Type::List(Box::new(t_a.clone())),
                    Type::List(Box::new(t_b.clone())),
                ],
                return_type: Box::new(Type::List(Box::new(Type::Tuple(vec![t_a, t_b])))),
                effects: EffectRow::pure(),
            },
        );
        // enumerate: (List<T>) -> List<(Int, T)>
        let t_enum = self.fresh_var();
        self.bind(
            "enumerate",
            Type::Function {
                params: vec![Type::List(Box::new(t_enum.clone()))],
                return_type: Box::new(Type::List(Box::new(Type::Tuple(vec![Type::Int, t_enum])))),
                effects: EffectRow::pure(),
            },
        );
        // find: (List<T>, (T) -> Bool) -> Option<T>
        let t_find = self.fresh_var();
        self.bind(
            "find",
            Type::Function {
                params: vec![
                    Type::List(Box::new(t_find.clone())),
                    Type::Function {
                        params: vec![t_find.clone()],
                        return_type: Box::new(Type::Bool),
                        effects: EffectRow::pure(),
                    },
                ],
                return_type: Box::new(t_find),
                effects: EffectRow::pure(),
            },
        );
        // string_length: (String) -> Int
        self.bind(
            "string_length",
            Type::Function {
                params: vec![Type::String],
                return_type: Box::new(Type::Int),
                effects: EffectRow::pure(),
            },
        );
        // string_contains: (String, String) -> Bool
        self.bind(
            "string_contains",
            Type::Function {
                params: vec![Type::String, Type::String],
                return_type: Box::new(Type::Bool),
                effects: EffectRow::pure(),
            },
        );
        // string_split: (String, String) -> List<String>
        self.bind(
            "string_split",
            Type::Function {
                params: vec![Type::String, Type::String],
                return_type: Box::new(Type::List(Box::new(Type::String))),
                effects: EffectRow::pure(),
            },
        );
        // string_trim: (String) -> String
        self.bind(
            "string_trim",
            Type::Function {
                params: vec![Type::String],
                return_type: Box::new(Type::String),
                effects: EffectRow::pure(),
            },
        );

        // Builtin Yield effect: yield(T) -> ()
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
}
