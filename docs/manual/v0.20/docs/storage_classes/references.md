## References

Céu supports *aliases* and *pointers* as references to entities, aka *strong*
and *weak* references, respectively.

An alias is an alternate view for an entity: after the entity and alias are
bounded, they are indistinguishable.

A pointer is a value that is the address of an entity, providing indirect
access to it.

As an analogy with a person's identity,
a family nickname referring to a person is an alias;
a job position referring to a person is a pointer.

### Aliases

An alias is declared by suffixing the storage class with the modifier
`&` and is acquired by prefixing an entity with the operator `&`.

A [native resource](#TODO) maps to an option alias variable in Céu.
An option alias is declared as `var&?` and is acquired by prefixing a
[native call](#TODO) with the operator `&`.

Examples:

```
// alias
var  int v = 0;
var& int a = &v;        // "a" is an alias to "v"
...
a = 1;                  // "a" and "v" are indistinguishable
_printf("%d\n", v);     // prints 1
```

```
// option alias
var&? _FILE f = &_fopen(<...>) finalize with
                    _fclose(f);
                end;
```

An alias must have a narrower scope than the entity it refers to.
The [assignment](#TODO) to the alias is immutable and must occur between its
declaration and first access or next [yielding statement](#TODO).
It is not possible to acquire aliases to external events or to pointer types.

### Pointers

A pointer is declared by suffixing the type with the modifier
`&&` and is acquired by prefixing an entity with the operator `&&`.
Applying the operator `*` to a pointer provides indirect access to its
referenced entity.

Example:

```
var int   v = 0;
var int&& p = &&v;      // "p" holds a pointer to "v"
...
*p = 1;                 // "p" provides indirect access to "v"
_printf("%d\n", v);     // prints 1
```

The following restrictions apply to pointers in Céu:

<!--
- Only pointers to [primitive](#TODO) and [data abstraction](#TODO) types
  are valid.
-->
- No support for pointers to events, vectors, or pools (only variables).
- A pointer is only accessible between its declaration and the next
  [yielding statement](#TODO).
