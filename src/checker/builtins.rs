/// Built-in type registrations for the Lux type checker.
use crate::types::{EffectRow, Type};

use super::TypeEnv;

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

        // to_string: (T) -> String with Alloc (creates new string)
        let t = self.fresh_var();
        self.bind(
            "to_string",
            Type::Function {
                params: vec![t],
                return_type: Box::new(Type::String),
                effects: EffectRow::single("Alloc"),
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

        // push: (List<T>, T) -> List<T> with Alloc (creates new list)
        let t = self.fresh_var();
        self.bind(
            "push",
            Type::Function {
                params: vec![Type::List(Box::new(t.clone())), t.clone()],
                return_type: Box::new(Type::List(Box::new(t))),
                effects: EffectRow::single("Alloc"),
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

        // range: (Int, Int) -> List<Int> with Alloc (creates new list)
        self.bind(
            "range",
            Type::Function {
                params: vec![Type::Int, Type::Int],
                return_type: Box::new(Type::List(Box::new(Type::Int))),
                effects: EffectRow::single("Alloc"),
            },
        );

        // NOTE: generate/next builtins removed — generators are now
        // implemented through the effect system. See examples/generators.lux.
        // yield() is an effect op, collection is a handler pattern.


        // String builtins
        self.bind(
            "split",
            Type::Function {
                params: vec![Type::String, Type::String],
                return_type: Box::new(Type::List(Box::new(Type::String))),
                effects: EffectRow::single("Alloc"),
            },
        );
        self.bind(
            "trim",
            Type::Function {
                params: vec![Type::String],
                return_type: Box::new(Type::String),
                effects: EffectRow::single("Alloc"),
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
                effects: EffectRow::single("Alloc"),
            },
        );
        self.bind(
            "chars",
            Type::Function {
                params: vec![Type::String],
                return_type: Box::new(Type::List(Box::new(Type::String))),
                effects: EffectRow::single("Alloc"),
            },
        );
        self.bind(
            "join",
            Type::Function {
                params: vec![Type::List(Box::new(Type::String)), Type::String],
                return_type: Box::new(Type::String),
                effects: EffectRow::single("Alloc"),
            },
        );
        // slice: (List<T>, Int, Int) -> List<T> with Alloc (creates new list)
        let t_slice = self.fresh_var();
        self.bind(
            "slice",
            Type::Function {
                params: vec![Type::List(Box::new(t_slice.clone())), Type::Int, Type::Int],
                return_type: Box::new(Type::List(Box::new(t_slice))),
                effects: EffectRow::single("Alloc"),
            },
        );
        // Numeric builtins
        let t_num = self.fresh_var();
        self.bind(
            "abs",
            Type::Function {
                params: vec![t_num.clone()],
                return_type: Box::new(t_num),
                effects: EffectRow::pure(),
            },
        );
        let t_min = self.fresh_var();
        self.bind(
            "min",
            Type::Function {
                params: vec![t_min.clone(), t_min.clone()],
                return_type: Box::new(t_min),
                effects: EffectRow::pure(),
            },
        );
        let t_max = self.fresh_var();
        self.bind(
            "max",
            Type::Function {
                params: vec![t_max.clone(), t_max.clone()],
                return_type: Box::new(t_max),
                effects: EffectRow::pure(),
            },
        );
        // clamp: (T, T, T) -> T
        let t_clamp = self.fresh_var();
        self.bind(
            "clamp",
            Type::Function {
                params: vec![t_clamp.clone(), t_clamp.clone(), t_clamp.clone()],
                return_type: Box::new(t_clamp),
                effects: EffectRow::pure(),
            },
        );
        // round: (Num) -> Int
        let t_round = self.fresh_var();
        self.bind(
            "round",
            Type::Function {
                params: vec![t_round],
                return_type: Box::new(Type::Int),
                effects: EffectRow::pure(),
            },
        );
        // atan2: (Float, Float) -> Float
        self.bind(
            "atan2",
            Type::Function {
                params: vec![Type::Float, Type::Float],
                return_type: Box::new(Type::Float),
                effects: EffectRow::pure(),
            },
        );
        // pi: () -> Float
        self.bind(
            "pi",
            Type::Function {
                params: vec![],
                return_type: Box::new(Type::Float),
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
        // sin: (Num) -> Float
        let t_sin = self.fresh_var();
        self.bind(
            "sin",
            Type::Function {
                params: vec![t_sin],
                return_type: Box::new(Type::Float),
                effects: EffectRow::pure(),
            },
        );
        // cos: (Num) -> Float
        let t_cos = self.fresh_var();
        self.bind(
            "cos",
            Type::Function {
                params: vec![t_cos],
                return_type: Box::new(Type::Float),
                effects: EffectRow::pure(),
            },
        );
        // tanh: (Num) -> Float
        let t_tanh = self.fresh_var();
        self.bind(
            "tanh",
            Type::Function {
                params: vec![t_tanh],
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

        // NOTE: Yield effect removed from builtins — generators declare their
        // own effects. See examples/generators.lux for the pattern.


        // ── Self-hosting builtins ────────────────────────────────

        // char_at: (String, Int) -> String
        self.bind(
            "char_at",
            Type::Function {
                params: vec![Type::String, Type::Int],
                return_type: Box::new(Type::String),
                effects: EffectRow::pure(),
            },
        );
        // char_code: (String) -> Int
        self.bind(
            "char_code",
            Type::Function {
                params: vec![Type::String],
                return_type: Box::new(Type::Int),
                effects: EffectRow::pure(),
            },
        );
        // from_char_code: (Int) -> String
        self.bind(
            "from_char_code",
            Type::Function {
                params: vec![Type::Int],
                return_type: Box::new(Type::String),
                effects: EffectRow::pure(),
            },
        );
        // ends_with: (String, String) -> Bool
        self.bind(
            "ends_with",
            Type::Function {
                params: vec![Type::String, Type::String],
                return_type: Box::new(Type::Bool),
                effects: EffectRow::pure(),
            },
        );
        // index_of: polymorphic (String, String) -> Int or (List<T>, T) -> Int
        let t_idx = self.fresh_var();
        self.bind(
            "index_of",
            Type::Function {
                params: vec![t_idx.clone(), t_idx],
                return_type: Box::new(Type::Int),
                effects: EffectRow::pure(),
            },
        );
        // string_slice: (String, Int, Int) -> String
        self.bind(
            "string_slice",
            Type::Function {
                params: vec![Type::String, Type::Int, Type::Int],
                return_type: Box::new(Type::String),
                effects: EffectRow::pure(),
            },
        );
        // parse_float: (String) -> Float
        self.bind(
            "parse_float",
            Type::Function {
                params: vec![Type::String],
                return_type: Box::new(Type::Float),
                effects: EffectRow::pure(),
            },
        );
        // to_int: (T) -> Int
        let t_to_int = self.fresh_var();
        self.bind(
            "to_int",
            Type::Function {
                params: vec![t_to_int],
                return_type: Box::new(Type::Int),
                effects: EffectRow::pure(),
            },
        );
        // type_of: (T) -> String
        let t_typeof = self.fresh_var();
        self.bind(
            "type_of",
            Type::Function {
                params: vec![t_typeof],
                return_type: Box::new(Type::String),
                effects: EffectRow::pure(),
            },
        );
        // to_upper: (String) -> String
        self.bind(
            "to_upper",
            Type::Function {
                params: vec![Type::String],
                return_type: Box::new(Type::String),
                effects: EffectRow::pure(),
            },
        );
        // to_lower: (String) -> String
        self.bind(
            "to_lower",
            Type::Function {
                params: vec![Type::String],
                return_type: Box::new(Type::String),
                effects: EffectRow::pure(),
            },
        );
        // is_number: (T) -> Bool
        let t_isnum = self.fresh_var();
        self.bind(
            "is_number",
            Type::Function {
                params: vec![t_isnum],
                return_type: Box::new(Type::Bool),
                effects: EffectRow::pure(),
            },
        );
    }
}
