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
Program ::= Stmts

Stmts ::= {Stmt `;´} {`;´}

Stmt ::= nothing

  /* Storage Classes */

      | var [`&´|`&?´] Type LIST(ID_int [`=´ Set])
      | vector [`&´] `[´ [Exp] `]´ Type LIST(ID_int [`=´ Set])
      | pool [`&´] `[´ [Exp] `]´ Type LIST(ID_int [`=´ Set])
      | event [`&´|`&?´] (Type | `(´LIST(Type)`)´) LIST(ID_int [`=´ Set])
      | input (Type | `(´LIST(Type)`)´) LIST(ID_ext)
      | output (Type | `(´LIST(Type)`)´) LIST(ID_ext)

  /* Event handling */

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
            Stmts
        { else/if Exp then
            Stmts }
        [ else
            Stmts ]
        end

  /* Loops */

      /* simple */
      | loop [`/´Exp] do
            Stmts
        end

      /* numeric iterator */
      | loop [`/´Exp] (`_´|ID_int) in Range do
            Stmts
        end
        // where
            Range ::= (`[´ | `]´)
                        ( Exp `->´ (`_´|Exp)
                        | (`_´|Exp) `<-´ Exp )
                      (`[´ | `]´) [`,´ Exp]

      /* pool iterator */
      | loop [`/´Exp] [ `(´ LIST(Var) `)´ ] in Name do
            Stmts
        end

      /* event iterator */
      | every [(Name | `(´TODO/List_Name_Any`)´) in] (ID_ext|Name|WCLOCKK|WCLOCKE) do
            Stmts
        end

      |  break [`/´ID_int]
      |  continue [`/´ID_int]

  /* Pause */

      | pause/if (Name|ID_ext) do
            Stmts
        end

  /* Parallel Compositions */

      /* parallels */
      | (par | par/and | par/or) do
            Stmts
        with
            Stmts
        { with
            Stmts }
         end

      /* watching */
      // Watching ::=
      | watching LIST((ID_ext|Name|WCLOCKK|WCLOCKE|Code) [`=>´ `(´ LIST(Var) `)´]) do
            Stmts
        end

  /* Asynchronous Execution */

      | await async [ `(´LIST(Var)`)´ ] do
            Stmts
        end

      // Async_Thread ::=
      | await async/thread [ `(´LIST(Var)`)´ ] do
            Stmts
        end

      /* synchronization */
      | atomic do
            Stmts
        end

  /* Blocks */

      // Do ::=
      |  do [`/´(`_´|ID_int)]
             Stmts
         end
      |  escape [`/´ID_int] [Exp]

      /* pre (top level) execution */
      | pre do
            Stmts
        end

      /* block spawn */
      | spawn do
            Stmts
        end

      /* finalization */
      | do
            Stmts
        finalize `(´ LIST(Name) `)´ with
            Stmts
        end
      | var `&?´ Type ID_int `=´ `&´ (Call_Nat | Call_Code)
        finalize `(´ LIST(Name) `)´ with
            Stmts
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
            Stmts
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

  /* Lua integration */

      // Lua ::=
      | lua `[´ [Exp] `]´ do
            Stmts
        end
      | `[´ {`=´} `[´
            { <code in Lua> | `@´ Exp }
        `]´ {`=´} `]´

  /* Assignments */

      | (Name | `(´ (LIST(Name)|`_´) `)´) `=´ Set
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
