* 1 [Introduction](#introduction)
    * 1.1 [Synchronous execution model](#synchronous-execution-model)
        * 1.1.1 [Parallel compositions and abortion](#parallel-compositions-and-abortion)
        * 1.1.2 [Bounded execution](#bounded-execution)
        * 1.1.3 [Deterministic execution](#deterministic-execution)
        * 1.1.4 [Internal reactions](#internal-reactions)
    * 1.2 [Organisms as abstractions](#organisms-as-abstractions)
* 2 [Lexical rules](#lexical-rules)
    * 2.1 [Keywords](#keywords)
    * 2.2 [Identifiers](#identifiers)
    * 2.3 [Literals](#literals)
        * 2.3.1 [Booleans](#booleans)
        * 2.3.2 [Integers](#integers)
        * 2.3.3 [Floats](#floats)
        * 2.3.4 [Null pointer](#null-pointer)
        * 2.3.5 [Strings](#strings)
    * 2.4 [Comments](#comments)
* 3 [Types](#types)
    * 3.1 [Primitive types](#primitive-types)
    * 3.2 [Native types](#native-types)
    * 3.3 [Class and Interface types](#class-and-interface-types)
    * 3.4 [Type modifiers](#type-modifiers)
        * 3.4.1 [Pointer](#pointer)
        * 3.4.2 [Alias](#alias)
        * 3.4.3 [Option](#option)
        * 3.4.4 [Dimension](#dimension)
* 4 [Statements](#statements)
    * 4.1 [Blocks](#blocks)
        * 4.1.1 [do-end](#do-end)
        * 4.1.2 [Pre](#pre)
    * 4.2 [Nothing](#nothing)
    * 4.3 [Declarations](#declarations)
        * 4.3.1 [Variables](#variables)
            * 4.3.1.1 [Organisms](#organisms)
                * 4.3.1.1.1 [Constructors](#constructors)
        * 4.3.2 [Pools](#pools)
        * 4.3.3 [Functions](#functions)
            * 4.3.3.1 [Internal functions](#internal-functions)
            * 4.3.3.2 [External functions](#external-functions)
                * 4.3.3.2.1 [return](#return)
        * 4.3.4 [Interrupt service routines](#interrupt-service-routines)
        * 4.3.5 [Events](#events)
            * 4.3.5.1 [Internal events](#internal-events)
            * 4.3.5.2 [External events](#external-events)
                * 4.3.5.2.1 [External Requests](#external-requests)
        * 4.3.6 [Classes and Interfaces](#classes-and-interfaces)
        * 4.3.7 [Data Types](#data-types)
        * 4.3.8 [Native declarations](#native-declarations)
            * 4.3.8.1 [Native blocks](#native-blocks)
            * 4.3.8.2 [Native annotations](#native-annotations)
        * 4.3.9 [Deterministic annotations](#deterministic-annotations)
    * 4.4 [Assignments](#assignments)
        * 4.4.1 [Simple assignment](#simple-assignment)
        * 4.4.2 [Block assignment](#block-assignment)
            * 4.4.2.1 [escape](#escape)
        * 4.4.3 [Await assignment](#await-assignment)
        * 4.4.4 [Emit assignment](#emit-assignment)
        * 4.4.5 [Data assignment](#data-assignment)
        * 4.4.6 [Traverse assignment](#traverse-assignment)
        * 4.4.7 [Vector assignment](#vector-assignment)
        * 4.4.8 [Lua assignment](#lua-assignment)
        * 4.4.9 [Do organism assignment](#do-organism-assignment)
        * 4.4.10 [Spawn assignment](#spawn-assignment)
        * 4.4.11 [Thread assignment](#thread-assignment)
    * 4.5 [Calls](#calls)
        * 4.5.1 [Internal calls](#internal-calls)
        * 4.5.2 [External calls](#external-calls)
    * 4.6 [Event handling](#event-handling)
        * 4.6.1 [Await statements](#await-statements)
            * 4.6.1.1 [Await event](#await-event)
            * 4.6.1.2 [Await time](#await-time)
            * 4.6.1.3 [Await organism](#await-organism)
            * 4.6.1.4 [Await FOREVER](#await-forever)
        * 4.6.2 [Emit statements](#emit-statements)
            * 4.6.2.1 [Emit event](#emit-event)
            * 4.6.2.2 [Emit time](#emit-time)
        * 4.6.3 [Requests](#requests)
    * 4.7 [Organism instantiation](#organism-instantiation)
        * 4.7.1 [Do organism](#do-organism)
        * 4.7.2 [Spawn](#spawn)
        * 4.7.3 [Kill](#kill)
    * 4.8 [Conditional](#conditional)
    * 4.9 [Loop](#loop)
        * 4.9.1 [break](#break)
        * 4.9.2 [continue](#continue)
        * 4.9.3 [Iterators](#iterators)
            * 4.9.3.1 [Incremental index](#incremental-index)
            * 4.9.3.2 [Pool instances](#pool-instances)
        * 4.9.4 [every](#every)
        * 4.9.5 [Traverse](#traverse)
    * 4.10 [Finalization](#finalization)
    * 4.11 [Parallel compositions](#parallel-compositions)
        * 4.11.1 [par/and](#par-and)
        * 4.11.2 [par/or](#par-or)
        * 4.11.3 [par](#par)
        * 4.11.4 [watching](#watching)
    * 4.12 [pause/if](#pause-if)
    * 4.13 [Asynchronous execution](#asynchronous-execution)
        * 4.13.1 [Asynchronous blocks](#asynchronous-blocks)
            * 4.13.1.1 [Simulation](#simulation)
        * 4.13.2 [Threads](#threads)
            * 4.13.2.1 [Synchronous blocks](#synchronous-blocks)
            * 4.13.2.2 [Atomic blocks](#atomic-blocks)
    * 4.14 [C statements](#c-statements)
    * 4.15 [Lua statements](#lua-statements)
* 5 [Expressions](#expressions)
    * 5.1 [Primary](#primary)
    * 5.2 [Arithmetic](#arithmetic)
    * 5.3 [Relational](#relational)
    * 5.4 [Logical](#logical)
    * 5.5 [Bitwise](#bitwise)
    * 5.6 [Vector indexing](#vector-indexing)
    * 5.7 [References](#references)
        * 5.7.1 [Aliasing](#aliasing)
    * 5.8 [### Pointer referencing and dereferencing](####-pointer-referencing-and-dereferencing)
    * 5.9 [Fields](#fields)
        * 5.9.1 [Structs](#structs)
        * 5.9.2 [Organisms](#organisms)
    * 5.10 [Option](#option)
    * 5.11 [Type casting](#type-casting)
    * 5.12 [Sizeof](#sizeof)
    * 5.13 [Precedence](#precedence)
    * 5.14 [Assignable expressions](#assignable-expressions)
* 6 [Static analysis](#static-analysis)
    * 6.1 [Types](#types)
    * 6.2 [Loops](#loops)
    * 6.3 [Finalization](#finalization)
    * 6.4 [Organisms references](#organisms-references)
* 7 [Environment](#environment)
    * 7.1 [The C API](#the-c-api)
        * 7.1.1 [Types](#types)
        * 7.1.2 [Functions](#functions)
        * 7.1.3 [Macros](#macros)
        * 7.1.4 [Constants and Defines](#constants-and-defines)
    * 7.2 [Compiler](#compiler)
* 8 [Errors](#errors)
    * 8.1 [Pointer attributions (11xx)](#pointer-attributions-(11xx))
        * 8.1.1 [1101 : *wrong operator*](#1101----wrong-operator-)
        * 8.1.2 [1102 : *attribution does not require "finalize"*](#1102----attribution-does-not-require-"finalize"-)
        * 8.1.3 [1103 : *wrong operator*](#1103----wrong-operator-)
        * 8.1.4 [1104 : *attribution does not require "finalize"*](#1104----attribution-does-not-require-"finalize"-)
        * 8.1.5 [1105 : *destination pointer must be declared with the "[]" buffer modifier*](#1105----destination-pointer-must-be-declared-with-the-"--"-buffer-modifier-)
        * 8.1.6 [1106 : *parameter must be "hold"*](#1106----parameter-must-be-"hold"-)
        * 8.1.7 [1107 : *pointer access across "await"*](#1107----pointer-access-across-"await"-)
        * 8.1.8 [1108 : *"finalize" inside constructor*](#1108----"finalize"-inside-constructor-)
        * 8.1.9 [1109 : *call requires "finalize"*](#1109----call-requires-"finalize"-)
        * 8.1.10 [1110 : *invalid "finalize"*](#1110----invalid-"finalize"-)
* 9 [Syntax](#syntax)
* 10 [License](#license)


<title>Céu 0.10 - Reference Manual - (warning, incomplete!)</title>
<meta http-equiv="Content-Type" content="text/html; charset=UTF-8"/></p>

## 1
Introduction
============

> *Warning:*
*This manual is under a rewriting process and still mostly reflects version 0.8.*

Céu is an imperative, concurrent and reactive language in which then lines of 
execution, known as *trails*, react together continuously and in synchronous 
steps to external input events from the environment.
Waiting for an event halts the running trail until that event occurs.
The environment broadcasts an occurring event to all active trails, which share 
a single global time reference (the event itself).

The synchronous concurrency model of Céu greatly diverges from conventional 
multithreading (e.g. *pthreads* and *Java threads*) and the actor model (e.g.  
*erlang* and *Go*).
On the one hand, trails can share variables in a deterministic and seamless way 
(e.g. no need for locks or semaphores).
On the other hand, there is no real parallelism (e.g. multi-core execution) in 
the standard synchronous execution mode of the language.

Céu integrates well with C, being possible to define and call C functions from 
within Céu programs.

Céu is [free software](#license).

<!--
Céu is a language for real-time concurrency with complex control 
specifications, but not for algorithm-intensive or distributed applications.
 "Structured Synchronous Reactive Programming"
(safe and deterministic concurrency with side effects)
Céu supports mutable data, with static memory and safe pointer manipulation.
Céu is a programming language for reactive applications and intends to offer a 
higher-level and safer alternative to C.
The two main peculiarities of Céu are the [synchronous execution 
model](#synchronous-execution-model) and the use of [organisms as 
abstractions](#organisms-as-abstractions).
Reactive applications interact in real time and continuously with external 
stimuli from the environment.
They represent a wide range of software areas and platforms: from games in 
powerful desktops, *"apps"* in capable smart phones, to the emerging internet 
of things in constrained embedded systems.
Céu supports concurrent lines of execution---known as *trails*---that react 
continuously to input events from the environment.
Céu has a memory footprint of around 2Kb of ROM and 50b of RAM (on embedded 
platform such as Arduino).
For a gentle introduction about Céu, see the [interactive 
tutorial](http://www.ceu-lang.org/try.php).
See also the complete [Syntax](#syntax) of Céu.
-->

### 1.1
Synchronous execution model
---------------------------

Céu is grounded on a precise definition of *logical time* as a discrete 
sequence of external input events:
a sequence because only a single input event is handled at a logical time; 
discrete because reactions to events are guaranteed to execute in bounded real 
time (see [Bounded execution](#bounded-execution)).

The execution model for Céu programs is as follows:

1. The program initiates the *boot reaction* from the first line of code in a
      single trail.
2. Active trails<sup>1</sup>, one after another, execute until they await or 
      terminate.
      This step is named a *reaction chain*, and always runs in bounded time.
3. The program goes idle and the environment takes control.
4. On the occurrence of a new external input event, the environment awakes 
      *all* trails awaiting that event.
      It then goes to step 2.

(<sup>1</sup>
*Trails can be created with [parallel 
compositions](#parallel-compositions-and-abortion).*)

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
At any time, at most one trail is executing.

The program and diagram below illustrate the behavior of the scheduler of Céu:

<pre><code> 1:  <b>input void</b> A, B, C;
 2:  <b>par/and do</b>           // A, B, and C are external input events
 3:      // trail 1
 4:      &lt;...&gt;            // &lt;...&gt; represents non-awaiting statements
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

![](reaction.png)

The program starts in the boot reaction and splits in three trails (a `par/and` 
rejoins after all trails terminate).
Following the order of declaration for the trails, they are scheduled as 
follows (*t0* in the diagram):

- *trail-1* executes up to the `await A` (line 5);
- *trail-2*, up to the `await B` (line 10);
- *trail-3*, up to `await A` (line 15).

As no other trails are pending, the reaction chain terminates and the scheduler 
remains idle until the event `A` occurs (*t1* in the diagram):

- *trail-1* awakes, executes and terminates (line 6);
- *trail-2* remains suspended, as it is not awaiting `A`.
- *trail-3* executes up to `await B` (line 17).

During this reaction, new instances of events `A`, `B`, and `C` occur (*t1* in 
the diagram) and are enqueued to be handled in the reactions that follow.
As `A` happened first, it is used in the next reaction.
However, no trails are awaiting it, so an empty reaction chain takes place 
(*t2* in the diagram).
The next reaction dequeues the event `B` (*t3* in the diagram):

- *trail-2* awakes, executes and terminates;
- *trail-3* splits in two and they both terminate.

With all trails terminated, the program also terminates and does not react to 
the pending event `C`.
Note that each step in the logical time line (*t0*, *t1*, etc.) is identified 
by the event it handles.
Inside a reaction, trails only react to that identifying event (or remain 
suspended).

<!--
A reaction chain may also contain emissions and reactions to internal events, 
which are presented in Section~\ref{sec.ceu.ints}.
-->

#### 1.1.1
### Parallel compositions and abortion

The use of trails in parallel allows programs to wait for multiple events at 
the same time.
Céu supports three kinds of parallel compositions differing in how they rejoin 
and proceed to the statement in sequence:

1. a `par/and` rejoins after all trails in parallel terminate;
2. a `par/or` rejoins after any trail in parallel terminates;
3. a `par` never rejoins (even if all trails terminate).

The termination of a trail inside a `par/or` aborts the other trails in 
parallel, which must be necessarily awaiting (from rule 2 of [Execution 
model](#synchronous-execution-model)).
Before aborting, a trail has a last opportunity to execute all active 
[finalization statements](#finalization).

As mentioned in the introduction and emphasized in the execution model, trails 
inside parallel compositions do not execute with real parallelism.
Therefore, inside compositions trails are *awaiting in parallel*, rather than 
*executing in parallel*.

#### 1.1.2
### Bounded execution

Reaction chains should run in bounded time to guarantee that programs are 
responsive and can handle upcoming input events from the environment.
For any loop statement in a program, Céu requires that every possible path 
inside its body contains at least one `await` or `break` statement, thus 
avoiding *tight loops* (i.e., unbounded loops that do not await).

In the example below, the `if` true branch may never execute, resulting in a 
tight loop (which the compiler complains about):

<pre><code><b>loop do</b>
    <b>if</b> &lt;cond&gt; <b>then</b>
        <b>break</b>;
    <b>end</b>
<b>end</b>
</code></pre>

For time-consuming algorithms that require unrestricted loops (e.g., 
cryptography, image processing), Céu provides [Asynchronous 
execution](#asynchronous-execution).

#### 1.1.3
### Deterministic execution

`TODO (shared memory + deterministic scheduler + optional static analysis)`

#### 1.1.4
### Internal reactions

Céu provides inter-trail communication through *internal events*.
Trails use the `await` and `emit` operations to manipulate internal events, 
i.e., a trail that emits an event can awake trails previously awaiting the same 
event.

An `emit` starts a new *internal reaction* in the program:

1. On an `emit`, the scheduler remembers the statement following it to execute 
later (i.e., its continuation).
2. All trails awaiting the emitted event awake and execute (like rule 2 for 
external reactions).
3. The emitting trail resumes execution from its continuation.

If an awaking trail emits another internal event, a new internal reaction 
starts.
The scheduler uses a stack policy (first in, last out) for saved continuation 
statements from rule 1.

Example:

<pre><code>1:  <b>par/and do</b>
2:      <b>await</b> e;
3:      <b>emit</b> f;
4:  <b>with</b>
5:      <b>await</b> f;
6:  <b>with</b>
7:      ...
8:      <b>emit</b> e;
9:  <b>end</b>
</code></pre>

The `emit e` in *trail-3* (line 8) starts an internal reaction that awakes the 
`await e` in *trail-1* (line 2).
Then, the `emit f` (line 3) starts another internal reaction that awakes the 
`await f` in *trail-2* (line 5).
*Trail-2* terminates and the `emit f` resumes in *trail-1*.
*Trail-1* terminates and the `emit e` resumes in *trail-3*.
*Trail-3* terminates.
Finally, the `par/and` rejoins (all trails have terminated) and the program 
terminates.

### 1.2
Organisms as abstractions
-------------------------

Céu uses an abstraction mechanism that reconciles data and control state into 
the single concept of an *organism*.
Organisms provide an object-like interface (data state) as well as multiple 
lines of execution (control state).

A class of organisms is composed of an *interface* and a single *execution 
body*.
The interface exposes public variables, methods, and internal events, just like 
objects.
The body can contain any valid code in Céu, which starts on the organism 
instantiation and executes in parallel with the program.
Organism instantiation can be either [static](#variables) or [dynamic](#spawn).

The example below (in the right) blinks two LEDs in parallel with different 
frequencies.
Each blinking LED is a static instance organism of the `Blink` class:

<table width="100%">
<tr valign="top">
<td>
<pre><code>
 1:  <b>class</b> Blink <b>with</b>
 2:      <b>var int</b> led;
 3:      <b>var int</b> freq;
 4:  <b>do</b>
 5:      <b>loop do</b>
 6:          _on(<b>this</b>.led);
 7:          <b>await</b> (<b>this</b>.freq)s;
 8:          _off(<b>this</b>.led);
 9:          <b>await</b> (<b>this</b>.freq/2)s;
10:      <b>end</b>
11:  <b>end</b>
12:
13:  <b>var</b> Blink b1 <b>with</b>
14:       <b>this</b>.led  = 0;
15:       <b>this</b>.freq = 2;
16:  <b>end</b>
17:
18:  <b>var</b> Blink b2 <b>with</b>
19:       <b>this</b>.led  = 1;
20:       <b>this</b>.freq = 4;
21:  <b>end</b>
22:
23:  <b>await</b> 1min;
</code></pre>
</td>

<td>
<pre><code>
 1:  <b>var</b> _Blink b1 <b>with</b>
 2:      <b>this</b>.led  = 0;
 3:      <b>this</b>.freq = 2;
 4:  <b>end</b>
 5:
 6:  <b>var</b> _Blink b2 <b>with</b>
 7:      <b>this</b>.led  = 1;
 8:      <b>this</b>.freq = 4;
 9:  <b>end</b>
10:
11:  <b>par/or do</b>
12:      // body of b1
13:      <b>loop do</b>
14:          _on(b1.led);
15:          <b>await</b> (b1.freq)s;
16:          _off(b1.led);
17:          <b>await</b> (b1.freq)s;
18:      <b>end</b>
19:      <b>await FOREVER</b>;
20:  <b>with</b>
21:      // body of b2
22:      <b>loop do</b>
23:          _on(b2.led);
24:          <b>await</b> (b2.freq)s;
25:          _off(b2.led);
26:          <b>await</b> (b2.freq)s;
27:      <b>end</b>
28:      <b>await FOREVER</b>;
29:  <b>with</b>
30:      <b>await</b> 1min;
31:  <b>end</b>
</code></pre>
</td>
</tr>
</table>

The `Blink` class (lines 1-11) exposes the `led` and `freq` fields, which 
correspond to the LED port and blinking frequency to be configured for each 
instance.
The application creates two instances, specifying the fields in the 
constructors (lines 13-16 and 18-21).
A constructor starts the instance body to execute in parallel with the 
application.
When reaching the `await 1min` (line 23), each instance already has its body 
switching between `_on()` and `_off()` every `freq` milliseconds (lines 5-10).

The code in the left is semantically equivalent to the one in the right, which 
expands the organisms bodies (lines 13-18 and 22-27) in a `par/or` with the 
rest of the application (`await 1min`, in line 30).
Note the `await FOREVER` statements (lines 19 and 28) that avoid the organisms 
bodies to terminate the `par/or`.
The `_Blink` type corresponds to a simple datatype without execution body 
(i.e., conventional *structs* or *records* or objects).

See also [Organism declarations](#organisms), [Class and Interface 
declarations](#classes-and-interfaces), and [Organisms 
instantiation](#organism-instantiation).

<!-- TODO
\footnote{\code{FOREVER} is a reserved keyword in \CEU, and represents an 
external input event that never occurs.}%
, meaning that only the enclosing block can terminate the \code{par/or}.

Note also that the block body runs first and properly initializes the organisms 
before they are spawned.

Once the enclosing block terminates, declared organisms are aborted and all 
memory can be reused, just as happens in standard parallel compositions.
The allocation and deallocation of organisms is static, with no runtime 
overhead such as garbage collection.
-->

------------------------------------------------------------------------------

## 2
Lexical rules
=============

### 2.1
Keywords
--------

Keywords in Céu are reserved names that cannot be used as identifiers (e.g., 
variable and class names):

<pre><code><b>
TODO(pre)

        and             async           async/thread    atomic          await

        bool            break           byte            call            call/rec

        char            class           continue        data            do

        else            else/if         emit            end             escape

        event           every           f32             f64             false

        finalize        float           FOREVER         function        global

        if              in              input           input/output    int

        interface       interrupt       kill            loop            native

        native/pre      new             not             nothing         null

        or              outer           output          output/input    par

        par/and         par/or          pause/if        pool            return

        s16             s32             s64             s8              request

        sizeof          spawn           sync            tag             then

        this            traverse        true            u16             u32

        u64             u8              uint            until           var

        void            watching        with            word            @const

        @hold           @nohold         @plain          @pure           @rec

        @safe
</b></code></pre>

### 2.2
Identifiers
-----------

Céu uses identifiers to refer to *variables*, *internal events*, *external 
events*,  *classes/interfaces*, *data types*, *data tags*, *fields*, and 
*native symbols*.

```
ID       ::= <a-z, A-Z, 0-9, _>+
ID_var   ::= `_´ | ID           // [variables and internal events] beginning with a lowercase letter
ID_ext   ::= ID                 // [external events] all in uppercase, not beginning with a digit
ID_cls   ::= ID                 // [classes and interfaces] beginning with an uppercase letter
ID_data  ::= ID                 // [data types] beginning with an uppercase letter
ID_tag   ::= ID                 // [data tags] all in uppercase, not beginning with a digit
ID_field ::= ID                 // [fields] not beginning with a digit
ID_nat   ::= ID                 // [native symbols] beginning with an underscore
ID_type  ::= ( ID_nat | ID_cls  // [types]
             | <b>bool</b>  | <b>byte</b>  | <b>char</b>  | <b>f32</b>   | <b>f64</b>   |
             | <b>float</b> | <b>int</b>   | <b>s16</b>   | <b>s32</b>   | <b>s64</b>   |
             | <b>s8</b>    | <b>u16</b>   | <b>u32</b>   | <b>u64</b>   | <b>u8</b>    |
             | <b>uint</b>  | <b>void</b>  | <b>word</b> )
```

Class, interface, and data [declarations] create new [types] which can be used 
as type identifiers.

Examples:

<pre><code><b>var int</b> a;                    // "a" is a variable, "int" is a type
<b>emit</b> e;                       // "e" is an internal event
<b>await</b> E;                      // "E" is an external input event
<b>var</b> Sprite s;                 // "Sprite" is a class and a type
<b>var</b> List l;                   // "List" is a data type and a type
<b>return</b> list.CONS.head;        // "CONS" is a tag, "head" is a field
_printf("hello world!\n");    // "_printf" is a native symbol
</code></pre>


### 2.3
Literals
--------

#### 2.3.1
### Booleans

Boolean types have the values `true` and `false`.

#### 2.3.2
### Integers

Integer values can be written in different bases and also as ASCII characters:

* Decimals are written *as is*.
* Octals are prefixed with <tt>0</tt>.
* Hexadecimals are prefixed with <tt>0x</tt>.
* ASCII characters and escape sequences are surrounded by apostrophes.
* `TODO: "1e10"`

Examples:

```
// all following are equal to the decimal 127
v = 127;
v = 0777;
v = 0x7F;

// newline ASCII character = decimal 10
c = '\n';
```

#### 2.3.3
### Floats

`TODO (like C)`

#### 2.3.4
### Null pointer

The `null` literal represents null [pointers](#pointer).

#### 2.3.5
### Strings

A sequence of characters surrounded by `"` is converted into a *null-terminated 
string*, just like in C:

Example:

```
_printf("Hello World!\n");
```

### 2.4
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


------------------------------------------------------------------------------

## 3
Types
=====

Céu is statically typed, requiring all variables and events to be declared before they are used.

A type is composed of an identifier with a sequence of optional modifiers:

<pre><code>Type ::= ID_type ( `&&´ | `&´ | `?´ | `[´ [NUM] `]´ )
</code></pre>

A type identifier can be a [native identifier](#identifiers), a [class 
identifier](#identifiers), a [data type identifier](#identifiers) or one of the 
primitive types:

<pre><code>ID_type ::= ( ID_nat | ID_cls | ID_data
              <b>bool</b>  | <b>byte</b>  | <b>char</b>  | <b>f32</b>   | <b>f64</b>   |
              <b>float</b> | <b>int</b>   | <b>s16</b>   | <b>s32</b>   | <b>s64</b>   |
              <b>s8</b>    | <b>u16</b>   | <b>u32</b>   | <b>u64</b>   | <b>u8</b>    |
              <b>uint</b>  | <b>void</b>  | <b>word</b> )
</code></pre>

Examples:

<pre><code><b>var u8</b> v;       // "v" is of 8-bit unsigned integer type
<b>var</b> _rect r;    // "r" is of external native type "rect"
<b>var char</b>&& buf; // "buf" is a pointer to a "char"
<b>var</b> Send s;     // "s" is an organism of class "Send"
<b>var</b> Tree t;     // "t" is a data of type "Tree"
</code></pre>

### 3.1
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

### 3.2
Native types
------------

Types defined externally in C can be prefixed by `_` to be used in Céu programs.

Example:

<pre><code><b>var</b> _message_t msg;      // "message_t" is a C type defined in an external library
</code></pre>

Native types support [annotations](#native-symbols) which provide additional 
information to the compiler.

<!--
The size of an external type must be explicitly [[#sec.stmts.decls.types|declared]].

Example:

    native _char = 1;  // declares the external native type `_char` of 1 byte
-->

### 3.3
Class and Interface types
-------------------------

`TODO (brief description)`

See [Classes and Interfaces](#classes-and-interfaces).

### 3.4
Type modifiers
--------------

Types can be suffixed with the following modifiers: `&&`, `&`, `?`, and `[N]`.

#### 3.4.1
### Pointer

`TODO (like C)`

#### 3.4.2
### Alias

`TODO (like C++ references)`

#### 3.4.3
### Option

`TODO (like Maybe)`

#### 3.4.4
### Dimension

`TODO (vectors, pools)`

One-dimensional vectors are declared by suffixing the variable type with the 
vector length surrounded by `[` and `]`.
The first index of a vector is zero.

Example:

<pre><code><b>var int</b>[2] v;       // declares a vector "v" of 2 integers
</code></pre>

------------------------------------------------------------------------------

## 4
Statements
==========

### 4.1
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

Compound statements (e.g. [if-then-else](#conditional)) create new blocks and 
can be nested for an arbitrary level.

#### 4.1.1
### do-end

A block can be explicitly created with the `do-end` statement:

<pre><code>Do ::= <b>do</b> Block <b>end</b>
</code></pre>

#### 4.1.2
### Pre

TODO ("static code" appended in sequence to the beginning)

<pre><code>Pre ::= <b>pre do</b> Block <b>end</b>
</code></pre>

### 4.2
Nothing
-------

`nothing` is a innocuous statement:

<pre><code>Nothing ::= <b>nothing</b>
</code></pre>

### 4.3
Declarations
------------

#### 4.3.1
### Variables

The syntax for the definition of variables is as follows:

<pre><code>DclVar ::= <b>var</b> Type ID_var [`=´ Assignment] { `,´ ID_var [`=´ Assignment] }
</code></pre>

A variable has an associated [type](#types) and can be optionally initialized 
(see [Assignments](#assignments)).

Variables are only visible inside the [block](#blocks) they are defined.

Examples:

<pre><code><b>var int</b> a=0, b=3;   // declares and initializes integer variables "a" and "b"
<b>var int</b>[2] v;       // declares a vector "v" of size 2
</code></pre>

##### 4.3.1.1
#### Organisms

An organism is a variable whose type is the identifier of a [class 
declaration](#classes-and-interfaces).
An optional constructor can initialize the organism fields:

<pre><code>DclOrg ::= <b>var</b> Type ID_var [ <b>with</b>
              Block
           <b>end</b> ]
</code></pre>

Example:

<pre><code><b>class</b> T <b>with</b>
    <b>var int</b> v;
<b>do</b>
    &lt;body-of-T&gt;
<b>end</b>
<b>var</b> T t <b>with</b>       // "t" is an organism of class "T"
    <b>this</b>.v = 0;    // whose field "v" is initialized to "0"
<b>end</b>
</code></pre>

After the declaration, the body of an organism starts to execute in 
[parallel](#parallel-compositions] with the rest of the application.
The table below shows the equivalent expansion of an organism declaration to a 
[`par/or`](#paror) containing the class body:

<table width="100%">
<tr valign="top">
<td>
<pre><code>&lt;code-pre-declaration&gt;
<b>var</b> T t <b>with</b>
    &lt;code-constructor-of-t&gt;
<b>end</b>;
&lt;code-pos-declaration&gt;
</code></pre>
</td>

<td>
<pre><code>&lt;code-pre-declaration&gt;
<b>par/or do</b>
    &lt;code-constructor-of-t&gt;
    &lt;code-body-of-class-T&gt;
    <b>await FOREVER;</b>
<b>with</b>
    &lt;code-pos-declaration&gt;
<b>end</b>
</code></pre>
</td>
</tr>
</table>

Given that an organism is a variable, the block it is declared restricts its 
lifetime.
In the expansion, the `par/or` makes the organism to go out of scope when 
`<code-pos-declaration>` terminates.

`TODO (assumes code-pos-declaration closes the block exactly on the end)`

`TODO (vectors of organisms: copy the declaration N times)`

###### 4.3.1.1.1
##### Constructors

Inside constructors the expression `this` refers to the new organism, while the 
expression `outer` refers to the enclosing organism creating the new organism:

<pre><code><b>class</b> U <b>with</b>
    <b>var int</b> v;
<b>do</b>
    ...
<b>end</b>

<b>class</b> T <b>with</b>
    <b>var int</b> v;
<b>do</b>
    <b>var</b> U u <b>with</b>
        <b>this</b>.v = <b>outer</b>.v;   // "this" is of class "U", "outer" is of class "T"
    <b>end</b>;
<b>end</b>
</code></pre>

#### 4.3.2
### Pools

A pool is a container for [dynamic instances of organisms](#spawn) and 
[recursive data](#TODO) of the same type:

<pre><code>DclPool ::= <b>pool</b> Type ID_var [`=´ Assignment] { `,´ ID_var [`=´ Assignment] }
</code></pre>

The type has to be a [class, interface, or data type identifier](#identifiers) 
followed by a [dimension modifier](#dimension).
For pools of classes and recursive data types, the number inside the dimension 
brackets represents the maximum number of instances supported by the pool.
For pools of interfaces, the number represents the maximum number of bytes for 
all instances (as each instance may have a different size).

The number inside the vector modifier brackets is optional.
If not specified, the number of instances in the pool is unbounded and all 
allocations go to the heap.
When specified, allocation goes to a static memory pool preallocated at compile 
time.

Examples:

<code><pre><b>pool</b> T[10]  ts;      // a pool of at most 10 instances of class "T"
<b>pool</b> T[]    ts;      // an unbounded pool of instances of class "T"
<b>pool</b> I[100] is;      // a pool of at most 100 bytes of instances of interface "I"
<b>pool</b> I[]    is;      // an unbounded pool of instances of interface "I"
<b>pool</b> D[100] ds;      // a pool of at most 100 instances of recursive data type "D"
<b>pool</b> D[]    ds;      // an unbounded pool of instances of recursive data type "D"
</code></pre>

The lifetime of all instances inside a pool is restricted to the block it is 
declared.
When a pool of organisms goes out of scope, all organism bodies are 
automatically aborted.

See [Dynamic execution](#spawn) for organisms allocation.
See [TODO](#TODO) for recursive data allocation.

#### 4.3.3
### Functions

`TODO (intro/prototype/implementation)`

<pre><code>/* internal functions */
DclFun ::= <b>function</b> [<b>@rec</b>] `(´ParList`)´ `=>´ Type ID_var
              [ `do´ Block `end´ ]

/* external functions */
DclFunExt ::= <b>output</b> [<b>@rec</b>] `(´ParList`)´ `=>´ Type ID_var ID_ext { `,´ ID_ext }
            | <b>input</b>  [<b>@rec</b>] `(´ParList`)´ `=>´ Type ID_var ID_ext { `,´ ID_ext }
                 [ `do´ Block `end´ ]

Return ::= <b>return</b> [Exp]

ParList ::= ParItem { `,´ ParItem }
ParItem ::= [<b>@hold</b>] Type [ID_var]
</code></pre>

##### 4.3.3.1
#### Internal functions

`TODO (like functions in any language)`

##### 4.3.3.2
#### External functions

`TODO (more or less like dynamically loaded functions)`

###### 4.3.3.2.1
##### return

`TODO (like return in any language)`

#### 4.3.4
### Interrupt service routines

`TODO`

<pre><code>DclIsr ::= <b>interrupt</b> `[´ NUM `]´ [<b>@rec</b>]
              [ `do´ Block `end´ ]
</code></pre>

#### 4.3.5
### Events

See also [Event handling](#event-handling).

##### 4.3.5.1
#### Internal events

Internal events have the same purpose of external events, but for 
[communication within trails in a program](#internal-reactions).

The declaration of internal events is as follows:

<pre><code>DclInt ::= <b>event</b> (Type | `(´ TypeList `)´) ID_var { `,´ ID_var }
</code></pre>

In contrast with external events, an internal event is for input and output at 
the same time.

Internal events cannot be of a vector type.

*Note: <tt>void</tt> is a valid type for signal-only internal events.*

<span id="sec.stmts.decls.c"></span>

##### 4.3.5.2
#### External events

External events are used as interfaces between programs and devices from the 
real world:

* *input* events represent input devices, such as sensors, switches, etc.
* *output* events represent output devices, such as LEDs, motors, etc.

Being reactive, programs in Céu have input events as their sole entry points 
through [await statements](#await-statements).

The declaration of input and output events is as follows:

<pre><code>DclExt ::= <b>output</b> (Type | `(´ TypeList `)´) ID_ext { `,´ ID_ext }
         | <b>input</b>  (Type | `(´ TypeList `)´) ID_ext { `,´ ID_ext }

TypeList ::= Type { `,´ Type }
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

###### 4.3.5.2.1
##### External Requests

`TODO (emit + await)`

<pre><code>DclReq ::= <b>output/input</b> `[´ [Exp] `]´ `(´ParList`)´ `=>´ Type ID_ext { `,´ ID_ext }
         | <b>input/output</b> `[´ [Exp] `]´ `(´ParList`)´ `=>´ Type ID_ext { `,´ ID_ext }
            [ `do´ Block `end´ ]
</code></pre>

<!--
An external event is either of type input or output, never being both at the 
same time.
For devices that perform input and output (e.g. radio transceivers), the 
underlying platform must provide different events for each functionality.
-->

#### 4.3.6
### Classes and Interfaces

A `class` is a template for creating organisms.
It contains an *interface* and a *body* common to all instances of the class.
The interface exposes internal variables, events, and methods that other 
organisms can manipulate directly.
The body specifies the behavior of the organism and executes when it is 
instantiated.

An `interface` is a template for classes that shares the same 
interface<sup>1</sup>.
The body and method implementations may vary among classes sharing the same 
interface.

(<sup>1</sup>
*The term "interface" is overload with two possible meanings: the set of 
members exposed by a class; and a template that defines a set of members that 
classes can reuse.*)

The declaration of classes and interfaces is as follows:

<pre><code>DclCls ::= <b>class</b> ID_cls <b>with</b>
                Dcls    // interface
            <b>do</b>
                Block   // body
            <b>end</b>

DclIfc ::= <b>interface</b> ID_cls <b>with</b>
                Dcls    // interface
            <b>end</b>

Dcls ::= { (DclVar | DclInt | DclPool | DclFun | DclImp) `;´ }

DclImp ::= <b>interface</b> ID_cls { `,´ ID_cls }
</code></pre>

`Dcls` is a sequence of variables, events, pools, and functions (methods) 
declarations.
It can also refer to other interfaces through a `DclImp` clause, which copies 
all declarations from the referred interfaces.

#### 4.3.7
### Data Types

`TODO`

<pre><code>DclData ::= <b>data</b> ID_data <b>with</b>
                (Struct | Union)
            <b>end</b>

Struct ::= DclVar `;´ { DclVar `;´ }
Union  ::= DclTag { <b>or</b> DclTag }

DclVar ::= <b>var</b> Type ID_var { `,´ ID_var }
DclTag ::= <b>tag</b> ID_tag <b>with</b>
               DclVar `;´ { DclVar `;´ }
           <b>end</b>
</code></pre>

#### 4.3.8
### Native declarations

##### 4.3.8.1
#### Native blocks

`TODO (native/pre)`

Native blocks define new types, variables, and functions in C:

<pre><code>Native ::= (<b>native</b> | <b>native/pre</b>) <b>do</b>
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

##### 4.3.8.2
#### Native annotations

Native declarations provide additional information about external C symbols.
A declaration is an annotation followed by a list of symbols:

<pre><code>DclNat   ::= <b>native</b> [<b>@pure</b>|<b>@const</b>|<b>@nohold</b>|<b>@plain</b>] Nat_list
Nat_list  ::= (Nat_type|Nat_func|Nat_var) { `,` (Nat_type|Nat_func|Nat_var) }
Nat_type  ::= ID_nat `=´ NUM
Nat_func  ::= ID_nat `(´ `)´
Nat_var   ::= ID_nat
</code></pre>

A type declaration may define its size in bytes to help the compiler organizing 
memory.
A type of size `0` is an *opaque type* and cannot be instantiated as a variable 
that is not a pointer.

Functions and variables are distinguished by the `()` that follows function declarations.

Native symbols can have the following annotations:

**@plain** states that the type is not a pointer to another type.
**@const** states that the symbol is a constant (e.g. a `#define`).
**@pure** states that the function has no side effects.
**@nohold** states that the function does not hold pointers passed as parameters.

The [static analysis](#static-analysis) of Céu relies on annotations.

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

#### 4.3.9
### Deterministic annotations

A variable or function can be declared as `@safe` with a set of other functions 
or variables:

<pre><code>DclDet ::= <b>@safe</b> ID <b>with</b> ID { `,´ ID }
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

See also [Static analysis](#static-analysis).

### 4.4
Assignments
-----------

Céu supports many kinds of assignments:

<pre><code>Set ::= (Exp | `(´VarList`)´) `=´ Assignment

VarList ::= ID_var  { `,´ ID_var } `)´

Assignment ::= Exp
             | AssignableBlock
             | &lt;await&gt;
             | ( [ `(´ ] &lt;emit-ext&gt
                       | &lt;call-ext&gt;
                       | &lt;request-ext&gt;
                 [ `)´ ] )
             | [ `new´ ] Data
             | &lt;traverse-loop&gt;
             | &lt;traverse-rec&gt;
             | Vector
             | &lt;lua&gt;
             | &lt;do-org&gt;
             | &lt;spawn&gt;
             | &lt;thread&gt;
</code></pre>

The expression on the left side must be [assignable](#assignable).

TODO (Exp, VarList)

#### 4.4.1
### Simple assignment

The simpler form of assignment uses [expressions](#expressions) as values.

Example:

<pre><code><b>var int</b> a,b;
a = b + 1;
</code></pre>

#### 4.4.2
### Block assignment

A whole block can be used as an assignment value by escaping from it.
The following block statements can be used in assignments: [`do-end`](#do-end) 
[`if-then-else`](#conditional), [`loop`](#loop), [`every`](#every), and 
[`par`](#par):

<pre><code>AssignableBlock ::= &lt;do-end&gt; | &lt;if-then-else&gt; | &lt;loop&gt; | &lt;every&gt; | &lt;par&gt;
</code></pre>

##### 4.4.2.1
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

#### 4.4.3
### Await assignment

See [Await statements](#await-statements).

#### 4.4.4
### Emit assignment

See [Emit statements](#emit-statements).

#### 4.4.5
### Data assignment

`TODO`

<pre><code>Data ::= ID_data [`.´ ID_tag] `(´ List `)´
List ::= [ (Data|Exp) { `,´ (Data|Exp) } ]
</code></pre>

#### 4.4.6
### Traverse assignment

`TODO`

#### 4.4.7
### Vector assignment

`TODO`

<pre><code>Vector ::= Item { `..´ Item }
Item   ::= Exp | `[´ [ExpList] `]´
</code></pre>

#### 4.4.8
### Lua assignment

`TODO`

#### 4.4.9
### Do organism assignment

`TODO`

#### 4.4.10
### Spawn assignment

See [Spawn](#spawn).

#### 4.4.11
### Thread assignment

See [Threads](#threads).

### 4.5
Calls
-----

The syntax for function calls is as follows:

<pre><code>/* internal calls */
CallInt ::= [<b>call</b>|<b>call/rec</b>] Exp * `(´ [ExpList] `)´

/* external calls */
CallExt ::= (<b>call</b>+<b>call/rec</b>) ID_ext [ `=>´ (Exp | `(´ [ExpList] `)´)

ExpList = Exp { `,´ Exp }
</code></pre>

<!--
The called expression has to evaluate to a [internal](#internal-functions), 
[external](#external-functions)), or [native](#native-symbols) function.
For internal and native calls, the `call` operator is optional, but recursive 
functions must use the `call/rec` operator (see [Static 
analysis](#static-analysis)).

Examples:

```
_printf("Hello World!\n");  // calls native "printf"
o.f();                      // calls method "f" of organism "o"
F(1,2,3);                   // calls external function "F"
```

TODO: unbounded execution
Native functions cannot be \CEU does not extend the bounded execution analysis 
to $C$ function calls.
On the one hand, $C$ calls must be carefully analyzed in order to keep programs
responsive.
On the other hand, they also provide means to circumvent the rigor of \CEU in a
well-marked way (the special underscore syntax).
-->

#### 4.5.1
### Internal calls

`TODO`

#### 4.5.2
### External calls

`TODO`

### 4.6
Event handling
--------------

Events are the most fundamental concept of Céu, accounting for its reactive 
nature.
Programs manipulate events through the `await` and `emit` statements.
An `await` halts the running trail until that event occurs.
An event occurrence is broadcast to all trails trails awaiting that event, 
awaking them to resume execution.

Céu supports external and internal events.
External events are triggered by the [environment](#environment), while 
internal events, by the `emit` statement.
See also [Synchronous execution model] for the differences between external and 
internal reactions.

#### 4.6.1
### Await statements

The `await` statement halts the running trail until the referred *wall-clock* 
time, [input event](#external), or [internal event](#internal) occurs.

<pre><code>Await ::= ( <b>await</b> ID_ext |
            <b>await</b> Exp    |
            <b>await</b> (WCLOCKK|WCLOCKE)
          ) [ <b>until</b> Exp ]
       | <b>await</b> <b>FOREVER</b>

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
It can be understood as the expansion below:

<pre><code><b>loop do</b>
    <b>await</b> &lt;...&gt;;
    <b>if</b> &lt;Exp&gt; <b>then</b>
        <b>break</b>;
    <b>end</b>
<b>end</b>
</code></pre>

##### 4.6.1.1
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

`TODO (awake rule for internal events, unless "every")`

##### 4.6.1.2
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

##### 4.6.1.3
#### Await organism

`TODO`

##### 4.6.1.4
#### Await FOREVER

The `await FOREVER` halts the running trail forever.
It cannot be used in assignments, because it never evaluates to anything.

#### 4.6.2
### Emit statements

The `emit` statement triggers the referred *wall-clock* time, [input 
event](#external), or [internal event](#internal), awaking all trails waiting 
for it.

<pre><code>Emit ::= <b>emit</b> Exp    [ `=>´ (Exp | `(´ [ExpList] `)´)
      |  <b>emit</b> ID_ext [ `=>´ (Exp | `(´ [ExpList] `)´)
      |  <b>emit</b> (WCLOCKK|WCLOCKE)
</code></pre>

##### 4.6.2.1
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

The emission of internal events start new [internal 
reactions](#internal-reactions).

`TODO (emit output evaluates to "int")`

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

##### 4.6.2.2
#### Emit time

Emit statements with *wall-clock* time expect expressions with units of time, 
as described in [Await time](#await-time).

Like input events, time can only be emitted inside [asynchronous 
blocks](#asynchronous-blocks).

#### 4.6.3
### Requests

`TODO (emit+await)`

<pre><code>Request ::= <b>request</b> ID_ext [ `=>´ (Exp | `(´ [ExpList] `)´)
</code></pre>

### 4.7
Organism instantiation
----------------------

#### 4.7.1
### Do organism

`TODO`

<pre><code>DoOrg ::= <b>do</b> ID_cls [<b>with</b>
              Constructor
          <b>end</b>]
</code></pre>

#### 4.7.2
### Spawn

The `spawn` statement creates instances of organisms dynamically:

<pre><code>Spawn ::= <b>spawn</b> ID_cls [<b>in</b> Exp] [<b>with</b>
              Constructor
          <b>end</b>]
</code></pre>

TODO(option return)
<!--
The `spawn` returns a pointer to the allocated organism, or `null` in the case 
of failure.
-->

The optional `in` clause allows the statement to specify in which 
[pool](#pools) the organisms will live.
If absent, the organism is allocated on an implicit pool in the outermost block 
of the class the allocation happens.

On allocation, the body of the organism starts to execute in parallel with the 
rest of the application, just like [static organisms](#organisms).
The constructor clause is also the same as for [static 
organisms](#constructors).

In contrast to static organisms, the lifetime of a dynamic instance is attached 
to the scope of the pool and not to the scope of the `spawn` instantiation.
Furthermore, a dynamic organism is automatically deallocated when its execution 
body terminates.

See [Static analysis](#organisms-references) for the restrictions on 
manipulating pointers and references to organisms.

#### 4.7.3
### Kill

`TODO`

<pre><code><b>kill</b> * Exp * [ `=>´ Exp ]
</code></pre>

### 4.8
Conditional
-----------

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

### 4.9
Loop
----

A `loop` continuously executes its body block:

<pre><code>Loop ::= <b>loop</b>[`/´ Exp] [ ID_var [<b>in</b> Exp] ] <b>do</b>
             Block
         <b>end</b>
</code></pre>

A `loop` terminates when it reaches a [`break`](#break) or its (optional) 
[iterator](#iterators) terminates.

`TODO (hard limit)`

#### 4.9.1
### break

A `break` escapes the innermost enclosing loop:

<pre><code>Break ::= <b>break</b>
</code></pre>

Example:

<pre><code><b>loop do</b>                   // loop 1
    ...
    <b>loop do</b>               // loop 2
        <b>if</b> &lt;cond-1&gt; <b>then</b>
            <b>break</b>;        // escapes loop 2
        <b>end</b>
        ...
    <b>end</b>
    ...
    <b>if</b> &lt;cond-2&gt; <b>then</b>
        <b>break</b>;            // escapes loop 1
    <b>end</b>
    ...
<b>end</b>
</code></pre>

#### 4.9.2
### continue

A `continue` restarts the innermost enclosing loop:

<pre><code>Continue ::= <b>continue</b>
</code></pre>

Example:

<pre><code><b>loop do</b>                   // loop 1
    ...
    <b>loop do</b>               // loop 2
        <b>if</b> &lt;cond-1&gt; <b>then</b>
            <b>continue</b>;        // restarts loop 2
        <b>end</b>
        ...
    <b>end</b>
    ...
    <b>if</b> &lt;cond-2&gt; <b>then</b>
        <b>break</b>;            // restarts loop 1
    <b>end</b>
    ...
<b>end</b>
</code></pre>

A `continue` can only be used inside an [`if-then-else`](#conditional) with an 
empty `else` branch and exactly one level deeper than the enclosing `loop`:

<pre><code><b>loop do</b>
    <b>par do</b>    // makes the "continue" illegal
        <b>if</b> &lt;cond&gt; <b>then</b>
            <b>continue</b>;
        <b>else</b>  // makes the "continue" illegal
            ...
        <b>end</b>
    <b>with</b>
        ...
    <b>end</b>
<b>end</b>
</code></pre>


#### 4.9.3
### Iterators

A `loop` may specify an iterator that yields a new value on each loop 
iteration.

##### 4.9.3.1
#### Incremental index

For iterators in which `Exp` is empty or is of type `int`, `ID_var` is 
incremented after each loop iteration.
`ID_var` is automatically declared read-only, with visibility restricted to the 
loop body, and is initialized to zero.
The optional `Exp` limits the number of iterations, and is evaluated once 
before the loop starts.

Example:

<pre><code><b>loop</b> i <b>in</b> 10 <b>do</b>
    _printf("i = %d\n", i);     // prints "i = 0" up to "i = 9"
<b>end</b>
</code></pre>

##### 4.9.3.2
#### Pool instances

For iterators in which `Exp` evaluates to a pool of organisms, `ID_var`
evaluates to pointers to instances in the pool, one at a time, from the oldest 
to the newest created.
`ID_var` is automatically declared read-only, with visibility restricted to the 
loop body.

`TODO (example)`

#### 4.9.4
### every

The `every` statement continuously awaits an event and executes its body:

<pre><code>Every ::= <b>every</b> (Var | `(´VarList`)´) <b>in</b> (WCLOCKK|WCLOCKE|ID_ext|Exp) <b>do</b>
              Block
          <b>end</b>
</code></pre>

An `every` expands to a `loop` as illustrated below:

<table width="100%">
<tr valign="top">
<td>
<pre><code><b>every</b> &lt;attr&gt; <b>in</b> &lt;event&gt; <b>do</b>
    &lt;block&gt;
<b>end</b>
</code></pre>
</td>

<td>
<pre><code><b>loop do</b>
    &lt;attr&gt; = <b>await</b> &lt;event&gt;
    &lt;block&gt;
<b>end</b>
</code></pre>
</td>
</tr>
</table>

The body of an `every` cannot contain an `await`, ensuring that no occurrences 
of `<event>` are ever missed.

`TODO (restrictions, escape/break)`

`TODO (exception to the rule for internal events)`

#### 4.9.5
### Traverse

`TODO`

<pre><code>TraverseLoop ::= <b>traverse</b> ID_var <b>in</b> (`[´ Exp `]´ | Exp)
                    [ <b>with</b> Dcls <b>end</b> ]
                 <b>do</b>
                     Block
                 <b>end</b>
TraverseRec  ::= <b>traverse</b>['/' NUM] Exp
                     [ <b>with</b> Block <b>end</b> ]
</code></pre>


### 4.10
Finalization
------------

The `finalize` statement postpones the execution of its body to happen when its 
associated block goes out of scope:

<pre><code>Finalize ::= <b>finalize</b>
                 [Exp `=´ Assignment]
             <b>with</b>
                 Block
             <b>end</b>
</code></pre>

The presence of the optional attribution clause determines which block to 
associate with the `finalize`:

1. The enclosing block, if the attribution is absent.
2. The block of the variable being assigned, if the attribution is present.

Example:

<pre><code>
<b>input int</b> A;
<b>par/or do</b>
    <b>var</b> _FILE* f;
    <b>finalize</b>
        f = _fopen("/tmp/test.txt");
    <b>with</b>
        _fclose(f);
    <b>end</b>
    <b>every</b> v <b>in</b> A <b>do</b>
        fwrite(&v, ..., f);
    <b>end</b>
<b>with</b>
    <b>await</b> 1s;
<b>end</b>
</code></pre>

The program opens `f` and writes to it on every occurrence of `A`.
The writing trail is aborted after one second, but the `finalize` safely closes
the file, because it is associated to the block that declares `f`.

The [static analysis](#static-analysis) of Céu enforces the use of `finalize` 
for unsafe attributions.

### 4.11
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

See [Synchronous execution model](#synchronous-execution-model) for a detailed 
description of parallel execution.

#### 4.11.1
### par/and

The `par/and` statement stands for *parallel-and* and rejoins when all trails 
terminate:

#### 4.11.2
### par/or

The `par/or` statement stands for *parallel-or* and rejoins when any of the 
trails terminate:

#### 4.11.3
### par

The `par` statement never rejoins and should be used when the trails in 
parallel are supposed to run forever:

<!--[TODO: static analysis or halt]-->

#### 4.11.4
### watching

The `watching` statement aborts its body when its associated event occurs:

<pre><code> Watching ::= <b>watching</b> [ (Var | `(´VarList`)´) <b>in</b> ] (WCLOCKK|WCLOCKE|ID_ext|Exp)
                 Block
             <b>end</b>
</code></pre>

A `watching` expands to a `par/or` as illustrated below:

<table width="100%">
<tr valign="top">
<td>
<pre><code><b>watching</b> &lt;...&gt; in &lt;event&gt; <b>do</b>
    &lt;block&gt;
<b>end</b>
</code></pre>
</td>

<td>
<pre><code><b>par/or do</b>
    &lt;...&gt; <b>await</b> &lt;event&gt;
<b>with</b>
    &lt;block&gt;
<b>end</b>
</code></pre>
</td>
</tr>
</table>

`TODO (Var/VarList is implicitly declared)`

`TODO: strong abortion`

`TODO: see Await for supported events`

### 4.12
pause/if
--------

`TODO`

<pre><code>Pause ::= <b>pause/if</b> Exp <b>do</b>
              Block
          <b>end</b>
</code></pre>

### 4.13
Asynchronous execution
----------------------

Asynchronous execution permit that programs execute time consuming computations 
without interfering with the *synchronous side* of applications (i.e., 
everything, except asynchronous statements).

<pre><code>Async ::= (<b>async</b> | <b>async/thread</b>) [ `(´VarList`)´ ] <b>do</b>
              Block
          <b>end</b>
</code></pre>

#### 4.13.1
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

##### 4.13.1.1
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

#### 4.13.2
### Threads

`TODO(async/thread)`

##### 4.13.2.1
#### Synchronous blocks

`TODO`

<pre><code>Sync ::= <b>sync do</b>
             Block
         <b>end</b>
</code></pre>

##### 4.13.2.2
#### Atomic blocks

`TODO(mutual exclusion isr and sync)`

<pre><code>Atomic ::= <b>atomic do</b>
             Block
         <b>end</b>
</code></pre>

### 4.14
C statements
------------

`TODO`

<pre><code>C ::= `{´ &lt;C code&gt; `}´
</code></pre>

### 4.15
Lua statements
--------------

`TODO`

<pre><code>Lua ::= `[´ {`=´} `[´
                       { <i>&lt;lua code&gt;</i> | `@´ Exp }
                   `]´ {`=´} `]´
</code></pre>

------------------------------------------------------------------------------

## 5
Expressions
===========

The syntax for expressions in Céu is as follows:

<pre><code>Exp ::= Prim
        |  Exp <b>or</b> Exp
        |  Exp <b>and</b> Exp
        |  Exp (`!=´|`==´|`&lt;=´|`&lt;´|`&gt;´|`&gt;=´) Exp
        |  Exp `|´ Exp
        |  Exp `^´ Exp
        |  Exp `&´ Exp
        |  Exp (`&lt;&lt;´|`&gt;&gt;´) Exp
        |  Exp (`+´|`-´) Exp
        |  Exp (`*´|`/´|`%´) Exp
        |  (<b>not</b>|`+´|`-´|`~´|`*´|`&&´|`&´|`$$´|`$´) Exp
        |  `(´ Type `)´ Exp     /* same precedence as previous */
        |  Exp `[´ Exp `]´      /* same precedence for all following */
        |  Exp (`.´|`:´) (ID_field | ID_tag)
        |  Exp (`?´|`!´)
        |  Exp `(´ [ExpList] `)´ [<b>finalize with</b> Block <b>end</b>]

Prim ::= `(´ Exp `)´
        |  <b>sizeof</b> `(´ (Type|Exp) `)´
        |  ID_var | ID_nat
        |  <b>null</b> | NUM | String
        |  <b>true</b> | <b>false</b>
        |  <b>global</b> | <b>this</b> | <b>outer</b>
        |  (<b>call</b> | <b>call/rec</b>) Exp
        |  &lt;c-stat&gt
</code></pre>

*Note: assignments are not expressions in Céu.*

### 5.1
Primary
-------

`TODO: global, this, outer, ID_var, ID_nat, null, NUM, String, true, false, 
call/call/rec/finalize, C, parens`

### 5.2
Arithmetic
----------

The arithmetic operators of Céu are

```
    +      -      %      *      /      +      -
```

which correspond to *addition*, *subtraction*, *modulo (remainder)*, *multiplication*, *division*, *unary-plus*, and *unary-minus*.
<!-- *Note: Céu has no support for pointer arithmetic.* -->

### 5.3
Relational
----------

The relational operators of Céu are

```
    ==      !=      >      <      >=      <=
```

which correspond to *equal-to*, *not-equal-to*, *greater-than*, *less-than*, *greater-than-or-equal-to*, and *less-than-or-equal-to*.

Relational expressions evaluate to 1 (*true*) or 0 (*false*).

### 5.4
Logical
-------

The logical operators of Céu are

<pre><code>    <b>not      and      or</b>
</code></pre>

<!--
which correspond to *not*, *and*, *or*.
-->

### 5.5
Bitwise
-------

The bitwise operators of Céu are

```
    ~      &      |      ^      <<      >>
```

which correspond to *not*, *and*, *or*, *xor*, *left-shift*, and *right-shift*.

### 5.6
Vector indexing
---------------

Céu uses square brackets to index [vectors](#Vectors):

```
Index ::= Exp `[´ Exp `]´
```

The expression on the left side is expected to evaluate to a vector.

Vector indexes start at zero.
<!-- TODO: limites e recolocar "pointer arith" -->

### 5.7
References
----------

`TODO`

#### 5.7.1
### Aliasing

`TODO`

```
Alias ::= `&´ Exp
```

The operand to `&amp;` must be an [[#sec.exps.assignable|assignable 
expression]].

### 5.8
### Pointer referencing and dereferencing
-----------------------------------------

`TODO`

The operator `&amp;&amp;` returns the address of its operand, while the
operator `*` dereferences its pointer operand.

```
Address ::= `&&´ Exp
Deref   ::= `*´ Exp
```

The operand to `&amp;&amp;` must be an [[#sec.exps.assignable|assignable 
expression]].

### 5.9
Fields
------

`TODO (tags,fields)`

#### 5.9.1
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

#### 5.9.2
### Organisms

`TODO`

`TODO (index clash)`

### 5.10
Option
------

`TODO (?!)`

### 5.11
Type casting
------------

Céu uses parenthesis for type casting:

<pre><code>Cast ::= `(´ ID_type `)´
</code></pre>

### 5.12
Sizeof
------

A `sizeof` expression returns the size of a type or expression, in bytes:

<pre><code>Sizeof ::= <b>sizeof</b> `(´ (Type|Exp) `)´
</code></pre>

<!--
The expression is evaluated at compile time.
-->

### 5.13
Precedence
----------

Céu follows the same precedence of C operators:

<pre><code>    /* lowest priority */

    <b>or</b>

    <b>and</b>

    !=    ==    &lt;=    &gt;=    &lt;     &gt;

    |

    ^

    &

    &gt;&gt;    &lt;&lt;

    +     -

    *     /     %

    <b>not</b>    +    -    ~    *    &&    &    $$    $    (Type)

    ()    []    :    .    ?    !

    /* highest priority */
</code></pre>

### 5.14
Assignable expressions
----------------------

An assignable expression (also known as an *l-value*) can be a variable, vector index, pointer dereference, or struct access.
L-values are required in [[#sec.stmts.assignments|assignments]] and [[#sec.exps.pointers|references]].

Examples:

<pre><code><b>var int</b> a;
a = 1;

<b>var int</b>[2] v;
v[0] = 1;

<b>var int</b>&& p;
*p = 1;

<b>var</b> _mystruct s;
s.v = 1;

<b>var</b> _mystruct&& ps;
ps:v = 1;
</code></pre>

------------------------------------------------------------------------------

## 6
Static analysis
===============

`TODO (introduction)`

### 6.1
Types
-----

`TODO (weakly typed, like C)`

`TODO (index clash)`

### 6.2
Loops
-----

`TODO`

### 6.3
Finalization
------------

`TODO`

`TODO (index clash)`

### 6.4
Organisms references
--------------------

`TODO`

------------------------------------------------------------------------------

## 7
Environment
===========

As a reactive language, Céu depends on an external environment (the host 
platform) to provide input and output events to programs.
The environment is responsible for sensing the world and notifying Céu about changes.
The actual events vary from environment to environment, as well as the 
implementation for the notification mechanism (e.g. *polling* or 
*interrupt-driven*).

### 7.1
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

#### 7.1.1
### Types

`TODO`

`TODO (index clash)`

#### 7.1.2
### Functions

`TODO`

`TODO (index clash)`

#### 7.1.3
### Macros

`TODO`

#### 7.1.4
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


### 7.2
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

------------------------------------------------------------------------------

## 8
Errors
======

### 8.1
Pointer attributions (11xx)
---------------------------

#### 8.1.1
### 1101 : *wrong operator*

Use of the unsafe operator ":=" for non-pointer attributions.

Instead, use `=`.

Example:

<pre><code><b>var int</b> v := 1;

>>> ERR [1101] : file.ceu : line 1 : wrong operator
</code></pre>

#### 8.1.2
### 1102 : *attribution does not require "finalize"*

Use of `finalize` for non-pointer attributions.

Instead, do not use `finalize`.

Example:

<pre><code><b>var int</b> v;
<b>finalize</b>
    v = 1;
<b>with</b>
    <...>
<b>end</b>

>>> ERR [1102] : file.lua : line 3 : attribution does not require "finalize"
</code></pre>

#### 8.1.3
### 1103 : *wrong operator*

Use of the unsafe operator `:=` for constant pointer attributions.

Instead, use `=`.

Example:

<pre><code><b>var int</b> ptr := null;

>>> ERR [1103] : file.ceu : line 1 : wrong operator
</code></pre>

#### 8.1.4
### 1104 : *attribution does not require "finalize"*

Use of `finalize` for constant pointer attributions.

Instead, do not use `finalize`.

Example:

<pre><code><b>var int</b> ptr;
<b>finalize</b>
    ptr = null;
<b>with</b>
    <...>
<b>end</b>

>>> ERR [1104] : file.lua : line 3 : attribution does not require `finalize´
</code></pre>

#### 8.1.5
### 1105 : *destination pointer must be declared with the "[]" buffer modifier*

Use of normal pointer `*` to hold pointer to acquired resource.

Instead, use `[]`.

Example:

<pre><code><b>var int</b>* ptr = _malloc();

>>> ERR [1105] : file.ceu : line 1 : destination pointer must be declared with the `[]´ buffer modifier
</code></pre>

#### 8.1.6
### 1106 : *parameter must be "hold"*

Omit `@hold` annotation for function parameter held in the class or global.

Instead, annotate the parameter declaration with `@hold`.

Examples:

<pre><code><b>class</b> T <b>with</b>
    <b>var void</b>* ptr;
    <b>function</b> (<b>void</b>* v)=><b>void</b> f;
<b>do</b>
    <b>function</b> (<b>void</b>* v)=><b>void</b> f <b>do</b>
        ptr := v;
    <b>end</b>
<b>end</b>

>>> ERR [1106] : file.ceu : line 6 : parameter must be `hold´

/*****************************************************************************/

<b>native do</b>
    <b>void</b>* V;
<b>end</b>
<b>function</b> (<b>void</b>* v)=><b>void</b> f <b>do</b>
    _V := v;
<b>end</b>

>>> ERR [1106] : file.ceu : line 5 : parameter must be `hold´
</code></pre>

#### 8.1.7
### 1107 : *pointer access across "await"*

Access to pointer across an `await` statement.
The pointed data may go out of scope between reactions to events.

Instead, don't do it. :)

(Or check if the pointer is better represented as a buffer pointer (`[]`).)

Examples:

<pre><code><b>event int</b>* e;
<b>var int</b>* ptr = <b>await</b> e;
<b>await</b> e;     // while here, what "ptr" points may go out of scope
<b>escape</b> *ptr;

>>> ERR [1107] : file.ceu : line 4 : pointer access across `await´

/*****************************************************************************/

<b>var int</b>* ptr = <...>;
<b>par/and do</b>
    <b>await</b> 1s;   // while here, what "ptr" points may go out of scope
<b>with</b>
    <b>event int</b>* e;
    ptr = <b>await</b> e;
<b>end</b>
<b>escape</b> *ptr;

>>> ERR [1107] : file.ceu : line 8 : pointer access across `await´
</code></pre>

#### 8.1.8
### 1108 : *"finalize" inside constructor*

Use of `finalize` inside constructor.

Instead, move it to before the constructor or to inside the class.

Examples:

<pre><code><b>class</b> T <b>with</b>
    <b>var void</b>* ptr;
<b>do</b>
    <...>
<b>end</b>

<b>var</b> T t <b>with</b>
    <b>finalize</b>
        this.ptr = _malloc(10);
    <b>with</b>
        _free(this.ptr);
    <b>end</b>
<b>end</b>;

>>> ERR [1008] : file.ceu : line 7 : `finalize´ inside constructor

/*****************************************************************************/

<b>class</b> T <b>with</b>
    <b>var void</b>* ptr;
<b>do</b>
    <...>
<b>end</b>

<b>spawn</b> T <b>with</b>
    <b>finalize</b>
        this.ptr = _malloc(10);
    <b>with</b>
        _free(this.ptr);
    <b>end</b>
<b>end</b>;

>>> ERR [1008] : file.ceu : line 7 : `finalize´ inside constructor
</code></pre>

#### 8.1.9
### 1109 : *call requires "finalize"*

Call missing `finalize` clause.

Call passes a pointer.
Function may hold the pointer indefinitely.
Pointed data goes out of scope and yields a dangling pointer.

Instead, `finalize` the call.

Example:

<pre><code><b>var char</b>[255] buf;
_enqueue(buf);

>>> ERR [1009] : file.ceu : line 2 : call requires `finalize´'
</code></pre>

#### 8.1.10
### 1110 : *invalid "finalize"*

Call a function that does not require a `finalize`.

Instead, don't use it.

Example:

<pre><code>_f() <b>finalize with</b>
        <...>
     <b>end</b>;

>>> ERR [1010] : file.ceu : line 1 : invalid `finalize´
</code></pre>

------------------------------------------------------------------------------

## 9
Syntax
======

<pre><code>
Stmt ::= &lt;empty-string&gt;
      |  <b>nothing</b>
      |  <b>escape</b> Exp
      |  <b>return</b> [Exp]
      |  <b>break</b>
      |  <b>continue</b>

  /* Declarations */

      /* variables, organisms, pools, and internal events */
      | <b>var</b> Type ID_var [`=´ &lt;Assignment&gt;] { `,´ ID_var [`=´ &lt;Assignment&gt;] }
      | <b>var</b> Type ID_var <b>with</b>
            Block
        <b>end</b>
      | <b>pool</b> Type ID_var [`=´ &lt;Assignment&gt;] { `,´ ID_var [`=´ &lt;Assignment&gt;] }
      | <b>event</b> (Type | `(´ TypeList `)´) ID_var { `,´ ID_var }

      /* internal functions */
      | <b>function</b> [<b>@rec</b>] `(´ParList`)´ `=>´ Type ID_var
            [ `do´ Block `end´ ]

      /* external functions */
      | <b>output</b> [<b>@rec</b>] `(´ParList`)´ `=>´ Type ID_var ID_ext { `,´ ID_ext }
      | <b>input</b>  [<b>@rec</b>] `(´ParList`)´ `=>´ Type ID_var ID_ext { `,´ ID_ext }
            [ `do´ Block `end´ ]

      /* interrupts */
      | <b>interrupt</b> `[´ NUM `]´ [<b>@rec</b>]
            [ `do´ Block `end´ ]

      /* external events */
      | <b>output</b> (Type | `(´ TypeList `)´) ID_ext { `,´ ID_ext }
      | <b>input</b>  (Type | `(´ TypeList `)´) ID_ext { `,´ ID_ext }

      /* external requests */
      | <b>output/input</b> `[´ [Exp] `]´ `(´ParList`)´ `=>´ Type ID_ext { `,´ ID_ext }
      | <b>input/output</b> `[´ [Exp] `]´ `(´ParList`)´ `=>´ Type ID_ext { `,´ ID_ext }
            [ `do´ Block `end´ ]

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
              Dcls   ::= { (&lt;var&gt; | &lt;event-int&gt; | &lt;pool&gt; | &lt;function&gt; | DclImp) `;´ }
              DclImp ::= <b>interface</b> ID_cls { `,´ ID_cls }

      /* data types */
      | <b>data</b> ID_data <b>with</b>
            (Struct | Union)
        <b>end</b>
          <i>where</i>
              Struct ::= DclVar `;´ { DclVar `;´ }
              Union  ::= DclTag { <b>or</b> DclTag }
                  <i>where</i>
                      DclVar ::= <b>var</b> Type ID_var { `,´ ID_var }
                      DclTag ::= <b>tag</b> ID_tag <b>with</b>
                                     DclVar `;´ { DclVar `;´ }
                                 <b>end</b>

      /* C integration */
      | <b>native</b> [<b>@pure</b>|<b>@const</b>|<b>@nohold</b>|<b>@plain</b>] Nat_list
          <i>where</i>
              Nat_list  ::= (Nat_type|Nat_func|Nat_var) { `,` (Nat_type|Nat_func|Nat_var) }
              Nat_type  ::= ID_nat `=´ NUM
              Nat_func  ::= ID_nat `(´ `)´
              Nat_var   ::= ID_nat
      | (<b>native/pre</b> | <b>native</b>) <b>do</b>
            <i>&lt;C code definitions&gt;</i>
        <b>end</b>

      /* deterministic annotations */
      | <b>@safe</b> ID <b>with</b> ID { `,´ ID }

  /* Assignments */

      | (Exp | `(´VarList`)´) `=´
          /* <i>Assignment</i> */
          ( Exp
          | AssignableBlock
          | &lt;await&gt;
          | ( [ `(´ ] &lt;emit-ext&gt
                    | &lt;call-ext&gt;
                    | &lt;request-ext&gt;
              [ `)´ ] )
          | [ `new´ ] Data
          | &lt;traverse-loop&gt;
          | &lt;traverse-rec&gt;
          | Vector
          | &lt;lua&gt;
          | &lt;do-org&gt;
          | &lt;spawn&gt;
          | &lt;thread&gt;
          )
              <i>where</i>
                  Data ::= ID_data [`.´ ID_tag] `(´ List `)´
                  List ::= [ (Data|Exp) { `,´ (Data|Exp) } ]

                  Vector ::= Item { `..´ Item }
                  Item   ::= Exp | `[´ [ExpList] `]´

                  AssignableBlock ::= &lt;do-end&gt; | &lt;if-then-else&gt; | &lt;loop&gt; | &lt;every&gt; | &lt;par&gt;

  /* Function calls */

      /* internal calls */
      | [<b>call</b>|<b>call/rec</b>] Exp * `(´ [ExpList] `)´

      /* external calls */
      | (<b>call</b>+<b>call/rec</b>) ID_ext [ `=>´ (Exp | `(´ [ExpList] `)´)

  /* Event handling */

      /* internal/external await */
      | ( <b>await</b> ID_ext
        | <b>await</b> Exp
        | <b>await</b> (WCLOCKK|WCLOCKE)
        ) [ <b>until</b> Exp ]
      | <b>await</b> <b>FOREVER</b>

      /* internal/external emit */
      | <b>emit</b> Exp    [ `=>´ (Exp | `(´ [ExpList] `)´)
      | <b>emit</b> ID_ext [ `=>´ (Exp | `(´ [ExpList] `)´)
      | <b>emit</b> (WCLOCKK|WCLOCKE)

      /* external request */
      | <b>request</b> ID_ext [ `=>´ (Exp | `(´ [ExpList] `)´)

  /* Organism instantiation */

      /* do organism */
      | <b>do</b> ID_cls <b>with</b>
            Block
        <b>end</b>

      /* spawn */
      | <b>spawn</b> * ID_cls * [<b>in</b> Exp]
            [ <b>with</b> Block <b>end</b> ]

      /* kill */
      | <b>kill</b> * Exp * [ `=>´ Exp ]

  /* Flow control */

      /* explicit block */
      |  <b>do</b> Block <b>end</b>

      /* pre (top level) execution */
      | <b>pre do</b>
            Block
        <b>end</b>

      /* conditional */
      | <b>if</b> Exp <b>then</b>
            Block
        { <b>else/if</b> Exp <b>then</b>
            Block }
        [ <b>else</b>
            Block ]
        <b>end</b>

      /* loops */
      | <b>loop</b>[`/´ Exp] [ ID_var [<b>in</b> Exp] ] <b>do</b>
            Block
        <b>end</b>
      | <b>every</b> (Var | `(´VarList`)´) <b>in</b> (WCLOCKK|WCLOCKE|ID_ext|Exp) <b>do</b>
            Block
        <b>end</b>

      /* traverse */
      | <b>traverse</b> ID_var <b>in</b> (`[´ Exp `]´ | Exp)
            [ <b>with</b> Dcls <b>end</b> ]
            <b>do</b>
                Block
            <b>end</b>
      | <b>traverse</b>['/' NUM] Exp
            [ <b>with</b> Block <b>end</b> ]

      /* finalization */
      | <b>finalize</b> [&lt;assignment&gt;] <b>with</b>
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
      | <b>watching</b> [ (Var | `(´VarList`)´) <b>in</b> ] (WCLOCKK|WCLOCKE|ID_ext|Exp)
        <b>do</b>
            Block
        <b>end</b>

      /* pause */
      | <b>pause/if</b> Exp <b>do</b>
            Block
        <b>end</b>

      /* asynchronous execution */
      | (<b>async</b> | [<b>async/thread</b>]) [ `(´VarList`)´ ] <b>do</b>
            Block
        <b>end</b>

      /* synchronization */
      | <b>sync do</b>
            Block
        <b>end</b>
      | <b>atomic do</b>
            Block
        <b>end</b>

  /* C integration */

     | `{´ &lt;C code&gt; `}´

  /* Lua integration */

      | `[´ {`=´} `[´
            { <i>&lt;lua code&gt;</i> | `@´ Exp }
        `]´ {`=´} `]´

/* Block */

Block ::= { Stmt `;´ }

/* Identifiers */

ID       ::= &lt;a-z, A-Z, 0-9, _&gt; +
ID_var   ::= `_´ | ID    // beginning with a lowercase letter
ID_ext   ::= ID          // all in uppercase, not beginning with a digit
ID_cls   ::= ID          // beginning with an uppercase letter
ID_data  ::= ID          // beginning with an uppercase letter
ID_tag   ::= ID          // all in uppercase, not beginning with a digit
ID_field ::= ID          // not beginning with a digit
ID_nat   ::= ID          // beginning with an underscore
ID_type  ::= ( ID_nat | ID_cls | ID_data
             | <b>bool</b>  | <b>byte</b>  | <b>char</b>  | <b>f32</b>   | <b>f64</b>   |
             | <b>float</b> | <b>int</b>   | <b>s16</b>   | <b>s32</b>   | <b>s64</b>   |
             | <b>s8</b>    | <b>u16</b>   | <b>u32</b>   | <b>u64</b>   | <b>u8</b>    |
             | <b>uint</b>  | <b>void</b>  | <b>word</b> )

/* Types */

Type ::= ID_type ( `&&´ | `&´ | `?´ | `[´ [NUM] `]´ )

/* Lists */

TypeList ::= Type    { `,´ Type    }
ExpList  ::= Exp     { `,´ Exp     }
VarList  ::= ID_var  { `,´ ID_var  }
ParList  ::= ParItem { `,´ ParItem }
                <i>where</i>
                    ParItem ::= [<b>@hold</b>] Type [ID_var] 

/* Wall-clock values */

WCLOCKK ::= [NUM <b>h</b>] [NUM <b>min</b>] [NUM <b>s</b>] [NUM <b>ms</b>] [NUM <b>us</b>]
WCLOCKE ::= `(´ Exp `)´ (<b>h</b>|<b>min</b>|<b>s</b>|<b>ms</b>|<b>us</b>)

/* Expressions */

Exp ::= Prim
        |  (`$$´|`$´) Exp
        |  Exp (`?´|`!´)
        |  Exp `(´ [ExpList] `)´ [<b>finalize with</b> Block <b>end</b>]

Prim ::= `(´ Exp `)´
        |  ID_var | ID_nat
        |  <b>null</b> | NUM | String
        |  <b>true</b> | <b>false</b>
        |  (<b>call</b> | <b>call/rec</b>) Exp
        |  &lt;c-code&gt

/* Operator precedence */

    /* lowest priority */
    <b>or</b>
    <b>and</b>
    !=    ==    &lt;=    &gt;=    &lt;     &gt;
    |
    ^
    &
    &gt;&gt;    &lt;&lt;
    +     -
    *     /     %
    <b>not</b>    +    -    ~    *    &&    &    $$    $    (Type)
    ()    []    :    .    ?    !
    /* highest priority */

/* Other */

    // single-line comment

    /** nested
        /* multi-line */
        comments **/

    # preprocessor directive

</code></pre>

------------------------------------------------------------------------------

## 10
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
