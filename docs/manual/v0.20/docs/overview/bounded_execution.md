## Bounded Execution

Reaction chains must run in bounded time to guarantee that programs are 
responsive and can handle upcoming input events from the environment.
For this reason, Céu requires every path inside the body of a `loop` statement
to contain at least one `await` or `break` statement.
This prevents *tight loops*, i.e., unbounded loops that do not await.

In the example below, the true branch of the `if` may never execute, resulting
in a tight loop when the condition is false:

```ceu
loop do
    if <cond> then
        break;
    end
end
```

Céu complains about tight loops in programs at compile time.
For time-consuming algorithms that require unrestricted loops (e.g., 
cryptography, image processing), Céu provides [Asynchronous 
Execution](#TODO).
