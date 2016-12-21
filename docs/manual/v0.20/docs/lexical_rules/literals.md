## Literals

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
