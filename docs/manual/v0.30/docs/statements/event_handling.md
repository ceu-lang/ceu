## Event Handling

### Await

The `await` statement halts the running trail until the specified event occurs.
The event can be an [input event](../storage_entities/#external-events), an
[internal event](../storage_entities/#internal-events), a terminating
[code abstraction](#code), a timer, a
[pausing event](#pausing_1), or forever (i.e., never awakes):

```ceu
Await ::= await (ID_ext | Loc) [until Exp]      /* events and option aliases */
       |  await (WCLOCKK|WCLOCKE)               /* timers */
       |  await (pause|resume)                  /* pausing events */
       |  await FOREVER                         /* forever */
```

Examples:

```ceu
await A;                  // awaits the input event "A"
await a until v==10;      // awaits the internal event "a" until the condition is satisfied

var&? My_Code my = <...>; // acquires a reference to a code abstraction instance
await my;                 // awaits it terminate

await 1min10s30ms100us;   // awaits the specified time
await (t)ms;              // awaits the current value of the variable "t" in milliseconds

await FOREVER;            // awaits forever
```

An `await` evaluates to zero or more values which can be captured with an
optional [assignment](#assignments).

#### Event

The `await` statement for events halts the running trail until the specified
[input event](../storage_entities/#external-events) or
[internal event](../storage_entities/#internal-events) occurs.
The `await` evaluates to a value of the type of the event.

The optional clause `until` tests an awaking condition.
The condition can use the returned value from the `await`.
It expands to a [`loop`](#simple-loop) as follows:

```ceu
loop do
    <ret> = await <evt>;
    if <Exp> then   // <Exp> can use <ret>
        break;
    end
end
```

Examples:

```ceu
input int E;                    // "E" is an input event carrying "int" values
var int v = await E until v>10; // assigns occurring "E" to "v", awaking only when "v>10"

event (bool,int) e;             // "e" is an internal event carrying "(bool,int)" pairs
var bool v1;
var int  v2;
(v1,v2) = await e;              // awakes on "e" and assigns its values to "v1" and "v2"
```

#### Code Abstraction

The `await` statement for a [code abstraction](#code) halts the running trail
until the specified instance terminates.

The `await` evaluates to the return value of the abstraction.

`TODO: option return on kill`

Example:

```ceu
var&? My_Code my = spawn My_Code();
var? int ret = await my;
```

#### Timer

The `await` statement for timers halts the running trail until the specified
timer expires:

- `WCLOCKK` specifies a constant timer expressed as a sequence of value/unit
  pairs.
- `WCLOCKE` specifies an [integer](../types/#primitives) expression in
  parenthesis followed by a single unit of time.

The `await` evaluates to a value of type `s32` and is the
*residual delta time (`dt`)* measured in microseconds:
    the difference between the actual elapsed time and the requested time.
The residual `dt` is always greater than or equal to 0.


If a program awaits timers in sequence (or in a `loop`), the residual `dt` from
the preceding timer is reduced from the timer in sequence.

Examples:

```ceu
var int t = <...>;
await (t)ms;                // awakes after "t" milliseconds
```

```ceu
var int dt = await 100us;   // if 1000us elapses, then dt=900us (1000-100)
await 100us;                // since dt=900, this timer is also expired, now dt=800us (900-100)
await 1ms;                  // this timer only awaits 200us (1000-800)
```

<!--
Refer to [[#Environment]] for information about storage types for *wall-clock*
time.
-->

#### Pausing

Pausing events are dicussed in [Pausing](#pausing_1).

#### `FOREVER`

The `await` statement for `FOREVER` halts the running trail forever.
It cannot be used in assignments because it never evaluates to anything.

Example:

```ceu
if v==10 then
    await FOREVER;  // this trail never awakes if condition is true
end
```

### Emit

The `emit` statement broadcasts an event to the whole program.
The event can be an [external event](../storage_entities/#external-events), an
[internal event](../storage_entities/#internal-events), or a timer:

```ceu
Emit_Int ::= emit Loc [`(´ [LIST(Exp)] `)´]
Emit_Ext ::= emit ID_ext [`(´ [LIST(Exp)] `)´]
          |  emit (WCLOCKK|WCLOCKE)
```

Examples:

```ceu
emit A;         // emits the output event `A` of type "void"
emit a(1);      // emits the internal event `a` of type "int"

emit 1s;        // emits the specified time
emit (t)ms;     // emits the current value of the variable `t` in milliseconds
```

#### Events

The `emit` statement for events expects the arguments to match the event type.

An `emit` to an input or timer event can only occur inside
[asynchronous blocks](#asynchronous-block).

An `emit` to an output event is also an expression that evaluates to a value of
type `s32` and can be captured with an optional [assignment](#assignments) (its
meaning is platform dependent).

An `emit` to an internal event starts a new
[internal reaction](../#internal-reactions).

Examples:

```ceu
input int I;
async do
    emit I(10);         // broadcasts "I" to the application itself, passing "10"
end

output void O;
var int ret = emit O(); // outputs "O" to the environment and captures the result

event (int,int) e;
emit e(1,2);            // broadcasts "e" passing a pair of "int" values
```

#### Timer

The `emit` statement for timers expects a [timer expression](#timer).

Like input events, time can only be emitted inside [asynchronous 
blocks](#asynchronous-blocks).

Examples:

```ceu
async do
    emit 1s;    // broadcasts "1s" to the application itself
end
```

### Lock

`TODO`
