#line 0 "=== FILENAME ==="
=== DEFS ===

#include <string.h>
#include <limits.h>

#ifdef CEU_DEBUG
#include <assert.h>
#include <signal.h>
#include <stdlib.h>
#endif

#ifdef CEU_NEWS
#include <stdlib.h>
#endif

#ifdef CEU_NEWS
=== POOL_C ===
#endif

#ifdef __cplusplus
#define CEU_WCLOCK_INACTIVE 0x7fffffffL     /* TODO */
#else
#define CEU_WCLOCK_INACTIVE INT32_MAX
#endif
#define CEU_WCLOCK_EXPIRED (CEU_WCLOCK_INACTIVE-1)

#define CEU_NMEM       (=== CEU_NMEM ===)
#define CEU_NTRAILS    (=== CEU_NTRAILS ===)

#ifdef CEU_IFCS
#include <stddef.h>
/* TODO: === direto? */
#define CEU_NCLS       (=== CEU_NCLS ===)
#endif

/* Macros that can be defined:
 * ceu_out_pending() (sync?)
 * ceu_out_wclock(dt)
 * ceu_out_event(id, len, data)
 * ceu_out_async(more?);
 * ceu_out_end(v)
*/

/*typedef === TCEU_NEVT === tceu_nevt;    // (x) number of events */
typedef u8 tceu_nevt;    /* (x) number of events */

/* TODO: lbl => unsigned */
typedef === TCEU_NLBL === tceu_nlbl;    /* (x) number of trails */

#ifdef CEU_IFCS
typedef === TCEU_NCLS === tceu_ncls;    /* (x) number of instances */
#endif

/* align all structs 1 byte
// TODO: verify defaults for microcontrollers
//#pragma pack(push)
//#pragma pack(1)
*/

#define CEU_MAX_STACK   255     /* TODO */

typedef union tceu_trl {
    tceu_nevt evt;
    struct {                    /* TODO(ram): bitfields */
        tceu_nevt evt1;
        tceu_nlbl lbl;
        u8        seqno;        /* TODO(ram): 2 bits is enough */
    };
    struct {                    /* TODO(ram): bitfields */
        tceu_nevt evt2;
        tceu_nlbl lbl2;
        u8        stk;
    };
#ifdef CEU_ORGS
    struct {
        tceu_nevt evt3;
        struct tceu_org* lnks;  /* TODO(ram): bad for alignment */
    };
#endif
} tceu_trl;

typedef union {
    int   v;
    void* ptr;
    s32   dt;
} tceu_evtp;

/* TODO(speed): hold nxt trl to run */
typedef struct {
    tceu_evtp evtp;
#ifdef CEU_INTS
#ifdef CEU_ORGS
    void*     evto;
#endif
#endif
    tceu_nevt evt;
} tceu_stk;

typedef struct {
#ifdef CEU_ORGS
    void*     org;
#endif
    tceu_trl* trl;
    tceu_nlbl lbl;
} tceu_lst;

/* simulates an org prv/nxt */
typedef struct {
    struct tceu_org* prv;   /* TODO(ram): lnks[0] does not use */
    struct tceu_org* nxt;   /*      prv, n, lnk                  */
    u8 n;                   /* use for ands/fins                 */
    u8 lnk;
} tceu_lnk;

typedef struct tceu_org
{
#ifdef CEU_ORGS
    struct tceu_org* prv;   /* linked list for the scheduler */
    struct tceu_org* nxt;
    u8 n;                   /* number of trails (TODO: to metadata) */

#ifdef CEU_IFCS
    tceu_ncls cls;          /* class id */
#endif

#ifdef CEU_NEWS
    u8 isDyn:  1;           /* created w/ new or spawn? */
    u8 toFree: 1;           /* free on termination? */
#endif
#endif  /* CEU_ORGS */

    tceu_trl trls[0];       /* first trail */

} tceu_org;

=== CLSS_DEFS ===

enum {
=== LABELS_ENUM ===
};

typedef struct {
#ifdef CEU_WCLOCKS
    int         wclk_late;
    s32         wclk_min;
    s32         wclk_min_tmp;
#endif

#ifdef CEU_IFCS
/* TODO: fun */
    u16   ifcs_flds[CEU_NCLS][=== IFCS_NFLDS ===];
    u16   ifcs_evts[CEU_NCLS][=== IFCS_NEVTS ===];
    void* ifcs_funs[CEU_NCLS][=== IFCS_NFUNS ===];
#endif

#ifdef CEU_DEBUG
    tceu_lst    lst; /* segfault printf */
#endif

    CEU_Main    mem;
} tceu;

/* TODO: fields that need no initialization? */

tceu CEU = {
#ifdef CEU_WCLOCKS
    0, CEU_WCLOCK_INACTIVE, CEU_WCLOCK_INACTIVE,
#endif
#ifdef CEU_IFCS
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
    {}                          /* TODO: o q ele gera? */
};

/*#pragma pack(pop) */

/**********************************************************************/

void ceu_go (int _ceu_evt, tceu_evtp _ceu_evtp);

/**********************************************************************/

#ifdef CEU_WCLOCKS

void ceu_wclocks_min (s32 dt, int out) {
    if (CEU.wclk_min > dt) {
        CEU.wclk_min = dt;
#ifdef ceu_out_wclock
        if (out)
            ceu_out_wclock(dt);
#endif
    }
}

int ceu_wclocks_expired (s32* t, s32 dt) {
    if (*t>CEU.wclk_min_tmp || *t>dt) {
        *t -= dt;
        ceu_wclocks_min(*t, 0);
        return 0;
    }
    return 1;
}

void ceu_trails_set_wclock (s32* t, s32 dt) {
    s32 dt_ = dt - CEU.wclk_late;
    *t = dt_;
    ceu_wclocks_min(dt_, 1);
}

#endif  /* CEU_WCLOCKS */

/**********************************************************************/

#ifdef CEU_NEWS
#ifdef CEU_RUNTESTS
/* TODO */
int _ceu_dyns_ = 0;
#endif
#endif

/**********************************************************************/

#ifdef CEU_DEBUG
void ceu_segfault (int sig_num) {
#ifdef CEU_ORGS
    fprintf(stderr, "SEGFAULT on %p : %d\n", CEU.lst.org, CEU.lst.lbl);
#else
    fprintf(stderr, "SEGFAULT on %d\n", CEU.lst.lbl);
#endif
    exit(0);
}
#endif

/**********************************************************************/

void ceu_org_init (tceu_org* org, int n, int lbl, int seqno,
                   tceu_org* par_org, int par_trl)
{
    /* { evt=0, seqno=0, lbl=0 } for all trails */
#ifdef CEU_ORGS
    org->n = n;
#endif
    memset(&org->trls, 0, n*sizeof(tceu_trl));

    /* org.trls[0] == org.blk.trails[1] */
    org->trls[0].evt   = CEU_IN__STK;
    org->trls[0].lbl   = lbl;
    org->trls[0].seqno = seqno;

#ifdef CEU_ORGS
    if (par_org == NULL)
        return;             /* main class */

    /* re-link */
    {
        tceu_org* lst = &par_org->trls[par_trl].lnks[1];
        lst->prv->nxt = org;
        org->prv = lst->prv;
        org->nxt = lst;
        lst->prv = org;
    }
#endif  /* CEU_ORGS */
}
#ifndef CEU_ORGS
#define ceu_org_init(a,b,c,d,e,f) ceu_org_init(a,b,c,d,NULL,0)
#endif

/**********************************************************************/

#ifdef CEU_PSES
void ceu_pause (tceu_trl* trl, tceu_trl* trlF, int psed) {
    do {
        if (psed) {
            if (trl->evt == CEU_IN__ORG)
                trl->evt = CEU_IN__ORG_PSED;
        } else {
            if (trl->evt == CEU_IN__ORG_PSED)
                trl->evt = CEU_IN__ORG;
        }
        if ( trl->evt == CEU_IN__ORG
        ||   trl->evt == CEU_IN__ORG_PSED ) {
            trl += 2;       /* jump [fst|lst] */
        }
    } while (++trl <= trlF);

#ifdef ceu_out_wclock
    if (!psed) {
        ceu_out_wclock(0);  /* TODO: recalculate MIN clock */
                            /*       between trl => trlF   */
    }
#endif
}
#endif

/**********************************************************************/

void ceu_go_init ()
{
#ifdef CEU_DEBUG
    signal(SIGSEGV, ceu_segfault);
#endif
#ifdef CEU_NEWS
    === CLSS_INIT ===
#endif
    ceu_org_init((tceu_org*)&CEU.mem, CEU_NTRAILS, Class_Main, 0, NULL, 0);
    {
        tceu_evtp p;
        p.ptr = NULL;
        ceu_go(CEU_IN__INIT, p);
    }
}

/* TODO: ret */

#ifdef CEU_EXTS
void ceu_go_event (int id, void* data)
{
#ifdef CEU_DEBUG_TRAILS
    fprintf(stderr, "====== %d\n", id);
#endif
    {
        tceu_evtp p;
        p.ptr = data;
        ceu_go(id, p);
    }
}
#endif

#ifdef CEU_ASYNCS
void ceu_go_async ()
{
#ifdef CEU_DEBUG_TRAILS
    fprintf(stderr, "====== ASYNC\n");
#endif
    {
        tceu_evtp p;
        p.ptr = NULL;
        ceu_go(CEU_IN__ASYNC, p);
    }
}
#endif

void ceu_go_wclock (s32 dt)
{
#ifdef CEU_WCLOCKS

#ifdef CEU_DEBUG_TRAILS
    fprintf(stderr, "====== WCLOCK\n");
#endif

    if (CEU.wclk_min <= dt)
        CEU.wclk_late = dt - CEU.wclk_min;   /* how much late the wclock is */

    CEU.wclk_min_tmp = CEU.wclk_min;
    CEU.wclk_min     = CEU_WCLOCK_INACTIVE;

    {
        tceu_evtp p;
        p.dt = dt;
        ceu_go(CEU_IN__WCLOCK, p);
    }

#ifdef ceu_out_wclock
    if (CEU.wclk_min != CEU_WCLOCK_INACTIVE)
        ceu_out_wclock(CEU.wclk_min);   /* only signal after all */
#endif

    CEU.wclk_late = 0;

#endif   /* CEU_WCLOCKS */

    return;
}

void ceu_go_all (int* ret_end)
{
    ceu_go_init();
    if (ret_end!=NULL && *ret_end) goto _CEU_END_;

#ifdef CEU_IN_START
    ceu_go_event(CEU_IN_START, NULL);
    if (ret_end!=NULL && *ret_end) goto _CEU_END_;
#endif

#ifdef CEU_ASYNCS
    for (;;) {
        ceu_go_async();
        if (ret_end!=NULL && *ret_end) goto _CEU_END_;
    }
#endif

_CEU_END_:;
#ifdef CEU_NEWS
#ifdef CEU_RUNTESTS
    #define CEU_MAX_DYNS 100
/*fprintf(stderr, "XXX %d\n", _ceu_dyns_); */
    assert(_ceu_dyns_ == 0);
#endif
#endif
}

#ifdef CEU_RUNTESTS
void ceu_stack_clr () {
    int a[1000];
    memset(a, 0, sizeof(a));
}
#endif

void ceu_go (int _ceu_evt, tceu_evtp _ceu_evtp)
{
#ifdef CEU_ORGS
    tceu_org* _ceu_evto;       /* org that emitted current event */
#endif

#ifdef CEU_ORGS
    /* TODO: CEU_ORGS is calculable // CEU_NEWS isn't (255?) */
    tceu_stk _CEU_STK[CEU_MAX_STACK];
#else
    tceu_stk _CEU_STK[CEU_NTRAILS];
#endif

    /* global seqno: incremented on every reaction
     * awaiting trails matches only if trl->seqno < seqno,
     * i.e., previously awaiting the event
     */
    static u8 _ceu_seqno = 0;

    /* current traversal state */
    int       _ceu_stki = 0;   /* points to next */
    tceu_trl* _ceu_trl;
    tceu_nlbl _ceu_lbl;
#ifdef CEU_ORGS
    tceu_org* _ceu_org;
#else
    #define   _ceu_org ((tceu_org*)&CEU.mem)
#endif

    /* traversals may be bounded to org/trl
     * default (NULL) is to traverse everything */
#ifdef CEU_CLEAR
    void* _ceu_stop = NULL;     /* stop at this trl/org */
#endif

    _ceu_seqno++;

    for (;;)    /* STACK */
    {
#ifdef CEU_ORGS
        /* TODO: don't restart if kill is impossible (hold trl on stk) */
        _ceu_org = (tceu_org*) &CEU.mem;    /* on pop(), always restart */
#endif
#if defined(CEU_INTS) || defined(CEU_ORGS)
_CEU_CALL_:
#endif
        /* restart from org->trls[0] */
        _ceu_trl = &_ceu_org->trls[0];

#if defined(CEU_CLEAR) || defined(CEU_ORGS)
_CEU_CALLTRL_:  /* restart from org->trls[i] */
#endif

#ifdef CEU_DEBUG_TRAILS
#ifdef CEU_ORGS
fprintf(stderr, "GO[%d]: evt=%d stk=%d org=%p [%d/%p]\n", _ceu_seqno,
                _ceu_evt, _ceu_stki, _ceu_org, _ceu_org->n, _ceu_org->trls);
#else
fprintf(stderr, "GO[%d]: evt=%d stk=%d [%d]\n", _ceu_seqno,
                _ceu_evt, _ceu_stki, CEU_NTRAILS);
#endif
#endif
        for (;;) /* TRL // TODO(speed): only range of trails that apply */
        {        /* (e.g. events that do not escape an org) */
#ifdef CEU_CLEAR
            if (_ceu_trl == _ceu_stop) {    /* bounded trail traversal? */
                _ceu_stop = NULL;           /* back to default */
                break;                      /* pop stack */
            }
#endif

            /* _ceu_org has been traversed to the end? */
            if (_ceu_trl ==
                &_ceu_org->trls[
#ifdef CEU_ORGS
                    _ceu_org->n
#else
                    CEU_NTRAILS
#endif
                ])
            {
                if (_ceu_org == (tceu_org*) &CEU.mem) {
                    break;  /* pop stack */
                }

#ifdef CEU_ORGS
                {
                    /* hold next org/trl */
                    /* TODO(speed): jump LST */
                    tceu_org* _org = _ceu_org->nxt;
                    tceu_trl* _trl = &_org->trls [
                                        (_ceu_org->n == 0) ?
                                         ((tceu_lnk*)_ceu_org)->lnk : 0
                                      ];

#ifdef CEU_NEWS
                    /* org has been cleared to the end? */
                    if ( _ceu_evt  == CEU_IN__CLEAR
                    &&   _ceu_org->isDyn
                    &&   _ceu_org->n != 0 )  /* TODO: avoids LST */
                    {
                        /* re-link PRV <-> NXT */
                        _ceu_org->prv->nxt = _ceu_org->nxt;
                        _ceu_org->nxt->prv = _ceu_org->prv;

                        /* FREE */
                        {
                        /* TODO: check if needed? (freed manually?) */
                        /*fprintf(stderr, "FREE: %p\n", _ceu_org);*/
                            === CLSS_FREE ===
                            /* else */
                            {
                                free(_ceu_org);
                            }
#ifdef CEU_RUNTESTS
                            _ceu_dyns_--;
#endif
                        }

                        /* explicit free(me) or end of spawn */
                        if (_ceu_stop == _ceu_org)
                            break;  /* pop stack */
                    }
#endif  /* CEU_NEWS */

                    _ceu_org = _org;
                    _ceu_trl = _trl;
/*fprintf(stderr, "UP[%p] %p %p\n", trl+1, _ceu_org _ceu_trl);*/
                    goto _CEU_CALLTRL_;
                }
#endif  /* CEU_ORGS */
            }

            /* continue traversing CUR org */
            {
#ifdef CEU_DEBUG_TRAILS
#ifdef CEU_ORGS
if (_ceu_trl->evt==CEU_IN__ORG)
    fprintf(stderr, "\tTRY [%p] : evt=%d org=?\n",
                    _ceu_trl, _ceu_trl->evt);
else
#endif
fprintf(stderr, "\tTRY [%p] : evt=%d seqno=%d lbl=%d\n",
                    _ceu_trl, _ceu_trl->evt, _ceu_trl->seqno, _ceu_trl->lbl);
#endif

                /* jump into linked orgs */
#ifdef CEU_ORGS
                if ( (_ceu_trl->evt == CEU_IN__ORG)
#ifdef CEU_PSES
                  || (_ceu_trl->evt==CEU_IN__ORG_PSED && _ceu_evt==CEU_IN__CLEAR)
#endif
                   )
                {
                    /* TODO(speed): jump LST */
                    _ceu_org = _ceu_trl->lnks[0].nxt;
                    if (_ceu_evt == CEU_IN__CLEAR) {
                        _ceu_trl->evt = CEU_IN__NONE;
                    }
                    goto _CEU_CALL_;
                }
#endif /* CEU_ORGS */

                switch (_ceu_evt)
                {
                    /* "clear" event */
                    case CEU_IN__CLEAR:
                        if (_ceu_trl->evt == CEU_IN__CLEAR)
                            goto _CEU_GO_;
                        _ceu_trl->evt = CEU_IN__NONE;
                        goto _CEU_NEXT_;
                }

                /* a continuation (STK) will always appear before a
                 * matched event in the same stack level
                 */
                if ( ! (
                    (_ceu_trl->evt==CEU_IN__STK && _ceu_trl->stk==_ceu_stki)
                ||
                    (_ceu_trl->evt==_ceu_evt    && _ceu_trl->seqno!=_ceu_seqno)
                    /* _ceu_evt!=CEU_IN__STK (never generated): comp is safe */
                    /* we use `!=´ intead of `<´ due to u8 overflow */
                ) ) {
                    goto _CEU_NEXT_;
                }
_CEU_GO_:
                /* execute this trail */
                _ceu_trl->evt   = CEU_IN__NONE;
                _ceu_trl->seqno = _ceu_seqno;   /* don't awake again */
                _ceu_lbl = _ceu_trl->lbl;
            }

#ifdef CEU_GOTO
_CEU_GOTO_:
#endif
#ifdef CEU_DEBUG
#ifdef CEU_ORG
    CEU.lst.org = _ceu_org;
#endif
    CEU.lst.trl = _ceu_trl;
    CEU.lst.lbl = _ceu_lbl;
#ifdef CEU_DEBUG_TRAILS
#ifdef CEU_ORGS
fprintf(stderr, "TRK: o.%p / l.%d\n", _ceu_org, _ceu_lbl);
#else
fprintf(stderr, "TRK: l.%d\n", _ceu_lbl);
#endif
#endif
#endif

#ifdef CEU_RUNTESTS
        ceu_stack_clr();
#endif

            switch (_ceu_lbl) {
                === CODE ===
            }
_CEU_NEXT_:
            /* _ceu_trl!=CEU_IN__ORG guaranteed here */
            if (_ceu_trl->evt!=CEU_IN__STK && _ceu_trl->seqno!=_ceu_seqno)
                _ceu_trl->seqno = _ceu_seqno-1;   /* keeps the gap tight */
            _ceu_trl++;
        }

        if (_ceu_stki == 0) {
            break;      /* reaction has terminated */
        }
        _ceu_evtp = _CEU_STK[--_ceu_stki].evtp;
#ifdef CEU_INTS
#ifdef CEU_ORGS
        _ceu_evto = _CEU_STK[  _ceu_stki].evto;
#endif
#endif
        _ceu_evt  = _CEU_STK[  _ceu_stki].evt;
    }
}
