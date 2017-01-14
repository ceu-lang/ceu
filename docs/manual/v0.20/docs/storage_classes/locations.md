## Locations

A location (aka *l-value*) is a path to a memory location holding a storage
class entity ([`ID_int`](#TODO)) or a native symbol ([`ID_nat`](#TODO)):

```
Loc    ::= Loc_01
Loc_01 ::= [`*´|`$´] Loc_02
Loc_02 ::= Loc_03 { `[´Exp`]´ | (`:´|`.´) (ID_int|ID_nat) | `!´ }
Loc_03 ::= `(´ Loc_01 [as (Type | `/´(nohold|plain|pure)) `)´
         |  ID_int
         |  ID_nat
         |  outer
         |  `{´ <code in C> `}´
```

The list that follows enumerates all valid locations:

- storage class entity: variable, vector, internal event (but not external), or pool
- native expressions and symbols
- data field (which are storage class entities)
- typecast
- vector index
- vector length `$`
- pointer dereferencing `*`
- option dereferencing `!`

Locations appear in assignments, event manipulation, iterators, and
expressions.

Examples:

```ceu
emit e(1);          // "e" is an internal event
_UDR = 10;          // "_UDR" is a native symbol
person.age = 70;    // "age" is a variable in "person"
vec[0] = $vec;      // "vec[0]" is a vector index
$vec = 1;           // "$vec" is a vector length
*ptr = 1;           // "ptr" is a pointer to a variable
a! = 1;             // "a" is of an option type
```
