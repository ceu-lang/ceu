## C Integration

<!--
Céu integrates safely with C, and programs can define and make native calls
seamlessly while avoiding memory leaks and dangling pointers when dealing with
external resources.
-->

Céu provides [native declarations](#native-declaration) to import C symbols,
[native blocks](#native-block) to define new code in C,
[native statements](#native-statement) to inline C statements,
[native calls](#native-call) to call C functions,
and [finalization](#resources-finalization) to deal with C pointers safely:

```ceu
Nat_Symbol ::= native [`/´(pure|const|nohold|plain)] `(´ LIST(ID_nat) `)´
Nat_Block  ::= native `/´(pre|pos) do
                   <code definitions in C>
               end
Nat_End    ::= native `/´ end

Nat_Stmts  ::= `{´ {<code in C> | `@´ (`(´Exp`)´|Exp)} `}´     /* `@@´ escapes to `@´ */

Nat_Call   ::= [call] (Loc | `(´ Exp `)´)  `(´ [ LIST(Exp)] `)´

Finalization ::= do [Stmt] Finalize
              |  var [`&´|`&?´] Type ID_int `=´ `&´ (Call_Nat | Call_Code) Finalize
Finalize ::= finalize [ `(´ LIST(Loc) `)´ ] with
                 Block
             [ pause  with Block ]
             [ resume with Block ]
             end
```

Native calls and statements transfer execution to C, losing the guarantees of
the [synchronous model](../#synchronous-execution-model).
For this reason, programs should only resort to C for asynchronous
functionality (e.g., non-blocking I/O) or simple `struct` accessors, but
never for control purposes.

`TODO: Nat_End`

### Native Declaration

In Céu, any [identifier](../lexical_rules/#identifiers) prefixed with an
underscore is a native symbol defined externally in C.
However, all external symbols must be declared before their first use in a
program.

Native declarations support four modifiers as follows:

- `const`: declares the listed symbols as constants.
    Constants can be used as bounded limits in [vectors](#vectors),
    [pools](#pools), and [numeric loops](../statements/#numeric-iterator).
    Also, constants cannot be [assigned](#assignments).
- `plain`: declares the listed symbols as *plain* types, i.e., types (or
    composite types) that do not contain pointers.
    A value of a plain type passed as argument to a function does not require
    [finalization](../statements/#resources-finalization).
- `nohold`: declares the listed symbols as *non-holding* functions, i.e.,
    functions that do not retain received pointers after returning.
    Pointers passed to non-holding functions do not require
    [finalization](../statements/#resources-finalization).
- `pure`: declares the listed symbols as pure functions.
    In addition to the `nohold` properties, pure functions never allocate
    resources that require [finalization](../statements/#resources-finalization)
    and have no side effects to take into account for the [safety checks](#TODO).

Examples:

```ceu
// values
native/const  _LOW, _HIGH;      // Arduino "LOW" and "HIGH" are constants
native        _errno;           // POSIX "errno" is a global variable

// types
native/plain  _char;            // "char" is a "plain" type
native        _SDL_PixelFormat; // SDL "SDL_PixelFormat" is a type holding a pointer

// functions
native        _uv_read_start;   // Libuv "uv_read_start" retains the received pointer
native/nohold _free;            // POSIX "free" receives a pointer but does not retain it
native/pure   _strlen;          // POSIX "strlen" is a "pure" function
```

### Native Block

A native block allows programs to define new external symbols in C.

The contents of native blocks is copied unchanged to the output in C depending
on the modifier specified:

- `pre`: code is placed before the declarations for the Céu program.
    Symbols defined in `pre` blocks are visible to Céu.
- `pos`: code is placed after the declarations for the Céu program.
    Symbols implicitly defined by the compiler of Céu are visible to `pos`
    blocks.

Native blocks are copied in the order they appear in the source code.

Since Céu uses the [C preprocessor](../compilation/#compilation), hash
directives `#` inside native blocks must be quoted as `##` to be considered
only in the C compilation phase.

If the code in C contains the terminating `end` keyword of Céu, the `native`
block should be delimited with matching comments to avoid confusing the parser:

Symbols defined in native blocks still need to be
[declared](#native-declaration) for use in the program.

Examples:

```ceu
native/plain _t;
native/pre do
    typedef int t;              // definition for "t" is placed before Céu declarations
end
var _t x = 10;                  // requires "t" to be already defined
```

```ceu
input none A;                   // declaration for "A" is placed before "pos" blocks
native _get_A_id;
native/pos do
    int get_A_id (void) {
        return CEU_INPUT_A;     // requires "A" to be already declared
    }
end
```

```ceu
native/nohold _printf;
native/pre do
    ##include <stdio.h>         // include the relevant header for "printf"
end
```

```ceu
native/pos do
    /******/
    char str = "This `end` confuses the parser";
    /******/
end
```

### Native Statement

The contents of native statements in between `{` and `}` are inlined in the
program.

Native statements support interpolation of expressions in Céu which are
expanded when preceded by the symbol `@`.

Examples:

```ceu
var int v_ceu = 10;
{
    int v_c = @v_ceu * 2;       // yields 20
}
v_ceu = { v_c + @v_ceu };       // yields 30
{
    printf("%d\n", @v_ceu);     // prints 30
}
```

### Native Call

Expressions that evaluate to a [native type](../types/#natives) can be called
from Céu.

If a call passes or returns pointers, it may require an accompanying
[finalization statement](#resources-finalization).

Examples:

```ceu
// all expressions below evaluate to a native type and can be called

_printf("Hello World!\n");

var _t f = <...>;
f();

var _s s = <...>;
s.f();
```

<!--
`TODO: ex. pointer return`
-->

### Resources & Finalization

A finalization statement unconditionally executes a series of statements when
its associated block terminates or is aborted.

Céu tracks the interaction of native calls with pointers and requires 
`finalize` clauses to accompany the calls:

- If Céu **passes** a pointer to a native call, the pointer represents a
  **local resource** that requires finalization.
  Finalization executes when the block of the local resource goes out of scope.
- If Céu **receives** a pointer from a native call return, the pointer
  represents an **external resource** that requires finalization.
  Finalization executes when the block of the receiving pointer goes out of
  scope.

In both cases, the program does not compile without the `finalize` statement.

A `finalize` cannot contain
[synchronous control statements](#synchronous-control-statements).

Examples:

```ceu
// Local resource finalization
watching <...> do
    var _buffer_t msg;
    <...>                       // prepares msg
    do
        _send_request(&&msg);
    finalize with
        _send_cancel(&&msg);
    end
    await SEND_ACK;             // transmission is complete
end
```

In the example above, the local variable `msg` is an internal resource passed
as a pointer to `_send_request`, which is an asynchronous call that transmits
the buffer in the background.
If the enclosing `watching` aborts before awaking from the `await SEND_ACK`,
the local `msg` goes out of scope and the external transmission would hold a
*dangling pointer*.
The `finalize` ensures that `_send_cancel` also aborts the transmission.

```ceu
// External resource finalization
watching <...> do
    var&? _FILE f = &_fopen(<...>) finalize with
                        _fclose(f);
                    end;
    _fwrite(<...>, f);
    await A;
    _fwrite(<...>, f);
end
```

In the example above, the call to `_fopen` returns an external file resource as
a pointer.
If the enclosing `watching` aborts before awaking from the `await A`, the file
would remain open as a *memory leak*.
The `finalize` ensures that `_fclose` closes the file properly.

To access an external resource from Céu requires an
[alias assignment](#alias-assignment) to a
[variable alias](../storage_entities/#aliases).
If the external call returns `NULL` and the variable is an option alias
`var&?`, the alias remains unbounded.
If the variable is an alias `var&`, the assigment raises a runtime error.

*Note: the compiler only forces the programmer to write finalization clauses,
       but cannot check if they handle the resource properly.*

[Declaration](#native-declaration) and [expression](../expressions/#modifiers)
modifiers may suppress the requirement for finalization in calls:

- `nohold` modifiers or `/nohold` typecasts make passing pointers safe.
- `pure`   modifiers or `/pure`   typecasts make passing pointers and returning
                                  pointers safe.
- `/plain` typecasts make return values safe.

Examples:

```ceu
// "_free" does not retain "ptr"
native/nohold _free;
_free(ptr);
// or
(_free as /nohold)(ptr);
```

```ceu
// "_strchr" does retain "ptr" or allocates resources
native/pure _strchr;
var _char&& found = _strchr(ptr);
// or
var _char&& found = (_strchr as /pure)(ptr);
```

```ceu
// "_f" returns a non-pointer type
var _tp v = _f() as /plain;
```
