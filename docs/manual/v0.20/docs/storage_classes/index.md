# Storage Classes

Storage classes represent all entities that are stored in memory during
execution.
Céu supports *variables*, *vectors*, *events* (external and internal), and
*pools* as storage classes.

An entity [declaration](#TODO) consists of a storage class,
a [type](#TODO), and an [identifier](#TODO).

Examples:

```ceu
var       int    v;     // "v" is a variable of type "int"
vector[9] byte   buf;   // "buf" is a vector with at most 9 values of type "byte"
input     void&& A;     // "A" is an input event that carries values of type "void&&"
event     bool   e;     // "e" is an internal event that carries values of type "bool"
pool[]    Anim   anims; // "anims" is a dynamic "pool" for instances of type "Anim"
```

A declaration binds the identifier with a memory location that holds values of
the associated type.

{!storage_classes/lexical_scope.md!}
{!storage_classes/classes.md!}
{!storage_classes/locations.md!}
{!storage_classes/references.md!}
