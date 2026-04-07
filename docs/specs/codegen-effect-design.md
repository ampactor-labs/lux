# CodegenCtx Effect — Design Spec

> The codegen threads a 10-tuple through every function. That's a manually-encoded effect.
> This spec defines the effect that replaces it.

## Current State

```lux
// Context: (code, constants, names, locals, depth, next_slot, upvalues, enclosing, effect_ops, handler_tables)
fn ctx_new() = ([], [], [], [], 0, 0, [], [], [], [])
```

Every compile function takes `ctx` as first param, returns modified `ctx`:
```lux
fn compile_expr(ctx, expr) = match expr {
  IntLit(n) => {
    let (ctx2, idx) = add_constant(ctx, ConstInt(n))
    emit_u16(emit_op(ctx2, OP_LOAD_CONST), idx)
  },
  ...
}
```

## Target State

```lux
effect Codegen {
  cg_emit(Int) -> ()           // append byte to code buffer
  cg_const(value) -> Int       // add constant, return index
  cg_name(String) -> Int       // intern name, return index
  cg_scope_begin() -> ()       // push scope
  cg_scope_end() -> Int        // pop scope, return pop count
  cg_local(String) -> Int      // push local, return slot
  cg_resolve(String) -> Int    // find local slot (-1 if not found)
  cg_upval(Bool, Int) -> Int   // push upvalue, return index
  cg_handler_table(List) -> Int // register handler table
  cg_effect_ops() -> List      // get effect op registry
  cg_code_len() -> Int         // current code buffer length
}
```

Every compile function drops `ctx`, uses effect operations:
```lux
fn compile_expr(expr) = match expr {
  IntLit(n) => {
    let idx = cg_const(ConstInt(n))
    cg_emit(OP_LOAD_CONST)
    cg_emit(idx / 256)
    cg_emit(idx - (idx / 256) * 256)
  },
  ...
}
```

## Handler

```lux
fn compile_program(stmts) = {
  handle {
    compile_stmts(stmts)
    cg_finish()  // returns the FnProto
  } with state = ctx_new() {
    cg_emit(byte) => {
      let (code, co, na, lo, de, sl, uv, enc, eo, ht) = state
      resume(()) with state = (push(code, byte), co, na, lo, de, sl, uv, enc, eo, ht)
    },
    cg_const(val) => {
      let (code, co, na, lo, de, sl, uv, enc, eo, ht) = state
      let idx = len(co)
      resume(idx) with state = (code, push(co, val), na, lo, de, sl, uv, enc, eo, ht)
    },
    ...
  }
}
```

## Child Contexts (Lambda/Fn Bodies)

Nested handlers for child compilation:
```lux
fn compile_lambda(name, params, body) = {
  let proto = handle {
    setup_params(params)
    compile_block(body)
    build_proto(name, params)
  } with child = ctx_child_from_current() {
    // Child handler shadows parent — all cg_* operations go to child
    cg_emit(byte) => { ... modify child ... resume(()) },
    ...
  }
  let idx = cg_const(ConstFnProto(proto))
  cg_emit(OP_MAKE_CLOSURE)
  cg_emit(idx / 256)
  cg_emit(idx - (idx / 256) * 256)
}
```

## Transformation Rules

| Before | After |
|--------|-------|
| `emit_op(ctx, op)` | `cg_emit(op)` |
| `emit_u8(ctx, v)` | `cg_emit(v)` |
| `emit_u16(ctx, v)` | `cg_emit(v / 256); cg_emit(v - (v/256)*256)` |
| `let (ctx2, idx) = add_constant(ctx, v)` | `let idx = cg_const(v)` |
| `let (ctx2, idx) = intern_name(ctx, n)` | `let idx = cg_name(n)` |
| `let ctx2 = begin_scope(ctx)` | `cg_scope_begin()` |
| `let (ctx2, pops) = end_scope(ctx)` | `let pops = cg_scope_end()` |
| `fn compile_expr(ctx, expr)` | `fn compile_expr(expr)` |

## Why This Is Right

1. **The info flows through effects.** The bytecode buffer, constant pool, name table —
   all flow through Codegen operations. No manual tuple threading.
2. **Handlers observe.** A debugging handler could log every emitted byte.
   An optimization handler could peephole-optimize.
3. **Children nest naturally.** Lambda compilation = nested handler.
   The parent's Codegen is shadowed, not threaded.
4. **The gradient applies.** Users who write `with Pure` mean it.
   `Codegen` is an effect — the compiler tracks it.

## Implementation Order

1. Define the effect (5 min)
2. Create the handler in compile_program (30 min)
3. Transform emit_byte/emit_op/emit_u16/add_constant/intern_name (30 min)
4. Transform scope operations (20 min)
5. Transform compile_expr and all compile_* functions (2 hours)
6. Handle child contexts for lambda/fn compilation (1 hour)
7. Test against all golden files
