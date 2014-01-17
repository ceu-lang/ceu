#include "ceu_os.h"

#include <stdlib.h>
#ifdef CEU_DEBUG
#include <stdio.h>      /* fprintf */
#endif
#ifdef CEU_RUNTESTS
#include <string.h>     /* memset */
#endif
#ifdef CEU_THREADS
#include <assert.h>
#endif

#ifdef CEU_THREADS
#   define CEU_ATOMIC(f)                                      \
            CEU_THREADS_MUTEX_LOCK(&CEU_APP.threads_mutex);   \
                f                                             \
            CEU_THREADS_MUTEX_UNLOCK(&CEU_APP.threads_mutex);
#else
#   define CEU_ATOMIC(f) f
#endif

#ifdef CEU_NEWS
#include "ceu_pool.h"
#endif

#line 1 "=== FILENAME ==="

=== DEFS ===

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

static int      ceu_app_go   (int* _ceu_ret, tceu_go* _ceu_go);
static void     ceu_app_init (void);
static CEU_Main ceu_app_data;

/* TODO: fields that need no initialization? */

/* TODO: static */
tceu_app CEU_APP = {
    0,
#ifdef CEU_WCLOCKS
    0, CEU_WCLOCK_INACTIVE, CEU_WCLOCK_INACTIVE,
#endif
#ifdef CEU_DEBUG
    {},
#endif
#ifdef CEU_THREADS
    PTHREAD_MUTEX_INITIALIZER,
    PTHREAD_COND_INITIALIZER,
#endif
    &ceu_app_go,
    &ceu_app_init,
    (tceu_org*) &ceu_app_data
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

#ifdef CEU_THREADS
=== THREADS_C ===
#endif

=== FUNCTIONS_C ===

static void ceu_app_init ()
{
#ifdef CEU_NEWS
    === POOLS_INIT ===
#endif
    ceu_org_init(CEU_APP.data, CEU_NTRAILS, Class_Main, 0, NULL, 0);
}

#ifdef CEU_RUNTESTS
static void ceu_stack_clr () {
    int a[1000];
    memset(a, 0, sizeof(a));
}
#endif

static int ceu_app_go (int* _ceu_ret, tceu_go* _ceu_go)
{
#ifdef CEU_GOTO
_CEU_GOTO_:
#endif
#ifdef CEU_DEBUG
#ifdef CEU_ORGS
    CEU_APP.lst.org = _ceu_go->org;
#endif
    CEU_APP.lst.trl = _ceu_go->trl;
    CEU_APP.lst.lbl = _ceu_go->lbl;
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
