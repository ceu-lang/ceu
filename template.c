#include <string.h>
#include <limits.h>

#define PR_MAX 0x7F
#define PR_MIN (-0x7F)

#define PTR(str,tp) ((tp)(CEU->mem + str ))

#define N_TRACKS    (=== N_TRACKS ===)
#define CEU_WCLOCK0 (=== CEU_WCLOCK0 ===)
#define CEU_ASYNC0  (=== CEU_ASYNC0 ===)
#define CEU_EMIT0   (=== CEU_EMIT0 ===)
#define CEU_FIN0    (=== CEU_FIN0 ===)

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

typedef struct {
#ifndef CEU_TRK_NOPRIO
    s8 prio;
#endif
    tceu_lbl lbl;
} tceu_trk;

enum {
=== LABELS ===
};

int ceu_go (int* ret);

=== HOST ===

typedef struct {
    char            mem[=== N_MEM ===];

    int             tracks_n;
#ifdef CEU_TRK_NOPRIO
    tceu_trk        tracks[N_TRACKS];
#else
    tceu_trk        tracks[N_TRACKS+1];  // 0 is reserved
#endif

#ifdef CEU_EXTS
    void*           ext_data;
    int             ext_int;
#endif

#ifdef CEU_WCLOCKS
    int             wclk_late;
    tceu_wclock*    wclk_cur;
#endif

#ifdef CEU_ASYNCS
    int             async_cur;
#endif
} tceu;

tceu CEU_ = { 0, 0, 0, 0, 0, 0, 0, 0, 0};
tceu* CEU = &CEU_;

#ifdef CEU_EXTS
// returns a pointer to the received value
int* ceu_ext_f (int v) {
    CEU->ext_int = v;
    return &CEU->ext_int;
}
#endif

#ifdef CEU_EMITS
int ceu_track_peek (tceu_trk* trk)
{
    *trk = CEU->tracks[1];
    return CEU->tracks_n > 0;
}
#endif

#ifdef CEU_FINS
void ceu_fins (int i, int j)
{
    for (; i<j; i++) {
        tceu_lbl* fin0 = PTR(CEU_FIN0,tceu_lbl*);
        if (fin0[i] != Inactive)
            ceu_track_ins(0, PR_MAX-i, fin0[i]);
    }
}
#endif

#ifdef CEU_WCLOCKS

#define CEU_WCLOCK_NONE LONG_MAX

int ceu_wclock_lt (tceu_wclock* tmr) {
    if (!CEU->wclk_cur || tmr->togo<CEU->wclk_cur->togo) {
        CEU->wclk_cur = tmr;
        return 1;
    }
    return 0;
}

void ceu_wclock_enable (int idx, s32 us, tceu_lbl lbl) {
    tceu_wclock* tmr = &(PTR(CEU_WCLOCK0,tceu_wclock*)[idx]);
    s32 dt = us - CEU->wclk_late;
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

/**********************************************************************/

#if defined CEU_TRK_NOPRIO
#define ceu_track_ins(chk,prio,lbl) ceu_track_ins_noprio(lbl)
#elif defined CEU_TRK_NOCHK
#define ceu_track_ins(chk,prio,lbl) ceu_track_ins_nochk(prio,lbl)
#endif

#if defined CEU_TRK_NOPRIO
void ceu_track_ins_noprio (tceu_lbl lbl)
#elif defined CEU_TRK_NOCHK
void ceu_track_ins_nochk (s8 prio, tceu_lbl lbl)
#else
void ceu_track_ins (int chk, s8 prio, tceu_lbl lbl)
#endif
{
#ifndef CEU_TRK_NOCHK
    {int i;
    if (chk) {
        for (i=1; i<=CEU->tracks_n; i++) {
#ifdef CEU_SIMUL
            if (lbl==CEU->tracks[i].lbl) {
                CEU->tracks[i].lbl = Inactive;
                S.chkPrio = 1;
            }
            if (prio > CEU->tracks[i].prio)
                S.hasPrio = 1;
#else
            if (lbl==CEU->tracks[i].lbl && prio==CEU->tracks[i].prio)
                return;
#endif
        }
    }}
#endif

#ifdef CEU_TRK_NOPRIO
    CEU->tracks[CEU->tracks_n++].lbl = lbl;
#else
    {int i;
    for (i=++CEU->tracks_n; (i>1) && (prio>CEU->tracks[i/2].prio); i/=2)
        CEU->tracks[i] = CEU->tracks[i/2];
    CEU->tracks[i].prio = prio;
    CEU->tracks[i].lbl  = lbl;}
#endif

#ifdef CEU_SIMUL
    if (CEU->tracks_n > S.n_tracks)
        S.n_tracks = CEU->tracks_n;
#endif
}

int ceu_track_rem (tceu_trk* trk)
{
    if (CEU->tracks_n == 0)
        return 0;

#ifdef CEU_TRK_NOPRIO
    *trk = CEU->tracks[--CEU->tracks_n];
    return 1;
#else
    {int i,cur;
    tceu_trk* last;

    if (trk)
        *trk = CEU->tracks[1];

    last = &CEU->tracks[CEU->tracks_n--];

    for (i=1; i*2<=CEU->tracks_n; i=cur)
    {
        cur = i * 2;
        if (cur!=CEU->tracks_n && CEU->tracks[cur+1].prio>CEU->tracks[cur].prio)
            cur++;

        if (CEU->tracks[cur].prio>last->prio)
            CEU->tracks[i] = CEU->tracks[cur];
        else
            break;
    }
    CEU->tracks[i] = *last;
    return 1;}
#endif
}

void ceu_spawn (tceu_lbl* lbl)
{
    if (*lbl != Inactive) {
        ceu_track_ins(0, PR_MAX, *lbl);
        *lbl = Inactive;
    }
}

void ceu_trigger (tceu_off off)
{
    int i;
    int n = CEU->mem[off];
    for (i=0 ; i<n ; i++) {
        ceu_spawn((tceu_lbl*)&CEU->mem[off+1+(i*sizeof(tceu_lbl))]);
    }
}

/**********************************************************************/

int ceu_go_init (int* ret)
{
    ceu_track_ins(0, PR_MAX, Init);
    return ceu_go(ret);
}

#ifdef CEU_EXTS
int ceu_go_event (int* ret, int id, void* data) {
    CEU->ext_data = data;
    ceu_trigger(id);
#ifdef CEU_WCLOCKS
    CEU->wclk_late--;
#endif
    return ceu_go(ret);
}
#endif

#ifdef CEU_ASYNCS
int ceu_go_async (int* ret, int* pending)
{
    int i,s=0;

    tceu_lbl* ASY0 = PTR(CEU_ASYNC0,tceu_lbl*);

    for (i=0; i<CEU_ASYNCS; i++) {
        int idx = (CEU->async_cur+i) % CEU_ASYNCS;
        if (ASY0[idx] != Inactive) {
            ceu_track_ins(0, PR_MAX, ASY0[idx]);
            ASY0[idx] = Inactive;
            CEU->async_cur = (idx+1) % CEU_ASYNCS;
#ifdef CEU_WCLOCKS
            CEU->wclk_late--;
#endif
            s = ceu_go(ret);
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

    if (!CEU->wclk_cur)
        return 0;

    if (CEU->wclk_cur->togo <= dt) {
        togo = CEU->wclk_cur->togo;
        CEU->wclk_late = dt - CEU->wclk_cur->togo;   // how much late the wclock is
    }

    // spawns all togo/ext
    // finds the next CEU->wclk_cur
    // decrements all togo
    CEU->wclk_cur = NULL;
    for (i=0; i<CEU_WCLOCKS; i++)
    {
        tceu_wclock* tmr = &CLK0[i];
        if (tmr->lbl == Inactive)
            continue;

        if (tmr->togo == togo) {
            ceu_spawn(&tmr->lbl);               // spawns sharing phys/ext
        } else {
            tmr->togo -= dt;
            ceu_wclock_lt(tmr);             // next? (sets CEU->wclk_cur)
        }
    }

#ifdef ceu_out_wclock
    if (CEU->wclk_cur)
        ceu_out_wclock(CEU->wclk_cur->togo);
    else
        ceu_out_wclock(CEU_WCLOCK_NONE);
#endif

    {int s = ceu_go(ret);
    CEU->wclk_late = 0;
    return s;}
#else
    return 0;
#endif
}

int ceu_go (int* ret)
{
    tceu_trk trk;
    int _lbl_;

#ifdef CEU_EMITS
    int _step_ = PR_MIN;
#endif

    while (ceu_track_rem(&trk))
    {
#ifdef CEU_EMITS
        if (trk.prio < 0) {
            tceu_lbl* EMT0 = PTR(CEU_EMIT0,tceu_lbl*);
            tceu_lbl T[N_TRACKS+1];
            int n = 0;
            _step_ = trk.prio;
            while (1) {
                tceu_lbl lbl = EMT0[trk.lbl]; // trk.lbl is actually a off
                if (lbl != Inactive)
                    T[n++] = lbl;
                if (!ceu_track_peek(&trk) || (trk.prio < _step_))
                    break;
                else
                    ceu_track_rem(NULL);
            }
            for (;n>0;)
                ceu_track_ins(0, PR_MAX, T[--n]);
            continue;
        } else
#endif
            _lbl_ = trk.lbl;
_SWITCH_:
//fprintf(stderr,"TRK: %d\n", _lbl_);

#ifdef CEU_SIMUL
        S.states[S.cur].vec[S.states[S.cur].vec_n++] = _lbl_;
#endif

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
