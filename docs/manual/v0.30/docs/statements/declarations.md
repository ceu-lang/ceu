## Declarations

A declaration introduces a [storage entity](../storage_entities/#storage-entities)
to the enclosing block.
All declarations are subject to [lexical scope](../storage_entities/#lexical-scope).

Céu supports variables, vectors, pools, internal events, and external events:

```ceu

Var  ::= var [`&´|`&?´] [ `[´ [Exp [`*`]] `]´ ] [`/dynamic´|`/nohold´] Type ID_int [`=´ Sources]
Pool ::= pool [`&´] `[´ [Exp] `]´ Type ID_int [`=´ Sources]
Int  ::= event [`&´] (Type | `(´ LIST(Type) `)´) ID_int [`=´ Sources]

Ext  ::= input  (Type | `(´ LIST(Type) `)´) ID_ext
      |  output (Type | `(´ LIST([`&´] Type [ID_int]) `)´) ID_ext
            [ do Block end ]

Sources ::= /* (see "Assignments") */
```

Most declarations support an initialization [assignment](#assignments).

<!--
See also [Storage Classes](#TODO) for an overview of storage entities.
-->

### Variables

A [variable](../storage_entities/#variables) declaration has an associated
[type](../types/#types) and can be optionally [initialized](#assignments).
Declarations can also be
[aliases or option aliases](../storage_entities/#aliases).

Examples:

```ceu
var  int v = 10;    // "v" is an integer variable initialized to 10
var  int a=0, b=3;  // "a" and "b" are integer variables initialized to 0 and 3
var& int z = &v;    // "z" is an alias to "v"
```

### Vectors

A [vector](../storage_entities/#vectors) declaration specifies a
[dimension](#dimension) between brackets,
an associated [type](../types/#types) and can be optionally
[initialized](#assignments).
Declarations can also be [aliases](../storage_entities/#aliases).
`TODO: ring buffers`

<!--
`TODO: unmacthing [] in binding`
-->

Examples:

```ceu
var int n = 10;
var[10] int vs1 = [];    // "vs1" is a static vector of 10 elements max
var[n]  int vs2 = [];    // "vs2" is a dynamic vector of 10 elements max
var[]   int vs3 = [];    // "vs3" is an unbounded vector
var&[]  int vs4 = &vs1;  // "vs4" is an alias to "vs1"
```

### Pools

A [pool](../storage_entities/#pools) declaration specifies a dimension and an
associated [type](../types/#types).
Declarations for pools can also be [aliases](../storage_entities/#aliases).
Only in this case they can be [initialized](#assignments).

The expression between the brackets specifies the [dimension](#dimension) of
the pool.

Examples:

```ceu
code/await Play (...) do ... end
pool[10] Play plays;        // "plays" is a static pool of 10 elements max
pool&[]  Play a = &plays;   // "a" is an alias to "plays"
```

<!--
See also [Code Invocation](#TODO).
-->

`TODO: data pools`

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
- `TODO: ring buffers`

### Events

An [event](../storage_entities/#events) declaration specifies a
[type](../types/#types) for the values it carries when occurring.
It can be also a list of types if the event communicates multiple values.

<!--
See also [Introduction](#TODO) for a general overview of events.
-->

#### External Events

Examples:

```ceu
input  none A;          // "A" is an input event carrying no values
output int  MY_EVT;     // "MY_EVT" is an output event carrying integer values
input (int,byte&&) BUF; // "BUF" is an input event carrying an "(int,byte&&)" pair
```

`TODO: output &/impl`

#### Internal Events

Declarations for internal events can also be
[aliases](../storage_entities/#aliases).
Only in this case they can be [initialized](#assignments).

Examples:

```ceu
event  none a;          // "a" is an internal events carrying no values
event& none z = &a;     // "z" is an alias to event "a"
event (int,int) c;      // "c" is a internal event carrying an "(int,int)" pair
```
