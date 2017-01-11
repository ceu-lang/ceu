## Literals

Céu supports literals for *booleans*, *integers*, *floats*, *strings*, and
*null pointers*.

<!--
A literal is a primitive and fixed value in source code.
A literal is a source code representation of a value. 
-->

### Booleans

The boolean type has only two possible values: `true` and `false`.

### Integers

Céu supports decimal and hexadecimal integers:

* Decimals: a sequence of digits (i.e., `[0-9]+`).
* Hexadecimals: a sequence of hexadecimal digits (i.e., `[0-9, a-f, A-F]+`)
                prefixed by <tt>0x</tt>.

<!--
* `TODO: "0b---", "0o---"`
-->

Examples:

```ceu
// both are equal to the decimal 127
v = 127;    // decimal
v = 0x7F;   // hexadecimal
```

### Floats

`TODO (like C)`

### Strings

A sequence of characters surrounded by `"` is converted into a *null-terminated 
string*, just like in C:

Example:

```ceu
_printf("Hello World!\n");
```

### Null pointer

The `null` literal represents [null pointers](#TODO).
