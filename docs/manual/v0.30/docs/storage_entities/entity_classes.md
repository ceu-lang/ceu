## Entity Classes

### Variables

A variable in Céu holds a value of a [declared](../statements/#variables)
[type](../types/#types) that may vary during program execution.
The value of a variable can be read in
[expressions](../expressions/#locations-expressions) or written in
[assignments](#assignments).
The current value of a variable is preserved until the next assignment, during
its whole lifetime.

<!--
TODO: exceptions for scope/lifetime
- pointers have "instant" lifetime, like fleeting events, scope is unbound
- intermediate values die after "watching", scope is unbound

*Note: since blocks can contain parallel compositions, variables can be read
       and written in trails in parallel.*
-->

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

### Vectors

A vector in Céu is a dynamic and contiguous collection of variables of the same
type.

A [vector declaration](../statements/#vectors) specifies its type and maximum
number of elements (possibly unlimited).
The current length of a vector is dynamic and can be accessed through the
[operator `$`](../expressions/#length).

Individual elements of a vector can be accessed through an
[index](../expressions/#index) starting from `0`.
Céu generates an [error](#TODO) for out-of-bounds vector accesses.

Example:

```ceu
var[9] byte buf = [1,2,3];  // write access
buf = buf .. [4];           // write access
escape buf[1];              // read access (yields 2)
```

`TODO: ring buffers`

### Events

Events account for the reactive nature of Céu.
Programs manipulate events through the [`await`](../statements/#event) and
[`emit`](../statements/#events_1)
statements.
An `await` halts the running trail until the specified event occurs.
An event occurrence is broadcast to the whole program and awakes trails
awaiting that event to resume execution.

Unlike all other entity classes, the value of an event is ephemeral and does
not persist after a reaction terminates.
For this reason, an event identifier is not a variable: values can only
be communicated through `emit` and `await` statements.
A [declaration](../statements/#events) includes the type of value the occurring
event carries.

*Note: <tt>none</tt> is a valid type for signal-only events with no associated values.*

Example:

```ceu
input  none I;           // "I" is an input event that carries no values
output int  O;           // "O" is an output event that carries values of type "int"
event  int  e;           // "e" is an internal event that carries values of type "int"
par/and do
    await I;             // awakes when "I" occurs
    emit e(10);          // broadcasts "e" passing 10, awakes the "await" below
with
    var int v = await e; // awaits "e" assigning the received value to "v"
    emit O(v);           // emits "O" back to the environment passing "v"
end
```

As described in [Internal Reactions](../#internal-reactions), Céu supports
external and internal events with different behavior.

#### External Events

External events are used as interfaces between programs and devices from the 
real world:

* *input events* represent input devices such as a sensor, button, mouse, etc.
* *output events* represent output devices such as a LED, motor, screen, etc.

The availability of external events depends on the
[environment](../#environments) in use.

Programs can `emit` output events and `await` input events.

<!--
Therefore, external declarations only make pre-existing events visible to a 
program.
Refer to [Environment](#TODO) for information about interfacing with 
external events at the platform level.
-->

<!--
#### External Input Events

As a reactive language, programs in Céu have input events as entry points in
the code through [await statements](#TODO).
Input events represent the notion of [logical time](#TODO) in Céu.

<!-
Only the [environment](#TODO) can emit inputs to the application.
Programs can only `await` input events.
->

#### External Output Events

Output events communicate values from the program back to the
[environment](#TODO).

Programs can only `emit` output events.

-->

#### Internal Events

Internal events, unlike external events, do not represent real devices and are
defined by the programmer.
Internal events serve as signalling and communication mechanisms among trails
in a program.

Programs can `emit` and `await` internal events.

### Pools

A pool is a dynamic container to hold running [code abstractions](../statements/#code).

A [pool declaration](../statements/#pools) specifies the type of the
abstraction and maximum number of concurrent instances (possibly unlimited).
Individual elements of pools can only be accessed through
[iterators](../statements/#pool-iterator).
New elements are created with [`spawn`](../statements/#code-invocation) and are
removed automatically when the code execution terminates.

Example:

```ceu
code/await Anim (none) => none do       // defines the "Anim" code abstraction
    <...>                               // body of "Anim"
end
pool[] Anim as;                         // declares an unlimited container for "Anim" instances
loop i in [1->10] do
    spawn Anim() in as;                 // creates 10 instances of "Anim" into "as"
end
```

When a pool declaration goes out of scope, all running code abstractions are
automatically aborted.

`TODO: kill`

<!--
`TODO: data`
-->
