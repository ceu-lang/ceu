#include <string.h>

#define PR_MAX  0x7F
#define PR_MIN  (-0x7F)

#define N_TIMERS    (=== N_TIMERS ===)
#define N_TRACKS    (1+ === N_TRACKS ===)
#define N_ASYNCS    (=== N_ASYNCS ===)
#define N_EMITS     (=== N_EMITS ===)
#define N_GTES      (=== N_GTES ===)
#define N_ANDS      (=== N_ANDS ===)
#define N_VARS      (=== N_VARS ===)

// Macros that can be defined:
// ceu_out_pending()   (1)
// ceu_out_timer(ns)
// ceu_out_event(id, len, data)
// ASSERT

typedef s16 tceu_gte;   // lbl=gte (must have the same sizes)
typedef s16 tceu_lbl;

int go (int* ret);

enum {
    CEU_TERM   = 0,
    CEU_NONE   = 1,
    CEU_TMREXP = 2,
};

enum {
    Inactive  = 0,
    Init      = 1,
=== LABELS ===
};

=== EVTS ===

=== HOST ===

void* DATA = NULL;

char ANDS[N_ANDS];      // TODO: bitfield
tceu_lbl GTES[N_GTES];
tceu_gte TRGS[] = { === TRGS === };

char VARS[N_VARS];

#if N_TIMERS > 0
u32 _extl_;     // TODO: suficiente?
u32 _extlmax_;  // needed for timers
#endif

// returns a pointer to the received value
int INT_v;
int* INT_f (int v) {
    INT_v = v;
    return &INT_v;
}

/* TRACKS ***************************************************************/

typedef struct {
    s8       prio;
    tceu_lbl lbl;
} QTrack;

QTrack TRACKS[N_TRACKS+1];    // 0 is reserved
int    TRACKS_n = 0;

void trk_insert (int chk, s8 prio, tceu_lbl lbl)
{
    int i;

    if (chk) {
        for (i=1; i<=TRACKS_n; i++)
            if (lbl == TRACKS[i].lbl)
                return;
    }

#ifdef ASSERT
    ASSERT(TRACKS_n < N_TRACKS);
#endif

    for (i=++TRACKS_n; (i>1) && (prio>TRACKS[i/2].prio); i/=2)
        TRACKS[i] = TRACKS[i/2];

    TRACKS[i].prio = prio;
    TRACKS[i].lbl  = lbl;
}

int trk_peek (QTrack* trk)
{
    if (TRACKS_n == 0)
        return 0;
    else {
        *trk = TRACKS[1];
        return 1;
    }
}

int trk_remove (QTrack* trk)
{
    int i,cur;
    QTrack* last;

    if (TRACKS_n == 0)
        return 0;

    if (trk != NULL)
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
    return 1;
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

/* TIMERS ***************************************************************/

u64 TIME_now = 0;

#if N_TIMERS > 0
u64 TIME_late;
int TIME_expired = 0;

typedef struct {
    u64 phys;
    u32 extl;
    tceu_gte gte;
} QTimer;

QTimer  TIMERS[N_TIMERS] = { === TIMERS === };
QTimer* TMR_cur = NULL;

int QTimer_lt (QTimer* tmr) {
    if ( tmr->phys != 0 && (
            (TMR_cur==NULL || tmr->phys<TMR_cur->phys ||
                (tmr->phys==TMR_cur->phys  &&  tmr->extl<TMR_cur->extl))
        )) {
        TMR_cur = tmr;
        return 1;
    }
    return 0;
}

void tmr_enable (u64 ns, int idx) {
    QTimer* tmr = &TIMERS[idx];
    s64 dt = ns - TIME_late;
    int nxt;

    tmr->phys = TIME_now + dt;
    tmr->extl = _extl_;
    nxt = QTimer_lt(tmr);

    if (dt <= 0) { // already expired
        TIME_expired = 1;
    }
#ifdef ceu_out_timer
    else {         // check if out_timer is needed (no cur or new minimum timer)
        if (new)
            ceu_out_timer(dt);
    }
#endif
}

u64* ceu_timer_nxt () {
    if (TMR_cur == NULL)
        return NULL;
    else
        return &TMR_cur->phys;
}
#endif

/* ASYNCS ***************************************************************/

#if N_ASYNCS > 0
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
#ifdef ASSERT
    ASSERT(async_cnt <= N_ASYNCS, 6);
#endif
}
#endif

/**********************************************************************/

int ceu_go_init (int* ret, u64 now)
{
    memset(GTES, 0, N_GTES);

    TIME_now  = now;
#if N_TIMERS > 0
    TIME_late = 0;
    _extlmax_ = _extl_ = 0;
#endif

    trk_insert(0, PR_MAX, Init);

    return go(ret);
}

int ceu_go_event (int* ret, int id, void* data) {
    DATA = data;
    trigger(id);

#if N_TIMERS > 0
    TIME_late = 0;
    _extl_ = ++_extlmax_;
#endif

    return go(ret);
}

#if N_ASYNCS > 0
int ceu_go_async (int* ret, int* count)
{
    if (count)
        *count = async_cnt;
    if (async_cnt == 0)
        return CEU_NONE;

    spawn(Q_ASYNC[async_ini]);
    async_ini = (async_ini+1) % N_ASYNCS;
    async_cnt--;

#if N_TIMERS > 0
    TIME_late = 0;
    _extl_ = ++_extlmax_;
#endif

    return go(ret);
}
#endif

int ceu_go_time (int* ret, u64 now)
{
#if N_TIMERS > 0
    int i;
    u64 phys;

    TIME_now = now;

    if (TMR_cur == NULL)
        return CEU_NONE;

    phys   = TMR_cur->phys;
    _extl_ = TMR_cur->extl;

    if (phys > TIME_now)
        return CEU_NONE;

    TIME_late = TIME_now - phys; // how much late the timer is

    // spawns all phys/ext
    // finds the next TMR_cur
    TMR_cur = NULL;
    for (i=0; i<N_TIMERS; i++)
    {
        QTimer* tmr = &TIMERS[i];
        if (tmr->phys==phys && tmr->extl==_extl_) {
            tmr->phys = 0;          // disables it
            spawn(tmr->gte);        // spawns sharing phys/ext
        } else {
            QTimer_lt(tmr);         // check if this is the next
            if (tmr->phys <= TIME_now)
                TIME_expired = 1;   // spawn in next cycle
        }
    }

#ifdef ceu_out_timer
    if (TMR_cur!=NULL && !TIME_expired)
        ceu_out_timer(TMR_cur->phys - TIME_now); // not yet to spawn
#endif

    return go(ret);
#else

    TIME_now = now;
    return CEU_NONE;
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
                int lbl = GTES[-trk.lbl];     // it is actually a gate
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

#if N_TIMERS > 0
    if (TIME_expired) {
        TIME_expired = 0;
        return CEU_TMREXP;
    }
#endif
    return CEU_NONE;
}

int ceu_go_polling (u64 now)
{
    int ret = 0;
#if N_ASYNCS > 0
    int async_cnt;
#endif

    if (ceu_go_init(&ret, now) == CEU_TERM)
        return ret;

#ifdef IN_Start
    //*PVAL(int,IN_Start) = (argc>1) ? atoi(argv[1]) : 0;
    if (ceu_go_event(&ret, IN_Start, NULL) == CEU_TERM)
        return ret;
#endif

#if N_ASYNCS > 0
    for (;;) {
        if (ceu_go_async(&ret,&async_cnt) == CEU_TERM)
            return ret;
        if (async_cnt == 0)
            break;              // returns nothing!
    }
#endif

    return ret;
}
