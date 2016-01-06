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

In this example, we use the output event `SEND` to send data to a specific 
machine and the input event `DONE` to be notified of completion.

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
every 5s do
    emit PING => "Hello";
    var char&& str = await PONG;
    _printf("%s\n", str);
end
```

The examples use an `emit` to request a service in sequence with an `await` for 
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
every 5s do
    var char&& str = (await PING_PONG => "Hello");
    _printf("%s\n", str);
end
```

## Safety and Programmability Considerations

The conversion described above is still a simplification of the problem and 
neglects some considerations:

1. *Failure*:  the resource should be allowed to fail and notify the
               application.
2. *Abortion*: the application should be allowed to abort a request and notify
               the resource.
3. *Sessions*: the application should be allowed to make concurrent requests to 
               the same resource.

Ideally, the language should deal with these issues as much transparently as 
possible.

### Failure

The first problem with the conversion above is that it does handle failures.
Considering the raw syntax (without the `output/input` and `request` sugars), 
an error could happen immediately, at the point of the `emit`; or later, when 
the application is already at the point of the corresponding `await`.
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

In Céu, an `emit` to an output event returns a value of type `int` as an 
immediate feedback.
Although each environment implementation can give its own semantics, this value 
typically represents error codes.
Hence, to handle early errors, we use the return value of the `emit`.
As an example, a `0` represents success, and a `1` represents that the 
associated resource is not yet bounded.

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
output/input (char&&)=>void SEND_DONE;          // unmodified
var char[] buffer = [0,1,0,1];
request SEND_DONE => &&buffer;                  // unmodified

// 2nd example
output/input (void)=>char SERIAL_CHAR;          // unmodified
var char? c;                                    // extra option modifier "?"
var int err;
(err, c) = request SERIAL_CHAR;                 // extra "err" variable

// 3rd example
output/input (char&&)=>char&& PING_PONG;        // unmodified
every 5s do
    var char&&? str;                            // extra option modifier "?"
    var int err;
    (err, str) = (await PING_PONG => "Hello");  // extra "err" variable
    _printf("%s\n", str!);                      // extra option modifier "!"
end
```

### Abortion

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
