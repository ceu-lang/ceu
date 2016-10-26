Lexical Rules
=============

Keywords
--------

Keywords in Céu are reserved names that cannot be used as identifiers (e.g., 
variable names):

```ceu
    and             as              async           atomic          await           

    break           call            code            const           continue        

    data            deterministic   do              dynamic         else            

    emit            end             escape          event           every           

    false           finalize        FOREVER         hold            if              

    in              input           is              isr             kill            

    loop            lua             native          new             nohold          

    not             nothing         null            or              outer           

    output          par             pause           plain           pool            

    pos             pre             pure            recursive       request         

    resume          sizeof          spawn           then            thread

    tight           traverse        true            until           val

    var             vector          watching        with            bool

    byte            f32             f64             float           int

    s16             s32             s64             s8              ssize

    u16             u32             u64             u8              uint

    usize           void
```

Identifiers
-----------

Céu uses identifiers to refer to *types*, *variables*, *vectors*, *pools*,
*internal events*, *external events*, *code abstractions*, *data abstractions*,
*fields*, *native symbols*, and *block labels*.

```ceu
ID       ::= [a-z, A-Z, 0-9, _]+
ID_int   ::= ID (first is lowercase)                        // variables, vectors, pools, internal events, and block labels
ID_ext   ::= ID (all in uppercase, first is not digit)      // external events
ID_abs   ::= ID (first is uppercase, contains lowercase)    // data and code abstractions
ID_field ::= ID (first is not digit)                        // fields
ID_nat   ::= ID (first is underscore)                       // native symbols
ID_type  ::= ( ID_nat | ID_abs                              // types
             | void  | bool  | byte
             | f32   | f64   | float
             | s8    | s16   | s32   | s64
             | u8    | u16   | u32   | u64
             | int   | uint  | ssize | usize )
```

Declarations for [`code` and `data`](#TODO) create new [types](#TODO) which can
be used as type identifiers.

Examples:

```ceu
var int a;                    // "a" is a variable, "int" is a type
emit e;                       // "e" is an internal event
await E;                      // "E" is an external input event
spawn Move();                 // "Move" is a code abstraction and a type
var Rect r;                   // "Rect" is a data abstraction and a type
return r.width;               // "width" is a field
_printf("hello world!\n");    // "_printf" is a native symbol
```


Literals
--------

### Booleans

The boolean type has two values, `true` and `false`.

### Integers

Integer values can be written in decimal and hexadecimal bases:

* Decimals are written *as is*.
* Hexadecimals are prefixed with <tt>0x</tt>.
<!--
* `TODO: "0b---", "0o---"`
-->

Examples:

```ceu
// both are equal to the decimal 127
v = 127;
v = 0x7F;
```

### Floats

`TODO (like C)`

### Null pointer

The `null` literal represents null [pointers](#TODO).

### Strings

A sequence of characters surrounded by `"` is converted into a *null-terminated 
string*, just like in C:

Example:

```ceu
_printf("Hello World!\n");
```

Comments
--------

Céu provides C-style comments.

Single-line comments begin with `//` and run to end of the line.

Multi-line comments use `/*` and `*/` as delimiters.
Multi-line comments can be nested by using a different number of `*` as
delimiters.

Examples:

```ceu
var int a;    // this is a single-line comment

/** comments a block that contains comments

var int a;
/* this is a nested multi-line comment
a = 1;
*/

**/
```
