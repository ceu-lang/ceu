## Names

A storage entity has one or more names :

```
Name    ::= Name_01
Name_01 ::= [`*´|`$´] Name_02
Name_02 ::= Name_03 { `[´Exp`]´ | (`:´|`.´) (ID_int|ID_nat) | `!´ }
Name_03 ::= `(´ Name_01 [as (Type | `/´(nohold|plain|pure)) `)´
         |  ID_int
         |  ID_nat
         |  outer
         |  `{´ <code in C> `}´
```
