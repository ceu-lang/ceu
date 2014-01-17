#line 1 "=== FILENAME ==="

=== DEFS ===

#ifdef CEU_IFCS
#include <stddef.h>
/* TODO: === direto? */
#define CEU_NCLS       (=== CEU_NCLS ===)
#endif

/*typedef === TCEU_NEVT === tceu_nevt;    // (x) number of events */
typedef u8 tceu_nevt;    /* (x) number of events */

/* TODO: lbl => unsigned */
typedef === TCEU_NLBL === tceu_nlbl;    /* (x) number of trails */

#ifdef CEU_IFCS
typedef === TCEU_NCLS === tceu_ncls;    /* (x) number of instances */
#endif

/* native code */
=== NATIVE ===

/* class definitions */
=== CLSS_DEFS ===

/* goto labels */
enum {
=== LABELS_ENUM ===
};

/* TODO: fields that need no initialization? */

static tceu_proc CEU = {
    0,
#ifdef CEU_WCLOCKS
    0, CEU_WCLOCK_INACTIVE, CEU_WCLOCK_INACTIVE,
#endif
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
    },
#endif
#ifdef CEU_DEBUG
    {},
#endif
#ifdef CEU_THREADS
    PTHREAD_MUTEX_INITIALIZER,
    PTHREAD_COND_INITIALIZER,
#endif
    {}                          /* TODO: o q ele gera? */
};

#endif  /* CEU_WCLOCKS */

/**********************************************************************/

#ifdef CEU_THREADS
=== THREADS_C ===
#endif

=== FUNCTIONS_C ===

enum {
    RET_HALT = 0,
    /*RET_GOTO,*/
#if defined(CEU_INTS) || defined(CEU_ORGS)
    RET_ORG,
#endif
#if defined(CEU_CLEAR) || defined(CEU_ORGS)
    RET_TRL
#endif
};

int ceu_go_one (tceu_go* _ceu_go)
{
#ifdef CEU_GOTO
_CEU_GOTO_:
#endif
#ifdef CEU_DEBUG
#ifdef CEU_ORGS
            CEU.lst.org = _ceu_go->org;
#endif
            CEU.lst.trl = _ceu_go->trl;
            CEU.lst.lbl = _ceu_go->lbl;
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
    /*return RET_HALT;*/
}
