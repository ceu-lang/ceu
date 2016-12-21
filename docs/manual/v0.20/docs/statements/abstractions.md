## Abstractions

Céu supports reuse with `data` declarations to define new types, and `code`
declarations to define new subprograms.
Declarations have [lexical scope](#TODO).

### Data

The `data` declaration creates a new data type:

```ceu
Data ::= data ID_abs [as (nothing|Exp)] [ with
             { <var_set|vector_set|pool_set|event_set> `;´ {`;´} }
         end ]

Data_Cons ::= (val|new) Abs_Cons
Abs_Cons  ::= ID_abs `(´ LIST(Data_Cons|Vec_Cons|Exp|`_´) `)´
```

A declaration may include fields with [storage declarations](#TODO) which
are included in the `data` type and are publicly accessible.
Field declarations may [assign](#TODO) default values for uninitialized
instances.

Data types can form hierarchies using dots (`.`) in identifiers:

- An identifier like `A` makes `A` a base type.
- An identifier like `A.B` makes `A.B` a subtype of its supertype `A`.

A subtype inherits all fields from its supertype.

The optional `as` modifier expects `nothing` or a constant expression of type
`int`:

- `nothing`: the `data` cannot be instantiated.
- *constant expression*: typecasting a value of the type to `int` evaluates to
                         the specified expression.

Examples:

```ceu
data Rect with
    var int x, y, h, w;
    var int z = 0;
end
var Rect r = val Rect(10,10, 100,100, _);  // "r.z" defaults to 0
```

```ceu
data Dir       as nothing;  // "Dir" is a base type and cannot be intantiated
data Dir.Right as  1;       // "Dir.Right" is a subtype of "Dir"
data Dir.Left  as -1;       // "Dir.Left"  is a subtype of "Dir"
var  Dir dir = <...>;       // receives one of "Dir.Right" or "Dir.Left"
escape (dir as int);        // returns 1 or -1
```

`TODO: new, pool, recursive types`

#### Data Constructor

A new *static value* is created with the `data` name followed by a list of
arguments matching its fields in the contexts as follows:

- Prefixed by `val` in an [assignment](#TODO) to a variable.
- As an argument to a [`code` instantiation](#TODO).
- Nested as an argument in a `data` creation.

In all cases, the arguments are copied to an explicit destination with static
storage.
The destination must be a plain declaration, and not an alias or pointer.

Variables of the exact same type can be copied in [assignments](#TODO).
The rules for assignments from a subtype to a supertype are as follows:

- [Copy assignments](#TODO) for plain values is only allowed if the subtype
                            is the same size as the supertype (i.e., no extra
                            fields).
- [Copy assignments](#TODO) for pointers is allowed.
- [Alias assignment](#TODO) is allowed.

```ceu
data Object with
    var Rect rect;
    var Dir  dir;
end
var Object o1 = val Object(Rect(0,0,10,10,_), Dir.Right());
```

```ceu
var Object o2 = o1;         // makes a deep copy of all fields from "o1" to "o2"
```

### Code

The `code/tight` and `code/await` declarations create new subprograms that can
be [invoked](#TODO) from arbitrary points in programs:

```ceu
// prototype declaration
Code_Tight ::= code/tight Mods ID_abs `(´ Params `)´ `->´ Type
Code_Await ::= code/await Mods ID_abs `(´ Params `)´ [`->´ `(´ Inits `)´] `->´ (Type | FOREVER)

// full declaration
Code_Impl ::= (Code_Tight | Code_Await) do
                  Block
              end

Mods ::= [`/´dynamic] [`/´recursive]

Params ::= void | LIST(Class [ID_int])
Class  ::= [dynamic] var   [`&´] [`/´hold] * Type
        |            vector `&´ `[´ [Exp] `]´ Type
        |            pool   `&´ `[´ [Exp] `]´ Type
        |            event  `&´ (Type | `(´ LIST(Type) `)´)

Inits ::= void | LIST(Class [ID_int])
Class ::= var    (`&´|`&?`) * Type
       |  vector (`&´|`&?`) `[´ [Exp] `]´ Type
       |  pool   (`&´|`&?`) `[´ [Exp] `]´ Type
       |  event  (`&´|`&?`) (Type | `(´ LIST(Type) `)´)

// invocation
Code_Call  ::= call  Mods Abs_Cons
Code_Await ::= await Mods Code_Cons_Init
Code_Spawn ::= spawn Mods Code_Cons_Init [in Name]

Mods ::= [`/´dynamic | `/´static] [`/´recursive]
Code_Cons_Init ::= Abs_Cons [`->´ `(´ LIST(`&´ Var) `)´])
```

A `code/tight` is a subprogram that cannot contain
[synchronous control statements](#TODO) and runs to completion in the current
[internal reaction](#TODO).

A `code/await` is a subprogram with no restrictions (e.g., it can manipulate
events and use parallel compositions) and its execution may outlive multiple
reactions.

A *prototype declaration* specifies the interface parameters of the
abstraction which code invocations must satisfy.
A *full declaration* (a.k.a. *definition*) also specifies an implementation
with a block of code.
An *invocation* specifies the name of the code abstraction and arguments
matching its declaration.

To support recursive abstractions, a code invocation can appear before the
implementation is known, but after the prototype declaration.
In this case, the declaration must use the modifier `recursive`.

Examples:

```ceu
code/tight Absolute (var int v) -> int do   // declares the prototype for "Absolute"
    if v > 0 then                           // implements the behavior
        escape  v;
    else
        escape -v;
    end
end
var int abs = call Absolute(-10);           // invokes "Absolute" (yields 10)
```

```ceu
code/await Hello_World (void) -> FOREVER do
    every 1s do
        _printf("Hello World!\n");  // prints "Hello World!" every second
    end
end
await Hello_World();                // never awakes
```

```ceu
code/tight/recursive Fat (var int v) -> int;    // "Fat" is a recursive code
code/tight/recursive Fat (var int v) -> int do
    if v > 1 then
        escape v * (call/recursive Fat(v-1));   // recursive invocation before full declaration
    else
        escape 1;
    end
end
var int fat = call/recursive Fat(10);           // invokes "Fat" (yields 3628800)
```

`TODO: hold`

#### Code Declaration

Code abstractions specify a list of input parameters in between `(` and `)`.
Each parameter specifies a [storage class](#TODO) with modifiers, a type and
an identifier (optional in declarations).
A `void` list specifies that the code has no parameters.

Code abstractions also specify an output return type.
A `code/await` may use `FOREVER` to indicate that the code never returns.

A `code/await` may also specify an optional *initialization return list*, which
represents local resources created in the outermost scope of its body.
These resources are exported and bound to aliases in the invoking context which
may access them while the code executes:

- The invoker passes a list of unbound aliases to the code.
- The code [binds](#TODO) the aliases to the local resources before any
  [synchronous control statement](#TODO) executes.

If the code does not terminate (i.e., return type is `FOREVER`), the
initialization list specifies normal `&` aliases.
Otherwise, since the code may terminate and deallocated the resource, the list
must specify option `&?` aliases.

Examples:

```ceu
// "Open" abstracts
code/await Open (var _char&& path) -> (var& _FILE res) -> FOREVER do
    var&? _FILE res_ = _fopen(path, <...>)  // allocates resource
                       finalize with
                           _fclose(res_!);  // releases resource
                       end;
    res = &res_!;                           // exports resource to invoker
    await FOREVER;
end

var& _FILE res;                             // declares resource
spawn Open(<...>) -> (&res);                // initiliazes resource
<...>                                       // uses resource
```

#### Code Invocation

A `code/tight` is invoked with a `call` followed by the abstraction name and
list of arguments.
A `code/await` is invoked with an `await` or `spawn` followed by the
abstraction name and list of arguments.

The list of arguments must satisfy the list of parameters in the
[code declaration](#TODO).

The `call` and `await` invocations suspend the ongoing computation and transfer
the execution control to the code abstraction.
The invoking point only resumes after the abstraction terminates and evaluates
to a value of the [return type](#TODO) which can be captured with an optional
[assignment](#TODO).

The `spawn` invocation also suspends and transfers control to the code
abstraction.
However, when the abstraction becomes idle (or terminates), the invoking point
resumes.
This allows the invocation point and the abstraction to execute concurrently.

The `spawn` invocation accepts an optional list of aliases matching the
[initialization list](#TODO) in the code abstraction.
These aliases are bound to local resources in the code and can be accessed
from the invocation point.

The `spawn` invocation also accepts an optional [pool](#TODO) which provides
storage and scope for invoked abstractions.
In this case, the invocation evaluates to a boolean that indicates if the pool
has space to execute the code.
The result can be captured with an optional [assignment](#TODO).
If the pool goes out of scope, all invoked abstractions invoked at that pool
are aborted.
If the `spawn` omits the pool, the invocation always succeed and has the same
scope as the invoking point: when the enclosing block terminates, the invoked
code is aborted.

#### Dynamic Dispatching

Céu supports dynamic code dispatching based on multiple parameters.

The `/dynamic` modifier in a declaration specifies that the code is dynamically
dispatched.
A dynamic code must have at least one `dynamic` parameter.
Also, all dynamic parameters must be pointers or aliases to a
[data type](#TODO) in some hierarchy.

A dynamic declaration requires other compatible dynamic declarations with the
same name, modifiers, parameters, and return type.
The exceptions are the `dynamic` parameters, which must be in the same
hierarchy of their corresponding parameters in other declarations.

To determine which declaration to execute during runtime, the actual argument
is checked against the first formal `dynamic` parameter of each declaration.
The declaration with the most specific type matching the argument wins.
In the case of a tie, the next dynamic parameter is checked.

A *catchall* declaration with the most general dynamic types must always be
provided.

Examples:

```ceu
data Media as nothing;
data Media.Audio with <...> end
data Media.Video with <...> end

code/await/dynamic Play (dynamic var& Media media) -> void do
    _assert(0);             // never dispatched
end
code/await/dynamic Play (dynamic var& Media.Audio media) -> void do
    <...>                   // plays an audio
end
code/await/dynamic Play (dynamic var& Media.Video media) -> void do
    <...>                   // plays a video
end

var& Media m = <...>;       // receives one of "Media.Audio" or "Media.Video"
await/dynamic Play(&m);     // dispatches the appropriate subprogram to play the media
```
