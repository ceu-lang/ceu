Syntax
======

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

      | var [`&´|`&?´] Type LIST(ID_int [`=´ Set])
      | vector [`&´] `[´ [Exp] `]´ Type LIST(ID_int [`=´ Set])
      | pool [`&´] `[´ [Exp] `]´ Type LIST(ID_int [`=´ Set])
      | event [`&´|`&?´] (Type | `(´ LIST(Type) `)´) LIST(ID_int [`=´ Set])
      | input (Type | `(´ LIST(Type) `)´) LIST(ID_ext)
      | output (Type | `(´ LIST(Type) `)´) LIST(ID_ext)

  /* Event Handling */

      // Await ::=
      | await (ID_ext | Name) [until Exp]
      | await (WCLOCKK|WCLOCKE)
      //
      | await FOREVER

      // Emit_Ext ::=
      | emit ID_ext [`=>´ (Exp | `(´ [LIST(Exp)] `)´)]
      | emit (WCLOCKK|WCLOCKE)
      //
      | emit Name [`=>´ (Exp | `(´ [LIST(Exp)] `)´)]

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
      | loop [`/´Exp] (`_´|ID_int) in Range do
            Block
        end
        // where
            Range ::= (`[´ | `]´)
                        ( Exp `->´ (`_´|Exp)
                        | (`_´|Exp) `<-´ Exp )
                      (`[´ | `]´) [`,´ Exp]

      /* pool iterator */
      | loop [`/´Exp] [ `(´ LIST(Var) `)´ ] in Name do
            Block
        end

      /* event iterator */
      | every [(Name | `(´ LIST(Name|`_´) `)´) in] (ID_ext|Name|WCLOCKK|WCLOCKE) do
            Block
        end

      |  break [`/´ID_int]
      |  continue [`/´ID_int]

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
      | watching LIST((ID_ext|Name|WCLOCKK|WCLOCKE|Code) [`=>´ `(´ LIST(Var) `)´]) do
            Block
        end

      /* block spawn */
      | spawn do
            Block
        end

  /* Asynchronous Execution */

      | await async [ `(´LIST(Var)`)´ ] do
            Block
        end

      // Async_Thread ::=
      | await async/thread [ `(´LIST(Var)`)´ ] do
            Block
        end

      /* synchronization */
      | atomic do
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
            Params ::= void | LIST([dynamic] Class ID_int)
            Class ::= var [`&´|`&?´] [`/´hold] * Type
                   |  vector `&´ `[´ [Exp] `]´ Type
                   |  pool `&´ `[´ [Exp] `]´ Type
                   |  event [`&´|`&?´] (Type | `(´LIST(Type)`)´)

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
      | spawn Mods Code [in Name] [`=>´ `(´ LIST(Var) `)´]

        // where
            Mods ::= [`/´dynamic | `/´static] [`/´recursive]
            Code ::= ID_abs `(´ [LIST(Exp)] `)´

  /* C integration */

      | native [`/´(pure|const|nohold|plain)] `(´ List_Nat `)´
        // where
            List_Nat ::= LIST(ID_nat)
      | native `/´(pre|pos) do
            <code definitions in C>
        end
      | native `/´ end
      | `{´ <code in C> `}´

      // Call_Nat ::=
      | call [`/´recursive] (Name | `(´ Exp `)´)  `(´ [ LIST(Exp)] `)´

      /* finalization */
      | do
            Block
        finalize `(´ LIST(Name) `)´ with
            Block
        end
      | var `&?´ Type ID_int `=´ `&´ (Call_Nat | Call_Code)
        finalize `(´ LIST(Name) `)´ with
            Block
        end

  /* Lua integration */

      // Lua ::=
      | lua `[´ [Exp] `]´ do
            Block
        end
      | `[´ {`=´} `[´
            { <code in Lua> | `@´ Exp }
        `]´ {`=´} `]´

  /* Assignments */

      | (Name | `(´ LIST(Name|`_´) `)´) `=´ Set
        // where
            Set ::= ( Await
                    | Emit_Ext
                    | Watching
                    | Async_Thread
                    | Do
                    | Data
                    | Await_Code
                    | Spawn_Code
                    | Lua
                    | Vector
                    | `_´
                    | Exp )
            Data ::= (val|new) ID_abs `(´ LIST(Exp) `)´ 
            Vector ::= (Exp | `[´ [LIST(Exp)] `]´) { `..´ (Exp | Lua | `[´ [LIST(Exp)] `]´) }

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
