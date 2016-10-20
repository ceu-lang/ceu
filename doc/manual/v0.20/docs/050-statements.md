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

The `pre-do-end` statement prepends its statements in the beginning of the
program:

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

Céu supports variables, vectors, external events, internal events, and pools:

```ceu
Var    ::= var [`&´|`&?´] Type LIST(ID_int [`=´ Set])
Vector ::= vector [`&´] `[´ [Exp] `]´ Type LIST(ID_int [`=´ Set])
Ext    ::= input  (Type | `(´ LIST(Type) `)´) LIST(ID_ext)
        |  output (Type | `(´ LIST(Type) `)´) LIST(ID_ext)
Int    ::= event [`&´|`&?´] (Type | `(´ LIST(Type) `)´) LIST(ID_int [`=´ Set])
Pool   ::= pool [`&´] `[´ [Exp] `]´ Type LIST(ID_int [`=´ Set])
```

See also [Storage Classes](#TODO) for an overview of storage entities.

### Variables

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

An event has a [type](#TODO) for the value it carries when occurring.
It can be also a list of types if the event communicates multiple values.
A single statement can declare multiple events of the same type.

See also [Introduction](#TODO) for a general overview of events.

#### External events

Examples:

```ceu
input  void A,B;        // "A" and "B" are input events carrying no values
output int  MY_EVT;     // "MY_EVT" is an output event carrying integer values
input (int,byte&&) BUF; // "BUF" is an input event carrying an "(int,byte&&)" pair
```

### Internal events

Declarations for internal events can also be [aliases](#TODO) or
[option aliases](#TODO).
Only in this case they can contain an [initialization](#TODO).

Examples:

```ceu
event  void a,b;        // "a" and "b" are internal events carrying no values
event& void z = &a;     // "z" is an alias to event "a"
event (int,int) c;      // "c" is a internal event carrying an "(int,int)" pair
```

### Pools

`TODO`

Event Handling
--------------

### Await

The `await` statement halts the running trail until the referred
event occurs.
The event can be an [external input event](#TODO), an [internal event](#TODO),
a timer, or forever (i.e., never awake):

```ceu
Await ::= await (ID_ext | Name) [until Exp]     /* events */
       |  await (WCLOCKK|WCLOCKE)               /* timers */
       |  await FOREVER                         /* forever */
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
[external input event](#TODO) or  [internal event](#TODO) occurs.

The `await` evaluates to a value of the type of the event.

The optional clause `until` tests an additional condition required to awake.
The condition can use the returned value from the `await`.
It expands to a [`loop`](#TODO) as follows:

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
var int v = await E until v>10; // assigns occurring "E" to "v", awaking when "v>10"

event (bool,int) e;             // "e" is an internal event carrying "(bool,int)" pairs
var bool v1;
var int  v2;
(v1,v2) = await e;              // awakes on "e" and assigns its values to "v1" and "v2"
```

#### Timers

The `await` statement for timers halts the running trail until the referred
timer expires.

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

The `emit` statement broadcasts an event to the whole program.
The event can be an [external event](#TODO), an [internal event](#TODO), or
a timer:

```ceu
Emit ::= emit (ID_ext | Name) [`=>´ (Exp | `(´ [LIST(Exp)] `)´)]
      |  emit (WCLOCKK|WCLOCKE)
```

Examples:

```ceu
emit A;         // emits the external event `A` of type "void"
emit a(1);      // emits the internal event `a` of type "int"

emit 1s;        // emits the specified time
emit (t)ms;     // emits the current value of the variable `t` in milliseconds
```

#### Events

The `emit` statement for events expects a specific number of arguments matching
the event type (unless the event is of type `void`).

- An `emit` to an external input or timer event can only occur inside
  [asynchronous blocks](#TODO).
- An `emit` to an external output event is also an expression that evaluates
  to a value of type `s32` (its meaning is [platform dependent](#TODO)).
- An `emit` to an internal event starts a new [internal reaction](#TODO).

Examples:

```ceu
input int I;
async do
    emit I(10);         // broadcasts "I" to the application itself, passing "10"
end

output void O;
var int ret = emit O(); // outputs "O" to the environment and captures the result

event (int,int) e;
emit e(1,2);            // broadcasts "e" passing a pair of "int" values
```

#### Timers

The `emit` statement for timers expects an expression of time as described in
[Await Timer](#TODO).

Like input events, time can only be emitted inside [asynchronous 
blocks](#asynchronous-blocks).

Examples:

```ceu
async do
    emit 1s;    // broadcasts "1s" to the application itself
end
```

Conditionals
------------

The `if-then-else` statement provides conditionals in Céu:

```ceu
If ::= if Exp then
           Block
       { else/if Exp then
           Block }
       [ else
           Block ]
       end
```

Each condition `Exp` is tested in sequence, first for the `if` clause and then
for each of the optional `else/if` clauses.
For the first condition that evaluates to `true`, the `Block` following it
executes.
If all conditions fail, the optional `else` clause executes.

All conditions must evaluate to a value of type [`bool`](#TODO), which is
checked at compile time.

Loops
-----

Céu supports simple loops, numeric iterators, event iterators, and pool
iterators:

```ceu
Loop ::=
      /* simple loop */
        loop [`/´Exp] do
            Block
        end

      /* numeric iterator */
      | loop [`/´Exp] Numeric do    /* Numeric ::= (see "Numeric Iterators") */
            Block
        end

      /* event iterator */
      | every [(Name | `(´ LIST(Name|`_´) `)´) in] (ID_ext|Name|WCLOCKK|WCLOCKE) do
            Block
        end

      /* pool iterator */
      | loop [`/´Exp] [ `(´ LIST(Var) `)´ ] in Name do
            Block
        end

Break    ::= break [`/´ID_int]
Continue ::= continue [`/´ID_int]
```

The `Block` body of a loop executes an arbitrary number of times, depending on
the conditions imposed by each kind of loop.

Except for the `every` iterator, all loops support an optional
<code>&grave;/&acute;Exp</code> to limit the maximum number of iterations and
avoid [infinite execution](#TODO).
The expression must be a constant evaluated at compile time.

### `break` and `continue`

The `break` statement aborts the deepest enclosing loop.

The `continue` statement aborts the body of the deepest enclosing loop and
restarts in the next iteration.

The optional <code>&grave;/&acute;ID_int</code> in both statements only applies
to [numeric iterators](#TODO).

### Simple Loops

A simple loop executes its body continually and forever.

Examples:

```ceu
loop do     // blinks a LED with a frequency of 1s forever
    emit LED(1);
    await 1s;
    emit LED(0);
    await 1s;
end
```

```ceu
loop do
    <...>
    loop do
        <...>
        if <cnd-1> then
            break;      // aborts the loop at line 3 if <cnd-1> is satisfied
        end
        <...>
    end
    <...>
    if <cnd-2> then
        continue;       // restarts the loop at line 1 if <cnd-2> is satisfied
    end
    <...>
end
```

### Numeric Iterators

The numeric loop modifies the value of a control variable on each iteration
according to the specification of an optional interval as follows:

```ceu
Numeric ::= (`_´|ID_int) in [ (`[´ | `]´)
                                  ( (     Exp `->´ (`_´|Exp))
                                  | (`_´|Exp) `<-´ Exp      ) )
                              (`[´ | `]´) [`,´ Exp] ]
```

The control variable assumes the values specified in the interval, one by one,
for each iteration of the loop body:

- **control variable:**
    `ID_int` is a variable of a [numeric type](#TODO).
    Alternatively, the special anonymous identifier `_` can be used if the body
    of the loop does not access the variable.
    The control variable is marked as `read-only` and cannot be changed
    explicitly.
- **interval:**
    Specifies a direction, endpoints with open or closed modifiers, and a step.
    - **direction**:
        - `->`: Starts from the endpoint `Exp` on the left increasing towards `Exp` on the right.
        - `<-`: Starts from the endpoint `Exp` on the right decreasing towards `Exp` on the left.
        Typically, the value on the left should always be smaller or equal to
        the value on the right.
    - **endpoints**:
        `[Exp` and `Exp]` are closed intervals which include `Exp` as the
        endpoints;
        `]Exp` and `Exp[` are open intervals which exclude `Exp` as the
        endpoints.
        Alternatively, the finishing endpoint may be `_` which means that the
        interval goes towards infinite.
    - **step**:
        An optional positive number added or subtracted towards the limit.
        If the step is omitted, it assumes the value `1`.
        If the direction is `->`, the step is added, otherwise it is subtracted.
    If the interval is not specified, it assumes the default `[0 -> _]`.

The execution of the numeric iterator is as follows:

- **initialization:**
    The starting endpoint is assigned to the control variable.
    If the starting enpoint is open, the control variable accumulates a step.
- **iteration:**
    1. **limits test:**
        If the control variable crossed the finishing endpoint, the loop
        terminates.
    2. **body execution:**
        The loop body executes.
    3. **step**
        Applies a step to the control variable. Goto step `1`.

Examples:

```ceu
var int i;
loop i do
    _printf("i=%d\n", i);   // prints "i=0", "i=1", ...
end
```

*Note : the runtime asserts that the step is a positive number and that the control
variable does not overflow.*
