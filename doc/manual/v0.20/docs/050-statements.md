Statements
==========

A program in Céu is a sequence of statements delimited by an enclosing block as
follows:

```ceu
Program ::= Block
Block   ::= {Stmt `;´} {`;´}
```

*Note: statements terminated with the `end` keyword do not require a
terminating semicolon.*

Blocks
------

A `Block` creates a new scope for [storage entities](#TODO) which are visible
only for statements inside the block.

Compound statements (e.g. *do-end*, *if-then-else*, *loops*, etc.) create new
blocks and can be nested to an arbitrary level.

### `do-end` and `escape`

The `do-end` statement creates an explicit block with an optional identifier.
The `escape` statement aborts the deepest enclosing `do-end` matching its
identifier:

```ceu
do [`/´ (`_´|ID_int)]
    Block
end

escape [`/´ID_int] [Exp]
```

A `do-end` supports the identifier `_` which is guaranteed not to match any
`escape` statement.

Example:

```ceu
do/a
    do/_
        do
            escape;     // matches line 3
        end
        escape/a;       // matches line 1
    end
end
```

### `pre-do-end`

A `pre-do-end` prepends its statements in the beginning of the program:

```ceu
pre do
    Block
end
```

All `pre-do-end` statements are concatenated together in the order they appear
and moved to the beginning of the top-level block, before all other statements.

Declarations
------------

A declaration exposes a [storage entity](#TODO) to the program.
Its [scope](#TODO) begins after the declaration and goes until the end of the
enclosing [block](#TODO).

See also [Storage Classes](#TODO) for a general overview of storage entities.

### Variables

Variable declarations are as follows:

```ceu
var [`&´|`&?´] Type LIST(ID_int [`=´ Set])
```

A variable has an associated [type](#TODO) and can be optionally
[initialized](#TODO).
A single statement can declare multiple variables of the same type.
Declarations can also be [aliases](#TODO) or [option aliases](#TODO).

Examples:

```ceu
var  int v = 10;    // "v" is an integer variable initialized to 10
var  int a=0, b=3;  // "a" and "b" are integer variables initialized to 0 and 3
var& int z = &v;    // "z" is an alias to "v"
```

### Vectors

Vector declarations are as follows:

```ceu
vector [`&´] `[´ [Exp] `]´ Type LIST(ID_int [`=´ Set])
```

A vector has a dimension, an associated [type](#TODO) and can be optionally
[initialized](#TODO).
A single statement can declare multiple vectors of the same dimension and type.
Declarations can also be [aliases](#TODO).

The expression between the brackets specifies the dimension of the vector with
the options that follow:

- *constant expression*: Maximum number of elements is fixed and space is
                         statically pre-allocated.
- *variable expression*: Maximum number of elements is fixed but space is
                         dynamically allocated.
                         The expression is evaulated once at declaration time.
- *omitted*: Maximum number of elements is unbounded and space is dynamically
             allocated.

The space for dynamic vectors grow and shrink automatically.

Examples:

```ceu
var int n = 10;
vector[10] int vs1 = [];    // "vs1" is a static vector of 10 elements max
vector[n]  int vs2 = [];    // "vs2" is a dynamic vector of 10 elements max
vector[]   int vs3 = [];    // "vs3" is an unbounded vector
vector&[]  int vs4 = &vs1;  // "vs4" is an alias to "vs1"
```

### Events

See also [Introduction](#TODO) for a general overview of events.

#### External events

External event declarations are as follows:

```ceu
input  (Type | `(´ LIST(Type) `)´) LIST(ID_ext)
output (Type | `(´ LIST(Type) `)´) LIST(ID_ext)
```

A declaration includes the [type](#TODO) of the value the event carries.
It can be also a list of types if the event communicates multiple values.
A single statement can declare multiple events of the same type.

Examples:

```ceu
input  void A,B;        // "A" and "B" are input events carrying no values
output int  MY_EVT;     // "MY_EVT" is an output event carrying integer values
input (int,byte&&) BUF; // "BUF" is an input event carrying an "(int,byte&&)" pair
```

### Internal events

Internal event declarations are as follows:

```ceu
event [`&´|`&?´] (Type | `(´ LIST(Type) `)´) LIST(ID_int [`=´ Set])
```

A declaration includes the [type](#TODO) of the value the event carries.
It can be also a list of types if the event communicates multiple values.
A single statement can declare multiple events of the same type.
Declarations can also be [aliases](#TODO) or [option aliases](#TODO).
Only in this case they can contain an [initialization](#TODO).

Examples:

```ceu
event  void a,b;        // "a" and "b" are internal events carrying no values
event& void z = &a;     // "z" is an alias to event "a"
event (int,int) c;      // "c" is a internal event carrying an "(int,int)" pair
```
