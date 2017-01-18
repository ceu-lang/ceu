<!--
The [compiler](#TODO) of Céu generates as output a program in C, which is
embedded in a host program also in C, which is further compiled to the final
binary program.

MOVE to #compiler?
-->

Environment
===========

As a reactive language, Céu depends on an external environment (the host 
platform) to provide input and output events to programs.
The environment is responsible for sensing the world and notifying Céu about changes.
The actual events vary from environment to environment, as well as the 
implementation for the notification mechanism (e.g. *polling* or 
*interrupt-driven*).

The C API
---------

The final output of the compiler of Céu is a program in C that follows a 
standard application programming interface.
The interface specifies some types, macros, and functions, which the 
environment has to manipulate in order to guide the execution of the original 
program in Céu.

The example below illustrates a possible `main` for a host platform:

```c
#include "_ceu_app.c"

int main (void)
{
    char mem[sizeof(CEU_Main)];
    tceu_app app;
        app.data = &mem;
    ceu_app_init(&app);

    while(app->isAlive) {
        ceu_sys_go(app, CEU_IN__ASYNC,  CEU_EVTP((void*)NULL));
        ceu_sys_go(app, CEU_IN__WCLOCK, CEU_EVTP(<how-much-time-since-previous-iteration>));
        if (occuring(CEU_IN_EVT1)) {
            ceu_sys_go(app, CEU_IN__EVT1, param1);
        }
        ...
        if (occuring(CEU_IN_EVTn)) {
            ceu_sys_go(app, CEU_IN__EVTn, paramN);
        }
    }
    return app->ret;
}

int occurring (int evt_id) {
    <platform dependent>
}
```

`tceu_app` is a type that represents an application in Céu.
The field `app.data` expects a pointer to the memory of the application, which 
has to be previously declared.

`TODO`

### Types

`TODO`

`TODO (index clash)`

### Functions

`TODO`

`TODO (index clash)`

### Macros

`TODO`

### Constants and Defines

`TODO`

<!--

The following functions should be called by the environment to command the execution of Céu programs:

* <tt>int ceu_go_init (int* ret)</tt>
: Initializes and starts the program.
: Should be called by the environment once, to start the Céu program.
: If the program terminates, the function returns <tt>1</tt> and sets <tt>ret</tt> to the return value of the program.
: Otherwise, the function returns <tt>0</tt>.
:
* <tt>int ceu_go_event (int* ret, int id, void* data)</tt>
: Signals the occurrence of the given event to the Céu runtime.
: The function receives the identifier of the input event (see [[#sec.env.api.constants|constants]]) and a pointer to its data.
: The program resumes on the trails awaiting the event, whose awaiting expressions return the received <tt>data</tt>.
: The return procedure of the function behaves as <tt>ceu_go_init</tt>.
:
* <tt>int ceu_go_async (int* ret, int* count)</tt>
: Executes a suspended asynchronous block for a time slice.
: The time slice is not specified, however the execution is interrupted when <tt>ceu_out_pending</tt> is true (see [[#sec.env.api.macros|macros]]).
: The return procedure of the function behaves as <tt>ceu_go_init</tt>, but also sets <tt>count</tt> to the number of suspended asynchronous blocks.
:
* <tt>int ceu_go_wclock (int* ret, s32 dt)</tt>
: Notifies the Céu runtime about the elapsed wall-clock time.
: The function receives the elapsed time in microseconds as <tt>dt</tt>.
: The program resumes on the trails whose wall-clock awaits have expired.
: The return procedure of the function behaves as <tt>ceu_go_init</tt>.
:

Other functions:

* <tt>int ceu_go_all ()</tt>
: Combines <tt>ceu_go_init</tt> with an infinite loop that continuously calls <tt>ceu_go_async</tt>.
: Expects that all events are generated from asynchronous blocks (see [[#sec.stmts.asyncs.simulation|simulation]]).

<span id="sec.env.api.macros"></span>

--### Macros

The following macros can be optionally defined by the environment to customize the behavior of the Céu runtime:

* <tt>ceu_out_pending()</tt>
: Probes the environment for the existence of pending input events.
: The expected return value is 1 (true) or 0 (false).
: This macro is called from the Céu runtime to interrupt the execution of asynchronous blocks when the environment has a pending input event.
: By default <tt>ceu_out_pending()</tt> translates to <tt>(1)</tt>, meaning that asynchronous blocks execute the least possible time slice before giving control back to the environment.
:
* <tt>ceu_out_wclock(us)</tt>
: Notifies the environment that the next wall-clock await will expire in <tt>us</tt> microseconds.
: This macro must be defined in interrupt-based platforms to remind the environment to call <tt>ceu_go_wclock</tt>.
: The special value <tt>CEU_WCLOCK_NONE</tt> represents the absence of wall-clock awaits.
: *Note: <tt>us</tt> can be sometimes less or equal to zero.*
: By default this macro is not defined, hence, the environment should call <tt>ceu_go_wclock</tt> periodically.
:
* <tt>ceu_out_event(id, len, data)</tt>
: Executes whenever the program emits an output event.
: This macro specifies the side effect associated with output events.
: The returned integer becomes the result of the <tt>emit</tt> in the program.
: <tt>id</tt> is a number that identifies the event (see [[#sec.env.api.constants|constants]]); <tt>len</tt> is the size of the event type; <tt>data</tt> is a pointer to the value emitted.
:
* <tt>ceu_out_event_XXX(data)</tt>
: Per-event version of <tt>ceu_out_event(id,len,data)</tt>.
: <tt>XXX</tt> is the name of the event.
: If this macro is defined for a given event, only this macro is called on the occurrence of that event.
:

--### Constants & Defines

The following constants and defines are generated by the Céu compiler to be used by the environment.

* <tt>CEU_WCLOCKS</tt>, defined if the program uses wall-clock awaits.
: The environment can conditionally compile code for calling system timers and <tt>ceu_go_wclock</tt>.
:
* <tt>CEU_ASYNCS</tt>, defined if the program uses asynchronous blocks.
: The environment can conditionally compile code for calling <tt>ceu_go_async</tt>.
:
* <tt>CEU_FUNC_XXX</tt>, defined for each called C function.
: <tt>XXX</tt> is the name of the function (e.g. CEU_FUNC_printf).
:
* <tt>CEU_IN_XXX</tt>, defined for each input event.
: Every external input event has a unique identifier associated with a number.
: The identifier is the name of the event prefixed with <tt>CEU_IN_</tt> (e.g. CEU_IN_Button).
:
* <tt>CEU_OUT_XXX</tt>, defined for each input event.
: Every external output event has a unique identifier associated with a number.
: The identifier is the name of the event prefixed with <tt>CEU_OUT_</tt> (e.g. CEU_IN_Led).
:
: As an example, consider the following Céu definitions:
:
    input int A, B;
    output void C, D;
:
: The compiler may generate the following constants for them:
:
<pre><code>#define CEU_IN_A    0;
#define CEU_IN_B    5;
#define CEU_OUT_C   0;
#define CEU_OUT_D   1;
</code></pre>
:
: Two input events never have the same associated value. The same holds for output events.
: The values between input and output events are unrelated.
: Also, the values need not to be continuous.

--### Types

Céu expects the following scalar types to be defined by the environment: <tt>s32</tt>, <tt>s16</tt>, <tt>s8</tt>, <tt>u32</tt>, <tt>u16</tt>, and <tt>u8</tt>.
They correspond to signed and unsigned variations of the referred sizes in bits.

Follows an example of possible definitions for the scalar types:

<pre><code>typedef long long  s64;
typedef long       s32;
typedef short      s16;
typedef char       s8;
typedef unsigned long long u64;
typedef unsigned long      u32;
typedef unsigned short     u16;
typedef unsigned char      u8;
</code></pre>

These types are used internally by the language runtime, and can also be used by programmers in Céu programs.
For instance, Céu internally uses a <tt>u64</tt> type to represent wall-clock time.

-->


Compiler
--------

Céu provides a command line compiler that generates C code for a given input program.
The compiler is independent of the target platform.

The generated C output should be included in the main application, and is supposed to be integrated with the specific platform through the presented [[#sec.env.api|API]].

The command line options for the compiler are as follows:

    ./ceu <filename>              # Ceu input file, or `-` for stdin
    
        --output <filename>       # C output file (stdout)
    
        --defs-file <filename>    # define constants in a separate output file (no)
    
        --join (--no-join)        # join lines enclosed by /*{-{*/ and /*}-}*/ (join)
    
        --dfa (--no-dfa)          # perform DFA analysis (no-dfa)
        --dfa-viz (--no-dfa-viz)  # generate DFA graph (no-dfa-viz)
    
        --m4 (--no-m4)            # preprocess the input with `m4` (no-m4)
        --m4-args                 # preprocess the input with `m4` passing arguments in between `"` (no)

The values in parenthesis show the defaults for the options that are omitted.

