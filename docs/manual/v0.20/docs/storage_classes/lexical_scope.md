## Lexical Scope

Storage entities have lexical scope, i.e., they are visible only in the
[block](#TODO) in which they are declared.

The lifetime of entities, which is the period between allocation and
deallocation in memory, is also limited to the scope of the enclosing block.
However, individual elements inside *vector* and *pool* entities have dynamic
lifetime, but which never outlive the scope of the declaration.
