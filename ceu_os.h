#ifndef _CEU_OS_H
#define _CEU_OS_H

#include <stddef.h>
#include "ceu_types.h"

#ifdef CEU_DEBUG
#include <assert.h>
#endif

#if defined(CEU_OS) && defined(__AVR)
#error Understand this again!
#include "Arduino.h"
#define CEU_ISR
#define CEU_ISR_ON()  interrupts()
#define CEU_ISR_OFF() noInterrupts()
#else
#define CEU_ISR_ON()
#define CEU_ISR_OFF()
#endif

#if defined(CEU_OS_KERNEL) || defined(CEU_OS_APP)
#define CEU_OS
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
    /*#define CEU_PSES*/ /* TODO: never tried */
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
    #define CEU_IN__ASYNC       250
    #define CEU_IN__THREAD      249
    #define CEU_IN__WCLOCK      248
    #define CEU_IN_OS_START     247
    #define CEU_IN_OS_STOP      246
    #define CEU_IN_OS_DT        245
    #define CEU_IN_OS_INTERRUPT 244
#ifdef CEU_TIMEMACHINE
    #define CEU_IN__WCLOCK_     243
    #define CEU_IN              243
#else
    #define CEU_IN              244
#endif

    typedef s8 tceu_nlbl;   /* TODO: to small!! */

#ifdef CEU_OS_APP
    #define ceu_out_assert(v) \
        ((__typeof__(ceu_sys_assert)*)((_ceu_app)->sys_vec[CEU_SYS_ASSERT]))(v)

    #define ceu_out_log(mode,str) \
        ((__typeof__(ceu_sys_log)*)((_ceu_app)->sys_vec[CEU_SYS_LOG]))(mode,str)

    #define ceu_out_realloc(ptr, size) \
        ((__typeof__(ceu_sys_realloc)*)((_ceu_app)->sys_vec[CEU_SYS_REALLOC]))(ptr,size)

    #define ceu_out_req() \
        ((__typeof__(ceu_sys_req)*)((_ceu_app)->sys_vec[CEU_SYS_REQ]))()

    #define ceu_out_load(addr) \
        ((__typeof__(ceu_sys_load)*)((_ceu_app)->sys_vec[CEU_SYS_LOAD]))(addr)

#ifdef CEU_ISR
    #define ceu_out_isr(n,f) \
        ((__typeof__(ceu_sys_isr)*)((_ceu_app)->sys_vec[CEU_SYS_ISR]))(n,f,_ceu_app)
#endif

    #define ceu_out_org(app,org,n,lbl,seqno,isDyn,par_org,par_trl) \
        ((__typeof__(ceu_sys_org)*)((app)->sys_vec[CEU_SYS_ORG]))(org,n,lbl,seqno,isDyn,par_org,par_trl)

#ifdef CEU_ORGS
    #define ceu_out_org_trail(org,idx,lnk) \
        ((__typeof__(ceu_sys_org_trail)*)((_ceu_app)->sys_vec[CEU_SYS_ORG_TRAIL]))(org,idx,lnk)

    #define ceu_out_org_spawn(go, lbl_cnt, org, lbl_org) \
        ((__typeof__(ceu_sys_org_spawn)*)((_ceu_app)->sys_vec[CEU_SYS_ORG_SPAWN]))(go,lbl_cnt,org,lbl_org)
#endif

    #define ceu_out_start(app) \
        ((__typeof__(ceu_sys_start)*)((_ceu_app)->sys_vec[CEU_SYS_START]))(app)
    #define ceu_out_link(app1,evt1 , app2,evt2) \
        ((__typeof__(ceu_sys_link)*)((_ceu_app)->sys_vec[CEU_SYS_LINK]))(app1,evt1,app2,evt2)

    #define ceu_out_emit(app,id,sz,buf) \
        ((__typeof__(ceu_sys_emit)*)((app)->sys_vec[CEU_SYS_EMIT]))(app,id,sz,buf)

    #define ceu_out_call(app,id,param) \
        ((__typeof__(ceu_sys_call)*)((app)->sys_vec[CEU_SYS_CALL]))(app,id,param)

#ifdef CEU_WCLOCKS
    #define ceu_out_wclock(app,dt,set,get) \
        ((__typeof__(ceu_sys_wclock)*)((app)->sys_vec[CEU_SYS_WCLOCK]))(app,dt,set,get)
#ifdef CEU_TIMEMACHINE
    #error TIMEMACHINE
#endif
#endif

    #define ceu_out_go(app,evt,evtp) \
        ((__typeof__(ceu_sys_go)*)((app)->sys_vec[CEU_SYS_GO]))(app,evt,evtp)
#endif

#else /* ! CEU_OS */
    #define ceu_out_assert(v) \
            ceu_sys_assert(v)
    #define ceu_out_log(mode,str) \
            ceu_sys_log(mode,str)
    #define ceu_out_realloc(ptr,size) \
            ceu_sys_realloc(ptr,size)
    #define ceu_out_req() \
            ceu_sys_req()
#ifdef CEU_NEWS
    #define ceu_out_org(app,org,n,lbl,seqno,isDyn,par_org,par_trl) \
            ceu_sys_org(org,n,lbl,seqno,isDyn,par_org,par_trl)
#else
    #define ceu_out_org(app,org,n,lbl,seqno,par_org,par_trl) \
            ceu_sys_org(org,n,lbl,seqno,par_org,par_trl)
#endif
#ifdef CEU_ORGS
    #define ceu_out_org_trail(org,idx,lnk) \
            ceu_sys_org_trail(org,idx,lnk)
    #define ceu_out_org_spawn(go, lbl_cnt, org, lbl_org) \
            ceu_sys_org_spawn(go, lbl_cnt, org, lbl_org)
#endif
#ifdef CEU_WCLOCKS
    #define ceu_out_wclock(app,dt,set,get) \
            ceu_sys_wclock(app,dt,set,get)
#ifdef CEU_TIMEMACHINE
    #define ceu_out_wclock_(app,dt,set,get) \
            ceu_sys_wclock_(app,dt,set,get)
#endif
#endif
    #define ceu_out_go(app,evt,evtp) \
            ceu_sys_go(app,evt,evtp)
#endif

#define ceu_in_emit(app,id,n,buf) \
    ceu_out_go(app,id,buf)

#ifdef CEU_THREADS
/* TODO: app */
#include "ceu_threads.h"
#endif

#ifdef CEU_LUA
#include <stdio.h>      /* BUFSIZ */
#include <string.h>     /* strcpy */
#if defined(__ANDROID__) || defined(CEU_OS)
    #include "lua.h"
    #include "lauxlib.h"
    #include "lualib.h"
#else
    #include <lua5.1/lua.h>
    #include <lua5.1/lauxlib.h>
    #include <lua5.1/lualib.h>
#endif

#ifdef CEU_OS_APP
    #define ceu_luaL_newstate(set) { \
        set = ceu_out_call(_ceu_app, CEU_OUT_LUA_NEW, NULL); \
    }

    #define ceu_luaL_openlibs(l) { \
        lua_State* p = l;          \
        ceu_out_call(_ceu_app, CEU_OUT_LUAL_OPENLIBS, &p); \
    }

    #define ceu_lua_atpanic(l, f) {     \
    }

    #define ceu_luaL_loadstring(set, l, str) {  \
        tceu__lua_State___char_ p = { l, str }; \
        set = (int) ceu_out_call(_ceu_app, CEU_OUT_LUAL_LOADSTRING, &p); \
    }

    #define ceu_lua_pushnumber(l, v) {      \
        tceu__lua_State___int p = { l, v }; \
        ceu_out_call(_ceu_app, CEU_OUT_LUA_PUSHNUMBER, &p); \
    }

    #define ceu_lua_pushstring(l, v) {      \
        tceu__lua_State___char_ p = { l, v }; \
        ceu_out_call(_ceu_app, CEU_OUT_LUA_PUSHSTRING, &p); \
    }

    #define ceu_lua_pushlightuserdata(l, v) {   \
        tceu__lua_State___void_ p = { l, v };     \
        ceu_out_call(_ceu_app, CEU_OUT_LUA_PUSHLIGHTUSERDATA, &p); \
    }

    #define ceu_lua_pcall(set,l,nargs,nrets,err) {                  \
        tceu__lua_State___int__int__int p = { l, nargs, nrets, err }; \
        ceu_out_call(_ceu_app, CEU_OUT_LUA_PCALL, &p); \
    }

    #define ceu_lua_isnumber(set, l, idx) {     \
        tceu__lua_State___int p = { l, idx };   \
        set = (int) ceu_out_call(_ceu_app, CEU_OUT_LUA_ISNUMBER, &p); \
    }

    #define ceu_lua_tonumber(set, l, idx) {     \
        tceu__lua_State___int p = { l, idx };   \
        set = (int) ceu_out_call(_ceu_app, CEU_OUT_LUA_TONUMBER, &p); \
    }

    #define ceu_lua_isboolean(set, l, idx) {    \
        tceu__lua_State___int p = { l, idx };   \
        set = (int) ceu_out_call(_ceu_app, CEU_OUT_LUA_ISBOOLEAN, &p); \
    }

    #define ceu_lua_toboolean(set, l, idx) {    \
        tceu__lua_State___int p = { l, idx };   \
        set = (int) ceu_out_call(_ceu_app, CEU_OUT_LUA_TOBOOLEAN, &p); \
    }

    #define ceu_lua_pop(l, n) {             \
        tceu__lua_State___int p = { l, n }; \
        ceu_out_call(_ceu_app, CEU_OUT_LUA_POP, &p); \
    }

    #define ceu_lua_isstring(set, l, idx) {     \
        tceu__lua_State___int p = { l, idx };   \
        set = (int) ceu_out_call(_ceu_app, CEU_OUT_LUA_ISSTRING, &p); \
    }

    #define ceu_lua_tostring(set, l, idx) {     \
        tceu__lua_State___int p = { l, idx };   \
        set = ceu_out_call(_ceu_app, CEU_OUT_LUA_TOSTRING, &p); \
    }

    #define ceu_lua_islightuserdata(set, l, idx) {  \
        tceu__lua_State___int p = { l, idx };       \
        set = (int) ceu_out_call(_ceu_app, CEU_OUT_LUA_ISLIGHTUSERDATA, &p); \
    }

    #define ceu_lua_touserdata(set, l, idx) {   \
        tceu__lua_State___int p = { l, idx };   \
        set = ceu_out_call(_ceu_app, CEU_OUT_LUA_TOUSERDATA, &p); \
    }

    #define ceu_lua_error(l) {  \
        lua_State** p = &l;        \
        ceu_out_call(_ceu_app, CEU_OUT_LUA_ERROR, &p); \
    }
#else
    #define ceu_luaL_newstate(set)               set = luaL_newstate()
    #define ceu_luaL_openlibs(l)                 luaL_openlibs(l)
    #define ceu_lua_atpanic(l,f)                 lua_atpanic(l,f)
    #define ceu_luaL_loadstring(set,l,str)       set = luaL_loadstring(l,str)
    #define ceu_lua_pushnumber(l,v)              lua_pushnumber(l,v)
    #define ceu_lua_pushstring(l,v)              lua_pushstring(l,v)
    #define ceu_lua_pushlightuserdata(l,v)       lua_pushlightuserdata(l,v)
    #define ceu_lua_pcall(set,l,nargs,nrets,err) set = lua_pcall(l,nargs,nrets,err)
    #define ceu_lua_isnumber(set,l,idx)          set = lua_isnumber(l,idx)
    #define ceu_lua_tonumber(set,l,idx)          set = lua_tonumber(l,idx)
    #define ceu_lua_isboolean(set,l,idx)         set = lua_isboolean(l,idx)
    #define ceu_lua_toboolean(set,l,idx)         set = lua_toboolean(l,idx)
    #define ceu_lua_pop(l,n)                     lua_pop(l,n)
    #define ceu_lua_isstring(set,l,idx)          set = lua_isstring(l,idx)
    #define ceu_lua_tostring(set,l,idx)          set = lua_tostring(l,idx)
    #define ceu_lua_islightuserdata(set,l,idx)   set = lua_islightuserdata(l,idx)
    #define ceu_lua_touserdata(set,l,idx)        set = lua_touserdata(l,idx)
    #define ceu_lua_error(l)                     lua_error(l)
#endif
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

/* TODO: remove */
#define tceu_evtp void*

/* TCEU_STK */

/* TODO(speed): hold nxt trl to run */
typedef struct tceu_stk {
    tceu_nevt evt;  /* TODO: small in the end of struct? */
    tceu_evtp evtp;
#ifdef CEU_INTS
#ifdef CEU_ORGS
    void* evto;
#endif
#endif

    tceu_trl* trl;  /* trail being traversed */
#ifdef CEU_ORGS
    void* org;      /* org being traversed */
#endif
#ifdef CEU_CLEAR
    void* stop;     /* stop at this trl/org */
        /* traversals may be bounded to org/trl
         * default (NULL) is to traverse everything */
#endif
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
    u8 isAlive: 1;          /* Two purposes:
                             * - =0 if terminate normally or =1 if from scope
                             *      checked to see if should call free on pool
                             * - required by "watching o" to avoid awaiting a
                             *      dead org
                             */
#ifdef CEU_NEWS
    u8 isDyn: 1;            /* created w/ new or spawn? */
    struct tceu_org* nxt_free;  /* "to free" list (only on reaction end) */
#endif
#endif  /* CEU_ORGS */

#ifdef CEU_NEWS_POOL
    void*  pool;            /* TODO(ram): opt, traverse lst of cls pools */
#endif

    tceu_trl trls[0];       /* first trail */

} tceu_org;

/* TCEU_GO */

/* TODO: tceu_go => tceu_stk? */
typedef struct tceu_go {
#if defined(CEU_ORGS) || defined(CEU_OS)
    #define CEU_MAX_STACK   128
    /* TODO: CEU_ORGS is calculable // CEU_NEWS isn't (255?) */
#else
    #define CEU_MAX_STACK   (CEU_NTRAILS+1) /* current +1 for each trail */
#endif
    tceu_stk stk[CEU_MAX_STACK];
    int stki;
} tceu_go;

#define stack_init(go) (go).stki = -1
#define stack_get(go) ((go).stk[(go).stki])
#define stack_pop(go) \
    go.stki--

#if defined(CEU_DEBUG) && !defined(CEU_OS)
#define stack_push(go,elem)             \
    ceu_out_assert((go).stki+1 < CEU_MAX_STACK);  \
    (go).stk[++((go).stki)] = elem
#else
#define stack_push(go,elem)             \
    (go).stk[++((go).stki)] = elem
#endif

#define STK  stack_get(go)
#define _STK stack_get(*_ceu_go)
#ifdef CEU_ORGS
#define STK_ORG_ATTR  (STK.org)
#define _STK_ORG_ATTR (_STK.org)
#else
#define STK_ORG_ATTR  (app->data)
#define _STK_ORG_ATTR (_ceu_app->data)
#endif
#define STK_ORG  ((tceu_org*)STK_ORG_ATTR)    /* not an lvalue */
#define _STK_ORG ((tceu_org*)_STK_ORG_ATTR)   /* not an lvalue */
#define STK_LBL (STK.trl->lbl)

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
    s32         wclk_late;
    s32         wclk_min;
    s32         wclk_min_tmp;
#ifdef CEU_TIMEMACHINE
    s32         wclk_late_;
    s32         wclk_min_;
    s32         wclk_min_tmp_;
#endif
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
#if defined(CEU_LUA) || defined(CEU_OS)
#ifdef CEU_LUA
    lua_State*  lua;    /* TODO: move to data? */
#else
    void*       lua;
#endif
#endif

    int         (*code)  (struct tceu_app*,tceu_go*);
    void        (*init)  (struct tceu_app*);
#ifdef CEU_OS
    tceu_evtp   (*calls) (struct tceu_app*,tceu_nevt,tceu_evtp);
    void**      sys_vec;
    void*       addr;
#ifdef CEU_OS_LUAIFC
    char*       luaifc;
#endif
#endif
    tceu_org*   data;
} tceu_app;

#ifdef CEU_OS
typedef void (*tceu_init)   (tceu_app* app);
typedef void (*tceu_export) (uint* size, tceu_init** init
#ifdef CEU_OS_LUAIFC
                            , char** luaifc
#endif
);
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
    RET_HALT = 0
    /*RET_GOTO,*/
#if defined(CEU_INTS) || defined(CEU_CLEAR) || defined(CEU_ORGS)
    , RET_RESTART
#endif
#ifdef CEU_ASYNCS
    , RET_ASYNC
#endif
#ifdef CEU_RET
    , RET_QUIT
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

void ceu_os_init      (void);
int  ceu_os_scheduler (int(*dt)());
tceu_queue* ceu_sys_queue_nxt (void);
void        ceu_sys_queue_rem (void);

void      ceu_sys_assert    (int v);
void      ceu_sys_log       (int mode, void* str);
void*     ceu_sys_realloc   (void* ptr, size_t size);
int       ceu_sys_req       (void);
tceu_app* ceu_sys_load      (void* addr);
#ifdef CEU_ISR
int       ceu_sys_isr       (int n, tceu_isr_f f, tceu_app* app);
#endif
void      ceu_sys_org       (tceu_org* org, int n, int lbl, int seqno, int isDyn, tceu_org* par_org, int par_trl);
#ifdef CEU_ORGS
void      ceu_sys_org_trail (tceu_org* org, int idx, tceu_org_lnk* lnk);
int       ceu_sys_org_spawn (tceu_go* _ceu_go, tceu_nlbl lbl_cnt, tceu_org* org, tceu_nlbl lbl_org);
#endif
void      ceu_sys_start     (tceu_app* app);
int       ceu_sys_link      (tceu_app* src_app, tceu_nevt src_evt, tceu_app* dst_app, tceu_nevt dst_evt);
int       ceu_sys_unlink    (tceu_app* src_app, tceu_nevt src_evt, tceu_app* dst_app, tceu_nevt dst_evt);
int       ceu_sys_emit      (tceu_app* app, tceu_nevt evt, int sz, tceu_evtp param);
tceu_evtp ceu_sys_call      (tceu_app* app, tceu_nevt evt, tceu_evtp param);

enum {
    CEU_SYS_ASSERT = 0,
    CEU_SYS_LOG,
    CEU_SYS_REALLOC,
    CEU_SYS_REQ,
    CEU_SYS_LOAD,
#ifdef CEU_ISR
    CEU_SYS_ISR,
#endif
    CEU_SYS_ORG,
#ifdef CEU_ORGS
    CEU_SYS_ORG_TRAIL,
    CEU_SYS_ORG_SPAWN,
#endif
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
