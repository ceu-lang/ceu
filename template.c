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
#   define CEU_ATOMIC(f)                                      \
            CEU_THREADS_MUTEX_LOCK(&_ceu_app->threads_mutex); \
                f                                             \
            CEU_THREADS_MUTEX_UNLOCK(&_ceu_app->threads_mutex);
#else
#   define CEU_ATOMIC(f) f
#endif

#ifdef CEU_NEWS_POOL
#include "ceu_pool.h"
#endif

#ifdef CEU_IFCS
#include <stddef.h>
/* TODO: === direto? */
#define CEU_NCLS       (=== CEU_NCLS ===)
#endif

/* native code from the Main class */
=== NATIVE ===

/* adts definitions */
=== ADTS_DEFS ===

/* class definitions */
/* may use types defined above in "NATIVE" */
/* each class may define new native code that appear after its struct declaration */
=== CLSS_DEFS ===

/* goto labels */
enum {
=== LABELS_ENUM ===
};

typedef struct {
#ifdef CEU_IFCS
#ifdef CEU_OS_APP
#error remove from RAM!
#endif
    s8        ifcs_clss[CEU_NCLS][=== IFCS_NIFCS ===];
            /* Does "cls" implements "ifc?"
             * (I*) ifc = (I*) cls;     // returns null if not
             * TODO(ram): bitfield
             */

    u16       ifcs_flds[CEU_NCLS][=== IFCS_NFLDS ===];
    u16       ifcs_evts[CEU_NCLS][=== IFCS_NEVTS ===];
    void*     ifcs_funs[CEU_NCLS][=== IFCS_NFUNS ===];
    tceu_ntrl ifcs_trls[CEU_NCLS][=== IFCS_NTRLS ===];
#endif
} _tceu_app;

/* TODO: remove from RAM */
static _tceu_app _CEU_APP = {
#ifdef CEU_IFCS
#ifdef CEU_OS_APP
#error remove from RAM!
#endif
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
    },
    {
=== IFCS_TRLS ===
    }
#endif
};

/**********************************************************************/

#ifndef CEU_OS_APP
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

#ifdef CEU_RUNTESTS
static void ceu_stack_clr () {
    int a[1000];
    memset(a, 0, sizeof(a));
}
#endif

/**********************************************************************/

#ifdef CEU_ORGS
=== PRES_C ===
#endif

#ifdef CEU_ORGS
=== CONSTRS_C ===
#endif

#ifdef CEU_THREADS
/* THREADS_C */
=== THREADS_C ===
#endif

/* FUNCTIONS_C */
=== FUNCTIONS_C ===

#ifdef CEU_OS_APP
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
        ceu_out_log(0, "invalid call\n");
#endif
    }
    return NULL;
}
#endif

static int ceu_app_go (tceu_app* _ceu_app , tceu_go* _ceu_go) {
    int _CEU_LBL = _STK.trl->lbl;
#ifdef CEU_GOTO
_CEU_GOTO_:
#endif

#ifdef CEU_DEBUG
#ifndef CEU_OS_APP
#ifdef CEU_ORGS
    _ceu_app->lst.org = _STK_ORG;
#endif
    _ceu_app->lst.trl = _STK.trl;
    _ceu_app->lst.lbl = _CEU_LBL;
#endif
#ifdef CEU_DEBUG_TRAILS
#ifndef CEU_OS_APP
fprintf(stderr, "OK : lbl=%d : org=%p\n", _CEU_LBL, _STK_ORG);
#endif
#endif
#endif

#ifdef CEU_RUNTESTS
    ceu_stack_clr();
#endif

    switch (_CEU_LBL) {
        === CODE ===
    }
#ifdef CEU_DEBUG
    ceu_out_assert(0);
#endif
    return RET_HALT;    /* TODO: should never be reached anyways */
}

#ifdef CEU_OS_APP
static __attribute__((noinline))  __attribute__((noclone))
#endif
void
ceu_app_init (tceu_app* _ceu_app)
{
    _ceu_app->seqno = 0;
#if defined(CEU_RET) || defined(CEU_OS_APP)
    _ceu_app->isAlive = 1;
#endif
#ifdef CEU_ASYNCS
    _ceu_app->pendingAsyncs = 1;
#endif
#ifdef CEU_RET
    _ceu_app->ret = 0;
#endif
#ifdef CEU_WCLOCKS
    _ceu_app->wclk_late = 0;
    _ceu_app->wclk_min_set = CEU_WCLOCK_INACTIVE;
    _ceu_app->wclk_min_cmp = CEU_WCLOCK_INACTIVE;
#ifdef CEU_TIMEMACHINE
    _ceu_app->wclk_late_ = 0;
    _ceu_app->wclk_min_set_ = CEU_WCLOCK_INACTIVE;
    _ceu_app->wclk_min_cmp_ = CEU_WCLOCK_INACTIVE;
#endif
#endif
#ifdef CEU_THREADS
    pthread_mutex_init(&_ceu_app->threads_mutex, NULL);
    /*PTHREAD_COND_INITIALIZER,*/
    _ceu_app->threads_n = 0;

    /* All code run atomically:
     * - the program is always locked as a whole
     * -    thread spawns will unlock => re-lock
     * - but program will still run to completion
     */
    CEU_THREADS_MUTEX_LOCK(&_ceu_app->threads_mutex);
#endif

#ifdef CEU_OS_APP

#ifdef __AVR
    _ceu_app->code  = (__typeof__(ceu_app_go)*)    (((word)_ceu_app->addr>>1) + &ceu_app_go);
    _ceu_app->calls = (__typeof__(ceu_app_calls)*) (((word)_ceu_app->addr>>1) + &ceu_app_calls);
#else
    _ceu_app->code  = (__typeof__(ceu_app_go)*)    (&ceu_app_go);
    _ceu_app->calls = (__typeof__(ceu_app_calls)*) (&ceu_app_calls);
#endif

#else   /* !CEU_OS_APP */

    _ceu_app->code  = (__typeof__(ceu_app_go)*)    (&ceu_app_go);

#endif  /* CEU_OS_APP */

#ifndef CEU_OS_APP
#ifdef CEU_DEBUG
    CEU_APP_SIG = _ceu_app;
    signal(SIGSEGV, ceu_segfault);
#endif
#endif

    ceu_out_org(_ceu_app, _ceu_app->data, CEU_NTRAILS, Class_Main, 0,
#ifdef CEU_NEWS
                0,
#endif
                NULL, 0);

#ifdef CEU_LUA
    ceu_luaL_newstate(_ceu_app->lua);
    /* TODO: lua_close(CEU_L); */
    ceu_out_assert(_ceu_app->lua != NULL);
    ceu_luaL_openlibs(_ceu_app->lua);
    ceu_lua_atpanic(_ceu_app->lua, ceu_lua_atpanic_f);    /* TODO: CEU_OS */
#endif

    ceu_out_go(_ceu_app, CEU_IN__INIT, NULL);
}

/* EXPORTED ENTRY POINT
 * CEU_EXPORT is put in a separate section ".export".
 * "gcc-ld" should place it at 0x00, before ".text".
 */

#ifdef CEU_OS_APP
__attribute__ ((section (".export")))
void CEU_EXPORT (uint* size, tceu_init** init
#ifdef CEU_OS_LUAIFC
                , char** luaifc
#endif
) {
    *size = sizeof(CEU_Main);
    *init = (tceu_init*) &ceu_app_init;
#ifdef CEU_OS_LUAIFC
    *luaifc = (=== APP_LUAIFC ===);
#endif
}
#endif
