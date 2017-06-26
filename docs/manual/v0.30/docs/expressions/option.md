## Option

The operator `?` checks if the [location](../storage_entities/#locations) of an
[option type](../types/#option) is set, while the operator `!` unwraps the
location, raising an [error](#TODO) if it is unset:

```ceu
Check  ::= Loc `?´
Unwrap ::= Loc `!´
```
