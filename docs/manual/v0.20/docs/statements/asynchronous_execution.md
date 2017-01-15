## Asynchronous Execution

Asynchronous execution allow programs to departure from the rigorous
synchronous model and preform computations under separate scheduling rules.

Céu supports *asynchronous blocks*, *threads*, and
*interrupt service routines*:

```ceu
Async  ::= await async [ `(´LIST(Var)`)´ ] do
               Block
           end

Thread ::= await async/thread [ `(´LIST(Var)`)´ ] do
               Block
           end

Isr ::= spawn async/isr `[´ LIST(Exp) `]´ [ `(´ LIST(Var) `)´ ] do
            Block
        end

Atomic ::= atomic do
               Block
           end
```

Asynchronous execution supports [tight loops](#TODO) while keeping the rest of
the application, aka the *synchronous side*, reactive to incoming events.
However, it does not support any [synchronous control statement](#TODO) (e.g.,
parallel compositions, event handling, pausing, etc.).

By default, asynchronous bodies do not share variables with their enclosing
scope, but the optional list of variables makes them visible to the block.

Even though asynchronous blocks execute in separate, they are still managed by
the program hierarchy and are also subject to lexical scope and abortion.

<!--
 execute time consuming computations 
without interfering with the responsiveness of the  *synchronous side* of
applications (i.e., all core language statements):

The program awaits the termination of the asynchronous `Block` body to proceed to the
statement in sequence.
-->

### Asynchronous Block

Asynchronous blocks, aka *asyncs*, intercalate execution with the synchronous
side as follows:

1. Start/Resume whenever the synchronous side is idle.
   When multiple *asyncs* are active, they execute in lexical order.
2. Suspend after each `loop` iteration.
3. Suspend on every input `emit` (see [Simulation](#TODO)).
4. Execute atomically and to completion unless rules `2` and `3` apply.

This rules imply that *asyncs* never execute with real parallelism with the
synchronous side, preserving determinism in the program.

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

An `async` block can emit [input and timer events](#TODO) towards the
synchronous side, providing a way to test programs in the language itself.
Every time an `async` emits an event, it suspends until the synchronous side
reacts to the event (see [`rule 1`](#TODO) above).

Examples:

```ceu
input int A;

// tests a program with input simulation in parallel
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

### Thread

Threads provide real parallelism for applications in Céu.
Once started, a thread executes completely detached from the synchronous side.
For this reason, thread execution is non deterministic and require explicit
[atomic blocks](#TODO) on accesses to variables to avoid race conditions.

A thread evaluates to a boolean value which indicates whether it started
successfully or not.
The value can be captured with an optional [assignment](#TODO).

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

### Asynchronous Interrupt Service Routine

`TODO`

### Atomic Block

Atomic blocks provide mutual exclusion among threads, interrupts, and the
synchronous side of application.
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
