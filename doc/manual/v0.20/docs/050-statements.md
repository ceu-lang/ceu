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

-------------------------------------------------------------------------------

Declarations
------------

A declaration exposes a [storage entity](#TODO) to the program.
Its [scope](#TODO) begins after the declaration and goes until the end of the
enclosing [block](#TODO).

Céu supports variables, vectors, external events, internal events, and pools:

```ceu
Var  ::= var [`&´|`&?´] Type LIST(ID_int [`=´ Cons])
Vec  ::= vector [`&´] `[´ [Exp] `]´ Type LIST(ID_int [`=´ Cons])
Ext  ::= input  (Type | `(´ LIST(Type) `)´) LIST(ID_ext)
      |  output (Type | `(´ LIST(Type) `)´) LIST(ID_ext)
Int  ::= event [`&´|`&?´] (Type | `(´ LIST(Type) `)´) LIST(ID_int [`=´ Cons])
Pool ::= pool [`&´] `[´ [Exp] `]´ Type LIST(ID_int [`=´ Cons])

Vec_Cons ::= (Exp | `[´ [LIST(Exp)] `]´) { `..´ (Exp | Lua_Stmts | `[´ [LIST(Exp)] `]´) }
```

See also [Storage Classes](#TODO) for an overview of storage entities.

### Variable

A [variable](#TODO) declaration has an associated [type](#TODO) and can be
optionally [initialized](#TODO).
A single statement can declare multiple variables of the same type.
Declarations can also be [aliases](#TODO) or [option aliases](#TODO).

Examples:

```ceu
var  int v = 10;    // "v" is an integer variable initialized to 10
var  int a=0, b=3;  // "a" and "b" are integer variables initialized to 0 and 3
var& int z = &v;    // "z" is an alias to "v"
```

### Vector

A [vector](#TODO) declaration has a dimension, an associated [type](#TODO) and
can be optionally [initialized](#TODO).
A single statement can declare multiple vectors of the same dimension and type.
Declarations can also be [aliases](#TODO).
The expression between the brackets specifies the [dimension](#TODO) of the
vector.

Examples:

```ceu
var int n = 10;
vector[10] int vs1 = [];    // "vs1" is a static vector of 10 elements max
vector[n]  int vs2 = [];    // "vs2" is a dynamic vector of 10 elements max
vector[]   int vs3 = [];    // "vs3" is an unbounded vector
vector&[]  int vs4 = &vs1;  // "vs4" is an alias to "vs1"
```

See also [vector constructor](#TODO).

### Event

An [event](#TODO) has a [type](#TODO) for the value it carries when occurring.
It can be also a list of types if the event communicates multiple values.
A single statement can declare multiple events of the same type.

See also [Introduction](#TODO) for a general overview of events.

#### External Event

Examples:

```ceu
input  void A,B;        // "A" and "B" are input events carrying no values
output int  MY_EVT;     // "MY_EVT" is an output event carrying integer values
input (int,byte&&) BUF; // "BUF" is an input event carrying an "(int,byte&&)" pair
```

### Internal Event

Declarations for internal events can also be [aliases](#TODO) or
[option aliases](#TODO).
Only in this case they can contain an [initialization](#TODO).

Examples:

```ceu
event  void a,b;        // "a" and "b" are internal events carrying no values
event& void z = &a;     // "z" is an alias to event "a"
event (int,int) c;      // "c" is a internal event carrying an "(int,int)" pair
```

### Pool

A [pool](#TODO) has a dimension, an associated [type](#TODO) and can be
optionally [initialized](#TODO).
A single statement can declare multiple pools of the same dimension and type.
Declarations can also be [aliases](#TODO).
The expression between the brackets specifies the [dimension](#TODO) of the
pool.

Examples:

```ceu
code/await Play (...) do ... end
pool[10] Play plays;        // "plays" is a static pool of 10 elements max
pool&[]  Play a = &plays;   // "a" is an alias to "plays"
```

See also [Code Invocation](#TODO).

`TODO: data`

### Dimension

A declaration for [vector](#TODO) or [pool](#TODO) requires an expression
between brackets to specify its [dimension](#TODO) as follows:

- *constant expression*: Maximum number of elements is fixed and space is
                         statically pre-allocated.
- *variable expression*: Maximum number of elements is fixed but space is
                         dynamically allocated.
                         The expression is evaulated once at declaration time.
- *omitted*: Maximum number of elements is unbounded and space is dynamically
             allocated.

The space for dynamic dimensions grow and shrink automatically.

-------------------------------------------------------------------------------

Event Handling
--------------

### Await

The `await` statement halts the running trail until the referred
event occurs.
The event can be an [external input event](#TODO), an [internal event](#TODO),
a timer, a [pausing event](#TODO), or forever (i.e., never awake):

```ceu
Await ::= await (ID_ext | Name) [until Exp]     /* events */
       |  await (WCLOCKK|WCLOCKE)               /* timers */
       |  await (pause|resume)                  /* pausing events */
       |  await FOREVER                         /* forever */
```

Examples:

```ceu
await A;                  // awaits the input event `A`
await a;                  // awaits the internal event `a`

await 1min10s30ms100us;   // awaits the specified time
await (t)ms;              // awaits the current value of the variable `t` in milliseconds

await FOREVER;            // awaits forever
```

An `await` evaluates to zero or more values which can be captured with an
optional [assignment](#TODO).

#### Event

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

#### Timer

The `await` statement for timers halts the running trail until the referred
timer expires.

`WCLOCKK` specifies a constant time expressed as a sequence of value/unit
pairs.
`WCLOCKE` specifies an expression in parenthesis followed by a single unit of
time.

The `await` evaluates to a value of type `s32` and is the
*residual delta time (`dt`)* measured in microseconds.
It is the difference between the actual elapsed time and the requested time.

If a program awaits timers in sequence (or in a `loop`), the residual `dt` from
the preceding timer is reduced from the timer in sequence.

Examples:

```ceu
var int t = <...>;
await (t)ms;                // awakes after "t" milliseconds
```

```ceu
var int dt = await 100us;   // if 1ms elapses,  1000>100, dt=900us
await 100us;                // timer is expired, 900>100, dt=800us
await 1ms;                  // timer only awaits 200us (1000-800)
```

*Note: The residual `dt` is always greater than or equal to 0.*

<!--
Refer to [[#Environment]] for information about storage types for *wall-clock*
time.
-->

#### Pausing

Pausing events are dicussed in [Pausing](#TODO).

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
Emit ::= emit (ID_ext | Name) [`(´ [LIST(Exp)] `)´)]
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
  to a value of type `s32` and can be captured with an optional
  [assignment](#TODO) (its meaning is [platform dependent](#TODO)).
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

#### Timer

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

-------------------------------------------------------------------------------

Conditional
-----------

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

### Simple Loop

A simple loop executes its body continually and forever.

Examples:

```ceu
// blinks a LED with a frequency of 1s forever
loop do
    emit LED(1);
    await 1s;
    emit LED(0);
    await 1s;
end
```

```ceu
loop do
    loop do
        if <cnd-1> then
            break;      // aborts the loop at line 2 if <cnd-1> is satisfied
        end
    end
    if <cnd-2> then
        continue;       // restarts the loop at line 1 if <cnd-2> is satisfied
    end
end
```

### Numeric Iterator

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

The numeric iterator executes as follows:

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

The `break` and `continue` statements inside numeric iterators accept an
optional modifier <code>&grave;/&acute;ID_int</code> to match the control
variable of the enclosing loop to affect.

Examples:

```ceu
// prints "i=0", "i=1", ...
var int i;
loop i do
    _printf("i=%d\n", i);
end
```

```ceu
// awaits 1s and prints "Hello World!" 10 times
loop _ in [0 -> 10[ do
    await 1s;
    _printf("Hello World!\n");
end
```

```ceu
var int i;
loop i do
    var int j;
    loop j do
        if <cnd-1> then
            continue/i;         // continues the loop at line 1
        else/if <cnd-2> then
            break/j;            // breaks the loop at line 4
        end
    end
end
```

*Note : the runtime asserts that the step is a positive number and that the
        control variable does not overflow.*

### Event Iterator

The `every` statement iterates over an event continuously and executes its
body whenever the event occurs.

The event can be an [external or internal event](#TODO) or a [timer](#TODO).

The optional assignment to a variable (or list of variables) stores the
carrying value(s) of the event.

An `every` expands to a `loop` as illustrated below:

```ceu
every <vars> in <event> do
    <body>
end
```

is equivalent to

```ceu
loop do
    <vars> = await <event>;
    <body>
end
```

However, the body of an `every` cannot contain
[synchronous control statements](#TODO), ensuring that no occurrences of the
specified event are ever missed.

Examples:

```ceu
every 1s do
    _printf("Hello World!\n");      // prints the "Hello World!" message on every second
end
```

```ceu
event (bool,int) e;
var bool cnd;
var int  v;
every (cnd,v) in e do
    if not cnd then
        break;                      // terminates when the received "cnd" is false
    else
        _printf("v = %d\n", v);     // prints the received "v" otherwise
    end
end
```

### Pool Iterator

Pool iterator is discussed in [Code Pools](#TODO).

-------------------------------------------------------------------------------

Parallel Compositions
---------------------

The parallel statements `par/and`, `par/or`, and `par` split the running trail 
in multiple others:

```ceu
Pars ::= (par | par/and | par/or) do
             Block
         with
             Block
         { with
             Block }
         end

Watching ::= watching LIST(ID_ext|Name|WCLOCKK|WCLOCKE|Code_Cons_Init) do
                 Block
             end

```

They differ only on how trails rejoin and terminate the composition.

The `watching` statement terminates when one of its listed events occur.
It evaluates to what the terminating event evaluates which can be captured with
an optional [assignment](#TODO).

See also [Parallel Compositions and Abortion](#TODO).

### par

The `par` statement never rejoins.

Examples:

```ceu
// reacts continuously to "1s" and "KEY_PRESSED" and never terminates
input void KEY_PRESSED;
par do
    every 1s do
        <...>           // does something every "1s"
    end
with
    every KEY_PRESSED do
        <...>           // does something every "KEY_PRESSED"
    end
end
```

### par/and

The `par/and` statement stands for *parallel-and* and rejoins when all trails 
terminate.

Examples:

```ceu
// reacts once to "1s" and "KEY_PRESSED" and terminates
input void KEY_PRESSED;
par/and do
    await 1s;
    <...>               // does something after "1s"
with
    await KEY_PRESSED;
    <...>               // does something after "KEY_PRESSED"
end
```

### par/or

The `par/or` statement stands for *parallel-or* and rejoins when any of the 
trails terminate, aborting all other trails.

Examples:

```ceu
// reacts once to `1s` or `KEY_PRESSED` and terminates
input void KEY_PRESSED;
par/or do
    await 1s;
    <...>               // does something after "1s"
with
    await KEY_PRESSED;
    <...>               // does something after "KEY_PRESSED"
end
```

### watching

The `watching` statement accepts a list of events and terminates when any of
the events occur.

A `watching` expands to a `par/or` with *n+1* trails:
one to await each of the listed events,
and one for its body, i.e.:

```ceu
watching <e1>,<e2>,... do
    <body>
end
```

expands to

```ceu
par/or do
    await <e1>;
with
    await <e2>;
with
    ...
with
    <body>
end
```

Examples:

```ceu
// reacts continuously to "KEY_PRESSED" during "1s"
input void KEY_PRESSED;
watching 1s do
    every KEY_PRESSED do
        <...>           // does something every "KEY_PRESSED"
    end
end
```

`TODO: watching <code>`

-------------------------------------------------------------------------------

Pausing
-------

The `pause/if` statement controls if its body should temporarily stop to react
to events:

```ceu
Pause_If ::= pause/if (Name|ID_ext) do
                 Block
             end

Pause_Await ::= await (pause|resume)
```

A `pause/if` determines a pausing event of type `bool` which, when emitted,
toggles between pausing (`true`) and resuming (`false`) reactions for its body.

When its body terminates, the whole `pause/if` terminates and proceeds to the
statement in sequence.

In transition points, the body can react to the special `pause` and `resume`
events before the corresponding state applies.

`TODO: finalize/pause/resume`

Examples:

```ceu
event bool e;
pause/if e do       // pauses/resumes the nested body on each "e"
    every 1s do
        <...>       // does something every "1s"
    end
end
```

```ceu
event bool e;
pause/if e do               // pauses/resumes the nested body on each "e"
    <...>
        loop do
            await pause;
            <...>           // does something before pausing
            await resume;
            <...>           // does something before resuming
        end
    <...>
end
```

<!--
*Note: The timeouts for timers remain frozen while paused.*
-->

-------------------------------------------------------------------------------

Asynchronous Execution
----------------------

Asynchronous execution allow programs to execute time consuming computations 
without interfering with the responsiveness of the  *synchronous side* of
applications (i.e., all core language statements):

```ceu
Async  ::= await async [ `(´LIST(Var)`)´ ] do
               Block
           end

Thread ::= await async/thread [ `(´LIST(Var)`)´ ] do
               Block
           end
Atomic ::= atomic do
               Block
           end
```

The program awaits the termination of the asynchronous body to proceed to the
statement in sequence.

Asynchronous bodies can contain [tight loops](#TODO) but which keep the
application reactive to incoming events.
However, they do not support nesting of asynchronous statements, and do not
support [synchronous control statements](#TODO) (i.e., parallel compositions,
event handling, pausing, etc.).

By default, asynchronous bodies do not shared variables with their enclosing
scope.
The optional list of variables makes them visible to the block.

### Asynchronous Block

The asynchronous block (`async`) preserves deterministic execution with the
rules as follows:

1. Resume execution whenever the synchronous side is idle.
2. Yield control to the synchronous side on every complete `loop` iteration.
3. Yield control to the synchronous side on every `emit`.
4. Execute atomically and to completion unless rules `2` and `3` apply.

This rules imply that `async` blocks and the synchronous side never run at the
same time with real parallelism.

Examples:

```ceu
// calculates the factorial of some "v" if it doesn't take too long
var u64  v   = <...>;
var u64  fat = 1;
var bool ok  = false;
watching 1s do
    await async (v,fat) do      // keeps "v" and "fat" visible
        loop i in [1 -> v] do   // reads from "v"
            fat = fat * i;      // writes to "fat"
        end
    end
    ok = true;                  // completed within "1s"
end
```

#### Simulation

An `async` block can emit [input events](#TODO) and the
[passage of time](#TODO) towards the synchronous side, providing a way to test
programs in the language itself.
Every time an `async` emits an event, it suspends until the synchronous side
reacts to the event (see [`rule 1`](#TODO) above).

Examples:

```ceu
input int A;

// tests a program with a simulation in parallel
par do

    // original program
    var int v = await A;
    loop i in [0 -> _[ do
        await 10ms;
        _printf("v = %d\n", v+i);
    end

with

    // input simulation
    async do
        emit A(0);      // initial value for "v"
        emit 1s35ms;    // the loop in the original program executes 103 times
    end
    escape 0;

end

// The example prints the message `v = <v+i>` exactly 103 times.
```

### Asynchronous Thread

Asynchronous threads (`async/thread`) provide real parallelism for applications
in Céu.
Once an `async/thread` starts, it runs completely detached from the synchronous
side.
However, they are still ruled by the synchronous side and are also subject to
abortion.

An `async/thread` evaluates to a boolean value which indicates whether it
started successfully.
The value can be captured with an optional [assignment](#TODO).

Asynchronous threads are non deterministic and require explicit synchronization
on accesses to variables to avoid race conditions.

Examples:

```ceu
// calculates the factorial of some "v" if it doesn't take too long
var u64  v   = <...>;
var u64  fat = 1;
var bool ok  = false;
watching 1s do
    await async/thread (v,fat) do   // keeps "v" and "fat" visible
        loop i in [1 -> v] do       // reads from "v"
            fat = fat * i;          // writes to "fat"
        end
    end
    ok = true;                      // completed within "1s"
end
```

#### Atomic Block

Atomic blocks provide mutual exclusion among threads and the synchronous
side of application.
Once an atomic block starts to execute, no other atomic block in the program
starts.

Examples:

```ceu
// A "race" between two threads: one incrementing, the other decrementing "count".

var s64 count = 0;                              // "count" is a shared variable
par do
    every 1s do
        atomic do
            _printf("count = %d\n", count);     // prints current value of "count" every "1s"
        end
    end
with
    await async/thread (count) do
        loop do
            atomic do
                count = count - 1;              // decrements "count" as fast as possible
            end
        end
    end
with
    await async/thread (count) do
        loop do
            atomic do
                count = count + 1;              // increments "count" as fast as possible
            end
        end
    end
end
```

-------------------------------------------------------------------------------

C Integration
-------------

Céu integrates safely with C, and programs can define and make native calls
seamlessly while avoiding memory leaks and dangling pointers when dealing with
external resources.

Céu provides [native declarations](#TODO) to import C symbols,
[native blocks](#TODO) to define new code in C,
[native statements](#TODO) to inline C statements,
[native calls](#TODO) to call C functions,
and [finalization](#TODO) to deal with C pointers safely:

```ceu
Nat_Symbol ::= native [`/´(pure|const|nohold|plain)] `(´ List_Nat `)´
Nat_Block  ::= native `/´(pre|pos) do
                   <code definitions in C>
               end
Nat_End    ::= native `/´ end

Nat_Stmts  ::= `{´ {<code in C> | `@´ Exp} `}´

Nat_Call   ::= [call] (Name | `(´ Exp `)´)  `(´ [ LIST(Exp)] `)´

List_Nat ::= LIST(ID_nat)

Finalization ::= do [Stmt] Finalize
              |  var `&?´ Type ID_int `=´ `&´ (Call_Nat | Call_Code) Finalize
Finalize ::= finalize `(´ LIST(Name) `)´ with
                 Block
             [ pause  with Block ]
             [ resume with Block ]
             end
```

Native calls and statements transfer the control of the CPU to inlined code in
C, losing the guarantees of the [synchronous model](#TODO).
For this reason, programs should only resort to C for asynchronous
functionality, such as non-blocking I/O, or simple `struct` accessors, but
never for control purposes.

`TODO: Nat_End`

### Native Declaration

In Céu, an [identifier](#TODO) prefixed with an underscore is considered a
native symbol that is defined externally in C.
However, all external symbols must be declared before their first use.

Native declarations support four modifiers as follows:

- `const`: declares the listed symbols as constants.
    Constants can be used as [bounded limits](#TODO) in [vectors](#TODO),
    [pools](#TODO), and [numeric loops](#TODO).
    Also, constants cannot be [assigned](#TODO).
- `plain`: declares the listed symbols as *plain* types, i.e., types (or
    composite types) that do not contain pointers.
    Value of plain types passed as arguments to functions do not require
    [finalization](#TODO).
- `nohold`: declares the listed symbols as *non-holding* functions, i.e.,
    a function that does not retain received pointers as arguments after
    returning.
    Pointers passed to non-holding functions do not require
    [finalization](#TODO).
- `pure`: declares the listed symbols as pure functions.
    In addition to the `nohold` properties, pure functions never allocate
    resources that require [finalization](#TODO) and have no side effects to
    take into account for the [safety checks](#TODO).

Examples:

```ceu
// values
native/const  _LOW, _HIGH;      // Arduino's "LOW" and "HIGH" are constants
native        _errno;           // POSIX's "errno" is a global variable

// types
native/plain  _char;            // "char" is a "plain" type
native        _SDL_PixelFormat; // SDL's "SDL_PixelFormat" is a type holding a pointer

// functions
native        _uv_read_start;   // Libuv's "uv_read_start" retains the received pointer
native/nohold _free;            // POSIX's "free" receives a pointer but does not retain it
native/pure   _strlen;          // POSIX's "strlen" is a "pure" function
```

### Native Block

Native blocks allows programs to define new external symbols in C.

The [compiler of Céu](#TODO) generates as output a program in C, which is
embedded in a host program also in C, which is further compiled to the final
binary program.

The contents of native blocks is not parsed by Céu, but copied unchanged to the
output in C depending on the modifier specified:

- `pre`: code is placed before the declarations for the Céu program.
    Symbols defined in `pre` blocks are visible to Céu.
- `pos`: code is placed after the declarations for the Céu program.
    Symbols defined by Céu are visible to `pos` blocks.

Native blocks are copied in the order they appear in the source code.

Since Céu uses the [C preprocessor](#TODO), `#` directives inside native blocks
must use `##` directives to be considered only in the C compilation phase.

Symbols defined in native blocks still need to be [declared](#TODO) for use in
the program.

Examples:

```ceu
native/plain _t;
native/pre do
    typedef int t;              // definition for "t" is placed before Céu declarations
end
var _t x = 10;                  // requires "t" to be already defined
```

```ceu
input void A;                   // declaration for "A" is placed before "pos" blocks
native _get_A_id;
native/pos do
    int get_A_id (void) {
        return CEU_INPUT_A;     // requires "A" to be already declared
    }
end
```

```ceu
native/nohold _printf;
native/pre do
    ##include <stdio.h>         // include the relevant header for "printf"
end
```

### Native Statement

The contents of native statements in between `{` and `}` are inlined in the
program.

Native statements support interpolation of expressions in Céu which are
expanded when preceded by a `@`.

Examples:

```ceu
var int v_ceu = 10;
{
    int v_c = @v_ceu * 2;       // yields 20
}
v_ceu = { v_c + @v_ceu };       // yields 30
{
    printf("%d\n", @v_ceu);     // prints 30
}
```

### Native Call

Names and expressions that evaluate to a [native type](#TODO) can be called
from Céu.

If a call passes or returns pointers, it may require an accompanying
[finalization statement](#TODO).

Examples:

```ceu
// all expressions evaluate to a native type and can be called

_printf("Hello World!\n");

var _t f = <...>;
f();

var _s s = <...>;
s.f();
```

`TODO: ex. pointer return`

### Finalization

The finalization statement unconditionally executes a series of statements when
its corresponding enclosing block terminates, even if aborted abruptly.

Céu tracks the interaction of native calls with pointers and requires 
`finalize` clauses to accompany them:

- If Céu **passes** a pointer to a native call, the pointer represents a
  **local** resource that requires finalization.
  Finalization executes when the block of the local resource goes out of scope.
- If Céu **receives** a pointer from a native call return, the pointer
  represents an **external** resource that requires finalization.
  Finalization executes when the block of the receiving pointer goes out of
  scope.

In both cases, the program does not compile without the `finalize` statement.

A `finalize` cannot contain [synchronous control statements](#TODO).

Examples:

```ceu
// Local resource finalization
watching <...> do
    var _buffer_t msg;
    <...>                       // prepares msg
    do
        _send_request(&msg);
    finalize with
        _send_cancel(&msg);
    end
    await SEND_ACK;             // transmission is complete
end
```

In the example above, the local variable `msg` is an internal resource passed
as a pointer to `_send_request`, which is an asynchronous call that transmits
the buffer in the background.
If the enclosing `watching` aborts before awaking from the `await SEND_ACK`,
the local `msg` goes out of scope and the external transmission now holds a
*dangling pointer*.
The `finalize` ensures that `_send_cancel` also aborts the transmission.

```ceu
// External resource finalization
watching <...> do
    var&? _FILE f = _fopen(<...>) finalize with
                        _fclose(f);
                    end;
    _fwrite(<...>, f);
    await A;
    _fwrite(<...>, f);
end
```

In the example above, the call to `_fopen` returns an external file resource as
a pointer.
If the enclosing `watching` aborts before awaking from the `await A`, the file
remains open as a *memory leak*.
The `finalize` ensures that `_fclose` closes the file properly.

*Note: the compiler only forces the programmer to write finalization clauses,
       but cannot check if they handle the resource properly.*

`TODO: &?`

[Declaration modifiers](#TODO) and [typecasts](#TODO) may suppress the
requirement for finalization:

- `nohold` modifiers or `/nohold` typecasts make passing pointers safe.
- `pure`   modifiers or `/pure`   typecasts make passing pointers and returning
                                  pointers safe
- `/plain` typecasts make returns safe

Examples:

```ceu
// "_free" does not retain "ptr"
native/nohold _free;
_free(ptr);
// or
(_free as /nohold)(ptr);
```

```ceu
// "_strchr" does retain "ptr" or allocates resources
native/pure _strchr;
var _char&& found = _strchr(ptr);
// or
var _char&& found = (_strchr as /pure)(ptr);
```

```ceu
// "_f" returns a non-pointer type
var _tp v = _f() as /plain;
```

-------------------------------------------------------------------------------

Lua Integration
---------------

Céu also integrates with Lua, providing [Lua states](#TODO) to delimit the
effects of [Lua statements](#TODO) which can be inlined in programs:

```ceu
Lua_State ::= lua `[´ [Exp] `]´ do
                 Block
              end
Lua_Stmts ::= `[´ {`=´} `[´
                  { {<code in Lua> | `@´ Exp} }
              `]´ {`=´} `]´
```

Lua statements transfer the control of the CPU to Lua, losing the guarantees of
the [synchronous model](#TODO).
Like [native statements](#TODO), programs should only resort to Lua for
asynchronous functionality, such as non-blocking I/O, or simple `struct`
accessors, but never for control purposes.

### Lua Statement

The contents of Lua statements in between `[[` and `]]` are inlined in the
program.

Like [native statements](#TODO), Lua statements support interpolation of
expressions in Céu which are expanded when preceded by a `@`.

Lua statements only affect the [Lua state](#TODO) in which they are embedded.

If a Lua statement is used in an [assignment](#TODO), it is evaluated as an
expression that must satisfy the destination.

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

### Lua State

A Lua state creates a separate environment for its embedded
[Lua statements](#TODO).

Programs have an implicit enclosing *global Lua state* which all orphan
statements apply.

Examples:

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

-------------------------------------------------------------------------------

Abstractions
------------

Céu supports reuse with `data` declarations to define new types, and `code`
declarations to define new subprograms.

### Data

The `data` declaration creates a new data type:

```ceu
Data ::= data ID_abs [as (nothing|Exp)] [ with
             { <var_set|vector_set|pool_set|event_set> `;´ {`;´} }
         end ]
```

A declaration may include fields with [storage declarations](#TODO) which
are included in the `data` type and are publicly accessible.
Field declarations may [assign](#TODO) default values for uninitialized
instances.

Data types can form hierarchies using dots (`.`) in identifiers:

- An identifier like `A` makes `A` a base type.
- An identifier like `A.B` makes `A.B` a subtype of its supertype `A`.

A subtype inherits all fields from its supertype.

The optional `as` modifier expects `nothing` or a constant expression of type
`int`:

- `nothing`: the `data` cannot be instantiated.
- *constant expression*: typecasting a value of the type to `int` evaluates to
                         the specified expression.

Examples:

```ceu
data Rect with
    var int x, y, h, w;
    var int z = 0;
end
var Rect r = val Rect(10,10, 100,100, _);  // "r.z" defaults to 0
```

```ceu
data Dir       as nothing;  // "Dir" is a base type and cannot be intantiated
data Dir.Right as  1;       // "Dir.Right" is a subtype of "Dir"
data Dir.Left  as -1;       // "Dir.Left"  is a subtype of "Dir"
var  Dir dir = <...>;       // receives one of "Dir.Right" or "Dir.Left"
escape (dir as int);        // returns 1 or -1
```

See also [data constructor](#TODO).

`TODO: new, pool, recursive types`

### Code

The `code/tight` and `code/await` declarations create new subprograms that can
be [invoked](#TODO) from arbitrary points in programs:

```ceu
// prototype declaration
Code_Tight ::= code/tight Mods ID_abs `(´ Params `)´ `->´ Type
Code_Await ::= code/await Mods ID_abs `(´ Params `)´ [`->´ `(´ Inits `)´] `->´ (Type | FOREVER)

// full declaration
Code_Impl ::= (Code_Tight | Code_Await) do
                  Block
              end

Mods ::= [`/´dynamic] [`/´recursive]

Params ::= void | LIST(Class [ID_int])
Class  ::= [dynamic] var   [`&´] [`/´hold] * Type
        |            vector `&´ `[´ [Exp] `]´ Type
        |            pool   `&´ `[´ [Exp] `]´ Type
        |            event  `&´ (Type | `(´ LIST(Type) `)´)

Inits ::= void | LIST(Class [ID_int])
Class ::= var    (`&´|`&?`) * Type
       |  vector (`&´|`&?`) `[´ [Exp] `]´ Type
       |  pool   (`&´|`&?`) `[´ [Exp] `]´ Type
       |  event  (`&´|`&?`) (Type | `(´ LIST(Type) `)´)

// invocation
Code_Call  ::= call  Mods Code_Cons
Code_Await ::= await Mods Code_Cons_Init
Code_Spawn ::= spawn Mods Code_Cons_Init [in Name]

Mods ::= [`/´dynamic | `/´static] [`/´recursive]
Code_Cons      ::= ID_abs `(´ LIST(Data_Cons|Vec_Cons|Exp|`_´) `)´
Code_Cons_Init ::= Code_Cons [`->´ `(´ LIST(`&´ Var) `)´])
```

A `code/tight` is a subprogram that cannot contain
[synchronous control statements](#TODO) and runs to completion in the current
[internal reaction](#TODO).

A `code/await` is a subprogram with no restrictions (e.g., it can manipulate
events and use parallel compositions) and its execution may outlive multiple
reactions.

A *prototype declaration* specifies the interface parameters of the
abstraction which code invocations must satisfy.
A *full declaration* (a.k.a. *definition*) also specifies an implementation
with a block of code.
An *invocation* specifies the name of the code abstraction and arguments
matching its declaration.

To support recursive abstractions, a code invocation can appear before the
implementation is known, but after the prototype declaration.
In this case, the declaration must use the modifier `recursive`.

Examples:

```ceu
code/tight Absolute (var int v) -> int do   // declares the prototype for "Absolute"
    if v > 0 then                           // implements the behavior
        escape  v;
    else
        escape -v;
    end
end
var int abs = call Absolute(-10);           // invokes "Absolute" (yields 10)
```

```ceu
code/await Hello_World (void) -> FOREVER do
    every 1s do
        _printf("Hello World!\n");  // prints "Hello World!" every second
    end
end
await Hello_World();                // never awakes
```

```ceu
code/tight/recursive Fat (var int v) -> int;    // "Fat" is a recursive code
code/tight/recursive Fat (var int v) -> int do
    if v > 1 then
        escape v * (call/recursive Fat(v-1));   // recursive invocation before full declaration
    else
        escape 1;
    end
end
var int fat = call/recursive Fat(10);           // invokes "Fat" (yields 3628800)
```

`TODO: hold`

#### Code Declaration

Code abstractions specify a list of input parameters in between `(` and `)`.
Each parameter specifies a [storage class](#TODO) with modifiers, a type and
an identifier (optional in declarations).
A `void` list specifies that the code has no parameters.

Code abstractions also specify an output return type.
A `code/await` may use `FOREVER` to indicate that the code never returns.

A `code/await` may also specify an optional *initialization return list*, which
represents local resources created in the outermost scope of its body.
These resources are exported and bound to aliases in the invoking context which
may access them while the code executes:

- The invoker passes a list of unbound aliases to the code.
- The code [binds](#TODO) the aliases to the local resources before any
  [synchronous control statement](#TODO) executes.

If the code does not terminate (i.e., return type is `FOREVER`), the
initialization list specifies normal `&` aliases.
Otherwise, since the code may terminate and deallocated the resource, the list
must specify option `&?` aliases.

Examples:

```ceu
// "Open" abstracts
code/await Open (var _char&& path) -> (var& _FILE res) -> FOREVER do
    var&? _FILE res_ = _fopen(path, <...>)  // allocates resource
                       finalize with
                           _fclose(res_!);  // releases resource
                       end;
    res = &res_!;                           // exports resource to invoker
    await FOREVER;
end

var& _FILE res;                             // declares resource
spawn Open(<...>) -> (&res);                // initiliazes resource
<...>                                       // uses resource
```

#### Code Invocation

A `code/tight` is invoked with a `call` followed by the abstraction name and
list of arguments.
A `code/await` is invoked with an `await` or `spawn` followed by the
abstraction name and list of arguments.

The list of arguments must satisfy the list of parameters in the
[code declaration](#TODO).

The `call` and `await` invocations suspend the ongoing computation and transfer
the execution control to the code abstraction.
The invoking point only resumes after the abstraction terminates and evaluates
to a value of the [return type](#TODO) which can be captured with an optional
[assignment](#TODO).

The `spawn` invocation also suspends and transfers control to the code
abstraction.
However, when the abstraction becomes idle (or terminates), the invoking point
resumes.
This allows the invocation point and the abstraction to execute concurrently.

The `spawn` invocation accepts an optional list of aliases matching the
[initialization list](#TODO) in the code abstraction.
These aliases are bound to local resources in the code and can be accessed
from the invocation point.

The `spawn` invocation also accepts an optional [pool](#TODO) which provides
storage and scope for invoked abstractions.
In this case, the invocation evaluates to a boolean that indicates if the pool
has space to execute the code.
The result can be captured with an optional [assignment](#TODO).
If the pool goes out of scope, all invoked abstractions invoked at that pool
are aborted.
If the `spawn` omits the pool, the invocation always succeed and has the same
scope as the invoking point: when the enclosing block terminates, the invoked
code is aborted.

#### Dynamic Dispatching

Céu supports dynamic code dispatching based on multiple parameters.

The `/dynamic` modifier in a declaration specifies that the code is dynamically
dispatched.
A dynamic code must have at least one `dynamic` parameter.
Also, all dynamic parameters must be pointers or aliases to a
[data type](#TODO) in some hierarchy.

A dynamic declaration requires other compatible dynamic declarations with the
same name, modifiers, parameters, and return type.
The exceptions are the `dynamic` parameters, which must be in the same
hierarchy of their corresponding parameters in other declarations.

To determine which declaration to execute during runtime, the actual argument
is checked against the first formal `dynamic` parameter of each declaration.
The declaration with the most specific type matching the argument wins.
In the case of a tie, the next dynamic parameter is checked.

A *catchall* declaration with the most general dynamic types must always be
provided.

Examples:

```ceu
data Media as nothing;
data Media.Audio with <...> end
data Media.Video with <...> end

code/await/dynamic Play (dynamic var& Media media) -> void do
    _assert(0);             // never dispatched
end
code/await/dynamic Play (dynamic var& Media.Audio media) -> void do
    <...>                   // plays an audio
end
code/await/dynamic Play (dynamic var& Media.Video media) -> void do
    <...>                   // plays a video
end

var& Media m = <...>;       // receives one of "Media.Audio" or "Media.Video"
await/dynamic Play(&m);     // dispatches the appropriate subprogram to play the media
```

-------------------------------------------------------------------------------

Assignments
-----------

`TODO: copy vs binding`

```ceu
Set ::= (Name | `(´ LIST(Name|`_´) `)´) `=´ Cons

Cons ::= ( Do
         | Await
         | Emit_Ext
         | Watching
         | Async_Thread
         | Lua_State
         | Lua_Stmts
         | Code_Await
         | Code_Spawn
         | Vec_Cons
         | Data_Cons
         | `_´
         | Exp )

Vec_Cons  ::= (Exp | `[´ [LIST(Exp)] `]´) { `..´ (Exp | Lua_Stmts | `[´ [LIST(Exp)] `]´) }
Data_Cons ::= (val|new) ID_abs `(´ LIST(Data_Cons|Vec_Cons|Exp|`_´) `)´
```

### Vector Constructor

`TODO:`

### Lua Assignment

A [Lua statement](#TODO) evaluates to an expression that either satisfies the
destination or generates a runtime error.
The list that follows specifies the *Céu destination* and expected
*Lua source*:

- a `var` `bool`              expects a `boolean`
- a [numeric](#TODO) `var`    expects a `number`
- a pointer `var`             expects a `lightuserdata`
- a `vector` `byte`           expects a `string`

`TODO: lua state captures errors`

### Data Constructor

A new *static value* is created with the `data` name followed by a list of
arguments matching its fields in the contexts as follows:

- Prefixed by `val` in an [assignment](#TODO) to a variable.
- As an argument to a [`code` instantiation](#TODO).
- Nested as an argument in a `data` creation.

In all cases, the arguments are copied to an explicit destination with static
storage.
The destination must be a plain declaration, and not an alias or pointer.

Variables of the exact same type can be copied in [assignments](#TODO).
The rules for assignments from a subtype to a supertype are as follows:

- [Copy assignments](#TODO) for plain values is only allowed if the subtype
                            is the same size as the supertype (i.e., no extra
                            fields).
- [Copy assignments](#TODO) for pointers is allowed.
- [Binding assignment](#TODO) is allowed.

```ceu
data Object with
    var Rect rect;
    var Dir  dir;
end
var Object o1 = val Object(Rect(0,0,10,10,_), Dir.Right());
```

```ceu
var Object o2 = o1;         // makes a deep copy of all fields from "o1" to "o2"
```

-------------------------------------------------------------------------------

Synchronous Control Statements
------------------------------

The *synchronous control statements*
`await`, `spawn`, `emit` (internal events), `every`, `finalize`, `pause/if`,
`par`, `par/and`, `par/or`, and `watching`
cannot appear in
[event iterators](#TODO),
[pool iterators](#TODO),
[asynchronous execution](#TODO),
[finalization](#TODO),
and
[tight code abstractions](#TODO).

As exceptions, an `every` can `emit` internal events, and a `code/tight` can
contain empty `finalize` statements.
