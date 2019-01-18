# Overview

Céu provides *Structured Synchronous Reactive Programming* with the following
general characteristics:

- *Reactive*:    code executes in reactions to events.
- *Structured*:  code uses structured control-flow mechanisms, such as `spawn`
                 and `await` (to create and suspend lines of execution).
- *Synchronous*: event reactions run atomically and to completion on each line
                 of execution.

<!--
- Event Handling:
    - An `await` statement to suspend a line of execution and wait for an input
      event from the environment.
    - An `emit` statement to signal an output event back to the environment.
- Concurrency:
    - A set of parallel constructs to compose concurrent lines of execution.
-->

The lines of execution in Céu, known as *trails*, react all together to input
events one after another, in discrete steps.
An input event is broadcast to all active trails, which share the event as an
unique and global time reference.

The example in Céu that follows blinks a LED every second and terminates on a
button press:

```ceu
input  none   BUTTON;
output on/off LED;
par/or do
    await BUTTON;
with
    loop do
        await 1s;
        emit LED(on);
        await 1s;
        emit LED(off);
    end
end
```

The synchronous concurrency model of Céu greatly diverges from multithreaded
and actor-based models (e.g. *pthreads* and *erlang*).
On the one hand, there is no preemption or real parallelism at the synchronous
core of the language (i.e., no multi-core execution).
On the other hand, accesses to shared variables among trails are deterministic
and do not require synchronization primitives (i.e., *locks* or
*queues*).

Céu provides static memory management based on lexical scope and does not
require a garbage collector.

Céu integrates safely with C, particularly when manipulating external resources
(e.g., file handles).
Programs can make native calls seamlessly while avoiding common pitfalls such
as memory leaks and dangling pointers.

Céu is [free software](license/#license).

{!overview/environments.md!}

{!overview/synchronous_execution_model.md!}

{!overview/parallel_compositions_and_abortion.md!}

{!overview/bounded_execution.md!}

{!overview/deterministic_execution.md!}

{!overview/internal_reactions.md!}
