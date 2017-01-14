# Statements

A program in Céu is a sequence of statements delimited by an implicit enclosing
block:

```ceu
Program ::= Block
Block   ::= {Stmt `;´} {`;´}
```

*Note: statements terminated with the `end` keyword do not require a
terminating semicolon.*
