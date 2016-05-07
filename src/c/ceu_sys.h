#ifndef _CEU_SYS_H
#define _CEU_SYS_H

#include <stddef.h>
#include "ceu_types.h"

#ifdef CEU_DEBUG
#include <assert.h>
#endif

#if defined(CEU_OS_KERNEL) || defined(CEU_OS_APP)
#define CEU_OS
#endif

#if defined(CEU_ORGS_NEWS) || defined(CEU_ADTS_NEWS)
#define CEU_NEWS
#endif
#if defined(CEU_ORGS_NEWS_POOL) || defined(CEU_ADTS_NEWS_POOL)
#define CEU_NEWS_POOL
#endif
#if defined(CEU_ORGS_AWAIT) || defined(CEU_ADTS_AWAIT)
#define CEU_ORGS_OR_ADTS_AWAIT
#endif

#ifdef CEU_OS

    /* TODO: all should be configurable */
    #define CEU_EXTS
    #define CEU_WCLOCKS
    #define CEU_ASYNCS
    #define CEU_RET
    #define CEU_CLEAR
    #define CEU_STACK_CLEAR
    #define CEU_INTS
    #define CEU_ORGS
    /*#define CEU_PSES*/ /* TODO: never tried */
    #define CEU_NEWS
    #define CEU_NEWS_POOL
    #define CEU_ORGS_NEWS
    #define CEU_ORGS_NEWS_MALLOC
    #define CEU_ORGS_NEWS_POOL
    #define CEU_ADTS_NEWS
    #define CEU_ADTS_NEWS_MALLOC
    #define CEU_ADTS_NEWS_POOL
    #define CEU_ORGS_AWAIT
    #define CEU_ADTS_AWAIT
    #define CEU_ORGS_OR_ADTS_AWAIT
/*
    #define CEU_THREADS
*/

    #define CEU_QUEUE_MAX 65536

    #define CEU_IN__NONE          0
    #define CEU_IN__ORG         255
    #define CEU_IN__ORG_PSED    254
    #define CEU_IN__CLEAR       253
    #define CEU_IN__ok_killed   252
    #define CEU_IN__INIT        251     /* HIGHER EXTERNAL */
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
    #define CEU_IN              242
#endif

    #define CEU_IN_higher       CEU_IN__INIT  /* _INIT = HIGHER EXTERNAL */
    #define CEU_IN_lower        128     /* TODO: not checked from up and down */

    typedef s8 tceu_nlbl;   /* TODO: to small!! */

#endif /* CEU_OS */

#ifdef CEU_OS_APP

    #define ceu_out_log(mode,str) \
        ((__typeof__(ceu_sys_log)*)((_ceu_app)->sys_vec[CEU_SYS_LOG]))(mode,str)

    #define ceu_out_assert(v) \
        ((__typeof__(ceu_sys_assert)*)((_ceu_app)->sys_vec[CEU_SYS_ASSERT]))(v)

    #define ceu_out_assert_msg_ex(v,msg,file,line)       \
        {                                                \
            int __ceu_v = v;                             \
            if ((!(__ceu_v)) && ((msg)!=NULL)) {         \
                ceu_out_log(0, (long)"[");               \
                ceu_out_log(0, (long)(file));            \
                ceu_out_log(0, (long)":");               \
                ceu_out_log(2, (line));                  \
                ceu_out_log(0, (long)"] ");              \
                ceu_out_log(0, (long)"runtime error: "); \
                ceu_out_log(0, (long)(msg));             \
                ceu_out_log(0, (long)"\n");              \
            }                                            \
            ((__typeof__(ceu_sys_assert)*)((_ceu_app)->sys_vec[CEU_SYS_ASSERT]))(__ceu_v); \
        }
    #define ceu_out_assert_msg(v,msg) ceu_out_assert_msg_ex((v),(msg),__FILE__,__LINE__)

    #define ceu_out_realloc(ptr, size) \
        ((__typeof__(ceu_sys_realloc)*)((_ceu_app)->sys_vec[CEU_SYS_REALLOC]))(ptr,size)

    #define ceu_out_req() \
        ((__typeof__(ceu_sys_req)*)((_ceu_app)->sys_vec[CEU_SYS_REQ]))()

    #define ceu_out_load(addr) \
        ((__typeof__(ceu_sys_load)*)((_ceu_app)->sys_vec[CEU_SYS_LOAD]))(addr)

#ifdef CEU_ISRS
    #define ceu_out_isr(n,f) \
        ((__typeof__(ceu_sys_isr)*)((_ceu_app)->sys_vec[CEU_SYS_ISR]))(n,f,_ceu_app)
#endif

    #define ceu_out_org_init(app,org,n,lbl,cls,isDyn,parent_org,parent_trl) \
        ((__typeof__(ceu_sys_org_init)*)((app)->sys_vec[CEU_SYS_ORG]))(org,n,lbl,cls,isDyn,parent_org,parent_trl)
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

#else /* ! CEU_OS_APP (!CEU_OS||CEU_OS_KERNEL) */

    #ifndef ceu_out_assert
        #error "Missing definition for macro \"ceu_out_assert\"."
    #endif

    #ifndef ceu_out_log
        #error "Missing definition for macro \"ceu_out_log\"."
    #endif

    #define ceu_out_assert_msg_ex(v,msg,file,line)          \
        {                                                   \
            int __ceu_v = v;                                \
            if ((!(__ceu_v)) && ((msg)!=NULL)) {            \
                ceu_out_log(0, (long)"[");                  \
                ceu_out_log(0, (long)(file));               \
                ceu_out_log(0, (long)":");                  \
                ceu_out_log(2, line);                       \
                ceu_out_log(0, (long)"] ");                 \
                ceu_out_log(0, (long)"runtime error: ");    \
                ceu_out_log(0, (long)(msg));                \
                ceu_out_log(0, (long)"\n");                 \
            }                                               \
            ceu_out_assert(__ceu_v);                        \
        }
    #define ceu_out_assert_msg(v,msg) ceu_out_assert_msg_ex((v),(msg),__FILE__,__LINE__)

    #define ceu_out_realloc(ptr,size) \
            ceu_sys_realloc(ptr,size)
    #define ceu_out_req() \
            ceu_sys_req()
    #define ceu_out_org_init(app,org,n,lbl,cls,isDyn,parent_org,parent_trl) \
            ceu_sys_org_init(org,n,lbl,cls,isDyn,parent_org,parent_trl)

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
    #define ceu_out_go_stk(app,evt,evtp,stk) \
            ceu_sys_go_stk(app,evt,evtp,stk)

#endif /* ! CEU_OS_APP (!CEU_OS||CEU_OS_KERNEL) */

#ifdef CEU_STACK_CLEAR
#define ceu_in_emit(app,id,n,buf) \
    ceu_out_go_stk(app,id,buf,&stk_)
#else
#define ceu_in_emit(app,id,n,buf) \
    ceu_out_go_stk(app,id,buf,NULL)
#endif

#ifdef CEU_THREADS
/* TODO: app */
#include "ceu_threads.h"
typedef struct tceu_threads_data {
    CEU_THREADS_T id;
    u8 has_started:    1;
    u8 has_terminated: 1;
    u8 has_aborted:    1;
    u8 has_notified:   1;
    u8 has_joined:     1;
    struct tceu_threads_data* nxt;
} tceu_threads_data;
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

    #define ceu_lua_error(l) {                          \
        lua_State** p = &l;                             \
        ceu_out_call(_ceu_app, CEU_OUT_LUA_ERROR, &p);  \
    }

    #define ceu_lua_objlen(set, l, idx) {                       \
        tceu__lua_State___int p = { l, idx };                   \
        set = ceu_out_call(_ceu_app, CEU_OUT_LUA_OBJLEN, &p);   \
    }

#else
    #define ceu_lua_atpanic(l,f)                 lua_atpanic(l,f)
    #define ceu_lua_concat(l,n)                  lua_concat(l,n)
    #define ceu_luaL_newstate(set)               set = luaL_newstate()
    #define ceu_luaL_openlibs(l)                 luaL_openlibs(l)
    #define ceu_luaL_loadstring(set,l,str)       set = luaL_loadstring(l,str)
    #define ceu_lua_pushboolean(l,v)             lua_pushboolean(l,v)
    #define ceu_lua_pushnumber(l,v)              lua_pushnumber(l,v)
    #define ceu_lua_pushstring(l,v)              lua_pushstring(l,v)
    #define ceu_lua_pushlstring(l,v,n)           lua_pushlstring(l,v,n)
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
    #define ceu_lua_objlen(set,l,idx)            set = lua_objlen(l,idx)
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

struct tceu_org;
typedef union tceu_trl {
    tceu_nevt evt;

    /* normal await // IN__CLEAR */
    struct {                    /* TODO(ram): bitfields */
        tceu_nevt evt1;
        tceu_nlbl lbl;
        u8        seqno;        /* TODO(ram): 2 bits is enough */
#ifdef CEU_INTS                 /* R-9: size of trails for internal events */
#ifdef CEU_ORGS
        void*     evto;
#endif
#endif
    };

    /* IN__ORG */
#ifdef CEU_ORGS
    struct {                    /* TODO(ram): bad for alignment */
        tceu_nevt evt3;
        struct tceu_org* org;
    };
#endif

    /* _ok_killed */
#ifdef CEU_ORGS_OR_ADTS_AWAIT
    struct {
        tceu_nevt evt4;
        tceu_nlbl lbl4;
        u8        seqno2;       /* TODO(ram): 2 bits is enough */
#ifdef CEU_ORGS_AWAIT
#ifdef CEU_ADTS_AWAIT
        u8        is_org;
#endif
#endif
        u8        t_kills;      /* avoids awake from old org in the same address */
        void*     org_or_adt;
    };
#endif
} tceu_trl;

/* TCEU_EVT */

typedef struct tceu_evt {
    tceu_nevt id;
    void*     param;
#if defined(CEU_ORGS) && defined(CEU_INTS)
    void*     org;      /* emitting org */
#endif
} tceu_evt;

/* TCEU_ORG */

struct tceu_pool_orgs;
typedef struct tceu_org
{
#ifdef CEU_ORGS
    struct tceu_org* nxt; /* first field because of free list for orgs/adts */
    struct tceu_org* prv;
    struct tceu_org* parent_org;
    tceu_ntrl parent_trl;
#endif

#if defined(CEU_ORGS) || defined(CEU_OS)
    tceu_ntrl n;            /* number of trails (TODO(ram): opt, metadata) */
#endif

#ifdef CEU_ORGS

#ifdef CEU_IFCS
    tceu_ncls cls;          /* class id */
#endif
    u8 isAlive: 1;          /* Three purposes:
                             * - avoids double free
                             * - required by "watching o" to avoid awaiting a
                             *      dead org
                             * - required by "Do T" to avoid awaiting a dead 
                             *      org
                             */
#if defined(CEU_ORGS_NEWS) || defined(CEU_ORGS_AWAIT)
#endif
#ifdef CEU_ORGS_NEWS
    u8 isDyn: 1;            /* created w/ new or spawn? */
#endif
#ifdef CEU_ORGS_NEWS_POOL
    struct tceu_pool_orgs* pool;
#endif

#ifdef CEU_ORGS_AWAIT
    int ret;
#endif

#endif  /* CEU_ORGS */

    tceu_trl trls[0];       /* first trail */

} tceu_org;

/* TCEU_POOL_ORGS , TCEU_POOL_ADTS */

#if defined(CEU_ORGS_NEWS_POOL) || defined(CEU_ADTS_NEWS_POOL)
#include "ceu_pool.h"
#endif

#ifdef CEU_ORGS_NEWS
typedef struct tceu_pool_orgs {
    tceu_org* parent_org;
    tceu_ntrl parent_trl;
#ifdef CEU_ORGS_NEWS_POOL
    tceu_pool pool;
#endif
} tceu_pool_orgs;
#endif

#ifdef CEU_ADTS_NEWS
typedef struct {
    void* root;
#ifdef CEU_ADTS_NEWS_POOL
    void* pool;
#endif
} tceu_pool_adts;
#endif

/* TCEU_KILL */

#ifdef CEU_ORGS_OR_ADTS_AWAIT
typedef struct tceu_kill {
    void*     org_or_adt;
    u8        t_kills;      /* TODO: u8? */
#ifdef CEU_ORGS_AWAIT
    int       ret;
    tceu_ntrl t1;
    tceu_ntrl t2;
#endif
} tceu_kill;
#endif

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

/* TCEU_STK */

typedef struct tceu_stk {
    tceu_evt*   evt;
#ifdef CEU_STACK_CLEAR
    struct tceu_stk* down;
    tceu_org*   org;
    tceu_ntrl   trl1;
    tceu_ntrl   trl2;
    char        is_alive;
#endif
} tceu_stk;

/* TCEU_APP */

typedef struct tceu_app {
    /* global seqno: incremented on every reaction
     * awaiting trails matches only if trl->seqno < seqno,
     * i.e., previously awaiting the event
     */
    u8 seqno:          2;
#if defined(CEU_RET) || defined(CEU_OS)
    u8 isAlive:        1;
#endif
#ifdef CEU_ASYNCS
    u8 pendingAsyncs:  1;
#endif
#if defined(CEU_ORGS_NEWS_MALLOC) && defined(CEU_ORGS_AWAIT)
    u8 dont_emit_kill: 1;
#endif

#ifdef CEU_OS
    struct tceu_app* nxt;
#endif

#if defined(CEU_RET) || defined(CEU_ORGS_AWAIT)
    int ret;
#endif

#ifdef CEU_ORGS_OR_ADTS_AWAIT
    u8 t_kills;                 /* TODO: u8? */
#endif

#ifdef CEU_ORGS_NEWS_MALLOC
    tceu_org* tofree;
#endif

#ifdef CEU_WCLOCKS
    s32         wclk_late;
    s32         wclk_min_set;   /* used to set */
    s32         wclk_min_cmp;   /* used to compare */
                                /* cmp<-set every reaction */
#ifdef CEU_TIMEMACHINE
    s32         wclk_late_;
    s32         wclk_min_set_;
    s32         wclk_min_cmp_;
#endif
#endif

#ifndef CEU_OS
#ifdef CEU_DEBUG
    tceu_lst    lst; /* segfault printf */
#endif
#endif

#ifdef CEU_THREADS
    CEU_THREADS_MUTEX_T threads_mutex;
    tceu_threads_data*  threads_head;   /* linked list of threads alive */
#endif
#if defined(CEU_LUA) || defined(CEU_OS)
#ifdef CEU_LUA
    lua_State*  lua;    /* TODO: move to data? */
#else
    void*       lua;
#endif
#endif

    void        (*code)  (struct tceu_app*,tceu_evt*,tceu_org*,tceu_trl*,tceu_stk*);
    void        (*init)  (struct tceu_app*);
#ifdef CEU_OS
    void*       (*calls) (struct tceu_app*,tceu_nevt,void*);
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
    tceu_app*          app;
    tceu_org*          org;
    tceu_threads_data* thread;
} tceu_threads_param;
#endif

#ifdef CEU_PSES
void ceu_pause (tceu_trl* trl, tceu_trl* trlF, int psed);
#endif

int ceu_go_all (tceu_app* app, int argc, char **argv);

#ifdef CEU_WCLOCKS
int ceu_sys_wclock (tceu_app* app, s32 dt, s32* set, s32* get);
#endif
void ceu_sys_go (tceu_app* app, int evt, void* evtp);

#endif  /* _CEU_OS_H */
