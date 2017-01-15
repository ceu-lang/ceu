## Lua Integration

Céu provides [Lua states](#TODO) to delimit the effects of inlined
[Lua statements](#TODO):

```ceu
Lua_State ::= lua `[´ [Exp] `]´ do
                 Block
              end
Lua_Stmts ::= `[´ {`=´} `[´
                  { {<code in Lua> | `@´ Exp} }
              `]´ {`=´} `]´
```

Lua statements transfer execution to Lua, losing the guarantees of the
[synchronous model](#TODO).
For this reason, programs should only resort to C for asynchronous
functionality (e.g., non-blocking I/O) or simple `struct` accessors, but
never for control purposes.

All programs have an implicit enclosing *global Lua state* which all orphan
statements apply.

### Lua State

A Lua state creates an isolated state for inlined [Lua statements](#TODO).

Example:

```ceu
// "v" is not shared between the two statements
par do
    // global Lua state
    [[ v = 0 ]];
    var int v = 0;
    every 1s do
        [[print('Lua 1', v, @v) ]];
        v = v + 1;
        [[ v = v + 1 ]];
    end
with
    // local Lua state
    lua[] do
        [[ v = 0 ]];
        var int v = 0;
        every 1s do
            [[print('Lua 2', v, @v) ]];
            v = v + 1;
            [[ v = v + 1 ]];
        end
    end
end
```

`TODO: dynamic scope, assignment/error, [dim]`

### Lua Statement

The contents of Lua statements in between `[[` and `]]` are inlined in the
program.

Like [native statements](#TODO), Lua statements support interpolation of
expressions in Céu which are expanded when preceded by a `@`.

Lua statements only affect the [Lua state](#TODO) in which they are embedded.

If a Lua statement is used in an [assignment](#TODO), it is evaluated as an
expression that either satisfies the destination or generates a runtime error.
The list that follows specifies the *Céu destination* and expected
*Lua source*:

- a `var` `bool`              expects a `boolean`
- a [numeric](#TODO) `var`    expects a `number`
- a pointer `var`             expects a `lightuserdata`
- a `vector` `byte`           expects a `string`

`TODO: lua state captures errors`

Examples:

```ceu
var int v_ceu = 10;
[[
    v_lua = @v_ceu * 2          -- yields 20
]]
v_ceu = [[ v_lua + @v_ceu ]];   // yields 30
[[
    print(@v_ceu)               -- prints 30
]]
```
