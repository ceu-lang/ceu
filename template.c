#include <string.h>
#include <limits.h>
#include <assert.h>

=== DEFS ===

#define CEU_STACK_MIN 0x01    // min prio for `stack´
#define CEU_TREE_MAX 0xFF     // max prio for `tree´

#ifdef __cplusplus
#define CEU_WCLOCK_NONE 0x7fffffffL     // TODO
#else
#define CEU_WCLOCK_NONE INT32_MAX
#endif

#define PTR(tp,off)     ((tp)(off))
#define PTR_org(tp,off) ((tp)(_trk_.org + off))

#define CEU_NMEM       (=== CEU_NMEM ===)
#define CEU_NTRACKS    (=== CEU_NTRACKS ===)
#define CEU_NLSTS      (=== CEU_NLSTS ===)

#ifdef CEU_FINS
#ifdef CEU_PSES
#define CEU_NLBLS      (=== CEU_NLBLS ===)
#endif
#endif

// Macros that can be defined:
// ceu_out_pending() (1)
// ceu_out_wclock(us)
// ceu_out_event(id, len, data)

typedef === TCEU_NTRK === tceu_ntrk;    // max number of tracks
typedef === TCEU_NLST === tceu_nlst;    // max number of event listeners
typedef === TCEU_NEVT === tceu_nevt;    // max number of event ids
typedef === TCEU_NLBL === tceu_nlbl;    // max number of label ids

typedef struct {
    void*     org;
#ifdef CEU_STACK
    u8 stack;
#endif
#ifdef CEU_TREE
    u8 tree;
#endif
    tceu_nlbl lbl;
} tceu_trk;

// TODO: union
typedef struct {
    void*     src;
    void*     org;
    tceu_nevt evt;
    tceu_nlbl lbl;
#ifdef CEU_PSES
    u8        pse;
#endif
    s32 togo;
} tceu_lst;

enum {
=== LABELS ===
};

int ceu_go (int* ret);

=== HOST ===

typedef struct {
    tceu_ntrk   tracks_n;

#if defined(CEU_STACK) || defined(CEU_TREE)
    tceu_trk    tracks[CEU_NTRACKS+1];  // 0 is reserved
#else
    tceu_trk    tracks[CEU_NTRACKS];
#endif

//#ifdef CEU_STACK      // TODO
    u8              stack;
//#endif

#ifdef CEU_EXTS
    void*       ext_data;
    int         ext_int;
#endif

#ifdef CEU_WCLOCKS
    int         wclk_late;
    s32         wclk_min;
#endif

#ifdef CEU_FINS
#ifdef CEU_PSES
    u8          lbl2fin[CEU_NLBLS];
#endif
#endif

    tceu_nlst   lsts_n;
    tceu_lst    lsts[CEU_NLSTS];

    char        mem[CEU_NMEM];
} tceu;

tceu CEU = {
    0, {},
//#ifdef CEU_STACK      // TODO
    CEU_STACK_MIN,
//#endif
#ifdef CEU_EXTS
    0, 0,
#endif
#ifdef CEU_WCLOCKS
    0, CEU_WCLOCK_NONE,
#endif
#ifdef CEU_FINS
#ifdef CEU_PSES
    { === LBL2FIN === },
#endif
#endif
    0, {},
    {}
};

/**********************************************************************/

#if defined(CEU_STACK) || defined(CEU_TREE)
int ceu_track_cmp (tceu_trk* trk1, tceu_trk* trk2) {
#ifdef CEU_STACK
    if (trk1->stack != trk2->stack) {
        if (trk1->stack == CEU.stack)
            return 1;
        if (trk2->stack == CEU.stack)
            return 0;
        return (trk1->stack > trk2->stack);
    }
#endif
#ifdef CEU_TREE
    return (trk1->tree > trk2->tree);
#endif
}
#endif

void ceu_track_ins (u8 stack, u8 tree, void* org, int chk, tceu_nlbl lbl)
{
#ifdef CEU_TREE_CHK
    {tceu_ntrk i;
    if (chk) {
        for (i=1; i<=CEU.tracks_n; i++) {
            if (org==CEU.tracks[i].org && lbl==CEU.tracks[i].lbl) {
                return;
            }
        }
    }}
#endif

#if defined(CEU_TREE) || defined(CEU_STACK)
{
    tceu_ntrk i;

    tceu_trk trk = {
        org,
#ifdef CEU_STACK
        stack,
#endif
#ifdef CEU_TREE
        tree,
#endif
        lbl
    };

    for ( i = ++CEU.tracks_n;
          (i>1) && ceu_track_cmp(&trk,&CEU.tracks[i/2]);
          i /= 2)
        CEU.tracks[i] = CEU.tracks[i/2];
    CEU.tracks[i] = trk;
}
#else // defined(CEU_TREE) || defined(CEU_STACK)
    CEU.tracks[CEU.tracks_n++].org = org;
    CEU.tracks[CEU.tracks_n++].lbl = lbl;
#endif
#ifdef CEU_DEBUG
/*
    fprintf(stderr, "======== %d\n", CEU.stack);
    for (int i=1; i<=CEU.tracks_n; i++) {
        tceu_trk* trk = &CEU.tracks[i];
        fprintf(stderr,"LST: o.%p s.%d/t.%d l.%d\n",
                    trk->org, trk->stack, trk->tree, trk->lbl);
    }
*/
    assert(CEU.tracks_n <= CEU_NTRACKS);        // TODO: remove
#endif
}

int ceu_track_rem (tceu_trk* trk, tceu_ntrk N)
{
    if (CEU.tracks_n == 0)
        return 0;

#ifdef CEU_TREE
    {tceu_ntrk i,cur;
    tceu_trk* last;

    if (trk)
        *trk = CEU.tracks[N];

    last = &CEU.tracks[CEU.tracks_n--];

    for (i=N; i*2<=CEU.tracks_n; i=cur)
    {
        cur = i * 2;
        if (cur!=CEU.tracks_n &&
            ceu_track_cmp(&CEU.tracks[cur+1], &CEU.tracks[cur]))
            cur++;

        if (ceu_track_cmp(&CEU.tracks[cur],last))
            CEU.tracks[i] = CEU.tracks[cur];
        else
            break;
    }
    CEU.tracks[i] = *last;
    return 1;}
#else
    if (trk)
        *trk = CEU.tracks[--CEU.tracks_n];
    return 1;
#endif
}

#ifdef CEU_STACK
void ceu_track_clr (void* org, tceu_nlbl l1, tceu_nlbl l2) {
    int i;
    for (i=1; i<=CEU.tracks_n; i++) {
        tceu_trk* trk = &CEU.tracks[i];
        if (trk->org==org && trk->lbl>=l1 && trk->lbl<=l2) {
            ceu_track_rem(NULL, i);
            i--;
        }
    }
}
#endif

/**********************************************************************/

void ceu_lst_ins (tceu_nevt evt, void* src, void* org, tceu_nlbl lbl, s32 togo) {
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
#ifdef CEU_DEBUG
/*
fprintf(stderr, "======== lsts (%d)\n", CEU.lsts_n);
for (int i=0; i<CEU.lsts_n; i++) {
    tceu_lst* lst = &CEU.lsts[i];
    fprintf(stderr,"LST: src.%p org=%p e.%d l.%d\n",
                lst->src, lst->org, lst->evt, lst->lbl);
}
*/
    assert(CEU.lsts_n <= CEU_NLSTS);
#endif
}

void ceu_lst_clr (void* org, tceu_nlbl l1, tceu_nlbl l2) {
    tceu_nlst i;
    for (i=0 ; i<CEU.lsts_n ; i++) {
        tceu_lst* lst = &CEU.lsts[i];
        if (lst->org==org && lst->lbl>=l1 && lst->lbl<=l2) {
            CEU.lsts_n--;
            if (i < CEU.lsts_n) {
                *lst = CEU.lsts[CEU.lsts_n];
                i--;
            }
        }
    }
}

#ifdef CEU_PSES
void ceu_lst_pse (void* org, tceu_nlbl l1, tceu_nlbl l2, int inc) {
    tceu_nlst i;
    for (i=0 ; i<CEU.lsts_n ; i++) {
        tceu_lst* lst = &CEU.lsts[i];
#ifdef CEU_FINS
        if (!CEU.lbl2fin[lst->lbl])
#endif
        if (lst->lbl && lst->org==org && lst->lbl>=l1 && lst->lbl<=l2) {
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

void ceu_lst_go (tceu_nevt evt, void* src)
{
    tceu_nlst i;
    for (i=0 ; i<CEU.lsts_n ; i++) {
        tceu_lst* lst = &CEU.lsts[i];
        if (lst->evt==evt && lst->src==src) {
#ifdef CEU_PSES
            if (lst->pse == 0) {
#endif
                ceu_track_ins(CEU.stack, CEU_TREE_MAX, lst->org, 0, lst->lbl);
                (CEU.lsts_n)--;
                if (i < CEU.lsts_n) {
                    *lst = CEU.lsts[CEU.lsts_n];
                    i--;
                }
#ifdef CEU_PSES
            }
#endif
        }
    }
}

/**********************************************************************/

#ifdef CEU_EXTS
// returns a pointer to the received value
int* ceu_ext_f (int v) {
    CEU.ext_int = v;
    return &CEU.ext_int;
}
#endif

#ifdef CEU_WCLOCKS

void ceu_wclock_enable (s32 us, void* org, tceu_nlbl lbl) {
    s32 dt = us - CEU.wclk_late;
    ceu_lst_ins(IN__WCLOCK, NULL, org, lbl, dt);
    if (CEU.wclk_min==CEU_WCLOCK_NONE || CEU.wclk_min>dt) {
        CEU.wclk_min = dt;
#ifdef ceu_out_wclock
        ceu_out_wclock(dt);
#endif
    }
}

s32 ceu_wclock_find (void* org, tceu_nlbl lbl) {
    tceu_nlst i;
    for (i=0 ; i<CEU.lsts_n ; i++) {
        if (CEU.lsts[i].org==org && CEU.lsts[i].lbl==lbl) {
            return CEU.lsts[i].togo;
        }
    }
    return CEU_WCLOCK_NONE;
}

#endif

/**********************************************************************/

int ceu_go_init (int* ret)
{
    ceu_track_ins(CEU_STACK_MIN, CEU_TREE_MAX, CEU.mem, 0, Class_Main);
    return ceu_go(ret);
}

#ifdef CEU_EXTS
int ceu_go_event (int* ret, tceu_nevt id, void* data)
{
    CEU.ext_data = data;
#ifdef CEU_STACK
    CEU.stack = CEU_STACK_MIN;
#endif
    ceu_lst_go(id, 0);

    return ceu_go(ret);
}
#endif

#ifdef CEU_ASYNCS
int ceu_go_async (int* ret, int* pending)
{
    int s;
#ifdef CEU_STACK
    CEU.stack = CEU_STACK_MIN;
#endif
    ceu_lst_go(IN__ASYNC, 0);
    s = ceu_go(ret);

    if (pending != NULL)
    {
        tceu_nlst i;
        *pending = 0;
        for (i=0 ; i<CEU.lsts_n ; i++) {
            if (CEU.lsts[i].evt == IN__ASYNC) {
                *pending = 1;
                break;
            }
        }
    }

    return s;
}
#endif

int ceu_go_wclock (int* ret, s32 dt, s32* nxt)
{
#ifdef CEU_WCLOCKS
    tceu_nlst i;
    s32 min_togo = CEU_WCLOCK_NONE;

#ifdef CEU_STACK
    CEU.stack = CEU_STACK_MIN;
#endif

    if (CEU.wclk_min == CEU_WCLOCK_NONE) {
        if (nxt)
            *nxt = CEU_WCLOCK_NONE;
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
            ceu_track_ins(CEU_STACK_MIN, CEU_TREE_MAX, lst->org, 0, lst->lbl);
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
    CEU.wclk_late = 0;
    return s;}

#else
    *nxt = CEU_WCLOCK_NONE;
    return 0;
#endif
}

int ceu_go (int* ret)
{
    tceu_trk _trk_;

#ifdef CEU_STACK
    CEU.stack = CEU_STACK_MIN;
#endif

    while (ceu_track_rem(&_trk_,1))
    {
#ifdef CEU_STACK
        if (_trk_.stack != CEU.stack)
            CEU.stack = _trk_.stack;
#endif
        if (_trk_.lbl == Inactive)
            continue;   // an escape may have cleared a `defer´ or `cont´

_SWITCH_:
#ifdef CEU_DEBUG
//fprintf(stderr,"TRK: o.%p s.%d/l.%d\n", _trk_.org, _trk_.stack, _trk_.lbl);
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
