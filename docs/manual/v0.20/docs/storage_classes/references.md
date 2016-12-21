## References

Céu supports *aliases* and *pointers* as references to entities
(a.k.a. as *strong* and *weak* references, respectively).

An alias is an alternate view for an entity---after the entity and alias are
bounded, they are indistinguishable.
A pointer is the address of an entity and provides indirect access to it.

As an analogy with a person's identity,
a family nickname used by her family to refer to her is an alias;
a job position used by her company to refer to her is a pointer.

### Aliases

An alias is [declared](#TODO) by suffixing the storage class with the modifier
`&` and is acquired by prefixing an entity with the operator `&`.

Example:

```
var  int v = 0;
var& int a = &v;        // "a" is an alias to "v"
...
a = 1;                  // "a" and "v" are indistinguishable
_printf("%d\n", v);     // prints 1
```

An alias must have a narrower scope than the entity it refers to.
The [assignment](#TODO) to the alias is immutable and must occur between its
declaration and first access or next [yielding statement](#TODO).
It is not possible to acquire aliases to external events or to pointer types.

`TODO: &?`

### Pointers

A pointer is [declared](#TODO) by suffixing the type with the modifier
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

Céu only supports pointers to [primitive](#TODO) and
[data abstraction](#TODO) types.
Also, it is only possible to acquire pointers to variables (not to events,
vectors, or pools).
However, a variable of a pointer type is only visible between its declaration
and the next [yielding statement](#TODO).
