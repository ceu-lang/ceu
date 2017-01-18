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

Céu support aliases to all storage classes, except external events and pointer
types.
Céu also supports option variable aliases which are aliases that may remain or
become unassigned.

An alias is declared by suffixing the storage class with the modifier
`&` and is acquired by prefixing an entity with the operator `&`.

An alias must have a narrower scope than the entity it refers to.
The [assignment](#TODO) to the alias is immutable and must occur between its
declaration and first access or next [yielding statement](#TODO).

Example:

```ceu
var  int v = 0;
var& int a = &v;        // "a" is an alias to "v"
...
a = 1;                  // "a" and "v" are indistinguishable
_printf("%d\n", v);     // prints 1
```

An option variable alias, declared as `var&?`, serves two purposes:

- Map a [native resource](#TODO) to a variable in Céu.
  The alias is acquired by prefixing the associated [native call](#TODO) with
  the operator `&`.
  Since the allocation may fail, the alias may remain unassigned.
- Track the lifetime of a variable.
  The alias is acquired by prefixing the associated variable with
  the operator `&`.
  Since the tracked variable may go out of scope, the alias may become
  unassigned.

Accesses to option variable aliases must always use
[option checking or unwrapping](#TODO).

Examples:

```ceu
var&? _FILE f = &_fopen(<...>) finalize with
                    _fclose(f);
                end;
if f? then
    <...>   // "f" is assigned
else
    <...>   // "f" is not assigned
end
```

```ceu
var&? int x;
do
    var int y = 10;
    x = &y;
    _printf("%d\n", x!);    // prints 10
end
_printf("%d\n", x!);        // error!
```

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
