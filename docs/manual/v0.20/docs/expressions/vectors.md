## Vectors

### Index

Céu uses square brackets to index [vectors](#Vectors):

```
Vec_Idx ::= Loc `[´ Exp `]´
```

The index expression must be of type [`usize`](#TODO).

Vectors start at index zero.
Céu generates an [error](#TODO) for out-of-bounds vector accesses.

### Length

The operator `$` returns the current length of a vector, while the operator
`$$` returns the max length:

```
Vec_Len ::= `$´  Loc
Vec_Max ::= `$$´ Loc
```

`TODO: max`

### Constructor

Vector constructors are only valid in [assignments](#TODO):

```ceu
Vec_Cons ::= (Exp | `[´ [LIST(Exp)] `]´) { `..´ (Exp | Lua_Stmts | `[´ [LIST(Exp)] `]´) }
```
