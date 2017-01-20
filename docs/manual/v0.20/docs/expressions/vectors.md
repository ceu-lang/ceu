## Vectors

### Index

Céu uses square brackets to index [vectors](#Vectors):

```
Vec_Idx ::= Loc `[´ Exp `]´
```

The index expression must be of type [`usize`](../types/#primitives).

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

Vector constructors are only valid in [assignments](../statements/#assignments):

```ceu
Vec_Cons ::= (Exp | `[´ [LIST(Exp)] `]´) { `..´ (Exp | Lua_Stmts | `[´ [LIST(Exp)] `]´) }
```

Examples:

```ceu
vector[3] int v;     // declare an empty vector of length 3     (v = [])
v = v .. [8];        // append value '8' to the empty vector    (v = [8])
v = v .. [1] .. [5]; // append values '1' and '5' to the vector (v = [8, 1, 5])
```
