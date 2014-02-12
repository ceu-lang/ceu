#line 1 "=== FILENAME ==="

=== OUT_H ===
#include "ceu_os.h"

#include <stdlib.h>
#ifdef CEU_DEBUG
#include <stdio.h>      /* fprintf */
#include <signal.h>     /* signal */
#endif
#ifdef CEU_RUNTESTS
#include <string.h>     /* memset */
#endif
#ifdef CEU_THREADS
#include <assert.h>
#endif

#ifdef CEU_THREADS
#   define CEU_ATOMIC(f)                                      \
            CEU_THREADS_MUTEX_LOCK(&_ceu_app->threads_mutex); \
                f                                             \
            CEU_THREADS_MUTEX_UNLOCK(&_ceu_app->threads_mutex);
#else
#   define CEU_ATOMIC(f) f
#endif

#ifdef CEU_NEWS
#include "ceu_pool.h"
#endif

#ifdef CEU_IFCS
#include <stddef.h>
/* TODO: === direto? */
#define CEU_NCLS       (=== CEU_NCLS ===)
#endif

/* native code */
=== NATIVE ===

/* class definitions */
=== CLSS_DEFS ===

/* goto labels */
enum {
=== LABELS_ENUM ===
};

typedef struct {
#ifdef CEU_IFCS
    s8    ifcs_clss[CEU_NCLS][=== IFCS_NIFCS ===];
            /* Does "cls" implements "ifc?"
             * (I*) ifc = (I*) cls;     // returns null if not
             * TODO(ram): bitfield
             */
    u16   ifcs_flds[CEU_NCLS][=== IFCS_NFLDS ===];
    u16   ifcs_evts[CEU_NCLS][=== IFCS_NEVTS ===];
    void* ifcs_funs[CEU_NCLS][=== IFCS_NFUNS ===];
#endif
#ifdef CEU_NEWS
    === POOLS_DCL ===
#endif
} _tceu_app;

/* TODO: remove from RAM */
static _tceu_app _CEU_APP = {
#ifdef CEU_IFCS
    {
=== IFCS_CLSS ===
    },
    {
=== IFCS_FLDS ===
    },
    {
=== IFCS_EVTS ===
    },
    {
=== IFCS_FUNS ===
    }
#endif
};

/**********************************************************************/

#ifndef CEU_OS
#ifdef CEU_DEBUG
tceu_app* CEU_APP_SIG = NULL;
static void ceu_segfault (int sig_num) {
#ifdef CEU_ORGS
    fprintf(stderr, "SEGFAULT on %p : %d\n", CEU_APP_SIG->lst.org, CEU_APP_SIG->lst.lbl);
#else
    fprintf(stderr, "SEGFAULT on %d\n", CEU_APP_SIG->lst.lbl);
#endif
    exit(0);
}
#endif
#endif

/**********************************************************************/

#ifdef CEU_THREADS
/* THREADS_C */
=== THREADS_C ===
#endif

/* FUNCTIONS_C */
=== FUNCTIONS_C ===

#ifdef CEU_OS
static tceu_evtp ceu_app_calls (tceu_app* _ceu_app, tceu_nevt evt, tceu_evtp param) {
    switch (evt) {
        /* STUBS */
        === STUBS ===
        /*
        case CEU_IN_XXX:
            return CEU_Main_XXX(param);
        */
        default:;
#ifdef CEU_DEBUG
            fprintf(stderr, "invalid call %d\n", evt);
#endif
    }
    return (tceu_evtp)NULL;
}
#endif

static int ceu_app_go (tceu_app* _ceu_app, tceu_go* _ceu_go)
{
#ifdef CEU_GOTO
_CEU_GOTO_:
#endif

#ifdef CEU_DEBUG
#ifndef CEU_OS
#ifdef CEU_ORGS
    _ceu_app->lst.org = _ceu_go->org;
#endif
    _ceu_app->lst.trl = _ceu_go->trl;
    _ceu_app->lst.lbl = _ceu_go->lbl;
#endif
#ifdef CEU_DEBUG_TRAILS
fprintf(stderr, "TRK: o.%p / l.%d\n", _ceu_go->org, _ceu_go->lbl);
#endif
#endif

#ifdef CEU_RUNTESTS
    ceu_stack_clr();
#endif

    switch (_ceu_go->lbl) {
        === CODE ===
    }
    return RET_HALT;    /* TODO: should never be reached anyways */
}

/* EXPORTED ENTRY POINTS */

int CEU_SIZE = sizeof(CEU_Main);

void ceu_app_init (tceu_app* app)
{
    app->seqno = 0;
#if defined(CEU_RET) || defined(CEU_OS)
    app->isAlive = 1;
#endif
#ifdef CEU_ASYNCS
    app->pendingAsyncs = 1;
#endif
#ifdef CEU_OS
    app->nxt = NULL;
#endif
#ifdef CEU_RET
    app->ret = 0;
#endif
#ifdef CEU_WCLOCKS
    app->wclk_late = 0;
    app->wclk_min = CEU_WCLOCK_INACTIVE;
    app->wclk_min_tmp = CEU_WCLOCK_INACTIVE;
#endif
#ifdef CEU_THREADS
    pthread_mutex_init(&app->threads_mutex, NULL);
    /*PTHREAD_COND_INITIALIZER,*/
    app->threads_n = 0;

    /* All code run atomically:
     * - the program is always locked as a whole
     * -    thread spawns will unlock => re-lock
     * - but program will still run to completion
     */
    CEU_THREADS_MUTEX_LOCK(&app->threads_mutex);
#endif
    app->code = &ceu_app_go;
#ifdef CEU_OS
    app->calls = &ceu_app_calls;
#endif

#ifdef CEU_NEWS
    === POOLS_INIT ===
#endif

#ifndef CEU_OS
#ifdef CEU_DEBUG
    CEU_APP_SIG = app;
    signal(SIGSEGV, ceu_segfault);
#endif
#endif

    ceu_org_init(app->data, CEU_NTRAILS, Class_Main, 0, NULL, 0);
    ceu_go(app, CEU_IN__INIT, (tceu_evtp)NULL);
}

#ifdef CEU_RUNTESTS
static void ceu_stack_clr () {
    int a[1000];
    memset(a, 0, sizeof(a));
}
#endif
