=== DEFS ===

#include <string.h>
#include <limits.h>

#ifdef CEU_DEBUG
#include <assert.h>
#endif

#ifdef CEU_NEWS
#include <stdlib.h>
#endif

#define CEU_STACK_MIN 0x01    // min prio for `stack´
#define CEU_TREE_MAX  0x7F    // max prio for `tree´

#ifdef __cplusplus
#define CEU_WCLOCK_NONE 0x7fffffffL     // TODO
#else
#define CEU_WCLOCK_NONE INT32_MAX
#endif

#define PTR(tp,off)     ((tp)(off))
#define PTR_org(tp,off) ((tp)(_trk_.org + off))

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

typedef === TCEU_NTRK === tceu_ntrk;    // max number of tracks
typedef === TCEU_NLST === tceu_nlst;    // max number of event listeners
typedef === TCEU_NEVT === tceu_nevt;    // max number of event ids
typedef === TCEU_NLBL === tceu_nlbl;    // max number of label ids

#ifdef CEU_IFCS
typedef === TCEU_NCLS === tceu_ncls;    // max number of classes
typedef === TCEU_NOFF === tceu_noff;    // max offset in an iface
#endif

typedef struct {
    char*     org;
    u8        stack;
    u8        tree;
    tceu_nlbl lbl;
} tceu_trk;

// TODO: union
typedef struct {
    char*     src;
    char*     org;
    tceu_nevt evt;
    tceu_nlbl lbl;
#ifdef CEU_PSES
    u8        pse;
#endif
    s32 togo;
} tceu_lst;

enum {
=== LABELS_ENUM ===
};

int ceu_go_nofree (int* ret);
#ifdef CEU_NEWS
int ceu_go_free (int* ret);
#define ceu_go ceu_go_free
#else
#define ceu_go ceu_go_nofree
#endif

typedef struct {
    char        mem[CEU_NMEM];

#ifdef CEU_EXTS
    void*       ext_data;
    int         ext_int;
#endif

#ifdef CEU_WCLOCKS
    int         wclk_late;
    s32         wclk_min;
#endif

#ifdef CEU_FINS
    u8          lbl2fin[CEU_NLBLS];
#endif

#ifdef CEU_IFCS
    tceu_noff   ifcs[CEU_NCLS][CEU_NIFCS];
#endif

#ifdef CEU_NEWS
    int         trks_n;
    int         trks_nmax;
    tceu_trk*   trks;

    int         lsts_n;
    int         lsts_nmax;
    tceu_lst*   lsts;

#else
    tceu_ntrk   trks_n;
    tceu_ntrk   trks_nmax;
    tceu_trk    trks[CEU_NTRACKS+1];  // 0 is reserved

    tceu_nlst   lsts_n;
    tceu_nlst   lsts_nmax;
    tceu_lst    lsts[CEU_NLSTS];
#endif

    u8          stack;
} tceu;

tceu CEU = {
    {},
#ifdef CEU_EXTS
    0, 0,
#endif
#ifdef CEU_WCLOCKS
    0, CEU_WCLOCK_NONE,
#endif
#ifdef CEU_FINS
    { === LABELS_FINS === },
#endif
#ifdef CEU_IFCS
    { === IFCS === },
#endif
#ifdef CEU_NEWS
    0, CEU_NTRACKS*2, NULL,
    0, CEU_NLSTS*2, NULL,
#else
    0, CEU_NTRACKS,   {},
    0, CEU_NLSTS,   {},
#endif
    CEU_STACK_MIN
};

=== CLS_ACCS ===

=== HOST ===

/**********************************************************************/

int ceu_trk_cmp (tceu_trk* trk1, tceu_trk* trk2) {
    if (trk1->stack != trk2->stack) {
        if (trk1->stack == CEU.stack)
            return 1;
        if (trk2->stack == CEU.stack)
            return 0;
        return (trk1->stack > trk2->stack);
    }
    return (trk1->tree > trk2->tree);
}

void ceu_trk_ins (u8 stack, u8 tree, char* org, int chk, tceu_nlbl lbl)
{
    tceu_ntrk i;
    tceu_trk trk = {
        org,
        stack,
        tree,
        lbl
    };

#ifdef CEU_TREE_CHK
    if (chk) {
        for (i=1; i<=CEU.trks_n; i++) {
            if (org==CEU.trks[i].org && lbl==CEU.trks[i].lbl) {
                return;
            }
        }
    }
#endif

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
/*
    fprintf(stderr, "======== TRKS: %d %d\n", CEU.trks_n, CEU.trks_nmax);
    for (int i=1; i<=CEU.trks_n; i++) {
        tceu_trk* trk = &CEU.trks[i];
        fprintf(stderr,"trk: o.%p s.%d/t.%d l.%d\n",
                    trk->org, trk->stack, trk->tree, trk->lbl);
    }
*/
    assert(CEU.trks_n < CEU.trks_nmax);
#endif

    for ( i = ++CEU.trks_n;
          (i>1) && ceu_trk_cmp(&trk,&CEU.trks[i/2]);
          i /= 2)
        CEU.trks[i] = CEU.trks[i/2];
    CEU.trks[i] = trk;
}

int ceu_trk_rem (tceu_trk* trk, tceu_ntrk N)
{
    tceu_ntrk i,cur;
    tceu_trk* last;

    if (CEU.trks_n == 0)
        return 0;

    if (trk)
        *trk = CEU.trks[N];

    last = &CEU.trks[CEU.trks_n--];

    for (i=N; i*2<=CEU.trks_n; i=cur)
    {
        cur = i * 2;
        if (cur!=CEU.trks_n &&
            ceu_trk_cmp(&CEU.trks[cur+1], &CEU.trks[cur]))
            cur++;

        if (ceu_trk_cmp(&CEU.trks[cur],last))
            CEU.trks[i] = CEU.trks[cur];
        else
            break;
    }
    CEU.trks[i] = *last;
    return 1;
}

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

void ceu_trk_clr (int child, char* org, tceu_nlbl l1, tceu_nlbl l2) {
    int i;
    for (i=1; i<=CEU.trks_n; i++) {
        tceu_trk* trk = &CEU.trks[i];
        if ( trk->org==org && trk->lbl>=l1 && trk->lbl<=l2
        ||   child && trk->org!=org && ceu_clr_child(trk->org,org,l1,l2) ) {
            ceu_trk_rem(NULL, i);
            i--;
        }
    }
}

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
/*
fprintf(stderr, "======== lsts (%d)\n", CEU.lsts_n);
for (int i=0; i<CEU.lsts_n; i++) {
    tceu_lst* lst = &CEU.lsts[i];
    fprintf(stderr,"LST: src.%p org=%p e.%d l.%d\n",
                lst->src, lst->org, lst->evt, lst->lbl);
}
*/
    assert(CEU.lsts_n < CEU.lsts_nmax);
#endif

    tceu_lst* lst = &CEU.lsts[CEU.lsts_n];
    lst->src = src;
    lst->org = org;
    lst->evt = evt;
    lst->lbl = lbl;
#ifdef CEU_PSES
    lst->pse = 0;
#endif
    lst->togo = togo;
    CEU.lsts_n++;
}

int ceu_lst_go (tceu_nevt evt, char* src, int single)
{
    tceu_nlst i;
    for (i=0 ; i<CEU.lsts_n ; i++) {
        tceu_lst* lst = &CEU.lsts[i];
        if (lst->evt==evt && lst->src==src) {
#ifdef CEU_PSES
            if (lst->pse == 0) {
#endif
                ceu_trk_ins(CEU.stack, CEU_TREE_MAX, lst->org, 0, lst->lbl);
                (CEU.lsts_n)--;
                if (i < CEU.lsts_n) {
                    *lst = CEU.lsts[CEU.lsts_n];
                    i--;
                }
                if (single)
                    return 1;
#ifdef CEU_PSES
            }
#endif
        }
    }
    return 0;
}

void ceu_lst_clr (int child, char* org, tceu_nlbl l1, tceu_nlbl l2, u8 tree) {
    tceu_nlst i;
    for (i=0 ; i<CEU.lsts_n ; i++) {
        tceu_lst* lst = &CEU.lsts[i];
        if ( lst->org==org && lst->lbl>=l1 && lst->lbl<=l2
        ||   child && lst->org!=org && ceu_clr_child(lst->org,org,l1,l2) ) {
#ifdef CEU_FINS
            // always trigger finalizers
            // (tree+lbl) guarantees they all run before the enclosing continuation
            u8 t = CEU.lbl2fin[lst->lbl];
            if (t)
                ceu_trk_ins(CEU.stack, tree+t, lst->org, 0, lst->lbl);
#endif
            CEU.lsts_n--;
            if (i < CEU.lsts_n) {
                *lst = CEU.lsts[CEU.lsts_n];
                i--;
            }
        }
    }
}

#ifdef CEU_PSES
void ceu_lst_pse (int child, char* org, tceu_nlbl l1, tceu_nlbl l2, int inc) {
    tceu_nlst i;
    for (i=0 ; i<CEU.lsts_n ; i++) {
        tceu_lst* lst = &CEU.lsts[i];
#ifdef CEU_FINS
        if (!CEU.lbl2fin[lst->lbl])
#endif
        if ( lst->org==org && lst->lbl>=l1 && lst->lbl<=l2
        ||   child && lst->org!=org && ceu_clr_child(lst->org,org,l1,l2) ) {
            lst->pse += inc;
#ifdef CEU_WCLOCKS
            if (lst->pse==0 && lst->evt==IN__WCLOCK) {
                if ( CEU.wclk_min==CEU_WCLOCK_NONE
                  || CEU.wclk_min>lst->togo )
                    CEU.wclk_min = lst->togo;
            }
#endif
        }
    }
}
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

void ceu_wclock_enable (s32 us, char* org, tceu_nlbl lbl) {
    s32 dt = us - CEU.wclk_late;
    ceu_lst_ins(IN__WCLOCK, NULL, org, lbl, dt);
    if (CEU.wclk_min==CEU_WCLOCK_NONE || CEU.wclk_min>dt) {
        CEU.wclk_min = dt;
#ifdef ceu_out_wclock
        ceu_out_wclock(dt);
#endif
    }
}

s32 ceu_wclock_find (char* org, tceu_nlbl lbl) {
    tceu_nlst i;
    for (i=0 ; i<CEU.lsts_n ; i++) {
        if (CEU.lsts[i].org==org && CEU.lsts[i].lbl==lbl) {
            return CEU.lsts[i].togo;
        }
    }
    return CEU_WCLOCK_NONE;
}

#endif

#ifdef CEU_ASYNCS
void ceu_async_enable (char* org, tceu_nlbl lbl) {
    ceu_lst_ins(IN__ASYNC, NULL, org, lbl, 0);
#ifdef ceu_out_async
        ceu_out_async(1);
#endif
}
#endif

/**********************************************************************/

int ceu_go_init (int* ret)
{
#ifdef CEU_NEWS
    CEU.trks = malloc(CEU.trks_nmax*sizeof(tceu_trk) + sizeof(tceu_trk));
    CEU.lsts = malloc(CEU.lsts_nmax*sizeof(tceu_lst));
    assert(CEU.trks!=NULL && CEU.lsts!=NULL);
#endif
    ceu_trk_ins(CEU_STACK_MIN, CEU_TREE_MAX, CEU.mem, 0, Class_Main);
    return ceu_go(ret);
}

#ifdef CEU_EXTS
int ceu_go_event (int* ret, tceu_nevt id, void* data)
{
    CEU.ext_data = data;
    CEU.stack = CEU_STACK_MIN;
    ceu_lst_go(id, 0, 0);

    return ceu_go(ret);
}
#endif

#ifdef CEU_ASYNCS
int ceu_go_async (int* ret, int* pending)
{
    int s, more;
    CEU.stack = CEU_STACK_MIN;
    more = ceu_lst_go(IN__ASYNC, 0, 1);
    s = ceu_go(ret);

    if (pending != NULL)
        *pending = more;

#ifdef ceu_out_async
    ceu_out_async(more);
#endif
    return s;
}
#endif

int ceu_go_wclock (int* ret, s32 dt, s32* nxt)
{
#ifdef CEU_WCLOCKS
    tceu_nlst i;
    s32 min_togo = CEU_WCLOCK_NONE;

    CEU.stack = CEU_STACK_MIN;

    if (CEU.wclk_min == CEU_WCLOCK_NONE) {
        if (nxt)
            *nxt = CEU_WCLOCK_NONE;
#ifdef ceu_out_wclock
        ceu_out_wclock(CEU_WCLOCK_NONE);
#endif
        return 0;
    }

    if (CEU.wclk_min <= dt) {
        min_togo = CEU.wclk_min;
        CEU.wclk_late = dt - CEU.wclk_min;   // how much late the wclock is
    }

    // spawns all togo/ext
    // finds the next CEU.wclk_min
    // decrements all togo
    CEU.wclk_min = CEU_WCLOCK_NONE;

    for (i=0; i<CEU.lsts_n; i++)
    {
        tceu_lst* lst = &CEU.lsts[i];

        if (lst->evt != IN__WCLOCK)
            continue;

// TODO: teste para dar erro aqui
/*
#ifdef CEU_PSES
        if (lst->pse > 0) {
            if ( CEU.wclk_min==CEU_WCLOCK_NONE
              || CEU.wclk_min>lst->togo )
                CEU.wclk_min = lst->togo;
            continue;
        }
#endif
*/
#ifdef CEU_PSES
        if (lst->pse > 0)
            continue;
#endif

        if (lst->togo == min_togo) {
            ceu_trk_ins(CEU_STACK_MIN, CEU_TREE_MAX, lst->org, 0, lst->lbl);
            CEU.lsts_n--;
            if (i < CEU.lsts_n) {
                *lst = CEU.lsts[CEU.lsts_n];
                i--;
            }
        } else {
            lst->togo -= dt;
            if ( CEU.wclk_min==CEU_WCLOCK_NONE
              || CEU.wclk_min>lst->togo )
                CEU.wclk_min = lst->togo;
        }
    }

    {int s = ceu_go(ret);
    if (nxt)
        *nxt = CEU.wclk_min;
#ifdef ceu_out_wclock
    ceu_out_wclock(CEU.wclk_min);
#endif
    CEU.wclk_late = 0;
    return s;}

#else   // CEU_WCLOCKS
    return 0;
#endif
}

#ifdef CEU_NEWS
int ceu_go_free (int* ret)
{
    int s = ceu_go_nofree(ret);
    if (s) {
        free(CEU.lsts);
        free(CEU.trks);
        CEU.lsts = NULL;    // subsequent events have no effect
        CEU.trks = NULL;
    }
    return s;
}
#endif

int ceu_go_nofree (int* ret)
{
    tceu_trk _trk_;

    CEU.stack = CEU_STACK_MIN;

    while (ceu_trk_rem(&_trk_,1))
    {
        if (_trk_.stack != CEU.stack)
            CEU.stack = _trk_.stack;

_SWITCH_:
#ifdef CEU_DEBUG
//fprintf(stderr,
    //"TRK: o.%p s.%d/t.%d/l.%d\n",
        //_trk_.org, _trk_.stack, _trk_.tree, _trk_.lbl);
#endif

        switch (_trk_.lbl)
        {
    === CODE ===
        }
    }

    return 0;
}

int ceu_go_all ()
{
    int ret = 0;
#ifdef CEU_ASYNCS
    int async_cnt;
#endif

    if (ceu_go_init(&ret))
        return ret;

#ifdef IN_START
    //*PVAL(int,IN_Start) = (argc>1) ? atoi(argv[1]) : 0;
    if (ceu_go_event(&ret, IN_START, NULL))
        return ret;
#endif

#ifdef CEU_ASYNCS
    for (;;) {
        if (ceu_go_async(&ret,&async_cnt))
            return ret;
        if (async_cnt == 0)
            break;              // returns nothing!
    }
#endif

    return ret;
}
