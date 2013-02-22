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
#define CEU_WCLOCK_INACTIVE 0x7fffffffL     // TODO
#else
#define CEU_WCLOCK_INACTIVE INT32_MAX
#endif
#define CEU_WCLOCK_EXPIRED (CEU_WCLOCK_INACTIVE-1)

#define PTR_glb(tp,off) ((tp)(CEU.mem + off))
#ifdef CEU_ORGS
#define PTR_org(tp,org,off) ((tp)(((char*)(org)) + off))
#define PTR_cur(tp,off) ((tp)(_ceu_org_ + off))
#else
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

typedef === TCEU_NLBL === tceu_nlbl;    // (x) number of trails
typedef === TCEU_NTRL === tceu_ntrl;    // (x) number of orgs

#ifdef CEU_IFCS
typedef === TCEU_NCLS === tceu_ncls;    // (x) number of instances
typedef === TCEU_NOFF === tceu_noff;    // (x) number of clss x ifcs
#endif

// align all structs 1 byte
// TODO: verify defaults for microcontrollers
#pragma pack(push)
#pragma pack(1)

typedef struct {
    //tceu_nevt evt;    // TODO: -ROM/-CPU/-on
    u8        on;       // TODO: bitmap?
    tceu_nlbl lbl;
#ifdef CEU_ORGS
    void*     org;
#endif
} tceu_trail;

typedef union {
    void*   ptr;        // exts
    int     v;          // exts
    s32     dt;         // wclocks
    void*   org;        // ints
} tceu_evt_param;

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
    tceu_trail  trail;        // segfault printf
#endif

    tceu_trail  trails[CEU_NTRAILS];

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
    {},
    {}                          // TODO: o q ele gera?
};

#pragma pack(pop)

=== CLS_ACCS ===

=== HOST ===

/**********************************************************************/

void ceu_call_f (u8 evt_id, tceu_evt_param evt_p,
                 tceu_nlbl lbl, void* org);
#ifdef CEU_ORGS
#define ceu_call(a,b,c,d) ceu_call_f(a,b,c,d)
#else
#define ceu_call(a,b,c,d) ceu_call_f(a,b,c,NULL)
#endif

/**********************************************************************/

tceu_trail* ceu_trails_get (int idx, void* org) {
#ifdef CEU_ORGS
    return &CEU.trails[
                *PTR_org(tceu_ntrl*,org,=== CEU_CLS_TRAIL0 ===) + idx
            ];
#else
    return &CEU.trails[idx];
#endif
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

int ceu_wclocks_not (s32* t, s32 dt) {
    if (*t>CEU.wclk_min_tmp || *t>dt) {
        *t -= dt;
        ceu_wclocks_min(*t, 0);
        return 1;
    }
    return 0;
}

#endif  // CEU_WCLOCKS

void ceu_trails_set (int idx, tceu_nlbl lbl, void* org) {
#ifdef CEU_ORGS
    tceu_trail* trl = ceu_trails_get(idx, org);
    trl->on  = 0;
    trl->lbl = lbl;
    trl->org = org;
#else
    CEU.trails[idx].on  = 0;
    CEU.trails[idx].lbl = lbl;
#endif
}
#ifndef CEU_ORGS
#define ceu_trails_set(a,b,c) ceu_trails_set(a,b,NULL)
#endif

void ceu_trails_set_evt (u8 evt_id, tceu_evt_param evt_p, int evt_idx,
                         int idx, tceu_nlbl lbl, void* org)
{
    ceu_trails_set(idx, lbl, org);

#ifdef CEU_WCLOCKS
    if (evt_id == IN__WCLOCK) {
        s32 dt_ = evt_p.dt - CEU.wclk_late;
        *PTR_org(s32*,org,evt_idx) = dt_;
        ceu_wclocks_min(dt_, 1);
    }
#endif

#ifdef CEU_ASYNCS
#ifdef ceu_out_async
    if (evt_id == IN__ASYNC) {
        ceu_out_async(1);
    }
#endif
#endif
}
#ifndef CEU_ORGS
#define ceu_trails_set_evt(a,b,c,d,e,f) ceu_trails_set_evt(a,b,c,d,e,NULL)
#endif


void ceu_trails_clr (int t1, int t2, void* org) {
    int i;
    for (i=t2; i>=t1; i--) {    // lst fins first
#ifdef CEU_FINS
        ceu_call(IN__FIN, (tceu_evt_param)NULL,
            ceu_trails_get(i,org)->lbl,
            ceu_trails_get(i,org)->org);
#endif
        ceu_trails_get(i,org)->lbl = CEU_INACTIVE;
    }
}
#ifndef CEU_ORGS
#define ceu_trails_clr(a,b,c) ceu_trails_clr(a,b,NULL)
#endif

void ceu_trails_on ()
{
    int i;
    for (i=0; i<CEU_NTRAILS; i++) {
        CEU.trails[i].on = 1;
    }
}

void ceu_trails_go (u8 evt_id, tceu_evt_param evt_p)
{
    int i;
    for (i=0; i<CEU_NTRAILS; i++) {
        if (CEU.trails[i].on && CEU.trails[i].lbl!=CEU_INACTIVE)
            ceu_call(evt_id, evt_p,
                     CEU.trails[i].lbl, CEU.trails[i].org);
    }
}

#ifdef CEU_PSES
void ceu_lsts_pse (int child, void* org, tceu_nlbl l1, tceu_nlbl l2, int inc) {
/*
    int i;
    for (i=0 ; i<CEU.lsts_n ; i++) {
        tceu_trail* lst = &CEU.lsts[i];
#ifdef CEU_FINS
        if (lst->evt == IN__FIN)
            continue;
#endif
#ifdef CEU_ORGS
        if ( lst->dst_org==org && lst->lbl>=l1 && lst->lbl<=l2
#ifndef CEU_ORGS_GLOBAL
        ||   child && lst->dst_org!=org &&
                ceu_clr_child(lst->dst_org,org,l1,l2)
#endif
        ) {
#else // CEU_ORGS
        if (lst->lbl>=l1 && lst->lbl<=l2) {
#endif // CEU_ORGS
            lst->pse += inc;
#ifdef CEU_WCLOCKS
            if (lst->pse==0 && lst->evt==IN__WCLOCK)
                ceu_wclocks_min(lst->togo, 1);
#endif
        }
    }
*/
}
#ifndef CEU_ORGS
#define ceu_lsts_pse(a,b,c,d,e) ceu_lsts_pse(a,NULL,c,d,e)
#endif
#endif

/**********************************************************************/

#ifdef CEU_DEBUG
void ceu_segfault (int sig_num) {
#ifdef CEU_ORGS
    fprintf(stderr, "SEGFAULT on %p : %d\n", CEU.trail.org, CEU.trail.lbl);
#else
    fprintf(stderr, "SEGFAULT on %d\n", CEU.trail.lbl);
#endif
    exit(0);
}
#endif

//void ceu_go (void* data);     // TODO: place here?

void ceu_go_init ()
{
#ifdef CEU_DEBUG
    signal(SIGSEGV, ceu_segfault);
#endif

/*
#ifdef CEU_NEWS
    CEU.trails = malloc(CEU.trails_nmax*sizeof(tceu_trail));
    assert(CEU.trails!=NULL);
#endif
*/
    ceu_call(0,(tceu_evt_param)NULL, Class_Main, &CEU.mem);
}

// TODO: ret

#ifdef CEU_EXTS
void ceu_go_event (int id, void* data)
{
    ceu_trails_on();
    ceu_trails_go(id, (tceu_evt_param)data);
}
#endif

#ifdef CEU_ASYNCS
void ceu_go_async ()
{
    ceu_trails_on();
    ceu_trails_go(IN__ASYNC, (tceu_evt_param)NULL);
}
#endif

void ceu_go_wclock (s32 dt)
{
    ceu_trails_on();

#ifdef CEU_WCLOCKS

    if (CEU.wclk_min <= dt)
        CEU.wclk_late = dt - CEU.wclk_min;   // how much late the wclock is

    CEU.wclk_min_tmp = CEU.wclk_min;
    CEU.wclk_min     = CEU_WCLOCK_INACTIVE;

    ceu_trails_go(IN__WCLOCK, (tceu_evt_param)dt);

#ifdef ceu_out_wclock
    if (CEU.wclk_min != CEU_WCLOCK_INACTIVE)
        ceu_out_wclock(CEU.wclk_min);   // only signal after all
#endif

    CEU.wclk_late = 0;

#endif   // CEU_WCLOCKS

    return;
}

// TODO
#ifdef CEU_EXTS
// returns a pointer to the received value
int* ceu_ext_f (int* data, int v) {
    *data = v;
    return data;
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
        ceu_go_async();
        if (*ret_end)
            return;
    }
#endif
}

void ceu_call_f (u8 _ceu_evt_id_, tceu_evt_param _ceu_evt_p_,
                 tceu_nlbl _ceu_lbl_, void* _ceu_org_)
{
#ifdef CEU_EXTS
    int _ceu_int_;
#endif

_SWITCH_:
#ifdef CEU_DEBUG
{
#ifdef CEU_ORGS
    tceu_trail _ceu_trail_ = {1, _ceu_lbl_, _ceu_org_};
#else
    tceu_trail _ceu_trail_ = {1, _ceu_lbl_};
#endif
    CEU.trail = _ceu_trail_;
}
#endif

    switch (_ceu_lbl_) {
        === CODE ===
    }
}
