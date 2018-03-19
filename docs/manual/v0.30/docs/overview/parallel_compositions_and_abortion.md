## Parallel Compositions and Abortion

The use of trails in parallel allows programs to wait for multiple events at 
the same time.
Céu supports three kinds of parallel compositions that differ in how they
rejoin and proceed to the statement in sequence:

1. a `par/and` rejoins after all trails in parallel terminate;
2. a `par/or` rejoins after any trail in parallel terminates, aborting all
   other trails automatically;
3. a `par` never rejoins, even if all trails terminate.

As mentioned in the introduction and emphasized in the execution model, trails
in parallel do not execute with real parallelism.
Therefore, it is important to note that parallel compositions support
*awaiting in parallel*, rather than *executing in parallel* (see
[Asynchronous Threads](statements/#thread) for real parallelism support).
<!--
The termination of a trail inside a `par/or` aborts the other trails in 
parallel which are necessarily idle
(see [`rule 2` for external reactions](#synchronous-execution-model)).
Before being aborted, a trail has a last opportunity to execute active 
[finalization statements](#TODO).
-->
