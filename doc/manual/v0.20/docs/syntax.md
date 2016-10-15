Syntax
======

```ceu
Stmt ::= nothing

  /* Storage Classes */

      | var    [`&´|`&?´] Type ID_int [`=´ <Set>] { `,´ ID_int [`=´ <Set>] } [`,´]
      | vector [`&´] `[´ [Exp] `]´ Type ID_int { `,´ ID_int [`=´ <Set>] } [`,´]
      | pool   [`&´] `[´ [Exp] `]´ Type ID_int { `,´ ID_int [`=´ <Set>] } [`,´]
      | event  [`&´|`&?´] (Type | `(´List_Type`)´) ID_int { `,´ ID_int } [`,´]
      | input (Type | `(´List_Type`)´) ID_ext { `,´ ID_ext } [`,´]
      | output (Type | `(´List_Type`)´) ID_ext { `,´ ID_ext } [`,´]

  /* Event handling */

      /* Awaits */
      | await FOREVER

      // Await ::=
      | await (ID_ext | Name) [ until Exp ]
      | await (WCLOCKK|WCLOCKE)

      /* Emits */

      | emit Name   [ `=>´ (Exp | `(´ [List_Exp] `)´)

      // Emit_Ext ::=
      | emit ID_ext [ `=>´ (Exp | `(´ [List_Exp] `)´)

      // Emit_Wclock ::=
      | emit (WCLOCKK|WCLOCKE)

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
      | loop [`/´ Exp] do
            Block
        end

      /* numeric iterator */
      | loop [`/´ Exp] (`_´|ID_int) in Range do
            Block
        end
        // where
            Range ::= (`[´ | `]´)
                        ( Exp `->´ (`_´|Exp) |
                          (`_´|Exp) `<-´ Exp )
                      (`[´ | `]´) [`,´ Exp]

      /* pool iterator */
      | loop [`/´ Exp] [ `(´ List_Var `)´ ] in Name do
            Block
        end

      /* event iterator */
      | every [(Name | `(´TODO/List_Name_Any`)´) in] (ID_ext|Name|WCLOCKK|WCLOCKE) do
            Block
        end

      |  break [`/´ ID_int]
      |  continue [`/´ ID_int]

  /* Pause */

      | pause/if (Name|ID_ext) do
            Block
        end

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
      | watching [`=>´ `(´ List_Var `)´] do
            Block
        end
        // where
            Watch_List ::= Watch {`,´ Watch } [`,´]
            Watch ::= (ID_ext|Name|WCLOCKK|WCLOCKE|TODO/Abs_Await) [`=>´ `(´ List_Var `)´]

  /* Asynchronous Execution */

      | await async [ `(´List_Var`)´ ] do
            Block
        end

      // Async_Thread ::=
      | await async/thread [ `(´List_Var`)´ ] do
            Block
        end

      /* synchronization */
      | atomic do
            Block
        end

  /* Blocks */

      // Do ::=
      |  do [`/´ (`_´|ID_int)]
             Block
         end
      |  escape [`/´ ID_int] [Exp]

      /* pre (top level) execution */
      | pre do
            Block
        end

      /* block spawn */
      | spawn do
            Block
        end

      /* finalization */
      | do
            Block
        finalize `(´ List_Name `)´ with
            Block
        end
      | var `&?´ Type ID_int `=´ `&´ (Call_Nat | Call_Code)
        finalize `(´ List_Name `)´ with
            Block
        end

  /* Abstractions */

      /* Data */

      | data ID_abs [is Exp]
      | data ID_abs [is Exp] [ with
                                { <var|vector|pool|event declaration> `;´ {`;´} }
                               end ]

      /* Code */

      // Code_Tight ::=
      | code/tight [`/´dynamic] [`/´recursive] ID_abs `(´ Params `)´ `=>´ Type

      // Code_Await ::=
      | code/await [`/´dynamic] [`/´recursive] ID_abs `(´ Params `)´ `=>´ [ `(´ Params `)´ `=>´ ] (Type | FOREVER)
        // where
            Params ::= void | (Param { `,´ Param } [`,´])
            Param ::= [dynamic] Class ID_int
            Class ::= var [`&´|`&?´] [`/´hold] * Type
                   |  vector `&´ `[´ [Exp] `]´ Type
                   |  pool `&´ `[´ [Exp] `]´ Type
                   |  event [`&´|`&?´] (Type | `(´List_Type`)´)

      /* code implementation */
      | (Code_Tight | Code_Await) do
            Block
        end

      /* code instantiation */

      // Call_Code ::=
      | call  Mods Code

      // Await_Code ::=
      | await Mods Code

      // Spawn_Code ::=
      | spawn Mods Code [in Name] [`=>´ `(´ List_Var `)´]

        // where
            Mods ::= [`/´dynamic | `/´static] [`/´recursive]
            Code ::= ID_abs `(´ [List_Exp] `)´

  /* C integration */

      | native [`/´(pure|const|nohold|plain)] `(´ List_Nat `)´
        // where
            List_Nat ::= ID_nat { `,´ ID_nat }
      | native `/´ (pre|pos) do
            <code definitions in C>
        end
      | native `/´ end
      | `{´ <code in C> `}´

      // Call_Nat ::=
      | call [`/´recursive] (Name | `(´ Exp `)´)  `(´ [ List_Exp] `)´

  /* Lua integration */

      // Lua ::=
      | lua `[´ [Exp] `]´ do
            Block
        end
      | `[´ {`=´} `[´
            { <code in Lua> | `@´ Exp }
        `]´ {`=´} `]´

  /* Assignments */

      | (Name | `(´ (List_Name|`_´) `)´) `=´ Set
        // where
            Set ::= ( Await
                    | Emit_Ext
                    | Emit_Wclock
                    | Watching
                    | Async_Thread
                    | Do
                    | Data
                    | Await_Code
                    | Spawn_Code
                    | Lua
                    | Vec
                    | `_´
                    | Exp )
            Data ::= (val|new) ID_abs `(´ Params `)´ 
            Vec ::= (Exp | `[´ [List_Exp] `]´) { `..´ (Exp | Lua | `[´ [List_Exp] `]´) }

/* Block */

Block ::= { Stmt `;´ {`;´} }

/* Identifiers */

ID       ::= [a-zA-Z0-9_]+
ID_int   ::= ID         // beginning with lowercase
ID_ext   ::= ID         // all in uppercase, not beginning with digit
ID_abs   ::= ID         // beginning with uppercase, containining at least one lowercase)
ID_field ::= ID         // not beginning with digit
ID_nat   ::= ID         // beginning with underscore
ID_type  ::= ( ID_nat | ID_abs
             | void  | bool  | byte
             | f32   | f64   | float
             | s8    | s16   | s32   | s64
             | u8    | u16   | u32   | u64
             | int   | uint  | ssize | usize )

/* Types */

Type ::= ID_type { `&&´ } [`?´]

/* Lists */

List_Type ::= Type    { `,´ Type    } [`,´]
List_Exp  ::= Exp     { `,´ Exp     } [`,´]
List_Var  ::= ID_int  { `,´ ID_int  } [`,´]
List_Name ::= (Name|`_´)  { `,´ (Name|`_´)  } [`,´]

/* Wall-clock values */

WCLOCKK ::= [NUM h] [NUM min] [NUM s] [NUM ms] [NUM us]
WCLOCKE ::= `(´ Exp `)´ (h|min|s|ms|us)

/* Expressions */

Name    ::= Name_01
Name_01 ::= [`*´|`$´] Name_02
Name_02 ::= Name_03 { `[´Exp`]´ | (`:´|`.´) (ID_int|ID_nat) | `!´ }
Name_03 ::= `(´ Name_01 [as (Type | `/´(nohold|plain|pure)) `)´
         |  ID_int
         |  ID_nat
         |  outer
         |  `{´ <code in C> `}´

Exp  ::= Prim (combined with the "Operator Precedence" below)
Prim ::= `(´ Exp `)´
      |  `&&´ Name
      |  Name [`?´]
      |  `&´ (Call_Nat | Name)
      |  Call_Nat | Call_Code
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
