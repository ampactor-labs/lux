---
description: how to extend the self-hosted compiler (std/compiler/)
---
// turbo-all

## Self-Hosted Compiler Architecture

```
std/compiler/lexer.lux    → Token ADTs (Ident, Number, String, Symbol, etc.)
std/compiler/parser.lux   → AST ADTs (Expr, Stmt) via recursive descent
std/compiler/checker.lux  → HM type inference (Ty, Subst, unification)
std/compiler/codegen.lux  → Bytecode emission (opcode-compatible with Rust VM)
```

## Current Capabilities

### Lexer (lexer.lux)
- Identifiers, integers, floats, strings
- Operators (+, -, *, /, ==, !=, <, >, <=, >=, ++, |>)
- Keywords (let, fn, if, else, match, true, false, import, effect, handle, type)
- Symbols (parens, braces, brackets, comma, =, =>, |, ::, ..)

### Parser (parser.lux)
- Expressions: literals, variables, binary ops, unary ops, if/else, match, lists, tuples, blocks, pipes, lambda, call, index
- Statements: let bindings, fn declarations, expression statements, imports
- Types: LetStmt, FnStmt, ExprStmt, ImportStmt + all Expr variants as ADTs

### Checker (checker.lux)
- HM type inference with unification and occurs check
- Types: TInt, TFloat, TString, TBool, TUnit, TFun, TList, TVar
- Environment: association list with lookup
- Substitution: composition and application
- Infers: Int, String, Bool, List<T>, function types

### Codegen (codegen.lux)
- Bytecode emission for: literals, vars (local/global), binops, unary, if/else, blocks, let, fn, call, pipe, list, tuple
- Scope tracking (locals with depth, declare/resolve)
- Jump patching (forward jumps for if/else, short-circuit and/or)
- Full disassembler
- NOT YET: upvalue capture, match compilation, effect handlers, string interpolation

## Development Pattern

1. **Test with a .lux file first**: Write your test in `examples/` using `import compiler/<module>`
2. **Run with --no-check**: `cargo run --quiet -- --no-check examples/<test>.lux`
3. **Errors go to stderr**: Use `2>/dev/null` for clean stdout, `2>&1` to see errors
4. **Thread state through context**: All compiler passes use the `(code, constants, names, locals, depth, slot)` tuple threading pattern
5. **Use ADTs for everything**: Token, Expr, Stmt, Ty — all ADT types declared in each module

## Key Opcode Numbers (must match src/vm/opcode.rs)
```
LoadConst=0, LoadInt=1, LoadBool=2, LoadUnit=3
LoadLocal=10, StoreLocal=11, LoadUpval=12
LoadGlobal=20, StoreGlobal=21
Add=30, Sub=31, Mul=32, Div=33, Mod=34, Neg=35, Not=36
Eq=40, Neq=41, Lt=42, LtEq=43, Gt=44, GtEq=45
Concat=50
Jump=60, JumpIfFalse=61, JumpIfTrue=62, Pop=63, Dup=64
MakeClosure=70, Call=71, Return=72, TailCall=73
MakeList=80, MakeTuple=81, ListIndex=82, MakeVariant=84
```
