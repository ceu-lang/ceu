#line 1 "=== FILENAME ==="

=== OUT_H ===
#include "ceu_os.h"

#include <stdlib.h>
#ifdef CEU_DEBUG
#include <stdio.h>      /* printf */
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

#ifdef CEU_VECTOR
#include "ceu_vector.h"
#endif

#ifdef CEU_IFCS
#include <stddef.h>
/* TODO: === direto? */
#define CEU_NCLS       (=== CEU_NCLS ===)
#endif

/* native code from the Main class */
=== NATIVE ===

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
#endif
} _tceu_app;

/* TODO: remove from RAM */
#ifdef CEU_IFCS
static _tceu_app _CEU_APP = {
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
    }
};
#endif

=== TOPS_C ===

/**********************************************************************/

#ifndef CEU_OS_APP
#ifdef CEU_DEBUG
tceu_app* CEU_APP_SIG = NULL;
static void ceu_segfault (int sig_num) {
#ifdef CEU_ORGS
    printf("SEGFAULT on %p : %d\n", CEU_APP_SIG->lst.org, CEU_APP_SIG->lst.lbl);
#else
    printf("SEGFAULT on %d\n", CEU_APP_SIG->lst.lbl);
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
static void* ceu_app_calls (tceu_app* _ceu_app, tceu_nevt evt, void* param) {
    switch (evt) {
        /* STUBS */
        === STUBS ===
        /*
        case CEU_IN_XXX:
            return CEU_Main_XXX(param);
        */
        default:;
#ifdef CEU_DEBUG
        ceu_out_log(0, (long)"invalid call\n");
#endif
    }
    return NULL;
}
#endif

static void ceu_app_go (tceu_app* _ceu_app, tceu_evt* _ceu_evt, tceu_org* _ceu_org, tceu_trl* _ceu_trl,
                        tceu_stk* _ceu_stk)
{
    tceu_nlbl _ceu_lbl = _ceu_trl->lbl;

#ifdef CEU_GOTO
_CEU_GOTO_:
#endif

#ifdef CEU_DEBUG
#ifndef CEU_OS_APP
#ifdef CEU_ORGS
    _ceu_app->lst.org = _ceu_org;
#endif
    _ceu_app->lst.trl = _ceu_trl;
    _ceu_app->lst.lbl = _ceu_lbl;
#endif
#ifdef CEU_DEBUG_TRAILS
#ifndef CEU_OS_APP
printf("OK : lbl=%d : org=%p\n", _ceu_lbl, _ceu_org);
#endif
#endif
#endif

#ifdef CEU_RUNTESTS
    ceu_stack_clr();
#endif

    switch (_ceu_lbl) {
        === CODE ===
    }
#ifdef CEU_DEBUG
    ceu_out_assert_msg(0, "no return");
#endif
}

#ifdef CEU_OS_APP
static __attribute__((noinline))  __attribute__((noclone))
#endif
void
ceu_app_init (tceu_app* app)
{
    app->seqno = 0;
#if defined(CEU_RET) || defined(CEU_OS_APP)
    app->isAlive = 1;
#endif
#ifdef CEU_ASYNCS
    app->pendingAsyncs = 1;
#endif
#if defined(CEU_ORGS_NEWS_MALLOC) && defined(CEU_ORGS_AWAIT)
    app->dont_emit_kill = 0;
#endif
#ifdef CEU_RET
    app->ret = 0;
#endif
#ifdef CEU_ORGS_NEWS_MALLOC
    app->tofree = NULL;
#endif
#ifdef CEU_WCLOCKS
    app->wclk_late = 0;
    app->wclk_min_set = CEU_WCLOCK_INACTIVE;
    app->wclk_min_cmp = CEU_WCLOCK_INACTIVE;
#ifdef CEU_TIMEMACHINE
    app->wclk_late_ = 0;
    app->wclk_min_set_ = CEU_WCLOCK_INACTIVE;
    app->wclk_min_cmp_ = CEU_WCLOCK_INACTIVE;
#endif
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

    === TOPS_INIT ===

#ifdef CEU_OS_APP

#ifdef __AVR
    app->code  = (__typeof__(ceu_app_go)*)    (((word)app->addr>>1) + &ceu_app_go);
    app->calls = (__typeof__(ceu_app_calls)*) (((word)app->addr>>1) + &ceu_app_calls);
#else
    app->code  = (__typeof__(ceu_app_go)*)    (&ceu_app_go);
    app->calls = (__typeof__(ceu_app_calls)*) (&ceu_app_calls);
#endif

#else   /* !CEU_OS_APP */

    app->code  = (__typeof__(ceu_app_go)*)    (&ceu_app_go);

#endif  /* CEU_OS_APP */

#ifndef CEU_OS_APP
#ifdef CEU_DEBUG
    CEU_APP_SIG = app;
    signal(SIGSEGV, ceu_segfault);
#endif
#endif

    ceu_out_org_init(app, app->data, CEU_NTRAILS, Class_Main,
                     0, 0,
                     NULL, 0);

#ifdef CEU_LUA
    ceu_luaL_newstate(app->lua);
    ceu_out_assert(app->lua != NULL);
    ceu_luaL_openlibs(app->lua);
    ceu_lua_atpanic(app->lua, ceu_lua_atpanic_f);    /* TODO: CEU_OS */
#endif

    app->data->trls[0].evt = CEU_IN__INIT;
    app->data->trls[0].seqno = 0;
    ceu_sys_go(app, CEU_IN__INIT, NULL);
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
