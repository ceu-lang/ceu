## Synchronous Execution Model

Céu is grounded on a precise definition of *logical time* (as opposed to
*physical* or *wall-clock time*) as a discrete sequence of external input
events:
a sequence because only a single input event is handled at a logical time; 
discrete because reactions to events are guaranteed to execute in bounded
physical time (see [Bounded Execution](#bounded-execution)).

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

The synchronous execution model of Céu is based on the hypothesis that reaction
chains run *infinitely faster* in comparison to the rate of external events.
A reaction chain is the set of computations that execute when an external 
event occurs.
Conceptually, a program takes no time on step 2 and is always idle on step 3.
In practice, if a new external input event occurs while a reaction chain is 
running (step 2), it is enqueued to run in the next reaction.
When multiple trails are active at a logical time (i.e. awaking from the same 
event), Céu schedules them in the order they appear in the program text.
This policy is somewhat arbitrary, but provides a priority scheme for trails, 
and also ensures deterministic and reproducible execution for programs.
At any time, at most one trail is executing.

The program and diagram below illustrate the behavior of the scheduler of Céu:

```ceu
 1:  input void A, B, C;
 2:  par/and do           // A, B, and C are external input events
 3:      // trail 1
 4:      <...>            // <...> represents non-awaiting statements
 5:      await A;
 6:      <...>
 7:  with
 8:      // trail 2
 9:      <...>
10:      await B;
11:      <...>
12:  with
13:      // trail 3
14:      <...>
15:      await A;
16:      <...>
17:      await B;
18:      par/and do
19:          // trail 3
20:          <...>
21:      with
22:          // trail 4
23:          <...>
24:      end
25:  end
```

![](images/010-reaction.png)

The program starts in the boot reaction and forks into three trails.
Respecting the lexical order of declaration for the trails, they are scheduled
as follows (*t0* in the diagram):

- *trail-1* executes up to the `await A` (line 5);
- *trail-2*, up to the `await B` (line 10);
- *trail-3*, up to `await A` (line 15).

As no other trails are pending, the reaction chain terminates and the scheduler 
remains idle until the event `A` occurs (*t1* in the diagram):

- *trail-1* awakes, executes and terminates (line 6);
- *trail-2* remains suspended, as it is not awaiting `A`.
- *trail-3* executes up to `await B` (line 17).

During the reaction *t1*, new instances of events `A`, `B`, and `C` occur and
are enqueued to be handled in the reactions in sequence.
As `A` happened first, it is used in the next reaction.
However, no trails are awaiting it, so an empty reaction chain takes place 
(*t2* in the diagram).
The next reaction dequeues the event `B` (*t3* in the diagram):

- *trail-2* awakes, executes and terminates;
- *trail-3* splits in two and they both terminate immediately.

A `par/and` rejoins after all trails terminate.
With all trails terminated, the program also terminates and does not react to 
the pending event `C`.

Note that each step in the logical time line (*t0*, *t1*, etc.) is identified 
by the unique event it handles.
Inside a reaction, trails only react to that identifying event (or remain 
suspended).

<!--
A reaction chain may also contain emissions and reactions to internal events, 
which are presented in Section~\ref{sec.ceu.ints}.
-->
