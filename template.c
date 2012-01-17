#include <string.h>

#define PR_MAX  0xFF

#define N_TIMERS    (1+ === N_TIMERS === +1) // async (TODO: pq esse +1 async?)
#define N_TRACKS    (1+ === N_TRACKS ===)
#define N_INTRAS    (1+ === N_INTRAS ===)
#define N_ASYNCS    (=== N_ASYNCS ===)
#define N_GTES      === N_GTES ===
#define N_ANDS      === N_ANDS ===
#define N_VARS      === N_VARS ===

#ifndef ceu_out_pending
#   define ceu_out_pending()   (1)
#endif

#ifndef ceu_out_timer
#   define ceu_out_timer(ms)
#endif

#ifndef ASSERT
#   include <assert.h>
#   define ASSERT(x,y) assert(x)
#endif

typedef u32 tceu_time;
typedef u16 tceu_gte;
typedef u16 tceu_lbl;

#include "binheap.h"
#include "binheap.c"

int go (int* ret);

=== HOST ===

enum {
    Init = 0,
=== LABELS ===
};

=== EVTS ===

void* DATA;

char ANDS[N_ANDS];      // TODO: bitfield
tceu_lbl GTES[N_GTES];
tceu_gte TRGS[] = { === TRGS === };

#define PVAR(tp,reg) ((tp*)(VARS+reg))
char VARS[N_VARS];

int _intl_, _extl_, _extlmax_;

/* INTRAS ***************************************************************/

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
    if (lbl) {
        qins_track(PR_MAX, lbl);
        GTES[gte] = 0;
    }
}

void trigger (int trg)
{
    int i;
    for (i=1 ; i<=TRGS[trg] ; i++)
        spawn(TRGS[trg+i]);
}

/* TIMERS ***************************************************************/

//tceu_time TIME_base = 0;
tceu_time TIME_now = 0;
tceu_time TIME_late;
int       TIME_expired = 0;

typedef struct {
    tceu_time phys;
    u8 extl;            // TODO: garantir/zerar u8
    u8 intl;            // TODO: garantir u8
    tceu_gte gte;
} QTimer;

int QTimer_prio (void* v1, void* v2) {
    QTimer* t1 = (QTimer*) v1;
    QTimer* t2 = (QTimer*) v2;
    int ret = t1->phys < t2->phys || (
            (t1->phys == t2->phys) && (
                t1->extl < t2->extl ||
                    (t1->extl==t2->extl && t1->intl>t2->intl)
                ));
//printf("%d = %d %d vs %d %d\n", ret, t1->phys,t1->extl, t2->phys,t2->extl);
    return ret;
}

Queue  Q_TIMERS;
QTimer Q_TIMERS_BUF[N_TIMERS];

void qins_timer (tceu_time ms, tceu_gte gte) {
    int i;
    QTimer v = { 0, _extl_, _intl_, gte };

    s32 dt = ms - TIME_late;
    v.phys = TIME_now + dt;

    if (dt <= 0) { // already expired
        TIME_expired = 1;
    }
    else {         // check if out_timer is needed (empty Q or minimum timer)
        QTimer min;
        if (!q_peek(&Q_TIMERS,&min) || (v.phys<min.phys))
            ceu_out_timer(dt);
    }


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
    ASSERT(async_cnt <= N_ASYNCS, 6);
}
#endif

/**********************************************************************/

/*
void dump (void)
{
    int i;
    for (i=0; i<20; i++)
        printf("%3d", i);
    printf("\n");
    for (i=0; i<20; i++)
        printf("%3X", VARS[i]);
    printf("\n");
}
*/

/**********************************************************************/

int ceu_go_init (int* ret, tceu_time now)
{
    memset(GTES, 0, N_GTES);

    q_init(&Q_TIMERS, Q_TIMERS_BUF, N_TIMERS, sizeof(QTimer), QTimer_prio);
    q_init(&Q_TRACKS, Q_TRACKS_BUF, N_TRACKS, sizeof(QTrack), QTrack_prio);
    q_init(&Q_INTRA,  Q_INTRA_BUF,  N_INTRAS, sizeof(QIntra), QIntra_prio);

    TIME_now  = now;
    TIME_late = 0;

    qins_track(PR_MAX, Init);

    _extlmax_ = _extl_ = 0;
    return go(ret);
}

int ceu_go_event (int* ret, int id, void* data) {
    DATA = data;

    //TIME_base++;
    TIME_late = 0;
    trigger(id);

    _extl_ = ++_extlmax_;
    return go(ret);
}

int ceu_go_start (int* ret)
{
#ifdef IO_Start
    //*PVAL(int,IO_Start) = (argc>1) ? atoi(argv[1]) : 0;
    return ceu_go_event(ret, IO_Start, NULL);
#else
    return 0;
#endif
}

int ceu_go_time (int* ret, tceu_time now)
{
    QTimer min, nxt;
    TIME_now = now; //(ext.v.time) ? ext.v.time : out_now();

    if (!q_peek(&Q_TIMERS, &min))
        return 0;

    if (min.phys > TIME_now)
        return 0;

    q_remove(&Q_TIMERS,NULL);

    TIME_late = TIME_now - min.phys; // how much late the timer is
    qins_intra(min.intl, min.gte);

    while (q_peek(&Q_TIMERS,&nxt))
    {
        // spawn all sharing min phys/ext time
        if (nxt.phys==min.phys && nxt.extl==min.extl) {
            q_remove(&Q_TIMERS, NULL);
            qins_intra(nxt.intl, nxt.gte);
//printf("handlei: %d %d\n", nxt.intl, nxt.gte);
        } else {
            if (nxt.phys > TIME_now)            // not yet to spawn
                ceu_out_timer(nxt.phys - TIME_now);
            else {                              // spawn, but in another cycle
                TIME_expired = 1;
            }
            break;
        }
    }

    _extl_ = min.extl;
    return go(ret);
}

#if N_ASYNCS > 0
int ceu_go_async (int* ret, int* count)
{
    if (count)
        *count = async_cnt;
    if (async_cnt == 0)
        return 0;

    //TIME_base++;
    TIME_late = 0;

    spawn(Q_ASYNC[async_ini++]);
    async_ini %= N_ASYNCS;
    async_cnt--;

    _extl_ = ++_extlmax_;
    return go(ret);
}
#endif

int go (int* ret)
{
    QTrack trk;
    QIntra itr;
    int _lbl_;

    _intl_ = 0;

_TRACKS_:
    while (q_remove(&Q_TRACKS,&trk))
    {
        _lbl_ = trk.lbl;
_SWITCH_:
//printf("=====================================\n");
//dump();
//printf("LABEL: %d\n", _lbl_);
        switch (_lbl_)
        {
            case Init:
=== CODE ===
        }
//dump();
//printf("=====================================\n");
    }

    if (q_remove(&Q_INTRA,&itr)) {
        spawn(itr.gte);
        _intl_ = itr.intl;
//printf("intra: %d %d\n", _intl_, itr.gte);
        while (q_peek(&Q_INTRA, &itr)) {
            if (itr.intl < _intl_)
                break;
            q_remove(&Q_INTRA, NULL);
            spawn(itr.gte);
        }
        goto _TRACKS_;
    }

    if (TIME_expired)
        return ceu_go_time(ret, TIME_now);

    return 0;
}

int ceu_go_polling (tceu_time now)
{
    int ret, async_cnt;

    if (ceu_go_init(&ret, now))
        return ret;

    if (ceu_go_start(&ret))
        return ret;

#if N_ASYNCS > 0
    for (;;) {
        if (ceu_go_async(&ret,&async_cnt))
            return ret;
        if (async_cnt == 0)
            break;              // returns nothing!
    }
#endif
}
