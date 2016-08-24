#include <stdlib.h>     /* NULL */
#include <string.h>     /* memset, strlen */

#include <lua5.3/lua.h>
#include <lua5.3/lauxlib.h>
#include <lua5.3/lualib.h>

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
typedef === TCEU_NTRL === tceu_ntrl;
typedef === TCEU_NLBL === tceu_nlbl;

typedef struct tceu_evt {
    tceu_nevt id;
    union {
        void* mem;                              /* CEU_INPUT__CODE, CEU_EVENT__MIN */
        struct tceu_stk* stk;                   /* OCCURRING */
        struct tceu_code_mem_dyn* pool_first;   /* CEU_INPUT__CODE_POOL */
        void* var;                              /* CEU_INPUT__VAR */
    };
} tceu_evt;

typedef struct tceu_evt_occ {
    tceu_evt evt;
    void*    params;
} tceu_evt_occ;

struct tceu_stk;
struct tceu_code_mem;
struct tceu_code_mem_dyn;

typedef struct tceu_trl {
    union {
        tceu_evt evt;

        /* NORMAL, CEU_INPUT__CODE, CEU_EVENT__MIN */
        struct {
            tceu_evt _1_evt;
            tceu_nlbl lbl;
        };

        /* CEU_INPUT__PAUSE */
        struct {
            tceu_evt  _2_evt;
            tceu_evt  pse_evt;
            tceu_ntrl pse_skip;
            u8        pse_paused;
        };
    };
} tceu_trl;

struct tceu_pool_pak;
typedef struct tceu_code_mem {
    struct tceu_pool_pak* pak;
    struct tceu_code_mem* up_mem;
    tceu_ntrl up_trl;
    tceu_ntrl trails_n;
    tceu_trl  trails[0];
} tceu_code_mem;

typedef struct tceu_code_mem_dyn {
    struct tceu_code_mem_dyn* prv;
    struct tceu_code_mem_dyn* nxt;
    tceu_code_mem mem[0];   /* actual tceu_code_mem is in sequence */
} tceu_code_mem_dyn;

typedef struct tceu_pool_pak {
    tceu_pool         pool;
    tceu_code_mem_dyn first;
} tceu_pool_pak;

/*****************************************************************************/

/* NATIVE_PRE */
=== NATIVE_PRE ===

/* EVENTS_ENUM */

enum {
    CEU_INPUT__NONE = 0,
    CEU_INPUT__CLEAR,
    CEU_INPUT__PAUSE,
    CEU_INPUT__VAR,
    CEU_INPUT__CODE,
    CEU_INPUT__CODE_POOL,
    CEU_INPUT__ASYNC,
    CEU_INPUT__WCLOCK,
    === EXTS_ENUM_INPUT ===

    CEU_EVENT__MIN,
    === EVTS_ENUM ===
};

enum {
    CEU_OUTPUT__NONE = 0,
    === EXTS_ENUM_OUTPUT ===
};

/* DATAS_HIERS */

typedef s16 tceu_ndata;  /* TODO */

=== DATAS_HIERS ===

static int ceu_data_is (tceu_ndata* supers, tceu_ndata me, tceu_ndata cmp) {
    return (me==cmp || (me!=0 && ceu_data_is(supers,supers[me],cmp)));
}

static void* ceu_data_as (tceu_ndata* supers, tceu_ndata* me, tceu_ndata cmp,
                          char* file, int line) {
    ceu_callback_assert_msg_ex(ceu_data_is(supers, *me, cmp),
                               "invalid cast `as´", file, line);
    return me;
}

/* DATAS_MEMS */

=== DATAS_MEMS ===

/*****************************************************************************/

=== CODES_MEMS ===
=== CODES_ARGS ===

=== EXTS_TYPES ===
=== EVTS_TYPES ===

enum {
    CEU_LABEL_NONE = 0,
    === LABELS ===
};

typedef struct tceu_app {

    /* WCLOCK */
    s32 wclk_late;
    s32 wclk_min_set;
    s32 wclk_min_cmp;

    lua_State* lua;

    tceu_code_mem_ROOT root;
} tceu_app;

static tceu_app CEU_APP;

/*****************************************************************************/

typedef struct tceu_stk {
    struct tceu_stk* down;
    tceu_code_mem*   mem;
    tceu_ntrl        trl;
    u8               is_alive : 1;
} tceu_stk;

static tceu_stk CEU_STK_BASE;

static int ceu_mem_is_child (tceu_code_mem* me, tceu_code_mem* par_mem,
                             tceu_ntrl par_trl1, tceu_ntrl par_trl2)
{
    if (me == par_mem) {
ceu_callback_assert_msg(0, "TODO");
        return (par_trl1==0 && par_trl2==me->trails_n-1);
    }

    tceu_code_mem* cur_mem;
    for (cur_mem=me; cur_mem!=NULL; cur_mem=cur_mem->up_mem) {
        if (cur_mem->up_mem == par_mem) {
            if (cur_mem->up_trl>=par_trl1 && cur_mem->up_trl<=par_trl2) {
                return 1;
            }
        }
    }
    return 0;
}

static void ceu_stack_clear (tceu_stk* stk, tceu_code_mem* mem,
                             tceu_ntrl trl1, tceu_ntrl trl2) {
    for (; stk!=&CEU_STK_BASE; stk=stk->down) {
        if (!stk->is_alive) {
            continue;
        }
        if (stk->mem != mem) {
            /* check if "stk->mem" is child of "mem" in between "[trl1,trl2]" */
            if (ceu_mem_is_child(stk->mem, mem, trl1, trl2)) {
                stk->is_alive = 0;
            }
        } else if (trl1<=stk->trl && stk->trl<=trl2) {  /* [trl1,trl2] */
            stk->is_alive = 0;
        }
    }
}

#if 0
static void ceu_stack_dump (tceu_stk* stk) {
    for (; stk!=&CEU_STK_BASE; stk=stk->down) {
        printf("stk=%p mem=%p\n", stk, stk->mem);
    }
}
#endif

/*****************************************************************************/

#define CEU_WCLOCK_INACTIVE INT32_MAX

static int ceu_wclock (s32 dt, s32* set, s32* sub)
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
        ceu_callback_num_ptr(CEU_CALLBACK_WCLOCK_MIN, t, NULL);
    }

    return ret;
}

/*****************************************************************************/

int ceu_lua_atpanic (lua_State* lua) {
    const char* msg = lua_tostring(lua,-1);
    ceu_dbg_assert(msg != NULL);
    ceu_callback_assert_msg(0, msg);
    return 0;
}

/*****************************************************************************/

static void ceu_go_bcast (tceu_evt_occ* occ, tceu_stk* stk,
                          tceu_code_mem* mem, tceu_ntrl trl0, tceu_ntrl trlF);
static void ceu_go_ext (tceu_nevt evt_id, void* evt_params);
static void ceu_go_lbl (tceu_evt_occ* _ceu_evt, tceu_stk* _ceu_stk,
                        tceu_code_mem* _ceu_mem, tceu_ntrl _ceu_trlK, tceu_nlbl _ceu_lbl);

#define CEU_STK_LBL(occ, stk_old, exe_mem,exe_trl,exe_lbl) {    \
    tceu_stk __ceu_stk = { stk_old, exe_mem, 0, 1 };            \
    ceu_go_lbl(occ, &__ceu_stk, exe_mem, exe_trl, exe_lbl);     \
}

#define CEU_STK_LBL_ABORT(occ, stk_old,                         \
                          abt_mem, abt_trl,                     \
                          exe_mem, exe_trl, exe_lbl) {          \
    tceu_stk __ceu_stk = { stk_old, abt_mem, abt_trl, 1 };      \
    ceu_go_lbl(occ, &__ceu_stk, exe_mem,exe_trl,exe_lbl);       \
    if (!__ceu_stk.is_alive) {                                  \
        return;                                                 \
    }                                                           \
}

#define CEU_STK_BCAST(occ, stk_old,                             \
                      abt_mem, abt_trl,                         \
                      exe_mem, exe_trl0, exe_trlF) {            \
    tceu_stk __ceu_stk = { stk_old, abt_mem, abt_trl, 1 };      \
    ceu_go_bcast(&occ, &__ceu_stk, exe_mem,exe_trl0,exe_trlF);  \
}

#define CEU_STK_BCAST_ABORT(occ, stk_old,                       \
                            abt_mem, abt_trl,                   \
                            exe_mem, exe_trl0, exe_trlF) {      \
    tceu_stk __ceu_stk = { stk_old, abt_mem, abt_trl, 1 };      \
    ceu_go_bcast(&occ, &__ceu_stk, exe_mem,exe_trl0,exe_trlF);  \
    if (!__ceu_stk.is_alive) {                                  \
        return;                                                 \
    }                                                           \
}

=== NATIVE_POS ===

=== CODES_WRAPPERS ===

/*****************************************************************************/

static void ceu_go_lbl (tceu_evt_occ* _ceu_evt, tceu_stk* _ceu_stk,
                        tceu_code_mem* _ceu_mem, tceu_ntrl _ceu_trlK, tceu_nlbl _ceu_lbl)
{
    switch (_ceu_lbl) {
        CEU_LABEL_NONE:
            break;
        === CODES ===
    }
}

static void ceu_go_bcast_1 (tceu_evt_occ* occ, tceu_stk* stk,
                            tceu_code_mem* mem, tceu_ntrl trl0, tceu_ntrl trlF)
{
    tceu_ntrl trlK;
    tceu_trl* trl;

    /* MARK TRAILS TO EXECUTE */

#if 0
#include <stdio.h>
printf("BCAST: stk=%p, evt=%d, trl0=%d, trlF=%d\n", stk, occ->evt.id, trl0, trlF);
#endif

    for (trlK=trl0, trl=&mem->trails[trlK];
         trlK<=trlF;
         trlK++, trl++)
    {
#if 0
printf("\ttrlI=%d, trl=%p, lbl=%d evt=%d\n", trlK, trl, trl->lbl, trl->evt);
#endif
        /* IN__CLEAR and "finalize" clause */
        int matches_clear = (occ->evt.id==CEU_INPUT__CLEAR &&
                             trl->evt.id==CEU_INPUT__CLEAR);

        /* occ->evt.id matches awaiting trail */
        int matches_await = (trl->evt.id==occ->evt.id);
        if (matches_await) {
            if (trl->evt.id == CEU_INPUT__CODE) {
                matches_await = (occ->evt.mem == trl->evt.mem);
            } else if (trl->evt.id == CEU_INPUT__VAR) {
                matches_await = (trl->evt.var==occ->evt.var || trl->evt.var==NULL);
                                                                /* HACK_4 */
            } else if (trl->evt.id > CEU_EVENT__MIN) {
                matches_await = (trl->evt.mem == occ->evt.mem);
            }
        }

        if (matches_clear || matches_await) {
            trl->evt.id  = CEU_INPUT__NONE;
            trl->evt.stk = stk;     /* awake only at this level again */

        /* propagate "evt" to nested "code" */
        } else if (trl->evt.id == CEU_INPUT__CODE) {
            ceu_go_bcast_1(occ, stk, (tceu_code_mem*)trl->evt.mem,
                           0, ((tceu_code_mem*)trl->evt.mem)->trails_n-1);
        } else if (trl->evt.id == CEU_INPUT__CODE_POOL) {
            tceu_code_mem_dyn* cur = trl->evt.pool_first->nxt;
#if 0
printf(">>> BCAST[%p]:\n", trl->pool_first);
printf(">>> BCAST[%p]: %p / %p\n", trl->pool_first, cur, &cur->mem[0]);
#endif
            while (cur != trl->evt.pool_first) {
                ceu_go_bcast_1(occ, stk, &cur->mem[0],
                               0, ((&cur->mem[0])->trails_n-1));
                cur = cur->nxt;
            }

        } else if (trl->evt.id == CEU_INPUT__PAUSE) {
            u8 was_paused = trl->pse_paused;
            if (occ->evt.id==trl->pse_evt.id &&
                (occ->evt.id<CEU_EVENT__MIN || occ->evt.mem==trl->pse_evt.mem))
            {
                trl->pse_paused = *((u8*)occ->params);
            }
            /* don't skip if pausing now */
            if (was_paused) {
                trlK += trl->pse_skip;
                trl  += trl->pse_skip;
            }

        } else if (occ->evt.id == CEU_INPUT__CLEAR) {
            trl->evt.id  = CEU_INPUT__NONE;
            trl->evt.stk = NULL;
        }
    }
}

static void ceu_go_bcast_2 (tceu_evt_occ* occ, tceu_stk* stk,
                            tceu_code_mem* mem, tceu_ntrl trl0, tceu_ntrl trlF)
{
    tceu_ntrl trlK;
    tceu_trl* trl;

    /* EXECUTE TRAILS */

    /* CLEAR: inverse execution order */
    if (occ->evt.id == CEU_INPUT__CLEAR) {
        tceu_ntrl tmp = trl0;
        trl0 = trlF;
        trlF = tmp;
    }

    for (trlK=trl0, trl=&mem->trails[trlK]; ;)
    {
        /* propagate "occ" to nested "code" */
        if (trl->evt.id == CEU_INPUT__CODE) {
            ceu_go_bcast_2(occ, stk, (tceu_code_mem*)trl->evt.mem,
                           0, ((tceu_code_mem*)trl->evt.mem)->trails_n-1);
        } else if (trl->evt.id == CEU_INPUT__CODE_POOL) {
/* TODO: inverse order for FINS */
            tceu_code_mem_dyn* cur = trl->evt.pool_first->nxt;
            while (cur != trl->evt.pool_first) {
                tceu_code_mem_dyn* nxt = cur->nxt;
                ceu_go_bcast_2(occ, stk, &cur->mem[0],
                                    0, (&cur->mem[0])->trails_n-1);
                if (trl->evt.id == CEU_INPUT__NONE) {
                    break;  /* bcast_2 killed myself */
                }
                cur = nxt;
            }
        }

        /* skip */
        else if (trl->evt.id == CEU_INPUT__PAUSE) {
            /* only necessary to avoid INPUT__CODE propagation */
            if (occ->evt.id!=CEU_INPUT__CLEAR && trl->pse_paused) {
                trlK += trl->pse_skip;
                trl  += trl->pse_skip;
            }

        /* execute */
        } else if (trl->evt.id==CEU_INPUT__NONE && trl->evt.stk==stk) {
            trl->evt.stk = NULL;
            CEU_STK_LBL(occ, stk, mem, trlK, trl->lbl);
        }

        /* clear after propagating */
        if (occ->evt.id == CEU_INPUT__CLEAR) {
            trl->evt.id  = CEU_INPUT__NONE;
            trl->evt.stk = NULL;
        }

        if (trlK == trlF) {
            break;
        } else if (occ->evt.id == CEU_INPUT__CLEAR) {
            trlK--; trl--;
        } else {
            trlK++; trl++;
        }
    }
}

static void ceu_go_bcast (tceu_evt_occ* occ, tceu_stk* stk,
                          tceu_code_mem* mem, tceu_ntrl trl0, tceu_ntrl trlF)
{
    ceu_go_bcast_1(occ, stk, mem, trl0, trlF);
    ceu_go_bcast_2(occ, stk, mem, trl0, trlF);
}

static void ceu_go_ext (tceu_nevt evt_id, void* evt_params)
{
    tceu_evt_occ occ = { {evt_id,{NULL}}, evt_params };
    switch (evt_id)
    {
        case CEU_INPUT__WCLOCK: {
            CEU_APP.wclk_min_cmp = CEU_APP.wclk_min_set;      /* swap "cmp" to last "set" */
            CEU_APP.wclk_min_set = CEU_WCLOCK_INACTIVE;    /* new "set" resets to inactive */
            if (CEU_APP.wclk_min_cmp <= *((s32*)evt_params)) {
                CEU_APP.wclk_late = *((s32*)evt_params) - CEU_APP.wclk_min_cmp;
            }
            break;
        }
    }
    ceu_go_bcast(&occ, &CEU_STK_BASE,
                (tceu_code_mem*)&CEU_APP.root, 0, CEU_APP.root.mem.trails_n-1);
}

/*****************************************************************************/

static int ceu_cb_terminating = 0;
static int ceu_cb_terminating_ret;
static int ceu_cb_pending_async = 0;

static tceu_callback_ret ceu_callback_go_all (int cmd, tceu_callback_arg p1, tceu_callback_arg p2) {
    tceu_callback_ret ret = { .is_handled=1 };
    switch (cmd) {
        case CEU_CALLBACK_STEP:
            if (!p1.num) {
                ceu_callback_void_void(CEU_CALLBACK_TERMINATING);
            }
            break;
        case CEU_CALLBACK_TERMINATING:
            ceu_cb_terminating = 1;
            ceu_cb_terminating_ret = p1.num;

/* TODO: CLOSE */
            lua_close(CEU_APP.lua);
            break;
        case CEU_CALLBACK_PENDING_ASYNC:
            ceu_cb_pending_async = 1;
            break;
        default:
            ret.is_handled = 0;
    }
    return ret;
}

int ceu_go_all (void)
{
    ceu_callback_void_void(CEU_CALLBACK_INIT);

    /* TODO: INIT */

    CEU_APP.wclk_late = 0;
    CEU_APP.wclk_min_set = CEU_WCLOCK_INACTIVE;
    CEU_APP.wclk_min_cmp = CEU_WCLOCK_INACTIVE;

    CEU_APP.lua = luaL_newstate();
    ceu_dbg_assert(CEU_APP.lua != NULL);
    luaL_openlibs(CEU_APP.lua);
    lua_atpanic(CEU_APP.lua, ceu_lua_atpanic);

    CEU_STK_LBL(NULL, &CEU_STK_BASE,
                (tceu_code_mem*)&CEU_APP.root, 0, CEU_LABEL_ROOT);

    while (!ceu_cb_terminating) {
        ceu_callback_num_void(CEU_CALLBACK_STEP, ceu_cb_pending_async);
        if (ceu_cb_pending_async) {
            ceu_cb_pending_async = 0;
            ceu_go_ext(CEU_INPUT__ASYNC, NULL);
        }
    }

    return ceu_cb_terminating_ret;
}
