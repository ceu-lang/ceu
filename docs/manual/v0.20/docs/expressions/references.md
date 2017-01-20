## References

Céu supports *aliases* and *pointers* as
[references](../storage_classes/#references).

### Aliases

An alias is acquired by prefixing a [native call](../statements/#native-call)
or a [location](../storage_classes/#locations) with the operator `&`:

```ceu
Alias ::= `&´ (Nat_Call | Loc)
```

See also the [unwrap operator](#option) `!` for option variable aliases.

### Pointers

The operator `&&` returns the address of a
[location](../storage_classes/#locations), while the operator `*` dereferences
a pointer:

```
Addr  ::= `&&´ Loc
Deref ::= `*´ Loc
```
