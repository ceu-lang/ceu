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
#define PTR_org(tp,org,off) ((tp)(((char*)(org)) + off))
#define PTR_cur(tp,off) ((tp)(((char*)_ceu_lst_.org) + off))
#else
#define PTR_org(tp,org,off) ((tp)(CEU.mem + off))
#define PTR_cur(tp,off) ((tp)(CEU.mem + off))
#endif

#define CEU_NMEM       (=== CEU_NMEM ===)
#define CEU_NTRAILS    (=== CEU_NTRAILS ===)

#ifdef CEU_ORGS
#define CEU_CLS_CNT      (=== CEU_CLS_CNT ===)
//#define CEU_CLS_NEWS_PRV (=== CEU_CLS_NEWS_PRV ===)
//#define CEU_CLS_NEWS_NXT (=== CEU_CLS_NEWS_NXT ===)
#define CEU_CLS_FREE     (=== CEU_CLS_FREE ===)
#define CEU_CLS_TRAILN   (=== CEU_CLS_TRAILN ===)
#endif
#define CEU_CLS_TRAIL0   (=== CEU_CLS_TRAIL0 ===)

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

typedef struct {
    tceu_nevt evt;
    tceu_nlbl lbl;
    u8        stk;
    u8        _1;           // TODO
    u8        _2;
} tceu_trail;

typedef struct {
    tceu_nevt evt;
    void*     org;
} tceu_trail_;

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
#ifdef CEU_ORGS
    void*       org;
#endif
} tceu_evt;

typedef struct {
#ifdef CEU_ORGS
    void*       org;
#endif
    tceu_trail* trl;
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

tceu_trail* ceu_trails_get (int idx, void* org) {
    return PTR_org(tceu_trail*, org,
                    CEU_CLS_TRAIL0 + idx*sizeof(tceu_trail));
}
#ifndef CEU_ORGS
#define ceu_trails_get(a,b) ceu_trails_get(a,NULL)
#endif

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

void ceu_trails_set (int idx, int evt, int lbl, int stk, void* org) {
    tceu_trail* trl = ceu_trails_get(idx, org);
    trl->evt = evt;
#ifdef CEU_ORGS
    if (evt == IN__ORG) {
// TODO: unsafe typecast
        ((tceu_trail_*)trl)->org = (void*)lbl;
    }
    else
#endif
    {
        trl->lbl = lbl;
        trl->stk = stk;
    }
}
#ifndef CEU_ORGS
#define ceu_trails_set(a,b,c,d,e) ceu_trails_set(a,b,c,d,NULL)
#endif

void ceu_trails_clr (int t1, int t2, void* org) {
    int i;
    for (i=t2; i>=t1; i--) {    // lst fins first
        tceu_trail* trl = ceu_trails_get(i,org);
#ifdef CEU_FINS
        ceu_go(IN__FIN, NULL, trl->lbl, 0, org);
#endif
        trl->evt = IN__NONE;
    }
}
#ifndef CEU_ORGS
#define ceu_trails_clr(a,b,c) ceu_trails_clr(a,b,NULL)
#endif

/**********************************************************************/

#ifdef CEU_NEWS

typedef struct tceu_news_one {
    struct tceu_news_one* prv;
    struct tceu_news_one* nxt;
} tceu_news_one;

typedef struct {
    tceu_news_one fst;
    tceu_news_one lst;
} tceu_news_blk;

#ifdef CEU_RUNTESTS
int __ceu_news = 0;
#endif

void* ceu_news_ins (tceu_news_blk* blk, int len)
{
    tceu_news_one* cur = malloc(len);
    if (cur == NULL)
        return NULL;

#ifdef CEU_RUNTESTS
    if (__ceu_news >= 100)
        return NULL;
    __ceu_news++;
#endif

    (blk->lst.prv)->nxt = cur;
    cur->prv            = blk->lst.prv;
    cur->nxt            = &blk->lst;
    blk->lst.prv        = cur;

    return (void*) cur;
}

void ceu_news_rem (void* org)
{
    tceu_news_one* cur = (tceu_news_one*) org;
    cur->prv->nxt = cur->nxt;
    cur->nxt->prv = cur->prv;

    // [0, N-1]
    ceu_trails_clr(0, *PTR_org(u8*,org,CEU_CLS_TRAILN)-1, org);
    free(org);
#ifdef CEU_RUNTESTS
        __ceu_news--;
#endif
}

void ceu_news_rem_all (tceu_news_one* cur) {
    while (cur->nxt != NULL) {
        void* org = (void*) cur;
        // block already clrs
        //ceu_trails_clr(0, *PTR_org(u8*,org,CEU_CLS_TRAILN)-1, org);
        cur = cur->nxt;
        free(org);
#ifdef CEU_RUNTESTS
        __ceu_news--;
#endif
    }
}

void ceu_news_go (u8 evt_id, tceu_param* evt_p,
                  int stk, tceu_news_one* cur) {
    while (cur->nxt != NULL) {
        void* org = (void*) cur;
        cur = cur->nxt;
        ceu_trails_go(evt_id, evt_p, stk, org);      // TODO: kill
    }
}

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

void ceu_org_init (void* org, int n, tceu_nlbl lbl) {
    // { stk=0, lbl=0 } for all trails
#ifdef CEU_ORGS
    *PTR_org(u8*,org,CEU_CLS_TRAILN) = n;
    memset(PTR_org(char*,org,CEU_CLS_TRAIL0), 0, n*sizeof(tceu_trail));
#else
    memset(CEU.mem, 0, CEU_NTRAILS*sizeof(tceu_trail));
#endif
    ceu_trails_set(0, IN__ANY, lbl, 0, org);
}

/**********************************************************************/

void ceu_go_init ()
{
#ifdef CEU_DEBUG
    signal(SIGSEGV, ceu_segfault);
#endif
    ceu_org_init(CEU.mem, CEU_NTRAILS, Class_Main);
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

#ifdef CEU_RUNTESTS
void ceu_stack_clr () {
    int a[1000];
    memset(a, 0, sizeof(a));
}
#endif

void ceu_go_all (int* ret_end)
{
    ceu_go_init();

#ifdef IN_START
    ceu_go_event(IN_START, NULL);
#endif

#ifdef CEU_ASYNCS
    for (;;) {
#ifdef CEU_RUNTESTS
        ceu_stack_clr();
#endif
        ceu_go_async();
        if (*ret_end)
            return;
    }
#endif
}

void ceu_go (int __ceu_id, tceu_param* __ceu_p)
{
#if defined(CEU_EXTS) || defined(CEU_INTS)
    int _ceu_int_;
#endif

    tceu_evt _CEU_STK_[255];  // TODO: 255
    int      _ceu_stk_ = 1;   // points to next (TODO: 1=desperdicio)

    tceu_evt _ceu_evt_;       // current stack entry
    tceu_lst _ceu_lst_;       // current listener

#ifdef CEU_ORGS
    _ceu_evt_.org = CEU.mem;
#endif

    // ceu_go_init(): nobody awaiting, jump reset
    if (__ceu_id == IN__INIT) {
        _ceu_evt_.id = IN__INIT;
    }

    // ceu_go_xxxx():
    else {
        // first set all awaiting: trl.stk=0
        _ceu_evt_.id = IN__ANY;

        // then stack external event
        if (__ceu_p)
            _CEU_STK_[_ceu_stk_].param = *__ceu_p;
#ifdef CEU_ORGS
        _CEU_STK_[_ceu_stk_].org = CEU.mem;
#endif
        _CEU_STK_[_ceu_stk_].id  = __ceu_id;
        _ceu_stk_++;
    }

    for (;;)    // STACK
    {
#ifdef CEU_ORGS
        _ceu_lst_.org = CEU.mem;    // on pop(), always restart
#endif
_CEU_CALL_:
        _ceu_lst_.trl = PTR_cur(tceu_trail*,CEU_CLS_TRAIL0);
        // TODO: .i -> .j

#ifdef CEU_DEBUG_TRAILS
fprintf(stderr, "GO: evt=%d stk=%d\n", _ceu_evt_.id, _ceu_stk_);
#endif
        for (;;)    // TRL
        {
            // check if all trails have been traversed
            if (_ceu_lst_.trl ==
                &PTR_cur(tceu_trail*,CEU_CLS_TRAIL0)[
#ifdef CEU_ORGS
                    *PTR_cur(u8*,CEU_CLS_TRAILN)
#else
                    CEU_NTRAILS
#endif
                ])
            {
#ifdef CEU_ORGS
                // check for next org
                if (_ceu_lst_.org != CEU.mem)
                    _ceu_lst_.trl = *PTR_cur(void**, CEU_CLS_CNT);
                else
#endif
                    break;  // terminate current stack
            }
            {
                // TODO: trl_vec is freed
                tceu_trail* trl = _ceu_lst_.trl;
#ifdef CEU_DEBUG_TRAILS
fprintf(stderr, "\tTRY: stk=%d lbl=%d\n", trl->stk, trl->lbl);
#endif
                if (trl->evt == IN__ORG) {
                    assert(0);                  // goto org
                }

                switch (_ceu_evt_.id)
                {
                    case IN__NONE:
                        goto _CEU_NEXT_;

                    case IN__ANY:
                        trl->stk = 0;     // new reaction reset stk
#ifdef CEU_DEBUG_TRAILS
//fprintf(stderr, "\t\tZERO\n");
#endif
                        goto _CEU_NEXT_;

                    default: {
                        // stk=0 (try to match) || stk==_stk_ (my turn)
                        if ( (trl->stk==0       || trl->stk==_ceu_stk_)
                        &&   (trl->evt==IN__ANY || trl->evt==_ceu_evt_.id) ) {
                            _ceu_lst_.lbl = trl->lbl;
                            trl->evt = IN__NONE;
                        } else {
                            goto _CEU_NEXT_;
                        }
                    }
                }
#ifdef CEU_DEBUG_TRAILS
//fprintf(stderr, "\t\tAWK\n");
#endif
            }
_CEU_GOTO_:
#ifdef CEU_DEBUG
    CEU.lst = _ceu_lst_;
#ifdef CEU_DEBUG_TRAILS
#ifdef CEU_ORGS
fprintf(stderr, "TRK: o.%p / l.%d\n", _ceu_lst_.org, _ceu_lst_.lbl);
#else
fprintf(stderr, "TRK: l.%d\n", _ceu_lst_.lbl);
#endif
#endif
#endif
            switch (_ceu_lst_.lbl) {
                === CODE ===
            }
_CEU_NEXT_:
            _ceu_lst_.trl++;
        }

        if (_ceu_stk_ == 1)
            break;
        _ceu_evt_ = _CEU_STK_[--_ceu_stk_];
    }
}
