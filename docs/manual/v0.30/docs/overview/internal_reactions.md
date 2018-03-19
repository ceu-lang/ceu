## Internal Reactions

Céu supports inter-trail communication through `await` and `emit` statements
for *internal events*.
A trail can `await` an internal event to suspend it.
Then, another trail can `emit` and broadcast an event, awaking all trails
awaiting that event.

Unlike input events, multiple internal events can coexist during an external
reaction.
An `emit` starts a new *internal reaction* in the program which relies on a
runtime stack:

1. The `emit` suspends the current trail and its continuation is pushed into
    the stack (i.e., the statement in sequence with the `emit`).
2. All trails awaiting the emitted event awake and execute in sequence
    (see [`rule 2`](#synchronous-execution-model) for external reactions).
    If an awaking trail emits another internal event, a nested internal
    reaction starts with `rule 1`.
3. The top of the stack is popped and the last emitting trail resumes execution
    from its continuation.

The program as follow illustrates the behavior of internal reactions in Céu:

```ceu
1:  par/and do      // trail 1
2:      await e;
3:      emit f;
4:  with            // trail 2
5:      await f;
6:  with            // trail 3
7:      emit e;
8:  end
```

The program starts in the boot reaction with an empty stack and forks into the
three trails.
Respecting the lexical order, the first two trails `await` and the third trail
executes:

- The `emit e` in *trail-3* (line 7) starts an internal reaction (`stack=[7]`).
- The `await e` in *trail-1* awakes (line 2) and then the `emit f` (line 3)
  starts another internal reaction (`stack=[7,3]`).
- The `await f` in *trail-2* awakes and terminates the trail (line 5).
  Since no other trails are awaiting `f`, the current internal reaction
  terminates, resuming and popping the top of the stack (`stack=[7]`).
- The `emit f` resumes in *trail-1* and terminates the trail (line 3).
  The current internal reaction terminates, resuming and popping the top of the
  stack (`stack=[]`).
- The `emit e` resumes in *trail-3* and terminates the trail (line 7).
  Finally, the `par/and` rejoins and the program terminates.
