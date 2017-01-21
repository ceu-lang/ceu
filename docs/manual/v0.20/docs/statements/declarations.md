## Declarations

A declaration introduces a [storage entity](../storage_classes/#storage-classes)
to the enclosing block.
All declarations are subject to [lexical scope](../storage_classes/#lexical-scope).

Céu supports variables, vectors, external events, internal events, and pools:

```ceu
Var  ::= var [`&´|`&?´] Type LIST(ID_int [`=´ Cons])
Vec  ::= vector [`&´] `[´ [Exp] `]´ Type LIST(ID_int [`=´ Cons])
Ext  ::= input  (Type | `(´ LIST(Type) `)´) LIST(ID_ext)
      |  output (Type | `(´ LIST(Type) `)´) LIST(ID_ext)
Int  ::= event [`&´|`&?´] (Type | `(´ LIST(Type) `)´) LIST(ID_int [`=´ Cons])
Pool ::= pool [`&´] `[´ [Exp] `]´ Type LIST(ID_int [`=´ Cons])

Cons ::= /* (see "Assignments") */
```

Most declarations support an initialization [assignment](#assignments).

<!--
See also [Storage Classes](#TODO) for an overview of storage entities.
-->

### Variables

A [variable](../storage_classes/#variables) declaration has an associated
[type](../types/#types) and can be optionally [initialized](#assignments).
A single statement can declare multiple variables of the same type.
Declarations can also be
[aliases or option aliases](../storage_classes/#aliases).

Examples:

```ceu
var  int v = 10;    // "v" is an integer variable initialized to 10
var  int a=0, b=3;  // "a" and "b" are integer variables initialized to 0 and 3
var& int z = &v;    // "z" is an alias to "v"
```

### Vectors

A [vector](../storage_classes/#vectors) declaration specifies a
[dimension](#dimension) between brackets,
an associated [type](../types/#types) and can be optionally
[initialized](#assignments).
A single statement can declare multiple vectors of the same dimension and type.
Declarations can also be [aliases](../storage_classes/#aliases).

<!--
`TODO: unmacthing [] in binding`
-->

Examples:

```ceu
var int n = 10;
vector[10] int vs1 = [];    // "vs1" is a static vector of 10 elements max
vector[n]  int vs2 = [];    // "vs2" is a dynamic vector of 10 elements max
vector[]   int vs3 = [];    // "vs3" is an unbounded vector
vector&[]  int vs4 = &vs1;  // "vs4" is an alias to "vs1"
```

### Events

An [event](../storage_classes/#events) declaration specifies a
[type](../types/#types) for the values it carries when occurring.
It can be also a list of types if the event communicates multiple values.
A single statement can declare multiple events of the same type.

<!--
See also [Introduction](#TODO) for a general overview of events.
-->

#### External Events

Examples:

```ceu
input  void A,B;        // "A" and "B" are input events carrying no values
output int  MY_EVT;     // "MY_EVT" is an output event carrying integer values
input (int,byte&&) BUF; // "BUF" is an input event carrying an "(int,byte&&)" pair
```

#### Internal Events

Declarations for internal events can also be
[aliases or option aliases](../storage_classes/#aliases).
Only in this case they can be [initialized](#assignments).

Examples:

```ceu
event  void a,b;        // "a" and "b" are internal events carrying no values
event& void z = &a;     // "z" is an alias to event "a"
event (int,int) c;      // "c" is a internal event carrying an "(int,int)" pair
```

### Pools

A [pool](../storage_classes/#pools) declaration specifies a dimension and an
associated [type](../types/#types).
A single statement can declare multiple pools of the same dimension and type.
Declarations for pools can also be [aliases](../storage_classes/#aliases).
Only in this case they can be [initialized](#assignments).

The expression between the brackets specifies the [dimension](#dimension) of the
pool.

Examples:

```ceu
code/await Play (...) do ... end
pool[10] Play plays;        // "plays" is a static pool of 10 elements max
pool&[]  Play a = &plays;   // "a" is an alias to "plays"
```

<!--
See also [Code Invocation](#TODO).
-->

`TODO: data`

### Dimension

Declarations for [vectors](#vectors) or [pools](#pools) require an expression
between brackets to specify a dimension as follows:

- *constant expression*: Maximum number of elements is fixed and space is
                         statically pre-allocated.
- *variable expression*: Maximum number of elements is fixed but space is
                         dynamically allocated.
                         The expression is evaulated once at declaration time.
- *omitted*: Maximum number of elements is unbounded and space is dynamically
             allocated.
             The space for dynamic dimensions grow and shrink automatically.
