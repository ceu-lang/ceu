Types
=====

Céu is statically typed, requiring all variables and events to be declared
before they are used.

A type is composed of a [type identifier](#TODO), followed by a sequence
of optional *pointer* modifiers `&&`, and an optional *option* modifier `?`:

```
Type ::= ID_type {`&&´} [`?´]
```

Examples:

```ceu
var u8     v;   // "v" is of 8-bit unsigned integer type
var _rect  r;   // "r" is of external native type "rect"
var byte&& buf; // "buf" is a pointer to a "byte"
var Tree   t;   // "t" is a data of type "Tree"
```
