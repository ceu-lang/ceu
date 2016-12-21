## Asynchronous Execution

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

`TODO: isr`

### Asynchronous Interrupt Service Routine

`TODO`
