## Lua Integration

Céu provides [Lua states](#lua-state) to delimit the effects of inlined
[Lua statements](#lua-statement).
Lua statements transfer execution to the Lua runtime, losing the guarantees of
the [synchronous model](../#synchronous-execution-model):

```ceu
Lua_State ::= lua `[´ [Exp] `]´ do
                 Block
              end
Lua_Stmts ::= `[´ {`=´} `[´
                  { {<code in Lua> | `@´ (`(´Exp`)´|Exp)} }   /* `@@´ escapes to `@´ */
              `]´ {`=´} `]´
```

Programs have an implicit enclosing *global Lua state* which all orphan
statements apply.

### Lua State

A Lua state creates an isolated state for inlined
[Lua statements](#lua-statement).

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

Like [native statements](#native-statement), Lua statements support
interpolation of expressions in Céu which are expanded when preceded by a `@`.

Lua statements only affect the [Lua state](#lua-state) in which they are embedded.

If a Lua statement is used in an [assignment](#assignments), it is evaluated as
an expression that either satisfies the destination or generates a runtime
error.
The list that follows specifies the *Céu destination* and expected
*Lua source*:

- a [boolean](../types/#primitives) [variable](../storage_entities/#variables)
    expects a `boolean` value
- a [numeric](../types/#primitives) [variable](../storage_entities/#variables)
    expects a `number` value
- a [pointer](../storage_entities/#pointers) [variable](../storage_entities/#variables)
    expects a `lightuserdata` value
- a [byte](../types/#primitives) [vector](../storage_entities/#vectors)
    expects a `string` value

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
