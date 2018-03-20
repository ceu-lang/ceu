## Abstractions

Céu supports reuse with `data` declarations to define new types, and `code`
declarations to define new subprograms.

Declarations are subject to [lexical scope](../storage_entities/#lexical-scope).

### Data

A `data` declaration creates a new data type:

```ceu
Data ::= data ID_abs [as (nothing|Exp)] [ with
             (Var|Vec|Pool|Int) `;´ { (Var|Vec|Pool|Int) `;´ }
         end

Data_Cons ::= (val|new) Abs_Cons
Abs_Cons  ::= [Loc `.´] ID_abs `(´ LIST(Data_Cons|Vec_Cons|Exp|`_´) `)´
```

A declaration may pack fields with
[storage declarations](#declarations) which become publicly
accessible in the new type.
Field declarations may [assign](#assignments) default values for
uninitialized instances.

Data types can form hierarchies using dots (`.`) in identifiers:

- An isolated identifier such as `A` makes `A` a base type.
- A dotted identifier such as `A.B` makes `A.B` a subtype of its supertype `A`.

A subtype inherits all fields from its supertype.

The optional modifier `as` expects the keyword `nothing` or a constant
expression of type `int`:

- `nothing`: the `data` cannot be instantiated.
- *constant expression*: [typecasting](../expressions/#type-cast) a value of
                         the type to `int` evaluates to the specified
                         enumeration expression.

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

A new data value is created in the contexts that follow:

- Prefixed by the keyword `val` in an [assignment](#assignments) to a variable.
- As an argument to a [`code` invocation](#code-invocation).
- Nested as an argument in a `data` creation (i.e., a `data` that contains
  another `data`).

In all cases, the arguments are copied to the destination.
The destination must be a plain declaration (i.e., not an alias or pointer).

The constructor uses the `data` identifier followed by a list of arguments
matching the fields of the type.

Variables of the exact same type can be copied in [assignments](#assignments).

For assignments from a subtype to a supertype, the rules are as follows:

- [Copy assignments](#copy-assignment)
    - plain values: only if the subtype contains no extra fields
    - pointers: allowed
- [Alias assignment](#alias-assignment): allowed.

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

The `code/tight` and `code/await` declarations specify new subprograms that can
be invoked from arbitrary points in programs:

```ceu
// prototype declaration
Code_Tight ::= code/tight Mods ID_abs `(´ Params `)´ `->´ Type
Code_Await ::= code/await Mods ID_abs `(´ Params `)´
                                        [ `->´ `(´ Params `)´ ]
                                            `->´ (Type | NEVER)
                    [ throws LIST(ID_abs) ]
Params ::= none | LIST(Var|Vec|Pool|Int)

// full declaration
Code_Impl ::= (Code_Tight | Code_Await) do
                  Block
              end

// invocation
Code_Call  ::= call  Mods Abs_Cons
Code_Await ::= await Mods Abs_Cons
Code_Spawn ::= spawn Mods Abs_Cons [in Loc]
Code_Kill  ::= kill Loc [ `(` Exp `)` ]

Mods ::= [`/´dynamic | `/´static] [`/´recursive]
```

A `code/tight` is a subprogram that cannot contain
[synchronous control statements](#synchronous-control-statements) and its body
runs to completion in the current [internal reaction](../#internal-reactions).

A `code/await` is a subprogram with no restrictions (e.g., it can manipulate
events and use parallel compositions) and its body execution may outlive
multiple reactions.

A *prototype declaration* specifies the interface parameters of the
abstraction which invocations must satisfy.
A *full declaration* (aka *definition*) also specifies an implementation
with a block of code.
An *invocation* specifies the name of the code abstraction and arguments
matching its declaration.

Declarations can be nested.
A nested declaration is not visible outside its enclosing declaration.
The body of a nested declaration may access entities from its enclosing
declarations with the prefix [`outer`](../expressions/#outer).

To support recursive abstractions, a code invocation can appear before the
implementation is known, but after the prototype declaration.
In this case, the declaration must use the modifier `/recursive`.

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
code/await Hello_World (none) -> NEVER do
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

Code abstractions specify a list of input parameters in between the symbols
`(` and `)`.
Each parameter specifies an [entity class](../storage_entities/#entity-classes)
with modifiers, a type and an identifier.
A `none` list specifies that the abstraction has no parameters.

Code abstractions also specify an output return type.
A `code/await` may use `NEVER` as output to indicate that it never returns.

A `code/await` may also specify an optional *public field list*, which are
local storage entities living in the outermost scope of the abstraction body.
These entities are visible to the invoking context, which may
[access](#code-references) them while the abstraction executes.
Likewise, nested code declarations in the outermost scope, known as methods,
are also visible to the invoking context.

`TODO: throws`

<!--
- The invoker passes a list of unbound aliases to the code.
- The code [binds](#alias-assignment) the aliases to the local resources before
  any [synchronous control statement](#synchronous-control-statements) executes.

Examples:

```ceu
// "Open" abstracts "_fopen"/"_fclose"
code/await Open (var _char&& path) -> (var& _FILE res) -> NEVER do
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
-->

#### Code Invocation

A `code/tight` is invoked with the keyword `call` followed by the abstraction
name and list of arguments.
A `code/await` is invoked with the keywords `await` or `spawn` followed by the
abstraction name and list of arguments.

The list of arguments must satisfy the list of parameters in the
[code declaration](#code-declaration).

The `call` and `await` invocations suspend the current trail and transfer
control to the code abstraction.
The invoking point only resumes after the abstraction terminates and evaluates
to a value of its return type which can be captured with an optional
[assignment](#assignment).

The `spawn` invocation also suspends and transfers control to the code
abstraction.
However, as soon as the abstraction becomes idle (or terminates), the invoking
point resumes.
This makes the invocation point and abstraction to execute concurrently.

The `spawn` invocation evaluates to a [reference](#code-references)
representing the instance and can be captured with an optional
[assignment](#assignment).
The alias must be an [option alias variable](../storage_entities/#aliases) of
the same type of the code abstraction.
If the abstraction never terminates (i.e., return type is `NEVER`), the
variable may be a simple alias.
If the `spawn` fails (e.g., lack of memory) the option alias variable is unset.
In the case of a simple alias, the assignment raises a runtime error.

The `spawn` invocation also accepts an optional [pool](#pools) which provides
storage and scope for invoked abstractions.
When the pool goes out of scope, all invoked abstractions residing in that pool
are aborted.
If the `spawn` omits the pool, the invocation always succeed and has the same
scope as the invoking point: when the enclosing block terminates, the invoked
code is also aborted.

`TODO: kill`

#### Code References

The `spawn` [invocation](#code-invocation) and the control variable of
[pool iterators](#pool-iterator) evaluate to a reference as an
[option alias](../storage_entities/#aliases) to an abstraction instance.
If the instance terminates at any time, the option variable is automatically
unset.

A reference provides [access](../expressions/#fields) to the public fields and
methods of the instance.

Examples:

```ceu
code/await My_Code (var int x) -> (var int y) -> NEVER do
    y = x;                              // "y" is a public field

    code/tight Get_X (none) -> int do   // "Get_X" is a public method
        escape outer.x;
    end

    await FOREVER;
end

var& My_Code c = spawn My_Code(10);
_printf("y=%d, x=%d\n", c.y, c.Get_X());    // prints "y=10, x=10"
```

#### Dynamic Dispatching

Céu supports dynamic code dispatching based on multiple parameters.

The modifier `/dynamic` in a declaration specifies that the code is dynamically
dispatched.
A dynamic code must have at least one `dynamic` parameter.
Also, all dynamic parameters must be pointers or aliases to a
[data type](#data) in some hierarchy.

A dynamic declaration requires other compatible dynamic declarations with the
same name, modifiers, parameters, and return type.
The exceptions are the `dynamic` parameters, which must be in the same
hierarchy of their corresponding parameters in other declarations.

To determine which declaration to execute during runtime, the actual argument
runtime type is checked against the first formal `dynamic` parameter of each
declaration.
The declaration with the most specific type matching the argument wins.
In the case of a tie, the next dynamic parameter is checked.

A *catchall* declaration with the most general dynamic types must always be
provided.

If the argument is explicitly [typecast](../expressions/#type-cast) to a
supertype, then dispatching considers that type instead.

Example:

```ceu
data Media as nothing;
data Media.Audio     with <...> end
data Media.Video     with <...> end
data Media.Video.Avi with <...> end

code/await/dynamic Play (dynamic var& Media media) -> none do
    _assert(0);             // never dispatched
end
code/await/dynamic Play (dynamic var& Media.Audio media) -> none do
    <...>                   // plays an audio
end
code/await/dynamic Play (dynamic var& Media.Video media) -> none do
    <...>                   // plays a video
end
code/await/dynamic Play (dynamic var& Media.Video.Avi media) -> none do
    <...>                                   // prepare the avi video
    await/dynamic Play(&m as Media.Video);  // dispatches the supertype
end

var& Media m = <...>;       // receives one of "Media.Audio" or "Media.Video"
await/dynamic Play(&m);     // dispatches the appropriate subprogram to play the media
```
