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

#ifdef __cplusplus
#define CEU_WCLOCK_NONE 0x7fffffffL     // TODO
#else
#define CEU_WCLOCK_NONE INT32_MAX
#endif

#define PTR_glb(tp,off) ((tp)(CEU.mem + off))
#define PTR_org(tp,org,off) ((tp)(((char*)(org)) + off))
#ifdef CEU_ORGS
#define PTR_cur(tp,off) ((tp)(_trk_.org + off))
#else
#define PTR_cur(tp,off) ((tp)(CEU.mem + off))
#endif

#define MIN(x,y) ((x<y)?x:y)
#define MAX(x,y) ((x>y)?x:y)
#define CEU_NMEM       (=== CEU_NMEM ===)
#define CEU_NTRACKS    (MAX(1,=== CEU_NTRACKS ===))
#define CEU_NLSTS      (MAX(1,=== CEU_NLSTS ===))

#ifdef CEU_FINS
#define CEU_NLBLS      (=== CEU_NLBLS ===)
#endif

#ifdef CEU_IFCS
#define CEU_NCLS       (=== CEU_NCLS ===)
#define CEU_NIFCS      (=== CEU_NIFCS ===)
#endif

#define GLOBAL CEU.mem

// Macros that can be defined:
// ceu_out_pending() (1)
// ceu_out_wclock(us)
// ceu_out_async(has)
// ceu_out_event(id, len, data)
// ceu_out_end(v)

// TODO: real ganho desses tipos?
typedef === TCEU_NTRK === tceu_ntrk;    // max number of tracks
typedef === TCEU_NLST === tceu_nlst;    // max number of event listeners
typedef === TCEU_NEVT === tceu_nevt;    // max number of event ids
typedef === TCEU_NLBL === tceu_nlbl;    // max number of label ids

#ifdef CEU_IFCS
typedef === TCEU_NCLS === tceu_ncls;    // max number of classes
typedef === TCEU_NOFF === tceu_noff;    // max offset in an iface
#endif

typedef struct {
#ifdef CEU_ORGS
    void*     org;
#endif
    tceu_nlbl lbl;
} tceu_trk;

typedef struct {
    union {
        struct {
#ifdef CEU_ORGS
            void* src;
#endif
            u8    on;
        };
#ifdef CEU_WCLOCKS
        s32   togo;
#endif
    };
    tceu_nevt evt;      // TODO: save this byte
    tceu_nlbl lbl;
#ifdef CEU_ORGS
    void*     org;
#endif
#ifdef CEU_PSES
    u8        pse;
#endif
} tceu_lst;

enum {
=== LABELS_ENUM ===
};

typedef struct {
#ifdef CEU_EXTS
    void*       ext_data;
    int         ext_int;
#endif

#ifdef CEU_WCLOCKS
    int         wclk_late;
    s32         wclk_min;
    s32         wclk_dt;
#endif

#ifdef CEU_FINS
    u8          lbl2fin[CEU_NLBLS];
#endif

#ifdef CEU_IFCS
    tceu_noff   ifcs[CEU_NCLS][CEU_NIFCS];
#endif

#ifdef CEU_DEBUG
    tceu_trk    trk;        // segfault printf
#endif

#ifdef CEU_NEWS     // uses `int´ (dynamic)
    int         trks_n;
    int         trks_nmax;
    tceu_trk*   trks;

    int         lsts_n;
    int         lsts_nmax;
    tceu_lst*   lsts;

#else
    tceu_ntrk   trks_n;
    tceu_ntrk   trks_nmax;              // TODO: mem (const)
    tceu_trk    trks[CEU_NTRACKS];

    tceu_nlst   lsts_n;
    tceu_nlst   lsts_nmax;              // TODO: mem (const)
    tceu_lst    lsts[CEU_NLSTS];
#endif

    char        mem[CEU_NMEM];
} tceu;

// TODO: fields that need no initialization?

tceu CEU = {
#ifdef CEU_EXTS
    0, 0,
#endif
#ifdef CEU_WCLOCKS
    0, CEU_WCLOCK_NONE, 0,
#endif
#ifdef CEU_FINS
    { === LABELS_FINS === },
#endif
#ifdef CEU_IFCS
    { === IFCS === },
#endif
#ifdef CEU_DEBUG
    {},
#endif
#ifdef CEU_NEWS
    0, CEU_NTRACKS*2, NULL,
    0, CEU_NLSTS*2, NULL,
#else
    0, CEU_NTRACKS, {},
    0, CEU_NLSTS,   {},
#endif
    {}
};

=== CLS_ACCS ===

=== HOST ===

/**********************************************************************/

void ceu_call_f (void* org, tceu_nlbl lbl);
#ifdef CEU_ORGS
#define ceu_call(a,b) ceu_call_f(a,b)
#else
#define ceu_call(a,b) ceu_call_f(NULL,b)
#endif

void ceu_wclock_min (s32 us, int out);

/**********************************************************************/

//int xxx = 0;
void ceu_trk_push (void* org, tceu_nlbl lbl)
{
    tceu_trk trk = {
#ifdef CEU_ORGS
        org,
#endif
        lbl
    };

#ifdef CEU_NEWS
    if (CEU.trks_n == CEU.trks_nmax) {
        u32 nmax;
        tceu_trk* new;
        for (nmax=CEU.trks_nmax*2; nmax>CEU.trks_nmax; nmax/=2) {
            new = realloc(CEU.trks, nmax*sizeof(tceu_trk) + sizeof(tceu_trk));
            if (new)
                break;
        }
        CEU.trks_nmax = nmax;
        CEU.trks = new;           // assert below
    }
#endif

#if defined(CEU_DEBUG) || defined(CEU_NEWS)
    assert(CEU.trks_n < CEU.trks_nmax);
#endif

    CEU.trks[CEU.trks_n++] = trk;
    //if (CEU.trks_n > xxx)
        //xxx = CEU.trks_n;
}
#ifndef CEU_ORGS
#define ceu_trk_push(a,b) ceu_trk_push(NULL,b)
#endif

#ifdef CEU_ORGS
#ifndef CEU_ORGS_GLOBAL
int ceu_clr_child (void* cur, void* org, tceu_nlbl l1, tceu_nlbl l2) {
    void* par = *PTR_org(void**,cur,(=== CEU_CLS_PAR_ORG ===));
    if (cur == CEU.mem) {
        return 0;                   // root org, no parent
    } else if (par == org) {
        tceu_nlbl lbl = *PTR_org(tceu_nlbl*,cur,(=== CEU_CLS_PAR_LBL ===));
        return lbl>=l1 && lbl<=l2;
    } else {
        return ceu_clr_child(par, org, l1, l2);
    }
}
#endif
#endif

void ceu_trk_clr (int child, void* org, tceu_nlbl l1, tceu_nlbl l2) {
    int i;
    for (i=0; i<CEU.trks_n; i++) {
        tceu_trk* trk = &CEU.trks[i];
#ifdef CEU_ORGS
        if ( (trk->org==org && trk->lbl>=l1 && trk->lbl<=l2)
#ifndef CEU_ORGS_GLOBAL
        ||   (child && trk->org!=org && ceu_clr_child(trk->org,org,l1,l2))
#endif
        ) {
#else
        if (trk->lbl>=l1 && trk->lbl<=l2) {
#endif
            // remove killed tracks
            // TODO: expensive
            int j;
            CEU.trks_n--;
            for (j=i; j<CEU.trks_n; j++)
                CEU.trks[j] = CEU.trks[j+1];
            i--;    // shifted all up to current position: repeat
        }
    }
}
#ifndef CEU_ORGS
#define ceu_trk_clr(a,b,c,d) ceu_trk_clr(a,NULL,c,d)
#endif

/**********************************************************************/

void ceu_lsts_adj ()
{
    int i;
    for (i=0; i<CEU.lsts_n; i++) {
#ifdef CEU_WCLOCKS
        if (CEU.lsts[i].evt != IN__WCLOCK)
#endif
            CEU.lsts[i].on = 1;
    }
}

void ceu_lsts_ins (tceu_nevt evt, void* src, void* org,
                   tceu_nlbl lbl, s32 togo)
{
    tceu_lst* lst;

#ifdef CEU_NEWS
    if (CEU.lsts_n == CEU.lsts_nmax) {
        u32 nmax;
        tceu_lst* new;
        for (nmax=CEU.lsts_nmax*2; nmax>CEU.lsts_nmax; nmax/=2 ) {
            new = realloc(CEU.lsts, nmax*sizeof(tceu_lst));
            if (new)
                break;
        }
        CEU.lsts_nmax = nmax;
        CEU.lsts = new;           // assert below
    }
#endif

#if defined(CEU_DEBUG) || defined(CEU_NEWS)
    assert(CEU.lsts_n < CEU.lsts_nmax);
#endif

    lst = &CEU.lsts[CEU.lsts_n++];
#ifdef CEU_ORGS
    lst->org = org;
#endif
    lst->evt = evt;
    lst->lbl = lbl;
#ifdef CEU_PSES
    lst->pse = 0;
#endif

#ifdef CEU_WCLOCKS
    if (evt == IN__WCLOCK) {
        lst->togo = togo;
    }
    else
#endif
    {
#ifdef CEU_ORGS
        lst->src = src;
#endif
        lst->on  = togo;
    }
}
#ifndef CEU_ORGS
#define ceu_lsts_ins(a,b,c,d,e) ceu_lsts_ins(a,NULL,NULL,d,e)
#endif

void ceu_lsts_go (tceu_nevt evt, void* src)
{
    int i;
#ifdef CEU_DETERMINISTIC
    int j;
#endif

#ifdef CEU_WCLOCKS
    s32 min=0;    // TODO: always init'ed (ignore gcc warning)
    if (evt == IN__WCLOCK) {
        min = MIN(CEU.wclk_min, CEU.wclk_dt);
        CEU.wclk_min = CEU_WCLOCK_NONE;
    }
#endif

    // last listeners are stacked first
    for (i=CEU.lsts_n-1; i>=0; i--)
    {
        tceu_lst* lst = &CEU.lsts[i];

        if (lst->evt != evt)
            continue;

#ifdef CEU_PSES
        if (lst->pse > 0)
            continue;
#endif

#ifdef CEU_WCLOCKS
        if (evt == IN__WCLOCK) {
            if (lst->togo != min) {
                lst->togo -= CEU.wclk_dt;
                ceu_wclock_min(lst->togo, 0);
                continue;
            }
        }
        else
#endif
        {
            if (! lst->on)
                continue;
#ifdef CEU_ORGS
            if (lst->src != src)
                continue;
#endif
        }

        ceu_trk_push(lst->org, lst->lbl);
        CEU.lsts_n--;

#ifdef CEU_DETERMINISTIC
        for (j=i; j<CEU.lsts_n; j++)
            CEU.lsts[j] = CEU.lsts[j+1];
#else
        if (i < CEU.lsts_n)
            *lst = CEU.lsts[CEU.lsts_n];
#endif

#ifdef CEU_ASYNCS
#ifdef ceu_out_async
        if (evt == IN__ASYNC) {
            ceu_out_async(1);
            //return;           // TODO: should take 1st not last!
        }
#endif
#endif
    }
}
#ifndef CEU_ORGS
#define ceu_lsts_go(a,b) ceu_lsts_go(a,NULL)
#endif

void ceu_lsts_clr (int child, void* org, tceu_nlbl l1, tceu_nlbl l2) {
    int i;
#ifdef CEU_DETERMINISTIC
    int j;
#endif
    for (i=CEU.lsts_n-1; i>=0; i--) {      // finalizers: last->first
        tceu_lst* lst = &CEU.lsts[i];
#ifdef CEU_ORGS
        if ( (lst->org==org && lst->lbl>=l1 && lst->lbl<=l2)
#ifndef CEU_ORGS_GLOBAL
        ||   (child && lst->org!=org && ceu_clr_child(lst->org,org,l1,l2))
#endif
        ) {
#else
        if (lst->lbl>=l1 && lst->lbl<=l2) {
#endif
#ifdef CEU_FINS
            if (CEU.lbl2fin[lst->lbl])
                ceu_call(lst->org, lst->lbl);
#endif
            CEU.lsts_n--;
#ifdef CEU_DETERMINISTIC
            for (j=i; j<CEU.lsts_n; j++)
                CEU.lsts[j] = CEU.lsts[j+1];
#else
            if (i < CEU.lsts_n)
                *lst = CEU.lsts[CEU.lsts_n];
#endif
            //i--;
        }
    }
}
#ifndef CEU_ORGS
#define ceu_lsts_clr(a,b,c,d) ceu_lsts_clr(a,NULL,c,d)
#endif

#ifdef CEU_PSES
void ceu_lsts_pse (int child, void* org, tceu_nlbl l1, tceu_nlbl l2, int inc) {
    tceu_nlst i;
    for (i=0 ; i<CEU.lsts_n ; i++) {
        tceu_lst* lst = &CEU.lsts[i];
#ifdef CEU_FINS
        if (!CEU.lbl2fin[lst->lbl])
#endif
#ifdef CEU_ORGS
        if ( lst->org==org && lst->lbl>=l1 && lst->lbl<=l2
#ifndef CEU_ORGS_GLOBAL
        ||   child && lst->org!=org && ceu_clr_child(lst->org,org,l1,l2)
#endif
        ) {
#else
        if (lst->lbl>=l1 && lst->lbl<=l2) {
#endif
            lst->pse += inc;
#ifdef CEU_WCLOCKS
            if (lst->pse==0 && lst->evt==IN__WCLOCK)
                ceu_wclock_min(lst->togo, 1);
#endif
        }
    }
}
#ifndef CEU_ORGS
#define ceu_lsts_pse(a,b,c,d,e) ceu_lsts_pse(a,NULL,c,d,e)
#endif
#endif

/**********************************************************************/

#ifdef CEU_EXTS
// returns a pointer to the received value
int* ceu_ext_f (int v) {
    CEU.ext_int = v;
    return &CEU.ext_int;
}
#endif

#ifdef CEU_WCLOCKS

void ceu_wclock_min (s32 us, int out) {
    if ( CEU.wclk_min == CEU_WCLOCK_NONE
      || CEU.wclk_min  > us) {
        CEU.wclk_min = us;
#ifdef ceu_out_wclock
        if (out)
            ceu_out_wclock(us);
#endif
    }
}

void ceu_wclock_enable (s32 us, void* org, tceu_nlbl lbl) {
    s32 dt = us - CEU.wclk_late;
    ceu_lsts_ins(IN__WCLOCK, NULL, org, lbl, dt);
    ceu_wclock_min(dt, 1);
}
#ifndef CEU_ORGS
#define ceu_wclock_enable(a,b,c) ceu_wclock_enable(a,NULL,c)
#endif

#endif

#ifdef CEU_ASYNCS
void ceu_async_enable (void* org, tceu_nlbl lbl) {
    ceu_lsts_ins(IN__ASYNC, NULL, org, lbl, 0);
#ifdef ceu_out_async
        ceu_out_async(1);
#endif
}
#ifndef CEU_ORGS
#define ceu_async_enable(a,b) ceu_async_enable(NULL,b)
#endif
#endif

/**********************************************************************/

#ifdef CEU_DEBUG
void ceu_segfault (int sig_num) {
    fprintf(stderr, "SEGFAULT on %d\n", CEU.trk.lbl);
    exit(0);
}
#endif

void ceu_go ();     // TODO: place here?

void ceu_go_init ()
{
#ifdef CEU_DEBUG
    signal(SIGSEGV, ceu_segfault);
#endif

#ifdef CEU_NEWS
    CEU.trks = malloc(CEU.trks_nmax*sizeof(tceu_trk) + sizeof(tceu_trk));
    CEU.lsts = malloc(CEU.lsts_nmax*sizeof(tceu_lst));
    assert(CEU.trks!=NULL && CEU.lsts!=NULL);
#endif
    ceu_trk_push(CEU.mem, Class_Main);
    ceu_go();
}

#ifdef CEU_EXTS
void ceu_go_event (int id, void* data)
{
    ceu_lsts_adj();
    CEU.ext_data = data;
    switch (id) {
        === EVENTS ===
        default:
            ceu_lsts_go(id, 0);
    }
    ceu_go();
}
#endif

#ifdef CEU_ASYNCS
void ceu_go_async ()
{
    ceu_lsts_adj();
    ceu_lsts_go(IN__ASYNC, 0);
    ceu_go();
}
#endif

void ceu_go_wclock (s32 dt)
{
    ceu_lsts_adj();

#ifdef CEU_WCLOCKS
    if (CEU.wclk_min == CEU_WCLOCK_NONE)
        return;

    if (CEU.wclk_min <= dt)
        CEU.wclk_late = dt - CEU.wclk_min;   // how much late the wclock is

    CEU.wclk_dt = dt;
    ceu_lsts_go(IN__WCLOCK, 0);
    ceu_go();

#ifdef ceu_out_wclock
    ceu_out_wclock(CEU.wclk_min);
#endif
    CEU.wclk_late = 0;

#endif   // CEU_WCLOCKS
}

void ceu_call_f (void* org, tceu_nlbl lbl)
{
#ifdef CEU_ORGS
    tceu_trk _trk_ = {org,lbl};
#else
    tceu_trk _trk_ = {lbl};
#endif

_SWITCH_:
#ifdef CEU_DEBUG
    CEU.trk = _trk_;
#endif

/*
#ifdef CEU_ORGS
fprintf(stderr, "TRK: o.%p / l.%d\n", _trk_.org, _trk_.lbl);
#else
fprintf(stderr, "TRK:%d l.%d\n", CEU.lsts_n, _trk_.lbl);
#endif
*/

    switch (_trk_.lbl) {
        === CODE ===
    }
}

void ceu_go ()
{
    while (CEU.trks_n > 0) {
        CEU.trks_n--;
        ceu_call(CEU.trks[CEU.trks_n].org,
                 CEU.trks[CEU.trks_n].lbl);
    }
}

void ceu_go_all (int* ret_end)
{
    ceu_go_init();

#ifdef IN_START
    ceu_go_event(IN_START, NULL);
#endif

#ifdef CEU_ASYNCS
    for (;;) {
        ceu_go_async();
        if (*ret_end)
            return;
    }
#endif
}
