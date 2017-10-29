## Bounded Execution

Reaction chains must run in bounded time to guarantee that programs are 
responsive and can handle incoming input events.
For this reason, Céu requires every path inside the body of a `loop` statement
to contain at least one `await` or `break` statement.
This prevents *tight loops*, which are unbounded loops that do not await.

In the example that follow, if the condition is false, the true branch of the
`if` never executes, resulting in a tight loop:

```ceu
loop do
    if <cond> then
        break;
    end
end
```

Céu warns about tight loops in programs at compile time.
For computationally-intensive algorithms that require unrestricted loops (e.g.,
cryptography, image processing), Céu provides
[Asynchronous Execution](statements/#asynchronous-execution).
