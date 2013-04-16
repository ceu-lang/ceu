//#line 0 "=== FILENAME ==="
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

#ifdef __cplusplus
#define CEU_WCLOCK_INACTIVE 0x7fffffffL     // TODO
#else
#define CEU_WCLOCK_INACTIVE INT32_MAX
#endif
#define CEU_WCLOCK_EXPIRED (CEU_WCLOCK_INACTIVE-1)

#define PTR_glb(tp,off) ((tp)(CEU.mem + off))
#ifdef CEU_ORGS
#define CUR ((tceu_org*) _ceu_cur_.org)
#define PTR_org(tp,org,off) ((tp)(((char*)(org)) + off))
#define PTR_cur(tp,off) ((tp)(((char*)_ceu_cur_.org) + off))
#else
#define CUR ((tceu_org*) CEU.mem)
#define PTR_org(tp,org,off) ((tp)(CEU.mem + off))
#define PTR_cur(tp,off) ((tp)(CEU.mem + off))
#endif

#define CEU_NMEM       (=== CEU_NMEM ===)
#define CEU_NTRAILS    (=== CEU_NTRAILS ===)

#ifdef CEU_IFCS
#define CEU_NCLS       (=== CEU_NCLS ===)
#define CEU_NIFCS      (=== CEU_NIFCS ===)
#endif

#define GLOBAL CEU.mem

// Macros that can be defined:
// ceu_out_pending() (sync?)
// ceu_out_wclock(dt)
// ceu_out_event(id, len, data)
// ceu_out_async(more?);
// ceu_out_end(v)

//typedef === TCEU_NEVT === tceu_nevt;    // (x) number of events
typedef u8 tceu_nevt;    // (x) number of events

// TODO: lbl => unsigned
typedef === TCEU_NLBL === tceu_nlbl;    // (x) number of trails

#ifdef CEU_IFCS
typedef === TCEU_NCLS === tceu_ncls;    // (x) number of instances
typedef === TCEU_NOFF === tceu_noff;    // (x) number of clss x ifcs
#endif

// align all structs 1 byte
// TODO: verify defaults for microcontrollers
//#pragma pack(push)
//#pragma pack(1)

#define CEU_MAX_STACK   255     // TODO

// TODO: 8 bytes!!!
typedef union {
    tceu_nevt evt;
    struct {
        tceu_nevt evt1;
        tceu_nlbl lbl;
        u8        stk;
    };
    struct {
        tceu_nevt        evt2;
        struct tceu_org* org;
    };
} tceu_trl;

typedef struct {
    union {
        void*   ptr;        // exts/ints
        int     v;          // exts/ints
        s32     dt;         // wclocks
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

// TODO: remove
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
    struct tceu_org* par_org;  // traversal
    tceu_trl*        par_trl;

#ifdef CEU_IFCS
    tceu_ncls cls;  // class id
#endif

#ifdef CEU_NEWS
    u8 isDyn:  1;       // created w/ new or spawn?
    u8 toFree: 1;       // free on termination?
#endif

    u8       n;      // number of trails (TODO: to metadata)
#endif
    tceu_trl trls[0];   // first trail

} tceu_org;

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
    tceu_noff   ifcs[CEU_NCLS][CEU_NIFCS];
#endif

#ifdef CEU_DEBUG
    tceu_lst    lst; // segfault printf
#endif

    char        mem[CEU_NMEM];
} tceu;

// TODO: fields that need no initialization?

tceu CEU = {
#ifdef CEU_WCLOCKS
    0, CEU_WCLOCK_INACTIVE, CEU_WCLOCK_INACTIVE,
#endif
#ifdef CEU_IFCS
    { === IFCS === },
#endif
#ifdef CEU_DEBUG
    {},
#endif
    {}                          // TODO: o q ele gera?
};

//#pragma pack(pop)

=== CLS_ACCS ===

=== HOST ===

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

#endif  // CEU_WCLOCKS

/**********************************************************************/

#ifdef CEU_NEWS
#ifdef CEU_RUNTESTS
// TODO
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

void ceu_org_init (tceu_org* org, int n, tceu_nlbl lbl)
{
    // { evt=0, stk=0, lbl=0 } for all trails
#ifdef CEU_ORGS
    org->n = n;
#endif
    memset(&org->trls, 0, n*sizeof(tceu_trl));
    {
        org->trls[0].evt = IN__ANY;
        org->trls[0].lbl = lbl;
        org->trls[0].stk = CEU_MAX_STACK;
    }
}

/**********************************************************************/

void ceu_pause (tceu_trl* trl, tceu_trl* trlF, int psed) {
    int n;

    do {
        if (psed) {
            if (trl->evt == IN__ORG)
                trl->evt = IN__ORG_PSED;
        } else {
            if (trl->evt == IN__ORG_PSED)
                trl->evt = IN__ORG;
        }
    } while (trl++ <= trlF);

    if (!psed) {
        ceu_go_wclock(0);   // TODO: hack
    }
}

/**********************************************************************/

void ceu_go_init ()
{
#ifdef CEU_DEBUG
    signal(SIGSEGV, ceu_segfault);
#endif
    ceu_org_init((tceu_org*)CEU.mem, CEU_NTRAILS, Class_Main);
    ceu_go(IN__INIT, NULL);
}

// TODO: ret

#ifdef CEU_EXTS
void ceu_go_event (int id, void* data)
{
#ifdef CEU_DEBUG_TRAILS
    fprintf(stderr, "====== %d\n", id);
#endif
    ceu_evt_param_ptr(data);
    ceu_go(id, &p);
}
#endif

#ifdef CEU_ASYNCS
void ceu_go_async ()
{
#ifdef CEU_DEBUG_TRAILS
    fprintf(stderr, "====== ASYNC\n");
#endif
    ceu_go(IN__ASYNC, NULL);
}
#endif

void ceu_go_wclock (s32 dt)
{
#ifdef CEU_WCLOCKS

#ifdef CEU_DEBUG_TRAILS
    fprintf(stderr, "====== WCLOCK\n");
#endif

    ceu_evt_param_dt(dt);

    if (CEU.wclk_min <= dt)
        CEU.wclk_late = dt - CEU.wclk_min;   // how much late the wclock is

    CEU.wclk_min_tmp = CEU.wclk_min;
    CEU.wclk_min     = CEU_WCLOCK_INACTIVE;

    ceu_go(IN__WCLOCK, &p);

#ifdef ceu_out_wclock
    if (CEU.wclk_min != CEU_WCLOCK_INACTIVE)
        ceu_out_wclock(CEU.wclk_min);   // only signal after all
#endif

    CEU.wclk_late = 0;

#endif   // CEU_WCLOCKS

    return;
}

void ceu_go_all (int* ret_end)
{
    ceu_go_init();
    if (*ret_end) goto _CEU_END_;

#ifdef IN_START
    ceu_go_event(IN_START, NULL);
    if (*ret_end) goto _CEU_END_;
#endif

#ifdef CEU_ASYNCS
    for (;;) {
        ceu_go_async();
        if (*ret_end) goto _CEU_END_;
    }
#endif

_CEU_END_:;
#ifdef CEU_NEWS
#ifdef CEU_RUNTESTS
    #define CEU_MAX_DYNS 100
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
#ifdef CEU_RUNTESTS
        ceu_stack_clr();
#endif

    tceu_evt _CEU_STK_[255];  // TODO: 255
    int      _ceu_stk_ = 1;   // points to next (TODO: 1=desperdicio)

    tceu_evt _ceu_evt_;       // current stack entry
    tceu_lst _ceu_cur_;       // current listener

#ifdef CEU_ORGS
    void*       _ceu_clr_org_;  // stop at this org
#endif
    tceu_trl* _ceu_clr_trl0_; //      at this trl

    // ceu_go_init(): nobody awaiting, jump reset
    if (__ceu_id == IN__INIT) {
        _ceu_evt_.id = IN__INIT;
    }

    // ceu_go_xxxx():
    else {
        // first set all awaiting: trl.stk=CEU_MAX_STACK
        _ceu_evt_.id = IN__ANY;

        // then stack external event
        if (__ceu_p)
            _CEU_STK_[_ceu_stk_].param = *__ceu_p;
        _CEU_STK_[_ceu_stk_].id  = __ceu_id;
        _ceu_stk_++;
    }

    for (;;)    // STACK
    {
#ifdef CEU_ORGS
        _ceu_cur_.org = CEU.mem;    // on pop(), always restart
#endif
_CEU_CALL_:
        if (_ceu_evt_.id == IN__CLR)
            _ceu_cur_.trl = &CUR->trls[
#ifdef CEU_ORGS
                                CUR->n
#else
                                CEU_NTRAILS
#endif
                            -1];
        else
            _ceu_cur_.trl = &CUR->trls[0];

_CEU_CALLTRL_:  // trl is already set (nxt/prv trail or CLR)

#ifdef CEU_DEBUG_TRAILS
#ifdef CEU_ORGS
fprintf(stderr, "GO: evt=%d stk=%d org=%p\n", _ceu_evt_.id, _ceu_stk_, CUR);
#else
fprintf(stderr, "GO: evt=%d stk=%d\n", _ceu_evt_.id, _ceu_stk_);
#endif
#endif
        for (;;)    // TRL
        {
            // clr is bounded to _trl0_ (set by code.lua)
            if (
                (_ceu_evt_.id == IN__CLR)
#ifdef CEU_ORGS
            &&  (_ceu_clr_org_ == CUR)
#endif
            &&  (_ceu_cur_.trl == _ceu_clr_trl0_)
            ) {
                break;
            }

            // check if all trails have been traversed
            // traverse next org if applicable
            {
                tceu_trl* cmp;
                if (_ceu_evt_.id == IN__CLR) {
                    cmp = &CUR->trls[-1];   // -1 is out
                } else {
                    cmp = &CUR->trls[
#ifdef CEU_ORGS
                                CUR->n
#else
                                CEU_NTRAILS
#endif
                            ];
                }

                // org has been traversed to the end?
                if (_ceu_cur_.trl == cmp)
                {
#ifdef CEU_ORGS
                    // check for next org
                    if (CUR != (tceu_org*)CEU.mem) {
                        tceu_org* PAR = CUR->par_org;
                        _ceu_cur_.trl = CUR->par_trl;
                        if (_ceu_evt_.id != IN__CLR) {
                            _ceu_cur_.trl++;     // X->Y [ X | org | Y ]
                        } else {
                            _ceu_cur_.trl--;     // Y->X [ X | org | Y ]
#ifdef CEU_NEWS
                            // re-link UP <-> DOWN
                            if (CUR->isDyn)
                            {
                                tceu_trl* down = &CUR->trls[CUR->n-1];

                                // HACK_1 (see code.lua)
                                // test org!=NULL instead of evt==IN__ORG
                                if (down->org != NULL) {
                                    CUR->par_trl->org = down->org;
                                    down->org->par_org = CUR->par_org;
                                    down->org->par_trl = CUR->par_trl;
                                } else {
                                    CUR->par_trl->evt = IN__NONE;
                                    CUR->par_trl->org = NULL;
                                }
                                // free if "dyn" and completelly traversed
                                // (i.e. _ceu_clr_org_ is not me)
//fprintf(stderr, "FREE: %p\n", CUR);
                                free(CUR);
#ifdef CEU_RUNTESTS
                                _ceu_dyns_--;
#endif
                            }
#endif
                        }
                        _ceu_cur_.org = PAR;
                        goto _CEU_CALLTRL_;
                    }
                    else
#endif
                    {
                        break;  // reached CEU.mem: terminate current stack
                    }
                }
                // continue traversing it
            }

            {
// TODO: trl_vec is freed
                tceu_trl* trl = _ceu_cur_.trl;
#ifdef CEU_DEBUG_TRAILS
#ifdef CEU_ORGS
if (trl->evt == IN__ORG)
    fprintf(stderr, "\tTRY: evt=%d org=%p\n", trl->evt, trl->org);
else
#endif
fprintf(stderr, "\tTRY: evt=%d stk=%d lbl=%d\n", trl->evt, trl->stk, trl->lbl);
#endif
#ifdef CEU_ORGS
                if ( trl->evt == IN__ORG
                ||   (trl->evt==IN__ORG_PSED && _ceu_evt_.id==IN__CLR)
                ) {
#ifdef CEU_DEBUG
                    assert(trl->org != NULL);
#endif
                    _ceu_cur_.org = trl->org;
                    goto _CEU_CALL_;
                }
#endif

                if (
                    (_ceu_evt_.id != IN__CLR)
                  &&
                    (  (trl->stk!=CEU_MAX_STACK && trl->stk!=_ceu_stk_)
                    || (trl->evt!=IN__ANY       && trl->evt!=_ceu_evt_.id) )
                ) {
                    if (_ceu_evt_.id == IN__ANY)
                        trl->stk = CEU_MAX_STACK; // new reaction reset stk
                    goto _CEU_NEXT_;
                }

                trl->stk = 0;             // no more awaking

                if (_ceu_evt_.id==IN__CLR && trl->evt!=IN__CLR) {
                    trl->evt = IN__NONE;  // no more awaiting
                    goto _CEU_NEXT_;
                }

                trl->evt = IN__NONE;      // no more awaiting
                _ceu_cur_.lbl = trl->lbl;
            }
_CEU_GOTO_:
#ifdef CEU_DEBUG
    CEU.lst = _ceu_cur_;
#ifdef CEU_DEBUG_TRAILS
#ifdef CEU_ORGS
fprintf(stderr, "TRK: o.%p / l.%d\n", CUR, _ceu_cur_.lbl);
#else
fprintf(stderr, "TRK: l.%d\n", _ceu_cur_.lbl);
#endif
#endif
#endif
            switch (_ceu_cur_.lbl) {
                === CODE ===
            }
_CEU_NEXT_:
            if (_ceu_evt_.id == IN__CLR)
                _ceu_cur_.trl--;
            else
                _ceu_cur_.trl++;
        }

        if (_ceu_stk_ == 1)
            break;
        _ceu_evt_ = _CEU_STK_[--_ceu_stk_];
    }
}
