## C API

The environment phase of the compiler packs the converted Céu program and
additional files in the order as follows:

1. type declarations    (option `--env-types`)
2. thread declarations  (option `--env-threads`, optional)
3. a callback prototype (fixed, see below)
4. Céu program          (option `--env-ceu`, auto generated)
5. main program         (option `--env-main`)

The Céu program uses standardized types and calls, which must be previously
mapped from the host environment in steps `1-3`.

The main program depends on declarations from the Céu program.

### Types

The type declarations must map the types of the host environment to all
[primitive types](../types/#primitives) of Céu.

Example:

```c
#include <stdint.h>
#include <sys/types.h>

typedef unsigned char bool;
typedef unsigned char byte;
typedef unsigned int  uint;

typedef ssize_t  ssize;
typedef size_t   usize;

typedef int8_t    s8;
typedef int16_t  s16;
typedef int32_t  s32;
typedef int64_t  s64;

typedef uint8_t   u8;
typedef uint16_t u16;
typedef uint32_t u32;
typedef uint64_t u64;

typedef float    real;
typedef float    r32;
typedef double   r64;
```

### Threads

If the user program uses [threads](../statements/#thread) and the option
`--ceu-features-thread` is set, the host environment must provide declarations
for types and functions expected by Céu.

Example:

```c
#include <pthread.h>
#include <unistd.h>
#define CEU_THREADS_T               pthread_t
#define CEU_THREADS_MUTEX_T         pthread_mutex_t
#define CEU_THREADS_CREATE(t,f,p)   pthread_create(t,NULL,f,p)
#define CEU_THREADS_CANCEL(t)       ceu_dbg_assert(pthread_cancel(t)==0)
#define CEU_THREADS_JOIN_TRY(t)     0
#define CEU_THREADS_JOIN(t)         ceu_dbg_assert(pthread_join(t,NULL)==0)
#define CEU_THREADS_MUTEX_LOCK(m)   ceu_dbg_assert(pthread_mutex_lock(m)==0)
#define CEU_THREADS_MUTEX_UNLOCK(m) ceu_dbg_assert(pthread_mutex_unlock(m)==0)
#define CEU_THREADS_SLEEP(us)       usleep(us)
#define CEU_THREADS_PROTOTYPE(f,p)  void* f (p)
#define CEU_THREADS_RETURN(v)       return v
```

`TODO: describe them`

### Céu

The converted program generates types and constants required by the main
program.

#### External Events

For each [external input and output event](../statements/#external-events)
`<ID>` defined in Céu, the compiler generates corresponding declarations as
follows:

1. An enumeration item `CEU_INPUT_<ID>` that univocally identifies the event.
2. A `define` macro `_CEU_INPUT_<ID>_`.
3. A struct type `tceu_input_<ID>` with fields corresponding to the types in
   of the event payload.

Example:

Céu program:

```ceu
input (int,u8&&) MY_EVT;
```

Converted program:

```c
enum {
    ...
    CEU_INPUT_MY_EVT,
    ...
};

#define _CEU_INPUT_MY_EVT_                                                         

typedef struct tceu_input_MY_EVT {                                               
    int _1;                                                                     
    u8* _2;                                                                     
} tceu_input_MY_EVT;
```

#### Data

The global `CEU_APP` of type `tceu_app` holds all program memory and runtime
information:

```
typedef struct tceu_app {
    bool end_ok;                /* if the program terminated */
    int  end_val;               /* final value of the program */
    bool async_pending;         /* if there is a pending "async" to execute */
    ...
    tceu_code_mem_ROOT root;    /* all Céu program memory */
} tceu_app;

static tceu_app CEU_APP;
```

The struct `tceu_code_mem_ROOT` holds the whole memory of the Céu program.
The identifiers for global variables are preserved, making them directly
accessible.

Example:

```ceu
var int x = 10;
```

```
typedef struct tceu_code_mem_ROOT {                                             
    ...
    int  x;                                                                         
} tceu_code_mem_ROOT;    
```

### Main

The main program provides the entry point for the host platform (i.e., the
`main` function), implementing the event loop that senses the world and
notifies the Céu program about changes.

The main program interfaces with the Céu program in both directions:

- Through direct calls, in the direction `main -> Céu`, typically when new input is available.
- Through callbacks, in the direction `Céu -> main`, typically when new output is available.

#### Calls

The functions that follow are called by the main program to command the
execution of Céu programs:

- `void ceu_start (tceu_callback* cb, int argc, char* argv[])`

    Initializes and starts the program.
    Should be called once.
    Expects a callback to register for further notifications.
    Also receives the program arguments in `argc` and `argv`.

- `void ceu_stop  (void)`

    Finalizes the program.
    Should be called once.

- `void ceu_input (tceu_nevt id, void* params)`

    Notifies the program about an input `id` with a payload `params`.
    Should be called whenever the event loop senses a change.
    The call to `ceu_input(CEU_INPUT__ASYNC, NULL)` makes
    [asynchronous blocks](../statements/#asynchronous-block) to execute a step.

- `int ceu_loop (tceu_callback* cb, int argc, char* argv[])`

    Implements a simple loop encapsulating `ceu_start`, `ceu_input`, and
    `ceu_stop`.
    On each loop iteration, make a `CEU_CALLBACK_STEP` callback and generates
    a `CEU_INPUT__ASYNC` input.
    Should be called once.
    Returns the final value of the program.

- `void ceu_callback_register (tceu_callback* cb)`

    Registers a new callback.

#### Callbacks

The Céu program makes callbacks to the main program in specific situations:

```c
enum {
    CEU_CALLBACK_START,                 /* once in the beginning of `ceu_start`             */
    CEU_CALLBACK_STOP,                  /* once in the end of `ceu_stop`                    */
    CEU_CALLBACK_STEP,                  /* on every iteration of `ceu_loop`                 */
    CEU_CALLBACK_ABORT,                 /* whenever an error occurs                         */
    CEU_CALLBACK_LOG,                   /* on error and debugging messages                  */
    CEU_CALLBACK_TERMINATING,           /* once after executing the last statement          */
    CEU_CALLBACK_ASYNC_PENDING,         /* whenever there's a pending "async" block         */
    CEU_CALLBACK_THREAD_TERMINATING,    /* whenever a thread terminates                     */
    CEU_CALLBACK_ISR_ENABLE,            /* whenever interrupts should be enabled/disabled   */
    CEU_CALLBACK_ISR_ATTACH,            /* whenever an "async/isr" starts                   */
    CEU_CALLBACK_ISR_DETACH,            /* whenever an "async/isr" is aborted               */
    CEU_CALLBACK_ISR_EMIT,              /* whenever an "async/isr" emits an innput          */
    CEU_CALLBACK_WCLOCK_MIN,            /* whenever a next minimum timer is required        */
    CEU_CALLBACK_WCLOCK_DT,             /* whenever the elapsed time is requested           */
    CEU_CALLBACK_OUTPUT,                /* whenever an output is emitted                    */
    CEU_CALLBACK_REALLOC,               /* whenever memory is allocated/deallocated         */
};
```

`TODO: payloads`

Céu invokes the registered callbacks in reverse register order, one after the
other, stopping when a callback returns that it handled the request.

A callback is composed of a function handler and a pointer to the next
callback:

```
typedef struct tceu_callback {
    tceu_callback_f       f;
    struct tceu_callback* nxt;
} tceu_callback;
```

A handler expects a request identifier with two arguments, as well as runtime
trace information (e.g., file name and line number of the request):

```
typedef int (*tceu_callback_f) (int, tceu_callback_val, tceu_callback_val, tceu_trace);
```

An argument has one of the following types:

```
typedef union tceu_callback_val {
    void* ptr;
    s32   num;
    usize size;
} tceu_callback_val;
```

A handler returns whether it handled the request or not (return type `int`).

Depending on the request, the handler must also assign a return value to the
global `ceu_callback_ret`:

```
static tceu_callback_val ceu_callback_ret;
```

<!--
WCLOCK_DT uses `CEU_WCLOCK_INACTIVE`
- `CEU_FEATURES_ISR`
- `CEU_FEATURES_LUA`
- `CEU_FEATURES_THREAD`

            tceu_evt_id_params evt;

    static volatile tceu_isr isrs[_VECTORS_SIZE];
-->

#### Example

Suppose the environment supports the events that follow:

```
input  int I;
output int O;
```

The `main.c` implements an event loop to sense occurrences of `I` and a
callback to handle occurrences of `O`:

```
#include "types.h"      // as illustrated above in "Types"

int ceu_is_running;     // detects program termination

int ceu_callback_main (int cmd, tceu_callback_val p1, tceu_callback_val p2, tceu_trace trace)
{
    int is_handled = 0;
    switch (cmd) {
        case CEU_CALLBACK_TERMINATING:
            ceu_is_running = 0;
            is_handled = 1;
            break;
        case CEU_CALLBACK_OUTPUT:
            if (p1.num == CEU_OUTPUT_O) {
                printf("output O has been emitted with %d\n", p2.num);
                is_handled = 1;
            }
            break;
    }
    return ret;
}

int main (int argc, char* argv[])
{
    ceu_is_running = 1;
    tceu_callback cb = { &ceu_callback_main, NULL };
    ceu_start(&cb, argc, argv);

    while (ceu_is_running) {
        if (<call-to-detect-if-A-occurred>()) {
            int v = <argument-to-A>;
            ceu_input(CEU_INPUT_A, &v);
        }
        ceu_input(CEU_INPUT__ASYNC, NULL);
    }

    ceu_stop();
}
```
