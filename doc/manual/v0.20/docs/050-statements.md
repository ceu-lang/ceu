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

-------------------------------------------------------------------------------

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

See also [Code Pools](#TODO) and [Data Pools](#TODO).

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

### Simple Loops

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

### Pool Iterators

Pool iterators are dicussed in [Code Pools](#TODO).

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

Watching ::= watching LIST(ID_ext|Name|WCLOCKK|WCLOCKE|Code2) do
                 Block
             end

```

They differ only on how trails rejoin and terminate the composition.

The `watching` statement terminates when one of its listed events occur.

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

Asynchronous blocks can contain [tight loops](#TODO) but which keep the
application reactive to incoming events.
However, they do not support nesting of asynchronous statements, and do not
support synchronous control statements (i.e., parallel compositions, event
handling, pausing, etc.).

By default, asynchronous blocks do not shared variables with their enclosing
scope.
The optional list of variables makes them visible to the block.

### Asynchronous Blocks

Asynchronous blocks (`async`) preserve deterministic execution with the rules
as follows:

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

### Asynchronous Threads

Asynchronous threads (`async/thread`) provide real parallelism for applications
in Céu.
Once an `async/thread` starts, it runs completely detached from the synchronous
side.
However, they are still ruled by the synchronous side and are also subject to
abortion.

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

Asynchronous threads are non deterministic and require explicit synchronization
on accesses to variables to avoid race conditions.

#### Atomic Blocks

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

The [compiler of Céu](#TODO) generates as output a program in C, which is
embedded in a host program also in C, which is further compiled to the final
binary program.

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

### Native Declarations

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

### Native Blocks

Native blocks allows programs to define new external symbols in C.

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

### Native Statements

The contents of native statements in between `{` and `}` are inlined in the
output in C.

Native statements support interpolation of expressions in Céu which are
expanded in the generated output in C when preceded by a `@`.

Examples:

```ceu
var int v = 10;
{
    printf("v = %d\n", @v);     // prints "v = 10"
};
```

### Native Calls

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

`TODO: pointer return`

### Finalization

The finalization statement unconditionally executes a series of
[non-yielding statements](#TODO) when its corresponding enclosing block
terminates, even if aborted abruptly.

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
    _fwrite(..., f);
    await A;
    _fwrite(..., f);
end
```

In the example above, the call to `_fopen` returns an external file resource as
a pointer.
If the enclosing `watching` aborts before awaking from the `await A`, the file
remains open as a *memory leak*.
The `finalize` ensures that `_fclose` closes the file properly.

*Note: the compiler only forces the programmer to write finalization clauses,
       but cannot check if they handle the resource properly.*

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

`TODO`

-------------------------------------------------------------------------------

Abstractions
------------

`TODO`
