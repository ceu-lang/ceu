Storage Classes
===============

Storage classes represent all entities that are stored in memory at runtime.
Céu supports *variables*, *vectors*, *events* (external and internal), and
*pools* as storage classes.
An entity [declaration](#TODO) consists of a storage class,
a [type](#TODO), and an [identifier](#TODO).

Examples:

```ceu
var       int    v;   // "v" is a variable of type "int"
vector[9] byte   buf; // "buf" is a vector with at most 9 values of type "byte"
input     void&& A;   // "A" is an external event that carries values of type "void&&"
pool[]    Anim   ans; // "ans" is a dynamic "pool" for instances of type "Anim"
```

A declaration binds the identifier with a memory location to hold values of the
associated type.
Entities have lexical scope, i.e., they are visible only in the [block](#TODO)
in which they are declared.
The lifetime of entities, (i.e., the period between allocation and deallocation
in memory) is also limited to the scope of the enclosing block.
However, individual elements inside *vector* and *pool* entities have dynamic
lifetime, but which never outlive the scope of the declaration.

Variables
---------

As in typical imperative languages, a variable in Céu holds a value of a
[declared](#TODO) [type](#TODO) that may vary during program execution.
The value of a variable can be read in [expressions](#TODO) or written in
[assignments](#TODO).
The current value of a variable is preserved until the next assignment, during
its whole lifetime.

<!--
TODO: exceptions for scope/lifetime
- pointers have "instant" lifetime, like fleeting events, scope is unbound
- intermediate values die after "watching", scope is unbound
-->

*Note: since blocks can contain parallel compositions, variables can be read
       and written in trails in parallel.*

Example:

```ceu
var int v = _;  // empty initializaton
par/and do
    v = 1;      // write access
with
    v = 2;      // write access
end
escape v;       // read access (yields 2)
```

Vectors
-------

In Céu, a vector is a dynamic and contiguous collection of elements of the same
type.
A vector [declaration](#TODO) specifies its type and maximum size (possibly
unlimited).
The current size of a vector is dynamic and can be accessed through the
[operator `$`](#TODO).
Individual elements of a vector can be accessed through a
[numeric index](#TODO) starting from `0`.

Example:

```ceu
vector[9] byte buf = [1,2,3];   // write access
buf[$buf+1] = 4;                // write access
escape buf[1];                  // read access (yields 2)
```

Events
------

Events are the most fundamental concept of Céu, accounting for its reactive 
nature.
Programs manipulate events through the `await` and `emit` [statements](#TODO).
An `await` halts the running trail until that event occurs.
An event occurrence is broadcast to all trails trails awaiting that event, 
awaking them to resume execution.

Céu supports external and internal events.
External events are triggered by the [environment](#TODO), while 
internal events, by the `emit` statement.
See also [Synchronous execution model] for the differences between external and 
internal reactions.

Unlike all other storage classes, the value of an event is ephemeral and does
not persist after a reaction terminates.
For this reason, an event identifier is not a variable: values can only
be communicated through `emit` and `await` statements.
A [declaration](#TODO) includes the type of value the occurring event carries.

*Note: <tt>void</tt> is a valid type for signal-only internal events.*

Examples:

```ceu
event int e;   // "e" is an internal event that carries values of type "int"
par do
    var int v = await e; // awaits "e" assigning the received value to "v"
    escape v;            // terminates the program (yields 10)
with
    emit e(10);          // broadcasts "e" passing 10, awakes the "await" above
end
```

### External Events

External events are used as interfaces between programs and devices from the 
real world:

* *input* events represent input devices, such as sensors, switches, etc.
* *output* events represent output devices, such as LEDs, motors, etc.

The availability of external events depends on the platform in use.
Therefore, external declarations only make pre-existing events visible to a 
program.
Refer to [Environment](#TODO) for information about interfacing with 
external events at the platform level.

#### External Input Events

As a reactive language, programs in Céu have input events as entry points in
the code through [await statements](#TODO).

<!--
TODO: parei aqui
-->

#### External Output Events

### Internal Events

<!--
In contrast with external events, an internal event is for input and output at 
the same time.
-->

Pools
-----

Aliases
-------

Exceptions
----------

<!--

### Dimension

`TODO (vectors, pools)`

One-dimensional vectors are declared by suffixing the variable type with the 
vector length surrounded by `[` and `]`.
The first index of a vector is zero.

Example:

<pre><code><b>var int</b>[2] v;       // declares a vector "v" of 2 integers
</code></pre>
-->
