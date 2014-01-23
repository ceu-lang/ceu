#ifndef _CEU_OS_H
#define _CEU_OS_H

#include <stddef.h>
#include "ceu_types.h"

#ifdef CEU_OS
    /* TODO: all should be configurable */
    #define CEU_EXTS
    #define CEU_WCLOCKS
    #define CEU_INTS
    #define CEU_ASYNCS
    #define CEU_THREADS
    #define CEU_ORGS
    #define CEU_NEWS
    #define CEU_NEWS_POOL
    #define CEU_NEWS_MALLOC
    #define CEU_CLEAR
    #define CEU_PSES
    #define CEU_RET

    #define CEU_IN__NONE          0
    #define CEU_IN__STK         255
    #define CEU_IN__ORG         254
    #define CEU_IN__ORG_PSED    253
    #define CEU_IN__INIT        252
    #define CEU_IN__CLEAR       251
    #define CEU_IN__WCLOCK      250
    #define CEU_IN__ASYNC       249
    #define CEU_IN__THREAD      248
    #define CEU_IN_START        247

    typedef s8 tceu_nlbl;

    #define CEU_QUEUE_MAX       255
#endif

#ifdef CEU_THREADS
/* TODO: app */
#include "ceu_threads.h"
#endif

typedef u8 tceu_nevt;   /* max number of events */
                        /* TODO: should "u8" be fixed? */

#ifdef __cplusplus
#define CEU_WCLOCK_INACTIVE 0x7fffffffL     /* TODO */
#else
#define CEU_WCLOCK_INACTIVE INT32_MAX
#endif
#define CEU_WCLOCK_EXPIRED (CEU_WCLOCK_INACTIVE-1)

/* TCEU_TRL */

typedef union tceu_trl {
    tceu_nevt evt;
    struct {                    /* TODO(ram): bitfields */
        tceu_nevt evt1;
        tceu_nlbl lbl;
        u8        seqno;        /* TODO(ram): 2 bits is enough */
    };
    struct {                    /* TODO(ram): bitfields */
        tceu_nevt evt2;
        tceu_nlbl lbl2;
        u8        stk;
    };
#ifdef CEU_ORGS
    struct {                    /* TODO(ram): bad for alignment */
        tceu_nevt evt3;
        struct tceu_org_lnk* lnks;
    };
#endif
} tceu_trl;

/* TCEU_EVTP */

typedef union tceu_evtp {
    int   v;
    void* ptr;
    s32   dt;
#ifdef CEU_THREADS
    CEU_THREADS_T thread;
#endif
} tceu_evtp;

/* TCEU_STK */

/* TODO(speed): hold nxt trl to run */
typedef struct tceu_stk {
    tceu_evtp evtp;
#ifdef CEU_INTS
#ifdef CEU_ORGS
    void*     evto;
#endif
#endif
    tceu_nevt evt;
} tceu_stk;

/* TCEU_LNK */

/* simulates an org prv/nxt */
typedef struct tceu_org_lnk {
    struct tceu_org* prv;   /* TODO(ram): lnks[0] does not use */
    struct tceu_org* nxt;   /*      prv, n, lnk                  */
    u8 n;                   /* use for ands/fins                 */
    u8 lnk;
} tceu_org_lnk;

/* TCEU_ORG */

typedef struct tceu_org
{
#ifdef CEU_ORGS
    struct tceu_org* prv;   /* linked list for the scheduler */
    struct tceu_org* nxt;
    u8 n;                   /* number of trails (TODO(ram): opt, metadata) */
    u8 lnk;
    /* tceu_org_lnk */

#ifdef CEU_IFCS
    tceu_ncls cls;          /* class id */
#endif

#ifdef CEU_NEWS
    u8 isDyn: 1;            /* created w/ new or spawn? */
    u8 isSpw: 1;            /* free on termination? */
#endif
#endif  /* CEU_ORGS */

#ifdef CEU_NEWS_POOL
    void*  pool;            /* TODO(ram): opt, traverse lst of cls pools */
#endif

    tceu_trl trls[0];       /* first trail */

} tceu_org;

/* TCEU_GO */

typedef struct tceu_go {
    int         evt;
    tceu_evtp   evtp;

#ifdef CEU_INTS
#ifdef CEU_ORGS
    tceu_org* evto;       /* org that emitted current event */
#endif
#endif

#ifdef CEU_ORGS
    #define CEU_MAX_STACK   255     /* TODO */
    /* TODO: CEU_ORGS is calculable // CEU_NEWS isn't (255?) */
    tceu_stk stk[CEU_MAX_STACK];
#else
    tceu_stk stk[CEU_NTRAILS];
#endif

    /* current traversal state */
    int        stki;   /* points to next */
    tceu_trl*  trl;
    tceu_nlbl  lbl;
    tceu_org* org;

    /* traversals may be bounded to org/trl
     * default (NULL) is to traverse everything */
#ifdef CEU_CLEAR
    void* stop;     /* stop at this trl/org */
#endif
} tceu_go;

/* TCEU_LST */

#ifdef CEU_DEBUG
typedef struct tceu_lst {
#ifdef CEU_ORGS
    void*     org;
#endif
    tceu_trl* trl;
    tceu_nlbl lbl;
} tceu_lst;
#endif

/* TCEU_THREADS_P */

#ifdef CEU_THREADS
typedef struct {
    tceu_org* org;
    s8*       st; /* thread state:
                   * 0=ini (sync  spawns)
                   * 1=cpy (async copies)
                   * 2=lck (sync  locks)
                   * 3=end (sync/async terminates)
                   */
} tceu_threads_p;
#endif

/* TCEU_APP */

typedef struct tceu_app {
    /* global seqno: incremented on every reaction
     * awaiting trails matches only if trl->seqno < seqno,
     * i.e., previously awaiting the event
     */
    u8 seqno:         2;
#ifdef CEU_RET
    u8 isAlive:       1;
#endif
#ifdef CEU_ASYNCS
    u8 pendingAsyncs: 1;
#endif
#ifdef CEU_OS
    struct tceu_app* nxt;
#endif

#ifdef CEU_RET
    int ret;
#endif

#ifdef CEU_WCLOCKS
    int         wclk_late;
    s32         wclk_min;
    s32         wclk_min_tmp;
#endif

#ifdef CEU_DEBUG
    tceu_lst    lst; /* segfault printf */
#endif

#ifdef CEU_THREADS
    CEU_THREADS_MUTEX_T threads_mutex;
    /*CEU_THREADS_COND_T  threads_cond;*/
    u8                  threads_n;          /* number of running threads */
        /* TODO: u8? */
#endif

    int         (*code) (tceu_go* _ceu_go);
    void        (*init) (void);
    tceu_org*   data;
} tceu_app;

/* RET_* */

enum {
    RET_HALT = 0,
    RET_END
    /*RET_GOTO,*/
#if defined(CEU_INTS) || defined(CEU_ORGS)
    , RET_ORG
#endif
#if defined(CEU_CLEAR) || defined(CEU_ORGS)
    , RET_TRL
#endif
#ifdef CEU_ASYNCS
    , RET_ASYNC
#endif
};

void* ceu_alloc (size_t size);
void  ceu_free (void* ptr);

void ceu_org_init (tceu_org* org, int n, int lbl, int seqno,
                   tceu_org* par_org, int par_trl);

#ifdef CEU_WCLOCKS
void ceu_trails_set_wclock (tceu_app* app, s32* t, s32 dt);
int ceu_wclocks_expired (tceu_app* app, s32* t, s32 dt);
#endif

void ceu_go        (tceu_app* app, int evt, tceu_evtp evtp);
void ceu_go_init   (tceu_app* app);
void ceu_go_event  (tceu_app* app, int id, void* data);
void ceu_go_async  (tceu_app* app);
void ceu_go_wclock (tceu_app* app, s32 dt);
int  ceu_go_all    (tceu_app* app);
#endif

#ifdef CEU_OS

/* TCEU_LINK */

typedef struct tceu_link {
    tceu_app* src_app;
    tceu_nevt src_evt;
    tceu_app* dst_app;
    tceu_nevt dst_evt;
    struct tceu_link* nxt;
} tceu_link;

/* TCEU_QUEUE */

typedef struct {
    tceu_app* app;
    tceu_nevt evt;
    tceu_evtp param;
} tceu_queue;

void ceu_sys_app (tceu_app* app);

int ceu_sys_event (tceu_app* app, tceu_nevt evt, tceu_evtp param);

int ceu_sys_link   (tceu_app* src_app, tceu_nevt src_evt,
                    tceu_app* dst_app, tceu_nevt dst_evt);
int ceu_sys_unlink (tceu_app* src_app, tceu_nevt src_evt,
                    tceu_app* dst_app, tceu_nevt dst_evt);
#endif
