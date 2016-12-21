## Pausing

The `pause/if` statement controls if its body should temporarily stop to react
to events:

```ceu
Pause_If ::= pause/if (Name|ID_ext) do
                 Block
             end

Pause_Await ::= await (pause|resume)
```

A `pause/if` determines a pausing event of type `bool` which, when emitted,
toggles between pausing (`true`) and resuming (`false`) reactions for its body.

When its body terminates, the whole `pause/if` terminates and proceeds to the
statement in sequence.

In transition points, the body can react to the special `pause` and `resume`
events before the corresponding state applies.

`TODO: finalize/pause/resume`

Examples:

```ceu
event bool e;
pause/if e do       // pauses/resumes the nested body on each "e"
    every 1s do
        <...>       // does something every "1s"
    end
end
```

```ceu
event bool e;
pause/if e do               // pauses/resumes the nested body on each "e"
    <...>
        loop do
            await pause;
            <...>           // does something before pausing
            await resume;
            <...>           // does something before resuming
        end
    <...>
end
```

<!--
*Note: The timeouts for timers remain frozen while paused.*
-->
