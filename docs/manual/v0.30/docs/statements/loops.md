## Loops

Céu supports simple loops, numeric iterators, event iterators, and pool
iterators:

```ceu
Loop ::=
      /* simple loop */
        loop [`/´Exp] do
            Block
        end

      /* numeric iterator */
      | loop [`/´Exp] NumericRange do
            Block
        end

      /* event iterator */
      | every [(Loc | `(´ LIST(Loc|`_´) `)´) in] (ID_ext|Loc|WCLOCKK|WCLOCKE) do
            Block
        end

      /* pool iterator */
      | loop [`/´Exp] (ID_int|`_´) in Loc do
            Block
        end

Break    ::= break [`/´ID_int]
Continue ::= continue [`/´ID_int]

NumericRange ::= /* (see "Numeric Iterator") */
```

The body of a loop `Block` executes an arbitrary number of times, depending on
the conditions imposed by each kind of loop.

Except for the `every` iterator, all loops support an optional constant
expression <code>&grave;/&acute;Exp</code> that limits the maximum number of
iterations to avoid [infinite execution](#bounded-execution).
If the number of iterations reaches the limit, a runtime error occurs.

<!--
The expression must be a constant evaluated at compile time.
-->

### `break` and `continue`

The `break` statement aborts the deepest enclosing loop.

The `continue` statement aborts the body of the deepest enclosing loop and
restarts it in the next iteration.

The optional modifier <code>&grave;/&acute;ID_int</code> in both statements
only applies to [numeric iterators](#numeric-iterator).

### Simple Loop

The simple `loop-do-end` statement executes its body forever:

```ceu
SimpleLoop ::= loop [`/´Exp] do
                   Block
               end
```

The only way to terminate a simple loop is with the `break` statement.

Examples:

```ceu
// blinks a LED with a frequency of 1s forever
loop do
    emit LED(1);
    await 1s;
    emit LED(0);
    await 1s;
end
```

```ceu
loop do
    loop do
        if <cnd-1> then
            break;      // aborts the loop at line 2 if <cnd-1> is satisfied
        end
    end
    if <cnd-2> then
        continue;       // restarts the loop at line 1 if <cnd-2> is satisfied
    end
end
```

### Numeric Iterator

The numeric loop executes its body a fixed number of times based on a numeric
range for a control variable:

```ceu
NumericIterator ::= loop [`/´Exp] NumericRange do
                        Block
                    end

NumericRange ::= (`_´|ID_int) in [ (`[´ | `]´)
                                       ( (     Exp `->´ (`_´|Exp))
                                       | (`_´|Exp) `<-´ Exp      ) )
                                   (`[´ | `]´) [`,´ Exp] ]
```

The control variable assumes the values specified in the interval, one by one,
for each iteration of the loop body:

- **control variable:**
    `ID_int` is a read-only variable of a [numeric type](../types/#primitives).
    Alternatively, the special anonymous identifier `_` can be used if the body
    of the loop does not access the variable.
- **interval:**
    Specifies a direction, endpoints with open or closed modifiers, and a step.
    - **direction**:
        - `->`: Starts from the endpoint `Exp` on the left increasing towards `Exp` on the right.
        - `<-`: Starts from the endpoint `Exp` on the right decreasing towards `Exp` on the left.
        Typically, the value on the left is smaller or equal to the value on
        the right.
    - **endpoints**:
        `[Exp` and `Exp]` are closed intervals which include `Exp` as the
        endpoints;
        `]Exp` and `Exp[` are open intervals which exclude `Exp` as the
        endpoints.
        Alternatively, the finishing endpoint may be `_` which means that the
        interval goes towards infinite.
    - **step**:
        An optional positive number added or subtracted towards the limit.
        If the step is omitted, it assumes the value `1`.
        If the direction is `->`, the step is added, otherwise it is subtracted.

    If the interval is not specified, it assumes the default `[0 -> _[`.

A numeric iterator executes as follows:

- **initialization:**
    The starting endpoint is assigned to the control variable.
    If the starting enpoint is open, the control variable accumulates a step
    immediately.

- **iteration:**
    1. **limit check:**
        If the control variable crossed the finishing endpoint, the loop
        terminates.
    2. **body execution:**
        The loop body executes.
    3. **step**
        Applies a step to the control variable. Goto step `1`.

The `break` and `continue` statements inside numeric iterators accept an
optional modifier <code>&grave;/&acute;ID_int</code> to affect the enclosing
loop matching the control variable.

Examples:

```ceu
// prints "i=0", "i=1", ...
var int i;
loop i do
    _printf("i=%d\n", i);
end
```

```ceu
// awaits 1s and prints "Hello World!" 10 times
loop _ in [0 -> 10[ do
    await 1s;
    _printf("Hello World!\n");
end
```

```ceu
var int i;
loop i do
    var int j;
    loop j do
        if <cnd-1> then
            continue/i;         // continues the loop at line 1
        else/if <cnd-2> then
            break/j;            // breaks the loop at line 4
        end
    end
end
```

*Note : the runtime asserts that the step is a positive number and that the
        control variable does not overflow.*

### Event Iterator

The `every` statement iterates over an event continuously, executing its
body whenever the event occurs:

```ceu
EventIterator ::= every [(Loc | `(´ LIST(Loc|`_´) `)´) in] (ID_ext|Loc|WCLOCKK|WCLOCKE) do
                      Block
                  end
```

The event can be an [external or internal event](#event) or a [timer](#timer).

The optional assignment to a variable (or list of variables) stores the
carrying value(s) of the event.

An `every` expands to a `loop` as illustrated below:

```ceu
every <vars> in <event> do
    <body>
end
```

is equivalent to

```ceu
loop do
    <vars> = await <event>;
    <body>
end
```

However, the body of an `every` cannot contain
[synchronous control statements](#synchronous-control-statements), ensuring
that no occurrences of the specified event are ever missed.

`TODO: reject break inside every`

Examples:

```ceu
every 1s do
    _printf("Hello World!\n");      // prints the "Hello World!" message on every second
end
```

```ceu
event (bool,int) e;
var bool cnd;
var int  v;
every (cnd,v) in e do
    if not cnd then
        break;                      // terminates when the received "cnd" is false
    else
        _printf("v = %d\n", v);     // prints the received "v" otherwise
    end
end
```

### Pool Iterator

The [pool](../storage_entities/#pools) iterator visits all alive
[abstraction](#code) instances residing in a given pool:

```ceu
PoolIterator ::= loop [`/´Exp] (ID_int|`_´) in Loc do
                     Block
                 end
```

On each iteration, the optional control variable becomes a
[reference](#code-references) to an instance, starting from the oldest created
to the newest.

The control variable must be an alias to the same type of the pool with the
same rules that apply to [`spawn`](#code-invocation).

Examples:

```
pool[] My_Code my_codes;

<...>

var&? My_Code my_code;
loop my_code in mycodes do
    <...>
end
```
