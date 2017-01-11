# Introduction

Céu provides *Structured Synchronous Reactive Programming* extending classical
structured programming with two main functionalities:

- An `await` statement to suspend a line of execution until the specified input
  event occurs.
- A set of parallel constructs to compose concurrent lines of execution.

The lines of execution in Céu, known as *trails*, react together to input
events continuously and in discrete steps.
An input event is broadcast to all active trails, which share the event as
their unique and global time reference.

The example that follows prints "Hello World!" every second and terminates on a
key press:

```ceu
input int KEY;
par/or do
    loop do
        await 1s;
        _printf("Hello World!\n");
    end
with
    await KEY;
end
```

The synchronous concurrency model of Céu greatly diverges from multithreaded
and actor-based models (e.g. *pthreads* and *erlang*).
On the one hand, there is no real parallelism at the synchronous kernel of the
language (i.e., no multi-core execution).
On the other hand, accesses to shared variables among trails are deterministic
and do not require synchronization primitives (i.e., *locks* or
*queues*).

Céu provides static memory management based on lexical scopes and does not
require a garbage collector.

Céu integrates safely with C, particularly when manipulating external resources
(e.g., file handles).
Programs can make native calls seamlessly while avoiding common pitfalls such
as memory leaks and dangling pointers.

Céu is [free software](#TODO).
