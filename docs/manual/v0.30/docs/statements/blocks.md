## Blocks

A `Block` delimits a lexical scope for
[storage entities](../storage_entities/#entity-classes)
and
[abstractions](#abstractions),
which are only visible to statements inside the block.

Compound statements (e.g. *do-end*, *if-then-else*, *loops*, etc.) create new
blocks and can be nested to an arbitrary level.

### `do-end` and `escape`

The `do-end` statement creates an explicit block.
The `escape` statement terminates the deepest matching enclosing `do-end`:

```ceu
Do ::= do [`/´(ID_int|`_´)] [`(´ [LIST(ID_int)] `)´]
           Block
       end

Escape ::= escape [`/´ID_int] [Exp]
```

A `do-end` and `escape` accept an optional identifier following the symbol `/`.
An `escape` only matches a `do-end` with the same identifier.
The neutral identifier `_` in a `do-end` is guaranteed not to match any
`escape` statement.

A `do-end` also supports an optional list of identifiers in parenthesis which
restricts the visible storage entities inside the block to those matching the
list.
An empty list hides all storage entities from the enclosing scope.

A `do-end` can be [assigned](#assignments) to a variable whose type must be
matched by nested `escape` statements.
The whole block evaluates to the value of a reached `escape`.
If the variable is of [option type](../types/#option), the `do-end` is allowed
to terminate without an `escape`, otherwise it raises a runtime error.

Programs have an implicit enclosing `do-end` that assigns to a
*program status variable* of type `int` whose meaning is platform dependent.

Examples:

```ceu
do
    do/a
        do/_
            escape;     // matches line 1
        end
        escape/a;       // matches line 2
    end
end
```

```ceu
var int a;
var int b;
do (a)
    a = 1;
    b = 2;  // "b" is not visible
end
```

```ceu
var int? v =
    do
        if <cnd> then
            escape 10;  // assigns 10 to "v"
        else
            nothing;    // "v" remains unassigned
        end
    end;
```

```ceu
escape 0;               // program terminates with a status value of 0
```

### `pre-do-end`

The `pre-do-end` statement prepends its statements in the beginning of the
program:

```ceu
Pre_Do ::= pre do
               Block
           end
```

All `pre-do-end` statements are concatenated together in the order they appear
and are moved to the beginning of the top-level block, before all other
statements.
