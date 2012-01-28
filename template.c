#include <string.h>

#define PR_MAX  0xFF

#define N_TIMERS    (1+ === N_TIMERS ===)
#define N_TRACKS    (1+ === N_TRACKS ===)
#define N_INTRAS    (1+ === N_INTRAS ===)
#define N_ASYNCS    (=== N_ASYNCS ===)
#define N_GTES      === N_GTES ===
#define N_ANDS      === N_ANDS ===
#define N_VARS      === N_VARS ===

// Macros that can be defined:
// ceu_out_pending()   (1)
// ceu_out_timer(ms)
// ASSERT

typedef u32 tceu_time;
typedef u16 tceu_gte;
typedef u16 tceu_lbl;

#include "binheap.h"
#include "binheap.c"

int go (int* ret);

=== HOST ===

enum {
    Inactive  = 0,
    Init      = 1,
=== LABELS ===
};

=== EVTS ===

void* DATA;

char ANDS[N_ANDS];      // TODO: bitfield
tceu_lbl GTES[N_GTES];
tceu_gte TRGS[] = { === TRGS === };

#define PVAR(tp,reg) ((tp*)(VARS+reg))
char VARS[N_VARS];

#if N_INTRAS > 1
int _intl_;
#endif

#if N_TIMERS > 1
int _extl_;
int _extlmax_;  // needed for timers
#endif

/* INTRAS ***************************************************************/
#if N_INTRAS > 1

typedef struct {
    u8       intl;
    tceu_gte gte;
} QIntra;

int QIntra_prio (void* v1, void* v2) {
    return ((QIntra*)v1)->intl > ((QIntra*)v2)->intl;
}

Queue  Q_INTRA;
QIntra Q_INTRA_BUF[N_INTRAS];

void qins_intra (u8 intl, tceu_gte gte) {
    QIntra v = { intl, gte };
    q_insert(&Q_INTRA, &v);
}
#endif

/* TRACKS ***************************************************************/

typedef struct {
    u8       prio;
    tceu_lbl lbl;
} QTrack;

int QTrack_prio (void* v1, void* v2) {
    return ((QTrack*)v1)->prio > ((QTrack*)v2)->prio;
}

Queue  Q_TRACKS;
QTrack Q_TRACKS_BUF[N_TRACKS];

void qins_track (u8 prio, tceu_lbl lbl) {
    QTrack v = { prio, lbl };
    q_insert(&Q_TRACKS, &v);
}

void qins_track_chk (u8 prio, tceu_lbl lbl) {
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
    if (lbl >= Init) {
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

//tceu_time TIME_base = 0;
tceu_time TIME_now = 0;
tceu_time TIME_late;
int       TIME_expired = 0;

typedef struct {
    tceu_time phys;
    u8 extl;            // TODO: garantir/zerar u8
#if N_INTRAS > 1
    u8 intl;            // TODO: garantir u8
#endif
    tceu_gte gte;
} QTimer;

int QTimer_prio (void* v1, void* v2) {
    QTimer* t1 = (QTimer*) v1;
    QTimer* t2 = (QTimer*) v2;
    int ret = t1->phys < t2->phys || (
            (t1->phys == t2->phys) && (
                t1->extl < t2->extl
#if N_INTRAS > 1
                    || (t1->extl==t2->extl && t1->intl>t2->intl)
#endif
                ));
    return ret;
}

Queue  Q_TIMERS;
QTimer Q_TIMERS_BUF[N_TIMERS];

void qins_timer (tceu_time ms, tceu_gte gte) {
    int i;
#if N_INTRAS > 1
    QTimer v = { 0, _extl_, _intl_, gte };
#else
    QTimer v = { 0, _extl_, gte };
#endif

    s32 dt = ms - TIME_late;
    v.phys = TIME_now + dt;

    if (dt <= 0) { // already expired
        TIME_expired = 1;
    }
#ifdef ceu_out_timer
    else {         // check if out_timer is needed (empty Q or minimum timer)
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
#if N_INTRAS > 1
    q_init(&Q_INTRA,  Q_INTRA_BUF,  N_INTRAS, sizeof(QIntra), QIntra_prio);
#endif

#if N_TIMERS > 1
    q_init(&Q_TIMERS, Q_TIMERS_BUF, N_TIMERS, sizeof(QTimer), QTimer_prio);
    TIME_now  = now;
    TIME_late = 0;
    _extlmax_ = _extl_ = 0;
#endif

    qins_track(PR_MAX, Init);

    return go(ret);
}

int ceu_go_event (int* ret, int id, void* data) {
    DATA = data;
    trigger(id);

#if N_TIMERS > 1
    //TIME_base++;
    TIME_late = 0;
    _extl_ = ++_extlmax_;
#endif

    return go(ret);
}

int ceu_go_time (int* ret, tceu_time now)
{
#if N_TIMERS > 1
    QTimer min, nxt;
    TIME_now = now; //(ext.v.time) ? ext.v.time : out_now();

    if (!q_peek(&Q_TIMERS, &min))
        return 0;

    if (min.phys > TIME_now)
        return 0;

    q_remove(&Q_TIMERS,NULL);

    TIME_late = TIME_now - min.phys; // how much late the timer is
#if N_INTRAS > 1
    qins_intra(min.intl, min.gte);
#else
    spawn(min.gte);
#endif

    while (q_peek(&Q_TIMERS,&nxt))
    {
        // spawn all sharing min phys/ext time
        if (nxt.phys==min.phys && nxt.extl==min.extl) {
            q_remove(&Q_TIMERS, NULL);
#if N_INTRAS > 1
            qins_intra(nxt.intl, nxt.gte);
#else
            spawn(nxt.gte);
#endif
//printf("handlei: %d %d\n", nxt.intl, nxt.gte);
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
    return go(ret);
#else
    return 0;
#endif
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
    //TIME_base++;
    TIME_late = 0;
    _extl_ = ++_extlmax_;
#endif

    return go(ret);
}
#endif

int go (int* ret)
{
    QTrack trk;
    int _lbl_;

#if N_INTRAS > 1
    QIntra itr;
    _intl_ = 0;
_TRACKS_:
#endif
    while (q_remove(&Q_TRACKS,&trk))
    {
        _lbl_ = trk.lbl;
_SWITCH_:
        switch (_lbl_)
        {
            case Init:
=== CODE ===
        }
    }

#if N_INTRAS > 1
    if (q_remove(&Q_INTRA,&itr)) {
        spawn(itr.gte);
        _intl_ = itr.intl;
        while (q_peek(&Q_INTRA, &itr)) {
            if (itr.intl < _intl_)
                break;
            q_remove(&Q_INTRA, NULL);
            spawn(itr.gte);
        }
        goto _TRACKS_;
    }
#endif

#if N_TIMERS > 1
    if (TIME_expired)
        return ceu_go_time(ret, TIME_now);
#endif

    return 0;
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
