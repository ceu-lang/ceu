## References

Céu supports *aliases* and *pointers* as [references](#TODO).

### Aliases

An alias is acquired by prefixing a [native call](#TODO) or a [location](#TODO)
with the operator `&`:

```ceu
Alias ::= `&´ (Nat_Call | Loc)
```

See also the [unwrapping operator](#TODO) `!` for option variable aliases.

### Pointers

The operator `&&` returns the address of a [location](#TODO), while the
operator `*` dereferences a pointer:

```
Addr  ::= `&&´ Loc
Deref ::= `*´ Loc
```
