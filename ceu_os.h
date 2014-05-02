#ifndef _CEU_OS_H
#define _CEU_OS_H

#include <stddef.h>
#include "ceu_types.h"

#if defined(CEU_OS) && defined(__AVR)
#include "Arduino.h"
#define CEU_ISR
#define CEU_ISR_ON()  interrupts()
#define CEU_ISR_OFF() noInterrupts()
#else
#define CEU_ISR_ON()
#define CEU_ISR_OFF()
#endif

#ifdef __cplusplus
#define CEU_EVTP(v) (tceu_evtp(v))
#else
#define CEU_EVTP(v) ((tceu_evtp)v)
#endif

#ifdef CEU_OS
    /* TODO: all should be configurable */
    #define CEU_EXTS
    #define CEU_WCLOCKS
    #define CEU_ASYNCS
    #define CEU_RET
    #define CEU_CLEAR
#ifndef __AVR
#endif
    #define CEU_INTS
    #define CEU_ORGS
    #define CEU_PSES
    #define CEU_NEWS
    #define CEU_NEWS_MALLOC
    #define CEU_NEWS_POOL
/*
    #define CEU_THREADS
*/

#ifdef __AVR
    #define CEU_QUEUE_MAX 256
#else
    #define CEU_QUEUE_MAX 65536
#endif

    #define CEU_IN__NONE          0
    #define CEU_IN__STK         255
    #define CEU_IN__ORG         254
    #define CEU_IN__ORG_PSED    253
    #define CEU_IN__INIT        252
    #define CEU_IN__CLEAR       251
    #define CEU_IN__WCLOCK      250
    #define CEU_IN__ASYNC       249
    #define CEU_IN__THREAD      248
    #define CEU_IN_OS_START     247
    #define CEU_IN_OS_STOP      246
    #define CEU_IN_OS_DT        245
    #define CEU_IN_OS_INTERRUPT 244
    #define CEU_IN              244

    typedef s8 tceu_nlbl;   /* TODO: to small!! */

    #define ceu_out_malloc(size) \
        ((__typeof__(ceu_sys_malloc)*)((_ceu_app)->sys_vec[CEU_SYS_MALLOC]))(size)
    #define ceu_out_free(ptr) \
        ((__typeof__(ceu_sys_free)*)((_ceu_app)->sys_vec[CEU_SYS_FREE]))(ptr)

    #define ceu_out_req() \
        ((__typeof__(ceu_sys_req)*)((_ceu_app)->sys_vec[CEU_SYS_REQ]))()

    #define ceu_out_load(addr) \
        ((__typeof__(ceu_sys_load)*)((_ceu_app)->sys_vec[CEU_SYS_LOAD]))(addr)

#ifdef CEU_ISR
    #define ceu_out_isr(n,f) \
        ((__typeof__(ceu_sys_isr)*)((_ceu_app)->sys_vec[CEU_SYS_ISR]))(n,f,_ceu_app)
#endif

    #define ceu_out_org(app,org,n,lbl,seqno,par_org,par_trl) \
        ((__typeof__(ceu_sys_org)*)((app)->sys_vec[CEU_SYS_ORG]))(org,n,lbl,seqno,par_org,par_trl)

    #define ceu_out_start(app) \
        ((__typeof__(ceu_sys_start)*)((_ceu_app)->sys_vec[CEU_SYS_START]))(app)
    #define ceu_out_link(app1,evt1 , app2,evt2) \
        ((__typeof__(ceu_sys_link)*)((_ceu_app)->sys_vec[CEU_SYS_LINK]))(app1,evt1,app2,evt2)

    #define ceu_out_emit_buf(app,id,sz,buf) \
        ((__typeof__(ceu_sys_emit)*)((app)->sys_vec[CEU_SYS_EMIT]))(app,id,CEU_EVTP((void*)NULL),sz,buf)

    #define ceu_out_emit_val(app,id,param) \
        ((__typeof__(ceu_sys_emit)*)((app)->sys_vec[CEU_SYS_EMIT]))(app,id,param,0,NULL)

    #define ceu_out_call_val(app,id,param) \
        ((__typeof__(ceu_sys_call)*)((app)->sys_vec[CEU_SYS_CALL]))(app,id,param)

#ifdef CEU_WCLOCKS
    #define ceu_out_wclock(app,dt,set,get) \
        ((__typeof__(ceu_sys_wclock)*)((app)->sys_vec[CEU_SYS_WCLOCK]))(app,dt,set,get)
#endif

    #define ceu_out_go(app,evt,evtp) \
        ((__typeof__(ceu_sys_go)*)((app)->sys_vec[CEU_SYS_GO]))(app,evt,evtp)

#else /* ! CEU_OS */
    #include "_ceu_app.h"
    #define ceu_out_malloc(size) \
            ceu_sys_malloc(size)
    #define ceu_out_free(ptr) \
            ceu_sys_free(ptr)
    #define ceu_out_req() \
            ceu_sys_req()
    #define ceu_out_org(app,org,n,lbl,seqno,par_org,par_trl) \
            ceu_sys_org(org,n,lbl,seqno,par_org,par_trl)
/*#ifdef ceu_out_emit_val*/
    #define ceu_out_emit_buf(app,id,sz,buf) \
            ceu_out_emit_val(app,id,CEU_EVTP((void*)buf))
/*#endif*/
#ifdef CEU_WCLOCKS
    #define ceu_out_wclock(app,dt,set,get) \
            ceu_sys_wclock(app,dt,set,get)
#endif
    #define ceu_out_go(app,evt,evtp) \
            ceu_sys_go(app,evt,evtp)
#endif

#define ceu_in_emit_val(app,id,param) \
    ceu_out_go(app,id,param)

#ifdef CEU_THREADS
/* TODO: app */
#include "ceu_threads.h"
#endif

typedef u8 tceu_nevt;   /* max number of events */
                        /* TODO: should "u8" be fixed? */

typedef u8 tceu_ntrl;   /* max number of trails per class */
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

    /* normal await // IN__CLEAR */
    struct {                    /* TODO(ram): bitfields */
        tceu_nevt evt1;
        tceu_nlbl lbl;
        u8        seqno;        /* TODO(ram): 2 bits is enough */
    };

    /* IN__STK */
    struct {                    /* TODO(ram): bitfields */
        tceu_nevt evt2;
        tceu_nlbl lbl2;
        u8        stk;
    };

    /* IN__ORG */
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
#ifdef __cplusplus
    tceu_evtp () {}
    tceu_evtp (void* vv) : ptr(vv) {}
    tceu_evtp (s32   vv) : dt(vv)  {}
    /*tceu_evtp (int   vv) : v(vv)   {}*/
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
    u8 lnk;
    tceu_ntrl n;            /* use for ands/fins                 */
} tceu_org_lnk;

/* TCEU_ORG */

typedef struct tceu_org
{
#ifdef CEU_ORGS
    struct tceu_org* prv;   /* linked list for the scheduler */
    struct tceu_org* nxt;
    u8 lnk;
#endif
#if defined(CEU_ORGS) || defined(CEU_OS)
    tceu_ntrl n;            /* number of trails (TODO(ram): opt, metadata) */
#endif
    /* prv/nxt/lnk/n must be in the same order as "tceu_org_lnk" */

#ifdef CEU_ORGS
#ifdef CEU_IFCS
    tceu_ncls cls;          /* class id */
#endif
    u8 isAlive: 1;          /* required by "watching o" */
#ifdef CEU_NEWS
    u8 isDyn: 1;            /* created w/ new or spawn? */
    /*u8 isSpw: 1;            // free on termination? */
    struct tceu_org* nxt_free;  /* "to free" list (only on reaction end) */
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

#if defined(CEU_ORGS) || defined(CEU_OS)
    #define CEU_MAX_STACK   255     /* TODO 256??? */
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

/* TCEU_APP */

typedef struct tceu_app {
    /* global seqno: incremented on every reaction
     * awaiting trails matches only if trl->seqno < seqno,
     * i.e., previously awaiting the event
     */
    u8 seqno:         2;
#if defined(CEU_RET) || defined(CEU_OS)
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

#ifndef CEU_OS
#ifdef CEU_DEBUG
    tceu_lst    lst; /* segfault printf */
#endif
#endif

#ifdef CEU_THREADS
    CEU_THREADS_MUTEX_T threads_mutex;
    /*CEU_THREADS_COND_T  threads_cond;*/
    u8                  threads_n;          /* number of running threads */
        /* TODO: u8? */
#endif

    int         (*code)  (struct tceu_app*,tceu_go*);
    void        (*init)  (struct tceu_app*);
#ifdef CEU_OS
    tceu_evtp   (*calls) (struct tceu_app*,tceu_nevt,tceu_evtp);
    void**      sys_vec;
    void*       addr;
#endif
    tceu_org*   data;
} tceu_app;

#ifdef CEU_OS
typedef void (*tceu_init)   (tceu_app* app);
typedef void (*tceu_export) (uint* size, tceu_init** init);
#endif

/* TCEU_THREADS_P */

#ifdef CEU_THREADS
typedef struct {
    tceu_app* app;
    tceu_org* org;
    s8*       st; /* thread state:
                   * 0=ini (sync  spawns)
                   * 1=cpy (async copies)
                   * 2=lck (sync  locks)
                   * 3=end (sync/async terminates)
                   */
} tceu_threads_p;
#endif

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

#ifdef CEU_PSES
void ceu_pause (tceu_trl* trl, tceu_trl* trlF, int psed);
#endif

int  ceu_go_all    (tceu_app* app);

#ifdef CEU_WCLOCKS
int       ceu_sys_wclock (tceu_app* app, s32 dt, s32* set, s32* get);
#endif
void      ceu_sys_go     (tceu_app* app, int evt, tceu_evtp evtp);

#ifdef CEU_OS

/* TCEU_LINK */

typedef struct tceu_lnk {
    tceu_app* src_app;
    tceu_nevt src_evt;
    tceu_app* dst_app;
    tceu_nevt dst_evt;
    struct tceu_lnk* nxt;
} tceu_lnk;

/* TCEU_QUEUE */

typedef struct {
    tceu_app* app;
    tceu_nevt evt;
    tceu_evtp param;
#if CEU_QUEUE_MAX == 256
    s8        sz;
#else
    s16       sz;   /* signed because of fill */
#endif
    byte      buf[0];
} tceu_queue;

#ifdef CEU_ISR
typedef void(*tceu_isr_f)(tceu_app* app, tceu_org* org);
#endif

void ceu_init      (void);
int  ceu_scheduler (int(*dt)());
tceu_queue* ceu_sys_queue_nxt (void);
void        ceu_sys_queue_rem (void);

void*     ceu_sys_malloc (size_t size);
void      ceu_sys_free   (void* ptr);
int       ceu_sys_req    (void);
tceu_app* ceu_sys_load   (void* addr);
#ifdef CEU_ISR
int       ceu_sys_isr    (int n, tceu_isr_f f, tceu_app* app);
#endif
void      ceu_sys_org    (tceu_org* org, int n, int lbl, int seqno, tceu_org* par_org, int par_trl);
void      ceu_sys_start  (tceu_app* app);
int       ceu_sys_link   (tceu_app* src_app, tceu_nevt src_evt, tceu_app* dst_app, tceu_nevt dst_evt);
int       ceu_sys_unlink (tceu_app* src_app, tceu_nevt src_evt, tceu_app* dst_app, tceu_nevt dst_evt);
int       ceu_sys_emit   (tceu_app* app, tceu_nevt evt, tceu_evtp param, int sz, byte* buf);
tceu_evtp ceu_sys_call   (tceu_app* app, tceu_nevt evt, tceu_evtp param);

enum {
    CEU_SYS_MALLOC = 0,
    CEU_SYS_FREE,
    CEU_SYS_REQ,
    CEU_SYS_LOAD,
#ifdef CEU_ISR
    CEU_SYS_ISR,
#endif
    CEU_SYS_ORG,
    CEU_SYS_START,
    CEU_SYS_LINK,
    CEU_SYS_UNLINK,
    CEU_SYS_EMIT,
    CEU_SYS_CALL,
#ifdef CEU_WCLOCKS
    CEU_SYS_WCLOCK,
#endif
    CEU_SYS_GO,
    CEU_SYS_MAX
};

/* SYS_VECTOR
 */
extern void* CEU_SYS_VEC[CEU_SYS_MAX];

#endif  /* CEU_OS */

#endif  /* _CEU_OS_H */
