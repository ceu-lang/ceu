## Natives

Types defined externally in C can be prefixed by `_` to be used in Céu programs.

Example:

```ceu
var _message_t msg;      // "message_t" is a C type defined in an external library
```

Native types support [modifiers](../statements/#native-declaration) to provide
additional information to the compiler.
