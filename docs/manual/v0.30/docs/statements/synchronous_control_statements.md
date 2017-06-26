## Synchronous Control Statements

The *synchronous control statements* which follow cannot appear in
[event iterators](#event-iterator),
[pool iterators](#pool-iterator),
[asynchronous execution](#asynchronous-execution),
[finalization](#resources-finalization),
and
[tight code abstractions](#code):
`await`, `spawn`, `emit` (internal events), `every`, `finalize`, `pause/if`,
`par`, `par/and`, `par/or`, and `watching`.

As exceptions, an `every` can `emit` internal events, and a `code/tight` can
contain empty `finalize` statements.
