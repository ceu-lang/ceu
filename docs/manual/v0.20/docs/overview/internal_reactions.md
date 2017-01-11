## Internal Reactions

Céu supports inter-trail communication through `await` and `emit` statements
for *internal events*.
A trail can `await` an internal event to suspend it.
Then, another trail can `emit` and broadcast an event, awaking all trails
awaiting that event.

An `emit` starts a new *internal reaction* in the program, relying on a
runtime stack:

1. An `emit` suspends the current trail and its continuation is pushed into the
    stack (i.e., the statement in sequence with the `emit`).
2. All trails awaiting the emitted event awake and execute
    (see [`rule 2` for external reactions](#synchronous-execution-model)).
3. The top of stack is popped and the last emitting trail resumes execution
    from its continuation.

Note that if an awaking trail emits another internal event (in `rule 2`), a
nested internal reaction starts (in `rule 1`).
Example:

```ceu
1:  par/and do
2:      await e;
3:      emit f;
4:  with
5:      await f;
6:  with
7:      ...
8:      emit e;
9:  end
```

The `emit e` in *trail-3* (line 8) starts an internal reaction that awakes the 
`await e` in *trail-1* (line 2).
Then, the `emit f` (line 3) starts another internal reaction that awakes the 
`await f` in *trail-2* (line 5).
*Trail-2* terminates and the `emit f` resumes in *trail-1*.
*Trail-1* terminates and the `emit e` resumes in *trail-3*.
*Trail-3* terminates.
Finally, the `par/and` rejoins and the program terminates.
