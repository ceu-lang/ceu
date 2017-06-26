## Modifiers

Expressions that evaluate to native types can be modified as follows:

```ceu
Mod ::= Exp as `/´(nohold|plain|pure)
```

Modifiers may suppress the requirement for
[resource finalization](../statements/#resources-finalization).
