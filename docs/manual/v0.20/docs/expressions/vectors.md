## Vectors

### Index

Céu uses square brackets to index [vectors](#Vectors):

```
Index ::= Loc `[´ Exp `]´
```

The index expression must be of type [`usize`](#TODO).

Vectors start at index zero.
Céu generates an [error](#TODO) for out-of-bounds vector accesses.

### Length

The operator `$` returns the current length of a vector, while the operator
`$$` returns the max length:

```
Cur ::= `$´  Loc
Max ::= `$$´ Loc
```

`TODO: max`
