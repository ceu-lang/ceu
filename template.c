/*#line 0 "=== FILENAME ==="*/
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
=== MEMB_H ===
=== MEMB_C ===
#endif

#ifdef __cplusplus
#define CEU_WCLOCK_INACTIVE 0x7fffffffL     /* TODO */
#else
#define CEU_WCLOCK_INACTIVE INT32_MAX
#endif
#define CEU_WCLOCK_EXPIRED (CEU_WCLOCK_INACTIVE-1)

#ifdef CEU_ORGS
#define CEU_CUR         ((tceu_org*) _ceu_cur_.org)
#define CEU_CUR_(tp)    ((tp*)_ceu_cur_.org)
#else
#define CEU_CUR         ((tceu_org*) &CEU.mem)
#define CEU_CUR_(tp)    (&CEU.mem)
#endif

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

 /* TODO (-RAM): bitfields */
typedef union tceu_trl {
    tceu_nevt evt;
    struct {
        tceu_nevt evt1;
        tceu_nlbl lbl;
        u8        stk;
    };
#ifdef CEU_ORGS
    struct {
        tceu_nevt evt2;
        u8        idx;      /* for linked list */
    };
    struct tceu_org* org;   /* for fst|lst */
#endif
} tceu_trl;

typedef struct {
    union {
        void*   ptr;        /* exts/ints */
        int     v;          /* exts/ints */
        s32     dt;         /* wclocks */
    };
} tceu_param;

typedef struct {
    tceu_param  param;
    tceu_nevt   id;
#ifdef CEU_INTS
#ifdef CEU_ORGS
    void*       org;
#endif
#endif
} tceu_evt;

typedef struct {
#ifdef CEU_ORGS
    void*       org;
#endif
    tceu_trl* trl;
    tceu_nlbl lbl;
} tceu_lst;

/* TODO: remove */
#define ceu_evt_param_ptr(a)    \
    tceu_param p;           \
    p.ptr = a;

#define ceu_evt_param_v(a)      \
    tceu_param p;           \
    p.v = a;

#define ceu_evt_param_dt(a)     \
    tceu_param p;           \
    p.dt = a;

typedef struct tceu_org
{
#ifdef CEU_ORGS

/* TODO: one pointer? */
    struct tceu_org* prv;   /* linked list for the scheduler */
    struct tceu_org* nxt;

#ifdef CEU_IFCS
    tceu_ncls cls;      /* class id */
#endif

#ifdef CEU_NEWS
    u8 isDyn:  1;       /* created w/ new or spawn? */
    u8 toFree: 1;       /* free on termination? */
#endif

    u8       n;         /* number of trails (TODO: to metadata) */
#endif
    tceu_trl trls[0];   /* first trail */

} tceu_org;

/*
=== HOST ===
*/

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

void ceu_go (int __ceu_id, tceu_param* __ceu_p);

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

void ceu_org_init (tceu_org* org, int n, int lbl,
                   tceu_org* par_org, int par_trl)
{
    /* { evt=0, stk=0, lbl=0 } for all trails */
#ifdef CEU_ORGS
    org->n = n;
#endif
    memset(&org->trls, 0, n*sizeof(tceu_trl));

    /* org.trls[0] == org.blk.trails[1] */
    org->trls[0].evt = CEU_IN__ANY;
    org->trls[0].lbl = lbl;
    org->trls[0].stk = CEU_MAX_STACK;

#ifdef CEU_ORGS
    if (par_org == NULL)
        return;             /* main class */

    /* re-link */
    {
        tceu_trl* fst = &par_org->trls[par_trl+1];
        tceu_trl* lst = &par_org->trls[par_trl+2];

        /* I am the only one */
        if (fst->org == NULL) {
/*fprintf(stderr, "... 1st: %p[%d] <=%p\n", org, n, par_org);*/
            /* par points to me */
            par_org->trls[par_trl].evt = CEU_IN__ORG_PAR;
            fst->org = org;
            /* I point to par */
            org->prv = par_org;     /* org->nxt below */

        } else {
            /* lst now points to me */
            lst->org->nxt = org;
            /*lst->org->trls[lst->org->n-1].idx = 0;*/
            lst->org->trls[lst->org->n-1].evt =
                (fst->org == lst->org) ? /* I am the 2nd? */
                    CEU_IN__ORG_FST :
                    CEU_IN__ORG_MID;
/*fprintf(stderr, "... 2nd?: %p %d [%p]\n", org, (fst->org==lst->org), * par_org);*/
            /* I point to lst */
            org->prv = lst->org;
        }

        lst->org = org;
        org->nxt = par_org;
        org->trls[org->n-1].evt = CEU_IN__ORG_LST;
        org->trls[org->n-1].idx = par_trl+3; /* point to parent
                                                jump [XXX|fst|lst] */
    }
#endif
}
#ifndef CEU_ORGS
#define ceu_org_init(a,b,c,d,e) ceu_org_init(a,b,c,NULL,0)
#endif

/**********************************************************************/

#ifdef CEU_PSES
void ceu_pause (tceu_trl* trl, tceu_trl* trlF, int psed) {
    do {
/*fprintf(stderr, "antes [%p] %d %p\n", trl, trl->evt, (trl+1)->org);*/
        if (psed) {
            if (trl->evt == CEU_IN__ORG_PAR)
                trl->evt = CEU_IN__ORG_PAR_PSED;
        } else {
            if (trl->evt == CEU_IN__ORG_PAR_PSED)
                trl->evt = CEU_IN__ORG_PAR;
        }
/*fprintf(stderr, "depois [%p] %d %p\n", trl, trl->evt, (trl+1)->org);*/
        if ( trl->evt == CEU_IN__ORG_PAR
        ||   trl->evt == CEU_IN__ORG_PAR_PSED ) {
            trl += 2;       /* jump [fst|lst] */
        }
    } while (++trl <= trlF);

    if (!psed) {
        ceu_go_wclock(0);   /* TODO: hack (recalculates MIN clock) */
                            /* TODO: CEU_IN__WCLOCK=0 de trl => trlF */
    }
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
    ceu_org_init((tceu_org*)&CEU.mem, CEU_NTRAILS, Class_Main, NULL, 0);
    ceu_go(CEU_IN__INIT, NULL);
}

/* TODO: ret */

#ifdef CEU_EXTS
void ceu_go_event (int id, void* data)
{
    ceu_evt_param_ptr(data);
#ifdef CEU_DEBUG_TRAILS
    fprintf(stderr, "====== %d\n", id);
#endif
    ceu_go(id, &p);
}
#endif

#ifdef CEU_ASYNCS
void ceu_go_async ()
{
#ifdef CEU_DEBUG_TRAILS
    fprintf(stderr, "====== ASYNC\n");
#endif
    ceu_go(CEU_IN__ASYNC, NULL);
}
#endif

void ceu_go_wclock (s32 dt)
{
#ifdef CEU_WCLOCKS

    ceu_evt_param_dt(dt);

#ifdef CEU_DEBUG_TRAILS
    fprintf(stderr, "====== WCLOCK\n");
#endif

    if (CEU.wclk_min <= dt)
        CEU.wclk_late = dt - CEU.wclk_min;   /* how much late the wclock is */

    CEU.wclk_min_tmp = CEU.wclk_min;
    CEU.wclk_min     = CEU_WCLOCK_INACTIVE;

    ceu_go(CEU_IN__WCLOCK, &p);

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

void ceu_go (int __ceu_id, tceu_param* __ceu_p)
{
#ifdef CEU_ORGS
    tceu_evt _CEU_STK_[CEU_MAX_STACK];  /* TODO: 255 */
#else
    tceu_evt _CEU_STK_[CEU_NTRAILS+1];
#endif
    int      _ceu_stk_ = 1;   /* points to next (TODO: 0=unused) */

    tceu_evt _ceu_evt_;       /* current stack entry */
    tceu_lst _ceu_cur_;       /* current listener */

    /* they are always set when _ceu_evt_.id=CEU_IN__CLR
     * no need to protect them with NULLs
     * however assignments avoid warning on nescc
     */
#ifdef CEU_CLEAR
#ifdef CEU_ORGS
    void* _ceu_clr_org_ = NULL;      /* stop at this org */
#endif
    tceu_trl* _ceu_clr_trlF_ = NULL; /*      at this trl */
#endif

    /* ceu_go_init(): nobody awaiting, jump reset */
    if (__ceu_id == CEU_IN__INIT) {
        _ceu_evt_.id = CEU_IN__INIT;
    }

    /* ceu_go_xxxx(): */
    else {
        /* first set all awaiting: trl.stk=CEU_MAX_STACK */
        _ceu_evt_.id = CEU_IN__ANY;

        /* then stack external event */
        if (__ceu_p)
            _CEU_STK_[_ceu_stk_].param = *__ceu_p;
        _CEU_STK_[_ceu_stk_].id  = __ceu_id;
        _ceu_stk_++;
    }

    for (;;)    /* STACK */
    {
#ifdef CEU_ORGS
        /* TODO: don't restart if kill is impossible (hold trl on stk) */
        _ceu_cur_.org = &CEU.mem;    /* on pop(), always restart */
#endif
_CEU_CALL_:
        /* restart from org->trls[0] */
        _ceu_cur_.trl = &CEU_CUR->trls[0];

_CEU_CALLTRL_:  /* restart from org->trls[i] */

#ifdef CEU_DEBUG_TRAILS
#ifdef CEU_ORGS
fprintf(stderr, "GO: evt=%d stk=%d org=%p [%d]\n", _ceu_evt_.id, _ceu_stk_,
                CEU_CUR, CEU_CUR->n);
#else
fprintf(stderr, "GO: evt=%d stk=%d [%d]\n", _ceu_evt_.id, _ceu_stk_, CEU_NTRAILS);
#endif
#endif
        for (;;)    /* TRL */
        {
            /* check if all trails have been traversed */
            if (
#ifdef CEU_ORGS
                _ceu_cur_.org == (tceu_org*)&CEU.mem &&
#endif
                _ceu_cur_.trl == &CEU_CUR->trls[CEU_NTRAILS]
            ) {
                break;
            }

#ifdef CEU_CLEAR
            /* clr is bounded to _trlF_ (set by code.lua) */
            if (
                (_ceu_evt_.id == CEU_IN__CLR)
#ifdef CEU_ORGS
            &&  (_ceu_clr_org_ == CEU_CUR)
#endif
            &&  (_ceu_clr_trlF_ == _ceu_cur_.trl)
            ) {
/*
 * they are always set when _ceu_evt_.id=CEU_IN__CLR
 * no need to protect them
#ifdef CEU_ORGS
                _ceu_clr_org_  = NULL;
#endif
                _ceu_clr_trlF_ = NULL;
*/
                break;
            }
#endif

            /* continue traversing CUR org */
            /* TODO: rewrite these if's / fatorate */
            {
                /* TODO: macro? */
                tceu_trl* trl = _ceu_cur_.trl;

#ifdef CEU_DEBUG_TRAILS
#ifdef CEU_ORGS
if (trl->evt==CEU_IN__ORG_PAR)
    fprintf(stderr, "\tTRY [%p] : evt=%d org=%p\n",
                    trl, trl->evt, (trl+1)->org);
else
#endif
fprintf(stderr, "\tTRY [%p] : evt=%d stk=%d lbl=%d\n",
                    trl, trl->evt, trl->stk, trl->lbl);
#endif

#ifdef CEU_ORGS
                /* jump into linked orgs */
                if ( (trl->evt == CEU_IN__ORG_PAR)
#ifdef CEU_PSES
                  || (trl->evt==CEU_IN__ORG_PAR_PSED && _ceu_evt_.id==CEU_IN__CLR)
#endif
                   )
                {
                    _ceu_cur_.org = (trl+1)->org;
                    if (_ceu_evt_.id == CEU_IN__CLR) {
                        trl->evt     = CEU_IN__NONE;
/*
                        (trl+1)->evt = CEU_IN__NONE;
                        (trl+2)->evt = CEU_IN__NONE;
*/
                    }
                    goto _CEU_CALL_;
                }

#ifdef CEU_PSES
/* TODO */
                if (trl->evt == CEU_IN__ORG_PAR_PSED) {
/*fprintf(stderr, "JUMP\n");*/
                    _ceu_cur_.trl += 2;
                    goto _CEU_NEXT_;
                }
#endif

                /* jump into nxt org */
                if (trl->evt>=CEU_IN__ORG_FST && trl->evt<=CEU_IN__ORG_LST)
                {
                    tceu_org* __org = CEU_CUR->nxt;
                    tceu_trl* __trl = &__org->trls[
                                        (trl->evt==CEU_IN__ORG_LST) ?
                                            trl->idx : 0
                                      ];
#ifdef CEU_NEWS
                    /* org has been cleared to the end? */
                    if ( _ceu_evt_.id  == CEU_IN__CLR
                    &&   _ceu_clr_org_ != CEU_CUR
                    &&   CEU_CUR->isDyn )
                    {
                        /* re-link PRV <-> NXT */
                        tceu_org* nxt = CEU_CUR->nxt;
                        tceu_org* prv = CEU_CUR->prv;

                        /* I was the only one */
                        if (prv == nxt) {
/*fprintf(stderr,"was only: %p %p (%d/%d)\n", CEU_CUR, 
                            &nxt->trls[_ceu_cur_.trl->idx-3],
                            trl->idx,trl->evt);*/
                            nxt->trls[ _ceu_cur_.trl->idx-3 ].evt = CEU_IN__NONE;
                            nxt->trls[ _ceu_cur_.trl->idx-2 ].org = NULL; /* fst */
                            nxt->trls[ _ceu_cur_.trl->idx-1 ].org = NULL; /* lst */
                        } else

                        /* I was the last one */
                        if (_ceu_cur_.trl->evt == CEU_IN__ORG_LST) {
/*fprintf(stderr,"was last: %p -> %p\n", prv, CEU_CUR);*/
/*fprintf(stderr,"was last: %p -> %p\n", prv, nxt);*/
                            prv->nxt = nxt;
                            prv->trls[prv->n-1].evt = CEU_IN__ORG_LST;
                            prv->trls[prv->n-1].idx = _ceu_cur_.trl->idx;
                            nxt->trls[ _ceu_cur_.trl->idx-1 ].org = prv; /* lst */
                        } else

                        /* I was the first one */
                        if (_ceu_cur_.trl->evt == CEU_IN__ORG_FST) {
/*fprintf(stderr,"was first: %p\n", CEU_CUR);*/
/*fprintf(stderr,"...[%p]: %p=>%p\n", &prv->trls[_ceu_cur_.trl->idx-3],
                                     CEU_CUR, nxt);*/
                            nxt->prv = prv;
/* TODO */
                            if (nxt->trls[nxt->n-1].evt != CEU_IN__ORG_LST)
                                nxt->trls[nxt->n-1].evt = CEU_IN__ORG_FST;
                            prv->trls[ _ceu_cur_.trl->idx-2 ].org = nxt; /* fst */
                        }

                        /* I was in the middle */
                        else {
/*fprintf(stderr,"was mid\n");*/
                            prv->nxt = nxt;
                            nxt->prv = prv;
                        }

                        /* FREE */
                        {
                            /* TODO: check if needed? (freed manually?) */
                            /*fprintf(stderr, "FREE: %p\n", CEU_CUR);*/
                            === CLSS_FREE ===
                            /* else */
                                free(CEU_CUR);
#ifdef CEU_RUNTESTS
                            _ceu_dyns_--;
#endif
                        }

                        /* explicit free(me): return */
                        if (_ceu_clr_org_ == NULL)
                            break;
                    }
#endif  /* CEU_NEWS */

                    _ceu_cur_.org = __org;
                    _ceu_cur_.trl = __trl;
/*fprintf(stderr, "UP[%p] %p %p\n", trl+1, _ceu_cur_.org, _ceu_cur_.trl);*/
                    /* no need to clear if IN__CLR */
                    goto _CEU_CALLTRL_;
                }
#endif /* CEU_ORGS */

                {
                    int run =
                        ( (trl->evt == CEU_IN__ANY) || (trl->evt == _ceu_evt_.id) )
                     &&
                        ( (trl->stk == _ceu_stk_)   || (trl->stk == CEU_MAX_STACK) );

                    /* clear trl only if i'll run or in a "clear" */
                    if ( run || (_ceu_evt_.id == CEU_IN__CLR) ) {
                        /* this test is necessary due to `HACK_1´ */
                        if (trl->evt != CEU_IN__NONE) {
                            trl->evt = CEU_IN__NONE;
                            trl->stk = 0;   /* `HACK_1´ */
                        }
                    } else

                    /* reset event */
                    if (_ceu_evt_.id == CEU_IN__ANY) {
/* TODO: this test should not be required!!! */
                        if (trl->evt != CEU_IN__NONE)
                            trl->stk = CEU_MAX_STACK;
                    }

                    if (! run)
                        goto _CEU_NEXT_;
                }

                /* finally, execute this trail */
                _ceu_cur_.lbl = trl->lbl;
            }

_CEU_GOTO_:
#ifdef CEU_DEBUG
    CEU.lst = _ceu_cur_;
#ifdef CEU_DEBUG_TRAILS
#ifdef CEU_ORGS
fprintf(stderr, "TRK: o.%p / l.%d\n", CEU_CUR, _ceu_cur_.lbl);
#else
fprintf(stderr, "TRK: l.%d\n", _ceu_cur_.lbl);
#endif
#endif
#endif

#ifdef CEU_RUNTESTS
        ceu_stack_clr();
#endif

            switch (_ceu_cur_.lbl) {
                === CODE ===
            }
_CEU_NEXT_:
            _ceu_cur_.trl++;
        }

        if (_ceu_stk_ == 1)
            break;
        _ceu_evt_ = _CEU_STK_[--_ceu_stk_];
    }
}
