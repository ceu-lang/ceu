<title>Requests in Céu</title>
<meta http-equiv="Content-Type" content="text/html; charset=UTF-8"/>

# Requests in Céu

<!--
Requests in Céu deal with .

set of syntactic constructs

The conversion described above for the request pattern is still a 
simplification of the problem and neglects some desired functionality:

1. *Failure*:  the resource should be allowed to fail and notify the
               application.
2. *Abortion*: the application should be allowed to abort an ongoing request 
               and notify the resource.
3. *Sessions*: the application should be allowed to make concurrent requests to 
               the same resource.

Ideally, the language should deal with these issues as much transparently as 
possible.

TODO: overall description of the concept
Ping-Pong

Install `ceu-mqueue`:
https://github.com/fsantanna/ceu-mqueue/blob/master/INSTALL
.

```
output/input (char[]&&)=>void SEND_DONE;
_printf("sending...\n");
var char[] str = [].."Hello World!";
var int err = (request SEND_DONE => &&str);
_printf("done: %d\n", err);
```

```
input/output (char[]&& v)=>void SEND_DONE do
    _DBG("received %s\n", v);
    loop i in 10 do
        _DBG("thinking...\n");
        await 1s;
    end
    _DBG("returning...\n");
    return;
end
```

# Design
-->

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
keyboard, it reacts and generates an appropriate stimulus to the LED according 
to the pressed key.

The `emit` is an asynchronous operation, i.e., it notifies the environment 
immediately and proceeds to the next line.
The environment can process the arguments and return a value of type `int`, but 
must not block the application indefinitely:

```
/* THE APPLICATION */

output char&& SEND;     /* transmits a packet */
var int err = (emit SEND => "Hello World!");
_assert(err == 0);

/* THE ENVIRONMENT */

/* An "emit SEND=>v" expands to this macro ... */
#define ceu_out_emit_SEND(v) SEND(v);

/* ... which calls this function ... */
int SEND (tceu_char_* v) {
    if (SYSTEM_SEND(v->_1) == <...>) {
        return 0; /* success */
    } else {
        return 1; /* error */
    }
}

/* ... which uses this type. */
typedef struct tceu_char_ {
    char* _1;
} tceu_char_;
    /*
     * (This type is generated automatically and is here only as an 
     * illustration.)
     * Event types are tuples: (tp1, tp2, ...)
     * In C, tuples are structs with fields `_1`, _`2`, ...
     */
```

Assuming that the event `SEND` transmits a network packet, the 
platform-dependent function `SYSTEM_SEND` typically enqueues the argument and 
returns a status, which is mapped to an error code returned to the application.

## Requests: Cause-and-Effect Output-Input

Some resources can generate *and* receive stimuli to/from the application.
In particular, some usage patterns sustain a cause-and-effect relationship 
between output and input events:

```
output char&& SEND;             // broadcasts some data
input  void   DONE;             // acknowledges the broadcast
var char[] buffer = [0,1,0,1];  // create some data
emit SEND => &&buffer;          // trigger the broadcast
await DONE;                     // broadcast confirmed
<...>
```

In this example, we use the output event `SEND` to broadcast data and the input 
event `DONE` to be notified on confirmation.
A `DONE` input cannot occur without a previous `SEND` output, hence, the 
cause-and-effect relationship applies in this case.

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

In the last example, the `PING`-`PONG` sequence abstracts the communication 
between the application and a predefined remote node in the network.
The asynchronous `emit PING` transfers the data in the background, which 
eventually reaches the remote node, which then prepares an answer and sends it 
back to the application, which eventually awakes from the `await PONG`.

In all three examples above, we use an `emit` to request a service in sequence 
with an `await` for a confirmation (with an optional answer).

Céu provides a syntactic sugar to deal with this pattern as follows:

1. An `output/input` declaration unifies the `output` and corresponding `input` 
event declarations.
2. A `request` statement unifies the sequence of an `emit` followed by an 
`await`.

We can now rewrite the three examples above using the syntactic sugar:

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

As we discuss [further](#the-environment), the environment still has to 
manipulate each event separately.
The event names derive from the `output/input` declaration and follow a naming 
convention.

## Safety and Programmability Considerations

The conversion described above for the request pattern is still a 
simplification of the problem and neglects some desired functionality:

1. *Failure*:  the resource should be allowed to fail and notify the
               application.
2. *Abortion*: the application should be allowed to abort an ongoing request 
               and notify the resource.
3. *Sessions*: the application should be allowed to make concurrent requests to 
               the same resource.

Ideally, the language should deal with these issues as much transparently as 
possible.

### Failure

We need to consider failures in the request pattern because the requesting 
`emit` might not always end up awaking the associated `await` as expected.

In fact, an error could happen immediately, at the point of the `emit`; or 
later, when the application is already at the point of the corresponding 
`await`.

An *early error* happens if the resource is not yet bounded to the output event 
(e.g., not yet configured or connected).
A *late error* happens if the resource is bounded but cannot handle the request 
now (e.g., it is busy or in an inconsistent state).

The code below catches possible failures when manipulating a resource through 
the raw syntax, with the events `OUT` and `IN`:

```
output <t1>       OUT;
input  (int,<t2>) IN;               // extra "int" for late errors

var <t1> v1 = <...>;
var int err = (emit OUT => v1);     // catches an early error

var <t2>? v2;
if err == 0 then
    (err, v2) = await IN;           // catches a late error
end
```

To represent early errors, we use the return value of the `emit`, which is 
tested before the `await IN`.
As an example, `0` represents success and `1` represents that the associated 
resource is not yet bounded.

To represent late errors, we add an additional type to the input declaration, 
before the event payload.
Now, the environment also needs to notify about errors.
As an example, `0` represents success and `2` represents that the resource is 
busy (to avoid reusing a `1` for early errors).

In the case of a failure, the input payload is not available and is not 
assigned to the corresponding variable.
For this reason, the corresponding variable has to be of an option type.

Using the syntactic sugar that Céu provides, we can now rewrite the three 
examples above as follows:

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

Note that the error argument is implicit and does not appear in the 
`output/input` declaration.

TODO: syntactic sugar that omits error handling and generates a run-time error 
instead

### Abortion

The `par/or` construct of Céu aborts active blocks of code safely, avoiding 
resource leaks.
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

After the `emit PING` and while idle in the `await PONG`, the `par/or` might 
abort the ongoing request due to awaking from the `await 5s`.
In this case, the application is no longer interested in the `PONG` answer, 
given that `str` is out of scope and the `_printf()` will never execute.
However, the `emit PING` started the communication and the remote node might do 
unnecessary work in addition too transfer data that will never be used.

To overcome this inefficiency, the `emit`-`await` sequence needs to include a 
`finalize` clause to cancel the ongoing request if the enclosing block 
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

The syntactic sugar for requests declares an implicit output event `CANCEL` and 
also includes the finalization clause automatically:

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

Again, as we discuss [further](#the-environment), the cancelling event name 
derive from the `output/input` declaration and follows a naming convention.

### Sessions

<!--
There are no syntactic restrictions on the use of `emit` and `await` 
statements, and as a consequence, also on use of the `request` statement.
In particular,
-->

Nothing prevents the programmer to write requests to the same resource in 
parallel:

```
output char&& SEND;
input  void   DONE;
par/and do
    var char[] buffer = [0,1,0,1];
    emit SEND => &&buffer;
    await DONE;
with
    var char[] buffer = [1,0,1,0];
    emit SEND => &&buffer;
    await DONE;
end
```

In this example, we want to broadcast two messages at the same time, and 
terminate when both transmissions are acknowledged.
However, the two `await DONE` in parallel do not distinguish between the two 
requests: both statements will awake as soon as either of the two transmissions 
is acknowledged.

To disambiguate concurrent requests, we use the concept of *sessions*, which is 
nothing more than a unique identifier shared by an `emit` and its corresponding 
`await` only.

```
output (int,char&&) SEND;                   // extra "int" session
input  int          DONE;                   // extra "int" session
par/and do
    var char[] buffer = [0,1,0,1];
    emit SEND => (1,&&buffer);              // session 1
    var int id = await DONE until id==1;
with
    var char[] buffer = [1,0,1,0];
    emit SEND => (2,&&buffer);              // session 2
    var int id = await DONE until id==2;
end
```

Again, the syntactic sugar for requests handle sessions automatically, 
providing the desired functionality:

```
output/input (char&&)=>void SEND_DONE;
par/and do
    var char[] buffer = [0,1,0,1];
    request SEND_DONE => &&buffer;
with
    var char[] buffer = [1,0,1,0];
    request SEND_DONE => &&buffer;
end
```

<!--
Currently, the session identifier is a dynamic and ever increasing counter such 
that no two sessions can share the same:
start .
-->

## The Full Conversion

Putting it all together, the full conversion is as follows, from the syntactic 
sugar to the full expansion:

```
output/input (<in1>,<in2>,...) => <out> <NAME>;
    // <in1>,<in2>,... // the argument types for the request
    // <out>           // the return type for the request
    // <NAME>          // the request identifier
<...>
var <in1> v1 = <...>;
var <in2> v2 = <...>;
<...>
var int err;
var <out>? ret;
(err, ret) = (request <NAME> => (v1,v2,...);
```

expands to

```
output (int,<in1>,<in2>,...) <NAME>_REQUEST;    // "int" session
output int                   <NAME>_CANCEL;     // "int" session
input  (int,int,<out>)       <NAME>_RETURN;     // "int" session, "int" error
<...>
var <in1> v1 = <...>;
var <in2> v2 = <...>;
<...>
var int err;
var <out>? ret;
do
    var int id = <allocate-session-id>;
    finalize with
        <release-session-id>;
        emit <NAME>_CANCEL => id;
    end
    var int err = (emit <NAME>_REQUEST => (id,v1,v2,...));
    if err == 0 then
        var int id_;
        (id_, err, ret) = await <NAME>_RETURN until id==id_;
    end
end
```

<!--
Besides the desugaring, there is one modification to the language:
The runtime knows that `<NAME>_RETURN` derives from an `output/input` 
declaration and does not assign to `ret` if `err` is nonzero.
(TODO: only required because of `async` simulation.)
-->

## The Environment

The expansion above shows that an `output/input` declaration becomes three 
external events:

```
output/input (<in1>,<in2>,...) => <out> <NAME>;
    /* becomes */
output (int,<in1>,<in2>,...) <NAME>_REQUEST;    // "int" session
output int                   <NAME>_CANCEL;     // "int" session
input  (int,int,<out>)       <NAME>_RETURN;     // "int" session, "int" error
```

The environment implementation has to deal with the three raw events and 
consider session IDs and error codes altogether:

```
/* output: REQUEST */
#define CEU_OUT_<NAME>_REQUEST(args) <NAME>_REQUEST(args)
int <NAME>_REQUEST (tceu_int__<args-tps>* args) {
    /*
     * Manipulates "args->_1", "args->_2", ...
     *      - "args->_1" is the session ID (must be kept somehow)
     *      - the other arguments depend on the request
     */
    return <error-code>;    // signals an "early error"
}

/* output: CANCEL */
#define CEU_OUT_<NAME>_CANCEL(args) <NAME>_CANCEL(args)
int <NAME>_CANCEL (tceu_int* args) {
    /*
     * Manipulates "args->_1", the session ID (and single field).
     * Should use the session ID to abort the ongoing request.
     */
    return 0;   // the returned value is currently ignored
}

/* input: RETURN */
int main (void) {
    /* The event loop: */
    for (;;) {
        <...>
            /*
             * Notifies the application about the request return:
             *      - must provide which <session-id> to awake
             *      - must provide a "late error" code
             *      - the return value depends on the request
             */
            tceu_int__int__<ret-tp> args = { <session-id>, <error-code>, <return-value> };
            ceu_sys_go(&<app>, CEU_IN_<NAME>_RETURN, &args);
    }
}
```

## Resource Implementation in Céu Itself

<!--
So far, we described how to control an external resource from Céu.
Céu also provides a syntactic sugar for the other way around, i.e., an external 
application controlling an application in Céu that represents a resource.


```
input  char&& SEND;             // broadcasts some data
output void   DONE;             // acknowledges the broadcast
loop do
    var char&& buffer = await SEND;
    <...>           // enqueue the buffer
    emit DONE;
end
```

In this example, we use the output event `SEND` to broadcast data and the input 
event `DONE` to be notified on confirmation.
A `DONE` input cannot occur without a previous `SEND` output, hence, the 
cause-and-effect relationship applies in this case.

Another example following this cause-and-effect pattern would be requesting a 
character from a serial line:

```
input  void SERIAL;
output char CHAR;
loop do
    await SERIAL;
    var char c =        // read one character from the serial
        do
            <...>;
            escape <...>;
        end;
    emit CHAR => c;
end
```

Or a simple *Echo* client-server:

```
input  char&& PING;
output char&& PONG;
loop do
    var char&& str = await PING;
    <...>;
    var char&& out =    // prepare an answer
        do
            <...>;
            escape <...>;
        end;
    emit
    emit PONG => out;
end
```

-->
