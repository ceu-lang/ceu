#include <string.h>

#define PR_MAX  0x7F
#define PR_MIN  (-0x7F)

#define N_TIMERS    (1+ === N_TIMERS ===)
#define N_TRACKS    (1+ === N_TRACKS ===)
#define N_ASYNCS    (=== N_ASYNCS ===)
#define N_EMITS     (=== N_EMITS ===)
#define N_GTES      (=== N_GTES ===)
#define N_ANDS      (=== N_ANDS ===)
#define N_VARS      (=== N_VARS ===)

// Macros that can be defined:
// ceu_out_pending()   (1)
// ceu_out_timer(ms)
// ASSERT

typedef u64 tceu_time;
typedef s16 tceu_gte;   // lbl=gte (must have the same sizes)
typedef s16 tceu_lbl;

#include "binheap.h"
#include "binheap.c"

int go (int* ret, tceu_time now);

=== HOST ===

enum {
    Inactive  = 0,
    Init      = 1,
=== LABELS ===
};

=== EVTS ===

void* DATA = NULL;

char ANDS[N_ANDS];      // TODO: bitfield
tceu_lbl GTES[N_GTES];
tceu_gte TRGS[] = { === TRGS === };

#define PVAR(tp,reg) ((tp*)(VARS+reg))
char VARS[N_VARS];

#if N_TIMERS > 1
u64 _extl_;
u64 _extlmax_;  // needed for timers
#endif

/* TRACKS ***************************************************************/

typedef struct {
    s8       prio;
    tceu_lbl lbl;
} QTrack;

int QTrack_prio (void* v1, void* v2) {
    return ((QTrack*)v1)->prio > ((QTrack*)v2)->prio;
}

Queue  Q_TRACKS;
QTrack Q_TRACKS_BUF[N_TRACKS];

void qins_track (s8 prio, tceu_lbl lbl) {
    QTrack v = { prio, lbl };
    q_insert(&Q_TRACKS, &v);
}

void qins_track_chk (s8 prio, tceu_lbl lbl) {
    QTrack v = { prio, lbl };
    int i;
    for (i=1; i<=Q_TRACKS.n; i++)
        if (lbl == Q_TRACKS_BUF[i].lbl)
            return;
    q_insert(&Q_TRACKS, &v);
}

void spawn (tceu_gte gte)
{
    tceu_lbl lbl = GTES[gte];
    if (lbl != Inactive) {
        qins_track(PR_MAX, lbl);
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
#if N_TIMERS > 1

tceu_time TIME_now = 0;
tceu_time TIME_late;
int       TIME_expired = 0;

typedef struct {
    tceu_time phys;
    u64 extl;
    tceu_gte gte;
} QTimer;

int QTimer_prio (void* v1, void* v2) {
    QTimer* t1 = (QTimer*) v1;
    QTimer* t2 = (QTimer*) v2;
    int ret = t1->phys < t2->phys  ||
            (t1->phys == t2->phys  &&  t1->extl < t2->extl);
    return ret;
}

Queue  Q_TIMERS;
QTimer Q_TIMERS_BUF[N_TIMERS];

void qins_timer (tceu_time ms, tceu_gte gte) {
    int i;
    QTimer v = { 0, _extl_, gte };

    s64 dt = ms - TIME_late;
    v.phys = TIME_now + dt;

    if (dt <= 0) { // already expired
        TIME_expired = 1;
    }
#ifdef ceu_out_timer
    else {         // check if out_timer is needed (empty Q or new minimum timer)
        QTimer min;
        if (!q_peek(&Q_TIMERS,&min) || (v.phys<min.phys))
            ceu_out_timer(dt);
    }
#endif


    // TODO: inef
    // checks if the gate is already on Q_TIMERS
    for (i=1; i<=Q_TIMERS.n; i++) {
        if (Q_TIMERS_BUF[i].gte == gte) {
            q_remove_i(&Q_TIMERS, i, NULL);
            break;
        }
    }
    q_insert(&Q_TIMERS, &v);
}
#endif

/* ASYNCS ***************************************************************/

#if N_ASYNCS > 0
tceu_gte Q_ASYNC[N_ASYNCS];
int async_ini = 0;
int async_end = 0;
int async_cnt = 0;

void qins_async (tceu_gte gte)
{
    int i;
    // TODO: maybe this is not needed
    // TODO: inef
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

int ceu_go_init (int* ret, tceu_time now)
{
    memset(GTES, 0, N_GTES);

    q_init(&Q_TRACKS, Q_TRACKS_BUF, N_TRACKS, sizeof(QTrack), QTrack_prio);

#if N_TIMERS > 1
    q_init(&Q_TIMERS, Q_TIMERS_BUF, N_TIMERS, sizeof(QTimer), QTimer_prio);
    TIME_now  = now;
    TIME_late = 0;
    _extlmax_ = _extl_ = 0;
#endif

    qins_track(PR_MAX, Init);

    return go(ret, 0);
}

int ceu_go_event (int* ret, int id, void* data) {
    DATA = data;
    trigger(id);

#if N_TIMERS > 1
    TIME_late = 0;
    _extl_ = ++_extlmax_;
#endif

    return go(ret, 0);
}

#if N_ASYNCS > 0
int ceu_go_async (int* ret, int* count)
{
    if (count)
        *count = async_cnt;
    if (async_cnt == 0)
        return 0;

    spawn(Q_ASYNC[async_ini++]);
    async_ini %= N_ASYNCS;
    async_cnt--;

#if N_TIMERS > 1
    TIME_late = 0;
    _extl_ = ++_extlmax_;
#endif

    return go(ret, 0);
}
#endif

int ceu_go_time (int* ret, tceu_time now)
{
#if N_TIMERS > 1
    return go(ret, now);
#else
    return 0;
#endif
}

int go (int* ret, tceu_time now)
{
#if N_TIMERS > 1
    if (now == 0)
        goto GO;
    else
        TIME_now = now;

GO_TIME:
    {
        QTimer min, nxt;

        if (!q_peek(&Q_TIMERS, &min))
            return 0;

        if (min.phys > TIME_now)
            return 0;

        q_remove(&Q_TIMERS,NULL);

        TIME_late = TIME_now - min.phys; // how much late the timer is
        spawn(min.gte);

        while (q_peek(&Q_TIMERS,&nxt))
        {
            // spawn all sharing min phys/ext time
            if (nxt.phys==min.phys && nxt.extl==min.extl) {
                q_remove(&Q_TIMERS, NULL);
                spawn(nxt.gte);
            } else {
                if (nxt.phys <= TIME_now)
                    TIME_expired = 1;                   // spawn in next cycle
#ifdef ceu_out_timer
                else
                    ceu_out_timer(nxt.phys - TIME_now); // not yet to spawn
#endif
                break;
            }
        }

        _extl_ = min.extl;
        goto GO;    //return go(ret);
    }

GO:
#endif  // N_TIMERS > 1
    {
        QTrack trk;
        int _lbl_;

#if N_EMITS > 0
        int _step_ = PR_MIN;
#endif

        while (q_remove(&Q_TRACKS,&trk))
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
                    if (!q_peek(&Q_TRACKS,&trk) || (trk.prio < _step_))
                        break;
                    else
                        q_remove(&Q_TRACKS,NULL);
                }
                for (;n>0;)
                    qins_track(PR_MAX, T[--n]);
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

#if N_TIMERS > 1
        if (TIME_expired) {
            TIME_expired = 0;
            goto GO_TIME;   //return ceu_go_time(ret, TIME_now);
        }
#endif
        return 0;
    }
}

int ceu_go_polling (tceu_time now)
{
    int ret = 0;
#if N_ASYNCS > 0
    int async_cnt;
#endif

    if (ceu_go_init(&ret, now))
        return ret;

#ifdef IO_Start
    //*PVAL(int,IO_Start) = (argc>1) ? atoi(argv[1]) : 0;
    if (ceu_go_event(&ret, IO_Start, NULL))
        return ret;
#endif

#if N_ASYNCS > 0
    for (;;) {
        if (ceu_go_async(&ret,&async_cnt))
            return ret;
        if (async_cnt == 0)
            break;              // returns nothing!
    }
#endif

    return ret;
}
