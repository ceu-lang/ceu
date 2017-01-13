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

```ceu
Program ::= Block
Block   ::= {Stmt `;´} {`;´}

Stmt ::= nothing

  /* Blocks */

      // Do ::=
      | do [`/´(`_´|ID_int)]
            Block
        end
      |  escape [`/´ID_int] [Exp]

      /* pre (top level) execution */
      | pre do
            Block
        end

  /* Storage Classes */

      | var [`&´|`&?´] Type LIST(ID_int [`=´ Cons])
      | vector [`&´] `[´ [Exp] `]´ Type LIST(ID_int [`=´ Cons])
      | pool [`&´] `[´ [Exp] `]´ Type LIST(ID_int [`=´ Cons])
      | event [`&´|`&?´] (Type | `(´ LIST(Type) `)´) LIST(ID_int [`=´ Cons])
      | input (Type | `(´ LIST(Type) `)´) LIST(ID_ext)
      | output (Type | `(´ LIST(Type) `)´) LIST(ID_ext)

  /* Event Handling */

      // Await ::=
      | await (ID_ext | Loc) [until Exp]
      | await (WCLOCKK|WCLOCKE)
      //
      | await (FOREVER | pause | resume)

      // Emit_Ext ::=
      | emit ID_ext [`(´ [LIST(Exp)] `)´]
      | emit (WCLOCKK|WCLOCKE)
      //
      | emit Loc [`(´ [LIST(Exp)] `)´]

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
      | loop [`/´Exp] (`_´|ID_int) in [Range] do
            Block
        end
        // where
            Range ::= (`[´ | `]´)
                        ( (      Exp `->´ (`_´|Exp))
                        | ((`_´|Exp) `<-´ Exp      ) )
                      (`[´ | `]´) [`,´ Exp]

      /* pool iterator */
      | loop [`/´Exp] [ `(´ LIST(Var) `)´ ] in Loc do
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
      | watching LIST(ID_ext|Loc|WCLOCKK|WCLOCKE|Code_Cons_Init) do
            Block
        end

      /* block spawn */
      | spawn do
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

      // Async_Thread ::=
      | await async/thread [ `(´ LIST(Var) `)´ ] do
            Block
        end

      /* synchronization */
      | atomic do
            Block
        end

  /* C integration */

      | native [`/´(pure|const|nohold|plain)] `(´ List_Nat `)´
        // where
            List_Nat ::= LIST(ID_nat)
      | native `/´(pre|pos) do
            <code definitions in C>
        end
      | native `/´ end
      | `{´ {<code in C> | `@´ Exp} `}´

      // Nat_Call ::=
      | [call] (Loc | `(´ Exp `)´)  `(´ [ LIST(Exp)] `)´

      /* finalization */
      | do [Stmt] Finalize
      | var `&?´ Type ID_int `=´ `&´ (Nat_Call | Code_Call) Finalize
        // where
            Finalize ::= finalize `(´ LIST(Loc) `)´ with
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
            { {<code in Lua> | `@´ Exp} }
        `]´ {`=´} `]´

  /* Abstractions */

      /* Data */

      | data ID_abs [as (nothing|Exp)] [ with
            { <var_set|vector_set|pool_set|event_set> `;´ {`;´} }
        end ]

      /* Code */

      // Code_Tight ::=
      | code/tight [`/´dynamic] [`/´recursive] ID_abs `(´ Params `)´ `->´ Type

      // Code_Await ::=
      | code/await [`/´dynamic] [`/´recursive] ID_abs `(´ Params `)´ [ `->´ `(´ Inits `)´ ] `->´ (Type | FOREVER)
        // where
            Params ::= void | LIST(Class [ID_int])
            Class ::= [dynamic] var    [`&´] [`/´hold] * Type
                   |            vector `&´ `[´ [Exp] `]´ Type
                   |            pool   `&´ `[´ [Exp] `]´ Type
                   |            event  `&´ (Type | `(´ LIST(Type) `)´)
            Inits ::= void | LIST(Class [ID_int])
            Class ::= var    (`&´|`&?`) * Type
                   |  vector (`&´|`&?`) `[´ [Exp] `]´ Type
                   |  pool   (`&´|`&?`) `[´ [Exp] `]´ Type
                   |  event  (`&´|`&?`) (Type | `(´ LIST(Type) `)´)

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
      | spawn Mods Code_Cons_Init [in Loc]

        // where
            Mods ::= [`/´dynamic | `/´static] [`/´recursive]
            Abs_Cons ::= ID_abs `(´ LIST(Data_Cons|Vec_Cons|Exp|`_´) `)´
            Code_Cons_Init ::= Abs_Cons [`->´ `(´ LIST(`&´ Var) `)´])

  /* Assignments */

      | (Loc | `(´ LIST(Loc|`_´) `)´) `=´ Cons
        // where
            Cons ::= ( Do
                     | Emit_Ext
                     | Watching
                     | Async_Thread
                     | Await
                     | Lua_State
                     | Lua_Stmts
                     | Code_Await
                     | Code_Spawn
                     | Vec_Cons
                     | Data_Cons
                     | `_´
                     | Exp )
            Vec_Cons  ::= (Exp | `[´ [LIST(Exp)] `]´) { `..´ (Exp | Lua_Stmts | `[´ [LIST(Exp)] `]´) }
            Data_Cons ::= (val|new) Abs_Cons

/* Identifiers */

ID       ::= [a-zA-Z0-9_]+
ID_int   ::= ID             // ID beginning with lowercase
ID_ext   ::= ID             // ID all in uppercase, not beginning with digit
ID_abs   ::= ID {`.´ ID}    // IDs beginning with uppercase, containining at least one lowercase)
ID_field ::= ID             // ID not beginning with digit
ID_nat   ::= ID             // ID beginning with underscore
ID_type  ::= ( ID_nat | ID_abs
             | void  | bool  | byte
             | f32   | f64   | float
             | s8    | s16   | s32   | s64
             | u8    | u16   | u32   | u64
             | int   | uint  | ssize | usize )

/* Types */

Type ::= ID_type { `&&´ } [`?´]

/* Wall-clock values */

WCLOCKK ::= [NUM h] [NUM min] [NUM s] [NUM ms] [NUM us]
WCLOCKE ::= `(´ Exp `)´ (h|min|s|ms|us)

/* Loc */

Loc    ::= [`*´|`$´] Loc_01
Loc_01 ::= Loc_02 { `[´Exp`]´ | (`:´|`.´) (ID_int|ID_nat) | `!´ }
Loc_02 ::= `(´ Loc [as (Type | `/´(nohold|plain|pure)) `)´
         |  ID_int
         |  ID_nat
         |  outer
         |  `{´ <code in C> `}´

/* Expressions */

Exp  ::= Prim (combined with the "Operator Precedence" below)
Prim ::= `(´ Exp `)´
      |  `&&´ Loc
      |  Loc [`?´]
      |  `&´ (Nat_Call | Loc)
      |  Nat_Call | Code_Call
      |  sizeof `(´ (Type|Exp) `)´
      |  NUM | STR | null | true | false

/* Literals */

NUM ::= [0-9] ([0-9]|[xX]|[A-F]|[a-f]|\.)*  // regex
STR ::= " [^\"\n]* "                        // regex

/* Operator precedence */

    /* lowest priority */
    is    as
    or
    and
    !=    ==    <=    >=    <     >
    |
    ^
    &
    <<    >>
    +     -
    *     /     %
    not   +    -    ~    $$
    /* highest priority */

/* Other */

    // single-line comment

    /** nested
        /* multi-line */
        comments **/

    # preprocessor directive

```

`TODO: statements that do not require ;`
