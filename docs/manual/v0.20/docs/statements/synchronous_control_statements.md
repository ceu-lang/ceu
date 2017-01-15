## Synchronous Control Statements

The *synchronous control statements* which follow cannot appear in
[event iterators](#TODO),
[pool iterators](#TODO),
[asynchronous execution](#TODO),
[finalization](#TODO),
and
[tight code abstractions](#TODO):
`await`, `spawn`, `emit` (internal events), `every`, `finalize`, `pause/if`,
`par`, `par/and`, `par/or`, and `watching`.

As exceptions, an `every` can `emit` internal events, and a `code/tight` can
contain empty `finalize` statements.
