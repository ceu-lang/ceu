<title>Céu 0.8 - Reference Manual</title>
<meta http-equiv="Content-Type" content="text/html; charset=UTF-8"/></p>

<!--
TODO:
rawstmt, atomic,
lua,
rawexp, luaexp
-->

Introduction
============

Céu is a language targeting reactive applications, aiming to offer a 
higher-level and safer alternative to C.
Reactive applications interact continuously with the environment and are mostly 
guided through input events from it.

Céu is a concurrent language in which multiple lines of execution---known as 
*trails*---continuously react to input events from the environment.
Waiting for an event halts the running trail until that event occurs.
The environment broadcasts an occurring event to all active trails, which share 
a single global time reference (the event itself).
The synchronous concurrency model of Céu greatly diverges from conventional 
multithreading (e.g. *pthreads*) and the actor model (e.g. *erlang*).
For instance, trails can share variables in a safe and seamless way (e.g. no 
need for locks or semaphores).
See the [execution model of Céu](#execution-model).

Céu integrates well with C, being possible to define and call C functions from 
within Céu programs.

Céu is [free software](#license).

<!--
Céu has a memory footprint of around 2Kb of ROM and 50b of RAM (on embedded 
platform such as Arduino).

For a gentle introduction about Céu, see the [interactive 
tutorial](http://www.ceu-lang.org/try.php).

See also the complete [Syntax](#syntax) of Céu.
-->

Execution model
===============

Céu is grounded on a precise definition of *logical time* as a discrete 
sequence of external input events:
a sequence because only a single input event is handled at a logical time; 
discrete because reactions to events are guaranteed to execute in bounded time 
(here the *physical* notion of time, see [Bounded 
execution](#bounded-execution)).

The execution model for Céu programs is as follows:

1. The program initiates the *boot reaction* in a single trail.
2. Active trails, one after another, execute until they await or terminate.
      This step is named a *reaction chain*, and always runs in bounded time.
3. The program goes idle and the environment takes control.
4. On the occurrence of a new external input event, the environment awakes 
      *all* trails awaiting that event.
      It then goes to step 2.

The synchronous execution model of Céu is based on the hypothesis that internal 
reactions run *infinitely faster* in comparison to the rate of external events.
An internal reaction is the set of computations that execute when an external 
event occurs.
Conceptually, a program takes no time on step 2 and is always idle on step 3.
In practice, if a new external input event occurs while a reaction chain is 
running (step 2), it is enqueued to run in the next reaction.
When multiple trails are active at a logical time (i.e. awaking on the same 
event), Céu schedules them in the order they appear in the program text.
This policy is somewhat arbitrary, but provides a priority scheme for trails, 
and also ensures deterministic and reproducible execution for programs.
Note that, at any time, at most one trail is executing.

The program and diagram that follows illustrate the behavior of the scheduler 
of Céu:

<pre><code> 1:  <b>input void</b> A, B, C;
 2:  <b>par/and do</b>
 3:      // trail 1
 4:      &lt;...&gt;         // &lt;...&gt; represents non-awaiting statements
 5:      <b>await</b> A;
 6:      &lt;...&gt;
 7:  <b>with</b>
 8:      // trail 2
 9:      &lt;...&gt;
10:      <b>await</b> B;
11:      &lt;...&gt;
12:  <b>with</b>
13:      // trail 3
14:      &lt;...&gt;
15:      <b>await</b> A;
16:      &lt;...&gt;
17:      <b>await</b> B;
18:      <b>par/and do</b>
19:          // trail 3
20:          &lt;...&gt;
21:      <b>with</b>
22:          // trail 4
23:          &lt;...&gt;
24:      <b>end</b>
25:  <b>end</b>
</code></pre>

![a](reaction.png)

The program starts in the boot reaction and is split in three trails.
Following the order of declaration, the scheduler first executes *trail-1*
until it awaits `A` in line 5;
then *trail-2* executes until it awaits `B` in line 10;
then *trail-3* is scheduled and also awaits `A`, in line 15.
%
As no other trails are pending, the reaction chain terminates and the scheduler 
remains idle until the occurrence of `A`:
*trail-1* awakes, executes and terminates;
and then *trail-3* executes and waits for `B` in line 17.
*Trail-2* remains suspended, as it is not awaiting `A`.
%
During this reaction, new instances of events `A`, `B`, and `C` occur and are 
enqueued to be handled in the reactions that follow.
%
As `A` happened first, it is used in the next reaction.
However, no trails are awaiting it, so an empty reaction chain takes place.
%
The next reaction dequeues event `B`:
*trail-2* awakes, executes and terminates;
then *trail-3* is split in two and both terminate.
%
The program terminates and does not react to the pending event `C`.
% (the \code{par/and}, to be introduced in the next section, rejoins when its 
%sub-trails terminate).
%
Note that each step in the logical time line (*t0*, *t1*, etc.) is identified 
by the event it handles.
Inside a reaction, trails only react to that identifying event (or remain 
suspended).

TODO: ints
<!--
A reaction chain may also contain emissions and reactions to internal events, 
which are presented in Section~\ref{sec.ceu.ints}.
-->

Bounded execution
-----------------

Reaction chains should run in bounded time to guarantee that programs are 
responsive and can handle upcoming input events from the environment.
Céu requires that each possible path in a loop body contains at least one 
`await` or `break` statement, thus avoiding *tight loops* (i.e., unbounded 
loops that do not await).

In the example that follows, the `if` true branch may never execute, resulting 
in a tight loop (which the compiler complains about):

<pre><code><b>loop do</b>
    <b>if</b> &lt;cond&gt; <b>then</b>
        <b>break</b>;
    <b>end</b>
<b>end</b>
</code></pre>

For time-consuming algorithms that require unrestricted loops (e.g., 
cryptography, image processing), Céu provides [Asynchronous 
execution](#asynchronous-execution).

Parallel compositions and abortion
----------------------------------

The use of trails in parallel allows programs to wait for multiple events at 
the same time.
Céu supports three kinds of parallel constructs differing in how they rejoin 
(to proceed to the statement in sequence):

1. a `par/and` rejoins after all trails in parallel terminate;
2. a `par/or` rejoins after any trail in parallel terminates;
3. a `par` never rejoins (even if all trails terminate).

The termination of a trail inside a `par/or` aborts the other trails in 
parallel, which must be necessarily awaiting (from rule 2 of [Execution 
model](#execution-model)).
Before aborting, a trail has a last opportunity to execute all active 
[finalization statements](finalization).

<!--
Shared-memory concurrency
-------------------------

TODO
-->

Lexical rules
=============

Keywords
--------

Keywords in Céu are reserved names that cannot be used as identifiers:

<pre><code><b>
        and         async       atomic      await       bool

        break       byte        call        call/rec    char

        class       continue    do          else        else/if

        emit        end         escape      event       every

        f32         f64         false       finalize    float

        FOREVER     free        function    global      if

        in          input       input/output    int     interface

        isr         loop        native      new         not

        nothing     null        or          outer       output

        output/input    par     par/and     par/or      pause/if

        pool        return      s16         s32         s64

        s8          sizeof      spawn       sync        then

        this        thread      true        u16         u32

        u64         u8          uint        until       var

        void        watching    with        word

        @const      @hold       @nohold     @plain      @pure

        @rec        @safe

</b></code></pre>

Identifiers
-----------

Céu uses identifiers to refer to *variables*, *internal events*, *external 
events*,  *classes/interfaces*, and*native symbols*.

```
ID      ::= <a-z, A-Z, 0-9, _> +
ID_var  ::= ID    // beginning with a lowercase letter
ID_ext  ::= ID    // all in uppercase, not beginning with a digit
ID_cls  ::= ID    // beginning with an uppercase letter
ID_nat  ::= ID    // beginning with an underscore
```

Examples:

<pre><code><b>var int</b> a;                    // "a" is a variable
<b>emit</b> e;                       // "e" is an internal event
<b>await</b> E;                      // "E" is an external input event
<b>var</b> T t;                      // "T" is a class
_printf("hello world!\n");    // "_printf" is a native symbol
</code></pre>


Literals
--------

### Booleans

Boolean types have the values `true` and `false`.

### Integers

Integer values can be written in different bases and also as ASCII characters:

* Decimals are written *as is*.
* Octals are prefixed with <tt>0</tt>.
* Hexadecimals are prefixed with <tt>0x</tt>.
* ASCII characters and escape sequences are surrounded by apostrophes.
* TODO: "1e10"

Examples:

```
// all following are equal to the decimal 127
v = 127;
v = 0777;
v = 0x7F;

// newline ASCII character = decimal 10
c = '\n';
```

### Floats

TODO

### Null pointer

The `null` literal represents null [pointers](#pointers).

### Strings

A sequence of characters surrounded by `"` is converted into a *null-terminated 
string*, just like in C:

Example:

```
_printf("Hello World!\n");
```

Comments
--------

Céu provides C-style comments.

Single-line comments begin with `//` and run to end of the line.

Multi-line comments use `/*` and `*/` as delimiters.
Multi-line comments can be nested by using a different number of `*` as delimiters.

Examples:

<pre><code><b>var int</b> a;    // this is a single-line comment

/** comments a block that contains comments

<b>var int</b> a;
/* this is a nested multi-line comment
a = 1;
*/

**/
</code></pre>


Types
=====

Céu is statically typed, requiring all variables and events to be declared before they are used.

<!--
[ TODO ]
, the [[Assignable expressions]] in the left and the assigning expression in the right must match the [[#sec.type|types]].
-->

A type is composed of an identifier with an optional modifier:

<pre><code>Type ::= ID_type ( {`*´} | `&´ | `[´ `]´ | `[´ NUM `]´ )
</code></pre>

A type identifier can be a [native identifier](#identifiers), a [class 
identifier](#identifiers), or one of the primitive types:

<pre><code>ID_type ::= ( ID_nat | ID_cls |
              <b>bool</b>  | <b>byte</b>  | <b>char</b>  | <b>f32</b>   | <b>f64</b>   |
              <b>float</b> | <b>int</b>   | <b>s16</b>   | <b>s32</b>   | <b>s64</b>   |
              <b>s8</b>    | <b>u16</b>   | <b>u32</b>   | <b>u64</b>   | <b>u8</b>    |
              <b>uint</b>  | <b>void</b>  | <b>word</b> )
</code></pre>

Examples:

<pre><code><b>var u8</b> v;       // "v" is of 8-bit unsigned integer type
<b>var</b> _rect r;    // "r" is of external native type `rect`
<b>var char</b>* buf;  // "buf" is a pointer to a `char`
</code></pre>

Primitive types
---------------

Céu has the following primitive types:

<pre><code>    <b>void           </b>    // void type
    <b>word           </b>    // type with the size of platform dependent word
    <b>bool           </b>    // boolean type
    <b>char           </b>    // char type
    <b>byte           </b>    // 1-byte type
    <b>int      uint  </b>    // platform dependent signed and unsigned integer
    <b>s8       u8    </b>    // signed and unsigned  8-bit integer
    <b>s16      u16   </b>    // signed and unsigned 16-bit integer
    <b>s32      u32   </b>    // signed and unsigned 32-bit integer
    <b>s64      u64   </b>    // signed and unsigned 64-bit integer
    <b>float          </b>    // platform dependent float
    <b>f32      f64   </b>    // 32-bit and 64-bit floats
</code></pre>

See also the [literals](#literals) for these types.

Native types
------------

Types defined externally in C can be prefixed by `_` to be used in Céu programs.

The syntax for types in Céu is as follows:

```
TODO
```

Example:

<pre><code><b>var</b> _rect r;    // "r" is of external native type "rect"
</code></pre>

TODO: type annotations

<!--
The size of an external type must be explicitly [[#sec.stmts.decls.types|declared]].

Example:

    native _char = 1;  // declares the external native type `_char` of 1 byte
-->

Type modifiers
--------------

Types can be suffixed with the following modifiers: `*`, `&`, `[]`, and `[N]`.

### Pointers

TODO

### References

TODO

### Buffer pointers

TODO

### Vectors

One-dimensional vectors are declared by suffixing the variable type (instead of 
its name) with the vector length surrounded by `[` and `]`.
The first index of a vector is zero.

*Note: currently, Céu has no syntax for initializing vectors.*

Example:

<pre><code><b>var int</b>[2] v;       // declares a vector "v" of 2 integers
</code></pre>

Statements
==========

Blocks
------

A block is a sequence of statements separated by semicolons (`;`):

```
Block ::= { Stmt `;´ }
```

*Note: statements terminated with the `end` keyword do not require a 
terminating semicolon.*

A block creates a new scope for [variables](#variables), which are only visible 
for statements inside the block.

Compound statements (e.g. [if-then-else](#if-then-else)) create new blocks and 
can be nested for an arbitrary level.

### do-end

A block can also be explicitly created with the `do-end` statement:

<pre><code>Do ::= <b>do</b> Block <b>end</b>
</code></pre>

<!--

TODO: FINALIZATION

The optional <tt>finally</tt> block is executed even if the whole <tt>do-finally-end</tt> block is killed by a trail in parallel.

*Note: the whole *<tt>do-end</tt>* defines a single block, i.e., variables defined in the *<tt>do</tt>* part are also visible to the *<tt>finally</tt>* part.*

Consider the example that follows:

<pre><code>par/or do
    do
        _FILE* f = _fopen("/tmp/test.txt");
        await A;
        // use f
    finally
        _fclose(f);
    end
with
    await B;
end
</code></pre>

Even if event <tt>B</tt> occurs before <tt>A</tt>, the opened file <tt>f</tt> is safely closed.

TODO: escape analysis / `:=` assignments

-->

Nothing
-------

`nothing` is a innocuous statement:

<pre><code>Nothing ::= <b>nothing</b>
</code></pre>

Declarations
------------

### Variables

The syntax for the definition of variables is as follows:

<pre><code>Dcl_var ::= <b>var</b> Type ID_var [`=´ SetExp] { `,´ ID_var [`=´ SetExp] }
</code></pre>

A variable must have an associated [type](#types) and can be optionally 
initialized (see [Assignments](#assignments)).

Variables are only visible inside the [block](#blocks) they are defined.

Examples:

<pre><code><b>var int</b> a=0, b=3;   // declares and initializes integer variables `a` and `b`
<b>var int</b>[2] v;       // declares a vector `v` of size 2
</code></pre>

### Events

See also [Event handling](#event-handling).

#### External events

External events are used as interfaces between programs and devices from the 
real world:

* *input* events represent input devices, such as sensors, switches, etc.
* *output* events represent output devices, such as LEDs, motors, etc.

Being reactive, programs in Céu have input events as their sole entry points 
through [await statements](#await).

An external event is either of type input or output, never being both at the 
same time.
For devices that perform input and output (e.g. radio transceivers), the 
underlying platform must provide different events for each functionality.

The declaration of input and output events is as follows:

<pre><code>Dcl_ext ::= <b>input</b> (Type|TypeList) ID_ext { `,´ ID_ext }
         |  <b>output</b> Type ID_ext { `,´ ID_ext }

TypeList ::= `(´ Type { `,´ Type } `)´
</code></pre>

Events communicate values between the environment and the application (and 
vice-versa).
The declaration includes the [type](#types) of the value, which can be also a 
list of types when the event communicates multiple values.

*Note: `void` is a valid type for signal-only events.*

The visibility of external events is always global, regardless of the block they are declared.

Examples:

<pre><code><b>input void</b> A,B;      // "A" and "B" are input events carrying no values
<b>output int</b> MY_EVT;   // "MY_EVT" is an output event carrying integer values
</code></pre>

The availability of external events depends on the platform in use.
Therefore, external declarations just make pre-existing events visible to a 
program.

Refer to [Environment](#environment) for information about interfacing with 
external events in the platform level.

##### Requests

TODO

#### Internal events

Internal events have the same purpose of external events, but for communication 
within trails in a program.

The declaration of internal events is as follows:

<pre><code>Dcl_int ::= <b>event</b> (Type|TypeList) ID_var { `,´ ID_var }
</code></pre>

In contrast with external events, an internal event is for input and output at 
the same time.

Internal events cannot be of a vector type.

*Note: <tt>void</tt> is a valid type for signal-only internal events.*

<span id="sec.stmts.decls.c"></span>

### Functions

#### Internal functions

TODO

<pre><code>Dcl_fun ::= <b>function</b> [<b>@rec</b>] ParList `=>´ Type ID_var
            [ <b>do</b> Block <b>end</b> ]

ParList     ::= `(´ ParListItem [ { `,´ ParListItem } ] `)´
ParListItem ::= [<b>@hold</b>] Type [ID_var]
</code></pre>

##### return

TODO

<pre><code>Return ::= <b>return</b> [Exp]
</code></pre>

#### External functions

TODO

#### Interrupt service routines

TODO

### Classes and Interfaces

<pre><code>Dcl_cls ::= <b>class</b> ID_cls <b>with</b>
                Dcls
            <b>do</b>
                Block
            <b>end</b>

Dcl_ifc ::= <b>interface</b> ID_cls <b>with</b>
                Dcls
            <b>end</b>

Dcls = { (Dcl_var | Dcl_int | Dcl_pool | Dcl_fun | Dcl_imp) `;´ }

Dcl_imp = <b>interface</b> ID_cls { `,´ ID_cls }
</code></pre>

TODO

### Pools

<pre><code>Dcl_pool = <b>pool</b> Type ID_var { `,´ ID_var }
</code></pre>

TODO

### Native symbols

Native declarations provide additional information about external C symbols.
A declaration is an annotation followed by a list of symbols:

<pre><code>Dcl_nat   ::= <b>native</b> [<b>@pure</b>|<b>@const</b>|<b>@nohold</b>|<b>@plain</b>] Nat_list
Nat_list  ::= (Nat_type|Nat_func|Nat_var) { `,` (Nat_type|Nat_func|Nat_var) }
Nat_type  ::= ID_nat `=´ NUM
Nat_func  ::= ID_nat `(´ `)´
Nat_var   ::= ID_nat
</code></pre>

A type declaration may define its size in bytes (TODO: why?).
A type of size `0` is an *opaque type* and cannot be instantiated as a variable 
that is not a pointer.

Functions and variables are distinguished by the `()` that follows function declarations.

Native symbols can have the following annotations:

**@plain** states that the type is not a pointer to another type.
**@const** states that the variable is actually a constants (e.g. a `#define`).
**@pure** states that the function has no side effects.
**@nohold** states that the function does not hold pointers passed as parameters.

TODO
<!--
By default, [concurrent](#concurrency) accesses to external symbols are 
considered [non-deterministic](#deterministic), because the Céu compiler has no 
information about them.
For the same reason, functions are considered to be impure (i.e. performing 
side-effects), and C variables to point to any memory location.

Annotations are discussed in more depth in sections [do-finally-end](#do) and 
TODO(determinism).
-->

Examples:

<pre><code><b>native</b> _char=1, _FILE=0;              // "char" is a 1-byte type, while `FILE` is "opaque"
<b>native @plain</b>  _rect;                  // "rect" is not a pointer type
<b>native @const</b>  _NULL;                  // "NULL" is a constant
<b>native @pure</b>   _abs(), _pow();         // "abs" and "pow" are pure functions
<b>native @nohold</b> _fprintf(), _sprintf(); // functions receive pointers but do not hold references to them
</code></pre>

<span id="sec.stmts.decls.det"></span>

### Safe annotations

A variable or function can be declared as `@safe` with a set of other functions 
or variables:

<pre><code>Dcl_det ::= <b>@safe</b> ID <b>with</b> ID { `,´ ID }
</code></pre>

Example:

<pre><code><b>native</b> _p, _f1(), _f2();
<b>@safe</b> _f1 <b>with</b> _f2;
<b>var int</b>* p;
<b>@safe</b> p <b>with</b> _p;
<b>par do</b>
    _f1(...);    // `f1` is safe with `f2`
    *p = 1;      // `p`  is safe with `_p`
    ...
<b>with</b>
    _f2(...);    // `f2` is safe with `f1`
    *_p = 2;     // `_p` is safe with `p`
    ...
<b>end</b>
</code></pre>

Safe annotations are discussed in more depth in section TODO(determinism).

Assignments
-----------

Céu supports many kinds of assignments:

<pre><code>Set ::= Exp `=´ SetExp
SetExp ::= Exp | &lt;do-end&gt; | &lt;if-then-else&gt; | &lt;loop&gt;
               | &lt;every&gt;  | &lt;par&gt; | &lt;await&gt; | &lt;emit (output)&gt;
               | &lt;thread&gt; | &lt;new&gt; | &lt;spawn&gt; )
</code></pre>

<!-- TODO: Lua -->

The expression on the left side must be [assignable](#assignable).

### Simple assignment

The simpler form of assignment uses [expressions](#expressions) as values.

Example:

<pre><code><b>var int</b> a,b;
a = b + 1;
</code></pre>

### Block assignment

A whole block can be used as an assignment value by escaping from it.
The following block statements can be used in assignments: [`do-end´](#do-end) 
[`if-then-else`](#if-then-else), [`loop`](#loop), [`every`](#every), and 
[`par`](#par).

#### escape

An `escape` statement escapes the deepest block being assigned to a variable.
The expression following it is then assigned to the respective variable:

<pre><code>Escape ::= <b>escape</b> Exp
</code></pre>

Every possible path inside the block must reach a `escape` statement whose 
expression becomes the final value of the assignment.
<!--[TODO: static analysis or halt]-->

Example:

<pre><code>a = <b>loop do</b>              // a=1, when "cond" is satisfied
        ...
        <b>if</b> cond <b>then</b>
            <b>escape</b> 1;    // "loop" is the deepest assignment block
        <b>end</b>
        ...
    <b>end</b>
</code></pre>

Every program in Céu contains an implicit `do-end` surrounding it, assigning to 
a special integer variable `$ret` holding the return value for the program 
execution.

Therefore, a program such as

<pre><code><b>escape</b> 1;
</code></pre>

should read as

<pre><code><b>var int</b> $ret =
    <b>do</b>
        <b>escape</b> 1;
    <b>end</b>;
</code></pre>

### Await assignment

See [Await statements](#await-statements).

### Emit assignment

See [Emit statements](#emit-statements).

### Thread assignment

See [Threads](#threads).

### New & Spawn assignment

See [Dynamic organisms](#dynamic-organisms).

Calls
-----

<pre><code>Call ::= [ <b>call</b>|<b>call/rec</b> ] Exp * `(´ [ExpList] `)´
ExpList = Exp { `,´ Exp }
</code></pre>

### Function calls

TODO

### External calls

TODO

### Native calls

Functions defined in C can be called from Céu:
Expressions that evaluate to C functions can also be called. 

Examples:

```
_printf("Hello World!\n");
ptr:f();
```

<!--[ TODO: unbounded execution ]-->

Event handling
--------------

Events are the most fundamental concept of Céu, accounting for its reactive 
nature.

Events are manipulated through the `await` and `emit` statements.

Waiting for an event halts the running trail until that event occurs.

The occurrence of an event is broadcast to all awaiting trails.

### Await statements

The `await` statement halts the running trail until the referred *wall-clock* 
time, [input event](#external), or [internal event](#internal) occurs.

<pre><code>Await ::= ( <b>await</b> ID_ext |
            <b>await</b> Exp    |
            <b>await</b> (WCLOCKK|WCLOCKE)
          ) [ <b>until</b> Exp ]
       | <b>await</b> <b>FOREVER</b>

VarList ::= `(´ ID_var  { `,´ ID_var } `)´

WCLOCKK ::= [NUM <b>h</b>] [NUM <b>min</b>] [NUM <b>s</b>] [NUM <b>ms</b>] [NUM <b>us</b>]
WCLOCKE ::= `(´ Exp `)´ (<b>h</b>|<b>min</b>|<b>s</b>|<b>ms</b>|<b>us</b>)
</code></pre>

Examples:

<pre><code><b>await</b> A;                  // awaits the input event `A`
<b>await</b> a;                  // awaits the internal event `a`

<b>await</b> 10min3s5ms100us;    // awaits the specified time
<b>await</b> (t)ms;              // awaits the current value of the variable `t` in milliseconds
    
<b>await FOREVER</b>;            // awaits forever
</code></pre>

An `await` may evaluate to zero or more values which can be captured with the 
optional assignment syntax.

The optional `until` clause tests an additional condition required to awake.
It can be understood as the following expansion:

<pre><code><b>loop do</b>
    <Await>
    <b>if</b> &lt;Exp&gt; <b>then</b>
        <b>break</b>;
    <b>end</b>
<b>end</b>
</code></pre>

#### Await event

For await statements with [internal](#internal) or [external](#external) 
events, the running trail awakes when the referred event is emitted.
The `await` evaluates to the type of the event.

<pre><code><b>input int</b> E;
<b>var int</b> v = <b>await</b> E;

<b>event</b> (<b>int</b>,<b>int</b>*) e;
<b>var int</b>  v;
<b>var int</b>* ptr;
(v,ptr) = <b>await</b> e;
</code></pre>

#### Await time

For await statements with *wall-clock* time (i.e., time measured in minutes, 
milliseconds, etc.), the running trail awakes when the referred time elapses.

A constant time is expressed with a sequence of value/unit-of-time pairs (see 
`WCLOCKK` above).
An expression time is specified with an expression in parenthesis followed by a 
single unit of time (see `WCLOCKE` above).

The `await` evaluates to the *residual delta time (dt)* (i.e.  elapsed time 
*minus* requested time), measured in microseconds:

<pre><code><b>var int</b> dt = <b>await</b> 30ms;    // if 31ms elapses, then dt=1000
</code></pre>

*Note: `dt` is always greater than or equal to 0.*

<!--
Refer to [[#Environment]] for information about storage types for *wall-clock* 
time.
-->

<span id="sec.stmts.events.await.forever"></span>

#### Await FOREVER

The `await FOREVER` halts the running trail forever.
It cannot be used in assignments, because it never evaluates to anything.

### Emit statements

The `emit` statement triggers the referred *wall-clock* time, [input 
event](#external), or [internal event](#internal), awaking all trails waiting 
for it.

<pre><code>Emit ::= <b>emit</b> Exp    [ `=>´ (Exp | `(´ ExpList `)´)
      |  <b>emit</b> ID_ext [ `=>´ (Exp | `(´ ExpList `)´)
      |  <b>emit</b> (WCLOCKK|WCLOCKE)
</code></pre>

#### Emit event

Emit statements with [internal](#internal) or [external](#external) events 
expect parameters that match the event type (unless the event is of type 
`void`).

Examples:

<pre><code><b>output int</b> E;
<b>emit</b> E => 1;

<b>event</b> (<b>int</b>,<b>int</b>) e;
<b>emit</b> e => (1,2);
</code></pre>

External input events can only be emitted inside [asynchronous 
blocks](#asynchronous-blocks).

TODO: EmitExt evaluates to "int"
<!--
: An emit on an output event returns immediately a status code of the action 
that runs asynchronously with the program.
: Both the status code and that asynchronous actions are platform dependent. The status code is always of type <tt>int</tt>.
:
: Example:

<pre><code><b>output int</b> SEND;
<b>if not emit</b> SEND=>1 then
   <b>return</b> 0;
<b>end</b>
</code></pre>
:
-->

TODO: stack/queue

#### Emit time

Emit statements with *wall-clock* time expect expressions with units of time, 
as described in [Await time](#await-time).

Like input events, time can only be emitted inside [asynchronous 
blocks](#asynchronous-blocks).

Flow control
------------

### if-then-else

Conditional flow uses the `if-then-else` statement:

<pre><code>If ::= <b>if</b> Exp <b>then</b>
           Block
       { <b>else/if</b> Exp <b>then</b>
           Block }
       [ <b>else</b>
           Block ]
       <b>end</b>
</code></pre>

The block following `then` executes if the condition expression after the `if` 
evaluates to a non-zero value.
Otherwise, the same process holds each `else/if` alternative.
Finally, it they all fail, the block following the `else` executes.

### loop

A `loop` continuously executes its body block:

<pre><code>Loop ::= <b>loop</b> [ ID_var [<b>in</b> Exp] ] <b>do</b>
             Block
         <b>end</b>
</code></pre>

A `loop` terminates when reaches a `break` in its body or when the specified 
iterator terminates.

#### break

A `break` escapes the innermost enclosing loop.

Example:

<pre><code><b>loop do</b>                   // loop 1
    ...
    <b>loop do</b>               // loop 2
        <b>if</b> &lt;cond-1&gt; <b>then</b>
            <b>break</b>;        // escapes loop 2
        <b>end</b>
    <b>end</b>
    ...
    <b>if</b> &lt;cond-2&gt; <b>then</b>
        <b>break</b>;            // escapes loop 1
    <b>end</b>
    ...
<b>end</b>
</code></pre>

#### Iterators

##### Incremental index

For iterators with `Exp` empty or of type `int`, the `ID_var` is incremented 
after each loop iteration.
`ID_var` is automatically declared read-only, with visibility restricted to the 
loop body, and is initialized to zero.
The optional `Exp`, which is evaluated once before the loop starts, limits the 
number of iterations.

##### Pool instances

TODO

#### every

TODO

<pre><code>Every ::= <b>every</b> (Exp|VarList) <b>in</b> (WCLOCKK|WCLOCKE|ID_ext|Exp) <b>do</b>
              Block
          <b>end</b>
</code></pre>

Finalization
------------

TODO

<pre><code>Finalize ::= <b>finalize</b> [Exp `=´ SetExp] <b>with</b>
                 Block
             <b>end</b>
</code></pre>

Parallel compositions
---------------------

The parallel statements `par/and`, `par/or`, and `par` split the running trail 
in multiple others:

<pre><code>Pars ::= (<b>par/and</b>|<b>par/or</b>|<b>par</b>) <b>do</b>
               Block
          <b>with</b>
               Block
          { <b>with</b>
               Block }
           <b>end</b>
</code></pre>

They differ only on how trails terminate (rejoin).

See [Execution model](#execution-model) for a detailed description of parallel 
execution.

### par/and

The `par/and` statement stands for *parallel-and* and rejoins when all trails 
terminate:

### par/or

The `par/or` statement stands for *parallel-or* and rejoins when any of the 
trails terminate:

### par

The `par` statement never rejoins and should be used when the trails in 
parallel are supposed to run forever:

<!--[TODO: static analysis or halt]-->

### watching

TODO: translates to `par/or`

<pre><code>Watching ::= <b>watching</b> (WCLOCKK|WCLOCKE|ID_ext|Exp) <b>do</b>
                 Block
             <b>end</b>
</code></pre>

pause/if
--------

TODO

<pre><code>Pause ::= <b>pause/if</b> Exp <b>do</b>
              Block
          <b>end</b>
</code></pre>

Dynamic organisms
-----------------

TODO
<!-- TODO [free] -->

<pre><code>
Dyn ::= (<b>new</b>|<b>spawn</b>) ID_cls [<b>in</b> Exp]
            [ <b>with</b> Constructor <b>end</b> ]
</code></pre>

TODO: Constructor

Asynchronous execution
----------------------

Asynchronous execution permit that programs execute time consuming computations 
without interfering with the *synchronous side* of applications (i.e., 
everything, except asynchronous statements).

<pre><code>Async ::= <b>async</b> [<b>thread</b>] [RefVarList] <b>do</b>
              Block
          <b>end</b>

RefVarList ::= `(´ [`&´] ID_var { `,´ [`&´] ID_var } `)´
</code></pre>

### Asynchronous blocks

Asynchronous blocks (`async`) are the simplest alternative for asynchronous 
execution.

An `async` body can contain non-awaiting loops (*tight loops*), which are 
[disallowed](#bounded) on the synchronous side to ensure that programs remain 
reactive.

The optional list of variables copies values between the synchronous and 
asynchronous scopes.
With the prefix `&`, the variable is passed by reference and can be altered 
from inside the `async`.

The next example uses an `async` to execute a time-consuming computation, 
keeping the synchronous side reactive.
In a parallel trail, the program awaits one second to kill the computation if it takes too long:

<pre><code><b>var int</b> fat;
<b>par/or do</b>
    <b>var int</b> v = ...

    // calculates the factorial of v
    fat = <b>async</b> (v) <b>do</b>
        <b>var int</b> fat = 1;
        <b>loop</b> i <b>in</b> v <b>do</b>   // a tight loop
            // v varies from 0 to (v-1)
            fat = fat * (i+1);
        <b>end</b>
        <b>return</b> fat;
    <b>end</b>;
<b>with</b>
    <b>await</b> 1s;          // watchdog to kill the async if it takes too long
    fat = 0;
<b>end</b>
<b>return</b> fat;
</code></pre>

An `async` has the following restrictions:

1. Only executes if there are no pending input events.
2. Yields control on every `loop` iteration on its body.
3. Cannot use parallel compositions.
4. Cannot nest other asyncs.
5. Cannot `await` events.
6. Cannot `emit` internal events.

<!--
A lower priority for `async` is fundamental to ensure that input events are 
handled as fast as possible.
-->

#### Simulation

An `async` is allowed to trigger [input events](#emit-event) and the [passage 
of time](#emit-time), providing a way to test programs in the language itself:

<pre><code><b>input int</b> A;

// tests a program with a simulation in parallel
<b>par do</b>

    // original program
    <b>var int</b> v = <b>await</b> A;
    <b>loop</b> i <b>do</b>
        <b>await</b> 10ms;
        _printf("v = %d\n", v+i);
    <b>end</b>

<b>with</b>

    // input simulation
    <b>async do</b>
        <b>emit</b> A=>0;      // initial value for "v"
        <b>emit</b> 1s35ms;    // the loop executes 103 times
    <b>end</b>
    <b>return</b> 0;
<b>end</b>
</code></pre>

Every time the `async` emits an event, it suspends (due to rule `1` of previous 
section).
The example prints the `v = <v+i>` message exactly 103 times.

### Threads

TODO

#### Synchronous blocks

TODO

<pre><code>Sync ::= <b>sync do</b>
             Block
         <b>end</b>
</code></pre>

Native blocks
-------------

Native blocks define new types, variables, and functions in C:

<pre><code>Native ::= <b>native</b> <b>do</b>
               &lt;code_in_C&gt;
           <b>end</b>
</code></pre>

<!--
Whatever is written inside a C block is placed on the top of the final output of the Céu parser (which is a C file).
-->

Example:

<pre><code><b>native do</b>
    #include <assert.h>
    int inc (int i) {
        return i+1;
    }
<b>end</b>
_assert(_inc(0) == 1);
</code></pre>

If the code in C contains the terminating `end` keyword of Céu, the `native`
block should be delimited with any matching comments to avoid confusing the 
parser:

<pre><code><b>native do</b>
    /*** c code ***/
    char str = "This `end` confuses the parser";
    /*** c code ***/
<b>end</b>
</code></pre>

Expressions
===========

The syntax for expressions in Céu is as follows:

<pre><code>Exp ::= Prim
     |  Exp (<b>or</b>|<b>and</b>) Exp
     |  Exp (`|´|`^´|`&´) Exp
     |  Exp (`!=´|`==´) Exp
     |  Exp (`&lt;=´|`&lt;´|`&gt;´|`&gt;=´) Exp
     |  Exp (`&lt;&lt;´|`&gt;&gt;´) Exp
     |  Exp (`+´|`-´) Exp
     |  Exp (`*´|`/´|`%´) Exp
     |  <b>not</b> Exp
     |  `&´ Exp
     |  (`-´|`+´) Exp
     |  `~´ Exp
     |  `*´ Exp
     |  `(´ Type `)´ Exp
     |  Exp `(´ [ExpList] `)´ [<b>finalize with</b> Block <b>end</b>]
     |  Exp `[´ Exp `]´
     |  Exp (`.´|`:´) ID

Prim ::= `(´ Exp `)´
      |  <b>sizeof</b> `(´ (Type|Exp) `)´
      |  ID_var | ID_nat
      |  <b>null</b> | NUM | String
      |  <b>global</b> | <b>this</b> | <b>outer</b>
      |  (<b>call</b> | <b>call/rec</b>) Exp
</code></pre>

TODO: RawExp

Most operators follow the same semantics of C.

*Note: assignments are not expressions in Céu.*

Primary
-------

TODO: global, this, outer,

Arithmetic
----------

The arithmetic operators of Céu are

```
    +      -      %      *      /      +      -
```

which correspond to *addition*, *subtraction*, *modulo (remainder)*, *multiplication*, *division*, *unary-plus*, and *unary-minus*.
<!-- *Note: Céu has no support for pointer arithmetic.* -->

Relational
----------

The relational operators of Céu are

```
    ==      !=      >      <      >=      <=
```

which correspond to *equal-to*, *not-equal-to*, *greater-than*, *less-than*, *greater-than-or-equal-to*, and *less-than-or-equal-to*.

Relational expressions evaluate to 1 (*true*) or 0 (*false*).

Logical
-------

The logical operators of Céu are

<pre><code>    <b>not      and      or</b>
</code></pre>

<!--
which correspond to *not*, *and*, *or*.
-->

Bitwise
-------

The bitwise operators of Céu are

```
    ~      &      |      ^      <<      >>
```

which correspond to *not*, *and*, *or*, *xor*, *left-shift*, and *right-shift*.

Vector indexing
---------------

Céu uses square brackets to index [vectors](#Vectors):

```
Index ::= Exp `[´ Exp `]´
```

The expression on the left side is expected to evaluate to a vector.

Vector indexes start at zero.
<!-- TODO: limites e recolocar "pointer arith" -->

Pointers
--------

The operator `*` dereferences its pointer operand, while the operator `&amp;` returns a pointer to its operand:

```
Deref ::= `*´ Exp
Ref   ::= `&´ Exp
```

The operand to `&amp;` must be an [[#sec.exps.assignable|assignable expression]].

Fields
------

### Structs

The operators `.´ and `:´ access the fields of structs.

```
Dot   ::= Exp `.´ Exp
Colon ::= Exp `:´ Exp
```

The operator `.` expects a `struct` as its left operand, while the operator `:` 
expects a reference to a `struct`.

Example:

<pre><code><b>native do</b>
    typedef struct {
        int v;
    } mystruct;
end
<b>var</b> _mystruct s;
<b>var</b> _mystruct* p = &s;
s.v = 1;
p:v = 0;
</code></pre>

*Note: `struct` must be declared in C, as Céu currently has no support for it.*

### Organisms

TODO

Type casting
------------

Céu uses parenthesis for type casting:

<pre><code>Cast ::= `(´ ID_type `)´
</code></pre>

Sizeof
------

A `sizeof` expression returns the size of a type or expression, in bytes:

<pre><code>Sizeof ::= <b>sizeof</b> `(´ (Type|Exp) `)´
</code></pre>

<!--
The expression is evaluated at compile time.
-->

Precedence
----------

Céu follows the same precedence of C operators:

<pre><code>    /* lower to higer precedence */
    
    <b>or</b>
        
    <b>and</b>
        
    |
    
    ^
    
    &
    
    !=    ==
    
    &lt;=    &gt;=    &lt;     &gt;
    
    &gt;&gt;    &lt;&lt;
    
    +     -                // binary
    
    *     /     %
    
    <b>not</b>     &
    
    +     -                // unary
    
    &lt;&gt;                     // typecast
    
    ()    []    :    .     // call, index
</code></pre>

Assignable expressions
----------------------

An assignable expression (also known as an *l-value*) can be a variable, vector index, pointer dereference, or struct access.
L-values are required in [[#sec.stmts.assignments|assignments]] and [[#sec.exps.pointers|references]].

Examples:

<pre><code><b>var int</b> a;
a = 1;

<b>var int</b>[2] v;
v[0] = 1;

<b>var int</b>* p;
*p = 1;

<b>var</b> _mystruct s;
s.v = 1;

<b>var</b> _mystruct* ps;
ps:v = 1;
</code></pre>


Execution model
===============

TODO

<!--

In Céu, trails execute synchronized in reaction to a single input event at a 
time, being impossible to have trails reacting to different events.
The disciplined step-by-step execution in Céu enables a rigorous analysis that 
guarantees at compile time that programs are completely race free.

=== Rejoining of trails ===

A [[#sec.stmts.parallel.par/or|par/or]], [[#sec.stmts.loop|loop]], or [[#sec.stmts.assignments.block|block assignment]] may terminate (rejoin) concurrently from different trails in parallel.
In this case, Céu ensures that all trails execute before rejoining the composition.

In the following example, both trails terminate the <tt>par/or</tt> concurrently:

<pre><code>int v1 = 0;
int v2 = 0;
par/or do
    v1 = 1;
with
    v2 = 2;
end
return v1 + v2;
</code></pre>

Céu ensures that both assignments in parallel execute before the <tt>par/or</tt> terminates.
The program always returns `3`.

However, it is also possible that trails in parallel rejoin a composition independently, when other trails are waiting for different events.
In this case, all awaiting trails nested within the composition are *killed*, i.e., they will never resume again.

The following example illustrates this behavior:

<pre><code>input void A, B;
int v =
    par do
        await A;
        return 1;
    with
        await B;
        return 2;
    end
end
return v;
</code></pre>

Initially, the trails in parallel are awaiting `A` and `B` to return different values.
If the event `A` occurs, the composition yields `1`, killing the trail awaiting `B`.

See [[#Rejoining of tracks]] for the detailed semantics of rejoins.

See [[#Deterministic execution]] for information on how Céu avoids 
non-determinism in parallel compositions.
-->

<!------------------------------------------------------------>
<!------------------------------------------------------------>


Environment
===========

As a reactive language, Céu depends on an external environment (platform) to provide input and output events to programs.
The environment is responsible for sensing the world and notifying Céu about changes.

The actual events vary from environment to environment, and an implementation may use a polling or interrupt-driven notification mechanism.

The Céu compiler generates a C output with hooks following a standard interface that the target platform should comply.

C API
-----

The following sections specify the available mechanisms of interaction between the environment and the Céu runtime.

### Functions

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

### Macros

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

### Constants & Defines

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

### Types

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

Syntax
======

<pre><code>
Block ::= { Stmt `;´ }

Stmt ::= &lt;empty-string&gt;
        |  <b>nothing</b>
        |  <b>escape</b> Exp
        |  <b>return</b> [Exp]
        |  <b>break</b>
        |  <b>continue</b>

    /* Declarations */

        /* variable, events, and pools */
        | <b>var</b> Type ID_var [`=´ SetExp] { `,´ ID_var [`=´ SetExp] }
        | <b>input</b> (Type|TypeList) ID_ext { `,´ ID_ext }
        | <b>output</b> Type ID_ext { `,´ ID_ext }
        | <b>event</b> (Type|TypeList) ID_var { `,´ ID_var }
        | <b>pool</b> Type ID_var { `,´ ID_var }

        /* functions */
        | <b>function</b> [<b>@rec</b>] ParList `=>´ Type ID_var
              [ `do´ Block `end´ ]
            <i>where</i>
                ParList     ::= `(´ ParListItem [ { `,´ ParListItem } ] `)´
                ParListItem ::= [<b>@hold</b>] Type [ID_var]

        /* classes & interfaces */
        | <b>class</b> ID_cls <b>with</b>
              Dcls
          <b>do</b>
              Block
          <b>end</b>
        | <b>interface</b> ID_cls <b>with</b>
              Dcls
          <b>end</b>
            <i>where</i>
                Dcls    ::= { (Dcl_var | Dcl_int | Dcl_pool | Dcl_fun | Dcl_imp) `;´ }
                Dcl_imp ::= <b>interface</b> ID_cls { `,´ ID_cls }

        /* native symbols */
        | <b>native</b> [<b>@pure</b>|<b>@const</b>|<b>@nohold</b>|<b>@plain</b>] Nat_list
            <i>where</i>
                Nat_list  ::= (Nat_type|Nat_func|Nat_var) { `,` (Nat_type|Nat_func|Nat_var) }
                Nat_type  ::= ID_nat `=´ NUM
                Nat_func  ::= ID_nat `(´ `)´
                Nat_var   ::= ID_nat

        /* deterministic annotations */
        | <b>@safe</b> ID <b>with</b> ID { `,´ ID }

    /* Assignments */

        | (Exp|VarList) `=´ SetExp

    /* Function calls */

        | [<b>call</b>|<b>call/rec</b>] Exp * `(´ [ExpList] `)´ ExpList = Exp { `,´ Exp }

    /* Event handling */

        /* await */
        | (
            <b>await</b> ID_ext |
            <b>await</b> Exp    |
            <b>await</b> (WCLOCKK|WCLOCKE)
          ) [ <b>until</b> Exp ]
        | <b>await</b> <b>FOREVER</b>

        /* emit */
        | <b>emit</b> Exp    [ `=>´ (Exp | `(´ ExpList `)´)
        | <b>emit</b> (WCLOCKK|WCLOCKE)
        | <b>emit</b> ID_ext [ `=>´ (Exp | `(´ ExpList `)´)

    /* Dynamic organisms */
        | (<b>new</b>|<b>spawn</b>) * ID_cls * [<b>in</b> Exp]
              [ <b>with</b> Constructor <b>end</b> ]

    /* Flow control */

        /* explicit block */
        |  <b>do</b> Block <b>end</b>

        /* conditional */
        | <b>if</b> Exp <b>then</b>
              Block
          { <b>else/if</b> Exp <b>then</b>
              Block }
          [ <b>else</b>
              Block ]
          <b>end</b>

        /* loops */
        | <b>loop</b> [ ID_var [<b>in</b> Exp] ] <b>do</b>
              Block
          <b>end</b>
        | <b>every</b> (Exp|VarList) <b>in</b> (WCLOCKK|WCLOCKE|ID_ext|Exp) <b>do</b>
              Block
          <b>end</b>

        /* finalization */
        | <b>finalize</b> [Exp `=´ SetExp] <b>with</b>
              Block
          <b>end</b>

        /* parallel compositions */
        | (<b>par/and</b>|<b>par/or</b>|<b>par</b>) <b>do</b>
              Block
          <b>with</b>
              Block
          { <b>with</b>
              Block }
           <b>end</b>
        | <b>watching</b> (WCLOCKK|WCLOCKE|ID_ext|Exp) <b>do</b>
              Block
          <b>end</b>

        /* pause */
        | <b>pause/if</b> Exp <b>do</b>
              Block
          <b>end</b>

        /* asynchronous execution */
        | <b>async</b> [<b>thread</b>] [RefVarList] <b>do</b>
              Block
          <b>end</b>
        | <b>sync do</b>
              Block
          <b>end</b>
            <i>where</i>
                RefVarList ::= `(´ [`&´] ID_var { `,´ [`&´] ID_var } `)´

VarList ::= `(´ ID_var  { `,´ ID_var } `)´
SetExp  ::= Exp | &lt;do-end&gt; | &lt;if-then-else&gt; | &lt;loop&gt;
                | &lt;every&gt;  | &lt;par&gt; | &lt;await&gt; | &lt;emit (output)&gt;
                | &lt;thread&gt; | &lt;new&gt; | &lt;spawn&gt; )

WCLOCKK ::= [NUM <b>h</b>] [NUM <b>min</b>] [NUM <b>s</b>] [NUM <b>ms</b>] [NUM <b>us</b>]
WCLOCKE ::= `(´ Exp `)´ (<b>h</b>|<b>min</b>|<b>s</b>|<b>ms</b>|<b>us</b>)

ID      ::= &lt;a-z, A-Z, 0-9, _&gt; +
ID_var  ::= ID    // beginning with a lowercase letter
ID_ext  ::= ID    // all in uppercase, not beginning with a digit
ID_cls  ::= ID    // beginning with an uppercase letter
ID_nat  ::= ID    // beginning with an underscore

Type    ::= ID_type ( {`*´} | `&´ | `[´ `]´ | `[´ NUM `]´ )
ID_type ::= ( ID_nat | ID_cls |
            | <b>bool</b>  | <b>byte</b>  | <b>char</b>  | <b>f32</b>   | <b>f64</b>   |
            | <b>float</b> | <b>int</b>   | <b>s16</b>   | <b>s32</b>   | <b>s64</b>   |
            | <b>s8</b>    | <b>u16</b>   | <b>u32</b>   | <b>u64</b>   | <b>u8</b>    |
            | <b>uint</b>  | <b>void</b>  | <b>word</b> )

Exp ::= Prim
        |  Exp (<b>or</b>|<b>and</b>) Exp
        |  Exp (`|´|`^´|`&´) Exp
        |  Exp (`!=´|`==´) Exp
        |  Exp (`&lt;=´|`&lt;´|`&gt;´|`&gt;=´) Exp
        |  Exp (`&lt;&lt;´|`&gt;&gt;´) Exp
        |  Exp (`+´|`-´) Exp
        |  Exp (`*´|`/´|`%´) Exp
        |  <b>not</b> Exp
        |  `&´ Exp
        |  (`-´|`+´) Exp
        |  `~´ Exp
        |  `*´ Exp
        |  `(´ Type `)´ Exp
        |  Exp `(´ [ExpList] `)´ [<b>finalize with</b> Block <b>end</b>]
        |  Exp `[´ Exp `]´
        |  Exp (`.´|`:´) ID

Prim ::= `(´ Exp `)´
        |  <b>sizeof</b> `(´ (Type|Exp) `)´
        |  ID_var | ID_nat
        |  <b>null</b> | NUM | String
        |  <b>global</b> | <b>this</b> | <b>outer</b>
        |  (<b>call</b> | <b>call/rec</b>) Exp

/* The operators follow the same precedence of C. */

    <b>or</b>              /* lowest priority */
    <b>and</b>
    |
    ^
    &
    !=    ==
    &lt;=    &gt;=    &lt;     &gt;
    &gt;&gt;    &lt;&lt;
    +     -                // binary
    *     /     %
    <b>not</b>     &
    +     -                // unary
    &lt;&gt;                     // typecast
    ()    []    :    .     // call, index

</code></pre>

License
=======

Céu is distributed under the MIT license reproduced below:

```
 Copyright (C) 2012 Francisco Sant'Anna
 
 Permission is hereby granted, free of charge, to any person obtaining a copy of
 this software and associated documentation files (the "Software"), to deal in
 the Software without restriction, including without limitation the rights to
 use, copy, modify, merge, publish, distribute, sublicense, and/or sell copies
 of the Software, and to permit persons to whom the Software is furnished to do
 so, subject to the following conditions:
 
 The above copyright notice and this permission notice shall be included in all
 copies or substantial portions of the Software.
 
 THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
 IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
 FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
 AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
 LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
 OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
 SOFTWARE.
```
