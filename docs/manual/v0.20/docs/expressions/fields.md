## Fields

The operators `.´ and `:´ specify fields of
[data abstractions](../statements/#data) and
[native](../statements/#c-integration) structs:

```
Dot   ::= Loc `.´ (ID_int|ID_nat)
Colon ::= Loc `:´ (ID_int|ID_nat)
```

The expression `e:f` is a sugar for `(*e).f`.

`TODO: ID_nat to avoid clashing with Céu keywords.`

<!--
Example:

```
native do
    typedef struct {
        int v;
    } mystruct;
end
var _mystruct s;
var _mystruct* p = &s;
s.v = 1;
p:v = 0;
```
-->
