<title>Embedding Céu in C</title>
<meta http-equiv="Content-Type" content="text/html; charset=UTF-8"/>

# Embedding Céu in C

Suppose you have an existing `main.c` in which you want to embed an `app.ceu`.

Adapt your `main.c` with the steps as follows:

1. `#include` the generated `app.c` from your `app.ceu`.
2. define a `ceu_callback` to receive runtime information from `app.c`.
3. call `ceu_start` to start the boot reaction in `app.c`.
4. call `ceu_input` continuously to feed `app.c` with events.
5. call `ceu_stop` after `app.c` terminates.

## Generate `app.c` from `app.ceu`

This example in Céu emits `O` as soon as `I` occurs and terminates:

```
// app.ceu
input  int I;
output int O;
var int i = await I;
emit O(i);
escape 0;
```

This command generates an `app.c` from `app.ceu`:

```
$ ceu --pre --pre-input=app.ceu \
      --ceu                     \
      --env --env-types=types.h \
            --env-output=app.c
```

It expects the file `types.h` with the type definitions for your plaftorm,
e.g.:

https://github.com/ceu-lang/ceu/blob/master/env/types.h

## Embed `app.c` in `main.c`

The `main.c` typically contains a loop that reads events from the environment
continuously and forwards them to Céu.
It might also contain a callback to handle events in the other direction, such
as program termination, coming from the runtime of Céu.

This example illustrates the 5 embedding steps:

```
// main.c

/* STEP 1: includes the generated program */
#include "app.c"

int ceu_is_running;     // Detects program termination:
                        //  - initialized before `ceu_start`
                        //  - tested in the main loop
                        //  - set in `ceu_callback`

/* STEP 2: handles callbacks from Ceu */
tceu_callback_ret ceu_callback (int cmd, tceu_callback_arg p1, tceu_callback_arg p2) {
    tceu_callback_ret ret = { .is_handled=1 };
    switch (cmd) {
        case CEU_CALLBACK_TERMINATING:
            ceu_is_running = 0;
            break;
        case CEU_CALLBACK_OUTPUT:
            if (p1.num == CEU_OUTPUT_O) {
                printf("output O has been emitted with %d\n", p2.num);
            }
            break;
        default:
            ret.is_handled = 0;
    }
    return ret;
}

int main (void) {
    ceu_is_running = 1;

    /* STEP 3: starts Ceu */
    ceu_start();

    /* STEP 4: feeds Ceu with events */
    while (ceu_is_running) {
        ...
        if detects(CEU_INPUT_A) {
            int v = ...;
            ceu_input(CEU_INPUT_A, &v);
        }
    }

    /* STEP 5: stops Ceu */
    ceu_stop();
}
```
