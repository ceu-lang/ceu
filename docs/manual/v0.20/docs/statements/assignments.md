## Assignments

An assignment associates the statement or expression at the right side of the
symbol `=` with the [location(s)](#TODO) at the left side:

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

- [`do-end` blocks](#TODO)
- [external emits](#TODO)
- [awaits](#TODO)
- [watching statements](#TODO)
- [threads](#TODO)
- [lua states](#TODO)
- [lua statements](#TODO)
- [code awaits](#TODO)
- [code spawns](#TODO)
- [vector constructors](#TODO)
- [data constructors](#TODO)
- [expressions](#TODO)
- the neutral identifier `_`

The anonymous identifier makes the assignment innocuous.

`TODO: required for uninitialized variables`

### Copy Assignment

A *copy assignment* evaluates the statement or expression at the right side and
copies the result(s) to the location(s) at the left side.

### Alias Assignment

An *alias assignment*, aka *binding*, makes the location at the left side to be
an [alias](#TODO) to the expression at the right side.

The right side of a binding is always prefixed by the operator `&`.
