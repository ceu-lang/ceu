#include <string.h>
#include <limits.h>

#define PR_MAX  0x7F
#define PR_MIN  (-0x7F)

#define N_WCLOCKS   (=== N_WCLOCKS ===)
#define N_TRACKS    (1+ === N_TRACKS ===)
#define N_ASYNCS    (=== N_ASYNCS ===)
#define N_EMITS     (=== N_EMITS ===)
#define N_GTES      (=== N_GTES ===)
#define N_ANDS      (=== N_ANDS ===)
#define N_VARS      (=== N_VARS ===)

// Macros that can be defined:
// ceu_out_pending()   (1)
// ceu_out_wclock(us)
// ceu_out_event(id, len, data)

typedef === TCEU_GTE === tceu_gte;   // |tceu_lbl|>=|tceu_gte|
typedef === TCEU_LBL === tceu_lbl;

int go (int* ret);

enum {
=== LABELS ===
};

=== DEFS ===

=== HOST ===

void* DATA = NULL;

char ANDS[N_ANDS];      // TODO: bitfield
tceu_lbl GTES[N_GTES];
tceu_gte TRGS[] = { === TRGS === };

char VARS[N_VARS];

#ifdef CEU_WCLOCKS
u32 _extl_;     // TODO: suficiente?
u32 _extlmax_;  // needed for wclocks
#endif

// returns a pointer to the received value
int INT_v;
int* INT_f (int v) {
    INT_v = v;
    return &INT_v;
}

/* TRACKS ***************************************************************/

typedef struct {
#ifndef CEU_TRK_NOPRIO
    s8       prio;
#endif
    tceu_lbl lbl;
} QTrack;

int TRACKS_n = 0;

#ifdef CEU_TRK_NOPRIO
QTrack TRACKS[N_TRACKS];
#else
QTrack TRACKS[N_TRACKS+1];  // 0 is reserved
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

#if N_EMITS > 0
int trk_peek (QTrack* trk)
{
    *trk = TRACKS[1];
    return TRACKS_n > 0;
}
#endif

int trk_remove (QTrack* trk)
{
    if (TRACKS_n == 0)
        return 0;

#ifdef CEU_TRK_NOPRIO
    *trk = TRACKS[--TRACKS_n];
    return 1;
#else
    {int i,cur;
    QTrack* last;

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

void spawn (tceu_gte gte)
{
    tceu_lbl lbl = GTES[gte];
    if (lbl != Inactive) {
        trk_insert(0, PR_MAX, lbl);
        GTES[gte] = Inactive;
    }
}

void trigger (int trg)
{
    int i;
    for (i=1 ; i<=((int)TRGS[trg]) ; i++)
        spawn(TRGS[trg+i]);
}

/* WCLOCKS ***************************************************************/

#ifdef CEU_WCLOCKS

#define WCLOCK_DISABLED LONG_MAX

s32 WCLOCK_late;

typedef struct {
    s32 togo;
    u32 extl;
    tceu_gte gte;
} QWClock;

QWClock  WCLOCKS[N_WCLOCKS] = { === WCLOCKS === };
QWClock* TMR_cur = NULL;

int QWClock_lt (QWClock* tmr) {
    if ( tmr->togo != WCLOCK_DISABLED && (
            (!TMR_cur || tmr->togo<TMR_cur->togo ||
                (tmr->togo==TMR_cur->togo  &&  tmr->extl<TMR_cur->extl))
        )) {
        TMR_cur = tmr;
        return 1;
    }
    return 0;
}

void tmr_enable (s32 us, int idx) {
    QWClock* tmr = &WCLOCKS[idx];
    s32 dt = us - WCLOCK_late;
#ifdef ceu_out_wclock
    int nxt;
#endif

    tmr->togo = dt;
    tmr->extl = _extl_;
#ifdef ceu_out_wclock
    nxt = QWClock_lt(tmr);
#else
    QWClock_lt(tmr);
#endif

#ifdef ceu_out_wclock
    if (nxt)
        ceu_out_wclock(dt);
#endif
}

#endif

/* ASYNCS ***************************************************************/

#ifdef CEU_ASYNCS
tceu_gte Q_ASYNC[N_ASYNCS];
int async_ini = 0;
int async_end = 0;
int async_cnt = 0;

void asy_insert (tceu_gte gte)
{
    int i;
    // TODO: inef
    // TODO: create func and move calls to escapes
    // checks if the gate is already on Q_ASYNC
    for (i=async_ini; i!=async_end; i=(i+1)%N_ASYNCS) {
        if (Q_ASYNC[i] == gte)
            return;
    }

    Q_ASYNC[async_end++] = gte;
    async_end %= N_ASYNCS;
    async_cnt++;
}
#endif

/**********************************************************************/

int ceu_go_init (int* ret)
{
    memset(GTES, 0, N_GTES*sizeof(tceu_lbl));

#ifdef CEU_WCLOCKS
    WCLOCK_late = 0;
    _extlmax_ = _extl_ = 0;
#endif

    trk_insert(0, PR_MAX, Init);

    return go(ret);
}

int ceu_go_event (int* ret, int id, void* data) {
    DATA = data;
    trigger(id);

#ifdef CEU_WCLOCKS
    WCLOCK_late = 0;
    _extl_ = ++_extlmax_;
#endif

    return go(ret);
}

#ifdef CEU_ASYNCS
int ceu_go_async (int* ret, int* count)
{
    if (count)
        *count = async_cnt;
    if (async_cnt == 0)
        return 0;

    spawn(Q_ASYNC[async_ini]);
    async_ini = (async_ini+1) % N_ASYNCS;
    async_cnt--;

#ifdef CEU_WCLOCKS
    WCLOCK_late = 0;
    _extl_ = ++_extlmax_;
#endif

    return go(ret);
}
#endif

int ceu_go_wclock (int* ret, s32 dt)
{
#ifdef CEU_WCLOCKS
    int i;
    s32 togo = WCLOCK_DISABLED;

    if (!TMR_cur)
        return 0;

    if (TMR_cur->togo <= dt) {
        togo   = TMR_cur->togo;
        _extl_ = TMR_cur->extl;
        WCLOCK_late = dt - TMR_cur->togo;   // how much late the wclock is
    }

    // spawns all togo/ext
    // finds the next TMR_cur
    // decrements all togo
    TMR_cur = NULL;
    for (i=0; i<N_WCLOCKS; i++)
    {
        QWClock* tmr = &WCLOCKS[i];
        if (tmr->togo == WCLOCK_DISABLED)
            continue;

        if (tmr->togo==togo && tmr->extl==_extl_) {
            tmr->togo = WCLOCK_DISABLED;// disables it
            spawn(tmr->gte);            // spawns sharing phys/ext
        } else {
            tmr->togo -= dt;
            QWClock_lt(tmr);            // next? (sets TMR_cur)
        }
    }

#ifdef ceu_out_wclock
    if (TMR_cur)
        ceu_out_wclock(TMR_cur->togo);
    else
        ceu_out_wclock(WCLOCK_DISABLED);
#endif

    return go(ret);

#else
    return 0;
#endif
}

int go (int* ret)
{
    QTrack trk;
    int _lbl_;

#if N_EMITS > 0
    int _step_ = PR_MIN;
#endif

    while (trk_remove(&trk))
    {
#if N_EMITS > 0
        if (trk.prio < 0) {
            tceu_lbl T[N_EMITS];
            int n = 0;
            _step_ = trk.prio;
            while (1) {
                tceu_lbl lbl = GTES[trk.lbl]; // trk.lbl is actually a gate
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
