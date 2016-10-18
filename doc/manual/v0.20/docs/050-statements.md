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
Do ::= do [`/´ (`_´|ID_int)]
           Block
       end

Escape ::= escape [`/´ID_int] [Exp]
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
Pre_Do ::= pre do
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
Var ::= var [`&´|`&?´] Type LIST(ID_int [`=´ Set])
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
Vector ::= vector [`&´] `[´ [Exp] `]´ Type LIST(ID_int [`=´ Set])
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
Ext ::= input  (Type | `(´ LIST(Type) `)´) LIST(ID_ext)
     |  output (Type | `(´ LIST(Type) `)´) LIST(ID_ext)
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
Int ::= event [`&´|`&?´] (Type | `(´ LIST(Type) `)´) LIST(ID_int [`=´ Set])
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

Event Handling
--------------

### Await

The `await` statement halts the running trail until the referred
event occurs.
The event can be an [external input event](#TODO), an [internal event](#TODO),
a timer, or forever (i.e., never awake):

```ceu
Await ::= await (ID_ext | Name) [until Exp]
       |  await (WCLOCKK|WCLOCKE)
       |  await FOREVER

WCLOCKK ::= [NUM h] [NUM min] [NUM s] [NUM ms] [NUM us]
WCLOCKE ::= `(´ Exp `)´ (h|min|s|ms|us)
```

Examples:

```ceu
await A;                  // awaits the input event `A`
await a;                  // awaits the internal event `a`

await 10min3s5ms100us;    // awaits the specified time
await (t)ms;              // awaits the current value of the variable `t` in milliseconds

await FOREVER;            // awaits forever
```

An `await` evaluates to zero or more values which can be captured with an
optional [assignment](#TODO).

#### Events

The `await` statement for events halts the running trail until the referred
[external input event](#TODO) or  [internal event](#TODO) occurs:

```ceu
Await ::= await (ID_ext | Name) [until Exp]
       |  ...   // other awaits
```

The `await` evaluates to a value of the type of the event.

The optional clause `until` tests an additional condition required to awake.
The condition can use the returned value from the `await`.
It expands to the `loop` as follows:

```ceu
loop do
    <ret> = await <evt>;
    if <Exp> then   // <Exp> can use <ret>
        break;
    end
end
```

Examples:

```ceu
input int E;                    // "E" is an external input event carrying "int" values
var int v = await E until v>10; // assigns occurring values of "E" to "v", awaking when "v>10"

event (bool,int) e;             // "e" is an internal event carrying "(bool,int)" pairs
var bool v1;
var int  v2;
(v1,v2) = await e;              // awakes on "e" and assigns its carrying values to "v1" and "v2"
```

#### Timers

The `await` statement for timers halts the running trail until the referred
timer expires:

```ceu
Await ::= await (WCLOCKK|WCLOCKE)
       |  ...   // other awaits

WCLOCKK ::= [NUM h] [NUM min] [NUM s] [NUM ms] [NUM us]
WCLOCKE ::= `(´ Exp `)´ (h|min|s|ms|us)
```

`WCLOCKK` specifies a constant time expressed as a sequence of value/unit
pairs.
`WCLOCKE` specifies an expression in parenthesis followed by a single unit of
time.

The `await` evaluates to a value of type `s32` and is the
*residual delta time (dt)* measured in microseconds.
Is is the difference between the actual elapsed time and the requested time.

Examples:

```ceu
var int t = <...>;
await (t)ms;                            // awakes after "t" milliseconds

var int dt = await 1min10s30ms100us;    // if 1min10s31ms000us elapses, then dt=900
```

*Note: The residual **dt** is always greater than or equal to 0.*

<!--
Refer to [[#Environment]] for information about storage types for *wall-clock*
time.
-->

#### `FOREVER`

The `await` statement for `FOREVER` halts the running trail forever.
It cannot be used in assignments because it never evaluates to anything.

```ceu
if <cnd> then
    await FOREVER;  // this trail never awakes if the condition is true
end
```

### Emit
