## Types

Céu supports type checks and casts:

```ceu
Check ::= Exp is Type
Cast  ::= Exp as Type
```

### Type Check

In a type check, the static type of the expression must be a supertype of the
checked type.
The check evaluates to *true* or *false* and checks if the runtime type of the
expression is of the checked type.

Example:

```ceu
data Aa;
data Aa.Bb;
var Aa a = <...>;       // "a" has static type "Aa"
<...>
if a is Aa.Bb then      // has "a" runtime type "Aa.Bb"?
    <...>
end
```

### Type Cast

A type cast converts the type of an expression into a new type as follows:

1. The expression type is a [data type](#TODO):
    1. The new type is `int`:
        Evaluates to the [type enumeration](#TODO) for the expression type.
    2. The new type is a subtype of the expression static type:
        1. The expression runtime type is a subtype of the new type:
            Evaluates to the new type.
        2. Evaluates to error.
    3. The new type is a supertype of the expression static type:
        Always succeeds and evaluates to the new type.
        See also [Dynamic Dispatching](#TODO).
    4. Evaluates to error.
2. Evaluates to the new type (i.e., a *weak typecast*, as in C).

Examples:

```ceu
var Direction dir = <...>;
_printf("dir = %d\n", dir as int);

var Aa a = <...>;
_printf("a.v = %d\n", (a as Aa.Bb).v);

var Media.Video vid = <...>;
await/dynamic Play(&m as Media);

var bool b = <...>;
_printf("b= %d\n", b as int);
```
