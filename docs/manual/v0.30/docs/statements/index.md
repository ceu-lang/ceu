# Statements

A program in Céu is a sequence of statements delimited by an implicit enclosing
block:

```ceu
Program ::= Block
Block   ::= {Stmt `;´}
```

*Note: statements terminated with the `end` keyword do not require a
terminating semicolon.*

{!statements/nothing.md!}

{!statements/blocks.md!}

{!statements/declarations.md!}

{!statements/assignments.md!}

{!statements/event_handling.md!}

{!statements/conditional.md!}

{!statements/loops.md!}

{!statements/parallel_compositions.md!}

{!statements/pausing.md!}

{!statements/exceptions.md!}

{!statements/asynchronous_execution.md!}

{!statements/c_integration.md!}

{!statements/lua_integration.md!}

{!statements/abstractions.md!}

{!statements/synchronous_control_statements.md!}
