# Expressions

Céu supports the following expressions:

```ceu
Exp ::= NUM | STR | null | true | false
     |  `(´ Exp `)´
     |  Exp <binop> Exp
     |  <unop> Exp
     |  Exp is Type
     |  Exp as Type
     |  Exp as `/´(nohold|plain|pure)
     |  `&´ (Nat_Call | Loc)
     |  `&&´ Loc
     |  Loc [`?´]
     |  sizeof `(´ (Type|Exp) `)´
     |  Nat_Call | Code_Call

Loc    ::= Loc_01
Loc_01 ::= [`*´|`$´] Loc_02
Loc_02 ::= Loc_03 { `[´Exp`]´ | (`:´|`.´) (ID_int|ID_nat) | `!´ }
Loc_03 ::= `(´ Loc_01 [as (Type | `/´(nohold|plain|pure)) `)´
        |  ID_int
        |  ID_nat
        |  outer
        |  `{´ <code in C> `}´

    /* operator precedence (binop & unop) */

    /* lowest priority */
    or                                  /* binops */
    and
    !=    ==    <=    >=    <     >
    |
    ^
    &
    <<    >>
    +     -
    *     /     %
    not   +    -    ~    $$             /* unops */
    /* highest priority */
```

Locations are introduced in [Storage Classes](#TODO).
