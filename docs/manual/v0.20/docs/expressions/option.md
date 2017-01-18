## Option

The operator `?` checks if the [location](#TODO) of an [option type](#TODO) is
set, while the operator `!` unwraps the location, raising an [error](#TODO) if
it is unset:

```ceu
Check  ::= Loc `?´
Unwrap ::= Loc `!´
```
