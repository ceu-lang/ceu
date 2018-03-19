## Identifiers

Céu uses identifiers to refer to *types* (`ID_type`), *variables* (`ID_int`),
*vectors* (`ID_int`), *pools* (`ID_int`), *internal events* (`ID_int`),
*external events* (`ID_ext`), *code abstractions* (`ID_abs`),
*data abstractions* (`ID_abs`), *fields* (`ID_field`),
*native symbols* (`ID_nat`), and *block labels* (`ID_int`).

```ceu
ID       ::= [a-z, A-Z, 0-9, _]+ // a sequence of letters, digits, and underscores
ID_int   ::= ID                  // ID beginning with lowercase
ID_ext   ::= ID                  // ID all in uppercase, not beginning with digit
ID_abs   ::= ID {`.´ ID}         // IDs beginning with uppercase, containining at least one lowercase)
ID_field ::= ID                  // ID not beginning with digit
ID_nat   ::= ID                  // ID beginning with underscore

ID_type  ::= ( ID_nat | ID_abs
             | none
             | bool  | on/off | yes/no
             | byte
             | r32   | r64    | real
             | s8    | s16    | s32     | s64
             | u8    | u16    | u32     | u64
             | int   | uint   | integer
             | ssize | usize )
```

Declarations for [`code` and `data` abstractions](../statements/#abstractions)
create new [types](../types/#types) which can be used as type identifiers.

Examples:

```ceu
var int a;                    // "a" is a variable, "int" is a type

emit e;                       // "e" is an internal event

await I;                      // "I" is an external input event

spawn Move();                 // "Move" is a code abstraction and a type

var Rect r;                   // "Rect" is a data abstraction and a type

escape r.width;               // "width" is a field

_printf("hello world!\n");    // "_printf" is a native symbol
```
