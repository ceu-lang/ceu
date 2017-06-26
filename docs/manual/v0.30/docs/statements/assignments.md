## Assignments

An assignment associates the statement or expression at the right side of the
symbol `=` with the [location(s)](../storage_entities/#locations) at the left side:

```ceu
Assignment ::= (Loc | `(´ LIST(Loc|`_´) `)´) `=´ Sources

Sources ::= ( Do
            | Emit_Ext
            | Await
            | Watching
            | Thread
            | Lua_State
            | Lua_Stmts
            | Code_Await
            | Code_Spawn
            | Vec_Cons
            | Data_Cons
            | Exp
            | `_´ )
```

Céu supports the following constructs as assignment sources:

- [`do-end` block](#do-end-and-escape)
- [external emit](#events_1)
- [await](#await)
- [watching statement](#watching)
- [thread](#thread)
- [lua state](#lua-state)
- [lua statement](#lua-statement)
- [code await](#code-invocation)
- [code spawn](#code-invocation)
- vector [length](../expressions/#length) & [constructor](../expressions/#constructor)
- [data constructor](#data-constructor)
- [expression](../expressions/#locations-expressions)
- the neutral identifier `_`

The anonymous identifier makes the assignment innocuous.

`TODO: required for uninitialized variables`

### Copy Assignment

A *copy assignment* evaluates the statement or expression at the right side and
copies the result(s) to the location(s) at the left side.

### Alias Assignment

An *alias assignment*, aka *binding*, makes the location at the left side to be
an [alias](../storage_entities/#aliases) to the expression at the right side.

The right side of a binding is always prefixed by the operator `&`.
