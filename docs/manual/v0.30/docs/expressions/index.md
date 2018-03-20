# Locations & Expressions

Céu specifies [locations](../storage_entities/#locations) and expressions as
follows:

```ceu
Exp ::= NUM | STR | null | true | false | on | off | yes | no
     |  `(´ Exp `)´
     |  Exp <binop> Exp
     |  <unop> Exp
     |  Exp (`:´|`.´) (ID_int|ID_nat)
     |  Exp (`?´|`!´)
     |  Exp `[´ Exp `]´
     |  Exp `(´ [ LIST(Exp) ] `)´
     |  Exp is Type
     |  Exp as Type
     |  Exp as `/´(nohold|plain|pure)
     |  sizeof `(´ (Type|Exp) `)´
     |  Nat_Call | Code_Call
     |  ID_int
     |  ID_nat
     |  outer

/* Locations */

Loc ::= Loc [as (Type | `/´(nohold|plain|pure)) `)´
     |  [`*´|`$´] Loc
     |  Loc { `[´Exp`]´ | (`:´|`.´) (ID_int|ID_nat) | `!´ }
     |  ID_int
     |  ID_nat
     |  outer
     |  `{´ <code in C> `}´
     |  `(´ Loc `)´

/* Operator Precedence */

    /* lowest priority */

    // locations
    *     $
    :     .     !     []
    as

    // expressions
    is    as                                            // binops
    or
    and
    !=    ==    <=    >=    <     >
    |
    ^
    &
    <<    >>
    +     -
    *     /     %
    not   +     -     ~     $$    $     *     &&    &   // unops
    :     .     !     ?     ()    []

    /* highest priority */
```

{!expressions/primary.md!}

{!expressions/arithmetic.md!}

{!expressions/bitwise.md!}

{!expressions/relational.md!}

{!expressions/logical.md!}

{!expressions/types.md!}

{!expressions/modifiers.md!}

{!expressions/references.md!}

{!expressions/option.md!}

{!expressions/sizeof.md!}

{!expressions/calls.md!}

{!expressions/vectors.md!}

{!expressions/fields.md!}
