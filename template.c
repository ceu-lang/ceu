#include <string.h>
#include <limits.h>

#define PR_MAX 0x7F
#define PR_MIN (-0x7F)

#define PTR(str,tp) ((tp)(MEM + str ))

#define N_TRACKS (1+ === N_TRACKS ===)
#define N_MEM    (=== N_MEM ===)

#define CEU_WCLOCK0 === CEU_WCLOCK0 ===
#define CEU_ASYNC0  === CEU_ASYNC0 ===
#define CEU_EMIT0   === CEU_EMIT0 ===
#define CEU_FIN0    === CEU_FIN0 ===

// Macros that can be defined:
// ceu_out_pending() (1)
// ceu_out_wclock(us)
// ceu_out_event(id, len, data)

typedef === TCEU_OFF === tceu_off;
typedef === TCEU_LBL === tceu_lbl;

=== DEFS ===

typedef struct {
    s32 togo;
    tceu_lbl lbl;
} tceu_wclock;

enum {
=== LABELS ===
};

int go (int* ret);

=== HOST ===

void* DATA = NULL;

char MEM[N_MEM];

// returns a pointer to the received value
int INT_v;
int* INT_f (int v) {
    INT_v = v;
    return &INT_v;
}

/* TRACKS ***************************************************************/

typedef struct {
#ifndef CEU_TRK_NOPRIO
    s8 prio;
#endif
    tceu_lbl lbl;
} tceu_trk;

int TRACKS_n = 0;

#ifdef CEU_TRK_NOPRIO
tceu_trk TRACKS[N_TRACKS];
#else
tceu_trk TRACKS[N_TRACKS+1];  // 0 is reserved
#endif

#if   defined CEU_TRK_NOPRIO
#define trk_insert(chk,prio,lbl) trk_insert_noprio(lbl)
#elif defined CEU_TRK_NOCHK
#define trk_insert(chk,prio,lbl) trk_insert_nochk(prio,lbl)
#endif

#if   defined CEU_TRK_NOPRIO
void trk_insert_noprio (tceu_lbl lbl)
#elif defined CEU_TRK_NOCHK
void trk_insert_nochk (s8 prio, tceu_lbl lbl)
#else
void trk_insert (int chk, s8 prio, tceu_lbl lbl)
#endif
{
#ifndef CEU_TRK_NOCHK
    {int i;
    if (chk) {
        for (i=1; i<=TRACKS_n; i++)
            if (lbl==TRACKS[i].lbl && prio==TRACKS[i].prio)
                return;
    }}
#endif

#ifdef CEU_TRK_NOPRIO
    TRACKS[TRACKS_n++].lbl = lbl;
#else
    {int i;
    for (i=++TRACKS_n; (i>1) && (prio>TRACKS[i/2].prio); i/=2)
        TRACKS[i] = TRACKS[i/2];
    TRACKS[i].prio = prio;
    TRACKS[i].lbl  = lbl;}
#endif
}

int trk_remove (tceu_trk* trk)
{
    if (TRACKS_n == 0)
        return 0;

#ifdef CEU_TRK_NOPRIO
    *trk = TRACKS[--TRACKS_n];
    return 1;
#else
    {int i,cur;
    tceu_trk* last;

    if (trk)
        *trk = TRACKS[1];

    last = &TRACKS[TRACKS_n--];

    for (i=1; i*2<=TRACKS_n; i=cur)
    {
        cur = i * 2;
        if (cur!=TRACKS_n && TRACKS[cur+1].prio>TRACKS[cur].prio)
            cur++;

        if (TRACKS[cur].prio>last->prio)
            TRACKS[i] = TRACKS[cur];
        else
            break;
    }
    TRACKS[i] = *last;
    return 1;}
#endif
}

void spawn (tceu_lbl* lbl)
{
    if (*lbl != Inactive) {
        trk_insert(0, PR_MAX, *lbl);
        *lbl = Inactive;
    }
}

void trigger (tceu_off off)
{
    int i;
    int n = MEM[off];
    for (i=0 ; i<n ; i++) {
        spawn((tceu_lbl*)&MEM[off+1+(i*sizeof(tceu_lbl))]);
    }
}

/* EMITS ***************************************************************/

#ifdef CEU_EMITS
int trk_peek (tceu_trk* trk)
{
    *trk = TRACKS[1];
    return TRACKS_n > 0;
}
#endif

/* FINS ***************************************************************/

#ifdef CEU_FINS
void ceu_fins (int i, int j)
{
    for (; i<j; i++) {
        tceu_lbl* fin0 = PTR(CEU_FIN0,tceu_lbl*);
        if (fin0[i] != Inactive)
            trk_insert(0, PR_MAX-i, fin0[i]);
    }
}
#endif

/* WCLOCKS ***************************************************************/

#ifdef CEU_WCLOCKS

#define CEU_WCLOCK_NONE LONG_MAX

int WCLOCK_late;

tceu_wclock* TMR_cur = NULL;

int ceu_wclock_lt (tceu_wclock* tmr) {
    if (!TMR_cur || tmr->togo<TMR_cur->togo) {
        TMR_cur = tmr;
        return 1;
    }
    return 0;
}

void tmr_enable (int idx, s32 us, tceu_lbl lbl) {
    tceu_wclock* tmr = &(PTR(CEU_WCLOCK0,tceu_wclock*)[idx]);
    s32 dt = us - WCLOCK_late;
#ifdef ceu_out_wclock
    int nxt;
#endif

    tmr->togo = dt;
    tmr->lbl  = lbl;
#ifdef ceu_out_wclock
    nxt = ceu_wclock_lt(tmr);
#else
    ceu_wclock_lt(tmr);
#endif

#ifdef ceu_out_wclock
    if (nxt)
        ceu_out_wclock(dt);
#endif
}

#endif

/* ASYNCS ***************************************************************/

#ifdef CEU_ASYNCS
int async_cur = 0;
#endif

/**********************************************************************/

int ceu_go_init (int* ret)
{
#ifdef CEU_WCLOCKS
    WCLOCK_late = 0;
#endif
    trk_insert(0, PR_MAX, Init);
    return go(ret);
}

#ifdef CEU_EXTS
int ceu_go_event (int* ret, int id, void* data) {
    DATA = data;
    trigger(id);
#ifdef CEU_WCLOCKS
    WCLOCK_late--;
#endif
    return go(ret);
}
#endif

#ifdef CEU_ASYNCS
int ceu_go_async (int* ret, int* pending)
{
    int i,s=0;

    tceu_lbl* ASY0 = PTR(CEU_ASYNC0,tceu_lbl*);

    for (i=0; i<CEU_ASYNCS; i++) {
        int idx = (async_cur+i) % CEU_ASYNCS;
        if (ASY0[idx] != Inactive) {
            trk_insert(0, PR_MAX, ASY0[idx]);
            ASY0[idx] = Inactive;
            async_cur = (idx+1) % CEU_ASYNCS;
#ifdef CEU_WCLOCKS
            WCLOCK_late--;
#endif
            s = go(ret);
            break;
        }
    }

    if (pending != NULL) {
        for (i=0; i<CEU_ASYNCS; i++) {
            if (ASY0 != Inactive) {
                *pending = 1;
                break;
            }
        }
    }

    return s;
}
#endif

int ceu_go_wclock (int* ret, s32 dt)
{
#ifdef CEU_WCLOCKS
    int i;
    s32 togo = CEU_WCLOCK_NONE;

    tceu_wclock* CLK0 = PTR(CEU_WCLOCK0,tceu_wclock*);

    if (!TMR_cur)
        return 0;

    if (TMR_cur->togo <= dt) {
        togo = TMR_cur->togo;
        WCLOCK_late = dt - TMR_cur->togo;   // how much late the wclock is
    }

    // spawns all togo/ext
    // finds the next TMR_cur
    // decrements all togo
    TMR_cur = NULL;
    for (i=0; i<CEU_WCLOCKS; i++)
    {
        tceu_wclock* tmr = &CLK0[i];
        if (tmr->lbl == Inactive)
            continue;

        if (tmr->togo == togo) {
            spawn(&tmr->lbl);               // spawns sharing phys/ext
        } else {
            tmr->togo -= dt;
            ceu_wclock_lt(tmr);             // next? (sets TMR_cur)
        }
    }

#ifdef ceu_out_wclock
    if (TMR_cur)
        ceu_out_wclock(TMR_cur->togo);
    else
        ceu_out_wclock(CEU_WCLOCK_NONE);
#endif

    {int s = go(ret);
    WCLOCK_late = 0;
    return s;}
#else
    return 0;
#endif
}

int go (int* ret)
{
    tceu_trk trk;
    int _lbl_;

#ifdef CEU_EMITS
    int _step_ = PR_MIN;
#endif

    while (trk_remove(&trk))
    {
#ifdef CEU_EMITS
        if (trk.prio < 0) {
            tceu_lbl* EMT0 = PTR(CEU_EMIT0,tceu_lbl*);
            tceu_lbl T[N_TRACKS];
            int n = 0;
            _step_ = trk.prio;
            while (1) {
                tceu_lbl lbl = EMT0[trk.lbl]; // trk.lbl is actually a off
                if (lbl != Inactive)
                    T[n++] = lbl;
                if (!trk_peek(&trk) || (trk.prio < _step_))
                    break;
                else
                    trk_remove(NULL);
            }
            for (;n>0;)
                trk_insert(0, PR_MAX, T[--n]);
            continue;
        } else
#endif
            _lbl_ = trk.lbl;
_SWITCH_:
//fprintf(stderr,"TRK: %d\n", _lbl_);
        switch (_lbl_)
        {
            case Init:
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

#ifdef IN_Start
    //*PVAL(int,IN_Start) = (argc>1) ? atoi(argv[1]) : 0;
    if (ceu_go_event(&ret, IN_Start, NULL))
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
