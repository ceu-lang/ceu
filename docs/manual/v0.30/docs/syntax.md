# Syntax

Follows the complete syntax of Céu in a BNF-like syntax:

- `A` : non terminal (starting in uppercase)
- **`a`** : terminal (in bold and lowercase)
- <code>&grave;.&acute;</code> : terminal (non-alphanumeric characters)
- `A ::= ...` : defines `A` as `...`
- `x y` : `x` in sequence with `y`
- `x|y` : `x` or `y`
- `{x}` : zero or more xs
- `[x]` : optional x
- `LIST(x)` : expands to <code>x {&grave;,&acute; x} [&grave;,&acute;]</code>
- `(...)` : groups `...`
- `<...>` : special informal rule

<!--
TODO:
    deterministic
-->

```ceu
Program ::= Block
Block   ::= {Stmt `;´}

Stmt ::= nothing

  /* Blocks */

      // Do ::=
      | do [`/´(ID_int|`_´)] [`(´ [LIST(ID_int)] `)´]
            Block
        end
      | escape [`/´ID_int] [Exp]

      /* pre (top level) execution */
      | pre do
            Block
        end

  /* Storage Entities / Declarations */

      // Dcls ::=
      | var [`&´|`&?´] `[´ [Exp [`*´]] `]´ [`/dynamic´|`/nohold´] Type ID_int [`=´ Sources]
      | pool [`&´] `[´ [Exp] `]´ Type ID_int [`=´ Sources]
      | event [`&´] (Type | `(´ LIST(Type) `)´) ID_int [`=´ Sources]

      | input (Type | `(´ LIST(Type) `)´) ID_ext
      | output (Type | `(´ LIST([`&´] Type [ID_int]) `)´) ID_ext
            [ do Block end ]

  /* Event Handling */

      // Await ::=
      | await (ID_ext | Loc) [until Exp]
      | await (WCLOCKK|WCLOCKE)
      //
      | await (FOREVER | pause | resume)

      // Emit_Ext ::=
      | emit ID_ext [`(´ [LIST(Exp|`_´)] `)´]
      | emit (WCLOCKK|WCLOCKE)
      //
      | emit Loc [`(´ [LIST(Exp|`_´)] `)´]

      | lock Loc do
            Block
        end

  /* Conditional */

      | if Exp then
            Block
        { else/if Exp then
            Block }
        [ else
            Block ]
        end

  /* Loops */

      /* simple */
      | loop [`/´Exp] do
            Block
        end

      /* numeric iterator */
      | loop [`/´Exp] (ID_int|`_´) in [Range] do
            Block
        end
        // where
            Range ::= (`[´ | `]´)
                        ( (      Exp `->´ (Exp|`_´))
                        | ((Exp|`_´) `<-´ Exp      ) )
                      (`[´ | `]´) [`,´ Exp]

      /* pool iterator */
      | loop [`/´Exp] (ID_int|`_´) in Loc do
            Block
        end

      /* event iterator */
      | every [(Loc | `(´ LIST(Loc|`_´) `)´) in] (ID_ext|Loc|WCLOCKK|WCLOCKE) do
            Block
        end

      |  break [`/´ID_int]
      |  continue [`/´ID_int]

  /* Parallel Compositions */

      /* parallels */
      | (par | par/and | par/or) do
            Block
        with
            Block
        { with
            Block }
         end

      /* watching */
      // Watching ::=
      | watching LIST(ID_ext|Loc|WCLOCKK|WCLOCKE|Abs_Cons) do
            Block
        end

      /* block spawn */
      | spawn [`(´ [LIST(ID_int)] `)´] do
            Block
        end

  /* Exceptions */

      | throw Exp
      | catch LIST(Loc) do
            Block
        end

  /* Pause */

      | pause/if (Loc|ID_ext) do
            Block
        end

  /* Asynchronous Execution */

      | await async [ `(´ LIST(Var) `)´ ] do
            Block
        end

      // Thread ::=
      | await async/thread [ `(´ LIST(Var) `)´ ] do
            Block
        end

      | spawn async/isr `[´ LIST(Exp) `]´ [ `(´ LIST(Var) `)´ ] do
            Block
        end

      /* synchronization */
      | atomic do
            Block
        end

  /* C integration */

      | native [`/´(pure|const|nohold|plain)] `(´ LIST(ID_nat) `)´
      | native `/´(pre|pos) do
            <code definitions in C>
        end
      | native `/´ end
      | `{´ {<code in C> | `@´ (`(´Exp`)´|Exp)} `}´     /* `@@´ escapes to `@´ */

      // Nat_Call ::=
      | [call] Exp

      /* finalization */
      | do [Stmt] Finalize
      | var [`&´|`&?´] Type ID_int `=´ `&´ (Nat_Call | Code_Call) Finalize
        // where
            Finalize ::= finalize [ `(´ LIST(Loc) `)´ ] with
                             Block
                         [ pause  with Block ]
                         [ resume with Block ]
                         end

  /* Lua integration */

      // Lua_State ::=
      | lua `[´ [Exp] `]´ do
            Block
        end
      // Lua_Stmts ::=
      | `[´ {`=´} `[´
            { {<code in Lua> | `@´ (`(´Exp`)´|Exp)} }   /* `@@´ escapes to `@´ */
        `]´ {`=´} `]´

  /* Abstractions */

      /* Data */

      | data ID_abs [as (nothing|Exp)] [ with
            Dcls `;´ { Dcls `;´ }
        end ]

      /* Code */

      // Code_Tight ::=
      | code/tight Mods ID_abs `(´ Params `)´ `->´ Type

      // Code_Await ::=
      | code/await Mods ID_abs `(´ Params `)´
                                    [ `->´ `(´ Params `)´ ]
                                        `->´ (Type | NEVER)
                                [ throws LIST(ID_abs) ]
        // where
            Params ::= none | LIST(Dcls)

      /* code implementation */
      | (Code_Tight | Code_Await) do
            Block
        end

      /* code invocation */

      // Code_Call ::=
      | call  Mods Abs_Cons

      // Code_Await ::=
      | await Mods Abs_Cons

      // Code_Spawn ::=
      | spawn Mods Abs_Cons [in Loc]
      | kill Loc [ `(` Exp `)` ]

        // where
            Mods ::= [`/´dynamic | `/´static] [`/´recursive]
            Abs_Cons ::= [Loc `.´] ID_abs `(´ LIST(Data_Cons|Vec_Cons|Exp|`_´) `)´

  /* Assignments */

      | (Loc | `(´ LIST(Loc|`_´) `)´) `=´ Sources
        // where
            Sources ::= ( Do
                        | Emit_Ext
                        | Await
                        | Watching
                        | Thread
                        | Lua_Stmts
                        | Code_Await
                        | Code_Spawn
                        | Vec_Cons
                        | Data_Cons
                        | Exp
                        | `_´ )
            Vec_Cons  ::= (Loc | Exp) Vec_Concat { Vec_Concat }
                       |  `[´ [LIST(Exp)] `]´ { Vec_Concat }
                        // where
                            Vec_Concat ::= `..´ (Exp | Lua_Stmts | `[´ [LIST(Exp)] `]´)
            Data_Cons ::= (val|new) Abs_Cons

/* Identifiers */

ID       ::= [a-zA-Z0-9_]+
ID_int   ::= ID             // ID beginning with lowercase
ID_ext   ::= ID             // ID all in uppercase, not beginning with digit
ID_abs   ::= ID {`.´ ID}    // IDs beginning with uppercase, containining at least one lowercase)
ID_field ::= ID             // ID not beginning with digit
ID_nat   ::= ID             // ID beginning with underscore
ID_type  ::= ( ID_nat | ID_abs
             | none
             | bool  | on/off | yes/no
             | byte
             | r32   | r64    | real
             | s8    | s16    | s32     | s64
             | u8    | u16    | u32     | u64
             | int   | uint   | integer
             | ssize   | usize )

/* Types */

Type ::= ID_type { `&&´ } [`?´]

/* Wall-clock values */

WCLOCKK ::= [NUM h] [NUM min] [NUM s] [NUM ms] [NUM us]
WCLOCKE ::= `(´ Exp `)´ (h|min|s|ms|us)

/* Literals */

NUM ::= [0-9] ([0-9]|[xX]|[A-F]|[a-f]|\.)*  // regex
STR ::= " [^\"\n]* "                        // regex

/* Expressions */

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

/* Other */

    // single-line comment

    /** nested
        /* multi-line */
        comments **/

    # preprocessor directive

```

`TODO: statements that do not require ;`
