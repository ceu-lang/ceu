## Assignments

An assignment associates the statement or expression at the right side of `=`
with the location(s) at the left side:

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
```

### Copy Assignment

A *copy assignment* evaluates the statement or expression at the right side and
copies the result(s) to the location(s).

### Alias Assignment

An *alias assignment* makes the location at the left side to be a synonym to
the expression at the right side.
