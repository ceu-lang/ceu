# Types

Céu is statically typed, requiring all variables, events, and other entities to
be declared before they are used in programs.

A type is composed of a [type identifier](../lexical_rules/#identifiers),
followed by an optional sequence of [pointer modifiers](#pointer) `&&`,
followed by an optional [option modifier](#option) `?`:

```
Type ::= ID_type {`&&´} [`?´]
```

Examples:

```ceu
var   u8     v;    // "v" is of 8-bit unsigned integer type
var   _rect  r;    // "r" is of external native type "rect"
var   Tree   t;    // "t" is a data of type "Tree"
var   int?   ret;  // "ret" is either unset or is of integer type
input byte&& RECV; // "RECV" is an input event carrying a pointer to a "byte"
```

{!types/primitives.md!}

{!types/natives.md!}

{!types/abstractions.md!}

{!types/modifiers.md!}
