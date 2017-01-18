## Blocks

A `Block` creates a new lexical scope for
[storage entities](#TODO)
and
[abstractions](#TODO),
which are visible only for statements inside the block.

Compound statements (e.g. *do-end*, *if-then-else*, *loops*, etc.) create new
blocks and can be nested to an arbitrary level.

### `do-end` and `escape`

The `do-end` statement creates an explicit block with an optional identifier.
The `escape` statement aborts the deepest enclosing `do-end` matching its
identifier:

```ceu
Do ::= do [`/´ (`_´|ID_int)]
           Block
       end

Escape ::= escape [`/´ID_int] [Exp]
```

`do-end` supports the neutral identifier `_` which is guaranteed not to match
any `escape` statement.

A `do-end` can be [assigned](#TODO) to a variable whose type must be matched
by nested `escape` statements.
The whole block evaluates to the value of a reached `escape`.
If the variable is of [option type](#TODO), the `do-end` is allowed to
terminate without an `escape`, otherwise it raises a runtime error.

Programs have an implicit enclosing `do-end` that assigns to a
*program status variable* of type `int` whose meaning is
[platform dependent](#TODO).

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
and moved to the beginning of the top-level block, before all other statements.
