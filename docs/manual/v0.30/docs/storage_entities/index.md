# Storage Entities

Storage entities represent all objects that are stored in memory during
execution.
Céu supports *variables*, *vectors*, *events* (external and internal), and
*pools* as entity classes.

An [entity declaration](../statements/#declarations) consists of an entity
class, a [type](../types/#types), and an [identifier](../lexical_rules/#identifiers).

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

{!storage_entities/lexical_scope.md!}

{!storage_entities/entity_classes.md!}

{!storage_entities/locations.md!}

{!storage_entities/references.md!}
