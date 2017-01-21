## Assignments

An assignment associates the statement or expression at the right side of the
symbol `=` with the [location(s)](../storage_classes/#locations) at the left side:

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

- [`do-end` blocks](#do-end-and-escape)
- [external emits](#events_1)
- [awaits](#await)
- [watching statements](#watching)
- [threads](#thread)
- [lua states](#lua-state)
- [lua statements](#lua-statement)
- [code awaits](#code-invocation)
- [code spawns](#code-invocation)
- [vector constructors](../expressions/#constructor)
- [data constructors](#data-constructor)
- [expressions](../expressions/#locations-expressions)
- the neutral identifier `_`

The anonymous identifier makes the assignment innocuous.

`TODO: required for uninitialized variables`

### Copy Assignment

A *copy assignment* evaluates the statement or expression at the right side and
copies the result(s) to the location(s) at the left side.

### Alias Assignment

An *alias assignment*, aka *binding*, makes the location at the left side to be
an [alias](../storage_classes/#aliases) to the expression at the right side.

The right side of a binding is always prefixed by the operator `&`.
