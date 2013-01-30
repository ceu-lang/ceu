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

#define PTR(tp,off)     ((tp)(off))
#ifdef CEU_ORGS
#define PTR_org(tp,off) ((tp)(_trk_.org + off))
#else
#define PTR_org(tp,off) ((tp)(CEU.mem + off))
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

int CEU_MOD (int x, int m) {
    return (x>=0) ? x%m : (x+m)%m;
}

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
    char*     org;
#endif
    tceu_nlbl lbl;
} tceu_trk;

typedef struct {
#ifdef CEU_ORGS
    char*     src;
    char*     org;
#endif
    tceu_nevt evt;
    tceu_nlbl lbl;
#ifdef CEU_PSES
    u8        pse;
#endif
    s32 togo;           // TODO: mem (even for non wclocks)
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
    int         lsts_ncur;
    int         lsts_nmax;
    tceu_lst*   lsts;

#else
    tceu_ntrk   trks_n;
    tceu_ntrk   trks_nmax;              // TODO: mem (const)
    tceu_trk    trks[CEU_NTRACKS];

    tceu_nlst   lsts_n;
    tceu_nlst   lsts_ncur;
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
    0, 0, CEU_NLSTS*2, NULL,
#else
    0, CEU_NTRACKS, {},
    0, 0, CEU_NLSTS,   {},
#endif
    {}
};

=== CLS_ACCS ===

=== HOST ===

/**********************************************************************/

void ceu_go_go_f (char* org, tceu_nlbl lbl);
#ifdef CEU_ORGS
#define ceu_go_go(a,b) ceu_go_go_f(a,b)
#else
#define ceu_go_go(a,b) ceu_go_go_f(NULL,b)
#endif

void ceu_wclock_min (s32 us, int out);

/**********************************************************************/

void ceu_trk_ins (char* org, tceu_nlbl lbl)
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
}
#ifndef CEU_ORGS
#define ceu_trk_ins(a,b) ceu_trk_ins(NULL,b)
#endif

#ifdef CEU_ORGS
int ceu_clr_child (char* cur, char* org, tceu_nlbl l1, tceu_nlbl l2) {
    char* par = *PTR(char**,cur+(=== CEU_CLS_PAR_ORG ===));
    if (cur == CEU.mem) {
        return 0;                   // root org, no parent
    } else if (par == org) {
        tceu_nlbl lbl = *PTR(tceu_nlbl*,(cur+(=== CEU_CLS_PAR_LBL ===)));
        return lbl>=l1 && lbl<=l2;
    } else {
        return ceu_clr_child(par, org, l1, l2);
    }
}
#endif

void ceu_trk_clr (int child, char* org, tceu_nlbl l1, tceu_nlbl l2) {
    int i;
    // increasing or decreasing, nothing is triggered
    for (i=0; i<CEU.trks_n; i++) {
        tceu_trk* trk = &CEU.trks[i];
#ifdef CEU_ORGS
        if ( (trk->org==org && trk->lbl>=l1 && trk->lbl<=l2)
        ||   (child && trk->org!=org && ceu_clr_child(trk->org,org,l1,l2)) ) {
#else
        if (trk->lbl>=l1 && trk->lbl<=l2) {
#endif
            // remove killed tracks
            // TODO: expensive
//fprintf(stderr, "trk: %d\n", trk->lbl);
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

void ceu_lst_ins (tceu_nevt evt, char* src, char* org, tceu_nlbl lbl, s32 togo) 
{
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
    //fprintf(stderr, "\t= lst_ins %d (%d/%d)\n",
                    //evt, CEU.lsts_n, CEU.lsts_nmax);
    assert(CEU.lsts_n < CEU.lsts_nmax);
#endif

    tceu_lst* lst = &CEU.lsts[CEU.lsts_n++];
#ifdef CEU_ORGS
    lst->src = src;
    lst->org = org;
#endif
    lst->evt = evt;
    lst->lbl = lbl;
#ifdef CEU_PSES
    lst->pse = 0;
#endif
    lst->togo = togo;
}
#ifndef CEU_ORGS
#define ceu_lst_ins(a,b,c,d,e) ceu_lst_ins(a,NULL,NULL,d,e)
#endif

void ceu_lst_go (tceu_nevt evt, char* src, int reset)
{
    int i;
#ifdef CEU_DETERMINISTIC
    int j;
#endif

#ifdef CEU_WCLOCKS
    s32 min;
    if (evt == IN__WCLOCK) {
        min = MIN(CEU.wclk_min, CEU.wclk_dt);
        CEU.wclk_min = CEU_WCLOCK_NONE;
    }
#endif

    // new awaits in current cycle must be ignored
    if (reset)
        CEU.lsts_ncur = CEU.lsts_n;

    // decreasing: first listeners execute first
    for (i=CEU.lsts_ncur-1 ; i>=0 ; i--) {
        tceu_lst* lst = &CEU.lsts[i];
#ifdef CEU_ORGS
        if (lst->evt!=evt || lst->src!=src)
            continue;
#else
        if (lst->evt!=evt)
            continue;
#endif
#ifdef CEU_PSES
        if (lst->pse > 0)
            continue;
#endif

#ifdef CEU_WCLOCKS
        if (evt == IN__WCLOCK) {
            if (lst->togo !=  min) {
                lst->togo -= CEU.wclk_dt;
                ceu_wclock_min(lst->togo, 0);
                continue;
            }
        }
#endif

        ceu_trk_ins(lst->org, lst->lbl);  // ceu_go_go pode remover lst
        CEU.lsts_n--;
        CEU.lsts_ncur--;
#ifdef CEU_DETERMINISTIC
        for (j=i; j<CEU.lsts_n; j++)
            CEU.lsts[j] = CEU.lsts[j+1];
#else
        if (i < CEU.lsts_n)
            *lst = CEU.lsts[CEU.lsts_n];
#endif
#ifdef CEU_ASYNCS
        if (evt == IN__ASYNC) {
            #ifdef ceu_out_async
            ceu_out_async(1);
            #endif
            return;           // TODO: should take 1st not last!
        }
#endif
    }
}
#ifndef CEU_ORGS
#define ceu_lst_go(a,b,c) ceu_lst_go(a,NULL,c)
#endif

void ceu_lst_clr (int child, char* org, tceu_nlbl l1, tceu_nlbl l2) {
    int i;
#ifdef CEU_DETERMINISTIC
    int j;
#endif
    for (i=CEU.lsts_n-1; i>=0; i--) {      // finalizers: last->first
        tceu_lst* lst = &CEU.lsts[i];
#ifdef CEU_ORGS
        if ( (lst->org==org && lst->lbl>=l1 && lst->lbl<=l2)
        ||   (child && lst->org!=org && ceu_clr_child(lst->org,org,l1,l2)) ) {
#else
        if (lst->lbl>=l1 && lst->lbl<=l2) {
#endif
#ifdef CEU_FINS
            // always trigger finalizers
//fprintf(stderr, "rem: %d=%d\n", lst->lbl, CEU.lbl2fin[lst->lbl]);
            if (CEU.lbl2fin[lst->lbl])
                ceu_go_go(lst->org, lst->lbl);
#endif
            CEU.lsts_n--;
            if (i < CEU.lsts_ncur)
                CEU.lsts_ncur--;
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
#define ceu_lst_clr(a,b,c,d) ceu_lst_clr(a,NULL,c,d)
#endif

#ifdef CEU_PSES
void ceu_lst_pse (int child, char* org, tceu_nlbl l1, tceu_nlbl l2, int inc) {
    tceu_nlst i;
    for (i=0 ; i<CEU.lsts_n ; i++) {
        tceu_lst* lst = &CEU.lsts[i];
#ifdef CEU_FINS
        if (!CEU.lbl2fin[lst->lbl])
#endif
#ifdef CEU_ORGS
        if ( lst->org==org && lst->lbl>=l1 && lst->lbl<=l2
        ||   child && lst->org!=org && ceu_clr_child(lst->org,org,l1,l2) ) {
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
#define ceu_lst_pse(a,b,c,d,e) ceu_lst_pse(a,NULL,c,d,e)
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

void ceu_wclock_enable (s32 us, char* org, tceu_nlbl lbl) {
    s32 dt = us - CEU.wclk_late;
    ceu_lst_ins(IN__WCLOCK, NULL, org, lbl, dt);
    ceu_wclock_min(dt, 1);
}
#ifndef CEU_ORGS
#define ceu_wclock_enable(a,b,c) ceu_wclock_enable(a,NULL,c)
#endif

#endif

#ifdef CEU_ASYNCS
void ceu_async_enable (char* org, tceu_nlbl lbl) {
    ceu_lst_ins(IN__ASYNC, NULL, org, lbl, 0);
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
    ceu_go_go(CEU.mem, Class_Main);
    ceu_go();
}

#ifdef CEU_EXTS
void ceu_go_event (tceu_nevt id, void* data)
{
    CEU.ext_data = data;
    ceu_lst_go(id, 0, 1);
    ceu_go();
}
#endif

#ifdef CEU_ASYNCS
void ceu_go_async ()
{
    ceu_lst_go(IN__ASYNC, 0, 1);
    ceu_go();
}
#endif

void ceu_go_wclock (s32 dt)
{
#ifdef CEU_WCLOCKS
    if (CEU.wclk_min == CEU_WCLOCK_NONE)
        return;

    if (CEU.wclk_min <= dt)
        CEU.wclk_late = dt - CEU.wclk_min;   // how much late the wclock is

    CEU.wclk_dt = dt;
    ceu_lst_go(IN__WCLOCK, 0, 1);
    ceu_go();

#ifdef ceu_out_wclock
    ceu_out_wclock(CEU.wclk_min);
#endif
    CEU.wclk_late = 0;

#endif   // CEU_WCLOCKS
}

void ceu_go_go_f (char* org, tceu_nlbl lbl)
{
#ifdef CEU_ORGS
    tceu_trk _trk_ = {org,lbl};
#else
    tceu_trk _trk_ = {lbl};
#endif

_SWITCH_:
#ifdef CEU_DEBUG
    CEU.trk = _trk_;
/*
#ifdef CEU_ORGS
fprintf(stderr, "TRK: o.%p / l.%d\n", _trk_.org, _trk_.lbl);
#else
fprintf(stderr, "TRK: l.%d\n", _trk_.lbl);
#endif
*/

/*
fprintf(stderr, "\t= lsts (%d/%d)\n", CEU.lsts_n, CEU.lsts_nmax);
for (int i=0; i<CEU.lsts_n; i++) {
    tceu_lst* lst = &CEU.lsts[i];
    fprintf(stderr,"\t\te.%d l.%d\n", lst->evt, lst->lbl);
}
*/

#endif
    switch (_trk_.lbl) {
        === CODE ===
    }
/*
    if (CEU.trks_n > 0) {
        _trk_ = CEU.trks[--CEU.trks_n];
        goto _SWITCH_;
    }
*/
}

void ceu_go ()
{
    while (CEU.trks_n > 0) {
        CEU.trks_n--;
        ceu_go_go(CEU.trks[CEU.trks_n].org,
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
