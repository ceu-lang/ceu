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

Primitive Types
---------------

Céu has the following primitive types:

```ceu
void               // void type
bool               // boolean type
byte               // 1-byte type
int      uint      // platform dependent signed and unsigned integer
s8       u8        // signed and unsigned  8-bit integer
s16      u16       // signed and unsigned 16-bit integer
s32      u32       // signed and unsigned 32-bit integer
s64      u64       // signed and unsigned 64-bit integer
float              // platform dependent float
f32      f64       // 32-bit and 64-bit floats
ssize    usize     // signed and unsigned size types
```

See also the [literals](#TODO) for these types.

Native Types
------------

Types defined externally in C can be prefixed by `_` to be used in Céu programs.

Example:

```ceu
var _message_t msg;      // "message_t" is a C type defined in an external library
```

Native types support [TODO-annotations] to provide additional information to
the compiler.

Abstraction Types
-----------------

`TODO (brief description)`

See also [Abstractions](#TODO).

Type Modifiers
--------------

Types can be suffixed with the following modifiers: `&&`, `?`.

#### Pointer

`TODO (like C)`

TODO: restrictions
    - cannot cross yielding statements

### Option

`TODO (like Maybe)`
