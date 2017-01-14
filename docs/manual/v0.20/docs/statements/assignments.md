## Assignments

An assignment associates the statement or expression at the right side of the
symbol `=` with the location(s) at the left side:

```ceu
Set ::= (Loc | `(´ LIST(Loc|`_´) `)´) `=´ Cons

Cons ::= ( Do
         | Await
         | Emit_Ext
         | Watching
         | Async_Thread
         | Lua_State
         | Lua_Stmts
         | Code_Await
         | Code_Spawn
         | Vec_Cons
         | Data_Cons
         | `_´
         | Exp )

Vec_Cons ::= (Exp | `[´ [LIST(Exp)] `]´) { `..´ (Exp | Lua_Stmts | `[´ [LIST(Exp)] `]´) }
```

`TODO: links to Cons's`

`TODO: examples`

`TODO: vector constructor`

### Copy Assignment

A *copy assignment* evaluates the statement or expression at the right side and
copies the result(s) to the location(s) at the left side.

### Alias Assignment

An *alias assignment*, aka *binding*, makes the location at the left side to be
an [alias](#TODO) to the expression at the right side.

The right side of a binding is always prefixed by the operator `&`.
