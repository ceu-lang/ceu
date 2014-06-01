<title>Céu 0.7 Reference Manual</title>
<meta http-equiv="Content-Type" content="text/html; charset=UTF-8"/></p>

Introduction
============

Céu is a reactive language targeted at embedded systems and intended to offer a 
higher-level and safer alternative to C.
Reactive applications interact continuously with the environment and are mostly 
guided through input events from it.

Céu supports multiple lines of execution, known as *trails*, which are allowed 
to share variables in a safe and seamless way (e.g. no need for locks or 
semaphores).
The synchronous concurrency model of Céu greatly diverges from conventional 
multithreading (e.g. *pthreads*) and the actor model (e.g. *erlang*):

In Céu, trails execute synchronized in reaction to a single input event at a 
time, being impossible to have trails reacting to different events.
The disciplined step-by-step execution in Céu enables a rigorous analysis that 
guarantees at compile time that programs are completely race free.

Céu integrates well with C, being possible to define and call C functions from 
within Céu programs.

<!--
Céu has a memory footprint of around 2Kb of ROM and 50b of RAM (on embedded 
platform such as Arduino).
-->

Céu is [free software](#license).

For a gentle introduction about Céu, see the [interactive 
tutorial](http://www.ceu-lang.org/try.php).

See also the complete [Syntax](#syntax) of Céu for further reference.

Lexical Rules
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

Declarations
------------

### Variables

The syntax for the definition of variables is as follows:

<pre><code>Dcl_var ::= <b>var</b> Type ID_var [`=´ SetExp] { `,´ ID_var [`=´ SetExp] }
</code></pre>

A variable must have an associated [type](#types) and can be optionally 
initialized.

Variables are only visible inside the [block](#blocks) they are defined.

Examples:

<pre><code><b>var int</b> a=0, b=3;   // declares and initializes integer variables `a` and `b`
<b>var int</b>[2] v;       // declares a vector `v` of size 2
</code></pre>

### Events

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

Refer to the Section [Environment](#environment) for information about 
interfacing with external events in the platform level.

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
            [ `do´ Block `end´ ]

ParListItem ::= [<b>@hold</b>] Type [ID_var]
ParList     ::= `(´ ParListItem [ { `,´ ParListItem } ] `)´
</code></pre>

#### External functions

TODO

#### Interrupt Service Routines

TODO

### Classes and Interfaces

<pre><code>Dcl_cls = <b>class</b> ID_cls <b>with</b>
              Dcls
          <b>do</b>
              Block
          <b>end</b>

Dcl_ifc = <b>interface</b> ID_cls <b>with</b>
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

<pre><code>Set ::= Exp `=´ ( Exp | &lt;block&gt; | &lt;await&gt; | &lt;emit&gt; | &lt;thread&gt; | &lt;new&gt; | &lt;spawn&gt; )
</code></pre>

The expression on the left side must be [assignable](#assignable).

### Simple assignment

The simpler form of assignment uses [expressions](#expressions) as values.

Example:

<pre><code><b>var int</b> a,b;
a = b + 1;
</code></pre>

### Block assignment

A whole block can be used as an assignment value by escaping from it.

Example:

<pre><code>// assigns 1 to the variable "a"
<b>var int</b> a =
    <b>do</b>
        <b>escape</b> 1;
    <b>end</b>
</code></pre>

Every possible path inside the block must reach a `escape` statement whose 
expression becomes the final value of the assignment.
<!--[TODO: static analysis or halt]-->

The following statements can be used in block assignments: [if-then-else](#if), 
[loop](#loop), [par](#parallel-par), and [do-finally-end](#do).

#### escape

An `escape` statement escapes the deepest block being assigned to a variable.
The expression following it is then assigned to the respective variable.

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

See section [Await statements](#await-statements).

### Emit assignment

See Section [Emit statements](#emit-statements).

### Thread assignment

See Section [Threads](#threads).

### New & Spawn assignment

See Section [Dynamic organisms](#dynamic-organisms).

Calls
-----

### Function calls

### Native calls

Functions defined in C can be called from Céu:

```
Call ::=  Exp `(` ExpList `)`
```

Expressions that evaluate to C functions can also be called. 

Examples:

```
_printf("Hello World!\n");
ptr:f();
```

<!--[ TODO: unbounded execution ]-->

Event manipulation
------------------

The fundamental concept in Céu, accounting for its reactive nature, is that of events.

Events are manipulated through the <tt>await</tt> and <tt>emit</tt> statements.

Waiting for an event halts the running trail until that event occurs.

The occurrence of an event is broadcast to all awaiting trails at the same time.

### Await statements

The <tt>await</tt> statement halts the running trail forever or until the referred *wall-clock* time, [[#sec.stmts.decls.external|input event]], or [[#sec.stmts.decls.internal|internal event]] occurs.

<pre><code>Await ::= (Exp `=`)? ( <b>await</b> (ID_ext|ID_var)
                     | <b>await</b> (WCLOCKK|WCLOCKE)
                     )
       |  <b>await</b> <b>FOREVER</b>
</code></pre>

Examples:

<pre><code>await A;                  // awaits the input event `A`
await a;                  // awaits the internal event `a`

await 10min3s5ms100us;    // awaits the specified time
await (t)ms;              // awaits the current value of the variable `t` in milliseconds
    
await FOREVER;            // awaits forever
</code></pre>

An optional assignment captures the value the <tt>await</tt> evaluates to.

#### Await event

For await statements referring to an event identifier, the running trail halts until that event occurs.
When the event occurs, the statement resumes and evaluates to the triggered value.

<pre><code>input int A;
var int v = await A;       // `v` is assigned the value of next occurrence of `A`
</code></pre>

#### Await *wall-clock*

For await statements referring to *wall-clock* time (i.e., time measured in minutes, milliseconds, etc.), the running trail halts until the referred time elapses.

<tt>WCLOCKK</tt> and <tt>WCLOCKE</tt> are described as follows:

<pre><code>WCLOCKK ::= (NUM <b>h</b>)? (NUM <b>min</b>)? (NUM <b>s</b>)? (NUM 
<b>ms</b>)?  (NUM <b>us</b>)?
WCLOCKE ::= `(` Exp `)` (<b>h</b>|<b>min</b>|<b>s</b>|<b>ms</b>|<b>us</b>)
</code></pre>

A constant time (<tt>WCLOCKK</tt>) is expressed with a sequence of value/unit-of-time pairs.
An expression time (<tt>WCLOCKE</tt>) is specified with an expression in parenthesis followed by a single unit of time.

After the referred time elapses, the <tt>await</tt> statement evaluates to the *residual delta time (dt)* (i.e. elapsed time *minus* requested time), measured in microseconds:

<pre><code>var int dt = await 30ms;    // if 31ms elapses, then dt=1000
</code></pre>

*Note: <tt>dt</tt> is always greater than or equal to 0.*

Refer to the Section [[#Environment]] for information about storage types for *wall-clock* time.

<span id="sec.stmts.events.await.forever"></span>

#### Await FOREVER

The <tt>await FOREVER</tt> statement halts the running trail forever.
It never evaluates to anything, and cannot be used in assignments.

<span id="sec.stmts.events.emit"></span>

### Emit statements

The <tt>emit</tt> statement triggers the referred *wall-clock* time, [[#sec.stmts.decls.external|external event]], or [[#sec.stmts.decls.internal|internal event]], awaking all trails waiting for that event (time).

<pre><code>Emit ::= <b>emit</b> (ID_ext|ID_var) (`(` Exp `)`)?
      |  <b>emit</b> (WCLOCKK|WCLOCKE)
</code></pre>

#### Emit event

* External events:
:
: For [[#sec.stmts.decls.external|external events]], the assignment expression is obligatory and represents the trigger value of the event (unless the event is of type <tt>void</tt>).
:
: An emit on an output event returns immediately a status code of the action that runs asynchronously with the program.
: Both the status code and that asynchronous actions are platform dependent. The status code is always of type <tt>int</tt>.
:
: Example:

<pre><code>output int Send;
if not emit Send(1) then
   return 0;
end
</code></pre>
:
: Input events can only be emitted inside [[#sec.stmts.asyncs|asyncs]] for the [[#sec.stmts.asyncs.simulation|simulation]] of programs.

* Internal events:
:
: For [[#sec.stmts.decls.internal|internal events]], the assignment expression is optional, and evaluates *before* the <tt>emit</tt>.
: The two following are equivalent:
:
    emit a(4);
and
    a = 4;
    emit a();
:
: The emit on an internal event suspends and resumes only after all the corresponding awaiting statements react to it. See also Section [[#Execution model]] for a precise description.
:
: Internal emits have no return status and cannot be used as expressions.

<span id="sec.stmts.events.emit.wclock"></span>

#### Emit time

The <tt>WCLOCKK</tt> and <tt>WCLOCKE</tt> parameters refer to *wall-clock* time, as described in Section [[#Await statements]].

Just like for [[#sec.stmts.decls.external|input events]], wall-clock time can only be emitted inside [[#sec.stmts.asyncs|asyncs]].

<!------------------------------------------------------------>

<span id="sec.stmts.flow"></span>

Flow control
------------

### if-then-else

Céu provides an <tt>if–then–else</tt> statement as follows:

<pre><code>If ::= <b>if</b> Exp <b>then</b>
           Block
       (<b>else/if</b> Exp <b>then</b>
           Block)*
       (<b>else</b>
           Block)?
       <b>end</b>
</code></pre>

The if–then–else statement executes the block following <tt>then</tt> if the condition expression evaluates to a non-zero value.
Otherwise, it retries the process with the (optional) <tt>else/if</tt> alternatives.
Finally, it they all fail, the block following the (optional) <tt>else</tt> is executed.

*Note: the condition is not required to be surrounded by parenthesis.*

<span id="sec.stmts.loop"></span>

### loop

The <tt>loop</tt> statement continuously executes the block on its body until it reaches its specified limit or a <tt>break</tt> statement.

<pre><code>Loop ::= <b>loop</b> (ID_var (`,` Exp)?)? <b>do</b> Block <b>end</b>
</code></pre>

The optional variable is automatically declared and initialized with zero.
Its visibility is restricted to the loop body.
The variable is read-only, but is automatically incremented after each iteration of the loop.

The optional limiting expression is evaluated once, before the loop starts.
If no limiting expression is specified, the loop runs forever.

#### break

The <tt>break</tt> statement escapes the innermost enclosing loop.

Example:
<pre><code>loop do                   // loop 1
    ...
    loop do               // loop 2
        if cond then
            break;        // escapes loop 2
        end
    end
    ...
    if cond 2 then
        break;            // escapes loop 1
    end
    ...
end
</code></pre>

<!------------------------------------------------------------>

Parallel compositions
---------------------

The parallel statements <tt>par/and</tt>, <tt>par/or</tt>, and <tt>par</tt> split the running trail in multiple others.
They differ only on how trails rejoin in the future.

See also Section [[#Execution model]] for a detailed description of parallel execution.

### par/and

The <tt>par/and</tt> statement stands for *parallel-and*, meaning that the trails in parallel rejoin only after *all of them terminate*.

<pre><code>ParAnd ::= <b>par/and</b> <b>do</b>
               Block
          (<b>with</b>
               Block)+
           <b>end</b>
</code></pre>

### par/or

The <tt>par/or</tt> statement stands for *parallel-or*, meaning that the trails in parallel rejoin after *any of them terminate*.

<pre><code>ParOr ::= <b>par/or</b> <b>do</b>
              Block
         (<b>with</b>
              Block)+
          <b>end</b>
</code></pre>

### par

The <tt>par</tt> statement never rejoins and should be used when the trails in parallel are supposed to run forever (e.g. a <tt>loop</tt> without <tt>break</tt>).

<pre><code>Par ::= <b>par</b> <b>do</b>
            Block
       (<b>with</b>
            Block)+
        <b>end</b>
</code></pre>

<!--[TODO: static analysis or halt]-->

pause/if
--------

TODO

Asynchronous execution
----------------------

### Asynchronous blocks

Asynchronous blocks (*asyncs*) permit that programs in Céu execute time consuming computations without interfering with reactions to input events (referred to as the *synchronous side* of applications).
The syntax for asyncs is as follows:

<pre><code>Async   ::= <b>async</b> ( `(` VarList `)` )? <b>do</b> Block 
<b>end</b>
VarList ::= ID_var (`,` ID_var)*
</code></pre>

An async body can contain non-awaiting loops (*tight loops*), which are [[#sec.model.constraints.bounded|disallowed]] on the synchronous side to ensure that programs remain reactive.

The optional list of variables can be used to copy values from the current scope to be used inside the async body.
Each identifier that appears on the list is automatically declared as new variable in the async body and initialized with the value of the variable with the same name in the current scope.

The following example executes a long computation inside an async in order to keep the program reactive.
In a parallel trail, the program awaits one second to kill the computation if it takes too long:

<pre><code>var int fat;
var int Value;
par/or do
    var int v = await Value;

    // calculates the factorial of v
    fat = async (v) do
        var int fat = 1;
        loop i, v do   // a tight loop
            // v varies from 0 to (v-1)
            fat = fat * (i+1);
        end
        return fat;
    end;
with
    await 1s;          // watchdog to kill the async if it takes too long
    fat = 0;
end
return fat;
</code></pre>

The following restrictions are imposed to asyncs:

* Asyncs only execute when there are no pending reactions to input events.
* Asyncs are suspended whenever a new input event occurs.
* Asyncs cannot use parallel compositions.
* Asyncs cannot nest other asyncs.
* Asyncs cannot await events.
* Asyncs cannot emit internal events.
* Asyncs do not share memory with the synchronous side.

A lower priority for asyncs is fundamental to ensure that input events are handled as fast as possible.

#### Simulation

As asyncs run *detached* from the synchronous side, they are allowed to trigger [[#sec.stmts.events.emit.event|input events]] and the [[#sec.stmts.events.emit.wclock|passage of time]], providing a way to test programs in the own language:

<pre><code>input int A;

// tests a program with a simulation in parallel
par do

    // original program
    var int v = await A;
    loop do
        await 10ms;
        _printf("v = %d\n", v);
        v = v + 1;
    end

with

    // input simulation
    async do
        emit A(0);      // initial value for `v'
        emit 1s35ms;    // the loop executes 103 times
    end
    return 0;
end

// (try online!)
</code></pre>

Whenever an async emits an event, it is suspeded due to its low priority compared to synchronous code.
The example prints the message exactly 103 times.

### Threads

TODO

Native blocks
-------------

Native blocks define new types, variables, and functions in C:

<pre><code>Native ::= <b>native</b> <b>do</b> <code_in_C> <b>end</b>
</code></pre>

<!--
Whatever is written inside a C block is placed on the top of the final output of the Céu parser (which is a C file).
-->

Example:

<pre><code>native _assert(), _inc();
native do
    #include <assert.h>
    int inc (int i) {
        return i+1;
    }
end
_assert(_inc(0) == 1);
</code></pre>

If the code in C contains the terminating <tt>end</tt> keyword of Céu, the 
native block must be delimited with a custom comment to avoid confusing the 
parser:

<pre><code>native do
    /*** c code ***/
    char str = "This `end` confuses the parser";
    /*** c code ***/
end
</code></pre>

Expressions
===========

Besides [[#sec.lex.literals|constants]], [[#sec.stmts.decls.variables|variables]], [[#sec.stmts.C|C symbols]], [[#sec.stmts.events.emit.event|output emits]], and [[#sec.stmts.C.calls|function calls]], Céu supports a wide range of expressions.

Most operators and expressions in Céu follow the same semantics of C.

*Note: assignments are not expressions in Céu.*

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

<pre><code>not      and      or
</code></pre>

which correspond to *not*, *and*, *or*.

Bitwise
-------

The bitwise operators of Céu are

```
    ~      &      |      ^      <<      >>
```

which correspond to *not*, *and*, *or*, *xor*, *left-shift*, and *right-shift*.

Vector indexing
---------------

Céu uses square brackets to index [[#sec.stmts.decls.variables|vectors]]:

```
Index ::= Exp `[` Exp `]`
```

The expression on the left side is expected to evaluate to a vector.

Vector indexes start at zero.
<!-- TODO: limites e recolocar "pointer arith" -->

Pointers
--------

The operator `*` dereferences its pointer operand, while the operator `&amp;` returns a pointer to its operand:

```
Deref ::= `*` Exp
Ref   ::= `&` Exp
```

The operand to `&amp;` must be an [[#sec.exps.assignable|assignable expression]].

Structs
-------

The operators `.` and `:` access the fields of structs.

```
Dot   ::= Exp `.` Exp
Colon ::= Exp `:` Exp
```

The operator `.` expects a struct as its left operand, while the operator `:` expects a reference to a struct.

Example:

<pre><code>native do
    typedef struct {
        int v;
    } mystruct;
end
var _mystruct s;
var _mystruct* p = &s;
s.v = 1;
p:v = 0;
</code></pre>

*Note: structs must be declared in C, as Céu currently has no support for it.*

Type casting
------------

Céu uses angle brackets for type casting:

</code></pre>
Cast ::= `<` ID_type `>`
</code></pre>

Sizeof
------

A <tt>sizeof</tt> expression returns the size of a type, in bytes:

<pre><code>Sizeof ::= `sizeof` `<` ID_type `>`
</code></pre>

The expression is evaluated at compile time.

*Note: Céu has no support for evaluating the size of expressions.*

Precedence
----------

Céu follows the same precedence of C operators:

    /* lower to higer precedence */
    
<pre><code>or
        
    and
        
    |
    
    ^
    
    &
    
    !=    ==
    
    <=    >=    <     >
    
    >>    <<
    
    +     -                // binary
    
    *     /     %
    
    not     &
    
    +     -                // unary
    
    <>                     // typecast
    
    ()    []    :    .     // call, index
    
    sizeof
</code></pre>

Assignable expressions
----------------------

An assignable expression (also known as an *l-value*) can be a variable, vector index, pointer dereference, or struct access.
L-values are required in [[#sec.stmts.assignments|assignments]] and [[#sec.exps.pointers|references]].

Examples:
<pre><code>var int a;
a = 1;

var int[2] v;
v[0] = 1;

var int* p;
*p = 1;

var _mystruct s;
s.v = 1;

var _mystruct* ps;
ps:v = 1;
</code></pre>


Execution model
===============

TODO

<!--
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

See Section [[#Rejoining of tracks]] for the detailed semantics of rejoins.

See Section [[#Deterministic execution]] for information on how Céu avoids non-determinism in parallel compositions.
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

