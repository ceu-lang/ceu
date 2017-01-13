## Conditional

The `if-then-else` statement provides conditionals in Céu:

```ceu
If ::= if Exp then
           Block
       { else/if Exp then
           Block }
       [ else
           Block ]
       end
```

Each condition `Exp` is tested in sequence, first for the `if` clause and then
for each of the optional `else/if` clauses.
For the first condition that evaluates to `true`, the `Block` following it
executes.
If all conditions fail, the optional `else` clause executes.

All conditions must evaluate to a value of type [`bool`](#TODO), which is
checked at compile time.
