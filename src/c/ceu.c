#include <stddef.h>     /* offsetof */
#include <stdlib.h>     /* NULL */
#include <string.h>     /* memset, strlen */
#ifdef CEU_TESTS
#include <stdio.h>
#endif

#ifdef CEU_FEATURES_LUA
#include <lua5.3/lua.h>
#include <lua5.3/lauxlib.h>
#include <lua5.3/lualib.h>
#endif

#define S8_MIN   -127
#define S8_MAX    127
#define U8_MAX    255

#define S16_MIN  -32767
#define S16_MAX   32767
#define U16_MAX   65535

#define S32_MIN  -2147483647
#define S32_MAX   2147483647
#define U32_MAX   4294967295

#define S64_MIN  -9223372036854775807
#define S64_MAX   9223372036854775807
#define U64_MAX   18446744073709551615

typedef u16 tceu_nevt;   /* TODO */
typedef u16 tceu_nseq;   /* TODO */
typedef u8  tceu_nstk;   /* TODO */
typedef === CEU_TCEU_NTRL === tceu_ntrl;
typedef === CEU_TCEU_NLBL === tceu_nlbl;

#define CEU_TRAILS_N === CEU_TRAILS_N ===

#define CEU_API
CEU_API void ceu_start (tceu_callback* cb, int argc, char* argv[]);
CEU_API void ceu_stop  (void);
CEU_API void ceu_input (tceu_nevt evt_id, void* evt_params);
CEU_API int  ceu_loop  (tceu_callback* cb, int argc, char* argv[]);
CEU_API void ceu_callback_register (tceu_callback* cb);

struct tceu_code_mem;
struct tceu_pool_pak;

typedef struct tceu_evt {
    tceu_nevt id;
    union {
        void* mem;                   /* CEU_INPUT__PROPAGATE_CODE, CEU_EVENT__MIN */
#ifdef CEU_FEATURES_POOL
        struct tceu_pool_pak* pak;   /* CEU_INPUT__PROPAGATE_POOL */
#endif
    };
} tceu_evt;

typedef struct tceu_range {
    struct tceu_code_mem* mem;
    tceu_ntrl             trl0;
    tceu_ntrl             trlF;
} tceu_range;

typedef struct tceu_stk {
    tceu_evt   evt;
    void*      params;
    tceu_range range;
} tceu_stk;

struct tceu_data_Exception;

typedef struct tceu_trl {
    struct {
        tceu_evt evt;
        union {
            /* NORMAL, CEU_EVENT__MIN */
            struct {
                tceu_nlbl lbl;
                union {
                    tceu_nstk  stk_level;   /* CEU_INPUT__STACKED */
                    tceu_range clr_range;   /* CEU_INPUT__CLEAR */
                };
            };

            /* CEU_INPUT__PAUSE_BLOCK */
            struct {
                tceu_evt  pse_evt;
                tceu_ntrl pse_skip;
                u8        pse_paused;
            };
        };
    };
} tceu_trl;

#ifdef CEU_FEATURES_EXCEPTION
typedef struct tceu_catch {
    struct tceu_catch*         up;
    struct tceu_code_mem*      mem;
    tceu_ntrl                  trl;
    struct tceu_opt_Exception* exception;
} tceu_catch;
#endif

typedef struct tceu_code_mem {
#ifdef CEU_FEATURES_POOL
    struct tceu_pool_pak* pak;
#endif
    struct tceu_code_mem* up_mem;
    tceu_ntrl   up_trl;
    u8          depth;
#ifdef CEU_FEATURES_TRACE
    tceu_trace  trace;
#endif
#ifdef CEU_FEATURES_EXCEPTION
    tceu_catch* catches;
#endif
#ifdef CEU_FEATURES_LUA
    lua_State*  lua;
#endif
    tceu_ntrl   trails_n;
    tceu_trl    _trails[0];
} tceu_code_mem;

#ifdef CEU_FEATURES_POOL
typedef struct tceu_code_mem_dyn {
    struct tceu_code_mem_dyn* prv;
    struct tceu_code_mem_dyn* nxt;
    u8 is_alive: 1;
    tceu_code_mem mem[0];   /* actual tceu_code_mem is in sequence */
} tceu_code_mem_dyn;

typedef struct tceu_pool_pak {
    tceu_pool         pool;
    tceu_code_mem_dyn first;
    tceu_code_mem*    up_mem;
    tceu_ntrl         up_trl;
    u8                n_traversing;
} tceu_pool_pak;
#endif

#ifdef CEU_FEATURES_TRACE
#define CEU_OPTION_EVT(a,b) CEU_OPTION_EVT_(a,b)
#else
#define CEU_OPTION_EVT(a,b) CEU_OPTION_EVT_(a)
#endif

static tceu_evt* CEU_OPTION_EVT_ (tceu_evt* alias
#ifdef CEU_FEATURES_TRACE
                                 , tceu_trace trace
#endif
                                 )
{
    ceu_assert_ex(alias != NULL, "value is not set", trace);
    return alias;
}

#ifdef CEU_FEATURES_THREAD
typedef struct tceu_threads_data {
    CEU_THREADS_T id;
    u8 has_started:    1;
    u8 has_terminated: 1;
    u8 has_aborted:    1;
    u8 has_notified:   1;
    struct tceu_threads_data* nxt;
} tceu_threads_data;

typedef struct {
    tceu_code_mem*     mem;
    tceu_threads_data* thread;
} tceu_threads_param;
#endif

#ifdef CEU_FEATURES_ISR
typedef struct tceu_evt_id_params {
    tceu_nevt id;
    void*     params;
} tceu_evt_id_params;

typedef struct tceu_isr {
    void (*fun)(tceu_code_mem*);
    tceu_code_mem*     mem;
    tceu_evt_id_params evt;
} tceu_isr;

#endif

/*****************************************************************************/

/* CEU_NATIVE_PRE */
=== CEU_NATIVE_PRE ===

/* EVENTS_ENUM */

enum {
    /* non-emitable */
    CEU_INPUT__NONE = 0,
    CEU_INPUT__STACKED,
    CEU_INPUT__FINALIZE,
    CEU_INPUT__THROW,
    CEU_INPUT__PAUSE_BLOCK,
    CEU_INPUT__PROPAGATE_CODE,
    CEU_INPUT__PROPAGATE_POOL,

    /* emitable */
    CEU_INPUT__CLEAR,           /* 7 */
    CEU_INPUT__PAUSE,
    CEU_INPUT__RESUME,
CEU_INPUT__SEQ,
    CEU_INPUT__CODE_TERMINATED,
    CEU_INPUT__ASYNC,
    CEU_INPUT__THREAD,
    CEU_INPUT__WCLOCK,
    === CEU_EXTS_ENUM_INPUT ===

CEU_EVENT__MIN,
    === CEU_EVTS_ENUM ===
};

enum {
    CEU_OUTPUT__NONE = 0,
    === CEU_EXTS_ENUM_OUTPUT ===
};

/* CEU_ISRS_DEFINES */

=== CEU_ISRS_DEFINES ===

/* EVENTS_DEFINES */

=== CEU_EXTS_DEFINES_INPUT_OUTPUT ===

/* CEU_DATAS_HIERS */

typedef s16 tceu_ndata;  /* TODO */

=== CEU_DATAS_HIERS ===

static int ceu_data_is (tceu_ndata* supers, tceu_ndata me, tceu_ndata cmp) {
    return (me==cmp || (me!=0 && ceu_data_is(supers,supers[me],cmp)));
}

#ifdef CEU_FEATURES_TRACE
#define ceu_data_as(a,b,c,d) ceu_data_as_(a,b,c,d)
#else
#define ceu_data_as(a,b,c,d) ceu_data_as_(a,b,c)
#endif

static void* ceu_data_as_ (tceu_ndata* supers, tceu_ndata* me, tceu_ndata cmp
#ifdef CEU_FEATURES_TRACE
                         , tceu_trace trace
#endif
                         )
{
    ceu_assert_ex(ceu_data_is(supers, *me, cmp), "invalid cast `as`", trace);
    return me;
}

/* CEU_DATAS_MEMS */

#pragma pack(push,1)
=== CEU_DATAS_MEMS ===
=== CEU_DATAS_MEMS_CASTS ===
#pragma pack(pop)

#ifdef CEU_FEATURES_EXCEPTION
typedef struct tceu_opt_Exception {
    bool      is_set;
    tceu_data_Exception value;
} tceu_opt_Exception;

#ifdef CEU_FEATURES_TRACE
#define CEU_OPTION_tceu_opt_Exception(a,b) CEU_OPTION_tceu_opt_Exception_(a,b)
#else
#define CEU_OPTION_tceu_opt_Exception(a,b) CEU_OPTION_tceu_opt_Exception_(a)
#endif

static tceu_opt_Exception* CEU_OPTION_tceu_opt_Exception_ (tceu_opt_Exception* opt
#ifdef CEU_FEATURES_TRACE
                                                          , tceu_trace trace
#endif
                                                          )
{
    ceu_assert_ex(opt->is_set, "value is not set", trace);
    return opt;
}
#endif

/*****************************************************************************/

=== CEU_CODES_MEMS ===
#if 0
=== CODES_ARGS ===
#endif

=== CEU_EXTS_TYPES ===
=== CEU_EVTS_TYPES ===

enum {
    CEU_LABEL_NONE = 0,
    === CEU_LABELS ===
};

/*****************************************************************************/

typedef struct tceu_app {
    int    argc;
    char** argv;

    bool end_ok;
    int  end_val;

    /* SEQ */
    tceu_nseq seq;
    tceu_nseq seq_base;

    /* CALLBACKS */
    tceu_callback* cbs;

    /* ASYNC */
    bool async_pending;

    /* WCLOCK */
    s32 wclk_late;
    s32 wclk_min_set;
    s32 wclk_min_cmp;

#ifdef CEU_FEATURES_THREAD
    CEU_THREADS_MUTEX_T threads_mutex;
    tceu_threads_data*  threads_head;   /* linked list of threads alive */
    tceu_threads_data** cur_;           /* TODO: HACK_6 "gc" mutable iterator */
#endif

    tceu_code_mem_ROOT root;
} tceu_app;

CEU_API static tceu_app CEU_APP;

/*****************************************************************************/

static tceu_code_mem* ceu_outer (tceu_code_mem* mem, u8 n) {
    for (; mem->depth!=n; mem=mem->up_mem);
    return mem;
}

/*****************************************************************************/

#define CEU_WCLOCK_INACTIVE INT32_MAX

#ifdef CEU_FEATURES_TRACE
#define ceu_wclock(a,b,c,d) ceu_wclock_(a,b,c,d)
#else
#define ceu_wclock(a,b,c,d) ceu_wclock_(a,b,c)
#endif

static int ceu_wclock_ (s32 dt, s32* set, s32* sub
#ifdef CEU_FEATURES_TRACE
                      , tceu_trace trace
#endif
                      )
{
    s32 t;          /* expiring time of track to calculate */
    int ret = 0;    /* if track expired (only for "sub") */

    /* SET */
    if (set != NULL) {
        t = dt - CEU_APP.wclk_late;
        *set = t;

    /* SUB */
    } else {
        t = *sub;
        if ((t > CEU_APP.wclk_min_cmp) || (t > dt)) {
            *sub -= dt;    /* don't expire yet */
            t = *sub;
        } else {
            ret = 1;    /* single "true" return */
        }
    }

    /* didn't awake, but can be the smallest wclk */
    if ( (!ret) && (CEU_APP.wclk_min_set > t) ) {
        CEU_APP.wclk_min_set = t;
        ceu_callback_num_ptr(CEU_CALLBACK_WCLOCK_MIN, t, NULL, trace);
    }

    return ret;
}

/*****************************************************************************/

#ifdef CEU_FEATURES_POOL
void ceu_code_mem_dyn_free (tceu_pool* pool, tceu_code_mem_dyn* cur) {
    cur->nxt->prv = cur->prv;
    cur->prv->nxt = cur->nxt;

#ifdef CEU_FEATURES_DYNAMIC
    if (pool->queue == NULL) {
        /* dynamic pool */
        ceu_callback_ptr_num(CEU_CALLBACK_REALLOC, cur, 0, CEU_TRACE_null);
    } else
#endif
    {
        /* static pool */
        ceu_pool_free(pool, (byte*)cur);
    }
}

void ceu_code_mem_dyn_remove (tceu_pool* pool, tceu_code_mem_dyn* cur) {
    cur->is_alive = 0;

    if (cur->mem[0].pak->n_traversing == 0) {
        ceu_code_mem_dyn_free(pool, cur);
    }
}

void ceu_code_mem_dyn_gc (tceu_pool_pak* pak) {
    if (pak->n_traversing == 0) {
        /* TODO-OPT: one element killing another is unlikely:
                     set bit in pool when this happens and only
                     traverses in this case */
        tceu_code_mem_dyn* cur = pak->first.nxt;
        while (cur != &pak->first) {
            tceu_code_mem_dyn* nxt = cur->nxt;
            if (!cur->is_alive) {
                ceu_code_mem_dyn_free(&pak->pool, cur);
            }
            cur = nxt;
        }
    }
}
#endif

/*****************************************************************************/

#ifdef CEU_FEATURES_LUA
static void ceu_lua_createargtable (lua_State* lua, char** argv, int argc, int script) {
    int i, narg;
    if (script == argc) script = 0;  /* no script name? */
    narg = argc - (script + 1);  /* number of positive indices */
    lua_createtable(lua, narg, script + 1);
    for (i = 0; i < argc; i++) {
        lua_pushstring(lua, argv[i]);
        lua_rawseti(lua, -2, i - script);
    }
    lua_setglobal(lua, "arg");
}

#endif

/*****************************************************************************/

CEU_API void ceu_callback_register (tceu_callback* cb) {
    cb->nxt = CEU_APP.cbs;
    CEU_APP.cbs = cb;
}

static void ceu_callback (int cmd, tceu_callback_val p1, tceu_callback_val p2
#ifdef CEU_FEATURES_TRACE
                         , tceu_trace trace
#else
#endif
                         )
{
    tceu_callback* cur = CEU_APP.cbs;
    while (cur) {
        int is_handled = cur->f(cmd,p1,p2
#ifdef CEU_FEATURES_TRACE
              ,trace
#endif
              );
        if (is_handled) {
            return;
        }
        cur = cur->nxt;
    }

#define CEU_TRACE(n) trace
    if (cmd == CEU_CALLBACK_OUTPUT) {
        switch (p1.num) {
            === CEU_CALLBACKS_OUTPUTS ===
        }
    }
#undef CEU_TRACE
}

/*****************************************************************************/

=== CEU_NATIVE_POS ===

=== CEU_CODES_WRAPPERS ===

=== CEU_ISRS ===

=== CEU_THREADS ===

/*****************************************************************************/

#ifdef CEU_FEATURES_EXCEPTION
void ceu_throw_ex (tceu_catch* catches, tceu_data_Exception* exception, usize len, tceu_stk* stk
#ifdef CEU_FEATURES_TRACE
                  , tceu_trace trace
#endif
                  )
{
    tceu_catch* cur = catches;
    while (cur != NULL) {
        if (ceu_data_is(CEU_DATA_SUPERS_Exception,exception->_enum,cur->exception->value._enum)) {
            //ceu_sys_assert(!cur->exception->is_set, "double catch");
            ceu_assert_ex(!cur->exception->is_set, "double catch", trace);
            cur->exception->is_set = 1;
            memcpy(&cur->exception->value, exception, len);

#if 0
            /* do not allow nested catches (and itself) to awake */
            cur->exception = NULL;
            while (catches != cur) {
                catches->exception = NULL;
                catches = catches->up;
            }
#endif

            return ceu_lbl(NULL, stk, cur->mem, cur->trl, cur->mem->_trails[cur->trl].lbl);
        }
        cur = cur->up;
    }
    ceu_assert_ex(0, exception->message, trace);
}
#ifdef CEU_FEATURES_TRACE
#define ceu_throw(a,b,c) ceu_throw_ex(a,b,c,_ceu_stk,CEU_TRACE(0))
#else
#define ceu_throw(a,b,c) ceu_throw_ex(a,b,c,_ceu_stk)
#endif
#endif

#ifdef CEU_FEATURES_THREAD
int ceu_threads_gc (int force_join) {
    int n_alive = 0;
    CEU_APP.cur_ = &CEU_APP.threads_head;
    tceu_threads_data*  head  = *CEU_APP.cur_;
    while (head != NULL) {
        tceu_threads_data** nxt_ = &head->nxt;
        if (head->has_terminated || head->has_aborted)
        {
            if (!head->has_notified) {
                ceu_input(CEU_INPUT__THREAD, &head->id);
                head->has_notified = 1;
            }

            /* remove from list if rejoined */
            {
                int has_joined;
                if (force_join || head->has_terminated) {
                    CEU_THREADS_JOIN(head->id);
                    has_joined = 1;
                } else {
                    /* possible with "CANCEL" which prevents setting "has_terminated" */
                    has_joined = CEU_THREADS_JOIN_TRY(head->id);
                }
                if (has_joined) {
                    *CEU_APP.cur_ = head->nxt;
                    nxt_ = CEU_APP.cur_;
                    ceu_callback_ptr_num(CEU_CALLBACK_REALLOC, head, 0, CEU_TRACE_null);
                }
            }
        }
        else
        {
            n_alive++;
        }
        CEU_APP.cur_ = nxt_;
        head  = *CEU_APP.cur_;
    }
    return n_alive;
}
#endif

/*****************************************************************************/

void ceu_input_one (tceu_nevt evt_id, void* evt_params);

#define CEU_GOTO(lbl) {_ceu_lbl=lbl; goto _CEU_LBL_;}

static int ceu_lbl (tceu_nstk _ceu_stk_level, void* _ceu_evt_param, tceu_stk* _ceu_stk, tceu_code_mem* _ceu_mem, tceu_nlbl _ceu_lbl)
{
#define CEU_TRACE(n) ((tceu_trace){&_ceu_mem->trace,__FILE__,__LINE__+(n)})
#ifdef CEU_STACK_MAX
    {
        static void* base = NULL;
        if (base == NULL) {
            base = &_ceu_evt_param;
        } else {
#if 0
#if 0
//Serial.begin(9600);
Serial.println((usize)base);
Serial.println((usize)&_ceu_lbl);
Serial.print(" lbl "); Serial.println(_ceu_lbl);
//Serial.flush();
    if((usize)(((byte*)base)-CEU_STACK_MAX) <= (usize)(&_ceu_evt_param)) {
    } else {
        delay(1000);
    }
#else
printf(">>> %p / %p / %ld\n", base, &_ceu_lbl, ((u64)base)-((u64)&_ceu_lbl));
printf("%ld %ld %d\n", (usize)(base-CEU_STACK_MAX), (usize)(&_ceu_evt_param),
            ((usize)(base-CEU_STACK_MAX) <= (usize)(&_ceu_evt_param)));
#endif
#endif
            ceu_assert((usize)(((byte*)base)-CEU_STACK_MAX) <= (usize)(&_ceu_evt_param), "stack overflow");
        }
    }
#endif

_CEU_LBL_:
    //printf("-=-=- %d -=-=-\n", _ceu_lbl);
    switch (_ceu_lbl) {
        CEU_LABEL_NONE:
            break;
        === CEU_CODES ===
    }
    //ceu_assert(0, "unreachable code");
    return 0;
#undef CEU_TRACE
}

#if defined(_CEU_DEBUG)
#define _CEU_DEBUG
static int xxx = 0;
#endif

static void ceu_bcast_mark (tceu_nstk stk_level, tceu_evt* evt, tceu_range* range)
{
    tceu_ntrl trlK = range->trl0;
    tceu_trl* trl  = &range->mem->_trails[trlK];

    for (; trlK<=range->trlF; trlK++,trl++)
    {
        //printf(">>> A %d %d\n", trlK, range->trlF);
#ifdef CEU_TESTS
        _ceu_tests_trails_visited_++;
#endif
        switch (trl->evt.id)
        {
            case CEU_INPUT__PROPAGATE_CODE: {
#if 0
                // TODO: simple optimization that could be done
                //          - do it also for POOL?
                if (occ->evt.id==CEU_INPUT__CODE_TERMINATED && occ->params==trl->evt.mem ) {
                    // dont propagate when I am terminating
                } else
#endif
                tceu_range _range = {
                    (tceu_code_mem*)trl->evt.mem,
                    0,
                    (tceu_ntrl)(((tceu_code_mem*)trl->evt.mem)->trails_n-1)
                };
                ceu_bcast_mark(stk_level, evt, &_range);
                break;
            }

#ifdef CEU_FEATURES_POOL
            case CEU_INPUT__PROPAGATE_POOL: {
                tceu_code_mem_dyn* cur = trl->evt.pak->first.nxt;
                while (cur != &trl->evt.pak->first) {
                    tceu_range _range = { &cur->mem[0],
                                              0, (tceu_ntrl)((&cur->mem[0])->trails_n-1) };
                    ceu_bcast_mark(stk_level, evt, &_range);
                    cur = cur->nxt;
                }
                break;
            }
#endif

#if 0
            case CEU_INPUT__PAUSE_BLOCK: {
                u8 was_paused = trl->pse_paused;
                if (occ->evt.id==trl->pse_evt.id &&
                    (occ->evt.id<CEU_EVENT__MIN || occ->evt.mem==trl->pse_evt.mem))
                {
                    if (*((u8*)occ->params) != trl->pse_paused) {
                        trl->pse_paused = *((u8*)occ->params);

                        if (trl->pse_paused) {
                            tceu_evt_occ occ2 = { {CEU_INPUT__PAUSE,{NULL}}, CEU_APP.seq, occ->params,
                                                  {range.mem,
                                                   (tceu_ntrl)(trlK+1), (tceu_ntrl)(trlK+trl->pse_skip)}
                                                };
                            ceu_bcast(&occ2, &_stk, 0);
                        } else {
                            CEU_APP.wclk_min_set = 0;   /* maybe resuming a timer, let it be the minimum set */
                            tceu_evt_occ occ2 = { {CEU_INPUT__RESUME,{NULL}}, CEU_APP.seq, occ->params,
                                                  {range.mem,
                                                   (tceu_ntrl)(trlK+1), (tceu_ntrl)(trlK+trl->pse_skip)}
                                                };
                            ceu_bcast(&occ2, &_stk, 0);
                        }
                        ceu_assert_ex(_stk.is_alive, "bug found", CEU_TRACE_null);
                    }
                }
                /* don't skip if pausing now */
                if (was_paused && occ->evt.id!=CEU_INPUT__CLEAR) {
                                  /* also don't skip on CLEAR (going reverse) */
                    trlK += (trl->pse_skip - 1);
                    trl  += (trl->pse_skip - 1);
                    goto _CEU_AWAKE_NO_;
                }
                break;
            }
#endif
        }

        if (evt->id == CEU_INPUT__CLEAR) {
            if (trl->evt.id == CEU_INPUT__FINALIZE) {
                goto _CEU_AWAKE_YES_;
            } else {
//printf("CLR %d\n", trlK);
                trl->evt.id = CEU_INPUT__NONE;
            }
        } else if (evt->id==CEU_INPUT__CODE_TERMINATED && trl->evt.id==CEU_INPUT__PROPAGATE_CODE) {
            if (trl->evt.mem == evt->mem) {
                goto _CEU_AWAKE_YES_;
            }
        } else if (trl->evt.id == evt->id) {
            if (evt->id==CEU_INPUT__PAUSE || evt->id==CEU_INPUT__RESUME) {
                goto _CEU_AWAKE_YES_;
            }
            if (trl->evt.id>CEU_EVENT__MIN || trl->evt.id==CEU_INPUT__CODE_TERMINATED) {
                if (trl->evt.mem == evt->mem) {
                    goto _CEU_AWAKE_YES_;   /* internal event matches "mem" */
                }
            } else {
                if (evt->id != CEU_INPUT__NONE) {
                    goto _CEU_AWAKE_YES_;       /* external event matches */
                }
            }
        }

        return;

_CEU_AWAKE_YES_:
        trl->evt.id    = CEU_INPUT__STACKED;
        trl->stk_level = stk_level;
    }
}

static int ceu_bcast_exec (tceu_nstk stk_level, tceu_evt* evt, void* evt_params, tceu_range* range, tceu_stk* stk)
{
    tceu_ntrl trlK;
    tceu_trl* trl;

    /* CLEAR: inverse execution order */
    tceu_ntrl trl0 = range->trl0;
    tceu_ntrl trlF = range->trlF;
    if (evt->id == CEU_INPUT__CLEAR) {
        tceu_ntrl tmp = trl0;
        trl0 = trlF;
        trlF = tmp;
    }

    //printf(">>> exec %d -> %d\n", trl0, trlF);
    for (trlK=trl0, trl=&range->mem->_trails[trlK]; ;)
    {
        //printf(">>> exec %d\n", trlK);
        switch (trl->evt.id)
        {
            case CEU_INPUT__PROPAGATE_CODE: {
#if 0
                // TODO: simple optimization that could be done
                //          - do it also for POOL?
                if (occ->evt.id==CEU_INPUT__CODE_TERMINATED && occ->params==trl->evt.mem ) {
                    // dont propagate when I am terminating
                } else
#endif
                {
                    tceu_range range_ = {
                        (tceu_code_mem*)trl->evt.mem,
                        0,
                        (tceu_ntrl)(((tceu_code_mem*)trl->evt.mem)->trails_n-1)
                    };
                    if (ceu_bcast_exec(stk_level, evt, evt_params, &range_, stk)) {
                        return 1;
                    }
                }
                break;
            }
#ifdef CEU_FEATURES_POOL
            case CEU_INPUT__PROPAGATE_POOL: {
                tceu_code_mem_dyn* cur = trl->evt.pak->first.nxt;
                while (cur != &trl->evt.pak->first) {
                    tceu_range range_ = { &cur->mem[0],
                                              0, (tceu_ntrl)((&cur->mem[0])->trails_n-1) };
                    if (ceu_bcast_exec(stk_level, evt, evt_params, &range_, stk)) {
                        return 1;
                    }
                    cur = cur->nxt;
                }
                break;
            }
#endif

#if 0
            /* skip "paused" blocks || set "paused" block */
            case CEU_INPUT__PAUSE_BLOCK: {
                u8 was_paused = trl->pse_paused;
                if (occ->evt.id==trl->pse_evt.id &&
                    (occ->evt.id<CEU_EVENT__MIN || occ->evt.mem==trl->pse_evt.mem))
                {
                    if (*((u8*)occ->params) != trl->pse_paused) {
                        trl->pse_paused = *((u8*)occ->params);

                        if (trl->pse_paused) {
                            tceu_evt_occ occ2 = { {CEU_INPUT__PAUSE,{NULL}}, CEU_APP.seq, occ->params,
                                                  {range.mem,
                                                   (tceu_ntrl)(trlK+1), (tceu_ntrl)(trlK+trl->pse_skip)}
                                                };
                            ceu_bcast(&occ2, &_stk, 0);
                        } else {
                            CEU_APP.wclk_min_set = 0;   /* maybe resuming a timer, let it be the minimum set */
                            tceu_evt_occ occ2 = { {CEU_INPUT__RESUME,{NULL}}, CEU_APP.seq, occ->params,
                                                  {range.mem,
                                                   (tceu_ntrl)(trlK+1), (tceu_ntrl)(trlK+trl->pse_skip)}
                                                };
                            ceu_bcast(&occ2, &_stk, 0);
                        }
                        ceu_assert_ex(_stk.is_alive, "bug found", CEU_TRACE_null);
                    }
                }
                /* don't skip if pausing now */
                if (was_paused && occ->evt.id!=CEU_INPUT__CLEAR) {
                                  /* also don't skip on CLEAR (going reverse) */
                    trlK += trl->pse_skip;
                    trl  += trl->pse_skip;
                    goto _CEU_AWAKE_NO_;
                }
                break;
            }
#endif

            case CEU_INPUT__STACKED: {
                if (trl->evt.id==CEU_INPUT__STACKED && trl->stk_level==stk_level) {
                    trl->evt.id = CEU_INPUT__NONE;
                    if (ceu_lbl(stk_level, evt_params, stk, range->mem, trl->lbl)) {
                        return 1;
                    }
                }
                break;
            }
        }

        if (trlK == trlF) {
            break;
        } else if (evt->id == CEU_INPUT__CLEAR) {
            trlK--; trl--;
        } else {
            trlK++; trl++;
        }
    }
    return 0;
}

void ceu_bcast (tceu_nstk stk_level, tceu_evt* evt, void* evt_params, tceu_range* range)
{
    //printf(">>> BCAST[%d]: %d\n", evt->id, stk_level);
    ceu_bcast_mark(stk_level, evt, range);
    while (1) {
        tceu_stk stk;
        int ret = ceu_bcast_exec(stk_level, evt, evt_params, range, &stk);
        if (ret) {
            ceu_assert(stk_level < 255, "too many stack levels");
            ceu_bcast(stk_level+1, &stk.evt, &stk.params, &stk.range);
        } else {
            break;
        }
    }
    //printf("<<< BCAST: %d\n", stk_level);
}

void ceu_input_one (tceu_nevt evt_id, void* evt_params)
{
    CEU_APP.seq_base = CEU_APP.seq;

    switch (evt_id) {
        case CEU_INPUT__WCLOCK:
            CEU_APP.wclk_min_cmp = CEU_APP.wclk_min_set;    /* swap "cmp" to last "set" */
            CEU_APP.wclk_min_set = CEU_WCLOCK_INACTIVE;     /* new "set" resets to inactive */
            ceu_callback_num_ptr(CEU_CALLBACK_WCLOCK_MIN, CEU_WCLOCK_INACTIVE, NULL, CEU_TRACE_null);
            if (CEU_APP.wclk_min_cmp <= *((s32*)evt_params)) {
                CEU_APP.wclk_late = *((s32*)evt_params) - CEU_APP.wclk_min_cmp;
            }
            break;
        case CEU_INPUT__ASYNC:
            CEU_APP.async_pending = 0;
            break;
    }
    if (evt_id != CEU_INPUT__WCLOCK) {
        CEU_APP.wclk_late = 0;
    }

    tceu_evt   evt   = {evt_id, {NULL}};
    tceu_range range = {(tceu_code_mem*)&CEU_APP.root,
                        0, (tceu_ntrl)(CEU_APP.root._mem.trails_n-1)};
    ceu_bcast(1, &evt, evt_params, &range);
}

CEU_API void ceu_input (tceu_nevt evt_id, void* evt_params)
{
    ceu_callback_void_void(CEU_CALLBACK_WCLOCK_DT, CEU_TRACE_null);
    s32 dt = ceu_callback_ret.num;
    if (dt != CEU_WCLOCK_INACTIVE) {
        ceu_input_one(CEU_INPUT__WCLOCK, &dt);
    }
    if (evt_id != CEU_INPUT__NONE) {
        ceu_input_one(evt_id, evt_params);
    }
}

CEU_API void ceu_start (tceu_callback* cb, int argc, char* argv[]) {
    CEU_APP.argc     = argc;
    CEU_APP.argv     = argv;

    CEU_APP.end_ok   = 0;

    CEU_APP.seq      = 0;
    CEU_APP.seq_base = 0;

    CEU_APP.cbs = cb;

    CEU_APP.async_pending = 0;

    CEU_APP.wclk_late = 0;
    CEU_APP.wclk_min_set = CEU_WCLOCK_INACTIVE;
    CEU_APP.wclk_min_cmp = CEU_WCLOCK_INACTIVE;

#ifdef CEU_FEATURES_THREAD
    pthread_mutex_init(&CEU_APP.threads_mutex, NULL);
    CEU_APP.threads_head = NULL;

    /* All code run atomically:
     * - the program is always locked as a whole
     * -    thread spawns will unlock => re-lock
     * - but program will still run to completion
     */
    CEU_THREADS_MUTEX_LOCK(&CEU_APP.threads_mutex);
#endif

    ceu_callback_void_void(CEU_CALLBACK_START, CEU_TRACE_null);

    CEU_APP.root._trails[0].evt.id    = CEU_INPUT__STACKED;
    CEU_APP.root._trails[0].stk_level = 1;
    CEU_APP.root._trails[0].lbl       = CEU_LABEL_ROOT;

    tceu_evt   evt   = {CEU_INPUT__NONE, {NULL}};
    tceu_range range = {(tceu_code_mem*)&CEU_APP.root, 0, CEU_TRAILS_N-1};
    ceu_bcast(1, &evt, NULL, &range);
}

CEU_API void ceu_stop (void) {
#ifdef CEU_FEATURES_THREAD
    CEU_THREADS_MUTEX_UNLOCK(&CEU_APP.threads_mutex);
    ceu_assert_ex(ceu_threads_gc(1) == 0, "bug found", CEU_TRACE_null); /* wait all terminate/free */
#endif
    ceu_callback_void_void(CEU_CALLBACK_STOP, CEU_TRACE_null);
}

/*****************************************************************************/

CEU_API int ceu_loop (tceu_callback* cb, int argc, char* argv[])
{
    ceu_start(cb, argc, argv);

    while (!CEU_APP.end_ok) {
        ceu_callback_void_void(CEU_CALLBACK_STEP, CEU_TRACE_null);
#ifdef CEU_FEATURES_THREAD
        if (CEU_APP.threads_head != NULL) {
            CEU_THREADS_MUTEX_UNLOCK(&CEU_APP.threads_mutex);
/* TODO: remove this!!! */
            CEU_THREADS_SLEEP(100); /* allow threads to do "atomic" and "terminate" */
            CEU_THREADS_MUTEX_LOCK(&CEU_APP.threads_mutex);
            ceu_threads_gc(0);
        }
#endif
        ceu_input(CEU_INPUT__ASYNC, NULL);
    }

    ceu_stop();

#ifdef CEU_TESTS
    printf("_ceu_tests_bcasts_ = %d\n", _ceu_tests_bcasts_);
    printf("_ceu_tests_trails_visited_ = %d\n", _ceu_tests_trails_visited_);
#endif

    return CEU_APP.end_val;
}
