# Introduction

Céu provides *Structured Synchronous Reactive Programming* which supports
safe and deterministic concurrency with side effects.
The lines of execution in Céu, known as *trails*, react together continuously
and in synchronous steps to external input events from the environment.
Waiting for an event halts the running trail until that event occurs.
The environment broadcasts an occurring event to all active trails, which share 
a single global time reference.

The synchronous concurrency model of Céu diverges from multithreading and also
from actor-based models (e.g. *pthreads* and *erlang*).
On the one hand, there is no real parallelism at the synchronous kernel of the
language (i.e., no multi-core execution).
On the other hand, trails can share variables deterministically without
synchronization primitives (i.e., no *locks*, *semaphores*, or *queues*).

Céu provides automatic memory management based on static lexical scopes (i.e.,
no *free* or *delete*) and does not require runtime garbage collection.

Céu integrates safely with C, and programs can define and make native calls
seamlessly while avoiding memory leaks and dangling pointers when dealing with
external resources.

Céu is [free software](#TODO).
