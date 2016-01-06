<title>Requests in Céu</title>
<meta http-equiv="Content-Type" content="text/html; charset=UTF-8"/>

# Requests in Céu

## Output and Input Events

Céu interacts with the environment through `input` and `output` events.
An `output` event represents an external resource to which applications 
generate stimuli (e.g., lighting a LED).
An `input` event represents an external resource from which applications 
receive stimuli (e.g., keyboard presses).
Applications `emit` output events and `await` input events:

```
output int  LED;                // lighting a LED
input  char KEY;                // keyboard presses
loop do
    var char key = await KEY;   // next key pressed
    if key == '+' then
        emit LED => 1;          // turn LED on
    else/if key == '-' then
        emit LED => 0;          // turn LED off
    end
end
```

In this example, every time the application receives a stimulus from the 
keyboard with the pressed key, it reacts and generates a stimulus to the LED 
accordingly.

The `emit` is an asynchronous operation, i.e., it notifies the environment 
immediately and proceeds to the next line.
The environment can process the arguments and return a value of type `int`, but 
must not block the application:

```
native do
    /* the environment */
    #define ceu_out_SEND(v)             \
        if (SYSTEM_SEND(v) == <...>) {  \
            return 0; /* success */     \
        } else {                        \
            return 1; /* error */       \
        }
end
output char&& SEND;     /* transmits a packet */
var int err = (emit SEND => "Hello World!");
_assert(err == 0);
```

Assuming that the event `SEND` transmits a network packet, the function 
`SYSTEM_SEND` typically enqueues the argument and returns a status, which is 
mapped to an error code returned to the application.

## Requests: Cause-and-Effect Output-Input

Some resources can generate *and* receive stimuli to/from the application.
In particular, some usage patterns sustain a cause-and-effect relationship 
between output and input events:

```
output char&& SEND;             // sending data
input  void   DONE;             // acknowledging a SEND
var char[] buffer = [0,1,0,1];  // create some data
emit SEND => &&buffer;          // start sending
await DONE;                     // finished sending
<...>                           // data delivery has been confirmed
```

In this example, we use the output event `SEND` to broadcast data and the input 
event `DONE` to be notified on completion.
A `DONE` cannot occur without a previous `SEND`, hence, the cause-and-effect 
relationship applies in this case.

Another example following this cause-and-effect pattern would be requesting a 
character from a serial line:

```
output void SERIAL;
input  char CHAR;
emit SERIAL;
var char c = await CHAR;
```

Or a simple *Echo* client-server:

```
output char&& PING;
input  char&& PONG;
loop do
    await 5s;
    emit PING => "Hello";
    var char&& str = await PONG;
    _printf("%s\n", str);
end
```

In this example, the `PING`-`PONG` sequence abstracts the communication between 
the application and a predefined remote node in the network.
The asynchronous `emit PING` transfers the data in the background, which 
eventually reaches the remote node, which then prepares an answer and sends it 
back to the application, which eventually awakes from the `await PONG`.

All examples use an `emit` to request a service in sequence with an `await` for 
a confirmation (or answer).
Céu provides a syntax sugar to deal with this pattern as follows:

1. An `output/input` declaration joins the `output` and corresponding `input` 
events.
2. A `request` substitutes the sequence of an `emit` followed by an `await`.

We can now rewrite the three examples above:

```
// 1st example
output/input (char&&)=>void SEND_DONE;
var char[] buffer = [0,1,0,1];
request SEND_DONE => &&buffer;

// 2nd example
output/input (void)=>char SERIAL_CHAR;
var char c = request SERIAL_CHAR;

// 3rd example
output/input (char&&)=>char&& PING_PONG;
loop do
    await 5s;
    var char&& str = (request PING_PONG => "Hello");
    _printf("%s\n", str);
end
```

## Safety and Programmability Considerations

The conversion described above for the request pattern is still a 
simplification of the problem and neglects some considerations:

1. *Failure*:  the resource should be allowed to fail and notify the
               application.
2. *Abortion*: the application should be allowed to abort a request and notify
               the resource.
3. *Sessions*: the application should be allowed to make concurrent requests to 
               the same resource.

Ideally, the language should deal with these issues as much transparently as 
possible.

### Failure

We need to consider failures when using the request pattern because the 
requesting `emit` might not always end up awaking the associated `await` as 
expected.
In fact, an error could happen immediately, at the point of the `emit`; or 
later, when the application is already at the point of the corresponding 
`await`.
An *early error* happens if the resource is not yet bounded to the output event 
(e.g., not yet configured or connected).
A *late error* happens if the resource is bounded but cannot handle the request 
now (e.g., it is busy or in an inconsistent state).

The code below catches possible failures when manipulating a resource through 
the raw syntax with the events `OUT` and `IN`:

```
output <t1>      OUT;
input  (int,<t2>) IN;

var <t1> v1 = <...>;
var int err = (emit OUT => v1); // catch an early error

var <t2>? v2;
if err == 0 then
    (err, v2) = await IN;       // catch a late error
end
```

To represent early errors, we use the return value of the `emit`, i.e., a `0` 
represents success, and a `1` represents that the associated resource is not 
yet bounded.

To represent late errors, we add an additional type to the input declaration, 
before the event payload.
Now, besides the input payload, the environment also has to notify about 
errors.
As an example, a `0` represents success, and a `2` represents that the resource 
is busy (to avoid reusing a `1` for early errors).
Also, in the case of a failure, the input payload is not available and is not 
assigned to the corresponding variable.
For this reason, the corresponding variable has to be of an option type.

Putting it all together and using the syntax sugar that Céu provides, we can 
now rewrite the three examples above as follows:

```
// 1st example
output/input (char&&)=>void SEND_DONE;
var char[] buffer = [0,1,0,1];
var int err;
err = (request SEND_DONE => &&buffer);          // extra "err" variable

// 2nd example
output/input (void)=>char SERIAL_CHAR;
var char? c;                                    // extra option modifier "?"
var int err;
(err, c) = request SERIAL_CHAR;                 // extra "err" variable

// 3rd example
output/input (char&&)=>char&& PING_PONG;
every 5s do
    var char&&? str;                            // extra option modifier "?"
    var int err;
    (err, str) = (await PING_PONG => "Hello");  // extra "err" variable
    _printf("%s\n", str!);                      // extra option modifier "!"
end
```

TODO: syntax sugar that omits error handling and generates a run-time error 
instead

### Abortion

Céu provides structured abortion primitives, such as the `par/or`, which aborts 
active blocks of code safely, avoiding resource leaks.
Now, consider a modified *Echo* client-server that sends a single message and 
terminates after *5s*:

```
output char&& PING;
input  char&& PONG;
par/or do
    emit PING => "Hello";
    var char&& str = await PONG;
    _printf("%s\n", str);
with
    await 5s;
end
<...>   // do something else
```

After the `emit PING` and while in the `await PONG`, the `par/or` might abort 
the ongoing request due to awaking from the `await 5s`.
Note that the application is no longer interested in the `PONG` answer: the 
`str` is out of scope and the `_printf()` will never execute.
However, the `emit PING` started the communication and the remote node might do 
unnecessary work and also transfer data that will never be used.

To overcome this inefficiency, the `emit`/`await` sequence needs to include a 
`finalize` clause to cancel the ongoing request in the case the enclosing block 
terminates:

```
output char&& PING;
input  char&& PONG;
output void   CANCEL;
par/or do
    do                      // additional block around emit/await
        finalize with
            emit CANCEL;    // cancel request on abortion
        end
        emit PING => "Hello";
        var char&& str = await PONG;
    end
    _printf("%s\n", str);
with
    await 5s;
end
<...>   // do something else
```

Note that the `CANCEL` is emitted even if the operation executes normally when 
awaking from the `await PONG`.
Hence, the environment implementation has to be neutral with respect to normal 
termination, i.e., the extra `emit CANCEL` should be harmless.

The `request` sugar declares an implicit output event `CANCEL` and also 
includes the finalization clause automatically:

```
output/input char&& PING_PONG;
par/or do
    var int err;
    var char&&? str;
    (err, str) = (request PING_PONG => "Hello");
                    // calls "emit PING_PONG_CANCEL" implicitly
                    // on abortion or normal termination
    _printf("%s\n", str);
with
    await 5s;
end
<...>   // do something else
```

### Sessions

```
output char&& SEND;
input  void   DONE;
par do
    var char[] buffer = [0,1,0,1];
    emit SEND => &&buffer;
    await DONE;
with
    var char[] buffer = [1,0,1,0];
    emit SEND => &&buffer;
    await DONE;
end
```

## The Environment

## input/output
